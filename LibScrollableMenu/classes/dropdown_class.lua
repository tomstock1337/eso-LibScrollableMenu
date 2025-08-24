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
local EM = GetEventManager() --EVENT_MANAGER
local tos = tostring
local sfor = string.format
local tins = table.insert
local trem = table.remove

local stringType = "string"
local numberType = "number"
local functionType = "function"
local booleanType = "boolean"
local userDataType = "userdata"


--------------------------------------------------------------------
--Library classes
--------------------------------------------------------------------
local classes = lib.classes


--------------------------------------------------------------------
--ZO_ComboBox function references
--------------------------------------------------------------------
--local zo_comboBoxDropdown_onEntrySelected = ZO_ComboBoxDropdown_Keyboard.OnEntrySelected
local zo_comboBoxDropdown_onMouseExitEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry
local zo_comboBoxDropdown_onMouseEnterEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry


--------------------------------------------------------------------
--LSM library locals
--------------------------------------------------------------------
local g_contextMenu
local refreshDropdownHeader

local has_submenu = true
local no_submenu = false


--Constants
local constants = lib.constants
local entryTypeConstants = constants.entryTypes
local entryTypeDefaultsConstants = constants.entryTypes.defaults
local searchFilterConstants = constants.searchFilter
local handlerNameConstants = constants.handlerNames
local submenuConstants = constants.submenu
local dropdownConstants = constants.dropdown
local fontConstants = constants.fonts


local dropdownDefaults = dropdownConstants.defaults
local noEntriesResults = searchFilterConstants.noEntriesResults
local filteredEntryTypes = searchFilterConstants.filteredEntryTypes
local filterNamesExempts = searchFilterConstants.filterNamesExempts

local MIN_WIDTH_WITHOUT_SEARCH_HEADER = dropdownDefaults.MIN_WIDTH_WITHOUT_SEARCH_HEADER
local MIN_WIDTH_WITH_SEARCH_HEADER = dropdownDefaults.MIN_WIDTH_WITH_SEARCH_HEADER



--Utility functions
local libUtil = lib.Util
local getControlName = libUtil.getControlName
local getControlData = libUtil.getControlData
local getValueOrCallback = libUtil.getValueOrCallback
local checkIfContextMenuOpenedButOtherControlWasClicked = libUtil.checkIfContextMenuOpenedButOtherControlWasClicked
local showTooltip = libUtil.showTooltip
local hideTooltip = libUtil.hideTooltip
local getContextMenuReference = libUtil.getContextMenuReference
local playSelectedSoundCheck = libUtil.playSelectedSoundCheck
local throttledCall = libUtil.throttledCall
local recursiveOverEntries = libUtil.recursiveOverEntries
local getIsNew = libUtil.getIsNew
local updateDataByFunctions = libUtil.updateDataByFunctions
local compareDropdownDataList = libUtil.compareDropdownDataList
local checkNextOnEntryMouseUpShouldExecute = libUtil.checkNextOnEntryMouseUpShouldExecute
local libUtil_BelongsToContextMenuCheck = libUtil.belongsToContextMenuCheck

--locals
--Filtering
local ignoreSubmenu 			--if using / prefix submenu entries not matching the search term should still be shown
local lastEntryVisible  = true	--Was the last entry processed visible at the results list? Used to e.g. show the divider below too
local filterString				--the search string
local filterFunc				--the filter function to use. Default is "defaultFilterFunc". Custom filterFunc can be added via options.customFilterFunc
local throttledCallDropdownClassSetFilterStringSuffix =  "_DropdownClass_SetFilterString"
local throttledCallDropdownClassOnTextChangedStringSuffix =  "_DropdownClass_OnTextChanged"


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------
-- Breadcrumb animation highlight
--------------------------------------------------------------------
--Did the virtual XML template for the highlight row change at the control? Reset the highlight control then so it will
--be build new with the new XML template, and same name -> Via ESOUI scrolltemplates.lua, PlayAnimationOnControl function
local function LSM_CheckIfAnimationControlNeedsXMLTemplateChange(control, controlTemplate)
	local retVar = false
	if control and controlTemplate then
		local rowHighlightData = control.LSM_rowHighlightData --was set to the control via self.highlightCallback(control, true) function at the scrollList!
		local highlightControlXMLTemplate = (rowHighlightData ~= nil and rowHighlightData.highlightXMLTemplate) or nil
		--Highlight control exists already and the XML template changed (e.g. scrolling an existing ScrollList row)
		if highlightControlXMLTemplate ~= nil and highlightControlXMLTemplate ~= controlTemplate then
			--Reset the animation timeline control and the highlight control
			local animationFieldName = rowHighlightData.animationFieldName
			if animationFieldName and control[animationFieldName] ~= nil then
				control[animationFieldName] = nil

				local highlightControlName = rowHighlightData.highlightControlName
				if highlightControlName ~= nil then
					if _G[highlightControlName] ~= nil then
						_G[highlightControlName] = nil
					end
				end
			end
			retVar = true
		end
	end

	--Reset the table at the control
	control.LSM_rowHighlightData = nil
	return retVar
end


--------------------------------------------------------------------
-- Dropdown (nested) submenu parsing functions
--------------------------------------------------------------------
--[[
-- Add/Remove the isAnySubmenuEntrySelected status
-- This works up from the mouse-over entry's submenu to the dropdown,
-- but only on entries having (opening) a submenu
-- as long as it does not run into a submenu still having a matching entry.
local function updateSubmenuIsAnyEntrySelectedStatus(selfVar, control, isMultiSelectEnabled)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 184) end
	local comboBox = selfVar.owner
	if not comboBox then return end

	--Only go on if multiselection is enabled
	if isMultiSelectEnabled == nil then
		isMultiSelectEnabled = comboBox.m_enableMultiSelect
	end
	if not isMultiSelectEnabled then return end

	local isAnySubmenuEntrySelected = false

	local data = getControlData(control)
	local submenuEntries = getValueOrCallback(data.entries, data) or {}

	-- We are only going to check the current submenu's entries, not recursively
	-- down from here since we are working our way up until we find an entry.
	for idx, subentry in ipairs(submenuEntries) do
		if comboBox:IsItemSelected(subentry) then
--d(">submenu item is selected: " .. tos(idx))
--LSM_Debug = LSM_Debug or {}
--LSM_Debug.updateSubmenuIsAnyEntrySelectedStatus = LSM_Debug.updateSubmenuIsAnyEntrySelectedStatus or {}
--LSM_Debug.updateSubmenuIsAnyEntrySelectedStatus[#LSM_Debug.updateSubmenuIsAnyEntrySelectedStatus+1] = {
	--indexFound = idx,
	--comboBox = comboBox,
	--subentry = ZO_ShallowTableCopy(subentry),
	--submenuEntries = ZO_ShallowTableCopy(submenuEntries),
--}
			isAnySubmenuEntrySelected = true
			break
		end
	end

	-- Set flag on submenu opening control
	control.isAnySubmenuEntrySelected = isAnySubmenuEntrySelected

	if not isAnySubmenuEntrySelected then
		ZO_ScrollList_RefreshVisible(control.m_dropdownObject.scrollControl)

		local parent = data.m_parentControl
		if parent then
			updateSubmenuIsAnyEntrySelectedStatus(selfVar, parent, isMultiSelectEnabled)
		end
	end
end
]]

-- Add/Remove the new status of a dropdown entry,
-- This works up from the mouse-over entry's submenu to the dropdown,
-- as long as it does not run into a submenu still having a matching entry.
local function updateSubmenuNewStatus(selfVar, control)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 31) end
	-- reverse parse
	local isNew = false

	local data = getControlData(control)
	local submenuEntries = getValueOrCallback(data.entries, data) or {}

	-- We are only going to check the current submenu's entries, not recursively
	-- down from here since we are working our way up until we find a new entry.
	for _, subentry in ipairs(submenuEntries) do
		if getIsNew(subentry, nil) then
			isNew = true
		end
	end

	if isNew ~= data.isNew then
		-- Set flag on submenu
		data.isNew = isNew

		lib:FireCallbacks('NewStatusUpdated', control, data)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 33, tos(getControlName(control))) end
	end

	if not isNew then
		ZO_ScrollList_RefreshVisible(control.m_dropdownObject.scrollControl)

		local parent = data.m_parentControl
		if parent then
			updateSubmenuNewStatus(selfVar, parent)
		end
	end
end

--[[
local function checkSubmenuOnMouseEnterTasks(selfVar, control, data)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 183) end
	--local doRefresh = false
	local comboBox = selfVar.owner
	local isMultiSelectEnabled = (comboBox ~= nil and comboBox.m_enableMultiSelect) or false

	--Remove the isAnySubmenuEntrySelected status of a dropdown entry
	-->Generally do this even if multiSelectionw as disabled
	--if isMultiSelectEnabled == true then
		-- Only directly change status on submenu openingControl entries
		if control.hasSubmenu == true or data.entries ~= nil then
			if control.isAnySubmenuEntrySelected == true then
				control.isAnySubmenuEntrySelected = false
				--doRefresh = true
			--end

			--if doRefresh == true then
				control.m_dropdownObject:Refresh(data)
			end
		else
			--Check parent menus (from bottom -> up to top)
			local parent = data.m_parentControl
			if parent then
				updateSubmenuIsAnyEntrySelectedStatus(selfVar, parent, isMultiSelectEnabled)
			end
		end
	--end
end
]]

local function checkNormalOnMouseEnterTasks(selfVar, control, data)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 32) end
	--local doRefresh = false

	--Remove the isNew status of a dropdown entry
	if data.isNew then
		-- Only directly change status on non-submenu entries. They are effected by child entries
		if data.entries == nil then
			--if data.isNew == true then
				data.isNew = false
				lib:FireCallbacks('NewStatusUpdated', control, data)
				if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 33, tos(getControlName(control))) end
				--doRefresh = true
			--d(debugPrefix.."checkNormalOnMouseEnterTasks - " .. tos(getControlName(control)))
			--end

			--if doRefresh == true then
				control.m_dropdownObject:Refresh(data)
			--end

			--Check parent menus (from bottom -> up to top)
			local parent = data.m_parentControl
			if parent then
				updateSubmenuNewStatus(selfVar, parent)
			end
		end
	end
end

--Run checks for submenus and nested submenus (upwards from the current item opening a submenu!) if you move the mouse above an entry
--e.g.multiselection any item selected in submenus
local function doSubmenuOnMouseEnterNestedSubmenuChecks(selfVar, control, data)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 182) end
	--checkSubmenuOnMouseEnterTasks(selfVar, control, data) --todo 20250212 Done in function libUtil.recursiveMultiSelectSubmenuOpeningControlUpdate now!
end

--Run checks for submenus and nested submenus (upwards from the current item!) if you move the mouse above an entry
--e.g. isNew
local function doOnMouseEnterNestedSubmenuChecks(selfVar, control, data)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 30) end
	checkNormalOnMouseEnterTasks(selfVar, control, data)
end


--------------------------------------------------------------------
-- Dropdown show/hide functions
--------------------------------------------------------------------
local function clearTimeout()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 7) end
	EM:UnregisterForUpdate(handlerNameConstants.dropdownCallLaterHandle)
end

local function setTimeout(callback)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 8) end
	clearTimeout()
	--Delay the dropdown close callback so we can move the mouse above a new dropdown control and keep that opened e.g.
	EM:RegisterForUpdate(handlerNameConstants.dropdownCallLaterHandle, submenuConstants.SUBMENU_SHOW_TIMEOUT, function()
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 9, tos(submenuConstants.SUBMENU_SHOW_TIMEOUT)) end
		clearTimeout()
		if callback then callback() end
	end)
end

local function checkWhereToShowSubmenu(selfVar) --#2025_34
--d(debugPrefix .. "dropdownClass:checkWhereToShowSubmenu - parentMenu: " ..tos(selfVar.m_parentMenu))
	if not selfVar.m_parentMenu then return false, true end

	local openSubmenuToSideForced = false
	local openToTheRight = true --Default value

	local submenuOpenToSide = selfVar:GetSubMenuOpeningSide()
	if submenuOpenToSide ~= nil then
		if submenuOpenToSide == "right" then
			openToTheRight = true
			openSubmenuToSideForced  = true
		elseif submenuOpenToSide == "left" then
			openToTheRight = false
			openSubmenuToSideForced  = true
		end
	end
	return openSubmenuToSideForced, openToTheRight
end


--------------------------------------------------------------------
-- Dropdown entry filter functions
--------------------------------------------------------------------
-- Prevents errors on the off chance a non-string makes it through into ZO_ComboBox
local function verifyLabelString(data)
	--Check for data.* keys to run any function and update data[key] with actual values
	updateDataByFunctions(data)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 18, tos(data.name)) end
	--Require the name to be a string
	return type(data.name) == stringType
end

--Check if entry should be added to the search/filter of the string search of the collapsible header
-->Returning true: item must be considered for the search / false: item should be skipped
local function passItemToSearch(item)
	--Check if name of entry counts as "to search", or not
	if filterString ~= "" then
		local name = item.label or item.name
		--Name is missing: Do not filter
		if name == nil then return false end
		return not filterNamesExempts[name]
	end
	return false
end

--Search the item's label or name now, if the entryType of the item should be processed by text search, and if the entry
--was not marked as "not to search" (always show in search results) in it's data
local function filterResults(item, comboBox)
	local entryType = item.entryType
	if not entryType or filteredEntryTypes[entryType] then
		--Should the item be skipped at the search filters?
		local doNotFilter = getValueOrCallback(item.doNotFilter, item) or false
		if doNotFilter == true then
			return true -- always included
		end
		--Check for other prerequisites
		if passItemToSearch(item) == true then
			--Not excluded, do the string comparison now
			return filterFunc(item, filterString)
		end
	else
		return lastEntryVisible
	end
end

--String filter the visible results, if options.enableFilter == true
-->if doFilter is true the text search will be executed, else textsearch is not executed -> Item should be shown directly
local function itemPassesFilter(item, comboBox, doFilter)
	--Check if the data.name / data.label are provided (also check all other data.* keys if functions need to be executed)
	if verifyLabelString(item) then
		if doFilter then
			--Recursively check menu entries (submenu and nested submenu entries) for the matching search string
			return recursiveOverEntries(item, comboBox, filterResults)
		else
			return true
		end
	end
end


--------------------------------------------------------------------
-- Dropdown entry/row pool control functions
--------------------------------------------------------------------
--Reset function which is called for the scrollList entryType pool's rowControls as they get hidden/scrolled out of sight
local function poolControlReset(selfVar, control)
    control:SetHidden(true)

	if control.isSubmenu then
		if control.m_owner.m_submenu then
			control.m_owner.m_submenu:HideDropdown()
		end
	end

	local button = control.m_button
	if button then
		local buttonGroup = button.m_buttonGroup
		if buttonGroup ~= nil then
			--local buttonGroupIndex = button.m_buttonGroupIndex
			buttonGroup:Remove(button)
		end
	end
end


--------------------------------------------------------------------
-- Dropdown entry/row handlers
--------------------------------------------------------------------
--return false to run default ZO_ComboBox OnMouseEnter handler + tooltip / true to skip original ZO_ComboBox handler and only show tooltip
--return false to run default ZO_ComboBox OnMouseExit handler + tooltip / true to skip original ZO_ComboBox handler and only show tooltip
--return false to "skip selection" and just run a callback function via dropdownClass:RunItemCallback / return true to "select" entry via described way in ZO_ComboBox handler
local function checkForMultiSelectEnabled(selfVar, control, isOnMouseUp)
	local isMultiSelectEnabled = (selfVar.owner and selfVar.owner.m_enableMultiSelect) or false
	if isOnMouseUp then
		if isMultiSelectEnabled then
			return false
		end
		return control.closeOnSelect
	else
		return (not isMultiSelectEnabled and not control.closeOnSelect) or false
	end
end

local function onMouseEnter(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 49, tos(getControlName(control)), tos(hasSubmenu)) end
	lib:FireCallbacks('EntryOnMouseEnter', control, data)
	dropdown:Narrate("OnEntryMouseEnter", control, data, hasSubmenu)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 50, tos(getControlName(control)), tos(hasSubmenu)) end

	return dropdown
end

local function onMouseExit(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 51, tos(getControlName(control)), tos(hasSubmenu)) end
	lib:FireCallbacks('EntryOnMouseExit', control, data)
	dropdown:Narrate("OnEntryMouseExit", control, data, hasSubmenu)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 52, tos(getControlName(control)), tos(hasSubmenu)) end

	return dropdown
end

local function onMouseUp(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject

	lib:FireCallbacks('OnEntrySelected', control, data)
	dropdown:Narrate("OnEntrySelected", control, data, hasSubmenu)

	hideTooltip(control)
	return dropdown
end


local handlerFunctions  = {
	--return false to run default ZO_ComboBox OnMouseEnter handler + tooltip / true to skip original ZO_ComboBox handler and only show tooltip
	["onMouseEnter"] = {
		[entryTypeConstants.LSM_ENTRY_TYPE_NORMAL] = function(selfVar, control, data, ...)
			onMouseEnter(control, data, no_submenu)
			doOnMouseEnterNestedSubmenuChecks(selfVar, control, data)
			return checkForMultiSelectEnabled(selfVar, control)
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_HEADER] = function(selfVar, control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER] = function(selfVar, control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_SUBMENU] = function(selfVar, control, data, ...)
			--d( debugPrefix .. 'onMouseEnter [entryTypeConstants.LSM_ENTRY_TYPE_SUBMENU]')
			local dropdown = onMouseEnter(control, data, has_submenu)
			clearTimeout()
			doSubmenuOnMouseEnterNestedSubmenuChecks(selfVar, control, data)
			--Show the submenu of the entry
			dropdown:ShowSubmenu(control)
			return false --not control.closeOnSelect
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_CHECKBOX] = function(selfVar, control, data, ...)
			onMouseEnter(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_BUTTON] = function(selfVar, control, data, ...)
			onMouseEnter(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON] = function(selfVar, control, data, ...)
			onMouseEnter(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_EDITBOX] = function(selfVar, control, data, ...)
			onMouseEnter(control, data, no_submenu)
			-- Return true to skip the default handler to prevent row highlight.
			return false --not control.closeOnSelect
		end,
	},

	--return false to run default ZO_ComboBox OnMouseExit handler + tooltip / true to skip original ZO:ComboBox handler and only show tooltip
	["onMouseExit"] = {
		[entryTypeConstants.LSM_ENTRY_TYPE_NORMAL] = function(selfVar, control, data)
			onMouseExit(control, data, no_submenu)
			return checkForMultiSelectEnabled(selfVar, control)
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_HEADER] = function(selfVar, control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER] = function(selfVar, control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return true
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_SUBMENU] = function(selfVar, control, data)
			local dropdown = onMouseExit(control, data, has_submenu)
			if not (MouseIsOver(control) or dropdown:IsEnteringSubmenu()) then
				dropdown:OnMouseExitTimeout(control)
			end
			return false --not control.closeOnSelect
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_CHECKBOX] = function(selfVar, control, data)
			onMouseExit(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_BUTTON] = function(selfVar, control, data, ...)
			onMouseExit(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON] = function(selfVar, control, data, ...)
			onMouseExit(control, data, no_submenu)
			return false --not control.closeOnSelect
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_EDITBOX] = function(selfVar, control, data, ...)
			-- Return true to skip the default handler to prevent row highlight.
			return false --not control.closeOnSelect
		end,
	},

	--The onMouseUp will be used to select an entry in the menu/submenu/nested submenu/context menu
	---> It will be called from dropdownClass:OnEntryMouseUp, and then call the ZO_ComboBoxDropdown_Keyboard.OnEntrySelected -> ZO_ComboBox:SetSelected -> ZO_ComboBox:SelectItem -> then:
	-----> If no multiselection is enabled: ZO_ComboBox_Base.SelectItem -> ZO_ComboBox_Base:ItemSelectedClickHelper(item, ignoreCallback) -> item.callback(comboBox, itemName, item, selectionChanged, oldItem) function
	-----> If multiselection is enabled: ZO_ComboBox:SelectItem contains the code via self:AddItemToSelected etc.

	---> The parameters for the LibScrollableMenu entry.callback functions will be:  (comboBox, itemName, item, selectionChanged, oldItem) -> The last param oldItem might change to checked for check and radiobuttons!
	---> The return value true/false controls if the calling function runHandler -> dropdownClass.OnEntryMouseUp(control, button, upInside, ctrl, alt, shift) -> will select the entry
	---> to the dropdown via ZO_ComboBoxDropdown_Keyboard.OnEntryMouseUp(control, button, upInside, ctrl, alt, shift)

	-- return true to "select" entry via described way in ZO_ComboBox handler (see above) / return false to "skip selection" and just run a callback function via dropdownClass:RunItemCallback
	["onMouseUp"] = {
		[entryTypeConstants.LSM_ENTRY_TYPE_NORMAL] = function(selfVar, control, data, button, upInside, ctrl, alt, shift)
--d(debugPrefix .. 'onMouseUp [entryTypeConstants.LSM_ENTRY_TYPE_NORMAL]')
			onMouseUp(control, data, no_submenu)
			return true
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_HEADER] = function(selfVar, control, data, button, upInside, ctrl, alt, shift)
			return false
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER] = function(selfVar, control, data, button, upInside, ctrl, alt, shift)
			return false
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_SUBMENU] = function(selfVar, control, data, button, upInside, ctrl, alt, shift)
--d(debugPrefix .. 'onMouseUp [entryTypeConstants.LSM_ENTRY_TYPE_SUBMENU]')
			onMouseUp(control, data, has_submenu)
			return checkForMultiSelectEnabled(selfVar, control, true) --control.closeOnSelect --if submenu entry has data.callback then select the entry #2025_6
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_CHECKBOX] = function(selfVar, control, data, button, upInside, ctrl, alt, shift)
			onMouseUp(control, data, no_submenu)
			return false
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_BUTTON] = function(selfVar, control, data, button, upInside, ctrl, alt, shift)
			onMouseUp(control, data, no_submenu)
			return false
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON] = function(selfVar, control, data, button, upInside, ctrl, alt, shift)
			onMouseUp(control, data, no_submenu)
			return false
		end,
		[entryTypeConstants.LSM_ENTRY_TYPE_EDITBOX] = function(selfVar, control, data, button, upInside, ctrl, alt, shift)
			onMouseUp(control, data, no_submenu)
			return false
		end,
	},
}

local function runHandler(selfVar, handlerTable, control, ...)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 53, tos(getControlName(control)), tos(handlerTable), tos(control.typeId)) end
	local handler = handlerTable[control.typeId]
	if handler then
		return handler(selfVar, control, ...)
	end
	return false
end


--------------------------------------------------------------------
-- Dropdown entry functions
--------------------------------------------------------------------
local function noCallback()
	return --d("NO CALLBACK - executed!")
end

local function createScrollableComboBoxEntry(self, item, index, entryType)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 54, tos(index), tos(entryType)) end
	local entryData = ZO_EntryData:New(item)
	entryData.m_index = index
	entryData.m_owner = self.owner
	entryData.m_dropdownObject = self
	entryData:SetupAsScrollListDataEntry(entryType)
	return entryData
end

local function addEntryToScrollList(self, item, dataList, index, allItemsHeight, largestEntryWidth, spacing, isLastEntry, isNoItemsMatchFilter, comboBoxObject)

	--[[
	if isLastEntry then
		item.isNoEntriesResultsEntry = isNoItemsMatchFilter --#2025_26
		if isNoItemsMatchFilter then
			d(debugPrefix .. "addEntryToScrollList - item is NoEntriesResults! index: " .. tos(index) ..", enabled: " ..tos(item.enabled))
		end
	end
	]]

	local entryHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT
	local entryType = entryTypeConstants.LSM_ENTRY_TYPE_NORMAL
	local widthPadding = 0
	if self.customEntryTemplateInfos and item.customEntryTemplate then
		local templateInfo = self.customEntryTemplateInfos[item.customEntryTemplate]
		if templateInfo then
			entryType = templateInfo.typeId
			entryHeight = templateInfo.entryHeight
			-- for static width padding beyond string length, such as submenu icon
			widthPadding = templateInfo.widthPadding or 0

			-- If the entry has an icon, or isNew, we add the row height to adjust for icon size.
			local iconPadding = (item.isNew or item.icon) and entryHeight or 0
			widthPadding = widthPadding + iconPadding
		end
	end

	if isLastEntry then
		--entryTypes are added via ZO_ScrollList_AddDataType and there always exists 1 respective "last" entryType too,
		--which handles the spacing at the last (most bottom) list entry to be different compared to the normal entryType
		entryType = entryType + 1
	else
		entryHeight = entryHeight + spacing
	end

	allItemsHeight = allItemsHeight + entryHeight

	local entry = createScrollableComboBoxEntry(self, item, index, entryType)
	tins(dataList, entry)

	local fontObject = self.owner:GetItemFontObject(item) --self.owner:GetDropdownFontObject()
	--Check string width of label (alternative text to show at entry) or name (internal value used)
	local nameWidth = GetStringWidthScaled(fontObject, item.label or item.name, 1, SPACE_INTERFACE) + widthPadding
	if nameWidth > largestEntryWidth then
		largestEntryWidth = nameWidth
	end
	return allItemsHeight, largestEntryWidth
end


--------------------------------------------------------------------
-- Dropdown scroll list functions
--------------------------------------------------------------------
local function getDropdownTemplate(enabled, baseTemplate, alternate, default)
	baseTemplate = MAJOR .. baseTemplate
	local templateName = sfor('%s%s', baseTemplate, (enabled and alternate or default))
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 2, tos(templateName)) end
	return templateName
end

local function getScrollContentsTemplate(barHidden)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 3, tos(barHidden)) end
	return getDropdownTemplate(barHidden, '_ScrollContents', '_BarHidden', '_BarShown')
end


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------
--Dropdown Header controls
--------------------------------------------------------------------

--[[ Adds options
	options.titleText
	options.titleFont
	options.subtitleText
	options.subtitleFont
	options.titleTextAlignment -- for title and subtitle
	options.customHeaderControl

	options.enableFilter
	options.headerCollapsible
	options.headerCollapsed

	context menu, on second showing, Filter is shown.
]]

-- The controls, here and in the XML, are subject to change
-- May only need PARENT, TITLE, FILTER_CONTAINER for now
local headerControls = {
	-- To not cycle through this when anchoring controls, skipped in ipairs
	PARENT				= -1,
	TITLE_BASELINE		= -2,
	CENTER_BASELINE		= 0,
	-- Cycles with ipairs
	TITLE				= 1,
	SUBTITLE			= 2,
	DIVIDER_SIMPLE		= 3,
	FILTER_CONTAINER	= 4,
	CUSTOM_CONTROL		= 5,
	TOGGLE_BUTTON		= 6,
	TOGGLE_BUTTON_CLICK_EXTENSION = 7, -- control that anchors to the toggle buttons left to make the whole header's width clickable to toggle the collapsed state
}
lib.XML.headerControls = headerControls --Needed for XML

do
	-- Alias the control names to make the code less verbose and more readable.
	local PARENT			= headerControls.PARENT
	local TITLE				= headerControls.TITLE
	local SUBTITLE			= headerControls.SUBTITLE
	local CENTER_BASELINE	= headerControls.CENTER_BASELINE
	local TITLE_BASELINE	= headerControls.TITLE_BASELINE
	local DIVIDER_SIMPLE	= headerControls.DIVIDER_SIMPLE
	local FILTER_CONTAINER	= headerControls.FILTER_CONTAINER
	local CUSTOM_CONTROL	= headerControls.CUSTOM_CONTROL
	local TOGGLE_BUTTON		= headerControls.TOGGLE_BUTTON
	local TOGGLE_BUTTON_CLICK_EXTENSION	= headerControls.TOGGLE_BUTTON_CLICK_EXTENSION

	local DEFAULT_CONTROLID = CENTER_BASELINE

	local g_currentBottomLeftHeader = DEFAULT_CONTROLID

	local ROW_OFFSET_Y = 5

	-- The Anchor class simply wraps a ZO_Anchor object with a target id, which we can later resolve into an actual control.
	-- This allows us to specify all anchor data at file scope and resolve the target controls only when needed.
	local Anchor = ZO_Object:Subclass()

	function Anchor:New(pointOnMe, targetId, pointOnTarget, offsetX, offsetY)
		local object = ZO_Object.New(self)
		object.targetId = targetId
		object.anchor = ZO_Anchor:New(pointOnMe, nil, pointOnTarget, offsetX, offsetY)
		return object
	end

	local DEFAULT_ANCHOR = 100

							-- {point, relativeTo_controlId, relativePoint, offsetX, offsetY}
	local anchors = {
		[TOGGLE_BUTTON]		= 				{ Anchor:New(BOTTOMRIGHT, PARENT, BOTTOMRIGHT, -ROW_OFFSET_Y, 0) },
		--Show a control left of the toggle button: We can click this to expand the header again, and after that the control resizes to 0pixels and hides
		[TOGGLE_BUTTON_CLICK_EXTENSION]	=	{ Anchor:New(BOTTOMRIGHT, TOGGLE_BUTTON, BOTTOMLEFT, 0, 0), Anchor:New(BOTTOMLEFT, PARENT, BOTTOMLEFT, -ROW_OFFSET_Y, 0) },
		[DIVIDER_SIMPLE]	= 				{ Anchor:New(TOPLEFT, nil, BOTTOMLEFT, 0, ROW_OFFSET_Y), Anchor:New(TOPRIGHT, nil, BOTTOMRIGHT, 0, 0) }, -- ZO_GAMEPAD_CONTENT_TITLE_DIVIDER_PADDING_Y
		[DEFAULT_ANCHOR]	= 				{ Anchor:New(TOPLEFT, nil, BOTTOMLEFT, 0, 0), Anchor:New(TOPRIGHT, nil, BOTTOMRIGHT, 0, 0) },
	}
			-- {point, relativeTo_controlId, relativePoint, offsetX, offsetY}

	local function header_applyAnchorToControl(headerControl, anchorData, controlId, control)
		if headerControl:IsHidden() then headerControl:SetHidden(false) end
		local controls = headerControl.controls

		local targetId = anchorData.targetId or g_currentBottomLeftHeader
		local target = controls[targetId]

		anchorData.anchor:SetTarget(target)
		anchorData.anchor:AddToControl(control)
	end

	local function header_applyAnchorSetToControl(headerControl, anchorSet, controlId, collapsed)
		local controls = headerControl.controls
		local control = controls[controlId]
		control:SetHidden(false)

		header_applyAnchorToControl(headerControl, anchorSet[1], controlId, control)
		if anchorSet[2] then
			header_applyAnchorToControl(headerControl, anchorSet[2], controlId, control)
		end

		g_currentBottomLeftHeader = controlId

		local height = control:GetHeight()

--d(">header_applyAnchorSetToControl-controlId: " .. tos(controlId) .. ", heightOfCtrl: " .. tos(height) .. ", controlName: " ..getControlName(control))

		if controlId == TOGGLE_BUTTON then
			-- We want to keep height if collapsed, but not add height for the button if not collapsed.
			height = collapsed and height or 0
		--The control processed is the collapsed header's toggle button "click extension"
		elseif controlId == TOGGLE_BUTTON_CLICK_EXTENSION then
			--Always fixed header height addition = 0 as the toggleButton already provided the extra height for the header
			--and this click extensikon control only is placed on the left to make it easier to expand the header again
			height = 0
			if collapsed then
				control:SetHidden(false)
				control:SetHeight(controls[TOGGLE_BUTTON]:GetHeight())
			else
				control:SetHidden(true)
				control:ClearAnchors()
				control:SetDimensions(0, 0)
			end
		end
		return height
	end

	local function showHeaderDivider(controlId)
		if g_currentBottomLeftHeader ~= DEFAULT_CONTROLID and controlId < TOGGLE_BUTTON then
			return g_currentBottomLeftHeader < DIVIDER_SIMPLE and controlId > DIVIDER_SIMPLE
		end
		return false
	end

	local function header_updateAnchors(headerControl, refreshResults, collapsed, isFilterEnabled)
--d(debugPrefix .. "header_updateAnchors - collapsed: " ..tos(collapsed) .. "; isFilterEnabled: " ..tos(isFilterEnabled))
		--local headerHeight = collapsed and 0 or 17
		local headerHeight = 0
		local controls = headerControl.controls
		g_currentBottomLeftHeader = DEFAULT_CONTROLID

		for controlId, control in ipairs(controls) do
			control:ClearAnchors()
			control:SetHidden(true)

			local hidden = not refreshResults[controlId]
			-- There are no other header controls showing, so hide the toggle button, and it's extension
			if not collapsed and (controlId == TOGGLE_BUTTON or controlId == TOGGLE_BUTTON_CLICK_EXTENSION) and g_currentBottomLeftHeader == DEFAULT_CONTROLID then
				hidden = true
			end

			if not hidden then
				if showHeaderDivider(controlId) then
					-- Only show the divider if g_currentBottomLeftHeader is before DIVIDER_SIMPLE and controlId is after DIVIDER_SIMPLE
					headerHeight = headerHeight + header_applyAnchorSetToControl(headerControl, anchors[DIVIDER_SIMPLE], DIVIDER_SIMPLE)
				end

				local anchorSet = anchors[controlId] or anchors[DEFAULT_ANCHOR]
				headerHeight = headerHeight + header_applyAnchorSetToControl(headerControl, anchorSet, controlId, collapsed)
			end
		end

--d(">headerHeight: " ..tos(headerHeight))
		if headerHeight > 0 then
			if not collapsed then
				headerHeight = headerHeight + (ROW_OFFSET_Y * 3)
			end
			headerControl:SetHeight(headerHeight)
		end

		local headerWidth = headerControl:GetWidth()
		if isFilterEnabled and headerWidth < MIN_WIDTH_WITH_SEARCH_HEADER then
			headerControl:SetDimensionConstraints(MIN_WIDTH_WITH_SEARCH_HEADER, headerHeight)
			headerControl:SetWidth(MIN_WIDTH_WITH_SEARCH_HEADER)
		elseif not isFilterEnabled and headerWidth < MIN_WIDTH_WITH_SEARCH_HEADER then
			headerControl:SetDimensionConstraints(MIN_WIDTH_WITHOUT_SEARCH_HEADER, headerHeight)
			headerControl:SetWidth(MIN_WIDTH_WITHOUT_SEARCH_HEADER)
		end
	end

	local function header_setAlignment(control, alignment, defaultAlignment)
		if control == nil then
			return
		end

		if alignment == nil then
			alignment = defaultAlignment
		end

		control:SetHorizontalAlignment(alignment)
	end

	local function header_setFont(control, font, defaultFont)
		if control == nil then
			return
		end

		if font == nil then
			font = defaultFont
		end

		control:SetFont(font)
	end

	local function header_processData(control, data, collapsed)
		-- if collapsed is true then this is hidden
		if control == nil or collapsed then
			return false
		end

		local dataType = type(data)

		if dataType == functionType then
			data = data(control)
		end

		if dataType == stringType or dataType == numberType then
			control:SetText(data)
		end

		if dataType == booleanType then
			return data
		end

		return data ~= nil
	end

	local function header_processControl(control, customControl, collapsed)
		-- if collapsed is true then this is hidden
		if control == nil or collapsed then
			return false
		end

		local dataType = type(customControl)
		control:SetHidden(dataType ~= userDataType)
		if dataType == userDataType then
			customControl:SetParent(control)
			customControl:ClearAnchors()
			customControl:SetAnchor(TOP, control, TOP, 0, 0)
			control:SetDimensions(customControl:GetDimensions())
			return true
		end

		return false
	end

	refreshDropdownHeader = function(comboBox, headerControl, options, collapsed)
--d(debugPrefix .. "refreshDropdownHeader - collapsed: " ..tos(collapsed))

		local controls = headerControl.controls

		headerControl:SetHidden(true)
		headerControl:SetHeight(0)

		local refreshResults = {}
		-- Title / Subtitle
		refreshResults[TITLE] = header_processData(controls[TITLE], getValueOrCallback(options.titleText, options), collapsed)
		header_setFont(controls[TITLE], getValueOrCallback(options.titleFont, options), fontConstants.HeaderFontTitle)

		refreshResults[SUBTITLE] = header_processData(controls[SUBTITLE], getValueOrCallback(options.subtitleText, options), collapsed)
		header_setFont(controls[SUBTITLE], getValueOrCallback(options.subtitleFont, options), fontConstants.HeaderFontSubtitle)

		header_setAlignment(controls[TITLE], getValueOrCallback(options.titleTextAlignment, options), TEXT_ALIGN_CENTER)
		header_setAlignment(controls[SUBTITLE], getValueOrCallback(options.titleTextAlignment, options), TEXT_ALIGN_CENTER)

		-- Others
		local isFilterEnabled = comboBox:IsFilterEnabled()
		refreshResults[FILTER_CONTAINER] = 				header_processData(controls[FILTER_CONTAINER], isFilterEnabled, collapsed)
		refreshResults[CUSTOM_CONTROL] = 				header_processControl(controls[CUSTOM_CONTROL], getValueOrCallback(options.customHeaderControl, options), collapsed)
		refreshResults[TOGGLE_BUTTON] = 				header_processData(controls[TOGGLE_BUTTON], getValueOrCallback(options.headerCollapsible, options))
		refreshResults[TOGGLE_BUTTON_CLICK_EXTENSION] = header_processData(controls[TOGGLE_BUTTON_CLICK_EXTENSION], getValueOrCallback(options.headerCollapsible, options))

		headerControl:SetDimensionConstraints(MIN_WIDTH_WITHOUT_SEARCH_HEADER, 0)
		header_updateAnchors(headerControl, refreshResults, collapsed, isFilterEnabled)
	end
	lib.Util.refreshDropdownHeader = refreshDropdownHeader
end



------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------
-- LSM dropdown class definition
--------------------------------------------------------------------
local dropdownClass = ZO_ComboBoxDropdown_Keyboard:Subclass() --vanilla: XML ZO_ComboBoxDropdown_Singleton_Keyboard -> XML ZO_ComboBoxDropdown_Keyboard_Template -> ZO_ComboBoxDropdown_Keyboard.InitializeFromControl(self)
classes.dropdownClass = dropdownClass


--------------------------------------------------------------------
-- LSM dropdown class
--------------------------------------------------------------------
local DEFAULT_ENTRY_ID = 1
local DEFAULT_LAST_ENTRY_ID = 2

-- dropdownClass:New(To simplify locating the beginning of the class
function dropdownClass:Initialize(comboBoxObject, comboBoxContainer, depth)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 55, tos(getControlName(comboBoxObject)), tos(getControlName(comboBoxContainer)), tos(depth)) end
--df(debugPrefix.."dropdownClass:Initialize - parent: %s, comboBoxContainer: %s, depth: %s", tos(getControlName(comboBoxObject)), tos(getControlName(comboBoxContainer)), tos(depth))
	local dropdownControl = CreateControlFromVirtual(comboBoxContainer:GetName(), GuiRoot, "LibScrollableMenu_Dropdown_Template", depth)
	--20250330 #2025_26 ZO_ComboBoxDropdown_Keyboard.Initialize(self, dropdownControl) --disabling this to supress default calls to ZO_ComboBoxDropdown_Keyboard functions, especially default SetupScrollList using ZO_ComboBoxEntry XML templates, instead of LSM's XML templates

	--v- ZO_ComboBoxDropdown_Keyboard.Initialize
	self.control = dropdownControl
    self.scrollControl = dropdownControl:GetNamedChild("Scroll")
    self.spacing = 0
    self.nextScrollTypeId = DEFAULT_LAST_ENTRY_ID + 1
    self.owner = nil
    self:SetupScrollList()
	--^- ZO_ComboBoxDropdown_Keyboard.Initialize

	dropdownControl.object = self
	dropdownControl.m_dropdownObject = self
	self.m_comboBox = comboBoxContainer.m_comboBox
	self.m_container = comboBoxContainer
	self.owner = comboBoxObject
	self:SetHidden(true)

	self.m_parentMenu = comboBoxObject.m_parentMenu
	self.m_sortedItems = {}

	local scrollCtrl = self.scrollControl
	if scrollCtrl then
		scrollCtrl.scrollbar.owner = 	scrollCtrl
		scrollCtrl.upButton.owner = 	scrollCtrl
		scrollCtrl.downButton.owner = 	scrollCtrl
	end
	self.scroll = self.scrollControl.contents

	local selfVar = self

	--------------------------------------------------------------------------------------------------------------------
	-- highlightTemplate, animationFieldName = self.highlightTemplateOrFunction(control)
	-->Function highlightTemplateOrFunctions will be called from local function RefreshHighlights() in function ZO_ScrollList_EnableHighlight
	--Enable different hightlight templates at the ZO_SortFilterList scrolLList entries -> OnMouseEnter
	-->entries opening a submenu, having a callback function, show with a different template (color e.g.)
	-->>!!! ZO_ScrollList_EnableHighlight(self.scrollControl, function(control) end) cannot be used here as it does NOT overwrite existing highlightTemplateOrFunction !!!
	--[[
		local function HighlightControl(self, control)
			local highlightTemplate, animationFieldName
			if type(self.highlightTemplateOrFunction) == functionType then
				-->!!! This will be the place where the code below is called !!!
				highlightTemplate, animationFieldName = self.highlightTemplateOrFunction(control)
			else
				highlightTemplate = self.highlightTemplateOrFunction
			end
			control.highlightAnimationFieldName = animationFieldName or "HighlightAnimation"
			PlayAnimationOnControl(control, highlightTemplate, control.highlightAnimationFieldName, DONT_ANIMATE_INSTANTLY, self.overrideHighlightEndAlpha)

			self.highlightedControl = control

			if self.highlightCallback then
				self.highlightCallback(control, true)
			end
		end
	]]
	-->!!! This will be the place where the function HighlightControl above calls the highlightTemplateOrFunction function !!!
	scrollCtrl.highlightTemplateOrFunction = function(control)
--d(debugPrefix .. "scrollCtrl.highlightTemplateOrFunction - " .. tos(getControlName(control)))
		if selfVar.owner then
			--return selfVar.owner:GetHighlightTemplate(control)
			local XMLVirtualHighlightTemplateOfRow = selfVar.owner:GetHighlightTemplate(control)
			--Check if the XML virtual template name changed and invalidate the _G highlight and animation control then (set = nil)
			--[[todo 20241228 Idea: Get a highlight control and animation from a ZO_ObjectPool instead of setting the existing highlight control and animation  = nil and
				creating a new one with the next template

			control.LSM_HighlightAnimation = selfVar.owner:GetHighlightFromPool()
			--Then return true and the animationFieldName "LSM_HighlightAnimation" so vanilla code function PlayAnimationOnControl will use
			--control.LSM_HighlightAnimation and play the animation
			return true, "LSM_HighlightAnimation"
			]]
			LSM_CheckIfAnimationControlNeedsXMLTemplateChange(control, XMLVirtualHighlightTemplateOfRow)

--d(">XMLVirtualHighlightTemplateOfRow: " .. tos(XMLVirtualHighlightTemplateOfRow))
			-->function PlayAnimationOnControl will set control[defaultHighLightAnimationFieldName] = animationControl then
			--->Also see function scrollCtrl.highlightCallback below
			return XMLVirtualHighlightTemplateOfRow, entryTypeDefaultsConstants.defaultHighLightAnimationFieldName --"LSM_HighlightAnimation"
		end
--d("<<defaultHighlightTemplate: " .. tos(defaultHighlightTemplate))
		return entryTypeDefaultsConstants.defaultHighlightTemplate, entryTypeDefaultsConstants.defaultHighLightAnimationFieldName --"ZO_SelectionHighlight", "LSM_HighlightAnimation"
	end

	--------------------------------------------------------------------------------------------------------------------
	--Set the table control.rowHighlightData so we can use it to compare the last used XML virtual template for the
	--highlight control, at this control, with the current one.
	-->Will be set here and read in function scrollCtrl.highlightTemplateOrFunction above -> LSM_CheckIfAnimationControlNeedsXMLTemplateChange
	scrollCtrl.highlightCallback = function(control, isHighlighting)
--d(debugPrefix .. "scrollCtrl.highlightCallback - " .. tos(isHighlighting))
		if control ~= nil and isHighlighting == true then
			if selfVar.owner then
				local animationFieldName = control.highlightAnimationFieldName
				if animationFieldName ~= nil then
					control.LSM_rowHighlightData = {
						highlightControlName =	control:GetName() .. "Scroll" .. animationFieldName,
						animationFieldName = 	animationFieldName,
						highlightXMLTemplate = 	selfVar.owner:GetHighlightTemplate(control)
					}
--d(">control.LSM_rowHighlightData SET")
				end
			else
--d("<<<control.LSM_rowHighlightData DELETED")
				control.LSM_rowHighlightData = nil
			end
		end
	end
	--------------------------------------------------------------------------------------------------------------------
end

---------------------------------------
-- Deprecated functions
---------------------------------------
function dropdownClass:AddItems(items)
	error(debugPrefix .. 'scrollHelper:AddItems is obsolete. You must use m_comboBox:AddItems')
end

function dropdownClass:AddItem(item)
	error(debugPrefix .. 'scrollHelper:AddItem is obsolete. You must use m_comboBox:AddItem')
end


---------------------------------------
--Narration
---------------------------------------
function dropdownClass:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 56, tos(eventName), tos(getControlName(ctrl)), tos(hasSubmenu), tos(anchorPoint)) end
	self.owner:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint) -->comboBox_base:Narrate(...)
end

--Returns the handler naem for OnSho or OnHide for the normal dropdown, submenu and contextMenu
--> OnMenuShow / OnMenuHide
--> OnSubmenuShow / OnSubmenuHide
--> OnContextmenuShow / OnContextmenuHide
function dropdownClass:GetFormattedNarrateEvent(suffix)
	local formattedNarrateEvent = ''
	if self.owner then
		formattedNarrateEvent = sfor('On%s%s', self.owner:GetMenuPrefix(), suffix)
	end
	return formattedNarrateEvent
end

---------------------------------------
-- Other dropdownClass functions
----------------------------------------
local getDefaultXMLTemplates
function dropdownClass:SetupScrollList()
--df(debugPrefix.."dropdownClass:SetupScrollList")

	local selfVar = self
    local entryHeightWithSpacing = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT + self.spacing

	local XMLTemplate = "LibScrollableMenu_ComboBoxEntry"
	local ROWHeight = entryHeightWithSpacing
	local SetupScrollableEntry = function(...)
		selfVar:SetupEntry(...)
	end

	--LSM custom template data?
	getDefaultXMLTemplates = getDefaultXMLTemplates or libUtil.getDefaultXMLTemplates

	local comboBoxObject = selfVar.owner or selfVar.m_comboBox
	if comboBoxObject then
		local defaultTemplates = getDefaultXMLTemplates(comboBoxObject)
		if defaultTemplates ~= nil then
			local normalEntryData = defaultTemplates[entryTypeConstants.LSM_ENTRY_TYPE_NORMAL]
			if normalEntryData then
				XMLTemplate = normalEntryData.template
				ROWHeight = normalEntryData.rowHeight
				SetupScrollableEntry = function(...)
					return normalEntryData.setupFunc(...)
				end
			end
		end
	end

	local scrollCtrl = self.scrollControl
    -- To support spacing like regular combo boxes, a separate template needs to be stored for the last entry.
    ZO_ScrollList_AddDataType(scrollCtrl, DEFAULT_ENTRY_ID, "LibScrollableMenu_ComboBoxEntry", ROWHeight, SetupScrollableEntry)
    ZO_ScrollList_AddDataType(scrollCtrl, DEFAULT_LAST_ENTRY_ID, "LibScrollableMenu_ComboBoxEntry", ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT, SetupScrollableEntry)

    ZO_ScrollList_EnableHighlight(scrollCtrl, "ZO_TallListHighlight")
end

function dropdownClass:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 57, tos(entryTemplate), tos(entryHeight), tos(setupFunction), tos(widthPadding)) end

--d(debugPrefix .. "dropdownClass:AddCustomEntryTemplate - entryTemplate: " .. tos(entryTemplate))
	if not self.customEntryTemplateInfos then
		self.customEntryTemplateInfos = {}
	end

	if self.customEntryTemplateInfos[entryTemplate] ~= nil then
		-- we have already added this template
		return
	end

	local customEntryInfo =
	{
		typeId = self.nextScrollTypeId,
		entryHeight = entryHeight,
		widthPadding = widthPadding,
	}

	self.customEntryTemplateInfos[entryTemplate] = customEntryInfo

	local selfVar = self
	local entryHeightWithSpacing = entryHeight + self.spacing
	--Always add 1 dataType for the normal entry and the next will be the one for the last entry in the ZO_ScrollList (without any height spacing!)
	ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId, entryTemplate, entryHeightWithSpacing, setupFunction, function(...) poolControlReset(selfVar, ...) end)
	ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId + 1, entryTemplate, entryHeight, setupFunction, function(...) poolControlReset(selfVar, ...) end)

	self.nextScrollTypeId = self.nextScrollTypeId + 2
end

function dropdownClass:GetSubMenuOpeningSide() --#2025_34
--d(debugPrefix .. "dropdownClass:GetSubMenuOpeningSide")
	if self.m_comboBox then
		return self.m_comboBox:GetSubMenuOpeningSide()
	end
end

function dropdownClass:AnchorToControl(parentControl)
	local guiRootWidth, guiRootHeight = GuiRoot:GetDimensions()
	local right = true
	local openSubmenuToSideForced = false

	local offsetX = parentControl.m_dropdownObject.scrollControl.scrollbar:IsHidden() and ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y or ZO_SCROLL_BAR_WIDTH
--	local offsetX = -4

	local offsetY = -ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y
--	local offsetY = -4

	local point, relativePoint = TOPLEFT, TOPRIGHT

	--It's a submenu and got a parentMenu? Check if we should anchor to the right
	if self.m_parentMenu ~= nil then
		openSubmenuToSideForced, right = checkWhereToShowSubmenu(self) --#2025_34

		local parentDropdownObject = self.m_parentMenu.m_dropdownObject
		if right == nil and parentDropdownObject.anchorRight ~= nil then
			right = parentDropdownObject.anchorRight
		end
	end

	--Should we anchor the menu to the left or the right of the control > Check if it fits to the maximum GuiRoot's width!
	if not right or (not openSubmenuToSideForced and ((parentControl:GetRight() + self.control:GetWidth()) > guiRootWidth)) then
		right = false
	--	offsetX = 4
		offsetX = 0
		point, relativePoint = TOPRIGHT, TOPLEFT
	end

	local relativeTo = parentControl
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 58, tos(point), tos(getControlName(relativeTo)), tos(relativePoint), tos(offsetX), tos(offsetY)) end

	self.control:ClearAnchors()
	self.control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)

	self.anchorRight = right
end

function dropdownClass:AnchorToComboBox(comboBox)
	local parentControl = comboBox:GetContainer()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 59, tos(getControlName(parentControl))) end
	self.control:ClearAnchors()
	self.control:SetAnchor(TOPLEFT, parentControl, BOTTOMLEFT)
end

function dropdownClass:AnchorToMouse()
	local menuToAnchor = self.control

	local x, y                        = GetUIMousePosition()
	local GUIRootWidth, GUIRootHeight = GuiRoot:GetDimensions()

	menuToAnchor:ClearAnchors()

	local openSubmenuToSideForced, right = checkWhereToShowSubmenu(self) --#2025_34
	if not openSubmenuToSideForced then
		if (x + menuToAnchor:GetWidth()) > GUIRootWidth then
			right = false
		end
	end

	local bottom = true
	if (y + menuToAnchor:GetHeight()) > GUIRootHeight then
		bottom = false
	end

	local point, relativeTo, relativePoint
	if right then
		x = x + 2
		if bottom then
			point = TOPLEFT
			relativeTo = nil
			relativePoint = TOPLEFT
		else
			point = BOTTOMLEFT
			relativeTo = nil
			relativePoint = TOPLEFT
		end
	else
		x = x - 2
		if bottom then
			point = TOPRIGHT
			relativeTo = nil
			relativePoint = TOPLEFT
		else
			point = BOTTOMRIGHT
			relativeTo = nil
			relativePoint = TOPLEFT
		end
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 60, tos(point), tos(getControlName(relativeTo)), tos(relativePoint), tos(x), tos(y)) end
	if point and relativePoint then
		menuToAnchor:SetAnchor(point, relativeTo, relativePoint, x, y)
	end
end

function dropdownClass:GetSubmenu()
	if self.owner then
		self.m_submenu = self.owner.m_submenu
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 61, tos(self.m_submenu)) end

	return self.m_submenu
end

function dropdownClass:IsDropdownVisible()
	-- inherited ZO_ComboBoxDropdown_Keyboard:IsHidden
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 62, tos(not self:IsHidden())) end
	return not self:IsHidden()
end

function dropdownClass:IsEnteringSubmenu()
	local submenu = self:GetSubmenu()
	if submenu then
		if submenu:IsDropdownVisible() and submenu:IsMouseOverControl() then
			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 63) end
			return true
		end
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 64) end
	return false
end

--todo 20250203 Why is this function here? As aS proxy to the comboBoxClass:IsItemSelected function?
function dropdownClass:IsItemSelected(item)
--d(debugPrefix .. "dropdownClass:IsItemSelected - item: " ..tos(item))
	if self.owner and self.owner.IsItemSelected then
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 65, tos(self.owner:IsItemSelected(item))) end
--d(">dropdownClass:IsItemSelected 1")
		return self.owner:IsItemSelected(item)
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 66) end
--d(">dropdownClass:IsItemSelected returning false")
	return false
end

function dropdownClass:IsMouseOverOpeningControl()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 67) end
	return false
end

function dropdownClass:OnMouseEnterEntry(control)
--d(debugPrefix .. "dropdownClass:OnMouseEnterEntry - name: " .. tos(getControlName(control)))
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 68, tos(getControlName(control))) end
	-- Added here for when mouse is moved from away from dropdowns over a row, it will know to close specific children
	self:OnMouseExitTimeout(control)

	local data = getControlData(control)
	if data.enabled == true then
		if not runHandler(self, handlerFunctions["onMouseEnter"], control, data) then
			--Each entryType uses the default scrolltemplates.lua, function PlayAnimationOnControl via the zo_comboBoxDropdown_onMouseEnterEntry function call,
			--which calls ZO_ScrollList_MouseEnter -> which calls HighlightControl -> Which calls self.highlightTemplateOrFunction(control) to get/create the
			--highlight control, and assign the virtual XML template to it, and to set the highlight animation on the control.
			--> See function dropdownClass:Initialize -> function scrollCtrl.highlightTemplateOrFunction and function scrollCtrl.highlightCallback here in LSM
			zo_comboBoxDropdown_onMouseEnterEntry(self, control)
		end

		if data.tooltip or data.customTooltip then
--d(">calling self:ShowTooltip ")
			self:ShowTooltip(control, data)
		end
	end

	--TODO: Conflicting OnMouseExitTimeout -> 20240310 What in detail is conflicting here, with what?
	g_contextMenu = getContextMenuReference()
	if g_contextMenu:IsDropdownVisible() then
		--d(">contex menu: Dropdown visible = yes")
		g_contextMenu.m_dropdownObject:OnMouseExitTimeout(control)
	end
end

function dropdownClass:OnMouseExitEntry(control)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 69, tos(getControlName(control))) end

	hideTooltip(control)
	local data = getControlData(control)
	self:OnMouseExitTimeout(control)
	if data.enabled and not runHandler(self, handlerFunctions["onMouseExit"], control, data) then
		zo_comboBoxDropdown_onMouseExitEntry(self, control)
	end

	--[[
	if not lib.GetPersistentMenus() then
--		self:OnMouseExitTimeout(control)
	end
	]]
end

function dropdownClass:OnMouseExitTimeout(control)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 70, tos(getControlName(control))) end
	setTimeout(function()
		self.owner:HideOnMouseExit(moc())
	end)
end

--Calls comboBox_class:SetSelected
function dropdownClass:OnEntrySelected(control)
--d(debugPrefix .."dropdownClass:OnEntrySelected-"  .. tos(getControlName(control)))
    if self.owner then
        self.owner:SetSelected(control.m_data.m_index)
    end
end

--Called from XML virtual template <Control name="ZO_ComboBoxEntry" -> "OnMouseUp" -> ZO_ComboBoxDropdown_Keyboard.OnEntryMouseUp
-->And in LSM code from XML virtual template LibScrollableMenu_ComboBoxEntry_Behavior -> "OnMouseUp" -> dropdownClass:OnEntryMouseUp
function dropdownClass:OnEntryMouseUp(control, button, upInside, ignoreHandler, ctrl, alt, shift, lsmEntryType)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 71, tos(getControlName(control)), tos(button), tos(upInside)) end
--d(debugPrefix .."dropdownClass:OnEntryMouseUp-"  .. tos(getControlName(control)) ..", button: " .. tos(button) .. ", upInside: " .. tos(upInside))
	--20240816 Suppress the next global mouseup event raised from a comboBox's dropdown (e.g. if a submenu entry outside of a context menu was clicked
	--while a context menu was opened, and the context menu was closed then due to this click, but the global mouse up handler on the sbmenu entry runs
	--afterwards)
	lib.preventerVars.suppressNextOnGlobalMouseUp = nil
	lib.preventerVars.suppressNextOnEntryMouseUp = nil --#2025_13

	if upInside then
		local data = getControlData(control)
		--	local comboBox = getComboBox(control, true)
		local comboBox = control.m_owner

		--[[
LSM_Debug = LSM_Debug or {}
LSM_Debug._OnEntryMouseUp = LSM_Debug._OnEntryMouseUp or {}
LSM_Debug._OnEntryMouseUp[#LSM_Debug._OnEntryMouseUp +1] = {
	self = self,
	control = control,
	comboBox = comboBox,
	data = data,
	enabled = data and data.enabled,
	multiSelectEnabledComboBox = comboBox.m_enableMultiSelect,
	multiSelectEnabledDropdownOwner = self.owner.m_enableMultiSelect,
	isSubmenu = self.isSubmenu or comboBox.isSubmenu
}
]]

		if data.enabled then
			if button == MOUSE_BUTTON_INDEX_LEFT then
				if lsmEntryType == entryTypeConstants.LSM_ENTRY_TYPE_EDITBOX then return end

				if checkIfContextMenuOpenedButOtherControlWasClicked(control, comboBox, button) == true then
					--d("3??? Setting suppressNextOnGlobalMouseUp = true ???")
					lib.preventerVars.suppressNextOnGlobalMouseUp = true
					--d("<ABORT -> [dropdownClass:OnEntryMouseUp]MOUSE_BUTTON_INDEX_LEFT -> suppressNextOnGlobalMouseUp: " ..tos(lib.preventerVars.suppressNextOnGlobalMouseUp))
					return
				end

				--Multiselection enabled?
				local isMultiSelectionEnabledAtParentMenu = comboBox.m_parentMenu and comboBox.m_parentMenu.m_enableMultiSelect
				local isMultiSelectionEnabled = comboBox.m_enableMultiSelect

				--20250129 isMultiSelectionEnabled is false, so that means the main LSM menu's options are passed to the main menu combobox, but the access here to submenu combobox.m_enableMultiSelect
				--does not respect the metatables setup in submenuClass:New? It does not read it from the parent/main menu!
				local isSubmenu = comboBox.isSubmenu
				if isSubmenu then
					-->So this here is a workaround to update the submenu's combobox m_enableMultiSelect from the m_parentMenu, if it's missing in the submenu
					if isMultiSelectionEnabledAtParentMenu == true and isMultiSelectionEnabled == false then
						--d(">multiSelection taken from parentMenu")
						self.owner.m_enableMultiSelect = true
					end
				end
				--d(debugPrefix .. "OnEntryMouseUp-multiSelection/atParent: " ..tos(isMultiSelectionEnabled) .."/" .. tos(isMultiSelectionEnabledAtParentMenu) .. ", isSubmenu: " .. tos(isSubmenu))
				--d(">self.owner.m_enableMultiSelect: " ..tos(self.owner.m_enableMultiSelect))


				--20250309 if the last comboBox_base:HiddenForReasons call closed an open contextMenu with multiSelect enabled, and we clicked on an LSM entry of another non-contextmenu
				--to close it, then just exit here and do not select the clicked entry
				--d("[dropdownClass:OnEntryMouseUp]MOUSE_BUTTON_INDEX_LEFT -> suppressNextOnEntryMouseUp: " ..tos(lib.preventerVars.suppressNextOnEntryMouseUp))
				if checkNextOnEntryMouseUpShouldExecute() then --#2025_13
					--#2025_18 Clicking a non-context menu submenu entry, while a context menu is opeed above, close the context nmenu BUT also selects that submenu entry and closes the whole  dropdown then
					-->That's because of evet_global_mouse_up fires on the submenu entry (if multiselection is disabled) and selects the entry. Trying to suppress it here
					if isSubmenu and not isMultiSelectionEnabled and lib.preventerVars.wasContextMenuOpenedAsOnMouseUpWasSuppressed then
						--d(">>preventerVars.wasContextMenuOpenedAsOnMouseUpWasSuppressed: true -> Setting suppressNextOnGlobalMouseUp = true")
						--d("4??? Setting suppressNextOnGlobalMouseUp = true ???")
						lib.preventerVars.suppressNextOnGlobalMouseUp = true
					end
					lib.preventerVars.wasContextMenuOpenedAsOnMouseUpWasSuppressed = nil
					--d("<<ABORTING")
					return
				end


				if not ignoreHandler and runHandler(self, handlerFunctions["onMouseUp"], control, data, button, upInside, ctrl, alt, shift) then
					--d(">>OnEntrySelected")
					self:OnEntrySelected(control) --self (= dropdown).owner (= combobox):SetSelected -> self.SelectItem
				else
					--d(">>RunItemCallback - ignoreHandler: " ..tos(ignoreHandler))
					self:RunItemCallback(data, data.ignoreCallback)
				end

				--Show context menu at the entry?
			elseif button == MOUSE_BUTTON_INDEX_RIGHT then
				g_contextMenu = getContextMenuReference()
				g_contextMenu.contextMenuIssuingControl = nil --#2025_28 Reset the contextMenuIssuingControl of the contextMenu for API functions
				local rightClickCallback = data.contextMenuCallback or data.rightClickCallback
				if rightClickCallback and not g_contextMenu.m_dropdownObject:IsOwnedByComboBox(comboBox) then
					--#2025_22 Check if the openingControl is another contextMenu -> We cannot show a contextMenu on a contextMenu
					if libUtil_BelongsToContextMenuCheck(control:GetOwningWindow()) then
						--d("<ABOER: contextMenu opening at a contextMenu entry -> Not allowed!")
						return
					end

					if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 72) end
					--d(">setting g_contextMenu.contextMenuIssuingControl: " ..tos(control and control:GetName() or "???"))
					g_contextMenu.contextMenuIssuingControl = control --#2025_28 Set the contextMenuIssuingControl of the contextMenu for API functions
					rightClickCallback(comboBox, control, data)
				end
			end
		else
			if comboBox.isSubmenu then
				--d(">disabled, submenu entry clicked. Supressing next onGlobalMouseUp to keep the submenu opened!")
				lib.preventerVars.suppressNextOnGlobalMouseUp = true
			end
		end
	end
end

--[[
function ZO_ComboBoxDropdown_Keyboard.OnEntryMouseUp(control, button, upInside)
	if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
		local dropdown = control.m_dropdownObject
		if dropdown then
			dropdown:OnEntrySelected(control)
		end
	end
end
]]

function dropdownClass:SelectItemByIndex(index, ignoreCallback)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 73, tos(index), tos(ignoreCallback)) end
	if self.owner then
		playSelectedSoundCheck(self, nil)
		return self.owner:SelectItemByIndex(index, ignoreCallback)
	end
end

function dropdownClass:RunItemCallback(item, ignoreCallback)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 74, tos(item), tos(ignoreCallback)) end
	if self.owner then
		playSelectedSoundCheck(self, item.entryType)
		return self.owner:RunItemCallback(item, ignoreCallback) --calls comboBox_base:RunItemCallback
	end
end

function dropdownClass:UpdateHeight()
--d(debugPrefix .. "dropdownClass:UpdateHeight")
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 77) end
	if self.owner then
		self.owner:UpdateHeight(self.control)
	end
end

function dropdownClass:UpdateWidth()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 178) end
	if self.owner then
		self.owner:UpdateWidth(self.control)
	end
end

--Will be executed from XML handlers -> formattedEventName will be build via method GetFormattedNarrateEvent
function dropdownClass:OnShow(formattedEventName)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 78) end
--	self.control:BringWindowToTop()

	if formattedEventName ~= nil then
		local anchorRight = self.anchorRight and 'Right' or 'Left'
		local ctrl = self.control
		lib:FireCallbacks(formattedEventName, ctrl, self)

		throttledCall(function()
			self:Narrate(formattedEventName, ctrl, nil, nil, anchorRight)
		end, 100, "_DropdownClassOnShow")
	end
end

--Will be executed from XML handlers -> formattedEventName will be build via method GetFormattedNarrateEvent
function dropdownClass:OnHide(formattedEventName)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 79) end
	if formattedEventName ~= nil then
		local ctrl = self.control
		lib:FireCallbacks(formattedEventName, ctrl, self)
		self:Narrate(formattedEventName, ctrl)
	end
end

--Called from comboBox_base:Show()
function dropdownClass:Show(comboBox, itemTable, minWidth, maxWidth, maxHeight, spacing)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 75, tos(getControlName(comboBox:GetContainer())), tos(minWidth), tos(maxWidth), tos(maxHeight), tos(spacing)) end
--d(debugPrefix .. "dropdownClass:Show - minWidth: " ..tos(minWidth) .. ", maxHeight: " .. tos(maxHeight))

	self.owner = comboBox

	local comboBoxObject = self.m_comboBox

	-- externally defined
	ignoreSubmenu, filterString, filterFunc = nil, nil, nil
	lastEntryVisible = false
	--options.enableFilter == true?
	if self:IsFilterEnabled() then
		ignoreSubmenu, filterString = comboBoxObject.filterString:match('(/?)(.*)') -- starts with / and followed by .* to include special characters
		filterFunc = comboBoxObject:GetFilterFunction()
	else
		self:ResetFilters(comboBoxObject.m_dropdown)
	end
	filterString = filterString or ''
	-- Convert ignoreSubmenu to bool
	-->If ignoreSubmenu == true: Show submenu entries even if they do not match the search term (as long as the submenu name matches the search term)
	ignoreSubmenu = ignoreSubmenu == '/'

	--Any text entered?
	local textSearchEnabled = filterString ~= ''
	--Text filter should show non-matching submenu entries? "/" prefix was used in text filter editBox
	if textSearchEnabled and comboBox.isSubmenu then
		if ignoreSubmenu == true then
			textSearchEnabled = false
		end
	end

	local control = self.control
	local scrollControl = self.scrollControl

	ZO_ScrollList_Clear(scrollControl)

	self:SetSpacing(spacing)

	local numItems = #itemTable
	local largestEntryWidth = 0
	local dataList = ZO_ScrollList_GetDataList(scrollControl)

	--Take control.header's height into account here as base height too
	local allItemsHeight = comboBox:GetBaseHeight(control)

	local anyItemMatchesFilter = false

	for i = 1, numItems do
		local item = itemTable[i]
		local isLastEntry = i == numItems

		local itemMatchesFilter = itemPassesFilter(item, comboBox, textSearchEnabled)
		if itemMatchesFilter and not anyItemMatchesFilter then
			anyItemMatchesFilter = true
		end
		lastEntryVisible        = itemMatchesFilter and true or false
		--#2025_26   Filter header: If the filter header filtered all items and we left click the "No search results" entry it will call the callback of another LSM control (looks like the controls of the scrollList are not properly destroyed from the pool and this the current control (entry of m_sortedItems of that combobox) is just changing the label text, but nothing else?
		--Trying to add an extra item instead therefore!
		local addItem           = (itemMatchesFilter == true or (isLastEntry and ZO_IsTableEmpty(dataList) and true)) or false
		local itemToAdd         = (addItem and ((itemMatchesFilter and item) or (not itemMatchesFilter and noEntriesResults))) or nil

		if addItem and itemToAdd ~= nil then
			allItemsHeight, largestEntryWidth = addEntryToScrollList(self, itemToAdd, dataList, i, allItemsHeight, largestEntryWidth, spacing, isLastEntry, not anyItemMatchesFilter, comboBoxObject)
		end
	end

	-- using the exact width of the text can leave us with pixel rounding issues
	-- so just add 5 to make sure we don't truncate at certain screen sizes
	largestEntryWidth = largestEntryWidth + 5
	-- Allow the dropdown to automatically widen to fit the widest entry, but
	-- prevent it from getting any skinnier than the container's initial width
	local longestEntryTextWidth = largestEntryWidth + (ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2) + ZO_SCROLL_BAR_WIDTH

	--Any options.minDropdownWidth "fixed width" chosen?
	local minDropdownWidth = comboBoxObject:GetMinDropdownWidth()
	if minDropdownWidth and minDropdownWidth > minWidth then
		minWidth = minDropdownWidth
	end
	--Any options.maxDropdownWidth "fixed width" chosen?
	local maxDropdownWidth = comboBoxObject:GetMaxDropdownWidth()
	--If a maxWidth was set in the options then use that one, else use the auto-size of the longest entry. If the auto-size of the longest entry is smaller than the maxWidth, then use that instead!
	local totalDropDownWidth = (maxDropdownWidth ~= nil and maxDropdownWidth < longestEntryTextWidth and maxDropdownWidth) or longestEntryTextWidth or maxWidth
	--Check if a minWidth is > than totalDropDownWidth
	local desiredWidth = zo_clamp(totalDropDownWidth, minWidth, totalDropDownWidth)

--d(">[LSM]dropdownClass:Show - minWidth: " .. tos(minWidth) ..", maxDropdownWidth: " .. tos(maxDropdownWidth) ..", maxWidth: " .. tos(maxWidth) .. ", totalDropDownWidth: " .. tos(totalDropDownWidth) .. ", longestEntryTextWidth: " ..tos(longestEntryTextWidth) ..", desiredWidth: " .. tos(desiredWidth))

	--maxHeight should have been defined before via self:UpdateHeight() -> Settings control:SetHeight() so self.m_height was set
	local desiredHeight = maxHeight
	ApplyTemplateToControl(scrollControl.contents, getScrollContentsTemplate(allItemsHeight < desiredHeight))
	-- Add padding one more time to account for potential pixel rounding issues that could cause the scroll bar to appear unnecessarily.
	allItemsHeight = allItemsHeight + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2) + 1

	if allItemsHeight < desiredHeight then
		desiredHeight = allItemsHeight
	end
	--	ZO_Scroll_SetUseScrollbar(self, false)

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 76, tos(totalDropDownWidth), tos(allItemsHeight), tos(desiredHeight)) end

	ZO_Scroll_SetUseFadeGradient(scrollControl, not self.owner.disableFadeGradient )
	control:SetWidth(desiredWidth)
	control:SetHeight(desiredHeight)

	ZO_ScrollList_SetHeight(scrollControl, desiredHeight)
	ZO_ScrollList_Commit(scrollControl)
end

function dropdownClass:ShowSubmenu(control)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 80, tos(getControlName(control))) end
	if self.owner then
		-- Must clear now. Otherwise, moving onto a submenu will close it from exiting previous row.
		clearTimeout()
		self.owner:ShowSubmenu(control)
	end
end

function dropdownClass:ShowTooltip(control, data)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 81, tos(getControlName(control)), tos(data.hasSubmenu)) end
	showTooltip(self, control, data, data.hasSubmenu)
end

function dropdownClass:HideDropdown()
--d("dropdownClass:HideDropdown()")
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 82) end
	if self.owner then
		self.owner:HideDropdown()
	end
end

--Called from checkNormalOnMouseEnterTasks, and dropdownClass:OnEntryMouseUp -> dropdownClass:OnEntrySelected -> --self(= dropdownClass).owner(= comboBoxClass of parentMenu?!):SetSelected -> self(comboBoxClass):SelectItem -> self.m_dropdownObject(dropdownClass):Refresh()
-->Needed to make multiselection for submenus work! Checked scrollControl must be the one of the submenu and not the parentMenu's!
function dropdownClass:Refresh(item)
--d(debugPrefix.."dropdownClass:Refresh - item: " ..tos(item))
	local entryData = nil
	local scrollControl = self.scrollControl

	if item then
		--20250131 self is the dropdownClass of the parentMenu, if a submenu item was clicked and the OnMouseUp -> comboBox:SetSelected -> dropdown refresh was called?
		--So why isn't self the dropdownClass of the submenu where the entry was clicked? That way the comparison of self.scrollControl's data:GetDataSource() is always wrong with the item passed in
		--and the items of the submenu never get selected, or updated properly.
		--Get the item's owner's scroll, if it's a submenu
		scrollControl = (item.m_owner ~= nil and item.m_owner.m_scroll) or nil
		if scrollControl ~= nil then
			entryData = compareDropdownDataList(self, scrollControl, item)
--d(">>found submenu #" .. tos(#ZO_ScrollList_GetDataList(scrollControl)) .. ", parentMent #" .. tos(#ZO_ScrollList_GetDataList(self.scrollControl)) .. "; entryData: " ..tos(entryData))
		end

		--No submenu entry found, compare with parent menu
		if entryData == nil then
--d(">>>taking parent menu entryData!")
			scrollControl = self.scrollControl
			entryData = compareDropdownDataList(self, scrollControl, item)
		end
	end
	ZO_ScrollList_RefreshVisible(scrollControl, entryData)
end


---------------------------------------
-- XML handlers
----------------------------------------
--Called from XML "LibScrollableMenu_Dropdown_Behavior"
function dropdownClass:XMLHandler(selfVar, handlerName)
	if selfVar == nil or handlerName == nil then return end

	if handlerName == "OnEffectivelyHidden" then
		self:HideDropdown()
	elseif handlerName == "OnMouseEnter" then
		self:OnMouseExitTimeout(selfVar)

	elseif handlerName == "OnShow" then
		self:OnShow(self:GetFormattedNarrateEvent('Show'))
	elseif handlerName == "OnHide" then
		self:OnHide(self:GetFormattedNarrateEvent('Hide'))
	end
end


--------------------------------------------------------------------
-- Dropdown text search functions
--------------------------------------------------------------------
local function setTextSearchEditBoxText(selfVar, filterBox, newText)
--d(debugPrefix .. "setTextSearchEditBoxText - wasTextSearchContextMenuEntryClicked = true")
	selfVar.wasTextSearchContextMenuEntryClicked = true
	filterBox:SetText(newText) --will call dropdownClass:SetFilterString() then
end

local function clearTextSearchHistory(self, comboBoxContainerName)
--d(debugPrefix .. "clearTextSearchHistory - wasTextSearchContextMenuEntryClicked = true")
	self.wasTextSearchContextMenuEntryClicked = true
	if comboBoxContainerName == nil or comboBoxContainerName == "" then return end
	if ZO_IsTableEmpty(lib.SV.textSearchHistory[comboBoxContainerName]) then return end
	lib.SV.textSearchHistory[comboBoxContainerName] = nil
end

local function addTextSearchEditBoxTextToHistory(comboBox, filterBox, historyText)
	historyText = historyText or filterBox:GetText()
	if comboBox == nil or historyText == nil or historyText == "" then return end
	local comboBoxContainerName = comboBox:GetUniqueName()
	if comboBoxContainerName == nil or comboBoxContainerName == "" then return end

	lib.SV.textSearchHistory[comboBoxContainerName] = lib.SV.textSearchHistory[comboBoxContainerName] or {}
	local textSearchHistory = lib.SV.textSearchHistory[comboBoxContainerName]
	--Entry already in the history, abort now
	if ZO_IsElementInNumericallyIndexedTable(textSearchHistory, historyText) then return end
	tins(textSearchHistory, 1, historyText)

	--Remove any entry > 10 (remove last ones first)
	local numEntries = #textSearchHistory
	if numEntries > 10 then
		--Remove last entry in the list
		trem(textSearchHistory, numEntries)
	end
end

function dropdownClass:WasTextSearchContextMenuEntryClicked(mocCtrl)
--d("dropdownClass:WasTextSearchContextMenuEntryClicked - wasTextSearchContextMenuEntryClicked: " ..tos(self.wasTextSearchContextMenuEntryClicked))
	--Internal variable was set as we selected a ZO_Menu entry at the header's editBox right click contextMenu?
	if self.wasTextSearchContextMenuEntryClicked then
		self.wasTextSearchContextMenuEntryClicked = nil
--d(">wasTextSearchContextMenuEntryClicked was TRUE")
		return true
	end
	--Clicked control is known and the owner is ZO_Menus -> then assume we did open the ZO_Menu above an LSM and need the LSM to stay open
	if mocCtrl ~= nil and mocCtrl:GetOwningWindow() == ZO_Menus then
--d(">ZO_Menus entry clicked!")
		return true
	end
	return false
end

function dropdownClass:SetFilterString(filterBox)
 --d("dropdownClass:SetFilterString")
	if self.m_comboBox then
		-- It probably does not need this but, added it to prevent lagging from fast typing.
		throttledCall(function()
			local text = filterBox:GetText()
--d(">throttledCall 1 - text: " ..tos(text))
			self.m_comboBox:SetFilterString(filterBox, text)

			--Delay the addition of a new text search history entry to take place after 1 second so we do not add
			--parts of currently typed characters
			throttledCall(function()
--d(">throttledCall 2 - Text search history")
				addTextSearchEditBoxTextToHistory(self.m_comboBox, filterBox, text)
			end, 990, throttledCallDropdownClassSetFilterStringSuffix)
		end, 10, throttledCallDropdownClassSetFilterStringSuffix)
	end
end

function dropdownClass:ShowFilterEditBoxHistory(filterBox)
	lib.preventerVars.suppressNextOnEntryMouseUpDisableCounter = nil

	local selfVar = self
	local comboBox = self.m_comboBox
	if comboBox ~= nil then
		local comboBoxContainerName = comboBox:GetUniqueName()
--d(debugPrefix .. "dropdownClass:ShowFilterEditBoxHistory - comboBoxContainerName: " .. tos(comboBoxContainerName))
		if comboBoxContainerName == nil or comboBoxContainerName == "" then return end
		--Get the last saved text search (history) and show them as context menu
		local textSearchHistory = lib.SV.textSearchHistory[comboBoxContainerName]
		if not ZO_IsTableEmpty(textSearchHistory) then
			self.wasTextSearchContextMenuEntryClicked = nil
			ClearMenu()
			for idx, textSearched in ipairs(textSearchHistory) do
				if textSearched ~= "" then
					AddMenuItem(tos(idx) .. ". " .. textSearched, function()
						setTextSearchEditBoxText(selfVar, filterBox, textSearched)
					end)
				end
			end
			if LibCustomMenu then
				AddCustomMenuItem("-") --if LCM is enabled. Add divider, for better readability
			end
			AddMenuItem("- " .. GetString(SI_STATS_CLEAR_ALL_ATTRIBUTES_BUTTON) .." - ", function()
				clearTextSearchHistory(selfVar, comboBoxContainerName)
			end)

			--Prevent LSM Hook at ShowMenu() to close the LSM below the cursor!!!
			lib.preventLSMClosingZO_Menu = true
--d(">preventLSMClosingZO_Menu: " ..tos(lib.preventLSMClosingZO_Menu))
			ShowMenu(filterBox)
			ZO_Tooltips_HideTextTooltip()
		end
	end
end


function dropdownClass:OnFilterEditBoxMouseUp(filterBox, button, upInside, ctrl, alt, shift)
	--Only react on right click
	ZO_Tooltips_HideTextTooltip()
	if not upInside or button ~= MOUSE_BUTTON_INDEX_RIGHT then return end

	self:ShowFilterEditBoxHistory(filterBox)
end

function dropdownClass:ResetFilters(owningWindow)
--d(debugPrefix .. "dropdownClass:ResetFilters")
	--If not showing the filters at a contextmenu
	-->Close any opened contextmenu
	if self.m_comboBox ~= nil then
		if not self.m_comboBox.isContextMenu then --#2025_23 replaced by self.m_comboBox.isContextMenu -> self.m_comboBox.openingControl == nil then
			--d(">>calling ClearCustomScrollableMenu")
			ClearCustomScrollableMenu()
		end
	end

	ZO_Tooltips_HideTextTooltip()
	if not owningWindow or not owningWindow.filterBox then return end
	owningWindow.filterBox:SetText('') --calls dropdownClass:SetFilterString(filterBox)
end

function dropdownClass:IsFilterEnabled()
--d(debugPrefix .. "dropdownClass:IsFilterEnabled")
	if self.m_comboBox then
		return self.m_comboBox:IsFilterEnabled()
	end
end

--[[ Used via XML button to I (include) submenu entries. Currently disabled, only available via text search prefix "/"
function dropdownClass:SetFilterIgnore(ignore)
	self.m_comboBox.ignoreEmpty = ignore
	self.m_comboBox:UpdateResults()
end
]]

function dropdownClass:ShowTextTooltip(control, side, tooltipText, owningWindow)
	ZO_Tooltips_HideTextTooltip()
	--Do not show tooltip if the context menu at the search editbox is shown
	if not ZO_Menu:IsHidden() or tooltipText == nil or tooltipText == "" then return end
	--Do not show tooltip if cursor is in the search editbox (typing)
	if owningWindow == nil and control.GetOwningWindow ~= nil then owningWindow = control:GetOwningWindow() end
	if owningWindow ~= nil then
		local searchFilterTextBox = owningWindow.filterBox
		if searchFilterTextBox ~= nil and control == searchFilterTextBox and control:HasFocus() then return end
	end
	ZO_Tooltips_ShowTextTooltip(control, side, tooltipText)
	InformationTooltipTopLevel:BringWindowToTop()
end


--XML handler for editBox rows: OnTextChanged should trigger the callback function
function dropdownClass:OnEditBoxTextChanged(filterBox)
LSM_Debug = LSM_Debug or {}
LSM_Debug._filterbox = 	filterBox
LSM_Debug._comboBox = self.m_comboBox

	ZO_Tooltips_HideTextTooltip()
	local selfVar = self
	if selfVar.m_comboBox and filterBox then
		local callbackFunc = (filterBox.callback or (filterBox:GetParent() and filterBox:GetParent():GetParent() and filterBox:GetParent():GetParent().callback)) or nil
		if callbackFunc ~= nil then
			filterBox.callback = callbackFunc
		end
		-- It probably does not need this but, added it to prevent lagging from fast typing.
		throttledCall(function()
			local text = filterBox:GetText()
--d(">throttledCall 1 - text: " ..tos(text))
			callbackFunc(selfVar.m_comboBox, filterBox, text) --comboBox, filterBox, text
		end, 250, throttledCallDropdownClassOnTextChangedStringSuffix)
	end
end
