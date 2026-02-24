# color-deploy

Blue/green VM deployment on Linode with DNS (Cloudflare) and SSH.

**Features**

- **Deploy color deployments** — Manage separate stacks (e.g. blue, green) for staging and production. Each color is its own VM (Terraform workspace). Deploy or destroy a color independently.
- **Setup HTTPS and SSH automatically, integrated with Cloudflare** — One command sets DNS (Cloudflare A record), installs Caddy on the VM, and obtains Let’s Encrypt SSL. After deploy, `~/.ssh/config` is updated so `ssh <PROJECT_SLUG>-<color>` works.
- **Switch DNS when ready** — Point prod or staging at any deployment with one make target. TTL 60s. Rollback by pointing DNS at the other color.

**Flow**

1. **Setup once** — `terraform/terraform.tfvars`: `linode_token`, `region`. `.env`: `PROJECT_SLUG`, `CLOUDFLARE_TOKEN`, `LIVE_DOMAIN`, `STAGING_DOMAIN`. Terraform in `PATH` or `.bin/`.
2. **Deploy** — `make init` then `make deploy-<color>` (creates VM, updates SSH config).
3. **HTTPS** — `make setup-staging-<color>` or `make setup-prod-<color>` (DNS + Caddy + SSL).
4. **Switch DNS** — `make staging-point-<color>` or `make prod-point-<color>` when ready for cutover.
5. **Rollback** — Point DNS at the other color. **Destroy:** `make destroy-<color>` is refused if prod (LIVE_DOMAIN) points at that deployment—you must run `make prod-point-<other-color>` first, then destroy.

**Commands** — `make init` | `make deploy-<color>` | `make output-<color>` | `make setup-staging-<color>` / `make setup-prod-<color>` | `make staging-point-<color>` / `make prod-point-<color>` | `make destroy-<color>` | `make status` | `make diagnose-<color>` | `make validate-<color>`. Optional: `make clone-app-<color>` (set `APP_REPO`, `GITHUB_TOKEN` in `.env`). **Validate HTTPS:** after setup run `make validate-yellow` (or `validate-<color>`); it curls `https://<STAGING_DOMAIN>/health` and runs diagnose, writes `validate-result.txt`. Quick check: `curl -sI https://test-staging.vexa.ai/health`. If ERR_SSL_PROTOCOL_ERROR, run `make diagnose-<color>` and ensure ports 80/443 are open.

**Publish (e.g. GitHub)** — Ensure `.env` and `terraform/terraform.tfvars` are never committed (see `.gitignore` and `SECURITY.md`). Then: `git init`, `git add .`, `git commit -m "Initial commit"`, create a new repo on GitHub, `git remote add origin <url>`, `git push -u origin main`.
