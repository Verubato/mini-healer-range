-- Loads MiniHealerRange into a mocked client and gives the tests control over the WoW APIs
-- FindClosestHealer(), ShouldRun() and the update ticker read: group roles, LibRangeCheck's
-- range reading, and UnitInRange. None of those file-local functions are exposed directly, so
-- every test drives them the way the addon itself does: through the events it registers for,
-- reading back which unit it asked UnitInRange about as the proof of which one it picked.

local harness = require("AddonHarness")
local Toc = require("Toc")
local WowMock = require("WowMock")

local M = {}

---Captures every ticker the addon creates, since the shared mock queues one-shot timers but
---never drives a repeating ticker on its own (see build/Lua/WowMock.lua's C_Timer.NewTicker).
---@param env table
local function CaptureTickers(env)
	local realNewTicker = _G.C_Timer.NewTicker

	_G.C_Timer.NewTicker = function(interval, callback)
		local ticker = realNewTicker(interval, callback)
		env.Tickers[#env.Tickers + 1] = { Ticker = ticker, Callback = callback }
		return ticker
	end
end

---Wires the overrides every test in this suite needs, whichever way the addon was loaded.
---@param env table
---@param context table
local function InstallOverrides(env, context)
	env.Roles = {}
	env.Ranges = {}
	env.InRangeCalls = {}
	env.Tickers = {}

	_G.UnitGroupRolesAssigned = function(unit)
		return env.Roles[unit] or "NONE"
	end

	_G.UnitInRange = function(unit)
		env.InRangeCalls[#env.InRangeCalls + 1] = unit
		return env.InRangeAnswer
	end

	env.InRangeAnswer = true

	local lib = _G.LibStub and _G.LibStub("LibRangeCheck-3.0", true)

	if lib then
		lib.GetRange = function(_, unit)
			local max = env.Ranges[unit]

			if max == nil then
				return nil, nil
			end

			return nil, max
		end
	end

	CaptureTickers(env)

	function env.SetRole(unit, role)
		env.Roles[unit] = role
	end

	---Sets the range LibRangeCheck reports for a unit. Only meaningful when the library loaded.
	function env.SetRange(unit, maxRange)
		env.Ranges[unit] = maxRange
	end

	---Controls what UnitInRange answers for whichever unit Run() asks about next.
	function env.SetInRange(inRange)
		env.InRangeAnswer = inRange
	end

	function env.SetGroup(members, inRaid)
		WowMock.State.GroupMembers = members
		WowMock.State.InRaid = inRaid or false
	end

	function env.SetInstance(inInstance, instanceType)
		WowMock.State.InInstance = inInstance
		WowMock.State.InstanceType = instanceType
	end

	---Fires the same event the addon registers for a roster change, which runs Run() once.
	function env.Trigger()
		env.InRangeCalls = {}
		WowMock.FireEvent("GROUP_ROSTER_UPDATE")
	end

	---Runs whichever ticker the addon has live, standing in for one tick of the real timer.
	function env.Tick()
		env.InRangeCalls = {}

		for _, entry in ipairs(env.Tickers) do
			if not entry.Ticker:IsCancelled() then
				entry.Callback()
			end
		end
	end

	---The unit Run() most recently asked UnitInRange about, which is FindClosestHealer()'s pick.
	---@return string?
	function env.LastSelected()
		return env.InRangeCalls[#env.InRangeCalls]
	end

	env.Context = context
	env.Addon = context.Addon
end

---Loads the addon the normal way, through its own TOC, so LibRangeCheck-3.0 registers itself
---with LibStub exactly as it does on a real client.
---@return table env
function M.Build()
	local context = harness.Load("MiniHealerRange")
	local env = {}

	InstallOverrides(env, context)
	harness.Login(context)

	return env
end

---Loads the addon without ever running LibRangeCheck-3.0.lua, standing in for a client where
---the vendored library failed to register. addon.lua's own `local LRC = LibStub and
---LibStub(...)` line only ever resolves once, at file load, so this is the one way to put it
---in the absent state without editing src/.
---@return table env
function M.BuildWithoutRangeCheck()
	local toc = Toc.Parse(Toc.Find("MiniHealerRange"))
	local files = {}

	for _, path in ipairs(toc.Files) do
		if not path:find("LibRangeCheck%-3%.0/LibRangeCheck%-3%.0%.lua", 1, false) then
			files[#files + 1] = path
		end
	end

	WowMock.Install()

	local addonTable = {}
	local loaded = harness.LoadFiles("MiniHealerRange", files, addonTable)

	local context = {
		Name = "MiniHealerRange",
		Toc = toc,
		Addon = addonTable,
		Loaded = loaded,
		Mock = WowMock,
	}

	local env = {}

	InstallOverrides(env, context)
	harness.Login(context)

	return env
end

return M
