# Native implementation plan

Scope agreed through the user's instruction to start building from both supplied
plans. The initial deliverable is the recommended offline guest vertical slice,
with the current repository contract taking precedence over stale examples.

## First implementation slice

1. **Resources and parity:** generate all accepted exercise IDs, selectable flags,
   metric profiles, reviewed guides, per-entry source attribution and the genuine
   empty-history starter workspace from existing JavaScript sources. Verify the
   bridge against the current validator and preserve deterministic output.
2. **Domain:** represent the v2 workspace, routines, session snapshots, all four
   measurement profiles and optional programming fields. Validate before a local
   mutation becomes committed. Count only eligible completed load/repetition sets
   as lifting volume; preserve per-side strength estimates and original plank
   units.
3. **Durability:** serialize local writes through a SQLite actor. A transaction
   commits before the UI reports saved or emits completion feedback. Reopening
   must restore the same active session and persisted rest deadline. Reject stale
   revisions and corruption instead of replacing data with an empty workspace.
4. **Native interface:** Today, Plan, Progress and You use SwiftUI navigation.
   Active training stays focused, with stable labelled inputs and large
   completion targets. Empty progress is intentional. Light/dark appearances,
   Dynamic Type, tabular numerals and Reduced Motion belong to the design.
5. **Data control:** expose an explicit backup export and accurate local privacy
   information. Reset requires confirmation. An exported copy belongs to its
   chosen Files/share destination and is not deleted when local data is reset.
6. **Verification:** run package and resource tests; generate the Xcode project;
   compile and execute native UI tests on macOS; then test interruptions,
   accessibility and file protection on physical devices. Preserve failed
   evidence and resolve defects before calling the slice release-ready.

## Follow-on work with named gates

| Work | Gate before it can ship |
| --- | --- |
| Native accounts and sync | Reviewed public-origin native auth protocol, server-derived identity, durable idempotent queue, conflict/recovery tests and member partition isolation |
| Account creation | Separate express workout-data consent, age/guardian policy, verification/MFA/recovery parity and findable in-app deletion initiation |
| Web backup import | Cross-language acceptance/rejection corpus, v1 migration and every optional v2 field preserved; explicit replace/merge preview |
| Broad catalogue/media release | Human review of licence/attribution, share-alike obligations, source guide quality and asset rights |
| App Store submission | Final identity, legal/entity assessment, storefronts, device tests, privacy/required-reason audit, signing, screenshots, review notes and owner approval |

The app must not imply these later features already work. No hidden review-only
configuration or remotely enabled account feature is part of this slice.

## Completion evidence

Record commands and actual results, rather than checking planned tasks as passed.
Native simulator/device performance targets in the research are design targets,
not measurements. A generated illustration, source review or Linux test result
does not establish App Store compliance or an iOS build.
