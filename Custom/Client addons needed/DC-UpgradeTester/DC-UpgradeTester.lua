local addonName = "DC Upgrade Tester"

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

local function printColored(prefix, message)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffa0ff00[%s]|r %s", addonName, message))
end

local function handleSystemMessage(text)
    if text:find("^DCUPGRADE_") then
        printColored("Upgrade", text)
    end
end

frame:SetScript("OnEvent", function(_, _, message)
    handleSystemMessage(message)
end)

SLASH_DCUPGRADETEST1 = "/dcutest"
SlashCmdList.DCUPGRADETEST = function(args)
    local cmd, rest = args:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "init" then
        SendChatMessage(".dcupgrade init", "SAY")
    elseif cmd == "query" then
        local bag, slot = rest:match("^(%d+)%s+(%d+)$")
        if bag and slot then
            SendChatMessage(string.format(".dcupgrade query %d %d", bag, slot), "SAY")
        else
            printColored("Usage", " /dcutest query <bag> <slot>")
        end
    elseif cmd == "perform" then
        local bag, slot, level = rest:match("^(%d+)%s+(%d+)%s+(%d+)$")
        if bag and slot and level then
            SendChatMessage(string.format(".dcupgrade perform %d %d %d", bag, slot, level), "SAY")
        else
            printColored("Usage", " /dcutest perform <bag> <slot> <level>")
        end
    else
        printColored("Commands", " /dcutest init | query <bag> <slot> | perform <bag> <slot> <level>")
    end
end
