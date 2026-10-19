# Workout editing and full-access coach release — 19 October 2026

Workout editing, fill-remaining-sets, left/right rep logging and full-access
coach tokens from
[PR #14](https://github.com/Raoof128/forma-workout-planner/pull/14), deployed
to private staging and production from `98f853d`. Owner-authorised ("commit
and push and merge and deploy all").

## Deployed versions

| Target                                              | Version                                                                         |
| --------------------------------------------------- | ------------------------------------------------------------------------------- |
| [Production Worker](https://forma.raoufabedini.dev) | `a09aec75-b94d-47a2-b392-e9fa2fc63f1b`                                          |
| Staging Worker                                      | `27deb76c-9af5-4fab-8286-cf31c9af7e73`                                          |
| API image (both)                                    | `forma-api:workout-coach-20261019-98f853d` (Node 26.11.1, UID 10001, amd64)     |
| Schema (both)                                       | 0006 (`0006-coach-token-scope.sql`)                                             |
| Previous (rollback)                                 | Workers `4b87caa9-…` / `712219ca-…`, image `forma-api:signout-20261018-ea2dc4b` |

[Deployment receipt](deployment.json)

Rolling the API back to `signout-20261018-ea2dc4b` is safe with schema 0006:
the older API ignores the `scope` column. It would reject workspaces that
contain `profile.fillSets` or set `sides`, so roll the Worker back first.

## Procedure

1. The first CI run failed at "Build non-root API image": the Dockerfile copies
   an explicit list of shared `src` files and lacked
   `src/catalog/unilateral.json` and `src/catalog/search.js`. Fixed in
   `98f853d`, which also makes CI import every server entry module inside the
   built image.
2. Image built on the owner's Mac for `linux/amd64` from a clean `git archive`
   of `98f853d`; all server modules load inside it. Saved and gzipped
   (SHA-256 `99b20ef6…118f`), copied, checksum re-verified on the host,
   loaded. The host reports the manifest digest (`4e116746…`); the config
   digest is `d2187e78…`.
3. One root-only release script ran per environment (staging, then
   production): row counts, encrypted signed backup, migration 0006 through
   the one-shot migrate service with the new image, the unchanged
   `ops/grant-runtime-access.sql` re-run, `IMAGE_TAG` switched, API recreated
   with `up -d --no-deps api`, health awaited, second backup, row counts and
   unrelated-container comparison.
4. Websites deployed with `npm run worker:deploy:staging` and
   `npm run worker:deploy:production`; each minted and revoked its own
   one-hour token.

Row counts were unchanged in both environments. Production's three existing
coach tokens became `read`, as designed; no token was widened. Evidence is on
the host under `/opt/forma-{staging,production}/releases/workout-coach-20261019/`.

## Verification

| Check                                                          | Result                          |
| -------------------------------------------------------------- | ------------------------------- |
| Home                                                           | 200, `no-transform`             |
| Live JS                                                        | Matches the local account build |
| `/api/health`                                                  | 200                             |
| `/api/workspace` anonymous                                     | 401                             |
| Coach summary, data and exercises without or with a bad token  | 401                             |
| Coach `PATCH` without a token / with a foreign `Origin`        | 401 / 403                       |
| `PUT /api/coach/workspace/data`                                | 405                             |
| `/api/auth/get-session` anonymous                              | 200 `null`                      |
| Unknown API route                                              | 404                             |
| Live guest workout: Edit workout, fill toggle, Left/Right reps | Present; test workout discarded |
| API error logs after the switch                                | None                            |

No live member account was used. The signed-in and coach-token flows are
covered by the PR's isolated account tests on PostgreSQL 18.4.
