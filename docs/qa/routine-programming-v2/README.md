# Routine programming v2 release — 17 October 2026

The owner requested full testing, commit, push and redeployment of all routine
programming changes in [PR #9](https://github.com/Raoof128/forma-workout-planner/pull/9).
Initial implementation/packaging source is `c491889`. The release also preserves
the live archive contract discovered during production validation.
See the [feature and migration contract](../../routine-programming-v2.md).

## Verification

| Check | Result |
| --- | --- |
| Unit | 89 passed |
| Real PostgreSQL API | 49 passed, repeated under Node 26 |
| Worker gateway | 21 passed |
| Operations | 14 passed |
| Development browsers | 348 unique cases, 116 per engine |
| Production guest browsers | 70 unique passed across five desktop/phone projects |
| Real account browsers | 55 passed across five desktop/phone projects |
| Production-built real account browsers | 55 passed across five projects |
| Lint, formatting, types, docs, frontend/server builds | Passed |
| Equipment audit / strict artwork coverage | Passed; 1,411 selectable exercises |
| Pinned deployment image | Node 26.11.1, UID 10001; read-only runtime smoke passed |

The development result includes exact replays after a test-server exit and one
isolated Firefox performance replay: 4.4 seconds against the unchanged 10-second
bound. The original failures and traces remain in ignored local evidence; test
assertions were not weakened. The account matrices used a 60-second CLI test
budget in the shared cloud environment. Test databases and email sinks are
isolated; no live member identity or email delivery is implied by those suites.

CI initially failed because `ops/Dockerfile.dockerignore` omitted the new routine
helper and alias JSON, despite their Dockerfile COPY instructions. The packaging
commit adds both explicit inclusions. The actual pinned image then built and
validated the compiled v2 schema and all selectable exercises.

## Image identity

| Artifact | SHA-256 |
| --- | --- |
| Compressed transfer archive | `1e8178e26be5678daef2db216efaf88b28e0c8b49ca7ae432f3bb728b01b5158` |
| Image configuration | `55a726adcc06c8b6cca1bd077c8921038167fe7c821faf81eb5e9bfa00a5b294` |
| OCI manifest reported by the host | `6a7a39f4bd1cba4f1d14445ef481f237d3c96e5cf459be1b6b64a5fe14544911` |

The host archive checksum matches the local artifact. Its OCI index names the
same manifest digest reported by the host. Both image digest forms are retained
because the two Docker versions report different identity fields.

## Staging rollout

The existing private project took verified encrypted and signed off-host backups
before and after migration. Old API writers were paused during migration 0004;
a second migration-runner invocation completed cleanly. Workspace, routine,
history and active-session counts matched, and every stored workspace passed the
compiled API v2 validator on the host. Member rows stayed on the host.

The matching API was deployed before the account frontend. Its existing 320 MiB
limit and private ports were preserved. Worker version:
`7123f2ae-d9c9-4934-9f35-28d3f032d88d`. The helper revoked its one-hour deploy token.

Hosted staging passed all 12 programming journeys: Chromium desktop/phone and
WebKit phone. They cover range/RPE/note targets, supersets and automatic rest,
reload persistence, duplicate independence, drag/arrow reordering and first-load
alias migration. Temporary Access smoke policies and credentials were removed.

Initial hosted runs found test assumptions about a transitional heading, desktop
card separators and desktop timer visibility. The tests now select the active
h1, support the responsive label and open the phone's timer panel. The production
matrix includes all four programming cases across its five projects. No runtime
application change or assertion weakening was needed. Firefox's hosted attempt
failed at the managed proxy's certificate trust; it remains covered by the local
and CI production matrices. Certificate verification was not disabled.

Production rollout and final CI are in progress.

## Legacy archive compatibility correction

The production pre-frontend validation rejected existing bounded `archivedAt`
routine timestamps. SQL 0004 had preserved them. API writes were paused while the
strict schema and archive/restore UI compatibility were restored; no applied SQL
was changed, no timestamp cleared and no member data exported. The corrected
image validates every production workspace on the host.

The new archive regression starts with every routine archived, edits a rep range,
reloads, restores, archives and duplicates while checking the original timestamp
and active copy. The schema regression failed before the fix. All 89 unit, 49 API
(including Node 26) and 15 focused development cases pass. The production matrix
passed 68 cases; two phone duplication failures identified a persistent disclosure
covering the card. After closing disclosures on action selection, all 25
programming/archive cases across five profiles pass, completing all 70 unique
production cases. Failed evidence was retained and assertions were not weakened.

Concurrent development runs emitted two React render-phase console warnings with
no caller stack. Four isolated concurrent exact-flow WebKit replays passed without
the warnings. The independent review found no Critical or Important issue and no
evidence supporting a speculative runtime change. These are retained development
observations, not claimed clean-console results.
