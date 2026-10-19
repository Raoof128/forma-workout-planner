import { createHash } from "node:crypto";
import type { Pool, PoolClient } from "pg";
import { freshData } from "../src/storage.js";
import type { WorkspaceAcknowledgement, WorkspaceData } from "./schema.js";
import {
  coachPatchSchema,
  workspaceDataSchema,
  workspacePutSchema,
} from "./schema.js";

export class WorkspaceConflict extends Error {
  constructor(
    message: string,
    readonly latest: WorkspaceAcknowledgement,
    readonly code: "stale_revision" | "operation_id_reused" = "stale_revision",
  ) {
    super(message);
    this.name = "WorkspaceConflict";
  }
}

export type WorkspaceIssue = { path: string; message: string };

export class InvalidWorkspace extends Error {
  constructor(
    message: string,
    /** Field-level reasons, returned to coach tools so they can fix a write. */
    readonly issues: WorkspaceIssue[] = [],
  ) {
    super(message);
    this.name = "InvalidWorkspace";
  }
}

/** A coach edit would delete logged workouts without saying how many. */
export class UnconfirmedHistoryRemoval extends Error {
  constructor(readonly removed: number) {
    super(
      `This change removes ${removed} logged workout(s); confirm with removesSessions.`,
    );
    this.name = "UnconfirmedHistoryRemoval";
  }
}

const MAX_WORKSPACE_BYTES = 20 * 1024 * 1024;

type WorkspaceRow = {
  data: WorkspaceData;
  revision: number;
  updated_at: string | Date;
};

function asAcknowledgement(
  row: WorkspaceRow,
  validate = true,
): WorkspaceAcknowledgement {
  const revision = Number(row.revision);
  return {
    // Rows this transaction just wrote were validated before the write; only
    // reads returned to clients re-check stored data.
    data: validate ? workspaceDataSchema.parse(row.data) : row.data,
    revision,
    updatedAt:
      typeof row.updated_at === "string" && row.updated_at.includes("T")
        ? row.updated_at
        : new Date(row.updated_at).toISOString(),
  };
}

function initialWorkspace(name?: string): WorkspaceData {
  const data = freshData();
  const safeName = typeof name === "string" ? name.trim().slice(0, 50) : "";
  data.profile.name = safeName || "Member";
  // The initial routines are useful starter content, but no training history
  // or achievements are invented for a new account.
  data.history = [];
  data.active = null;
  data.revision = 0;
  return workspaceDataSchema.parse(data);
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (value && typeof value === "object") {
    const object = value as Record<string, unknown>;
    return `{${Object.keys(object)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableJson(object[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function requestHash(data: WorkspaceData, expectedRevision: number): string {
  // The revision inside a legacy backup is informational. Only the explicit
  // expectedRevision participates in optimistic concurrency.
  const payload = { ...data, revision: 0 };
  return createHash("sha256")
    .update(stableJson({ data: payload, expectedRevision }))
    .digest("hex");
}

async function ensureWorkspace(
  client: PoolClient,
  userId: string,
  name?: string,
): Promise<void> {
  await client.query(
    `INSERT INTO member_workspace (owner_id, data, revision, updated_at)
     VALUES ($1, $2::jsonb, 0, clock_timestamp())
     ON CONFLICT (owner_id) DO NOTHING`,
    [userId, JSON.stringify(initialWorkspace(name))],
  );
}

async function selectWorkspace(
  client: PoolClient,
  userId: string,
  lock = false,
  validate = true,
): Promise<WorkspaceAcknowledgement> {
  const result = await client.query<WorkspaceRow>(
    `SELECT data, revision,
            to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS updated_at
       FROM member_workspace
      WHERE owner_id = $1${lock ? " FOR UPDATE" : ""}`,
    [userId],
  );
  if (!result.rows[0]) throw new Error("Workspace row was not created.");
  return asAcknowledgement(result.rows[0], validate);
}

export async function getWorkspace(
  pool: Pool,
  userId: string,
  name?: string,
): Promise<WorkspaceAcknowledgement> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await ensureWorkspace(client, userId, name);
    const workspace = await selectWorkspace(client, userId);
    await client.query("COMMIT");
    return workspace;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

type WriteRequest = {
  operationId: string;
  /** Fingerprint of the caller's payload, for idempotent retries. */
  hash: string;
  expectedRevision: number;
  /** Produces the validated next workspace from the locked current one. */
  build: (current: WorkspaceData) => WorkspaceData;
};

type WriteResult =
  | { replayed: false; acknowledgement: WorkspaceAcknowledgement }
  | { replayed: true; revision: number; updatedAt: string };

/**
 * The one write path for a member workspace: lock the row, replay a repeated
 * operation, refuse a stale revision, then store the next version. Member
 * saves and coach edits both go through here.
 */
async function writeWorkspace(
  pool: Pool,
  userId: string,
  memberName: string | undefined,
  { operationId, hash, expectedRevision, build }: WriteRequest,
): Promise<WriteResult> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await ensureWorkspace(client, userId, memberName);
    // Validated only if it is returned to the client in a conflict below.
    const locked = await selectWorkspace(client, userId, true, false);
    const latest = () => ({
      ...locked,
      data: workspaceDataSchema.parse(locked.data),
    });

    const prior = await client.query<{
      request_hash: string;
      acknowledgement: Pick<WorkspaceAcknowledgement, "revision" | "updatedAt">;
    }>(
      `SELECT request_hash, acknowledgement
         FROM member_workspace_operations
        WHERE owner_id = $1 AND operation_id = $2`,
      [userId, operationId],
    );
    if (prior.rows[0]) {
      // nosemgrep: ajinabraham.njsscan.crypto.timing_attack_node.node_timing_attack -- idempotency hash of the member's own payload, not a secret
      if (prior.rows[0].request_hash !== hash) {
        throw new WorkspaceConflict(
          "operationId was already used for a different workspace update.",
          latest(),
          "operation_id_reused",
        );
      }
      const acknowledgement = prior.rows[0].acknowledgement;
      await client.query("COMMIT");
      return { replayed: true, ...acknowledgement };
    }

    if (locked.revision !== expectedRevision) {
      throw new WorkspaceConflict(
        "Workspace changed since it was loaded.",
        latest(),
      );
    }

    const nextRevision = locked.revision + 1;
    if (nextRevision > 2_147_483_647)
      throw new InvalidWorkspace("Workspace revision limit reached.");
    const saved: WorkspaceData = {
      ...build(locked.data),
      revision: nextRevision,
    };
    const updated = await client.query<WorkspaceRow>(
      `UPDATE member_workspace
          SET data = $2::jsonb,
              revision = $3,
              updated_at = GREATEST(clock_timestamp(), updated_at + interval '1 microsecond')
        WHERE owner_id = $1
        RETURNING data, revision,
                  to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS updated_at`,
      [userId, JSON.stringify(saved), nextRevision],
    );
    const acknowledgement = asAcknowledgement(updated.rows[0], false);
    await client.query(
      `INSERT INTO member_workspace_operations
         (owner_id, operation_id, request_hash, acknowledgement)
       VALUES ($1, $2, $3, $4::jsonb)`,
      [
        userId,
        operationId,
        hash,
        JSON.stringify({
          revision: acknowledgement.revision,
          updatedAt: acknowledgement.updatedAt,
        }),
      ],
    );
    // The client sends the same payload when retrying an operation, so only
    // revision/time metadata is needed to reconstruct the original response.
    // Keep a bounded retry window. An expired operation can only receive a
    // stale-revision 409; it cannot reapply to newer state.
    await client.query(
      `DELETE FROM member_workspace_operations
        WHERE owner_id = $1
          AND (
            created_at < clock_timestamp() - interval '30 days'
            OR operation_id IN (
              SELECT operation_id
                FROM member_workspace_operations
               WHERE owner_id = $1
               ORDER BY created_at DESC, operation_id DESC
               OFFSET 1000
            )
          )`,
      [userId],
    );
    await client.query("COMMIT");
    return { replayed: false, acknowledgement };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function putWorkspace(
  pool: Pool,
  userId: string,
  memberName: string | undefined,
  input: unknown,
): Promise<WorkspaceAcknowledgement> {
  const parsed = workspacePutSchema.safeParse(input);
  if (!parsed.success)
    throw new InvalidWorkspace("Workspace payload is invalid.");

  const { expectedRevision, operationId } = parsed.data;
  // workspacePutSchema already ran the full workspace validator.
  const incoming = parsed.data.data;
  if (Buffer.byteLength(JSON.stringify(incoming), "utf8") > MAX_WORKSPACE_BYTES)
    throw new InvalidWorkspace("Workspace data exceeds 20 MiB.");
  const result = await writeWorkspace(pool, userId, memberName, {
    operationId,
    hash: requestHash(incoming, expectedRevision),
    expectedRevision,
    build: () => incoming,
  });
  if (!result.replayed) return result.acknowledgement;
  return {
    revision: result.revision,
    updatedAt: result.updatedAt,
    data: { ...incoming, revision: result.revision },
  };
}

/** The workspace sections a coach edit may replace, each as a whole. */
export const COACH_SECTIONS = [
  "routines",
  "history",
  "active",
  "profile",
  "schedule",
] as const;

function issuesOf(error: {
  issues: { path: PropertyKey[]; message: string }[];
}) {
  return error.issues.slice(0, 10).map((issue) => ({
    path: issue.path.map(String).join("."),
    message: issue.message,
  }));
}

/**
 * Apply a coach edit: each section named in `changes` replaces the stored
 * section; everything else is kept. The merged workspace passes the same
 * strict validator as a member save. Dropping logged workouts must be
 * confirmed with their exact count, so a tool that only read the recent
 * summary cannot erase older history by accident.
 */
export async function patchWorkspace(
  pool: Pool,
  userId: string,
  memberName: string | undefined,
  input: unknown,
): Promise<{ revision: number; updatedAt: string; replayed: boolean }> {
  const parsed = coachPatchSchema.safeParse(input);
  if (!parsed.success)
    throw new InvalidWorkspace(
      "Send expectedRevision, operationId and changes with at least one of: routines, history, active, profile, schedule.",
      issuesOf(parsed.error),
    );
  const { expectedRevision, operationId, changes, removesSessions } =
    parsed.data;
  const hash = createHash("sha256")
    .update(
      stableJson({
        coach: true,
        changes,
        removesSessions: removesSessions ?? null,
        expectedRevision,
      }),
    )
    .digest("hex");
  const result = await writeWorkspace(pool, userId, memberName, {
    operationId,
    hash,
    expectedRevision,
    build(current) {
      const merged: Record<string, unknown> = { ...current };
      for (const section of COACH_SECTIONS)
        if (Object.hasOwn(changes, section)) merged[section] = changes[section];
      const checked = workspaceDataSchema.safeParse(merged);
      if (!checked.success)
        throw new InvalidWorkspace(
          "The edited workspace is invalid.",
          issuesOf(checked.error),
        );
      if (
        Buffer.byteLength(JSON.stringify(checked.data), "utf8") >
        MAX_WORKSPACE_BYTES
      )
        throw new InvalidWorkspace("Workspace data exceeds 20 MiB.");
      const next = checked.data as WorkspaceData;
      const kept = new Set(next.history.map((session) => session.id));
      const removed = current.history.filter(
        (session: { id: string }) => !kept.has(session.id),
      ).length;
      if (removed > 0 && removesSessions !== removed)
        throw new UnconfirmedHistoryRemoval(removed);
      return next;
    },
  });
  return result.replayed
    ? { revision: result.revision, updatedAt: result.updatedAt, replayed: true }
    : {
        revision: result.acknowledgement.revision,
        updatedAt: result.acknowledgement.updatedAt,
        replayed: false,
      };
}

export function parseWorkspace(value: unknown): WorkspaceData {
  const parsed = workspaceDataSchema.safeParse(value);
  if (!parsed.success) throw new InvalidWorkspace("Workspace data is invalid.");
  return parsed.data;
}
