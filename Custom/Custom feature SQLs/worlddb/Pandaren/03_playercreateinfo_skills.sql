-- Pandaren: skill coverage for races 22/23.
-- Unlike Worgoblin there is no 3.3.5 "Racial - Pandaren" skill-line stub to grant,
-- and no per-class weapon-skill gap to patch. The one structural need: any skill row
-- gated to BOTH base factions (human bit 1 AND orc bit 2 set) must also admit the
-- two pandaren rows, mirroring the "class spells = human INTERSECT orc" rule in 04.
-- raceMask = 0 rows mean all races and need nothing. Idempotent (bitwise OR).
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 6291456
WHERE (`raceMask` & 1) AND (`raceMask` & 2);
