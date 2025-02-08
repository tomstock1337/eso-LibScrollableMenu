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
local SNM = SCREEN_NARRATION_MANAGER
local tos = tostring
local sfor = string.format
local zostrlow = zo_strlower
local tins = table.insert
local trem = table.remove

-----------------------------------------------------------------------
-- Library utility
--------------------------------------------------------------------
local constants = lib.contants
local fontConstants = constants.fonts
local entryTypeConstants = constants.entryTypes
local comboBoxConstants = constants.comboBox
local soundConstants = constants.sounds
local handlerNameConstants = constants.handlerNames
local comboBoxMappingConstants = comboBoxConstants.mapping
local comboBoxDefaults = comboBoxConstants.defaults

local libUtil = lib.Util


-----------------------------------------------------------------------
-- Library local utility variables
--------------------------------------------------------------------
local libDivider = lib.DIVIDER

local NIL_CHECK_TABLE = constants.NIL_CHECK_TABLE


--Throttled calls
local throttledCallDelaySuffixCounter = 0
local throttledCallDelayName = handlerNameConstants.throttledCallDelayName
local throttledCallDelay = constants.throttledCallDelay

--Context menus
local g_contextMenu
local getValueOrCallback
local getControlName
local recursiveOverEntries


--------------------------------------------------------------------
-- Determine value or function returned value
--------------------------------------------------------------------
--Run function arg to get the return value (passing in ... as optional params to that function),
--or directly use non-function return value arg
function libUtil.getValueOrCallback(arg, ...)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 6, tos(arg)) end
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end
getValueOrCallback = libUtil.getValueOrCallback


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
--local getControlData = libUtil.getControlData


--------------------------------------------------------------------
-- Entry functions
--------------------------------------------------------------------
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