local lib = LibScrollableMenu
local MAJOR = lib.name

------------------------------------------------------------------------------------------------------------------------
-- For testing - Combobox with all kind of entry types (test offsets, etc.)
------------------------------------------------------------------------------------------------------------------------
local function test()
	if lib.testComboBoxContainer == nil then
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

		local options = {
			visibleRowsDropdown = 10,
			visibleRowsSubmenu = 10,
			sortEntries=function() return false end,
			narrate = narrateOptions,
			disableFadeGradient = false,
			headerColor = HEADER_TEXT_COLOR_RED,
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
				[lib.scrollListRowTypes.ENTRY_ID] = {
					template = "LibScrollableMenu_ComboBoxEntry_TestXMLRowTemplates",
					rowHeight = 40,
					setupFunc = function(control, data, list)
						local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer) -- comboBoxContainer = The ZO_ComboBox control you created via WINDOW_MANAGER:CreateControlFromVirtual("NameHere", yourTopLevelControlToAddAsAChild, "ZO_ComboBox")
						comboBox:SetupEntryLabel(control, data, list)
					end,
				}
			}

			]]
		}

		--Try to change the options of the scrollhelper as it gets created
		--[[
		lib:RegisterCallback('OnDropdownMenuAdded', function(comboBox, optionsPassedIn)
--d("[LSM]TEST - Callback fired: OnDropdownMenuAdded - current visibleRows: " ..tostring(optionsPassedIn.visibleRowsDropdown))
			optionsPassedIn.visibleRowsDropdown = 5 -- Overwrite the visible rows at the dropdown
--d("<visibleRows after: " ..tostring(optionsPassedIn.visibleRowsDropdown))
		end)
		]]

		--Create a scrollHelper then and reference your ZO_ComboBox, plus pass in the options
		--After that build your menu entres (see below) and add them to the combobox via :AddItems(comboBoxMenuEntries)
		local scrollHelper = AddCustomScrollableComboBoxDropdownMenu(testTLC, comboBoxContainer, options)
		-- did not work		scrollHelper.OnShow = function() end --don't change parenting


		--Prepare and add the text entries in the dropdown's comboBox

		local subEntries = {

			{
				
				name            = "Submenu entry 1:1",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry 1:1")
				end,
				--tooltip         = "Submenu Entry Test 1",
				--icons 			= nil,
			},
			{
				name            = "-",
			},
			{
				
				name            = "Submenu entry 1:2",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry 1:2")
				end,
				tooltip         = "Submenu entry 1:2",
				isNew			= true,
				--icons 			= nil,
			}
		}

		--LibScrollableMenu - LSM entry - Submenu normal
		local submenuEntries = {
			{
				
				name            = "Submenu Entry Test 1",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 1")
				end,
				contextMenuCallback =   function(self)
					d("contextMenuCallback")
					ClearCustomScrollableMenu()

					AddCustomScrollableSubMenuEntry("Submenu entry 1", subEntries)

					AddCustomScrollableMenuEntry("Custom menu Normal entry 1", function() d('Custom menu Normal entry 1') end)

					AddCustomScrollableMenuEntry("Custom menu Normal entry 2", function() d('Custom menu Normal entry 2') end)

					ShowCustomScrollableMenu(nil, { narrate = narrateOptions, })
					d("Submenu entry 1")
				end,
				--tooltip         = "Submenu Entry Test 1",
				--icons 			= nil,
			},
			{
				
				name            = "Submenu Entry Test 2",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 2")
				end,
				tooltip         = "Submenu Entry Test 2",
				isNew			= true,
				--icons 			= nil,
			},
			{
				isCheckbox		= function() return true  end,
				name            = "Checkbox entry 1",
				icon 			= "/esoui/art/inventory/inventory_trait_ornate_icon.dds",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Checkbox entry 1")
				end,
				--	tooltip         = function() return "Checkbox entry 1"  end
				tooltip         = "Checkbox entry 1"
			},
			{
				name            = "-", --Divider
			},
			{
				isCheckbox		= true,
				name            = "Checkbox entry 2",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Checkbox entry 2")
				end,
				checked			= true, -- Confirmed does start checked.
				--tooltip         = function() return "Checkbox entry 2" end
				tooltip         = "Checkbox entry 2"
			},
			{
				name            = "-", --Divider
			},
			--LibScrollableMenu - LSM entry - Submenu divider
			{
				name            = "-",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					--Headers do not use any callback
				end,
				tooltip         = "Submenu Divider Test 1",
				--icons 			= nil,
			},
			{
				
				name            = "Submenu Entry Test 3",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 3")
				end,
				isNew			= true,
				--tooltip         = "Submenu Entry Test 3",
				--icons 			= nil,
			},
			{
				isHeader        = true, --Enables the header at LSM
				name            = "Header Test 1",
				icon			= "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_Staff_Frost_Up.dds",
				tooltip         = "Header test 1",
				--icons 			= nil,
			},
			{
				
				name            = "Submenu Entry Test 4",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 4")
				end,
				tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				
				name            = "Submenu Entry Test 5",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 5")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
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
						--icons 			= nil,
					},
					{
						
						name            = "Submenu entry 6 1:2",
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
								--icons 			= nil,
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
										--icons 			= nil,
									},
									{
										
										name            = "Normal entry 6 2:2",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:2")
										end,
										tooltip         = "Normal entry 6 2:2",
										isNew			= true,
										--icons 			= nil,
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
						--icons 			= nil,
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
				--icons 			= nil,
			},
			{
				
				name            = "Submenu Entry Test 8",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 8")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				
				name            = "Submenu Entry Test 9",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 9")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				
				name            = "Submenu Entry Test 10",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 10")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			}
		}

		--Normal entries
		local wasNameChangedAtEntry = false
		local wasLabelChangedAtEntry = false
		local comboBoxMenuEntries = {
			{
				name            = function()
					if not wasNameChangedAtEntry then
						wasNameChangedAtEntry = true
						return "Normal entry 1"
					else
						wasNameChangedAtEntry = false
						return "Normal entry 1 - Changed"
					end
				end,
				--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				callback        =   function(self)
					d("Normal entry 1")
				end,
				contextMenuCallback =   function(self)
					d("contextMenuCallback")
					ClearCustomScrollableMenu()
					AddCustomScrollableSubMenuEntry("Context menu entry 1", subEntries)
					AddCustomScrollableMenuEntry("Context menu Normal entry 1", function() d('Context menu Normal entry 1') end)
					AddCustomScrollableMenuEntry("Context menu Normal entry 2", function() d('Context menu Normal entry 2') end)
					ShowCustomScrollableMenu()
				end,
				icon			= "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_Staff_Frost_Up.dds",
				isNew			= true,
				--entries         = submenuEntries,
				--tooltip         =
			},
			{
				name            = "-", --Divider
			},
			{
				name            = "Name value", --no name test
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
			},
			{
				name            = "-", --Divider
			},
			{
				name            = "Entry having submenu 1",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Entry having submenu 1")
				end,
				entries         = submenuEntries,
				tooltip         = 'Submenu test tooltip.'
			},
			{
				name            = "Normal entry 2",
				--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				callback        =   function(self)
					d("Normal entry 2")
				end,
				contextMenuCallback         =   function(self)
					d("Normal entry 2")
					ClearCustomScrollableMenu()

					AddCustomScrollableMenuEntry("Normal entry 2", function() d('Custom menu Normal entry 2') end)

					ShowCustomScrollableMenu(self)
				end,
				isNew			= true,
				--entries         = submenuEntries,
				--tooltip         =
			},
			{
				isHeader		= function() return true  end,
				name            = "Header entry 1",
				icon 			= "/esoui/art/inventory/inventory_trait_ornate_icon.dds",
				--icons 	     = nil,
			},
			{
				isCheckbox		= function() return true  end,
				name            = "Checkbox entry 1",
				icon 			= "/esoui/art/inventory/inventory_trait_ornate_icon.dds",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Checkbox entry 1")
				end,
				--	tooltip         = function() return "Checkbox entry 1"  end
				tooltip         = "Checkbox entry 1"
			},
			{
				name            = "-", --Divider
			},
			{
				isCheckbox		= true,
				name            = "Checkbox entry 2",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Checkbox entry 2")
				end,
				checked			= true, -- Confirmed does start checked.
				--tooltip         = function() return "Checkbox entry 2" end
				tooltip         = "Checkbox entry 2"
			},
			{
				name            = "-", --Divider
			},
			{
				name            = "Normal entry 4",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 4")
				end,
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 4"  end
				tooltip         = "Normal entry 4"
			},
			{
				name            = "Normal entry 5",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 5")
				end,
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 5"  end
				tooltip         = "Normal entry 5"
			},
			{
				name            = "Submenu entry 6",
				--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem) d("Submenu entry 6") end,
				entries         = {
					{
						
						name            = "Normal entry 6 1:1",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:1")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icons 			= nil,
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
								--icons 			= nil,
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
										--icons 			= nil,
									},
									{
										
										name            = "Normal entry 6 2:2",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:2")
										end,
										tooltip         = "Normal entry 6 2:2",
										isNew			= true,
										--icons 			= nil,
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
						--icons 			= nil,
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
				name            = "Normal entry 8",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 8")
				end,
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 8"  end
				tooltip         = "Normal entry 8"
			},
			{
				name            = "Normal entry 9",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 9")
				end,
				--entries         = submenuEntries,
				--	tooltip         = function() return "Normal entry 9"  end
				tooltip         = "Normal entry 9"
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
			d("[LSM]ZO_PlayerInventoryTabsActive - OnMouseUp")
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
		ZO_PlayerInventoryMenuBarButton1:SetHandler("OnMouseUp", function(ctrl, button, upInside)
			d("[LSM]ZO_PlayerInventoryMenuBarButton1 - OnMouseUp")
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
d("[LSM]Test2 - Updating options- toggling visibleRows to: " ..tostring(optionsVisibleRowsCurrent) .. ", disableFadeGradient to: " ..tostring(optionsDisableFadeGradient))

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
