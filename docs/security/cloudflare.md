# Cloudflare Worker, Access and Tunnel

[Back to security overview](README.md)

The Worker (`worker/index.ts`) serves the SPA and is the only public path to
the API. Its behaviour is covered by `worker/tests/gateway.test.ts` and
`worker/tests/redteam.test.ts`. Cloudflare account configuration (Access,
Tunnel, DNS, WAF) is not in the repository and was **not verified**.

## Gateway behaviour (verified locally)

| Control             | Behaviour                                                                                                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fixed upstream      | `BACKEND_URL` must be an HTTPS origin without path or credentials. The upstream URL is built from the request path only; 60,000 fuzzed paths never changed the upstream host.                     |
| Routes and methods  | Exact allowlist per route. `/api/auth/*` paths containing `%`, `\`, `//` or dot segments are refused. Unknown `/api` paths are JSON 404s, never the SPA.                                          |
| Origin and CSRF     | Mutations need `Origin` equal to `APP_ORIGIN`; any foreign `Origin` is refused. `Sec-Fetch-Site: cross-site` is refused except GET navigations to email-link endpoints.                           |
| Request headers     | Allowlist: `accept`, `accept-language`, `content-type`, `cookie`, `origin`, `user-agent`, `x-forma-member`, `x-request-id`, `sec-fetch-*`. Credentials are added server-side.                     |
| Client IP           | `cf-connecting-ip` is copied to `x-forma-client-ip`; client-supplied values are dropped. Outside development a request without it gets 503 so callers never share one limiter bucket.             |
| Body limits         | 20 MiB only for `PUT /api/workspace`; 64 KiB elsewhere; enforced on declared length and while streaming.                                                                                          |
| Timeouts            | 30 seconds for the whole exchange.                                                                                                                                                                |
| Redirects           | Not followed. `Location` must resolve to the app origin (or the backend origin, rewritten); everything else is 502.                                                                               |
| Response headers    | Allowlist: `content-type`, `content-language`, `content-disposition`, `etag`, `last-modified`, `retry-after`, `vary`.                                                                             |
| Cookies             | Only `forma.*` and `__Secure-forma.*` cookies pass, with any `Domain` attribute removed. An Access `CF_Authorization` cookie can never reach the browser.                                         |
| Response types      | Only `application/json` and `text/plain`; HTML (an Access login page), SVG and XML are refused.                                                                                                   |
| Security headers    | API: `no-store`, `nosniff`, `default-src 'none'; frame-ancestors 'none'; sandbox`, `DENY`, `no-referrer`, CORP, HSTS. Assets: strict CSP (`script-src 'self'`), HSTS, `DENY`, Permissions-Policy. |
| Alternate hostnames | Production sets `workers_dev: false` and `preview_urls: false`.                                                                                                                                   |

## Required account configuration (not verified)

1. Put the API hostname behind a Cloudflare Access application with exactly one
   **Service Auth** policy that admits only the Worker's service token. Do not
   add identity-provider or "Allow" policies to that application.
2. Turn on **Strict service token authentication** (Zero Trust, Access
   controls, Access settings) so failed tokens get 401/403 rather than a login
   redirect. The Worker already refuses HTML responses, so a misconfiguration
   fails closed either way.
3. Store `ACCESS_CLIENT_ID`, `ACCESS_CLIENT_SECRET` and `FORMA_WORKER_SECRET`
   with `wrangler secret put` per environment, never in `wrangler.jsonc`.
   Use independent values for staging and production.
4. Set a service-token expiry and enable the expiring-token notification;
   rotate by issuing a second token, deploying it, then revoking the first.
5. The Tunnel's only ingress rule must map the API hostname to
   `http://api:3000`, followed by `http_status:404`. Publish no other hostname
   and no DNS record pointing at the Droplet's public address.
6. Optionally validate `Cf-Access-Jwt-Assertion` (signature, `aud`, `iss`) in
   the API as a third check. The API already requires the worker secret, so
   this is defence in depth.
7. Workers VPC bindings to a Tunnel exist in beta. They were not assessed and
   should be reviewed separately before replacing the Access hop.

A valid service token never grants member access: the API still requires a
member session and member reference.

## Live checks still to run (BLOCKED here)

- Request the API hostname without a token, with a revoked token and with an
  expired token; each must be 401/403 with no HTML.
- Confirm the Droplet has no public listener on 3000/5432 (`ss -tlnp`) and the
  DigitalOcean cloud firewall blocks all inbound except SSH from the operator.
- Confirm Cloudflare caching does not store any `/api/*` response.
- `wrangler tail` a sign-in to confirm no `CF_Authorization` cookie appears.
