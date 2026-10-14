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
Final header-fix redeployment and live verification will be recorded here.
