-- 005_progression.sql — Modular practice, breakthrough levels, combos, components
-- Philosophy: 2-3 combat actives max; many inert pieces combine into surprises.

ALTER TABLE characters
    ADD COLUMN IF NOT EXISTS prog_level INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS breakthrough_pending TINYINT NOT NULL DEFAULT 0;

ALTER TABLE character_abilities
    ADD COLUMN IF NOT EXISTS combat_active TINYINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS combat_slot INT DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS practice_tags VARCHAR(120) DEFAULT NULL;

CREATE TABLE IF NOT EXISTS character_practice (
    id INT AUTO_INCREMENT PRIMARY KEY,
    character_id INT NOT NULL,
    practice_key VARCHAR(40) NOT NULL,
    points INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_char_practice (character_id, practice_key),
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS character_unlocks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    character_id INT NOT NULL,
    unlock_key VARCHAR(80) NOT NULL,
    unlock_type ENUM('ability','passive','component','combo') NOT NULL DEFAULT 'component',
    display_name VARCHAR(150) NOT NULL,
    description TEXT,
    is_shiny TINYINT NOT NULL DEFAULT 0,
    source_note VARCHAR(200) DEFAULT NULL,
    unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_char_unlock (character_id, unlock_key),
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS combo_recipes (
    combo_key VARCHAR(80) PRIMARY KEY,
    display_name VARCHAR(150) NOT NULL,
    primer_key VARCHAR(80) NOT NULL,
    followup_key VARCHAR(80) NOT NULL,
    effect_summary TEXT,
    bonus_damage INT NOT NULL DEFAULT 4,
    narrative_flavor VARCHAR(255) DEFAULT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS party_combos_discovered (
    id INT AUTO_INCREMENT PRIMARY KEY,
    combo_key VARCHAR(80) NOT NULL,
    fused_unlock_key VARCHAR(80) DEFAULT NULL,
    discovered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_combo (combo_key)
) ENGINE=InnoDB;

-- Combat menu: top 3 actives for Meyiu
UPDATE character_abilities ca
JOIN characters c ON ca.character_id = c.id
SET ca.combat_active = 1, ca.combat_slot = 1, ca.practice_tags = 'arcane,focus'
WHERE c.name = 'Meyiu' AND ca.ability_key = 'zen_mage_firebolt';

UPDATE character_abilities ca
JOIN characters c ON ca.character_id = c.id
SET ca.combat_active = 1, ca.combat_slot = 2, ca.practice_tags = 'practical,strength'
WHERE c.name = 'Meyiu' AND ca.ability_key = 'ash_wood_breathguard';

UPDATE character_abilities ca
JOIN characters c ON ca.character_id = c.id
SET ca.combat_active = 1, ca.combat_slot = 3, ca.practice_tags = 'practical,arcane'
WHERE c.name = 'Meyiu' AND ca.ability_key = 'penitents_wrap';

-- Companion track uses same road_xp fields
UPDATE characters SET road_xp_max = 10 WHERE name = 'Sera Thornwake' AND road_xp_max = 10;

-- Sera combat/support abilities (companion acts alongside player)
INSERT IGNORE INTO character_abilities (character_id, ability_key, ability_name, uses_remaining, description, proficiency, combat_active, combat_slot, practice_tags)
SELECT c.id, 'sera_frozen_ground', 'Frozen Ground (zone)', NULL,
       'Sera lays chill on the field — primes Thermal Shock with Firebolt.',
       0, 1, 1, 'science,medicine'
FROM characters c WHERE c.name = 'Sera Thornwake';

INSERT IGNORE INTO character_abilities (character_id, ability_key, ability_name, uses_remaining, description, proficiency, combat_active, combat_slot, practice_tags)
SELECT c.id, 'sera_triage_mark', 'Triage Mark', NULL,
       'Sera marks the foe — your next hit gains focus.',
       0, 1, 2, 'medicine,tactics'
FROM characters c WHERE c.name = 'Sera Thornwake';

INSERT IGNORE INTO combo_recipes (combo_key, display_name, primer_key, followup_key, effect_summary, bonus_damage, narrative_flavor)
VALUES
('thermal_shock', 'Thermal Shock',
 'sera_frozen_ground', 'zen_mage_firebolt',
 'Cold meets fire — pressure rupture. Bonus damage and brief stagger.',
 5, 'The air screams. Ice becomes steam.'),

('ember_aegis', 'Ember Aegis',
 'ash_wood_breathguard', 'zen_mage_firebolt',
 'Buckler heat meets bolt — reflected ember lash.',
 3, 'Your guard glows; the enemy flinches at the afterimage.');