# Hinterland Battleground Addon (Modern Edition)

## Overview
The Hinterland Battleground Addon provides a comprehensive interface for the custom Hinterland 25v25 PvP battleground on DarkChaos-255 server. Features include a modern HUD, match history, statistics, and queue management with enhanced stability and visual design.

## Version
1.5.7-emergency (Modern UI Edition)

## ✨ Modern Features
- **🎨 Modern UI Design**: Dark theme with professional styling, card-based layouts
- **📊 Real-time HUD**: Moveable modern HUD showing Alliance/Horde resources and battle status  
- **📈 Statistics Dashboard**: Beautiful card-based stats display with win/loss rates and performance metrics
- **📋 Match History**: Enhanced history viewer with sorting and pagination
- **🎯 Smart Content Loading**: Automatic test data population when server data unavailable
- **🔧 Enhanced Error Handling**: Comprehensive compatibility fixes for WoW 3.3.5a
- **💬 Debug Tools**: Advanced debugging commands for troubleshooting

## 🚀 Quick Start
1. **Installation**: Copy `HinterlandAffixHUD` folder to `WoW/Interface/AddOns/`
2. **Dependencies**: Ensure `AIO_Client` addon is installed
3. **Launch**: Use `/reload` then `/hlbg show` to open the modern interface

## 📋 Command Reference

### Primary Commands
- `/hlbg show` - Open the modernized main window
- `/hlbg hide` - Close the main window  
- `/hlbg reload` - Reload all UI components
- `/hlbg testdata` - Load test data for empty tabs
- `/hlbg style` - Reapply modern styling
- `/hlbg stats` - Refresh statistics display

### Debug & Troubleshooting
- `/hlbgws` - Show all worldstate values (HUD sync debugging)
- `/hlbgdiag` - Diagnose empty tabs and UI issues
- `/hlbgdebug ws` - Worldstate debugging info
- `/hlbgdebug hud` - Force HUD update

### Legacy Support
- `/hlaffix dump` - List current worldstates  
- `/hlaffix id <number>` - Set affix worldstate ID
- `/hlaffix hide on|off` - Toggle Blizzard HUD visibility

## 🎯 Key Improvements

### ✅ Fixed Issues
- **Background Affix HUD**: Completely disabled conflicting background HUD
- **Live Tab**: Removed redundant Live tab, restructured tab system
- **Empty Tabs**: Enhanced content loading with immediate fallback data
- **HUD Sync**: Improved worldstate parsing for reliable Alliance/Horde resource display
- **Modern Styling**: Professional dark theme with hover effects and smooth animations

### 🔧 Technical Enhancements  
- **C_Timer Compatibility**: Full 3.3.5a compatibility layer
- **Safe AIO Operations**: Graceful fallback when AIO unavailable
- **Enhanced Error Handling**: Comprehensive error catching and recovery
- **Smart Initialization**: Multiple retry mechanisms ensure reliable loading

## 📊 Interface Tabs

### 🗂️ History Tab
- Enhanced battle history with modern row styling
- Sortable columns and pagination controls
- Immediate test data loading if server data unavailable
- Color-coded faction indicators

### 📈 Stats Tab  
- Beautiful 2x3 card grid layout showing key metrics
- Real-time win/loss rates and performance statistics
- Refresh button for manual data updates
- Fallback data when server statistics unavailable

### ℹ️ Info Tab
- Comprehensive battleground information and rules
- Affix explanations and strategy guides
- Modern formatting with enhanced readability

## 🛠️ Troubleshooting

### Common Issues
1. **Empty Tabs**: Use `/hlbgdiag` to check status, `/hlbg testdata` to load sample data
2. **HUD Not Syncing**: Use `/hlbgws` to verify worldstate data availability
3. **UI Not Loading**: Use `/hlbg reload` to reinitialize all components
4. **Missing Modern Styling**: Use `/hlbg style` to reapply visual enhancements

### Debug Information
- Enable comprehensive logging with `/hlbgdebug ws`
- Check worldstate sync with `/hlbgws` command
- Diagnose tab content issues with `/hlbgdiag`

## 📁 File Structure (Post-Cleanup)
**Active Files (29 total):**
- Core: `HinterlandAffixHUD.lua`, `HLBG_Core.lua`, `HLBG_UI.lua`
- Modern UI: `HLBG_HUD_Modern.lua`, `HLBG_UI_Modern.lua`
- Compatibility: `HLBG_ErrorFixes.lua`, `HLBG_Compatibility.lua`
- Features: `HLBG_Settings.lua`, `HLBG_Help.lua`, `HLBG_SlashCommands.lua`
- Debug: `HLBG_WorldstateDebug.lua`, `HLBG_Debug_Helper.lua`

**Removed in Cleanup (41 files):**
- Duplicate functionality files, legacy implementations, backup TOC files
- See `CLEANUP_LOG.md` for complete removal details

## 💡 Tips
- **First Time Users**: The addon automatically loads test data if no server data is available
- **HUD Positioning**: Drag the modern HUD to reposition it on screen
- **Tab Navigation**: Use mouse or keyboard shortcuts to switch between tabs
- **Performance**: Modern UI is optimized for smooth performance on 3.3.5a clients

## 🏆 Credits
- **Created by**: DC-255
- **Server**: DarkChaos-255 Hinterland Battleground
- **Modern UI**: Enhanced with professional styling and improved UX
- **Compatibility**: Optimized for WoW 3.3.5a with comprehensive error handling