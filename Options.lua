--[[--------------------------------------------------------------------
	Hydra
	Multibox leveling helper.
	Written by Phanx <addons@phanx.net>
	Maintained by Akkorian <akkorian@hotmail.com>
	Copyright © 2010–2011 Phanx. Some rights reserved. See LICENSE.txt for details.
	http://www.wowinterface.com/downloads/info17572-Hydra.html
	http://wow.curse.com/downloads/wow-addons/details/hydra.aspx
----------------------------------------------------------------------]]

local HYDRA, core = ...
if not core then core = _G.Hydra end

local module = core:RegisterModule("Options")

local L, realmName, playerName = core.L, GetRealmName(), UnitName("player")

local CreateButton = LibStub("PhanxConfig-Button").CreateButton
local CreateCheckbox = LibStub("PhanxConfig-Checkbox").CreateCheckbox
local CreateDropdown = LibStub("PhanxConfig-Dropdown").CreateDropdown
local CreateEditBox = LibStub("PhanxConfig-EditBox").CreateEditBox
local CreateSlider = LibStub("PhanxConfig-Slider").CreateSlider

local CreateHeader = function( parent, name, desc )
	if type( parent ) ~= "table" or not parent.CreateFontString then return end

	local title = parent:CreateFontString( nil, "ARTWORK", "GameFontNormalLarge" )
	title:SetPoint( "TOPLEFT", 16, -16 )
	title:SetPoint( "TOPRIGHT", -16, -16 )
	title:SetJustifyH( "LEFT" )
	title:SetText( name )

	local notes = parent:CreateFontString( nil, "ARTWORK", "GameFontHighlight" )
	notes:SetPoint( "TOPLEFT", title, "BOTTOMLEFT", 0, -8 )
	notes:SetPoint( "TOPRIGHT", title, "BOTTOMRIGHT", 0, -8 )
	notes:SetHeight( 32 )
	notes:SetJustifyH( "LEFT")
	notes:SetJustifyV( "TOP")
	notes:SetNonSpaceWrap( true )
	notes:SetText( desc )

	return title, notes
end

------------------------------------------------------------------------

local trustOptions = CreateFrame( "Frame", nil, InterfaceOptionsFramePanelContainer )
trustOptions.name = HYDRA

trustOptions:Hide()
trustOptions:SetScript( "OnShow", function( self )
	local title, notes = CreateHeader( self, HYDRA, GetAddOnMetadata( HYDRA, "Notes" ) )

	local add = CreateEditBox( self, L["Add name"], 12, L["Add a name to your trust list."] )
	add:SetPoint( "TOPLEFT", notes, "BOTTOMLEFT", 0, -16 )
	add:SetPoint( "TOPRIGHT", notes, "BOTTOM", -8, -16 )
	add.OnValueChanged = function( self, value )
		local len = value and string.len( string.trim( value ) ) or 0
		if len > 2 and len < 13 then
			value = string.gsub( value, "%a", string.upper, 1 )
			core:Print( L["Added %s to your trust list."], value )
			core.trusted[ value ] = value
			HydraTrustList[ realmName ][ value ] = value
			core:TriggerEvent( "PARTY_MEMBERS_CHANGED" )
		end
		self:SetText( nil )
	end

	local grp = CreateButton( self, L["Add party"], L["Add everyone in your party to your trust list."] )
	grp:SetPoint( "TOPLEFT", notes, "BOTTOM", 8, -16 )
	grp:SetPoint( "TOPRIGHT", notes, "BOTTOMRIGHT", 0, -16 )
	grp.OnClick = function( self )
		local added
		for i = 1, 4 do
			local value = UnitName( "party" .. i )
			if value then
				core:Print( L["Added %s to your trust list."], value )
				core.trusted[ value ] = value
				HydraTrustList[ realmName ][ value ] = value
				added = true
			end
		end
		if added then
			core:TriggerEvent( "PARTY_MEMBERS_CHANGED" )
		end
	end

	local rem = CreateDropdown( self, L["Remove name"], L["Remove a name from your trust list."] )
	rem:SetPoint( "TOPLEFT", add, "BOTTOMLEFT", 0, -12 )
	rem:SetPoint( "TOPRIGHT", add, "BOTTOMRIGHT", 0, -12 )
	rem.OnValueChanged = function( self )
		local name = self.value
		if core.trusted[ name ] then
			core.trusted[ name ] = nil
			HydraTrustList[ realmName ][ name ] = nil
			core:TriggerEvent( "PARTY_MEMBERS_CHANGED" )
		end
		rem.valueText:SetText( nil )
	end
	do
		local info = { }
		local list = { }
		UIDropDownMenu_Initialize( rem.dropdown, function()
			for name in pairs( core.trusted ) do
				list[ #list + 1 ] = name
			end
			table.sort( list )
			for i = 1, #list do
				local name = list[ i ]

				info.name = name
				info.value = name
				info.func = rem.OnValueChanged
				info.notCheckable = 1

				UIDropDownMenu_AddButton( info )
			end
			table.wipe( list )
		end )
	end

	self:SetScript( "OnShow", nil )
end )

InterfaceOptions_AddCategory( trustOptions )

------------------------------------------------------------------------

function module:CheckState()
	do return end
	self:Debug("Loading options...")

	local L, tlist, pname = core.L, { }, UnitName("player")

	local options = {
		type = "group", args = {
			help = {
				name = L["Hydra is a multibox leveling helper that aims to minimize the need to actively control secondary characters."],
				type = "description",
				order = 1,
			},
			TrustList = {
				name = L["Trust List"],
				type = "group", dialogInline = true,
				order = 2,
				args = {
					add = {
						name = L["Add Name"],
						desc = L["Add a name to your trusted list."],
						type = "input",
						order = 20,
						get = false,
						set = function(t, v)
							v = v:trim():gsub("%a", string.upper, 1)
							core:Print("Added", v, "to the trusted list.")
							core.trusted[v] = v
							HydraTrustList[realmName][v] = v
							core:TriggerEvent("PARTY_MEMBERS_CHANGED")
						end,
					},
					remove = {
						name = L["Remove Name"],
						desc = L["Remove a name from your trusted list."],
						type = "select",
						order = 30,
						values = core.trusted,
						get = false,
						set = function(t, v)
							core:Print("Removed", v, "from the trusted list.")
							core.trusted[v] = nil
							HydraTrustList[realmName][v] = nil
							core:TriggerEvent("PARTY_MEMBERS_CHANGED")
						end,
					},
					group = {
						name = L["Add Current Party"],
						desc = L["Adds all the characters in your current party group to your trusted list."],
						type = "execute",
						func = function()
							for i = 1, GetNumPartyMembers() do
								local v = UnitName("party" .. i)
								core:Print("Added", v, "to the trusted list.")
								core.trusted[v] = v
								HydraTrustList[realmName][v] = v
							end
							core:TriggerEvent("PARTY_MEMBERS_CHANGED")
						end,
					},
				},
			},
			Automation = {
				name = L["Automation"],
				type = "group", dialogInline = true,
				get = function(t)
					return core.db["Automation"][t.arg]
				end,
				set = function(t, v)
					core.db["Automation"][t.arg] = v
					if t[#t] ~= "verbose" then
						core.modules["Automation"]:CheckState()
					end
				end,
				args = {
					help = {
						name = L["Automates simple repetetive tasks, such as clicking common dialogs."],
						type = "description",
						order = 10,
					},
					duel = {
						name = L["Decline duels"],
						type = "toggle",
						order = 20,
						arg = "declineDuels",
					},
					arena = {
						name = L["Decline arena teams"],
						type = "toggle",
						order = 30,
						arg = "declineArenaTeams",
					},
					guild = {
						name = L["Decline guilds"],
						type = "toggle",
						order = 40,
						arg = "declineGuilds",
					},
					summon = {
						name = L["Accept summons"],
						type = "toggle",
						order = 50,
						arg = "acceptSummons",
					},
					res = {
						name = L["Accept resurrections"],
						type = "toggle",
						order = 60,
						arg = "acceptResurrections",
					},
					combatres = {
						name = L["Accept resurrections in combat"],
						type = "toggle",
						order = 65,
						arg = "acceptResurrectionsInCombat",
					},
		--[[
					corpse = {
						name = L["Accept corpse"],
						desc = L["Accept resurrection to your corpse if another party member is alive and nearby."],
						type = "toggle",
						order = 70,
						arg = "acceptCorpseResurrections",
					},
					release = {
						name = L["Release spirit"],
						desc = L["Release your spirit when you die."],
						type = "toggle",
						order = 80,
						arg = "releaseSpirit",
					},
		--]]
					repair = {
						name = L["Repair equipment"],
						type = "toggle",
						order = 90,
						arg = "repairEquipment",
					},
					sell = {
						name = L["Sell junk"],
						type = "toggle",
						order = 100,
						arg = "sellJunk",
					},
					verbose = {
						name = L["Verbose mode"],
						desc = L["Print messages to the chat frame when performing any action."],
						type = "toggle",
						order = 200,
						arg = "verbose",
					},
				},
			},
			Chat = {
				name = L["Chat"],
				type = "group", dialogInline = true, args = {
					help = {
						name = L["Forwards whispers sent to inactive characters to party chat, and forwards replies to the original sender."],
						type = "description",
						order = 10,
					},
					enable = {
						name = L["Enable"],
						type = "toggle",
						order = 20,
						get = function()
							return core.db["Chat"].enable
						end,
						set = function(_, v)
							core.db["Chat"].enable = v
							core.modules["Chat"]:CheckState()
						end,
					},
					mode = {
						name = L["Mode"],
						order = 30,
						type = "select", values = {
							appfocus = L["Application Focus"],
							leader = L["Party Leader"],
						},
						get = function()
							return core.db["Chat"].mode
						end,
						set = function(_, v)
							core.db["Chat"].mode = v
							core.modules["Chat"]:CheckState()
						end,
					},
					timeout = {
						name = L["Timeout"],
						type = "range", min = 30, max = 600, step = 30,
						order = 40,
						get = function()
							return core.db["Chat"].timeout
						end,
						set = function(_, v)
							core.db["Chat"].timeout = v
						end,
					},
				},
			},
			Follow = {
				name = L["Follow"],
				type = "group", dialogInline = true, args = {
					help = {
						name = L["Responds to follow requests from trusted party members."],
						type = "description",
						order = 10,
					},
					enable = {
						name = L["Enable"],
						type = "toggle",
						order = 20,
						get = function()
							return core.db["Follow"].enable
						end,
						set = function(_, v)
							core.db["Follow"].enable = v
						end,
					},
					verbose = {
						name = L["Verbose"],
						type = "toggle",
						order = 30,
						get = function()
							return core.db["Follow"].verbose
						end,
						set = function(_, v)
							core.db["Follow"].verbose = v
						end,
					},
				},
			},
			Mount = {
				name = L["Mount"],
				type = "group", dialogInline = true, args = {
					help = {
						name = L["Summons your mount when another party member mounts."],
						type = "description",
						order = 10,
					},
					enable = {
						name = L["Enable"],
						type = "toggle",
						order = 20,
						get = function()
							return core.db["Mount"].enable
						end,
						set = function(_, v)
							core.db["Mount"].enable = v
							core.modules["Mount"]:CheckState()
						end,
					},
				},
			},
			Party = {
				name = L["Party"],
				type = "group", dialogInline = true, args = {
					help = {
						name = L["Responds to invite and promote requests from trusted players."],
						type = "description",
						order = 10,
					},
					enable = {
						name = L["Enable"],
						type = "toggle",
						order = 20,
						get = function()
							return core.db["Party"].enable
						end,
						set = function(_, v)
							core.db["Party"].enable = v
							core.modules["Party"]:CheckState()
						end,
					},
				},
			},
			Quest = {
				name = L["Quest"],
				type = "group", dialogInline = true,
				get = function(t)
					return core.db["Quest"][t[#t]]
				end,
				set = function(t, v)
					core.db["Quest"][t[#t]] = v
				end,
				args = {
					help = {
						name = L["Helps keep party members' quests in sync."],
						type = "description",
						order = 10,
					},
					turnin = {
						name = L["Turn in quests"],
						desc = L["Turn in complete quests."],
						type = "toggle",
						order = 20,
					},
					accept = {
						name = L["Accept quests"],
						desc = L["Accept quests shared by party members, quests from NPCs that other party members have already accepted, and escort-type quests started by another party member."],
						type = "toggle",
						order = 30,
					},
					share = {
						name = L["Share quests"],
						desc = L["Share quests you accept from NPCs."],
						type = "toggle",
						order = 40,
					},
					abandon = {
						name = L["Abandon quests"],
						desc = L["Abandon quests abandoned by a trusted party member."],
						type = "toggle",
						order = 50,
					},
				},
			},
			Taxi = {
				name = L["Taxi"],
				type = "group", dialogInline = true, args = {
					help = {
						name = L["Selects the same taxi destination as other party members."],
						type = "description",
						order = 10,
					},
					enable = {
						name = L["Enable"],
						type = "toggle",
						order = 20,
						get = function()
							return core.db["Taxi"].enable
						end,
						set = function(_, v)
							core.db["Chat"].enable = v
							core.modules["Taxi"]:CheckState()
						end,
					},
					timeout = {
						name = L["Timeout"],
						desc = L["Clear the taxi selection after this many seconds."],
						type = "range", min = 30, max = 600, step = 30,
						order = 30,
						get = function()
							return core.db["Taxi"].timeout
						end,
						set = function(_, v)
							core.db["Taxi"].timeout = v
						end,
					},
				},
			},
		}
	}

	AceConfigRegistry:RegisterOptionsTable(HYDRA, options)

	local panel = AceConfigDialog:AddToBlizOptions(HYDRA)
	local about = LibStub("LibAboutPanel", true) and LibStub("LibAboutPanel").new(HYDRA, HYDRA)

	SlashCmdList.HYDRA = function()
		if about then InterfaceOptionsFrame_OpenToCategory(about) end -- expand!
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
	SLASH_HYDRA1 = "/hydra"

	if LibStub("LibDataBroker-1.1", true) then
		LibStub("LibDataBroker-1.1"):NewDataObject(HYDRA, {
			type = "launcher",
			icon = "Interface\\Icons\\Achievement_Boss_Bazil_Akumai",
			label = HYDRA,
			OnClick = SlashCmdList.HYDRA,
		})
	end

	core.modules["Options"] = nil
	module, AceConfigRegistry, AceConfigDialog = nil, nil, nil
end