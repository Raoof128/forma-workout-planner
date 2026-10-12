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
  options: { pool: Pool; requireMember: RequireMember },
) {
  const { pool, requireMember } = options;
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

  app.put("/api/workspace", { bodyLimit }, async (request, reply) => {
    const member = await requireMember(request, reply);
    if (!member) return reply;
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
  });
}
