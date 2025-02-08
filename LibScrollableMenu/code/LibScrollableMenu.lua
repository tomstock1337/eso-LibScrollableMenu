local lib = LibScrollableMenu
if not lib then return end

local MAJOR = lib.name


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


--------------------------------------------------------------------
-- LSM library locals
--------------------------------------------------------------------
local constants = lib.contants
local entryTypeConstants = constants.entryTypes
local comboBoxConstants = constants.comboBox
local comboBoxMappingConstants = comboBoxConstants.mapping
local comboBoxDefaults = comboBoxConstants.defaults

local additionalDataKeyToLSMEntryType = entryTypeConstants.additionalDataKeyToLSMEntryType


local libDivider = lib.DIVIDER

local libUtil = lib.Util
local getControlName = libUtil.getControlName
local getControlData = libUtil.getControlData
local getValueOrCallback = libUtil.getValueOrCallback
local getContextMenuReference = libUtil.getContextMenuReference

local getDataSource


--------------------------------------------------------------------
-- For debugging and logging
--------------------------------------------------------------------
--Logging and debugging
local libDebug = lib.Debug
local debugPrefix = libDebug.prefix

local dlog = libDebug.DebugLog


--------------------------------------------------------------------
--SavedVariables
--------------------------------------------------------------------
local svConstants = lib.SVConstans
local sv = lib.SV








--------------------------------------------------------------------
-- XML template functions
--------------------------------------------------------------------



--------------------------------------------------------------------
-- Screen / UI helper functions
--------------------------------------------------------------------
local function getScreensMaxDropdownHeight()
	return GuiRoot:GetHeight() - 100
end


--------------------------------------------------------------------
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
lib.headerControls = { 
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
local headerControls = lib.headerControls

local refreshDropdownHeader
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
		[TOGGLE_BUTTON]		= { Anchor:New(BOTTOMRIGHT, PARENT, BOTTOMRIGHT, -ROW_OFFSET_Y, 0) },
		--Show a control left of the toggle button: We can click this to expand the header again, and after that the control resizes to 0pixels and hides
		[TOGGLE_BUTTON_CLICK_EXTENSION]	= { Anchor:New(BOTTOMRIGHT, TOGGLE_BUTTON, BOTTOMLEFT, 0, 0),
							    	Anchor:New(BOTTOMLEFT, PARENT, BOTTOMLEFT, -ROW_OFFSET_Y, 0) },
		[DIVIDER_SIMPLE]	= { Anchor:New(TOPLEFT, nil, BOTTOMLEFT, 0, ROW_OFFSET_Y),
								Anchor:New(TOPRIGHT, nil, BOTTOMRIGHT, 0, 0) }, -- ZO_GAMEPAD_CONTENT_TITLE_DIVIDER_PADDING_Y
								
		[DEFAULT_ANCHOR]	= { Anchor:New(TOPLEFT, nil, BOTTOMLEFT, 0, 0),
								Anchor:New(TOPRIGHT, nil, BOTTOMRIGHT, 0, 0) },
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

		if dataType == "function" then
			data = data(control)
		end

		if dataType == "string" or dataType == "number" then
			control:SetText(data)
		end

		if dataType == "boolean" then
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
		control:SetHidden(dataType ~= "userdata")
		if dataType == "userdata" then
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
		header_setFont(controls[TITLE], getValueOrCallback(options.titleFont, options), HeaderFontTitle)

		refreshResults[SUBTITLE] = header_processData(controls[SUBTITLE], getValueOrCallback(options.subtitleText, options), collapsed)
		header_setFont(controls[SUBTITLE], getValueOrCallback(options.subtitleFont, options), HeaderFontSubtitle)

		header_setAlignment(controls[TITLE], getValueOrCallback(options.titleTextAlignment, options), TEXT_ALIGN_CENTER)
		header_setAlignment(controls[SUBTITLE], getValueOrCallback(options.titleTextAlignment, options), TEXT_ALIGN_CENTER)

		-- Others
		local isFilterEnabled = comboBox:IsFilterEnabled()
		refreshResults[FILTER_CONTAINER] = header_processData(controls[FILTER_CONTAINER], isFilterEnabled, collapsed)
		refreshResults[CUSTOM_CONTROL] = header_processControl(controls[CUSTOM_CONTROL], getValueOrCallback(options.customHeaderControl, options), collapsed)
		refreshResults[TOGGLE_BUTTON] = header_processData(controls[TOGGLE_BUTTON], getValueOrCallback(options.headerCollapsible, options))
		refreshResults[TOGGLE_BUTTON_CLICK_EXTENSION] = header_processData(controls[TOGGLE_BUTTON_CLICK_EXTENSION], getValueOrCallback(options.headerCollapsible, options))

		headerControl:SetDimensionConstraints(MIN_WIDTH_WITHOUT_SEARCH_HEADER, 0)
		header_updateAnchors(headerControl, refreshResults, collapsed, isFilterEnabled)
	end
end

--------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------


--Control types which should save the parentName to the SV (for the header's toggleState) instead of each children
--e.g. ZO_ScrollLists
local headerToggleControlTypesSaveTheParent = {
	[CT_SCROLL] = true
}
local function getHeaderToggleStateControlSavedVariableName(selfVar)
	local openingControlOrComboBoxName = selfVar:GetUniqueName()
	if openingControlOrComboBoxName then
		local openingControlOrComboBoxCtrl = _G[openingControlOrComboBoxName]
		local parentCtrl = openingControlOrComboBoxCtrl:GetParent()
		--Parent control is a scrollList -> then save the parent as SV entry name, and not each single row of the scrollList
		if parentCtrl and parentCtrl.GetType and headerToggleControlTypesSaveTheParent[parentCtrl:GetType()] then
--d(">parentName: " ..tos(getControlName(parentCtrl)))
			return getControlName(parentCtrl)
		end
	end
--d(">openingControlOrComboBoxName: " ..tos(openingControlOrComboBoxName))
	return openingControlOrComboBoxName
end






--Called from ZO_Menu's ShowMenu, if preventing the call via lib.preventLSMClosingZO_Menu == true is not enabled
--and called if the SCENE_MANAGER shows a scene
local function hideCurrentlyOpenedLSMAndContextMenu()
	local openMenu = lib.openMenu
	if openMenu and openMenu:IsDropdownVisible() then
		ClearCustomScrollableMenu()
		openMenu:HideDropdown()
	end
end





--------------------------------------------------------------------
-- Local entry/item data functions
--------------------------------------------------------------------


--20240727 Prevent selection of entries if a context menu was opened and a left click was done "outside of the context menu"
--Param isContextMenu will be true if coming from contextMenuClass:GetHiddenForReasons function or it will change to true if
--any contextMenu is curently shown as this function runs
--Returns boolean true if the click should NOT affect the clicked control, and should only close the contextMenu
local function checkIfHiddenForReasons(selfVar, button, isContextMenu, owningWindow, mocCtrl, comboBox, entry, isSubmenu)
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



-- Recursively check for new entries.
-->Done within preUpdateSubItems func now
--[[
local function areAnyEntriesNew(entry)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 30) end
	return recursiveOverEntries(entry, getIsNew, true)
end
]]







--------------------------------------------------------------------
-- Local tooltip functions
--------------------------------------------------------------------











--Recursivley map the entries of a submenu and add them to the mapTable
--used for the callback "NewStatusUpdated" to provide the mapTable with the entries
local function doMapEntries(entryTable, mapTable, entryTableType)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 23) end
	if entryTableType == nil then
		-- If getValueOrCallback returns nil then return {}
		entryTable = getValueOrCallback(entryTable) or {}
	end

	for _, entry in pairs(entryTable) do
		if entry.entries then
			doMapEntries(entry.entries, mapTable)
		end

		if entry.callback then
			mapTable[entry] = entry
		end
	end
end

-- This function will create a map of all entries recursively. Useful when there are submenu entries
-- and you want to use them for comparing in the callbacks, NewStatusUpdated, CheckboxUpdated, RadioButtonUpdated
local function mapEntries(entryTable, mapTable, blank)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 24) end

	if blank ~= nil then
		entryTable = mapTable
		mapTable = blank
		blank = nil
	end

	local entryTableType, mapTableType = type(entryTable), type(mapTable)
	local entryTableToMap = entryTable
	if entryTableType == "function" then
		entryTableToMap = getValueOrCallback(entryTable)
		entryTableType = type(entryTableToMap)
	end

	assert(entryTableType == 'table' and mapTableType == 'table' , sfor("["..MAJOR..":MapEntries] tables expected, got %q = %s, %q = %s", "entryTable", tos(entryTableType), "mapTable", tos(mapTableType)))

	-- Splitting these up so the above is not done each iteration
	doMapEntries(entryTableToMap, mapTable, entryTableType)
end
lib.MapEntries = mapEntries


------------------------------------------------------------------------------------------------------------------------
-- API functions for custom scrollable inventory context menu (ZO_Menu / LibCustomMenu support)
------------------------------------------------------------------------------------------------------------------------
--> See ZO_Menu2LSM_Mapping.lua


------------------------------------------------------------------------------------------------------------------------
-- XML handler functions
------------------------------------------------------------------------------------------------------------------------

--Called from XML at e.g. the collapsible header's editbox, and other controls
--Used for event handlers like OnMouseUp and OnChanged etc.
function lib.OnXMLControlEventHandler(owningWindowFunctionName, refVar, ...)
	--d(debugPrefix .. "lib.OnXMLControlEventHandler - owningWindowFunctionName: " .. tos(owningWindowFunctionName))

	if refVar == nil or owningWindowFunctionName == nil then return end

	local owningWindow = refVar:GetOwningWindow()
	local owningWindowObject = (owningWindow ~= nil and owningWindow.object) or nil
	if owningWindowObject ~= nil then
		local owningFunctionNameType = type(owningWindowFunctionName)
		if owningFunctionNameType == "string" and type(owningWindowObject[owningWindowFunctionName]) == "function"  then
			owningWindowObject[owningWindowFunctionName](owningWindowObject, ...)
		elseif owningFunctionNameType == "function" then
			owningWindowFunctionName(owningWindowObject, ...)
		end
	end
end


--XML OnClick handler for checkbox and radiobuttons
function lib.XMLButtonOnInitialize(control, entryType)
	--Which XML button control's handler was used, checkbox or radiobutton?
	local isCheckbox = entryType == entryTypeConstants.LSM_ENTRY_TYPE_CHECKBOX
	local isRadioButton = not isCheckbox and entryType == entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON

	control:GetParent():SetHandler('OnMouseUp', function(parent, buttonId, upInside, ...)
--d(debugPrefix .. "OnMouseUp of parent-upInside: " ..tos(upInside) .. ", buttonId: " .. tos(buttonId))
		if upInside then
			if checkIfContextMenuOpenedButOtherControlWasClicked(control, parent.m_owner, buttonId) == true then return end
			if buttonId == MOUSE_BUTTON_INDEX_LEFT then
				local data = getControlData(parent)
				playSelectedSoundCheck(parent.m_dropdownObject, data.entryType)

				local onClickedHandler = control:GetHandler('OnClicked')
				if onClickedHandler then
					onClickedHandler(control, buttonId)
				end

			elseif buttonId == MOUSE_BUTTON_INDEX_RIGHT then
				local owner = parent.m_owner
				local data = getControlData(parent)
				local rightClickCallback = data.contextMenuCallback or data.rightClickCallback
				if rightClickCallback and not g_contextMenu.m_dropdownObject:IsOwnedByComboBox(owner) then
					if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 173) end
					rightClickCallback(owner, parent, data)
				end
			end
		end
	end)

	if not isRadioButton then
		local originalClicked = control:GetHandler('OnClicked')
		control:SetHandler('OnClicked', function(p_control, buttonId, ignoreCallback, skipHiddenForReasonsCheck, ...)
			skipHiddenForReasonsCheck = skipHiddenForReasonsCheck or false
			if not skipHiddenForReasonsCheck then
				local parent = p_control:GetParent()
				local comboBox = parent.m_owner
				if checkIfContextMenuOpenedButOtherControlWasClicked(p_control, comboBox, buttonId) == true then return end
			end

			if originalClicked then
				originalClicked(p_control, buttonId, ignoreCallback, ...)
			end
			p_control.checked = nil
		end)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------

--Load of the addon/library starts
local function onAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)

	--Debug logging
	libDebug.LoadLogger()
	libDebug = lib.Debug
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 174) end

	--SavedVariables
	lib.SV = ZO_SavedVars:NewAccountWide(svConstants.name, svConstants.version, svConstants.profile, svConstants.defaults)
	sv = lib.SV

	--Create the ZO_ComboBox and the g_contextMenu object (lib.contextMenu) for the LSM contextmenus
	lib.CreateContextMenuObject()


	--------------------------------------------------------------------------------------------------------------------
	--Hooks & ZOs code changes
	--------------------------------------------------------------------------------------------------------------------
	--Register a scene manager callback for the SetInUIMode function so any menu opened/closed closes the context menus of LSM too
	SecurePostHook(SCENE_MANAGER, 'SetInUIMode', function(self, inUIMode, bypassHideSceneConfirmationReason)
		if not inUIMode then
			ClearCustomScrollableMenu()
		end
	end)

	--Register a scene manager callback for the Show function so any menu opened/closed closes the context menus of LSM too
	SecurePostHook(SCENE_MANAGER, 'Show', function(self, ...)
		hideCurrentlyOpenedLSMAndContextMenu()
	end)

	--ZO_Menu - ShowMenu hook: Hide LSM if a ZO_Menu menu opens
	ZO_PreHook("ShowMenu", function(owner, initialRefCount, menuType)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 175, tos(#ZO_Menu.items), tos(menuType)) end
		--Do not close on other menu types (only default menu type supported)
		if menuType ~= nil and menuType ~= MENU_TYPE_DEFAULT then return end

		--No entries in ZO_Menu -> nothign will be shown, abort here
		if next(ZO_Menu.items) == nil then
			return false
		end
		--Should the ZO_Menu not close any opened LSM? e.g. to show the textSearchHistory at the LSM text filter search box
		if lib.preventLSMClosingZO_Menu then
			lib.preventLSMClosingZO_Menu = nil
--d("[ShowMenu]preventLSMClosingZO_Menu: " ..tos(lib.preventLSMClosingZO_Menu))
			return
		end
		hideCurrentlyOpenedLSMAndContextMenu()
		return false
	end)

	--------------------------------------------------------------------------------------------------------------------
	--Slash commands
	--------------------------------------------------------------------------------------------------------------------
	SLASH_COMMANDS["/lsmdebug"] = function()
		libDebug.debugLoggingToggle("debug")
	end
	SLASH_COMMANDS["/lsmdebugverbose"] = function()
		libDebug.debugLoggingToggle("debugVerbose")
	end
end
EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
EM:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, onAddonLoaded)






------------------------------------------------------------------------------------------------------------------------
-- Notes | Changelog | TODO | UPCOMING FEATURES
------------------------------------------------------------------------------------------------------------------------

--[[
---------------------------------------------------------------
	NOTES
---------------------------------------------------------------



---------------------------------------------------------------
	CHANGELOG Current version: 2.35 - Updated 2025-02-08
---------------------------------------------------------------

[WORKING ON]

Split up into several files

[Fixed]
Removed globally leaking variables

[Added]

[Changed]

[Removed]


---------------------------------------------------------------
TODO - To check (future versions)
---------------------------------------------------------------
	1. Make Options update same style like updateDataValues does for entries
	2. Attention: zo_comboBox_base_hideDropdown(self) in self:HideDropdown() does NOT close the main dropdown if right clicked! Only for a left click... See ZO_ComboBox:HideDropdownInternal()
	3. verify submenu anchors. Small adjustments not easily seen on small laptop monitor
	- fired on handlers dropdown_OnShow dropdown_OnHide
	4. If header is enabled and the filter is enabled, you right clicked the editbox of the filter header, and choose an entry: Next left click outside does not close the opened dropdown)

---------------------------------------------------------------
UPCOMING FEATURES  - What could be added in the future?
---------------------------------------------------------------
	1. Sort headers for the dropdown (ascending/descending) (maybe: allowing custom sort functions too)
	2. LibCustomMenu and ZO_Menu replacement (currently postponed, see code at branch LSM v2.4) due to several problems with ZO_Menu (e.g. zo_callLater used by addons during context menu addition) and chat, and other problems
]]