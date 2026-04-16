#!/usr/bin/env bash
set -euo pipefail

RETRIES="${POSTGRES_RETRIES:-30}"
INTERVAL="${POSTGRES_INTERVAL:-2}"
DB_USER="${POSTGRES_USER:-scaffolded_application}"
DB_NAME="${POSTGRES_DB:-scaffolded_application}"

echo "Waiting for Postgres to be ready (user=${DB_USER} db=${DB_NAME})..."
for i in $(seq 1 "${RETRIES}"); do
  if pg_isready -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; then
    echo "Postgres is ready."
    exit 0
  fi
  echo "  attempt ${i}/${RETRIES} - not ready yet, sleeping ${INTERVAL}s..."
  sleep "${INTERVAL}"
done

echo "[ERR] Postgres did not become ready after ${RETRIES} attempts." >&2
exit 1
