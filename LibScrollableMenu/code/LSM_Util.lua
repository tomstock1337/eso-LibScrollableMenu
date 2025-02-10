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

local suppressNextOnGlobalMouseUp = lib.suppressNextOnGlobalMouseUp
local additionalDataKeyToLSMEntryType = entryTypeConstants.additionalDataKeyToLSMEntryType

--local sv



--Throttled calls
local throttledCallDelaySuffixCounter = 0
local throttledCallDelayName = handlerNameConstants.throttledCallDelayName
local throttledCallDelay = constants.throttledCallDelay

--Context menus
local g_contextMenu
local getValueOrCallback = libUtil.getValueOrCallback
local getControlName
local getControlData
local recursiveOverEntries
local getComboBox


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
		if type(svOptionData) ~= "table" then return end
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
		if type(svOptionData) ~= "table" then return end
		return lib.SV[svOptionName][subTableName]
	else
		return lib.SV[svOptionName]
	end
end


--------------------------------------------------------------------
-- Data & data source determination
--------------------------------------------------------------------
function libUtil.getDataSource(data)
	if data and data.dataSource then
		return data:GetDataSource()
	end
	return data or NIL_CHECK_TABLE
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
function libUtil.subMenuArrowColor(control, color)
	if control.m_arrow == nil then return end
	control.m_arrow:SetColor(color or colorConstants.DEFAULT_ARROW_COLOR)
end
local subMenuArrowColor = libUtil.subMenuArrowColor


function libUtil.checkIfSubmenuArrowColorNeedsChange(_entry)
	--todo 20260211
end

--Check if an entry got the isNew set
function libUtil.getIsNew(_entry)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 17) end
	return getValueOrCallback(_entry.isNew, _entry) or false
end

--The default callback for the recursiveOverEntries function
local function defaultRecursiveCallback()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 11) end
	return false
end

-- Recursively loop over drdopdown entries, and submenu dropdown entries of that parent dropdown, and check if e.g. isNew needs to be updated
-- Used for the search of the collapsible header too
function libUtil.recursiveOverEntries(entry, callback)
	recursiveOverEntries = libUtil.recursiveOverEntries
	callback = callback or defaultRecursiveCallback

	local result = callback(entry)
	local submenu = (entry.entries ~= nil and getValueOrCallback(entry.entries, entry)) or {}

	--local submenuType = type(submenu)
	--assert(submenuType == 'table', sfor('["..MAJOR..':recursiveOverEntries] table expected, got %q = %s', "submenu", tos(submenuType)))
	if type(submenu) == "table" and #submenu > 0 then
		for _, subEntry in pairs(submenu) do
			local subEntryResult = recursiveOverEntries(subEntry, callback)
			if subEntryResult then
				result = subEntryResult
			end
		end
	end
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 19, tos(#submenu), tos(result)) end
	return result
end
recursiveOverEntries = libUtil.recursiveOverEntries

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
	local useDoNotSkipTable = type(doNotSkipTable) == "table" and not ZO_IsTableEmpty(doNotSkipTable)
	local useCallback = type(callbackFunc) == "function"
--d(debugPrefix .. "mixinTableAndSkipExisting - useDoNotSkipTable: " .. tos(useDoNotSkipTable))
	for i = 1, select("#", sourceData) do
		local source = select(i, sourceData)
		for k, v in pairs(source) do
			--d(">k: " ..tos(k) .. ", v: " .. tos(v) .. ", target: " .. tos(targetData[k]))
			--Skip existing entries in target table, unless they should not be skipped (see doNotSkipTable)
			local doOverwrite = targetData[k] == nil
			local doNotSkipDataOfKey = (useDoNotSkipTable and type(doNotSkipTable[k]) == "table" and doNotSkipTable[k]) or nil

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
	getContextMenuReference()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 29, tos(comboBox == g_contextMenu), tos(g_contextMenu:IsDropdownVisible())) end
	if comboBox ~= g_contextMenu and g_contextMenu:IsDropdownVisible() then
--d("!!!!ContextMenu - check if OPENED!!!!! comboBox: " ..tos(comboBox))
		if comboBox ~= nil then
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
		if submenu and not submenu:IsDropdownVisible() then
			return getTooltipAnchor(self, control, tooltipText, hasSubmenu)
		end
		relativeTo = submenu.m_dropdownObject.control
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
		local nameWidth = (type(tooltipText) == "string" and GetStringWidthScaled(fontObject, tooltipText, 1, SPACE_INTERFACE)) or 250

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
	if type(customTooltipFunc) ~= "function" then customTooltipFunc = nil end

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 39, tos(getControlName(control)), tos(tooltipText), tos(hasSubmenu), tos(customTooltipFunc)) end

	--To prevent empty tooltips from opening.
	if tooltipText == nil and customTooltipFunc == nil then return end

	local relativeTo, point, offsetX, offsetY, relativePoint = getTooltipAnchor(self, control, tooltipText, hasSubmenu)

	--RelativeTo is a control?
	if type(relativeTo) == "userdata" and type(relativeTo.IsControlHidden) == "function" then
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
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 20, tos(doSilence), tos(entryType)) end
	local soundNameForSilence = soundConstants.entryTypeToSilenceSoundName[entryType]
	if soundNameForSilence == nil then return end
	if doSilence == true then
		SOUNDS[soundNameForSilence] = soundConstants.soundClickedSilenced
	else
		local origSound = soundConstants.entryTypeToOriginalSelectedSound[entryType]
		SOUNDS[soundNameForSilence] = origSound
	end
end
local silenceEntryClickedSound = libUtil.silenceEntryClickedSound

--Check if a sound should be played if a dropdown entry was selected
function libUtil.playSelectedSoundCheck(dropdown, entryType)
	entryType = entryType or entryTypeConstants.LSM_ENTRY_TYPE_NORMAL
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 22, tos(entryType)) end

	silenceEntryClickedSound(false, entryType)

	local soundToPlay
	local soundToPlayOrig = soundConstants.entryTypeToOriginalSelectedSound[entryType]
	local options = getOptionsForDropdown(dropdown)

	if options ~= nil then
		--Chosen at options to play no selected sound?
		if getValueOrCallback(options.selectedSoundDisabled, options) == true then
			silenceEntryClickedSound(true, entryType)
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
	PlaySound(soundToPlay)
end


--------------------------------------------------------------------
-- Dropdown / combobox hidden checks
--------------------------------------------------------------------
--20240727 Prevent selection of entries if a context menu was opened and a left click was done "outside of the context menu"
--Param isContextMenu will be true if coming from contextMenuClass:GetHiddenForReasons function or it will change to true if
--any contextMenu is curently shown as this function runs
--Returns boolean true if the click should NOT affect the clicked control, and should only close the contextMenu
function libUtil.checkIfHiddenForReasons(selfVar, button, isContextMenu, owningWindow, mocCtrl, comboBox, entry, isSubmenu)
	g_contextMenu = getContextMenuReference()
	isContextMenu = isContextMenu or false

	local returnValue = false

	--Check if context menu is currently shown
	local isContextMenuVisible = isContextMenu or g_contextMenu:IsDropdownVisible()
	if not isContextMenu and isContextMenuVisible == true then isContextMenu = true end

	local dropdownObject = selfVar.m_dropdownObject
	local contextMenuDropdownObject = g_contextMenu.m_dropdownObject
	local isOwnedByComboBox = dropdownObject:IsOwnedByComboBox(comboBox)
	local isCntxtMenOwnedByComboBox = contextMenuDropdownObject:IsOwnedByComboBox(comboBox)
--d("[checkIfHiddenForReasons]isOwnedByCBox: " .. tos(isOwnedByComboBox) .. ", isCntxtMenVis: " .. tos(isContextMenuVisible) .. ", isCntxtMenOwnedByCBox: " ..tos(isCntxtMenOwnedByComboBox) .. ", isSubmenu: " .. tos(selfVar.isSubmenu))


	if not isContextMenu then
		--No context menu currently shown
		if button == MOUSE_BUTTON_INDEX_LEFT then
			--todo 2024-08-07 Submenu -> Context menu -> Click on entry at the submenu (but outside the context menu) closes aLL menus -> why? It must only close the contextMenu then
			if isOwnedByComboBox == true then
				if not comboBox then
					--d("<1not comboBox -> true")
					returnValue = true
				else
					--Is the mocEntry an empty table (something else was clicked than a LSM entry)
					if ZO_IsTableEmpty(entry) then
						--d("<1ZO_IsTableEmpty(entry) -> true")
						returnValue = true
					else

						if mocCtrl then
							local owner = mocCtrl.m_owner
							if owner then
								--d("1>>owner found")
								--Does moc entry belong to a LSM menu and it IS the current comboBox?
								if owner == comboBox then
									--d(">>1 - closeOnSelect: " ..tos(mocCtrl.closeOnSelect))
									returnValue = mocCtrl.closeOnSelect
								else
									--d(">>1 - true")
									--Does moc entry belong to a LSM menu but it's not the current comboBox?
									returnValue = true
								end
							end
						else
							--d(">>1 - no mocCtrl")
						end
					end
				end
			elseif isCntxtMenOwnedByComboBox ~= nil then
				--20240807 Works for context menu clicks rasied from a subenu but not if context menu go a submenu itsself....
				return not isCntxtMenOwnedByComboBox
			else
				returnValue = true
			end

		elseif button == MOUSE_BUTTON_INDEX_RIGHT then
			returnValue = true --close as a context menu might open
		end

	else
		local doNotHideContextMenu = false
		--Context menu is currently shown
		if button == MOUSE_BUTTON_INDEX_LEFT then
			--Is there no LSM comboBox available? Close the context menu
			if not comboBox then
				--d("<2not comboBox -> true")
				returnValue = true
			else
				--Is the mocEntry an empty table (something else was clicked than a LSM entry)
				if ZO_IsTableEmpty(entry) then
					--d("<2ZO_IsTableEmpty(entry) -> true; ctxtDropdown==mocCtrl.dropdown: " ..tos(contextMenuDropdownObject == mocCtrl.m_dropdownObject) .. "; owningWind==cntxMen: " ..tos(mocCtrl:GetOwningWindow() == g_contextMenu.m_dropdown))
					-- Was e.g. a context menu's submenu search header's editBox or the refresh button left clicked?
					if mocCtrl then
						if (contextMenuDropdownObject == mocCtrl.m_dropdownObject or (mocCtrl.GetOwningWindow and mocCtrl:GetOwningWindow() == g_contextMenu.m_dropdown)) then
--d(">>2 - submenu search header editBox or refresh button clicked")
							returnValue = false
							doNotHideContextMenu = true
						else
							-- or was a checkbox's [ ] box control in a contextMenu's submenu clicked directly?
							if mocCtrl.m_owner == nil then
								local parent = mocCtrl:GetParent()
								mocCtrl = parent
							end
							local owner = mocCtrl.m_owner
--d(">>2 - isSubmenu: " .. tos(isSubmenu) .. "/" .. tos(owner.isSubmenu) .. "; closeOnSelect: " .. tos(mocCtrl.closeOnSelect))
							if owner and (isSubmenu == true or owner.isSubmenu == true) and isCntxtMenOwnedByComboBox == true then
--d(">>2 - clicked contextMenu entry, not moc.closeOnSelect: " .. tos(not mocCtrl.closeOnSelect))
								returnValue = not mocCtrl.closeOnSelect
							else
								returnValue = true
							end
						end
					else
						returnValue = true
					end
				else

					if mocCtrl then
						local owner = mocCtrl.m_owner or mocCtrl:GetParent().m_owner
						if owner then
							--d(">>2_1owner found")
							--Does moc entry belong to a LSM menu and it IS the current contextMenu?
							if owner == g_contextMenu then --comboBox then
								--d(">>2_1 - closeOnSelect: " ..tos(mocCtrl.closeOnSelect))
								returnValue = mocCtrl.closeOnSelect
							else
								--d(">>2_1 - true: isSubmenu: " .. tos(isSubmenu) .. "/" .. tos(owner.isSubmenu) .. "; closeOnSelect: " .. tos(mocCtrl.closeOnSelect))
								--Does moc entry belong to a LSM menu but it's not the current contextMenu?
								--Is it a submenu entry of the context menu?
								if (isSubmenu == true or owner.isSubmenu == true) and isCntxtMenOwnedByComboBox == true then
									--d(">>>2_1 - clicked contextMenu entry, not moc.closeOnSelect: " .. tos(not mocCtrl.closeOnSelect))
									returnValue = not mocCtrl.closeOnSelect
								else
									--d(">>>2_1 - true")
									returnValue = true
								end
							end
						else
							--d(">>2_1 - owner not found")
						end
					end
				end
			end
			--Do not hide the contextMenu if the mocCtrl clicked should keep the menu opened
			if mocCtrl and mocCtrl.closeOnSelect == false then
				doNotHideContextMenu = true
				suppressNextOnGlobalMouseUp = true
--d(">suppressNextOnGlobalMouseUp: " ..tos(suppressNextOnGlobalMouseUp))
				returnValue = false
			end

		elseif button == MOUSE_BUTTON_INDEX_RIGHT then
			-- Was e.g. the search header's editBox left clicked?
			if mocCtrl and contextMenuDropdownObject == mocCtrl.m_dropdownObject then
				returnValue = false
				doNotHideContextMenu = true
			else
				returnValue = true --close context menu
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

function libUtil.getComboBoxsSortedItems(comboBox, fromOpeningControl, onlyOpeningControl)
	fromOpeningControl = fromOpeningControl or false
	onlyOpeningControl = onlyOpeningControl or false
	local sortedItems
	if fromOpeningControl == true then
		local openingControl = comboBox.openingControl
		if openingControl ~= nil then
			sortedItems = openingControl.m_owner ~= nil and openingControl.m_owner.m_sortedItems
		end
		if onlyOpeningControl then return sortedItems end
	end
	return sortedItems or comboBox.m_sortedItems
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
	if type(highlightTemplate) ~= "string" then return defaultHighlightData.defaultHighlightTemplate end

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

