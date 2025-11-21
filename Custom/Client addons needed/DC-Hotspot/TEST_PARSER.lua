-- Test the new message parser
-- Paste this in-game: /run dofile("Interface\\AddOns\\DC-Hotspot\\TEST_PARSER.lua")

print("|cffFFD700Testing DC-Hotspot Message Parser|r")
print(string.rep("-", 60))

-- Test message from your chat log
local testMessage = "ID: 31 | Map: 0 | Zone: Duskwood (10) | Pos: (-4739.6, -2212.5, 534.1) | Time Left: 30m"

print("\nTest message:")
print("|cffaaaaaa" .. testMessage .. "|r")

-- Extract data manually to verify
local id = testMessage:match("ID:%s*(%d+)")
local map = testMessage:match("Map:%s*(%d+)")
local zoneName, zoneId = testMessage:match("Zone:%s*([^%(]+)%s*%((%d+)%)")
local x, y, z = testMessage:match("Pos:%s*%(([%-%d%.]+),%s*([%-%d%.]+),%s*([%-%d%.]+)%)")
local timeValue, timeUnit = testMessage:match("Time Left:%s*(%d+)(%w+)")

print("\n|cff00ff00Extracted values:|r")
print(string.format("  ID: %s", tostring(id)))
print(string.format("  Map: %s", tostring(map)))
print(string.format("  Zone: %s (%s)", tostring(zoneName), tostring(zoneId)))
print(string.format("  Coords: x=%s, y=%s, z=%s", tostring(x), tostring(y), tostring(z)))
print(string.format("  Time: %s%s", tostring(timeValue), tostring(timeUnit)))

-- Convert time
if timeValue and timeUnit then
    local dur = tonumber(timeValue)
    if timeUnit == "m" then dur = dur * 60 end
    print(string.format("  Duration: %d seconds", dur))
end

print("\n" .. string.rep("-", 60))
print("|cff00ff00Parser test complete!|r")
print("Enable debug mode and wait for next hotspot announcement to see parsing in action.")
