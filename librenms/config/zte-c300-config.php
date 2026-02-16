<?php
/**
 * ZTE C300 Custom Configuration
 *
 * This configuration file enables custom polling modules for ZTE C300 OLT
 * and defines ZTE-specific OIDs and settings.
 */

// Enable custom polling modules for ZTE devices
$config['os']['zte']['polling_modules']['zte-optical-power'] = true;
$config['os']['zte']['polling_modules']['zte-ont-status'] = true;

// ZTE C300 specific OID definitions
$config['zte']['oids'] = [
    // Optical Power OIDs
    'optical_power' => [
        'tx_power' => '.1.3.6.1.4.1.3902.1082.500.10.2.1.1.1',
        'rx_power' => '.1.3.6.1.4.1.3902.1082.500.10.2.1.1.2',
        'pon_port_table' => '.1.3.6.1.4.1.3902.1082.500.10.2.1',
    ],
    
    // ONT Status OIDs
    'ont_status' => [
        'ont_table' => '.1.3.6.1.4.1.3902.1082.500.11.2.1',
        'ont_serial' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.3',
        'ont_status' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.1',
        'ont_model' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.4',
        'ont_firmware' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.5',
        'ont_rx_power' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.6',
        'ont_tx_power' => '.1.3.6.1.4.1.3902.1082.500.11.2.1.1.7',
    ],
];

// Optical power thresholds (in dBm)
$config['zte']['optical_power_thresholds'] = [
    'tx' => [
        'low' => -10,
        'low_warn' => -8,
        'high_warn' => 2,
        'high' => 3,
    ],
    'rx' => [
        'low' => -30,
        'low_warn' => -28,
        'high_warn' => -8,
        'high' => -6,
    ],
];

// ONT status codes
$config['zte']['ont_status_codes'] = [
    1 => 'online',
    2 => 'offline',
    3 => 'dying-gasp',
    4 => 'unknown',
];

// Polling interval (in seconds) - default 5 minutes
$config['zte']['polling_interval'] = 300;
