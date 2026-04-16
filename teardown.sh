#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="${SCRIPT_DIR}"
DEFAULT_TARGET_DIR="${REPO_ROOT}/scaffolded-application"
TARGET_DIR="${1:-${DEFAULT_TARGET_DIR}}"
DRY_RUN="${DRY_RUN:-false}"

run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    echo ""
    return 0
  fi
  "$@"
}

run_optional() {
  local label="$1"
  shift
  if run_cmd "$@"; then
    return 0
  fi
  echo "[WARN] ${label} failed, continuing teardown." >&2
  return 0
}

read_env_key() {
  local key="$1"
  local env_file="$2"
  awk -F= -v key="${key}" '$1 == key || $1 == "#" key { sub(/^[^=]*=/, "", $0); print $0; exit }' "${env_file}"
}

load_env_key_if_unset() {
  local key="$1"
  local env_file="$2"
  local current="${!key:-}"
  local value=""

  if [[ -n "${current}" || ! -f "${env_file}" ]]; then
    return
  fi

  value="$(read_env_key "${key}" "${env_file}" || true)"
  if [[ -n "${value}" ]]; then
    export "${key}=${value}"
  fi
}

cleanup_droplet() {
  local target_dir_abs="$1"
  local droplet_id="${DROPLET_ID:-}"
  local droplet_tag="${DROPLET_TAG:-}"
  local tagged_droplets=""
  local tagged_count="0"
  local droplet_list=""

  if [[ -z "${droplet_tag}" ]]; then
    droplet_tag="$(basename -- "${target_dir_abs}")"
  fi

  if [[ -z "${DO_API_TOKEN:-}" ]] || ! command -v doctl >/dev/null 2>&1; then
    if [[ -n "${droplet_id}${DROPLET_IP:-}${droplet_tag}" ]]; then
      echo "[WARN] Droplet cleanup requested but doctl or DO_API_TOKEN is missing; skipping droplet deletion." >&2
    fi
    return
  fi

  if [[ -z "${droplet_id}" && -n "${droplet_tag}" ]]; then
    if tagged_droplets="$(doctl --access-token "${DO_API_TOKEN}" compute droplet list --tag-name "${droplet_tag}" --format ID,PublicIPv4 --no-header)"; then
      if [[ -n "${DROPLET_IP:-}" ]]; then
        droplet_id="$(awk -v ip="${DROPLET_IP}" '$2 == ip { print $1; exit }' <<<"${tagged_droplets}")"
      fi

      if [[ -z "${droplet_id}" ]]; then
        tagged_count="$(awk 'NF {count++} END {print count+0}' <<<"${tagged_droplets}")"
        if [[ "${tagged_count}" -eq 1 ]]; then
          droplet_id="$(awk 'NF {print $1; exit}' <<<"${tagged_droplets}")"
        elif [[ "${tagged_count}" -gt 1 ]]; then
          echo "[WARN] Multiple droplets found for DROPLET_TAG=${droplet_tag}; set DROPLET_ID or DROPLET_IP to disambiguate. Skipping droplet deletion to avoid removing the wrong server." >&2
        fi
      fi
    else
      echo "[WARN] Unable to list droplets for DROPLET_TAG=${droplet_tag}; check DO_API_TOKEN and doctl connectivity." >&2
    fi
  fi

  if [[ -z "${droplet_id}" && -n "${DROPLET_IP:-}" ]]; then
    if droplet_list="$(doctl --access-token "${DO_API_TOKEN}" compute droplet list --format ID,PublicIPv4 --no-header)"; then
      droplet_id="$(awk -v ip="${DROPLET_IP}" '$2 == ip { print $1; exit }' <<<"${droplet_list}")"
      if [[ -z "${droplet_id}" ]]; then
        echo "[WARN] No droplet found for DROPLET_IP=${DROPLET_IP}; skipping droplet deletion." >&2
      fi
    else
      echo "[WARN] Unable to list droplets with doctl; skipping DROPLET_IP lookup." >&2
    fi
  fi

  if [[ -n "${droplet_id}" ]]; then
    run_optional "droplet delete" doctl --access-token "${DO_API_TOKEN}" compute droplet delete "${droplet_id}" --force
  fi
}

resolve_dns_target_ips() {
  local target_dir_abs="$1"
  local droplet_tag="${DROPLET_TAG:-}"
  local resolved_ips=""
  local tagged_ips=""

  if [[ -n "${DROPLET_IP:-}" ]]; then
    resolved_ips+="${DROPLET_IP}"$'\n'
  fi

  if [[ -z "${droplet_tag}" ]]; then
    droplet_tag="$(basename -- "${target_dir_abs}")"
  fi

  if [[ -n "${droplet_tag}" ]] && [[ -n "${DO_API_TOKEN:-}" ]] && command -v doctl >/dev/null 2>&1; then
    tagged_ips="$(doctl --access-token "${DO_API_TOKEN}" compute droplet list --tag-name "${droplet_tag}" --format PublicIPv4 --no-header 2>/dev/null || true)"
    if [[ -n "${tagged_ips}" ]]; then
      while IFS= read -r ip; do
        [[ -z "${ip}" ]] && continue
        resolved_ips+="${ip}"$'\n'
      done <<< "${tagged_ips}"
    fi
  fi

  printf '%s' "${resolved_ips}" | awk 'NF && !seen[$1]++ { print $1 }'
}

cleanup_dns_records() {
  local target_dir_abs="$1"
  local app_hostname="${APP_HOSTNAME:-}"
  local target_ips=""
  local record_list=""
  local record_ids=""

  if [[ -z "${app_hostname}" ]]; then
    return
  fi

  if [[ -z "${DO_API_TOKEN:-}" ]] || ! command -v doctl >/dev/null 2>&1; then
    echo "[WARN] DNS cleanup requested for APP_HOSTNAME=${app_hostname} but doctl or DO_API_TOKEN is missing; skipping DNS cleanup." >&2
    return
  fi

  if ! record_list="$(doctl --access-token "${DO_API_TOKEN}" compute domain records list "${app_hostname}" --format ID,Type,Name,Data --no-header 2>/dev/null || true)"; then
    echo "[WARN] Unable to list DNS records for ${app_hostname}; skipping DNS cleanup." >&2
    return
  fi

  if [[ -z "${record_list}" ]]; then
    return
  fi

  target_ips="$(resolve_dns_target_ips "${target_dir_abs}")"
  if [[ -z "${target_ips}" ]]; then
    echo "[WARN] No droplet IPs resolved from DROPLET_TAG/DROPLET_IP; skipping DNS cleanup to avoid deleting unrelated records." >&2
    return
  fi

  record_ids="$(awk -v ips="${target_ips}" '
BEGIN {
  n = split(ips, ip_list, "\n")
  for (i = 1; i <= n; i++) {
    if (ip_list[i] != "") {
      allowed_ips[ip_list[i]] = 1
    }
  }
}
$2 == "A" && ($3 == "@" || $3 == "*.preview") && ($4 in allowed_ips) { print $1 }
' <<<"${record_list}")"
  if [[ -z "${record_ids}" ]]; then
    return
  fi

  while IFS= read -r record_id; do
    [[ -z "${record_id}" ]] && continue
    run_optional "DNS record delete" doctl --access-token "${DO_API_TOKEN}" compute domain records delete "${app_hostname}" "${record_id}" --force
  done <<< "${record_ids}"
}

if [[ -z "${TARGET_DIR}" || "${TARGET_DIR}" == "/" ]]; then
  echo "[ERR] Refusing to delete an empty path or root directory." >&2
  exit 1
fi

TARGET_PARENT="$(dirname -- "${TARGET_DIR}")"
TARGET_NAME="$(basename -- "${TARGET_DIR}")"
TARGET_PARENT_ABS="$(cd "${TARGET_PARENT}" 2>/dev/null && pwd -P)" || {
  echo "[ERR] Refusing to delete: unable to resolve target parent directory: ${TARGET_PARENT}" >&2
  exit 1
}
TARGET_DIR_ABS="${TARGET_PARENT_ABS}/${TARGET_NAME}"

case "${TARGET_DIR_ABS}" in
  "${DEFAULT_TARGET_DIR}"|"${REPO_ROOT}"/*)
    ;;
  *)
    echo "[ERR] Refusing to delete unsafe path outside the repository: ${TARGET_DIR_ABS}" >&2
    exit 1
    ;;
esac

if [[ "${DRY_RUN}" == "true" ]]; then
  echo ">> [dry-run] Would run project teardown at: ${TARGET_DIR_ABS}/teardown.sh (if present)"
  echo ">> [dry-run] Would attempt DNS cleanup for APP_HOSTNAME (A @ and A *.preview records)"
  echo ">> [dry-run] Would attempt droplet cleanup via DROPLET_ID, DROPLET_TAG, or DROPLET_IP"
  echo ">> [dry-run] Would remove generated project at: ${TARGET_DIR_ABS}"
  echo ">> [dry-run] No actions were executed."
  exit 0
fi

TARGET_ENV_FILE="${TARGET_DIR_ABS}/.env"
ROOT_ENV_FILE="${SCRIPT_DIR}/.env"
TARGET_TEARDOWN_SCRIPT="${TARGET_DIR_ABS}/teardown.sh"

load_env_key_if_unset DO_API_TOKEN "${TARGET_ENV_FILE}"
load_env_key_if_unset DROPLET_ID "${TARGET_ENV_FILE}"
load_env_key_if_unset DROPLET_IP "${TARGET_ENV_FILE}"
load_env_key_if_unset DROPLET_TAG "${TARGET_ENV_FILE}"
load_env_key_if_unset APP_HOSTNAME "${TARGET_ENV_FILE}"

load_env_key_if_unset DO_API_TOKEN "${ROOT_ENV_FILE}"
load_env_key_if_unset DROPLET_ID "${ROOT_ENV_FILE}"
load_env_key_if_unset DROPLET_IP "${ROOT_ENV_FILE}"
load_env_key_if_unset DROPLET_TAG "${ROOT_ENV_FILE}"
load_env_key_if_unset APP_HOSTNAME "${ROOT_ENV_FILE}"

if [[ -f "${TARGET_TEARDOWN_SCRIPT}" ]]; then
  echo ">> Running project teardown at: ${TARGET_TEARDOWN_SCRIPT}"
  run_optional "project teardown" bash "${TARGET_TEARDOWN_SCRIPT}"
fi

cleanup_dns_records "${TARGET_DIR_ABS}"
cleanup_droplet "${TARGET_DIR_ABS}"

echo ">> Removing generated project at: ${TARGET_DIR_ABS}"
run_cmd rm -rf "${TARGET_DIR_ABS}"
echo ">> Done. You can run setup.sh again."
