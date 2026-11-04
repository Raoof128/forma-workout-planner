# Focused design verification receipts

These receipts preserve actual controlled failures and final checks for WD-14/WD-15. Logs retain their original bytes. Historical temporary trace paths inside logs are references; trace bundles are not included here. Screenshot and contact-sheet provenance is in [the visual index](../screenshots/INDEX.md).

| Receipt                                                | Observed result                                                                                                                                |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [Security controlled red](security-controlled-red.log) | At 320 px, document width 515 exceeded the unchanged ≤321 assertion.                                                                           |
| [Security final](security-five-profiles-pass.log)      | Five browser profiles passed in 56.1 seconds; each exercises 320/360/375, both radio choices and panel/viewport/control center-hit bounds.     |
| [Auth controlled red](auth-controlled-red.log)         | At 768 px, intrinsic grid width 570 exceeded visible client width 490.                                                                         |
| [Auth final](auth-five-profiles-pass.log)              | Five profiles passed in 41.8 seconds; each checks sign-in, sign-up and reset at 768/820/960 against the visible panel.                         |
| [Initial width sweep](account-widths-initial.json)     | 88 states recorded; three Security document-overflow failures at 320/360/375; no page errors.                                                  |
| [Final width sweep](account-widths-final.json)         | All 88 states passed across 11 required widths, including internal auth panel/card/control/link bounds, phone input size and zero page errors. |

The first Security harness attempt used the wrong enclosing-panel selector; its [five harness errors](security-initial-harness-errors.log) are retained. The first auth harness assumed same-hash navigation reset form mode in every engine; [three failures and two passes](auth-initial-harness-errors.log) are retained. The tests now use the actual enclosing form and the real Back to sign in action between widths. Original geometry assertions and timeouts remain.

The durable cases live in `tests/accounts-design.spec.js` and are discovered by the normal five-project account configuration for both development and production. These focused mocks do not replace full service-backed account matrices or physical Safari testing. [Checksums](MANIFEST.json) identify each copied receipt.
