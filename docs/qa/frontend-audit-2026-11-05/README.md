# Frontend audit release — 5 November 2026

The owner authorized fixing confirmed issues, committing/pushing and redeploying the configured FORMA services. The corrected account website is live on [production](https://forma.raoufabedini.dev) and [staging](https://forma-staging.raoufabedini.dev), with both private APIs updated. The operations dashboard and scheduled edge monitor were also redeployed. Final read-only postflight confirms the expected versions, healthy backends and private boundaries.

## Source and correction

The initial audit/evidence checkpoint `21270818ec28073acf96fd800e500527fccb628c` passed [CI 41855617331](https://github.com/Raoof128/forma-workout-planner/actions/runs/41855617331): 1,394 executions, including 1,115 browser executions, with zero failures or skips. Its [receipt](evidence/ci-initial-2127081.json) preserves the actual commands, versions and scanner qualifications. The earlier [complete audit](../../audits/forma-web-frontend-2026-11/FINAL_REPORT.md) remains evidence for its recorded source and testing window.

Live staging inspection then found a small additional readability fault: at 320 px, the decorative F painted over two lines of the account introduction. Commit `af8f476420e2e4451c03ae0537e936eba457c2c7` reserves paragraph space only at widths through 540 px. It retains the full copy, emblem, headline and controls. The new regression measures loaded-font text-line rectangles against the actual emblem at six widths. All five profiles reproduced the fault; focused follow-up passed 5/5 and the complete account-design suite passed 40/40. Lint, formatting, types, documentation and staged secret/whitespace checks passed. [CI 41906385541](https://github.com/Raoof128/forma-workout-planner/actions/runs/41906385541) passed the corrected source: **1,404 executions, zero failures/skips/interruption**. Its actual browser totals are 540 guest development, 175 production smoke, 205 account development and 205 production-built account checks; the remaining 279 are unit, Worker, PostgreSQL and operational executions. See the [completed CI receipt](evidence/ci-correction-af8f476.json) and [local regression receipt](evidence/local-regression.json). Repeated profiles and focused reruns are counted as executions.

Only `src/account.css`, the regression test and the two project logs changed in that correction. Backend build inputs remain identical to `2127081`; its verified API image is reused. There are no new dependencies or SQL migrations, and no authentication, workspace schema, historical exercise ID or unit changes.

## Deployment and preservation

| Surface                | Verified version or state                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------------------------- |
| Staging API            | `forma-api:frontend-audit-20261105-2127081`; healthy, UID 10001, Node 26.12.1                           |
| Staging website        | `98eecbb4-4c5e-49ad-9e9d-7d062f9c252c`; corrected `af8f476` account build                               |
| Production API         | `forma-api:frontend-audit-20261105-2127081`; healthy, UID 10001, Node 26.12.1                           |
| Production website     | `3a5980c7-d697-49b0-bd23-d4a5cd808631`; corrected `af8f476` account build                               |
| Operations dashboard   | `e3cee2fb-f50a-46f4-934f-38316d6e7617`; anonymous requests return Cloudflare Access 302                 |
| Scheduled edge monitor | `332a451b-383a-4860-9dec-fd1e024736e1`; original five-minute schedule, KV and backup bindings preserved |

The API archive's configuration digest is `sha256:aface4c8001110e1964ea28961adf032520d592e11aa89e1dd875f7535c238e2`; all ten layer hashes/diff IDs and the configuration hash were verified before transfer. The loaded host image reports OCI identity `sha256:a59ce84f37303cd459ba86086a602cafaa11741ac9d7a37e234df314150b630b`. Configuration and layer checks reconcile these identifiers; they are not interchangeable digest types.

Each API update made fresh encrypted off-host backups before and after replacement, for four verified release backups across staging and production. Uploaded ciphertext checksums and Ed25519 signatures were verified against the repository-pinned public key. This was not a new decryption/restore drill. Only the selected API was recreated, preserving the actual host overrides, private ports, resource policy and all unrelated container IDs. Secrets and row counts were unchanged. See the [staging API receipt](evidence/staging-api.json), [production API receipt](evidence/production-api.json) and [final live postflight](evidence/final-live-postflight.json). The earlier [host preflight](evidence/host-preflight.json) remains a separate read-only snapshot.

Host monitoring scripts and Tunnel readiness configuration already matched current source and needed no rewrite. Both existing connectors returned readiness 200. The [edge monitor receipt](evidence/edge-monitor.json) records a normal scheduled healthy check with zero failures/signals; no alert or email test was forced.

## Hosted verification and visual evidence

The corrected staging website passed [44 HTTPS checks](evidence/staging-http.json), and production independently passed [44/44](evidence/production-http.json), including exact HTML/all four emitted asset hashes, API health, anonymous workspace/export denial, unknown-route denial, bearer challenge, null anonymous session, no-store and security headers. The [account build identity](evidence/account-build.json) records all five emitted file hashes. A [final anonymous public confirmation](evidence/final-public-confirmation.json) at 23:13 UTC passed all nine checks: five exact production file hashes, API health, anonymous workspace denial and protected staging/dashboard entry.

An immediate first post-upload probe passed 40/44, with four asset-hash mismatches. The unchanged repeat passed 44/44, followed by an independent byte check of all five files; no redeployment, source/configuration change or weakened assertion occurred between probes. The retained [first receipt](evidence/staging-first-probe.json) is consistent with activation timing, but the provider mechanism was not established.

The [browser evidence](evidence/browser/README.md) contains **63 screenshots**: 21 public BEFORE, 21 corrected staging and 21 production AFTER captures at 320, 390 and 1440 px. The [local comparison viewer](evidence/browser/comparison.html) presents 21 actual production before/after pairs. Seven frames per width cover sign-in, signup, reset, Overview, Library, Progress and Privacy. All three phases have no attempted member writes, page/console/HTTP errors or overflow. Each Library capture waited for 24 decoded thumbnails; background photos and local fonts were checked. Staging and production each additionally passed the six live text/emblem geometry checks, with loaded fonts, complete copy and controls within viewport bounds. The corrected 320 px copy is visibly clear of the emblem.

The public BEFORE phase records its observed Worker version and actual asset hashes. Its frontend Git source is not inferred from the previous backend image tag. The initial disk interruption after 18 captures and subsequent three-frame continuation remain separate history. Local Docker was started for the image build and gracefully stopped with zero running containers, preserving all images and volumes; no project data or evidence was deleted to resolve the temporary disk pressure.

## Access, rollback and limits

Each Worker deployment uses a one-hour scoped token and revokes it after the command. The temporary staging Service Auth policy, service credential and scoped Access API token are removed, with existing policies preserved; [cleanup verification](evidence/access-cleanup.json) confirms this. Staging and the dashboard still deny anonymous entry through Cloudflare Access. Original configuration/secrets, database volumes and previous API images/Worker versions are retained for rollback.

These hosted checks use fresh anonymous contexts and GET/HEAD/OPTIONS without account creation, login, email or production-member writes. They do not establish a new authenticated member lifecycle, inbox delivery, restore drill, sustained-load/field performance or accessibility-conformance result. Owner-authenticated dashboard rendering was not repeated.

## Physical iPhone Verification

The earlier native audit used the authorized Raouf iPhone Air and a deliberately isolated development bundle. Its signed baseline/final builds passed in 38.889/37.952 seconds; 164 tests passed, two personal-device safety checks were intentionally skipped, and three additional Light tours passed. It preserves 32 matched Light/Dark screenshot pairs. Actual native projection samples averaged 20.188→19.926 ms; the four-tab XCTest clock averaged 5.712→5.749 seconds including driver overhead. App CPU samples averaged 1.472→1.493 seconds; absolute physical memory averaged 80,155.717→80,018.067 kB, five samples per build. Launch samples were incomplete; no speedup, thermal, energy or leak conclusion follows. These are the prior native audit's results, not a newly repeated native suite or physical Safari benchmark. See the [actual builds, screenshots, CPU/memory and limits](../../../ios/docs/audits/native-frontend-2026-11/PHYSICAL_IPHONE_VERIFICATION.md).

The current release's physical Safari check is still being completed. Device setup attempts, the owner's explicit approval for Safari testing settings, the isolated UI diagnostic and actual final browser outcome will be recorded separately before this report is finalized.

Simulator: no new iOS Simulator UI journey completed. The website browser matrices ran in desktop engines and phone emulation; the earlier native report identifies the stalled Simulator attempt separately from actual iPhone tests.

App Store/TestFlight distribution, physical Watch/Health, minimum-OS runtime and the remaining native privacy/release gates are unverified; no Store build was uploaded or distributed.

For future maintenance, follow [deployment](../../deployment.md): verify the current backup and rollback identities, release the API before its matching website, and verify staging before production. Use the protected local deployment binding and SSH key; never copy its values into Vite, Git, screenshots or logs.
