## I need help in every area to work on more topics and issues - especially scripting and Client changes
## It would be great to have someone doing some wild stuff with map modifications in Ashzara Crater and the other level Areas for a more Classic+ feeling
## I am always open for proposals and discussions
## Please contact me via Github or Discord (Darkmord1991)

## Planned Features - based on AzerothCore:

* Max Level 255 (currently set to 80 max as development goes on)
* Level Zones 1 - 255
* Custom Items
* Custom Dungeons
* Custom Quests
* Custom features
* Blizzlike orientation
* Teleporters (mobile + NPC)
* Service NPC mobile
* Help commands via LUA (currently not working due to an Eluna change)
* Hinterland Custom Open world Battleground + Interface addon

## Handling in general:

* low amount of modifications in Core to be able to keep the updates without big modifications
* high usage of Modules + Eluna Scripts -> flexibility
* combined usage of Waypoints and wandering -> world feels more alive
* Balanced - no high/wild stats - Gameplay

## General WoW stuff:

* Level 255 stats for Players, Creatures, Pets
* Remove of hardcoded Level limit in Azerothcore
* Teleporter NPCs (mobile + standard one, same scripts used from DB Table based on LUA scripts)
* Vendors for every kind of WOTLK item
* Vendors and trainers for every profession

## Custom areas:

* Hinterland BG - Scripted OutdoorPvP Area
* Ashzara Crater Level Area 1-80
* Custom Tier Vendor Jail

## Custom Item Sets:

* T11 - Level 100 (weapons + armor from PvE and PvP)
* T12 - Level 130 (weapons + armor from PvE and PvP)
* two new bags (30 + 36 spaces) + quests per dungeon

## Custom Dungeons - all Blizz NPCs, Scripts, Quests 
## Questgiver in front of every dungeon kept and upgraded

* The Nexus         - Level 100 -> prepared non-HC + HC
* The Oculus        - Level 100 -> prepared non-HC + HC
* Gundrak           - Level 130 -> prepared non-HC + HC
* AhnCahet          - Level 130 -> prepared non-HC + HC
* Auchenai Crypts   - Level 160 -> prepared non-HC + HC
* Mana Tombs        - Level 160 -> prepared non-HC + HC
* Sethekk Halls     - Level 160 -> prepared non-HC + HC
* Shadow Labyrinth  - Level 160 -> prepared non-HC + HC

## Custom Level Areas:
* Ashzara Crater - Level 1 - 80 - spawns and preps done, more quests to be done
* Hyjal - Level 80 - 130 - start area prepared
* Strathholme dungeon outside - Level 130 - 160
* Flightmasters to be implemented for more immersion (Ashzara Crater already done)
* Teleporting guards for easier access

## HinterlandBG Features:
* Several commands (for reset, status)
* Interface Addon via .hlbg or /hlbg or via the PvP panel (still WIP, little buggy -> reading history data from CharDB, Stats, Queue start, etc.)
* Worldstates for current state
* lots of stuff configurable via config
* Queue system for the warmup phase
* Affix/Weather system prepared
* Season system prepared
* Auto check for level
* Autoinvite to raid group per faction
* and much more

## used modules
* git clone https://github.com/azerothcore/mod-ah-bot.git modules/mod-ah-bot
* git clone https://github.com/azerothcore/mod-duel-reset.git modules/mod-duel-reset
* git clone https://github.com/azerothcore/mod-learn-spells.git modules/mod-learn-spells
* git clone https://github.com/azerothcore/mod-transmog.git modules/mod-transmog
* git clone https://github.com/azerothcore/mod-world-chat.git modules/mod-world-chat
* git clone https://github.com/azerothcore/mod-cfbg.git modules/mod-cfbg
* git clone https://github.com/azerothcore/mod-skip-dk-starting-area.git modules/mod-skip-dk-starting-area
* git clone https://github.com/azerothcore/mod-npc-services.git modules/mod-npc-services
* git clone https://github.com/azerothcore/mod-instance-reset.git modules/mod-instance-reset
* git clone https://github.com/azerothcore/mod-arac.git modules/mod-arac
* git clone https://github.com/azerothcore/mod-anticheat.git modules/mod-anticheat
* git clone https://github.com/azerothcore/mod-npc-beastmaster.git modules/mod-npc-beastmaster
* git clone https://github.com/azerothcore/mod-zone-difficulty.git modules/mod-zone-difficulty
* git clone https://github.com/nl-saw/mod-challenge-modes.git modules/mod-challenge-modes
* git clone https://github.com/silviu20092/mod-mythic-plus.git modules/mod-mythic-plus
* git clone https://github.com/azerothcore/mod-eluna.git modules/mod-eluna
* git clone https://github.com/Brian-Aldridge/mod-customlogin.git modules/mod-customlogin

