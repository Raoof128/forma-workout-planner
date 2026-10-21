# Hold timer and timed holds release — 22 October 2026

PRs #20–#25 merged into `main` (`c4b3b2b`) and deployed to private staging and
production. Owner-authorised ("I approve the release of PRs #20–#25 … deploy
the API image … to staging and then production … then run
`npm run worker:deploy:staging` and `npm run worker:deploy:production`").

- #20 animated demonstrations in the cards, #21 no weight column for no-load
  exercises and the hold timer, #22 and #24 timed identities for 30 holds,
  #23 "Use the timed version" switch, #25 routine-drag fixes.
- `main`'s tree (`3601f43b…`) is identical to `316c5d9`, the head that #25's
  CI passed and the API image was built from.

## Deployed versions

| Target                                              | Version                                          |
| --------------------------------------------------- | ------------------------------------------------ |
| [Production Worker](https://forma.raoufabedini.dev) | `28ef859c-e665-471f-91cf-e500b52c4826`           |
| Staging Worker                                      | `2b97ab5f-51d2-43fa-a982-fb8b51d22983`           |
| API image (both)                                    | `forma-api:holds-timer-20261022-316c5d9`         |
| Schema (both)                                       | 0006, unchanged (no new migrations)              |
| Previous (rollback)                                 | image `forma-api:workout-coach-20261019-98f853d` |

**Do not roll the API back** once a member has saved one of the new timed
holds: the older image rejects their IDs, so their workspace would stop
loading. Fix forward.

## Procedure

1. Image built on the owner's Mac for `linux/amd64` from a clean `git archive`
   of `316c5d9`; Node 26.11.1, user `forma`, config ID `sha256:923b8a80…8484`.
   Its catalogue holds 1,711 exercises, including the old rep IDs and the new
   `forma-…` timed IDs. Archive SHA-256 `18593834…9773`, re-verified on the
   host.
2. [`api-release.sh`](api-release.sh) ran once per environment as root
   (staging, then production): row counts, encrypted signed backup, the
   one-shot migrate service (no-op), `IMAGE_TAG` switched, API recreated with
   `up -d --no-deps api`, health awaited (with automatic switch-back), second
   backup, counts and unrelated-container comparison.
3. Websites deployed with `npm run worker:deploy:staging` and
   `npm run worker:deploy:production`; each minted and revoked its own
   one-hour token.

### Incident: staging database container recreated with production config

The first production run left out `-p forma-production`. Both environments'
`compose.yaml` begin with `name: forma-staging`, so the migrate step ran as
project `forma-staging` and recreated `forma-staging-db-1` from production's
compose files and `.env`. It kept staging's data volume and network; the
migrator then failed authentication, so nothing was migrated and production
was untouched (its database stayed up). Staging's database was recreated from
its own files within about two minutes (`-p forma-staging`, `small-host`);
staging's API stayed healthy and its row counts were unchanged. The script now
always passes `-p "forma-$ENV"`.

An earlier attempt also stopped after the first backup because the backup
tool's `docker exec` read the rest of the piped script from stdin; both backup
calls now take `< /dev/null`.

## Verification

| Check                                     | Result                                   |
| ----------------------------------------- | ---------------------------------------- |
| Production home                           | 200                                      |
| Live JS                                   | `index-DbISlD_R.js`, matches local build |
| `/api/health`                             | 200                                      |
| `/api/workspace` anonymous                | 401                                      |
| `/api/auth/get-session` anonymous         | 200                                      |
| Unknown API route                         | 404                                      |
| Live bundle has the hold timer and switch | Yes                                      |
| Row counts before and after (both)        | Unchanged                                |
| Unrelated containers (both)               | Unchanged                                |
| API error lines after the switch (both)   | 0                                        |
| Staging                                   | Behind Cloudflare Access (302); healthy  |

Backups: staging `forma-staging-20261021T232828Z` / `…232840Z`, production
`forma-production-20261021T233043Z` / `…233056Z` (UTC). Evidence is on the
host under `/opt/forma-{staging,production}/releases/holds-timer-20261022-316c5d9/`.
