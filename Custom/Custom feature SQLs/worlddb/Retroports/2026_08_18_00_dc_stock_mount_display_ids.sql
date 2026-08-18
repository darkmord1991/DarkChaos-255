-- 2026_08_18_00_dc_stock_mount_display_ids.sql
--
-- dc_mount_definitions.display_id is wrong for every STOCK (blizzlike) mount: it holds a
-- RETAIL-era CreatureDisplayInfo id, not a 3.3.5 one. None of those ids exist in this
-- client's CreatureDisplayInfo.dbc (Flying Broom = 56954, Brewfest Kodo = 29447, Great
-- Elite Elekk = 39654), and many mounts share one -- all five horse bridles carry 13108,
-- all twelve mechanostriders carry 17785 -- so the value can neither be resolved to a
-- model nor tell the colour variants apart. That is why every stock mount previewed blank
-- in DC-Collection while the custom ones rendered.
--
-- Correct value per mount, derived from the server's own data:
--   Spell.dbc EffectAura == 78 (SPELL_AURA_MOUNTED) -> EffectMiscValue = mount creature entry
--   -> creature_template_model.CreatureDisplayID = the real 3.3.5 display id.
-- (48778/64749/64762 wrap their mount in a TRIGGER_SPELL, and 55884 is the generic
--  "Learning" spell on a duplicate Horn of the Timber Wolf row; those four were resolved
--  through the triggered spell / by name.)
--
-- The client side no longer DEPENDS on this: Data/MountModelPathsStock.lua is keyed by
-- mount spell precisely because these ids were unusable. Applying this still fixes the
-- display id shown in the collection tooltip and makes the ordinary display-keyed lookup
-- work. Custom mounts (display_id >= 500000) are untouched.
--
-- NOTE: Custom/Custom feature SQLs/collectionextracts/extracts.sql has already been
-- patched with the same values, because generate_dc_collection_cdbc.py loads it LAST and
-- it would otherwise override these rows when the CDBC is regenerated.

UPDATE `dc_mount_definitions` SET `display_id` = 2404 WHERE `spell_id` = 458; -- Brown Horse Bridle
UPDATE `dc_mount_definitions` SET `display_id` = 2402 WHERE `spell_id` = 470; -- Black Stallion Bridle
UPDATE `dc_mount_definitions` SET `display_id` = 2409 WHERE `spell_id` = 472; -- Pinto Bridle
UPDATE `dc_mount_definitions` SET `display_id` = 247 WHERE `spell_id` = 580; -- Horn of the Timber Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 2405 WHERE `spell_id` = 6648; -- Chestnut Mare Bridle
UPDATE `dc_mount_definitions` SET `display_id` = 2327 WHERE `spell_id` = 6653; -- Horn of the Dire Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 2328 WHERE `spell_id` = 6654; -- Horn of the Brown Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 2736 WHERE `spell_id` = 6777; -- Gray Ram
UPDATE `dc_mount_definitions` SET `display_id` = 2786 WHERE `spell_id` = 6898; -- White Ram
UPDATE `dc_mount_definitions` SET `display_id` = 2785 WHERE `spell_id` = 6899; -- Brown Ram
UPDATE `dc_mount_definitions` SET `display_id` = 6080 WHERE `spell_id` = 8394; -- Reins of the Striped Frostsaber
UPDATE `dc_mount_definitions` SET `display_id` = 4806 WHERE `spell_id` = 8395; -- Whistle of the Emerald Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 6444 WHERE `spell_id` = 10789; -- Reins of the Spotted Frostsaber
UPDATE `dc_mount_definitions` SET `display_id` = 6448 WHERE `spell_id` = 10793; -- Reins of the Striped Nightsaber
UPDATE `dc_mount_definitions` SET `display_id` = 6472 WHERE `spell_id` = 10796; -- Whistle of the Turquoise Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 6473 WHERE `spell_id` = 10799; -- Whistle of the Violet Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 9473 WHERE `spell_id` = 10873; -- Red Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 6569 WHERE `spell_id` = 10969; -- Blue Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 9474 WHERE `spell_id` = 15779; -- White Mechanostrider Mod B
UPDATE `dc_mount_definitions` SET `display_id` = 9991 WHERE `spell_id` = 16055; -- Reins of the Nightsaber
UPDATE `dc_mount_definitions` SET `display_id` = 9695 WHERE `spell_id` = 16056; -- Reins of the Ancient Frostsaber
UPDATE `dc_mount_definitions` SET `display_id` = 4805 WHERE `spell_id` = 16058; -- Reins of the Primal Leopard
UPDATE `dc_mount_definitions` SET `display_id` = 6442 WHERE `spell_id` = 16059; -- Reins of the Tawny Sabercat
UPDATE `dc_mount_definitions` SET `display_id` = 9714 WHERE `spell_id` = 16060; -- Reins of the Golden Sabercat
UPDATE `dc_mount_definitions` SET `display_id` = 2326 WHERE `spell_id` = 16080; -- Horn of the Red Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 1166 WHERE `spell_id` = 16081; -- Horn of the Arctic Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 2408 WHERE `spell_id` = 16082; -- Palomino Bridle
UPDATE `dc_mount_definitions` SET `display_id` = 2410 WHERE `spell_id` = 16083; -- White Stallion Bridle
UPDATE `dc_mount_definitions` SET `display_id` = 6469 WHERE `spell_id` = 16084; -- Whistle of the Mottled Red Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 10426 WHERE `spell_id` = 17229; -- Reins of the Winterspring Frostsaber
UPDATE `dc_mount_definitions` SET `display_id` = 6471 WHERE `spell_id` = 17450; -- Whistle of the Ivory Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 10661 WHERE `spell_id` = 17453; -- Green Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 9476 WHERE `spell_id` = 17454; -- Unpainted Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 10662 WHERE `spell_id` = 17455; -- Purple Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 10664 WHERE `spell_id` = 17456; -- Red and Blue Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 9475 WHERE `spell_id` = 17458; -- Fluorescent Green Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 10666 WHERE `spell_id` = 17459; -- Icy Blue Mechanostrider Mod A
UPDATE `dc_mount_definitions` SET `display_id` = 2787 WHERE `spell_id` = 17460; -- Frost Ram
UPDATE `dc_mount_definitions` SET `display_id` = 2784 WHERE `spell_id` = 17461; -- Black Ram
UPDATE `dc_mount_definitions` SET `display_id` = 10670 WHERE `spell_id` = 17462; -- Red Skeletal Horse
UPDATE `dc_mount_definitions` SET `display_id` = 10671 WHERE `spell_id` = 17463; -- Blue Skeletal Horse
UPDATE `dc_mount_definitions` SET `display_id` = 10672 WHERE `spell_id` = 17464; -- Brown Skeletal Horse
UPDATE `dc_mount_definitions` SET `display_id` = 10720 WHERE `spell_id` = 17465; -- Green Skeletal Warhorse
UPDATE `dc_mount_definitions` SET `display_id` = 10718 WHERE `spell_id` = 17481; -- Deathcharger''s Reins
UPDATE `dc_mount_definitions` SET `display_id` = 12246 WHERE `spell_id` = 18989; -- Gray Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 11641 WHERE `spell_id` = 18990; -- Brown Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 12245 WHERE `spell_id` = 18991; -- Green Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 12242 WHERE `spell_id` = 18992; -- Teal Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 14337 WHERE `spell_id` = 22717; -- Black War Steed Bridle
UPDATE `dc_mount_definitions` SET `display_id` = 14348 WHERE `spell_id` = 22718; -- Black War Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 14372 WHERE `spell_id` = 22719; -- Black Battlestrider
UPDATE `dc_mount_definitions` SET `display_id` = 14577 WHERE `spell_id` = 22720; -- Black War Ram
UPDATE `dc_mount_definitions` SET `display_id` = 14388 WHERE `spell_id` = 22721; -- Whistle of the Black War Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 10719 WHERE `spell_id` = 22722; -- Red Skeletal Warhorse
UPDATE `dc_mount_definitions` SET `display_id` = 14330 WHERE `spell_id` = 22723; -- Reins of the Black War Tiger
UPDATE `dc_mount_definitions` SET `display_id` = 14334 WHERE `spell_id` = 22724; -- Horn of the Black War Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 14332 WHERE `spell_id` = 23219; -- Reins of the Swift Mistsaber
UPDATE `dc_mount_definitions` SET `display_id` = 14329 WHERE `spell_id` = 23220; -- Reins of the Swift Dawnsaber
UPDATE `dc_mount_definitions` SET `display_id` = 14331 WHERE `spell_id` = 23221; -- Reins of the Swift Frostsaber
UPDATE `dc_mount_definitions` SET `display_id` = 14377 WHERE `spell_id` = 23222; -- Swift Yellow Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 14376 WHERE `spell_id` = 23223; -- Swift White Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 14374 WHERE `spell_id` = 23225; -- Swift Green Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 14582 WHERE `spell_id` = 23227; -- Swift Palomino
UPDATE `dc_mount_definitions` SET `display_id` = 14338 WHERE `spell_id` = 23228; -- Swift White Steed
UPDATE `dc_mount_definitions` SET `display_id` = 14583 WHERE `spell_id` = 23229; -- Swift Brown Steed
UPDATE `dc_mount_definitions` SET `display_id` = 14347 WHERE `spell_id` = 23238; -- Swift Brown Ram
UPDATE `dc_mount_definitions` SET `display_id` = 14576 WHERE `spell_id` = 23239; -- Swift Gray Ram
UPDATE `dc_mount_definitions` SET `display_id` = 14346 WHERE `spell_id` = 23240; -- Swift White Ram
UPDATE `dc_mount_definitions` SET `display_id` = 14339 WHERE `spell_id` = 23241; -- Swift Blue Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 14344 WHERE `spell_id` = 23242; -- Swift Olive Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 14342 WHERE `spell_id` = 23243; -- Swift Orange Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 10721 WHERE `spell_id` = 23246; -- Purple Skeletal Warhorse
UPDATE `dc_mount_definitions` SET `display_id` = 14349 WHERE `spell_id` = 23247; -- Great White Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 14579 WHERE `spell_id` = 23248; -- Great Gray Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 14578 WHERE `spell_id` = 23249; -- Great Brown Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 14573 WHERE `spell_id` = 23250; -- Horn of the Swift Brown Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 14575 WHERE `spell_id` = 23251; -- Horn of the Swift Timber Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 14574 WHERE `spell_id` = 23252; -- Horn of the Swift Gray Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 14632 WHERE `spell_id` = 23338; -- Reins of the Swift Stormsaber
UPDATE `dc_mount_definitions` SET `display_id` = 14776 WHERE `spell_id` = 23509; -- Horn of the Frostwolf Howler
UPDATE `dc_mount_definitions` SET `display_id` = 14777 WHERE `spell_id` = 23510; -- Stormpike Battle Charger
UPDATE `dc_mount_definitions` SET `display_id` = 15289 WHERE `spell_id` = 24242; -- Swift Razzashi Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 15290 WHERE `spell_id` = 24252; -- Swift Zulian Tiger
UPDATE `dc_mount_definitions` SET `display_id` = 15672 WHERE `spell_id` = 25953; -- Blue Qiraji Resonating Crystal
UPDATE `dc_mount_definitions` SET `display_id` = 15681 WHERE `spell_id` = 26054; -- Red Qiraji Resonating Crystal
UPDATE `dc_mount_definitions` SET `display_id` = 15680 WHERE `spell_id` = 26055; -- Yellow Qiraji Resonating Crystal
UPDATE `dc_mount_definitions` SET `display_id` = 15679 WHERE `spell_id` = 26056; -- Green Qiraji Resonating Crystal
UPDATE `dc_mount_definitions` SET `display_id` = 15676 WHERE `spell_id` = 26656; -- Black Qiraji Resonating Crystal
UPDATE `dc_mount_definitions` SET `display_id` = 17697 WHERE `spell_id` = 32235; -- Golden Gryphon
UPDATE `dc_mount_definitions` SET `display_id` = 17694 WHERE `spell_id` = 32239; -- Ebon Gryphon
UPDATE `dc_mount_definitions` SET `display_id` = 17696 WHERE `spell_id` = 32240; -- Snowy Gryphon
UPDATE `dc_mount_definitions` SET `display_id` = 17759 WHERE `spell_id` = 32242; -- Swift Blue Gryphon
UPDATE `dc_mount_definitions` SET `display_id` = 17699 WHERE `spell_id` = 32243; -- Tawny Wind Rider
UPDATE `dc_mount_definitions` SET `display_id` = 17700 WHERE `spell_id` = 32244; -- Blue Wind Rider
UPDATE `dc_mount_definitions` SET `display_id` = 17701 WHERE `spell_id` = 32245; -- Green Wind Rider
UPDATE `dc_mount_definitions` SET `display_id` = 17719 WHERE `spell_id` = 32246; -- Swift Red Wind Rider
UPDATE `dc_mount_definitions` SET `display_id` = 17718 WHERE `spell_id` = 32289; -- Swift Red Gryphon
UPDATE `dc_mount_definitions` SET `display_id` = 17703 WHERE `spell_id` = 32290; -- Swift Green Gryphon
UPDATE `dc_mount_definitions` SET `display_id` = 17717 WHERE `spell_id` = 32292; -- Swift Purple Gryphon
UPDATE `dc_mount_definitions` SET `display_id` = 17720 WHERE `spell_id` = 32295; -- Swift Green Wind Rider
UPDATE `dc_mount_definitions` SET `display_id` = 17722 WHERE `spell_id` = 32296; -- Swift Yellow Wind Rider
UPDATE `dc_mount_definitions` SET `display_id` = 17721 WHERE `spell_id` = 32297; -- Swift Purple Wind Rider
UPDATE `dc_mount_definitions` SET `display_id` = 18697 WHERE `spell_id` = 33660; -- Swift Pink Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 17063 WHERE `spell_id` = 34406; -- Brown Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 17906 WHERE `spell_id` = 34407; -- Great Elite Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 19303 WHERE `spell_id` = 34790; -- Reins of the Dark War Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 18696 WHERE `spell_id` = 34795; -- Red Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 19375 WHERE `spell_id` = 34896; -- Reins of the Cobalt War Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 19377 WHERE `spell_id` = 34897; -- Reins of the White War Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 19378 WHERE `spell_id` = 34898; -- Reins of the Silver War Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 19376 WHERE `spell_id` = 34899; -- Reins of the Tan War Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 19479 WHERE `spell_id` = 35018; -- Purple Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 19480 WHERE `spell_id` = 35020; -- Blue Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 19478 WHERE `spell_id` = 35022; -- Black Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 19484 WHERE `spell_id` = 35025; -- Swift Green Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 19482 WHERE `spell_id` = 35027; -- Swift Purple Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 20359 WHERE `spell_id` = 35028; -- zzoldSwift Warstrider
UPDATE `dc_mount_definitions` SET `display_id` = 19869 WHERE `spell_id` = 35710; -- Gray Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 19870 WHERE `spell_id` = 35711; -- Purple Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 19873 WHERE `spell_id` = 35712; -- Great Green Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 19871 WHERE `spell_id` = 35713; -- Great Blue Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 19872 WHERE `spell_id` = 35714; -- Great Purple Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 19250 WHERE `spell_id` = 36702; -- Fiery Warhorse''s Reins
UPDATE `dc_mount_definitions` SET `display_id` = 20344 WHERE `spell_id` = 37015; -- Swift Nether Drake
UPDATE `dc_mount_definitions` SET `display_id` = 21073 WHERE `spell_id` = 39315; -- Reins of the Cobalt Riding Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 21074 WHERE `spell_id` = 39316; -- Reins of the Dark Riding Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 21075 WHERE `spell_id` = 39317; -- Reins of the Silver Riding Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 21077 WHERE `spell_id` = 39318; -- Reins of the Tan Riding Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 21076 WHERE `spell_id` = 39319; -- Reins of the White Riding Talbuk
UPDATE `dc_mount_definitions` SET `display_id` = 21152 WHERE `spell_id` = 39798; -- Green Riding Nether Ray
UPDATE `dc_mount_definitions` SET `display_id` = 21158 WHERE `spell_id` = 39800; -- Red Riding Nether Ray
UPDATE `dc_mount_definitions` SET `display_id` = 21155 WHERE `spell_id` = 39801; -- Purple Riding Nether Ray
UPDATE `dc_mount_definitions` SET `display_id` = 21157 WHERE `spell_id` = 39802; -- Silver Riding Nether Ray
UPDATE `dc_mount_definitions` SET `display_id` = 21156 WHERE `spell_id` = 39803; -- Blue Riding Nether Ray
UPDATE `dc_mount_definitions` SET `display_id` = 17890 WHERE `spell_id` = 40192; -- Ashes of Al''ar
UPDATE `dc_mount_definitions` SET `display_id` = 21473 WHERE `spell_id` = 41252; -- Reins of the Raven Lord
UPDATE `dc_mount_definitions` SET `display_id` = 21520 WHERE `spell_id` = 41513; -- Reins of the Onyx Netherwing Drake
UPDATE `dc_mount_definitions` SET `display_id` = 21521 WHERE `spell_id` = 41514; -- Reins of the Azure Netherwing Drake
UPDATE `dc_mount_definitions` SET `display_id` = 21525 WHERE `spell_id` = 41515; -- Reins of the Cobalt Netherwing Drake
UPDATE `dc_mount_definitions` SET `display_id` = 21523 WHERE `spell_id` = 41516; -- Reins of the Purple Netherwing Drake
UPDATE `dc_mount_definitions` SET `display_id` = 21522 WHERE `spell_id` = 41517; -- Reins of the Veridian Netherwing Drake
UPDATE `dc_mount_definitions` SET `display_id` = 21524 WHERE `spell_id` = 41518; -- Reins of the Violet Netherwing Drake
UPDATE `dc_mount_definitions` SET `display_id` = 21939 WHERE `spell_id` = 42667; -- Flying Broom
UPDATE `dc_mount_definitions` SET `display_id` = 21939 WHERE `spell_id` = 42668; -- Swift Flying Broom
UPDATE `dc_mount_definitions` SET `display_id` = 21939 WHERE `spell_id` = 42680; -- Old Magic Broom
UPDATE `dc_mount_definitions` SET `display_id` = 21973 WHERE `spell_id` = 42776; -- Reins of the Spectral Tiger
UPDATE `dc_mount_definitions` SET `display_id` = 21974 WHERE `spell_id` = 42777; -- Reins of the Swift Spectral Tiger
UPDATE `dc_mount_definitions` SET `display_id` = 22464 WHERE `spell_id` = 43688; -- Amani War Bear
UPDATE `dc_mount_definitions` SET `display_id` = 22265 WHERE `spell_id` = 43899; -- Brewfest Ram
UPDATE `dc_mount_definitions` SET `display_id` = 22350 WHERE `spell_id` = 43900; -- Swift Brewfest Ram
UPDATE `dc_mount_definitions` SET `display_id` = 22473 WHERE `spell_id` = 43927; -- Cenarion War Hippogryph
UPDATE `dc_mount_definitions` SET `display_id` = 22720 WHERE `spell_id` = 44151; -- Turbo-Charged Flying Machine Control
UPDATE `dc_mount_definitions` SET `display_id` = 22719 WHERE `spell_id` = 44153; -- Flying Machine Control
UPDATE `dc_mount_definitions` SET `display_id` = 22620 WHERE `spell_id` = 44744; -- Merciless Nether Drake
UPDATE `dc_mount_definitions` SET `display_id` = 23656 WHERE `spell_id` = 46197; -- X-51 Nether-Rocket
UPDATE `dc_mount_definitions` SET `display_id` = 23647 WHERE `spell_id` = 46199; -- X-51 Nether-Rocket X-TREME
UPDATE `dc_mount_definitions` SET `display_id` = 19483 WHERE `spell_id` = 46628; -- Swift White Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 21939 WHERE `spell_id` = 47977; -- Magic Broom
UPDATE `dc_mount_definitions` SET `display_id` = 25159 WHERE `spell_id` = 48025; -- The Horseman''s Reins
UPDATE `dc_mount_definitions` SET `display_id` = 23928 WHERE `spell_id` = 48027; -- Reins of the Black War Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 25280 WHERE `spell_id` = 48778; -- Acherus Deathcharger
UPDATE `dc_mount_definitions` SET `display_id` = 24693 WHERE `spell_id` = 48954; -- Swift Zhevra OLD
UPDATE `dc_mount_definitions` SET `display_id` = 24725 WHERE `spell_id` = 49193; -- Vengeful Nether Drake
UPDATE `dc_mount_definitions` SET `display_id` = 24745 WHERE `spell_id` = 49322; -- Swift Zhevra
UPDATE `dc_mount_definitions` SET `display_id` = 24758 WHERE `spell_id` = 49378; -- Brewfest Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 24757 WHERE `spell_id` = 49379; -- Great Brewfest Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 19996 WHERE `spell_id` = 50281; -- [PH] Reins of the Black Warp Stalker
UPDATE `dc_mount_definitions` SET `display_id` = 25335 WHERE `spell_id` = 51412; -- Big Battle Bear
UPDATE `dc_mount_definitions` SET `display_id` = 25511 WHERE `spell_id` = 51960; -- Ashes of Al''ar
UPDATE `dc_mount_definitions` SET `display_id` = 28108 WHERE `spell_id` = 54729; -- Winged Steed of the Ebon Blade
UPDATE `dc_mount_definitions` SET `display_id` = 28428 WHERE `spell_id` = 54753; -- Polar Bear Harness
UPDATE `dc_mount_definitions` SET `display_id` = 25871 WHERE `spell_id` = 55531; -- Mechano-hog
UPDATE `dc_mount_definitions` SET `display_id` = 247 WHERE `spell_id` = 55884; -- Horn of the Timber Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 27507 WHERE `spell_id` = 58615; -- Brutal Nether Drake
UPDATE `dc_mount_definitions` SET `display_id` = 27567 WHERE `spell_id` = 58983; -- Big Blizzard Bear
UPDATE `dc_mount_definitions` SET `display_id` = 27785 WHERE `spell_id` = 59567; -- Reins of the Azure Drake
UPDATE `dc_mount_definitions` SET `display_id` = 25832 WHERE `spell_id` = 59568; -- Reins of the Blue Drake
UPDATE `dc_mount_definitions` SET `display_id` = 25833 WHERE `spell_id` = 59569; -- Reins of the Bronze Drake
UPDATE `dc_mount_definitions` SET `display_id` = 25835 WHERE `spell_id` = 59570; -- Reins of the Red Drake
UPDATE `dc_mount_definitions` SET `display_id` = 27796 WHERE `spell_id` = 59571; -- Reins of the Twilight Drake
UPDATE `dc_mount_definitions` SET `display_id` = 27659 WHERE `spell_id` = 59572; -- Reins of the Black Polar Bear
UPDATE `dc_mount_definitions` SET `display_id` = 27660 WHERE `spell_id` = 59573; -- Reins of the Brown Polar Bear
UPDATE `dc_mount_definitions` SET `display_id` = 25831 WHERE `spell_id` = 59650; -- Reins of the Black Drake
UPDATE `dc_mount_definitions` SET `display_id` = 27247 WHERE `spell_id` = 59785; -- Reins of the Black War Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 27245 WHERE `spell_id` = 59788; -- Reins of the Black War Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 27243 WHERE `spell_id` = 59791; -- Reins of the Wooly Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 27244 WHERE `spell_id` = 59793; -- Reins of the Wooly Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 27246 WHERE `spell_id` = 59797; -- Reins of the Ice Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 27248 WHERE `spell_id` = 59799; -- Reins of the Ice Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 28044 WHERE `spell_id` = 59961; -- Reins of the Red Proto-Drake
UPDATE `dc_mount_definitions` SET `display_id` = 28040 WHERE `spell_id` = 59976; -- Reins of the Black Proto-Drake
UPDATE `dc_mount_definitions` SET `display_id` = 28041 WHERE `spell_id` = 59996; -- Reins of the Blue Proto-Drake
UPDATE `dc_mount_definitions` SET `display_id` = 28045 WHERE `spell_id` = 60002; -- Reins of the Time-Lost Proto-Drake
UPDATE `dc_mount_definitions` SET `display_id` = 28042 WHERE `spell_id` = 60021; -- Reins of the Plagued Proto-Drake
UPDATE `dc_mount_definitions` SET `display_id` = 28043 WHERE `spell_id` = 60024; -- Reins of the Violet Proto-Drake
UPDATE `dc_mount_definitions` SET `display_id` = 25836 WHERE `spell_id` = 60025; -- Reins of the Albino Drake
UPDATE `dc_mount_definitions` SET `display_id` = 27820 WHERE `spell_id` = 60114; -- Reins of the Armored Brown Bear
UPDATE `dc_mount_definitions` SET `display_id` = 27821 WHERE `spell_id` = 60116; -- Reins of the Armored Brown Bear
UPDATE `dc_mount_definitions` SET `display_id` = 27818 WHERE `spell_id` = 60118; -- Reins of the Black War Bear
UPDATE `dc_mount_definitions` SET `display_id` = 27819 WHERE `spell_id` = 60119; -- Reins of the Black War Bear
UPDATE `dc_mount_definitions` SET `display_id` = 25870 WHERE `spell_id` = 60424; -- Mekgineer''s Chopper
UPDATE `dc_mount_definitions` SET `display_id` = 27913 WHERE `spell_id` = 61229; -- Armored Snowy Gryphon
UPDATE `dc_mount_definitions` SET `display_id` = 27914 WHERE `spell_id` = 61230; -- Armored Blue Wind Rider
UPDATE `dc_mount_definitions` SET `display_id` = 28053 WHERE `spell_id` = 61294; -- Reins of the Green Proto-Drake
UPDATE `dc_mount_definitions` SET `display_id` = 28060 WHERE `spell_id` = 61309; -- Magnificent Flying Carpet
UPDATE `dc_mount_definitions` SET `display_id` = 27237 WHERE `spell_id` = 61425; -- Reins of the Traveler''s Tundra Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 28063 WHERE `spell_id` = 61442; -- Swift Mooncloth Carpet
UPDATE `dc_mount_definitions` SET `display_id` = 28064 WHERE `spell_id` = 61446; -- Swift Spellfire Carpet
UPDATE `dc_mount_definitions` SET `display_id` = 27238 WHERE `spell_id` = 61447; -- Reins of the Traveler''s Tundra Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 28082 WHERE `spell_id` = 61451; -- Flying Carpet
UPDATE `dc_mount_definitions` SET `display_id` = 27241 WHERE `spell_id` = 61465; -- Reins of the Grand Black War Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 27240 WHERE `spell_id` = 61467; -- Reins of the Grand Black War Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 27239 WHERE `spell_id` = 61469; -- Reins of the Grand Ice Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 27242 WHERE `spell_id` = 61470; -- Reins of the Grand Ice Mammoth
UPDATE `dc_mount_definitions` SET `display_id` = 27525 WHERE `spell_id` = 61996; -- Blue Dragonhawk Mount
UPDATE `dc_mount_definitions` SET `display_id` = 28402 WHERE `spell_id` = 61997; -- Red Dragonhawk Mount
UPDATE `dc_mount_definitions` SET `display_id` = 28912 WHERE `spell_id` = 63232; -- Stormwind Steed
UPDATE `dc_mount_definitions` SET `display_id` = 29261 WHERE `spell_id` = 63635; -- Darkspear Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 29258 WHERE `spell_id` = 63636; -- Ironforge Ram
UPDATE `dc_mount_definitions` SET `display_id` = 29256 WHERE `spell_id` = 63637; -- Darnassian Nightsaber
UPDATE `dc_mount_definitions` SET `display_id` = 28571 WHERE `spell_id` = 63638; -- Gnomeregan Mechanostrider
UPDATE `dc_mount_definitions` SET `display_id` = 29255 WHERE `spell_id` = 63639; -- Exodar Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 29260 WHERE `spell_id` = 63640; -- Orgrimmar Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 29259 WHERE `spell_id` = 63641; -- Thunder Bluff Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 29262 WHERE `spell_id` = 63642; -- Silvermoon Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 29257 WHERE `spell_id` = 63643; -- Forsaken Warhorse
UPDATE `dc_mount_definitions` SET `display_id` = 28890 WHERE `spell_id` = 63796; -- Mimiron''s Head
UPDATE `dc_mount_definitions` SET `display_id` = 22471 WHERE `spell_id` = 63844; -- Argent Hippogryph
UPDATE `dc_mount_definitions` SET `display_id` = 28953 WHERE `spell_id` = 63956; -- Reins of the Ironbound Proto-Drake
UPDATE `dc_mount_definitions` SET `display_id` = 28954 WHERE `spell_id` = 63963; -- Reins of the Rusted Proto-Drake
UPDATE `dc_mount_definitions` SET `display_id` = 12241 WHERE `spell_id` = 64657; -- White Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 207 WHERE `spell_id` = 64658; -- Horn of the Black Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 29102 WHERE `spell_id` = 64659; -- Whistle of the Venomhide Ravasaur
UPDATE `dc_mount_definitions` SET `display_id` = 29161 WHERE `spell_id` = 64731; -- Sea Turtle
UPDATE `dc_mount_definitions` SET `display_id` = 17697 WHERE `spell_id` = 64749; -- Loaned Gryphon Reins
UPDATE `dc_mount_definitions` SET `display_id` = 17699 WHERE `spell_id` = 64762; -- Loaned Wind Rider Reins
UPDATE `dc_mount_definitions` SET `display_id` = 25511 WHERE `spell_id` = 64927; -- Deadly Gladiator''s Frost Wyrm
UPDATE `dc_mount_definitions` SET `display_id` = 29130 WHERE `spell_id` = 64977; -- Black Skeletal Horse
UPDATE `dc_mount_definitions` SET `display_id` = 25593 WHERE `spell_id` = 65439; -- Furious Gladiator''s Frost Wyrm
UPDATE `dc_mount_definitions` SET `display_id` = 28606 WHERE `spell_id` = 65637; -- Great Red Elekk
UPDATE `dc_mount_definitions` SET `display_id` = 14333 WHERE `spell_id` = 65638; -- Swift Moonsaber
UPDATE `dc_mount_definitions` SET `display_id` = 28607 WHERE `spell_id` = 65639; -- Swift Red Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 29043 WHERE `spell_id` = 65640; -- Swift Gray Steed
UPDATE `dc_mount_definitions` SET `display_id` = 28556 WHERE `spell_id` = 65641; -- Great Golden Kodo
UPDATE `dc_mount_definitions` SET `display_id` = 14375 WHERE `spell_id` = 65642; -- Turbostrider
UPDATE `dc_mount_definitions` SET `display_id` = 28612 WHERE `spell_id` = 65643; -- Swift Violet Ram
UPDATE `dc_mount_definitions` SET `display_id` = 14343 WHERE `spell_id` = 65644; -- Swift Purple Raptor
UPDATE `dc_mount_definitions` SET `display_id` = 28605 WHERE `spell_id` = 65645; -- White Skeletal Warhorse
UPDATE `dc_mount_definitions` SET `display_id` = 14335 WHERE `spell_id` = 65646; -- Swift Burgundy Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 29344 WHERE `spell_id` = 65917; -- Magic Rooster Egg
UPDATE `dc_mount_definitions` SET `display_id` = 22474 WHERE `spell_id` = 66087; -- Silver Covenant Hippogryph
UPDATE `dc_mount_definitions` SET `display_id` = 29696 WHERE `spell_id` = 66088; -- Sunreaver Dragonhawk
UPDATE `dc_mount_definitions` SET `display_id` = 28888 WHERE `spell_id` = 66090; -- Quel''dorei Steed
UPDATE `dc_mount_definitions` SET `display_id` = 28889 WHERE `spell_id` = 66091; -- Sunreaver Hawkstrider
UPDATE `dc_mount_definitions` SET `display_id` = 29754 WHERE `spell_id` = 66846; -- Ochre Skeletal Warhorse
UPDATE `dc_mount_definitions` SET `display_id` = 29755 WHERE `spell_id` = 66847; -- Reins of the Striped Dawnsaber
UPDATE `dc_mount_definitions` SET `display_id` = 28919 WHERE `spell_id` = 66906; -- Argent Charger
UPDATE `dc_mount_definitions` SET `display_id` = 29794 WHERE `spell_id` = 67336; -- Relentless Gladiator''s Frost Wyrm
UPDATE `dc_mount_definitions` SET `display_id` = 28918 WHERE `spell_id` = 67466; -- Argent Warhorse
UPDATE `dc_mount_definitions` SET `display_id` = 29283 WHERE `spell_id` = 68056; -- Swift Horde Wolf
UPDATE `dc_mount_definitions` SET `display_id` = 29284 WHERE `spell_id` = 68057; -- Swift Alliance Steed
UPDATE `dc_mount_definitions` SET `display_id` = 29937 WHERE `spell_id` = 68187; -- Crusader''s White Warhorse
UPDATE `dc_mount_definitions` SET `display_id` = 29938 WHERE `spell_id` = 68188; -- Crusader''s Black Warhorse
UPDATE `dc_mount_definitions` SET `display_id` = 30346 WHERE `spell_id` = 69395; -- Reins of the Onyxian Drake
UPDATE `dc_mount_definitions` SET `display_id` = 30989 WHERE `spell_id` = 71342; -- Big Love Rocket
UPDATE `dc_mount_definitions` SET `display_id` = 31047 WHERE `spell_id` = 71810; -- Wrathful Gladiator''s Frost Wyrm
UPDATE `dc_mount_definitions` SET `display_id` = 31007 WHERE `spell_id` = 72286; -- Invincible''s Reins
UPDATE `dc_mount_definitions` SET `display_id` = 31154 WHERE `spell_id` = 72807; -- Reins of the Icebound Frostbrood Vanquisher
UPDATE `dc_mount_definitions` SET `display_id` = 31156 WHERE `spell_id` = 72808; -- Reins of the Bloodbathed Frostbrood Vanquisher
UPDATE `dc_mount_definitions` SET `display_id` = 25279 WHERE `spell_id` = 73313; -- Reins of the Crimson Deathcharger
UPDATE `dc_mount_definitions` SET `display_id` = 31803 WHERE `spell_id` = 74856; -- Blazing Hippogryph
UPDATE `dc_mount_definitions` SET `display_id` = 31721 WHERE `spell_id` = 74918; -- Wooly White Rhino
UPDATE `dc_mount_definitions` SET `display_id` = 28063 WHERE `spell_id` = 75596; -- Frosty Flying Carpet
UPDATE `dc_mount_definitions` SET `display_id` = 31957 WHERE `spell_id` = 75614; -- Celestial Steed
UPDATE `dc_mount_definitions` SET `display_id` = 31992 WHERE `spell_id` = 75973; -- X-53 Touring Rocket

-- Verification: expect 0 rows back (every stock row now carries a real 3.3.5 display).
-- SELECT spell_id, name, display_id FROM dc_mount_definitions
--   WHERE display_id < 500000 AND display_id NOT IN (SELECT CreatureDisplayID FROM creature_template_model);
