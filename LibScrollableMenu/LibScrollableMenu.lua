if LibScrollableMenu ~= nil then return end -- the same or newer version of this lib is already loaded into memory

local lib = ZO_CallbackObject:New()
lib.name = "LibScrollableMenu"
local MAJOR = lib.name
lib.version = "1.8"

lib.data = {}

if not lib then return end

--Constant for the divider entryType
lib.DIVIDER = "-"
local libDivider = lib.DIVIDER

lib.HELPER_MODE_NORMAL = 0
lib.HELPER_MODE_LAYOUT_ONLY = 1 -- means only the layout of the dropdown will be altered, not the way it handles layering through ZO_Menus

--ZO_ComboBox changes with API101041 -> ZO_ComboBox uses a TLC for the dropdown now -> dropdownObject
--TODO: remove or make use of --> local APIVersion = GetAPIVersion()
--TODO: remove or make use of --> local apiVersionUpdate3_8 = 101041

--TODO: remove or make use of --> local isUsingDropdownObject = (APIVersion >= apiVersionUpdate3_8 and true) or false

--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
local dropdownControlPool = ZO_ControlPool:New("LibScrollableMenu_Keyboard_Template")


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
local CUSTOM_SCROLLABLE_MENU_NAME = MAJOR.."_CustomContextMenu"

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
--Saved indices of header and divider entries (upon showing the menu -> AddMenuItems)
--TODO: remove or make use of --v
local rowIndex = {
	[DIVIDER_ENTRY_ID] = {},
	[HEADER_ENTRY_ID] = {},
}

--Possible options passed in at the ScrollableHelper menus are:
local possibleLibraryOptions = {
	["visibleRowsDropdown"] = true,
	["visibleRowsSubmenu"] = true,
	["sortEntries"] = true,
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

--TODO: remove or make use of --v
--Tooltip anchors
local defaultTooltipAnchor = {TOPLEFT, 0, 0, BOTTOMRIGHT}

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

--Custom scrollable menu's ZO_ComboBox
local customScrollableMenuComboBox
local initCustomScrollableMenu, clearCustomScrollableMenu, addCustomScrollableMenuEntry,
		setCustomScrollableMenuOptions


local function submenuSortHelper(item1, item2, comboBoxObject)
    return ZO_TableOrderingFunction(item1, item2, "name", comboBoxObject.m_sortType, comboBoxObject.m_sortOrder)
end

local g_contextMenu
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

local  nextId = 1
local function setTimeout(callback , ...)
	local params = {...}
	if submenuCallLaterHandle ~= nil then clearTimeout() end
	submenuCallLaterHandle = MAJOR.."Timeout" .. nextId
	nextId = nextId + 1

	--Delay the submenu close callback so we can move the mouse above a new submenu control and keep that opened e.g.
	EM:RegisterForUpdate(submenuCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		clearTimeout()
		if callback then callback(unpack(params)) end
	end )
end


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

local function getContainerFromControl(control)
	local owner = control.m_owner
	return owner and owner.m_container
end

local function getOptionsForEntry(entry)
	local entrysComboBox = getContainerFromControl(entry)
	
	--[[ IsJustaGhost
		TODO: Would it be better to return {} if nil
		local options = entrysComboBox.options or {}
	]]
		
	return entrysComboBox ~= nil and entrysComboBox.options
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

-- TODO: Is this even needed?
local function setMaxMenuWidthAndRows()
	-- MAX_MENU_WIDTH is to set a cap on how wide text can make a menu. Don't want a menu being 2934 pixels wide.
	local uiWidth, uiHeight = GuiRoot:GetDimensions()
	MAX_MENU_WIDTH = uiWidth * 0.3
	MAX_MENU_ROWS = zo_floor((uiHeight * 0.5) / SCROLLABLE_ENTRY_TEMPLATE_HEIGHT)
--	/script d( GuiRoot:GetDimensions() * 0.2)
-- On my screen, at 0.2, this is currently 384
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
			
		local parent = control.m_dropdownObject.m_openingControl
		if parent then
			updateSubmenuNewStatus(parent)
		end
	end
end
-- m_dropdownObject.m_openingControl
local function clearNewStatus(control, data)
--d( '[LSM]clearNewStatus')
--d( 'data.isNew ' .. tostring(data.isNew))
	if data.isNew then
		-- Only directly change status on non-submenu entries. The are effected by child entries
		if data.entries == nil then
			data.isNew = false
			
			lib:FireCallbacks('NewStatusUpdated', data, control)
			
			control.m_dropdownObject:Refresh(data)
			
			local parent = control.m_dropdownObject.m_openingControl
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

local function addItems(self, items, templateTable)
--	d( '[LSM]addItems')
	local numItems = #items
	for i, item in pairs(items) do
		local isLastEntry = i == numItems
		
		local hasSubmenu = setItemEntryCustomTemplate(item, isLastEntry, templateTable)
		
		if hasSubmenu then
			item.hasSubmenu = true
			item.isNew = areAnyEntriesNew(item)
		end
		
		self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
	end
	
	return self.hasSubmenu
end

--TODO: remove or make use of --v
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

--TODO: fix
local function selectEntryAndResetLastSubmenuData(self, control)
	playSelectedSoundCheck(control)

	--Pass the entrie's text to the dropdown control's selectedItemText
	-- m_datais incorrect here
	
	ZO_ComboBoxDropdown_Keyboard.OnEntrySelected(self, control)
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

local function createScrollableComboBoxEntry(self, item, index, entryType)
	local entryData = ZO_EntryData:New(item)
	entryData.m_index = index
	entryData.m_owner = self.owner
	entryData.m_dropdownObject = self
	entryData:SetupAsScrollListDataEntry(entryType)
	return entryData
end

--------------------------------------------------------------------
-- DropdownObject
--------------------------------------------------------------------
local DropdownObject = ZO_ComboBoxDropdown_Keyboard:Subclass()

local SubmenuObject = DropdownObject:Subclass()

lib.DropdownObject = DropdownObject

-- DropdownObject:New( -- Just a reference for New
-- Available options are: See below at API function "AddCustomScrollableComboBoxDropdownMenu"
function DropdownObject:Initialize(parent, container, options, depth)
	depth = depth + 1 -- All top level comboboxs use 0 + 1. Submenus use parent.depth + 1
	self.depth = depth
	self.parent = parent
	
	local dropdownControl = dropdownControlPool:AcquireObject(depth)
    dropdownControl.object = self
	ZO_ComboBoxDropdown_Keyboard.Initialize(self, dropdownControl)

	self.optionsChanged = true
	self:UpdateOptions(options)
end

function DropdownObject:ComboBoxIntegration(comboBox)
	comboBox:SetDropdownObject(self)
		
	comboBox.AddItems = function(control, items)
		-- We are using this to add custom layout info to entries.
		addItems(control, items, self.XMLrowTemplates)
	end
	
	comboBox.ShowDropdownOnMouseUp = function(comboBox)
		d( '[LSM] comboBox.ShowDropdownOnMouseUp')
		-- Here we add the dropdown object on comboBox open.
		comboBox:SetDropdownObject(self)
		ZO_ComboBox.ShowDropdownOnMouseUp(comboBox)
	end
	
--[[
	comboBox.AddMenuItems = function(comboBox)
		comboBox:SetDropdownObject(self)
		ZO_ComboBox.AddMenuItems(comboBox)
	end
]]
end

function DropdownObject:AddItems(items)
	-- To be overwritten
end

function DropdownObject:GetOptions()
	return self.options
end

function DropdownObject:UpdateOptions(options)
	d( sfor('[LSM]UpdateOptionsoptionsChanged %s', tostring(self.optionsChanged)))

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

function DropdownObject:AddCustomEntryTemplate(entryTemplate, entryHeight, widthAdjust, setupFunction)
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

function DropdownObject:AddCustomEntryTemplates(options)
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
				setupEntry(control, data)
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
				setupEntry(control, data)
		--		self:SetupEntry(control, data, list)
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
				setupEntry(control, data)
				addDivider(control, data, list)
			end,
		},
		[HEADER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxHeaderEntry',
			rowHeight = HEADER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				setupEntry(control, data)
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
				setupEntry(control, data)
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

--TODO: remove or make use of --> local mouseExitRefCounts = {}
--Narration
function DropdownObject:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
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

function DropdownObject:OnMouseEnterEntry(control)
	self.control:BringWindowToTop()
	d( '[LSM]DropdownObject:OnMouseEnterEntry')

	ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry(self, control)
	
	local data = getControlData(control)

	local hasSubmenu = control.hasSubmenu or data.entries ~= nil

	self:Narrate("OnEntryMouseEnter", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseEnter', data, control)
	
	clearTimeout()
	if hasSubmenu then
		control.hasSubmenu = hasSubmenu
		self:ShowSubmenu(control)
	end
	
	clearNewStatus(control, data)
end

function DropdownObject:OnMouseExitEntry(control)
	d( '[LSM]DropdownObject:OnMouseExitEntry')
	
	ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry(self, control)
	
	local data = getControlData(control)
	local hasSubmenu = control.hasSubmenu or data.entries ~= nil
	
	self:Narrate("OnEntryMouseExit", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseExit', data, control)
	
--	if self:IsEnteringSubmenu() or self:IsOwnedByDopdown(control.m_dropdownObject) then
--d( '- - - IsEnteringSubmenu ' .. tostring(self:IsEnteringSubmenu(control)))

	-- over self / over submenu / close
	
	d( 'IsMouseOverControl ' .. tostring(self:IsMouseOverControl()))
	
	if not MouseIsOver(control) then
	else
	end
	
	if self:IsEnteringSubmenu(control) then
		-- Keep open
		clearTimeout()
		return
--	elseif g_contextMenu.m_isDropdownVisible and not g_contextMenu:IsEnteringSubmenu(control) then
	elseif g_contextMenu:IsEnteringSubmenu(control) then
		clearTimeout()
		return
	elseif self.childMenu then
		clearTimeout()
		self.childMenu:HideSubmenu()
	end
	
	if not lib.GetPersistentMenus() then
		local function onMouseExitTimeout(...)
			self:OnMouseExitTimeout(control)
		end
		
		setTimeout(onMouseExitTimeout)
	end
	
	if g_contextMenu.m_isDropdownVisible then
		g_contextMenu:HideContextMenu()
	end
	
end

function DropdownObject:OnEntrySelected(control, button, upInside)
--	d( '[LSM]DropdownObject:OnEntrySelected IsUpInside ' .. tostring(upInside) .. ' Button ' .. tostring(button))
	
	if upInside then
		local data = getControlData(control)
		local hasSubmenu = control.hasSubmenu or data.entries ~= nil
	
		if button == MOUSE_BUTTON_INDEX_LEFT then
			self:Narrate("OnEntrySelected", control, data, hasSubmenu)
			--d( "lib:FireCallbacks('EntryOnSelected)")
			lib:FireCallbacks('EntryOnSelected', data, control)

			--	d( dataEntry.entries)
			if hasSubmenu then
				return true
			elseif control.m_checkbox then
				playSelectedSoundCheck(control)
				ZO_CheckButton_OnClicked(control.m_checkbox)
				return true
			else
				selectEntryAndResetLastSubmenuData(self, control)
			end
		else -- right-click
			if data.contextMenuCallback then
				data.contextMenuCallback(control)
			end
		end
	end
end

function DropdownObject:OnMouseExitTimeout(control)
 d( "[LSM]DropdownObject:OnMouseExitTimeout")
	local moc = moc()
	
	
	if self:IsEnteringSubmenu(control) then
		-- Keep open
	elseif moc.GetType == nil or moc:GetType() ~= CT_SLIDER then
	end
	
	if not self:IsMouseOverControl() then
		self:HideSubmenu()
	else
	--	d( '- - OnMouseExitEntry  no childMenu. Hide self???')
	end
end

function DropdownObject:ShowSubmenu(parentControl)
	local submenu = self.childMenu

	
	if not self.childMenu then
		self.childMenu = SubmenuObject:New(self, parentControl, self.options, self.depth)
	end
	
	self.childMenu:ShowDropdown(parentControl)
end

--[[
function DropdownObject:SetHidden(hidden)
	ZO_ComboBoxDropdown_Keyboard.SetHidden(self, hidden)
--	self:HideSubmenu()
end
function DropdownObject:HideSubmenu(eventCode, button, ctrl, alt, shift, command)
	if not button or button == MOUSE_BUTTON_INDEX_LEFT then
		
		local submenu = self.childMenu
		if submenu then
			submenu:HideDropdown()
		end
	--	self:SetHidden(true)
	
	else
	end
end

]]

function DropdownObject:HideSubmenu(eventCode, button, ctrl, alt, shift, command)
	if not button or button == MOUSE_BUTTON_INDEX_LEFT then
	else
	end

	if self.childMenu then
		self.childMenu:HideSubmenu()
		if not self.childMenu:IsMouseOverControl() then
			self.childMenu:HideDropdown()
		end
		-- else hide parents?
		-- hide root up ?
	end
end

function DropdownObject:IsEnteringSubmenu(control)
	local submenu = self.childMenu
	if submenu then
		if submenu:IsMouseOverControl() then
			return true
		end
	end
	return false
end

function DropdownObject:HideDropdown(submenu)
	local submenu = self.childMenu
	if submenu then
		submenu:HideDropdown()
	end
	self:SetHidden(true)
end

--[[

function DropdownObject:IsOwnedByDopdown(submenu)
	return self == submenu
end

function DropdownObject:Show(...)
	ZO_ComboBoxDropdown_Keyboard.Show(self, ...)
	self:SetVisible(true)
end

]]

--------------------------------------------------------------------
-- SubmenuObject
--------------------------------------------------------------------
function SubmenuObject:Initialize(parentMenu, control, options, parentDepth)
	DropdownObject.Initialize(self, parentMenu, control, options, parentDepth)
	self.owner = parentMenu.owner
	self.parentMenu = parentMenu
	self.depth = parentDepth + 1
	self.m_sortedItems = {}
	
	self.isSubmenu = true

	self.m_isDropdownVisible = false
	self.m_preshowDropdownFn = nil
	self.m_name = self.control:GetName()
end

function SubmenuObject:OnGlobalMouseUp(eventCode, button)
    if self:IsDropdownVisible() then
        if button == MOUSE_BUTTON_INDEX_LEFT and not self:IsMouseOverControl() then
            self:HideDropdown()
		else
        end
    else
		if button == MOUSE_BUTTON_INDEX_RIGHT then
			-- right-click
			if data.contextMenuCallback then
				data.contextMenuCallback(control)
			end
		end

        if self.control:IsHidden() then
            self:HideDropdown()
        else
            -- If shown in ShowDropdownInternal, the global mouseup will fire and immediately dismiss the combo box. We need to
            -- delay showing it until the first one fires.
      --      self:ShowDropdownOnMouseUp()
        end
    end
end

function SubmenuObject:AnchorToControl(parentControl)
	local width, height = GuiRoot:GetDimensions()
	
	local offsetX = 0
	self.control:ClearAnchors()
	
	local right = self.parent.anchorPoint or false
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

function SubmenuObject:OnEntrySelected(control, button, upInside)
--	d( string.format('SubmenuObject:OnEntrySelected Button %s upInside %s', tostring(button), tostring(upInside)))

	local data = getControlData(control)
	if data and upInside then
	--TODO: remove or make use of --> 	local hasSubmenu = control.hasSubmenu or data.entries ~= nil
	
		if button == MOUSE_BUTTON_INDEX_LEFT then
			self:SetSelected(control.m_data.m_index)
			-- multi-select dropdowns will stay open to allow for selecting more entries
			if not self.owner.m_enableMultiSelect then
				self.owner:HideDropdown()
			end
		else
			-- Context menu opens here
			
			if data.contextMenuCallback then
				data.contextMenuCallback(control)
			end
		end
	end
end

function SubmenuObject:SetSelected(index, ignoreCallback)
	local item = self.m_sortedItems[index]
	if self.owner then
		self.owner:SelectItem(item, ignoreCallback)
	end
end

function SubmenuObject:IsDropdownVisible()
	return self.m_isDropdownVisible
end

function SubmenuObject:SetVisible(visible)
	self.m_isDropdownVisible = visible
end

function SubmenuObject:HideDropdown()
    if self:IsDropdownVisible() then
        self:HideDropdownInternal()
    end
end

function SubmenuObject:HideDropdownInternal()
	d( '[LSM]SubmenuObject:HideDropdownInternal')
	self:SetHidden(true)
	self:SetVisible(false)
	if self.onHideDropdownCallback then
		self.onHideDropdownCallback()
	end
end

function SubmenuObject:SetHidden(hidden)
	ZO_ComboBoxDropdown_Keyboard.SetHidden(self, hidden)
	self.control:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)	
	
	--[[
	local submenu = self.childMenu
	if submenu then
		local childMenu = submenu.childMenu
		-- Recursive hiding
		if childMenu then
			childMenu:SetHidden(hidden)
		end
	--	submenu:SetHidden(hidden)
	end
	]]
	
end

function SubmenuObject:HideSubmenu(eventCode, button, ctrl, alt, shift, command)
	if not button or button == MOUSE_BUTTON_INDEX_LEFT then
		local childMenu = self.childMenu
		if childMenu then
			-- Recursive hiding
			childMenu:HideSubmenu()
		end
		self:SetHidden(true)
	else
	end

end

function SubmenuObject:ShowInternal(parentControl)
	self.m_openingControl = parentControl
	local owner = parentControl.m_owner
	if owner then
		self.owner = owner
		
		self:Show(owner, self.m_sortedItems, 20, self.owner.m_height, self.owner:GetSpacing())
		
		self.control:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self:OnGlobalMouseUp(...) end)
		
		self:Narrate("OnSubMenuShow", parentControl, nil, nil, self.anchorPoint)
		lib:FireCallbacks('SubmenuOnShow', self)
		
		self:AnchorToControl(parentControl)
		self:SetVisible(true)
		self.control:SetHidden(false)
		self.control:BringWindowToTop()
	end
end

function SubmenuObject:ShowDropdown(parentControl)
	local data = ZO_ScrollList_GetData(parentControl)
	local items =  getValueOrCallback(data.entries, data)
	self:AddItems(items)
	
	self:ShowInternal(parentControl)
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
        local entryType = DEFAULT_ENTRY_ID
		local widthAdjust = 0
        if self.customEntryTemplateInfos and item.customEntryTemplate then
            local templateInfo = self.customEntryTemplateInfos[item.customEntryTemplate]
            if templateInfo then
                entryType = templateInfo.typeId
                entryHeight = templateInfo.entryHeight
                widthAdjust = templateInfo.widthAdjust or 0
		
				-- If it is new, we need to add the height again for the icon width.
				--TODO: need to think about checking for other icon too.
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

    -- Allow the dropdown to automatically widen to fit the widest entry, but
    -- prevent it from getting any skinnier than the container's initial width
    local totalDropDownWidth = largestEntryWidth + ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2 + ZO_SCROLL_BAR_WIDTH
    if totalDropDownWidth > minWidth then
        self.control:SetWidth(totalDropDownWidth)
    else
        self.control:SetWidth(minWidth)
    end

    allItemsHeight = allItemsHeight + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2)

    local desiredHeight = maxHeight
    if allItemsHeight < desiredHeight then
        desiredHeight = allItemsHeight
    end

    self.control:SetHeight(desiredHeight)
    ZO_ScrollList_SetHeight(self.scrollControl, desiredHeight)

    ZO_ScrollList_Commit(self.scrollControl)
end

function SubmenuObject:AddItems(items)
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)
	
	local numItems = #items
	
	for i = 1, numItems do
		local item = items[i]
		item.m_owner = self
		item.parent = parentControl
		local isLastEntry = i == numItems
		
		local hasSubmenu = setItemEntryCustomTemplate(item, isLastEntry, self.XMLrowTemplates)
		
		if hasSubmenu then
			item.hasSubmenu = true
			item.isNew = areAnyEntriesNew(item)
		end
		table.insert(self.m_sortedItems, item)
	end
end

function SubmenuObject:AddItem(itemEntry, updateOptions)
    table.insert(self.m_sortedItems, itemEntry)
    
    if updateOptions ~= ZO_COMBOBOX_SUPPRESS_UPDATE then
        self:UpdateItems()
    end

 --   self:OnItemAdded()
end

function SubmenuObject:UpdateItems()
	if self.owner then
		if self.m_sortOrder and self.m_sortsItems then
			table.sort(self.m_sortedItems, function(item1, item2) return submenuSortHelper(item1, item2, self.owner) end)
		end
		
		if self.m_openingControl then
			if self:IsDropdownVisible() then
				self:ShowDropdown(self.m_openingControl)
			end
		end
	end
	
end

--------------------------------------------------------------------
-- ContextMenu
--------------------------------------------------------------------
local uiWidth, uiHeight = GuiRoot:GetDimensions() -- < just testing v
local DEFAULT_HEIGHT = uiHeight / 2
local DEFAULT_FONT = "ZoFontGame"
local DEFAULT_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
local DEFAULT_TEXT_HIGHLIGHT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))

local ContextMenuObject = SubmenuObject:MultiSubclass(ZO_ComboBox_Base)

function ContextMenuObject:Initialize(depth)
	d( '[LSM]ContextMenuObject:Initialize')
	local control = dropdownControlPool:AcquireObject(depth)
	ZO_ComboBoxDropdown_Keyboard.Initialize(self, control)
    control.object = self
	
	self.control = control
--	self.owner = parent.owner
--	self.parent = parent
	self.depth = depth
	self.data = {}
	self.m_sortedItems = {}
	
	self:SetHeight(DEFAULT_HEIGHT)
	self.m_font = DEFAULT_FONT
	self.m_normalColor = DEFAULT_TEXT_COLOR
	self.m_highlightColor = DEFAULT_TEXT_HIGHLIGHT
	self.m_containerWidth = 300
	self.m_isDropdownVisible = false
	self.m_preshowDropdownFn = nil
	self.m_name = control:GetName()
	self.spacing = 0
	
	self.optionsChanged = true
	self:UpdateOptions(options)
	
	control:SetHeight(0)
end

function ContextMenuObject:AnchorToControl(parentControl)
	local width, height = GuiRoot:GetDimensions()
	
	local offsetX = 0
	self.control:ClearAnchors()
	
	local right = false
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
end

function ContextMenuObject:SetHeight(height)
	self.m_height = height or DEFAULT_HEIGHT
end

function ContextMenuObject:ShowContextMenu(parentControl)
	self:AddItems(self.data)
	
	self:ShowInternal(parentControl)
end

function ContextMenuObject:GetSortedItems()
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)
	local data = ZO_ScrollList_GetData(parentControl)
	
	itemTable = itemTable or getValueOrCallback(data.entries, data)
	local numItems = #itemTable
	for i, item in pairs(itemTable) do
		item.m_owner = self
		item.parent = parentControl
		local isLastEntry = i == numItems
		
		local hasSubmenu = setItemEntryCustomTemplate(item, isLastEntry, self.XMLrowTemplates)
		
		if hasSubmenu then
			item.hasSubmenu = true
			item.isNew = areAnyEntriesNew(item)
		end
		table.insert(self.m_sortedItems, item)
	end
	return self.m_sortedItems
end

function ContextMenuObject:HideContextMenu(eventCode, button, ctrl, alt, shift, command)
	d( '[LSM]ContextMenuObject:HideContextMenu')
	--[[
	local moc = moc()
	
	if eventCode then
		if button == MOUSE_BUTTON_INDEX_LEFT then
			if moc:GetOwningWindow() ~= self.control then
				self.control:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)
				
				local childMenu = self.childMenu
				if childMenu then
					-- Recursive hiding
					childMenu:HideSubmenu()
				end
				self:SetHidden(true)
			end
		else
		end
	else
		if moc:GetOwningWindow() ~= self.control then
			self:SetHidden(true)
		end
	end
	]]
end

function ContextMenuObject:ClearItems()
--	ZO_ComboBox_HideDropdown(self:GetContainer()) Need to use another hide self
	ZO_ClearNumericallyIndexedTable(self.data)
	self:SetSelectedItemText("")
	self.m_selectedItemData = nil
	self:OnClearItems()
end

function ContextMenuObject:SetupEntryLabel(labelControl, data)
	labelControl:SetText(data.name)
	labelControl:SetFont(self.owner:GetDropdownFont())
	local color = self.owner:GetItemNormalColor(data)
	labelControl:SetColor(color:UnpackRGBA())
	labelControl:SetHorizontalAlignment(self.horizontalAlignment)
end

function ContextMenuObject:SetupEntryBase(control, data, list)
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
--	control:SetHidden(false)
end

function ContextMenuObject:SetupEntry(control, data, list)
	self:SetupEntryBase(control, data, list)

	control.m_label = control:GetNamedChild("Label")
--	self:SetupEntryLabel(control.m_label, data)
end

function ContextMenuObject:IsItemSelected(item)
	
	return false
end

function ContextMenuObject:AddItem(itemEntry, updateOptions)
    table.insert(self.data, itemEntry)
    
    if updateOptions ~= ZO_COMBOBOX_SUPPRESS_UPDATE then
        self:UpdateItems()
    end

 --   self:OnItemAdded()
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

	if comboBoxContainer.comboBox == nil then
--		comboBoxContainer.comboBox = comboBoxControl
	end
	if comboBoxContainer.dropdown == nil then
--		comboBoxContainer.dropdown = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
	end
	
--	d( parent:GetName())


	--Add a new scrollable menu helper
	comboBoxContainer.m_comboBox.isTopLevel = true
--	comboBoxContainer.dropdown.m_submenu = lib.submenu
	-- Add
	local depth = 1
	local dropdownObject = DropdownObject:New(parent, comboBoxContainer, options, 1)
	
	local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
	dropdownObject:ComboBoxIntegration(comboBox)
	
	return dropdownObject
end
--TODO: remove or make use of --v
local addCustomScrollableComboBoxDropdownMenu = AddCustomScrollableComboBoxDropdownMenu


--[Custom scrollable context menu at any control]
--Add a scrollable menu to any control (not only a ZO_ComboBox), e.g. to an inventory row
--by creating a DUMMY ZO_ComboBox, adding the ScrollHelper class to it and use it
----------------------------------------------------------------------
--Function to check for global mouse down -> to close the custom scrollable context menus if clicked somwhere else
--> Was changed from mouseUp to mouseDown so holding a mouse down to drag a control will close the menus too
local mouseDownRefCounts = {}
local function onGlobalMouseDown()
	local refCount = mouseDownRefCounts[customScrollableMenuComboBox]
--d("[LSM]OnGlobalMouseUp-refCount: " ..tos(refCount))
	if refCount ~= nil then
		local moc = moc()
		local owningWindowIsNotZO_Menus = moc:GetOwningWindow() ~= ZO_Menus
		local owner = moc.m_owner
		local isOwnerNil = owner == nil
		local container = getContainerFromControl(moc)
		local parent = moc:GetParent()
		local isScrollbar = moc.scrollbar ~= nil or (parent ~= nil and parent.scrollbar ~= nil)

--d("[onGlobalMouseDown]owningWindowIsNotZO_Menus: " ..tos(owningWindowIsNotZO_Menus) .. ", isOwnerNil: " ..tos(isOwnerNil) .. ", container: " .. tos(container ~= nil and container:GetName()) .. ", contextMenuCtrl: " ..tos(customScrollableMenuComboBox:GetName()))
		--Scrollbar and the onwing window is ZO_Menus?
		if isScrollbar and not owningWindowIsNotZO_Menus then
			return
		end
		--Or the owning window ZO_Menus (the onwer of our DUMMY ZO_ComboBox for the custom scrollable context menu)
		--or is the m_owner variable provided (tells us we got a ScrollHelper entry here -> main menu or submenu)
		if (owningWindowIsNotZO_Menus or isOwnerNil or (container ~= nil and container ~= customScrollableMenuComboBox)) then
--d(">is no main menu entry, maybe a Submenu entry?")
			if not owningWindowIsNotZO_Menus and not isOwnerNil and owner.m_submenu ~= nil then
--d(">>isSubmenu entry")
				return
			end
			refCount = refCount - 1
			mouseDownRefCounts[customScrollableMenuComboBox] = refCount
			if refCount <= 0 then
				clearCustomScrollableMenu = clearCustomScrollableMenu or ClearCustomScrollableMenu
				clearCustomScrollableMenu()
			end
		end
	end
end

--If no ZO_ComboBox dummy control was created yet: Do so now
local function initCustomScrollMenuControl(parent, options)
	if customScrollableMenuComboBox == nil then
		initCustomScrollableMenu = initCustomScrollableMenu or InitCustomScrollableMenu
		return initCustomScrollableMenu(parent, options)
	else
		if options ~= nil then
			setCustomScrollableMenuOptions = setCustomScrollableMenuOptions or SetCustomScrollableMenuOptions
			setCustomScrollableMenuOptions(options)
		end
	end
	
--	g_contextMenu:AddCustomEntryTemplates(options)
end

--Initialize the scrollable context menu
function InitCustomScrollableMenu(parent, options)
	parent = parent or moc()
--d("[LSM]InitCustomScrollableMenu-parent: " ..tos(parent:GetName()))
	if parent == nil then return end

	-- Initialize in one place. To simplify setup not depending on what method is used
	-->Creates one dummy ZO_ComboBox which can be used to show the context menu via it's "opened dropdown", and hiding the combobox borders etc. itsself
	createNewCustomScrollableComboBox()

	lib.customContextMenu = customScrollableMenuComboBox

	local scrollHelper = addCustomScrollableComboBoxDropdownMenu(parent, customScrollableMenuComboBox, options or defaultContextMenuOptions)
	customScrollableMenuComboBox.scrollHelper = scrollHelper

	scrollHelper.optionsChanged = options ~= nil
	scrollHelper:InitContextMenuValues()

	return scrollHelper
end

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
		g_contextMenu:UpdateOptions(options)
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
	g_contextMenu:HideContextMenu()
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
	setMaxMenuWidthAndRows()

	g_contextMenu = ContextMenuObject:New(1)
	lib.contextMenu = g_contextMenu

	--Other events
	EM:RegisterForEvent(lib.name, EVENT_SCREEN_RESIZED, setMaxMenuWidthAndRows)
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
