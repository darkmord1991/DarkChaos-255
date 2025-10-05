# Hinterland BG UI Fixes Implementation Guide

## Overview

This document provides a quick guide for implementing the fixes to the Hinterland Battleground UI. The fixes address two main issues:
1. UI errors related to scroll frames
2. Missing C_Timer API in WoW 3.3.5a

## Files Added/Modified

### New Files:
- **HLBG_Compatibility.lua** - Compatibility layer for WoW 3.3.5a
- **HLBG_Debug_Helper.lua** - Enhanced debugging tools
- **UI_FIXES_CHANGELOG.md** - Documentation of changes

### Modified Files:
- **HinterlandAffixHUD.toc** - Updated file loading order and version
- **HLBG_UI_Helpers.lua** - Removed redundant C_Timer implementation

## Implementation Steps

1. **Backup Original Files**
   ```
   mkdir backup_hlbg
   copy *.* backup_hlbg\
   ```

2. **Copy New Files**
   - Copy the new HLBG_Compatibility.lua to the addon folder
   - Copy the new HLBG_Debug_Helper.lua to the addon folder

3. **Replace Modified Files**
   - Replace HLBG_UI_Helpers.lua with the updated version
   - Replace HinterlandAffixHUD.toc with the updated version

4. **Update Version Number**
   - The TOC file has been updated to version 1.5.3

## Testing

To test the fixes:

1. Launch WoW client
2. Login to a character
3. Use the following slash commands to help with debugging:
   - `/hlbgdebug` - Toggle the debug window
   - `/hlbgdebug verbose` - Set debug level to verbose for more information
   - `/hlbgdebug ui` - Apply UI fixes manually
   
4. Open the Hinterland BG interface and verify:
   - All tabs open without errors
   - Scroll frames work correctly
   - Settings are saved properly

## Troubleshooting

If issues persist:

1. Check the debug output (`/hlbgdebug`)
2. Verify the loading order in the TOC file
3. Ensure no errors appear in the chat window

## Key Changes

### Compatibility Layer
- Implements C_Timer.After, C_Timer.Cancel, and C_Timer.NewTicker
- Adds missing string functions
- Includes version detection
- Provides a SafeCall wrapper for error handling

### Debug Helpers
- Visual debug frame for detailed inspection
- Configurable debug levels
- Easy logging via HLBG.Debug.Error(), HLBG.Debug.Info(), etc.
- Slash command integration

## Contact

For questions or issues, contact the developer at [your-email@example.com].