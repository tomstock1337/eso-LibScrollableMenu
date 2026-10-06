local lib = LibScrollableMenu
if not lib then return end

local MAJOR = lib.name


--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--ZOs local speed-up/reference variables
local EM = GetEventManager() --EVENT_MANAGER
local tos = tostring
local sfor = string.format


--------------------------------------------------------------------
-- LSM library locals
--------------------------------------------------------------------
local constants = lib.constants
local entryTypeConstants = constants.entryTypes

local libXML  = lib.XML
local libUtil = lib.Util
local getControlData = libUtil.getControlData
local getValueOrCallback = libUtil.getValueOrCallback
local getContextMenuReference = libUtil.getContextMenuReference
local checkIfContextMenuOpenedButOtherControlWasClicked = libUtil.checkIfContextMenuOpenedButOtherControlWasClicked
local checkNextOnEntryMouseUpShouldExecute = libUtil.checkNextOnEntryMouseUpShouldExecute
local playSelectedSoundCheck = libUtil.playSelectedSoundCheck

local g_contextMenu
local clearCustomScrollableMenu

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
--local sv = lib.SV


--------------------------------------------------------------------
-- Local helper functions
--------------------------------------------------------------------
--Called from ZO_Menu's ShowMenu, if preventing the call via lib.preventLSMClosingZO_Menu == true is not enabled
--and called if the SCENE_MANAGER shows a scene
local function hideCurrentlyOpenedLSMAndContextMenu()
--d("[LSM]hideCurrentlyOpenedLSMAndContextMenu")
	local openMenu = lib.openMenu
	if openMenu and openMenu:IsDropdownVisible() then
		clearCustomScrollableMenu = clearCustomScrollableMenu or ClearCustomScrollableMenu
		clearCustomScrollableMenu()
		openMenu:HideDropdown()
	end
end


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

	assert(entryTableType == 'table' and mapTableType == 'table' , sfor("["..MAJOR..".MapEntries] tables expected, got %q = %s, %q = %s", "entryTable", tos(entryTableType), "mapTable", tos(mapTableType)))

	-- Splitting these up so the above is not done each iteration
	doMapEntries(entryTableToMap, mapTable, entryTableType)
end
lib.MapEntries = mapEntries
libUtil.MapEntries = mapEntries



------------------------------------------------------------------------------------------------------------------------
-- XML handler functions
------------------------------------------------------------------------------------------------------------------------

--Called from XML at e.g. the collapsible header's editbox, and other controls
--Used for event handlers like OnMouseUp, OnClicked and OnChanged etc.
-->Calls the function owningWindowFunctionName inside the refVar, and passes in the parameters ...
function libXML.OnXMLControlEventHandler(owningWindowFunctionName, refVar, ...)
--d(debugPrefix .. "lib.XML.OnXMLControlEventHandler - owningWindowFunctionName: " .. tos(owningWindowFunctionName))
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
function libXML.XMLButtonOnInitialize(control, entryType)
	--Which XML button control's handler was used, checkbox or radiobutton?
	local isCheckbox = entryType == entryTypeConstants.LSM_ENTRY_TYPE_CHECKBOX
	local isRadioButton = not isCheckbox and entryType == entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON

	control:GetParent():SetHandler('OnMouseUp', function(parent, buttonId, upInside, ...)
--d(debugPrefix .. "XML-OnMouseUp of parent-upInside: " ..tos(upInside) .. ", buttonId: " .. tos(buttonId))
		if upInside then
			if checkIfContextMenuOpenedButOtherControlWasClicked(control, parent.m_owner, buttonId) == true then
--d("<aborting due to checkIfContextMenuOpenedButOtherControlWasClicked, skipNextOnMouseUp: " .. tos(lib.preventerVars.suppressNextOnEntryMouseUp))
				return
			end
			if buttonId == MOUSE_BUTTON_INDEX_LEFT then
				--#2026-01 Here lib.preventerVars.suppressNextOnEntryMouseUp is already true and that way the first click on a checkbox or radio button,
				--after clicked on another checkbox before and then clossing and reopening the menu, is suppressed
				--20260606 Maybe the variable lib.preventerVars.suppressNextOnEntryMouseUp needs to be reset on each comboBox's ShowMenu calls?

				if checkNextOnEntryMouseUpShouldExecute() then
--d("<aborting due to checkNextOnEntryMouseUpShouldExecute, skipNextOnMouseUp: " .. tos(lib.preventerVars.suppressNextOnEntryMouseUp)) --#2026_01
					return
				end

				local data = getControlData(parent)
				local dropdown = parent.m_dropdownObject
				playSelectedSoundCheck(dropdown, data.entryType)

				local onClickedHandler = control:GetHandler('OnClicked')
				if onClickedHandler then
					onClickedHandler(control, buttonId) --Calls the OnClicked function below (for checkboxes only, radiobuttons use their default OnClicked handler) now

					dropdown:SubmenuOrCurrentListRefresh(control) --#2025_42 #2026_14 disable
				end

			elseif buttonId == MOUSE_BUTTON_INDEX_RIGHT then
				g_contextMenu = getContextMenuReference()

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

	--Checkboxes only!
	if not isRadioButton then
		local originalClicked = control:GetHandler('OnClicked')
		control:SetHandler('OnClicked', function(p_control, buttonId, ignoreCallback, skipHiddenForReasonsCheck, ...)
--d(debugPrefix .. "XML-OnClicked - buttonId: " .. tos(buttonId) .. ", skipHiddenForReasonsCheck: " ..tos(skipHiddenForReasonsCheck))
			skipHiddenForReasonsCheck = skipHiddenForReasonsCheck or false
--local prevVars = lib.preventerVars --#2026_01
--d("PreventerVars-skipNextOnMouseUp: " .. tos(prevVars.suppressNextOnEntryMouseUp) .. ", skipNextGlobalMouseUp: " ..tos(prevVars.suppressNextOnGlobalMouseUp) .. ", skipNextGlobalMouseUp: " ..tos(prevVars.suppressNextOnEntryMouseUpDisableCounter))

			if not skipHiddenForReasonsCheck then
				local comboBox = (p_control.toggleFunction ~= nil and p_control:GetParent().m_owner) or p_control.m_owner --#2026_14
				--Check if we clicked the row or the actual checkbox/radiobutton icon in the row -> in that case get the parentControl (the row)
				if checkIfContextMenuOpenedButOtherControlWasClicked(p_control, comboBox, buttonId) == true then
--d("<aborting due to checkIfContextMenuOpenedButOtherControlWasClicked, skipNextOnMouseUp: " .. tos(lib.preventerVars.suppressNextOnEntryMouseUp))
					return
				end
			end
			if checkNextOnEntryMouseUpShouldExecute() then
				return
--d("<<aborting due to checkNextOnEntryMouseUpShouldExecute, skipNextOnMouseUp: " .. tos(lib.preventerVars.suppressNextOnEntryMouseUp))
			end
			if originalClicked then
--d(">originalClicked called!")
				originalClicked(p_control, buttonId, ignoreCallback, ...) -- Calls ZO_CheckButton_OnClicked: OnClicked function was set at comboBox_base:SetupEntryCheckbox -> local addCheckButton -> ZO_CheckButton_SetToggleFunction -> local toggleFunction (in comboBox_base:SetupEntryCheckbox)
			end
			p_control.checked = nil
		end)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------

--Load of the addon/library starts
local function onAddonLoaded(eventId, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)

	--Debug logging
	libDebug.LoadLogger()
	libDebug = lib.Debug
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG, 174) end

	--SavedVariables
	lib.SV = ZO_SavedVars:NewAccountWide(svConstants.name, svConstants.version, svConstants.profile, svConstants.defaults)
	--sv = lib.SV

	--Create the ZO_ComboBox and the g_contextMenu object (lib.contextMenu) for the LSM contextmenus
	lib.CreateContextMenuObject()


	--------------------------------------------------------------------------------------------------------------------
	--Create any custom entry type
	--------------------------------------------------------------------------------------------------------------------
	-- ColorPicker
	lib.InstallColorPicker()


	--------------------------------------------------------------------------------------------------------------------
	--Hooks & ZOs code changes
	--------------------------------------------------------------------------------------------------------------------
	--Register a scene manager callback for the SetInUIMode function so any menu opened/closed closes the context menus of LSM too
	SecurePostHook(SCENE_MANAGER, 'SetInUIMode', function(self, inUIMode, bypassHideSceneConfirmationReason)
		if not inUIMode then
			clearCustomScrollableMenu = clearCustomScrollableMenu or ClearCustomScrollableMenu
			clearCustomScrollableMenu()
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
	CHANGELOG Current version: 2.47 - Updated 2026-10-06
---------------------------------------------------------------
Max error/feature #: 2026_22



[WORKING ON]
--#2026_22 More colorpicker features

[FEATURE]


--======================================================================================================================
[KNOWN PROBLEMS]
--======================================================================================================================
--#2026_01 After a LSM contextMenu was shown and a checkbox was clicked (on the checkbox's label, not the icon!), the next opened contextMenu's checkbox label
  is not changing the checkbox state (as if the first click is not accepted?), only the 2nd click does. (noticed during BMU LCM -> LSM changes at 2026-01-25)
--#2026_03 Search header contextMenu for last searched does not work on BeamMeUp item filter header?
--======================================================================================================================


[Fixed]
-- ColorPicker closes if any non-colorPicker raising entry is clicked, a contextMenu is opened, etc.

[Added]
--ColorPicker fires the following callbacks now:
LibScrollableMenu_ColorPicker_OnShown			-	Parameters: ColorPickerObject, comboBox, LSMEntryControl, colorPickerData
LibScrollableMenu_ColorPicker_OnHidden			-	Parameters:	ColorPickerObject
LibScrollableMenu_ColorPicker_OnColorSelected	-	Parameters: ColorPickerObject, comboBox, LSMEntryControl, colorPickerData, newColorTable
LibScrollableMenu_ColorPicker_OnColorReset		-	Parameters: ColorPickerObject, comboBox, LSMEntryControl, colorPickerData, resetColorTable

[Changed]
--Added parameter "comboBox, colorPickerData" to the API function colorPickerData.OnColorUpdateFunc signature: OnColorUpdateFunc(comboBox, r, g, b, a, colorPickerData)
--Added new possible values to colorPickerData table:
--					previewControl = userdata:control,			--optional control or function(comboBox, LSMEntryControl, colorPickerData) returning the control that should be colorized as the color is chosen in the color picker, and shows the preview of the color. By default this is the LSM entry's previewControl but you can specify any you want, including the LSM label of the entry e.g.
--					OnColorGetFunc = function(colorPickerData) return r, g, b, a end,	--optional function(comboBox, colorPickerData) returning the r, g, b, a values of the current color e.g. from SavedVariables -> Will only be used if no controlToColorize was provided where that could be read from automatically
--					defaultColor = { r=1, g=1, b=1, a=1 },		--optional color table or function(colorPickerData) returning a color table: The default color that the colorPicker should reset to
--					hidePreview =	false,						--optional boolean or function(colorPickerData) returning a boolean: Hide the previewControl (texture) that shows the current color
--					title = "Text here", 						--optional string or function(colorPickerData) returning a string for the color picker title. If not specified the title will be the label of the LSM entry clicked on to open the colorpicker. That entry label text is present in colorPickerData.LSMEntryLabel (once the entry was clicked) and can be used that way in your title callback function!
--					snapToOpeningControl = false,				--optional boolean or function(colorPickerData) returning a boolean: Snap the color picker UI to the LSM entry that opened it? Default: true

[Removed]


---------------------------------------------------------------
TODO - To check (future versions)
---------------------------------------------------------------


---------------------------------------------------------------
UPCOMING FEATURES  - What could be added in the future?
---------------------------------------------------------------
	1. LibCustomMenu and ZO_Menu replacement (currently postponed, see code at branch LSM v2.4) due to several problems with ZO_Menu (e.g. zo_callLater used by addons during context menu addition) and chat, and other problems
]]