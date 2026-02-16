<?php
/**
 * Interface and Port Monitoring Configuration
 *
 * This configuration enables standard interface polling for all devices
 * with a 5-minute polling interval as per Requirements 3.1 and 3.4.
 */

// Enable ports module for all devices
$config['poller_modules']['ports'] = true;
$config['discovery_modules']['ports'] = true;

// Configure polling interval (300 seconds = 5 minutes)
$config['rrd']['step'] = 300;
$config['poller_interval'] = 300;

// Enable interface status collection
$config['enable_ports'] = true;
$config['enable_ports_separate_walk'] = true;

// Collect all interface statistics
$config['enable_ports_etherlike'] = true;
$config['enable_ports_junoseatmvp'] = false;
$config['enable_ports_poe'] = true;

// Enable interface status monitoring (up/down)
$config['ports_fdb'] = true;
$config['ports_purge'] = true;

// Enable 64-bit counters for high-speed interfaces
$config['enable_ports_64bit'] = true;

// Enable interface state change detection
$config['ports_state_change_detection'] = true;

// Log interface state changes to eventlog (Requirements 3.2)
$config['log_interface_state_changes'] = true;

// Enable interface graphs
$config['enable_ports_graph'] = true;

// Interface polling performance settings
$config['ports_polling_timeout'] = 30;  // 30 seconds timeout
$config['ports_polling_retries'] = 3;   // 3 retries on failure

// Enable SNMP bulk walk for faster polling
$config['snmp']['max_repeaters'] = 25;
$config['snmp']['max_oid'] = 10;

