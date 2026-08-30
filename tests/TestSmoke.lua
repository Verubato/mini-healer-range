-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")
local WowMock = require("WowMock")

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

---Finds the control an appearance entry was built around, by the label the widget kept on it.
---@param text string
---@return table?
local function FindLabelled(text)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.Label and frame.Label.GetText and frame.Label:GetText() == text then
			return frame
		end
	end
end

---A dropdown is taller than its label and centred on it, so an entry that stacked on the
---label above would sit on top of that dropdown.
---@param text string
---@param aboveText string
---@return boolean
local function StacksOnControl(text, aboveText)
	local entry = FindLabelled(text)
	local above = FindLabelled(aboveText)

	if not entry or not above then
		return false
	end

	local region = entry.Label or entry

	for i = 1, region:GetNumPoints() do
		local point, relativeTo = region:GetPoint(i)

		if point == "TOP" then
			return relativeTo == above
		end
	end

	return false
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

	if not slider then
		return false
	end

	local swatch = FindLabelled("Colour")

	for i = 1, slider:GetNumPoints() do
		local point, relativeTo = slider:GetPoint(i)

		if point == "TOP" then
			return swatch ~= nil and relativeTo == swatch
		end
	end

	return false
end

---The swatch's label is flipped to its left, so the button hangs off the label rather than the
---other way round.
---@return boolean
local function SwatchFollowsItsLabel()
	for _, frame in ipairs(WowMock.Frames) do
		if frame.Label and frame.Label.GetText and frame.Label:GetText() == "Colour" then
			local _, relativeTo = frame:GetPoint()

			return relativeTo == frame.Label
		end
	end

	return false
end

---The test button flows under the slider instead of parking at the panel's bottom edge.
---@return boolean
local function TestButtonFollowsSlider()
	local btn = FindButton("Test")

	if not btn then
		return false
	end

	for i = 1, btn:GetNumPoints() do
		local point, relativeTo = btn:GetPoint(i)

		if point == "TOP" then
			return relativeTo ~= nil and relativeTo.GetObjectType and relativeTo:GetObjectType() == "Slider"
		end
	end

	return false
end

smoke.Run("MiniHealerRange", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")
		fw.truthy(HasDivider("SETTINGS"), "the settings section rule under the header")
		fw.truthy(SliderFollowsColourRow(), "the font size slider sits below the colour row")
		fw.truthy(StacksOnControl("Outline", "Font"), "the outline row clears the font dropdown")
		fw.truthy(StacksOnControl("Colour", "Outline"), "the colour row clears the outline dropdown")
		fw.truthy(SwatchFollowsItsLabel(), "the colour swatch hangs off its label")
		fw.truthy(TestButtonFollowsSlider(), "the test button flows under the slider")

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
	end,
})
