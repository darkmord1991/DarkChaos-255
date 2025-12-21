# DarkChaos Unified Collection System

**Priority:** B6-B8 (Medium Priority)  
**Effort:** High (4-6 weeks total)  
**Impact:** High (Endgame content, player engagement)  
**Architecture:** Unified Plugin-Based System

---

## Executive Summary

This document outlines a **unified collection system** for DarkChaos-255 that consolidates:
- **Mount Journal** (planned)
- **Pet Collection** (planned)
- **Transmog Appearances** (existing - needs integration)
- **Toys** (future)
- **Heirlooms** (future - ties to existing upgrade system)
- **Titles** (future)

The system is designed as a **plugin-based architecture** where each collectible type is a module that registers with a central collection manager. This allows easy expansion without rewriting core logic.

---

## Evaluation of Current Systems

### Existing: Transmogrification Addon

**Strengths:**
| Aspect | Assessment |
|--------|------------|
| UI Framework | Uses Ace3 libraries (mature, well-tested) |
| Communication | Uses AIO for server-client sync |
| Collection Storage | Account-wide `CollectedAppearances` table |
| Tooltip Integration | Hooks `OnTooltipSetItem` for "New Appearance" |
| Preview System | Full 3D model preview with TryOn() |

**Weaknesses:**
| Aspect | Issue |
|--------|-------|
| Protocol | Uses AIO, not DCAddonProtocol (inconsistent) |
| Isolation | Standalone addon, not integrated with DC ecosystem |
| No Journal View | Only shows per-slot appearances, no full collection browse |
| No Statistics | Doesn't track collected count, rarity breakdown |

### Planned: Mount Journal (24_MOUNT_JOURNAL.md)

**Design Quality:** ⭐⭐⭐⭐ (Good)
- Clear database schema
- Account-wide collection model
- Random mount feature specified
- Achievement integration planned

**Missing:**
- No protocol integration with DCAddonProtocol
- UI mockup lacking detail
- No pagination for large collections

### Planned: Pet Collection (25_PET_COLLECTION.md)

**Design Quality:** ⭐⭐⭐⭐ (Good)
- Similar structure to Mount Journal
- Pet naming feature
- Favorites system

**Missing:**
- Same issues as Mount Journal
- Could share significant code with Mount system

---

## Why a Unified System?

### Code Reuse Analysis

| Component | Mount | Pet | Transmog | Toy | Shared? |
|-----------|-------|-----|----------|-----|---------|
| Grid UI | ✓ | ✓ | ✓ | ✓ | **90%** |
| Pagination | ✓ | ✓ | ✓ | ✓ | **100%** |
| Search/Filter | ✓ | ✓ | ✓ | ✓ | **95%** |
| Favorites | ✓ | ✓ | ✗ | ✓ | **85%** |
| Random Summon | ✓ | ✓ | ✗ | ✗ | **80%** |
| Account Storage | ✓ | ✓ | ✓ | ✓ | **100%** |
| Achievement Hook | ✓ | ✓ | ✓ | ✓ | **95%** |
| Preview Model | ✓ | ✓ | ✓ | ✗ | **70%** |

**Conclusion:** ~85% code can be shared via a plugin architecture.

### User Experience

A unified system provides:
1. **Consistent UI** - Same look and feel across all collection types
2. **Single Frame** - One window with tabs (like retail)
3. **Unified Statistics** - "You've collected X/Y total collectibles"
4. **Cross-Collection Achievements** - "Collect 500 items across all types"

---

## Architecture Decision: DCAddonProtocol Integration

### Current State
- Transmogrification uses **AIO** (legacy)
- Other DC addons use **DCAddonProtocol** (modern, JSON-based)

### Recommendation
**Migrate to DCAddonProtocol** for:
1. Unified message format (JSON by default)
2. Built-in debug/logging via `/dc debug`
3. Request tracking and statistics
4. Error handling infrastructure
5. Module wrapper pattern (`DC.Collection.*`)

### Proposed Protocol Addition

```lua
-- Add to DCAddonProtocol.lua
DC.Module.COLLECTION = "COLL"

DC.Collection = {
    -- Core collection queries
    GetAll = function(type) DC:Request("COLL", 0x01, { type = type }) end,
    GetCount = function(type) DC:Request("COLL", 0x02, { type = type }) end,
    
    -- Mount-specific
    SummonMount = function(id) DC:Request("COLL", 0x10, { spellId = id }) end,
    SummonRandomMount = function() DC:Request("COLL", 0x11, {}) end,
    SetMountFavorite = function(id, fav) DC:Request("COLL", 0x12, { spellId = id, favorite = fav }) end,
    
    -- Pet-specific
    SummonPet = function(id) DC:Request("COLL", 0x20, { petId = id }) end,
    SummonRandomPet = function() DC:Request("COLL", 0x21, {}) end,
    RenamePet = function(id, name) DC:Request("COLL", 0x22, { petId = id, name = name }) end,
    
    -- Transmog (bridge to existing)
    SyncTransmog = function() DC:Request("COLL", 0x30, {}) end,
    
    -- Toys
    UseToy = function(id) DC:Request("COLL", 0x40, { itemId = id }) end,
    
    -- Statistics
    GetStatistics = function() DC:Request("COLL", 0x50, {}) end,
}

DC.Opcode.Collection = {
    -- Client -> Server
    CMSG_GET_COLLECTION = 0x01,
    CMSG_GET_COUNT = 0x02,
    CMSG_SET_FAVORITE = 0x03,
    CMSG_USE_COLLECTABLE = 0x04,
    CMSG_GET_STATISTICS = 0x05,
    CMSG_SEARCH = 0x06,
    
    -- Server -> Client
    SMSG_COLLECTION_DATA = 0x10,
    SMSG_COLLECTION_COUNT = 0x11,
    SMSG_ITEM_LEARNED = 0x12,
    SMSG_STATISTICS = 0x13,
    SMSG_SEARCH_RESULTS = 0x14,
    SMSG_ERROR = 0x1F,
}
```

---

## Retail Reference (Screenshots Analysis)

Based on the provided screenshots (German client):

### Mount Journal ("Reittiere")
- **284 mounts** collected
- Left panel: Scrollable list with icons + names
- Right panel: 3D preview + source info
- "Aufsitzen" (Mount) button
- Filter/search bar
- "Zufälliges Lieblingsreittier" (Random favorite mount)

### Toy Box ("Spielzeugkiste")
- **125/933** collected (shows total)
- Grid layout (3x6 = 18 per page)
- Page indicator: "Seite 7/7"
- Search + Filter options

### Appearances ("Vorlagen")
- **199/928** collected for Mage class
- Tabbed by equipment slot (head icons)
- "Sets" vs "Gegenstände" (Items) toggle
- Grid of head appearances
- Page indicator: "Seite 1/52"

**Key Insight:** Retail uses a tabbed interface at the bottom:
- Reittiere (Mounts)
- Haustierführer (Pets)
- Spielzeugkiste (Toys)
- Erbstücke (Heirlooms)
- Vorlagen (Appearances)
- Lagerplätze (Void Storage)

---

## Recommended Implementation Order

| Phase | Module | Dependencies | Effort |
|-------|--------|--------------|--------|
| **1** | Core Framework | DCAddonProtocol | 1 week |
| **2** | Mount Journal | Core Framework | 1.5 weeks |
| **3** | Pet Collection | Core Framework | 1.5 weeks |
| **4** | Transmog Integration | Existing transmog + Core | 1 week |
| **5** | Toy Box | Core Framework | 1 week |
| **6** | Polish & Achievements | All above | 1 week |

---

## File Structure

```
Custom/Client addons needed/DC-Collections/
├── DC-Collections.toc
├── Core/
│   ├── CollectionManager.lua      -- Plugin registration, shared state
│   ├── CollectionFrame.lua        -- Main frame with tabs
│   ├── CollectionGrid.lua         -- Reusable grid component
│   ├── CollectionSearch.lua       -- Search/filter logic
│   ├── CollectionPreview.lua      -- 3D model preview
│   └── CollectionTooltip.lua      -- Shared tooltip hooks
├── Modules/
│   ├── MountJournal.lua           -- Mount-specific logic
│   ├── PetCollection.lua          -- Pet-specific logic
│   ├── TransmogBridge.lua         -- Bridge to existing transmog
│   ├── ToyBox.lua                 -- Toy collection
│   └── HeirloomCollection.lua     -- Heirloom tracking
├── Locale/
│   ├── enUS.lua
│   └── deDE.lua
└── assets/
    └── *.blp                      -- UI textures
```

---

## Next Steps

See related documents:
1. [01_SERVER_ARCHITECTURE.md](01_SERVER_ARCHITECTURE.md) - C++ server implementation
2. [02_CLIENT_ADDON_DESIGN.md](02_CLIENT_ADDON_DESIGN.md) - Lua addon structure
3. [03_DATABASE_SCHEMA.md](03_DATABASE_SCHEMA.md) - SQL tables
4. [04_IMPLEMENTATION_ROADMAP.md](04_IMPLEMENTATION_ROADMAP.md) - Detailed timeline

---

## Summary

| Aspect | Decision |
|--------|----------|
| Architecture | Plugin-based unified system |
| Protocol | DCAddonProtocol (JSON) |
| UI | Single frame with tabs |
| Storage | Account-wide database tables |
| Expandability | New types = new module file |
| Transmog | Bridge existing addon, gradual migration |
