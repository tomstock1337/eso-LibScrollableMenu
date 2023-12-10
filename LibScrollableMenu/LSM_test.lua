local lib = LibScrollableMenu
local MAJOR = lib.name

------------------------------------------------------------------------------------------------------------------------
-- For testing - Combobox with all kind of entry types (test offsets, etc.)
------------------------------------------------------------------------------------------------------------------------
local function test()
	if lib.testDropdown == nil then
		local testTLC = CreateTopLevelWindow(MAJOR .. "TestTLC")
		testTLC:SetHidden(true)
		testTLC:SetDimensions(1, 1)
		testTLC:SetAnchor(CENTER, GuiRoot, CENTER)
		testTLC:SetMovable(true)
		testTLC:SetMouseEnabled(false)

		local dropdown = WINDOW_MANAGER:CreateControlFromVirtual(MAJOR .. "TestDropdown", testTLC, "ZO_ComboBox")
		dropdown:SetAnchor(LEFT, testTLC, LEFT, 10, 0)
		dropdown:SetHeight(24)
		dropdown:SetWidth(250)
		dropdown:SetMovable(true)

		--Define your options for the scrollHelper here
		-->For all possible option values check API function "AddCustomScrollableComboBoxDropdownMenu" description at file
		-->LibScrollableMenu.lua
		local options = { visibleRowsDropdown = 10, visibleRowsSubmenu = 5, sortEntries=function() return false end, }
		--Create a scrollHelper then and reference your ZO_ComboBox, plus pass in the options
		--After that build your menu entres (see below) and add them to the combobox via :AddItems(comboBoxMenuEntries)
		local scrollHelper = AddCustomScrollableComboBoxDropdownMenu(testTLC, dropdown, options)

-- did not work		scrollHelper.OnShow = function() end --don't change parenting

		lib.testDropdown = dropdown

		--Prepare and add the text entries in the dropdown's comboBox
		local comboBox = dropdown.m_comboBox

		--LibScrollableMenu - LSM entry - Submenu normal
		local submenuEntries = {
			{
				isHeader        = false,
				name            = "Submenu Entry Test 1",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 1")
				end,
				--tooltip         = "Submenu Entry Test 1",
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 2",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 2")
				end,
				tooltip         = "Submenu Entry Test 2",
				isNew			= true,
				--icons 			= nil,
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
				isHeader        = false,
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
				isHeader        = false,
				name            = "Submenu Entry Test 4",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 4")
				end,
				tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				isHeader        = false,
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
						isHeader        = false,
						name            = "Normal entry 6 1:1",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:1")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icons 			= nil,
					},
					{
						isHeader        = false,
						name            = "Submenu entry 6 1:2",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:2")
						end,
						tooltip         = "Submenu entry 6 1:2",
						entries         = {
							{
								isHeader        = false,
								name            = "Submenu entry 6 2:1",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:1")
								end,
								--tooltip         = "Submenu Entry Test 1",
								--icons 			= nil,
							},
							{
								isHeader        = false,
								name            = "Submenu entry 6 2:2",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:2")
								end,
								tooltip         = "Submenu entry 6 2:2",
								entries         = {
									{
										isHeader        = false,
										name            = "Normal entry 6 2:1",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:1")
										end,
										--tooltip         = "Submenu Entry Test 1",
										--icons 			= nil,
									},
									{
										isHeader        = false,
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
						isHeader        = false,
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
				isHeader        = false,
				name            = "Submenu Entry Test 7",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 7")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 8",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 8")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 9",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 9")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 10",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 10")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			}
		}

		--Normal entries
		local comboBoxMenuEntries = {
			{
				name            = "Normal entry 1",
			--	callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				callback        =   function(self)
					d("Normal entry 1")
				end,
				contextMenuCallback =   function(self)
					d("Normal entry 1")
					ClearCustomScrollableMenu()
					
					AddCustomScrollableMenuEntry("Normal entry 1", function() d('Custom menu Normal entry 1') end)
					
					AddCustomScrollableMenuEntry("Normal entry 2", function() d('Custom menu Normal entry 2') end)
					
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
				name            = "Entry having submenu 1",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Entry having submenu 1")
				end,
				entries         = submenuEntries,
				--tooltip         =
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
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry 6")
				end,
				entries         = {
					{
						isHeader        = false,
						name            = "Normal entry 6 1:1",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:1")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icons 			= nil,
					},
					{
						isHeader        = false,
						name            = "Submenu entry 6 1:1",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:2")
						end,
						tooltip         = "Submenu entry 6 1:2",
						entries         = {
							{
								isHeader        = false,
								name            = "Submenu entry 6 2:1",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:1")
								end,
								--tooltip         = "Submenu Entry Test 1",
								--icons 			= nil,
							},
							{
								isHeader        = false,
								name            = "Submenu entry 6 2:2",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:2")
								end,
								tooltip         = "Submenu entry 6 2:2",
								entries         = {
									{
										isHeader        = false,
										name            = "Normal entry 6 2:1",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:1")
										end,
										--tooltip         = "Submenu Entry Test 1",
										--icons 			= nil,
									},
									{
										isHeader        = false,
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
						isHeader        = false,
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


		local entryMap = {}
		-- Recursively maps all combobox entries and submenu entries created by the addon to use for comparing data sent from one of the callbacks.
		-- entries are mapped by entryMap[data]
		-- data = { -- not limited to...
		--	name            = name __string__,
		--	callback        = callback __function__,
		--	tooltip         = tooltip __string or function?__,
		--}
		lib:MapEntries(comboBoxMenuEntries, entryMap)

		-- This example callback is checking if the data matches a new combobox entry from this addon.
		lib:RegisterCallback('NewStatusUpdated', function(data, entry)
			-- Callback is fired on mouse-over previously new entries
			if entryMap[data] ~= nil then
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
		ZO_PlayerInventoryTabsActive:SetMouseEnabled(true)
		ZO_PlayerInventoryTabsActive:SetHandler("OnMouseUp", function(ctrl, button, upInside)
	d("[LSM]ZO_PlayerInventoryTabsActive - OnMouseUp")
			if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
				ClearCustomScrollableMenu()

				AddCustomScrollableMenuEntry("Normal entry 1", function()
					d('Custom menu Normal entry 1')
				end)

				AddCustomScrollableMenuEntry("Normal entry 2", function()
					d('Custom menu Normal entry 2')
				end)

				ShowCustomScrollableMenu()


				--[[
				ClearCustomScrollableMenu()

				AddCustomScrollableMenu(ZO_PlayerInventoryTabsActive, {
					{
						isHeader        = false,
						name            = "Submenu Entry Test 7",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Custom scrollable context menu entry test 1")
						end,
					},
					{
						isHeader        = false,
						name            = "Submenu Entry Test 8",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Custom scrollable context menu entry test 1")
						end,
					}
				},
				nil)
				ShowCustomScrollableMenu() --ZO_PlayerInventoryTabsActive
				]]
			end
		end)

	end

	local dropdown = lib.testDropdown
	local testTLC = dropdown:GetParent()
	if testTLC:IsHidden() then
		testTLC:SetHidden(false)
		testTLC:SetMouseEnabled(true)
	else
		testTLC:SetHidden(true)
		testTLC:SetMouseEnabled(false)
	end
end
lib.Test = test
--	/script LibScrollableMenu.Test()
SLASH_COMMANDS["/lsmtest"] = function() lib.Test() end