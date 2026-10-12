import { createHash } from "node:crypto";
import type { Pool, PoolClient } from "pg";
import { freshData } from "../src/storage.js";
import type { WorkspaceAcknowledgement, WorkspaceData } from "./schema.js";
import { workspaceDataSchema, workspacePutSchema } from "./schema.js";

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

export class InvalidWorkspace extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidWorkspace";
  }
}

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
  const maxBytes = 20 * 1024 * 1024;
  if (Buffer.byteLength(JSON.stringify(incoming), "utf8") > maxBytes)
    throw new InvalidWorkspace("Workspace data exceeds 20 MiB.");
  const hash = requestHash(incoming, expectedRevision);

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
      const retryAcknowledgement: WorkspaceAcknowledgement = {
        ...acknowledgement,
        data: { ...incoming, revision: acknowledgement.revision },
      };
      return retryAcknowledgement;
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
    const saved: WorkspaceData = { ...incoming, revision: nextRevision };
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
    return acknowledgement;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export function parseWorkspace(value: unknown): WorkspaceData {
  const parsed = workspaceDataSchema.safeParse(value);
  if (!parsed.success) throw new InvalidWorkspace("Workspace data is invalid.");
  return parsed.data;
}
