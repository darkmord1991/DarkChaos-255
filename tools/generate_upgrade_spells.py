import csv
from pathlib import Path

SPELL_CSV = Path(r"c:/Users/flori/Desktop/WoW Server/Azeroth Fork/DarkChaos-255/Custom/CSV DBC/Spell.csv")
BONUS_SQL = Path(r"c:/Users/flori/Desktop/WoW Server/Azeroth Fork/DarkChaos-255/Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_upgrade_enchants_stat_bonuses.sql")

# Load existing spells and capture template row (Blessing of Kings)
with SPELL_CSV.open(encoding="utf-8", newline="") as f:
    reader = csv.reader(f)
    header = next(reader)
    existing_rows = [row for row in reader]

id_index = 0
effect_basepoints_1_index = header.index("EffectBasePoints_1")

name_lang_indices = {
    idx: col[len("Name_Lang_") :]
    for idx, col in enumerate(header)
    if col.startswith("Name_Lang_") and not col.endswith("_Mask")
}
description_lang_indices = {
    idx: col[len("Description_Lang_") :]
    for idx, col in enumerate(header)
    if col.startswith("Description_Lang_") and not col.endswith("_Mask")
}
aura_lang_indices = {
    idx: col[len("AuraDescription_Lang_") :]
    for idx, col in enumerate(header)
    if col.startswith("AuraDescription_Lang_") and not col.endswith("_Mask")
}

name_mask_index = header.index("Name_Lang_Mask")
description_mask_index = header.index("Description_Lang_Mask")
aura_mask_index = header.index("AuraDescription_Lang_Mask")

try:
    template_row = next(row for row in existing_rows if row[id_index] == "20217")
except StopIteration as exc:
    raise SystemExit("Template spell 20217 not found in Spell.csv") from exc

template_row = template_row[:]  # copy to avoid mutating original

# Parse stat bonuses from SQL insert statements
bonus_values: dict[int, float] = {}
with BONUS_SQL.open(encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line or not line.startswith("("):
            continue
        parts = line.split("),")
        for part in parts:
            part = part.strip()
            if not part:
                continue
            if part.startswith("("):
                part = part[1:]
            if part.endswith(")"):
                part = part[:-1]
            values = [p.strip() for p in part.split(",")]
            if len(values) < 2:
                continue
            try:
                spell_id = int(values[0])
                direct_bonus = float(values[1])
            except ValueError:
                continue
            bonus_values[spell_id] = direct_bonus

if not bonus_values:
    raise SystemExit("No upgrade enchant bonuses could be parsed from SQL file.")

target_ids = set(bonus_values.keys())

# Preserve all existing rows except the ones we replace
filtered_rows = [
    row for row in existing_rows
    if not (row and row[id_index].isdigit() and int(row[id_index]) in target_ids)
]

if len(filtered_rows) == len(existing_rows):
    print("No existing upgrade spell rows found; proceeding to append new entries.")

new_rows: list[list[str]] = []
for spell_id in sorted(target_ids):
    bonus = bonus_values[spell_id]
    percent = bonus * 100.0
    effect_amount = max(1, int(percent))
    base_points = effect_amount - 1

    tier = (spell_id - 80000) // 100
    level = (spell_id - 80000) % 100
    name = f"Item Upgrade: Tier {tier} Level {level}"
    description = f"Increases all stats by {percent:.2f}% while the upgraded item is equipped."
    aura_desc = f"All stats increased by {percent:.2f}%."

    row = template_row[:]  # clone template baseline
    row[id_index] = str(spell_id)
    row[effect_basepoints_1_index] = str(base_points)

    for idx, suffix in name_lang_indices.items():
        row[idx] = name if suffix == "enUS" else ""

    for idx, suffix in description_lang_indices.items():
        row[idx] = description if suffix == "enUS" else ""

    for idx, suffix in aura_lang_indices.items():
        row[idx] = aura_desc if suffix == "enUS" else ""

    row[name_mask_index] = template_row[name_mask_index]
    row[description_mask_index] = template_row[description_mask_index]
    row[aura_mask_index] = template_row[aura_mask_index]

    new_rows.append(row)

output_rows = filtered_rows + new_rows

with SPELL_CSV.open("w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f, quoting=csv.QUOTE_ALL)
    writer.writerow(header)
    writer.writerows(output_rows)

print(f"Wrote {len(new_rows)} upgrade spell rows to {SPELL_CSV.name} (replacing any previous versions).")
