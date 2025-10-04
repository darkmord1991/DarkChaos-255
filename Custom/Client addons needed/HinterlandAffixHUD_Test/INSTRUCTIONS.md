# HinterlandAffixHUD Test Version

This is a test version of the HinterlandAffixHUD addon with fixes for loading issues. Follow these steps to test it:

## Installation

1. Copy the entire `HinterlandAffixHUD_Test` folder to your WoW addons directory:
   - Usually located at: `World of Warcraft\Interface\AddOns\`
   - Rename this folder from `HinterlandAffixHUD_Test` to `HinterlandAffixHUD` when placing it in your addons directory

## Testing Steps

1. **Standard Test**:
   - Launch WoW with the addon enabled
   - If it loads successfully, use the `/hlbg` command to verify functionality

2. **If the addon fails to load**:
   - Rename `HinterlandAffixHUD.toc` to `HinterlandAffixHUD.toc.original`
   - Rename `HinterlandAffixHUD_Emergency.toc` to `HinterlandAffixHUD.toc`
   - Launch WoW again with the emergency version
   - Use the `/hlbgtrouble` command to run diagnostics

3. **Diagnostic Commands**:
   - `/hlbgtrouble` - Runs comprehensive diagnostics
   - `/hlbgdiag` - Shows basic loading information
   - `/hlbgloadfile list` - Lists all available files
   - `/hlbgloadfile filename` - Tests loading a specific file

## Key Fixes in This Version

1. **Fixed duplicate function definitions** - Removed redundant copies of functions
2. **Improved compatibility layer** - Better C_Timer implementation for WoW 3.3.5
3. **Fixed loading order** - Critical files now load in the correct sequence
4. **Added diagnostics** - Tools to troubleshoot issues if they persist
5. **Fixed corrupt code** - Repaired malformed functions with misplaced API calls

## Requirements

- AIO_Client addon must be installed and enabled
- This addon is specifically for WoW 3.3.5a client version

## Troubleshooting

If you encounter any issues, please see the TROUBLESHOOTING.md file for detailed steps.

Created: October 2023