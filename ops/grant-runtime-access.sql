GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  "user", "session", account, verification, "twoFactor", mfa_totp_replay,
  member_workspace, member_workspace_operations
TO forma_runtime;
