-- [[ GreyGone v1.0 ]] --
-- Author: Farhood

local AddonName = "GreyGone"
local bagState = {} 
local deleteQueue = {}

-- Temporary table for settings
local tempDB = {} 
local initialKey = nil 

-- =============================================================
-- 1. DRIVER FRAME (Always running)
-- =============================================================
local driver = CreateFrame("Frame", "GreyGoneDriver", UIParent)
driver:Show() 

local triggerBtn = CreateFrame("Button", "GreyGoneTrigger", driver, "SecureActionButtonTemplate")
triggerBtn:RegisterForClicks("AnyUp")

-- =============================================================
-- 2. CORE LOGIC
-- =============================================================

local function SniperDelete(targetLink, amount)
    local deleted = 0
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b) do
            local l = GetContainerItemLink(b, s)
            if l == targetLink and deleted < amount then
                local _, count = GetContainerItemInfo(b, s)
                table.insert(deleteQueue, {b=b, s=s, l=l, c=count})
                deleted = deleted + (count or 1)
            end
        end
    end
end

local function TotalBagSweep()
    if InCombatLockdown() then 
        print("|cffff0000[GreyGone]|r Cannot delete items in combat!")
        return 
    end
    
    local found = false
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b) do
            local l = GetContainerItemLink(b, s)
            if l then
                local _, _, q, _, _, _, _, _, _, _, p = GetItemInfo(l)
                if q == 0 and (p or 0) > 0 then
                    local _, count = GetContainerItemInfo(b, s)
                    table.insert(deleteQueue, {b=b, s=s, l=l, c=count})
                    found = true
                end
            end
        end
    end
    if not found and GreyGoneDB.verbose then
        print("|cff9d9d9d[GreyGone]|r No grey items found.")
    end
end

triggerBtn:SetScript("OnClick", TotalBagSweep)

local timerFrame = CreateFrame("Frame")
local lastUp = 0
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUp = lastUp + elapsed
    if lastUp < 0.2 then return end
    lastUp = 0
    if #deleteQueue > 0 and not InCombatLockdown() and not CursorHasItem() then
        local item = table.remove(deleteQueue, 1)
        if GetContainerItemLink(item.b, item.s) == item.l then
            ClearCursor()
            PickupContainerItem(item.b, item.s)
            if CursorHasItem() then 
                DeleteCursorItem() 
                if GreyGoneDB.verbose then 
                    print("|cff9d9d9d[GreyGone] Removed:|r "..item.l.." x"..(item.c or 1)) 
                end
            end
        end
    end
end)

-- =============================================================
-- 3. INTERFACE OPTIONS PANEL
-- =============================================================

local panel = CreateFrame("Frame", "GreyGoneOptionsPanel", UIParent)
panel.name = AddonName

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(AddonName .. " Settings")

local subText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subText:SetText("Configure settings or perform a manual sweep.")

-- Keybinding Helper
local bindLabel 
local function ApplyKeyToDriver(key)
    ClearOverrideBindings(driver)
    if key then
        SetOverrideBindingClick(driver, true, key, "GreyGoneTrigger")
        if bindLabel then bindLabel:SetText("Current Bind: |cff00ff00" .. key .. "|r") end
    else
        if bindLabel then bindLabel:SetText("Current Bind: |cff808080None|r") end
    end
end

-- Checkbox Helper
local function CreateCheck(label, dbKey, relativeTo, x, y)
    local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", x, y)
    
    cb.Text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 0, 1)
    cb.Text:SetText(label)

    cb:SetScript("OnClick", function(self) 
        tempDB[dbKey] = self:GetChecked() 
    end)
    
    cb.UpdateVisual = function(self) 
        self:SetChecked(tempDB[dbKey]) 
    end
    return cb
end

local cb1 = CreateCheck("Auto Remove", "autoBag", subText, 0, -20)
local cb2 = CreateCheck("Remove On Loot (New loot & related stacks only)", "autoLoot", cb1, 0, -10)
local cb3 = CreateCheck("Print Deleted Names", "verbose", cb2, 0, -10)

-- =============================================================
-- 4. KEYBINDING SYSTEM
-- =============================================================

local bindHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
bindHeader:SetPoint("TOPLEFT", cb3, "BOTTOMLEFT", 0, -30)
bindHeader:SetText("Keybinding")

bindLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
bindLabel:SetPoint("TOPLEFT", bindHeader, "BOTTOMLEFT", 0, -10)
bindLabel:SetText("Current Bind: None")

local btnBind = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
btnBind:SetSize(120, 22)
btnBind:SetPoint("LEFT", bindLabel, "RIGHT", 20, 0)
btnBind:SetText("Set Keybind")

StaticPopupDialogs["GREYGONE_CONFIRM_BIND"] = {
    text = "Key '%s' is already bound to '%s'.\nOverwrite?",
    button1 = "Yes", button2 = "No",
    OnAccept = function(self)
        tempDB.boundKey = self.data.key
        ApplyKeyToDriver(self.data.key) 
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local binderFrame = nil
local function FinishBinding(key)
    if binderFrame then binderFrame:Hide() end
    btnBind:SetText("Set Keybind")
    
    if key == "ESCAPE" then return end 
    if key == "BUTTON1" or key == "ENTER" then 
        print("|cffff0000[GreyGone]|r Cannot bind Left Click or Enter.")
        return 
    end

    local currentAction = GetBindingAction(key)
    if currentAction ~= "" and currentAction ~= "CLICK GreyGoneTrigger:LeftButton" then
        local dialog = StaticPopup_Show("GREYGONE_CONFIRM_BIND", key, currentAction)
        if dialog then dialog.data = {key = key} end
    else
        tempDB.boundKey = key
        ApplyKeyToDriver(key) 
    end
end

btnBind:SetScript("OnClick", function()
    if not binderFrame then
        binderFrame = CreateFrame("Button", "GreyGoneBinder", UIParent)
        binderFrame:SetAllPoints(UIParent)
        binderFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        binderFrame:EnableKeyboard(true)
        binderFrame:EnableMouse(true)
        binderFrame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"}) 
        binderFrame:SetAlpha(0.8)
        
        local instr = binderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        instr:SetPoint("CENTER")
        instr:SetText("Press Key or Mouse Button\n(Left Click or ESC to Cancel)")
        
        binderFrame:SetScript("OnKeyDown", function(self, k) FinishBinding(k) end)
        binderFrame:SetScript("OnMouseDown", function(self, b) 
            local k = (b=="LeftButton" and "BUTTON1") or (b=="RightButton" and "BUTTON2") or (b=="MiddleButton" and "BUTTON3") or b:upper()
            FinishBinding(k) 
        end)
    end
    btnBind:SetText("Waiting...")
    binderFrame:Show()
end)

-- =============================================================
-- 5. RESET BUTTON & MANUAL BUTTON
-- =============================================================

-- Reset Button
local btnReset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
btnReset:SetSize(120, 22)
btnReset:SetPoint("BOTTOMLEFT", 16, 16)
btnReset:SetText("Reset to Defaults")
btnReset:SetScript("OnClick", function()
    tempDB.autoBag = true
    tempDB.autoLoot = false
    tempDB.verbose = true
    tempDB.boundKey = nil
    
    cb1:UpdateVisual()
    cb2:UpdateVisual()
    cb3:UpdateVisual()
    ApplyKeyToDriver(nil)
end)

-- [[ NEW BUTTON LOCATION ]] --
local btnManual = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
btnManual:SetSize(160, 40) -- Size preserved as requested
btnManual:SetPoint("LEFT", btnReset, "RIGHT", 20, 0) -- Placed next to Reset
btnManual:SetText("DELETE GREYS NOW")
btnManual:SetScript("OnClick", function()
    TotalBagSweep()
end)

-- =============================================================
-- 6. PANEL HANDLERS
-- =============================================================

panel.refresh = function()
    tempDB = {}
    tempDB.autoBag = GreyGoneDB.autoBag
    tempDB.autoLoot = GreyGoneDB.autoLoot
    tempDB.verbose = GreyGoneDB.verbose
    tempDB.boundKey = GreyGoneDB.boundKey
    initialKey = GreyGoneDB.boundKey
    
    cb1:UpdateVisual()
    cb2:UpdateVisual()
    cb3:UpdateVisual()
    ApplyKeyToDriver(tempDB.boundKey)
end

panel.okay = function()
    GreyGoneDB.autoBag = tempDB.autoBag
    GreyGoneDB.autoLoot = tempDB.autoLoot
    GreyGoneDB.verbose = tempDB.verbose
    GreyGoneDB.boundKey = tempDB.boundKey
    ApplyKeyToDriver(GreyGoneDB.boundKey)
    
    if GreyGoneDB.autoBag then TotalBagSweep() end
end

panel.cancel = function()
    ApplyKeyToDriver(initialKey)
end

panel.default = function()
    tempDB.autoBag = true
    tempDB.autoLoot = false
    tempDB.verbose = true
    tempDB.boundKey = nil
    cb1:UpdateVisual()
    cb2:UpdateVisual()
    cb3:UpdateVisual()
    ApplyKeyToDriver(nil)
end

InterfaceOptions_AddCategory(panel)

-- =============================================================
-- 7. EVENTS & INITIALIZATION
-- =============================================================

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("LOOT_OPENED")
driver:RegisterEvent("BAG_UPDATE")

driver:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        if not GreyGoneDB then 
            GreyGoneDB = {autoBag=true, autoLoot=false, verbose=true} 
        end
        ApplyKeyToDriver(GreyGoneDB.boundKey)

    elseif event == "LOOT_OPENED" then
        wipe(bagState)
        for b=0,4 do for s=1,GetContainerNumSlots(b) do
            local l = GetContainerItemLink(b,s)
            if l then local _, c = GetContainerItemInfo(b,s); bagState[l] = (bagState[l] or 0) + (c or 1) end
        end end

    elseif event == "BAG_UPDATE" then
        for b=0,4 do for s=1,GetContainerNumSlots(b) do
            local l = GetContainerItemLink(b,s)
            if l then
                local _, _, q, _, _, _, _, _, _, _, p = GetItemInfo(l)
                if q == 0 and (p or 0) > 0 then
                    local _, cur = GetContainerItemInfo(b, s)
                    local old = bagState[l] or 0
                    if (GreyGoneDB.autoBag or GreyGoneDB.autoLoot) and cur > old then
                        SniperDelete(l, cur - old)
                        bagState[l] = cur
                    end
                end
            end
        end end
    end
end)

SLASH_GREYGONE1 = "/greygone"
SlashCmdList["GREYGONE"] = function() 
    InterfaceOptionsFrame_OpenToCategory(panel)
end