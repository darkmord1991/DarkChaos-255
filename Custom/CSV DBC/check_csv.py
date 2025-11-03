#!/usr/bin/env python3
"""
Check Achievement.csv for data type issues and fix them
"""
import csv
import sys

csv_file = r"C:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255\Custom\CSV DBC\Achievement.csv"

print("Analyzing Achievement.csv for data type issues...")

with open(csv_file, 'r', encoding='utf-8', newline='') as f:
    reader = csv.reader(f, delimiter=',', quotechar='"')
    headers = next(reader)
    
    print(f"Headers ({len(headers)} columns): {headers[:10]}...")
    print(f"\nChecking all {sum(1 for row in csv.reader(open(csv_file, 'r', encoding='utf-8')))-1} data rows...")
    
    f.seek(0)
    reader = csv.reader(f, delimiter=',', quotechar='"')
    next(reader)  # Skip header
    
    issues = []
    for row_num, row in enumerate(reader, start=2):  # Start at 2 (1=header, 2=first data)
        if len(row) != len(headers):
            issues.append(f"Row {row_num}: Column count mismatch (has {len(row)}, expected {len(headers)})")
            if row_num == 1517:
                print(f"\n*** FOUND PROBLEM ROW 1517 ***")
                print(f"Row data: {row[:min(10, len(row))]}...")
                print(f"Column count: {len(row)} (expected {len(headers)})")
            continue  # Skip further checks for malformed rows
        
        # Check specific data types for numeric fields
        if row[0]:  # Only check if not empty
            try:
                # ID should be numeric
                int(row[0])
            except ValueError:
                issues.append(f"Row {row_num}: Non-numeric ID '{row[0]}'")
        
        if len(row) > 1 and row[1]:  # Only check if exists and not empty
            try:
                # Faction should be numeric
                int(row[1])
            except ValueError:
                issues.append(f"Row {row_num}: Non-numeric Faction '{row[1]}'")

print(f"\n{'='*60}")
if issues:
    print(f"Found {len(issues)} issues:")
    for issue in issues[:20]:  # Show first 20
        print(f"  - {issue}")
    if len(issues) > 20:
        print(f"  ... and {len(issues)-20} more")
else:
    print("✓ No issues found! CSV appears valid.")

print(f"{'='*60}\n")

# Also check line 1517 specifically
with open(csv_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()
    if len(lines) >= 1517:
        print(f"Line 1517 raw content:")
        print(repr(lines[1516][:200]))
