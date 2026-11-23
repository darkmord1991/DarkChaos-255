-- DC maps 750/751: graveyard links for the zones split out of Azshara, Ashenvale and Arathi (2026-11-22).
-- Each new zone uses the graveyards of the zone it was part of, so deaths there resolve exactly as before.
DELETE FROM `graveyard_zone` WHERE `GhostZone` = 16819;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) SELECT `ID`, 16819, `Faction`, 'Durotar (80-90) (split from zone 4930)' FROM `graveyard_zone` WHERE `GhostZone` = 4930;
DELETE FROM `graveyard_zone` WHERE `GhostZone` = 16833;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) SELECT `ID`, 16833, `Faction`, 'Orgrimmar (80-90) (split from zone 4930)' FROM `graveyard_zone` WHERE `GhostZone` = 4930;
DELETE FROM `graveyard_zone` WHERE `GhostZone` = 16841;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) SELECT `ID`, 16841, `Faction`, 'Northern Barrens (88-98) (split from zone 4931)' FROM `graveyard_zone` WHERE `GhostZone` = 4931;
DELETE FROM `graveyard_zone` WHERE `GhostZone` = 16849;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) SELECT `ID`, 16849, `Faction`, 'Stonetalon Mountains (88-98) (split from zone 4931)' FROM `graveyard_zone` WHERE `GhostZone` = 4931;
DELETE FROM `graveyard_zone` WHERE `GhostZone` = 16858;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) SELECT `ID`, 16858, `Faction`, 'Wetlands (142-147) (split from zone 4938)' FROM `graveyard_zone` WHERE `GhostZone` = 4938;
DELETE FROM `graveyard_zone` WHERE `GhostZone` = 16859;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) SELECT `ID`, 16859, `Faction`, 'Twilight Highlands (142-147) (split from zone 4938)' FROM `graveyard_zone` WHERE `GhostZone` = 4938;
