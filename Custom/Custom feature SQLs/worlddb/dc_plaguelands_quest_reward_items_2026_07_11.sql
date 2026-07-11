-- ---------------------------------------------------------------------------
-- item_template additions -- 5 missing Plaguelands quest reward-choice items
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-11): quest_template.RewardChoiceItemIDx
-- referenced these 5 item ids for 5 Plaguelands (map 751) quests, but none
-- existed in item_template (cata_world has no item_template table; nelt_world
-- lacks them too). Each is the 'neutral' reward-choice slot (ring/neck/cloak)
-- alongside the already-downported cloth/leather/plate/weapon choices for the
-- same quest. Sourced from the real retail client Item/ItemSparse CSVs; fields
-- (ItemLevel=0, RequiredLevel=1, Quality=2, no stats, bonding=0) mirror the
-- exact convention already used by every sibling reward item in this set.
-- Icon-only ItemDisplayInfo minted the same way (8,000,000 + IconFileDataID).
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (62156,62172,62192,62210,62214);

INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,
     `BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,
     `maxcount`,`stackable`,`ContainerSlots`,`bonding`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(62156,4,0,-1,'Grant''s Signet',8337102,2,0,0,1,0,0,11,-1,-1,0,1,0,1,0,0,3,0,0),
(62172,4,1,-1,'Forest Green Cloak',8133761,2,0,0,1,0,0,16,-1,-1,0,1,0,1,0,0,7,0,0),
(62192,4,0,-1,'Zen''Kiki''s Thanks',8133312,2,0,0,1,0,0,2,-1,-1,0,1,0,1,0,0,4,0,0),
(62210,4,0,-1,'Pack Leader''s Band',8133344,2,0,0,1,0,0,11,-1,-1,0,1,0,1,0,0,3,0,0),
(62214,4,0,-1,'Ring of Aces',8133375,2,0,0,1,0,0,11,-1,-1,0,1,0,1,0,0,3,0,0);
