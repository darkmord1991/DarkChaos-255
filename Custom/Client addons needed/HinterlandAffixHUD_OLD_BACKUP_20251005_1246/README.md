# Hinterland Battleground Addon

## Overview
The Hinterland Battleground Addon enhances your experience in the custom Hinterland 25v25 PvP battleground. It provides a heads-up display showing the current affix, resources, timers, and other information crucial to gameplay. The addon also offers a comprehensive UI for viewing match history, statistics, and joining the queue.

## Version
1.5.0

## Features
- **Live Battle HUD**: Shows real-time resources, player counts, and time remaining
- **Match History**: View details of your past battleground matches
- **Statistics**: See your win/loss rates and performance metrics
- **Affix Information**: Detailed explanation of all possible battleground affixes
- **Queue Management**: Join the queue and see estimated wait times
- **Settings**: Customize the addon's behavior and appearance
- **Help System**: In-game documentation and FAQ

## Installation
- Copy the `HinterlandAffixHUD` folder to your WoW/Interface/AddOns directory on your client.
- Ensure the AIO_Client addon is installed (required dependency)
- Restart the client or use `/reload`.

## Usage
- Type `/hlbg` or `/hinterland` to open the main interface
- Join the battleground queue via the Queue tab or with `/hlbg queue join`
- Configure the addon's settings in the Settings tab or with `/hlbgconfig`

## Commands
- `/hlbg` - Open the main interface
- `/hlbg queue join` - Join the battleground queue
- `/hlbg queue leave` - Leave the battleground queue
- `/hlbg status` - Show current battleground status
- `/hlbg debug [on|off]` - Enable or disable debug mode
- `/hlbg season <n>` - Set the season filter (0 = all/current)
- `/hlbgconfig` - Open the addon settings panel
- `/hinterland` - Alias for /hlbg

Legacy commands:
- `/hlaffix dump` - List current worldstates (helps identify the right ID)
- `/hlaffix id <number|0xHEX>` - Set the affix worldstate ID (default 0xDD1010)
- `/hlaffix hide on|off` - Hide/show Blizzard's WG-style HUD

## Customization
The addon offers various customization options in the Settings tab:
- Toggle chat notifications for battleground events
- Adjust HUD scale and position
- Configure auto-teleport and notification settings
- Enable developer mode for debugging

## Troubleshooting
If you encounter issues with the addon:
1. Make sure AIO_Client is installed and working
2. Check if the addon is enabled in your AddOns list
3. Enable debug mode with `/hlbg debug on` and check for error messages
4. Try reloading your UI with `/reload`

## Credits
- Created by DC-255
- For the Hinterland Battleground custom content on DarkChaos-255 server
====================

HinterlandAffixHUD
------------------
A tiny addon that shows the current Hinterland BG affix (and weather) near the WG-style HUD. It reads a custom worldstate value sent by the server and falls back to parsing server announcements.

Install:
- Copy the `HinterlandAffixHUD` folder to your WoW/Interface/AddOns directory on your client.
- Restart the client or use `/reload`.

Usage:
- /hlaffix dump — list current worldstates (helps identify the right ID)
- /hlaffix id <number|0xHEX> — set the affix worldstate ID (default 0xDD1010)
- /hlaffix hide on|off — hide/show Blizzard’s WG-style HUD (so the addon “replaces” it visually)

Notes:
- Requires the server to send the custom worldstate ID and announcements (Affix/Weather lines) for best results.
- You can reposition by editing the `SetPoint` line in `HinterlandAffixHUD.lua`.
- Affix names map: 0=None, 1=Haste, 2=Slow, 3=Reduced Healing, 4=Reduced Armor, 5=Boss Enrage.
