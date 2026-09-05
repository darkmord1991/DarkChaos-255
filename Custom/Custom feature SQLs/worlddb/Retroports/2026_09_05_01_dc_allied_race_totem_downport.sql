-- =====================================================================================
-- Allied-race totem art downport (BfA -> 3.3.5), 2026-09-05
--
-- Downported from retail 12.1.0 CASC:
--   world/expansion07/doodads/zandalaritroll/8tr_zandalari_totem_{fire,earth,water,air}.m2
--   world/expansion07/doodads/vulpera/8vp_vulpera_shaman_totem{01..04}.m2
--   world/expansion07/doodads/human/8hu_kultiras_totem_{fire,earth,water,air}.m2
--   world/expansion07/doodads/darkiron/8dw_darkiron_totem_{fire,earth,water,air}.m2
--
-- Retail paths are preserved, so the assets deploy to patch-8 (WORLD role) per
-- dc_mpq_layout.dest_for(). 16 models + 30 skins + 103 textures.
--
-- Vulpera's models are numbered, not element-named. The element mapping was read off
-- the base textures and cross-checked against the Zandalari set (which IS element-named)
-- to confirm the colour convention: orange=fire, green=earth, blue=water, pale cyan=air.
--   totem01 = fire, totem02 = water, totem03 = earth, totem04 = air
--
-- DBC ids (CreatureModelData 505034-505049, CreatureDisplayInfo 505135-505150) are added
-- by the CSV/DBC half of this change, not by this file.
-- =====================================================================================

-- The per-race assignment (`player_totem_model`) ships separately in
-- data/sql/updates/pending_db_world/rev_1757088000000000000.sql, because that table is
-- stock AzerothCore and belongs in the migration chain. `dc_shapeshift_form_skins` is a
-- DC table created by Custom/.../CollectionSystem/rev_1781473174411445000.sql, so its
-- rows stay here where that table is guaranteed to exist.

-- -------------------------------------------------------------------------------------
-- Forms wardrobe entries (dc_shapeshift_form_skins, form 240-243 = fire/earth/water/air)
--
-- race = 0 means "offered to every race", matching how the existing totem skins are
-- registered. sort_order continues each form's existing sequence.
-- -------------------------------------------------------------------------------------

DELETE FROM `dc_shapeshift_form_skins` WHERE `form` BETWEEN 240 AND 243 AND `model` BETWEEN 505135 AND 505150;
INSERT INTO `dc_shapeshift_form_skins` (`form`, `race`, `model`, `name`, `sort_order`, `is_default`) VALUES
-- Fire (240)
(240, 0, 505135, 'Zandalari Fire Totem', 114, 0),
(240, 0, 505139, 'Vulpera Fire Totem', 115, 0),
(240, 0, 505143, 'Kul Tiran Fire Totem', 116, 0),
(240, 0, 505147, 'Dark Iron Fire Totem', 117, 0),
-- Earth (241)
(241, 0, 505136, 'Zandalari Earth Totem', 111, 0),
(241, 0, 505140, 'Vulpera Earth Totem', 112, 0),
(241, 0, 505144, 'Kul Tiran Earth Totem', 113, 0),
(241, 0, 505148, 'Dark Iron Earth Totem', 114, 0),
-- Water (242)
(242, 0, 505137, 'Zandalari Water Totem', 114, 0),
(242, 0, 505141, 'Vulpera Water Totem', 115, 0),
(242, 0, 505145, 'Kul Tiran Water Totem', 116, 0),
(242, 0, 505149, 'Dark Iron Water Totem', 117, 0),
-- Air (243)
(243, 0, 505138, 'Zandalari Air Totem', 112, 0),
(243, 0, 505142, 'Vulpera Air Totem', 113, 0),
(243, 0, 505146, 'Kul Tiran Air Totem', 114, 0),
(243, 0, 505150, 'Dark Iron Air Totem', 115, 0);
