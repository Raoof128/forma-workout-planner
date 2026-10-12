-- Durable abuse budgets keyed by an HMAC of the subject (normalised email,
-- member ID). Raw identifiers are never stored, so the table is not an email
-- directory and is safe to keep outside the auth tables.
CREATE TABLE IF NOT EXISTS security_throttle (
  scope text NOT NULL CHECK (char_length(scope) BETWEEN 1 AND 64),
  key_digest char(64) NOT NULL,
  window_started timestamptz NOT NULL DEFAULT clock_timestamp(),
  window_count integer NOT NULL DEFAULT 0 CHECK (window_count >= 0),
  consecutive_failures integer NOT NULL DEFAULT 0 CHECK (consecutive_failures >= 0),
  locked_until timestamptz,
  PRIMARY KEY (scope, key_digest)
);

CREATE INDEX IF NOT EXISTS security_throttle_window_idx
  ON security_throttle (window_started);
