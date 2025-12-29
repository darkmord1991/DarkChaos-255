# TSWoW Adaptation Analysis for Dark Chaos Core

## Document Purpose
Evaluate TSWoW (TypeScript WoW) framework features for potential adaptation to Dark Chaos AzerothCore-based server.

---

## 1. TSWoW Overview

### What is TSWoW?
TSWoW is a **TypeScript-based modding framework** for WoW 3.3.5a (WotLK) that enables:
- **Datascripts**: Static content creation (creatures, spells, items, quests, etc.)
- **Livescripts**: Dynamic runtime scripting (similar to Eluna but TypeScript)
- **Client addon creation**: Custom UI and client-side modifications
- **Module system**: Organized, modular content packages

### Key Technical Facts
| Aspect | Details |
|--------|---------|
| Base Core | **TrinityCore** (NOT AzerothCore) |
| Language | TypeScript (compiles to C++/SQL/DBC) |
| License | GPL-3.0 |
| Repository | github.com/tswow/tswow |
| Active Development | Moderate (113 stars, last updated 2024) |

---

## 2. TSWoW Features Breakdown

### 2.1 Datascripts (Static Content Creation)
Datascripts compile to **DBC files and SQL** at build time. They use a "cell-based" programming model where entities are defined declaratively.

#### What Datascripts Can Create:
- **Creatures/NPCs** - Stats, spawns, AI behaviors
- **Spells** - Custom spell effects, auras, procs
- **Items** - Equipment, consumables, currencies
- **Quests** - Objectives, rewards, chains
- **Classes** - Custom classes with talent trees
- **Races** - New playable races
- **Zones/Areas** - Map data and zone definitions
- **Professions** - Custom crafting systems
- **Dungeons/Battlegrounds** - Instance definitions

#### Example Datascript (Creating a Creature):
```typescript
const myCreature = std.CreatureTemplates.create('mymod', 'custom_npc', 1234);
myCreature.Name.enGB.set('Dark Chaos Vendor');
myCreature.Models.addIds(1234);
myCreature.Level.set(80, 80);
myCreature.FactionTemplate.set(35);
```

### 2.2 Livescripts (Runtime Scripting)
Livescripts are **TypeScript scripts that run at runtime**, similar to Eluna but with:
- Type safety
- Better IDE support
- Automatic reloading during development

#### Livescript Capabilities:
- Event handling (OnKill, OnSpellCast, OnLogin, etc.)
- Custom combat mechanics
- Instance scripting
- World events
- Player interactions

#### Example Livescript:
```typescript
export function Main(events: TSEvents) {
    events.Player.OnKilledUnit((player, killed) => {
        if (killed.GetEntry() === 12345) {
            player.SendBroadcastMessage("Boss defeated!");
        }
    });
}
```

### 2.3 Client Addon/Asset Manipulation
TSWoW can **generate and modify client files**:
- Create Lua/XML addon files
- Modify DBC files for client
- Generate texture patches
- Create custom models (with external tools)

---

## 3. Adaptation Feasibility for Dark Chaos

### 3.1 Core Differences: TrinityCore vs AzerothCore

| Aspect | TrinityCore (TSWoW) | AzerothCore (Dark Chaos) |
|--------|---------------------|--------------------------|
| Codebase | TrinityCore fork | TrinityCore derivative |
| API Compatibility | ~70-80% similar | Different hook systems |
| Scripting | TSWoW/SmartAI | Eluna/C++ ScriptAI |
| Database Schema | Similar but diverged | AC-specific tables |
| Module System | TSWoW modules | AC modules |

### 3.2 What CAN Be Directly Used

#### ✅ Directly Usable (with client patch):
1. **DBC Files** - TSWoW-generated DBCs are compatible
2. **SQL Data** - Creature/Item/Quest definitions (with mapping)
3. **Client Addons** - Lua/XML output works on any 3.3.5 client
4. **Asset Patches** - BLP textures, M2 models, MPQ content

#### ✅ Conceptually Adaptable:
1. **Datascript Patterns** - Port to C++/SQL generators
2. **Module Organization** - Similar concepts in AC modules
3. **Cell-based Design** - Useful abstraction pattern

### 3.3 What CANNOT Be Directly Used

#### ❌ Requires Significant Rework:
1. **Livescripts** - Different event system than Eluna
2. **Core Extensions** - TrinityCore-specific patches
3. **Build System** - TSWoW's TypeScript pipeline

---

## 4. Recommended Adaptation Strategies

### Strategy A: Selective Porting (Recommended)
**Best for Dark Chaos**: Port specific features rather than adopting TSWoW wholesale.

| TSWoW Feature | Dark Chaos Equivalent | Porting Effort |
|---------------|----------------------|----------------|
| Custom Classes | C++ ClassScripts + DBC patches | High |
| Custom Races | DBC patches + CharCreate mods | Medium |
| Custom Spells | SpellScripts + DBC patches | Medium |
| Quests/NPCs | SQL + Eluna scripts | Low |
| Client UI | AIO addon framework | Low |

### Strategy B: Parallel Development
Maintain a TSWoW instance for **content prototyping**, then manually port to AC:
1. Design content in TSWoW (faster iteration)
2. Export DBC/SQL/client files
3. Adapt scripts to Eluna/C++
4. Integrate into Dark Chaos

### Strategy C: Tooling Inspiration
Create **similar tooling for AzerothCore**:
- TypeScript content generators → SQL/DBC
- Declarative creature/spell definitions
- Hot-reload development workflow

---

## 5. Feature-by-Feature Adaptation Guide

### 5.1 Custom Classes
**TSWoW Approach**: Full TypeScript class definition with talents, spells, UI

**Dark Chaos Adaptation**:
```
1. DBC Patches: ChrClasses.dbc, ChrRaces.dbc, Talents, SpellIcons
2. C++ Scripts: Class-specific mechanics
3. AIO Addon: Class UI frames, power bars, action bars
4. Database: Spell definitions, talent trees, trainer data
```

**Effort**: 4-6 weeks per class  
**Client Patch**: Required (DBC + optional MPQ)

### 5.2 Custom Races
**TSWoW Approach**: Race definition with starting zones, racials, models

**Dark Chaos Adaptation**:
```
1. DBC Patches: ChrRaces, CharStartOutfit, CharacterCreateData
2. Client MPQ: Race models, textures (or reuse existing)
3. SQL: Starting zone, quest chain, trainers
4. Eluna: Racial abilities implementation
```

**Effort**: 2-3 weeks per race  
**Client Patch**: Required

### 5.3 Custom Dungeons/Battlegrounds
**TSWoW Approach**: Full instance scripting with events

**Dark Chaos Adaptation**:
```
1. Map Files: ADT/WMO (use Noggit/existing zones) - see ZONE_DUNGEON_REUSE_ANALYSIS.md
2. SQL: Instance template, creature spawns, objects
3. C++: InstanceScript for boss mechanics
4. DBC: DungeonMap, LFGDungeons entries
```

**Effort**: 2-4 weeks per dungeon  
**Dark Chaos Advantage**: Already has custom zones working!

### 5.4 Custom Professions
**TSWoW Approach**: Profession skill with recipes, gathering nodes

**Dark Chaos Adaptation**:
```
1. DBC Patches: SkillLine, SkillLineAbility, SpellFocusObject
2. SQL: Recipe spells, skill-up data, crafted items
3. C++: Gathering mechanics, special crafting rules
4. AIO: Profession UI enhancements
```

**Effort**: 3-4 weeks per profession

---

## 6. TSWoW Features Most Valuable for Dark Chaos

### Priority 1: Content Generation Patterns
TSWoW's declarative approach to content creation can inspire **Dark Chaos tooling**:

```python
# Conceptual Python equivalent for DC content generation
def create_dungeon_tier(base_dungeon_id, tier_level, scaling_factor):
    # Generate scaled creature templates
    # Generate loot tables with tier multipliers
    # Generate instance difficulty entries
    pass
```

### Priority 2: Client Asset Management
TSWoW's systematic approach to client patches:
- Organized MPQ structure
- DBC versioning
- Asset dependency tracking

### Priority 3: Module Patterns
TSWoW modules encapsulate:
- All SQL/DBC for a feature
- All scripts (client + server)
- Configuration and documentation

---

## 7. Implementation Roadmap

### Phase 1: Tooling (Weeks 1-4)
1. Create Python/TypeScript content generators for Dark Chaos
2. Establish DBC patching workflow (DBCUtil integration)
3. Document AIO addon patterns for client features

### Phase 2: Content Porting Framework (Weeks 5-8)
1. Build SQL template system for scaled content
2. Create Eluna script templates matching TSWoW patterns
3. Develop testing framework for new content

### Phase 3: Feature Implementation (Ongoing)
Use new tooling to implement priority features:
- Mythic+ dungeon tiers (already exists!)
- World scaling zones (for level 255)
- Custom class extensions

---

## 8. Conclusion

### Verdict: Inspiration Over Adoption

**TSWoW should NOT be directly adopted** for Dark Chaos because:
1. Different core (TrinityCore vs AzerothCore)
2. Dark Chaos already has mature tooling (Eluna, AIO, modules)
3. Migration effort outweighs benefits

**TSWoW SHOULD inspire Dark Chaos tooling**:
1. Declarative content definitions
2. TypeScript-based generators
3. Module organization patterns
4. Client asset management

### Dark Chaos Advantages Over TSWoW
| Aspect | Dark Chaos | TSWoW |
|--------|-----------|-------|
| Player base | Established | New projects only |
| Stability | Mature AC core | Custom fork |
| Scripting | Proven Eluna + AIO | Newer livescripts |
| Community | Large AC community | Smaller TSWoW community |
| Custom Content | Already extensive | Would need rebuild |

### Final Recommendation
**Keep Dark Chaos on AzerothCore** but:
1. Study TSWoW's content patterns for tooling inspiration
2. Use TSWoW's DBC output as reference for patches
3. Consider TSWoW for isolated prototyping of complex features
4. Contribute AC-compatible tools inspired by TSWoW concepts

---

## References
- TSWoW GitHub: https://github.com/tswow/tswow
- TSWoW Wiki: https://tswow.github.io/tswow-wiki/
- TSWoW Datascripts: https://tswow.github.io/tswow-wiki/documentation/datascripts/
- AzerothCore Modules: https://www.azerothcore.org/catalogue/
