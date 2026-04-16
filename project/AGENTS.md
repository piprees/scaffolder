# Repository Agent (Root)

## Persona

You are the repo-level maintainer agent for this contract-first monorepo. Optimize for safe, reviewable PRs with minimal diff size.

## Use Context7 MCP First

Before implementing framework/library changes, query **Context7 MCP** for current docs/examples (already configured). Prefer Context7 over memory for Next.js, Spring Boot, Docker, Kamal, and DigitalOcean behavior.

## Fast Commands

```bash
pnpm install              # install all workspace deps + generate code
pnpm dev                  # docker compose up --build (all services)
pnpm dev:frontend         # next dev on port 3000
pnpm dev:backend          # spring-boot:run on port 8080
pnpm generate             # regenerate code from contract/openapi.yml
pnpm lint                 # prettier + eslint + checkstyle + sqlfluff + hadolint
pnpm lint:fix             # autofix variants of the above
pnpm format               # prettier:write + sortpom:sort
pnpm test                 # vitest + maven test
pnpm test:e2e             # bruno API tests against running backend
pnpm ci                   # lint + test + test:e2e (full gate)
docker compose config     # validate compose file
bundle exec kamal deploy  # deploy via Kamal 2
```

## Structure

```
├── frontend/          Next.js 15 App Router (React 19, TypeScript, Tailwind CSS 4)
├── backend/           Spring Boot 3 API (Java 25, Maven, Flyway)
├── contract/          OpenAPI spec + code generator (Redocly, swagger-cli)
├── database/          init.sql + seed.sql (mounted into Postgres container)
├── bruno/             Bruno API test collections + environments
├── config/            Kamal deploy.yml + deploy.preview.yml (destination)
├── .kamal/            Kamal secrets (variable refs) + hooks
├── .github/workflows/ CI + Deploy + Preview (kamal destinations)
├── docker-compose.yml Postgres + backend + frontend for local dev
├── .lefthook.yml      Parallel pre-commit: lint, format, test
├── teardown.sh        Remove containers, node_modules, target, vendor
├── .env / .env.example Runtime secrets (git-ignored) and template
└── pnpm-workspace.yaml Workspace: frontend, backend, contract, bruno
```

## Docker + Compose Conventions

- Multi-stage builds are used: `deps` -> `build` -> `runtime` in both `frontend/Dockerfile` and `backend/Dockerfile`.
- Frontend runs as non-root user `app`; backend runs as `appuser` (UID 1001).
- Both Dockerfiles include `HEALTHCHECK` directives.
- Keep `.dockerignore` strict to reduce build context.
- Use `depends_on: condition: service_healthy` for startup ordering when adding services.
- Avoid unnecessary port exposure; keep backend network internal where possible.

## Kamal Deployment

- Config: `config/deploy.yml`. Secrets: `.kamal/secrets` (variable refs resolved from env at deploy time).
- Hooks: `.kamal/hooks/` — non-zero exit aborts deploy.
- Deploy workflow (`.github/workflows/deploy.yml`): push to `main` -> `bundle exec kamal deploy`.
- Preview workflow (`.github/workflows/preview.yml`): PR open/sync -> `kamal deploy -d preview`; PR close -> teardown.
- Preview destination config: `config/deploy.preview.yml` (service name includes PR number for isolation).
- When `APP_HOSTNAME` is set: production uses `proxy.host` with TLS; previews use `pr-N.preview.{APP_HOSTNAME}` with Let's Encrypt.
- When `APP_HOSTNAME` is empty: previews fall back to `pr-N.{IP}.sslip.io` (HTTP, no DNS config needed).
- Core commands: `kamal setup`, `kamal deploy`, `kamal deploy --skip-push`, `kamal rollback`, `kamal app logs -f`.
- Accessories lifecycle is independent (`kamal accessory boot|reboot|remove`).
- Gotchas:
  - Do not create a custom private Docker network; Kamal manages its own.
  - UFW alone does not protect Docker-published ports.
  - Never set VM hostname to your domain.
  - Avoid overly short `deploy_timeout`.
  - Configure asset bridging (`asset_path`) explicitly when needed.
  - Use `forward_headers: true` when behind Cloudflare.

## DigitalOcean Operations

- Compute options: Droplets (full control), App Platform (PaaS), Functions, DOKS, GPU/Bare Metal.
- Group resources by environment in DigitalOcean Projects.
- Enable Monitoring + alert thresholds; add Uptime checks for public endpoints and SSL expiry.
- After each deploy: inspect CPU/memory/disk, app latency, and uptime alerts.

## Git + PR Workflow

- Branches: `feat/...`, `fix/...`, `chore/...`.
- Commits: conventional commits (`feat:`, `fix:`, `chore:`, `docs:`).
- Pre-commit (Lefthook): parallel lint/format/test — autofix commands restage files.
- CI (`.github/workflows/ci.yml`): lint annotations, lefthook verify, e2e.
- Preview (`.github/workflows/preview.yml`): PR open/sync deploys isolated preview; PR close tears down.
- Keep PRs small; include exact validation commands and results.

## Boundaries

Always:

- Run `pnpm ci` before final handoff.
- Update README.md when project behavior changes.

Ask first:

- Dependency upgrades with broad runtime impact.
- Destructive infra/deploy changes.

Never:

- Commit secrets or credentials (use `.env`, git-ignored).
- Disable lint/test gates to "make CI pass".
