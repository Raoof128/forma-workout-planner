#!/usr/bin/env bash
set -euo pipefail

: "${BACKUP_AGE_RECIPIENT:?Set BACKUP_AGE_RECIPIENT to the off-host age public recipient}"
: "${BACKUP_REMOTE:?Set BACKUP_REMOTE to an access-controlled rclone destination}"
: "${COMPOSE_PROJECT_NAME:?Set COMPOSE_PROJECT_NAME, for example forma-staging}"
: "${COMPOSE_ENV_FILE:?Set COMPOSE_ENV_FILE to the protected deployment env file}"

command -v age >/dev/null || { echo "age is required." >&2; exit 2; }
command -v rclone >/dev/null || { echo "rclone is required." >&2; exit 2; }
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
stamp=$(date -u +%Y%m%dT%H%M%SZ)
name="forma-${COMPOSE_PROJECT_NAME}-${stamp}.dump.age"
archive="$temp_dir/$name"
compose=(docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" -f ops/compose.yaml)

"${compose[@]}" exec -T db sh -c 'export PGPASSWORD="$(cat "$POSTGRES_PASSWORD_FILE")"; exec pg_dump --host=127.0.0.1 --username="$POSTGRES_USER" --dbname=forma --format=custom --no-owner --no-privileges' \
  | age --encrypt --recipient "$BACKUP_AGE_RECIPIENT" --output "$archive"
(cd "$temp_dir" && sha256sum "$name" > "$name.sha256")
rclone copyto "$archive" "${BACKUP_REMOTE%/}/$name"
rclone copyto "$archive.sha256" "${BACKUP_REMOTE%/}/$name.sha256"
printf 'Encrypted PostgreSQL backup uploaded: %s/%s\n' "${BACKUP_REMOTE%/}" "$name"
