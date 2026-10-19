import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import type { Pool } from "pg";
import { estimatedOneRM, exerciseById } from "../src/data.js";
import { tracksLoadReps } from "../src/exerciseMetrics.js";
import type { WorkspaceData } from "./schema.js";

/**
 * Coach tokens let a member hand a coaching tool (a script, an AI assistant)
 * a credential for their training data. A `read` token reads the training
 * summary only. A `full` token also reads the whole workspace and edits any
 * part of it (routines, workouts, history, profile, schedule). No token can
 * reach the account itself: email, password, sessions, 2-step verification,
 * other tokens and account deletion stay behind the member's own sign-in.
 * The plaintext token is shown once; PostgreSQL stores only an HMAC digest
 * under the server auth secret, so a database read yields no usable credential.
 */

export const COACH_TOKEN_PREFIX = "forma_coach_";
/** Tokens expire so a forgotten copy stops working on its own. */
export const COACH_TOKEN_LIFETIME_DAYS = 90;
/** Enough for one tool per device without becoming a token farm. */
export const MAX_ACTIVE_COACH_TOKENS = 5;
/** Default and maximum window of history returned to a coach. */
export const DEFAULT_SUMMARY_DAYS = 28;
export const MAX_SUMMARY_DAYS = 365;
export const MAX_SUMMARY_SESSIONS = 200;
export const COACH_SCOPES = ["read", "full"] as const;
export type CoachScope = (typeof COACH_SCOPES)[number];
const MAX_NOTE_CHARS = 1000;

const TOKEN_PATTERN = /^forma_coach_[A-Za-z0-9_-]{43}$/;
const ID_PATTERN = /^[A-Za-z0-9_-]{22}$/;
// Mirrors the profile-name rule: no control, format or separator characters.
const LABEL_FORBIDDEN =
  /[\p{Cc}\p{Cf}\p{Cs}\p{Co}\p{Cn}\p{Default_Ignorable_Code_Point}\u2028\u2029\u2800\u3164]/u;

export type CoachTokenRecord = {
  id: string;
  label: string;
  scope: CoachScope;
  createdAt: string;
  expiresAt: string;
  lastUsedAt: string | null;
};

export class CoachTokenLimit extends Error {
  constructor() {
    super("Too many active coach tokens.");
    this.name = "CoachTokenLimit";
  }
}

export class InvalidCoachTokenScope extends Error {
  constructor() {
    super("Coach token scope is invalid.");
    this.name = "InvalidCoachTokenScope";
  }
}

/** Absent means read-only: widening access is always an explicit choice. */
export function normaliseCoachScope(value: unknown): CoachScope {
  if (value === undefined) return "read";
  if (value === "read" || value === "full") return value;
  throw new InvalidCoachTokenScope();
}

export class InvalidCoachTokenLabel extends Error {
  constructor() {
    super("Coach token label is invalid.");
    this.name = "InvalidCoachTokenLabel";
  }
}

export function coachTokenDigest(token: string, secret: string): string {
  return createHmac("sha256", secret)
    .update(`coach-token:${token}`)
    .digest("hex");
}

export function isCoachTokenId(value: unknown): value is string {
  return typeof value === "string" && ID_PATTERN.test(value);
}

/** Accepts only `Bearer <token>` with the FORMA token shape; anything else is unauthenticated. */
export function bearerCoachToken(header: unknown): string | null {
  const value = Array.isArray(header) ? header[0] : header;
  if (typeof value !== "string" || value.length > 120) return null;
  const match = /^Bearer\s+(\S+)$/.exec(value.trim());
  if (!match || !TOKEN_PATTERN.test(match[1])) return null;
  return match[1];
}

export function normaliseCoachLabel(value: unknown): string {
  if (typeof value !== "string") throw new InvalidCoachTokenLabel();
  const label = value.trim();
  const length = [...label].length;
  if (length < 1 || length > 60 || LABEL_FORBIDDEN.test(label))
    throw new InvalidCoachTokenLabel();
  return label;
}

type TokenRow = {
  id: string;
  label: string;
  scope: CoachScope;
  created_at: Date;
  expires_at: Date;
  last_used_at: Date | null;
};

function asRecord(row: TokenRow): CoachTokenRecord {
  return {
    id: row.id,
    label: row.label,
    scope: row.scope === "full" ? "full" : "read",
    createdAt: new Date(row.created_at).toISOString(),
    expiresAt: new Date(row.expires_at).toISOString(),
    lastUsedAt: row.last_used_at
      ? new Date(row.last_used_at).toISOString()
      : null,
  };
}

export async function listCoachTokens(
  pool: Pool,
  userId: string,
): Promise<CoachTokenRecord[]> {
  const result = await pool.query<TokenRow>(
    `SELECT id, label, scope, created_at, expires_at, last_used_at
       FROM member_coach_token
      WHERE owner_id = $1
        AND revoked_at IS NULL
        AND expires_at > clock_timestamp()
      ORDER BY created_at DESC`,
    [userId],
  );
  return result.rows.map(asRecord);
}

/**
 * Mint a token for the authenticated member. The returned `token` is the only
 * copy that will ever exist in plaintext.
 */
export async function issueCoachToken(
  pool: Pool,
  secret: string,
  userId: string,
  labelInput: unknown,
  scopeInput?: unknown,
): Promise<{ token: string; record: CoachTokenRecord }> {
  const label = normaliseCoachLabel(labelInput);
  const scope = normaliseCoachScope(scopeInput);
  const token = `${COACH_TOKEN_PREFIX}${randomBytes(32).toString("base64url")}`;
  const id = randomBytes(16).toString("base64url");
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    // Serialise per member so two concurrent requests cannot exceed the cap.
    await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [
      `coach-token:${userId}`,
    ]);
    const active = await client.query<{ count: string }>(
      `SELECT count(*)::text AS count FROM member_coach_token
        WHERE owner_id = $1 AND revoked_at IS NULL
          AND expires_at > clock_timestamp()`,
      [userId],
    );
    if (Number(active.rows[0]?.count ?? 0) >= MAX_ACTIVE_COACH_TOKENS) {
      await client.query("ROLLBACK");
      throw new CoachTokenLimit();
    }
    const inserted = await client.query<TokenRow>(
      `INSERT INTO member_coach_token
         (id, owner_id, token_digest, label, scope, created_at, expires_at)
       VALUES ($1, $2, $3, $4, $6, clock_timestamp(),
               clock_timestamp() + make_interval(days => $5))
       RETURNING id, label, scope, created_at, expires_at, last_used_at`,
      [
        id,
        userId,
        coachTokenDigest(token, secret),
        label,
        COACH_TOKEN_LIFETIME_DAYS,
        scope,
      ],
    );
    await client.query("COMMIT");
    return { token, record: asRecord(inserted.rows[0]) };
  } catch (error) {
    if (!(error instanceof CoachTokenLimit)) await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

/** Revokes one of the caller's own tokens; another member's ID is simply not found. */
export async function revokeCoachToken(
  pool: Pool,
  userId: string,
  id: string,
): Promise<boolean> {
  if (!isCoachTokenId(id)) return false;
  const result = await pool.query(
    `UPDATE member_coach_token
        SET revoked_at = clock_timestamp()
      WHERE owner_id = $1 AND id = $2 AND revoked_at IS NULL`,
    [userId, id],
  );
  return result.rowCount === 1;
}

/**
 * Resolve a presented token to its owner. Expired and revoked tokens resolve
 * to nothing, exactly like unknown ones. The digest lookup is an indexed
 * equality on random material; a constant-time compare of the stored digest
 * is kept anyway so the code path does not depend on index behaviour.
 */
export async function resolveCoachToken(
  pool: Pool,
  secret: string,
  token: string,
): Promise<{
  userId: string;
  memberName?: string;
  tokenId: string;
  scope: CoachScope;
} | null> {
  if (!TOKEN_PATTERN.test(token)) return null;
  const digest = coachTokenDigest(token, secret);
  const result = await pool.query<{
    id: string;
    owner_id: string;
    token_digest: string;
    scope: string;
    member_name: string | null;
  }>(
    `SELECT t.id, t.owner_id, t.token_digest, t.scope, u.name AS member_name
       FROM member_coach_token AS t
       JOIN "user" AS u ON u.id = t.owner_id
      WHERE t.token_digest = $1
        AND t.revoked_at IS NULL
        AND t.expires_at > clock_timestamp()`,
    [digest],
  );
  const row = result.rows[0];
  if (!row) return null;
  const stored = Buffer.from(row.token_digest.trim());
  const presented = Buffer.from(digest);
  if (stored.length !== presented.length || !timingSafeEqual(stored, presented))
    return null;
  await pool.query(
    `UPDATE member_coach_token SET last_used_at = clock_timestamp() WHERE id = $1`,
    [row.id],
  );
  return {
    userId: row.owner_id,
    memberName: row.member_name || undefined,
    tokenId: row.id,
    scope: row.scope === "full" ? "full" : "read",
  };
}

const WEEKDAYS = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
];

type AnySet = {
  weight: number | "";
  reps: number | "";
  sides?: { left: number | ""; right: number | "" };
  rpe?: number | null;
  done: boolean;
  durationSeconds?: number | "";
  distanceMeters?: number | "";
};

function exerciseName(id: string): string {
  return exerciseById.get(id)?.name ?? id;
}

function compactSet(set: AnySet) {
  return {
    weight: set.weight,
    reps: set.reps,
    // Unilateral sets: reps is the total of both sides.
    ...(set.sides ? { sides: set.sides } : {}),
    ...(set.rpe != null ? { rpe: set.rpe } : {}),
    done: set.done,
    ...(set.durationSeconds !== undefined
      ? { durationSeconds: set.durationSeconds }
      : {}),
    ...(set.distanceMeters !== undefined
      ? { distanceMeters: set.distanceMeters }
      : {}),
  };
}

export function parseSummaryDays(value: unknown): number | null {
  if (value === undefined) return DEFAULT_SUMMARY_DAYS;
  if (typeof value !== "string" || !/^\d{1,3}$/.test(value)) return null;
  const days = Number(value);
  if (days < 1 || days > MAX_SUMMARY_DAYS) return null;
  return days;
}

/**
 * The coach view of a workspace: routines, recent sessions, personal bests and
 * weekly totals. It carries no email, member ID, revision or operation data.
 */
export function coachSummary(
  data: WorkspaceData,
  days = DEFAULT_SUMMARY_DAYS,
  now = Date.now(),
) {
  const since = now - days * 24 * 60 * 60 * 1000;
  const history = [...data.history].sort(
    (a, b) => Date.parse(b.date) - Date.parse(a.date),
  );
  const recent = history
    .filter((session) => Date.parse(session.date) >= since)
    .slice(0, MAX_SUMMARY_SESSIONS);

  const bests = new Map<
    string,
    { bestWeight: number; estimatedOneRM: number; lastPerformed: string }
  >();
  for (const session of history) {
    for (const entry of session.exercises) {
      const exercise = exerciseById.get(entry.exerciseId);
      if (!tracksLoadReps(exercise)) continue;
      for (const set of entry.sets as AnySet[]) {
        if (!set.done || typeof set.weight !== "number") continue;
        const reps = typeof set.reps === "number" ? set.reps : 0;
        const current = bests.get(entry.exerciseId) ?? {
          bestWeight: 0,
          estimatedOneRM: 0,
          lastPerformed: session.date,
        };
        current.bestWeight = Math.max(current.bestWeight, set.weight);
        if (reps >= 1 && reps <= 12)
          current.estimatedOneRM = Math.max(
            current.estimatedOneRM,
            Math.round(estimatedOneRM(set.weight, reps) * 10) / 10,
          );
        if (Date.parse(session.date) > Date.parse(current.lastPerformed))
          current.lastPerformed = session.date;
        bests.set(entry.exerciseId, current);
      }
    }
  }

  const weeks = new Map<string, { sessions: number; volume: number }>();
  for (const session of recent) {
    const date = new Date(session.date);
    const weekStart = new Date(date);
    weekStart.setUTCHours(0, 0, 0, 0);
    weekStart.setUTCDate(date.getUTCDate() - ((date.getUTCDay() + 6) % 7));
    const key = weekStart.toISOString().slice(0, 10);
    const week = weeks.get(key) ?? { sessions: 0, volume: 0 };
    week.sessions += 1;
    for (const entry of session.exercises) {
      if (!tracksLoadReps(exerciseById.get(entry.exerciseId))) continue;
      for (const set of entry.sets as AnySet[])
        if (
          set.done &&
          typeof set.weight === "number" &&
          typeof set.reps === "number"
        )
          week.volume += set.weight * set.reps;
    }
    weeks.set(key, week);
  }

  return {
    generatedAt: new Date(now).toISOString(),
    days,
    member: { name: data.profile.name, weeklyGoal: data.profile.goal },
    schedule: [...data.schedule].sort().map((day) => WEEKDAYS[day]),
    routines: data.routines.map((routine) => ({
      id: routine.id,
      name: routine.name,
      minutes: routine.minutes,
      level: routine.level,
      exercises: routine.exercises.map((item) => ({
        exerciseId: item.exerciseId,
        name: exerciseName(item.exerciseId),
        sets: item.sets,
        reps: item.reps,
        weight: item.weight,
        ...(item.durationSeconds !== undefined
          ? { durationSeconds: item.durationSeconds }
          : {}),
        ...(item.distanceMeters !== undefined
          ? { distanceMeters: item.distanceMeters }
          : {}),
      })),
    })),
    activeWorkout: data.active
      ? {
          name: data.active.name,
          startedAt: new Date(data.active.startedAt).toISOString(),
        }
      : null,
    sessions: recent.map((session) => ({
      id: session.id,
      name: session.name,
      routineId: session.routineId ?? null,
      date: session.date,
      durationSeconds: session.duration,
      notes: session.notes.slice(0, MAX_NOTE_CHARS),
      exercises: session.exercises.map((entry) => ({
        exerciseId: entry.exerciseId,
        name: exerciseName(entry.exerciseId),
        sets: (entry.sets as AnySet[]).map(compactSet),
      })),
    })),
    personalBests: [...bests.entries()]
      .map(([exerciseId, best]) => ({
        exerciseId,
        name: exerciseName(exerciseId),
        ...best,
      }))
      .sort((a, b) => a.name.localeCompare(b.name)),
    weekly: [...weeks.entries()]
      .sort(([a], [b]) => (a < b ? 1 : -1))
      .map(([weekStart, totals]) => ({ weekStart, ...totals })),
    totalSessions: history.length,
  };
}
