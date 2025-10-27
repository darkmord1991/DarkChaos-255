-- .luacheckrc: repo-level configuration
-- Ignore common vendor/library folders to reduce noise
ignore_files = {
  "Custom/**/Libs/**",
  "Custom/**/Ace3/**",
  "Custom/**/Archive/**",
  "Custom/**/Mapster/**",
  "Custom/**/WDM/**",
  "Custom/**/GatherMate/**",
}
-- also ignore common vendor/lib name variations
table.insert(ignore_files, "Custom/**/Lib/**")
table.insert(ignore_files, "Custom/**/vendor/**")
table.insert(ignore_files, "Custom/**/libs/**")

-- Use Lua 5.1 standard (WoW uses ~5.1 semantics)
std = 'lua51'

-- Don't be too strict on line length for older vendor code; keep reasonably large limit
-- Allow a larger max line length to accomodate long, intentional debug strings in addons.
max_line_length = 300

-- Declare common WoW API globals and vendor globals to avoid spurious 'undefined' warnings
read_globals = {
  -- WoW APIs
  'CreateFrame', 'GetTime', 'UnitName', 'UnitClass', 'UnitRace', 'UnitFactionGroup', 'GetRealmName',
  'PlaySound', 'StaticPopup_Show', 'InterfaceOptions_AddCategory', 'GameTooltip', 'GetFrameRate', 'GetFramerate',
  'hooksecurefunc', 'wipe', 'DEFAULT_CHAT_FRAME', 'SELECTED_CHAT_FRAME', 'NORMAL_FONT_COLOR',
  'GameFontHighlight', 'GameFontHighlightLarge', 'GameFontHighlightSmall', 'CloseSpecialWindows',
  -- Common vendor globals
  'LibStub', 'ChatThrottleLib', 'Astrolabe', 'AstrolabeMapMonitor', 'DongleStub',
}

-- Addons-specific and common WoW globals used across this repo (reduce spurious "undefined" warnings)
for _, g in ipairs({
  'UIParent','WorldMapFrame','WorldMapDetailFrame','Minimap','GetCursorPosition','GetPlayerMapPosition',
  'GetRealZoneText','GetSubZoneText','GetCurrentMapAreaID','GetMapInfo','SetMapByID','SetMapToMapID',
  'GetNumWorldStateUI','GetWorldStateUIInfo','SecondsToTime','C_Timer','C_Timer_After','date','SendAddonMessage',
  'SendChatMessage','ChatEdit_SendText','ChatFrame1EditBox','GetNumGroupMembers','GetBattlefieldStatus',
  -- addon saved-vars & helpers present in Custom/* (DC-* / HLBG etc.)
  'DCMapExtensionDB','DCMap_StitchFrame',
  -- DC/HLBG/RestoreXP specific globals
  'DCRestoreXPDB','DCRestoreXP','DCRXPTEST','DCRXPOPTS','SLASH_DCRXPTEST1','SLASH_DCRXP1','SLASH_DCRXPOPTS1',
  'DCMap_*','DCMap_StitchFrame',
  'DCHLBGDB','HLBG','DCHLBG_DebugLog','AIO',
  -- Map/tile constants and texture types
  'PNG_POT_TEXTURE','PNG_TEXTURE','BLP_TEXTURE','NUM_WORLDMAP_DETAIL_TILES','MAP_ID_AZSHARA_CRATER',
  -- common helper libs and integration hooks
  'Mapster','Mapster_Initialize','MapsterOptions',
  -- UI widgets and frames
  'InterfaceOptionsFramePanelContainer','InterfaceOptionsFrame','GameFontNormalSmall','UIErrorsFrame','ShowUIPanel',
  -- addon messaging / timers / json
  'RegisterAddonMessagePrefix','RegisterAddonMessagePrefix','SendAddonMessage','C_Timer','C_Timer_After',
  'json_decode','json_encode',
}) do
  table.insert(read_globals, g)
end

-- Some globals are intentionally created/modified by addons (saved-vars, stitched frames, etc.).
-- Declare them as writable globals so luacheck doesn't warn when files assign to them.
globals = {
  'DCMapExtensionDB', 'DCMap_HotspotsSaved', 'DCMap_MapBounds', 'DCMap_StitchFrame',
  'DCRestoreXPDB','DCRestoreXP','DCRXPTEST','DCRXPOPTS',
  'DCHLBGDB','HLBG','DCHLBG_DebugLog','AIO',
  'SLASH_DCMAP1','SLASH_DCMAPBOUNDS1','SLASH_DCMAPREFLOW1','SLASH_DCRXP1','SLASH_DCRXPOPTS1',
  'PNG_POT_TEXTURE','PNG_TEXTURE','BLP_TEXTURE','NUM_WORLDMAP_DETAIL_TILES','MAP_ID_AZSHARA_CRATER'
}

-- Additional writable globals and helper names observed in DC-MapExtension
table.insert(globals, 'EnsureMapsterIntegration')
table.insert(globals, 'PrintReflowSnapshot')
table.insert(globals, 'PrintTextureDiagnosticsOnce')
table.insert(globals, 'ResilientShowStitch')
table.insert(globals, 'ReportClickToChatWithMapCoords')
table.insert(globals, 'ReportClickToChat')
table.insert(globals, 'DCMAP')
table.insert(globals, 'DCMAPBOUNDS')
table.insert(globals, 'DCMAPREFLOW')
-- Ensure SlashCmdList and common saved-vars are writable to allow addons to set fields
table.insert(globals, 'SlashCmdList')
table.insert(globals, 'DCMap_HotspotsSaved')

-- Allow non-standard globals (mutations) in WoW addons
allow_defined_globals = true
