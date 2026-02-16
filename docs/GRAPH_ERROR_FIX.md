# Graph Error Fix Documentation

## Problem

LibreNMS was returning HTTP 500 errors for all graph requests (`graph.php`). The web interface showed many failed requests in the browser console.

## Root Cause

The error was caused by incompatible configuration in `librenms/config/interface-polling-config.php`. Specifically:

```
TypeError trim(): Argument #1 ($string) must be of type string, array given @ /opt/librenms/LibreNMS/Data/Store/Rrd.php:89
```

The issue was caused by array configurations that LibreNMS expected to be strings or simple values:

1. `$config['ports_stats']` - Array of statistics to collect
2. `$config['bad_if']` - Array of interfaces to ignore
3. `$config['bad_if_regexp']` - Array of regex patterns
4. `$config['rrd_rra']` - Array of RRD retention settings
5. `$config['ports_descr']` - Array of interface description fields

## Solution

Removed the problematic array configurations from `interface-polling-config.php` and kept only the essential boolean and scalar configurations:

- Removed `$config['ports_stats']` array
- Removed `$config['bad_if']` and `$config['bad_if_regexp']` arrays
- Removed `$config['rrd_rra']` array (LibreNMS uses defaults)
- Removed `$config['ports_descr']` array

The simplified configuration file now only contains:
- Boolean flags for enabling/disabling features
- Scalar values for timeouts and intervals
- Simple key-value pairs for SNMP settings

## Verification

After restarting the LibreNMS containers, all graph requests now return HTTP 200:

```bash
./scripts/test-graphs.sh
```

Results:
- ✓ device_bits graph: OK (HTTP 200)
- ✓ device_processor graph: OK (HTTP 200)
- ✓ device_mempool graph: OK (HTTP 200)
- ✓ port_bits graph: OK (HTTP 200)

## Files Modified

1. `librenms/config/interface-polling-config.php` - Simplified configuration
2. `scripts/test-graphs.sh` - Created test script for graph generation

## Testing

To verify graphs are working:

```bash
# Test graph generation
./scripts/test-graphs.sh

# Check for errors in logs
docker logs librenms --tail 50 | grep -i error

# Access LibreNMS web interface
# Navigate to: http://localhost/device/1/graphs
# All graphs should now display properly
```

## Lessons Learned

1. LibreNMS configuration should be kept simple - use defaults when possible
2. Not all configuration options support array values
3. Always test configuration changes by checking logs for errors
4. Graph generation errors often indicate RRD configuration issues

## Related Requirements

- Requirements 3.1: Interface polling every 5 minutes ✓
- Requirements 3.2: Interface state change event logging ✓
- Requirements 3.4: Interface statistics collection ✓
- Requirements 7.3: Dashboard graphs for key metrics ✓

