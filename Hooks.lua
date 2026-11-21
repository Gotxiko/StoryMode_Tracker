local addonName, T = ...

-- =============================================================================
-- Story Mode - Tracker: hooks into Story Mode
-- Everything here works from outside Story Mode's files, through functions it
-- keeps in its namespace (_G.StoryMode), so a new Story Mode release needs no
-- changes to it:
--
--   Begin/Continue Story and /sm track follow the story in the tracker;
--   switching Guided/Explorer redraws the tracker;
--   /sm tracker hides or shows it;
--   shift-click a chapter on the Progress track, or a story card, to track
--   or untrack it, with the crosshair on what's tracked.
-- =============================================================================

local SM = T.Base
if not (SM and SM.Client and SM.Client.isForever) then return end

local L = T.L

-- ── Following the story the player continues ─────────────────────────────
-- Begin/Continue Story, a quest card's Track and /sm track all come through
-- SM.SetWaypointForQuest.
-- (The tracker's quiet waypoint calls it too, as T.OnStoryContinued.)
local function OnStoryContinued(data, quest)
    if not (data and data.id) then return end
    T.SetFollowedStoryID(data.id)
    -- A chapter the player untracked comes back when they continue it.
    local ch = quest and quest._chapter
    if ch and T.GetChapterTrackState(data, ch) == false then
        T.SetChapterTrackState(data, ch, nil)
    end
    if T.RefreshNextStepTracker then T.RefreshNextStepTracker() end
    if SM.RefreshStoryListState then SM.RefreshStoryListState() end
    T.RefreshTrackNodeBadges()
end

T.OnStoryContinued = OnStoryContinued

local SetWaypointForQuest = SM.SetWaypointForQuest
if SetWaypointForQuest then
    SM.SetWaypointForQuest = function(data, quest, ...)
        local result = SetWaypointForQuest(data, quest, ...)
        if quest then OnStoryContinued(data, quest) end
        return result
    end
end

-- ── Guided / Explorer ────────────────────────────────────────────────────
if SM.SetQuestCardMode then
    hooksecurefunc(SM, "SetQuestCardMode", function()
        if T.RefreshNextStepTracker then T.RefreshNextStepTracker() end
        T.RefreshTrackNodeBadges()
    end)
end

-- ── /sm tracker ──────────────────────────────────────────────────────────
local function WrapSlashCommand()
    local handler = SlashCmdList and SlashCmdList["STORYMODE"]
    if not handler or handler == T.SlashHandler then return end
    T.SlashHandler = function(msg, ...)
        if type(msg) == "string" and msg:lower():match("^%s*tracker") then
            if T.ToggleNextStepTracker then T.ToggleNextStepTracker() end
            return
        end
        return handler(msg, ...)
    end
    SlashCmdList["STORYMODE"] = T.SlashHandler
end
WrapSlashCommand()
if SM.InitializeSlashCommands then hooksecurefunc(SM, "InitializeSlashCommands", WrapSlashCommand) end

-- ── Chapter nodes on the Progress track ──────────────────────────────────
local function Tooltip() return SM.Tooltip or GameTooltip end

local function RefreshNode(node)
    local data, ch = node.smtData, node.smtChapter
    if not (node:IsShown() and data and ch) then return end
    node.smtTrackHint = T.GetChapterTrackHint and T.GetChapterTrackHint(data, ch) or nil
    if node.smtBadge then
        node.smtBadge:SetShown(T.IsChapterInTracker and T.IsChapterInTracker(data, ch) or false)
    end
end

-- After the followed story or a chapter's tracking changes.
function T.RefreshTrackNodeBadges()
    local nodes = SM.DetailUI and SM.DetailUI.dTrackNodes
    if not nodes then return end
    for _, node in ipairs(nodes) do RefreshNode(node) end
end

-- Redraws the tooltip a frame is showing, after its tracking changed.
local function ReshowTooltip(frame)
    local onEnter = frame:GetScript("OnEnter")
    if onEnter and frame:IsMouseOver() then onEnter(frame) end
end

local CreateTrackNode = SM.CreateTrackNode
if CreateTrackNode then
    SM.CreateTrackNode = function(parent, ...)
        local node = CreateTrackNode(parent, ...)
        -- The crosshair (top-left) while the chapter is in the tracker.
        node.smtBadge = T.CreateTrackedBadge(node, 24)
        node.smtBadge:SetPoint("TOPLEFT", node.portrait or node, "TOPLEFT", -6, 6)
        -- What shift-click does, at the end of the node's tooltip.
        node:HookScript("OnEnter", function(self)
            local tip = Tooltip()
            if self.smtTrackHint and tip:IsShown() and tip:GetOwner() == self then
                tip:AddLine(" ")
                tip:AddLine(self.smtTrackHint, 1, 0.82, 0, true)
                tip:Show()
            end
        end)
        return node
    end
end

-- Story Mode sets each node's click every time it lays out the track, so
-- shift-click is put in front of it each time too.
local function WrapNodeClick(node)
    local click = node:GetScript("OnClick")
    if not click or click == node.smtClick then return end
    node.smtClick = function(self, button, ...)
        if button == "LeftButton" and IsShiftKeyDown() and self.smtData and self.smtChapter and T.ToggleTrackedChapter then
            T.ToggleTrackedChapter(self.smtData, self.smtChapter)
            T.RefreshTrackNodeBadges()
            ReshowTooltip(self)
            return
        end
        return click(self, button, ...)
    end
    node:SetScript("OnClick", node.smtClick)
end

if SM.LayoutProgressTab then
    hooksecurefunc(SM, "LayoutProgressTab", function(data)
        local nodes = SM.DetailUI and SM.DetailUI.dTrackNodes
        if not (data and nodes and SM.GetAllChapters) then return end
        local chapters = SM.GetAllChapters(data)
        for i, node in ipairs(nodes) do
            local ch = chapters[i]
            if ch and node:IsShown() then
                node.smtData, node.smtChapter = data, ch
                WrapNodeClick(node)
                RefreshNode(node)
            else
                node.smtData, node.smtChapter = nil, nil
                if node.smtBadge then node.smtBadge:Hide() end
            end
        end
    end)
end

-- ── Story cards ──────────────────────────────────────────────────────────
local function DecorateRow(row)
    local card, data = row and row.btn, row and row.data
    if not (card and data) then return end
    card.smtData = data

    -- The finished flag with the crosshair, where the finished flag hangs,
    -- while the tracker follows the story (and it isn't finished).
    if not card.smtRibbon and row.checkmark and T.CreateTrackedRibbon then
        local ribbon = T.CreateTrackedRibbon(card)
        ribbon:SetScale(row.checkmark:GetScale())
        ribbon:SetPoint("CENTER", row.checkmark, "CENTER", 0, 0)
        card.smtRibbon = ribbon
    end
    if card.smtRibbon then
        local finished = row.checkmark and row.checkmark:IsShown()
        card.smtRibbon:SetShown(not finished and T.IsStoryTracked and T.IsStoryTracked(data) or false)
    end

    -- Shift-left-click links the story while typing in chat (Story Mode's
    -- own); otherwise it follows or stops following the story, even one
    -- still locked (a level to reach, say): the tracker lists its chapters
    -- with what they wait on right under them.
    local click = card:GetScript("OnClick")
    if click and click ~= card.smtClick then
        card.smtClick = function(self, button, ...)
            if button == "LeftButton" and IsShiftKeyDown() then
                local typing = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
                if not typing and T.ToggleTrackedStory then
                    T.ToggleTrackedStory(self.smtData)
                    T.RefreshTrackNodeBadges()
                    ReshowTooltip(self)
                    return
                end
            end
            return click(self, button, ...)
        end
        card:SetScript("OnClick", card.smtClick)
    end

    -- What shift-click does: under the lock on a locked card's tooltip
    -- (Story Mode's own), else in a tooltip of its own.
    if not card.smtEnterHooked then
        card.smtEnterHooked = true
        card:HookScript("OnEnter", function(self)
            if not self.smtData then return end
            local tip = Tooltip()
            local tracked = T.IsStoryTracked and T.IsStoryTracked(self.smtData)
            local hint = T.FormatHotkeys(tracked and L["Story Card Untrack"] or L["Story Card Track"])
            if self.lockReason then
                if not (tip:IsShown() and tip:GetOwner() == self) then return end
                tip:AddLine(" ")
                tip:AddLine(hint, 1, 0.82, 0, true)
                tip:Show()
                return
            end
            tip:SetOwner(self, "ANCHOR_RIGHT")
            tip:ClearLines()
            tip:AddLine(self.smtData.title, 1, 1, 1)
            tip:AddLine(hint, 1, 0.82, 0)
            tip:Show()
        end)
        card:HookScript("OnLeave", function() Tooltip():Hide() end)
    end
end

function T.RefreshStoryCards()
    if not (SM.GetAllQuestlines and SM.GetStoryRowForData) then return end
    for _, data in ipairs(SM.GetAllQuestlines() or {}) do
        DecorateRow(SM.GetStoryRowForData(data))
    end
end

for _, name in ipairs({ "BuildStoryWindow", "RebuildStoryWindow", "RefreshStoryListState" }) do
    if SM[name] then hooksecurefunc(SM, name, function() T.RefreshStoryCards() end) end
end
