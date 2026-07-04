-- profiles/public_arc_start.sql
-- Chapter 1 start of the Brindleford arc — full storyline ahead, neutral pilgrim names.
-- Public players experience the entire arc (forge → medicine → sheriff → mill → bridge).
-- NOT the author's mid-arc checkpoint (profiles/author_checkpoint.sql).
-- Registration renames Pilgrim / Guide Walker to player-chosen names.

INSERT INTO characters (name, title, class, current_hp, max_hp, coins_silver, road_xp, road_xp_max, location, is_player, notes)
VALUES ('Pilgrim', 'Walker on the Open Road', 'Mage', 13, 13, 4, 0, 10, 'Brindleford Forge', TRUE,
        'A mage on the road. The full vale arc lies ahead — forge, gang, mill, bridge.');

SET @player_id = (SELECT id FROM characters WHERE is_player = TRUE ORDER BY id LIMIT 1);

INSERT INTO characters (name, title, class, current_hp, max_hp, location, is_player, notes)
VALUES ('Guide Walker', 'Field-healer, trail archer, buckler fighter', 'Healer-Archer', 14, 14, 'Brindleford Forge', FALSE,
        'A provisional companion. The arc will test whether they choose to stay.');

SET @companion_id = (SELECT id FROM characters WHERE is_player = FALSE ORDER BY id LIMIT 1);

INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags) VALUES
(@player_id, 'ash_wood_buckler', 'Ash-Wood Buckler', 1, TRUE,
 'A practical buckler from the village forge.',
 'Passive Guard: reduce the first physical hit by 1 each round. Breathguard: once per battle, reduce one hit by 3.',
 'defensive,passive,breathguard'),
(@player_id, 'penitents_wrap', "Penitent's Wrap", 1, TRUE,
 'Once per battle, after damage, reduce by 2.',
 'Helps receive pain without panic.', 'defensive,once_per_battle'),
(@player_id, 'repair_bundle', 'Repair and Supply Bundle', 1, FALSE,
 'Oilcloth kit for field repairs.', 'Solve a minor practical problem once per travel day.', 'tool,craft'),
(@player_id, 'healing_potion', 'Healing Potion', 1, FALSE,
 'Restores 6 HP.', 'Standard healing draught.', 'consumable,healing'),
(@player_id, 'road_knife', 'Road Knife', 1, FALSE,
 'Mundane utility knife.', 'Practical tool.', 'tool'),
(@companion_id, 'sera_bow', 'Trail Bow', 1, TRUE, 'Companion bow.', 'Bow Shot: 3 damage.', 'weapon,companion'),
(@companion_id, 'sera_buckler', 'Buckler', 1, TRUE, 'Companion buckler.', 'Buckler Guard: reduce damage by 2 once per round.', 'defensive,companion');

INSERT INTO world_state (state_key, value) VALUES
('current_chapter', 'The Road of Bread and Iron'),
('arc_goal', 'Help Brindleford survive the Black Bridge Gang. Gain practical gear, supplies, XP, and earn your companion''s trust.'),
('black_bridge_gang_status', 'Rumors of a gang on Iron Bridge. No personal history yet.'),
('brindleford_preparedness', 'Low'),
('sera_trust', 'provisional'),
('last_major_event', 'You arrive at Brindleford Forge with your companion. The road opens.'),
('sera_trust_level', '20'),
('sera_bond_level', '15'),
('sera_joint_experiences', '0'),
('sera_leadership_moments', '0'),
('sera_last_action', ''),
('sera_recent_event', ''),
('game_initialized', 'public_arc_start'),
('mill_status', 'unexamined'),
('brindleford_food_supply', 'at_risk'),
('bridge_alert_level', 'low');

INSERT INTO character_abilities (character_id, ability_key, ability_name, uses_remaining, description) VALUES
(@player_id, 'zen_mage_firebolt', 'Improved Zen-Mage Firebolt', NULL,
 '6 damage. If it kills, heal overkill damage +1 (cannot exceed max HP).'),
(@player_id, 'penitents_wrap', "Penitent's Wrap", 1,
 'Once per battle: reduce incoming damage by 2.'),
(@player_id, 'ash_wood_breathguard', 'Breathguard (Ash-Wood Buckler)', 1,
 'Once per battle: reduce one incoming hit by 3 and gain +1 Focus on next action.');

UPDATE inventory SET slot = 'off_hand' WHERE character_id = @player_id AND item_key = 'ash_wood_buckler';

UPDATE characters c
JOIN locations l ON l.key_name = 'forge'
SET c.location_key = 'forge', c.location = l.display_name
WHERE c.id IN (@player_id, @companion_id);

UPDATE locations SET visited = TRUE WHERE key_name IN ('forge');

INSERT INTO session_log (log_type, entry, location, character_name)
VALUES ('SYSTEM', 'Arc start: Brindleford Forge. Full vale storyline available from the beginning.', 'Brindleford Forge', 'System');