# LibreNMS OLT Monitoring - Shell Aliases Guide

Dokumen ini menjelaskan semua shell aliases yang tersedia setelah menjalankan `scripts/setup.sh`.

## Setup

Untuk menginstall aliases:

```bash
bash scripts/setup.sh
```

Kemudian reload shell configuration:

```bash
# Untuk Bash
source ~/.bashrc

# Untuk Zsh
source ~/.zshrc

# Untuk Fish
source ~/.config/fish/config.fish

# Atau restart terminal
```

## Resource Monitoring Aliases

### `librenms-stats`

Menampilkan snapshot resource usage dari semua containers.

**Usage:**
```bash
librenms-stats
```

**Output Example:**
```
NAME                  CPU %     MEM USAGE / LIMIT    MEM %
librenms              0.02%     44.46MiB / 1.25GiB   3.47%
librenms_dispatcher   0.07%     27.84MiB / 128MiB    21.75%
librenms_redis        0.34%     15.11MiB / 128MiB    11.80%
librenms_db           0.04%     186.6MiB / 512MiB    36.44%
```

**Use Case:**
- Quick check resource usage
- Verify containers within limits
- Troubleshooting performance issues

---

### `librenms-stats-live`

Menampilkan live updating resource usage (refresh setiap detik).

**Usage:**
```bash
librenms-stats-live
```

**Output:** Same format as `librenms-stats` but updates continuously.

**Use Case:**
- Monitor resource usage during operations
- Watch memory/CPU trends in real-time
- Identify resource spikes

**Note:** Press `Ctrl+C` to exit.

---

### `librenms-resources`

Menampilkan detailed resource usage dengan total memory calculation.

**Usage:**
```bash
librenms-resources
```

**Output Example:**
```
NAME                  CPU %     MEM USAGE / LIMIT    MEM %
librenms              0.02%     44.46MiB / 1.25GiB   3.47%
librenms_dispatcher   0.07%     27.84MiB / 128MiB    21.75%
librenms_redis        0.34%     15.11MiB / 128MiB    11.80%
librenms_db           0.04%     186.6MiB / 512MiB    36.44%

Total Memory:
274 MiB / 2048 MiB
```

**Use Case:**
- Comprehensive resource overview
- Verify total memory usage against 2GB limit
- System health check

---

## Container Management Aliases

### `librenms-up`

Start semua containers dalam detached mode.

**Usage:**
```bash
librenms-up
```

**Equivalent Command:**
```bash
cd /path/to/project && sudo docker compose up -d
```

**Use Case:**
- Start sistem setelah reboot
- Start containers setelah maintenance
- Initial deployment

---

### `librenms-down`

Stop dan remove semua containers (data tetap tersimpan di volumes).

**Usage:**
```bash
librenms-down
```

**Equivalent Command:**
```bash
cd /path/to/project && sudo docker compose down
```

**Use Case:**
- Shutdown sistem untuk maintenance
- Free up resources
- Before system reboot

**Warning:** Containers akan dihapus, tapi data di volumes tetap aman.

---

### `librenms-restart`

Restart semua containers tanpa rebuild.

**Usage:**
```bash
librenms-restart
```

**Equivalent Command:**
```bash
cd /path/to/project && sudo docker compose restart
```

**Use Case:**
- Apply configuration changes
- Recover from errors
- Clear memory leaks

---

### `librenms-logs`

View live logs dari semua containers.

**Usage:**
```bash
librenms-logs
```

**Equivalent Command:**
```bash
cd /path/to/project && sudo docker compose logs -f
```

**Output:** Streaming logs dari semua containers dengan color coding.

**Use Case:**
- Troubleshooting errors
- Monitor system activity
- Debug issues

**Note:** Press `Ctrl+C` to exit.

---

### `librenms-ps`

Show status semua containers.

**Usage:**
```bash
librenms-ps
```

**Output Example:**
```
NAME                  IMAGE                      STATUS
librenms              librenms/librenms:latest   Up 2 hours
librenms_dispatcher   librenms/librenms:latest   Up 2 hours
librenms_db           mariadb:10.11              Up 2 hours
librenms_redis        redis:7-alpine             Up 2 hours
```

**Use Case:**
- Quick status check
- Verify all containers running
- Check uptime

---

## Backup & Restore Aliases

### `librenms-backup`

Create full backup (database, RRD files, configuration).

**Usage:**
```bash
librenms-backup
```

**Equivalent Command:**
```bash
cd /path/to/project && sudo bash scripts/backup.sh
```

**Output:**
- Backup file: `./backups/librenms_backup_YYYYMMDD_HHMMSS.tar.gz`
- Includes: database dump, RRD files, config, logs, plugins

**Use Case:**
- Before major changes
- Regular scheduled backups
- Before system updates

---

### `librenms-restore`

Restore dari backup archive.

**Usage:**
```bash
librenms-restore ./backups/librenms_backup_20260216_223715.tar.gz
```

**Equivalent Command:**
```bash
cd /path/to/project && sudo bash scripts/restore.sh <backup-file>
```

**Process:**
1. Extract backup
2. Drop and recreate database
3. Restore database
4. Restore RRD files
5. Restore configuration
6. Validate data
7. Restart services

**Use Case:**
- Disaster recovery
- Migrate to new server
- Rollback after failed changes

**Warning:** Will overwrite existing data!

---

### `librenms-backups`

List all available backup files.

**Usage:**
```bash
librenms-backups
```

**Output Example:**
```
-rw-r--r-- 1 root root 28K Feb 16 22:37 librenms_backup_20260216_223715.tar.gz
-rw-r--r-- 1 root root 32K Feb 15 02:00 librenms_backup_20260215_020000.tar.gz
-rw-r--r-- 1 root root 29K Feb 14 02:00 librenms_backup_20260214_020000.tar.gz
```

**Use Case:**
- Find backup files for restore
- Check backup sizes
- Verify backup schedule working

---

## Quick Access Aliases

### `librenms-cd`

Navigate to project directory dari mana saja.

**Usage:**
```bash
librenms-cd
```

**Equivalent Command:**
```bash
cd /path/to/project
```

**Use Case:**
- Quick navigation to project
- Before running manual commands
- Access project files

---

### `librenms-help`

Display README documentation dalam less viewer.

**Usage:**
```bash
librenms-help
```

**Equivalent Command:**
```bash
cat /path/to/project/README.md | less
```

**Use Case:**
- Quick reference documentation
- Review setup instructions
- Check troubleshooting guide

**Navigation:**
- `Space` - Next page
- `b` - Previous page
- `/` - Search
- `q` - Quit

---

## Common Workflows

### Daily Health Check

```bash
# Check container status
librenms-ps

# Check resource usage
librenms-resources

# View recent logs
librenms-logs
```

### Before Maintenance

```bash
# Create backup
librenms-backup

# Stop containers
librenms-down

# ... perform maintenance ...

# Start containers
librenms-up

# Verify status
librenms-ps
librenms-resources
```

### Troubleshooting

```bash
# Check container status
librenms-ps

# Check resource usage
librenms-stats

# View logs for errors
librenms-logs

# Restart if needed
librenms-restart
```

### Disaster Recovery

```bash
# List available backups
librenms-backups

# Restore from backup
librenms-restore ./backups/librenms_backup_YYYYMMDD_HHMMSS.tar.gz

# Verify restoration
librenms-ps
librenms-resources
```

---

## Uninstalling Aliases

Jika ingin menghapus aliases:

### Bash/Zsh

```bash
# Edit shell config
nano ~/.bashrc  # atau ~/.zshrc

# Hapus section:
# # LibreNMS OLT Monitoring Aliases
# ...
# # End LibreNMS Aliases

# Reload shell
source ~/.bashrc  # atau ~/.zshrc
```

### Fish

```bash
# Edit fish config
nano ~/.config/fish/config.fish

# Hapus section LibreNMS aliases

# Reload shell
source ~/.config/fish/config.fish
```

---

## Supported Shells

- **Bash** - Tested on Bash 4.0+
- **Zsh** - Tested on Zsh 5.0+
- **Fish** - Tested on Fish 3.0+

Other shells may work but are not officially supported.

---

## Troubleshooting

### Aliases not working

```bash
# Verify aliases loaded
alias | grep librenms

# Reload shell config
source ~/.bashrc  # atau ~/.zshrc

# Or restart terminal
```

### Permission denied errors

Aliases menggunakan `sudo` untuk Docker commands. Pastikan user memiliki sudo access:

```bash
# Add user to docker group (alternative to sudo)
sudo usermod -aG docker $USER

# Logout and login again
```

### Command not found

```bash
# Verify setup script ran successfully
bash scripts/setup.sh

# Check shell config file
cat ~/.bashrc | grep librenms  # atau ~/.zshrc
```

---

## Tips & Best Practices

1. **Use `librenms-resources` regularly** untuk monitor resource usage
2. **Setup cron job** untuk `librenms-backup` (daily recommended)
3. **Use `librenms-logs`** saat troubleshooting issues
4. **Always backup** sebelum major changes dengan `librenms-backup`
5. **Check `librenms-ps`** setelah restart untuk verify all containers up

---

## Support

Untuk issues atau questions:
- Check README.md: `librenms-help`
- View logs: `librenms-logs`
- Check status: `librenms-ps`
- Monitor resources: `librenms-resources`
