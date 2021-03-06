--[[--------------------------------------------------------------------
	Hydra
	Multibox leveling helper.
	Copyright (c) 2010-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/Hydra
	https://mods.curse.com/addons/wow/hydra
	https://www.wowinterface.com/downloads/info17572-Hydra.html
------------------------------------------------------------------------
	Hydra Group
	* Type "/inviteme" to command your target to invite you to a Group
	  and promote you to Group leader. Supplying any parameter with this
	  command will stop the target from promoting you after inviting.
	* Type "/promoteme" to command your target to promote you to Group
	  leader.
----------------------------------------------------------------------]]

local _, Hydra = ...
local L = Hydra.L
local STATE_SOLO, STATE_INSECURE, STATE_SECURE, STATE_LEADER = Hydra.STATE_SOLO, Hydra.STATE_INSECURE, Hydra.STATE_SECURE, Hydra.STATE_LEADER

local Group = Hydra:NewModule("Group")
Group.defaults = { enable = true }

local ACTION_INVITE, ACTION_PROMOTE = "INVITE", "PROMOTE"

local remote

------------------------------------------------------------------------

function Group:ShouldEnable()
	return self.db.enable
end

function Group:OnEnable()
	self:RegisterEvent("PARTY_INVITE_REQUEST")
end

------------------------------------------------------------------------

local function GetGroupLeader()
	local u, n
	if IsInRaid() then
		u, n = "raid", GetNumGroupMembers()
	else
		u, n = "party", GetNumGroupMembers() - 1
	end
	for i = 1, n do
		local unit = u..i
		if UnitIsGroupLeader(unit) then
			return unit
		end
	end
end

------------------------------------------------------------------------

function Group:OnAddonMessage(message, channel, sender)
	self:Debug("OnAddonMessage", message, channel, sender)

	if message == ACTION_INVITE then
		if not Hydra:IsTrusted(sender) then
			return self:SendChatMessage(L.CantInviteNotTrusted, sender)
		end
		if GetNumGroupMembers() > 0 and not UnitIsGroupLeader("player") then
			return self:SendChatMessage(L.CantInviteNotLeader, sender)
		end
		InviteUnit(Ambiguate(sender, "none"))

	elseif message == ACTION_PROMOTE then
		if not Hydra:IsTrusted(sender) then
			return self:SendChatMessage(L.CantPromoteNotTrusted, sender)
		end
		if GetNumGroupMembers() == 0 then
			remote = sender
			self:RegisterEvent("PARTY_LEADER_CHANGED")
			return self:OnAddonMessage(ACTION_INVITE, channel, sender)
		end
		if not UnitIsGroupLeader("player") then
			-- This should never happen.
			return self:SendChatMessage(L.CantPromoteNotLeader, sender)
		end
		PromoteToLeader(Ambiguate(sender, "none"))
	end
end

function Group:PARTY_LEADER_CHANGED()
	if remote and GetNumGroupMembers() > 0 and UnitIsGroupLeader("player") then
		self:UnregisterEvent("PARTY_LEADER_CHANGED")
		PromoteToLeader(Ambiguate(remote, "none"))
		remote = nil
	end
end

------------------------------------------------------------------------

do
	local function checkInvite(which, sender)
		if Group.enabled and Hydra:IsTrusted(sender) then
			Group:Debug("Sender", sender, "is trusted.")
			local dialog = StaticPopup_Visible(which)
			if dialog then
				Group:Debug("Dialog found:", dialog)
				StaticPopup_OnClick(_G[dialog], 1)
			else
				Group:Debug("Dialog not found.")
			end
		end
	end

	hooksecurefunc("StaticPopup_Show", function(which, sender)
		if which == "PARTY_INVITE" or which == "PARTY_INVITE_XREALM" then
			Group:Debug("StaticPopup_Show", which, sender)
			checkInvite(which, sender)
		end
	end)

	function Group:PARTY_INVITE_REQUEST(sender, roleTankAvailable, roleHealerAvailable, roleDamagerAvailable, isCrossRealm)
		if role1 or role2 or role3 then
			-- LFG thingy
			return
		end
		self:Debug("PARTY_INVITE_REQUEST", sender)
		checkInvite(isCrossRealm and "PARTY_INVITE_XREALM" or "PARTY_INVITE", sender)
	end
end

------------------------------------------------------------------------

SLASH_HYDRA_INVITEME1 = "/inviteme"
SLASH_HYDRA_INVITEME2 = "/ime"

if L.SlashInviteMe ~= SLASH_HYDRA_INVITEME1 and L.SlashInviteMe ~= SLASH_HYDRA_INVITEME2 then
	SLASH_HYDRA_INVITEME3 = L.SlashInviteMe
end

SlashCmdList.HYDRA_INVITEME = function(name)
	if not name or not Group.enabled or GetNumGroupMembers() > 0 then return end

	name = name and strtrim(name) or ""
	if strlen(name) == 0 and UnitCanCooperate("player", "target") then
		name = Hydra:IsTrusted(UnitName("target"))
	else
		name = Hydra:IsTrusted(name)
	end

	if name then
		Group:Debug("Sending invite request to", name)
		Group:SendAddonMessage(ACTION_INVITE, name)
	end
end

------------------------------------------------------------------------

SLASH_HYDRA_PROMOTEME1 = "/promoteme"
SLASH_HYDRA_PROMOTEME2 = "/pme"
SLASH_HYDRA_PROMOTEME3 = L.SlashPromoteMe

SlashCmdList.HYDRA_PROMOTEME = function(name)
	if UnitIsGroupLeader("player") then
		return Group:Debug("You are already the leader")
	elseif IsInGroup() then
		name = GetUnitName(GetGroupLeader(), true)
		Group:Debug("Sending promote request to", name)
	else
		name = name and strtrim(name) or ""
		if strlen(name) == 0 and UnitCanCooperate("player", "target") then
			name = Hydra:IsTrusted(UnitFullName("target"))
		else
			name = Hydra:IsTrusted(name)
		end
		if not name then
			return Group:Debug("/promoteme - Not in group, no valid name specified.")
		end
		Group:Debug("Sending invite+promote request to", name)
	end

	Group:SendAddonMessage(ACTION_PROMOTE, name)
end

------------------------------------------------------------------------

Group.displayName = L.Group
function Group:SetupOptions(panel)
	local title, notes = panel:CreateHeader(L.Group, L.Group_Info)

	local enable = panel:CreateCheckbox(L.Enable, L.Enable_Info)
	enable:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", 0, -12)
	function enable:OnValueChanged(value)
		Group.db.enable = value
		Group:Refresh()
	end

	local help = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	help:SetPoint("BOTTOMLEFT", 16, 16)
	help:SetPoint("BOTTOMRIGHT", -16, 16)
	help:SetHeight(112)
	help:SetJustifyH("LEFT")
	help:SetJustifyV("BOTTOM")
	help:SetText(L.GroupHelpText)

	panel.refresh = function()
		enable:SetChecked(Group.db.enable)
	end
end
