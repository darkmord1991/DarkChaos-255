# Hotspot Display Addon

**Version:** 1.0  
**Author:** DarkChaos Team  
**Interface:** 3.3.5a (WotLK)

---

## Description

A simple and clean addon that displays "XP+" text on your map when you're standing in an XP Hotspot. Works with the DarkChaos Hotspots server system.

---

## Features

✅ **Map Text Overlay** - Shows "XP+100%" at your location when in hotspot  
✅ **Automatic Detection** - Uses buff detection (no manual input needed)  
✅ **Pulsing Effect** - Text pulses to grab attention  
✅ **Sound Notification** - Plays sound when entering hotspot  
✅ **Chat Notifications** - Alerts you when entering/leaving hotspots  
✅ **Customizable** - Adjust text size and toggle features  
✅ **Lightweight** - Minimal performance impact

---

## Installation

### Step 1: Copy Addon
Copy the `HotspotDisplay` folder to your WoW addons directory:

```
World of Warcraft/Interface/AddOns/HotspotDisplay/
```

### Step 2: Enable Addon
1. Launch World of Warcraft
2. Click "AddOns" at character selection screen
3. Enable "Hotspot Display"
4. Enter game

### Step 3: Verify
You should see in chat:
```
[Hotspot Display] Loaded v1.0
[Hotspot Display] Type /hotspot for options
```

---

## How to Use

### Automatic Detection

The addon automatically detects when you're in a hotspot by checking for the buff:
- **Buff Name:** "Sayge's Dark Fortune of Strength"
- **Buff ID:** 23768

When you enter a hotspot:
1. You'll hear a sound (auction house open sound)
2. Chat message: "You are in an XP Hotspot! Check your map."
3. Open your map (`M` key) to see "XP+100%" at your position

### Opening the Map

1. Press `M` to open the world map
2. If you're in a hotspot, you'll see gold "XP+100%" text at your character position
3. The text pulses to make it easy to spot

---

## Commands

Type `/hotspot` or `/hotspots` followed by:

| Command | Description |
|---------|-------------|
| `/hotspot` | Show help menu |
| `/hotspot toggle` | Enable/disable addon |
| `/hotspot text` | Toggle map text display |
| `/hotspot size <number>` | Set text size (10-30) |
| `/hotspot status` | Show current settings and hotspot status |
| `/hotspot reset` | Reset all settings to defaults |

### Examples

```
/hotspot status
>> Status:
>>   Enabled: Yes
>>   Show Text: Yes
>>   Text Size: 16
>>   XP Bonus: +100%
>>   In Hotspot: Yes

/hotspot size 20
>> Text size set to 20

/hotspot toggle
>> Addon disabled
```

---

## Configuration

### Saved Settings

Settings are saved per character in `SavedVariables/HotspotDisplayDB.lua`:

```lua
HotspotDisplayDB = {
    enabled = true,        -- Addon on/off
    showText = true,       -- Show map text overlay
    textSize = 16,         -- Font size (10-30)
    xpBonus = 100,         -- XP bonus percentage (auto-detected)
}
```

### Customizing

**Change Text Size:**
```
/hotspot size 20
```

**Disable Map Text:**
```
/hotspot text
```

**Temporarily Disable:**
```
/hotspot toggle
```

---

## How It Works

### Detection Method

The addon uses **buff detection** to determine if you're in a hotspot:

1. Every 1 second, checks your buffs for spell ID 23768
2. When buff is found, marks you as "in hotspot"
3. When buff is removed, marks you as "out of hotspot"
4. Updates map display accordingly

### Map Display

When the world map is open and you're in a hotspot:

1. Gets your position on map (0-1 coordinates)
2. Converts to pixel position on WorldMapFrame
3. Creates text overlay at your position
4. Applies gold color and pulsing animation
5. Updates every frame for smooth animation

### XP Bonus Parsing

The addon listens for world chat announcements:
```
[Hotspot] A new XP Hotspot has appeared in Eastern Kingdoms! (+100% XP)
```

When detected, it extracts the bonus percentage (100%) and displays it on the map.

---

## Troubleshooting

### "No text appears on map"

**Check:**
1. Are you actually in a hotspot? Look for the buff icon in your buff bar
2. Is the addon enabled? Type `/hotspot status`
3. Is map text enabled? Type `/hotspot text` to toggle
4. Try reloading UI: `/reload`

### "Buff not detected"

**Verify server config matches:**
- Server buff spell ID: 23768
- If server uses different spell ID, edit `Core.lua` line 14

### "Text is too small/large"

**Adjust size:**
```
/hotspot size 12   (smaller)
/hotspot size 20   (larger)
```

### "Addon not loading"

**Check:**
1. Folder is named exactly `HotspotDisplay`
2. Files are in correct location: `Interface/AddOns/HotspotDisplay/`
3. Both `HotspotDisplay.toc` and `Core.lua` are present
4. Addon is enabled at character select screen

---

## Technical Details

### Files

```
HotspotDisplay/
├── HotspotDisplay.toc    # Addon metadata
├── Core.lua              # Main addon code
└── README.md             # This file
```

### Dependencies

- None! This is a standalone addon
- Uses only standard WoW API (no libraries required)

### Performance

- **Memory:** ~50KB
- **CPU:** Minimal (checks buffs once per second)
- **Frame Rate:** No noticeable impact

### Compatibility

- **Client:** WoW 3.3.5a (WotLK)
- **Server:** DarkChaos Hotspots System
- **Other Addons:** Compatible with most UI addons

---

## Advanced Configuration

### Editing Core.lua

For advanced users, you can edit configuration in `Core.lua`:

```lua
local CONFIG = {
    HOTSPOT_BUFF_SPELL_ID = 23768,  -- Change if server uses different spell
    XP_BONUS_PERCENT = 100,         -- Default bonus
    TEXT_COLOR = {1, 0.84, 0},      -- RGB color (gold)
    PULSE_ENABLED = true,           -- Enable/disable pulsing
    CHECK_INTERVAL = 1.0,           -- Buff check frequency (seconds)
}
```

**Example:** Change text color to red:
```lua
TEXT_COLOR = {1, 0, 0},  -- Red
```

**Example:** Disable pulsing:
```lua
PULSE_ENABLED = false,
```

---

## FAQ

**Q: Does this work on retail WoW?**  
A: No, this is specifically for WoW 3.3.5a (WotLK) private servers.

**Q: Do other players need this addon?**  
A: No, it's optional. Each player can choose to install it.

**Q: Will this get me banned?**  
A: No, this is a UI addon that only displays information. It doesn't automate gameplay or give unfair advantages.

**Q: Can I see other players' hotspot locations?**  
A: No, you only see your own position when you're in a hotspot.

**Q: Does this show all hotspots on the map?**  
A: No, it only shows your current hotspot. For showing all hotspots, you'd need a more complex addon (see HOTSPOT_MAP_DISPLAY_GUIDE.md).

**Q: Can I customize the text?**  
A: Yes, edit `Core.lua` to change colors, size, animation, etc.

---

## Changelog

### Version 1.0 (October 17, 2025)
- Initial release
- Buff detection system
- Map text overlay with pulsing animation
- Sound and chat notifications
- Slash commands for configuration
- Saved settings per character

---

## Support

**Issues or Questions?**
- Check the main documentation: `Custom\HOTSPOT_MAP_DISPLAY_GUIDE.md`
- Server-side issues: Contact server administrators

**Feature Requests:**
- Submit to DarkChaos development team

---

## Credits

**Developer:** DarkChaos Team  
**Server System:** DarkChaos Hotspots (AzerothCore)  
**Inspired by:** Project Ascension Hotspots

---

## License

GNU AGPL v3 License  
Same as AzerothCore server framework

---

**Enjoy the XP bonuses!** 🎮✨
