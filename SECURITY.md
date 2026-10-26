# Security reporting

Do not post exploit details, credentials, session cookies, recovery codes,
exported workout data, or other private information in a public issue.

Check the repository's GitHub **Security** tab for a private vulnerability-reporting option. Availability depends on the repository settings. If no private reporting option is available, open a public issue with only a brief, non-sensitive request for a private contact route; do not include reproduction details until a private route is established.

When reporting privately, include the affected version or commit, browser and
operating system when relevant, impact, and minimal reproduction steps using
synthetic data. Do not send real workout backups or secrets. For account/API
reports, include the route and whether the request used a synthetic member,
without including cookies, password-reset links, MFA recovery codes, or member
payloads.

The latest security assessment, threat model, residual risks and release
verdict are in [docs/security](docs/security/README.md).

The account architecture and known deployment boundaries are documented in
[account security and database notes](docs/accounts/database.md),
[infrastructure operations](docs/accounts-infrastructure.md), and
[release readiness](docs/accounts/release-readiness.md). The repository does
not claim a security certification, response-time commitment, or supported-version
policy. The dated [production launch record](docs/accounts/production-launch.md)
documents deployment and off-host restore checks performed then; those records
do not certify the current state of a running service.
