-- 003_equipment.sql
-- Phase 1: equipment slots and ability proficiency tracking.

ALTER TABLE inventory ADD COLUMN IF NOT EXISTS slot VARCHAR(50) DEFAULT NULL;
ALTER TABLE character_abilities ADD COLUMN IF NOT EXISTS proficiency INT DEFAULT 0;