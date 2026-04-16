#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
SETUP_UNDER_TEST_DIR="${WORK_DIR}/setup-under-test"
SETUP_UNDER_TEST="${SETUP_UNDER_TEST_DIR}/setup.sh"
mkdir -p "${SETUP_UNDER_TEST_DIR}"
cp "${SCRIPT_DIR}/setup.sh" "${SETUP_UNDER_TEST}"
cp -r "${SCRIPT_DIR}/project" "${SETUP_UNDER_TEST_DIR}/project"
chmod +x "${SETUP_UNDER_TEST}"

echo ">> Running setup.sh in dry-run mode..."
echo "   Working directory: $WORK_DIR"

set -a
export OAUTH_CLIENT_ID=test-client-id
export OAUTH_CLIENT_SECRET=test-client-secret
export ADMIN_GITHUB_USERNAMES=testadmin
export DO_API_TOKEN=test-token
export KAMAL_REGISTRY_USERNAME=ghcr.io/test-registry-user
export KAMAL_REGISTRY_PASSWORD=test-registry-pw
export DROPLET_IP=127.0.0.1
export DROPLET_SIZE=s-1vcpu-1gb

set +a

export DRY_RUN=true
export NON_INTERACTIVE=true
export SETUP_COMPACT_OUTPUT=1
export PROJECT_DIR="${WORK_DIR}/my-app"
DRY_RUN_OUTPUT_LOG="${WORK_DIR}/dry-run-output.log"

bash "${SETUP_UNDER_TEST}" | tee "${DRY_RUN_OUTPUT_LOG}"

echo ""
echo ">> Validating generated project..."

if grep -Eq "░▒▓███████▓▒|░█▀▀░█░█░█▀▀░█▀▀|░██████                         ░██|██▄   ████▄" "${DRY_RUN_OUTPUT_LOG}"; then
  echo "[FAIL] setup output should not include ASCII headers when SETUP_COMPACT_OUTPUT=1"
  exit 1
else
  echo "  [OK]  setup output omits ASCII headers in compact mode"
fi

if grep -q "bundle exec kamal setup --version" "${DRY_RUN_OUTPUT_LOG}" &&
  grep -q "bundle exec kamal deploy --version" "${DRY_RUN_OUTPUT_LOG}"; then
  echo "  [OK]  dry-run output includes explicit Kamal version for setup/deploy"
else
  echo "[FAIL] setup dry-run output should include explicit Kamal version for setup/deploy"
  exit 1
fi

if grep -q "\[dry-run\] pnpm install" "${DRY_RUN_OUTPUT_LOG}"; then
  echo "  [OK]  dry-run output includes pnpm install step"
else
  echo "[FAIL] setup dry-run output should include pnpm install step"
  exit 1
fi

if grep -q "Droplet ID:" "${DRY_RUN_OUTPUT_LOG}" &&
  grep -q "Droplet IP:" "${DRY_RUN_OUTPUT_LOG}"; then
  echo "  [OK]  setup output includes droplet ID/IP summary"
else
  echo "[FAIL] setup output should include droplet ID/IP summary"
  exit 1
fi

if grep -q "waiting for cloud-init/APT locks to clear on" "${SETUP_UNDER_TEST}" &&
  grep -q "cloud-init/APT locks cleared on root@" "${SETUP_UNDER_TEST}"; then
  echo "  [OK]  setup waits for cloud-init/APT readiness before Kamal deploy"
else
  echo "[FAIL] setup should wait for cloud-init/APT readiness before Kamal deploy"
  exit 1
fi

if grep -q "apply_new_droplet_security_baseline" "${SETUP_UNDER_TEST}" &&
  grep -q "PermitRootLogin prohibit-password" "${SETUP_UNDER_TEST}" &&
  grep -q "apt-get -yq full-upgrade" "${SETUP_UNDER_TEST}" &&
  grep -q "if ! ufw allow OpenSSH; then" "${SETUP_UNDER_TEST}" &&
  grep -q "ufw allow 22/tcp" "${SETUP_UNDER_TEST}" &&
  grep -q "ufw allow 80/tcp" "${SETUP_UNDER_TEST}" &&
  grep -q "systemctl enable --now fail2ban" "${SETUP_UNDER_TEST}"; then
  echo "  [OK]  setup applies baseline patching and safe SSH/firewall hardening on newly provisioned droplets"
else
  echo "[FAIL] setup should baseline-patch and harden newly provisioned droplets"
  exit 1
fi

assert_file() {
  if [[ ! -f "$1" ]]; then
    echo "[FAIL] Missing: $1"
    exit 1
  fi
  echo "  [OK]  $1"
}

assert_file "${PROJECT_DIR}/.mise.toml"
assert_file "${PROJECT_DIR}/.tool-versions"
assert_file "${PROJECT_DIR}/.nvmrc"
assert_file "${PROJECT_DIR}/.ruby-version"
assert_file "${PROJECT_DIR}/.sdkmanrc"
assert_file "${PROJECT_DIR}/.npmrc"
assert_file "${PROJECT_DIR}/.editorconfig"
assert_file "${PROJECT_DIR}/.prettierrc"
assert_file "${PROJECT_DIR}/.prettierignore"
assert_file "${PROJECT_DIR}/.lefthook.yml"
assert_file "${PROJECT_DIR}/.gitignore"
assert_file "${PROJECT_DIR}/.env.example"
assert_file "${PROJECT_DIR}/Gemfile"
assert_file "${PROJECT_DIR}/.bundle/config"
assert_file "${PROJECT_DIR}/teardown.sh"
assert_file "${PROJECT_DIR}/.vscode/settings.json"
assert_file "${PROJECT_DIR}/.vscode/extensions.json"
assert_file "${PROJECT_DIR}/.vscode/tasks.json"
assert_file "${PROJECT_DIR}/.vscode/mcp.json"
assert_file "${PROJECT_DIR}/.idea/codeStyles/Project.xml"
assert_file "${PROJECT_DIR}/.idea/codeStyles/codeStyleConfig.xml"
assert_file "${PROJECT_DIR}/.idea/saveactions_settings.xml"
assert_file "${PROJECT_DIR}/.idea/mcp.json"
assert_file "${PROJECT_DIR}/.idea/runConfigurations/pnpm_dev.xml"
assert_file "${PROJECT_DIR}/.idea/runConfigurations/pnpm_lint.xml"
assert_file "${PROJECT_DIR}/.idea/runConfigurations/pnpm_test.xml"
assert_file "${PROJECT_DIR}/.copilot/mcp-config.json"
assert_file "${PROJECT_DIR}/.kiro/mcp.json"
assert_file "${PROJECT_DIR}/.kiro/settings.json"
assert_file "${PROJECT_DIR}/.kiro/tasks.json"
assert_file "${PROJECT_DIR}/pnpm-workspace.yaml"
assert_file "${PROJECT_DIR}/package.json"
assert_file "${PROJECT_DIR}/docker-compose.yml"
assert_file "${PROJECT_DIR}/docker-compose.dev.yml"
assert_file "${PROJECT_DIR}/docker-compose.prod.yml"
assert_file "${PROJECT_DIR}/contract/openapi.yml"
assert_file "${PROJECT_DIR}/contract/generate.sh"
assert_file "${PROJECT_DIR}/contract/package.json"
assert_file "${PROJECT_DIR}/frontend/Dockerfile"
assert_file "${PROJECT_DIR}/frontend/.dockerignore"
assert_file "${PROJECT_DIR}/frontend/.eslintrc.json"
assert_file "${PROJECT_DIR}/frontend/next.config.js"
assert_file "${PROJECT_DIR}/frontend/next-env.d.ts"
assert_file "${PROJECT_DIR}/frontend/tsconfig.json"
assert_file "${PROJECT_DIR}/frontend/package.json"
assert_file "${PROJECT_DIR}/frontend/playwright.config.ts"
assert_file "${PROJECT_DIR}/frontend/postcss.config.mjs"
assert_file "${PROJECT_DIR}/frontend/src/app/globals.css"
assert_file "${PROJECT_DIR}/frontend/e2e/home.spec.ts"
assert_file "${PROJECT_DIR}/frontend/src/app/layout.tsx"
assert_file "${PROJECT_DIR}/frontend/src/app/page.tsx"
assert_file "${PROJECT_DIR}/frontend/src/app/account/page.tsx"
assert_file "${PROJECT_DIR}/frontend/src/app/admin/page.tsx"
assert_file "${PROJECT_DIR}/frontend/src/components/sign-in.tsx"
assert_file "${PROJECT_DIR}/frontend/src/components/unauthorised.tsx"
assert_file "${PROJECT_DIR}/frontend/src/util/getUser.ts"
assert_file "${PROJECT_DIR}/frontend/src/util/getSignInLink.ts"
assert_file "${PROJECT_DIR}/frontend/src/util/logoutAction.ts"
assert_file "${PROJECT_DIR}/backend/pom.xml"
assert_file "${PROJECT_DIR}/backend/package.json"
assert_file "${PROJECT_DIR}/backend/Dockerfile"
assert_file "${PROJECT_DIR}/backend/.dockerignore"
assert_file "${PROJECT_DIR}/backend/dev.sh"
assert_file "${PROJECT_DIR}/backend/wait-for-postgres.sh"
assert_file "${PROJECT_DIR}/backend/seed/SeedDataGenerator.java"
assert_file "${PROJECT_DIR}/backend/src/main/java/com/myapp/MyAppApplication.java"
assert_file "${PROJECT_DIR}/backend/src/main/java/com/myapp/config/OpenApiConfig.java"
assert_file "${PROJECT_DIR}/backend/src/main/java/com/myapp/config/SecurityConfig.java"
assert_file "${PROJECT_DIR}/backend/src/main/java/com/myapp/controller/AdminController.java"
assert_file "${PROJECT_DIR}/backend/src/main/java/com/myapp/controller/GreetingController.java"
assert_file "${PROJECT_DIR}/backend/src/main/java/com/myapp/controller/UserController.java"
assert_file "${PROJECT_DIR}/backend/src/main/resources/db/migration/V1__init.sql"
assert_file "${PROJECT_DIR}/backend/src/main/resources/application.properties"
# shellcheck disable=SC2016
if grep -q 'client-id=${OAUTH_CLIENT_ID:placeholder}' "${PROJECT_DIR}/backend/src/main/resources/application.properties"; then
  echo "  [OK]  OAuth2 client-id has non-empty placeholder default (app boots without env vars)"
else
  echo "[FAIL] application.properties: OAuth2 client-id default must be non-empty (e.g. 'placeholder') to allow boot without env vars"
  exit 1
fi
assert_file "${PROJECT_DIR}/backend/src/test/resources/application-test.properties"
assert_file "${PROJECT_DIR}/backend/src/test/java/com/myapp/ApiEndpointsTest.java"
assert_file "${PROJECT_DIR}/database/init.sql"
assert_file "${PROJECT_DIR}/database/seed.sql"
assert_file "${PROJECT_DIR}/README.md"
assert_file "${PROJECT_DIR}/AGENTS.md"
assert_file "${PROJECT_DIR}/frontend/AGENTS.md"
assert_file "${PROJECT_DIR}/backend/AGENTS.md"
assert_file "${PROJECT_DIR}/contract/AGENTS.md"
assert_file "${PROJECT_DIR}/.github/workflows/ci.yml"
assert_file "${PROJECT_DIR}/.github/workflows/deploy.yml"
assert_file "${PROJECT_DIR}/.github/workflows/preview.yml"
assert_file "${PROJECT_DIR}/config/deploy.yml"
assert_file "${PROJECT_DIR}/config/deploy.preview.yml"
assert_file "${PROJECT_DIR}/.kamal/hooks/pre-deploy"
assert_file "${PROJECT_DIR}/.kamal/secrets"
assert_file "${PROJECT_DIR}/.sqlfluff"
assert_file "${PROJECT_DIR}/bruno/bruno.json"
assert_file "${PROJECT_DIR}/bruno/environments/ci.bru"
assert_file "${PROJECT_DIR}/bruno/requests/admin-health.bru"
assert_file "${PROJECT_DIR}/bruno/requests/user-profile.bru"
assert_file "${PROJECT_DIR}/frontend/public/.gitkeep"

if grep -q "depends_on:" "${PROJECT_DIR}/docker-compose.yml" &&
  grep -q "service_healthy" "${PROJECT_DIR}/docker-compose.yml"; then
  echo "  [OK]  docker-compose.yml backend depends_on db with healthcheck"
else
  echo "[FAIL] docker-compose.yml should declare backend depends_on db with healthcheck"
  exit 1
fi

if grep -q "pnpm build || true" "${PROJECT_DIR}/frontend/Dockerfile"; then
  echo "[FAIL] frontend/Dockerfile should not swallow build failures with || true"
  exit 1
else
  echo "  [OK]  frontend/Dockerfile does not swallow build failures"
fi

if grep -q "yum install.*shadow-utils.*curl" "${PROJECT_DIR}/backend/Dockerfile" &&
  grep -q "useradd" "${PROJECT_DIR}/backend/Dockerfile"; then
  echo "  [OK]  backend/Dockerfile installs shadow-utils and curl before useradd"
else
  echo "[FAIL] backend/Dockerfile must install shadow-utils (provides useradd) and curl on amazoncorretto"
  exit 1
fi

echo ""
echo ">> Validating deploy artifacts..."
if grep -q "KAMAL_REGISTRY_PASSWORD=\\\$KAMAL_REGISTRY_PASSWORD" "${PROJECT_DIR}/.kamal/secrets"; then
  echo "  [OK]  .kamal/secrets uses variable references (not actual values)"
else
  echo "[FAIL] .kamal/secrets should use variable references, not actual secret values"
  exit 1
fi

if grep -q '^KAMAL_REGISTRY_USERNAME=test-registry-user$' "${PROJECT_DIR}/.env"; then
  echo "  [OK]  setup normalizes KAMAL_REGISTRY_USERNAME (strips ghcr.io/ prefix)"
else
  echo "[FAIL] setup should normalize KAMAL_REGISTRY_USERNAME by stripping ghcr.io/ prefix"
  exit 1
fi

required_env_keys=(
  OAUTH_CLIENT_ID
  OAUTH_CLIENT_SECRET
  ADMIN_GITHUB_USERNAMES
  DO_API_TOKEN
  KAMAL_REGISTRY_USERNAME
  KAMAL_REGISTRY_PASSWORD
  POSTGRES_PASSWORD
  APP_HOSTNAME
  DROPLET_SSH_PRIVATE_KEY_PATH
)

for key in "${required_env_keys[@]}"; do
  if grep -q "^${key}=" "${PROJECT_DIR}/.env" &&
    grep -q "^${key}=" "${PROJECT_DIR}/.env.example"; then
    continue
  fi
  echo "[FAIL] generated env files should include required key ${key}"
  exit 1
done
echo "  [OK]  generated env files include all required env keys"

env_perms="$(stat -c '%a' "${PROJECT_DIR}/.env" 2>/dev/null || stat -f '%Lp' "${PROJECT_DIR}/.env" 2>/dev/null)"
if [[ "${env_perms}" == "600" ]]; then
  echo "  [OK]  generated .env has restrictive permissions (600)"
else
  echo "[FAIL] generated .env should have 600 permissions (got ${env_perms})"
  exit 1
fi

echo ""
echo ">> Validating setup.sh loads env only from next to the script..."
ENV_FIXTURE_DIR="${WORK_DIR}/env-fixture"
mkdir -p "${ENV_FIXTURE_DIR}"
ENV_FIXTURE_LOG="${WORK_DIR}/env-fixture.log"
cp "${SETUP_UNDER_TEST}" "${ENV_FIXTURE_DIR}/setup.sh"
cp -r "${SETUP_UNDER_TEST_DIR}/project" "${ENV_FIXTURE_DIR}/project"
chmod +x "${ENV_FIXTURE_DIR}/setup.sh"

cat > "${ENV_FIXTURE_DIR}/.env" <<EOF
DRY_RUN=true
NON_INTERACTIVE=true
SETUP_COMPACT_OUTPUT=1
PROJECT_DIR=${ENV_FIXTURE_DIR}/generated-from-env
OAUTH_CLIENT_ID=fixture-client-id
OAUTH_CLIENT_SECRET=fixture-client-secret
ADMIN_GITHUB_USERNAMES=fixture-admin
DO_API_TOKEN=fixture-do-token
KAMAL_REGISTRY_USERNAME=fixture-registry-user
KAMAL_REGISTRY_PASSWORD=fixture-registry-password
DROPLET_SIZE=s-1vcpu-1gb
DROPLET_IP=127.0.0.1
EOF

(cd "${ENV_FIXTURE_DIR}" && \
  unset PROJECT_DIR DRY_RUN NON_INTERACTIVE WIPE_EXISTING SETUP_COMPACT_OUTPUT \
    OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET ADMIN_GITHUB_USERNAMES DO_API_TOKEN \
    KAMAL_REGISTRY_USERNAME KAMAL_REGISTRY_PASSWORD DROPLET_IP DROPLET_SIZE && \
  bash "${ENV_FIXTURE_DIR}/setup.sh") > "${ENV_FIXTURE_LOG}" 2>&1

if [[ -f "${ENV_FIXTURE_DIR}/generated-from-env/package.json" ]] &&
  grep -q "NON_INTERACTIVE=true" "${ENV_FIXTURE_LOG}" &&
  ! grep -q "Missing required environment variables" "${ENV_FIXTURE_LOG}"; then
  echo "  [OK]  setup.sh uses only script-colocated .env"
else
  echo "[FAIL] setup.sh should load env only from a .env next to the script"
  echo "       Log: ${ENV_FIXTURE_LOG}"
  exit 1
fi

if grep -q 'github.actor' "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q 'secrets.GITHUB_TOKEN' "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q 'secrets.OAUTH_CLIENT_SECRET' "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q 'secrets.POSTGRES_PASSWORD' "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q 'secrets.DO_API_TOKEN' "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q 'DROPLET_TAG' "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q 'compute droplet list --tag-name' "${PROJECT_DIR}/.github/workflows/deploy.yml"; then
  echo "  [OK]  deploy workflow uses repository-scoped GitHub auth and required secrets"
else
  echo "[FAIL] deploy workflow should use repository-scoped GitHub auth and required secrets for Kamal"
  exit 1
fi

if grep -q "permissions:" "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q "packages: write" "${PROJECT_DIR}/.github/workflows/deploy.yml"; then
  echo "  [OK]  deploy workflow declares required permissions"
else
  echo "[FAIL] deploy workflow should declare permissions (packages: write)"
  exit 1
fi

if grep -q "Post-deploy health check" "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q "YAML.safe_load_file" "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q "Invalid app host format in config/deploy.yml" "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q "APP_URL=\"http://\${APP_HOST}\"" "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q "curl --fail --show-error --retry 30 --retry-delay 10 --retry-connrefused --retry-all-errors --connect-timeout 10 --max-time 30 --output /dev/null --url \"\${APP_URL}/\"" "${PROJECT_DIR}/.github/workflows/deploy.yml"; then
  echo "  [OK]  deploy workflow runs post-deploy app URL health check"
else
  echo "[FAIL] deploy workflow should run post-deploy app URL health check"
  exit 1
fi

if grep -q "service:" "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q "image:" "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'ENV.fetch("KAMAL_REGISTRY_USERNAME")' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'sub(%r{\\Aghcr\\.io/}, "")' "${PROJECT_DIR}/config/deploy.yml"; then
  echo "  [OK]  config/deploy.yml has service configuration"
else
  echo "[FAIL] config/deploy.yml should have service configuration"
  exit 1
fi

if grep -q 'PR_NUMBER:' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'secrets.DROPLET_IP' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'secrets.DO_API_TOKEN' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'DROPLET_TAG' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'compute droplet list --tag-name' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'vars.APP_HOSTNAME' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'kamal deploy -d preview' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'kamal app remove -d preview --confirmed' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'kamal accessory remove db -d preview --confirmed' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'pull-requests: write' "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q 'preview-url' "${PROJECT_DIR}/.github/workflows/preview.yml"; then
  echo "  [OK]  preview workflow deploys/tears down isolated preview environments per PR"
else
  echo "[FAIL] preview workflow should deploy and teardown isolated preview environments per PR"
  exit 1
fi

if grep -q 'ENV.fetch("PR_NUMBER")' "${PROJECT_DIR}/config/deploy.preview.yml" &&
  grep -q 'ENV.fetch("DROPLET_IP")' "${PROJECT_DIR}/config/deploy.preview.yml" &&
  grep -q 'sslip.io' "${PROJECT_DIR}/config/deploy.preview.yml" &&
  grep -q 'ENV\["APP_HOSTNAME"\]' "${PROJECT_DIR}/config/deploy.preview.yml" &&
  grep -q 'app_port: 3000' "${PROJECT_DIR}/config/deploy.preview.yml" &&
  grep -q 'healthcheck:' "${PROJECT_DIR}/config/deploy.preview.yml" &&
  grep -q 'path: /' "${PROJECT_DIR}/config/deploy.preview.yml" &&
  grep -q 'ssl: true' "${PROJECT_DIR}/config/deploy.preview.yml" &&
  grep -q 'accessories:' "${PROJECT_DIR}/config/deploy.preview.yml" &&
  grep -q 'POSTGRES_PASSWORD' "${PROJECT_DIR}/config/deploy.preview.yml"; then
  echo "  [OK]  config/deploy.preview.yml configures PR-isolated preview with hostname/sslip.io fallback"
else
  echo "[FAIL] config/deploy.preview.yml should configure PR-isolated preview with hostname support and sslip.io fallback"
  exit 1
fi

if grep -q 'ENV.fetch("DROPLET_IP")' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'ENV.fetch("APP_HOSTNAME")' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'app_port: 3000' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'healthcheck:' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'path: /' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'ssl: true' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'registry:' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'server: ghcr.io' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'KAMAL_REGISTRY_PASSWORD' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'builder:' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'arch: amd64' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'context: frontend' "${PROJECT_DIR}/config/deploy.yml" &&
  grep -q 'dockerfile: frontend/Dockerfile' "${PROJECT_DIR}/config/deploy.yml"; then
  echo "  [OK]  config/deploy.yml supports custom hostname with TLS, GHCR registry, and Kamal builder arch"
else
  echo "[FAIL] config/deploy.yml should support custom hostname with TLS, GHCR registry, and Kamal builder arch"
  exit 1
fi

if grep -q 'vars.APP_HOSTNAME' "${PROJECT_DIR}/.github/workflows/deploy.yml"; then
  echo "  [OK]  deploy workflow passes APP_HOSTNAME variable"
else
  echo "[FAIL] deploy workflow should pass APP_HOSTNAME variable"
  exit 1
fi

if grep -q "DRY_RUN=\"\${DRY_RUN:-false}\"" "${PROJECT_DIR}/teardown.sh" &&
  grep -Fq "SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd -P)\"" "${PROJECT_DIR}/teardown.sh" &&
  grep -Fq "cd \"\${SCRIPT_DIR}\"" "${PROJECT_DIR}/teardown.sh" &&
  grep -q "bundle exec kamal remove --version" "${PROJECT_DIR}/teardown.sh" &&
  grep -q "doctl --access-token" "${PROJECT_DIR}/teardown.sh" &&
  grep -q "resolve_teardown_kamal_version" "${PROJECT_DIR}/teardown.sh" &&
  grep -q 'load_env_key_if_unset DROPLET_TAG' "${PROJECT_DIR}/teardown.sh" &&
  grep -q 'load_env_key_if_unset APP_HOSTNAME' "${PROJECT_DIR}/teardown.sh" &&
  grep -q 'compute domain records list' "${PROJECT_DIR}/teardown.sh" &&
  grep -q 'compute domain records delete' "${PROJECT_DIR}/teardown.sh" &&
  grep -q 'No droplet IPs resolved from DROPLET_TAG/DROPLET_IP' "${PROJECT_DIR}/teardown.sh" &&
  grep -q 'in allowed_ips' "${PROJECT_DIR}/teardown.sh" &&
  grep -Fq "read_env_key \"\${key}\" \"\${SCRIPT_DIR}/.env\"" "${PROJECT_DIR}/teardown.sh" &&
  grep -Fq "basename \"\${SCRIPT_DIR}\"" "${PROJECT_DIR}/teardown.sh" &&
  grep -q 'compute droplet list --tag-name' "${PROJECT_DIR}/teardown.sh" &&
  grep -q 'Multiple droplets found for DROPLET_TAG=' "${PROJECT_DIR}/teardown.sh" &&
  grep -q "compute droplet delete" "${PROJECT_DIR}/teardown.sh" &&
  ! grep -q "source .env" "${PROJECT_DIR}/teardown.sh"; then
  echo "  [OK]  generated teardown handles kamal and droplet cleanup with dry-run support"
else
  echo "[FAIL] generated teardown should handle kamal and droplet cleanup with dry-run support"
  exit 1
fi

echo ""
echo ">> Validating dry-run behavior..."
if grep -q "bundle exec kamal deploy" "${PROJECT_DIR}/README.md"; then
  echo "  [OK]  README includes bundler/kamal usage"
else
  echo "[FAIL] README should include bundler/kamal usage"
  exit 1
fi

if grep -q '"url": "https://mcp.context7.com/mcp"' "${PROJECT_DIR}/.vscode/mcp.json" &&
  grep -q '"url": "https://mcp.context7.com/mcp"' "${PROJECT_DIR}/.idea/mcp.json" &&
  grep -q '"url": "https://mcp.context7.com/mcp"' "${PROJECT_DIR}/.copilot/mcp-config.json" &&
  grep -q '"url": "https://mcp.context7.com/mcp"' "${PROJECT_DIR}/.kiro/mcp.json"; then
  echo "  [OK]  MCP configs preconfigure Context7 remote server for editor and Copilot clients"
else
  echo "[FAIL] MCP configs should preconfigure Context7 remote server for supported clients"
  exit 1
fi

if grep -q '"editor.codeActionsOnSave"' "${PROJECT_DIR}/.kiro/settings.json" &&
  grep -q '"editor.formatOnSave": true' "${PROJECT_DIR}/.kiro/settings.json" &&
  grep -q '"source.fixAll.eslint": "always"' "${PROJECT_DIR}/.kiro/settings.json" &&
  grep -q '"label": "pnpm lint"' "${PROJECT_DIR}/.kiro/tasks.json" &&
  grep -q '"label": "pnpm test:e2e"' "${PROJECT_DIR}/.kiro/tasks.json" &&
  grep -q '"label": "pnpm dev"' "${PROJECT_DIR}/.kiro/tasks.json"; then
  echo "  [OK]  Kiro settings/tasks mirror VS Code autofix and lint/test workflow"
else
  echo "[FAIL] Kiro settings/tasks should mirror VS Code autofix and lint/test workflow"
  exit 1
fi

for agents_file in \
  "${PROJECT_DIR}/AGENTS.md" \
  "${PROJECT_DIR}/frontend/AGENTS.md" \
  "${PROJECT_DIR}/backend/AGENTS.md" \
  "${PROJECT_DIR}/contract/AGENTS.md"; do
  if grep -q "Context7 MCP" "${agents_file}"; then
    echo "  [OK]  ${agents_file} encourages Context7 MCP usage"
  else
    echo "[FAIL] ${agents_file} should explicitly encourage Context7 MCP usage"
    exit 1
  fi

  actual_line_count="$(wc -l < "${agents_file}")"
  actual_word_count="$(wc -w < "${agents_file}")"
  if ((actual_line_count <= 600)) && ((actual_word_count <= 2000)); then
    echo "  [OK]  ${agents_file} is within line/word limits"
  else
    echo "[FAIL] ${agents_file} exceeds line/word limits (${actual_line_count} lines, ${actual_word_count} words)"
    exit 1
  fi
done

if [[ "$(cat "${PROJECT_DIR}/.git/HEAD")" == "ref: refs/heads/main" ]]; then
  echo "  [OK]  git init uses main as default branch"
else
  echo "[FAIL] git init should use main as default branch"
  exit 1
fi

if grep -q '"lint": "pnpm prettier:write' "${PROJECT_DIR}/package.json"; then
  echo "  [OK]  package.json includes lint orchestration"
else
  echo "[FAIL] package.json should include lint orchestration"
  exit 1
fi

if grep -q '"prepare": "lefthook install"' "${PROJECT_DIR}/package.json" &&
  grep -q '"lint:fix": "pnpm format && pnpm lint:contract && pnpm lint:frontend:fix && pnpm lint:backend && pnpm lint:sql && pnpm lint:docker"' "${PROJECT_DIR}/package.json" &&
  grep -q '"lefthook": "2.1.5"' "${PROJECT_DIR}/package.json"; then
  echo "  [OK]  package.json installs and configures lefthook pre-commit flow"
else
  echo "[FAIL] package.json should install lefthook and define lint:fix pre-commit script"
  exit 1
fi

if grep -q "parallel: true" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "prettier_fix:" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "backend_format:" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "lint_contract:" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "lint_frontend_fix:" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "lint_backend:" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "lint_sql:" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "lint_docker:" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "test_frontend:" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "test_backend:" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "run: pnpm prettier:write" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "run: pnpm spotless:apply" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "run: pnpm lint:frontend:fix" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "run: pnpm --filter frontend test" "${PROJECT_DIR}/.lefthook.yml" &&
  grep -q "run: pnpm --filter backend test" "${PROJECT_DIR}/.lefthook.yml"; then
  echo "  [OK]  .lefthook.yml runs individual lints/tests in parallel with autofix restaging"
else
  echo "[FAIL] .lefthook.yml should define parallel individual lint and test commands with autofix restaging"
  exit 1
fi

# test_e2e should NOT be in pre-commit (requires running DB, too slow for pre-commit)
if grep -q "test_e2e:" "${PROJECT_DIR}/.lefthook.yml"; then
  echo "[FAIL] .lefthook.yml should not include test_e2e in pre-commit (requires running DB)"
  exit 1
else
  echo "  [OK]  .lefthook.yml does not include DB-dependent e2e test in pre-commit"
fi

if grep -q '"postinstall": "pnpm generate && pnpm --filter backend run install"' "${PROJECT_DIR}/package.json"; then
  echo "  [OK]  package.json postinstall avoids recursive pnpm install"
else
  echo "[FAIL] package.json postinstall should use 'pnpm --filter backend run install'"
  exit 1
fi

if grep -q '^onlyBuiltDependencies:' "${PROJECT_DIR}/pnpm-workspace.yaml" &&
  grep -q "@openapitools/openapi-generator-cli" "${PROJECT_DIR}/pnpm-workspace.yaml" &&
  grep -q "lefthook" "${PROJECT_DIR}/pnpm-workspace.yaml" &&
  grep -q "sharp" "${PROJECT_DIR}/pnpm-workspace.yaml"; then
  echo "  [OK]  pnpm-workspace.yaml allows required pnpm build scripts"
else
  echo "[FAIL] pnpm-workspace.yaml should include onlyBuiltDependencies for required build scripts"
  exit 1
fi

if grep -q '"lint:contract": "pnpm --filter contract lint && pnpm --filter contract validate"' "${PROJECT_DIR}/package.json"; then
  echo "  [OK]  package.json includes contract lint command"
else
  echo "[FAIL] package.json should include contract lint command"
  exit 1
fi

if grep -q '"dev": "NEXT_TELEMETRY_DISABLED=1 next dev"' "${PROJECT_DIR}/frontend/package.json" &&
  grep -q '"build": "NEXT_TELEMETRY_DISABLED=1 next build"' "${PROJECT_DIR}/frontend/package.json" &&
  grep -q '"onlyBuiltDependencies": \["esbuild", "sharp", "unrs-resolver"\]' "${PROJECT_DIR}/frontend/package.json" &&
  grep -q '"lint": "eslint . --max-warnings=0"' "${PROJECT_DIR}/frontend/package.json" &&
  grep -q '"lint:fix": "eslint . --fix --max-warnings=0"' "${PROJECT_DIR}/frontend/package.json"; then
  echo "  [OK]  frontend package disables telemetry, allows required pnpm build scripts, and supports eslint autofix linting"
else
  echo "[FAIL] frontend/package.json should disable telemetry, include pnpm onlyBuiltDependencies allowlist, and define eslint autofix linting"
  exit 1
fi

if grep -q '"extends": \["next/core-web-vitals", "prettier"\]' "${PROJECT_DIR}/frontend/.eslintrc.json"; then
  echo "  [OK]  frontend eslint config includes prettier compatibility"
else
  echo "[FAIL] frontend/.eslintrc.json should extend prettier"
  exit 1
fi

if grep -q '"tailwindcss":' "${PROJECT_DIR}/frontend/package.json" &&
  grep -q '"@tailwindcss/postcss":' "${PROJECT_DIR}/frontend/package.json"; then
  echo "  [OK]  frontend/package.json includes Tailwind CSS 4 dependencies"
else
  echo "[FAIL] frontend/package.json should include tailwindcss and @tailwindcss/postcss"
  exit 1
fi

if grep -q '@tailwindcss/postcss' "${PROJECT_DIR}/frontend/postcss.config.mjs"; then
  echo "  [OK]  postcss.config.mjs uses @tailwindcss/postcss plugin"
else
  echo "[FAIL] postcss.config.mjs should use @tailwindcss/postcss plugin"
  exit 1
fi

if grep -q "@import 'tailwindcss'" "${PROJECT_DIR}/frontend/src/app/globals.css"; then
  echo "  [OK]  globals.css imports Tailwind CSS"
else
  echo "[FAIL] globals.css should import tailwindcss"
  exit 1
fi

if grep -q "import './globals.css'" "${PROJECT_DIR}/frontend/src/app/layout.tsx"; then
  echo "  [OK]  layout.tsx imports globals.css"
else
  echo "[FAIL] layout.tsx should import globals.css"
  exit 1
fi

if grep -q '"validate:contract": "pnpm --filter contract validate"' "${PROJECT_DIR}/package.json"; then
  echo "  [OK]  package.json includes contract validate command"
else
  echo "[FAIL] package.json should include contract validate command"
  exit 1
fi

if grep -q '"ci": "pnpm lint && pnpm test && pnpm ci:e2e"' "${PROJECT_DIR}/package.json"; then
  echo "  [OK]  package.json includes CI command"
else
  echo "[FAIL] package.json should include CI command with ci:e2e"
  exit 1
fi

if grep -q '"bruno:test": "start-server-and-test \\\"cd backend && mvn --no-transfer-progress spring-boot:run\\\" http://127.0.0.1:8080/api/admin/health \\\"cd bruno && pnpm exec bru run --env ci\\\""' "${PROJECT_DIR}/package.json" &&
  ! grep -q 'SPRING_PROFILES_ACTIVE=test' "${PROJECT_DIR}/package.json"; then
  echo "  [OK]  package.json e2e backend startup uses PostgreSQL (not test profile)"
else
  echo "[FAIL] package.json bruno:test should use PostgreSQL (default profile), not H2 test profile"
  exit 1
fi

if grep -q 'ci:e2e.*docker compose up db.*pnpm test:e2e.*docker compose down' "${PROJECT_DIR}/package.json"; then
  echo "  [OK]  package.json ci:e2e starts DB before e2e tests"
else
  echo "[FAIL] package.json should have ci:e2e that starts DB via docker compose"
  exit 1
fi

# ci:e2e should always clean up DB even on test failure (reject the unsafe && pattern)
if grep -q 'pnpm test:e2e && docker compose down' "${PROJECT_DIR}/package.json"; then
  echo "[FAIL] package.json ci:e2e should not chain test and cleanup with && (DB leaks on failure)"
  exit 1
else
  echo "  [OK]  package.json ci:e2e cleans up DB even on test failure"
fi

if grep -q "pnpm ci:e2e" "${PROJECT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  generated CI runs end-to-end checks with DB"
else
  echo "[FAIL] generated CI should run end-to-end checks"
  exit 1
fi

if grep -q 'run: pnpm lint' "${PROJECT_DIR}/.github/workflows/ci.yml" &&
  grep -q 'Frontend unit tests' "${PROJECT_DIR}/.github/workflows/ci.yml" &&
  grep -q 'Backend tests' "${PROJECT_DIR}/.github/workflows/ci.yml" &&
  grep -q 'dorny/test-reporter' "${PROJECT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  generated CI runs lint and tests with PR reporting"
else
  echo "[FAIL] generated CI should run pnpm lint and tests with PR reporting"
  exit 1
fi

if grep -q 'doctl = "1.154.0"' "${PROJECT_DIR}/.mise.toml" &&
  grep -q 'doctl 1.154.0' "${PROJECT_DIR}/.tool-versions"; then
  echo "  [OK]  generated version manager files include doctl"
else
  echo "[FAIL] generated version manager files should include doctl"
  exit 1
fi

if grep -q '^registry=https://registry.npmjs.org/$' "${PROJECT_DIR}/.npmrc" &&
  grep -q '^engine-strict=true$' "${PROJECT_DIR}/.npmrc" &&
  grep -q '^save-prefix=~$' "${PROJECT_DIR}/.npmrc" &&
  grep -q '^strict-peer-deps=true$' "${PROJECT_DIR}/.npmrc" &&
  grep -q '^auto-install-peers=true$' "${PROJECT_DIR}/.npmrc" &&
  grep -q '^fund=false$' "${PROJECT_DIR}/.npmrc" &&
  grep -q '^audit-level=moderate$' "${PROJECT_DIR}/.npmrc" &&
  grep -q '^minimumReleaseAge=4320$' "${PROJECT_DIR}/.npmrc"; then
  echo "  [OK]  generated .npmrc includes expected npm defaults"
else
  echo "[FAIL] generated .npmrc should include required npm defaults"
  exit 1
fi

if grep -q "Verify lefthook pre-commit (autofix + tests)" "${PROJECT_DIR}/.github/workflows/ci.yml" ||
  grep -q 'git commit -m "ci: verify lefthook"' "${PROJECT_DIR}/.github/workflows/ci.yml" ||
  grep -q "export const lefthookValue = 'ok';" "${PROJECT_DIR}/.github/workflows/ci.yml"; then
  echo "[FAIL] generated CI should not include lefthook pre-commit verification commit step"
  exit 1
else
  echo "  [OK]  generated CI omits lefthook pre-commit verification commit step"
fi

if grep -q "pnpm run ci" "${SCRIPT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  root CI runs project ci script via pnpm run ci"
else
  echo "[FAIL] root CI should run generated project ci script via 'pnpm run ci'"
  exit 1
fi

if grep -q "smoke:" "${SCRIPT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  real deployment smoke test job exists in root CI workflow"
else
  echo "[FAIL] missing smoke job in .github/workflows/ci.yml"
  exit 1
fi

if grep -q "pull_request:" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "workflow_dispatch:" "${SCRIPT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  root CI workflow triggers real deployment smoke test on pull requests and manual dispatch"
else
  echo "[FAIL] root CI workflow should trigger real deployment smoke test on pull_request and workflow_dispatch events"
  exit 1
fi

if grep -q "digitalocean/action-doctl@v2" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "Setup project + provision droplet + deploy app (no dry-run)" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "Install generated project dependencies for smoke checks" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  ! grep -q "Lint and test generated project" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "DROPLET_SSH_KEY_FINGERPRINT: \\\${{ secrets.DROPLET_SSH_KEY_FINGERPRINT }}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "POSTGRES_PASSWORD: \\\${{ secrets.POSTGRES_PASSWORD }}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -Fq "grep '^#\\?DROPLET_IP=' \"\${PROJECT_DIR}/.env\" | head -n1 | sed 's/^#//' | cut -d= -f2-" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -Fq "grep '^#\\?DROPLET_TAG=' \"\${PROJECT_DIR}/.env\" | head -n1 | sed 's/^#//' | cut -d= -f2-" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "compute droplet list --tag-name" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "pnpm exec bru run --env ci" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "playwright screenshot" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "DROPLET_IP: \\\${{ steps.scaffold.outputs.droplet_ip }}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "PRIMARY_BASE_URL=\"http://\${DROPLET_IP}\"" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "PREFERRED_BASE_URL=\"\${PRIMARY_BASE_URL}\"" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "Checking primary app endpoint \${PREFERRED_BASE_URL}/" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "TLS probe for \${APP_HOSTNAME}:443" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "expected 404 when APP_HOSTNAME host-routing is enabled" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "Checking API health endpoint \${API_HEALTH_URL}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "Required API health endpoint check failed at \${API_HEALTH_URL}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "Running Bruno API smoke tests against \${BASE_URL}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  ! grep -q "Skipping Bruno API smoke tests because /api/admin/health is not available on \${BASE_URL}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  ! grep -q "doctl compute droplet create" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  ! grep -q "bundle exec kamal setup" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  ! grep -q "bundle exec kamal deploy" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  ! grep -q "source \"\${PROJECT_DIR}/.env\"" "${SCRIPT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  real deployment workflow provisions and verifies a real deployment"
else
  echo "[FAIL] root CI real deployment smoke test should delegate provision/deploy to setup and verify with Bruno + visual checks"
  exit 1
fi

if grep -q "if: always()" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "Teardown local and remote resources" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "KAMAL_REGISTRY_USERNAME: \\\${{ vars.KAMAL_REGISTRY_USERNAME || github.actor }}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "DROPLET_ID: \\\${{ steps.scaffold.outputs.droplet_id }}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "DROPLET_TAG: \\\${{ steps.scaffold.outputs.droplet_tag }}" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "bash ./teardown.sh" "${SCRIPT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  real deployment workflow always performs teardown"
else
  echo "[FAIL] real deployment workflow should always teardown local and remote resources"
  exit 1
fi

if grep -q "secrets.DO_API_TOKEN" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "secrets.DROPLET_SSH_KEY_FINGERPRINT" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "secrets.DROPLET_SSH_PRIVATE_KEY" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "secrets.POSTGRES_PASSWORD" "${SCRIPT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  real deployment workflow documents required DigitalOcean secrets"
else
  echo "[FAIL] real deployment workflow should reference required DigitalOcean secrets"
  exit 1
fi

if grep -q "DROPLET_SSH_PRIVATE_KEY secret is required for Kamal deploy/teardown" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  grep -q "exit 1" "${SCRIPT_DIR}/.github/workflows/ci.yml" &&
  ! grep -q "skipping SSH key configuration" "${SCRIPT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  real deployment workflow fails fast when SSH key secret is missing"
else
  echo "[FAIL] real deployment workflow should fail fast when DROPLET_SSH_PRIVATE_KEY is missing"
  exit 1
fi

if grep -Fq 'DROPLET_REGION:-lon1' "${SETUP_UNDER_TEST}" &&
  grep -q 'DROPLET_REGION.*lon1' "${SCRIPT_DIR}/README.md"; then
  echo "  [OK]  repository defaults DigitalOcean region to London (lon1)"
else
  echo "[FAIL] repository should default DigitalOcean region to London (lon1)"
  exit 1
fi

if grep -q "wearerequired/lint-action@v2" "${PROJECT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  generated CI enables lint annotations"
else
  echo "[FAIL] generated CI should enable lint annotations"
  exit 1
fi

if grep -q "pnpm/action-setup@v4" "${PROJECT_DIR}/.github/workflows/ci.yml" &&
  grep -q "version: '10'" "${PROJECT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  generated CI pins pnpm action version"
else
  echo "[FAIL] generated CI should pin pnpm action version"
  exit 1
fi

if grep -q "actions/setup-java@v4" "${PROJECT_DIR}/.github/workflows/ci.yml" &&
  grep -q "distribution: corretto" "${PROJECT_DIR}/.github/workflows/ci.yml" &&
  grep -q "java-version: '25.0.2.10.1'" "${PROJECT_DIR}/.github/workflows/ci.yml"; then
  echo "  [OK]  generated CI pins Java to Corretto 25.0.2.10.1"
else
  echo "[FAIL] generated CI should use Corretto Java 25.0.2.10.1"
  exit 1
fi

if grep -q "DROPLET_SSH_PRIVATE_KEY secret is required for Kamal deploy" "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  grep -q "DROPLET_SSH_PRIVATE_KEY secret is required for Kamal preview deploy" "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  grep -q "DROPLET_SSH_PRIVATE_KEY secret is required for Kamal preview teardown" "${PROJECT_DIR}/.github/workflows/preview.yml" &&
  ! grep -q "skipping SSH key configuration" "${PROJECT_DIR}/.github/workflows/deploy.yml" &&
  ! grep -q "skipping SSH key configuration" "${PROJECT_DIR}/.github/workflows/preview.yml"; then
  echo "  [OK]  generated deploy and preview workflows fail fast when SSH key secret is missing"
else
  echo "[FAIL] generated deploy and preview workflows should fail fast when DROPLET_SSH_PRIVATE_KEY is missing"
  exit 1
fi

if grep -q '"lint": "redocly lint ./openapi.yml"' "${PROJECT_DIR}/contract/package.json" &&
  grep -q '"validate": "swagger-cli validate ./openapi.yml"' "${PROJECT_DIR}/contract/package.json" &&
  grep -q '"onlyBuiltDependencies": \["@nestjs/core", "@openapitools/openapi-generator-cli"\]' "${PROJECT_DIR}/contract/package.json"; then
  echo "  [OK]  contract package lints/validates OpenAPI schema and allows required pnpm build scripts"
else
  echo "[FAIL] contract/package.json should lint/validate OpenAPI schema and include pnpm onlyBuiltDependencies allowlist"
  exit 1
fi

if grep -q 'pnpm exec openapi-generator-cli generate' "${PROJECT_DIR}/contract/generate.sh" &&
  ! grep -q 'pnpx @openapitools/openapi-generator-cli generate' "${PROJECT_DIR}/contract/generate.sh"; then
  echo "  [OK]  contract/generate.sh uses pnpm exec (no nested pnpx install)"
else
  echo "[FAIL] contract/generate.sh should use pnpm exec openapi-generator-cli generate"
  exit 1
fi

if grep -q '/api/admin/health' "${PROJECT_DIR}/contract/openapi.yml" &&
  grep -q '/api/user/profile' "${PROJECT_DIR}/contract/openapi.yml"; then
  echo "  [OK]  OpenAPI spec includes /api/admin/health and /api/user/profile endpoints"
else
  echo "[FAIL] OpenAPI spec should include /api/admin/health and /api/user/profile"
  exit 1
fi

if grep -q "pnpm-lock.yaml" "${PROJECT_DIR}/.prettierignore"; then
  echo "  [OK]  .prettierignore excludes pnpm-lock.yaml"
else
  echo "[FAIL] .prettierignore should exclude pnpm-lock.yaml"
  exit 1
fi

if grep -q "backend/src/main/resources/db/migration/\\*.sql" "${PROJECT_DIR}/.prettierignore"; then
  echo "  [OK]  .prettierignore excludes SQL migration files"
else
  echo "[FAIL] .prettierignore should exclude SQL migration files"
  exit 1
fi

echo ""
echo ">> Validating name substitution (PROJECT_DIR basename 'my-app')..."
if grep -q '"name": "my-app"' "${PROJECT_DIR}/package.json"; then
  echo "  [OK]  package.json name is 'my-app'"
else
  echo "[FAIL] package.json should have name 'my-app'"
  exit 1
fi
if grep -q "POSTGRES_DB: my_app" "${PROJECT_DIR}/docker-compose.yml"; then
  echo "  [OK]  docker-compose.yml uses my_app"
else
  echo "[FAIL] docker-compose.yml should use 'my_app'"
  exit 1
fi
if grep -q "package com.myapp" "${PROJECT_DIR}/backend/src/main/java/com/myapp/config/SecurityConfig.java"; then
  echo "  [OK]  SecurityConfig.java package is com.myapp"
else
  echo "[FAIL] SecurityConfig.java package should be com.myapp"
  exit 1
fi

echo "[PASS] dry-run scaffold test passed"

echo ""
echo ">> Running setup.sh with custom name argument 'my-cool-app'..."
unset PROJECT_DIR
CUSTOM_DIR="${WORK_DIR}/my-cool-app"
(cd "${WORK_DIR}" && bash "${SETUP_UNDER_TEST}" "my-cool-app")

echo ""
echo ">> Validating custom name substitution..."
assert_file "${CUSTOM_DIR}/package.json"
assert_file "${CUSTOM_DIR}/docker-compose.yml"
assert_file "${CUSTOM_DIR}/backend/src/main/java/com/mycoolapp/MyCoolAppApplication.java"
assert_file "${CUSTOM_DIR}/backend/src/main/java/com/mycoolapp/config/SecurityConfig.java"
assert_file "${CUSTOM_DIR}/backend/src/test/java/com/mycoolapp/ApiEndpointsTest.java"

if grep -q '"name": "my-cool-app"' "${CUSTOM_DIR}/package.json"; then
  echo "  [OK]  package.json name is 'my-cool-app'"
else
  echo "[FAIL] package.json should have name 'my-cool-app'"
  exit 1
fi
if grep -q "POSTGRES_DB: my_cool_app" "${CUSTOM_DIR}/docker-compose.yml"; then
  echo "  [OK]  docker-compose.yml uses my_cool_app"
else
  echo "[FAIL] docker-compose.yml should use 'my_cool_app'"
  exit 1
fi
if grep -q "# My Cool App" "${CUSTOM_DIR}/README.md"; then
  echo "  [OK]  README.md title is 'My Cool App'"
else
  echo "[FAIL] README.md should have title 'My Cool App'"
  exit 1
fi
if grep -q "package com.mycoolapp" "${CUSTOM_DIR}/backend/src/main/java/com/mycoolapp/config/SecurityConfig.java"; then
  echo "  [OK]  SecurityConfig.java package is com.mycoolapp"
else
  echo "[FAIL] SecurityConfig.java package should be com.mycoolapp"
  exit 1
fi
if grep -q "MyCoolApp" "${CUSTOM_DIR}/backend/pom.xml" 2>/dev/null || grep -q "mycoolapp" "${CUSTOM_DIR}/backend/pom.xml"; then
  echo "  [OK]  pom.xml uses mycoolapp groupId"
else
  echo "[FAIL] pom.xml should use mycoolapp groupId"
  exit 1
fi

echo ""
echo ">> Validating custom folder path argument..."
unset PROJECT_DIR
CUSTOM_PATH_DIR="${WORK_DIR}/nested/custom-path-app"
(cd "${WORK_DIR}" && bash "${SETUP_UNDER_TEST}" "./nested/custom-path-app")

assert_file "${CUSTOM_PATH_DIR}/package.json"
if grep -q '"name": "custom-path-app"' "${CUSTOM_PATH_DIR}/package.json"; then
  echo "  [OK]  setup.sh supports custom folder path argument"
else
  echo "[FAIL] setup.sh should support custom folder path argument"
  exit 1
fi

echo ""
echo ">> Validating PROJECT_DIR supports ~/ path expansion..."
unset PROJECT_DIR
TILDE_HOME_DIR="${WORK_DIR}/tilde-home"
mkdir -p "${TILDE_HOME_DIR}"
TILDE_PATH_REL="projects/tilde-project-app"
TILDE_PATH_ABS="${TILDE_HOME_DIR}/${TILDE_PATH_REL}"
TILDE_PATH_LOG="${WORK_DIR}/tilde-path.log"
TILDE_PROJECT_DIR="$(printf '\176/%s' "${TILDE_PATH_REL}")"

set +e
HOME="${TILDE_HOME_DIR}" \
  DRY_RUN=true \
  NON_INTERACTIVE=true \
  WIPE_EXISTING=false \
  PROJECT_DIR="${TILDE_PROJECT_DIR}" \
  bash "${SETUP_UNDER_TEST}" > "${TILDE_PATH_LOG}" 2>&1
tilde_path_exit_code=$?
set -e

if [[ "${tilde_path_exit_code}" -eq 0 ]] &&
  [[ -f "${TILDE_PATH_ABS}/package.json" ]] &&
  grep -q "PROJECT_DIR=${TILDE_PATH_ABS}" "${TILDE_PATH_LOG}"; then
  echo "  [OK]  setup.sh expands PROJECT_DIR values that start with ~/"
else
  echo "[FAIL] setup.sh should expand PROJECT_DIR values that start with ~/"
  echo "       Exit code: ${tilde_path_exit_code}"
  echo "       Log: ${TILDE_PATH_LOG}"
  exit 1
fi

echo ""
echo ">> Validating default name (no argument, no PROJECT_DIR)..."
DEFAULT_DIR="${WORK_DIR}/scaffolded-application"
(cd "${WORK_DIR}" && bash "${SETUP_UNDER_TEST}")

assert_file "${DEFAULT_DIR}/package.json"
if grep -q '"name": "scaffolded-application"' "${DEFAULT_DIR}/package.json"; then
  echo "  [OK]  default package.json name is 'scaffolded-application'"
else
  echo "[FAIL] default package.json should have name 'scaffolded-application'"
  exit 1
fi

echo ""
echo ">> Validating NON_INTERACTIVE exits early when PROJECT_DIR is not empty..."
NON_INTERACTIVE_EARLY_EXIT_DIR="${WORK_DIR}/non-interactive-existing-dir"
mkdir -p "${NON_INTERACTIVE_EARLY_EXIT_DIR}"
echo "keep" > "${NON_INTERACTIVE_EARLY_EXIT_DIR}/keep.txt"
NON_INTERACTIVE_EARLY_EXIT_LOG="${WORK_DIR}/non-interactive-early-exit.log"

set +e
DRY_RUN=true \
  NON_INTERACTIVE=true \
  WIPE_EXISTING=false \
  PROJECT_DIR="${NON_INTERACTIVE_EARLY_EXIT_DIR}" \
  bash "${SETUP_UNDER_TEST}" > "${NON_INTERACTIVE_EARLY_EXIT_LOG}" 2>&1
non_interactive_exit_code=$?
set -e

if [[ "${non_interactive_exit_code}" -ne 0 ]] &&
  grep -q "PROJECT_DIR already exists and is not empty" "${NON_INTERACTIVE_EARLY_EXIT_LOG}" &&
  grep -q "NON_INTERACTIVE=true: refusing to continue" "${NON_INTERACTIVE_EARLY_EXIT_LOG}" &&
  ! grep -q "Missing required env var" "${NON_INTERACTIVE_EARLY_EXIT_LOG}"; then
  echo "  [OK]  NON_INTERACTIVE fails early with clear non-empty PROJECT_DIR error"
else
  echo "[FAIL] setup should fail early in NON_INTERACTIVE mode when PROJECT_DIR is not empty"
  echo "       Exit code: ${non_interactive_exit_code}"
  echo "       Log: ${NON_INTERACTIVE_EARLY_EXIT_LOG}"
  exit 1
fi

echo ""
echo ">> Validating WIPE_EXISTING=true allows non-interactive overwrite..."
NON_INTERACTIVE_WIPE_DIR="${WORK_DIR}/non-interactive-wipe-dir"
mkdir -p "${NON_INTERACTIVE_WIPE_DIR}"
echo "keep" > "${NON_INTERACTIVE_WIPE_DIR}/keep.txt"
NON_INTERACTIVE_WIPE_LOG="${WORK_DIR}/non-interactive-wipe.log"

set +e
DRY_RUN=true \
  NON_INTERACTIVE=true \
  WIPE_EXISTING=true \
  PROJECT_DIR="${NON_INTERACTIVE_WIPE_DIR}" \
  bash "${SETUP_UNDER_TEST}" > "${NON_INTERACTIVE_WIPE_LOG}" 2>&1
non_interactive_wipe_exit_code=$?
set -e

if [[ "${non_interactive_wipe_exit_code}" -eq 0 ]] &&
  grep -q "WIPE_EXISTING=true, removing existing directory" "${NON_INTERACTIVE_WIPE_LOG}" &&
  [[ -f "${NON_INTERACTIVE_WIPE_DIR}/package.json" ]] &&
  [[ ! -f "${NON_INTERACTIVE_WIPE_DIR}/keep.txt" ]]; then
  echo "  [OK]  WIPE_EXISTING=true wipes existing PROJECT_DIR in NON_INTERACTIVE mode"
else
  echo "[FAIL] setup should wipe and continue when WIPE_EXISTING=true"
  echo "       Exit code: ${non_interactive_wipe_exit_code}"
  echo "       Log: ${NON_INTERACTIVE_WIPE_LOG}"
  exit 1
fi

echo ""
echo ">> Validating interactive mode requires explicit y/Y to wipe PROJECT_DIR..."
INTERACTIVE_NO_WIPE_DIR="${WORK_DIR}/interactive-existing-dir"
mkdir -p "${INTERACTIVE_NO_WIPE_DIR}"
echo "keep" > "${INTERACTIVE_NO_WIPE_DIR}/keep.txt"
INTERACTIVE_NO_WIPE_LOG="${WORK_DIR}/interactive-no-wipe.log"

set +e
printf '\n' | DRY_RUN=true \
  NON_INTERACTIVE=false \
  WIPE_EXISTING=false \
  PROJECT_DIR="${INTERACTIVE_NO_WIPE_DIR}" \
  bash "${SETUP_UNDER_TEST}" > "${INTERACTIVE_NO_WIPE_LOG}" 2>&1
interactive_no_wipe_exit_code=$?
set -e

if [[ "${interactive_no_wipe_exit_code}" -ne 0 ]] &&
  grep -q "Aborted. Existing directory was not wiped." "${INTERACTIVE_NO_WIPE_LOG}" &&
  [[ -f "${INTERACTIVE_NO_WIPE_DIR}/keep.txt" ]]; then
  echo "  [OK]  interactive mode does not wipe unless user explicitly enters y/Y"
else
  echo "[FAIL] setup should require explicit y/Y before wiping existing PROJECT_DIR"
  echo "       Exit code: ${interactive_no_wipe_exit_code}"
  echo "       Log: ${INTERACTIVE_NO_WIPE_LOG}"
  exit 1
fi

echo ""
echo ">> Validating setup does not import invocation-directory .env values..."
unset PROJECT_DIR
unset OAUTH_CLIENT_ID
LEAK_TEST_DIR="${WORK_DIR}/env-isolation-app"
LEAK_SCRIPT_DIR="${WORK_DIR}/env-isolation-script"
mkdir -p "${LEAK_SCRIPT_DIR}"
cp "${SETUP_UNDER_TEST}" "${LEAK_SCRIPT_DIR}/setup.sh"
cp -r "${SETUP_UNDER_TEST_DIR}/project" "${LEAK_SCRIPT_DIR}/project"
chmod +x "${LEAK_SCRIPT_DIR}/setup.sh"
cat > "${WORK_DIR}/.env" <<'EOF'
OAUTH_CLIENT_ID=leaked-client-id
EOF
(cd "${WORK_DIR}" && \
  unset OAUTH_CLIENT_ID && \
  DRY_RUN=true \
  NON_INTERACTIVE=true \
  WIPE_EXISTING=false \
  PROJECT_DIR="${LEAK_TEST_DIR}" \
  OAUTH_CLIENT_SECRET="${OAUTH_CLIENT_SECRET}" \
  ADMIN_GITHUB_USERNAMES="${ADMIN_GITHUB_USERNAMES}" \
  DO_API_TOKEN="${DO_API_TOKEN}" \
  KAMAL_REGISTRY_USERNAME="${KAMAL_REGISTRY_USERNAME}" \
  KAMAL_REGISTRY_PASSWORD="${KAMAL_REGISTRY_PASSWORD}" \
  DROPLET_IP="${DROPLET_IP}" \
  bash "${LEAK_SCRIPT_DIR}/setup.sh")
if grep -q "^OAUTH_CLIENT_ID=leaked-client-id$" "${LEAK_TEST_DIR}/.env"; then
  echo "[FAIL] setup should not import invocation-directory .env values"
  exit 1
fi
if grep -q "^OAUTH_CLIENT_ID=test-client-id$" "${LEAK_TEST_DIR}/.env"; then
  echo "  [OK]  setup ignores invocation-directory .env values"
else
  echo "[FAIL] setup should use dry-run default OAUTH_CLIENT_ID when not provided"
  exit 1
fi
rm -f "${WORK_DIR}/.env"

echo "[PASS] all scaffold tests passed"
