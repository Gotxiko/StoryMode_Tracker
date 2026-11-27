local addonName, T = ...

-- =============================================================================
-- Story Mode - Tracker: options in the Story Mode window
--
--   Show the tracker        the tracker at all (also /sm tracker)
--   Journey Mode            hides the quest tracker while a story is tracked
--                           (JourneyMode.lua)
--   Show help in tooltips   the click and shift-click lines in this addon's
--                           tooltips (on by default)
--
-- Story Mode 2.1 has a settings page in its window (the page facing the
-- letter on the start page). The tracker's options go there, in a section of
-- their own under Story Mode's, as rows like Story Mode's: the inked box on
-- the spellbook backplate, and what the option does in the column on the
-- right while the mouse is on it. Story Mode keeps that page to itself (its
-- list of settings is local), so the section is added each time Story Mode
-- lays the page out, by wrapping SM.ForeverWindow.LayoutStartPage.
--
-- An older Story Mode, with no settings page, gets checkboxes in the window's
-- header instead, right of the points bar and under the close button.
--
-- The same options are on the tracker's page under Options > AddOns
-- (SettingsPage.lua).
-- =============================================================================

local SM = T.Base
if not (SM and SM.Client and SM.Client.isForever) then return end

local L = T.L

-- ── Help in tooltips ─────────────────────────────────────────────────────
-- StoryModeTrackerDB.hideTooltipHelp = true | nil.
function T.ShowsTooltipHelp()
    local db = T.DB()
    return not (db and db.hideTooltipHelp)
end

local function SetTooltipHelp(on)
    local db = T.DB()
    if not db then return end
    db.hideTooltipHelp = not on or nil
    -- The Progress track's nodes keep their hint from the last layout.
    if T.RefreshTrackNodeBadges then T.RefreshTrackNodeBadges() end
end

-- ── The options ──────────────────────────────────────────────────────────
-- (headerToo: also in the header of an older Story Mode's window.)
local OPTIONS = {
    { label = "Show Tracker", text = "Show Tracker Text",
      get = function() local db = T.DB(); return not (db and db.nextStepTrackerHidden) end,
      set = function(on) if T.SetNextStepTrackerShown then T.SetNextStepTrackerShown(on) end end },
    { label = "Journey Mode", text = "Journey Mode Text", headerToo = true,
      get = function() return T.IsJourneyMode and T.IsJourneyMode() end,
      set = function(on) if T.SetJourneyMode then T.SetJourneyMode(on) end end },
    { label = "Tooltip Help", text = "Tooltip Help Text", headerToo = true,
      get = T.ShowsTooltipHelp,
      set = SetTooltipHelp },
}

T.TrackerOptions = OPTIONS

local function IsOn(option) return option.get() and true or false end

-- ── A section on Story Mode's settings page ──────────────────────────────
-- Story Mode's own numbers (START in its ForeverWindow.lua), so the rows
-- match its rows.
local ROW = {
    height = 38, gap = 6, inset = 10,
    backplate = "spellbook-item-backplate", idle = 0.25, hover = 1,
    controls = "Interface\\AddOns\\StoryMode\\Art\\Decor\\settings_controls",
    cellSize = 32, checkSize = 22,
    boxOff = { 0, 0.5, 0, 0.25 }, boxOn = { 0.5, 1, 0, 0.25 }, check = { 0, 0.5, 0.25, 0.5 },
    minListH = 280,                    -- the list's (and its rule's) height on Story Mode's page
}
local SECTION = { top = 18, below = 10 } -- space above the section's title and under it

local section = {}                     -- list, rule, title, rows, setFocus, ink

-- Story Mode's list: the frame on the start page whose children are its
-- setting rows (each a Button with .def and .backplate).
local function IsSettingsList(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.def and child.backplate and not child.smTracker then return true end
    end
    return false
end

local function FindSettingsList(parent)
    -- parent > the start page > its pages > the list.
    for _, page in ipairs({ parent:GetChildren() }) do
        for _, sub in ipairs({ page:GetChildren() }) do
            for _, frame in ipairs({ sub:GetChildren() }) do
                if IsSettingsList(frame) then return frame end
            end
        end
    end
end

-- The upright rule between the list and the explanation: a frame beside
-- the list with .core (where its line runs).
local function FindRule(list)
    for _, child in ipairs({ list:GetParent():GetChildren() }) do
        if child ~= list and child.core then return child end
    end
end

local function BaseRows(list)
    local rows = {}
    for _, child in ipairs({ list:GetChildren() }) do
        if child.def and child.backplate and not child.smTracker then rows[#rows + 1] = child end
    end
    return rows
end

local function RefreshRow(row)
    local on = IsOn(row.option)
    row.checkmark:SetShown(on)
    row.boxArt:SetTexCoord(unpack(on and ROW.boxOn or ROW.boxOff))
end

local function RefreshRows()
    for _, row in ipairs(section.rows or {}) do RefreshRow(row) end
end

local function Cell(parent, coords, size, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(ROW.controls)
    texture:SetTexCoord(unpack(coords))
    texture:SetSize(size, size)
    return texture
end

local function Inked(parent, font)
    local text = parent:CreateFontString(nil, "ARTWORK", font)
    text:SetShadowOffset(0, 0)
    text:SetTextColor(unpack(section.ink))
    return text
end

local function CreateRow(list, option)
    local row = CreateFrame("Button", nil, list)
    row.smTracker, row.option = true, option
    row:SetHeight(ROW.height)
    -- What Story Mode's page reads from a row it focuses: its explanation
    -- in the right column.
    row.def = {
        kind = "check",
        get = function() return IsOn(option) end,
        explain = function() return L[option.text] end,
    }
    row.backplate = row:CreateTexture(nil, "BACKGROUND")
    row.backplate:SetAtlas(ROW.backplate)
    row.backplate:SetPoint("TOPLEFT", row, "TOPLEFT", -8, 4)
    row.backplate:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 8, -4)
    row.backplate:SetAlpha(ROW.idle)
    row.label = Inked(row, "SystemFont_Med3")
    row.label:SetPoint("LEFT", row, "LEFT", ROW.inset, 0)
    row.label:SetText(L[option.label])
    local box = CreateFrame("Frame", nil, row)
    box:SetSize(ROW.cellSize, ROW.cellSize)
    box:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.boxArt = Cell(box, ROW.boxOff, ROW.cellSize)
    row.boxArt:SetPoint("CENTER")
    row.checkmark = Cell(box, ROW.check, ROW.checkSize, "OVERLAY")
    row.checkmark:SetPoint("CENTER", box, "CENTER", 1, 1)
    row:SetScript("OnEnter", function(self)
        if section.setFocus then section.setFocus(self) end
    end)
    row:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        option.set(not IsOn(option))
        RefreshRow(self)
    end)
    RefreshRow(row)
    return row
end

local function BuildSection(list)
    local base = BaseRows(list)
    section.list, section.rule = list, FindRule(list)
    -- Story Mode's rows focus with its own function (their OnEnter), which
    -- lights the row and shows its explanation; the section's rows use it too.
    section.setFocus = base[1] and base[1]:GetScript("OnEnter")
    -- The journal's ink, as Story Mode's labels have it.
    local r, g, b = 0.24, 0.16, 0.08
    if base[1] and base[1].label then r, g, b = base[1].label:GetTextColor() end
    section.ink = { r, g, b, 1 }
    section.title = Inked(list, "QuestFont_Large")
    section.title:SetJustifyH("LEFT")
    section.title:SetText(L["Settings Title"])
    section.rows = {}
    for _, option in ipairs(OPTIONS) do
        section.rows[#section.rows + 1] = CreateRow(list, option)
    end
    -- Changed elsewhere (/sm tracker, Options > AddOns) since last shown.
    list:HookScript("OnShow", RefreshRows)
    if list:GetParent() then list:GetParent():HookScript("OnShow", RefreshRows) end
end

-- Under Story Mode's last shown row; the list (and the rule beside it)
-- grows to hold the section.
-- Story Mode stacks its shown rows from the list's top, a row and a gap
-- each, so the section goes that far down.
local function LayoutSection()
    local list = section.list
    local y = 0
    for _, row in ipairs(BaseRows(list)) do
        if row:IsShown() then y = y + (y > 0 and ROW.gap or 0) + ROW.height end
    end
    if y > 0 then y = y + SECTION.top end
    section.title:ClearAllPoints()
    section.title:SetPoint("TOPLEFT", list, "TOPLEFT", ROW.inset, -y)
    section.title:SetWidth(math.max(1, (list:GetWidth() or 0) - ROW.inset))
    y = y + math.ceil(section.title:GetStringHeight() or 16) + SECTION.below
    for i, row in ipairs(section.rows) do
        if i > 1 then y = y + ROW.gap end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
        y = y + ROW.height
        RefreshRow(row)
    end
    local height = math.max(ROW.minListH, y)
    list:SetHeight(height)
    if section.rule then section.rule:SetHeight(height) end
end

local function AddToStartPage(window)
    if not (window and window.LayoutStartPage) or window.smTrackerWrapped then return end
    window.smTrackerWrapped = true
    local Layout = window.LayoutStartPage
    window.LayoutStartPage = function(parent, ...)
        local last = Layout(parent, ...)
        -- A fault here is reported but never stops Story Mode's page.
        local ok, err = pcall(function()
            if not section.list then
                local list = parent and FindSettingsList(parent)
                if list then BuildSection(list) end
            end
            if section.list then LayoutSection() end
        end)
        if not ok then geterrorhandler()(err) end
        return last
    end
end

-- ── Older Story Mode: checkboxes in the window's header ──────────────────
local CHECK = { size = 22, right = -14, top = -28, spacing = 22 }

local checks = {}

local function CreateCheckbox(frame, option, index)
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(CHECK.size, CHECK.size)
    check:SetPoint("TOPRIGHT", frame, "TOPRIGHT", CHECK.right, CHECK.top - (index - 1) * CHECK.spacing)
    check:SetFrameLevel(frame:GetFrameLevel() + 20)
    local label = check.Text or check.text or check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetFontObject("GameFontNormalSmall")
    label:ClearAllPoints()
    label:SetPoint("RIGHT", check, "LEFT", -1, 1)
    label:SetText(L[option.label])
    -- The label is part of the button: clicking it toggles too.
    check:SetHitRectInsets(-(label:GetStringWidth() + 4), 0, 0, 0)
    check:SetScript("OnShow", function(self) self:SetChecked(IsOn(option)) end)
    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        option.set(on)
    end)
    check:SetScript("OnEnter", function(self)
        local tip = SM.Tooltip or GameTooltip
        tip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        tip:ClearLines()
        tip:AddLine(L[option.label], 1, 1, 1)
        tip:AddLine(L[option.text], 1, 0.82, 0, true)
        tip:Show()
    end)
    check:SetScript("OnLeave", function() (SM.Tooltip or GameTooltip):Hide() end)
    check:SetChecked(IsOn(option))
    return check
end

local function HasSettingsPage()
    return SM.ForeverWindow and SM.ForeverWindow.LayoutStartPage ~= nil
end

local function Attach()
    if HasSettingsPage() then
        AddToStartPage(SM.ForeverWindow)
        return
    end
    local frame = _G.StoryModeFrame
    if not frame or #checks > 0 then return end
    for _, option in ipairs(OPTIONS) do
        if option.headerToo then
            checks[#checks + 1] = CreateCheckbox(frame, option, #checks + 1)
        end
    end
end

Attach()
for _, name in ipairs({ "BuildStoryWindow", "RebuildStoryWindow" }) do
    if SM[name] then hooksecurefunc(SM, name, Attach) end
end
