-- ---------------------------------------------------------------------------
-- 138  Hyjal round-18 -- 3 displays that can crash the client
-- ---------------------------------------------------------------------------
--     Creature (Entry: 3653163) lists non-existing CreatureDisplayID id
--     (37295), this can crash the client.        (+ 3653354/34581, 3652990/37729)
--     Creature (Entry: 3653163) does not have any existing display id in
--     creature_template_model.
--
-- Also self-inflicted by 126_: it imported the summon/transform target
-- creatures with their nelt display ids, and three of those displays are not in
-- the built CreatureDisplayInfo.dbc.  128_ gave them `creature_model_info` rows,
-- but that is the *other* gate -- ObjectMgr::LoadCreatureTemplateModels drops a
-- model row whose display id is absent from the DBC itself, which is why 3653163
-- and 3653354 end up with no usable model at all.
--
-- Two of the three need no asset work:
--   34581 -> CREATURE\INVISIBLESTALKER\INVISIBLESTALKER.M2 @ scale 2.0
--   37295 -> the same model @ scale 1.0
-- InvisibleStalker is stock 3.3.5 (CreatureModelData 1731, already used by
-- display 11686 among others), so these are pure DBC rows, appended to
-- Custom/CSV DBC/CreatureDisplayInfo.csv by this round.  Both creatures are
-- invisible helper bunnies ("Rope", "Escape Winds"), so the model is right.
--
-- The third is different: 37729 is
-- CREATURE\EPICDRUIDFLIGHTWORGEN\EPICDRUIDFLIGHTWORGEN.M2 -- a Cata-only worgen
-- druid flight form with no 3.3.5 equivalent, so it would need a real model
-- bake.  It is model slot 2 of 3652990 "Captured Hyjal Druid", whose other two
-- slots (21243 / 21244) are valid stock displays, so the cheap correct fix is
-- to drop the unusable slot rather than invent a substitute: the creature keeps
-- two working appearances and the crash risk goes away.  Revisit if the worgen
-- flight form is ever baked.
-- ---------------------------------------------------------------------------

DELETE FROM `creature_template_model`
WHERE `CreatureID` = 3652990 AND `CreatureDisplayID` = 37729;

-- Re-index the surviving slots so Idx stays contiguous from 0 (ChooseDisplayId
-- walks the vector, so a hole is harmless, but keeping it tidy avoids surprises
-- if the rows are ever re-read positionally).
UPDATE `creature_template_model` SET `Idx` = 0
WHERE `CreatureID` = 3652990 AND `CreatureDisplayID` = 21243;
UPDATE `creature_template_model` SET `Idx` = 1
WHERE `CreatureID` = 3652990 AND `CreatureDisplayID` = 21244;

-- ---------------------------------------------------------------------------
-- CLIENT PREREQUISITE for 34581 / 37295: rows appended to
-- Custom/CSV DBC/CreatureDisplayInfo.csv this round --
--     34581, model 1731 (InvisibleStalker), scale 2.0
--     37295, model 1731 (InvisibleStalker), scale 1.0
-- Needs a CreatureDisplayInfo.dbc recompile + deploy (server side too: the
-- `creaturedisplayinfo_dbc` SQL table is empty on this fork, so the server reads
-- the file).  Until that lands, 3653163 / 3653354 stay unspawnable -- but they
-- are summon-only helpers, so nothing else breaks in the meantime.
-- ---------------------------------------------------------------------------
