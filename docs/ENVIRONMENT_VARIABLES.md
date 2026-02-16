# Environment Variables Configuration

## Overview

System menggunakan `.env` file untuk konfigurasi environment variables. Semua kredensial dan konfigurasi disimpan di file ini untuk memudahkan manajemen dan keamanan.

## Setup

1. Copy `.env.example` ke `.env`:
```bash
cp .env.example .env
```

2. Edit `.env` sesuai kebutuhan:
```bash
nano .env
```

3. **PENTING**: Ganti password default sebelum production:
```
DB_PASSWORD=your_secure_password
MYSQL_ROOT_PASSWORD=your_root_password
```

## Environment Variables

### Resource Limits

System menyediakan 4 preset konfigurasi (2GB, 4GB, 8GB, 16GB). Lihat `docs/RESOURCE_PRESETS.md` untuk detail lengkap.

```
LIBRENMS_MEMORY=1280M
LIBRENMS_CPU=1.25
DB_MEMORY=512M
DB_CPU=0.5
REDIS_MEMORY=128M
REDIS_CPU=0.125
DISPATCHER_MEMORY=128M
DISPATCHER_CPU=0.125
```

Memory limit untuk setiap container. Total harus sesuai RAM sistem Anda.

### LibreNMS Configuration

```
TZ=Asia/Jakarta
```
Timezone untuk sistem. Sesuaikan dengan lokasi Anda.

```
PUID=1000
PGID=1000
```
User ID dan Group ID untuk file permissions di container.

### Database Configuration

```
DB_HOST=db
```
Hostname database container (jangan diubah kecuali custom setup).

```
DB_NAME=librenms
```
Nama database LibreNMS.

```
DB_USER=librenms
```
Username database untuk LibreNMS.

```
DB_PASSWORD=librenms_password
```
**HARUS DIGANTI** - Password database untuk user LibreNMS.

```
DB_TIMEOUT=60
```
Timeout koneksi database dalam detik.

```
MYSQL_ROOT_PASSWORD=root_password
```
**HARUS DIGANTI** - Password root untuk MariaDB.

### Redis Configuration

```
REDIS_HOST=redis
```
Hostname Redis container (jangan diubah kecuali custom setup).

```
REDIS_PORT=6379
```
Port Redis (default 6379).

```
REDIS_DB=0
```
Redis database number.

### Dispatcher Configuration

```
DISPATCHER_NODE_ID=dispatcher1
```
ID untuk dispatcher node (untuk multi-node setup).

```
SIDECAR_DISPATCHER=1
```
Enable sidecar dispatcher mode.

### Database Optimization Parameters

System menyediakan preset untuk berbagai ukuran RAM. Lihat `docs/RESOURCE_PRESETS.md` untuk detail.

**Key Parameters:**

```
DB_INNODB_BUFFER_POOL=256M
```
InnoDB buffer pool size. Harus 50% dari DB_MEMORY.

```
DB_MAX_CONNECTIONS=50
```
Maximum database connections. Sesuaikan dengan load.

```
DB_TMP_TABLE_SIZE=32M
```
Temporary table size untuk complex queries.

**Static Parameters** (jangan diubah):
- `DB_INNODB_FILE_PER_TABLE=1`
- `DB_LOWER_CASE_TABLE_NAMES=0`
- `DB_CHARACTER_SET=utf8mb4`
- `DB_COLLATION=utf8mb4_unicode_ci`
- `DB_SKIP_LOG_BIN=1`
- `DB_PERFORMANCE_SCHEMA=OFF`

## Security Best Practices

### 1. Ganti Password Default

Sebelum deployment production, ganti semua password:

```bash
nano .env
```

Ganti:
- `DB_PASSWORD` - gunakan password kuat (min 16 karakter)
- `MYSQL_ROOT_PASSWORD` - gunakan password kuat (min 16 karakter)

### 2. File Permissions

Set permission yang benar untuk `.env`:

```bash
chmod 600 .env
```

Ini memastikan hanya owner yang bisa read/write file.

### 3. Git Ignore

File `.env` sudah ada di `.gitignore`. Jangan commit file ini ke repository.

### 4. Backup Credentials

Simpan credentials di tempat aman (password manager) untuk recovery.

## Usage in Scripts

Semua script otomatis membaca `.env` file:

```bash
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi
```

Script yang menggunakan `.env`:
- `scripts/deploy.sh`
- `scripts/backup.sh`
- `scripts/restore.sh`
- `scripts/setup-librenms.sh`

## Usage in Docker Compose

Docker Compose otomatis membaca `.env` file di directory yang sama dengan `docker-compose.yml`.

Variables digunakan dengan syntax `${VARIABLE_NAME}`:

```yaml
environment:
  - DB_PASSWORD=${DB_PASSWORD}
  - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
```

## Troubleshooting

### Script tidak membaca .env

Pastikan `.env` file ada di root directory project:
```bash
ls -la .env
```

### Permission denied

Set permission yang benar:
```bash
chmod 600 .env
```

### Docker Compose tidak membaca .env

Pastikan `.env` file di directory yang sama dengan `docker-compose.yml`:
```bash
pwd
ls -la .env docker-compose.yml
```

### Variable tidak ter-substitute

Check format variable di `.env`:
- Tidak ada spasi sebelum/sesudah `=`
- Tidak ada quotes kecuali value mengandung spasi
- Tidak ada trailing whitespace

Contoh benar:
```
DB_PASSWORD=mypassword
```

Contoh salah:
```
DB_PASSWORD = mypassword
DB_PASSWORD= "mypassword"
```

## Validation

Validate environment variables loaded correctly:

```bash
source .env
echo $DB_PASSWORD
echo $MYSQL_ROOT_PASSWORD
```

Validate Docker Compose reads variables:

```bash
docker compose config | grep -A 5 environment
```

## References

- Docker Compose Environment Variables: https://docs.docker.com/compose/environment-variables/
- Bash Environment Variables: https://www.gnu.org/software/bash/manual/html_node/Environment.html

