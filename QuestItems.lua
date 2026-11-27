local addonName, T = ...

-- =============================================================================
-- Story Mode - Tracker: quest item buttons
-- A quest in the log that has an item to use (GetQuestLogSpecialItemInfo)
-- gets its button beside the quest on the next-step tracker, left of the
-- block, level with the quest's title, as the quest tracker shows it.
--
-- The buttons are secure (using an item is a protected action), so they sit
-- on UIParent by screen position, as FlareUI's do: a protected frame may
-- only be anchored to UIParent. They're placed, shown and hidden only out of
-- combat; in combat they stay where they are and keep working, and the
-- layout catches up when the fight ends.
--
-- While Journey Mode hides FlareUI's tracker, FlareUI's own item buttons
-- would be left behind where its tracker was; they're hidden too.
-- =============================================================================

local SM = T.Base
if not (SM and SM.Client and SM.Client.isForever) then return end

local SIZE = 26     -- the button
local GAP = 4       -- between it and the block's left edge
local RAISE = 3     -- its top, above the quest title's

local buttons = {}
local targets = {}  -- { frame = the quest's row, questID = }, in tracker order
local block, clip   -- the tracker's block, and the scroll frame that clips its list
local dirty = false

local function NewButton(i)
    local b = CreateFrame("Button", "StoryModeTrackerItem" .. i, UIParent, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- The quest tracker's item frame where the client has it, else a dark edge.
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-QuestTrackerButton-QuestItem-Frame") then
        local frame = b:CreateTexture(nil, "OVERLAY")
        frame:SetAtlas("UI-QuestTrackerButton-QuestItem-Frame")
        frame:SetPoint("CENTER")
        frame:SetSize(SIZE * 1.5, SIZE * 1.5)
    else
        local edge = b:CreateTexture(nil, "BACKGROUND", nil, -1)
        edge:SetPoint("TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", 1, -1)
        edge:SetColorTexture(0, 0, 0, 0.8)
    end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    b:SetScript("OnEnter", function(self)
        if not self.logIndex then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetQuestLogSpecialItem(self.logIndex)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    buttons[i] = b
    return b
end

-- A frame's edge in UIParent's units.
local function ToUI(frame, value)
    return value * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function UpdateCooldowns()
    for _, b in ipairs(buttons) do
        if b:IsShown() and b.logIndex and GetQuestLogSpecialItemCooldown then
            local start, duration, enable = GetQuestLogSpecialItemCooldown(b.logIndex)
            if start and CooldownFrame_Set then CooldownFrame_Set(b.cooldown, start, duration, enable) end
        end
    end
end

-- FlareUI's item buttons, while its tracker is hidden (Journey Mode).
local function HideFlareItems()
    local holder = _G.FlareUI_ObjectiveTracker
    if not holder or holder:IsVisible() then return end
    local i = 1
    while _G["FlareUI_TrackerItem" .. i] do
        _G["FlareUI_TrackerItem" .. i]:Hide()
        i = i + 1
    end
end

local function Layout()
    if InCombatLockdown() then
        dirty = true
        return
    end
    dirty = false
    HideFlareItems()
    local used = 0
    local showing = block and block:IsVisible() and GetQuestLogSpecialItemInfo
    local left = showing and block:GetLeft()
    local viewTop, viewBottom = clip and clip:GetTop(), clip and clip:GetBottom()
    if left and viewTop and viewBottom then
        for _, target in ipairs(targets) do
            local frame = target.frame
            local logIndex = target.questID and SM.GetLogIndexForQuestID and SM.GetLogIndexForQuestID(target.questID)
            local top = frame:IsVisible() and frame:GetTop()
            if logIndex and top then
                local link, texture, charges, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
                local itemID = link and link:match("item:(%d+)")
                local complete = C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(target.questID)
                -- Only while its quest's row is in view (the list scrolls).
                local inView = top <= viewTop + 1 and top - SIZE >= viewBottom - 1
                if itemID and inView and (showWhenComplete or not complete) then
                    used = used + 1
                    local b = buttons[used] or NewButton(used)
                    if b.link ~= link then
                        b.link = link
                        b:SetAttribute("item", "item:" .. itemID)
                        b.icon:SetTexture(texture)
                    end
                    b.logIndex = logIndex
                    b.count:SetText((charges and charges > 1) and tostring(charges) or "")
                    b:ClearAllPoints()
                    b:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", ToUI(block, left) - GAP, ToUI(frame, top) + RAISE)
                    b:Show()
                end
            end
        end
    end
    for i = used + 1, #buttons do buttons[i]:Hide() end
    UpdateCooldowns()
end

-- The next-step tracker hands over its block, its list's clip and the quests
-- it shows after each layout; the buttons follow a frame later, once the
-- block has settled where the quest tracker stack puts it.
function T.SetQuestItemTargets(blockFrame, clipFrame, list)
    block, clip, targets = blockFrame, clipFrame, list or {}
    C_Timer.After(0, Layout)
end

-- After the list scrolls, or the block moves.
function T.RelayoutQuestItems()
    C_Timer.After(0, Layout)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "BAG_UPDATE_COOLDOWN", "QUEST_LOG_UPDATE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if dirty then Layout() end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        UpdateCooldowns()
    else
        T.RelayoutQuestItems()
    end
end)
