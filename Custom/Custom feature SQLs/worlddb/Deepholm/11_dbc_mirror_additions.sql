-- Deepholm Downport: acore_dbc mirror additions (server-side DBC overrides)
-- Merged into the server's DBC stores via DBCStorage::LoadFromDB().
-- The CLIENT gets identical data through CSV -> WDBX -> .dbc -> MPQ patch.

-- faction_dbc: parent factions the new FactionTemplates point at
-- (1128 Twilight's Hammer, 1135 Earthen Ring, 1158 Guardians of Hyjal, 1162 Cataclysm, 1171 Therazane)
INSERT IGNORE INTO `faction_dbc` (`ID`,`ReputationIndex`,`ReputationRaceMask_1`,`ReputationRaceMask_2`,`ReputationRaceMask_3`,`ReputationRaceMask_4`,`ReputationClassMask_1`,`ReputationClassMask_2`,`ReputationClassMask_3`,`ReputationClassMask_4`,`ReputationBase_1`,`ReputationBase_2`,`ReputationBase_3`,`ReputationBase_4`,`ReputationFlags_1`,`ReputationFlags_2`,`ReputationFlags_3`,`ReputationFlags_4`,`ParentFactionID`,`ParentFactionMod_1`,`ParentFactionMod_2`,`ParentFactionCap_1`,`ParentFactionCap_2`,`Name_Lang_enUS`,`Name_Lang_Mask`) VALUES
(1128,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1.0,1.0,5,5,'Twilight''s Hammer',16712190),
(1135,110,-1,0,0,0,0,0,0,0,0,0,0,0,16,0,0,0,1162,0.0,0.0,5,5,'The Earthen Ring',16712190),
(1158,113,-1,0,0,0,0,0,0,0,0,0,0,0,16,0,0,0,1162,0.0,0.0,0,0,'Guardians of Hyjal',16712190),
(1162,111,-1,0,0,0,0,0,0,0,0,0,0,0,4104,0,0,0,0,0.0,0.0,0,0,'Cataclysm',16712190),
(1171,116,-1,0,0,0,0,0,0,0,-42000,0,0,0,64,0,0,0,1162,0.0,0.0,0,0,'Therazane',16712190);

-- factiontemplate_dbc (WotLK MAX_FACTION_RELATIONS=4)
INSERT IGNORE INTO `factiontemplate_dbc` (`ID`,`Faction`,`Flags`,`FactionGroup`,`FriendGroup`,`EnemyGroup`,`Enemies_1`,`Enemies_2`,`Enemies_3`,`Enemies_4`,`Friend_1`,`Friend_2`,`Friend_3`,`Friend_4`) VALUES
(2146,1128,1,8,0,1,0,0,0,0,1128,0,0,0),
(2147,1128,0,8,0,1,0,0,0,0,1128,0,0,0),
(2167,1135,0,0,0,0,0,0,0,0,1135,0,0,0),
(2168,1135,257,0,0,0,0,0,0,0,1135,0,0,0),
(2232,74,33,8,0,1,1158,0,0,0,74,1128,0,0),
(2244,959,260,0,1,0,960,0,0,0,959,0,0,0),
(2256,1135,288,0,0,0,14,0,0,0,1135,0,0,0),
(2257,14,144,8,0,1,1135,0,0,0,14,0,0,0),
(2263,959,36,0,1,0,960,0,0,0,959,0,0,0),
(2281,1171,0,0,0,0,0,0,0,0,1171,0,0,0),
(2282,1171,1,0,0,0,0,0,0,0,1171,0,0,0),
(2283,1171,32,0,0,0,14,0,0,0,1171,0,0,0),
(2284,1171,33,0,0,0,0,0,0,0,1171,0,0,0),
(2285,1171,32,0,0,0,1128,0,0,0,1171,0,0,0),
(2286,1171,33,0,0,0,1128,0,0,0,1171,0,0,0),
(2288,1171,32,0,0,0,1135,0,0,0,1171,0,0,0),
(2289,1135,288,0,0,0,1171,0,0,0,1135,0,0,0),
(2290,1135,289,0,0,0,1171,0,0,0,1135,0,0,0),
(2291,1128,32,8,0,1,1171,1135,0,0,74,1128,0,0),
(2292,1128,33,8,0,1,1171,1135,0,0,74,1128,0,0),
(2297,1128,32,8,0,1,14,0,0,0,1128,0,0,0),
(2298,14,144,8,0,1,1128,0,0,0,14,0,0,0),
(2312,32,33,8,0,1,1171,0,0,0,32,0,0,0),
(2318,1135,289,0,0,0,1128,0,0,0,1135,0,0,0);

-- lock_dbc
INSERT IGNORE INTO `lock_dbc` (`ID`,`Type_1`,`Type_2`,`Type_3`,`Type_4`,`Type_5`,`Type_6`,`Type_7`,`Type_8`,`Index_1`,`Index_2`,`Index_3`,`Index_4`,`Index_5`,`Index_6`,`Index_7`,`Index_8`,`Skill_1`,`Skill_2`,`Skill_3`,`Skill_4`,`Skill_5`,`Skill_6`,`Skill_7`,`Skill_8`,`Action_1`,`Action_2`,`Action_3`,`Action_4`,`Action_5`,`Action_6`,`Action_7`,`Action_8`) VALUES
(1852,0,2,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(1861,2,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,425,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(1863,2,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,475,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(1864,2,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,450,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(1865,2,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,500,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(1866,2,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,475,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(1932,1,0,0,0,0,0,0,0,60739,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0);

-- spellfocusobject_dbc
INSERT IGNORE INTO `spellfocusobject_dbc` (`ID`,`Name_Lang_enUS`,`Name_Lang_Mask`) VALUES
(1678,'Pale Resonating Crystal',16712190),
(1680,'Stonescale Matriarch''s feeding grounds',16712190),
(1681,'Center of Abyssion''s Lair',16712190);
