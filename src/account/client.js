import { createAuthClient } from "better-auth/react";
import { twoFactorClient } from "better-auth/client/plugins";

// The browser talks only to the same-origin Worker gateway. Better Auth owns
// password and session handling; no bearer token is stored by this client.
export const authClient = createAuthClient({
  baseURL: window.location.origin,
  basePath: "/api/auth",
  plugins: [twoFactorClient()],
});

export function unwrapAuthResult(result) {
  if (result?.error) {
    const error = new Error(
      result.error.message || "The account request could not be completed.",
    );
    error.code = result.error.code;
    error.status = result.error.status;
    throw error;
  }
  return result?.data ?? result;
}
