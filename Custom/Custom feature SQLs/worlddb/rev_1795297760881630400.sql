-- DarkChaos spell charges
-- Used by: src/server/scripts/DC/AddonExtension/dc_addon_spellcharges.cpp
--
-- One row per player spell that holds several charges instead of a single
-- cooldown. Every cast spends a charge; charges come back one at a time, each
-- after rechargeMs. The spell is only on cooldown while no charge is left.
-- The native client shows the count from SMSG_DC_SPELL_CHARGES (capability
-- SPELL_CHARGES_NATIVE); other clients see the cooldown cleared while a charge
-- is left and a cooldown until the next charge at zero.
--
-- rechargeMs: 0 = the spell's own RecoveryTime, else its CategoryRecoveryTime.
-- The table ships empty.

CREATE TABLE IF NOT EXISTS `dc_spell_charges` (
  `spellId` INT UNSIGNED NOT NULL,
  `maxCharges` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `rechargeMs` INT UNSIGNED NOT NULL DEFAULT 0,
  `comment` VARCHAR(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`spellId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos: player spells with charges';
