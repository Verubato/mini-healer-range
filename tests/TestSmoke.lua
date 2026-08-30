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

---The confirmation dialog is a frame the framework owns, so a test reaches it by its button label.
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

smoke.Run("MiniHealerRange", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")
		fw.truthy(HasDivider("SETTINGS"), "the settings section rule under the header")

		local db = _G["MiniHealerRangeDB"]
		db.FontSize = 99
		db.Enabled.Arena = false

		local resetBtn = FindButton("Reset to Defaults")
		fw.not_nil(resetBtn, "reset button exists")
		resetBtn:Click()

		local confirmAccept = FindButton("Reset")
		fw.not_nil(confirmAccept, "the confirmation dialog opened")
		confirmAccept:Click()

		fw.eq(db.FontSize, context.Addon.Config.DbDefaults.FontSize, "reset restored FontSize")
		fw.eq(db.Enabled.Arena, context.Addon.Config.DbDefaults.Enabled.Arena, "reset restored Enabled.Arena")
	end,
})
