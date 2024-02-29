if LibScrollableMenu ~= nil then return end -- the same or newer version of this lib is already loaded into memory

local lib = ZO_CallbackObject:New()
lib.name = "LibScrollableMenu"
local MAJOR = lib.name
lib.version = "1.9"

lib.data = {}

if not lib then return end

--Constant for the divider entryType
lib.DIVIDER = "-"
local libDivider = lib.DIVIDER

--TODO: remove or make use of --> lib.HELPER_MODE_NORMAL = 0
--TODO: remove or make use of --> lib.HELPER_MODE_LAYOUT_ONLY = 1 -- means only the layout of the dropdown will be altered, not the way it handles layering through ZO_Menus

--ZO_ComboBox changes with API101041 -> ZO_ComboBox uses a TLC for the dropdown now -> dropdownObject
--TODO: remove or make use of --> local APIVersion = GetAPIVersion()
--TODO: remove or make use of --> local apiVersionUpdate3_8 = 101041

--TODO: remove or make use of --> local isUsingDropdownObject = (APIVersion >= apiVersionUpdate3_8 and true) or false

--TODO: find out why submenu width shrinks slightly when moving back onto it from it's childMenu
--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--local speed up variables
local EM = EVENT_MANAGER
local SNM = SCREEN_NARRATION_MANAGER

local tos = tostring
local sfor = string.format
local tins = table.insert

--LibScrollableMenu XML template names
local LSM_XML_Template_Keyboard = MAJOR.. "_Keyboard_Template"

--Timeout data
local libTimeoutNextId = 1
local libTimeoutPattern = MAJOR.."Timeout"

--Sound settings
local origSoundComboClicked = SOUNDS.COMBO_CLICK
local soundComboClickedSilenced = SOUNDS.NONE

--Submenu settings
local SUBMENU_SHOW_TIMEOUT = 350
local submenuCallLaterHandle

--Custom scrollable menu settings (context menus e.g.)
--TODO: remove or make use of --> local CUSTOM_SCROLLABLE_MENU_NAME = MAJOR.."_CustomContextMenu"

--Menu settings (main and submenu)
--TODO: remove or make use of --> local MAX_MENU_ROWS = 25
--TODO: remove or make use of --> local MAX_MENU_WIDTH
local DEFAULT_VISIBLE_ROWS = 10
local DEFAULT_SORTS_ENTRIES = true --sort the entries in main- and submenu lists

--Entry type settings
local DIVIDER_ENTRY_HEIGHT = 7
local HEADER_ENTRY_HEIGHT = 30
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT -- same as in zo_comboBox.lua: 25
--TODO: remove or make use of --> local ICON_PADDING = 20
--TODO: remove or make use of --> local PADDING = GetMenuPadding() / 2 -- half the amount looks closer to the regular dropdown
local WITHOUT_ICON_LABEL_DEFAULT_OFFSETX = 4

local DEFAULT_FONT = "ZoFontGame"

--Entry types - For the scroll list's dataType of the menus
local ENTRY_ID = 1
local LAST_ENTRY_ID = 2
local DIVIDER_ENTRY_ID = 3
local HEADER_ENTRY_ID = 4
local SUBMENU_ENTRY_ID = 5
local CHECKBOX_ENTRY_ID = 6
local _DEFAULT_ENTRY_ID = ENTRY_ID

--The custom scrollable context menu entry types
lib.LSM_ENTRY_TYPE_NORMAL = 	ENTRY_ID
lib.LSM_ENTRY_TYPE_DIVIDER = 	DIVIDER_ENTRY_ID
lib.LSM_ENTRY_TYPE_HEADER = 	HEADER_ENTRY_ID
lib.LSM_ENTRY_TYPE_CHECKBOX = 	CHECKBOX_ENTRY_ID
--Add global variables
LSM_ENTRY_TYPE_NORMAL = 		lib.LSM_ENTRY_TYPE_NORMAL
LSM_ENTRY_TYPE_DIVIDER = 		lib.LSM_ENTRY_TYPE_DIVIDER
LSM_ENTRY_TYPE_HEADER = 		lib.LSM_ENTRY_TYPE_HEADER
LSM_ENTRY_TYPE_CHECKBOX = 		lib.LSM_ENTRY_TYPE_CHECKBOX


--Scrollable context menus (like ZO_Menu)
--The local "global" context menu variable
local g_contextMenu -- Will be creaed at onAddonLoaded, from class ContextMenuObject, which is a subclass of SubmenuObject, which is a subclass of DropdownObject_Base

local allowedEntryTypesForContextMenu = {
	[lib.LSM_ENTRY_TYPE_NORMAL] = 	true,
	[lib.LSM_ENTRY_TYPE_DIVIDER] = 	true,
	[lib.LSM_ENTRY_TYPE_HEADER] = 	true,
	[lib.LSM_ENTRY_TYPE_CHECKBOX] = true,
}

--Make them accessible for the DropdownObject:New options table -> options.XMLRowTemplates
lib.scrollListRowTypes = {
	ENTRY_ID = 						ENTRY_ID,
	LAST_ENTRY_ID = 				LAST_ENTRY_ID,
	DIVIDER_ENTRY_ID = 				DIVIDER_ENTRY_ID,
	HEADER_ENTRY_ID = 				HEADER_ENTRY_ID,
	SUBMENU_ENTRY_ID = 				SUBMENU_ENTRY_ID,
	CHECKBOX_ENTRY_ID = 			CHECKBOX_ENTRY_ID,
}

--Possible options passed in at the ScrollableHelper menus are:
local possibleLibraryOptions = {
	["visibleRowsDropdown"] = 		true,
	["visibleRowsSubmenu"] = 		true,
	["sortEntries"] = 				true,
	["XMLRowTemplates"] = 			true,
	["narrate"] = 					true,
}
lib.possibleLibraryOptions = possibleLibraryOptions

--The default values for the context menu options are:
local defaultContextMenuOptions  = {
	["visibleRowsDropdown"] = 		20,
	["visibleRowsSubmenu"] = 		20,
	["sortEntries"] = 				false,
}
lib.defaultContextMenuOptions  = defaultContextMenuOptions

--Textures
local iconNewIcon = ZO_KEYBOARD_NEW_ICON

--Narration
local UINarrationName = MAJOR .. "_UINarration_"
local UINarrationUpdaterName = MAJOR .. "_UINarrationUpdater_"

--Boolean to on/off texts for narration
--[[
local booleanToOnOff = {
	[false] = GetString(SI_CHECK_BUTTON_OFF):upper(),
	[true]  = GetString(SI_CHECK_BUTTON_ON):upper(),
}
]]
--MultiIcon
local iconNarrationNewValue = GetString(SI_SCREEN_NARRATION_NEW_ICON_NARRATION)


--------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------
-- >> data, dataEntry
local function getControlData(control)
	local data = control.m_sortedItems or control.m_data
	
	if data.dataSource then
		data = data:GetDataSource()
	end
	
	return data
end

-- >> template, height, setupFunction
local function getTemplateData(entryType, template)
	local templateDataForEntryType = template[entryType]
	return templateDataForEntryType.template, templateDataForEntryType.rowHeight, templateDataForEntryType.widthAdjust, templateDataForEntryType.setupFunc
end

local function clearTimeout()
	if submenuCallLaterHandle ~= nil then
		EM:UnregisterForUpdate(submenuCallLaterHandle)
		submenuCallLaterHandle = nil
	end
end

local function setTimeout(callback , ...)
	local params = {...}
	if submenuCallLaterHandle ~= nil then clearTimeout() end
	submenuCallLaterHandle =  libTimeoutPattern .. libTimeoutNextId
	libTimeoutNextId = libTimeoutNextId + 1

	--Delay the submenu close callback so we can move the mouse above a new submenu control and keep that opened e.g.
	--TODO: This isn't really used for that anymore. It's purpose is to provide a delay 
	-- if the mouse has moved outside of the dropdown controls. To give time to move back in.
	EM:RegisterForUpdate(submenuCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		clearTimeout()
		if callback then callback(unpack(params)) end
	end )
end


--Run function arg to get the return value (passing in ... as optional params to that function),
--or directly use non-function return value arg
local function getValueOrCallback(arg, ...)
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end

--Mix in table entries in other table and skip existing entries
local function mixinTableAndSkipExisting(object, ...)
	for i = 1, select("#", ...) do
		local source = select(i, ...)
		for k,v in pairs(source) do
			--Skip existing entries in
			if object[k] == nil then
				object[k] = v
			end
		end
	end
end

--Get the container of a control
local function getContainerFromControl(control)
	local owner = control.m_owner
	return owner and owner.m_container
end


--------------------------------------------------------------------
-- Local dropdown/entry functions
--------------------------------------------------------------------
--Get the options from a combobox, that belongs to the dropdown's item/entry
local function getOptionsForEntry(entry)
	local entrysComboBox = getContainerFromControl(entry)
	
	--[[ IsJustaGhost
		TODO: Would it be better to return {} if nil
		local options = entrysComboBox.options or {}
	]]
		
	return entrysComboBox ~= nil and entrysComboBox.options
end

--The default callback for the recursiveOverEntries function
local function defaultRecursiveCallback(_entry)
	return false
end

--Check if an entry got the isNew set
local function getIsNew(_entry)
	return getValueOrCallback(_entry.isNew, _entry) or false
end

-- Recursively loop over drdopdown entries, and submenu dropdown entries of that parent dropdown, and check if e.g. isNew needs to be updated
local function recursiveOverEntries(entry, callback)
	callback = callback or defaultRecursiveCallback
	
	local result = callback(entry)
	local submenu = entry.entries or {}

	--local submenuType = type(submenu)
	--assert(submenuType == 'table', sfor('[LibScrollableMenu:recursiveOverEntries] table expected, got %q = %s', "submenu", tos(submenuType)))

	if  type(submenu) == "table" and #submenu > 0 then
		for k, subEntry in pairs(submenu) do
			local subEntryResult = recursiveOverEntries(subEntry, callback)
			if subEntryResult then
				result = subEntryResult
			end
		end
	end
	return result
end

-- Recursively check for new entries in dropdowns (menus, submenus)
local function areAnyEntriesNew(entry)
	return recursiveOverEntries(entry, getIsNew)
end

--(Un)Silence the OnClicked sound of a selected dropdown
local function silenceComboBoxClickedSound(doSilence)
	doSilence = doSilence or false
	if doSilence == true then
		--Silence the "selected comboBox sound"
		SOUNDS.COMBO_CLICK = soundComboClickedSilenced
	else
		--Unsilence the "selected comboBox sound" again
		SOUNDS.COMBO_CLICK = origSoundComboClicked
	end
end

--Check if a sound should be played if a dropdown entry was selected
local function playSelectedSoundCheck(entry)
	silenceComboBoxClickedSound(false)

	local soundToPlay = origSoundComboClicked
	local options = getOptionsForEntry(entry)
	
	if options ~= nil then
		--Chosen at options to play no selected sound?
		if getValueOrCallback(options.selectedSoundDisabled, options) == true then
			silenceComboBoxClickedSound(true)
			return
		else
			soundToPlay = getValueOrCallback(options.selectedSound, options)
			soundToPlay = soundToPlay or SOUNDS.COMBO_CLICK
		end
	end
	PlaySound(soundToPlay) --SOUNDS.COMBO_CLICK
end

--Recursivley map the entries of a submenu and add them to the mapTable
--used for the callback "NewStatusUpdated" to provide the mapTable with the entries
local function doMapEntries(entryTable, mapTable)
	for k, entry in pairs(entryTable) do
		if entry.entries then
			doMapEntries(entry.entries, mapTable)
		end
		
		if entry.callback ~= nil then
			mapTable[entry] = entry
		end
	end
end


-- This function will create a map of all entries recursively. Useful when there are submenu entries
-- and you want to use them for comparing in the callbacks, NewStatusUpdated, CheckboxUpdated
local function mapEntries(entryTable, mapTable, blank)
	if blank ~= nil then
		entryTable = mapTable
		mapTable = blank
		blank = nil
	end
	
	local entryTableType, mapTableType = type(entryTable), type(mapTable)
	assert(entryTableType == 'table' and mapTableType == 'table' , sfor('[LibScrollableMenu:MapEntries] tables expected, got %q = %s, %q = %s', "entryTable", tos(entryTableType), "mapTable", tos(mapTableType)))
	
	-- Splitting these up so the above is not done each iteration
	doMapEntries(entryTable, mapTable)
end

-- Add/Remove the new status of a dropdown entry.
-- This works up from the mouse-over entry's submenu up to the dropdown,
-- as long as it does not run into a submenu still having a new entry.
local function updateSubmenuNewStatus(control)
--	d( '[LSM]updateSubmenuNewStatus')
	-- reverse parse
	local isNew = false
	
	local data = getControlData(control)
	local submenuEntries = data.entries or {}
	
	-- We are only going to check the current submenu's entries, not recursively
	-- down from here since we are working our way up until we find a new entry.
	for k, subentry in ipairs(submenuEntries) do
		if getIsNew(subentry) then
			isNew = true
		end
	end
	-- Set flag on submenu
	data.isNew = isNew
	if not isNew then
		ZO_ScrollList_RefreshVisible(control.m_dropdownObject.scrollControl)
			
		local parent = control.m_dropdownObject.parentControl
		if parent then
			updateSubmenuNewStatus(parent)
		end
	end
end

--Remove the new status of a dropdown entry
local function clearNewStatus(control, data)
--d( '[LSM]clearNewStatus')
--d( 'data.isNew ' .. tostring(data.isNew))
	if data.isNew then
		-- Only directly change status on non-submenu entries. The are effected by child entries
		if data.entries == nil then
			data.isNew = false
			
			lib:FireCallbacks('NewStatusUpdated', data, control)
			
			control.m_dropdownObject:Refresh(data)
			
			local parent = control.m_dropdownObject.parentControl
			if parent then
				updateSubmenuNewStatus(parent)
			end
		end
	end
end

--Update the icons of a dropdown entry's MultiIcon control
local function updateIcons(control, data)
	local isNewValue = getValueOrCallback(data.isNew, data)
	local iconData = getValueOrCallback(data.icon, data)
	--If only a "any.dds" texture was passed in
	if type(iconData) ~= 'table' then
		iconData = { iconTexture = iconData }
	end
	local iconValue = iconData ~= nil and getValueOrCallback(iconData.iconTexture, data)
	local visible = isNewValue == true or iconValue ~= nil

	local tooltipForIcon = getValueOrCallback(iconData.tooltip, data)
	local iconNarration = visible and iconData.iconNarration

	local multiIconContainerCtrl = control.m_iconContainer
	local multiIconCtrl = control.m_icon

	local parentHeight = multiIconCtrl:GetParent():GetHeight()
	local iconHeight = parentHeight
	-- This leaves a padding to keep the label from being too close to the edge
	local iconWidth = visible and iconHeight or WITHOUT_ICON_LABEL_DEFAULT_OFFSETX

	multiIconCtrl:ClearIcons()
	if visible == true then
		control.m_icon.data = control.m_icon.data or {}

		--Icon's height and width
		if iconData.width ~= nil then
			iconWidth = zo_clamp(getValueOrCallback(iconData.width, data), WITHOUT_ICON_LABEL_DEFAULT_OFFSETX, parentHeight)
		end
		if iconData.height ~= nil then
			iconHeight = zo_clamp(getValueOrCallback(iconData.height, data), WITHOUT_ICON_LABEL_DEFAULT_OFFSETX, parentHeight)
		end
		--Icon's color
		local iconTint = getValueOrCallback(iconData.iconTint, data)
		if type(iconTint) == "string" then
			local iconColorDef = ZO_ColorDef:New(iconTint)
			iconTint = iconColorDef
		end
		--Icon's tooltip? Reusing default tooltip functions of controls: ZO_Options_OnMouseEnter and ZO_Options_OnMouseExit
		multiIconCtrl.data.tooltipText = nil
		if tooltipForIcon ~= nil and tooltipForIcon ~= "" then
			multiIconCtrl.data.tooltipText = tooltipForIcon
		end

		--Icon's narration=
		iconNarration = getValueOrCallback(iconData.iconNarration, data)

		if isNewValue == true then
			multiIconCtrl:AddIcon(iconNewIcon, nil, iconNarrationNewValue)
		end
		if iconValue ~= nil then
			multiIconCtrl:AddIcon(iconValue, iconTint, iconNarration)
		end

		multiIconCtrl:SetHandler("OnMouseEnter", function(...)
			ZO_Options_OnMouseEnter(...)
			InformationTooltipTopLevel:BringWindowToTop()
		end)
		multiIconCtrl:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)

		multiIconCtrl:Show()
	end
	multiIconCtrl:SetMouseEnabled(tooltipForIcon ~= nil)
	multiIconCtrl:SetDrawTier(DT_MEDIUM)
	multiIconCtrl:SetDrawLayer(DL_CONTROLS)
	multiIconCtrl:SetDrawLevel(10)

	-- Using the control also as a padding. if no icon then shrink it
	-- This also allows for keeping the icon in size with the row height.
	multiIconContainerCtrl:SetDimensions(iconWidth, iconHeight)
	multiIconCtrl:SetDimensions(iconWidth, iconHeight)
	multiIconCtrl:SetHidden(not visible)
end


--Set the custom XML virtual template for a dropdown entry
local function setItemEntryCustomTemplate(item, isLastEntry, templateTable)
	local isHeader = getValueOrCallback(item.isHeader, item)
	local isDivider = (item.label ~= nil and getValueOrCallback(item.label, item) == libDivider) or getValueOrCallback(item.name, item) == libDivider
	local isCheckbox = getValueOrCallback(item.isCheckbox, item)
	--local isCheckboxChecked = GetValueOrCallback(item.checked, item)
	--local icon = GetValueOrCallback(item.icon, item)

	local hasSubmenu = item.entries ~= nil

	local entryType = (isDivider and DIVIDER_ENTRY_ID) or (isCheckbox and CHECKBOX_ENTRY_ID) or (isHeader and HEADER_ENTRY_ID) or
			(hasSubmenu and SUBMENU_ENTRY_ID) or (isLastEntry and LAST_ENTRY_ID) or ENTRY_ID

--	item.hasSubmenu = hasSubmenu
--	item.isDivider = isDivider
	
	local entryTemplate = templateTable[entryType].template

	ZO_ComboBox.SetItemEntryCustomTemplate(item, entryTemplate)
	return hasSubmenu
end

--TODO: remove or make use of --v
--[[
local function anchorCustomContextMenuToMouse(menuToAnchor)
	if menuToAnchor == nil then return end
	local x, y = GetUIMousePosition()
	local width, height = GuiRoot:GetDimensions()

	menuToAnchor:ClearAnchors()

--d( "[LSM]anchorCustomContextMenuToMouse-width: " ..tos(menuToAnchor:GetWidth()) .. ", height: " ..tos(menuToAnchor:GetHeight()))

	local right = true
	if x + menuToAnchor:GetWidth() > width then
		right = false
	end
	local bottom = true
	if y + menuToAnchor:GetHeight() > height then
		bottom = false
	end

	if right then
		if bottom then
			menuToAnchor:SetAnchor(TOPLEFT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMLEFT, nil, TOPLEFT, x, y)
		end
	else
		if bottom then
			menuToAnchor:SetAnchor(TOPRIGHT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMRIGHT, nil, TOPLEFT, x, y)
		end
	end
end
]]

--TODO: fix -- 20240228 Baertram: What needs to be fixed?
local function selectEntryAndResetLastSubmenuData(self, control)
	playSelectedSoundCheck(control)

	--Pass the entrie's text to the dropdown control's selectedItemText
	-- m_data is incorrect here
	
	ZO_ComboBoxDropdown_Keyboard.OnEntrySelected(self, control)
end

local function createScrollableDropdownEntry(self, item, index, entryType)
	local entryData = ZO_EntryData:New(item)
	entryData.m_index = index
	entryData.m_owner = self.owner
	entryData.m_dropdownObject = self
	entryData:SetupAsScrollListDataEntry(entryType)
	return entryData
end


--------------------------------------------------------------------
-- Local tooltip functions
--------------------------------------------------------------------
--Hide the tooltip of a dropdown entry
local function hideTooltip()
	ClearTooltip(InformationTooltip)
end

--Show the tooltip of a dropdown entry. First check for any custom tooltip function that handles the control show/hide
--and if none is provided use default InformationTooltip
local function showTooltip(control, data, hasSubmenu)
	lib.lastCustomTooltipControl = nil

	--Any custom tooltip function provided? It will handle the control positioning and show/hide itsself
	local customTooltipFunc = data.customTooltip
	if type(customTooltipFunc) == "function" then
		lib.lastCustomTooltipControl = customTooltipFunc(data, control, true) --show
		return
	end

	--No custom tooltip: Use normal InformationTooltip
	local tooltipData = getValueOrCallback(data.tooltip, data)
	local tooltipText = getValueOrCallback(tooltipData, data)
	--No tooltip and/or no tooltip text: Abort here
	if tooltipText == nil then return end

	local point, offsetX, offsetY, relativePoint = BOTTOMLEFT, 0, 0, TOPRIGHT

	local parentControl = control
	if control.m_dropdownObject then
		parentControl = control.m_dropdownObject.control
	end

	local anchorPoint = select(2,parentControl:GetAnchor())
	local right = anchorPoint ~= 3
	if not right then
		local width, height = GuiRoot:GetDimensions()
		local fontObject = _G[DEFAULT_FONT]
		local nameWidth = GetStringWidthScaled(fontObject, tooltipText, 1, SPACE_INTERFACE)

		if control:GetRight() + nameWidth > width then
			right = true
		end
	end

	if right then
		if hasSubmenu then
			point, relativePoint = BOTTOMRIGHT, TOPRIGHT
		else
			point, relativePoint = BOTTOMRIGHT, TOPLEFT
			point, relativePoint = RIGHT, LEFT
		end
	else
		if hasSubmenu then
			point, relativePoint = BOTTOMLEFT, TOPLEFT
		else
			point, relativePoint = LEFT, RIGHT
		end
	end

	InitializeTooltip(InformationTooltip, control, point, offsetX, offsetY, relativePoint)
	SetTooltipText(InformationTooltip, tooltipText)
	InformationTooltipTopLevel:BringWindowToTop()
end


--------------------------------------------------------------------
-- Local narration functions
--------------------------------------------------------------------
local function isAccessibilitySettingEnabled(settingId)
	return GetSetting_Bool(SETTING_TYPE_ACCESSIBILITY, settingId)
end

local function isAccessibilityModeEnabled()
	return isAccessibilitySettingEnabled(ACCESSIBILITY_SETTING_ACCESSIBILITY_MODE)
end

local function isAccessibilityUIReaderEnabled()
	return isAccessibilityModeEnabled() and isAccessibilitySettingEnabled(ACCESSIBILITY_SETTING_SCREEN_NARRATION)
end

--Currently commented as these functions are used in each addon and the addons only pass in options.narrate table so their
--functions will be called for narration
local function canNarrate()
	--todo: Add any other checks, like "Is any menu still showing ..."
	return true
end

--local customNarrateEntryNumber = 0
local function addNewUINarrationText(newText, stopCurrent)
	if isAccessibilityUIReaderEnabled() == false then return end
	stopCurrent = stopCurrent or false
--d( "["..MAJOR.."]AddNewChatNarrationText-stopCurrent: " ..tostring(stopCurrent) ..", text: " ..tostring(newText))
	--Stop the current UI narration before adding a new?
	if stopCurrent == true then
		--StopNarration(true)
		ClearActiveNarration()
	end

	--!DO NOT USE CHAT NARRATION AS IT IS TO CLUNKY / NON RELIABLE!
	--Remove any - from the text as it seems to make the text not "always" be read?
	--local newTextClean = string.gsub(newText, "-", "")

	--if newTextClean == nil or newTextClean == "" then return end
	--PlaySound(SOUNDS.TREE_HEADER_CLICK)
	--if LibDebugLogger == nil and DebugLogViewer == nil then
		--Using this API does no always properly work
		--RequestReadTextChatToClient(newText)
		--Adding it to the chat as debug message works better/more reliably
		--But this will add a timestamp which is read, too :-(
		--CHAT_ROUTER:AddDebugMessage(newText)
	--else
		--Using this API does no always properly work
		--RequestReadTextChatToClient(newText)
		--Adding it to the chat as debug message works better/more reliably
		--But this will add a timestamp which is read, too :-(
		--Disable DebugLogViewer capture of debug messages?
		--LibDebugLogger:SetBlockChatOutputEnabled(false)
		--CHAT_ROUTER:AddDebugMessage(newText)
		--LibDebugLogger:SetBlockChatOutputEnabled(true)
	--end
	--RequestReadTextChatToClient(newTextClean)


	--Use UI Screen reader narration
	local addOnNarationData = {
		canNarrate = function()
			return canNarrate() --ADDONS_FRAGMENT:IsShowing() -->Is currently showing
		end,
		selectedNarrationFunction = function()
			return SNM:CreateNarratableObject(newText)
		end,
	}
	--customNarrateEntryNumber = customNarrateEntryNumber + 1
	local customNarrateEntryName = UINarrationName --.. tostring(customNarrateEntryNumber)
	SNM:RegisterCustomObject(customNarrateEntryName, addOnNarationData)
	SNM:QueueCustomEntry(customNarrateEntryName)
	RequestReadPendingNarrationTextToClient(NARRATION_TYPE_UI_SCREEN)
end

--Delayed narration updater function to prevent queuing the same type of narration (e.g. OnMouseEnter and OnMouseExit)
--several times after another, if you move the mouse from teh top of a menu to the bottom of the menu, hitting all entries once
-->Only the last entry will be narrated then, where the mouse stops
local function onUpdateDoNarrate(uniqueId, delay, callbackFunc)
	local updaterName = UINarrationUpdaterName ..tostring(uniqueId)
--d( "[LSM]onUpdateDoNarrate-updaterName: " ..tos(updaterName))
	EM:UnregisterForUpdate(updaterName)
	if isAccessibilityUIReaderEnabled() == false or callbackFunc == nil then return end
	delay = delay or 1000
	EM:RegisterForUpdate(updaterName, delay, function()
		if isAccessibilityUIReaderEnabled() == false then EM:UnregisterForUpdate(updaterName) return end
--d( ">>>calling func delayed now!")
		callbackFunc()
		EM:UnregisterForUpdate(updaterName)
	end)
end

--Own narration functions, if ever needed -> Currently the addons pass in their narration functions
local function onMouseEnterOrExitNarrate(narrateText, stopCurrent)
	onUpdateDoNarrate("OnMouseEnterExit", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end

local function onSelectedNarrate(narrateText, stopCurrent)
	onUpdateDoNarrate("OnEntryOrCheckboxSelected", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end

local function onMouseMenuOpenOrCloseNarrate(narrateText, stopCurrent)
	onUpdateDoNarrate("OnMenuOpenOrClose", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end
--Lookup table for ScrollableHelper:Narrate() function -> If a string will be returned as 1st return parameter (and optionally a boolean as 2nd, for stopCurrent)
--by the addon's narrate function, the library will lookup the function to use for the narration event, and narrate it then via the UI narration.
-->Select the same function if you want to suppress multiple similar messages to be played after another (e.g. OnMouseEnterExitNarrate for similar OnMouseEnter/Exit events)
local narrationEventToLibraryNarrateFunction = {
	["OnDropdownMouseEnter"] = 	onMouseEnterOrExitNarrate,
	["OnDropdownMouseExit"] =	onMouseEnterOrExitNarrate,
	["OnMenuShow"] = 			onMouseEnterOrExitNarrate,
	["OnMenuHide"] = 			onMouseEnterOrExitNarrate,
	["OnSubMenuShow"] = 		onMouseMenuOpenOrCloseNarrate,
	["OnSubMenuHide"] = 		onMouseMenuOpenOrCloseNarrate,
	["OnEntryMouseEnter"] = 	onMouseEnterOrExitNarrate,
	["OnEntryMouseExit"] = 		onMouseEnterOrExitNarrate,
	["OnEntrySelected"] = 		onSelectedNarrate,
	["OnCheckboxUpdated"] = 	onSelectedNarrate,
}


--------------------------------------------------------------------
-- Dropdown entry/row handlers
--------------------------------------------------------------------
local function onMouseEnter(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry(dropdown, control)
	
	dropdown:Narrate("OnEntryMouseEnter", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseEnter', data, control)
	if data.tooltip or data.customTooltip then
		dropdown:ShowTooltip(control, data)
	end
	return dropdown
end

local function onMouseExit(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry(dropdown, control)
	
	dropdown:Narrate("OnEntryMouseExit", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseExit', data, control)
	hideTooltip()
	
	return dropdown
end

local function onMouseUp(control, data, hasSubmenu, button, upInside)
	local dropdown = control.m_dropdownObject
	
	dropdown:Narrate("OnEntrySelected", entry, data, hasSubmenu)
	lib:FireCallbacks('EntryOnSelected', data, entry)

	return dropdown
end

-- All entryTypes besides ENTRY_ID are ignored OnGlobalMouseUp.
local handlerFunctions  = {
	[ENTRY_ID] = {
		onMouseEnter = function(control, ...)
			d( '[LSM]ENTRY_ID onMouseEnter')
			local data = getControlData(control)
			local dropdown = onMouseEnter(control, data, false)
			clearNewStatus(control, data)
		end,
		onMouseExit = function(control, ...)
			d( '[LSM]ENTRY_ID onMouseExit')
			local data = getControlData(control)
			local dropdown = onMouseExit(control, data, false)
		end,
		onMouseUp = function(control, button, upInside)
			d( '[LSM]ENTRY_ID onMouseUp')
			local data = getControlData(control)
			local dropdown = onMouseUp(control, data, false, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					ZO_ComboBoxDropdown_Keyboard.OnEntrySelected(dropdown, control)
					
					-- This is required for selecting in submenus.
					dropdown:SetSelected(control.m_data.m_index)
					
					local HIDE_INSTANTLY = true
					dropdown:HideDropdown(HIDE_INSTANTLY)
				else -- right-click
				end
			else
				--TODO: Do we want to close dropdowns on mouse up not upInside?
			end
		end,
	},
	[SUBMENU_ENTRY_ID] = {
		onMouseEnter = function(control)
		d( '[LSM]SUBMENU_ENTRY_ID onMouseEnter')
			local data = getControlData(control)
			local dropdown = onMouseEnter(control, data, true)
			
			dropdown:ShowSubmenu(control)
		end,
		onMouseExit = function(control)
		d( '[LSM]SUBMENU_ENTRY_ID onMouseExit')
			local data = getControlData(control)
			local dropdown = onMouseExit(control, data, false)

			if not (MouseIsOver(control) or dropdown:IsEnteringSubmenu()) then
				-- Keep open
				clearTimeout()
				dropdown.m_submenu:HideDropdown()
			end
			
			
			--[[
			if dropdown:IsEnteringSubmenu(control) then
				-- Keep open
				clearTimeout()
				return
			elseif dropdown.m_submenu and dropdown.m_submenu:IsDropdownVisible() then
				clearTimeout()
				dropdown.m_submenu:HideDropdown()
			end
			]]
			
		end,
		onMouseUp = function(control, button, upInside)
			d( '[LSM]SUBMENU_ENTRY_ID onMouseUp')
			local data = getControlData(control)
			local dropdown = onMouseUp(control, data, false, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					ZO_ComboBoxDropdown_Keyboard.OnEntrySelected(dropdown, control)
					
					-- This is required for selecting in submenus.
					dropdown:SetSelected(control.m_data.m_index)
					
					local HIDE_INSTANTLY = true
					dropdown:HideDropdown(HIDE_INSTANTLY)
				else -- right-click
				end
			else
				--TODO: Do we want to close dropdowns on mouse up not upInside?
			end
		end,
	},
	[DIVIDER_ENTRY_ID] = {
		-- Intentionally empty.
	},
	[HEADER_ENTRY_ID] = {
		onMouseEnter = function(control, ...)
			local dropdown = control.m_dropdownObject
			local data = getControlData(control)
			if data.tooltip or data.customTooltip then
				dropdown:ShowTooltip(control, data)
			end
		end,
		onMouseExit = function(control, ...)
			hideTooltip()
		end,
	},
	[CHECKBOX_ENTRY_ID] = {
		onMouseEnter = function(control, ...)
		d( '[LSM]CHECKBOX_ENTRY_ID onMouseEnter')
			local data = getControlData(control)
			local dropdown = onMouseEnter(control, data, false)
		end,
		onMouseExit = function(control, ...)
		d( '[LSM]CHECKBOX_ENTRY_ID onMouseExit')
			local data = getControlData(control)
			local dropdown = onMouseExit(control, data, false)
		end,
		onMouseUp = function(control, button, upInside)
		d( '[LSM]CHECKBOX_ENTRY_ID onMouseUp')
			local dropdown = control.m_dropdownObject
			if upInside then
				local data = getControlData(control)
				
				if button == MOUSE_BUTTON_INDEX_LEFT then
					-- left click on row toggles the checkbox.
					ZO_CheckButton_OnClicked(control.m_checkbox)
					
					data.checked = ZO_CheckButton_IsChecked(control.m_checkbox)
					playSelectedSoundCheck(control)
				else -- right-click
				end
			else
				--TODO: Do we want to close dropdowns on mouse up not upInside?
			end
		end,
	},
}

local function runHandler(handlerTable, handlerName, control, ...)
	local handlers = handlerTable[control.typeId]
	if handlers then
		local handler = handlers[handlerName]
		if handler then
			--TODO: Make use of return, or remove?
			local done, returnVal = handler(control, ...)
			if(done) then
			--	return done, returnVal
			end
		end
		return true
	end

	return false
end

--------------------------------------------------------------------
-- The base dropdown object.
--------------------------------------------------------------------
local dropdownControlPool = ZO_ControlPool:New(LSM_XML_Template_Keyboard, nil, MAJOR .. '_Dropdown')

local DropdownObject_Base = ZO_ComboBoxDropdown_Keyboard:Subclass()
local SubmenuObject = DropdownObject_Base:Subclass()

function DropdownObject_Base:Initialize(options, dropdownPool, depth)
	local dropdownControl, key = dropdownPool:AcquireObject(depth)
	dropdownControl:SetHidden(true)
	ZO_ComboBoxDropdown_Keyboard.Initialize(self, dropdownControl)
	dropdownControl.object = self
	
	self.m_isDropdownVisible = false
	self.m_preshowDropdownFn = nil
	self.m_name = self.control:GetName()
	
	depth = depth or 1
	
	self.depth = depth
	self.m_NextFree = depth + 1
	
	self.m_sortedItems = {}

	self.optionsChanged = true
	self:UpdateOptions(options)
end

--[[ Mange the control pool
function DropdownObject_Base:Initialize(options, dropdownPool, depth)
	self.dropdownPool = dropdownPool
	
	local dropdownControl = self:AcquireControl()
	-- We need the dropdownControl to initialize the scroll list.
	ZO_ComboBoxDropdown_Keyboard.Initialize(self, dropdownControl)
	
	self.m_isDropdownVisible = false
	self.m_preshowDropdownFn = nil
	self.m_name = self.control:GetName()
	
	depth = depth or 1
	
	self.depth = depth
	self.m_NextFree = depth + 1
	
	self.m_sortedItems = {}

	self.optionsChanged = true
	self:UpdateOptions(options)
	
	-- We can release the dropdownControl now.
	self:ReleaseControl()
end

function DropdownObject_Base:SetHidden(isHidden)
	ZO_ComboBoxDropdown_Keyboard.SetHidden(self, isHidden)
	
	if isHidden and self.key then
		self:ReleaseControl()
		
	elseif not isHidden then
		self:AcquireControl()
	end
end

function DropdownObject_Base:AcquireControl()
	local dropdownControl, key = self.dropdownPool:AcquireObject()
	dropdownControl.object = self
	self.key = key
	
	
	self.control = dropdownControl

--	self.scrollControl = dropdownControl:GetNamedChild("Scroll")

	self.scrollControl:SetParent(self.control)
	
	self.spacing = 0
--	self.nextScrollTypeId = DEFAULT_LAST_ENTRY_ID + 1

	
	return dropdownControl
end

function DropdownObject_Base:ReleaseControl()
	self.dropdownPool:ReleaseObject(self.key)
end
]]

function DropdownObject_Base:HideDropdownInternal()
	-- To be overwritten
end

function DropdownObject_Base:AddItems(items)
	-- To be overwritten
end


local function comboBoxSortHelper(item1, item2, comboBoxObject)
    return ZO_TableOrderingFunction(item1, item2, "name", comboBoxObject.m_sortType, comboBoxObject.m_sortOrder)
end

function DropdownObject_Base:UpdateItemNames()
	for k, item in ipairs(self.m_sortedItems) do
		local name = getValueOrCallback(item.name, data)
		
		if item.label ~= nil then
			name  = getValueOrCallback(item.label, data)
		end
		
		if name ~= 	item.name then
			item.name = name
		end
	end
end

function DropdownObject_Base:GetOptions()
	return self.options
end

function DropdownObject_Base:UpdateOptions(options)
	d( sfor('[LSM]UpdateOptionsoptionsChanged %s', tos(self.optionsChanged)))

	if not self.optionsChanged then return end

	self.optionsChanged = false

	options = options or {}

	local control = self.control

	-- Backwards compatible
	if type(options) ~= 'table' then
		options = {
			visibleRowsDropdown = options
		}
	end

	local defaultOptions = self.options or defaultContextMenuOptions
	-- We add all previous options to the new table
	mixinTableAndSkipExisting(options, defaultOptions)

	local visibleRows = getValueOrCallback(options.visibleRowsDropdown, options)
	local visibleRowsSubmenu = getValueOrCallback(options.visibleRowsSubmenu, options)
	local sortsItems = getValueOrCallback(options.sortEntries, options)
	local narrateData = getValueOrCallback(options.narrate, options)

	control.options = options
	self.options = options

	visibleRows = visibleRows or DEFAULT_VISIBLE_ROWS
	visibleRowsSubmenu = visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS
	self.visibleRows = visibleRows					--Will be nil for a submenu!
	self.visibleRowsSubmenu = visibleRowsSubmenu

	if sortsItems == nil then sortsItems = DEFAULT_SORTS_ENTRIES end
	self.sortsItems = sortsItems

	
	if self.m_comboBox then
		self.m_comboBox:SetSortsItems(self.sortsItems)
	end
	
	self.options = options
	self.control.options = options
	self.narrateData = narrateData
	self.control.narrateData = narrateData
	
	-- this will add custom and default templates to self.XMLrowTemplates the same way dataTypes were created before.
	self:AddCustomEntryTemplates(options)
end

function DropdownObject_Base:AddCustomEntryTemplate(entryTemplate, entryHeight, widthAdjust, setupFunction)
	if not self.customEntryTemplateInfos then
		self.customEntryTemplateInfos = {}
	end

	if self.customEntryTemplateInfos[entryTemplate] ~= nil then
		-- we have already added this template
		return
	end

	local customEntryInfo =
	{
		typeId = self.nextScrollTypeId,
		entryHeight = entryHeight,
		widthAdjust = widthAdjust,
	}

	self.customEntryTemplateInfos[entryTemplate] = customEntryInfo

	local entryHeightWithSpacing = entryHeight + self.spacing
	ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId, entryTemplate, entryHeightWithSpacing, setupFunction)
	ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId + 1, entryTemplate, entryHeight, setupFunction)

	self.nextScrollTypeId = self.nextScrollTypeId + 2
end

function DropdownObject_Base:AddCustomEntryTemplates(options)
	-- checkbox wrappers
	local function setupEntry(control, data)
		control.m_data = data
		control.m_owner = self.owner
		control.m_dropdownObject = self
	end

	local function setChecked(checkbox, checked)
		local data = ZO_ScrollList_GetData(checkbox:GetParent())
		
		data.checked = checked
		if data.callback then
			data.callback(checked, data)
		end
		
		self:Narrate("OnCheckboxUpdated", checkbox, data, nil)
		lib:FireCallbacks('CheckboxUpdated', checked, data, checkbox)
	end

	local function addCheckbox(control, data, list)
		control.m_checkbox = control.m_checkbox or control:GetNamedChild("Checkbox")
		local checkbox = control.m_checkbox
		ZO_CheckButton_SetToggleFunction(checkbox, setChecked)
		ZO_CheckButton_SetCheckState(checkbox, getValueOrCallback(data.checked, data))
	end
	
	local function addIcon(control, data, list)
		control.m_iconContainer = control.m_iconContainer or control:GetNamedChild("IconContainer")
		local iconContainer = control.m_iconContainer
		control.m_icon = control.m_icon or iconContainer:GetNamedChild("Icon")
		control.m_label = control.m_label or control:GetNamedChild("Label")
		control.m_checkbox = control.m_checkbox or control:GetNamedChild("Checkbox")
		updateIcons(control, data)
	end
	
	local function addArrow(control, data, list)
		control.m_arrow = control:GetNamedChild("Arrow")
		
		local hasSubmenu = data.entries ~= nil
		data.hasSubmenu = hasSubmenu
		
		if control.m_arrow then
			control.m_arrow:SetHidden(not hasSubmenu)
			--SUBMENU_ARROW_PADDING = control.m_arrow:GetHeight()
		end
	end
	
	local function addDivider(control, data, list)
		control.m_owner = data.m_owner
		control.m_data = data
		control.m_divider = control:GetNamedChild("Divider")
	end

	local function addLabel(control, data, list)
		control.m_owner = data.m_owner
		control.m_data = data
		control.m_label = control.m_label or control:GetNamedChild("Label")

		local oName = data.name
		local name = getValueOrCallback(data.name, data)
		-- I used this to test max row width. Since this text is being changed later then data is passed in,
		-- it only effects the width after 1st showing.
	--	local name = GetValueOrCallback(data.name, data) .. ': This is so I can test the max width of entry text.'
		local labelStr = name
		if oName ~= name then
			data.oName = oName
			data.name = name
		end
		
		--Passed in an alternative text/function returning a text to show at the label control of the menu entry?
		if data.label ~= nil then
			data.labelStr  = getValueOrCallback(data.label, data)
			labelStr = data.labelStr
		end
		
		control.m_label:SetText(labelStr)
		control.m_font = control.m_owner.m_font
		
		if not control.isHeader then
			-- This would overwrite the header's font and color.
			control.m_label:SetFont(control.m_owner.m_font)
			control.m_label:SetColor(control.m_owner.m_normalColor:UnpackRGBA())
		end
	end

	-- was planing on moving DropdownObject:AddDataTypes() and 
	-- all the template stuff wrapped up in here
	local defaultXMLTemplates  = {
		[ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				control.typeId = ENTRY_ID
				self:SetupEntryBase(control, data, list)
		--		setupEntry(control, data)
		--		self:SetupEntry(control, data, list)
				--Check if the data.name is a function returning a string, so prepare the String value now
				--and update the original function for later usage to data.oName
				addIcon(control, data, list)
				addArrow(control, data, list)
				addLabel(control, data, list)
				
			--	control.m_data = data --update changed (after oSetup) data entries to the control, and other entries have been updated
			end,
		},
		[SUBMENU_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxSubmenuEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthAdjust = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				control.typeId = SUBMENU_ENTRY_ID
				self:SetupEntryBase(control, data, list)
		--		setupEntry(control, data)
				--Check if the data.name is a function returning a string, so prepare the String value now
				--and update the original function for later usage to data.oName
				addIcon(control, data, list)
				addArrow(control, data, list)
				addLabel(control, data, list)
				
			--	control.m_data = data --update changed (after oSetup) data entries to the control, and other entries have been updated
			end,
		},
		[DIVIDER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxDividerEntry',
			rowHeight = DIVIDER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				control.typeId = DIVIDER_ENTRY_ID
				self:SetupEntryBase(control, data, list)
		--		setupEntry(control, data)
				addDivider(control, data, list)
			end,
		},
		[HEADER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxHeaderEntry',
			rowHeight = HEADER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				control.typeId = HEADER_ENTRY_ID
				self:SetupEntryBase(control, data, list)
			--	setupEntry(control, data)
				control.isHeader = true
				addDivider(control, data, list)
				addIcon(control, data, list)
				addLabel(control, data, list)
			end,
		},
		[CHECKBOX_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxCheckboxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				control.typeId = CHECKBOX_ENTRY_ID
				self:SetupEntryBase(control, data, list)
		--		setupEntry(control, data)
		--		self:SetupEntry(control, data, list)
				control.isCheckbox = true
				addIcon(control, data, list)
				addCheckbox(control, data, list)
				addLabel(control, data, list)
			end,
		},
	}
	--Default last entry ID copies from normal entry id
	defaultXMLTemplates[LAST_ENTRY_ID] = ZO_ShallowTableCopy(defaultXMLTemplates[ENTRY_ID])
	lib.DefaultXMLTemplates = defaultXMLTemplates

		--Were any options and XMLRowTemplates passed in?
	local optionTemplates = options and getValueOrCallback(options.XMLRowTemplates, options)
	local XMLrowTemplatesToUse = ZO_ShallowTableCopy(defaultXMLTemplates)

	--Check if all XML row templates are passed in, and update missing ones with default values
	if optionTemplates ~= nil then
		for entryType, defaultData in pairs(defaultXMLTemplates) do
			if optionTemplates[entryType] ~= nil  then
				zo_mixin(XMLrowTemplatesToUse[entryType], optionTemplates[entryType])
			end
		end
	end

	self.XMLrowTemplates = XMLrowTemplatesToUse
	
	-- These register the templates and creates a dataType for each.
	self:AddCustomEntryTemplate(getTemplateData(ENTRY_ID, XMLrowTemplatesToUse))
	self:AddCustomEntryTemplate(getTemplateData(LAST_ENTRY_ID, XMLrowTemplatesToUse))
	self:AddCustomEntryTemplate(getTemplateData(SUBMENU_ENTRY_ID, XMLrowTemplatesToUse))
	self:AddCustomEntryTemplate(getTemplateData(DIVIDER_ENTRY_ID, XMLrowTemplatesToUse))
	self:AddCustomEntryTemplate(getTemplateData(HEADER_ENTRY_ID, XMLrowTemplatesToUse))
	self:AddCustomEntryTemplate(getTemplateData(CHECKBOX_ENTRY_ID, XMLrowTemplatesToUse))
	
	-- TODO: we should not rely on these anymore. Instead we should attach them to self if they are still needed
	SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = XMLrowTemplatesToUse[ENTRY_ID].rowHeight
	DIVIDER_ENTRY_HEIGHT = XMLrowTemplatesToUse[DIVIDER_ENTRY_ID].rowHeight
	HEADER_ENTRY_HEIGHT = XMLrowTemplatesToUse[HEADER_ENTRY_ID].rowHeight
	ICON_PADDING = SCROLLABLE_ENTRY_TEMPLATE_HEIGHT
end

function DropdownObject_Base:IsItemSelected(item)
	if self.owner and self.owner.IsItemSelected then
		return self.owner:IsItemSelected(item)
	end
	return false
end

--Narration
function DropdownObject_Base:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	local narrateData = self.narrateData
--d( "[LSM]Narrate-"..tos(eventName) .. ", narrateData: " ..tos(narrateData))
	if eventName == nil or isAccessibilityUIReaderEnabled() == false or narrateData == nil then return end
	local narrateCallbackFuncForEvent = narrateData[eventName]
	if narrateCallbackFuncForEvent == nil or type(narrateCallbackFuncForEvent) ~= "function" then return end

	local eventCallbackFunctionsSignatures = {
		["OnDropdownMouseEnter"] = function() return self, ctrl end,
		["OnDropdownMouseExit"] =  function() return self, ctrl end,
		["OnMenuShow"]		   = function() return self, ctrl end,
		["OnMenuHide"]		   = function() return self, ctrl end,
		["OnSubMenuShow"]		= function() return self, ctrl, anchorPoint end,
		["OnSubMenuHide"]		= function() return self, ctrl end,
		["OnEntryMouseEnter"]	= function() return self, ctrl, data, hasSubmenu end,
		["OnEntryMouseExit"]	 = function() return self, ctrl, data, hasSubmenu end,
		["OnEntrySelected"]	  = function() return self, ctrl, data, hasSubmenu end,
		["OnCheckboxUpdated"]	= function() return self, ctrl, data end,
	}
	--Create a table with the callback functions parameters
	local callbackParams = { eventCallbackFunctionsSignatures[eventName]() }
	--Pass in the callback params to the narrateFunction
	local narrateText, stopCurrent = narrateCallbackFuncForEvent(unpack(callbackParams))

--d( ">NarrateText: " ..tos(narrateText) .. ", stopCurrent: " ..tos(stopCurrent))
	--Didn't the addon take care of the narration itsself? So this library here should narrate the text returned
	if type(narrateText) == "string" then
		local narrateFuncOfLibrary = narrationEventToLibraryNarrateFunction[eventName]
		if narrateFuncOfLibrary == nil then return end
		narrateFuncOfLibrary(narrateText, stopCurrent)
	end
end

-- Handlers
function DropdownObject_Base:OnMouseEnterEntry(control)
	d( '[LSM]DropdownObject_Base:OnMouseEnterEntry')
	d( control:GetName())
	self.m_selectedRowControl = control
	
	local submenu = self.m_submenu
	if submenu then
		if submenu:IsDropdownVisible() and not submenu:IsMouseOverControl() then
			submenu:HideDropdown()
		end
	end
	
	if not runHandler(handlerFunctions, 'onMouseEnter', control) then
		-- It is not a custom entry.
		ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry(self, control)
	end
end

function DropdownObject_Base:OnMouseExitEntry(control)
	d( '[LSM]DropdownObject_Base:OnMouseExitEntry')
	d( control:GetName())
	
	if not runHandler(handlerFunctions, 'onMouseExit', control) then
		-- It is not a custom entry.
		ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry(self, control)
	end
	if not lib.GetPersistentMenus() then
		self:OnMouseExitTimeout(control)
	end
--	self.m_selectedRowControl = nil
end

function DropdownObject_Base:OnEntrySelected(control, button, upInside)
	d( '[LSM]DropdownObject_Base:OnEntrySelected IsUpInside ' .. tos(upInside) .. ' Button ' .. tos(button))
	
	if not runHandler(handlerFunctions, 'onMouseUp', control, button, upInside) then
		-- It is not a custom entry.
		ZO_ComboBoxDropdown_Keyboard.OnEntrySelected(self, control)
	end
	
	local data = getControlData(control)
	
	if upInside then
		if button == MOUSE_BUTTON_INDEX_RIGHT then
			if data.contextMenuCallback then
				data.contextMenuCallback(control)
			end
		end
	end
end

function DropdownObject_Base:OnMouseExitTimeout(control)
	clearTimeout()
	
	setTimeout(function()
		d( "[LSM]DropdownObject:OnMouseExitTimeout")
		local submenu = self.m_submenu
		if not submenu or not submenu:IsMouseOverControl() then
			-- This will only close the dropdown if the mouse is not over the dropdown ore over the control that opened it.
			if not (self:IsMouseOverControl() or self:IsMouseOverParent()) then
				self:HideDropdown()
			end
		end
	end)
end

function DropdownObject_Base:ShowTooltip(control, data)
	if data.hasSubmenu then
		--Delay the tooltip by 1 frame (delay = 0) to show it "on top" of the submenu
		zo_callLater(function()
			showTooltip(self:GetSubmenu(control).control, data, data.hasSubmenu)
		end, 0)
	else
		showTooltip(control, data, data.hasSubmenu)
	end
end

--TODO 20240229: Move down to DropdownObject or, add it to all children.
function DropdownObject_Base:SetPreshowDropdownCallback(fn)
	-- Called right before the menu is shown.
	self.m_preshowDropdownFn = fn
end

function DropdownObject_Base:ShouldClose()
	d( '[LSM]DropdownObject_Base:ShouldClose')
	local parentControl = self.parentControl
	local submenu = self.m_submenu
	
	-- Not over opening row and not over submenu and not over opened contextMenu
	if not submenu or (submenu ~= nil and not (submenu:IsDropdownVisible() and submenu:IsMouseOverControl()))
			or (g_contextMenu ~= nil and not (g_contextMenu:IsDropdownVisible() and g_contextMenu:IsMouseOverControl())) then
		return not (self:IsMouseOverControl() or (parentControl and MouseIsOver(parentControl)))
	end
end

function DropdownObject_Base:HideDropdown(hideInstantly)
	local submenu = self.m_submenu
	if submenu and submenu:IsDropdownVisible() then
		submenu:HideDropdown()
	end
	
	if self:IsDropdownVisible() then
	--	PlaySound(SOUNDS.ANTIQUITIES_FANFARE_COMPLETED)
		
		self:HideDropdownInternal(hideInstantly)
	end
end

function DropdownObject_Base:IsMouseOverRow()
	local selectedRowCtrl = self.m_selectedRowControl
	if selectedRowCtrl then
		return MouseIsOver(selectedRowCtrl)
	end
	return true
end

function DropdownObject_Base:OnGlobalMouseUp(eventCode, button, ctrl, alt, shift, command)
	d( '[LSM]DropdownObject_Base:OnGlobalMouseUp')
    if self:IsDropdownVisible() and self:BypassOnGlobalMouseUp(button) then
		-- Either we did not click on a selectable entry or, we used right-click
	--	PlaySound(SOUNDS.ANTIQUITIES_FANFARE_FAILURE)
		d( 'BypassOnGlobalMouseUp')
    elseif self.owner then
		ZO_ComboBox.OnGlobalMouseUp(self.owner, eventCode, button, ctrl, alt, shift, command)
	end
end

--[[
function DropdownObject_Base:BypassOnGlobalMouseUp(button)
	local moc = moc()
	local typeId = moc.typeId
	
	return (button == MOUSE_BUTTON_INDEX_LEFT and (moc.typeId and moc.typeId ~= ENTRY_ID)) or button == MOUSE_BUTTON_INDEX_RIGHT
end
]]

function DropdownObject_Base:BypassOnGlobalMouseUp(button)
	if self:IsMouseOverRow() then 
		if button == MOUSE_BUTTON_INDEX_LEFT then
			local mouseOverCtrl = moc()
			if mouseOverCtrl then
				local mocTypeId = mouseOverCtrl.typeId
				return mocTypeId and mocTypeId ~= ENTRY_ID
			end
		end
		
		return button == MOUSE_BUTTON_INDEX_RIGHT
	end
end

function DropdownObject_Base:IsDropdownVisible()
	-- inherited ZO_ComboBoxDropdown_Keyboard:IsHidden
	return not self:IsHidden()
end

function DropdownObject_Base:SetSelected(index, ignoreCallback)
	local item = self.m_sortedItems[index]
	local owner = self.owner
	if owner then
		owner:SelectItem(item, ignoreCallback)
		
		-- multi-select dropdowns will stay open to allow for selecting more entries
		if not owner.m_enableMultiSelect then
			owner:HideDropdown()
		end
	end
end

function DropdownObject_Base:ShowSubmenu(parentControl)
	-- This is a special function, separate from ShowDropdown, used only to initialize and begin showing a submenu
	local submenu = self:GetSubmenu(parentControl)
	submenu:ShowDropdown(parentControl)
end

function DropdownObject_Base:GetSubmenu(parentControl)
	if not self.m_submenu then
		self.m_submenu = SubmenuObject:New(self, parentControl, self.options, self.submenuPool, self.m_NextFree)
	end
	return self.m_submenu
end

function DropdownObject_Base:IsEnteringSubmenu()
	local submenu = self.m_submenu
	if submenu then
		if submenu:IsDropdownVisible() and submenu:IsMouseOverControl() then
			return true
		end
	end
	return false
end

function DropdownObject_Base:IsMouseOverParent()
	return true
end

--------------------------------------------------------------------
-- SubmenuObject
--------------------------------------------------------------------
function SubmenuObject:Initialize(parentMenu, control, options, submenuPool, parentDepth)
--	DropdownObject.Initialize(self, parentMenu, control.m_owner.m_container, options, parentDepth, 'Submenu')
	DropdownObject_Base.Initialize(self, options, submenuPool, parentDepth)
	
	self.isSubmenu = true
	self.submenuPool = submenuPool
	self.owner = parentMenu.owner
	self.parentMenu = parentMenu
	
	if control.m_dropdownObject then
		self.m_mainScrollableMenu = control.m_dropdownObject.m_mainScrollableMenu or control.m_dropdownObject
	end
end

--LibScrollableMenuTestDropdown_Dropdown 2Scroll5Row1_Submenu Scroll5Row1_SubmenuScroll5Row1_ Submenu
function SubmenuObject:AnchorToControl(parentControl)
	local width, height = GuiRoot:GetDimensions()
	
	local offsetX = 0
	self.control:ClearAnchors()
	
	local right = self.parentMenu.anchorPoint or false
	if right or parentControl:GetRight() + self.control:GetWidth() > width then
		right = true
		offsetX = 0
	end
	
	if right then
		self.control:SetAnchor(TOPRIGHT, parentControl, TOPLEFT, offsetX, 0)
	else
		self.control:SetAnchor(TOPLEFT, parentControl, TOPRIGHT, offsetX, 0)
	end
	
	self.anchorPoint = right
	self.control:SetHidden(false)
end

function SubmenuObject:SetSelected(index, ignoreCallback)
	local item = self.m_sortedItems[index]
	local owner = self.owner
	if owner then
		owner:SelectItem(item, ignoreCallback)
		
		-- multi-select dropdowns will stay open to allow for selecting more entries
		if not owner.m_enableMultiSelect then
			owner:HideDropdown()
		end
	end
end

function SubmenuObject:ShowDropdown(parentControl)
	self.parentControl = parentControl
	self.owner = parentControl.m_owner
	
	local data = ZO_ScrollList_GetData(parentControl)
	local items = getValueOrCallback(data.entries, data)
	
	-- Reset the scrollList
	self:SetHidden(false)
	-- Here we actually add the items to self.m_sortedItems
	self:AddItems(items)
	
	self:AddMenuItems(parentControl)

 	self:AnchorToControl(parentControl)
	
	self.control:BringWindowToTop()
end
 
function SubmenuObject:AddMenuItems(parentControl)
	local comboBox = parentControl.m_owner
	if comboBox then
		self.control:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self:OnGlobalMouseUp(...) end)
		--comboBox, itemTable, minWidth, maxHeight, spacing
		self:Show(comboBox, self.m_sortedItems, comboBox.m_containerWidth, comboBox.m_height, comboBox:GetSpacing())
	end
	
	self:Narrate("OnSubMenuShow", parentControl, nil, nil, self.anchorPoint)
	--TODO: do we want to move this so context menu can fire it's own?
	lib:FireCallbacks('SubmenuOnShow', self)
end

function SubmenuObject:Show(comboBox, itemTable, minWidth, maxHeight, spacing)
	self.owner = comboBox
--[[
	local parentControl = comboBox:GetContainer()
	self.control:ClearAnchors()
	self.control:SetAnchor(TOPLEFT, parentControl, BOTTOMLEFT)

]]
	ZO_ScrollList_Clear(self.scrollControl)

	self:SetSpacing(spacing)

	local numItems = #itemTable
	local dataList = ZO_ScrollList_GetDataList(self.scrollControl)

	local largestEntryWidth = 0
	local allItemsHeight = 0

	for i = 1, numItems do
		local item = itemTable[i]

		local isLastEntry = i == numItems
		local entryHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT
		local entryType = _DEFAULT_ENTRY_ID
		local widthAdjust = 0
		if self.customEntryTemplateInfos and item.customEntryTemplate then
			local templateInfo = self.customEntryTemplateInfos[item.customEntryTemplate]
			if templateInfo then
				entryType = templateInfo.typeId
				entryHeight = templateInfo.entryHeight
				widthAdjust = templateInfo.widthAdjust or 0
		
				-- If the entry has an icon, or isNew, we add the row height to adjust for icon size.
				widthAdjust = widthAdjust + (item.isNew and entryHeight or 0)
			end
		end
		
		if isLastEntry then
			entryType = entryType + 1
		else
			entryHeight = entryHeight + self.spacing
		end

		allItemsHeight = allItemsHeight + entryHeight

		local entry = createScrollableDropdownEntry(self, item, i, entryType)
		tins(dataList, entry)

		local fontObject = self.owner:GetDropdownFontObject()
		local nameWidth = GetStringWidthScaled(fontObject, item.name, 1, SPACE_INTERFACE) + widthAdjust
		if nameWidth > largestEntryWidth then
			largestEntryWidth = nameWidth
		end
	end

	-- using the exact width of the text can leave us with pixel rounding issues
	-- so just add 5 to make sure we don't truncate at certain screen sizes
	largestEntryWidth = largestEntryWidth + 5

	-- Allow the dropdown to automatically widen to fit the widest entry, but
	-- prevent it from getting any skinnier than the container's initial width
	local totalDropDownWidth = largestEntryWidth + ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2 + ZO_SCROLL_BAR_WIDTH
	self.control:SetWidth((totalDropDownWidth > minWidth and totalDropDownWidth) or minWidth)

	allItemsHeight = allItemsHeight + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2)

	local desiredHeight = maxHeight
	if allItemsHeight < desiredHeight then
		desiredHeight = allItemsHeight
	end

	self.control:SetHeight(desiredHeight)
	ZO_ScrollList_SetHeight(self.scrollControl, desiredHeight)

	ZO_ScrollList_Commit(self.scrollControl)
end

function SubmenuObject:AddItem(itemEntry, updateOptions)
	tins(self.m_sortedItems, itemEntry)
	
	if updateOptions ~= ZO_COMBOBOX_SUPPRESS_UPDATE then
		self:UpdateItems()
	end

 --   self:OnItemAdded()
end

function SubmenuObject:AddItems(items)
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)
	
	local numItems = #items
	
	for i = 1, numItems do
		local item = items[i]
		item.m_owner = self
		item.parent = self.parentControl
		local isLastEntry = i == numItems
		
		local hasSubmenu = setItemEntryCustomTemplate(item, isLastEntry, self.XMLrowTemplates)
		
		if hasSubmenu then
			item.hasSubmenu = true
			item.isNew = areAnyEntriesNew(item)
		end

		--todo 20240229 how to get "data" from the item
		local data = getControlData(item) or item.data
		local name = getValueOrCallback((item.label ~= nil and item.label) or item.name, data)
		if name ~= item.name then
			item.name = name
		end
	
		tins(self.m_sortedItems, item)
	end
end

function SubmenuObject:OnGlobalMouseUp(eventCode, button, ctrl, alt, shift, command)
	hideTooltip()
	
	if self:IsDropdownVisible() then
		if button == MOUSE_BUTTON_INDEX_LEFT and not self:IsMouseOverControl() then
			self:HideDropdown()
		else
		end
	else
		--[[
		if button == MOUSE_BUTTON_INDEX_RIGHT then
			-- right-click
			if data.contextMenuCallback then
				data.contextMenuCallback(control)
			end
		else
		end
		
		if g_contextMenu:IsDropdownVisible() then
		]]

		if self.control:IsHidden() then
			self:HideDropdown()
		else
			-- If shown in ShowDropdownInternal, the global mouseup will fire and immediately dismiss the combo box. We need to
			-- delay showing it until the first one fires.
	  --	  self:ShowDropdownOnMouseUp()
		end
	end
end

function SubmenuObject:HideDropdownInternal(hideInstantly)
	self.control:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)
	
	--todo 20240229 is this still used?
	--[[
	if g_contextMenu and g_contextMenu:IsDropdownVisible() then
--		g_contextMenu:HideDropdown()
	end
	]]
	
	local submenu = self.childMenu
	if submenu and submenu:IsDropdownVisible() then
		submenu:HideDropdown()
	end
	
	if hideInstantly or not self:IsMouseOverControl() then
		self:SetHidden(true)
		
		if self.onHideDropdownCallback then
			self.onHideDropdownCallback(self)
		end
	end
end

function SubmenuObject:SetupEntryBase(control, data, list)
	control.m_owner = self.owner
	control.m_data = data
	control.m_dropdownObject = self

	if self:IsItemSelected(data:GetDataSource()) then
		if not control.m_selectionHighlight then
			control.m_selectionHighlight = CreateControlFromVirtual("$(parent)Selection", control, "ZO_ComboBoxEntry_SelectedHighlight")
		end
		control.m_selectionHighlight:SetHidden(false)
	elseif control.m_selectionHighlight then
		control.m_selectionHighlight:SetHidden(true)
	end
	
	--[[
function ZO_ComboBoxDropdown_Keyboard:SetupEntryBase(control, data, list)
	control.m_owner = self.owner
	control.m_data = data
	control.m_dropdownObject = self

	if self.owner:IsItemSelected(data:GetDataSource()) then
		if not control.m_selectionHighlight then
			control.m_selectionHighlight = CreateControlFromVirtual("$(parent)Selection", control, "ZO_ComboBoxEntry_SelectedHighlight")
		end

		control.m_selectionHighlight:SetHidden(false)
	elseif control.m_selectionHighlight then
		control.m_selectionHighlight:SetHidden(true)
	end
end

	]]
end

function SubmenuObject:IsMouseOverParent()
	local parent = self.parentControl
	return parent and parent.m_dropdownObject and parent.m_dropdownObject:IsMouseOverControl()
end



--------------------------------------------------------------------
-- Scrollable ContextMenu
--------------------------------------------------------------------
local uiWidth, uiHeight = GuiRoot:GetDimensions() -- < just testing v
local DEFAULT_HEIGHT = uiHeight / 2
local DEFAULT_FONT = "ZoFontGame"
local DEFAULT_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
local DEFAULT_TEXT_HIGHLIGHT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))

-- This requires functions available in ZO_ComboBox since it may not be directly attached to a comboBox.
local ContextMenuObject = SubmenuObject:MultiSubclass(ZO_ComboBox)

function ContextMenuObject:Initialize(depth)
	d( '[LSM]ContextMenuObject:Initialize')
	
	local dropdownControl = dropdownControlPool:AcquireObject(depth)
	ZO_ComboBoxDropdown_Keyboard.Initialize(self, dropdownControl)
	dropdownControl.object = self
	
--	self.owner = parent.owner
--	self.parent = parent
	self.depth = depth
	self.data = {}
	self.m_sortedItems = {}
	self.m_NextFree = depth + 1
	
	self:SetHeight(DEFAULT_HEIGHT)
	self.m_font = DEFAULT_FONT
	self.m_normalColor = DEFAULT_TEXT_COLOR
	self.m_highlightColor = DEFAULT_TEXT_HIGHLIGHT
	self.m_containerWidth = 300
	self.m_isDropdownVisible = false
	self.m_preshowDropdownFn = nil
	self.m_name = dropdownControl:GetName()
	self.m_spacing = 0
	
	self.optionsChanged = true
	local options = nil
--	self:UpdateOptions(options)
	self:AddCustomEntryTemplates(options)
	
	dropdownControl:SetHeight(0)
	
	-- This is also inheriting ZO_ComboBox_Base since chance parentControl may not be part of a comboBox.
	-- the scrollControl needs several parts of a comboBox
end

function ContextMenuObject:SetHeight(height)
	self.m_height = height or DEFAULT_HEIGHT
end

function ContextMenuObject:AnchorToMouse(parentControl)
	local zoMenu = ZO_Menu
	local menuToAnchor = self.control
	
	local x, y = GetUIMousePosition()
	local width, height = GuiRoot:GetDimensions()

	menuToAnchor:ClearAnchors()

	local right = true
	if x + zoMenu.width > width then
		right = false
	end
	local bottom = true
	if y + zoMenu.height > height then
		bottom = false
	end

	if right then
		if bottom then
			menuToAnchor:SetAnchor(TOPLEFT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMLEFT, nil, TOPLEFT, x, y)
		end
	else
		if bottom then
			menuToAnchor:SetAnchor(TOPRIGHT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMRIGHT, nil, TOPLEFT, x, y)
		end
	end
end

function ContextMenuObject:ShowContextMenu(parentControl)
	if parentControl.m_dropdownObject then
		self.m_NextFree = parentControl.m_dropdownObject.depth + 1
	else
--		self.m_NextFree = self.m_NextFree + 1
	end
	
	self.parentControl = parentControl
	
	self:AddItems(self.data)
	self:ShowDropdown(parentControl)
end

function ContextMenuObject:ShowDropdown(parentControl)
	self.parentControl = parentControl
	
	self:SetHidden(false)
	-- Here we actually add the items to self.m_sortedItems
	self:AddItems(self.data)
	
	self:AddMenuItems(parentControl)
	
	self:AnchorToMouse(parentControl)
	self.control:BringWindowToTop()
end
 
function ContextMenuObject:AddMenuItems(parentControl)
	local comboBox = parentControl.m_owner or self
	if comboBox then
		--comboBox, itemTable, minWidth, maxHeight, spacing
		self:Show(comboBox, self.m_sortedItems, comboBox.m_containerWidth, comboBox.m_height, comboBox:GetSpacing())
	end
	self.control:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self:OnGlobalMouseUp(...) end)
end

function ContextMenuObject:ClearItems()
--	ZO_ComboBox_HideDropdown(self:GetContainer()) Need to use another hide self
	ZO_ClearNumericallyIndexedTable(self.data)
	self:SetSelectedItemText("")
	self.m_selectedItemData = nil
	self:OnClearItems()
end

function ContextMenuObject:IsItemSelected(item)
	return false
end

function ContextMenuObject:AddItem(itemEntry, updateOptions)
	tins(self.data, itemEntry)
	
	if updateOptions ~= ZO_COMBOBOX_SUPPRESS_UPDATE then
		self:UpdateItems()
	end

 --   self:OnItemAdded()
end

--------------------------------------------------------------------
-- DropdownObject
--------------------------------------------------------------------
local DropdownObject = DropdownObject_Base:Subclass()

lib.DropdownObject = DropdownObject

-- DropdownObject:New( -- Just a reference for New
-- Available options are: See below at API function "AddCustomScrollableComboBoxDropdownMenu"
function DropdownObject:Initialize(parent, container, options, depth)
	DropdownObject_Base.Initialize(self, options, dropdownControlPool, depth)
	
	self.submenuPool = ZO_ControlPool:New(LSM_XML_Template_Keyboard, nil, container:GetName() .. '_Submenu')
	self.parent = parent
end

function DropdownObject:ComboBoxIntegration(comboBox)
	comboBox:SetDropdownObject(self)
		
	comboBox.AddItems = function(comboBox, items)
		DropdownObject.AddItems(comboBox, items, self.XMLrowTemplates)
	end
	
	comboBox.ShowDropdownOnMouseUp = function(comboBox)
		DropdownObject.UpdateItemNames(comboBox)
		
		comboBox.m_dropdownObject:SetHidden(false)
		comboBox:AddMenuItems()

		comboBox:SetVisible(true)
	end
	
	--[[ Redundant
	-- To ensure the dropdown object was not changed
	local orig_ShowDropdownOnMouseUp = comboBox.ShowDropdownOnMouseUp
	comboBox.ShowDropdownOnMouseUp = function(comboBox)
		
	--	d( '[LSM] comboBox.ShowDropdownOnMouseUp')
		-- Here we add the dropdown object on comboBox open.
		
	d( '[LSM]comboBox:ShowDropdownOnMouseUp')
	d( 'comboBox.m_dropdownObject ~= self ' .. tostring(comboBox.m_dropdownObject ~= self))
		if comboBox.m_dropdownObject ~= self then
			comboBox:SetDropdownObject(self)
		end
		
		orig_ShowDropdownOnMouseUp(comboBox)
		self.control:BringWindowToTop()
	end
	]]
	
	-- So we can catch right-click on EVENT_GLOBAL_MOUSE_UP
	-- This is where we can prevent the dropdown from closing when opening a context menu.
--	comboBox.OnGlobalMouseUp = function(comboBox, eventCode, button, ctrl, alt, shift, command)
	
	comboBox.OnGlobalMouseUp = function(comboBox, eventCode, button, ctrl, alt, shift, command)
		d( '[LSM] comboBox.OnGlobalMouseUp')
		local dropdownObject = comboBox.m_dropdownObject
		if self:IsDropdownVisible() and dropdownObject and dropdownObject:BypassOnGlobalMouseUp(button) then
			d( 'BypassOnGlobalMouseUp')
		--	dropdownObject:OnGlobalMouseUp(eventCode, button, ctrl, alt, shift, command)
		else
		   ZO_ComboBox.OnGlobalMouseUp(comboBox,eventCode, button, ctrl, alt, shift, command)
		end
	end
	
	-- This allows us to show currently selected item as highlighted in the submenu.
	comboBox.IsItemSelected = function(comboBox, item)
		if not comboBox.m_enableMultiSelect then
			return comboBox.m_selectedItemData == item
		end

		for i, itemData in ipairs(comboBox.m_multiSelectItemData) do
			if itemData == item then
				return true
			end
		end

		return false
	end
	
	comboBox.RemoveItemFromSelected = function(comboBox, item)
		if not comboBox.m_enableMultiSelect then
			comboBox.m_selectedItemData = nil
		end
		
		for i, itemData in ipairs(comboBox.m_multiSelectItemData) do
			if itemData == item then
				table.remove(comboBox.m_multiSelectItemData, i)
				return
			end
		end
	end
end

function DropdownObject:UpdateItemNames()
	for k, item in ipairs(self.m_sortedItems) do
		local name = getValueOrCallback(item.name, data)
		
		if item.label ~= nil then
			name  = getValueOrCallback(item.label, data)
		end
		
		if name ~= 	item.name then
			item.name = name
		end
		d( item.name)
	end
end

function DropdownObject:AddItems(items, templates)
	-- We are using this to add custom layout info to entries if needed.
		
	local numItems = #items
	for i, item in pairs(items) do
		local isLastEntry = i == numItems
		
		local hasSubmenu = setItemEntryCustomTemplate(item, isLastEntry, templates)
		
		if hasSubmenu then
			item.hasSubmenu = true
			-- Since this is a submenu, it is marked as "new" if it contains any descendants that are marked as "isNew = true".
			item.isNew = areAnyEntriesNew(item)
		end
		
		self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
	end
end

function DropdownObject:HideDropdownInternal()
	if self.owner then
		self.owner:HideDropdownInternal()
	end
end

--[[
function ZO_ComboBox:ShowDropdownInternal()
	-- Just set the global mouse up handler here... we want the combo box to exhibit the same behvaior
	-- as a context menu, which is dismissed when the user clicks outside the menu or on a menu item
	-- (but not in the menu otherwise)
	self.m_container:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self:OnGlobalMouseUp(...) end)
end

function ZO_ComboBox_Base:HideDropdown()
	if self:IsDropdownVisible() then
		self:HideDropdownInternal()
	end
end

]]

--[[
function DropdownObject:Show(comboBox, itemTable, minWidth, maxHeight, spacing)
	d( 'comboBox ' .. tostring(comboBox ~= nil))
   ZO_ComboBoxDropdown_Keyboard.Show(self, comboBox, itemTable, minWidth, maxHeight, spacing)
end
]]

--------------------------------------------------------------------
-- Public API functions
--------------------------------------------------------------------
lib.persistentMenus = false -- controls if submenus are closed shortly after the mouse exists them
function lib.GetPersistentMenus()
	return lib.persistentMenus
end
function lib.SetPersistentMenus(persistent)
	lib.persistentMenus = persistent
end

lib.MapEntries = mapEntries

--[Custom scrollable ZO_ComboBox menu]
----------------------------------------------------------------------
--Adds a scroll helper to the comboBoxControl dropdown entries, and enables submenus (scollable too) at the entries.
--	control parent 							Must be the parent control of the comboBox
--	control comboBoxControl 				Must be any ZO_ComboBox control (e.g. created from virtual template ZO_ComboBox)
 --  table options:optional = {
 --		number visibleRowsDropdown:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened dropdown
 --		number visibleRowsSubmenu:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened submenus
 --		boolean sortEntries:optional			Boolean or function returning boolean if items in the main-/submenu should be sorted alphabetically
--		table	XMLRowTemplates:optional		Table or function returning a table with key = row type of lib.scrollListRowTypes and the value = subtable having
--												"template" String = XMLVirtualTemplateName, rowHeight number = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,setupFunc = function(control, data, list) end
--												-->See local table "defaultXMLTemplates" in LibScrollableMenu
--												-->Attention: If you do not specify all template attributes, the non-specified will be mixedIn from defaultXMLTemplates[entryType_ID] again!
--		{
--			[lib.scrollListRowTypes.ENTRY_ID] = 		{ template = "XMLVirtualTemplateRow_ForEntryId", ... }
--			[lib.scrollListRowTypes.SUBMENU_ENTRY_ID] = { template = "XMLVirtualTemplateRow_ForSubmenuEntryId", ... },
--			...
--		}
--		table	narrate:optional				Table or function returning a table with key = narration event and value = function called for that narration event.
--												Each functions signature/parameters is shown below!
--												-> The function either builds your narrateString and narrates it in your addon.
--												   Or you must return a string as 1st return param (and optionally a boolean "stopCurrentNarration" as 2nd return param. If this is nil it will be set to false!)
--													and let the library here narrate it for you via the UI narration
--												Optional narration events can be:
--												"OnDropdownMouseEnter" 	function(m_dropdownObjectObject, dropdownControl)  Build your narrateString and narrate it now, or return a string and let the library narrate it for you end
--												"OnDropdownMouseExit"	function(m_dropdownObjectObject, dropdownControl) end
--												"OnMenuShow"			function(m_dropdownObjectObject, dropdownControl, nil, nil) end
--												"OnMenuHide"			function(m_dropdownObjectObject, dropdownControl) end
--												"OnSubMenuShow"			function(m_dropdownObjectObject, parentControl, anchorPoint) end
--												"OnSubMenuHide"			function(m_dropdownObjectObject, parentControl) end
--												"OnEntryMouseEnter"		function(m_dropdownObjectObject, entryControl, data, hasSubmenu) end
--												"OnEntryMouseExit"		function(m_dropdownObjectObject, entryControl, data, hasSubmenu) end
--												"OnEntrySelected"		function(m_dropdownObjectObject, entryControl, data, hasSubmenu) end
--												"OnCheckboxUpdated"		function(m_dropdownObjectObject, checkboxControl, data) end
--			Example:	narrate = { ["OnDropdownMouseEnter"] = myAddonsNarrateDropdownOnMouseEnter, ... }
--  }

function AddCustomScrollableComboBoxDropdownMenu(parent, comboBoxContainer, options)
	assert(parent ~= nil and comboBoxContainer ~= nil, MAJOR .. " - AddCustomScrollableComboBoxDropdownMenu ERROR: Parameters parent and comboBoxControl must be provided!")

	if comboBoxContainer.comboBox == nil then
--		comboBoxContainer.comboBox = comboBoxControl
	end
	if comboBoxContainer.dropdown == nil then
--		comboBoxContainer.dropdown = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
	end
	
--	d( parent:GetName())


	--Add a new scrollable menu helper
--	comboBoxContainer.dropdown.m_submenu = lib.submenu
	-- Add
--	local dropdownObject = DropdownObject:New(parent, comboBoxContainer, options, 2, 'Dropdown')
	local dropdownObject = DropdownObject:New(parent, comboBoxContainer, options)
	dropdownObject.isTopLevel = true
	
	local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
	dropdownObject:ComboBoxIntegration(comboBox)

	--todo: 20240229 global preshowCallback? param? Or where is it from?
	--[[
	if preshowCallback then
	--TODO: v
	--	dropdownObject:SetPreshowDropdownCallback(preshowCallback)
		--- Or
	--	comboBox:SetPreshowDropdownCallback(preshowCallback)
	end
	]]
	
	return dropdownObject
end
--TODO: remove or make use of --v
local addCustomScrollableComboBoxDropdownMenu = AddCustomScrollableComboBoxDropdownMenu

--[Custom scrollable context menu at any control]
--Add a scrollable menu to any control (not only a ZO_ComboBox), e.g. to an inventory row
--by creating a DUMMY ZO_ComboBox, adding the ScrollHelper class to it and use it
----------------------------------------------------------------------

--Adds a new entry to the context menu entries with the shown text, which calls the callback function once clicked.
--If entries is provided the entry will be a submenu having those entries. The callback can only be used if entries are passed in
--but normally it should be nil in that case
function AddCustomScrollableMenuEntry(text, callback, entryType, entries, isNew)
	assert(text ~= nil, sfor('[LibScrollableMenu:AddCustomScrollableMenuEntry] String or function returning a string expected, got %q = %s', "text", tos(text)))
--	local scrollHelper = initCustomScrollMenuControl()
--	scrollHelper = scrollHelper or getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	local options = g_contextMenu:GetOptions()

	--If no entryType was passed in: Use normal text line type
	entryType = entryType or lib.LSM_ENTRY_TYPE_NORMAL
	if not allowedEntryTypesForContextMenu[entryType] then
		entryType = lib.LSM_ENTRY_TYPE_NORMAL
	end
	if entryType ~= lib.LSM_ENTRY_TYPE_HEADER and entryType ~= lib.LSM_ENTRY_TYPE_DIVIDER and entries == nil then
		assert(type(callback) == "function", sfor('[LibScrollableMenu:AddCustomScrollableMenuEntry] Callback function expected, got %q = %s', "callback", tos(callback)))
	end

	-->Todo: if entryType is not in lib.allowedContextMenuEntryTypes then change to lib.LSM_ENTRY_TYPE_NORMAL
	--Or is it a header line?
	local isHeader = entryType == lib.LSM_ENTRY_TYPE_HEADER
	--Or a clickable checkbox line?
	local isCheckbox = entryType == lib.LSM_ENTRY_TYPE_CHECKBOX
	--or just a ---------- divider line?
	local isDivider = entryType == lib.LSM_ENTRY_TYPE_DIVIDER or text == libDivider
	if isDivider == true then entryType = lib.LSM_ENTRY_TYPE_DIVIDER end

	--Add the line of the context menu to the internal tables. Will be read as the ZO_ComboBox's dropdown opens and calls
	--:AddMenuItems() -> Added to internal scroll list then
	
	g_contextMenu:AddItem({
		isDivider		= isDivider,
		isHeader		= isHeader,
		isCheckbox		= isCheckbox,
		isNew			= getValueOrCallback(isNew, options) or false,
		--The shown text line of the entry
		name			= getValueOrCallback(text, options),
		--Callback function as context menu entry get's selected. Will also work for an enry where a submenu is available (but usually is not provided in that case)
		callback		= not isDivider and callback, --ZO_ComboBox:SelectItem will call the item.callback(self, item.name, item), where item = { isHeader = ... }
		--Any submenu entries (with maybe nested submenus)?
		entries			= entries,
	}, ZO_COMBOBOX_SUPPRESS_UPDATE)
end
local addCustomScrollableMenuEntry = AddCustomScrollableMenuEntry

--Adds an entry having a submenu (or maybe nested submenues) in the entries table
function AddCustomScrollableSubMenuEntry(text, entries)
	addCustomScrollableMenuEntry(text, nil, lib.LSM_ENTRY_TYPE_NORMAL, entries, nil)
end

--Adds a divider line to the context menu entries
function AddCustomScrollableMenuDivider()
	addCustomScrollableMenuEntry(libDivider, nil, lib.LSM_ENTRY_TYPE_DIVIDER, nil, nil)
end

--Pass in a table with predefined context menu entries and let them all be added in order of the table's number key
function AddCustomScrollableMenuEntries(contextMenuEntries)
--	g_contextMenu:AddItems(contextMenuEntries)
	
	if ZO_IsTableEmpty(contextMenuEntries) then return end
	for _, v in ipairs(contextMenuEntries) do
		addCustomScrollableMenuEntry(v.label or v.text, v.callback, v.entryType, v.entries, v.isNew)
	end
	return true
end


--Set the options (visible rows max, etc.) for the scrollable context menu
function SetCustomScrollableMenuOptions(options)
	local optionsTableType = type(options)
	assert(optionsTableType == 'table' , sfor('[LibScrollableMenu:SetCustomScrollableMenuOptions] table expected, got %q = %s', "options", tos(optionsTableType)))

	if options then
		g_contextMenu:Clear()
		g_contextMenu:UpdateOptions(options)
	end
end
--setCustomScrollableMenuOptions = SetCustomScrollableMenuOptions

--Add a new scrollable context menu with the defined entries table.
--You can add more entries later via AddCustomScrollableMenuEntry function too
function AddCustomScrollableMenu(parent, entries, options)
	local entryTableType = type(entries)
	assert(entryTableType == 'table' , sfor('[LibScrollableMenu:AddCustomScrollableMenu] table expected, got %q = %s', "entries", tos(entryTableType)))

	if options then
		g_contextMenu:Clear()
		g_contextMenu:UpdateOptions(options)
	end

	g_contextMenu:AddItems(entries)
	return g_contextMenu
end

--Show the custom scrollable context menu now
function ShowCustomScrollableMenu(controlToAnchorTo, point, relativePoint, offsetX, offsetY, options)
	d("[LSM]ShowCustomScrollableMenu")
	controlToAnchorTo = controlToAnchorTo or moc()
	g_contextMenu:ShowContextMenu(controlToAnchorTo)
	return true
end

--Hide the custom scrollable context menu and clear internal variables, mouse clicks etc.
function ClearCustomScrollableMenu()
	d("[LSM]ClearCustomScrollableMenu")
	
	if g_contextMenu:IsDropdownVisible() then
		g_contextMenu:HideDropdown()
	end
	g_contextMenu:ClearItems()
	return true
end

--[[
function LibScrollableMenu_GetContextMenuObject()
	return g_contextMenu
end
]]



--Custom tooltip function
--[[
Function to show or hide a custom tooltip control. Pass that in to the data table of any entry, via data.customTooltip!

Your function needs to create and show/hide that control, and populate the text etc to the control too!
Parameters:
-data The table with the current data of the rowControl
-rowControl The userdata of the control the tooltip should show about
-showOrHide boolean true to show, or hide to hide the tooltip

myAddon.customTooltipFunc(table data, userdata rowControl, boolean showOrHide)
e.g. data = { name="Test 1", label="Test", customTooltip=function(data, rowControl, showOrHide) ... end, ... }
]]



------------------------------------------------------------------------------------------------------------------------
-- XML functions
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------
local function onAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
	
	g_contextMenu = ContextMenuObject:New(1)
	lib.contextMenu = g_contextMenu
end
EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
EM:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, onAddonLoaded)


------------------------------------------------------------------------------------------------------------------------
-- Global library reference
------------------------------------------------------------------------------------------------------------------------
LibScrollableMenu = lib

--[[TODO:
fix where m_dropdownObject replaced dropdownHelper

UnParent and hide submenu comboBox
Deal with contextMenus


-- TODO: Decide on what to pass, in LibCustomMenus it always passes ZO_Menu as the 1st parameter
-- but since we don't use that there are a few options:
--	1) Always pass the root dropdown and never a submenu dropdown
--	2) Pass root dropdown for initial entries and the appropriate submenu dropdown for the rest
--	3) Don't pass any dropdown control or object (!!CURRENTLY USED!!)
-- Another decision is if we pass the dropdown control, the parent container or the comboBox object
--
-- Regardless of the above we always pass the control/entry data since in a scroll list the controls
-- aren't fixed for each entry.
local function getValueOrCallback(arg, ...)
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end

]]
