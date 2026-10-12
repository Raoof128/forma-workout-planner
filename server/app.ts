import Fastify, {
  type FastifyInstance,
  type FastifyReply,
  type FastifyRequest,
} from "fastify";
import { createHmac, timingSafeEqual } from "node:crypto";
import type { Pool } from "pg";
import { createAuth, type EmailSender } from "./auth.js";
import type { AppConfig } from "./config.js";
import { createEmailSender } from "./email.js";
import { registerWorkspaceRoutes } from "./workspaceRoutes.js";

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

export function createRequireMember(auth: AuthInstance, secret: string) {
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

async function resolveSession(auth: AuthInstance, request: FastifyRequest) {
  const headers = new Headers();
  for (const [name, value] of Object.entries(request.headers)) {
    if (Array.isArray(value)) {
      for (const item of value) headers.append(name, item);
    } else if (typeof value === "string") {
      headers.set(name, value);
    }
  }
  return auth.api.getSession({ headers });
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
  app.addContentTypeParser(
    "application/json",
    { parseAs: "string" },
    (request, body, done) => {
      const rawBody = body.toString();
      request.rawBody = rawBody;
      try {
        done(null, rawBody.length ? JSON.parse(rawBody) : {});
      } catch (error) {
        done(error as Error);
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

  const auth = createAuth(pool, config, email ?? createEmailSender(config));
  const requireMember = createRequireMember(auth, config.authSecret);

  app.addHook("onRequest", async (request, reply) => {
    reply.header("cache-control", "no-store");
    if (request.url === "/healthz" && request.method === "GET") return;
    if (!request.url.startsWith("/api/")) return;

    const suppliedSecret = headerValue(
      request.headers["x-forma-worker-secret"],
    );
    if (!secretMatches(suppliedSecret, config.workerSharedSecret)) {
      reply.code(401).send({ error: "unauthorized" });
      return;
    }

    if (!["GET", "HEAD", "OPTIONS"].includes(request.method)) {
      const origin = headerValue(request.headers.origin);
      if (origin !== config.appOrigin) {
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
      const memberBoundPaths = new Set([
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
        "two-factor/view-backup-codes",
      ]);
      if (memberBoundPaths.has(authPath)) {
        const session = await resolveSession(auth, request);
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

      const rawBody = request.rawBody;
      let body: string | Uint8Array | undefined;
      if (!["GET", "HEAD"].includes(request.method)) {
        body =
          typeof rawBody === "string"
            ? rawBody
            : rawBody
              ? new Uint8Array(rawBody)
              : JSON.stringify(request.body ?? {});
      }
      const authRequest = new Request(url, {
        method: request.method,
        headers,
        // Node accepts Uint8Array request bodies; this project's DOM typings
        // model only the ArrayBuffer-backed variant of BodyInit.
        ...(body === undefined ? {} : { body: body as BodyInit }),
      });

      try {
        const response = await auth.handler(authRequest);
        if (response.body === null) {
          copyResponseHeaders(response.headers, reply);
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
                "session_token",
                "trust_device",
              ]);
              return reply.code(401).send({ error: "invalid_code" });
            }
          }
          copyResponseHeaders(response.headers, reply);
          reply.code(response.status);
          const body = removeSensitiveAuthFields(authBody, config.authSecret);
          return reply.send(body);
        }
        copyResponseHeaders(response.headers, reply);
        reply.code(response.status);
        return reply.send(Buffer.from(await response.arrayBuffer()));
      } catch {
        return reply.code(500).send({ error: "internal_error" });
      }
    },
  });

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
      if (
        !current ||
        Date.now() - current.session.createdAt.getTime() > 5 * 60_000
      ) {
        return reply.code(403).send({ error: "reauthentication_required" });
      }
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
    if (
      !current ||
      Date.now() - current.session.createdAt.getTime() > 5 * 60_000
    ) {
      return reply.code(403).send({ error: "reauthentication_required" });
    }
    await pool.query(`DELETE FROM "session" WHERE "userId" = $1 AND id <> $2`, [
      member.userId,
      current.session.id,
    ]);
    return reply.send({ status: true });
  });

  app.post("/api/account/sessions/revoke-all", async (request, reply) => {
    const member = await requireMember(request, reply);
    if (!member) return reply;
    const current = await resolveSession(auth, request);
    if (
      !current ||
      Date.now() - current.session.createdAt.getTime() > 5 * 60_000
    ) {
      return reply.code(403).send({ error: "reauthentication_required" });
    }
    await pool.query(`DELETE FROM "session" WHERE "userId" = $1`, [
      member.userId,
    ]);
    return reply.send({ status: true });
  });

  await registerWorkspaceRoutes(app, { pool, requireMember });
  return app;
}
