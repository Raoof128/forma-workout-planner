# FORMA account implementation handoff

This is the original 12 October 2026 implementation handoff. Its draft PR and
NO-GO statements describe that review stage; the later
[production launch record](production-launch.md) records activation and hosted
checks. Preserve this handoff as historical evidence.

The account implementation is available in [draft PR #2](https://github.com/Raoof128/forma-workout-planner/pull/2), stacked on the earlier release-audit PR. **External release remains NO-GO.** See [release readiness](release-readiness.md) for current results and mandatory gates.

1. **Architecture:** React member workspaces use a same-origin Cloudflare Worker, private Fastify/Better Auth API and PostgreSQL. The planned private connection uses Tunnel plus Access service authentication. Cloudflare Email Service supplies transactional mail.
2. **Source changes:** Account UI and providers in `src/`; private workspace repositories; `worker/` gateway; `server/` authentication, workspace, migrations and email modules; `ops/` containers, database privileges and encrypted backup scripts; browser, server and unit tests. The PR contains the complete diff.
3. **Account features:** Verified registration, login, reset/change password, approved email change, sessions and revocation, TOTP/recovery codes, profile, private export and confirmed deletion. Four branded email designs were approved by the owner.
4. **Authentication evidence:** Real Better Auth/PostgreSQL lifecycle and adversarial tests pass. The final 24-test server suite also covers template validation and mocked Cloudflare transport failures. It does not prove external email delivery.
5. **Database:** Versioned auth/workspace migrations, checksum tracking and a migration lock are implemented. Local runtime-role tests permit application DML while denying schema modification and migration-ledger access. No RLS claim is made.
6. **Cloudflare:** Worker/Tunnel/Access/DNS inventory succeeded. Isolated app, origin and mail hostnames are selected. The isolated mail domain is enabled and one approved test was accepted/queued by Cloudflare; details are in [operations](operations.md); a deployed frontend-to-origin journey remains unverified.
7. **Droplet:** Non-root API and private database container checks passed locally. The supplied SSH key parses and matches its fingerprint, but this environment's port-22 connection is refused before authentication. No existing backend has been altered.
8. **Isolation:** Real synthetic members cannot read, write or export each other's workspaces. Expected-member binding rejects stale-tab writes after the shared session changes.
9. **Sync:** Tests cover revision conflicts, preservation/export of unsaved work, exact retry after a lost acknowledgement, and rejection of a delayed stale read. Hosted two-device verification remains outstanding.
10. **Legacy migration:** Migration requires explicit review and backup/export acknowledgement, preserves the browser copy, and uses revision checks before replacing cloud data.
11. **Security:** Independent review verified fixes for stale-account writes, MFA replay, session freshness, deletion callbacks, header trust and export limits. No unresolved high finding remains in the bounded source review; operational security remains unverified.
12. **Browsers:** Chromium desktop/mobile, Firefox and WebKit desktop/mobile are exercised. Exact candidate results are in [release readiness](release-readiness.md). The [control inventory](../qa/accounts-ui-inventory.json) keeps incomplete keyboard/error/loading evidence marked PARTIAL.
13. **Documentation:** [API](api.md), [database](database.md), [operations](operations.md), [sources](sources.md), [security QA](../qa/accounts-security.md), [independent review](../qa/accounts-independent-review.md), and [approved email previews](email-previews/README.md) are included. Reusable cloud-environment instructions are saved as a platform draft.
14. **Limitations:** Hosted staging, confirmed inbox receipt, host firewall/egress checks, off-host backup scheduling, and complete per-control interaction evidence remain required. A real isolated encrypted database restore passed; this does not establish operational recovery.
15. **Revision and PR:** The reviewed implementation candidate is `ebbec2eae455388013076b09facfbca341e108e3` on `feature/self-hosted-accounts`. Documentation-only follow-ups are visible in [PR #2](https://github.com/Raoof128/forma-workout-planner/pull/2); neither PR has been merged and no production deployment is claimed.
16. **Recommendation:** **NO-GO for external release.** Local implementation and bounded security evidence support review, while mandatory hosted and interaction gates remain incomplete. Do not substitute local sinks, provider mocks or placeholder origins for deployment evidence.
