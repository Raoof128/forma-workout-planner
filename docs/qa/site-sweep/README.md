# Whole-site review — 14 October 2026

The owner requested this review after completion of all 1,414 exercise artwork
matches. Artwork checkpoint `0f8bc3c4eaa126bad139afa49662cbb546b9ecd5` is
pushed to main and passes the strict complete-coverage check.

## Review in progress

Fresh browser captures cover all ten guest routes at 1536×1024 and 390×844,
plus an exercise guide and active workout. No route overflow or page exceptions
were observed in those captures. The initially captured library screenshot was
too early; it was recaptured after visible images loaded. Captures use synthetic
guest data. Account workflows are being checked separately with isolated local
services, not live member accounts.

The cold library measurement records actual browser resource sizes: 15,047,445
encoded image bytes across nine requests on desktop and 7,330,382 across four
on mobile. It is a local development-server measurement, not a production
network benchmark or Core Web Vitals claim.

Confirmed fixes in progress: compact image derivatives, keyboard focus and
reduced-motion behavior in legal contents links, and a visible keyboard focus
indicator for account backup import. Original site photography will replace
the existing hero and routine photos whose redistribution terms were not
documented in the README. Exercise source PNGs and their reviews stay archived.

Official React, Vite, MDN and WCAG documentation was fetched on 14 October
2026. Source receipts and read-only audit findings are included here. Fetching
current documentation does not establish that every dependency is the newest
release. Source-only recommendations, including broad catalog/storage
restructuring, are not proven runtime defects or completed fixes.

Final validation and implementation details will be recorded here when the
reviewed fixes are complete. No site deployment is part of this checkpoint.

## Implemented checkpoint

Compact previews are now committed for all 186 source atlases, totaling 5,681,534
bytes. Original PNGs and registry are unchanged. Fresh cold-load observations
were 278,134 image bytes on desktop and 155,102 on mobile (about 98% less than
the original observation). Guides still load the original full-size image.
Preview and guide crop percentages agree in the uneven-row regression.
Runtime JSON now stores shared preview metadata once; its raw size fell, while
gzip size rose slightly because the new hash metadata is less compressible.
This is an image-payload improvement, not a claim of improved Core Web Vitals.

Keyboard/reduced-motion fixes passed all seven focused browser checks, after
four expected failures before the fixes. Five artwork browser checks, 62 unit
cases, strict 1,414 coverage, lint, types, formatting, docs and build passed.
The full baseline was 90 passed / four failures: a stale test clicked a disabled
reorder button, and long aggregate tests exhausted their budgets. The corrected
tests preserve the underlying assertions and default timeouts. Diagnostics
also found generated trace HTML causing Vite reloads and parallel Playwright
runners colliding on an output directory. Generated directories are now
excluded from the watcher; independent runs use separate artifact folders.
A browser websocket probe confirmed that creating/deleting scratch HTML causes
no full reload.

Final complete guest/account browser runs and final photo crops are pending.
No deployment or live member-data operation occurred.

Photo crops have now been checked in the rendered desktop and mobile app.
The hero keeps the face within the phone crop; routine cards show the bar or
kettlebell grip. The phone routine-detail banner had been scaling the entire
three-column sprite into one cover; its scoped background sizing now displays
only the selected column. Reviewed screenshots are under `visuals/`.

The isolated account suite passed all 18 desktop/mobile Chromium cases with a
120-second CLI budget; no skips or flaky cases. The initial default 30-second
run was stopped after long multi-step account journeys timed out. Functional
verification covers password/reset/MFA/session/deletion controls, two-member
data isolation, lost-save retries, migration review and workout persistence.
These use synthetic members and an in-memory email sink. The disposable database
and test services are stopped. This establishes local behavior, not external
email delivery or live infrastructure readiness. Twelve account screens were
captured; a focus/scroll artifact in the mobile registration capture is being
checked before accepting that image as final visual evidence.

The account form transition check confirmed a keyboard defect, not only a
screenshot artifact: registration and MFA headings stayed inactive after mode
changes. Four real-component regressions failed before the repair. The form
now moves focus to its visible heading on mode changes, including password
recovery; initial route focus and authentication methods are unchanged. Four
real-app desktop/mobile checks passed with mocked local API responses. New
regressions are in `tests/accounts-auth-focus.spec.js`; the existing 18 real
account-service journeys remain separately recorded.

The system-browser two-worker guest run recorded 86 passed / 26 failed. Most
were aggregate time limits; the three other failures were a late fallback
heading, a 24ms clock bracket overshoot and a 10.712s large-history measurement
against a 10s bound. Those cases are being replayed with the matching bundled
Chromium and one worker. Accessibility setup now seeds before a single direct
navigation; timer assertions bracket actual browser timestamps around the click.
Assertions, ordinary 30s budgets and the 10s performance bound remain intact.
