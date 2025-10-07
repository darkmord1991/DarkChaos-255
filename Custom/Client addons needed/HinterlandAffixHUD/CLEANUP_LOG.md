# Files Removed During Cleanup (October 7, 2025)

## Backup/Old TOC Files (4 files removed)
- HinterlandAffixHUD.toc.backup-failed
- HinterlandAffixHUD_Emergency.toc  
- HinterlandAffixHUD_MinimalTest.toc
- HinterlandAffixHUD_Test6B_shim.toc

## Obsolete/Duplicate Functionality Files (15 files removed)
- HLBG_HUD.lua (replaced by HLBG_HUD_Modern.lua)
- HLBG_AIO.lua (obsolete AIO handler)
- HLBG_AIO_Client.lua (obsolete AIO handler)
- HLBG_AIO_Shim.lua (obsolete AIO handler)
- HLBG_UI_History_Fixed.lua (integrated into main HLBG_UI.lua)
- HLBG_UI_Info.lua (duplicate of functionality in HLBG_Info.lua)
- HLBG_UI_Info_Enhanced.lua (duplicate)
- HLBG_UI_Settings.lua (duplicate of functionality in HLBG_Settings.lua)  
- HLBG_UI_Settings_Enhanced.lua (duplicate)
- HLBG_UI_Stats.lua (integrated into modern UI system)
- HLBG_UI_Stats_Enhanced.lua (duplicate)
- HLBG_UI_Scoreboard_Modern.lua (unused)
- HLBG_DebugBootstrap_Safe.lua (duplicate of HLBG_DebugBootstrap.lua)
- HLBG_UI_Helpers.lua (functionality moved to HLBG_UI_Modern.lua)
- HLBG_UI_Integrator.lua (unused integration layer)

## Legacy/Unused Files (17 files removed)
- HLBG_335a_Compatibility_Checks.lua (replaced by HLBG_Compatibility.lua)
- HLBG_Affixes.lua (unused affix system)
- HLBG_AntiFlicker.lua (unused optimization)
- HLBG_DedupeHUD.lua (unused HUD deduplication)
- HLBG_Diagnostic.lua (replaced by HLBG_WorldstateDebug.lua)
- HLBG_Diagnostics_Shared.lua (unused diagnostic system)
- HLBG_EmergencyCleanup.lua (temporary emergency file)
- HLBG_FileLoader.lua (unused file loading system)
- HLBG_HistoryHandler.lua (integrated into HLBG_UI.lua)
- HLBG_Integration_Enhanced.lua (unused integration layer)
- HLBG_RequestManager.lua (unused request management)
- HLBG_Stability.lua (replaced by HLBG_ErrorFixes.lua)
- HLBG_StatsHandler.lua (integrated into HLBG_UI.lua)
- HLBG_TabStability.lua (integrated into modern UI system)
- HLBG_Telemetry.lua (unused telemetry system)
- HLBG_Troubleshooter.lua (replaced by HLBG_WorldstateDebug.lua)
- HLBG_ZoneDetect.lua (unused zone detection)

## Documentation Consolidation (5 files removed)
- ENHANCEMENT_SUMMARY.md (consolidated into STABILITY_FIXES_APPLIED.md)
- INSTRUCTIONS.md (consolidated into README.md)
- LOAD_ORDER.md (consolidated into STABILITY_FIXES_APPLIED.md)
- TROUBLESHOOTING.md (consolidated into README.md)  
- UI_FIXES_CHANGELOG.md (consolidated into STABILITY_FIXES_APPLIED.md)

## Total Files Removed: 41
## Files Kept: 26 active files + 3 documentation files = 29 total

This cleanup removed 58% of the files while maintaining all functionality.