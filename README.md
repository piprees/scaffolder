# Scaffolder

```plaintext
 ░▒▓███████▓▒░░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓████████▓▒░▒▓████████▓▒░▒▓██████▓▒░░▒▓█▓▒░      ░▒▓███████▓▒░░▒▓████████▓▒░▒▓███████▓▒░
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
 ░▒▓██████▓▒░░▒▓█▓▒░      ░▒▓████████▓▒░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓██████▓▒░ ░▒▓███████▓▒░
       ░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
       ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓██████▓▒░░▒▓████████▓▒░▒▓███████▓▒░░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░
```

A contract-first full-stack scaffold generator for monorepo projects with frontend, backend, and deployment config.

---

## What Is This?

Scaffolder generates a ready-to-use monorepo with:

- **OpenAPI contract** - single source of truth for your API
- **Next.js frontend** - typed client auto-generated from the contract
- **Spring Boot backend** - interfaces auto-generated from the contract
- **PostgreSQL** - via Docker Compose
- **Kamal deployment** - push-to-deploy via GitHub Actions
- **Universal language version management** - works with mise, asdf, nvm, rvm, sdkman, or whichever tool you already use
- **pnpm workspaces** - monorepo package management

```plaintext
+-------------------------------------------------------+
|                                                       |
|   OpenAPI Contract                                    |
|        |                                              |
|        +----------> Frontend Typed Client (TS)        |
|        |                                              |
|        +----------> Spring Boot Interfaces (Java)     |
|                          |                            |
|                          +------> PostgreSQL          |
|                                                       |
+-------------------------------------------------------+
```

---

## Prerequisites

You need the following tools installed before running `setup.sh`. Each section shows install options for every common workflow.

### Docker

| Method   | Command                               |
| -------- | ------------------------------------- |
| Direct   | <https://docs.docker.com/get-docker/> |
| Homebrew | `brew install --cask docker`          |

### GitHub CLI (`gh`)

| Method   | Command                                        |
| -------- | ---------------------------------------------- |
| Direct   | <https://cli.github.com/>                      |
| Homebrew | `brew install gh`                              |
| mise     | `mise use -g gh`                               |
| asdf     | `asdf plugin add gh && asdf install gh latest` |

### DigitalOcean CLI (`doctl`)

| Method   | Command                                                                                           |
| -------- | ------------------------------------------------------------------------------------------------- |
| Direct   | <https://docs.digitalocean.com/reference/doctl/>                                                  |
| Homebrew | `brew install doctl`                                                                              |
| mise     | `mise use -g doctl@1.154.0`                                                                       |
| asdf     | `asdf plugin add doctl https://github.com/bstoutenburgh/asdf-doctl && asdf install doctl 1.154.0` |

### Node.js

> The scaffold generates `.nvmrc`, `.mise.toml`, and `.tool-versions` so **any** Node version manager activates the correct version automatically.

| Method   | Command                                                 |
| -------- | ------------------------------------------------------- |
| mise     | `mise use -g node@24.14.1`                              |
| asdf     | `asdf plugin add nodejs && asdf install nodejs 24.14.1` |
| nvm      | `nvm install 24.14.1 && nvm use 24.14.1`                |
| Homebrew | `brew install node@24`                                  |

### pnpm

| Method   | Command                                                       |
| -------- | ------------------------------------------------------------- |
| corepack | `corepack enable && corepack prepare pnpm@10.33.0 --activate` |
| npm      | `npm install -g pnpm`                                         |
| Homebrew | `brew install pnpm`                                           |

### Java

> The scaffold generates `.sdkmanrc` and a `.mise.toml` entry so mise, asdf, or SDKMan activate the correct JDK automatically.

| Method   | Command                                                          |
| -------- | ---------------------------------------------------------------- |
| mise     | `mise use -g java@corretto-25.0.2.10.1`                          |
| asdf     | `asdf plugin add java && asdf install java corretto-25.0.2.10.1` |
| SDKMan   | `sdk install java 25.0.2.10.1-amzn`                              |
| Homebrew | `brew install --cask corretto`                                   |

### Ruby

> The scaffold generates `.ruby-version` so mise, asdf, rvm, or rbenv activate the correct Ruby version automatically.

| Method   | Command                                           |
| -------- | ------------------------------------------------- |
| mise     | `mise use -g ruby@4.0.2`                          |
| asdf     | `asdf plugin add ruby && asdf install ruby 4.0.2` |
| rvm      | `rvm install 4.0.2 && rvm use 4.0.2`              |
| rbenv    | `rbenv install 4.0.2 && rbenv global 4.0.2`       |
| Homebrew | `brew install ruby`                               |

After installing Ruby, install Bundler:

```bash
gem install bundler -v 4.0.10
```

### Context 7

If you are using an AI harness like copilot, this project benefits from using Context7.

Head to this link to get set up.
<https://context7.com/docs/resources/all-clients>

---

## Install & Run

Clone the repository and run `setup.sh` with your chosen app name:

```bash
git clone https://github.com/piprees/scaffolder.git ~/projects/scaffolder
cd ~/projects/scaffolder
bash ./setup.sh my-cool-app
```

If you omit the name the project is generated as `scaffolded-application`:

```bash
bash ./setup.sh
```

> **Note**: `setup.sh` requires the `project/` directory alongside it (the template files for the generated scaffold). A bare `curl | bash` of the script alone will not work — always clone the repo first.

The script will:

1. Check that all required tools are present (and tell you exactly how to install any that are missing)
2. Prompt you interactively for your credentials (GitHub OAuth app, DigitalOcean API token, registry credentials, and droplet details)
3. Provision a new droplet when `DROPLET_IP` is not provided, then apply baseline server patching/hardening (Ubuntu package upgrades, unattended upgrades, fail2ban, UFW allowing 22/80/443, and SSH key-only root access)
4. Generate the full project scaffold in `./<app-name>` with all names (`package.json`, Java packages, Docker services, etc.) replaced to match your chosen name
5. Initialise a git repository inside the new project and run `pnpm install` (which triggers code generation from the OpenAPI contract)

Before the droplet prompts, `setup.sh` runs:

```bash
doctl compute size list
```

Use one of the returned slugs (for example `s-1vcpu-1gb`) as `DROPLET_SIZE`.

### Running the Generated App

Once setup completes:

```bash
cd my-cool-app
pnpm install
pnpm dev
```

The app will be available at:

- **Frontend** - <http://localhost:3000>
- **Backend** - <http://127.0.0.1:8080>
- **Database** - <http://localhost:5432>

### Running Tests

```bash
cd my-cool-app
pnpm test
```

### Custom Output Directory

You can override the output directory with the `PROJECT_DIR` environment variable (the app name is derived from the directory's basename):

```bash
PROJECT_DIR=/path/to/my-project bash ./setup.sh
```

### Non-Interactive (CI / Automation)

Export your credentials first, then run with `NON_INTERACTIVE=true`:

```bash
export OAUTH_CLIENT_ID=xxx
export OAUTH_CLIENT_SECRET=yyy
export ADMIN_GITHUB_USERNAMES=alice,bob
export DO_API_TOKEN=zzz
export KAMAL_REGISTRY_USERNAME=myuser
export KAMAL_REGISTRY_PASSWORD=mytoken
export DROPLET_SIZE=s-1vcpu-1gb
export DROPLET_IP=1.2.3.4

NON_INTERACTIVE=true bash ./setup.sh
```

`setup.sh` only reads pre-existing values from `<PROJECT_DIR>/.env` (when present), and does not import `.env` from the directory where you invoke the generator.

For CI logs, you can suppress the large ASCII headers:

```bash
SETUP_COMPACT_OUTPUT=1 NON_INTERACTIVE=true bash ./setup.sh
```

### Environment Variables

| Variable                  | Description                                                                  |
| ------------------------- | ---------------------------------------------------------------------------- |
| `$1` (argument)           | App name / folder name (default: `scaffolded-application`)                   |
| `PROJECT_DIR`             | Override output directory; app name is derived from the directory's basename |
| `DRY_RUN`                 | Skip side effects (`true`/`false`)                                           |
| `NON_INTERACTIVE`         | Disable interactive prompts                                                  |
| `SETUP_COMPACT_OUTPUT`    | Compact logs by omitting ASCII headers (`1` to enable)                       |
| `OAUTH_CLIENT_ID`         | GitHub OAuth client ID                                                       |
| `OAUTH_CLIENT_SECRET`     | GitHub OAuth client secret                                                   |
| `ADMIN_GITHUB_USERNAMES`  | Comma-separated admin usernames                                              |
| `DO_API_TOKEN`            | DigitalOcean API token                                                       |
| `KAMAL_REGISTRY_USERNAME` | GHCR username for image registry, e.g; `myname`                              |
| `KAMAL_REGISTRY_PASSWORD` | GHCR token / password                                                        |
| `DROPLET_SIZE`            | DigitalOcean droplet size slug (from `doctl compute size list`)              |
| `DROPLET_IP`              | Target deployment host IP                                                    |
| `DROPLET_TAG`             | Droplet tag used for on-demand IP lookup                                     |
| `APP_HOSTNAME`            | Custom domain (optional; enables TLS + clean preview URLs)                   |

---

## Teardown & Cleanup

Once generated, your project is fully standalone — use the **project's own** `teardown.sh` to clean up:

```bash
cd my-cool-app
bash teardown.sh
```

This will:

- Remove the Kamal deployment (`kamal remove`)
- Tear down Docker Compose resources (volumes, containers)
- Clean up DigitalOcean DNS `A` records for `APP_HOSTNAME` (`@` and `*.preview`) when `DO_API_TOKEN` is available
- Attempt droplet deletion via `doctl` (prefers `DROPLET_ID`, then `DROPLET_TAG`, then `DROPLET_IP`)
- Remove build artifacts (`node_modules`, `target`, `generated` dirs)
- Load env values from the project's own `.env`

To preview what teardown would do without actually running it:

```bash
cd my-cool-app
DRY_RUN=true bash teardown.sh
```

> **Note:** The root scaffolder also ships a `teardown.sh`, but it relies on the root `.env` which may diverge from your generated project's `.env` after local changes. Always prefer the generated project's teardown script.

After teardown you can re-run `setup.sh` at any time to start fresh.

---

## Deep Dive

### What Gets Generated

```plaintext
<app-name>/
  .mise.toml              # language versions (mise / asdf / nvm / rvm / sdkman)
  .tool-versions          # language versions (asdf)
  .nvmrc                  # Node version (nvm)
  .ruby-version           # Ruby version (rvm / rbenv)
  .sdkmanrc               # Java version (SDKMan)
  .editorconfig
  .prettierrc
  .lefthook.yml           # git pre-commit automation (autofix + tests)
  .gitignore
  .env                    # secrets (git-ignored)
  pnpm-workspace.yaml
  package.json
  docker-compose.yml
  Gemfile                 # kamal + ruby deps
  teardown.sh             # local env teardown
  README.md
  contract/
    openapi.yml           # API contract (source of truth)
    generate.sh           # code generation script
  frontend/               # Next.js app
  backend/                # Spring Boot app
  .kamal/                 # Kamal deployment secrets/hooks
  config/
    deploy.yml            # Kamal deployment config
    deploy.preview.yml    # Kamal preview destination (PR environments)
  .github/
    workflows/
      ci.yml              # GitHub Actions CI
      deploy.yml          # GitHub Actions deploy (Kamal)
      preview.yml         # GitHub Actions preview environments (per PR)
  .vscode/               # editor settings, tasks, extension recommendations, MCP config
  .idea/                 # IntelliJ code style/run configs + MCP config
  .copilot/              # Copilot CLI MCP config
  .kiro/                 # Kiro MCP + workspace settings/tasks
```

### Language Version Manager Compatibility

The scaffold works with **any** language version manager. The following config files are generated so each tool activates the correct versions automatically - no switching required:

| File             | Tool(s)                       |
| ---------------- | ----------------------------- |
| `.mise.toml`     | mise                          |
| `.tool-versions` | asdf, mise                    |
| `.nvmrc`         | nvm, mise, asdf (node plugin) |
| `.ruby-version`  | rvm, rbenv, mise, asdf        |
| `.sdkmanrc`      | SDKMan, mise                  |

### Contract-First Workflow

1. Edit `contract/openapi.yml` to add or modify API endpoints
2. Run `pnpm generate` to regenerate the typed frontend client and Spring interfaces
3. Implement the generated backend interface methods
4. Use the regenerated frontend client in your components

### Pre-Commit Automation in Generated Projects

Generated projects include [Lefthook](https://github.com/evilmartians/lefthook), installed automatically during `pnpm install` via the `prepare` script.

On every commit, the pre-commit hook runs individual linter and test commands in parallel.
Autofix commands (`pnpm prettier:write`, `pnpm spotless:apply`, `pnpm lint:frontend:fix`) restage changed files automatically.

If tests fail, the commit is blocked.

### How Deployment Works

Deployment uses [Kamal](https://kamal-deploy.org/) and is triggered automatically by pushing to `main`:

1. GitHub Actions builds Docker images and pushes them to GitHub Container Registry (GHCR)
2. Kamal SSHes into your DigitalOcean droplet and pulls the new image
3. The app is restarted with zero downtime

The generated deploy workflow uses the repository-scoped `GITHUB_TOKEN` (`packages: write`) so images are published under your GitHub namespace for this project.

### Preview Environments (Review Apps)

Generated projects include a `preview.yml` workflow that provides fully isolated preview environments for every pull request:

1. **PR opened/updated** → deploys an isolated stack (app + database) via `kamal deploy -d preview`
2. **Preview URL** → `https://pr-{number}.preview.{APP_HOSTNAME}` (or `http://pr-{number}.{IP}.sslip.io` without a custom domain)
3. **PR closed** → tears down the preview app and database automatically

Each preview environment is completely isolated:

- **Service**: unique Kamal service per PR (`{app}-pr-{number}`)
- **Database**: dedicated Postgres container per PR (`{app}_pr_{number}`)
- **Routing**: kamal-proxy routes by subdomain via custom domain or [sslip.io](https://sslip.io) fallback
- **Infrastructure**: reuses the same droplet provisioned during setup

**Required repository secrets** (in addition to existing deploy secrets):

| Secret              | Description                                        |
| ------------------- | -------------------------------------------------- |
| `DROPLET_IP`        | IP of the droplet (already known from setup)       |
| `POSTGRES_PASSWORD` | Database password for preview instances            |
| `APP_HOSTNAME`      | Custom domain (optional; enables TLS + clean URLs) |

**How it works**:

- `config/deploy.preview.yml` is a [Kamal destination](https://kamal-deploy.org/docs/configuration/overview/) config that overrides the service name, adds proxy host routing, and adds a Postgres accessory - all parameterized by `PR_NUMBER`
- The workflow uses `concurrency: preview-{pr}` so subsequent pushes to the same PR update the existing preview (no duplicates)
- Teardown uses `continue-on-error: true` to ensure cleanup completes even if a step fails

**Custom domain vs sslip.io**:

| Mode                   | Preview URL                        | TLS                     | DNS required                          |
| ---------------------- | ---------------------------------- | ----------------------- | ------------------------------------- |
| With `APP_HOSTNAME`    | `https://pr-N.preview.example.com` | ✅ Let's Encrypt (auto) | Wildcard `*.preview.example.com → IP` |
| Without `APP_HOSTNAME` | `http://pr-N.{IP}.sslip.io`        | ❌                      | None                                  |

When you set `APP_HOSTNAME` during setup, the script automatically configures DNS if your domain is managed via DigitalOcean DNS. For other DNS providers, it prints the required records:

```plaintext
A    @            → {DROPLET_IP}
A    *.preview    → {DROPLET_IP}
```

**Assumptions and caveats**:

- Preview environments share the same droplet as production - monitor resource usage for many concurrent PRs
- For sslip.io mode: preview URLs are HTTP only
- Each preview Postgres instance uses disk space; stale environments are cleaned up on PR close
- SSH always uses the droplet IP directly (not the hostname) for reliability

---

## Running Tests (this repository)

```bash
# Run the dry-run scaffold test
bash test.sh
```

The test runs `setup.sh` in `DRY_RUN=true NON_INTERACTIVE=true` mode and validates that all expected files are generated correctly.

---

## Real Deployment CI (this repository)

This repository includes a `smoke` job in `.github/workflows/ci.yml`, which runs with the rest of CI on **every pull request**, on pushes to `main`, and on manual dispatch. It runs `setup.sh` with `DRY_RUN=false` to provision a temporary DigitalOcean droplet, deploy the full stack, run lint/tests/e2e, API + Bruno checks, and a Playwright screenshot. Everything is torn down (including the droplet) even if a step fails.

Cleanup is centralized in the generated project's `teardown.sh`, which now handles `kamal remove` and optional droplet deletion (prefers `DROPLET_ID`, then `DROPLET_TAG`, then `DROPLET_IP`) with `DRY_RUN` support.

Required repository secrets:

- `DO_API_TOKEN`
- `DROPLET_SSH_KEY_FINGERPRINT`
- `DROPLET_SSH_PRIVATE_KEY`
- `OAUTH_CLIENT_ID`
- `OAUTH_CLIENT_SECRET`
- `ADMIN_GITHUB_USERNAMES`
- `POSTGRES_PASSWORD`

Optional repository variables (with defaults if unset):

- `DROPLET_REGION` (default `lon1`)
- `DROPLET_IMAGE` (default `ubuntu-24-04-x64`)

Optional repository secrets:

- `APP_HOSTNAME` - custom domain; enables TLS + clean preview URLs (see [Custom Domain Setup](#custom-domain-setup) below)

---

## Environment Variable Walkthrough

This section walks through every environment variable, how to obtain each one, and which are required vs optional. Two scenarios are covered:

1. **Deploying a real generated app** - you ran `setup.sh`, generated a project, and want to deploy it to production
2. **Enabling Real Deployment CI** - you want the `piprees/scaffolder` repository itself to run the live smoke test on every PR

### Variable Reference

| Variable                       | Required?                                   | Type     | Where to get it                                                                       |
| ------------------------------ | ------------------------------------------- | -------- | ------------------------------------------------------------------------------------- |
| `DO_API_TOKEN`                 | **Required**                                | Secret   | DigitalOcean API token                                                                |
| `OAUTH_CLIENT_ID`              | **Required**                                | Secret   | GitHub OAuth app client ID                                                            |
| `OAUTH_CLIENT_SECRET`          | **Required**                                | Secret   | GitHub OAuth app client secret                                                        |
| `ADMIN_GITHUB_USERNAMES`       | **Required**                                | Secret   | Comma-separated GitHub usernames                                                      |
| `KAMAL_REGISTRY_USERNAME`      | Optional                                    | Variable | GHCR username (defaults to `github.actor` if not set)                                 |
| `KAMAL_REGISTRY_PASSWORD`      | **Required**                                | Secret   | GitHub personal access token (PAT) or `GITHUB_TOKEN`                                  |
| `DROPLET_SIZE`                 | **Required**                                | Variable | DigitalOcean droplet size slug                                                        |
| `DROPLET_SSH_PRIVATE_KEY_PATH` | Optional                                    | Variable | Local path to private key file (used by setup.sh to load key + infer fingerprint)     |
| `DROPLET_SSH_KEY_FINGERPRINT`  | Optional                                    | Secret   | SSH key fingerprint registered with DigitalOcean (auto-inferred when key path is set) |
| `DROPLET_SSH_PRIVATE_KEY`      | **Required** (for deploy workflows)         | Secret   | Private key contents for SSH access (required for CI deploy/preview/teardown)         |
| `DROPLET_IP`                   | Optional                                    | Variable | Droplet public IP (auto-provisioned if empty)                                         |
| `DROPLET_TAG`                  | Optional                                    | Variable | Droplet tag used for on-demand IP lookup in workflows/teardown                        |
| `APP_HOSTNAME`                 | Optional                                    | Variable | Custom domain name for TLS + clean URLs                                               |
| `POSTGRES_PASSWORD`            | **Required** (in generated project secrets) | Secret   | Any strong random password                                                            |
| `DROPLET_REGION`               | Optional                                    | Variable | DigitalOcean region slug (default `lon1`)                                             |
| `DROPLET_IMAGE`                | Optional                                    | Variable | DigitalOcean OS image (default `ubuntu-24-04-x64`)                                    |

> **Secrets** are stored under Settings → Secrets and variables → Actions → **Secrets** tab - they are encrypted and never visible in logs. **Variables** are stored under the **Variables** tab - they are plaintext and visible in logs, suitable for non-sensitive configuration.

### Step-by-Step: Required Variables

#### 1. `DO_API_TOKEN` - DigitalOcean API Token

1. Log in to [cloud.digitalocean.com](https://cloud.digitalocean.com)
2. Go to **API** → **Tokens** → **Generate New Token**
3. Give it a name (e.g. `my-app-deploy`), select **Read + Write** scope
4. Copy the token - you won't see it again

```bash
export DO_API_TOKEN="dop_v1_abc123..."
```

#### 2. `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET` - GitHub OAuth App

The generated app uses GitHub OAuth for user authentication. You need a GitHub OAuth app:

1. Go to [github.com/settings/developers](https://github.com/settings/developers) → **OAuth Apps** → **New OAuth App**
2. Fill in:
   - **Application name**: your app name (e.g. `my-cool-app`)
   - **Homepage URL**: `http://localhost:3000` (update to your production URL later)
   - **Authorization callback URL**: `http://127.0.0.1:8080/login/oauth2/code/github`
3. Click **Register application**
4. Copy the **Client ID**
5. Click **Generate a new client secret** and copy it immediately

```bash
export OAUTH_CLIENT_ID="Iv1.abc123..."
export OAUTH_CLIENT_SECRET="abc123secret..."
```

> **Note**: the callback URL points to the Spring Boot backend (port 8080), which handles the OAuth code exchange. In production, Kamal's proxy routes traffic from your domain to the backend automatically, so update the callback URL to `https://yourdomain.com/login/oauth2/code/github` (with `APP_HOSTNAME`) or `http://{DROPLET_IP}/login/oauth2/code/github` (without).

#### 3. `ADMIN_GITHUB_USERNAMES` - Admin Users

A comma-separated list of GitHub usernames that should have admin access in the generated app:

```bash
export ADMIN_GITHUB_USERNAMES="your-github-username"
# Multiple admins:
export ADMIN_GITHUB_USERNAMES="alice,bob,charlie"
```

#### 4. `KAMAL_REGISTRY_USERNAME` and `KAMAL_REGISTRY_PASSWORD` - Container Registry

The generated app pushes Docker images to GitHub Container Registry (GHCR). You need:

- **Username**: your GitHub username (do **not** include `ghcr.io/`)
- **Password**: a GitHub Personal Access Token (PAT) with `write:packages` scope

To create a PAT:

1. Go to [github.com/settings/tokens](https://github.com/settings/tokens) → **Generate new token (classic)**
2. Select scope: `write:packages` (and `read:packages`)
3. Copy the token

```bash
export KAMAL_REGISTRY_USERNAME="your-github-username"
export KAMAL_REGISTRY_PASSWORD="ghp_abc123..."
```

> **Note**: in GitHub Actions workflows, the generated deploy workflow uses the built-in `GITHUB_TOKEN` (`github.actor` / `secrets.GITHUB_TOKEN`) automatically - no PAT needed for CI.

#### 5. `DROPLET_SIZE` - Droplet Size

Choose a DigitalOcean droplet size. List available sizes:

```bash
doctl compute size list
```

Common choices:

| Slug          | vCPUs | RAM  | Price  |
| ------------- | ----- | ---- | ------ |
| `s-1vcpu-1gb` | 1     | 1 GB | $6/mo  |
| `s-1vcpu-2gb` | 1     | 2 GB | $12/mo |
| `s-2vcpu-2gb` | 2     | 2 GB | $18/mo |

```bash
export DROPLET_SIZE="s-1vcpu-1gb"
```

### Step-by-Step: Optional Variables

#### 6. `DROPLET_IP` - Existing Droplet

If you already have a droplet, provide its IP and the script will skip provisioning:

```bash
export DROPLET_IP="143.198.52.4"
```

If you leave this empty, `setup.sh` will auto-provision a new droplet using `doctl` (requires `DO_API_TOKEN` and either `DROPLET_SSH_KEY_FINGERPRINT` or `DROPLET_SSH_PRIVATE_KEY_PATH`).

#### 7. `DROPLET_SSH_PRIVATE_KEY_PATH` - Local SSH Key Path (Recommended)

Recommended for local runs. Point this at your private key file and `setup.sh` will:

- read the key contents for local setup convenience
- infer `DROPLET_SSH_KEY_FINGERPRINT` automatically when it is not explicitly set

```bash
export DROPLET_SSH_PRIVATE_KEY_PATH="~/.ssh/id_ed25519"
```

When using `DROPLET_SSH_PRIVATE_KEY_PATH`, `DROPLET_SSH_KEY_FINGERPRINT` is optional.

If you have not created and registered a key yet:

```bash
# Generate a key
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519

# Register its public key with DigitalOcean
doctl compute ssh-key create my-key --public-key "$(cat ~/.ssh/id_ed25519.pub)"
```

#### 8. `DROPLET_SSH_KEY_FINGERPRINT` - Manual Fingerprint Override

Optional override when you want to set the fingerprint explicitly instead of inferring it from `DROPLET_SSH_PRIVATE_KEY_PATH`.

To find your SSH key fingerprint:

```bash
# List SSH keys registered with DigitalOcean
doctl compute ssh-key list
```

Copy the fingerprint from the output:

```bash
export DROPLET_SSH_KEY_FINGERPRINT="ab:cd:ef:12:34:56:78:90:..."
```

#### 9. `APP_HOSTNAME` - Custom Domain (TLS + Clean URLs)

Optional. When set, the app uses your domain with automatic Let's Encrypt TLS:

```bash
export APP_HOSTNAME="example.com"
```

When empty, the app uses sslip.io with IP-based URLs (no TLS, but works immediately with zero DNS config).

See the [Preview Environments](#preview-environments-review-apps) section for how this affects preview URLs.

### Custom Domain Setup

**DNS setup**: if you set `APP_HOSTNAME`, you need two DNS A records pointing to your droplet:

```text
A    @            → {DROPLET_IP}       (routes example.com to your droplet)
A    *.preview    → {DROPLET_IP}       (routes pr-N.preview.example.com for preview environments)
```

The `@` record enables `https://example.com` for production. The `*.preview` wildcard enables preview URLs like `https://pr-123.preview.example.com` - each PR gets its own subdomain.

- If your domain uses **DigitalOcean DNS**, `setup.sh` creates these records automatically
- For **other DNS providers** (Cloudflare, Route 53, etc.), the script prints the records you need to add manually

#### 10. `POSTGRES_PASSWORD` - Database Password

The generated project needs a `POSTGRES_PASSWORD` secret in its GitHub repository settings for deploy and preview workflows. It can be any strong random string:

```bash
# Generate a random password
openssl rand -base64 32
```

Then add it as a **repository secret** in the generated project's GitHub settings (Settings → Secrets and variables → Actions → New repository secret).

> **Note**: for local development, the `docker-compose.yml` uses `localdev` as the password - you don't need to set anything locally.

---

#### 10. Add Repository Secrets to Your Generated App

After running `setup.sh` and pushing the generated project to GitHub, add these **repository secrets** in your project's GitHub settings (Settings → Secrets and variables → Actions → New repository secret):

**Required secrets** (deploy won't work without these):

| Secret                   | Value                                                  |
| ------------------------ | ------------------------------------------------------ |
| `OAUTH_CLIENT_ID`        | From your GitHub OAuth app (step 2 above)              |
| `OAUTH_CLIENT_SECRET`    | From your GitHub OAuth app (step 2 above)              |
| `ADMIN_GITHUB_USERNAMES` | Comma-separated admin GitHub usernames                 |
| `POSTGRES_PASSWORD`      | Any strong random password (`openssl rand -base64 32`) |

> `KAMAL_REGISTRY_USERNAME` and `KAMAL_REGISTRY_PASSWORD` are **not** needed as secrets - the deploy workflow uses `github.actor` and `secrets.GITHUB_TOKEN` automatically.

**Optional secrets** (for custom domain + preview environments):

| Secret       | Value                                                            |
| ------------ | ---------------------------------------------------------------- |
| `DROPLET_IP` | Your droplet's public IP (fallback if tag lookup is unavailable) |

**Optional variables** (Settings → Secrets and variables → Actions → **Variables** tab):

| Variable       | Value                                                               |
| -------------- | ------------------------------------------------------------------- |
| `APP_HOSTNAME` | Your custom domain (enables TLS + clean preview URLs)               |
| `DROPLET_TAG`  | Droplet tag to resolve IP dynamically (defaults to repository name) |

That's it. Push to `main` and the deploy workflow will build, push, and deploy your app via Kamal.

---

### Setting Up Real Deployment CI for This Repository

The `piprees/scaffolder` repo runs a live smoke test (`smoke` job in `.github/workflows/ci.yml`) that provisions a real droplet, deploys the full stack, runs tests, and tears everything down. To enable this:

#### 11. Generate an SSH key pair for CI

```bash
ssh-keygen -t ed25519 -C "setup-ci" -f /tmp/setup-ci-key -N ""
```

#### 12. Register the public key with DigitalOcean

```bash
doctl compute ssh-key create setup-ci --public-key "$(cat /tmp/setup-ci-key.pub)"
# Note the fingerprint from the output
```

#### 13. Add repository secrets

Go to `github.com/piprees/scaffolder` → Settings → Secrets and variables → Actions → **New repository secret**, and add:

| Secret                        | How to get it                                                           |
| ----------------------------- | ----------------------------------------------------------------------- |
| `DO_API_TOKEN`                | DigitalOcean API token (step 1 above)                                   |
| `DROPLET_SSH_KEY_FINGERPRINT` | Fingerprint from step 12                                                |
| `DROPLET_SSH_PRIVATE_KEY`     | Full contents of `/tmp/setup-ci-key` (the private key file)             |
| `OAUTH_CLIENT_ID`             | From a GitHub OAuth app (step 2 above - can be a test app)              |
| `OAUTH_CLIENT_SECRET`         | From the same GitHub OAuth app                                          |
| `ADMIN_GITHUB_USERNAMES`      | Any valid GitHub username (e.g. your own)                               |
| `KAMAL_REGISTRY_PASSWORD`     | GitHub PAT with `write:packages` scope (or use workflow `GITHUB_TOKEN`) |
| `POSTGRES_PASSWORD`           | Any strong random password (`openssl rand -base64 32`)                  |

#### 14. Add repository variables for droplet config

Go to Settings → Secrets and variables → Actions → **Variables** tab → **New repository variable**:

| Variable                  | Default            | Description                          |
| ------------------------- | ------------------ | ------------------------------------ |
| `KAMAL_REGISTRY_USERNAME` | `github.actor`     | GHCR username (your GitHub username) |
| `DROPLET_SIZE`            | `s-1vcpu-1gb`      | DigitalOcean droplet size slug       |
| `DROPLET_REGION`          | `lon1`             | DigitalOcean region                  |
| `DROPLET_IMAGE`           | `ubuntu-24-04-x64` | OS image                             |

> `KAMAL_REGISTRY_USERNAME` should be just the username/org value (no `ghcr.io/` prefix).

#### 15. (Optional) Enable custom domain in CI

If you have a domain available for testing, add it as a **repository variable** (not a secret):

| Variable       | Value                                        |
| -------------- | -------------------------------------------- |
| `APP_HOSTNAME` | Your test domain (e.g. `deploy.example.com`) |

Without `APP_HOSTNAME`, the CI test uses sslip.io URLs and skips TLS - this is perfectly valid for testing the setup script.

#### 16. Trigger a run

The CI workflow runs automatically on every PR. You can also trigger it manually: Actions → CI → Run workflow.

> **Cost note**: each CI run provisions a temporary droplet (~$0.01 per run for a `s-1vcpu-1gb` instance running for a few minutes). The droplet is always torn down in the `always()` cleanup step, even if the test fails.

---

## Troubleshooting

| Problem                            | Solution                                                                           |
| ---------------------------------- | ---------------------------------------------------------------------------------- |
| Port conflict on 3000/8080/5432    | Free the port or stop the conflicting service (`lsof -i :<port>`)                  |
| Docker not running                 | Start Docker daemon / Docker Desktop                                               |
| OAuth callback mismatch            | Confirm callback URLs match in GitHub OAuth app settings                           |
| mise not activated                 | Add `eval "$(mise activate bash)"` (or `zsh`/`fish`) to your shell profile         |
| asdf not activated                 | Add `. "$HOME/.asdf/asdf.sh"` to your shell profile                                |
| nvm not activated                  | Add `source ~/.nvm/nvm.sh` to your shell profile                                   |
| rvm not activated                  | Add `source ~/.rvm/scripts/rvm` to your shell profile                              |
| SDKMan not activated               | Add `source "$HOME/.sdkman/bin/sdkman-init.sh"` to your shell profile              |
| Wrong Node / Java / Ruby version   | `cd my-app && mise install` (or `asdf install`) to activate the pinned versions    |
| Stale local state                  | Run teardown (see above) then re-run `setup.sh`                                    |
| Missing env var in non-interactive | Export the variable explicitly before running `setup.sh`                           |
| `bundle install` fails             | Ensure Ruby is active (`ruby -v`) and bundler is installed (`gem install bundler`) |
| `pnpm install` fails               | Ensure Node ≥ 18 is active (`node -v`) and pnpm is installed                       |
| `doctl` auth error                 | Run `doctl auth init` and enter your DigitalOcean API token                        |
| `gh` auth error                    | Run `gh auth login` and follow the prompts                                         |

---

## License

See [LICENSE](LICENSE).
