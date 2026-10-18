-- Read-only coach access tokens. A member mints a token in Account > Security
-- and gives it to a coaching tool. Only the HMAC digest of the token is stored,
-- so the table never contains a usable credential. Rows cascade with the user.
CREATE TABLE IF NOT EXISTS member_coach_token (
  id text PRIMARY KEY CHECK (char_length(id) BETWEEN 16 AND 64),
  owner_id text NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
  token_digest char(64) NOT NULL UNIQUE,
  label text NOT NULL CHECK (char_length(label) BETWEEN 1 AND 60),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  last_used_at timestamptz,
  revoked_at timestamptz,
  CONSTRAINT member_coach_token_expiry_after_creation CHECK (expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS member_coach_token_owner_idx
  ON member_coach_token (owner_id);
