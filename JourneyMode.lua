local addonName, T = ...

-- =============================================================================
-- Story Mode - Tracker: Journey Mode
-- A checkbox in the Story Mode window's header. While it's on and the
-- next-step tracker shows a story, the standard quest tracker is hidden, so
-- only the story's steps are on screen. Off, or with no story shown, the
-- quest tracker comes back.
--
-- The quest tracker is Blizzard's ObjectiveTrackerFrame, or FlareUI's while
-- it stands in for Blizzard's. Blizzard's holds secure quest item buttons, so
-- it's only hidden or shown out of combat; a change asked for in combat waits
-- for combat to end.
-- =============================================================================

local SM = T.Base
if not (SM and SM.Client and SM.Client.isForever) then return end

local L = T.L

-- ── The setting ──────────────────────────────────────────────────────────
-- StoryModeTrackerDB.journeyMode = true | nil (account-wide).
function T.IsJourneyMode()
    local db = T.DB()
    return db and db.journeyMode and true or false
end

-- ── Hiding the quest tracker ─────────────────────────────────────────────
local storyShown = false   -- the next-step tracker shows a story right now
local hiddenByUs = {}      -- [frame] = true: frames this hid, to show again
local hooked = {}
local pending = false      -- a change waits for combat to end

local function QuestTrackers()
    local list = {}
    if _G.ObjectiveTrackerFrame then list[#list + 1] = _G.ObjectiveTrackerFrame end
    if _G.FlareUI_ObjectiveTracker then list[#list + 1] = _G.FlareUI_ObjectiveTracker end
    return list
end

local function Wanted()
    return T.IsJourneyMode() and storyShown
end

local Apply

-- The game (or FlareUI) shows its tracker again whenever it updates; while
-- Journey mode wants it gone, it's hidden again right after.
local function HookShow(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    frame:HookScript("OnShow", function()
        if Wanted() then C_Timer.After(0, Apply) end
    end)
end

function Apply()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local hide = Wanted()
    for _, frame in ipairs(QuestTrackers()) do
        HookShow(frame)
        if hide then
            if frame:IsShown() then
                frame:Hide()
                hiddenByUs[frame] = true
            end
        elseif hiddenByUs[frame] then
            hiddenByUs[frame] = nil
            frame:Show()
        end
    end
end

-- The next-step tracker says whether it shows a story after each refresh.
function T.SetStoryTrackerShown(shown)
    shown = shown and true or false
    if shown == storyShown then return end
    storyShown = shown
    Apply()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if pending then Apply() end
end)

-- ── The checkbox ─────────────────────────────────────────────────────────
-- In the window's header, right of the points bar and under the close
-- button; it says what it does in its tooltip.
local CHECK = { size = 24, right = -14, top = -32 }

local function SetJourneyMode(on)
    local db = T.DB()
    if not db then return end
    db.journeyMode = on and true or nil
    PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    Apply()
end

local function CreateCheckbox()
    local frame = _G.StoryModeFrame
    if not frame or T.JourneyModeCheck then return end
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(CHECK.size, CHECK.size)
    check:SetPoint("TOPRIGHT", frame, "TOPRIGHT", CHECK.right, CHECK.top)
    check:SetFrameLevel(frame:GetFrameLevel() + 20)
    local label = check.Text or check.text
    if not label then
        label = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    label:SetFontObject("GameFontNormalSmall")
    label:ClearAllPoints()
    label:SetPoint("RIGHT", check, "LEFT", -1, 1)
    label:SetText(L["Journey Mode"])
    -- The label is part of the button: clicking it toggles too.
    check:SetHitRectInsets(-(label:GetStringWidth() + 4), 0, 0, 0)
    check:SetScript("OnShow", function(self) self:SetChecked(T.IsJourneyMode()) end)
    check:SetScript("OnClick", function(self) SetJourneyMode(self:GetChecked()) end)
    check:SetScript("OnEnter", function(self)
        local tip = SM.Tooltip or GameTooltip
        tip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        tip:ClearLines()
        tip:AddLine(L["Journey Mode"], 1, 1, 1)
        tip:AddLine(L["Journey Mode Text"], 1, 0.82, 0, true)
        tip:Show()
    end)
    check:SetScript("OnLeave", function() (SM.Tooltip or GameTooltip):Hide() end)
    check:SetChecked(T.IsJourneyMode())
    T.JourneyModeCheck = check
end

CreateCheckbox()
for _, name in ipairs({ "BuildStoryWindow", "RebuildStoryWindow" }) do
    if SM[name] then hooksecurefunc(SM, name, CreateCheckbox) end
end
