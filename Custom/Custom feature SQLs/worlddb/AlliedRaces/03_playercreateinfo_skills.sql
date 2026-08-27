-- Allied races: skill rows gated to BOTH base factions must admit the new races too
-- (same rule as the pandaren port; raceMask = 0 means all races and needs nothing).
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 58720256
WHERE (`raceMask` & 1) AND (`raceMask` & 2);
