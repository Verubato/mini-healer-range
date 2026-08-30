local addonName, addon = ...

-- A FontFamilyMember is keyed by alphabet, one per alphabet the client distinguishes.
local FAMILY_ALPHABETS = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }
local LOCALE_ALPHABETS = {
	koKR = "korean",
	zhCN = "simplifiedchinese",
	zhTW = "traditionalchinese",
	ruRU = "russian",
}

-- SetFont on a font object hits the same lazy file loading a fontstring does, answering false
-- for a file the client is still loading, so objects are built once through CreateFontFamily
-- and never edited after.
local fontObjects = {}
local fontObjectCount = 0

---@class Fonts
local M = {}
addon.Fonts = M

---@param file string
---@param size number
---@param flags string
---@return table[] members
local function FamilyMembers(file, size, flags)
	local override = LOCALE_ALPHABETS[GetLocale()] or "roman"
	local members = {}

	for _, alphabet in ipairs(FAMILY_ALPHABETS) do
		local memberFile = file

		-- A non-local alphabet borrows the client's own file for it.
		if alphabet ~= override and GameFontNormal and GameFontNormal.GetFontObjectForAlphabet then
			local gameObject = GameFontNormal:GetFontObjectForAlphabet(alphabet)

			memberFile = (gameObject and gameObject:GetFont()) or file
		end

		members[#members + 1] = {
			alphabet = alphabet,
			file = memberFile,
			height = size,
			flags = flags,
		}
	end

	return members
end

---The font object for this file, size and flags, cached because editing an object a
---fontstring already holds doesn't repaint it, so a font change has to hand over a
---different object instead.
---@param file string
---@param size number
---@param flags string
---@return table object
function M:FileFontObject(file, size, flags)
	local bySize = fontObjects[file]

	if not bySize then
		bySize = {}
		fontObjects[file] = bySize
	end

	local byFlags = bySize[size]

	if not byFlags then
		byFlags = {}
		bySize[size] = byFlags
	end

	local object = byFlags[flags]

	if not object then
		fontObjectCount = fontObjectCount + 1

		local name = addonName .. "Font" .. fontObjectCount

		if CreateFontFamily then
			object = CreateFontFamily(name, FamilyMembers(file, size, flags))
			byFlags[flags] = object
		else
			-- Only an old client gets here, where the two-step is all there is.
			object = CreateFont(name)

			-- A file still loading leaves SetFont false, so a failed object isn't cached
			-- and the next call gets to retry.
			if object:SetFont(file, size, flags) then
				byFlags[flags] = object
			end
		end
	end

	return object
end
