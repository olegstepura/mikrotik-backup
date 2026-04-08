# MikroTik Backup Bot (Docker)

A lightweight, high-security "Pull" backup system for MikroTik devices. Seamlessly supports both RouterOS v6 and v7.

## 💡 The Concept
* **Pull-based**: The server initiates the connection, keeping the routers secure from pushing malicious payloads.
* **Modern Key-Based Auth**: Uses Ed25519 SSH keys with strict Trust-On-First-Use (TOFU) host verification.
* **Double Secure**: Binary `.backup` files are secured natively on the router with a temporary, random password before download.
* **Encrypted at Rest**: Both the `.backup` and plaintext `.rsc` config are combined into an AES-256 encrypted 7-Zip archive.

## 🚀 Setup Instructions

### 1. Initialization
Create a `.env` file in the same directory as your `docker-compose.yml` and define your variables:

```env
BACKUP_USER=backup
BACKUP_PASSWORD=YourSuperSecureGlobal7zPassword
MIKROTIK_IPS=192.168.88.1 10.0.0.5 172.16.0.1
```

Then run:

`docker-compose up`

**Check the logs:** The container will generate a new SSH key and print a pre-formatted MikroTik command to your terminal. **(Note: Host keys are automatically trusted and pinned on the first successful connection).**

### 2. MikroTik Configuration (Line-by-Line)
Copy the commands from the terminal logs and paste them into your MikroTik Terminal **line by line**. 

When you run the second command, the router will securely prompt you to create a password for the new backup user.

```routeros
/user group add name=backup-group policy=ssh,read,write,ftp,sensitive,test,password,policy;
/user add name=backup group=backup-group comment="Backup Bot";
/user ssh-keys add user=backup key="ssh-ed25519 AAAA...";
```

**No files to upload, no dragging and dropping.** The key is injected directly into the router's configuration.

### 3. Verification
Run the container again to perform the first backup:

```bash
docker-compose up
```

Check the `./archives` folder for your encrypted `.7z` files.

## 📦 Extracting Archives
Use a temporary Docker container to easily unpack your archives without needing to install `7zip` on your host machine. 

Run this command from the directory containing your `.env` file, replacing the path at the very end with your actual archive name (running without backup name will list all backups):

```bash
docker-compose run --rm mikrotik-backup /app/extract.sh 192.168.88.1/bkp_2026-01-01_00-00-59.7z
```

This creates a neatly organized folder right next to your archive containing:
1. Your `.rsc` plaintext config.
2. Your `.backup` binary file.
3. A `_router_pass.txt` file containing the temporary password required to restore the `.backup` file to the router.

## ♻️ Rotation & Retention
The script manages disk space using a GFS (Grandfather-Father-Son) policy per IP folder:
* **KEEP_LAST_N**: Keeps the last **7** backups (default).
* **KEEP_MONTHS**: Keeps **1** backup per month for **6** months (default).
* Older files are automatically purged during every run.

## ⏰ Automation (Built-in Scheduling)

You do not need host-level crontabs! The container has a built-in lightweight scheduler (Supercronic). 

To run the container continuously in the background and trigger backups automatically, simply add the `CRON_SCHEDULE` environment variable to your `.env` file (e.g., run every night at 3:00 AM):

```env
CRON_SCHEDULE=0 3 * * *
```

Then, ensure your `docker-compose.yml` has `restart: unless-stopped` and bring it up in detached mode:

```bash
docker-compose up -d
```

*(If `CRON_SCHEDULE` is omitted, the container will run exactly once and exit, allowing you to manually trigger it or use external orchestration).*

### ⚡ Immediate Run / Testing
If you are running the container as a daemon with a cron schedule, you can force it to run immediately upon startup before the cron scheduler takes over. Add this to your `.env` file:

```env
RUN_ON_STARTUP=true
```

Alternatively, you can trigger a backup on-demand inside an already running background container at any time:

```bash
docker exec -it mt-backup-runner /app/backup.sh
```

### 🚨 Error Monitoring with Sentry
If you are running the container in daemon mode (using `CRON_SCHEDULE`), you can automatically report backup script failures directly to Sentry. 

Simply add your DSN to your `.env` file or `docker-compose.yml`:

```env
SENTRY_DSN=[https://yourPublicKey@o0.ingest.sentry.io/0](https://yourPublicKey@o0.ingest.sentry.io/0)
```

*(Optional: You can also define `SENTRY_ENVIRONMENT` and `SENTRY_RELEASE` for deeper context).*


## 🔒 Security Summary
* **SSH Keys & TOFU**: No login passwords stored or sent over the network. Strict Host Key Checking (`accept-new`) prevents Man-in-the-Middle (MitM) attacks.
* **Restricted User**: The `backup` user belongs to a custom group tailored for backup operations.
* **On-Disk Router Security**: Binary backups are never left unencrypted on the router's flash storage.
* **7z Encryption**: All backups are locked in AES-256 archives with hidden filenames (`-mhe=on`).
* **Secrets Management**: Configuration is loaded securely via a `.env` file, keeping plaintext passwords out of version control and process lists.
