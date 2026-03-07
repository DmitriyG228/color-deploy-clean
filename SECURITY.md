# Security

## Secrets

**Do not commit secrets.**

- **`terraform/terraform.tfvars`** — Contains `linode_token` (Linode/Akamai API). Create from `terraform.tfvars.example` locally; this file is gitignored.
- **`.env`** — Contains `CLOUDFLARE_TOKEN`, `GITHUB_TOKEN` (optional), and domains. Create from `.env.example` locally; this file is gitignored.

Both files are in `.gitignore`; never remove them or force-add. When cloning, copy the example files and fill in your own tokens. If a token was exposed (e.g. committed by mistake), revoke it immediately in Linode/Cloudflare/GitHub, create a new token, and update your local files; assume the old token is compromised.

## VM Hardening

Every VM is hardened automatically during `setup.sh` (Step 2/4) and can be hardened independently:

```bash
make harden-blue   # Harden a specific deployment
```

### What `harden-vm.sh` does

1. **UFW firewall**: Default deny incoming, allow 22/80/443 only. Enabled on boot.
2. **SSH key-only auth**: Disables `PasswordAuthentication`, sets `PermitRootLogin prohibit-password`.
3. **Unattended security upgrades**: Installs `unattended-upgrades` for automatic OS patching.

The script is idempotent — safe to run multiple times.

### Docker port binding

UFW does **not** protect Docker-published ports (Docker manipulates iptables directly). To secure Docker services:

- Bind ports to `127.0.0.1` in docker-compose: `"127.0.0.1:8080:8080"` instead of `"8080:8080"`
- Let Caddy reverse-proxy to `localhost:<port>` for external access
- Only ports that Caddy needs should be bound; everything else stays internal to Docker networks
