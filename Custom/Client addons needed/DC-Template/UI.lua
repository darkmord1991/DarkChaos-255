local _, NS = ...
NS.UI = {}

function NS.UI:Init()
    -- Create Main Window using DC-UI-Lib
    -- Syntax: DC_UI:CreateWindow(globalName, width, height, title)
    self.MainFrame = DC_UI:CreateWindow("DCTemplateFrame", 400, 300, "DC Template Addon")
    self.MainFrame:Hide()
    
    -- Add a Button
    local btn = DC_UI:CreateButton(self.MainFrame, 120, 30, "Test Button")
    btn:SetPoint("CENTER", 0, 20)
    btn:SetScript("OnClick", function()
        print("DC Template: Button Clicked!")
    end)
    
    -- Add a Label
    local label = self.MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", btn, "BOTTOM", 0, -10)
    label:SetText("This is a template addon using DC-UI-Lib")
    label:SetTextColor(1, 1, 1)
end

function NS.UI:Toggle()
    if self.MainFrame:IsShown() then
        self.MainFrame:Hide()
    else
        self.MainFrame:Show()
    end
end
