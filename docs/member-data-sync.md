# Member workspace API and conflict handling

The API stores one version 1 FORMA workspace per authenticated Better Auth user
in PostgreSQL. Every workspace query is scoped by the user ID obtained from the
server-validated session. The request body cannot choose an owner. The browser
uses the same-origin `/api/workspace` endpoints; it never connects to PostgreSQL.

`GET /api/workspace` returns `{ data, revision, updatedAt }`. A new account gets
starter routines, an empty workout history, no active workout, and a profile
name derived from the account. The server assigns the authoritative integer
revision and monotonic UTC timestamp.

`PUT /api/workspace` accepts exactly this top-level shape:

```json
{
  "data": { "version": 1 },
  "expectedRevision": 4,
  "operationId": "client-generated-unique-id"
}
```

The abbreviated `data` shown above represents the validated version 1 FORMA
backup shape. PUT validates with the same runtime rules as browser backups,
including duplicate-ID and active/history consistency checks, and accepts at
most 20 MiB of workspace data. A successful response is the committed
`{ data, revision, updatedAt }` acknowledgement. Clients must use that
acknowledgement as the base for their next write.

Writes use optimistic concurrency. If `expectedRevision` is stale, the server
returns HTTP 409 with `error: "stale_revision"` and the latest `data`,
`revision`, and `updatedAt`; the client must present or merge that newer state
before retrying with a new operation ID. Reusing an operation ID with a
different normalized payload returns HTTP 409 with
`error: "operation_id_reused"`. Retrying the same operation ID and payload
returns the original acknowledgement, including its original revision and
timestamp. This makes retries safe after a request times out after commit.

For bounded storage, the idempotency ledger retains the latest 1,000 successful
operations per member and removes entries older than 30 days during writes.
The ledger stores only the request hash and acknowledgement revision/time;
the exact acknowledgement data is reconstructed from the retried payload. If
an acknowledgement has aged out, its old expected revision cannot be applied
again: the client receives a stale-revision conflict and reloads the current
workspace.

`GET /api/workspace/export` returns the authenticated member's validated
workspace as a JSON attachment. Import uses the same PUT path after explicit
confirmation in the interface, so imported ownership fields are ignored and
the authenticated account remains the only database owner. Account deletion
deletes the Better Auth user; foreign-key cascades remove its workspace and
idempotency records.
