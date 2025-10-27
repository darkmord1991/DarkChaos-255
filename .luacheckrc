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

-- Use Lua 5.1 standard (WoW uses ~5.1 semantics)
std = 'lua51'

-- Don't be too strict on line length for older vendor code; keep reasonably large limit
max_line_length = 200

-- Declare common WoW API globals and vendor globals to avoid spurious 'undefined' warnings
read_globals = {
  -- WoW APIs
  'CreateFrame', 'GetTime', 'UnitName', 'UnitClass', 'UnitRace', 'UnitFactionGroup', 'GetRealmName',
  'PlaySound', 'StaticPopup_Show', 'InterfaceOptions_AddCategory', 'GameTooltip', 'GetFrameRate', 'GetFramerate',
  'hooksecurefunc', 'wipe', 'DEFAULT_CHAT_FRAME', 'SELECTED_CHAT_FRAME', 'NORMAL_FONT_COLOR',
  'GameFontHighlight', 'GameFontHighlightLarge', 'GameFontHighlightSmall', 'CloseSpecialWindows',
  -- Common vendor globals
  'LibStub', 'ChatThrottleLib', 'Astrolabe', 'AstrolabeMapMonitor', 'DongleStub', 'SlashCmdList',
}

-- Allow non-standard globals (mutations) in WoW addons
allow_defined_globals = true
