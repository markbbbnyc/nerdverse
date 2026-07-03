-- 001_initial_state.sql
-- Exact reproduction of the "Brindleford Forge Save Point" from the restart packet.
-- Uses INSERT ... ON DUPLICATE KEY UPDATE so it is idempotent / safe to re-apply.

-- === MEYIU ===
INSERT INTO characters (name, title, class, current_hp, max_hp, coins_silver, road_xp, road_xp_max, location, is_player, notes)
VALUES ('Meyiu', 'The Sinner Who Still Chooses', 'Mage', 11, 13, 4, 5, 10, 'Brindleford Forge', TRUE,
        'Expanded: And Chooses What Is His To Carry | Beloved, Responsible, Unfinished, Still Becoming, Pilgrim of the Unfinished. Main attack: Firebolt 6. Improved Zen-Mage Firebolt 6 + overkill heal +1.')
ON DUPLICATE KEY UPDATE
    current_hp = VALUES(current_hp),
    coins_silver = VALUES(coins_silver),
    road_xp = VALUES(road_xp),
    location = VALUES(location),
    notes = VALUES(notes);

-- Get the character id (works in both fresh and re-seed)
SET @meyiu_id = (SELECT id FROM characters WHERE name = 'Meyiu' LIMIT 1);

-- === SERA THORNWAKE (companion prospect) ===
INSERT INTO characters (name, title, class, current_hp, max_hp, location, is_player, notes)
VALUES ('Sera Thornwake', 'Field-healer, trail archer, buckler fighter', 'Healer-Archer', 14, 14, 'Brindleford Forge', FALSE,
        'Provisional trust. May join permanently if Brindleford survives. Sharp-tongued, practical, protective. Controls the medicine room.')
ON DUPLICATE KEY UPDATE
    current_hp = VALUES(current_hp),
    location = VALUES(location),
    notes = VALUES(notes);

SET @sera_id = (SELECT id FROM characters WHERE name = 'Sera Thornwake' LIMIT 1);

-- === MEYIU INVENTORY & EQUIPPED ===
-- Ashen Prayer Bead
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'ashen_prayer_bead', 'Ashen Prayer Bead', 1, TRUE,
        'Focus anchor from the tower.',
        '+1 Focus on calm magical/spiritual control actions. Helps Zen-Mage Breathing, resisting fear, controlling fire, reading cursed inscriptions.',
        'passive,focus')
ON DUPLICATE KEY UPDATE equipped=VALUES(equipped), description=VALUES(description), effect=VALUES(effect);

-- Penitent's Wrap
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'penitents_wrap', "Penitent's Wrap", 1, TRUE,
        'Once per battle, after damage, reduce by 2. Does not erase pain.',
        'Helps receive pain without panic.',
        'defensive,once_per_battle')
ON DUPLICATE KEY UPDATE equipped=VALUES(equipped);

-- Ash-Wood Buckler (just purchased)
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'ash_wood_buckler', 'Ash-Wood Buckler', 1, TRUE,
        'Crafted at Brindleford Forge from ash wood, rusty spearhead, and cracked leather belt.',
        'Passive Guard: Once per round, reduce the first physical hit by 1. Breathguard: Once per battle, reduce one incoming hit by 3 and gain +1 Focus on next action.',
        'defensive,passive,breathguard')
ON DUPLICATE KEY UPDATE equipped=VALUES(equipped), description=VALUES(description), effect=VALUES(effect);

-- Healing Potion
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'healing_potion', 'Healing Potion', 1, FALSE,
        'Restores 6 HP.',
        'Standard healing draught.',
        'consumable,healing')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- Leechheart Pearl
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'leechheart_pearl', 'Leechheart Pearl', 1, FALSE,
        'Restores 4 HP or can be used in a ritual involving blood, water, roots, or similar themes.',
        'From the Bloodroot Leech encounter.',
        'consumable,ritual')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- Road Knife
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'road_knife', 'Road Knife', 1, FALSE,
        'Mundane utility knife. Keep it.',
        'Practical tool.',
        'tool')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- Black Bridge-Token
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'black_bridge_token', 'Black Bridge-Token', 1, FALSE,
        'Evidence tying the captured bandits to the Black Bridge Gang.',
        'Do not sell. Do not wave around near criminals unless deliberately.',
        'evidence,quest')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- Cinder Nameplate
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'cinder_nameplate', 'Cinder Nameplate', 1, FALSE,
        'Identity anchor. Reads: MEYIU -- THE SINNER WHO STILL CHOOSES',
        'Rejects false shame-names.',
        'identity,story')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- Black Brazier-Glass Shard
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'brazier_glass_shard', 'Black Brazier-Glass Shard', 1, FALSE,
        'Shame-mirror from the Ash Warden brazier.',
        'Passive: reveals shame/name/identity distortions. One-use active: Mirrorcut (cut palm lightly and spend 1 HP to reflect or reveal a curse).',
        'identity,one_use')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- Gray-Blue Question Slip
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'gray_blue_slip', 'Gray-Blue Question Slip', 1, FALSE,
        'Folded note from the WIFE drawer. "How can I make you feel less alone?"',
        'Useful against loneliness, unheard grief, or spirits whose real need is to be heard.',
        'story,compassion')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- White Quill Splinter
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'white_quill_splinter', 'White Quill Splinter', 1, FALSE,
        'Broken splinter from the Scribe Without Ink.',
        'Once: amend a written curse, false label, or hostile record without erasing the truth beneath it.',
        'story,truth')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- Repair and Supply Bundle (just bought)
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@meyiu_id, 'repair_bundle', 'Repair and Supply Bundle', 1, FALSE,
        'Practical oilcloth kit: cord, tinder, needle, bandage cloth, whetstone, oilcloth wrap, small hook, waxed thread.',
        'Once per travel day: solve a minor practical problem without a shop (repair strap, patch cloak, start fire in wet weather, mend pack, rig alarm, support Campcraft, etc.).',
        'tool,craft,consumable')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- === SERA'S BASIC GEAR (for reference / future companion system) ===
INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@sera_id, 'sera_bow', 'Trail Bow', 1, TRUE,
        'Sera''s bow.',
        'Bow Shot: 3 damage.',
        'weapon,companion')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

INSERT INTO inventory (character_id, item_key, item_name, quantity, equipped, description, effect, tags)
VALUES (@sera_id, 'sera_buckler', 'Buckler', 1, TRUE,
        'Sera''s buckler.',
        'Buckler Guard: reduce damage to self or ally by 2 once per round.',
        'defensive,companion')
ON DUPLICATE KEY UPDATE quantity=VALUES(quantity);

-- === WORLD STATE ===
INSERT INTO world_state (state_key, value) VALUES
('current_chapter', 'The Road of Bread and Iron'),
('arc_goal', 'Help Brindleford survive the Black Bridge Gang. Gain practical gear, supplies, XP, and possibly recruit Sera.'),
('black_bridge_gang_status', 'Expected retaliation by dusk or midnight after failed medicine theft.'),
('brindleford_preparedness', 'Low'),
('sera_trust', 'provisional'),
('last_major_event', 'Medicine cart ambush resolved. Three bandits captured alive. Medicine crate saved.')
ON DUPLICATE KEY UPDATE value=VALUES(value);

-- === INITIAL ABILITIES / PASSIVES FOR MEYIU ===
INSERT INTO character_abilities (character_id, ability_key, ability_name, uses_remaining, description)
VALUES (@meyiu_id, 'zen_mage_firebolt', 'Improved Zen-Mage Firebolt', NULL,
        '6 damage. If it kills, heal overkill damage +1 (cannot exceed max HP).')
ON DUPLICATE KEY UPDATE description=VALUES(description);

INSERT INTO character_abilities (character_id, ability_key, ability_name, uses_remaining, description)
VALUES (@meyiu_id, 'penitents_wrap', "Penitent's Wrap", 1,
        'Once per battle: reduce incoming damage by 2.')
ON DUPLICATE KEY UPDATE uses_remaining=1;

INSERT INTO character_abilities (character_id, ability_key, ability_name, uses_remaining, description)
VALUES (@meyiu_id, 'ash_wood_breathguard', 'Breathguard (Ash-Wood Buckler)', 1,
        'Once per battle: reduce one incoming hit by 3 and gain +1 Focus on next action.')
ON DUPLICATE KEY UPDATE uses_remaining=1;

-- === LOCATIONS (initial Brindleford map) ===
INSERT INTO locations (key_name, display_name, description, connected_to, danger_level, visited)
VALUES
('forge', 'Cold Forge (Old Brenn)', 'The forge where Meyiu just bought the Ash-Wood Buckler and repair bundle. Old Brenn is injured.', 'inn,sheriff,medicine', 1, TRUE),
('medicine', 'Sera''s Medicine Room', 'Where the recovered medicine crate is stored. Sera controls supplies and will criticize waste.', 'forge,sheriff', 0, FALSE),
('sheriff', 'Sheriff Marn''s Office', 'Tired but armed. Can muster a few villagers. Bandit interrogation and village defense planning happen here.', 'forge,medicine,inn', 1, TRUE),
('inn', 'Hearthmouse Inn', 'Food, rest, rumors, lodging. Meyiu has a meal and lodging token from Sheriff Marn.', 'sheriff,forge', 0, FALSE),
('mill', 'The Old Mill', 'Food supply threat. Wheel turns too slowly. Possible rot, sabotage, or other problem.', 'medicine', 2, FALSE),
('bridge', 'Iron Bridge / Gang Tollhouse', 'Black Bridge Gang base. 9-12 fighters led by Garran Pike. Champion: Toll-Saint.', 'mill', 5, FALSE)
ON DUPLICATE KEY UPDATE display_name=VALUES(display_name), description=VALUES(description);

-- === FIRST SYSTEM LOG ENTRY (bootstrap) ===
INSERT INTO session_log (log_type, entry, location, character_name)
VALUES ('SYSTEM', 'Phase 0 bootstrap complete. Current save loaded from restart packet: Meyiu at Brindleford Forge with 4 silver, Sera at his side. Road XP 5/10.', 'Brindleford Forge', 'System');
