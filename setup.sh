#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

load_env_file_values() {
  local env_file="$1"
  local key
  local value

  if [[ ! -f "${env_file}" ]]; then
    return
  fi

  while IFS='=' read -r key value; do
    [[ -z "${key}" ]] && continue
    [[ "${key}" =~ ^[[:space:]]*# ]] && continue

    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ -z "${key}" ]] && continue
    [[ "${key}" =~ ^[A-Z0-9_]+$ ]] || continue

    if [[ -z "${!key:-}" ]]; then
      export "${key}=${value:-}"
    fi
  done < "${env_file}"
}

load_env_file_values "${SCRIPT_DIR}/.env"

on_error() {
  local exit_code=$?
  echo "[ERROR] setup failed at line ${BASH_LINENO[0]}: ${BASH_COMMAND}" >&2
  echo "        Exit code: ${exit_code}" >&2
  echo "        Suggested fix: review the failing command, install missing tools, then re-run setup.sh." >&2
  exit "${exit_code}"
}
trap on_error ERR

DRY_RUN="${DRY_RUN:-false}"
case "${DRY_RUN}" in
  true|false) ;;
  *)
    echo "[WARN] Invalid DRY_RUN value '${DRY_RUN}', defaulting to false." >&2
    DRY_RUN=false
    ;;
esac
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"
WIPE_EXISTING="${WIPE_EXISTING:-false}"
SETUP_COMPACT_OUTPUT="${SETUP_COMPACT_OUTPUT:-0}"

case "${WIPE_EXISTING}" in
  true|false) ;;
  *)
    echo "[WARN] Invalid WIPE_EXISTING value '${WIPE_EXISTING}', defaulting to false." >&2
    WIPE_EXISTING=false
    ;;
esac

case "${SETUP_COMPACT_OUTPUT}" in
  1|true|TRUE|yes|YES|on|ON)
    SETUP_COMPACT_OUTPUT=true
    ;;
  0|false|FALSE|no|NO|off|OFF|"")
    SETUP_COMPACT_OUTPUT=false
    ;;
  *)
    echo "[WARN] Invalid SETUP_COMPACT_OUTPUT value '${SETUP_COMPACT_OUTPUT}', defaulting to false." >&2
    SETUP_COMPACT_OUTPUT=false
    ;;
esac

PROVISIONED_NEW_DROPLET="false"

log() {
  echo ">> $*"
}

run_cmd() {
  local cmd=("$@")
  local cmd_name="${cmd[0]:-}"
  local cmd_display

  printf -v cmd_display '%q ' "${cmd[@]}"
  cmd_display="${cmd_display% }"

  if [[ "${DRY_RUN}" == "true" && "${cmd_name}" =~ ^(doctl|gh|kamal|bundle)$ ]]; then
    echo "[dry-run] ${cmd_display}"
    return 0
  fi
  "${cmd[@]}"
}

detect_github_username() {
  if [[ -n "${GITHUB_USER:-}" ]]; then
    echo "${GITHUB_USER}"
    return
  fi
  if [[ -n "${GITHUB_ACTOR:-}" ]]; then
    echo "${GITHUB_ACTOR}"
    return
  fi
  if command -v gh >/dev/null 2>&1; then
    local gh_user=""
    gh_user="$(gh api user --jq .login 2>/dev/null || true)"
    if [[ -n "${gh_user}" ]]; then
      echo "${gh_user}"
      return
    fi
  fi
}

prompt_value() {
  local var_name="$1"
  local prompt="$2"
  local default="${3:-}"
  local current="${!var_name:-}"

  if [[ -n "${current}" ]]; then
    return
  fi

  read -r -p "${prompt}${default:+ [${default}]}: " input
  input="${input:-$default}"
  if [[ -z "${input}" ]]; then
    echo "[ERR] ${var_name} is required." >&2
    exit 1
  fi
  export "${var_name}=${input}"
}

prompt_optional_value() {
  local var_name="$1"
  local prompt="$2"
  local default="${3:-}"
  local current="${!var_name:-}"

  if [[ -n "${current}" ]]; then
    return
  fi

  read -r -p "${prompt}${default:+ [${default}]}: " input
  input="${input:-$default}"
  export "${var_name}=${input}"
}

expand_home_path() {
  local path="$1"
  local tilde_literal
  tilde_literal="$(printf '\176')"

  if [[ "${path}" == "${tilde_literal}" ]]; then
    printf '%s' "${HOME}"
    return
  fi
  if [[ "${path:0:1}" == "${tilde_literal}" && "${path:1:1}" == "/" ]]; then
    printf '%s' "${HOME}/${path:2}"
    return
  fi
  printf '%s' "${path}"
}

resolve_ssh_key_material() {
  local key_path="${DROPLET_SSH_PRIVATE_KEY_PATH:-}"
  local inferred_fingerprint=""
  local pub_key_path=""
  local temp_pub_key=""

  if [[ -z "${key_path}" ]]; then
    return
  fi

  key_path="$(expand_home_path "${key_path}")"
  if [[ ! -f "${key_path}" ]]; then
    echo "[ERR] DROPLET_SSH_PRIVATE_KEY_PATH does not exist: ${key_path}" >&2
    exit 1
  fi

  export DROPLET_SSH_PRIVATE_KEY_PATH="${key_path}"

  if [[ -z "${DROPLET_SSH_PRIVATE_KEY:-}" ]]; then
    DROPLET_SSH_PRIVATE_KEY="$(cat "${key_path}")"
    export DROPLET_SSH_PRIVATE_KEY
  fi

  if [[ -n "${DROPLET_SSH_KEY_FINGERPRINT:-}" ]]; then
    return
  fi

  if ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "[ERR] ssh-keygen is required to infer DROPLET_SSH_KEY_FINGERPRINT from DROPLET_SSH_PRIVATE_KEY_PATH." >&2
    exit 1
  fi

  pub_key_path="${key_path}.pub"
  if [[ -f "${pub_key_path}" ]]; then
    inferred_fingerprint="$(ssh-keygen -E md5 -lf "${pub_key_path}" 2>/dev/null | awk '{print $2}' | sed 's/^MD5://')"
  else
    temp_pub_key="$(mktemp)"
    if ssh-keygen -y -f "${key_path}" > "${temp_pub_key}" 2>/dev/null; then
      inferred_fingerprint="$(ssh-keygen -E md5 -lf "${temp_pub_key}" 2>/dev/null | awk '{print $2}' | sed 's/^MD5://')"
    fi
    rm -f "${temp_pub_key}"
  fi

  if [[ -z "${inferred_fingerprint}" ]]; then
    echo "[ERR] Could not infer DROPLET_SSH_KEY_FINGERPRINT from ${key_path}. Set DROPLET_SSH_KEY_FINGERPRINT explicitly." >&2
    exit 1
  fi

  export DROPLET_SSH_KEY_FINGERPRINT="${inferred_fingerprint}"
  echo "[info] inferred DROPLET_SSH_KEY_FINGERPRINT from ${key_path}"
}

wait_for_ssh_auth() {
  local host_ip="$1"
  local max_attempts="${2:-30}"
  local ssh_auth_ok="false"

  for attempt in $(seq 1 "${max_attempts}"); do
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@${host_ip}" true >/dev/null 2>&1; then
      ssh_auth_ok="true"
      break
    fi
    echo "[info] waiting for SSH auth on ${host_ip} (attempt ${attempt}/${max_attempts})..."
    sleep 5
  done

  if [[ "${ssh_auth_ok}" != "true" ]]; then
    echo "[ERR] SSH authentication to root@${host_ip} failed after ${max_attempts} attempts. Ensure the SSH key matches the one registered with the droplet." >&2
    exit 1
  fi

  echo "[OK]  SSH authentication verified for root@${host_ip}"
}

wait_for_remote_package_readiness() {
  local host_ip="$1"
  local max_readiness_attempts="${2:-120}"
  local remote_pkg_ready="false"
  local remote_readiness_script
  local remote_readiness_detail=""

  remote_readiness_script="$(cat <<'EOF'
if command -v cloud-init >/dev/null 2>&1; then
  cloud_init_status="$(cloud-init status 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  if ! printf '%s' "${cloud_init_status}" | grep -q 'status: done'; then
    echo "blocker=cloud-init status=${cloud_init_status:-unknown}"
    exit 1
  fi
fi
if command -v pgrep >/dev/null 2>&1; then
  apt_pids="$(pgrep -ax apt 2>/dev/null || true)"
  apt_get_pids="$(pgrep -ax apt-get 2>/dev/null || true)"
  dpkg_pids="$(pgrep -ax dpkg 2>/dev/null || true)"
  if [[ -n "${apt_pids}${apt_get_pids}${dpkg_pids}" ]]; then
    echo "blocker=package-process apt='${apt_pids}' apt-get='${apt_get_pids}' dpkg='${dpkg_pids}'"
    exit 1
  fi
fi
if command -v fuser >/dev/null 2>&1; then
  lock_holders="$(fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock 2>/dev/null || true)"
  if [[ -n "${lock_holders}" ]]; then
    echo "blocker=apt-lock holders='${lock_holders}'"
    exit 1
  fi
fi
echo "ready"
exit 0
EOF
)"

  for attempt in $(seq 1 "${max_readiness_attempts}"); do
    if remote_readiness_detail="$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@${host_ip}" "${remote_readiness_script}" 2>/dev/null)"; then
      remote_pkg_ready="true"
      break
    fi

    remote_readiness_detail="$(printf '%s' "${remote_readiness_detail}" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    if [[ -z "${remote_readiness_detail}" ]]; then
      remote_readiness_detail="(no blocker detail returned)"
    fi

    echo "[info] waiting for cloud-init/APT locks to clear on ${host_ip} (attempt ${attempt}/${max_readiness_attempts})..."
    sleep 5
  done

  if [[ "${remote_pkg_ready}" != "true" ]]; then
    echo "[ERR] Remote package manager/cloud-init is still busy on ${host_ip} after ${max_readiness_attempts} attempts (last detail: ${remote_readiness_detail}). Retry once provisioning has fully completed." >&2
    exit 1
  fi

  echo "[OK]  cloud-init/APT locks cleared on root@${host_ip}"
}

provision_droplet_if_needed() {
  if [[ -n "${DROPLET_IP:-}" ]]; then
    echo "[info] using provided DROPLET_IP=${DROPLET_IP}"
    PROVISIONED_NEW_DROPLET="false"
    return
  fi

  local region="${DROPLET_REGION:-lon1}"
  local size="${DROPLET_SIZE:-s-1vcpu-1gb}"
  local image="${DROPLET_IMAGE:-ubuntu-24-04-x64}"
  local droplet_tag="${DROPLET_TAG:-${APP_NAME_KEBAB}}"
  export DROPLET_TAG="${droplet_tag}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[dry-run] doctl --access-token *** compute droplet create ${APP_NAME_KEBAB}-<id> --region ${region} --size ${size} --image ${image} --ssh-keys <fingerprint> --tag-names ${droplet_tag} --wait --format ID,PublicIPv4 --no-header"
    export DROPLET_ID="${DROPLET_ID:-dry-run-droplet-id}"
    export DROPLET_IP="${DROPLET_IP:-127.0.0.1}"
    PROVISIONED_NEW_DROPLET="true"
    return
  fi

  if [[ -z "${DO_API_TOKEN:-}" ]]; then
    echo "[ERR] Missing DO_API_TOKEN, cannot provision droplet." >&2
    exit 1
  fi
  if [[ -z "${DROPLET_SSH_KEY_FINGERPRINT:-}" ]]; then
    echo "[ERR] Missing DROPLET_SSH_KEY_FINGERPRINT, cannot provision droplet." >&2
    exit 1
  fi

  local droplet_name
  droplet_name="${APP_NAME_KEBAB}-${RANDOM}-$(date +%s)"
  local droplet_info
  log "Creating droplet '${droplet_name}' in region '${region}' with size '${size}' and image '${image}'."
  droplet_info="$(doctl --access-token "${DO_API_TOKEN}" compute droplet create "${droplet_name}" \
    --region "${region}" \
    --size "${size}" \
    --image "${image}" \
    --ssh-keys "${DROPLET_SSH_KEY_FINGERPRINT}" \
    --tag-names "${droplet_tag}" \
    --wait \
    --format ID,PublicIPv4 \
    --no-header)"

  DROPLET_ID="$(awk '{print $1}' <<<"${droplet_info}")"
  DROPLET_IP="$(awk '{print $2}' <<<"${droplet_info}")"
  if [[ -z "${DROPLET_ID}" ]]; then
    echo "[ERR] Failed to parse droplet ID from doctl output: ${droplet_info}" >&2
    exit 1
  fi

  if [[ -z "${DROPLET_IP}" ]]; then
    echo "[info] droplet ${DROPLET_ID} created, waiting for public IPv4 assignment..."
    for attempt in $(seq 1 30); do
      DROPLET_IP="$(doctl --access-token "${DO_API_TOKEN}" compute droplet get "${DROPLET_ID}" --format PublicIPv4 --no-header | awk 'NF {print; exit}' || true)"
      if [[ -n "${DROPLET_IP}" ]]; then
        break
      fi
      echo "[info] waiting for droplet public IPv4 (attempt ${attempt}/30)..."
      sleep 5
    done
  fi

  export DROPLET_ID DROPLET_IP
  PROVISIONED_NEW_DROPLET="true"

  if [[ -z "${DROPLET_IP}" ]]; then
    echo "[ERR] Droplet ${DROPLET_ID} created but public IPv4 is still unavailable after waiting. Check DigitalOcean networking and retry." >&2
    exit 1
  fi

  echo "[OK]  provisioned droplet ID=${DROPLET_ID} IP=${DROPLET_IP}"
  mkdir -p "${HOME}/.ssh"
  touch "${HOME}/.ssh/known_hosts"
  local ssh_key_scanned="false"
  for _ in $(seq 1 30); do
    if ssh-keyscan -T 5 "${DROPLET_IP}" >> "${HOME}/.ssh/known_hosts" 2>/dev/null; then
      ssh_key_scanned="true"
      break
    fi
    sleep 5
  done
  if [[ "${ssh_key_scanned}" != "true" ]]; then
    echo "[WARN] Unable to fetch SSH host key for ${DROPLET_IP} after 30 attempts; Kamal SSH may fail until connectivity/host-key issues are resolved." >&2
  fi

  # Wait for SSH auth and cloud-init/APT activity to settle before remote configuration/deploy.
  wait_for_ssh_auth "${DROPLET_IP}" 30
  wait_for_remote_package_readiness "${DROPLET_IP}" 120
}

apply_new_droplet_security_baseline() {
  if [[ "${PROVISIONED_NEW_DROPLET}" != "true" ]]; then
    return
  fi

  if [[ -z "${DROPLET_IP:-}" ]]; then
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[dry-run] ssh root@${DROPLET_IP} '<apt update/full-upgrade/autoremove + install unattended-upgrades ufw fail2ban + ssh hardening + ufw allow 22/80/443 + conditional reboot>'"
    return
  fi

  log "Applying baseline Ubuntu patching and hardening on root@${DROPLET_IP} (keeps key-based root SSH for Kamal/GitHub Actions)."

  local remote_hardening_script
  remote_hardening_script="$(cat <<'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get -yq full-upgrade
apt-get -yq autoremove --purge

apt-get install -yq unattended-upgrades ufw fail2ban

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOC'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOC

systemctl enable --now unattended-upgrades || true
systemctl enable --now apt-daily.timer apt-daily-upgrade.timer || true

install -d -m 755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-scaffolder-hardening.conf <<'EOC'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
DebianBanner no
EOC

install -d -m 0755 /run/sshd
/usr/sbin/sshd -t
systemctl restart ssh.service

install -d -m 755 /etc/fail2ban/jail.d
cat > /etc/fail2ban/jail.d/sshd.local <<'EOC'
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
EOC

systemctl enable --now fail2ban
fail2ban-client reload >/dev/null 2>&1 || true

if ! ufw allow OpenSSH; then
  ufw allow 22/tcp
fi
ufw allow 80/tcp
ufw allow 443/tcp
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

if [[ -f /var/run/reboot-required ]]; then
  echo "reboot-required"
else
  echo "no-reboot-required"
fi
EOF
)"

  local hardening_output
  if ! hardening_output="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no "root@${DROPLET_IP}" "${remote_hardening_script}" 2>&1)"; then
    echo "[ERR] Baseline patching/hardening failed on root@${DROPLET_IP}. Output follows:" >&2
    echo "${hardening_output}" >&2
    exit 1
  fi

  if grep -q "reboot-required" <<<"${hardening_output}"; then
    echo "[info] reboot required after baseline patching on ${DROPLET_IP}; rebooting now..."
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no "root@${DROPLET_IP}" "reboot" >/dev/null 2>&1 || true
    wait_for_ssh_auth "${DROPLET_IP}" 60
  fi

  wait_for_remote_package_readiness "${DROPLET_IP}" 120
  echo "[OK]  baseline patching/hardening complete on root@${DROPLET_IP}"
}

configure_dns_if_needed() {
  if [[ -z "${APP_HOSTNAME:-}" ]]; then
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[dry-run] doctl compute domain records create ${APP_HOSTNAME} --record-type A --record-name @ --record-data ${DROPLET_IP} --record-ttl 300"
    echo "[dry-run] doctl compute domain records create ${APP_HOSTNAME} --record-type A --record-name *.preview --record-data ${DROPLET_IP} --record-ttl 300"
    return
  fi

  if [[ -z "${DO_API_TOKEN:-}" ]] || ! command -v doctl >/dev/null 2>&1; then
    echo ""
    echo "[action required] Add these DNS records for ${APP_HOSTNAME}:"
    echo "  A    @            → ${DROPLET_IP}"
    echo "  A    *.preview    → ${DROPLET_IP}"
    echo ""
    echo "  Once configured, your app will be available at:"
    echo "    Production:  https://${APP_HOSTNAME}"
    echo "    Previews:    https://pr-N.preview.${APP_HOSTNAME}"
    return
  fi

  log "Configuring DNS for ${APP_HOSTNAME} via DigitalOcean..."
  if doctl --access-token "${DO_API_TOKEN}" compute domain get "${APP_HOSTNAME}" >/dev/null 2>&1; then
    echo "[info] domain ${APP_HOSTNAME} already exists in DigitalOcean DNS"
  else
    if ! doctl --access-token "${DO_API_TOKEN}" compute domain create "${APP_HOSTNAME}" >/dev/null 2>&1; then
      echo "[WARN] Unable to create domain ${APP_HOSTNAME} in DigitalOcean DNS." >&2
      echo "[action required] Add these DNS records for ${APP_HOSTNAME} manually:"
      echo "  A    @            → ${DROPLET_IP}"
      echo "  A    *.preview    → ${DROPLET_IP}"
      return
    fi
    echo "[OK]  created domain ${APP_HOSTNAME} in DigitalOcean DNS"
  fi

  if doctl --access-token "${DO_API_TOKEN}" compute domain records create "${APP_HOSTNAME}" \
    --record-type A --record-name "@" --record-data "${DROPLET_IP}" --record-ttl 300 >/dev/null 2>&1; then
    echo "[OK]  DNS A record: ${APP_HOSTNAME} → ${DROPLET_IP}"
  else
    echo "[WARN] Failed to create A record for ${APP_HOSTNAME}. Setup will continue, but you need to add this record manually:" >&2
    echo "       A    @    → ${DROPLET_IP}" >&2
  fi

  if doctl --access-token "${DO_API_TOKEN}" compute domain records create "${APP_HOSTNAME}" \
    --record-type A --record-name "*.preview" --record-data "${DROPLET_IP}" --record-ttl 300 >/dev/null 2>&1; then
    echo "[OK]  DNS A record: *.preview.${APP_HOSTNAME} → ${DROPLET_IP}"
  else
    echo "[WARN] Failed to create wildcard A record for *.preview.${APP_HOSTNAME}. Preview URLs will not work until you add this record manually:" >&2
    echo "       A    *.preview    → ${DROPLET_IP}" >&2
  fi

  echo ""
  echo "  Production URL: https://${APP_HOSTNAME}"
  echo "  Preview URLs:   https://pr-N.preview.${APP_HOSTNAME}"
  echo ""
  echo "  Note: DNS propagation may take a few minutes."
  echo "  If your domain's nameservers are not pointed to DigitalOcean,"
  echo "  update them at your registrar to: ns1.digitalocean.com, ns2.digitalocean.com, ns3.digitalocean.com"
}

offer_ssh_alias() {
  if [[ -z "${DROPLET_IP:-}" ]]; then
    return
  fi

  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    return
  fi

  echo ""
  echo ">> Would you like to add an SSH alias for easy server access?"
  echo "   This adds an entry to ~/.ssh/config so you can run: ssh ${APP_NAME_KEBAB}"
  echo ""
  read -r -p "Add SSH alias? [y/N]: " add_ssh_alias
  if [[ "${add_ssh_alias}" =~ ^[Yy]$ ]]; then
    mkdir -p "${HOME}/.ssh"
    if grep -q "Host ${APP_NAME_KEBAB}" "${HOME}/.ssh/config" 2>/dev/null; then
      echo "[info] SSH alias '${APP_NAME_KEBAB}' already exists in ~/.ssh/config"
    else
      {
        echo ""
        echo "Host ${APP_NAME_KEBAB}"
        echo "  HostName ${DROPLET_IP}"
        echo "  User root"
      } >> "${HOME}/.ssh/config"
      chmod 600 "${HOME}/.ssh/config"
      echo "[OK]  Added SSH alias: ssh ${APP_NAME_KEBAB} → root@${DROPLET_IP}"
    fi
  fi
}

resolve_kamal_version() {
  local kamal_version="${KAMAL_VERSION:-${VERSION:-}}"
  if [[ -z "${kamal_version}" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
    kamal_version="$(git rev-parse --short HEAD 2>/dev/null || true)"
  fi
  if [[ -z "${kamal_version}" ]]; then
    kamal_version="$(date -u +%Y%m%d%H%M%S)"
  fi
  printf '%s' "${kamal_version}"
}

deploy_app_if_needed() {
  local kamal_version
  kamal_version="$(resolve_kamal_version)"

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[dry-run] bundle exec kamal setup --version ${kamal_version}"
    echo "[dry-run] bundle exec kamal deploy --version ${kamal_version}"
    return
  fi
  if [[ -z "${DROPLET_IP:-}" ]]; then
    echo "[ERR] Missing DROPLET_IP, cannot run Kamal deployment." >&2
    exit 1
  fi
  run_cmd bundle exec kamal setup --version "${kamal_version}"
  run_cmd bundle exec kamal deploy --version "${kamal_version}"
}

check_tool() {
  local name="$1"
  local check_cmd="$2"
  local install_hint="$3"
  if command -v "${check_cmd}" >/dev/null 2>&1; then
    echo "[OK]  ${name} already installed ($(command -v "${check_cmd}"))"
  else
    echo "[!!]  ${name} not found."
    echo "      Install hint: ${install_hint}"
    if [[ "${DRY_RUN}" != "true" ]]; then
      echo "[ERR] Please install ${name} and re-run."
      exit 1
    fi
    echo "[dry-run] continuing without ${name}"
  fi
}

to_kebab() {
  # 1. lowercase, 2. spaces/underscores to hyphens, 3. remove non-alphanumeric (except hyphens),
  # 4. collapse consecutive hyphens, 5. trim leading/trailing hyphens
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[ _]/-/g; s/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//'
}

to_pascal() {
  echo "$1" | awk -F'-' '{result=""; for(i=1;i<=NF;i++){result=result toupper(substr($i,1,1)) substr($i,2)}; print result}'
}

to_title() {
  echo "$1" | awk -F'-' '{for(i=1;i<=NF;i++){if(i>1)printf " "; printf "%s%s",toupper(substr($i,1,1)),substr($i,2)}; print ""}'
}

project_dir_has_non_env_files() {
  local dir_path="$1"
  [[ -d "${dir_path}" ]] || return 1
  [[ -n "$(find "${dir_path}" -mindepth 1 -maxdepth 1 ! -name '.env' 2>/dev/null)" ]]
}

handle_existing_project_dir() {
  if ! project_dir_has_non_env_files "${PROJECT_DIR}"; then
    return
  fi

  if [[ "${WIPE_EXISTING}" == "true" ]]; then
    if [[ -z "${PROJECT_DIR}" || "${PROJECT_DIR}" == "/" ]]; then
      echo "[ERR] Refusing to wipe unsafe PROJECT_DIR path: ${PROJECT_DIR}" >&2
      exit 1
    fi
    echo "[WARN] PROJECT_DIR already exists and is not empty: ${PROJECT_DIR}"
    echo "[info] WIPE_EXISTING=true, removing existing directory before continuing."
    rm -rf "${PROJECT_DIR}"
    return
  fi

  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    echo "[ERR] PROJECT_DIR already exists and is not empty: ${PROJECT_DIR}" >&2
    echo "      NON_INTERACTIVE=true: refusing to continue to avoid deleting existing files." >&2
    echo "      Use an empty directory, set PROJECT_DIR to a new path, or set WIPE_EXISTING=true." >&2
    exit 1
  fi

  echo "[WARN] PROJECT_DIR already exists and is not empty: ${PROJECT_DIR}"
  echo "       Enter 'y' to wipe it and continue. Any other input (including Enter) aborts."
  local wipe_existing=""
  read -r -p "Wipe existing directory and continue? [y/N]: " wipe_existing

  if [[ "${wipe_existing}" =~ ^[Yy]$ ]]; then
    if [[ -z "${PROJECT_DIR}" || "${PROJECT_DIR}" == "/" ]]; then
      echo "[ERR] Refusing to wipe unsafe PROJECT_DIR path: ${PROJECT_DIR}" >&2
      exit 1
    fi
    echo "[info] Wiping existing project directory: ${PROJECT_DIR}"
    rm -rf "${PROJECT_DIR}"
    return
  fi

  echo "[ERR] Aborted. Existing directory was not wiped." >&2
  exit 1
}

rename_project() {
  if [[ "${APP_NAME_KEBAB}" == "scaffolded-application" ]]; then
    return 0
  fi

  log "Renaming project from 'scaffolded-application' to '${APP_NAME_KEBAB}'..."

  while IFS= read -r f; do
    sed -i.bak \
      -e "s/scaffoldedapplication/${APP_NAME_COMPACT_NOSPACE}/g" \
      -e "s/ScaffoldedApplication/${APP_NAME_PASCAL}/g" \
      -e "s/Scaffolded Application/${APP_NAME_TITLE}/g" \
      -e "s/scaffolded-application/${APP_NAME_KEBAB}/g" \
      -e "s/scaffolded_application/${APP_NAME_SNAKE}/g" \
      -e "s/ScaffoldedApplication/${APP_NAME_COMPACT}/g" \
      "$f"
    rm -f "${f}.bak"
  done < <(grep -rIEl \
    --exclude-dir=.git \
    --exclude-dir=node_modules \
    --exclude-dir=target \
    --exclude-dir=vendor \
    "scaffoldedapplication|scaffolded-application|scaffolded_application|ScaffoldedApplication|ScaffoldedApplication|Scaffolded Application" \
    "${PROJECT_DIR}" 2>/dev/null || true)

  local new_main_pkg="${PROJECT_DIR}/backend/src/main/java/com/${APP_NAME_COMPACT_NOSPACE}"
  local old_main_pkg="${PROJECT_DIR}/backend/src/main/java/com/scaffoldedapplication"
  if [[ -d "${old_main_pkg}" && "${old_main_pkg}" != "${new_main_pkg}" ]]; then
    mv "${old_main_pkg}" "${new_main_pkg}"
  fi

  local new_test_pkg="${PROJECT_DIR}/backend/src/test/java/com/${APP_NAME_COMPACT_NOSPACE}"
  local old_test_pkg="${PROJECT_DIR}/backend/src/test/java/com/scaffoldedapplication"
  if [[ -d "${old_test_pkg}" && "${old_test_pkg}" != "${new_test_pkg}" ]]; then
    mv "${old_test_pkg}" "${new_test_pkg}"
  fi

  local old_app_class_file="${new_main_pkg}/ScaffoldedApplicationApplication.java"
  local new_app_class_file="${new_main_pkg}/${APP_NAME_PASCAL}Application.java"
  if [[ -f "${old_app_class_file}" && "${old_app_class_file}" != "${new_app_class_file}" ]]; then
    mv "${old_app_class_file}" "${new_app_class_file}"
  fi

  log "Done renaming project."
}

write_project_files() {
  if project_dir_has_non_env_files "${PROJECT_DIR}"; then
    echo "[ERR] PROJECT_DIR already exists and is not empty: ${PROJECT_DIR}" >&2
    echo "      Use an empty directory or set PROJECT_DIR to a new path." >&2
    exit 1
  fi
  mkdir -p "${PROJECT_DIR}"
  cd "${PROJECT_DIR}" || { echo "[ERR] Failed to enter PROJECT_DIR: ${PROJECT_DIR}" >&2; exit 1; }

  local project_source_dir="${SCRIPT_DIR}/project"
  if [[ ! -d "${project_source_dir}" ]]; then
    echo "[ERR] project source directory not found: ${project_source_dir}" >&2
    exit 1
  fi

  # Read ignore patterns from .scaffolderignore
  local ignore_file="${project_source_dir}/.scaffolderignore"
  local ignored_patterns=()
  local line
  if [[ -f "${ignore_file}" ]]; then
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      [[ "${line}" =~ ^[[:space:]]*# ]] && continue
      ignored_patterns+=("${line}")
    done < "${ignore_file}"
  fi

  # Copy all files from project/ to PROJECT_DIR
  local src_file rel_path skip dest_dir pattern
  while IFS= read -r src_file; do
    rel_path="${src_file#"${project_source_dir}"/}"
    # Skip .scaffolderignore itself
    if [[ "${rel_path}" == ".scaffolderignore" ]]; then
      continue
    fi
    # Check if file matches any ignore pattern
    skip="false"
    if [[ ${#ignored_patterns[@]} -gt 0 ]]; then
      for pattern in "${ignored_patterns[@]}"; do
        if [[ "${rel_path}" == "${pattern}" ]]; then
          skip="true"
          break
        fi
      done
    fi
    if [[ "${skip}" == "true" ]]; then
      continue
    fi
    dest_dir="$(dirname "${PROJECT_DIR}/${rel_path}")"
    mkdir -p "${dest_dir}"
    cp "${src_file}" "${PROJECT_DIR}/${rel_path}"
  done < <(find "${project_source_dir}" -type f | sort)
}

main() {
  local _raw_name
  local arg_path_mode="false"
  if [[ -n "${1:-}" ]]; then
    if [[ "$1" == */* || "$1" == .* ]]; then
      arg_path_mode="true"
      PROJECT_DIR="${PROJECT_DIR:-$1}"
      _raw_name="$(basename "$1")"
    else
      _raw_name="$1"
    fi
  elif [[ -n "${PROJECT_DIR:-}" ]]; then
    _raw_name="$(basename "${PROJECT_DIR}")"
  else
    _raw_name="scaffolded-application"
  fi

  APP_NAME_KEBAB="$(to_kebab "${_raw_name}")"
  APP_NAME_SNAKE="${APP_NAME_KEBAB//-/_}"
  APP_NAME_PASCAL="$(to_pascal "${APP_NAME_KEBAB}")"
  APP_NAME_COMPACT="${APP_NAME_KEBAB//-/}"
  APP_NAME_COMPACT_NOSPACE="$(echo "${APP_NAME_COMPACT}" | tr -d '[:space:]')"
  APP_NAME_TITLE="$(to_title "${APP_NAME_KEBAB}")"
  readonly APP_NAME_KEBAB APP_NAME_SNAKE APP_NAME_PASCAL APP_NAME_COMPACT APP_NAME_COMPACT_NOSPACE APP_NAME_TITLE

  local tilde_literal
  tilde_literal="$(printf '\176')"

  if [[ -n "${PROJECT_DIR:-}" ]]; then
    if [[ "${PROJECT_DIR}" == "${tilde_literal}" ]]; then
      PROJECT_DIR="${HOME}"
    elif [[ "${PROJECT_DIR:0:1}" == "${tilde_literal}" && "${PROJECT_DIR:1:1}" == "/" ]]; then
      PROJECT_DIR="${HOME}/${PROJECT_DIR:2}"
    fi
  fi

  portable_realpath() {
    local target="$1"
    # Use realpath -m if available (GNU coreutils); fall back to portable normalization.
    if command -v realpath >/dev/null 2>&1 && realpath -m / >/dev/null 2>&1; then
      realpath -m "${target}"
    elif command -v python3 >/dev/null 2>&1; then
      python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "${target}"
    else
      # Minimal portable normalization: ensure absolute, collapse //, no trailing slash.
      echo "${target}" | sed 's|/\./|/|g; s|//*|/|g; s|/$||'
    fi
  }

  if [[ "${arg_path_mode}" == "true" ]]; then
    if [[ "${PROJECT_DIR}" == /* ]]; then
      PROJECT_DIR="$(portable_realpath "${PROJECT_DIR}")"
    else
      PROJECT_DIR="$(portable_realpath "$(pwd)/${PROJECT_DIR}")"
    fi
  else
    PROJECT_DIR="${PROJECT_DIR:-$(pwd)/${APP_NAME_KEBAB}}"
  fi

  handle_existing_project_dir

  if [[ "${SETUP_COMPACT_OUTPUT}" != "true" ]]; then
    cat <<'EOF'
 ░▒▓███████▓▒░░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓████████▓▒░▒▓████████▓▒░▒▓██████▓▒░░▒▓█▓▒░      ░▒▓███████▓▒░░▒▓████████▓▒░▒▓███████▓▒░
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
 ░▒▓██████▓▒░░▒▓█▓▒░      ░▒▓████████▓▒░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓██████▓▒░ ░▒▓███████▓▒░
       ░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
       ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓██████▓▒░░▒▓████████▓▒░▒▓███████▓▒░░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░

EOF
  fi
  echo "  APP_NAME=${APP_NAME_KEBAB}"
  echo "  PROJECT_DIR=${PROJECT_DIR}"
  echo "  DRY_RUN=${DRY_RUN} NON_INTERACTIVE=${NON_INTERACTIVE} WIPE_EXISTING=${WIPE_EXISTING}"

  if [[ "${SETUP_COMPACT_OUTPUT}" != "true" ]]; then
    cat <<'EOF'

+----------------------------------------------------------+
|                                                          |
|   ░█▀▀░█░█░█▀▀░█▀▀░█░█░▀█▀░█▀█░█▀▀   ░█▀▄░█▀▀░█▀█░█▀▀    |
|   ░█░░░█▀█░█▀▀░█░░░█▀▄░░█░░█░█░█░█   ░█░█░█▀▀░█▀▀░▀▀█    |
|   ░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀   ░▀▀░░▀▀▀░▀░░░▀▀▀    |
|                                                          |
+----------------------------------------------------------+

EOF
  fi
  if command -v mise >/dev/null 2>&1; then
    echo "[OK]  mise already installed"
  elif command -v asdf >/dev/null 2>&1; then
    echo "[OK]  asdf detected -- will create both .mise.toml and .tool-versions"
  else
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "[dry-run] would install mise via https://mise.run"
    else
      log "Installing mise..."
      curl https://mise.run | sh
      eval "$("${HOME}/.local/bin/mise" activate bash)"
      echo "[info] Add 'eval \"\$(mise activate bash)\"' to your shell profile."
    fi
  fi

  check_tool "pnpm" "pnpm" "corepack enable && corepack prepare pnpm@10.33.0 --activate"
  check_tool "docker" "docker" "Install Docker Desktop / Docker Engine"
  check_tool "gh" "gh" "Install GitHub CLI: https://cli.github.com/"
  check_tool "doctl" "doctl" "Install DigitalOcean CLI: https://docs.digitalocean.com/reference/doctl/"
  check_tool "ruby" "ruby" "Install Ruby 4+"
  check_tool "bundle" "bundle" "Install bundler: gem install bundler -v 4.0.10"

  # --- Apply defaults for optional vars ---
  DROPLET_SIZE="${DROPLET_SIZE:-s-1vcpu-1gb}"
  DROPLET_REGION="${DROPLET_REGION:-lon1}"
  DROPLET_IMAGE="${DROPLET_IMAGE:-ubuntu-24-04-x64}"
  DROPLET_TAG="${DROPLET_TAG:-${APP_NAME_KEBAB}}"
  export DROPLET_SIZE DROPLET_REGION DROPLET_IMAGE DROPLET_TAG
  resolve_ssh_key_material

  # --- Validate / collect env vars ---
  local required_vars=(OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET ADMIN_GITHUB_USERNAMES DO_API_TOKEN KAMAL_REGISTRY_USERNAME KAMAL_REGISTRY_PASSWORD)

  if [[ "${NON_INTERACTIVE}" == "true" ]]; then
    # In DRY_RUN, fill placeholder values for any missing required vars so the run can complete.
    if [[ "${DRY_RUN}" == "true" ]]; then
      : "${OAUTH_CLIENT_ID:=test-client-id}"
      : "${OAUTH_CLIENT_SECRET:=test-client-secret}"
      : "${ADMIN_GITHUB_USERNAMES:=testadmin}"
      : "${DO_API_TOKEN:=test-token}"
      : "${KAMAL_REGISTRY_USERNAME:=test-registry-user}"
      : "${KAMAL_REGISTRY_PASSWORD:=test-registry-pw}"
      : "${DROPLET_IP:=127.0.0.1}"
      export OAUTH_CLIENT_ID OAUTH_CLIENT_SECRET ADMIN_GITHUB_USERNAMES DO_API_TOKEN KAMAL_REGISTRY_USERNAME KAMAL_REGISTRY_PASSWORD DROPLET_IP
    fi

    # Validate all required vars at once.
    local missing=()
    for var in "${required_vars[@]}"; do
      if [[ -z "${!var:-}" ]]; then
        missing+=("${var}")
      fi
    done
    # DROPLET_SSH_KEY_FINGERPRINT is required when DROPLET_IP is not set (auto-provisioning).
    if [[ -z "${DROPLET_IP:-}" && -z "${DROPLET_SSH_KEY_FINGERPRINT:-}" ]]; then
      missing+=("DROPLET_IP or DROPLET_SSH_KEY_FINGERPRINT (or DROPLET_SSH_PRIVATE_KEY_PATH)")
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
      echo "[ERR] Missing required environment variables:" >&2
      for var in "${missing[@]}"; do
        echo "      - ${var}" >&2
      done
      echo "" >&2
      echo "      Set them in .env or export them, then re-run." >&2
      exit 1
    fi
  else
    # Interactive: prompt only for vars that are still empty.
    local detected_github_username=""
    detected_github_username="$(detect_github_username)"

    prompt_value OAUTH_CLIENT_ID "Paste GitHub OAuth client ID" ""
    prompt_value OAUTH_CLIENT_SECRET "Paste GitHub OAuth client secret" ""
    prompt_value ADMIN_GITHUB_USERNAMES "Comma-separated GitHub admins" "${detected_github_username}"
    prompt_value DO_API_TOKEN "Paste your DigitalOcean API token" ""
    prompt_value KAMAL_REGISTRY_USERNAME "Paste GHCR username (not ghcr.io/... path)" ""
    prompt_value KAMAL_REGISTRY_PASSWORD "Paste GHCR token/password" ""

    echo ""
    echo ">> Available DigitalOcean droplet sizes (slug values):"
    if ! run_cmd doctl compute size list; then
      echo "[warn] Unable to list droplet sizes automatically; setup will continue."
      echo "       You can run: doctl compute size list"
    fi
    prompt_optional_value DROPLET_SIZE "Droplet size slug" "${DROPLET_SIZE}"
    prompt_optional_value DROPLET_REGION "DigitalOcean region" "${DROPLET_REGION}"
    prompt_optional_value DROPLET_IMAGE "DigitalOcean image slug" "${DROPLET_IMAGE}"
    prompt_optional_value DROPLET_SSH_PRIVATE_KEY_PATH "SSH private key path (optional; used to infer fingerprint and avoid pasting key contents)" ""
    prompt_optional_value DROPLET_SSH_KEY_FINGERPRINT "SSH key fingerprint (optional if key path is set; required to auto-provision when DROPLET_IP is empty)" ""
    prompt_optional_value DROPLET_IP "Droplet IP (leave blank to auto-provision via doctl)" ""
    resolve_ssh_key_material

    if [[ -z "${DROPLET_IP:-}" && -z "${DROPLET_SSH_KEY_FINGERPRINT:-}" ]]; then
      echo "[ERR] Either DROPLET_IP or DROPLET_SSH_KEY_FINGERPRINT must be set." >&2
      echo "      Set DROPLET_IP to use an existing server, set DROPLET_SSH_PRIVATE_KEY_PATH to infer fingerprint, or set DROPLET_SSH_KEY_FINGERPRINT explicitly to auto-provision." >&2
      exit 1
    fi
  fi

  KAMAL_REGISTRY_USERNAME="${KAMAL_REGISTRY_USERNAME#https://}"
  KAMAL_REGISTRY_USERNAME="${KAMAL_REGISTRY_USERNAME#http://}"
  KAMAL_REGISTRY_USERNAME="${KAMAL_REGISTRY_USERNAME#ghcr.io/}"
  KAMAL_REGISTRY_USERNAME="${KAMAL_REGISTRY_USERNAME#/}"
  KAMAL_REGISTRY_USERNAME="${KAMAL_REGISTRY_USERNAME%/}"
  if [[ -z "${KAMAL_REGISTRY_USERNAME}" ]]; then
    echo "[ERR] KAMAL_REGISTRY_USERNAME resolved to an empty value. Use only your GHCR username (for example: piprees)." >&2
    exit 1
  fi

  provision_droplet_if_needed
  apply_new_droplet_security_baseline
  if [[ "${NON_INTERACTIVE}" != "true" ]]; then
    prompt_optional_value APP_HOSTNAME "Custom domain (e.g. example.com; leave blank for IP-based sslip.io URLs)" ""
  fi
  configure_dns_if_needed
  offer_ssh_alias

  if [[ "${SETUP_COMPACT_OUTPUT}" != "true" ]]; then
    cat <<'EOF'

░██████                         ░██               ░██ ░██ ░██
  ░██                           ░██               ░██ ░██
  ░██  ░████████   ░███████  ░████████  ░██████   ░██ ░██ ░██░████████   ░████████
  ░██  ░██    ░██ ░██           ░██          ░██  ░██ ░██ ░██░██    ░██ ░██    ░██
  ░██  ░██    ░██  ░███████     ░██     ░███████  ░██ ░██ ░██░██    ░██ ░██    ░██
  ░██  ░██    ░██        ░██    ░██    ░██   ░██  ░██ ░██ ░██░██    ░██ ░██   ░███
░██████░██    ░██  ░███████      ░████  ░█████░██ ░██ ░██ ░██░██    ░██  ░█████░██ ░██ ░██ ░██
                                                                               ░██
                                                                         ░███████

EOF
  fi
  write_project_files
  rename_project

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[dry-run] bundle install"
  else
    run_cmd bundle install
  fi

  cat > .env <<EOF
# GitHub OAuth app client ID used by the backend auth flow.
# Find it in GitHub -> Settings -> Developer settings -> OAuth Apps -> your app.
OAUTH_CLIENT_ID=${OAUTH_CLIENT_ID}
# GitHub OAuth app client secret paired with OAUTH_CLIENT_ID.
# Find it in GitHub -> Settings -> Developer settings -> OAuth Apps -> your app.
OAUTH_CLIENT_SECRET=${OAUTH_CLIENT_SECRET}
# Comma-separated GitHub usernames that should have admin access in the app.
# Find/set this from your GitHub org/repo user list.
ADMIN_GITHUB_USERNAMES=${ADMIN_GITHUB_USERNAMES}
# DigitalOcean API token used for droplet/DNS operations.
# Create it in DigitalOcean -> API -> Tokens/Keys.
DO_API_TOKEN=${DO_API_TOKEN}
# GHCR username for container image pushes.
# Usually your GitHub username (or org bot account username); do not include ghcr.io/.
KAMAL_REGISTRY_USERNAME=${KAMAL_REGISTRY_USERNAME}
# GHCR password/token used by Kamal for registry auth.
# Use a GitHub PAT with package scopes (or GITHUB_TOKEN in GitHub Actions).
KAMAL_REGISTRY_PASSWORD=${KAMAL_REGISTRY_PASSWORD}
# Postgres password used by Kamal accessories and deploy workflows.
# Generate a strong random value, e.g. with openssl rand -base64 32.
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-}
# DigitalOcean droplet size slug for provisioning.
# List available values with doctl compute size list.
DROPLET_SIZE=${DROPLET_SIZE}
# Optional: DigitalOcean droplet ID (used by teardown/automation).
# Find it via doctl compute droplet list or the DigitalOcean dashboard.
DROPLET_ID=${DROPLET_ID:-}
# Optional: Droplet public IPv4 address (leave blank to auto-provision).
# Find it via doctl compute droplet list or the DigitalOcean dashboard.
DROPLET_IP=${DROPLET_IP:-}
# Optional: Droplet tag used for IP discovery in CI/teardown.
# Find/set it in DigitalOcean tags or via doctl compute droplet list --tag-name <tag>.
DROPLET_TAG=${DROPLET_TAG:-${APP_NAME_KEBAB}}
# Optional: DigitalOcean region slug (defaults to lon1).
# List available values with doctl compute region list.
DROPLET_REGION=${DROPLET_REGION:-lon1}
# Optional: DigitalOcean image slug (defaults to ubuntu-24-04-x64).
# List available values with doctl compute image list-distribution ubuntu.
DROPLET_IMAGE=${DROPLET_IMAGE:-ubuntu-24-04-x64}
# Optional: Local SSH private key path used by setup.sh to load key contents and infer fingerprint.
# Example: ~/.ssh/id_ed25519
DROPLET_SSH_PRIVATE_KEY_PATH=${DROPLET_SSH_PRIVATE_KEY_PATH:-}
# Optional: SSH key fingerprint used when auto-provisioning droplets.
# Find it with doctl compute ssh-key list or in DigitalOcean -> Settings -> Security.
DROPLET_SSH_KEY_FINGERPRINT=${DROPLET_SSH_KEY_FINGERPRINT:-}
# Optional: Custom app domain (enables TLS + clean preview URLs).
# Find/use a domain you control in your DNS provider (DigitalOcean DNS or registrar).
APP_HOSTNAME=${APP_HOSTNAME:-}
EOF
  chmod 600 .env

  if command -v git >/dev/null 2>&1; then
    run_cmd git init -b main
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[dry-run] pnpm install"
  else
    run_cmd pnpm install
  fi

  deploy_app_if_needed

  echo ""
  if [[ "${SETUP_COMPACT_OUTPUT}" != "true" ]]; then
    cat <<'EOF'
██▄   ████▄    ▄   ▄███▄
█  █  █   █     █  █▀   ▀
█   █ █   █ ██   █ ██▄▄
█  █  ▀████ █ █  █ █▄   ▄▀
███▀        █  █ █ ▀███▀
            █   ██

EOF
  fi
  echo "  Your app scaffold is ready!"
  echo "  Location:   ${PROJECT_DIR}"
  echo "  Droplet ID: ${DROPLET_ID:-n/a}"
  echo "  Droplet IP: ${DROPLET_IP:-n/a}"
  if [[ -n "${DROPLET_SSH_PRIVATE_KEY_PATH:-}" ]]; then
    echo "  SSH key:    ${DROPLET_SSH_PRIVATE_KEY_PATH}"
    if command -v pbcopy >/dev/null 2>&1; then
      echo "  Copy key:   pbcopy < \"${DROPLET_SSH_PRIVATE_KEY_PATH}\""
    fi
  fi
  echo "  Local dev:  pnpm dev -> http://localhost:3000"
  echo "  Contract:   contract/openapi.yml"
  echo "  Regenerate: pnpm generate"
  echo "  Format:     pnpm format"
}

main "$@"
