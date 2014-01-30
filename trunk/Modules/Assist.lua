--[[--------------------------------------------------------------------
	Hydra
	Multibox leveling helper.
	Copyright (c) 2010-2013 Phanx <addons@phanx.net>. All rights reserved.
	See the accompanying README and LICENSE files for more information.
	http://www.wowinterface.com/downloads/info17572-Hydra.html
	http://www.curse.com/addons/wow/hydra
------------------------------------------------------------------------
	Hydra Assist
	* /assistme commands all party members to set you as their assist target.
----------------------------------------------------------------------]]

--[[

1. PartyA sends AssistMe command.
2. PartyB registers PartyA as assist target.
3a. If out of combat, update assist macro.
3b. If in combat, send CombatErr message, register PLAYER_REGEN_ENABLED.
4. On leaving combat, update assist macro.

--]]

local _, core = ...
local L = core.L
local SOLO, PARTY, TRUSTED, LEADER = core.STATE_SOLO, core.STATE_PARTY, core.STATE_TRUSTED, core.STATE_LEADER
local PLAYER = core.CURRENT_PLAYER

local assisters, assisting, pending = {}

local module = core:NewModule("Assist")
module.defaults = { respond = true, verbose = true }

local statusText = {
	COMBAT  = L.AssistFailedCombat,
	ERROR   = L.AssistFailed,
	NOTRUST = L.AssistFailedTrust,
	SET     = L.AssistSet,
	UNSET   = L.AssistUnset,
}

------------------------------------------------------------------------

function module:ShouldEnable()
	return core.state > SOLO
end

function module:OnDisable(silent)
	assisters, assisting, pending = wipe(assisters), nil, nil
end

------------------------------------------------------------------------

local button = CreateFrame("Button", "HydraAssistButton", nil, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyUp")
button:SetAttribute("type", "macro")
button:SetAttribute("macrotext", "")

local MACRO_NAME, MACRO_ICON, MACRO_BODY = L.AssistMacro, "Spell_Priest_VowofUnity", "/click HydraAssistButton"

function module:GetMacro()
	local index = GetMacroIndexByName(MACRO_NAME)
	if InCombatLockdown() then
		return index
	elseif index == 0 then
		-- Macro doesn't exist yet. Create it.
		return CreateMacro(MACRO_NAME, MACRO_ICON, format(MACRO_BODY, name or ""), 0)
	else
		-- Macro already exists. Update it.
		return EditMacro(index, MACRO_NAME, MACRO_ICON, format(MACRO_BODY, name or ""))
	end
end

function module:SetAssist(name)
	self:Debug("SetAssist", name)

	if InCombatLockdown() then
		-- Player in combat. Queue change for end of combat, and inform the requester.
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		pending = name
		if name then
			self:SendAddonMessage("COMBAT", name)
		end

	elseif not name then
		-- Clear the assist target.
		button:SetAttribute("macrotext", "")

	elseif not core:IsTrusted(name) then
		-- Requester not trusted. Inform them.
		self:SendAddonMessage("NOTRUST", name)

	else
		-- Set the requester to be assisted.
		assisting = name
		button:SetAttribute("macrotext", SLASH_ASSIST1.." "..name)
		self:SendAddonMessage("SET " .. name)
	end
end

------------------------------------------------------------------------

function module:PLAYER_REGEN_ENABLED()
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	self:SetAssist(pending)
end

function module:ReceiveAddonMessage(message, channel, sender)
	self:Debug("AddonMessage", channel, sender, message)
	local message, detail = strsplit(" ", message, 2)

	if message == "REQUEST" then
		-- sender wants to be the assist target
		return self:SetAssist(sender)
	end

	if message == "SET" then
		if detail == PLAYER then
			-- sender is now assisting the player
			assisters[sender] = true
		elseif assisters[sender] then
			-- sender was assisting the player, but now someone else
			assisters[sender] = nil
			message = "UNSET"
		else
			-- irrelevant
			return
		end
	end

	if self.db.verbose then
		local report = statusText[message]
		if report then
			self:Print(report, sender, detail)
		end
	end
end

------------------------------------------------------------------------

SLASH_HYDRA_ASSIST1 = "/assistme"
SLASH_HYDRA_ASSIST2 = L.SlashAssistMe

function SlashCmdList.HYDRA_ASSIST(command)
	if not module.enabled then return end
	command = command and strlower(strtrim(command))

	if command == "who" then
		if not next(assisting) then
			return self:Print(L.NobodyAssisting)
		end
		for name in pairs(assisting) do
			self:Print(statusText["SET"], name)
		end
	else
		self:SendAddonMessage("REQUEST")
	end
end

------------------------------------------------------------------------

_G["BINDING_NAME_CLICK HydraAssistButton"] = L.AssistMacro
BINDING_NAME_HYDRA_REQUEST_ASSIST = L.RequestAssist

------------------------------------------------------------------------

module.displayName = L.Assist
function module:SetupOptions(panel)
	local title, notes = LibStub("PhanxConfig-Header"):New(panel, L.Assist, L.Assist_Info)

	local CreateCheckbox = LibStub("PhanxConfig-Checkbox").CreateCheckbox
	local CreateKeyBinding = LibStub("PhanxConfig-KeyBinding").CreateKeyBinding

	local respond = CreateCheckbox(panel, L.AssistRespond, L.AssistRespond_Info)
	respond:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", 0, -12)
	respond.OnValueChanged = function(this, value)
		self.db.respond = value
		self:Refresh()
	end

	local verbose = CreateCheckbox(panel, L.Verbose, L.Verbose_Info)
	verbose:SetPoint("TOPLEFT", respond, "BOTTOMLEFT", 0, -8)
	verbose.OnValueChanged = function(this, value)
		self.db.verbose = value
	end

	local usemacro = CreateKeyBinding(panel, L.AssistMacro, L.AssistMacro_Info, "CLICK HydraAssistButton")
	usemacro:SetPoint("TOPLEFT", notes, "BOTTOM", -8, -8)
	usemacro:SetPoint("TOPRIGHT", notes, "BOTTOMRIGHT", 0, -8)

	local request = CreateKeyBinding(panel, L.RequestAssist, L.RequestAssist_Info, "HYDRA_REQUEST_ASSIST")
	request:SetPoint("TOPLEFT", usemacro, "BOTTOMLEFT", 0, -8)
	request:SetPoint("TOPRIGHT", usemacro, "BOTTOMRIGHT", 0, -8)

	local help = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	help:SetPoint("BOTTOMLEFT", 16, 16)
	help:SetPoint("BOTTOMRIGHT", -16, 16)
	help:SetHeight(112)
	help:SetJustifyH("LEFT")
	help:SetJustifyV("BOTTOM")
	help:SetText(L.AssistHelpText)

	local getmacro = LibStub("PhanxConfig-Button"):New(panel, L.AssistGetMacro, L.AssistGetMacro_Info)
	getmacro:SetPoint("BOTTOMRIGHT", help, "TOPRIGHT", 0, 24)
	getmacro.OnClick = function(this, button)
		PickupMacro(self:GetMacro())
	end

	panel.refresh = function()
		respond:SetChecked(self.db.respond)
		verbose:SetChecked(self.db.verbose)
		usemacro:RefreshValue()
		request:RefreshValue()
	end
end