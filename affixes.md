# Affixes Reference

## Mythic+ affixes

Source: Mythic+ affix enum and handlers.

| Affix ID | Name | Spell ID | Effect | Status |
| --- | --- | --- | --- | --- |
| 1 | Bolstering | 900010 | When any non-boss enemy dies, nearby non-boss allies gain +20% max health and +20% damage (stacking). | Handler implemented |
| 2 | Necrotic | 900020 | Enemy melee attacks apply stacking Necrotic Wound; each stack reduces healing received by 1% and deals damage over time (up to 99 stacks). | Handler implemented |
| 3 | Grievous | 900030 | Players below 90% HP take periodic damage; stacks up to 10 and is removed when healed above 90%. | Handler implemented |
| 4 | Tyrannical | — | Bosses have +40% max health and deal +15% damage. | Handler implemented |
| 5 | Fortified | — | Non-boss enemies have +20% max health and deal +30% damage. | Handler implemented |
| 6 | Raging | — | Enemies deal +100% damage at low HP and cannot be crowd-controlled. | Declared only (no handler registered) |
| 7 | Sanguine | — | Enemies leave damaging pools on death that heal other enemies. | Declared only (no handler registered) |
| 8 | Volcanic | — | Volcanic plumes erupt under distant players. | Declared only (no handler registered) |

Notes:
- Spell IDs are the custom affix aura spells used by the handlers where applicable.
- The weekly schedule uses affix IDs from the database schedule table; the HUD worldstate sends affix IDs per run.

## Hinterland BG affixes

Source: Hinterland BG affix enum and constants.

| Code | Name | Spell ID | Target | Effect |
| --- | --- | --- | --- | --- |
| 1 | Sunlight | 910010 | Players | Clear weather: +10% haste to players. |
| 2 | Clear Skies | 910011 | Players | Clear weather: +15% damage to players. |
| 3 | Gentle Breeze | 910012 | Players | Light rain: +20% healing received to players. |
| 4 | Storm | 910020 | NPCs | Heavy rain: +15% damage to NPCs. |
| 5 | Heavy Rain | 910021 | NPCs | Storm: +20% armor to NPCs. |
| 6 | Fog | 910022 | NPCs | Sandstorm: +10% evasion to NPCs. |

Notes:
- Affix spell IDs are configurable and default to the constants above.
- The active affix code can be broadcast through worldstate and addon packets for HUD display.
- Weather type/intensity is mapped per affix and can be overridden via config.
