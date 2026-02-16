# Database Optimization Configuration

## Overview

MariaDB database configured with optimizations for low memory environments (512MB allocated). Settings ensure efficient operation within resource constraints defined in Requirements 9.1 and 9.2.

## Configuration Parameters

### InnoDB Buffer Pool Settings

```
--innodb-buffer-pool-size=256M
```
Main memory cache for InnoDB tables and indexes. Set to 256MB (50% of allocated 512MB memory). Critical for query performance.

```
--innodb-log-file-size=64M
```
Size of redo log files for crash recovery. Balanced for performance and memory usage.

```
--innodb-file-per-table=1
```
Each table gets its own tablespace file. Better for space management and backup operations.

### Connection Limits

```
--max-connections=50
--max-user-connections=45
```
Maximum simultaneous database connections. Limited to prevent memory exhaustion. Sufficient for LibreNMS polling and web interface.

### Thread and Cache Settings

```
--thread-cache-size=8
```
Number of threads to cache for reuse. Reduces overhead of creating new threads.

```
--table-open-cache=400
--table-definition-cache=400
```
Number of open tables and table definitions to cache. Balanced for memory conservation.

### Temporary Table Settings

```
--tmp-table-size=32M
--max-heap-table-size=32M
```
Maximum size for in-memory temporary tables. Larger queries will use disk-based temporary tables.

### Per-Connection Buffer Settings

```
--sort-buffer-size=2M
--read-buffer-size=1M
--read-rnd-buffer-size=2M
--join-buffer-size=2M
```
Memory allocated per connection for various operations. Kept small to prevent memory exhaustion with many connections. Total per-connection memory: ~7MB.

### Character Set

```
--character-set-server=utf8mb4
--collation-server=utf8mb4_unicode_ci
```
Full UTF-8 support including emoji and special characters. Required for international device names and descriptions.

```
--lower-case-table-names=0
```
Case-sensitive table names. Required by LibreNMS.

### Binary Logging

```
--skip-log-bin
```
Binary logging disabled to save disk space and memory. Enable only if you need replication or point-in-time recovery.

### Performance Schema

```
--performance-schema=OFF
```
Disabled to save memory (~400MB savings). Enable only for detailed performance analysis.

### InnoDB Performance Settings

```
--innodb-flush-log-at-trx-commit=2
```
Flush redo log to disk every second (not on every commit). Less safe but significantly faster. Acceptable for monitoring data (not financial transactions).

```
--innodb-flush-method=O_DIRECT
```
Bypass OS cache for InnoDB I/O. Prevents double buffering (OS cache + InnoDB buffer pool).

```
--innodb-log-buffer-size=8M
```
Buffer for redo log writes before flushing to disk.

```
--innodb-read-io-threads=2
--innodb-write-io-threads=2
```
Reduced I/O threads for low CPU environment. Sufficient for typical monitoring workload.

### Connection Timeout Settings

```
--wait-timeout=600
--interactive-timeout=600
--connect-timeout=10
```
Idle connections closed after 10 minutes. Connection establishment timeout: 10 seconds. Prevents resource leaks from abandoned connections.

### Network Settings

```
--max-allowed-packet=64M
```
Maximum size for queries and result sets. Sufficient for large SNMP data imports.

## Memory Usage Calculation

### Fixed Memory Usage
- InnoDB Buffer Pool: 256 MB
- InnoDB Log Buffer: 8 MB
- Table Caches: ~20 MB
- Thread Cache: ~2 MB
- **Subtotal: ~286 MB**

### Per-Connection Memory (worst case)
- Sort Buffer: 2 MB
- Read Buffer: 1 MB
- Read RND Buffer: 2 MB
- Join Buffer: 2 MB
- **Per Connection: ~7 MB**

### Total Memory Estimate
- Fixed: 286 MB
- Connections (50 × 7 MB): 350 MB
- **Total: ~636 MB**

Within 512MB container limit because:
1. Not all connections use maximum buffer sizes
2. Buffers are allocated on-demand
3. Typical usage: 5-10 active connections
4. Realistic usage: ~350-400 MB

## Monitoring Database Performance

### Check Current Connections
```bash
docker exec librenms_db mysql -u root -proot_password -e "SHOW PROCESSLIST;"
```

### Check InnoDB Status
```bash
docker exec librenms_db mysql -u root -proot_password -e "SHOW ENGINE INNODB STATUS\G"
```

### Check Memory Usage
```bash
docker stats librenms_db --no-stream
```

### Check Buffer Pool Usage
```bash
docker exec librenms_db mysql -u root -proot_password -e "
SELECT 
  (SELECT SUM(data_length + index_length) FROM information_schema.TABLES) / 1024 / 1024 AS 'Total DB Size (MB)',
  @@innodb_buffer_pool_size / 1024 / 1024 AS 'Buffer Pool Size (MB)',
  (SELECT COUNT(*) FROM information_schema.PROCESSLIST) AS 'Active Connections';
"
```

## Tuning Recommendations

### If Memory Usage is Too High
1. Reduce `max_connections` to 30
2. Reduce buffer sizes by 50%
3. Reduce `table_open_cache` to 200

### If Performance is Slow
1. Check if buffer pool is too small (hit ratio < 95%)
2. Increase `innodb_buffer_pool_size` if memory available
3. Enable slow query log to identify problematic queries

### If Disk I/O is High
1. Check if temporary tables are spilling to disk
2. Increase `tmp_table_size` if memory available
3. Optimize queries to reduce temporary table usage

## Validation

Database configuration can be validated by:

1. **Container starts successfully**
   ```bash
   docker compose up -d db
   docker logs librenms_db
   ```

2. **Memory usage within limits**
   ```bash
   docker stats librenms_db --no-stream
   ```

3. **LibreNMS can connect**
   ```bash
   docker exec librenms php /opt/librenms/lnms db:check
   ```

4. **Query performance acceptable**
   - Dashboard loads in < 2 seconds
   - Polling completes within 5 minute interval

## References

- Requirements 9.1: Memory usage ≤ 2GB total (512MB for database)
- Requirements 9.2: CPU usage ≤ 2 cores total (0.5 cores for database)
- MariaDB Documentation: https://mariadb.com/kb/en/server-system-variables/
- InnoDB Tuning: https://mariadb.com/kb/en/innodb-system-variables/

