local addonName, T = ...

-- =============================================================================
-- Story Mode - Tracker: settings page
-- A page under Options > AddOns: the tracker's options (the same ones as its
-- section on Story Mode's settings page, WindowOptions.lua), each
-- with what it does under it, then a preview of every look a quest can have
-- on the tracker.
-- =============================================================================

local SM = T.Base
if not (SM and SM.Client and SM.Client.isForever) then return end
if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end

local L = T.L

local PAGE = { left = 16, top = 16, textW = 560, optionGap = 14, sectionGap = 22 }

local panel = CreateFrame("Frame")
panel.name = L["Settings Title"]

local checks = {}

local function Build()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAGE.left, -PAGE.top)
    title:SetText(L["Settings Title"])
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
        or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetWidth(PAGE.textW)
    sub:SetJustifyH("LEFT")
    sub:SetText(L["Settings Subtitle"] .. (version and ("  |cff808080v" .. version .. "|r") or ""))

    local anchor, gap = sub, PAGE.sectionGap
    for _, option in ipairs(T.TrackerOptions or {}) do
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetSize(26, 26)
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == sub and -2 or 0, -gap)
        local label = check.Text or check.text or check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetFontObject("GameFontNormal")
        label:ClearAllPoints()
        label:SetPoint("LEFT", check, "RIGHT", 2, 1)
        label:SetText(L[option.label])
        check:SetHitRectInsets(0, -(label:GetStringWidth() + 4), 0, 0)
        check:SetScript("OnClick", function(self)
            local on = self:GetChecked() and true or false
            PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            option.set(on)
        end)
        local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 28, 0)
        text:SetWidth(PAGE.textW - 28)
        text:SetJustifyH("LEFT")
        text:SetText(L[option.text])
        checks[#checks + 1] = { check = check, option = option }
        anchor, gap = check, text:GetStringHeight() + PAGE.optionGap
    end

    -- The preview.
    local head = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 2, -(gap + PAGE.sectionGap - PAGE.optionGap))
    head:SetText(L["Preview Title"])
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
    note:SetWidth(PAGE.textW)
    note:SetJustifyH("LEFT")
    note:SetText(L["Preview Text"])
    local preview = CreateFrame("Frame", nil, panel)
    preview:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -12)
    preview:SetWidth(PAGE.textW)
    local height = T.BuildTrackerPreview and T.BuildTrackerPreview(preview) or 1
    preview:SetHeight(height)
end

panel:SetScript("OnShow", function()
    if not panel.built then
        panel.built = true
        Build()
    end
    -- Changed elsewhere (the Story Mode window, /sm tracker) since last shown.
    for _, c in ipairs(checks) do c.check:SetChecked(c.option.get() and true or false) end
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)
T.SettingsCategory = category
