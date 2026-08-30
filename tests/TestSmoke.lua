-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")
local WowMock = require("WowMock")

-- Mirrors FIELD_BORDER_LEFT and FIELD_BORDER_RIGHT in src/Config.lua.
local FIELD_BORDER_LEFT = 6
local FIELD_BORDER_RIGHT = 2

---The section rule is built by the framework and never handed back to the addon, so a test
---finds it the way a player sees it, by its label.
---@param text string
---@return boolean
local function HasDivider(text)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.Label and frame.Label.GetText and frame.Label:GetText() == text then
			return true
		end
	end

	return false
end

---The reset button is a frame the framework owns, so a test reaches it by its label.
---@param label string
---@return table?
local function FindButton(label)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.GetText and frame:GetText() == label and frame.Click then
			return frame
		end
	end

	return nil
end

---The client does nothing with a prompt in the mock, so a test stands in for it.
---@param open fun()
local function AcceptConfirm(open)
	local seen
	local real = StaticPopup_Show

	StaticPopup_Show = function(which, _, _, data)
		seen = { Which = which, Data = data }
	end

	local ok, err = pcall(open)

	StaticPopup_Show = real

	if not ok then
		error(err, 0)
	end

	if not seen then
		error("no confirmation was opened")
	end

	StaticPopupDialogs[seen.Which].OnAccept(nil, seen.Data)
end

---The appearance labels are plain font strings the panel owns, so a test finds one by its words.
---@param text string
---@return table?
local function FindLabel(text)
	for _, frame in ipairs(WowMock.Frames) do
		for _, region in ipairs({ frame:GetRegions() }) do
			if region.GetText and region:GetText() == text then
				return region
			end
		end
	end
end

---Every appearance control is anchored by its left edge to the label naming it.
---@param text string
---@return table?
local function FindControlFor(text)
	local label = FindLabel(text)

	if not label then
		return nil
	end

	for _, frame in ipairs(WowMock.Frames) do
		for i = 1, frame:GetNumPoints() do
			local point, relativeTo = frame:GetPoint(i)

			if point == "LEFT" and relativeTo == label then
				return frame
			end
		end
	end
end

---A modern dropdown only exposes its choices through the generator it handed to SetupMenu, so a
---test replays that generator against a description that keeps the callbacks.
---@param dd table
---@return table<string, fun()>
local function MenuChoices(dd)
	local choices = {}
	local description = {}

	setmetatable(description, {
		__index = function()
			return function() end
		end,
	})

	description.CreateRadio = function(_, text, _, setSelected)
		choices[text] = setSelected

		return nil
	end

	dd.__menuGenerator(dd, description)

	return choices
end

---MenuChoices keys rows by their text, so two rows sharing a name would collapse to one key
---even when the list underneath still carries both. A row count catches that duplication.
---@param dd table
---@return number
local function CountMenuChoices(dd)
	local count = 0
	local description = {}

	setmetatable(description, {
		__index = function()
			return function() end
		end,
	})

	description.CreateRadio = function()
		count = count + 1

		return nil
	end

	dd.__menuGenerator(dd, description)

	return count
end

---The shared mock's own menu description has no AddInitializer, so calling a decorator directly
---would stay green even if it were never wired to the dropdown. This replays the generator
---against a description that keeps each row's captured initializer instead.
---@param dd table
---@return table<any, fun(button: table)>
local function MenuInitializers(dd)
	local initializers = {}
	local description = {}

	setmetatable(description, {
		__index = function()
			return function() end
		end,
	})

	description.CreateRadio = function(_, _, _, _, value)
		local node = {}

		node.AddInitializer = function(_, initializer)
			initializers[value] = initializer
		end

		return node
	end

	dd.__menuGenerator(dd, description)

	return initializers
end

---A stand-in for a row's font string, tracking whichever font object it was last handed.
---@param initial table?
---@return table
local function StubFontString(initial)
	local stub = { object = initial }

	function stub:GetFontObject()
		return self.object
	end

	function stub:SetFontObject(object)
		self.object = object
	end

	return stub
end

---@param region table
---@param pointName string
---@return table? relativeTo, number? x, string? relativePoint
local function PointOn(region, pointName)
	for i = 1, region:GetNumPoints() do
		local point, relativeTo, relativePoint, x = region:GetPoint(i)

		if point == pointName then
			return relativeTo, x, relativePoint
		end
	end
end

---A dropdown is taller than its label and centred on it, so an entry that stacked on the
---label above would sit on top of that dropdown.
---@param text string
---@param aboveText string
---@return boolean
local function StacksOnControl(text, aboveText)
	local label = FindLabel(text)
	local above = FindControlFor(aboveText)

	if not label or not above then
		return false
	end

	return PointOn(label, "TOP") == above
end

---The size slider sits below the colour row, so a test follows its own anchor rather than
---reading the layout code back.
---@return boolean
local function SliderFollowsColourRow()
	local slider

	for _, frame in ipairs(WowMock.Frames) do
		if frame:GetObjectType() == "Slider" then
			slider = frame
		end
	end

	local swatch = FindControlFor("Colour")

	if not slider or not swatch then
		return false
	end

	return PointOn(slider, "TOP") == swatch
end

---@return boolean
local function TestButtonSitsLeftOfReset()
	local test = FindButton("Test")
	local reset = FindButton("Reset to Defaults")

	if not test or not reset then
		return false
	end

	local point, relativeTo, relativePoint = test:GetPoint()

	return point == "RIGHT" and relativeTo == reset and relativePoint == "LEFT"
end

smoke.Run("MiniHealerRange", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")
		fw.truthy(HasDivider("SETTINGS"), "the settings section rule under the header")
		fw.truthy(SliderFollowsColourRow(), "the font size slider sits below the colour row")
		fw.truthy(StacksOnControl("Outline", "Font"), "the outline row clears the font dropdown")
		fw.truthy(StacksOnControl("Colour", "Outline"), "the colour row clears the outline dropdown")
		fw.not_nil(FindControlFor("Colour"), "the colour swatch hangs off its label")
		fw.truthy(TestButtonSitsLeftOfReset(), "the test button sits left of the reset button")

		local entries = { "Message", "Font", "Outline", "Colour" }
		local labelAnchor, labelX = PointOn(FindLabel("Message"), "LEFT")

		for _, text in ipairs(entries) do
			local anchor, x = PointOn(FindLabel(text), "LEFT")

			fw.eq(anchor, labelAnchor, text .. " label shares the label column's anchor")
			fw.eq(x, labelX, text .. " label shares the label column")
		end

		local _, controlX = PointOn(FindControlFor("Font"), "LEFT")

		for _, text in ipairs(entries) do
			local control = FindControlFor(text)
			local relativeTo, x, relativePoint = PointOn(control, "LEFT")

			-- Every control measures from its label's own left edge, so one offset puts them
			-- all in the same column whatever the labels are worth.
			fw.eq(relativeTo, FindLabel(text), text .. " control hangs off its own label")
			fw.eq(relativePoint, "LEFT", text .. " control measures from its label's left edge")

			if text == "Message" then
				fw.eq(x - FIELD_BORDER_LEFT, controlX, "the message field's border sits on the control column")
			else
				fw.eq(x, controlX, text .. " control shares the control column")
			end
		end

		local fontWidth = FindControlFor("Font"):GetWidth()

		fw.eq(FindControlFor("Outline"):GetWidth(), fontWidth, "both dropdowns are the same length")
		fw.eq(
			FindControlFor("Message"):GetWidth() + FIELD_BORDER_LEFT + FIELD_BORDER_RIGHT,
			fontWidth,
			"the message field draws the same length as a dropdown"
		)

		local db = _G["MiniHealerRangeDB"]
		db.FontSize = 99
		db.Enabled.Arena = false

		local resetBtn = FindButton("Reset to Defaults")
		fw.not_nil(resetBtn, "reset button exists")

		AcceptConfirm(function()
			resetBtn:Click()
		end)

		fw.eq(db.FontSize, context.Addon.Config.DbDefaults.FontSize, "reset restored FontSize")
		fw.eq(db.Enabled.Arena, context.Addon.Config.DbDefaults.Enabled.Arena, "reset restored Enabled.Arena")

		local fontDdl = FindControlFor("Font")
		local newFontName = "MiniHealerRange Test Face"

		fw.not_nil(fontDdl, "the font dropdown exists")

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "LibSharedMedia resolves under the mock")

		lsm:Register("font", newFontName, "Fonts\\MiniHealerRangeTestFace.ttf")

		fw.no_key(MenuChoices(fontDdl), newFontName, "the registration alone doesn't rebuild the list yet")

		WowMock.RunTimers()

		fw.has_key(MenuChoices(fontDdl), newFontName, "the font appears once the coalesced refresh runs")

		local secondFontName = "MiniHealerRange Second Test Face"
		local thirdFontName = "MiniHealerRange Third Test Face"

		lsm:Register("font", secondFontName, "Fonts\\MiniHealerRangeSecondTestFace.ttf")
		lsm:Register("font", thirdFontName, "Fonts\\MiniHealerRangeThirdTestFace.ttf")

		fw.eq(WowMock.RunTimers(), 1, "two registrations in one frame coalesce into a single refresh")
		fw.has_key(MenuChoices(fontDdl), secondFontName, "the first of the pair lands after the one refresh")
		fw.has_key(MenuChoices(fontDdl), thirdFontName, "the second of the pair lands after the same refresh")

		local rowsBeforeSharedFile = CountMenuChoices(fontDdl)
		local sharedFile = "Fonts\\MiniHealerRangeSharedFace.ttf"

		lsm:Register("font", "MiniHealerRange Shared Name One", sharedFile)
		lsm:Register("font", "MiniHealerRange Shared Name Two", sharedFile)

		WowMock.RunTimers()

		fw.eq(
			CountMenuChoices(fontDdl) - rowsBeforeSharedFile,
			1,
			"two names resolving to one file add a single row"
		)

		local _, initializer = next(MenuInitializers(fontDdl))
		fw.not_nil(initializer, "the font dropdown wires a row initializer")

		local stockFont = {}
		local button = { fontString = StubFontString(stockFont) }

		initializer(button)

		local previewed = button.fontString:GetFontObject()
		fw.truthy(previewed ~= nil and previewed ~= stockFont, "the row previews the font it names")

		-- A plain CreateFont object has no __members, and an incomplete family has fewer than
		-- five, so this one count proves both the family route and the full alphabet list.
		fw.eq(previewed.__members and #previewed.__members or 0, 5, "the preview is a family declaring all five alphabets")

		local capturedStock = button.MiniHealerRangeStockFont
		fw.eq(capturedStock, stockFont, "the row's original face is captured before the preview is applied")

		initializer(button)
		fw.eq(button.MiniHealerRangeStockFont, capturedStock, "a reopened row keeps the face it first captured")

		-- Fetch would answer this one face for every name, leaving a single row naming a raw path.
		lsm:SetGlobal("font", newFontName)
		lsm:Register("font", "MiniHealerRange Overridden Face", "Fonts\\MiniHealerRangeOverriddenFace.ttf")

		WowMock.RunTimers()

		local overridden = MenuChoices(fontDdl)

		fw.has_key(overridden, secondFontName, "a global font override leaves the other faces listed")
		fw.has_key(overridden, "MiniHealerRange Overridden Face", "the face registered under the override lands too")

		lsm:SetGlobal("font", nil)
	end,
})
