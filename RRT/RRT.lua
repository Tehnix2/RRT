-- RRT v0.03
-- Auto-resets raid lockouts based on user preferences

RRT = {}
RRT.Version = "0.03"

-------------------------------------------------------------------
-- Saved Variables and Defaults
-------------------------------------------------------------------

-- Initialize saved variables with defaults
RRT_Settings = RRT_Settings or {
    Enabled = true,
    AutoResetDays = {
        [1] = false, -- Monday
        [2] = false, -- Tuesday
        [3] = true,  -- Wednesday (default)
        [4] = false, -- Thursday
        [5] = false, -- Friday
        [6] = false, -- Saturday
        [7] = false, -- Sunday
    },
    ResetOnLeaveGroup = false,
    ShowResetMessage = true,
    LastResetDay = 0,
}

RRT_CharacterData = RRT_CharacterData or {
    LastResetCheck = 0,
}

-- Day names for display
local DayNames = {
    [1] = "Monday",
    [2] = "Tuesday",
    [3] = "Wednesday",
    [4] = "Thursday",
    [5] = "Friday",
    [6] = "Saturday",
    [7] = "Sunday",
}

-------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------


local function GetCurrentDayOfWeek()
    local weekday = tonumber(date("%w"))
    if not weekday then
        -- Fallback: use calendar API
        local weekday_calendar = CalendarGetWeekday()
        return weekday_calendar
    end
    return weekday == 0 and 7 or weekday
end

local function GetDayOfYear()
    local day = tonumber(date("%j"))
    if not day then
        -- Fallback calculation
        local month, day_of_month, year = CalendarGetDate()
        local days_in_months = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
        if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
            days_in_months[2] = 29
        end
        local day_count = day_of_month
        for i = 1, month - 1 do
            day_count = day_count + days_in_months[i]
        end
        return day_count
    end
    return day
end


local function ShouldResetToday()
    local currentDay = GetCurrentDayOfWeek()
    return RRT_Settings.AutoResetDays[currentDay] == true
end

local function HasAlreadyResetToday()
    local currentDayOfYear = GetDayOfYear()
    return RRT_CharacterData.LastResetCheck == currentDayOfYear
end

-------------------------------------------------------------------
-- Core Reset Function
-------------------------------------------------------------------

local function PerformRaidReset()
    -- Reset all instance types
    if ResetInstances then ResetInstances() end    
    if ResetRaids then ResetRaids() end
    if ResetDungeons then ResetDungeons() end
    
    -- Handle saved instances via C_Instance API
    if C_Instance and C_Instance.GetSavedMapAndDifficulty then
        for _, lockout in ipairs(C_Instance:GetSavedMapAndDifficulty()) do
            if C_LootLockout and C_LootLockout.ResetInstanceDifficulty then
                C_LootLockout.ResetInstanceDifficulty(lockout.mapID, lockout.difficultyID)
            end
        end
    end
    
    -- Query instance binds to refresh the UI
    if C_LootLockout and C_LootLockout.QueryInstanceBinds then
        C_LootLockout.QueryInstanceBinds()
    end
    
    -- Update last reset day
    RRT_CharacterData.LastResetCheck = GetDayOfYear()
    
    -- Show confirmation message if enabled
    if RRT_Settings.ShowResetMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r All raid lockouts have been reset.", 1, 1, 0)
    end
end

-------------------------------------------------------------------
-- Check and Reset Function
-------------------------------------------------------------------

function RRT.CheckAndResetRaids()
    if not RRT_Settings.Enabled then
        return
    end
    
    if not ShouldResetToday() then
        return
    end
    
    if HasAlreadyResetToday() then
        return
    end
    
    PerformRaidReset()
end

-------------------------------------------------------------------
-- Manual Reset Command
-------------------------------------------------------------------

function RRT.ManualReset()
    PerformRaidReset()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Manual reset completed.", 1, 1, 0)
end

-------------------------------------------------------------------
-- Settings GUI
-------------------------------------------------------------------

local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "RRTSettingsPanel", UIParent)
    panel.name = "RRT"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RRT v" .. RRT.Version)
    
    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure automatic raid lockout resets")
    
    -- Enable/Disable checkbox
    local enabledCheckbox = CreateFrame("CheckButton", "RRTEnabledCheckbox", panel, "UICheckButtonTemplate")
    enabledCheckbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    enabledCheckbox.text = enabledCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enabledCheckbox.text:SetPoint("LEFT", enabledCheckbox, "RIGHT", 5, 0)
    enabledCheckbox.text:SetText("Enable Automatic Raid Reset")
    enabledCheckbox:SetChecked(RRT_Settings.Enabled)
    enabledCheckbox:SetScript("OnClick", function(self)
        RRT_Settings.Enabled = self:GetChecked()
    end)
    
    -- Day selection header
    local dayHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dayHeader:SetPoint("TOPLEFT", enabledCheckbox, "BOTTOMLEFT", 0, -20)
    dayHeader:SetText("Reset on these days:")
    
    -- Day checkboxes
    local dayCheckboxes = {}
    for i = 1, 7 do
        local cb = CreateFrame("CheckButton", "RRTDayCheckbox"..i, panel, "UICheckButtonTemplate")
        if i == 1 then
            cb:SetPoint("TOPLEFT", dayHeader, "BOTTOMLEFT", 0, -10)
        else
            cb:SetPoint("TOPLEFT", dayCheckboxes[i-1], "BOTTOMLEFT", 0, -5)
        end
        
        cb.text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        cb.text:SetText(DayNames[i])
        cb:SetChecked(RRT_Settings.AutoResetDays[i])
        cb.dayIndex = i
        cb:SetScript("OnClick", function(self)
            RRT_Settings.AutoResetDays[self.dayIndex] = self:GetChecked()
        end)
        
        dayCheckboxes[i] = cb
    end
    
    -- Reset on leave group checkbox
    local leaveGroupCheckbox = CreateFrame("CheckButton", "RRTLeaveGroupCheckbox", panel, "UICheckButtonTemplate")
    leaveGroupCheckbox:SetPoint("TOPLEFT", dayCheckboxes[7], "BOTTOMLEFT", 0, -20)
    leaveGroupCheckbox.text = leaveGroupCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    leaveGroupCheckbox.text:SetPoint("LEFT", leaveGroupCheckbox, "RIGHT", 5, 0)
    leaveGroupCheckbox.text:SetText("Auto-reset lockouts when leaving a raid group")
    leaveGroupCheckbox:SetChecked(RRT_Settings.ResetOnLeaveGroup)
    leaveGroupCheckbox:SetScript("OnClick", function(self)
        RRT_Settings.ResetOnLeaveGroup = self:GetChecked()
    end)
    
    -- Warning text for leave group option
    local warningText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    warningText:SetPoint("TOPLEFT", leaveGroupCheckbox.text, "BOTTOMLEFT", 0, -5)
    warningText:SetPoint("RIGHT", -16, 0)
    warningText:SetJustifyH("LEFT")
    warningText:SetTextColor(1, 0.5, 0)
    warningText:SetText("Warning: This will reset ALL raid lockouts when you leave any raid group.")
    
    -- Show message checkbox
    local showMessageCheckbox = CreateFrame("CheckButton", "RRTShowMessageCheckbox", panel, "UICheckButtonTemplate")
    showMessageCheckbox:SetPoint("TOPLEFT", warningText, "BOTTOMLEFT", 0, -15)
    showMessageCheckbox.text = showMessageCheckbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    showMessageCheckbox.text:SetPoint("LEFT", showMessageCheckbox, "RIGHT", 5, 0)
    showMessageCheckbox.text:SetText("Show reset confirmation message")
    showMessageCheckbox:SetChecked(RRT_Settings.ShowResetMessage)
    showMessageCheckbox:SetScript("OnClick", function(self)
        RRT_Settings.ShowResetMessage = self:GetChecked()
    end)
    
    -- Manual reset button
    local resetButton = CreateFrame("Button", "RRTManualResetButton", panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -20)
    resetButton:SetSize(150, 25)
    resetButton:SetText("Reset Now")
    resetButton:SetScript("OnClick", function()
        RRT.ManualReset()
    end)
    
    -- Info text
    local infoText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    infoText:SetPoint("BOTTOMLEFT", 16, 25)
    infoText:SetPoint("RIGHT", -16, 0)
    infoText:SetJustifyH("LEFT")
    infoText:SetTextColor(0.7, 0.7, 0.7)
    infoText:SetText("Note: Resets are tracked per-character. Each character will reset independently on their first login of the\nselected day(s). Commands: /rrt, /raidreset")
    
    InterfaceOptions_AddCategory(panel)
    return panel
end

-------------------------------------------------------------------
-- Event Handling
-------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")

local hasCheckedOnLogin = false

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "RRT" then
        CreateSettingsPanel()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r loaded. Type |cFFFFFF00/rrt|r to open settings.", 1, 1, 0)
        
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if not hasCheckedOnLogin then
            hasCheckedOnLogin = true
            RRT.CheckAndResetRaids()
        end
        
    elseif event == "PARTY_MEMBERS_CHANGED" then
        -- Check if player left a raid group
        if RRT_Settings.ResetOnLeaveGroup then
            local numRaidMembers = GetNumRaidMembers()
            if numRaidMembers == 0 and self.wasInRaid then
                PerformRaidReset()
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Left raid group - lockouts reset.", 1, 1, 0)
            end
            self.wasInRaid = numRaidMembers > 0
        end
    end
end)

-------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------

SLASH_RRT1 = "/rrt"
SLASH_RRT2 = "/raidreset"

SlashCmdList["RRT"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "reset" or msg == "r" then
        RRT.ManualReset()
    elseif msg == "status" or msg == "s" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Status:", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("  Enabled: " .. (RRT_Settings.Enabled and "Yes" or "No"))
        DEFAULT_CHAT_FRAME:AddMessage("  Last Reset: Day " .. RRT_CharacterData.LastResetCheck .. " of year")
        DEFAULT_CHAT_FRAME:AddMessage("  Current Day: " .. DayNames[GetCurrentDayOfWeek()])
    elseif msg == "help" or msg == "h" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[RRT]|r Commands:", 1, 1, 0)
        DEFAULT_CHAT_FRAME:AddMessage("  /rrt - Open settings")
        DEFAULT_CHAT_FRAME:AddMessage("  /rrt reset - Manually reset lockouts")
        DEFAULT_CHAT_FRAME:AddMessage("  /rrt status - Show current status")
    else
        -- Open settings
        InterfaceOptionsFrame_OpenToCategory("RRT")
        InterfaceOptionsFrame_OpenToCategory("RRT") -- Call twice due to Blizzard bug
    end
end