-- Dark Chaos Guild Housing - Per-decoration visual scale
-- Adds a persisted scale (OBJECT_FIELD_SCALE_X) to each placed decoration so
-- the Noggit-style editor's scale control survives a server restart. The core
-- `gameobject` spawn has no scale column, so scale is tracked here and
-- re-applied on world-add (see GuildHouseDecorationScaleScript).
-- Table: dc_guildhouse_decoration_instances

ALTER TABLE `dc_guildhouse_decoration_instances`
    ADD COLUMN `scale` FLOAT NOT NULL DEFAULT 1.0 AFTER `paid_copper`;

UPDATE `dc_guildhouse_decoration_instances`
SET `scale` = 1.0
WHERE `scale` IS NULL OR `scale` <= 0;
