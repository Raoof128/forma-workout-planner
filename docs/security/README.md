# Security

[Back to README](../../README.md)

This folder is the security record for FORMA's self-hosted account
architecture: a React SPA and API gateway on a Cloudflare Worker, a private
Fastify and Better Auth API on a DigitalOcean Droplet behind Cloudflare Access
and Tunnel, and PostgreSQL.

**Current verdict: NO-GO for real members.** The code-level controls were
red-teamed and hardened, but live infrastructure, recovery and monitoring have
not been verified. See the [release verdict](release-security-verdict.md).

No application can be proven secure. These documents record what was tested,
how, what was fixed, and what remains.

## Documents

| Document                                                 | Contents                                                              |
| -------------------------------------------------------- | --------------------------------------------------------------------- |
| [Standards and scope](standards-and-scope.md)            | Engagement scope, standards and versions, exclusions                  |
| [Threat model](threat-model.md)                          | Architecture, trust boundaries, STRIDE register, compound threats     |
| [Authentication](authentication.md)                      | Sign-up, sign-in limits, passwords, reset, 2FA, sessions              |
| [Authorisation](authorisation.md)                        | Member isolation and the route inventory                              |
| [Cloudflare](cloudflare.md)                              | Worker gateway behaviour and required Access and Tunnel configuration |
| [Droplet hardening](droplet-hardening.md)                | Container controls and the host checklist                             |
| [Database security](database-security.md)                | Roles, isolation, integrity and backups                               |
| [Supply chain](supply-chain.md)                          | Dependencies, scanners, CI and repository settings                    |
| [Privacy](privacy.md)                                    | Data inventory, retention, export and deletion                        |
| [Incident response](incident-response.md)                | Detection requirements and runbooks                                   |
| [Penetration test report](penetration-test-report.md)    | Findings, fixes, regression tests and residual risk                   |
| [Security coverage matrix](security-coverage-matrix.csv) | Control-by-control traceability                                       |
| [ASVS mapping](asvs-l2-mapping.csv)                      | OWASP ASVS 5.0.0 Level 1 and 2 requirement mapping                    |
| [Release verdict](release-security-verdict.md)           | Gates S01–S20 and the GO/NO-GO decision                               |

## Running the security tests

```sh
npm run test:server   # real PostgreSQL; includes server/tests/redteam.test.ts
npm run test:worker   # includes worker/tests/redteam.test.ts
npm run test:unit     # includes unit/redteam-release.test.js
```

`TEST_DATABASE_URL` must point at a disposable database; the suites fail rather
than skip when it is missing. Report vulnerabilities as described in
[SECURITY.md](../../SECURITY.md).
