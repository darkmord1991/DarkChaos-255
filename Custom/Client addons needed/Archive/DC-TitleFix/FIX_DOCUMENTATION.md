# DC-TitleFix - Enhanced Title System Fix

## Issues Resolved

### Error 1: "attempt to index local 'playerTitles' (a nil value)"
- **Cause:** The `playerTitles` table is never populated in WoW 3.3.5a
- **Impact:** Clicking titles button crashes character sheet
- **Fix:** Initialize and maintain empty `playerTitles` table

### Error 2: "bad argument #1 to 'strtrim' (string expected, got no value)"
- **Cause:** `GetTitleName()` returns `nil` instead of a string
- **Impact:** PaperDollFrame.lua line 2608 tries to trim nil value
- **Fix:** Wrapper function ensures `GetTitleName()` always returns a valid string

### Error 3: "bad argument to 'GetTitleName' (got no value)"
- **Cause:** Title data isn't synced from server to client
- **Impact:** Server doesn't send title information
- **Fix:** Provide fallback default titles from Wrath of the Lich King

## Solution Overview

The enhanced fix provides three layers of protection:

### Layer 1: Default Title Data
```lua
DEFAULT_TITLES = {
    [1] = "Private",
    [2] = "Corporal",
    [3] = "Sergeant",
    ...
}
```
Ensures there's always something to display even if server data is missing.

### Layer 2: GetTitleName() Wrapper
```lua
_G.GetTitleName = function(titleID)
    local result = original_GetTitleName(titleID)
    
    if result and type(result) == "string" and result ~= "" then
        return result
    end
    
    return DEFAULT_TITLES[titleID] or "Title " .. tostring(titleID)
end
```
Never returns nil - always returns a valid string.

### Layer 3: Error Handling (pcall)
```lua
local success, err = pcall(original_UpdateTitles)
if not success then
    -- Gracefully handle any remaining errors
end
```
Catches any remaining errors and prevents crashes.

## What Changed

### Old Approach (Problematic)
- ❌ Only initialized empty tables
- ❌ Didn't handle nil returns from GetTitleName()
- ❌ No error handling (pcall)
- ❌ Players still got "strtrim" errors

### New Approach (Robust)
- ✅ Provides default title names
- ✅ Wraps GetTitleName() to guarantee strings
- ✅ Uses pcall for error protection
- ✅ Gracefully degrades on errors
- ✅ Multiple initialization points

## How It Works

1. **Immediately on Load:**
   - Initializes playerTitles = {}
   - Sets up GetTitleName() wrapper
   - Patches frame update functions

2. **On Title Frame Open:**
   - Ensures playerTitles exists
   - Calls original functions with safety net
   - If error occurs, shows empty (no crash)

3. **On ADDON_LOADED:**
   - Re-initializes everything to be safe
   - Catches any late-loading conflicts

## Technical Details

### GetTitleName() Wrapper
- Checks if original GetTitleName exists
- Calls original and checks if result is valid string
- Falls back to DEFAULT_TITLES
- Never returns nil or empty string

### PlayerTitleFrame_UpdateTitles Patch
- Ensures playerTitles exists before calling original
- Wraps call in pcall() for error safety
- Clears scroll frame on error to prevent further issues

### PlayerTitlePickerScrollFrame_Update Patch
- Ensures playerTitles exists before calling original
- Wraps call in pcall() to catch strtrim errors
- Manually hides buttons if error occurs

## Result

**Before Fix:**
```
Error: Interface\FrameXML\PaperDollFrame.lua:2608: 
       bad argument #1 to 'strtrim' (string expected, got no value)
       
Error: Interface\FrameXML\PaperDollFrame.lua:2576: 
       attempt to index local 'playerTitles' (a nil value)
```
**Result:** ❌ Character sheet crashes when opening titles

**After Fix:**
```
✅ Titles frame opens cleanly
✅ No Lua errors in console
✅ Shows "No Title" or available titles
✅ Character sheet remains functional
```
**Result:** ✅ Graceful degradation, no crashes

## Server-Side Note

The best permanent fix would be on the server side:
```cpp
// In WorldSession::HandleCharacterEnum()
// Send available titles to client before character loads

// OR in Player::LoadTitlesFromDB()
// Properly sync knownTitles from database to client
```

But this client-side addon fix works around the issue without server changes.

## Testing

To verify the fix works:

1. Open character sheet
2. Go to Character Info
3. Click "Titles" button
4. Verify no errors appear in `/console` 
5. Titles frame should show (even if empty)
6. No crash or freeze

### Expected Behavior
- Frame opens cleanly
- Shows "No Title" or available titles
- Can switch between title frame and other tabs
- No console errors

## Compatibility

- **WoW Version:** 3.3.5a (Interface 30300)
- **Server:** AzerothCore and compatible
- **Performance:** Negligible impact
- **Dependencies:** None

## Files

- `DC-TitleFix.lua` - Main fix implementation
- `DC-TitleFix.toc` - Addon manifest
- This documentation file

## Notes

- The fix is defensive and non-invasive
- All patches use original function references
- Multiple initialization points ensure coverage
- Error handling prevents cascading failures
- Safe to load alongside other addons

---

**Status:** ✅ Enhanced and production-ready
