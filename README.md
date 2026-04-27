# Introduction
This is a guide for running docker compose to create the Unifi Network Application instance on a Raspberry Pi.

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
./scripts/setup-pi.sh 192.168.1.50 gm ./containers/secrets.env
```

The script will:
1. Auto-detect environment secrets (e.g. `secrets.production.json`) in the same folder — no need to pass them explicitly
2. Install `unclutter` and Docker on the Pi (skips Docker if already installed)
3. Create `/docker/compose`, `/docker/data`, `/docker/scripts`
4. Copy `containers/docker-compose.yml` and secrets to `/docker/compose/`
5. Copy `containers/rc.local` to `/etc/rc.local` (runs Docker on boot)
6. Prompt whether to reboot the Pi

# Secrets

- `containers/secrets.env` — empty template (committed to repo)
- `containers/secrets.production.env` — real credentials (gitignored, never committed)

The script automatically detects any `secrets.<environment>.env` file in `containers/` and uses it as the source, copying it to the Pi as `secrets.env`. If multiple environment files exist, the first alphabetically wins.

Copy the template and fill in your Unifi credentials:
```bash
cp containers/secrets.env containers/secrets.production.env
nano containers/secrets.production.env
```

The env file contains:
```env
MONGO_USER=unifi
MONGO_PASS=
MONGO_INITDB_ROOT_USERNAME=root
MONGO_INITDB_ROOT_PASSWORD=
```

# Repo Structure

| File | Purpose |
|------|---------|
| `containers/docker-compose.yml` | Docker Compose config for Unifi + MongoDB |
| `containers/secrets.env` | Empty secrets template |
| `containers/mongo-init.sh` | MongoDB init script — creates Unifi user on first run |
| `containers/rc.local` | Boot script — starts Docker on Pi startup |
| `scripts/setup-pi.sh` | Automated Pi provisioning script |
| `scripts/reset-docker.sh` | Stops all containers and wipes `/docker/data` on the Pi |

# First Run

After the Pi reboots, SSH in and start the containers for the first time:

```bash
ssh <PI_USER>@<PI_IP>
cd /docker/compose
sudo docker compose up
```

Stop (Ctrl+C) once containers are running. Subsequent boots will start them automatically via `rc.local`.

# Verify

SSH into the Pi after reboot and check containers are running:

```bash
ssh <PI_USER>@<PI_IP>
sudo docker ps
```

# Troubleshooting

## Force Adoption of Older Access Points

Older APs may not auto-discover the controller. To manually adopt:

1. SSH into the AP:
   ```bash
   ssh ubnt@<AP_IP>
   ```
   Default credentials: `ubnt` / `ubnt`

2. In the Unifi UI, start the adoption process for the device (it will show as "Pending Adoption" or you can click Adopt).

3. In the SSH session, run:
   ```bash
   set-inform http://X.X.X.X:8080/inform
   ```
   Replace `X.X.X.X` with your Pi's IP address.

4. The AP will connect to the controller and complete adoption. You may need to run `set-inform` twice if the first attempt is rejected.
