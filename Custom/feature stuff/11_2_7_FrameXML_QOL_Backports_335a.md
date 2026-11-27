# 11.2.7 FrameXML QoL Backports for WotLK 3.3.5a

## Executive Summary

The best things to take from WoW 11.2.7 are not full systems copied line-for-line. The real value is in the retail UX patterns:

1. Searchable settings and a cleaner configuration shell.
2. A unified edit mode for frame movement, action bars, and quick keybinding.
3. A reusable toast and feedback layer.
4. Better quest, tooltip, and map readability.
5. Cleaner menu, navigation, and interaction patterns.

For 3.3.5a, these should be treated as **design ports**, not direct API ports. Retail SharedXML, EditMode, ScrollBox, Settings, and Menu code depends on APIs and framework layers that do not exist in Wrath. The practical path is to recreate the behavior with smaller WotLK-safe systems.

---

## Guiding Principle

Backport **player-facing wins**, not retail internals.

Good targets:

- Faster discovery of options.
- Less friction when moving or configuring UI.
- Better visual feedback when actions succeed or fail.
- Cleaner reading of quests, tooltips, objectives, and map state.
- Better consistency between modules.

Bad targets:

- Full direct ports of `ScrollBox`, `C_*` APIs, modern secure systems, or Warband/account-wide architecture.
- Any retail system whose value depends on framework code that does not exist in 3.3.5a.

---

## Biggest Wins

| Priority | Retail Pattern | 3.3.5a Backport Version | Why It Matters | Risk |
|----------|----------------|-------------------------|----------------|------|
| P1 | Searchable settings shell | Category dashboard with search, tags, filters, reusable widgets | Players can actually find settings quickly | Low |
| P1 | Edit Mode + Quick Keybind | Unified edit state for frame moving, bar layout, route preview, and bind mode | Huge usability gain for power users and casual users | Medium |
| P1 | Toast / notification layer | Reusable success, warning, and info feedback for bags, vendor, mail, talents, social, navigation | Makes systems feel responsive and modern | Low |
| P1 | Accessibility and readability | Font scaling, tooltip cleanup, contrast options, cleaner quest text | Helps every user immediately | Low |
| P2 | Objective tracker and map clarity | Better watched quest presentation, route emphasis, better POI hierarchy | Strong day-to-day QoL during leveling and events | Medium |
| P2 | Menu and context action cleanup | Cleaner contextual actions, fewer hidden slash-only flows | Reduces feature discoverability problems | Medium |
| P2 | Inventory and vendor UX polish | Better bag state, junk handling, merchant summary feedback, mailbox flow | Frequent interaction surfaces benefit most | Low |
| P3 | Minimap and navigation polish | Cleaner pin language, route markers, zone guidance, follow target behavior | Strong value if paired with custom world content | Medium |
| P3 | AddOn and profile presentation ideas | Better profile surfacing, module summaries, more readable options UI | Nice consistency improvement, lower urgency | Low |

---

## Recommended Retail Systems to Study

These files are valuable as **reference material** for behavior, visual hierarchy, naming, and UX flow.

| Retail File / System | What To Extract From It | Backport Advice |
|----------------------|-------------------------|-----------------|
| `Blizzard_Settings_Shared/Blizzard_Settings.lua` | Searchable settings layout, category browsing, widget consistency | Recreate with simple WotLK frames and your own search index |
| `Blizzard_EditMode/EditModeManager.lua` | Unified customization mode, toolbar logic, frame registration model | Copy the idea, not the manager code |
| `Blizzard_QuickKeybind/Blizzard_QuickKeybind.lua` | In-context bind editing | Excellent high-value behavior for 3.3.5a |
| `Blizzard_Menu/Menu.lua` | Cleaner contextual action structure | Build a lighter custom menu helper |
| `Blizzard_ObjectiveTracker.lua` | Spacing, visual priority, objective readability | Strong source for tracker cleanup and emphasis rules |
| `Blizzard_WorldMap.lua` | Quest-follow flow, route emphasis, map readability | Good source for navigation behavior and hierarchy |
| `Blizzard_Minimap.lua` | Button cleanup and minimap interaction ideas | Cherry-pick cautiously |
| `Blizzard_SharedXML/NineSlice.lua` | Framing, border composition patterns | Use as an art/layout reference, not a direct dependency |
| `Blizzard_SharedXML/Scroll/ScrollBox.lua` | Scroll behavior and content framing | Do not port directly; mimic only the visible behavior |
| `TextSizeManager.lua` | Readability scaling concepts | Excellent for accessibility-inspired options |
| `QuestTextContrast.lua` | Quest text readability and contrast handling | Good low-risk QoL feature |
| `Blizzard_HUDInventory` | Inventory surface polish and item feedback patterns | Useful for bag and vendor modules |

---

## Best Features to Recreate in 3.3.5a

### 1. Shared Settings Shell

**Retail inspiration:** Blizzard Settings system

**What to recreate:**

- Search box that filters modules and keywords.
- Consistent checkbox, slider, dropdown, button, and section styling.
- Category dashboard with icons and short descriptions.
- Reusable “open this module directly” behavior.
- Lightweight keyword tagging for hidden or advanced options.

**Why this is a big win:**

- It improves every single module at once.
- It reduces slash-command dependency.
- It makes custom systems feel like one product instead of many addons stapled together.

**Implementation note:**

- Build your own widget layer and keyword index.
- Do not try to port retail `SettingsPanel` architecture directly.

### 2. Unified Edit Mode

**Retail inspiration:** Edit Mode + Quick Keybind

**What to recreate:**

- One edit-mode entry point.
- Toolbar for frame unlock, grid, snap, route preview, keybind mode, and action bar layout.
- Shared “editing state” used by FrameMover, ActionBars, Keybinds, and Navigation.
- Clear enter/exit feedback and state restoration.

**Why this is a big win:**

- It turns multiple disconnected configuration flows into one understandable experience.
- It is one of the clearest “retail-feeling” QoL wins you can ship to Wrath.

**Implementation note:**

- Recreate the workflow and interaction model.
- Do not attempt to port retail secure action customization internals.

### 3. Reusable Toast / Notification Layer

**Retail inspiration:** Shared alerts, lightweight action confirmations, contextual prompts

**What to recreate:**

- Standard toast frame with icon, color, title, and short message.
- Success, warning, info, and error variants.
- Shared entry point used by bags, vendor, mail, social, talents, navigation, and protocol messages.

**Why this is a big win:**

- It immediately modernizes feedback quality.
- It removes the need to dump everything into chat.
- It helps custom systems feel connected.

### 4. Accessibility and Readability

**Retail inspiration:** Text sizing and quest contrast helpers

**What to recreate:**

- Optional font scaling.
- Tooltip cleanup mode.
- Higher contrast text options.
- Cleaner quest and lore text presentation.
- Better separation between important and secondary text.

**Why this is a big win:**

- It benefits all users, not just advanced users.
- It is technically low-risk.
- It is especially valuable on private servers with lots of custom text.

### 5. Objective Tracker and Quest Follow Improvements

**Retail inspiration:** Objective tracker and world map improvements

**What to recreate:**

- Better spacing and bullet hierarchy.
- Clear “followed objective” presentation.
- Better watched quest emphasis.
- Cleaner route preview from tracked objectives.
- Better relation between quest log, watch frame, and map pins.

**Why this is a big win:**

- This is one of the most-used parts of the UI during leveling and custom zone play.
- It matters even more on servers with custom quest flow and navigation logic.

### 6. Menu and Context Action Cleanup

**Retail inspiration:** Blizzard Menu patterns

**What to recreate:**

- Structured contextual actions instead of hidden behavior.
- Safer right-click and control-click flows.
- Reusable menu building helpers for module actions.

**Why this is a big win:**

- It makes advanced features discoverable.
- It reduces user confusion around custom item, friend, vendor, and quest actions.

### 7. Inventory, Mail, and Vendor Polish

**Retail inspiration:** Modern inventory surfaces and better transaction feedback

**What to recreate:**

- Clearer bag state changes.
- Better merchant summary UI.
- Better junk and repair preview feedback.
- Mail collection confirmations and status notices.
- Cleaner visual treatment for item actions.

**Why this is a big win:**

- Bags, merchant, and mail are high-frequency surfaces.
- Small changes here are felt constantly.

---

## Texture and Art Families Worth Extracting

The most useful retail art to extract is not giant scene art first. The best ROI is **small reusable UI texture families**.

### High-Value Texture Families

| Art Family | Best Use In 3.3.5a | Notes |
|------------|--------------------|-------|
| Settings panels and category cards | Shared settings shell, dashboard buttons, module cards | Strong value across all UI modules |
| Search bars, tabs, toggles, checkboxes, radios | Modern control styling | High reuse |
| Edit mode frames and highlight rings | Unified edit mode, selected state, hovered state | Great visual upgrade |
| Toast / alert art | Notifications, confirmations, warnings | Extremely reusable |
| Objective tracker bullets and quest badges | Tracker cleanup and emphasis | Strong everyday visibility |
| Minimap pins and route markers | Navigation, supertrack, custom POIs | Good for custom content systems |
| Nine-slice dialog and panel borders | Popups, settings, tooltips, module windows | Convert to simpler WotLK-safe framing |
| Tooltip card textures and soft glows | Cleaner tooltip presentation | Strong polish value |
| Bag slot accents, item borders, small badges | Inventory and vendor UI | High reuse in item-heavy surfaces |
| Category icons and module glyphs | Dashboard organization | Makes large systems more readable |

### Best Sources For Art Discovery

- `Helix/AtlasInfo.lua`
- `ArtTextureID.lua`
- Edit Mode atlas groups
- Objective tracker atlas groups
- Minimap and world map atlas groups
- Shared settings and menu atlases

### Practical Asset Notes

- Convert only what you can maintain.
- Prefer reusable UI parts over giant one-off backgrounds.
- 3.3.5a still needs manual texture coordinates and BLP conversion.
- Many retail atlases are best treated as **source art references**, then rebuilt into smaller Wrath-safe sheets.

---

## Systems That Are Worth Backporting Only Partially

These are useful, but should be adapted rather than copied.

### Scroll Containers

Retail `ScrollBox` is not worth direct porting. What is worth copying:

- Better spacing.
- Cleaner clipping behavior.
- More deliberate list presentation.
- Reusable row/card layouts.

### Modern Menus

Retail menu architecture is too heavy for a direct Wrath port, but the interaction model is worth keeping:

- Cleaner action grouping.
- Better labels.
- Fewer hidden actions.
- Better separators and state display.

### Map and POI Systems

Retail map systems assume more client support. Still worth adapting:

- Quest-follow concepts.
- Better POI emphasis.
- Route preview logic.
- Better visual hierarchy between destination types.

---

## What Is Not Worth Direct Porting

These are poor backport targets unless you are willing to build major infrastructure first.

- `ScrollBox` as a direct framework dependency.
- Retail `C_*` API-driven systems.
- Warband/account-wide architecture.
- Modern collections UI that depends on retail data organization.
- Full ping UI without matching protocol and world interaction support.
- Retail secure layout systems for action bars and HUD composition.

---

## Recommended Implementation Order

### Phase 1: Shared UX Foundation

- Shared settings shell.
- Search and keyword tagging.
- Reusable widget styling.
- Toast / notification layer.
- Accessibility and readability options.

### Phase 2: Customization Experience

- Unified edit mode.
- Quick keybind mode.
- Frame mover integration.
- Action bar editing integration.
- Navigation preview integration.

### Phase 3: Questing and Navigation

- Objective tracker cleanup.
- Followed quest flow.
- Better route emphasis.
- Better minimap and world map marker hierarchy.

### Phase 4: Daily Use Surfaces

- Bags.
- Vendor.
- Mail.
- Social.
- Talents and utility modules.

### Phase 5: Art and Visual Cohesion

- Shared panel art.
- Tooltip polish.
- Module category iconography.
- Edit mode art pass.
- Navigation and tracker texture pass.

---

## Recommended Focus for DarkChaos / DC-QOS

If the goal is the largest immediate QoL gain inside the existing DarkChaos addon stack, the best 11.2.7-derived priorities are:

1. Shared settings + search shell.
2. Unified edit mode.
3. Toast / notification framework.
4. Accessibility and readability.
5. Tracker / map / navigation cleanup.
6. Inventory, vendor, and mail polish.

That order produces the highest value because it improves both the **feel** and the **discoverability** of everything else built later.

---

## Final Recommendation

The most realistic 11.2.7 backports for 3.3.5a are not giant visual overhauls first. The biggest wins are the invisible quality-of-life structures:

- a better settings shell,
- a shared edit mode,
- a unified feedback system,
- clearer text and quest presentation,
- and stronger navigation clarity.

Those give the strongest retail feel with the lowest technical risk, and they scale well across DarkChaos custom systems.