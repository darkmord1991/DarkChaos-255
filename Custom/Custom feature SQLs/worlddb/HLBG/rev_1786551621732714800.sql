-- Hinterland BG: turn Thrall (810002) and Varian (810003) into real faction bosses.
-- The C++ AI lives in src/server/scripts/DC/HinterlandBG/hlbg_faction_boss.h and is
-- already bound via ScriptName; these rows only clean up template state that
-- contradicts the new behaviour.

-- Varian carried AIName = 'NullCreatureAI'. ScriptName currently wins in
-- FactorySelector::SelectAI, so this was inert - but it would silently disable the
-- boss the moment ScriptName were cleared. Thrall already has an empty AIName.
UPDATE `creature_template` SET `AIName` = '' WHERE `entry` = 810003;

-- Thrall carried npcflag 1 (GOSSIP) for the old lore-event menu, which no longer
-- exists. A boss should not offer a chat bubble; Varian is already npcflag 0.
UPDATE `creature_template` SET `npcflag` = 0 WHERE `entry` = 810002;

-- Both bosses are repeatable battleground objectives, so neither should award XP.
-- Varian already had flags_extra 2 (CREATURE_FLAG_EXTRA_NO_XP); match Thrall to it.
UPDATE `creature_template` SET `flags_extra` = `flags_extra` | 2 WHERE `entry` = 810002;
