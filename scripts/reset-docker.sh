#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[reset-docker]${NC} $*"; }
warn() { echo -e "${YELLOW}[reset-docker]${NC} $*"; }
err()  { echo -e "${RED}[reset-docker] ERROR:${NC} $*" >&2; }

COMPOSE_DIR="/docker/compose"
DATA_DIR="/docker/data"

# ─── Confirm ─────────────────────────────────────────────────────────────────
warn "This will stop and remove all containers and DELETE all data in ${DATA_DIR}."
read -r -p "Are you sure? [y/N] " CONFIRM
if [[ "${CONFIRM,,}" != "y" ]]; then
  log "Aborted."
  exit 0
fi

# ─── Stop and remove containers ──────────────────────────────────────────────
log "Stopping and removing containers..."
if [[ -f "${COMPOSE_DIR}/docker-compose.yml" ]]; then
  docker compose -f "${COMPOSE_DIR}/docker-compose.yml" down --remove-orphans || true
else
  warn "No docker-compose.yml found at ${COMPOSE_DIR} — skipping compose down."
fi

# Kill any remaining running containers just in case
RUNNING=$(docker ps -q)
if [[ -n "$RUNNING" ]]; then
  log "Killing remaining running containers..."
  docker kill $RUNNING || true
fi

# Remove all stopped containers
STOPPED=$(docker ps -aq)
if [[ -n "$STOPPED" ]]; then
  log "Removing all stopped containers..."
  docker rm -f $STOPPED || true
fi

log "All containers stopped and removed."

# ─── Delete data directories ─────────────────────────────────────────────────
log "Deleting ${DATA_DIR}..."
sudo rm -rf "${DATA_DIR}"
sudo mkdir -p "${DATA_DIR}"
log "${DATA_DIR} cleared."

log "Done. Run 'docker compose -f ${COMPOSE_DIR}/docker-compose.yml up -d' to start fresh."
