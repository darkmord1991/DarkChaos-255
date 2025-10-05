# HinterlandAffixHUD Troubleshooting

## Client Loading Issues

If your client is not loading with the addon enabled, please try the following steps:

### Step 1: Try the Emergency Version
1. Rename `HinterlandAffixHUD.toc` to `HinterlandAffixHUD.toc.original`
2. Rename `HinterlandAffixHUD_Emergency.toc` to `HinterlandAffixHUD.toc`
3. Start WoW and see if the minimal version loads
4. If it loads, use `/hlbgtrouble` to run diagnostics

### Step 2: Check Dependencies
1. Make sure you have the `AIO_Client` addon installed and enabled
2. Check if other addons might be causing conflicts

### Step 3: Loading Order Issues
The order of files in the TOC file is critical. The files MUST load in this exact order:
1. HLBG_LoadDebug.lua
2. HLBG_TimerCompat.lua
3. (other files)

### Common Issues and Fixes

1. **"C_Timer not found" errors**
   - This means the compatibility layer isn't loading correctly
   - Make sure HLBG_TimerCompat.lua is the SECOND file in the TOC

2. **Duplicate Function Errors**
   - These occur when the same function is defined multiple times
   - We've fixed this in HLBG_AIO_Client.lua

3. **Missing AIO Addon**
   - HinterlandAffixHUD requires AIO_Client to be installed and enabled
   - Check if AIO_Client is in your addons folder and enabled

4. **Using Diagnostic Commands**
   - `/hlbgtrouble` - Runs all diagnostics
   - `/hlbgdiag` - Shows basic loading information
   - `/hlbgloadfile list` - Lists all available files
   - `/hlbgloadfile filename` - Tries to load a specific file

## For Advanced Users

If you're comfortable with Lua and WoW addons, you can try:

1. Opening a single file at a time to identify which one causes issues
2. Using the emergency TOC and adding files one by one
3. Checking for errors in the client's error.log file

## Report Issues

If you continue to experience problems, please collect the output of `/hlbgtrouble` and report it to the addon author.

Last updated: October 2023