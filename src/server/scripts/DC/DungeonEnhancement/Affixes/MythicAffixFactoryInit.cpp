/*
 * ============================================================================
 * Dungeon Enhancement System - Affix Factory Initialization
 * ============================================================================
 * Purpose: Register all affix handler factory functions
 * Called: On server startup (WorldScript::OnStartup)
 * ============================================================================
 */

#include "MythicAffixFactory.h"
#include "../Core/DungeonEnhancementConstants.h"

// Forward declare all affix factory functions
namespace DungeonEnhancement
{
    // Affix_Tyrannical.cpp
    extern MythicAffixHandler* CreateTyrannicalHandler(AffixData* data);

    // Affix_Fortified.cpp
    extern MythicAffixHandler* CreateFortifiedHandler(AffixData* data);

    // Affix_Bolstering.cpp
    extern MythicAffixHandler* CreateBolsteringHandler(AffixData* data);

    // Affix_Raging.cpp
    extern MythicAffixHandler* CreateRagingHandler(AffixData* data);

    // Affix_Sanguine.cpp
    extern MythicAffixHandler* CreateSanguineHandler(AffixData* data);

    // Affix_Necrotic.cpp
    extern MythicAffixHandler* CreateNecroticHandler(AffixData* data);

    // Affix_Volcanic.cpp
    extern MythicAffixHandler* CreateVolcanicHandler(AffixData* data);

    // Affix_Grievous.cpp
    extern MythicAffixHandler* CreateGrievousHandler(AffixData* data);

    /**
     * Initialize the affix factory registry
     * Registers all affix handler factory functions
     */
    void InitializeAffixFactory()
    {
        LOG_INFO("dungeon.enhancement.affixes", "Initializing Affix Handler Factory...");

        // Register Tier 1 affixes (M+2)
        sAffixFactory->RegisterHandler(AFFIX_TYRANNICAL, CreateTyrannicalHandler);
        sAffixFactory->RegisterHandler(AFFIX_FORTIFIED, CreateFortifiedHandler);

        // Register Tier 2 affixes (M+4)
        sAffixFactory->RegisterHandler(AFFIX_BOLSTERING, CreateBolsteringHandler);
        sAffixFactory->RegisterHandler(AFFIX_RAGING, CreateRagingHandler);
        sAffixFactory->RegisterHandler(AFFIX_SANGUINE, CreateSanguineHandler);

        // Register Tier 3 affixes (M+7)
        sAffixFactory->RegisterHandler(AFFIX_NECROTIC, CreateNecroticHandler);
        sAffixFactory->RegisterHandler(AFFIX_VOLCANIC, CreateVolcanicHandler);
        sAffixFactory->RegisterHandler(AFFIX_GRIEVOUS, CreateGrievousHandler);

        LOG_INFO("dungeon.enhancement.affixes", "Affix Handler Factory initialized with 8 handlers");
    }

    /**
     * Cleanup the affix factory
     * Called on server shutdown
     */
    void CleanupAffixFactory()
    {
        LOG_INFO("dungeon.enhancement.affixes", "Cleaning up Affix Handler Factory...");
        sAffixFactory->Cleanup();
    }

} // namespace DungeonEnhancement
