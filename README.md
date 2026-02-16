# Sistem Monitoring Jaringan dengan LibreNMS

Sistem monitoring jaringan berbasis LibreNMS yang di-deploy menggunakan Docker. Sistem ini mendukung monitoring untuk **semua jenis perangkat jaringan yang support SNMP**, termasuk:

- **OLT** (ZTE C300, Huawei MA5680T, Fiberhome, dll)
- **Router & Switch** (Cisco, Mikrotik, Juniper, HP, Dell, Ubiquiti, dll)
- **Wireless** (UniFi, Mikrotik Wireless, Cambium, Ruckus, dll)
- **Server** (Linux, Windows, VMware ESXi, Proxmox, dll)
- **Perangkat lainnya** (UPS, PDU, IP Camera, Printer, dll)

LibreNMS akan otomatis mendeteksi jenis perangkat dan menerapkan polling module yang sesuai.

## Prerequisites

- Docker Engine 20.10 atau lebih baru
- Docker Compose V2
- Minimal 2GB RAM tersedia
- Minimal 10GB disk space
- Linux OS (tested on Ubuntu 20.04+)

## Arsitektur

Sistem ini terdiri dari 4 container Docker:

1. **LibreNMS** (1.28GB RAM, 1.25 CPU cores) - Aplikasi monitoring utama
2. **MariaDB** (512MB RAM, 0.5 CPU cores) - Database untuk menyimpan konfigurasi dan metrics
3. **Redis** (128MB RAM, 0.125 CPU cores) - Cache dan session storage
4. **Dispatcher** (128MB RAM, 0.125 CPU cores) - Background job processing untuk alerts dan discovery

**Total Resource Usage:**
- Memory: 2GB (2048MB - exactly at limit)
- CPU: 2.0 cores (exactly at limit)
- Disk: ~10GB untuk data 30 hari

## Quick Start

### 1. Clone atau Download Repository

```bash
git clone <repository-url>
cd olt-monitoring-system
```

### 2. Setup Shell Aliases (Recommended)

Jalankan setup script untuk menambahkan helpful aliases ke shell configuration:

```bash
bash scripts/setup.sh
```

Script ini akan:
- Mendeteksi shell yang digunakan (bash, zsh, fish)
- Menambahkan aliases untuk resource monitoring dan management
- Menyediakan shortcut commands untuk operasi sehari-hari

Setelah setup, reload shell configuration:
```bash
source ~/.bashrc  # untuk bash
source ~/.zshrc   # untuk zsh
```

### 3. Konfigurasi Environment Variables

```bash
cp .env.example .env
# Edit .env file sesuai kebutuhan (opsional untuk quick start)
```

### 4. Deploy Sistem

```bash
# Pull images dan start containers
docker compose up -d
# atau gunakan alias: librenms-up

# Verify semua containers running
docker compose ps
# atau gunakan alias: librenms-ps
```

### 5. Akses Dashboard

Buka browser dan akses: `http://localhost:80`

Default credentials akan dibuat saat first-time setup.

## Docker Compose Configuration

### Services

#### LibreNMS Container
- **Image**: `librenms/librenms:latest`
- **Port**: 80:8000 (HTTP)
- **Volumes**: `./librenms:/data` (persistent storage)
- **Resource Limits**: 1280M RAM, 1.25 CPU cores
- **Environment Variables**:
  - `TZ`: Timezone (default: Asia/Jakarta)
  - `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`: Database connection
  - `REDIS_HOST`, `REDIS_PORT`: Redis connection

#### MariaDB Container
- **Image**: `mariadb:10.11`
- **Volumes**: `./db:/var/lib/mysql` (persistent storage)
- **Resource Limits**: 512M RAM, 0.5 CPU cores
- **Optimizations**:
  - InnoDB buffer pool: 256M
  - InnoDB log file: 64M
  - Character set: utf8mb4

#### Redis Container
- **Image**: `redis:7-alpine`
- **Resource Limits**: 128M RAM, 0.125 CPU cores
- **Purpose**: Caching dan session storage

#### Dispatcher Container
- **Image**: `librenms/librenms:latest`
- **Resource Limits**: 128M RAM, 0.125 CPU cores
- **Purpose**: Background job processing (alerts, discovery, polling)

### Networks

Semua containers terhubung melalui `librenms_network` (bridge network) untuk komunikasi internal.

### Volumes

Data persistence menggunakan bind mounts:
- `./librenms` - LibreNMS data (config, RRD files, logs)
- `./db` - MariaDB database files

## Management Commands

### Shell Aliases (Recommended)

Jika sudah menjalankan `scripts/setup.sh`, gunakan aliases berikut:

**Resource Monitoring:**
```bash
librenms-stats          # Show current resource usage (snapshot)
librenms-stats-live     # Show live resource usage (updating)
librenms-resources      # Show detailed resource usage with totals
```

**Container Management:**
```bash
librenms-up             # Start all containers
librenms-down           # Stop all containers
librenms-restart        # Restart all containers
librenms-logs           # View container logs (live)
librenms-ps             # Show container status
```

**Backup & Restore:**
```bash
librenms-backup         # Create backup
librenms-restore        # Restore from backup
librenms-backups        # List available backups
```

**Quick Access:**
```bash
librenms-cd             # Go to project directory
librenms-help           # Show README documentation
```

### Manual Commands

Jika tidak menggunakan aliases, gunakan docker compose commands:

#### Start/Stop Sistem

```bash
# Start semua containers
docker compose up -d

# Stop semua containers
docker compose down

# Restart semua containers
docker compose restart

# View logs
docker compose logs -f

# View logs untuk specific service
docker compose logs -f librenms
```

#### Resource Monitoring

```bash
# Check resource usage (snapshot)
docker stats --no-stream

# Check resource usage (live updating)
docker stats

# Check specific container
docker stats librenms

# Detailed resource usage with formatting
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

### Database Access

```bash
# Access MariaDB shell
docker compose exec db mysql -u librenms -p librenms
```

## Backup dan Restore

Sistem ini dilengkapi dengan automated backup dan restore scripts untuk memastikan data safety.

### Backup

Script backup akan membuat backup lengkap dari:
- MariaDB database (mysqldump)
- RRD files (time-series metrics)
- Configuration files
- Logs dan plugins

```bash
# Jalankan backup
sudo bash scripts/backup.sh
```

Backup akan disimpan di `./backups/` dengan format:
- Filename: `librenms_backup_YYYYMMDD_HHMMSS.tar.gz`
- Compressed dengan gzip
- Include metadata (timestamp, version, hostname)

**Output Example:**
```
[INFO] Starting backup process...
[INFO] ✓ Database backup completed (212K)
[INFO] ✓ RRD files backup completed (4.0K)
[INFO] ✓ Backup compressed successfully (28K)
[INFO] Backup file: ./backups/librenms_backup_20260216_223715.tar.gz
```

### Restore

Script restore akan mengembalikan data dari backup archive:

```bash
# List available backups
ls -lh ./backups/*.tar.gz

# Restore dari backup file
sudo bash scripts/restore.sh ./backups/librenms_backup_YYYYMMDD_HHMMSS.tar.gz
```

**Proses Restore:**
1. Extract backup archive
2. Drop dan recreate database
3. Restore database dari SQL dump
4. Restore RRD files dengan proper permissions
5. Restore configuration files
6. Validate restored data
7. Restart LibreNMS services

**Warning:** Restore akan overwrite semua data yang ada. Pastikan untuk backup data current sebelum restore.

### Backup Schedule (Recommended)

Untuk automated backups, tambahkan ke crontab:

```bash
# Edit crontab
crontab -e

# Backup setiap hari jam 2 pagi
0 2 * * * cd /path/to/olt-monitoring-system && sudo bash scripts/backup.sh

# Backup setiap 6 jam
0 */6 * * * cd /path/to/olt-monitoring-system && sudo bash scripts/backup.sh
```

### Backup Retention

Untuk menghapus backup lama dan menghemat disk space:

```bash
# Hapus backup lebih dari 7 hari
find ./backups -name "*.tar.gz" -mtime +7 -delete

# Hapus backup lebih dari 30 hari
find ./backups -name "*.tar.gz" -mtime +30 -delete
```

Atau tambahkan ke crontab untuk automatic cleanup:

```bash
# Cleanup backup lama setiap minggu
0 3 * * 0 find /path/to/olt-monitoring-system/backups -name "*.tar.gz" -mtime +30 -delete
```

## Data Persistence

Semua data disimpan dalam Docker volumes yang di-mount ke host filesystem:

- **Configuration**: `./librenms/config.php`
- **RRD Files**: `./librenms/rrd/` (time-series metrics)
- **Database**: `./db/` (MariaDB data files)
- **Logs**: `./librenms/logs/`

Data akan tetap ada setelah container restart atau system reboot.

## Troubleshooting

### Container tidak start

```bash
# Check logs
docker compose logs

# Check resource availability
free -h
docker system df
```

### Database connection error

```bash
# Verify database container running
docker compose ps db

# Check database logs
docker compose logs db

# Test database connection
docker compose exec db mysql -u librenms -p -e "SELECT 1"
```

### High memory usage

```bash
# Check memory usage per container
docker stats --no-stream

# Restart containers to free memory
docker compose restart
```

### Port 80 already in use

Edit `docker-compose.yml` dan ubah port mapping:
```yaml
ports:
  - "8080:8000"  # Gunakan port 8080 instead of 80
```

## Security Notes

1. **Change default passwords** di `.env` file sebelum production deployment
2. **Restrict network access** menggunakan firewall rules
3. **Enable HTTPS** untuk production (tambahkan nginx reverse proxy dengan SSL)
4. **Regular backups** untuk database dan RRD files
5. **Keep images updated** dengan `docker compose pull && docker compose up -d`

## Resource Constraints

Sistem ini dirancang untuk berjalan pada laptop dengan resource terbatas:

- **Maximum Memory**: 2GB total
- **Maximum CPU**: 2 cores
- **Maximum Disk**: 10GB untuk 30 hari data

Jika resource usage melebihi limit, pertimbangkan:
- Reduce polling frequency
- Reduce data retention period
- Disable unused modules

## Features Implemented

### ✅ Interface and Port Monitoring (Task 7)

Sistem sudah dikonfigurasi untuk monitoring interface dan port dengan fitur:

**Standard Interface Polling:**
- ✅ Polling interval 5 menit untuk semua interface
- ✅ Collect interface status (up/down) secara real-time
- ✅ Collect traffic statistics (bytes in/out, errors, discards)
- ✅ Support 64-bit counters untuk high-speed interfaces
- ✅ RRD data retention 30 hari dengan multiple resolutions

**Interface State Change Event Logging:**
- ✅ Automatic logging untuk interface up/down events
- ✅ Timestamp untuk setiap event
- ✅ Event log retention 30 hari
- ✅ State change detection dengan threshold untuk prevent flapping

**Configuration Files:**
- `librenms/config/interface-polling-config.php` - Interface polling configuration
- `librenms/config/interface-eventlog-config.php` - Event logging configuration

**Verification:**
```bash
# Verify interface polling configuration
./scripts/verify-interface-logging.sh

# Test graph generation
./scripts/test-graphs.sh
```

### ✅ Graph Error Fix

Sistem sudah diperbaiki dari error HTTP 500 pada graph generation:

**Problem Fixed:**
- ❌ Sebelumnya: Semua graph request menghasilkan HTTP 500 error
- ✅ Sekarang: Semua graph berfungsi normal (HTTP 200)

**Root Cause:**
- Incompatible array configurations di `interface-polling-config.php`
- TypeError pada RRD configuration

**Solution Applied:**
- Simplified configuration dengan hanya boolean dan scalar values
- Removed problematic array configurations
- System restart untuk load new configuration

**Documentation:**
- `docs/GRAPH_ERROR_FIX.md` - Detailed fix documentation

### 🔧 Custom Modules for ZTE C300 OLT

Sistem dilengkapi dengan 4 custom modules untuk monitoring ZTE C300 OLT:

1. **Optical Power Polling Module** - Monitor TX/RX optical power pada PON ports
2. **ONT Status Polling Module** - Track semua ONT (online/offline/dying-gasp)
3. **Optical Power Discovery Module** - Auto-discover optical power sensors
4. **ONT Discovery Module** - Auto-discover semua ONT yang terhubung

**Module Files:**
- `librenms/includes/polling/zte-optical-power.inc.php`
- `librenms/includes/polling/zte-ont-status.inc.php`
- `librenms/includes/discovery/sensors/optical-power/zte-c300.inc.php`
- `librenms/includes/discovery/zte-ont-discovery.inc.php`

**Configuration:**
- `librenms/config/zte-c300-config.php` - ZTE-specific OIDs and thresholds

**Documentation:**
- `librenms/custom-modules/README.md` - Complete module documentation
- `docs/ZTE_CUSTOM_MODULES.md` - Installation and usage guide

**Note:** Custom modules akan aktif otomatis ketika device ZTE C300 ditambahkan ke LibreNMS.

## Next Steps

Setelah sistem berjalan:

1. **Setup shell aliases** (jika belum):
   ```bash
   bash scripts/setup.sh
   source ~/.bashrc  # atau ~/.zshrc
   ```

2. **Configure SNMP credential encryption**:
   ```bash
   ./scripts/configure-encryption.sh
   ```

3. **Add network devices** (OLT, router, switch, server, dll):
   ```bash
   # Contoh: Add ZTE C300 OLT
   ./scripts/add-device.sh -h 192.168.1.1 -v v2c -c public
   
   # Contoh: Add Mikrotik Router
   ./scripts/add-device.sh -h 192.168.1.254 -v v2c -c public
   
   # Contoh: Add Cisco Switch dengan SNMP v3
   ./scripts/add-device.sh -h 10.0.0.1 -v v3 -u admin -p password123 -a SHA
   ```
   
   Lihat [SNMP Device Management Guide](docs/SNMP_DEVICE_MANAGEMENT.md) untuk detail lengkap.

4. **Verify interface monitoring**:
   ```bash
   # Check interface polling status
   ./scripts/verify-interface-logging.sh
   
   # Test graph generation
   ./scripts/test-graphs.sh
   ```

5. Akses dashboard di `http://localhost:80`
6. Complete initial setup wizard
7. Configure alert rules dan transports
8. Customize dashboard sesuai kebutuhan
9. **Setup automated backups** dengan crontab

## Useful Commands Cheatsheet

```bash
# Quick resource check
librenms-resources

# View live logs
librenms-logs

# Create backup before maintenance
librenms-backup

# Restart after configuration changes
librenms-restart

# Check container status
librenms-ps

# View all available backups
librenms-backups
```

## Support

Untuk issues atau questions, refer to:
- **Supported Devices**: [docs/SUPPORTED_DEVICES.md](docs/SUPPORTED_DEVICES.md) - Daftar lengkap perangkat yang didukung
- **SNMP Device Management**: [docs/SNMP_DEVICE_MANAGEMENT.md](docs/SNMP_DEVICE_MANAGEMENT.md) - Panduan lengkap menambahkan berbagai jenis perangkat
- **Aliases Guide**: [docs/ALIASES.md](docs/ALIASES.md) - Detailed documentation untuk semua shell aliases
- **Resource Presets**: [docs/RESOURCE_PRESETS.md](docs/RESOURCE_PRESETS.md) - Panduan memilih preset sesuai RAM sistem
- LibreNMS Documentation: https://docs.librenms.org/
- Docker Compose Documentation: https://docs.docker.com/compose/
