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

local g_addItem = ZO_ComboBox_Base.AddItem
local g_selectItem = ZO_ComboBox.SelectItem
local g_hideDropdown = ZO_ComboBox_Base.HideDropdown
local g_onGlobalMouseUp = ZO_ComboBox.OnGlobalMouseUp
local g_setDropdownObject = ZO_ComboBox.SetDropdownObject
local g_setItemEntryCustomTemplate = ZO_ComboBox.SetItemEntryCustomTemplate

local g_onEntrySelected = ZO_ComboBoxDropdown_Keyboard.OnEntrySelected
local g_onMouseExitEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry
local g_onMouseEnterEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry

local g_contextMenu

--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--local speed up variables
local EM = EVENT_MANAGER
local SNM = SCREEN_NARRATION_MANAGER

local tos = tostring
local sfor = string.format
--TODO: make use of 
local tins = table.insert

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

--Entry types - For the scroll list's dataType of te menus
local DEFAULT_ENTRY_ID = 1
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

--TODO: remove or make use of --v
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

--The default values for the context menu options are:
local defaultContextMenuOptions  = {
	["visibleRowsDropdown"] = 20,
	["visibleRowsSubmenu"] = 20,
	["sortEntries"] = false,
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

local function clearTimeout()
	if submenuCallLaterHandle ~= nil then
		EM:UnregisterForUpdate(submenuCallLaterHandle)
		submenuCallLaterHandle = nil
	end
end

local  nextId = 1
local function setTimeout(callback , ...)
	local params = {...}
	if submenuCallLaterHandle ~= nil then clearTimeout() end
	submenuCallLaterHandle = MAJOR.."Timeout" .. nextId
	nextId = nextId + 1

	--Delay the submenu close callback so we can move the mouse above a new submenu control and keep that opened e.g.
	--TODO: This isn't really used for that anymore. It's purpose is to provide a delay 
	-- if the mouse has moved outside of the dropdown controls. To give time to move back in.
	EM:RegisterForUpdate(submenuCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		clearTimeout()
		if callback then callback(unpack(params)) end
	end )
end


-- TODO: Decide on what to pass, in LibCustomMenus
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

-- TODO: consider renaming?
--local function new_mixin(object, ...)
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

local function defaultRecursiveCallback(_entry)
	return false
end

local function getIsNew(_entry)
	return getValueOrCallback(_entry.isNew, _entry) or false
end

-- Recursive over entries.
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

-- Recursively check for new entries.
local function areAnyEntriesNew(entry)
	return recursiveOverEntries(entry, getIsNew)
end

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

local function doMapEntries(entryTable, mapTable)
	for k, entry in pairs(entryTable) do
		if entry.entries then
			doMapEntries(entry.entries, mapTable)
		end
		
		-- TODO: only map entries with callbacks?
		if entry.callback then
		--	tins(mapTable, entry)
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
lib.MapEntries = mapEntries

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
-- m_dropdownObject.parentControl
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

-- entry.dataSource.entries
-- data.entries

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
		g_setItemEntryCustomTemplate(item, customEntryTemplate)
	end

	return hasSubmenu
end

local function hideTooltip()
	if lib.lastCustomTooltipControl then
		lib.lastCustomTooltipControl()
	else
		ClearTooltip(InformationTooltip)
	end
end

local function showTooltip(control, data, hasSubmenu)
	local tooltipData = getValueOrCallback(data.tooltip, data)
	local tooltipText = getValueOrCallback(tooltipData, data)
	
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
	
	lib.lastCustomTooltipControl = nil
	
	local customTooltipFunc = data.customTooltip
	if type(customTooltipFunc) == "function" then
		local SHOW = true
		--TODO: Pass in "point, offsetX, offsetY, relativePoint" for anchoring?
	--	lib.lastCustomTooltipControl = customTooltipFunc(data, control, SHOW)
		lib.lastCustomTooltipControl = customTooltipFunc(data, control, point, offsetX, offsetY, relativePoint)
	else
		InitializeTooltip(InformationTooltip, control, point, offsetX, offsetY, relativePoint)
		SetTooltipText(InformationTooltip, tooltipText)
		InformationTooltipTopLevel:BringWindowToTop()
	end
end

local function processNameString(data)
	local name = getValueOrCallback(data.name, data)

	--Passed in an alternative text/function returning a text to show at the label control of the menu entry?
	if data.label ~= nil then
		name = getValueOrCallback(data.label, data)
	end
	
	if data.name ~= name then
		data.name = name
	end
	return name
end

local function getContainerFromControl(control)
	local owner = control.m_owner
	return owner and owner.m_container
end

local function getContainerFromControl(control)
	if control.m_container then
		return control.m_container
	elseif control.m_dropdownObject then
		return getContainerFromControl(control.m_dropdownObject)
	end
end

local function getComboBoxFromControl(control)
	if control.m_comboBox then
		return control.m_comboBox
	end
	
	local container = getContainerFromControl(control)
	if container then
		return getComboBoxFromControl(container)
	end
end

local function getSubmenuFromContainer(control)
	if control.m_submenu then
		return control.m_submenu
	end
	local comboBox = getComboBoxFromControl(control)
	if comboBox then
		return getSubmenuFromContainer(comboBox)
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

LSM_DEBUG = {
	init = {},
	submenu = {},
	owners = {},
}

--------------------------------------------------------------------
-- Row handlers
--------------------------------------------------------------------

local function onMouseEnter(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
--	g_onMouseEnterEntry(dropdown, control)
	
	dropdown:Narrate("OnEntryMouseEnter", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseEnter', data, control)
	
	return dropdown
end

local function onMouseExit(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
--	g_onMouseExitEntry(dropdown, control)
	
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
--[[
local handlerFunctions  = {
	[ENTRY_ID] = {
		onMouseEnter = function(control, ...)
			local data = getControlData(control)
			local dropdown = onMouseEnter(control, data, no_submenu)
			clearNewStatus(control, data)
		end,
		onMouseExit = function(control, ...)
			local data = getControlData(control)
			local dropdown = onMouseExit(control, data, no_submenu)
		end,
		onMouseUp = function(control, button, upInside)
			local data = getControlData(control)
			local dropdown = onMouseUp(control, data, no_submenu, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					dropdown:SelectItemByIndex(control.m_data.m_index)
				else -- right-click
				end
			else
				--TODO: Do we want to close dropdowns on mouse up not upInside?
			end
		end,
	},
	[SUBMENU_ENTRY_ID] = {
		onMouseEnter = function(control)
			local data = getControlData(control)
			local dropdown = onMouseEnter(control, data, has_submenu)
			dropdown:ShowSubmenu(control)
		end,
		onMouseExit = function(control)
			local data = getControlData(control)
			local dropdown = onMouseExit(control, data, has_submenu)

			if not (MouseIsOver(control) or dropdown:IsEnteringSubmenu()) then
				-- Keep open
				clearTimeout()
				dropdown:HideSubmenu()
			end
		end,
		onMouseUp = function(control, button, upInside)
			local data = getControlData(control)
			local dropdown = onMouseUp(control, data, has_submenu, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					if data.callback then
						data.callback(control, data)
					end
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
		-- Intentionally empty.
	},
	[CHECKBOX_ENTRY_ID] = {
		onMouseEnter = function(control, ...)
			local data = getControlData(control)
			local dropdown = onMouseEnter(control, data, no_submenu)
		end,
		onMouseExit = function(control, ...)
			local data = getControlData(control)
			local dropdown = onMouseExit(control, data, no_submenu)
		end,
		onMouseUp = function(control, button, upInside)
			local dropdown = control.m_dropdownObject
			if upInside then
				local data = getControlData(control)
				
				if button == MOUSE_BUTTON_INDEX_LEFT then
					-- left click on row toggles the checkbox.
					playSelectedSoundCheck(dropdown)
					ZO_CheckButton_OnClicked(control.m_checkbox)
					data.checked = ZO_CheckButton_IsChecked(control.m_checkbox)
				else -- right-click
				end
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
]]

local handlerFunctions  = {
	['onMouseEnter'] = {
		[ENTRY_ID] = function(control, ...)
			local data = getControlData(control)
			local dropdown = onMouseEnter(control, data, no_submenu)
			clearNewStatus(control, data)
			return false
		end,
		[HEADER_ENTRY_ID] = function(control, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control)
			local data = getControlData(control)
			local dropdown = onMouseEnter(control, data, has_submenu)
			dropdown:ShowSubmenu(control)
			return false
		end,
		[CHECKBOX_ENTRY_ID] = function(control, ...)
			local data = getControlData(control)
			local dropdown = onMouseEnter(control, data, no_submenu)
			return false
		end,
	},
	['onMouseExit'] = {
		[ENTRY_ID] = function(control, ...)
			local data = getControlData(control)
			local dropdown = onMouseExit(control, data, no_submenu)
			return false
		end,
		[HEADER_ENTRY_ID] = function(control, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control)
			local data = getControlData(control)
			local dropdown = onMouseExit(control, data, has_submenu)

			if not (MouseIsOver(control) or dropdown:IsEnteringSubmenu()) then
				-- Keep open
				clearTimeout()
				dropdown:HideSubmenu()
			end
			return false
		end,
		[CHECKBOX_ENTRY_ID] = function(control, ...)
			local data = getControlData(control)
			local dropdown = onMouseExit(control, data, no_submenu)
			return false
		end,
	},
	['onMouseUp'] = {
		[ENTRY_ID] = function(control, button, upInside)
			d( 'onMouseUp [ENTRY_ID]')
			local data = getControlData(control)
			local dropdown = onMouseUp(control, data, no_submenu, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					dropdown:SelectItemByIndex(control.m_data.m_index)
				else -- right-click
				end
			else
				--TODO: Do we want to close dropdowns on mouse up not upInside?
			end
			return true
		end,
		[HEADER_ENTRY_ID] = function(control, button, upInside)
			if upInside then
				local data = getControlData(control)
				if button == MOUSE_BUTTON_INDEX_RIGHT then
					if data.contextMenuCallback then
						data.contextMenuCallback(control)
					end
				end
			end
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, button, upInside)
			local data = getControlData(control)
			local dropdown = onMouseUp(control, data, has_submenu, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					if data.callback then
						dropdown:SelectItemByIndex(control.m_data.m_index)
					end
				else -- right-click
				end
			else
				--TODO: Do we want to close dropdowns on mouse up not upInside?
			end
			return true
		end,
		[CHECKBOX_ENTRY_ID] = function(control, button, upInside)
			d( 'onMouseUp [CHECKBOX_ENTRY_ID]')
			local dropdown = control.m_dropdownObject
			if upInside then
				local data = getControlData(control)
				
				if button == MOUSE_BUTTON_INDEX_LEFT then
					-- left click on row toggles the checkbox.
					playSelectedSoundCheck(dropdown)
					ZO_CheckButton_OnClicked(control.m_checkbox)
					data.checked = ZO_CheckButton_IsChecked(control.m_checkbox)
				else -- right-click
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

	self:SetHidden(true)
	
	self.m_parentMenu = parent.m_parentMenu
	self.m_sortedItems = {}
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
	
	self.control:ClearAnchors()
	
	local offsetX = 0
	
	local right = true
	
	if self.m_parentMenu.m_dropdownObject and self.m_parentMenu.m_dropdownObject.anchorRight ~= nil then
		right = self.m_parentMenu.m_dropdownObject.anchorRight
	end
	
	if not right or parentControl:GetRight() + self.control:GetWidth() > width then
		right = false
	end
	
	if right then
		self.control:SetAnchor(TOPLEFT, parentControl, TOPRIGHT, offsetX, 0)
	else
		self.control:SetAnchor(TOPRIGHT, parentControl, TOPLEFT, offsetX, 0)
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

function dropdownClass:GetSubmenu()
	if self.owner then
		self.m_submenu = self.owner.m_submenu
	end

	return self.m_submenu
end

function dropdownClass:OnMouseEnterEntry(control)
--	d( '[LSM]dropdownClass:OnMouseEnterEntry')
	self.control:BringWindowToTop()
	
	clearTimeout()
	
	if not runHandler(handlerFunctions['onMouseEnter'], control) then
		g_onMouseEnterEntry(self, control)
	end
	
	local data = getControlData(control)
	if data.tooltip or data.customTooltip then
		self:ShowTooltip(control, data)
	end
end

local function onMouseExitHelper(comboBox)
	if comboBox:IsDropdownVisible() then
		local childMenu = comboBox.m_submenu
		if not (comboBox:IsMouseOverControl() or childMenu and childMenu:IsDropdownVisible()) then
			comboBox:HideDropdown()
		end
	end
	
	if comboBox ~= g_contextMenu then
		onMouseExitHelper(g_contextMenu)
	end
end
	
function dropdownClass:OnMouseExitEntry(control)
--	d( '[LSM]dropdownClass:OnMouseExitEntry')
--	d( control:GetName())

	hideTooltip()
	onMouseExitHelper(self.owner)
	
	if not runHandler(handlerFunctions['onMouseExit'], control) then
		g_onMouseExitEntry(self, control)
	end
	
	if not lib.GetPersistentMenus() then
		self:OnMouseExitTimeout(control)
	end
end

function dropdownClass:OnMouseExitTimeout(control)
--	clearTimeout()
	
	setTimeout(function()
		local moc = moc()
		
		if moc == GuiRoot then
			-- Need to close all submenus
		--	local submenu = getSubmenuFromContainer(self)
			local comboBox = self.m_container.m_comboBox
			
			if comboBox and comboBox.m_submenu then
				comboBox.m_submenu:HideDropdown()
			end
		end
		
		local submenu = self:GetSubmenu()
		if not submenu or not submenu:IsMouseOverControl() then
			-- This will only close the dropdown if the mouse is not over the dropdown or over the control that opened it.
			if not (self:IsMouseOverControl() or self:IsMouseOverParent()) then
				self.owner:HideDropdown()
			else
				--TODO: reopen?
			end
		end
	end)
end

function dropdownClass:OnEntrySelected(control, button, upInside)
--	d( '[LSM]dropdownClass:OnEntrySelected IsUpInside ' .. tos(upInside) .. ' Button ' .. tos(button))
	
	if not runHandler(handlerFunctions['onMouseUp'], control, button, upInside) then
		g_onEntrySelected(self, control)
	end
	
	if upInside then
		if button == MOUSE_BUTTON_INDEX_RIGHT then
			local data = getControlData(control)
			if data.contextMenuCallback then
				data.contextMenuCallback(control)
			end
		end
	end
end

function dropdownClass:SelectItemByIndex(index, ignoreCallback)
	if self.owner then
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

function dropdownClass:Show(comboBox, itemTable, minWidth, maxHeight, spacing)
	self.owner = comboBox
	
	ZO_ScrollList_Clear(self.scrollControl)

	self:SetSpacing(spacing)

	local numItems = #itemTable
	local dataList = ZO_ScrollList_GetDataList(self.scrollControl)

	local largestEntryWidth = 0
	local allItemsHeight = 0

	for i = 1, numItems do
		local item = itemTable[i]
		processNameString(item)

		local isLastEntry = i == numItems
		local entryHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT
		local entryType = DEFAULT_ENTRY_ID
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

		local entry = createScrollableComboBoxEntry(self, item, i, entryType)
		table.insert(dataList, entry)

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

function dropdownClass:IsDropdownVisible()
	-- inherited ZO_ComboBoxDropdown_Keyboard:IsHidden
	return not self:IsHidden()
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

function dropdownClass:IsMouseOverParent()
	return false
end

function dropdownClass:HideDropdown()
	local submenu = self:GetSubmenu()
	if submenu and submenu:IsDropdownVisible() then
		submenu:HideDropdown()
	end
	
	if self:IsDropdownVisible() then
	--	PlaySound(SOUNDS.ANTIQUITIES_FANFARE_COMPLETED)
	end
	
	self.owner:HideDropdown()
end

function dropdownClass:HideSubmenu()
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end
end

function dropdownClass:ShowDropdownInternal()
	self.control:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self.owner:OnGlobalMouseUp(...) end)
end

function dropdownClass:HideDropdownInternal()
	self.control:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)
end

--------------------------------------------------------------------
-- ComboBox classes
--------------------------------------------------------------------
local DEFAULT_HEIGHT = 250
local DEFAULT_FONT = "ZoFontGame"
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

local buttonToString = { -- TODO: for debug
	[MOUSE_BUTTON_INDEX_RIGHT] = 'MOUSE_BUTTON_INDEX_RIGHT',
	[MOUSE_BUTTON_INDEX_LEFT] = 'MOUSE_BUTTON_INDEX_LEFT',
}

--------------------------------------------------------------------
-- comboBoxClass
--------------------------------------------------------------------
local comboBoxClass = ZO_ComboBox:Subclass()
local submenuClass = comboBoxClass:Subclass()

-- submenuClass:New(To simplify locating the beginning of the class
function comboBoxClass:Initialize(parent, comboBoxContainer, options, depth)
	-- Add all comboBox defaults not present.
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
	
	self.optionsChanged = true
	self:UpdateOptions(options)
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

function comboBoxClass:GetDropdownObject(comboBoxContainer, depth)
--	d( '[LSM]comboBoxClass:GetDropdownObject')
	self.m_nextFree = depth + 1
	return dropdownClass:New(self, comboBoxContainer, depth)
end

function comboBoxClass:GetOptions()
	return self.options
end

function comboBoxClass:UpdateOptions(options)
--	d( '[LSM]comboBoxClass:UpdateOptions')
--	d( sfor('[LSM]UpdateOptions optionsChanged %s', tos(self.optionsChanged)))

	if not self.optionsChanged then return end
	self.optionsChanged = false

	options = options or {}

--	local control = self.m_container

	-- Backwards compatible
	if type(options) ~= 'table' then
		options = {
			visibleRowsDropdown = options
		}
	end

	local defaultOptions = self.options or defaultContextMenuOptions
	-- We add all previous options to the new table
	mixinTableAndSkipExisting(options, defaultOptions)

	local sortsItems = getValueOrCallback(options.sortEntries, options)
	local narrateData = getValueOrCallback(options.narrate, options)
	local visibleRows = getValueOrCallback(options.visibleRowsDropdown, options)
	local preshowDropdownFn = getValueOrCallback(options.preshowDropdownFn, options)
	local visibleRowsSubmenu = getValueOrCallback(options.visibleRowsSubmenu, options)

--	control.options = options
	self.options = options
	
	self.visibleRows = visibleRows or DEFAULT_VISIBLE_ROWS
	self.visibleRowsSubmenu = visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS

	if preshowDropdownFn then
		self:SetPreshowDropdownCallback(preshowDropdownFn)
	end
	
	if sortsItems == nil then sortsItems = DEFAULT_SORTS_ENTRIES end
	self:SetSortsItems(sortsItems)
	
	self.options = options
	self.narrateData = narrateData
--	self.m_container.options = options
--	self.m_container.narrateData = narrateData
	
	-- this will add custom and default templates to self.XMLrowTemplates the same way dataTypes were created before.
	self:AddCustomEntryTemplates(options)
end

function comboBoxClass:SetupEntryBase(control, data, list)
	self.m_dropdownObject:SetupEntryBase(control, data, list)
end

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

function comboBoxClass:OnGlobalMouseUp(eventCode, ...)
	if not self:BypassOnGlobalMouseUp(...) then
	   g_onGlobalMouseUp(self ,eventCode , ...)
	end
end

function comboBoxClass:BypassOnGlobalMouseUp(button)
--	d( buttonToString[button])
	if button == MOUSE_BUTTON_INDEX_LEFT then
		local moc = moc()
		if moc.typeId then
			return moc.typeId ~= ENTRY_ID
		end
	end

	return button == MOUSE_BUTTON_INDEX_RIGHT
end

function comboBoxClass:IsMouseOverControl()
	return self.m_dropdownObject:IsMouseOverControl()
end

-- >> template, height, setupFunction
local function getTemplateData(entryType, template)
	local templateDataForEntryType = template[entryType]
	return templateDataForEntryType.template, templateDataForEntryType.rowHeight, templateDataForEntryType.setupFunc, templateDataForEntryType.widthAdjust
end

-- Initializes custom data types setup functions
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
		
		control.m_label:SetText(name)
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

function comboBoxClass:AddMenuItems()
	self:UpdateItems()
	self.m_dropdownObject:AnchorToComboBox(self)

	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
end

local function comboBoxSortHelper(item1, item2, comboBoxObject)
	return ZO_TableOrderingFunction(item1, item2, "name", comboBoxObject.m_sortType, comboBoxObject.m_sortOrder)
end

function comboBoxClass:UpdateItems()
	if self.m_sortOrder and self.m_sortsItems then
		table.sort(self.m_sortedItems, function(item1, item2) return comboBoxSortHelper(item1, item2, self) end)
	end
	
	for k, itemEntry in ipairs(self.m_sortedItems) do
		local hasSubmenu = setItemEntryCustomTemplate(itemEntry, self.XMLrowTemplates)
		
		if hasSubmenu then
			itemEntry.hasSubmenu = true
			itemEntry.isNew = areAnyEntriesNew(itemEntry)
		end
	end
	
	if self:IsDropdownVisible() then
		self:ShowDropdown()
	end
end

function comboBoxClass:AddItem(itemEntry, updateOptions, templates)
	-- Append
	if not itemEntry.customEntryTemplate then
		local hasSubmenu = setItemEntryCustomTemplate(itemEntry, self.XMLrowTemplates)
		
		if hasSubmenu then
			itemEntry.hasSubmenu = true
			itemEntry.isNew = areAnyEntriesNew(itemEntry)
		end
	end
	g_addItem(self, itemEntry, updateOptions)
end

function comboBoxClass:HideDropdown()
	hideTooltip()
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end
	g_hideDropdown(self)
end

function comboBoxClass:ShowDropdownOnMouseEnter(parentControl)
	self:ShowDropdown()
	self.m_dropdownObject:SetHidden(false)
	self:AddMenuItems(parentControl)

	self:SetVisible(true)
end

function comboBoxClass:GetSubmenu()
	if not self.m_submenu then
		self.m_submenu = submenuClass:New(self, self.m_container, self.options, self.m_nextFree)
	end
	
	return self.m_submenu
end

function comboBoxClass:ShowSubmenu(parentControl)
	local submenu = self:GetSubmenu()

	submenu:ShowDropdownOnMouseEnter(parentControl)
end

--[[ controls if selected rows should open as selected
function comboBoxClass:IsItemSelected(item)
	-- This allows us to show currently selected item as highlighted in the submenu.
	if not self.m_enableMultiSelect then
		return self.m_selectedItemData == item
	end
	
	for i, itemData in ipairs(self.m_multiSelectItemData) do
		if itemData == item then
			return true
		end
	end
end

function comboBoxClass:RemoveItemFromSelected(item)
	if not self.m_enableMultiSelect then
		self.m_selectedItemData = nil
	end
	
	for i, itemData in ipairs(self.m_multiSelectItemData) do
		if itemData == item then
			table.remove(self.m_multiSelectItemData, i)
			return
		end
	end
end

]]
function comboBoxClass:SelectItemByIndex(index, ignoreCallback)
	self:HideDropdown()
	return g_selectItem(self, self.m_sortedItems[index], ignoreCallback)
end

--------------------------------------------------------------------
-- submenuClass
--------------------------------------------------------------------
-- submenuClass:New(To simplify locating the beginning of the class
function submenuClass:Initialize(parent, comboBoxContainer, options, depth)
--	d( '[LSM]submenuClass:Initialize')
	self.m_parentMenu = parent
	comboBoxClass.Initialize(self, parent, comboBoxContainer, options, depth)
end

function submenuClass:AddMenuItems(parentControl)
	self:UpdateItems(parentControl)
	
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())

	self.m_dropdownObject:AnchorToControl(parentControl)
end

function submenuClass:GetComboBox()
	return self.m_container.m_comboBox
end

function submenuClass:UpdateItems(parentControl)
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)
	local data = getControlData(parentControl)

	for k, item in ipairs(data.entries) do
		item.m_parentControl = parentControl
		self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
	end
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
	local comboBox = self:GetComboBox()
	return g_selectItem(comboBox, self.m_sortedItems[index], ignoreCallback)
end

--[[ controls if selected rows should open as selected
function submenuClass:IsItemSelected(item)
	-- This allows us to show currently selected item as highlighted in the submenu.
	
	local comboBox = self:GetComboBox()
	return comboBox:IsItemSelected(item)
end

function submenuClass:RemoveItemFromSelected(item)
	comboBox:RemoveItemFromSelected(item)
end
]]

--------------------------------------------------------------------
-- 
--------------------------------------------------------------------
local contextMenuClass = submenuClass:Subclass()
-- LibScrollableMenu
-- contextMenu:New(To simplify locating the beginning of the class
function contextMenuClass:Initialize(comboBoxContainer)
	submenuClass.Initialize(self, nil, comboBoxContainer, nil, 1)
	self.data = {}
	self.m_sortedItems = {}
end

function contextMenuClass:AddItem(itemEntry, updateOptions)
	if not itemEntry.customEntryTemplate then
		local hasSubmenu = setItemEntryCustomTemplate(itemEntry, self.XMLrowTemplates)
		
		if hasSubmenu then
			itemEntry.hasSubmenu = true
			itemEntry.isNew = areAnyEntriesNew(itemEntry)
		end
	end

	table.insert(self.data, itemEntry)
	
	if updateOptions ~= ZO_COMBOBOX_SUPPRESS_UPDATE then
		self:UpdateItems()
	end

	self:OnItemAdded()
end

function contextMenuClass:AddMenuItems()
	self:UpdateItems()
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
	self.m_dropdownObject:AnchorToMouse()
	self.m_dropdownObject.control:BringWindowToTop()
end

function contextMenuClass:ClearItems()
	ZO_ComboBox_HideDropdown(self:GetContainer())
	ZO_ClearNumericallyIndexedTable(self.data)
	self:SetSelectedItemText("")
	self.m_selectedItemData = nil
	self:OnClearItems()
end

function contextMenuClass:ShowSubmenu(parentControl)
	local submenu = self:GetSubmenu()
	submenu.m_container = self.m_comboBox.m_container
	submenu:ShowDropdownOnMouseEnter(parentControl)
end

function contextMenuClass:GetParentFromControl(control)
	local comboBox = getComboBoxFromControl(control)
	return comboBox or self.m_container.m_comboBox
end

function contextMenuClass:ShowContextMenu(parentControl)
	self.m_comboBox = self:GetParentFromControl(parentControl)
	
	-- Let the caller know that this is about to be shown...
	if self.m_preshowDropdownFn then
		self.m_preshowDropdownFn(self)
	end
	
	self:ShowDropdown()
	self:ShowDropdownOnMouseUp(parentControl)
end

function contextMenuClass:UpdateItems()
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)

	for k, v in ipairs(self.data) do
		table.insert(self.m_sortedItems, v)
	end
end

function contextMenuClass:PostUpdateOptions(options)
	self.optionsChanged = self.options ~= options
	comboBoxClass.UpdateOptions(self, options)
end

--[[
function contextMenuClass:ShowSubmenu(parentControl)
	local submenu = self:GetSubmenu()
	submenu.m_comboBox = self.m_comboBox
	submenu:ShowDropdownOnMouseEnter(parentControl)
end
]]

function contextMenuClass:GetComboBox()
	return self.m_comboBox
end

--------------------------------------------------------------------
-- 
--------------------------------------------------------------------
-- We need to integrate a supplied ZO_ComboBox with the lib's functionality.
-- First we must replace several of the m_comboBox functions with ones from comboBoxClass.

local function applyUpgrade(parent, comboBoxContainer, options)
	local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)

	assert(comboBox and comboBox.IsInstanceOf and comboBox:IsInstanceOf(ZO_ComboBox), 'The comboBoxContainer you supplied must be a valid ZO_ComboBox container. "comboBoxContainer.m_comboBox:IsInstanceOf(ZO_ComboBox)"')
	
	zo_mixin(comboBox, comboBoxClass)
	comboBox.__index = comboBox
	comboBox:Initialize(parent, comboBoxContainer, options, 1)
	
--	comboBoxContainer.m_comboBox = newComboBox
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
	assert(parent ~= nil and comboBoxContainer ~= nil, MAJOR .. " - AddCustomScrollableComboBoxDropdownMenu ERROR: Parameters parent and comboBoxControl must be provided!")

	local comboBox = applyUpgrade(parent, comboBoxContainer, options)
	return comboBox.m_dropdownObject
end
local addCustomScrollableComboBoxDropdownMenu = AddCustomScrollableComboBoxDropdownMenu

--[Custom scrollable context menu at any control]
--Add a scrollable menu to any control (not only a ZO_ComboBox), e.g. to an inventory row
--by creating a DUMMY ZO_ComboBox, adding the ScrollHelper class to it and use it
----------------------------------------------------------------------
local setCustomScrollableMenuOptions
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
addCustomScrollableMenuEntry = AddCustomScrollableMenuEntry

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
		g_contextMenu:PostUpdateOptions(options)
	end
end
setCustomScrollableMenuOptions = SetCustomScrollableMenuOptions

--Add a new scrollable context menu with the defined entries table.
--You can add more entries later via AddCustomScrollableMenuEntry function too
function AddCustomScrollableMenu(parent, entries, options)
	local entryTableType = type(entries)
	assert(entryTableType == 'table' , sfor('[LibScrollableMenu:AddCustomScrollableMenu] table expected, got %q = %s', "entries", tos(entryTableType)))

	if options then
		g_contextMenu:Clear()
		g_contextMenu:PostUpdateOptions(options)
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
-point, offsetX, offsetY, relativePoint: Suggested anchoring points

myAddon.customTooltipFunc(table data, userdata rowControl, Int point, Int offsetX, Int offsetY, Int relativePoint)
e.g. data = { name="Test 1", label="Test", customTooltip=function(data, rowControl, point, offsetX, offsetY, relativePoint) ... end, ... }

customTooltipFunc = function(data, control, point, offsetX, offsetY, relativePoint)
	if data == nil then
		self.myTooltipControl:SetHidden(true)
	else
		self.myTooltipControl:ClearAnchors()
		self.myTooltipControl:SetAnchor(point, control, relativePoint, offsetX, offsetY)
		self.myTooltipControl:SetText(data.tooltip)
		self.myTooltipControl:SetHidden(false)
	end
end
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

--[[TODO: 

We do not use ZO_Menu. Other then that, I do not know what should be change in this. -v-
just a reference to it's above counterpart
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
