# Test results

The implementation checkpoint includes the last confirmed Skip-after-retry correction. The later 540-case guest attempt stopped with 271 passes, one test-readiness failure, one interruption and 267 unrun before that correction. Its unchanged data assertion now follows an explicit ready-heading wait and passes across three engines. Complete current-source CI and local account matrices remain pending; no full current pass is claimed.

## Environment and isolation

Apple Silicon macOS; Node 24.21.0, npm 11.19.0, Playwright 1.64.1, pinned Chromium 156.0.8078.4, Firefox 157 and WebKit 27.2. Mobile projects are emulations, not physical Safari. The exact production Node 26.12.1 runtime was not installed.

Earlier PostgreSQL checks used the pinned disposable 18.4 Docker image. Repeated Docker precondition failures led to the existing PostgreSQL 18.6 binary with a new private temporary cluster and socket on loopback port 55440. No existing database, global service or configuration changed. All three database test variables point to that same isolated database. Synthetic accounts, per-run schemas and local mail prevent production-member mutations. The [final server receipt](evidence/POSTGRESQL_FINAL.json) includes matching source hashes.

Browser measurements and functional matrices use separate windows. Final guest checks use one worker and zero retries. Existing assertions and timeouts are retained. In the security spec, continuous trace-filmstrip screenshots alone are disabled; DOM/network/source traces and independent failure screenshots remain. The complete unchanged security journey passed in 20.873 seconds under its original 30-second limit before that narrow setting was applied.

## Required commands and current results

| Command/check | Actual outcome |
| --- | --- |
| `npm ci` | Passed, 408 packages; dependency pins and lockfile unchanged. |
| `npm run lint`, `npm run format:check`, `npm run typecheck` | Full batch passed; later changed CSS/tests also passed scoped formatting/lint. The all-file repeat after the last App/test change passed, including documentation checks for 166 Markdown files. |
| `npm run test:unit` | 151 passed; zero failed, skipped or cancelled; 5.444 seconds. |
| `npm run test:worker` | 35 passed; zero failed, skipped or cancelled; 30.214 seconds. |
| `npm run test:server` | Final 77 passed on private PostgreSQL 18.6; zero failed, skipped or cancelled; 29.076 seconds. Earlier final 77 also passed on 18.4. |
| `VITE_ACCOUNT_MODE=guest npm run build -- --outDir /tmp/forma-web-final-guest-dist-20261104 --emptyOutDir` | Passed. Clean entry HTML and emitted assets are byte-identical to the final measured build. Existing large-chunk warning remains. |
| `npm run test:browser -- --workers=1 --reporter=line,json` | Stopped: 271 passed, one failed readiness check, one interrupted, 267 unrun. Final current-source CI planned. |
| `npm run test:browser:production -- --workers=1 --reporter=line,json` | Final five-project run pending. |
| `npm run test:accounts -- --project=accounts-webkit` | Full final 40-case profile pending after the Docker server-start attempt executed zero tests. |
| `npm run test:accounts` | Final five-profile, 200-case development run pending. |
| `npm run test:accounts:production` | Final five-profile, 200-case built run pending. |
| `npm run docs:check`, `git diff --check`, staged secret scan | Interim docs/whitespace checks pass; final checks follow final reports. |

The guest runs additionally set `PLAYWRIGHT_BROWSERS_PATH` to the audit-owned pinned browser cache. The final development run reuses the explicitly started loopback guest Vite server with empty API proxy/secret. `PLAYWRIGHT_JSON_OUTPUT_FILE` preserves a private raw result alongside the line log. Production uses the existing repository build/preview command. Exact final raw counts and hashes are consolidated in [verification evidence](evidence/VERIFICATION_RESULTS.json).

## Reproductions and focused checks

| Check | Actual outcome |
| --- | --- |
| Original editor/order faults | Six controlled failures. |
| Final editor/order checks | 18 passed across Chromium, Firefox and WebKit, 31.2 seconds. |
| Profile drafts, read/write retry and explicit conflict reload | 15 passed across three engines, 42.1 seconds; both baseline and intermediate follow-up faults were reproduced before correction. |
| Existing WebKit focus cases | Original frozen source failed all six. Volatile keyboard mode alone passed one and left five failures. Final product passed all six unchanged assertions in 23.1 seconds. |
| Original Firefox workflow alone | Passed unchanged in 8.5 seconds, 12.6 seconds including runner overhead. |
| Hold owner/numeric regressions | 21 passed across three engines, 1.5 minutes. An explicit vibration-count assertion was then added to the five hold cases; the final 540-case run verifies that stronger version. |
| Narrow Security actions | New regression reproduced overflow; final five browser profiles passed in 56.1 seconds. |
| Tablet auth forms | New internal-bound regression reproduced clipping; final five profiles passed in 41.8 seconds, each checking three modes at three widths. |
| Extended responsive account sweep | All 88 states passed at 11 widths, including internal auth bounds, phone field sizing and zero page errors. |
| Frozen-source production measurement | 20 completed journeys, five pairs per profile; zero browser errors. |
| Frozen-source React profiling | Six completed profiles, 26–27 commits each; zero browser errors. |
| Asset integrity | 627 full raster decodes/draws; 22 complete video decodes/6,924 frames; zero errors. |
| Skip after recovered cloud read | Controlled three-engine red, then 3/3 passed in 13.5 seconds with fresh GET/no PUT/no page errors/unchanged route retained. |
| Existing empty-start CTA case | Added an exact started-session h1 readiness wait before the unchanged persisted-name assertion; 3/3 passed in 25.8 seconds. |
| Final visual evidence | 318 primary product PNGs and paired sheets; temporary candidates and intermediate frames remain separate. |

The new history-success fixture initially expected the receipt to close; it was corrected to assert the intended receipt and disappearance of the correction fields. A new Security geometry fixture initially used a nonexistent ancestor selector and failed five profiles; the actual form selector corrected the harness without changing the bounds assertions. A new auth fixture retained Reset mode after same-hash navigation in Chromium/Firefox, causing three failures and two passes; it now uses the real Back to sign in action between widths. These are recorded harness corrections, not weakened existing assertions.

## Retained incomplete and failed broad attempts

| Attempt | Actual outcome |
| --- | --- |
| Early unfrozen 507-case guest attempt | 35 passed, two failed, two interrupted, 468 unrun; 4.1 minutes. |
| Frozen baseline 507-case attempt | 130 passed, two timeout failures, one interrupted, 374 unrun; 11.9 minutes. |
| First complete 519-case final guest attempt | 512 passed, seven failed; 32.5 minutes. Six WebKit focus faults reproduced on the frozen baseline; one Firefox case exceeded the unchanged cumulative budget under contention. |
| Later 540-case guest attempt | 271 passed, one test-readiness failure, one interrupted, 267 unrun; 16.6 minutes. Stopped before the confirmed same-route Skip follow-up. The ready-heading wait and Skip correction then passed targeted checks. |
| Focused design attempt under contention | Eight passed, one interrupted, 33 unrun out of 42; no failed assertion. |
| First five-profile account development matrix | 189 passed and one desktop WebKit security timeout out of 190; zero skips. |
| Fresh-server unchanged desktop WebKit repeat | 37 passed and one timeout out of 38; remaining assertions were not all completed. |
| Independent account setup in parallel | Also timed out; that proposed test change was not applied. |
| Docker precondition failures | Two attempts executed zero tests; these are not security-test passes or failed assertions. |

The timeout traces did not establish a failed member-isolation value assertion, but they also did not complete all remaining account-switch assertions. Neither attempt is called a full pass. [Account history](evidence/ACCOUNT_HISTORY.json) preserves phase-specific detail. Final matrices must supply their own results; targeted follow-ups do not retroactively make earlier runs green.

## Physical iPhone Verification

The isolated authorized iPhone Air suite completed 164 passes, two intentional personal-device safety skips and zero failures; three additional Light screenshot tours passed. There are 32 matched Light/Dark screenshot pairs, signed development build results and actual CPU/memory/clock samples. Ordinary app/widget/Watch compilation also passed unsigned. Simulator UI installation stalled; physical Watch/Health, system placement/privacy, complete assistive-technology, energy and distribution checks remain open. See the [dedicated native report](../../../ios/docs/audits/native-frontend-2026-11/PHYSICAL_IPHONE_VERIFICATION.md). These native results do not establish physical Safari website behavior.
