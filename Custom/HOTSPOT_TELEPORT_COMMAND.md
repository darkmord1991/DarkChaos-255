# Hotspot Teleport Command - Implementation Complete

**Date:** October 17, 2025  
**Feature:** Added `.hotspots tp [id]` command for GM teleportation

---

## New Command

### `.hotspots tp [id]`

Teleports the GM to a hotspot location for testing and verification.

**Permission Level:** SEC_GAMEMASTER (GM level 1+)

---

## Usage

### Basic Usage (No ID)
```
.hotspots tp
```
Teleports to the **first active hotspot** in the list.

### Specific Hotspot (With ID)
```
.hotspots tp 3
```
Teleports to the hotspot with **ID 3**.

---

## Workflow Example

### Testing a New Hotspot

**Step 1: Spawn a hotspot**
```
.hotspots spawn
```
Output: `Spawned a new hotspot.`

**Step 2: List active hotspots**
```
.hotspots list
```
Output:
```
Active Hotspots: 1
  ID: 1 | Map: 0 | Zone: 12 | Pos: (-9500.2, -1234.5, 50.0) | Time Left: 60m
```

**Step 3: Teleport to it**
```
.hotspots tp 1
```
Output: `Teleported to Hotspot ID 1 on map 0 at (-9500.2, -1234.5, 50.0)`

**Step 4: Verify effects**
- You should see the cloud aura (entry effect)
- Check buff bar for flag icon (Sayge's Dark Fortune)
- Kill a mob to verify XP bonus
- Check map for GameObject marker (flag icon)

**Step 5: Clean up (optional)**
```
.hotspots clear
```

---

## Benefits for GMs

### Quick Testing
- Instantly teleport to hotspot locations
- Verify coordinates are valid (not underwater, in walls, etc.)
- Test XP bonus functionality
- Verify visual effects (auras, GameObject markers)

### Server Validation
- Check hotspot spawn positions before live deployment
- Test multiple hotspots without flying/running between them
- Debug hotspot detection radius
- Verify zone boundaries

### Player Support
- Teleport to player-reported hotspot issues
- Guide players to active hotspots
- Demonstrate hotspot features

---

## Error Handling

### No Active Hotspots
```
.hotspots tp
>> No active hotspots to teleport to.
```

### Invalid Hotspot ID
```
.hotspots tp 999
>> Hotspot ID 999 not found.
```

### Teleport Failure
```
.hotspots tp 1
>> Failed to teleport to hotspot.
```
(Rare - usually indicates map not loaded or invalid coordinates)

---

## Technical Details

### Implementation

**Function:** `HandleHotspotsTeleportCommand`

**Logic:**
1. Check if any hotspots are active
2. Parse hotspot ID from command args (or use first hotspot if no ID)
3. Find the hotspot in the active list
4. Use `player->TeleportTo(mapId, x, y, z, orientation)`
5. Send confirmation message with coordinates

**Code Excerpt:**
```cpp
if (player->TeleportTo(targetHotspot->mapId, targetHotspot->x, targetHotspot->y, 
                       targetHotspot->z, player->GetOrientation()))
{
    handler->PSendSysMessage("Teleported to Hotspot ID {} on map {} at ({:.1f}, {:.1f}, {:.1f})",
                            targetHotspot->id, targetHotspot->mapId,
                            targetHotspot->x, targetHotspot->y, targetHotspot->z);
}
```

---

## Complete Command Reference

### All Hotspot Commands

| Command | Level | Description |
|---------|-------|-------------|
| `.hotspots list` | GM (1) | List all active hotspots with details |
| `.hotspots spawn` | Admin (3) | Manually spawn a new hotspot |
| `.hotspots clear` | Admin (3) | Remove all active hotspots |
| `.hotspots reload` | Admin (3) | Reload configuration from file |
| `.hotspots tp [id]` | GM (1) | Teleport to hotspot by ID (or first) |

---

## Use Cases

### Development/Testing
1. **Coordinate Validation:**
   - Spawn hotspot → List to get coords → TP to verify location is valid
   
2. **Visual Testing:**
   - TP to hotspot → Check GameObject marker on map → Verify aura effects

3. **XP Bonus Testing:**
   - TP to hotspot → Kill mobs → Calculate XP gain → Verify bonus percentage

### Server Management
1. **Player Assistance:**
   - Player reports hotspot bug → TP to location → Investigate issue
   
2. **Event Setup:**
   - Before event → Spawn hotspots → TP to each → Verify all are accessible

3. **Performance Testing:**
   - Spawn multiple hotspots → TP between them → Monitor server performance

---

## Tips

### Finding Hotspot IDs
```
.hotspots list
```
Always shows the current ID of each active hotspot.

### Multiple Hotspots
If 3 hotspots are active (IDs 1, 2, 3):
```
.hotspots tp 1    # TP to first
.hotspots tp 2    # TP to second  
.hotspots tp 3    # TP to third
```

### Quick Testing Loop
```bash
# Spawn → TP → Test → Clear → Repeat
.hotspots spawn
.hotspots tp
# (test XP, visuals, etc.)
.hotspots clear
```

### Production Monitoring
```bash
# Check active hotspots
.hotspots list

# Visit each one to verify
.hotspots tp 1
.hotspots tp 2
# etc.
```

---

## Safety Notes

- **Teleport safety:** The command uses standard `TeleportTo()` which validates coordinates
- **Permission gating:** Only GMs (level 1+) can use this command
- **No exploits:** Players cannot use this command (requires GM permission)
- **Map loading:** If target map isn't loaded, teleport will fail gracefully

---

## Future Enhancements

Potential additions (not currently implemented):
- `.hotspots tp nearest` - TP to closest hotspot
- `.hotspots tp random` - TP to random active hotspot
- `.hotspots goto <player>` - TP player to nearest hotspot
- `.hotspots summon <player> <id>` - Summon player to specific hotspot

---

## Related Commands

### Movement Commands
- `.tele <name>` - Standard teleport by location name
- `.gps` - Show current coordinates
- `.appear <player>` - Teleport to player location

### Hotspot Management
- `.hotspots list` - See all active hotspots first
- `.hotspots spawn` - Create hotspot to test
- `.hotspots clear` - Remove hotspots after testing

---

## Documentation References

**Full Implementation Guide:**
- `Custom\HOTSPOTS_AND_AOELOOT_IMPLEMENTATION.md`

**Quick Reference:**
- `Custom\IMPLEMENTATION_SUMMARY.md`

**Client Addon Guide:**
- `Custom\HOTSPOT_MAP_DISPLAY_GUIDE.md`

**Final Status:**
- `Custom\IMPLEMENTATION_STATUS_FINAL.md`

---

## Changelog

### October 17, 2025
- ✅ Added `.hotspots tp [id]` command
- ✅ Supports teleport by ID or default to first hotspot
- ✅ Added error handling for invalid IDs
- ✅ Added success/failure messages
- ✅ Updated all documentation files
- ✅ Set permission level to SEC_GAMEMASTER

---

**Status:** Implemented and documented ✅  
**Ready for:** Compilation and in-game testing  
**Permission:** GM Level 1+
