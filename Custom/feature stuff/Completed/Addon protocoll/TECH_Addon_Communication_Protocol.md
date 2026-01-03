# Addon Communication Protocol - Technical Deep Dive

## Executive Summary

This document analyzes the client-server communication protocol used by DarkChaos custom systems to synchronize data with WoW 3.3.5a client addons. It covers the current implementation, limitations, optimization strategies, and recommendations for future development.

---

## Current Implementation Overview

### Communication Channel: Addon Messages

WoW 3.3.5a provides a built-in addon message system using:
- **Client → Server:** `SendAddonMessage(prefix, message, channel, target)`
- **Server → Client:** `SMSG_MESSAGECHAT` with `CHAT_MSG_WHISPER` and `LANG_ADDON`

### Prefixes in Use

| System | Prefix | Direction | Purpose |
|--------|--------|-----------|---------|
| AoE Loot Extensions | `DCAOE` | Bidirectional | Settings sync, statistics |
| M+ Spectator | `DCSPEC` | Server → Client | Run updates, HUD sync |
| Hinterland BG | `HLBG` | Bidirectional | Score updates, queue status |
| Item Upgrades | `DCUPG` | Bidirectional | Upgrade status, catalog |

---

## Technical Architecture

### Message Flow Diagram

```
┌─────────────────┐                              ┌─────────────────┐
│   WoW Client    │                              │  AzerothCore    │
│    (Addon)      │                              │    (Server)     │
└────────┬────────┘                              └────────┬────────┘
         │                                                │
         │  SendAddonMessage("DCAOE", "GET_SETTINGS")    │
         │ ─────────────────────────────────────────────>│
         │                                                │
         │                    [Server processes request]  │
         │                                                │
         │  SMSG_MESSAGECHAT (LANG_ADDON, response)      │
         │ <─────────────────────────────────────────────│
         │                                                │
         │              [Addon parses response]           │
         │                                                │
```

### Server-Side Hook: `OnAddonMessage`

The `PlayerScript::OnAddonMessage` hook intercepts addon messages:

```
bool OnAddonMessage(Player* player, uint32 type, std::string const& message, 
                    Player* receiver, std::string const& prefix)
```

**Parameters:**
- `player`: Sender
- `type`: Message type (CHAT_MSG_WHISPER, CHAT_MSG_PARTY, etc.)
- `message`: Raw message string
- `receiver`: Target player (for whispers)
- `prefix`: Addon prefix (e.g., "DCAOE")

### Packet Construction (Server → Client)

```
WorldPacket data(SMSG_MESSAGECHAT, size);
data << uint8(CHAT_MSG_WHISPER);
data << uint32(LANG_ADDON);
data << uint64(0);                    // Sender GUID (0 for system)
data << uint32(0);                    // Custom chat size
data << uint64(0);                    // Receiver GUID  
data << uint32(message.size() + 1);   // Message length
data << message;                      // The actual message
data << uint8(0);                     // Chat tag
```

---

## Protocol Design Patterns

### Current: Delimiter-Based Protocol

**Format:** `COMMAND:arg1,arg2,arg3,...`

**Example (AoE Loot):**
```
GET_SETTINGS                           → Request
SETTINGS:1,2,1,1,0,45.0               → Response (enabled,quality,skin,smart,vendor,range)
SAVE_SETTINGS:1,3,0,1,1,30.0          → Save request
SAVED                                  → Confirmation
```

**Advantages:**
- Simple to parse
- Human-readable for debugging
- Low overhead for small messages

**Disadvantages:**
- No type safety
- Fragile if field order changes
- Limited nesting capability
- No built-in error handling

### Alternative: JSON Protocol

**Example:**
```json
{"cmd":"SETTINGS","enabled":true,"quality":2,"autoSkin":true}
```

**Advantages:**
- Self-documenting
- Type-safe (booleans, numbers, strings)
- Extensible without breaking compatibility
- Nested structures supported

**Disadvantages:**
- Higher bandwidth usage
- Parsing overhead on client (Lua)
- More complex server serialization

### Alternative: Binary Protocol

**Example:** Packed struct with header
```
[1 byte: command] [2 bytes: length] [N bytes: data]
```

**Advantages:**
- Minimal bandwidth
- Fast parsing
- Fixed-size fields

**Disadvantages:**
- Not human-readable
- Endianness concerns
- Requires version tracking
- Harder to debug

---

## Message Size Limitations

### WoW 3.3.5a Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Addon prefix max length | 16 characters | Hard client limit |
| Addon message max length | 255 characters | Per-message limit |
| Messages per second | ~10-15 | Soft rate limit |
| Channel restrictions | WHISPER, PARTY, RAID, GUILD | No global broadcast |

### Chunking Strategy for Large Data

For data exceeding 255 characters (e.g., replay data, leaderboards):

```
Message 1: "REPLAY:1/5:{"events":[{"t":0,"type":1,..."
Message 2: "REPLAY:2/5:...continued data..."
Message 3: "REPLAY:3/5:...more data..."
Message 4: "REPLAY:4/5:...more data..."
Message 5: "REPLAY:5/5:...final data]}"
```

**Client reassembly:**
1. Buffer chunks by sequence number
2. Wait for all chunks (with timeout)
3. Concatenate and parse

---

## Systems Requiring Addon Communication

### 1. AoE Loot Extensions (`DCAOE`)

**Current Messages:**
| Message | Direction | Purpose |
|---------|-----------|---------|
| `GET_SETTINGS` | C→S | Request player preferences |
| `SETTINGS:...` | S→C | Return current settings |
| `SAVE_SETTINGS:...` | C→S | Persist new settings |
| `SAVED` | S→C | Confirmation |
| `GET_STATS` | C→S | Request loot statistics |
| `STATS:...` | S→C | Return statistics |

**Linked Systems:**
- Base `ac_aoeloot` module
- Mythic+ range bonus calculation
- Player preferences database

### 2. M+ Spectator System (`DCSPEC`)

**Current Messages:**
| Message | Direction | Purpose |
|---------|-----------|---------|
| `RUN\|...` | S→C | Run status update (periodic) |
| `HUD\|...` | S→C | Worldstate sync |
| `REPLAY\|...` | S→C | Replay event data |

**Linked Systems:**
- MythicPlusRunManager
- ArenaSpectator framework
- WorldState broadcasting

### 3. Hinterland BG (`HLBG`)

**Current Messages:**
| Message | Direction | Purpose |
|---------|-----------|---------|
| `SCORE:...` | S→C | Score updates |
| `QUEUE:...` | S→C | Queue position |
| `AFFIX:...` | S→C | Active affix info |

**Linked Systems:**
- OutdoorPvPHL
- Scoreboard NPC
- AIO system integration

### 4. Item Upgrade System (`DCUPG`)

**Potential Messages:**
| Message | Direction | Purpose |
|---------|-----------|---------|
| `STATUS:...` | S→C | Current upgrade status |
| `CATALOG:...` | S→C | Available upgrades |
| `UPGRADE:...` | C→S | Request upgrade |
| `RESULT:...` | S→C | Upgrade result |

---

## AzerothCore Modifications Required

### 1. Hook Registration

Ensure `PlayerScript::OnAddonMessage` is properly registered:

**File:** `ScriptMgr.cpp`
```cpp
// Verify PLAYERHOOK_ON_ADDON_MESSAGE is in enum
// Verify ScriptMgr::OnAddonMessage dispatches correctly
```

### 2. Packet Handler Verification

**File:** `ChatHandler.cpp` or `Chat/ChatIO.cpp`

Verify `CMSG_MESSAGECHAT_ADDON` is handled:
- Prefix extraction
- Message validation
- Hook dispatch

### 3. Rate Limiting Consideration

**File:** `WorldSession.cpp`

Current behavior:
- No server-side rate limiting for addon messages
- Client handles rate limiting

**Recommendation:**
- Add configurable rate limit per player
- Prevent addon message spam DoS

### 4. Message Logging (Optional)

**File:** New `AddonMessageLogger.cpp`

For debugging:
- Log addon messages to separate file
- Filter by prefix
- Include timestamps and player info

---

## Security Considerations

### 1. Input Validation

**Issue:** Malformed addon messages can crash server or cause undefined behavior.

**Mitigation:**
- Validate message format before parsing
- Check array bounds
- Sanitize string inputs
- Use try/catch for parsing

### 2. Replay/Spoofing Prevention

**Issue:** Clients can send arbitrary addon messages.

**Mitigation:**
- Server is authoritative for all game state
- Never trust client-provided player data
- Validate player can perform requested action

### 3. Information Disclosure

**Issue:** Addon messages can leak information.

**Mitigation:**
- Only send data player should have access to
- Stream mode for spectator privacy
- Rate limit info requests

### 4. Prefix Collision

**Issue:** Other addons may use similar prefixes.

**Mitigation:**
- Use unique prefixes (DC prefix)
- Check for expected message formats
- Ignore malformed messages silently

---

## Testing Strategy

### 1. Unit Testing (Server-Side)

Test message parsing:
- Valid messages parse correctly
- Invalid messages return errors
- Edge cases (empty, max length, special chars)

### 2. Integration Testing

Test full round-trip:
1. Client sends request
2. Server processes
3. Server sends response
4. Client receives and parses

### 3. Load Testing

Stress test:
- Many players sending messages simultaneously
- Rapid-fire messages from single client
- Large message chunking

### 4. Client Addon Testing

Lua-side validation:
- Test in WoW client with addon loaded
- Verify UI updates correctly
- Test error handling

### 5. Testing Tools

| Tool | Purpose |
|------|---------|
| `/dump SendAddonMessage(...)` | Client-side testing |
| `LOG_DEBUG("addon", ...)` | Server-side logging |
| Wireshark | Packet inspection |
| Custom test addon | Automated testing |

---

## Performance Metrics to Track

### Server-Side

| Metric | Target | Action if Exceeded |
|--------|--------|-------------------|
| Messages processed/sec | < 1000/sec | Add rate limiting |
| Parse time per message | < 1ms | Optimize parsing |
| Memory per player (addon state) | < 1KB | Review data structures |

### Client-Side

| Metric | Target | Action if Exceeded |
|--------|--------|-------------------|
| Addon memory usage | < 1MB | Optimize Lua tables |
| Frame time impact | < 1ms/frame | Throttle updates |
| Message queue depth | < 100 | Add flow control |

---

## Recommendations

### Short-Term (Current Systems)

1. **Standardize message format** across all DC systems
2. **Add version field** to messages for compatibility
3. **Implement chunking** for large data transfers
4. **Add error responses** for failed operations

### Medium-Term (Optimization)

1. **Consider JSON** for complex data structures
2. **Implement message compression** for large payloads
3. **Add heartbeat mechanism** for connection health
4. **Create shared Lua library** for client-side parsing

### Long-Term (Architecture)

1. **Design message schema** with forward compatibility
2. **Implement request/response correlation** (message IDs)
3. **Add encryption** for sensitive data (if needed)
4. **Create protocol documentation** for addon developers

---

## Open Questions

1. Should we use a single prefix (`DC`) with sub-commands or keep system-specific prefixes?
2. Is JSON parsing overhead acceptable for client Lua performance?
3. Should we implement server-side message queuing for reliability?
4. Do we need backwards compatibility with older addon versions?
5. Should we support localized messages for different client languages?

---

## References

- [WoW API: SendAddonMessage](https://wowpedia.fandom.com/wiki/API_SendAddonMessage)
- [AzerothCore ScriptMgr Documentation](https://www.azerothcore.org/wiki/ScriptMgr)
- [WoW 3.3.5a Packet Structure](https://wowdev.wiki/SMSG_MESSAGECHAT)
- [Lua Performance Guide](http://lua-users.org/wiki/OptimisationTips)
