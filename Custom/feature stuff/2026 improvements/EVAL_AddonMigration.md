# Addon Communication Migration Report

## Overview
This document outlines the systems currently using legacy communication methods (AIO, Chat Prefixes, or raw Addon Messages) and provides a plan to migrate them to the new `AddonExtension` system.

**Current Status:** The `src/server/scripts/DC/AddonExtension` directory already contains modern handlers (`dc_addon_hlbg.cpp`, `dc_addon_mythicplus.cpp`, `dc_addon_gomove.cpp`, `dc_addon_seasons.cpp`), effectively duplicating the logic. The goal is to switch the core systems to use these new handlers and remove the legacy code.

## 1. Hinterland BG (HLBG)

### Current State
- **Legacy Handler:** `src/server/scripts/DC/HinterlandBG/hlbg_addon.cpp`
  - Uses chat prefixes (e.g., `[HLBG_LIVE_JSON]`, `[HLBG_QUEUE]`) to communicate with the client.
  - Implements its own command handling for `.hlbg queue`.
- **New Handler:** `src/server/scripts/DC/AddonExtension/dc_addon_hlbg.cpp`
  - Fully implements binary/opcode protocol (Status, Resources, Queue, Stats, Leaderboards).
- **Client:** `Custom/Client addons needed/DC-HinterlandBG`
  - Contains `HLBG_AIO_Check.lua` and likely relies on the chat prefix parsing or legacy AIO checks.

### Required Actions
1.  **Server:** Deprecate and remove `hlbg_addon.cpp`.
2.  **Server:** Ensure `OutdoorPvPHL` (the core logic) calls `DCAddon::HLBG::SendStatus` / `SendUpdate` instead of its internal string builders.
3.  **Client:** Update `DC-HinterlandBG` to use `DCAddon` protocol Opcodes (1-6 for CMSG, 16-24 for SMSG).
4.  **Cleanup:** Remove `HLBG_AIO_Check.lua`.

## 2. Mythic+ System

### Current State
- **Legacy Logic:** `src/server/scripts/DC/MythicPlus/MythicPlusRunManager.cpp`
  - Contains `MaybeSendAioSnapshot` which builds a massive JSON string.
  - Conditionally includes `AIO.h`.
- **New Handler:** `src/server/scripts/DC/AddonExtension/dc_addon_mythicplus.cpp`
  - Exists and presumably implements the `MYTHIC_PLUS` module opcodes.
- **Client:** `Custom/Client addons needed/DC-MythicPlus`
  - Likely listening for the JSON snapshot via AIO channel.

### Required Actions
1.  **Server:** Refactor `MythicPlusRunManager::UpdateHud`. Instead of calling `MaybeSendAioSnapshot`, it should trigger `DCAddon::MythicPlus::SendHudUpdate(state)`.
2.  **Server:** Move the JSON serialization logic (if still needed for the new protocol) or the binary serialization logic into `dc_addon_mythicplus.cpp`.
3.  **Server:** Remove `AIO.h` dependency.
4.  **Client:** Audit `DC-MythicPlus` to ensure it parses the new `DCAddon` packets.

## 3. GOMove

### Current State
- **Legacy Logic:** `src/server/scripts/DC/GOMove/GOMove.cpp`
  - Uses manual `SendAddonMessage` with `SMSG_MESSAGECHAT` and `GOMOVE` prefix.
- **New Handler:** `src/server/scripts/DC/AddonExtension/dc_addon_gomove.cpp`
  - Exists and implements the `GOMOVE` module.

### Required Actions
1.  **Server:** Modify `GOMove::SendAddonMessage` (or its call sites like `SendAdd`/`SendRemove`) to call `DCAddon::GOMove::SendPacket` instead.
2.  **Server:** Ensure the `GOMove` class interacts correctly with the `DCAddon` namespace.
3.  **Client:** If using a custom GOMove client adaptation, update it to use `DCAddon` channel/prefix.

## 4. Seasonal Rewards

### Current State
- **Legacy Logic:** `src/server/scripts/DC/Seasons/SeasonalRewardSystem.cpp`
  - `NotifyPlayer` sends simple chat messages (`PSendSysMessage`) as a placeholder.
- **New Handler:** `src/server/scripts/DC/AddonExtension/dc_addon_seasons.cpp`
  - Exists.

### Required Actions
1.  **Server:** Update `SeasonalRewardSystem::NotifyPlayer` to call `DCAddon::Seasons::SendRewardNotification`.
2.  **Client:** Ensure client has a notification frame to handle this opcode.

## 5. General Cleanup

### Required Actions
1.  **Delete:** `src/server/scripts/DC/AIO/aio_bridge.cpp`.
2.  **Delete:** `src/server/scripts/DC/AIO` directory (if empty after deletion).
3.  **Client:** Mark `AIO_Client` as deprecated / remove from distribution.
