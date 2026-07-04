-- 002_fresh_game.sql
-- Author Life-2 checkpoint: "Brindleford Forge" restart packet (local dev only).
-- Public terminal uses 003_public_terminal_fresh.sql via nerdverse_web_* session DBs.
-- Applied ONLY on first install or an explicit --fresh reset (see apply_migrations.sh).
-- Never run on routine play.sh / migration passes — it would overwrite a live save.

-- === MEYIU ===
INSERT INTO characters (name, title, class, current_hp, max_hp, coins_silver, road_xp, road_xp_max, location, is_player, notes)
VALUES ('Meyiu', 'The Sinner Who Still Chooses', 'Mage', 11, 13, 4, 5, 10, 'Brindleford Forge', TRUE,
        'Expanded: And Chooses What Is His To Carry | Beloved, Responsible, Unfinished, Still Becoming, Pilgrim of the Unfinished. Main attack: Firebolt 6. Improved Zen-Mage Firebolt 6 + overkill heal +1.');

SET @meyiu_id = (SELECT id FROM characters WHERE name = 'Meyiu' LIMIT 1);

-- === SERA THORNWAKE ===
INSERT INTO characters (name, title, class, current_hp, max_hp, location, is_player, notes)
VALUES ('Sera Thornwake', 'Field-healer, trail archer, buckler fighter', 'Healer-Archer', 14, 14, 'Brindleford Forge', FALSE,
        'Sharp because softness got people killed. Practical to a fault. Triage wound [5]. Dull edges [4] - learning acceptance from Meyiu [8 pull]. Chooses the journey herself. 70/30 lead. Bond via shared actions. Seeks light external on voids.');

SET @sera_id = (SELECT id FROM characters WHERE name = 'Sera Thornwake' LIMIT 1);

-- === MEYIU INVENTORY ===
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags) VALUES
(@meyiu_id, 'ashen_prayer_bead', 'Ashen Prayer Bead', 1, TRUE,
 'Focus anchor from the tower.',
 '+1 Focus on calm magical/spiritual control actions. Helps Zen-Mage Breathing, resisting fear, controlling fire, reading cursed inscriptions.',
 'passive,focus'),
(@meyiu_id, 'penitents_wrap', "Penitent's Wrap", 1, TRUE,
 'Once per battle, after damage, reduce by 2. Does not erase pain.',
 'Helps receive pain without panic.',
 'defensive,once_per_battle'),
(@meyiu_id, 'ash_wood_buckler', 'Ash-Wood Buckler', 1, TRUE,
 'Crafted at Brindleford Forge from ash wood, rusty spearhead, and cracked leather belt.',
 'Passive Guard: Once per round, reduce the first physical hit by 1. Breathguard: Once per battle, reduce one incoming hit by 3 and gain +1 Focus on next action.',
 'defensive,passive,breathguard'),
(@meyiu_id, 'healing_potion', 'Healing Potion', 1, FALSE,
 'Restores 6 HP.', 'Standard healing draught.', 'consumable,healing'),
(@meyiu_id, 'leechheart_pearl', 'Leechheart Pearl', 1, FALSE,
 'Restores 4 HP or can be used in a ritual involving blood, water, roots, or similar themes.',
 'From the Bloodroot Leech encounter.', 'consumable,ritual'),
(@meyiu_id, 'road_knife', 'Road Knife', 1, FALSE,
 'Mundane utility knife. Keep it.', 'Practical tool.', 'tool'),
(@meyiu_id, 'black_bridge_token', 'Black Bridge-Token', 1, FALSE,
 'Evidence tying the captured bandits to the Black Bridge Gang.',
 'Do not sell. Do not wave around near criminals unless deliberately.', 'evidence,quest'),
(@meyiu_id, 'cinder_nameplate', 'Cinder Nameplate', 1, FALSE,
 'Identity anchor. Reads: MEYIU -- THE SINNER WHO STILL CHOOSES',
 'Rejects false shame-names.', 'identity,story'),
(@meyiu_id, 'brazier_glass_shard', 'Black Brazier-Glass Shard', 1, FALSE,
 'Shame-mirror from the Ash Warden brazier.',
 'Passive: reveals shame/name/identity distortions. One-use active: Mirrorcut (cut palm lightly and spend 1 HP to reflect or reveal a curse).',
 'identity,one_use'),
(@meyiu_id, 'gray_blue_slip', 'Gray-Blue Question Slip', 1, FALSE,
 'Folded note from the WIFE drawer. "How can I make you feel less alone?"',
 'Useful against loneliness, unheard grief, or spirits whose real need is to be heard.', 'story,compassion'),
(@meyiu_id, 'white_quill_splinter', 'White Quill Splinter', 1, FALSE,
 'Broken splinter from the Scribe Without Ink.',
 'Once: amend a written curse, false label, or hostile record without erasing the truth beneath it.', 'story,truth'),
(@meyiu_id, 'repair_bundle', 'Repair and Supply Bundle', 1, FALSE,
 'Practical oilcloth kit: cord, tinder, needle, bandage cloth, whetstone, oilcloth wrap, small hook, waxed thread.',
 'Once per travel day: solve a minor practical problem without a shop (repair strap, patch cloak, start fire in wet weather, mend pack, rig alarm, support Campcraft, etc.).',
 'tool,craft,consumable');

-- === SERA GEAR ===
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags) VALUES
(@sera_id, 'sera_bow', 'Trail Bow', 1, TRUE, 'Sera''s bow.', 'Bow Shot: 3 damage.', 'weapon,companion'),
(@sera_id, 'sera_buckler', 'Buckler', 1, TRUE, 'Sera''s buckler.', 'Buckler Guard: reduce damage to self or ally by 2 once per round.', 'defensive,companion');

-- === WORLD STATE (story starting point) ===
INSERT INTO world_state (state_key, value) VALUES
('current_chapter', 'The Road of Bread and Iron'),
('arc_goal', 'Help Brindleford survive the Black Bridge Gang. Gain practical gear, supplies, XP, and possibly recruit Sera.'),
('black_bridge_gang_status', 'Expected retaliation by dusk or midnight after failed medicine theft.'),
('brindleford_preparedness', 'Low'),
('sera_trust', 'provisional'),
('last_major_event', 'Medicine cart ambush resolved. Three bandits captured alive. Medicine crate saved.'),
('sera_trust_level', '35'),
('sera_bond_level', '25'),
('sera_joint_experiences', '0'),
('sera_leadership_moments', '0'),
('sera_last_action', ''),
('sera_recent_event', ''),
('game_initialized', '1'),
('mill_status', 'unexamined'),
('brindleford_food_supply', 'at_risk'),
('bridge_alert_level', 'low');

-- === MEYIU ABILITIES ===
INSERT INTO character_abilities (character_id, ability_key, ability_name, uses_remaining, description) VALUES
(@meyiu_id, 'zen_mage_firebolt', 'Improved Zen-Mage Firebolt', NULL,
 '6 damage. If it kills, heal overkill damage +1 (cannot exceed max HP).'),
(@meyiu_id, 'penitents_wrap', "Penitent's Wrap", 1,
 'Once per battle: reduce incoming damage by 2.'),
(@meyiu_id, 'ash_wood_breathguard', 'Breathguard (Ash-Wood Buckler)', 1,
 'Once per battle: reduce one incoming hit by 3 and gain +1 Focus on next action.');

-- Equipment slots (requires migration 003_equipment)
UPDATE inventory SET slot = 'focus'    WHERE character_id = @meyiu_id AND item_key = 'ashen_prayer_bead';
UPDATE inventory SET slot = 'off_hand' WHERE character_id = @meyiu_id AND item_key = 'ash_wood_buckler';

-- Wire characters to the locations graph
UPDATE characters c
JOIN locations l ON l.key_name = 'forge'
SET c.location_key = 'forge', c.location = l.display_name
WHERE c.name IN ('Meyiu', 'Sera Thornwake');

-- Mark starting locations visited for the tutorial beat
UPDATE locations SET visited = TRUE WHERE key_name IN ('forge', 'sheriff');

-- === FIRST SYSTEM LOG ENTRY ===
INSERT INTO session_log (log_type, entry, location, character_name)
VALUES ('SYSTEM', 'Fresh game started. Meyiu at Brindleford Forge with 4 silver, Sera at his side. Road XP 5/10.', 'Brindleford Forge', 'System');