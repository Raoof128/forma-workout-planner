#!/usr/bin/env bash
set -euo pipefail

: "${BACKUP_REMOTE:?Set BACKUP_REMOTE to the access-controlled rclone destination}"
: "${BACKUP_ARCHIVE:?Set BACKUP_ARCHIVE to the encrypted archive filename}"
: "${BACKUP_AGE_IDENTITY_FILE:?Set BACKUP_AGE_IDENTITY_FILE to the protected decryption identity file}"
: "${RESTORE_DATABASE_NAME:?Set a pre-created isolated database name beginning forma_restore_}"
: "${RESTORE_DATABASE_URL:?Set RESTORE_DATABASE_URL to the isolated restore database}"
: "${COMPOSE_PROJECT_NAME:?Set COMPOSE_PROJECT_NAME, for example forma-staging}"
: "${COMPOSE_ENV_FILE:?Set COMPOSE_ENV_FILE to the protected deployment env file}"

[[ "$RESTORE_DATABASE_NAME" =~ ^forma_restore_[a-zA-Z0-9_]+$ ]] || { echo "Refusing restore: destination database must begin forma_restore_." >&2; exit 2; }
[[ "$RESTORE_DATABASE_URL" == */"$RESTORE_DATABASE_NAME" ]] || { echo "Refusing restore: URL database does not match RESTORE_DATABASE_NAME." >&2; exit 2; }
# Query parameters such as ?dbname= can override the path database, so the URL must carry none.
[[ "$RESTORE_DATABASE_URL" != *\?* ]] || { echo "Refusing restore: RESTORE_DATABASE_URL must not contain query parameters." >&2; exit 2; }
[[ "$BACKUP_ARCHIVE" =~ ^forma-[A-Za-z0-9_-]+-[0-9]{8}T[0-9]{6}Z\.dump\.age$ ]] || { echo "Backup archive name is invalid." >&2; exit 2; }
[[ -r "$BACKUP_AGE_IDENTITY_FILE" ]] || { echo "Backup decryption identity is unreadable." >&2; exit 2; }
command -v age >/dev/null || { echo "age is required." >&2; exit 2; }
command -v rclone >/dev/null || { echo "rclone is required." >&2; exit 2; }

compose=(docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$COMPOSE_ENV_FILE" -f ops/compose.yaml)
# Confirm the connection really lands in the isolated database before anything
# is downloaded or written. Run it where pg_restore runs (the db container),
# so the URL resolves the same way.
connected_database=$("${compose[@]}" exec -T db psql "$RESTORE_DATABASE_URL" -tAc 'select current_database()' < /dev/null) || { echo "Refusing restore: cannot connect to RESTORE_DATABASE_URL." >&2; exit 2; }
[[ "$connected_database" == "$RESTORE_DATABASE_NAME" ]] || { echo "Refusing restore: connected database does not match RESTORE_DATABASE_NAME." >&2; exit 2; }

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
archive="$temp_dir/$BACKUP_ARCHIVE"
remote="${BACKUP_REMOTE%/}/$BACKUP_ARCHIVE"
rclone copyto "$remote" "$archive"
rclone copyto "$remote.sha256" "$archive.sha256"
(cd "$temp_dir" && sha256sum --check "$BACKUP_ARCHIVE.sha256")

age --decrypt --identity "$BACKUP_AGE_IDENTITY_FILE" "$archive" \
  | "${compose[@]}" exec -T db pg_restore --exit-on-error --clean --if-exists --no-owner --no-privileges --dbname "$RESTORE_DATABASE_URL"
printf 'Restore completed in isolated database %s. Run application-level integrity checks before considering recovery complete.\n' "$RESTORE_DATABASE_NAME"
