# FORMA account implementation plan

Execute the owner's supplied architecture using independent specialists with explicit file ownership. Shared root dependency manifests, integration scripts and final reports are orchestrator-owned. Final critical review must be independent of each implementation owner.

1. Verify the audited baseline; retrieve official API documentation and inspect installed package versions. Preserve the previous release findings.
2. Luna B: `server/auth.ts`, `app.ts`, config/email modules and identity SQL; implement Better Auth session, email, TOTP and lifecycle tests.
3. Luna C: `server/workspace.ts`, routes/schema/migrations; validate owner-scoped JSONB, transactional revisions and operation-ledger idempotency against real PostgreSQL.
4. Luna D: `worker/index.ts`, Wrangler and `ops/`; test fixed-origin proxy security and provide private deployment, encrypted backup and restore procedures.
5. Luna E: account provider/client/cloud repository and App/navigation integration; gate private rendering, isolate account changes and implement acknowledged saves and explicit migration.
6. Luna A: Account component/styles/control inventory; connect every account/security/data action to real services and match FORMA's visual identity.
7. Luna F: independent security/API/browser suite; exercise two-member attacks, account lifecycle, cross-context synchronization and failure feedback against real integration services.
8. Root: pinned dependency installation, TypeScript/lint/build integration, disposable PostgreSQL, test/email harness, original regression suite, backup restore, documentation and CI.
9. After implementation, assign fresh Astra independent review. Reproduce and repair findings, run final checks on the proposed candidate and record exact results and external blockers.
10. Commit on `feature/self-hosted-accounts`, push and prepare a draft PR. Do not merge or deploy production. Staging execution is conditional on available authorized infrastructure details.

## Contracts

- `createApp({pool,config,email?})` constructs a testable Fastify app.
- Domain registration: `registerWorkspaceRoutes(app,{pool,requireMember})` with identity resolved exclusively from Better Auth.
- `GET /api/workspace` returns `{data,revision,updatedAt}`; `PUT` accepts only `{data,expectedRevision,operationId}`; `GET /api/workspace/export` returns a backup.
- Frontend `useAccount()` distinguishes loading, guest, authenticated and error. Account receives `{account,workspace,onNavigate,notify}`.
- Account repository serializes commits, uses server acknowledgement, isolates epochs and exposes explicit refresh/conflict recovery.
- Root test harness binds API 3001 and development UI 5175 to loopback; any email test control is isolated on a separate loopback-only listener and never included in the production app.
