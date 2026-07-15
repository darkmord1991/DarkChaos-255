-- ============================================================================
-- DC Beastmaster - "secret" hunter pets wiring (batch 2)
-- ============================================================================
-- Cross-referenced the Wowhead Secret Hunter Pets Guide against the Cataclysm
-- TrinityCore world DB (cata_world) and the DC client. Result: the MODELS +
-- CreatureDisplayInfo rows for these Cata challenge tames are ALREADY in the DC
-- client (firespider/owlghost/deepseacrab/spectraltiger/chimerabeast/... were
-- downported earlier), and the SetCreatureDisplay native (2026-07-15) now renders
-- them textured. So "missing downports" = missing catalog wiring, not missing art.
--
-- This file adds the two secret pets that already have a creature_template + a
-- valid display in the world DB but were not yet adoptable:
--   Chimaeron (43296)  display 33308 (chimerabeast) -> Chimaera (exotic hydra look)
--   Oondasta  (400100) display 500234 (devilsaur)   -> Devilsaur (exotic)
-- Both are family 0 as imported, which the adopt handler rejects (family 0 crashes
-- Player::CreatePet), so set a valid pet family + tameable/exotic flags first.
--
-- Already wired + rendering via the native (no action needed): Ankha, Ban'thalos,
-- Deth'tilac, Horridon, Magria, Thok the Bloodthirsty.
-- ============================================================================

-- --- Chimaeron: map the hydra to the Chimaera family (exotic; closest 3.3.5 look)
UPDATE `creature_template`
SET `family` = 38, `type` = 1, `type_flags` = `type_flags` | 0x10001
WHERE `entry` = 43296;

-- --- Oondasta: Devilsaur family (exotic)
UPDATE `creature_template`
SET `family` = 39, `type` = 1, `type_flags` = `type_flags` | 0x10001
WHERE `entry` = 400100;

-- --- Add to the Beastmaster catalog -----------------------------------------
DELETE FROM `dc_beastmaster_pets` WHERE `creature_id` IN (43296, 400100);
INSERT INTO `dc_beastmaster_pets`
    (`creature_id`, `category`, `rarity`, `source_text`, `sort_order`, `enabled`) VALUES
    (43296,  'Chimaera',  4, 'Blackwing Descent (secret tame)', 3010, 1),
    (400100, 'Devilsaur', 4, 'Isle of Giants (secret tame)',    3011, 1);
