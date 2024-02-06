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
local APIVersion = GetAPIVersion()
local apiVersionUpdate3_8 = 101041
local isUsingDropdownObject = (APIVersion >= apiVersionUpdate3_8 and true) or false

--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--[[
local function poolFactory(objectPool)
	-- (name, templateName, objectPool, parentControl)
	local newControl = ZO_ObjectPool_CreateControl("LibScrollableMenu_Keyboard_Template", objectPool, GuiRoot)
	return newControl
end
local dropdownObjectPool = ZO_ObjectPool:New(poolFactory, ZO_ObjectPool_DefaultResetObject)
]]
local dropdownObjectPool = ZO_ControlPool:New("LibScrollableMenu_Keyboard_Template")
local comboBoxtPool = ZO_ControlPool:New("LibScrollableMenu_ComboBox_TLC")


--local speed up variables
local EM = EVENT_MANAGER
local SNM = SCREEN_NARRATION_MANAGER

local tos = tostring
local sfor = string.format
local tins = table.insert

--Sound settings
local origSoundComboClicked = SOUNDS.COMBO_CLICK
local soundComboClickedSilenced = SOUNDS.NONE

--Submenu settings
local ROOT_PREFIX = MAJOR.."Sub"
local ROOT_PREFIX = MAJOR.."_ComboBox_TLC"
local SUBMENU_SHOW_TIMEOUT = 350
local submenuCallLaterHandle
local nextId = 1

--Custom scrollable menu settings (context menus e.g.)
local CUSTOM_SCROLLABLE_MENU_NAME = MAJOR.."_CustomContextMenu"

--Menu settings (main and submenu)
local MAX_MENU_ROWS = 25
local MAX_MENU_WIDTH
local DEFAULT_VISIBLE_ROWS = 10
local DEFAULT_SORTS_ENTRIES = true --sort the entries in main- and submenu lists

--Entry type settings
local DIVIDER_ENTRY_HEIGHT = 7
local HEADER_ENTRY_HEIGHT = 30
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT -- same as in zo_comboBox.lua: 25
local ICON_PADDING = 20
local PADDING = GetMenuPadding() / 2 -- half the amount looks closer to the regular dropdown
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
local allowedEntryTypesForContextMenu = {
	[lib.LSM_ENTRY_TYPE_NORMAL] = true,
	[lib.LSM_ENTRY_TYPE_DIVIDER] = true,
	[lib.LSM_ENTRY_TYPE_HEADER] = true,
	[lib.LSM_ENTRY_TYPE_CHECKBOX] = true,
}

--Make them accessible for the ScrollableDropdownHelper:New options table -> options.XMLRowTemplates
lib.scrollListRowTypes = {
	ENTRY_ID = ENTRY_ID,
	LAST_ENTRY_ID = LAST_ENTRY_ID,
	DIVIDER_ENTRY_ID = DIVIDER_ENTRY_ID,
	HEADER_ENTRY_ID = HEADER_ENTRY_ID,
	SUBMENU_ENTRY_ID = SUBMENU_ENTRY_ID,
	CHECKBOX_ENTRY_ID = CHECKBOX_ENTRY_ID,
}
--Saved indices of header and divider entries (upon showing the menu -> AddMenuItems)
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


--------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------

-- >> data, dataEntry
local function getControlData(control)
	local data = control.m_data
	local dataEntry = {} -- To prevent indexing a nil value
	
	if data.dataSource then
		dataEntry = data:GetDataSource()
	end
	
	return data, dataEntry
end

-- >> template, height, setupFunction
local function getTemplateData(entryType, template)
	local templateDataForEntryType = template[entryType]
	return templateDataForEntryType.template, templateDataForEntryType.rowHeight, templateDataForEntryType.setupFunc
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

local function onMouseExitTimeout()
--d("[LSM]onMouseExitTimeout")
	local control = moc()
	local name = control and control:GetName()
	if name and zo_strfind(name, ROOT_PREFIX) == 1 then
		--TODO: check for matching depth??
	else
		--Are we NOT above the scrollbar of the scrolhelper? Close the submenu then on mouse exit
		if control.GetType == nil or control:GetType() ~= CT_SLIDER then
			lib.submenu:Clear()
		end
	end
end

-- TODO: Decide on what to pass, in LibCustomMenus it always passes ZO_Menu as the 1st parameter
-- but since we don't use that there are a few options:
--    1) Always pass the root dropdown and never a submenu dropdown
--    2) Pass root dropdown for initial entries and the appropriate submenu dropdown for the rest
--    3) Don't pass any dropdown control or object (!!CURRENTLY USED!!)
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

local function getSubmenuFromControl(control)
	local owner = control.m_owner or {}
--	return owner and owner.m_submenu
	
	LSM_DEBUG.owners = LSM_DEBUG.owners or {}
	
	if not LSM_DEBUG.owners[owner] then
		LSM_DEBUG.owners[owner] = owner
	end
	return owner.m_submenu
end

local function getScrollHelperObjectFromControl(control)
	--Submenu entry?
	local submenu = getSubmenuFromControl(control)
	if submenu ~= nil then
		return submenu.scrollHelper
	else
		--Normal menu entry
		local container = getContainerFromControl(control)
		if container ~= nil then
			return container.parentScrollableDropdownHelper or container.scrollHelper
		else
			if control == lib.customContextMenu then
				return control.scrollHelper
			end
		end
	end
	return
end

local function getDropdownObjectFromControl(control)
	--Submenu entry?
	local submenu = getSubmenuFromControl(control)
	if submenu ~= nil then
		return submenu.m_dropdownObject
	else
		--Normal menu entry
		local container = getContainerFromControl(control)
		if container ~= nil then
			return container.parentScrollableDropdownHelper or container.m_dropdownObject
		else
			if control == lib.customContextMenu then
				return control.m_dropdownObject
			end
		end
	end
	return
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
--	/script d(GuiRoot:GetDimensions() * 0.2)
-- On my screen, at 0.2, this is currently 384
end

--Get currently shown entryType in the dropdown, to calculate the height properly
local function getVisibleEntryTypeControls(visibleRows, entryType)
	local highest = 0
	--Filled at function ScrollableDropdownHelper:AddMenuItems(), CreateEntry
	for k, index in ipairs(rowIndex[entryType]) do
		if index < visibleRows then
			highest = highest + 1
		end
	end
	return highest
end

--Get currently shown divider and header indices of the menu entries
local function getVisibleHeadersAndDivider(visibleItems)
	return getVisibleEntryTypeControls(visibleItems, HEADER_ENTRY_ID), getVisibleEntryTypeControls(visibleItems, DIVIDER_ENTRY_ID)
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


local function getParent(control)
	if control.m_parent then
		return control.m_parent
	end
	local m_submenu = getSubmenuFromControl(control)
	if m_submenu then
		return getParent(control)
	end
end

-- This works up from the mouse-over entry's submenu up to the dropdown, 
-- as long as it does not run into a submenu still having a new entry.
local function updateSubmenuNewStatus(control)
	if control then
		-- reverse parse
		local isNew = false
			d( 'updateSubmenuNewStatus ' .. control:GetName())
		
		local data, dataEntry = getControlData(control)
		local submenuEntries = dataEntry.entries or {}
		
		-- We are only going to check the current submenu's entries, not recursively
		-- down from here since we are working our way up until we find a new entry.
		for k, subentry in ipairs(submenuEntries) do
			if getIsNew(subentry) then
				isNew = true
			end
		end
		-- Set flag on submenu
		dataEntry.isNew = isNew
		if not isNew then
			control.m_dropdownObject:Refresh(dataEntry)
			
			if control.m_owner then
				local m_submenu = getSubmenuFromControl(control)
				if m_submenu then
					updateSubmenuNewStatus(m_submenu.m_parent)
				end
			end
		end
	end
end

local function clearNewStatus(control, data)
	if data.isNew then
		if data.entries == nil then
			data.isNew = false
			control.m_dropdownObject:Refresh(data)
			
			lib:FireCallbacks('NewStatusUpdated', data, control)
			
			if control.m_owner then
				local m_submenu = getSubmenuFromControl(control)
				if m_submenu then
					updateSubmenuNewStatus(m_submenu.m_parent)
				end
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
--	d( 'addItems')
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
	
	self:UpdateItems()
	return self.hasSubmenu
end

local function anchorCustomContextMenuToMouse(menuToAnchor)
	if menuToAnchor == nil then return end
	local x, y = GetUIMousePosition()
	local width, height = GuiRoot:GetDimensions()

	menuToAnchor:ClearAnchors()

--d("[LSM]anchorCustomContextMenuToMouse-width: " ..tos(menuToAnchor:GetWidth()) .. ", height: " ..tos(menuToAnchor:GetHeight()))

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
local function selectEntryAndResetLastSubmenuData(control)
	playSelectedSoundCheck(control)

	--Pass the entrie's text to the dropdown control's selectedItemText
	-- m_datais incorrect here
	control.m_owner:SetSelected(control.m_data.m_index, ignoreCallback)
	lib.submenu.lastClickedEntryWithSubmenu = nil
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
--d("["..MAJOR.."]AddNewChatNarrationText-stopCurrent: " ..tostring(stopCurrent) ..", text: " ..tostring(newText))
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
--d("[LSM]onUpdateDoNarrate-updaterName: " ..tos(updaterName))
    EM:UnregisterForUpdate(updaterName)
    if isAccessibilityUIReaderEnabled() == false or callbackFunc == nil then return end
    delay = delay or 1000
    EM:RegisterForUpdate(updaterName, delay, function()
        if isAccessibilityUIReaderEnabled() == false then EM:UnregisterForUpdate(updaterName) return end
--d(">>>calling func delayed now!")
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
local hookedLSM_COMBO_BOX_DROPDOWN_KEYBOARD = false

--------------------------------------------------------------------
-- ScrollableDropdownHelper
--------------------------------------------------------------------
local getScrollableSubmenu

local ScrollableDropdownHelper = ZO_ComboBoxDropdown_Keyboard:Subclass()
lib.ScrollableDropdownHelper = ScrollableDropdownHelper
-- ScrollableDropdownHelper:New( -- Just a reference for New
-- Available options are: See below at API function "AddCustomScrollableComboBoxDropdownMenu"
function ScrollableDropdownHelper:Initialize(parent, control, options, isSubMenum_dropdownObject)
	local dropdownObject, depth = dropdownObjectPool:AcquireObject(self.depth)
	self.depth = depth
	ZO_ComboBoxDropdown_Keyboard.Initialize(self, dropdownObject)
	
	
--	d( control:GetName())
	
	local comboBox = control.comboBox
	local dropdown = control.dropdown
	dropdown:SetDropdownObject(self)
--	control.m_dropdownObject = self
	
	self.parent = parent
	self.comboBox = comboBox
	
	self.optionsChanged = true
--	self:UpdateOptions(options)

	-- this will add custom and default templates to self.XMLrowTemplates the same way dataTypes were created before.
	self:AddCustomEntryTemplates(options)
	if dropdown and not self.dropdown then
		self.dropdown = dropdown
		
		dropdown.AddItems = function(control, items)
			self.hasSubmenu = addItems(control, items, self.XMLrowTemplates)
		end

		ZO_PreHook(dropdown, 'HideDropdownInternal', function(object)
			d( 'HideDropdownInternal')
			local submenu = object.m_submenu
			if submenu then
			d( '- - - submenu.comboBox ' .. tostring(self:IsOwnedByComboBox(submenu.comboBox)))
				if submenu.m_dropdownObject then
	d( 'IsUpInside ' .. tostring(submenu.m_dropdownObject:IsOwnedByComboBox(self.comboBox)))
			--		return submenu.m_dropdownObject:IsOwnedByComboBox(submenu.comboBox)
				end
			end
	--		return self:IsOwnedByComboBox(self.comboBox)
		end)
	end
end

function ScrollableDropdownHelper:AddItems(items)
	self.dropdown:AddItems(items)
end

function ScrollableDropdownHelper:UpdateOptions(options)
	--d(sfor('[LSM]UpdateOptionsoptionsChanged %s', tostring(self.optionsChanged)))

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

	local comboBox = control.comboBox
	comboBox.m_comboBox:SetSortsItems(self.sortsItems)

	self.options = options
	self.control.options = options
	self.narrateData = narrateData
	self.control.narrateData = narrateData
end

function ScrollableDropdownHelper:AddCustomEntryTemplates(options)
	-- checkbox wrappers
	local function setupEntry(control, data)
		control.m_owner = self.owner
		control.m_data = data
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

	-- was planing on moving ScrollableDropdownHelper:AddDataTypes() and 
	-- all the template stuff wrapped up in here
	local defaultXMLTemplates  = {
		[ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntry(control, data, list)
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
			setupFunc = function(control, data, list)
				self:SetupEntry(control, data, list)
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
				self:SetupEntry(control, data, list)
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

function ScrollableDropdownHelper:UpdateIcons(data)
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

	local multiIconContainerCtrl = self.m_iconContainer
	local multiIconCtrl = self.m_icon

	local parentHeight = multiIconCtrl:GetParent():GetHeight()
	local iconHeight = parentHeight
	-- This leaves a padding to keep the label from being too close to the edge
	local iconWidth = visible and iconHeight or WITHOUT_ICON_LABEL_DEFAULT_OFFSETX

	multiIconCtrl:ClearIcons()
	if visible == true then
		self.m_icon.data = self.m_icon.data or {}

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

--Narration
function ScrollableDropdownHelper:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	local narrateData = self.narrateData
--d("[LSM]Narrate-"..tos(eventName) .. ", narrateData: " ..tos(narrateData))
	if eventName == nil or isAccessibilityUIReaderEnabled() == false or narrateData == nil then return end
	local narrateCallbackFuncForEvent = narrateData[eventName]
	if narrateCallbackFuncForEvent == nil or type(narrateCallbackFuncForEvent) ~= "function" then return end

	local eventCallbackFunctionsSignatures = {
		["OnDropdownMouseEnter"] = function() return self, ctrl end,
		["OnDropdownMouseExit"] =  function() return self, ctrl end,
		["OnMenuShow"]           = function() return self, ctrl end,
		["OnMenuHide"]           = function() return self, ctrl end,
		["OnSubMenuShow"]        = function() return self, ctrl, anchorPoint end,
		["OnSubMenuHide"]        = function() return self, ctrl end,
		["OnEntryMouseEnter"]    = function() return self, ctrl, data, hasSubmenu end,
		["OnEntryMouseExit"]     = function() return self, ctrl, data, hasSubmenu end,
		["OnEntrySelected"]      = function() return self, ctrl, data, hasSubmenu end,
		["OnCheckboxUpdated"]    = function() return self, ctrl, data end,
	}
	--Create a table with the callback functions parameters
	local callbackParams = { eventCallbackFunctionsSignatures[eventName]() }
	--Pass in the callback params to the narrateFunction
	local narrateText, stopCurrent = narrateCallbackFuncForEvent(unpack(callbackParams))

--d(">NarrateText: " ..tos(narrateText) .. ", stopCurrent: " ..tos(stopCurrent))
	--Didn't the addon take care of the narration itsself? So this library here should narrate the text returned
	if type(narrateText) == "string" then
		local narrateFuncOfLibrary = narrationEventToLibraryNarrateFunction[eventName]
		if narrateFuncOfLibrary == nil then return end
		narrateFuncOfLibrary(narrateText, stopCurrent)
	end
end

function ScrollableDropdownHelper:OnMouseEnterEntry(control)
	if control.selectible then
		-- Prevents headers and dividers from being highlighted.
		ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry(self, control)
	end
	
    if self.owner then
		local data, dataEntry = getControlData(control)
		
		local hasSubmenu = dataEntry.hasSubmenu or dataEntry.entries ~= nil
		
		self:Narrate("OnEntryMouseEnter", control, data, hasSubmenu)
		lib:FireCallbacks('EntryOnMouseEnter', data, control)
		
		-- For submenus
		local mySubmenu = getSubmenuFromControl(control)

		if hasSubmenu then
			data.hasSubmenu = true
			clearTimeout()
			if mySubmenu then -- open next submenu (nested)
				local childMenu = mySubmenu:GetChild(true) -- create if needed
				if childMenu then
					childMenu:Show(control)
				else
					lib.submenu:Show(control)
				end
			else
				lib.submenu:Show(control)
			end
		elseif mySubmenu then
			clearTimeout()
			mySubmenu:ClearChild()
		else
			lib.submenu:Clear(false)
		end
		
		clearNewStatus(control, dataEntry)
	end
	
end

local function overScroll(control)
	local moc = moc()
--	return moc:GetOwningWindow() == control.m_dropdownObject.scrollControl.scrollbar
	return moc:GetOwningWindow() == control.m_dropdownObject.scrollControl:GetOwningWindow()
end

local function onMouseExitTimeout(control)
--d("[LSM]onMouseExitTimeout")
	local moc = moc()
	local name = moc and moc:GetName()
	d( 'onMouseExitTimeout ' .. tostring(name))
	if control.GetName then
		d( 'control ' .. tostring(control:GetName()))
	end
	
	if name and zo_strfind(name, ROOT_PREFIX) == 1 then
		--TODO: check for matching depth??
	elseif control == moc then
	elseif control.m_submenu and control.m_submenu.m_dropdownObject:IsUpInside(control) then
--	elseif control.m_dropdownObject:IsUpInside(control) then
	elseif control == moc or moc:GetOwningWindow() ~= control:GetOwningWindow() then
	else
--		d( '- - - TODO: check for matching depth??')
		
		--Are we NOT above the scrollbar of the scrolhelper? Close the submenu then on mouse exit
--		if moc ~= control or (moc.GetType == nil or moc:GetType() ~= CT_SLIDER) then
		if moc.GetType == nil or moc:GetType() ~= CT_SLIDER then
			lib.submenu:Clear()
		end
	end
end

function ScrollableDropdownHelper:OnMouseExitEntry(control)
	ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry(self, control)
	

	local data, dataEntry = getControlData(control)
	local hasSubmenu = dataEntry.hasSubmenu or dataEntry.entries ~= nil
	
	self:Narrate("OnEntryMouseExit", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseExit', data, control)
	
	--[[Old
	-- For submenus
	local mySubmenu = getSubmenuFromControl(control)

	if overScroll(control) then
		d( '-- - - overScroll')
		return
	end
		if control.m_dropdownObject:IsUpInside(control) then
		
	--		lib.submenu:Clear()
		end
	if hasSubmenu then
		
		if mySubmenu then
--		if mySubmenu and not control.m_dropdownObject:IsUpInside(control) then
			clearTimeout()
			mySubmenu:ClearChild()
		else
			if not lib.GetPersistentMenus() then
				setTimeout(onMouseExitTimeout, control)
			end
			lib.submenu:Clear()
		end
	else
		if not lib.GetPersistentMenus() then
			setTimeout(onMouseExitTimeout, control)
		end
	end
	
	control.m_dropdownObject.scrollControl
	
	
		if control.m_owner then
--d("LibScrollableMenu_Entry_OnMouseExit")
		local data = ZO_ScrollList_GetData(control)
		local hasSubmenu = control.hasSubmenu or data.entries ~= nil

		--d("lib:FireCallbacks('EntryOnMouseExit)")
		local scrollHelper = getScrollHelperObjectFromControl(control)
		scrollHelper:Narrate("OnEntryMouseExit", control, data, hasSubmenu)
		lib:FireCallbacks('EntryOnMouseExit', data, control)

		ZO_ScrollList_MouseExit(control.m_owner.m_scroll, control)
		control.m_label:SetColor(control.m_owner.m_normalColor:UnpackRGBA())
		if control.m_owner.onMouseExitCallback then
			control.m_owner:onMouseExitCallback(control)
		end
	end
	
	if not lib.GetPersistentMenus() then
		setTimeout(onMouseExitTimeout)
	end
	]]
end

function ScrollableDropdownHelper:OnEntrySelected(control)
	d( 'OnEntrySelected IsUpInside ' .. tostring(self:IsUpInside(control)))
	
	local data, dataEntry = getControlData(control)
	if dataEntry and upInside then
		if button == MOUSE_BUTTON_INDEX_LEFT then
			ZO_ComboBoxDropdown_Keyboard.OnEntrySelected(self, control)
			
			local hasSubmenu = dataEntry.hasSubmenu or dataEntry.entries ~= nil

			self:Narrate("OnEntrySelected", control, dataEntry, hasSubmenu)
			--d("lib:FireCallbacks('EntryOnSelected)")
			lib:FireCallbacks('EntryOnSelected', dataEntry, control)

			local mySubmenu = getSubmenuFromControl(control)
			--	d( dataEntry.entries)
			if hasSubmenu then
				control.hasSubmenu = true
				--d(">menu control with submenu - hasSubmenu: " ..tos(control.hasSubmenu))
				--Save the current control to lib.submenu.lastClickedEntryWithSubmenu
				lib.submenu.lastClickedEntryWithSubmenu = control

				local targetSubmenu = lib.submenu
				if mySubmenu and mySubmenu.childMenu then
					--d(">childMenu")
					targetSubmenu = mySubmenu.childMenu
				end

				if targetSubmenu then
					if targetSubmenu:IsVisible() then
						--d(">targetSubMenu:IsVisible")
						targetSubmenu:Clear() -- need to clear it straight away, no timeout
					else
						--Has the control a submenu but also a callback function: Do not show the submenu if you click the control
						-->e.g. AddonSelector: Click main control to select addon pack, instead of having to select the submenu control
						if dataEntry.callback ~= nil then
							--Run the callback
							dataEntry.callback(control)
							targetSubmenu:Clear()
							--Hide the dropdown
							--[[TODO:
							local comboBox = getContainerFromControl(control)
							if comboBox and comboBox.m_dropdownObject then
							--  nil function	comboBox.m_dropdownObject:DoHide()
							-- comboBox.m_dropdownObject == self
							end
							]]
							
							selectEntryAndResetLastSubmenuData(control)
							return
						end
						--Check if submenu should be shown/hidden
						libMenuEntryOnMouseEnter(control)
					end
				end
				return true
			elseif data.checked ~= nil then
				playSelectedSoundCheck(entry)
				ZO_CheckButton_OnClicked(entry.m_checkbox)
				lib.submenu.lastClickedEntryWithSubmenu = nil
				return true
			else
				selectEntryAndResetLastSubmenuData(entry)
			end
		else -- right-click
			if data.contextMenuCallback  then
				data.contextMenuCallback (entry)
			end
		end
	end
	
	--[[
	--d(string.format('$s, buttonIndex = %s, upInside = %s', "LibScrollableMenu_OnSelected", tostring(button), tostring(upInside)))
	if entry.m_owner then -- is this really needed? It only fires from our xml. 
		-- also, what happens if an addon uses a different template. Hopefully they call this function in their OnMouseUp
		local data = ZO_ScrollList_GetData(entry)
		if data and upInside then
			if button == MOUSE_BUTTON_INDEX_LEFT then
				--d("LibScrollableMenu_OnSelected")
				local data = ZO_ScrollList_GetData(entry)
				local hasSubmenu = entry.hasSubmenu or data.entries ~= nil

				local scrollHelper = getScrollHelperObjectFromControl(entry)
				scrollHelper:Narrate("OnEntrySelected", entry, data, hasSubmenu)
				--d("lib:FireCallbacks('EntryOnSelected)")
				lib:FireCallbacks('EntryOnSelected', data, entry)

				local mySubmenu = getSubmenuFromControl(entry)
				--	d( data.entries)
				if hasSubmenu then
					entry.hasSubmenu = true
					--d(">menu entry with submenu - hasSubmenu: " ..tos(entry.hasSubmenu))
					--Save the current entry to lib.submenu.lastClickedEntryWithSubmenu
					lib.submenu.lastClickedEntryWithSubmenu = entry

					local targetSubmenu = lib.submenu
					if mySubmenu and mySubmenu.childMenu then
						--d(">childMenu")
						targetSubmenu = mySubmenu.childMenu
					end

					if targetSubmenu then
						if targetSubmenu:IsVisible() then
							--d(">targetSubMenu:IsVisible")
							targetSubmenu:Clear() -- need to clear it straight away, no timeout
						else
							--Has the entry a submenu but also a callback function: Do not show the submenu if you click the entry
							-->e.g. AddonSelector: Click main entry to select addon pack, instead of having to select the submenu entry
							if data.callback ~= nil then
								--Run the callback
								data.callback(entry)
								targetSubmenu:Clear()
								--Hide the dropdown
								local comboBox = getContainerFromControl(entry)
								if comboBox and comboBox.scrollHelper then
									comboBox.scrollHelper:DoHide()
								end
								
								selectEntryAndResetLastSubmenuData(entry)
								return
							end
							--Check if submenu should be shown/hidden
							libMenuEntryOnMouseEnter(entry)
						end
					end
					return true
				elseif data.checked ~= nil then
					playSelectedSoundCheck(entry)
					ZO_CheckButton_OnClicked(entry.m_checkbox)
					lib.submenu.lastClickedEntryWithSubmenu = nil
					return true
				else
					selectEntryAndResetLastSubmenuData(entry)
				end
			else -- right-click
				if data.contextMenuCallback  then
					data.contextMenuCallback (entry)
				end
			end
		end
	end
	]]
end

function LibScrollableMenu_OnSelected(control, button, upInside)
    local dropdown = control.m_dropdownObject
    if dropdown then
        dropdown:OnEntrySelected(control, button, upInside)
    end
end

-- not used
function ScrollableDropdownHelper:IsUpInside(control)
	local moc = WINDOW_MANAGER:GetMouseOverControl()
	return moc == control
end

--[[
function ScrollableDropdownHelper:Show(comboBox, itemTable, minWidth, maxHeight, spacing)
	for k, item in ipairs(itemTable) do
		if self.hasSubmenu then
			item.isNew = areAnyEntriesNew(item)
		end
	end
	ZO_ComboBoxDropdown_Keyboard.Show(self, comboBox, itemTable, minWidth, maxHeight, spacing)
end

function ScrollableDropdownHelper:GetChild(canCreate)
	if not self.childMenu and canCreate then
		self.childMenu = getScrollableSubmenu(self.depth + 1)
	end
	return self.childMenu
end

]]

--[[
function ScrollableDropdownHelper:SetupEntry(control, data, list)
	ZO_ComboBoxDropdown_Keyboard.SetupEntry(self, control, data, list)

	control.m_owner = self.owner
	control.m_data = data
	control.m_dropdownObject = self
end

function ScrollableDropdownHelper:SetupEntryLabel(labelControl, data)
	if labelControl then		
		labelControl:SetText(data.name)
		labelControl:SetFont(self.owner:GetDropdownFont())
		local color = self.owner:GetItemNormalColor(data)
		labelControl:SetColor(color:UnpackRGBA())
		labelControl:SetHorizontalAlignment(self.horizontalAlignment)
	end
end

]]

--------------------------------------------------------------------
-- ScrollableSubmenu
--------------------------------------------------------------------
local submenus = {}
local ScrollableSubmenu = ZO_InitializingObject:Subclass()

getScrollableSubmenu = function(depth)
--local function getScrollableSubmenu(depth)
	if depth > #submenus then
		tins(submenus, ScrollableSubmenu:New(depth))
	end
	return submenus[depth]
end
lib.submenus = submenus

-- ScrollableSubmenu:New
function ScrollableSubmenu:Initialize(submenuDepth)
	self.depth = submenuDepth
	self.isShown = false
	
	local submenuControl = comboBoxtPool:AcquireObject(submenuDepth)
	submenuControl:SetHidden(true)
	
	d( submenuControl:GetName())
	
	if not self.control then
		local scrollableDropdown = submenuControl:GetNamedChild('Dropdown')
		self.comboBox = scrollableDropdown
		self.dropdown = ZO_ComboBox_ObjectFromContainer(scrollableDropdown)
		self.dropdown.m_submenu = self
		self.control = submenuControl
	end
	
		-- for easier access
	

--	comboBoxtPool:AcquireObject(self.depth)
--[[
	local submenuControl = WINDOW_MANAGER:CreateControlFromVirtual(ROOT_PREFIX..submenuDepth, ZO_Menus, 'LibScrollableMenu_ComboBox')
	submenuControl:SetHidden(true)
	submenuControl:SetHandler("OnHide", function(control)
		clearTimeout()
		self:Clear()
	end)
	
	self.dropdown = ZO_ComboBox_ObjectFromContainer(scrollableDropdown)
	self.dropdown.m_submenu = self
	
	submenuControl:SetDrawLevel(ZO_Menu:GetDrawLevel() + submenuDepth)
	--submenuControl:SetExcludeFromResizeToFitExtents(true)
	
	local scrollableDropdown = submenuControl:GetNamedChild('Dropdown')
	self.comboBox = scrollableDropdown
	


	self.dropdown.SetSelected = function(dropdown, index, ignoreCallback)
		local parentDropdown = lib.submenu.owner.m_comboBox
		parentDropdown:ItemSelectedClickHelper(dropdown.m_sortedItems[index])
		parentDropdown:HideDropdown()
	end

	-- nesting
	self.depth = submenuDepth
	self.parentMenu = getScrollableSubmenu(submenuDepth - 1)
	if self.parentMenu then
		self.parentMenu.childMenu = self
	end

]]
	-- nesting
	self.parentMenu = getScrollableSubmenu(submenuDepth - 1)
	d( 'ScrollableSubmenu:Initialize parentMenu', tostring(self.parentMenu ~= nil))
	if self.parentMenu then
		self.parentMenu.childMenu = self
	end
	
	-- for easier access
	self.control = submenuControl
	
	--don't need parent for this / leave visibleRows nil (defualt 10 will be used) / only use visibleSubmenuRows = 10 as default
	-->visibleSubmenuRows will be overwritten at ScrollableSubmenu:Show -> taken from parent's ScrollableDropdownHelper dropdown.visibleRowsSubMenu
	-- (parent, control, options, isSubMenum_dropdownObject)
--	self.m_dropdownObject = ScrollableDropdownHelper:New(nil, self.control, nil, true)
	
	--self.m_dropdownObject.OnShow = function() end
--	self.control.m_dropdownObject = self.m_dropdownObject
	
	self.control.submenu = self
	
end

--[[
function ScrollableSubmenu:AddItem(...)
	self.dropdown:AddItem(...)
end

function ScrollableSubmenu:AddItems(entries)
	self:ClearItems()
	for i = 1, #entries do
		self:AddItem(entries[i], ZO_COMBOBOX_SUPRESS_UPDATE)
	end
end
]]

function ScrollableSubmenu:AnchorToControl(parentControl)
--	d( parentControl:GetName())
--	d( 'need owner', self.control:GetName())
	local myControl = self.m_dropdownObject.control -- singleton cannot anchor it to parentControl
	local myControl = self.control.dropdown.m_container -- singleton cannot anchor it to parentControl
	myControl:ClearAnchors()

	local parentDropdown = self:GetOwner().m_comboBox.m_dropdown
	local parentDropdown = parentControl.m_dropdownObject.control

	local anchorPoint = LEFT
	local anchorOffset = -3
	local anchorOffsetY = -7 --Move the submenu a bit up so it's 1st row is even with the main menu's row having/showing this submenu
	local anchorOffsetY = -parentControl:GetHeight()

	if self.parentMenu then
		anchorPoint = self.parentMenu.anchorPoint or RIGHT
	elseif (parentControl:GetRight() + myControl:GetWidth()) < GuiRoot:GetRight() then
		anchorPoint = RIGHT
	end

	if anchorPoint == RIGHT then
		anchorOffset = 3 + parentDropdown:GetWidth() - parentControl:GetWidth() - PADDING * 2
	--	anchorOffset = 3 + parentControl:GetWidth() - parentControl:GetWidth() - PADDING * 2
	end

	myControl:SetAnchor(TOP + (10 - anchorPoint), parentControl, TOP + anchorPoint, anchorOffset, anchorOffsetY)
	self.anchorPoint = anchorPoint
	myControl:SetHidden(false)
end

function ScrollableSubmenu:Clear(doFireCallback)
	if self.isShown == true then
	d("lib:FireCallbacks('SubmenuOnHide)")
		self.m_dropdownObject:Narrate("OnSubMenuHide", self.dropdown, nil, nil)
		lib:FireCallbacks('SubmenuOnHide', self)
	end

	self:ClearItems()
	self:SetOwner(nil)
	self.control:SetHidden(true)
	self:ClearChild()

	self.isShown = false
end

--[[
function ScrollableSubmenu:ClearChild()
	local childMenu = self.childMenu
	if self.childMenu then
	end
--	if not upInside then clear
	
	if childMenu then
		if childMenu.m_dropdownObject and childMenu.m_dropdownObject:IsOwnedByComboBox(childMenu.comboBox) then
			childMenu:Clear()
		else
			childMenu:Clear()
		end
	end
end
]]

function ScrollableSubmenu:ClearChild()
	local childMenu = self.childMenu
	if self.childMenu then
	end
	
--	if not upInside then clear
	if childMenu then
		if childMenu.m_dropdownObject and childMenu.m_dropdownObject:IsUpInside() then
			return
		else
			childMenu:Clear()
		end
	end
end

function ScrollableSubmenu:ClearItems()
	self.dropdown:ClearItems()
end

--[[
]]
function ScrollableSubmenu:GetChild(canCreate)
	d( '- - - ScrollableSubmenu:GetChild' )
	d( tostring(not self.childMenu and canCreate))
	
	if not self.childMenu and canCreate then
		self.childMenu = getScrollableSubmenu(self.depth + 1)
	end
	return self.childMenu
end

function ScrollableSubmenu:GetOwner(topmost)
	if topmost and self.parentMenu then
		return self.parentMenu:GetOwner(topmost)
	else
		return self.owner
	end
end

function ScrollableSubmenu:IsVisible()
	return not self.control:IsControlHidden()
end

function ScrollableSubmenu:SetOwner(owner) --owner is container for dropdown, use owner.m_comboBox for the object
		if self.owner then
			--self.control.dropdown.m_dropdown:SetParent(Z)
			self.owner = nil
		end
		if owner then
			if self == lib.submenu then
				--self.control:SetParent(owner)
				--self.control.dropdown.m_dropdown:SetParent(owner.m_comboBox.m_dropdown)
			end
			self.owner = owner
		end
end

function ScrollableSubmenu:Show(parentControl) -- parentControl is a row within another comboBox's dropdown scrollable list
	-- If mouse exits row and reenters before self hides then the entries will be added another time. So clear them on each Show.
--	self:ClearItems()
	self:Clear()
	
	local owner = getContainerFromControl(parentControl)
	self:SetOwner(owner)
	
	-- This gives us a parent submenu to all entries
	self.m_parent = parentControl
	parentControl.m_submenu = self
	
	d( 'parentControl.m_owner.isTopLevel ' .. tostring(parentControl.m_owner.isTopLevel))
--	if not parentControl.m_owner.isTopLevel then
	if not self.isTopLevel then
	end
	
--	m_owner = comboBox
	
--	parentControl.m_owner.m_dropdownObject:SetDrawTier(DT_MEDIUM)
	--Get the owner's (ComboBox control) ScrollableDropdownHelper object and the visibleSubmenuRows attribute, and update this
	--ScrollableSubmenu's ScrollableDropdownHelper object with this owner data, as attribute .parentScrollableDropdownHelper

--TODO:	self.parentScrollableDropdownHelper = owner and owner.parentScrollableDropdownHelper

	--Take over options from the owner m_dropdownObject
	-->Narration
	if self.parentScrollableDropdownHelper ~= nil then
	--	self.m_dropdownObject.narrateData = self.parentScrollableDropdownHelper.narrateData
	end

		local options = parentControl.m_dropdownObject.options
		self.m_dropdownObject = self.m_dropdownObject or ScrollableDropdownHelper:New(nil, self.control, options, true)
	
	local data = ZO_ScrollList_GetData(parentControl)
--	self:AddItems(getValueOrCallback(data.entries, data)) -- "self:GetOwner(TOP_MOST)", remove TOP_MOST if we want to pass the parent submenu control instead
	self.m_dropdownObject:AddItems(getValueOrCallback(data.entries, data)) -- "self:GetOwner(TOP_MOST)", remove TOP_MOST if we want to pass the parent submenu control instead
	ZO_Scroll_ResetToTop(self.m_dropdownObject.scrollControl)
	
	self.dropdown:SetDropdownObject(self.m_dropdownObject)

	self:AnchorToControl(parentControl)

	self:ClearChild()
	self.dropdown:ShowDropdownOnMouseUp() --show the submenu's ScrollableDropdownHelper comboBox entries -> Calls self.dropdown:AddMenuItems()


	parentControl.m_active = self.comboBox
	self.isShown = true
--d("lib:FireCallbacks('SubmenuOnShow)")
	self.m_dropdownObject:Narrate("OnSubMenuShow", parentControl, nil, nil, self.anchorPoint)
	lib:FireCallbacks('SubmenuOnShow', self)

	--self.m_dropdownObject.OnShow = function() end
--	self.control.m_dropdownObject = self.m_dropdownObject
	return true
end

--------------------------------------------------------------------
-- Custom scrollable menu comboBox
--------------------------------------------------------------------
local function createNewCustomScrollableComboBox()
--d("[LSM]createNewCustomScrollableComboBox")
	if customScrollableMenuComboBox ~= nil then return end
	customScrollableMenuComboBox = WINDOW_MANAGER:CreateControlFromVirtual(CUSTOM_SCROLLABLE_MENU_NAME, ZO_Menus, 'LibScrollableMenu_CustomContextMenu_ComboBox')
	customScrollableMenuComboBox:SetHidden(true)
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
--												    and let the library here narrate it for you via the UI narration
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

function AddCustomScrollableComboBoxDropdownMenu(parent, comboBoxControl, options)
	assert(parent ~= nil and comboBoxControl ~= nil, MAJOR .. " - AddCustomScrollableComboBoxDropdownMenu ERROR: Parameters parent and comboBoxControl must be provided!")

	if comboBoxControl.comboBox == nil then
		comboBoxControl.comboBox = comboBoxControl
	end
	if comboBoxControl.dropdown == nil then
		comboBoxControl.dropdown = ZO_ComboBox_ObjectFromContainer(comboBoxControl)
	end
	
--	d( parent:GetName())
	--Add a new scrollable menu helper
	comboBoxControl.dropdown.isTopLevel = true
	return ScrollableDropdownHelper:New(parent, comboBoxControl, options, false)
end
local addCustomScrollableComboBoxDropdownMenu = AddCustomScrollableComboBoxDropdownMenu



--[Custom scrollable context menu at any control]
--Add a scrollable menu to any control (not only a ZO_ComboBox), e.g. to an inventory row
--by creating a DUMMY ZO_ComboBox, adding the m_dropdownObject class to it and use it
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
		--or is the m_owner variable provided (tells us we got a m_dropdownObject entry here -> main menu or submenu)
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
end

--Clear all entries at the scrollable context menu
local function clearCustomScrollableMenuInternals(m_dropdownObject)
--d("[LSM]ClearCustomScrollableMenu")
	if customScrollableMenuComboBox == nil then return end
	m_dropdownObject = m_dropdownObject or getDropdownObjectFromControl(customScrollableMenuComboBox)
	m_dropdownObject:InitContextMenuValues()
	--m_dropdownObject:ResetOptions()
	mouseDownRefCounts[customScrollableMenuComboBox] = nil
end

--Adds an entry having a submenu (or maybe nested submenues) in the entries table
function AddCustomScrollableSubMenuEntry(text, entries)
end

--Adds a divider line to the context menu entries
function AddCustomScrollableMenuDivider()
end

--Pass in a table with predefined context menu entries and let them all be added in order of the table's number key
function AddCustomScrollableMenuEntries(contextMenuEntries)
end


--Set the options (visible rows max, etc.) for the scrollable context menu
function SetCustomScrollableMenuOptions(options, m_dropdownObject)
end

--Add a new scrollable context menu with the defined entries table.
--You can add more entries later via AddCustomScrollableMenuEntry function too
function AddCustomScrollableMenu(parent, entries, options)
end

--Show the custom scrollable context menu now
function ShowCustomScrollableMenu(controlToAnchorTo, point, relativePoint, offsetX, offsetY, options)
end

--Hide the custom scrollable context menu and clear internal variables, mouse clicks etc.
function ClearCustomScrollableMenu()
end


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
-- Init
------------------------------------------------------------------------------------------------------------------------
local function onAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
	setMaxMenuWidthAndRows()

	lib.submenu = getScrollableSubmenu(1)
--	createNewCustomScrollableComboBox()

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
--    1) Always pass the root dropdown and never a submenu dropdown
--    2) Pass root dropdown for initial entries and the appropriate submenu dropdown for the rest
--    3) Don't pass any dropdown control or object (!!CURRENTLY USED!!)
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