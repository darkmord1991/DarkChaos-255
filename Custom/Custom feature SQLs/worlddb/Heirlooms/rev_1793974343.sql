-- Frontier heirlooms (tier 10) have stat enchants for levels 1-5 only
-- (SpellItemEnchantment 920000 + package*100 + level), as the tier's own
-- description says, but max_upgrade_level was 15. The server now clamps the
-- level to the enchants that exist, so this only makes the tier row agree.
UPDATE `dc_item_upgrade_tiers` SET `max_upgrade_level` = 5 WHERE `tier_id` = 10 AND `max_upgrade_level` > 5;
