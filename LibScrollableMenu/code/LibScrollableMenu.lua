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


local libUtil = lib.Util
local getControlData = libUtil.getControlData
local getValueOrCallback = libUtil.getValueOrCallback
local getContextMenuReference = libUtil.getContextMenuReference
local checkIfContextMenuOpenedButOtherControlWasClicked = libUtil.checkIfContextMenuOpenedButOtherControlWasClicked
local checkNextOnEntryMouseUpShouldExecute = libUtil.checkNextOnEntryMouseUpShouldExecute
local playSelectedSoundCheck = libUtil.playSelectedSoundCheck

local g_contextMenu


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
	local openMenu = lib.openMenu
	if openMenu and openMenu:IsDropdownVisible() then
		ClearCustomScrollableMenu()
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
--Used for event handlers like OnMouseUp and OnChanged etc.
function lib.XML.OnXMLControlEventHandler(owningWindowFunctionName, refVar, ...)
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
function lib.XML.XMLButtonOnInitialize(control, entryType)
	--Which XML button control's handler was used, checkbox or radiobutton?
	local isCheckbox = entryType == entryTypeConstants.LSM_ENTRY_TYPE_CHECKBOX
	local isRadioButton = not isCheckbox and entryType == entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON

	control:GetParent():SetHandler('OnMouseUp', function(parent, buttonId, upInside, ...)
--d(debugPrefix .. "XML-OnMouseUp of parent-upInside: " ..tos(upInside) .. ", buttonId: " .. tos(buttonId))
		if upInside then
			if checkIfContextMenuOpenedButOtherControlWasClicked(control, parent.m_owner, buttonId) == true then return end
			if buttonId == MOUSE_BUTTON_INDEX_LEFT then
				if checkNextOnEntryMouseUpShouldExecute() then return end

				local data = getControlData(parent)
				local dropdown = parent.m_dropdownObject
				playSelectedSoundCheck(dropdown, data.entryType)

				local onClickedHandler = control:GetHandler('OnClicked')
				if onClickedHandler then
					onClickedHandler(control, buttonId)

					dropdown:SubmenuOrCurrentListRefresh(control) --#2025_42
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

	if not isRadioButton then
		local originalClicked = control:GetHandler('OnClicked')
		control:SetHandler('OnClicked', function(p_control, buttonId, ignoreCallback, skipHiddenForReasonsCheck, ...)
			skipHiddenForReasonsCheck = skipHiddenForReasonsCheck or false
			if not skipHiddenForReasonsCheck then
				local parent = p_control:GetParent()
				local comboBox = parent.m_owner
				if checkIfContextMenuOpenedButOtherControlWasClicked(p_control, comboBox, buttonId) == true then return end
			end
			if checkNextOnEntryMouseUpShouldExecute() then return end

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
	--sv = lib.SV

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
	CHANGELOG Current version: 2.38 - Updated 2025-11-14
---------------------------------------------------------------
Max error #: 2025_61

[FEATURE]

[KNOWN PROBLEMS]
#2025_61 Submenu at contextmenu (opend from another submenu) will close the submenu of the context menu automatically if the entry of the opened submenu is not above the LSM dropdown.
--e.g. LSM test -> Normal entry 6 1:1 - ContextMenu with divider tests -> ContextMenu -> Submenu ContextMenu at Submenu Entry6 1:1 - 5 ->
-->  Submenu Entry 6 -> Move mouse above any opened submenu entry which is not above the LSM dropdowns anymore -> Submenu closes (if mouse is not moved anymore; as long as you move it fast enough above any new submenu it still opens them)


[WORKING ON]


[Fixed]
#2025_46 Clicking a disabled entry at a contextmenu submenu will close the submenu as the control is not mouseEnabled and the scrollList control below is clicked. Detection of the scrollList's owner == LSM menu should take place then to suppress the close of the menu?
#2025_47 Clicking a scrollbar at a contextmenu (submenu) will close the contextmenu (submenu)
#2025_48 Search header is not searching an editBox's text or a slider's value (only the label's text in front)
#2025_49 Editbox clicked at context menu's submenu will close the contextmenu
#2025_50 Slider  clicked at context menu's submenu will close the contextmenu
#2025_51 MultiIcon clicked at context menu's submenu will close the contextmenu
#2025_52 Checkbox [ ] part clicked in a submenu closes the submenu
#2025_53 Checkbox label or [ ] part clicked in a contextmenu's submenu closes the submenu
#2025_54 Radiobutton label or [ ] part clicked in a contextmenu's submenu closes the submenu
#2025_55 Radiobutton [ ] part clicked in a contextmenu's submenu raises a lua error user:/AddOns/LibScrollableMenu/classes/buttonGroup_class.lua:171: attempt to index a nil value

[Added]
#2025_42 Automatically update all entries (checkbox/radiobutton checked, and all entries enabled state) in a (sub)menu, if e.g. any other entry was clicked
#2025_43 Automatically fix wrong formated .icon table format
#2025_44 Recursively check if any entry on the current submenu's path, up to the main menu (via the parentMenus), needs an update.
--Optional checkFunc must return a boolean true [default return value] (refresh now) or false (no refresh needed), and uses the signature:
--> checkFunc(comboBox, control, data)
--Manual call via API function UpdateCustomScrollableMenuEntryPath (e.g. from any callback of an entry) or automatic call if submenuEntry.updateEntryPath == true
--UpdateCustomScrollableMenuEntryPath(comboBox, control, data, checkFunc, checkFuncParam1, checkFuncParam2, ...)
#2025_45 Register special contextMenu OnShow and/or OnHide callback for registered contextMenus (done at ShowCustomScrollableMenu, last parameter specialCallbackData.addonName and specialCallbackData.onHideCallback e.g.)
--#2025_57 Recursively check if any icon on the current submenu's path, up to the main menu (via the parentMenus), needs an update.
--Manual call via API function UpdateCustomScrollableMenuEntryIconsPath (e.g. from any callback of an entry) or automatic call if submenuEntry.updateIconPath == true
--UpdateCustomScrollableMenuEntryIconsPath(comboBox, control, data)
#2025_58 API to refresh a dropdown's submenu or mainmenu or an entry control visually (e.g. if you click an entry, called from the callback function)
-->Parameter updateMode can be left empty, then the system will automatically determine if a submenu exists and the item belongs to that, and refresh that,
--or it will update the mainmenu if it exists.
--Or you specify one of the following updateModes:
--->LSM_UPDATE_MODE_MAINMENU	Only update the mainmenu visually
--->LSM_UPDATE_MODE_SUBMENU		Only update the submenu visually
--->LSM_UPDATE_MODE_BOTH		Update the submenu and the mainmenu, both
---Parameter comboBox is optional
RefreshCustomScrollableMenu(mocCtrl, updateMode, comboBox)
#2025_59 Added API function IsCustomScrollableContextMenuShown()
--Returns boolean true/false if any LSM context menu is currently showing it's dropdown
#2025_60 Added API function IsCustomScrollableMenuShown()
--Returns boolean true/false if any LSM menu is currently showing it's dropdown (including any LSM ContextMenu!)


[Changed]
#2025_56 Change entry's data.doNotFilter: If it's a function it's signature now is doNotFilterFunc(LSM_comboBox, selectedContextMenuItem, openingMenusEntries), so one can e.g. make a button entryType only filter if there is no other entry inside the table currentDropdownEntriesTable
--->If it's a fucntion you can also specify doNotFilterEntryTypes = table or function returning a table of LSM entryTypes which should be prefiltering the current list, before the doNotFilter function is executed on them (e.g. { LSM_ENTRY_TYPE_CHECKBOX } to only prefilter checkbox entries of the current list)

[Removed]


---------------------------------------------------------------
TODO - To check (future versions)
---------------------------------------------------------------
	1. Optionally: Make Options update same style like updateDataValues does for entries
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