# Cloud environment startup and networking

[Getting started](getting-started.md) · [Deployment](deployment.md)

The managed checkout is `/workspace/forma-workout-planner`. Use Node 24 and
`npm ci`. The environment snapshot retains installed dependencies and browser
artifacts; it does not retain running Vite, test API or PostgreSQL processes.
Start the guest UI with `VITE_ACCOUNT_MODE=guest npm run dev -- --host 127.0.0.1`.
Local guest mode needs no account credentials. For API tests, use only an
isolated disposable database and the documented account test harness.

## HTTP access

In the environment editor, change Internet access from the package-manager
preset to unrestricted/all domains if that option is available. Save the
configuration, publish the environment, and select that published version for
a new task. A saved draft is not an active version. Existing tasks can still
report the older version; check the selected version rather than assuming a
draft save changed it.

For a restricted configuration, retain existing destinations and add
`api.cloudflare.com`, `forma.raoufabedini.dev`,
`forma-staging.raoufabedini.dev`, `forma-api-staging.raoufabedini.dev`,
`wger.de`, `github.com`, `api.github.com`, `raw.githubusercontent.com`, and the
Playwright download hosts. Node fetch requires `NODE_USE_ENV_PROXY=1` for the
inherited HTTP proxy. Preserve TLS verification and the environment CA trust.

## SSH access is separate

Unrestricted HTTP access does not enable raw TCP or SSH. The documented managed
TCP route uses a sidecar VPN, explicit TCP grants, and a private destination
address. This environment reports no VPN and no TCP grants. Its tooling can
save HTTP destinations but cannot enable a public SSH route. A public Droplet
cannot be reached through the private-address-only VPN route as it stands.

Use an environment with public TCP egress, or configure a supported private VPN
route to the owned server and its corresponding TCP grant, then publish and
start a replacement environment. Do not edit the policy snapshot, remove proxy
settings, or change the Droplet's firewall to work around missing sandbox egress.
Successful SSH from a Mac proves that Mac's connection path only.

The provided key is stored outside the public checkout in the local environment
file with restricted permissions. Use the existing binding without printing or
committing it. A connection refusal occurs before key authentication, so it
does not establish whether this key matches the server. After transport works,
verify host identity and inspect only the FORMA stack before making changes.

The local helper `node /workspace/forma-ssh.mjs` reads the existing binding,
creates a temporary mode-0600 key, runs read-only host identity commands, and
removes the temporary key. Its known-host file stays outside the checkout.
It cannot create a network route; run it again after a supported route is active.

The published environment now reports unrestricted access as enforced. A
temporary Cloudflare Access SSH route was subsequently verified from this
sandbox and removed after use. See [the verified SSH method](cloud-ssh-access.md)
for the current official documentation and authentication requirements.
