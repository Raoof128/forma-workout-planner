# Penetration test report

[Back to security overview](README.md)

| Field         | Value                                                                                                                                                                                                                 |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Date          | 2026-10-12 (Australia/Sydney)                                                                                                                                                                                         |
| Target        | Baseline `ca328a16efd73401e6c98daab0d70f34398a0340` (`feature/self-hosted-accounts`)                                                                                                                                  |
| Result branch | `security/red-team-hardening`                                                                                                                                                                                         |
| Environment   | Local only; see [standards and scope](standards-and-scope.md)                                                                                                                                                         |
| Method        | Source review of all handwritten server, Worker, frontend, ops and CI code; live probing of the real Fastify app and Better Auth against PostgreSQL 18; Worker driven with controlled upstreams; Playwright; scanners |
| Team          | Lead reviewer plus five independent reviewers (edge; frontend and sync; authentication and authorisation; infrastructure and standards; purple-team retest of the fixes)                                              |

The repository is public, so this report describes each weakness at the level
needed to understand the fix. Reproductions are the regression tests named
below; scratch exploit scripts were not committed.

## Summary

- **No Critical findings. One High** (availability, authenticated): crafted
  workspace documents stalled the API for 7–16 seconds each. Fixed.
- **No cross-member access** was achieved on any route, by any method.
- **No authentication bypass** was found in Better Auth itself. Weaknesses were
  in how the library was exposed and limited, and in defence-in-depth layers.
- 27 findings were fixed. 29 behavioural regression tests (RT-01 to RT-19
  except RT-04b, EDGE-01 to EDGE-07, FE-01, FE-03, FE-04) each **fail** on the
  code they guard against (the baseline, or for RT-18 and RT-19 the first fix
  commit `6f26a09`) and pass on the result branch. RT-04b unit-tests the
  throttle module; EDGE-08 was added after the comparison. FS-19 and FS-21 have
  no dedicated failing test; they rely on the existing browser journeys, which
  is a coverage gap.
- The engagement's own fixes were attacked twice by reviewers who did not
  write them. That surfaced two findings introduced by the fixes (FS-04,
  FS-23) and four weaknesses in later fix rounds (see [retest](#retest)). All
  were fixed before release of this branch.
- Open items are listed under [residual risk](#residual-risk).

Severity uses CVSS v4.0 qualitative bands adjusted for FORMA's context
(member-data exposure, data loss, and whether the Worker already blocked the
path).

## Fixed findings

| ID    | Severity | Finding                                                                                                                                                                                            | Fix                                                                                                                                                                   | Regression            |
| ----- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| FS-01 | Medium   | The API's gateway-secret and Origin checks tested the raw URL prefix while routing used the decoded path, so a percent-encoded path skipped both. Not reachable through the Worker.                | Deny by default: only exact `/healthz` is public; encoded paths are refused.                                                                                          | RT-01                 |
| FS-02 | Low      | Token GET endpoints (reset, verify, delete callback) redirected to any `callbackURL`, with or without a valid token. The Worker already blocked these redirects.                                   | Redirect parameters and emitted `Location` limited to the app origin.                                                                                                 | RT-02, RT-12          |
| FS-03 | Medium   | No per-account limit on failed sign-ins; only 5 per minute per IP.                                                                                                                                 | Durable per-account cap (10 per 15 min; hard lock at 100 until reset).                                                                                                | RT-04, RT-04b         |
| FS-04 | Medium   | (Introduced by FS-03's first version.) Form-encoded auth bodies skipped every body-based proxy check.                                                                                              | Auth requests must be JSON objects.                                                                                                                                   | RT-13                 |
| FS-05 | Medium   | Revoking other sessions on password change was a client choice.                                                                                                                                    | Forced server-side.                                                                                                                                                   | RT-05                 |
| FS-06 | Medium   | The change-email link minted a session without password or TOTP, which also satisfied the five-minute step-up.                                                                                     | Sessions from email links are deleted and their cookies withheld.                                                                                                     | RT-10                 |
| FS-07 | Medium   | Mail could be sent to one recipient without limit (replayable change-email approval, deletion requests, resends across IPs).                                                                       | Per-recipient, per-kind budget (5 per hour).                                                                                                                          | RT-06                 |
| FS-08 | Low      | Unused Better Auth endpoints were reachable, including a password check allowing 100 attempts per minute and an endpoint returning the raw internal user ID.                                       | Allowlist of the endpoints FORMA uses.                                                                                                                                | RT-08                 |
| FS-09 | Low      | Profile name and image were unbounded (a 900 KB name was accepted and echoed on every session check).                                                                                              | Names 1–60 code points without control, format or separator characters; no images.                                                                                    | RT-09, RT-17, RT-19   |
| FS-10 | Low      | Sessions had no absolute lifetime.                                                                                                                                                                 | 30 days from sign-in.                                                                                                                                                 | RT-11, RT-16          |
| FS-11 | High     | No aggregate bounds on workspace size; one valid 20 MiB document took 7–16 s to validate, five times per save, on the single event loop. No write rate limit; bodies parsed before authentication. | Bounds checked before parsing (10,000 workouts, 150,000 sets, 200 routines); one validation per save; 120 saves per minute per member; authentication before parsing. | FE-01, RT-07, EDGE-01 |
| FS-12 | Low      | Malformed JSON returned 500 with the parser message and logged a stack trace.                                                                                                                      | Generic 400 `invalid_json`; generic errors everywhere.                                                                                                                | RT-03                 |
| FS-13 | Medium   | The Worker forwarded 20 MiB bodies on every route.                                                                                                                                                 | 64 KiB except workspace saves.                                                                                                                                        | EDGE-01               |
| FS-14 | Low      | The Worker forwarded request headers by denylist.                                                                                                                                                  | Allowlist.                                                                                                                                                            | EDGE-02               |
| FS-15 | Low      | The Worker passed through upstream response headers and every cookie, including any `Domain` widening; an Access cookie could have reached browsers.                                               | Header allowlist; only FORMA cookies, `Domain` stripped.                                                                                                              | EDGE-03               |
| FS-16 | Low      | API responses lacked CSP, frame and HSTS headers; SVG and XML bodies passed through.                                                                                                               | Restrictive API headers; JSON or text only.                                                                                                                           | EDGE-04               |
| FS-17 | Info     | Malformed upstream redirects returned odd statuses.                                                                                                                                                | 502.                                                                                                                                                                  | EDGE-05               |
| FS-18 | Low      | No `Sec-Fetch-Site` check; a request without the edge client IP shared one limiter bucket.                                                                                                         | Cross-site refused except email links; 503 without client IP.                                                                                                         | EDGE-06, EDGE-07      |
| FS-19 | Medium   | A transient session-check failure discarded unsent cloud edits.                                                                                                                                    | Signed-in state kept unless the server says 401.                                                                                                                      | Browser suite         |
| FS-20 | Medium   | Restore and import replaced the cloud workspace even if another device had saved since the backup was reviewed.                                                                                    | Pinned to the reviewed revision.                                                                                                                                      | FE-03                 |
| FS-21 | Low      | Megabyte-sized schema errors shown to members; reset token left in the address bar.                                                                                                                | Generic messages; token removed after reading.                                                                                                                        | Browser suite         |
| FS-22 | Low      | A browser's guest data was offered to, and could be imported by, every member who signed in on it.                                                                                                 | Offered once; other members see a notice.                                                                                                                             | FE-04                 |
| FS-23 | Medium   | (Introduced by FS-03's second version.) Parallel guesses all passed the per-account check before any failure was recorded.                                                                         | Attempts reserved atomically before checking; refused attempts are never counted.                                                                                     | RT-14                 |
| FS-24 | Medium   | A stolen session could guess the password without limit on signed-in endpoints.                                                                                                                    | Same limits per member on every password-checking endpoint; only non-empty passwords count; password reset lifts the lock.                                            | RT-15, RT-18          |
| FS-25 | Low      | `workers_dev` enabled in production; floating image tags; a password on a command line; PUBLIC database privileges and no statement timeouts.                                                      | Disabled; digests pinned; environment instead of argv; privileges revoked; timeouts set.                                                                              | Role checks below     |
| FS-26 | Low      | CI had no secret scanning, vulnerability scanning, SAST or SBOM, and persisted credentials.                                                                                                        | Fail-closed security job; `persist-credentials: false`; Dependabot.                                                                                                   | Local run             |
| FS-27 | Low      | HTTP security tests silently skipped when no database was configured.                                                                                                                              | Fail when the database is missing.                                                                                                                                    | Suite behaviour       |

## Verified controls (no finding)

- **Isolation:** every combination of one member's session with another's
  reference returned 409; session revoke by another member's reference returned
  404; 20 parallel writes at one revision produced one success; retries of one
  operation produced one revision.
- **Authentication:** sign-up mass assignment, enumeration via sign-up, reset
  and resend, cookie flags, TOTP replay (including 8 parallel uses of one code),
  recovery-code reuse, reset-token reuse and expiry, deletion-token reuse.
- **Edge:** 60,000 fuzzed paths never changed the upstream host; 40 hostile
  `Location` variants were blocked; spoofed IP, identity and Access headers
  never reached the origin.
- **Frontend:** hostile text renders literally; no HTML sinks; no tokens in any
  browser storage; prototype-polluting keys are stripped.
- **Database role** (executed against PostgreSQL 18.4): no superuser, create,
  truncate, alter, file read, `COPY PROGRAM`, temp tables or access to other
  databases; 15-second statement timeout.
- **Scanners:** npm audit 0, OSV 0, gitleaks 0 across all branches, Semgrep 0
  after triage.

## Retest

The purple-team reviewer, who wrote none of the fixes, attacked each one after
remediation. It confirmed no bypass of the gateway check, route allowlist,
redirect checks, JSON-only rule, session-mint stripping, workspace bounds or
Worker controls, and found five issues (FS-23, FS-24, the deletion-callback gap
in FS-10, the name characters in FS-09, and the lockout combination below).
All but the last were fixed and are covered by RT-14 to RT-17.

A second independent retest then attacked those fixes and the later ones
(FS-22, EDGE-08). It confirmed the concurrency cap (100 parallel guesses: 10
judged, 90 refused), the deletion-callback lifetime and the CSP change, and
found four weaknesses in the fixes themselves:

| Weakness                                                                                   | Severity   | Fix                                                                              | Regression  |
| ------------------------------------------------------------------------------------------ | ---------- | -------------------------------------------------------------------------------- | ----------- |
| Refused attempts were still counted, so one burst could reach the until-reset lock         | Low        | Counters move only when a slot is granted (`RETURNING old.*`, PostgreSQL 18)     | RT-14       |
| An empty password on `delete-user` returned 200 and cleared the member's guess counter     | Medium     | Only non-empty passwords are reserved and can clear the counter                  | RT-18       |
| A password reset did not lift the signed-in password-check lock                            | Medium-Low | Reset clears both locks                                                          | RT-18       |
| Names were validated trimmed but stored untrimmed (5,000 trailing spaces accepted)         | Low        | The trimmed, validated name is what is stored; more invisible characters refused | RT-19       |
| After navigating away and back, the guest import was offered again to the importing member | Low (UX)   | Import marker kept in application state                                          | Lead review |

These last fixes are verified by their regression tests and the lead review;
they have not had a third independent attack.

## Residual risk

| ID   | Item                                                                                                                                  | Severity | Owner            |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------- | -------- | ---------------- |
| R-01 | Backup archives are not signed; a writer to the backup store can substitute one.                                                      | Medium   | Owner            |
| R-08 | Targeted lockout: a known address can be locked and its reset mail suppressed by sustained requests. Logged; operator can lift it.    | Medium   | Owner (accepted) |
| R-10 | No breached-password blocklist (NIST SP 800-63B-4).                                                                                   | Medium   | Owner            |
| R-14 | No security alerting or monitoring pipeline.                                                                                          | High     | Owner            |
| R-17 | No isolated restore from a real off-host backup has been performed.                                                                   | Medium   | Owner            |
| R-02 | Backups run as the database superuser.                                                                                                | Low      | Owner            |
| R-03 | Application secrets in container environment variables.                                                                               | Low      | Owner            |
| R-04 | API container has unrestricted egress.                                                                                                | Low      | Owner            |
| R-06 | An unverified address can be pre-registered by someone else until the owner resets it.                                                | Low      | Accepted         |
| R-07 | Changing email does not end other sessions.                                                                                           | Info     | Owner            |
| R-11 | Better Auth's per-IP limiter is in memory and resets on restart.                                                                      | Low      | Owner            |
| R-18 | Everything beyond the repository: Access policy, Tunnel ingress, DNS, Droplet firewall and host, secrets rotation, live CI.           | Unknown  | Owner            |
| R-19 | Email link lifetimes exceed ASVS 5.0 V6.5.5 (verification and reset 1 hour, deletion 24 hours, against 10 minutes).                   | Low      | Owner            |
| R-20 | Recovery codes are stored encrypted rather than hashed (V6.5.2); TOTP is optional (V6.3.3).                                           | Medium   | Owner            |
| R-21 | One `AUTH_SECRET` signs cookies, derives references and encrypts TOTP secrets; no key-separation or rotation policy (V11).            | Low      | Owner            |
| R-22 | Better Auth's scrypt cost (N=16384, r=16, p=1) is below OWASP's current minimum guidance (V11.4.2).                                   | Low      | Owner            |
| R-23 | Session cookie uses the `__Secure-` prefix rather than `__Host-` (V3.3.3); host-only scoping relies on the Worker stripping `Domain`. | Low      | Owner            |
| R-24 | Tunnel-to-API and API-to-database traffic is unencrypted on internal Docker networks (V12.3.3).                                       | Low      | Owner            |

An independent human penetration test of the deployed staging environment is
recommended before inviting real members.
