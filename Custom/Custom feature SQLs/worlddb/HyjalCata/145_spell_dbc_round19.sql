-- ---------------------------------------------------------------------------
-- 145  Hyjal round-19 -- spell 97678 "Flame Cat Form" (+ its transform target)
-- ---------------------------------------------------------------------------
-- Boot log, fresh restart 2026-07-25:
--     SmartAIMgr: Entry 3654343 SourceType 0 Event 0 Action 11 uses non-existent
--     Spell entry 97678, skipped.
--
-- 3654343 "Druid of the Flame" had its SmartAI imported by 142_. Its first action
-- casts 97678, which resolves in NEITHER the built client Spell.dbc NOR
-- acore_world.spell_dbc, so SmartAIMgr throws that row away and the druid never
-- uses the ability. (Its other two casts, 17273 and 13878, are stock 3.3.5 ids
-- that resolve straight from the DBC file -- which is why the log names only this
-- one, and why checking `spell_dbc` alone is misleading: that table holds only
-- CUSTOM additions, not the stock spell set.)
--
-- Downported from the real Cata 4.3.4 client (Spell.dbc + SpellEffect.dbc out of
-- wow-update-base-15601.MPQ) by HyjalCata/tools/gen_hyjal_spell_downport_r19.py,
-- which reuses the proven r14-r17 field mapping unchanged.
--
-- THE PART THAT IS EASY TO MISS: 97678 is EffectAura 56 (SPELL_AURA_TRANSFORM),
-- and a transform aura's EffectMiscValue is the CREATURE ENTRY to morph into --
-- here Cata's 52836 "Flame Cat Form". Downporting the spell alone would have left
-- that pointing at an entry this DB does not have, so the druid would still never
-- change shape. The generator's MISC_REMAP therefore rewrites 52836 -> 3652836
-- (verified in the emitted row: EffectMiscValue_1 = 3652836), and this file
-- creates that clone below.
--
-- The clone's display is NOT the Cata original: 52836 uses CreatureDisplayInfo
-- 38150, which is absent from both the client CSV (28,027 rows) and the server
-- DBC, and downporting a new display would drag in a CreatureModelData row plus
-- the M2 asset for one cosmetic morph. Display **1058** is used instead -- the
-- stock "Cat Form (Tauren Druid)" / Mountain Lion display, already present and
-- already referenced by live creatures. The druid turns into a cat rather than a
-- *burning* cat; swapping in a real fire-cat display later is a one-row UPDATE.
--
-- The matching CLIENT row is appended to Custom/CSV DBC/Spell.csv and Spell.dbc
-- is recompiled + packed into patch-4.MPQ and enGB/patch-enGB-3.MPQ (same rule as
-- every other client DBC here -- enGB-3 outranks patch-4).
--
-- Idempotent. Needs a worldserver restart.
-- ---------------------------------------------------------------------------

DELETE FROM `spell_dbc` WHERE `ID` IN (97678);

INSERT INTO `spell_dbc` VALUES
('97678','0','0','0','536870912','1024','273154052','268632576','8388608','393216','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','0','0','0','18','0','0','0','0','0','3','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','-1','0','0','6','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','56','0','0','0','0','0','0','0','0','0','0','0','0','0','0','3652836','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','Flame Cat Form','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','16712190','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0');

-- ---- transform target: clone Cata 52836 "Flame Cat Form" -> 3652836 ---------
-- Column map = HyjalCata/29 (faction_A->faction, dmg_multiplier->DamageModifier,
-- Health_mod/Mana_mod/Armor_mod->*Modifier, speed_fly->speed_flight, LEAST(exp,2)),
-- identical to MoltenFront/01_. It is a pure morph shell: faction 35 (friendly),
-- rank 0, type 1 (Beast), no loot, no AI -- nothing ever spawns it, the aura only
-- reads its display.
INSERT IGNORE INTO acore_world.creature_template
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+3600000, 0, 0, name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, 0, 0, 0, PetSpellDataId, 0, 0, 0, '', MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template
WHERE entry = 52836;

-- Display 1058 = stock "Cat Form (Tauren Druid)"; Cata's own 38150 does not exist
-- on this client (see header). Guarded on the clone having been created.
DELETE FROM acore_world.creature_template_model WHERE `CreatureID` = 3652836;
INSERT INTO acore_world.creature_template_model
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 3652836, 0, 1058, 1, 1, 0
WHERE EXISTS (SELECT 1 FROM acore_world.creature_template WHERE `entry` = 3652836);
