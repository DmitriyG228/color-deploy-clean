# Security

**Do not commit secrets.**

- **`terraform/terraform.tfvars`** — Contains `linode_token` (Linode/Akamai API). Create from `terraform.tfvars.example` locally; this file is gitignored.
- **`.env`** — Contains `CLOUDFLARE_TOKEN`, `GITHUB_TOKEN` (optional), and domains. Create from `.env.example` locally; this file is gitignored.

Both files are in `.gitignore`; never remove them or force-add. When cloning, copy the example files and fill in your own tokens. If a token was exposed (e.g. committed by mistake), revoke it immediately in Linode/Cloudflare/GitHub, create a new token, and update your local files; assume the old token is compromised.
