# DC Addon Interface Rollout Plan

## 1. Inventory of Addons
The following addons have been identified for migration to the new `DC-UI-Lib` standard:

| Addon Name | Current Style | Complexity | Priority |
| :--- | :--- | :--- | :--- |
| **DC-Welcome** | Custom Flat (Dark) | Low | High (Pilot) |
| **DC-Collection** | Blizzard Standard | High | High (Pilot) |
| **DC-GM** | *Unknown* | Medium | Medium |
| **DC-Hotspot** | *Unknown* | Low | Medium |
| **DC-InfoBar** | *Unknown* | Low | Low |
| **DC-ItemUpgrade** | *Unknown* | Medium | Medium |
| **DC-Leaderboards**| *Unknown* | Medium | Medium |
| **DC-MythicPlus** | *Unknown* | High | High |
| **DC-AOESettings** | *Unknown* | Low | Low |

## 2. Step-by-Step Execution

### Step 1: Create the Foundation (`DC-UI-Lib`)
*   **Action**: Create new addon folder `Custom/Client addons needed/DC-UI-Lib`.
*   **Content**:
    *   `DC-UI-Lib.toc`: Interface 30300.
    *   `Core.lua`: The API implementation.
    *   `Media/`: Folder for Logo, Fonts, and Textures.
*   **Deliverable**: A working library that can be loaded in-game.

### Step 2: The "Style Guide" Demo
*   **Action**: Create a temporary command `/dcui test` in the library.
*   **Content**: Opens a window displaying:
    *   H1, H2, Body text.
    *   Primary/Secondary buttons.
    *   Input fields.
    *   Checkboxes.
    *   Scrollbar.
*   **Goal**: Verify the aesthetics before touching real addons.

### Step 3: Pilot - DC-Welcome
*   **Reason**: It's the first thing players see.
*   **Action**:
    *   Add `DC-UI-Lib` to `DC-Welcome.toc` (OptionalDeps or RequiredDeps).
    *   Replace `CreateFrame` logic in `WelcomeFrame.lua` with `DC_UI:CreateWindow`.
    *   Remove local texture definitions (solid colors) and use the library's theme.

### Step 4: Pilot - DC-Collection
*   **Reason**: It's the most complex UI.
*   **Action**:
    *   Replace `UIPanelDialogTemplate` with `DC_UI:CreateWindow`.
    *   The "Tabs" system in `MainFrame.lua` needs to be adapted to the new Tab style (likely top-aligned or side-nav).
    *   Retest all sub-frames (Mounts, Pets, Transmog) to ensure they fit the new container.

### Step 5: Mass Migration
*   Once the pilots are stable, apply the changes to the remaining addons.
*   **Pattern**:
    1.  Open `.toc`, add dependency.
    2.  Open `Core.lua` / `MainFrame.lua`.
    3.  Find Main Window creation.
    4.  Swap to `DC_UI:CreateWindow`.
    5.  Adjust child element positioning (since borders/offsets might change).

## 3. Timeline Estimate
*   **Library Dev**: 1-2 Days.
*   **Pilots**: 2-3 Days.
*   **Full Rollout**: 1 Week (depending on testing feedback).
