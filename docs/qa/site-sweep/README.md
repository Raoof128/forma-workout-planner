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
