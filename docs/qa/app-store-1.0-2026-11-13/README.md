# App Store 1.0 preparation release — 13 November 2026

The owner authorised merging PR #48 and releasing its API and website to
staging and then production, so the back end accepts what the iOS 1.0 build
sends before that build goes to App Review. Nothing was uploaded to App Store
Connect.

## Source

| Item              | Value                                                                   |
| ----------------- | ----------------------------------------------------------------------- |
| Merge             | PR #48 into `main` as `3a2f2fc`; tree identical to the tested `b659ad6` |
| API image source  | `191b4a7` (later commits changed CI configuration and logs only)        |
| API image         | `forma-api:app-store-20261113-191b4a7`, `linux/amd64`, Node 26.12.1     |
| Previous image    | `forma-api:reconcile-20261109-8d0244e` (kept on the host for rollback)  |
| Schema migrations | None new; the migration step ran as a no-op in both environments        |

API inputs changed since the previous image: `src/storage.js` accepts an Apple
Watch summary on a finished workout, and `server/app.ts` and
`server/coachRoutes.ts` let an older sign-in confirm its password in place when
creating a coach token.

## CI

- `191b4a7`: Native iOS passed. Both Verify runs passed every step they
  reached and were cancelled at the 70-minute job limit inside the last
  browser suite. Not counted as a pass.
- `b659ad6` (limit raised to 100 minutes): Verify passed twice (push and pull
  request, about 52 minutes each), Native iOS passed, security scans passed.
- An earlier run on `8b9b255` failed two tests that were out of step with the
  merged code; the 13 November log entries describe both fixes.

## Release

| Step                     | Staging                                | Production                             |
| ------------------------ | -------------------------------------- | -------------------------------------- |
| Archive checksum on host | verified                               | verified                               |
| Backup before            | `forma-staging-20261113T012308Z`       | `forma-production-20261113T012431Z`    |
| Migration                | no-op                                  | no-op                                  |
| API after switch         | healthy, 0 restarts, 0 error lines     | healthy, 0 restarts, 0 error lines     |
| Backup after             | `forma-staging-20261113T012326Z`       | `forma-production-20261113T012445Z`    |
| Row counts               | unchanged                              | unchanged                              |
| Other containers         | unchanged                              | unchanged                              |
| Host monitor             | healthy, no signals                    | healthy, no signals                    |
| Worker version           | `ee035d14-35f4-4f58-b9f1-eae7ebf6846c` | `70447239-794c-4372-82f7-0cb3c1de4294` |

Each backup reported an encrypted off-host upload with its signature. The
deploy helper revoked its one-hour token after each Worker upload.

## Verification

- **Running code, both environments:** a script run inside each API container
  imported the deployed `storage.js` and confirmed it accepts a workspace whose
  finished workout carries a Watch summary and rejects a heart rate above the
  bound. It wrote nothing.
- **Production over HTTPS, anonymous:** the page and both emitted assets match
  the local build byte for byte; `/api/health` 200; `/api/workspace` 401; an
  unknown API route 404; the session endpoint returns null; the
  app-site-association file is served as JSON; security headers present.
- **Staging over HTTPS:** anonymous requests receive the Cloudflare Access
  redirect, as intended.

## Not done

- No signed-in journey was run against staging or production, and no temporary
  Access policy was created to do so. The account browser suites ran in CI
  against an isolated database only.
- No restore drill, mail delivery test or alert test.
- The Apple Watch workout, Health save and Live Activity still need a
  hands-on pass on the owner's devices; see
  [the submission checklist](../../../ios/docs/app-store-submission.md).

## Rollback

Set `IMAGE_TAG=reconcile-20261109-8d0244e` in the environment's host `.env` and
recreate only `api`. Do not roll back once a member has synced a workout with a
Watch summary: the older image rejects that field and the workspace stops
loading. Fix forward instead.
