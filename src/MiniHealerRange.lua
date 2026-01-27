local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework
local testMode = false
local frame
local updateInterval = 0.5
local draggable
local text
local ticker
local LRC = LibStub and LibStub("LibRangeCheck-3.0", true)
---@type Db
local db
---@type Db
local dbDefaults = addon.Config.DbDefaults

local function ApplyPosition()
	local point = db.Point or dbDefaults.Point
	local relativePoint = db.RelativePoint or dbDefaults.RelativePoint
	local relativeTo = (db.RelativeTo and _G[db.RelativeTo]) or UIParent
	local x = (type(db.X) == "number") and db.X or dbDefaults.X
	local y = (type(db.Y) == "number") and db.Y or dbDefaults.Y

	draggable:ClearAllPoints()
	draggable:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function SavePosition()
	local point, relativeTo, relativePoint, x, y = draggable:GetPoint(1)

	db.Point = point
	db.RelativeTo = relativeTo
	db.RelativePoint = relativePoint
	db.X = x
	db.Y = y
end

local function ResizeDraggableToText()
	local w = text:GetStringWidth() or 0
	local h = text:GetStringHeight() or 0

	if w < 1 then
		w = 1
	end
	if h < 1 then
		h = 1
	end

	draggable:SetSize(w + (db.PaddingX or 0) * 2, h + (db.PaddingY or 0) * 2)
end

local function UpdateText()
	text:SetText(db.Message)

	ResizeDraggableToText()
end

local function UpdateFontStyle()
	text:SetFont(db.FontPath or "Fonts\\FRIZQT__.TTF", db.FontSize or 18, db.FontFlags or "OUTLINE")

	local c = db.FontColor
	local r, g, b, a = 1, 1, 1, 1

	if type(c) == "table" then
		r = (type(c.R) == "number") and c.R or r
		g = (type(c.G) == "number") and c.G or g
		b = (type(c.B) == "number") and c.B or b
		a = (type(c.A) == "number") and c.A or a
	end

	text:SetTextColor(r, g, b, a)
end

local function StopTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function IsHealer(unit)
	return UnitGroupRolesAssigned(unit) == "HEALER"
end

local function GetRangeMax(unit)
	if LRC then
		local _, maxRange = LRC:GetRange(unit)
		return maxRange
	end

	return nil
end

local function Within25Yards(unit)
	local max = GetRangeMax(unit)
	return max and max <= 25
end

local function Within40Yards(unit)
	local max = GetRangeMax(unit)
	return max and max <= 40
end

local function FindClosestHealer()
	local inRaid = IsInRaid()
	local prefix = inRaid and "raid" or "party"
	local count = inRaid and (MAX_RAID_MEMBERS or 40) or (MAX_PARTY_MEMBERS or 4)
	local healer = nil
	-- 25 yards for evokers
	local healerWithin25Yards = nil
	local healerWithin40Yards = nil

	for i = 1, count do
		local unit = prefix .. i

		if IsHealer(unit) then
			healer = unit

			if Within40Yards(unit) then
				healerWithin40Yards = unit

				if Within25Yards(unit) then
					healerWithin25Yards = unit
				end
			end
		end
	end

	return healerWithin25Yards or healerWithin40Yards or healer
end

local function ShouldRun()
	if testMode then
		return true
	end

	if IsHealer("player") then
		return false
	end

	local _, instanceType = IsInInstance()

	if instanceType == "arena" then
		return db.Enabled.Arena
	end

	if instanceType == "pvp" then
		return db.Enabled.Battlegrounds
	end

	if instanceType == "party" or instanceType == "scenario" then
		return db.Enabled.Dungeons
	end

	return false
end

local function Run()
	if not ShouldRun() then
		StopTicker()
		draggable:Hide()
		return
	end

	if testMode then
		draggable:Show()
		return
	end

	local healer = FindClosestHealer()

	if not healer then
		StopTicker()
		draggable:Hide()
		return
	end

	local inRange = UnitInRange(healer)

	if mini:IsSecret(inRange) then
		draggable:SetAlphaFromBoolean(inRange, 0, 1)
		draggable:Show()
	else
		if inRange then
			draggable:Hide()
		else
			draggable:Show()
		end
	end
end

local function EnsureTicker()
	if ticker then
		return
	end

	ticker = C_Timer.NewTicker(updateInterval, Run)
end

local function OnEvent(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		if testMode then
			testMode = false
			addon:Refresh()
			return
		end
	end

	EnsureTicker()
	Run()
end

local function OnAddonLoaded()
	addon.Config:Init()

	db = mini:GetSavedVars(dbDefaults)

	draggable = CreateFrame("Frame", addonName .. "Frame", UIParent)
	draggable:SetClampedToScreen(true)
	draggable:EnableMouse(true)
	draggable:SetMovable(true)

	-- let us control the position via saved vars
	if draggable.SetDontSavePosition then
		draggable:SetDontSavePosition(true)
	end

	draggable:RegisterForDrag("LeftButton")
	draggable:Hide()

	draggable:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)

	draggable:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)

	ApplyPosition()

	text = draggable:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", draggable, "CENTER", 0, 0)
	text:Show()

	-- must apply font before setting the text
	UpdateFontStyle()
	UpdateText()

	frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")

	frame:SetScript("OnEvent", OnEvent)
end

function addon:Refresh()
	UpdateFontStyle()
	UpdateText()
	Run()
end

function addon:ToggleTest()
	testMode = not testMode
	addon:Refresh()
end

mini:WaitForAddonLoad(OnAddonLoaded)
