# LibScrollableMenu

<center><img src="preview.png" alt="Screenshot" width=300px/></center>

The purpose of this plugin is to allow for creation of custom scrollable menus.

Originally developed in Kyoma's Titlizer.  Now used in ImprovedTitleizer, merTochbug, AdvancedFilters, and other addons...

GitHub: https://github.com/tomstock1337/eso-LibScrollableMenu

ESOUI.com (AddOns): https://www.esoui.com/downloads/fileinfo.php?id=3546

With update P40, API101040 ~2023-09-20 the ZO_ComboBox was changed into a ZO_ScrollableComboBox directly.
Some API functions beginning with ZO_ScrollableComboBox* changed to ZO_ComboBox* that way.
The main change was that ZO_Menu is not used any longer for the dropdown entries of ZO_ComboBox and thus
entries cannot be added/manipulated via other libraries about ZO_Menu, like the common lirary LibCustomMenu,
any longer!
That's why LibScrollableMenu got implemented additional features that LibCustomMenu provided, like non clickable
header rows, label texts for the entries (used instead of normal entry.name).

Here is a brief "howto change addons using LibCustomMenu and overwriting ZO_ComboBox:AddMenuItems" to LibScrollableMenu instead:

## If you only want some non-submenu entries in the combobox:
Do not override :AddMenuItems() and just do it the normal way. Your combobox will be scrollable by default now and will work well.

## If you still want to use submenus: Instructions how to change your ZO_ComboBox to a scrollable list with submenus (scrollable too!)
Check file LSM_test.lua for example code and menus + submenus + callbacks!

Create a comboBox from virtual template e.g.:

```lua
local comboBox = WINDOW_MANAGER:CreateControlFromVirtual("AF_FilterBar" .. myName .. "DropdownFilter", parentControl, "ZO_ComboBox")
```


Add the scrollable helper via LibScrollableMenu:
```lua
--Define your options for the scrollHelper here
-->For all possible option values check API function "AddCustomScrollableComboBoxDropdownMenu" description at file
-->LibScrollableMenu.lua
local options = { visibleRowsDropdown = 10, visibleRowsSubmenu = 5, sortEntries=function() return false end, }
--Create a scrollHelper then and reference your ZO_ComboBox, plus pass in the options
--After that build your menu entres (see below) and add them to the combobox via :AddItems(comboBoxMenuEntries)
local scrollHelper = AddCustomScrollableComboBoxDropdownMenu(testTLC, comboBox, options)
```

The scroll helper enables a scrollable comboxbox then, without multi selection!
You can add submenus and even the submenus are scrollable AND provide submenus again (nested!) -> Noice
-> btw: Technically the submenus are scrollable comoboxes too, only hiding their dropdown controls etc. around them ;)


### In order to add items to the combobox - Use the comboBox:AddItems(table) function
Just use (comboBox = dropdown.m_comboBox)
```comboBox:AddItems(tableWithEntries)```

tableWithEntries can contain entries for normal non-submenu lines:
```lua
local tableWithEntries = {}

tableWithEntries [#tableWithEntries +1] = {
    name            = "My non-submenu entry",
    callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
        --do what needs to be done once the entry was selected
    end,
    tooltip         = "Tooltip text",
}
```

or lines with submenus, where you specify "entries" as a tabl which got the same format as non-submenu entries again (see above).
```lua
local submenuEntries = {
  submenuEntries [#submenuEntries +1] = {
      name            = "My submenu sub-entry 1",
      --label             = "My submenu sub-entry 1",
      callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
          --do what needs to be done once the entry was selected
      end,
      tooltip         = "Tooltip text",
  }

  submenuEntries [#submenuEntries  +1] = {
      name            = "My submenu sub-entry 2",
      callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
          --do what needs to be done once the entry was selected
      end,
      tooltip         = "Tooltip text",
  }
}

tableWithEntries [#tableWithEntries +1] = {
    name            = "My submenu entry",
    entries         = submenuEntries,
    tooltip         = "Tooltip text",
}
```

From esoui.com description:
Add a scrolhelper (dropdown scrollable) to a ZO_ComboBox:
API syntax:
```
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
```

Added new API functions to create the scrollable (nested) context menus at any control,like LibCustomMenu does.
API syntax:
```
Entry types:
LSM_ENTRY_TYPE_NORMAL
LSM_ENTRY_TYPE_DIVIDER
LSM_ENTRY_TYPE_HEADER
LSM_ENTRY_TYPE_SUBMENU
LSM_ENTRY_TYPE_CHECKBOX
LSM_ENTRY_TYPE_BUTTON
LSM_ENTRY_TYPE_RADIOBUTTON
LSM_ENTRY_TYPE_EDITBOX
LSM_ENTRY_TYPE_SLIDER

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


--Adds an entry having a submenu (or maybe nested submenues) in the entries table/entries function whch returns a table
--> See examples for the table "entries" values above AddCustomScrollableMenuEntry
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableSubMenuEntry(text, entries, callbackFunc)


--Adds a divider line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuDivider()


--Adds a header line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuHeader(text, additionalData)


--Adds a checkbox line to the context menu entries
--callback function signature:  comboBox, itemName, item, checked, data
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuCheckbox(text, callback, checked, additionalData)


--Adds a radiobutton line to the context menu entries
--The buttonGroup number (function returning a number) controls which group the radiobutton belongs to (same number = 1 group)
-->If the buttonGroup is not specified it will be automatically set to 1!
-->If you want to specify the buttonGroupOnSelectionChangedCallback function(control, previousControl), add it to the additionalData table
--callback function signature:  comboBox, itemName, item, checked, data
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuRadioButton(text, callback, checked, buttonGroup, additionalData)


--Adds an editBox line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
-->Clicking the line does not call any callback, only changing the text in the editBox calls the callback!
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuEditBox(text, callback, editBoxData, additionalData)


--Adds a slider line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
-->Clicking the line does not call any callback, only changing the slider value calls the callback!
---> returns nilable:number indexOfNewAddedEntry, nilable:table newEntryData
function AddCustomScrollableMenuSlider(text, callback, sliderData, additionalData)


--Pass in a table/function returning a table with predefined context menu entries and let them all be added in order of the table's number key
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
---> returns boolean allWereAdded, nilable:table indicesOfNewAddedEntries, nilable:table newEntriesData
function AddCustomScrollableMenuEntries(contextMenuEntries)


--Populate a new scrollable context menu with the defined entries table/a functinon returning the entries.
--Existing context menu entries will be reset, because ClearCustomScrollableMenu will be called!
--You can add more entries later, prior to showing, via AddCustomScrollableMenuEntry / AddCustomScrollableMenuEntries functions too
---> returns boolean allWereAdded, nilable:table indicesOfNewAddedEntries, nilable:table newEntriesData
function AddCustomScrollableMenu(entries, options)


--Set the options (visible rows max, etc.) for the scrollable context menu, or any passed in 2nd param comboBoxContainer
-->See possible options above AddCustomScrollableComboBoxDropdownMenu
function SetCustomScrollableMenuOptions(options, comboBoxContainer)


--Show the custom scrollable context menu now at the control controlToAnchorTo, using optional options.
--If controlToAnchorTo is nil it will be anchored to the current control's position below the mouse, like ZO_Menu does
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function ShowCustomScrollableMenu(controlToAnchorTo, options)


--Hide the custom scrollable context menu and clear it's entries, clear internal variables, mouse clicks etc.
function ClearCustomScrollableMenu()


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
--The table needs to have a number key and a LibScrollableMenu entryType constants as value, e.g. [1] = LSM_ENTRY_TYPE_CHECKBOX. Only the provided entryTypes will be selected
--from the m_sortedItems list of the (same/parent) dropdown! All others will be filtered out. Only the selected entries will be passed to the myAddonCallbackFunc's param openingMenusEntries.
--If the param filterEntryTypes is nil: All entries will be selected and passed to the myAddonCallbackFunc's param openingMenusEntries.
--
--If the boolean/function returning a boolean parameter fromParentMenu is true: The menu items of the opening (parent) menu will be returned. If false: The currently shown menu's items will be returned
---> returns boolean customCallbackFuncWasExecuted, nilable:any customCallbackFunc's return value
function RunCustomScrollableMenuItemsCallback(comboBox, item, myAddonCallbackFunc, filterEntryTypes, fromParentMenu, ...)


---Function to return the data of a LSM scrollList row. Params: userdata rowControl
-->Returns the m_sortedItems.dataSource or m_data.dataSource or data of the rowControl, or an empty table {}
function GetCustomScrollableMenuRowData(rowControl)


-- API to set all buttons in a group based on Select all, Unselect All, Invert all.
-->Used in "checkbox" buttonGroup to show the default context menu (if no custom contextmenu was provided!) at a control which provides the
-->"Select all", "Deselect all" and "Invert selection" entries
function LibScrollableMenu.ButtonGroupDefaultContextMenu(comboBox, control, data)
```
