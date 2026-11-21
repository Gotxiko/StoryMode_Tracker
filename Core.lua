local addonName, T = ...

-- =============================================================================
-- Story Mode - Tracker: core
-- A companion to Story Mode, kept apart so Story Mode itself can stay the
-- author's release. Story Mode exposes its namespace as _G.StoryMode; this
-- addon's namespace (T) reads through to it, so the tracker's code calls
-- Story Mode's functions as SM.* and its own as SM.* too. What this addon
-- defines stays in T and never lands in Story Mode's table, except the few
-- functions Hooks.lua wraps on purpose.
-- Story Mode's data and answers come first (what a quest is, whether a
-- chapter is locked or reached, ...); this addon asks the game itself only
-- where Story Mode has no answer.
-- =============================================================================

local SM = _G.StoryMode
T.Base = SM
setmetatable(T, { __index = SM })

if not (SM and SM.Client and SM.Client.isForever) then return end

local L = T.L

-- ── Saved state ──────────────────────────────────────────────────────────
-- StoryModeTrackerDB:
--   followedStory[character]            = story ID
--   trackedChapters[character][storyID] = { [chapter key] = true | false }
--   nextStepTrackerHidden               = true | nil
--   nextStepTrackerFolded[story|chapter] = true | nil

-- Same key Story Mode uses for a character ("Realm:Name").
local function CharacterKey()
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    if not name or name == "" then name = UnitName and UnitName("player") end
    if not name or name == "" then return nil end
    if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
    return (realm or "UnknownRealm") .. ":" .. name
end

local function DB()
    return _G.StoryModeTrackerDB
end
T.DB = DB

-- The fork of Story Mode this addon came out of kept the same state in
-- StoryModeDB. Brought over once, so nothing tracked is lost.
local MIGRATED_FIELDS = { "followedStory", "trackedChapters", "nextStepTrackerHidden", "nextStepTrackerFolded" }

local function InitDB()
    _G.StoryModeTrackerDB = _G.StoryModeTrackerDB or {}
    local db = _G.StoryModeTrackerDB
    if not db.migrated then
        local old = _G.StoryModeDB
        if type(old) == "table" then
            for _, field in ipairs(MIGRATED_FIELDS) do
                if db[field] == nil and old[field] ~= nil then db[field] = old[field] end
            end
        end
        db.migrated = true
    end
end

function T.GetFollowedStoryID()
    local db, key = DB(), CharacterKey()
    return db and key and db.followedStory and db.followedStory[key] or nil
end

function T.SetFollowedStoryID(storyID)
    local db, key = DB(), CharacterKey()
    if not (db and key) then return end
    db.followedStory = db.followedStory or {}
    db.followedStory[key] = storyID
end

-- A chapter's key: its English name, the same in every language. Story Mode
-- translates chapter names in place, so the English one is found again
-- through its locale table (English text -> translation).
local englishOf
local function EnglishName(name)
    if type(name) ~= "string" then return name end
    if not englishOf then
        englishOf = {}
        for english, localized in pairs(SM.L or {}) do
            if type(localized) == "string" and type(english) == "string" and englishOf[localized] == nil then
                englishOf[localized] = english
            end
        end
    end
    return englishOf[name] or name
end

local function ChapterKey(ch)
    return ch and (ch._key or EnglishName(ch.chapter))
end
T.GetTrackedChapterKey = ChapterKey

local function ChapterTrackStates(storyID, create)
    local db, key = DB(), CharacterKey()
    if not (db and key and storyID) then return nil end
    if create then
        db.trackedChapters = db.trackedChapters or {}
        db.trackedChapters[key] = db.trackedChapters[key] or {}
        db.trackedChapters[key][storyID] = db.trackedChapters[key][storyID] or {}
    end
    local byStory = db.trackedChapters and db.trackedChapters[key]
    return byStory and byStory[storyID]
end

-- What the player chose for a chapter: true (shown though it isn't open
-- yet), false (untracked), or nil (the default: shown while it's open).
function T.GetChapterTrackState(data, ch)
    local states = data and ChapterTrackStates(data.id, false)
    if not states then return nil end
    return states[ChapterKey(ch)]
end

-- Sets a chapter's choice (true, false or nil) and follows its story.
function T.SetChapterTrackState(data, ch, state)
    if not (data and data.id and ch) then return end
    local states = ChapterTrackStates(data.id, state ~= nil)
    if states then states[ChapterKey(ch)] = state end
    T.SetFollowedStoryID(data.id)
end

-- ── Hotkey icons ─────────────────────────────────────────────────────────
-- Strings carry {lclick}, {rclick} and {shift}; each becomes the housing
-- editor's hotkey icon where the client has that atlas, else its word.
local HOTKEY_ATLAS = { lclick = "housing-hotkey-icon-leftclick", rclick = "housing-hotkey-icon-rightclick" }
local HOTKEY_WORD = { lclick = "Hotkey Left Click", rclick = "Hotkey Right Click", shift = "Hotkey Shift" }
local HOTKEY_ICON_SIZE = 16

function T.FormatHotkeys(text)
    if type(text) ~= "string" then return text end
    return (text:gsub("{(%a+)}", function(key)
        local atlas = HOTKEY_ATLAS[key]
        if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
            return string.format("|A:%s:%d:%d|a", atlas, HOTKEY_ICON_SIZE, HOTKEY_ICON_SIZE)
        end
        local word = HOTKEY_WORD[key]
        return word and L[word] or nil
    end))
end

-- The tracking crosshair, for "in the next-step tracker".
function T.SetTrackedIconTexture(tex)
    if SM.SafeSetAtlas and SM.SafeSetAtlas(tex, "crosshair_track_48", false) then return end
    tex:SetTexture("Interface\\Cursor\\UITrackCrosshair2x")
end

-- A badge with the crosshair, hidden until shown.
function T.CreateTrackedBadge(parent, size)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(size, size)
    badge:SetFrameLevel(parent:GetFrameLevel() + 10)
    local icon = badge:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    T.SetTrackedIconTexture(icon)
    badge:Hide()
    return badge
end

-- Story Mode's finished flag with the crosshair in place of the check.
function T.CreateTrackedRibbon(parent)
    local ribbon = SM.CreateCompletionRibbon(parent)
    local _, check = ribbon:GetRegions()
    if check then
        check:SetVertexColor(1, 1, 1)
        T.SetTrackedIconTexture(check)
        check:SetSize(18, 18)
    end
    return ribbon
end

-- ── Quest text (as Story Mode's quest cards show it) ─────────────────────
local ENGLISH = { enUS = true, enGB = true }
function T.GetQuestCardText(questID)
    if not questID then return nil end
    local text = SM.ForeverQuestTextLocalized and SM.ForeverQuestTextLocalized[questID]
    if not text and ENGLISH[GetLocale()] then
        text = SM.ForeverQuestText and SM.ForeverQuestText[questID]
    end
    if not text then return nil end
    if SM.ApplyGenderTokens then text = SM.ApplyGenderTokens(text) end
    text = text:gsub("%$%d+o[a-z]%s*", "")
    text = text:gsub("%$[Nn]", UnitName and UnitName("player") or "")
    text = text:gsub("%$[Cc]", UnitClass and (UnitClass("player")) or "")
    text = text:gsub("%$[Rr]", UnitRace and (UnitRace("player")) or "")
    text = text:gsub("%$[Bb]", " "):gsub("%s+", " ")
    return text
end

-- A dungeon or raid quest's label ("Dungeon", "Raid", in the player's
-- language) and the quest log's icon for it, or nil. Story Mode says which
-- it is (SM.GetQuestInstanceType: the game's quest tag, remembered per
-- account, or the story data); the game's tag is read here only where Story
-- Mode has no answer.
local DUNGEON_ICON, RAID_ICON = "questlog-questtypeicon-dungeon", "questlog-questtypeicon-raid"
local INSTANCE_QUEST_TAGS = { [81] = DUNGEON_ICON, [62] = RAID_ICON, [88] = RAID_ICON, [89] = RAID_ICON }
local DATA_INSTANCE_TAGS = {
    dungeon = { label = "LFG_TYPE_DUNGEON", fallback = "Dungeon", icon = DUNGEON_ICON },
    raid = { label = "LFG_TYPE_RAID", fallback = "Raid", icon = RAID_ICON },
}
function T.GetInstanceQuestTag(quest)
    if not quest then return nil end
    if SM.GetQuestInstanceType then
        local kind = SM.GetQuestInstanceType(quest)
        local tag = DATA_INSTANCE_TAGS[kind]
        if tag then return _G[tag.label] or tag.fallback, tag.icon end
        if kind == "none" then return nil end
    end
    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        for _, questID in ipairs(SM.GetQuestIDs(quest)) do
            local info = C_QuestLog.GetQuestTagInfo(questID)
            if info and INSTANCE_QUEST_TAGS[info.tagID] and info.tagName and info.tagName ~= "" then
                return info.tagName, INSTANCE_QUEST_TAGS[info.tagID]
            end
        end
    end
    local tag = quest.instance and DATA_INSTANCE_TAGS[quest.instance]
    if tag then return _G[tag.label] or tag.fallback, tag.icon end
    return nil
end

-- Who gives the quest and where, from the story data.
function T.GetQuestGiverText(data, quest)
    local npc = quest and quest.npc or ""
    local location = quest and (quest.location
        or (data and data.npcLocations and data.npcLocations[quest.npc] and data.npcLocations[quest.npc].location))
    if location and location ~= "" then
        -- A location standing alone gets a capital (ASCII only: %l never
        -- matches a UTF-8 lead byte).
        if npc == "" then return (location:gsub("^%l", string.upper)) end
        if location:sub(1, #npc) == npc then return location end
        return npc .. ", " .. location
    end
    return npc
end

-- A nudge toward the step, where the story data has one. In Explorer mode
-- hintExplorer, which only says roughly where to look, wins.
function T.GetQuestHint(quest)
    if not quest then return nil end
    local hint = (SM.IsExplorerMode() and quest.hintExplorer) or quest.hint
    if hint and hint ~= "" then return SM.L[hint] or hint end
    return nil
end

-- ── Explorer mode hints ──────────────────────────────────────────────────
local function LastPart(location)
    local area = location and location:match(".*,%s*(.-)%s*$")
    if area and area ~= "" then return area end
    return nil
end

local function MapName(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo
        and C_Map.GetMapInfo(SM.GetClientMapID and SM.GetClientMapID(mapID) or mapID)
    return info and info.name or nil
end

-- Roughly where a step happens: the zone part of its location, its map's
-- zone, its giver's map's zone or place, else the story's zone.
local function ExplorerStartArea(data, quest)
    if not quest then return data and data.zone or nil end
    local npc = data and data.npcLocations and quest.npc and data.npcLocations[quest.npc]
    return LastPart(quest.location) or MapName(quest.mapID)
        or (npc and (MapName(npc.mapID) or LastPart(npc.location)))
        or (data and data.zone) or nil
end

-- What the tracker says under a step in Explorer mode with no hint: the
-- chapter's description, else roughly where to look, never who or where.
function T.GetExplorerFallbackHint(data, quest, chapter)
    local summary = chapter and SM.GetChapterText and SM.GetChapterText(chapter, "summary")
    if summary and summary ~= "" then return summary end
    local area = ExplorerStartArea(data, quest)
    local hasGiver = quest and quest.npc and quest.npc ~= ""
    if area and area ~= "" then
        return string.format(hasGiver and L["Explorer Hint Giver Format"] or L["Explorer Hint Search Format"], area)
    end
    return L["Explorer Hint Explore"]
end

-- ── A chapter's next quest ───────────────────────────────────────────────
-- Built on Story Mode's own rules (SM.IsQuestEffectivelyComplete): a quest
-- waits on the step before it; parallel quests share a step; after = id(s)
-- opens a quest once those are done instead.

local function CountsAsStep(q)
    return q ~= nil and not q.optional and SM.IsQuestForPlayer(q) and not SM.ShouldHideQuest(q)
end

local function QuestIndexByID(quests, id)
    for i, q in ipairs(quests) do
        for _, questID in ipairs(SM.GetQuestIDs(q)) do
            if questID == id then return i end
        end
    end
    return nil
end

-- The index of the step a quest belongs to (parallel quests join the one
-- before them).
function T.GetQuestStepLead(quests, index)
    local i = index
    while i > 1 and quests[i] and quests[i].parallel do i = i - 1 end
    return i
end

-- What the quest at index waits on: indices in the chapter, and IDs outside.
function T.GetQuestDependencies(quests, index)
    local q = quests and quests[index]
    if not q then return {}, {} end
    if q.after then
        local inside, outside = {}, {}
        for _, id in ipairs(type(q.after) == "table" and q.after or { q.after }) do
            local i = QuestIndexByID(quests, id)
            if i then inside[#inside + 1] = i else outside[#outside + 1] = id end
        end
        return inside, outside
    end
    if q.parallel then
        local lead = T.GetQuestStepLead(quests, index)
        if lead ~= index then return T.GetQuestDependencies(quests, lead) end
    end
    local prev = index - 1
    while prev >= 1 and not CountsAsStep(quests[prev]) do prev = prev - 1 end
    if prev < 1 then return {}, {} end
    local inside = {}
    for i = T.GetQuestStepLead(quests, prev), prev do
        if CountsAsStep(quests[i]) then inside[#inside + 1] = i end
    end
    return inside, {}
end

-- Whether everything the quest at index waits on is done; if not, the first
-- quest it's still waiting on.
function T.IsQuestOpen(quests, index)
    local inside, outside = T.GetQuestDependencies(quests, index)
    for _, i in ipairs(inside) do
        if not SM.IsQuestEffectivelyComplete(i, quests) then return false, quests[i] end
    end
    for _, id in ipairs(outside) do
        if not SM.IsQuestComplete(id) then return false, { id = id } end
    end
    return true
end

local function HasPrereqProgress(data)
    if not data.prereqs then return true end
    for _, ch in ipairs(data.prereqs) do
        if SM.GetChapterProgress(ch) > 0 then return true end
    end
    return false
end

-- One chapter's next step: the quest it has in the log, or the one it's
-- ready for, or nil when it has none right now.
local function ChapterCandidate(ch, hasPrereqProgress)
    local unmetPrereq = SM.GetFirstUnmetChapterPrerequisite and SM.GetFirstUnmetChapterPrerequisite(ch)
    if unmetPrereq then
        return {
            id = unmetPrereq.id,
            name = unmetPrereq.name,
            npc = unmetPrereq.npc,
            _isPrerequisiteForChapter = ch.chapter,
        }
    end
    local chDone, chTotal = SM.GetChapterProgress(ch)
    if chDone >= chTotal then return nil end
    local section = ch._section or 1
    for j, q in ipairs(ch.quests or {}) do
        if not SM.IsQuestForPlayer(q) or SM.ShouldHideQuest(q) then
            -- the opposing faction's variant, or a branch the player didn't take
        elseif SM.IsQuestEntryInLog(q) then
            return q
        elseif not SM.IsQuestEffectivelyComplete(j, ch.quests) then
            if j == 1 then
                if (section >= 2 and hasPrereqProgress)
                    or (section == 1 and chDone == 0 and not hasPrereqProgress) then
                    return q
                end
                return nil
            elseif T.IsQuestOpen(ch.quests, j) then
                return q
            end
            -- Not open yet: a quest further down may be (another branch).
        end
    end
    return nil
end

-- The next quest of one chapter. strict: only what the story itself would
-- offer now (in the log, or ready to take). Otherwise a chapter the story
-- wouldn't send the player to yet still names its first unfinished quest.
-- nil once the chapter is done.
function T.FindChapterNextQuest(data, ch, strict)
    if not (data and ch) then return nil end
    local quest = ChapterCandidate(ch, HasPrereqProgress(data))
    if quest then return quest end
    if strict then return nil end
    local chDone, chTotal = SM.GetChapterProgress(ch)
    if chDone >= chTotal then return nil end
    for j, q in ipairs(ch.quests or {}) do
        if SM.IsQuestForPlayer(q) and not SM.ShouldHideQuest(q) and not SM.IsQuestEffectivelyComplete(j, ch.quests) then
            return q
        end
    end
    return nil
end

-- ── Showing the way without opening anything ─────────────────────────────
-- Story Mode's Track Quest (SM.SetWaypointForQuest) sets the waypoint and
-- focus, then opens the quest log and the world map to ping the spot.
-- Clicked from the tracker while playing, only the first part is wanted, and
-- opening the map only to close it again makes the game hitch. So this does
-- what Story Mode does there, step for step, but never touches the map or
-- the quest log. Story Mode's data says where a quest is; the game is asked
-- only to place it exactly.

-- Whether Story Mode may mark the map (WoW Forever: only while the world
-- map's Quest Objectives filter is on), as in Story Mode.
local function MapPinsWanted()
    if not (SM.Client and SM.Client.isForever) then return true end
    local value = GetCVar and GetCVar("questPOI")
    return value == nil or value == "1"
end

-- Trivial quest tracking on, as Story Mode turns it on, so low quests show.
local function EnsureTrivialQuestsVisible()
    if not (SM.GetNumTrackingTypes and SM.GetTrackingInfo and SM.SetTracking) then return end
    for i = 1, SM.GetNumTrackingTypes() do
        local info = SM.GetTrackingInfo(i)
        if info and not info.active then
            local isTrivial = (MINIMAP_TRACKING_TRIVIAL_QUESTS and info.name == MINIMAP_TRACKING_TRIVIAL_QUESTS)
                or info.name == "Trivial Quests" or info.name == "Low Level Quests"
            if isTrivial then
                local idx, name = i, info.name
                C_Timer.After(0, function()
                    SM.SetTracking(idx, true)
                    local format = SM.L and SM.L["Tracking Enabled Trivial Format"]
                    if format then print(L["Addon Prefix"] .. string.format(format, name)) end
                end)
                return
            end
        end
    end
end

local function TrackedQuestID(quest)
    local _, activeID = SM.IsQuestEntryInLog(quest)
    return activeID or quest.id
end

-- Where the game puts the quest's icon (a quest in the log, or one offered
-- on the map at hand), or nil.
local function LiveQuestLocation(qid, mapHint)
    if not (qid and C_QuestLog) then return nil end
    if C_QuestLog.GetQuestUiMapID and C_QuestLog.GetNextWaypointForMap then
        local mapID = C_QuestLog.GetQuestUiMapID(qid)
        if mapID and mapID > 0 then
            local x, y = C_QuestLog.GetNextWaypointForMap(qid, mapID)
            if x and y then return { mapID = mapID, x = x, y = y } end
        end
    end
    if mapHint and C_QuestLog.GetQuestsOnMap then
        for _, q in ipairs(C_QuestLog.GetQuestsOnMap(mapHint) or {}) do
            if q.questID == qid and q.x and q.y then return { mapID = mapHint, x = q.x, y = q.y } end
        end
    end
    return nil
end

-- Where a quest is, as Story Mode finds it: the game's exact spot when it
-- knows one on the map the story data points to, else the story data's
-- (the quest's own spot, its giver's, the story's start).
local function QuestLocation(data, quest)
    local questLocation = quest.mapID and quest.x and quest.y
        and SM.GetClientLocation({ mapID = quest.mapID, x = quest.x, y = quest.y }) or nil
    local npcLocation = data.npcLocations and SM.GetClientLocation(data.npcLocations[quest.npc]) or nil
    local mapHint = (questLocation and questLocation.mapID) or (npcLocation and npcLocation.mapID)
        or SM.GetClientMapID(data.startMapID)
    local live = LiveQuestLocation(TrackedQuestID(quest), mapHint)
    if live then return live end
    if questLocation then return questLocation end
    if npcLocation then return npcLocation end
    if data.startQuest and quest.id == data.startQuest.id and data.startMapID and data.startX and data.startY then
        return SM.GetClientLocation({ mapID = data.startMapID, x = data.startX, y = data.startY })
    end
    return nil
end

-- A quest the story sends the player to first (guidanceQuest/s), while it's
-- still to do.
local function GuidanceOverride(quest)
    if SM.IsQuestEntryInLog(quest) then return nil end
    if quest.id and SM.IsQuestComplete(quest.id) then return nil end
    local function Pending(g)
        return type(g) == "table" and not (g.id and SM.IsQuestComplete(g.id))
    end
    for _, g in ipairs(type(quest.guidanceQuests) == "table" and quest.guidanceQuests or {}) do
        if Pending(g) then return g end
    end
    if Pending(quest.guidanceQuest) then return quest.guidanceQuest end
    return nil
end

local function TrackResult(kind, questID, loc, questOverride)
    return { kind = kind, questID = questID, mapID = loc and loc.mapID or nil, location = loc,
        openedQuestLog = false, quest = questOverride }
end

local WAYPOINT_SOUND = SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON or 167425

-- Sets the waypoint and focus for a quest, as Track Quest does, without
-- opening anything. Returns what SM.PrintTrackResult reports.
function T.SetWaypointQuiet(data, quest)
    if not (data and quest) then return TrackResult("no_location") end
    -- The tracker follows the story, as when it's continued in the window.
    if T.OnStoryContinued then T.OnStoryContinued(data, quest) end

    if SM.IsClassicClient and SM.IsClassicClient() then
        local inLog, activeID = SM.IsQuestEntryInLog(quest)
        if inLog then return TrackResult("classic_in_log", activeID) end
        local guidance = GuidanceOverride(quest)
        if guidance then return TrackResult("classic_guidance", nil, QuestLocation(data, guidance), guidance) end
        return TrackResult("classic_guidance", TrackedQuestID(quest))
    end

    local pinsWanted = MapPinsWanted()
    if pinsWanted then EnsureTrivialQuestsVisible() end

    if SM.IsQuestEntryInLog(quest) then
        local qid = TrackedQuestID(quest)
        if SM.AddQuestWatch then SM.AddQuestWatch(qid) end
        if pinsWanted and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
            C_SuperTrack.SetSuperTrackedQuestID(qid)
        end
        PlaySound(WAYPOINT_SOUND)
        return TrackResult(pinsWanted and "supertracked" or "classic_in_log", qid, QuestLocation(data, quest))
    end

    local guidance = GuidanceOverride(quest)
    local target = guidance or quest
    local loc = QuestLocation(data, target)
    local qid = TrackedQuestID(target)
    if pinsWanted and qid and C_SuperTrack and C_SuperTrack.SetSuperTrackedMapPin
        and Enum and Enum.SuperTrackingMapPinType and Enum.SuperTrackingMapPinType.QuestOffer then
        C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.QuestOffer, qid)
    end
    if pinsWanted and loc and C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(loc.mapID)
        and UiMapPoint and C_Map.SetUserWaypoint then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(loc.mapID, loc.x, loc.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        PlaySound(WAYPOINT_SOUND)
        return TrackResult("waypoint", qid, loc, guidance)
    end
    if loc then
        PlaySound(WAYPOINT_SOUND)
        return TrackResult("waypoint_approx", qid, loc, guidance)
    end
    return TrackResult("no_location", qid, nil, guidance)
end

-- ── Loading ──────────────────────────────────────────────────────────────
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    InitDB()
    if T.RefreshNextStepTracker then T.RefreshNextStepTracker() end
end)
