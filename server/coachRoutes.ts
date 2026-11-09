import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { Pool } from "pg";
import {
  bearerCoachToken,
  coachSummary,
  assertCoachTokenActive,
  CoachTokenInactive,
  CoachTokenLimit,
  InvalidCoachTokenLabel,
  InvalidCoachTokenScope,
  isCoachTokenId,
  issueCoachToken,
  listCoachTokens,
  normaliseCoachLabel,
  normaliseCoachScope,
  parseSummaryDays,
  resolveCoachToken,
  revokeCoachToken,
  touchCoachToken,
} from "./coachTokens.js";
import type { CoachScope } from "./coachTokens.js";
import { consumeBudget, throttleKey } from "./throttle.js";
import {
  getWorkspace,
  InvalidWorkspace,
  patchWorkspace,
  UnconfirmedActiveRemoval,
  UnconfirmedHistoryRemoval,
  WorkspaceConflict,
} from "./workspace.js";
import type { RequireMember } from "./workspaceRoutes.js";
import { selectableExercises } from "../src/data.js";
import { matchesExercise } from "../src/catalog/search.js";
import { metricFields } from "../src/exerciseMetrics.js";
import { defaultPerSide, sideLabel } from "../src/routineProgramming.js";

/** Failed bearer presentations tolerated per client IP in a 15-minute window. */
export const COACH_FAILURE_LIMIT = 20;
export const COACH_FAILURE_SCOPE = "coach-token-failure";
/** Successful reads allowed per token per hour; a coach polls, it does not stream. */
export const COACH_READ_LIMIT = 120;
export const COACH_READ_SCOPE = "coach-token-read";
/** Edits allowed per full-access token per hour. */
export const COACH_WRITE_LIMIT = 60;
export const COACH_WRITE_SCOPE = "coach-token-write";
/** Edits allowed across all of one member's tokens per hour (cap of five tokens x 60). */
export const COACH_MEMBER_WRITE_LIMIT = 120;
export const COACH_MEMBER_WRITE_SCOPE = "coach-member-write";
/** Well-formed mint attempts per member per hour, refused or not. */
export const COACH_MINT_LIMIT = 10;
export const COACH_MINT_SCOPE = "coach-token-mint";
export const COACH_DATA_PATH = "/api/coach/workspace/data";
const MAX_EXERCISE_RESULTS = 100;
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
    writeLimit?: number;
  },
) {
  const {
    pool,
    authSecret,
    requireMember,
    sessionCreatedAt,
    failureLimit = COACH_FAILURE_LIMIT,
    readLimit = COACH_READ_LIMIT,
    writeLimit = COACH_WRITE_LIMIT,
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
      const label = (body as { label?: unknown }).label;
      const scope = (body as { scope?: unknown }).scope;
      // Only well-formed attempts spend the mint budget; a bad label is a 400.
      normaliseCoachLabel(label);
      normaliseCoachScope(scope);
      if (!(await spend(COACH_MINT_SCOPE, COACH_MINT_LIMIT, member.userId)))
        return rateLimited(reply);
      const issued = await issueCoachToken(
        pool,
        authSecret,
        member.userId,
        label,
        scope,
      );
      return reply.code(201).headers(noStore).send(issued);
    } catch (error) {
      if (error instanceof InvalidCoachTokenLabel)
        return reply
          .code(400)
          .headers(noStore)
          .send({ error: "invalid_label" });
      if (error instanceof InvalidCoachTokenScope)
        return reply
          .code(400)
          .headers(noStore)
          .send({ error: "invalid_scope" });
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

  // --- Bearer-token routes (no cookie, no member reference) --------------

  type Resolved = NonNullable<Awaited<ReturnType<typeof resolveCoachToken>>>;
  const coaches = new WeakMap<FastifyRequest, Resolved>();

  function rateLimited(reply: FastifyReply) {
    return reply
      .code(429)
      .headers({ ...noStore, "retry-after": "3600" })
      .send({ error: "rate_limited" });
  }

  /** Spends one unit of a per-member, one-hour budget. */
  function spend(scope: string, limit: number, userId: string) {
    return consumeBudget(
      pool,
      scope,
      throttleKey(authSecret, scope, userId),
      limit,
      60 * 60,
    );
  }

  /**
   * Authenticates a bearer token, checks its scope, then spends its budgets.
   * Every failure is answered here; null means the reply has been sent. Use is
   * recorded last, so a refused or rate-limited request leaves `last_used_at` alone.
   */
  async function authenticateCoach(
    request: FastifyRequest,
    reply: FastifyReply,
    need: CoachScope,
    budget: { scope: string; limit: number },
    memberBudget?: { scope: string; limit: number },
  ): Promise<Resolved | null> {
    const token = bearerCoachToken(request.headers.authorization);
    // Count the failure before the lookup so a flood of guesses is capped
    // whether or not any of them is well-formed.
    const resolved = token
      ? await resolveCoachToken(pool, authSecret, token)
      : null;
    if (!resolved) {
      const allowed = await consumeBudget(
        pool,
        COACH_FAILURE_SCOPE,
        throttleKey(authSecret, COACH_FAILURE_SCOPE, clientIp(request)),
        failureLimit,
        15 * 60,
      );
      reply
        .code(allowed ? 401 : 429)
        .headers({
          ...noStore,
          "www-authenticate": 'Bearer realm="forma-coach"',
        })
        .send({ error: allowed ? "unauthorized" : "too_many_attempts" });
      return null;
    }
    if (need === "full" && resolved.scope !== "full") {
      reply
        .code(403)
        .headers({
          ...noStore,
          "www-authenticate":
            'Bearer realm="forma-coach", error="insufficient_scope"',
        })
        .send({
          error: "insufficient_scope",
          message:
            "This token is read-only. Create a full-access token in Account › Security to edit.",
        });
      return null;
    }
    const withinBudget = await consumeBudget(
      pool,
      budget.scope,
      throttleKey(authSecret, budget.scope, resolved.tokenId),
      budget.limit,
      60 * 60,
    );
    if (!withinBudget) {
      rateLimited(reply);
      return null;
    }
    if (
      memberBudget &&
      !(await spend(memberBudget.scope, memberBudget.limit, resolved.userId))
    ) {
      rateLimited(reply);
      return null;
    }
    await touchCoachToken(pool, resolved.tokenId);
    return resolved;
  }
  const readBudget = { scope: COACH_READ_SCOPE, limit: readLimit };
  const writeBudget = { scope: COACH_WRITE_SCOPE, limit: writeLimit };
  const memberWriteBudget = {
    scope: COACH_MEMBER_WRITE_SCOPE,
    limit: COACH_MEMBER_WRITE_LIMIT,
  };

  app.get<{ Querystring: Record<string, unknown> }>(
    "/api/coach/workspace",
    async (request, reply) => {
      const days = parseSummaryDays(request.query?.days);
      const resolved = await authenticateCoach(
        request,
        reply,
        "read",
        readBudget,
      );
      if (!resolved) return reply;
      if (days === null)
        return reply.code(400).headers(noStore).send({ error: "invalid_days" });
      try {
        const workspace = await getWorkspace(
          pool,
          resolved.userId,
          resolved.memberName,
        );
        return reply.headers(noStore).send({
          ...coachSummary(workspace.data, days),
          access: resolved.scope,
        });
      } catch {
        return reply
          .code(500)
          .headers(noStore)
          .send({ error: "workspace_unavailable" });
      }
    },
  );

  // Exercise IDs a coach needs to write routines and workouts. Public catalogue
  // data, but still behind a token so the bearer routes stay one model.
  app.get<{ Querystring: Record<string, unknown> }>(
    "/api/coach/exercises",
    async (request, reply) => {
      const resolved = await authenticateCoach(
        request,
        reply,
        "read",
        readBudget,
      );
      if (!resolved) return reply;
      const q = request.query?.q;
      const limitText = request.query?.limit;
      if (
        (q !== undefined && (typeof q !== "string" || q.length > 100)) ||
        (limitText !== undefined &&
          (typeof limitText !== "string" ||
            !/^\d{1,3}$/.test(limitText) ||
            Number(limitText) < 1 ||
            Number(limitText) > MAX_EXERCISE_RESULTS))
      )
        return reply
          .code(400)
          .headers(noStore)
          .send({ error: "invalid_query" });
      const limit = limitText === undefined ? 25 : Number(limitText);
      type CatalogRow = {
        id: string;
        name: string;
        muscle: string;
        equipment: string;
        metric?: string;
      };
      const catalog = selectableExercises as CatalogRow[];
      const matches = catalog.filter((exercise) =>
        typeof q === "string" && q.trim() ? matchesExercise(exercise, q) : true,
      );
      return reply.headers(noStore).send({
        total: matches.length,
        exercises: matches.slice(0, limit).map((exercise) => ({
          id: exercise.id,
          name: exercise.name,
          muscle: exercise.muscle,
          equipment: exercise.equipment,
          metric: exercise.metric ?? "load_reps",
          logs: metricFields(exercise).map((field) => field.key),
          perSideByDefault: defaultPerSide(exercise),
          ...(defaultPerSide(exercise) ? { side: sideLabel(exercise) } : {}),
        })),
      });
    },
  );

  // Full workspace for full-access tokens: everything the app stores for the
  // member, plus the revision a write must name.
  app.get(COACH_DATA_PATH, async (request, reply) => {
    const resolved = await authenticateCoach(
      request,
      reply,
      "full",
      readBudget,
    );
    if (!resolved) return reply;
    try {
      const workspace = await getWorkspace(
        pool,
        resolved.userId,
        resolved.memberName,
      );
      return reply.headers(noStore).send(workspace);
    } catch {
      return reply
        .code(500)
        .headers(noStore)
        .send({ error: "workspace_unavailable" });
    }
  });

  app.patch(
    COACH_DATA_PATH,
    {
      bodyLimit: 20 * 1024 * 1024 + 16 * 1024,
      // Authenticate and spend the budget before Fastify buffers the body.
      async onRequest(request, reply) {
        const resolved = await authenticateCoach(
          request,
          reply,
          "full",
          writeBudget,
          memberWriteBudget,
        );
        if (!resolved) return reply;
        coaches.set(request, resolved);
      },
    },
    async (request, reply) => {
      const resolved = coaches.get(request);
      if (!resolved)
        return reply.code(401).headers(noStore).send({ error: "unauthorized" });
      try {
        // The write path re-checks this token inside its transaction.
        // Re-check the token inside the write transaction: one revoked or
        // expired while this body was uploading cannot commit.
        const saved = await patchWorkspace(
          pool,
          resolved.userId,
          resolved.memberName,
          request.body,
          (client) =>
            assertCoachTokenActive(client, resolved.userId, resolved.tokenId),
        );
        return reply.headers(noStore).send(saved);
      } catch (error) {
        if (error instanceof CoachTokenInactive)
          return reply
            .code(401)
            .headers({
              ...noStore,
              "www-authenticate": 'Bearer realm="forma-coach"',
            })
            .send({ error: "unauthorized" });
        if (error instanceof WorkspaceConflict)
          return reply.code(409).headers(noStore).send({
            error: error.code,
            message: error.message,
            revision: error.latest.revision,
            updatedAt: error.latest.updatedAt,
          });
        if (error instanceof UnconfirmedActiveRemoval)
          return reply.code(400).headers(noStore).send({
            error: "active_removal_unconfirmed",
            message: error.message,
          });
        if (error instanceof UnconfirmedHistoryRemoval)
          return reply.code(400).headers(noStore).send({
            error: "history_removal_unconfirmed",
            message: error.message,
            removedSessions: error.removed,
          });
        if (error instanceof InvalidWorkspace)
          return reply.code(400).headers(noStore).send({
            error: "invalid_workspace",
            message: error.message,
            issues: error.issues,
          });
        return reply
          .code(500)
          .headers(noStore)
          .send({ error: "workspace_unavailable" });
      }
    },
  );
}
