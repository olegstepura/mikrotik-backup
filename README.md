# MikroTik Backup Bot (Docker)

A lightweight, high-security "Pull" backup system for MikroTik devices.

## 💡 The Concept
* **Pull-based**: The server initiates the connection, keeping the routers secure.
* **Single Key**: One global SSH key for all your routers (Key-based auth).
* **Double Secure**: Binary `.backup` and plaintext `.rsc` config are combined into an encrypted 7-Zip archive.

## 🚀 Setup Instructions

### 1. Initialization
Create a `.env` file in the same directory as your `docker-compose.yml` and define your variables:

```
BACKUP_PASSWORD=YourSecurePassword
MIKROTIK_IPS=192.168.88.1 10.0.0.5
```

Then run:

`docker-compose up`

**Check the logs:** The container will generate a new SSH key, scan the host keys to establish a trust baseline, and **print a pre-formatted MikroTik command** to your terminal.

### 2. MikroTik Configuration (100% Copy-Paste)
Copy the command block from the terminal logs and paste it into your MikroTik Terminal. It looks like this:

```routeros
/user group add name=backup-group policy=ssh,read,test,sensitive;
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

## ♻️ Rotation & Retention
The script manages disk space using a GFS (Grandfather-Father-Son) policy per IP folder:
* **KEEP_LAST_N**: Keeps the last **7** backups (default).
* **KEEP_MONTHS**: Keeps **1** backup per month for **6** months (default).
* Older files are automatically purged during every run.

## ⏰ Automation
Add this to your host's crontab to run every night at 3:00 AM:

```cron
0 3 * * * docker start -a mt-backup-runner >> /var/log/mikrotik-backup.log 2>&1
```

## 🔒 Security Summary
* **SSH Keys**: No login passwords stored or sent over the network.
* **Restricted User**: The `backup` user has no permission to change settings or reboot.
* **7z Encryption**: All backups are locked in AES-256 archives with hidden filenames.
