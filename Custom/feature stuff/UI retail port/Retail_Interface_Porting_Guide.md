# Retail Interface Porting Guide (Target: WotLK 3.3.5a)

## 1. Overview
This document outlines the technical strategy for backporting the modern Retail (Dragonflight/The War Within) Login, Character Creation, and Realm Selection screens to the WotLK 3.3.5a client.

**Target Style:** Clean, minimalist, high-resolution assets, side-panel navigation for character creation, and rich realm lists.
**Constraints:** WotLK 3.3.5a API (Lua 5.1, WoW API v3), no native `AnimationGroup` (limited), no `Mixin`.

## 2. Core File Structure (GlueXML)
The entire pre-login interface lives in `Interface/GlueXML`. To replace it, you must override these specific files in your MPQ patch:

| File | Purpose | Retail Equivalent Logic |
|------|---------|-------------------------|
| `GlueParent.xml` | Root frame | Initialize global styles/fonts here. |
| `AccountLogin.xml/lua` | Login Screen | Needs total layout wipe. Implement "Clean" login box. |
| `CharacterCreate.xml/lua` | Char Creation | **Complex**. Needs race/class icons, 3D model preview, customization sliders. |
| `CharacterSelect.xml/lua` | Char Selection | The "Warband" style scene (campfire) requires heavy 3D model work. |
| `RealmList.xml/lua` | Realm Selection | Needs a scrollable list with "Population", "Type", "Ping" columns. |
| `GlueXML.toc` | Manifest | Ensure your new files are loaded here. |

## 3. API Gap Analysis & Polyfills

### 3.1. Animations
Retail uses `CreateAnimationGroup`. WotLK does not have this in GlueXML (it was added later).
**Solution:** Implement a Lua-based animation system using `OnUpdate`.
```lua
-- Simple Animation Polyfill
function UIFrameFadeIn(frame, timeToFade, startAlpha, endAlpha)
    local fadeInfo = {};
    fadeInfo.mode = "IN";
    fadeInfo.timeToFade = timeToFade;
    fadeInfo.startAlpha = startAlpha;
    fadeInfo.endAlpha = endAlpha;
    UIFrameFade(frame, fadeInfo);
end
```
*Note: `UIFrameFade` exists in 3.3.5a GlueXML, but complex translations/scales need custom `OnUpdate` scripts.*

### 3.2. Mixins
Retail uses `Mixin(frame, Table)`.
**Solution:** Simple Lua table merging.
```lua
function Mixin(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...);
        for k, v in pairs(mixin) do
            object[k] = v;
        end
    end
    return object;
end
```

### 3.3. Models & Lighting
Retail character creation has dynamic lighting and high-res backgrounds.
**WotLK Capability:**
- `PlayerModel` widget exists.
- `SetLight(enabled, omni, dirX, dirY, dirZ, ambIntensity, ambR, ambG, ambB, dirIntensity, dirR, dirG, dirB)` is available in 3.3.5a (undocumented in some wikis, but present).
- **Reference:** `Noa-1995` uses `model:SetLight(true, false, ...)` to simulate the "Heroic" lighting of retail.

## 4. Implementation Strategy

### 4.1. Login Screen (AccountLogin)
1.  **Hide Default Elements:** `VirtualAccountLogin` textures must be hidden or replaced with empty BLPs.
2.  **Background:** Use a high-res `Texture` covering the whole screen (`SetAllPoints()`).
3.  **Layout:** Create a `Frame` for the login box (center or right-aligned).
4.  **Customization:**
    ```lua
    RetailUI_Config.Login = {
        Background = "Interface\\Custom\\Login\\Dragonflight_BG",
        Logo = "Interface\\Custom\\Login\\ServerLogo",
        Music = "Sound\\Music\\GlueScreenMusic\\Dragonflight_Theme.mp3"
    };
    ```

### 4.2. Character Creation (CharacterCreate)
This is the hardest part.
1.  **Layout:** Retail uses a left-side list for Races/Classes and a right-side panel for Customization.
2.  **Race/Class Buttons:** Create a `ScrollFrame` or a static list.
    -   *Icons:* You need extracted icons from Retail (`Interface\Icons\...`).
3.  **Model Preview:** The central `CharacterCreate` model needs to be scaled and positioned carefully.
    -   *API:* `CharacterCreate:SetPosition(z, x, y)` and `CharacterCreate:SetFacing(angle)`.
4.  **Customization Options:**
    -   WotLK exposes `GetSkinVariation`, `GetFaceVariation`, `GetHairVariation`, etc.
    -   You must map these IDs to custom UI sliders/buttons.

### 4.3. Server/Realm Selection
1.  **Data Source:** `GetRealmInfo(index)` returns `name, numCharacters, invalidRealm, realmDown, currentRealm, pvp, rp, load`.
2.  **Visuals:** Create a "Card" style list instead of the default table.

## 5. Server-Side Sync & Customization
**Challenge:** The Glue screen runs *before* authentication, so it cannot receive packets from the WorldServer.

**Strategies:**
1.  **Static Config (Lua):**
    -   Generate a `RetailUI_Config.lua` file inside the MPQ patch.
    -   This file contains server name, realmlist address, and feature flags.
2.  **Launcher Injection:**
    -   If using a custom launcher, it can write to `WTF/Config.wtf` or a saved variable file `WTF/Account/SavedVariables/RetailUI.lua` *before* the game starts.
    -   The Lua code can read `RetailUI_DB` from `SavedVariables`.
3.  **Server Message of the Day (MOTD):**
    -   The `GlueXML` can read the MOTD after authentication (at Char Select). You can parse the MOTD string (e.g., `|cDATA{...}|r`) to configure the UI dynamically *after* login.

## 6. Reference: Noa-1995 / Retail Ports
Based on analysis of similar projects:
-   **Texture Atlases:** They heavily use `SetTexCoord` to pull UI elements from a single large texture (Atlas) to save memory and draw calls.
-   **Virtual Frames:** Define XML templates (`<Frame name="RetailButtonTemplate" virtual="true">`) to reuse the "Retail Button" style (blue glow, rounded corners).
-   **Font Strings:** Retail uses `Friz Quadrata` but with different spacing. Use `SetSpacing()` and `SetShadowOffset()` to mimic the clean text look.

## 7. Action Plan
1.  **Extract Assets:** Get the BLP textures from the `11.2.7` dump provided.
2.  **Setup Environment:** Create a dev MPQ with `Interface/GlueXML`.
3.  **Core Library:** Write `RetailUI_Core.lua` (Mixins, Anims, Config).
4.  **Module: Login:** Rewrite `AccountLogin.xml`.
5.  **Module: CharCreate:** Rewrite `CharacterCreate.xml`.

