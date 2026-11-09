import { betterAuth } from "better-auth";
import { twoFactor } from "better-auth/plugins";
import type { Pool } from "pg";
import type { AppConfig } from "./config.js";
import type { AuthEmail } from "./email.js";
import {
  clearSignInFailures,
  normaliseEmail,
  PASSWORD_CHECK_SCOPE,
  throttleKey,
} from "./throttle.js";

export type EmailSender = (message: AuthEmail) => Promise<void>;

/**
 * Returns the raised per-subject limit for an explicit NODE_ENV=test harness,
 * or null in every other environment. Production limits are never configurable.
 */
export function testLimitOverride(config: AppConfig): number | null {
  return config.environment === "test" &&
    process.env.NODE_ENV === "test" &&
    Number.isInteger(config.authRateLimitMax) &&
    (config.authRateLimitMax ?? 0) >= 5 &&
    (config.authRateLimitMax ?? 0) <= 1000
    ? config.authRateLimitMax!
    : null;
}

export function signInThrottleKey(secret: string, email: string): string {
  return throttleKey(secret, "sign-in", email);
}

/**
 * Credentials that must not outlive a credential change: active coach tokens
 * and the member's two-factor trusted-device records. Better Auth stores a trust
 * record as identifier `trust-device-<random>` with the user id as its value
 * (node_modules/better-auth/dist/plugins/two-factor/verify-two-factor.mjs).
 */
export async function revokeCredentialArtifacts(
  pool: Pool,
  userId: string,
): Promise<void> {
  await pool.query(
    `UPDATE member_coach_token SET revoked_at = now()
      WHERE owner_id = $1 AND revoked_at IS NULL`,
    [userId],
  );
  await pool.query(
    `DELETE FROM verification
      WHERE starts_with(identifier, 'trust-device-') AND value = $1`,
    [userId],
  );
}

/** Logs a fixed event and the error class only: never the address, URL or message. */
function logEmailFailure(error: unknown): void {
  const errorClass = error instanceof Error ? error.name : typeof error;
  process.stderr.write(
    `${JSON.stringify({ event: "auth_email_failed", errorClass })}\n`,
  );
}

export function createAuth(
  pool: Pool,
  config: AppConfig,
  sendEmail: EmailSender,
) {
  // Better Auth awaits every email send unless a background handler is set, so
  // an account that exists (no mail) answers faster than one that does (mail),
  // which is a timing oracle. Production sends in the background and absorbs
  // failures here. That removes the largest difference (mail delivery); small
  // ones from database work remain. The in-memory sink stays awaited so tests
  // read it at once.
  const backgroundEmail = !config.emailSinkEnabled;
  const deliver: EmailSender = backgroundEmail
    ? async (message) => {
        try {
          await sendEmail(message);
        } catch (error) {
          logEmailFailure(error);
        }
      }
    : sendEmail;
  const testRateLimitOverride = testLimitOverride(config) !== null;
  // The local browser journey harness reuses a synthetic edge IP across many
  // independent specs. Never honor this override outside an explicit test app.
  const testAuthLimit = testRateLimitOverride ? config.authRateLimitMax! : 5;
  const globalRateLimitMax =
    config.environment === "test" && process.env.NODE_ENV === "test"
      ? Math.max(100, testAuthLimit)
      : 100;
  const auth = betterAuth({
    appName: "FORMA",
    database: pool,
    baseURL: config.appOrigin,
    basePath: "/api/auth",
    secret: config.authSecret,
    trustedOrigins: [config.appOrigin],
    emailVerification: {
      sendOnSignUp: true,
      sendOnSignIn: true,
      autoSignInAfterVerification: false,
      expiresIn: 60 * 60,
      async sendVerificationEmail({ user, url }) {
        await deliver({ kind: "verify-email", email: user.email, url });
      },
    },
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: true,
      minPasswordLength: 15,
      maxPasswordLength: 1024,
      revokeSessionsOnPasswordReset: true,
      // Proving mailbox control is the recovery path for an account locked by
      // the per-account failed sign-in cap.
      async onPasswordReset({ user }) {
        const email = normaliseEmail(user.email);
        if (email)
          await clearSignInFailures(
            pool,
            signInThrottleKey(config.authSecret, email),
          );
        // Also lift any signed-in password-check lock for this member.
        await clearSignInFailures(
          pool,
          throttleKey(config.authSecret, "password-check", user.id),
          PASSWORD_CHECK_SCOPE,
        );
        // A reset means the old secret may be known: end coach and trusted-device access.
        await revokeCredentialArtifacts(pool, user.id);
      },
      async sendResetPassword({ user, url }) {
        await deliver({ kind: "reset-password", email: user.email, url });
      },
    },
    user: {
      changeEmail: {
        enabled: true,
        async sendChangeEmailConfirmation({ user, newEmail, url }) {
          await deliver({
            kind: "change-email",
            email: user.email,
            url,
            detail: newEmail,
          });
        },
      },
      deleteUser: {
        enabled: true,
        // Seconds (update-user.mjs multiplies by 1e3). Better Auth's default is one day.
        deleteTokenExpiresIn: 60 * 60,
        async sendDeleteAccountVerification({ user, url }) {
          await deliver({ kind: "delete-account", email: user.email, url });
        },
        // Better Auth does not cascade the verification table. Remove only the
        // records whose value is the user id: reset, delete-account, trusted
        // device and 2FA challenge rows. Attempt counters hold "0" or a count.
        async afterDelete(user) {
          await pool.query(
            `DELETE FROM verification
              WHERE value = $1 AND (
                starts_with(identifier, 'reset-password:')
                OR starts_with(identifier, 'delete-account-')
                OR starts_with(identifier, 'trust-device-')
                OR starts_with(identifier, '2fa-'))`,
            [user.id],
          );
        },
      },
    },
    session: {
      expiresIn: 60 * 60 * 24 * 7,
      updateAge: 60 * 60 * 24,
      freshAge: 5 * 60,
      cookieCache: { enabled: false },
    },
    rateLimit: {
      enabled: true,
      window: 60,
      max: globalRateLimitMax,
      customRules: {
        "/sign-in/email": { window: 60, max: testAuthLimit },
        "/sign-up/email": { window: 60, max: testAuthLimit },
        "/request-password-reset": { window: 60, max: testAuthLimit },
        "/reset-password": { window: 60, max: testAuthLimit },
        ...(testRateLimitOverride
          ? { "/send-verification-email": { window: 60, max: testAuthLimit } }
          : {}),
      },
    },
    advanced: {
      cookiePrefix: "forma",
      useSecureCookies: config.appOrigin.startsWith("https://"),
      defaultCookieAttributes: {
        httpOnly: true,
        secure: config.appOrigin.startsWith("https://"),
        sameSite: "lax",
        path: "/",
      },
      ipAddress: { ipAddressHeaders: ["x-forma-client-ip"] },
      ...(backgroundEmail
        ? {
            backgroundTasks: {
              handler(task: Promise<unknown>) {
                // Email sends catch their own failures above; anything else
                // Better Auth runs in the background is logged generically.
                task.catch((error: unknown) =>
                  process.stderr.write(
                    `${JSON.stringify({
                      event: "auth_background_task_failed",
                      errorClass:
                        error instanceof Error ? error.name : typeof error,
                    })}\n`,
                  ),
                );
              },
            },
          }
        : {}),
    },
    plugins: [twoFactor({ issuer: "FORMA" })],
  });

  return auth;
}
