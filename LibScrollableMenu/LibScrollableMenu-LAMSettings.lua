--------------------------------------------------------------------
-- LibScrollableMenu - Support for ZO_Menu (including LibCustomMenu)

local lib = LibScrollableMenu
if lib == nil then return end


--local ZOs references
local tos = tostring

--Local libray references
local MAJOR = lib.name

local comboBoxDefaults = lib.comboBoxDefaults

local sv = lib.SV


--Other libraries
local LAM2 = lib.LAM2 or LibAddonMenu2


------------------------------------------------------------------------------------------------------------------------
--LAM settings menu - local helper functions
------------------------------------------------------------------------------------------------------------------------
local existingOwnerNamesList
local function buildExistingOwnerNamesList()
	local existingOwnerNamesListLoc = {}
	sv = lib.SV
	if sv and sv.contextMenuSettings ~= nil then
		for ownerControlName, _ in pairs(sv.contextMenuSettings) do
			existingOwnerNamesListLoc[#existingOwnerNamesListLoc + 1] = ownerControlName
		end
	end
	return existingOwnerNamesListLoc
end

local function updateExistingOwerNamesList(noLAMControlUpdate)
	noLAMControlUpdate = noLAMControlUpdate or false
	existingOwnerNamesList = buildExistingOwnerNamesList()

	if not noLAMControlUpdate then
		if LSM_LAM_DROPDOWN_SELECTED_EXISTING_OWNER_NAME ~= nil then
			LSM_LAM_DROPDOWN_SELECTED_EXISTING_OWNER_NAME:UpdateChoices(existingOwnerNamesList)
		end
	end
end


------------------------------------------------------------------------------------------------------------------------
-- LibAddonMenu - Settings menu for LibScrollableMenu
------------------------------------------------------------------------------------------------------------------------
function lib.BuildLAMSettingsMenu()
	LAM2 = LAM2 or LibAddonMenu2
	if LAM2 == nil then return end

	--Add the LAM settings menufor the library to e.g. control the default values for visibleRows of all contextMenus, or
	--change those for contextMenu's ownerNames (e.g. the ZO_PlayerInventory)
	local panelData = {
		type = "panel",
		name = MAJOR,
		displayName = MAJOR,
		author = lib.author,
		version = lib.version,
		slashCommand = "/lsmsettings",
		registerForRefresh = true,
		registerForDefaults = false,
	}
    local LSMLAMPanelName = MAJOR .. "_LAMSettings"

	lib.LAMsettingsPanel = LAM2:RegisterAddonPanel(LSMLAMPanelName, panelData)
	sv = lib.SV

	local contextMenuOwnerControlName, selectedExistingOwnerName, newVisibleRowsForControlName, newVisibleRowsSubmenuForControlName
	updateExistingOwerNamesList(true)

	local optionsData = {
		{
			type = "header",
			name = MAJOR,
		},
		{
			type = "description",
			title = "Context menus",
			text = "Test description here\n\ntest test test\n\n\nbla blubb",
		},
		{
			type = "checkbox",
			name = "Replace all ZO_Menu context menus",
			tooltip = "Replace the context menus (ZO_Menu, LibCustomMenu) with LibScrolableMenu's scrollable context menu",
			getFunc = function() return sv.ZO_MenuContextMenuReplacement end,
			setFunc = function(checked)
				--sv.ZO_MenuContextMenuReplacement = checked
				lib.ContextMenuZO_MenuReplacement(checked, false) -- show chat output
			end,
			--disabled = function() return false end,
			default = false,
			reference = "LSM_LAM_CHECKBOX_REPLACE_ZO_MENU_CONTEXTMENUS"
		},
        {
            type = "editbox",
            name = "Owner control name",
            tooltip = "Enter here the control name of a context menu owner, e.g. ZO_PlayerInventory",
            getFunc = function() return contextMenuOwnerControlName end,
            setFunc = function(newValue)
				contextMenuOwnerControlName = newValue
				if contextMenuOwnerControlName ~= "" then
					if _G[contextMenuOwnerControlName] == nil then
						d("["..MAJOR.."]ERROR - Control " .. tos(contextMenuOwnerControlName) .." does not globally exist!")
						contextMenuOwnerControlName = nil
						selectedExistingOwnerName = nil
						newVisibleRowsForControlName = nil
						newVisibleRowsSubmenuForControlName = nil
					else
						newVisibleRowsForControlName = (sv.contextMenuSettings and sv.contextMenuSettings[contextMenuOwnerControlName] and sv.contextMenuSettings[contextMenuOwnerControlName]["visibleRows"]) or comboBoxDefaults.visibleRows
						newVisibleRowsSubmenuForControlName = (sv.contextMenuSettings and sv.contextMenuSettings[contextMenuOwnerControlName] and sv.contextMenuSettings[contextMenuOwnerControlName]["visibleRowsSubmenu"]) or comboBoxDefaults.visibleRowsSubmenu
					end
				else
					contextMenuOwnerControlName = nil
					selectedExistingOwnerName = nil
					newVisibleRowsForControlName = nil
					newVisibleRowsSubmenuForControlName = nil
				end
			end,
            disabled = function() return false end,
			width = "full",
			default = "",
        },
        {
            type = "slider",
            name = "Visible rows #",
            tooltip = "Enter the number of visible rows at the contextmenu of the owner's controlName",
            getFunc = function()
				return newVisibleRowsForControlName or comboBoxDefaults.visibleRows
			end,
            setFunc = function(newValue)
				newVisibleRowsForControlName = newValue
            end,
			step = 1,
			min = 5,
			max = 30,
            disabled = function() return contextMenuOwnerControlName == nil or contextMenuOwnerControlName == "" end,
			width = "half",
			default = comboBoxDefaults.visibleRows,
        },
        {
            type = "slider",
            name = "Visible rows #, submenus",
            tooltip = "Enter the number of visible rows at the contextmenu's submenus of the owner's controlName",
            getFunc = function()
				return newVisibleRowsSubmenuForControlName or comboBoxDefaults.visibleRowsSubmenu
			end,
            setFunc = function(newValue)
				newVisibleRowsSubmenuForControlName = newValue
            end,
			step = 1,
			min = 5,
			max = 30,
            disabled = function() return contextMenuOwnerControlName == nil or contextMenuOwnerControlName == "" end,
			width = "half",
			default = comboBoxDefaults.visibleRowsSubmenu,
        },
        {
            type = "button",
            name = "Apply visibleRows",
            tooltip = "Change the visible rows and visible rows of the submenu for the entered context menu owner's controlName.",
            func = function()
				if contextMenuOwnerControlName ~= nil and (newVisibleRowsForControlName ~= nil or newVisibleRowsSubmenuForControlName ~= nil) then
					--Add the savedvariables update of sv.contextMenuSettings[contextMenuOwnerControlName]
					if newVisibleRowsForControlName ~= nil then
						sv.contextMenuSettings = sv.contextMenuSettings or {}
						sv.contextMenuSettings[contextMenuOwnerControlName] = sv.contextMenuSettings[contextMenuOwnerControlName] or {}
						sv.contextMenuSettings[contextMenuOwnerControlName].visibleRows = newVisibleRowsForControlName
					end
					if newVisibleRowsSubmenuForControlName ~= nil then
						sv.contextMenuSettings = sv.contextMenuSettings or {}
						sv.contextMenuSettings[contextMenuOwnerControlName] = sv.contextMenuSettings[contextMenuOwnerControlName] or {}
						sv.contextMenuSettings[contextMenuOwnerControlName].visibleRowsSubmenu = newVisibleRowsSubmenuForControlName
					end
					contextMenuOwnerControlName = nil
					selectedExistingOwnerName = nil
					newVisibleRowsForControlName = nil
					newVisibleRowsSubmenuForControlName = nil

					updateExistingOwerNamesList(false)
				end
			end,
            disabled = function() return (contextMenuOwnerControlName == nil or contextMenuOwnerControlName == "") or (newVisibleRowsForControlName == nil and newVisibleRowsSubmenuForControlName == nil) end,
        },
        {
            type = "dropdown",
			name = "Already added owner names",
			tooltip = "Choose an already added owner's controlName to change the values, or to delete the saved values in total.",
			choices = existingOwnerNamesList,
			getFunc = function() return selectedExistingOwnerName end,
			setFunc = function(selectedOwnerName)
				selectedExistingOwnerName = selectedOwnerName
				contextMenuOwnerControlName = selectedOwnerName
				newVisibleRowsForControlName = (sv.contextMenuSettings and sv.contextMenuSettings[selectedOwnerName] and sv.contextMenuSettings[selectedOwnerName]["visibleRows"]) or comboBoxDefaults.visibleRows
				newVisibleRowsSubmenuForControlName = (sv.contextMenuSettings and sv.contextMenuSettings[selectedOwnerName] and sv.contextMenuSettings[selectedOwnerName]["visibleRowsSubmenu"]) or comboBoxDefaults.visibleRowsSubmenu
				--[[
				for ownerName, _ in pairs(sv.contextMenuSettings) do
					if ownerName == selectedOwnerName then
						selectedExistingOwnerName = selectedOwnerName
						contextMenuOwnerControlName = selectedOwnerName
                        break
					end
				end
				]]
			end,
            scrollable = true,
			width = "half",
			default = function() return nil end,
			reference = "LSM_LAM_DROPDOWN_SELECTED_EXISTING_OWNER_NAME"
        },
        {
            type = "button",
            name = "Delete control name",
            tooltip = "Delete the selected owner's controlName from the saved controls list",
            func = function()
				if selectedExistingOwnerName ~= nil then
					if sv.contextMenuSettings and sv.contextMenuSettings[selectedExistingOwnerName] ~= nil then
						sv.contextMenuSettings[selectedExistingOwnerName] = nil
					end
					selectedExistingOwnerName = nil
					contextMenuOwnerControlName = nil
					newVisibleRowsForControlName = nil
					newVisibleRowsSubmenuForControlName = nil

					updateExistingOwerNamesList(false)
				end
			end,
            disabled = function() return selectedExistingOwnerName == nil or selectedExistingOwnerName == "" or contextMenuOwnerControlName == nil or contextMenuOwnerControlName == "" or contextMenuOwnerControlName ~= selectedExistingOwnerName end,
        },

	}
	LAM2:RegisterOptionControls(LSMLAMPanelName, optionsData)

    local function openedPanel(panel)
        if panel ~= lib.LAMsettingsPanel then return end

		selectedExistingOwnerName = nil
		contextMenuOwnerControlName = nil
		newVisibleRowsForControlName = nil
		newVisibleRowsSubmenuForControlName = nil

		updateExistingOwerNamesList(false)
    end
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", openedPanel)
end