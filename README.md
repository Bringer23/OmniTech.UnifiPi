# Introduction
This is a guide for running docker compose to create the foundryvtt instance for the game screen.

# Raspberry Pi
__Documentation:__ https://www.raspberrypi.com/software/

Flash Raspberry Pi OS to your SD card using the Raspberry Pi Imager. Enable SSH during imaging (set hostname, username, password).

# Automated Setup

Once the Pi is booted and reachable via SSH, run from this repo:

```bash
./scripts/setup-pi.sh <PI_IP> <PI_USER> <SECRETS_FILE>
```

**Example:**
```bash
./scripts/setup-pi.sh 192.168.1.50 gm ./containers/secrets.json
```

The script will:
1. Auto-detect environment secrets (e.g. `secrets.production.json`) in the same folder — no need to pass them explicitly
2. Install `unclutter` and Docker on the Pi (skips Docker if already installed)
3. Create `/docker/compose`, `/docker/data`, `/docker/scripts`
4. Copy `containers/docker-compose.yml` and secrets to `/docker/compose/`
5. Copy `containers/rc.local` to `/etc/rc.local` (runs Docker on boot)
6. Prompt whether to reboot the Pi

# Secrets

- `containers/secrets.json` — empty template (committed to repo)
- `containers/secrets.production.json` — real credentials (gitignored, never committed)

The script automatically detects any `secrets.<environment>.json` file in `containers/` and uses it as the source, copying it to the Pi as `secrets.json`. If multiple environment files exist, the first alphabetically wins.

Copy the template and fill in your FoundryVTT credentials:
```bash
cp containers/secrets.json containers/secrets.production.json
nano containers/secrets.production.json
```

# Repo Structure

| File | Purpose |
|------|---------|
| `containers/docker-compose.yml` | Docker Compose config for FoundryVTT |
| `containers/secrets.json` | Empty secrets template |
| `containers/rc.local` | Boot script — starts Docker on Pi startup |
| `scripts/setup-pi.sh` | Automated Pi provisioning script |

# First Run

After the Pi reboots, SSH in and start FoundryVTT for the first time to trigger the download:

```bash
ssh <PI_USER>@<PI_IP>
cd /docker/compose
sudo docker compose up
```

Stop (Ctrl+C) after FoundryVTT finishes downloading. Subsequent boots will start it automatically via `rc.local`.

# Verify

SSH into the Pi after reboot and check containers are running:

```bash
ssh <PI_USER>@<PI_IP>
sudo docker ps
```
