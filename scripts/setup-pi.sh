#!/bin/bash
set -euo pipefail

# ─── Colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

log()  { echo -e "${GREEN}[setup-pi]${NC} $*"; }
warn() { echo -e "${YELLOW}[setup-pi]${NC} $*"; }
err()  { echo -e "${RED}[setup-pi] ERROR:${NC} $*" >&2; }

# ─── Usage ──────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: $0 <PI_IP> <PI_USER> <SECRETS_FILE>"
  echo ""
  echo "  PI_IP         IP address of the Raspberry Pi"
  echo "  PI_USER       SSH username (e.g. gm)"
  echo "  SECRETS_FILE  Path to secrets file (e.g. ./containers/secrets.production.json)"
  echo ""
  echo "Secret file naming convention:"
  echo "  <name>.<environment>.json  — environment detected, copied to Pi as <name>.json"
  echo "  <name>.json                — no environment, copied to Pi as-is"
  exit 1
}

# ─── Config ──────────────────────────────────────────────────────────────────
# Paths relative to repo root — edit here if files move
COMPOSE_RELATIVE="containers/docker-compose.yml"
RC_LOCAL_RELATIVE="containers/rc.local"

# ─── Args ───────────────────────────────────────────────────────────────────
[[ $# -lt 3 ]] && { usage; }

PI_IP="$1"
PI_USER="$2"
SECRETS_FILE="$3"

# ─── SSH options ─────────────────────────────────────────────────────────────
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"

# ─── Check sshpass ───────────────────────────────────────────────────────────
if ! command -v sshpass &>/dev/null; then
  err "sshpass not found. Install with:"
  err "  Linux: sudo apt install sshpass"
  err "  Mac:   brew install sshpass"
  exit 1
fi

# ─── Password prompt ─────────────────────────────────────────────────────────
read -s -p "Password for ${PI_USER}@${PI_IP}: " PI_PASS
echo ""

# Helper: run a remote command prefixed with sudo -S, password piped via stdin
# Usage: ssh_sudo "command && another command"
ssh_sudo() {
  echo "$PI_PASS" | sshpass -p "$PI_PASS" ssh $SSH_OPTS "${PI_USER}@${PI_IP}" "sudo -S bash -c '$1'"
}

# Helper: run remote command without sudo
ssh_run() {
  sshpass -p "$PI_PASS" ssh $SSH_OPTS "${PI_USER}@${PI_IP}" "$1"
}

# ─── Resolve secrets ─────────────────────────────────────────────────────────
SECRETS_DIR="$(dirname "$SECRETS_FILE")"
SECRETS_BASENAME="$(basename "$SECRETS_FILE")"
SECRETS_STEM="${SECRETS_BASENAME%.json}"

# Destination filename on Pi always matches CLI arg
BASE_NAME="${SECRETS_BASENAME}"

# Scan for environment-specific variants: <stem>.<env>.json, pick first alphabetically
SECRETS_SOURCE="$SECRETS_FILE"
ENV_FILE="$(ls "${SECRETS_DIR}/${SECRETS_STEM}".*.json 2>/dev/null | sort | head -n1 || true)"

if [[ -n "$ENV_FILE" ]]; then
  ENV_BASENAME="$(basename "$ENV_FILE")"
  ENVIRONMENT="${ENV_BASENAME#"${SECRETS_STEM}."}"
  ENVIRONMENT="${ENVIRONMENT%.json}"
  SECRETS_SOURCE="$ENV_FILE"
  log "Detected environment file: ${ENV_BASENAME} (environment: ${ENVIRONMENT}) — will copy to Pi as ${BASE_NAME}"
else
  warn "No environment file found — using ${SECRETS_BASENAME} directly"
fi

# Verify source file exists
if [[ ! -f "$SECRETS_SOURCE" ]]; then
  err "Secrets file not found: $SECRETS_SOURCE"
  exit 1
fi

log "Source secrets : $SECRETS_SOURCE"
log "Destination    : /docker/compose/${BASE_NAME}"

# ─── Locate repo files ───────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/$COMPOSE_RELATIVE"
RC_LOCAL_FILE="$REPO_ROOT/$RC_LOCAL_RELATIVE"

for f in "$COMPOSE_FILE" "$RC_LOCAL_FILE"; do
  if [[ ! -f "$f" ]]; then
    err "Required file not found: $f"
    exit 1
  fi
done

# ─── Test SSH connectivity ───────────────────────────────────────────────────
log "Testing SSH connectivity to ${PI_USER}@${PI_IP}..."
if ! sshpass -p "$PI_PASS" ssh $SSH_OPTS "${PI_USER}@${PI_IP}" "echo ok" &>/dev/null; then
  err "Cannot connect to ${PI_USER}@${PI_IP}. Check IP, username, password, and SSH access."
  exit 1
fi
log "SSH connection successful."

# ─── Install unclutter ───────────────────────────────────────────────────────
log "Installing unclutter..."
ssh_sudo "DEBIAN_FRONTEND=noninteractive apt update && DEBIAN_FRONTEND=noninteractive apt install -y unclutter"
log "unclutter installed."

# ─── Install Docker ──────────────────────────────────────────────────────────
if ssh_run "command -v docker" &>/dev/null; then
  log "Docker already installed — skipping."
else
  log "Installing Docker..."
  ssh_run "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh"
  ssh_sudo "DEBIAN_FRONTEND=noninteractive sh /tmp/get-docker.sh && rm /tmp/get-docker.sh"
  log "Docker installed."
fi

# ─── Create directories ──────────────────────────────────────────────────────
log "Creating /docker directories..."
ssh_sudo "mkdir -p /docker/compose /docker/data /docker/scripts"
log "Directories created."

# ─── Copy docker-compose.yml ─────────────────────────────────────────────────
log "Copying docker-compose.yml..."
sshpass -p "$PI_PASS" scp $SSH_OPTS "$COMPOSE_FILE" "${PI_USER}@${PI_IP}:/tmp/docker-compose.yml"
ssh_sudo "mv /tmp/docker-compose.yml /docker/compose/docker-compose.yml"
log "docker-compose.yml copied."

# ─── Copy secrets ────────────────────────────────────────────────────────────
log "Copying secrets as ${BASE_NAME}..."
sshpass -p "$PI_PASS" scp $SSH_OPTS "$SECRETS_SOURCE" "${PI_USER}@${PI_IP}:/tmp/${BASE_NAME}"
ssh_sudo "mv /tmp/${BASE_NAME} /docker/compose/${BASE_NAME}"
log "Secrets copied."

# ─── Copy rc.local ───────────────────────────────────────────────────────────
log "Copying rc.local to /etc/rc.local..."
sshpass -p "$PI_PASS" scp $SSH_OPTS "$RC_LOCAL_FILE" "${PI_USER}@${PI_IP}:/tmp/rc.local"
ssh_sudo "mv /tmp/rc.local /etc/rc.local && chmod +x /etc/rc.local"
log "rc.local installed."

# ─── Reboot ──────────────────────────────────────────────────────────────────
echo ""
read -r -p "Reboot the Pi now? [y/N] " REBOOT_CONFIRM
if [[ "${REBOOT_CONFIRM,,}" == "y" ]]; then
  log "Rebooting Pi..."
  ssh_sudo "reboot" || true
  log "Done. Pi is rebooting. Wait ~30s then verify with: ssh ${PI_USER}@${PI_IP} 'sudo docker ps'"
else
  log "Skipping reboot. You can reboot manually with: ssh ${PI_USER}@${PI_IP} 'sudo reboot'"
fi
