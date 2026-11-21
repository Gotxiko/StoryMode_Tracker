local addonName, SM = ...

-- =============================================================================
-- Tracker stack (WoW Forever)
-- Blocks that sit at the top of the quest tracker, one under the other, with
-- the quest tracker pushed down by all of them together. The same design as
-- ParchmentUI's (Modules/TrackerStack.lua): a block isn't a module of the
-- tracker (a module would taint the tracker's own updates); it takes the
-- tracker's place and moves the tracker down by its height, and puts it back
-- when it goes away.
--
-- Only one addon may move the tracker, or their SetPoint hooks would keep
-- reading each other's push as the tracker's new home. So when ParchmentUI
-- shares its stack (_G.ParchmentUI_TrackerStack), Story Mode's blocks join
-- that one, and this copy is never used.
--
-- The quest tracker is FlareUI's when FlareUI replaces Blizzard's (Blizzard's
-- is then "parked", scaled to almost nothing), otherwise Blizzard's
-- ObjectiveTrackerFrame.
-- =============================================================================

if not (SM.Client and SM.Client.isForever) then return end

local GAP = 6 -- between two blocks, and between the last block and the quest tracker

local Own = {}

local blocks = {}      -- { frame =, order =, shown =, height =, onMoved = }, sorted by order
local pushed           -- { frame = the tracker, points = its own anchors, offset = how far it's moved }
local applying = false -- we're moving the tracker ourselves (its SetPoint hook ignores that)
local pendingMove = false
local hooked = {}

local function Parked(f) return f:GetScale() < 0.01 or f:GetAlpha() == 0 end

-- The quest tracker on screen: FlareUI's while it stands in for Blizzard's.
function Own.Target()
    local blizz = _G.ObjectiveTrackerFrame
    local flare = _G.FlareUI_ObjectiveTracker
    if flare and (not blizz or Parked(blizz)) then return flare end
    return blizz
end

-- Blizzard's tracker is the game's own frame: only moved out of combat.
local function CanMove(f)
    return f ~= _G.ObjectiveTrackerFrame or not InCombatLockdown()
end

-- Edit Mode frames carry the plain widget methods as *Base; those don't
-- touch Edit Mode's own state.
local function ClearPoints(f) (f.ClearAllPointsBase or f.ClearAllPoints)(f) end
local function SetPointRaw(f, ...) (f.SetPointBase or f.SetPoint)(f, ...) end

local function ReadPoints(f)
    local pts = {}
    for i = 1, f:GetNumPoints() do
        local p, rel, rp, x, y = f:GetPoint(i)
        pts[i] = { p, rel or f:GetParent(), rp, x or 0, y or 0 }
    end
    return pts
end

local function ApplyOffset(offset)
    local f = pushed.frame
    if pushed.offset == offset then return true end
    if not CanMove(f) then pendingMove = true return false end
    applying = true
    ClearPoints(f)
    for _, p in ipairs(pushed.points) do SetPointRaw(f, p[1], p[2], p[3], p[4], p[5] - offset) end
    applying = false
    pushed.offset = offset
    return true
end

local function Release()
    if not pushed then return end
    if ApplyOffset(0) then pushed = nil end
end

local Layout

-- Someone else (Edit Mode, the tracker's own addon) placed the tracker:
-- that's its new home. Read it on the next frame and make room again.
local function OnTrackerMoved(f)
    if applying or not pushed or pushed.frame ~= f then return end
    C_Timer.After(0, function()
        if not pushed or pushed.frame ~= f or applying then return end
        pushed.points = ReadPoints(f)
        pushed.offset = 0
        Layout()
        for _, b in ipairs(blocks) do
            if b.onMoved then b.onMoved() end
        end
    end)
end

local function Hook(f)
    if hooked[f] then return end
    hooked[f] = true
    hooksecurefunc(f, "SetPoint", OnTrackerMoved)
    if f.SetPointBase then hooksecurefunc(f, "SetPointBase", OnTrackerMoved) end
end

-- Places every shown block where the tracker stands, one under the other,
-- and moves the tracker below them all.
function Layout()
    local list = {}
    for _, b in ipairs(blocks) do
        if b.shown then list[#list + 1] = b end
    end
    if #list == 0 then Release() return end

    local f = Own.Target()
    if pushed and pushed.frame ~= f then
        Release()
        if pushed then return end -- can't put the old one back yet (combat)
    end
    if not f or f:GetNumPoints() == 0 or not (f:GetLeft() and f:GetTop()) then
        -- No quest tracker on screen: the blocks stand alone, top right.
        local prev
        for _, b in ipairs(list) do
            local B = b.frame
            B:SetScale(1)
            B:ClearAllPoints()
            if prev then
                B:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -GAP)
            else
                B:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -220)
            end
            prev = B
        end
        return
    end
    if not pushed then
        pushed = { frame = f, points = ReadPoints(f), offset = 0 }
        Hook(f)
    end
    -- Same scale as the tracker. The blocks go where the tracker's top
    -- corner is without our push; on the right half of the screen they line
    -- up with its right edge, so a wider block grows inward.
    local scale = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local top = f:GetTop() + pushed.offset
    local cx = (f:GetLeft() + f:GetRight()) / 2
    local onRight = cx * f:GetEffectiveScale() > UIParent:GetWidth() * UIParent:GetEffectiveScale() / 2
    local total = 0
    for _, b in ipairs(list) do
        local B = b.frame
        B:SetScale(scale)
        B:ClearAllPoints()
        if onRight then
            B:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", f:GetRight(), top - total)
        else
            B:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", f:GetLeft(), top - total)
        end
        total = total + b.height + GAP
    end
    ApplyOffset(total)
end

-- A block joins the stack. order: lower is higher up.
function Own.Register(frame, order, onMoved)
    local b = { frame = frame, order = order or 50, shown = false, height = 0, onMoved = onMoved }
    blocks[#blocks + 1] = b
    table.sort(blocks, function(x, y) return x.order < y.order end)
    return b
end

-- The block is shown (at this height) or not.
function Own.Set(b, shown, height)
    b.shown = shown and true or false
    b.height = height or b.height
    if b.shown then
        Layout()
        b.frame:Show()
    else
        if b.frame:IsShown() then b.frame:Hide() end
        Layout()
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
    if not pendingMove then return end
    pendingMove = false
    Layout()
end)

-- ParchmentUI's stack when it shares one, else this copy. Asked when the
-- first block registers, after every addon has loaded.
function SM.GetTrackerStack()
    local shared = _G.ParchmentUI_TrackerStack
    if type(shared) == "table" and shared.Register and shared.Set and shared.Target then
        return shared
    end
    return Own
end
