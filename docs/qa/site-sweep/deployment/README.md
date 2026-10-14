# Artwork and site redeployment — 14 October 2026

The owner requested commit, push and redeploy after the completed site review.
Source `d29266496f4c178920897e5e3a066806c478b1bd` was already pushed to main.
Both frontends were deployed in account mode. The current production-launch
record supersedes the historical guest-only deployment notes. Existing API
services, secrets and member data were preserved.

Initial production version: `d832eea9-2e4f-4800-8c4d-afb91262d118`.
Initial staging version: `8e203414-13f7-48d9-aa5a-352579ebe579`.
Both one-hour deployment tokens were revoked by the helper after use.
Live HTML, main JS/CSS, both photographs and the final exercise atlas matched
the built byte hashes recorded in [asset evidence](live-asset-hashes.json).

## Edge-injection correction

The live browser exposed a Cloudflare-injected Web Analytics script. The existing
`script-src 'self'` policy blocked it from executing. Management-token reads of
the account RUM inventory returned 403, so no account-wide analytics configuration
was changed. The supported response-level fix adds `no-transform` to HTML cache
control while retaining existing directives and all script/API cache policies.

Cloudflare's [Web Analytics setup documentation](https://developers.cloudflare.com/web-analytics/get-started/),
retrieved 14 October 2026, states:

> If you have a `Cache-Control` header set to `public, no-transform`, Cloudflare
> proxy will not be able to modify the original payload of the website.
> Therefore, the Beacon script will not be automatically injected to your site,
> and Web Analytics will not work.

The new regression failed against the previous Worker; after correction, all
21 Worker tests passed. It covers existing HTML cache directives, an absent
header, an already-present directive and unchanged JavaScript caching.
## Final deployed versions and verification

Runtime source: `be2ddfa` (the artwork/site assets are the unchanged account build
from `d292664`). Subsequent commits update evidence and operating documentation.

| Target | Final version |
| --- | --- |
| [Public site](https://forma.raoufabedini.dev) | `20b4bb4a-e50a-4762-93aa-3a9746f0baa2` |
| Private staging | `e815bd37-68d7-483b-91b4-6bd292d5fa02` |

Both final deployments uploaded no changed assets and revoked their one-hour
tokens. Four temporary deployment tokens in total were revoked during this task.
The unchanged API image/catalog identities required no host restart or database
migration. No member data or shared-host service was changed.

Real public Chromium checks at 1536×1024 and 390×844 pass:

- Library displays 1,414 movements. EZ-Bar Curl loads the 768-pixel WebP preview
  and 1536-pixel original, with identical reviewed CSS crop geometry.
- Registration focuses its visible heading without submitting a form. Privacy
  contents transfer keyboard focus; the phone section starts at 90px below the
  66px header. No horizontal overflow, page errors or console errors occur.
- Actual browser HTML includes `no-transform` and contains no injected beacon.
  The browser makes no external requests during the tested routes.
- Anonymous health returns 200, private workspace 401 and session null.
  Public account mode remains enabled. Staging anonymous access still returns
  302 to Cloudflare Access; no temporary Access bypass or member was created.
- The generated hero and routine photos load from the site's own origin.
  CSP, HSTS and the API's ownership boundaries remain intact.

Live screenshots wait for the guide image's visible state, decoding and two
animation frames. An early screenshot taken at `naturalWidth` readiness was
paint-incomplete and was replaced; it is not accepted evidence.

These are hosted desktop/mobile-emulation smoke checks, not a new full member
lifecycle, real-device certification or email-delivery test. Earlier local
matrices remain described accurately in the [site review](../README.md).

Rollback can select the prior frontend/Worker versions listed above through
Wrangler. No database rollback is required for this presentation-only release.
