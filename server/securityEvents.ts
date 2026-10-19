import { createHmac } from "node:crypto";

const COACH_PATHS = new Set([
  "/api/coach/workspace",
  "/api/coach/workspace/data",
  "/api/coach/exercises",
]);

/** Fixed event names and a pseudonymous client key; never serialize requests. */
export function securityEvent(
  url: string,
  status: number,
  client: string,
  secret: string,
  errorCode?: string,
  method = "GET",
): { event: string; actor: string } | null {
  const path = url.split("?", 1)[0];
  let event: string | undefined;
  if (path === "/api/auth/sign-in/email") {
    if (status === 401) event = "sign_in_failure";
    if (status === 429) event = "sign_in_lockout";
  } else if (path.startsWith("/api/auth/two-factor/") && status === 429) {
    event = "mfa_lockout";
  } else if (COACH_PATHS.has(path)) {
    if (status === 401) event = "coach_token_failure";
    // A guessing lockout and an over-budget valid token are different signals.
    if (status === 429)
      event =
        errorCode === "rate_limited"
          ? "coach_token_rate_limited"
          : "coach_token_lockout";
    if (status === 403) event = "coach_scope_denied";
    // An audit trail of every edit a coach tool made to a workspace.
    if (method === "PATCH" && status === 200) event = "coach_workspace_write";
  } else if (status === 409 && errorCode === "account_changed") {
    event = "account_changed";
  }
  return event
    ? {
        event,
        actor: createHmac("sha256", secret)
          .update(`monitor:${client}`)
          .digest("hex"),
      }
    : null;
}
