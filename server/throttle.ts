import { createHmac } from "node:crypto";
import type { Pool } from "pg";

/**
 * PostgreSQL-backed abuse budgets. Better Auth's built-in limiter is keyed by
 * client IP only, so it cannot stop a distributed attack on one account or a
 * flood of mail to one recipient. These budgets are keyed by subject instead.
 */

export function throttleKey(secret: string, scope: string, subject: string) {
  return createHmac("sha256", secret)
    .update(`throttle:${scope}:${subject}`)
    .digest("hex");
}

export function normaliseEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  return email.length >= 3 && email.length <= 320 ? email : null;
}

/**
 * Consume one unit of a fixed-window budget. Returns false once `limit` units
 * were used inside `windowSeconds`. The upsert is a single atomic statement so
 * concurrent requests cannot overspend.
 */
export async function consumeBudget(
  pool: Pool,
  scope: string,
  keyDigest: string,
  limit: number,
  windowSeconds: number,
): Promise<boolean> {
  const result = await pool.query<{ window_count: number }>(
    `INSERT INTO security_throttle (scope, key_digest, window_started, window_count)
     VALUES ($1, $2, clock_timestamp(), 1)
     ON CONFLICT (scope, key_digest) DO UPDATE SET
       window_count = CASE
         WHEN security_throttle.window_started <= clock_timestamp() - make_interval(secs => $3)
           THEN 1 ELSE security_throttle.window_count + 1 END,
       window_started = CASE
         WHEN security_throttle.window_started <= clock_timestamp() - make_interval(secs => $3)
           THEN clock_timestamp() ELSE security_throttle.window_started END
     RETURNING window_count`,
    [scope, keyDigest, windowSeconds],
  );
  return Number(result.rows[0]?.window_count ?? Infinity) <= limit;
}

export interface SignInPolicy {
  /** Failures allowed inside one window before a temporary lock. */
  windowLimit: number;
  windowSeconds: number;
  lockSeconds: number;
  /** NIST SP 800-63B-4 caps consecutive failures per account at 100. */
  consecutiveLimit: number;
}

export const DEFAULT_SIGN_IN_POLICY: SignInPolicy = {
  windowLimit: 10,
  windowSeconds: 15 * 60,
  lockSeconds: 15 * 60,
  consecutiveLimit: 100,
};

export const SIGN_IN_SCOPE = "sign-in-failure";
/** Wrong passwords on endpoints a signed-in member uses (keyed by user). */
// nosemgrep: ajinabraham.njsscan.generic.hardcoded_secrets.node_password -- a scope label, not a credential
export const PASSWORD_CHECK_SCOPE = "password-check-failure";

export async function signInLocked(
  pool: Pool,
  keyDigest: string,
  scope = SIGN_IN_SCOPE,
): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM security_throttle
      WHERE scope = $1 AND key_digest = $2 AND locked_until > clock_timestamp()`,
    [scope, keyDigest],
  );
  return (result.rowCount ?? 0) > 0;
}

/**
 * Reserve one password attempt before it is checked. Counting first (in one
 * atomic statement) means concurrent requests cannot all pass a check that
 * only records failures afterwards. Returns false when the subject is locked
 * or this attempt would exceed a limit; the caller must then refuse it.
 */
export async function reserveAttempt(
  pool: Pool,
  keyDigest: string,
  policy: SignInPolicy = DEFAULT_SIGN_IN_POLICY,
  scope = SIGN_IN_SCOPE,
): Promise<boolean> {
  // Counters only move when this request is granted a slot, so a burst of
  // refused requests can never push the subject towards the hard lock.
  // RETURNING old.* (PostgreSQL 18) tells us whether a slot was granted.
  const result = await pool.query<{
    granted: boolean;
    window_count: number;
    consecutive_failures: number;
  }>(
    `INSERT INTO security_throttle AS t
       (scope, key_digest, window_started, window_count, consecutive_failures)
     VALUES ($1, $2, clock_timestamp(), 1, 1)
     ON CONFLICT (scope, key_digest) DO UPDATE SET
       window_started = CASE
         WHEN t.window_started <= clock_timestamp() - make_interval(secs => $3)
           THEN clock_timestamp() ELSE t.window_started END,
       window_count = CASE
         WHEN t.consecutive_failures >= $5 THEN t.window_count
         WHEN t.window_started <= clock_timestamp() - make_interval(secs => $3)
           THEN 1
         WHEN t.window_count < $4 THEN t.window_count + 1
         ELSE t.window_count END,
       consecutive_failures = CASE
         WHEN t.consecutive_failures < $5
          AND (t.window_started <= clock_timestamp() - make_interval(secs => $3)
               OR t.window_count < $4)
           THEN t.consecutive_failures + 1
         ELSE t.consecutive_failures END
     WHERE t.locked_until IS NULL OR t.locked_until <= clock_timestamp()
     RETURNING (old.consecutive_failures IS NULL
                OR new.consecutive_failures > old.consecutive_failures) AS granted,
               new.window_count, new.consecutive_failures`,
    [
      scope,
      keyDigest,
      policy.windowSeconds,
      policy.windowLimit,
      policy.consecutiveLimit,
    ],
  );
  const row = result.rows[0];
  if (!row) return false;
  if (!row.granted) {
    await applyLock(pool, keyDigest, policy, scope);
    return false;
  }
  return true;
}

async function applyLock(
  pool: Pool,
  keyDigest: string,
  policy: SignInPolicy,
  scope: string,
): Promise<void> {
  await pool.query(
    `UPDATE security_throttle SET locked_until = CASE
         WHEN consecutive_failures >= $3 THEN 'infinity'::timestamptz
         ELSE GREATEST(COALESCE(locked_until, '-infinity'::timestamptz),
                       clock_timestamp() + make_interval(secs => $4))
       END
      WHERE scope = $1 AND key_digest = $2
        AND (window_count >= $5 OR consecutive_failures >= $3)`,
    [
      scope,
      keyDigest,
      policy.consecutiveLimit,
      policy.lockSeconds,
      policy.windowLimit,
    ],
  );
}

/** The reserved attempt failed: keep it counted and lock at the limits. */
export async function settleFailure(
  pool: Pool,
  keyDigest: string,
  policy: SignInPolicy = DEFAULT_SIGN_IN_POLICY,
  scope = SIGN_IN_SCOPE,
): Promise<void> {
  await applyLock(pool, keyDigest, policy, scope);
}

/** The reserved attempt was never judged (e.g. 429, 5xx): give it back. */
export async function refundAttempt(
  pool: Pool,
  keyDigest: string,
  scope = SIGN_IN_SCOPE,
): Promise<void> {
  await pool.query(
    `UPDATE security_throttle
        SET window_count = GREATEST(window_count - 1, 0),
            consecutive_failures = GREATEST(consecutive_failures - 1, 0)
      WHERE scope = $1 AND key_digest = $2`,
    [scope, keyDigest],
  );
}

/** Test helper and legacy entry point: reserve and immediately fail. */
export async function recordSignInFailure(
  pool: Pool,
  keyDigest: string,
  policy: SignInPolicy = DEFAULT_SIGN_IN_POLICY,
  scope = SIGN_IN_SCOPE,
): Promise<void> {
  await reserveAttempt(pool, keyDigest, policy, scope);
  await settleFailure(pool, keyDigest, policy, scope);
}

export async function clearSignInFailures(
  pool: Pool,
  keyDigest: string,
  scope = SIGN_IN_SCOPE,
): Promise<void> {
  await pool.query(
    `DELETE FROM security_throttle WHERE scope = $1 AND key_digest = $2`,
    [scope, keyDigest],
  );
}

/** Remove stale rows; called opportunistically, never on a hot path alone. */
export async function pruneThrottle(pool: Pool): Promise<void> {
  await pool.query(
    `DELETE FROM security_throttle
      WHERE window_started < clock_timestamp() - interval '2 days'
        AND (locked_until IS NULL OR locked_until < clock_timestamp())`,
  );
}
