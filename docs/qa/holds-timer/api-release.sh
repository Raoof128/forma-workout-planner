#!/usr/bin/env bash
# API release for one environment. Run as root: bash -s <env> <tag> <archive> <sha256>
set -euo pipefail
ENV="$1"; TAG="$2"; ARCHIVE="$3"; SHA="$4"
case "$ENV" in
  staging) HOSTFILE=compose.small-host.yaml ;;
  production) HOSTFILE=compose.production-host.yaml ;;
  *) echo "unknown env $ENV" >&2; exit 2 ;;
esac
D=/opt/forma-$ENV
R=$D/releases/$TAG
mkdir -p "$R"
cd "$D/ops"
C=(docker compose -p "forma-$ENV" --env-file ../.env -f compose.yaml -f "$HOSTFILE")
DB=forma-$ENV-db-1
API=forma-$ENV-api-1
COUNTS_SQL=/opt/forma-production/releases/workout-coach-20261019/counts.sql
counts() { docker exec -i "$DB" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA' < "$COUNTS_SQL"; }
others() { docker ps --format '{{.Names}} {{.Image}} {{.Status}}' | grep -v "^forma-$ENV-" | sed -E 's/ Up .*/ Up/' | sort; }

# 1. Verify and load the image.
[ -f "$R/$(basename "$ARCHIVE")" ] || cp "$ARCHIVE" "$R/"
cd "$R"
echo "$SHA  $(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256"
sha256sum -c "$(basename "$ARCHIVE").sha256"
docker image inspect "forma-api:$TAG" >/dev/null 2>&1 || gunzip -c "$(basename "$ARCHIVE")" | docker load > image-load.log
docker image inspect "forma-api:$TAG" --format '{{.Id}} {{.Architecture}} {{.Config.User}}' | tee image-config-id.txt
cd "$D/ops"

# 2. Before: counts, unrelated containers, encrypted backup.
counts > "$R/counts.before.json"
others > "$R/other-containers.before"
(cd "$D" && python3 operations/account-operations.py operations/config.json backup < /dev/null) > "$R/pre-backup.log" 2>&1
tail -1 "$R/pre-backup.log"

# 3. Migrations (expected no-op: no new migration files) with the new image.
IMAGE_TAG="$TAG" "${C[@]}" --profile migrate run --rm migrate < /dev/null > "$R/migration.log" 2>&1
tail -2 "$R/migration.log"

# 4. Switch the API image.
cp ../.env "$R/env.previous"
PREV=$(grep -E '^IMAGE_TAG=' ../.env | cut -d= -f2)
sed -i -E "s/^IMAGE_TAG=.*/IMAGE_TAG=$TAG/" ../.env
"${C[@]}" up -d --no-deps api < /dev/null > "$R/startup.log" 2>&1
healthy=""
for _ in $(seq 1 60); do
  s=$(docker inspect "$API" --format '{{.State.Health.Status}}' 2>/dev/null || true)
  [ "$s" = healthy ] && { healthy=1; break; }
  sleep 3
done
if [ -z "$healthy" ]; then
  echo "API not healthy; rolling back to $PREV" >&2
  cp "$R/env.previous" ../.env
  "${C[@]}" up -d --no-deps api < /dev/null >> "$R/startup.log" 2>&1
  exit 1
fi
docker logs --since 2m "$API" 2>&1 | grep -iE '"level":(50|60)|error' | head -5 > "$R/api-errors.log" || true

# 5. After: backup, counts, unrelated containers.
(cd "$D" && python3 operations/account-operations.py operations/config.json backup < /dev/null) > "$R/post-backup.log" 2>&1
tail -1 "$R/post-backup.log"
counts > "$R/counts.after.json"
others > "$R/other-containers.after"
echo "previous=$PREV now=$(docker inspect "$API" --format '{{.Config.Image}}') health=$(docker inspect "$API" --format '{{.State.Health.Status}}')"
cmp -s "$R/counts.before.json" "$R/counts.after.json" && echo "counts unchanged" || { echo "counts changed:"; cat "$R/counts.before.json" "$R/counts.after.json"; }
cmp -s "$R/other-containers.before" "$R/other-containers.after" && echo "other containers unchanged" || echo "other containers differ"
echo "api error lines: $(wc -l < "$R/api-errors.log")"
