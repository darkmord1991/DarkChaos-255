# Collection System - Implementation Roadmap

**Total Estimated Time:** 4-6 weeks  
**Team Size:** 1-2 developers  
**Priority:** Medium (B6-B8)

---

## Phase Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    IMPLEMENTATION TIMELINE                          │
├─────────────────────────────────────────────────────────────────────┤
│ Week 1        │ Week 2        │ Week 3        │ Week 4        │ W5  │
│               │               │               │               │     │
│ ┌───────────┐ │ ┌───────────┐ │ ┌───────────┐ │ ┌───────────┐ │ ┌───┤
│ │ Phase 1   │ │ │ Phase 2   │ │ │ Phase 3   │ │ │ Phase 4   │ │ │ 5 │
│ │ Core      │ │ │ Mounts    │ │ │ Pets      │ │ │ Transmog  │ │ │Pol│
│ │ Framework │ │ │ Journal   │ │ │ Collection│ │ │ Bridge    │ │ │ish│
│ └───────────┘ │ └───────────┘ │ └───────────┘ │ └───────────┘ │ └───┤
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Core Framework (Week 1)

**Goal:** Build the foundation that all collection modules will use.

### Tasks

| Task | Effort | Priority | Dependencies |
|------|--------|----------|--------------|
| Create database tables (definitions) | 2h | Critical | None |
| Create database tables (collections) | 2h | Critical | Definitions |
| Implement ICollectionModule interface | 4h | Critical | None |
| Implement CollectionManager singleton | 6h | Critical | Interface |
| Add COLL module to DCAddonProtocol | 3h | Critical | None |
| Create basic addon structure | 4h | Critical | Protocol |
| Implement CollectionManager.lua | 6h | Critical | Structure |
| Implement GridView component | 8h | High | Manager |
| Implement SearchBar component | 3h | High | GridView |
| Create main CollectionFrame | 6h | High | Components |
| Write unit tests | 4h | Medium | All above |

### Deliverables

- [ ] Database schema created and tested
- [ ] Server-side ICollectionModule interface defined
- [ ] CollectionManager singleton functional
- [ ] DCAddonProtocol extended with COLL module
- [ ] Basic addon loads without errors
- [ ] Empty frame with tabs renders

### Acceptance Criteria

1. `/collections` opens empty collection frame
2. Server responds to `COLL|0x01` requests
3. Tab switching works (visual only)

---

## Phase 2: Mount Journal (Week 2)

**Goal:** Complete mount collection implementation as the template for other modules.

### Tasks

| Task | Effort | Priority | Dependencies |
|------|--------|----------|--------------|
| Populate dc_mount_definitions | 4h | Critical | Phase 1 |
| Implement MountModule (server) | 8h | Critical | CollectionManager |
| Implement mount learning hook | 3h | Critical | MountModule |
| Implement MountModule.lua (client) | 6h | Critical | Phase 1 addon |
| Mount grid with icons and names | 4h | High | GridView |
| 3D mount preview | 6h | High | Frame |
| Mount filtering (type/rarity/source) | 4h | High | SearchBar |
| Favorite system | 3h | High | Module |
| Random mount summoning | 4h | High | Module |
| Smart mount (ground vs flying) | 2h | Medium | Random |
| Mount usage tracking | 2h | Medium | Module |
| Mount achievements | 4h | Medium | Module |

### Deliverables

- [ ] 100+ mounts in definition table
- [ ] All account mounts visible in journal
- [ ] Click to summon mount
- [ ] Right-click to favorite
- [ ] Random mount button works
- [ ] Filters work correctly

### Acceptance Criteria

1. Player can view all mounts (collected/uncollected)
2. Learning a mount adds to collection instantly
3. Summoning mount from UI works
4. Random favorite mount works
5. Achievement "Collect 10 mounts" triggers

---

## Phase 3: Pet Collection (Week 3)

**Goal:** Pet collection using the mount pattern.

### Tasks

| Task | Effort | Priority | Dependencies |
|------|--------|----------|--------------|
| Populate dc_pet_definitions | 4h | Critical | Phase 1 |
| Implement PetModule (server) | 6h | Critical | CollectionManager |
| Pet learning/summoning hooks | 3h | Critical | PetModule |
| Implement PetModule.lua (client) | 5h | Critical | Phase 1 addon |
| Pet grid display | 3h | High | GridView |
| Pet 3D preview | 4h | High | ModelPreview |
| Pet naming system | 4h | High | Module |
| Pet favorites | 2h | High | Module |
| Random pet summoning | 3h | High | Module |
| Auto-summon pet option | 2h | Medium | Module |
| Pet achievements | 3h | Medium | Module |
| Pet sources display | 2h | Medium | Tooltip |

### Deliverables

- [ ] 50+ pets in definition table
- [ ] Pet journal tab functional
- [ ] Pet renaming works
- [ ] Favorites and random summon
- [ ] DarkChaos exclusive pets added

### Acceptance Criteria

1. Pet tab shows all pets correctly
2. Summoning pet from UI works
3. Renaming pet persists
4. Random favorite pet works
5. Pet achievements trigger

---

## Phase 4: Transmog Integration (Week 4)

**Goal:** Bridge existing Transmogrification addon with collection system.

### Tasks

| Task | Effort | Priority | Dependencies |
|------|--------|----------|--------------|
| Analyze existing transmog tables | 2h | Critical | None |
| Create TransmogBridge (server) | 6h | Critical | CollectionManager |
| Implement TransmogModule.lua | 6h | Critical | Phase 1 addon |
| Slot-based filtering | 4h | High | Module |
| Appearance count tracking | 3h | High | Bridge |
| Cross-reference with existing addon | 4h | High | Module |
| "Open Transmog" button | 2h | Medium | Frame |
| Appearance statistics | 3h | Medium | Stats panel |
| Appearance achievements | 3h | Medium | Module |
| Migration documentation | 2h | Low | All above |

### Deliverables

- [ ] Transmog tab shows appearance count
- [ ] Slot filtering works
- [ ] Links to existing transmog UI
- [ ] No duplicate data storage
- [ ] Works alongside existing addon

### Acceptance Criteria

1. Transmog tab shows X/Y appearances
2. Filtering by slot works
3. Click opens existing transmog UI
4. Collecting new appearance updates count
5. No conflicts with existing addon

---

## Phase 5: Polish & Extras (Week 5)

**Goal:** Quality improvements, toys, and final polish.

### Tasks

| Task | Effort | Priority | Dependencies |
|------|--------|----------|--------------|
| Toy Box implementation | 8h | High | Phase 1 |
| Toy definitions (100+ items) | 4h | High | Toy module |
| Cross-collection statistics | 4h | High | All modules |
| Statistics panel UI | 4h | High | Stats |
| Collection progress bars | 3h | Medium | UI |
| Toast notifications | 3h | Medium | UI |
| Sound effects | 2h | Medium | UI |
| Keybind support | 2h | Medium | Frame |
| Settings panel | 4h | Medium | Config |
| German localization | 4h | Medium | All text |
| Documentation | 4h | Medium | All |
| Bug fixes and testing | 8h | High | All |

### Deliverables

- [ ] Toy Box functional
- [ ] Statistics panel shows all types
- [ ] Cross-collection achievements
- [ ] Polish and sounds
- [ ] Full documentation

### Acceptance Criteria

1. All 5 tabs functional (Mount, Pet, Transmog, Toy, Stats)
2. No major bugs
3. Performance acceptable (<100ms response)
4. German language complete

---

## Future Phases (Post-Release)

### Phase 6: Heirloom Integration
- Connect to existing upgrade system
- Show upgrade levels
- Track account-wide heirlooms

### Phase 7: Title Collection
- Track earned titles
- Display source information
- Title achievements

### Phase 8: Advanced Features
- Collection sharing/comparing
- Guild collection statistics
- Collection leaderboard

---

## Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Transmog addon conflicts | High | Medium | Bridge pattern, no replacement |
| Performance with large collections | Medium | Medium | Pagination, lazy loading |
| Database migration issues | High | Low | Thorough testing, backups |
| Protocol changes break addons | High | Low | Version negotiation |
| Scope creep | Medium | High | Strict phase gates |

---

## Resource Requirements

### Development
- 1-2 C++ developers for server-side
- 1 Lua developer for addon
- Access to test server

### Data
- Mount spell IDs and sources
- Pet entry IDs and sources
- Toy item IDs

### Assets
- UI textures (can reuse from transmog)
- Tab icons
- Rarity border colors

---

## Testing Plan

### Unit Tests
- CollectionManager methods
- Module registration
- JSON serialization

### Integration Tests
- Server-client communication
- Database operations
- Achievement triggering

### User Acceptance Tests
- Full collection workflow
- Edge cases (empty collection, max collection)
- Multi-character scenarios

### Performance Tests
- 1000+ items in collection
- Rapid tab switching
- Multiple simultaneous users

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Frame open time | <500ms | Client timing |
| Server response time | <100ms | Protocol logging |
| Collection sync accuracy | 100% | Manual verification |
| Bug count post-release | <5 major | Issue tracker |
| Player adoption | >50% | Slash command usage |

---

## Rollout Plan

### Week 5 (Internal)
1. Deploy to dev server
2. Team testing
3. Bug fixes

### Week 6 (Beta)
1. Deploy to test realm
2. Selected player testing
3. Feedback collection
4. Critical bug fixes

### Week 7 (Release)
1. Deploy to live server
2. Announcement post
3. Monitor for issues
4. Hotfix capability ready

---

## Summary

| Phase | Duration | Key Deliverable |
|-------|----------|-----------------|
| 1 - Core | 1 week | Framework + empty UI |
| 2 - Mounts | 1 week | Full mount journal |
| 3 - Pets | 1 week | Full pet collection |
| 4 - Transmog | 1 week | Transmog bridge |
| 5 - Polish | 1 week | Toys + Statistics |

**Total: 5 weeks development + 1-2 weeks testing/rollout**
