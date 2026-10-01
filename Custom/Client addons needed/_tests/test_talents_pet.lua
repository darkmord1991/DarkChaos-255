--[[
	DC-Talents headless test, second character: a level 80 hunter with a Ferocity pet.
	Covers the Pet tab (the retail tree renderer on the pet config) and applying loadout glyphs.

	Run from this directory:  lua test_talents_pet.lua        (-v prints errors as they happen)
]]

dofile("talents_sim.lua")
dofile("talents_client.lua")
local T = dofile("talents_testlib.lua")
local CLIENT = SIM.client
local ok, section, noNewErrors = T.ok, T.section, T.noNewErrors

CLIENT.player.class = "HUNTER"
CLIENT.player.level = 80
-- A level 80 pet has 16 talent points (WotLK: level / 4 - 4).
CLIENT.pet = { treeMask = 1, totalPoints = 16 }

local petTabs = CLIENT.Tabs(true)
ok(#petTabs == 1 and petTabs[1].name == "Ferocity", "the simulated pet has the Ferocity tree")

section("load")
local ns = T.Boot()
noNewErrors("boot as a hunter")
local env = ns.env
local L = ns.L

section("pet tab")
ToggleTalentFrame()
SIM.Run(0.5)
local frame = PlayerSpellsFrame
local FrameTabs = env.PlayerSpellsUtil.FrameTabs
ok(frame:IsTabAvailable(frame.petTabID), "a hunter with a pet gets the Pet tab")
ok(frame:TrySetTab(FrameTabs.Pet), "the Pet tab can be selected")
SIM.Run(0.3)
local page = frame.PetFrame
ok(page:IsVisible() and not frame.TalentsFrame:IsVisible(), "the pet page replaces the class talents")
ok(frame.TitleContainer.TitleText:GetText() == L.PET_TITLE, "the title reads Pet Talents")
noNewErrors("open the pet tab")

section("pet tree")
local missing, invisible = 0, 0
for _, talentID in ipairs(petTabs[1].talents) do
	local button = page:GetTalentButtonByNodeID(talentID)
	if not button then
		missing = missing + 1
	elseif not button:IsVisible() then
		invisible = invisible + 1
	end
end
ok(missing == 0 and invisible == 0, ("every Ferocity talent has a visible button (%d missing, %d hidden)"):format(missing, invisible))
ok(page.TreeName:GetText() == "FEROCITY" and page.TreePoints:GetText() == "0", "the header reads FEROCITY / 0")
ok(page.PointsText:GetText() == L.PET_POINTS_FORMAT:format(16), "16 pet talent points available")
ok(not page.ApplyButton:IsEnabled() and not page.UndoButton:IsEnabled(), "Apply and Undo start disabled")

local pet1
for _, talentID in ipairs(petTabs[1].talents) do
	if SIM.TalentData[talentID][2] == 0 then
		pet1 = talentID
		break
	end
end

page:GetTalentButtonByNodeID(pet1):Click("LeftButton")
SIM.Run(0.2)
ok(page:GetTalentButtonByNodeID(pet1):GetNodeInfo().currentRank == 1, "a left click stages a pet talent")
ok(page.ApplyButton:IsEnabled() and page.UndoButton:IsEnabled(), "Apply and Undo enable")
ok(page.PointsText:GetText() == L.PET_POINTS_FORMAT:format(15), "the staged rank costs a pet point")

page.UndoButton:Click("LeftButton")
SIM.Run(0.2)
ok(page:GetTalentButtonByNodeID(pet1):GetNodeInfo().currentRank == 0, "Undo drops the staged rank")

page:GetTalentButtonByNodeID(pet1):Click("LeftButton")
SIM.Run(0.2)
local before = #DCAddonProtocol.sent
page.ApplyButton:Click("LeftButton")
SIM.Run(1)
local request = DCAddonProtocol.sent[before + 1]
ok(request and request.module == "TLNT" and request.opcode == 0x03, "Apply sends APPLY_PET_BUILD")
ok(CLIENT.petRanks[pet1] == 1, "the server learned the pet talent")
local button = page:GetTalentButtonByNodeID(pet1)
ok(button and button:GetNodeInfo().currentRank == 1, "the rebuilt tree shows the learned rank")
ok(not page.ApplyButton:IsEnabled(), "Apply disables after the commit")
noNewErrors("pet apply")

button:Click("RightButton")
SIM.Run(0.2)
page.ApplyButton:Click("LeftButton")
SIM.Run(1)
ok(CLIENT.petRanks[pet1] == nil, "a learned pet talent can be refunded (free respec)")
noNewErrors("pet refund")

section("pet dismissed")
CLIENT.pet = nil
CLIENT.ResetTabCache()
SIM.FireEvent("UNIT_PET", "player")
SIM.Run(0.3)
ok(not frame:IsTabAvailable(frame.petTabID), "without a pet there is no Pet tab")
ok(not page:IsShown() and frame.TalentsFrame:IsShown(), "the window falls back to the talents tab")
noNewErrors("dismiss the pet")

section("pet without the server module")
CLIENT.pet = { treeMask = 1, totalPoints = 16 }
CLIENT.ResetTabCache()
SIM.FireEvent("UNIT_PET", "player")
SIM.Run(0.3)
ok(frame:IsTabAvailable(frame.petTabID), "summoning the pet brings the tab back")
ns.Server.state.hello = nil
frame:TrySetTab(FrameTabs.Pet)
SIM.Run(0.3)
local sentBefore = #DCAddonProtocol.sent
page:GetTalentButtonByNodeID(pet1):Click("LeftButton")
SIM.Run(0.2)
page.ApplyButton:Click("LeftButton")
SIM.Run(1)
ok(#DCAddonProtocol.sent == sentBefore, "nothing goes to the missing module")
ok(CLIENT.petRanks[pet1] == 1, "the pet talent is learned through the stock preview path")
ok(not page:IsCommitInProgress() and not page.ApplyButton:IsEnabled(), "the commit completes")
noNewErrors("pet preview path")

section("loadout glyphs")
-- A loadout that wants a major glyph in the first major socket; the glyph item is in the bags.
local loadout = ns.Loadouts.Create("Glyph test", {}, { major = { 56000, 0, 0 }, minor = { 0, 0, 0 } }, "test")
local configID = ns.Loadouts.ConfigIDFor(loadout)
ns.Loadouts.SetLastSelected(1, configID)
CLIENT.AddItem(0, 3, "Spell56000", 56000)
frame:TrySetTab(FrameTabs.Glyphs)
SIM.Run(0.2)
local glyphPage = DCTalentsGlyphPage
ok(glyphPage.LoadoutStatus:GetText() == L.GLYPHS_LOADOUT_STATUS:format("Glyph test", 1), "the Glyphs tab reports one glyph to apply (" .. tostring(glyphPage.LoadoutStatus:GetText()) .. ")")
ok(glyphPage.ApplyGlyphsButton:IsEnabled(), "Apply Loadout Glyphs is enabled")
glyphPage.ApplyGlyphsButton:Click("LeftButton")
SIM.Run(0.3)
ok(CLIENT.glyphs[1][1] == 56000, "the glyph went into the first major socket")
ok(glyphPage.LoadoutStatus:GetText() == L.GLYPHS_LOADOUT_MATCH:format("Glyph test"), "the status says the glyphs match")
ok(not glyphPage.ApplyGlyphsButton:IsEnabled(), "and the button disables")
noNewErrors("loadout glyphs")

T.Finish()
