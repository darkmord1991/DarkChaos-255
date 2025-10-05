# HinterlandAffixHUD Loading Order

For WoW 3.3.5a compatibility, the addon must load files in a specific order to ensure compatibility layers are in place before features are used.

## Critical Loading Order

1. **HLBG_TimerCompat.lua** - Must load first to provide C_Timer API compatibility
2. **HLBG_DebugBootstrap.lua** - Provides debug foundation
3. **HLBG_Compatibility.lua** - Additional compatibility functions
4. **HLBG_Debug_Helper.lua** - Debug utilities

After these core compatibility files, the rest of the addon can load in any order.

## Common Issues

If the WoW client fails to load with this addon:

1. Verify the .toc file lists HLBG_TimerCompat.lua first
2. Check for any functions using modern APIs without compatibility layers
3. Look for duplicate function definitions that may be causing conflicts
4. Verify AIO_Client addon is installed and loaded before this addon

## Compatibility Layer Features

### C_Timer API

The HLBG_TimerCompat.lua file provides these APIs for WoW 3.3.5a:

- C_Timer.After(seconds, callback)
- C_Timer.NewTimer(seconds, callback)
- C_Timer.NewTicker(seconds, callback, iterations)

These functions are used throughout the addon for scheduling and UI updates.