#!/usr/bin/env bash
set -euo pipefail
cd /opt/greater-change-foundation
exec 9>/var/lock/gcf-deploy.lock
flock -n 9 || { echo "Another GCF deployment is running" >&2; exit 1; }
: "${1:?Provide the immutable app image}"
: "${2:?Provide the immutable migration image}"
mountpoint -q /mnt/HC_Volume_106964646 || { echo "GCF data volume is not mounted" >&2; exit 1; }
[ "$(readlink -f /var/lib/gcf)" = /mnt/HC_Volume_106964646/gcf ] || { echo "Unexpected GCF data location" >&2; exit 1; }
install -d -m 700 /var/lib/gcf/database /var/lib/gcf/sqitch /var/lib/gcf/caddy/data /var/lib/gcf/caddy/config
export GCF_IMAGE="$1" GCF_MIGRATION_IMAGE="$2"
if [ -f .env ]; then cp .env .env.previous; fi
docker compose --env-file /dev/null -f deploy/compose.yaml pull
# Save both the local Sqitch registry and Turso files together before migrations.
if [ -n "$(find /var/lib/gcf/database -mindepth 1 -print -quit)" ]; then
  install -d -m 700 /var/backups/gcf
  docker compose --env-file /dev/null -f deploy/compose.yaml stop app database
  tar -czf "/var/backups/gcf/pre-deploy-$(date -u +%Y%m%dT%H%M%SZ).tar.gz" -C /var/lib/gcf database sqitch
fi
printf 'GCF_IMAGE=%s\nGCF_MIGRATION_IMAGE=%s\nGCF_DOMAIN=gcf.5-161-104-141.sslip.io\n' "$GCF_IMAGE" "$GCF_MIGRATION_IMAGE" > .env
chmod 600 .env
docker compose -f deploy/compose.yaml up -d --wait database
docker compose -f deploy/compose.yaml run --rm migrate deploy --verify
docker compose -f deploy/compose.yaml up -d --wait app proxy
curl --fail --retry 12 --retry-delay 2 --retry-connrefused http://127.0.0.1:4000/readyz
