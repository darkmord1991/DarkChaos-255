import csv
import re

# Path to the generated SQL file
sql_file = 'Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_item_upgrade_clones_generated.sql'

# Path to Item.csv
csv_file = 'Custom/CSV DBC/Item.csv'

# Read the SQL file and extract item_template inserts
item_data = {}
with open(sql_file, 'r') as f:
    for line in f:
        if 'REPLACE INTO item_template VALUES (' in line:
            # Extract the values, handling quoted strings
            start = line.find('(') + 1
            end = line.rfind(')')
            values_str = line[start:end]
            # Split by comma, but keep quoted strings together
            values = []
            current = ''
            in_quote = False
            for char in values_str:
                if char == "'":
                    in_quote = not in_quote
                if char == ',' and not in_quote:
                    values.append(current)
                    current = ''
                else:
                    current += char
            values.append(current)
            # Strip spaces
            values = [v.strip() for v in values]
            entry = int(values[0])
            if 2000000 <= entry < 3000000:  # Clone range
                print(f"Processing entry {entry}")
                class_id = int(values[1])
                subclass_id = int(values[2])
                sound_override = int(values[3])
                # Material is omitted, assume 6 for armor
                material = 6
                display_id = int(values[5])
                inventory_type = int(values[6])
                # Sheath omitted or invalid, set to 0
                sheath_type = 0
                item_data[entry] = {
                    'ClassID': class_id,
                    'SubclassID': subclass_id,
                    'Sound_Override_Subclassid': sound_override,
                    'Material': material,
                    'DisplayInfoID': display_id,
                    'InventoryType': inventory_type,
                    'SheatheType': sheath_type
                }

# Read Item.csv and update clone entries
updated_rows = []
with open(csv_file, 'r', newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        entry = int(row['ID'])
        if entry in item_data:
            # Update with correct values
            row.update(item_data[entry])
        updated_rows.append(row)

# Write back to Item.csv
with open(csv_file, 'w', newline='') as f:
    fieldnames = ['ID', 'ClassID', 'SubclassID', 'Sound_Override_Subclassid', 'Material', 'DisplayInfoID', 'InventoryType', 'SheatheType']
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(updated_rows)

print(f"Updated {len(item_data)} clone entries in Item.csv")