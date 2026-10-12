import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { Pool } from "pg";
import {
  getWorkspace,
  InvalidWorkspace,
  putWorkspace,
  WorkspaceConflict,
} from "./workspace.js";

export type MemberIdentity = {
  userId: string;
  name?: string;
  email?: string;
};

export type RequireMember = (
  request: FastifyRequest,
  reply: FastifyReply,
) => Promise<MemberIdentity | null>;

export function registerWorkspaceRoutes(
  app: FastifyInstance,
  options: {
    pool: Pool;
    requireMember: RequireMember;
    /** Per-member write budget; resolves false when the member is over it. */
    allowWrite?: (userId: string) => Promise<boolean>;
  },
) {
  const { pool, requireMember, allowWrite } = options;
  const noStore = { "cache-control": "private, no-store, max-age=0" };
  const bodyLimit = 20 * 1024 * 1024 + 16 * 1024;

  app.get("/api/workspace", async (request, reply) => {
    const member = await requireMember(request, reply);
    if (!member) return reply;
    try {
      const workspace = await getWorkspace(pool, member.userId, member.name);
      return reply.headers(noStore).send(workspace);
    } catch {
      return reply
        .code(500)
        .headers(noStore)
        .send({ error: "workspace_unavailable" });
    }
  });

  app.get("/api/workspace/export", async (request, reply) => {
    const member = await requireMember(request, reply);
    if (!member) return reply;
    try {
      const workspace = await getWorkspace(pool, member.userId, member.name);
      return (
        reply
          .headers({
            ...noStore,
            "content-type": "application/json; charset=utf-8",
            "content-disposition": 'attachment; filename="forma-backup.json"',
          })
          // Keep a valid near-limit workspace within the gateway's wire limit.
          .send(JSON.stringify(workspace.data))
      );
    } catch {
      return reply
        .code(500)
        .headers(noStore)
        .send({ error: "workspace_unavailable" });
    }
  });

  const writers = new WeakMap<FastifyRequest, MemberIdentity>();
  app.put(
    "/api/workspace",
    {
      bodyLimit,
      // Authenticate and spend the write budget before Fastify buffers and
      // parses up to 20 MiB, so anonymous or throttled callers cost little.
      async onRequest(request, reply) {
        const member = await requireMember(request, reply);
        if (!member) return reply;
        try {
          if (allowWrite && !(await allowWrite(member.userId))) {
            return reply
              .code(429)
              .headers({ ...noStore, "retry-after": "60" })
              .send({
                error: "rate_limited",
                message:
                  "Too many saves in a short time. Try again in a minute.",
              });
          }
        } catch {
          return reply
            .code(503)
            .headers(noStore)
            .send({ error: "workspace_unavailable" });
        }
        writers.set(request, member);
      },
    },
    async (request, reply) => {
      const member = writers.get(request);
      if (!member)
        return reply.code(401).headers(noStore).send({ error: "unauthorized" });
      try {
        const acknowledgement = await putWorkspace(
          pool,
          member.userId,
          member.name,
          request.body,
        );
        return reply.headers(noStore).send(acknowledgement);
      } catch (error) {
        if (error instanceof WorkspaceConflict) {
          return reply
            .code(409)
            .headers(noStore)
            .send({
              error: error.code,
              message: error.message,
              ...error.latest,
            });
        }
        if (error instanceof InvalidWorkspace) {
          return reply
            .code(400)
            .headers(noStore)
            .send({ error: "invalid_workspace", message: error.message });
        }
        return reply
          .code(500)
          .headers(noStore)
          .send({ error: "workspace_unavailable" });
      }
    },
  );
}
