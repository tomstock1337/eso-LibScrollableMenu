
if LibScrollableMenu ~= nil then return end -- the same or newer version of this lib is already loaded into memory

--------------------------------------------------------------------
-- LibScrollableMenu - Object & version
--------------------------------------------------------------------
local lib = ZO_CallbackObject:New()
lib.name = "LibScrollableMenu"
local MAJOR = lib.name

lib.author = "IsJustaGhost, Baertram, tomstock, Kyoma"
lib.version = "2.33"

if not lib then return end

--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--ZOs local speed-up/reference variables
local AM = GetAnimationManager() --ANIMATION_MANAGER
local EM = GetEventManager() --EVENT_MANAGER
local SNM = SCREEN_NARRATION_MANAGER
local tos = tostring
local sfor = string.format
local zostrlow = zo_strlower
local tins = table.insert
local trem = table.remove


--------------------------------------------------------------------
-- For debugging and logging
--------------------------------------------------------------------
--Logging and debugging
lib.Debug = {}
lib.Debug.doDebug = false
lib.Debug.doVerboseDebug = false

local debugPrefix = "[" .. MAJOR .. "]"
lib.Debug.prefix = debugPrefix

local libDebug = lib.Debug


local function initDebugLogging()
	if not lib.Debug then return false end
	libDebug = lib.Debug
	if not libDebug.LoadLogger then return false end
	libDebug.LoadLogger()
	return true
end
local dlog --= libDebug.DebugLog, updated at EVENT_ADDON_LOADED

local function debugLoggingToggle(debugType)
	if not initDebugLogging() then return end

	if debugType == "debug" then
		lib.Debug.doDebug = not lib.Debug.doDebug
		libDebug = lib.Debug
		if libDebug.logger then libDebug.logger:SetEnabled(libDebug.doDebug) end
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 176, tos(libDebug.doDebug and "ON" or "OFF")) end

	elseif debugType == "debugVerbose" then
		lib.Debug.doVerboseDebug = not lib.Debug.doVerboseDebug
		libDebug = lib.Debug
		if libDebug.logger and libDebug.logger.verbose then
			libDebug.logger.verbose:SetEnabled(libDebug.doVerboseDebug)
			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 177, tos(libDebug.doVerboseDebug and "ON" or "OFF"), tos(libDebug.doDebug and "ON" or "OFF")) end
		end
	end
end


--------------------------------------------------------------------
--SavedVariables
--------------------------------------------------------------------
--The default SV variables
local lsmSVDefaults = {
	textSearchHistory = {},
	collapsedHeaderState = {},
}
local svName = "LibScrollableMenu_SavedVars"
lib.SVName = svName
lib.SV = {} --will be init properly at the onAddonLoaded function
local sv = lib.SV

local function updateSavedVariable(svOptionName, newValue, subTableName)
--d(debugPrefix .. "updateSavedVariable - svOptionName: " ..tostring(svOptionName) .. ", newValue: " ..tostring(newValue) ..", subTableName: " ..tostring(subTableName))
	if svOptionName == nil then return end
	local svOptionData = lib.SV[svOptionName]
	if svOptionData == nil then return end
	if subTableName ~= nil then
		if type(svOptionData) ~= "table" then return end
--d(">>sv is table")
		lib.SV[svOptionName][subTableName] = newValue
	else
		lib.SV[svOptionName] = newValue
	end
	sv = lib.SV
end


local function getSavedVariable(svOptionName, subTableName)
	if svOptionName == nil then return end
	local svOptionData = lib.SV[svOptionName]
	if svOptionData == nil then return end
	if subTableName ~= nil then
		if type(svOptionData) ~= "table" then return end
		return lib.SV[svOptionName][subTableName]
	else
		return lib.SV[svOptionName]
	end
end


--------------------------------------------------------------------
-- Libraries
--------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
--Library internal global locals
local g_contextMenu -- The contextMenu (like ZO_Menu): Will be created at onAddonLoaded


------------------------------------------------------------------------------------------------------------------------
--ZO_ComboBox function references
local zo_comboBox_base_addItem = ZO_ComboBox_Base.AddItem
local zo_comboBox_base_hideDropdown = ZO_ComboBox_Base.HideDropdown
local zo_comboBox_base_updateItems = ZO_ComboBox_Base.UpdateItems

local zo_comboBox_setItemEntryCustomTemplate = ZO_ComboBox.SetItemEntryCustomTemplate

--local zo_comboBoxDropdown_onEntrySelected = ZO_ComboBoxDropdown_Keyboard.OnEntrySelected
local zo_comboBoxDropdown_onMouseExitEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry
local zo_comboBoxDropdown_onMouseEnterEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry

local suppressNextOnGlobalMouseUp
local buttonGroupDefaultContextMenu


------------------------------------------------------------------------------------------------------------------------
--Menu settings (main and submenu) - default values
local DEFAULT_VISIBLE_ROWS = 10
local DEFAULT_SORTS_ENTRIES = false --sort the entries in main- and submenu lists (ZO_ComboBox default is true!)
local DEFAULT_HEIGHT = 250

--dropdown settings
local SUBMENU_SHOW_TIMEOUT = 500 --350 ms before
local dropdownCallLaterHandle = MAJOR .. "_Timeout"

--Entry type default settings
local DIVIDER_ENTRY_HEIGHT = 7
local HEADER_ENTRY_HEIGHT = 30
local DEFAULT_SPACING = 0
local WITHOUT_ICON_LABEL_DEFAULT_OFFSETX = 4

--Fonts
local DEFAULT_FONT = 				"ZoFontGame"
local HeaderFontTitle = 			"ZoFontHeader3"
local HeaderFontSubtitle = 			"ZoFontHeader2"

--Colors
local HEADER_TEXT_COLOR = 			ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED))
local DEFAULT_TEXT_COLOR = 			ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
local DEFAULT_TEXT_HIGHLIGHT = 		ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))
local DEFAULT_TEXT_DISABLED_COLOR = ZO_GAMEPAD_UNSELECTED_COLOR

--Textures
local iconNewIcon = 				ZO_KEYBOARD_NEW_ICON

--MultiIcon
local iconNarrationNewValue = 		GetString(SI_SCREEN_NARRATION_NEW_ICON_NARRATION)

--Narration
local UINarrationName = MAJOR .. "_UINarration_"
local UINarrationUpdaterName = MAJOR .. "_UINarrationUpdater_"

--Throttled calls
local throttledCallDelayName = MAJOR .. '_throttledCallDelay'
local throttledCallDelay = 10

--local "global" variables
local NIL_CHECK_TABLE = {}

--Highlight and animation
local defaultHighlightTemplate 	-- See below at comboBoxDefaults
local defaultHighlightColor 	-- See below at comboBoxDefaults
local defaultHighLightAnimationFieldName = 'LSM_HighlightAnimation'
local subAndContextMenuHighlightAnimationBreadcrumbsPattern = '%s_%s'

--local "global" functions
local getValueOrCallback
local getDataSource
local getControlName

------------------------------------------------------------------------------------------------------------------------
--Entry types - For the scroll list's dataType of the menus
local LSM_ENTRY_TYPE_NORMAL = 	1
local LSM_ENTRY_TYPE_DIVIDER = 	2
local LSM_ENTRY_TYPE_HEADER = 	3
local LSM_ENTRY_TYPE_SUBMENU = 	4
local LSM_ENTRY_TYPE_CHECKBOX = 5
local LSM_ENTRY_TYPE_BUTTON = 6
local LSM_ENTRY_TYPE_RADIOBUTTON = 7

--Constant for the divider entryType
lib.DIVIDER = "-"
local libDivider = lib.DIVIDER

--Make them accessible for the DropdownObject:New options table -> options.XMLRowTemplates
lib.scrollListRowTypes = {
	["LSM_ENTRY_TYPE_NORMAL"] =			LSM_ENTRY_TYPE_NORMAL,
	["LSM_ENTRY_TYPE_DIVIDER"] = 		LSM_ENTRY_TYPE_DIVIDER,
	["LSM_ENTRY_TYPE_HEADER"] = 		LSM_ENTRY_TYPE_HEADER,
	["LSM_ENTRY_TYPE_SUBMENU"] = 		LSM_ENTRY_TYPE_SUBMENU,
	["LSM_ENTRY_TYPE_CHECKBOX"] =		LSM_ENTRY_TYPE_CHECKBOX,
	["LSM_ENTRY_TYPE_BUTTON"] =			LSM_ENTRY_TYPE_BUTTON,
	["LSM_ENTRY_TYPE_RADIOBUTTON"] = 	LSM_ENTRY_TYPE_RADIOBUTTON,
}
local scrollListRowTypes = lib.scrollListRowTypes

--The custom scrollable context menu entry types > Globals
for key, value in pairs(scrollListRowTypes) do
	--Create the lib.LSM_ENTRY_TYPE* variables
	lib[key] = value
	--Create the LSM_ENTRY_TYPE*L globals
	_G[key] = value
end

--Mapping table for entryType to button's childName (in XML template)
local entryTypeToButtonChildName = {
	[LSM_ENTRY_TYPE_CHECKBOX] = 	"Checkbox",
	[LSM_ENTRY_TYPE_RADIOBUTTON] = 	"RadioButton",
}

--Used in API RunCustomScrollableMenuItemsCallback and comboBox_base:AddCustomEntryTemplates to validate passed in entryTypes
local libraryAllowedEntryTypes = {
	[LSM_ENTRY_TYPE_NORMAL] = 		true,
	[LSM_ENTRY_TYPE_DIVIDER] = 		true,
	[LSM_ENTRY_TYPE_HEADER] = 		true,
	[LSM_ENTRY_TYPE_SUBMENU] =		true,
	[LSM_ENTRY_TYPE_CHECKBOX] =		true,
	[LSM_ENTRY_TYPE_BUTTON] =		true,
	[LSM_ENTRY_TYPE_RADIOBUTTON] =	true,
}
lib.AllowedEntryTypes = libraryAllowedEntryTypes

--Used in API AddCustomScrollableMenuEntry to validate passed in entryTypes to be allowed for the contextMenus
local allowedEntryTypesForContextMenu = {
	[LSM_ENTRY_TYPE_NORMAL] = 		true,
	[LSM_ENTRY_TYPE_DIVIDER] = 		true,
	[LSM_ENTRY_TYPE_HEADER] = 		true,
	[LSM_ENTRY_TYPE_SUBMENU] =		true,
	[LSM_ENTRY_TYPE_CHECKBOX] = 	true,
	[LSM_ENTRY_TYPE_BUTTON] = 		true,
	[LSM_ENTRY_TYPE_RADIOBUTTON] = 	true,
}
lib.AllowedEntryTypesForContextMenu = allowedEntryTypesForContextMenu

--Used in API AddCustomScrollableMenuEntry to validate passed in entryTypes to be used without a callback function
--provided (else the assert raises an error)
local entryTypesForContextMenuWithoutMandatoryCallback = {
	[LSM_ENTRY_TYPE_DIVIDER] = 		true,
	[LSM_ENTRY_TYPE_HEADER] = 		true,
	[LSM_ENTRY_TYPE_SUBMENU] =		true,
}

--Table additionalData's key (e.g. isDivider) to the LSM entry type mapping
local additionalDataKeyToLSMEntryType = {
	["isDivider"] = 	LSM_ENTRY_TYPE_DIVIDER,
	["isHeader"] = 		LSM_ENTRY_TYPE_HEADER,
	["isCheckbox"] =	LSM_ENTRY_TYPE_CHECKBOX,
	["isButton"] = 		LSM_ENTRY_TYPE_BUTTON,
	["isRadioButton"] = LSM_ENTRY_TYPE_RADIOBUTTON,
}


------------------------------------------------------------------------------------------------------------------------
--Row highlights (on mouse enter)
local LSM_ROW_HIGHLIGHT_DEFAULT = 	'ZO_SelectionHighlight'
local LSM_ROW_HIGHLIGHT_GREEN = 	'LibScrollableMenu_Highlight_Green'
local LSM_ROW_HIGHLIGHT_BLUE = 		'LibScrollableMenu_Highlight_Blue'
local LSM_ROW_HIGHLIGHT_RED = 		'LibScrollableMenu_Highlight_Red'
local LSM_ROW_HIGHLIGHT_OPAQUE = 	'LibScrollableMenu_Highlight_Opaque'
lib.scrollListRowHighlights = {
	["LSM_ROW_HIGHLIGHT_DEFAULT"] =		LSM_ROW_HIGHLIGHT_DEFAULT,
	["LSM_ROW_HIGHLIGHT_GREEN"] = 		LSM_ROW_HIGHLIGHT_GREEN,
	["LSM_ROW_HIGHLIGHT_BLUE"] = 		LSM_ROW_HIGHLIGHT_BLUE,
	["LSM_ROW_HIGHLIGHT_RED"] = 		LSM_ROW_HIGHLIGHT_RED,
	["LSM_ROW_HIGHLIGHT_OPAQUE"] =		LSM_ROW_HIGHLIGHT_OPAQUE,
}
local scrollListRowHighlights = lib.scrollListRowHighlights
--The custom scrollable context menu row highlight types > Globals
for key, value in pairs(scrollListRowHighlights) do
	--Create the lib.LSM_ROW_HIGHLIGHT* variables
	lib[key] = value
	--Create the LSM_ROW_HIGHLIGHT* globals
	_G[key] = value
end

--The default row highlight data for all entries
local defaultHighlightTemplateData = {
	template = 	LSM_ROW_HIGHLIGHT_DEFAULT,
	color = 	DEFAULT_TEXT_HIGHLIGHT,
}
--The default row highlight data for an entry having a submenu, where the entry itsself got a callback
local defaultHighlightTemplateDataEntryHavingSubMenuWithCallback = {
	template = 	LSM_ROW_HIGHLIGHT_GREEN, --green row
	color = 	DEFAULT_TEXT_HIGHLIGHT,
}
--The default row highlight data for an entry opening a contextMenu
local defaultHighlightTemplateDataEntryContextMenuOpeningControl = {
	template = 	LSM_ROW_HIGHLIGHT_GREEN, --green row
	color = 	DEFAULT_TEXT_HIGHLIGHT,
}



------------------------------------------------------------------------------------------------------------------------
--Entries data
--The subtable in entry.data table where all LibScrollableMenu relevant extra data and functions etc. are stored
local LSM_DATA_SUBTABLE =						"_LSM"
--The subtable names in the entry.data[LSM_DATA_SUBTABLE] table where:
---the original data table is copied to, for reference and e.g. keeping passed in m_highlightTemplate etc. values
local LSM_DATA_SUBTABLE_ORIGINAL_DATA =			"OriginalData"
---the functions of data[key] are stored, so we can execute them each time we need it to return the real value for data[key]
local LSM_DATA_SUBTABLE_CALLBACK_FUNCTIONS = 	"funcData"


------------------------------------------------------------------------------------------------------------------------
--Entries key mapping

--The mapping between LibScrollableMenu entry key and ZO_ComboBox entry key. Used in addItem_Base -> updateVariables
-->Only keys provided in this table will be copied from item.additionalData to item directly!
local LSMEntryKeyZO_ComboBoxEntryKey = {
	--ZO_ComboBox keys
	["normalColor"] =		"m_normalColor",
	["disabledColor"] =		"m_disabledColor",
	["highlightColor"] =	"m_highlightColor",
	["highlightTemplate"] =	"m_highlightTemplate",

	--Keys which can be passed in at API functions like AddCustomScrollableMenuEntry
	-->Will be taken care of in func updateVariable -> at the else if selfVar[key] == nil then ...
}

------------------------------------------------------------------------------------------------------------------------
--Entries which can use a function and need to be updated via function updateDataValues
--Table contains [string key] = defaultValue boolean for the row/entry's data table
--> If key inside the row's data table (e.g. data["name"]) is a function:
--> This function will be added to row's data._LSM.funcData subtables (see function updateDataValues) and executed upon
--> showing the LSM dropdown.
--> If the functions return value is nil it will use the value of this table below, if it is true (false/others will be ignored)
local nilToTrue = true
local nilIgnore = false
local possibleEntryDataWithFunction = {
	--Ignored entryDatas: Returning nil by default
	["name"] = 		nilIgnore,
	["label"] = 	nilIgnore,
	["checked"] = 	nilIgnore,
	["font"] = 		nilIgnore,

	--entryData returning true by default
	["enabled"] = 	nilToTrue,
}


------------------------------------------------------------------------------------------------------------------------
--Default options/settings and values

--ZO_ComboBox default settings: Will be copied over as default attributes to comboBoxClass and inherited to the scrollable
--dropdown helper classes
local comboBoxDefaults = {
	--From ZO_ComboBox
	---member data with m_
	m_customEntryTemplateInfos =	nil,
	m_disabledColor = 				DEFAULT_TEXT_DISABLED_COLOR,
	m_enableMultiSelect = 			false,
	m_font = 						DEFAULT_FONT,
	m_height = 						DEFAULT_HEIGHT,
	m_highlightColor = 				DEFAULT_TEXT_HIGHLIGHT,
	m_highlightTemplate =			LSM_ROW_HIGHLIGHT_DEFAULT, --ZO_SelectionHighlight
	m_isDropdownVisible = 			false,
	m_maxNumSelections = 			nil,
	m_normalColor = 				DEFAULT_TEXT_COLOR,
	m_preshowDropdownFn = 			nil,
	m_selectedColor =				{ GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED) },
	m_selectedItemData = 			nil,
	m_sortsItems = 					false, --ZO_ComboBox real default is true
	m_sortOrder = 					ZO_SORT_ORDER_UP,
	m_sortType = 					ZO_SORT_BY_NAME,
	m_spacing = 					DEFAULT_SPACING,

	--non member data
	horizontalAlignment = 			TEXT_ALIGN_LEFT,

	--LibCustomMenu support
	itemYPad = 						0,

	--LibScrollableMenu internal (e.g. options)
	disableFadeGradient = 			false,
	headerFont =					DEFAULT_FONT,
	headerColor = 					HEADER_TEXT_COLOR,
	visibleRows = 					DEFAULT_VISIBLE_ROWS,
	visibleRowsSubmenu = 			DEFAULT_VISIBLE_ROWS,
	baseEntryHeight = 				ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
	headerCollapsed = 				false,
}
lib.comboBoxDefaults = comboBoxDefaults

--Set the default highlight values
defaultHighlightTemplate = comboBoxDefaults.m_highlightTemplate
defaultHighlightColor = comboBoxDefaults.m_highlightColor


--The default values for dropdownHelper options -> used for non-passed in options at LSM API functions
local defaultComboBoxOptions  = {
	["disableFadeGradient"] = 		false,
	["font"] = 						DEFAULT_FONT,
	["headerCollapsed"] =			false,
	["headerCollapsible"] = 		false,
	["highlightContextMenuOpeningControl"] = false,
	["sortEntries"] = 				DEFAULT_SORTS_ENTRIES,
	["spacing"] = 					DEFAULT_SPACING,
	["useDefaultHighlightForSubmenuWithCallback"] = false,
	["visibleRowsDropdown"] = 		DEFAULT_VISIBLE_ROWS,
	["visibleRowsSubmenu"] = 		DEFAULT_VISIBLE_ROWS,
	--["XMLRowTemplates"] = 		table, --Will be set at comboBoxClass:UpdateOptions(options) from options (see function comboBox_base:AddCustomEntryTemplates)
	--["XMLRowHighlightTemplates"] =table, --Will be set at comboBoxClass:UpdateOptions(options) from options (see function comboBox_base:AddCustomEntryTemplates)
}
lib.defaultComboBoxOptions  = defaultComboBoxOptions


------------------------------------------------------------------------------------------------------------------------
--Options key mapping

--The mapping between LibScrollableMenu options key and ZO_ComboBox's key. Used in comboBoxClass:UpdateOptions()
local LSMOptionsKeyToZO_ComboBoxOptionsKey = {
	--All possible options entries "must" be mapped here (left: options entry / right: ZO_ComboBox relating entry where the value is saved)
	-->e.g. options.visibleRowsDropdown -> Will be saved at comboBox.visibleRows (and if a function in table LSMOptionsToZO_ComboBoxOptionsCallbacks
	-->is defiend below this function will be executed too).
	-->Missing entries (even if names are the same) will relate in function comboBoxClass:SetOption not respecting the value!
	["disableFadeGradient"] =	"disableFadeGradient", --Used for the ZO_ScrollList of the dropdown, not the comboBox itsself
	["disabledColor"] =			"m_disabledColor",
	["enableFilter"] =			"enableFilter",
	["headerCollapsible"] = 	"headerCollapsible",
	["headerCollapsed"] = 		"headerCollapsed",
	["headerColor"] =			"headerColor",
	["headerFont"] =			"headerFont",
	["highlightContextMenuOpeningControl"] = "highlightContextMenuOpeningControl",
	["narrate"] = 				"narrateData",
	["normalColor"] = 			"m_normalColor",
	["subtitleText"] = 			"subtitleText",
	["subtitleFont"] = 			"subtitleFont",
	["titleFont"] = 			"titleFont",
	["titleText"] = 			"titleText",
	["titleTextAlignment"] =	"titleTextAlignment",
	["useDefaultHighlightForSubmenuWithCallback"] = "useDefaultHighlightForSubmenuWithCallback",
	["visibleRowsSubmenu"]=		"visibleRowsSubmenu",

	--Entries with callback function -> See table "LSMOptionsToZO_ComboBoxOptionsCallbacks" below
	-->!!!Attention: You must add those entries, which you add as callback function to table "LSMOptionsToZO_ComboBoxOptionsCallbacks",
	-->to this table LSMOptionsKeyToZO_ComboBoxOptionsKey here too!!!
	['font'] = 					"m_font",
	['maxDropdownHeight'] =		"maxHeight",
	["preshowDropdownFn"] = 	"m_preshowDropdownFn",
	['sortEntries'] = 			"m_sortsItems",
	['sortOrder'] = 			"m_sortOrder",
	['sortType'] = 				"m_sortType",
	['spacing'] = 				"m_spacing",
	["visibleRowsDropdown"] =	"visibleRows",
}
lib.LSMOptionsKeyToZO_ComboBoxOptionsKey = LSMOptionsKeyToZO_ComboBoxOptionsKey

--The callback functions for the mapped LSM option -> ZO_ComboBox options (where any provided/needed)
local LSMOptionsToZO_ComboBoxOptionsCallbacks = {
	--These callback functions will apply the options directly
	--If self. (= comboBoxObject) updatedOptions table is provided it might contain already processed
	--"updated" options of the current loop at self:UpdateOptions(optionsTable)
	-->You can use these table entries to get the most up2date values of the currently processed options

	['font'] = function(comboBoxObject, font)
		comboBoxObject:SetFont(font) --sets comboBoxObject.m_font
	end,
	["maxDropdownHeight"] = function(comboBoxObject, maxDropdownHeight)
		comboBoxObject.maxHeight = maxDropdownHeight
		comboBoxObject:UpdateHeight(comboBoxObject.m_dropdown)
	end,
	["preshowDropdownFn"] = function(comboBoxObject, preshowDropdownCallbackFunc)
		comboBoxObject:SetPreshowDropdownCallback(preshowDropdownCallbackFunc) --sets m_preshowDropdownFn
	end,
	["sortEntries"] = function(comboBoxObject, sortEntries)
		comboBoxObject:SetSortsItems(sortEntries) --sets comboBoxObject.m_sortsItems
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
	['sortType'] = function(comboBoxObject, sortType)
		local options = comboBoxObject.options
		--Check if any updatedOptions already exist and if the sortOrder was updated already then sortType does not need
		--to be updated too (and vice versa)
		local updatedOptions = comboBoxObject.updatedOptions
		if updatedOptions.sortOrder then return end

		local sortOrder = getValueOrCallback(options.sortOrder, options)
		if sortOrder == nil then sortOrder = comboBoxObject.m_sortOrder end
		comboBoxObject:SetSortOrder(sortType , sortOrder )
	end,
	['spacing'] = function(comboBoxObject, spacing)
		comboBoxObject:SetSpacing(spacing) --sets comboBoxObject.m_spacing
	end,
	["visibleRowsDropdown"] = function(comboBoxObject, visibleRows)
		comboBoxObject.visibleRows = visibleRows
		comboBoxObject:UpdateHeight(comboBoxObject.m_dropdown)
	end,
}
lib.LSMOptionsToZO_ComboBoxOptionsCallbacks = LSMOptionsToZO_ComboBoxOptionsCallbacks


------------------------------------------------------------------------------------------------------------------------
--Submenu key mapping

-- Pass-through variables:
--If submenuClass_exposedVariables[key] == true: if submenu[key] is nil, returns submenu.m_comboBox[key] (means it takes the value from the owning LSM dropdown for the submenu then)
--> where key = e.g. "m_font"
local submenuClass_exposedVariables = {
	-- ZO_ComboBox
	["m_customEntryTemplateInfos"] = false, -- needs to be false to supress pass-through of XML template from main menu -> would break submenu's row setup.
	["m_height"] = false, -- needs to be false so options.visibleRowsSubmenu is used for the height of the submenu, and not the main menu's height (from options.visibleRowsDropdown)
	-------------------------------------
	['m_containerWidth'] = true,
	['m_enableMultiSelect'] = true,
	["m_font"] = true,
	['m_highlightColor'] = true,
	['m_maxNumSelections'] = true,
	['m_normalColor'] = true,

	-- ZO_ComboBox_Base
	["m_selectedItemText"] = false, -- This is handeled by "SelectItem"
	["m_selectedItemData"] = false, -- This is handeled by "SelectItem"
	["m_isDropdownVisible"] = false, -- each menu has different dropdowns
	["m_sortedItems"] = false, -- needs to be false to provide the possibility to sort submenu items differently compared to main menu
	---------------------------------------
	["horizontalAlignment"] = true,
	["m_container"] = true, -- all children use the same container as the comboBox
	["m_disabledColor"] = true,
	["m_name"] = true, -- since the name is acquired by the container name.
	["m_openDropdown"] = true, -- control, set to true for submenu to make comboBox_base:IsEnabled( function work
	["m_preshowDropdownFn"] = true,
	["m_selectedColor"] = true,
	["m_sortsItems"] = true,
	["m_sortOrder"] = true,
	["m_sortType"] = true,
	["m_spacing"] = true,

	-- LibScrollableMenu
	["headerCollapsed"] = false,		--Header: Currently not available separately for a submenu
	["headerCollapsible"] = false, 		--Header: Currently not available separately for a submenu
	---------------------------------------
	['disableFadeGradient'] = true,
	['headerFont'] = true,
	['headerColor'] = true,
	['highlightContextMenuOpeningControl'] = true,
	['options'] = true,
	['maxDropdownHeight'] = true,
	['m_highlightTemplate'] = true,
	['narrateData'] = true,
	['useDefaultHighlightForSubmenuWithCallback'] = true,
	['visibleRowsSubmenu'] = true, --we only need this "visibleRowsSubmenu" for the submenus, mainMenu uses visibleRowsDropdown
	['XMLRowTemplates'] = true, --TODO: is this being overwritten?
	['XMLRowHighlightTemplates'] = true, --TODO: is this being overwritten?
}

-- Pass-through functions:
--If submenuClass_exposedFunctions[variable] == true: if submenuClass[key] is not nil, returns submenuClass[key](submenu.m_comboBox, ...)
local submenuClass_exposedFunctions = {
	["SelectItem"] = true, -- (item, ignoreCallback)
}


------------------------------------------------------------------------------------------------------------------------
-- Search filter
--No entry found in main menu
local noEntriesResults = {
	enabled = false,
	name = GetString(SI_SORT_FILTER_LIST_NO_RESULTS),
	m_disabledColor = DEFAULT_TEXT_DISABLED_COLOR,
}
--No entry found in sub menu
local noEntriesSubmenu = {
	name = GetString(SI_QUICKSLOTS_EMPTY),
	enabled = false,
	m_disabledColor = DEFAULT_TEXT_DISABLED_COLOR,
--	m_disabledColor = ZO_ERROR_COLOR,
}

--LSM entryTypes which should be processed by the text search/filter. Basically all entryTypes that use a label/name
local filteredEntryTypes = {
	[LSM_ENTRY_TYPE_NORMAL] = 	true,
	[LSM_ENTRY_TYPE_SUBMENU] = 	true,
	[LSM_ENTRY_TYPE_CHECKBOX] = true,
	[LSM_ENTRY_TYPE_HEADER] = 	true,
	[LSM_ENTRY_TYPE_BUTTON] = 	true,
	[LSM_ENTRY_TYPE_RADIOBUTTON] = true,
	--[LSM_ENTRY_TYPE_DIVIDER] = false,
}
--Table defines if some names of the entries count as "search them or skip them".
--true: Item's name does not need to be searched -> skip them / false: search the item's name as usual
local filterNamesExempts = {
	--Direct check via "name" string
	[""] = true,
	[noEntriesSubmenu.name] = true, -- "Empty"
	--Check via type(name)
	--['nil'] = true,
}


------------------------------------------------------------------------------------------------------------------------
--Sound settings

local origSoundComboClicked = 	SOUNDS.COMBO_CLICK
local origSoundDefaultClicked = SOUNDS.DEFAULT_CLICK
local soundClickedSilenced	= 	SOUNDS.NONE
--Sound names of the combobox entry selected sounds
local defaultClick = "DEFAULT_CLICK"
local comboClick = "COMBO_CLICK"
local entryTypeToSilenceSoundName = {
	[LSM_ENTRY_TYPE_NORMAL] 	= 	comboClick,
	[LSM_ENTRY_TYPE_CHECKBOX]	=	defaultClick,
	[LSM_ENTRY_TYPE_BUTTON] 	= 	defaultClick,
	[LSM_ENTRY_TYPE_RADIOBUTTON]= 	defaultClick,
}
--Original sounds of the combobox entry selected sounds
local entryTypeToOriginalSelectedSound = {
	[LSM_ENTRY_TYPE_NORMAL]		= origSoundComboClicked,
	[LSM_ENTRY_TYPE_CHECKBOX]	= origSoundDefaultClicked,
	[LSM_ENTRY_TYPE_BUTTON] 	= origSoundDefaultClicked,
	[LSM_ENTRY_TYPE_RADIOBUTTON]= origSoundDefaultClicked,
}


--------------------------------------------------------------------
-- Data source determination
--------------------------------------------------------------------
function getDataSource(data)
	if data and data.dataSource then
		return data:GetDataSource()
	end
	return data or NIL_CHECK_TABLE
end

-- >> data, dataEntry
local function getControlData(control)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 28, tos(getControlName(control))) end
	local data = control.m_sortedItems or control.m_data

	return getDataSource(data)
end


--------------------------------------------------------------------
-- Breadcrumb animation highlight
--------------------------------------------------------------------
--Did the virtual XML template for the highlight row change at the control? Reset the highlight control then so it will
--be build new with the new XML template, and same name -> Via ESOUI scrolltemplates.lua, PlayAnimationOnControl function
local function LSM_CheckIfAnimationControlNeedsXMLTemplateChange(control, controlTemplate)
	local retVar = false
	if control and controlTemplate then
		local rowHighlightData = control.LSM_rowHighlightData --was set to the control via self.highlightCallback(control, true) function at the scrollList!
		local highlightControlXMLTemplate = (rowHighlightData ~= nil and rowHighlightData.highlightXMLTemplate) or nil
		--Highlight control exists already and the XML template changed (e.g. scrolling an existing ScrollList row)
		if highlightControlXMLTemplate ~= nil and highlightControlXMLTemplate ~= controlTemplate then
			--Reset the animation timeline control and the highlight control
			local animationFieldName = rowHighlightData.animationFieldName
			if animationFieldName and control[animationFieldName] ~= nil then
				control[animationFieldName] = nil

				local highlightControlName = rowHighlightData.highlightControlName
				if highlightControlName ~= nil then
					if _G[highlightControlName] ~= nil then
						_G[highlightControlName] = nil
					end
				end
			end
			retVar = true
		end
	end

	--Reset the table at the control
	control.LSM_rowHighlightData = nil
	return retVar
end

--Similar function to /esoui/libraries/zo_templates/scrolltempaltes.lua, function PlayAnimationOnControl used for ZO_ScrollList
-->But here only for the contextmenu and submenu opening controls!
--Each other entryType: See call of "zo_comboBoxDropdown_onMouseEnterEntry" function and it's information about scrollCtrl.highlightTemplateOrFunction etc.
local function SubOrContextMenu_PlayAnimationOnControl(control, controlTemplate, animationFieldName, animateInstantly, overrideEndAlpha)
    if control and controlTemplate and animationFieldName then
		local animationCtrl = control[animationFieldName]
        if not animationCtrl then
            local highlight = CreateControlFromVirtual("$(parent)Scroll", control, controlTemplate, animationFieldName)
            animationCtrl = AM:CreateTimelineFromVirtual("ShowOnMouseOverLabelAnimation", highlight)

			local width = highlight:GetWidth()
			highlight:SetFadeGradient(1, (width / 3) , 0, width)
			--SetFadeGradient(gradientIndex, normalX, normalY, gradientLength)


            if overrideEndAlpha then
                animationCtrl:GetAnimation(1):SetAlphaValues(0, overrideEndAlpha)
            end

			control[animationFieldName] = animationCtrl
        end

		if animateInstantly then
			animationCtrl:PlayInstantlyToEnd()
		else
			animationCtrl:PlayForward()
		end
    end
end

local function removeAnimationOnControl(control, animationFieldName, animateInstantly)
	if control ~= nil then
		if animationFieldName ~= nil then
			local animationControl = control[animationFieldName]
			if animationControl then
				if animateInstantly then
					animationControl:PlayInstantlyToStart()
				else
					animationControl:PlayBackward()
				end
			end
		end
		control.breadcrumbName = nil
	end
end


local function unhighlightControl(selfVar, instantly, control, resetHighlightTemplate)
	local highlightControl = selfVar.highlightedControl
	if highlightControl then
		removeAnimationOnControl(highlightControl, highlightControl.breadcrumbName, instantly)
	end
	selfVar.highlightedControl = nil

	if control ~= nil and resetHighlightTemplate == true then
		if control.m_highlightTemplate then
			control.m_highlightTemplate = nil
		end

		local data = getControlData(control)
		if data then
			if data.m_highlightTemplate then
				data.m_highlightTemplate = nil
			end
		end
	end
end

--Should only be called from submenu or contextmenu's OnMouseEnter
-->Normal menus use the scrolltemplates.lua function HighlightControl via normal ZO_ScrolList. See function "highlightTemplateOrFunction"
local function SubOrContextMenu_highlightControl(selfVar, control)
	--d(debugPrefix .. "SubOrContextMenu_highlightControl: " .. tos(getControlName(control)))
	if selfVar.highlightedControl then
		unhighlightControl(selfVar, false, nil, nil)
	end

	--local isContextMenu = selfVar.isContextMenu or false

	--Get the highlight template from control.m_data.m_highlightTemplate of the submenu opening, or contextmenu opening control
	local highlightTemplate = selfVar:GetHighlightTemplate(control)

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 1, tos(highlightTemplate)) end
	if type(highlightTemplate) ~= "string" then return defaultHighlightTemplate end

	--Use the breadcrumbName as animationFieldName (e.g. LSM_HighlightAnimation_SubmenuBreadcrumb or LSM_HighlightAnimation_ContextMenuBreadcrumb)
	control.breadcrumbName = sfor(subAndContextMenuHighlightAnimationBreadcrumbsPattern, defaultHighLightAnimationFieldName, tos(selfVar.breadcrumbName))
	return SubOrContextMenu_PlayAnimationOnControl(control, highlightTemplate, control.breadcrumbName, false, 0.5)
end

--------------------------------------------------------------------
-- XML template functions
--------------------------------------------------------------------

local function getDropdownTemplate(enabled, baseTemplate, alternate, default)
	baseTemplate = MAJOR .. baseTemplate
	local templateName = sfor('%s%s', baseTemplate, (enabled and alternate or default))
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 2, tos(templateName)) end
	return templateName
end

local function getScrollContentsTemplate(barHidden)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 3, tos(barHidden)) end
	return getDropdownTemplate(barHidden, '_ScrollContents', '_BarHidden', '_BarShown')
end


--------------------------------------------------------------------
-- Screen / UI helper functions
--------------------------------------------------------------------
local function getScreensMaxDropdownHeight()
	return GuiRoot:GetHeight() - 100
end


--------------------------------------------------------------------
--Dropdown Header controls
--------------------------------------------------------------------

--[[ Adds options
	options.titleText
	options.titleFont
	options.subtitleText
	options.subtitleFont
	options.titleTextAlignment -- for title and subtitle
	options.customHeaderControl
	
	options.enableFilter
	options.headerCollapsible
	options.headerCollapsed
	
	context menu, on second showing, Filter is shown.
]]

-- The controls, here and in the XML, are subject to change
-- May only need PARENT, TITLE, FILTER_CONTAINER for now
lib.headerControls = { 
	-- To not cycle through this when anchoring controls, skipped in ipairs
	PARENT				= -1,
	TITLE_BASELINE		= -2,
	CENTER_BASELINE		= 0,
	-- Cycles with ipairs
	TITLE				= 1,
	SUBTITLE			= 2,
	DIVIDER_SIMPLE		= 3,
	FILTER_CONTAINER	= 4,
	CUSTOM_CONTROL		= 5,
	TOGGLE_BUTTON		= 6,
	TOGGLE_BUTTON_CLICK_EXTENSION = 7, -- control that anchors to the toggle buttons left to make the whole header's width clickable to toggle the collapsed state
}
local headerControls = lib.headerControls

local refreshDropdownHeader
do
	-- Alias the control names to make the code less verbose and more readable.
	local PARENT			= headerControls.PARENT
	local TITLE				= headerControls.TITLE
	local SUBTITLE			= headerControls.SUBTITLE
	local CENTER_BASELINE	= headerControls.CENTER_BASELINE
	local TITLE_BASELINE	= headerControls.TITLE_BASELINE
	local DIVIDER_SIMPLE	= headerControls.DIVIDER_SIMPLE
	local FILTER_CONTAINER	= headerControls.FILTER_CONTAINER
	local CUSTOM_CONTROL	= headerControls.CUSTOM_CONTROL
	local TOGGLE_BUTTON		= headerControls.TOGGLE_BUTTON
	local TOGGLE_BUTTON_CLICK_EXTENSION	= headerControls.TOGGLE_BUTTON_CLICK_EXTENSION

	local DEFAULT_CONTROLID = CENTER_BASELINE
	
	local g_currentBottomLeftHeader = DEFAULT_CONTROLID

	local ROW_OFFSET_Y = 5

	-- The Anchor class simply wraps a ZO_Anchor object with a target id, which we can later resolve into an actual control.
	-- This allows us to specify all anchor data at file scope and resolve the target controls only when needed.
	local Anchor = ZO_Object:Subclass()

	function Anchor:New(pointOnMe, targetId, pointOnTarget, offsetX, offsetY)
		local object = ZO_Object.New(self)
		object.targetId = targetId
		object.anchor = ZO_Anchor:New(pointOnMe, nil, pointOnTarget, offsetX, offsetY)
		return object
	end

	local DEFAULT_ANCHOR = 100

							-- {point, relativeTo_controlId, relativePoint, offsetX, offsetY}
	local anchors = {
		[TOGGLE_BUTTON]		= { Anchor:New(BOTTOMRIGHT, PARENT, BOTTOMRIGHT, -ROW_OFFSET_Y, 0) },
		--Show a control left of the toggle button: We can click this to expand the header again, and after that the control resizes to 0pixels and hides
		[TOGGLE_BUTTON_CLICK_EXTENSION]	= { Anchor:New(BOTTOMRIGHT, TOGGLE_BUTTON, BOTTOMLEFT, 0, 0),
							    	Anchor:New(BOTTOMLEFT, PARENT, BOTTOMLEFT, -ROW_OFFSET_Y, 0) },
		[DIVIDER_SIMPLE]	= { Anchor:New(TOPLEFT, nil, BOTTOMLEFT, 0, ROW_OFFSET_Y),
								Anchor:New(TOPRIGHT, nil, BOTTOMRIGHT, 0, 0) }, -- ZO_GAMEPAD_CONTENT_TITLE_DIVIDER_PADDING_Y
								
		[DEFAULT_ANCHOR]	= { Anchor:New(TOPLEFT, nil, BOTTOMLEFT, 0, 0),
								Anchor:New(TOPRIGHT, nil, BOTTOMRIGHT, 0, 0) },
	}
			-- {point, relativeTo_controlId, relativePoint, offsetX, offsetY}

	local function header_applyAnchorToControl(headerControl, anchorData, controlId, control)
		if headerControl:IsHidden() then headerControl:SetHidden(false) end
		local controls = headerControl.controls
		
		local targetId = anchorData.targetId or g_currentBottomLeftHeader
		local target = controls[targetId]
		
		anchorData.anchor:SetTarget(target)
		anchorData.anchor:AddToControl(control)
	end

	local function header_applyAnchorSetToControl(headerControl, anchorSet, controlId, collapsed)
		local controls = headerControl.controls
		local control = controls[controlId]
		control:SetHidden(false)
		
		header_applyAnchorToControl(headerControl, anchorSet[1], controlId, control)
		if anchorSet[2] then
			header_applyAnchorToControl(headerControl, anchorSet[2], controlId, control)
		end
		
		g_currentBottomLeftHeader = controlId

		local height = control:GetHeight()
		if controlId == TOGGLE_BUTTON then
			-- We want to keep height if collapsed but not add height for the button if not.
			height = collapsed and height or 0
		--The control processed is the collapsed header's toggle button "click extension"
		elseif controlId == TOGGLE_BUTTON_CLICK_EXTENSION then
			--Always fixed header height addition = 0 as the toggleButton already provided the extra height for the header
			--and this click extensikon control only is placed on the left to make it easier to expand the header again
			height = 0
			if collapsed then
				control:SetHidden(false)
				control:SetHeight(controls[TOGGLE_BUTTON]:GetHeight())
			else
				control:SetHidden(true)
				control:ClearAnchors()
				control:SetDimensions(0, 0)
			end
		end

		return height
	end

	local function showHeaderDivider(controlId)
		if g_currentBottomLeftHeader ~= DEFAULT_CONTROLID and controlId < TOGGLE_BUTTON then
			return g_currentBottomLeftHeader < DIVIDER_SIMPLE and controlId > DIVIDER_SIMPLE
		end
		return false
	end
	
	local function header_updateAnchors(headerControl, refreshResults, collapsed)
		--local headerHeight = collapsed and 0 or 17
		local headerHeight = 0
		local controls = headerControl.controls
		g_currentBottomLeftHeader = DEFAULT_CONTROLID

		for controlId, control in ipairs(controls) do
			control:ClearAnchors()
			control:SetHidden(true)

			local hidden = not refreshResults[controlId]
			-- There are no other header controls showing, so hide the toggle button, and it's extension
			if not collapsed and (controlId == TOGGLE_BUTTON or controlId == TOGGLE_BUTTON_CLICK_EXTENSION) and g_currentBottomLeftHeader == DEFAULT_CONTROLID then
				hidden = true
			end

			if not hidden then
				if showHeaderDivider(controlId) then
					-- Only show the divider if g_currentBottomLeftHeader is before DIVIDER_SIMPLE and controlId is after DIVIDER_SIMPLE
					headerHeight = headerHeight + header_applyAnchorSetToControl(headerControl, anchors[DIVIDER_SIMPLE], DIVIDER_SIMPLE)
				end

				local anchorSet = anchors[controlId] or anchors[DEFAULT_ANCHOR]
				headerHeight = headerHeight + header_applyAnchorSetToControl(headerControl, anchorSet, controlId, collapsed)
			end
		end
		
		if headerHeight > 0 then
			if not collapsed then
				headerHeight = headerHeight + (ROW_OFFSET_Y * 3)
			end
			headerControl:SetHeight(headerHeight)
		end
	end
	
	local function header_setAlignment(control, alignment, defaultAlignment)
		if control == nil then
			return
		end

		if alignment == nil then
			alignment = defaultAlignment
		end

		control:SetHorizontalAlignment(alignment)
	end

	local function header_setFont(control, font, defaultFont)
		if control == nil then
			return
		end

		if font == nil then
			font = defaultFont
		end

		control:SetFont(font)
	end

	local function header_processData(control, data, collapsed)
		-- if collapsed is true then this is hidden
		if control == nil or collapsed then
			return false
		end

		local dataType = type(data)

		if dataType == "function" then
			data = data(control)
		end

		if dataType == "string" or dataType == "number" then
			control:SetText(data)
		end

		if dataType == "boolean" then
			return data
		end

		return data ~= nil
	end

	local function header_processControl(control, customControl, collapsed)
		-- if collapsed is true then this is hidden
		if control == nil or collapsed then
			return false
		end

		local dataType = type(customControl)
		control:SetHidden(dataType ~= "userdata")
		if dataType == "userdata" then
			customControl:SetParent(control)
			customControl:ClearAnchors()
			customControl:SetAnchor(TOP, control, TOP, 0, 0)
			control:SetDimensions(customControl:GetDimensions())
			return true
		end

		return false
	end

	refreshDropdownHeader = function(comboBox, headerControl, options, collapsed)
		local controls = headerControl.controls

		headerControl:SetHidden(true)
		headerControl:SetHeight(0)

		local refreshResults = {}
		-- Title / Subtitle 
		refreshResults[TITLE] = header_processData(controls[TITLE], getValueOrCallback(options.titleText, options), collapsed)
		header_setFont(controls[TITLE], getValueOrCallback(options.titleFont, options), HeaderFontTitle)

		refreshResults[SUBTITLE] = header_processData(controls[SUBTITLE], getValueOrCallback(options.subtitleText, options), collapsed)
		header_setFont(controls[SUBTITLE], getValueOrCallback(options.subtitleFont, options), HeaderFontSubtitle)

		header_setAlignment(controls[TITLE], getValueOrCallback(options.titleTextAlignment, options), TEXT_ALIGN_CENTER)
		header_setAlignment(controls[SUBTITLE], getValueOrCallback(options.titleTextAlignment, options), TEXT_ALIGN_CENTER)

		-- Others
		refreshResults[FILTER_CONTAINER] = header_processData(controls[FILTER_CONTAINER], comboBox:IsFilterEnabled(), collapsed)
		refreshResults[CUSTOM_CONTROL] = header_processControl(controls[CUSTOM_CONTROL], getValueOrCallback(options.customHeaderControl, options), collapsed)
		refreshResults[TOGGLE_BUTTON] = header_processData(controls[TOGGLE_BUTTON], getValueOrCallback(options.headerCollapsible, options))
		refreshResults[TOGGLE_BUTTON_CLICK_EXTENSION] = header_processData(controls[TOGGLE_BUTTON_CLICK_EXTENSION], getValueOrCallback(options.headerCollapsible, options))

		header_updateAnchors(headerControl, refreshResults, collapsed)
	end
end

--------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------

local throttledCallDelaySuffixCounter = 0
local function throttledCall(callback, delay, throttledCallNameSuffix)
	delay = delay or throttledCallDelay
	throttledCallDelaySuffixCounter = throttledCallDelaySuffixCounter + 1
	throttledCallNameSuffix = throttledCallNameSuffix or tos(throttledCallDelaySuffixCounter)
	local throttledCallDelayTotalName = throttledCallDelayName .. throttledCallNameSuffix
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 4, tos(callback), tos(delay), tos(throttledCallDelayTotalName)) end
	EM:UnregisterForUpdate(throttledCallDelayTotalName)
	EM:RegisterForUpdate(throttledCallDelayTotalName, delay, function()
		EM:UnregisterForUpdate(throttledCallDelayTotalName)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 5, tos(callback), tos(throttledCallDelayTotalName)) end
		callback()
	end)
end
lib.ThrottledCall = throttledCall

--Run function arg to get the return value (passing in ... as optional params to that function),
--or directly use non-function return value arg
function getValueOrCallback(arg, ...)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 6, tos(arg)) end
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end
lib.GetValueOrCallback = getValueOrCallback

local function getHeaderControl(selfVar)
	if ZO_IsTableEmpty(selfVar.options) then return end
	local dropdownControl = selfVar.m_dropdownObject.control
	return dropdownControl.header, dropdownControl
end

getControlName = function(control, alternativeControl)
	local ctrlName = control ~= nil and (control.name or (control.GetName ~= nil and control:GetName()))
	if ctrlName == nil and alternativeControl ~= nil then
		ctrlName = (alternativeControl.name or (alternativeControl.GetName ~= nil and alternativeControl:GetName()))
	end
	ctrlName = ctrlName or "n/a"
	return ctrlName
end
lib.GetControlName = getControlName

--Control types which should save the parentName to the SV (for the header's toggleState) instead of each children
--e.g. ZO_ScrollLists
local headerToggleControlTypesSaveTheParent = {
	[CT_SCROLL] = true
}
local function getHeaderToggleStateControlSavedVariableName(selfVar)
	local openingControlOrComboBoxName = selfVar:GetUniqueName()
	if openingControlOrComboBoxName then
		local openingControlOrComboBoxCtrl = _G[openingControlOrComboBoxName]
		local parentCtrl = openingControlOrComboBoxCtrl:GetParent()
		--Parent control is a scrollList -> then save the parent as SV entry name, and not each single row of the scrollList
		if parentCtrl and parentCtrl.GetType and headerToggleControlTypesSaveTheParent[parentCtrl:GetType()] then
--d(">parentName: " ..tos(getControlName(parentCtrl)))
			return getControlName(parentCtrl)
		end
	end
--d(">openingControlOrComboBoxName: " ..tos(openingControlOrComboBoxName))
	return openingControlOrComboBoxName
end


--Check for isDivider, isHeader, isCheckbox ... in table (e.g. item.additionalData) and get the LSM entry type for it
local function checkTablesKeyAndGetEntryType(dataTable, text)
	for key, entryType in pairs(additionalDataKeyToLSMEntryType) do
--d(">checkTablesKeyAndGetEntryType - text: " ..tos(text)..", key: " .. tos(key))
		if dataTable[key] ~= nil then
--d(">>found dataTable[key]")
			if getValueOrCallback(dataTable[key], dataTable) == true then
--d("<<<checkTablesKeyAndGetEntryType - text: " ..tos(text) ..", l_entryType: " .. tos(entryType) .. ", key: " .. tos(key))
				return entryType
			end
		end
	end
	return nil
end

local function checkEntryType(text, entryType, additionalData, isAddDataTypeTable, options)
--df("[LSM]checkEntryType - text: %s, entryType: %s, additionalData: %s, isAddDataTypeTable: %s", tos(text), tos(entryType), tos(additionalData), tos(isAddDataTypeTable))
	if entryType == nil then
		isAddDataTypeTable = isAddDataTypeTable or false
		if isAddDataTypeTable == true then
			if additionalData == nil then isAddDataTypeTable = false
--d("<<<isAddDataTypeTable set to false")
			end
		end
		local l_entryType

		--Test was passed in?
		if text ~= nil then
--(">!!text check")
			--It should be a divider, according to the passed in text?
			if getValueOrCallback(text, ((isAddDataTypeTable and additionalData) or options)) == libDivider then
--d("<entry is divider, by text")
				return LSM_ENTRY_TYPE_DIVIDER
			end
		end

		--Additional data was passed in?
		if additionalData ~= nil and isAddDataTypeTable == true then
--d(">!!additionalData checks")
			if additionalData.entryType ~= nil then
--d(">>!!additionalData.entryType check")
				l_entryType = getValueOrCallback(additionalData.entryType, additionalData)
				if l_entryType ~= nil then
--d("<l_entryType by entryType: " ..tos(l_entryType))
					return l_entryType
				end
			end

			--Any isDivider, isHeader, isCheckbox, ...?
--d(">>!!checkTablesKeyAndGetEntryType additionalData")
			l_entryType = checkTablesKeyAndGetEntryType(additionalData, text)
			if l_entryType ~= nil then
--d("<l_entryType by checkTablesKeyAndGetEntryType: " ..tos(l_entryType))
				return l_entryType
			end

			local name = additionalData.name
			if name ~= nil then
--d(">>!!additionalData.name check")
				if getValueOrCallback(name, additionalData) == libDivider then
--d("<entry is divider, by name")
					return LSM_ENTRY_TYPE_DIVIDER
				end
			end
			local label = additionalData.label
			if name == nil and label ~= nil then
--d(">>!!additionalData.label check")
				if getValueOrCallback(label, additionalData) == libDivider then
--d("<entry is divider, by label")
					return LSM_ENTRY_TYPE_DIVIDER
				end
			end
		end
	end
	return entryType
end

local function hideCurrentlyOpenedLSMAndContextMenu()
	local openMenu = lib.openMenu
	if openMenu and openMenu:IsDropdownVisible() then
		ClearCustomScrollableMenu()
		openMenu:HideDropdown()
	end
end

local function hideContextMenu()
--d(debugPrefix .. "hideContextMenu")
	if g_contextMenu:IsDropdownVisible() then
		g_contextMenu:HideDropdown()
	end
	g_contextMenu:ClearItems()
end

local function clearTimeout()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 7) end
	EM:UnregisterForUpdate(dropdownCallLaterHandle)
end

local function setTimeout(callback)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 8) end
	clearTimeout()
	--Delay the dropdown close callback so we can move the mouse above a new dropdown control and keep that opened e.g.
	EM:RegisterForUpdate(dropdownCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 9, tos(SUBMENU_SHOW_TIMEOUT)) end
		clearTimeout()
		if callback then callback() end
	end)
end

--Mix in table entries in other table and skip existing entries. Optionally run a callback function on each entry
--e.g. getValueOrCallback(...)
local function mixinTableAndSkipExisting(targetData, sourceData, callbackFunc, ...)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 10, tos(callbackFunc)) end
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
local function defaultRecursiveCallback()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 11) end
	return false
end

--Add the entry additionalData value/options value to the "selfVar" object
local function updateVariable(selfVar, key, value)
	local zo_ComboBoxEntryKey = LSMEntryKeyZO_ComboBoxEntryKey[key]
	if zo_ComboBoxEntryKey ~= nil then
		if type(selfVar[zo_ComboBoxEntryKey]) ~= 'function' then
			selfVar[zo_ComboBoxEntryKey] = value
		end
	else
		if selfVar[key] == nil then
			selfVar[key] = value --value could be a function
		end
	end
end

--Loop at the entries .additionalData table and add them to the "selfVar" object directly
local function updateAdditionalDataVariables(selfVar)
	local additionalData = selfVar.additionalData
	if additionalData == nil then return end
	for key, value in pairs(additionalData) do
		updateVariable(selfVar, key, value)
	end
end

--Add subtable data._LSM and the next level subTable subTB
--and store a callbackFunction or a value at data._LSM[subTB][key]
local function addEntryLSM(data, subTB, key, valueOrCallbackFunc)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 12, tos(data), tos(subTB), tos(key), tos(valueOrCallbackFunc)) end
	if data == nil or subTB == nil or key == nil then return end
	local _lsm = data[LSM_DATA_SUBTABLE] or {}
	_lsm[subTB] = _lsm[subTB] or {} --create e.g. _LSM["funcData"] or _LSM["OriginalData"]

	_lsm[subTB][key] = valueOrCallbackFunc -- add e.g.  _LSM["funcData"]["name"] or _LSM["OriginalData"]["data"]
	data._LSM = _lsm --Update the original data's _LSM table
end

--Execute pre-stored callback functions of the data table, in data._LSM.funcData
local function updateDataByFunctions(data)
	data = getDataSource(data)

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 13, tos(data)) end
	--If subTable _LSM  (of row's data) contains funcData subTable: This contains the original functions passed in for
	--example "label" or "name" (instead of passing in strings). Loop the functions and execute those now for each found
	local lsmData = data[LSM_DATA_SUBTABLE] or NIL_CHECK_TABLE
	local funcData = lsmData[LSM_DATA_SUBTABLE_CALLBACK_FUNCTIONS] or NIL_CHECK_TABLE

	--Execute the callback functions for e.g. "name", "label", "checked", "enabled", ... now
	for _, updateFN in pairs(funcData) do
		updateFN(data)
	end
end

--Check if any data.* entry is a function (via table possibleEntryDataWithFunctionAndDefaultValue) and add them to
--subTable data._LSM.funcData
--> Those functions will be executed at Show of the LSM dropdown via calling function updateDataByFunctions. The functions
--> will update the data.* keys then with their "currently determined values" properly.
--> Example: "name" -> function -> prepare as entry is created and store in data._LSM.funcData["name"] -> execute on show
--> update data["name"] with the returned value from that prestored function in data._LSM.funcData["name"]
--> If the function does not return anything (nil) the nilOrTrue of table possibleEntryDataWithFunctionAndDefaultValue
--> will be used IF i is true (e.g. for the "enabled" state of the entry)
local function updateDataValues(data, onlyTheseEntries)
	--Backup all original values of the data passed in in data's subtable _LSM.OriginalData.data
	--so we can leave this untouched and use it to check if e.g. data.m_highlightTemplate etc. were passed in to "always overwrite"
	if data and data[LSM_DATA_SUBTABLE] == nil then
--d(debugPrefix .. "Added _LSM subtable and placing originalData")
		addEntryLSM(data, LSM_DATA_SUBTABLE_ORIGINAL_DATA, "data", ZO_ShallowTableCopy(data)) --"OriginalData"
	end

	--Did the addon pass in additionalData for the entry?
	-->Map the keys from LSM entry to ZO_ComboBox entry and only transfer the relevant entries directly to itemEntry
	-->so that ZO_ComboBox can use them properly
	-->Pass on custom added values/functions too
	updateAdditionalDataVariables(data)

	--Compatibility fix for missing name in data -> Use label (e.g. sumenus of LibCustomMenu only have "label" and no "name")
	if data.name == nil and data.label then
		data.name = data.label
	end

	local checkOnlyProvidedKeys = not ZO_IsTableEmpty(onlyTheseEntries)
	for key, l_nilToTrue in pairs(possibleEntryDataWithFunction) do
		local goOn = true
		if checkOnlyProvidedKeys == true and not ZO_IsElementInNumericallyIndexedTable(onlyTheseEntries, key) then
			goOn = false
		end
		if goOn then
			local dataValue = data[key] --e.g. data["name"] -> either it's value or it's function
			if type(dataValue) == 'function' then
				if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 14, tos(key)) end

				--local originalFuncOfDataKey = dataValue

				--Add the _LSM.funcData[key] = function to run on Show of the LSM dropdown now
				addEntryLSM(data, LSM_DATA_SUBTABLE_CALLBACK_FUNCTIONS, key, function(p_data) --'funcData'
					--Run the original function of the data[key] now and pass in the current provided data as params
					local value = dataValue(p_data)
					if value == nil and l_nilToTrue == true then
						value = l_nilToTrue
					end
					if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 15, tos(key), tos(value)) end

					--Update the current data[key] with the determiend current value
					p_data[key] = value
				end)
				--defaultValue is true and data[*] is nil
			elseif l_nilToTrue == true and dataValue == nil then
				--e.g. data["enabled"] = true to always enable the row if nothing passed in explicitly
				if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 16, tos(key), tos(l_nilToTrue)) end
				data[key] = l_nilToTrue
			end
		end
	end

	--Execute the callbackFunctions (the functions of the data[key] were moved to subtable _LSM.funcData via function addEntryLSM above)
	--and update data[key] with the results of that functions now
	-->This way we keep the original callback functions for later but alwasy got the actual value returned by them in data[key]
	updateDataByFunctions(data)
end

--Check if an entry got the isNew set
local function getIsNew(_entry)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 17) end
	return getValueOrCallback(_entry.isNew, _entry) or false
end

local function preUpdateSubItems(item)
	if item[LSM_DATA_SUBTABLE] == nil then
		--Get/build the additionalData table, and name/label etc. functions' texts and data
		updateDataValues(item)
	end
	--Return if the data got a new flag
	return getIsNew(item)
end

-- Prevents errors on the off chance a non-string makes it through into ZO_ComboBox
local function verifyLabelString(data)
	--Check for data.* keys to run any function and update data[key] with actual values
	updateDataByFunctions(data)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 18, tos(data.name)) end
	--Require the name to be a string
	return type(data.name) == 'string'
end

-- Recursively loop over drdopdown entries, and submenu dropdown entries of that parent dropdown, and check if e.g. isNew needs to be updated
-- Used for the search of the collapsible header too
local function recursiveOverEntries(entry, callback)
	callback = callback or defaultRecursiveCallback
	
	local result = callback(entry)
	local submenu = (entry.entries ~= nil and getValueOrCallback(entry.entries, entry)) or {}

	--local submenuType = type(submenu)
	--assert(submenuType == 'table', sfor('['..MAJOR..':recursiveOverEntries] table expected, got %q = %s', "submenu", tos(submenuType)))
	if type(submenu) == "table" and #submenu > 0 then
		for _, subEntry in pairs(submenu) do
			local subEntryResult = recursiveOverEntries(subEntry, callback)
			if subEntryResult then
				result = subEntryResult
			end
		end
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 19, tos(#submenu), tos(result)) end
	return result
end

--(Un)Silence the OnClicked sound of a selected dropdown entry
local function silenceEntryClickedSound(doSilence, entryType)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 20, tos(doSilence), tos(entryType)) end
	local soundNameForSilence = entryTypeToSilenceSoundName[entryType]
	if soundNameForSilence == nil then return end
	if doSilence == true then
		SOUNDS[soundNameForSilence] = soundClickedSilenced
	else
		local origSound = entryTypeToOriginalSelectedSound[entryType]
		SOUNDS[soundNameForSilence] = origSound
	end
end

--Get the options of the scrollable dropdownObject
local function getOptionsForDropdown(dropdown)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 21) end
	return dropdown.owner.options or {}
end

--Check if a sound should be played if a dropdown entry was selected
local function playSelectedSoundCheck(dropdown, entryType)
	entryType = entryType or LSM_ENTRY_TYPE_NORMAL
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 22, tos(entryType)) end

	silenceEntryClickedSound(false, entryType)

	local soundToPlay
	local soundToPlayOrig = entryTypeToOriginalSelectedSound[entryType]
	local options = getOptionsForDropdown(dropdown)

	if options ~= nil then
		--Chosen at options to play no selected sound?
		if getValueOrCallback(options.selectedSoundDisabled, options) == true then
			silenceEntryClickedSound(true, entryType)
			return
		else
			--Custom selected sound passed in?
			soundToPlay = getValueOrCallback(options.selectedSound, options)
			--Use default selected sound
			if soundToPlay == nil then soundToPlay = soundToPlayOrig end
		end
	else
		soundToPlay = soundToPlayOrig
	end
	PlaySound(soundToPlay)
end

--Recursivley map the entries of a submenu and add them to the mapTable
--used for the callback "NewStatusUpdated" to provide the mapTable with the entries
local function doMapEntries(entryTable, mapTable, entryTableType)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 23) end
	if entryTableType == nil then
		-- If getValueOrCallback returns nil then return {}
		entryTable = getValueOrCallback(entryTable) or {}
	end

	for _, entry in pairs(entryTable) do
		if entry.entries then
			doMapEntries(entry.entries, mapTable)
		end
		
		if entry.callback then
			mapTable[entry] = entry
		end
	end
end

-- This function will create a map of all entries recursively. Useful when there are submenu entries
-- and you want to use them for comparing in the callbacks, NewStatusUpdated, CheckboxUpdated, RadioButtonUpdated
local function mapEntries(entryTable, mapTable, blank)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 24) end

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

local function updateIcon(control, data, iconIdx, singleIconDataOrTab, multiIconCtrl, parentHeight)
	--singleIconDataTab can be a table or any other format (supported: string or function returning a string)
	local iconValue
	local iconDataType = type(singleIconDataOrTab)
	local iconDataGotMoreParams = false
	--Is the passed in iconData a table?
	if iconDataType == "table" then
		--table of format { [1] = "texture path to .dds here or a function returning the path" }
		if singleIconDataOrTab[1] ~= nil then
			iconValue = getValueOrCallback(singleIconDataOrTab[1], data)
		--or a table containing more info like { [1]= {iconTexture = "path or funciton returning a path", width=24, height=24, tint=ZO_ColorDef, narration="", tooltip=function return "tooltipText" end}, [2] = { ... } }
		else
			iconDataGotMoreParams = true
			iconValue = getValueOrCallback(singleIconDataOrTab.iconTexture, data)
		end
	else
		--No table, only  e.g. String or function returning a string
		iconValue = getValueOrCallback(singleIconDataOrTab, data)
	end

	local isNewValue = getValueOrCallback(data.isNew, data)
	local visible = isNewValue == true or iconValue ~= nil

	local iconHeight = parentHeight
	-- This leaves a padding to keep the label from being too close to the edge
	local iconWidth = visible and iconHeight or WITHOUT_ICON_LABEL_DEFAULT_OFFSETX

	if visible == true then
		multiIconCtrl.data = multiIconCtrl.data or {}
		if iconIdx == 1 then multiIconCtrl.data.tooltipText = nil end

		if iconDataGotMoreParams then
			--Icon's height and width
			if singleIconDataOrTab.width ~= nil then
				iconWidth = zo_clamp(getValueOrCallback(singleIconDataOrTab.width, data), WITHOUT_ICON_LABEL_DEFAULT_OFFSETX, parentHeight)
			end
			if singleIconDataOrTab.height ~= nil then
				iconHeight = zo_clamp(getValueOrCallback(singleIconDataOrTab.height, data), WITHOUT_ICON_LABEL_DEFAULT_OFFSETX, parentHeight)
			end
		end

		if isNewValue == true then
			multiIconCtrl:AddIcon(iconNewIcon, nil, iconNarrationNewValue)
			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 25) end
			--d(debugPrefix .. "updateIcon - Adding \'new icon\'")
		end
		if iconValue ~= nil then
			--Icon's color
			local iconTint
			if iconDataGotMoreParams then
				iconTint = getValueOrCallback(singleIconDataOrTab.iconTint, data)
				if type(iconTint) == "string" then
					local iconColorDef = ZO_ColorDef:New(iconTint)
					iconTint = iconColorDef
				end
			end

			--Icon's tooltip? Reusing default tooltip functions of controls: ZO_Options_OnMouseEnter and ZO_Options_OnMouseExit
			-->Just add each icon as identifier and then the tooltipText (1 line = 1 icon)
			local tooltipForIcon = (visible and iconDataGotMoreParams and getValueOrCallback(singleIconDataOrTab.tooltip, data)) or nil
			if tooltipForIcon ~= nil and tooltipForIcon ~= "" then
				local tooltipTextAtMultiIcon = multiIconCtrl.data.tooltipText
				if tooltipTextAtMultiIcon == nil then
					tooltipTextAtMultiIcon =  zo_iconTextFormat(iconValue, 24, 24, tooltipForIcon, iconTint)
				else
					tooltipTextAtMultiIcon = tooltipTextAtMultiIcon .. "\n" .. zo_iconTextFormat(iconValue, 24, 24, tooltipForIcon, iconTint)
				end
				multiIconCtrl.data.tooltipText = tooltipTextAtMultiIcon
			end

			--Icon's narration
			local iconNarration = (iconDataGotMoreParams and getValueOrCallback(singleIconDataOrTab.iconNarration, data)) or nil
			multiIconCtrl:AddIcon(iconValue, iconTint, iconNarration)
			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 26, tos(iconIdx), tos(visible), tos(iconValue), tos(iconTint), tos(iconWidth), tos(iconHeight), tos(iconNarration)) end
		end

		return true, iconWidth, iconHeight
	end
	return false, iconWidth, iconHeight
end

--Update the icons of a dropdown entry's MultiIcon control
local function updateIcons(control, data)
	local multiIconContainerCtrl = control.m_iconContainer
	local multiIconCtrl = control.m_icon
	multiIconCtrl:ClearIcons()

	local iconWidth = WITHOUT_ICON_LABEL_DEFAULT_OFFSETX
	local parentHeight = multiIconCtrl:GetParent():GetHeight()
	local iconHeight = parentHeight

	local iconData = getValueOrCallback(data.icon, data)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 27, tos(iconData ~= nil and #iconData or 0)) end

	local anyIconWasAdded = false
	local iconDataType = iconData ~= nil and type(iconData) or nil
	if iconDataType ~= nil then
		if iconDataType ~= 'table' then
			--If only a "any.dds" texture path or a function returning this was passed in
			iconData = { [1] = { iconTexture = iconData } }
		end
		for iconIdx, singleIconData in ipairs(iconData) do
			local l_anyIconWasAdded, l_iconWidth, l_iconHeight = updateIcon(control, data, iconIdx, singleIconData, multiIconCtrl, parentHeight)
			if l_anyIconWasAdded == true then
				anyIconWasAdded = true
			end
			if l_iconWidth > iconWidth then iconWidth = l_iconWidth end
			if l_iconHeight > iconHeight then iconHeight = l_iconHeight end
		end

	end
	multiIconCtrl:SetMouseEnabled(anyIconWasAdded) --todo 20240527 Make that dependent on getValueOrCallback(data.enabled, data) ?! And update via multiIconCtrl:Hide()/multiIconCtrl:Show() on each show of menu!
	multiIconCtrl:SetDrawTier(DT_MEDIUM)
	multiIconCtrl:SetDrawLayer(DL_CONTROLS)
	multiIconCtrl:SetDrawLevel(10)

	if anyIconWasAdded then
		multiIconCtrl:SetHandler("OnMouseEnter", function(...)
			ZO_Options_OnMouseEnter(...)
			InformationTooltipTopLevel:BringWindowToTop()
		end)
		multiIconCtrl:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)

		multiIconCtrl:Show() --todo 20240527 Make that dependent on getValueOrCallback(data.enabled, data) ?! And update via multiIconCtrl:Hide()/multiIconCtrl:Show() on each show of menu!
	end


	-- Using the control also as a padding. if no icon then shrink it
	-- This also allows for keeping the icon in size with the row height.
	multiIconContainerCtrl:SetDimensions(iconWidth, iconHeight)
	--TODO: see how this effects it
	--	multiIconCtrl:SetDimensions(iconWidth, iconHeight)
	multiIconCtrl:SetHidden(not anyIconWasAdded)
end

-- 2024-06-14 IsjustaGhost: oh crap. it may be returturning m_owner, which would be the submenu object
--> context menu's submenu directly closing on click on entry because comboBox passed in (which was determined via getComboBox) is not the correct one
--> -all submenus are g_contextMenu.m_submenu.m_dropdownObject.m_combobox = g_contextMenu.m_container.m_comboBox
--> -m_owner is personal. m_comboBox is singular to link all children to the owner
local function getComboBox(control, owningMenu)
	if control then
		--owningMenu boolean will be used to determine the m_comboBox (main menu) only and not the m_owner
		-->Needed for LSM context menus that do not open on any LSM control, but standalone!
		-->Checked in onMouseUp's callback function
		if owningMenu then
			if control.m_comboBox then
				return control.m_comboBox
			end
		else
			if control.m_owner then
				return control.m_owner
			elseif control.m_comboBox then
				return control.m_comboBox
			end
		end
	end

	if type(control) == 'userdata' then
		local owningWindow = control:GetOwningWindow()
		if owningWindow then
			if owningWindow.object and owningWindow.object ~= control then
				return getComboBox(owningWindow.object, owningMenu)
			end
		end
	end
end


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


--------------------------------------------------------------------
-- Local entry/item data functions
--------------------------------------------------------------------
--Functions to run per item's entryType, after the item has been setup (e.g. to add missing mandatory data or change visuals)
local postItemSetupFunctions = {
	[LSM_ENTRY_TYPE_SUBMENU] = function(comboBox, itemEntry)
		itemEntry.isNew = recursiveOverEntries(itemEntry, preUpdateSubItems)
	end,
	[LSM_ENTRY_TYPE_HEADER] = function(comboBox, itemEntry)
		itemEntry.font = comboBox.headerFont or itemEntry.font
		itemEntry.color = comboBox.headerColor or itemEntry.color
	end,
	[LSM_ENTRY_TYPE_DIVIDER] = function(comboBox, itemEntry)
		itemEntry.name = libDivider
	end,
}


--20240727 Prevent selection of entries if a context menu was opened and a left click was done "outside of the context menu"
--Param isContextMenu will be true if coming from contextMenuClass:GetHiddenForReasons function or it will change to true if
--any contextMenu is curently shown as this function runs
--Returns boolean true if the click should NOT affect the clicked control, and should only close the contextMenu
local function checkIfHiddenForReasons(selfVar, button, isContextMenu, owningWindow, mocCtrl, comboBox, entry, isSubmenu)
	isContextMenu = isContextMenu or false

	local returnValue = false

	--Check if context menu is currently shown
	local isContextMenuVisible = isContextMenu or g_contextMenu:IsDropdownVisible()
	if not isContextMenu and isContextMenuVisible == true then isContextMenu = true end

	local dropdownObject = selfVar.m_dropdownObject
	local contextMenuDropdownObject = g_contextMenu.m_dropdownObject
	local isOwnedByComboBox = dropdownObject:IsOwnedByComboBox(comboBox)
	local isCntxtMenOwnedByComboBox = contextMenuDropdownObject:IsOwnedByComboBox(comboBox)
--d(">isOwnedByCBox: " .. tos(isOwnedByComboBox) .. ", isCntxtMenVis: " .. tos(isContextMenuVisible) .. ", isCntxtMenOwnedByCBox: " ..tos(isCntxtMenOwnedByComboBox) .. ", isSubmenu: " .. tos(selfVar.isSubmenu))


	if not isContextMenu then
		--No context menu currently shown
		if button == MOUSE_BUTTON_INDEX_LEFT then
			--todo 2024-08-07 Submenu -> Context menu -> Click on entry at the submenu (but outside the context menu) closes aLL menus -> why? It must only close the contextMenu then
			if isOwnedByComboBox == true then
				if not comboBox then
					--todo check if submenu opened -> How?

					--d("<1not comboBox -> true")
					returnValue = true
				else
					--Is the mocEntry an empty table (something else was clicked than a LSM entry)
					if ZO_IsTableEmpty(entry) then
						--d("<1ZO_IsTableEmpty(entry) -> true")
						returnValue = true
					else

						if mocCtrl then
							local owner = mocCtrl.m_owner
							if owner then
								--d("1>>owner found")
								--Does moc entry belong to a LSM menu and it IS the current comboBox?
								if owner == comboBox then
									--d(">>1 - closeOnSelect: " ..tos(mocCtrl.closeOnSelect))
									returnValue = mocCtrl.closeOnSelect
								else
									--d(">>1 - true")
									--Does moc entry belong to a LSM menu but it's not the current comboBox?
									returnValue = true
								end
							end
						else
							--d(">>1 - no mocCtrl")
						end
					end
				end
			elseif isCntxtMenOwnedByComboBox ~= nil then
				--20240807 Works for context menu clicks rasied from a subenu but not if context menu go a submenu itsself....
				return not isCntxtMenOwnedByComboBox
			else
				returnValue = true
			end

		elseif button == MOUSE_BUTTON_INDEX_RIGHT then
			returnValue = true --close as a context menu might open
		end

	else
		local doNotHideContextMenu = false
		--Context menu is currently shown
		if button == MOUSE_BUTTON_INDEX_LEFT then
			--Is there no LSM comboBox available? Close the context menu
			if not comboBox then
				--d("<2not comboBox -> true")
				returnValue = true
			else
				--Is the mocEntry an empty table (something else was clicked than a LSM entry)
				if ZO_IsTableEmpty(entry) then
					--d("<2ZO_IsTableEmpty(entry) -> true; ctxtDropdown==mocCtrl.dropdown: " ..tos(contextMenuDropdownObject == mocCtrl.m_dropdownObject) .. "; owningWind==cntxMen: " ..tos(mocCtrl:GetOwningWindow() == g_contextMenu.m_dropdown))
					-- Was e.g. a context menu's submenu search header's editBox or the refresh button left clicked?
					if mocCtrl then
						if (contextMenuDropdownObject == mocCtrl.m_dropdownObject or (mocCtrl.GetOwningWindow and mocCtrl:GetOwningWindow() == g_contextMenu.m_dropdown)) then
--d(">>2 - submenu search header editBox or refresh button clicked")
							returnValue = false
							doNotHideContextMenu = true
						else
							-- or was a checkbox's [ ] box control in a contextMenu's submenu clicked directly?
							if mocCtrl.m_owner == nil then
								local parent = mocCtrl:GetParent()
								mocCtrl = parent
							end
							local owner = mocCtrl.m_owner
--d(">>2 - isSubmenu: " .. tos(isSubmenu) .. "/" .. tos(owner.isSubmenu) .. "; closeOnSelect: " .. tos(mocCtrl.closeOnSelect))
							if owner and (isSubmenu == true or owner.isSubmenu == true) and isCntxtMenOwnedByComboBox == true then
--d(">>2 - clicked contextMenu entry, not moc.closeOnSelect: " .. tos(not mocCtrl.closeOnSelect))
								returnValue = not mocCtrl.closeOnSelect
							else
								returnValue = true
							end
						end
					else
						returnValue = true
					end
				else

					if mocCtrl then
						local owner = mocCtrl.m_owner or mocCtrl:GetParent().m_owner
						if owner then
							--d(">>2_1owner found")
							--Does moc entry belong to a LSM menu and it IS the current contextMenu?
							if owner == g_contextMenu then --comboBox then
								--d(">>2_1 - closeOnSelect: " ..tos(mocCtrl.closeOnSelect))
								returnValue = mocCtrl.closeOnSelect
							else
								--d(">>2_1 - true: isSubmenu: " .. tos(isSubmenu) .. "/" .. tos(owner.isSubmenu) .. "; closeOnSelect: " .. tos(mocCtrl.closeOnSelect))
								--Does moc entry belong to a LSM menu but it's not the current contextMenu?
								--Is it a submenu entry of the context menu?
								if (isSubmenu == true or owner.isSubmenu == true) and isCntxtMenOwnedByComboBox == true then
									--d(">>>2_1 - clicked contextMenu entry, not moc.closeOnSelect: " .. tos(not mocCtrl.closeOnSelect))
									returnValue = not mocCtrl.closeOnSelect
								else
									--d(">>>2_1 - true")
									returnValue = true
								end
							end
						else
							--d(">>2_1 - owner not found")
						end
					end
				end
			end
			--Do not hide the contextMenu if the mocCtrl clicked should keep the menu opened
			if mocCtrl and mocCtrl.closeOnSelect == false then
				doNotHideContextMenu = true
				suppressNextOnGlobalMouseUp = true
				returnValue = false
			end

		elseif button == MOUSE_BUTTON_INDEX_RIGHT then
			-- Was e.g. the search header's editBox left clicked?
			if mocCtrl and contextMenuDropdownObject == mocCtrl.m_dropdownObject then
				returnValue = false
				doNotHideContextMenu = true
			else
				returnValue = true --close context menu
			end
		end

		--Reset the contextmenus' opened dropdown value so next check in comboBox_base:HiddenForReasons(button) will not show g_contextMenu:IsDropdownVisible() == true!
		if not doNotHideContextMenu then
			hideContextMenu()
		end
	end

	return returnValue
end

--Check if a context menu was shown and a control not belonging to that context menu was clicked
--Returns boolean true if that was the case -> Prevent selection of entries or changes of radioButtons/checkboxes
--while a context menu was opened and one directly clicks on that other entry
local function checkIfContextMenuOpenedButOtherControlWasClicked(control, comboBox, buttonId)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 29, tos(comboBox == g_contextMenu), tos(g_contextMenu:IsDropdownVisible())) end
	if comboBox ~= g_contextMenu and g_contextMenu:IsDropdownVisible() then
--d("!!!!ContextMenu - check if OPENED!!!!! comboBox: " ..tos(comboBox))
		if comboBox ~= nil then
			return comboBox:HiddenForReasons(buttonId)
		end
	end
--d("<<combobox not hidden for reasons")
	return false
end

local function getMouseOver_HiddenFor_Info()
	local mocCtrl = moc()
	local owningWindow = mocCtrl and mocCtrl:GetOwningWindow()
	local comboBox = getComboBox(owningWindow or mocCtrl)

	--If submenu exists and is shown: the combobox for the m_dropdownObject owner check should be the submenu's one
	--[[
	if mocCtrl.m_owner and mocCtrl.m_owner.isSubmenu == true then
		local ownerSubmenu = mocCtrl.m_owner.m_submenu
		if ownerSubmenu and ownerSubmenu:IsDropdownVisible() then
d(">submenu is open -> use it for owner check")
			comboBox = ownerSubmenu
		end
	end
	]]

	-- owningWindow, mocCtrl, comboBox, entry
	return owningWindow, mocCtrl, comboBox, getControlData(mocCtrl)
end


-- Recursively check for new entries.
-->Done within preUpdateSubItems func now
--[[
local function areAnyEntriesNew(entry)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 30) end
	return recursiveOverEntries(entry, getIsNew, true)
end
]]

-- Add/Remove the new status of a dropdown entry.
-- This works up from the mouse-over entry's submenu up to the dropdown,
-- as long as it does not run into a submenu still having a new entry.
local function updateSubmenuNewStatus(control)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 31) end
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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 32) end
	if data.isNew then
		-- Only directly change status on non-submenu entries. The are effected by child entries
		if data.entries == nil then
			data.isNew = false
			
			lib:FireCallbacks('NewStatusUpdated', control, data)
			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 33, tos(getControlName(control))) end

			control.m_dropdownObject:Refresh(data)
			
			local parent = data.m_parentControl
			if parent then
				updateSubmenuNewStatus(parent)
			end
		end
	end
end

local function validateEntryType(item)
	--Prefer passed in entryType (if any provided)
	local entryType = getValueOrCallback(item.entryType, item)

	--Check if any other entryType could be determined
	local isDivider = (((item.label ~= nil and item.label == libDivider) or item.name == libDivider) or (item.isDivider ~= nil and getValueOrCallback(item.isDivider, item))) or LSM_ENTRY_TYPE_DIVIDER == entryType
	local isHeader = (item.isHeader ~= nil and getValueOrCallback(item.isHeader, item)) or LSM_ENTRY_TYPE_HEADER == entryType
	local isButton = (item.isButton ~= nil and getValueOrCallback(item.isButton, item)) or LSM_ENTRY_TYPE_BUTTON == entryType
	local isRadioButton = (item.isRadioButton ~= nil and getValueOrCallback(item.isRadioButton, item)) or LSM_ENTRY_TYPE_RADIOBUTTON == entryType
	local isCheckbox = (item.isCheckbox ~= nil and getValueOrCallback(item.isCheckbox, item)) or LSM_ENTRY_TYPE_CHECKBOX == entryType
	local hasSubmenu = (item.entries ~= nil and getValueOrCallback(item.entries, item) ~= nil) or LSM_ENTRY_TYPE_SUBMENU == entryType

	--If no entryType was passed in: Get the entryType by the before determined data
	if not entryType or entryType == LSM_ENTRY_TYPE_NORMAL then
		entryType = hasSubmenu and LSM_ENTRY_TYPE_SUBMENU or
					isDivider and LSM_ENTRY_TYPE_DIVIDER or
					isHeader and LSM_ENTRY_TYPE_HEADER or
					isCheckbox and LSM_ENTRY_TYPE_CHECKBOX or
					isButton and LSM_ENTRY_TYPE_BUTTON or
					isRadioButton and LSM_ENTRY_TYPE_RADIOBUTTON or
					LSM_ENTRY_TYPE_NORMAL
	end

	--Update the item's variables
	item.isHeader = isHeader
	item.isButton = isButton
	item.isRadioButton = isRadioButton
	item.isDivider = isDivider
	item.isCheckbox = isCheckbox
	item.hasSubmenu = hasSubmenu

	--Set the entryType to the itm
	item.entryType = entryType
end

--After item's setupFunction was executed we need to run some extra functions on each subitem (submenus e.g.)?
local function runPostItemSetupFunction(comboBox, itemEntry)
	local postItem_SetupFunc = postItemSetupFunctions[itemEntry.entryType]
	if postItem_SetupFunc ~= nil then
		postItem_SetupFunc(comboBox, itemEntry)
	end
end

--Set the custom XML virtual template for a dropdown entry
local function setItemEntryCustomTemplate(item, customEntryTemplates)
	local entryType = item.entryType
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 34, tos(item.label or item.name), tos(entryType)) end

	if entryType then
		local customEntryTemplate = customEntryTemplates[entryType].template
		zo_comboBox_setItemEntryCustomTemplate(item, customEntryTemplate)
	end
end

-- We can add any row-type post checks and update dataEntry with static values.
local function addItem_Base(self, itemEntry)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 35, tos(itemEntry)) end

	--Get/build data.label and/or data.name / data.* values, and others (see table LSMEntryKeyZO_ComboBoxEntryKey)
	updateDataValues(itemEntry)

	--Validate the entryType now
	validateEntryType(itemEntry)

	if not itemEntry.customEntryTemplate then
		--Set it's XML entry row template
		setItemEntryCustomTemplate(itemEntry, self.XMLRowTemplates)
	end

	--Run a post setup function to update mandatory data or change visuals, for the entryType
	-->Recursively checks all submenu and their nested submenu entries
	runPostItemSetupFunction(self, itemEntry)
end

--------------------------------------------------------------------
-- Local tooltip functions
--------------------------------------------------------------------

local function resetCustomTooltipFuncVars()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 36) end
	lib.lastCustomTooltipFunction = nil
	lib.onHideCustomTooltipFunc = nil
end

--Hide the tooltip of a dropdown entry
local function hideTooltip(control)
--d(debugPrefix .. "hideTooltip - name: " .. tos(getControlName(control)))
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 37, tos(lib.onHideCustomTooltipFunc)) end
	if lib.onHideCustomTooltipFunc then
		lib.onHideCustomTooltipFunc()
	else
		ZO_Tooltips_HideTextTooltip()
	end
	resetCustomTooltipFuncVars()
end

local function getTooltipAnchor(self, control, tooltipText, hasSubmenu)
	local relativeTo = control
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 38, tos(getControlName(control)), tos(tooltipText), tos(hasSubmenu)) end

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
-doShow boolean to show if your mouse is inside the control and should show the tooltip. Must be false if tooltip should hide
-data The table with the current data of the rowControl
	-> To distinguish if the tooltip should be hidden or shown:	If 1st param data is missing the tooltip will be hidden! If data is provided the tooltip wil be shown
-rowControl The userdata of the control the tooltip should show about
-point, offsetX, offsetY, relativePoint: Suggested anchoring points

Example - Show an item tooltip of an inventory item
data.customTooltip = function(control, doShow, data, relativeTo, point, offsetX, offsetY, relativePoint)
	ClearTooltip(ItemTooltip)
	if doShow and data then
		InitializeTooltip(ItemTooltip, relativeTo, point, offsetX, offsetY, relativePoint)
		ItemTooltip:SetBagItem(data.bagId, data.slotIndex)
		ItemTooltipTopLevel:BringWindowToTop()
	end
end

Another example using a custom control of your addon to show the tooltip:
customTooltipFunc = function(control, doShow, data, rowControl, point, offsetX, offsetY, relativePoint)
	if not doShow or data == nil then
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

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 39, tos(getControlName(control)), tos(tooltipText), tos(hasSubmenu), tos(customTooltipFunc)) end

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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 40, tos(settingId), tos(isSettingEnabled)) end
	return isSettingEnabled
end

local function isAccessibilityModeEnabled()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 41) end
	return isAccessibilitySettingEnabled(ACCESSIBILITY_SETTING_ACCESSIBILITY_MODE)
end

local function isAccessibilityUIReaderEnabled()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 42) end
	return isAccessibilityModeEnabled() and isAccessibilitySettingEnabled(ACCESSIBILITY_SETTING_SCREEN_NARRATION)
end

--Currently commented as these functions are used in each addon and the addons either pass in options.narrate table so their
--functions will be called for narration, or not
local function canNarrate()
	--todo: Add any other checks, like "Is any LSM menu still showing and narration should still read?"
	return true
end

--local customNarrateEntryNumber = 0
local function addNewUINarrationText(newText, stopCurrent)
	if isAccessibilityUIReaderEnabled() == false then return end
	stopCurrent = stopCurrent or false
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 43, tos(newText), tos(stopCurrent)) end
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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 44, tos(updaterName), tos(delay)) end

	EM:UnregisterForUpdate(updaterName)
	if isAccessibilityUIReaderEnabled() == false or callbackFunc == nil then return end
	delay = delay or 1000
	EM:RegisterForUpdate(updaterName, delay, function()
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 45, tos(updaterName)) end
		if isAccessibilityUIReaderEnabled() == false then EM:UnregisterForUpdate(updaterName) return end
		callbackFunc()
		EM:UnregisterForUpdate(updaterName)
	end)
end

--Own narration functions, if ever needed -> Currently the addons pass in their narration functions
local function onMouseEnterOrExitNarrate(narrateText, stopCurrent)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 46, tos(narrateText), tos(stopCurrent)) end
	onUpdateDoNarrate("OnMouseEnterExit", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end

local function onSelectedNarrate(narrateText, stopCurrent)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 47, tos(narrateText), tos(stopCurrent)) end
	onUpdateDoNarrate("OnEntryOrButtonSelected", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end

local function onMouseMenuOpenOrCloseNarrate(narrateText, stopCurrent)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 48, tos(narrateText), tos(stopCurrent)) end
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
	["OnRadioButtonUpdated"] = 	onSelectedNarrate,
}

--------------------------------------------------------------------
-- Dropdown entry/row handlers
--------------------------------------------------------------------

local function onMouseEnter(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 49, tos(getControlName(control)), tos(hasSubmenu)) end
	lib:FireCallbacks('EntryOnMouseEnter', control, data)
	dropdown:Narrate("OnEntryMouseEnter", control, data, hasSubmenu)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 50, tos(getControlName(control)), tos(hasSubmenu)) end

	return dropdown
end

local function onMouseExit(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 51, tos(getControlName(control)), tos(hasSubmenu)) end
	lib:FireCallbacks('EntryOnMouseExit', control, data)
	dropdown:Narrate("OnEntryMouseExit", control, data, hasSubmenu)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 52, tos(getControlName(control)), tos(hasSubmenu)) end

	return dropdown
end

local function onMouseUp(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject

	lib:FireCallbacks('OnEntrySelected', control, data)
	dropdown:Narrate("OnEntrySelected", control, data, hasSubmenu)

	hideTooltip(control)
	return dropdown
end

local has_submenu = true
local no_submenu = false

local handlerFunctions  = {
	['onMouseEnter'] = {
		[LSM_ENTRY_TYPE_NORMAL] = function(control, data, ...)
			onMouseEnter(control, data, no_submenu)
			clearNewStatus(control, data)
			return not control.closeOnSelect
		end,
		[LSM_ENTRY_TYPE_HEADER] = function(control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[LSM_ENTRY_TYPE_DIVIDER] = function(control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[LSM_ENTRY_TYPE_SUBMENU] = function(control, data, ...)
			--d( debugPrefix .. 'onMouseEnter [LSM_ENTRY_TYPE_SUBMENU]')
			local dropdown = onMouseEnter(control, data, has_submenu)
			clearTimeout()
			--Show the submenu of the entry
			dropdown:ShowSubmenu(control)
			return false --not control.closeOnSelect
		end,
		[LSM_ENTRY_TYPE_CHECKBOX] = function(control, data, ...)
			onMouseEnter(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[LSM_ENTRY_TYPE_BUTTON] = function(control, data, ...)
			onMouseEnter(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[LSM_ENTRY_TYPE_RADIOBUTTON] = function(control, data, ...)
			onMouseEnter(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
	},
	['onMouseExit'] = {
		[LSM_ENTRY_TYPE_NORMAL] = function(control, data)
			onMouseExit(control, data, no_submenu)
			return not control.closeOnSelect
		end,
		[LSM_ENTRY_TYPE_HEADER] = function(control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[LSM_ENTRY_TYPE_DIVIDER] = function(control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[LSM_ENTRY_TYPE_SUBMENU] = function(control, data)
			local dropdown = onMouseExit(control, data, has_submenu)
			--TODO: This is onMouseExit, MouseIsOver(control) should not apply.
			if not (MouseIsOver(control) or dropdown:IsEnteringSubmenu()) then
				dropdown:OnMouseExitTimeout(control)
			end
			return false --not control.closeOnSelect
		end,
		[LSM_ENTRY_TYPE_CHECKBOX] = function(control, data)
			onMouseExit(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[LSM_ENTRY_TYPE_BUTTON] = function(control, data, ...)
			onMouseExit(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[LSM_ENTRY_TYPE_RADIOBUTTON] = function(control, data, ...)
			onMouseExit(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
	},
	--The onMouseUp will be used to select an entry in the menu/submenu/nested submenu/context menu
	---> It will call the ZO_ComboBoxDropdown_Keyboard.OnEntrySelected and via that ZO_ComboBox_Base:ItemSelectedClickHelper(item, ignoreCallback)
	---> which will then call the item.callback(comboBox, itemName, item, selectionChanged, oldItem) function
	---> So the parameters for the LibScrollableMenu entry.callback functions will be the same:  (comboBox, itemName, item, selectionChanged, oldItem)
	---> The return value true/false controls if the calling function runHandler -> dropdownClass.OnEntryMouseUp(control, button, upInside, ctrl, alt, shift) -> will select the entry
	---> to the dropdown via ZO_ComboBoxDropdown_Keyboard.OnEntryMouseUp(control, button, upInside, ctrl, alt, shift)

	-- return true to "select" entry
	['onMouseUp'] = {
		[LSM_ENTRY_TYPE_NORMAL] = function(control, data, button, upInside, ctrl, alt, shift)
			onMouseUp(control, data, no_submenu)
			return true
		end,
		[LSM_ENTRY_TYPE_HEADER] = function(control, data, button, upInside, ctrl, alt, shift)
			return false
		end,
		[LSM_ENTRY_TYPE_DIVIDER] = function(control, data, button, upInside, ctrl, alt, shift)
			return false
		end,
		[LSM_ENTRY_TYPE_SUBMENU] = function(control, data, button, upInside, ctrl, alt, shift)
			onMouseUp(control, data, has_submenu)
			return control.closeOnSelect --if submenu entry has data.callback then select the entry
		end,
		[LSM_ENTRY_TYPE_CHECKBOX] = function(control, data, button, upInside, ctrl, alt, shift)
--d(debugPrefix .. 'onMouseUp [LSM_ENTRY_TYPE_CHECKBOX]')
			onMouseUp(control, data, no_submenu)
			return false
		end,
		[LSM_ENTRY_TYPE_BUTTON] = function(control, data, button, upInside, ctrl, alt, shift)
--d(debugPrefix .. 'onMouseUp [LSM_ENTRY_TYPE_BUTTON]')
			onMouseUp(control, data, no_submenu)
			return false
		end,
		[LSM_ENTRY_TYPE_RADIOBUTTON] = function(control, data, button, upInside, ctrl, alt, shift)
--d(debugPrefix .. 'onMouseUp [LSM_ENTRY_TYPE_RADIOBUTTON]')
			onMouseUp(control, data, no_submenu)
			return false
		end,
	},
}

local function runHandler(handlerTable, control, ...)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 53, tos(getControlName(control)), tos(handlerTable), tos(control.typeId)) end
	local handler = handlerTable[control.typeId]
	if handler then
		return handler(control, ...)
	end
	return false
end

--------------------------------------------------------------------
-- Dropdown entry filter functions
--------------------------------------------------------------------

--local helper variables for string filter functions
local ignoreSubmenu 			--if using / prefix submenu entries not matching the search term should still be shown
local lastEntryVisible  = true	--Was the last entry processed visible at the results list? Used to e.g. show the divider below too
local filterString				--the search string
local filterFunc				--the filter function to use. Default is "defaultFilterFunc". Custom filterFunc can be added via options.customFilterFunc

--options.customFilterFunc needs the same signature/parameters like this function
--return value needs to be a boolean: true = found/false = not found
-->Attention: prefix "/" in the filterString still jumps this function for submenus as non-matching will be always found that way!
local function defaultFilterFunc(p_item, p_filterString)
	local name = p_item.label or p_item.name
	return zostrlow(name):find(p_filterString) ~= nil
end

--Check if entry should be added to the search/filter of the string search of the collapsible header
-->Returning true: item must be considered for the search / false: item should be skipped
local function passItemToSearch(item)
	--Check if name of entry counts as "to search", or not
	if filterString ~= "" then
		local name = item.label or item.name
		--Name is missing: Do not filter
		if name == nil then return false end
		return not filterNamesExempts[name]
	end
	return false
end

--Search the item's label or name now, if the entryType of the item should be processed by text search, and if the entry
--was not marked as "not to search" (always show in search results) in it's data
local function filterResults(item)
	local entryType = item.entryType
	if not entryType or filteredEntryTypes[entryType] then
		--Should the item be skipped at the search filters?
		local doNotFilter = getValueOrCallback(item.doNotFilter, item) or false
		if doNotFilter == true then
			return true -- always included
		end
		--Check for other prerequisites
		if passItemToSearch(item) == true then
			--Not excluded, do the string comparison now
			return filterFunc(item, filterString)
		end
	else
		return lastEntryVisible
	end
end

--String filter the visible results, if options.enableFilter == true
-->if doFilter is true the text search will be executed, else textsearch is not executed -> Item should be shown directly
local function itemPassesFilter(item, doFilter)
	--Check if the data.name / data.label are provided (also check all other data.* keys if functions need to be executed)
	if verifyLabelString(item) then
		if doFilter then
			--Recursively check menu entries (submenu and nested submenu entries) for the matching search string
			return recursiveOverEntries(item, filterResults)
		else
			return true
		end
	end
end

--------------------------------------------------------------------
-- Dropdown entry functions
--------------------------------------------------------------------
local function createScrollableComboBoxEntry(self, item, index, entryType)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 54, tos(index), tos(entryType)) end
	local entryData = ZO_EntryData:New(item)
	entryData.m_index = index
	entryData.m_owner = self.owner
	entryData.m_dropdownObject = self
	entryData:SetupAsScrollListDataEntry(entryType)
	return entryData
end

local function addEntryToScrollList(self, item, dataList, index, allItemsHeight, largestEntryWidth, spacing, isLastEntry)
	local entryHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT
	local entryType = LSM_ENTRY_TYPE_NORMAL
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
		entryHeight = entryHeight + spacing
	end

	allItemsHeight = allItemsHeight + entryHeight

	local entry = createScrollableComboBoxEntry(self, item, index, entryType)
	tins(dataList, entry)

	local fontObject = self.owner:GetItemFontObject(item) --self.owner:GetDropdownFontObject()
	--Check string width of label (alternative text to show at entry) or name (internal value used)
	local nameWidth = GetStringWidthScaled(fontObject, item.label or item.name, 1, SPACE_INTERFACE) + widthPadding
	if nameWidth > largestEntryWidth then
		largestEntryWidth = nameWidth
	end
	return allItemsHeight, largestEntryWidth
end

--Reset function which is called for the scrollList entryType pool's rowControls as they get hidden/scrolled out of sight
local function poolControlReset(selfVar, control)
    control:SetHidden(true)

	if control.isSubmenu then
		if control.m_owner.m_submenu then
			control.m_owner.m_submenu:HideDropdown()
		end
	end

	local button = control.m_button
	if button then
		local buttonGroup = button.m_buttonGroup
		if buttonGroup ~= nil then
			--local buttonGroupIndex = button.m_buttonGroupIndex
			buttonGroup:Remove(button)
		end
	end
end


--------------------------------------------------------------------
-- dropdownClass
--------------------------------------------------------------------

local dropdownClass = ZO_ComboBoxDropdown_Keyboard:Subclass()

-- dropdownClass:New(To simplify locating the beginning of the class
function dropdownClass:Initialize(parent, comboBoxContainer, depth)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 55, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth)) end
	--df("[LSM]dropdownClass:Initialize - parent: %s, comboBoxContainer: %s, depth: %s", tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth))
	local dropdownControl = CreateControlFromVirtual(comboBoxContainer:GetName(), GuiRoot, "LibScrollableMenu_Dropdown_Template", depth)
	ZO_ComboBoxDropdown_Keyboard.Initialize(self, dropdownControl)
	dropdownControl.object = self
	dropdownControl.m_dropdownObject = self
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
	self.scroll = self.scrollControl.contents

	local selfVar = self

	--------------------------------------------------------------------------------------------------------------------
	-- highlightTemplate, animationFieldName = self.highlightTemplateOrFunction(control)
	-->Function highlightTemplateOrFunctions will be called from local function RefreshHighlights() in function ZO_ScrollList_EnableHighlight
	--Enable different hightlight templates at the ZO_SortFilterList scrolLList entries -> OnMouseEnter
	-->entries opening a submenu, having a callback function, show with a different template (color e.g.)
	-->>!!! ZO_ScrollList_EnableHighlight(self.scrollControl, function(control) end) cannot be used here as it does NOT overwrite existing highlightTemplateOrFunction !!!
	--[[
		local function HighlightControl(self, control)
			local highlightTemplate, animationFieldName
			if type(self.highlightTemplateOrFunction) == "function" then
				-->!!! This will be the place where the code below is called !!!
				highlightTemplate, animationFieldName = self.highlightTemplateOrFunction(control)
			else
				highlightTemplate = self.highlightTemplateOrFunction
			end
			control.highlightAnimationFieldName = animationFieldName or "HighlightAnimation"
			PlayAnimationOnControl(control, highlightTemplate, control.highlightAnimationFieldName, DONT_ANIMATE_INSTANTLY, self.overrideHighlightEndAlpha)

			self.highlightedControl = control

			if self.highlightCallback then
				self.highlightCallback(control, true)
			end
		end
	]]
	-->!!! This will be the place where the function HighlightControl above calls the highlightTemplateOrFunction function !!!
	scrollCtrl.highlightTemplateOrFunction = function(control)
		if selfVar.owner then
			--return selfVar.owner:GetHighlightTemplate(control)
			local XMLVirtualHighlightTemplateOfRow = selfVar.owner:GetHighlightTemplate(control)
			--Check if the XML virtual template name changed and invalidate the _G highlight and animation control then (set = nil)
			LSM_CheckIfAnimationControlNeedsXMLTemplateChange(control, XMLVirtualHighlightTemplateOfRow)

			-->function PlayAnimationOnControl will set control[defaultHighLightAnimationFieldName] = animationControl then
			--->Also see function scrollCtrl.highlightCallback below
			return XMLVirtualHighlightTemplateOfRow, defaultHighLightAnimationFieldName --"LSM_HighlightAnimation"
		end
		return defaultHighlightTemplate, defaultHighLightAnimationFieldName --"ZO_SelectionHighlight", "LSM_HighlightAnimation"
	end

	--------------------------------------------------------------------------------------------------------------------
	--Set the table control.rowHighlightData so we can use it to compare the last used XML virtual template for the
	--highlight control, at this control, with the current one.
	-->Will be set here and read in function scrollCtrl.highlightTemplateOrFunction above -> LSM_CheckIfAnimationControlNeedsXMLTemplateChange
	scrollCtrl.highlightCallback = function(control, isHighlighting)
		if control ~= nil and isHighlighting == true then
			if selfVar.owner then
				local animationFieldName = control.highlightAnimationFieldName
				if animationFieldName ~= nil then
					control.LSM_rowHighlightData = {
						highlightControlName =	control:GetName() .. "Scroll" .. animationFieldName,
						animationFieldName = 	animationFieldName,
						highlightXMLTemplate = 	selfVar.owner:GetHighlightTemplate(control)
					}
				end
			else
				control.LSM_rowHighlightData = nil
			end
		end
	end
	--------------------------------------------------------------------------------------------------------------------
end

function dropdownClass:AddItems(items)
	error(debugPrefix .. 'scrollHelper:AddItems is obsolete. You must use m_comboBox:AddItems')
end

function dropdownClass:AddItem(item)
	error(debugPrefix .. 'scrollHelper:AddItem is obsolete. You must use m_comboBox:AddItem')
end

--Narration
function dropdownClass:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 56, tos(eventName), tos(getControlName(ctrl)), tos(hasSubmenu), tos(anchorPoint)) end
	self.owner:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint) -->comboBox_base:Narrate(...)
end


function dropdownClass:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 57, tos(entryTemplate), tos(entryHeight), tos(setupFunction), tos(widthPadding)) end
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

	local selfVar = self
	local entryHeightWithSpacing = entryHeight + self.spacing
	ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId, entryTemplate, entryHeightWithSpacing, setupFunction, function(...) poolControlReset(selfVar, ...) end)
	ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId + 1, entryTemplate, entryHeight, setupFunction, function(...) poolControlReset(selfVar, ...) end)

	self.nextScrollTypeId = self.nextScrollTypeId + 2
end

function dropdownClass:AnchorToControl(parentControl)
	local width, height = GuiRoot:GetDimensions()
	local right = true

	local offsetX = parentControl.m_dropdownObject.scrollControl.scrollbar:IsHidden() and ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y or ZO_SCROLL_BAR_WIDTH
--	local offsetX = -4

	local offsetY = -ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y
--	local offsetY = -4

	local point, relativePoint = TOPLEFT, TOPRIGHT

	if self.m_parentMenu.m_dropdownObject and self.m_parentMenu.m_dropdownObject.anchorRight ~= nil then
		right = self.m_parentMenu.m_dropdownObject.anchorRight
	end

	if not right or parentControl:GetRight() + self.control:GetWidth() > width then
		right = false
	--	offsetX = 4
		offsetX = 0
		point, relativePoint = TOPRIGHT, TOPLEFT
	end

	local relativeTo = parentControl
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 58, tos(point), tos(getControlName(relativeTo)), tos(relativePoint), tos(offsetX), tos(offsetY)) end

	self.control:ClearAnchors()
	self.control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)

	self.anchorRight = right
end

function dropdownClass:AnchorToComboBox(comboBox)
	local parentControl = comboBox:GetContainer()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 59, tos(getControlName(parentControl))) end
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
		x = x + 2
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
		x = x - 2
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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 60, tos(point), tos(getControlName(relativeTo)), tos(relativePoint), tos(x), tos(y)) end
	if point and relativePoint then
		menuToAnchor:SetAnchor(point, relativeTo, relativePoint, x, y)
	end
end

function dropdownClass:GetSubmenu()
	if self.owner then
		self.m_submenu = self.owner.m_submenu
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 61, tos(self.m_submenu)) end

	return self.m_submenu
end

function dropdownClass:IsDropdownVisible()
	-- inherited ZO_ComboBoxDropdown_Keyboard:IsHidden
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 62, tos(not self:IsHidden())) end
	return not self:IsHidden()
end

function dropdownClass:IsEnteringSubmenu()
	local submenu = self:GetSubmenu()
	if submenu then
		if submenu:IsDropdownVisible() and submenu:IsMouseOverControl() then
			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 63) end
			return true
		end
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 64) end
	return false
end

function dropdownClass:IsItemSelected(item)
	if self.owner and self.owner.IsItemSelected then
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 65, tos(self.owner:IsItemSelected(item))) end
		return self.owner:IsItemSelected(item)
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 66) end
	return false
end

function dropdownClass:IsMouseOverOpeningControl()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 67) end
	return false
end

function dropdownClass:OnMouseEnterEntry(control)
--d(debugPrefix .. "dropdownClass:OnMouseEnterEntry - name: " .. tos(getControlName(control)))
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 68, tos(getControlName(control))) end
	-- Added here for when mouse is moved from away from dropdowns over a row, it will know to close specific children
	self:OnMouseExitTimeout(control)

	local data = getControlData(control)
	if data.enabled == true then
		if not runHandler(handlerFunctions['onMouseEnter'], control, data) then
			--Each entryType uses the default scrolltemplates.lua, function PlayAnimationOnControl via the zo_comboBoxDropdown_onMouseEnterEntry function call
			--to get/create the highlight control and assign the virtual XML tempalte to it, and to set the highlight animation on the control.
			--> See function dropdownClass:Initialize -> function scrollCtrl.highlightTemplateOrFunction and function scrollCtrl.highlightCallback
			zo_comboBoxDropdown_onMouseEnterEntry(self, control)
		end

		if data.tooltip or data.customTooltip then
--d(">calling self:ShowTooltip ")
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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 69, tos(getControlName(control))) end

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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 70, tos(getControlName(control))) end
	setTimeout(function()
		self.owner:HideOnMouseExit(moc())
	end)
end

function dropdownClass:OnEntryMouseUp(control, button, upInside, ignoreHandler, ctrl, alt, shift)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 71, tos(getControlName(control)), tos(button), tos(upInside)) end
--d(debugPrefix .. "OnEntryMouseUp - button: " ..tos(button) .. ", upInside: " .. tos(upInside) .. ", ignoreHandler: " ..tos(ignoreHandler))

	--20240816 Suppress the next global mouseup event raised from a comboBox's dropdown (e.g. if a submenu entry outside of a context menu was clicked
	--while a context menu was opened, and the context menu was closed then due to this click, but the global mouse up handler on the sbmenu entry runs
	--afterwards)
	suppressNextOnGlobalMouseUp = nil


	if upInside then
		local data = getControlData(control)
	--	local comboBox = getComboBox(control, true)
		local comboBox = control.m_owner


		if data.enabled then

			if button == MOUSE_BUTTON_INDEX_LEFT then
				if checkIfContextMenuOpenedButOtherControlWasClicked(control, comboBox, button) == true then
					suppressNextOnGlobalMouseUp = true
					return
				end
				if not ignoreHandler and runHandler(handlerFunctions['onMouseUp'], control, data, button, upInside, ctrl, alt, shift) then
					self:OnEntrySelected(control)
				else
					self:RunItemCallback(data, data.ignoreCallback)
				end

			--Show context menu at the entry?
			elseif button == MOUSE_BUTTON_INDEX_RIGHT then
				local rightClickCallback = data.contextMenuCallback or data.rightClickCallback
				if rightClickCallback and not g_contextMenu.m_dropdownObject:IsOwnedByComboBox(comboBox) then
					if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 72) end
					rightClickCallback(comboBox, control, data)
				end
			end
		end
	end
end

--[[
function ZO_ComboBoxDropdown_Keyboard.OnEntryMouseUp(control, button, upInside)
	if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
		local dropdown = control.m_dropdownObject
		if dropdown then
			dropdown:OnEntrySelected(control)
		end
	end
end
]]

function dropdownClass:SelectItemByIndex(index, ignoreCallback)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 73, tos(index), tos(ignoreCallback)) end
	if self.owner then
		playSelectedSoundCheck(self, nil)
		return self.owner:SelectItemByIndex(index, ignoreCallback)
	end
end

function dropdownClass:RunItemCallback(item, ignoreCallback)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 74, tos(item), tos(ignoreCallback)) end
	if self.owner then
		playSelectedSoundCheck(self, item.entryType)
		return self.owner:RunItemCallback(item, ignoreCallback)
	end
end

function dropdownClass:Show(comboBox, itemTable, minWidth, maxHeight, spacing)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 75, tos(getControlName(comboBox:GetContainer())), tos(minWidth), tos(maxHeight), tos(spacing)) end

	self.owner = comboBox

	local comboBoxObject = self.m_comboBox

	-- externally defined
	ignoreSubmenu, filterString, filterFunc = nil, nil, nil
	lastEntryVisible = false
	--options.enableFilter == true?
	if self:IsFilterEnabled() then
		ignoreSubmenu, filterString = comboBoxObject.filterString:match('(/?)(.*)') -- starts with / and followed by .* to include special characters
		filterFunc = comboBoxObject:GetFilterFunction()
	else
		self:ResetFilters(comboBoxObject.m_dropdown)
	end
	filterString = filterString or ''
	-- Convert ignoreSubmenu to bool
	-->If ignoreSubmenu == true: Show submenu entries even if they do not match the search term (as long as the submenu name matches the search term)
	ignoreSubmenu = ignoreSubmenu == '/'

	--Any text entered?
	local textSearchEnabled = filterString ~= ''
	--Text filter should show non-matching submenu entries? "/" prefix was used in text filter editBox
	if textSearchEnabled and comboBox.isSubmenu then
		if ignoreSubmenu == true then
			textSearchEnabled = false
		end
	end

	local control = self.control
	local scrollControl = self.scrollControl

	ZO_ScrollList_Clear(scrollControl)

	self:SetSpacing(spacing)

	local numItems = #itemTable
	local largestEntryWidth = 0
	local dataList = ZO_ScrollList_GetDataList(scrollControl)

	--Take control.header's height into account here as base height too
	local allItemsHeight = comboBox:GetBaseHeight(control)
	for i = 1, numItems do
		local item = itemTable[i]
		local isLastEntry = i == numItems
		if itemPassesFilter(item, textSearchEnabled) then
			allItemsHeight, largestEntryWidth = addEntryToScrollList(self, item, dataList, i, allItemsHeight, largestEntryWidth, spacing, isLastEntry)
			lastEntryVisible = true
		else
			lastEntryVisible = false
			if isLastEntry and ZO_IsTableEmpty(dataList) then
				-- If no item passes filter: Show "No items found with search term" entry
				allItemsHeight, largestEntryWidth = addEntryToScrollList(self, noEntriesResults, dataList, i, allItemsHeight, largestEntryWidth, spacing, isLastEntry)
			end
		end
	end

	-- using the exact width of the text can leave us with pixel rounding issues
	-- so just add 5 to make sure we don't truncate at certain screen sizes
	largestEntryWidth = largestEntryWidth + 5

	--maxHeight should have been defined before via self:UpdateHeight() -> Settings control:SetHeight() so self.m_height was set
	local desiredHeight = maxHeight
	ApplyTemplateToControl(scrollControl.contents, getScrollContentsTemplate(allItemsHeight < desiredHeight))
	-- Add padding one more time to account for potential pixel rounding issues that could cause the scroll bar to appear unnecessarily.
	allItemsHeight = allItemsHeight + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2) + 1

	if allItemsHeight < desiredHeight then
		desiredHeight = allItemsHeight
	end
--	ZO_Scroll_SetUseScrollbar(self, false)

	-- Allow the dropdown to automatically widen to fit the widest entry, but
	-- prevent it from getting any skinnier than the container's initial width
	local totalDropDownWidth = largestEntryWidth + (ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2) + ZO_SCROLL_BAR_WIDTH
	if totalDropDownWidth > minWidth then
		control:SetWidth(totalDropDownWidth)
	else
		control:SetWidth(minWidth)
	end

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 76, tos(totalDropDownWidth), tos(allItemsHeight), tos(desiredHeight)) end

	ZO_Scroll_SetUseFadeGradient(scrollControl, not self.owner.disableFadeGradient )
	control:SetHeight(desiredHeight)

	ZO_ScrollList_SetHeight(scrollControl, desiredHeight)
	ZO_ScrollList_Commit(scrollControl)
end

function dropdownClass:UpdateHeight()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 77) end
	if self.owner then
		self.owner:UpdateHeight(self.control)
	end
end

--Returns the handler naem for OnSho or OnHide for the normal dropdown, submenu and contextMenu
--> OnMenuShow / OnMenuHide
--> OnSubmenuShow / OnSubmenuHide
--> OnContextmenuShow / OnContextmenuHide
function dropdownClass:GetFormattedNarrateEvent(suffix)
	local formattedNarrateEvent = ''
	if self.owner then
		formattedNarrateEvent = sfor('On%s%s', self.owner:GetMenuPrefix(), suffix)
	end
	return formattedNarrateEvent
end

--Will be executed from XML handlers -> formattedEventName will be build via method GetFormattedNarrateEvent
function dropdownClass:OnShow(formattedEventName)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 78) end
--	self.control:BringWindowToTop()

	if formattedEventName ~= nil then
		local anchorRight = self.anchorRight and 'Right' or 'Left'
		local ctrl = self.control
		lib:FireCallbacks(formattedEventName, ctrl, self)

		throttledCall(function()
			self:Narrate(formattedEventName, ctrl, nil, nil, anchorRight)
		end, 100, "_DropdownClassOnShow")
	end
end

--Will be executed from XML handlers -> formattedEventName will be build via method GetFormattedNarrateEvent
function dropdownClass:OnHide(formattedEventName)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 79) end
	if formattedEventName ~= nil then
		local ctrl = self.control
		lib:FireCallbacks(formattedEventName, ctrl, self)
		self:Narrate(formattedEventName, ctrl)
	end
end

--Called from XML "LibScrollableMenu_Dropdown_Behavior"
function dropdownClass:XMLHandler(selfVar, handlerName)
	if selfVar == nil or handlerName == nil then return end

	if handlerName == "OnEffectivelyHidden" then
		self:HideDropdown()
	elseif handlerName == "OnMouseEnter" then
		self:OnMouseExitTimeout(selfVar)

	elseif handlerName == "OnShow" then
		self:OnShow(self:GetFormattedNarrateEvent('Show'))
	elseif handlerName == "OnHide" then
		self:OnHide(self:GetFormattedNarrateEvent('Hide'))
	end
end

function dropdownClass:ShowSubmenu(control)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 80, tos(getControlName(control))) end
	if self.owner then
		-- Must clear now. Otherwise, moving onto a submenu will close it from exiting previous row.
		clearTimeout()
		self.owner:ShowSubmenu(control)
	end
end

function dropdownClass:ShowTooltip(control, data)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 81, tos(getControlName(control)), tos(data.hasSubmenu)) end
	showTooltip(self, control, data, data.hasSubmenu)
end

function dropdownClass:HideDropdown()
--d("dropdownClass:HideDropdown()")
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 82) end
	if self.owner then
		self.owner:HideDropdown()
	end
end

function dropdownClass:HideSubmenu()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 83) end
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end
end

--------------------------------------------------------------------
-- Dropdown text search functions
--------------------------------------------------------------------

local function setTextSearchEditBoxText(selfVar, filterBox, newText)
	selfVar.wasTextSearchContextMenuEntryClicked = true
	filterBox:SetText(newText) --will call dropdownClass:SetFilterString() then
end

local function clearTextSearchHistory(self, comboBoxContainerName)
	self.wasTextSearchContextMenuEntryClicked = true
	if comboBoxContainerName == nil or comboBoxContainerName == "" then return end
	if ZO_IsTableEmpty(sv.textSearchHistory[comboBoxContainerName]) then return end
	sv.textSearchHistory[comboBoxContainerName] = nil
end

local function addTextSearchEditBoxTextToHistory(comboBox, filterBox, historyText)
	historyText = historyText or filterBox:GetText()
	if comboBox == nil or historyText == nil or historyText == "" then return end
	local comboBoxContainerName = comboBox:GetUniqueName()
	if comboBoxContainerName == nil or comboBoxContainerName == "" then return end

	sv.textSearchHistory[comboBoxContainerName] = sv.textSearchHistory[comboBoxContainerName] or {}
	local textSearchHistory = sv.textSearchHistory[comboBoxContainerName]
	--Entry already in the history, abort now
	if ZO_IsElementInNumericallyIndexedTable(textSearchHistory, historyText) then return end
	tins(textSearchHistory, 1, historyText)

	--Remove any entry > 10 (remove last ones first)
	local numEntries = #textSearchHistory
	if numEntries > 10 then
		--Remove last entry in the list
		trem(textSearchHistory, numEntries)
	end
end

function dropdownClass:WasTextSearchContextMenuEntryClicked(mocCtrl)
--d("dropdownClass:WasTextSearchContextMenuEntryClicked - wasTextSearchContextMenuEntryClicked: " ..tos(self.wasTextSearchContextMenuEntryClicked))
	--Internal variable was set as we selected a ZO_Menu entry?
	if self.wasTextSearchContextMenuEntryClicked then
		self.wasTextSearchContextMenuEntryClicked = nil
--d(">wasTextSearchContextMenuEntryClicked was TRUE")
		return true
	end
	--Clicked control is known and the owner is ZO_Menus -> then assume we did open the ZO_Menu above an LSM and need the LSM to stay open
	if mocCtrl ~= nil and mocCtrl:GetOwningWindow() == ZO_Menus then
--d(">ZO_Menus entry clicked!")
		return true
	end
	return false
end

local throttledCallDropdownClassSetFilterStringSuffix =  "_DropdownClass_SetFilterString"
function dropdownClass:SetFilterString(filterBox)
 --d("dropdownClass:SetFilterString")
	if self.m_comboBox then
		-- It probably does not need this but, added it to prevent lagging from fast typing.
		throttledCall(function()
			local text = filterBox:GetText()
--d(">throttledCall 1 - text: " ..tos(text))
			self.m_comboBox:SetFilterString(filterBox, text)

			--Delay the addition of a new text search history entry to take place after 1 second so we do not add
			--parts of currently typed characters
			throttledCall(function()
--d(">throttledCall 2 - Text search history")
				addTextSearchEditBoxTextToHistory(self.m_comboBox, filterBox, text)
			end, 990, throttledCallDropdownClassSetFilterStringSuffix)
		end, 10, throttledCallDropdownClassSetFilterStringSuffix)
	end
end

function dropdownClass:ShowFilterEditBoxHistory(filterBox)
	local selfVar = self
	local comboBox = self.m_comboBox
	if comboBox ~= nil then
		local comboBoxContainerName = comboBox:GetUniqueName()
--d(debugPrefix .. "dropdownClass:ShowFilterEditBoxHistory - comboBoxContainerName: " .. tos(comboBoxContainerName))
		if comboBoxContainerName == nil or comboBoxContainerName == "" then return end
		--Get the last saved text search (history) and show them as context menu
		local textSearchHistory = sv.textSearchHistory[comboBoxContainerName]
		if not ZO_IsTableEmpty(textSearchHistory) then
			self.wasTextSearchContextMenuEntryClicked = nil
			ClearMenu()
			for idx, textSearched in ipairs(textSearchHistory) do
				if textSearched ~= "" then
					AddMenuItem(tos(idx) .. ". " .. textSearched, function()
						setTextSearchEditBoxText(selfVar, filterBox, textSearched)
					end)
				end
			end
			if LibCustomMenu then
				AddCustomMenuItem("-") --if LCM is enabled. Add divider, for better readability
			end
			AddMenuItem("- " .. GetString(SI_STATS_CLEAR_ALL_ATTRIBUTES_BUTTON) .." - ", function()
				clearTextSearchHistory(selfVar, comboBoxContainerName)
			end)

			--Prevent LSM Hook at ShowMenu() to close the LSM below the cursor!!!
			lib.preventLSMClosingZO_Menu = true
			ShowMenu(filterBox)
			ZO_Tooltips_HideTextTooltip()
		end
	end
end


--Called from XML at e.g. the collapsible header's editbox, and other controls
--Used for event handlers like OnMouseUp and OnChanged etc.
function lib.OnXMLControlEventHandler(owningWindowFunctionName, refVar, ...)
	--d(debugPrefix .. "lib.OnXMLControlEventHandler - owningWindowFunctionName: " .. tos(owningWindowFunctionName))

	if refVar == nil or owningWindowFunctionName == nil then return end

	local owningWindow = refVar:GetOwningWindow()
	local owningWindowObject = (owningWindow ~= nil and owningWindow.object) or nil
	if owningWindowObject ~= nil then
		local owningFunctionNameType = type(owningWindowFunctionName)
		if owningFunctionNameType == "string" and type(owningWindowObject[owningWindowFunctionName]) == "function"  then
			owningWindowObject[owningWindowFunctionName](owningWindowObject, ...)
		elseif owningFunctionNameType == "function" then
			owningWindowFunctionName(owningWindowObject, ...)
		end
	end
end

function dropdownClass:OnFilterEditBoxMouseUp(filterBox, button, upInside, ctrl, alt, shift)
	--Only react on right click
	ZO_Tooltips_HideTextTooltip()
	if not upInside or button ~= MOUSE_BUTTON_INDEX_RIGHT then return end

	self:ShowFilterEditBoxHistory(filterBox)
end

function dropdownClass:ResetFilters(owningWindow)
--d(debugPrefix .. "dropdownClass:ResetFilters")
	--If not showing the filters at a contextmenu
	-->Close any opened contextmenu
	if self.m_comboBox ~= nil and self.m_comboBox.openingControl == nil then
--d(">>calling ClearCustomScrollableMenu")
		ClearCustomScrollableMenu()
	end

	ZO_Tooltips_HideTextTooltip()
	if not owningWindow or not owningWindow.filterBox then return end
	owningWindow.filterBox:SetText('') --calls dropdownClass:SetFilterString(filterBox)
end

function dropdownClass:IsFilterEnabled()
--d(debugPrefix .. "dropdownClass:IsFilterEnabled")
	if self.m_comboBox then
		return self.m_comboBox:IsFilterEnabled()
	end
end


--[[ Used via XML button to I (include) submenu entries. Currently disabled, only available via text search prefix "/"
function dropdownClass:SetFilterIgnore(ignore)
	self.m_comboBox.ignoreEmpty = ignore
	self.m_comboBox:UpdateResults()
end
]]

function dropdownClass:ShowTextTooltip(control, side, tooltipText, owningWindow)
	ZO_Tooltips_HideTextTooltip()
	--Do not show tooltip if the context menu at the search editbox is shown
	if not ZO_Menu:IsHidden() or tooltipText == nil or tooltipText == "" then return end
	--Do not show tooltip if cursor is in the search editbox (typing)
	if owningWindow == nil and control.GetOwningWindow ~= nil then owningWindow = control:GetOwningWindow() end
	if owningWindow ~= nil then
		local searchFilterTextBox = owningWindow.filterBox
		if searchFilterTextBox ~= nil and control == searchFilterTextBox and control:HasFocus() then return end
	end
	ZO_Tooltips_ShowTextTooltip(control, side, tooltipText)
	InformationTooltipTopLevel:BringWindowToTop()
end


--------------------------------------------------------------------
-- buttonGroupClass
--  (radio) buttons in a group will change their checked state to false if another button in the group was clicked
--------------------------------------------------------------------

local function getButtonGroupOfEntryType(comboBox, groupIndex, entryType)
	local buttonGroupObject = comboBox.m_buttonGroup
	local buttonGroupOfEntryType = (buttonGroupObject ~= nil and buttonGroupObject[entryType] ~= nil and buttonGroupObject[entryType][groupIndex]) or nil
	return buttonGroupOfEntryType
end


local buttonGroupClass = ZO_RadioButtonGroup:Subclass()

function buttonGroupClass:Add(button, entryType)
	if button then
		--local buttonGroupIndex = button.m_buttonGroupIndex
--d("Add - groupIndex: " ..tos(buttonGroupIndex) .. ", button: " .. tos(button:GetName()))
		if self.m_buttons[button] == nil then
			local selfVar = self
--d(">>adding new button to group now...")

			-- Remember the original handler so that its call can be forced.
			local originalHandler = button:GetHandler("OnClicked")
			self.m_buttons[button] = { originalHandler = originalHandler, isValidOption = true, entryType = entryType } -- newly added buttons always start as valid options for now.

			--d( debugPrefix..'isRadioButton ' .. tos(isRadioButton))
			if entryType == LSM_ENTRY_TYPE_RADIOBUTTON then
				-- This throws away return values from the original function, which is most likely ok in the case of a click handler.
				local newHandler = function(control, buttonId, ignoreCallback)
--d( debugPrefix.. 'buttonGroup -> OnClicked handler. Calling HandleClick')
					--2024-08-15 Add checkIfContextMenuWasOpened here at direct radioButton click as OnClick handler does not work here!
					if checkIfContextMenuOpenedButOtherControlWasClicked(control, control:GetParent().m_owner, buttonId) == true then return end
					selfVar:HandleClick(control, buttonId, ignoreCallback)
				end

				--d( debugPrefix..'originalHandler' .. tos(originalHandler))
				button:SetHandler("OnClicked", newHandler)

				if button.label then
					button.label:SetColor(self.labelColorEnabled:UnpackRGB())
				end
			end
			return true
		end
	end
end

function buttonGroupClass:Remove(button)
	local buttonData = self.m_buttons[button]
	if buttonData then
--d("Removed  - button: " .. tos(button:GetName()))
		--self:SetButtonState(button, nil, buttonData.isValidOption)
		button:SetHandler("OnClicked", buttonData.originalHandler)
		if self.m_clickedButton == button then
			self.m_clickedButton = nil
		end
		self.m_buttons[button] = nil
	end
end

function buttonGroupClass:SetButtonState(button, clickedButton, enabled, ignoreCallback)
--d("SetButtonState  - button: " .. tos(button:GetName()) .. ", clickedButton: " .. tos(clickedButton ~= nil and clickedButton) .. ", enabled: " .. tos(enabled) .. "; ignoreCallback: " ..tos(ignoreCallback))
	if(enabled) then
		local checked = true
		if(button == clickedButton) then
			button:SetState(BSTATE_PRESSED, true)
		else
			button:SetState(BSTATE_NORMAL, false)
			checked = false
		end

		if button.label then
			button.label:SetColor(self.labelColorEnabled:UnpackRGB())
		end
		-- move here and always update
--d(">checked: " .. tos(checked))

		if (button.toggleFunction ~= nil) and not ignoreCallback then -- and checked then
			button:toggleFunction(checked)
		end
	else
        if(button == clickedButton) then
            button:SetState(BSTATE_DISABLED_PRESSED, true)
        else
            button:SetState(BSTATE_DISABLED, true)
        end
        if button.label then
            button.label:SetColor(self.labelColorDisabled:UnpackRGB())
        end
    end
end

function buttonGroupClass:HandleClick(control, buttonId, ignoreCallback)
--d("HandleClick - button: " .. getControlName(control))
	if not self.m_enabled or self.m_clickedButton == control then
		return
	end

	-- Can't click disabled buttons
	local controlData = self.m_buttons[control]
	if controlData and not controlData.isValidOption then
		return
	end

	if self.customClickHandler and self.customClickHandler(control, buttonId, ignoreCallback) then
		return
	end

	-- For now only the LMB will be allowed to click radio buttons.
	if buttonId == MOUSE_BUTTON_INDEX_LEFT then
		-- Set all buttons in the group to unpressed, and unlocked.
		-- If the button is disabled externally (maybe it isn't a valid option at this time)
		-- then set it to unpressed, but disabled.
--d(">>> for k, v in pairs(self.buttons) -> SetButtonState")
		for k, v in pairs(self.m_buttons) do
		--	self:SetButtonState(k, nil, v.isValidOption)
			self:SetButtonState(k, control, v.isValidOption, ignoreCallback)
		end

		-- Set the clicked button to pressed and lock it down (so that it stays pressed.)
--		control:SetState(BSTATE_PRESSED, true)
		local previousControl = self.m_clickedButton
		self.m_clickedButton = control

		if self.onSelectionChangedCallback and not ignoreCallback then
			self:onSelectionChangedCallback(control, previousControl)
			hideTooltip(control)
		end
	end

	if controlData.originalHandler then
		controlData.originalHandler(control, buttonId)
	end
end

function buttonGroupClass:SetChecked(control, checked, ignoreCallback)
--d("SetChecked - control: " .. getControlName(control) .. ", checked: " ..tos(checked) .. ", ignoreCallback: " .. tos(ignoreCallback))
	local previousControl = self.m_clickedButton
	-- This must be made nil as running this virtually resets the button group.
	-- Not dong so will break readial buttons, if used on them.
	-- Lets say one inverts radio buttons. The previously set one will remain so, tho it's no inverted, it will not be able to be selected again until another is selected first.
	-- if not self.m_enabled or self.m_clickedButton == control then
	self.m_clickedButton = nil

	local buttonId = MOUSE_BUTTON_INDEX_LEFT
	local updatedButtons = {}

	local valueChanged = false
	for button, controlData in pairs(self.m_buttons) do
--d(">button: " ..getControlName(button) .. ", enabled: " ..tos(button.enabled))
		if button.enabled then
			if ZO_CheckButton_IsChecked(button) ~= checked then
				valueChanged = true
				-- button.checked Used to pass checked to handler
				button.checked = checked
				table.insert(updatedButtons, button)
				if controlData.originalHandler then
--d(">>calling originalHandler")
					local skipHiddenForReasonsCheck = true
					controlData.originalHandler(button, buttonId, ignoreCallback, skipHiddenForReasonsCheck) --As a normal OnClicked handler is called here: prevent doing nothing-> So we need to skip the HiddenForReasons check at the checkboxes!
				end
			end
		end
	end

	if not ignoreCallback and not ZO_IsTableEmpty(updatedButtons) and self.onStateChangedCallback then
		self:onStateChangedCallback(control, updatedButtons)
	end

	return valueChanged
end

function buttonGroupClass:SetInverse(control, ignoreCallback)
	return self:SetChecked(control, nil, ignoreCallback)
end

function buttonGroupClass:SetStateChangedCallback(callback)
    self.onStateChangedCallback = callback
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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 84, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth)) end
	self.m_sortedItems = {}
	self.m_unsortedItems = {}
	self.m_container = comboBoxContainer
	local dropdownObject = self:GetDropdownObject(comboBoxContainer, depth)
	self:SetDropdownObject(dropdownObject)

	self:UpdateOptions(options, true)
	self:SetupDropdownHeader()
	self:UpdateHeight()
end

-- Common functions
-- Adds the customEntryTemplate to all items added
function comboBox_base:AddItem(itemEntry, updateOptions, templates)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 85, tos(updateOptions), tos(self.baseEntryHeight), tos(templates)) end
	addItem_Base(self, itemEntry)
	zo_comboBox_base_addItem(self, itemEntry, updateOptions)
	tins(self.m_unsortedItems, itemEntry)
end

-- Adds widthPadding as a valid parameter
function comboBox_base:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 86, tos(entryTemplate), tos(entryHeight), tos(setupFunction), tos(widthPadding)) end
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

function comboBox_base:GetItemFontObject(item)
	local font = item.font or self:GetDropdownFont() --self.m_font
	return _G[font]
end

-- >> template, height, setupFunction
local function getTemplateData(entryType, template)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 87, tos(entryType), tos(template)) end
	local templateDataForEntryType = template[entryType]
	return templateDataForEntryType.template, templateDataForEntryType.rowHeight, templateDataForEntryType.setupFunc, templateDataForEntryType.widthPadding
end

local function getDefaultXMLTemplates(selfVar)
	--The virtual XML templates, with their setup functions for the row controls, for the different row types
	local defaultXMLTemplates  = {
		[LSM_ENTRY_TYPE_NORMAL] = {
			template = 'LibScrollableMenu_ComboBoxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryLabel(control, data, list, LSM_ENTRY_TYPE_NORMAL)
			end,
		},
		[LSM_ENTRY_TYPE_SUBMENU] = {
			template = 'LibScrollableMenu_ComboBoxSubmenuEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthPadding = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntrySubmenu(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_DIVIDER] = {
			template = 'LibScrollableMenu_ComboBoxDividerEntry',
			rowHeight = DIVIDER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryDivider(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_HEADER] = {
			template = 'LibScrollableMenu_ComboBoxHeaderEntry',
			rowHeight = HEADER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryHeader(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_CHECKBOX] = {
			template = 'LibScrollableMenu_ComboBoxCheckboxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthPadding = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryCheckbox(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_BUTTON] = {
			template = 'LibScrollableMenu_ComboBoxButtonEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthPadding = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryButton(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_RADIOBUTTON] = {
			template = 'LibScrollableMenu_ComboBoxRadioButtonEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthPadding = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryRadioButton(control, data, list)
			end,
		},
	}

	--The virtual XML highlight templates (mouse moved above an antry), for the different row types
	local defaultXMLHighlightTemplates = {
		[LSM_ENTRY_TYPE_NORMAL] = {
			template = defaultHighlightTemplate,
			templateContextMenuOpeningControl = defaultHighlightTemplate, --template for an entry providing a contextMenu
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_SUBMENU] = {
			template = defaultHighlightTemplate,
			templateSubMenuWithCallback = LSM_ROW_HIGHLIGHT_GREEN, -- template for the entry where a submenu is opened but you can click the entry to call a callback too
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_DIVIDER] = {
			template = defaultHighlightTemplate,
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_HEADER] = {
			template = defaultHighlightTemplate,
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_CHECKBOX] = {
			template = defaultHighlightTemplate,
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_BUTTON] = {
			template = defaultHighlightTemplate,
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_RADIOBUTTON] = {
			template = defaultHighlightTemplate,
			color = defaultHighlightColor,
		},
	}
	return defaultXMLTemplates, defaultXMLHighlightTemplates
end

--Called from comboBoxClass:UpdateOptions
function comboBox_base:AddCustomEntryTemplates(options, isContextMenu)
	--[[
	if isContextMenu then
		d(debugPrefix .. "comboBox_base:AddCustomEntryTemplates - options: " ..tos(options) .. ", contextMenu: " ..tos(isContextMenu))
	end
	]]
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 88, tos(options)) end

	local defaultXMLTemplates, defaultXMLHighlightTemplates = getDefaultXMLTemplates(self)

	--Were any options and options.XMLRowTemplates passed in?
	local optionTemplates = options and getValueOrCallback(options.XMLRowTemplates, options)
	--Copy the default XML templates to a new table (protect original one against changes!)
	local XMLrowTemplatesToUse = ZO_ShallowTableCopy(defaultXMLTemplates)

	--Check if all XML row templates are passed in, and update missing ones with default values
	if optionTemplates ~= nil then
--d(debugPrefix .. "options.XMLRowTemplates found!")
		for entryType, _ in pairs(defaultXMLTemplates) do
			if optionTemplates[entryType] ~= nil then
				--ZOs function overwrites exising table entries!
				zo_mixin(XMLrowTemplatesToUse[entryType], optionTemplates[entryType])
			end
		end
	end
	self.XMLRowTemplates = XMLrowTemplatesToUse


	--Custom highlight XML templates from options:
	--Was "one" highlight template (or color) provided, then use this for all row's entryTypes
	local customHighlightTemplateForAllEntryTypes = options and getValueOrCallback(options.highlightTemplate, options)
	local customHighlightColorForAllEntryTypes = options and getValueOrCallback(options.highlightColor, options)

	--Were any options and options.XMLRowHighlightTemplates passed in?
	local optionHighlightTemplates = options and getValueOrCallback(options.XMLRowHighlightTemplates, options)

	--Copy the default XML templates to a new table (protect original one against changes!)
	local XMLrowHighlightTemplatesToUse = ZO_ShallowTableCopy(defaultXMLHighlightTemplates)
	--Check if all XML row highlight templates are passed in, and update missing ones with default values
	--or set the template/color that should be used for all of the entryTypes
	if optionHighlightTemplates or customHighlightTemplateForAllEntryTypes or customHighlightColorForAllEntryTypes then
		--[[
		if isContextMenu then
			d(debugPrefix .. "customHighlightTemplateForAll: " .. tos(customHighlightTemplateForAllEntryTypes) ..", customHighlightColorForAll: ".. tos(customHighlightColorForAllEntryTypes) ..", optionHighlightTemplates: " .. tos(options.XMLRowHighlightTemplates))
		end
		]]
		for entryType, _ in pairs(defaultXMLHighlightTemplates) do
			--Any highlight templates passed in via options
			if optionHighlightTemplates and optionHighlightTemplates[entryType] then
	--[[
	if isContextMenu then
		d(">entryType: " .. tos(entryType) ..", customHighlightXML: " .. tos(optionHighlightTemplates[entryType].template) .. "; templateSubMenuWithCallback: " .. tos(optionHighlightTemplates[entryType].templateSubMenuWithCallback) .. "; templateContextMenuOpeningControl: " .. tos(optionHighlightTemplates[entryType].templateContextMenuOpeningControl))
	end
	]]
				--ZOs function overwrites exising table entries!
				zo_mixin(XMLrowHighlightTemplatesToUse[entryType], optionHighlightTemplates[entryType])
			end

			--Use one highlightTemplate for all normal highlights
			if customHighlightTemplateForAllEntryTypes ~= nil then
				XMLrowHighlightTemplatesToUse[entryType].template = customHighlightTemplateForAllEntryTypes
			end
			--use one highlight color for all normal highlights?
			if customHighlightColorForAllEntryTypes ~= nil then
				XMLrowHighlightTemplatesToUse[entryType].color = customHighlightColorForAllEntryTypes
			end
		end
	end
	--Will be used in comboBox_base:GetHighLightTemplate to get the template data for the rowType
	self.XMLRowHighlightTemplates = XMLrowHighlightTemplatesToUse


	--Set the row templates to use to the current object
	--[[ for debugging
		lib._debugXMLrowTemplates = lib._debugXMLrowTemplates or {}
		lib._debugXMLrowTemplates[self] = self
		if isContextMenu then
			LSM_DebugAddCustomEntryTemplates = {
				options = ZO_ShallowTableCopy(options),
				XMLRowHighlightTemplates = ZO_ShallowTableCopy(self.XMLRowHighlightTemplates)
			}
		end
	]]

	-- These register the templates and creates a dataType for each.
	for entryTypeId, entryTypeIsUsed in ipairs(libraryAllowedEntryTypes) do
		if entryTypeIsUsed == true then
			self:AddCustomEntryTemplate(getTemplateData(entryTypeId, XMLrowTemplatesToUse))
		end
	end

	--Update the current object's rowHeight (normal entry type)
	local normalEntryHeight = XMLrowTemplatesToUse[LSM_ENTRY_TYPE_NORMAL].rowHeight
	-- We will use this, per-comboBox, to set max rows.
	self.baseEntryHeight = normalEntryHeight
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 89, tos(normalEntryHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_DIVIDER].rowHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_HEADER].rowHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_CHECKBOX].rowHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_BUTTON].rowHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_RADIOBUTTON].rowHeight)) end
end

function comboBox_base:OnGlobalMouseUp(eventId, button)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 90, tos(button), tos(suppressNextOnGlobalMouseUp)) end
--d("comboBox_base:OnGlobalMouseUp-button: " ..tos(button) .. ", suppressNextMouseUp: " .. tos(suppressNextOnGlobalMouseUp))
	if suppressNextOnGlobalMouseUp then
		suppressNextOnGlobalMouseUp = nil
		return false
	end

	if self:IsDropdownVisible() then
		if not self.m_dropdownObject:IsMouseOverControl() then
--d(">>dropdownVisible -> not IsMouseOverControl")
			if self:HiddenForReasons(button) then
--d(">>>HiddenForReasons -> Hiding dropdown now")
				return self:HideDropdown()
			end
		end
	else
		if self.m_container:IsHidden() then
--d(">>>else - containerIsHidden -> Hiding dropdown now")
			self:HideDropdown()
		else
--d("<SHOW DROPDOWN OnMouseUp")
			lib.openMenu = self
			-- If shown in ShowDropdownInternal, the global mouseup will fire and immediately dismiss the combo box. We need to
			-- delay showing it until the first one fires.
			self:ShowDropdownOnMouseUp()
		end
	end
end

function comboBox_base:GetBaseHeight(control)
	-- We need to include the header height to allItemsHeight, or the scroll hight will include the header height.
	-- Filtering will result in a shorter list with scrollbars that extend byond it.
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 91, tos(getControlName(control)), tos(control.header ~= nil), tos(control.header ~= nil and control.header:GetHeight() or 0)) end
	if control.header then
		return control.header:GetHeight()--  + ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y
	end
	return 0
end

function comboBox_base:GetMaxDropdownHeight()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 92, tos(self.maxHeight)) end
	return self.maxHeight
end

function comboBox_base:GetDropdownObject(comboBoxContainer, depth)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 93, tos(getControlName(comboBoxContainer)), tos(depth)) end
	self.m_nextFree = depth + 1
	return dropdownClass:New(self, comboBoxContainer, depth)
end

-- Create the m_dropdownObject on initialize.
function comboBox_base:GetOptions()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 94) end
	return self.options or {}
end

-- Get or create submenu

function comboBox_base:GetSubmenu()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 95) end
	if not self.m_submenu then
		self.m_submenu = submenuClass:New(self, self.m_container, self:GetOptions(), self.m_nextFree)
	end
	return self.m_submenu
end

function comboBox_base:HiddenForReasons(button)
	local owningWindow, mocCtrl, comboBox, mocEntry = getMouseOver_HiddenFor_Info()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 96, tos(button)) end
--d("comboBox_base:HiddenForReasons - button: " .. tos(button))

	--[[
	LSM_debug = LSM_debug or {}
	LSM_debug.HiddenForReasons = LSM_debug.HiddenForReasons or {}
	local tabEntryName = getControlName(mocCtrl) or "n/a"
	LSM_debug.HiddenForReasons[tabEntryName] = {
		self = self,
		owningWindow = owningWindow,
		mocCtrl = mocCtrl,
		mocEntry = mocEntry,
		comboBox = comboBox,
		m_dropdownObject = self.m_dropdownObject,
		selfOwner = self.owner,
		dropdownObjectOwner = self.m_dropdownObject.owner,
	}
	]]

	local dropdownObject = self.m_dropdownObject
	local isContextMenuVisible = g_contextMenu:IsDropdownVisible()
	local isOwnedByComboBox = dropdownObject:IsOwnedByComboBox(comboBox)
	local wasTextSearchContextMenuEntryClicked = dropdownObject:WasTextSearchContextMenuEntryClicked()
	if isContextMenuVisible and not wasTextSearchContextMenuEntryClicked then
		wasTextSearchContextMenuEntryClicked = g_contextMenu.m_dropdownObject:WasTextSearchContextMenuEntryClicked()
	end
--d(">ownedByCBox: " .. tos(isOwnedByComboBox) .. ", isCtxtMenVis: " .. tos(isContextMenuVisible) ..", isCtxMen: " ..tos(self.isContextMenu) .. "; cntxTxtSearchEntryClicked: " .. tos(wasTextSearchContextMenuEntryClicked))

	if isOwnedByComboBox == true or wasTextSearchContextMenuEntryClicked == true then
--d(">>isEmpty: " ..tos(ZO_IsTableEmpty(mocEntry)) .. ", enabled: " ..tos(mocEntry.enabled) .. ", mouseEnabled: " .. tos(mocEntry.IsMouseEnabled and mocEntry:IsMouseEnabled()))
		if ZO_IsTableEmpty(mocEntry) or (mocEntry.enabled and mocEntry.enabled ~= false) or (mocEntry.IsMouseEnabled and mocEntry:IsMouseEnabled()) then
			if button == MOUSE_BUTTON_INDEX_LEFT then
				--do not close or keep open based on clicked entry but do checks in contextMenuClass:GetHiddenForReasons instead
				if isContextMenuVisible == true then
					--Is the actual mocCtrl's owner the contextMenu? Or did we click some other non-context menu entry/control?
					if owningWindow ~= g_contextMenu.m_container then
--d(">>>returing nothing because is or isOpened -> contextMenu. Going to GetHiddenForReasons")
						if wasTextSearchContextMenuEntryClicked == true then
--d(">>>returing false cuz textSearchEntry was selected")
							return false
						end
					else
--d("<<returning contextmenu via mouseLeft -> closeOnSelect: " ..tos(mocCtrl.closeOnSelect))
						return mocCtrl.closeOnSelect and not self.m_enableMultiSelect
					end
				else
--d("<<returning via mouseLeft -> closeOnSelect: " ..tos(mocCtrl.closeOnSelect))
					--Clicked entry should close after selection?
					return mocCtrl.closeOnSelect and not self.m_enableMultiSelect
				end
			elseif button == MOUSE_BUTTON_INDEX_RIGHT then
				-- bypass right-clicks on the entries. Context menus will be checked and opened at the OnMouseUp handler
				-->See local function onMouseUp called via runHandler -> from dropdownClass:OnEntrySelected
				return false
			end
		end
	end

	local hiddenForReasons
	if not self.GetHiddenForReasons then
--d("<<self:GetHiddenForReasons is NIL! isContextMenuVisible: " .. tos(isContextMenuVisible))
--LSM_debug.HiddenForReasons[tabEntryName]._GetHiddenForReasonsMissing = true
		return false
	end
	hiddenForReasons = self:GetHiddenForReasons(button) --call e.g. contextMenuClass:GetHiddenForReasons()

	if hiddenForReasons == nil then return false end
	return hiddenForReasons(owningWindow, mocCtrl, comboBox, mocEntry)
end

--Get the highlight XML template for the entry
function comboBox_base:GetHighlightTemplate(control)
	local highlightTemplate = ((control ~= nil and control.m_data ~= nil and control.m_data.m_highlightTemplate) or self.m_highlightTemplate) or nil
	return highlightTemplate
end


--Get the current row's highlight template based on the options, and differ between normal entry type's highlights,
-- entry type opening a submenu and having it's own callback (templateSubMenuWithCallback) highlights, contextMenu opening
-- control (templateContextMenuOpeningControl) highlights
function comboBox_base:GetHighlightTemplateData(control, m_data, isSubMenu, isContextMenu)
	local entryType = control.typeId

	--Get the highlight template based on the entryType
	if entryType == nil then return	end

	local appliedHighlightTemplate = self:GetHighlightTemplate(control)
	local appliedHighlightTemplateCopy = appliedHighlightTemplate
	local highlightTemplateData = ((self.XMLRowHighlightTemplates[entryType] ~= nil and ZO_ShallowTableCopy(self.XMLRowHighlightTemplates[entryType])) or (appliedHighlightTemplateCopy)) or ZO_ShallowTableCopy(defaultHighlightTemplateData) --loose the reference so we can overwrite values below, without changing originals
	highlightTemplateData.overwriteHighlightTemplate = highlightTemplateData.overwriteHighlightTemplate or false

	local options = self:GetOptions()
	local data = getControlData(control)

	--Check if the original data passed in got a m_highlightTemplate, m_highlightColor etc. which should always be used
	-->Original data was copied to data._LSM.OriginalData.data via function updateDataValues in addItembase
	if data then
		local origData = data[LSM_DATA_SUBTABLE] and data[LSM_DATA_SUBTABLE][LSM_DATA_SUBTABLE_ORIGINAL_DATA] and data[LSM_DATA_SUBTABLE][LSM_DATA_SUBTABLE_ORIGINAL_DATA].data
		if origData then
			if origData.m_highlightTemplate or origData.m_highlightColor then
				local origHighlightTemplateData = {}
				origHighlightTemplateData.template = 	origData.m_highlightTemplate
				origHighlightTemplateData.color = 		origData.m_highlightColor or defaultHighlightColor

				origHighlightTemplateData.overwriteHighlightTemplate = true

				return origHighlightTemplateData
			end
		end
	end

	if isSubMenu and control.closeOnSelect then
		if options and not options.useDefaultHighlightForSubmenuWithCallback then
			--Color the highlight light row green if the submenu has a callback (entry opening a submenu can be clicked to select it)
			--but keep the color of the text as defined in options (self.XMLRowHighlightTemplates[entryType].color)
			--Was a custom template provided in "templateSubMenuWithCallback" for that case, then use it. Else use default template (green)
			highlightTemplateData.template = ((highlightTemplateData.templateSubMenuWithCallback ~= nil and highlightTemplateData.templateSubMenuWithCallback) or (appliedHighlightTemplateCopy)) or ZO_ShallowTableCopy(defaultHighlightTemplateDataEntryHavingSubMenuWithCallback).template
		end
	else
		local isContextMenuAndHighlightContextMenuOpeningControl = (options ~= nil and options.highlightContextMenuOpeningControl == true) or self.highlightContextMenuOpeningControl == true
		if isContextMenuAndHighlightContextMenuOpeningControl then
			local comboBox = control.m_owner
			local gotRightCLickCallback = ((data ~= nil and comboBox ~= nil and (data.contextMenuCallback ~= nil or data.rightClickCallback ~= nil)) and true) or false
			local isOwnedByContextMenuComboBox = g_contextMenu.m_dropdownObject:IsOwnedByComboBox(comboBox)

			if gotRightCLickCallback and not isOwnedByContextMenuComboBox then

				--highlightContextMenuOpeningControl support -> highlightTemplateData.templateContextMenuOpeningControl
				highlightTemplateData.template = ((highlightTemplateData.templateContextMenuOpeningControl ~= nil and highlightTemplateData.templateContextMenuOpeningControl) or (appliedHighlightTemplateCopy)) or ZO_ShallowTableCopy(defaultHighlightTemplateDataEntryContextMenuOpeningControl).template
				highlightTemplateData.overwriteHighlightTemplate = true
			end
		end
	end
	return highlightTemplateData
end

--Write the highlight template to the control.m_data.m_highlightTemplate (ZO_ComboBox default variable for that), based
--on the XMLRowHighlightTemplates passed in via the options (or using default values)
function comboBox_base:UpdateHighlightTemplate(control, data, isSubMenu, isContextMenu)

	isContextMenu = isContextMenu or self.isContextMenu
	local highlightTemplateData = self:GetHighlightTemplateData(control, data, isSubMenu, isContextMenu)
	local highlightTemplate = (highlightTemplateData ~= nil and highlightTemplateData.template) or nil

	if control.m_data then
		if highlightTemplateData == nil then
			control.m_data.m_highlightTemplate = nil --defaultHighlightTemplateData.template ???
			control.m_data.m_highlightColor = nil    --defaultHighlightTemplateData.color ???
		elseif highlightTemplateData.overwriteHighlightTemplate == true or not control.m_data.m_highlightTemplate then
			control.m_data.m_highlightTemplate = highlightTemplate
			control.m_data.m_highlightColor = highlightTemplateData.color
		end
	end
end

-- Changed to hide tooltip and, if available, it's submenu
-- We hide the tooltip here so it is hidden if the dropdown is hidden OnGlobalMouseUp
function comboBox_base:HideDropdown()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 97) end
	-- Recursive through all open submenus and close them starting from last.

	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		-- Close all open descendants.
		self.m_submenu:HideDropdown()
	end

--	lib.openMenu = nil

	if self.highlightedControl then
		unhighlightControl(self, false, nil, nil)
	end

	-- Close self
	zo_comboBox_base_hideDropdown(self)
	return true
end

-- These are part of the m_dropdownObject but, since we now use them from the comboBox,
-- they are added here to reference the ones in the m_dropdownObject.
function comboBox_base:IsMouseOverControl()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 98, tos(self.m_dropdownObject:IsMouseOverControl())) end
	return self.m_dropdownObject:IsMouseOverControl()
end

--Narrate (screen UI reader): Read out text based on the narration event fired
function comboBox_base:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 99, tos(eventName), tos(getControlName(ctrl)), tos(hasSubmenu), tos(anchorPoint)) end
	local narrateData = self.narrateData
	if eventName == nil or isAccessibilityUIReaderEnabled() == false or narrateData == nil then return end
	local narrateCallbackFuncForEvent = narrateData[eventName]
	if narrateCallbackFuncForEvent == nil or type(narrateCallbackFuncForEvent) ~= "function" then return end
	local selfVar = self

	--The function parameters signature for the different narration callbacks
	local eventCallbackFunctionsSignatures = {
		["OnMenuShow"]			= function() return selfVar, ctrl end,
		["OnMenuHide"]			= function() return selfVar, ctrl end,
		["OnSubMenuShow"]		= function() return selfVar, ctrl, anchorPoint end,
		["OnSubMenuHide"]		= function() return selfVar, ctrl end,
		["OnEntrySelected"]		= function() return selfVar, ctrl, data, hasSubmenu end,
		["OnEntryMouseExit"]	= function() return selfVar, ctrl, data, hasSubmenu end,
		["OnEntryMouseEnter"]	= function() return selfVar, ctrl, data, hasSubmenu end,
		["OnCheckboxUpdated"]	= function() return selfVar, ctrl, data end,
		["OnRadioButtonUpdated"]= function() return selfVar, ctrl, data end,
		["OnComboBoxMouseExit"] = function() return selfVar, ctrl end,
		["OnComboBoxMouseEnter"]= function() return selfVar, ctrl end,
	}
	--Create a table with the callback functions parameters
	if eventCallbackFunctionsSignatures[eventName] == nil then return end
	local callbackParams = { eventCallbackFunctionsSignatures[eventName]() }
	--Pass in the callback params to the narrateFunction
	local narrateText, stopCurrent = narrateCallbackFuncForEvent(unpack(callbackParams))

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 100, tos(narrateText), tos(stopCurrent)) end
	--Didn't the addon take care of the narration itsself? So this library here should narrate the text returned
	if type(narrateText) == "string" then
		local narrateFuncOfLibrary = narrationEventToLibraryNarrateFunction[eventName]
		if narrateFuncOfLibrary == nil then return end
		narrateFuncOfLibrary(narrateText, stopCurrent)
	end
end

--Should exit on PTS already
if comboBox_base.IsEnabled == nil then
	function comboBox_base:IsEnabled()
		return self.m_openDropdown:GetState() ~= BSTATE_DISABLED
	end
end

function comboBox_base:RefreshSortedItems(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 101, tos(getControlName(parentControl))) end
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)

	local entries = self:GetEntries()
	-- Ignore nil entries
	if entries ~= nil then
		-- replace empty entries with noEntriesSubmenu item
		if ZO_IsTableEmpty(entries) then
			noEntriesSubmenu.m_owner = self
			noEntriesSubmenu.m_parentControl = parentControl
			self:AddItem(noEntriesSubmenu, ZO_COMBOBOX_SUPPRESS_UPDATE)
		else
			for _, item in ipairs(entries) do
				item.m_owner = self
				item.m_parentControl = parentControl
				-- update strings by functions will be done in AddItem
				self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
			end
			
			self:UpdateItems()
		end
	end
end

function comboBox_base:RunItemCallback(item, ignoreCallback, ...)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 102) end

	if item.callback and not ignoreCallback then
		return item.callback(self, item.name, item, ...)
	end
	return false
end

function comboBox_base:SetOptions(options)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 103) end
	self.options = options
end

function comboBox_base:SetupEntryBase(control, data, list)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 104, tos(getControlName(control))) end
	self.m_dropdownObject:SetupEntryBase(control, data, list)

	control.callback = data.callback
	control.contextMenuCallback = data.contextMenuCallback
	control.closeOnSelect = (control.selectable and type(data.callback) == 'function') or false

    control:SetMouseEnabled(data.enabled ~= false)
end

function comboBox_base:Show()
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
	self.m_dropdownObject.control:BringWindowToTop()
end

-- used for onMouseEnter[submenu] and onMouseUp[contextMenu]
function comboBox_base:ShowDropdownOnMouseAction(parentControl)
	--d( debugPrefix .. 'comboBox_base:ShowDropdownOnMouseAction')
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 105, tos(getControlName(parentControl))) end
	if self:IsDropdownVisible() then
		-- If submenu was currently opened, close it so it can reset.
		self:HideDropdown()
	end

	if self:IsEnabled() then
		self.m_dropdownObject:SetHidden(false)
		self:AddMenuItems(parentControl)

		self:ShowDropdown()
		self:SetVisible(true)
	else
		--If we get here, that means the dropdown was disabled after the request to show it was made, so just cancel showing entirely
		self.m_container:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)
	end
end

function comboBox_base:ShowSubmenu(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 106, tos(getControlName(parentControl))) end
	-- We don't want a submenu to open under the context menu or it's submenus.
	--TODO: see if this acts negatively in contextmenu submenus
	hideContextMenu()

	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

function comboBox_base:ShouldHideDropdown()
	if self.m_submenu and self.m_submenu:ShouldHideDropdown() then
		self.m_submenu:HideDropdown()
	end
	return self:IsDropdownVisible() and not self:IsMouseOverControl()
end

function comboBox_base:UpdateItems()
	zo_comboBox_base_updateItems(self)

	--[[
	20240615 Should not be needed anymore as this is already done at runPostItemSetupFunction[LSM_ENTRY_TYPE_SUBMENU] in add_itemBase
	for _, itemEntry in pairs(self.m_sortedItems) do
		if itemEntry.hasSubmenu then
			recursiveOverEntries(itemEntry, preUpdateSubItems)
		end
	end
	]]
end

function comboBox_base:UpdateHeight(control)
--d(debugPrefix .. "comboBox_base:UpdateHeight - control: " .. getControlName(control))
	local maxHeightInTotal = 0

	local spacing = self.m_spacing or 0
	--Maximum height explicitly set by options?
	local maxDropdownHeight = self:GetMaxDropdownHeight()

	--The height of each row
	local baseEntryHeight = self.baseEntryHeight
	local maxRows
	local maxHeightByEntries

	--Is the dropdown using a header control? then calculate it's size too
	local headerHeight = 0
	if control ~= nil then
		headerHeight = self:GetBaseHeight(control)
	end

	--Calculate the maximum height now:
	---If set as explicit maximum value: Use that
	if maxDropdownHeight ~= nil then
		maxHeightInTotal = maxDropdownHeight
	else
		--Calculate maximum visible height based on visibleRowsDrodpdown or visibleRowsSubmenu
		maxRows = self:GetMaxRows()
		-- Add spacing to each row then subtract spacing for last row
		maxHeightByEntries = ((baseEntryHeight + spacing) * maxRows) - spacing + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2)

--d(">[LSM]maxRows: " ..tos(maxRows) .. ", maxHeightByEntries: " ..tos(maxHeightByEntries))
		--Add the header's height first, then add the rows' calculated needed total height
		maxHeightInTotal = maxHeightByEntries
	end


	--The minimum dropdown height is either the height of 1 base row + the y padding (4x because 2 at anchors of ZO_ScrollList and 1x at top of list and 1x at bottom),
	--> and if a header exists + header height
	local minHeight = (baseEntryHeight * 1) + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 4) + headerHeight

	--Add a possible header's height to the total maximum height
	maxHeightInTotal = maxHeightInTotal + headerHeight

	--Check if the determined dropdown height is > than the screen's height: An min to that screen height then
	local screensMaxDropdownHeight = getScreensMaxDropdownHeight()
	--maxHeightInTotal = (maxHeightInTotal > screensMaxDropdownHeight and screensMaxDropdownHeight) or maxHeightInTotal
	--If the height of the total height is below minHeight then increase it to be at least that high
	maxHeightInTotal = zo_clamp(maxHeightInTotal, minHeight, screensMaxDropdownHeight)
--d(">[LSM]headerHeight: " ..tos(headerHeight) .. ", maxHeightInTotal: " ..tos(maxHeightInTotal))


	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 107, tos(getControlName(control)), tos(maxHeightInTotal), tos(maxDropdownHeight), tos(maxHeightByEntries),  tos(baseEntryHeight), tos(maxRows), tos(spacing), tos(headerHeight)) end

	--This will set self.m_height for later usage in self:Show() -> as the dropdown is shown
	self:SetHeight(maxHeightInTotal)
	
	if self:IsDropdownVisible() then
	--	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
		self:Show()
	end
end

do -- Row setup functions
	local function applyEntryFont(control, font, color, horizontalAlignment)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 108, tos(getControlName(control)), tos(font), tos(color), tos(horizontalAlignment)) end
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
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 109, tos(getControlName(control)), tos(list)) end
		control.m_iconContainer = control.m_iconContainer or control:GetNamedChild("IconContainer")
		local iconContainer = control.m_iconContainer
		control.m_icon = control.m_icon or iconContainer:GetNamedChild("Icon")
		updateIcons(control, data)
	end

	local function addArrow(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 110, tos(getControlName(control)), tos(list)) end
		control.m_arrow = control:GetNamedChild("Arrow")
		data.hasSubmenu = true
	end

	local function addDivider(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 111, tos(getControlName(control)), tos(list)) end
		control.m_divider = control:GetNamedChild("Divider")
	end

	local function addLabel(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 112, tos(getControlName(control)), tos(list)) end
		control.m_label = control.m_label or control:GetNamedChild("Label")

		control.m_label:SetText(data.label or data.name) -- Use alternative passed in label string, or the default mandatory name string
	end

	local function addButton(comboBox, control, data, toggleFunction)
		local entryType = control.typeId
		if entryType == nil then return end
		local childName = entryTypeToButtonChildName[entryType]
		if childName == nil then return end

		local buttonControl = control.m_button or control:GetNamedChild(childName)
		control.m_button = buttonControl
		buttonControl.entryType = entryType

		local isEnabled = data.enabled ~= false
		buttonControl:SetMouseEnabled(isEnabled)
		buttonControl.enabled = isEnabled

		ZO_CheckButton_SetToggleFunction(buttonControl, toggleFunction)
		--	ZO_CheckButton_SetEnableState(buttonControl, data.enabled ~= false)

		local buttonGroup
		local groupIndex = getValueOrCallback(data.buttonGroup, data)

		if type(groupIndex) == "number" then
			-- Prepare buttonGroup
			comboBox.m_buttonGroup = comboBox.m_buttonGroup or {}
			comboBox.m_buttonGroup[entryType] = comboBox.m_buttonGroup[entryType] or {}
			comboBox.m_buttonGroup[entryType][groupIndex] = comboBox.m_buttonGroup[entryType][groupIndex] or buttonGroupClass:New()
			buttonGroup = comboBox.m_buttonGroup[entryType][groupIndex]

			--d(debugPrefix .. "setupFunc RB - addButton, groupIndex: " ..tos(groupIndex))

			if type(data.buttonGroupOnSelectionChangedCallback) == "function" then
				buttonGroup:SetSelectionChangedCallback(data.buttonGroupOnSelectionChangedCallback)
			end

			if type(data.buttonGroupOnStateChangedCallback) == "function" then
				buttonGroup:SetStateChangedCallback(data.buttonGroupOnStateChangedCallback)
			end

			-- Add buttonControl to buttonGroup
			buttonControl.m_buttonGroup = buttonGroup
			buttonControl.m_buttonGroupIndex = groupIndex
			buttonGroup:Add(buttonControl, entryType)

			local IGNORECALLBACK = true
			buttonGroup:SetButtonState(buttonControl, data.clicked, isEnabled, IGNORECALLBACK)
			--	buttonGroup:SetButtonIsValidOption(buttonControl, isEnabled)

			if entryType == LSM_ENTRY_TYPE_CHECKBOX and data.rightClickCallback == nil and data.contextMenuCallback == nil then
				data.rightClickCallback = buttonGroupDefaultContextMenu
			end
		end
		return buttonControl, buttonGroup
	end

	function comboBox_base:SetupEntryDivider(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 113, tos(getControlName(control)), tos(list)) end
		control.typeId = LSM_ENTRY_TYPE_DIVIDER
		addDivider(control, data, list)
		self:SetupEntryBase(control, data, list)
		control.isDivider = true
	end

	function comboBox_base:SetupEntryLabelBase(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 114, tos(getControlName(control)), tos(list)) end
		local font = getValueOrCallback(data.font, data)
		font = font or self:GetDropdownFont()

		local color = getValueOrCallback(data.color, data)
		color = color or self:GetItemNormalColor(data)

		local horizontalAlignment = getValueOrCallback(data.horizontalAlignment, data)
		horizontalAlignment = horizontalAlignment or self.horizontalAlignment

		applyEntryFont(control, font, color, horizontalAlignment)
		self:SetupEntryBase(control, data, list)
	end

	function comboBox_base:SetupEntryLabel(control, data, list, realEntryType)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 115, tos(getControlName(control)), tos(list)) end
		control.typeId = LSM_ENTRY_TYPE_NORMAL
		addIcon(control, data, list)
		addLabel(control, data, list)
		self:SetupEntryLabelBase(control, data, list)

		if realEntryType == LSM_ENTRY_TYPE_NORMAL then
			self:UpdateHighlightTemplate(control, data, nil, nil)
		end
	end

	function comboBox_base:SetupEntrySubmenu(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 116, tos(getControlName(control)), tos(list)) end
		self:SetupEntryLabel(control, data, list)
		addArrow(control, data, list)
		control.typeId = LSM_ENTRY_TYPE_SUBMENU

--d(debugPrefix .. "submenu setup: - name: " .. tos(getValueOrCallback(data.label or data.name, data)) ..", closeOnSelect: " ..tos(control.closeOnSelect) .. "; m_highlightTemplate: " ..tos(data.m_highlightTemplate) )

		self:UpdateHighlightTemplate(control, data, true, nil)
	end
	
	function comboBox_base:SetupEntryHeader(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 117, tos(getControlName(control)), tos(list)) end
		addDivider(control, data, list)
		self:SetupEntryLabel(control, data, list)
		control.isHeader = true
		control.typeId = LSM_ENTRY_TYPE_HEADER
	end


	function comboBox_base:SetupEntryRadioButton(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 118, tos(getControlName(control)), tos(list)) end

		local selfVar = self
		local function toggleFunction(button, checked)
--d(debugPrefix .. "RB toggleFunc - button: " ..tos(getControlName(button)) .. ", checked: " .. tos(checked))
			local rowData = getControlData(button:GetParent())
			rowData.checked = checked

			if checked then
				if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 119, tos(getControlName(control)), tos(checked), tos(list)) end
				selfVar:RunItemCallback(data, data.ignoreCallback, checked)

				lib:FireCallbacks('RadioButtonUpdated', control, data, checked)
				selfVar:Narrate("OnRadioButtonUpdated", button, data, nil)
				if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 120, tos(getControlName(button)), tos(checked)) end
			end
		end
		self:SetupEntryLabel(control, data, list)
		control.isRadioButton = true
		control.typeId = LSM_ENTRY_TYPE_RADIOBUTTON

		self:UpdateHighlightTemplate(control, data, nil, nil)

		local radioButton, radioButtonGroup = addButton(self, control, data, toggleFunction)
		if radioButtonGroup then
			if data.checked == true then
				-- Only 1 can be set as "checked" here.
				local IGNORECALLBACK = true
				radioButtonGroup:SetClickedButton(radioButton, IGNORECALLBACK)
			end
		end
	end

	function comboBox_base:SetupEntryCheckbox(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 121, tos(getControlName(control)), tos(list)) end

		local selfVar = self
		local function toggleFunction(checkbox, checked)
			local checkedData = getControlData(checkbox:GetParent())

			checkedData.checked = checked

			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 122, tos(getControlName(control)), tos(checked), tos(list)) end
			--Changing the params similar to the normal entry's itemSelectionHelper signature: function(comboBox, itemName, item, checked, data)
			selfVar:RunItemCallback(data, data.ignoreCallback, checked)

			lib:FireCallbacks('CheckboxUpdated', control, data, checked)
			selfVar:Narrate("OnCheckboxUpdated", checkbox, data, nil)
			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 123, tos(getControlName(checkbox)), tos(checked)) end

			hideTooltip(control)
		end

		self:SetupEntryLabel(control, data, list)
		control.isCheckbox = true
		control.typeId = LSM_ENTRY_TYPE_CHECKBOX

		self:UpdateHighlightTemplate(control, data, nil, nil)

		local checkbox = addButton(self, control, data, toggleFunction)
		ZO_CheckButton_SetCheckState(checkbox, getValueOrCallback(data.checked, data))
	end

	function comboBox_base:SetupEntryButton(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 124, tos(getControlName(control)), tos(list)) end

		-- The row it's self is treated as a button, no child button
		control.isButton = true
		control.typeId = LSM_ENTRY_TYPE_BUTTON
		addIcon(control, data, list)
		addLabel(control, data, list)

		local font = getValueOrCallback(data.font, data)
		font = font or self:GetDropdownFont()

		local color = getValueOrCallback(data.color, data)
		color = color or self:GetItemNormalColor(data)

		local horizontalAlignment = getValueOrCallback(data.horizontalAlignment, data)
		horizontalAlignment = horizontalAlignment or TEXT_ALIGN_CENTER

		applyEntryFont(control, font, color, horizontalAlignment)
		self:SetupEntryBase(control, data, list)

		control:SetEnabled(data.enabled)

		if data.buttonTemplate then
			ApplyTemplateToControl(control, data.buttonTemplate)
		end

		self:UpdateHighlightTemplate(control, data, nil, nil)
	end
end

--[[
	if comboBox.m_buttonGroup then
		comboBox.m_buttonGroup:Clear()
	end

function comboBox_base:HighlightLabel(labelControl, data)
	if labelControl.SetColor then
		local color = self:GetItemHighlightColor(data)
		labelControl:SetColor(color:UnpackRGBA())
	end
end

function ZO_ComboBox:UnhighlightLabel(labelControl, data)
	if labelControl.SetColor then
		local color = self:GetItemNormalColor(data)
		labelControl:SetColor(color:UnpackRGBA())
	end
end
]]

-- Blank
function comboBox_base:GetMaxRows()
	-- Overwrite at subclasses
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 125) end
end

function comboBox_base:IsFilterEnabled()
	-- Overwrite at subclasses
end

function comboBox_base:GetFilterFunction()
	local options = self:GetOptions()
	local filterFunction = (options and options.customFilterFunc) or defaultFilterFunc
	return filterFunction
end

function comboBox_base:UpdateOptions(options, onInit)
	-- Overwrite at subclasses
end

function comboBox_base:SetFilterString()
	-- Overwrite at subclasses
end

function comboBox_base:SetupDropdownHeader()
	-- Overwrite at subclasses
end

function comboBox_base:UpdateDropdownHeader()
	-- Overwrite at subclasses
end

--------------------------------------------------------------------
-- comboBoxClass
--------------------------------------------------------------------

local comboBoxClass = comboBox_base:Subclass()

-- comboBoxClass:New(To simplify locating the beginning of the class
function comboBoxClass:Initialize(parent, comboBoxContainer, options, depth, initExistingComboBox)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 126, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth)) end
	comboBoxContainer.m_comboBox = self

	self:SetDefaults()

	--Reset to the default ZO_ComboBox variables
	self:ResetToDefaults(initExistingComboBox)

	-- Add all comboBox defaults not present.
	self.m_name = comboBoxContainer:GetName()
	self.m_openDropdown = comboBoxContainer:GetNamedChild("OpenDropdown")
	self.m_containerWidth = comboBoxContainer:GetWidth()
	self.m_selectedItemText = comboBoxContainer:GetNamedChild("SelectedItemText")
	self.m_multiSelectItemData = {}
	comboBox_base.Initialize(self, parent, comboBoxContainer, options, depth)

	--Custom added controls

	return self
end

function comboBoxClass:GetUniqueName()
	return self.m_name
end

-- Changed to force updating items and, to set anchor since anchoring was removed from :Show() due to separate anchoring based on comboBox type. (comboBox to self /submenu to row/contextMenu to mouse)
function comboBoxClass:AddMenuItems()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 127) end
	self:UpdateItems()
	self.m_dropdownObject:AnchorToComboBox(self)
	self:Show()
end

-- [New functions]
function comboBoxClass:GetMaxRows()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 128, tos(self.visibleRows or DEFAULT_VISIBLE_ROWS)) end
	return self.visibleRows or DEFAULT_VISIBLE_ROWS
end

function comboBoxClass:GetMenuPrefix()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 129) end
	return 'Menu'
end

function comboBoxClass:GetHiddenForReasons(button)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 130, tos(button)) end
--d("111111111111111 comboBoxClass:GetHiddenForReasons - button: " ..tos(button))
	local selfVar = self
	return function(owningWindow, mocCtrl, comboBox, entry) return checkIfHiddenForReasons(selfVar, button, false, owningWindow, mocCtrl, comboBox, entry) end
end


function comboBoxClass:HideDropdown()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 131) end
--d(debugPrefix .. "comboBoxClass:HideDropdown")
	-- Recursive through all open submenus and close them starting from last.
	hideContextMenu()
	return comboBox_base.HideDropdown(self)
end

function comboBoxClass:HideOnMouseEnter()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 132) end
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() and not self:IsMouseOverControl() then
		self.m_submenu:HideDropdown()
	end
end

function comboBoxClass:HideOnMouseExit(mocCtrl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 133) end
	if self.m_submenu and self.m_submenu:ShouldHideDropdown() then
--d(">submenu found, but mouse not over it! HideDropdown")
		self.m_submenu:HideDropdown()
		return true
	end
end

function comboBoxClass:IsFilterEnabled()
	local options = self:GetOptions()
	local enableFilter = (options and getValueOrCallback(options.enableFilter, options)) or false
--d(debugPrefix .. "comboBoxClass:IsFilterEnabled - enableFilter: " ..tos(enableFilter))
	if not enableFilter then
		self.filterString = ""
	else
		self.filterString = self.filterString or ""
	end

	--local retVar = #self.m_sortedItems > 1 and enableFilter or false
--d(">#sortedItems: " ..tos(#self.m_sortedItems) .. ",  isEnabled: " ..tos(retVar))
	--Only show the filter header if there is more than 1 entry
	return enableFilter
end

function comboBoxClass:SetFilterString(filterBox, newText)
	ZO_Tooltips_HideTextTooltip()
	self.filterString = (newText ~= nil and zo_strlower(newText)) or zo_strlower(filterBox:GetText())
	self:UpdateResults(true)
end

function comboBoxClass:SetDefaults()
	self.defaults = {}
	for k, v in  pairs(comboBoxDefaults) do
		if v and self[k] ~= v then
			self.defaults[k] = v
		end
	end
end

--Reset internal default values like m_font or LSM defaults like visibleRowsDropdown
-->If called from init function of API AddCustomScrollableComboBoxDropdownMenu: Keep existing ZO default (or changed by addons) entries of the ZO_ComboBox and only reset missing ones
-->If called later from e.g. UpdateOptions function where options passed in are nil or empty: Reset all to LSM default values
--->In all cases the function comboBoxClass:UpdateOptions should update the options needed!
function comboBoxClass:ResetToDefaults(initExistingComboBox)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 134) end
	local defaults = ZO_DeepTableCopy(comboBoxDefaults)
	zo_mixin(defaults, self.defaults)

	zo_mixin(self, defaults) -- overwrite existing ZO_ComboBox default values with LSM defaults

	self:SetOptions(nil)
end

--Update the comboBox's attribute/functions with a value returned from the applied custom options of the LSM, or with
--ZO_ComboBox default options (set at self:ResetToDefaults())
function comboBoxClass:SetOption(LSMOptionsKey)
	--Old code: Updating comboBox[key] with the newValue
	--Get current value
	local currentZO_ComboBoxValueKey = LSMOptionsKeyToZO_ComboBoxOptionsKey[LSMOptionsKey]
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 135, tos(LSMOptionsKey), tos(currentZO_ComboBoxValueKey)) end
	if currentZO_ComboBoxValueKey == nil then return end
	local currentValue = self[currentZO_ComboBoxValueKey]

	--Get new value via options passed in
	local options = self:GetOptions()
	local newValue = options and getValueOrCallback(options[LSMOptionsKey], options) --read new value from the options (run function there or get the value)
	if newValue == nil then
--d(">LSMOptionsKey: " .. tos(LSMOptionsKey) .. " -> Is nil in options")
		newValue = currentValue
	end
	if newValue == nil then return end

	--Filling the self.updatedOptions table with values so they can be used in the callback functions (if any is given)
	--from table LSMOptionsToZO_ComboBoxOptionsCallbacks
	-->e.g. used for sortOrder and sortType
	self.updatedOptions[LSMOptionsKey] = newValue

	--Do we need to run a callback function to set the updated value?
	local setOptionFuncOrKey = LSMOptionsToZO_ComboBoxOptionsCallbacks[LSMOptionsKey]
	if type(setOptionFuncOrKey) == "function" then
		setOptionFuncOrKey(self, newValue)
	else
		self[currentZO_ComboBoxValueKey] = newValue
	end
end

function comboBoxClass:UpdateOptions(options, onInit, isContextMenu)
	onInit = onInit or false
	local optionsChanged = self.optionsChanged

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 136, tos(options), tos(onInit), tos(optionsChanged)) end

	--[[
	if isContextMenu then
		d("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
		d(debugPrefix .. "comboBoxClass:UpdateOptions - options: " ..tos(options) .. ", onInit: " .. tos(onInit))
	end
	]]

	--Called from Initialization of the object -> self:ResetToDefaults() was called in comboBoxClass:Initialize() already
	-->And self:UpdateOptions() is then called via comboBox_base.Initialize(...), from where we get here
	if onInit == true then
		--Do not change any other options, just init. the combobox -> call self:AddCustomEntryTemplates(options) and set
		--optionsChanged to false (self.options will be nil at that time)
		optionsChanged = false
	else
		--self.optionsChanged might have been set by contextMenuClass:SetOptions(options) already. Check that first and keep that boolean state as we
		--do not use self.options for the context menus, but self.contextMenuOptions here:
		--->Coming from contextMenuClass:ShowContextMenu() -> self.contextMenuOptions was set via contextMenuClass:SetOptions(options) before, and will be passed in here
		--->to UpdateOptions(options) as options parameter. self.optionsChanged will be true if the options changed at the contex menu (compared to old self.contextMenuOptions)
		---->self.contextMenuOptions is then used at OnShow of the context menu.
		--
		--For other "non-context menu" calls: Compare the already stored self.options table to the new passed in options table (both could be nil though)
		optionsChanged = optionsChanged or options ~= self.options
	end

	--[[
	if isContextMenu then
		d("> optionsChanged: " .. tos(optionsChanged))
	end
	]]
	--(Did the options change: Yes / OR are we initializing a ZO_ComboBox ) / AND Are the new passed in options nil or empty: Yes
	--> Reset to default ZO_ComboBox variables and just call AddCustomEntryTemplates()
	if (optionsChanged == true or onInit == true) and ZO_IsTableEmpty(options) then
		optionsChanged = false
	--[[
		if isContextMenu then
			d(">>resetting options to defaults!")
		end
	]]
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
		self:SetOptions(options)

		--Clear the table with options which got updated. Will be filled in self:SetOption(key) method
		-->Filling the self.updatedOptions table with values so they can be used in the callback functions (if any is given)
		-->from table LSMOptionsToZO_ComboBoxOptionsCallbacks, e.g. sortOrder and sortType can check if either was updated already
		-->via the loop and self:SetOption() calls below
		self.updatedOptions = {}

		-- Defaults are predefined in defaultComboBoxOptions, but they will be taken from ZO_ComboBox defaults set from table comboBoxDefaults
		-- at function self:ResetToDefaults().
		-- If any variable was set to the ZO_ComboBox already (e.g. self.m_font) it will be used again from that internal variable, if nothing
		-- was overwriting it here from passed in options table

		-- LibScrollableMenu custom options
		if not ZO_IsTableEmpty(options) then
			for key, _ in pairs(options) do
	--[[
if isContextMenu then
	d(">>setting option key: " ..tos(key))
end
]]				self:SetOption(key)
			end
		end

		--Reset the table with options which got updated (only needed here for the callback functions called from self:SetOption
		---> See table LSMOptionsToZO_ComboBoxOptionsCallbacks
		self.updatedOptions = nil

	--[[
		if isContextMenu then
			d("> SetOption and for ... do SetOptions looped ")
		end
	]]
	end

	-- this will add custom and default templates to self.XMLRowTemplates the same way dataTypes were created before.
	self:AddCustomEntryTemplates(options, isContextMenu)
end

function comboBoxClass:UpdateResults(comingFromFilters)
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end
	self:Show()
end

function comboBoxClass:ShowDropdown()
	-- Let the caller know that this is about to be shown...
	if self.m_preshowDropdownFn then
		self.m_preshowDropdownFn(self)
	end

	if not self:IsDropdownVisible() then
		-- Update header only if hidden.
		self:UpdateDropdownHeader()
	end
	self:ShowDropdownInternal()
end

-- We need to integrate a supplied ZO_ComboBox with the lib's functionality.
-- We do this by replacing the metatable with comboBoxClass.
function comboBoxClass:UpdateMetatable(parent, comboBoxContainer, options)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 137, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(options)) end

--d("comboBoxClass:UpdateMetatable")

	setmetatable(self, comboBoxClass)
	ApplyTemplateToControl(comboBoxContainer, 'LibScrollableMenu_ComboBox_Behavior')

	--Fire the OnDropdownMenuAdded callback where one can replace options in the options table
	lib:FireCallbacks('OnDropdownMenuAdded', self, options)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 138, tos(getControlName(self.m_container)), tos(options)) end

	self:Initialize(parent, comboBoxContainer, options, 1, true)
end

function comboBoxClass:SetupDropdownHeader()
	local dropdownControl = self.m_dropdownObject.control
	ApplyTemplateToControl(dropdownControl, 'LibScrollableMenu_Dropdown_Template_WithHeader')

	local options = self:GetOptions()
	if options.headerCollapsible then
		local headerCollapsed = (options and options.headerCollapsed)

		if headerCollapsed == nil then
			headerCollapsed = getSavedVariable("collapsedHeaderState", getHeaderToggleStateControlSavedVariableName(self))
		end
		if headerCollapsed ~= nil then
			if dropdownControl.toggleButton then
				ZO_CheckButton_SetCheckState(dropdownControl.toggleButton, headerCollapsed)
			end
		end
	end
end

--Toggle function called as the collapsible header is clicked
function comboBoxClass:UpdateDropdownHeader(toggleButtonCtrl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 139, tos(self.options), tos(toggleButtonCtrl)) end
	local headerControl, dropdownControl = getHeaderControl(self)
	if headerControl == nil then return end

	local headerCollapsed = false

	local options = self:GetOptions()
	if options.headerCollapsible then
		toggleButtonCtrl = toggleButtonCtrl or dropdownControl.toggleButton
		if toggleButtonCtrl then
			headerCollapsed = ZO_CheckButton_IsChecked(toggleButtonCtrl)

			if options.headerCollapsed == nil then
				-- No need in saving state if we are going to force state by options.headerCollapsed
				updateSavedVariable("collapsedHeaderState", headerCollapsed, getHeaderToggleStateControlSavedVariableName(self))
			end
		end
	end

	--d(debugPrefix.."comboBoxClass:UpdateDropdownHeader - headerCollapsed: " ..tos(headerCollapsed))
	refreshDropdownHeader(self, headerControl, self.options, headerCollapsed)
	self:UpdateHeight(dropdownControl) --> Update self.m_height properly for self:Show call (including the now updated header's height)
end


--------------------------------------------------------------------
-- submenuClass
--------------------------------------------------------------------

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
					return function(p_self, ...)
						return value(p_self.m_comboBox, ...)
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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 140, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth)) end
	self.m_comboBox = comboBoxContainer.m_comboBox
	self.isSubmenu = true
	self.m_parentMenu = parent

	comboBox_base.Initialize(self, parent, comboBoxContainer, options, depth)
	self.breadcrumbName = 'SubmenuBreadcrumb'
end

function submenuClass:UpdateOptions(options, onInit)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 141, tos(options), tos(onInit)) end
	self:AddCustomEntryTemplates(self:GetOptions())
end

function submenuClass:AddMenuItems(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 142, tos(getControlName(parentControl))) end
	self.openingControl = parentControl
	self:RefreshSortedItems(parentControl)
	self:UpdateHeight()
	self:Show()
	self.m_dropdownObject:AnchorToControl(parentControl)
end

function submenuClass:GetEntries()
	local data = getControlData(self.openingControl)

	local entries = getValueOrCallback(data.entries, data)
	return entries
end

function submenuClass:GetMaxRows()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 143, tos(self.visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS)) end
	return self.visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS
end

function submenuClass:GetMenuPrefix()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 144) end
	return 'SubMenu'
end

function submenuClass:ShowDropdownInternal()
	if self.openingControl then
		SubOrContextMenu_highlightControl(self, self.openingControl) --submenu
	end
end

function submenuClass:HideDropdownInternal()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 145) end

	if self.m_dropdownObject:IsOwnedByComboBox(self) then
		self.m_dropdownObject:SetHidden(true)
	end
	self:SetVisible(false)
	if self.onHideDropdownCallback then
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 146) end
		self.onHideDropdownCallback()
	end

	if self.highlightedControl then
		unhighlightHighlightedControl(self)
	end
end

function submenuClass:HideDropdown()
	return comboBox_base.HideDropdown(self)
end

function submenuClass:HideOnMouseExit(mocCtrl)
	-- Only begin hiding if we stopped over a dropdown.
	mocCtrl = mocCtrl or moc()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 147, tos(getControlName(mocCtrl))) end
	if mocCtrl.m_dropdownObject then
		if comboBoxClass.HideOnMouseExit(self) then
			-- Close all open submenus beyond this point
			-- This will only close the dropdown if the mouse is not over the dropdown or over the control that opened it.
			if self:ShouldHideDropdown() then
				return self:HideDropdown()
			end
		end
	end
end

function submenuClass:ShouldHideDropdown()
	return self:IsDropdownVisible() and (not self:IsMouseOverControl() and not self:IsMouseOverOpeningControl())
end

function submenuClass:IsMouseOverOpeningControl()
--d(debugPrefix .. "submenuClass:IsMouseOverOpeningControl: " .. tos(MouseIsOver(self.openingControl)))
	return MouseIsOver(self.openingControl)
end

function submenuClass:GetHiddenForReasons(button)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 148, tos(button)) end
--d("222222222222222 submenuClass:GetHiddenForReasons - button: " ..tos(button))
	local selfVar = self
	return function(owningWindow, mocCtrl, comboBox, entry) return checkIfHiddenForReasons(selfVar, button, false, owningWindow, mocCtrl, comboBox, entry, true) end
end


--------------------------------------------------------------------
-- contextMenuClass
--------------------------------------------------------------------

local contextMenuClass = comboBoxClass:Subclass()
-- LibScrollableMenu.contextMenu
-- contextMenuClass:New(To simplify locating the beginning of the class
function contextMenuClass:Initialize(comboBoxContainer)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 149, tos(getControlName(comboBoxContainer))) end
	self:SetDefaults()
	comboBoxClass.Initialize(self, nil, comboBoxContainer, nil, 1)
	self.data = {}

	self:ClearItems()

	self.breadcrumbName = 'ContextmenuBreadcrumb'
	self.isContextMenu = true
end

function contextMenuClass:GetUniqueName()
	if self.openingControl then
		return getControlName(self.openingControl)
	else
		return self.m_name
	end
end

-- Renamed from AddItem since AddItem can be the same as base. This function is only to pre-set data for updating on show,
function contextMenuClass:AddContextMenuItem(itemEntry)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 150, tos(itemEntry)) end
	local indexAdded = tins(self.data, itemEntry)
	indexAdded = indexAdded or #self.data
	return indexAdded
--	m_unsortedItems
end

function contextMenuClass:AddMenuItems(parentControl, comingFromFilters)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 151) end
	self:RefreshSortedItems()
	self:Show()
	self.m_dropdownObject:AnchorToMouse()
end

function contextMenuClass:ClearItems()
--d(debugPrefix .. 'contextMenuClass:ClearItems()')
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 152) end
	self:SetContextMenuOptions(nil)
	self:ResetToDefaults()

--	ZO_ComboBox_HideDropdown(self:GetContainer())
	ZO_ComboBox_HideDropdown(self)
	ZO_ClearNumericallyIndexedTable(self.data)

	self:SetSelectedItemText("")
	self.m_selectedItemData = nil
	self:OnClearItems()
end

function contextMenuClass:GetEntries()
	return self.data
end

function contextMenuClass:GetMenuPrefix()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 153) end
	return 'ContextMenu'
end

function contextMenuClass:GetHiddenForReasons(button)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 154, tos(button)) end
--d("3333333333333333 contextMenuClass:GetHiddenForReasons - button: " ..tos(button))
	local selfVar = self
	return function(owningWindow, mocCtrl, comboBox, entry) return checkIfHiddenForReasons(selfVar, button, true, owningWindow, mocCtrl, comboBox, entry) end
end

function contextMenuClass:HideDropdown()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 155) end
	-- Recursive through all open submenus and close them starting from last.

	return comboBox_base.HideDropdown(self)
end

function contextMenuClass:ShowSubmenu(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 156, tos(getControlName(parentControl))) end
	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

function contextMenuClass:HighlightOpeningControl()
	local openingControl = self.openingControl
	if openingControl then
		local highlightContextMenuOpeningControl = (self.options ~= nil and self.options.highlightContextMenuOpeningControl) or false
--d(debugPrefix .. "ctxMen-highlightCntxtMenOpeningControl-name: " .. tos(getControlName(openingControl)) ..", highlightIt: " .. tos(highlightContextMenuOpeningControl))
		--Options tell us to highlight the openingControl?
		if highlightContextMenuOpeningControl == true then
			--Apply the highlightOpeningControl XML template to the openingControl and highlight it than via the animation
			SubOrContextMenu_highlightControl(self, openingControl) --context menu
		end
	end
end

function contextMenuClass:ShowContextMenu(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 157, tos(getControlName(parentControl))) end
--[[
	d("///////////////////////////////")
	d(debugPrefix .. "->->->->-> contextMenuClass:ShowContextMenu")
]]
	--Cache last opening Control for the comparison with new openingControl and reset of filters etc. below
	local openingControlOld = self.openingControl
	self.openingControl = parentControl

	-- To prevent the context menu from overlapping a submenu it is not opened from:
	-- If the opening control is a dropdown and has a submenu visible, close the submenu.
	local comboBox = getComboBox(parentControl)
	if comboBox and comboBox.m_submenu and comboBox.m_submenu:IsDropdownVisible() then
		comboBox.m_submenu:HideDropdown()
	end

	if self:IsDropdownVisible() then
		self:HideDropdown()
	end

	self:UpdateOptions(self.contextMenuOptions, nil, true) --Updates self.options

	self:HighlightOpeningControl()

--d("->->->->->->-> [LSM]ContextMenuClass:ShowContextMenu -> ShowDropdown now!")
	self:ShowDropdown()

--d(debugPrefix .. "ContextMenuClass:ShowContextMenu - openingControl changed!")
	throttledCall(function()
		if openingControlOld ~= parentControl then
--d(debugPrefix .. "ContextMenuClass:ShowContextMenu - openingControl changed!")
			if self:IsFilterEnabled() then
	--d(">>resetting filters now")
				local dropdown = self.m_dropdown
				if dropdown and dropdown.object then
					dropdown.object:ResetFilters(dropdown)
				end
			end
		end
  	end, 10, "_ContextMenuClass_ShowContextMenu")
end

function contextMenuClass:SetContextMenuOptions(options)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 158, tos(options)) end

	-- self.contextMenuOptions is only a temporary table used to check for changes and to send to UpdateOptions
	-- so we can check here if anything changed within the passed in options paramter (compared to previous options)
	self.optionsChanged = self.contextMenuOptions ~= options

--d(debugPrefix .. "contextMenuClass:SetContextMenuOptions - optionsChanged: " .. tos(self.optionsChanged))
	--Wil be used in contextMenuClass:ShowContextMenu -> self:UpdateOptions(self.contextMenuOptions)
	self.contextMenuOptions = options
end

--Create the local context menu object for the library's context menu API functions
local function createContextMenuObject()
	local comboBoxContainer = CreateControlFromVirtual(MAJOR .. "_ContextMenu", GuiRoot, "ZO_ComboBox")
	g_contextMenu = contextMenuClass:New(comboBoxContainer)
	lib.contextMenu = g_contextMenu
end


--------------------------------------------------------------------
-- Public API functions
--------------------------------------------------------------------

lib.persistentMenus = false -- controls if submenus are closed shortly after the mouse exists them
							-- 2024-03-10 Currently not used anywhere!!!
function lib.GetPersistentMenus()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 159, tos(lib.persistentMenus)) end
	return lib.persistentMenus
end
function lib.SetPersistentMenus(persistent)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 160, tos(persistent)) end
	lib.persistentMenus = persistent
end


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--[API - Custom scrollable ZO_ComboBox menu]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--Adds a scrollable dropdown to the comboBoxControl, replacing the original dropdown, and enabling scrollable submenus (even with nested scrollable submenus)
--	control parent 							Must be the parent control of the comboBox
--	control comboBoxContainer 				Must be any ZO_ComboBox control (e.g. created from virtual template ZO_ComboBox -> Where ZO_ComboBox_ObjectFromContainer can find the m_comboBox object)
--
--  table options:optional = {
--> === Dropdown general customization =================================================================================
--		number visibleRowsDropdown:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened dropdown
--		number visibleRowsSubmenu:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened submenus
--		number maxDropdownHeight				Number or function returning number of total dropdown's maximum height
--		boolean sortEntries:optional			Boolean or function returning boolean if items in the main-/submenu should be sorted alphabetically. !!!Attention: Default is TRUE (sorting is enabled)!!!
--		table sortType:optional					table or function returning table for the sort type, e.g. ZO_SORT_BY_NAME, ZO_SORT_BY_NAME_NUMERIC
--		boolean sortOrder:optional				Boolean or function returning boolean for the sort order ZO_SORT_ORDER_UP or ZO_SORT_ORDER_DOWN
-- 		string font:optional				 	String or function returning a string: font to use for the dropdown entries
-- 		number spacing:optional,	 			Number or function returning a Number: Spacing between the entries
--		boolean disableFadeGradient:optional	Boolean or function returning a boolean: for the fading of the top/bottom scrolled rows
--		string headerFont:optional				String or function returning a string: font to use for the header entries
--		table headerColor:optional				table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for header entries
--		table normalColor:optional				table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for all normal (enabled) entries
--		table disabledColor:optional 			table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for all disabled entries
--		boolean highlightContextMenuOpeningControl Boolean or function returning boolean if the openingControl of a context menu should be highlighted.
--												If you set this to true you either also need to set data.m_highlightTemplate at the row and provide the XML template name for the highLight, e.g. "LibScrollableMenu_Highlight_Green".
--												Or (if not at contextMenu options!!!) you can use the templateContextMenuOpeningControl at options.XMLRowHighlightTemplates[lib.scrollListRowTypes.LSM_ENTRY_TYPE_*] = { template = "ZO_SelectionHighlight" , templateContextMenuOpeningControl = "LibScrollableMenu_Highlight_Green" } to specify the XML highlight template for that entryType
-->  ===Dropdown header/title ==========================================================================================
--		string titleText:optional				String or function returning a string: Title text to show above the dropdown entries
--		string titleFont:optional				String or function returning a font string: Title text's font. Default: "ZoFontHeader3"
--		string subtitleText:optional			String or function returning a string: Sub-title text to show below the titleText and above the dropdown entries
--		string subtitleFont:optional			String or function returning a font string: Sub-Title text's font. Default: "ZoFontHeader2"
--		number titleTextAlignment:optional		Number or function returning a number: The title's vertical alignment, e.g. TEXT_ALIGN_CENTER
--		userdata customHeaderControl:optional	Userdata or function returning Userdata: A custom control thta should be shown above the dropdown entries
--		boolean headerCollapsible			 	Boolean or function returning boolean if the header control should show a collapse/expand button
-->  === Dropdown text search & filter =================================================================================
--		boolean enableFilter:optional			Boolean or function returning boolean which controls if the text search/filter editbox at the dropdown header is shown
--		function customFilterFunc				A function returning a boolean true: show item / false: hide item. Signature of function: customFilterFunc(item, filterString)
--->  === Dropdown callback functions
-- 		function preshowDropdownFn:optional 	function function(ctrl) codeHere end: to run before the dropdown shows
--->  === Dropdown's Custom XML virtual row/entry templates ============================================================
--		boolean useDefaultHighlightForSubmenuWithCallback	Boolean or function returning a boolean if always the default ZO_ComboBox highlight XML template should be used for an entry having a submenu AND a callback function. If false the highlight 'LibScrollableMenu_Highlight_Green' will be used
--		table XMLRowTemplates:optional			Table or function returning a table with key = row type of lib.scrollListRowTypes and the value = subtable having
--												"template" String = XMLVirtualTemplateName,
--												rowHeight number = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
--												setupFunc = function(control, data, list)
--													local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer) -- comboBoxContainer = The ZO_ComboBox control you created via WINDOW_MANAGER:CreateControlFromVirtual("NameHere", yourTopLevelControlToAddAsAChild, "ZO_ComboBox")
--													comboBox:SetupEntryLabel(control, data, list)
--													-->See class comboBox_base:SetupEntry* functions above for examples how the setup functions provide the data to the row control
--													-->Reuse those where possible by calling them via e.g. self:SetupEntryBase(...) and then just adding your additional controls setup routines
--												end
--												-->See local table "defaultXMLTemplates" in LibScrollableMenu
--												-->Attention: If you do not specify all template attributes, the non-specified will be mixedIn from defaultXMLTemplates[entryType_ID] again!
--		{
--			[lib.scrollListRowTypes.LSM_ENTRY_TYPE_NORMAL] =	{ template = "XMLVirtualTemplateRow_ForEntryId", ... }
--			[lib.scrollListRowTypes.LSM_ENTRY_TYPE_SUBMENU] = 	{ template = "XMLVirtualTemplateRow_ForSubmenuEntryId", ... },
--			...
--		}
--		table XMLRowHighlightTemplates:optional	Table or function returning a table with key = row type of lib.scrollListRowTypes and the value = subtable having
--												"template" String = XMLVirtualTemplateNameForHighlightOfTheRow (on mouse enter). Default is comboBoxDefaults.m_highlightTemplate,
--												"color" ZO_ColorDef = the color for the highlight. Default is Default is comboBoxDefaults.m_highlightColor (light blue),
--												-->See local table "defaultXMLHighlightTemplates" in LibScrollableMenu
--												-->Attention: If you do not specify all template attributes, the non-specified will be mixedIn from defaultXMLHighlightTemplates[entryType_ID] again!
--												-->templateSubMenuWithCallback is used for an entry that got a submenu where clicking that entry also runs teh callback
--												-->templateContextMenuOpeningControl is used for a contexMenu only, where the entry opens a contextMenu (right click)
--		{
--			[lib.scrollListRowTypes.LSM_ENTRY_TYPE_NORMAL] =	{ template = "XMLVirtualTemplateRowHighlight_ForEntryId", color = ZO_ColorDef:New("FFFFFF"), templateSubMenuWithCallback = "XMLVirtualTemplateRowHighlight_EntryOpeningASubmenuHavingACallback", templateContextMenuOpeningControl = "XMLVirtualTemplateRowHighlight_ContextMenuOpening_ForEntryId", ... }
--			[lib.scrollListRowTypes.LSM_ENTRY_TYPE_SUBMENU] = 	{ template = "XMLVirtualTemplateRowHighlight_ForSubmenuEntryId", color = ZO_ColorDef:New("FFFFFF"), ...  },
--			...
--		}
--->  === Narration: UI screen reader, with accessibility mode enabled only ============================================
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
--												"OnRadioButtonUpdated"	function(m_dropdownObject, checkboxControl, data) end
--			Example:	narrate = { ["OnComboBoxMouseEnter"] = myAddonsNarrateComboBoxOnMouseEnter, ... }
--  }
function AddCustomScrollableComboBoxDropdownMenu(parent, comboBoxContainer, options)
	assert(parent ~= nil and comboBoxContainer ~= nil, MAJOR .. " - AddCustomScrollableComboBoxDropdownMenu ERROR: Parameters parent and comboBoxContainer must be provided!")

	local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
	assert(comboBox and comboBox.IsInstanceOf and comboBox:IsInstanceOf(ZO_ComboBox), MAJOR .. ' | The comboBoxContainer you supplied must be a valid ZO_ComboBox container. "comboBoxContainer.m_comboBox:IsInstanceOf(ZO_ComboBox)"')

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 161, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(options)) end
	comboBoxClass.UpdateMetatable(comboBox, parent, comboBoxContainer, options) --Calls comboboxCLass:Initialize

	return comboBox.m_dropdownObject
end


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--[API - Custom scrollable context menu at any control]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--Params: userdata rowControl - Returns the m_sortedItems.dataSource or m_data.dataSource or data of the rowControl, or an empty table {}
GetCustomScrollableMenuRowData = getControlData


--Add a scrollable context (right click) menu at any control (not only a ZO_ComboBox), e.g. to any custom control of your
--addon or even any entry of a LibScrollableMenu combobox dropdown
--
--The context menu syntax is similar to the ZO_Menu usage:
--A new context menu should be using ClearCustomScrollableMenu() before it adds the first entries (to hide other contextmenus and clear the new one).
--After that use either AddCustomScrollableMenuEntry to add single entries, AddCustomScrollableMenuEntries to add a whole entries table/function
--returning a table, or even directly use AddCustomScrollableMenu and pass in the entrie/function to get entries.
--And after adding all entries, call ShowCustomScrollableMenu(parentControl) to show the menu at the parentControl. If no control is provided
--moc() (control below mouse cursor) will be used
-->Attention: ClearCustomScrollableMenu() will clear and hide ALL LSM contextmenus at any time! So we cannot have an LSM context menu to show at another
--LSM context menu entry (similar to ZO_Menu).


--Adds a new entry to the context menu entries with the shown text, where the callback function is called once the entry is clicked.
--If entries is provided the entry will be a submenu having those entries. The callback can be used, if entries are passed in, too (to select a special entry and not an enry of the opening submenu).
--But usually it should be nil if entries are specified, as each entry in entries got it's own callback then.
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
--
--Example - Normal entry without submenu
--AddCustomScrollableMenuEntry("Test entry 1", function() d("test entry 1 clicked") end, LibScrollableMenu.LSM_ENTRY_TYPE_NORMAL, nil, nil)
--Example - Normal entry with submenu
--AddCustomScrollableMenuEntry("Test entry 1", function() d("test entry 1 clicked") end, LibScrollableMenu.LSM_ENTRY_TYPE_NORMAL, {
--	[1] = {
--		label = "Test submenu entry 1", --optional String or function returning a string. If missing: Name will be shown and used for clicked callback value
--		name = "TestValue1" --String or function returning a string if label is givenm name will be only used for the clicked callback value
--		isHeader = false, -- optional boolean or function returning a boolean Is this entry a non clickable header control with a headline text?
--		isDivider = false, -- optional boolean or function returning a boolean Is this entry a non clickable divider control without any text?
--		isCheckbox = false, -- optional boolean or function returning a boolean Is this entry a clickable checkbox control with text?
--		isNew = false, --  optional booelan or function returning a boolean Is this entry a new entry and thus shows the "New" icon?
--		entries = { ... see above ... }, -- optional table containing nested submenu entries in this submenu -> This entry opens a new nested submenu then. Contents of entries use the same values as shown in this example here
--		contextMenuCallback = function(ctrl) ... end, -- optional function for a right click action, e.g. show a scrollable context menu at the menu entry
-- }
--}, --[[additionalData]]
--	 	{ isNew = true, normalColor = ZO_ColorDef, highlightColor = ZO_ColorDef, disabledColor = ZO_ColorDef, highlightTemplate = "ZO_SelectionHighlight",
--		   font = "ZO_FontGame", label="test label", name="test value", enabled = true, checked = true, customValue1="foo", cutomValue2="bar", ... }
--		--[[ Attention: additionalData keys which are maintained in table LSMOptionsKeyToZO_ComboBoxOptionsKey will be mapped to ZO_ComboBox's key and taken over into the entry.data[ZO_ComboBox's key]. All other "custom keys" will stay in entry.data.additionalData[key]! ]]
--)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuEntry(text, callback, entryType, entries, additionalData)
	--Special handling for dividers
	local options = g_contextMenu:GetOptions()

	--Additional data table was passed in? e.g. containing  gotAdditionalData.isNew = function or boolean
	local addDataType = additionalData ~= nil and type(additionalData) or nil
	local isAddDataTypeTable = (addDataType ~= nil and addDataType == "table" and true) or false

	--Determine the entryType based on text, passed in entryType, and/or additionalData table
	entryType = checkEntryType(text, entryType, additionalData, isAddDataTypeTable, options)
	entryType = entryType or LSM_ENTRY_TYPE_NORMAL

	local generatedText

	--Generate the entryType from passed in function, or use passed in value
	local generatedEntryType = getValueOrCallback(entryType, (isAddDataTypeTable and additionalData) or options)

	--If entry is a divider
	if generatedEntryType == LSM_ENTRY_TYPE_DIVIDER then
		text = libDivider
	end

	--Additional data was passed in as a table: Check if label and/or name were provided and get their string value for the assert check
	if isAddDataTypeTable == true then
		--Text was passed in?
		if text ~= nil then
			--text and additionalData.name are provided: text wins
			additionalData.name = text
		end
		generatedText = getValueOrCallback(additionalData.label or additionalData.name, additionalData)
	end
	generatedText = generatedText or ((text ~= nil and getValueOrCallback(text, options)) or nil)

	--Text, or label, checks
	assert(generatedText ~= nil and generatedText ~= "" and generatedEntryType ~= nil, sfor('['..MAJOR..':AddCustomScrollableMenuEntry] text/additionalData.label/additionalData.name: String or function returning a string, got %q; entryType: number LSM_ENTRY_TYPE_* or function returning the entryType expected, got %q', tos(generatedText), tos(generatedEntryType)))
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

	--The entryData for the new item
	local newEntry = {
		--The entry type
		entryType 		= entryType,
		--The shown text line of the entry
		label			= (isAddDataTypeTable and additionalData.label) or nil,
		--The value line of the entry (or shown text too, if label is missing)
		name			= (isAddDataTypeTable and additionalData.name) or text,

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
		--Add whole table to the newEntry, which will be processed at function addItem_Base() then, keys will be read
		--and mapped to ZO_ComboBox kyes (e.g. "font" -> "m_font"), or non-combobox keys will be taken 1:1 to the entry.data
		newEntry.additionalData = additionalData
	end


	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 162, tos(text), tos(callback), tos(entryType), tos(entries)) end

	--Add the line of the context menu to the internal tables. Will be read as the ZO_ComboBox's dropdown opens and calls
	--:AddMenuItems() -> Added to internal scroll list then
	local indexAdded = g_contextMenu:AddContextMenuItem(newEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)

	return indexAdded, newEntry
end
local addCustomScrollableMenuEntry = AddCustomScrollableMenuEntry

--Adds an entry having a submenu (or maybe nested submenues) in the entries table/entries function whch returns a table
--> See examples for the table "entries" values above AddCustomScrollableMenuEntry
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableSubMenuEntry(text, entries)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 163, tos(text), tos(entries)) end
	return addCustomScrollableMenuEntry(text, nil, LSM_ENTRY_TYPE_SUBMENU, entries, nil)
end

--Adds a divider line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuDivider()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 164) end
	return addCustomScrollableMenuEntry(libDivider, nil, LSM_ENTRY_TYPE_DIVIDER, nil, nil)
end

--Adds a header line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuHeader(text, additionalData)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 165, tos(text)) end
	return addCustomScrollableMenuEntry(text, nil, LSM_ENTRY_TYPE_HEADER, nil, additionalData)
end

--Adds a checkbox line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuCheckbox(text, callback, checked, additionalData)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 166, tos(text), tos(checked)) end
	if checked ~= nil then
		additionalData = additionalData or {}
		additionalData.checked = checked
	end
	return addCustomScrollableMenuEntry(text, callback, LSM_ENTRY_TYPE_CHECKBOX, nil, additionalData)
end


--Set the options (visible rows max, etc.) for the scrollable context menu, or any passed in 2nd param comboBoxContainer
-->See possible options above AddCustomScrollableComboBoxDropdownMenu
function SetCustomScrollableMenuOptions(options, comboBoxContainer)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 167, tos(getControlName(comboBoxContainer)), tos(options)) end
--df("[LSM]SetCustomScrollableMenuOptions - comboBoxContainer: %s, options: %s", tos(getControlName(comboBoxContainer)), tos(options))

	--Use specified comboBoxContainer's dropdown to update the options to
	if comboBoxContainer ~= nil then
		local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
		if comboBox == nil and comboBoxContainer.m_dropdownObject ~= nil then
			comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer.m_dropdownObject)
		end
		if comboBox ~= nil and comboBox.UpdateOptions then
			comboBox.optionsChanged = options ~= comboBox.options
--d(">comboBox:UpdateOptions -> optionsChanged: " ..tos(comboBox.optionsChanged))
			comboBox:UpdateOptions(options)
		end
	else
--d(">g_contextMenu:SetContextMenuOptions")
		--Update options to default contextMenu
		g_contextMenu:SetContextMenuOptions(options)
	end
end
local setCustomScrollableMenuOptions = SetCustomScrollableMenuOptions

--Hide the custom scrollable context menu and clear it's entries, clear internal variables, mouse clicks etc.
function ClearCustomScrollableMenu()
--d(debugPrefix .. "<<<<<< ClearCustomScrollableMenu <<<<<<<<<<<<<")
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 168) end
	hideContextMenu()

	setCustomScrollableMenuOptions(defaultComboBoxOptions, nil)
	return true
end
local clearCustomScrollableMenu = ClearCustomScrollableMenu

--Pass in a table/function returning a table with predefined context menu entries and let them all be added in order of the table's number key
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns boolean allWereAdded, nilable:table indicesOfNewAddedEntries, nilable:table newEntriesData
function AddCustomScrollableMenuEntries(contextMenuEntries)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 169, tos(contextMenuEntries)) end

	local indicesAdded = nil
	local newAddedEntriesData = nil

	contextMenuEntries = validateContextMenuSubmenuEntries(contextMenuEntries, nil, "AddCustomScrollableMenuEntries")
	if ZO_IsTableEmpty(contextMenuEntries) then return false, nil, nil end
	for _, v in ipairs(contextMenuEntries) do
		--If a label was explicitly requested
		local label = v.label
		if label ~= nil then
			--Check if it was requested at the additinalData.label too: If yes, keep that
			--If no: Add it there for a proper usage in AddCustomScrollableMenuEntry -> newEntry
			if v.additionalData == nil then
				v.additionalData = { label = label }
			elseif v.additionalData.label == nil then
				v.additionalData.label = label
			end
		end
		local indexAdded, newAddedEntry = addCustomScrollableMenuEntry(v.name, v.callback, v.entryType, v.entries, v.additionalData)
		if indexAdded == nil or newAddedEntry == nil then return false, nil, nil end

		indicesAdded = indicesAdded or {}
		tins(indicesAdded, indexAdded)
		newAddedEntriesData = newAddedEntriesData or {}
		tins(newAddedEntriesData, newAddedEntry)
	end
	return true, indicesAdded, newAddedEntriesData
end
local addCustomScrollableMenuEntries = AddCustomScrollableMenuEntries

--Populate a new scrollable context menu with the defined entries table/a functinon returning the entries.
--Existing context menu entries will be reset, because ClearCustomScrollableMenu will be called!
--You can add more entries later, prior to showing, via AddCustomScrollableMenuEntry / AddCustomScrollableMenuEntries functions too
---> returns boolean allWereAdded, nilable:table indicesOfNewAddedEntries, nilable:table newEntriesData
function AddCustomScrollableMenu(entries, options)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 170, tos(entries), tos(options)) end
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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 171, tos(getControlName(controlToAnchorTo)), tos(options)) end
--d("°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°")
--df("[LSM]_-_-_-_-_ShowCustomScrollableMenu - controlToAnchorTo: %s, options: %s", tos(getControlName(controlToAnchorTo)), tos(options))

	--Fire the OnDropdownMenuAdded callback where one can replace options in the options table -> Here: For the contextMenu
	local optionsForCallbackFire = options or {}
	lib:FireCallbacks('OnDropdownMenuAdded', g_contextMenu, optionsForCallbackFire)
	if optionsForCallbackFire ~= options then
		options = optionsForCallbackFire
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 172, tos(getControlName(g_contextMenu.m_container)), tos(options)) end

	if options ~= nil then
--d(">>>>>calling SetCustomScrollableMenuOptions")
		setCustomScrollableMenuOptions(options)
	end

	controlToAnchorTo = controlToAnchorTo or moc()
	g_contextMenu:ShowContextMenu(controlToAnchorTo)
	return true
end
local showCustomScrollableMenu = ShowCustomScrollableMenu

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
---> returns boolean customCallbackFuncWasExecuted, nilable:any customCallbackFunc's return value
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

--d(debugPrefix .. ""..assertFuncName.." - filterEntryTypes: " ..tos(gotFilterEntryTypes) .. ", type: " ..tos(filterEntryTypesTableType) ..", fromParentMenu: " ..tos(fromParentMenuValue))

	--Find out via comboBox and item -> What was the "opening menu" and "how do I get openingMenu m_sortedItems"?
	--comboBox would be the comboBox or dropdown of the context menu -> if RunCustomScrollableMenuCheckboxCallback was called from the callback of a contex menu entry
	--item could have a control or something like that from where we can get the owner and then check if the owner got a openingControl or similar?
	local sortedItems = getComboBoxsSortedItems(comboBox, fromParentMenu, false)
	if ZO_IsTableEmpty(sortedItems) then return false end

	local itemsForCallbackFunc = sortedItems

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

	return true, myAddonCallbackFunc(comboBox, item, itemsForCallbackFunc, ...)
end


-- API to show a context menu at a buttonGrouop where you can set all buttons in a group based on Select all, Unselect All, Invert all.
function buttonGroupDefaultContextMenu(comboBox, control, data)
	local buttonGroup = comboBox.m_buttonGroup
	if buttonGroup == nil then return end
	local groupIndex = getValueOrCallback(data.buttonGroup, data)
	if groupIndex == nil then return end
	local entryType = getValueOrCallback(data.entryType, data)
	if entryType == nil then return end

--d(debugPrefix .. "setButtonGroupState - comboBox: " .. tos(comboBox) .. ", control: " .. tos(getControlName(control)) .. ", entryType: " .. tos(entryType) .. ", groupIndex: " .. tos(groupIndex))

	local buttonGroupSetAll = {
		{ -- LSM_ENTRY_TYPE_NORMAL selecct and close.
			name = GetString(SI_LSM_CNTXT_CHECK_ALL), --Check All
			--entryType = LSM_ENTRY_TYPE_BUTTON,
			entryType = LSM_ENTRY_TYPE_NORMAL,
			--additionalData = {
				--horizontalAlignment = TEXT_ALIGN_CENTER,
				--selectedSound = origSoundComboClicked, -- not working? I want it to sound like a button.
				-- ignoreCallback = true -- Just a thought
			--},
			callback = function()
				local buttonGroupOfEntryType = getButtonGroupOfEntryType(comboBox, groupIndex, entryType)
				if buttonGroupOfEntryType == nil then return end
				return buttonGroupOfEntryType:SetChecked(control, true, data.ignoreCallback) -- Sets all as selected
			end,
		},
		{
			name = GetString(SI_LSM_CNTXT_CHECK_NONE),-- Check none
			entryType = LSM_ENTRY_TYPE_NORMAL,
			--additionalData = {
				--horizontalAlignment = TEXT_ALIGN_CENTER,
				--selectedSound = origSoundComboClicked, -- not working? I want it to sound like a button.
			--},
			callback = function()
				local buttonGroupOfEntryType = getButtonGroupOfEntryType(comboBox, groupIndex, entryType)
				if buttonGroupOfEntryType == nil then return end
				return buttonGroupOfEntryType:SetChecked(control, false, data.ignoreCallback) -- Sets all as unselected
			end,
		},
		{ -- LSM_ENTRY_TYPE_BUTTON allows for, invert, undo, invert, undo
			name = GetString(SI_LSM_CNTXT_CHECK_INVERT), -- Invert
			entryType = LSM_ENTRY_TYPE_NORMAL,
			callback = function()
				local buttonGroupOfEntryType = getButtonGroupOfEntryType(comboBox, groupIndex, entryType)
				if buttonGroupOfEntryType == nil then return end
				return buttonGroupOfEntryType:SetInverse(control, data.ignoreCallback) -- sets all as oposite of what they currently are set to.
			end,
		},
	}

	clearCustomScrollableMenu()
	addCustomScrollableMenuEntries(buttonGroupSetAll)
--d(debugPrefix .. "°°°°°°°°°°°°°°°° showCustomScrollableMenu checkbox context menu")
	showCustomScrollableMenu(nil, nil)
end
lib.SetButtonGroupState = buttonGroupDefaultContextMenu --Only for compatibilitxy (if any other addon was using 'SetButtonGroupState' already)
lib.ButtonGroupDefaultContextMenu = buttonGroupDefaultContextMenu


------------------------------------------------------------------------------------------------------------------------
-- API functions for custom scrollable inventory context menu (ZO_Menu / LibCustomMenu support)
------------------------------------------------------------------------------------------------------------------------
--> See ZO_Menu2LSM_Mapping.lua


------------------------------------------------------------------------------------------------------------------------
-- XML handler functions
------------------------------------------------------------------------------------------------------------------------
--XML OnClick handler for checkbox and radiobuttons
function lib.XMLButtonOnInitialize(control, entryType)
	--Which XML button control's handler was used, checkbox or radiobutton?
	local isCheckbox = entryType == LSM_ENTRY_TYPE_CHECKBOX
	local isRadioButton = not isCheckbox and entryType == LSM_ENTRY_TYPE_RADIOBUTTON

	control:GetParent():SetHandler('OnMouseUp', function(parent, buttonId, upInside, ...)
--d(debugPrefix .. "OnMouseUp of parent-upInside: " ..tos(upInside) .. ", buttonId: " .. tos(buttonId))
		if upInside then
			if checkIfContextMenuOpenedButOtherControlWasClicked(control, parent.m_owner, buttonId) == true then return end
			if buttonId == MOUSE_BUTTON_INDEX_LEFT then
				local data = getControlData(parent)
				playSelectedSoundCheck(parent.m_dropdownObject, data.entryType)

				local onClickedHandler = control:GetHandler('OnClicked')
				if onClickedHandler then
					onClickedHandler(control, buttonId)
				end

			elseif buttonId == MOUSE_BUTTON_INDEX_RIGHT then
				local owner = parent.m_owner
				local data = getControlData(parent)
				local rightClickCallback = data.contextMenuCallback or data.rightClickCallback
				if rightClickCallback and not g_contextMenu.m_dropdownObject:IsOwnedByComboBox(owner) then
					if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 173) end
					rightClickCallback(owner, parent, data)
				end
			end
		end
	end)

	if not isRadioButton then
		local originalClicked = control:GetHandler('OnClicked')
		control:SetHandler('OnClicked', function(p_control, buttonId, ignoreCallback, skipHiddenForReasonsCheck, ...)
			skipHiddenForReasonsCheck = skipHiddenForReasonsCheck or false
			if not skipHiddenForReasonsCheck then
				local parent = p_control:GetParent()
				local comboBox = parent.m_owner
				if checkIfContextMenuOpenedButOtherControlWasClicked(p_control, comboBox, buttonId) == true then return end
			end

			if originalClicked then
				originalClicked(p_control, buttonId, ignoreCallback, ...)
			end
			p_control.checked = nil
		end)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------

--Load of the addon/library starts
local function onAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)

	--Debug logging
	libDebug.LoadLogger()
	libDebug = lib.Debug
	dlog = libDebug.DebugLog
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 174) end

	--SavedVariables
	lib.SV = ZO_SavedVars:NewAccountWide(svName, 1, "LSM", lsmSVDefaults)
	sv = lib.SV

	--Create the ZO_ComboBox and the g_contextMenu object (lib.contextMenu) for the LSM contextmenus
	createContextMenuObject()


	--------------------------------------------------------------------------------------------------------------------
	--Hooks & ZOs code changes
	--------------------------------------------------------------------------------------------------------------------
	--Register a scene manager callback for the SetInUIMode function so any menu opened/closed closes the context menus of LSM too
	SecurePostHook(SCENE_MANAGER, 'SetInUIMode', function(self, inUIMode, bypassHideSceneConfirmationReason)
		if not inUIMode then
			ClearCustomScrollableMenu()
		end
	end)

	--Register a scene manager callback for the SetInUIMode function so any menu opened/closed closes the context menus of LSM too
	SecurePostHook(SCENE_MANAGER, 'Show', function(self, ...)
		hideCurrentlyOpenedLSMAndContextMenu()
	end)

	--ZO_Menu - ShowMenu hook: Hide LSM if a ZO_Menu menu opens
	ZO_PreHook("ShowMenu", function(owner, initialRefCount, menuType)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 175, tos(#ZO_Menu.items), tos(menuType)) end
		--Do not close on other menu types (only default menu type supported)
		if menuType ~= nil and menuType ~= MENU_TYPE_DEFAULT then return end

		--No entries in ZO_Menu -> nothign will be shown, abort here
		if next(ZO_Menu.items) == nil then
			return false
		end
		--Should the ZO_Menu not close any opened LSM? e.g. to show the textSearchHistory at the LSM text filter search box
		if lib.preventLSMClosingZO_Menu then
			lib.preventLSMClosingZO_Menu = nil
			return
		end
		hideCurrentlyOpenedLSMAndContextMenu()
		return false
	end)

	--------------------------------------------------------------------------------------------------------------------
	--Slash commands
	--------------------------------------------------------------------------------------------------------------------
	SLASH_COMMANDS["/lsmdebug"] = function()
		debugLoggingToggle("debug")
	end
	SLASH_COMMANDS["/lsmdebugverbose"] = function()
		debugLoggingToggle("debugVerbose")
	end
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
WORKING ON - Current version: 2.33 - Updated 2024-12-28
-------------------
-Bug fix: 	Submenu options applied again via API function SetCustomScrollableMenuOptions did not apply (visibleRowsSubmenu e.g.)
-Bug fix: 	Name of handler for context menu show and hide changed to proper Uppercase OnContextMenu*
-Bug fix: 	XMLRowTemplates using a non capital R at some locations
-Bug fix: 	Fire the OnDropdownMenuAdded callback for the contextMenu too
-Bug fix: 	options.headerFont and headerColor work now and do not use m_headerFont etc. anymore to pass in the options
-Bug fix: 	Hide the tooltip as checkbox is toggled, or radioButton is changed
-Bug fix: 	Pool controls did not reapply the proper highlight upon scrolling and re-usage of the controls
-Changed: 	XML handlers for the header's text search etc. to call one LSM function to reduce redundant code
-Changed: 	handlers On(Sub/Context)MenuShow and Hide will provide the dropdownObject as 2nd parameter now (sames as 1st parameter's dropdownControl.m_dropdownObject)
-Changed: 	Moved debug messages to a table and use the index of the message instead of sending the whole text on each debug message, plus orevent calling debug messages if debugging is disbled
-Added: 	options.XMLRowHighlightTemplates for row highlight XML virtual templates and colors (on mouse enter) per entryType.
-Added: 	return values index/indices, entryData/entryDataTable to the context menu API functions AddCustomScrollableMenuEntry/Entries etc.
-Renamed: 	API function lib.SetButtonGroupState to lib.ButtonGroupDefaultContextMenu as the name was missleading. It never changed or set any values directly it only added a contextmenu where you could choose "Select all", "Select none", "Invers"
-Renamed: 	self.optionsData at contextMenus was properly renamed to self.contextMenuOptions




-------------------
TODO - To check (future versions)
-------------------

	1. Make Options update same style like updateDataValues does for entries
	2. Attention: zo_comboBox_base_hideDropdown(self) in self:HideDropdown() does NOT close the main dropdown if right clicked! Only for a left click... See ZO_ComboBox:HideDropdownInternal()
	3. verify submenu anchors. Small adjustments not easily seen on small laptop monitor
	- fired on handlers dropdown_OnShow dropdown_OnHide
	4. Make LSM options not  only accept XMLRowTemplates but their highlight templates too


-------------------
UPCOMING FEATURES  - What will be added in the future?
-------------------
	1. Sort headers for the dropdown (ascending/descending) (maybe: allowing custom sort functions too)
	2. LibCustomMenu and ZO_Menu support in inventories
]]

--[[
Placed here as a reminder to inspect how comboBox enabled is being handeled
not to be confused with itemData.enabled

function ZO_ComboBox_Base:SetEnabled(enabled)
	self.m_container:SetMouseEnabled(enabled)
	self.m_openDropdown:SetEnabled(enabled)
	self.m_selectedItemText:SetColor(self:GetSelectedTextColor(enabled))

	self:HideDropdown()
end

function ZO_ComboBox_Base:IsEnabled()
	return self.m_openDropdown:GetState() ~= BSTATE_DISABLED
end

		item.callback(self, item.name, item, selectionChanged, oldItem)
]]
