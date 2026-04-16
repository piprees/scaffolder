#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}"

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

resolve_teardown_kamal_version() {
  local kamal_version="${KAMAL_VERSION:-${VERSION:-}}"
  if [[ -z "${kamal_version}" ]] && git rev-parse --git-dir >/dev/null 2>&1; then
    kamal_version="$(git rev-parse --short HEAD 2>/dev/null || true)"
  fi
  if [[ -z "${kamal_version}" ]]; then
    kamal_version="$(date -u +%Y%m%d%H%M%S)"
  fi
  printf '%s' "${kamal_version}"
}

read_env_key() {
  local key="$1"
  local env_file="$2"
  awk -F= -v key="${key}" '$1 == key || $1 == "#" key { sub(/^[^=]*=/, "", $0); print $0; exit }' "${env_file}"
}

load_env_key_if_unset() {
  local key="$1"
  local current="${!key:-}"
  local value=""
  if [[ -n "${current}" || ! -f "${SCRIPT_DIR}/.env" ]]; then
    return
  fi
  value="$(read_env_key "${key}" "${SCRIPT_DIR}/.env" || true)"
  if [[ -n "${value}" ]]; then
    printf -v "${key}" '%s' "${value}"
    export "${key}"
  fi
}

cleanup_dns_records() {
  local droplet_tag="${DROPLET_TAG:-}"
  local app_hostname="${APP_HOSTNAME:-}"
  local target_ips=""
  local tagged_ips=""
  local record_list=""
  local record_ids=""

  if [[ -z "${droplet_tag}" ]]; then
    droplet_tag="$(basename "${SCRIPT_DIR}")"
  fi

  if [[ -z "${app_hostname}" ]]; then
    return
  fi

  if [[ -z "${DO_API_TOKEN:-}" ]] || ! command -v doctl >/dev/null 2>&1; then
    echo "[WARN] APP_HOSTNAME is set but doctl or DO_API_TOKEN is missing, skipping DNS cleanup." >&2
    return
  fi

  if [[ -n "${DROPLET_IP:-}" ]]; then
    target_ips+="${DROPLET_IP}"$'\n'
  fi

  if [[ -n "${droplet_tag}" ]]; then
    tagged_ips="$(doctl --access-token "${DO_API_TOKEN}" compute droplet list --tag-name "${droplet_tag}" --format PublicIPv4 --no-header 2>/dev/null || true)"
    if [[ -n "${tagged_ips}" ]]; then
      while IFS= read -r ip; do
        [[ -z "${ip}" ]] && continue
        target_ips+="${ip}"$'\n'
      done <<< "${tagged_ips}"
    fi
  fi

  target_ips="$(printf '%s' "${target_ips}" | awk 'NF && !seen[$1]++ { print $1 }')"
  if [[ -z "${target_ips}" ]]; then
    echo "[WARN] No droplet IPs resolved from DROPLET_TAG/DROPLET_IP, skipping DNS cleanup to avoid deleting unrelated records." >&2
    return
  fi

  if ! record_list="$(doctl --access-token "${DO_API_TOKEN}" compute domain records list "${app_hostname}" --format ID,Type,Name,Data --no-header 2>/dev/null || true)"; then
    echo "[WARN] Unable to list DNS records for ${app_hostname}, skipping DNS cleanup." >&2
    return
  fi

  if [[ -z "${record_list}" ]]; then
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

load_env_key_if_unset DO_API_TOKEN
load_env_key_if_unset DROPLET_ID
load_env_key_if_unset DROPLET_IP
load_env_key_if_unset DROPLET_TAG
load_env_key_if_unset APP_HOSTNAME

echo ">> Tearing down deployment and local environment..."
if [[ -f Gemfile ]]; then
  kamal_version="$(resolve_teardown_kamal_version)"
  run_optional "kamal remove" bundle exec kamal remove --version "${kamal_version}" --confirmed
fi

run_optional "docker compose down" docker compose down --volumes --remove-orphans
cleanup_dns_records

droplet_id="${DROPLET_ID:-}"
droplet_tag="${DROPLET_TAG:-}"
if [[ -z "${droplet_tag}" ]]; then
  droplet_tag="$(basename "${SCRIPT_DIR}")"
fi
if [[ -z "${droplet_id}" ]] && command -v doctl >/dev/null 2>&1 && [[ -n "${DO_API_TOKEN:-}" ]]; then
  if [[ -n "${droplet_tag}" ]]; then
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
      echo "[WARN] Unable to list droplets for DROPLET_TAG=${droplet_tag}, skipping tag lookup. Check DO_API_TOKEN and doctl connectivity." >&2
    fi
  fi
fi

if [[ -z "${droplet_id}" ]] && [[ -n "${DROPLET_IP:-}" ]] &&
  command -v doctl >/dev/null 2>&1 && [[ -n "${DO_API_TOKEN:-}" ]]; then
  if droplet_list="$(doctl --access-token "${DO_API_TOKEN}" compute droplet list --format ID,PublicIPv4 --no-header)"; then
    droplet_id="$(awk -v ip="${DROPLET_IP}" '$2 == ip { print $1; exit }' <<<"${droplet_list}")"
    if [[ -z "${droplet_id}" ]]; then
      echo "[WARN] No droplet found for DROPLET_IP=${DROPLET_IP}, skipping droplet deletion." >&2
    fi
  else
    echo "[WARN] Unable to list droplets with doctl, skipping DROPLET_IP lookup." >&2
  fi
fi

if [[ -n "${droplet_id}" ]]; then
  if command -v doctl >/dev/null 2>&1 && [[ -n "${DO_API_TOKEN:-}" ]]; then
    run_optional "droplet delete" doctl --access-token "${DO_API_TOKEN}" compute droplet delete "${droplet_id}" --force
  else
    echo "[WARN] DROPLET_ID is set but doctl or DO_API_TOKEN is missing, skipping droplet deletion." >&2
  fi
fi

rm -rf frontend/node_modules contract/node_modules node_modules backend/target vendor/bundle
rm -rf frontend/src/generated backend/src/generated
echo ">> Teardown complete. You can run pnpm install and pnpm dev again."
