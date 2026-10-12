#!/usr/bin/env bash
set -euo pipefail

: "${POSTGRES_ADMIN_PASSWORD_FILE:?Set POSTGRES_ADMIN_PASSWORD_FILE to a protected local file}"
: "${APP_DB_PASSWORD:?Set APP_DB_PASSWORD in the deployment environment}"
: "${MIGRATION_DB_PASSWORD:?Set MIGRATION_DB_PASSWORD in the deployment environment}"
: "${COMPOSE_PROJECT_NAME:?Set COMPOSE_PROJECT_NAME, for example forma-staging}"
: "${COMPOSE_ENV_FILE:?Set COMPOSE_ENV_FILE to the protected deployment env file}"

for value in "$APP_DB_PASSWORD" "$MIGRATION_DB_PASSWORD"; do
  [[ "$value" =~ ^[a-f0-9]{64}$ ]] || { echo "Database role passwords must be 64 lowercase hexadecimal characters." >&2; exit 2; }
done
[[ "$APP_DB_PASSWORD" != "$MIGRATION_DB_PASSWORD" ]] || { echo "Runtime and migration passwords must differ." >&2; exit 2; }
[[ -r "$POSTGRES_ADMIN_PASSWORD_FILE" ]] || { echo "PostgreSQL administrator password file is unreadable." >&2; exit 2; }

compose=(docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" -f ops/compose.yaml)
{
  printf '\\set app_password %s\n' "$APP_DB_PASSWORD"
  printf '\\set migration_password %s\n' "$MIGRATION_DB_PASSWORD"
  cat ops/bootstrap-db-roles.sql
} | "${compose[@]}" exec -T db sh -c 'export PGPASSWORD="$(cat "$POSTGRES_PASSWORD_FILE")"; exec psql -h 127.0.0.1 -U "$POSTGRES_USER" -d forma -v ON_ERROR_STOP=1'
