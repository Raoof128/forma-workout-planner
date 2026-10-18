GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  "user", "session", account, verification, "twoFactor", mfa_totp_replay,
  member_workspace, member_workspace_operations, security_throttle,
  member_coach_token
TO forma_runtime;
