# Standards and scope

[Back to security overview](README.md)

This records what the 2026-10-12 security engagement covered, what it measured
against, and what it could not reach. It is an engineering assessment, not a
certification or a legal opinion.

## Scope record

| Item                       | Value                                                                                                                                                                                                           |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Repository                 | `Raoof128/forma-workout-planner` (public)                                                                                                                                                                       |
| Baseline                   | `feature/self-hosted-accounts` at `ca328a16efd73401e6c98daab0d70f34398a0340`, a superset of `main` and `release/forma-readiness-audit`                                                                          |
| Hardening branch           | `security/red-team-hardening` (local; not merged, not deployed)                                                                                                                                                 |
| Environments tested        | Local only: Node.js 24.21, a throwaway PostgreSQL 18.4 container bound to `127.0.0.1`, the Worker handler driven with controlled upstreams, and Playwright browsers against isolated test servers               |
| Identities                 | Synthetic members with `example.test` addresses created and destroyed per run                                                                                                                                   |
| Not in scope (not reached) | Any deployed Cloudflare Worker, Access application or service token, Tunnel, DigitalOcean Droplet or VPC, production or staging database, real mail provider, off-host backup store, GitHub repository settings |
| Prohibited and not done    | Traffic to any live host, credential stuffing beyond bounded local loops, load tests, real member data                                                                                                          |
| Evidence                   | Regression tests in the repository (see [the penetration test report](penetration-test-report.md)); scratch exploit scripts were kept out of the repository                                                     |

Everything that depends on live infrastructure is recorded as **BLOCKED**, not
as passed. See the [release verdict](release-security-verdict.md).

## Standards used

Sources were read on 2026-10-12.

| Standard                                      | Version and status                                         | How it was used                                                                                                                                                                                                                                                                                   |
| --------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OWASP ASVS                                    | 5.0.0, current stable (`v5.0.0` tag)                       | Level 2 target with risk-selected Level 3 items for authentication, sessions and authorisation. All 253 Level 1 and 2 requirements are mapped in [the ASVS mapping](asvs-l2-mapping.csv), from the official CSV export (`5.0/docs_en`); file and line references reflect the code at review time. |
| OWASP API Security Top 10                     | 2023 edition                                               | All ten categories exercised; see the [coverage matrix](security-coverage-matrix.csv)                                                                                                                                                                                                             |
| OWASP Web Security Testing Guide              | Stable v4.2 methodology                                    | Test case structure (identity, authentication, session, authorisation, input, business logic, client-side)                                                                                                                                                                                        |
| NIST SP 800-63B-4                             | Final, July 2025                                           | Password length, blocklist, failed-attempt limits, session lifetimes                                                                                                                                                                                                                              |
| Cloudflare Access service tokens              | "Strict service token authentication" setting (docs, 2026) | Required configuration for the Worker-to-origin hop; see [Cloudflare](cloudflare.md)                                                                                                                                                                                                              |
| Better Auth                                   | 1.7.7 security, rate-limit and session documentation       | Library behaviour was verified in its shipped source, not only its docs                                                                                                                                                                                                                           |
| OWASP Cheat Sheet Series, NIST SSDF (800-218) | Current                                                    | Supporting guidance for sessions, logging, supply chain                                                                                                                                                                                                                                           |

ASVS 5.0 chapter numbering differs from 4.0.3. The chapters used are V1
Encoding and Sanitization, V2 Validation and Business Logic, V3 Web Frontend
Security, V4 API and Web Service, V5 File Handling, V6 Authentication, V7
Session Management, V8 Authorization, V11 Cryptography, V12 Secure
Communication, V13 Configuration, V14 Data Protection, V15 Secure Coding and
Architecture and V16 Security Logging and Error Handling. V9 Self-contained
Tokens applies only to the HS256 tokens Better Auth embeds in email links. V10
OAuth and OIDC and V17 WebRTC are not applicable: FORMA implements no
OAuth/OIDC and has no WebRTC.

### Specific NIST SP 800-63B-4 points

- Passwords as a single factor need at least 15 characters. FORMA enforces 15
  to 1,024.
- The verifier SHALL compare new passwords against a blocklist. FORMA does not
  yet do this; it is an open item owned by the project owner.
- Consecutive failed attempts per account SHALL be limited to no more than 100.
  FORMA now locks an address after 100 consecutive failures until a password
  reset, with a shorter temporary lock after 10 failures in 15 minutes.
- AAL1 reauthentication SHOULD occur at least every 30 days. FORMA sessions now
  end 30 days after sign-in regardless of activity.

### Cloudflare Access, October 2026

Cloudflare documents a **Strict service token authentication** setting under
Zero Trust, Access controls, Access settings. With it on, a failed
service-token request receives 401 or 403 instead of a redirect to a login
page, and only Service Auth policies can admit service tokens. Organisations
created on or after 2026-10-05 have it enabled and cannot disable it; older
organisations can toggle it. This single documentation source was not
independently corroborated.

## Australian privacy

Whether the Australian Privacy Principles bind the operator depends on the
operator's circumstances (for example the small-business exemption), which this
assessment cannot determine. [Privacy](privacy.md) applies APP 11 style
safeguards as good practice without asserting legal applicability.
