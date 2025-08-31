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
local AM = GetAnimationManager() --ANIMATION_MANAGER
local EM = GetEventManager() --EVENT_MANAGER
local tos = tostring
local sfor = string.format

local functionType = "function"
local userdataType = "userdata"
local stringType = "string"
local tableType = "table"


-----------------------------------------------------------------------
-- Library utility
--------------------------------------------------------------------
local constants = lib.constants
local fontConstants = constants.fonts
local entryTypeConstants = constants.entryTypes
local colorConstants = constants.colors
local soundConstants = constants.sounds
local handlerNameConstants = constants.handlerNames
local subTableConstants = constants.data.subtables
local defaultHighlightData = entryTypeConstants.defaults.highlights


local libUtil = lib.Util


-----------------------------------------------------------------------
-- Library local utility variables
--------------------------------------------------------------------
local libDivider = lib.DIVIDER
local NIL_CHECK_TABLE = constants.NIL_CHECK_TABLE

local additionalDataKeyToLSMEntryType = entryTypeConstants.additionalDataKeyToLSMEntryType

--local sv



--Throttled calls
local throttledCallDelaySuffixCounter = 0
local throttledCallDelayName = handlerNameConstants.throttledCallDelayName
local throttledCallDelay = constants.throttledCallDelay

--Context menus
local g_contextMenu
local contextMenuContainer

local getValueOrCallback = libUtil.getValueOrCallback
local getControlName
local getControlData
local recursiveOverEntries
local getComboBox
local recursiveMultiSelectSubmenuOpeningControlUpdate
local checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect

--local levelChecked = 0
local alreadyCheckedSubmenuOpeningItems = {}

--------------------------------------------------------------------
-- Controls
--------------------------------------------------------------------
function libUtil.getControlName(control, alternativeControl)
	local ctrlName = control ~= nil and (control.name or (control.GetName ~= nil and control:GetName()))
	if ctrlName == nil and alternativeControl ~= nil then
		ctrlName = (alternativeControl.name or (alternativeControl.GetName ~= nil and alternativeControl:GetName()))
	end
	ctrlName = ctrlName or "n/a"
	return ctrlName
end
getControlName = libUtil.getControlName

function libUtil.getHeaderControl(selfVar)
	if ZO_IsTableEmpty(selfVar.options) then return end
	local dropdownControl = selfVar.m_dropdownObject.control
	return dropdownControl.header, dropdownControl
end
local getHeaderControl = libUtil.getHeaderControl


--------------------------------------------------------------------
--SavedVariables - Functions
--------------------------------------------------------------------
function libUtil.updateSavedVariable(svOptionName, newValue, subTableName)
--d(debugPrefix .. "updateSavedVariable - svOptionName: " ..tostring(svOptionName) .. ", newValue: " ..tostring(newValue) ..", subTableName: " ..tostring(subTableName))
	if svOptionName == nil then return end
	local svOptionData = lib.SV[svOptionName]
	if svOptionData == nil then return end
	if subTableName ~= nil then
		if type(svOptionData) ~= tableType then return end
--d(">>sv is table")
		lib.SV[svOptionName][subTableName] = newValue
	else
		lib.SV[svOptionName] = newValue
	end
	--sv = lib.SV
end


function libUtil.getSavedVariable(svOptionName, subTableName)
	if svOptionName == nil then return end
	local svOptionData = lib.SV[svOptionName]
	if svOptionData == nil then return end
	if subTableName ~= nil then
		if type(svOptionData) ~= tableType then return end
		return lib.SV[svOptionName][subTableName]
	else
		return lib.SV[svOptionName]
	end
end


--------------------------------------------------------------------
-- Data & data source determination
--------------------------------------------------------------------
function libUtil.getDataSource(dataOrControl)
	local retData
	if dataOrControl ~= nil then
		retData = dataOrControl
		if retData.dataSource == nil and type(retData) == userdataType then
			retData = dataOrControl.m_data or dataOrControl
		end

		if retData and retData.dataSource then
			return retData:GetDataSource()
		end
	end
	return retData or NIL_CHECK_TABLE
end
local getDataSource = libUtil.getDataSource

-- >> data, dataEntry
function libUtil.getControlData(control)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 28, tos(getControlName(control))) end
	local data = control.m_sortedItems or control.m_data

	return getDataSource(data)
end
getControlData = libUtil.getControlData


--------------------------------------------------------------------
-- Entry functions
--------------------------------------------------------------------
function libUtil.getEditBoxData(control, data)
	--EditBox data was specified too?
	local editBoxData = getValueOrCallback(data.editBoxData, data)
	if type(editBoxData) == "table" then
		return editBoxData
	end
	return
end


function libUtil.compareDropdownDataList(selfVar, scrollControl, item)
	local dataList = ZO_ScrollList_GetDataList(scrollControl)

	for _, data in ipairs(dataList) do
		if data:GetDataSource() == item then
			return data
		end
	end
end
--local compareDropdownDataList = libUtil.compareDropdownDataList


local endlessLoopPreventionCounter = 0

-- Recursively loop over drdopdown entries, and submenu dropdown entries of that parent dropdown, and check if e.g. isNew needs to be updated
-- Used for the search of the collapsible header too
function libUtil.recursiveOverEntries(entry, comboBox, callback, ...)
	recursiveOverEntries = recursiveOverEntries or libUtil.recursiveOverEntries
	--local doDebug = callback and callback == checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect
	----if doDebug then d("!!!!!!!!!! RecursiveOverEntries") end
	endlessLoopPreventionCounter = 0
	--callback = callback or defaultRecursiveCallback
	--No need to loop all entries just to return false always in the end! Do return it early here
	if type(callback) ~= functionType then
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 19, 0, tos(false)) end
		return false
	end

	local result = callback(entry, comboBox, ...)
	local submenu = (entry.entries ~= nil and getValueOrCallback(entry.entries, entry)) or {}
	--[[
	if doDebug then
		d("!> Result: " ..tos(result) .. ", #submenu: " ..tos(#submenu))
	end
	]]

	if endlessLoopPreventionCounter >= 5000 then
d("[LSM]recursiveOverEntries - EEEEEEEEEEEEEEE   --ABORT ENDLESS LOOP--   EEEEEEEEEEEEEE")
		return
	end

	--local submenuType = type(submenu)
	--assert(submenuType == 'table', sfor('["..MAJOR..':recursiveOverEntries] table expected, got %q = %s', "submenu", tos(submenuType)))
	if type(submenu) == tableType and #submenu > 0 then
		for _, subEntry in pairs(submenu) do
			local subEntryResult = recursiveOverEntries(subEntry, comboBox, callback, ...)
			if subEntryResult then
				--[[
				if doDebug then
					d("!> subEntryResult: " ..tos(subEntryResult))
				end
				]]
				result = subEntryResult
			end
		end
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 19, tos(#submenu), tos(result)) end
	return result
end
recursiveOverEntries = libUtil.recursiveOverEntries

--Check if any submenu item is still selected within multiSelection
function libUtil.checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect(item, comboBox)
	checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect = checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect or libUtil.checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect
	--levelChecked = levelChecked + 1
	endlessLoopPreventionCounter = endlessLoopPreventionCounter + 1
	if endlessLoopPreventionCounter >= 10000 then return false end

	if item == nil or comboBox == nil then return false end
	if not comboBox.m_enableMultiSelect then return false end

	alreadyCheckedSubmenuOpeningItems[item] = true

	local result = false
	local currentSubmenuItems = item.m_owner and item.m_owner.m_sortedItems --comboBox.m_sortedItems
	if not ZO_IsTableEmpty(currentSubmenuItems) then
		--d("______________________________________________________________")
		--d("[checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect]levelChecked: " .. tos(levelChecked))
		--d(">found current submenu items #" ..tos(#currentSubmenuItems))
		local multiSelectedItemData = comboBox.m_multiSelectItemData
		if not ZO_IsTableEmpty(multiSelectedItemData) then
			--d(">>found currently selected items #" .. tos(#multiSelectedItemData))
			for _, currentSubmenuItem in ipairs(currentSubmenuItems) do
				for _, selectedSubmenuItem in ipairs(multiSelectedItemData) do
					if selectedSubmenuItem == currentSubmenuItem then
						--d(">>>found still selected item in submenu: " ..tos(selectedSubmenuItem))
						--[[
						LSM_Debug = LSM_Debug or {}
						LSM_Debug.checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect = LSM_Debug.checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect or {}
						LSM_Debug.checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect[#LSM_Debug.checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect +1] = {
							item = item ~= nil and ZO_ShallowTableCopy(item),
							comboBox = comboBox ~= nil and ZO_ShallowTableCopy(comboBox),
						}
						]]
						--Update the current submenu's comboBox openingControl arrow
						if comboBox.m_dropdownObject ~= nil and comboBox.openingControl ~= nil then
							--d(">>>>refreshing the scrolList's openingControl: " .. tos(comboBox.openingControl))
							local dataEntryOfOpeningControl = (comboBox.openingControl.dataEntry and comboBox.openingControl.dataEntry.data) or nil
							ZO_ScrollList_RefreshVisible(comboBox.m_dropdownObject.scrollControl, dataEntryOfOpeningControl)
						end
						return true
					elseif item ~= currentSubmenuItem and not alreadyCheckedSubmenuOpeningItems[currentSubmenuItem] and currentSubmenuItem.entries ~= nil then
	--d("<non selected submenuitem having a nested submenu: " ..tos(currentSubmenuItem.name or currentSubmenuItem.dataEntry.data.name))
						--Check if the item got another submenu and then check this one recursively too
						result = recursiveOverEntries(currentSubmenuItem, comboBox, checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect)
						--if result == true then return true end
					end
				end
			end
		end
	end
	return result
end
checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect = libUtil.checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect

--Recursively check the current item's submenu's openingControl and set the isAnySubmenuEntrySelected boolean value there,
--then check if that submenu got another parentMenu and go on upwards with these openingControls until all flags are set.
--Call the scrolllist update for the submenu's openingControl then to refresh the visible submenu opening arrow texture and color
function libUtil.recursiveMultiSelectSubmenuOpeningControlUpdate(selfVar, item, newValue, parentDepth)
	recursiveMultiSelectSubmenuOpeningControlUpdate = recursiveMultiSelectSubmenuOpeningControlUpdate or libUtil.recursiveMultiSelectSubmenuOpeningControlUpdate
	parentDepth = parentDepth or 0

--[[
LSM_Debug = LSM_Debug or {}
LSM_Debug.multiSelectSubmenuOpeningControlUpdate = LSM_Debug.multiSelectSubmenuOpeningControlUpdate or {}
local counter = #LSM_Debug.multiSelectSubmenuOpeningControlUpdate +1
]]

--d(debugPrefix .. "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
--d("[multiSelectSubmenuOpeningControlUpdate]counter: " .. tos(counter) ..", parentDepth: " ..tos(parentDepth))

	--Get the opening control of the currently shown submenu (if a submenu was opened)
	-->parentDepth > 0: selfVar is the openingControl's parentMenu
	local comboBoxOfItem = item.m_owner --(parentDepth == 0 and item.m_owner) or (parentDepth > 0 and selfVar) or nil
	if comboBoxOfItem == nil or not comboBoxOfItem.isSubmenu then return end
	local openingControl = comboBoxOfItem.openingControl --(selfVar ~= nil and selfVar.isSubmenu and selfVar.openingControl) or nil
--[[
LSM_Debug.multiSelectSubmenuOpeningControlUpdate[counter] = {
	selfVar = selfVar,
	openingControl = openingControl,
	item = type(item) == "table" and ZO_ShallowTableCopy(item) or item,
	newValue = newValue,
}
	]]

	if openingControl ~= nil then
		--d(">OpeningControl: " .. getControlName(openingControl))

		local foundStillSelectedItem = false
		local selectedEntries = comboBoxOfItem:GetNumSelectedEntries()
		local isAnyEntrySelected = selectedEntries > 0
		if not isAnyEntrySelected then
			--d("<["..(parentDepth) .."]not any entry selected anymore!")
			newValue = nil
		end

		--Check if no multiselect entry is selected at all anymore
		--Always check uowards if any arrow needs to be refreshed
		if newValue == true then
			--d(">["..(parentDepth) .."]isAnySubmenuEntrySelected = " ..tos(newValue))
			openingControl.isAnySubmenuEntrySelected = newValue
		end

		--Check recursively for another parentMenu (nested submenu's parent) -> "Go Up"
		local parentMenu = openingControl.m_owner ~= nil and openingControl.m_owner.m_parentMenu
		if parentMenu ~= nil and parentDepth < 100 then --security check to prevent endless loops! Max 100 iterations
			parentDepth = parentDepth + 1

			--d("-------->>found a parentMenu, depth: " ..tos(parentDepth))
			recursiveMultiSelectSubmenuOpeningControlUpdate(parentMenu, getDataSource(openingControl), newValue, parentDepth)
			--d("<--------back from parentmenu, depth: " ..tos(parentDepth))
		end

		--Check downwards for any arrow change needed too
		--levelChecked = 0
		--Check if any other entry is selected in the same submenu (or any deeper submenus) -> "Go down"
		--and only then set the openingControls isAnySubmenuEntrySelected = nil?
		--d("-------->>checkingRecursiveSubmenuEntries")
		alreadyCheckedSubmenuOpeningItems = {}
		foundStillSelectedItem = recursiveOverEntries(item, comboBoxOfItem, checkIfSubmenuEntriesAreCurrentlySelectedForMultiSelect)
		--d("<["..(parentDepth) .."]foundStillSelectedItem = " ..tos(foundStillSelectedItem))
		--No submenu item in the current, or nested deeper, submenu is still selected,
		--And we unselected the current?
		if not newValue and (not foundStillSelectedItem or not isAnyEntrySelected) then
			openingControl.isAnySubmenuEntrySelected = nil
		end

		--Mark the openingControl's arrow now via refreshing it and calling the setupFunction callback of the entryType
		if newValue == true or (not newValue and (not isAnyEntrySelected or not foundStillSelectedItem)) then
			if openingControl.m_dropdownObject ~= nil then
				local dataOfOpeningControl = openingControl.dataEntry.data --getDataSource(openingControl)
				--d(">refreshing scrollControl of openingControl, dataSource: " .. tos(dataOfOpeningControl ~= nil and dataOfOpeningControl.name))
				ZO_ScrollList_RefreshVisible(openingControl.m_dropdownObject.scrollControl, dataOfOpeningControl)
			end
		end
	--else
		--d("<openingControl not found!")
	end
	--d(debugPrefix .. "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
end
recursiveMultiSelectSubmenuOpeningControlUpdate = libUtil.recursiveMultiSelectSubmenuOpeningControlUpdate

function libUtil.subMenuArrowColor(control, data)
	if control.m_arrow == nil then return end
	local comboBox = control.m_owner
	local isMultiSelectionEnabled = (comboBox and comboBox.m_enableMultiSelect) or false -- todo 20250211 Replace with correct value m_enableMultiSelect from comboBox -> via control's m_dropdownObject e.g.?
	local isMultiSelectSubmenuEntrySelected = (isMultiSelectionEnabled == true and control.isAnySubmenuEntrySelected) or false

	local options = (comboBox and comboBox:GetOptions()) or nil
	local multiSelectSubmenuSelectedArrowColor = (isMultiSelectSubmenuEntrySelected == true and options ~= nil and getValueOrCallback(options.multiSelectSubmenuSelectedArrowColor, options)) or colorConstants.DEFAULT_ARROW_COLOR
	local submenuArrowColor = (not isMultiSelectSubmenuEntrySelected and options ~= nil and getValueOrCallback(options.submenuArrowColor, options)) or colorConstants.DEFAULT_ARROW_COLOR

	local newColor = ((isMultiSelectSubmenuEntrySelected == true and multiSelectSubmenuSelectedArrowColor) or (not isMultiSelectSubmenuEntrySelected and submenuArrowColor)) or colorConstants.DEFAULT_ARROW_COLOR
--d(debugPrefix .. "isMultiSelectSubmenuEntrySelected: " ..tos(isMultiSelectSubmenuEntrySelected) ..", arrowColor: " ..tos(newColor))
--[[
LSM_Debug = LSM_Debug or {}
LSM_Debug.subMenuArrowColor = { isMultiSelectSubmenuEntrySelected = isMultiSelectSubmenuEntrySelected, control = control, data = data, newColor = newColor,  }
]]
	if newColor ~= nil then
		control.m_arrow:SetColor(newColor:UnpackRGBA())
	end
end
--local subMenuArrowColor = libUtil.subMenuArrowColor

--Check if an entry got the isNew set
function libUtil.getIsNew(_entry, _comboBox)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 17) end
	return getValueOrCallback(_entry.isNew, _entry) or false
end

--The default callback for the recursiveOverEntries function
--[[
local function defaultRecursiveCallback(_entry, _comboBox)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 11) end
	return false
end
]]

function libUtil.validateEntryType(item)
	--Prefer passed in entryType (if any provided)
	local entryType = getValueOrCallback(item.entryType, item)

	--Check if any other entryType could be determined
	local isDivider = (((item.label ~= nil and item.label == libDivider) or item.name == libDivider) or (item.isDivider ~= nil and getValueOrCallback(item.isDivider, item))) or entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER == entryType
	local isHeader = (item.isHeader ~= nil and getValueOrCallback(item.isHeader, item)) or entryTypeConstants.LSM_ENTRY_TYPE_HEADER == entryType
	local isButton = (item.isButton ~= nil and getValueOrCallback(item.isButton, item)) or entryTypeConstants.LSM_ENTRY_TYPE_BUTTON == entryType
	local isRadioButton = (item.isRadioButton ~= nil and getValueOrCallback(item.isRadioButton, item)) or entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON == entryType
	local isCheckbox = (item.isCheckbox ~= nil and getValueOrCallback(item.isCheckbox, item)) or entryTypeConstants.LSM_ENTRY_TYPE_CHECKBOX == entryType
	local hasSubmenu = (item.entries ~= nil and getValueOrCallback(item.entries, item) ~= nil) or entryTypeConstants.LSM_ENTRY_TYPE_SUBMENU == entryType

	--If no entryType was passed in: Get the entryType by the before determined data
	if not entryType or entryType == entryTypeConstants.LSM_ENTRY_TYPE_NORMAL then
		entryType = hasSubmenu and entryTypeConstants.LSM_ENTRY_TYPE_SUBMENU or
					isDivider and entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER or
					isHeader and entryTypeConstants.LSM_ENTRY_TYPE_HEADER or
					isCheckbox and entryTypeConstants.LSM_ENTRY_TYPE_CHECKBOX or
					isButton and entryTypeConstants.LSM_ENTRY_TYPE_BUTTON or
					isRadioButton and entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON or
					entryTypeConstants.LSM_ENTRY_TYPE_NORMAL
	end

	--Update the item's variables
	item.isHeader = isHeader
	item.isButton = isButton
	item.isRadioButton = isRadioButton
	item.isDivider = isDivider
	item.isCheckbox = isCheckbox
	item.hasSubmenu = hasSubmenu

	--Set the entryType to the itm
	item.entryType = entryType
end

--Check for isDivider, isHeader, isCheckbox ... in table (e.g. item.additionalData) and get the LSM entry type for it
local function checkTablesKeyAndGetEntryType(dataTable, text)
	for key, entryType in pairs(additionalDataKeyToLSMEntryType) do
--d(">checkTablesKeyAndGetEntryType - text: " ..tos(text)..", key: " .. tos(key))
		if dataTable[key] ~= nil then
--d(">>found dataTable[key]")
			if getValueOrCallback(dataTable[key], dataTable) == true then
--d("<<<checkTablesKeyAndGetEntryType - text: " ..tos(text) ..", l_entryType: " .. tos(entryType) .. ", key: " .. tos(key))
				return entryType
			end
		end
	end
	return nil
end

function libUtil.checkEntryType(text, entryType, additionalData, isAddDataTypeTable, options)
--df(debugPrefix.."checkEntryType - text: %s, entryType: %s, additionalData: %s, isAddDataTypeTable: %s", tos(text), tos(entryType), tos(additionalData), tos(isAddDataTypeTable))
	if entryType == nil then
		isAddDataTypeTable = isAddDataTypeTable or false
		if isAddDataTypeTable == true then
			if additionalData == nil then isAddDataTypeTable = false
--d("<<<isAddDataTypeTable set to false")
			end
		end
		local l_entryType

		--Test was passed in?
		if text ~= nil then
--(">!!text check")
			--It should be a divider, according to the passed in text?
			if getValueOrCallback(text, ((isAddDataTypeTable and additionalData) or options)) == libDivider then
--d("<entry is divider, by text")
				return entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER
			end
		end

		--Additional data was passed in?
		if additionalData ~= nil and isAddDataTypeTable == true then
--d(">!!additionalData checks")
			if additionalData.entryType ~= nil then
--d(">>!!additionalData.entryType check")
				l_entryType = getValueOrCallback(additionalData.entryType, additionalData)
				if l_entryType ~= nil then
--d("<l_entryType by entryType: " ..tos(l_entryType))
					return l_entryType
				end
			end

			--Any isDivider, isHeader, isCheckbox, ...?
--d(">>!!checkTablesKeyAndGetEntryType additionalData")
			l_entryType = checkTablesKeyAndGetEntryType(additionalData, text)
			if l_entryType ~= nil then
--d("<l_entryType by checkTablesKeyAndGetEntryType: " ..tos(l_entryType))
				return l_entryType
			end

			local name = additionalData.name
			if name ~= nil then
--d(">>!!additionalData.name check")
				if getValueOrCallback(name, additionalData) == libDivider then
--d("<entry is divider, by name")
					return entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER
				end
			end
			local label = additionalData.label
			if name == nil and label ~= nil then
--d(">>!!additionalData.label check")
				if getValueOrCallback(label, additionalData) == libDivider then
--d("<entry is divider, by label")
					return entryTypeConstants.LSM_ENTRY_TYPE_DIVIDER
				end
			end
		end
	end
	return entryType
end

--Execute pre-stored callback functions of the data table, in data._LSM.funcData
function libUtil.updateDataByFunctions(data)
	data = getDataSource(data)

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 13, tos(data)) end
	--If subTable _LSM  (of row's data) contains funcData subTable: This contains the original functions passed in for
	--example "label" or "name" (instead of passing in strings). Loop the functions and execute those now for each found
	local lsmData = data[subTableConstants.LSM_DATA_SUBTABLE] or NIL_CHECK_TABLE
	local funcData = lsmData[subTableConstants.LSM_DATA_SUBTABLE_CALLBACK_FUNCTIONS] or NIL_CHECK_TABLE

	--Execute the callback functions for e.g. "name", "label", "checked", "enabled", ... now
	for _, updateFN in pairs(funcData) do
		updateFN(data)
	end
end


--------------------------------------------------------------------
-- Options functions
--------------------------------------------------------------------
--Get the options of the scrollable dropdownObject
function libUtil.getOptionsForDropdown(dropdown)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 21) end
	return dropdown.owner.options or {}
end
local getOptionsForDropdown = libUtil.getOptionsForDropdown


--Mix in table entries in other table and skip existing entries. Optionally run a callback function on each entry
--e.g. getValueOrCallback(...)
function libUtil.mixinTableAndSkipExisting(targetData, sourceData, doNotSkipTable, callbackFunc, ...)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 10, tos(callbackFunc)) end
	local useDoNotSkipTable = type(doNotSkipTable) == tableType and not ZO_IsTableEmpty(doNotSkipTable)
	local useCallback = type(callbackFunc) == functionType
--d(debugPrefix .. "mixinTableAndSkipExisting - useDoNotSkipTable: " .. tos(useDoNotSkipTable))
	for i = 1, select("#", sourceData) do
		local source = select(i, sourceData)
		for k, v in pairs(source) do
			--d(">k: " ..tos(k) .. ", v: " .. tos(v) .. ", target: " .. tos(targetData[k]))
			--Skip existing entries in target table, unless they should not be skipped (see doNotSkipTable)
			local doOverwrite = targetData[k] == nil
			local doNotSkipDataOfKey = (useDoNotSkipTable and type(doNotSkipTable[k]) == tableType and doNotSkipTable[k]) or nil

			if doOverwrite or doNotSkipDataOfKey ~= nil then
				local newValue = v

				if not doOverwrite and not useCallback and useDoNotSkipTable and doNotSkipDataOfKey ~= nil then
					local ifEqualsCondResult = getValueOrCallback(doNotSkipDataOfKey["ifEquals"])
					if targetData[k] == ifEqualsCondResult then
						newValue = getValueOrCallback(doNotSkipDataOfKey["changeTo"])
						doOverwrite = newValue ~= targetData[k]
					end
				end

				if doOverwrite then
					targetData[k] = (useCallback == true and callbackFunc(v, ...)) or newValue
					--d(">>target new: " .. tos(targetData[k]) .. ", doNotSkipTable[k]: " .. tos(doNotSkipTable[k]))
					--			else
					--d(">existing [" .. tos(k) .. "] = " .. tos(v))
				end
			end
		end
	end
end


--------------------------------------------------------------------
-- Delayed / queued calls
--------------------------------------------------------------------
function libUtil.throttledCall(callback, delay, throttledCallNameSuffix)
	delay = delay or throttledCallDelay
	throttledCallDelaySuffixCounter = throttledCallDelaySuffixCounter + 1
	throttledCallNameSuffix = throttledCallNameSuffix or tos(throttledCallDelaySuffixCounter)
	local throttledCallDelayTotalName = throttledCallDelayName .. throttledCallNameSuffix
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 4, tos(callback), tos(delay), tos(throttledCallDelayTotalName)) end
	EM:UnregisterForUpdate(throttledCallDelayTotalName)
	EM:RegisterForUpdate(throttledCallDelayTotalName, delay, function()
		EM:UnregisterForUpdate(throttledCallDelayTotalName)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 5, tos(callback), tos(throttledCallDelayTotalName)) end
		callback()
	end)
end
--local throttledCall = libUtil.throttledCall


--------------------------------------------------------------------
-- Context menu functions
--------------------------------------------------------------------
function libUtil.getContextMenuReference()
	g_contextMenu = g_contextMenu or lib.contextMenu
	return g_contextMenu
end
local getContextMenuReference = libUtil.getContextMenuReference

function libUtil.belongsToContextMenuCheck(ctrl)
	g_contextMenu = getContextMenuReference()
	contextMenuContainer = contextMenuContainer or g_contextMenu.m_container

	local dropdownObject = (ctrl ~= nil and ctrl.m_dropdownObject) or nil
	if dropdownObject then
		return contextMenuContainer == dropdownObject.m_container
	end
	return false
end
local libUtil_BelongsToContextMenuCheck = libUtil.belongsToContextMenuCheck

function libUtil.hideContextMenu()
	--d(debugPrefix .. "hideContextMenu")
	g_contextMenu = getContextMenuReference()
	if g_contextMenu == nil then return end

	if g_contextMenu:IsDropdownVisible() then
		g_contextMenu:HideDropdown()
	end
	g_contextMenu:ClearItems()
end
local hideContextMenu = libUtil.hideContextMenu

function libUtil.validateContextMenuSubmenuEntries(entries, options, calledByStr)
	--Passed in contextMenuEntries are a function -> Must return a table then
	local entryTableType = type(entries)
	if entryTableType == 'function' then
		g_contextMenu = getContextMenuReference()
		options = options or g_contextMenu:GetOptions()
		--Run the function -> Get the results table
		local entriesOfPassedInEntriesFunc = entries(options)
		--Check if the result is a table
		entryTableType = type(entriesOfPassedInEntriesFunc)
		assert(entryTableType == 'table', sfor('['..MAJOR.. ']'.. calledByStr ..' - table expected, got %q', tos(entryTableType)))
		entries = entriesOfPassedInEntriesFunc
	end
	return entries
end

--Check if a context menu was shown and a control not belonging to that context menu was clicked
--Returns boolean true if that was the case -> Prevent selection of entries or changes of radioButtons/checkboxes
--while a context menu was opened and one directly clicks on that other entry
function libUtil.checkIfContextMenuOpenedButOtherControlWasClicked(control, comboBox, buttonId)
--d(debugPrefix .. "checkIfContextMenuOpenedButOtherControlWasClicked")
	getContextMenuReference()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 29, tos(comboBox == g_contextMenu), tos(g_contextMenu:IsDropdownVisible())) end
	if comboBox ~= g_contextMenu and g_contextMenu:IsDropdownVisible() then
		if comboBox ~= nil then
--d(">!!!!ContextMenu - check if OPENED!!!!! comboBox: " ..tos(comboBox))
			return comboBox:HiddenForReasons(buttonId)
		end
	end
--d("<<combobox not hidden for reasons")
	return false
end


--------------------------------------------------------------------
-- Button group functions
--------------------------------------------------------------------
function libUtil.getButtonGroupOfEntryType(comboBox, groupIndex, entryType)
	local buttonGroupObject = comboBox.m_buttonGroup
	local buttonGroupOfEntryType = (buttonGroupObject ~= nil and buttonGroupObject[entryType] ~= nil and buttonGroupObject[entryType][groupIndex]) or nil
	return buttonGroupOfEntryType
end


--------------------------------------------------------------------
-- Tooltip functions
--------------------------------------------------------------------
local function resetCustomTooltipFuncVars()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 36) end
	lib.lastCustomTooltipFunction = nil
	lib.onHideCustomTooltipFunc = nil
end

--Hide the tooltip of a dropdown entry
function libUtil.hideTooltip(control)
--d(debugPrefix .. "hideTooltip - name: " .. tos(getControlName(control)))
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 37, tos(lib.onHideCustomTooltipFunc)) end
	if lib.onHideCustomTooltipFunc then
		lib.onHideCustomTooltipFunc()
	else
		ZO_Tooltips_HideTextTooltip()
	end
	resetCustomTooltipFuncVars()
end

local getTooltipAnchor
function libUtil.getTooltipAnchor(self, control, tooltipText, hasSubmenu)
	getTooltipAnchor = libUtil.getTooltipAnchor
	local relativeTo = control
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 38, tos(getControlName(control)), tos(tooltipText), tos(hasSubmenu)) end

	local submenu = self:GetSubmenu()
	if hasSubmenu then
		if submenu then
			if not submenu:IsDropdownVisible() then
				return getTooltipAnchor(self, control, tooltipText, hasSubmenu)
			end
			if submenu.m_dropdownObject then
				relativeTo = submenu.m_dropdownObject.control
			end
		end
	else
		if submenu and submenu:IsDropdownVisible() then
			submenu:HideDropdown()
		end
	end

	local point, offsetX, offsetY, relativePoint = BOTTOMLEFT, 0, 0, TOPRIGHT

	local anchorPoint = select(2, relativeTo:GetAnchor())
	local right = anchorPoint ~= 3
	if not right then
		local width, height = GuiRoot:GetDimensions()
		local fontObject = _G[fontConstants.DEFAULT_FONT]
		local nameWidth = (type(tooltipText) == stringType and GetStringWidthScaled(fontObject, tooltipText, 1, SPACE_INTERFACE)) or 250

		if control:GetRight() + nameWidth > width then
			right = true
		end
	end

	if right then
		if hasSubmenu then
			point, relativePoint = BOTTOMRIGHT, TOPRIGHT
		else
			point, relativePoint = RIGHT, LEFT
		end
	else
		if hasSubmenu then
			point, relativePoint = BOTTOMLEFT, TOPLEFT
		else
			point, relativePoint = LEFT, RIGHT
		end
	end
	-- In the order used in InitializeTooltip
	return relativeTo, point, offsetX, offsetY, relativePoint
end
getTooltipAnchor = libUtil.getTooltipAnchor


--Show the tooltip of a dropdown entry. First check for any custom tooltip function that handles the control show/hide
--and if none is provided use default InformationTooltip
--> For a custom tooltip example see line below:
--[[
--Custom tooltip function example
Function to show and hide a custom tooltip control. Pass that in to the data table of any entry, via data.customTooltip!
Your function needs to create and show/hide that control, and populate the text etc to the control too!
Parameters:
-control The control the tooltip blongs to
-doShow boolean to show if your mouse is inside the control and should show the tooltip. Must be false if tooltip should hide
-data The table with the current data of the rowControl
	-> To distinguish if the tooltip should be hidden or shown:	If 1st param data is missing the tooltip will be hidden! If data is provided the tooltip wil be shown
-rowControl The userdata of the control the tooltip should show about
-point, offsetX, offsetY, relativePoint: Suggested anchoring points

Example - Show an item tooltip of an inventory item
data.customTooltip = function(control, doShow, data, relativeTo, point, offsetX, offsetY, relativePoint)
	ClearTooltip(ItemTooltip)
	if doShow and data then
		InitializeTooltip(ItemTooltip, relativeTo, point, offsetX, offsetY, relativePoint)
		ItemTooltip:SetBagItem(data.bagId, data.slotIndex)
		ItemTooltipTopLevel:BringWindowToTop()
	end
end

Another example using a custom control of your addon to show the tooltip:
customTooltipFunc = function(control, doShow, data, rowControl, point, offsetX, offsetY, relativePoint)
	if not doShow or data == nil then
		myAddon.myTooltipControl:SetHidden(true)
	else
		myAddon.myTooltipControl:ClearAnchors()
		myAddon.myTooltipControl:SetAnchor(point, rowControl, relativePoint, offsetX, offsetY)
		myAddon.myTooltipControl:SetText(data.tooltip)
		myAddon.myTooltipControl:SetHidden(false)
	end
end
]]
function libUtil.showTooltip(self, control, data, hasSubmenu)
	resetCustomTooltipFuncVars()

	local tooltipData = getValueOrCallback(data.tooltip, data)
	local tooltipText = getValueOrCallback(tooltipData, data)
	local customTooltipFunc = data.customTooltip
	if type(customTooltipFunc) ~= functionType then customTooltipFunc = nil end

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 39, tos(getControlName(control)), tos(tooltipText), tos(hasSubmenu), tos(customTooltipFunc)) end

	--To prevent empty tooltips from opening.
	if tooltipText == nil and customTooltipFunc == nil then return end

	local relativeTo, point, offsetX, offsetY, relativePoint = getTooltipAnchor(self, control, tooltipText, hasSubmenu)

	--RelativeTo is a control?
	if type(relativeTo) == userdataType and type(relativeTo.IsControlHidden) == functionType then
		if customTooltipFunc ~= nil then
			lib.lastCustomTooltipFunction = customTooltipFunc

			local onHideCustomTooltipFunc = function()
				customTooltipFunc(control, false, nil) --Set 2nd param to false and leave 3rd param data empty so the calling func knows we are hiding
			end
			lib.onHideCustomTooltipFunc = onHideCustomTooltipFunc
			customTooltipFunc(control, true, data, relativeTo, point, offsetX, offsetY, relativePoint)
		else
			InitializeTooltip(InformationTooltip, relativeTo, point, offsetX, offsetY, relativePoint)
			SetTooltipText(InformationTooltip, tooltipText)
			InformationTooltipTopLevel:BringWindowToTop()
		end
	end
end


--------------------------------------------------------------------
-- Sound functions
--------------------------------------------------------------------
--(Un)Silence the OnClicked sound of a selected dropdown entry
function libUtil.silenceEntryClickedSound(doSilence, entryType)
--d(debugPrefix .. "libUtil.silenceEntryClickedSound - doSilence: " .. tos(doSilence) .. "; entryType: " .. tos(entryType))
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 20, tos(doSilence), tos(entryType)) end
	local soundNameForSilence = soundConstants.entryTypeToSilenceSoundName[entryType]
	if soundNameForSilence == nil then return end
	if doSilence == true then
		SOUNDS[soundNameForSilence] = soundConstants.soundClickedSilenced
--d(">sound is now: " .. tos(SOUNDS[soundNameForSilence]))
	else
		local origSound = soundConstants.entryTypeToOriginalSelectedSound[entryType]
		SOUNDS[soundNameForSilence] = origSound
	end
end
local silenceEntryClickedSound = libUtil.silenceEntryClickedSound

--Check if a sound should be played if a dropdown entry was selected
function libUtil.playSelectedSoundCheck(dropdown, entryType)
--d(debugPrefix .. "playSelectedSoundCheck - dropdown: " .. tos(dropdown) .. "; entryType: " .. tos(entryType))
	entryType = entryType or entryTypeConstants.LSM_ENTRY_TYPE_NORMAL
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 22, tos(entryType)) end

	silenceEntryClickedSound(false, entryType)

	local soundToPlay
	local soundToPlayOrig = soundConstants.entryTypeToOriginalSelectedSound[entryType]
	local options = getOptionsForDropdown(dropdown)

	if options ~= nil then
		--Chosen at options to play no selected sound?
		if getValueOrCallback(options.selectedSoundDisabled, options) == true then
--d(">selectedSoundDisabled -> true, soundToPlayOrig: " .. tos(soundToPlayOrig))
			silenceEntryClickedSound(true, entryType)
--d(">soundToPlayNow: " .. tos(soundToPlayOrig))
			return
		else
			--Custom selected sound passed in?
			soundToPlay = getValueOrCallback(options.selectedSound, options)
			--Use default selected sound
			if soundToPlay == nil then soundToPlay = soundToPlayOrig end
		end
	else
		soundToPlay = soundToPlayOrig
	end
--d(">>playing sound: " .. tos(soundToPlay))
	PlaySound(soundToPlay)
end

--------------------------------------------------------------------
-- Dropdown / combobox hidden checks
--------------------------------------------------------------------
--20250309 #2025_13 If the last comboBox_base:HiddenForReasons call closed an open contextMenu with multiSelect enabled, and we clicked on an LSM entry of another non-contextmenu
--to close it, then just exit here and do not select the clicked entry
function libUtil.checkNextOnEntryMouseUpShouldExecute()
--d(debugPrefix.."libUtil.checkNextOnEntryMouseUpShouldExecute - suppressNextOnEntryMouseUp:" ..tos(lib.preventerVars.suppressNextOnEntryMouseUp))
	if lib.preventerVars.suppressNextOnEntryMouseUp == true then
		--Was any special handling for the checkboxes/radiobuttons (clicked while an opened LSM contextMenu was on top of them) enabled. Disable the "skip" of next OnMouseUp so it not skipping it twice
		if lib.preventerVars.suppressNextOnEntryMouseUpDisableCounter ~= nil then
			lib.preventerVars.suppressNextOnEntryMouseUpDisableCounter = lib.preventerVars.suppressNextOnEntryMouseUpDisableCounter - 1
			if lib.preventerVars.suppressNextOnEntryMouseUpDisableCounter <= 0 then
				lib.preventerVars.suppressNextOnEntryMouseUpDisableCounter = 0
			end
			if lib.preventerVars.suppressNextOnEntryMouseUpDisableCounter == 0 then
--d("<°°°suppressNextOnEntryMouseUpDisableCounter reached 0 -> Returning false -> Not skipping next OnMouseUp! °°°")
				lib.preventerVars.suppressNextOnEntryMouseUp = nil
				return false
			end
		end
--d("<!!! OnMosueup on LSM entry suppressed !!!")
		lib.preventerVars.suppressNextOnEntryMouseUp = nil
		return true
	end
	return false
end

function libUtil.isAnyLSMDropdownVisible(contextMenuToo)
	if lib._objects == nil then return false end
	for _, lsmRef in ipairs(lib._objects) do
		if lsmRef ~= nil and lsmRef:IsDropdownVisible() then
			if not contextMenuToo or (contextMenuToo and lsmRef.isContextMenu) then
				return true
			end
		end
	end
	return false
end

--20240727 Prevent selection of entries if a context menu was opened and a left click was done "outside of the context menu"
--Param isContextMenu will be true if coming from contextMenuClass:GetHiddenForReasons function or it will change to true if
--any contextMenu is curently shown as this function runs
--Returns boolean true if the click should NOT affect the clicked control, and should only close the contextMenu
function libUtil.checkIfHiddenForReasons(selfVar, button, isContextMenu, owningWindow, mocCtrl, comboBox, entry, isSubmenu)
	g_contextMenu = getContextMenuReference()
	isContextMenu = isContextMenu or false

	local returnValue = false
	local clickedNoEntry = false

	--Check if context menu is currently shown
	local isContextMenuVisible = isContextMenu or g_contextMenu:IsDropdownVisible()
	if not isContextMenu and isContextMenuVisible == true then isContextMenu = true end

	local dropdownObject = selfVar.m_dropdownObject
	local contextMenuDropdownObject = g_contextMenu.m_dropdownObject
	local isOwnedByComboBox          = dropdownObject:IsOwnedByComboBox(comboBox)
	local isCntxtMenuOwnedByComboBox = contextMenuDropdownObject:IsOwnedByComboBox(comboBox)


	local doDebugNow = false --todo disable again after testing
	if doDebugNow then d(debugPrefix .. "[checkIfHiddenForReasons]isOwnedByCBox: " .. tos(isOwnedByComboBox) .. ", isCntxtMenVis: " .. tos(isContextMenuVisible) .. ", isCntxtMenOwnedByCBox: " ..tos(isCntxtMenuOwnedByComboBox) .. ", isSubmenu: " .. tos(selfVar.isSubmenu)) end

	if not isContextMenu then
		--No context menu currently shown
		if button == MOUSE_BUTTON_INDEX_LEFT then
			if isOwnedByComboBox == true then
				if not comboBox then
					if doDebugNow then d("<1not comboBox -> true") end
					returnValue = true
				else
					--Is the mocEntry an empty table (something else was clicked than a LSM entry)
					if ZO_IsTableEmpty(entry) then
						if doDebugNow then d("<1ZO_IsTableEmpty(entry) -> true") end
						returnValue = true
					else

						if mocCtrl then
							local owner = mocCtrl.m_owner
							if owner then
								if doDebugNow then d("1>>owner found") end
								--Does moc entry belong to a LSM menu and it IS the current comboBox?
								if owner == comboBox then
									if doDebugNow then d(">>1 - closeOnSelect: " ..tos(mocCtrl.closeOnSelect)) end
									returnValue = mocCtrl.closeOnSelect
								else
									if doDebugNow then d(">>1 - true") end
									--Does moc entry belong to a LSM menu but it's not the current comboBox?
									returnValue = true
								end
							end
						else
							if doDebugNow then d(">>1 - no mocCtrl") end
						end
					end
				end
			elseif isCntxtMenuOwnedByComboBox ~= nil then
				--20240807 Works for context menu clicks raised from a submenu but not if context menu go a submenu itsself....
				if doDebugNow then d(">isCntxtMenuOwnedByComboBox: " .. tos(isCntxtMenuOwnedByComboBox)) end
				return not isCntxtMenuOwnedByComboBox
			else
				returnValue = true
			end

		elseif button == MOUSE_BUTTON_INDEX_RIGHT then
			returnValue = true --close as a context menu might open
		end


	else
		--Context menu is currently shown
		if doDebugNow then d(">isContextMenu -> TRUE") end
		local doNotHideContextMenu = false
		local mocCtrlName

		if button == MOUSE_BUTTON_INDEX_LEFT then
			--Is there no LSM comboBox's control (entry, or header etc.) clicked? Close the context menu
			if not comboBox then
				if doDebugNow then d("<2 not comboBox -> true") end
				returnValue = true
				clickedNoEntry = true
			else
				--Is the mocEntry an empty table (something else was clicked than a LSM entry)
				if ZO_IsTableEmpty(entry) then
					if doDebugNow then d("<2 ZO_IsTableEmpty(entry) -> true; ctxtDropdown==mocCtrl.dropdown: " ..tos(contextMenuDropdownObject == mocCtrl.m_dropdownObject) .. "; owningWind==cntxMen: " ..tos(mocCtrl:GetOwningWindow() == g_contextMenu.m_dropdown)) end
					-- Was e.g. a context menu's submenu search header's editBox or the refresh button left clicked?
					if mocCtrl then
						--Did we click on GuiRoot -> Close the contextMenu
						if mocCtrl == GuiRoot then
							returnValue = true
							clickedNoEntry = true
						else
							--Clicked a context menu's search header e.g.
							if (contextMenuDropdownObject == mocCtrl.m_dropdownObject or (mocCtrl.GetOwningWindow and mocCtrl:GetOwningWindow() == g_contextMenu.m_dropdown)) then
								if doDebugNow then d(">>2 - submenu search header editBox or refresh button clicked") end
								returnValue = false
								doNotHideContextMenu = true
							else
								if doDebugNow then d(">!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
									LSM_Debug = LSM_Debug or {}
									LSM_Debug.checkIfHiddenForReasons = LSM_Debug.checkIfHiddenForReasons or {}

									getControlName = getControlName or libUtil.getControlName
									mocCtrlName = getControlName(mocCtrl)
									LSM_Debug.checkIfHiddenForReasons[mocCtrlName] = {
										mocCtrl = type(mocCtrl) == "table" and ZO_ShallowTableCopy(mocCtrl) or nil,
										closeOnSelect = mocCtrl.closeOnSelect,
										isCntxtMenOwnedByComboBox = isCntxtMenuOwnedByComboBox,
										enableMultiSelect = selfVar.m_enableMultiSelect,
									}
								end
								-- or was a checkbox's [ ] box control in a contextMenu's submenu clicked directly?
								if mocCtrl.m_owner == nil then
									local parent = mocCtrl:GetParent()
									mocCtrl = parent
									if doDebugNow then LSM_Debug.checkIfHiddenForReasons[mocCtrlName].parent = parent end
								end
								local owner = mocCtrl.m_owner
								if doDebugNow then
									d(">>2 - isSubmenu: " .. tos(isSubmenu) .. "/" .. tos(owner and owner.isSubmenu or nil) .. "; closeOnSelect: " .. tos(mocCtrl and mocCtrl.closeOnSelect or nil))
									if owner then
										LSM_Debug.checkIfHiddenForReasons[mocCtrlName].owner = owner
										LSM_Debug.checkIfHiddenForReasons[mocCtrlName].isSubmenu = isSubmenu or owner.isSubmenu
									end
								end
								if owner and (isSubmenu == true or owner.isSubmenu == true) and isCntxtMenuOwnedByComboBox == true then
									if doDebugNow then d(">>2 - clicked contextMenu entry, not moc.closeOnSelect: " .. tos(not mocCtrl.closeOnSelect) .. ", multiSelect: " .. tos(selfVar.m_enableMultiSelect) .. ", result: " .. tos(not mocCtrl.closeOnSelect or selfVar.m_enableMultiSelect)) end
									returnValue = not mocCtrl.closeOnSelect or selfVar.m_enableMultiSelect
								else
									if doDebugNow then d(">>2 owner and no submenu -> return true") end
									returnValue = true
								end
								if doDebugNow then
									LSM_Debug.checkIfHiddenForReasons[mocCtrlName].returnValue = returnValue
									d("<!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
								end
							end
						end
					else
						if doDebugNow then d(">>2 no mocCtrl -> return true") end
						returnValue = true
						clickedNoEntry = true
					end
				else

					if mocCtrl then
						if mocCtrl == GuiRoot then
							if doDebugNow then d(">>2_1GuiRoot!") end
							returnValue = true
							clickedNoEntry = true
						else
							local owner = mocCtrl.m_owner or mocCtrl:GetParent().m_owner
							if owner then
								if doDebugNow then d(">>2_1owner found") end
								--Does moc entry belong to a LSM menu and it IS the current contextMenu?
								if owner == g_contextMenu then --comboBox then
									if doDebugNow then d(">>2_1 - closeOnSelect: " ..tos(mocCtrl.closeOnSelect)) end
									returnValue = mocCtrl.closeOnSelect
								else
									if doDebugNow then d(">>2_1 - true: isSubmenu: " .. tos(isSubmenu) .. "/" .. tos(owner.isSubmenu) .. "; closeOnSelect: " .. tos(mocCtrl.closeOnSelect)) end
									--Does moc entry belong to a LSM menu but it's not the current contextMenu?
									--Is it a submenu entry of the context menu?
									if (isSubmenu == true or owner.isSubmenu == true) and isCntxtMenuOwnedByComboBox == true then
										if doDebugNow then d(">>>2_1 - clicked contextMenu entry, not moc.closeOnSelect: " .. tos(not mocCtrl.closeOnSelect)) end
										returnValue = not mocCtrl.closeOnSelect or selfVar.m_enableMultiSelect
									else
										if doDebugNow then d(">>>2_1 - true") end
										returnValue = true
									end
								end
							else
								if doDebugNow then d(">>2_1 - owner not found") end
								clickedNoEntry = true
							end
						end
					end
				end
			end

			--Do not hide the contextMenu if the mocCtrl clicked should keep the menu opened, or if multiselection is enabled (and one clicked a combobox entry)
			if not clickedNoEntry and ((mocCtrl and mocCtrl.closeOnSelect == false) or selfVar.m_enableMultiSelect) then
				doNotHideContextMenu = true
				if doDebugNow then d("1??? Setting suppressNextOnGlobalMouseUp = true ???") end
				lib.preventerVars.suppressNextOnGlobalMouseUp = true
				if doDebugNow then d(">suppressNextOnGlobalMouseUp: " ..tos(lib.preventerVars.suppressNextOnGlobalMouseUp)) end
				returnValue = false
			end

		elseif button == MOUSE_BUTTON_INDEX_RIGHT then
--d("-RIGHT MOUSE CLICK-")
			-- Was e.g. the search header's editBox right clicked?
			if mocCtrl and contextMenuDropdownObject == mocCtrl.m_dropdownObject then
				returnValue = false
				doNotHideContextMenu = true
--d("->header right clicked")
			else
				if mocCtrl and libUtil_BelongsToContextMenuCheck(mocCtrl) then
--d("->context menu belonging entry right clicked")
					returnValue = false
					doNotHideContextMenu = true
				else
--d("->other right clicked")
					returnValue = true --close context menu
				end
			end
		end

		--Reset the contextmenus' opened dropdown value so next check in comboBox_base:HiddenForReasons(button) will not show g_contextMenu:IsDropdownVisible() == true!
		if not doNotHideContextMenu then
			hideContextMenu()
		end
	end

	return returnValue
end


-- 2024-06-14 IsjustaGhost: oh crap. it may be returturning m_owner, which would be the submenu object
--> context menu's submenu directly closing on click on entry because comboBox passed in (which was determined via getComboBox) is not the correct one
--> -all submenus are g_contextMenu.m_submenu.m_dropdownObject.m_combobox = g_contextMenu.m_container.m_comboBox
--> -m_owner is personal. m_comboBox is singular to link all children to the owner
function libUtil.getComboBox(control, owningMenu)
	getComboBox = libUtil.getComboBox
	if control then
		--owningMenu boolean will be used to determine the m_comboBox (main menu) only and not the m_owner
		-->Needed for LSM context menus that do not open on any LSM control, but standalone!
		-->Checked in onMouseUp's callback function
		if owningMenu then
			if control.m_comboBox then
				return control.m_comboBox
			end
		else
			if control.m_owner then
				return control.m_owner
			elseif control.m_comboBox then
				return control.m_comboBox
			end
		end
	end

	if type(control) == 'userdata' then
		local owningWindow = control:GetOwningWindow()
		if owningWindow then
			if owningWindow.object and owningWindow.object ~= control then
				return getComboBox(owningWindow.object, owningMenu)
			end
		end
	end
end
getComboBox = libUtil.getComboBox

--Get the sorted items of a dropdown's comboBox (either from the current menu or the parent [openingControl] menu)
function libUtil.getComboBoxsSortedItems(comboBox, fromOpeningControl, onlyOpeningControl)
--d(debugPrefix .. "libUtil.getComboBoxsSortedItems - comboBox: " ..tos(comboBox) .. "; fromOpeningControl: " .. tos(fromOpeningControl) .. "; onlyOpeningControl: " .. tos(onlyOpeningControl))
	fromOpeningControl = fromOpeningControl or false
	onlyOpeningControl = onlyOpeningControl or false
	local sortedItems
	local isContextMenu = comboBox.isContextMenu
	local l_openingControl = comboBox.openingControl
	local ocCopy = l_openingControl

--[[
LSM_Debug = LSM_Debug or {}
LSM_Debug._getComboBoxsSortedItems = {
	isContextMenu = isContextMenu,
	comboBox = comboBox,
	openingControl = ocCopy,
}
]]

	if comboBox ~= nil then
		if fromOpeningControl == true then
			local openingControl = comboBox.openingControl
			if openingControl ~= nil then
				sortedItems = (openingControl.m_owner ~= nil and openingControl.m_owner.m_sortedItems) or nil
--d(">found sortedItems: " .. tos(sortedItems ~= nil and #sortedItems or nil))
			end
			if onlyOpeningControl then return sortedItems end
		end
--d(">comboBox.m_sortedItems: " .. tos(comboBox.m_sortedItems))
		return sortedItems or comboBox.m_sortedItems
	end
	return sortedItems
end
lib.getComboBoxsSortedItems = libUtil.getComboBoxsSortedItems


--------------------------------------------------------------------
-- Highlight & Animation
--------------------------------------------------------------------
--Similar function to /esoui/libraries/zo_templates/scrolltempaltes.lua, function PlayAnimationOnControl used for ZO_ScrollList
-->But here only for the contextmenu and submenu opening controls!
--Each other entryType: See call of "zo_comboBoxDropdown_onMouseEnterEntry" function and it's information about scrollCtrl.highlightTemplateOrFunction etc.
local function SubOrContextMenu_PlayAnimationOnControl(control, controlTemplate, animationFieldName, animateInstantly, overrideEndAlpha)
	if control and controlTemplate and animationFieldName then
		local animationCtrl = control[animationFieldName]
		if not animationCtrl then
			local highlight = CreateControlFromVirtual("$(parent)Scroll", control, controlTemplate, animationFieldName)
			animationCtrl = AM:CreateTimelineFromVirtual("ShowOnMouseOverLabelAnimation", highlight)

			local width = highlight:GetWidth()
			highlight:SetFadeGradient(1, (width / 3) , 0, width)
			--SetFadeGradient(gradientIndex, normalX, normalY, gradientLength)


			if overrideEndAlpha then
				animationCtrl:GetAnimation(1):SetAlphaValues(0, overrideEndAlpha)
			end

			control[animationFieldName] = animationCtrl
		end

		if animateInstantly then
			animationCtrl:PlayInstantlyToEnd()
		else
			animationCtrl:PlayForward()
		end
	end
end

local function removeAnimationOnControl(control, animationFieldName, animateInstantly)
	if control ~= nil then
		if animationFieldName ~= nil then
			local animationControl = control[animationFieldName]
			if animationControl then
				if animateInstantly then
					animationControl:PlayInstantlyToStart()
				else
					animationControl:PlayBackward()
				end
			end
		end
		control.breadcrumbName = nil
	end
end

function libUtil.unhighlightControl(selfVar, instantly, control, resetHighlightTemplate)
	local highlightControl = selfVar.highlightedControl
	if highlightControl then
		removeAnimationOnControl(highlightControl, highlightControl.breadcrumbName, instantly)
	end
	selfVar.highlightedControl = nil

	if control ~= nil and resetHighlightTemplate == true then
		if control.m_highlightTemplate then
			control.m_highlightTemplate = nil
		end

		local data = getControlData(control)
		if data then
			if data.m_highlightTemplate then
				data.m_highlightTemplate = nil
			end
		end
	end
end
local unhighlightControl = libUtil.unhighlightControl


--Should only be called from submenu or contextmenu's OnMouseEnter
-->Normal menus use the scrolltemplates.lua function HighlightControl via normal ZO_ScrolList. See function "highlightTemplateOrFunction"
function libUtil.SubOrContextMenu_highlightControl(selfVar, control)
	--d(debugPrefix .. "SubOrContextMenu_highlightControl: " .. tos(getControlName(control)))
	if selfVar.highlightedControl then
		unhighlightControl(selfVar, false, nil, nil)
	end

	--local isContextMenu = selfVar.isContextMenu or false

	--Get the highlight template from control.m_data.m_highlightTemplate of the submenu opening, or contextmenu opening control
	local highlightTemplate = selfVar:GetHighlightTemplate(control)

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 1, tos(highlightTemplate)) end
	if type(highlightTemplate) ~= stringType then return defaultHighlightData.defaultHighlightTemplate end

	--Use the breadcrumbName as animationFieldName (e.g. LSM_HighlightAnimation_SubmenuBreadcrumb or LSM_HighlightAnimation_ContextMenuBreadcrumb)
	control.breadcrumbName = sfor(defaultHighlightData.subAndContextMenuHighlightAnimationBreadcrumbsPattern, defaultHighlightData.defaultHighLightAnimationFieldName, tos(selfVar.breadcrumbName))
	SubOrContextMenu_PlayAnimationOnControl(control, highlightTemplate, control.breadcrumbName, false, 0.5)
	selfVar.highlightedControl = control
end


--------------------------------------------------------------------
-- Screen / UI helper functions
--------------------------------------------------------------------
function libUtil.getScreensMaxDropdownHeight()
	return GuiRoot:GetHeight() - 100
end