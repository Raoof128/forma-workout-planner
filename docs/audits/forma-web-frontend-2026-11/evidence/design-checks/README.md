# Focused design verification receipts

Published JSON receipts preserve the observed counts, outcomes, phases and causes of the controlled failures and final checks for WD-14/WD-15. Each records the exact SHA-256 of its private raw log. Raw logs remain private and ignored; they are absent from a clean checkout. Published summaries exclude raw trace bodies, absolute machine paths and credential material. Screenshot and contact-sheet provenance is in [the visual index](../screenshots/INDEX.md).

| Receipt                                                 | Observed result                                                                                                                                |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [Security controlled red](security-controlled-red.json) | At 320 px, document width 515 exceeded the unchanged ≤321 assertion.                                                                           |
| [Security final](security-five-profiles-pass.json)      | Five browser profiles passed in 56.1 seconds; each exercises 320/360/375, both radio choices and panel/viewport/control center-hit bounds.     |
| [Auth controlled red](auth-controlled-red.json)         | At 768 px, intrinsic grid width 570 exceeded visible client width 490.                                                                         |
| [Auth final](auth-five-profiles-pass.json)              | Five profiles passed in 41.8 seconds; each checks sign-in, sign-up and reset at 768/820/960 against the visible panel.                         |
| [Initial width sweep](account-widths-initial.json)      | 88 states recorded; three Security document-overflow failures at 320/360/375; no page errors.                                                  |
| [Final width sweep](account-widths-final.json)          | All 88 states passed across 11 required widths, including internal auth panel/card/control/link bounds, phone input size and zero page errors. |

The first Security harness attempt used the wrong enclosing-panel selector; its [five harness errors](security-initial-harness-errors.json) are recorded in the summary. The first auth harness assumed same-hash navigation reset form mode in every engine; [three failures and two passes](auth-initial-harness-errors.json) are recorded in the summary. The tests now use the actual enclosing form and the real Back to sign in action between widths. Original geometry assertions and timeouts remain.

The durable cases live in `tests/accounts-design.spec.js` and are discovered by the normal five-project account configuration for both development and production. These focused mocks do not replace full service-backed account matrices or physical Safari testing. [Checksums and publication boundaries](MANIFEST.json) distinguish the eight published JSON receipts from six private raw-log provenance records. Summary receipts are derived evidence; the two width-result JSON files retain their original bytes.
