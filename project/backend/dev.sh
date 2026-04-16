#!/usr/bin/env bash
set -euo pipefail
# backend/dev.sh - load ../.env into the environment then start DB + backend

DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$DIR/../.env"
DOCKER_FILE="$DIR/../docker-compose.dev.yml"

if [ -f "$ENV_FILE" ]; then
  echo "Loading env from $ENV_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  unset APP_HOSTNAME;
  unset DROPLET_IP;
  set +a
else
  echo "Warning: $ENV_FILE not found; proceeding without loading .env"
fi

echo "Starting Postgres container via $DOCKER_FILE..."
docker compose --file "$DOCKER_FILE" up -d db --remove-orphans

echo "Waiting for Postgres to be ready..."
"$DIR/wait-for-postgres.sh"

echo "Starting Spring Boot..."
exec mvn --no-transfer-progress spring-boot:run

