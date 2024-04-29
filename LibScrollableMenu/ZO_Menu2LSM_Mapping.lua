local lib = LibScrollableMenu
if lib == nil then return end

local MAJOR = lib.name

--local ZOs references
local tos = tostring
local sfor = string.format

--Local libray references
--Variables
local LSM_ENTRY_TYPE_NORMAL = 	LSM_ENTRY_TYPE_NORMAL
local LSM_ENTRY_TYPE_DIVIDER = 	LSM_ENTRY_TYPE_DIVIDER
local LSM_ENTRY_TYPE_HEADER = 	LSM_ENTRY_TYPE_HEADER
local LSM_ENTRY_TYPE_CHECKBOX = LSM_ENTRY_TYPE_CHECKBOX

local libDivider = lib.DIVIDER
local comboBoxDefaults = lib.comboBoxDefaults

--Functions
local clearCustomScrollableMenu = ClearCustomScrollableMenu

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

local registeredCustomScrollableInventoryContextMenus = {}


--Table of last created (theoretically, not shown!) ZO_Menu items -> Which LSM will then show on ShowMenu() call
lib.ZO_MenuData = {}
local ZO_MenuData = lib.ZO_MenuData
--Preventer variable with the name and callback and itemtype (and optional isSubmenu boolean) for AddMenuItem function hook
--> Prevents that if LibCustomMenu is enabled the function calls to AddCustom*MenuItem, that internally call AddMenuItem again,
--> will add duplicate data
lib.LCMLastAddedMenuItem                 = {}
local LCMLastAddedMenuItem = lib.LCMLastAddedMenuItem

------------------------------------------------------------------------------------------------------------------------
-- Move LibCustomMenu and normal vanilla ZO_Menu to LibScrollableMenu scrollable menus
-- -> Means: Map the entries of the ZO_Menu items to LSM entries and then only show LSM instead
------------------------------------------------------------------------------------------------------------------------

--[[
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

--Hide currently shown context menus
local function clearZO_MenuAndLSM()
	ClearMenu()
	clearCustomScrollableMenu()
end


--local API func helpers
lib.registeredCustomScrollableInventoryContextMenus = registeredCustomScrollableInventoryContextMenus

--Is any custom scrollable ZO_Menu replacement context menu registered?
local function isAnyCustomScrollableZO_MenuContextMenuRegistered()
	return not ZO_IsTableEmpty(registeredCustomScrollableInventoryContextMenus)
end
lib.IsAnyCustomScrollableZO_MenuContextMenuRegistered = isAnyCustomScrollableZO_MenuContextMenuRegistered





------------------------------------------------------------------------------------------------------------------------
--Load the ZO_Menu hooks
------------------------------------------------------------------------------------------------------------------------
function lib.LoadZO_MenuHooks()
	--LibCustomMenu is loaded? If not these hooks will only take care of vanilla ZO_Menu
	local libCustomMenuIsLoaded = LibCustomMenu ~= nil


	---- MAPPING ----
	--Mapping between LibCustomMenu and LibScrollableMenu's entry types at the context menus
	local mapLCMItemtypeToLSMEntryType
	if libCustomMenuIsLoaded then
		mapLCMItemtypeToLSMEntryType = {
			[MENU_ADD_OPTION_LABEL]		= LSM_ENTRY_TYPE_NORMAL,
			[MENU_ADD_OPTION_CHECKBOX]	= LSM_ENTRY_TYPE_CHECKBOX,
			[MENU_ADD_OPTION_HEADER]	= LSM_ENTRY_TYPE_HEADER,
		}
	end

	--Map the LibCustomMenu and normal ZO_Menu entries data to LibScrollableMenu entries data
	local itemAddedNum = 0
	local function mapZO_MenuItemToLSMEntry(ZO_MenuItemData, menuIndex, isBuildingSubmenu)
		itemAddedNum = itemAddedNum + 1
		if lib.debugLCM then d("[LSM]mapZO_MenuItemToLSMEntry-itemAddedNum: " .. tos(itemAddedNum) ..", isBuildingSubmenu: " .. tos(isBuildingSubmenu)) end
		isBuildingSubmenu = isBuildingSubmenu or false
		local lsmEntry
		local ZO_Menu_ItemCtrl = ZO_MenuItemData.item --~= nil and ZO_ShallowTableCopy(ZO_MenuItemData.item)
		if ZO_Menu_ItemCtrl ~= nil then

			local entryName
			local callbackFunc
			local isCheckbox = ZO_Menu_ItemCtrl.itemType == MENU_ADD_OPTION_CHECKBOX or ZO_MenuItemData.checkbox ~= nil
			local isDivider = false
			local isHeader = false --todo: how to detect a header
			local entryType = isCheckbox and LSM_ENTRY_TYPE_CHECKBOX or LSM_ENTRY_TYPE_NORMAL
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
			local tooltip --todo: Add tooltips check and if function -> map to LSM entry.customTooltip
			local customTooltip
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
				local entryData = ZO_MenuItemData.entryData
				--Is this an entry opening a submenu?
				local submenuData = ZO_MenuItemData.submenuData
				local submenuItems = submenuData ~= nil and submenuData.entries

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
					tooltip = 				not tooltipIsFunction and tooltipData
					customTooltip = 		tooltipIsFunction and tooltipData
					--enabled =				submenuData.enabled Not supported in LibCustomMenu

					hasSubmenu = true
					--Add non-nested subMenu entries of LibCustomMenu (as LCM only can build 1 level submenus we do not need to nest more depth)
					submenuEntries = {}
					for submenuIdx, submenuEntry in ipairs(submenuItems) do
						submenuEntry.submenuData = nil
						--Prepapre the needed data table for the recursive call to mapZO_MenuItemToLSMEntry
						-->Fill in "entryData" table into a DUMMY item
						submenuEntry.entryData = {
							mytext = 				submenuEntry.label,
							itemType =				submenuEntry.itemType,
							myfunction =			submenuEntry.callback,
							myfont =				submenuEntry.myfont,
							normalColor =			submenuEntry.normalColor,
							highlightColor =		submenuEntry.highlightColor,
							itemYPad =				submenuEntry.itemYPad,
							--horizontalAlignment =	submenuEntry.horizontalAlignment,
							enabled =				true
						}

						local tooltipDataSubMenu = submenuEntry.tooltip
						local tooltipIsFunctionSubMenu = type(tooltipData) == "function"
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

					isHeader = 				isHeader or ZO_Menu_ItemCtrl.isHeader

					tooltip = 				not tooltipIsFunction and tooltipData
					customTooltip = 		tooltipIsFunction and tooltipData

					processVanillaZO_MenuItem = (entryName == nil or callbackFunc == nil and true) or false

					if entryData.enabled ~= nil then
						enabled = entryData.enabled
					end

					if lib.debugLCM then d(">LCM found normal item-processVanillaZO_MenuItem: " .. tos(processVanillaZO_MenuItem)) end
				end
			end

			--Normal ZO_Menu item added via AddMenuItem (without LibCustomMenu, if with LCM but data was missig -> Fill up)
			if processVanillaZO_MenuItem then
				if lib.debugLCM then d(">LCM process vanilla ZO_Menu item") end
				entryName = 	entryName or (ZO_Menu_ItemCtrl.nameLabel and ZO_Menu_ItemCtrl.nameLabel:GetText())
				callbackFunc = 	callbackFunc or ZO_Menu_ItemCtrl.OnSelect
				isHeader = 		isHeader or ZO_Menu_ItemCtrl.isHeader
				tooltip = 		not tooltipIsFunction and tooltipData
				customTooltip = tooltipIsFunction and tooltipData

				if ZO_Menu_ItemCtrl.enabled ~= nil then
					enabled = ZO_Menu_ItemCtrl.enabled
				end
			end

			--Entry type checks
			---Is the entry a divider "-"?
			isDivider = entryName and entryName == libDivider
			if isDivider then entryType = LSM_ENTRY_TYPE_DIVIDER end
			---Is the entry a header?
			if isHeader then entryType = LSM_ENTRY_TYPE_HEADER end


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
				lsmEntry.customTooltip =customTooltip

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
					_item = ZO_Menu_ItemCtrl ~= nil and ZO_Menu_ItemCtrl or "! ERROR !",
					_itemNameLabel = (ZO_Menu_ItemCtrl.nameLabel ~= nil and ZO_Menu_ItemCtrl.nameLabel) or "! ERROR !",
					_itemCallback = (ZO_Menu_ItemCtrl.OnSelect ~= nil and ZO_Menu_ItemCtrl.OnSelect) or "! ERROR !",
					lsmEntry = lsmEntry ~= nil and ZO_ShallowTableCopy(lsmEntry) or "! ERROR !",
					isBuildingSubmenu = isBuildingSubmenu,
					menuIndex = menuIndex,
				}
			end
		end
		return lsmEntry
	end
	lib.MapZO_MenuItemToLibScrollableMenuEntry = mapZO_MenuItemToLSMEntry


	--Store ZO_Menu items data at lib.ZO_MenuData = {}, with the same index as ZO_Menu.itms currently use. Will be directly mapped to LibCustomMenu entries and shown at ShowMenu() then
	local function storeZO_MenuItemDataForLSM(index, mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled, entries, isDivider)
d("[LSM]storeLCMEntryDataToLSM-index: " ..tos(index) .."; mytext: " ..tos(mytext) .. "; entries: " .. tos(entries))

		if index == nil or mytext == nil or ZO_MenuData[index] ~= nil then return end

		local lastAddedZO_MenuItem = ZO_Menu.items[index]
		local lastAddedZO_MenuItemCtrl = (lastAddedZO_MenuItem ~= nil and lastAddedZO_MenuItem.item) or nil
		if lastAddedZO_MenuItemCtrl ~= nil then
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
					["entries"] = entries,
					["isDivider"] = isDivider
			}

			--Submenu?
			if entries ~= nil and itemType == MENU_ADD_OPTION_LABEL then
				lastAddedZO_MenuItemCtrl.entryData = nil
				lastAddedZO_MenuItemCtrl.submenuData = dataToAdd
			else
				--Normal entry
				lastAddedZO_MenuItemCtrl.submenuData = nil
				lastAddedZO_MenuItemCtrl.entryData = dataToAdd
			end

			--Map the entry new and add it to our data
			local lsmEntryMapped = mapZO_MenuItemToLSMEntry(lastAddedZO_MenuItemCtrl, index)
			if not ZO_IsTableEmpty(lsmEntryMapped) then
				ZO_MenuData[index] = lsmEntryMapped
			end
		end
	end


	---- HOOKs ----
	local ZO_Menu_showMenuHooked = false
	local LCM_AddItemFunctionsHooked = false
	local function addZO_Menu_ShowMenuHook()
		if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then return end

		--LibCustomMenu is loaded?
		if libCustomMenuIsLoaded then
			--Check if LibCustomMenu hooks were done
			if LCM_AddItemFunctionsHooked then return end

			--LibCustomMenu.AddMenuItem(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled)
			ZO_PreHook(LibCustomMenu, "AddMenuItem", function(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled)
				LCMLastAddedMenuItem = {}
				if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then return false end

				--Add the entry to lib.ZO_MenuData = {} now
				LCMLastAddedMenuItem = { name = mytext, callback = myfunction, itemType = itemType }
			end)
			--LibCustomMenu.AddSubMenuItem(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, entries, isDivider)
			ZO_PreHook(LibCustomMenu, "AddSubMenuItem", function(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, entries, isDivider)
				LCMLastAddedMenuItem = {}
				if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then return false end

				--Add the entry to lib.ZO_MenuData = {} now
				LCMLastAddedMenuItem = { name = mytext, callback = myfunction, itemType = itemType, isSubmenu = true, entries = entries }
			end)

			--Hook the LibCustomMenu functions
			LCM_AddItemFunctionsHooked = true
		end


		--Check if ZO_Menu hooks were done
		if not ZO_Menu_showMenuHooked then
			--ZO_Menu's AddMenuitem function. Attention: Will be called internally by LibCustomMenu's AddCustom*MenuItem too!
			SecurePostHook("AddMenuItem", function(labelText, onSelect, itemType, labelFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled)
				if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then LCMLastAddedMenuItem = {} return false end

				--Was the item added via LibCustomMenu?
				local entries
				if libCustomMenuIsLoaded == true and LCMLastAddedMenuItem.name ~= nil then
					if LCMLastAddedMenuItem.name == labelText and
							LCMLastAddedMenuItem.callback == onSelect and
							LCMLastAddedMenuItem.itemType == itemType and
							LCMLastAddedMenuItem.isSubmenu == true then
						entries = ZO_ShallowTableCopy(LCMLastAddedMenuItem.entries)
					end
				end
				LCMLastAddedMenuItem = {}

				--Add the entry to lib.ZO_MenuData = {} now
				local isDivider = (libCustomMenuIsLoaded == true and itemType ~= MENU_ADD_OPTION_HEADER and labelText == libDivider) or labelText == libDivider
				--As we are at a "Pre"Hook we need to manually increase the index of ZO_Menu items by 1 (for our function call), to simulate the correct index
				-->Chanegd to secure posthook so we have the index AND the data in ZO_Menu.items[index]!
				storeZO_MenuItemDataForLSM(ZO_Menu.currentIndex, labelText, onSelect, itemType, labelFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled, entries, isDivider)

				--return false --Call original ZO_Menu AddMenuItem code now too to increase the ZO_Menu.currentIndex and fill ZO_Menu.items etc. properly
			end)


			--Hook the ClearMenu function so we can clear our LSM variables too
			local preventClearCustomScrollableMenu = false
			SecurePostHook("ClearMenu", function()
				ZO_MenuData = {}
				if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then preventClearCustomScrollableMenu = false return end
				if preventClearCustomScrollableMenu == true then
					preventClearCustomScrollableMenu = false
					return
				end
				d("[LSM]ClearMenu")
				--Clear the existing LSM context menu entries
				clearCustomScrollableMenu()
			end)

			--PreHook the ShowMenu function of ZO_Menu in order to map the ZO_Menu.items to the LSM entries
			--and suppress the ZO_Menu to show -> Instead show LSM context menu
			-->Attention: ShowMenu will be called several times after another (e.g. first by ZOs vanilla code, then addon added menu entries)
			-->So we do must NOT call ClearMenu() or ClearCustomScrollableMenu() in between


			--TODO 20240417
			--On ClearMenu() -> ClearCustomScrollableMenu() -> clear lib.ZO_MenuData
			--On AddMenuItem or AddCustomMenuItem (wenn LibCustomMenu is enabled) and AddCustomSubmenuItem (Attention: AddCustom*Menuitem call AddMenuItem internally again! So set a preventer for duplicate entries there via hooks to LibCustomMenu AddMenuItem and AddSubMenuItem)
			--> Directly map to LSM entry data and store it in a table lib.ZO_MenuData
			--> At ShowMenu: Just check entries in lib.ZO_MenuData and populate them via LSM (if relevant)
			--> Else, as it currently is handled on ShowMenu, each new addon using ShowMenu would multiply the output of the same entries again and again!


		--TODO: Will be called TWICE or at least multiple times -> once per addon!
			ZO_PreHook("ShowMenu", function(owner)
				if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then return false end
				d("[LSM]ShowMenu")
				if lib.debugLCM then
					LSM_Debug = LSM_Debug or {}
					LSM_Debug._ZO_Menu_Items = LSM_Debug._ZO_Menu_Items or {}
				end

				if ZO_IsTableEmpty(ZO_MenuData) then return end

				local ownerName = (owner ~= nil and owner.GetName and owner:GetName()) or owner
				if lib.debugLCM then d("[LSM]SecurePostHook-ShowMenu-owner: " .. tos(ownerName)) end
				if owner == nil then return false end

				--[[
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
				--local isAllowed, _ = isSupportedInventoryRowPattern(owner, ownerName)
				local isAllowed = true --> Allow ALL ZO_Menu
				if not isAllowed then
					if lib.debugLCM then d("<<ABORT! Not supported context menu owner: " ..tos(ownerName)) end
					return false
				end
				]]

				--Build new LSM context menu now
				local numLSMItemsAdded = 0
				for idx, lsmEntry in ipairs(ZO_MenuData) do
					if lib.debugLCM then
						LSM_Debug._ZO_Menu_Items[ownerName].LSM_Items = LSM_Debug._ZO_Menu_Items[ownerName].LSM_Items or {}
						LSM_Debug._ZO_Menu_Items[ownerName].LSM_Items[#LSM_Debug._ZO_Menu_Items[ownerName].LSM_Items+1] = lsmEntry
					end

					if lsmEntry ~= nil and lsmEntry.name ~= nil then
						--Transfer the menu entry now to LibScrollableMenu instead of ZO_Menu
						--->pass in lsmEntry as additionlData (last parameter) so m_normalColor etc. will be applied properly
						AddCustomScrollableMenuEntry(lsmEntry.name, lsmEntry.callback, lsmEntry.entryType, lsmEntry.entries, lsmEntry)
						numLSMItemsAdded = numLSMItemsAdded + 1
					end
				end

				--No LSM mapped items found? Show normal ZO_Menu now
				if lib.debugLCM then d(">>> numLSMItemsAdded: " ..tos(numLSMItemsAdded)) end
				if numLSMItemsAdded <= 0 then return false end


				--Hide original ZO_Menu (and LibCustomMenu added entries) now -> Do this here AFTER preparing LSM entries,
				-- else the ZO_Menu.items and sub controls will be emptied already (nil)!
				-->Actually do not clear the ZO_Menu items here as oher ones might be added by addons
				--if lib.debugLCM then d(">> ~~ Clear ZO_Menu ~~~") end
				preventClearCustomScrollableMenu = true
				ClearMenu()

				--Show the LSM contetx menu now with the mapped and added ZO_Menu entries
				if lib.debugLCM then d("< ~~ SHOWING LSM! ShowCustomScrollableMenu ~~~") end
				local isZOListDialogHidden = zoListDialog:IsHidden()
				ShowCustomScrollableMenu(owner, {
					sortEntries = 			false,
					visibleRowsDropdown = 	isZOListDialogHidden and 20 or 15,
					visibleRowsSubmenu = 	isZOListDialogHidden and 20 or 15,
				})

				--Suppress original ZO_Menu building and "Show" now
				return true
			end)
			ZO_Menu_showMenuHooked = true

		end
	end




	--------------------------------------------------------------------------------------------------------------------
	-- API functions for ZO_Menu hooks of LSM
	--------------------------------------------------------------------------------------------------------------------

	--Similar to LibCustomMenu: Register a hook for your addon to use LibScrollableMenu for the inventory context menus
	-->If ANY CustomScrollableInventoryContextMenu was registered with LibScrollableMenu:
	-->LibCustomMenu and vanilla ZO_Menu inventory context menus will be suppressed then, mapped into LSM entries and
	-->LSM context menu will be shown instead
	-->Else: Normal ZO_Menu and LibCustomMenu inventory context menus will be used
	function lib.RegisterCustomScrollableZO_MenuContextMenu(addonName)
		assert(addonName ~= nil and registeredCustomScrollableInventoryContextMenus[addonName] == nil, sfor('['..MAJOR..'.RegisterCustomScrollableZO_MenuContextMenu] \'addonName\' missing or already registered: %q', tos(addonName)))
		registeredCustomScrollableInventoryContextMenus[addonName] = true
		clearZO_MenuAndLSM()
		addZO_Menu_ShowMenuHook()
	end
	local registerCustomScrollableZO_MenuContextMenu = lib.RegisterCustomScrollableZO_MenuContextMenu


	--Unregister a before registered custom scrollable invetory context menu again
	--returns true if addon was unregistered, false if addon was not unregstered
	function lib.UnregisterCustomScrollableZO_MenuContextMenu(addonName)
		if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then return end
		assert(addonName ~= nil, sfor('['..MAJOR..'.UnregisterCustomScrollableZO_MenuContextMenu] \'addonName\' missing: %q', tos(addonName)))
		if registeredCustomScrollableInventoryContextMenus[addonName] ~= nil then
			registeredCustomScrollableInventoryContextMenus[addonName] = nil
			clearZO_MenuAndLSM()
			return true
		end
		return false
	end
	local unregisterCustomScrollableZO_MenuContextMenu = lib.UnregisterCustomScrollableZO_MenuContextMenu

	--Did an addon register a custom scrollable menu as replacement for ZO_Menu?
	function lib.IsCustomScrollableZO_MenuContextMenuRegistered(addonName)
		if not isAnyCustomScrollableZO_MenuContextMenuRegistered() then return false end
		assert(addonName ~= nil, sfor('['..MAJOR..'.IsCustomScrollableZO_MenuContextMenuRegistered] \'addonName\' missing: %q', tos(addonName)))
		return registeredCustomScrollableInventoryContextMenus[addonName] ~= nil
	end
	local isCustomScrollableZO_MenuContextMenuRegistered = lib.IsCustomScrollableZO_MenuContextMenuRegistered



	local function invContextMenuZO_MenuReplacement()
		if isCustomScrollableZO_MenuContextMenuRegistered(MAJOR) then
			unregisterCustomScrollableZO_MenuContextMenu(MAJOR)
		else
			registerCustomScrollableZO_MenuContextMenu(MAJOR)
		end
	end

	--Toggle the replacement of ZO_Menu (including LibCustomMenu) on and off
	SLASH_COMMANDS["/lsmuseforinv"] = function() invContextMenuZO_MenuReplacement() end

------------------------------------------------------------------------------------------------------------------------
end --function lib.LoadZO_MenuHooks()
------------------------------------------------------------------------------------------------------------------------








