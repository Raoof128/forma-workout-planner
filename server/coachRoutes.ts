import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { Pool } from "pg";
import {
  bearerCoachToken,
  coachSummary,
  CoachTokenLimit,
  InvalidCoachTokenLabel,
  isCoachTokenId,
  issueCoachToken,
  listCoachTokens,
  parseSummaryDays,
  resolveCoachToken,
  revokeCoachToken,
} from "./coachTokens.js";
import { consumeBudget, throttleKey } from "./throttle.js";
import { getWorkspace } from "./workspace.js";
import type { RequireMember } from "./workspaceRoutes.js";

/** Failed bearer presentations tolerated per client IP in a 15-minute window. */
export const COACH_FAILURE_LIMIT = 20;
export const COACH_FAILURE_SCOPE = "coach-token-failure";
/** Successful reads allowed per token per hour; a coach polls, it does not stream. */
export const COACH_READ_LIMIT = 120;
export const COACH_READ_SCOPE = "coach-token-read";
/** Minting a credential is a step-up action, like revoking sessions. */
const FRESH_SESSION_MS = 5 * 60 * 1000;

export function registerCoachRoutes(
  app: FastifyInstance,
  options: {
    pool: Pool;
    authSecret: string;
    requireMember: RequireMember;
    /** Resolves the caller's current session creation time, if any. */
    sessionCreatedAt: (request: FastifyRequest) => Promise<Date | null>;
    failureLimit?: number;
    readLimit?: number;
  },
) {
  const {
    pool,
    authSecret,
    requireMember,
    sessionCreatedAt,
    failureLimit = COACH_FAILURE_LIMIT,
    readLimit = COACH_READ_LIMIT,
  } = options;
  const noStore = { "cache-control": "private, no-store, max-age=0" };

  function clientIp(request: FastifyRequest): string {
    const header = request.headers["x-forma-client-ip"];
    const value = Array.isArray(header) ? header[0] : header;
    return value || request.ip;
  }

  async function requireFreshMember(
    request: FastifyRequest,
    reply: FastifyReply,
  ) {
    const member = await requireMember(request, reply);
    if (!member) return null;
    const createdAt = await sessionCreatedAt(request);
    if (!createdAt || Date.now() - createdAt.getTime() > FRESH_SESSION_MS) {
      reply
        .code(403)
        .headers(noStore)
        .send({ error: "reauthentication_required" });
      return null;
    }
    return member;
  }

  // --- Member-session management routes (cookie + member reference) -------

  app.get("/api/account/coach-tokens", async (request, reply) => {
    const member = await requireMember(request, reply);
    if (!member) return reply;
    return reply
      .headers(noStore)
      .send(await listCoachTokens(pool, member.userId));
  });

  app.post("/api/account/coach-tokens", async (request, reply) => {
    const member = await requireFreshMember(request, reply);
    if (!member) return reply;
    const body = request.body;
    if (!body || typeof body !== "object" || Array.isArray(body))
      return reply.code(400).headers(noStore).send({ error: "bad_request" });
    try {
      const issued = await issueCoachToken(
        pool,
        authSecret,
        member.userId,
        (body as { label?: unknown }).label,
      );
      return reply.code(201).headers(noStore).send(issued);
    } catch (error) {
      if (error instanceof InvalidCoachTokenLabel)
        return reply
          .code(400)
          .headers(noStore)
          .send({ error: "invalid_label" });
      if (error instanceof CoachTokenLimit)
        return reply.code(409).headers(noStore).send({ error: "token_limit" });
      throw error;
    }
  });

  app.delete<{ Params: { id: string } }>(
    "/api/account/coach-tokens/:id",
    async (request, reply) => {
      const member = await requireMember(request, reply);
      if (!member) return reply;
      if (!isCoachTokenId(request.params.id))
        return reply
          .code(404)
          .headers(noStore)
          .send({ error: "token_not_found" });
      const revoked = await revokeCoachToken(
        pool,
        member.userId,
        request.params.id,
      );
      if (!revoked)
        return reply
          .code(404)
          .headers(noStore)
          .send({ error: "token_not_found" });
      return reply.headers(noStore).send({ status: true });
    },
  );

  // --- Bearer-token read route (no cookie, no member reference) -----------

  app.get<{ Querystring: Record<string, unknown> }>(
    "/api/coach/workspace",
    async (request, reply) => {
      const ip = clientIp(request);
      const token = bearerCoachToken(request.headers.authorization);
      const days = parseSummaryDays(request.query?.days);
      // Count the failure before the lookup so a flood of guesses is capped
      // whether or not any of them is well-formed.
      const resolved = token
        ? await resolveCoachToken(pool, authSecret, token)
        : null;
      if (!resolved) {
        const allowed = await consumeBudget(
          pool,
          COACH_FAILURE_SCOPE,
          throttleKey(authSecret, COACH_FAILURE_SCOPE, ip),
          failureLimit,
          15 * 60,
        );
        return reply
          .code(allowed ? 401 : 429)
          .headers({
            ...noStore,
            "www-authenticate": 'Bearer realm="forma-coach"',
          })
          .send({ error: allowed ? "unauthorized" : "too_many_attempts" });
      }
      if (days === null)
        return reply.code(400).headers(noStore).send({ error: "invalid_days" });
      const withinBudget = await consumeBudget(
        pool,
        COACH_READ_SCOPE,
        throttleKey(authSecret, COACH_READ_SCOPE, resolved.tokenId),
        readLimit,
        60 * 60,
      );
      if (!withinBudget)
        return reply
          .code(429)
          .headers({ ...noStore, "retry-after": "3600" })
          .send({ error: "rate_limited" });
      try {
        const workspace = await getWorkspace(
          pool,
          resolved.userId,
          resolved.memberName,
        );
        return reply.headers(noStore).send(coachSummary(workspace.data, days));
      } catch {
        return reply
          .code(500)
          .headers(noStore)
          .send({ error: "workspace_unavailable" });
      }
    },
  );
}
