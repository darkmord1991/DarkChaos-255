-- AreaTrigger server rows for HyjalCata (trigger id +600000, matching the AreaTrigger.dbc client additions).
-- teleports keep their original destination; quest 'explore' triggers keep the (ported) quest id.
INSERT IGNORE INTO acore_world.areatrigger_teleport (ID,Name,target_map,target_position_x,target_position_y,target_position_z,target_orientation)
SELECT ID+600000, Name, target_map, target_position_x, target_position_y, target_position_z, target_orientation
FROM cata_world.areatrigger_teleport WHERE ID IN (2206,2207,2208,2211,2213,2287,2327,3586,3587,4015,4085,4666,4667,4673,5450,5451,5518,5606,5610,5796,5797,5798,5799,5800,5876,5879,5880,5893,5894,5895,5931,5933,5934,5935,5936,5937,6039,6055,6056,6058,6059,6068,6071,6078,6103,6129,6130,6215,6463,6505,6510,6515,6516,6519,6630,6710,6800,6801,6802,6809,6864);
INSERT IGNORE INTO acore_world.areatrigger_involvedrelation (id, quest)
SELECT id+600000, quest FROM cata_world.areatrigger_involvedrelation WHERE id IN (2206,2207,2208,2211,2213,2287,2327,3586,3587,4015,4085,4666,4667,4673,5450,5451,5518,5606,5610,5796,5797,5798,5799,5800,5876,5879,5880,5893,5894,5895,5931,5933,5934,5935,5936,5937,6039,6055,6056,6058,6059,6068,6071,6078,6103,6129,6130,6215,6463,6505,6510,6515,6516,6519,6630,6710,6800,6801,6802,6809,6864);
