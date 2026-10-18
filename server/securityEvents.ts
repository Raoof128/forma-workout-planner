import { createHmac } from "node:crypto";

/** Fixed event names and a pseudonymous client key; never serialize requests. */
export function securityEvent(
  url: string,
  status: number,
  client: string,
  secret: string,
  errorCode?: string,
): { event: string; actor: string } | null {
  const path = url.split("?", 1)[0];
  let event: string | undefined;
  if (path === "/api/auth/sign-in/email") {
    if (status === 401) event = "sign_in_failure";
    if (status === 429) event = "sign_in_lockout";
  } else if (path.startsWith("/api/auth/two-factor/") && status === 429) {
    event = "mfa_lockout";
  } else if (path === "/api/coach/workspace") {
    if (status === 401) event = "coach_token_failure";
    if (status === 429) event = "coach_token_lockout";
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
