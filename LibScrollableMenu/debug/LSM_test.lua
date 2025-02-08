local lib = LibScrollableMenu
local MAJOR = lib.name

local debugPrefix = lib.Debug.prefix

------------------------------------------------------------------------------------------------------------------------
-- For testing - Combobox with all kind of entry types (test offsets, etc.)
------------------------------------------------------------------------------------------------------------------------
local function test()
	if lib.testComboBoxContainer == nil then
		local testSV = ZO_SavedVars:NewAccountWide("LibScrollableMenu_SavedVars", 1, "LSM_Test",
				{ cbox1 = false, cbox2 = false, cbox3 = false,
				  cboxSubmenu1 = false, cboxSubmenu2 = false, cboxSubmenu3 = false,
				  cboxContextmenu1 = false, cboxContextmenu2 = false, cboxContextmenu3 = false },
				nil, nil)


		local testTLC = CreateTopLevelWindow(MAJOR .. "TestTLC")
		testTLC:SetHidden(true)
		testTLC:SetDimensions(1, 1)
		testTLC:SetAnchor(CENTER, GuiRoot, CENTER)
		testTLC:SetMovable(true)
		testTLC:SetMouseEnabled(false)

		local comboBoxContainer = WINDOW_MANAGER:CreateControlFromVirtual(MAJOR .. "TestDropdown", testTLC, "ZO_ComboBox")
		local comboBox          = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
		lib.testComboBoxContainer = comboBoxContainer

		comboBoxContainer:SetAnchor(LEFT, testTLC, LEFT, 10, 0)
		comboBoxContainer:SetHeight(24)
		comboBoxContainer:SetWidth(250)
		comboBoxContainer:SetMovable(true)

		local narrateOptions = {
			["OnComboBoxMouseEnter"] = 	function(m_dropdownObject, comboBoxControl)
				local isOpened = m_dropdownObject:IsDropdownVisible()
				return "ComboBox mouse entered - opened: " .. tostring(isOpened)
			end,
			["OnComboBoxMouseExit"] =	function(m_dropdownObject, comboBoxControl)
				return "ComboBox mouse exit"
			end,
			["OnMenuShow"] =			function(m_dropdownObject, dropdownControl)
				return "Menu show"
			end,
			["OnMenuHide"] =			function(m_dropdownObject, dropdownControl)
				return "Menu hide"
			end,
			["OnSubMenuShow"] =			function(m_dropdownObject, parentControl, anchorPoint)
				return "Submenu show, anchorPoint: " ..tostring(anchorPoint)
			end,
			["OnSubMenuHide"] =			function(m_dropdownObject, parentControl)
				return "Submenu hide"
			end,
			["OnEntryMouseEnter"] =		function(m_dropdownObject, entryControl, data, hasSubmenu)
				local entryName = lib.GetValueOrCallback(data.label ~= nil and data.label or data.name, data) or "n/a"
				return "Entry Mouse entered: " ..entryName .. ", hasSubmenu: " ..tostring(hasSubmenu)
			end,
			["OnEntryMouseExit"] =		function(m_dropdownObject, entryControl, data, hasSubmenu)
				local entryName = lib.GetValueOrCallback(data.label ~= nil and data.label or data.name, data) or "n/a"
				return "Entry Mouse exit: " ..entryName .. ", hasSubmenu: " ..tostring(hasSubmenu)
			end,
			["OnEntrySelected"] =		function(m_dropdownObject, entryControl, data, hasSubmenu)
				local entryName = lib.GetValueOrCallback(data.label ~= nil and data.label or data.name, data) or "n/a"
				return "Entry selected: " ..entryName .. ", hasSubmenu: " ..tostring(hasSubmenu)
			end,
			["OnCheckboxUpdated"] =		function(m_dropdownObject, checkboxControl, data)
				local entryName = lib.GetValueOrCallback(data.label ~= nil and data.label or data.name, data) or "n/a"
				local isChecked = ZO_CheckButton_IsChecked(checkboxControl)
				return "Checkbox updated: " ..entryName .. ", checked: " ..tostring(isChecked)
			end,
		}


		--Define your options for the scrollHelper here
		-->For all possible option values check API function "AddCustomScrollableComboBoxDropdownMenu" description at file
		-->LibScrollableMenu.lua
		local HEADER_TEXT_COLOR_RED = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_FAILED))
		local CUSTOM_DISABLED_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_GAME_REPRESENTATIVE))
		local CUSTOM_HIGHLIGHT_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_TOOLTIP_INSTRUCTIONAL))


		local function customFilterFunc(p_item, p_filterString)
			local name = p_item.label or p_item.name
			if p_item.customFilterFuncData ~= nil then
				if p_item.customFilterFuncData.findMe ~= nil then
			d(">customFilterFunc - findMe: " ..tostring(p_item.customFilterFuncData.findMe))
					return zo_strlower(p_item.customFilterFuncData.findMe):find(p_filterString) ~= nil
				end
			end
			return false
		end


		--==============================================================================================================
		-- Options for the main combobox menu
		--==============================================================================================================
		local options = {
			enableMultiSelect = true, --todo 20250127 test
			maxNumSelections = 2,
			maxNumSelectionsErrorText =		debugPrefix.."ERROR - Maximum items selected already",
			multiSelectionTextFormatter = 	"<<1>> selected",
			noSelectionText = 				"",
			OnSelectionBlockedCallback = function() d(debugPrefix.."ERROR - Selection of entry was blocked!") end,

			visibleRowsDropdown = 10,
			visibleRowsSubmenu = 10,
			maxDropdownHeight = 450,
			--maxDropdownWidth = 450,

			--Big yellow headers!
			--headerFont = "ZoFontHeader3",
			--headerColor = CUSTOM_DISABLED_TEXT_COLOR,

			--useDefaultHighlightForSubmenuWithCallback = true,

			--sortEntries=function() return false end,
			narrate = narrateOptions,
			disableFadeGradient = false,
			--headerColor = HEADER_TEXT_COLOR_RED,
			--titleText = function()  return "Custom title text" end,
			--subtitleText = "Custom sub title",
			enableFilter = function() return true end,
			headerCollapsible = true,
			headerCollapsed = true,

			--customFilterFunc = customFilterFunc

			--[[ Define in XML:
				<!-- Normal entry for Custom options.XMLRowTemplates test  -->
				<Control name="LibScrollableMenu_ComboBoxEntry_TestXMLRowTemplates" inherits="LibScrollableMenu_ComboBoxEntry" mouseEnabled="true" virtual="true">
					<Dimensions y="ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT" />
					<OnInitialized>
						<!-- Is this still needed? -->
						self.selectible = true <!-- Denotes this is a selectible entry.   -->
					</OnInitialized>

					<Controls>
						<Label name="$(parent)Label" verticalAlignment="CENTER" override="true" wrapMode="ELLIPSIS" maxLineCount="1">
							<Anchor point="TOPLEFT" relativeTo="$(parent)IconContainer" relativePoint="TOPRIGHT" offsetX="1" />
							<Anchor point="RIGHT" offsetX="ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING" />
						</Label>
					</Controls>
				</Control>

			--Afterwards enable this custom enryType's setupFunction
			XMLRowTemplates = {
				[lib.scrollListRowTypes.LSM_ENTRY_TYPE_NORMAL] = {
					template = "LibScrollableMenu_ComboBoxEntry_TestXMLRowTemplates",
					rowHeight = 40,
					setupFunc = function(control, data, list)
						local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer) -- comboBoxContainer = The ZO_ComboBox control you created via WINDOW_MANAGER:CreateControlFromVirtual("NameHere", yourTopLevelControlToAddAsAChild, "ZO_ComboBox")
						comboBox:SetupEntryLabel(control, data, list)
					end,
				}
			},
			]]
			highlightContextMenuOpeningControl = true,
			XMLRowHighlightTemplates = {
				[lib.LSM_ENTRY_TYPE_NORMAL] = {
					template = lib.LSM_ROW_HIGHLIGHT_DEFAULT, --"ZO_SelectionHighlight",
					color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
					templateContextMenuOpeningControl = lib.LSM_ROW_HIGHLIGHT_BLUE,
				},
				[lib.LSM_ENTRY_TYPE_SUBMENU] = {
					template = lib.LSM_ROW_HIGHLIGHT_DEFAULT, --"ZO_SelectionHighlight", --Will be replaced with green if submenu entry got callback
					templateSubMenuWithCallback = lib.LSM_ROW_HIGHLIGHT_OPAQUE,
					color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
				},
				[lib.LSM_ENTRY_TYPE_CHECKBOX] = {
					template = lib.LSM_ROW_HIGHLIGHT_RED, --"LibScrollableMenu_Highlight_Blue",
					color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
					templateContextMenuOpeningControl = lib.LSM_ROW_HIGHLIGHT_OPAQUE,
				},
				[lib.LSM_ENTRY_TYPE_BUTTON] = {
					template = lib.LSM_ROW_HIGHLIGHT_RED, --"LibScrollableMenu_Highlight_Red",
					color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
				},
				[lib.LSM_ENTRY_TYPE_RADIOBUTTON] = {
					template = lib.LSM_ROW_HIGHLIGHT_OPAQUE, --"LibScrollableMenu_Highlight_White",
					color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
				},
			},
		}

		--Try to change the options of the scrollhelper as it gets created
		--[[
		lib:RegisterCallback('OnDropdownMenuAdded', function(comboBox, optionsPassedIn)
--d(debugPrefix .. "TEST - Callback fired: OnDropdownMenuAdded - current visibleRows: " ..tostring(optionsPassedIn.visibleRowsDropdown))
			optionsPassedIn.visibleRowsDropdown = 5 -- Overwrite the visible rows at the dropdown
--d("<visibleRows after: " ..tostring(optionsPassedIn.visibleRowsDropdown))
		end)
		]]

		--Create a scrollHelper then and reference your ZO_ComboBox, plus pass in the options
		--After that build your menu entres (see below) and add them to the combobox via :AddItems(comboBoxMenuEntries)
		local scrollHelper = AddCustomScrollableComboBoxDropdownMenu(testTLC, comboBoxContainer, options)
		-- did not work		scrollHelper.OnShow = function() end --don't change parenting


		--Prepare and add the text entries in the dropdown's comboBox

		--==============================================================================================================
		-- Submenu entries within contextMenus
		--==============================================================================================================
		local submenuEntriesForContextMenu = {
			{
				label = 		"Test Checkbox in context menu submenu",
				callback = function()
					d("Checkbox in context menu submenu clicked")
				end,
				entryType = LSM_ENTRY_TYPE_CHECKBOX,

			},
			{
				--name            = "CntxtMenu - Submenu entry 1:1",
				label = 			"Test name missing - only label",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("CntxtMenu - Submenu entry 1:1")
				end,
				tooltip         = 	"CntxtMenu - Submenu Entry Test 1:1",
				--icon 			= nil,
				enabled 		= true,
			},
			{
				name            =	"-",
			},
			{

				name            = "CntxtMenu - Submenu entry 1:2",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("CntxtMenu - Submenu entry 1:2")
				end,
				tooltip         = function() return "CntxtMenu - Submenu Entry Test 1:2" end,
				isNew			= true,
				--icon 			= nil,
				enabled 		= function() return true end,
			},
			{
				entryType		= LSM_ENTRY_TYPE_DIVIDER,
			},
			{

				name            = "CntxtMenu - Submenu entry with 3 icon 1:3",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("CntxtMenu - Submenu entry 1:3")
				end,
				--tooltip         = function() return "CntxtMenu - Submenu Entry Test 1:2" end,
				--isNew			= true,
				--icon 			= nil,
				icon =			{ "/esoui/art/inventory/inventory_trait_ornate_icon.dds", "EsoUI/Art/Inventory/inventory_trait_intricate_icon.dds", "EsoUI/Art/Inventory/inventory_trait_not_researched_icon.dds" },
				--enabled 		= function() return false end,
			},
			{
				name = function() return "-" end,
				customValue1 = "test",
				--entryType = LSM_ENTRY_TYPE_DIVIDER,
			},
			{

				name            = "CntxtMenu - Submenu entry with 2 icon 1:4",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("CntxtMenu - Submenu entry 1:3")
				end,
				--tooltip         = function() return "CntxtMenu - Submenu Entry Test 1:2" end,
				--isNew			= true,
				--icon 			= nil,
				icon =			{ { iconTexture = "/esoui/art/inventory/inventory_trait_ornate_icon.dds", width = 32, height = 32, tooltip = "Hello world" }, "EsoUI/Art/Inventory/inventory_trait_intricate_icon.dds", { iconTexture = "EsoUI/Art/Inventory/inventory_trait_not_researched_icon.dds", width = 16, height = 16, tooltip = "Hello world - 2nd tooltip" }  },
				--enabled 		= false,
			},
			{
				name            =	"bla blubb",
				entryType		= LSM_ENTRY_TYPE_DIVIDER,
			},
			{

				name            = "CntxtMenu - Submenu entry 1:5",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("CntxtMenu - Submenu entry 1:5")
				end,
				--tooltip         = function() return "CntxtMenu - Submenu Entry Test 1:2" end,
				--isNew			= false,
				--icon 			= nil,
			},
		}

		--==============================================================================================================
		-- Submenu entries
		--==============================================================================================================
		--LibScrollableMenu - LSM entry - Submenu normal
		local isCheckBoxNow = false
		local isCheckBoxNow2 = false
		local submenuEntries               = {
			{

				name            = "Submenu Entry Test 1 (contextMenu)",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 1")
				end,
				contextMenuCallback =   function(self)
					d("Submenu Entry Test 1 (contextMenu) -> Callback")
					ClearCustomScrollableMenu()

					AddCustomScrollableSubMenuEntry("Context Submenu entry 1 (function)", submenuEntriesForContextMenu) -- function() return subEntries end --todo: ERROR both do not remove the isNew onMouseEnter at a contextmenu

					AddCustomScrollableMenuEntry("Context RunCustomScrollableMenuItemsCallback (Parent, All)", function(comboBox, itemName, item, selectionChanged, oldItem)
						d('Custom menu Normal entry 1')

						local function myAddonCallbackFuncSubmenu(p_comboBox, p_item, entriesFound) --... will be filled with customParams
							--Loop at entriesFound, get it's .data.dataSource etc and check SavedVAriables etc.
d(debugPrefix .. "Context menu submenu - Custom menu Normal entry 1->RunCustomScrollableMenuItemsCallback: WAS EXECUTED!")
							for _, v in ipairs(entriesFound) do
								local name = v.label or v.name
								d(">name of entry: " .. tostring(name).. ", checked: " .. tostring(v.checked))
							end

						end

						--Use LSM API func to get the opening control's list and m_sorted items properly so addons do not have to take care of that again and again on their own
						RunCustomScrollableMenuItemsCallback(comboBox, item, myAddonCallbackFuncSubmenu, nil, true)
					end)

					AddCustomScrollableMenuEntry("Context Custom menu Normal entry 2", function() d('Custom menu Normal entry 2') end)

					ShowCustomScrollableMenu(nil, { narrate = narrateOptions, enableFilter = true })
				end,
				--tooltip         = "Submenu Entry Test 1",
				--icon 			= nil,
				highlightContextMenuOpeningControl = true,
				m_highlightTemplate = lib.LSM_ROW_HIGHLIGHT_RED --"LibScrollableMenu_Highlight_Red", -> Should be transfered into data._LSM.OriginalData.data subtable so it can be always found again even if other XMLRowHighlightTemplates were provided via the options
			},
			{

				name            = "Submenu Entry Test 2 (contextMenu)",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 2")
				end,
				contextMenuCallback =   function(self)
					d("Submenu Entry Test 2 (contextMenu) -> Callback")
					ClearCustomScrollableMenu()

					AddCustomScrollableMenuEntry("Context RunCustomScrollableMenuItemsCallback (Same, All)", function(comboBox, itemName, item, selectionChanged, oldItem)
						d('Custom menu Normal entry 1')

						local function myAddonCallbackFuncSubmenu(p_comboBox, p_item, entriesFound) --... will be filled with customParams
							--Loop at entriesFound, get it's .data.dataSource etc and check SavedVAriables etc.
d(debugPrefix .. "Context menu submenu 2 - Custom menu 2 Normal entry 1->RunCustomScrollableMenuItemsCallback: WAS EXECUTED!")
							for k, v in ipairs(entriesFound) do
								local name = v.label or v.name
								d(">[Same menu]name of entry: " .. tostring(name).. ", checked: " .. tostring(v.checked))
							end

						end

						--Use LSM API func to get the opening control's list and m_sorted items properly so addons do not have to take care of that again and again on their own
						RunCustomScrollableMenuItemsCallback(comboBox, item, myAddonCallbackFuncSubmenu, nil, false)
					end)

					AddCustomScrollableMenuEntry("Context Custom menu Normal entry 2", function() d('Custom menu Normal entry 2') end)

					ShowCustomScrollableMenu(nil, { narrate = narrateOptions, })
				end,
				isNew			= true,
				--icon 			= nil,
			},
			{
				--isCheckbox		= function() isCheckBoxNow = not isCheckBoxNow d("isCheckBoxNow = " ..tostring(isCheckBoxNow)) return isCheckBoxNow end,
				entryType = 	function() isCheckBoxNow = not isCheckBoxNow d("isCheckBoxNow = " ..tostring(isCheckBoxNow)) return isCheckBoxNow and LSM_ENTRY_TYPE_CHECKBOX or LSM_ENTRY_TYPE_NORMAL end,
				name            = "Checkbox submenu entry 1 with 3 icon - entryType = func (checkbox)",
				icon 			= "/esoui/art/inventory/inventory_trait_ornate_icon.dds",
				callback        =   function(comboBox, itemName, item, checked)
					d("Checkbox entry 1 - checked: " ..tostring(checked))
				end,
				--	tooltip         = function() return "Checkbox entry 1"  end
				tooltip         = "Checkbox entry 1",
				icon =			{ "/esoui/art/inventory/inventory_trait_ornate_icon.dds", "EsoUI/Art/Inventory/inventory_trait_intricate_icon.dds", "EsoUI/Art/Inventory/inventory_trait_not_researched_icon.dds" }
			},
			{
				name            = "-", --Divider
			},
			{
				--isCheckbox		= true,
				name            = "Checkbox submenu entry 2 - LSM_ENTRY_TYPE_CHECKBOX - checked from SV fixed",
				callback        =   function(comboBox, itemName, item, checked)
					d("Checkbox entry 2 - checked: " ..tostring(checked))
					testSV.cboxSubmenu1 = checked
				end,
				checked			= testSV.cboxSubmenu1, -- Confirmed does start checked.
				--tooltip         = function() return "Checkbox entry 2" end
				tooltip         = "Checkbox entry 2",
				entryType		= LSM_ENTRY_TYPE_CHECKBOX,
				--[[
				additionalData = {
						normalColor =		GetClassColor(GetUnitClassId("player")),
						disabledColor =		CUSTOM_DISABLED_TEXT_COLOR,
						highlightColor =	CUSTOM_HIGHLIGHT_TEXT_COLOR,
						highlightTemplate =	"ZO_TallListSelectedHighlight",
						font = function() return "ZoFontBookLetter" end,
					}
					]]
			},
			{
				name            = "-", --Divider
			},
			--LibScrollableMenu - LSM entry - Submenu divider
			{
				name            = "test submenu divider with name text - LSM_ENTRY_TYPE_DIVIDER",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					--Dividers do not use any callback
				end,
				tooltip         = "Submenu Divider Test 1",
				--icon 			= nil,
				entryType		= LSM_ENTRY_TYPE_DIVIDER,
			},
			{

				name            = "Submenu Entry Test 3",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 3")
				end,
				isNew			= true,
				--tooltip         = "Submenu Entry Test 3",
				--icon 			= nil,
			},
			{
				isHeader        = true, --Enables the header at LSM
				name            = "Header Test 1 - isHeader",
				icon			= "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_Staff_Frost_Up.dds",
				tooltip         = "Header test 1",
				--icon 			= nil,
			},
			{

				name            = "Submenu Entry Test 4 - LSM_ENTRY_TYPE_NORMAL",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 4")
				end,
				tooltip         = function() return "Submenu Entry Test 4"  end,
				--icon 			= nil,
				entryType		= LSM_ENTRY_TYPE_NORMAL,
			},
			{

				name            = "Submenu Entry Test 4 - LSM_ENTRY_TYPE_NORMAL, but entries",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 4")
				end,
				tooltip         = function() return "Submenu Entry Test 4"  end,
				--icon 			= nil,
				entryType		= LSM_ENTRY_TYPE_NORMAL,
				entries 		= {}, --does that match together with entryType = LSM_ENTRY_TYPE_NORMAL? Or LSM_ENTRY_TYPE_SUBMENU needed?
			},
			{

				name            = "Submenu Entry Test 5",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 5")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icon 			= nil,
			},
			{
				name            = "Submenu entry 6",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry 6")
				end,
				entries         = {
					{

						name            = "Normal entry 6 1:1",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:1")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icon 			= nil,
					},
					{

						name            = "Submenu entry 6 1:2",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:2")
						end,
						tooltip         = "Submenu entry 6 1:2",
						entries         = {
							{

								name            = "Submenu entry 6 with 3 icon 2:1",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:1")
								end,
								--tooltip         = "Submenu Entry Test 1",
								icon =			{ "/esoui/art/inventory/inventory_trait_ornate_icon.dds", "EsoUI/Art/Inventory/inventory_trait_intricate_icon.dds", "EsoUI/Art/Inventory/inventory_trait_not_researched_icon.dds" }
							},
							{

								name            = "Submenu entry 6 2:2",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:2")
								end,
								tooltip         = "Submenu entry 6 2:2",
								entries         = {
									{

										name            = "Normal entry 6 2:1",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:1")
										end,
										--tooltip         = "Submenu Entry Test 1",
										--icon 			= nil,
									},
									{

										name            = "Normal entry 6 2:2",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:2")
										end,
										tooltip         = "Normal entry 6 2:2",
										isNew			= true,
										--icon 			= nil,
									},
								},
							},
						},
					},
					{

						name            = "Normal entry 6 1:2",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Normal entry 6 1:2")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icon 			= nil,
					},
				},
				--	tooltip         = function() return "Submenu entry 6"  end
				tooltip         = "Submenu entry 6"
			},
			{

				name            = "Submenu Entry Test 7",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 7")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icon 			= nil,
			},
			{

				name            = "Submenu Entry Test 8",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 8")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icon 			= nil,
			},
			{

				name            = "Submenu Entry Test 9",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 9")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icon 			= nil,
			},
			{

				name            = "Submenu Entry Test 10",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 10")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icon 			= nil,
			}
		}

		--Normal entries
		local wasNameChangedAtEntry = false
		local wasLabelChangedAtEntry = false
		local isEnabledNowMain = false
		local isEnabledNow = false
		local gotSubmenuEntries = false
		local isChecked = false

		--==============================================================================================================
		-- Main combobox menu entries
		--==============================================================================================================
		local comboBoxMenuEntries          = {
			{
				isHeader        = function() return true end, --Enables the header at LSM
				name            = "Header Test Main 1 - isHeader = func",
				tooltip         = "Header test main 1",
				--icon 			= nil,
			},
			{
				entryType		= LSM_ENTRY_TYPE_BUTTON,
				label			= "Click me - I'm a button",
				name            = "Button1",
				tooltip         = "Button button button...",
				callback 		= function(comboBox, itemName, item, selectionChanged, oldItem)
					d("I clicked a button with the name: " .. tostring(itemName))
				end,
				doNotFilter		= true,
			},
			{
				entryType		= LSM_ENTRY_TYPE_RADIOBUTTON,
				label			= "Radiobutton group 1-1",
				name            = "Radiobutton group 1-1",
				tooltip         = "Radiobutton tooltip 1",
				checked 		= true,
				callback 		= function(comboBox, itemName, item, checked)
					d("I clicked Radiobutton group 1-1 with the name: " .. tostring(itemName))
				end,
				buttonGroup = 1,
				doNotFilter		= true,
			},
			{
				entryType		= LSM_ENTRY_TYPE_RADIOBUTTON,
				label			= "Radiobutton group 1-2",
				name            = "Radiobutton group 1-2",
				tooltip         = "Radiobutton tooltip 2",
				checked 		= false,
				callback 		= function(comboBox, itemName, item, checked)
					d("I clicked Radiobutton group 1-2 with the name: " .. tostring(itemName))
				end,
				buttonGroup = function() return 1 end,
				buttonGroupOnSelectionChangedCallback = function(control, previousControl) d("radio Radiobutton group 1 selection changed callback!")  end
			},
			{
				entryType		= LSM_ENTRY_TYPE_RADIOBUTTON,
				label			= "Radiobutton group 2-3",
				name            = "Radiobutton group 2-3",
				tooltip         = "Radiobutton tooltip 3",
				checked 		= true,
				callback 		= function(comboBox, itemName, item, checked)
					d("I clicked Radiobutton group 2-3 with the name: " .. tostring(itemName))
				end,
				buttonGroup = 2,
			},
			{
				entryType		= LSM_ENTRY_TYPE_RADIOBUTTON,
				label			= "Radiobutton group 2-4",
				name            = "Radiobutton group 2-4",
				tooltip         = "Radiobutton tooltip 4",
				checked 		= false,
				callback 		= function(comboBox, itemName, item, checked)
					d("I clicked Radiobutton group 2-4 with the name: " .. tostring(itemName))
				end,
				buttonGroup = function() return 2 end,
				buttonGroupOnSelectionChangedCallback = function(control, previousControl) d("radio button group 2 selection changed callback!")  end
			},
			{
				entryType		= LSM_ENTRY_TYPE_CHECKBOX,
				label			= "Checkbox group 3-1",
				name            = "Checkbox group 3-1",
				tooltip         = "cButton cbutton cbutton...",
				checked 		= true,
				callback 		= function(comboBox, itemName, item, checked)
					d("I clicked checkbox group3-1 with the name: " .. tostring(itemName) .. ", checked: " .. tostring(checked))
				end,
				buttonGroup = 3,
				contextMenuCallback = function(...)
					LibScrollableMenu.SetButtonGroupState(...)
				end,
			},
			{
				entryType		= LSM_ENTRY_TYPE_CHECKBOX,
				label			= "Checkbox group 3-2",
				name            = "Checkbox group 3-2",
				tooltip         = "cButton2 cbutton2 cbutton2...",
				checked 		= false,
				callback 		= function(comboBox, itemName, item, checked)
					d("I clicked checkbox group3-2 with the name: " .. tostring(itemName) .. ", checked: " .. tostring(checked))
				end,
				buttonGroup = function() return 3 end,
				buttonGroupOnSelectionChangedCallback = function(control, previousControl) d("checkbox group 3 selection changed callback!")  end,
				rightClickCallback = function(...)
					LibScrollableMenu.SetButtonGroupState(...)
				end,
			},
			{
				additionalData = {
					normalColor =		GetClassColor(GetUnitClassId("player")),
					disabledColor =		CUSTOM_DISABLED_TEXT_COLOR,
					highlightColor =	CUSTOM_HIGHLIGHT_TEXT_COLOR,
					highlightTemplate =	"ZO_TallListSelectedHighlight",
					font = 				function() return "ZoFontBookLetter" end,
				},

				enabled = function() isEnabledNowMain = not isEnabledNowMain return isEnabledNowMain end,
				name = function()
					if not wasNameChangedAtEntry then
						wasNameChangedAtEntry = true
						return "Normal entry 1 (contextMenu)"
					else
						wasNameChangedAtEntry = false
						return "Normal entry 1 - Changed (contextMenu)"
					end
				end,
				--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				callback        =   function(self)
					d("Normal entry 1")
				end,
				--entryType = lib.LSM_ENTRY_TYPE_CHECKBOX,
				contextMenuCallback =   function(self)
					d("contextMenuCallback")
					ClearCustomScrollableMenu()
					--AddCustomScrollableSubMenuEntry("Context menu entry 1", subEntries)
					AddCustomScrollableMenuHeader("Header test in context menu", nil)

					AddCustomScrollableSubMenuEntry("Context menu entry1 opening a submenu", submenuEntriesForContextMenu)

					AddCustomScrollableMenuEntry("RunCustomScrollableMenuItemsCallback (Parent, Checkboxes)", function(comboBox, itemName, item, selectionChanged, oldItem)
						d('Context menu Normal entry 1')


						local function myAddonCallbackFunc(p_comboBox, p_item, entriesFound, ...) --... will be filled with customParams
							--Loop at entriesFound, get it's .data.dataSource etc and check SavedVAriables etc.
							d(debugPrefix .. "Context menu - Normal entry 1->RunCustomScrollableMenuItemsCallback: WAS EXECUTED!")
							for k, v in ipairs(entriesFound) do
								local name = v.label or v.name
								d(">name of checkbox: " .. tostring(name).. ", checked: " .. tostring(v.checked))
							end

						end

						--Use LSM API func to get the opening control's list and m_sorted items properly so addons do not have to take care of that again and again on their own
						RunCustomScrollableMenuItemsCallback(comboBox, item, myAddonCallbackFunc, { LSM_ENTRY_TYPE_CHECKBOX }, true, "customParam1", "customParam2")
					end)

					AddCustomScrollableMenuEntry("Context menu Normal entry 2", function() d('Context menu Normal entry 2') end, nil, nil, {
						normalColor =		GetClassColor(GetUnitClassId("player")),
						disabledColor =		CUSTOM_DISABLED_TEXT_COLOR,
						highlightColor =	CUSTOM_HIGHLIGHT_TEXT_COLOR,
						highlightTemplate =	"ZO_TallListSelectedHighlight",
						font = function() return "ZoFontBookLetter" end,
					})

					AddCustomScrollableMenuEntry("Context menu Normal entry 3", function() d('Context menu Normal entry 3') end)

					AddCustomScrollableMenuEntry("Context menu Normal entry 4", function() d('Context menu Normal entry 4') end)

					AddCustomScrollableMenuEntry("Context menu Normal entry 5", function() d('Context menu Normal entry 5') end)

					ShowCustomScrollableMenu(nil, {
						--titleText = "Context menu",
						--titleFont = function() return "ZoFontGameSmall" end,
						--subtitleText = function() return "Test 1" end,
						--subtitleFont = "ZoFontHeader3", --Same font size as title
						enableFilter = true,
						--headerColor = HEADER_TEXT_COLOR_RED,
						visibleRowsDropdown = 5,
						visibleRowsSubmenu = 4,
						--maxDropdownHeight = 250,
						--sortEntries = false,
					})
				end,
				icon			= "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_Staff_Frost_Up.dds",
				isNew			= true,
				--entries         = submenuEntries,
				--tooltip         =
				customTooltip   = function(control, isAbove, data, rowControl, point, offsetX, offsetY, relativePoint)
					if isAbove and data ~= nil then
						ZO_Tooltips_ShowTextTooltip(rowControl, point or TOP, "Test custom tooltip")
					else
						ZO_Tooltips_HideTextTooltip()
					end
				end,
			},
			{
				name            = "-", --Divider
			},
			{

				name            = "Submenu Entry Test - No entries",
				entryType = LSM_ENTRY_TYPE_SUBMENU,

			},
			{
				name            = "Main checkbox - checked (toggle func)",
				checked           = function() isChecked = not isChecked return isChecked end,
				callback        =   function(comboBox, itemName, item, checked)
					d("Main checkbox! checked: " ..tostring(checked))
				end,
				--entries         = submenuEntries,
				--tooltip         =
				entryType = lib.LSM_ENTRY_TYPE_CHECKBOX,
				rightClickCallback = function() d("Test context menu")  end
			},
			{
				label = "test",
				isDivider = true
			}, --todo: Divider test, working this way?
			{
				customFilterFuncData = {
					findMe = "test",
				},


				name            = "Main checkbox 2 - isCheckbox = true, entryType=checkbox, checked = SV fixed",
				checked           = testSV.cbox1,
				--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				callback        =   function(comboBox, itemName, item, checked)
					d("Main checkbox 2! checked: " ..tostring(checked))
					testSV.cbox1 = checked
				end,
				--entries         = submenuEntries,
				--tooltip         =
				entryType = lib.LSM_ENTRY_TYPE_CHECKBOX,
				isCheckbox = true,
			},
			{
				label ="Header with label",
				isHeader = true
			}, --todo: header test, working this way?
			{
				name            = "Main checkbox 3 - entryType = checkbox, checked = SV func",
				checked           = function() return testSV.cbox2  end,
				--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				callback        =   function(comboBox, itemName, item, checked)
					d("Main checkbox 3! checked: " ..tostring(checked))
					testSV.cbox2 = checked
				end,
				--entries         = submenuEntries,
				--tooltip         =
				entryType = lib.LSM_ENTRY_TYPE_CHECKBOX
				--isCheckbox = true,
			},
			{
				entryType            = function() return LSM_ENTRY_TYPE_DIVIDER end --divider with function returning the entryType
			},
			{
				name            = "Name used as value, label shows entry's name", --no name test
				label           = function()
					if not wasLabelChangedAtEntry then
						wasLabelChangedAtEntry = true
						return "Entry with label 1"
					else
						wasLabelChangedAtEntry = false
						return "Entry with label 1 - Changed"
					end
				end,
				--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				callback        =   function(self)
					d("Entry with label 1!")
				end,
				--entries         = submenuEntries,
				--tooltip         =
				--type = lib.LSM_ENTRY_TYPE_CHECKBOX
			},
			{
				name            = "-", --Divider
			},
			{
				name            = "Entry having submenu 1 - entries = function, callback = true",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Entry having submenu 1")
				end,
				--entries         = function() gotSubmenuEntries = not gotSubmenuEntries if gotSubmenuEntries == true then return submenuEntries else return { } end end,
				entries         = function() return submenuEntries end,
				tooltip         = 'Submenu test tooltip.',
				icon =			{ { iconTexture = "/esoui/art/inventory/inventory_trait_ornate_icon.dds", width = 32, height = 32, tooltip = "Hello world" }, "EsoUI/Art/Inventory/inventory_trait_intricate_icon.dds", { iconTexture = "EsoUI/Art/Inventory/inventory_trait_not_researched_icon.dds", width = 16, height = 16, tooltip = "Hello world - 2nd tooltip" }  }
			},
			{
				name            = "Normal entry 2 (contextMenu)",
				--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				callback        =   function(self)
					d("Normal entry 2")
				end,
				contextMenuCallback         =   function(self)
					d("Normal entry 2")
					ClearCustomScrollableMenu()

					AddCustomScrollableMenuHeader("Test header context menu")

					AddCustomScrollableMenuCheckbox("Context menu checkbox entry 2 - checked from SV func",
							function(comboBox, itemName, item, checked)
								d('Checkbox clicked at custom context menu entry 2 - checked: ' ..tostring(checked))
								testSV.cboxContextmenu1 = checked
							end,
							function() return testSV.cboxContextmenu1 end)

					AddCustomScrollableMenuEntry("Normal context menu entry 2", function() d('Custom context menu Normal entry 2') end)

					AddCustomScrollableMenuCheckbox("Context menu checkbox entry 3 - checked from SV func",
							function(comboBox, itemName, item, checked)
								d('Checkbox clicked at custom context menu entry 2 - checked: ' ..tostring(checked))
								testSV.cboxContextmenu2 = checked
							end,
							function() return false  end, --should be taken to additionalData.checked and thus always return false!
							{
								checked = function() return testSV.cboxContextmenu2 end
							})

					ShowCustomScrollableMenu(nil, {
						XMLRowHighlightTemplates = {
							[lib.LSM_ENTRY_TYPE_NORMAL] = {
								template = lib.LSM_ROW_HIGHLIGHT_DEFAULT, --"ZO_SelectionHighlight",
								color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
							},
							[lib.LSM_ENTRY_TYPE_SUBMENU] = {
								template = lib.LSM_ROW_HIGHLIGHT_DEFAULT, --"ZO_SelectionHighlight", --Will be replaced with green if submenu entry got callback
								templateSubMenuWithCallback = lib.LSM_ROW_HIGHLIGHT_BLUE,
								color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
							},
							[lib.LSM_ENTRY_TYPE_CHECKBOX] = {
								template = lib.LSM_ROW_HIGHLIGHT_BLUE, --"LibScrollableMenu_Highlight_Blue",
								color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
							},
							[lib.LSM_ENTRY_TYPE_BUTTON] = {
								template = lib.LSM_ROW_HIGHLIGHT_RED, --"LibScrollableMenu_Highlight_Red",
								color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
							},
							[lib.LSM_ENTRY_TYPE_RADIOBUTTON] = {
								template = lib.LSM_ROW_HIGHLIGHT_OPAQUE, --"LibScrollableMenu_Highlight_White",
								color = CUSTOM_HIGHLIGHT_TEXT_COLOR,
							},
						},
					})
				end,
				isNew			= true,
				--entries         = submenuEntries,
				--tooltip         =
			},
			{
				--isHeader		= function() return true  end,
				name            = "Header entry 1 - LSM_ENTRY_TYPE_HEADER",
				icon 			= "/esoui/art/inventory/inventory_trait_ornate_icon.dds",
				--icon 	     = nil,
				entryType	= LSM_ENTRY_TYPE_HEADER,
			},
			{
				isCheckbox		= function() isCheckBoxNow2 = not isCheckBoxNow2 d("isCheckBoxNow2 = " ..tostring(isCheckBoxNow2)) return isCheckBoxNow2 end,
				name            = "Checkbox entry 1 - isCheckbox func",
				icon 			= "/esoui/art/inventory/inventory_trait_ornate_icon.dds",
				callback        =   function(comboBox, itemName, item, checked)
					d("Checkbox entry 1 - checked: " ..tostring(checked))
				end,
				--	tooltip         = function() return "Checkbox entry 1"  end
				tooltip         = "Checkbox entry 1"
			},
			{
				name            = "-", --Divider
			},
			{
				isCheckbox		= true,
				name            = "Checkbox entry 2 - isCheckbox bool = true",
				callback        =   function(comboBox, itemName, item, checked)
					d("Checkbox entry 2 - checked: " ..tostring(checked))
				end,
				checked			= true, -- Confirmed does start checked.
				--tooltip         = function() return "Checkbox entry 2" end
				tooltip         = "Checkbox entry 2"
			},
			{
				name            = "-", --Divider
			},
			{
				name            = "Normal entry 4 - entryType func",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 4")
				end,
				entryType = function()
					return LSM_ENTRY_TYPE_NORMAL
				end,
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 4"  end
				tooltip         = "Normal entry 4"
			},
			{
				name            = "Normal entry 5 with 3 icon",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 5")
				end,
				icon =			{ "/esoui/art/inventory/inventory_trait_ornate_icon.dds", "EsoUI/Art/Inventory/inventory_trait_intricate_icon.dds", "EsoUI/Art/Inventory/inventory_trait_not_researched_icon.dds" },
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 5"  end
				tooltip         = "Normal entry 5"
			},
			{
				name            = "Submenu entry 6",
				--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem) d("Submenu entry 6") end,
				entries         = {
					{

						name            = "Normal entry 6 1:1 - context menu with divider tests",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:1")
						end,
						tooltip         = "Submenu Entry Test 6 1:1 - context menu with divider tests",
						icon 			= { [1] = function() return "EsoUI/Art/Inventory/inventory_trait_reconstruct_icon.dds" end },
						contextMenuCallback         =   function(self)
							d("contextMenuCallback Submenu Entry Test 6 1:1")
							ClearCustomScrollableMenu()

							AddCustomScrollableMenuEntry("Normal context menu at submenu entry6 1:1 - 1", function() d("Normal context menu at submenu entry6 1:1 - 1") end)
							AddCustomScrollableMenuEntry("-")
							AddCustomScrollableMenuEntry("Normal context menu at submenu entry6 1:1 - 2", function() d("Normal context menu at submenu entry6 1:1 - 2") end)
							AddCustomScrollableMenuEntry("divider test", nil, nil, nil, { isDivider = true })
							AddCustomScrollableMenuEntry("Normal context menu at submenu entry6 1:1 - 3", function() d("Normal context menu at submenu entry6 1:1 - 3") end)
							AddCustomScrollableMenuDivider()
							AddCustomScrollableMenuEntry("Normal context menu at submenu entry6 1:1 - 4", function() d("Normal context menu at submenu entry6 1:1 - 4") end)
							AddCustomScrollableMenuEntry(nil, nil, nil, nil, { isDivider = true })
							AddCustomScrollableMenuEntry("Normal context menu at submenu entry6 1:1 - 5", function() d("Normal context menu at submenu entry6 1:1 - 5") end)
							AddCustomScrollableMenuEntry(nil, nil, nil, nil, { entryType = LSM_ENTRY_TYPE_DIVIDER })
							AddCustomScrollableMenuEntry("Normal context menu at submenu entry6 1:1 - 5", function() d("Normal context menu at submenu entry6 1:1 - 5") end)
							AddCustomScrollableMenuEntry(nil, nil, nil, nil, { label = "test header in context menu", isHeader = true })
							AddCustomScrollableMenuEntry("Normal context menu at submenu entry6 1:1 - 5", function() d("Normal context menu at submenu entry6 1:1 - 5") end)

							local optionsContextMenu = {
								visibleRowsDropdown = 3,
								visibleRowsSubmenu = 3,
								maxDropdownHeight = 300,

								--sortEntries=function() return false end,
								disableFadeGradient = true,
								--headerColor = HEADER_TEXT_COLOR_RED,
								--titleText = function()  return "Custom title text" end,
								--subtitleText = "Custom sub title",
								enableFilter = true,
							}
							ShowCustomScrollableMenu(nil, optionsContextMenu)
						end,
					},
					{

						name            = "Submenu entry 6 1:1",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:2")
						end,
						tooltip         = "Submenu entry 6 1:2",
						entries         = {
							{

								name            = "Submenu entry 6 2:1",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:1")
								end,
								--tooltip         = "Submenu Entry Test 1",
								--icon 			= nil,
							},
							{

								name            = "Submenu entry 6 2:2",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:2")
								end,
								tooltip         = "Submenu entry 6 2:2",
								entries         = {
									{

										name            = "Normal entry 6 2:2:1",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:1")
										end,
										--tooltip         = "Submenu Entry Test 1",
										--icon 			= nil,
									},
									{

										name            = "Normal entry 6 2:2:2",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:2")
										end,
										tooltip         = "Normal entry 6 2:2",
										isNew			= true,
										--icon 			= nil,
									},
								},
							},
						},
					},
					{

						name            = "Normal entry 6 1:2",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Normal entry 6 1:2")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icon 			= nil,
					},
				},
				--	tooltip         = function() return "Submenu entry 6"  end
				tooltip         = "Submenu entry 6"
			},
			{
				name            = "Normal entry 7",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 7")
				end,
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 7"  end
				tooltip         = "Normal entry 7"
			},
			{
				name            = "Normal entry 8- enabled = func",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 8")
				end,
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 8"  end
				tooltip         = "Normal entry 8",
				enabled 		= function() isEnabledNow = not isEnabledNow return isEnabledNow  end
			},
			{
				name            = "Normal entry 9 - enabled false (boolean)",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 9")
				end,
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 9"  end
				tooltip         = "Normal entry 9",
				enabled 		= false,
			},
			{
				name            = "Normal entry 10 - Very long text here at this entry!",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 10")
				end,
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 10"  end
				tooltip         = "Normal entry 10"
			}
		}

		--Add the entries (menu and submenu) to the combobox
		comboBox:AddItems(comboBoxMenuEntries)
		--scrollHelper:AddItems(comboBoxMenuEntries)

		local entryMap = {}
		-- Recursively maps all combobox entries and submenu entries created by the addon to use for comparing data sent from one of the callbacks.
		-- entries are mapped by entryMap[data]
		-- data = { -- not limited to...
		--	name            = name __string__,
		--	callback        = callback __function__,
		--	tooltip         = tooltip __string or function?__,
		--}
		lib:MapEntries(comboBoxMenuEntries, entryMap)

		comboBox.entryMap = entryMap
		-- This example callback is checking if the data matches a new combobox entry from this addon.
		lib:RegisterCallback('NewStatusUpdated', function(data, entry)
			-- Callback is fired on mouse-over previously new entries
			if entryMap[data] ~= nil then
				entryMap[data].isNew = false
				-- Belongs to this addon
			end
		end)

		-- This example callback is checking if the data matches a checkbox entry from this addon.
		lib:RegisterCallback('CheckboxUpdated', function(checked, data, checkbox)
			-- Callback is fired on checkbox checked state change
			if entryMap[data] ~= nil then
				-- Belongs to this addon
			end
		end)


		--Custom scrollable context menu

		--DOES NOT WORK
		ZO_PlayerInventoryTabsActive:SetMouseEnabled(true)
		ZO_PlayerInventoryTabsActive:SetHandler("OnMouseUp", function(ctrl, button, upInside)
			d(debugPrefix .. "ZO_PlayerInventoryTabsActive - OnMouseUp")
			if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
				ClearCustomScrollableMenu()

				local entries = {
					{
						name = "Test",
						label = "Test!!!",
						callback = function()  d("test") end,
					}
				}
				AddCustomScrollableMenu(entries, {sortEntries=false})


				AddCustomScrollableMenuEntry("Normal entry 2", function()
					d('Custom menu Normal entry 2')
				end)

				AddCustomScrollableMenuDivider()

				AddCustomScrollableMenuEntry("Normal entry 1", function()
					d('Custom menu Normal entry 1')
				end)

				local entriesSubmenu = {
					{
						label = "Test submenu entry 1",
						name =  "Test submenu data 1",
						callback = function()  d("Test submenu entry 1") end,
					}
				}
				AddCustomScrollableMenuEntry("Test submenu", nil, lib.LSM_ENTRY_TYPE_NORMAL, entriesSubmenu)

				--SetCustomScrollableMenuOptions({sortEntries=true})

				ShowCustomScrollableMenu()
			end
		end)


		--DOES WORK
		ZO_PreHookHandler(ZO_PlayerInventoryMenuBarButton1, "OnMouseUp", function(ctrl, button, upInside)
			d(debugPrefix .. "ZO_PlayerInventoryMenuBarButton1 - OnMouseUp")
			if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
				ClearCustomScrollableMenu()

				local entries = {
					{
						name = "Test 2",
						callback = function()  d("test") end,
					}
				}
				AddCustomScrollableMenu(entries, nil)


				AddCustomScrollableMenuEntry("Normal entry 2 - 2", function()
					d('Custom menu Normal entry 2')
				end)

				AddCustomScrollableMenuEntry("Normal entry 1 - 2", function()
					d('Custom menu Normal entry 1')
				end)

				ShowCustomScrollableMenu(nil, {sortEntries=true})
			end
		end)

	end


	local testTLC = lib.testComboBoxContainer:GetOwningWindow()
	--local testTLC = comboBox:GetParent()
	if testTLC:IsHidden() then
		testTLC:SetHidden(false)
		testTLC:SetMouseEnabled(true)
	else
		testTLC:SetHidden(true)
		testTLC:SetMouseEnabled(false)
	end
end
lib.Test = test


local optionsVisibleRowsCurrent = 10
local optionsDisableFadeGradient = false
local function test2()
	if lib.testComboBoxContainer == nil then return end
	local comboBox = lib.testComboBoxContainer
	if comboBox then
		if optionsVisibleRowsCurrent == 10 then
			optionsVisibleRowsCurrent = 15
		else
			optionsVisibleRowsCurrent = 10
		end
d(debugPrefix .. "Test2 - Updating options- toggling visibleRows to: " ..tostring(optionsVisibleRowsCurrent) .. ", disableFadeGradient to: " ..tostring(optionsDisableFadeGradient))

		if optionsDisableFadeGradient then
			optionsDisableFadeGradient = false
		else
			optionsDisableFadeGradient = true
		end
		local optionsNew = {
			visibleRowsDropdown = optionsVisibleRowsCurrent,
			visibleRowsSubmenu = optionsVisibleRowsCurrent,
			disableFadeGradient = optionsDisableFadeGradient,
			sortEntries=function() return false end,
			--narrate = narrateOptions,
		}

		SetCustomScrollableMenuOptions(optionsNew, comboBox)
	end
end
lib.Test2 = test2

--test()
--	/script LibScrollableMenu.Test()

--Create LSM test UI and TLC
SLASH_COMMANDS["/lsmtest"] = function() lib.Test() end

--Update LSM test UI combobox with new options
SLASH_COMMANDS["/lsmtest2"] = function() lib.Test2() end



--[[
What should happen if a combobox's dropdown entry / submenu entry / nested submenu entry, or a context menu at any of these entries,
is selected:

[ Comobox ]

Dropdown 1
 _________________		Submenu dropdown 1
| 1 Normal entry |	 _____________________
| 2 Submenu    > |	| 4 Submenu Entry    |	 Nested submenu dropdown 1
|_3 Submenu_____|   |_5 Nested Submenu_ >|   ________________________
											| 6 Nested Submenu Entry |
											__________________________


1)  OnSelected: Close Dropdown 1
	OnContextMenu:
Cntxt. Dropdown 1
 _________________		Cntxt. Submenu dropdown 1
| 7 Normal entry |	 _____________________
| 8 Submenu    > |	| 10 Submenu Entry    |	 Cntxt. Nested submenu dropdown 1
|_9 Submenu_____|   |_11 Nested Submenu_ >|  ________________________
											| 12 Nested Submenu Entry |
											__________________________
 OnContextEntrySelected (7-12): Close Cntxt [(Nested) submenu] dropdown 1
 Keep Dropdown 1 opened (no matter if moc() == Dropdown 1 control or not)
 Keep all other (nested) submenus and dropdowns opened too.

2) OnSelected: If entry got a callback: Close Dropdown 1
3) OnSelected: If entry got a callback: Close Dropdown 1
4) OnSelected: Close Submenu dropdown 1, close Dropdown 1
5) OnSelected: If entry got a callback: Close Submenu dropdown 1, close Dropdown 1
6) OnSelected: Close Nested submenu dropdown, close Submenu dropdown 1, close Dropdown 1
	OnContextMenu:
Cntxt. Dropdown 2
 _________________		Cntxt. Submenu dropdown 2
| 13 Normal entry |	 _____________________
| 14 Submenu    > |	| 16 Submenu Entry    |	 Cntxt. Nested submenu dropdown 2
|_15 Submenu_____|  |_17 Nested Submenu_ >|  ________________________
											| 18 Nested Submenu Entry |
											__________________________
 OnContextEntrySelected (13-18): Close Cntxt [(Nested) submenu] dropdown 2
 Keep Nested Submenu dropdown 1 opened (no matter if moc() == Nested submenu dropdown 1 or not.
 Keep all other (nested) submenus and dropdowns opened too.

]]