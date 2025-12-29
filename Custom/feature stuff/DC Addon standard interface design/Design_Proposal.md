# DC Addon Standard Interface Design Proposal

## 1. Objective
To establish a unified, professional, and branded look for all DarkChaos (DC) client-side addons. This ensures a consistent user experience and simplifies future development by reusing common UI components.

## 2. Visual Identity (The "DarkChaos" Theme)
The design will move away from the standard Blizzard "parchment and stone" look towards a modern, dark, and sleek interface that fits the "DarkChaos" name.

### 2.1. Color Palette
*   **Background:** Dark Grey / Obsidian (`#1a1a1a` / `0.1, 0.1, 0.1`) with high opacity (90-95%).
*   **Header/Title Bar:** Darker Grey / Black (`#0d0d0d` / `0.05, 0.05, 0.05`).
*   **Accent/Highlight:** Chaos Gold / Orange (`#ffcc00` / `1.0, 0.8, 0.0`). Used for borders, active tabs, and primary buttons.
*   **Text:**
    *   Primary: White (`#ffffff`).
    *   Secondary: Light Grey (`#b3b3b3`).
    *   Accent: Gold (`#ffcc00`).

### 2.2. Standard Components
*   **Main Window:**
    *   Thin 1px Gold border.
    *   "DarkChaos" Logo in the top-left corner of the header.
    *   Title text centered or left-aligned next to the logo.
    *   Standard "X" close button in the top-right (custom texture, not the red Blizzard one).
*   **Buttons:**
    *   Background: Dark Grey gradient.
    *   Border: 1px Grey (Normal), 1px Gold (Hover).
    *   Text: White (Normal), Gold (Hover).
*   **Tabs:**
    *   Bottom-aligned or Top-aligned (consistent across addons).
    *   Active tab has a Gold underline or glow.

## 3. Technical Implementation: `DC-UI-Lib`
Instead of copy-pasting styles into every addon, we will create a shared library addon: **`DC-UI-Lib`**.

### 3.1. Library Features
*   **`DC_UI:CreateWindow(name, width, height, title)`**: Creates a fully styled main window with logo, title, and close button.
*   **`DC_UI:CreateButton(parent, width, height, text)`**: Creates a standardized button.
*   **`DC_UI:CreateScrollFrame(parent)`**: Creates a styled scroll frame (custom scrollbar textures).
*   **`DC_UI:SkinFrame(frame)`**: Applies the DC backdrop and border to an existing frame (useful for retrofitting).

### 3.2. Asset Management
The `DC-UI-Lib` folder will contain the standard assets:
*   `Textures/Logo_32.tga`
*   `Textures/CloseButton.tga`
*   `Textures/Border.tga`
*   `Textures/Button_Normal.tga`, `Button_Hover.tga`

## 4. Standardized Settings & Communication
To ensure a consistent user experience and simplify development, all addons must adhere to the following standards for settings and server communication.

### 4.1. Settings Interface
*   **Unified Settings Tab:** Every addon with configurable options must have a "Settings" tab (or a gear icon opening a settings modal) using the standard `DC-UI-Lib` components.
*   **Standard Layout:**
    *   **Left Column:** Category navigation (if complex) or simple list of options.
    *   **Right Column:** Controls (Checkboxes, Sliders, Dropdowns).
*   **"Apply" Behavior:** Settings should ideally apply immediately, or have a clear "Save" button if server confirmation is required.

### 4.2. Communication Protocol (`DC-AddonProtocol`)
All addons must use the standardized communication layer defined in `#file:Addon protocoll` and implemented in `#file:AddonExtension`.
*   **Library:** Use `DC-AddonProtocol` (client-side lib) for all server calls.
*   **Prefix Registration:** Ensure the addon registers its prefix (e.g., `DCAOE`, `DCCOL`) via `RegisterAddonMessagePrefix`.
*   **Packet Structure:** Follow the `COMMAND:arg1,arg2` or JSON-based format defined in the protocol documentation.
*   **Handshake:** Implement the standard `HELLO` / `WELCOME` handshake on login to verify version compatibility.

### 4.3. Learnings from Existing Addons
*   **DC-Welcome:**
    *   *Lesson:* "Flat" designs look better than textured ones on modern screens.
    *   *Lesson:* Pre-caching data (e.g., news) prevents UI lag on open.
*   **DC-Collection:**
    *   *Lesson:* Heavy data (like item lists) should be loaded lazily or paginated to avoid freezing the client.
    *   *Lesson:* Search bars must have a slight delay (debounce) to prevent spamming filters.
*   **DC-MythicPlus:**
    *   *Lesson:* Real-time updates (timers) need efficient `OnUpdate` scripts; avoid creating new objects every frame.

## 5. Standard HUD & Live Sync (`DC-InfoBar`)
To maintain a clean screen while providing critical server information, `DC-InfoBar` is designated as the standard HUD component for persistent data.

### 5.1. HUD Design Standards
*   **Position:** Top or Bottom edge of the screen (user configurable), full width.
*   **Visual Style:**
    *   **Background:** Semi-transparent Dark Grey (`#0A0A0C`, 85% opacity).
    *   **Text:** Light Grey labels (`#CCCCCC`), White values (`#FFFFFF`).
    *   **Accents:** Cyan (`#32C4FF`) for highlights, Yellow (`#FFD100`) for warnings/timers.
    *   **Icons:** Simple, recognizable icons (16x16) for each module.
*   **Modules:** Information is organized into "Plugins" (e.g., Gold, Durability, Season, Events).

### 5.2. Live Sync Implementation
`DC-InfoBar` utilizes the `DC-AddonProtocol` to receive real-time updates from the server without polling.
*   **Event Sync:** The `Events` plugin listens for `SMSG_MESSAGECHAT` packets containing event state changes (e.g., "Invasion Started").
    *   *Implementation:* `Plugins/Server/Events.lua` registers a listener for specific protocol messages.
    *   *UI Update:* The bar updates immediately (e.g., showing a countdown timer) via an efficient `OnUpdate` loop that only redraws text, not frames.
*   **World Boss Timers:** The `WorldBoss` plugin syncs spawn timers.
    *   *Optimization:* The server sends a "Snapshot" on login, and subsequent updates only occur on status change (Spawn/Death), minimizing traffic.

## 6. Migration Strategy (Rollout)

### Phase 1: Library Creation
1.  Develop `DC-UI-Lib` with the core functions.
2.  Create a "Style Guide" addon (a simple window showing all components) to verify the look.

### Phase 2: Pilot Migration
1.  Migrate **`DC-Welcome`**: It already uses a custom style, so adapting it to the shared library will be a good test.
2.  Migrate **`DC-Collection`**: This is a complex addon using Blizzard templates. We will replace `UIPanelDialogTemplate` with `DC_UI:CreateWindow`.

### Phase 3: Full Rollout
1.  Update all other addons (`DC-GM`, `DC-Hotspot`, etc.) to add `DC-UI-Lib` to their `.toc` dependencies.
2.  Refactor their `CreateFrame` calls.

## 5. Example Usage
```lua
-- Old Way
local frame = CreateFrame("Frame", "MyAddonFrame", UIParent, "UIPanelDialogTemplate")

-- New Way
local frame = DC_UI:CreateWindow("MyAddonFrame", 600, 400, "My Addon Title")
local btn = DC_UI:CreateButton(frame, 120, 30, "Save Settings")
btn:SetPoint("BOTTOM", 0, 20)
```
