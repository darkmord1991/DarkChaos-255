Flightmaster (Option 2) - Server Script + DB Steps

NPC 800010: ScriptName = ACFM1
Gryphon vehicle NPC 800011: ScriptName = ac_gryphon_taxi_800011 (VehicleId must be set)

In-game:
- Talk to NPC 800010; choose "Take the gryphon tour" to board a temporary gryphon.
- The gryphon flies through the Azshara Crater path and drops you at the last node.

DB setup quick notes:
1) Bind script to the NPC template:
   UPDATE creature_template SET ScriptName='ACFM1' WHERE entry=800010;
2) Clone an existing gryphon vehicle template to 800011 (with a valid VehicleId) and set ScriptName='ac_gryphon_taxi_800011'.
   See Custom/DBTools/ac_flightmasters.sql for example statements and movement flags.
3) Ensure creature_template_movement has Flight=1 for CreatureId=800011.

Coordinates used (map 37):
- acfm1: 137.186, 954.93, 327.514
- acfm2: 269.873, 827.023, 289.094
- acfm3: 267.836, 717.604, 291.322
- acfm4: 198.497, 627.077, 293.514
- acfm5: 117.579, 574.066, 297.429
- acfm6: 11.149, 598.844, 284.878
- acfm7: 33.102, 542.816, 291.363
- acfm8: 42.68, 499.412, 315.351
- acfm9: 77.031, 432.792, 323.848
- acfm10: -4.513, 415.75, 308.212

Notes:
- If you want stricter level gating, uncomment the level check in OnGossipHello.
- To adjust flight speed, tweak SetSpeedRate(MOVE_FLIGHT, value) in ac_gryphon_taxi_800011AI::IsSummonedBy.
- If the gryphon spawns but doesn't board the player, verify the VehicleId and seat layout in your VehicleSeat.dbc data.
