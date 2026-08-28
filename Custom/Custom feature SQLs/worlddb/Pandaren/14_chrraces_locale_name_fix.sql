-- Pandaren (22/23): clear the locale name slots inherited from the worgen donor row.
--
-- Rows 22/23 were cloned from race 12 and only Name_Lang_enUS was overwritten, so every other
-- locale still said "Worgen" -- in Korean, Chinese, Russian and Spanish -- and the generator wrote
-- those bytes through the wrong codec on top of it. An enGB client reads slot enUS and never sees
-- them; a deDE or ruRU client would show Pandaren as Worgen.
--
-- Blanked rather than translated, matching races 24/25/26, which ship enUS only and display fine.
-- 11_dbc_overlay.sql is already corrected, so a fresh apply_all needs none of this; this is the
-- in-place fix for a database that has already had the Pandaren overlay applied.

UPDATE `chrraces_dbc` SET
    `Name_Lang_enGB` = '', `Name_Lang_koKR` = '', `Name_Lang_frFR` = '', `Name_Lang_deDE` = '',
    `Name_Lang_enCN` = '', `Name_Lang_zhCN` = '', `Name_Lang_enTW` = '', `Name_Lang_zhTW` = '',
    `Name_Lang_esES` = '', `Name_Lang_esMX` = '', `Name_Lang_ruRU` = '', `Name_Lang_ptPT` = '',
    `Name_Lang_ptBR` = '', `Name_Lang_itIT` = '', `Name_Lang_Unk`  = '',
    `Name_Female_Lang_enGB` = '', `Name_Female_Lang_koKR` = '', `Name_Female_Lang_frFR` = '',
    `Name_Female_Lang_deDE` = '', `Name_Female_Lang_enCN` = '', `Name_Female_Lang_zhCN` = '',
    `Name_Female_Lang_enTW` = '', `Name_Female_Lang_zhTW` = '', `Name_Female_Lang_esES` = '',
    `Name_Female_Lang_esMX` = '', `Name_Female_Lang_ruRU` = '', `Name_Female_Lang_ptPT` = '',
    `Name_Female_Lang_ptBR` = '', `Name_Female_Lang_itIT` = '', `Name_Female_Lang_Unk`  = '',
    `Name_Male_Lang_enGB` = '', `Name_Male_Lang_koKR` = '', `Name_Male_Lang_frFR` = '',
    `Name_Male_Lang_deDE` = '', `Name_Male_Lang_enCN` = '', `Name_Male_Lang_zhCN` = '',
    `Name_Male_Lang_enTW` = '', `Name_Male_Lang_zhTW` = '', `Name_Male_Lang_esES` = '',
    `Name_Male_Lang_esMX` = '', `Name_Male_Lang_ruRU` = '', `Name_Male_Lang_ptPT` = '',
    `Name_Male_Lang_ptBR` = '', `Name_Male_Lang_itIT` = '', `Name_Male_Lang_Unk`  = ''
WHERE `ID` IN (22, 23);
