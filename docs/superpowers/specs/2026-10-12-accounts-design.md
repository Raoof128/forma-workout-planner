# FORMA self-hosted accounts design

The owner supplied a complete implementation brief and explicitly authorized execution, specialist delegation, commits and a draft pull request. This phase builds on audited commit `86cfddad922eea6fb54de344c3b7a045c94f0ce8`; its unresolved release findings remain historical evidence. Production deployment and live credential rotation require separate authorization.

## Boundaries

The browser uses the existing React/Vite frontend and same-origin `/api/*`. A Cloudflare Worker serves static assets and proxies only approved API routes to a fixed HTTPS Tunnel hostname protected by Access Service Auth. The Worker strips caller service/identity headers and attaches its own service credentials plus an independent backend shared secret. The private Node/Fastify service authenticates the member with Better Auth before accessing PostgreSQL. The database and origin have no public inbound listeners. A VPC-only Droplet requires verified outbound routing/NAT for Tunnel, email, patching and backups. Workers VPC remains an optional alternative requiring independent availability review, not a baseline dependency.

## Identity and private state

Better Auth owns credentials, verified email, sessions, reset tokens and TOTP. Minimum password length is 15; host-only HttpOnly cookies, exact trusted origin, no session cookie cache, recent authentication for sensitive operations, rate limits and server-side revocation form the baseline. An HTTPS transactional email adapter is separate from identity storage. Local tests use an explicit in-process email sink; production refuses it.

Guest browser storage remains supported. Member data is never persisted in localStorage. Authentication bootstrap gates private rendering; session/account transitions cancel stale requests and remount workspace state. Account settings expose real library-backed operations and real persisted training metrics. Initials avatars avoid introducing an unnecessary upload attack surface.

## Workspace ADR

Choose normalized identity/session tables plus a validated, versioned owner-keyed JSONB workspace. The existing v1 backup contract is an atomic aggregate of routines, history, active workout, profile and schedule; preserving it avoids lossy conversion and keeps existing validation/calculations usable. Every read and mutation derives owner identity from the verified server session. Member-local embedded IDs cannot address another member's workspace. There are no cross-owner record lookup routes.

Writes use a database transaction, expected revision and operation ID. Repeating the same ID and payload returns the prior acknowledgement; a reused ID with a changed payload fails. Conflicting revisions return 409 with current state; the client never silently overwrites it. The tradeoff is whole-workspace transfer and contention, acceptable for the current bounded product but requiring measurement before larger-scale use. No claim of database RLS is made unless its role and pooling semantics are implemented and tested; ownership predicates and foreign keys are mandatory.

## Migration and online-first behavior

Import is an explicit informed action, with counts, a recoverable copy and acknowledgement/refetch checks. Local guest data is retained. Existing cloud data is kept unless the member confirms replacement; no silent account attachment or merge-by-ID. Import validates schema, duplicates and byte limits. Online-first member editing exposes saving, offline, conflict and retry states; no durable offline queue is promised. Ambiguous network failures retry the same operation rather than manufacture a second workout.

## Verification and deployment

Run real PostgreSQL and Better Auth integrations, adversarial two-member tests, concurrent CAS/idempotency tests, actual backup/isolated restore, Worker transport tests, and browser workflows. Retain the original guest suite. Cloudflare/Droplet staging needs the owner's existing bindings and hostnames, requested while independent local work continues. Missing real email/staging results remain BLOCKED. The final handoff must distinguish tested artifacts from deployment configuration and cannot declare GO with an unresolved mandatory gate.
