-- ---------------------------------------------------------------------------
-- 314  OPTIONAL -- put the 750xxx ladder's armor on the same curve as everything else
-- ---------------------------------------------------------------------------
-- 🔴 NOT IN apply_all.sql. This retunes the reward tier you designed, so it is
-- your call, not mine.
--
-- FOUND WHILE VERIFYING 310_. The 90 ladder items (400708-400782, 400110-400124)
-- carry armor that does not come from Cata's armor curve. Running the same
-- generator that produced 310_ over them gives:
--
--   entry   piece                ilvl   now    curve
--   400708  cloth wrist          300     102     485
--   400753  cloth wrist          372     127     589
--   400115  cloth shoulder       398     200    1160
--   400120  cloth legs           398     241    1353
--   400124  PLATE legs           398    2424    3360
--
-- Every one is low, and cloth/leather/mail are low by ~5x while plate is only
-- ~1.4x off -- the signature of an armor-type index that was wrong for the
-- non-plate classes when these were first built.
--
-- WHY IT MATTERS NOW: 310_ gives the 2,536 clones correct curve-derived armor
-- (cloth wrist 468-642, cloth legs 936-1257). Without this file, a GREEN cloth
-- clone out-armors the RARE ladder cloth piece of the same band by 4-6x, which
-- inverts the tier -- the ladder is supposed to be the good drop.
--
-- Two ways to resolve it, and they are genuinely different design choices:
--   * apply this file -> the whole tier sits on Cata's curve, ladder back on top
--   * skip it and lower 310_'s values instead -> a flatter, WotLK-ish armor
--     world, but then the clones no longer match the ilvls they advertise
-- I have not chosen for you. This file is the first option, ready to run.
--
-- Apply against acore_world, then restart. Idempotent (absolute assignments).
-- The old values are not backed up here -- they are reproducible from git, and
-- `310_`'s header records the five samples above.
-- ---------------------------------------------------------------------------
UPDATE `item_template` SET `armor`=1063 WHERE `entry`=400110;
UPDATE `item_template` SET `armor`=1063 WHERE `entry`=400111;
UPDATE `item_template` SET `armor`=1366 WHERE `entry`=400112;
UPDATE `item_template` SET `armor`=2640 WHERE `entry`=400113;
UPDATE `item_template` SET `armor`=2640 WHERE `entry`=400114;
UPDATE `item_template` SET `armor`=1160 WHERE `entry`=400115;
UPDATE `item_template` SET `armor`=1160 WHERE `entry`=400116;
UPDATE `item_template` SET `armor`=1491 WHERE `entry`=400117;
UPDATE `item_template` SET `armor`=2880 WHERE `entry`=400118;
UPDATE `item_template` SET `armor`=2880 WHERE `entry`=400119;
UPDATE `item_template` SET `armor`=1353 WHERE `entry`=400120;
UPDATE `item_template` SET `armor`=1353 WHERE `entry`=400121;
UPDATE `item_template` SET `armor`=1739 WHERE `entry`=400122;
UPDATE `item_template` SET `armor`=3360 WHERE `entry`=400123;
UPDATE `item_template` SET `armor`=3360 WHERE `entry`=400124;
UPDATE `item_template` SET `armor`=485 WHERE `entry`=400708;
UPDATE `item_template` SET `armor`=485 WHERE `entry`=400709;
UPDATE `item_template` SET `armor`=622 WHERE `entry`=400710;
UPDATE `item_template` SET `armor`=1196 WHERE `entry`=400711;
UPDATE `item_template` SET `armor`=1196 WHERE `entry`=400712;
UPDATE `item_template` SET `armor`=623 WHERE `entry`=400713;
UPDATE `item_template` SET `armor`=623 WHERE `entry`=400714;
UPDATE `item_template` SET `armor`=800 WHERE `entry`=400715;
UPDATE `item_template` SET `armor`=1538 WHERE `entry`=400716;
UPDATE `item_template` SET `armor`=1538 WHERE `entry`=400717;
UPDATE `item_template` SET `armor`=692 WHERE `entry`=400718;
UPDATE `item_template` SET `armor`=692 WHERE `entry`=400719;
UPDATE `item_template` SET `armor`=889 WHERE `entry`=400720;
UPDATE `item_template` SET `armor`=1709 WHERE `entry`=400721;
UPDATE `item_template` SET `armor`=1709 WHERE `entry`=400722;
UPDATE `item_template` SET `armor`=485 WHERE `entry`=400723;
UPDATE `item_template` SET `armor`=485 WHERE `entry`=400724;
UPDATE `item_template` SET `armor`=622 WHERE `entry`=400725;
UPDATE `item_template` SET `armor`=1196 WHERE `entry`=400726;
UPDATE `item_template` SET `armor`=1196 WHERE `entry`=400727;
UPDATE `item_template` SET `armor`=623 WHERE `entry`=400728;
UPDATE `item_template` SET `armor`=623 WHERE `entry`=400729;
UPDATE `item_template` SET `armor`=800 WHERE `entry`=400730;
UPDATE `item_template` SET `armor`=1538 WHERE `entry`=400731;
UPDATE `item_template` SET `armor`=1538 WHERE `entry`=400732;
UPDATE `item_template` SET `armor`=692 WHERE `entry`=400733;
UPDATE `item_template` SET `armor`=692 WHERE `entry`=400734;
UPDATE `item_template` SET `armor`=889 WHERE `entry`=400735;
UPDATE `item_template` SET `armor`=1709 WHERE `entry`=400736;
UPDATE `item_template` SET `armor`=1709 WHERE `entry`=400737;
UPDATE `item_template` SET `armor`=786 WHERE `entry`=400738;
UPDATE `item_template` SET `armor`=786 WHERE `entry`=400739;
UPDATE `item_template` SET `armor`=1048 WHERE `entry`=400740;
UPDATE `item_template` SET `armor`=2142 WHERE `entry`=400741;
UPDATE `item_template` SET `armor`=2142 WHERE `entry`=400742;
UPDATE `item_template` SET `armor`=858 WHERE `entry`=400743;
UPDATE `item_template` SET `armor`=858 WHERE `entry`=400744;
UPDATE `item_template` SET `armor`=1143 WHERE `entry`=400745;
UPDATE `item_template` SET `armor`=2337 WHERE `entry`=400746;
UPDATE `item_template` SET `armor`=2337 WHERE `entry`=400747;
UPDATE `item_template` SET `armor`=1001 WHERE `entry`=400748;
UPDATE `item_template` SET `armor`=1001 WHERE `entry`=400749;
UPDATE `item_template` SET `armor`=1334 WHERE `entry`=400750;
UPDATE `item_template` SET `armor`=2726 WHERE `entry`=400751;
UPDATE `item_template` SET `armor`=2726 WHERE `entry`=400752;
UPDATE `item_template` SET `armor`=589 WHERE `entry`=400753;
UPDATE `item_template` SET `armor`=589 WHERE `entry`=400754;
UPDATE `item_template` SET `armor`=775 WHERE `entry`=400755;
UPDATE `item_template` SET `armor`=1557 WHERE `entry`=400756;
UPDATE `item_template` SET `armor`=1557 WHERE `entry`=400757;
UPDATE `item_template` SET `armor`=841 WHERE `entry`=400758;
UPDATE `item_template` SET `armor`=841 WHERE `entry`=400759;
UPDATE `item_template` SET `armor`=1107 WHERE `entry`=400760;
UPDATE `item_template` SET `armor`=2224 WHERE `entry`=400761;
UPDATE `item_template` SET `armor`=2224 WHERE `entry`=400762;
UPDATE `item_template` SET `armor`=757 WHERE `entry`=400763;
UPDATE `item_template` SET `armor`=757 WHERE `entry`=400764;
UPDATE `item_template` SET `armor`=996 WHERE `entry`=400765;
UPDATE `item_template` SET `armor`=2002 WHERE `entry`=400766;
UPDATE `item_template` SET `armor`=2002 WHERE `entry`=400767;
UPDATE `item_template` SET `armor`=632 WHERE `entry`=400768;
UPDATE `item_template` SET `armor`=632 WHERE `entry`=400769;
UPDATE `item_template` SET `armor`=821 WHERE `entry`=400770;
UPDATE `item_template` SET `armor`=1617 WHERE `entry`=400771;
UPDATE `item_template` SET `armor`=1617 WHERE `entry`=400772;
UPDATE `item_template` SET `armor`=903 WHERE `entry`=400773;
UPDATE `item_template` SET `armor`=903 WHERE `entry`=400774;
UPDATE `item_template` SET `armor`=1173 WHERE `entry`=400775;
UPDATE `item_template` SET `armor`=2310 WHERE `entry`=400776;
UPDATE `item_template` SET `armor`=2310 WHERE `entry`=400777;
UPDATE `item_template` SET `armor`=812 WHERE `entry`=400778;
UPDATE `item_template` SET `armor`=812 WHERE `entry`=400779;
UPDATE `item_template` SET `armor`=1056 WHERE `entry`=400780;
UPDATE `item_template` SET `armor`=2079 WHERE `entry`=400781;
UPDATE `item_template` SET `armor`=2079 WHERE `entry`=400782;
