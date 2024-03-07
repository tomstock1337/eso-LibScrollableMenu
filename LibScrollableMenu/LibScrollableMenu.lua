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

--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------

--ZOs local speed-up/reference variables
local zo_comboBox_base_addItem = ZO_ComboBox_Base.AddItem
local zo_comboBox_base_hideDropdown = ZO_ComboBox_Base.HideDropdown

local zo_comboBox_selectItem = ZO_ComboBox.SelectItem
local zo_comboBox_onGlobalMouseUp = ZO_ComboBox.OnGlobalMouseUp
local zo_comboBox_setItemEntryCustomTemplate = ZO_ComboBox.SetItemEntryCustomTemplate

local zo_comboBoxDropdown_onEntrySelected = ZO_ComboBoxDropdown_Keyboard.OnEntrySelected
local zo_comboBoxDropdown_onMouseExitEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry
local zo_comboBoxDropdown_onMouseEnterEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry

--Library internal global locals
local g_contextMenu -- The contextMenu (like ZO_Menu): Will be created at onAddonLoaded

--local speed up variables
local EM = EVENT_MANAGER
local SNM = SCREEN_NARRATION_MANAGER

local tos = tostring
local sfor = string.format
local tins = table.insert
--TODO: make use of?
local trem = table.remove

--LibScrollableMenu XML template names
local LSM_XML_Template_Keyboard = MAJOR.. "_Keyboard_Template"

--Timeout data
local libTimeoutNextId = 1
local libTimeoutPattern = MAJOR.."Timeout"

--Sound settings
local origSoundComboClicked = SOUNDS.COMBO_CLICK
local soundComboClickedSilenced = SOUNDS.NONE

--Submenu settings
local SUBMENU_SHOW_TIMEOUT = 500 --350 ms before
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
local ICON_PADDING = 20
local DEFAULT_SPACING = 0
--TODO: remove or make use of --> local PADDING = GetMenuPadding() / 2 -- half the amount looks closer to the regular dropdown
local WITHOUT_ICON_LABEL_DEFAULT_OFFSETX = 4

local DEFAULT_FONT = "ZoFontGame"
local DEFAULT_HEIGHT = 250

--Entry types - For the scroll list's dataType of te menus
						  
local ENTRY_ID = 1
local LAST_ENTRY_ID = 2
local DIVIDER_ENTRY_ID = 3
local HEADER_ENTRY_ID = 4
local SUBMENU_ENTRY_ID = 5
local CHECKBOX_ENTRY_ID = 6

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

local allowedEntryTypesForContextMenu = {
	[lib.LSM_ENTRY_TYPE_NORMAL] = true,
	[lib.LSM_ENTRY_TYPE_DIVIDER] = true,
	[lib.LSM_ENTRY_TYPE_HEADER] = true,
	[lib.LSM_ENTRY_TYPE_CHECKBOX] = true,
}

--Make them accessible for the DropdownObject:New options table -> options.XMLRowTemplates
lib.scrollListRowTypes = {
	ENTRY_ID = ENTRY_ID,
	LAST_ENTRY_ID = LAST_ENTRY_ID,
	DIVIDER_ENTRY_ID = DIVIDER_ENTRY_ID,
	HEADER_ENTRY_ID = HEADER_ENTRY_ID,
	SUBMENU_ENTRY_ID = SUBMENU_ENTRY_ID,
	CHECKBOX_ENTRY_ID = CHECKBOX_ENTRY_ID,
}

--Possible options passed in at the ScrollableHelper menus are:
local possibleLibraryOptions = {
	["visibleRowsDropdown"] = true,
	["visibleRowsSubmenu"] = true,
	["sortEntries"] = true,
	["preshowDropdownFn"] = true,
	["XMLRowTemplates"] = true,
	["narrate"] = true,
}
lib.possibleLibraryOptions = possibleLibraryOptions

--The default values for comboBox options:
--The default values for the context menu options are:
local defaultComboBoxOptions  = {
	["font"] = DEFAULT_FONT,
	["spacing"] = DEFAULT_SPACING,
	["sortEntries"] = DEFAULT_SORTS_ENTRIES,
	["preshowDropdownFn"] = nil,
	["visibleRowsSubmenu"] = DEFAULT_VISIBLE_ROWS,
	["visibleRowsDropdown"] = DEFAULT_VISIBLE_ROWS,
}
lib.defaultComboBoxOptions  = defaultComboBoxOptions

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
	--assert(submenuType == 'table', sfor('['..MAJOR..':recursiveOverEntries] table expected, got %q = %s', "submenu", tos(submenuType)))

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

-- Recursively check for new entries.
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

local function getOptionsForDropdown(dropdown)
	return dropdown.owner.options or {}
end

--Check if a sound should be played if a dropdown entry was selected
local function playSelectedSoundCheck(dropdown)
	silenceComboBoxClickedSound(false)

	local soundToPlay = origSoundComboClicked
	local options = getOptionsForDropdown(dropdown)
	
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
		
		-- TODO: only map entries with callbacks?
		if entry.callback then
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
	assert(entryTableType == 'table' and mapTableType == 'table' , sfor('['..MAJOR..':MapEntries] tables expected, got %q = %s, %q = %s', "entryTable", tos(entryTableType), "mapTable", tos(mapTableType)))
	
	-- Splitting these up so the above is not done each iteration
	doMapEntries(entryTable, mapTable)
end
lib.MapEntries = mapEntries

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
			
		local parent = data.m_parentControl
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
			
			local parent = data.m_parentControl
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
--TODO: see how this effects it 
--	multiIconCtrl:SetDimensions(iconWidth, iconHeight)
	multiIconCtrl:SetHidden(not visible)
end

--Set the custom XML virtual template for a dropdown entry
local function setItemEntryCustomTemplate(item, customEntryTemplates)
	local isHeader = getValueOrCallback(item.isHeader, item)
	local isDivider = (item.label ~= nil and getValueOrCallback(item.label, item) == libDivider) or getValueOrCallback(item.name, item) == libDivider
	local isCheckbox = getValueOrCallback(item.isCheckbox, item)
	--local isCheckboxChecked = GetValueOrCallback(item.checked, item)
	--local icon = GetValueOrCallback(item.icon, item)

	local hasSubmenu = item.entries ~= nil

	local entryType = (isDivider and DIVIDER_ENTRY_ID) or (isCheckbox and CHECKBOX_ENTRY_ID) or (isHeader and HEADER_ENTRY_ID) or
			(hasSubmenu and SUBMENU_ENTRY_ID) or ENTRY_ID

--	item.hasSubmenu = hasSubmenu
--	item.isDivider = isDivider
	if entryType then
		local customEntryTemplate = customEntryTemplates[entryType].template
		zo_comboBox_setItemEntryCustomTemplate(item, customEntryTemplate)
	end

	return hasSubmenu
end

local function processNameString(data)
	local name = getValueOrCallback(data.name, data)

	--Passed in an alternative text/function returning a text to show at the label control of the menu entry?
	if data.label ~= nil then
		name = getValueOrCallback(data.label, data)
	end
	
	data.name = name
end

--------------------------------------------------------------------
-- Local tooltip functions
--------------------------------------------------------------------

--Hide the tooltip of a dropdown entry
local function hideTooltip()
	if lib.lastCustomTooltipFunction then
		lib.lastCustomTooltipFunction()
	else
		ClearTooltip(InformationTooltip)
	end
end

--Show the tooltip of a dropdown entry. First check for any custom tooltip function that handles the control show/hide
--and if none is provided use default InformationTooltip
local function showTooltip(control, data, hasSubmenu)
	local tooltipData = getValueOrCallback(data.tooltip, data)
	local tooltipText = getValueOrCallback(tooltipData, data)
	
	--To prevent empty tooltips from opening.
	if tooltipText == nil then return end
	
	local point, offsetX, offsetY, relativePoint = BOTTOMLEFT, 0, 0, TOPRIGHT
	
	local parentControl = control
	if control.m_dropdownObject then
		-- Lets get the dropdown control if called from another type of dropdown.
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
			point, relativePoint = RIGHT, LEFT
		end
	else
		if hasSubmenu then
			point, relativePoint = BOTTOMLEFT, TOPLEFT
		else
			point, relativePoint = LEFT, RIGHT
		end
	end
	
	lib.lastCustomTooltipFunction = nil
	
	local customTooltipFunc = data.customTooltip
	if type(customTooltipFunc) == "function" then
		lib.lastCustomTooltipFunction = customTooltipFunc(data, control, point, offsetX, offsetY, relativePoint)
	else
		InitializeTooltip(InformationTooltip, control, point, offsetX, offsetY, relativePoint)
		SetTooltipText(InformationTooltip, tooltipText)
		InformationTooltipTopLevel:BringWindowToTop()
	end
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
	local updaterName = UINarrationUpdaterName ..tos(uniqueId)
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

LSM_DEBUG = {
	init = {},
	submenu = {},
	owners = {},
}

--------------------------------------------------------------------
-- Dropdown entry/row handlers
--------------------------------------------------------------------

local function onMouseEnter(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	
	dropdown:Narrate("OnEntryMouseEnter", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseEnter', data, control)
	
	return dropdown
end

local function onMouseExit(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	
	dropdown:Narrate("OnEntryMouseExit", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseExit', data, control)
	
	return dropdown
end

local function onMouseUp(control, data, hasSubmenu, button, upInside)
	local dropdown = control.m_dropdownObject
	
	dropdown:Narrate("OnEntrySelected", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnSelected', data, control)
	
	return dropdown
end

local has_submenu = true
local no_submenu = false

local handlerFunctions  = {
	['onMouseEnter'] = {
		[ENTRY_ID] = function(control, data, ...)
			local dropdown = onMouseEnter(control, data, no_submenu)
			clearNewStatus(control, data)
			return false
		end,
		[HEADER_ENTRY_ID] = function(control, data, ...)
			-- Return true to skip the default handler.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, data, ...)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, data, ...)
			d( 'onMouseEnter [SUBMENU_ENTRY_ID]')
			-- Must clear now. Otherwise, moving onto a submenu will close it from exiting previous row.
			local dropdown = onMouseEnter(control, data, has_submenu)
			clearTimeout()
			dropdown:ShowSubmenu(control)
			return false
		end,
		[CHECKBOX_ENTRY_ID] = function(control, data, ...)
			local dropdown = onMouseEnter(control, data, no_submenu)
			return false
		end,
	},
	['onMouseExit'] = {
		[ENTRY_ID] = function(control, data)
			local dropdown = onMouseExit(control, data, no_submenu)
			return false
		end,
		[HEADER_ENTRY_ID] = function(control, data)
			-- Return true to skip the default handler.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, data)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, data)
			local dropdown = onMouseExit(control, data, has_submenu)
			--TODO: This is onMouseExit, MouseIsOver(control) should not apply.
			if not (MouseIsOver(control) or dropdown:IsEnteringSubmenu()) then
				dropdown:OnMouseExitTimeout(control)
			end
			return false
		end,
		[CHECKBOX_ENTRY_ID] = function(control, data)
			local dropdown = onMouseExit(control, data, no_submenu)
			return false
		end,
	},
	['onMouseUp'] = {
		[ENTRY_ID] = function(control, data, button, upInside)
			d( 'onMouseUp [ENTRY_ID]')
			local dropdown = onMouseUp(control, data, no_submenu, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					dropdown:SelectItemByIndex(control.m_data.m_index)
				end
			end
			return true
		end,
		[HEADER_ENTRY_ID] = function(control, data, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, data, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, data, button, upInside)
			local dropdown = onMouseUp(control, data, has_submenu, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					if data.callback then
						dropdown:SelectItemByIndex(control.m_data.m_index)
					end
				end
			else
				--TODO: Do we want to close dropdowns on mouse up not upInside?
			end
			return true
		end,
		[CHECKBOX_ENTRY_ID] = function(control, data, button, upInside)
			d( 'onMouseUp [CHECKBOX_ENTRY_ID]')
			local dropdown = control.m_dropdownObject
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					-- left click on row toggles the checkbox.
					playSelectedSoundCheck(dropdown)
					ZO_CheckButton_OnClicked(control.m_checkbox)
					data.checked = ZO_CheckButton_IsChecked(control.m_checkbox)
				end
			end
			return true
		end,
	},
}

local function runHandler(handlerTable, control, ...)
	local handler = handlerTable[control.typeId]
	if handler then
		return handler(control, ...)
	end

	return false
end

--------------------------------------------------------------------
-- dropdownClass
--------------------------------------------------------------------

local dropdownClass = ZO_ComboBoxDropdown_Keyboard:Subclass()

-- dropdownClass:New(To simplify locating the beginning of the class
function dropdownClass:Initialize(parent, comboBoxContainer, depth)
	local dropdownControl = CreateControlFromVirtual(comboBoxContainer:GetName(), GuiRoot, "LibScrollableMenu_Keyboard_Template", depth)
	ZO_ComboBoxDropdown_Keyboard.Initialize(self, dropdownControl)
	dropdownControl.object = self
	self.m_comboBox = comboBoxContainer.m_comboBox
	self.m_container = comboBoxContainer
	self.owner = parent

	self:SetHidden(true)
	
	self.m_parentMenu = parent.m_parentMenu
	self.m_sortedItems = {}
end

-- Redundancy functions. These functions redirect back to the comboBox for if "scrollHelper" was used to add items.
function dropdownClass:AddItems(items)
	if self.owner then
		self.owner:AddItems(items)
	end
end

function dropdownClass:AddItem(item)
	if self.owner then
		self.owner:AddItem(item)
	end
end

--Narration
function dropdownClass:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	self.owner:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
end

function dropdownClass:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthAdjust)
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

function dropdownClass:AnchorToControl(parentControl)
	local width, height = GuiRoot:GetDimensions()

	local offsetX = ZO_SCROLL_BAR_WIDTH - 4

	local right = true
	
	if self.m_parentMenu.m_dropdownObject and self.m_parentMenu.m_dropdownObject.anchorRight ~= nil then
		right = self.m_parentMenu.m_dropdownObject.anchorRight
	end
	
	if not right or parentControl:GetRight() + self.control:GetWidth() > width then
		right = false
	end

	self.control:ClearAnchors()
	if right then
		self.control:SetAnchor(TOPLEFT, parentControl, TOPRIGHT, offsetX)
	else
		self.control:SetAnchor(TOPRIGHT, parentControl, TOPLEFT)
	end
	
	self.anchorRight = right
end

function dropdownClass:AnchorToComboBox(conboBox)
	local parentControl = conboBox:GetContainer()
	self.control:ClearAnchors()
	self.control:SetAnchor(TOPLEFT, parentControl, BOTTOMLEFT)
end

function dropdownClass:AnchorToMouse()
	local menuToAnchor = self.control
	
	local x, y = GetUIMousePosition()
	local width, height = GuiRoot:GetDimensions()

	menuToAnchor:ClearAnchors()
	
	local right = true
	if x + menuToAnchor:GetWidth() > width then
		right = false
	end
	local bottom = true
	if y + menuToAnchor:GetHeight() > height then
		bottom = false
	end

	if right then
		x = x + 10
		if bottom then
			menuToAnchor:SetAnchor(TOPLEFT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMLEFT, nil, TOPLEFT, x, y)
		end
	else
		x = x - 10
		if bottom then
			menuToAnchor:SetAnchor(TOPRIGHT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMRIGHT, nil, TOPLEFT, x, y)
		end
	end
end

function dropdownClass:GetScrollbar()
d("[LSM]dropdownClass:GetScrollbar")
	local scrollCtrl = self.scrollControl
	local scrollBar = scrollCtrl ~= nil and scrollCtrl.scrollbar
	if scrollBar then ---and scrollCtrl.useScrollbar == true then (does not work for menus where there is no scrollabr active, but used in general!)
d(">scrollBar found!")
		return scrollBar
	end
	return
end

function dropdownClass:GetSubmenu()
	if self.owner then
		self.m_submenu = self.owner.m_submenu
	end

	return self.m_submenu
end

function dropdownClass:IsDropdownVisible()
	-- inherited ZO_ComboBoxDropdown_Keyboard:IsHidden
	return not self:IsHidden()
end

function dropdownClass:IsEnteringScrollbar()
d("[LSM]dropdownClass:IsEnteringScrollbar")
	local scrollbar = self:GetScrollbar()
	if scrollbar then
d(">scrollbar found")
		if MouseIsOver(scrollbar) then
d(">>is over scrollbar")
			return true
		else
			--scrollbar found but not active: How to detect if the mouse is over it at the moment, because it is SetHidden(true)
			if scrollbar:IsHidden() then
				scrollbar:SetHidden(false)
				local wasMouseOverScrollbar = MouseIsOver(scrollbar)
				scrollbar:SetHidden(true)
d(">>scrollbar is hidden. Mouse is over it? " ..tos(wasMouseOverScrollbar))
				return wasMouseOverScrollbar
			end
		end
	end
	return false
end

function dropdownClass:IsEnteringSubmenu()
	local submenu = self:GetSubmenu()
	if submenu then
		if submenu:IsDropdownVisible() and submenu:IsMouseOverControl() then
			return true
		end
	end
	return false
end

function dropdownClass:IsItemSelected(item)
	if self.owner and self.owner.IsItemSelected then
		return self.owner:IsItemSelected(item)
	end
	return false
end

function dropdownClass:IsMouseOverOpeningControl()
	return false
end

function dropdownClass:OnMouseEnterEntry(control)
--	d( '[LSM]dropdownClass:OnMouseEnterEntry')
--	self.control:BringWindowToTop()
	
	-- Added here for when mouse is moved from away from dropdowns over a row, it will know to close specific children
	self:OnMouseExitTimeout(control)

	local data = getControlData(control)
	if not runHandler(handlerFunctions['onMouseEnter'], control, data) then
		zo_comboBoxDropdown_onMouseEnterEntry(self, control)
	end
	
	if data.tooltip or data.customTooltip then
		self:ShowTooltip(control, data)
	end
	
	--TODO: Conflicting OnMouseExitTimeout
	if g_contextMenu:IsDropdownVisible() then
		g_contextMenu.m_dropdownObject:OnMouseExitTimeout(control)
	end
end

function dropdownClass:OnMouseExitEntry(control)
--	d( '[LSM]dropdownClass:OnMouseExitEntry')
--	d( control:GetName())
	
	hideTooltip()
	local data = getControlData(control)
	self:OnMouseExitTimeout(control)
	if not runHandler(handlerFunctions['onMouseExit'], control, data) then
		zo_comboBoxDropdown_onMouseExitEntry(self, control)
	end
	
	if not lib.GetPersistentMenus() then
--		self:OnMouseExitTimeout(control)
	end
end

function dropdownClass:OnMouseExitTimeout(control)
--	clearTimeout()
	d( "[LSM]dropdownClass:OnMouseExitTimeout-control: " ..tos(control:GetName()))

	setTimeout(function()
		self.owner:HideOnMouseExit(moc())
	end)
end

function dropdownClass:OnEntrySelected(control, button, upInside)
--	d( '[LSM]dropdownClass:OnEntrySelected IsUpInside ' .. tos(upInside) .. ' Button ' .. tos(button))
	
	local data = getControlData(control)
	if not runHandler(handlerFunctions['onMouseUp'], control, data, button, upInside) then
		zo_comboBoxDropdown_onEntrySelected(self, control)
	end
	
	if upInside then
		if button == MOUSE_BUTTON_INDEX_RIGHT then
			if data.contextMenuCallback then
				data.contextMenuCallback(control)
			end
		end
	end
end

function dropdownClass:SelectItemByIndex(index, ignoreCallback)
	if self.owner then
		self:HideDropdown()
		playSelectedSoundCheck(self)
		return self.owner:SelectItemByIndex(index, ignoreCallback)
	end
end

local function createScrollableComboBoxEntry(self, item, index, entryType)
	local entryData = ZO_EntryData:New(item)
	entryData.m_index = index
	entryData.m_owner = self.owner
	entryData.m_dropdownObject = self
	entryData:SetupAsScrollListDataEntry(entryType)
	return entryData
end

function dropdownClass:Show(comboBox, itemTable, minWidth, maxHeight, spacing, maxRows)
	d( sfor('minWidth = %s, maxHeight = %s, spacing = %s, maxRows = %s', tos(minWidth), tos(maxHeight), tos(spacing), tos(maxRows)))
	self.owner = comboBox
	
	ZO_ScrollList_Clear(self.scrollControl)

	self:SetSpacing(spacing)

	local numItems = #itemTable
	local dataList = ZO_ScrollList_GetDataList(self.scrollControl)

	local largestEntryWidth = 0
	local allItemsHeight = 0

	local rowCount = 0
	for i = 1, numItems do
		local item = itemTable[i]
		processNameString(item)

		local isLastEntry = i == numItems
		local entryHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT
		local entryType = ENTRY_ID
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

		if item.name ~= '' and item.name ~= lib.DIVIDER then
			rowCount = rowCount + 1
		end

		if rowCount <= maxRows then
			allItemsHeight = allItemsHeight + entryHeight
		end

--[[
		if i <= maxRows then
			allItemsHeight = allItemsHeight + entryHeight
		end
]]

		local entry = createScrollableComboBoxEntry(self, item, i, entryType)
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

	allItemsHeight = allItemsHeight + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2)

	local scroll_bar_padding = ZO_SCROLL_BAR_WIDTH
	local desiredHeight = maxHeight
	if allItemsHeight < desiredHeight then
		desiredHeight = allItemsHeight
		scroll_bar_padding = 0
	end

	-- Allow the dropdown to automatically widen to fit the widest entry, but
	-- prevent it from getting any skinnier than the container's initial width
	local totalDropDownWidth = largestEntryWidth + ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2 + scroll_bar_padding
	if totalDropDownWidth > minWidth then
		self.control:SetWidth(totalDropDownWidth)
	else
		self.control:SetWidth(minWidth)
	end

	self.control:SetHeight(desiredHeight)
	ZO_ScrollList_SetHeight(self.scrollControl, desiredHeight)

	ZO_Scroll_SetUseFadeGradient(self.scrollControl, desiredHeight >= DEFAULT_HEIGHT)

	ZO_ScrollList_Commit(self.scrollControl)
	self.control:BringWindowToTop()
end

function dropdownClass:ShowSubmenu(control)
	if self.owner then
		self.owner:ShowSubmenu(control)
	end
end

function dropdownClass:ShowTooltip(control, data)
	if data.hasSubmenu then
		local submenu = self:GetSubmenu()
		zo_callLater(function()
			showTooltip(submenu.m_dropdownObject.control, data, data.hasSubmenu)
		end, 10)
	else
		showTooltip(control, data, data.hasSubmenu)
	end
end

function dropdownClass:HideDropdown()
	if self.owner then
		self.owner:HideDropdown()
	end
end

function dropdownClass:HideSubmenu()
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end
end

-- These are added here to make use of it's control to register the events too, 
-- instead of menu using the same control to register the same event for different dropdowns.
function dropdownClass:ShowDropdownInternal()
	self.control:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self.owner:OnGlobalMouseUp(...) end)
end

function dropdownClass:HideDropdownInternal()
	self.control:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)
end

--------------------------------------------------------------------
-- ComboBox classes
--------------------------------------------------------------------
local HEADER_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED))
local DEFAULT_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
local DEFAULT_TEXT_HIGHLIGHT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))

local comboBoxDefaults = {
	m_selectedItemData = nil,
	m_selectedColor = { GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED) },
	m_disabledColor = ZO_ERROR_COLOR,
	m_sortOrder = ZO_SORT_ORDER_UP,
	m_sortType = ZO_SORT_BY_NAME,
	m_sortsItems = true,
	m_isDropdownVisible = false,
	m_preshowDropdownFn = nil,
	m_spacing = 0,
	m_font = DEFAULT_FONT,
	m_normalColor = DEFAULT_TEXT_COLOR,
	m_highlightColor = DEFAULT_TEXT_HIGHLIGHT,
	m_customEntryTemplateInfos = nil,
	m_enableMultiSelect = false,
	m_maxNumSelections = nil,
	m_height = DEFAULT_HEIGHT,
	horizontalAlignment = TEXT_ALIGN_LEFT,
}

--------------------------------------------------------------------
-- comboBoxClass
--------------------------------------------------------------------
local comboBoxClass = ZO_ComboBox:Subclass()
local submenuClass = comboBoxClass:Subclass()

-- comboBoxClass:New(To simplify locating the beginning of the class
function comboBoxClass:Initialize(parent, comboBoxContainer, options, depth)
	-- Add all comboBox defaults not present.
--	self.options = {}
	local defaults = ZO_DeepTableCopy(comboBoxDefaults)
	mixinTableAndSkipExisting(self, defaults)

	self.m_name = comboBoxContainer:GetName()
	self.m_container = comboBoxContainer
	self.m_sortedItems = {}
	self.m_openDropdown = comboBoxContainer:GetNamedChild("OpenDropdown")
	self.m_containerWidth = comboBoxContainer:GetWidth()
	self.m_selectedItemText = comboBoxContainer:GetNamedChild("SelectedItemText")
	self.m_multiSelectItemData = {}
	
	local dropdownObject = self:GetDropdownObject(comboBoxContainer, depth)
	self:SetDropdownObject(dropdownObject)
	-- Uncomment below if they ever remove it from SetDropdownObject
	-- self.m_scroll = dropdownObject.scrollControl
	
	self.optionsChanged = true
	self:UpdateOptions(options)
end

-- [Replaced functions]
-- Adds widthAdjust as a valid parameter
function comboBoxClass:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthAdjust)
	if not self.m_customEntryTemplateInfos then
		self.m_customEntryTemplateInfos = {}
	end

	local customEntryInfo =
	{
		entryTemplate = entryTemplate,
		entryHeight = entryHeight,
		widthAdjust = widthAdjust,
		setupFunction = setupFunction,
	}

	self.m_customEntryTemplateInfos[entryTemplate] = customEntryInfo

	self.m_dropdownObject:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthAdjust)
end

-- Adds the customEntryTemplate to all items added
function comboBoxClass:AddItem(itemEntry, updateOptions, templates)
	-- Append
	if not itemEntry.customEntryTemplate then
		local hasSubmenu = setItemEntryCustomTemplate(itemEntry, self.XMLrowTemplates)
		
		if hasSubmenu then
			itemEntry.hasSubmenu = true
			itemEntry.isNew = areAnyEntriesNew(itemEntry)
		end
	end
	zo_comboBox_base_addItem(self, itemEntry, updateOptions)
end

-- Changed to force updating items and, to set anchor since anchoring was removed from :Show( due to separate anchoring based on comboBox type. (comboBox to self /submenu to row/contextMenu to mouse)
function comboBoxClass:AddMenuItems()
	self:UpdateItems()
	self.m_dropdownObject:AnchorToComboBox(self)
	
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing(), self:GetMaxRows())
end

-- Changed to hide tooltip and, if available, it's submenu
-- We hide the tooltip here so it is hidden if the dropdown is hidden OnGlobalMouseUp
function comboBoxClass:HideDropdown()
	hideTooltip()
	-- Recursive through all open submenus and close them starting from last.
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end
	
	zo_comboBox_base_hideDropdown(self)
end

function comboBoxClass:SelectItemByIndex(index, ignoreCallback)
	d( 'SelectItemByIndex ' .. tos(index))
	return zo_comboBox_selectItem(self, self.m_sortedItems[index], ignoreCallback)
end

-- Changed to bypass if needed.
function comboBoxClass:OnGlobalMouseUp(eventCode, ...)
	d( 'BypassOnGlobalMouseUp ' .. tos(self:BypassOnGlobalMouseUp(...)))
	if not self:BypassOnGlobalMouseUp(...) then
	   zo_comboBox_onGlobalMouseUp(self ,eventCode , ...)
	end
end

-- [New functions]
function comboBoxClass:IsMouseOverScrollbarControl()
	local mocCtrl = moc()
	if mocCtrl ~= nil then
		local parent = mocCtrl:GetParent()
		if parent ~= nil then
			local gotScrollbar = parent.scrollbar ~= nil
			--Clicked the up/down buttons?
			if not gotScrollbar then
				parent = parent:GetParent()
				gotScrollbar = parent and parent.scrollbar ~= nil
			end
			return gotScrollbar or false
		end
	end
	return false
end
--[[
function comboBoxClass:IsMouseOverScrollbarControl()
	local moc = moc()
	local scrollbar = self.m_scroll.scrollbar
	if scrollbar ~= nil and moc ~= nil then
		return moc == scrollbar or moc:GetParent() == scrollbar
	end
	return false
end

]]

function comboBoxClass:BypassOnGlobalMouseUp(button)
	if self:IsMouseOverScrollbarControl() then
		return true
	end

	if button == MOUSE_BUTTON_INDEX_LEFT then
		local moc = moc()
		if moc.typeId then
			return moc.typeId ~= ENTRY_ID
		end
	end

	return button == MOUSE_BUTTON_INDEX_RIGHT
end

-- Create the m_dropdownObject on initialize.
function comboBoxClass:GetDropdownObject(comboBoxContainer, depth)
	self.m_nextFree = depth + 1
	return dropdownClass:New(self, comboBoxContainer, depth)
end

function comboBoxClass:GetOptions()
	return self.options
end

function comboBoxClass:GetMaxRows()
	return self.visibleRows or DEFAULT_VISIBLE_ROWS
end

-- Get or create submenu
function comboBoxClass:GetSubmenu()
	if not self.m_submenu then
		self.m_submenu = submenuClass:New(self, self.m_container, self.options, self.m_nextFree)
	end
	
	return self.m_submenu
end

function comboBoxClass:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	local narrateData = self.narrateData
--d( "[LSM]Narrate-"..tos(eventName) .. ", narrateData: " ..tos(narrateData))
	if eventName == nil or isAccessibilityUIReaderEnabled() == false or narrateData == nil then return end
	local narrateCallbackFuncForEvent = narrateData[eventName]
	if narrateCallbackFuncForEvent == nil or type(narrateCallbackFuncForEvent) ~= "function" then return end

	local eventCallbackFunctionsSignatures = {
		["OnMenuShow"]			= function() return self, ctrl end,
		["OnMenuHide"]			= function() return self, ctrl end,
		["OnSubMenuShow"]		= function() return self, ctrl, anchorPoint end,
		["OnSubMenuHide"]		= function() return self, ctrl end,
		["OnEntrySelected"]		= function() return self, ctrl, data, hasSubmenu end,
		["OnEntryMouseExit"]	= function() return self, ctrl, data, hasSubmenu end,
		["OnEntryMouseEnter"]	= function() return self, ctrl, data, hasSubmenu end,
		["OnCheckboxUpdated"]	= function() return self, ctrl, data end,
		["OnDropdownMouseExit"]	= function() return self, ctrl end,
		["OnDropdownMouseEnter"] = function() return self, ctrl end,
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

-- used for onMouseEnter[submenu] and onMouseUp[contextMenu]
function comboBoxClass:ShowDropdownOnMouseAction(parentControl)
	if self:IsDropdownVisible() then
		-- If submenu was currently opened, close it so it can reset.
		self:HideDropdown()
	end
	
	self:ShowDropdown()
	self.m_dropdownObject:SetHidden(false)
	self:AddMenuItems(parentControl)

	self:SetVisible(true)
end

function comboBoxClass:ShowSubmenu(parentControl)
	-- We don't want a submenu to open under the context menu or it's submenus.
	if g_contextMenu:IsDropdownVisible() then
		g_contextMenu:HideDropdown()
	end

	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

function comboBoxClass:UpdateOptions(options)
	d( '- - - UpdateOptions')
	
	d( '- - - self.optionsChanged')
	if not self.optionsChanged then return end
	self.optionsChanged = false

	options = options or {}
	
	-- Backwards compatible
	if type(options) ~= 'table' then
		options = {
			visibleRows = options,
			visibleRowsDropdown = options
		}
	end

--	local defaultOptions = self.options or defaultComboBoxOptions
	-- We add all previous options to the new table
--	mixinTableAndSkipExisting(options, defaultOptions)
	-- We will need to start with a clean table in order to reset options.
	mixinTableAndSkipExisting(options, defaultComboBoxOptions)
	
	local narrateData = getValueOrCallback(options.narrate, options)

	-- Defaults are predefined in defaultComboBoxOptions
	local font = getValueOrCallback(options.font, options)
	local spacing = getValueOrCallback(options.spacing, options)
	local sortEntries = getValueOrCallback(options.sortEntries, options)
	local visibleRows = getValueOrCallback(options.visibleRowsDropdown, options)
	local preshowDropdownFn = getValueOrCallback(options.preshowDropdownFn, options)
	local visibleRowsSubmenu = getValueOrCallback(options.visibleRowsSubmenu, options)
	-- Defaults used if nil
	local sortType = getValueOrCallback(options.sortType, options)
	local sortOrder = getValueOrCallback(options.sortOrder, options)

	if preshowDropdownFn then
		self:SetPreshowDropdownCallback(preshowDropdownFn)
	end
	
	self.visibleRows = visibleRows
	self.visibleRowsSubmenu = visibleRowsSubmenu
	
	self:SetSortsItems(sortEntries)
	self:SetFont(font)
	self:SetSpacing(spacing)
	self:SetSortOrder(sortOrder, sortType)
		
	self.options = options
	self.narrateData = narrateData
	
	-- this will add custom and default templates to self.XMLrowTemplates the same way dataTypes were created before.
	self:AddCustomEntryTemplates(options)
end

-- >> template, height, setupFunction
local function getTemplateData(entryType, template)
	local templateDataForEntryType = template[entryType]
	return templateDataForEntryType.template, templateDataForEntryType.rowHeight, templateDataForEntryType.setupFunc, templateDataForEntryType.widthAdjust
end

function comboBoxClass:AddCustomEntryTemplates(options)
	-- checkbox wrappers
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
		updateIcons(control, data)
	end
	
	local function addArrow(control, data, list)
		control.m_arrow = control:GetNamedChild("Arrow")
		data.hasSubmenu = true
	end
	
	local function addDivider(control, data, list)
		control.m_divider = control:GetNamedChild("Divider")
	end

	-- addLabel initializes the entry, both as label and, as a comboBox.m_dropdownObject entry
	-- All entries besides divider uses this. DIVIDER_ENTRY_ID initializes it's self with SetupEntryBase
	local function addLabel(control, data, list)
		-- Remember, labelStr is being handled in processNameString, replacing it with .name
		-- data.name == data.label() or data.label or data.name() or data.name
		self:SetupEntry(control, data, list)

		local font = getValueOrCallback(data.font, data)
		if font then
			self.m_label:SetFont(font)
		end
		local color = getValueOrCallback(data.color, data)
		if color then
			self.m_label:SetColor(color)
		end
	end

	-- all the template stuff wrapped up in here
	local defaultXMLTemplates  = {
		[ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				control.typeId = ENTRY_ID
				
				addIcon(control, data, list)
				addLabel(control, data, list)
			end,
		},
		[SUBMENU_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxSubmenuEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthAdjust = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				control.typeId = SUBMENU_ENTRY_ID
				
				addIcon(control, data, list)
				addLabel(control, data, list)
				addArrow(control, data, list)
			end,
		},
		[DIVIDER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxDividerEntry',
			rowHeight = DIVIDER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntryBase(control, data, list)
				control.typeId = DIVIDER_ENTRY_ID
				
				addDivider(control, data, list)
			end,
		},
		[HEADER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxHeaderEntry',
			rowHeight = HEADER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				control.typeId = HEADER_ENTRY_ID
				
				control.isHeader = true
				addDivider(control, data, list)
				addIcon(control, data, list)
				addLabel(control, data, list)
				
				-- Since the font is being change in addLabel due to SetupEntry...
				control.m_label:SetFont('ZoFontWinH5')
				control.m_label:SetColor(HEADER_TEXT_COLOR:UnpackRGBA())
			end,
		},
		[CHECKBOX_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxCheckboxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				control.typeId = CHECKBOX_ENTRY_ID
				
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

function comboBoxClass:HideOnMouseEnter()
	d( 'comboBoxClass:HideOnMouseEnter')
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() and not self:IsMouseOverControl() then
		self.m_submenu:HideDropdown()
	end
end

function comboBoxClass:HideOnMouseExit(moc)
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() then
		self.m_submenu:HideDropdown()
		return true
	end
end

-- These are part of the m_dropdownObject but, since we now use them from the comboBox, 
-- they are added here to reference the ones in the m_dropdownObject.
function comboBoxClass:IsMouseOverControl()
	return self.m_dropdownObject:IsMouseOverControl()
end

function comboBoxClass:SetupEntryBase(control, data, list)
	-- Used to initialize a basic divider and bypass SetupEntry
	self.m_dropdownObject:SetupEntryBase(control, data, list)
end

function comboBoxClass:SetupEntry(control, data, list)
	-- Used to initialize all entries with labels
	self.m_dropdownObject:SetupEntry(control, data, list)
end

--------------------------------------------------------------------
-- submenuClass
--------------------------------------------------------------------
-- submenuClass:New(To simplify locating the beginning of the class
function submenuClass:Initialize(parent, comboBoxContainer, options, depth)
--	d( '[LSM]submenuClass:Initialize')
	self.m_parentMenu = parent
	comboBoxClass.Initialize(self, parent, comboBoxContainer, options, depth)
	self.owner = comboBoxContainer.m_comboBox
end

function submenuClass:AddMenuItems(parentControl)
	self.openingControl = parentControl
	self:RefreshSortedItems(parentControl)
	
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing(), self:GetMaxRows())

	self.m_dropdownObject:AnchorToControl(parentControl)
end

function submenuClass:GetMaxRows()
	return self.visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS
end

function submenuClass:RefreshSortedItems(parentControl)
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)
	local data = getControlData(parentControl)

	for k, item in ipairs(data.entries) do
		item.m_parentControl = parentControl
		self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
	end
	
	self:UpdateItems()
end

function submenuClass:OnGlobalMouseUp(eventCode, ...)
	if  self:IsDropdownVisible() and not self:BypassOnGlobalMouseUp(...) then
		self:HideDropdown()
	end
end

function submenuClass:ShowDropdownInternal()
	-- Outsourcing these so the control used to register OnGlobalMouseUp is not the same control for all.
	self.m_dropdownObject:ShowDropdownInternal()
end

function submenuClass:HideDropdownInternal()
	self.m_dropdownObject:HideDropdownInternal()
	if self.m_dropdownObject:IsOwnedByComboBox(self) then
		self.m_dropdownObject:SetHidden(true)
	end
	self:SetVisible(false)
	if self.onHideDropdownCallback then
		self.onHideDropdownCallback()
	end
--	PlaySound(SOUNDS.ANTIQUITIES_FANFARE_COMPLETED)
end

function submenuClass:SelectItemByIndex(index, ignoreCallback)
	self.owner:HideDropdown()
	return zo_comboBox_selectItem(self.owner, self.m_sortedItems[index], ignoreCallback)
end

function submenuClass:HideOnMouseExit(moc)
	-- Only begin hiding if we stopped over a dropdown.
	if moc.m_dropdownObject then
		if comboBoxClass.HideOnMouseExit(self) then
			-- Close all open submenus beyond this point
			
			-- This will only close the dropdown if the mouse is not over the dropdown or over the control that opened it.
			if not (self:IsMouseOverControl() or self:IsMouseOverOpeningControl()) then
				self:HideDropdown()
			end
		end
	end
end

function submenuClass:IsMouseOverOpeningControl()
	return MouseIsOver(self.openingControl)
end

--------------------------------------------------------------------
-- 
--------------------------------------------------------------------
local contextMenuClass = submenuClass:Subclass()
local contextMenuClass = comboBoxClass:Subclass()
-- LibScrollableMenu.contextMenu
-- contextMenuClass:New(To simplify locating the beginning of the class
function contextMenuClass:Initialize(comboBoxContainer)
	comboBoxClass.Initialize(self, nil, comboBoxContainer, nil, 1)
	self.data = {}
	self.m_sortedItems = {}
	
	self:ClearItems()
end

function contextMenuClass:AddItem(itemEntry, updateOptions)
	if not itemEntry.customEntryTemplate then
		local hasSubmenu = setItemEntryCustomTemplate(itemEntry, self.XMLrowTemplates)
		
		if hasSubmenu then
			itemEntry.hasSubmenu = true
			itemEntry.isNew = areAnyEntriesNew(itemEntry)
		end
	end

	tins(self.data, itemEntry)
	
	if updateOptions ~= ZO_COMBOBOX_SUPPRESS_UPDATE then
		self:UpdateItems()
	end

	self:OnItemAdded()
end

function contextMenuClass:AddMenuItems()
	self:RefreshSortedItems()
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing(), self:GetMaxRows())
	self.m_dropdownObject:AnchorToMouse()
	self.m_dropdownObject.control:BringWindowToTop()
end

function contextMenuClass:ClearItems()
	self:SetOptions(nil)
	
	ZO_ComboBox_HideDropdown(self:GetContainer())
	ZO_ClearNumericallyIndexedTable(self.data)
	
	self:SetSelectedItemText("")
	self.m_selectedItemData = nil
	self:OnClearItems()
end

function contextMenuClass:ShowSubmenu(parentControl)
	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

function contextMenuClass:ShowContextMenu(parentControl)
	self.openingControl = parentControl

	self:UpdateOptions(self.optionsData)

	-- Let the caller know that this is about to be shown...
	if self.m_preshowDropdownFn then
		self.m_preshowDropdownFn(self)
	end
	
	self:ShowDropdown()
	self:ShowDropdownOnMouseUp(parentControl)
end

function contextMenuClass:HideDropdownInternal()
	submenuClass.HideDropdownInternal(self)

	self:ClearItems()
end

function contextMenuClass:RefreshSortedItems()
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)

	for k, v in ipairs(self.data) do
		tins(self.m_sortedItems, v)
	end
	self:UpdateItems()
end

function contextMenuClass:SetOptions(options)
	-- self.optionsData is only a temporary table used check for change and to send to UpdateOptions.
	self.optionsChanged = self.optionsData ~= options
	self.optionsData = options
end

function contextMenuClass:SetPreshowDropdownCallback()
	-- Intentionally blank. This is to prevent abusing the function in the context menu.
end

--------------------------------------------------------------------
-- 
--------------------------------------------------------------------
-- We need to integrate a supplied ZO_ComboBox with the lib's functionality.
-- We do this by replacing the m_comboBox with our custom comboBoxClass.

local function applyUpgrade(parent, comboBoxContainer, options)
	local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)

	assert(comboBox and comboBox.IsInstanceOf and comboBox:IsInstanceOf(ZO_ComboBox), MAJOR .. ' | The comboBoxContainer you supplied must be a valid ZO_ComboBox container. "comboBoxContainer.m_comboBox:IsInstanceOf(ZO_ComboBox)"')
	
	zo_mixin(comboBox, comboBoxClass)
	comboBox.__index = comboBox
	comboBox:Initialize(parent, comboBoxContainer, options, 1)
	
	return comboBox
end

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
	assert(parent ~= nil and comboBoxContainer ~= nil, MAJOR .. " - AddCustomScrollableComboBoxDropdownMenu ERROR: Parameters parent and comboBoxContainer must be provided!")

	local comboBox = applyUpgrade(parent, comboBoxContainer, options)
	return comboBox.m_dropdownObject
end
																					   

--[Custom scrollable context menu at any control]
--Add a scrollable menu to any control (not only a ZO_ComboBox), e.g. to an inventory row
--by creating a DUMMY ZO_ComboBox, adding the ScrollHelper class to it and use it
----------------------------------------------------------------------

--Adds a new entry to the context menu entries with the shown text, which calls the callback function once clicked.
--If entries is provided the entry will be a submenu having those entries. The callback can only be used if entries are passed in
--but normally it should be nil in that case
function AddCustomScrollableMenuEntry(text, callback, entryType, entries, isNew)
	assert(text ~= nil, sfor('['..MAJOR..':AddCustomScrollableMenuEntry] String or function returning a string expected, got %q = %s', "text", tos(text)))
--	local scrollHelper = initCustomScrollMenuControl()
--	scrollHelper = scrollHelper or getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	local options = g_contextMenu:GetOptions()

	--If no entryType was passed in: Use normal text line type
	entryType = entryType or lib.LSM_ENTRY_TYPE_NORMAL
	if not allowedEntryTypesForContextMenu[entryType] then
		entryType = lib.LSM_ENTRY_TYPE_NORMAL
	end
	if entryType ~= lib.LSM_ENTRY_TYPE_HEADER and entryType ~= lib.LSM_ENTRY_TYPE_DIVIDER and entries == nil then
		assert(type(callback) == "function", sfor('['..MAJOR..':AddCustomScrollableMenuEntry] Callback function expected, got %q = %s', "callback", tos(callback)))
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
	if ZO_IsTableEmpty(contextMenuEntries) then return end
	for _, v in ipairs(contextMenuEntries) do
		addCustomScrollableMenuEntry(v.label or v.text, v.callback, v.entryType, v.entries, v.isNew)
	end
--	g_contextMenu:AddItems(contextMenuEntries)
	return true
end
local addCustomScrollableMenuEntries = AddCustomScrollableMenuEntries

--Set the options (visible rows max, etc.) for the scrollable context menu
function SetCustomScrollableMenuOptions(options)
	local optionsTableType = type(options)
	assert(optionsTableType == 'table' , sfor('['..MAJOR..':SetCustomScrollableMenuOptions] table expected, got %q = %s', "options", tos(optionsTableType)))

	if options then
		g_contextMenu:SetOptions(options)
	end
end
local setCustomScrollableMenuOptions = SetCustomScrollableMenuOptions

--Populate the scrollable context menu with the defined entries table.
--You can add more entries later, prior to showing, via AddCustomScrollableMenuEntry function too
function AddCustomScrollableMenu(parent, entries, options)
	if type(parent) == 'table' then
		-- Allow use as AddCustomScrollableMenu(entries, options)
		options = entries
		entries = parent
	end
	local entryTableType = type(entries)
	assert(entryTableType == 'table' , sfor('['..MAJOR..':AddCustomScrollableMenu] table expected, got %q = %s', "entries", tos(entryTableType)))

	if options then
		setCustomScrollableMenuOptions(options)
	end
	
	addCustomScrollableMenuEntries(entries)
--	g_contextMenu:AddItems(entries)
	return true
end

--Show the custom scrollable context menu now
function ShowCustomScrollableMenu(controlToAnchorTo, point, relativePoint, offsetX, offsetY, options)
	--d("[LSM]ShowCustomScrollableMenu")
	if options then
		setCustomScrollableMenuOptions(options)
	end

	controlToAnchorTo = controlToAnchorTo or moc()
	g_contextMenu:ShowContextMenu(controlToAnchorTo)
	return true
end

--Hide the custom scrollable context menu and clear internal variables, mouse clicks etc.
function ClearCustomScrollableMenu()
	--d("[LSM]ClearCustomScrollableMenu")
	g_contextMenu:ClearItems()
	
	setCustomScrollableMenuOptions(defaultComboBoxOptions)
	return true
end

--Custom tooltip function
--[[
Function to show or hide a custom tooltip control. Pass that in to the data table of any entry, via data.customTooltip!

Your function needs to create and show/hide that control, and populate the text etc to the control too!
Parameters:
-data The table with the current data of the rowControl
-rowControl The userdata of the control the tooltip should show about
-point, offsetX, offsetY, relativePoint: Suggested anchoring points

myAddon.customTooltipFunc(table data, userdata rowControl, Int point, Int offsetX, Int offsetY, Int relativePoint)
e.g. data = { name="Test 1", label="Test", customTooltip=function(data, rowControl, point, offsetX, offsetY, relativePoint) ... end, ... }

customTooltipFunc = function(data, rowControl, point, offsetX, offsetY, relativePoint)
	if data == nil then
		self.myTooltipControl:SetHidden(true)
	else
		self.myTooltipControl:ClearAnchors()
		self.myTooltipControl:SetAnchor(point, rowControl, relativePoint, offsetX, offsetY)
		self.myTooltipControl:SetText(data.tooltip)
		self.myTooltipControl:SetHidden(false)
	end
end
]]

------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------

local function onAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)

	local comboBoxContainer = CreateControlFromVirtual(MAJOR .. "_ContextMenu", GuiRoot, 'ZO_ComboBox')
	g_contextMenu = contextMenuClass:New(comboBoxContainer)
	lib.contextMenu = g_contextMenu
end
EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
EM:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, onAddonLoaded)


------------------------------------------------------------------------------------------------------------------------
-- Global library reference
------------------------------------------------------------------------------------------------------------------------
LibScrollableMenu = lib

------------------------------------------------------------------------------------------------------------------------
-- Notes: | TODO:
------------------------------------------------------------------------------------------------------------------------

--[[TODO:
	find out why submenu width shrinks slightly when moving back onto it from it's childMenu
		Does this still happen?

setTimeout no longer needs ... param

Change the description of the context menu. 
	
remove? point, relativePoint, offsetX, offsetY 
function ShowCustomScrollableMenu(controlToAnchorTo, point, relativePoint, offsetX, offsetY, options)

remove? parent
function AddCustomScrollableMenu(parent, entries, options)

remove? parent
AddCustomScrollableComboBoxDropdownMenu(parent, comboBoxContainer, options)

LUA Size reduction act:
AddCustomScrollableMenuEntries and AddCustomScrollableMenu are basically the same thing. Just one has options.
We could remove one and and just make one with (entries, options)

We decided to commit to only using these functions from the comboBox. Remove?
dropdownClass:AddItems, dropdownClass:AddItem

Improve setTimeout
]]

--[[Changes - delete me
	added option to change individual list label font and color by data.font and data.color
	
	Renamed some functions to better reflect what they do. Such as, IsMouseOverParent to IsMouseOverOpeningControl
	
	Opening a submenu will instantly close any previously opened submenu, of same level, and all it's children. This includes the context menu.
	If the context menu is opened and, mouse travels over a submenu of the parent, the context menu will close before the submenu opens.
	
	Included all default options for comboBoxs in defaultComboBoxOptions
	Adjusted how options are handled. Defaults are applied every time. If tables match then stop updating. Test this for efficiency.
	
	Added several TODO:s to keep note on.
	
	Implemeted max rows
]]
