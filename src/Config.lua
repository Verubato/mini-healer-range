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
-- The legacy dropdown template draws its field in from the frame's own left edge.
local LEGACY_DROPDOWN_INSET = 16
-- The flattened field's border draws outside the box's own frame on both sides.
local FIELD_BORDER_LEFT = 6
local FIELD_BORDER_RIGHT = 2
-- Only the client's own locale takes the previewed file, so text in another script still
-- renders from the game's own files.
local FAMILY_ALPHABETS = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }
local LOCALE_ALPHABETS = {
	koKR = "korean",
	zhCN = "simplifiedchinese",
	zhTW = "traditionalchinese",
	ruRU = "russian",
}
-- The preview rows are menu rows, so their text matches the menu's own size.
local PREVIEW_FONT_SIZE = 13
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
-- The dropdown holds these tables, so they are refilled in place rather than replaced.
local fontItems = {}
local fontNames = {}
local fontsDropdown
local fontsMediaSubscribed = false
local fontsRefreshQueued = false
-- Cached per file, since CreateFontFamily needs a unique name per object and dropdown rows ask
-- for the same handful of files over and over.
local previewFontObjects = {}
local previewFontObjectCount = 0
---@class Config
local M = {
	DbDefaults = dbDefaults,
}
addon.Config = M

---Refills the font lists in place from LibSharedMedia, falling back to the client's own faces
---only when nothing has registered anything at all.
local function RefillFontLists()
	wipe(fontItems)
	wipe(fontNames)

	local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
	-- Fetch answers one override file for every name once an addon sets a global font.
	local hash = lsm and lsm:HashTable("font")

	if hash then
		for _, name in ipairs(lsm:List("font") or {}) do
			local file = hash[name]

			if file and not fontNames[file] then
				fontItems[#fontItems + 1] = file
				fontNames[file] = name
			end
		end
	end

	if #fontItems == 0 then
		for _, file in ipairs(builtinFontItems) do
			fontItems[#fontItems + 1] = file
			fontNames[file] = builtinFontNames[file]
		end
	end

	table.sort(fontItems, function(a, b)
		return (fontNames[a] or a) < (fontNames[b] or b)
	end)
end

---Runs the list refresh once at the end of the frame however many times it is asked for in one,
---since LibSharedMedia fires once per registered entry and a media pack registers its whole set
---inside a single frame.
local function QueueFontListsChanged()
	if fontsRefreshQueued then
		return
	end

	fontsRefreshQueued = true

	C_Timer.After(0, function()
		fontsRefreshQueued = false
		RefillFontLists()

		if fontsDropdown then
			fontsDropdown:MiniRefresh()
		end
	end)
end

---Fonts keep arriving for as long as media addons keep loading, which is routinely after this
---panel was built.
local function EnsureFontMediaSubscription()
	if fontsMediaSubscribed then
		return
	end

	local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)

	if not lsm or not lsm.RegisterCallback then
		return
	end

	fontsMediaSubscribed = true

	lsm.RegisterCallback(M, "LibSharedMedia_Registered", QueueFontListsChanged)
end

---One member per alphabet the client distinguishes.
---@param file string
---@return table[] members
local function FamilyMembers(file)
	local override = LOCALE_ALPHABETS[GetLocale()] or "roman"
	local members = {}

	for _, alphabet in ipairs(FAMILY_ALPHABETS) do
		local memberFile = file

		if alphabet ~= override and GameFontNormal and GameFontNormal.GetFontObjectForAlphabet then
			local gameObject = GameFontNormal:GetFontObjectForAlphabet(alphabet)

			memberFile = (gameObject and gameObject:GetFont()) or file
		end

		members[#members + 1] = {
			alphabet = alphabet,
			file = memberFile,
			height = PREVIEW_FONT_SIZE,
			flags = "",
		}
	end

	return members
end

---A font object wearing this file's own face, for a dropdown row that previews the font it names.
---SetFont answers false for a file the client is still loading, leaving the object undefined for
---good.
---@param file string
---@return table? object
local function PreviewFontObject(file)
	if not CreateFontFamily then
		return nil
	end

	local object = previewFontObjects[file]

	if not object then
		previewFontObjectCount = previewFontObjectCount + 1

		object = CreateFontFamily(addonName .. "FontPreview" .. previewFontObjectCount, FamilyMembers(file))
		previewFontObjects[file] = object
	end

	return object
end

---Previews the font each dropdown row names. Menu rows are pooled and reused across openings.
---@param button table
---@param file string
local function DecorateFontRow(button, file)
	local text = button.fontString

	if not text then
		return
	end

	if button.MiniHealerRangeStockFont == nil then
		button.MiniHealerRangeStockFont = text:GetFontObject() or false
	end

	local preview = PreviewFontObject(file)

	if preview then
		text:SetFontObject(preview)
	elseif button.MiniHealerRangeStockFont then
		text:SetFontObject(button.MiniHealerRangeStockFont)
	end
end

function M:Init()
	-- A styled button clashes with the stock Blizzard art around it in the settings screen.
	mini:SetCustomStyling(true, { Button = false })

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
		Divider = true,
		Test = {
			OnClick = function()
				addon:ToggleTest()
			end,
		},
		Reset = {
			OnAccept = function()
				mini:ResetSavedVars(dbDefaults)
				addon:Refresh()
			end,
		},
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

	arenaChkBox:SetPoint("TOPLEFT", header.Anchor, "BOTTOMLEFT", 0, -verticalSpacing)

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

	local appearanceDivider = mini:Divider({
		Parent = panel,
		Text = "Appearance",
	})

	appearanceDivider:SetPoint("TOPLEFT", arenaChkBox, "BOTTOMLEFT", 0, -verticalSpacing * 2)
	appearanceDivider:SetPoint("RIGHT", panel, "RIGHT", 0, 0)

	-- Every entry spends this budget, so their right edges line up down the section.
	local entryWidth = columnStep * 2

	---Starts an entry on the section's left edge, clear of whatever control sits above it.
	---@param region table
	---@param above table
	---@param gap number
	local function StackEntry(region, above, gap)
		region:SetPoint("TOP", above, "BOTTOM", 0, -gap)
		region:SetPoint("LEFT", appearanceDivider, "LEFT", 0, 0)
	end

	---@param text string
	---@return table
	local function CreateLabel(text)
		local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		label:SetText(text)

		return label
	end

	local messageLabel = CreateLabel("Message")
	local fontLabel = CreateLabel("Font")
	local outlineLabel = CreateLabel("Outline")
	local colourLabel = CreateLabel("Colour")

	-- The widest label decides where every control starts, so the labels share one column and
	-- the controls share another.
	local labelColumn = 0

	for _, label in ipairs({ messageLabel, fontLabel, outlineLabel, colourLabel }) do
		labelColumn = math.max(labelColumn, label:GetStringWidth())
	end

	labelColumn = labelColumn + horizontalSpacing

	local controlWidth = math.max(1, entryWidth - labelColumn)

	---Puts a control in the second column, level with the label that names it.
	---@param control table
	---@param label table
	---@param inset number? backed out of the column so the control's drawn edge lands on it
	local function AttachControl(control, label, inset)
		control:SetPoint("LEFT", label, "LEFT", labelColumn - (inset or 0), 0)
	end

	local messageEditBox = mini:EditBox({
		Parent = panel,
		GetValue = function()
			return db.Message
		end,
		SetValue = function(value)
			db.Message = tostring(value)
			addon:Refresh()
		end,
	})

	StackEntry(messageLabel, appearanceDivider, verticalSpacing)
	-- The box is inset so its border, not its frame, lands on the column.
	messageEditBox.EditBox:SetPoint("LEFT", messageLabel, "LEFT", labelColumn + FIELD_BORDER_LEFT, 0)
	messageEditBox.EditBox:SetWidth(math.max(1, controlWidth - FIELD_BORDER_LEFT - FIELD_BORDER_RIGHT))

	RefillFontLists()

	local fontDdl, fontIsModern = mini:Dropdown({
		Parent = panel,
		Items = fontItems,
		Width = controlWidth,
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
		DecorateItem = DecorateFontRow,
	})

	fontsDropdown = fontDdl
	EnsureFontMediaSubscription()

	local dropdownInset = fontIsModern and 0 or LEGACY_DROPDOWN_INSET

	StackEntry(fontLabel, messageEditBox.EditBox, verticalSpacing)
	AttachControl(fontDdl, fontLabel, dropdownInset)

	local outlineDdl = mini:Dropdown({
		Parent = panel,
		Items = fontFlagItems,
		Width = controlWidth,
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

	StackEntry(outlineLabel, fontDdl, verticalSpacing)
	AttachControl(outlineDdl, outlineLabel, dropdownInset)

	local colourSwatch = mini:ColorSwatch({
		Parent = panel,
		TooltipTitle = "Colour",
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

	StackEntry(colourLabel, outlineDdl, verticalSpacing)
	AttachControl(colourSwatch, colourLabel)

	local textSizeSlider = mini:Slider({
		Parent = panel,
		LabelText = "Size",
		Min = 10,
		-- it seems blizzard have a hard cap at 120
		Max = 120,
		Step = 1,
		Width = entryWidth,
		GetValue = function()
			return db.FontSize
		end,
		SetValue = function(value)
			db.FontSize = mini:ClampInt(value, 10, 120, dbDefaults.FontSize)
			addon:Refresh()
		end,
	})

	StackEntry(textSizeSlider.Slider, colourSwatch, verticalSpacing + mini.SliderChipOverhang)

	mini:RegisterSlashCommand(category, panel, {
		"/minihr",
		"/mhr",
	})
end
