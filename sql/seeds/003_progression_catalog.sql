-- 003_progression_catalog.sql — idempotent combo + unlock catalog extensions

INSERT IGNORE INTO combo_recipes (combo_key, display_name, primer_key, followup_key, effect_summary, bonus_damage, narrative_flavor)
VALUES
('quiet_rally', 'Quiet Rally',
 'sera_triage_mark', 'zen_mage_firebolt',
 'Marked foe — bolt lands with surgical certainty.',
 2, 'Sera nods once. You do not miss.');