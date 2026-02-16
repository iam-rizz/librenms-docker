# Quick Start: Memilih Resource Preset

## Langkah Cepat

### 1. Cek RAM Sistem

```bash
free -h | grep Mem
```

### 2. Pilih Preset

| RAM Sistem | Preset | Devices | Users |
|------------|--------|---------|-------|
| 2GB        | Preset 1 (Default) | 1-5 OLT | 1-2 |
| 4GB        | Preset 2 | 5-20 OLT | 3-5 |
| 8GB        | Preset 3 | 20-50 OLT | 5-10 |
| 16GB       | Preset 4 | 50+ OLT | 10-20 |

### 3. Edit .env

```bash
nano .env
```

### 4. Aktifkan Preset

**Untuk RAM 2GB (Default - sudah aktif):**
Tidak perlu ubah apa-apa.

**Untuk RAM 4GB:**

Comment preset 2GB:
```bash
# LIBRENMS_MEMORY=1280M
# LIBRENMS_CPU=1.25
# DB_MEMORY=512M
# DB_CPU=0.5
# REDIS_MEMORY=128M
# REDIS_CPU=0.125
# DISPATCHER_MEMORY=128M
# DISPATCHER_CPU=0.125
```

Uncomment preset 4GB:
```bash
LIBRENMS_MEMORY=2560M
LIBRENMS_CPU=2.0
DB_MEMORY=1024M
DB_CPU=1.0
REDIS_MEMORY=256M
REDIS_CPU=0.25
DISPATCHER_MEMORY=256M
DISPATCHER_CPU=0.25
```

Dan di section database, comment preset 512MB:
```bash
# DB_INNODB_BUFFER_POOL=256M
# DB_INNODB_LOG_FILE_SIZE=64M
# DB_MAX_CONNECTIONS=50
# ...
```

Uncomment preset 1GB:
```bash
DB_INNODB_BUFFER_POOL=512M
DB_INNODB_LOG_FILE_SIZE=128M
DB_MAX_CONNECTIONS=100
# ...
```

**Untuk RAM 8GB atau 16GB:**
Ikuti pola yang sama, uncomment preset yang sesuai.

### 5. Deploy

```bash
docker compose up -d
```

### 6. Verify

```bash
docker stats --no-stream
```

Check apakah memory usage sesuai dengan preset yang dipilih.

## Troubleshooting Cepat

**Container tidak start:**
```bash
docker compose logs db
```

Kemungkinan: Memory limit terlalu kecil. Turunkan preset atau tambah RAM.

**Dashboard lambat:**
Naikkan ke preset yang lebih tinggi.

**Out of Memory:**
Turunkan ke preset yang lebih rendah.

## Detail Lengkap

Lihat dokumentasi lengkap:
- `docs/RESOURCE_PRESETS.md` - Detail setiap preset
- `docs/ENVIRONMENT_VARIABLES.md` - Penjelasan semua variables
- `docs/DATABASE_OPTIMIZATION.md` - Database tuning guide

