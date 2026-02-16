-- Migration: Create ONTs table for ZTE C300 ONT monitoring
-- Requirements: 5.1, 5.2, 5.5
-- 
-- This table stores ONT (Optical Network Terminal) information
-- for ZTE C300 OLT devices including status, identity, and optical power data.

CREATE TABLE IF NOT EXISTS `onts` (
    `ont_id` INT(11) NOT NULL AUTO_INCREMENT,
    `device_id` INT(11) NOT NULL,
    `pon_port` VARCHAR(32) NOT NULL COMMENT 'PON port identifier (e.g., gpon-olt_1/1/1)',
    `ont_index` INT(11) NOT NULL COMMENT 'ONT ID within the PON port',
    `serial_number` VARCHAR(64) DEFAULT NULL COMMENT 'ONT serial number',
    `model` VARCHAR(64) DEFAULT NULL COMMENT 'ONT model/hardware type',
    `firmware_version` VARCHAR(64) DEFAULT NULL COMMENT 'ONT firmware version',
    `status` ENUM('online', 'offline', 'dying-gasp', 'unknown') DEFAULT 'unknown' COMMENT 'Current ONT status',
    `rx_power` DECIMAL(5,2) DEFAULT NULL COMMENT 'Received optical power in dBm',
    `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last time ONT was seen/polled',
    PRIMARY KEY (`ont_id`),
    UNIQUE KEY `device_pon_ont` (`device_id`, `pon_port`, `ont_index`),
    KEY `device_id` (`device_id`),
    KEY `status` (`status`),
    KEY `last_seen` (`last_seen`),
    CONSTRAINT `onts_device_id_fk` FOREIGN KEY (`device_id`) 
        REFERENCES `devices` (`device_id`) 
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='ONT status and information for ZTE C300 OLT devices';

-- Create index for efficient status queries
CREATE INDEX `idx_device_status` ON `onts` (`device_id`, `status`);

-- Create index for efficient PON port queries
CREATE INDEX `idx_pon_port` ON `onts` (`pon_port`);
