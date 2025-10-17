
#  NEW SYSTEMS: Hotspots & AOE Loot

**Date**: October 17, 2025  
**Status**:  Implementation Complete - Ready for Build

---

## Overview

Two major server-side gameplay systems implemented:

1. **Hotspots System** - Random XP bonus zones
2. **AOE Loot System** - Multi-loot nearby corpses

---

##  Hotspots System

### What It Does
- Random zones spawn that give **+100% XP bonus**
- Players see visual effects entering hotspot
- Lasts 1 hour, then expires
- World announcements when spawning

### Files Created
- src/server/scripts/DC/ac_hotspots.cpp
- Custom/Config files/ac_hotspots.conf.dist

### GM Commands
```
.hotspots list
.hotspots spawn
.hotspots clear
.hotspots reload
.hotspots tp [id]
```

---

##  AOE Loot System

### What It Does
- Loot one corpse → loots all nearby (packet interception)
- Automatic: auto-loot, quest items, money
- Based on official AzerothCore module

### Files Created
- src/server/scripts/DC/ac_aoeloot.cpp
- Custom/Config files/ac_aoeloot.conf.dist

### GM Commands
```
.aoeloot info
.aoeloot reload
```

---

##  Quick Start

1. Build: ```./acore.sh compiler build```
2. Copy configs from Custom/Config files/ to conf/
3. Adjust corpse decay in worldserver.conf: `Rate.Corpse.Decay.Looted = 0.1`
4. Restart server
5. Test with GM commands

See full docs:
- HOTSPOTS_AND_AOELOOT_IMPLEMENTATION.md
- IMPLEMENTATION_SUMMARY.md

