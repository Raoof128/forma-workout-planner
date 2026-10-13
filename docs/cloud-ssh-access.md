# SSH from the managed environment

[Cloud environment](cloud-environment.md) · [Deployment](deployment.md)

The published environment reports version 5, unrestricted Internet access and
an enforced policy. Direct public SSH still fails before authentication. The
supported alternative verified on 13 October 2026 is Cloudflare Tunnel with a
self-hosted Access application and client-side `cloudflared`.

## Current official documentation

- [OpenAI cloud environments: connect to services](https://learn.chatgpt.com/docs/environments/cloud-environments#connect-to-services)
  describes network settings, publication, credentials and Tailscale private
  networking. Allowing a destination does not provide credentials or service
  permissions. The current runtime's direct public TCP route remains unavailable.
- [Cloudflare SSH with client-side cloudflared](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/),
  updated 17 April 2026, documents an SSH published application and native SSH
  through a `cloudflared access ssh` proxy command. It supports an SSH server on
  a different address from the Tunnel connector.
- [Cloudflare service tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/),
  updated 2 October 2026, documents short-lived automated credentials and Service
  Auth policies. These protect the edge connection; the server still requires
  the SSH key.
- [Remote Tunnel API setup](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel-api/)
  documents ingress configuration and the required final catch-all rule.

## Verified connection

The existing `forma-staging` Tunnel was healthy. A temporary hostname was
protected by a Service Auth policy allowing only its one-hour credential. The
original API route was retained and the SSH route added before the catch-all.
Anonymous HTTP access returned 403. The checksum-verified `cloudflared` 2026.9.3
client honoured the environment's HTTPS proxy and used the existing SSH key to
log in as root. The read-only host identity probe succeeded.

Cloudflared's official client supports the `TUNNEL_SERVICE_TOKEN_ID` and
`TUNNEL_SERVICE_TOKEN_SECRET` environment variables, so the secret need not be
placed in a command line or chat. Native SSH host-key checking remains enabled;
the known-host record is kept outside the repository. TLS verification remains
enabled and the inherited proxy is retained.

The temporary Access application, credential, DNS record and ingress were
removed after the probe, and the scoped infrastructure token revoked. This does
not leave a permanent SSH endpoint. Future maintenance can recreate a temporary
protected route using the existing infrastructure credentials. Never publish
an unprotected SSH route or change unrelated Tunnel ingress, host firewalls or
backend services to repair sandbox access.
