air=set(x for x in open('k:/tmp/nel_air.txt').read().split(',') if x)
wander=set(x for x in open('k:/tmp/nel_wanderers.txt').read().split(',') if x)
patrol=set(x for x in open('k:/tmp/nel_patrol.txt').read().split(',') if x)
BOSS={'50059','50061','43641'}  # Terborus, Xariona, Aeosera -> scripted, leave movement alone
# Flyers: Neltharion air-list + Stonescale Drake (43971, high-Z drake patroller, NULL in acore)
flyer=sorted(air | {'43971'}, key=int)
# Wander/patrol mobs to un-static (exclude bosses; SQL also excludes invisible triggers by name)
wand=sorted((wander | patrol) - BOSS, key=int)
OUT=r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/Deepholm/26_movement_fixes.sql"
with open(OUT,'w',encoding='utf-8',newline='\n') as f:
    f.write("""-- =====================================================================
-- Deepholm Downport  --  26  Movement fixes (flyers falling + static world)
-- ---------------------------------------------------------------------
-- The TDB shipped Deepholm movement-incomplete: aerial NPCs had no
-- creature_template_movement row (=> gravity => "falling from the sky once a
-- player reaches them"), and ~100 ambient mob entries were MovementType=0 with
-- no wander (=> "lots of stuff is very static", Twilight Throne airspace empty).
-- Flight flag + wander intent recovered from Project Neltharion 4.3.4
-- (InhabitType air-list + per-spawn MovementType profile). Flight enum:
-- 0=None, 1=DisableGravity (stays aloft), 2=CanFly.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A) Flyers: give airborne NPCs Flight=1 (DisableGravity) so they don't fall.
--    (Aeosera/Xariona/Stone Drake already had Flight=1; this fills the gaps:
--     Twilight Pyremaw 42824, Crystalwing 48520, Stonescale Drake 43971, etc.)
-- ---------------------------------------------------------------------
INSERT INTO `creature_template_movement` (`CreatureId`,`Ground`,`Swim`,`Flight`,`Rooted`,`Chase`,`Random`,`InteractionPauseTimer`) VALUES
""")
    rows=["(%s,0,0,1,0,0,0,0)"%e for e in flyer]
    f.write(",\n".join(rows)+"\nON DUPLICATE KEY UPDATE `Flight`=1;\n\n")
    f.write("""-- ---------------------------------------------------------------------
-- B) Un-static the ambient mobs: idle (MovementType=0) spawns of entries that
--    Neltharion moves (random/patrol) -> random wander. Excludes bosses
--    (scripted) and invisible triggers/credits/bunnies/platforms by name.
--    (True patrol routes are a later refinement; random wander >> frozen.)
-- ---------------------------------------------------------------------
UPDATE `creature` c
JOIN `creature_template` ct ON ct.`entry`=c.`id`
SET c.`MovementType`=1, c.`wander_distance`=GREATEST(c.`wander_distance`,5)
WHERE c.`map`=646 AND c.`MovementType`=0
  AND (c.`ScriptName`='' OR c.`ScriptName` IS NULL)
  AND ct.`name` NOT REGEXP 'Bunny|Trigger|Credit|Beam|Controller| Ward|Platform|Generic|Stalker Beam|Totem|Camera|Visual'
  AND c.`id` IN (""")
    f.write(",".join(wand))
    f.write(");\n")
print("flyer entries:",len(flyer)," wander entries:",len(wand))
print("OUT:",OUT)
