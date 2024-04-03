if LibScrollableMenu ~= nil then return end -- the same or newer version of this lib is already loaded into memory

local lib = ZO_CallbackObject:New()
lib.name = "LibScrollableMenu"
local MAJOR = lib.name
lib.version = "2.0"

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
local zo_comboBox_hideDropdownInternal = ZO_ComboBox.HideDropdownInternal
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

--Sound settings
local origSoundComboClicked = SOUNDS.COMBO_CLICK
local soundComboClickedSilenced = SOUNDS.NONE

--dropdown settings
local SUBMENU_SHOW_TIMEOUT = 500 --350 ms before
local dropdownCallLaterHandle = MAJOR .. "_Timeout"

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
local DEFAULT_SPACING = 0
--TODO: remove or make use of --> local PADDING = GetMenuPadding() / 2 -- half the amount looks closer to the regular dropdown
local WITHOUT_ICON_LABEL_DEFAULT_OFFSETX = 4

local DEFAULT_FONT = "ZoFontGame"
local DEFAULT_HEIGHT = 250

--Menu types for the different scrollable menus
LSM_MENUTYPE_MAINMENU = 1
LSM_MENUTYPE_SUBMENU = 2
LSM_MENUTYPE_CONTEXTMENU = 100
LSM_MENUTYPE_CONTEXTMENU_SUBMENU = 101
local LSM_MENUTYPE_MAINMENU = LSM_MENUTYPE_MAINMENU
local LSM_MENUTYPE_SUBMENU = LSM_MENUTYPE_SUBMENU
local LSM_MENUTYPE_CONTEXTMENU = LSM_MENUTYPE_CONTEXTMENU
local LSM_MENUTYPE_CONTEXTMENU_SUBMENU = LSM_MENUTYPE_CONTEXTMENU_SUBMENU

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

local entryTypesForContextMenuWithoutMandatoryCallback = {
	[lib.LSM_ENTRY_TYPE_DIVIDER] = true,
	[lib.LSM_ENTRY_TYPE_HEADER] = true,
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
	["XMLRowTemplates"] = true,
	["narrate"] = true,
	["font"] = true,
	["spacing"] = true,
	["preshowDropdownFn"] = true,
}
lib.possibleLibraryOptions = possibleLibraryOptions

--The default values for comboBox options:
--The default values for the context menu options are:
local defaultComboBoxOptions  = {
	["visibleRowsDropdown"] = DEFAULT_VISIBLE_ROWS,
	["visibleRowsSubmenu"] = DEFAULT_VISIBLE_ROWS,
	["sortEntries"] = DEFAULT_SORTS_ENTRIES,
	["font"] = DEFAULT_FONT,
	["spacing"] = DEFAULT_SPACING,
	["preshowDropdownFn"] = nil,
	--["XMLRowTemplates"] = table, --Will be set at comboBoxClass:UpdateOptions(options) from options
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
	EM:UnregisterForUpdate(dropdownCallLaterHandle)
end

local function setTimeout(callback)
	clearTimeout()
	--Delay the dropdown close callback so we can move the mouse above a new dropdown control and keep that opened e.g.
	EM:RegisterForUpdate(dropdownCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		clearTimeout()
		if callback then callback() end
	end)
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
lib.GetValueOrCallback = getValueOrCallback

local function updateIsContextMenuAndIsSubmenu(selfVar)
	selfVar.isContextMenu = g_contextMenu and g_contextMenu.m_container == selfVar.m_container
	selfVar.isSubmenu = selfVar.m_parentMenu ~= nil
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
--	d("[LSM]updateSubmenuNewStatus")
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
--d("[LSM]clearNewStatus")
--d("data.isNew ' .. tostring(data.isNew))
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
	--We are not going to use processNameString(item) function here to update item.name and item.label here already because at dropdown:Show it's called to react on
	--actual values -> if item.name or item.label is a function checking values!
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
	--Passed in an alternative text/function returning a text to show at the label control of the menu entry?
	local label = data.label
	if type(label) == 'function' then
		--Keep the original name function at the data, as we need a "String only" text as data.name for ZO_ComboBox internal functions!
		data.labelFunction = label
	end
	if data.labelFunction then
		label = data.labelFunction(data)
		data.label = label
	end

	--Name: Mandatory! Used interally of ZO_ComboBox and dropdownObject to SetSelectedItemText and run callback on clicked entry with (self, item.name, data, selectionChanged, oldItem)
	local name = data.name
	if type(name) == 'function' then
		--Keep the original name function at the data, as we need a "String only" text as data.name for ZO_ComboBox internal functions!
		data.nameFunction = name
	end
	if data.nameFunction then
		name = data.nameFunction(data)
		data.name = name
	end


	--Check if name is provided as string: Mandatory!
	return type(data.name) == 'string'
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
--> For a custom tooltip example see line below:
--[[
--Custom tooltip function example
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
	["OnComboBoxMouseEnter"] = 	onMouseEnterOrExitNarrate,
	["OnComboBoxMouseExit"] =	onMouseEnterOrExitNarrate,
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

	if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
		dropdown:Narrate("OnEntrySelected", control, data, hasSubmenu)
		lib:FireCallbacks('EntryOnSelected', data, control)
	end

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
			--d("onMouseEnter [SUBMENU_ENTRY_ID]")
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
			--onMouseUp [ENTRY_ID]")
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
			--d("onMouseUp [CHECKBOX_ENTRY_ID]")
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

	local scrollCtrl = self.scrollControl
	if scrollCtrl then
		scrollCtrl.scrollbar.owner = 	scrollCtrl
		scrollCtrl.upButton.owner = 	scrollCtrl
		scrollCtrl.downButton.owner = 	scrollCtrl
	else
--d("[LSM]dropdownClass:Initialize -  self.scrollControl is nil")
	end
end

function dropdownClass:AddItems(items)
	error('['..MAJOR..'] scrollHelper:AddItems is obsolete. You must use m_comboBox:AddItems')
end

function dropdownClass:AddItem(item)
	error('['..MAJOR..'] scrollHelper:AddItems is obsolete. You must use m_comboBox:AddItem')
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
	local right = true
	local point, relativePoint = TOPLEFT, TOPRIGHT
	
	if self.m_parentMenu.m_dropdownObject and self.m_parentMenu.m_dropdownObject.anchorRight ~= nil then
		right = self.m_parentMenu.m_dropdownObject.anchorRight
	end
	
	if not right or parentControl:GetRight() + self.control:GetWidth() > width then
		right = false
		point, relativePoint = TOPRIGHT, TOPLEFT
	end
	
	local relativeTo = parentControl.m_dropdownObject.scrollControl
	-- Get offsetY in relation to parentControl's top in the scroll container
    local offsetY = select(6, parentControl:GetAnchor(0))

	self.control:ClearAnchors()
	self.control:SetAnchor(point, relativeTo, relativePoint, 2, offsetY)
	
	self.anchorRight = right

	--Check for context menu and submenu, and do narration
	updateIsContextMenuAndIsSubmenu(self)
	if not self.isContextMenu and self.isSubmenu == true then
		local anchorPoint = (right == true and TOPRIGHT) or TOPLEFT
		self:Narrate("OnSubMenuShow", parentControl, nil, nil, anchorPoint)
		lib:FireCallbacks('OnSubMenuShow', parentControl, anchorPoint)
	end
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
--d("[LSM]dropdownClass:GetScrollbar")
	local scrollCtrl = self.scrollControl
	local scrollBar = scrollCtrl ~= nil and scrollCtrl.scrollbar
	if scrollBar then ---and scrollCtrl.useScrollbar == true then (does not work for menus where there is no scrollabr active, but used in general!)
--d(">scrollBar found!")
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
--	d("[LSM]dropdownClass:OnMouseEnterEntry")
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
	
	--TODO: Conflicting OnMouseExitTimeout -> 20240310 What in detail is conflicting here, with what?
	if g_contextMenu:IsDropdownVisible() then
--d(">contex menu: Dropdown visible = yes")
		g_contextMenu.m_dropdownObject:OnMouseExitTimeout(control)
	end
end

function dropdownClass:OnMouseExitEntry(control)
	--d("[LSM]dropdownClass:OnMouseExitEntry")
--	d( control:GetName())
	
	hideTooltip()
	local data = getControlData(control)
	self:OnMouseExitTimeout(control)
	if not runHandler(handlerFunctions['onMouseExit'], control, data) then
		zo_comboBoxDropdown_onMouseExitEntry(self, control)
	end

	--[[
	if not lib.GetPersistentMenus() then
--		self:OnMouseExitTimeout(control)
	end
	]]
end

function dropdownClass:OnMouseExitTimeout(control)
--	clearTimeout()
	--d( "[LSM]dropdownClass:OnMouseExitTimeout-control: " ..tos(control:GetName()))

	setTimeout(function()
		self.owner:HideOnMouseExit(moc())
	end)
end

function dropdownClass:OnEntrySelected(control, button, upInside)
	--d("[LSM]dropdownClass:OnEntrySelected IsUpInside ' .. tos(upInside) .. ' Button ' .. tos(button))
	
	local data = getControlData(control)
	if not runHandler(handlerFunctions['onMouseUp'], control, data, button, upInside) then
--d(">not runHandler: onMouseUp -> Calling zo_comboBoxDropdown_onEntrySelected")
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

--Called from dropdownClass:SetupEntry(control, data, list)
function dropdownClass:SetupEntryLabel(labelControl, data)
	labelControl:SetText(data.label or data.name) -- Use alternative passed in label string, or the default mandatory name string
	labelControl:SetFont(self.owner:GetDropdownFont())
	local color = self.owner:GetItemNormalColor(data)

	LSM_Debug = LSM_Debug or {}
LSM_Debug._dropdownClass_SetupEntryLabel = LSM_Debug._dropdownClass_SetupEntryLabel or {}
LSM_Debug._dropdownClass_SetupEntryLabel[labelControl] = {
	control = labelControl,
	data = data,
	self = self,
	owner = self.owner,
	color = color,
	text = data.label or data.name,
	enabled = data.enabled,
	normalColor = data.m_normalColor,
}

	labelControl:SetColor(color:UnpackRGBA())
	labelControl:SetHorizontalAlignment(self.horizontalAlignment)
end

function dropdownClass:Show(comboBox, itemTable, minWidth, maxHeight, spacing)
	--d( sfor('[LSM]dropdownClass:Show - minWidth = %s, maxHeight = %s, spacing = %s', tos(minWidth), tos(maxHeight), tos(spacing)))
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
		if processNameString(item) then
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

			allItemsHeight = allItemsHeight + entryHeight

			local entry = createScrollableComboBoxEntry(self, item, i, entryType)
			tins(dataList, entry)

			local fontObject = self.owner:GetDropdownFontObject()
			--Check string width of label (alternative text to show at entry) or name (internal value used)
			local nameWidth = GetStringWidthScaled(fontObject, item.label or item.name, 1, SPACE_INTERFACE) + widthAdjust
			if nameWidth > largestEntryWidth then
				largestEntryWidth = nameWidth
			end
		end
	end

	-- using the exact width of the text can leave us with pixel rounding issues
	-- so just add 5 to make sure we don't truncate at certain screen sizes
	largestEntryWidth = largestEntryWidth + 5

	allItemsHeight = allItemsHeight + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2)

	local desiredHeight = maxHeight
	if allItemsHeight < desiredHeight then
		desiredHeight = allItemsHeight
		ApplyTemplateToControl(self.scrollControl.contents, "LibScrollableMenu_Scroll_No_Bar")
	else
		ApplyTemplateToControl(self.scrollControl.contents, "LibScrollableMenu_Scroll_Bar")
	end

	-- Allow the dropdown to automatically widen to fit the widest entry, but
	-- prevent it from getting any skinnier than the container's initial width
	local totalDropDownWidth = largestEntryWidth + ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2 + ZO_SCROLL_BAR_WIDTH
	if totalDropDownWidth > minWidth then
		self.control:SetWidth(totalDropDownWidth)
	else
		self.control:SetWidth(minWidth)
	end

	self.control:SetHeight(desiredHeight)
	ZO_ScrollList_SetHeight(self.scrollControl, desiredHeight)

	ZO_ScrollList_Commit(self.scrollControl)
	self.control:BringWindowToTop()

	--Check for context menu and submenu, and do narration
	updateIsContextMenuAndIsSubmenu(self)
	if not self.isContextMenu and not self.isSubmenu == true then
		self:Narrate("OnMenuShow", self.control)
		lib:FireCallbacks('OnMenuShow', self.control)
	end
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
--> dropdownClass:ShowDropdownInternal() -> Used for submenus only. Main menu will be handled directly at ZO_ComboBox class!
function dropdownClass:ShowDropdownInternal()
	local control = self.control
	control:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self.owner:OnGlobalMouseUp(...) end)
end

--> dropdownClass:HideDropdownInternal() -> Used for submenus only
function dropdownClass:HideDropdownInternal()
	local control = self.control
	control:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)

	updateIsContextMenuAndIsSubmenu(self)
	if not self.isContextMenu then
		if self.isSubmenu == true then
			self:Narrate("OnSubMenuHide", control)
			lib:FireCallbacks('OnSubMenuHide', control)
		end
	end
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

	return self
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
	
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
end

-- Changed to hide tooltip and, if available, it's submenu
-- We hide the tooltip here so it is hidden if the dropdown is hidden OnGlobalMouseUp
function comboBoxClass:HideDropdown()
--d("comboBoxClass:HideDropdown()")
	-- Recursive through all open submenus and close them starting from last.
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end

	zo_comboBox_base_hideDropdown(self)

	--Narrate the OnMenuHide texts
	local function narrateOnMenuHideButOnlyOnceAsHideDropdownIsCalledTwice()
		updateIsContextMenuAndIsSubmenu(self)
		if self.narrateData and self.narrateData["OnMenuHide"] then
	--d(">narrate OnMenuHide-isContextMenu: " ..tos(self.isContextMenu) .. ", isSubmenu: " .. tos(self.isSubmenu))
			if not self.isContextMenu and not self.isSubmenu then
				self:Narrate("OnMenuHide", self.m_container)
				lib:FireCallbacks('OnMenuHide', self.m_container)
			end
		end
	end
	onUpdateDoNarrate("OnMenuHide_Start", 25, narrateOnMenuHideButOnlyOnceAsHideDropdownIsCalledTwice)
end

function comboBoxClass:HideDropdownInternal()
	zo_comboBox_hideDropdownInternal(self)
	hideTooltip()
end

function comboBoxClass:SelectItemByIndex(index, ignoreCallback)
	--d("SelectItemByIndex ' .. tos(index))
	return zo_comboBox_selectItem(self, self.m_sortedItems[index], ignoreCallback)
end

-- Changed to bypass if needed.
function comboBoxClass:OnGlobalMouseUp(eventCode, ...)
--d("[LSM]comboBoxClass:OnGlobalMouseUp - BypassOnGlobalMouseUp: " ..tos(self:BypassOnGlobalMouseUp(...)))
	if not self:BypassOnGlobalMouseUp(...) then
	   zo_comboBox_onGlobalMouseUp(self ,eventCode , ...)
	end
end

-- [New functions]
function comboBoxClass:IsMouseOverScrollbarControl()
--d("[LSM]comboBoxClass:IsMouseOverScrollbarControl")
	local mocCtrl = moc()
	if mocCtrl ~= nil then
		local owner = mocCtrl.owner
		return owner and owner.scrollbar ~= nil
	end
	return false
end

function comboBoxClass:BypassOnGlobalMouseUp(button)
	--d("[LSM]comboBoxClass:BypassOnGlobalMouseUp-button: " ..tos(button) .. ", isMouseOverScrollbar: " ..tos(self:IsMouseOverScrollbarControl()))

	if self:IsMouseOverScrollbarControl() then
		--d(">>mouse is above scrollbar")
		return true
	end

	if button == MOUSE_BUTTON_INDEX_LEFT then
		local mocCtrl = moc()
		--d(">moc: " ..tos(mocCtrl ~= nil and mocCtrl:GetName()) .. ", mocTypeId: " ..tos(mocCtrl.typeId))
		if mocCtrl.typeId then
			return mocCtrl.typeId ~= ENTRY_ID
		end
	end
	--Any other right mouse click -> Stay opened!
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
		["OnComboBoxMouseExit"] = function() return self, ctrl end,
		["OnComboBoxMouseEnter"]= function() return self, ctrl end,
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
	if not self.optionsChanged then return end
	self.optionsChanged = false

	options = options or {}
	
	-- Backwards compatible
	if type(options) ~= 'table' then
		options = {
			visibleRowsDropdown = options
		}
	end

--	local defaultOptions = self.options or defaultComboBoxOptions
	-- We add all previous options to the new table
--	mixinTableAndSkipExisting(options, defaultOptions)
	-- We will need to start with a clean table in order to reset options if they were changed before.
	-- Otherwise, if options are changed, all previous changes will be applied to undefined entries.
	mixinTableAndSkipExisting(options, defaultComboBoxOptions)
	
	local narrateData = getValueOrCallback(options.narrate, options)

	-- Defaults are predefined in defaultComboBoxOptions
	local visibleRows = getValueOrCallback(options.visibleRowsDropdown, options)
	local visibleRowsSubmenu = getValueOrCallback(options.visibleRowsSubmenu, options)
	local sortEntries = getValueOrCallback(options.sortEntries, options)
	local font = getValueOrCallback(options.font, options)
	local spacing = getValueOrCallback(options.spacing, options)
	local preshowDropdownFn = getValueOrCallback(options.preshowDropdownFn, options)

	-- Defaults used if nil
	local sortType = getValueOrCallback(options.sortType, options)
	local sortOrder = getValueOrCallback(options.sortOrder, options)

	if preshowDropdownFn then
		self:SetPreshowDropdownCallback(preshowDropdownFn)
	end
	
	self.visibleRows = visibleRows
	self.visibleRowsSubmenu = visibleRowsSubmenu or visibleRows
	
	self:SetSortsItems(sortEntries)
	self:SetFont(font)
	self:SetSpacing(spacing)
	self:SetSortOrder(sortOrder, sortType)
		
	self.options = options
	self.narrateData = narrateData
	
	-- this will add custom and default templates to self.XMLrowTemplates the same way dataTypes were created before.
	self:AddCustomEntryTemplates(options)
	
	local maxHeight = SCROLLABLE_ENTRY_TEMPLATE_HEIGHT * self:GetMaxRows()
	self:SetHeight(maxHeight)
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
end

function comboBoxClass:HideOnMouseEnter()
	--d("comboBoxClass:HideOnMouseEnter")
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() and not self:IsMouseOverControl() then
		self.m_submenu:HideDropdown()
	end
end

function comboBoxClass:HideOnMouseExit(mocCtrl)
--d("[LSM]comboBoxClass:HideOnMouseExit")
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() and not self.m_submenu:IsMouseOverOpeningControl() then
--d(">submenu found, but mouse not over it! HideDropdown")
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
--	d("[LSM]submenuClass:Initialize")
	self.m_parentMenu = parent
	comboBoxClass.Initialize(self, parent, comboBoxContainer, options, depth)
	self.owner = comboBoxContainer.m_comboBox
	self.isSubmenu = true
end

function submenuClass:AddMenuItems(parentControl)
	self.openingControl = parentControl
	self:RefreshSortedItems(parentControl)
	
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())

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
--d("[LSM]submenuClass:OnGlobalMouseUp - DropdownVisible: " ..tos(self:IsDropdownVisible()) ..", BypassOnGlobalMouseUp: " ..tos(self:BypassOnGlobalMouseUp(...)))
	if self:IsDropdownVisible() and not self:BypassOnGlobalMouseUp(...) then
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

function submenuClass:HideOnMouseExit(mocCtrl)
--d("[LSM]submenuClass:HideOnMouseExit")
	-- Only begin hiding if we stopped over a dropdown.
	mocCtrl = mocCtrl or moc()
	if mocCtrl.m_dropdownObject then
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
--local contextMenuClass = submenuClass:Subclass()
local contextMenuClass = comboBoxClass:Subclass()
-- LibScrollableMenu.contextMenu
-- contextMenuClass:New(To simplify locating the beginning of the class
function contextMenuClass:Initialize(comboBoxContainer)
	comboBoxClass.Initialize(self, nil, comboBoxContainer, nil, 1)
	self.data = {}
	self.m_sortedItems = {}
	
	self:ClearItems()

	self.isContextMenu = true
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
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
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
	comboBoxClass.HideDropdownInternal(self)
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

function contextMenuClass:OnGlobalMouseUp(eventCode, ...)
--d("[LSM]contextMenuClass:OnGlobalMouseUp")
	submenuClass.OnGlobalMouseUp(self, eventCode, ...)
end


--------------------------------------------------------------------
-- 
--------------------------------------------------------------------
-- We need to integrate a supplied ZO_ComboBox with the lib's functionality.
-- We do this by replacing the m_comboBox with our custom comboBoxClass.

local function setComboBoxHandlers(comboBoxContainer, comboBoxSelf)
--d("[LSM]setComboBoxHandlers:SetHandlers - comboBoxContainer: " ..tos(comboBoxContainer:GetName()))
	if comboBoxContainer == nil or comboBoxSelf == nil or comboBoxSelf.Narrate == nil then return end

	local narrateData = comboBoxSelf.narrateData
	if narrateData ~= nil then

		if (narrateData["OnComboBoxMouseEnter"] or narrateData["OnComboBoxMouseExit"]) then
			--d(">>narrateData and OnComboBoxMouseEnter or OnComboBoxMouseExit found!")
			local function comboBoxCtrlOnMouseEnter()
				comboBoxSelf:Narrate("OnComboBoxMouseEnter", comboBoxContainer, nil, nil)
			end
			local function comboBoxCtrlOnMouseExit()
				comboBoxSelf:Narrate("OnComboBoxMouseExit", comboBoxContainer, nil, nil)
			end
			ZO_PostHookHandler(comboBoxContainer, "OnMouseEnter", function() comboBoxCtrlOnMouseEnter() end)
			ZO_PostHookHandler(comboBoxContainer, "OnMouseExit", function() comboBoxCtrlOnMouseExit() end)
		end
	end
end


local function applyUpgrade(parent, comboBoxContainer, options)
	local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)

	assert(comboBox and comboBox.IsInstanceOf and comboBox:IsInstanceOf(ZO_ComboBox), MAJOR .. ' | The comboBoxContainer you supplied must be a valid ZO_ComboBox container. "comboBoxContainer.m_comboBox:IsInstanceOf(ZO_ComboBox)"')

	local originalIndex = comboBox.__index
	local parentClasses = { comboBoxClass, originalIndex }
	comboBox.__index = setmetatable(comboBox, {
		__index = function(tbl, key)
			for _, parentClassTable in ipairs(parentClasses) do
				local value = parentClassTable[key]
				if value ~= nil then
					return value
				end
			end
		end
	})
	comboBox.__parentClasses = parentClasses

	lib:FireCallbacks('OnDropdownMenuAdded', comboBox, options)

	comboBox:Initialize(parent, comboBoxContainer, options, 1)

	setComboBoxHandlers(comboBoxContainer, comboBox)

	return comboBox
end


--[[
local function applyUpgrade(parent, comboBoxContainer, options)
	local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)

	assert(comboBox and comboBox.IsInstanceOf and comboBox:IsInstanceOf(ZO_ComboBox), MAJOR .. ' - applyUpgrade | The comboBoxContainer you supplied must be a valid ZO_ComboBox container. "comboBoxContainer.m_comboBox:IsInstanceOf(ZO_ComboBox)"')

	zo_mixin(comboBox, comboBoxClass)
	comboBox.__index = comboBox
	comboBox:Initialize(parent, comboBoxContainer, options, 1)

	return comboBox
end
]]

--------------------------------------------------------------------
-- Public API functions
--------------------------------------------------------------------
lib.persistentMenus = false -- controls if submenus are closed shortly after the mouse exists them
							-- 2024-03-10 Currently not used anywhere!!!
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
--	control comboBoxContainer 				Must be any ZO_ComboBox control (e.g. created from virtual template ZO_ComboBox)
--  table options:optional = {
--		number visibleRowsDropdown:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened dropdown
--		number visibleRowsSubmenu:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened submenus
--		boolean sortEntries:optional			Boolean or function returning boolean if items in the main-/submenu should be sorted alphabetically: ZO_SORT_ORDER_UP or ZO_SORT_ORDER_DOWN
--		table sortType:optional					table or function returning table for the sort type, e.g. ZO_SORT_BY_NAME, ZO_SORT_BY_NAME_NUMERIC
--		boolean sortOrder:optional				Boolean or function returning boolean for the sort order
-- 		string font:optional = "FontNameHere" 	String or function returning a string: font to use for the dropdown entries
-- 		number spacing:optional = 1, 			Number or function returning a Number : Spacing between the entries
-- 		function preshowDropdownFn:optional 	function function(ctrl) codeHere end to run before the dropdown shows
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
--												"OnComboBoxMouseEnter" 	function(m_dropdownObject, comboBoxControl)  Build your narrateString and narrate it now, or return a string and let the library narrate it for you end
--												"OnComboBoxMouseExit"	function(m_dropdownObject, comboBoxControl) end
--												"OnMenuShow"			function(m_dropdownObject, dropdownControl, nil, nil) end
--												"OnMenuHide"			function(m_dropdownObject, dropdownControl) end
--												"OnSubMenuShow"			function(m_dropdownObject, parentControl, anchorPoint) end
--												"OnSubMenuHide"			function(m_dropdownObject, parentControl) end
--												"OnEntryMouseEnter"		function(m_dropdownObject, entryControl, data, hasSubmenu) end
--												"OnEntryMouseExit"		function(m_dropdownObject, entryControl, data, hasSubmenu) end
--												"OnEntrySelected"		function(m_dropdownObject, entryControl, data, hasSubmenu) end
--												"OnCheckboxUpdated"		function(m_dropdownObject, checkboxControl, data) end
--			Example:	narrate = { ["OnComboBoxMouseEnter"] = myAddonsNarrateComboBoxOnMouseEnter, ... }
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

--Adds a new entry to the context menu entries with the shown text, where the callback function is called once the entry is clicked.
--If entries is provided the entry will be a submenu having those entries. The callback can be used, if entries are passed in, too (to select a special entry and not an enry of the opening submenu).
--But usually it should be nil if entries are specified, as each entry in entries got it's own callback then.
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
--
--Example - Normal entry without submenu
--AddCustomScrollableMenuEntry("Test entry 1", function() d("test entry 1 clicked") end, LibScrollableMenu.LSM_ENTRY_TYPE_NORMAL, nil, nil)
--Example - Normal entry with submenu
--AddCustomScrollableMenuEntry("Test entry 1", function() d("test entry 1 clicked") end, LibScrollableMenu.LSM_ENTRY_TYPE_NORMAL, {
--	{
--		label = "Test submenu entry 1", --optional String or function returning a string. If missing: Name will be shown and used for clicked callback value
--		name = "TestValue1" --String or function returning a string if label is givenm name will be only used for the clicked callback value
--		isHeader = false, -- optional boolean or function returning a boolean Is this entry a non clickable header control with a headline text?
--		isDivider = false, -- optional boolean or function returning a boolean Is this entry a non clickable divider control without any text?
--		isCheckbox = false, -- optional boolean or function returning a boolean Is this entry a clickable checkbox control with text?
--		isNew = false, --  optional booelan or function returning a boolean Is this entry a new entry and thus shows the "New" icon?
--		entries = { ... see above ... }, -- optional table containing nested submenu entries in this submenu -> This entry opens a new nested submenu then. Contents of entries use the same values as shown in this example here
--		contextMenuCallback = function(ctrl) ... end, -- optional function for a right click action, e.g. show a scrollable context menu at the menu entry
-- }
--}, --[[additionalData]] { isNew = true, m_normalColor = ZO_ColorDef, m_highlightColor = ZO_ColorDef, m_disabledColor = ZO_ColorDef, m_font = "ZO_FontGame" } )
function AddCustomScrollableMenuEntry(text, callback, entryType, entries, additionalData)
	assert(text ~= nil, sfor('['..MAJOR..':AddCustomScrollableMenuEntry] String or function returning a string expected, got %q = %s', "text", tos(text)))
--	local scrollHelper = initCustomScrollMenuControl()
--	scrollHelper = scrollHelper or getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	local options = g_contextMenu:GetOptions()

	--If no entryType was passed in: Use normal text line type
	entryType = entryType or lib.LSM_ENTRY_TYPE_NORMAL
	if not allowedEntryTypesForContextMenu[entryType] then
		entryType = lib.LSM_ENTRY_TYPE_NORMAL
	end
	--If an entry type is used which does need a callback, and no submenu entries were passed in additionally: error the missing callback
	if entries == nil and not entryTypesForContextMenuWithoutMandatoryCallback[entryType] then
		assert(type(callback) == "function", sfor('['..MAJOR..':AddCustomScrollableMenuEntry] Callback function expected, got %q = %s', "callback", tos(callback)))
	end

	--Or is it a header line?
	local isHeader = entryType == lib.LSM_ENTRY_TYPE_HEADER
	--Or a clickable checkbox line?
	local isCheckbox = entryType == lib.LSM_ENTRY_TYPE_CHECKBOX
	--or just a ---------- divider line?
	local isDivider = entryType == lib.LSM_ENTRY_TYPE_DIVIDER or text == libDivider
	if isDivider == true then entryType = lib.LSM_ENTRY_TYPE_DIVIDER end

	local newEntry = {
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
	}

	local addDataType = type(additionalData)
	if addDataType == "table" then
		--[[ Will add e.g. the following data:
			additionalData.m_normalColor
			additionalData.m_highlightColor
			additionalData.m_disabledColor
			additionalData.m_font
			additionalData.isNew
		]]
		mixinTableAndSkipExisting(newEntry, additionalData)
	--Fallback vor old verions of LSM <2.1 where additionalData table was missing and isNew was used as the same parameter
	elseif addDataType == "boolean" then
		newEntry.isNew = addDataType
	end

	--Add the line of the context menu to the internal tables. Will be read as the ZO_ComboBox's dropdown opens and calls
	--:AddMenuItems() -> Added to internal scroll list then
	g_contextMenu:AddItem(newEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)
end
local addCustomScrollableMenuEntry = AddCustomScrollableMenuEntry

--Adds an entry having a submenu (or maybe nested submenues) in the entries table
--> See examples for the table "entries" values above AddCustomScrollableMenuEntry
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableSubMenuEntry(text, entries)
	addCustomScrollableMenuEntry(text, nil, lib.LSM_ENTRY_TYPE_NORMAL, entries, nil)
end

--Adds a divider line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableMenuDivider()
	addCustomScrollableMenuEntry(libDivider, nil, lib.LSM_ENTRY_TYPE_DIVIDER, nil, nil)
end

--Set the options (visible rows max, etc.) for the scrollable context menu
-->See possible options above AddCustomScrollableComboBoxDropdownMenu
function SetCustomScrollableMenuOptions(options, comboBoxContainer)
	local optionsTableType = type(options)
	assert(optionsTableType == 'table' , sfor('['..MAJOR..':SetCustomScrollableMenuOptions] table expected, got %q = %s', "options", tos(optionsTableType)))

	if options then
		--Use specified comboBoxContainer's dropdown to update the options to
		if comboBoxContainer ~= nil then
			local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
			if comboBox ~= nil and comboBox.UpdateOptions then
				comboBox.optionsChanged = options ~= comboBox.options
				comboBox:UpdateOptions(options)
			end
		else
			--Update options to default contextMenu
			g_contextMenu:SetOptions(options)
		end
	end
end
local setCustomScrollableMenuOptions = SetCustomScrollableMenuOptions

--Hide the custom scrollable context menu and clear it's entries, clear internal variables, mouse clicks etc.
function ClearCustomScrollableMenu()
	--d("[LSM]ClearCustomScrollableMenu")
	g_contextMenu:ClearItems()

	setCustomScrollableMenuOptions(defaultComboBoxOptions)
	return true
end
local clearCustomScrollableMenu = ClearCustomScrollableMenu

--Pass in a table with predefined context menu entries and let them all be added in order of the table's number key
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableMenuEntries(contextMenuEntries)
	if ZO_IsTableEmpty(contextMenuEntries) then return end
	for _, v in ipairs(contextMenuEntries) do
		addCustomScrollableMenuEntry(v.label or v.name, v.callback, v.entryType, v.entries, v.isNew)
	end
	return true
end
local addCustomScrollableMenuEntries = AddCustomScrollableMenuEntries

--Populate a new scrollable context menu with the defined entries table.
--Existing context menu entries will be reset, because ClearCustomScrollableMenu will be called!
--You can add more entries later, prior to showing, via AddCustomScrollableMenuEntry / AddCustomScrollableMenuEntries functions too
function AddCustomScrollableMenu(entries, options)
	--Clear the existing menu entries
	clearCustomScrollableMenu()

	local entryTableType = type(entries)
	assert(entryTableType == 'table' , sfor('['..MAJOR..':AddCustomScrollableMenu] table expected, got %q = %s', "entries", tos(entryTableType)))

	if options then
		setCustomScrollableMenuOptions(options)
	end
	
	return addCustomScrollableMenuEntries(entries)
end

--Show the custom scrollable context menu now at the control controlToAnchorTo, using optional options.
--If controlToAnchorTo is nil it will be anchored to the current control's position below the mouse, like ZO_Menu does
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function ShowCustomScrollableMenu(controlToAnchorTo, options)
	--d("[LSM]ShowCustomScrollableMenu")
	if options then
		setCustomScrollableMenuOptions(options)
	end

	controlToAnchorTo = controlToAnchorTo or moc()
	g_contextMenu:ShowContextMenu(controlToAnchorTo)
	return true
end






------------------------------------------------------------------------------------------------------------------------
-- Test - Move LibCustomMenu and normal vanilla ZO_Menu controls to LibScrollableMenu scrollable menus
------------------------------------------------------------------------------------------------------------------------
--Only enable for these "owners" (ZO_Menu's owner, or parent or owningWindow)
local zoListDialog = ZO_ListDialog1

local listRowsAllowedPatterns = {
	--ZOs
    "^ZO_%a+Backpack%dRow%d%d*",                                            --Inventory backpack
    "^ZO_%a+InventoryList%dRow%d%d*",                                       --Inventory backpack
    "^ZO_CharacterEquipmentSlots.+$",                                       --Character
    "^ZO_CraftBagList%dRow%d%d*",                                           --CraftBag
    "^ZO_Smithing%aRefinementPanelInventoryBackpack%dRow%d%d*",             --Smithing refinement
    "^ZO_RetraitStation_%a+RetraitPanelInventoryBackpack%dRow%d%d*",        --Retrait
    "^ZO_QuickSlot_Keyboard_TopLevelList%dRow%d%d*",                        --Quickslot
    "^ZO_RepairWindowList%dRow%d%d*",                                       --Repair at vendor
    "^ZO_ListDialog1List%dRow%d%d*",                                        --List dialog (Repair, Recharge, Enchant, Research)
    "^ZO_CompanionEquipment_Panel_.+List%dRow%d%d*",                        --Companion Inventory backpack
    "^ZO_CompanionCharacterWindow_.+_TopLevelEquipmentSlots.+$",            --Companion character
    "^ZO_UniversalDeconstructionTopLevel_%a+PanelInventoryBackpack%dRow%d%d*",--Universal deconstruction

	--Other addons
	"^IIFA_ListItem_%d",													--Inventory Insight from Ashes (IIfA)
}
local function isSupportedInventoryRowPattern(ownerCtrl, controlName)
	--return false --todo: for debugging remve againto enable LSM at inventory row context menus again

	controlName = controlName or (ownerCtrl ~= nil and ownerCtrl.GetName and ownerCtrl:GetName())
    if not controlName then return false, nil end
    if not listRowsAllowedPatterns then return false, nil end
    for _, patternToCheck in ipairs(listRowsAllowedPatterns) do
        if controlName:find(patternToCheck) ~= nil then
            return true, patternToCheck
        end
    end
    return false, nil
end

local entryTypeNormal = lib.LSM_ENTRY_TYPE_NORMAL
local entryTypeCheckbox = lib.LSM_ENTRY_TYPE_CHECKBOX
local entryTypeDivider = lib.LSM_ENTRY_TYPE_DIVIDER
local entryTypeHeader = lib.LSM_ENTRY_TYPE_HEADER

local libCustomMenuIsLoaded = LibCustomMenu ~= nil
local mapLCMItemtypeToLSMEntryType
if libCustomMenuIsLoaded then
	mapLCMItemtypeToLSMEntryType = {
		[MENU_ADD_OPTION_LABEL]		= entryTypeNormal,
		[MENU_ADD_OPTION_CHECKBOX]	= entryTypeCheckbox,
		[MENU_ADD_OPTION_HEADER]	= entryTypeHeader,
	}
end

local itemAddedNum = 0
local errorNr = 0
local function mapZO_MenuItemToLSMEntry(ZO_MenuItemData, menuIndex, isBuildingSubmenu)
	if lib.debugLCM then d("[LSM]mapZO_MenuItemToLSMEntry-itemAddedNum: " .. tos(itemAddedNum) .. ", isBuildingSubmenu: " .. tos(isBuildingSubmenu)) end
	isBuildingSubmenu = isBuildingSubmenu or false
	itemAddedNum = itemAddedNum + 1
	local lsmEntry
	local itemCopy = ZO_MenuItemData.item --~= nil and ZO_ShallowTableCopy(ZO_MenuItemData.item)

	local itemCopyCopy
	if itemCopy ~= nil then
		itemCopyCopy = itemCopy


		local entryName
		local callbackFunc
		local isCheckbox = ZO_MenuItemData.checkbox ~= nil
		local isDivider = false
		local isHeader = false
		local entryType = isCheckbox and entryTypeCheckbox or entryTypeNormal
		local hasSubmenu = false
		local submenuEntries
		local isNew = nil

		--LibCustomMenu variables - LSM does not support that all yet - TODO?
		local myfont
		local normalColor
		local highlightColor
		local disabledColor
		local itemYPad
		local horizontalAlignment
		local tooltip
		local enabled = true

		local processVanillaZO_MenuItem = true
		if libCustomMenuIsLoaded then
			--LibCustomMenu values in ZO_Menu.items[i].item.entryData or .submenuData:
			--[[
			{
				mytext = mytext,
				myfunction = myfunction or function() end,
				itemType = itemType,
				myfont = myFont,
				normalColor = normalColor,
				highlightColor = highlightColor,
				itemYPad = itemYPad,
				horizontalAlignment = horizontalAlignment
			}
			]]
			--Is this an entry opening a submen?
			local entryData = itemCopy.entryData
			local submenuData = itemCopy.submenuData
			if submenuData ~= nil and submenuData.entries ~= nil then
				local submenuItems = submenuData.entries
				if lib.debugLCM then d(">LCM  found Submenu items: " ..tos(#submenuItems)) end
				processVanillaZO_MenuItem = false

				entryName = 			submenuData.mytext
				entryType = 			mapLCMItemtypeToLSMEntryType[submenuData.itemType] or entryTypeNormal
				callbackFunc = 			submenuData.myfunction
				myfont =				submenuData.myfont
				normalColor = 			submenuData.normalColor
				highlightColor = 		submenuData.highlightColor
				itemYPad = 				submenuData.itemYPad
				isHeader = 				false
				tooltip = 				itemCopy.tooltip
				--enabled =				submenuData.enabled Not supported in LibCustomMenu

				hasSubmenu = true
				--Add non-nested (only 1 level) subMenu entries of LibCustomMenu
				submenuEntries = {}
				for submenuIdx, submenuEntry in ipairs(submenuItems) do
					submenuEntry.submenuData = nil
					--Prepapre the needed data table for the recursive call to mapZO_MenuItemToLSMEntry
					submenuEntry.entryData = {
						mytext = 				submenuEntry.label,
						itemType =				submenuEntry.itemType,
						myfunction =			submenuEntry.callback,
						myfont =				submenuEntry.myfont,
						normalColor =			submenuEntry.normalColor,
						highlightColor =		submenuEntry.highlightColor,
						itemYPad =				submenuEntry.itemYPad,
						--horizontalAlignment =	submenuEntry.horizontalAlignment,
						tooltip = 				submenuEntry.tooltip,

						enabled =				true
					}
					if submenuEntry.disabled ~= nil then
						local disabledType = type(submenuEntry.disabled)
						if disabledType == "function" then
							submenuEntry.entryData.enabled = function(...) return not submenuEntry.disabled(...) end
						elseif disabledType == "boolean" then
							submenuEntry.entryData.enabled = not submenuEntry.disabled
						else
						end
					end

					local lsmEntryForSubmenu = mapZO_MenuItemToLSMEntry({ item = submenuEntry }, submenuIdx, true)
					if lsmEntryForSubmenu ~= nil and lsmEntryForSubmenu.name ~= nil then
						submenuEntries[#submenuEntries + 1] = lsmEntryForSubmenu
					end
				end

			elseif entryData ~= nil then
				entryName =				entryData.mytext
				entryType = 			mapLCMItemtypeToLSMEntryType[entryData.itemType] or entryTypeNormal
				callbackFunc = 			entryData.myfunction
				myfont =				entryData.myfont
				normalColor = 			entryData.normalColor
				highlightColor = 		entryData.highlightColor
				itemYPad = 				entryData.itemYPad
				horizontalAlignment = 	entryData.horizontalAlignment

				isHeader = 				isHeader or itemCopy.isHeader

				tooltip = 				itemCopy.tooltip

				processVanillaZO_MenuItem = (entryName == nil or callbackFunc == nil and true) or false

				if entryData.enabled ~= nil then
					enabled = entryData.enabled
				end

				if lib.debugLCM then d(">LCM found normal item-processVanillaZO_MenuItem: " .. tos(processVanillaZO_MenuItem)) end
			end
		end

		--Normal ZO_Menu item added via AddMenuItem (without LibCustomMenu)
		if processVanillaZO_MenuItem then
			if lib.debugLCM then d(">LCM process vanilla ZO_Menu item") end
			entryName = 	entryName or (itemCopy.nameLabel and itemCopy.nameLabel:GetText())
			callbackFunc = 	callbackFunc or itemCopy.OnSelect
			isHeader = 		isHeader or itemCopy.isHeader
			tooltip = 		itemCopy.tooltip

			if itemCopy.enabled ~= nil then
				enabled = itemCopy.enabled
			end
		end

		--Entry type checks
		---Is the entry a divider "-"?
		isDivider = entryName and entryName == libDivider
		if isDivider then entryType = entryTypeDivider end
		---Is the entry a header?
		if isHeader then entryType = entryTypeHeader end


		if lib.debugLCM then
			d(">>LSM entry[" .. tos(itemAddedNum) .. "]-name: " ..tos(entryName) .. ", callbackFunc: " ..tos(callbackFunc) .. ", type: " ..tos(entryType) .. ", hasSubmenu: " .. tos(hasSubmenu) .. ", entries: " .. tos(submenuEntries))
		end

		--Return values for LSM entry
		if entryName ~= nil then
			lsmEntry = {}
			lsmEntry.name = 		entryName
			lsmEntry.isDivider = 	isDivider
			lsmEntry.isHeader = 	isHeader

			lsmEntry.entryType = 	entryType

			lsmEntry.callback = 	callbackFunc

			lsmEntry.hasSubmenu = 	hasSubmenu
			lsmEntry.entries = 		submenuEntries

			lsmEntry.tooltip = 		tooltip

			lsmEntry.isNew = 		isNew

			--lsmEntry.m_font		= 	myfont or comboBoxDefaults.m_font
			lsmEntry.m_normalColor = normalColor or comboBoxDefaults.m_normalColor
			lsmEntry.m_disabledColor = disabledColor or comboBoxDefaults.m_disabledColor
			lsmEntry.m_highlightColor = highlightColor or comboBoxDefaults.m_highlightColor

			--todo: LSM does not support that yet -> Add it to SetupFunction and use ZO_ComboBox_Base:SetItemEnabled(item, GetValurOrCallback(data.enabled, data)) then
			lsmEntry.enabled = 		enabled
		end

		if lib.debugLCM then
			LSM_Debug = LSM_Debug or {}
			LSM_Debug._ZO_MenuMappedToLSMEntries = LSM_Debug._ZO_MenuMappedToLSMEntries or {}
			LSM_Debug._ZO_MenuMappedToLSMEntries[itemAddedNum] = {
				_itemData = ZO_ShallowTableCopy(ZO_MenuItemData),
				_item = itemCopy ~= nil and itemCopy or "! ERROR !",
				_itemCopy = itemCopyCopy,
				_itemNameLabel = (itemCopy.nameLabel ~= nil and itemCopy.nameLabel) or "! ERROR !",
				_itemCallback = (itemCopy.OnSelect ~= nil and itemCopy.OnSelect) or "! ERROR !",
				lsmEntry = lsmEntry ~= nil and ZO_ShallowTableCopy(lsmEntry) or "! ERROR !",
				isBuildingSubmenu = isBuildingSubmenu,
				menuIndex = menuIndex,
			}
		end
	else
		if lib.debugLCM then
			errorNr = errorNr + 1
			d("<[LSM]ERROR " .. tos(errorNr) .."- ZO_Menu.items[".. tos(menuIndex).."].item is NIL!")
			LSM_Debug = LSM_Debug or {}
			LSM_Debug._ZO_MenuMappedToLSMEntriesERRORS = LSM_Debug._ZO_MenuMappedToLSMEntriesERRORS or {}
			LSM_Debug._ZO_MenuMappedToLSMEntriesERRORS[errorNr] = {
				_itemData = ZO_ShallowTableCopy(ZO_MenuItemData),
				isBuildingSubmenu = isBuildingSubmenu,
				menuIndex = menuIndex,
			}
		end
	end
	return lsmEntry
end


SecurePostHook("ShowMenu", function(owner)
	if lib.debugLCM then
		LSM_Debug = LSM_Debug or {}
		LSM_Debug._ZO_Menu_Items = LSM_Debug._ZO_Menu_Items or {}
	end

	if next(ZO_Menu.items) == nil then
		return false
	end
	local ownerName = (owner ~= nil and owner.GetName and owner:GetName()) or owner
	if lib.debugLCM then d("[LSM]SecurePostHook-ShowMenu-owner: " .. tos(ownerName)) end
	if owner == nil then return end

	local parent = owner.GetParent and owner:GetParent()
	local owningWindow = owner.GetOwningWindow and owner:GetOwningWindow()
	if lib.debugLCM then
		LSM_Debug._ZO_Menu_Items[ownerName] = {
			_owner = owner,
			_ownerName = ownerName,
			_parent = parent,
			_owningWindow = owningWindow,
		}
	end
	local isAllowed, _ = isSupportedInventoryRowPattern(owner, ownerName)
	if not isAllowed then
		if lib.debugLCM then d("<<ABORT! Not supported context menu owner: " ..tos(ownerName)) end
		return
	end

	local copyOfMenuItems =  ZO_ShallowTableCopy(ZO_Menu.items)
	if lib.debugLCM then
		LSM_Debug._ZO_Menu_Items[ownerName].ZO_MenuItems = copyOfMenuItems
	end

	--Build new LSM context menu now
	for idx, itemData in ipairs(copyOfMenuItems) do
		--[[
		--Do not clear it here as it would prevent usage of multiple addons using LSM!
		if idx == 1 then
			--d("> ~~ clearing LSM! ClearCustomScrollableMenu ~~~")
			--ClearCustomScrollableMenu()
		end
		]]

		local lsmEntry = mapZO_MenuItemToLSMEntry(itemData, idx)
		if lib.debugLCM then
			LSM_Debug._ZO_Menu_Items[ownerName].LSM_Items = LSM_Debug._ZO_Menu_Items[ownerName].LSM_Items or {}
			LSM_Debug._ZO_Menu_Items[ownerName].LSM_Items[#LSM_Debug._ZO_Menu_Items[ownerName].LSM_Items+1] = lsmEntry
		end

		if lsmEntry ~= nil and lsmEntry.name ~= nil then
			--Transfer the menu entry now to LibScrollableMenu instead of ZO_Menu
			--->pass in lsmEntry as additionlData (last parameter) so m_normalColor etc. will be applied properly
			AddCustomScrollableMenuEntry(lsmEntry.name, lsmEntry.callback, lsmEntry.entryType, lsmEntry.entries, lsmEntry)
		end
	end

	--Hide original ZO_Menu (and LibCustomMenu added entries) now -> Do this here AFTER preparing LSM entries,
	-- else the ZO_Menu.items and sub controls will be emptied already (nil)!
	if lib.debugLCM then d(">> ~~ Clear ZO_Menu ~~~") end
	ClearMenu()

	--Show the LSM contetx menu now with the mapped and added ZO_Menu entries
	if lib.debugLCM then d("< ~~ SHOWING LSM! ShowCustomScrollableMenu ~~~") end
	local isZOListDialogHidden = zoListDialog:IsHidden()
	ShowCustomScrollableMenu(owner, {
		sortEntries = 			false,
		visibleRowsDropdown = 	isZOListDialogHidden and 20 or 15,
		visibleRowsSubmenu = 	isZOListDialogHidden and 20 or 15,
	})
end)


------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------
--Load of the addon/library starts
local function onAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)

	local comboBoxContainer = CreateControlFromVirtual(MAJOR .. "_ContextMenu", GuiRoot, "ZO_ComboBox")
	--Create the local context menu object for the library's context menu API functions
	g_contextMenu = contextMenuClass:New(comboBoxContainer)
	lib.contextMenu = g_contextMenu
end
EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
EM:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, onAddonLoaded)


------------------------------------------------------------------------------------------------------------------------
-- Global library reference
------------------------------------------------------------------------------------------------------------------------
LibScrollableMenu = lib


----------------------------------------------------------------------------------------------------------------
-- Notes: | TODO:
------------------------------------------------------------------------------------------------------------------------



--[[

-------------------
WORKING ON - Current version:	2.0
-------------------
	- Fixed: width update of entries (no abbreviated texts)
	- Fixed: data.label (string or function returning a string)
	- Fixed: SetTimeout menus opening/closing
	- Added: Callback for dropdown menu added (pre-init!) "OnDropdownMenuAdded"


-------------------
TODO - To check (future versions)
-------------------
	1. Add comboBoxClass:AddMenuItems -> self:RefreshSortedItems()
	   Move processNameString to RefreshSortedItems
	2. Create 2 xml templates to use for anchoring based on scrollbar visibility
	3. Adjust AnchorToControl so submenus sit on edge of previous dropdown.
	4. Create new setup functions for each entry type to make them global -> Currently addLabel etc. are local
	   Check if options.XMLRowTemplates are working properly
	5. Check if callback OnDropdownMenuAdded can change the options of a dropdown pre-init
	6. Work on XML templates for dropdown skinning via the options of the dropdown (in general, for e.g. addons like PerfectPixel), e.g. options.XMLDropdownTemplates
	7. comboBoxClass:OnGlobalMouseUp(eventCode, ...) must close all submenus and the main menu (dropdown) of the ZO_ComboBox if we right click on the main comboBox to show a context menu there,
	   but it needs to stay opened if right clicking any menu or submenu entry (currently self:BypassOnGlobalMouseUp(...) returns true in that case)
	   Attention: zo_comboBox_base_hideDropdown(self) in self:HideDropdown() does NOT close the main dropdown if right clicked! Only for a left click... See ZO_ComboBox:HideDropdownInternal()
	8. Add options.disableFadeGradient: ZO_Scroll_SetUseFadeGradient(self.scrollControl,  not self.owner.disableFadeGradient )
]]
