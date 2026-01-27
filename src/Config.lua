local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework
local verticalSpacing = mini.VerticalSpacing
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
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local description = mini:TextLine({
		Parent = panel,
		Text = "Increase your awareness.",
	})

	description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

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

	arenaChkBox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", -4, -verticalSpacing)

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

	local textSizeSlider = mini:Slider({
		Parent = panel,
		LabelText = "Size",
		Min = 10,
		Max = 100,
		Step = 1,
		GetValue = function()
			return db.FontSize
		end,
		SetValue = function(value)
			db.FontSize = mini:ClampInt(value, 10, 100, dbDefaults.FontSize)
			addon:Refresh()
		end,
	})

	textSizeSlider.Slider:SetPoint("TOPLEFT", arenaChkBox, "BOTTOMLEFT", 0, -verticalSpacing * 3)

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
