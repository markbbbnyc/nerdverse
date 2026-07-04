-- 001_catalog.sql
-- World catalog: locations, maps hooks, state keys. Neutral text — any pilgrim.
-- Safe to re-apply on every migration (DEV + public). Does NOT overwrite live story values.
-- New lore/locations added here flow to all environments on deploy.

INSERT INTO locations (key_name, display_name, description, connected_to, danger_level, visited)
VALUES
('forge', 'Cold Forge (Old Brenn)', 'The village forge. Old Brenn crafts practical gear; ash-wood bucklers are prized here.', 'inn,sheriff,medicine', 1, FALSE),
('medicine', 'Medicine Room', 'Field supplies and triage. The companion often leads here when crates or wounds demand attention.', 'forge,sheriff', 0, FALSE),
('sheriff', 'Sheriff Marn''s Office', 'Tired but armed. Village defense, bandit interrogation, and dusk watches are planned here.', 'forge,medicine,inn', 1, FALSE),
('inn', 'Hearthmouse Inn', 'Food, rest, rumors, lodging. A meal and a roof before the harder roads.', 'sheriff,forge', 0, FALSE),
('mill', 'The Old Mill', 'Food supply threat. The wheel turns too slowly — rot, sabotage, or worse.', 'medicine', 2, FALSE),
('bridge', 'Iron Bridge / Gang Tollhouse', 'Black Bridge Gang territory. Led by Garran Pike. Champion: Toll-Saint.', 'mill', 5, FALSE)
ON DUPLICATE KEY UPDATE
    display_name = VALUES(display_name),
    description = VALUES(description),
    connected_to = VALUES(connected_to),
    danger_level = VALUES(danger_level);

INSERT IGNORE INTO world_state (state_key, value) VALUES
('sera_trust_level', '20'),
('sera_bond_level', '15'),
('sera_joint_experiences', '0'),
('sera_leadership_moments', '0'),
('sera_last_action', ''),
('sera_recent_event', ''),
('mill_status', 'unexamined'),
('brindleford_food_supply', 'at_risk'),
('bridge_alert_level', 'low'),
('bridge_arrival_scouted', '');