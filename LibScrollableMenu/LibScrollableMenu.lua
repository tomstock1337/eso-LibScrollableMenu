if LibScrollableMenu ~= nil then return end -- the same or newer version of this lib is already loaded into memory

local lib = ZO_CallbackObject:New()
lib.name = "LibScrollableMenu"
local MAJOR = lib.name
lib.version = "2.1.2"

lib.data = {}

if not lib then return end

--Constant for the divider entryType
lib.DIVIDER = "-"
local libDivider = lib.DIVIDER


--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--ZOs local speed-up/reference variables
local EM = EVENT_MANAGER
local SNM = SCREEN_NARRATION_MANAGER
local tos = tostring
local sfor = string.format
local tins = table.insert

--------------------------------------------------------------------
-- Libraries
--------------------------------------------------------------------
local LDL = LibDebugLogger

------------------------------------------------------------------------------------------------------------------------
--ZO_ComboBox function references
local zo_comboBox_base_addItem = ZO_ComboBox_Base.AddItem
local zo_comboBox_base_hideDropdown = ZO_ComboBox_Base.HideDropdown

--local zo_comboBox_selectItem = ZO_ComboBox.SelectItem
--local zo_comboBox_onGlobalMouseUp = ZO_ComboBox.OnGlobalMouseUp
--local zo_comboBox_hideDropdownInternal = ZO_ComboBox.HideDropdownInternal
local zo_comboBox_setItemEntryCustomTemplate = ZO_ComboBox.SetItemEntryCustomTemplate

local zo_comboBoxDropdown_onEntrySelected = ZO_ComboBoxDropdown_Keyboard.OnEntrySelected
local zo_comboBoxDropdown_onMouseExitEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry
local zo_comboBoxDropdown_onMouseEnterEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry


------------------------------------------------------------------------------------------------------------------------
--Library internal global locals
local g_contextMenu -- The contextMenu (like ZO_Menu): Will be created at onAddonLoaded

------------------------------------------------------------------------------------------------------------------------
--Logging
lib.doDebug = false
local logger
local debugPrefix = "[" .. MAJOR .. "]"
local LSM_LOGTYPE_DEBUG = 1
local LSM_LOGTYPE_VERBOSE = 2
local LSM_LOGTYPE_DEBUG_CALLBACK = 3
local LSM_LOGTYPE_INFO = 10
local LSM_LOGTYPE_ERROR = 99
local loggerTypeToName = {
	[LSM_LOGTYPE_DEBUG] = " -DEBUG- ",
	[LSM_LOGTYPE_VERBOSE] = " -VERBOSE- ",
	[LSM_LOGTYPE_DEBUG_CALLBACK] = "-CALLBACK- ",
	[LSM_LOGTYPE_INFO] = " -INFO- ",
	[LSM_LOGTYPE_ERROR] = " -ERROR- ",
}


------------------------------------------------------------------------------------------------------------------------
--Menu settings (main and submenu)
local DEFAULT_VISIBLE_ROWS = 10
local DEFAULT_SORTS_ENTRIES = true --sort the entries in main- and submenu lists

--Entry type settings
local DIVIDER_ENTRY_HEIGHT = 7
local HEADER_ENTRY_HEIGHT = 30
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT -- same as in zo_comboBox.lua: 25
local DEFAULT_SPACING = 0
local WITHOUT_ICON_LABEL_DEFAULT_OFFSETX = 4

--Fonts
local DEFAULT_FONT = "ZoFontGame"
local HEADER_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED))
local DEFAULT_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
local DEFAULT_TEXT_HIGHLIGHT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))

--Height and width
local DEFAULT_HEIGHT = 250

--dropdown settings
local SUBMENU_SHOW_TIMEOUT = 500 --350 ms before
local dropdownCallLaterHandle = MAJOR .. "_Timeout"

--Sound settings
local origSoundComboClicked = SOUNDS.COMBO_CLICK
local soundComboClickedSilenced = SOUNDS.NONE

--Textures
local iconNewIcon = ZO_KEYBOARD_NEW_ICON

--MultiIcon
local iconNarrationNewValue = GetString(SI_SCREEN_NARRATION_NEW_ICON_NARRATION)

--Narration
local UINarrationName = MAJOR .. "_UINarration_"
local UINarrationUpdaterName = MAJOR .. "_UINarrationUpdater_"


local getValueOrCallback

------------------------------------------------------------------------------------------------------------------------
--Menu types for the different scrollable menus
--[[
LSM_MENUTYPE_MAINMENU = 1
LSM_MENUTYPE_SUBMENU = 2
LSM_MENUTYPE_CONTEXTMENU = 100
LSM_MENUTYPE_CONTEXTMENU_SUBMENU = 101
local LSM_MENUTYPE_MAINMENU = LSM_MENUTYPE_MAINMENU
local LSM_MENUTYPE_SUBMENU = LSM_MENUTYPE_SUBMENU
local LSM_MENUTYPE_CONTEXTMENU = LSM_MENUTYPE_CONTEXTMENU
local LSM_MENUTYPE_CONTEXTMENU_SUBMENU = LSM_MENUTYPE_CONTEXTMENU_SUBMENU
]]

--Entry types - For the scroll list's dataType of te menus
local ENTRY_ID = 1
local DIVIDER_ENTRY_ID = 2
local HEADER_ENTRY_ID = 3
local SUBMENU_ENTRY_ID = 4
local CHECKBOX_ENTRY_ID = 5

--The custom scrollable context menu entry types
lib.LSM_ENTRY_TYPE_NORMAL = 	ENTRY_ID
lib.LSM_ENTRY_TYPE_DIVIDER = 	DIVIDER_ENTRY_ID
lib.LSM_ENTRY_TYPE_HEADER = 	HEADER_ENTRY_ID
lib.LSM_ENTRY_TYPE_SUBMENU = 	SUBMENU_ENTRY_ID
lib.LSM_ENTRY_TYPE_CHECKBOX = 	CHECKBOX_ENTRY_ID
--Add global variables
LSM_ENTRY_TYPE_NORMAL = 		lib.LSM_ENTRY_TYPE_NORMAL
LSM_ENTRY_TYPE_DIVIDER = 		lib.LSM_ENTRY_TYPE_DIVIDER
LSM_ENTRY_TYPE_HEADER = 		lib.LSM_ENTRY_TYPE_HEADER
LSM_ENTRY_TYPE_CHECKBOX = 		lib.LSM_ENTRY_TYPE_CHECKBOX
LSM_ENTRY_TYPE_SUBMENU = 		lib.LSM_ENTRY_TYPE_SUBMENU

local LSM_ENTRY_TYPE_NORMAL = 	LSM_ENTRY_TYPE_NORMAL
local LSM_ENTRY_TYPE_DIVIDER = 	LSM_ENTRY_TYPE_DIVIDER
local LSM_ENTRY_TYPE_HEADER = 	LSM_ENTRY_TYPE_HEADER
local LSM_ENTRY_TYPE_CHECKBOX = LSM_ENTRY_TYPE_CHECKBOX
local LSM_ENTRY_TYPE_SUBMENU = 	LSM_ENTRY_TYPE_SUBMENU

--Used in API RunCustomScrollableMenuItemsCallback to validate passed in entryTypes
local libraryAllowedEntryTypes = {
	[LSM_ENTRY_TYPE_NORMAL] = 	true,
	[LSM_ENTRY_TYPE_DIVIDER] = 	true,
	[LSM_ENTRY_TYPE_HEADER] = 	true,
	[LSM_ENTRY_TYPE_SUBMENU] =	true,
	[LSM_ENTRY_TYPE_CHECKBOX] =	true,
}
lib.allowedEntryTypes = libraryAllowedEntryTypes

--Used in API AddCustomScrollableMenuEntry to validate passed in entryTypes to be allowed for the contextMenus
local allowedEntryTypesForContextMenu = {
	[LSM_ENTRY_TYPE_NORMAL] = true,
	[LSM_ENTRY_TYPE_DIVIDER] = true,
	[LSM_ENTRY_TYPE_HEADER] = true,
	[LSM_ENTRY_TYPE_SUBMENU] =	true,
	[LSM_ENTRY_TYPE_CHECKBOX] = true,
}

--Used in API AddCustomScrollableMenuEntry to validate passed in entryTypes to be used without a callback function
local entryTypesForContextMenuWithoutMandatoryCallback = {
	[LSM_ENTRY_TYPE_DIVIDER] = true,
	[LSM_ENTRY_TYPE_HEADER] = true,
	[LSM_ENTRY_TYPE_SUBMENU] =	true,
}


--Make them accessible for the DropdownObject:New options table -> options.XMLRowTemplates
lib.scrollListRowTypes = {
	ENTRY_ID = ENTRY_ID,
	DIVIDER_ENTRY_ID = DIVIDER_ENTRY_ID,
	HEADER_ENTRY_ID = HEADER_ENTRY_ID,
	SUBMENU_ENTRY_ID = SUBMENU_ENTRY_ID,
	CHECKBOX_ENTRY_ID = CHECKBOX_ENTRY_ID,
}
------------------------------------------------------------------------------------------------------------------------


--ZO_ComboBox default settings: Will be copied over as default attributes to comboBoxClass and inherited scrollable
--dropdown helper classes
local comboBoxDefaults = {
	--From ZO_ComboBox
	m_selectedItemData = nil,
	m_selectedColor = { GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED) },
	m_disabledColor = ZO_GAMEPAD_UNSELECTED_COLOR, --ZO_ERROR_COLOR,
	m_sortOrder = ZO_SORT_ORDER_UP,
	m_sortType = ZO_SORT_BY_NAME,
	m_sortsItems = true,
	m_isDropdownVisible = false,
	m_preshowDropdownFn = nil,
	m_spacing = DEFAULT_SPACING,
	m_font = DEFAULT_FONT,
	m_normalColor = DEFAULT_TEXT_COLOR,
	m_highlightColor = DEFAULT_TEXT_HIGHLIGHT,
	m_customEntryTemplateInfos = nil,
	m_enableMultiSelect = false,
	m_maxNumSelections = nil,
	m_height = DEFAULT_HEIGHT,
	horizontalAlignment = TEXT_ALIGN_LEFT,

	--LibScrollableMenu internal (e.g. .options)
	disableFadeGradient = false,
	m_headerFontColor = HEADER_TEXT_COLOR,
	visibleRows = DEFAULT_VISIBLE_ROWS,
	visibleRowsSubmenu = DEFAULT_VISIBLE_ROWS,
	baseEntryHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
}
lib.comboBoxDefaults = comboBoxDefaults

--The default values for dropdownHelper options -> used for non-passed in options at LSM API functions
local defaultComboBoxOptions  = {
	["visibleRowsDropdown"] = DEFAULT_VISIBLE_ROWS,
	["visibleRowsSubmenu"] = DEFAULT_VISIBLE_ROWS,
	["sortEntries"] = DEFAULT_SORTS_ENTRIES,
	["font"] = DEFAULT_FONT,
	["spacing"] = DEFAULT_SPACING,
	["disableFadeGradient"] = false,
	["headerColor"] = nil,
	["preshowDropdownFn"] = nil,
	--["XMLRowTemplates"] = table, --Will be set at comboBoxClass:UpdateOptions(options) from options
}
lib.defaultComboBoxOptions  = defaultComboBoxOptions

--The mapping between LibScrollableMenu options key and ZO_ComboBox options key. Used in comboBoxClass:UpdateOptions()
local LSMOptionsKeyToZO_ComboBoxOptionsKey = {
	--These callback functions will apply the options directly
	['sortType'] = 				"m_sortType",
	['sortOrder'] = 			"m_sortOrder",
	['sortEntries'] = 			"m_sortsItems",
	['spacing'] = 				"m_spacing",
	['font'] = 					"m_font",
	["preshowDropdownFn"] = 	"m_preshowDropdownFn",
	["disableFadeGradient"] =	"disableFadeGradient", --Used for the ZO_ScrollList of the dropdown, not the comboBox itsself
	["headerColor"] =			"m_headerFontColor",
	["normalColor"] = 			"m_normalColor",
	["disabledColor"] =			"m_disabledColor",
	["visibleRowsDropdown"] =	"visibleRows",
	["visibleRowsSubmenu"]=		"visibleRowsSubmenu",
	["narrate"] = 				"narrateData",
}
lib.LSMOptionsKeyToZO_ComboBoxOptionsKey = LSMOptionsKeyToZO_ComboBoxOptionsKey

--The callback functions for the mapped LSM option -> ZO_ComboBox options (where any provided/needed)
local LSMOptionsToZO_ComboBoxOptionsCallbacks = {
	--These callback functions will apply the options directly
	['sortType'] = function(comboBoxObject, sortType)
		local options = comboBoxObject.options
		local updatedOptions = comboBoxObject.updatedOptions
		if updatedOptions.sortOrder then return end

		local sortOrder = getValueOrCallback(options.sortOrder, options)
		if sortOrder == nil then sortOrder = comboBoxObject.m_sortOrder end
		comboBoxObject:SetSortOrder(sortType , sortOrder )
	end,
	['sortOrder'] = function(comboBoxObject, sortOrder)
		local options = comboBoxObject.options
		local updatedOptions = comboBoxObject.updatedOptions
		--SortType was updated already during current comboBoxObject:UpdateOptions(options) -> SetOption() loop? No need to
		--update the sort order again here
		if updatedOptions.sortType ~= nil then return end

		local sortType = getValueOrCallback(options.sortType, options) or comboBoxObject.m_sortType
		comboBoxObject:SetSortOrder(sortType , sortOrder)
	end,
	["sortEntries"] = function(comboBoxObject, sortEntries)
		comboBoxObject:SetSortsItems(sortEntries) --sets comboBoxObject.m_sortsItems
	end,
	['spacing'] = function(comboBoxObject, spacing)
		comboBoxObject:SetSpacing(spacing) --sets comboBoxObject.m_spacing
	end,
	['font'] = function(comboBoxObject, font)
		comboBoxObject:SetFont(font) --sets comboBoxObject.m_font
	end,
	["preshowDropdownFn"] = function(comboBoxObject, preshowDropdownCallbackFunc)
		comboBoxObject:SetPreshowDropdownCallback(preshowDropdownCallbackFunc) --sets m_preshowDropdownFn
	end,
}
lib.LSMOptionsToZO_ComboBoxOptionsCallbacks = LSMOptionsToZO_ComboBoxOptionsCallbacks


--------------------------------------------------------------------
-- Debug logging
--------------------------------------------------------------------
local function loadLogger()
    --LibDebugLogger
	LDL = LDL or LibDebugLogger
    if not lib.logger and LDL then
        logger = LDL(MAJOR)
		logger:SetEnabled(true)
        logger:Debug("Library loaded")
        logger.verbose = logger:Create("Verbose")
        logger.verbose:SetEnabled(false)

        logger.callbacksFired = logger:Create("Callbacks")

        lib.logger = logger
    end
end
--Early try to load libs and to create logger (done again in EVENT_ADD_ON_LOADED)
loadLogger()


--Debug log function
local function dLog(debugType, text, ...)
	if not lib.doDebug then return end

	debugType = debugType or LSM_LOGTYPE_DEBUG


	local debugText = text
	if ... ~= nil and select(1, {...}) ~= nil then
		debugText = string.format(text, ...)
	end
	if debugText == nil or debugText == "" then return end

	--LibDebugLogger
	if LDL then
		if debugType == LSM_LOGTYPE_DEBUG_CALLBACK then
			logger.callbacksFired:Debug(debugText)

		elseif debugType == LSM_LOGTYPE_DEBUG then
			logger:Debug(debugText)

		elseif debugType == LSM_LOGTYPE_VERBOSE then
			if logger.verbose and logger.verbose.isEnabled == true then
				logger:Verbose(debugText)
			end

		elseif debugType == LSM_LOGTYPE_INFO then
			logger:Info(debugText)

		elseif debugType == LSM_LOGTYPE_ERROR then
			logger:Error(debugText)
		end

		--Normal debugging
	else
		--No verbose debuglos in normal chat!
		if debugType ~= LSM_LOGTYPE_VERBOSE then
			local debugTypePrefix = loggerTypeToName[debugType] or ""
			d(debugPrefix .. debugTypePrefix .. debugText)
		end
	end
end


--------------------------------------------------------------------
-- XML template functions
--------------------------------------------------------------------

local function getDropdownTemplate(enabled, baseTemplate, alternate, default)
	baseTemplate = MAJOR .. baseTemplate
	local templateName = sfor('%s%s', baseTemplate, (enabled and alternate or default))
	dLog(LSM_LOGTYPE_VERBOSE, "getDropdownTemplate - templateName: " ..tos(templateName))
	return templateName
end

local function getScrollContentsTemplate(barHidden)
	dLog(LSM_LOGTYPE_VERBOSE, "getScrollContentsTemplate - barHidden: " ..tos(barHidden))
	return getDropdownTemplate(barHidden, '_ScrollContents', '_BarHidden', '_BarShown')
end


--------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------
local function getControlName(control, alternativeControl)
	local ctrlName = control ~= nil and (control.name or (control.GetName ~= nil and control:GetName()))
	if ctrlName == nil and alternativeControl ~= nil then
		ctrlName = (alternativeControl.name or (alternativeControl.GetName ~= nil and alternativeControl:GetName()))
	end
	ctrlName = ctrlName or "n/a"
	return ctrlName
end
lib.GetControlName = getControlName

-- Is moc owned by comboBox
local function isMocOwnedByComboBox(self, control)
	local owningWindow = control:GetOwningWindow()
	local object = owningWindow and owningWindow.object
	local comboBox = object and object.m_comboBox

	local dropdownObject = comboBox and comboBox.m_dropdownObject

	if dropdownObject and dropdownObject.m_comboBox ~= nil then
		return dropdownObject:IsOwnedByComboBox(self)
	end
	return false
end

local function onGlobalMouseLeftUp(self, button, ...)
	if button == MOUSE_BUTTON_INDEX_LEFT then
		local mocCtrl = moc()

		if isMocOwnedByComboBox(self, mocCtrl) then
			return not mocCtrl.closeOnSelect
		end
	end
	return false
end

--Run function arg to get the return value (passing in ... as optional params to that function),
--or directly use non-function return value arg
function getValueOrCallback(arg, ...)
	dLog(LSM_LOGTYPE_VERBOSE, "getValueOrCallback - arg: " ..tos(arg))
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end
lib.GetValueOrCallback = getValueOrCallback

local function clearTimeout()
	dLog(LSM_LOGTYPE_VERBOSE, "ClearTimeout")
	EM:UnregisterForUpdate(dropdownCallLaterHandle)
end

local function setTimeout(callback)
	dLog(LSM_LOGTYPE_VERBOSE, "setTimeout")
	clearTimeout()
	--Delay the dropdown close callback so we can move the mouse above a new dropdown control and keep that opened e.g.
	EM:RegisterForUpdate(dropdownCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		dLog(LSM_LOGTYPE_VERBOSE, "setTimeout -> delayed by: " ..tos(SUBMENU_SHOW_TIMEOUT))
		clearTimeout()
		if callback then callback() end
	end)
end

local function updateIsContextMenuAndIsSubmenu(selfVar)
	dLog(LSM_LOGTYPE_VERBOSE, "updateIsContextMenuAndIsSubmenu")
	selfVar.isContextMenu = g_contextMenu ~= nil and g_contextMenu.m_container == selfVar.m_container
	selfVar.isSubmenu = selfVar.m_parentMenu ~= nil
end

--Mix in table entries in other table and skip existing entries. Optionally run a callback function on each entry
--e.g. getValueOrCallback(...)
local function mixinTableAndSkipExisting(targetData, sourceData, callbackFunc, ...)
	dLog(LSM_LOGTYPE_VERBOSE, "mixinTableAndSkipExisting - callbackFunc: %s", tos(callbackFunc))
	for i = 1, select("#", sourceData) do
		local source = select(i, sourceData)
		for k,v in pairs(source) do
			--Skip existing entries in target table
			if targetData[k] == nil then
				targetData[k] = (callbackFunc ~= nil and callbackFunc(v, ...)) or v
			end
		end
	end
end

--The default callback for the recursiveOverEntries function
local function defaultRecursiveCallback(_entry)
	dLog(LSM_LOGTYPE_VERBOSE, "defaultRecursiveCallback")
	return false
end

-- Recursively loop over drdopdown entries, and submenu dropdown entries of that parent dropdown, and check if e.g. isNew needs to be updated
local function recursiveOverEntries(entry, callback)
	callback = callback or defaultRecursiveCallback
	
	local result = callback(entry)
	local submenu = (entry.entries ~= nil and getValueOrCallback(entry.entries, entry)) or {}

	--local submenuType = type(submenu)
	--assert(submenuType == 'table', sfor('['..MAJOR..':recursiveOverEntries] table expected, got %q = %s', "submenu", tos(submenuType)))
	if  type(submenu) == "table" and #submenu > 0 then
		for _, subEntry in pairs(submenu) do
			local subEntryResult = recursiveOverEntries(subEntry, callback)
			if subEntryResult then
				result = subEntryResult
			end
		end
	end
	dLog(LSM_LOGTYPE_VERBOSE, "recursiveOverEntries - #submenu: %s, result: %s", tos(#submenu), tos(result))
	return result
end

--(Un)Silence the OnClicked sound of a selected dropdown
local function silenceComboBoxClickedSound(doSilence)
	doSilence = doSilence or false
	dLog(LSM_LOGTYPE_VERBOSE, "silenceComboBoxClickedSound - doSilence: " .. tos(doSilence))
	if doSilence == true then
		--Silence the "selected comboBox sound"
		SOUNDS.COMBO_CLICK = soundComboClickedSilenced
	else
		--Unsilence the "selected comboBox sound" again
		SOUNDS.COMBO_CLICK = origSoundComboClicked
	end
end

--Get the options of the scrollable dropdownObject
local function getOptionsForDropdown(dropdown)
	dLog(LSM_LOGTYPE_VERBOSE, "getOptionsForDropdown")
	return dropdown.owner.options or {}
end

--Check if a sound should be played if a dropdown entry was selected
local function playSelectedSoundCheck(dropdown)
	dLog(LSM_LOGTYPE_VERBOSE, "playSelectedSoundCheck")
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
local function doMapEntries(entryTable, mapTable, entryTableType)
	dLog(LSM_LOGTYPE_VERBOSE, "doMapEntries")
	if entryTableType == nil then
		entryTable = getValueOrCallback(entryTable)
	end

	for _, entry in pairs(entryTable) do
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
	dLog(LSM_LOGTYPE_VERBOSE, "mapEntries")

	if blank ~= nil then
		entryTable = mapTable
		mapTable = blank
		blank = nil
	end
	
	local entryTableType, mapTableType = type(entryTable), type(mapTable)
	local entryTableToMap = entryTable
	if entryTableType == "function" then
		entryTableToMap = getValueOrCallback(entryTable)
		entryTableType = type(entryTableToMap)
	end

	assert(entryTableType == 'table' and mapTableType == 'table' , sfor('['..MAJOR..':MapEntries] tables expected, got %q = %s, %q = %s', "entryTable", tos(entryTableType), "mapTable", tos(mapTableType)))
	
	-- Splitting these up so the above is not done each iteration
	doMapEntries(entryTableToMap, mapTable, entryTableType)
end
lib.MapEntries = mapEntries

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

	dLog(LSM_LOGTYPE_VERBOSE, "updateIcons - iconValue: %s, visible: %s, isNew: %s, tooltip: %s, narration: %s", tos(iconValue), tos(visible), tos(isNewValue), tos(tooltipForIcon), tos(iconNarration))

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

--------------------------------------------------------------------
-- Local entryData functions
--------------------------------------------------------------------

-- >> data, dataEntry
local function getControlData(control)
	dLog(LSM_LOGTYPE_VERBOSE, "getControlData - name: " ..tos(getControlName(control)))
	local data = control.m_sortedItems or control.m_data
	
	if data.dataSource then
		data = data:GetDataSource()
	end
	
	return data
end


--Check if an entry got the isNew set
local function getIsNew(_entry)
	dLog(LSM_LOGTYPE_VERBOSE, "getIsNew")
	return getValueOrCallback(_entry.isNew, _entry) or false
end

-- Recursively check for new entries.
local function areAnyEntriesNew(entry)
	dLog(LSM_LOGTYPE_VERBOSE, "areAnyEntriesNew")
	return recursiveOverEntries(entry, getIsNew)
end

-- Add/Remove the new status of a dropdown entry.
-- This works up from the mouse-over entry's submenu up to the dropdown,
-- as long as it does not run into a submenu still having a new entry.
local function updateSubmenuNewStatus(control)
	dLog(LSM_LOGTYPE_VERBOSE, "updateSubmenuNewStatus")
	-- reverse parse
	local isNew = false
	
	local data = getControlData(control)
	local submenuEntries = getValueOrCallback(data.entries, data) or {}
	
	-- We are only going to check the current submenu's entries, not recursively
	-- down from here since we are working our way up until we find a new entry.
	for _, subentry in ipairs(submenuEntries) do
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
	dLog(LSM_LOGTYPE_VERBOSE, "clearNewStatus")
	if data.isNew then
		-- Only directly change status on non-submenu entries. The are effected by child entries
		if data.entries == nil then
			data.isNew = false
			
			lib:FireCallbacks('NewStatusUpdated', data, control)
			dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: NewStatusUpdated - control: " ..tos(getControlName(control)))

			control.m_dropdownObject:Refresh(data)
			
			local parent = data.m_parentControl
			if parent then
				updateSubmenuNewStatus(parent)
			end
		end
	end
end

--Set the custom XML virtual template for a dropdown entry
local function setItemEntryCustomTemplate(item, customEntryTemplates)
	local entryType = item.entryType
	dLog(LSM_LOGTYPE_VERBOSE, "setItemEntryCustomTemplate - name: %q, entryType: %s", tos(item.label or item.name), tos(entryType))

	if entryType then
		local customEntryTemplate = customEntryTemplates[entryType].template
		zo_comboBox_setItemEntryCustomTemplate(item, customEntryTemplate)
	end
end

local function validateEntryType(item)
	--Check if any other entryType could be determined
	local isDivider = (item.label ~= nil and item.label == libDivider) or item.name == libDivider
	local isHeader = getValueOrCallback(item.isHeader, item)
	local isCheckbox = getValueOrCallback(item.isCheckbox, item)
	local hasSubmenu = getValueOrCallback(item.entries, item) ~= nil

	--Prefer passed in entryType (if any provided)
	local entryType = getValueOrCallback(item.entryType, item)
	--If no entryType was passed in: Get the entryType by the before determined data
	if not entryType or entryType == LSM_ENTRY_TYPE_NORMAL then
		entryType = hasSubmenu and LSM_ENTRY_TYPE_SUBMENU or
					isDivider and LSM_ENTRY_TYPE_DIVIDER or
					isHeader and LSM_ENTRY_TYPE_HEADER or
					isCheckbox and LSM_ENTRY_TYPE_CHECKBOX
					or LSM_ENTRY_TYPE_NORMAL
	end

	--Update the item's variables
	item.isHeader = isHeader
	item.isDivider = isDivider
	item.isCheckbox = isCheckbox
	item.hasSubmenu = hasSubmenu

	--Set the entryType to the itm
	item.entryType = entryType
end

local function updateLabelsStrings(data)
	dLog(LSM_LOGTYPE_VERBOSE, "updateLabelsStrings - labelFunc: %s, nameFunc: %s", tos(data.labelFunction), tos(data.nameFunction))
	if data.labelFunction then
		data.label = data.labelFunction(data)
	end

	if data.nameFunction then
		data.name = data.nameFunction(data)
	end

	if data.enabledFunction then
		local isEnabled = data.enabledFunction(data)
		if isEnabled == nil then
			-- Evaluate nil to be equivalent to true for backwards compatibility.
			isEnabled = true
		end
		data.enabled = isEnabled
	end
end

local function processNameString(data)
	--Passed in an alternative text/function returning a text to show at the label control of the menu entry?
	local labelData = data.label
	if type(labelData) == 'function' then
		--Keep the original label function at the data, data.label will be used as a string directly updated by data.labelFunction(data).
		data.labelFunction = labelData
	end
	
	--Name: Mandatory! Used interally of ZO_ComboBox and dropdownObject to SetSelectedItemText and run callback on clicked entry with (self, item.name, data, selectionChanged, oldItem)
	local nameData = data.name
	if type(nameData) == 'function' then
		--Keep the original name function at the data, as we need a "String only" text as data.name for ZO_ComboBox internal functions!
		data.nameFunction = nameData
	end
	dLog(LSM_LOGTYPE_VERBOSE, "processNameString - label: %s, name: %s", tos(labelData), tos(nameData))

	local isEnabled = data.enabled
	if type(isEnabled) == 'function' then
		--Keep the original label function at the data, data.label will be used as a string directly updated by data.labelFunction(data).
		data.enabledFunction = isEnabled
	else
		if isEnabled == nil then
			-- Evaluate nil to be equivalent to true for backwards compatibility.
			data.enabled = true
		end
	end
	updateLabelsStrings(data)
	
	--[[
	if type(data.name) ~= 'string' then
		--TODO: implement logging
	end
	]]
end

-- Prevents errors on the off chance a non-string makes it through into ZO_ComboBox
local function verifyLabelString(data)
	dLog(LSM_LOGTYPE_VERBOSE, "verifyLabelString")
	updateLabelsStrings(data)
	
	return type(data.name) == 'string'
end

-- We can add any row-type post checks and update dateEntry with static values.
local function addItem_Base(self, itemEntry)
	dLog(LSM_LOGTYPE_VERBOSE, "addItem_Base - itemEntry: " ..tos(itemEntry))
	--Get/build data.label and/or data.name values
	processNameString(itemEntry)
	--Get the entrType
	validateEntryType(itemEntry)

	if not itemEntry.customEntryTemplate then
		setItemEntryCustomTemplate(itemEntry, self.XMLrowTemplates)
		
		if itemEntry.hasSubmenu then
			itemEntry.isNew = areAnyEntriesNew(itemEntry)
		elseif itemEntry.isHeader then
			itemEntry.font = self.m_headerFont
			itemEntry.color = self.m_headerFontColor
		--elseif itemEntry.isDivider then
			-- Placeholder: Divider
		--elseif itemEntry.isCheckbox then
			-- Placeholder: Checkbox
		--elseif itemEntry.isNew then
			-- Placeholder: Is new
		end
	end
end

--------------------------------------------------------------------
-- Local tooltip functions
--------------------------------------------------------------------

local function resetCustomTooltipFuncVars()
	dLog(LSM_LOGTYPE_VERBOSE, "resetCustomTooltipFuncVars")
	lib.lastCustomTooltipFunction = nil
	lib.onHideCustomTooltipFunc = nil
end

--Hide the tooltip of a dropdown entry
local function hideTooltip()
	dLog(LSM_LOGTYPE_VERBOSE, "hideTooltip - custom onHide func: " ..tos(lib.onHideCustomTooltipFunc))
	if lib.onHideCustomTooltipFunc then
		lib.onHideCustomTooltipFunc()
	else
		ClearTooltip(InformationTooltip)
	end
	resetCustomTooltipFuncVars()
end

local function getTooltipAnchor(self, control, tooltipText, hasSubmenu)
	local relativeTo = control
	dLog(LSM_LOGTYPE_VERBOSE, "getTooltipAnchor - control: %s, tooltipText: %s, hasSubmenu: %s", tos(getControlName(control)), tos(tooltipText), tos(hasSubmenu))

	local submenu = self:GetSubmenu()
	if hasSubmenu then
		if submenu and not submenu:IsDropdownVisible() then
			return getTooltipAnchor(self, control, tooltipText, hasSubmenu)
		end
		relativeTo = submenu.m_dropdownObject.control
	else
		if submenu and submenu:IsDropdownVisible() then
			submenu:HideDropdown()
		end
	end

	local point, offsetX, offsetY, relativePoint = BOTTOMLEFT, 0, 0, TOPRIGHT

	local anchorPoint = select(2, relativeTo:GetAnchor())
	local right = anchorPoint ~= 3
	if not right then
		local width, height = GuiRoot:GetDimensions()
		local fontObject = _G[DEFAULT_FONT]
		local nameWidth = (type(tooltipText) == "string" and GetStringWidthScaled(fontObject, tooltipText, 1, SPACE_INTERFACE)) or 250

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
	-- In the order used in InitializeTooltip
	return relativeTo, point, offsetX, offsetY, relativePoint
end

--Show the tooltip of a dropdown entry. First check for any custom tooltip function that handles the control show/hide
--and if none is provided use default InformationTooltip
--> For a custom tooltip example see line below:
--[[
--Custom tooltip function example
Function to show and hide a custom tooltip control. Pass that in to the data table of any entry, via data.customTooltip!
Your function needs to create and show/hide that control, and populate the text etc to the control too!
Parameters:
-control The control the tooltip blongs to
-inside boolean to show if your mouse is inside the control. Will be false if tooltip should hide
-data The table with the current data of the rowControl
	-> To distinguish if the tooltip should be hidden or shown:	If 1st param data is missing the tooltip will be hidden! If data is provided the tooltip wil be shown
-rowControl The userdata of the control the tooltip should show about
-point, offsetX, offsetY, relativePoint: Suggested anchoring points

Example - Show an item tooltip of an inventory item
data.customTooltip = function(control, inside, data, relativeTo, point, offsetX, offsetY, relativePoint)
    ClearTooltip(ItemTooltip)
	if inside and data then
		InitializeTooltip(ItemTooltip, relativeTo, point, offsetX, offsetY, relativePoint)
        ItemTooltip:SetBagItem(data.bagId, data.slotIndex)
		ItemTooltipTopLevel:BringWindowToTop()
	end
end

Another example using a custom control of your addon to show the tooltip:
customTooltipFunc = function(control, inside, data, rowControl, point, offsetX, offsetY, relativePoint)
	if not inside or data == nil then
		myAddon.myTooltipControl:SetHidden(true)
	else
		myAddon.myTooltipControl:ClearAnchors()
		myAddon.myTooltipControl:SetAnchor(point, rowControl, relativePoint, offsetX, offsetY)
		myAddon.myTooltipControl:SetText(data.tooltip)
		myAddon.myTooltipControl:SetHidden(false)
	end
end
]]
local function showTooltip(self, control, data, hasSubmenu)
	resetCustomTooltipFuncVars()

	local tooltipData = getValueOrCallback(data.tooltip, data)
	local tooltipText = getValueOrCallback(tooltipData, data)
	local customTooltipFunc = data.customTooltip
	if type(customTooltipFunc) ~= "function" then customTooltipFunc = nil end

	dLog(LSM_LOGTYPE_VERBOSE, "showTooltip - control: %s, tooltipText: %s, hasSubmenu: %s, customTooltipFunc: %s", tos(getControlName(control)), tos(tooltipText), tos(hasSubmenu), tos(customTooltipFunc))

	--To prevent empty tooltips from opening.
	if tooltipText == nil and customTooltipFunc == nil then return end

	local relativeTo, point, offsetX, offsetY, relativePoint = getTooltipAnchor(self, control, tooltipText, hasSubmenu)

	--RelativeTo is a control?
	if type(relativeTo) == "userdata" and type(relativeTo.IsControlHidden) == "function" then
		if customTooltipFunc ~= nil then
			lib.lastCustomTooltipFunction = customTooltipFunc

			local onHideCustomTooltipFunc = function()
				customTooltipFunc(control, false, nil) --Set 2nd param to false and leave 3rd param data empty so the calling func knows we are hiding
			end
			lib.onHideCustomTooltipFunc = onHideCustomTooltipFunc

			customTooltipFunc(control, true, data, relativeTo, point, offsetX, offsetY, relativePoint)
		else
			InitializeTooltip(InformationTooltip, relativeTo, point, offsetX, offsetY, relativePoint)
			SetTooltipText(InformationTooltip, tooltipText)
			InformationTooltipTopLevel:BringWindowToTop()
		end
	end
end


--------------------------------------------------------------------
-- Local narration functions
--------------------------------------------------------------------

local function isAccessibilitySettingEnabled(settingId)
	local isSettingEnabled = GetSetting_Bool(SETTING_TYPE_ACCESSIBILITY, settingId)
	dLog(LSM_LOGTYPE_VERBOSE, "isAccessibilitySettingEnabled - settingId: %s, isSettingEnabled: %s", tos(settingId), tos(isSettingEnabled))
	return isSettingEnabled
end

local function isAccessibilityModeEnabled()
	dLog(LSM_LOGTYPE_VERBOSE, "isAccessibilityModeEnabled")
	return isAccessibilitySettingEnabled(ACCESSIBILITY_SETTING_ACCESSIBILITY_MODE)
end

local function isAccessibilityUIReaderEnabled()
	dLog(LSM_LOGTYPE_VERBOSE, "isAccessibilityUIReaderEnabled")
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
	dLog(LSM_LOGTYPE_VERBOSE, "addNewUINarrationText - newText: %s, stopCurrent: %s", tos(newText), tos(stopCurrent))
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
	dLog(LSM_LOGTYPE_VERBOSE, "onUpdateDoNarrate - updName: %s, delay: %s", tos(updaterName), tos(delay))

	EM:UnregisterForUpdate(updaterName)
	if isAccessibilityUIReaderEnabled() == false or callbackFunc == nil then return end
	delay = delay or 1000
	EM:RegisterForUpdate(updaterName, delay, function()
		dLog(LSM_LOGTYPE_VERBOSE, "onUpdateDoNarrate - Delayed call: updName: %s", tos(updaterName))
		if isAccessibilityUIReaderEnabled() == false then EM:UnregisterForUpdate(updaterName) return end
		callbackFunc()
		EM:UnregisterForUpdate(updaterName)
	end)
end

--Own narration functions, if ever needed -> Currently the addons pass in their narration functions
local function onMouseEnterOrExitNarrate(narrateText, stopCurrent)
	dLog(LSM_LOGTYPE_VERBOSE, "onMouseEnterOrExitNarrate - narrateText: %s, stopCurrent: %s", tos(narrateText), tos(stopCurrent))
	onUpdateDoNarrate("OnMouseEnterExit", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end

local function onSelectedNarrate(narrateText, stopCurrent)
	dLog(LSM_LOGTYPE_VERBOSE, "onSelectedNarrate - narrateText: %s, stopCurrent: %s", tos(narrateText), tos(stopCurrent))
	onUpdateDoNarrate("OnEntryOrCheckboxSelected", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end

local function onMouseMenuOpenOrCloseNarrate(narrateText, stopCurrent)
	dLog(LSM_LOGTYPE_VERBOSE, "onMouseMenuOpenOrCloseNarrate - narrateText: %s, stopCurrent: %s", tos(narrateText), tos(stopCurrent))
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
	
	dLog(LSM_LOGTYPE_VERBOSE, "onMouseEnter - control: %s, hasSubmenu: %s", tos(getControlName(control)), tos(hasSubmenu))
	dropdown:Narrate("OnEntryMouseEnter", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseEnter', data, control)
	dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: EntryOnMouseEnter - control: %s, hasSubmenu: %s", tos(getControlName(control)), tos(hasSubmenu))

	return dropdown
end

local function onMouseExit(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject

	dLog(LSM_LOGTYPE_VERBOSE, "onMouseExit - control: %s, hasSubmenu: %s", tos(getControlName(control)), tos(hasSubmenu))
	dropdown:Narrate("OnEntryMouseExit", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseExit', data, control)
	dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: EntryOnMouseExit - control: %s, hasSubmenu: %s", tos(getControlName(control)), tos(hasSubmenu))

	return dropdown
end

local function onMouseUp(control, data, hasSubmenu, button, upInside)
	local dropdown = control.m_dropdownObject

	dLog(LSM_LOGTYPE_VERBOSE, "onMouseUp - control: %s, button: %s, upInside: %s, hasSubmenu: %s", tos(getControlName(control)), tos(button), tos(upInside), tos(hasSubmenu))
	if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
		dropdown:Narrate("OnEntrySelected", control, data, hasSubmenu)
		lib:FireCallbacks('EntryOnSelected', data, control)
		dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: EntryOnSelected - control: %s, button: %s, upInside: %s, hasSubmenu: %s", tos(getControlName(control)), tos(button), tos(upInside), tos(hasSubmenu))

		if data.callback then
			dropdown:SelectItemByIndex(control.m_data.m_index)
		end
	end

	hideTooltip()
	return dropdown
end

local has_submenu = true
local no_submenu = false

local handlerFunctions  = {
	['onMouseEnter'] = {
		[ENTRY_ID] = function(control, data, ...)
			local dropdown = onMouseEnter(control, data, no_submenu)
			clearNewStatus(control, data)
			return not control.closeOnSelect
		end,
		[HEADER_ENTRY_ID] = function(control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, data, ...)
			--d( 'onMouseEnter [SUBMENU_ENTRY_ID]')

			local dropdown = onMouseEnter(control, data, has_submenu)
			clearTimeout()
			dropdown:ShowSubmenu(control)
			return false --not control.closeOnSelect
		end,
		[CHECKBOX_ENTRY_ID] = function(control, data, ...)
			local dropdown = onMouseEnter(control, data, no_submenu)
			return true
		end,
	},
	['onMouseExit'] = {
		[ENTRY_ID] = function(control, data)
			local dropdown = onMouseExit(control, data, no_submenu)
			return not control.closeOnSelect
		end,
		[HEADER_ENTRY_ID] = function(control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, data)
			local dropdown = onMouseExit(control, data, has_submenu)
			--TODO: This is onMouseExit, MouseIsOver(control) should not apply.
			if not (MouseIsOver(control) or dropdown:IsEnteringSubmenu()) then
				dropdown:OnMouseExitTimeout(control)
			end
			return false --not control.closeOnSelect
		end,
		[CHECKBOX_ENTRY_ID] = function(control, data)
			local dropdown = onMouseExit(control, data, no_submenu)
			return true
		end,
	},
	--The onMouseUp will be used to select an entry in the menu/submenu/nested submenu/context menu
	---> It will call the ZO_ComboBoxDropdown_Keyboard.OnEntrySelected and via that ZO_ComboBox_Base:ItemSelectedClickHelper(item, ignoreCallback)
	---> which will then call the item.callback(comboBox, itemName, item, selectionChanged, oldItem) function
	---> So the parameters for the LibScrollableMenu entry.callback functions will be the same:  (comboBox, itemName, item, selectionChanged, oldItem)
	['onMouseUp'] = {
		[ENTRY_ID] = function(control, data, button, upInside)
			--onMouseUp [ENTRY_ID]')
			local dropdown = onMouseUp(control, data, no_submenu, button, upInside)
			return true
		end,
		[HEADER_ENTRY_ID] = function(control, data, button, upInside)
			local dropdown = onMouseUp(control, data, no_submenu, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, data, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, data, button, upInside)
			local dropdown = onMouseUp(control, data, has_submenu, button, upInside)
			return true
		end,
		[CHECKBOX_ENTRY_ID] = function(control, data, button, upInside)
			--d( 'onMouseUp [CHECKBOX_ENTRY_ID]')
			local dropdown = control.m_dropdownObject
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					-- left click on row toggles the checkbox.
					playSelectedSoundCheck(dropdown)
					ZO_CheckButton_OnClicked(control.m_checkbox)
					data.checked = ZO_CheckButton_IsChecked(control.m_checkbox)
					dLog(LSM_LOGTYPE_VERBOSE, "Checkbox onMouseUp - control: %s, button: %s, upInside: %s, isChecked: %s", tos(getControlName(control)), tos(button), tos(upInside), tos(data.checked))
				end
			end
			return true
		end,
	},
}

local function runHandler(handlerTable, control, ...)
	dLog(LSM_LOGTYPE_VERBOSE, "runHandler - control: %s, handlerTable: %s, typeId: %s", tos(getControlName(control)), tos(handlerTable), tos(control.typeId))
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
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:Initialize - parent: %s, comboBoxContainer: %s, depth: %s", tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth))

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
	end

	--Enable different hightlight templates at the ZO_SortFilterList scrolLList entries -> OnMousEnter
	-->entries opening a submenu, having a callback function, show with a different template (color e.g.)
	-->>!!! ZO_ScrollList_EnableHighlight(self.scrollControl, function(control) end) cannot be used here as it does NOT overwrite existing highlightTemplateOrFunction !!!
	self.scrollControl.highlightTemplateOrFunction = function(control)
		local highlightName = "ZO_SelectionHighlight"
		local data = getControlData(control)
		if data.hasSubmenu == true and data.callback ~= nil then
			highlightName = "LSM_ListRowHighlightTemplate_SubmenuEntryWithCallback"
		end
		dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:Initialize - name: %q, scrollListHighlight: %s, hasSubmenu: %s, callback: %s", tos(getControlName(control)), tos(highlightName), tos(data.hasSubmenu), tos(data.callback))
		return highlightName
	end
end

function dropdownClass:AddItems(items)
	error('[LSM] scrollHelper:AddItems is obsolete. You must use m_comboBox:AddItems')
end

function dropdownClass:AddItem(item)
	error('[LSM] scrollHelper:AddItems is obsolete. You must use m_comboBox:AddItem')
end

--Narration
function dropdownClass:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:Narrate - eventName: %s, ctrl: %s, hasSubmenu: %s, anchorPoint: %s", tos(eventName), tos(getControlName(ctrl)), tos(hasSubmenu), tos(anchorPoint))
	self.owner:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
end

function dropdownClass:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:AddCustomEntryTemplate - entryTemplate: %s, entryHeight: %s, setupFunction: %s, widthPadding: %s", tos(entryTemplate), tos(entryHeight), tos(setupFunction), tos(widthPadding))
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
		widthPadding = widthPadding,
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
	local offsetX = -4
	local point, relativePoint = TOPLEFT, TOPRIGHT
	
	if self.m_parentMenu.m_dropdownObject and self.m_parentMenu.m_dropdownObject.anchorRight ~= nil then
		right = self.m_parentMenu.m_dropdownObject.anchorRight
	end
	
	if not right or parentControl:GetRight() + self.control:GetWidth() > width then
		right = false
		offsetX = 4
		point, relativePoint = TOPRIGHT, TOPLEFT
	end
	
	local relativeTo = parentControl.m_dropdownObject.scrollControl
	-- Get offsetY in relation to parentControl's top in the scroll container
    local offsetY = select(6, parentControl:GetAnchor(0))

	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:AnchorToControl - point: %s, relativeTo: %s, relativePoint: %s offsetX: %s, offsetY: %s", tos(point), tos(getControlName(relativeTo)), tos(relativePoint), tos(offsetX), tos(offsetY))

	self.control:ClearAnchors()
	self.control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
	
	self.anchorRight = right

	--Check for context menu and submenu, and do narration
	updateIsContextMenuAndIsSubmenu(self)
	if not self.isContextMenu and self.isSubmenu == true then
		local anchorPoint = (right == true and TOPRIGHT) or TOPLEFT
		self:Narrate("OnSubMenuShow", parentControl, nil, nil, anchorPoint)
		dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: OnSubMenuShow - control: %s, anchorPoint: %s", tos(getControlName(parentControl)), tos(anchorPoint))
		lib:FireCallbacks('OnSubMenuShow', parentControl, anchorPoint)
	end
end

function dropdownClass:AnchorToComboBox(comboBox)
	local parentControl = comboBox:GetContainer()
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:AnchorToComboBox - comboBox container: %s", tos(getControlName(parentControl)))
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

	local point, relativeTo, relativePoint
	if right then
		x = x + 10
		if bottom then
			point = TOPLEFT
			relativeTo = nil
			relativePoint = TOPLEFT
		else
			point = BOTTOMLEFT
			relativeTo = nil
			relativePoint = TOPLEFT
		end
	else
		x = x - 10
		if bottom then
			point = TOPRIGHT
			relativeTo = nil
			relativePoint = TOPLEFT
		else
			point = BOTTOMRIGHT
			relativeTo = nil
			relativePoint = TOPLEFT
		end
	end
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:AnchorToMouse - point: %s, relativeTo: %s, relativePoint: %s offsetX: %s, offsetY: %s", tos(point), tos(getControlName(relativeTo)), tos(relativePoint), tos(x), tos(y))
	if point and relativePoint then
		menuToAnchor:SetAnchor(point, relativeTo, relativePoint, x, y)
	end
end

function dropdownClass:GetScrollbar()
	local scrollCtrl = self.scrollControl
	local scrollBar = scrollCtrl ~= nil and scrollCtrl.scrollbar
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:GetScrollbar - scrollbar: " ..tos(getControlName(scrollBar, scrollCtrl)))
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
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:GetSubmenu - submenu: " ..tos(self.m_submenu))

	return self.m_submenu
end

function dropdownClass:IsDropdownVisible()
	-- inherited ZO_ComboBoxDropdown_Keyboard:IsHidden
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:IsDropdownVisible: " ..tos(not self:IsHidden()))
	return not self:IsHidden()
end

function dropdownClass:IsEnteringSubmenu()
	local submenu = self:GetSubmenu()
	if submenu then
		if submenu:IsDropdownVisible() and submenu:IsMouseOverControl() then
			dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:IsEnteringSubmenu -> Yes")
			return true
		end
	end
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:IsEnteringSubmenu -> No")
	return false
end

function dropdownClass:IsItemSelected(item)
	if self.owner and self.owner.IsItemSelected then
		dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:IsItemSelected -> " ..tos(self.owner:IsItemSelected(item)))
		return self.owner:IsItemSelected(item)
	end
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:IsItemSelected -> No")
	return false
end

function dropdownClass:IsMouseOverOpeningControl()
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:IsMouseOverOpeningControl -> No")
	return false
end

function dropdownClass:OnMouseEnterEntry(control)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:OnMouseEnterEntry - control: " .. tos(getControlName(control)))

	-- Added here for when mouse is moved from away from dropdowns over a row, it will know to close specific children
	self:OnMouseExitTimeout(control)

	local data = getControlData(control)
	if data.enabled == true then
		if not runHandler(handlerFunctions['onMouseEnter'], control, data) then
			zo_comboBoxDropdown_onMouseEnterEntry(self, control)
		end

		if data.tooltip or data.customTooltip then
			self:ShowTooltip(control, data)
		end
	end

	--TODO: Conflicting OnMouseExitTimeout -> 20240310 What in detail is conflicting here, with what?
	if g_contextMenu:IsDropdownVisible() then
		--d(">contex menu: Dropdown visible = yes")
		g_contextMenu.m_dropdownObject:OnMouseExitTimeout(control)
	end
end

function dropdownClass:OnMouseExitEntry(control)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:OnMouseExitEntry - control: " .. tos(getControlName(control)))

	hideTooltip(control)
	local data = getControlData(control)
	self:OnMouseExitTimeout(control)
	if data.enabled and not runHandler(handlerFunctions['onMouseExit'], control, data) then
		zo_comboBoxDropdown_onMouseExitEntry(self, control)
	end

	--[[
	if not lib.GetPersistentMenus() then
--		self:OnMouseExitTimeout(control)
	end
	]]
end

function dropdownClass:OnMouseExitTimeout(control)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:OnMouseExitTimeout - control: " .. tos(getControlName(control)))
	setTimeout(function()
		self.owner:HideOnMouseExit(moc())
	end)
end

function dropdownClass:OnEntrySelected(control, button, upInside)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:OnEntrySelected - control: %s, button: %s, upInside: %s", tos(getControlName(control)), tos(button), tos(upInside))

	local data = getControlData(control)
	if data.enabled then
		if data.enabled and not runHandler(handlerFunctions['onMouseUp'], control, data, button, upInside) then
			--d(">not runHandler: onMouseUp -> Calling zo_comboBoxDropdown_onEntrySelected")
			zo_comboBoxDropdown_onEntrySelected(self, control)
		end

		if upInside then
			if button == MOUSE_BUTTON_INDEX_RIGHT then
				if data.contextMenuCallback then
					dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:OnEntrySelected - contextMenuCallback!")
					data.contextMenuCallback(control)
				elseif g_contextMenu:IsDropdownVisible() then
					ClearCustomScrollableMenu()
				end
			end
		end
	--else
		--d("[LSM]dropdownClass:OnEntrySelected-name: ".. getControlName(control) .. " NOT ENABLED!")
		--todo: Still fires the dropdown hide then via global on mouse down/up handler?
		--todo header entryType does not do that!
	end
end

function dropdownClass:SelectItemByIndex(index, ignoreCallback)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:SelectItemByIndex - index: %s, ignoreCallback: %s,", tos(index), tos(ignoreCallback))
	if self.owner then
		playSelectedSoundCheck(self)
		return self.owner:SelectItemByIndex(index, ignoreCallback)
	end
end

local function createScrollableComboBoxEntry(self, item, index, entryType)
	dLog(LSM_LOGTYPE_VERBOSE, "createScrollableComboBoxEntry - index: %s, entryType: %s,", tos(index), tos(entryType))
	local entryData = ZO_EntryData:New(item)
	entryData.m_index = index
	entryData.m_owner = self.owner
	entryData.m_dropdownObject = self
	entryData:SetupAsScrollListDataEntry(entryType)
	return entryData
end

function dropdownClass:SetupEntryLabel(labelControl, data)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:SetupEntryLabel - labelControl: %s", tos(getControlName(labelControl)))
	labelControl:SetText(data.label or data.name) -- Use alternative passed in label string, or the default mandatory name string
	labelControl:SetFont(self.owner:GetDropdownFont())
	local color = self.owner:GetItemNormalColor(data)
	labelControl:SetColor(color:UnpackRGBA())
	labelControl:SetHorizontalAlignment(self.horizontalAlignment)
end

function dropdownClass:Show(comboBox, itemTable, minWidth, maxHeight, spacing)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:Show - comboBox: %s, minWidth: %s, maxHeight: %s, spacing: %s", tos(getControlName(comboBox:GetContainer())), tos(minWidth), tos(maxHeight), tos(spacing))
	self.owner = comboBox
	
	ZO_ScrollList_Clear(self.scrollControl)

	self:SetSpacing(spacing)

	local numItems = #itemTable
	local dataList = ZO_ScrollList_GetDataList(self.scrollControl)

	local largestEntryWidth = 0
	local allItemsHeight = 0
	for i = 1, numItems do
		local item = itemTable[i]
		if verifyLabelString(item) then
			local isLastEntry = i == numItems
			local entryHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT
			local entryType = ENTRY_ID
			local widthPadding = 0
			if self.customEntryTemplateInfos and item.customEntryTemplate then
				local templateInfo = self.customEntryTemplateInfos[item.customEntryTemplate]
				if templateInfo then
					entryType = templateInfo.typeId
					entryHeight = templateInfo.entryHeight
					 -- for static width padding beyond string length, such as submenu icon
					widthPadding = templateInfo.widthPadding or 0

					-- If the entry has an icon, or isNew, we add the row height to adjust for icon size.
					local iconPadding = (item.isNew or item.icon) and entryHeight or 0
					widthPadding = widthPadding + iconPadding
				end
			end

			if isLastEntry then
				--entryTypes are added via ZO_ScrollList_AddDataType and there always exists 1 respective "last" entryType too,
				--which handles the spacing at the last (most bottom) list entry to be different compared to the normal entryType
				entryType = entryType + 1
			else
				entryHeight = entryHeight + self.spacing
			end

			allItemsHeight = allItemsHeight + entryHeight

			local entry = createScrollableComboBoxEntry(self, item, i, entryType)
			tins(dataList, entry)

			local fontObject = self.owner:GetDropdownFontObject()
			--Check string width of label (alternative text to show at entry) or name (internal value used)
			local nameWidth = GetStringWidthScaled(fontObject, item.label or item.name, 1, SPACE_INTERFACE) + widthPadding
			if nameWidth > largestEntryWidth then
				largestEntryWidth = nameWidth
			end
		end
	end
	
	-- using the exact width of the text can leave us with pixel rounding issues
	-- so just add 5 to make sure we don't truncate at certain screen sizes
	largestEntryWidth = largestEntryWidth + 5

	-- Add padding one more time to account for potential pixel rounding issues that could cause the scroll bar to appear unnecessarily.
	allItemsHeight = allItemsHeight + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2) + ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y

	local desiredHeight = maxHeight
	ApplyTemplateToControl(self.scrollControl.contents, getScrollContentsTemplate(allItemsHeight < desiredHeight))
	if allItemsHeight < desiredHeight then
		desiredHeight = allItemsHeight
	end

	-- Allow the dropdown to automatically widen to fit the widest entry, but
	-- prevent it from getting any skinnier than the container's initial width
	local totalDropDownWidth = largestEntryWidth + (ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2) + ZO_SCROLL_BAR_WIDTH
	if totalDropDownWidth > minWidth then
		self.control:SetWidth(totalDropDownWidth)
	else
		self.control:SetWidth(minWidth)
	end

	dLog(LSM_LOGTYPE_VERBOSE, ">totalDropDownWidth: %s, allItemsHeight: %s, desiredHeight: %s", tos(totalDropDownWidth), tos(allItemsHeight), tos(desiredHeight))


	ZO_Scroll_SetUseFadeGradient(self.scrollControl, not self.owner.disableFadeGradient )
	self.control:SetHeight(desiredHeight)

	ZO_ScrollList_SetHeight(self.scrollControl, desiredHeight)
	ZO_ScrollList_Commit(self.scrollControl)
	self:OnShown()
end

function dropdownClass:UpdateHeight()
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:UpdateHeight")
	if self.owner then
		self.owner:UpdateHeight()
	end
end

function dropdownClass:OnShown()
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:OnShown")
	self.control:BringWindowToTop()

	--Check for context menu and submenu, and do narration
	updateIsContextMenuAndIsSubmenu(self)
	if not self.isContextMenu and not self.isSubmenu == true then
		local control = self.control
		self:Narrate("OnMenuShow", control)
		lib:FireCallbacks('OnMenuShow', control)
		dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: OnMenuShow - control: " ..tos(getControlName(control)))
	end
end

function dropdownClass:ShowSubmenu(control)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:ShowSubmenu - control: " ..tos(getControlName(control)))
	if self.owner then
		-- Must clear now. Otherwise, moving onto a submenu will close it from exiting previous row.
		clearTimeout()
		self.owner:ShowSubmenu(control)
	end
end

function dropdownClass:ShowTooltip(control, data)
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:ShowTooltip - control: %s, hasSubmenu: %s", tos(getControlName(control)), tos(data.hasSubmenu))
	showTooltip(self, control, data, data.hasSubmenu)
end

function dropdownClass:HideDropdown()
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:HideDropdown")
	if self.owner then
		self.owner:HideDropdown()
		if not self.isContextMenu and not self.isSubmenu then
			local containerCtrl = self.m_container
			lib:FireCallbacks('OnMenuHide', containerCtrl)
			dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: OnMenuHide - control: " ..tos(getControlName(containerCtrl)))
		end
	end
end

function dropdownClass:HideSubmenu()
	dLog(LSM_LOGTYPE_VERBOSE, "dropdownClass:HideSubmenu")
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end
end


--------------------------------------------------------------------
-- ComboBox classes
--------------------------------------------------------------------

--------------------------------------------------------------------
-- comboBox base
--------------------------------------------------------------------

local comboBox_base = ZO_ComboBox:Subclass()
local submenuClass = comboBox_base:Subclass()

function comboBox_base:Initialize(parent, comboBoxContainer, options, depth)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:Initialize - parent: %s, comboBoxContainer: %s, depth: %s", tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth))
	self.m_sortedItems = {}
	self.m_unsortedItems = {}
	self.m_container = comboBoxContainer
	local dropdownObject = self:GetDropdownObject(comboBoxContainer, depth)
	self:SetDropdownObject(dropdownObject)

	self:UpdateOptions(options, true)
	self:UpdateHeight()
end


function comboBox_base:UpdateHeight()
	local maxRows = self:GetMaxRows()

	-- Add padding to each row then subtract padding for last row
	local spacing = self.m_spacing or 0
	local baseEntryHeight = self.baseEntryHeight
	local maxHeight = ((baseEntryHeight + spacing) * maxRows) - spacing + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2)

	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:UpdateHeight - maxHeight: %s, baseEntryHeight: %s, maxRows: %s, spacing: %s", tos(maxHeight), tos(baseEntryHeight), tos(maxRows), tos(spacing))

	self:SetHeight(maxHeight)
end



-- Common functions
-- Adds the customEntryTemplate to all items added
function comboBox_base:AddItem(itemEntry, updateOptions, templates)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:AddItem - itemEntry: %s, updateOptions: %s, templates: %s", tos(updateOptions), tos(self.baseEntryHeight), tos(templates))
	addItem_Base(self, itemEntry)
	zo_comboBox_base_addItem(self, itemEntry, updateOptions)
	tins(self.m_unsortedItems, itemEntry)
end

-- Adds widthPadding as a valid parameter
function comboBox_base:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:AddCustomEntryTemplate - entryTemplate: %s, entryHeight: %s, setupFunction: %s, widthPadding: %s", tos(entryTemplate), tos(entryHeight), tos(setupFunction), tos(widthPadding))
	if not self.m_customEntryTemplateInfos then
		self.m_customEntryTemplateInfos = {}
	end

	local customEntryInfo =
	{
		entryTemplate = entryTemplate,
		entryHeight = entryHeight,
		widthPadding = widthPadding,
		setupFunction = setupFunction,
	}

	self.m_customEntryTemplateInfos[entryTemplate] = customEntryInfo

	self.m_dropdownObject:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
end

-- >> template, height, setupFunction
local function getTemplateData(entryType, template)
	dLog(LSM_LOGTYPE_VERBOSE, "getTemplateData - entryType: %s, template: %s", tos(entryType), tos(template))
	local templateDataForEntryType = template[entryType]
	return templateDataForEntryType.template, templateDataForEntryType.rowHeight, templateDataForEntryType.setupFunc, templateDataForEntryType.widthPadding
end

function comboBox_base:AddCustomEntryTemplates(options)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:AddCustomEntryTemplates - options: %s", tos(options))
	local defaultXMLTemplates  = {
		[ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntryLabel(control, data, list)
			end,
		},
		[SUBMENU_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxSubmenuEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthPadding = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntrySubmenu(control, data, list)
			end,
		},
		[DIVIDER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxDividerEntry',
			rowHeight = DIVIDER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntryDivider(control, data, list)
			end,
		},
		[HEADER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxHeaderEntry',
			rowHeight = HEADER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntryHeader(control, data, list)
			end,
		},
		[CHECKBOX_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxCheckboxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupCheckbox(control, data, list)
			end,
		},
	}
	
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
	self:AddCustomEntryTemplate(getTemplateData(ENTRY_ID, self.XMLrowTemplates))
	self:AddCustomEntryTemplate(getTemplateData(SUBMENU_ENTRY_ID, self.XMLrowTemplates))
	self:AddCustomEntryTemplate(getTemplateData(DIVIDER_ENTRY_ID, self.XMLrowTemplates))
	self:AddCustomEntryTemplate(getTemplateData(HEADER_ENTRY_ID, self.XMLrowTemplates))
	self:AddCustomEntryTemplate(getTemplateData(CHECKBOX_ENTRY_ID, self.XMLrowTemplates))
	
	-- TODO: we should not rely on these anymore. Instead we should attach them to self if they are still needed
	SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = self.XMLrowTemplates[ENTRY_ID].rowHeight
	DIVIDER_ENTRY_HEIGHT = self.XMLrowTemplates[DIVIDER_ENTRY_ID].rowHeight
	HEADER_ENTRY_HEIGHT = self.XMLrowTemplates[HEADER_ENTRY_ID].rowHeight
	
	-- We will use this, per-comboBox, to set max rows.
	self.baseEntryHeight = self.XMLrowTemplates[ENTRY_ID].rowHeight

	dLog(LSM_LOGTYPE_VERBOSE, ">SCROLLABLE_ENTRY_TEMPLATE_HEIGHT: %s, DIVIDER_ENTRY_HEIGHT: %s, HEADER_ENTRY_HEIGHT: %s, baseEntryHeight: %s", tos(SCROLLABLE_ENTRY_TEMPLATE_HEIGHT), tos(DIVIDER_ENTRY_HEIGHT), tos(HEADER_ENTRY_HEIGHT), tos(self.baseEntryHeight))
end

function comboBox_base:GetDropdownControl()
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:GetDropdownControl")
	if self.m_dropdownObject then
		return self.m_dropdownObject.control
	end
end

function comboBox_base:GetDropdownObject(comboBoxContainer, depth)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:GetDropdownObject - comboBoxContainer: %s, depth: %s", tos(getControlName(comboBoxContainer)), tos(depth))
	self.m_nextFree = depth + 1
	return dropdownClass:New(self, comboBoxContainer, depth)
end

-- Create the m_dropdownObject on initialize.
function comboBox_base:GetOptions()
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:GetOptions")
	return self.options
end

-- Get or create submenu
function comboBox_base:GetSubmenu()
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:GetSubmenu")
	if not self.m_submenu then
		self.m_submenu = submenuClass:New(self, self.m_container, self.options, self.m_nextFree)
	end
	return self.m_submenu
end

-- Changed to hide tooltip and, if available, it's submenu
-- We hide the tooltip here so it is hidden if the dropdown is hidden OnGlobalMouseUp
function comboBox_base:HideDropdown()
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:HideDropdown")
	-- Recursive through all open submenus and close them starting from last.
--	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
	if self.m_submenu then
		self.m_submenu:HideDropdown()
	end
	zo_comboBox_base_hideDropdown(self)

	--Narrate the OnMenuHide texts
	local function narrateOnMenuHideButOnlyOnceAsHideDropdownIsCalledTwice()
		dLog(LSM_LOGTYPE_VERBOSE, "narrateOnMenuHideButOnlyOnceAsHideDropdownIsCalledTwice")
		updateIsContextMenuAndIsSubmenu(self)
		if self.narrateData and self.narrateData["OnMenuHide"] then
	--d(">narrate OnMenuHide-isContextMenu: " ..tos(self.isContextMenu) .. ", isSubmenu: " .. tos(self.isSubmenu))
			if not self.isContextMenu and not self.isSubmenu then
				local containerCtrl = self.m_container
				self:Narrate("OnMenuHide", containerCtrl)
			end
		end
	end
	onUpdateDoNarrate("OnMenuHide_Start", 25, narrateOnMenuHideButOnlyOnceAsHideDropdownIsCalledTwice)
end

function comboBox_base:IsMouseOverScrollbarControl()
	local mocCtrl = moc()
	if mocCtrl ~= nil then
		local owner = mocCtrl.owner
		dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:IsMouseOverScrollbarControl > " ..tos(owner and owner.scrollbar ~= nil))
		return owner and owner.scrollbar ~= nil
	end
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:IsMouseOverScrollbarControl > No")
	return false
end

function comboBox_base:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:Narrate - eventName: %s, ctrl: %s, hasSubmenu: %s, anchorPoint: %s ", tos(eventName), tos(getControlName(ctrl)), tos(hasSubmenu), tos(anchorPoint))
	local narrateData = self.narrateData
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

	dLog(LSM_LOGTYPE_VERBOSE, ">narrateText: %s, stopCurrent: %s", tos(narrateText), tos(stopCurrent))
	--Didn't the addon take care of the narration itsself? So this library here should narrate the text returned
	if type(narrateText) == "string" then
		local narrateFuncOfLibrary = narrationEventToLibraryNarrateFunction[eventName]
		if narrateFuncOfLibrary == nil then return end
		narrateFuncOfLibrary(narrateText, stopCurrent)
	end
end

-- used for onMouseEnter[submenu] and onMouseUp[contextMenu]
function comboBox_base:ShowDropdownOnMouseAction(parentControl)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:ShowDropdownOnMouseAction - parentControl: %s " .. tos(getControlName(parentControl)))
	if self:IsDropdownVisible() then
		-- If submenu was currently opened, close it so it can reset.
		self:HideDropdown()
	end

	self.m_dropdownObject:SetHidden(false)
	self:AddMenuItems(parentControl)
	self:ShowDropdown()

	self:SetVisible(true)
end

function comboBox_base:ShowSubmenu(parentControl)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:ShowSubmenu - parentControl: %s " .. tos(getControlName(parentControl)))
	-- We don't want a submenu to open under the context menu or it's submenus.
	if g_contextMenu:IsDropdownVisible() then
		g_contextMenu:HideDropdown()
	end

	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

-- These are part of the m_dropdownObject but, since we now use them from the comboBox, 
-- they are added here to reference the ones in the m_dropdownObject.
function comboBox_base:IsMouseOverControl()
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:IsMouseOverControl: " .. tos(self.m_dropdownObject:IsMouseOverControl()))
	return self.m_dropdownObject:IsMouseOverControl()
end

function comboBox_base:RefreshSortedItems(parentControl)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:RefreshSortedItems - parentControl: %s", tos(getControlName(parentControl)))
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)

	local entries = self:GetEntries()
	for _, item in ipairs(entries) do
		item.m_parentControl = parentControl
		-- update strings by functions will be done in AddItem
		self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
	end
end

function comboBox_base:SetupEntryBase(control, data, list)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:SetupEntryBase - control: " .. tos(getControlName(control)))
	self.m_dropdownObject:SetupEntryBase(control, data, list)

	control.closeOnSelect = control.selectable and data.callback ~= nil or false
end

do -- Row setup functions
	local function applyEntryFont(control, font, color, horizontalAlignment)
		dLog(LSM_LOGTYPE_VERBOSE, "applyEntryFont - control: %s, font: %s, color: %s, horizontalAlignment: %s", tos(getControlName(control)), tos(font), tos(color), tos(horizontalAlignment))
		if font then
			control.m_label:SetFont(font)
		end
		
		if color then
			control.m_label:SetColor(color:UnpackRGBA())
		end
		
		if horizontalAlignment then
			control.m_label:SetHorizontalAlignment(horizontalAlignment)
		end
	end

	local function addIcon(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "addIcon - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		control.m_iconContainer = control.m_iconContainer or control:GetNamedChild("IconContainer")
		local iconContainer = control.m_iconContainer
		control.m_icon = control.m_icon or iconContainer:GetNamedChild("Icon")
		updateIcons(control, data)
	end

	local function addArrow(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "addArrow - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		control.m_arrow = control:GetNamedChild("Arrow")
		data.hasSubmenu = true
	end

	local function addDivider(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "addDivider - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		control.m_divider = control:GetNamedChild("Divider")
	end

	local function addLabel(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "addLabel - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		control.m_label = control.m_label or control:GetNamedChild("Label")

		control.m_label:SetText(data.label or data.name) -- Use alternative passed in label string, or the default mandatory name string
	end
	
	function comboBox_base:SetupEntryDivider(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:SetupEntryDivider - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		control.typeId = DIVIDER_ENTRY_ID
		addDivider(control, data, list)
		self:SetupEntryBase(control, data, list)
	end

	function comboBox_base:SetupEntryLabelBase(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:SetupEntryLabelBase - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		local font = getValueOrCallback(data.font, data)
		font = font or self:GetDropdownFont()
		
		local color = getValueOrCallback(data.color, data)
		color = color or self:GetItemNormalColor(data)
		
		local horizontalAlignment = getValueOrCallback(data.horizontalAlignment, data)
		horizontalAlignment = horizontalAlignment or self.horizontalAlignment
		
		applyEntryFont(control, font, color, horizontalAlignment)
		self:SetupEntryBase(control, data, list)
	end
	
	function comboBox_base:SetupEntryLabel(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:SetupEntryLabel - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		control.typeId = ENTRY_ID
		addIcon(control, data, list)
		addLabel(control, data, list)
		self:SetupEntryLabelBase(control, data, list)
	end

	function comboBox_base:SetupEntrySubmenu(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:SetupEntrySubmenu - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		self:SetupEntryLabel(control, data, list)
		addArrow(control, data, list)
		control.typeId = SUBMENU_ENTRY_ID
	end

	function comboBox_base:SetupEntryHeader(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:SetupEntryHeader - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		addDivider(control, data, list)
		self:SetupEntryLabel(control, data, list)
		control.isHeader = true
		control.typeId = HEADER_ENTRY_ID
	end

	function comboBox_base:SetupCheckbox(control, data, list)
		dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:SetupCheckbox - control: %s, list: %s,", tos(getControlName(control)), tos(list))
		local function setChecked(checkbox, checked)
			local checkedData   = ZO_ScrollList_GetData(checkbox:GetParent())
			
			checkedData.checked = checked
			if checkedData.callback then
				dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:SetupCheckbox - calling checkbox callback, control: %s, checked: %s, list: %s,", tos(getControlName(control)), tos(checked), tos(list))
				checkedData.callback(checked, checkedData)
			end
			
			self:Narrate("OnCheckboxUpdated", checkbox, checkedData, nil)
			lib:FireCallbacks('CheckboxUpdated', checked, checkedData, checkbox)
			dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: CheckboxUpdated - control: %q, checked: %s", tos(getControlName(checkbox)), tos(checked))
		end
		
		self:SetupEntryLabel(control, data, list)
		control.isCheckbox = true

		control.typeId = CHECKBOX_ENTRY_ID
		
		control.m_checkbox = control.m_checkbox or control:GetNamedChild("Checkbox")
		local checkbox = control.m_checkbox
		ZO_CheckButton_SetToggleFunction(checkbox, setChecked)
		ZO_CheckButton_SetCheckState(checkbox, getValueOrCallback(data.checked, data))
	end
end

-- Blank
function comboBox_base:GetMaxRows()
	-- Overwrite at subclasses
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:GetMaxRows")
end

function comboBox_base:UpdateOptions(options, onInit)
	-- Overwrite at subclasses
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:UpdateOptions - options: %s, onInit: %s", tos(options), tos(onInit))
end

function comboBox_base:BypassOnGlobalMouseUp(button)
	-- Overwrite at subclasses
end

function comboBox_base:OnGlobalMouseUp(eventCode, ...)
	-- Overwrite at subclasses
end

--------------------------------------------------------------------
-- comboBoxClass
--------------------------------------------------------------------
local comboBoxClass = comboBox_base:Subclass()

-- comboBoxClass:New(To simplify locating the beginning of the class
function comboBoxClass:Initialize(parent, comboBoxContainer, options, depth, initExistingComboBox)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:Initialize - parent: %s, comboBoxContainer: %s, depth: %s", tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth))
	comboBoxContainer.m_comboBox = self

	--Reset to the default ZO_ComboBox variables
	self:ResetToDefaults(initExistingComboBox)

	-- Add all comboBox defaults not present.
	self.m_name = comboBoxContainer:GetName()
	self.m_openDropdown = comboBoxContainer:GetNamedChild("OpenDropdown")
	self.m_containerWidth = comboBoxContainer:GetWidth()
	self.m_selectedItemText = comboBoxContainer:GetNamedChild("SelectedItemText")
	self.m_multiSelectItemData = {}
	comboBox_base.Initialize(self, parent, comboBoxContainer, options, depth)
	
	return self
end

-- [Replaced functions]

-- Changed to force updating items and, to set anchor since anchoring was removed from :Show( due to separate anchoring based on comboBox type. (comboBox to self /submenu to row/contextMenu to mouse)
function comboBoxClass:AddMenuItems()
	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:AddMenuItems")
	self:UpdateItems()
	self:UpdateHeight()
	self.m_dropdownObject:AnchorToComboBox(self)
	
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
end

function comboBoxClass:BypassOnGlobalMouseUp(button, ...)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBox_base:BypassOnGlobalMouseUp - button: %s, isMouseOverScrollbar: %s", tos(button), tos(self:IsMouseOverScrollbarControl()))

	if onGlobalMouseLeftUp(self, button, ...) then
		return true
	else
		if g_contextMenu:IsDropdownVisible() then
			-- to prevent a context menu selection from closing the comboBox
			return true
		end
	end

	--Any other right mouse click -> Stay opened!
	return button == MOUSE_BUTTON_INDEX_RIGHT
end

function comboBoxClass:OnGlobalMouseUp(eventCode, ...)
	if not self:BypassOnGlobalMouseUp(...) then
		if self:IsDropdownVisible() then
			self:HideDropdown()
		else
			if self.m_container:IsHidden() then
				self:HideDropdown()
			else
				-- If shown in ShowDropdownInternal, the global mouseup will fire and immediately dismiss the combo box. We need to
				-- delay showing it until the first one fires.
				self:ShowDropdownOnMouseUp()
			end
		end
	else

		local mocCtrl = moc()
		if mocCtrl == self.m_container and self:IsDropdownVisible() then
			-- hide dropdown if comboBox is right-clicked
			self:HideDropdown()
		end
	end
end


-- [New functions]
function comboBoxClass:GetMaxRows()
	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:GetMaxRows: " .. tos(self.visibleRows or DEFAULT_VISIBLE_ROWS))
	return self.visibleRows or DEFAULT_VISIBLE_ROWS
end

function comboBoxClass:GetMenuPrefix()
	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:GetMenuPrefix: Menu")
	return 'Menu'
end

function comboBoxClass:HideOnMouseEnter()
	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:HideOnMouseEnter")
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() and not self:IsMouseOverControl() then
		self.m_submenu:HideDropdown()
	end
end

function comboBoxClass:HideOnMouseExit(mocCtrl)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:HideOnMouseExit")
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() and not self.m_submenu:IsMouseOverOpeningControl() then
--d(">submenu found, but mouse not over it! HideDropdown")
		self.m_submenu:HideDropdown()
		return true
	end
end

--Update the comboBox's attribute/functions with a value returned from the applied custom options of the LSM, or with
--ZO_ComboBox default options (set at self:ResetToDefaults())
function comboBoxClass:SetOption(LSMOptionsKey)
	--Old code: Updating comboBox[key] with the newValue
	local options = self.options
	--Get current value
	local currentZO_ComboBoxValueKey = LSMOptionsKeyToZO_ComboBoxOptionsKey[LSMOptionsKey]
	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:SetOption . key: %s, ZO_ComboBox[key]: %s", tos(LSMOptionsKey), tos(currentZO_ComboBoxValueKey))
	if currentZO_ComboBoxValueKey == nil then return end
	local currentValue = self[currentZO_ComboBoxValueKey]

	--Get new value via options passed in
	local newValue = getValueOrCallback(options[LSMOptionsKey], options) --read new value from the options (run function there or get the value)
	if newValue == nil then
		newValue = currentValue
	end
	if newValue == nil then return end

	--Filling the self.updatedOptions table with values so they can be used in the callback functions (if any is given)
	self.updatedOptions[LSMOptionsKey] = newValue

	--Do we need to run a callback function to set the updated value?
	local setOptionFuncOrKey = LSMOptionsToZO_ComboBoxOptionsCallbacks[LSMOptionsKey]
	if type(setOptionFuncOrKey) == "function" then
		setOptionFuncOrKey(self, newValue)
	else
		self[currentZO_ComboBoxValueKey] = newValue
	end
end

function comboBoxClass:UpdateOptions(options, onInit)
	onInit = onInit or false
	local optionsChanged = self.optionsChanged

	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:UpdateOptions . options: %s, onInit: %s, optionsChanged: %s", tos(options), tos(onInit), tos(optionsChanged))

	--Called from Initialization of the object -> self:ResetToDefaults() was called in comboBoxClass:Initialize() already
	-->And self:UpdateOptions() is then called via comboBox_base.Initialize(...), from where we get here
	if onInit == true then
		--Do not change any other options, just init. the combobox -> call self:AddCustomEntryTemplates(options) ands set
		--optionsChanged to false (self.options will be nil at that time)
		optionsChanged = false
	else
		--self.optionsChanged might have been set by contextMenuClass:SetOptions(options) already. Check that first and keep that boolean state as we
		--do not use self.options but self.optionsData here:
		--->Coming from contextMenuClass:ShowContextMenu() -> self.optionsData was set via contextMenuClass:SetOptions(options) before, and will be passed in here
		--->to UpdateOptions(options) as options parameter. self.optionsChanged will be true if the options changed at the contex menu (compared to old self.optionsData)
		---->self.optionsData  is then used at OnShow of the context menu. That's why we cannot compare the self.options here!
		--
		--For other "non-context menu" calls: Compare the already stored self.options table to the new passed in options table (both could be nil though)
		optionsChanged = optionsChanged or options ~= self.options
	end

	--(Did the options change: Yes / OR are we initializing a ZO_ComboBox ) / AND Are the new passed in options nil or empty: Yes
	--> Reset to default ZO_ComboBox variables and just call AddCustomEntryTemplates()
	if (optionsChanged == true or onInit == true) and ZO_IsTableEmpty(options) then
		optionsChanged = false
		self:ResetToDefaults() -- Reset comboBox internal variables of ZO_ComboBox, e.g. m_font, and LSM defaults like visibleRowsDropdown

	--Did the options change: Yes / OR Are the already stored options at the object nil or empty (should happen if self:UpdateOptions(options) was not called before): Yes
	--> Use passed in options, or use the default ZO_ComboBox options added via self:ResetToDefaults() before
	elseif optionsChanged == true or ZO_IsTableEmpty(self.options) then
		optionsChanged = false

		--Create empty table options, if nil
		options = options or {}

		-- Backwards compatiblity for the time when options was no table bu just 1 variable "visibleRowsDropdown"
		if type(options) ~= 'table' then
			options = { visibleRowsDropdown = options }
		end

		--Set the passed in options to the ZO_ComboBox .options table (for future comparison, see above at optionsChanged = optionsChanged or options ~= self.options)
		self.options = options

		--Clear the table with options which got updated. Will be filled in self:SetOption(key) method
		self.updatedOptions = {}

		-- Defaults are predefined in defaultComboBoxOptions, but they will be taken from ZO_ComboBox defaults set from table comboBoxDefaults
		-- at function self:ResetToDefaults().
		-- If any variable was set to the ZO_ComboBox already (e.g. self.m_font) it will be used again from that internal variable, if nothing
		-- was overwriting it here from passed in options table

		-- LibScrollableMenu custom options
		for key, _ in pairs(options) do
			self:SetOption(key)
		end

		--Reset the table with options which got updated
		self.updatedOptions = nil
	end

	-- this will add custom and default templates to self.XMLrowTemplates the same way dataTypes were created before.
	self:AddCustomEntryTemplates(options)
end


--Reset internal default values like m_font or LSM defaults liek visibleRowsDropdown
-->If called from init function of API AddCustomScrollableComboBoxDropdownMenu: Keep existing ZO default (or changed by addons) entries of the ZO_ComboBox and only reset missing ones
-->If called later from e.g. UpdateOptions function where options passed in are nil or empty: Reset all to LSM default values
--->In all cases the function comboBoxClass:UpdateOptions should update the options needed!
function comboBoxClass:ResetToDefaults(keepExisting)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:ResetToDefaults")
	local defaults = ZO_DeepTableCopy(comboBoxDefaults)
	if keepExisting then
		mixinTableAndSkipExisting(self, defaults) --keep existing ZO_ComboBox default (or addon changed) values -> e.g. add a LSM helper to an exisitng ZO_ComboBox via AddCustomScrollableComboBoxDropdownMenu
	else
		zo_mixin(self, defaults) -- overwrite existing ZO_ComboBox default values with LSM defaults
	end
	self.options = nil
end


--------------------------------------------------------------------
-- submenuClass
--------------------------------------------------------------------

-- Pass-through variables
local submenuClass_exposedVariables = {
	-- ZO_ComboBox
	["m_font"] = true, -- 
	["m_height"] = false, -- needs to be separate for visibleRowsSubmenu
	['m_normalColor'] = true, -- 
	['m_highlightColor'] = true, -- 
	['m_containerWidth'] = true, -- 
	['m_maxNumSelections'] = true, -- 
	['m_enableMultiSelect'] = true, -- 
	["m_customEntryTemplateInfos"] = false, -- Allowing this to paas-through would break row setup.
	
	-- ZO_ComboBox_Base
	["m_name"] = true, -- since the name is acquired by the container name.
	["m_spacing"] = true, -- 
	["m_sortType"] = true, -- 
	["m_container"] = true, -- all children use the same container as the comboBox
	["m_sortOrder"] = true, -- 
	["m_sortsItems"] = true, -- 
	["m_sortedItems"] = false, -- for obvious reasons
	["m_openDropdown"] = false, -- control
	["m_selectedColor"] = true, -- 
	["m_disabledColor"] = true, -- 
	["m_selectedItemText"] = false, -- This is handeled by "SelectItem"
	["m_selectedItemData"] = false, -- This is handeled by "SelectItem"
	["m_isDropdownVisible"] = false, -- each menu has different dropdowns
	["m_preshowDropdownFn"] = true, -- 
	["horizontalAlignment"] = true, -- 
	
	-- LibScrollableMenu
	['options'] = true,
	['narrateData'] = true,
	['m_headerFont'] = true,
	['XMLrowTemplates'] = true, --TODO: is this being overwritten?
	['m_headerFontColor'] = true,
	['visibleRowsSubmenu'] = true, -- we only need this "visibleRowsSubmenu" for the submenus
	['disableFadeGradient'] = true,
}


local submenuClass_exposedFunctions = {
	["SelectItem"] = true, -- (item, ignoreCallback)
}


function submenuClass:New(...)
	local newObject = setmetatable({},  {
		__index = function (obj, key)
			if submenuClass_exposedVariables[key] then
				local value = obj.m_comboBox[key]
				if value then
					return value
				end
			end

			local value = submenuClass[key]
			if value then
				if submenuClass_exposedFunctions[key] then
					return function(self, ...)
						return value(self.m_comboBox, ...)
					end
				end

				return value
			end


		end
	})

	newObject.__parentClasses = {self}
	newObject:Initialize(...)
	return newObject
end

-- submenuClass:New(To simplify locating the beginning of the class
function submenuClass:Initialize(parent, comboBoxContainer, options, depth)
	dLog(LSM_LOGTYPE_VERBOSE, "submenuClass:Initialize - parent: %s, comboBoxContainer: %s, depth: %s", tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth))
	self.m_comboBox = comboBoxContainer.m_comboBox
	self.isSubmenu = true
	self.m_parentMenu = parent
	
	comboBox_base.Initialize(self, parent, comboBoxContainer, options, depth)
end

function submenuClass:UpdateOptions(options, onInit)
	dLog(LSM_LOGTYPE_VERBOSE, "submenuClass:UpdateOptions - options: %s, onInit: %s", tos(options), tos(onInit))
	self:AddCustomEntryTemplates(self.options)
end

function submenuClass:AddMenuItems(parentControl)
	dLog(LSM_LOGTYPE_VERBOSE, "submenuClass:AddMenuItems - parentControl: %s", tos(getControlName(parentControl)))
	self.openingControl = parentControl
	self:RefreshSortedItems(parentControl)
	
	self:UpdateItems()
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())

	self.m_dropdownObject:AnchorToControl(parentControl)
end

function submenuClass:GetEntries()
	local data = getControlData(self.openingControl)

	local entries = getValueOrCallback(data.entries, data)
	return entries or {}
end

function submenuClass:GetMaxRows()
	dLog(LSM_LOGTYPE_VERBOSE, "submenuClass:GetMaxRows: " .. tos(self.visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS))
	return self.visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS
end

function submenuClass:GetMenuPrefix()
	dLog(LSM_LOGTYPE_VERBOSE, "submenuClass:GetMenuPrefix: SubMenu")
	return 'SubMenu'
end

function submenuClass:ShowDropdownInternal()
	dLog(LSM_LOGTYPE_VERBOSE, "submenuClass:ShowDropdownInternal")
	if self.m_dropdownObject then
		local control = self.m_dropdownObject.control
		control:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self:OnGlobalMouseUp(...) end)
	end
end

function submenuClass:HideDropdownInternal()
	-- m_container for a fallback
	local control = self.m_container
	if self.m_dropdownObject then
		control = self.m_dropdownObject.control
		control:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)
	end
	
	updateIsContextMenuAndIsSubmenu(self)
	dLog(LSM_LOGTYPE_VERBOSE, "submenuClass:HideDropdownInternal-isContextMenu: " .. tos(self.isContextMenu))

	if not self.isContextMenu then
		self:Narrate("OnSubMenuHide", control)
		lib:FireCallbacks('OnSubMenuHide', control)
		dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: OnSubMenuHide - control: " ..tos(getControlName(control)))
	end

--d(">m_dropdownObject:IsOwnedByComboBox: " ..tos(self.m_dropdownObject:IsOwnedByComboBox(self)))

	if self.m_dropdownObject:IsOwnedByComboBox(self) then
		self.m_dropdownObject:SetHidden(true)
	end
	self:SetVisible(false)
	if self.onHideDropdownCallback then
		dLog(LSM_LOGTYPE_VERBOSE, ">submenuClass:HideDropdownInternal - onHideDropdownCallback called")
		self.onHideDropdownCallback()
	end
end

function submenuClass:HideOnMouseExit(mocCtrl)
	-- Only begin hiding if we stopped over a dropdown.
	mocCtrl = mocCtrl or moc()
	dLog(LSM_LOGTYPE_VERBOSE, "submenuClass:HideOnMouseExit - mocCtrl: %s", tos(getControlName(mocCtrl)))
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
--d("[LSM]submenuClass:IsMouseOverOpeningControl: " .. tos(MouseIsOver(self.openingControl)))
	return MouseIsOver(self.openingControl)
end

--------------------------------------------------------------------
-- contextMenuClass
--------------------------------------------------------------------

local contextMenuClass = comboBoxClass:Subclass()
-- LibScrollableMenu.contextMenu
-- contextMenuClass:New(To simplify locating the beginning of the class
function contextMenuClass:Initialize(comboBoxContainer)
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:Initialize - comboBoxContainer: %s", tos(getControlName(comboBoxContainer)))
	comboBoxClass.Initialize(self, nil, comboBoxContainer, nil, 1)
	self.data = {}
	
	self:ClearItems()

	self.isContextMenu = true
end

-- Renamed from AddItem since AddItem can be the same as base. This function is only to pre-set data for updating on show,
function contextMenuClass:AddContextMenuItem(itemEntry, updateOptions)
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:AddContextMenuItem - itemEntry: %s, updateOptions: %s", tos(itemEntry), tos(updateOptions))
	tins(self.data, itemEntry)
	
--	m_unsortedItems
end

function contextMenuClass:AddMenuItems()
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:AddMenuItems")
	self:RefreshSortedItems()
	self:UpdateItems()
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
	self.m_dropdownObject:AnchorToMouse()
	self.m_dropdownObject.control:BringWindowToTop()
end

function contextMenuClass:ClearItems()
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:ClearItems")
	self:SetOptions(nil)

	--Clear cached entries of LSM (which have been build based on ZO_Menu items)
	-->But only if we aren't currently in a ShowMenu() process where we build the entries in lib.ZO_MenuData (accross
	-->vanilla menus and addon added menu entries -> ShowMenu could be called several times then, and ClearMenu() [by LSM] too)
	if not lib.preventClearCustomScrollableMenuToClearZO_MenuData then
		lib.ZO_MenuData = {}
		lib.ZO_MenuData_CurrentIndex = 0
	end

	--Clear the ZO_Menu items if we clear the LSM context menu items?
	if lib.callZO_MenuClearMenuOnClearCustomScrollableMenu then
		lib.callZO_MenuClearMenuOnClearCustomScrollableMenu = false
d(">Calling ClearMenu() because of callZO_MenuClearMenuOnClearCustomScrollableMenu = true")
		ClearMenu()
	end

	ZO_ComboBox_HideDropdown(self:GetContainer())
	ZO_ClearNumericallyIndexedTable(self.data)
	
	self:SetSelectedItemText("")
	self.m_selectedItemData = nil
	self:OnClearItems()
end

function contextMenuClass:GetEntries()
	return self.data
end

function contextMenuClass:GetMenuPrefix()
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:GetMenuPrefix: Contextmenu")
	return 'Contextmenu'
end

function contextMenuClass:ShowSubmenu(parentControl)
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:ShowSubmenu - parentControl: %s", tos(getControlName(parentControl)))
	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

function contextMenuClass:ShowContextMenu(parentControl)
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:ShowContextMenu - parentControl: %s", tos(getControlName(parentControl)))
	self.openingControl = parentControl

	if parentControl.m_owner and parentControl.m_owner.m_submenu and parentControl.m_owner.m_submenu:IsDropdownVisible() then
		-- To prevent the context menu from overlapping a submenu it is not opened from,
		-- If the opening control is a dropdown and has a submenu visible, close the submenu.
		parentControl.m_owner.m_submenu:HideDropdown()
	end
	self:UpdateOptions(self.optionsData)

	-- Let the caller know that this is about to be shown...
	if self.m_preshowDropdownFn then
		self.m_preshowDropdownFn(self)
	end
	
	self:ShowDropdown()
--	self:ShowDropdownOnMouseUp()
end

function contextMenuClass:HideDropdownInternal()
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:HideDropdownInternal")
	comboBoxClass.HideDropdownInternal(self)
	self:ClearItems()
end

function contextMenuClass:SetOptions(options)
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:SetOptions - options: %s", tos(options))
	-- self.optionsData is only a temporary table used check for change and to send to UpdateOptions.
	self.optionsChanged = self.optionsData ~= options
	self.optionsData = options
end

function contextMenuClass:SetPreshowDropdownCallback()
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:SetPreshowDropdownCallback")
	-- Intentionally blank. This is to prevent abusing the function in the context menu.
end


function contextMenuClass:BypassOnGlobalMouseUp(button, ...)
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:BypassOnGlobalMouseUp - button: %s, isMouseOverScrollbar: %s", tos(button), tos(self:IsMouseOverScrollbarControl()))

	if not self:IsDropdownVisible() and button == MOUSE_BUTTON_INDEX_RIGHT then
		-- Needed to open the context menu
		return false
	end

	if onGlobalMouseLeftUp(self, button, ...) then
		return true
	end
	--Any other right mouse click -> Stay opened!
	return button == MOUSE_BUTTON_INDEX_RIGHT
end

function contextMenuClass:OnGlobalMouseUp(eventCode, ...)
	dLog(LSM_LOGTYPE_VERBOSE, "contextMenuClass:OnGlobalMouseUp - eventCode: %s", tos(eventCode))
	if not self:BypassOnGlobalMouseUp(...) then
		if self:IsDropdownVisible() then
			self:HideDropdown()
		else
			if self.m_container:IsHidden() then
				self:HideDropdown()
			else
				-- If shown in ShowDropdownInternal, the global mouseup will fire and immediately dismiss the combo box. We need to
				-- delay showing it until the first one fires.
				self:ShowDropdownOnMouseUp()
			end
		end
	end
end



--[[
function contextMenuClass:ShowDropdownOnMouseUp()
	if self:IsEnabled() then
		self.m_dropdownObject:SetHidden(false)
		self:AddMenuItems()

		self:SetVisible(true)
	else
		--If we get here, that means the dropdown was disabled after the request to show it was made, so just cancel showing entirely
		self.m_container:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)
	end
end
]]

--------------------------------------------------------------------
-- 
--------------------------------------------------------------------
-- We need to integrate a supplied ZO_ComboBox with the lib's functionality.
-- We do this by replacing the metatable with comboBoxClass.

function comboBoxClass:UpdateMetatable(parent, comboBoxContainer, options)
	dLog(LSM_LOGTYPE_VERBOSE, "comboBoxClass:UpdateMetatable - parent: %s, comboBoxContainer: %s, options: %s", tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(options))

	setmetatable(self, comboBoxClass)
	ApplyTemplateToControl(comboBoxContainer, 'LibScrollableMenu_ComboBox_Behavior')

--d("[LSM]FireCallbacks - OnDropdownMenuAdded - current visibleRows: " ..tostring(options.visibleRowsDropdown))
	lib:FireCallbacks('OnDropdownMenuAdded', self, options)
	dLog(LSM_LOGTYPE_DEBUG_CALLBACK, "FireCallbacks: OnDropdownMenuAdded - control: %s, options: %s", tos(getControlName(self.m_container)), tos(options))
	self:Initialize(parent, comboBoxContainer, options, 1, true)
end

--------------------------------------------------------------------
-- Public API functions
--------------------------------------------------------------------
lib.persistentMenus = false -- controls if submenus are closed shortly after the mouse exists them
							-- 2024-03-10 Currently not used anywhere!!!
function lib.GetPersistentMenus()
	dLog(LSM_LOGTYPE_DEBUG, "GetPersistentMenus: %s", tos(lib.persistentMenus))
	return lib.persistentMenus
end
function lib.SetPersistentMenus(persistent)
	dLog(LSM_LOGTYPE_DEBUG, "SetPersistentMenus - persistent: %s", tos(persistent))
	lib.persistentMenus = persistent
end


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--[API - Custom scrollable ZO_ComboBox menu]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--Adds a scrollable dropdown to the comboBoxControl, replacing the original dropdown, and enabling scrollable submenus (even with nested scrolable submenus)
--	control parent 							Must be the parent control of the comboBox
--	control comboBoxContainer 				Must be any ZO_ComboBox control (e.g. created from virtual template ZO_ComboBox)
--  table options:optional = {
--		number visibleRowsDropdown:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened dropdown
--		number visibleRowsSubmenu:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened submenus
--		boolean sortEntries:optional			Boolean or function returning boolean if items in the main-/submenu should be sorted alphabetically: ZO_SORT_ORDER_UP or ZO_SORT_ORDER_DOWN
--		table sortType:optional					table or function returning table for the sort type, e.g. ZO_SORT_BY_NAME, ZO_SORT_BY_NAME_NUMERIC
--		boolean sortOrder:optional				Boolean or function returning boolean for the sort order
-- 		string font:optional				 	String or function returning a string: font to use for the dropdown entries
-- 		number spacing:optional,	 			Number or function returning a Number: Spacing between the entries
--		boolean disableFadeGradient:optional	Boolean or function returning a boolean: for the fading of the top/bottom scrolled rows
--		table headerColor:optional				table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for header entries
--		table normalColor:optional				table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for all normal (enabled) entries
--		table disabledColor:optional 			table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for all disabled entries
-- 		function preshowDropdownFn:optional 	function function(ctrl) codeHere end: to run before the dropdown shows
--		table	XMLRowTemplates:optional		Table or function returning a table with key = row type of lib.scrollListRowTypes and the value = subtable having
--												"template" String = XMLVirtualTemplateName,
--												rowHeight number = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
--												setupFunc = function(control, data, list)
--													local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer) -- comboBoxContainer = The ZO_ComboBox control you created via WINDOW_MANAGER:CreateControlFromVirtual("NameHere", yourTopLevelControlToAddAsAChild, "ZO_ComboBox")
--													comboBox:SetupEntryLabel(control, data, list)
--												end
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

	local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
	assert(comboBox and comboBox.IsInstanceOf and comboBox:IsInstanceOf(ZO_ComboBox), MAJOR .. ' | The comboBoxContainer you supplied must be a valid ZO_ComboBox container. "comboBoxContainer.m_comboBox:IsInstanceOf(ZO_ComboBox)"')
	
	dLog(LSM_LOGTYPE_DEBUG, "AddCustomScrollableComboBoxDropdownMenu - parent: %s, comboBoxContainer: %s, options: %s", tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(options))
	comboBoxClass.UpdateMetatable(comboBox, parent, comboBoxContainer, options)
	
	return comboBox.m_dropdownObject
end
																					   
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--[API - Custom scrollable context menu at any control]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--Add a scrollable context (right click) menu at any control (not only a ZO_ComboBox), e.g. to any custom control of your
--addon or even any entry of a LibScrollableMenu combobox dropdown
--
--The context menu syntax is similar to the ZO_Menu usage:
--A new context menu should be using ClearCustomScrollableMenu() before it adds the first entries (to hide other contextmenus and clear the new one).
--After that use either AddCustomScrollableMenuEntry to add single entries, AddCustomScrollableMenuEntries to add a whole entries table/function
--returning a table, or even directly use AddCustomScrollableMenu and pass in the entrie/function to get entries.
--And after adding all entries, call ShowCustomScrollableContextMenu(parentControl) to show the menu at the parentControl. If no control is provided
--moc() (control below mouse cursor) will be used
-->Attention: ClearCustomScrollableMenu() will clear and hide ALL LSM contextmenus at any time! So we cannot have an LSM context menu to show at another
--LSM context menu entry (similar to ZO_Menu).

----------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
--Local context menu helper functions
------------------------------------------------------------------------------------------------------------------------
local function validateContextMenuSubmenuEntries(entries, options, calledByStr)
	--Passed in contextMenuEntries are a function -> Must return a table then
	local entryTableType = type(entries)
	if entryTableType == 'function' then
		options = options or g_contextMenu:GetOptions()
		--Run the function -> Get the results table
		local entriesOfPassedInEntriesFunc = entries(options)
		--Check if the result is a table
		entryTableType = type(entriesOfPassedInEntriesFunc)
		assert(entryTableType == 'table', sfor('['..MAJOR.. calledByStr .. '] table expected, got %q', tos(entryTableType)))
		entries = entriesOfPassedInEntriesFunc
	end
	return entries
end

local function getComboBoxsSortedItems(comboBox, fromOpeningControl, onlyOpeningControl)
	fromOpeningControl = fromOpeningControl or false
	onlyOpeningControl = onlyOpeningControl or false
	local sortedItems
	if fromOpeningControl == true then
		local openingControl = comboBox.openingControl
		if openingControl ~= nil then
			sortedItems = openingControl.m_owner ~= nil and openingControl.m_owner.m_sortedItems
		end
		if onlyOpeningControl then return sortedItems end
	end
	return sortedItems or comboBox.m_sortedItems
end
lib.getComboBoxsSortedItems = getComboBoxsSortedItems


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
--}, --[[additionalData]] { isNew = true, normalColor = ZO_ColorDef, highlightColor = ZO_ColorDef, disabledColor = ZO_ColorDef, font = "ZO_FontGame" } )
function AddCustomScrollableMenuEntry(text, callback, entryType, entries, additionalData)
	entryType = entryType or LSM_ENTRY_TYPE_NORMAL
	local options = g_contextMenu:GetOptions()
	local generatedText

	--Additional data table was passed in? e.g. containing  gotAdditionalData.isNew = function or boolean
	local gotAdditionalData = (additionalData ~= nil and true) or false
	local addDataType = gotAdditionalData and type(additionalData)
	local isAddDataTypeTable = (addDataType ~= nil and addDataType == "table" and true) or false

	--Generate the entryType from passed in function, or use passed in value
	local generatedEntryType = getValueOrCallback(entryType, isAddDataTypeTable and additionalData or options)

	--Additional data was passed in as a table, and a label text/function was provided?
	if isAddDataTypeTable == true and additionalData.label ~= nil then
		--If "text" param and additionalData.name both were provided: text param wins and overwites the additionalData.name!
		additionalData.name = text
		--Get/build additionalData.label and/or additionalData.name values (and store additionalData.labelFunc and/or additionalData.nameFunc -> if needed)
		processNameString(additionalData)
		generatedText = additionalData.label or additionalData.name
	else
		generatedText = getValueOrCallback(text, options)
	end

	--Text, or label, checks
	assert(generatedText ~= nil and generatedText ~= "" and generatedEntryType ~= nil, sfor('['..MAJOR..':AddCustomScrollableMenuEntry] text: String or function returning a string, got %q; entryType: number LSM_ENTRY_TYPE_* or functon returning the entryType expected, got %q', tos(generatedText), tos(generatedEntryType)))
	--EntryType checks: Allowed entryType for context menu?
	assert(allowedEntryTypesForContextMenu[generatedEntryType] == true, sfor('['..MAJOR..':AddCustomScrollableMenuEntry] entryType %q is not allowed', tos(generatedEntryType)))

	--If no entry type is used which does need a callback, and no callback was given, and we did not pass in entries for a submenu: error the missing callback
	if generatedEntryType ~= nil and not entryTypesForContextMenuWithoutMandatoryCallback[generatedEntryType] and entries == nil then
		local callbackFuncType = type(callback)
		assert(callbackFuncType == "function", sfor('['..MAJOR..':AddCustomScrollableMenuEntry] Callback function expected for entryType %q, callback\'s type: %s, name: %q', tos(generatedEntryType), tos(callbackFuncType), tos(generatedText)))
	end

	--Is the text a ---------- divider line, or entryType is divider?
	local isDivider = generatedEntryType == LSM_ENTRY_TYPE_DIVIDER or generatedText == libDivider
	if isDivider then callback = nil end

	--Fallback vor old verions of LSM <2.1 where additionalData table was missing and isNew was used as the same parameter
	local isNew = (isAddDataTypeTable and additionalData.isNew) or (not isAddDataTypeTable and additionalData) or false

	local newEntry = {
		--The entry type
		entryType 		= entryType,
		--The shown text line of the entry
		label			= (isAddDataTypeTable and additionalData.label) or nil,
		--The value line of the entry (or shown text too, if label is missing)
		name			= text,

		--Callback function as context menu entry get's selected. Will also work for an entry where a submenu is available (but usually is not provided in that case)
		--Parameters for the callback function are:
		--comboBox, itemName, item, selectionChanged, oldItem
		--> LSM's 'onMouseUp' handler will call -> ZO_ComboBoxDropdown_Keyboard.OnEntrySelected -> will call ZO_ComboBox_Base:ItemSelectedClickHelper(item, ignoreCallback) -> will call item.callback(comboBox, itemName, item, selectionChanged, oldItem)
		callback		= callback,

		--Any submenu entries (with maybe nested submenus)
		entries			= entries,

		--Is a new item?
		isNew			= isNew,
	}

	--Any other custom params passed in? Mix in missing ones and skip existing (e.g. isNew)
	if isAddDataTypeTable then
		--[[ Will add e.g. the following data, if missing in newEntry
			additionalData.normalColor
			additionalData.highlightColor
			additionalData.disabledColor
			additionalData.font
			additionalData.label
			...
			--> and other custom values for your addons

			--Info: The call to processNameString has updated addiitonalData with nameFunc and labelFunc already, if
			--additionalData.label was provided
			additionalData.labelFunc
			additionalData.nameFunc
		]]
		mixinTableAndSkipExisting(newEntry, additionalData)
	end

	dLog(LSM_LOGTYPE_DEBUG, "AddCustomScrollableMenuEntry - text: %s, callback: %s, entryType: %s, entries: %s", tos(text), tos(callback), tos(entryType), tos(entries))

	--Add the line of the context menu to the internal tables. Will be read as the ZO_ComboBox's dropdown opens and calls
	--:AddMenuItems() -> Added to internal scroll list then
	g_contextMenu:AddContextMenuItem(newEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)
end
local addCustomScrollableMenuEntry = AddCustomScrollableMenuEntry

--Adds an entry having a submenu (or maybe nested submenues) in the entries table/entries function whch returns a table
--> See examples for the table "entries" values above AddCustomScrollableMenuEntry
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableSubMenuEntry(text, entries)
	dLog(LSM_LOGTYPE_DEBUG, "AddCustomScrollableSubMenuEntry - text: %s, entries: %s", tos(text), tos(entries))
	addCustomScrollableMenuEntry(text, nil, LSM_ENTRY_TYPE_NORMAL, entries, nil)
end

--Adds a divider line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableMenuDivider()
	dLog(LSM_LOGTYPE_DEBUG, "AddCustomScrollableMenuDivider")
	addCustomScrollableMenuEntry(libDivider, nil, LSM_ENTRY_TYPE_DIVIDER, nil, nil)
end

--Set the options (visible rows max, etc.) for the scrollable context menu, or any passed in 2nd param comboBoxContainer
-->See possible options above AddCustomScrollableComboBoxDropdownMenu
function SetCustomScrollableMenuOptions(options, comboBoxContainer)
	--local optionsTableType = type(options)
	--assert(optionsTableType == 'table' , sfor('['..MAJOR..':SetCustomScrollableMenuOptions] table expected, got %q = %s', "options", tos(optionsTableType)))

	dLog(LSM_LOGTYPE_DEBUG, "SetCustomScrollableMenuOptions - comboBoxContainer: %s, options: %s", tos(getControlName(comboBoxContainer)), tos(options))

	--Use specified comboBoxContainer's dropdown to update the options to
	if comboBoxContainer ~= nil then
		local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
		if comboBox ~= nil and comboBox.UpdateOptions then
			comboBox.optionsChanged = options ~= comboBox.options
--d(">SetCustomScrollableMenuOptions - Found UpdateOptions - optionsChanged: " ..tos(comboBox.optionsChanged))
			comboBox:UpdateOptions(options)
		end
	else
		--Update options to default contextMenu
		g_contextMenu:SetOptions(options)
	end
end
local setCustomScrollableMenuOptions = SetCustomScrollableMenuOptions

--Hide the custom scrollable context menu and clear it's entries, clear internal variables, mouse clicks etc.
function ClearCustomScrollableMenu()
	dLog(LSM_LOGTYPE_DEBUG, "ClearCustomScrollableMenu")
	g_contextMenu:ClearItems()

	setCustomScrollableMenuOptions(defaultComboBoxOptions, nil)
	return true
end
local clearCustomScrollableMenu = ClearCustomScrollableMenu


--Pass in a table/function returning a table with predefined context menu entries and let them all be added in order of the table's number key
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableMenuEntries(contextMenuEntries)
	dLog(LSM_LOGTYPE_DEBUG, "AddCustomScrollableMenuEntries - contextMenuEntries: %s", tos(contextMenuEntries))

	contextMenuEntries = validateContextMenuSubmenuEntries(contextMenuEntries, nil, "AddCustomScrollableMenuEntries")
	if ZO_IsTableEmpty(contextMenuEntries) then return end

	for _, v in ipairs(contextMenuEntries) do
		addCustomScrollableMenuEntry(v.label or v.name, v.callback, v.entryType, v.entries, v.additionalData)
	end
	return true
end
local addCustomScrollableMenuEntries = AddCustomScrollableMenuEntries

--Populate a new scrollable context menu with the defined entries table/a functinon returning the entries.
--Existing context menu entries will be reset, because ClearCustomScrollableMenu will be called!
--You can add more entries later, prior to showing, via AddCustomScrollableMenuEntry / AddCustomScrollableMenuEntries functions too
function AddCustomScrollableMenu(entries, options)
	dLog(LSM_LOGTYPE_DEBUG, "AddCustomScrollableMenu - entries: %s, options: %s", tos(entries), tos(options))
	--Clear the existing LSM context menu entries
	clearCustomScrollableMenu()

	entries = validateContextMenuSubmenuEntries(entries, options, "AddCustomScrollableMenu")

	--Any options provided? Update the options for the context menu now
	-->Do not pass in if nil als else existing options will be overwritten with defaults again.
	---> For that explicitly call SetCustomScrollableMenuOptions
	if options ~= nil then
		setCustomScrollableMenuOptions(options)
	end
	
	return addCustomScrollableMenuEntries(entries)
end

--Show the custom scrollable context menu now at the control controlToAnchorTo, using optional options.
--If controlToAnchorTo is nil it will be anchored to the current control's position below the mouse, like ZO_Menu does
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function ShowCustomScrollableMenu(controlToAnchorTo, options)
	dLog(LSM_LOGTYPE_DEBUG, "ShowCustomScrollableMenu - controlToAnchorTo: %s, options: %s", tos(getControlName(controlToAnchorTo)), tos(options))
	if options then
		setCustomScrollableMenuOptions(options)
	end

	controlToAnchorTo = controlToAnchorTo or moc()
	g_contextMenu:ShowContextMenu(controlToAnchorTo)
	return true
end


--Run a callback function myAddonCallbackFunc passing in the entries of the opening menu/submneu of a clicked LSM context menu item
-->Parameters of your function myAddonCallbackFunc must be:
-->function myAddonCallbackFunc(userdata LSM_comboBox, userdata selectedContextMenuItem, table openingMenusEntries, ...)
-->... can be any additional params that your function needs, and must be passed in to the ... of calling API function RunCustomScrollableMenuItemsCallback too!
--->e.g. use this function in your LSM contextMenu entry's callback function, to call a function of your addon to update your SavedVariables
-->based on the currently selected checkboxEntries of the opening LSM dropdown:
--[[
	AddCustomScrollableMenuEntry("Context menu Normal entry 1", function(comboBox, itemName, item, selectionChanged, oldItem)
		d('Context menu Normal entry 1')


		local function myAddonCallbackFunc(LSM_comboBox, selectedContextMenuItem, openingMenusEntries, customParam1, customParam2)
				--Loop at openingMenusEntries, get it's .dataSource, and if it's a checked checkbox then update SavedVariables of your addon accordingly
				--or do oher things
				--> Attention: Updating the entries in openingMenusEntries won't work as it's a copy of the data as the contextMenu was shown, and no reference!
				--> Updating the data directly would make the menus break, and sometimes the data would be even gone due to your mouse moving above any other entry
				--> wile the callbackFunc here runs
		end
		--Use LSM API func to get the opening control's list and m_sorted items properly so addons do not have to take care of that again and again on their own
		RunCustomScrollableMenuItemsCallback(comboBox, item, myAddonCallbackFunc, { LSM_ENTRY_TYPE_CHECKBOX }, true, "customParam1", "customParam2")
	end)
]]
--If table/function returning a table parameter filterEntryTypes is not nil:
--The table needs to have a number key and a LibScrollableMenu entryType constants e.g. LSM_ENTRY_TYPE_CHECKBOX as value. Only the provided entryTypes will be selected
--from the m_sortedItems list of the parent dropdown! All others will be filtered out. Only the selected entries will be passed to the myAddonCallbackFunc's param openingMenusEntries.
--If the param filterEntryTypes is nil: All entries will be selected and passed to the myAddonCallbackFunc's param openingMenusEntries.
--
--If the boolean/function returning a boolean parameter fromParentMenu is true: The menu items of the opening (parent) menu will be returned. If false: The currently shown menu's items will be returned
function RunCustomScrollableMenuItemsCallback(comboBox, item, myAddonCallbackFunc, filterEntryTypes, fromParentMenu, ...)
	local assertFuncName = "RunCustomScrollableMenuItemsCallback"
	local addonCallbackFuncType = type(myAddonCallbackFunc)
	assert(addonCallbackFuncType == "function", sfor('['..MAJOR..':'..assertFuncName..'] myAddonCallbackFunc: function expected, got %q', tos(addonCallbackFuncType)))

	local options = g_contextMenu:GetOptions()

	local gotFilterEntryTypes = filterEntryTypes ~= nil and true or false
	local filterEntryTypesTable = (gotFilterEntryTypes == true and getValueOrCallback(filterEntryTypes, options)) or nil
	local filterEntryTypesTableType = (filterEntryTypesTable ~= nil and type(filterEntryTypesTable)) or nil
	assert(gotFilterEntryTypes == false or (gotFilterEntryTypes == true and filterEntryTypesTableType == "table"), sfor('['..MAJOR..':'..assertFuncName..'] filterEntryTypes: table or function returning a table expected, got %q', tos(filterEntryTypesTableType)))

	local fromParentMenuValue
	if fromParentMenu == nil then
		fromParentMenuValue = false
	else
		fromParentMenuValue = getValueOrCallback(fromParentMenu, options)
		assert(type(fromParentMenuValue) == "boolean", sfor('['..MAJOR..':'..assertFuncName..'] fromParentMenu: boolean expected, got %q', tos(type(fromParentMenu))))
	end

--d("[LSM]"..assertFuncName.." - filterEntryTypes: " ..tos(gotFilterEntryTypes) .. ", type: " ..tos(filterEntryTypesTableType) ..", fromParentMenu: " ..tos(fromParentMenuValue))

	--Find out via comboBox and item -> What was the "opening menu" and "how do I get openingMenu m_sortedItems"?
	--comboBox would be the comboBox or dropdown of the context menu -> if RunCustomScrollableMenuCheckboxCallback was called from the callback of a contex menu entry
	--item could have a control or something like that from where we can get the owner and then check if the owner got a openingControl or similar?
	local sortedItems = getComboBoxsSortedItems(comboBox, fromParentMenu, false)
	if ZO_IsTableEmpty(sortedItems) then return end

	--Unlink the copied items so we can pass them to the addon's calling, without fearing they will change the actual's
	--control data and invalidate any opend LSM menus
	local itemsForCallbackFunc = ZO_ShallowTableCopy(sortedItems)

	--Any entryTypes to filter passed in?
	if gotFilterEntryTypes == true and not ZO_IsTableEmpty(filterEntryTypesTable) then
		local allowedEntryTypes = {}
		--Build lookup table for allowed entry types
		for _, entryTypeToFilter in ipairs(filterEntryTypesTable) do
			--Is the entryType passed in a library's known and allowed one?
			if libraryAllowedEntryTypes[entryTypeToFilter] then
				allowedEntryTypes[entryTypeToFilter] = true
			end
		end

		--Any entryType to filter left now ?
		if not ZO_IsTableEmpty(allowedEntryTypes) then
			local filteredTab = {}
			--Check the determined items' entryType and only add the matching (non filtered) ones
			for _, v in ipairs(itemsForCallbackFunc) do
				local itemsEntryType = v.entryType
					if itemsEntryType ~= nil and allowedEntryTypes[itemsEntryType] then
						filteredTab[#filteredTab + 1] = v
					end
				end
			itemsForCallbackFunc = filteredTab
		end
	end

	local gotAnyCustomParams = (select(1, {...}) ~= nil and true) or false
	myAddonCallbackFunc(comboBox, item, itemsForCallbackFunc, (gotAnyCustomParams and unpack({...})) or nil)
end


------------------------------------------------------------------------------------------------------------------------
-- API functions for custom scrollable inventory context menu (ZO_Menu / LibCustomMenu support)
------------------------------------------------------------------------------------------------------------------------
--> See ZO_Menu2LSM_Mapping.lua


------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------
--Load of the addon/library starts
local function onAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
	loadLogger()
	dLog(LSM_LOGTYPE_DEBUG, "~~~~~ onAddonLoaded ~~~~~")

	local comboBoxContainer = CreateControlFromVirtual(MAJOR .. "_ContextMenu", GuiRoot, "ZO_ComboBox")
	--Create the local context menu object for the library's context menu API functions
	g_contextMenu = contextMenuClass:New(comboBoxContainer)
	lib.contextMenu = g_contextMenu

	--Register a scene manager callback for the SetInUIMode function so any menu opened/closed closes the context menus of LSM too
	SecurePostHook(SCENE_MANAGER, 'SetInUIMode', function(self, inUIMode, bypassHideSceneConfirmationReason)
		if not inUIMode then
			ClearCustomScrollableMenu()
		end
	end)

	SLASH_COMMANDS["/lsmdebug"] = function()
		loadLogger()
		lib.doDebug = not lib.doDebug
		if logger then logger:SetEnabled(lib.doDebug) end
	end
	SLASH_COMMANDS["/lsmdebugverbose"] = function()
		loadLogger()
		lib.doDebug = not lib.doDebug
		if logger and logger.verbose then
			logger.verbose:SetEnabled(lib.doDebug)
		end
	end

	--Load the hooks for ZO_Menu and allow replacement of ZO_Menu items with LSM entries
	lib.LoadZO_MenuHooks()
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




--[[
-------------------
WORKING ON - Current version: 2.1.2
-------------------
	LibCustomMenu integration



-------------------
TODO - To check (future versions)
-------------------
	1. recursive variable sharing for post init submenu updating ideas
		-- this is not recursive, it's direct access to comboBox's variables.
		-- example: comboBox.m_submenu.m_sortsItems returns comboBox.m_sortsItems. The same with comboBox.m_submenu.m_submenu.m_submenu.m_submenu.m_submenu.m_sortsItems. to the nth.
		-- This funnctions no matter where they are called from, even in the api.
		-- This means that no function calling any of the pass-through variables need to be modified to get the comboBox's variable from a submenu object.
		-- in actuallity, submenu.-variable- does not exist. As seen in TB. See about 2.
		-- The function "SelectItem" is allso "pass-through". No. It simply hands the function over too the comboBox.
		-- This makes it so, after the submenu data is colected from submenu.m_sortedItems, it will be handed directly through as submenu.SelectItem(comboBox, submenuItem)
		-- Which makes every self within SelectItem belong to the comboBox
		
		-- The best part about all this is, these variabels do not need to be inhereted on init and, they never need to be set in any submenu.
		1. hook all parent set functions regarding such variables on submenu init 
			-- No. This would break the purpos of the custom metatable.
			-- Setting any of the select variables from the submenu would actually create that variable in the submenu due to .__newindex. It would mean, if the variable is ever changed using the comboBox, it would no longer be reflected in that submenu.
		2. intercept specific functions in comboBox metatable and recursively fire corresponding functions for all available submenus. 
			-- This is not needed. If any function of the comboBox needs to be directly effected by the submenus, adding it to exposedFunctions is all that should be needed.
			-- I've only found this needed for "SelectItem". But, if other functions are found that would benift from this, they can be added too.
		3. intercept variables in comboBox metatable and recursively change available submenus. 
			-- All changes to any variable in exposedVariables, from the comboBox, will automatically be reflected in all child menus
		4. intercept variables in submenu metatable as shared with parent comboBox. 
			-- done
		5. clean up submenuClass:ShowDropdownInternal and submenuClass:HideDropdownInternal, if needed.
		
		-- Since "SelectItem" is the only funcition currently using this metatable trick, we could just make a custom version of the function that does the same thing. 
		-- But, it would add some dificulty, beyond adding a string to a table, if ever there were other functions needing this action.
		
	2. Attention: zo_comboBox_base_hideDropdown(self) in self:HideDropdown() does NOT close the main dropdown if right clicked! Only for a left click... See ZO_ComboBox:HideDropdownInternal()
	4. verify submenu anchors. Small adjustments not easily seen on small laptop monitor
	5. consider making a pre-show function to contain common calls prior to dropdownClass:Show(
		- update fade gradient state
		-
	6. Check if entries' .tooltip can be a function and then call that function and show it as normal ZO_Tooltips_ShowTextTooltip(control, text) instead of having to use .customTooltip for that
	7. Check why a context menu opened at an LSM dropdown closes the whole LSM dropdown + context menu if an entry is selected at the context menu AND the mouse (moc()) is not above the owners dropdown anymore
	8. Add options.maxHeight and options.maxSubmenuHeight as number or function returning a number. Set that to self.m_height fixed then instead of calculating the height via entryHeigh * visibleRowsDropdown/visibleRowsSubmenu

-------------------
UPCOMING FEATURES  - What will be added in the future?
-------------------
	1. String filter editbox at the top of dropdownbox allowing to filter for e.g. "search string". Search sring prefixed by "/" will be keeping submenu entries non-matching the search string
	2. Sort headers for the dropdown (ascending/descending) (maybe: allowing custom sort functions too)
	3. LibCustomMenu and ZO_Menu support in inventories
]]

