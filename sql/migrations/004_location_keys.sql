-- 004_location_keys.sql
-- Wire characters to the locations graph via stable key_name.

ALTER TABLE characters ADD COLUMN IF NOT EXISTS location_key VARCHAR(100) DEFAULT NULL;