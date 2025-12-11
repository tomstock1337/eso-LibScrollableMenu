local lib = LibScrollableMenu
if not lib then return end

local MAJOR = lib.name


--------------------------------------------------------------------
-- For debugging and logging
--------------------------------------------------------------------
--Logging and debugging
local libDebug = lib.Debug
local debugPrefix = libDebug.prefix

local dlog = libDebug.DebugLog


--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--ZOs local speed-up/reference variables
local tos = tostring
local sfor = string.format
local tins = table.insert


--------------------------------------------------------------------
--Library classes
--------------------------------------------------------------------
local classes = lib.classes
local comboBoxClass = classes.comboBoxClass


--------------------------------------------------------------------
--LSM library locals
--------------------------------------------------------------------

local constants = lib.constants
local entryTypeConstants = constants.entryTypes
local comboBoxConstants = constants.comboBox
local defaultComboBoxOptions = comboBoxConstants.defaultComboBoxOptions
local comboBoxDefaults = comboBoxConstants.defaults

local libDivider = lib.DIVIDER

local libraryAllowedEntryTypes = entryTypeConstants.libraryAllowedEntryTypes
local allowedEntryTypesForContextMenu = entryTypeConstants.allowedEntryTypesForContextMenu
local entryTypesForContextMenuWithoutMandatoryCallback = entryTypeConstants.entryTypesForContextMenuWithoutMandatoryCallback

local libUtil = lib.Util
local getControlName = libUtil.getControlName
local getValueOrCallback = libUtil.getValueOrCallback
local getContextMenuReference = libUtil.getContextMenuReference
local getButtonGroupOfEntryType = libUtil.getButtonGroupOfEntryType
local hideContextMenu = libUtil.hideContextMenu
local getComboBoxsSortedItems = libUtil.getComboBoxsSortedItems
local validateContextMenuSubmenuEntries = libUtil.validateContextMenuSubmenuEntries
local checkEntryType = libUtil.checkEntryType
local libUtil_BelongsToContextMenuCheck = libUtil.belongsToContextMenuCheck

local g_contextMenu
local buttonGroupDefaultContextMenu


--------------------------------------------------------------------
--LSM library local functions
--------------------------------------------------------------------
local function updateContextMenuRef()
	g_contextMenu = g_contextMenu or getContextMenuReference()
	return g_contextMenu
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
--		number maxDropdownWidth					Number or function returning number of total dropdown's maximum width
--		number minDropdownWidth					Number or function returning number of total dropdown's minimum width
--		boolean sortEntries:optional			Boolean or function returning boolean if items in the main-/submenu should be sorted alphabetically. !!!Attention: Default is TRUE (sorting is enabled)!!!
--		table sortType:optional					table or function returning table for the sort type, e.g. ZO_SORT_BY_NAME, ZO_SORT_BY_NAME_NUMERIC
--		boolean sortOrder:optional				Boolean or function returning boolean for the sort order ZO_SORT_ORDER_UP or ZO_SORT_ORDER_DOWN
-- 		string font:optional				 	String or function returning a string: font to use for the dropdown entries
-- 		number spacing:optional,	 			Number or function returning a number: Spacing between the entries
--		boolean disableFadeGradient:optional	Boolean or function returning a boolean: for the fading of the top/bottom scrolled rows
--		string headerFont:optional				String or function returning a string: font to use for the header entries
--		table headerColor:optional				table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for header entries
--		table normalColor:optional				table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for all normal (enabled) entries
--		table disabledColor:optional 			table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for all disabled entries
--		table submenuArrowColor:optional		table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for the submenu opening arrow > texture
--		string submenuOpenToSide				String or function returning a string "left" or "right": Force the submenu to open at the left/right side. If not specififed the submenu opens at the side where there is enough space to show the whole menu (GUI root/screen size is respected)
--		boolean highlightContextMenuOpeningControl Boolean or function returning boolean if the openingControl of a context menu should be highlighted.
--												If you set this to true you either also need to set data.m_highlightTemplate at the row and provide the XML template name for the highLight, e.g. "LibScrollableMenu_Highlight_Green".
--												Or (if not at contextMenu options!!!) you can use the templateContextMenuOpeningControl at options.XMLRowHighlightTemplates[lib.scrollListRowTypes.LSM_ENTRY_TYPE_*] = { template = "ZO_SelectionHighlight" , templateContextMenuOpeningControl = "LibScrollableMenu_Highlight_Green" } to specify the XML highlight template for that entryType
-->  ===Dropdown multiselection ========================================================================================
--		boolean enableMultiSelect:optional		Boolean or function returning boolean if multiple items in the main-/submenu can be selected at the same time
--		number maxNumSelections:optional		Number or function returning a number: Maximum number of selectable entries (at the same time)
--		string maxNumSelectionsErrorText		String or function returning a string: The text showing if maximum number of selectable items was reached. Default: GetString(SI_COMBO_BOX_MAX_SELECTIONS_REACHED_ALERT)
-- 		string multiSelectionTextFormatter:optional	String SI constant or function returning a string SI constant: The text showing how many items have been selected currently, with the multiselection enabled. Default: SI_COMBO_BOX_DEFAULT_MULTISELECTION_TEXT_FORMATTER
-- 		string noSelectionText:optional			String or function returning a string: The text showing if no item is selected, with the multiselection enabled. Default: GetString(SI_COMBO_BOX_DEFAULT_NO_SELECTION_TEXT)
--		table multiSelectSubmenuSelectedArrowColor:optional		table (ZO_ColorDef) or function returning a color table with r, g, b, a keys and their values: for the submenu opening arrow > texture where multiselection is enabled and any (nested) submenu entry was selected
--		function OnSelectionBlockedCallback:optional	function(selectedItem) codeHere end: callback function called as a multi-selection item selection was blocked
-->  ===Dropdown header/title ==========================================================================================
--		string titleText:optional				String or function returning a string: Title text to show above the dropdown entries
--		string titleFont:optional				String or function returning a font string: Title text's font. Default: "ZoFontHeader3"
--		string subtitleText:optional			String or function returning a string: Sub-title text to show below the titleText and above the dropdown entries
--		string subtitleFont:optional			String or function returning a font string: Sub-Title text's font. Default: "ZoFontHeader2"
--		number titleTextAlignment:optional		Number or function returning a number: The title's vertical alignment, e.g. TEXT_ALIGN_CENTER
--		userdata customHeaderControl:optional	Userdata or function returning Userdata: A custom control thta should be shown above the dropdown entries
--		boolean headerCollapsible			 	Boolean or function returning boolean if the header control should show a collapse/expand button
--		boolean headerCollapsed			 		Boolean or function returning boolean if the header control should always be collapsed as the dropdown is opened. If this is false (default) the last state will be saved in LSM SavedVariables (per dropdown box name)
--		table headerCollapsedIcon				table or function returning a table of signature { iconTexture = "path/to/textureName.dds", iconTint=ZO_ColorDef, width=number, height=number, align=LEFT|CENTER(default)|RIGHT, offSetX=12, offSetY=-12 }: Icon shown as the header is collapsed (e.g. a magnifying glass to show you can expand it to get a search). Default value is nil. Height is capped at 32!
--		table headerCollapsedTitle				table or function returning a table of signature { text = "Click to search", color=ZO_ColorDef, font="FontNameHere", align=LEFT|CENTER(default)|RIGHT, offSetX=12, offSetY=-12 }: Title text shown as the header is collapsed (e.g. a text to show you can expand the section and see the search). Default value is nil.
-->  === Dropdown text search & filter =================================================================================
--		boolean enableFilter:optional			Boolean or function returning boolean which controls if the text search/filter editbox at the dropdown header is shown
--		function customFilterFunc				A function returning a boolean true: show item / false: hide item. Signature of function: customFilterFunc(item, filterString)
--->  === Dropdown callback functions
-- 		function preshowDropdownFn:optional 	function function(ctrl) codeHere end: to run before the dropdown shows
--		boolean automaticRefresh:optional		Boolean or function returning boolean which controls if the automatic refresh of the normal scrolllist should happen, if you click/change any entry's value. This would be needed
--												e.g. if you want the entry B to react on entry A's value (e.g. checkboxes -> enabled state). Default value is false
--		boolean automaticSubmenuRefresh:optional		Boolean or function returning boolean which controls if the automatic refresh of the submenu's scrolllist should happen, if you click/change any entry's value. This would be needed
--												e.g. if you want the entry B to react on entry A's value (e.g. checkboxes -> enabled state). Default value is false
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
	comboBoxClass.UpdateMetatable(comboBox, parent, comboBoxContainer, options) --Calls comboboxClass:Initialize

	return comboBox.m_dropdownObject
end


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--[API - Custom scrollable context menu at any control]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--Params: userdata rowControl - Returns the m_sortedItems.dataSource or m_data.dataSource or data of the rowControl, or an empty table {}
GetCustomScrollableMenuRowData = libUtil.getControlData


--Add a scrollable context (right click) menu at any control (not only a ZO_ComboBox), e.g. to any custom control of your
--addon or even any entry of a LibScrollableMenu combobox dropdown
--
--The context menu syntax is similar to the ZO_Menu usage:
--A new context menu should be using ClearCustomScrollableMenu() before it adds the first entries (to hide other contextmenus and clear the new one).
--After that use either AddCustomScrollableMenuEntry to add single entries, AddCustomScrollableMenuEntries to add a whole entries table/function
--returning a table, or even directly use AddCustomScrollableMenu and pass in the entrie/function to get entries.
--And after adding all entries, call ShowCustomScrollableMenu(controlToAnchorTo, options, specialCallbackData) to show the menu at the parentControl. If no control is provided
--moc() (control below mouse cursor) will be used
-->Attention: ClearCustomScrollableMenu() will clear and hide ALL LSM contextmenus at any time! So we cannot have an LSM context menu to show at another
--LSM context menu entry (similar to ZO_Menu).


--Adds a new entry to the context menu entries with the shown text, where the callback function is called once the entry is clicked.
--If entries is provided the entry will be a submenu having those entries. The callback can be used, if entries are passed in, too (to select a special entry and not an enry of the opening submenu).
--But usually it should be nil if entries are specified, as each entry in entries got it's own callback then.
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
--
--Example - Normal entry without submenu
--AddCustomScrollableMenuEntry("Test entry 1", function(comboBox, itemName, item, selectionChanged, oldItem) d("test entry 1 clicked") end, LibScrollableMenu.LSM_ENTRY_TYPE_NORMAL, nil, nil)
--Example - Normal entry with submenu
--AddCustomScrollableMenuEntry("Test entry 1", function(comboBox, itemName, item, selectionChanged, oldItem) d("test entry 1 clicked") end, LibScrollableMenu.LSM_ENTRY_TYPE_NORMAL, {
--	[1] = {
--		label = "Test submenu entry 1", --optional String or function returning a string. If missing: Name will be shown and used for clicked callback value
--		name = "TestValue1" --String or function returning a string if label is givenm name will be only used for the clicked callback value
--		isHeader = false, -- optional boolean or function returning a boolean Is this entry a non clickable header control with a headline text?
--		isDivider = false, -- optional boolean or function returning a boolean Is this entry a non clickable divider control without any text?
--		isCheckbox = false, -- optional boolean or function returning a boolean Is this entry a clickable checkbox control with text?
--		isRadioButton = false, -- optional boolean or function returning a boolean Is this entry a clickable radiobutton control with text?
--		isEditBox = false, -- optional boolean or function returning a boolean Is this entry a clickable editbox control with text?
--		-> --ONLY for editBox control type:	editBoxData = { table or function returning a table providing the editbox's visuals, validation options, right click handler etc.
--					hideLabel = false,							-- optional boolean or function returning a boolean Hide the label at the row
--					labelWidth = "20%",							-- optional string/number or function returning a string/number	Width of the label at the row
--					text = "Hello world",						-- optional string or function returning a string Text of the editBox, when it is shown (e.g. from SavedVariables)
--					defaultText = "Enter something...",			-- optional string or function returning a string The text to show as default text inside the editBox, if no other text was entered
--					maxInputCharacters = 5,						-- optional number or function returning a number The maximum number of characters that can be typed into the editbox
--					textType = TEXT_TYPE_NUMERIC_UNSIGNED_INT,	-- optional number or function returning a number The text type constant for the validation
--					font = "ZoFontChat",						-- optional string or function returning a string The font of the editBox
--					width = "80%",								-- optional string/number or function returning a string/number The width of the editbox
--					contextMenuCallback = function(selfEditBox) end,	-- optional function to open a contextMenu at the editbox (if right clicked)
--		->		}
--		isSlider = false, -- optional boolean or function returning a boolean Is this entry a clickable slider control with text?
--		-> --ONLY for slider control type:	sliderData = { table or function returning a table providing the slider's visuals, validation options, right click handler etc.
--					hideLabel = false,							-- optional boolean or function returning a boolean Hide the label at the row
--					labelWidth = "20%",							-- optional string/number or function returning a string/number	Width of the label at the row
--					value = 10,									-- optional number or function returning a number Value of the slider (e.g. from SavedVariables)
--					min = 0,									-- optional number or function returning a number Minimum value of the slider (e.g. from SavedVariables)
--					max = 20, 									-- optional number or function returning a number Maximum value of the slider (e.g. from SavedVariables)
--					step = 0.5,									-- optional number or function returning a number The step of the slider (e.g. from SavedVariables)
--					showValueLabel = false,						-- optional boolean or function returning a boolean Show the value label at the row, right side of the slider
--					valueLabelFont = "ZoFontWinH5",				-- optional string or function returning a string The font of the value label
--					hideValueTooltip = true,					-- optional boolean or function returning a boolean Hide the tooltip showing the actual value, min, max and tooltip of the row at the slider
--					width = "80%",								-- optional string/number or function returning a string/number The width of the slider
--					contextMenuCallback = function(selfSlider) end,	-- optional function to open a contextMenu at the slider (if right clicked)
--		->		}
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
	updateContextMenuRef()
	local options = g_contextMenu:GetOptions()

	--Additional data table was passed in? e.g. containing  gotAdditionalData.isNew = function or boolean
	local addDataType = additionalData ~= nil and type(additionalData) or nil
	local isAddDataTypeTable = (addDataType ~= nil and addDataType == "table" and true) or false

	--Determine the entryType based on text, passed in entryType, and/or additionalData table
	entryType = checkEntryType(text, entryType, additionalData, isAddDataTypeTable, options)
	entryType = entryType or entryTypeConstants.LSM_ENTRY_TYPE_NORMAL

	local generatedText

	--Generate the entryType from passed in function, or use passed in value
	local generatedEntryType = getValueOrCallback(entryType, (isAddDataTypeTable and additionalData) or options)

	--If entry is a divider
	if generatedEntryType == entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER then
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
	assert(generatedText ~= nil and generatedText ~= "" and generatedEntryType ~= nil, sfor("["..MAJOR..":AddCustomScrollableMenuEntry] text/additionalData.label/additionalData.name: String or function returning a string, got %q; entryType: number LSM_ENTRY_TYPE_* or function returning the entryType expected, got %q", tos(generatedText), tos(generatedEntryType)))
	--EntryType checks: Allowed entryType for context menu?
	assert(allowedEntryTypesForContextMenu[generatedEntryType] == true, sfor("["..MAJOR..":AddCustomScrollableMenuEntry] entryType %q is not allowed", tos(generatedEntryType)))

	--If no entry type is used which does need a callback, and no callback was given, and we did not pass in entries for a submenu: error the missing callback
	if generatedEntryType ~= nil and not entryTypesForContextMenuWithoutMandatoryCallback[generatedEntryType] and entries == nil then
		local callbackFuncType = type(callback)
		assert(callbackFuncType == "function", sfor("["..MAJOR..":AddCustomScrollableMenuEntry] Callback function expected for entryType %q, callback\'s type: %s, name: %q", tos(generatedEntryType), tos(callbackFuncType), tos(generatedText)))
	end

	--Is the text a ---------- divider line, or entryType is divider?
	local isDivider = generatedEntryType == entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER or generatedText == libDivider
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
function AddCustomScrollableSubMenuEntry(text, entries, callbackFunc)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 163, tos(text), tos(entries)) end
	return addCustomScrollableMenuEntry(text, callbackFunc, entryTypeConstants.LSM_ENTRY_TYPE_SUBMENU, entries, nil)
end

--Adds a divider line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuDivider()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 164) end
	return addCustomScrollableMenuEntry(libDivider, nil, entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER, nil, nil)
end

--Adds a header line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuHeader(text, additionalData)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 165, tos(text)) end
	return addCustomScrollableMenuEntry(text, nil, entryTypeConstants.LSM_ENTRY_TYPE_HEADER, nil, additionalData)
end

--Adds a checkbox line to the context menu entries
--callback function signature:  comboBox, itemName, item, checked, data
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuCheckbox(text, callback, checked, additionalData)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 166, tos(text), tos(checked)) end
	if checked ~= nil then
		additionalData = additionalData or {}
		additionalData.checked = checked
	end
	return addCustomScrollableMenuEntry(text, callback, entryTypeConstants.LSM_ENTRY_TYPE_CHECKBOX, nil, additionalData)
end

--Adds a radiobutton line to the context menu entries
--The buttonGroup number (function returning a number) controls which group the radiobutton belongs to (same number = 1 group)
-->If the buttonGroup is not specified it will be automatically set to 1!
-->If you want to specify the buttonGroupOnSelectionChangedCallback function(control, previousControl), add it to the additionalData table
--callback function signature:  comboBox, itemName, item, checked, data
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuRadioButton(text, callback, checked, buttonGroup, additionalData)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 189, tos(text), tos(checked), tos(buttonGroup)) end
	if checked ~= nil or buttonGroup ~= nil then
		buttonGroup = buttonGroup or 1
		additionalData = additionalData or {}
		additionalData.checked = checked
		additionalData.buttonGroup = buttonGroup
	end
	return addCustomScrollableMenuEntry(text, callback, entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON, nil, additionalData)
end

--Adds an editBox line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
-->Clicking the line does not call any callback, only changing the text in the editBox calls the callback!
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuEditBox(text, callback, editBoxData, additionalData)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 188, tos(text), tos(editBoxData)) end
	if editBoxData ~= nil then
		additionalData = additionalData or {}
		additionalData.editBoxData = editBoxData
	end
	return addCustomScrollableMenuEntry(text, callback, entryTypeConstants.LSM_ENTRY_TYPE_EDITBOX, nil, additionalData)
end

--Adds a slider line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
-->Clicking the line does not call any callback, only changing the slider value calls the callback!
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuSlider(text, callback, sliderData, additionalData)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 191, tos(text), tos(sliderData)) end
	if sliderData ~= nil then
		additionalData = additionalData or {}
		additionalData.sliderData = sliderData
	end
	return addCustomScrollableMenuEntry(text, callback, entryTypeConstants.LSM_ENTRY_TYPE_SLIDER, nil, additionalData)
end

--Set the options (visible rows max, etc.) for the scrollable context menu, or any passed in 2nd param comboBoxContainer
-->See possible options above AddCustomScrollableComboBoxDropdownMenu
function SetCustomScrollableMenuOptions(options, comboBoxContainer)
	updateContextMenuRef()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 167, tos(getControlName(comboBoxContainer)), tos(options)) end
--df(debugPrefix.."SetCustomScrollableMenuOptions - comboBoxContainer: %s, options: %s", tos(getControlName(comboBoxContainer)), tos(options))

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
--Optional table specialCallbackData can be used to register an onShowCallback or onHideCallback function for your unqiue addon name,
--so you can react on an "Show" and/or "Hide" of this particular context menu. Registered callback functions will be executed in order of register!
--You can pass in any other variable with the same table. The whole table will passed to the callback function's signature, and to the uniqueAddonName generating function.
-- The signature of the table must follow this example:
--  { addonName = string or function returning a string "UniqueString", onShowCallback = function(comboBox, openingControl, specialData) end, onHideCallback = function(comboBox, openingControl, specialData) end, anyOtherVariableToPassInToTheCallback=anyValue, ... }
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function ShowCustomScrollableMenu(controlToAnchorTo, options, specialCallbackData) --#2025_45
	updateContextMenuRef()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 171, tos(getControlName(controlToAnchorTo)), tos(options)) end
	--d("°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°")
	--df(debugPrefix.."_-_-_-_-_ShowCustomScrollableMenu - controlToAnchorTo: %s, options: %s", tos(getControlName(controlToAnchorTo)), tos(options))

	--[[
	--#2025_22 Check if the openingControl is another contextMenu -> We cannot show a contextMenu on a contextMenu
	controlToAnchorTo = controlToAnchorTo or moc()
LSM_Debug = LSM_Debug or {}
LSM_Debug.cntxtMenuControlToAnchorTo = controlToAnchorTo
	if controlToAnchorTo ~= nil and libUtil_BelongsToContextMenuCheck(controlToAnchorTo:GetOwningWindow()) then
		clearCustomScrollableMenu()
		return
	end
	]]

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

	--#2025_45 Register special callback functions for this contextMenu?
	if type(specialCallbackData) == "table" then
		local uniqueAddonName = getValueOrCallback(specialCallbackData.addonName, specialCallbackData)
		assert(uniqueAddonName ~= nil and uniqueAddonName ~= "", sfor("["..MAJOR.."-ShowCustomScrollableMenu]specialCallbackData.addonName: Unique string expected, got %q", tos(uniqueAddonName)))
		if specialCallbackData.onShowCallback ~= nil then
			local funcTypeOnShow = type(specialCallbackData.onShowCallback)
			assert(funcTypeOnShow == "function", sfor("["..MAJOR.."-ShowCustomScrollableMenu]specialCallbackData.onShowCallback: Function expected, got %q", tos(funcTypeOnShow)))
			g_contextMenu:RegisterSpecialCallback(uniqueAddonName, "onShowCallback", specialCallbackData)
		end
		if specialCallbackData.onHideCallback ~= nil then
			local funcTypeOnHide = type(specialCallbackData.onHideCallback)
			assert(funcTypeOnHide == "function", sfor("["..MAJOR.."-ShowCustomScrollableMenu]specialCallbackData.onHideCallback: Function expected, got %q", tos(funcTypeOnHide)))
			g_contextMenu:RegisterSpecialCallback(uniqueAddonName, "onHideCallback", specialCallbackData)
		end
	end

	g_contextMenu:ShowContextMenu(controlToAnchorTo)
	return true
end
local showCustomScrollableMenu = ShowCustomScrollableMenu

--Run a callback function myAddonCallbackFunc passing in the entries of the opening menu/submenu of a clicked LSM context menu item
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
--The table needs to have a number key and a LibScrollableMenu entryType constants as value, e.g. [1] = LSM_ENTRY_TYPE_CHECKBOX. Only the provided entryTypes will be selected
--from the m_sortedItems list of the (same/parent) dropdown! All others will be filtered out. Only the selected entries will be passed to the myAddonCallbackFunc's param openingMenusEntries.
--If the param filterEntryTypes is nil: All entries will be selected and passed to the myAddonCallbackFunc's param openingMenusEntries.
--
--If the boolean/function returning a boolean parameter fromParentMenu is true: The menu items of the opening (parent) menu will be returned. If false: The currently shown menu's items will be returned
---> returns boolean customCallbackFuncWasExecuted, nilable:any customCallbackFunc's return value
function RunCustomScrollableMenuItemsCallback(comboBox, item, myAddonCallbackFunc, filterEntryTypes, fromParentMenu, ...)
	updateContextMenuRef()
	local assertFuncName = "RunCustomScrollableMenuItemsCallback"
	local addonCallbackFuncType = type(myAddonCallbackFunc)
	assert(addonCallbackFuncType == "function", sfor("["..MAJOR..":"..assertFuncName.."] myAddonCallbackFunc: function expected, got %q", tos(addonCallbackFuncType)))

	local options = g_contextMenu:GetOptions()

	local gotFilterEntryTypes = filterEntryTypes ~= nil and true or false
	local filterEntryTypesTable = (gotFilterEntryTypes == true and getValueOrCallback(filterEntryTypes, options)) or nil
	local filterEntryTypesTableType = (filterEntryTypesTable ~= nil and type(filterEntryTypesTable)) or nil
	assert(gotFilterEntryTypes == false or (gotFilterEntryTypes == true and filterEntryTypesTableType == "table"), sfor("["..MAJOR..":"..assertFuncName.."] filterEntryTypes: table or function returning a table expected, got %q", tos(filterEntryTypesTableType)))

	local fromParentMenuValue
	if fromParentMenu == nil then
		fromParentMenuValue = false
	else
		fromParentMenuValue = getValueOrCallback(fromParentMenu, options)
		assert(type(fromParentMenuValue) == "boolean", sfor("["..MAJOR..":"..assertFuncName.."] fromParentMenu: boolean expected, got %q", tos(type(fromParentMenu))))
	end

--d(debugPrefix .. ""..assertFuncName.." - filterEntryTypes: " ..tos(gotFilterEntryTypes) .. ", type: " ..tos(filterEntryTypesTableType) ..", fromParentMenu: " ..tos(fromParentMenuValue))

	--Find out via comboBox and item -> What was the "opening menu" and "how do I get openingMenu m_sortedItems"?
	--comboBox would be the comboBox or dropdown of the context menu -> if RunCustomScrollableMenuCheckboxCallback was called from the callback of a contex menu entry
	--item could have a control or something like that from where we can get the owner and then check if the owner got a openingControl or similar?
	local sortedItems = getComboBoxsSortedItems(comboBox, fromParentMenuValue, false)
	if ZO_IsTableEmpty(sortedItems) then
--d("<sortedItems are empty!")
		return false, nil
	end

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

--API to refresh a dropdown's submenu or mainmenu or an entry control visually (e.g. if you click an entry, called from the callback function)
-->Parameter updateMode can be left empty, then the system will automatically determine if a submenu exists and the item belongs to that, and refresh that,
--or it will update the mainmenu if it exists.
--Or you specify one of the following updateModes:
--->LSM_UPDATE_MODE_MAINMENU	Only update the mainmenu visually
--->LSM_UPDATE_MODE_SUBMENU		Only update the submenu visually
--->LSM_UPDATE_MODE_BOTH		Update the submenu and the mainmenu, both
---Parameter comboBox is optional
local function LSM_RefreshLibScrollableMenu(mocCtrl, updateMode, comboBox) -- #2025_58
	--Update the visible LSM dropdown's submenu now so the disabled state and checkbox values commit again
	if mocCtrl == nil then mocCtrl = moc() end
--d("[RefreshCustomScrollableMenu] - moc: " .. getControlName(mocCtrl) .. "; updateMode: " ..tos(updateMode) .. "; comboBox: " .. tos(comboBox))
	if mocCtrl ~= nil then
		if comboBox == nil then
			comboBox = (mocCtrl.m_comboBox or (mocCtrl.m_owner and mocCtrl.m_owner.m_comboBox)) or nil
		end
		if comboBox == nil then return end
--d(">[LSM]found combobox")
		--Main Menu
		if updateMode == LSM_UPDATE_MODE_BOTH or updateMode == LSM_UPDATE_MODE_MAINMENU then
			--local owningWindow = mocCtrl.GetOwningWindow ~= nil and mocCtrl:GetOwningWindow() or nil
			--local mainMenuDropdown = (owningWindow and owningWindow.m_dropdownObject) or nil
			local mainMenuComboBox = (mocCtrl.m_owner ~= nil and mocCtrl.m_owner.m_comboBox) or nil
			local mainMenuDropdown = (mainMenuComboBox ~= nil and mainMenuComboBox.m_dropdownObject) or nil
			if mainMenuDropdown ~= nil then
				if mainMenuComboBox:IsDropdownVisible() == true then
					mainMenuDropdown:SubmenuOrCurrentListRefresh(mocCtrl, true, true)
				end
			end
		end

		--Submenu
		if updateMode == LSM_UPDATE_MODE_BOTH or updateMode == LSM_UPDATE_MODE_SUBMENU then
			if mocCtrl.m_dropdownObject and comboBox and comboBox:IsDropdownVisible() == true then
--d(">[LSM[refresh submenu - TRY")
				mocCtrl.m_dropdownObject:SubmenuOrCurrentListRefresh(mocCtrl, true, false)
			end
		end
	end
end
RefreshCustomScrollableMenu = LSM_RefreshLibScrollableMenu

--Returns boolean true/false if any LSM context menu is currently showing it's dropdown
local function LSM_IsContextMenuCurrentlyShown()
	g_contextMenu = updateContextMenuRef()
	if g_contextMenu == nil then return false end
	return g_contextMenu:IsDropdownVisible()
end
IsCustomScrollableContextMenuShown = LSM_IsContextMenuCurrentlyShown --#2025_59

local function LSM_IsLSMCurrentlyShown()
	local LSM_menus = lib._objects
	if ZO_IsTableEmpty(LSM_menus) then return false end
	for _, LSM_menu in ipairs(LSM_menus) do
		if LSM_menu ~= nil and LSM_menu.IsDropdownVisible then
			if LSM_menu:IsDropdownVisible() then return true end
		end
	end
	return LSM_IsContextMenuCurrentlyShown()
end
IsCustomScrollableMenuShown = LSM_IsLSMCurrentlyShown --#2025_60

-- API to show a context menu at a buttonGroup where you can (un)check/invert all buttons in a group:
-- Select all, Unselect All, Invert all.
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
			entryType = entryTypeConstants.LSM_ENTRY_TYPE_NORMAL,
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
			entryType = entryTypeConstants.LSM_ENTRY_TYPE_NORMAL,
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
			entryType = entryTypeConstants.LSM_ENTRY_TYPE_NORMAL,
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


--======================================================================================================================
--[[ Other API functions available:

--]Defined in dropdown_class.lua[--

--#2025_57 Recursively check if any icon on the current submenu's path, up to the main menu (via the parentMenus), needs an update.
--Manual call via API function UpdateCustomScrollableMenuEntryIconPath (e.g. from any callback of an entry) or automatic call if submenuEntry.updateIconPath == true
--UpdateCustomScrollableMenuEntryIconPath(comboBox, control, data)

--#2025_44 Recursively check if any entry on the current submenu's path, up to the main menu (via the parentMenus), needs an update.
--Optional checkFunc must return a boolean true [default return value] (refresh now) or false (no refresh needed), and uses the signature:
--> checkFunc(comboBox, control, data)
--Manual call via API function UpdateCustomScrollableMenuEntryPath (e.g. from any callback of an entry) or automatic call if submenuEntry.updateEntryPath == true
--UpdateCustomScrollableMenuEntryPath(comboBox, control, data, checkFunc, checkFuncParam1, checkFuncParam2, ...)
]]
