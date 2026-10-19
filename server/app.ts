import Fastify, {
  type FastifyInstance,
  type FastifyReply,
  type FastifyRequest,
} from "fastify";
import { createHmac, timingSafeEqual } from "node:crypto";
import type { Pool } from "pg";
import {
  createAuth,
  signInThrottleKey,
  testLimitOverride,
  type EmailSender,
} from "./auth.js";
import type { AppConfig } from "./config.js";
import { createEmailSender } from "./email.js";
import {
  clearSignInFailures,
  consumeBudget,
  DEFAULT_SIGN_IN_POLICY,
  normaliseEmail,
  PASSWORD_CHECK_SCOPE,
  pruneThrottle,
  refundAttempt,
  reserveAttempt,
  settleFailure,
  SIGN_IN_SCOPE,
  throttleKey,
} from "./throttle.js";
import { registerWorkspaceRoutes } from "./workspaceRoutes.js";
import { COACH_DATA_PATH, registerCoachRoutes } from "./coachRoutes.js";
import { securityEvent } from "./securityEvents.js";

declare module "fastify" {
  interface FastifyRequest {
    rawBody: string | Buffer | null;
  }
}

export interface MemberIdentity {
  userId: string;
  name?: string;
  email?: string;
}

export interface AppOptions {
  pool: Pool;
  config: AppConfig;
  email?: EmailSender;
}

type AuthInstance = ReturnType<typeof createAuth>;

export function memberReference(userId: string, secret: string): string {
  return `mem_${createHmac("sha256", secret).update(`member:${userId}`).digest("base64url")}`;
}

export function createRequireMember(
  auth: AuthInstance,
  secret: string,
  onExpired?: (sessionId: string) => Promise<void>,
) {
  return async (
    request: FastifyRequest,
    reply: FastifyReply,
  ): Promise<MemberIdentity | null> => {
    try {
      const headers = new Headers();
      for (const [name, value] of Object.entries(request.headers)) {
        if (Array.isArray(value)) {
          for (const item of value) headers.append(name, item);
        } else if (typeof value === "string") {
          headers.set(name, value);
        }
      }
      const session = await auth.api.getSession({ headers });
      if (!session?.user?.id) {
        reply.code(401).send({ error: "unauthorized" });
        return null;
      }
      if (sessionTooOld(session.session.createdAt)) {
        await onExpired?.(session.session.id);
        reply.code(401).send({ error: "unauthorized" });
        return null;
      }
      if (
        headerValue(request.headers["x-forma-member"]) !==
        memberReference(session.user.id, secret)
      ) {
        reply.code(409).send({ error: "account_changed" });
        return null;
      }
      return {
        userId: session.user.id,
        name: session.user.name || undefined,
        email: session.user.email || undefined,
      };
    } catch {
      reply.code(401).send({ error: "unauthorized" });
      return null;
    }
  };
}

function requestHeaders(request: FastifyRequest): Headers {
  const headers = new Headers();
  for (const [name, value] of Object.entries(request.headers)) {
    if (Array.isArray(value)) {
      for (const item of value) headers.append(name, item);
    } else if (typeof value === "string") {
      headers.set(name, value);
    }
  }
  return headers;
}

async function resolveSession(auth: AuthInstance, request: FastifyRequest) {
  return auth.api.getSession({ headers: requestHeaders(request) });
}

function headerValue(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function secretMatches(actual: string | undefined, expected: string): boolean {
  if (!actual) return false;
  const left = Buffer.from(actual);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

function copyResponseHeaders(
  source: Headers,
  reply: FastifyReply,
  excludedCookies: string[] = [],
): void {
  source.forEach((value, name) => {
    if (
      ![
        "set-cookie",
        "content-length",
        "content-encoding",
        "transfer-encoding",
      ].includes(name.toLowerCase())
    ) {
      reply.header(name, value);
    }
  });
  const cookies = source.getSetCookie().filter((cookie) => {
    const name = cookie.slice(0, cookie.indexOf("=")).toLowerCase();
    return !excludedCookies.some(
      (excluded) =>
        name === excluded.toLowerCase() ||
        name.endsWith(excluded.toLowerCase()),
    );
  });
  if (cookies.length) reply.header("set-cookie", cookies);
}

function removeSensitiveAuthFields(value: unknown, secret: string): unknown {
  if (Array.isArray(value))
    return value.map((item) => removeSensitiveAuthFields(item, secret));
  if (!value || typeof value !== "object") return value;
  const result: Record<string, unknown> = {};
  const record = value as Record<string, unknown>;
  const isUser =
    typeof record.email === "string" ||
    typeof record.emailVerified === "boolean";
  for (const [key, item] of Object.entries(value)) {
    // Better Auth exposes session tokens for native clients and database IDs
    // for convenience. FORMA uses HttpOnly cookies and server-side IDs only.
    if (key === "token" || key === "userId") continue;
    if (key === "id") {
      if (isUser && typeof item === "string") {
        result.id = memberReference(item, secret);
      }
      continue;
    }
    result[key] = removeSensitiveAuthFields(item, secret);
  }
  return result;
}

function sessionReference(sessionId: string, secret: string): string {
  return createHmac("sha256", secret)
    .update(`session:${sessionId}`)
    .digest("base64url");
}

function referenceMatches(candidate: string, expected: string): boolean {
  const left = Buffer.from(candidate);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

// Better Auth exposes many endpoints FORMA never calls (password oracles such as
// verify-password, list-accounts, OTP and social routes). Only the flows the
// app uses are reachable; anything else is a 404 at the proxy.
const AUTH_ROUTES: Record<string, ReadonlySet<string>> = {
  GET: new Set([
    "get-session",
    "verify-email",
    "delete-user/callback",
    "list-sessions",
  ]),
  POST: new Set([
    "sign-up/email",
    "sign-in/email",
    "sign-out",
    "send-verification-email",
    "request-password-reset",
    "reset-password",
    "update-user",
    "change-email",
    "change-password",
    "delete-user",
    "revoke-sessions",
    "revoke-other-sessions",
    "two-factor/enable",
    "two-factor/disable",
    "two-factor/verify-totp",
    "two-factor/verify-backup-code",
    "two-factor/generate-backup-codes",
  ]),
};

// Signed-in endpoints that verify the member's password.
const PASSWORD_CHECKED_PATHS: ReadonlySet<string> = new Set([
  "change-password",
  "delete-user",
  "two-factor/enable",
  "two-factor/disable",
  "two-factor/generate-backup-codes",
]);
const PASSWORD_FIELDS = ["password", "currentPassword"];

// Endpoints acting on the signed-in member must carry the matching
// X-Forma-Member reference, so a tab still showing member A cannot act as B.
const memberBoundPathsAll: ReadonlySet<string> = new Set([
  "update-user",
  "change-email",
  "change-password",
  "delete-user",
  "revoke-sessions",
  "revoke-other-sessions",
  "list-sessions",
  "sign-out",
  "two-factor/enable",
  "two-factor/disable",
  "two-factor/verify-totp",
  "two-factor/verify-backup-code",
  "two-factor/generate-backup-codes",
]);

export function authRouteAllowed(method: string, authPath: string): boolean {
  if (
    method === "GET" &&
    /^reset-password\/[A-Za-z0-9_-]{1,256}$/.test(authPath)
  )
    return true;
  return AUTH_ROUTES[method]?.has(authPath) ?? false;
}

/** NIST SP 800-63B-4 AAL1: reauthenticate at least every 30 days. */
export const MAX_SESSION_AGE_MS = 30 * 24 * 60 * 60 * 1000;

function sessionTooOld(createdAt: unknown): boolean {
  const created = new Date(createdAt as string | Date).getTime();
  return !Number.isFinite(created) || Date.now() - created > MAX_SESSION_AGE_MS;
}

/** Profile fields a member may set; Better Auth itself accepts any size. */
function invalidProfileInput(body: unknown): boolean {
  if (!body || typeof body !== "object" || Array.isArray(body)) return false;
  const record = body as Record<string, unknown>;
  if ("name" in record) {
    if (typeof record.name !== "string") return true;
    const name = record.name.trim();
    // Count code points, and refuse control, format (zero-width, bidi) and
    // line/paragraph separator characters that hide or spoof a name.
    const length = [...name].length;
    if (
      length < 1 ||
      length > 60 ||
      /[\p{Cc}\p{Cf}\p{Cs}\p{Co}\p{Cn}\p{Default_Ignorable_Code_Point}\u2028\u2029\u2800\u3164]/u.test(
        name,
      )
    )
      return true;
  }
  // FORMA has no avatars; an arbitrary image URL is only a tracking vector.
  return "image" in record && record.image !== null;
}

function sessionTokenFromCookie(cookie: string): string | null {
  const pair = cookie.split(";", 1)[0];
  const name = pair.slice(0, pair.indexOf("=")).trim().toLowerCase();
  if (!name.endsWith("session_token")) return null;
  const value = decodeURIComponent(pair.slice(pair.indexOf("=") + 1));
  return value ? value.split(".", 1)[0] : null;
}

const REDIRECT_PARAMETERS = [
  "callbackURL",
  "redirectTo",
  "errorCallbackURL",
  "newUserCallbackURL",
];

/**
 * Accept only same-origin absolute URLs or origin-relative paths. Better Auth
 * does not validate callbackURL on unauthenticated token GETs, so the proxy
 * enforces it for every auth request instead of trusting the library.
 */
export function isSafeRedirect(value: unknown, appOrigin: string): boolean {
  if (typeof value !== "string" || value.length > 2048) return false;
  // nosemgrep: ajinabraham.njsscan.dos.regex_dos.regex_dos -- single character class, input capped at 2048 chars
  if (/[\u0000-\u001f\\]/.test(value)) return false;
  if (value.startsWith("/") && !value.startsWith("//")) return true;
  try {
    return new URL(value).origin === appOrigin;
  } catch {
    return false;
  }
}

function unsafeRedirectParameter(
  url: URL,
  body: unknown,
  appOrigin: string,
): boolean {
  for (const name of REDIRECT_PARAMETERS) {
    for (const value of url.searchParams.getAll(name))
      if (!isSafeRedirect(value, appOrigin)) return true;
    if (body && typeof body === "object" && !Array.isArray(body)) {
      const value = (body as Record<string, unknown>)[name];
      if (value !== undefined && !isSafeRedirect(value, appOrigin)) return true;
    }
  }
  return false;
}

async function storeTotpUse(
  pool: Pool,
  secret: string,
  userId: string,
  code: string,
): Promise<boolean> {
  const digest = createHmac("sha256", secret)
    .update(`totp-replay:${userId}:${code}`)
    .digest("hex");
  await pool.query("DELETE FROM mfa_totp_replay WHERE expires_at <= now()");
  const result = await pool.query(
    `INSERT INTO mfa_totp_replay ("userId", code_digest, expires_at)
     VALUES ($1, $2, now() + interval '90 seconds')
     ON CONFLICT ("userId", code_digest) DO UPDATE
       SET expires_at = EXCLUDED.expires_at
       WHERE mfa_totp_replay.expires_at <= now()
     RETURNING 1`,
    [userId, digest],
  );
  return result.rowCount === 1;
}

export async function createApp({
  pool,
  config,
  email,
}: AppOptions): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: "warn",
      redact: {
        paths: [
          "req.headers.cookie",
          "req.headers.authorization",
          "req.headers.x-forma-worker-secret",
          "req.body.password",
          "req.body.currentPassword",
          "req.body.newPassword",
          "req.body.token",
          "req.body.code",
          "req.url",
        ],
        censor: "[REDACTED]",
      },
    },
    bodyLimit: 1024 * 1024,
    trustProxy: false,
  });

  app.decorateRequest("rawBody", null);
  app.addHook("onSend", async (request, reply, payload) => {
    let errorCode: string | undefined;
    if (
      (reply.statusCode === 409 || reply.statusCode === 429) &&
      typeof payload === "string"
    ) {
      try {
        errorCode = (JSON.parse(payload) as { error?: string }).error;
      } catch {
        // Non-JSON responses are not interpreted as member conflict events.
      }
    }
    const event = securityEvent(
      request.url,
      reply.statusCode,
      headerValue(request.headers["x-forma-client-ip"]) || request.ip,
      config.authSecret,
      errorCode,
      request.method,
    );
    if (event)
      request.log.warn(
        { ...event, requestId: request.id, status: reply.statusCode },
        "security event",
      );
    return payload;
  });
  app.addContentTypeParser(
    "application/json",
    { parseAs: "string" },
    (request, body, done) => {
      const rawBody = body.toString();
      request.rawBody = rawBody;
      try {
        done(null, rawBody.length ? JSON.parse(rawBody) : {});
      } catch {
        const error = new Error("invalid_json") as Error & {
          statusCode: number;
        };
        error.statusCode = 400;
        done(error);
      }
    },
  );
  app.addContentTypeParser(
    "*",
    { parseAs: "buffer" },
    (request, body, done) => {
      request.rawBody = body;
      done(null, body);
    },
  );

  // Never echo framework or parser messages; they can describe internals.
  app.setErrorHandler((error, request, reply) => {
    const status =
      typeof (error as { statusCode?: unknown }).statusCode === "number" &&
      (error as { statusCode: number }).statusCode >= 400 &&
      (error as { statusCode: number }).statusCode < 600
        ? (error as { statusCode: number }).statusCode
        : 500;
    if (status >= 500) request.log.error({ err: error }, "request failed");
    const code =
      status === 400 && (error as Error).message === "invalid_json"
        ? "invalid_json"
        : status === 413
          ? "payload_too_large"
          : status === 415
            ? "unsupported_media_type"
            : status >= 500
              ? "internal_error"
              : "bad_request";
    reply
      .code(status)
      .header("cache-control", "no-store")
      .send({ error: code });
  });
  app.setNotFoundHandler((_request, reply) => {
    reply.code(404).send({ error: "not_found" });
  });

  const testLimit = testLimitOverride(config);
  const deliverEmail = email ?? createEmailSender(config);
  const emailPerRecipientLimit = testLimit ?? 5;
  // Better Auth limits resends per IP only. Cap mail per recipient and kind so
  // a distributed client cannot flood a victim's mailbox. Over-budget mail is
  // dropped silently: the HTTP response must not reveal account state.
  const throttledEmail: EmailSender = async (message) => {
    const recipient = normaliseEmail(message.email);
    if (!recipient) return;
    const allowed = await consumeBudget(
      pool,
      `email:${message.kind}`,
      throttleKey(config.authSecret, `email:${message.kind}`, recipient),
      emailPerRecipientLimit,
      60 * 60,
    );
    if (!allowed) {
      app.log.warn({ kind: message.kind }, "auth email suppressed by budget");
      return;
    }
    await deliverEmail(message);
  };
  const auth = createAuth(pool, config, throttledEmail);
  const expireSession = async (sessionId: string) => {
    await pool.query(`DELETE FROM "session" WHERE id = $1`, [sessionId]);
  };
  const requireMember = createRequireMember(
    auth,
    config.authSecret,
    expireSession,
  );
  const signInPolicy = {
    ...DEFAULT_SIGN_IN_POLICY,
    windowLimit: testLimit ?? DEFAULT_SIGN_IN_POLICY.windowLimit,
  };
  const workspaceWriteLimit = testLimit ?? 120;

  app.addHook("onRequest", async (request, reply) => {
    reply.header("cache-control", "no-store");
    const path = (request.raw.url ?? request.url).split("?", 1)[0];
    // Deny by default. The router decodes percent-escapes, so a prefix test on
    // the raw URL (e.g. "/api/") can be sidestepped with "/%61pi/...". Only the
    // exact health probe is public; every other spelling needs the Worker.
    if (
      (request.method === "GET" || request.method === "HEAD") &&
      path === "/healthz"
    )
      return;
    if (path.includes("%")) {
      // The Worker never forwards encoded paths; refuse ambiguous spellings.
      reply.code(404).send({ error: "not_found" });
      return;
    }

    const suppliedSecret = headerValue(
      request.headers["x-forma-worker-secret"],
    );
    if (!secretMatches(suppliedSecret, config.workerSharedSecret)) {
      reply.code(401).send({ error: "unauthorized" });
      return;
    }

    if (!["GET", "HEAD", "OPTIONS"].includes(request.method)) {
      const origin = headerValue(request.headers.origin);
      // A coach edit authenticates only with an explicit bearer header, which
      // browsers never attach on their own, and the route ignores cookies, so
      // there is no ambient credential to forge. A tool calling from a server
      // sends no Origin; a foreign Origin is still refused.
      const bearerEdit =
        request.method === "PATCH" &&
        path === COACH_DATA_PATH &&
        origin === undefined;
      if (origin !== config.appOrigin && !bearerEdit) {
        reply.code(403).send({ error: "forbidden" });
      }
    }
  });

  app.get("/healthz", async () => ({ status: "ok" }));

  app.route({
    method: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    url: "/api/auth/*",
    async handler(request, reply) {
      const rawUrl = request.raw.url ?? "/api/auth";
      const url = new URL(rawUrl, config.appOrigin);
      const headers = new Headers();
      for (const [name, value] of Object.entries(request.headers)) {
        if (
          name.toLowerCase() === "host" ||
          name.toLowerCase() === "content-length"
        )
          continue;
        if (Array.isArray(value)) {
          for (const item of value) headers.append(name, item);
        } else if (typeof value === "string") {
          headers.set(name, value);
        }
      }

      const authPath = url.pathname.replace(/^\/api\/auth\//, "");
      if (!authRouteAllowed(request.method, authPath)) {
        return reply.code(404).send({ error: "not_found" });
      }
      if (request.method !== "GET") {
        // Every check below reads the parsed JSON body. Better Auth also
        // accepts form-encoded bodies on some routes, which would arrive here
        // as an unparsed buffer and silently skip those checks. The FORMA
        // client only sends JSON, so nothing else is accepted.
        const type = headerValue(request.headers["content-type"])
          ?.split(";", 1)[0]
          .trim()
          .toLowerCase();
        if (
          type !== "application/json" ||
          !request.body ||
          typeof request.body !== "object" ||
          Array.isArray(request.body)
        ) {
          return reply.code(415).send({ error: "unsupported_media_type" });
        }
      }
      if (unsafeRedirectParameter(url, request.body, config.appOrigin)) {
        return reply.code(400).send({ error: "invalid_redirect" });
      }
      if (
        (authPath === "update-user" || authPath === "sign-up/email") &&
        invalidProfileInput(request.body)
      ) {
        return reply.code(400).send({ error: "invalid_profile" });
      }
      // Resolve the caller's session once for checks that need it.
      const needsSession =
        authPath === "get-session" ||
        authPath === "verify-email" ||
        authPath === "delete-user/callback" ||
        memberBoundPathsAll.has(authPath);
      const existingSession = needsSession
        ? await resolveSession(auth, request).catch(() => null)
        : null;
      if (existingSession && sessionTooOld(existingSession.session.createdAt)) {
        // Past the absolute lifetime: end it so Better Auth sees no session.
        await expireSession(existingSession.session.id);
      }
      const memberBoundPaths = memberBoundPathsAll;
      if (memberBoundPaths.has(authPath)) {
        const session =
          existingSession && !sessionTooOld(existingSession.session.createdAt)
            ? existingSession
            : null;
        if (session?.user?.id) {
          const suppliedMember = headerValue(request.headers["x-forma-member"]);
          const expectedMember = memberReference(
            session.user.id,
            config.authSecret,
          );
          if (suppliedMember !== expectedMember) {
            return reply.code(409).send({ error: "account_changed" });
          }
          if (["revoke-sessions", "revoke-other-sessions"].includes(authPath)) {
            const createdAt = new Date(session.session.createdAt).getTime();
            if (
              !Number.isFinite(createdAt) ||
              Date.now() - createdAt > 5 * 60 * 1000
            ) {
              return reply
                .code(403)
                .send({ error: "reauthentication_required" });
            }
          }
        }
      }

      let rawBody = request.rawBody;
      if (
        (authPath === "update-user" || authPath === "sign-up/email") &&
        typeof (request.body as { name?: unknown })?.name === "string"
      ) {
        // Validation checks the trimmed name; store exactly what was checked.
        rawBody = JSON.stringify({
          ...(request.body as Record<string, unknown>),
          name: (request.body as { name: string }).name.trim(),
        });
      }
      if (
        authPath === "change-password" &&
        request.body &&
        typeof request.body === "object" &&
        !Array.isArray(request.body)
      ) {
        // A password change must end every other session, whatever the client
        // asked for; otherwise a stolen session survives the change.
        rawBody = JSON.stringify({
          ...(request.body as Record<string, unknown>),
          revokeOtherSessions: true,
        });
      }

      // Password attempts are reserved before they are checked so concurrent
      // guesses cannot all slip past the limit (see server/throttle.ts).
      let attempt: { key: string; scope: string } | null = null;
      if (authPath === "sign-in/email") {
        const submitted = normaliseEmail(
          (request.body as { email?: unknown } | undefined)?.email,
        );
        if (submitted)
          attempt = {
            key: signInThrottleKey(config.authSecret, submitted),
            scope: SIGN_IN_SCOPE,
          };
      } else if (
        PASSWORD_CHECKED_PATHS.has(authPath) &&
        existingSession &&
        // Only a non-empty password is checked; Better Auth treats an empty
        // one as "no password" (e.g. delete-user then sends an email), and a
        // 200 for that must not clear the counter.
        PASSWORD_FIELDS.some((field) => {
          const value = (request.body as Record<string, unknown>)[field];
          return typeof value === "string" && value.length > 0;
        })
      ) {
        // A stolen session must not become an unthrottled password oracle.
        attempt = {
          key: throttleKey(
            config.authSecret,
            "password-check",
            existingSession.user.id,
          ),
          scope: PASSWORD_CHECK_SCOPE,
        };
      }
      if (
        attempt &&
        !(await reserveAttempt(pool, attempt.key, signInPolicy, attempt.scope))
      ) {
        return reply.code(429).send({
          message:
            "Too many password attempts for this account. Try again later or reset your password.",
          code: "TOO_MANY_ATTEMPTS",
        });
      }
      let body: string | Uint8Array | undefined;
      if (!["GET", "HEAD"].includes(request.method)) {
        body =
          typeof rawBody === "string"
            ? rawBody
            : rawBody
              ? new Uint8Array(rawBody)
              : JSON.stringify(request.body ?? {});
      }
      // nosemgrep: ajinabraham.njsscan.xss.xss_node.express_xss -- internal Request to Better Auth, not an HTML response
      const authRequest = new Request(url, {
        method: request.method,
        headers,
        // Node accepts Uint8Array request bodies; this project's DOM typings
        // model only the ArrayBuffer-backed variant of BodyInit.
        ...(body === undefined ? {} : { body: body as BodyInit }),
      });

      try {
        const response = await auth.handler(authRequest);
        if (attempt) {
          let wrongPassword = false;
          if (attempt.scope === SIGN_IN_SCOPE) {
            wrongPassword = response.status === 401 || response.status === 403;
          } else if (response.status === 400 || response.status === 401) {
            const code = await response
              .clone()
              .json()
              .then((value: { code?: unknown }) => value?.code)
              .catch(() => undefined);
            wrongPassword = code === "INVALID_PASSWORD";
          }
          if (response.status === 200) {
            await clearSignInFailures(pool, attempt.key, attempt.scope);
          } else if (wrongPassword) {
            await settleFailure(pool, attempt.key, signInPolicy, attempt.scope);
            // nosemgrep: ajinabraham.njsscan.crypto.crypto_node.node_insecure_random_generator -- sampling for housekeeping, not a secret
            if (Math.random() < 0.01) void pruneThrottle(pool).catch(() => {});
          } else {
            await refundAttempt(pool, attempt.key, attempt.scope);
          }
        }
        // FORMA never signs a member in from an email link
        // (autoSignInAfterVerification is off), but Better Auth's change-email
        // confirmation mints a session when clicked without a cookie. That
        // session would pass the fresh-session step-up with no password or
        // TOTP, so it is deleted and its cookies are withheld.
        const withheldCookies: string[] = [];
        if (authPath === "verify-email") {
          for (const cookie of response.headers.getSetCookie()) {
            const minted = sessionTokenFromCookie(cookie);
            if (minted && minted !== existingSession?.session.token) {
              await pool.query(`DELETE FROM "session" WHERE token = $1`, [
                minted,
              ]);
              withheldCookies.push("session_token", "session_data");
            }
          }
        }
        const location = response.headers.get("location");
        if (location !== null && !isSafeRedirect(location, config.appOrigin)) {
          // Defence in depth for any redirect the library builds itself.
          return reply.code(400).send({ error: "invalid_redirect" });
        }
        if (response.body === null) {
          copyResponseHeaders(response.headers, reply, withheldCookies);
          return reply.code(response.status).send();
        }
        const contentType = response.headers.get("content-type") ?? "";
        if (contentType.includes("application/json")) {
          const authBody = await response.json();
          if (
            url.pathname === "/api/auth/sign-in/email" &&
            response.status === 403 &&
            authBody &&
            typeof authBody === "object" &&
            (authBody as { code?: unknown }).code === "EMAIL_NOT_VERIFIED"
          ) {
            // Keep verified-state from being an account-existence oracle. The
            // UI offers a separate generic resend-verification action.
            return reply.code(401).send({
              message: "Invalid email or password",
              code: "INVALID_EMAIL_OR_PASSWORD",
            });
          }
          if (
            response.status >= 200 &&
            response.status < 300 &&
            url.pathname === "/api/auth/two-factor/verify-totp" &&
            typeof (request.body as { code?: unknown } | undefined)?.code ===
              "string" &&
            authBody &&
            typeof authBody === "object" &&
            typeof (authBody as { token?: unknown }).token === "string" &&
            typeof (authBody as { user?: { id?: unknown } }).user?.id ===
              "string"
          ) {
            const code = (request.body as { code: string }).code;
            const userId = (authBody as { user: { id: string } }).user.id;
            const accepted = await storeTotpUse(
              pool,
              config.authSecret,
              userId,
              code,
            );
            if (!accepted) {
              const sessionToken = (authBody as { token: string }).token;
              const authenticatedSession = await resolveSession(auth, request);
              if (authenticatedSession?.session.token !== sessionToken) {
                await pool.query(
                  `DELETE FROM "session" WHERE token = $1 AND "userId" = $2`,
                  [sessionToken, userId],
                );
              }
              copyResponseHeaders(response.headers, reply, [
                ...withheldCookies,
                "session_token",
                "trust_device",
              ]);
              return reply.code(401).send({ error: "invalid_code" });
            }
          }
          copyResponseHeaders(response.headers, reply, withheldCookies);
          reply.code(response.status);
          const body = removeSensitiveAuthFields(authBody, config.authSecret);
          // nosemgrep: javascript.express.security.audit.xss.direct-response-write.direct-response-write -- JSON body; the Worker refuses HTML API responses
          return reply.send(body);
        }
        copyResponseHeaders(response.headers, reply, withheldCookies);
        reply.code(response.status);
        // nosemgrep: javascript.express.security.audit.xss.direct-response-write.direct-response-write -- Better Auth body; the Worker allows only JSON/text
        return reply.send(Buffer.from(await response.arrayBuffer()));
      } catch {
        return reply.code(500).send({ error: "internal_error" });
      }
    },
  });

  // Removing *other* sessions needs a sign-in from the last five minutes, so a
  // stolen session cannot lock the owner out and keep itself. An older session
  // may instead confirm the password (plus an unused TOTP code when two-step
  // is on) in the same request. Wrong attempts share the signed-in
  // password-check throttle; nothing about the session or cookies changes.
  async function confirmStepUp(
    request: FastifyRequest,
    reply: FastifyReply,
    userId: string,
    current: NonNullable<Awaited<ReturnType<typeof resolveSession>>>,
  ): Promise<boolean> {
    const createdAt = new Date(current.session.createdAt).getTime();
    if (Number.isFinite(createdAt) && Date.now() - createdAt <= 5 * 60_000)
      return true;
    const twoFactor = !!(current.user as { twoFactorEnabled?: boolean })
      .twoFactorEnabled;
    const body = request.body as
      { password?: unknown; code?: unknown } | undefined;
    const password =
      typeof body?.password === "string" &&
      body.password.length > 0 &&
      body.password.length <= 1024
        ? body.password
        : null;
    if (!password) {
      reply.code(403).send({ error: "reauthentication_required", twoFactor });
      return false;
    }
    const key = throttleKey(config.authSecret, "password-check", userId);
    if (
      !(await reserveAttempt(pool, key, signInPolicy, PASSWORD_CHECK_SCOPE))
    ) {
      reply.code(429).send({
        message:
          "Too many password attempts for this account. Try again later or reset your password.",
        code: "TOO_MANY_ATTEMPTS",
      });
      return false;
    }
    try {
      const context = await auth.$context;
      const accounts = await context.internalAdapter.findAccounts(userId);
      const hash = accounts.find(
        (account) => account.providerId === "credential",
      )?.password;
      if (!hash || !(await context.password.verify({ hash, password }))) {
        await settleFailure(pool, key, signInPolicy, PASSWORD_CHECK_SCOPE);
        reply.code(401).send({ error: "invalid_password" });
        return false;
      }
      if (twoFactor) {
        // Six ASCII digits, checked without a regex on member input.
        const code =
          typeof body?.code === "string" &&
          body.code.length === 6 &&
          [...body.code].every((digit) => digit >= "0" && digit <= "9")
            ? body.code
            : null;
        let accepted = false;
        if (code) {
          try {
            // With a session, Better Auth only checks the code; it creates no
            // session and sets no cookie.
            await auth.api.verifyTOTP({
              body: { code },
              headers: requestHeaders(request),
            });
            accepted = await storeTotpUse(
              pool,
              config.authSecret,
              userId,
              code,
            );
          } catch {
            accepted = false;
          }
        }
        if (!accepted) {
          await settleFailure(pool, key, signInPolicy, PASSWORD_CHECK_SCOPE);
          reply.code(401).send({ error: "invalid_code" });
          return false;
        }
      }
      await clearSignInFailures(pool, key, PASSWORD_CHECK_SCOPE);
      return true;
    } catch (error) {
      await refundAttempt(pool, key, PASSWORD_CHECK_SCOPE);
      throw error;
    }
  }

  app.get("/api/account/sessions", async (request, reply) => {
    const member = await requireMember(request, reply);
    if (!member) return reply;
    const current = await resolveSession(auth, request);
    const result = await pool.query<{
      id: string;
      createdAt: Date;
      expiresAt: Date;
      userAgent: string | null;
    }>(
      `SELECT id, "createdAt", "expiresAt", "userAgent"
       FROM "session" WHERE "userId" = $1 AND "expiresAt" > now()
       ORDER BY "createdAt" DESC`,
      [member.userId],
    );
    return reply.send(
      result.rows.map((session) => ({
        id: sessionReference(session.id, config.authSecret),
        createdAt: session.createdAt,
        expiresAt: session.expiresAt,
        userAgent: session.userAgent,
        current: session.id === current?.session.id,
      })),
    );
  });

  app.delete<{ Params: { id: string } }>(
    "/api/account/sessions/:id/revoke",
    async (request, reply) => {
      const member = await requireMember(request, reply);
      if (!member) return reply;
      const current = await resolveSession(auth, request);
      if (!current)
        return reply.code(403).send({ error: "reauthentication_required" });
      if (!(await confirmStepUp(request, reply, member.userId, current)))
        return reply;
      const result = await pool.query<{ id: string }>(
        `SELECT id FROM "session" WHERE "userId" = $1 AND "expiresAt" > now()`,
        [member.userId],
      );
      const target = result.rows.find((row) =>
        referenceMatches(
          request.params.id,
          sessionReference(row.id, config.authSecret),
        ),
      );
      if (!target) return reply.code(404).send({ error: "session_not_found" });
      await pool.query(
        `DELETE FROM "session" WHERE id = $1 AND "userId" = $2`,
        [target.id, member.userId],
      );
      return reply.send({ status: true });
    },
  );

  app.post("/api/account/sessions/revoke-others", async (request, reply) => {
    const member = await requireMember(request, reply);
    if (!member) return reply;
    const current = await resolveSession(auth, request);
    if (!current)
      return reply.code(403).send({ error: "reauthentication_required" });
    if (!(await confirmStepUp(request, reply, member.userId, current)))
      return reply;
    await pool.query(`DELETE FROM "session" WHERE "userId" = $1 AND id <> $2`, [
      member.userId,
      current.session.id,
    ]);
    return reply.send({ status: true });
  });

  // Ending every session, including the caller's, cannot help a stolen
  // session keep access, so it needs no recent sign-in.
  app.post("/api/account/sessions/revoke-all", async (request, reply) => {
    const member = await requireMember(request, reply);
    if (!member) return reply;
    await pool.query(`DELETE FROM "session" WHERE "userId" = $1`, [
      member.userId,
    ]);
    return reply.send({ status: true });
  });

  await registerWorkspaceRoutes(app, {
    pool,
    requireMember,
    allowWrite: (userId) =>
      consumeBudget(
        pool,
        "workspace-write",
        throttleKey(config.authSecret, "workspace-write", userId),
        workspaceWriteLimit,
        60,
      ),
  });
  registerCoachRoutes(app, {
    pool,
    authSecret: config.authSecret,
    requireMember,
    sessionCreatedAt: async (request) => {
      const current = await resolveSession(auth, request).catch(() => null);
      return current ? new Date(current.session.createdAt) : null;
    },
    ...(testLimit !== null
      ? { failureLimit: testLimit, readLimit: testLimit, writeLimit: testLimit }
      : {}),
  });
  return app;
}
