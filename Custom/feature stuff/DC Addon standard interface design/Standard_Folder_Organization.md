# Standard Addon Folder Organization

## 1. Root Structure
All custom addons reside in `Custom/Client addons needed/`.
To maintain cleanliness, we use the following naming conventions:

*   **`DC-AddonProtocol`**: The Core library (Protocol + UI Lib).
*   **`DC-<FeatureName>`**: Feature-specific addons (e.g., `DC-MythicPlus`, `DC-Collection`).
*   **`!Astrolabe` / `Ace3`**: Third-party libraries (kept separate).

## 2. Internal Addon Structure
Every DC addon should follow this standard layout to ensure maintainability and consistency.

```
DC-AddonName/
├── DC-AddonName.toc       # Manifest
├── Core.lua               # Initialization, Event Handling, Protocol Registration
├── Config.lua             # Settings & SavedVariables logic
├── Localization.lua       # Localization strings (L table)
├── Media/                 # Addon-specific textures/fonts
│   ├── Logo.tga
│   └── Background.tga
├── Modules/               # Sub-features (if complex)
│   ├── ModuleA.lua
│   └── ModuleB.lua
└── UI/                    # Interface code
    ├── MainFrame.lua      # Primary window creation
    └── Templates.lua      # Reusable XML/Lua templates
```

## 3. File Responsibilities

### `Core.lua`
*   **Namespace**: `local addonName, NS = ...`
*   **Events**: `ADDON_LOADED`, `PLAYER_LOGIN`.
*   **Protocol**: `DCAddonProtocol:RegisterPrefix("PREFIX")`.
*   **Slash Commands**: `/dcaddon`.

### `Config.lua`
*   **Defaults**: Define default settings table.
*   **Loading**: Merge `SavedVariables` with defaults.
*   **Settings Menu**: Create the options panel (using `DC-UI-Lib`).

### `UI/`
*   **Separation**: Keep UI logic separate from data logic.
*   **Library Usage**: Always use `DC_UI:CreateWindow` instead of raw `CreateFrame` for main windows.

## 4. Dependency Management
*   **TOC File**: Always include `## Dependencies: DC-AddonProtocol`.
*   **No Embedded Libs**: Do not embed `Ace3` or `Astrolabe` inside your addon folder unless absolutely necessary. Use the shared versions in the root folder.

## 5. Asset Standards
*   **Format**: TGA (32-bit uncompressed) or BLP.
*   **Dimensions**: Powers of 2 (e.g., 32x32, 512x512).
*   **Pathing**: Use relative paths in code where possible, or standard `Interface\AddOns\DC-AddonName\Media\...`.
