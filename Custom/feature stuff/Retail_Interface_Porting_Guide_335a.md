# Technical Guide: Porting Retail (Dragonflight/TWW) Interface to WotLK 3.3.5a

## 1. GlueXML Structure & Key Files

In WotLK 3.3.5a, the "Login" and "Character Selection" screens are part of the **GlueXML** environment. This environment is separate from the in-game **FrameXML** environment. Addons do not load here; only files defined in `GlueXML.toc` are loaded.

To modify these screens, you must patch the files located in `Interface\GlueXML\`.

### Key Files to Modify:
*   **`AccountLogin.xml` / `.lua`**: The main login screen.
    *   *Retail Goal*: Remove the center frame, move inputs to the bottom/center, add a "Clean" background or 3D model background.
*   **`CharacterCreate.xml` / `.lua`**: The character creation screen.
    *   *Retail Goal*: This requires the heaviest modification. Retail uses a split view (Race/Class on sides, model in center). 3.3.5a uses a fixed layout. You will need to hide almost all default textures and rebuild the UI using new Frames.
*   **`CharacterSelect.xml` / `.lua`**: The screen where you choose your character to enter the world.
    *   *Retail Goal*: The "Warband" style scene is a 3D model. In 3.3.5a, the background is a `Model` widget. You can replace the background model (`Interface\Glues\Models\UI_Main\UI_Main.m2`) or specific race backgrounds.
*   **`RealmList.xml` / `.lua`**: The server selection screen.
    *   *Retail Goal*: Modernize the list look.

## 2. API Differences & Limitations (3.3.5a vs Retail)

The 3.3.5a client runs on a modified Lua 5.1 engine and lacks many modern WoW API features.

### Missing Features & Polyfills:
1.  **AnimationGroups**: Retail uses `CreateAnimationGroup` for smooth fades, slides, and bounces.
    *   *Workaround*: You must implement a custom Animation System using `OnUpdate` scripts.
    *   *Logic*: Create a table of "Active Animations". In a global `OnUpdate`, loop through them and adjust `SetAlpha` or `SetPoint` based on `GetTime()`.
2.  **Mixins**: Retail uses `Mixin(frame, SomeMixin)`.
    *   *Workaround*: Use standard Lua table inheritance or simply define functions on the frame directly. `Frame.Method = function(self) ... end`.
3.  **9-Slice (NineSlice)**: Retail has native 9-slice support for high-res borders.
    *   *Workaround*: 3.3.5a `SetBackdrop` is powerful but rigid. For complex borders, you may need to manually create 8 separate textures (corners + sides) and anchor them, or use `SetBackdrop` with a custom `edgeFile`.
4.  **Atlas System**: Retail uses `GetAtlasInfo` to map logical names to texture coordinates.
    *   *Workaround*: You must manually calculate `SetTexCoord` for your sprite sheets (BLP files).

## 3. Asset Handling

### Textures
*   **Format**: Must be **BLP** (Blizzard proprietary). Use tools like `BLPConverter` or `XnView` with plugins.
*   **Resolution**: 3.3.5a handles 1024x1024 well. 2048x2048 might work but can be unstable on older clients.
*   **Alpha**: Ensure your BLPs are saved with Alpha channels (usually DXT5 or uncompressed ARGB8888 for UI elements to avoid artifacts).

### Models & Camera
*   **Backgrounds**: The login screen background is a 3D model (`Model` widget). You can backport the Dragonflight login screen model (M2) to 3.3.5a format.
*   **Character Create Camera**: In 3.3.5a, the camera positions for races are largely hardcoded or defined in DBCs (`ChrRaces.dbc` has some data, but camera specific data is often in the binary).
    *   *Trick*: Instead of moving the *camera*, move the *model*. In `CharacterCreate.lua`, you can adjust the `SetPosition` and `SetFacing` of the `CharacterCreateModel` frame to simulate different camera angles.

## 4. Server Sync (Server-to-Glue Communication)

**Challenge**: The GlueXML environment runs *before* the client enters the world. It connects to the **AuthServer**, not the **WorldServer**.

### Possibilities:
1.  **Impossible**: Sending arbitrary Lua packets from WorldServer to Login Screen (because you aren't connected to WorldServer yet).
2.  **Limited (AuthServer)**: The AuthServer sends `REALM_LIST` packets.
    *   *Hack*: You could repurpose the "Realm Name" or "Realm Type" fields to send small config flags (e.g., "MyServer (1)" where 1 indicates a specific background ID), but this is messy.
3.  **Config File**: The best approach for 3.3.5a is a client-side `Config.lua` file that users download with the patch.
4.  **WTF SavedVariables**: `GlueXML` can read `SavedVariables`. You can store data from a previous game session.
    *   *Strategy*: If the user was logged in, an addon can write to `SavedVariables`. The next time they launch the game, the Login Screen reads that variable (e.g., "LastPlayedCharacterBackground").

## 5. Customization Structure

To make your code maintainable, separate the config from the logic.

**`RetailLoginConfig.lua`**:
```lua
RetailLoginConfig = {
    BackgroundModel = "Interface\\Glues\\Models\\UI_Main\\UI_Main_DF.m2",
    LogoTexture = "Interface\\Custom\\DF_Logo.blp",
    EnableMusic = true,
    Colors = {
        Primary = {0.1, 0.1, 0.1, 0.9},
        Highlight = {1.0, 0.82, 0.0, 1.0},
    }
}
```

**`AccountLogin_Custom.lua`**:
```lua
-- Hook the loading function
local oldAccountLogin_OnLoad = AccountLogin_OnLoad;
function AccountLogin_OnLoad(self)
    oldAccountLogin_OnLoad(self);
    
    -- Apply Retail Look
    RetailLogin_ApplyStyle();
end

function RetailLogin_ApplyStyle()
    -- Hide default frames
    AccountLoginLogo:SetTexture(RetailLoginConfig.LogoTexture);
    AccountLoginUI:Hide(); -- Hide the old parchment frame
    
    -- Create new frames
    if (not RetailLoginFrame) then
        RetailLoginFrame = CreateFrame("Frame", "RetailLoginFrame", AccountLogin, nil);
        -- ... setup code ...
    end
end
```

## 6. Implementation Plan

1.  **Clean Slate**: Create a patch that hides all standard 3.3.5a login elements (`AccountLoginUI`, `VirtualKeypad`, etc.).
2.  **Backport Assets**: Convert Dragonflight UI textures (buttons, inputs, logos) to BLP.
3.  **Layout**: Recreate the bottom-center login box using standard `CreateFrame`.
4.  **Character Create**:
    *   Hide `CharacterCreateRaceFrame`, `CharacterCreateClassFrame`.
    *   Create new "Icon Grids" for Races/Classes on the left/right sides.
    *   Hook `CharacterCreate_OnChar` to update the central model when icons are clicked.
5.  **Animation System**: Write a simple `TWW_Animation.lua` to handle smooth transitions (alpha/translation).

## 7. Insights from "Noa-1995/WoW-Retail-Interface"
This project is a gold standard reference for 3.3.5a interface mods. Key takeaways:

*   **Config-Driven Design**: Use a `Config` table in `AccountLogin.lua` to control fade times, background textures, and animation paths.
*   **Custom Model Handling**: Use a helper function like `CreateLoginModel(parent, modelData)` to instantiate and position 3D models dynamically, rather than relying on hardcoded XML.
*   **Race/Class Data**: Store detailed race/class info (descriptions, icons, spells) in Lua tables (e.g., `Races_Informations`, `Class_Informations` in `CharacterInfo.lua`) to populate the rich tooltips seen in Retail.
*   **Lighting Control**: You can customize the lighting of the character model using `model:AddCharacterLight(LIGHT_LIVE, ...)` and `model:AddLight(...)`. This is crucial for achieving the "Retail" look, as 3.3.5a default lighting is flat.
*   **Ambience**: Use `PlayGlueAmbience` with custom tracks defined in a table (e.g., `GlueAmbienceTracks`) to match the race/class selection.

## 8. References & Search Terms
*   **"Noa-1995/WoW-Retail-Interface"**: (GitHub) A comprehensive open-source project implementing many of these features.
*   **"AIO (All In One) 3.3.5a"**: A project that handles client-server communication, though mostly in-game.
*   **"Eluna Engine"**: If your server supports Eluna, you have more control, but still limited at the Login Screen.
*   **"GlueXML hacks 3.3.5"**: Search for this to find specific memory editing tricks if Lua isn't enough.
