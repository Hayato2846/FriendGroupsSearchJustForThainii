local hooks = {}

local function Hook(source, target, secure)
	hooks[source] = _G[source]
	if secure then
		hooksecurefunc(source, target)
	else
		_G[source] = target
	end
end

local FRIENDS_GROUP_NAME_COLOR = NORMAL_FONT_COLOR

local INVITE_RESTRICTION_NO_GAME_ACCOUNTS = 0
local INVITE_RESTRICTION_CLIENT = 1
local INVITE_RESTRICTION_LEADER = 2
local INVITE_RESTRICTION_FACTION = 3
local INVITE_RESTRICTION_REALM = 4
local INVITE_RESTRICTION_INFO = 5
local INVITE_RESTRICTION_WOW_PROJECT_ID = 6
local INVITE_RESTRICTION_WOW_PROJECT_MAINLINE = 7
local INVITE_RESTRICTION_WOW_PROJECT_CLASSIC = 8
local INVITE_RESTRICTION_NONE = 9
local INVITE_RESTRICTION_MOBILE = 10

-- classic and retails use different values for restrictions
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	INVITE_RESTRICTION_NO_GAME_ACCOUNTS = 0
	INVITE_RESTRICTION_CLIENT = 1
	INVITE_RESTRICTION_LEADER = 2
	INVITE_RESTRICTION_FACTION = 3
	INVITE_RESTRICTION_REALM = nil
	INVITE_RESTRICTION_INFO = 4
	INVITE_RESTRICTION_WOW_PROJECT_ID = 5
	INVITE_RESTRICTION_WOW_PROJECT_MAINLINE = 6
	INVITE_RESTRICTION_WOW_PROJECT_CLASSIC = 7
	INVITE_RESTRICTION_NONE = 8
	INVITE_RESTRICTION_MOBILE = 9
end

local ONE_MINUTE = 60
local ONE_HOUR = 60 * ONE_MINUTE
local ONE_DAY = 24 * ONE_HOUR
local ONE_MONTH = 30 * ONE_DAY
local ONE_YEAR = 12 * ONE_MONTH

local FriendButtons = { count = 0 }
local GroupCount = 0
local GroupTotal = {}
local GroupOnline = {}
local GroupSorted = {}

local FriendRequestString = string.sub(FRIEND_REQUESTS,1,-6)

local OPEN_DROPDOWNMENUS_SAVE = nil
local friend_popup_menus = { "FRIEND", "FRIEND_OFFLINE", "BN_FRIEND", "BN_FRIEND_OFFLINE" }
UnitPopupButtons["FRIEND_GROUP_NEW"] = { text = "Create new group"}
UnitPopupButtons["FRIEND_GROUP_ADD"] = { text = "Add to group", nested = 1}
UnitPopupButtons["FRIEND_GROUP_DEL"] = { text = "Remove from group", nested = 1}
UnitPopupMenus["FRIEND_GROUP_ADD"] = { }
UnitPopupMenus["FRIEND_GROUP_DEL"] = { }

local currentExpansionMaxLevel = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and 120 or 60 -- Make it dynamic somehow

local FriendsScrollFrame
local FriendButtonTemplate
local FriendGroupsSearchOpened
local FriendGroupsSearchValue = ""

if FriendsListFrameScrollFrame then
	FriendsScrollFrame = FriendsListFrameScrollFrame
	FriendButtonTemplate = "FriendsListButtonTemplate"
else
	FriendsScrollFrame = FriendsFrameFriendsScrollFrame
	FriendButtonTemplate = "FriendsFrameButtonTemplate"
end

local function ClassColourCode(class, returnTable)
	if not class then
		return returnTable and FRIENDS_GRAY_COLOR or string.format("|cFF%02x%02x%02x", FRIENDS_GRAY_COLOR.r*255, FRIENDS_GRAY_COLOR.g*255, FRIENDS_GRAY_COLOR.b*255)
	end

	local initialClass = class
	for k, v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
		if class == v then
			class = k
			break
		end
	end
	if class == initialClass then
		for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
			if class == v then
				class = k
				break
			end
		end
	end
	local colour = class ~= "" and RAID_CLASS_COLORS[class] or FRIENDS_GRAY_COLOR
	-- Shaman color is shared with pally in the table in classic
	if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC and class == "SHAMAN" then
		colour.r = 0
		colour.g = 0.44
		colour.b = 0.87
	end
	if returnTable then
		return colour
	else
		return string.format("|cFF%02x%02x%02x", colour.r*255, colour.g*255, colour.b*255)
	end
end

local function FriendGroups_GetTopButton(offset)
	local usedHeight = 0
	for i = 1, FriendButtons.count do
		local buttonHeight = FRIENDS_BUTTON_HEIGHTS[FriendButtons[i].buttonType]
		if ( usedHeight + buttonHeight >= offset ) then
			return i - 1, offset - usedHeight
		else
			usedHeight = usedHeight + buttonHeight
		end
	end
	return 0,0
end

local function GetOnlineInfoText(client, isMobile, rafLinkType, locationText)
	if not locationText or locationText == "" then
		return UNKNOWN
	end
	if isMobile then
		return LOCATION_MOBILE_APP
	end
	if (client == BNET_CLIENT_WOW) and (rafLinkType ~= Enum.RafLinkType.None) and not isMobile then
		if rafLinkType == Enum.RafLinkType.Recruit then
			return RAF_RECRUIT_FRIEND:format(locationText)
		else
			return RAF_RECRUITER_FRIEND:format(locationText)
		end
	end
	return locationText
end

local function GetFriendInfoById(id)
	local accountName, characterName, class, level, isFavoriteFriend, isOnline,
		bnetAccountId, client, canCoop, wowProjectID, lastOnline,
		isAFK, isGameAFK, isDND, isGameBusy, mobile, zoneName, battleTag,
		realmName 

	if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
		local accountInfo = C_BattleNet.GetFriendAccountInfo(id)
		if accountInfo then
			accountName = accountInfo.accountName
			isFavoriteFriend = accountInfo.isFavorite
			bnetAccountId = accountInfo.bnetAccountID
			isAFK = accountInfo.isAFK
			isDND = accountInfo.isDND
			zoneName = accountInfo.areaName
			lastOnline = accountInfo.lastOnlineTime
			battleTag = accountInfo.battleTag

			local gameAccountInfo = accountInfo.gameAccountInfo

			if gameAccountInfo then
				isOnline = gameAccountInfo.isOnline
				isGameAFK = gameAccountInfo.isGameAFK
				isGameBusy = gameAccountInfo.isGameBusy
				mobile = gameAccountInfo.isWowMobile
				characterName = gameAccountInfo.characterName
				class = gameAccountInfo.className
				level = gameAccountInfo.characterLevel
				client = gameAccountInfo.clientProgram
				wowProjectID = gameAccountInfo.wowProjectID
				gameText = gameAccountInfo.richPresence
				zoneName = gameAccountInfo.richPresence
				realmName = gameAccountInfo.realmName
			end

			canCoop = CanCooperateWithGameAccount(accountInfo)
		end
	end

	return accountName, characterName, class, level, isFavoriteFriend, isOnline,
		bnetAccountId, client, canCoop, wowProjectID, lastOnline,
		isAFK, isGameAFK, isDND, isGameBusy, mobile, zoneName, gameText, battleTag
end

local function FriendGroups_splitBattleTag(battleTag)
   local sep = "#"

   if sep == nil then
      sep = "%s"
   end
   local t={}
   for str in string.gmatch(battleTag, "([^"..sep.."]+)") do
      table.insert(t, str)
   end
   return t[1]
end

local function FriendGroups_GetBNetButtonNameText(accountName, client, canCoop, characterName, class, level, battleTag)
	local nameText

	-- set up player name and character name
	if accountName then
		if FriendGroups_SavedVars.show_btag and battleTag then
			nameText = FriendGroups_splitBattleTag(battleTag)
		else
			nameText = accountName
		end
	else
		nameText = UNKNOWN
	end

	-- append character name
	if characterName then
		local coopLabel = ""
		if not canCoop then
			coopLabel = CANNOT_COOPERATE_LABEL
		end
		local characterNameSuffix
		if (not level) or (FriendGroups_SavedVars.hide_high_level and level == currentExpansionMaxLevel) then
			characterNameSuffix = coopLabel
		else
			characterNameSuffix= "-"..level..coopLabel
		end

		if client == BNET_CLIENT_WOW then
			local nameColor = FriendGroups_SavedVars.colour_classes and ClassColourCode(class)
			nameText = nameText.." "..nameColor.."("..characterName..characterNameSuffix..")"..FONT_COLOR_CODE_CLOSE
		else
			if ENABLE_COLORBLIND_MODE == "1" then
				characterName = characterName..coopLabel
			end
			local characterNameAndLevel = characterName..characterNameSuffix
			nameText = nameText.." "..FRIENDS_OTHER_NAME_COLOR_CODE.."("..characterNameAndLevel..")"..FONT_COLOR_CODE_CLOSE
		end
	end

	return nameText
end

local function FriendGroups_UpdateFriendButton(button)
	local index = button.index
	button.buttonType = FriendButtons[index].buttonType
	button.id = FriendButtons[index].id
	local height = FRIENDS_BUTTON_HEIGHTS[button.buttonType]
	local nameText, nameColor, infoText, broadcastText, isFavoriteFriend
	local hasTravelPassButton = false
	if button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
		local info = C_FriendList.GetFriendInfoByIndex(FriendButtons[index].id)
		broadcastText = nil
		if info.connected then
			button.background:SetColorTexture(FRIENDS_WOW_BACKGROUND_COLOR.r, FRIENDS_WOW_BACKGROUND_COLOR.g, FRIENDS_WOW_BACKGROUND_COLOR.b, FRIENDS_WOW_BACKGROUND_COLOR.a)
			if info.afk then
				button.status:SetTexture(FRIENDS_TEXTURE_AFK)
			elseif ( info.dnd ) then
				button.status:SetTexture(FRIENDS_TEXTURE_DND)
			else
				button.status:SetTexture(FRIENDS_TEXTURE_ONLINE)
			end

			nameColor = FriendGroups_SavedVars.colour_classes and ClassColourCode(info.className, true) or FRIENDS_WOW_NAME_COLOR

			if FriendGroups_SavedVars.hide_high_level and info.level == currentExpansionMaxLevel then
				nameText = info.name..", "..info.className
			else
				nameText = info.name..", "..format(FRIENDS_LEVEL_TEMPLATE, info.level, info.className)
			end
			if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
				infoText = GetOnlineInfoText(BNET_CLIENT_WOW, info.mobile, info.rafLinkType, info.area)
			end
		else
			button.background:SetColorTexture(FRIENDS_OFFLINE_BACKGROUND_COLOR.r, FRIENDS_OFFLINE_BACKGROUND_COLOR.g, FRIENDS_OFFLINE_BACKGROUND_COLOR.b, FRIENDS_OFFLINE_BACKGROUND_COLOR.a)
			button.status:SetTexture(FRIENDS_TEXTURE_OFFLINE)
			nameText = info.name
			nameColor = FRIENDS_GRAY_COLOR
			infoText = FRIENDS_LIST_OFFLINE
		end
		infoText = info.mobile and LOCATION_MOBILE_APP or info.area
		button.gameIcon:Hide()
		button.summonButton:ClearAllPoints()
		button.summonButton:SetPoint("TOPRIGHT", button, "TOPRIGHT", 1, -1)
		FriendsFrame_SummonButton_Update(button.summonButton)
	elseif button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
		local id = FriendButtons[index].id
		local accountName, characterName, class, level, isFavoriteFriend, isOnline,
			bnetAccountId, client, canCoop, wowProjectID, lastOnline,
			isAFK, isGameAFK, isDND, isGameBusy, mobile, zoneName, gameText, battleTag = GetFriendInfoById(id)

		nameText = FriendGroups_GetBNetButtonNameText(accountName, client, canCoop, characterName, class, level, battleTag)
		
		if isOnline then
			button.background:SetColorTexture(FRIENDS_BNET_BACKGROUND_COLOR.r, FRIENDS_BNET_BACKGROUND_COLOR.g, FRIENDS_BNET_BACKGROUND_COLOR.b, FRIENDS_BNET_BACKGROUND_COLOR.a)
			if isAFK or isGameAFK or (FriendGroups_SavedVars.show_mobile_afk and client == 'BSAp') then
				button.status:SetTexture(FRIENDS_TEXTURE_AFK)
			elseif isDND or isGameBusy then
				button.status:SetTexture(FRIENDS_TEXTURE_DND)
			else
				button.status:SetTexture(FRIENDS_TEXTURE_ONLINE)
			end
			if client == BNET_CLIENT_WOW and wowProjectID == WOW_PROJECT_ID then
				if not zoneName or zoneName == "" then
					infoText = UNKNOWN
				else
					infoText = mobile and LOCATION_MOBILE_APP or zoneName
				end
			else
				infoText = gameText
			end
			if FriendGroups_SavedVars.add_mobile_text and infoText == '' and client == 'BSAp' then
				infoText = "Mobile"
			end
			button.gameIcon:SetTexture(BNet_GetClientTexture(client))
			nameColor = FRIENDS_BNET_NAME_COLOR
			local fadeIcon = (client == BNET_CLIENT_WOW) and (wowProjectID ~= WOW_PROJECT_ID)
			if fadeIcon then
				button.gameIcon:SetAlpha(0.6)
			else
				button.gameIcon:SetAlpha(1)
			end
			-- Note - this logic should match the logic in FriendsFrame_ShouldShowSummonButton

			local shouldShowSummonButton = FriendsFrame_ShouldShowSummonButton(button.summonButton)
			button.gameIcon:SetShown(not shouldShowSummonButton)

			-- travel pass
			hasTravelPassButton = true
			local restriction = FriendsFrame_GetInviteRestriction(button.id)
			if ( restriction == INVITE_RESTRICTION_NONE ) then
				button.travelPassButton:Enable()
			else
				button.travelPassButton:Disable()
			end
		else
			button.background:SetColorTexture(FRIENDS_OFFLINE_BACKGROUND_COLOR.r, FRIENDS_OFFLINE_BACKGROUND_COLOR.g, FRIENDS_OFFLINE_BACKGROUND_COLOR.b, FRIENDS_OFFLINE_BACKGROUND_COLOR.a)
			button.status:SetTexture(FRIENDS_TEXTURE_OFFLINE)
			nameColor = FRIENDS_GRAY_COLOR
			button.gameIcon:Hide()
			if ( not lastOnline or lastOnline == 0 or time() - lastOnline >= ONE_YEAR ) then
				infoText = FRIENDS_LIST_OFFLINE
			else
				infoText = string.format(BNET_LAST_ONLINE_TIME, FriendsFrame_GetLastOnline(lastOnline))
			end
		end
		
		if nameText == UNKNOWN then
			button:Hide();
		end
		
		button.summonButton:ClearAllPoints()
		button.summonButton:SetPoint("CENTER", button.gameIcon, "CENTER", 1, 0)
		FriendsFrame_SummonButton_Update(button.summonButton)
	elseif ( button.buttonType == FRIENDS_BUTTON_TYPE_DIVIDER ) then
		local title
		local group = FriendButtons[index].text
		local counts
		
		if group == "" or not group then
			title = "[no group]"
		else
			title = group
		end
		
		if group == "Search..." then
			counts = ""
		else
			counts = "(" .. GroupOnline[group] .. "/" .. GroupTotal[group] .. ")"
		end
		
		if button["text"] then
			button.text:SetText(title)
			button.text:Show()
			nameText = counts
			button.name:SetJustifyH("RIGHT")
		else
			nameText = title.." "..counts
			button.name:SetJustifyH("CENTER")
		end
		nameColor = FRIENDS_GROUP_NAME_COLOR
		
		if group ~= "Search..." then
			if FriendGroups_SavedVars.collapsed[group] then
				button.status:SetTexture("Interface\\Buttons\\UI-PlusButton-UP")
			else
				button.status:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
			end
		else
			button.status:SetTexture("")
		end
		
		infoText = group
		button.info:Hide()
		button.gameIcon:Hide()
		button.background:SetColorTexture(FRIENDS_OFFLINE_BACKGROUND_COLOR.r, FRIENDS_OFFLINE_BACKGROUND_COLOR.g, FRIENDS_OFFLINE_BACKGROUND_COLOR.b, FRIENDS_OFFLINE_BACKGROUND_COLOR.a)
		button.background:SetAlpha(0.5)
	elseif ( button.buttonType == FRIENDS_BUTTON_TYPE_INVITE_HEADER ) then
		local header = FriendsScrollFrame.PendingInvitesHeaderButton
		header:SetPoint("TOPLEFT", button, 1, 0)
		header:Show()
		header:SetFormattedText(FRIEND_REQUESTS, BNGetNumFriendInvites())
		local collapsed = GetCVarBool("friendInvitesCollapsed")
		if ( collapsed ) then
			header.DownArrow:Hide()
			header.RightArrow:Show()
		else
			header.DownArrow:Show()
			header.RightArrow:Hide()
		end
		nameText = nil
	elseif ( button.buttonType == FRIENDS_BUTTON_TYPE_INVITE ) then
		local scrollFrame = FriendsScrollFrame
		local invite = scrollFrame.invitePool:Acquire()
		invite:SetParent(scrollFrame.ScrollChild)
		invite:SetAllPoints(button)
		invite:Show()
		local inviteID, accountName = BNGetFriendInviteInfo(button.id)
		invite.Name:SetText(accountName)
		invite.inviteID = inviteID
		invite.inviteIndex = button.id
		nameText = nil
	end
	-- travel pass?
	if ( hasTravelPassButton ) then
		button.travelPassButton:Show()
	else
		button.travelPassButton:Hide()
	end
	-- selection
	if ( FriendsFrame.selectedFriendType == FriendButtons[index].buttonType and FriendsFrame.selectedFriend == FriendButtons[index].id ) then
		button:LockHighlight()
	else
		button:UnlockHighlight()
	end
	-- finish setting up button if it's not a header
	if ( nameText ) then
		if button.buttonType ~= FRIENDS_BUTTON_TYPE_DIVIDER then
			if button["text"] then
				button.text:Hide()
			end
			button.name:SetJustifyH("LEFT")
			button.background:SetAlpha(1)
			button.info:Show()
		else
			local group = FriendButtons[index].text
			
			if group == "Search..." and FriendGroupsSearchOpened then
				nameText = ""
			end
		end
		
		button.name:SetText(nameText)
		button.name:SetTextColor(nameColor.r, nameColor.g, nameColor.b)
		button.info:SetText(infoText)
		
		button:Show()
		if isFavoriteFriend and button.Favorite then
			button.Favorite:Show()
			button.Favorite:ClearAllPoints()
			button.Favorite:SetPoint("TOPLEFT", button.name, "TOPLEFT", button.name:GetStringWidth(), 0)
		elseif button.Favorite then
			button.Favorite:Hide()
		end
	else
		button:Hide()
	end
	-- update the tooltip if hovering over a button
	if ( FriendsTooltip.button == button ) or ( GetMouseFocus() == button ) then
		if FriendsFrameTooltip_Show then
			FriendsFrameTooltip_Show(button)
		else
			button:OnEnter()
		end
	end

	return height
end

local function FriendGroups_UpdateFriends()
	local scrollFrame = FriendsScrollFrame
	local offset = HybridScrollFrame_GetOffset(scrollFrame)
	local buttons = scrollFrame.buttons
	local numButtons = #buttons
	local numFriendButtons = FriendButtons.count
	local usedHeight = 0
	
	scrollFrame.dividerPool:ReleaseAll()
	scrollFrame.invitePool:ReleaseAll()
	scrollFrame.PendingInvitesHeaderButton:Hide()
	
	for i = 1, numButtons do
		local button = buttons[i]
		local index = offset + i

		if ( index <= numFriendButtons ) then
			button.index = index
			local height = FriendGroups_UpdateFriendButton(button)
			button:SetHeight(height)
			usedHeight = usedHeight + height
		else
			button.index = nil
			button:Hide()
		end
	end

	HybridScrollFrame_Update(scrollFrame, scrollFrame.totalFriendListEntriesHeight, usedHeight)

	if hooks["FriendsFrame_UpdateFriends"] then
		hooks["FriendsFrame_UpdateFriends"]()
	end

	-- Delete unused groups in the collapsed part
	for key,_ in pairs(FriendGroups_SavedVars.collapsed) do
		if not GroupTotal[key] then
			FriendGroups_SavedVars.collapsed[key] = nil
		end
	end
end

local function FillGroups(groups, note, ...)
	wipe(groups)
	local n = select('#', ...)
	for i = 1, n do
		local v = select(i, ...)
		v = strtrim(v)
		groups[v] = true
	end
	if n == 0 then
		groups[""] = true
	end
	return note
end

local function NoteAndGroups(note, groups)
	if not note then
		return FillGroups(groups, "")
	end
	if groups then
		return FillGroups(groups, strsplit("#", note))
	end
	return strsplit("#", note)
end

local function CreateNote(note, groups)
	local value = ""
	if note then
		value = note
	end
	for group in pairs(groups) do
		value = value .. "#" .. group
	end
	return value
end

local function AddGroup(note, group)
	local groups = {}
	note = NoteAndGroups(note, groups)
	groups[""] = nil --ew
	groups[group] = true
	return CreateNote(note, groups)
end

local function RemoveGroup(note, group)
	local groups = {}
	note = NoteAndGroups(note, groups)
	groups[""] = nil --ew
	groups[group] = nil
	return CreateNote(note, groups)
end

local function IncrementGroup(group, online)
	if not GroupTotal[group] then
		GroupCount = GroupCount + 1
		GroupTotal[group] = 0
		GroupOnline[group] = 0
	end
	GroupTotal[group] = GroupTotal[group] + 1
	if online then
		GroupOnline[group] = GroupOnline[group] + 1
	end
end

local function sortButtonsByStatus()
	local newOrderInGroups = {}
	local sortRangeInGroups = {}
	local groupOrder = {}
	local currentGroup, isBNET, isWOW
	local friendId

	for buttonIndex, buttonInfo in pairs(FriendButtons) do
		if buttonIndex ~= "count" then
			if buttonInfo.buttonType ~= FRIENDS_BUTTON_TYPE_INVITE then
				if buttonInfo.buttonType == FRIENDS_BUTTON_TYPE_DIVIDER then
					currentGroup = buttonInfo.text
					if not newOrderInGroups[currentGroup] then
						newOrderInGroups[currentGroup] = {{},{},{},{}}
					end
					if not sortRangeInGroups[currentGroup] then
						sortRangeInGroups[currentGroup] = {}
					end
				else
					isBNET = (buttonInfo.buttonType == FRIENDS_BUTTON_TYPE_BNET)
					isWOW = (buttonInfo.buttonType == FRIENDS_BUTTON_TYPE_WOW)
					friendId = buttonInfo.id
					
					if isBNET then
						local isOnline = select(6,GetFriendInfoById(friendId))
						local isDND = select(14,GetFriendInfoById(friendId))
						local isAFK = select(12,GetFriendInfoById(friendId))
						local isGameAFK = select(13,GetFriendInfoById(friendId))
						local mobile = select(16,GetFriendInfoById(friendId))
						local client = select(8,GetFriendInfoById(friendId))
					
						if isOnline then
							if isDND then
								table.insert(newOrderInGroups[currentGroup][2], buttonInfo)
							elseif isAFK or isGameAFK or mobile or client == "BSAp" then
								table.insert(newOrderInGroups[currentGroup][3], buttonInfo)
							else
								table.insert(newOrderInGroups[currentGroup][1], buttonInfo)
							end
						else
							table.insert(newOrderInGroups[currentGroup][4], buttonInfo)
						end
						table.insert(sortRangeInGroups[currentGroup], buttonIndex)
					elseif isWOW then
						local isOnline = select(1,C_FriendList.GetFriendInfoByIndex(friendId))
						local isDND = select(8,C_FriendList.GetFriendInfoByIndex(friendId))
						local isAFK = select(9,C_FriendList.GetFriendInfoByIndex(friendId))
						local mobile = select(11,C_FriendList.GetFriendInfoByIndex(friendId))
						
						if isOnline then
							if isDND then
								table.insert(newOrderInGroups[currentGroup][2], buttonInfo)
							elseif isAFK then
								table.insert(newOrderInGroups[currentGroup][3], buttonInfo)
							else
								table.insert(newOrderInGroups[currentGroup][1], buttonInfo)
							end
						else
							table.insert(newOrderInGroups[currentGroup][4], buttonInfo)
						end
						table.insert(sortRangeInGroups[currentGroup], buttonIndex)
					end
				end
			end
		end
	end
	
	for groupName, onlineStatusTables in pairs(newOrderInGroups) do
		groupOrder[groupName] = {}
		for _, onlineStatusTable in ipairs(onlineStatusTables) do
			for _, friendButtonInfo in ipairs(onlineStatusTable) do
				table.insert(groupOrder[groupName], friendButtonInfo)
			end
		end
	end
	
	for groupName, groupSortRange in pairs(sortRangeInGroups) do
		for i, buttonIndex in ipairs(groupSortRange) do
			FriendButtons[buttonIndex] = groupOrder[groupName][i]
		end
	end	
end

local function FriendGroups_SearchByParam(friendType, friendId)
	
	local valid
	local returnValue
	local nameText
	local searchValue = FriendGroupsSearchValue:lower()
	
	if FriendGroupsSearchValue == "" then return true end
	
	if friendType == FRIENDS_BUTTON_TYPE_BNET then
		local accountName, characterName, class, level, isFavoriteFriend, isOnline,
			bnetAccountId, client, canCoop, wowProjectID, lastOnline,
			isAFK, isGameAFK, isDND, isGameBusy, mobile, zoneName, gameText, battleTag = GetFriendInfoById(friendId)

		nameText = FriendGroups_GetBNetButtonNameText(accountName, client, canCoop, characterName, class, level, battleTag)
	elseif friendType == FRIENDS_BUTTON_TYPE_WOW then
		local info = C_FriendList.GetFriendInfoByIndex(friendId)
		
		if FriendGroups_SavedVars.hide_high_level and info.level == currentExpansionMaxLevel then
			nameText = info.name..", "..info.className
		else
			nameText = info.name..", "..format(FRIENDS_LEVEL_TEMPLATE, info.level, info.className)
		end
	end
	
	nameText = nameText:lower()
	valid = nameText:find(searchValue, 1, true)
	
	if valid then
		returnValue = true
	else
		returnValue = false
	end
	
	return returnValue
	
end

local function FriendGroups_Update(forceUpdate)
	local numBNetTotal, numBNetOnline, numBNetFavorite, numBNetFavoriteOnline = BNGetNumFriends()
	numBNetFavorite = numBNetFavorite or 0
	numBNetFavoriteOnline = numBNetFavoriteOnline or 0
	local numBNetOffline = numBNetTotal - numBNetOnline
	local numBNetFavoriteOffline = numBNetFavorite - numBNetFavoriteOnline
	local numWoWTotal = C_FriendList.GetNumFriends()
	local numWoWOnline = C_FriendList.GetNumOnlineFriends()
	local numWoWOffline = numWoWTotal - numWoWOnline

	if QuickJoinToastButton then
		QuickJoinToastButton:UpdateDisplayedFriendCount()
	end
	if ( not FriendsListFrame:IsShown() and not forceUpdate) then
		return
	end

	wipe(FriendButtons)
	wipe(GroupTotal)
	wipe(GroupOnline)
	wipe(GroupSorted)
	GroupCount = 0

	local BnetFriendGroups = {}
	local WowFriendGroups = {}
	local FriendReqGroup = {}

	local buttonCount = 0

	FriendButtons.count = 0
	local addButtonIndex = 0
	local totalButtonHeight = 0
	local function AddButtonInfo(buttonType, id)
		addButtonIndex = addButtonIndex + 1
		if ( not FriendButtons[addButtonIndex] ) then
			FriendButtons[addButtonIndex] = { }
		end
		FriendButtons[addButtonIndex].buttonType = buttonType
		FriendButtons[addButtonIndex].id = id
		FriendButtons.count = FriendButtons.count + 1
		totalButtonHeight = totalButtonHeight + FRIENDS_BUTTON_HEIGHTS[buttonType]
	end

	-- invites
	local numInvites = BNGetNumFriendInvites()
	if ( numInvites > 0 ) then
		for i = 1, numInvites do
			if not FriendReqGroup[i] then
				FriendReqGroup[i] = {}
			end
			IncrementGroup(FriendRequestString,true)
			NoteAndGroups(nil, FriendReqGroup[i])
			if not FriendGroups_SavedVars.collapsed[group] then
				buttonCount = buttonCount + 1
				AddButtonInfo(FRIENDS_BUTTON_TYPE_INVITE, i)
			end
		end
	end

	-- favorite friends online
	for i = 1, numBNetFavoriteOnline do
		local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
		local client = select(8,GetFriendInfoById(i))
		local noteText;
		
		if accountInfo and accountInfo.note then
			noteText = accountInfo.note;
		end
		
		if (FriendGroups_SavedVars.show_search and FriendGroups_SearchByParam(FRIENDS_BUTTON_TYPE_BNET, i)) or not FriendGroups_SavedVars.show_search then
			if (FriendGroups_SavedVars.ingame_only and client == BNET_CLIENT_WOW) or not FriendGroups_SavedVars.ingame_only then
				if not BnetFriendGroups[i] then
					BnetFriendGroups[i] = {}
				end
				
				NoteAndGroups(noteText, BnetFriendGroups[i])
				
				for group in pairs(BnetFriendGroups[i]) do
					IncrementGroup(group, true)
					if not FriendGroups_SavedVars.collapsed[group] then
						buttonCount = buttonCount + 1
						AddButtonInfo(FRIENDS_BUTTON_TYPE_BNET, i)
					end
				end
			end
		end
	end
	
	--favorite friends offline
	for i = 1, numBNetFavoriteOffline do
		local j = i + numBNetFavoriteOnline
		local accountInfo = C_BattleNet.GetFriendAccountInfo(j)
		local client = select(8,GetFriendInfoById(j))
		local noteText;
		
		if accountInfo and accountInfo.note then
			noteText = accountInfo.note;
		end
		
		if (FriendGroups_SavedVars.show_search and FriendGroups_SearchByParam(FRIENDS_BUTTON_TYPE_BNET, j)) or not FriendGroups_SavedVars.show_search then
			if (FriendGroups_SavedVars.ingame_only and client == BNET_CLIENT_WOW) or not FriendGroups_SavedVars.ingame_only then
				if not BnetFriendGroups[j] then
					BnetFriendGroups[j] = {}
				end
				
				NoteAndGroups(noteText, BnetFriendGroups[j])
				for group in pairs(BnetFriendGroups[j]) do
					IncrementGroup(group)
					 if not FriendGroups_SavedVars.collapsed[group] and not FriendGroups_SavedVars.hide_offline then
						buttonCount = buttonCount + 1
						AddButtonInfo(FRIENDS_BUTTON_TYPE_BNET, j)
					end
				end
			end
		end
	end
	-- online Battlenet friends
	for i = 1, numBNetOnline - numBNetFavoriteOnline do
		local j = i + numBNetFavorite
		local accountInfo = C_BattleNet.GetFriendAccountInfo(j)
		local noteText;
		local client = select(8,GetFriendInfoById(j))
		
		if accountInfo then
			noteText = accountInfo.note
		end
		
		if (FriendGroups_SavedVars.show_search and FriendGroups_SearchByParam(FRIENDS_BUTTON_TYPE_BNET, j)) or not FriendGroups_SavedVars.show_search then
			if (FriendGroups_SavedVars.ingame_only and client == BNET_CLIENT_WOW) or not FriendGroups_SavedVars.ingame_only then
				if not BnetFriendGroups[j] then
					BnetFriendGroups[j] = {}
				end
				
				NoteAndGroups(noteText, BnetFriendGroups[j])
				for group in pairs(BnetFriendGroups[j]) do
					IncrementGroup(group, true)
					 if not FriendGroups_SavedVars.collapsed[group] then
						buttonCount = buttonCount + 1
						AddButtonInfo(FRIENDS_BUTTON_TYPE_BNET, j)
					end
				end
			end
		end
	end
	-- online WoW friends
	for i = 1, numWoWOnline do
		if (FriendGroups_SavedVars.show_search and FriendGroups_SearchByParam(FRIENDS_BUTTON_TYPE_WOW, i)) or not FriendGroups_SavedVars.show_search then
			if not WowFriendGroups[i] then
				WowFriendGroups[i] = {}
			end
			local note = C_FriendList.GetFriendInfoByIndex(i) and C_FriendList.GetFriendInfoByIndex(i).notes
			NoteAndGroups(note, WowFriendGroups[i])
			for group in pairs(WowFriendGroups[i]) do
				IncrementGroup(group, true)
				if not FriendGroups_SavedVars.collapsed[group] then
					buttonCount = buttonCount + 1
					AddButtonInfo(FRIENDS_BUTTON_TYPE_WOW, i)
				end
			end
		end
	end
	-- offline Battlenet friends
	for i = 1, numBNetOffline - numBNetFavoriteOffline do
		local j = i + numBNetFavorite + numBNetOnline - numBNetFavoriteOnline
		local accountInfo = C_BattleNet.GetFriendAccountInfo(j)
		local client = select(8,GetFriendInfoById(j))
		local noteText;
		
		if accountInfo and accountInfo.note then
			noteText = accountInfo.note;
		end
		
		if (FriendGroups_SavedVars.show_search and FriendGroups_SearchByParam(FRIENDS_BUTTON_TYPE_BNET, j)) or not FriendGroups_SavedVars.show_search then
			if (FriendGroups_SavedVars.ingame_only and client == BNET_CLIENT_WOW) or not FriendGroups_SavedVars.ingame_only then
				if not BnetFriendGroups[j] then
					BnetFriendGroups[j] = {}
				end
				
				NoteAndGroups(noteText, BnetFriendGroups[j])
				for group in pairs(BnetFriendGroups[j]) do
					IncrementGroup(group)
					 if not FriendGroups_SavedVars.collapsed[group] and not FriendGroups_SavedVars.hide_offline then
						buttonCount = buttonCount + 1
						AddButtonInfo(FRIENDS_BUTTON_TYPE_BNET, j)
					end
				end
			end
		end
	end
	-- offline WoW friends
	for i = 1, numWoWOffline do
		local j = i + numWoWOnline
		local note = C_FriendList.GetFriendInfoByIndex(j) and C_FriendList.GetFriendInfoByIndex(j).notes
		
		if (FriendGroups_SavedVars.show_search and FriendGroups_SearchByParam(FRIENDS_BUTTON_TYPE_WOW, j)) or not FriendGroups_SavedVars.show_search then
			if not FriendGroups_SavedVars.ingame_only then
				if not WowFriendGroups[j] then
					WowFriendGroups[j] = {}
				end
				
				NoteAndGroups(note, WowFriendGroups[j])
				for group in pairs(WowFriendGroups[j]) do
					IncrementGroup(group)
					if not FriendGroups_SavedVars.collapsed[group] and not FriendGroups_SavedVars.hide_offline then
						buttonCount = buttonCount + 1
						AddButtonInfo(FRIENDS_BUTTON_TYPE_WOW, j)
					end
				end
			end
		end
	end
	
	buttonCount = buttonCount + GroupCount
	if FriendGroups_SavedVars.show_search then
		GroupCount = GroupCount + 1
	end
	-- 1.5 is a magic number which prevents the list scroll to be too long
	totalScrollHeight = totalButtonHeight + GroupCount * FRIENDS_BUTTON_HEIGHTS[FRIENDS_BUTTON_TYPE_DIVIDER]

	FriendsScrollFrame.totalFriendListEntriesHeight = totalScrollHeight
	FriendsScrollFrame.numFriendListEntries = addButtonIndex

	if buttonCount > #FriendButtons then
		for i = #FriendButtons + 1, buttonCount do
			FriendButtons[i] = {}
		end
	end
	
	for group in pairs(GroupTotal) do
		table.insert(GroupSorted, group)
	end

	table.sort(GroupSorted)

	if GroupSorted[1] == "" then
		table.remove(GroupSorted, 1)
		table.insert(GroupSorted, "")
	end

	for key,val in pairs(GroupSorted) do
		if val == FriendRequestString then
			table.remove(GroupSorted,key)
			table.insert(GroupSorted,1,FriendRequestString)
		end
	end
	
	local index
	
	if FriendGroups_SavedVars.show_search then
		index = 1
		
		table.insert(FriendButtons, 1, {buttonType = FRIENDS_BUTTON_TYPE_DIVIDER, text = "Search..."})
	else
		index = 0
	end
	
	for _,group in ipairs(GroupSorted) do
		index = index + 1
		if FriendButtons[index] then
			FriendButtons[index].buttonType = FRIENDS_BUTTON_TYPE_DIVIDER
			FriendButtons[index].text = group
			if not FriendGroups_SavedVars.collapsed[group] then
				for i = 1, #FriendReqGroup do
					if group == FriendRequestString then
						index = index + 1
						FriendButtons[index].buttonType = FRIENDS_BUTTON_TYPE_INVITE
						FriendButtons[index].id = i
					end
				end
				for i = 1, numBNetFavoriteOnline do
					if BnetFriendGroups[i] and BnetFriendGroups[i][group] then
						index = index + 1
						FriendButtons[index].buttonType = FRIENDS_BUTTON_TYPE_BNET
						FriendButtons[index].id = i
					end
				end
				for i = numBNetFavorite + 1, numBNetOnline + numBNetFavoriteOffline do
					if BnetFriendGroups[i] and BnetFriendGroups[i][group] then
						index = index + 1
						FriendButtons[index].buttonType = FRIENDS_BUTTON_TYPE_BNET
						FriendButtons[index].id = i
					end
				end
				for i = 1, numWoWOnline do
					if WowFriendGroups[i] and WowFriendGroups[i][group] then
						index = index + 1
						FriendButtons[index].buttonType = FRIENDS_BUTTON_TYPE_WOW
						FriendButtons[index].id = i
					end
				end
				if not FriendGroups_SavedVars.hide_offline and not FriendGroups_SavedVars.ingame_only then
					for i = numBNetFavoriteOnline + 1, numBNetFavorite do
						if BnetFriendGroups[i] and BnetFriendGroups[i][group] then
							index = index + 1
							FriendButtons[index].buttonType = FRIENDS_BUTTON_TYPE_BNET
							FriendButtons[index].id = i
						end
					end
					for i = numBNetOnline + numBNetFavoriteOffline + 1, numBNetTotal do
						if BnetFriendGroups[i] and BnetFriendGroups[i][group] then
							index = index + 1
							FriendButtons[index].buttonType = FRIENDS_BUTTON_TYPE_BNET
							FriendButtons[index].id = i
						end
					end
					for i = numWoWOnline + 1, numWoWTotal do
						if WowFriendGroups[i] and WowFriendGroups[i][group] then
							index = index + 1
							FriendButtons[index].buttonType = FRIENDS_BUTTON_TYPE_WOW
							FriendButtons[index].id = i
						end
					end
				end
			end
		end
	end
	FriendButtons.count = index
	
	if FriendGroups_SavedVars.sort_by_status then sortButtonsByStatus() end

	-- selection
	local selectedFriend = 0
	-- check that we have at least 1 friend
	if numBNetTotal + numWoWTotal > 0 then
		-- get friend
		if FriendsFrame.selectedFriendType == FRIENDS_BUTTON_TYPE_WOW then
			selectedFriend = C_FriendList.GetSelectedFriend()
		elseif FriendsFrame.selectedFriendType == FRIENDS_BUTTON_TYPE_BNET then
			selectedFriend = BNGetSelectedFriend()
		end
		-- set to first in list if no friend
		if not selectedFriend or selectedFriend == 0 then
			FriendsFrame_SelectFriend(FriendButtons[1].buttonType, 1)
			selectedFriend = 1
		end
		-- check if friend is online
		FriendsFrameSendMessageButton:SetEnabled(FriendsList_CanWhisperFriend(FriendsFrame.selectedFriendType, selectedFriend))
	else
		FriendsFrameSendMessageButton:Disable()
	end
	FriendsFrame.selectedFriend = selectedFriend

	-- RID warning, upon getting the first RID invite
	local showRIDWarning = false
	local numInvites = BNGetNumFriendInvites()
	if ( numInvites > 0 and not GetCVarBool("pendingInviteInfoShown") ) then
		local _, _, _, _, _, _, isRIDEnabled = BNGetInfo()
		if ( isRIDEnabled ) then
			for i = 1, numInvites do
				local inviteID, accountName, isBattleTag = BNGetFriendInviteInfo(i)
				if ( not isBattleTag ) then
					-- found one
					showRIDWarning = true
					break
				end
			end
		end
	end
	if showRIDWarning then
		FriendsListFrame.RIDWarning:Show()
		FriendsScrollFrame.scrollBar:Disable()
		FriendsScrollFrame.scrollUp:Disable()
		FriendsScrollFrame.scrollDown:Disable()
	else
		FriendsListFrame.RIDWarning:Hide()
	end

	FriendGroups_UpdateFriends()
end

local function FriendGroups_SaveOpenMenu()
	if OPEN_DROPDOWNMENUS then
		OPEN_DROPDOWNMENUS_SAVE = CopyTable(OPEN_DROPDOWNMENUS)
	end
end

-- when one of our new menu items is clicked
local function FriendGroups_OnFriendMenuClick(self)
	if not self.value then
		return
	end

	local add = strmatch(self.value, "FGROUPADD_(.+)")
	local del = strmatch(self.value, "FGROUPDEL_(.+)")
	local creating = self.value == "FRIEND_GROUP_NEW"

	if add or del or creating then
		local dropdown = UIDROPDOWNMENU_INIT_MENU
		local source = OPEN_DROPDOWNMENUS_SAVE[1] and OPEN_DROPDOWNMENUS_SAVE[1].which or self.owner -- OPEN_DROPDOWNMENUS is nil on click

		if source == "BN_FRIEND" or source == "BN_FRIEND_OFFLINE" then
			local accountInfo = C_BattleNet.GetAccountInfoByID(dropdown.bnetIDAccount)
			local note;
		
			if accountInfo and accountInfo.note then
				note = accountInfo.note;
			end

			if creating then
				StaticPopup_Show("FRIEND_GROUP_CREATE", nil, nil, { id = dropdown.bnetIDAccount, note = note, set = BNSetFriendNote })
			else
				if add then
					note = AddGroup(note, add)
				else
					note = RemoveGroup(note, del)
				end
				BNSetFriendNote(dropdown.bnetIDAccount, note)
			end
		elseif source == "FRIEND" or source == "FRIEND_OFFLINE" then
			for i = 1, C_FriendList.GetNumFriends() do
				local friend_info = C_FriendList.GetFriendInfoByIndex(i)
				local name = friend_info.name
				local note = friend_info.notes
				if dropdown.name and name:find(dropdown.name) then
					if creating then
						StaticPopup_Show("FRIEND_GROUP_CREATE", nil, nil, { id = i, note = note, set = C_FriendList.SetFriendNotes })
					else
						if add then
							note = AddGroup(note, add)
						else
							note = RemoveGroup(note, del)
						end
						C_FriendList.SetFriendNotes(name, note)
					end
					break
				end
			end
		end
		FriendGroups_Update()
	end
	HideDropDownMenu(1)
end

-- hide the add/remove group buttons if we're not right clicking on a friendlist item
local function FriendGroups_HideButtons()
	local dropdown = UIDROPDOWNMENU_INIT_MENU
	
	local hidden = false
	for index, value in ipairs(UnitPopupMenus[UIDROPDOWNMENU_MENU_VALUE] or UnitPopupMenus[dropdown.which]) do
		if value == "FRIEND_GROUP_ADD" or value == "FRIEND_GROUP_DEL" or value == "FRIEND_GROUP_NEW" then
			if not dropdown.friendsList then
				UnitPopupShown[UIDROPDOWNMENU_MENU_LEVEL][index] = 0
				hidden = true
			end
		end
	end

	if not hidden then
		wipe(UnitPopupMenus["FRIEND_GROUP_ADD"])
		wipe(UnitPopupMenus["FRIEND_GROUP_DEL"])
		local groups = {}
		local note = nil
		
		if dropdown.bnetIDAccount then
			local accountInfo = C_BattleNet.GetAccountInfoByID(dropdown.bnetIDAccount)
			
			if accountInfo and accountInfo.note then
				note = accountInfo.note
			end
		else
			for i = 1, C_FriendList.GetNumFriends() do
				local friend_info = C_FriendList.GetFriendInfoByIndex(i)
				local name = friend_info.name
				local noteText = friend_info.notes
				if dropdown.name and name:find(dropdown.name) then
					note = noteText
					break
				end
			end
		end
		
		NoteAndGroups(note, groups)

		for _,group in ipairs(GroupSorted) do
			if group ~= "" and not groups[group] then
				local faux = "FGROUPADD_" .. group
				--polluting the popup buttons list
				UnitPopupButtons[faux] = { text = group}
				table.insert(UnitPopupMenus["FRIEND_GROUP_ADD"], faux)
			end
		end
		for group in pairs(groups) do
			if group ~= "" then
				local faux = "FGROUPDEL_" .. group
				UnitPopupButtons[faux] = { text = group}
				table.insert(UnitPopupMenus["FRIEND_GROUP_DEL"], faux)
			end
		end
	end
end

local function FriendGroups_Rename(self, old)
	local input = self.editBox:GetText()
	if input == "" then
		return
	end
	local groups = {}
	for i = 1, BNGetNumFriends() do
		local presenceID = C_BattleNet.GetFriendAccountInfo(i).bnetAccountID
		local noteText = C_BattleNet.GetFriendAccountInfo(i).note
		local note = NoteAndGroups(noteText, groups)
		if groups[old] then
			groups[old] = nil
			groups[input] = true
			note = CreateNote(note, groups)
			BNSetFriendNote(presenceID, note)
		end
	end
	for i = 1, C_FriendList.GetNumFriends() do
		local note = C_FriendList.GetFriendInfoByIndex(i).notes
		local name = C_FriendList.GetFriendInfoByIndex(i).name
		if groups[old] then
			groups[old] = nil
			groups[input] = true
			note = CreateNote(note, groups)
			C_FriendList.SetFriendNotes(name, note)
		end
	end
	FriendGroups_Update()
end

local function FriendGroups_Create(self, data)
	local input = self.editBox:GetText()
	if input == "" then
		return
	end
	local note = AddGroup(data.note, input)
	data.set(data.id, note)
end

StaticPopupDialogs["FRIEND_GROUP_RENAME"] = {
	text = "Enter new group name",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	OnAccept = FriendGroups_Rename,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		FriendGroups_Rename(parent, parent.data)
		parent:Hide()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1
}

StaticPopupDialogs["FRIEND_GROUP_CREATE"] = {
	text = "Enter new group name",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	OnAccept = FriendGroups_Create,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		FriendGroups_Create(parent, parent.data)
		parent:Hide()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1
}

local function InviteOrGroup(clickedgroup, invite)
	local groups = {}
	for i = 1, BNGetNumFriends() do
		local friendAccountInfo = C_BattleNet.GetFriendAccountInfo(i)
		local presenceID = friendAccountInfo.bnetAccountID
		local noteText = friendAccountInfo.note
		local gameAccountInfo = friendAccountInfo.gameAccountInfo
		local note = NoteAndGroups(noteText, groups)
		
		if gameAccountInfo and gameAccountInfo.isOnline then
			local toonID = gameAccountInfo.gameAccountID
			if groups[clickedgroup] then
				if invite and toonID then
					BNInviteFriend(toonID)
				elseif not invite then
					groups[clickedgroup] = nil
					note = CreateNote(note, groups)
					BNSetFriendNote(presenceID, note)
				end
			end
		end
	end
	for i = 1, C_FriendList.GetNumFriends() do
		local friend_info = C_FriendList.GetFriendInfoByIndex(i)
		local name = friend_info.name
		local connected = friend_info.connected
		local noteText = friend_info.notes
		local note = NoteAndGroups(noteText, groups)
		if groups[clickedgroup] then
			if invite and connected then
				InviteUnit(name)
			elseif not invite then
				groups[clickedgroup] = nil
				note = CreateNote(note, groups)
				C_FriendList.SetFriendNotes(name, note)
			end
		end
	end
end

local FriendGroups_Menu = CreateFrame("Frame", "FriendGroups_Menu")
FriendGroups_Menu.displayMode = "MENU"
local menu_items = {
	[1] = {
		{ text = "", notCheckable = true, isTitle = true },
		{ text = "Invite all to party", notCheckable = true, func = function(self, menu, clickedgroup) InviteOrGroup(clickedgroup, true) end },
		{ text = "Rename group", notCheckable = true, func = function(self, menu, clickedgroup) StaticPopup_Show("FRIEND_GROUP_RENAME", nil, nil, clickedgroup) end },
		{ text = "Remove group", notCheckable = true, func = function(self, menu, clickedgroup) InviteOrGroup(clickedgroup, false) end },
		{ text = "Settings", notCheckable = true, hasArrow = true },
	},
	[2] = {
		{ text = "Hide all offline", checked = function() return FriendGroups_SavedVars.hide_offline end, func = function() CloseDropDownMenus() FriendGroups_SavedVars.hide_offline = not FriendGroups_SavedVars.hide_offline FriendGroups_Update() end },
		{ text = "Hide level of max level players", checked = function() return FriendGroups_SavedVars.hide_high_level end, func = function() CloseDropDownMenus() FriendGroups_SavedVars.hide_high_level = not FriendGroups_SavedVars.hide_high_level FriendGroups_Update() end },
		{ text = "Colour names", checked = function() return FriendGroups_SavedVars.colour_classes end, func = function() CloseDropDownMenus() FriendGroups_SavedVars.colour_classes = not FriendGroups_SavedVars.colour_classes FriendGroups_Update() end },
		{ text = "Show Mobile always as AFK", checked = function() return FriendGroups_SavedVars.show_mobile_afk end, func = function() CloseDropDownMenus() FriendGroups_SavedVars.show_mobile_afk = not FriendGroups_SavedVars.show_mobile_afk FriendGroups_Update() end },
		{ text = "Add Mobile Text", checked = function() return FriendGroups_SavedVars.add_mobile_text end, func = function() CloseDropDownMenus() FriendGroups_SavedVars.add_mobile_text = not FriendGroups_SavedVars.add_mobile_text FriendGroups_Update() end },
		{ text = "Show only Ingame Friends", checked = function() return FriendGroups_SavedVars.ingame_only end, func = function() CloseDropDownMenus() FriendGroups_SavedVars.ingame_only = not FriendGroups_SavedVars.ingame_only FriendGroups_Update() end },
		{ text = "Show only BattleTag", checked = function() return FriendGroups_SavedVars.show_btag end, func = function() CloseDropDownMenus() FriendGroups_SavedVars.show_btag = not FriendGroups_SavedVars.show_btag FriendGroups_Update() end },
		{ text = "Sort by status", checked = function() return FriendGroups_SavedVars.sort_by_status end, func = function() CloseDropDownMenus() FriendGroups_SavedVars.sort_by_status = not FriendGroups_SavedVars.sort_by_status FriendGroups_Update() end },
		{ text = "Enable Search", checked = function() return FriendGroups_SavedVars.show_search end, func = function() CloseDropDownMenus() FriendGroups_SavedVars.show_search = not FriendGroups_SavedVars.show_search FriendGroups_Update() end },
	},
}

FriendGroups_Menu.initialize = function(self, level)
	if not menu_items[level] then return end
	for _, items in ipairs(menu_items[level]) do
		local info = UIDropDownMenu_CreateInfo()
		for prop, value in pairs(items) do
			info[prop] = value ~= "" and value or UIDROPDOWNMENU_MENU_VALUE ~= "" and UIDROPDOWNMENU_MENU_VALUE or "[no group]"
		end
		info.arg1 = k
		info.arg2 = UIDROPDOWNMENU_MENU_VALUE
		UIDropDownMenu_AddButton(info, level)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")

local function FriendGroups_OnClick(self, button)
	if self["text"] and not self.text:IsShown() then
		hooks["FriendsFrameFriendButton_OnClick"](self, button)
		return
	end
	
	if self.buttonType ~= FRIENDS_BUTTON_TYPE_DIVIDER then
		if FriendsListButtonMixin then
			FriendsListButtonMixin.OnClick(self, button)
			return
		end
	end
	
	local group = self.info:GetText() or ""
	if button == "RightButton" and group ~= "Search..." then
		ToggleDropDownMenu(1, group, FriendGroups_Menu, "cursor", 0, 0)
	elseif button == "LeftButton" and group == "Search..." then
		FriendGroupsSearchOpened = true
		self.name:SetText("")
		local searchBox = CreateFrame("EditBox", "FriendGroupsSearch", self)
		searchBox:SetSize((self:GetWidth() / 1.5), FRIENDS_BUTTON_HEIGHTS[FRIENDS_BUTTON_TYPE_DIVIDER])
		searchBox:SetFontObject("ChatFontNormal")
        searchBox:SetScript("OnEscapePressed", function()
			searchBox:Hide()
			FriendGroupsSearchOpened = false
			FriendGroupsSearchValue = ""
			FriendGroups_Update()
		end)
		searchBox:SetScript("OnEditFocusLost", function()
			searchBox:Hide()
			FriendGroupsSearchOpened = false
			FriendGroups_Update()
		end)
		searchBox:SetScript("OnEnterPressed", function()
			searchBox:Hide()
			FriendGroupsSearchOpened = false
			FriendGroups_Update()
		end)
		searchBox:SetScript("OnTextChanged", function(searchBox)
			local searchValue = searchBox:GetText()
			
			if searchValue then
				FriendGroupsSearchValue = searchValue
				FriendGroups_Update()
			end
		end)
		searchBox:SetPoint("CENTER", self, "CENTER");
		searchBox:SetAutoFocus(false);
		searchBox:SetCursorPosition(1)
		searchBox:SetFocus(true)
		searchBox:SetText(FriendGroupsSearchValue)
	else
		FriendGroups_SavedVars.collapsed[group] = not FriendGroups_SavedVars.collapsed[group]
		FriendGroups_Update()
	end
end

local function FriendGroups_OnEnter(self)
	if ( self.buttonType == FRIENDS_BUTTON_TYPE_DIVIDER ) then
		if FriendsTooltip:IsShown() then
			FriendsTooltip:Hide()
		end
		return
	end
end
local function HookButtons()
	local scrollFrame = FriendsScrollFrame
	local buttons = scrollFrame.buttons
	local numButtons = #buttons
	for i = 1, numButtons do
		if not FriendsFrameFriendButton_OnClick then
			buttons[i]:SetScript("OnClick", FriendGroups_OnClick)
		end
		if not FriendsFrameTooltip_Show then
			buttons[i]:HookScript("OnEnter", FriendGroups_OnEnter)
		end
	end
end

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		Hook("FriendsList_Update", FriendGroups_Update, true)
		--if other addons have hooked this, we should too
		if not issecurevariable("FriendsFrame_UpdateFriends") then
			Hook("FriendsFrame_UpdateFriends", FriendGroups_UpdateFriends)
		end
		Hook("UnitPopup_ShowMenu", FriendGroups_SaveOpenMenu, true)
		Hook("UnitPopup_OnClick", FriendGroups_OnFriendMenuClick, true)
		Hook("UnitPopup_HideButtons", FriendGroups_HideButtons, true)
		if FriendsFrameFriendButton_OnClick then
			Hook("FriendsFrameFriendButton_OnClick", FriendGroups_OnClick)
		end
		if FriendsFrameTooltip_Show then
			Hook("FriendsFrameTooltip_Show", FriendGroups_OnEnter, true)-- Fixes tooltip showing on groups
		end
		FriendsScrollFrame.dynamic = FriendGroups_GetTopButton
		FriendsScrollFrame.update = FriendGroups_UpdateFriends

		--add some more buttons
		FriendsScrollFrame.buttons[1]:SetHeight(FRIENDS_FRAME_FRIENDS_FRIENDS_HEIGHT)
		HybridScrollFrame_CreateButtons(FriendsScrollFrame, FriendButtonTemplate)

		table.remove(UnitPopupMenus["BN_FRIEND"], 5) --remove target option

		--add our add/remove group buttons to the friend list popup menus
		for _,menu in ipairs(friend_popup_menus) do
			table.insert(UnitPopupMenus[menu], #UnitPopupMenus[menu], "FRIEND_GROUP_NEW")
			table.insert(UnitPopupMenus[menu], #UnitPopupMenus[menu], "FRIEND_GROUP_ADD")
			table.insert(UnitPopupMenus[menu], #UnitPopupMenus[menu], "FRIEND_GROUP_DEL")
		end

		HookButtons()

		if not FriendGroups_SavedVars then
			FriendGroups_SavedVars = {
				collapsed = {},
				hide_offline = false,
				colour_classes = true,
				hide_high_level = false,
				show_mobile_afk = false,
				add_mobile_text = false,
				ingame_only = false,
				show_btag = false,
				sort_by_status = false,
				show_search = false
			}
		end
	end
end)
