# LibScrollableMenu

<center><img src="preview.png" alt="Screenshot" width=300px/></center>

The purpose of this plugin is to allow for creation of custom scrollable menus.

Originally developed in Kyoma's Titlizer.  Now used in ImprovedTitleizer.

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
__Check file LSM_test.lua for example code and menus + submenus + callbacks!__

Create a comboBox from virtual template e.g.:
```local comboBox = WINDOW_MANAGER:CreateControlFromVirtual("AF_FilterBar" .. myName .. "DropdownFilter", parentControl, "ZO_ComboBox")```


Add the scrollable dropdown via LibScrollableMenu:
```
		--For possible options check file LibScrollableMenu.lua, above API function AddCustomScrollableComboBoxDropdownMenu
		local scrollableDropdownObject = AddCustomScrollableComboBoxDropdownMenu(testTLC, comboBox, options)
```

You can add submenus and even the submenus are scrollable AND provide submenus again (nested!) -> Noice
-> btw: Technically the submenus are scrollable comoboxes' dropdowns too, only hiding their combobox controls etc. around them ;)


### In order to add items to the combobox - Use the comboBox:AddItems(table) function
Just use (comboBox = comboBox.m_comboBox)
```comboBox:AddItems(tableWithEntries)```

tableWithEntries can contain entries for normal non-submenu lines:
```
local tableWithEntries = {}

                    tableWithEntries [#tableWithEntries +1] = {
                        name            = "My non-submenu entry",
                        callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
                           --do what neesd to be done once the entry was selected
                        end,
                        tooltip         = "Tooltip text",
                    }


```

or lines with submenus, where you specify "entries" as a tabl which got the same format as non-submenu entries again (see above).
```
local submenuEntries = {
                    submenuEntries [#submenuEntries +1] = {
                        name            = "My submenu sub-entry 1",
                        --label             = "My submenu sub-entry 1", --shown text onle, name is still used for the selected data
                        callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
                           --do what neesd to be done once the entry was selected
                        end,
                        tooltip         = "Tooltip text",
                    }

                    submenuEntries [#submenuEntries  +1] = {
                        name            = "My submenu sub-entry 2",
                        callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
                           --do what neesd to be done once the entry was selected
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


## Version 1.9 added context menus at any control

### Syntax
```
Entry types:
LSM_ENTRY_TYPE_NORMAL 
LSM_ENTRY_TYPE_DIVIDER 
LSM_ENTRY_TYPE_HEADER
LSM_ENTRY_TYPE_CHECKBOX 


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
--}, nil)
function AddCustomScrollableMenuEntry(text, callback, entryType, entries, isNew)

--Adds an entry having a submenu (or maybe nested submenues) in the entries table
--> See examples for the table "entries" values above AddCustomScrollableMenuEntry
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableSubMenuEntry(text, entries)

--Adds a divider line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableMenuDivider()

--Set the options (visible rows max, etc.) for the scrollable context menu
-->See possible options above AddCustomScrollableComboBoxDropdownMenu
function SetCustomScrollableMenuOptions(options, comboBoxContainer)

--Hide the custom scrollable context menu and clear it's entries, clear internal variables, mouse clicks etc.
function ClearCustomScrollableMenu()

--Pass in a table with predefined context menu entries and let them all be added in order of the table's number key
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableMenuEntries(contextMenuEntries)

--Populate a new scrollable context menu with the defined entries table.
--Existing context menu entries will be reset, because ClearCustomScrollableMenu will be called!
--You can add more entries later, prior to showing, via AddCustomScrollableMenuEntry / AddCustomScrollableMenuEntries functions too
function AddCustomScrollableMenu(entries, options)

--Show the custom scrollable context menu now at the control controlToAnchorTo, using optional options.
--If controlToAnchorTo is nil it will be anchored to the current control's position below the mouse, like ZO_Menu does
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function ShowCustomScrollableMenu(controlToAnchorTo, options)
```
