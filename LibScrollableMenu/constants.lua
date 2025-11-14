if LibScrollableMenu ~= nil then return end -- the same or newer version of this lib is already loaded into memory

--------------------------------------------------------------------
-- LibScrollableMenu - Object & version
--------------------------------------------------------------------
local lib = ZO_CallbackObject:New()
lib.name = "LibScrollableMenu"
lib.author = "Baertram, IsJustaGhost, tomstock, Kyoma"
lib.version = "2.38"
if not lib then return end
--------------------------------------------------------------------


--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--ZOs local speed-up/reference variables
local tos = tostring


--------------------------------------------------------------------
--Libray locals
--------------------------------------------------------------------
local MAJOR = lib.name

--Contains all created LSM objects
lib._objects = {}


--PreventerVariables
lib.preventerVars = {
	--suppressNextOnGlobalMouseUp = nil, --used in comboBox_base:OnGlobalMouseUp and comboBox_base:HiddenForReasons; if this is true the next globalOnMouseUp event on any control is skipped (e.g. to suppress the LSM menus closing by clicking somewhere on GuiRoot as a LSM contextMenu was opened)
	--suppressNextOnEntryMouseUp = nil,  --used in comboBox_base:HiddenForReasons and dropdownClass:OnEntryMouseUp; if this is true the next OnMouseUp event on any LSM control is skipped (e.g. to suppress the LSM entries to be selected by clicking on a LSM entry beklow an opened LSM contextmenu)
	--suppressNextOnEntryMouseUpDisableCounter = 0 --used in comboBox_base:HiddenForReasons and dropdownClass:OnEntryMouseUp; if this counter is ~= nil and > 0, it will count the suppressNextOnEntryMouseUp down by 1 each and if it reaches 0 it will reset suppressNextOnEntryMouseUp to nil (e.g. by clicking on a checkbox/radiobutton below an opened LSM contextMenu, the suppressNextOnEntryMouseUp might get set true twice. So we need to skip the 2nd one then)
	--wasContextMenuOpenedAsOnMouseUpWasSuppressed = nil, --used in comboBox_base closeContextMenuAndSuppressClickCheck, and dropdownClass:OnEntryMouseUp
}

--Library's XML functions and code
lib.XML = {}

--#2025_45 ContextMenu callbacks which got registered via API function ShowCustomScrollableMenu's parameter specialCallbackData
lib.contextMenuCallbacksRegistered = {}

--Constants for the library
lib.constants = {}
local constants = lib.constants


--------------------------------------------------------------------
--Logging and debugging
--------------------------------------------------------------------
lib.Debug = {}
lib.Debug.doDebug = false
lib.Debug.doVerboseDebug = false
lib.Debug.controlNameCache = {}

local debugPrefix = "[" .. MAJOR .. "]"
lib.Debug.prefix = debugPrefix
local libDebug = lib.Debug


--DebugLog types
local LSM_LOGTYPE_DEBUG = 1
local LSM_LOGTYPE_VERBOSE = 2
local LSM_LOGTYPE_DEBUG_CALLBACK = 3
local LSM_LOGTYPE_INFO = 10
local LSM_LOGTYPE_ERROR = 99
lib.Debug.LSM_LOGTYPE_DEBUG = LSM_LOGTYPE_DEBUG
lib.Debug.LSM_LOGTYPE_VERBOSE = LSM_LOGTYPE_VERBOSE
lib.Debug.LSM_LOGTYPE_DEBUG_CALLBACK = LSM_LOGTYPE_DEBUG_CALLBACK
lib.Debug.LSM_LOGTYPE_INFO = LSM_LOGTYPE_INFO
lib.Debug.LSM_LOGTYPE_ERROR = LSM_LOGTYPE_ERROR

--DebugLog type to name mapping
local loggerTypeToName = {
	[LSM_LOGTYPE_DEBUG] = 			" -DEBUG- ",
	[LSM_LOGTYPE_VERBOSE] = 		" -VERBOSE- ",
	[LSM_LOGTYPE_DEBUG_CALLBACK] = 	" -CALLBACK- ",
	[LSM_LOGTYPE_INFO] = 			" -INFO- ",
	[LSM_LOGTYPE_ERROR] = 			" -ERROR- ",
}
lib.Debug.loggerTypeToName = loggerTypeToName

local dlog = libDebug.DebugLog --nil here, will be updated upon usage within functions below


--------------------------------------------------------------------
--SavedVariables
--------------------------------------------------------------------
--The default SV variables
local lsmSVDefaults = {
	textSearchHistory = {},
	collapsedHeaderState = {},
}
lib.SVConstans = {
    name =      "LibScrollableMenu_SavedVars",
    version =   1,
    profile =   "LSM",
    defaults =  lsmSVDefaults,
}
lib.SV = {} --will be init properly at the onAddonLoaded function


--------------------------------------------------------------------
-- Other Libraries
--------------------------------------------------------------------
--LibDebugLogger


-----------------------------------------------------------------------
-- Library internal classes
--------------------------------------------------------------------
lib.classes = {}


-----------------------------------------------------------------------
-- Library utility
--------------------------------------------------------------------
lib.Util = {}
local libUtil = lib.Util


--Determine value or function returned value
--Run function arg to get the return value (passing in ... as optional params to that function),
--or directly use non-function return value arg
function libUtil.getValueOrCallback(arg, ...)
	if libDebug.doDebug then
		dlog = dlog or libDebug.DebugLog
		dlog(libDebug.LSM_LOGTYPE_VERBOSE, 6, tos(arg))
	end
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end
local getValueOrCallback = libUtil.getValueOrCallback



------------------------------------------------------------------------------------------------------------------------
--All kind of constants
local NIL_CHECK_TABLE = {}
constants.NIL_CHECK_TABLE = NIL_CHECK_TABLE

--Throttled calls
constants.throttledCallDelay = 		10

--Handler names
constants.handlerNames = {}
constants.handlerNames.dropdownCallLaterHandle = 	MAJOR .. "_Timeout"
local UINarrationName = MAJOR .. "_UINarration"
constants.handlerNames.UINarrationName = 			UINarrationName .. "_"
constants.handlerNames.UINarrationUpdaterName = 	UINarrationName .. "Updater_"
constants.handlerNames.throttledCallDelayName = 	MAJOR .. '_throttledCallDelay'

--ComboBox
constants.comboBox = {}

--Menu settings (main and submenu) - default values
constants.dropdown = {}
constants.dropdown.defaults = {}

constants.dropdown.defaults.DEFAULT_VISIBLE_ROWS 			= 10
constants.dropdown.defaults.DEFAULT_SORTS_ENTRIES 			= false --sort the entries in main- and submenu lists (ZO_ComboBox default is true!)
constants.dropdown.defaults.DEFAULT_HEIGHT                  = 250
constants.dropdown.defaults.MIN_WIDTH_WITHOUT_SEARCH_HEADER = 50
constants.dropdown.defaults.MIN_WIDTH_WITH_SEARCH_HEADER    = 125
local dropdownDefaults = constants.dropdown.defaults

--dropdown settings
constants.submenu = {}
constants.submenu.SUBMENU_SHOW_TIMEOUT = 500 --350 ms before
--local submenu = constants.submenu

--Entry type default settings
constants.entryTypes = {}
constants.entryTypes.defaults = {}
constants.entryTypes.defaults.DIVIDER_ENTRY_HEIGHT 					= 7
constants.entryTypes.defaults.HEADER_ENTRY_HEIGHT 					= 30
constants.entryTypes.defaults.DEFAULT_SPACING 						= 0
constants.entryTypes.defaults.WITHOUT_ICON_LABEL_DEFAULT_OFFSETX 	= 4
local entryTypeDefaults = constants.entryTypes.defaults

--Fonts
constants.fonts = {}
constants.fonts.DEFAULT_FONT = 					"ZoFontGame"
constants.fonts.HeaderFontTitle = 				"ZoFontHeader3"
constants.fonts.HeaderFontSubtitle = 			"ZoFontHeader2"
local fonts = constants.fonts

--Colors
constants.colors = {}
constants.colors.HEADER_TEXT_COLOR = 			ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED))
constants.colors.DEFAULT_TEXT_COLOR = 			ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
constants.colors.DEFAULT_TEXT_HIGHLIGHT = 		ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))
constants.colors.DEFAULT_TEXT_DISABLED_COLOR = 	ZO_GAMEPAD_UNSELECTED_COLOR
constants.colors.DEFAULT_ARROW_COLOR = 			ZO_ColorDef:New("FFFFFF")
local colors = constants.colors

--Textures
constants.textures = {}
constants.textures.iconNewIcon = 				ZO_KEYBOARD_NEW_ICON


--Narration
constants.narration = {}
constants.narration.iconNarrationNewValue = 	GetString(SI_SCREEN_NARRATION_NEW_ICON_NARRATION) --MultiIcon


--local "global" variables
--Highlight and animation
constants.entryTypes.defaults.highlights = {}
constants.entryTypes.defaults.highlights.defaultHighlightTemplate = nil 	-- See below at comboBoxDefaults
constants.entryTypes.defaults.highlights.defaultHighlightColor = nil		-- See below at comboBoxDefaults
constants.entryTypes.defaults.highlights.defaultHighLightAnimationFieldName = 'LSM_HighlightAnimation'
constants.entryTypes.defaults.highlights.subAndContextMenuHighlightAnimationBreadcrumbsPattern = '%s_%s'


------------------------------------------------------------------------------------------------------------------------
--Entry types - For the scroll list's dataType of the menus
local LSM_ENTRY_TYPE_NORMAL 		= 1
local LSM_ENTRY_TYPE_DIVIDER 		= 2
local LSM_ENTRY_TYPE_HEADER 		= 3
local LSM_ENTRY_TYPE_SUBMENU 		= 4
local LSM_ENTRY_TYPE_CHECKBOX		= 5
local LSM_ENTRY_TYPE_BUTTON 		= 6
local LSM_ENTRY_TYPE_RADIOBUTTON 	= 7
local LSM_ENTRY_TYPE_EDITBOX 		= 8
local LSM_ENTRY_TYPE_SLIDER 		= 9

--Updater modes for the menus (See API function RefreshCustomScrollableMenu)
LSM_UPDATE_MODE_MAINMENU = 1
LSM_UPDATE_MODE_SUBMENU = 2
LSM_UPDATE_MODE_BOTH = 99


--Constant for the divider entryType
lib.DIVIDER = "-"

--Make them accessible for the DropdownObject:New options table -> options.XMLRowTemplates
lib.scrollListRowTypes = {
	["LSM_ENTRY_TYPE_NORMAL"] =			LSM_ENTRY_TYPE_NORMAL,
	["LSM_ENTRY_TYPE_DIVIDER"] = 		LSM_ENTRY_TYPE_DIVIDER,
	["LSM_ENTRY_TYPE_HEADER"] = 		LSM_ENTRY_TYPE_HEADER,
	["LSM_ENTRY_TYPE_SUBMENU"] = 		LSM_ENTRY_TYPE_SUBMENU,
	["LSM_ENTRY_TYPE_CHECKBOX"] =		LSM_ENTRY_TYPE_CHECKBOX,
	["LSM_ENTRY_TYPE_BUTTON"] =			LSM_ENTRY_TYPE_BUTTON,
	["LSM_ENTRY_TYPE_RADIOBUTTON"] = 	LSM_ENTRY_TYPE_RADIOBUTTON,
	["LSM_ENTRY_TYPE_EDITBOX"] = 		LSM_ENTRY_TYPE_EDITBOX,
	["LSM_ENTRY_TYPE_SLIDER"] =			LSM_ENTRY_TYPE_SLIDER,
}
local scrollListRowTypes = lib.scrollListRowTypes

--The custom scrollable context menu entry types > Globals
for key, value in pairs(scrollListRowTypes) do
	--Create the lib.LSM_ENTRY_TYPE* variables
	lib[key] = value
	constants.entryTypes[key] = value
	--Create the LSM_ENTRY_TYPE*L globals
	_G[key] = value
end

--Exclude the OnMouseUp handler for these rowTypes (entryTypes) as the callbacks of an editBox/slider should not be executed
--if you click the row, but the editBox's text/the slider's value was changed (via XML handlers!)
local onEntryMouseUpExclude = {
	[LSM_ENTRY_TYPE_EDITBOX] = true,
	[LSM_ENTRY_TYPE_SLIDER] = true,
}
constants.entryTypes.onEntryMouseUpExclude = onEntryMouseUpExclude

--Mapping table for entryType to button's childName (in XML template)
local entryTypeToButtonChildName = {
	[LSM_ENTRY_TYPE_CHECKBOX] = 	"Checkbox",
	[LSM_ENTRY_TYPE_RADIOBUTTON] = 	"RadioButton",
}
constants.entryTypes.entryTypeToButtonChildName = entryTypeToButtonChildName

--Is the entryType having a subcontrol like a checkbox (then define it true here so the parent control, the row, will be selected properly)
local isEntryTypeWithParentMocCtrl = {
	[LSM_ENTRY_TYPE_CHECKBOX] = true,
	[LSM_ENTRY_TYPE_RADIOBUTTON] = true,
	[LSM_ENTRY_TYPE_EDITBOX] = true,
	[LSM_ENTRY_TYPE_SLIDER] = true,
}
constants.entryTypes.isEntryTypeWithParentMocCtrl = isEntryTypeWithParentMocCtrl

--Used in API RunCustomScrollableMenuItemsCallback and comboBox_base:AddCustomEntryTemplates to validate passed in entryTypes
local libraryAllowedEntryTypes = {
	[LSM_ENTRY_TYPE_NORMAL] = 		true,
	[LSM_ENTRY_TYPE_DIVIDER] = 		true,
	[LSM_ENTRY_TYPE_HEADER] = 		true,
	[LSM_ENTRY_TYPE_SUBMENU] =		true,
	[LSM_ENTRY_TYPE_CHECKBOX] =		true,
	[LSM_ENTRY_TYPE_BUTTON] =		true,
	[LSM_ENTRY_TYPE_RADIOBUTTON] =	true,
	[LSM_ENTRY_TYPE_EDITBOX] = 		true,
	[LSM_ENTRY_TYPE_SLIDER] = 		true,
}
constants.entryTypes.libraryAllowedEntryTypes = libraryAllowedEntryTypes
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
	[LSM_ENTRY_TYPE_EDITBOX] = 		true,
	[LSM_ENTRY_TYPE_SLIDER] = 		true,
}
constants.entryTypes.allowedEntryTypesForContextMenu = allowedEntryTypesForContextMenu
lib.AllowedEntryTypesForContextMenu = allowedEntryTypesForContextMenu

--Used in API AddCustomScrollableMenuEntry to validate passed in entryTypes to be used without a callback function
--provided (else the assert raises an error)
local entryTypesForContextMenuWithoutMandatoryCallback = {
	[LSM_ENTRY_TYPE_DIVIDER] = 		true,
	[LSM_ENTRY_TYPE_HEADER] = 		true,
	[LSM_ENTRY_TYPE_SUBMENU] =		true,
}
constants.entryTypes.entryTypesForContextMenuWithoutMandatoryCallback = entryTypesForContextMenuWithoutMandatoryCallback

--Table additionalData's key (e.g. isDivider) to the LSM entry type mapping
local additionalDataKeyToLSMEntryType = {
	["isDivider"] = 	LSM_ENTRY_TYPE_DIVIDER,
	["isHeader"] = 		LSM_ENTRY_TYPE_HEADER,
	["isCheckbox"] =	LSM_ENTRY_TYPE_CHECKBOX,
	["isButton"] = 		LSM_ENTRY_TYPE_BUTTON,
	["isRadioButton"] = LSM_ENTRY_TYPE_RADIOBUTTON,
	["isEditBox"] = 	LSM_ENTRY_TYPE_EDITBOX,
	["isSlider"] = 		LSM_ENTRY_TYPE_SLIDER,
}
constants.entryTypes.additionalDataKeyToLSMEntryType = additionalDataKeyToLSMEntryType

--##2025_44/2025_57 Table with entry's data key which could raise an automatic update of the entry, and all parentMenu
--entries.
local updateEntryPathsData = {
	updateEntryPath = "updateEntryPath",
	updateEntryPathCheckFunc = "updateEntryPathCheckFunc",
	updateIconPath = "updateIconPath"
}
constants.entryTypes.updateEntryPathsData = updateEntryPathsData

--The index of this table defines the priority -> The lower the index, the higher the priority (the higher the priority the
--earlier this data's callback function is called)
local dataAllowedAutomaticUpdateRaise = {
	[1] = updateEntryPathsData.updateEntryPath,
	[2] = updateEntryPathsData.updateIconPath,
}
constants.entryTypes.dataAllowedAutomaticUpdateRaise = dataAllowedAutomaticUpdateRaise


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
	constants.entryTypes.defaults.highlights[key] = value
	--Create the LSM_ROW_HIGHLIGHT* globals
	_G[key] = value
end

--The default row highlight data for all entries
local defaultHighlightTemplateData = {
	template = 	LSM_ROW_HIGHLIGHT_DEFAULT,
	color = 	colors.DEFAULT_TEXT_HIGHLIGHT,
}
constants.entryTypes.defaults.highlights.defaultHighlightTemplateData = defaultHighlightTemplateData

--The default row highlight data for an entry having a submenu, where the entry itsself got a callback
local defaultHighlightTemplateDataEntryHavingSubMenuWithCallback = {
	template = 	LSM_ROW_HIGHLIGHT_GREEN, --green row
	color = 	colors.DEFAULT_TEXT_HIGHLIGHT,
}
constants.entryTypes.defaults.highlights.defaultHighlightTemplateDataEntryHavingSubMenuWithCallback = defaultHighlightTemplateDataEntryHavingSubMenuWithCallback

--The default row highlight data for an entry opening a contextMenu
local defaultHighlightTemplateDataEntryContextMenuOpeningControl = {
	template = 	LSM_ROW_HIGHLIGHT_GREEN, --green row
	color = 	colors.DEFAULT_TEXT_HIGHLIGHT,
}
constants.entryTypes.defaults.highlights.defaultHighlightTemplateDataEntryContextMenuOpeningControl = defaultHighlightTemplateDataEntryContextMenuOpeningControl




------------------------------------------------------------------------------------------------------------------------
--Entries data
constants.data = {}
constants.data.subtables = {}
--The subtable in entry.data table where all LibScrollableMenu relevant extra data and functions etc. are stored
constants.data.subtables.LSM_DATA_SUBTABLE =						"_LSM"
--The subtable names in the entry.data[LSM_DATA_SUBTABLE] table where:
---the original data table is copied to, for reference and e.g. keeping passed in m_highlightTemplate etc. values
constants.data.subtables.LSM_DATA_SUBTABLE_ORIGINAL_DATA =			"OriginalData"
---the functions of data[key] are stored, so we can execute them each time we need it to return the real value for data[key]
constants.data.subtables.LSM_DATA_SUBTABLE_CALLBACK_FUNCTIONS = 	"funcData"


------------------------------------------------------------------------------------------------------------------------
--Entries key mapping
constants.comboBox.mapping = {}

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
constants.comboBox.mapping.LSMEntryKeyZO_ComboBoxEntryKey = LSMEntryKeyZO_ComboBoxEntryKey

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
constants.comboBox.mapping.possibleEntryDataWithFunction = possibleEntryDataWithFunction

------------------------------------------------------------------------------------------------------------------------
--Default options/settings and values

--ZO_ComboBox default settings: Will be copied over as default attributes to comboBoxClass and inherited to the scrollable
--dropdown helper classes, but only if they were not set in an existing ZO_ComboBox already (e.g. multiselection, etc.)
--before LSM was added
-->For LSM contextMenus these options will be used as defaultValues on each open! If you want to change them make sure to
-->pass in your own options at API functions of contextMenu's "Show"
local comboBoxDefaults = {
	--From ZO_ComboBox
	---member data with m_
	m_disabledColor = 				colors.DEFAULT_TEXT_DISABLED_COLOR,
	m_enableMultiSelect = 			false,
	m_font = 						fonts.DEFAULT_FONT,
	m_height = 						dropdownDefaults.DEFAULT_HEIGHT,
	m_highlightColor = 				colors.DEFAULT_TEXT_HIGHLIGHT,
	m_highlightTemplate =			LSM_ROW_HIGHLIGHT_DEFAULT, --ZO_SelectionHighlight
	m_isDropdownVisible = 			false,
	m_maxNumSelectionsErrorText =	GetString(SI_COMBO_BOX_MAX_SELECTIONS_REACHED_ALERT),
	m_normalColor = 				colors.DEFAULT_TEXT_COLOR,
	--m_preshowDropdownFn =  		 nil, --Setting this nil will
	m_selectedColor =				{ GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED) },
	m_sortsItems = 					false, --ZO_ComboBox real default is true
	m_sortOrder = 					ZO_SORT_ORDER_UP,
	m_sortType = 					ZO_SORT_BY_NAME,
	m_spacing = 					entryTypeDefaults.DEFAULT_SPACING,
	multiSelectionTextFormatter = 	SI_COMBO_BOX_DEFAULT_MULTISELECTION_TEXT_FORMATTER,
	noSelectionText = 				GetString(SI_COMBO_BOX_DEFAULT_NO_SELECTION_TEXT),

	--non member data
	horizontalAlignment = 			TEXT_ALIGN_LEFT,

	--LibCustomMenu support
	itemYPad = 						0,

	--LibScrollableMenu internal (e.g. options)
	automaticRefresh = 				false, --#2025_42
	automaticSubmenuRefresh =		false, --#2025_42
	baseEntryHeight = 				ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
	containerMinWidth = 			dropdownDefaults.MIN_WIDTH_WITHOUT_SEARCH_HEADER,
	disableFadeGradient = 			false,
	enableFilter = 					false, --#2025_27
	headerFont =					fonts.DEFAULT_FONT,
	headerColor = 					colors.HEADER_TEXT_COLOR,
	headerCollapsed = 				false,
	submenuArrowColor = 			colors.DEFAULT_ARROW_COLOR,
	visibleRows = 					dropdownDefaults.DEFAULT_VISIBLE_ROWS,
	visibleRowsSubmenu = 			dropdownDefaults.DEFAULT_VISIBLE_ROWS,
}
constants.comboBox.defaults = comboBoxDefaults

--Always overwrite these settings in the comboBoxes with these default values of LSM
--e.g. sorting = disabled (ZO_ComboBox default sorting = enabled).
---> This will only happen if API function AddCustomScrollableComboBoxDropdownMenu was used to apply a LSM to an existing ZO_ComboBox!
-->Key = comboBox variable name, value = table with if and changeTo. If the "ifEquals" check (can be a function or a value) passes then the changeTo (can be a function or a value)
-- will be set as ZO_ComboBox[key]
local comboBoxDefaultsContextualInitValues = {
	m_sortsItems = 	{ ["ifEquals"]=true, ["changeTo"]=comboBoxDefaults.m_sortsItems }, --ZO_ComboBox real default is true
}
constants.comboBox.defaultsContextualInitValues = comboBoxDefaultsContextualInitValues

--Set the default highlight values
constants.entryTypes.defaults.highlights.defaultHighlightTemplate = comboBoxDefaults.m_highlightTemplate
constants.entryTypes.defaults.highlights.defaultHighlightColor = comboBoxDefaults.m_highlightColor


--The default values for dropdownHelper options -> used for non-passed in options at LSM API functions
local defaultComboBoxOptions  = {
	["automaticRefresh"] = 			false, --#2025_42
	["automaticSubmenuRefresh"] =	false, --#2025_42
	["enableFilter"] = 				false,
	["disableFadeGradient"] = 		false,
	["font"] = 						fonts.DEFAULT_FONT,
	["headerCollapsed"] =			false,
	["headerCollapsible"] = 		false,
	["highlightContextMenuOpeningControl"] = false,
	["sortEntries"] = 				dropdownDefaults.DEFAULT_SORTS_ENTRIES,
	["spacing"] = 					entryTypeDefaults.DEFAULT_SPACING,
	["useDefaultHighlightForSubmenuWithCallback"] = false,
	["visibleRowsDropdown"] = 		dropdownDefaults.DEFAULT_VISIBLE_ROWS,
	["visibleRowsSubmenu"] = 		dropdownDefaults.DEFAULT_VISIBLE_ROWS,
	--["XMLRowTemplates"] = 		table, --Will be set at comboBoxClass:UpdateOptions(options) from options (see function comboBox_base:AddCustomEntryTemplates)
	--["XMLRowHighlightTemplates"] =table, --Will be set at comboBoxClass:UpdateOptions(options) from options (see function comboBox_base:AddCustomEntryTemplates)
}
constants.comboBox.defaultComboBoxOptions  = defaultComboBoxOptions


------------------------------------------------------------------------------------------------------------------------
-- LSM Options -> ZO_ComboBox options
------------------------------------------------------------------------------------------------------------------------
--Options key mapping
--The mapping between LibScrollableMenu options key and ZO_ComboBox's key. Used in comboBoxClass:UpdateOptions()
local LSMOptionsKeyToZO_ComboBoxOptionsKey = {
	--All possible options entries "must" be mapped here (left: options entry / right: ZO_ComboBox relating entry where the value is saved)
	-->e.g. options.visibleRowsDropdown -> Will be saved at comboBox.visibleRows (and if a function in table LSMOptionsToZO_ComboBoxOptionsCallbacks
	-->is defiend below this function will be executed too).
	-->Missing entries (even if names are the same) will relate in function comboBoxClass:SetOption not respecting the value!
	["automaticRefresh"] =		"automaticRefresh", --#2025_42
	["automaticSubmenuRefresh"]= "automaticSubmenuRefresh", --#2025_42
	["disableFadeGradient"] =	"disableFadeGradient", --Used for the ZO_ScrollList of the dropdown, not the comboBox itsself
	["disabledColor"] =			"m_disabledColor",
	["enableFilter"] =			"enableFilter",
	["enableMultiSelect"] = 	"m_enableMultiSelect",
	["headerCollapsible"] = 	"headerCollapsible",
	["headerCollapsed"] = 		"headerCollapsed",
	["headerColor"] =			"headerColor",
	["headerFont"] =			"headerFont",
	["highlightContextMenuOpeningControl"] = "highlightContextMenuOpeningControl",
	["maxNumSelections"] =		"m_maxNumSelections",
	["maxNumSelectionsErrorText"] = "m_overrideMaxSelectionsErrorText",
	["multiSelectionTextFormatter"] = "multiSelectionTextFormatter",
	["narrate"] = 				"narrateData",
	["normalColor"] = 			"m_normalColor",
	["noSelectionText"] = 		"noSelectionText",
	["subtitleText"] = 			"subtitleText",
	["subtitleFont"] = 			"subtitleFont",
	["titleFont"] = 			"titleFont",
	["titleText"] = 			"titleText",
	["titleTextAlignment"] =	"titleTextAlignment",
	["useDefaultHighlightForSubmenuWithCallback"] = "useDefaultHighlightForSubmenuWithCallback",
	["visibleRowsSubmenu"] =	"visibleRowsSubmenu",

	--Entries with callback function -> See table "LSMOptionsToZO_ComboBoxOptionsCallbacks" below
	-->!!!Attention: You must add those entries, which you add as callback function to table "LSMOptionsToZO_ComboBoxOptionsCallbacks",
	-->to this table LSMOptionsKeyToZO_ComboBoxOptionsKey here too!!!
	["font"] = 					"m_font",
	["maxDropdownHeight"] =		"maxHeight",
	["maxDropdownWidth"] =		"maxWidth",
	["minDropdownWidth"] =		"minWidth",
	["preshowDropdownFn"] = 	"m_preshowDropdownFn",
	["sortEntries"] = 			"m_sortsItems",
	["sortOrder"] = 			"m_sortOrder",
	["sortType"] = 				"m_sortType",
	["spacing"] = 				"m_spacing",
	["submenuArrowColor"] =		"submenuArrowColor",
	["submenuOpenToSide"] =		"submenuOpenToSide",
	["multiSelectSubmenuSelectedArrowColor"] = "multiSelectSubmenuSelectedArrowColor",
	["visibleRowsDropdown"] =	"visibleRows",
}
constants.comboBox.mapping.LSMOptionsKeyToZO_ComboBoxOptionsKey = LSMOptionsKeyToZO_ComboBoxOptionsKey


local function updateMultiSelectionOptions(comboBoxObject, isMultiSelectionEnabled, maxNumSelections, maxNumSelectionsErrorText, multiSelectionTextFormatter, noSelectionText, onSelectionBlockedCallback)
--d("============================ options->updateMultiSelectionOptions")
		--options which should be considered/updated first if comboBoxObject:EnableMultiSelect is called
	---maxNumSelections
	---maxNumSelectionsErrorText
	---noSelectionText
	---multiSelectionTextFormatter
	---onSelectionBlockedCallback
--[[
d(">isMultiSelectionEnabled = " .. tos(isMultiSelectionEnabled))
d(">maxNumSelections = " .. tos(maxNumSelections))
d(">maxNumSelectionsErrorText = " .. tos(maxNumSelectionsErrorText))
d(">noSelectionText = " .. tos(noSelectionText))
d(">multiSelectionTextFormatter = " .. tos(multiSelectionTextFormatter))
d(">onSelectionBlockedCallback = " .. tos(onSelectionBlockedCallback))
d("comboBoxObject.isContextMenu: " .. tos(comboBoxObject.isContextMenu) ..", contextMenuOptions: " .. tos(comboBoxObject.contextMenuOptions) .. ", options: " .. tos(comboBoxObject.options))
]]
	--#2025_21 20250323 if multiSelection is disabled in a contextmenu options (explicitly) -> Then updatedOptions and options are nil here and somehow ALL entries in the resulting context menua re missing at the end
	local options = comboBoxObject:GetOptions()
	local updatedOptions = comboBoxObject.updatedOptions

	local isMultiSelectionEnabledPassedIn = isMultiSelectionEnabled

	if isMultiSelectionEnabled == nil then
		isMultiSelectionEnabled = (updatedOptions ~= nil and updatedOptions.enableMultiSelect) or nil
		if isMultiSelectionEnabled == nil then
			isMultiSelectionEnabled = (options ~= nil and getValueOrCallback(options.enableMultiSelect, options)) or nil
		end
		if isMultiSelectionEnabled == nil then
			isMultiSelectionEnabled = comboBoxDefaults.m_enableMultiSelect
		end
	end

	maxNumSelections = maxNumSelections or							updatedOptions.maxNumSelections or 				getValueOrCallback(options.maxNumSelections, options) or comboBoxDefaults.m_maxNumSelections
	if maxNumSelections ~= nil and maxNumSelections < 0 then maxNumSelections = nil	end
	maxNumSelectionsErrorText = maxNumSelectionsErrorText or		updatedOptions.maxNumSelectionsErrorText or 	getValueOrCallback(options.maxNumSelectionsErrorText, options) or comboBoxDefaults.m_maxNumSelectionsErrorText
	noSelectionText = noSelectionText or 							updatedOptions.noSelectionText or 				getValueOrCallback(options.noSelectionText, options) or comboBoxDefaults.noSelectionText
	multiSelectionTextFormatter = multiSelectionTextFormatter or 	updatedOptions.multiSelectionTextFormatter or 	getValueOrCallback(options.multiSelectionTextFormatter, options) or comboBoxDefaults.multiSelectionTextFormatter
	onSelectionBlockedCallback = onSelectionBlockedCallback or		(updatedOptions.OnSelectionBlockedCallback or 	options.OnSelectionBlockedCallback) or comboBoxDefaults.onSelectionBlockedCallback

	updatedOptions.maxNumSelections = maxNumSelections
	updatedOptions.maxNumSelectionsErrorText = maxNumSelectionsErrorText
	updatedOptions.noSelectionText = noSelectionText
	updatedOptions.multiSelectionTextFormatter = multiSelectionTextFormatter
	updatedOptions.OnSelectionBlockedCallback = onSelectionBlockedCallback

	if isMultiSelectionEnabled == false then
		if isMultiSelectionEnabledPassedIn == false and not comboBoxObject.isContextMenu then
			comboBoxObject:DisableMultiSelect() --sets comboBoxObject.m_enableMultiSelect = false AND attention: Calls comboBoxObject:ClaerItems, so do not call that here for e.g. contextMenus or the list will be empty
		end
--d("<multiSelect disabled")
		return
	end
--d(">multiSelect enabled")

	comboBoxObject:SetMaxSelections(maxNumSelections)
	comboBoxObject:SetMaxSelectionsErrorText(maxNumSelectionsErrorText)
	comboBoxObject:SetOnSelectionBlockedCallback(onSelectionBlockedCallback)
	comboBoxObject:EnableMultiSelect(multiSelectionTextFormatter, noSelectionText) --sets comboBoxObject.m_enableMultiSelect = true
end

--The callback functions for the mapped LSM option -> ZO_ComboBox options (where any provided/needed)
local LSMOptionsToZO_ComboBoxOptionsCallbacks = {
	--These callback functions will apply the options directly
	--If self. (= comboBoxObject) "updatedOptions" table is provided it might contain already processed
	--"updated" options of the current loop at self:UpdateOptions(optionsTable)
	-->You can use these table entries to get the most up2date values of the currently processed options

	["enableMultiSelect"] = function(comboBoxObject, isMultiSelectionEnabled)
		updateMultiSelectionOptions(comboBoxObject, isMultiSelectionEnabled, nil, nil, nil, nil, nil)
	end,
	["font"] = function(comboBoxObject, font)
		comboBoxObject:SetFont(font) --sets comboBoxObject.m_font
	end,
	["maxDropdownHeight"] = function(comboBoxObject, maxDropdownHeight)
		comboBoxObject.maxHeight = maxDropdownHeight
		comboBoxObject:UpdateHeight(comboBoxObject.m_dropdown)
	end,
	["maxDropdownWidth"] = function(comboBoxObject, maxDropdownWidth)
		comboBoxObject.maxWidth = maxDropdownWidth
		comboBoxObject:UpdateWidth(comboBoxObject.m_dropdown)
	end,
	["minDropdownWidth"] = function(comboBoxObject, minDropdownWidth)
		comboBoxObject.minWidth = minDropdownWidth
		comboBoxObject:UpdateWidth(comboBoxObject.m_dropdown)
	end,
	["maxNumSelections"] = function(comboBoxObject, maxNumSelections)
		updateMultiSelectionOptions(comboBoxObject, nil, maxNumSelections, nil, nil, nil, nil)
	end,
	["maxNumSelectionsErrorText"] = function(comboBoxObject, maxNumSelectionsErrorText)
		updateMultiSelectionOptions(comboBoxObject, nil, nil, maxNumSelectionsErrorText, nil, nil, nil)
	end,
	["multiSelectionTextFormatter"] = function(comboBoxObject, multiSelectionTextFormatter)
		updateMultiSelectionOptions(comboBoxObject, nil, nil, nil, multiSelectionTextFormatter, nil, nil)
	end,
	["noSelectionText"] = function(comboBoxObject, noSelectionText)
		updateMultiSelectionOptions(comboBoxObject, nil, nil, nil, nil, noSelectionText, nil)
	end,
	["OnSelectionBlockedCallback"] = function(comboBoxObject, OnSelectionBlockedCallbackFunc)
		updateMultiSelectionOptions(comboBoxObject, nil, nil, nil, nil, nil, OnSelectionBlockedCallbackFunc)
	end,
	["preshowDropdownFn"] = function(comboBoxObject, preshowDropdownCallbackFunc)
		comboBoxObject:SetPreshowDropdownCallback(preshowDropdownCallbackFunc) --sets m_preshowDropdownFn
	end,
	["sortEntries"] = function(comboBoxObject, sortEntries)
		comboBoxObject:SetSortsItems(sortEntries) --sets comboBoxObject.m_sortsItems
	end,
	["sortOrder"] = function(comboBoxObject, sortOrder)
		local options = comboBoxObject.options
		local updatedOptions = comboBoxObject.updatedOptions
		--SortType was updated already during current comboBoxObject:UpdateOptions(options) -> SetOption() loop? No need to
		--update the sort order again here
		if updatedOptions.sortType ~= nil then return end

		local sortType = getValueOrCallback(options.sortType, options) or comboBoxObject.m_sortType
		comboBoxObject:SetSortOrder(sortType , sortOrder)
	end,
	["sortType"] = function(comboBoxObject, sortType)
		local options = comboBoxObject.options
		--Check if any updatedOptions already exist and if the sortOrder was updated already then sortType does not need
		--to be updated too (and vice versa)
		local updatedOptions = comboBoxObject.updatedOptions
		if updatedOptions.sortOrder then return end

		local sortOrder = getValueOrCallback(options.sortOrder, options)
		if sortOrder == nil then sortOrder = comboBoxObject.m_sortOrder end
		comboBoxObject:SetSortOrder(sortType , sortOrder )
	end,
	["spacing"] = function(comboBoxObject, spacing)
		comboBoxObject:SetSpacing(spacing) --sets comboBoxObject.m_spacing
	end,
	["visibleRowsDropdown"] = function(comboBoxObject, visibleRows)
		comboBoxObject.visibleRows = visibleRows
		comboBoxObject:UpdateHeight(comboBoxObject.m_dropdown)
	end,
}
constants.comboBox.mapping.LSMOptionsToZO_ComboBoxOptionsCallbacks = LSMOptionsToZO_ComboBoxOptionsCallbacks


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
	["m_containerWidth"] = true,
	["m_enableMultiSelect"] = true,
	["m_font"] = true,
	["m_highlightColor"] = true,
	["m_maxNumSelections"] = true,
	["m_multiSelectItemData"] = true,
	["m_overrideMaxSelectionsErrorText"] = true,
	["multiSelectionTextFormatter"] = true,
	["noSelectionText"] = true,
	["onSelectionBlockedCallback"] = true,
	["m_normalColor"] = true,

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
	["disableFadeGradient"] = true,
	["headerFont"] = true,
	["headerColor"] = true,
	["highlightContextMenuOpeningControl"] = true,
	["options"] = true,
	["maxDropdownHeight"] = true,
	["maxDropdownWidth"] = true,
	["minDropdownWidth"] = true,
	["m_highlightTemplate"] = true,
	["narrateData"] = true,
	["submenuArrowColor"] =	 true,
	["submenuOpenToSide"] = true,
	["multiSelectSubmenuSelectedArrowColor"] = true,
	["useDefaultHighlightForSubmenuWithCallback"] = true,
	["visibleRowsSubmenu"] = true, --we only need this "visibleRowsSubmenu" for the submenus, mainMenu uses visibleRowsDropdown
	["XMLRowTemplates"] = true,
	["XMLRowHighlightTemplates"] = true,
}
constants.submenu.submenuClass_exposedVariables = submenuClass_exposedVariables

-- Pass-through functions:
--If submenuClass_exposedFunctions[variable] == true: if submenuClass[key] is not nil, returns submenuClass[key](submenu.m_comboBox, ...)
local submenuClass_exposedFunctions = {
	["SelectItem"] = true, -- (item, ignoreCallback)
	["IsItemSelected"] = true,
}
constants.submenu.submenuClass_exposedFunctions = submenuClass_exposedFunctions


------------------------------------------------------------------------------------------------------------------------
-- Search filter
constants.searchFilter = {}

--No entry found in main menu
local noEntriesResults = {
	entryType = LSM_ENTRY_TYPE_NORMAL,
	enabled = false,
	name = GetString(SI_SORT_FILTER_LIST_NO_RESULTS) .. "    ", --add 4 spaces because of the icon at the left (XML row template)
	m_disabledColor = colors.DEFAULT_TEXT_DISABLED_COLOR,
	callback = function() d("no entries found!")  end,
	selectable = false,
	isNoEntriesResult = true,
}
constants.searchFilter.noEntriesResults = noEntriesResults

--No entry found in sub menu
local noEntriesSubmenuResults = {
	entryType = LSM_ENTRY_TYPE_NORMAL,
	enabled = false,
	name = GetString(SI_QUICKSLOTS_EMPTY) .. "    ", --add 4 spaces because of the icon at the left (XML row template),
	m_disabledColor = colors.DEFAULT_TEXT_DISABLED_COLOR,
	callback = function() d("no submenu entries found!")  end,
	selectable = false,
	isNoEntriesResult = true,
}
constants.searchFilter.noEntriesSubmenuResults = noEntriesSubmenuResults

--LSM entryTypes which should be processed by the text search/filter. Basically all entryTypes that use a label/name
local filteredEntryTypes = {
	[LSM_ENTRY_TYPE_NORMAL] = 	true,
	[LSM_ENTRY_TYPE_SUBMENU] = 	true,
	[LSM_ENTRY_TYPE_CHECKBOX] = true,
	[LSM_ENTRY_TYPE_HEADER] = 	true,
	[LSM_ENTRY_TYPE_BUTTON] = 	true,
	[LSM_ENTRY_TYPE_RADIOBUTTON] = true,
	--[LSM_ENTRY_TYPE_DIVIDER] = false,
	[LSM_ENTRY_TYPE_EDITBOX] = true,
	[LSM_ENTRY_TYPE_SLIDER] = true,
}
constants.searchFilter.filteredEntryTypes = filteredEntryTypes

--LSM entryTypes which should not search the LSMentry's name alone, but also another childControl of the LSMentry
--which was added to the data table as e.g. ._EditBoxCtrl reference
local filteredEntryTypsChildsToSearch = {
	[LSM_ENTRY_TYPE_EDITBOX] = {
		[1] = {
			dataTable = "editBoxData",
			dataName = "_EditBoxCtrl",
			getFunc = "GetText",
			getFuncReturnType = "string",
		}
	},
	[LSM_ENTRY_TYPE_SLIDER] = {
		[1] = {
			dataTable = "sliderData",
			dataName = "_SliderCtrl",
			getFunc = "GetValue",
			getFuncReturnType = "number",
		}
	},
}
constants.searchFilter.filteredEntryTypsChildsToSearch = filteredEntryTypsChildsToSearch

--Table defines if some names of the entries count as "search them or skip them".
--true: Item's name does not need to be searched -> skip them / false: search the item's name as usual
local filterNamesExempts = {
	--Direct check via "name" string
	[""] = true,
	[noEntriesSubmenuResults.name] = true, -- "Empty"
	--Check via type(name)
	--["nil"] = true,
}
constants.searchFilter.filterNamesExempts = filterNamesExempts



------------------------------------------------------------------------------------------------------------------------
--Sound settings
constants.sounds = {}

local origSoundComboClicked = 	SOUNDS.COMBO_CLICK
local origSoundDefaultClicked = SOUNDS.DEFAULT_CLICK
local soundClickedSilenced	= 	SOUNDS.NONE
constants.sounds.origSoundComboClicked = origSoundComboClicked
constants.sounds.origSoundDefaultClicked = origSoundDefaultClicked
constants.sounds.soundClickedSilenced = soundClickedSilenced

--Sound names of the combobox entry selected sounds
local defaultClick = "DEFAULT_CLICK"
constants.sounds.defaultClick = defaultClick
local comboClick = "COMBO_CLICK"
constants.sounds.comboClick = comboClick

local entryTypeToSilenceSoundName = {
	[LSM_ENTRY_TYPE_NORMAL] 	= 	comboClick,
	[LSM_ENTRY_TYPE_CHECKBOX]	=	defaultClick,
	[LSM_ENTRY_TYPE_BUTTON] 	= 	defaultClick,
	[LSM_ENTRY_TYPE_RADIOBUTTON]= 	defaultClick,
}
constants.sounds.entryTypeToSilenceSoundName = entryTypeToSilenceSoundName

--Original sounds of the combobox entry selected sounds
local entryTypeToOriginalSelectedSound = {
	[LSM_ENTRY_TYPE_NORMAL]		= origSoundComboClicked,
	[LSM_ENTRY_TYPE_CHECKBOX]	= origSoundDefaultClicked,
	[LSM_ENTRY_TYPE_BUTTON] 	= origSoundDefaultClicked,
	[LSM_ENTRY_TYPE_RADIOBUTTON]= origSoundDefaultClicked,
}
constants.sounds.entryTypeToOriginalSelectedSound = entryTypeToOriginalSelectedSound





------------------------------------------------------------------------------------------------------------------------
-- Global library reference
------------------------------------------------------------------------------------------------------------------------
LibScrollableMenu = lib