CREATE TABLE IF NOT EXISTS member_workspace (
  owner_id text PRIMARY KEY REFERENCES "user" (id) ON DELETE CASCADE,
  data jsonb NOT NULL,
  revision integer NOT NULL DEFAULT 0 CHECK (revision >= 0),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT member_workspace_data_object CHECK (jsonb_typeof(data) = 'object'),
  CONSTRAINT member_workspace_data_version CHECK (data ->> 'version' = '1'),
  CONSTRAINT member_workspace_revision_matches_data CHECK (data ->> 'revision' = revision::text)
);

CREATE TABLE IF NOT EXISTS member_workspace_operations (
  owner_id text NOT NULL REFERENCES "user" (id) ON DELETE CASCADE,
  operation_id text NOT NULL,
  request_hash char(64) NOT NULL,
  acknowledgement jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (owner_id, operation_id),
  CONSTRAINT workspace_operation_ack_object CHECK (jsonb_typeof(acknowledgement) = 'object')
);

CREATE INDEX IF NOT EXISTS member_workspace_operations_created_at_idx
  ON member_workspace_operations (created_at);
