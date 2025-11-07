# DC-ItemUpgrade: Next Steps Checklist

## 🎯 Immediate Next Steps (Do These First)

### Step 1: Execute SQL Setup (2 minutes)
```powershell
# From workspace root
.\execute_sql_in_docker.ps1
```

**What this does:** Populates upgrade costs table with 75 entries
**Expected result:** "✅ SQL successfully executed!"

**Verification:**
```bash
docker exec ac-database mysql -uroot -p"password" acore_world \
  -e "SELECT COUNT(*) FROM dc_item_upgrade_costs;"
# Should output: 75
```

### Step 2: Test Currency Display (5 minutes)
1. Start server/reload addon
2. Give yourself test currency: `.upgrade token add flori 1000`
3. Open character sheet
4. **Verify:** "Upgrade Tokens: 1000" appears in top-right corner

### Step 3: Test Command System (5 minutes)
1. Open Item Upgrade addon
2. Click button that sends `.dcupgrade init`
3. **Verify:** Currency updates in addon window
4. Test upgrade on an item
5. **Verify:** Tokens deduct from display

---

## 🚀 Phase 2: Token Acquisition (Choose ONE)

### Option A: Quest Rewards ⭐ RECOMMENDED
**Why:** Most immersive, natural progression, best player experience

**Implementation steps:**
1. Create daily quest: "Collect Upgrade Materials"
   - Reward: 100 tokens + 50 essence
   - Repeatable daily
   
2. Create weekly quest: "Elite Challenge"
   - Reward: 500 tokens + 250 essence
   - Challenging content
   
3. Add to existing quest chains
   - Outdoor farm quests → +50 tokens each
   - Dungeon completion → +25-75 tokens

**Estimated time:** 1-2 hours
**Files to create:** Custom quest handler in C++ or Eluna script

**Example flow:**
```
Player completes quest
  ↓
Quest reward triggers
  ↓
Server adds tokens to player via db_item_upgrade_currency
  ↓
Player can see new balance on character sheet
```

---

### Option B: Vendor NPC
**Why:** Simple to implement, direct control of economy

**Implementation steps:**
1. Create NPC (can use existing vendor like Quartermaster)
2. Set token sale price
   - Example: 10 gold = 1 token
   - Configurable rate
   
3. Add vendor menu items
   - Single token
   - Token bundle (50, 100, 500)
   - Essence separately

4. Implement transaction handler

**Estimated time:** 1 hour
**Files to modify:** Vendor script, NPC template

**Example flow:**
```
Player talks to vendor
  ↓
Vendor shows "Buy 100 tokens for 1000 gold"
  ↓
Player clicks purchase
  ↓
Server deducts 1000 gold, adds 100 tokens
  ↓
Transaction complete
```

---

### Option C: PvP/BG Rewards
**Why:** Encourages PvP participation

**Implementation steps:**
1. Hook into Arena match completion
   - Win: 50 tokens + 25 essence
   - Loss: 10 tokens + 5 essence
   
2. Hook into Battleground completion
   - Win: 25 tokens + 12 essence
   - Loss: 5 tokens + 2 essence
   
3. Optional: Rating-based scaling
   - Starter Arena: Normal reward
   - Rated Arena: 2x reward
   - High rating: 3x reward

4. Event handler for PvP completion

**Estimated time:** 1.5-2 hours
**Files to modify:** Arena/BG event scripts

**Example flow:**
```
Arena match ends (player wins)
  ↓
Server hook fires
  ↓
Reward: 50 tokens added
  ↓
Chat message: "You earned 50 upgrade tokens!"
```

---

## 🔧 Implementation Guide by Option

### If You Choose Quests (Option A)

**Step 1: Create quest template**
```sql
-- Add to acore_world database
INSERT INTO quest_template VALUES (...);
```

**Step 2: Create reward handler**
- File: `Custom/Scripts/Quests/quest_upgrade_rewards.cpp`
- Hook: OnQuestComplete event
- Logic: Add tokens to player currency table

**Step 3: Set reward amounts**
- Daily: 100 tokens, 50 essence
- Weekly: 500 tokens, 250 essence
- Adjust based on testing

---

### If You Choose Vendor (Option B)

**Step 1: Create NPC vendor**
```sql
INSERT INTO creature_template VALUES (...);
INSERT INTO creature VALUES (...);
```

**Step 2: Create transaction script**
- File: `Custom/Scripts/Vendor/vendor_upgrade_tokens.cpp`
- Hook: OnGossipHello event
- Logic: Show token purchase menu

**Step 3: Configure pricing**
- Set exchange rate (gold → tokens)
- Create bundle options
- Handle insufficient gold

---

### If You Choose PvP (Option C)

**Step 1: Create event handler**
```cpp
// Custom/Scripts/PvP/pvp_upgrade_rewards.cpp
void OnArenaFinish(Arena* arena, bool isRated) {
    // Add tokens to winners
}

void OnBGFinish(BattleGround* bg) {
    // Add tokens to all participants
}
```

**Step 2: Configure reward amounts**
- Set base rewards
- Implement scaling (rating-based)
- Add messaging

**Step 3: Test edge cases**
- Multiple simultaneous matches
- Deserters (left game)
- Server crashes mid-match

---

## 📝 After You Choose

### Universal Steps (for any option):

1. **Code implementation** (~45-90 minutes)
2. **Compile and test** (~30 minutes)
3. **Database setup** (~15 minutes)
4. **In-game testing** (~30 minutes)
5. **Balance adjustment** (~30 minutes)

### Testing Scenarios:
- [ ] First token acquisition works
- [ ] Multiple acquisitions accumulate correctly
- [ ] Currency display updates in real-time
- [ ] Can spend tokens after earning them
- [ ] Relog doesn't lose tokens
- [ ] Database backups preserve currency

---

## 🎮 Testing Plan Template

After implementing chosen option:

```
Scenario: Player earns tokens and upgrades item

GIVEN: Player has no tokens
  AND: Item in inventory
  
WHEN: Player completes quest / buys from vendor / wins arena match
  
THEN: 
  [ ] Tokens added to player account
  [ ] Character sheet shows new total
  [ ] `/dcupgrade init` returns correct amount
  [ ] Player can upgrade item
  [ ] Tokens deducted after upgrade
  [ ] New item level reflected in character sheet
  [ ] On relog, tokens still present
```

---

## 🛠️ Troubleshooting Checklist

If tokens aren't working:

- [ ] SQL executed successfully (check row count)
- [ ] Addon loaded (check TOC file)
- [ ] Server reloaded after code changes
- [ ] Character sheet display visible
- [ ] Commands return correct format
- [ ] Database queries return data
- [ ] No compilation errors in logs

---

## 📊 Recommendation

**I recommend Option A (Quest Rewards) because:**
1. Most immersive for players
2. Encourages content engagement
3. Natural progression curve
4. Can be balanced with daily/weekly caps
5. Easiest to debug (quest system is stable)
6. Most expandable (easy to add more quests)

**Time estimate:** 1-2 hours total implementation + testing

---

## 🎯 Success Criteria

After implementing token sources, verify:

- ✅ Player can earn tokens naturally (not GM command)
- ✅ Earned tokens appear immediately in UI
- ✅ Currency display updates automatically
- ✅ Tokens persist after relog
- ✅ Can spend tokens on upgrades
- ✅ Upgrade costs deduct correctly
- ✅ Multiple players independent balances
- ✅ Economy is balanced (not too cheap/expensive)

---

## 💾 Files You'll Need to Create

### For Quests (Option A):
- `Custom/Scripts/Quests/quest_upgrade_rewards.cpp`
- `Custom/SQL/quests_upgrade.sql`

### For Vendor (Option B):
- `Custom/Scripts/Vendor/vendor_upgrade_tokens.cpp`
- `Custom/SQL/vendor_upgrade_npc.sql`

### For PvP (Option C):
- `Custom/Scripts/PvP/pvp_upgrade_rewards.cpp`
- `Custom/SQL/pvp_rewards_config.sql`

---

## 🏁 Final Checklist

After executing SQL:
- [ ] 75 cost entries in database
- [ ] Currency display works on character sheet
- [ ] Commands return proper format
- [ ] Ready to implement token sources

After implementing token sources:
- [ ] Players can earn tokens
- [ ] Tokens appear in UI
- [ ] Can spend tokens on upgrades
- [ ] System is balanced

Ready for production:
- [ ] All testing complete
- [ ] Documentation updated
- [ ] Performance verified
- [ ] Deployment plan created

---

## 📞 Need Help?

Check these files:
- `DCUPGRADE_INTEGRATION_GUIDE.md` - Full technical details
- `DCUPGRADE_QUICK_START.md` - One-page reference
- `DCUPGRADE_SESSION_COMPLETION.md` - Session summary

---

## ⏰ Timeline

| Task | Duration | Status |
|------|----------|--------|
| Execute SQL | 2 min | ⏳ READY |
| Test current system | 15 min | ⏳ READY |
| Implement token source | 60-90 min | 🔄 IN PROGRESS |
| Testing & balancing | 30-60 min | 🔄 IN PROGRESS |
| Production ready | - | ⏳ PENDING |

**Total time to completion: ~2.5-3 hours from now**

