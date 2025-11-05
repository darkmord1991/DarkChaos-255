# DarkChaos Item Upgrade Addon

A retail-like visual interface for the AzerothCore item upgrade system.

## Features

- **Retail-like Interface**: Clean, professional UI that resembles the actual WoW item upgrade interface
- **Item Selection**: Click and drag items from your inventory/bags or browse upgradable items
- **Dynamic Stats Display**: Shows current item stats and previews upgraded stats
- **Cost Calculation**: Real-time calculation of upgrade costs (tokens/essence)
- **Level Selection**: Slider to choose how many levels to upgrade (1-15)
- **Server Integration**: Full integration with the DarkChaos item upgrade system

## Installation

1. Copy the `DarkChaos_ItemUpgrade` folder to your `World of Warcraft/Interface/AddOns/` directory
2. Ensure the addon is enabled in the character select screen
3. The addon will automatically load when you enter the game

## Usage

### Opening the Interface

- Type `/dcupgrade` or `/itemupgrade` in chat
- The interface will open showing the item upgrade window

### Upgrading Items

1. **Select an Item**:
   - Click the item slot in the upgrade window
   - Drag an item from your inventory/bags onto the slot
   - Browse your upgradable items in the inventory panel

2. **Choose Upgrade Level**:
   - Use the slider to select your target upgrade level (1-15)
   - The interface will show updated costs and stats in real-time

3. **Review Changes**:
   - Current stats are shown on the left
   - Upgraded stats are previewed on the right
   - Upgrade costs are displayed in the cost panel

4. **Perform Upgrade**:
   - Click "Upgrade Item" to confirm
   - The system will deduct costs and apply the upgrade
   - Stats will update automatically

### Interface Elements

- **Item Slot**: Click to open inventory browser or drag items here
- **Item Info**: Shows item name, current level, and upgrade progress
- **Level Slider**: Select target upgrade level (current to max)
- **Cost Display**: Shows required tokens and/or essence
- **Stats Panels**: Compare current vs upgraded item statistics
- **Upgrade Button**: Confirms and performs the upgrade

## Server Requirements

This addon requires the DarkChaos Item Upgrade system to be installed on the server. The addon communicates with server-side scripts to:

- Retrieve item upgrade information
- Calculate upgrade costs
- Perform upgrades
- Track player currency (tokens/essence)

## Technical Details

### Files

- `DarkChaos_ItemUpgrade.toc`: Addon table of contents
- `DarkChaos_ItemUpgrade.xml`: UI frame definitions
- `DarkChaos_ItemUpgrade.lua`: Main addon logic and server communication

### Server Communication

The addon uses custom opcodes to communicate with the server:

- `CMSG_ITEM_UPGRADE_REQUEST_INFO`: Request item upgrade data
- `SMSG_ITEM_UPGRADE_INFO_RESPONSE`: Receive item upgrade information
- `CMSG_ITEM_UPGRADE_PERFORM`: Send upgrade request
- `SMSG_ITEM_UPGRADE_RESULT`: Receive upgrade result
- `CMSG_ITEM_UPGRADE_INVENTORY_SCAN`: Request upgradable items list
- `SMSG_ITEM_UPGRADE_INVENTORY_LIST`: Receive upgradable items

### Dependencies

- AzerothCore server with DarkChaos Item Upgrade system
- Compatible with WoW 3.3.5a (Wrath of the Lich King)

## Troubleshooting

### Addon Not Loading
- Ensure the addon folder is in the correct location
- Check that the addon is enabled in the character select screen
- Verify your WoW client version is compatible

### Server Connection Issues
- Ensure you're connected to a server with the DarkChaos Item Upgrade system
- Check that server-side scripts are properly loaded
- Verify your account has proper permissions

### Item Not Upgrading
- Confirm you have sufficient currency (tokens/essence)
- Check that the item is eligible for upgrading
- Verify your character level meets requirements

## Support

For issues or questions:
1. Check the server logs for error messages
2. Verify addon and server versions are compatible
3. Contact the DarkChaos development team

## Version History

### 1.0.0
- Initial release
- Retail-like interface design
- Full server integration
- Item selection and upgrade functionality
- Real-time cost and stat calculations