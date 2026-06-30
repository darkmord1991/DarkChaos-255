-- AreaTrigger server rows for Plaguelands (trigger id +600000, matching the AreaTrigger.dbc client additions).
-- teleports keep their original destination; quest 'explore' triggers keep the (ported) quest id.
INSERT IGNORE INTO acore_world.areatrigger_teleport (ID,Name,target_map,target_position_x,target_position_y,target_position_z,target_orientation)
SELECT ID+600000, Name, target_map, target_position_x, target_position_y, target_position_z, target_orientation
FROM cata_world.areatrigger_teleport WHERE ID IN (45,178,610,612,614,708,2214,2216,2217,2413,2567,2647,2706,2707,3366,3367,4058,4294,4409,5127,5128,5129,5130,5131,5132,5133,5134,5135,5136,5137,5138,6213,6235,6237,6238,6243,6244,6249,6282,6300,6313,6314,6338,6339,6342,6343,6344,6466,6467);
INSERT IGNORE INTO acore_world.areatrigger_involvedrelation (id, quest)
SELECT id+600000, quest FROM cata_world.areatrigger_involvedrelation WHERE id IN (45,178,610,612,614,708,2214,2216,2217,2413,2567,2647,2706,2707,3366,3367,4058,4294,4409,5127,5128,5129,5130,5131,5132,5133,5134,5135,5136,5137,5138,6213,6235,6237,6238,6243,6244,6249,6282,6300,6313,6314,6338,6339,6342,6343,6344,6466,6467);
