# Resource Presets Configuration

## Overview

Sistem menyediakan 4 preset konfigurasi resource berdasarkan RAM sistem yang tersedia: 2GB, 4GB, 8GB, dan 16GB. Setiap preset sudah dikalkulasi optimal untuk performa dan stabilitas.

## Cara Memilih Preset

### 1. Cek RAM Sistem Anda

```bash
free -h
```

Lihat baris "Mem:" kolom "total".

### 2. Edit File .env

```bash
nano .env
```

### 3. Uncomment Preset yang Sesuai

Cari section "RESOURCE LIMITS" dan "DATABASE OPTIMIZATION PARAMETERS", lalu:
1. Comment (tambahkan `#` di awal baris) preset yang sedang aktif
2. Uncomment (hapus `#` di awal baris) preset yang Anda inginkan

**PENTING**: Hanya aktifkan 1 preset untuk resource limits dan 1 preset untuk database parameters!

## Preset Details

### Preset 1: RAM 2GB (Minimal)

**Untuk sistem dengan:**
- RAM: 2GB
- CPU: 2 cores
- Use case: Monitoring 1-5 OLT devices

**Resource Allocation:**
```
LibreNMS: 1280M RAM, 1.25 CPU
Database: 512M RAM, 0.5 CPU
Redis: 128M RAM, 0.125 CPU
Dispatcher: 128M RAM, 0.125 CPU
Total: 2048M RAM, 2.0 CPU
```

**Database Configuration:**
```
Buffer Pool: 256M
Max Connections: 50
Tmp Table Size: 32M
```

**Expected Performance:**
- Polling interval: 5 minutes
- Dashboard load time: < 2 seconds
- Concurrent users: 1-2

### Preset 2: RAM 4GB (Recommended)

**Untuk sistem dengan:**
- RAM: 4GB
- CPU: 3-4 cores
- Use case: Monitoring 5-20 OLT devices

**Resource Allocation:**
```
LibreNMS: 2560M RAM, 2.0 CPU
Database: 1024M RAM, 1.0 CPU
Redis: 256M RAM, 0.25 CPU
Dispatcher: 256M RAM, 0.25 CPU
Total: 4096M RAM, 3.5 CPU
```

**Database Configuration:**
```
Buffer Pool: 512M
Max Connections: 100
Tmp Table Size: 64M
```

**Expected Performance:**
- Polling interval: 5 minutes
- Dashboard load time: < 1 second
- Concurrent users: 3-5

### Preset 3: RAM 8GB (High Performance)

**Untuk sistem dengan:**
- RAM: 8GB
- CPU: 4-6 cores
- Use case: Monitoring 20-50 OLT devices

**Resource Allocation:**
```
LibreNMS: 5120M RAM, 3.0 CPU
Database: 2048M RAM, 1.5 CPU
Redis: 512M RAM, 0.5 CPU
Dispatcher: 512M RAM, 0.5 CPU
Total: 8192M RAM, 5.5 CPU
```

**Database Configuration:**
```
Buffer Pool: 1024M
Max Connections: 200
Tmp Table Size: 128M
```

**Expected Performance:**
- Polling interval: 5 minutes
- Dashboard load time: < 0.5 seconds
- Concurrent users: 5-10

### Preset 4: RAM 16GB (Maximum Performance)

**Untuk sistem dengan:**
- RAM: 16GB
- CPU: 8+ cores
- Use case: Monitoring 50+ OLT devices

**Resource Allocation:**
```
LibreNMS: 10240M RAM, 4.0 CPU
Database: 4096M RAM, 2.0 CPU
Redis: 1024M RAM, 1.0 CPU
Dispatcher: 1024M RAM, 1.0 CPU
Total: 16384M RAM, 8.0 CPU
```

**Database Configuration:**
```
Buffer Pool: 2048M
Max Connections: 400
Tmp Table Size: 256M
```

**Expected Performance:**
- Polling interval: 5 minutes
- Dashboard load time: < 0.3 seconds
- Concurrent users: 10-20

## Contoh Konfigurasi

### Mengaktifkan Preset 4GB

Edit `.env`:

```bash
# Comment preset 2GB (default)
# LIBRENMS_MEMORY=1280M
# LIBRENMS_CPU=1.25
# DB_MEMORY=512M
# DB_CPU=0.5
# REDIS_MEMORY=128M
# REDIS_CPU=0.125
# DISPATCHER_MEMORY=128M
# DISPATCHER_CPU=0.125

# Uncomment preset 4GB
LIBRENMS_MEMORY=2560M
LIBRENMS_CPU=2.0
DB_MEMORY=1024M
DB_CPU=1.0
REDIS_MEMORY=256M
REDIS_CPU=0.25
DISPATCHER_MEMORY=256M
DISPATCHER_CPU=0.25
```

Dan di section database:

```bash
# Comment preset 512MB
# DB_INNODB_BUFFER_POOL=256M
# DB_INNODB_LOG_FILE_SIZE=64M
# DB_MAX_CONNECTIONS=50
# ...

# Uncomment preset 1GB
DB_INNODB_BUFFER_POOL=512M
DB_INNODB_LOG_FILE_SIZE=128M
DB_MAX_CONNECTIONS=100
# ...
```

### Apply Perubahan

Setelah edit `.env`:

```bash
docker compose down
docker compose up -d
```

## Monitoring Resource Usage

### Check Current Usage

```bash
docker stats --no-stream
```

### Check Database Buffer Pool Usage

```bash
docker exec librenms_db mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "
SHOW STATUS LIKE 'Innodb_buffer_pool%';
"
```

### Check Connection Usage

```bash
docker exec librenms_db mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "
SHOW STATUS LIKE 'Threads_connected';
SHOW VARIABLES LIKE 'max_connections';
"
```

## Troubleshooting

### Container OOMKilled (Out of Memory)

Gejala:
```bash
docker ps -a
```
Status: "Exited (137)"

Solusi:
1. Turunkan ke preset yang lebih rendah
2. Atau tambah RAM sistem

### Database Slow

Gejala:
- Dashboard load > 5 seconds
- Polling tidak selesai dalam 5 menit

Solusi:
1. Naikkan ke preset yang lebih tinggi
2. Check buffer pool hit ratio (harus > 95%)

### Too Many Connections Error

Gejala:
```
ERROR 1040: Too many connections
```

Solusi:
1. Naikkan `DB_MAX_CONNECTIONS` di preset yang lebih tinggi
2. Atau custom manual di `.env`

## Custom Configuration

Jika preset tidak sesuai, Anda bisa custom manual:

1. Pilih preset terdekat sebagai base
2. Uncomment preset tersebut
3. Edit nilai sesuai kebutuhan
4. Pastikan total memory tidak melebihi RAM sistem
5. Restart containers

**Formula Dasar:**
```
Buffer Pool = 50% dari DB_MEMORY
Max Connections = (DB_MEMORY - Buffer Pool) / 7MB per connection
```

## Validation

Setelah apply preset baru:

1. **Check containers running:**
```bash
docker compose ps
```

2. **Check memory usage:**
```bash
docker stats --no-stream
```

3. **Check database accessible:**
```bash
docker exec librenms php /opt/librenms/lnms db:check
```

4. **Check web interface:**
```
http://localhost:80
```

## References

- Requirements 9.1: Memory usage optimization
- Requirements 9.2: CPU usage optimization
- docs/DATABASE_OPTIMIZATION.md: Detailed database tuning guide

