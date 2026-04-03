import csv
from pathlib import Path


SPELL_CSV = Path("Custom/CSV DBC/Spell.csv")
OUT_CSV = Path("Custom/CSV DBC/Spell.model_mount_additions.csv")


MOUNT_SPELLS = [
    {
        "spell_id": 300700,
        "template_id": 32235,  # Golden Gryphon (flying)
        "creature_entry": 3461001,
        "name": "Dreamowl Firemount",
        "description": "Summons and dismisses a rideable Dreamowl Firemount.",
    },
    {
        "spell_id": 300701,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461004,
        "name": "Felblaze Infernal",
        "description": "Summons and dismisses a rideable Felblaze Infernal.",
    },
    {
        "spell_id": 300702,
        "template_id": 32235,  # Golden Gryphon (flying)
        "creature_entry": 3461005,
        "name": "Netherwing Mount",
        "description": "Summons and dismisses a rideable Netherwing Mount.",
    },
    {
        "spell_id": 300707,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461007,
        "name": "Black Skeletal Warhorse II",
        "description": "Summons and dismisses a rideable Black Skeletal Warhorse II.",
    },
    {
        "spell_id": 300720,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461013,
        "name": "Brown Skeletal Warhorse II",
        "description": "Summons and dismisses a rideable Brown Skeletal Warhorse II.",
    },
    {
        "spell_id": 300721,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461014,
        "name": "Green Skeletal Warhorse II",
        "description": "Summons and dismisses a rideable Green Skeletal Warhorse II.",
    },
    {
        "spell_id": 300722,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461015,
        "name": "Midnight Skeletal Warhorse II",
        "description": "Summons and dismisses a rideable Midnight Skeletal Warhorse II.",
    },
    {
        "spell_id": 300723,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461016,
        "name": "Purple Skeletal Warhorse II",
        "description": "Summons and dismisses a rideable Purple Skeletal Warhorse II.",
    },
    {
        "spell_id": 300724,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461017,
        "name": "Red Skeletal Warhorse II",
        "description": "Summons and dismisses a rideable Red Skeletal Warhorse II.",
    },
    {
        "spell_id": 300725,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461018,
        "name": "White Skeletal Warhorse II",
        "description": "Summons and dismisses a rideable White Skeletal Warhorse II.",
    },
    {
        "spell_id": 300703,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461009,
        "name": "Coldflame Infernal",
        "description": "Summons and dismisses a rideable Coldflame Infernal.",
    },
    {
        "spell_id": 300704,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461010,
        "name": "Flarecore Infernal",
        "description": "Summons and dismisses a rideable Flarecore Infernal.",
    },
    {
        "spell_id": 300705,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461011,
        "name": "Frostshard Infernal",
        "description": "Summons and dismisses a rideable Frostshard Infernal.",
    },
    {
        "spell_id": 300706,
        "template_id": 23214,  # Charger (ground)
        "creature_entry": 3461012,
        "name": "Hellfire Infernal",
        "description": "Summons and dismisses a rideable Hellfire Infernal.",
    },
]


def main() -> None:
    with SPELL_CSV.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        existing_rows = list(reader)
        rows_by_id = {int(row[0]): row for row in existing_rows}

    id_idx = header.index("ID")
    name_idx = header.index("Name_Lang_enUS")
    name_en_gb_idx = header.index("Name_Lang_enGB")
    desc_idx = header.index("Description_Lang_enUS")
    desc_en_gb_idx = header.index("Description_Lang_enGB")
    aura_desc_idx = header.index("AuraDescription_Lang_enUS")
    aura_desc_en_gb_idx = header.index("AuraDescription_Lang_enGB")
    misc_value_idx = header.index("EffectMiscValue_1")

    generated_rows = []
    for spec in MOUNT_SPELLS:
        template_id = spec["template_id"]
        if template_id not in rows_by_id:
            raise SystemExit(f"Template spell {template_id} not found in {SPELL_CSV}")

        row = rows_by_id[template_id].copy()
        row[id_idx] = str(spec["spell_id"])
        row[name_idx] = spec["name"]
        row[name_en_gb_idx] = spec["name"]
        row[desc_idx] = spec["description"]
        row[desc_en_gb_idx] = spec["description"]
        row[aura_desc_idx] = row[aura_desc_idx] or "Mounted."
        row[aura_desc_en_gb_idx] = row[aura_desc_idx]
        row[misc_value_idx] = str(spec["creature_entry"])

        if len(row) != len(header):
            raise SystemExit(
                f"Generated row length mismatch for {spec['spell_id']}: "
                f"{len(row)} vs {len(header)}"
            )

        generated_rows.append(row)

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_ALL)
        for row in generated_rows:
            writer.writerow(row)

    generated_ids = {str(spec["spell_id"]) for spec in MOUNT_SPELLS}
    updated_rows = [row for row in existing_rows if row[id_idx] not in generated_ids]
    updated_rows.extend(generated_rows)

    with SPELL_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_ALL)
        writer.writerow(header)
        writer.writerows(updated_rows)

    print(f"Wrote {OUT_CSV}")
    print(f"Updated {SPELL_CSV} with spell IDs: {', '.join(sorted(generated_ids))}")


if __name__ == "__main__":
    main()
