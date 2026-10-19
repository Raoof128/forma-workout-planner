-- Coach tokens gain an access scope. Every existing token stays read-only
-- ('read'): a credential already handed to a tool is never widened in place.
-- 'full' tokens can also read the whole workspace and edit any section of it
-- through the coach API. Neither scope reaches account or credential actions.
ALTER TABLE member_coach_token
  ADD COLUMN IF NOT EXISTS scope text NOT NULL DEFAULT 'read';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'member_coach_token_scope_known'
  ) THEN
    ALTER TABLE member_coach_token
      ADD CONSTRAINT member_coach_token_scope_known
      CHECK (scope IN ('read', 'full'));
  END IF;
END $$;
