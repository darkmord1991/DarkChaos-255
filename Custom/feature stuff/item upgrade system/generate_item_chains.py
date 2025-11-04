#!/usr/bin/env python3
"""
DarkChaos-255 Item Upgrade Chain Generator
Generates SQL INSERT statements for creating upgrade chains from base items
This implements the "lowest effort" approach: one item_template entry per iLvl

Usage:
    python generate_item_chains.py --track-id 2 --base-ilvl 226 --max-ilvl 245 --item-count 50

Output:
    Generates SQL file with all item entries and upgrade chain definitions
"""

import argparse
import sys
from dataclasses import dataclass
from typing import List, Dict, Optional


@dataclass
class ItemChainConfig:
    """Configuration for generating an item upgrade chain"""
    track_id: int
    track_name: str
    source_content: str  # dungeon, raid, hlbg
    difficulty: str     # normal, heroic, mythic
    
    base_ilvl: int      # Starting iLvl
    max_ilvl: int       # Max after upgrades
    upgrade_steps: int  # Number of steps (usually 5)
    ilvl_per_step: int  # +4 or +3 per step
    
    base_entry_offset: int  # Start ID for this track's items (e.g., 50000)


class ItemUpgradeChainGenerator:
    """Generates SQL for item upgrade chains"""
    
    def __init__(self, output_file: str = "item_upgrade_chains.sql"):
        self.output_file = output_file
        self.sql_statements = []
        self.item_id_counter = 50000  # Starting item entry IDs
        
    def generate_item_entries_for_item(
        self, 
        base_item_name: str,
        item_template_entry: int,
        item_slot: str,
        item_quality: int,
        item_type: str,
        config: ItemChainConfig
    ) -> Dict[str, int]:
        """
        Generate 6 item entries (levels 0-5) for a single base item
        
        Returns dict of:
        {
            'chain_id': id,
            'ilvl_0': entry_id,
            'ilvl_1': entry_id,
            ...
            'ilvl_5': entry_id
        }
        """
        entries = {}
        
        # Generate 6 item entries (upgrade levels 0-5)
        for level in range(config.upgrade_steps + 1):
            new_entry_id = self.item_id_counter
            self.item_id_counter += 10  # Gap of 10 for potential expansion
            
            ilvl = config.base_ilvl + (level * config.ilvl_per_step)
            
            entries[f'ilvl_{level}'] = new_entry_id
            
            # Generate item_template SQL for this level
            # This creates the actual item entry in the database
            item_template_sql = self._generate_item_template_sql(
                new_entry_id,
                base_item_name,
                f" [iLvl {ilvl}]",  # Append to name for clarity
                ilvl,
                item_quality,
                item_slot,
                item_type
            )
            self.sql_statements.append(item_template_sql)
        
        return entries
    
    def _generate_item_template_sql(
        self,
        entry_id: int,
        name: str,
        suffix: str,
        ilvl: int,
        quality: int,
        slot: str,
        item_type: str
    ) -> str:
        """Generate SQL INSERT for item_template"""
        
        # Map slot names to inventory types
        slot_to_inv_type = {
            'head': 1,
            'neck': 2,
            'shoulder': 3,
            'chest': 5,
            'waist': 6,
            'legs': 7,
            'feet': 8,
            'wrist': 9,
            'hand': 10,
            'finger': 11,
            'trinket': 12,
            'back': 16,
        }
        
        # Map armor type to subclass
        type_to_subclass = {
            'plate': 4,
            'mail': 3,
            'leather': 2,
            'cloth': 1,
        }
        
        inv_type = slot_to_inv_type.get(slot, 0)
        subclass = type_to_subclass.get(item_type, 0)
        
        full_name = name + suffix
        
        sql = f"""
-- Item: {full_name} (iLvl {ilvl})
INSERT INTO item_template (
    entry, class, subclass, name, displayid, quality, flags, 
    buy_count, sell_price, buy_price, max_count, stackable, container_slots,
    stat_type1, stat_value1, stat_type2, stat_value2, stat_type3, stat_value3,
    damage_min1, damage_max1, damage_type1, armor, holy_res, fire_res, nature_res, frost_res, shadow_res, arcane_res,
    bonding, unique_count, item_level, required_level, required_skill, required_skill_rank, 
    required_spell, flags_extra, expansion_id, inventory_type, script_name
) VALUES (
    {entry_id},                          -- entry
    4,                                   -- class (Armor)
    {subclass},                          -- subclass (plate/mail/leather/cloth)
    '{full_name}',                       -- name
    0,                                   -- displayid (will be set from base item)
    {quality},                           -- quality ({quality} = epic)
    0,                                   -- flags
    1,                                   -- buy_count
    0,                                   -- sell_price (set from base)
    0,                                   -- buy_price
    1,                                   -- max_count
    1,                                   -- stackable
    0,                                   -- container_slots
    0,0,0,0,0,0,                         -- stat types/values (copied from original)
    0,0,0,                               -- damage (armor pieces)
    0,                                   -- armor
    0,0,0,0,0,0,                         -- resistances
    1,                                   -- bonding (Binds when picked up)
    1,                                   -- unique_count
    {ilvl},                              -- item_level
    80,                                  -- required_level
    0,                                   -- required_skill
    0,                                   -- required_skill_rank
    0,                                   -- required_spell
    0,                                   -- flags_extra
    3,                                   -- expansion_id (WotLK)
    {inv_type},                          -- inventory_type
    'npc_item_upgrade_flag'              -- script_name (optional)
) ON DUPLICATE KEY UPDATE name=VALUES(name), item_level=VALUES(item_level);
"""
        return sql
    
    def generate_chain_record(
        self,
        base_item_name: str,
        item_quality: int,
        item_slot: str,
        item_type: str,
        config: ItemChainConfig,
        entries: Dict[str, int]
    ) -> str:
        """Generate dc_item_upgrade_chains INSERT statement"""
        
        sql = f"""
INSERT INTO dc_item_upgrade_chains (
    base_item_name, item_quality, item_slot, item_type, track_id,
    ilvl_0_entry, ilvl_1_entry, ilvl_2_entry, ilvl_3_entry, ilvl_4_entry, ilvl_5_entry,
    season, description
) VALUES (
    '{base_item_name}',                   -- base_item_name
    {item_quality},                       -- item_quality
    '{item_slot}',                        -- item_slot
    '{item_type}',                        -- item_type
    {config.track_id},                    -- track_id
    {entries['ilvl_0']},                  -- ilvl_0_entry
    {entries['ilvl_1']},                  -- ilvl_1_entry
    {entries['ilvl_2']},                  -- ilvl_2_entry
    {entries['ilvl_3']},                  -- ilvl_3_entry
    {entries['ilvl_4']},                  -- ilvl_4_entry
    {entries['ilvl_5']},                  -- ilvl_5_entry
    0,                                    -- season (0 = permanent)
    'Upgradeable {item_type} {item_slot}: {config.difficulty} {config.source_content}'
);
"""
        return sql
    
    def generate_chains_from_config(
        self,
        items: List[Dict],
        config: ItemChainConfig
    ):
        """
        Generate all chains from a list of base items
        
        items = [
            {'name': 'Item Name', 'slot': 'chest', 'type': 'plate', 'quality': 4},
            ...
        ]
        """
        
        for item_data in items:
            # Generate item entries (iLvl progression)
            entries = self.generate_item_entries_for_item(
                base_item_name=item_data['name'],
                item_template_entry=item_data.get('entry', 0),
                item_slot=item_data['slot'],
                item_quality=item_data.get('quality', 4),
                item_type=item_data['type'],
                config=config
            )
            
            # Generate chain record
            chain_sql = self.generate_chain_record(
                base_item_name=item_data['name'],
                item_quality=item_data.get('quality', 4),
                item_slot=item_data['slot'],
                item_type=item_data['type'],
                config=config,
                entries=entries
            )
            self.sql_statements.append(chain_sql)
    
    def save_to_file(self):
        """Write all SQL statements to file"""
        with open(self.output_file, 'w', encoding='utf-8') as f:
            f.write("-- DarkChaos-255: Auto-generated Item Upgrade Chains\n")
            f.write("-- This file was generated by generate_item_chains.py\n")
            f.write("-- DO NOT EDIT BY HAND\n\n")
            f.write("-- ============================================================\n")
            f.write("-- ITEM TEMPLATE ENTRIES (6 per item = 6 iLvl progression)\n")
            f.write("-- ============================================================\n\n")
            
            for stmt in self.sql_statements:
                f.write(stmt)
            
            f.write("\n-- ============================================================\n")
            f.write("-- Summary: Generated upgrade chains\n")
            f.write(f"-- Total item entries: {(self.item_id_counter - 50000) // 10}\n")
            f.write("-- ============================================================\n")
        
        print(f"✓ Generated {self.output_file}")
        print(f"  Total item entries: {(self.item_id_counter - 50000) // 10}")


def create_sample_items_for_track(track: str) -> List[Dict]:
    """
    Create sample item definitions for a track
    
    In real usage, these would be queried from existing item_template
    """
    
    samples = {
        'heroic_dungeon': [
            {'name': 'Heroic Breastplate of the Eternal', 'slot': 'chest', 'type': 'plate', 'quality': 4},
            {'name': 'Heroic Crown of the Eternal', 'slot': 'head', 'type': 'plate', 'quality': 4},
            {'name': 'Heroic Legguards of the Eternal', 'slot': 'legs', 'type': 'plate', 'quality': 4},
            {'name': 'Heroic Pauldrons of the Eternal', 'slot': 'shoulder', 'type': 'plate', 'quality': 4},
            {'name': 'Heroic Gauntlets of the Eternal', 'slot': 'hand', 'type': 'plate', 'quality': 4},
            {'name': 'Heroic Greaves of the Eternal', 'slot': 'feet', 'type': 'plate', 'quality': 4},
            
            {'name': 'Heroic Hauberk of the Eternal', 'slot': 'chest', 'type': 'mail', 'quality': 4},
            {'name': 'Heroic Helm of the Eternal', 'slot': 'head', 'type': 'mail', 'quality': 4},
            {'name': 'Heroic Leggings of the Eternal', 'slot': 'legs', 'type': 'mail', 'quality': 4},
            {'name': 'Heroic Shoulderpads of the Eternal', 'slot': 'shoulder', 'type': 'mail', 'quality': 4},
            
            {'name': 'Heroic Tunic of the Eternal', 'slot': 'chest', 'type': 'leather', 'quality': 4},
            {'name': 'Heroic Mask of the Eternal', 'slot': 'head', 'type': 'leather', 'quality': 4},
            
            {'name': 'Heroic Robe of the Eternal', 'slot': 'chest', 'type': 'cloth', 'quality': 4},
            {'name': 'Heroic Hood of the Eternal', 'slot': 'head', 'type': 'cloth', 'quality': 4},
        ],
        'mythic_raid': [
            {'name': 'Mythic Plate of the Eternal', 'slot': 'chest', 'type': 'plate', 'quality': 4},
            {'name': 'Mythic Helm of the Eternal', 'slot': 'head', 'type': 'plate', 'quality': 4},
            {'name': 'Mythic Mail Hauberk of the Eternal', 'slot': 'chest', 'type': 'mail', 'quality': 4},
            {'name': 'Mythic Leather Tunic of the Eternal', 'slot': 'chest', 'type': 'leather', 'quality': 4},
            {'name': 'Mythic Cloth Robe of the Eternal', 'slot': 'chest', 'type': 'cloth', 'quality': 4},
        ]
    }
    
    return samples.get(track, [])


def main():
    parser = argparse.ArgumentParser(
        description='Generate Item Upgrade Chain SQL',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate heroic dungeon items
  python generate_item_chains.py --track heroic_dungeon --output heroic_chains.sql
  
  # Generate mythic raid items
  python generate_item_chains.py --track mythic_raid --output mythic_chains.sql
  
  # Generate all tracks
  python generate_item_chains.py --generate-all
        """
    )
    
    parser.add_argument(
        '--track',
        choices=['hlbg', 'heroic_dungeon', 'mythic_dungeon', 'raid_normal', 'raid_heroic', 'raid_mythic'],
        help='Which track to generate items for'
    )
    parser.add_argument(
        '--output',
        default='item_upgrade_chains.sql',
        help='Output SQL file (default: item_upgrade_chains.sql)'
    )
    parser.add_argument(
        '--generate-all',
        action='store_true',
        help='Generate all tracks to separate files'
    )
    
    args = parser.parse_args()
    
    # Track configurations
    configs = {
        'hlbg': ItemChainConfig(
            track_id=1, track_name='HLBG Progression',
            source_content='hlbg', difficulty='normal',
            base_ilvl=219, max_ilvl=239, upgrade_steps=5, ilvl_per_step=4,
            base_entry_offset=50000
        ),
        'heroic_dungeon': ItemChainConfig(
            track_id=2, track_name='Heroic Dungeon Gear',
            source_content='dungeon', difficulty='heroic',
            base_ilvl=226, max_ilvl=245, upgrade_steps=5, ilvl_per_step=4,
            base_entry_offset=51000
        ),
        'mythic_dungeon': ItemChainConfig(
            track_id=3, track_name='Mythic Dungeon Gear',
            source_content='dungeon', difficulty='mythic',
            base_ilvl=239, max_ilvl=258, upgrade_steps=5, ilvl_per_step=4,
            base_entry_offset=52000
        ),
        'raid_normal': ItemChainConfig(
            track_id=4, track_name='Raid Normal',
            source_content='raid', difficulty='normal',
            base_ilvl=245, max_ilvl=264, upgrade_steps=5, ilvl_per_step=4,
            base_entry_offset=53000
        ),
        'raid_heroic': ItemChainConfig(
            track_id=5, track_name='Raid Heroic',
            source_content='raid', difficulty='heroic',
            base_ilvl=258, max_ilvl=277, upgrade_steps=5, ilvl_per_step=4,
            base_entry_offset=54000
        ),
        'raid_mythic': ItemChainConfig(
            track_id=6, track_name='Raid Mythic',
            source_content='raid', difficulty='mythic',
            base_ilvl=271, max_ilvl=290, upgrade_steps=5, ilvl_per_step=4,
            base_entry_offset=55000
        ),
    }
    
    if args.generate_all:
        for track_name, config in configs.items():
            output_file = f'{track_name}_chains.sql'
            generator = ItemUpgradeChainGenerator(output_file)
            items = create_sample_items_for_track(track_name)
            generator.generate_chains_from_config(items, config)
            generator.save_to_file()
    else:
        if not args.track:
            parser.print_help()
            print("\nError: Please specify --track or use --generate-all")
            sys.exit(1)
        
        config = configs[args.track]
        generator = ItemUpgradeChainGenerator(args.output)
        items = create_sample_items_for_track(args.track)
        
        if not items:
            print(f"Warning: No sample items found for track '{args.track}'")
            print(f"Creating empty generator...")
        
        generator.generate_chains_from_config(items, config)
        generator.save_to_file()


if __name__ == '__main__':
    main()
