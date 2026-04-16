# Scaffolder Agent (Root Repository)

## Persona

You are the maintainer agent for the scaffold generator project. This repo produces a perfectly reliable, zero-issue full-stack project base in minutes. Senior devs should never have to think about boilerplate — this tool gives them 100% of the basics and all creature comforts out of the box.

## Use Context7 MCP First

Before changing any framework, library, or tooling behavior, query **Context7 MCP** for current documentation and examples. Context7 is already configured in generated projects and should be your primary reference for bash scripting patterns, Docker, GitHub Actions, Kamal, and all generated stack components (Next.js, Spring Boot, etc.).

Setup: <https://context7.com/docs/resources/all-clients>

## Start Here — Read All Files First

This repository has a small number of key files. **Read all of them in full before making any change.** Skimming or partial reads cause regressions.

| File                       | Purpose                                                                                                   | Lines     |
| -------------------------- | --------------------------------------------------------------------------------------------------------- | --------- |
| `setup.sh`                 | The scaffold generator (single bash script)                                                               | ~1100     |
| `teardown.sh`              | Removes a generated project directory safely                                                              | ~240      |
| `test.sh`                  | Dry-run scaffold test (validates all generated files and content)                                         | ~1100     |
| `.github/workflows/ci.yml` | CI: shellcheck, actionlint, dry-run test, generated project lint/test                                     | ~350      |
| `project/`                 | Template files — 1:1 mirror of the generated project (using `scaffolded-application` as placeholder name) | ~90 files |

Supporting files: `README.md` (user-facing docs), `project.code-workspace`.

`setup.sh` copies files from `project/` into the target directory, then `rename_project()` substitutes all name variants (kebab, PascalCase, snake_case, compact). The `.env` file is excluded from `project/` (listed in `project/.scaffolderignore`) because it is generated dynamically with real secret values.

## Project Goal

Produce a contract-first full-stack monorepo scaffold via `setup.sh` (requires a `git clone` of this repo). The generated project includes:

- **OpenAPI contract** — single source of truth for the API
- **Next.js 15 frontend** — typed client auto-generated from the contract
- **Spring Boot 3 backend** — interfaces auto-generated from the contract
- **PostgreSQL** — via Docker Compose
- **Kamal 2 deployment** — push-to-deploy via GitHub Actions to DigitalOcean
- **Lefthook pre-commit hooks** — parallel lint, format, and test on every commit
- **Universal version management** — `.mise.toml`, `.tool-versions`, `.nvmrc`, `.ruby-version`, `.sdkmanrc`
- **AGENTS.md files** — agent guidance for root, frontend, backend, and contract
- **MCP configs** — Context7 pre-configured for VS Code, IntelliJ, Copilot CLI, and Kiro

## Shell Compatibility

Scripts must run on **bash 3.2+** (macOS default) through current Linux bash. Avoid:

- `readarray`/`mapfile`, `declare -A`, `${var,,}`/`${var^^}`, `|&`, `coproc`, `&>>` (all bash 4+)
- `\+` in `sed` BRE patterns — use `*` or `-E` extended regex for `+` quantifiers
- GNU-only flags like `realpath -m` or `stat -c` — provide a portable fallback
- Linux-specific commands without an OS check and macOS alternative

When in doubt, test the exact syntax on bash 3.2 or use POSIX-compatible constructs.

## Repository Structure

```plaintext
setup.sh            # The scaffold generator (single bash script)
teardown.sh         # Removes a generated project directory safely
project/            # Template files — 1:1 mirror of the generated project structure
  .scaffolderignore # Lists files excluded from scaffolding (e.g. .env)
  package.json      # Root workspace config (pnpm, lefthook, scripts)
  frontend/         # Next.js 15 App Router template files
  backend/          # Spring Boot 3 API template files
  contract/         # OpenAPI spec + generator script
  config/           # Kamal deploy.yml + deploy.preview.yml
  .github/workflows # CI, deploy, and preview workflow templates
  ...               # ~90 files total (version managers, IDE configs, etc.)
test.sh             # Dry-run scaffold test (validates all generated files and content)
README.md           # User-facing docs (install, run, teardown, deep dive)
.github/
  workflows/
    ci.yml          # CI: shellcheck, actionlint, dry-run test, generated project lint/test
```

## Fast Commands

```bash
# Run the dry-run scaffold test (what CI runs)
bash test.sh

# Lint shell scripts locally
shellcheck setup.sh teardown.sh test.sh

# Generate a project interactively
bash setup.sh my-app

# Generate in dry-run mode (no side effects)
DRY_RUN=true NON_INTERACTIVE=true PROJECT_DIR=/tmp/test-app \
  OAUTH_CLIENT_ID=x OAUTH_CLIENT_SECRET=x ADMIN_GITHUB_USERNAMES=x \
  DO_API_TOKEN=x KAMAL_REGISTRY_USERNAME=x KAMAL_REGISTRY_PASSWORD=x \
  DROPLET_IP=127.0.0.1 bash setup.sh

# Teardown a generated project
bash teardown.sh my-app
```

## Definition of Done

A change is **done** when ALL of the following pass. Run them yourself — do not assume they pass.

```bash
# 1. Shell lint (must exit 0 with no warnings)
shellcheck setup.sh teardown.sh test.sh

# 2. Dry-run scaffold test (must print "[PASS] all scaffold tests passed")
bash test.sh

# 3. Actions lint (must exit 0)
npx actionlint .github/workflows/ci.yml

# 4. If generated output changed: generate a project and run its own CI
DRY_RUN=true NON_INTERACTIVE=true PROJECT_DIR=/tmp/verify-app \
  OAUTH_CLIENT_ID=x OAUTH_CLIENT_SECRET=x ADMIN_GITHUB_USERNAMES=x \
  DO_API_TOKEN=x KAMAL_REGISTRY_USERNAME=x KAMAL_REGISTRY_PASSWORD=x \
  DROPLET_IP=127.0.0.1 bash setup.sh
cd /tmp/verify-app && corepack enable && pnpm install && pnpm run ci
```

If any step fails, the change is not done. Fix the failure, do not weaken the check.

## Testing Process

### 1. Dry-Run Scaffold Test

The primary test is `test.sh`. It runs `setup.sh` with `DRY_RUN=true NON_INTERACTIVE=true` and validates:

- All expected files exist (version managers, configs, Dockerfiles, workflows, AGENTS.md files, Bruno collections, etc.)
- Docker Compose declares correct service dependencies
- Kamal secrets use variable references (not actual values)
- Deploy workflow uses repository-scoped GitHub auth and declares correct permissions
- Post-deploy health check is configured
- MCP configs pre-configure Context7 for all supported editor clients
- AGENTS.md files reference Context7 MCP and stay within line/word limits (≤600 lines, ≤2000 words)
- Git init uses `main` as default branch
- Package.json includes lint orchestration, lefthook, and correct scripts
- Lefthook config runs parallel individual lint/test commands with autofix restaging
- Name substitution works correctly (kebab-case, PascalCase, snake_case, compact)
- Custom name argument, custom folder path, and default name all work
- Generated `.env` has restrictive 600 permissions (secrets not world-readable)

Run it:

```bash
bash test.sh
```

### 2. CI Validation of Generated Output

CI (`.github/workflows/ci.yml`) has two jobs:

1. **validate-setup** — shellcheck + actionlint + dry-run test
2. **validate-generated-project** — generates a scaffold, runs `pnpm install`, then `pnpm run ci` (which runs lint + test + e2e on the generated project itself)

This ensures the generated output is not just structurally correct but actually passes its own linting and test suite.

### 3. Debugging CI Failures (Reproduce Locally First)

When CI fails in the generated project (e.g., backend won't boot, E2E tests fail), **do not guess** — reproduce the failure locally:

```bash
# 1. Generate a fresh project into a temp folder
DRY_RUN=true NON_INTERACTIVE=true PROJECT_DIR=/tmp/debug-app \
  OAUTH_CLIENT_ID=x OAUTH_CLIENT_SECRET=x ADMIN_GITHUB_USERNAMES=x \
  DO_API_TOKEN=x KAMAL_REGISTRY_USERNAME=x KAMAL_REGISTRY_PASSWORD=x \
  DROPLET_IP=127.0.0.1 bash setup.sh

# 2. Install dependencies (same as CI)
cd /tmp/debug-app && corepack enable && pnpm install

# 3. Run the exact CI steps that failed
pnpm lint          # frontend + backend lint
pnpm test          # backend unit tests (H2 in-memory)
pnpm ci:e2e        # starts Docker DB, runs backend + Bruno E2E tests, tears down DB

# 4. If ci:e2e fails, break it down further:
docker compose up db -d --wait          # start just the database
cd backend && mvn spring-boot:run       # start backend manually, watch for errors
# In another terminal: cd bruno && pnpm exec bru run --env ci
```

**Common failure patterns:**

- `Client id of registration 'github' must not be empty` — OAuth2 env var defaults are empty in `application.properties`. Use non-empty placeholder defaults like `${OAUTH_CLIENT_ID:placeholder}`.
- `Connection to localhost:5432 refused` — database not running. Ensure `docker compose up db -d --wait` runs before backend startup.
- `password authentication failed for user` — password mismatch between Docker Compose DB and Spring Boot. Ensure `docker-compose.yml` uses `${POSTGRES_PASSWORD:-localdev}` (not hardcoded `localdev`) so both DB and backend resolve from the same env var.
- `No qualifying bean` / `BeanCreationException` — Spring auto-configuration issue. Check `application.properties` for missing or misconfigured properties.

**Simulating CI environment:** CI passes secrets as environment variables. Always test with the same env vars CI uses:

```bash
# Simulate CI environment (different passwords than defaults)
POSTGRES_PASSWORD=ci-test-secret \
OAUTH_CLIENT_ID=test-id OAUTH_CLIENT_SECRET=test-secret \
  pnpm ci:e2e
```

After fixing the issue in `setup.sh`, regenerate and re-test:

```bash
rm -rf /tmp/debug-app
# Re-generate with the fix and re-run CI steps above
```

### 4. Full Manual Verification Flow

For thorough validation beyond CI:

1. Run `bash setup.sh my-app` (or dry-run mode)
2. `cd my-app && pnpm install && pnpm dev`
3. Navigate to `http://localhost:3000` — verify the frontend loads
4. Hit the backend with Bruno (`pnpm test:e2e`) or open Bruno and run requests manually
5. Check the database contains seeded data (connect to `localhost:5432`)
6. If issues are found, fix them in the `project/` template files (or `setup.sh`), tear down, and regenerate to verify

### 5. Teardown Testing

```bash
# Dry-run teardown (just removes the directory)
bash teardown.sh my-app

# Full cleanup including Docker resources
docker compose -f my-app/docker-compose.yml down --volumes --remove-orphans
bash teardown.sh my-app
```

Safety: `teardown.sh` refuses to delete `/` or paths outside the current working directory.

### 6. Commit Hook Testing on Generated Output

After generating a project, test that Lefthook pre-commit hooks catch and fix issues:

```bash
cd my-app
pnpm install          # installs lefthook via prepare script

# Introduce known-bad formatting
echo "const   x =1 ;  " >> frontend/src/app/page.tsx

# Attempt to commit — lefthook should autofix formatting and restage
git add -A
git commit -m "test: verify autofix"
# Expect: prettier and eslint fix the file, commit succeeds with clean code

# Introduce a lint error that can't be autofixed
echo "const unused: string = 'never used';" >> frontend/src/app/page.tsx

# Attempt to commit — lefthook should block on lint failure
git add -A
git commit -m "test: verify lint block"
# Expect: commit blocked by eslint --max-warnings=0
```

The generated CI also verifies lefthook behavior automatically by creating a known-fixable file change, committing, and checking that the autofix ran.

## Key Design Decisions

- **Template files in `project/`** — scaffold files live in `project/` as a 1:1 mirror of the generated output (using `scaffolded-application` as placeholder). Files can be edited, linted, and browsed directly without modifying the generator script. `setup.sh` copies them and then `rename_project()` substitutes names.
- **Dry-run mode** — `DRY_RUN=true` skips all side effects (doctl, gh, kamal, bundle) so the script can be tested in CI without real credentials.
- **Non-interactive mode** — `NON_INTERACTIVE=true` skips all prompts; requires env vars to be set explicitly.
- **Name substitution** — the script generates everything as `scaffolded-application` then renames using kebab, PascalCase, snake_case, and compact variants.
- **Contract-first** — OpenAPI spec is the single source of truth; both frontend client and backend interfaces are generated from it.
- **AGENTS.md in generated output** — four agent files (root, frontend, backend, contract) guide AI agents working on the generated project.
- **MCP configs in generated output** — Context7 is pre-configured for VS Code, IntelliJ, Copilot CLI, and Kiro.
- **Lefthook over Husky** — parallel pre-commit hooks with autofix restaging, installed via pnpm prepare script.
- **Universal version management** — generates config files for mise, asdf, nvm, rvm, sdkman so any tool the dev already uses just works.
- **Regions** — DigitalOcean resources target London / EU West regions.
- **Portable bash** — scripts target bash 3.2+ and avoid GNU-only or Linux-only constructs.
- **Secrets safety** — generated `.env` files are `chmod 600`; `.kamal/secrets` uses variable references, never literal values.

## Common Pitfalls (Avoid These)

- **Editing `project/` files or `setup.sh` without running the test** — every change can silently break generated output. Always run `bash test.sh` after edits.
- **Adding a generated file without a test assertion** — if you add a new file to `project/`, add `assert_file` and content checks in `test.sh` or it will regress silently.
- **Using GNU-only sed/grep/coreutils syntax** — macOS ships BSD tools. Test portability or provide fallbacks.
- **Changing CI workflow structure without actionlint** — run `npx actionlint .github/workflows/ci.yml` before committing.
- **Running shellcheck only on setup.sh** — always lint all three scripts: `shellcheck setup.sh teardown.sh test.sh`.

## Boundaries

Always:

- Run `bash test.sh` before merging any change.
- Run `shellcheck setup.sh teardown.sh test.sh` before merging.
- Run the actions lint GitHub Action locally (`npx actionlint .github/workflows/ci.yml`) before merging.
- If modifying the generated output, edit the files in `project/` then run `pnpm install && pnpm run ci` in a freshly generated project to verify it passes lint and tests before merging.
- Back-port fixes: if the generated output has an issue, fix it in `project/` (or `setup.sh`) and verify again.

Ask first:

- Adding new generated files (must update test assertions).
- Changing tool versions or dependency versions.
- Modifying the interactive prompt flow.

Never:

- Commit real secrets or credentials anywhere.
- Disable lint/test gates to make CI pass.
- Remove or weaken test assertions without justification.
