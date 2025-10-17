# Hotspot Display Addon - Installation Guide

**Quick Start Guide for Players**

---

## Step 1: Locate Your WoW Folder

Find your World of Warcraft installation directory:

**Common Locations:**
- `C:\Program Files (x86)\World of Warcraft\`
- `C:\Games\World of Warcraft\`
- `D:\World of Warcraft\`

---

## Step 2: Navigate to AddOns Folder

Inside your WoW folder, navigate to:
```
World of Warcraft\Interface\AddOns\
```

If the `AddOns` folder doesn't exist, create it:
```
World of Warcraft\Interface\AddOns\
```

---

## Step 3: Install the Addon

Copy the entire `HotspotDisplay` folder to the AddOns directory:

**From:**
```
DarkChaos-255\Custom\Client addons needed\HotspotDisplay\
```

**To:**
```
World of Warcraft\Interface\AddOns\HotspotDisplay\
```

**Final Structure:**
```
World of Warcraft\
└── Interface\
    └── AddOns\
        └── HotspotDisplay\
            ├── HotspotDisplay.toc
            ├── Core.lua
            └── README.md
```

---

## Step 4: Verify Installation

### Method 1: Character Select Screen
1. Launch World of Warcraft
2. At character selection, click **"AddOns"** button (bottom-left)
3. Look for **"Hotspot Display"** in the list
4. Make sure it's **checked** (enabled)
5. Click **"Okay"**

### Method 2: In-Game Check
1. Log in to your character
2. Look for this message in chat:
   ```
   [Hotspot Display] Loaded v1.0
   [Hotspot Display] Type /hotspot for options
   ```
3. Type `/hotspot status` to verify it's working

---

## Step 5: Test the Addon

### Find a Hotspot
1. Wait for server announcement:
   ```
   [Hotspot] A new XP Hotspot has appeared in Eastern Kingdoms! (+100% XP)
   ```
2. Use `.hotspots list` (if you're a GM) or ask a GM for location
3. Travel to the hotspot location

### Verify Functionality
1. When you enter the hotspot, you should:
   - Hear a sound (auction house opening)
   - See chat message: "You are in an XP Hotspot! Check your map."
   - See buff icon "Sayge's Dark Fortune of Strength" in your buff bar

2. Open your map (press `M`)
3. You should see **gold "XP+100%" text** at your character position
4. The text should pulse slowly

---

## Common Issues

### Issue: "Addon not in list"

**Solution:**
1. Double-check folder name is exactly `HotspotDisplay` (case-sensitive on some systems)
2. Verify files are in the correct location
3. Restart WoW completely (close and reopen)
4. Try deleting `Cache` folder in WoW directory (WoW will regenerate it)

### Issue: "Addon loads but no text on map"

**Solution:**
1. Make sure you're actually in a hotspot (check for buff icon)
2. Type `/hotspot status` to check if addon is enabled
3. Type `/hotspot text` to ensure map text is enabled
4. Try `/reload` to reload UI

### Issue: "Out of date" warning

**Solution:**
1. Click "Load out of date AddOns" at character select
2. Or enable "Load out of date AddOns" in Interface options

---

## Uninstalling

To remove the addon:

1. Close World of Warcraft
2. Navigate to `World of Warcraft\Interface\AddOns\`
3. Delete the `HotspotDisplay` folder
4. (Optional) Delete saved settings:
   - `World of Warcraft\WTF\Account\<ACCOUNT>\<SERVER>\<CHARACTER>\SavedVariables\HotspotDisplayDB.lua`

---

## Using the Addon

Once installed, the addon works automatically:

1. **No configuration needed** - Works out of the box
2. **Automatic detection** - Detects hotspots via buff
3. **Map display** - Open map (`M` key) to see XP+ text when in hotspot

**Slash Commands:**
```
/hotspot           # Show help
/hotspot status    # Check status
/hotspot size 20   # Adjust text size
```

---

## Updating the Addon

If a new version is released:

1. Close World of Warcraft
2. Delete old `HotspotDisplay` folder
3. Copy new `HotspotDisplay` folder to AddOns
4. Launch WoW

Your settings will be preserved (stored in SavedVariables).

---

## Distribution

### For Server Admins

To distribute this addon to players:

**Option 1: Direct Download**
- Zip the `HotspotDisplay` folder
- Host on website/Discord
- Provide installation instructions

**Option 2: Addon Pack**
- Include in server addon pack with other recommended addons
- Create installer script (optional)

**Option 3: In-Game Link**
- Use MOTD (Message of the Day) to link to download
- Include in welcome messages

**Example MOTD:**
```
Welcome to DarkChaos!
Download the Hotspot Display addon: www.yourserver.com/addons
Installation guide: www.yourserver.com/addon-guide
```

---

## Support for Players

**Having issues?**

1. Type `/hotspot status` in-game
2. Check README.md for troubleshooting
3. Ask in server Discord/forum
4. Contact a GM in-game

**Common Commands:**
```
/hotspot status    # Check if working
/hotspot toggle    # Try disabling and re-enabling
/reload            # Reload UI
```

---

## Technical Requirements

**Client:**
- World of Warcraft 3.3.5a (WotLK)
- No other addons required

**Server:**
- DarkChaos Hotspots System enabled
- Buff spell ID 23768 (default)

---

## Additional Resources

**Documentation:**
- `README.md` - Full addon documentation
- `HOTSPOT_MAP_DISPLAY_GUIDE.md` - Advanced features guide
- Server documentation in `Custom\` folder

**Commands:**
- `/hotspot help` - In-game help
- `/hotspot status` - Check addon status

---

**Installation Complete!**

You're ready to see XP+ hotspot locations on your map! 🎮✨

Look for the buff icon in your buff bar when you enter a hotspot, then open your map to see the gold "XP+100%" text at your position.

Happy leveling!
