--------------------------------------------------------------------
-- LibScrollableMenu - Support for ZO_Menu (including LibCustomMenu)

local lib = LibScrollableMenu
if lib == nil then return end


--local ZOs references
local tos = tostring
local trem = table.remove

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


local contextMenuLookupWhiteList = lib.contextMenuLookupLists.whiteList
local contextMenuLookupWhiteListExclusionList = lib.contextMenuLookupLists.whiteListExclusionList
local contextMenuLookupBlackList = lib.contextMenuLookupLists.blackList

local existingWhiteList, existingWhiteListExclusion, existingBlackList
local function buildControlListsNew()
	lib.contextMenuLookupLists.whiteList = {}
	lib.contextMenuLookupLists.whiteListExclusionList = {}
	lib.contextMenuLookupLists.blackList = {}

	local existingWhiteListLoc = {}
	local existingWhiteListExclusionLoc = {}
	local existingBlackListLoc = {}
	sv = lib.SV
	if sv and sv.contextMenuReplacementControls ~= nil then
		for _, controlName in ipairs(sv.contextMenuReplacementControls.whiteList) do
			existingWhiteListLoc[#existingWhiteListLoc + 1] = controlName
			lib.contextMenuLookupLists.whiteList[controlName] = true
		end
		for _, controlName in ipairs(sv.contextMenuReplacementControls.whiteListExclusion) do
			existingWhiteListExclusionLoc[#existingWhiteListExclusionLoc + 1] = controlName
			lib.contextMenuLookupLists.whiteListExclusionList[controlName] = true
		end
		for _, controlName in ipairs(sv.contextMenuReplacementControls.blackList) do
			existingBlackListLoc[#existingBlackListLoc + 1] = controlName
			lib.contextMenuLookupLists.blackList[controlName] = true
		end
	end
	contextMenuLookupWhiteList = lib.contextMenuLookupLists.whiteList
	contextMenuLookupWhiteListExclusionList = lib.contextMenuLookupLists.whiteListExclusionList
	contextMenuLookupBlackList = lib.contextMenuLookupLists.blackList
	return existingWhiteListLoc, existingBlackListLoc, existingWhiteListExclusionLoc
end

local function updateExistingBlackAndWhiteLists(noLAMControlUpdate)
	noLAMControlUpdate = noLAMControlUpdate or false
	existingWhiteList, existingBlackList, existingWhiteListExclusion = buildControlListsNew()

	if not noLAMControlUpdate then
		if LSM_LAM_DROPDOWN_SELECTED_WHITELIST ~= nil then
			LSM_LAM_DROPDOWN_SELECTED_WHITELIST:UpdateChoices(existingWhiteList)
		end
		if LSM_LAM_DROPDOWN_SELECTED_WHITELISTEXCLUSION ~= nil then
			LSM_LAM_DROPDOWN_SELECTED_WHITELISTEXCLUSION:UpdateChoices(existingWhiteListExclusion)
		end
		if LSM_LAM_DROPDOWN_SELECTED_BLACKLIST ~= nil then
			LSM_LAM_DROPDOWN_SELECTED_BLACKLIST:UpdateChoices(existingBlackList)
		end
	end
end
lib.updateExistingBlackAndWhiteLists = updateExistingBlackAndWhiteLists

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
	local selectedContextMenuControlWhitelistEntry, selectedContextMenuControlBlacklistEntry, selectedContextMenuControlWhitelistExclusionEntry, contextMenuListControlName
	updateExistingOwerNamesList(true)
	updateExistingBlackAndWhiteLists(true)

	local optionsData = {
		{
			type = "header",
			name = MAJOR,
		},
		{
			type = "description",
			title = GetString(SI_LSM_LAM_HEADER_CNTXTMENU),
			text = GetString(SI_LSM_LAM_CNTXTMEN_DESC)
		},

		{
			type = "divider",
		},

		{
			type = "checkbox",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_REPLACE),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_REPLACE_TT),
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
			type = "checkbox",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_FIRST_SUB_CALLBACK),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_FIRST_SUB_CALLBACK_TT),
			getFunc = function() return sv.contextMenuReplacementControls.submenuAutoSelectFirstEntry end,
			setFunc = function(checked)
				sv.contextMenuReplacementControls.submenuAutoSelectFirstEntry = checked
			end,
			disabled = function() return not sv.ZO_MenuContextMenuReplacement end,
			default = false,
		},
		{
			type = "checkbox",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_FIRST_SUB_IFONLYONE),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_FIRST_SUB_IFONLYONE_TT),
			getFunc = function() return sv.contextMenuReplacementControls.submenuAutoSelectFirstEntryIfOnlyOne end,
			setFunc = function(checked)
				sv.contextMenuReplacementControls.submenuAutoSelectFirstEntryIfOnlyOne = checked
			end,
			disabled = function() return not sv.ZO_MenuContextMenuReplacement or not sv.contextMenuReplacementControls.submenuAutoSelectFirstEntry end,
			default = false,
		},

		{
			type = "divider",
		},

		{
			type = "checkbox",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_USE_FOR_ALL),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_USE_FOR_ALL_TT),
			getFunc = function() return sv.contextMenuReplacementControls.replaceAll end,
			setFunc = function(checked)
				sv.contextMenuReplacementControls.replaceAll = checked
				selectedContextMenuControlWhitelistEntry = nil
				selectedContextMenuControlWhitelistExclusionEntry = nil
				selectedContextMenuControlBlacklistEntry = nil
			end,
			disabled = function() return not sv.ZO_MenuContextMenuReplacement end,
			default = false,
		},


		{
            type = "slider",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_VIS_ROWS_DEF),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_VIS_ROWS_DEF_TT),
            getFunc = function()
				return sv.contextMenuSettings._Defaults.visibleRows
			end,
            setFunc = function(newValue)
				sv.contextMenuSettings._Defaults.visibleRows = newValue
            end,
			step = 1,
			min = 2,
			max = 30,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement end,
			width = "half",
			default = 20,
        },
        {
            type = "slider",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_VIS_ROWS_SUBMENU_DEF),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_VIS_ROWS_SUBMENU_DEF_TT),
            getFunc = function()
				return sv.contextMenuSettings._Defaults.visibleRowsSubmenu
			end,
            setFunc = function(newValue)
				sv.contextMenuSettings._Defaults.visibleRowsSubmenu = newValue
            end,
			step = 1,
			min = 5,
			max = 30,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement end,
			width = "half",
			default = 20,
        },

		{
			type = "divider",
		},

        {
            type = "editbox",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_OWNER_NAME),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_OWNER_NAME_TT),
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
            disabled = function() return not sv.ZO_MenuContextMenuReplacement end,
			width = "full",
			default = "",
        },
        {
            type = "slider",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_VIS_ROWS),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_VIS_ROWS_TT),
            getFunc = function()
				return newVisibleRowsForControlName or comboBoxDefaults.visibleRows
			end,
            setFunc = function(newValue)
				newVisibleRowsForControlName = newValue
            end,
			step = 1,
			min = 2,
			max = 30,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or (contextMenuOwnerControlName == nil or contextMenuOwnerControlName == "") end,
			width = "half",
			default = comboBoxDefaults.visibleRows,
        },
        {
            type = "slider",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_VIS_ROWS_SUBMENU),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_VIS_ROWS_SUBMENU_TT),
            getFunc = function()
				return newVisibleRowsSubmenuForControlName or comboBoxDefaults.visibleRowsSubmenu
			end,
            setFunc = function(newValue)
				newVisibleRowsSubmenuForControlName = newValue
            end,
			step = 1,
			min = 5,
			max = 30,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or (contextMenuOwnerControlName == nil or contextMenuOwnerControlName == "") end,
			width = "half",
			default = comboBoxDefaults.visibleRowsSubmenu,
        },
        {
            type = "button",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_APPLY_VIS_ROWS),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_APPLY_VIS_ROWS_TT),
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
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or ((contextMenuOwnerControlName == nil or contextMenuOwnerControlName == "") or (newVisibleRowsForControlName == nil and newVisibleRowsSubmenuForControlName == nil)) end,
        },
		{
			type = "dropdown",
			name = GetString(SI_LSM_LAM_CNTXTMEN_ADDED_OWNERS_DD),
			tooltip = GetString(SI_LSM_LAM_CNTXTMEN_ADDED_OWNERS_DD_TT),
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
			sort = "name-up",
			width = "half",
			default = function() return nil end,
			disabled = function() return not sv.ZO_MenuContextMenuReplacement end,
			reference = "LSM_LAM_DROPDOWN_SELECTED_EXISTING_OWNER_NAME"
		},
        {
            type = "button",
            name = GetString(SI_LSM_LAM_CNTXTMEN_DELETE_OWNER),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_DELETE_OWNER_TT),
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
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or (selectedExistingOwnerName == nil or selectedExistingOwnerName == "" or contextMenuOwnerControlName == nil or contextMenuOwnerControlName == "" or contextMenuOwnerControlName ~= selectedExistingOwnerName) end,
        },


		{
			type = "divider",
		},
        {
            type = "editbox",
    		name = GetString(SI_LSM_LAM_CNTXTMEN_LIST_CONTROLNAME),
    		tooltip = GetString(SI_LSM_LAM_CNTXTMEN_LIST_CONTROLNAME_TT),
            getFunc = function() return contextMenuListControlName end,
            setFunc = function(newValue)
				contextMenuListControlName = newValue
				selectedContextMenuControlWhitelistEntry = nil
				selectedContextMenuControlWhitelistExclusionEntry = nil
				selectedContextMenuControlBlacklistEntry = nil
				if contextMenuListControlName ~= "" then
					if _G[contextMenuListControlName] == nil then
						d("["..MAJOR.."]ERROR - Control " .. tos(contextMenuListControlName) .." does not globally exist!")
						contextMenuListControlName = nil
					end
				else
					contextMenuListControlName = nil
				end
			end,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement end,
			width = "full",
			default = "",
        },

        {
            type = "dropdown",
            name = GetString(SI_LSM_LAM_CNTXTMEN_WHITELIST),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_WHITELIST_TT),
			choices = existingWhiteList,
			getFunc = function() return selectedContextMenuControlWhitelistEntry end, -- sv.contextMenuReplacementControls.whiteList
			setFunc = function(entry)
				selectedContextMenuControlWhitelistEntry = entry
				selectedContextMenuControlWhitelistExclusionEntry = nil
				selectedContextMenuControlBlacklistEntry = nil
			end,
            scrollable = true,
			sort = "name-up",
			width = "half",
			default = function() return nil end,
			disabled = function() return not sv.ZO_MenuContextMenuReplacement or sv.contextMenuReplacementControls.replaceAll end,
			reference = "LSM_LAM_DROPDOWN_SELECTED_WHITELIST"
        },
        {
            type = "dropdown",
            name = GetString(SI_LSM_LAM_CNTXTMEN_WHITELISTEXCL),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_WHITELISTEXCL_TT),
			choices = existingWhiteList,
			getFunc = function() return selectedContextMenuControlWhitelistExclusionEntry end, -- sv.contextMenuReplacementControls.whiteListExclusion
			setFunc = function(entry)
				selectedContextMenuControlWhitelistExclusionEntry = entry
				selectedContextMenuControlWhitelistEntry = nil
				selectedContextMenuControlBlacklistEntry = nil
			end,
            scrollable = true,
			sort = "name-up",
			width = "half",
			default = function() return nil end,
			disabled = function() return not sv.ZO_MenuContextMenuReplacement or sv.contextMenuReplacementControls.replaceAll end,
			reference = "LSM_LAM_DROPDOWN_SELECTED_WHITELISTEXCLUSION"
        },
        {
            type = "button",
            name = GetString(SI_LSM_LAM_CNTXTMEN_WHITELIST_ADD),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_WHITELIST_ADD_TT),
            func = function()
				if contextMenuListControlName ~= nil then
					sv.contextMenuReplacementControls.whiteList[#sv.contextMenuReplacementControls.whiteList + 1] = contextMenuListControlName
					updateExistingBlackAndWhiteLists(false)
					contextMenuListControlName = nil
					selectedContextMenuControlWhitelistEntry = nil
					selectedContextMenuControlWhitelistExclusionEntry = nil
					selectedContextMenuControlBlacklistEntry = nil

					sv.contextMenuReplacementControls._wasChanged = true
				end
			end,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or (contextMenuListControlName == nil or contextMenuListControlName == "" or contextMenuLookupWhiteList[contextMenuListControlName]) end,
			width = "half"
        },
        {
            type = "button",
            name = GetString(SI_LSM_LAM_CNTXTMEN_WHITELISTEXCL_ADD),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_WHITELISTEXCL_ADD_TT),
            func = function()
				if contextMenuListControlName ~= nil then
					sv.contextMenuReplacementControls.whiteListExclusion[#sv.contextMenuReplacementControls.whiteListExclusion + 1] = contextMenuListControlName
					updateExistingBlackAndWhiteLists(false)
					contextMenuListControlName = nil
					selectedContextMenuControlWhitelistEntry = nil
					selectedContextMenuControlWhitelistExclusionEntry = nil
					selectedContextMenuControlBlacklistEntry = nil

					sv.contextMenuReplacementControls._wasChanged = true
				end
			end,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or (contextMenuListControlName == nil or contextMenuListControlName == "" or contextMenuLookupWhiteListExclusionList[contextMenuListControlName]) end,
			width = "half"
        },
        {
            type = "button",
            name = GetString(SI_LSM_LAM_CNTXTMEN_WHITELIST_DEL),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_WHITELIST_DEL_TT),
            func = function()
				if selectedContextMenuControlWhitelistEntry ~= nil then
					local delIdx
					for idx, controlName in ipairs(sv.contextMenuReplacementControls.whiteList) do
						if controlName == selectedContextMenuControlWhitelistEntry then
							delIdx = idx
							break
						end
					end
					if delIdx ~= nil then
						trem(sv.contextMenuReplacementControls.whiteList, delIdx)
						updateExistingBlackAndWhiteLists(false)
						sv.contextMenuReplacementControls._wasChanged = true
					end
					contextMenuListControlName = nil
					selectedContextMenuControlWhitelistEntry = nil
					selectedContextMenuControlWhitelistExclusionEntry = nil
					selectedContextMenuControlBlacklistEntry = nil
				end
			end,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or (selectedContextMenuControlWhitelistEntry == nil or selectedContextMenuControlWhitelistEntry == "" or contextMenuLookupWhiteList[selectedContextMenuControlWhitelistEntry] == nil) end,
			width = "half"
        },
        {
            type = "button",
            name = GetString(SI_LSM_LAM_CNTXTMEN_WHITELISTEXCL_DEL),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_WHITELISTEXCL_DEL_TT),
            func = function()
				if selectedContextMenuControlWhitelistExclusionEntry ~= nil then
					local delIdx
					for idx, controlName in ipairs(sv.contextMenuReplacementControls.whiteListExclusion) do
						if controlName == selectedContextMenuControlWhitelistExclusionEntry then
							delIdx = idx
							break
						end
					end
					if delIdx ~= nil then
						trem(sv.contextMenuReplacementControls.whiteListExclusion, delIdx)
						updateExistingBlackAndWhiteLists(false)
						sv.contextMenuReplacementControls._wasChanged = true
					end
					contextMenuListControlName = nil
					selectedContextMenuControlWhitelistEntry = nil
					selectedContextMenuControlWhitelistExclusionEntry = nil
					selectedContextMenuControlBlacklistEntry = nil
				end
			end,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or (selectedContextMenuControlWhitelistExclusionEntry == nil or selectedContextMenuControlWhitelistExclusionEntry == "" or contextMenuLookupWhiteListExclusionList[selectedContextMenuControlWhitelistExclusionEntry] == nil) end,
			width = "half"
        },

		{
			type = "divider",
		},

        {
            type = "dropdown",
            name = GetString(SI_LSM_LAM_CNTXTMEN_BLACKLIST),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_BLACKLIST_TT),
			choices = existingBlackList,
			getFunc = function() return selectedContextMenuControlBlacklistEntry end, -- sv.contextMenuReplacementControls.blackList
			setFunc = function(entry)
				selectedContextMenuControlBlacklistEntry = entry
				selectedContextMenuControlWhitelistExclusionEntry = nil
				selectedContextMenuControlWhitelistEntry = nil
			end,
            scrollable = true,
			sort = "name-up",
			width = "half",
			default = function() return nil end,
			disabled = function() return not sv.ZO_MenuContextMenuReplacement or not sv.contextMenuReplacementControls.replaceAll end,
			reference = "LSM_LAM_DROPDOWN_SELECTED_BLACKLIST"
        },
        {
            type = "button",
            name = GetString(SI_LSM_LAM_CNTXTMEN_BLACKLIST_ADD),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_BLACKLIST_ADD_TT),
            func = function()
				if contextMenuListControlName ~= nil then
					sv.contextMenuReplacementControls.blackList[#sv.contextMenuReplacementControls.blackList + 1] = contextMenuListControlName
					updateExistingBlackAndWhiteLists(false)
					contextMenuListControlName = nil
					selectedContextMenuControlWhitelistEntry = nil
					selectedContextMenuControlWhitelistExclusionEntry = nil
					selectedContextMenuControlBlacklistEntry = nil

					sv.contextMenuReplacementControls._wasChanged = true
				end
			end,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or (contextMenuListControlName == nil or contextMenuListControlName == "" or contextMenuLookupBlackList[contextMenuListControlName]) end,
			width = "half"
        },

        {
            type = "button",
            name = GetString(SI_LSM_LAM_CNTXTMEN_BLACKLIST_DEL),
            tooltip = GetString(SI_LSM_LAM_CNTXTMEN_BLACKLIST_DEL_TT),
            func = function()
				if selectedContextMenuControlBlacklistEntry ~= nil then
					local delIdx
					for idx, controlName in ipairs(sv.contextMenuReplacementControls.blackList) do
						if controlName == selectedContextMenuControlBlacklistEntry then
							delIdx = idx
							break
						end
					end
					if delIdx ~= nil then
						trem(sv.contextMenuReplacementControls.blackList, delIdx)
						updateExistingBlackAndWhiteLists(false)
						sv.contextMenuReplacementControls._wasChanged = true
					end
					contextMenuListControlName = nil
					selectedContextMenuControlWhitelistEntry = nil
					selectedContextMenuControlWhitelistExclusionEntry = nil
					selectedContextMenuControlBlacklistEntry = nil
				end
			end,
            disabled = function() return not sv.ZO_MenuContextMenuReplacement or (selectedContextMenuControlBlacklistEntry == nil or selectedContextMenuControlBlacklistEntry == "" or contextMenuLookupBlackList[selectedContextMenuControlBlacklistEntry] == nil) end,
			width = "half"
        },

	}
	LAM2:RegisterOptionControls(LSMLAMPanelName, optionsData)


    local function openedPanel(panel)
        if panel ~= lib.LAMsettingsPanel then return end

		selectedExistingOwnerName = nil
		contextMenuOwnerControlName = nil
		newVisibleRowsForControlName = nil
		newVisibleRowsSubmenuForControlName = nil

		contextMenuListControlName = nil
		selectedContextMenuControlWhitelistEntry = nil
		selectedContextMenuControlWhitelistExclusionEntry = nil
		selectedContextMenuControlBlacklistEntry = nil

		updateExistingOwerNamesList(false)
		updateExistingBlackAndWhiteLists(false)
    end
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", openedPanel)
end