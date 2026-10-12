import { betterAuth } from "better-auth";
import { twoFactor } from "better-auth/plugins";
import type { Pool } from "pg";
import type { AppConfig } from "./config.js";
import type { AuthEmail } from "./email.js";

export type EmailSender = (message: AuthEmail) => Promise<void>;

export function createAuth(
  pool: Pool,
  config: AppConfig,
  sendEmail: EmailSender,
) {
  const testRateLimitOverride =
    config.environment === "test" &&
    process.env.NODE_ENV === "test" &&
    Number.isInteger(config.authRateLimitMax) &&
    (config.authRateLimitMax ?? 0) >= 5 &&
    (config.authRateLimitMax ?? 0) <= 1000;
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
        await sendEmail({ kind: "verify-email", email: user.email, url });
      },
    },
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: true,
      minPasswordLength: 15,
      maxPasswordLength: 1024,
      revokeSessionsOnPasswordReset: true,
      async sendResetPassword({ user, url }) {
        await sendEmail({ kind: "reset-password", email: user.email, url });
      },
    },
    user: {
      changeEmail: {
        enabled: true,
        async sendChangeEmailConfirmation({ user, newEmail, url }) {
          await sendEmail({
            kind: "change-email",
            email: user.email,
            url,
            detail: newEmail,
          });
        },
      },
      deleteUser: {
        enabled: true,
        async sendDeleteAccountVerification({ user, url }) {
          await sendEmail({ kind: "delete-account", email: user.email, url });
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
    },
    plugins: [twoFactor({ issuer: "FORMA" })],
  });

  return auth;
}
