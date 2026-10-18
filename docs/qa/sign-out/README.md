# Sign-out release — 18 October 2026

Session sign-out fixes and the sidebar account menu from
[PR #11](https://github.com/Raoof128/forma-workout-planner/pull/11), deployed
to private staging and production. Merged tree `746fdf8` (identical to the
image source `ea2dc4b`). Owner-authorised; the owner asked to merge without
waiting for the "Verify application" CI job, which was still running.

## Deployed versions

| Target                                              | Version                                                               |
| --------------------------------------------------- | --------------------------------------------------------------------- |
| [Production Worker](https://forma.raoufabedini.dev) | `4b87caa9-25ff-4181-b298-1d795e518301`                                |
| Staging Worker                                      | `712219ca-42b0-4b6c-8324-7dc520c77956`                                |
| API image (both)                                    | `forma-api:signout-20261018-ea2dc4b` (Node 26.11.1, UID 10001, amd64) |
| Previous production (rollback)                      | Worker `4005f27c-…`, image `forma-api:coach-20261018-a831507`         |
| Previous staging (rollback)                         | image `forma-api:routine-v2-20261017-cca9b07`                         |

[Deployment receipt](deployment.json)

## Procedure

1. Image built on the owner's Mac for `linux/amd64` from a clean `git archive`
   of `ea2dc4b`, saved and gzipped (SHA-256 `8e843c29…5965`), copied, checksum
   re-verified on the host and loaded. The archive holds both the config
   digest (`80b40600…`) and the manifest digest the host reports (`7eba2e8b…`).
2. **Staging:** encrypted, signed backup; `0005-coach-tokens.sql` applied by
   the migrate service (staging had stayed on 0004); the current
   `ops/grant-runtime-access.sql` installed and run; `IMAGE_TAG` switched and
   the API recreated; healthy; post-release backup. Website deployed with
   `npm run worker:deploy:staging`.
3. **Production:** schema and grants were already current. Encrypted, signed
   backup; `IMAGE_TAG` switched; API recreated; healthy; post-release backup.
   Website deployed with `npm run worker:deploy:production`.
4. Both website deploys minted and revoked their own one-hour token.

Row counts were unchanged across each release, and the seven unrelated
containers on the shared host kept the same IDs. Evidence is on the host under
`/opt/forma-{staging,production}/releases/sign-out-20261018/`.

## Verification

| Check                                                 | Result                         |
| ----------------------------------------------------- | ------------------------------ |
| Home                                                  | 200, `no-transform`, no beacon |
| Live JS/CSS                                           | Match the local account build  |
| `/api/health`                                         | 200                            |
| `/api/workspace`, `/api/coach/workspace` anonymous    | 401 / 401                      |
| `/api/auth/get-session` anonymous                     | 200 `null`                     |
| Unknown API route                                     | 404                            |
| `revoke-all`, `revoke-others` anonymous with password | 401 / 401                      |
| Staging anonymous                                     | 302 (Cloudflare Access)        |
| Live guest site, desktop and phone                    | Loads, no page errors          |

No live member account was created; the signed-in flows are covered by the
PR's isolated account tests.
