/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 *
 * CrossSystemItemClassFilter.h - "is this item meant for that class at all?"
 *
 * The generated loot pools (dc_vault_loot_table, dc_heroic_loot_pool) carry a
 * class_mask column, but most of it is unusable: 1023, 1535, 32767 and 262143
 * all mean "every class", and between them they cover the majority of the
 * rows. That left armor_type as the only thing actually separating classes,
 * and it cannot: leather is shared by rogue and druid, cloth by
 * priest/mage/warlock, mail by hunter/shaman, plate by warrior/paladin/death
 * knight - and the "Misc" bucket (rings, necks, trinkets, cloaks, and every
 * weapon in the pool) is shared by everyone. That is how a rogue ended up
 * being handed an intellect leather helm.
 *
 * So the pool metadata is not trusted for this. The decision is made from the
 * item itself:
 *
 *   1. item_template.AllowableClass, where the item declares a restriction.
 *   2. Can the class equip it at all - armor tier, weapon proficiency,
 *      shields, relics.
 *   3. Does it carry a stat the class can never use - the caster/physical
 *      split, plus strength (melee-only) and intellect (mana users only).
 *
 * Specs deliberately play no part: a Fury warrior may be handed Protection
 * plate and a Balance druid a Restoration piece. Only the class has to match.
 */

#ifndef DC_CROSSSYSTEM_ITEM_CLASS_FILTER_H
#define DC_CROSSSYSTEM_ITEM_CLASS_FILTER_H

#include "ItemTemplate.h"
#include "Player.h"
#include "SharedDefines.h"

namespace DC
{
namespace ItemClassFilter
{
    // Bit per ITEM_SUBCLASS_WEAPON_*.
    constexpr uint32 WeaponBit(uint32 weaponSubClass)
    {
        return 1u << weaponSubClass;
    }

    struct ClassGearProfile
    {
        uint32 armorSubClass;      // the class's own ITEM_SUBCLASS_ARMOR_* tier
        uint32 weaponSubClassMask; // weapon types the class can wield
        bool usesCasterStats;      // spirit / spell power family
        bool usesPhysicalStats;    // strength / agility / attack power family
        bool usesStrength;
        // Intellect is a mana-pool stat, not a caster stat: WotLK hunter tier
        // mail carries Agility, Attack Power *and* Intellect (Cryptstalker,
        // Windrunner's, Dragonstalker's, Ahn'Kahar). Only the classes with no
        // mana bar at all - warrior, rogue, death knight - can never use it.
        bool usesIntellect;
        // No usesAgility counterpart on purpose. Agility is not exclusive to
        // the agility classes: hybrid plate weapons carry it next to strength
        // (Inevitable Defeat is Str 100 / Agi 80), so forbidding it for the
        // plate classes made such items fit no class at all. usesPhysicalStats
        // already keeps agility away from the pure casters.
    };

    // WotLK proficiencies. Deliberately not read from the character's skill
    // lines: an untrained weapon-master skill (warrior polearms, say) is a trip
    // to a trainer, not a reason to keep a whole weapon type out of that
    // class's reward pool.
    inline ClassGearProfile const* GetClassGearProfile(uint8 classId)
    {
        constexpr uint32 MELEE_1H =
            WeaponBit(ITEM_SUBCLASS_WEAPON_AXE) | WeaponBit(ITEM_SUBCLASS_WEAPON_MACE) |
            WeaponBit(ITEM_SUBCLASS_WEAPON_SWORD);
        constexpr uint32 MELEE_2H =
            WeaponBit(ITEM_SUBCLASS_WEAPON_AXE2) | WeaponBit(ITEM_SUBCLASS_WEAPON_MACE2) |
            WeaponBit(ITEM_SUBCLASS_WEAPON_SWORD2) | WeaponBit(ITEM_SUBCLASS_WEAPON_POLEARM);
        constexpr uint32 RANGED =
            WeaponBit(ITEM_SUBCLASS_WEAPON_BOW) | WeaponBit(ITEM_SUBCLASS_WEAPON_GUN) |
            WeaponBit(ITEM_SUBCLASS_WEAPON_CROSSBOW);
        constexpr uint32 STAFF = WeaponBit(ITEM_SUBCLASS_WEAPON_STAFF);
        constexpr uint32 DAGGER = WeaponBit(ITEM_SUBCLASS_WEAPON_DAGGER);
        constexpr uint32 FIST = WeaponBit(ITEM_SUBCLASS_WEAPON_FIST);
        constexpr uint32 THROWN = WeaponBit(ITEM_SUBCLASS_WEAPON_THROWN);
        constexpr uint32 WAND = WeaponBit(ITEM_SUBCLASS_WEAPON_WAND);

        //                          armor tier, weapons, caster, physical, STR, INT
        static ClassGearProfile const warrior {
            ITEM_SUBCLASS_ARMOR_PLATE,
            MELEE_1H | MELEE_2H | RANGED | STAFF | DAGGER | FIST | THROWN,
            false, true, true, false };
        static ClassGearProfile const paladin {
            ITEM_SUBCLASS_ARMOR_PLATE,
            MELEE_1H | MELEE_2H,
            true, true, true, true };
        static ClassGearProfile const hunter {
            ITEM_SUBCLASS_ARMOR_MAIL,
            WeaponBit(ITEM_SUBCLASS_WEAPON_AXE) | WeaponBit(ITEM_SUBCLASS_WEAPON_SWORD) |
            MELEE_2H | RANGED | STAFF | DAGGER | FIST | THROWN,
            false, true, false, true };
        static ClassGearProfile const rogue {
            ITEM_SUBCLASS_ARMOR_LEATHER,
            MELEE_1H | RANGED | DAGGER | FIST | THROWN,
            false, true, false, false };
        static ClassGearProfile const priest {
            ITEM_SUBCLASS_ARMOR_CLOTH,
            WeaponBit(ITEM_SUBCLASS_WEAPON_MACE) | STAFF | DAGGER | WAND,
            true, false, false, true };
        static ClassGearProfile const deathKnight {
            ITEM_SUBCLASS_ARMOR_PLATE,
            MELEE_1H | MELEE_2H,
            false, true, true, false };
        static ClassGearProfile const shaman {
            ITEM_SUBCLASS_ARMOR_MAIL,
            WeaponBit(ITEM_SUBCLASS_WEAPON_AXE) | WeaponBit(ITEM_SUBCLASS_WEAPON_MACE) |
            WeaponBit(ITEM_SUBCLASS_WEAPON_AXE2) | WeaponBit(ITEM_SUBCLASS_WEAPON_MACE2) |
            STAFF | DAGGER | FIST,
            true, true, false, true };
        static ClassGearProfile const mage {
            ITEM_SUBCLASS_ARMOR_CLOTH,
            WeaponBit(ITEM_SUBCLASS_WEAPON_SWORD) | STAFF | DAGGER | WAND,
            true, false, false, true };
        static ClassGearProfile const warlock {
            ITEM_SUBCLASS_ARMOR_CLOTH,
            WeaponBit(ITEM_SUBCLASS_WEAPON_SWORD) | STAFF | DAGGER | WAND,
            true, false, false, true };
        static ClassGearProfile const druid {
            ITEM_SUBCLASS_ARMOR_LEATHER,
            WeaponBit(ITEM_SUBCLASS_WEAPON_MACE) | WeaponBit(ITEM_SUBCLASS_WEAPON_MACE2) |
            WeaponBit(ITEM_SUBCLASS_WEAPON_POLEARM) | STAFF | DAGGER | FIST,
            true, true, false, true };

        switch (classId)
        {
            case CLASS_WARRIOR:      return &warrior;
            case CLASS_PALADIN:      return &paladin;
            case CLASS_HUNTER:       return &hunter;
            case CLASS_ROGUE:        return &rogue;
            case CLASS_PRIEST:       return &priest;
            case CLASS_DEATH_KNIGHT: return &deathKnight;
            case CLASS_SHAMAN:       return &shaman;
            case CLASS_MAGE:         return &mage;
            case CLASS_WARLOCK:      return &warlock;
            case CLASS_DRUID:        return &druid;
            default:                 return nullptr;
        }
    }

    // Stats only a caster can turn into throughput or survivability.
    // ITEM_MOD_INTELLECT is deliberately absent - see ClassGearProfile.
    inline bool IsCasterOnlyStat(uint32 stat)
    {
        switch (stat)
        {
            case ITEM_MOD_SPIRIT:
            case ITEM_MOD_SPELL_POWER:
            case ITEM_MOD_SPELL_PENETRATION:
            case ITEM_MOD_MANA_REGENERATION:
            case ITEM_MOD_SPELL_HEALING_DONE:
            case ITEM_MOD_SPELL_DAMAGE_DONE:
            case ITEM_MOD_HIT_SPELL_RATING:
            case ITEM_MOD_CRIT_SPELL_RATING:
            case ITEM_MOD_HASTE_SPELL_RATING:
                return true;
            default:
                return false;
        }
    }

    // Stats only a melee or ranged attacker can use. Stamina, resilience and
    // the undifferentiated hit/crit/haste ratings appear in neither list -
    // every class benefits from those.
    inline bool IsPhysicalOnlyStat(uint32 stat)
    {
        switch (stat)
        {
            case ITEM_MOD_STRENGTH:
            case ITEM_MOD_AGILITY:
            case ITEM_MOD_ATTACK_POWER:
            case ITEM_MOD_RANGED_ATTACK_POWER:
            case ITEM_MOD_EXPERTISE_RATING:
            case ITEM_MOD_ARMOR_PENETRATION_RATING:
            case ITEM_MOD_DEFENSE_SKILL_RATING:
            case ITEM_MOD_DODGE_RATING:
            case ITEM_MOD_PARRY_RATING:
            case ITEM_MOD_BLOCK_RATING:
            case ITEM_MOD_BLOCK_VALUE:
            case ITEM_MOD_HIT_MELEE_RATING:
            case ITEM_MOD_HIT_RANGED_RATING:
            case ITEM_MOD_CRIT_MELEE_RATING:
            case ITEM_MOD_CRIT_RANGED_RATING:
            case ITEM_MOD_HASTE_MELEE_RATING:
            case ITEM_MOD_HASTE_RANGED_RATING:
                return true;
            default:
                return false;
        }
    }

    // Can this class equip the item at all? Rings, necks, trinkets and cloaks
    // sit outside the armour tiers and stay open to everyone.
    inline bool CanClassEquipItem(uint8 classId, ClassGearProfile const& profile, ItemTemplate const* proto)
    {
        if (proto->Class == ITEM_CLASS_WEAPON)
        {
            if (proto->SubClass >= MAX_ITEM_SUBCLASS_WEAPON)
                return false;

            return (profile.weaponSubClassMask & WeaponBit(proto->SubClass)) != 0;
        }

        if (proto->Class != ITEM_CLASS_ARMOR)
            return true;

        if (proto->InventoryType == INVTYPE_CLOAK)
            return true;

        switch (proto->SubClass)
        {
            case ITEM_SUBCLASS_ARMOR_MISC:
                return true;
            case ITEM_SUBCLASS_ARMOR_CLOTH:
            case ITEM_SUBCLASS_ARMOR_LEATHER:
            case ITEM_SUBCLASS_ARMOR_MAIL:
            case ITEM_SUBCLASS_ARMOR_PLATE:
                return proto->SubClass == profile.armorSubClass;
            case ITEM_SUBCLASS_ARMOR_BUCKLER:
            case ITEM_SUBCLASS_ARMOR_SHIELD:
                return classId == CLASS_WARRIOR || classId == CLASS_PALADIN || classId == CLASS_SHAMAN;
            case ITEM_SUBCLASS_ARMOR_LIBRAM:
                return classId == CLASS_PALADIN;
            case ITEM_SUBCLASS_ARMOR_IDOL:
                return classId == CLASS_DRUID;
            case ITEM_SUBCLASS_ARMOR_TOTEM:
                return classId == CLASS_SHAMAN;
            case ITEM_SUBCLASS_ARMOR_SIGIL:
                return classId == CLASS_DEATH_KNIGHT;
            default:
                return true;
        }
    }

    /**
     * True when the item belongs in that class's gear pool - equippable by the
     * class, and carrying no stat the class can never use.
     *
     * Spec-agnostic by design: any item a member of the class could reasonably
     * wear passes, whatever they have spent their talent points on.
     */
    inline bool IsItemForClass(uint8 classId, ItemTemplate const* proto)
    {
        if (!proto)
            return false;

        ClassGearProfile const* profile = GetClassGearProfile(classId);
        if (!profile)
            return true; // unknown or custom class - do not block its rewards

        // AllowableClass is uint32, and the usual "-1" in item_template loads
        // as 0xFFFFFFFF, so an unrestricted item passes the bit test with no
        // special case.
        if ((proto->AllowableClass & (1u << (classId - 1))) == 0)
            return false;

        if (!CanClassEquipItem(classId, *profile, proto))
            return false;

        for (uint32 i = 0; i < proto->StatsCount && i < uint32(MAX_ITEM_PROTO_STATS); ++i)
        {
            _ItemStat const& itemStat = proto->ItemStat[i];
            if (itemStat.ItemStatValue <= 0)
                continue;

            if (!profile->usesCasterStats && IsCasterOnlyStat(itemStat.ItemStatType))
                return false;
            if (!profile->usesPhysicalStats && IsPhysicalOnlyStat(itemStat.ItemStatType))
                return false;

            switch (itemStat.ItemStatType)
            {
                case ITEM_MOD_STRENGTH:
                    if (!profile->usesStrength)
                        return false;
                    break;
                case ITEM_MOD_INTELLECT:
                    if (!profile->usesIntellect)
                        return false;
                    break;
                default:
                    break;
            }
        }

        // Spell power granted through an equip spell rather than a stat - the
        // old +healing / +damage items. Same verdict as ITEM_MOD_SPELL_POWER.
        if (!profile->usesCasterStats && proto->HasSpellPowerStat())
            return false;

        return true;
    }

    inline bool IsItemForPlayer(Player const* player, ItemTemplate const* proto)
    {
        if (!player)
            return false;

        return IsItemForClass(player->getClass(), proto);
    }
}
}

// Canonical namespace alias, matching CrossSystemVaultUtils.h
namespace DarkChaos
{
namespace CrossSystem
{
    namespace ItemClassFilter = ::DC::ItemClassFilter;
}
}

#endif // DC_CROSSSYSTEM_ITEM_CLASS_FILTER_H
