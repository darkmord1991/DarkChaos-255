# Prestige System - Player Guide

## 🎯 Alt-Friendly XP Bonus

### What is it?
Get bonus XP on new characters based on how many max-level (255) characters you already have!

### How much bonus do I get?
- **5% bonus XP per max-level character** on your account
- **Maximum 25% bonus** (capped at 5 characters)

### Example
```
1 max-level character → 5% bonus XP on alts
2 max-level characters → 10% bonus XP on alts
3 max-level characters → 15% bonus XP on alts
4 max-level characters → 20% bonus XP on alts
5+ max-level characters → 25% bonus XP on alts (maximum)
```

### Commands
- `.prestige altbonus info` - Check your current bonus

### Notes
- Max-level characters don't get the bonus (only alts do)
- Bonus applies automatically to all XP gains
- Welcome message shows your bonus when you log in

---

## 🏆 Prestige Challenges

### What are they?
Optional **HARD MODE** challenges you can attempt while leveling to 255 for extra rewards!

### Available Challenges

#### 🛡️ Iron Prestige
- **Goal**: Reach level 255 **without dying**
- **Difficulty**: Extreme
- **Rewards**: 
  - Special title: **"Iron [Your Name]"**
  - +2% permanent stat bonus

#### ⚡ Speed Prestige  
- **Goal**: Reach level 255 in **less than 100 hours** played
- **Difficulty**: High
- **Rewards**:
  - Special title: **"Swift [Your Name]"**
  - +2% permanent stat bonus

#### 🎯 Solo Prestige
- **Goal**: Reach level 255 **without joining a group**
- **Difficulty**: Medium
- **Rewards**:
  - Special title: **"Lone Wolf [Your Name]"**
  - +2% permanent stat bonus

### How to Start
1. Type `.prestige challenge list` to see all available challenges
2. Type `.prestige challenge start <type>` to begin
   - Example: `.prestige challenge start iron`
3. Level to 255 while following the rules!

### Commands
- `.prestige challenge list` - View all challenges and requirements
- `.prestige challenge start <iron|speed|solo>` - Start a challenge
- `.prestige challenge status` - Check your active/completed challenges

### Important Notes

**⚠️ Challenge Rules**
- You can do **multiple challenges at once** (if you're brave!)
- Once you fail a challenge, you must **restart it** to try again
- Challenges are **per prestige level** - you can attempt them again after prestiging

**💀 Failure Conditions**
- **Iron**: ANY death fails the challenge immediately
- **Speed**: Reaching 255 after 100 hours played fails
- **Solo**: Joining ANY group/party/raid fails immediately

**🎁 Rewards Stack!**
```
Complete all 3 challenges = +6% permanent stats (2% each)
+ Prestige Level 10 = +10% stats
─────────────────────────────────────────────
Total Maximum = +16% permanent stat bonus!
```

### Pro Tips

**Iron Prestige**:
- Stay in safe zones early levels
- Use defensive talents and gear
- Avoid risky quests and elite mobs
- Consider leveling in dungeons with a healer (if doing solo challenge too)

**Speed Prestige**:
- Plan efficient leveling routes
- Use XP potions and buffs
- Minimize downtime (crafting, AFK, etc.)
- The alt bonus helps! (25% XP = faster leveling)

**Solo Prestige**:
- Pick a strong solo class (Hunter, Warlock, Death Knight)
- Focus on solo-friendly zones
- Use pets and summons
- Complete solo quests and grinding spots

---

## 📊 Checking Your Progress

### Alt Bonus
```
.prestige altbonus info

Output:
════════════════════════════════
Max-level characters: 3
Current XP bonus: 15%
(5% per max-level character, max 25%)
```

### Challenges
```
.prestige challenge status

Output:
════════════════════════════════
=== Active Prestige Challenges ===
- Iron Prestige (Prestige Level 1)
- Speed Prestige (Prestige Level 1)
  Time remaining: 87h 23m

=== Completed Challenges ===
- Solo Prestige

Total challenge stat bonus: +2%
```

---

## ❓ FAQ

**Q: Can I lose my alt bonus?**
A: No! Once a character reaches 255, they permanently count toward your account bonus.

**Q: Do challenges reset when I prestige?**
A: Yes! You can attempt challenges again for each prestige level.

**Q: Can I pause a challenge?**
A: No. Once started, the challenge is active until you complete it, fail it, or prestige.

**Q: What if I DC during Iron Prestige?**
A: Disconnecting doesn't count as death. Your challenge continues when you log back in.

**Q: Can I do all 3 challenges at once?**
A: Yes! If you complete Iron + Speed + Solo simultaneously, you get all 3 rewards (+6% stats total).

**Q: Do challenge bonuses apply to prestige stat bonuses?**
A: Yes! They stack additively. Prestige 10 (+10%) + All Challenges (+6%) = +16% total.

**Q: What happens if I fail Speed Prestige at level 254?**
A: The challenge fails immediately. You can restart it and try again.

**Q: Can I group for Iron and Speed, just not Solo?**
A: Yes! Only Solo Prestige restricts grouping. Iron and Speed allow groups.

---

## 🎮 Combining Systems

### Optimal Leveling Strategy
1. **First Character**: Focus on reaching 255 (no alt bonus yet)
2. **Second Character**: You get 5% bonus XP - try Speed Prestige!
3. **Third Character**: 10% bonus XP - attempt Solo Prestige
4. **Fourth Character**: 15% bonus XP - go for Iron Prestige
5. **Fifth Character**: 20% bonus XP - try all 3 challenges at once!
6. **Sixth+ Characters**: 25% bonus XP (maximum) - farm prestige levels

### Prestige Strategy
- Complete challenges **before prestiging** (they reset after)
- Use alt bonus XP to complete Speed Prestige faster
- Stack all bonuses for maximum character power

---

## 🌟 Leaderboard Goals

Want to be the best? Aim for these achievements:

- **First Iron Prestige** - Server-wide announcement
- **Fastest Speed Prestige** - Under 50 hours played
- **Triple Challenge Champion** - Complete all 3 challenges in one prestige
- **Prestige 10 + All Challenges** - Maximum stat bonus (16%)
- **Alt Army** - 5+ characters at level 255 (25% bonus for future chars)

---

## 🔧 Troubleshooting

**Problem**: Alt bonus not showing
- **Solution**: Use `.prestige altbonus info` to verify. It may be 0% if you have no max-level characters yet.

**Problem**: Challenge failed unexpectedly
- **Solution**: Check `.prestige challenge status` for failure reason. Challenges are strict!

**Problem**: Don't see my challenge title
- **Solution**: Titles require client DBC modification. Contact server admin if missing.

**Problem**: XP bonus not applying
- **Solution**: Bonus only applies to non-max-level characters. Max-level (255) characters don't get bonus XP.

---

## 📞 Support

Having issues? Use these commands:
- `.prestige info` - General prestige information
- `.prestige altbonus info` - Alt bonus details  
- `.prestige challenge status` - Challenge progress
- `.prestige challenge list` - Available challenges

For bugs or questions, contact a GM or visit the server Discord!

---

**Good luck, and may your alts level swiftly! 🚀**
