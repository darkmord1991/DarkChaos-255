/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license: https://github.com/azerothcore/azerothcore-wotlk/blob/master/LICENSE-AGPL3
 */

#include "naxx40_config.h"

VanillaNaxxramas* VanillaNaxxramas::instance()
{
    static VanillaNaxxramas instance;
    return &instance;
}

class VanillaNaxxramas_WorldScript : public WorldScript
{
public:
    VanillaNaxxramas_WorldScript() : WorldScript("DC_Naxx40_WorldScript") { }

    void OnBeforeConfigLoad(bool /*reload*/) override
    {
        sVanillaNaxxramas->requireAttunement = sConfigMgr->GetOption<bool>("DC.Naxx40.RequireAttunement", true);
        sVanillaNaxxramas->requireNaxxStrath = sConfigMgr->GetOption<bool>("DC.Naxx40.RequireStratholmeEntrance", true);
    }
};

void AddVanillaNaxxramasScripts()
{
    new VanillaNaxxramas_WorldScript();
}
