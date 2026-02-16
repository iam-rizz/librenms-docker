<?php
/**
 * Interface State Change Event Logging Configuration
 *
 * This configuration enables logging of interface state changes (up/down)
 * with timestamps as per Requirements 3.2.
 */

// Enable interface state change event logging
$config['log_interface_state_changes'] = true;

// Enable eventlog module
$config['enable_syslog'] = true;

// Configure event logging for port status changes
$config['ports_state_change_detection'] = true;

// Log all interface state changes to eventlog table
$config['eventlog_severity'] = [
    'interface_up' => 1,    // Informational
    'interface_down' => 3,  // Warning
];

// Enable detailed logging for interface events
$config['log_events'] = true;

// Configure which interface state changes to log
$config['log_port_status'] = [
    'up' => true,       // Log when interface goes up
    'down' => true,     // Log when interface goes down
    'testing' => true,  // Log when interface enters testing state
];

// Enable timestamp for all events (automatic in LibreNMS)
// Events are stored in eventlog table with datetime field

// Configure event retention (30 days as per Requirements 3.5)
$config['eventlog_purge'] = 30;  // Days to keep event logs

// Enable interface status change alerts (optional, for Requirements 3.2)
$config['alert']['default_only'] = false;
$config['alert']['disable'] = false;

// Configure interface down detection threshold
// This prevents flapping interfaces from generating too many events
$config['interface_down_detection_threshold'] = 2;  // Number of consecutive polls before logging

// Enable interface status history
$config['enable_port_status_history'] = true;

// Log interface errors and discards changes
$config['log_port_errors'] = true;
$config['log_port_discards'] = true;

// Configure event message format
$config['eventlog_message_format'] = [
    'interface_up' => 'Interface %s changed state to UP',
    'interface_down' => 'Interface %s changed state to DOWN',
    'interface_testing' => 'Interface %s changed state to TESTING',
];

// Enable syslog for interface events (optional)
$config['enable_syslog'] = true;
$config['syslog_filter'] = [
    'interface' => true,
];

