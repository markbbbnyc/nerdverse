-- 001_catalog.sql
-- Reference / world catalog data. Safe to re-apply on every migration run.
-- Does NOT touch player progress (HP, location, inventory quantities, world story state).

-- === LOCATIONS (static world graph — preserve visited flag) ===
INSERT INTO locations (key_name, display_name, description, connected_to, danger_level, visited)
VALUES
('forge', 'Cold Forge (Old Brenn)', 'The forge where Meyiu just bought the Ash-Wood Buckler and repair bundle. Old Brenn is injured.', 'inn,sheriff,medicine', 1, FALSE),
('medicine', 'Sera''s Medicine Room', 'Where the recovered medicine crate is stored. Sera controls supplies and will criticize waste.', 'forge,sheriff', 0, FALSE),
('sheriff', 'Sheriff Marn''s Office', 'Tired but armed. Can muster a few villagers. Bandit interrogation and village defense planning happen here.', 'forge,medicine,inn', 1, FALSE),
('inn', 'Hearthmouse Inn', 'Food, rest, rumors, lodging. Meyiu has a meal and lodging token from Sheriff Marn.', 'sheriff,forge', 0, FALSE),
('mill', 'The Old Mill', 'Food supply threat. Wheel turns too slowly. Possible rot, sabotage, or other problem.', 'medicine', 2, FALSE),
('bridge', 'Iron Bridge / Gang Tollhouse', 'Black Bridge Gang base. 9-12 fighters led by Garran Pike. Champion: Toll-Saint.', 'mill', 5, FALSE)
ON DUPLICATE KEY UPDATE
    display_name = VALUES(display_name),
    description = VALUES(description),
    connected_to = VALUES(connected_to),
    danger_level = VALUES(danger_level);

-- === WORLD STATE KEYS (ensure exist on older saves — never overwrite values) ===
INSERT IGNORE INTO world_state (state_key, value) VALUES
('sera_trust_level', '35'),
('sera_bond_level', '25'),
('sera_joint_experiences', '0'),
('sera_leadership_moments', '0'),
('sera_last_action', ''),
('sera_recent_event', ''),
('mill_status', 'unexamined'),
('brindleford_food_supply', 'at_risk'),
('bridge_alert_level', 'low'),
('bridge_arrival_scouted', '');