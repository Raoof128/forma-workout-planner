#!/usr/bin/env bash
set -euo pipefail

: "${MIGRATION_DB_PASSWORD:?Set MIGRATION_DB_PASSWORD in the deployment environment}"
: "${COMPOSE_PROJECT_NAME:?Set COMPOSE_PROJECT_NAME, for example forma-staging}"
: "${COMPOSE_ENV_FILE:?Set COMPOSE_ENV_FILE to the protected deployment env file}"
[[ "$MIGRATION_DB_PASSWORD" =~ ^[a-f0-9]{64}$ ]] || { echo "Migration role password must be 64 lowercase hexadecimal characters." >&2; exit 2; }

compose=(docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" -f ops/compose.yaml)
# Pass the password through the environment, not argv, so host `ps` never shows it.
PGPASSWORD="$MIGRATION_DB_PASSWORD" "${compose[@]}" exec -T -e PGPASSWORD db \
  psql -h 127.0.0.1 -U forma_migrator -d forma -v ON_ERROR_STOP=1 \
  < ops/grant-runtime-access.sql
