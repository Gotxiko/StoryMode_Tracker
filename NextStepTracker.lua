local addonName, SM = ...
local L = SM.L

-- =============================================================================
-- Next-step tracker (WoW Forever), for Story Mode
-- A block at the top of the quest tracker, laid out like Retail's
-- Lorewalking tracker, for the story this character last began or continued
-- (SM.GetFollowedStoryID):
--
--   the Lorewalking plate with the story's title, and a red X to stop
--   following it;
--   then, for each chapter shown, a heading (as FlareUI's zone headings)
--   that folds it, and its next quest, with the tracker's campaign shield
--   and gold title, and under it its lines: its live objectives once it's
--   in the log, or else who gives it and where (and, in Guided mode, what
--   it asks).
--
-- The chapters shown are all the open ones (a quest in the log or ready to
-- take), so a story of stories like The Long Watch follows Darkshire and
-- Raven Hill side by side. Right-click a heading here, or a chapter on the
-- Progress track, to untrack it; right-click a chapter on the track to add
-- one that isn't open yet. Continue Story brings an untracked chapter back.
--
-- In Guided mode a bar shows how far into each chapter you are. Explorer
-- mode shows no count or bar, says what a quest asks only once it's in the
-- log, as the quest cards do, and lets only chapters already reached be
-- tracked.
--
-- It takes the quest tracker's place and pushes it down (Code/UI/
-- TrackerStack.lua, or ParchmentUI's stack when that addon shares it, below
-- its dungeon tracker and Legacy challenges).
--
-- Clicking the plate opens the story. Clicking the quest shows the way, as
-- Continue Story does; right-clicking it opens the story. /sm tracker hides
-- or shows the block.
-- =============================================================================

if not (SM.Client and SM.Client.isForever) then return end

local ORDER = 30            -- in the stack: ParchmentUI's dungeon tracker is 10, Legacy 20
local MIN_W, MAX_W, DEFAULT_W = 210, 320, 248
local PLATE_RATIO = 80 / 253
local PLATE_TEXT_BOTTOM = 0.2   -- the plate's text stands this far up it, as a share of its height
local PLATE_TEXT_RIGHT = 22     -- the plate's text, in from its right edge as from its left
-- The chapter heading, as FlareUI draws its tracker's zone headings: the
-- tracker's secondary header strip cut in three (both ends at their own
-- width, a thin slice of the plain middle stretched between them), centred
-- on the text, which sits in Blizzard's 7 px with 5 px of room above and
-- below, and the fold arrow right after the text.
local STRIP_CAP = 0.3       -- each end of the strip, as a share of its width
local STRIP_FRAME = 260     -- Blizzard's header width: the strip reaches past it on both sides
local HEADING_TEXT_X = 7
local HEADING_PAD = 5
local HEADING_COLOR = { 1, 0.82, 0 }
local FOLD_RIGHT = 6        -- the fold button, in from the heading's right edge
local BOTTOM_PAD = 10       -- room under the block, so the quest tracker starts a little lower
local TITLE_X = 34          -- the quest title, after its shield
local LINE_X = 36           -- a line under it
local SHIELD_SIZE = 28
local BANG_RAISE = 2        -- the ! over the shield, up from its centre
local LOCK_SIZE = 20        -- the padlock in place of the shield, while the chapter is locked
local IN_PROGRESS_SIZE = 18 -- the in-progress icon over the shield
local TAG_GAP = 2           -- between the quest title and its Dungeon / Raid tag under it
local CHECK_SIZE = 14
local GAP = 3               -- between two lines under a quest
local TITLE_GAP = 4         -- under the quest title
local STEP_GAP = 6          -- under the step's text, before its objectives
local QUEST_TOP = 8         -- between a chapter heading and its quest
local ENTRY_GAP = 12        -- between one chapter's quest and the next heading
local SUB_GAP = 8           -- between two quests of the same chapter
local INSTANCE_ICON_SIZE = 14  -- the dungeon or raid icon in the tag under a quest's title
local MAX_LIST_SHARE = 0.45   -- the chapters scroll past this share of the screen's height
local SCROLL_STEP = 40         -- how far one turn of the mouse wheel moves them
-- The chapter bar: Blizzard's widget status bar (Interface/Widgets/
-- WidgetStatusBar), its 18 px background scaled to BAR_H, with the 31 px
-- border around it and the spark at the fill's end.
local BAR_H = 12
local BAR_SCALE = BAR_H / 18
local BAR_OVERHANG = math.floor(6 * BAR_SCALE + 0.5)                     -- border past each end
local BAR_OVERHANG_Y = math.floor((31 - 18) / 2 * BAR_SCALE + 0.5)       -- and above and below
local MAX_LINES = 6

-- Atlases (Retail's names; each one is checked, with a plain fallback).
local ATLAS = {
    plate = "lorewalking-scenario-frame",                       -- Interface/Scenarios/ScenarioLorewalking
    section = "UI-QuestTracker-Secondary-Objective-Header",     -- Interface/QuestFrame/QuestTracker2x
    collapse = "UI-QuestTrackerButton-Secondary-Collapse",
    expand = "UI-QuestTrackerButton-Secondary-Expand",
    check = "UI-QuestTracker-Tracker-Check",
    -- The campaign quest button (Interface/QuestFrame/QuestCampaignMapIcons),
    -- built as Blizzard builds it: the shield, yellow while it's the one in
    -- focus, with the ! or ? drawn over it.
    shield = "UI-QuestPoiCampaign-QuestNumber",
    shieldFocus = "UI-QuestPoiCampaign-QuestNumber-SuperTracked",
    glow = "UI-QuestPoiCampaign-InnerGlow",
    bang = "UI-QuestPoiCampaign-QuestBang",                     -- ! to pick up
    turnIn = "UI-QuestPoiCampaign-QuestBangTurnIn",             -- ? to hand in
    -- Under way, not ready to hand in yet (Interface/QuestFrame/
    -- QuestInProgressIcons2x): yellow on the plain shield, brown on the
    -- yellow one of the quest in focus.
    inProgress = "Quest-In-Progress-Icon-yellow",
    inProgressFocus = "Quest-In-Progress-Icon-Brown",
    -- In place of the shield while a requirement (a level, say) locks the
    -- chapter: the artifact forge's padlock (Interface/Artifacts/ArtifactForge).
    lock = "Forge-Lock",
}

-- A dungeon or raid step says so right under its title: the quest log's
-- icon for it (Interface/QuestFrame/QuestLogQuestTypeIcons2x) and the
-- client's own word for it.
local INSTANCE_TAG = {
    dungeon = { icon = "questlog-questtypeicon-dungeon", label = "LFG_TYPE_DUNGEON", fallback = "Dungeon" },
    raid = { icon = "questlog-questtypeicon-raid", label = "LFG_TYPE_RAID", fallback = "Raid" },
}
local TAG_COLOR = { r = 0.7, g = 0.7, b = 0.7 }

-- The quest tracker's colours, or the same values where the game has none.
local TRACKER_COLOR = _G.OBJECTIVE_TRACKER_COLOR or {}
local COLOR = {
    title = TRACKER_COLOR.Header or { r = 0.75, g = 0.61, b = 0 },
    titleHover = TRACKER_COLOR.HeaderHighlight or { r = 1, g = 0.82, b = 0 },
    line = TRACKER_COLOR.Normal or { r = 0.8, g = 0.8, b = 0.8 },
    lineHover = TRACKER_COLOR.NormalHighlight or { r = 1, g = 1, b = 1 },
    done = TRACKER_COLOR.Complete or { r = 0.6, g = 0.6, b = 0.6 },
    locked = { r = 1, g = 0.35, b = 0.3 },
}

local function HasAtlas(name)
    return name and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function FirstAtlas(names)
    for _, name in ipairs(names or {}) do
        if HasAtlas(name) then return name end
    end
    return nil
end

-- Quests the game was asked to load, to learn whether they're dungeon or
-- raid quests; the tracker redraws when one arrives.
local loadingKind = {}
local kindEvents

-- "dungeon", "raid" or nil for a step. Story Mode's own answer (the game's
-- quest tag, remembered per account, or the story data's instance field),
-- as its quest cards and story list show it. A quest the game hasn't loaded
-- yet (one not in the log) is loaded, and the tracker redraws then.
local function InstanceKind(nextQuest)
    if not nextQuest then return nil end
    if SM.GetQuestInstanceType then
        local kind, unknown = SM.GetQuestInstanceType(nextQuest)
        if kind == "dungeon" or kind == "raid" then return kind end
        if unknown and C_QuestLog and C_QuestLog.RequestLoadQuestByID then
            if not kindEvents then
                kindEvents = CreateFrame("Frame")
                pcall(kindEvents.RegisterEvent, kindEvents, "QUEST_DATA_LOAD_RESULT")
                kindEvents:SetScript("OnEvent", function(_, _, questID)
                    if not loadingKind[questID] then return end
                    loadingKind[questID] = nil
                    if SM.RefreshNextStepTracker then SM.RefreshNextStepTracker() end
                end)
            end
            for _, questID in ipairs(unknown) do
                if loadingKind[questID] == nil then
                    loadingKind[questID] = pcall(C_QuestLog.RequestLoadQuestByID, questID) or false
                end
            end
        end
        return nil
    end
    local _, icon = SM.GetInstanceQuestTag and SM.GetInstanceQuestTag(nextQuest)
    return icon and (icon:find("raid") and "raid" or icon:find("dungeon") and "dungeon") or nil
end

-- A step's tag text ("|A:icon|a Dungeon"), or nil when it's no dungeon or raid.
local function InstanceTagText(nextQuest)
    local tag = INSTANCE_TAG[InstanceKind(nextQuest)]
    if not tag then return nil end
    local text = _G[tag.label] or tag.fallback
    if HasAtlas(tag.icon) then
        text = string.format("|A:%s:%d:%d|a %s", tag.icon, INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE, text)
    end
    return text
end

local function SetAtlasOr(texture, atlas, r, g, b, a)
    if HasAtlas(atlas) then
        texture:SetAtlas(atlas)
        return true
    end
    texture:SetColorTexture(r or 0, g or 0, b or 0, a or 0.45)
    return false
end

-- The strip behind the chapter heading, cut in three so its ends keep their
-- shape at any width (FlareUI's Build.PlaceStrip). Returns its height, or
-- nil when this client lacks the art.
local function PlaceStrip(owner, atlas)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if not (info and info.file and (info.width or 0) > 0) then
        if owner.strip then for _, tex in pairs(owner.strip) do tex:Hide() end end
        return nil
    end
    local strip = owner.strip
    if not strip then
        strip = {}
        for _, part in ipairs({ "L", "M", "R" }) do
            strip[part] = owner:CreateTexture(nil, "BACKGROUND", nil, -1)
        end
        owner.strip = strip
    end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local span = r - l
    local cap = math.floor(info.width * STRIP_CAP + 0.5)
    local capSpan = span * cap / info.width
    local mid = l + span / 2
    local reach = math.max(0, (info.width - STRIP_FRAME) / 2)
    for _, tex in pairs(strip) do
        tex:SetTexture(info.file)
        tex:ClearAllPoints()
        tex:SetHeight(info.height)
        tex:Show()
    end
    strip.L:SetTexCoord(l, l + capSpan, t, b)
    strip.L:SetWidth(cap)
    strip.L:SetPoint("LEFT", owner, "LEFT", -reach, 0)
    strip.R:SetTexCoord(r - capSpan, r, t, b)
    strip.R:SetWidth(cap)
    strip.R:SetPoint("RIGHT", owner, "RIGHT", reach, 0)
    strip.M:SetTexCoord(mid - span * 0.005, mid + span * 0.005, t, b)
    strip.M:SetPoint("LEFT", strip.L, "RIGHT")
    strip.M:SetPoint("RIGHT", strip.R, "LEFT")
    return info.height
end

local function FontObject(...)
    for i = 1, select("#", ...) do
        local font = _G[select(i, ...)]
        if font then return font end
    end
    return GameFontNormal
end

-- The story's title on the plate: the large highlight font, 2 points smaller.
local PLATE_FONT = CreateFont("StoryModeTrackerPlateFont")
PLATE_FONT:SetFontObject(FontObject("GameFontHighlightLarge", "GameFontNormalLarge"))
do
    local path, size, flags = PLATE_FONT:GetFont()
    if path and size then PLATE_FONT:SetFont(path, math.max(10, size - 2), flags or "") end
end
local SECTION_FONT = FontObject("GameFontNormalMed2", "GameFontNormalLarge", "GameFontNormal")
local LINE_FONT = FontObject("ObjectiveTrackerLineFont", "ObjectiveFont", "GameFontHighlight")
-- The lines under a quest title (the step's text from its quest card and
-- the objectives): the small highlight font at 11, just under the title.
local BODY_FONT_SIZE = 11
local STEP_FONT = CreateFont("StoryModeTrackerBodyFont")
STEP_FONT:SetFontObject(FontObject("GameFontHighlightSmall", "GameFontHighlight"))
do
    local path, _, flags = STEP_FONT:GetFont()
    if path then STEP_FONT:SetFont(path, BODY_FONT_SIZE, flags or "") end
end

local B             -- the block
local plate
local entries = {}  -- one per chapter shown: { section =, quest =, lines =, bar = }
local stack, slot
local scroll, content, listTop  -- the chapters' scroll frame, its child, the top of the list

-- How far a heading's strip reaches past the heading: sideways past its
-- edges, and up and down at most half the art's height.
local function StripOverflow()
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ATLAS.section)
    if not (info and (info.width or 0) > 0) then return 0, 0 end
    local x = math.ceil(math.max(0, (info.width - STRIP_FRAME) / 2)) + 2
    local y = math.ceil((info.height or 0) / 2)
    return x, y
end

local function IsHiddenByPlayer()
    local db = SM.DB()
    return db and db.nextStepTrackerHidden
end

-- Folded chapter headings, per story and chapter (by English name).
local function FoldKey(data, ch)
    return tostring(data.id) .. "|" .. tostring(SM.GetTrackedChapterKey(ch))
end

local function IsFolded(data, ch)
    local db = SM.DB()
    local folded = db and db.nextStepTrackerFolded
    return folded and folded[FoldKey(data, ch)] or false
end

local function ToggleFolded(data, ch)
    local db = SM.DB()
    if not db then return end
    db.nextStepTrackerFolded = db.nextStepTrackerFolded or {}
    local key = FoldKey(data, ch)
    db.nextStepTrackerFolded[key] = not db.nextStepTrackerFolded[key] or nil
end

local function EditModeActive()
    local em = _G.EditModeManagerFrame
    return em and em.IsEditModeActive and em:IsEditModeActive()
end

local function SetColor(text, color)
    text:SetTextColor(color.r, color.g, color.b)
end

local function NewText(parent, font, wrap)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(font)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(wrap ~= false)
    return text
end

local Refresh

local function OpenStory(data, chapter)
    if not data then return end
    if SM.OpenStoryModeToSelection then
        SM.OpenStoryModeToSelection(data.id, chapter and chapter._chapterIndex or 1, "progress")
    end
end

-- The tracker sits at the top right of the screen, so its tooltips open to
-- the left of what's hovered and grow down from its top edge.
-- The click and shift-click lines, while the player wants them (Show help
-- in tooltips, in the Story Mode window).
local function ShowsHelp()
    return not SM.ShowsTooltipHelp or SM.ShowsTooltipHelp()
end

local function AnchorTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -4, 0)
end

-- Hovering a quest brightens it, as the quest tracker's blocks do.
-- Whether the game is focused on this quest (super-tracked): in the log by
-- its quest ID, or before that by the quest offer's map pin, which is what
-- clicking it on the tracker sets.
local function IsFocused(nextQuest)
    if not (nextQuest and C_SuperTrack) then return false end
    for _, questID in ipairs(SM.GetQuestIDs(nextQuest)) do
        if C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID() == questID then
            return true
        end
        if C_SuperTrack.GetSuperTrackedMapPinInfo and Enum and Enum.SuperTrackingMapPinType then
            local pinType, pinID = C_SuperTrack.GetSuperTrackedMapPinInfo()
            if pinType == Enum.SuperTrackingMapPinType.QuestOffer and pinID == questID then return true end
        end
    end
    return false
end

-- Greys the glyph or not.
local function GreyGlyph(glyph, grey)
    glyph:SetDesaturated(grey and true or false)
    glyph:SetAlpha(grey and 0.75 or 1)
end

local function PaintQuest(entry)
    local quest = entry.quest
    -- The shield behind the glyph: the tracker's focused (yellow) shield for
    -- the quest the game is focused on; a glow over it while hovered.
    -- A locked chapter shows the padlock alone (the glyph), no shield.
    local padlock = entry.locked and HasAtlas(ATLAS.lock)
    local focused = not entry.locked and IsFocused(entry.nextQuest)
    local atlas = (focused and HasAtlas(ATLAS.shieldFocus)) and ATLAS.shieldFocus or ATLAS.shield
    quest.shield:SetShown(not padlock and HasAtlas(atlas))
    if HasAtlas(atlas) then quest.shield:SetAtlas(atlas) end
    quest.shield:SetDesaturated(entry.locked and true or false)
    quest.glow:SetShown(not padlock and entry.hovering and HasAtlas(ATLAS.glow))
    -- The in-progress icon: brown on the yellow shield, yellow on the plain one.
    if entry.glyph == ATLAS.inProgress then
        quest.glyph:SetAtlas((focused and HasAtlas(ATLAS.inProgressFocus)) and ATLAS.inProgressFocus or ATLAS.inProgress)
    end
    if entry.locked then
        SetColor(quest.title, COLOR.locked)
    else
        SetColor(quest.title, entry.hovering and COLOR.titleHover or COLOR.title)
    end
    for _, line in ipairs(entry.lines) do
        if line:IsShown() then
            SetColor(line.text, line.finished and COLOR.done or (entry.hovering and COLOR.lineHover or COLOR.line))
        end
    end
end

local function NewLine(entry)
    local line = CreateFrame("Frame", nil, entry.quest)
    line.text = NewText(line, LINE_FONT)
    line.text:SetPoint("TOPLEFT")
    line.check = line:CreateTexture(nil, "ARTWORK")
    line.check:SetSize(CHECK_SIZE, CHECK_SIZE)
    line.check:SetPoint("TOPRIGHT", line, "TOPLEFT", -1, 1)
    line.check:Hide()
    entry.lines[#entry.lines + 1] = line
    return line
end

local function CreateBlock()
    if B then return end
    B = CreateFrame("Frame", "StoryModeNextStepTracker", UIParent)
    B:SetSize(DEFAULT_W, 80)
    B:SetFrameStrata("LOW")
    B:SetClampedToScreen(true)
    B:Hide()

    -- The Lorewalking plate: the story's title, and the X to stop following.
    plate = CreateFrame("Button", nil, B)
    -- Over the chapters' list, so what scrolls up goes under the plate.
    plate:SetFrameLevel(B:GetFrameLevel() + 10)
    plate:SetPoint("TOPLEFT")
    plate:SetPoint("TOPRIGHT")
    plate.bg = plate:CreateTexture(nil, "BACKGROUND")
    plate.bg:SetAllPoints()
    SetAtlasOr(plate.bg, ATLAS.plate)
    plate.text = NewText(plate, PLATE_FONT)
    plate.text:SetMaxLines(2)
    -- Left-click opens the story, right-click its journal (diario),
    -- shift-left-click stops following it.
    plate:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    plate:SetScript("OnClick", function(_, button)
        local data = B.data
        if not data then return end
        if button == "RightButton" then
            if SM.OpenStoryModeToSelection then
                SM.OpenStoryModeToSelection(data.id, StoryModeDB and StoryModeDB.selectedChapter or 1, "journal")
            end
        elseif IsShiftKeyDown() then
            GameTooltip:Hide()
            if SM.SetFollowedStoryID then SM.SetFollowedStoryID(nil) end
            Refresh()
            if SM.RefreshStoryListState then SM.RefreshStoryListState() end
            if SM.RefreshTrackNodeBadges then SM.RefreshTrackNodeBadges() end
        else
            OpenStory(data, nil)
        end
    end)
    -- The story's title and description, as its card in the Story Mode
    -- window shows them, then what a click does.
    plate:SetScript("OnEnter", function(self)
        local data = B.data
        if not data then return end
        AnchorTooltip(self)
        GameTooltip:AddLine(data.title, 1, 0.82, 0)
        local description = SM.GetStoryIntroText and SM.GetStoryIntroText(data)
        if description and description ~= "" then
            GameTooltip:AddLine(description, 1, 1, 1, true)
        end
        if ShowsHelp() then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(SM.FormatHotkeys(L["Tracker Tooltip Plate"]), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(SM.FormatHotkeys(L["Tracker Tooltip Plate Untrack"]), 0.7, 0.7, 0.7)
            GameTooltip:AddLine(SM.FormatHotkeys(L["Tracker Tooltip Plate Journal"]), 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    plate:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- The chapters scroll under the plate, which stays put: past a share of
    -- the screen's height, the mouse wheel moves them.
    scroll = CreateFrame("ScrollFrame", nil, B)
    scroll:SetClipsChildren(true)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(DEFAULT_W, 1)
    scroll:SetScrollChild(content)
    -- The first heading hangs from this, at the top of the list (placed
    -- with the clip's margins in Refresh).
    listTop = CreateFrame("Frame", nil, content)
    listTop:SetHeight(1)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, (content:GetHeight() or 0) - self:GetHeight())
        local target = self:GetVerticalScroll() - delta * SCROLL_STEP
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, target)))
        -- Quest item buttons follow their quests (QuestItems.lua).
        if SM.RelayoutQuestItems then SM.RelayoutQuestItems() end
    end)

    stack = SM.GetTrackerStack and SM.GetTrackerStack()
    if stack then slot = stack.Register(B, ORDER, function() SM.RefreshNextStepTracker() end) end
end

-- One chapter's widgets: its heading (as FlareUI's zone headings: strip,
-- gold text, fold button at the right) and its next quest (shield, gold
-- title, its lines, and in Guided mode the chapter's bar).
-- Three pieces of a bar (left cap, stretched middle, right cap) on layer,
-- from atlases name-left/center/right at their own width scaled by
-- BAR_SCALE, reaching out past the bar by out and centred on it.
local function BarPieces(bar, layer, sub, prefix, out)
    local left, center, right = prefix .. "left", prefix .. "center", prefix .. "right"
    if not (HasAtlas(left) and HasAtlas(center) and HasAtlas(right)) then return nil end
    local infoL = C_Texture.GetAtlasInfo(left)
    local infoR = C_Texture.GetAtlasInfo(right)
    local h = infoL.height * BAR_SCALE
    local l = bar:CreateTexture(nil, layer, nil, sub)
    l:SetAtlas(left)
    l:SetSize(infoL.width * BAR_SCALE, h)
    l:SetPoint("LEFT", bar, "LEFT", -out, 0)
    local r = bar:CreateTexture(nil, layer, nil, sub)
    r:SetAtlas(right)
    r:SetSize(infoR.width * BAR_SCALE, h)
    r:SetPoint("RIGHT", bar, "RIGHT", out, 0)
    local c = bar:CreateTexture(nil, layer, nil, sub)
    c:SetAtlas(center, false)
    c:SetHeight(h)
    c:SetPoint("LEFT", l, "RIGHT")
    c:SetPoint("RIGHT", r, "LEFT")
    return { l, c, r }
end

-- The chapter bar, built from Blizzard's widget status bar; a plain bar
-- where this client lacks its art.
local function NewWidgetBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(BAR_H)
    bar:SetMinMaxValues(0, 1)
    if HasAtlas("widgetstatusbar-fill-yellow") then
        -- Status bars take an atlas name as their fill, as Blizzard's
        -- widget bars set theirs.
        bar:SetStatusBarTexture("widgetstatusbar-fill-yellow")
    else
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(1, 0.82, 0)
    end
    if not BarPieces(bar, "BACKGROUND", 0, "widgetstatusbar-bg", 0) then
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.5)
    end
    -- The border sits over the fill, in a frame of its own above the bar.
    local over = CreateFrame("Frame", nil, bar)
    over:SetAllPoints()
    over:SetFrameLevel(bar:GetFrameLevel() + 2)
    BarPieces(over, "OVERLAY", 0, "widgetstatusbar-border", BAR_OVERHANG)
    if HasAtlas("widgetstatusbar-spark") then
        local spark = over:CreateTexture(nil, "OVERLAY", nil, 1)
        spark:SetAtlas("widgetstatusbar-spark")
        spark:SetSize(8 * BAR_SCALE, 32 * BAR_SCALE)
        spark:SetBlendMode("ADD")
        spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
        bar.spark = spark
    end
    bar.text = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    return bar
end

-- Calls fn with the story as the current one (lore chapters read it), like
-- SM.IsStoryFinished.
local function WithStory(data, fn, ...)
    local previous = SM.GetCurrentStoryData and SM.GetCurrentStoryData() or nil
    if SM.SetCurrentStoryData then SM.SetCurrentStoryData(data) end
    local a, b, c = fn(...)
    if SM.SetCurrentStoryData then SM.SetCurrentStoryData(previous) end
    return a, b, c
end

local function NewEntry()
    local entry = { lines = {} }

    local section = CreateFrame("Button", nil, content)
    section.text = NewText(section, SECTION_FONT, false)
    section.text:SetTextColor(HEADING_COLOR[1], HEADING_COLOR[2], HEADING_COLOR[3])
    section.fold = section:CreateTexture(nil, "ARTWORK")
    section:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    section:SetScript("OnClick", function(_, button)
        if not entry.data then return end
        if button == "RightButton" then
            -- Untrack this chapter.
            if SM.ToggleTrackedChapter then SM.ToggleTrackedChapter(entry.data, entry.chapter, false) end
            return
        end
        ToggleFolded(entry.data, entry.chapter)
        Refresh()
    end)
    -- The chapter's name and summary, as its node on the Progress track
    -- shows them (the summary only once it's reached, in Explorer mode),
    -- then what a click does.
    section:SetScript("OnEnter", function(self)
        local data, ch = entry.data, entry.chapter
        if not (data and ch) then return end
        AnchorTooltip(self)
        GameTooltip:AddLine(ch.chapter, 1, 0.82, 0)
        local explorer = SM.IsExplorerMode and SM.IsExplorerMode()
        local summary = SM.GetChapterText and SM.GetChapterText(ch, "summary")
        if summary and summary ~= "" and (not explorer or WithStory(data, SM.IsChapterReached, data, ch)) then
            GameTooltip:AddLine(summary, 1, 1, 1, true)
        end
        if ShowsHelp() then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(SM.FormatHotkeys(L["Tracker Tooltip Heading"]), 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    section:SetScript("OnLeave", function() GameTooltip:Hide() end)
    entry.section = section

    local quest = CreateFrame("Button", nil, content)
    quest:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    quest.shield = quest:CreateTexture(nil, "ARTWORK", nil, 1)
    quest.shield:SetSize(SHIELD_SIZE, SHIELD_SIZE)
    -- By its centre, so a dungeon or raid pin of another size sits in its place.
    quest.shield:SetPoint("CENTER", quest, "TOPLEFT", 2 + SHIELD_SIZE / 2, 3 - SHIELD_SIZE / 2)
    quest.glyph = quest:CreateTexture(nil, "ARTWORK", nil, 2)
    quest.glyph:SetSize(SHIELD_SIZE, SHIELD_SIZE)
    quest.glyph:SetPoint("CENTER", quest.shield, "CENTER")
    quest.glow = quest:CreateTexture(nil, "ARTWORK", nil, 3)
    quest.glow:SetSize(SHIELD_SIZE, SHIELD_SIZE)
    quest.glow:SetPoint("CENTER", quest.shield, "CENTER")
    quest.glow:SetBlendMode("ADD")
    if HasAtlas(ATLAS.glow) then quest.glow:SetAtlas(ATLAS.glow) end
    quest.glow:Hide()
    quest.title = NewText(quest, LINE_FONT)
    quest.title:SetPoint("TOPLEFT", quest, "TOPLEFT", TITLE_X, 0)
    -- Dungeon / Raid, right under the title.
    quest.tag = NewText(quest, STEP_FONT, false)
    quest.tag:SetPoint("TOPLEFT", quest.title, "BOTTOMLEFT", 0, -TAG_GAP)
    SetColor(quest.tag, TAG_COLOR)
    quest.tag:Hide()
    quest:SetScript("OnEnter", function(self)
        entry.hovering = true
        PaintQuest(entry)
        -- The quest's name and where it stands, who gives it and where, its
        -- step's text and objectives (as the tracker shows them, so Explorer
        -- mode gives nothing more away), then what a click does.
        local data, nextQuest = entry.data, entry.nextQuest
        if not (data and nextQuest) then return end
        AnchorTooltip(self)
        GameTooltip:AddLine(nextQuest.name or "", 1, 0.82, 0)
        -- Dungeon / Raid, as under the title on the tracker.
        local tagText = InstanceTagText(nextQuest)
        if tagText then GameTooltip:AddLine(tagText, TAG_COLOR.r, TAG_COLOR.g, TAG_COLOR.b) end
        if entry.locked then
            local reason = SM.GetQuestlineGateReason and SM.GetQuestlineGateReason(data, entry.chapter)
            if reason then GameTooltip:AddLine(reason, COLOR.locked.r, COLOR.locked.g, COLOR.locked.b, true) end
        else
            local inLog, questID = SM.IsQuestEntryInLog(nextQuest)
            local status
            if inLog and questID and C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) then
                status = L["Tracker Quest Ready"]
            elseif inLog then
                status = L["Quest Status In Progress"]
            else
                status = L["Tracker Quest To Pick Up"]
            end
            GameTooltip:AddLine(status, 0.7, 0.7, 0.7)
            -- Explorer mode names no giver or place here: the hint alone
            -- says roughly where to look.
            local giver = not (SM.IsExplorerMode and SM.IsExplorerMode())
                and SM.GetQuestGiverText and SM.GetQuestGiverText(data, nextQuest)
            if giver and giver ~= "" then GameTooltip:AddLine(giver, 1, 1, 1, true) end
            -- A nudge toward the step (a vaguer one in Explorer mode).
            local hint = SM.GetQuestHint and SM.GetQuestHint(nextQuest)
            if not hint and not inLog and SM.IsExplorerMode and SM.IsExplorerMode() and SM.GetExplorerFallbackHint then
                hint = SM.GetExplorerFallbackHint(data, nextQuest, entry.chapter)
            end
            if hint then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(hint, 0.55, 0.85, 1, true)
            end
            local explorer = SM.IsExplorerMode and SM.IsExplorerMode()
            local step = (not explorer or inLog) and SM.GetQuestCardText and SM.GetQuestCardText(nextQuest.id)
            if step and step ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(step, 1, 1, 1, true)
            end
            local objectives = inLog and questID and SM.GetQuestObjectives and SM.GetQuestObjectives(questID)
            if objectives and #objectives > 0 then
                GameTooltip:AddLine(" ")
                for _, objective in ipairs(objectives) do
                    if objective.text and objective.text ~= "" then
                        if objective.finished then
                            GameTooltip:AddLine(objective.text, 0.45, 0.9, 0.35, true)
                        else
                            GameTooltip:AddLine(objective.text, 0.9, 0.9, 0.9, true)
                        end
                    end
                end
            end
        end
        if ShowsHelp() then
            GameTooltip:AddLine(" ")
            local focusedNow = not entry.locked and IsFocused(nextQuest)
            GameTooltip:AddLine(SM.FormatHotkeys(focusedNow and L["Tracker Tooltip Left Click Stop"] or L["Tracker Tooltip Left Click"]), 0.7, 0.7, 0.7)
            -- Shift-left-click opens the quest log on a quest that's in it.
            if not entry.locked and SM.IsQuestEntryInLog(nextQuest) then
                GameTooltip:AddLine(SM.FormatHotkeys(L["Tracker Tooltip Shift Click Log"]), 0.7, 0.7, 0.7)
            end
            GameTooltip:AddLine(SM.FormatHotkeys(L["Tracker Tooltip Right Click"]), 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    quest:SetScript("OnLeave", function()
        entry.hovering = false
        PaintQuest(entry)
        GameTooltip:Hide()
    end)
    quest:SetScript("OnClick", function(_, button)
        if not entry.data then return end
        if button == "RightButton" then
            OpenStory(entry.data, entry.chapter)
        elseif button == "LeftButton" and IsShiftKeyDown() then
            -- The quest log, open on the quest, while it's in the log.
            local inLog, questID = false, nil
            if entry.nextQuest then inLog, questID = SM.IsQuestEntryInLog(entry.nextQuest) end
            if inLog and questID and SM.OpenQuestLogToQuest then SM.OpenQuestLogToQuest(questID) end
        elseif entry.nextQuest and not entry.locked and IsFocused(entry.nextQuest) and SM.ClearWaypointQuiet then
            -- Already the quest in focus: stop showing the way. It stays here.
            SM.ClearWaypointQuiet()
            PaintQuest(entry)
        elseif entry.nextQuest and not entry.locked and SM.SetWaypointQuiet then
            -- Sets the waypoint and focuses the quest without opening the
            -- map or the quest log (Continue Story in the window does).
            -- (No chat line: the shield and the waypoint say it.)
            local ok, err = pcall(SM.SetWaypointQuiet, entry.data, entry.nextQuest)
            if not ok then
                print(L["Addon Prefix"] .. tostring(err))
                geterrorhandler()(err)
            end
        end
    end)
    entry.quest = quest

    entry.bar = NewWidgetBar(quest)

    entries[#entries + 1] = entry
    return entry
end


-- A chapter's next quest if the tracker shows it, else nil. Shown: every
-- open chapter (one with a quest in the log or ready to take, as the story
-- itself would offer), unless the player untracked it, and any chapter the
-- player added though it isn't open yet. Optional chapters only when added.
-- In Explorer mode only chapters the player has reached. Done ones drop out.
local function ShownChapterQuest(data, ch, explorer)
    local state = SM.GetChapterTrackState(data, ch)
    if state == false then return nil end
    if state == nil and ch.optional then return nil end
    local nextQuest = WithStory(data, SM.FindChapterNextQuest, data, ch, true)
    if not nextQuest and state == true then
        nextQuest = WithStory(data, SM.FindChapterNextQuest, data, ch, false)
    end
    if not nextQuest then return nil end
    if explorer and not WithStory(data, SM.IsChapterReached, data, ch) then return nil end
    return nextQuest
end

-- The chapters to show, in story order, each with its next quest, then
-- (sub = true, under the same heading) the chapter's other quests that are
-- in the log or open (what they wait on is done): side quests, quests that
-- run alongside the next one, and the heads of other branches.
local function ChaptersToShow(data)
    local list = {}
    local explorer = SM.IsExplorerMode and SM.IsExplorerMode()
    for _, ch in ipairs(SM.GetAllChapters(data)) do
        local nextQuest = ShownChapterQuest(data, ch, explorer)
        if nextQuest then
            list[#list + 1] = { chapter = ch, quest = nextQuest }
            local quests = ch.quests or {}
            for i, q in ipairs(quests) do
                if q ~= nextQuest and SM.IsQuestForPlayer(q) and not SM.ShouldHideQuest(q) then
                    local open = not q.optional and not SM.IsQuestEffectivelyComplete(i, quests)
                        and SM.IsQuestOpen(quests, i)
                    if SM.IsQuestEntryInLog(q) or open then
                        list[#list + 1] = { chapter = ch, quest = q, sub = true }
                    end
                end
            end
        end
    end
    return list
end

-- The lines under a quest: { text =, finished =, plain = } each. First the
-- step's text from its quest card (plain), then, once the quest is
-- in the log, its live objectives, or before that who gives it and where.
local function QuestLines(data, nextQuest, gateReason, explorer, chapter)
    if gateReason then return { { text = gateReason } } end
    local list = {}
    local inLog, questID = SM.IsQuestEntryInLog(nextQuest)
    -- As on the quest cards: in Explorer mode the next quest names its
    -- giver, not what they'll ask, until it's in the log.
    if not explorer or inLog then
        local step = SM.GetQuestCardText and SM.GetQuestCardText(nextQuest.id)
        if step and step ~= "" then list[#list + 1] = { text = step, plain = true } end
    end
    local objectives = inLog and questID and SM.GetQuestObjectives and SM.GetQuestObjectives(questID)
    local added = false
    if objectives then
        for _, objective in ipairs(objectives) do
            if objective.text and objective.text ~= "" then
                list[#list + 1] = { text = objective.text, finished = objective.finished }
                added = true
            end
        end
    end
    if not added then
        -- In Explorer mode, the step's vague hint instead of who and where.
        local giver
        if explorer then
            -- A step without a hint still says roughly where to look,
            -- unless its own text above already does.
            giver = SM.GetQuestHint and SM.GetQuestHint(nextQuest)
            if not giver and #list == 0 and SM.GetExplorerFallbackHint then
                giver = SM.GetExplorerFallbackHint(data, nextQuest, chapter)
            end
        else
            giver = SM.GetQuestGiverText and SM.GetQuestGiverText(data, nextQuest)
        end
        if giver and giver ~= "" then list[#list + 1] = { text = giver } end
    end
    return list, inLog, questID
end

-- The glyph over the shield, and whether it's greyed: ! to pick up, the
-- in-progress icon while the quest is under way (a grey ? without it), ? to
-- hand in, the padlock (or, without it, a grey !) while the chapter is
-- locked. The in-progress icon's colour follows the focus (PaintQuest).
local function QuestGlyph(gateReason, inLog, questID)
    if gateReason then
        if HasAtlas(ATLAS.lock) then return ATLAS.lock, false end
        return ATLAS.bang, true
    end
    if inLog then
        if questID and C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) then
            return ATLAS.turnIn, false
        end
        if HasAtlas(ATLAS.inProgress) then return ATLAS.inProgress, false end
        return ATLAS.turnIn, true
    end
    return ATLAS.bang, false
end


-- Lays out one chapter under anchor (the frame above it); returns its
-- bottom-most frame and its height.
local function LayoutEntry(entry, data, item, anchor, width, explorer)
    local chapter, nextQuest = item.chapter, item.quest
    local gateReason = SM.GetQuestlineGateReason and SM.GetQuestlineGateReason(data, chapter)
    entry.data, entry.chapter, entry.nextQuest, entry.locked = data, chapter, nextQuest, gateReason ~= nil
    local section, quest = entry.section, entry.quest

    -- Another quest of the chapter above: no heading of its own, right
    -- under the quest before (and gone with it when the chapter is folded).
    local folded = IsFolded(data, chapter)
    local height
    if item.sub then
        section:Hide()
        if folded then
            quest:Hide()
            return anchor, 0
        end
        quest:ClearAllPoints()
        quest:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -SUB_GAP)
        quest:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -SUB_GAP)
        height = SUB_GAP
    else
        -- The heading.
        section.text:SetText(chapter.chapter)
        section.text:SetWidth(0)
        local textH = section.text:GetStringHeight()
        local foldH = math.max(8, math.floor(textH - 2 + 0.5))
        local foldW = HasAtlas(ATLAS.collapse) and foldH + 4 or 0
        section.text:SetWidth(math.min(section.text:GetStringWidth(), width - HEADING_TEXT_X - foldW - FOLD_RIGHT - 4))
        local sectionH = math.floor(textH + HEADING_PAD * 2 + 0.5)
        section:ClearAllPoints()
        -- Right under the plate; further down under the chapter before.
        local topGap = anchor == listTop and 4 or ENTRY_GAP
        section:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -topGap)
        section:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -topGap)
        section:SetHeight(sectionH)
        section.text:ClearAllPoints()
        section.text:SetPoint("LEFT", section, "LEFT", HEADING_TEXT_X, 0)
        if not PlaceStrip(section, ATLAS.section) then
            section.bg = section.bg or section:CreateTexture(nil, "BACKGROUND")
            section.bg:SetAllPoints()
            section.bg:SetColorTexture(0, 0, 0, 0.45)
        end
        local foldAtlas = folded and ATLAS.expand or ATLAS.collapse
        section.fold:SetShown(HasAtlas(foldAtlas))
        if HasAtlas(foldAtlas) then
            section.fold:SetAtlas(foldAtlas)
            section.fold:SetSize(foldH, foldH)
            section.fold:ClearAllPoints()
            section.fold:SetPoint("RIGHT", section, "RIGHT", -FOLD_RIGHT, 0)
        end
        section:Show()

        height = topGap + sectionH
        if folded then
            quest:Hide()
            return section, height
        end

        quest:ClearAllPoints()
        quest:SetPoint("TOPLEFT", section, "BOTTOMLEFT", 0, -QUEST_TOP)
        quest:SetPoint("TOPRIGHT", section, "BOTTOMRIGHT", 0, -QUEST_TOP)
        height = height + QUEST_TOP
    end

    local list, inLog, questID = QuestLines(data, nextQuest, gateReason, explorer, chapter)
    local glyph, grey = QuestGlyph(gateReason, inLog, questID)
    entry.glyph = glyph
    quest.glyph:SetShown(HasAtlas(glyph))
    if HasAtlas(glyph) then quest.glyph:SetAtlas(glyph) end
    if glyph == ATLAS.lock then
        quest.glyph:SetSize(LOCK_SIZE, LOCK_SIZE)
    elseif glyph == ATLAS.inProgress then
        quest.glyph:SetSize(IN_PROGRESS_SIZE, IN_PROGRESS_SIZE)
    else
        quest.glyph:SetSize(SHIELD_SIZE, SHIELD_SIZE)
    end
    -- The ! art sits low on the shield; lift it to look centred.
    quest.glyph:ClearAllPoints()
    quest.glyph:SetPoint("CENTER", quest.shield, "CENTER", 0, glyph == ATLAS.bang and BANG_RAISE or 0)
    GreyGlyph(quest.glyph, grey)

    quest.title:SetWidth(width - TITLE_X - 6)
    quest.title:SetText(nextQuest.name or "")
    local y = quest.title:GetStringHeight()
    -- A dungeon or raid step's tag under the title.
    local tagText = InstanceTagText(nextQuest)
    quest.tag:SetShown(tagText ~= nil)
    if tagText then
        quest.tag:SetText(tagText)
        y = y + TAG_GAP + quest.tag:GetStringHeight()
    end
    y = y + TITLE_GAP

    for i = 1, math.max(MAX_LINES, #entry.lines) do
        local line_ = list[i]
        local line = entry.lines[i] or (line_ and i <= MAX_LINES and NewLine(entry))
        if line then
            if line_ and i <= MAX_LINES then
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", quest, "TOPLEFT", LINE_X, -y)
                line:SetSize(width - LINE_X - 6, 1)
                line.text:SetWidth(width - LINE_X - 6)
                -- A finished objective gets the tracker's check beside it.
                local checked = line_.finished and HasAtlas(ATLAS.check)
                line.text:SetFontObject(STEP_FONT)
                line.text:SetText(line_.text)
                line.check:SetShown(checked)
                if checked then line.check:SetAtlas(ATLAS.check) end
                line.finished = line_.finished
                line:Show()
                y = y + line.text:GetStringHeight() + (line_.plain and STEP_GAP or GAP)
            else
                line:Hide()
            end
        end
    end

    -- Guided: how far into the chapter. Explorer gives nothing ahead away.
    -- Once per chapter, under its first quest.
    local bar = entry.bar
    local done, total = SM.GetChapterProgress(chapter)
    if not explorer and not item.sub and total and total > 0 then
        -- The border reaches past the bar on every side: room for it.
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", quest, "TOPLEFT", LINE_X + BAR_OVERHANG, -(y + BAR_OVERHANG_Y + 1))
        bar:SetWidth(width - LINE_X - 12 - BAR_OVERHANG * 2)
        bar:SetValue(done / total)
        bar.text:SetText(string.format("%d/%d", done, total))
        bar:Show()
        if bar.spark then
            -- The spark marks the fill's end, but not at empty or full.
            local fraction = done / total
            bar.spark:SetShown(fraction > 0 and fraction < 1)
        end
        y = y + BAR_H + BAR_OVERHANG_Y * 2 + GAP + 3
    else
        bar:Hide()
    end

    local questH = math.max(SHIELD_SIZE, y)
    quest:SetHeight(questH)
    quest:Show()
    PaintQuest(entry)
    return quest, height + questH
end

local function Hide()
    if SM.SetStoryTrackerShown then SM.SetStoryTrackerShown(false) end
    if SM.SetQuestItemTargets then SM.SetQuestItemTargets(B, scroll, nil) end
    if not B then return end
    if stack and slot then stack.Set(slot, false) else B:Hide() end
end

function Refresh()
    if not B and IsHiddenByPlayer() then return end
    local storyID = SM.GetFollowedStoryID and SM.GetFollowedStoryID()
    local data = storyID and SM.GetQuestlineByID and SM.GetQuestlineByID(storyID)
    local shown = data and ChaptersToShow(data) or {}
    if #shown == 0 or IsHiddenByPlayer() or EditModeActive() then
        Hide()
        return
    end
    CreateBlock()

    local tracker = stack and stack.Target and stack.Target()
    local width = tracker and tracker:GetWidth() or DEFAULT_W
    if not width or width < MIN_W then width = MIN_W elseif width > MAX_W then width = MAX_W end
    B:SetWidth(width)
    B.data = data

    -- The plate: just the story's title, inside the parchment (the art's
    -- frame takes its top). It stands on a line a little above the plate's
    -- lower edge, so a second line grows upward.
    local plateH = math.floor(width * PLATE_RATIO + 0.5)
    plate:SetHeight(plateH)
    local bottom = math.floor(plateH * PLATE_TEXT_BOTTOM + 0.5)
    plate.text:ClearAllPoints()
    plate.text:SetJustifyV("BOTTOM")
    plate.text:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT", 22, bottom)
    plate.text:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", -PLATE_TEXT_RIGHT, bottom)
    plate.text:SetText(data.title)

    -- One heading and quest per chapter shown.
    local explorer = SM.IsExplorerMode and SM.IsExplorerMode()
    -- The scroll area clips what's in it, and the headings' strip reaches
    -- past their edges, so the clip reaches as far: the list sits that far
    -- in from the scroll area's edges, and the area that far out from the
    -- block's.
    local clipX, clipY = StripOverflow()
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", plate, "BOTTOMLEFT", -clipX, clipY)
    scroll:SetPoint("TOPRIGHT", plate, "BOTTOMRIGHT", clipX, clipY)
    content:SetWidth(width + clipX * 2)
    listTop:ClearAllPoints()
    listTop:SetPoint("TOPLEFT", content, "TOPLEFT", clipX, -clipY)
    listTop:SetPoint("TOPRIGHT", content, "TOPRIGHT", -clipX, -clipY)

    local listH = 0
    local anchor = listTop
    for i, item in ipairs(shown) do
        local entry = entries[i] or NewEntry()
        local last, h = LayoutEntry(entry, data, item, anchor, width, explorer)
        anchor = last
        listH = listH + h
    end
    for i = #shown + 1, #entries do
        entries[i].section:Hide()
        entries[i].quest:Hide()
    end

    -- The list shows whole up to a share of the screen, and scrolls past it.
    listH = math.floor(listH + 0.5)
    local maxListH = math.floor((UIParent:GetHeight() or 768) * MAX_LIST_SHARE)
    local shownListH = math.min(listH, maxListH)
    content:SetHeight(listH + clipY * 2)
    scroll:SetHeight(shownListH + clipY * 2)
    -- Keep the scroll inside the list as it shrinks.
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, listH - shownListH)))
    local height = math.floor(plateH + shownListH + 0.5)
    B:SetHeight(height)
    -- The stack makes room for the block and a little more under it.
    if stack and slot then stack.Set(slot, true, height + BOTTOM_PAD) else B:Show() end
    -- Journey mode hides the quest tracker while a story shows here.
    if SM.SetStoryTrackerShown then SM.SetStoryTrackerShown(true) end
    -- Each shown quest in the log may have an item to use, beside it.
    if SM.SetQuestItemTargets then
        local targets = {}
        for i = 1, #shown do
            local entry = entries[i]
            if entry.nextQuest and not entry.locked and entry.quest:IsShown() then
                local inLog, questID = SM.IsQuestEntryInLog(entry.nextQuest)
                if inLog then targets[#targets + 1] = { frame = entry.quest, questID = questID } end
            end
        end
        SM.SetQuestItemTargets(B, scroll, targets)
    end
end

function SM.RefreshNextStepTracker()
    if SM.DebounceTask then
        SM.DebounceTask("next-step-tracker", 0.15, Refresh)
    else
        Refresh()
    end
end

function SM.ToggleNextStepTracker()
    local db = SM.DB()
    if not db then return end
    db.nextStepTrackerHidden = not db.nextStepTrackerHidden or nil
    print(L["Addon Prefix"] .. (db.nextStepTrackerHidden and L["Tracker Hidden"] or L["Tracker Shown"]))
    Refresh()
end

local function IsFollowed(data)
    return data ~= nil and data.id ~= nil and SM.GetFollowedStoryID and SM.GetFollowedStoryID() == data.id
end

-- Whether the tracker shows this chapter right now: its story is the one
-- followed, and the chapter is one the tracker would list for it.
local function IsShown(data, ch)
    if not IsFollowed(data) then return false end
    return ShownChapterQuest(data, ch, SM.IsExplorerMode and SM.IsExplorerMode()) ~= nil
end
SM.IsChapterInTracker = IsShown

function SM.IsStoryTracked(data)
    return IsFollowed(data)
end

-- Follows a story in the next-step tracker, in place of the one followed,
-- or stops following it (tracked: true, false, or nil to switch).
function SM.ToggleTrackedStory(data, tracked)
    if not (data and data.id) then return end
    if tracked == nil then tracked = not IsFollowed(data) end
    if SM.SetFollowedStoryID then SM.SetFollowedStoryID(tracked and data.id or nil) end
    if SM.Client.isForever then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    Refresh()
    if SM.RefreshStoryListState then SM.RefreshStoryListState() end
    if SM.RefreshTrackNodeBadges then SM.RefreshTrackNodeBadges() end
end

-- The hint a chapter's node on the Progress track shows, or nil when it
-- can't be tracked (finished, or not reached yet in Explorer mode) or the
-- player turned help in tooltips off.
function SM.GetChapterTrackHint(data, ch)
    if not (data and ch) or not ShowsHelp() then return nil end
    if IsShown(data, ch) then return SM.FormatHotkeys(L["Tracker Node Untrack"]) end
    if not WithStory(data, SM.FindChapterNextQuest, data, ch, false) then return nil end
    if SM.IsExplorerMode and SM.IsExplorerMode() and not WithStory(data, SM.IsChapterReached, data, ch) then return nil end
    return SM.FormatHotkeys(L["Tracker Node Track"])
end

-- Tracks a chapter of a story in the next-step tracker, or untracks it
-- (tracked: true, false, or nil to switch). Either way the tracker follows
-- that story.
function SM.ToggleTrackedChapter(data, ch, tracked)
    if not (data and ch) then return end
    if tracked == nil then tracked = not IsShown(data, ch) end
    if tracked then
        if SM.IsExplorerMode and SM.IsExplorerMode() and not WithStory(data, SM.IsChapterReached, data, ch) then
            print(L["Addon Prefix"] .. L["Tracker Explorer Unreached"])
            return
        end
        if not WithStory(data, SM.FindChapterNextQuest, data, ch, false) then return end
        -- Back to the default if that shows it (it's open); else added by hand.
        local open = WithStory(data, SM.FindChapterNextQuest, data, ch, true)
        if open and not ch.optional then
            SM.SetChapterTrackState(data, ch, nil)
        else
            SM.SetChapterTrackState(data, ch, true)
        end
    else
        SM.SetChapterTrackState(data, ch, false)
    end
    if SM.Client.isForever then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    Refresh()
    if SM.RefreshStoryListState then SM.RefreshStoryListState() end
    if SM.RefreshTrackNodeBadges then SM.RefreshTrackNodeBadges() end
end

-- ── Preview (the settings page) ──────────────────────────────────────────
-- Every look a quest can have on the tracker, built from the same art and
-- sizes: one row per state, its shield as it shows normally and while the
-- quest is the one in focus, then a dungeon step's tag.
local PREVIEW = { rowH = 36, labelW = 190, cellW = 90, gap = 6 }

local function PreviewIcon(parent, glyph, focused, locked)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetSize(SHIELD_SIZE, SHIELD_SIZE)
    local padlock = locked and HasAtlas(ATLAS.lock)
    local shieldAtlas = (focused and HasAtlas(ATLAS.shieldFocus)) and ATLAS.shieldFocus or ATLAS.shield
    if not padlock and HasAtlas(shieldAtlas) then
        local shield = cell:CreateTexture(nil, "ARTWORK", nil, 1)
        shield:SetSize(SHIELD_SIZE, SHIELD_SIZE)
        shield:SetPoint("CENTER")
        shield:SetAtlas(shieldAtlas)
        shield:SetDesaturated(locked and true or false)
    end
    if glyph == ATLAS.inProgress and focused and HasAtlas(ATLAS.inProgressFocus) then glyph = ATLAS.inProgressFocus end
    if HasAtlas(glyph) then
        local tex = cell:CreateTexture(nil, "ARTWORK", nil, 2)
        local size = (glyph == ATLAS.lock and LOCK_SIZE)
            or ((glyph == ATLAS.inProgress or glyph == ATLAS.inProgressFocus) and IN_PROGRESS_SIZE)
            or SHIELD_SIZE
        tex:SetSize(size, size)
        tex:SetPoint("CENTER", 0, glyph == ATLAS.bang and BANG_RAISE or 0)
        tex:SetAtlas(glyph)
        if locked and not padlock then
            tex:SetDesaturated(true)
            tex:SetAlpha(0.75)
        end
    end
    return cell
end

-- Builds the preview in parent; returns its height.
function SM.BuildTrackerPreview(parent)
    local states = {
        { label = "Preview To Pick Up", glyph = ATLAS.bang },
        { label = "Preview In Progress", glyph = HasAtlas(ATLAS.inProgress) and ATLAS.inProgress or ATLAS.turnIn },
        { label = "Preview Ready", glyph = ATLAS.turnIn },
        { label = "Preview Locked", glyph = HasAtlas(ATLAS.lock) and ATLAS.lock or ATLAS.bang, locked = true },
    }
    local y = 0
    -- Column headings.
    for i, key in ipairs({ "Preview Normal", "Preview Tracked" }) do
        local head = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        head:SetPoint("TOP", parent, "TOPLEFT", PREVIEW.labelW + (i - 0.5) * PREVIEW.cellW, -y)
        head:SetText(L[key])
    end
    y = y + 18
    for _, state in ipairs(states) do
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", parent, "TOPLEFT", 0, -(y + PREVIEW.rowH / 2))
        label:SetWidth(PREVIEW.labelW - 8)
        label:SetJustifyH("LEFT")
        label:SetText(L[state.label])
        for i, focused in ipairs({ false, true }) do
            -- A locked chapter can't be the one in focus.
            if not (state.locked and focused) then
                local cell = PreviewIcon(parent, state.glyph, focused, state.locked)
                cell:SetPoint("CENTER", parent, "TOPLEFT", PREVIEW.labelW + (i - 0.5) * PREVIEW.cellW, -(y + PREVIEW.rowH / 2))
            end
        end
        y = y + PREVIEW.rowH
    end
    -- A dungeon step: its title, the tag under it.
    y = y + PREVIEW.gap
    local cell = PreviewIcon(parent, ATLAS.bang, false)
    cell:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -y)
    local title = parent:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(LINE_FONT)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", TITLE_X, -(y + 3))
    title:SetText(L["Preview Dungeon Step"])
    SetColor(title, COLOR.title)
    local tag = INSTANCE_TAG.dungeon
    local tagText = _G[tag.label] or tag.fallback
    if HasAtlas(tag.icon) then
        tagText = string.format("|A:%s:%d:%d|a %s", tag.icon, INSTANCE_ICON_SIZE, INSTANCE_ICON_SIZE, tagText)
    end
    local tagLine = parent:CreateFontString(nil, "OVERLAY")
    tagLine:SetFontObject(STEP_FONT)
    tagLine:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -TAG_GAP)
    tagLine:SetText(tagText)
    SetColor(tagLine, TAG_COLOR)
    y = y + SHIELD_SIZE + 12
    return y
end

-- Shows or hides the tracker (the settings page; /sm tracker toggles it).
function SM.SetNextStepTrackerShown(on)
    local db = SM.DB()
    if not db then return end
    db.nextStepTrackerHidden = not on or nil
    Refresh()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "SUPER_TRACKING_CHANGED" }) do
    -- (pcall: a client without one of these events would raise an error)
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function()
    SM.RefreshNextStepTracker()
end)

-- Out of the way while Edit Mode places the quest tracker.
if _G.EditModeManagerFrame then
    if EditModeManagerFrame.EnterEditMode then hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() Refresh() end) end
    if EditModeManagerFrame.ExitEditMode then hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() SM.RefreshNextStepTracker() end) end
end
