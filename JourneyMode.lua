local addonName, T = ...

-- =============================================================================
-- Story Mode - Tracker: Journey Mode
-- A checkbox in the Story Mode window's header (WindowOptions.lua). While it's on and the
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
local restoreAt            -- when the story went away: the tracker comes back a moment later

-- How long the story may be gone before the quest tracker comes back. The
-- next-step tracker can drop its story for a refresh or two (a quest just
-- accepted or turned in), and the quest tracker shouldn't flash in between.
local RESTORE_DELAY = 0.5

local function QuestTrackers()
    local list = {}
    if _G.ObjectiveTrackerFrame then list[#list + 1] = _G.ObjectiveTrackerFrame end
    if _G.FlareUI_ObjectiveTracker then list[#list + 1] = _G.FlareUI_ObjectiveTracker end
    return list
end

local function Wanted()
    return T.IsJourneyMode() and storyShown
end

local function CanChange(frame)
    return not (InCombatLockdown() and frame.IsProtected and frame:IsProtected())
end

local function HideTracker(frame)
    if not frame:IsShown() then return end
    if not CanChange(frame) then
        pending = true
        return
    end
    frame:Hide()
    hiddenByUs[frame] = true
    -- FlareUI's item buttons sit apart from its tracker; they go with it.
    if T.RelayoutQuestItems then T.RelayoutQuestItems() end
end

-- Back to its owner: Blizzard's tracker through its own Update, which shows
-- it only when it has something to show; FlareUI's just shown (its next
-- update hides it again when there's nothing to track).
local function RestoreTracker(frame)
    if not hiddenByUs[frame] then return end
    if not CanChange(frame) then
        pending = true
        return
    end
    hiddenByUs[frame] = nil
    if frame == _G.ObjectiveTrackerFrame and frame.Update then
        frame:Update()
    else
        frame:Show()
    end
end

-- The game (or FlareUI) shows its tracker again whenever it updates, as when
-- a quest is accepted; while Journey Mode wants it gone, it's hidden again
-- at once.
local function HookShow(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    frame:HookScript("OnShow", function(self)
        if Wanted() then HideTracker(self) end
    end)
end

local function Apply()
    pending = false
    local hide = Wanted()
    for _, frame in ipairs(QuestTrackers()) do
        HookShow(frame)
        if hide then HideTracker(frame) else RestoreTracker(frame) end
    end
end

-- The next-step tracker says whether it shows a story after each refresh.
function T.SetStoryTrackerShown(shown)
    shown = shown and true or false
    if shown then
        restoreAt = nil
        storyShown = true
        Apply()
    elseif storyShown and not restoreAt then
        local token = GetTime()
        restoreAt = token
        C_Timer.After(RESTORE_DELAY, function()
            if restoreAt ~= token then return end
            restoreAt = nil
            storyShown = false
            Apply()
        end)
    end
end

-- Besides the tracker's own refreshes: after combat (a change that had to
-- wait), and whenever the quest log changes, since another addon's tracker
-- may only appear then (FlareUI builds its own after login).
local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED", "QUEST_WATCH_LIST_CHANGED", "QUEST_LOG_UPDATE" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then Apply() end
    elseif Wanted() then
        Apply()
    end
end)
T.ApplyJourneyMode = Apply

-- Turned on or off from its checkbox in the Story Mode window
-- (WindowOptions.lua).
function T.SetJourneyMode(on)
    local db = T.DB()
    if not db then return end
    db.journeyMode = on and true or nil
    Apply()
end
