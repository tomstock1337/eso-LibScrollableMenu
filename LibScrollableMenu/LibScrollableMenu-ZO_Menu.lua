--------------------------------------------------------------------
-- LibScrollableMenu - Support for ZO_Menu (including LibCustomMenu)

local lib = LibScrollableMenu
if lib == nil then return end

------------------------------------------------------------------------------------------------------------------------
-- Overview of what the ZO_Menu & LibCustomMenu integration does
------------------------------------------------------------------------------------------------------------------------
--[[
	ZO_Menu is the ZOs control used to show context menus or context-menu like menus (at the chat text input, to show last entered values e.g., or at the
	player inventory to show a list of possible actions like "Link to chat" etc.) at controls.
	Vanilla code and/or addons add entries via AddMenuItem (or LibCustomMenu uses AddCustomMenuItem and AddCustomSubMenuItem -> both call AddMenuItem internally in the end!)
	and show them via the ShowMenu(ownerControl) function. ClearMenu() hides the menu again and clears internal values.

	AddMenuItem will increase an index ZO_Menu.currentIndex by 1 and add the entries to ZO_Menu.items[index] table.
	ShowMenu does read all entries in ZO_Menu.items from 1 to last and creates menu item controls, anchored to each other (below each other).
	ShowMenu will be called by each addon adding items to a context menu, e.g. adding entries to a player inventory row! That means that it can be called
	multiple times after another to draw a complete menu (always starting at 1 and recreating all entries again and again :-( ). This makes it hard to
	properly capture all cases of vanilla dn addon added context menu entries -> transfer them to LibScrollableMenu properly.

	What does LibScrollableMenu do now?
	It hooks into the ZO_Menu functions like AddMenuItem, and LibCustomMenu AddMenuItem and AddSubmenuItem functions, to build an internal table
	LibScrollableMenu.ZO_MenuData -> with mapped data of the ZO_Menu.items -> mapped to the LibScrollableMenu context menu entry format.
	At ShowMenu it basically does the same like ZO_Menu did and loops all LibScrollableMenu.ZO_MenuData entries and shows them at the scrollable list menu of LSM.
	ZO_Menu will then be supressed/hidden (items in ZO_Menu.items will be kept until ClearMenu is called by the game itsself or until the LSM context menu closes, then
	ClearMenu will be called too).
	That way LibCustomMenu and ZO_Menu are still able to add entries to ZO_Menu, but LibScrollableMenu will read those, map them to LSM entries, suppress the ZO_Menu
	showing them and shows them via LSM UI then in the end, which makes the menus scrollable, searchable etc.

	[Where is done what?]
	Function code to map the ZO_Menu/LCM items to LSM is here in this lua file:
	->See function lib.LoadZO_MenuHooks()

	Additional hook code is in file LibScrollableMenu:
	-> See function onAddonLoaded(event, name) -> calling lib.LoadZO_MenuHooks() of this file here
	-> Additional hooks to LSM context menus see function contextMenuClass:ZO_MenuHooks()

	!Many thanks to votan for creating LibCustomMenu and providing API functions for LSM which we can hook to get the menu and submenu data more easily!
]]

----Variables etc.

--local ZOs references
local tos = tostring
local sfor = string.format

--Local libray references
local MAJOR = lib.name
local scrollListRowTypes = lib.scrollListRowTypes
local libDivider = lib.DIVIDER

local sv = lib.SV

--Entry type variables
local LSM_ENTRY_TYPE_NORMAL = 		scrollListRowTypes["LSM_ENTRY_TYPE_NORMAL"]
local LSM_ENTRY_TYPE_DIVIDER = 		scrollListRowTypes["LSM_ENTRY_TYPE_DIVIDER"]
local LSM_ENTRY_TYPE_HEADER = 		scrollListRowTypes["LSM_ENTRY_TYPE_HEADER"]
local LSM_ENTRY_TYPE_CHECKBOX = 	scrollListRowTypes["LSM_ENTRY_TYPE_CHECKBOX"]
local LSM_ENTRY_TYPE_SUBMENU = 		scrollListRowTypes["LSM_ENTRY_TYPE_SUBMENU"]
local LSM_ENTRY_TYPE_BUTTON = 		scrollListRowTypes["LSM_ENTRY_TYPE_BUTTON"]
local LSM_ENTRY_TYPE_RADIOBUTTON = 	scrollListRowTypes["LSM_ENTRY_TYPE_RADIOBUTTON"]


--LibCustomMenu is loaded? If not these hooks will only take care of vanilla ZO_Menu
local libCustomMenuIsLoaded = LibCustomMenu ~= nil

--Mapping between LibCustomMenu and LibScrollableMenu's entry types at the context menus
local mapLCMItemtypeToLSMEntryType
if libCustomMenuIsLoaded then
	mapLCMItemtypeToLSMEntryType = {
		[MENU_ADD_OPTION_LABEL]		= LSM_ENTRY_TYPE_NORMAL,
		[MENU_ADD_OPTION_CHECKBOX]	= LSM_ENTRY_TYPE_CHECKBOX,
		[MENU_ADD_OPTION_HEADER]	= LSM_ENTRY_TYPE_HEADER,
	}
end


local comboBoxDefaults = lib.comboBoxDefaults


--local function references
local getValueOrCallback = lib.GetValueOrCallback
local clearCustomScrollableMenu = ClearCustomScrollableMenu
local getControlName = lib.GetControlName


--ZOs controls
local zoListDialog = ZO_ListDialog1


--[[
--Patterns for string search: ZO scroll list rowControl names
local listRowsAllowedPatternsForContextMenu = {
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
]]

--Add controls here (or parent controls, or owningWindow controls) which are allowed for ZO_Menu -> LSM mapping.
-->LSM will be shown and used for them -> LibScrollableMenu does not hook into it
local whitelistedControlNamesForZO_MenuReplacement = {
	--Player Inventory
	["ZO_PlayerInventory"] = true,
	--Player bank
	--House bank
	--Guild bank
	--Companion
	--Crafting tables
}


--Add controls here (or parent controls, or owningWindow controls) which got blacklisted for ZO_Menu -> LSM mapping.
-->ZO_Menu will be shown and used normally for them and LibScrollableMenu does not hook into it
local blacklistedControlsForZO_MenuReplacement = {
	--Chat editbox
	--["ZO_ChatWindowTextEntryEditBox"] = true,
}

--The table with the already registered LSM context menu hooks
-->See API function lib.RegisterZO_MenuContextMenuReplacement below
local registeredCustomScrollableContextMenus        = {}
lib.registeredCustomScrollableContextMenus = registeredCustomScrollableContextMenus



------------------------------------------------------------------------------------------------------------------------
-- local variables for the ZO_Menu mapping
------------------------------------------------------------------------------------------------------------------------
--Counter for the ZO_Menu.items -> mapped to LSM entry already
local LSMAlreadyMappedItemNum = 0
--The last added (previous) index at ZO_Menu.items
local lastAddedZO_MenuItemsIndex = 0

--Table of last created (theoretically, not shown!) ZO_Menu items -> Which LSM will then show instead on next ShowMenu() call
lib.ZO_MenuData = {} --Will be reset in LibScrollableMenu.lua, class method contextMenuClass:ZO_MenuHooks()
lib.ZO_MenuData_CurrentIndex = 0
--Preventer variable to keep the current lib.ZO_MenuData entries (e.g. if ClearMenu() is called from ShowMenu() function)
lib.preventClearCustomScrollableMenuToClearZO_MenuData = false
--Explicitly call ClearMenu() of ZO_Menu if ClearCustomScrollableMenu() ( -> g_contextMenu:ClearItems()) is called?
--> See function contextMenuClass:ZO_MenuHooks()
lib.callZO_MenuClearMenuOnClearCustomScrollableMenu = false
--Checkbox Controls of ZO_Menu where we need to monitor "the next" change of the state, so we can update the LSMentry in
--lib.ZO_MenuData properly
lib.ZO_Menu_cBoxControlsToMonitor = {}
--Preventer variable with the name and callback and itemtype (and optional isSubmenu boolean) for AddMenuItem function hook
--> Prevents that if LibCustomMenu is enabled the function calls to AddCustom*MenuItem, which internally call AddMenuItem again,
--> will add duplicate data in the end
lib.LCMLastAddedMenuItem                 = {}
local LCMLastAddedMenuItem = lib.LCMLastAddedMenuItem



------------------------------------------------------------------------------------------------------------------------
-- local variables for the ZO_Menu hooks
------------------------------------------------------------------------------------------------------------------------
local ZO_Menu_showMenuHooked = false
local LCM_AddItemFunctionsHooked = false


------------------------------------------------------------------------------------------------------------------------
--Local helper functions
------------------------------------------------------------------------------------------------------------------------

--Is the control allowed -> Means: Does this control use LSM for ZO_Menu/LCM entries?
--> LSM will be used normally then
local function isAllowedControl(owner)
	if owner ~= nil then
		local ownerName = getControlName(owner)
		if whitelistedControlNamesForZO_MenuReplacement[ownerName] then
			return true, ownerName
		end
		local parent = owner.GetParent and owner:GetParent()
		if parent ~= nil then
			ownerName = getControlName(parent)
			if whitelistedControlNamesForZO_MenuReplacement[ownerName] then
				return true, ownerName
			end
			local owningWindow = owner.GetOwningWindow and owner:GetOwningWindow()
			if owningWindow ~= nil then
				ownerName = getControlName(owningWindow)
				if whitelistedControlNamesForZO_MenuReplacement[ownerName] then
					return true, ownerName
				end
			end
		end
	end
	return false, nil
end

--Is the control blacklisted -> Means: Does this control prevent the LSM usage for ZO_Menu/LCM entries?
--> ZO_Menu will be used normally then
local function isBlacklistedControl(owner)
	if owner ~= nil then
		if blacklistedControlsForZO_MenuReplacement[owner] then
			return true, getControlName(owner)
		end
		local parent = owner.GetParent and owner:GetParent()
		if parent ~= nil then
			if blacklistedControlsForZO_MenuReplacement[parent] then
				return true, getControlName(parent)
			end
			local owningWindow = owner.GetOwningWindow and owner:GetOwningWindow()
			if owningWindow ~= nil and blacklistedControlsForZO_MenuReplacement[owningWindow] then
				return true, getControlName(owningWindow)
			end
		end
	end
	return false, nil
end

--[[ Currently disabled as ALL rows should try to replace the context menu entries
local function isSupportedInventoryRowPattern(ownerCtrl, controlName)
	--return false --todo: for debugging remove again to enable LSM at inventory row context menus again

	controlName = controlName or (ownerCtrl ~= nil and ownerCtrl.GetName and ownerCtrl:GetName())
    if not controlName then return false, nil end
    if not listRowsAllowedPatternsForContextMenu then return false, nil end
    for _, patternToCheck in ipairs(listRowsAllowedPatternsForContextMenu) do
        if controlName:find(patternToCheck) ~= nil then
            return true, patternToCheck
        end
    end
    return false, nil
end
]]

--Reset internal variables of LSM so ZO_Menu/LCM is used normally, or LSM is not doing any extra steps
local function resetZO_MenuClearVariables()
	lib.callZO_MenuClearMenuOnClearCustomScrollableMenu = false
	lib.preventClearCustomScrollableMenuToClearZO_MenuData = false
end

--Hide currently shown context menus, LSM and ZO_Menu/LSM
local function clearZO_MenuAndLSM()
	ZO_Menus:SetHidden(false)
	ClearMenu()
	clearCustomScrollableMenu()
end

--Hide the ZO_Menu controls etc. but keep the index, owner and anchors etc. as they are
-->ZO_Menu.items should be valid then for other addons to read them until real ClearMenu() is called?
local function customClearMenu()
	ZO_Menu_SetSelectedIndex(nil)

	ZO_Menu:ClearAnchors()
	ZO_Menu:SetDimensions(0, 0)
	ZO_Menu.width = 0
	ZO_Menu.height = 0
	ZO_Menu.spacing = 0
	ZO_Menu.menuPad = 8
	ZO_Menu:SetHidden(true)
	ZO_MenuHighlight:SetHidden(true)

	--Hide the ZO_Menu TLC now -> to hide that small [ ] menu TLC near the right clicked mouse position
	ZO_Menus:SetHidden(true)
end

local function clearInternalZO_MenuToLSMMappingData()
	if lib.debugLCM then d("["..MAJOR.."]clearInternalZO_MenuToLSMMappingData") end
	LCMLastAddedMenuItem              = {}
	lastAddedZO_MenuItemsIndex        = 0
	lib.ZO_Menu_cBoxControlsToMonitor = {}
end



------------------------------------------------------------------------------------------------------------------------
--Local API helper functions
------------------------------------------------------------------------------------------------------------------------
--Is any custom scrollable ZO_Menu replacement context menu registered?
local function isAnyCustomScrollableZO_MenuContextMenuRegistered()
	local isAnyLSMContextMenuReplacementRegistered = not ZO_IsTableEmpty(registeredCustomScrollableContextMenus)
	if lib.debugLCM then d("["..MAJOR.."]isAnyCustomScrollableZO_MenuContextMenuRegistered: " .. tos(isAnyLSMContextMenuReplacementRegistered)) end
	return isAnyLSMContextMenuReplacementRegistered
end
lib.IsAnyCustomScrollableZO_MenuContextMenuRegistered = isAnyCustomScrollableZO_MenuContextMenuRegistered



------------------------------------------------------------------------------------------------------------------------
--Local Show context menu helper functions
------------------------------------------------------------------------------------------------------------------------
local function getOwnerControlSavedVars(ownerName, svTableName)
	--todo SavedVariables reading with "ownerName" as key and subtable data visibleRows and visibleRowsSubmenu
	local visibleRows, visibleRowsSubmenu
	sv = lib.SV
	local savedContextMenuVisibleRows = sv ~= nil and sv[svTableName]
	if ownerName ~= nil and savedContextMenuVisibleRows ~= nil then
		local savedDataPerOwnerName = savedContextMenuVisibleRows[ownerName]
		if savedDataPerOwnerName ~= nil then
			visibleRows			= savedDataPerOwnerName["visibleRows"]
			visibleRowsSubmenu	= savedDataPerOwnerName["visibleRowsSubmenu"]
		end
	end
	visibleRows = visibleRows or comboBoxDefaults.visibleRows --default value: 10
	visibleRowsSubmenu = visibleRowsSubmenu or comboBoxDefaults.visibleRowsSubmenu --default value: 10

	return visibleRows, visibleRowsSubmenu
end

local function getVisibleRowsByOwnerControlSettings(owner, ownerName)
	local isZOListDialogHidden = zoListDialog:IsHidden()
	if ownerName == nil or ownerName == "" then
		return comboBoxDefaults.visibleRows, comboBoxDefaults.visibleRowsSubmenu, isZOListDialogHidden
	end

	--Read the SavedVariables: If the ownerName was saved with own set visible rows, use that
	local visibleRows, visibleRowsSubmenu = getOwnerControlSavedVars(ownerName, "contextMenuVisibleRows")
	return visibleRows, visibleRowsSubmenu, isZOListDialogHidden
end

local function showLSMReplacmentContextMenuForZO_MenuNow(owner, ownerName)
	--Show the LSM context menu now with the mapped and added ZO_Menu entries, in LSM format.
	-->ShowCustomScrollableMenu will show all previously added entries

	local visibleRows, visibleRowsSubmenu, isZOListDialogHidden = getVisibleRowsByOwnerControlSettings(owner, ownerName)

	if lib.debugLCM then d("< ~~ SHOWING LSM! ShowCustomScrollableMenu - isZOListDialogHidden: " ..tos(isZOListDialogHidden) .."; visibleRows: " ..tos(visibleRows) .."; visibleRowsSubmenu: " ..tos(visibleRowsSubmenu) .." ~~~") end
	ShowCustomScrollableMenu(owner, {
		sortEntries = 			false,
		visibleRowsDropdown = 	visibleRows,
		visibleRowsSubmenu = 	visibleRowsSubmenu,
	})
end



------------------------------------------------------------------------------------------------------------------------
--Load the ZO_Menu hooks
------------------------------------------------------------------------------------------------------------------------
function lib.LoadZO_MenuHooks()
	--Map the LibCustomMenu and normal ZO_Menu entries data to LibScrollableMenu entries data

	--======================================================================================================================
	--Function to map the ZO_menu items to LSM entryType context menu items
	-->Those will be called from function AddMenuItem, and then calls function storeZO_MenuItemDataForLSM and stores in table lib.ZO_MenuData[menuIndex]
	--======================================================================================================================
	local function mapZO_MenuItemToLSMEntry(ZO_MenuItemData, menuIndex, isBuildingSubmenu)
		LSMAlreadyMappedItemNum = LSMAlreadyMappedItemNum + 1
		if lib.debugLCM then
			if isBuildingSubmenu == true then
				d("-_-_-_-_- RECURSIVE CALL -_-_-_-_-")
			end
			d("[LSM]mapZO_MenuItemToLSMEntry-itemAddedNum: " .. tos(LSMAlreadyMappedItemNum) ..", isBuildingSubmenu: " .. tos(isBuildingSubmenu))
		end
		isBuildingSubmenu = isBuildingSubmenu or false
		local lsmEntry
		local ZO_Menu_ItemCtrl = ZO_MenuItemData.item --~= nil and ZO_ShallowTableCopy(ZO_MenuItemData.item)
		if ZO_Menu_ItemCtrl ~= nil then

			local entryName
			local callbackFunc
			local checked
			local isChecked = false
			local isZO_MenuEntryHavingCheckbox = (ZO_MenuItemData.checkbox ~= nil and true) or false
			--Is the item a checkbox control? Attention: ZO_Menu entries openign a submenu via LibCustomMenu sometimes got the ZO_MenuItemData.checkbox set -> somehow used internally in LCM to provide the submenu's arrow texture?
			local isCheckbox = ((ZO_Menu_ItemCtrl.itemType == MENU_ADD_OPTION_CHECKBOX or isZO_MenuEntryHavingCheckbox) and true) or false
			if isZO_MenuEntryHavingCheckbox == true then
				--Get ZO_Menu's checkbox's current checked state
				isChecked = ZO_CheckButton_IsChecked(ZO_MenuItemData.checkbox)
			end
			local isDivider = false
			local isHeader = false
			local entryType = (isCheckbox == true and LSM_ENTRY_TYPE_CHECKBOX) or LSM_ENTRY_TYPE_NORMAL
			local hasSubmenu = false
			local submenuEntries
			local isNew = nil

			local myfont
			local normalColor
			local highlightColor
			local disabledColor
			local itemYPad
			local horizontalAlignment

			--Tooltips
			local tooltip
			local customTooltip --LSM uses entry.customTooltip function to show any tooltip that was added for LCM
			local enabled = true

			--Flag for "Read values directly from a ZO_Menu item too"
			local processVanillaZO_MenuItem = true


			--Is the tooltip a function, or a string?
			local tooltipData = ZO_Menu_ItemCtrl.tooltip
			local tooltipIsFunction = type(tooltipData) == "function"

			--Is LibCustomMenu loaded?
			if libCustomMenuIsLoaded == true then
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
				--Normal entry?
				local entryData = ZO_Menu_ItemCtrl.entryData
				--Is this an entry opening a submenu?
				local submenuData = ZO_Menu_ItemCtrl.submenuData
				local submenuItems = (submenuData ~= nil and submenuData.entries ~= nil and submenuData.entries) or nil
				if lib.debugLCM then d(">entryData: " ..tos(entryData) .."; submenuData: " ..tos(submenuData) .."; #entries: " ..tos(submenuItems ~= nil and #submenuItems or 0)) end

				-->LCM Submenu
				if submenuData ~= nil and not ZO_IsTableEmpty(submenuItems) then
					if lib.debugLCM then d(">LCM  found Submenu items: " ..tos(#submenuItems)) end
					processVanillaZO_MenuItem = false

					entryName = 			entryData.mytext
					entryType = 			LSM_ENTRY_TYPE_NORMAL
					callbackFunc = 			entryData.myfunction
					myfont =				entryData.myfont
					normalColor = 			entryData.normalColor
					highlightColor = 		entryData.highlightColor
					itemYPad = 				entryData.itemYPad
					isHeader = 				false
					tooltip = 				(not tooltipIsFunction and tooltipData) or nil
					customTooltip = 		(tooltipIsFunction == true and tooltipData) or nil
					--enabled =				submenuData.enabled Not supported in LibCustomMenu

					hasSubmenu = true
					--Add non-nested subMenu entries of LibCustomMenu (as LCM only can build 1 level submenus we do not need to nest more depth)
					submenuEntries = {}
					for submenuIdx, submenuEntry in ipairs(submenuItems) do
						submenuEntry.submenuData = nil
						--Prepapre the needed data table for the recursive call to mapZO_MenuItemToLSMEntry
						-->Fill in "entryData" table into a DUMMY item
						submenuEntry.entryData = {
							mytext = 				submenuEntry.label or submenuEntry.name,
							itemType =				submenuEntry.itemType,
							myfunction =			submenuEntry.callback,
							myfont =				submenuEntry.myfont,
							normalColor =			submenuEntry.normalColor,
							highlightColor =		submenuEntry.highlightColor,
							itemYPad =				submenuEntry.itemYPad,
							horizontalAlignment =	submenuEntry.horizontalAlignment,
							enabled =				true,
							checked = 				submenuEntry.checked,
						}

						local tooltipDataSubMenu = submenuEntry.tooltip
						local tooltipIsFunctionSubMenu = type(tooltipDataSubMenu) == "function"
						if tooltipIsFunctionSubMenu then
							submenuEntry.entryData.customTooltip = tooltipDataSubMenu
						else
							submenuEntry.entryData.tooltip = tooltipDataSubMenu
						end

						if submenuEntry.disabled ~= nil then
							local disabledType = type(submenuEntry.disabled)
							if disabledType == "function" then
								submenuEntry.entryData.enabled = function(...) return not submenuEntry.disabled(...) end
							elseif disabledType == "boolean" then
								submenuEntry.entryData.enabled = not submenuEntry.disabled
							else
							end
						end

						if lib.debugLCM then
							local subMenuEntryCheckedState = getValueOrCallback(submenuEntry.entryData.checked, submenuEntry.entryData)
							d(">>Submenu item-name: " ..tos(submenuEntry.entryData.mytext) .."; itemType: " ..tos(submenuEntry.entryData.itemType) .. "; checked: " .. tos(subMenuEntryCheckedState))
						end

						--Recursively call the same function here to map the submenu entries for LSM
						local lsmEntryForSubmenu = mapZO_MenuItemToLSMEntry({ item = submenuEntry }, submenuIdx, true)
						if lsmEntryForSubmenu ~= nil and lsmEntryForSubmenu.name ~= nil then
							submenuEntries[#submenuEntries + 1] = lsmEntryForSubmenu
						end
					end

				--> LCM normal entry
				elseif entryData ~= nil then
					entryName =				entryData.mytext
					entryType = 			mapLCMItemtypeToLSMEntryType[entryData.itemType] or LSM_ENTRY_TYPE_NORMAL
					callbackFunc = 			entryData.myfunction
					myfont =				entryData.myfont
					normalColor = 			entryData.normalColor
					highlightColor = 		entryData.highlightColor
					itemYPad = 				entryData.itemYPad
					horizontalAlignment = 	entryData.horizontalAlignment

					isHeader = 				(entryData.isHeader or (isHeader or ZO_Menu_ItemCtrl.isHeader)) or nil
					checked =				(entryData.checked or (isCheckbox == true and isChecked)) or nil

					tooltip = 				(entryData.tooltip or (not tooltipIsFunction and tooltipData)) or nil
					customTooltip = 		(entryData.customTooltip or (tooltipIsFunction and tooltipData)) or nil

					--Do we need to get additional data from ZO_Menu.items controls?
					processVanillaZO_MenuItem = (entryName == nil or callbackFunc == nil and true) or false

					if entryData.enabled ~= nil then
						enabled = entryData.enabled
					end

					if lib.debugLCM then d(">LCM found normal item-processVanillaZO_MenuItem: " .. tos(processVanillaZO_MenuItem)) end
				end
			end

			--Normal ZO_Menu item added via AddMenuItem (without LibCustomMenu, if with LCM but data was missig -> Fill up)
			if processVanillaZO_MenuItem == true then
				if lib.debugLCM then d(">LCM process vanilla ZO_Menu item") end
				entryName = 	entryName or (ZO_Menu_ItemCtrl.nameLabel and ZO_Menu_ItemCtrl.nameLabel:GetText())
				callbackFunc = 	callbackFunc or ZO_Menu_ItemCtrl.OnSelect
				isHeader = 		isHeader or ZO_Menu_ItemCtrl.isHeader
				tooltip = 		not tooltipIsFunction and tooltipData
				customTooltip = tooltipIsFunction and tooltipData
				checked = 		isCheckbox == true and isChecked or nil
				if ZO_Menu_ItemCtrl.enabled ~= nil then
					enabled = ZO_Menu_ItemCtrl.enabled
				end
			end

			--Entry type checks
			---Is the entry a divider "-"?
			isDivider = (entryName and entryName == libDivider and true) or false
			if isDivider then entryType = LSM_ENTRY_TYPE_DIVIDER end
			---Is the entry a header?
			if isHeader then entryType = LSM_ENTRY_TYPE_HEADER end


			if lib.debugLCM then
				d(">>LSM entry[" .. tos(LSMAlreadyMappedItemNum) .. "]-name: " ..tos(entryName) .. ", callbackFunc: " ..tos(callbackFunc) .. ", type: " ..tos(entryType) .. ", hasSubmenu: " .. tos(hasSubmenu) .. ", entries: " .. tos(submenuEntries))
			end

			--Return values for LSM entry
			if entryName ~= nil then
				lsmEntry = {}
				lsmEntry.name = 			entryName
				--lsmEntry.label = 			entryName -- only neede dif the label differs from the name. label = visible text, name = internal key and visible text if no label provided

				lsmEntry.entryType = 		entryType
				lsmEntry.isDivider = 		isDivider
				lsmEntry.isHeader = 		isHeader
				lsmEntry.checked = 			checked

				lsmEntry.callback = 		callbackFunc

				lsmEntry.hasSubmenu = 		hasSubmenu
				lsmEntry.entries = 			submenuEntries

				lsmEntry.tooltip = 			tooltip
				lsmEntry.customTooltip =	customTooltip

				lsmEntry.isNew = 			isNew

				lsmEntry.m_font		= 		myfont or comboBoxDefaults.m_font
				lsmEntry.m_normalColor = 	normalColor or comboBoxDefaults.m_normalColor
				lsmEntry.m_disabledColor = 	disabledColor or comboBoxDefaults.m_disabledColor
				lsmEntry.m_highlightColor = highlightColor or comboBoxDefaults.m_highlightColor

				--TODO LSM 2.4 Add Support for those in LSM comboBoxDefaults etc.!
				lsmEntry.m_itemYPad = 			 itemYPad or comboBoxDefaults.itemYPad
				lsmEntry.m_horizontalAlignment = horizontalAlignment or comboBoxDefaults.horizontalAlignment

				lsmEntry.enabled = 			enabled
			end
		elseif lib.debugLCM then
			d("<ABORT: item data not found")
		end
		return lsmEntry
	end
	lib.MapZO_MenuItemToLibScrollableMenuEntry = mapZO_MenuItemToLSMEntry


	--======================================================================================================================
	--Function to store ZO_Menu items data at lib.ZO_MenuData = {}, called from function AddMenuItem
	--> uses the same index as ZO_Menu.items currently use. Will be directly mapped to LibScrollableMenu entries via function
	--> mapZO_MenuItemToLSMEntry, and shown at ShowMenu() then
	--======================================================================================================================
	local function storeZO_MenuItemDataForLSM(index, mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled, entries, isDivider)
		if lib.debugLCM then d("[LSM]storeLCMEntryDataToLSM-index: " ..tos(index) .."; mytext: " ..tos(mytext) .. "; entries: " .. tos(entries)) end

		if index == nil or mytext == nil or lib.ZO_MenuData[index] ~= nil then
			if lib.debugLCM then d("<ABORT index: " ..tos(index).. ", name: " ..mytext .. ", exists: " ..tos(lib.ZO_MenuData[index] ~= nil)) end
			return
		end

		--Check if any ZO_Menu item was added, and get it's item's control
		local lastAddedZO_MenuItem = ZO_Menu.items[index]
		local lastAddedZO_MenuItemCtrl = (lastAddedZO_MenuItem ~= nil and lastAddedZO_MenuItem.item) or nil
		if lastAddedZO_MenuItemCtrl ~= nil then

			--Entry is a checkbox? Get current checked state
			local isCheckbox = itemType == MENU_ADD_OPTION_CHECKBOX or lastAddedZO_MenuItem.checkbox ~= nil
			local isChecked = false
			if isCheckbox == true and lastAddedZO_MenuItem.checkbox ~= nil then
				--Get ZO_Menu's checkbox's current checked state
				isChecked = ZO_CheckButton_IsChecked(lastAddedZO_MenuItem.checkbox)
				if lib.debugLCM then d("[LSM]storeZO_MenuItemDataForLSM - checkbox: " .. tos(getControlName(lastAddedZO_MenuItem.checkbox)) .. ", currentState: " .. tos(isChecked)) end
			end

			--Prepare the data table that should be mapped
			local dataToAdd = {
				["index"] = index,
				["mytext"] = mytext,
				["myfunction"] = myfunction,
				["itemType"] = itemType,
				["myFont"] = myFont,
				["normalColor"] = normalColor,
				["highlightColor"] = highlightColor,
				["itemYPad"] = itemYPad,
				["horizontalAlignment"] = horizontalAlignment,
				["isHighlighted"] = isHighlighted,
				["onEnter"] = onEnter,
				["onExit"] = onExit,
				["enabled"] = enabled,
				["isDivider"] = isDivider,
				["checked"] = isChecked,

				["entries"] = entries,
			}
			lastAddedZO_MenuItem.item.entryData = dataToAdd
			lastAddedZO_MenuItem.item.submenuData = (entries ~= nil and dataToAdd) or nil

			--Map the entry of ZO_Menu to LSM entries now and add it to our internal ZO_MenuData table
			local lsmEntryMapped = mapZO_MenuItemToLSMEntry(lastAddedZO_MenuItem, index, false)
			if lsmEntryMapped ~= nil then
				if lib.debugLCM then d(">>ADDED LSMEntryMapped, index: " ..tos(index) ..", name: " ..mytext) end
				lib.ZO_MenuData[index] = lsmEntryMapped
			end
		elseif lib.debugLCM then
			d("<ABORT 2: lastAddedZO_MenuItemCtrl is NIL")
		end
	end


	---- HOOKs ----
	--Add a hook to the SHowMenu() function, if any addon registered a custom LSM replacement for ZO_menu via API function lib.RegisterZO_MenuContextMenuReplacement(addonName)
	local function addZO_Menu_ShowMenuHook()
		if lib.debugLCM then d("["..MAJOR.."]addZO_Menu_ShowMenuHook") end
		if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then clearInternalZO_MenuToLSMMappingData() return end

		--LibCustomMenu is loaded?
		if libCustomMenuIsLoaded == true then
			--Check if LibCustomMenu hooks were done
			if LCM_AddItemFunctionsHooked == true then return end
			if lib.debugLCM then d("["..MAJOR.."]LibCustomMenu: Enabled / Applying hooks") end

			--Needed functions of LCM do not exist (wrong LCM version loaded)?
			if LibCustomMenu.AddMenuItem ~= nil and LibCustomMenu.AddSubMenuItem ~= nil then
				--LibCustomMenu.AddMenuItem(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled)
				ZO_PreHook(LibCustomMenu, "AddMenuItem", function(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled)
					LCMLastAddedMenuItem = {}
					if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then clearInternalZO_MenuToLSMMappingData() return false end

					--Add the entry to lib.ZO_MenuData = {} now
					LCMLastAddedMenuItem = { index = ZO_Menu.currentIndex, name = mytext, callback = myfunction, itemType = itemType }
					if lib.debugLCM then d("[LSM]PreHook LCM.AddMenuItem-name: " ..tos(mytext) .. "; itemType: " ..tos(itemType)) end
				end)
				--LibCustomMenu.AddSubMenuItem(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, entries, isDivider)
				ZO_PreHook(LibCustomMenu, "AddSubMenuItem", function(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, entries, isDivider)
					LCMLastAddedMenuItem = {}
					if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then clearInternalZO_MenuToLSMMappingData() return false end

					--Add the entry to lib.ZO_MenuData = {} now
					LCMLastAddedMenuItem = { index = ZO_Menu.currentIndex, name = mytext, callback = myfunction, itemType = itemType, isSubmenu = true, entries = entries }
					if lib.debugLCM then d("[LSM]PreHook LCM.AddSubMenuItem-name: " ..tos(mytext) .. "; entries: " ..tos(entries)) end
				end)

				--LibCustomMenu - Tooltip function hook to add the ZO_Menu.items[index].customTooltip function (if needed)
				SecurePostHook("AddCustomMenuTooltip", function(tooltipFunc, index)
					if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then clearInternalZO_MenuToLSMMappingData() return false end
					if type(tooltipFunc) ~= "function" then return end
					index = index or #ZO_Menu.items
					assert(index > 0 and index <= #ZO_Menu.items, "["..MAJOR.."]No ZO_Menu item found for the tooltip")
					--Add the tooltip func as customTooltip to the mapped LSM entry now
					local lsmEntry = lib.ZO_MenuData[index]
					if lsmEntry == nil then return end
					if lib.debugLCM then d("[LSM]AddCustomMenuTooltip-index: " ..tos(index) .. "; entry: " .. tos(lsmEntry.label or lsmEntry.name)) end
					lsmEntry.tooltip = nil
					lsmEntry.customTooltip = tooltipFunc
				end)

				--Hook the LibCustomMenu functions
				LCM_AddItemFunctionsHooked = true
			else
				clearInternalZO_MenuToLSMMappingData()
			end
		end



		--Check if ZO_Menu hooks were done
		if ZO_Menu_showMenuHooked == false then
			if lib.debugLCM then d("["..MAJOR.."]ZO_Menu / Applying hooks") end

			--Checkboxes: If they were added to ZO_Menu via AddMenuItem - Monitor those so the first time they get checked/unchecked properly via the ZOs API functions
			--they will update that value to the LSMentry too
			-->e.g. if AddMenuItem returns the index for the entry of ZO_Menu and then you update it afterwards via ZO_CheckButton_SetChecked or ZO_CheckButton_SetUnchecked
			local function checkIfZO_MenuCheckboxStateChanged(cBoxControl)
				if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then clearInternalZO_MenuToLSMMappingData() return end
				local ZO_MenuIndexofCheckbox = lib.ZO_Menu_cBoxControlsToMonitor[cBoxControl]
				if lib.debugLCM then d("[LSM]checkIfZO_MenuCheckboxStateChanged-ZO_MenuIndexofCheckbox: " ..tos(ZO_MenuIndexofCheckbox) .. "; name: " .. tos(getControlName(cBoxControl))) end
				if cBoxControl == nil or ZO_MenuIndexofCheckbox == nil then return end
				--Clear the monitored checkbox control from the table: Only update the checked state once
				lib.ZO_Menu_cBoxControlsToMonitor[cBoxControl] = nil

				--Get the mapped LSM entry of this checkbox
				local lsmEntryForCheckbox = lib.ZO_MenuData[ZO_MenuIndexofCheckbox]
				if lsmEntryForCheckbox == nil then return end

				--PostHook here: Get the checkbox's current checked state
				local isChecked = ZO_CheckButton_IsChecked(cBoxControl)
				if isChecked == nil then return end

				if lib.debugLCM then d(">>found LSMEntry, current checked state: " ..tos(getValueOrCallback(lsmEntryForCheckbox.checked)) .. ", newState: " .. tos(isChecked)) end
				--If the LSMentry's .checked is nil or not a function (which would be run properly to update it's checked state), we set it manually now once
				if type(lsmEntryForCheckbox.checked) ~= "function" then
					lsmEntryForCheckbox.checked = isChecked
				end
			end
			SecurePostHook("ZO_CheckButton_SetChecked", checkIfZO_MenuCheckboxStateChanged)
			SecurePostHook("ZO_CheckButton_SetUnchecked", checkIfZO_MenuCheckboxStateChanged)
			if lib.debugLCM then d(">>> PostHooked ZO_CheckButton_SetUnChecked") end


			--ZO_Menu's AddMenuitem function. Attention: Will be called internally by LibCustomMenu's AddCustom*MenuItem too!
			SecurePostHook("AddMenuItem", function(labelText, onSelect, itemType, labelFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled)
				ZO_Menus:SetHidden(false)

				--As we are in a PostHook: We need to get back to last index to compare it properly!
				if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then clearInternalZO_MenuToLSMMappingData() return end
				lastAddedZO_MenuItemsIndex = ZO_Menu.currentIndex - 1
				local lastAddedLCMEntryName = LCMLastAddedMenuItem ~= nil and LCMLastAddedMenuItem.name

				if lib.debugLCM then d("[LSM]PostHook AddMenuItem-labelText: " ..tos(labelText) .. "; index: " ..tos(LCMLastAddedMenuItem.index) .."/last: " ..tos(lastAddedZO_MenuItemsIndex) .."; entries: " ..tos(LCMLastAddedMenuItem.entries)) end

				--Was the item added via LibCustomMenu?
				local entries
				if libCustomMenuIsLoaded == true and lastAddedLCMEntryName ~= nil and LCMLastAddedMenuItem.index ~= nil  then

					--Checkbox?
					if LCMLastAddedMenuItem.itemType == MENU_ADD_OPTION_CHECKBOX then
						--The checkbox's state might be updated "afer the AddMenuItem call" -> Which returns the ZO_Menu index for the checkbox row!
						--So we need to get the state now via the same function that would check the state
						--We assume functions ZO_CheckButton_SetChecked and ZO_CheckButton_SetUnchecked are used and the control passed in is the ZO_Menu.items[lastAddedIndex].checkbox.
						--> So add that current cbox control to a list (ZO_MenucBoxControlsToMonitor) to check and SecurePostHook those functions (see above -> SecurePostHook("ZO_CheckButton_SetChecked", checkIfZO_MenuCheckboxStateChanged))
						---> Check in them if the control passed in is our cbox here.
						--> And then get it's "new actual" (posthook should have applied the new state already) state and update it in the LSMentry data afterwards:
						--> As storeZO_MenuItemDataForLSM will be called directly after these line here it should add an entry to lib.ZO_MenuData[lastAddedIndex]
						local cBoxControl = ZO_Menu.items[lastAddedZO_MenuItemsIndex].checkbox
						if cBoxControl ~= nil then
							if lib.debugLCM then d("[LSM]AddMenuItem-Added cbox control with index: "..tos(lastAddedZO_MenuItemsIndex) .. ", to ZO_Menu_cBoxControlsToMonitor") end
							lib.ZO_Menu_cBoxControlsToMonitor[cBoxControl] = lastAddedZO_MenuItemsIndex
						end
					else
						--Entry last added was a submenu?
						if LCMLastAddedMenuItem.isSubmenu == true and LCMLastAddedMenuItem.entries ~= nil
								and ( LCMLastAddedMenuItem.index == lastAddedZO_MenuItemsIndex
								or ( lastAddedLCMEntryName == labelText or (labelText == string.format("%s |u16:0::|u", lastAddedLCMEntryName)) )
						) and
								LCMLastAddedMenuItem.callback == onSelect and LCMLastAddedMenuItem.itemType == itemType then
							--Get a copy of the submenu entries added
							entries = ZO_ShallowTableCopy(LCMLastAddedMenuItem.entries)
						end
					end

				end
				LCMLastAddedMenuItem = {}

				--Add the entry to lib.ZO_MenuData = {} now
				local isDivider = (((libCustomMenuIsLoaded == true and itemType ~= MENU_ADD_OPTION_HEADER and labelText == libDivider) or labelText == libDivider) and true) or false

				--Store the ZO_Menu/LCM last added entry to our LSM internal table now, with the mapped data to LSM context menu entry format
				storeZO_MenuItemDataForLSM(lastAddedZO_MenuItemsIndex,
						labelText,
						onSelect,
						itemType,
						labelFont,
						normalColor,
						highlightColor,
						itemYPad,
						horizontalAlignment,
						isHighlighted,
						onEnter,
						onExit,
						enabled,
						entries,
						isDivider)
			end)
			if lib.debugLCM then d(">>> PostHooked AddMenuItem") end


			--Hook the ClearMenu function so we can clear our LSM variables too
			SecurePostHook("ClearMenu", function()
				if lib.debugLCM then
					d("<<<<<<<<<<<<<<<<<<<<<<<")
					d("[LSM]ClearMenu - preventClearCustomScrollableMenuToClearZO_MenuData: " ..tos(lib.preventClearCustomScrollableMenuToClearZO_MenuData))
					d("<<<<<<<<<<<<<<<<<<<<<<<")
				end
				ZO_Menus:SetHidden(false)

				--Clear the existing LSM context menu entries
				clearCustomScrollableMenu()
			end)
			if lib.debugLCM then d(">>> PostHooked ClearMenu") end

			--PreHook the ShowMenu function of ZO_Menu in order to map the ZO_Menu.items to the LSM entries
			--and suppress the ZO_Menu to show -> Instead show LSM context menu
			-->Attention: ShowMenu will be called several times after another (e.g. first by ZOs vanilla code, then for EACH addon added menu entries)
			---->Important: So we do must NOT call ClearMenu() or ClearCustomScrollableMenu() in between
			--->One needs to "only add new entries added to ZO_Menu". Else we would re-add the before added entries which have been added via
			--->AddCustomScrollableMenuEntry already
			--->The currently last added entry index will be stored in lib.ZO_MenuData_CurrentIndex, and we will only add the "new added" (after that index)
			--->entries of our table lib.ZO_MenuData to the current menu then
			ZO_PreHook("ShowMenu", function(owner, initialRefCount, menuType)
				--Unhide the TLC so the menus of ZO_Menu will show properly in any case
				ZO_Menus:SetHidden(false)

				--Should the ZO_Menu not close any opened LSM? e.g. to show the textSearchHistory at the LSM text filter search box
				if lib.preventLSMClosingZO_Menu == true then
					lib.preventLSMClosingZO_Menu = nil
					return
				end

				--No LSM replacement for ZO_Menu is registered at all? Abort here now and show ZO_Menu normally
				if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then
					resetZO_MenuClearVariables()
					return false -- run original ZO_Menu's ShowMenu()
				end
				if lib.debugLCM then
					d("!!!!!!!!!!!!!!!!!!!!")
					d("[LSM]ShowMenu - initialRefCount: " ..tos(initialRefCount) .. ", menuType: " ..tos(menuType))
					d("!!!!!!!!!!!!!!!!!!!!")
				end
				--Any items to show in the ZO_Menu?
				if next(ZO_Menu.items) == nil then
					if lib.debugLCM then d("<ABORT: No ZO_Menu.items available") end
					resetZO_MenuClearVariables()
					return false -- run original ZO_Menu's ShowMenu() -> Will return false in there directly then
				end

				--No entries added to internal LSM mapped enties table yet (nothing was available in ZO_Menu?) -> Show normal ZO_Menu.items data then
				local ZO_MenuData = lib.ZO_MenuData
				if ZO_IsTableEmpty(ZO_MenuData) then
					if lib.debugLCM then d("<ABORT: No LSM.ZO_MenuData mapped entries available") end
					resetZO_MenuClearVariables()
					return false -- run original ZO_Menu's ShowMenu()
				end

				--Do not support any non default menu types (e.g. dropdown special menus like ZO_AutoComplete)
				menuType = menuType or MENU_TYPE_DEFAULT
				if menuType ~= MENU_TYPE_DEFAULT then
					if lib.debugLCM then d("<ABORT: Non supported menu type: " .. tos(menuType)) end
					resetZO_MenuClearVariables()
					return false -- run original ZO_Menu's ShowMenu()
				end

				owner = owner or GetMenuOwner(ZO_Menu)
				--No owner provided? Get the control below the mouse cursor
				owner = owner or moc()
				if owner == nil then
					if lib.debugLCM then d("<ABORT: No menu owner determined") end
					resetZO_MenuClearVariables()
					return false -- run original ZO_Menu's ShowMenu()
				end

				--Is the control allowed to exchange ZO_Menu? e.g. inventory context menu
				local isAllowed, ownerName = isAllowedControl(owner)
				if not isAllowed then
					if lib.debugLCM then d("<ABORT: Menu owner " .. tos(ownerName) .. " is not allowed for LSM usage") end
					resetZO_MenuClearVariables()
					return false
				end

				--Is the control blocked?
				local isBlocked = false
				isBlocked, ownerName = isBlacklistedControl(owner, ownerName)
				if isBlocked == true then
					if lib.debugLCM then d("<ABORT: Menu owner " .. tos(ownerName) .. " is a blocked control") end
					resetZO_MenuClearVariables()
					return false -- run original ZO_Menu's ShowMenu()
				end

				--Build new LSM context menu now
				local numLSMItemsAddedDuringThisShowMenu = 0
				--The last index added for an LSM entry in the current context menu (so we do not add the same entries again and again with each ShowMenu() call)
				local lastUsedItemIndex                  = lib.ZO_MenuData_CurrentIndex

				--for idx, lsmEntry in ipairs(lib.ZO_MenuData) do
				local numItems = #ZO_MenuData
				local startIndex = lastUsedItemIndex + 1
				if startIndex > numItems then
					if lib.debugLCM then d("<ABORT: startIndex "  ..tos(startIndex).." > numItems: " ..tos(numItems)) end
					resetZO_MenuClearVariables()
					return false -- run original ZO_Menu's ShowMenu()
				end

				--Now loop all new added entries (> lib.ZO_MenuData_CurrentIndex) from ZO_MenuData and add them to the LSM context menu
				for idx=startIndex, numItems, 1  do
					local lsmEntry = ZO_MenuData[idx]

					if lsmEntry ~= nil and lsmEntry.name ~= nil then
						if lib.debugLCM then d("~~~~ Add item of ZO_Menu["..tos(idx).."]: " ..tos(lsmEntry.name)) end

						--Transfer the menu entry now to LibScrollableMenu, instead of ZO_Menu
						--->pass in lsmEntry as additionlData (last parameter) so m_normalColor etc. will be applied properly too
						AddCustomScrollableMenuEntry(lsmEntry.name, lsmEntry.callback, lsmEntry.entryType, lsmEntry.entries, lsmEntry)
						numLSMItemsAddedDuringThisShowMenu = numLSMItemsAddedDuringThisShowMenu + 1
					else
						if lib.debugLCM then d("???? ERROR: item of ZO_Menu["..tos(idx).."] is nil, or got no name!") end
					end

					--Set the last added index now, for next call to ShowMenu()
					lib.ZO_MenuData_CurrentIndex = idx
				end

				--No LSM mapped items found? Show normal ZO_Menu now
				if lib.debugLCM then d(">>> nummber of new added LSM items: " ..tos(numLSMItemsAddedDuringThisShowMenu)) end
				if numLSMItemsAddedDuringThisShowMenu <= 0 then
					resetZO_MenuClearVariables()
					return false -- run original ZO_Menu's ShowMenu()
				end

				--Set the variable to call ClearMenu() on next reset of the LSM contextmenu (if LSM context menu closes e.g.)
				lib.callZO_MenuClearMenuOnClearCustomScrollableMenu = true

				--Hide original ZO_Menu (and LibCustomMenu added entries) now -> Do this here AFTER preparing LSM entries,
				-- else the ZO_Menu.items and sub controls will be emptied already (nil)!
				-->Important: Do NOT clear the ZO_Menu here!  Keep all entries in ZO_Menu.items. Entries with the same index
				-->are skipped due to the usage of the index offset lib.ZO_MenuData_CurrentIndex!
				--> So only visually "hide" the ZO_Menu here but do not call ClearMenu() as this would empty the ZO_Menu.items early!
				customClearMenu()


				--Show the LSM context menu now with the mapped and added ZO_Menu entries, in LSM format.
				-->ShowCustomScrollableMenu will show all previously added entries plus the new ones
				showLSMReplacmentContextMenuForZO_MenuNow(owner, ownerName)

				--Hide the ZO_Menu TLC now -> Delayed to next frame (to hide that small [ ] menu TLC near the right clicked mouse position)
				--> TODO: Moved to customClearMenu() function above. Test if that works
				--[[
				zo_callLater(function()
					ZO_Menus:SetHidden(true)
				end, 1)
				]]

				--Suppress original ZO_Menu building and "Show" LSM entries now (se above via ShowCustomScrollableMenu( ... ) )
				return true
			end)
			if lib.debugLCM then d(">>> PreHooked ShowMenu") end

			ZO_Menu_showMenuHooked = true
		end
	end


	--------------------------------------------------------------------------------------------------------------------
	-- API functions for ZO_Menu hooks of LSM
	--------------------------------------------------------------------------------------------------------------------

	--Similar to LibCustomMenu: Register a hook for your addon to use LibScrollableMenu for the context menus
	-->If ANY CustomScrollableContextMenu was registered with LibScrollableMenu:
	-->LibCustomMenu and vanilla ZO_Menu context menus will be suppressed then, mapped into LSM entries and
	-->LSM context menu will be shown instead
	-->Else: Normal ZO_Menu and LibCustomMenu context menus will be used
	function lib.RegisterZO_MenuContextMenuReplacement(addonName)
		assert(addonName ~= nil and registeredCustomScrollableContextMenus[addonName] == nil, sfor('['..MAJOR..'.RegisterZO_MenuContextMenuReplacement] \'addonName\' missing or already registered: %q', tos(addonName)))
		registeredCustomScrollableContextMenus[addonName] = true
		clearZO_MenuAndLSM()
		--Check if the ZO_Menu hooks need to be applied
		addZO_Menu_ShowMenuHook()
	end
	local registerZO_MenuContextMenuReplacement = lib.RegisterZO_MenuContextMenuReplacement


	--Unregister a before registered custom scrollable context menu again
	--Returns true if addon was unregistered, false if addon was not unregistered
	function lib.UnregisterZO_MenuContextMenuReplacement(addonName)
		if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then
			resetZO_MenuClearVariables()
			return
		end
		assert(addonName ~= nil, sfor('['..MAJOR..'.UnregisterZO_MenuContextMenuReplacement] \'addonName\' missing: %q', tos(addonName)))
		if registeredCustomScrollableContextMenus[addonName] ~= nil then
			registeredCustomScrollableContextMenus[addonName] = nil
			clearZO_MenuAndLSM()
			return true
		end
		return false
	end
	local unregisterZO_MenuContextMenuReplacement = lib.UnregisterZO_MenuContextMenuReplacement

	--Did an addon with name "<addonName>" register a custom scrollable menu as replacement for ZO_Menu?
	function lib.IsZO_MenuContextMenuReplacementRegistered(addonName)
		if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then
			resetZO_MenuClearVariables()
			return false
		end
		assert(addonName ~= nil, sfor('['..MAJOR..'.IsZO_MenuContextMenuReplacementRegistered] \'addonName\' missing: %q', tos(addonName)))
		return registeredCustomScrollableContextMenus[addonName] ~= nil
	end
	local isZO_MenuContextMenuReplacementRegistered = lib.IsZO_MenuContextMenuReplacementRegistered


	--------------------------------------------------------------------------------------------------------------------
	-- API functions for ZO_Menu hooks - Blacklisted controls
	--------------------------------------------------------------------------------------------------------------------

	--Add a control to a blacklist that should not be replacing ZO_Menu context menus with LibScrollableMenu context menu.
	-->For these added controls on the blacklist the LSM context menu will not be shown instead of ZO_Menu, but ZO_Menu
	-->will be used.
	-->The controlName must be the name of the control where the context menu opens on, the parent control of that control or
	-->the openingWindow control of that control!
	function lib.AddControlToZO_MenuContextMenuReplacementBlacklist(controlName)
		local controlNameType = type(controlName)
		assert(controlNameType == "string" and blacklistedControlsForZO_MenuReplacement[controlName] == nil, sfor('['..MAJOR..'.AddControlToZO_MenuContextMenuReplacementBlacklist] \'controlName\' missing, wrong type %q, or already added. Name: %q', tos(controlNameType), tos(controlName)))
		blacklistedControlsForZO_MenuReplacement[controlName] = true
	end

	--Remove a control from the blacklist that should not be replacing ZO_Menu context menus with LibScrollableMenu context menu.
	-->For these removed controls the LSM context menu will be shown, instead of ZO_Menu
	function lib.RemoveControlFromZO_MenuContextMenuReplacementBlacklist(controlName)
		local controlNameType = type(controlName)
		assert(controlNameType == "string" and blacklistedControlsForZO_MenuReplacement[controlName] ~= nil, sfor('['..MAJOR..'.RemoveControlFromZO_MenuContextMenuReplacementBlacklist] \'controlName\' missing, wrong type %q, or was not added yet. Name: %q', tos(controlNameType), tos(controlName)))
		blacklistedControlsForZO_MenuReplacement[controlName] = nil
	end

	--Check if the controlName is on the blacklist (to prevent LSM usage for ZO_Menu)
	function lib.IsControlOnZO_MenuContextMenuReplacementBlacklist(controlName)
		local controlNameType = type(controlName)
		assert(controlNameType == "string", sfor('['..MAJOR..'.IsControlOnZO_MenuContextMenuReplacementBlacklist] \'controlName\' missing or wrong type %q. Name: %q', tos(controlNameType), tos(controlName)))
		return blacklistedControlsForZO_MenuReplacement[controlName] ~= nil
	end



	--Add a control to a whitelist/allowed list that should be replacing ZO_Menu context menus with LibScrollableMenu context menu.
	-->For these added controls on the whitelist the LSM context menu will be shown instead of ZO_Menu.
	-->The controlName must be the name of the control where the context menu opens on, the parent control of that control or
	-->the openingWindow control of that control!
	function lib.AddControlToZO_MenuContextMenuReplacementWhitelist(controlName)
		local controlNameType = type(controlName)
		assert(controlNameType == "string" and whitelistedControlNamesForZO_MenuReplacement[controlName] == nil, sfor('['..MAJOR..'.AddControlToZO_MenuContextMenuReplacementWhitelist] \'controlName\' missing, wrong type %q, or already added. Name: %q', tos(controlNameType), tos(controlName)))
		whitelistedControlNamesForZO_MenuReplacement[controlName] = true
	end

	--Remove a control from the whitelist/allowed list that should be replacing ZO_Menu context menus with LibScrollableMenu context menu.
	-->For these removed controls the ZO_Menu context menu will be shown, instead of LSM
	function lib.RemoveControlFromZO_MenuContextMenuReplacementWhitelist(controlName)
		local controlNameType = type(controlName)
		assert(controlNameType == "string" and whitelistedControlNamesForZO_MenuReplacement[controlName] ~= nil, sfor('['..MAJOR..'.RemoveControlFromZO_MenuContextMenuReplacementWhitelist] \'controlName\' missing, wrong type %q, or was not added yet. Name: %q', tos(controlNameType), tos(controlName)))
		whitelistedControlNamesForZO_MenuReplacement[controlName] = nil
	end

	--Check if the controlName is on the whitelist (to use LSM instead of ZO_Menu)
	function lib.IsControlOnZO_MenuContextMenuReplacementWhitelist(controlName)
		local controlNameType = type(controlName)
		assert(controlNameType == "string", sfor('['..MAJOR..'.IsControlOnZO_MenuContextMenuReplacementWhitelist] \'controlName\' missing or wrong type %q. Name: %q', tos(controlNameType), tos(controlName)))
		return whitelistedControlNamesForZO_MenuReplacement[controlName] ~= nil
	end


	--------------------------------------------------------------------------------------------------------------------
	-- Load the ZO_Menu & LCM -> LSM hook via a slash command
	--------------------------------------------------------------------------------------------------------------------
	local function contextMenuZO_MenuReplacement()
		local onOffTag = ""
		if isZO_MenuContextMenuReplacementRegistered(MAJOR) then
			unregisterZO_MenuContextMenuReplacement(MAJOR)
			onOffTag = "OFF"
		else
			registerZO_MenuContextMenuReplacement(MAJOR)
			onOffTag = "ON"
		end
		d("["..MAJOR.."]Provides context menus for whitelisted controls: " .. tos(onOffTag))
	end

	--Toggle the replacement of ZO_Menu (including LibCustomMenu) at iventory contextmenus on/off
	SLASH_COMMANDS["/lsmcontextmenu"] = function()
        contextMenuZO_MenuReplacement()
    end

	SLASH_COMMANDS["/lsmdebugcontextmenu"] = function()
		lib.debugLCM = not lib.debugLCM
		d("["..MAJOR.."]Debugging ZO_Menu context menus for whitelisted controls: " .. tos(lib.debugLCM))
    end

	--Test for ZO_Menu / LibCustomMenu replacement
	function lib.Test3()
		if isZO_MenuContextMenuReplacementRegistered(MAJOR) then
			--Add another inventory context menu entry
			AddCustomScrollableMenuEntry("Inv. context menu - Test entry 1", function() d("Inv. context test entry 1 clicked") end, LSM_ENTRY_TYPE_NORMAL, nil, nil)
			ShowCustomScrollableMenu()
		end
	end


------------------------------------------------------------------------------------------------------------------------
end --function lib.LoadZO_MenuHooks()
------------------------------------------------------------------------------------------------------------------------

