-- FindClosestHealer(), ShouldRun(), GetRangeMax() and the unit token cache are all file-local,
-- so these drive them entirely through tests/Helpers/Env.lua: the GROUP_ROSTER_UPDATE event the
-- addon already listens for, and reading back which unit it asked UnitInRange about as the
-- proof of which healer it picked.

local fw = require("TestFramework")
local Env = require("Env")

fw.describe("MiniHealerRange - FindClosestHealer range priority", function()
	local env

	fw.before_each(function()
		env = Env.Build()
		env.SetInstance(true, "party")
		_G.MiniHealerRangeDB.Enabled.Dungeons = true
		env.SetGroup(3, false) -- party1, party2
	end)

	-- party1 is processed first, so a version that just kept the last matching healer instead
	-- of tracking each band separately would report party2 here instead of party1.
	fw.it("a 25 yard healer beats a 40 yard one", function()
		env.SetRole("party1", "HEALER")
		env.SetRange("party1", 20)
		env.SetRole("party2", "HEALER")
		env.SetRange("party2", 35)

		env.Trigger()

		fw.eq(env.LastSelected(), "party1", "the 25 yard band wins even though it was found first")
	end)

	-- party2, the unlimited-range healer, is processed last, so a version that fell back to
	-- whichever healer was found last would report party2 here instead of party1.
	fw.it("a 40 yard healer beats one with unlimited range", function()
		env.SetRole("party1", "HEALER")
		env.SetRange("party1", 40)
		env.SetRole("party2", "HEALER") -- no range data at all: unlimited

		env.Trigger()

		fw.eq(env.LastSelected(), "party1", "the 40 yard band wins even though it was found first")
	end)

	fw.it("no healer in the group leaves nothing selected", function()
		env.Trigger()

		fw.is_nil(env.LastSelected(), "UnitInRange was never asked about anyone")
		fw.falsy(_G["MiniHealerRangeFrame"]:IsShown(), "nothing to highlight")
	end)

	fw.it("two healers at the same range resolve deterministically", function()
		env.SetRole("party1", "HEALER")
		env.SetRange("party1", 20)
		env.SetRole("party2", "HEALER")
		env.SetRange("party2", 20)

		env.Trigger()

		-- Every matching healer overwrites the previous pick as the loop walks the roster, so
		-- the later slot always wins a tie rather than the first one found.
		fw.eq(env.LastSelected(), "party2", "the later slot in iteration order wins the tie")
	end)
end)

fw.describe("MiniHealerRange - ShouldRun gating", function()
	local env

	fw.before_each(function()
		env = Env.Build()
		env.SetGroup(3, false) -- party1, party2
		env.SetRole("party1", "HEALER")
	end)

	fw.it("routes arena to its own setting", function()
		env.SetInstance(true, "arena")

		_G.MiniHealerRangeDB.Enabled.Arena = true
		env.Trigger()
		fw.eq(env.LastSelected(), "party1", "runs in arena once Arena is enabled")

		_G.MiniHealerRangeDB.Enabled.Arena = false
		env.Trigger()
		fw.is_nil(env.LastSelected(), "stays off once Arena is disabled")
	end)

	fw.it("routes battlegrounds to its own setting", function()
		env.SetInstance(true, "pvp")

		_G.MiniHealerRangeDB.Enabled.Battlegrounds = false
		env.Trigger()
		fw.is_nil(env.LastSelected(), "off by default in a battleground")

		_G.MiniHealerRangeDB.Enabled.Battlegrounds = true
		env.Trigger()
		fw.eq(env.LastSelected(), "party1", "runs once Battlegrounds is enabled")
	end)

	fw.it("routes dungeons to its own setting", function()
		env.SetInstance(true, "party")

		_G.MiniHealerRangeDB.Enabled.Dungeons = true
		env.Trigger()
		fw.eq(env.LastSelected(), "party1", "runs in a dungeon once Dungeons is enabled")

		_G.MiniHealerRangeDB.Enabled.Dungeons = false
		env.Trigger()
		fw.is_nil(env.LastSelected(), "stays off once Dungeons is disabled")
	end)

	fw.it("routes a scenario to the dungeon setting too", function()
		env.SetInstance(true, "scenario")
		_G.MiniHealerRangeDB.Enabled.Dungeons = true

		env.Trigger()

		fw.eq(env.LastSelected(), "party1", "a scenario shares Dungeons with a party instance")
	end)

	fw.it("never runs when the player is itself a healer", function()
		env.SetInstance(true, "party")
		_G.MiniHealerRangeDB.Enabled.Dungeons = true
		env.SetRole("player", "HEALER")

		env.Trigger()

		fw.is_nil(env.LastSelected(), "the player-is-healer check exits before any search runs")
	end)
end)

fw.describe("MiniHealerRange - GetRangeMax with LibRangeCheck absent", function()
	local env

	fw.before_each(function()
		env = Env.BuildWithoutRangeCheck()
		env.SetInstance(true, "party")
		env.SetGroup(3, false) -- party1, party2
	end)

	fw.it("still finds a healer with no range library to consult", function()
		env.SetRole("party1", "HEALER")

		env.Trigger()

		fw.eq(env.LastSelected(), "party1", "the search still works with GetRangeMax always nil")
	end)

	fw.it("picks the later of two healers, since range can never break the tie", function()
		env.SetRole("party1", "HEALER")
		env.SetRole("party2", "HEALER")

		env.Trigger()

		fw.eq(env.LastSelected(), "party2", "neither range band can ever be reached without the library")
	end)
end)

fw.describe("MiniHealerRange - unit token generation", function()
	local env

	fw.before_each(function()
		env = Env.Build()
		env.SetInstance(true, "party")
		_G.MiniHealerRangeDB.Enabled.Dungeons = true
		env.SetGroup(2, false) -- party1 only
		env.SetRole("party1", "HEALER")
	end)

	-- Lua interns strings, so a token built fresh from "party" .. 1 is already indistinguishable
	-- from a cached one by identity; what the cache actually guarantees, and what this proves,
	-- is that the same group slot keeps naming the same unit call after call.
	fw.it("names the same unit on a second call as it did on the first", function()
		env.Trigger()
		local first = env.LastSelected()

		env.Trigger()
		local second = env.LastSelected()

		fw.eq(first, "party1", "first call resolved the healer's token")
		fw.eq(second, first, "the cached token still names the same unit")
	end)
end)

fw.describe("MiniHealerRange - the update ticker", function()
	local env

	fw.before_each(function()
		env = Env.Build()
	end)

	-- Run() cancels its own ticker the moment ShouldRun() is false, which it is throughout the
	-- login sequence, so the live ticker only exists once a passing event has recreated it.
	-- Changing state between that event and the tick proves the tick itself re-ran Run(),
	-- rather than the assertion just seeing the earlier event's result.
	fw.it("drives Run() and lands the highlight on the right unit", function()
		env.SetInstance(true, "party")
		_G.MiniHealerRangeDB.Enabled.Dungeons = true
		env.SetGroup(2, false) -- party1 only
		env.SetRole("party1", "HEALER")
		env.SetRange("party1", 20)
		env.SetInRange(false)

		env.Trigger()
		fw.eq(env.LastSelected(), "party1", "the event pass already found the right healer")

		env.SetInRange(true)
		env.Tick()

		fw.eq(env.LastSelected(), "party1", "the ticker's own Run() re-picked the same healer")
		fw.falsy(_G["MiniHealerRangeFrame"]:IsShown(), "hidden once the ticker itself sees it back in range")
	end)

	fw.it("shows the frame once the ticker sees the healer go out of range", function()
		env.SetInstance(true, "party")
		_G.MiniHealerRangeDB.Enabled.Dungeons = true
		env.SetGroup(2, false)
		env.SetRole("party1", "HEALER")
		env.SetRange("party1", 20)
		env.SetInRange(true)

		env.Trigger()
		fw.falsy(_G["MiniHealerRangeFrame"]:IsShown(), "hidden while in range")

		env.SetInRange(false)
		env.Tick()

		fw.truthy(_G["MiniHealerRangeFrame"]:IsShown(), "shown once the ticker itself sees it out of range")
	end)
end)
