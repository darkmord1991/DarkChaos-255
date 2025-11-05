-- DarkChaos Item Upgrade Addon - Test Script
-- Run this to verify the addon loads and basic functions work

local function TestAddonLoading()
    if not DarkChaos_ItemUpgrade then
        DEFAULT_CHAT_FRAME:AddMessage("ERROR: DarkChaos_ItemUpgrade addon not loaded!", 1, 0, 0);
        return false;
    end

    DEFAULT_CHAT_FRAME:AddMessage("DarkChaos_ItemUpgrade addon loaded successfully!", 0, 1, 0);
    return true;
end

local function TestUILoading()
    if not DarkChaos_ItemUpgradeFrame then
        DEFAULT_CHAT_FRAME:AddMessage("ERROR: Main UI frame not found!", 1, 0, 0);
        return false;
    end

    DEFAULT_CHAT_FRAME:AddMessage("UI frames loaded successfully!", 0, 1, 0);
    return true;
end

local function TestFunctions()
    local tests = {
        {name = "DarkChaos_ItemUpgrade_OnLoad", func = DarkChaos_ItemUpgrade_OnLoad},
        {name = "DarkChaos_ItemUpgrade_ShowFrame", func = DarkChaos_ItemUpgrade_ShowFrame},
        {name = "DarkChaos_ItemUpgrade_UpdateUI", func = DarkChaos_ItemUpgrade_UpdateUI},
        {name = "DarkChaos_ItemUpgrade_OnSliderValueChanged", func = DarkChaos_ItemUpgrade_OnSliderValueChanged},
        {name = "DarkChaos_ItemUpgrade_OnUpgradeClick", func = DarkChaos_ItemUpgrade_OnUpgradeClick},
    };

    local passed = 0;
    local total = #tests;

    for _, test in ipairs(tests) do
        if type(test.func) == "function" then
            passed = passed + 1;
        else
            DEFAULT_CHAT_FRAME:AddMessage("ERROR: Function " .. test.name .. " not found!", 1, 0, 0);
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("Function tests: " .. passed .. "/" .. total .. " passed", 0, 1, 0);
    return passed == total;
end

-- Slash command for testing
SLASH_DCUPGRADETEST1 = "/dcupgradetest";
SlashCmdList["DCUPGRADETEST"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("=== DarkChaos Item Upgrade Addon Test ===", 1, 1, 0);

    local addonTest = TestAddonLoading();
    local uiTest = TestUILoading();
    local funcTest = TestFunctions();

    if addonTest and uiTest and funcTest then
        DEFAULT_CHAT_FRAME:AddMessage("All tests passed! Addon is ready to use.", 0, 1, 0);
        DEFAULT_CHAT_FRAME:AddMessage("Type /dcupgrade to open the interface.", 0, 1, 0);
    else
        DEFAULT_CHAT_FRAME:AddMessage("Some tests failed. Check the errors above.", 1, 0, 0);
    end
end;