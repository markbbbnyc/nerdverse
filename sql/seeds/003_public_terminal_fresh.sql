-- 003_public_terminal_fresh.sql
-- Anonymous one-shot public-terminal lives ONLY (nerdverse_web_* databases).
-- NOT the author's Life-2 checkpoint (002_fresh_game.sql) — generic pilgrim start.
-- Applied via NERDVERSE_PUBLIC_FRESH_SEED=1 in game_db_create_web_session().
-- Characters are renamed during registration (character_create_wizard_public).

INSERT INTO characters (name, title, class, current_hp, max_hp, coins_silver, road_xp, road_xp_max, location, is_player, notes)
VALUES ('Pilgrim', 'Walker on the Open Road', 'Mage', 11, 13, 4, 0, 10, 'Brindleford Forge', TRUE,
        'A new operator on the public terminal lane. Names are chosen at registration.');

SET @player_id = (SELECT id FROM characters WHERE is_player = TRUE ORDER BY id LIMIT 1);

INSERT INTO characters (name, title, class, current_hp, max_hp, location, is_player, notes)
VALUES ('Guide Walker', 'Field-healer and trail archer', 'Healer-Archer', 14, 14, 'Brindleford Forge', FALSE,
        'Provisional companion for a one-shot pilgrimage. Renamed during registration.');

SET @companion_id = (SELECT id FROM characters WHERE is_player = FALSE ORDER BY id LIMIT 1);

INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags) VALUES
(@player_id, 'ash_wood_buckler', 'Ash-Wood Buckler', 1, TRUE,
 'A practical buckler from the village forge.',
 'Passive Guard: reduce the first physical hit by 1 each round. Breathguard: once per battle, reduce one hit by 3.',
 'defensive,passive,breathguard'),
(@player_id, 'repair_bundle', 'Repair and Supply Bundle', 1, FALSE,
 'Oilcloth kit: cord, needle, bandage cloth, whetstone.',
 'Solve a minor practical problem without a shop once per travel day.', 'tool,craft'),
(@player_id, 'road_knife', 'Road Knife', 1, FALSE,
 'Mundane utility knife.', 'Practical tool.', 'tool'),
(@companion_id, 'sera_bow', 'Trail Bow', 1, TRUE, 'Companion bow.', 'Bow Shot: 3 damage.', 'weapon,companion'),
(@companion_id, 'sera_buckler', 'Buckler', 1, TRUE, 'Companion buckler.', 'Buckler Guard: reduce damage by 2 once per round.', 'defensive,companion');

INSERT INTO world_state (state_key, value) VALUES
('current_chapter', 'First Steps on the Road'),
('arc_goal', 'Learn the vale, gather practical gear, and decide who walks beside you.'),
('black_bridge_gang_status', 'Rumors on the wind — nothing personal yet.'),
('brindleford_preparedness', 'Low'),
('sera_trust', 'provisional'),
('last_major_event', 'A new road opens at Brindleford Forge.'),
('sera_trust_level', '20'),
('sera_bond_level', '15'),
('sera_joint_experiences', '0'),
('sera_leadership_moments', '0'),
('sera_last_action', ''),
('sera_recent_event', ''),
('game_initialized', 'public_terminal_template'),
('mill_status', 'unexamined'),
('brindleford_food_supply', 'stable'),
('bridge_alert_level', 'low');

INSERT INTO character_abilities (character_id, ability_key, ability_name, uses_remaining, description) VALUES
(@player_id, 'zen_mage_firebolt', 'Zen-Mage Firebolt', NULL, '6 damage. A basic arcane strike.'),
(@player_id, 'ash_wood_breathguard', 'Breathguard (Ash-Wood Buckler)', 1,
 'Once per battle: reduce one incoming hit by 3.');

UPDATE inventory SET slot = 'off_hand' WHERE character_id = @player_id AND item_key = 'ash_wood_buckler';

UPDATE characters c
JOIN locations l ON l.key_name = 'forge'
SET c.location_key = 'forge', c.location = l.display_name
WHERE c.id IN (@player_id, @companion_id);

UPDATE locations SET visited = TRUE WHERE key_name IN ('forge');

INSERT INTO session_log (log_type, entry, location, character_name)
VALUES ('SYSTEM', 'Public-terminal life created. Registration assigns pilgrim and companion names.', 'Brindleford Forge', 'System');