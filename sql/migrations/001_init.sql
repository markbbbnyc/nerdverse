-- 001_init.sql
-- Phase 0: Core schema for characters, inventory, world state, abilities, logs
-- Designed to be idempotent. Safe to re-run.

-- Track applied migrations
CREATE TABLE IF NOT EXISTS schema_migrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    migration VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Player and important NPCs
CREATE TABLE IF NOT EXISTS characters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    title VARCHAR(255),
    class VARCHAR(50) DEFAULT 'Mage',
    current_hp INT DEFAULT 10,
    max_hp INT DEFAULT 10,
    coins_silver INT DEFAULT 0,
    road_xp INT DEFAULT 0,
    road_xp_max INT DEFAULT 10,
    location VARCHAR(100) DEFAULT 'Unknown',
    is_player BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_name (name)
) ENGINE=InnoDB;

-- Inventory items (can be equipped or carried)
CREATE TABLE IF NOT EXISTS inventory (
    id INT AUTO_INCREMENT PRIMARY KEY,
    character_id INT NOT NULL,
    item_key VARCHAR(100) NOT NULL,           -- stable identifier e.g. 'ashen_prayer_bead'
    item_name VARCHAR(150) NOT NULL,
    quantity INT DEFAULT 1,
    equipped BOOLEAN DEFAULT FALSE,
    description TEXT,
    effect TEXT,                              -- human + mechanical summary
    tags VARCHAR(255),                        -- comma list e.g. 'passive,focus,defensive'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY uk_char_item (character_id, item_key)
) ENGINE=InnoDB;

-- World state as simple key/value (very flexible for early game)
CREATE TABLE IF NOT EXISTS world_state (
    state_key VARCHAR(100) PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Simple ability / passive tracking (cooldowns, uses remaining)
CREATE TABLE IF NOT EXISTS character_abilities (
    id INT AUTO_INCREMENT PRIMARY KEY,
    character_id INT NOT NULL,
    ability_key VARCHAR(100) NOT NULL,
    ability_name VARCHAR(150),
    uses_remaining INT,
    cooldown_until TIMESTAMP NULL,
    description TEXT,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY uk_char_ability (character_id, ability_key)
) ENGINE=InnoDB;

-- Append-only session / story log
CREATE TABLE IF NOT EXISTS session_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    log_type ENUM('NARRATIVE','MECHANICAL','DECISION','SYSTEM','COMPANION') DEFAULT 'NARRATIVE',
    entry TEXT NOT NULL,
    location VARCHAR(100),
    character_name VARCHAR(100)
) ENGINE=InnoDB;

-- Basic locations table (for future map / travel)
CREATE TABLE IF NOT EXISTS locations (
    key_name VARCHAR(100) PRIMARY KEY,
    display_name VARCHAR(150),
    description TEXT,
    connected_to TEXT,           -- comma list of other keys for now
    danger_level INT DEFAULT 0,
    visited BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB;

-- Seed the migration record (will be inserted by apply script)
-- INSERT IGNORE INTO schema_migrations (migration) VALUES ('001_init');  -- done by script
