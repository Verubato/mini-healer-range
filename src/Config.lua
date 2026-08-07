local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework
local horizontalSpacing = mini.HorizontalSpacing
local verticalSpacing = mini.VerticalSpacing
local builtinFontItems = {
	"Fonts\\FRIZQT__.TTF",
	"Fonts\\ARIALN.TTF",
	"Fonts\\MORPHEUS.TTF",
	"Fonts\\SKURRI.TTF",
	"Fonts\\MYRIADPRO-BOLD.TTF",
}
local builtinFontNames = {
	["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata",
	["Fonts\\ARIALN.TTF"] = "Arial Narrow",
	["Fonts\\MORPHEUS.TTF"] = "Morpheus",
	["Fonts\\SKURRI.TTF"] = "Skurri",
	["Fonts\\MYRIADPRO-BOLD.TTF"] = "Myriad Pro",
}
local fontFlagItems = { "OUTLINE", "THICKOUTLINE", "MONOCHROME", "" }
local fontFlagNames = {
	OUTLINE = "Outline",
	THICKOUTLINE = "Thick Outline",
	MONOCHROME = "Monochrome",
	[""] = "None",
}
---@class Db
local db
---@class Db
local dbDefaults = {
	Version = 1,
	Point = "TOP",
	RelativeTo = "UIParent",
	RelativePoint = "TOP",
	X = 0,
	Y = -200,
	Message = "No healer in range",
	FontPath = "Fonts\\FRIZQT__.TTF",
	FontSize = 24,
	FontFlags = "OUTLINE",
	FontColor = {
		R = 1,
		G = 0,
		B = 0,
		A = 1,
	},
	PaddingX = 10,
	PaddingY = 10,
	Locked = false,

	Enabled = {
		Arena = true,
		Battlegrounds = false,
		Dungeons = true,
	},
}
---@class Config
local M = {
	DbDefaults = dbDefaults,
}
addon.Config = M

local function GetFontLists()
	local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)

	if lsm then
		local items = {}
		local names = {}

		for _, name in ipairs(lsm:List("font") or {}) do
			local file = lsm:Fetch("font", name)

			if file then
				items[#items + 1] = file
				names[file] = name
			end
		end

		if #items > 0 then
			return items, names
		end
	end

	return builtinFontItems, builtinFontNames
end

function M:Init()
	db = mini:GetSavedVars(dbDefaults)

	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = mini:AddCategory(panel)

	if not category then
		return
	end

	local columns = 4
	local columnStep = mini:ColumnWidth(columns, 0, 0)
	local header = mini:PanelHeader({
		Parent = panel,
		Description = "Increase your awareness.",
	})

	local arenaChkBox = mini:Checkbox({
		Parent = panel,
		LabelText = "Arena",
		Tooltip = "Whether to enable/disable in arena.",
		GetValue = function()
			return db.Enabled.Arena
		end,
		SetValue = function(enabled)
			db.Enabled.Arena = enabled
			addon:Refresh()
		end,
	})

	arenaChkBox:SetPoint("TOPLEFT", header.Anchor, "BOTTOMLEFT", -4, -verticalSpacing)

	local bgChkBox = mini:Checkbox({
		Parent = panel,
		LabelText = "Battlegrounds",
		Tooltip = "Whether to enable/disable in battlegrounds.",
		GetValue = function()
			return db.Enabled.Battlegrounds
		end,
		SetValue = function(enabled)
			db.Enabled.Battlegrounds = enabled
			addon:Refresh()
		end,
	})

	bgChkBox:SetPoint("LEFT", arenaChkBox, "LEFT", columnStep, 0)

	local dungeonsChkBox = mini:Checkbox({
		Parent = panel,
		LabelText = "Dungeons",
		Tooltip = "Whether to enable/disable in dungeons.",
		GetValue = function()
			return db.Enabled.Dungeons
		end,
		SetValue = function(enabled)
			db.Enabled.Dungeons = enabled
			addon:Refresh()
		end,
	})

	dungeonsChkBox:SetPoint("LEFT", bgChkBox, "LEFT", columnStep, 0)

	local lockChkBox = mini:Checkbox({
		Parent = panel,
		LabelText = "Lock",
		Tooltip = "Prevents the frame from being dragged.",
		GetValue = function()
			return db.Locked
		end,
		SetValue = function(enabled)
			db.Locked = enabled
			addon:Refresh()
		end,
	})

	lockChkBox:SetPoint("LEFT", dungeonsChkBox, "LEFT", columnStep, 0)

	local messageEditBox = mini:EditBox({
		Parent = panel,
		LabelText = "Message",
		Width = columnStep * 2,
		GetValue = function()
			return db.Message
		end,
		SetValue = function(value)
			db.Message = tostring(value)
			addon:Refresh()
		end,
	})

	messageEditBox.Label:SetPoint("TOPLEFT", arenaChkBox, "BOTTOMLEFT", 0, -verticalSpacing)
	messageEditBox.EditBox:SetPoint("LEFT", messageEditBox.Label, "RIGHT", horizontalSpacing, 0)

	local textSizeSlider = mini:Slider({
		Parent = panel,
		LabelText = "Size",
		Min = 10,
		-- it seems blizzard have a hard cap at 120
		Max = 120,
		Step = 1,
		GetValue = function()
			return db.FontSize
		end,
		SetValue = function(value)
			db.FontSize = mini:ClampInt(value, 10, 120, dbDefaults.FontSize)
			addon:Refresh()
		end,
	})

	textSizeSlider.Slider:SetPoint("TOPLEFT", messageEditBox.Label, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	local fontItems, fontNames = GetFontLists()

	local fontDdl = mini:Dropdown({
		Parent = panel,
		LabelText = "Font",
		Items = fontItems,
		Width = columnStep * 2,
		GetValue = function()
			return db.FontPath
		end,
		SetValue = function(value)
			db.FontPath = value
			addon:Refresh()
		end,
		GetText = function(value)
			return fontNames[value] or value
		end,
	})

	fontDdl.Label:SetPoint("TOPLEFT", textSizeSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing * 2)

	local outlineDdl = mini:Dropdown({
		Parent = panel,
		LabelText = "Outline",
		Items = fontFlagItems,
		Width = columnStep,
		GetValue = function()
			return db.FontFlags
		end,
		SetValue = function(value)
			db.FontFlags = value
			addon:Refresh()
		end,
		GetText = function(value)
			return fontFlagNames[value] or value
		end,
	})

	outlineDdl.Label:SetPoint("LEFT", fontDdl, "RIGHT", horizontalSpacing * 2, 0)

	local colourSwatch = mini:ColorSwatch({
		Parent = panel,
		LabelText = "Colour",
		Tooltip = "Click to change the font colour.",
		GetValue = function()
			local c = db.FontColor
			return c.R, c.G, c.B, c.A
		end,
		SetValue = function(r, g, b, a)
			local c = db.FontColor
			c.R, c.G, c.B, c.A = r, g, b, a
		end,
		OnChange = function()
			addon:Refresh()
		end,
	})

	colourSwatch:SetPoint("LEFT", outlineDdl, "RIGHT", horizontalSpacing * 2, 0)

	local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	testBtn:SetSize(120, 26)
	testBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, verticalSpacing)
	testBtn:SetText("Test")
	testBtn:SetScript("OnClick", function()
		addon:ToggleTest()
	end)

	mini:RegisterSlashCommand(category, panel, {
		"/minihr",
		"/mhr",
	})
end
