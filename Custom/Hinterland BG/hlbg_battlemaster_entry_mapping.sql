-- HLBG battlemaster mappings
-- Battleground template ID 20 is reserved for Hinterland Battleground in Custom/CSV DBC/BattlemasterList.csv.
-- This maps selected standard battlemasters and the custom HLBG NPC to HLBG.

REPLACE INTO `battlemaster_entry` (`entry`, `bg_template`) VALUES
(900001, 20), -- Custom HLBG battlemaster
(34955, 20), -- Random BG Battlemaster (Horde)
(35008, 20); -- Random BG Battlemaster (Alliance)
