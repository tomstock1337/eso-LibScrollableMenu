if LibScrollableMenu ~= nil then return end -- the same or newer version of this lib is already loaded into memory

local lib = ZO_CallbackObject:New()
lib.name = "LibScrollableMenu"
local MAJOR = lib.name
lib.version = "1.6"

lib.data = {}

if not lib then return end

--Constant for the divider entryType
lib.DIVIDER = "-"

lib.HELPER_MODE_NORMAL = 0
lib.HELPER_MODE_LAYOUT_ONLY = 1 -- means only the layout of the dropdown will be altered, not the way it handles layering through ZO_Menus

--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--local speed up variables
local EM = EVENT_MANAGER
local SNM = SCREEN_NARRATION_MANAGER

local tos = tostring
local sfor = string.format
local tins = table.insert

--Sound settings
local origSoundComboClicked = SOUNDS.COMBO_CLICK
local soundComboClickedSilenced = SOUNDS.NONE

--Submenu settings
local ROOT_PREFIX = MAJOR.."Sub"
local SUBMENU_SHOW_TIMEOUT = 350
local submenuCallLaterHandle
local nextId = 1

--Custom scrollable menu settings (context menus e.g.)
local CUSTOM_SCROLLABLE_MENU_NAME = MAJOR.."_CustomContextMenu"

--Menu settings (main and submenu)
local MAX_MENU_ROWS = 25
local MAX_MENU_WIDTH
local DEFAULT_VISIBLE_ROWS = 10
local DEFAULT_SORTS_ENTRIES = true --sort the entries in main- and submenu lists

--Entry type settings
local DIVIDER_ENTRY_HEIGHT = 7
local HEADER_ENTRY_HEIGHT = 30
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT -- same as in zo_combobox.lua: 25
local ICON_PADDING = 20
local PADDING = GetMenuPadding() / 2 -- half the amount looks closer to the regular dropdown
local WITHOUT_ICON_LABEL_DEFAULT_OFFSETX = 4

--Entry types
local ENTRY_ID = 1
local LAST_ENTRY_ID = 2
local DIVIDER_ENTRY_ID = 3
local HEADER_ENTRY_ID = 4
local SUBMENU_ENTRY_ID = 5
local CHECKBOX_ENTRY_ID = 6
--Make them accessible for the ScrollableDropdownHelper:New options table -> options.XMLRowTemplates 
lib.scrollListRowTypes = {
	ENTRY_ID = ENTRY_ID,
	LAST_ENTRY_ID = LAST_ENTRY_ID,
	DIVIDER_ENTRY_ID = DIVIDER_ENTRY_ID,
	HEADER_ENTRY_ID = HEADER_ENTRY_ID,
	SUBMENU_ENTRY_ID = SUBMENU_ENTRY_ID,
	CHECKBOX_ENTRY_ID = CHECKBOX_ENTRY_ID,
}
--Saved indices of header and divider entries (upon showing the menu -> AddMenuItems)
local rowIndex = {
	[DIVIDER_ENTRY_ID] = {},
	[HEADER_ENTRY_ID] = {},
}

--Possible options passed in at the ScrollableHelper menus are:
local possibleLibraryOptions = {
	["visibleRowsDropdown"] = true,
	["visibleRowsSubmenu"] = true,
	["sortEntries"] = true,
	["XMLRowTemplates"] = true,
	["narrate"] = true,
}
lib.possibleLibraryOptions = possibleLibraryOptions

--The default values for the context menu options are:
local defaultContextMenuOptions  = {
	["visibleRowsDropdown"] = 20,
	["visibleRowsSubmenu"] = 20,
	["sortEntries"] = false,
}
lib.defaultContextMenuOptions  = defaultContextMenuOptions

--Textures
local iconNewIcon = ZO_KEYBOARD_NEW_ICON

--Tooltip anchors
local defaultTooltipAnchor = {TOPLEFT, 0, 0, BOTTOMRIGHT}

--Narration
local UINarrationName = MAJOR .. "_UINarration_"
local UINarrationUpdaterName = MAJOR .. "_UINarrationUpdater_"

--Boolean to on/off texts for narration
--[[
local booleanToOnOff = {
    [false] = GetString(SI_CHECK_BUTTON_OFF):upper(),
    [true]  = GetString(SI_CHECK_BUTTON_ON):upper(),
}
]]
--MultiIcon
local iconNarrationNewValue = GetString(SI_SCREEN_NARRATION_NEW_ICON_NARRATION)

--Custom scrollable menu's ZO_ComboBox
local customScrollableMenuComboBox


--------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------

local function clearTimeout()
	if (submenuCallLaterHandle ~= nil) then
		EM:UnregisterForUpdate(submenuCallLaterHandle)
		submenuCallLaterHandle = nil
	end
end

local function setTimeout(callback)
	if (submenuCallLaterHandle ~= nil) then clearTimeout() end
	submenuCallLaterHandle = MAJOR.."Timeout" .. nextId
	nextId = nextId + 1

	EM:RegisterForUpdate(submenuCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		clearTimeout()
		if callback then callback() end
	end )
end


-- TODO: Decide on what to pass, in LibCustomMenus it always passes ZO_Menu as the 1st parameter
-- but since we don't use that there are a few options:
--    1) Always pass the root dropdown and never a submenu dropdown
--    2) Pass root dropdown for initial entries and the appropriate submenu dropdown for the rest
--    3) Don't pass any dropdown control or object (!!CURRENTLY USED!!)
-- Another decision is if we pass the dropdown control, the parent container or the combobox object
--
-- Regardless of the above we always pass the control/entry data since in a scroll list the controls
-- aren't fixed for each entry.
local function getValueOrCallback(arg, ...)
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end

local function getContainerFromControl(control)
	local owner = control.m_owner
	return owner and owner.m_container
end

local function getSubmenuFromControl(control)
	local owner = control.m_owner
	return owner and owner.m_submenu
end

local function getScrollHelperObjectFromControl(control)
	--Submenu entry?
	local submenu = getSubmenuFromControl(control)
	if submenu ~= nil then
d(">submenu found form control")
		return submenu.scrollHelper
	else
d(">normal menu found form control")
		--Normal menu entry
		local container = getContainerFromControl(control)
		if container ~= nil then
			return container.parentScrollableDropdownHelper or container.scrollHelper
		else
d(">Container is nil")
			if control == lib.customContextMenu then
				return control.scrollHelper
			end
		end
	end
	return
end

local function getOptionsForEntry(entry)
	local entrysComboBox = getContainerFromControl(entry)
	
	--[[ IsJustaGhost
		TODO: Would it be better to return {} if nil
		local options = entrysComboBox.options or {}
	]]
		
	return entrysComboBox ~= nil and entrysComboBox.options
end

local function defaultRecursiveCallback(_entry)
	return false
end

local function getIsNew(_entry)
	return getValueOrCallback(_entry.isNew, _entry) or false
end

-- Recursive over entries.
local function recursiveOverEntries(entry, callback)
	callback = callback or defaultRecursiveCallback
	
	local result = callback(entry)
	local submenu = entry.entries or {}
	if #submenu > 0 then
		for k, subEntry in pairs(submenu) do
			local subEntryResult = recursiveOverEntries(subEntry, callback)
			if subEntryResult then
				result = subEntryResult
			end
		end
	end
	return result
end

-- Recursively check for new entries.
local function areAnyEntriesNew(entry)
	return recursiveOverEntries(entry, getIsNew)
end

local function silenceComboBoxClickedSound(doSilence)
	doSilence = doSilence or false
	if doSilence == true then
		--Silence the "selected combobox sound"
		SOUNDS.COMBO_CLICK = soundComboClickedSilenced
	else
		--Unsilence the "selected combobox sound" again
		SOUNDS.COMBO_CLICK = origSoundComboClicked
	end
end

local function playSelectedSoundCheck(entry)
	silenceComboBoxClickedSound(false)

	local soundToPlay = origSoundComboClicked
	local options = getOptionsForEntry(entry)
	
	if options ~= nil then
		--Chosen at options to play no selected sound?
		if getValueOrCallback(options.selectedSoundDisabled, options) == true then
			silenceComboBoxClickedSound(true)
			return
		else
			soundToPlay = getValueOrCallback(options.selectedSound, options)
			soundToPlay = soundToPlay or SOUNDS.COMBO_CLICK
		end
	end
	PlaySound(soundToPlay) --SOUNDS.COMBO_CLICK
end

-- TODO: Is this even needed?
local function setMaxMenuWidthAndRows()
	-- MAX_MENU_WIDTH is to set a cap on how wide text can make a menu. Don't want a menu being 2934 pixels wide.
    local uiWidth, uiHeight = GuiRoot:GetDimensions()
	MAX_MENU_WIDTH = uiWidth * 0.3
	MAX_MENU_ROWS = zo_floor((uiHeight * 0.5) / SCROLLABLE_ENTRY_TEMPLATE_HEIGHT)
--	/script d(GuiRoot:GetDimensions() * 0.2)
-- On my screen, at 0.2, this is currently 384
end

--Get currently shown entryType in the dropdown, to calculate the height properly
local function getVisibleEntryTypeControls(visibleRows, entryType)
	local highest = 0
	--Filled at function ScrollableDropdownHelper:AddMenuItems(), CreateEntry
	for k, index in ipairs(rowIndex[entryType]) do
		if index < visibleRows then
			highest = highest + 1
		end
	end
	return highest
end

--Get currently shown divider and header indices of the menu entries
local function getVisibleHeadersAndDivider(visibleItems)
	return getVisibleEntryTypeControls(visibleItems, HEADER_ENTRY_ID), getVisibleEntryTypeControls(visibleItems, DIVIDER_ENTRY_ID)
end
	
local function doMapEntries(entryTable, mapTable)
	for k, entry in pairs(entryTable) do
		if entry.entries then
			doMapEntries(entry.entries, mapTable)
		end
		
		-- TODO: only map entries with callbacks?
		if entry.callback then
		--	tins(mapTable, entry)
			mapTable[entry] = entry
		end
	end
end


-- This function will create a map of all entries recursively. Useful when there are submenu entries
-- and you want to use them for comparing in the callbacks, NewStatusUpdated, CheckboxUpdated
local function mapEntries(entryTable, mapTable, blank)
    if blank ~= nil then
        entryTable = mapTable
        mapTable = blank
        blank = nil
    end
	
	local entryTableType, mapTableType = type(entryTable), type(mapTable)
	assert(entryTableType == 'table' and mapTableType == 'table' , sfor('[LibScrollableMenu:MapEntries] tables expected got entryTable = %s, mapTable = %s', tos(entryTableType), tos(mapTableType)))
	
	-- Splitting these up so the above is not done each iteration
	doMapEntries(entryTable, mapTable)
end


local function AnchorCustomContextMenuToMouse(menuToAnchor)
	if menuToAnchor == nil then return end
	local x, y = GetUIMousePosition()
	local width, height = GuiRoot:GetDimensions()

	menuToAnchor:ClearAnchors()

--d("[LSM]AnchorCustomContextMenuToMouse-width: " ..tos(menuToAnchor:GetWidth()) .. ", height: " ..tos(menuToAnchor:GetHeight()))

	local right = true
	if x + menuToAnchor:GetWidth() > width then
		right = false
	end
	local bottom = true
	if y + menuToAnchor:GetHeight() > height then
		bottom = false
	end

	if right then
		if bottom then
			menuToAnchor:SetAnchor(TOPLEFT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMLEFT, nil, TOPLEFT, x, y)
		end
	else
		if bottom then
			menuToAnchor:SetAnchor(TOPRIGHT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMRIGHT, nil, TOPLEFT, x, y)
		end
	end
end

local function mergeTable(dest, src)
	-- just reversing the desired table
	zo_mixin(src, dest)
end


--------------------------------------------------------------------
-- Local narration functions
--------------------------------------------------------------------
local function isAccessibilitySettingEnabled(settingId)
    return GetSetting_Bool(SETTING_TYPE_ACCESSIBILITY, settingId)
end

local function isAccessibilityModeEnabled()
	return isAccessibilitySettingEnabled(ACCESSIBILITY_SETTING_ACCESSIBILITY_MODE)
end

local function isAccessibilityUIReaderEnabled()
	return isAccessibilityModeEnabled() and isAccessibilitySettingEnabled(ACCESSIBILITY_SETTING_SCREEN_NARRATION)
end

--Currently commented as these functions are used in each addon and the addons only pass in options.narrate table so their
--functions will be called for narration
local function canNarrate()
	--todo: Add any other checks, like "Is any menu still showing ..."
	return true
end

--local customNarrateEntryNumber = 0
local function addNewUINarrationText(newText, stopCurrent)
    if isAccessibilityUIReaderEnabled() == false then return end
    stopCurrent = stopCurrent or false
--d("["..MAJOR.."]AddNewChatNarrationText-stopCurrent: " ..tostring(stopCurrent) ..", text: " ..tostring(newText))
    --Stop the current UI narration before adding a new?
	if stopCurrent == true then
        --StopNarration(true)
        ClearActiveNarration()
    end

	--!DO NOT USE CHAT NARRATION AS IT IS TO CLUNKY / NON RELIABLE!
    --Remove any - from the text as it seems to make the text not "always" be read?
    --local newTextClean = string.gsub(newText, "-", "")

    --if newTextClean == nil or newTextClean == "" then return end
    --PlaySound(SOUNDS.TREE_HEADER_CLICK)
    --if LibDebugLogger == nil and DebugLogViewer == nil then
        --Using this API does no always properly work
        --RequestReadTextChatToClient(newText)
        --Adding it to the chat as debug message works better/more reliably
        --But this will add a timestamp which is read, too :-(
        --CHAT_ROUTER:AddDebugMessage(newText)
    --else
        --Using this API does no always properly work
        --RequestReadTextChatToClient(newText)
        --Adding it to the chat as debug message works better/more reliably
        --But this will add a timestamp which is read, too :-(
        --Disable DebugLogViewer capture of debug messages?
        --LibDebugLogger:SetBlockChatOutputEnabled(false)
        --CHAT_ROUTER:AddDebugMessage(newText)
        --LibDebugLogger:SetBlockChatOutputEnabled(true)
    --end
    --RequestReadTextChatToClient(newTextClean)


    --Use UI Screen reader narration
    local addOnNarationData = {
        canNarrate = function()
            return canNarrate() --ADDONS_FRAGMENT:IsShowing() -->Is currently showing
        end,
        selectedNarrationFunction = function()
            return SNM:CreateNarratableObject(newText)
        end,
    }
    --customNarrateEntryNumber = customNarrateEntryNumber + 1
    local customNarrateEntryName = UINarrationName --.. tostring(customNarrateEntryNumber)
    SNM:RegisterCustomObject(customNarrateEntryName, addOnNarationData)
	SNM:QueueCustomEntry(customNarrateEntryName)
    RequestReadPendingNarrationTextToClient(NARRATION_TYPE_UI_SCREEN)
end

--Delayed narration updater function to prevent queuing the same type of narration (e.g. OnMouseEnter and OnMouseExit)
--several times after another, if you move the mouse from teh top of a menu to the bottom of the menu, hitting all entries once
-->Only the last entry will be narrated then, where the mouse stops
local function onUpdateDoNarrate(uniqueId, delay, callbackFunc)
    local updaterName = UINarrationUpdaterName ..tostring(uniqueId)
--d("[LSM]onUpdateDoNarrate-updaterName: " ..tos(updaterName))
    EM:UnregisterForUpdate(updaterName)
    if isAccessibilityUIReaderEnabled() == false or callbackFunc == nil then return end
    delay = delay or 1000
    EM:RegisterForUpdate(updaterName, delay, function()
        if isAccessibilityUIReaderEnabled() == false then EM:UnregisterForUpdate(updaterName) return end
--d(">>>calling func delayed now!")
        callbackFunc()
        EM:UnregisterForUpdate(updaterName)
    end)
end

--Own narration functions, if ever needed -> Currently the addons pass in their narration functions
local function onMouseEnterOrExitNarrate(narrateText, stopCurrent)
	onUpdateDoNarrate("OnMouseEnterExit", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end

local function onSelectedNarrate(narrateText, stopCurrent)
	onUpdateDoNarrate("OnEntryOrCheckboxSelected", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end

local function onMouseMenuOpenOrCloseNarrate(narrateText, stopCurrent)
	onUpdateDoNarrate("OnMenuOpenOrClose", 25, function() addNewUINarrationText(narrateText, stopCurrent) end)
end
--Lookup table for ScrollableHelper:Narrate() function -> If a string will be returned as 1st return parameter (and optionally a boolean as 2nd, for stopCurrent)
--by the addon's narrate function, the library will lookup the function to use for the narration event, and narrate it then via the UI narration.
-->Select the same function if you want to suppress multiple similar messages to be played after another (e.g. OnMouseEnterExitNarrate for similar OnMouseEnter/Exit events)
local narrationEventToLibraryNarrateFunction = {
	["OnDropdownMouseEnter"] = 	onMouseEnterOrExitNarrate,
	["OnDropdownMouseExit"] =	onMouseEnterOrExitNarrate,
	["OnMenuShow"] = 			onMouseEnterOrExitNarrate,
	["OnMenuHide"] = 			onMouseEnterOrExitNarrate,
	["OnSubMenuShow"] = 		onMouseMenuOpenOrCloseNarrate,
	["OnSubMenuHide"] = 		onMouseMenuOpenOrCloseNarrate,
	["OnEntryMouseEnter"] = 	onMouseEnterOrExitNarrate,
	["OnEntryMouseExit"] = 		onMouseEnterOrExitNarrate,
	["OnEntrySelected"] = 		onSelectedNarrate,
	["OnCheckboxUpdated"] = 	onSelectedNarrate,
}


--------------------------------------------------------------------
-- ScrollableDropdownHelper
--------------------------------------------------------------------
local ScrollableDropdownHelper = ZO_InitializingObject:Subclass()
lib.ScrollableDropdownHelper = ScrollableDropdownHelper

-- ScrollableDropdownHelper:New( -- Just a reference for New
-- Available options are: See below at API function "AddCustomScrollableComboBoxDropdownMenu"
function ScrollableDropdownHelper:Initialize(parent, control, options, isSubMenuScrollHelper)
	isSubMenuScrollHelper = isSubMenuScrollHelper or false
	control.scrollHelper = self

	local combobox = control.combobox
	local dropdown = control.dropdown

	self.parent = parent
	self.control = control
	self.combobox = combobox
	self.dropdown = dropdown
	self.isSubMenuScrollHelper = isSubMenuScrollHelper

	--Not a submenu? Add the reference to our ScrollHelper object to the combobox's control/container
	--so we can read it via the Submenu's "owner" (= the combobox control) .parentScrollableDropdownHelper again
	if not isSubMenuScrollHelper then
		control.parentScrollableDropdownHelper = self
	end
	--self.visibleRows = GetOption(options, "visibleRows", DEFAULT_VISIBLE_ROWS)
	--self.mode        = GetOption(options, "mode", lib.HELPER_MODE_NORMAL)

	--For the custom scrollable context menu
	self.customContextMenuEntries = {}
	--Set the options and prepare some defaults
	self:UpdateOptions(options)

	-- clear anchors so we can adjust the width dynamically
	dropdown.m_dropdown:ClearAnchors()
	dropdown.m_dropdown:SetAnchor(TOPRIGHT, combobox, BOTTOMRIGHT)

	-- handle dropdown or settingsmenu opening/closing
	-- I would prefer to add these to a class
	local function onShow() self:OnShow() end
	local function onHide(isOnEffectivelyHiddenCall) self:OnHide(isOnEffectivelyHiddenCall) end
	local function doHide() self:DoHide() end

	local narrateData = self.narrateData
	if not isSubMenuScrollHelper and narrateData ~= nil and (narrateData["OnDropdownMouseEnter"] or narrateData["OnDropdownMouseExit"]) then
		local function dropdownOnMouseEnter()
			self:Narrate("OnDropdownMouseEnter", control, nil, nil)
		end
		local function dropdownOnMouseExit()
			self:Narrate("OnDropdownMouseExit", control, nil, nil)
		end
		combobox:SetHandler("OnMouseEnter", function() dropdownOnMouseEnter() end)
		combobox:SetHandler("OnMouseExit", function() dropdownOnMouseExit() end)
	end

	ZO_PreHook(dropdown,"ShowDropdownOnMouseUp", onShow)
	ZO_PreHook(dropdown,"HideDropdownInternal", onHide)
	combobox:SetHandler("OnEffectivelyHidden", function() onHide(false) end)
	if parent then parent:SetHandler("OnEffectivelyHidden", doHide) end

	--combobox.m_comboBox:SetSortsItems(self.sortsItems) --> Moved to self:UpdateOptions()

	-- dont fade entries near the edges
	local mScroll = dropdown.m_scroll
	mScroll.selectionTemplate = nil
	mScroll.highlightTemplate = nil
	ZO_ScrollList_EnableSelection(mScroll, "ZO_SelectionHighlight")
	ZO_ScrollList_EnableHighlight(mScroll, "ZO_SelectionHighlight")
	ZO_Scroll_SetUseFadeGradient(mScroll, false)

	-- adjust scroll content anchor to mimic menu padding
	local scroll = dropdown.m_dropdown:GetNamedChild("Scroll")
	local anchor1 = {scroll:GetAnchor(0)}
	local anchor2 = {scroll:GetAnchor(1)}
	scroll:ClearAnchors()
	scroll:SetAnchor(anchor1[2], anchor1[3], anchor1[4], anchor1[5] + PADDING, anchor1[6] + PADDING)
	scroll:SetAnchor(anchor2[2], anchor2[3], anchor2[4], anchor2[5] - PADDING, anchor2[6] - PADDING)

	--Disable multi selection (added zo ZO_ComboBox with update P40)
	-->Clears the box!
	dropdown:DisableMultiSelect()

	ZO_ScrollList_Commit(mScroll)

	-- make sure spacing is updated for dividers
	local function setSpacing(dropdown, spacing)
		local newHeight = DIVIDER_ENTRY_HEIGHT + spacing
		ZO_ScrollList_UpdateDataTypeHeight(mScroll, DIVIDER_ENTRY_ID, newHeight)
	end
	ZO_PreHook(dropdown, "SetSpacing", setSpacing)

	-- NOTE: changed to completely override the function
	--> Will add the entries added via comboBox:AddItems(), calculate height and width, etc.
	dropdown.AddMenuItems = function() self:AddMenuItems() end

	--Add the dataTypes to the scroll list (normal row, last row, header row, submenu row, divider row)
	self:AddDataTypes()

	--------------------------------------------------------------------
	--Hooks
	-- List data type templates
	--Disable the SOUNDS.COMBO_CLICK upon item selected. Will be handled via options table AND
	--------------------------------------------------------------------
	--function LibScrollableMenu_OnSelected below!
	--...
	--Reenable the sound for comboBox select item again
	SecurePostHook(dropdown, "SelectItem", function()
		silenceComboBoxClickedSound(false)
	end)

	return self
end

-- Add the dataTypes for the different entry types
function ScrollableDropdownHelper:AddDataTypes()
	local dropdown = self.dropdown
	local mScroll = dropdown.m_scroll
	local options = self.control.options or {}

	--dataType 1 (normal entry) and dataType2 (last entry) use the same default setupCallback
	local dataType1 = ZO_ScrollList_GetDataTypeTable(mScroll, 1)
	--local dataType2 = ZO_ScrollList_GetDataTypeTable(mScroll, 2)
	--Determine the original setupCallback for the list row -> Maybe default's ZO:ComboBox one, but maybe even changed by any addon -> Depends on the
	--combobox this ScrollHelper was added to!
	local oSetup = dataType1.setupCallback -- both data types 1 (normal row) and 2 (last row) use the same setup function. See ZO_ComboBox.lua, ZO_ComboBox:SetupScrollList()

	-- hook mouse enter/exit
	local function onMouseEnter(control) return self:OnMouseEnter(control) end
	local function onMouseExit(control)  return self:OnMouseExit(control)  end

	-- checkbox wrappers
	local function setChecked(checkbox, checked)
		local data = ZO_ScrollList_GetData(checkbox:GetParent())
		
		data.checked = checked
		if data.callback then
			data.callback(checked, data)
		end
		
		self:Narrate("OnCheckboxUpdated", checkbox, data, nil)
		lib:FireCallbacks('CheckboxUpdated', checked, data, checkbox)
	end

	local function addCheckbox(control, data, list)
		control.m_checkbox = control.m_checkbox or control:GetNamedChild("Checkbox")
		local checkbox = control.m_checkbox
		ZO_CheckButton_SetToggleFunction(checkbox, setChecked)
		ZO_CheckButton_SetCheckState(checkbox, getValueOrCallback(data.checked, data))
	end
	
	local function addIcon(control, data, list)
		local iconContainer = control:GetNamedChild("IconContainer")
		control.m_iconContainer = iconContainer
		control.m_icon = iconContainer:GetNamedChild("Icon")
		control.m_label = control.m_label or control:GetNamedChild("Label")
		control.m_checkbox = control.m_checkbox or control:GetNamedChild("Checkbox")
		ScrollableDropdownHelper.UpdateIcons(control, data)
	end
	
	local function addArrow(control, data, list)
		control.m_arrow = control:GetNamedChild("Arrow")
		
		local hasSubmenu = data.entries ~= nil
		data.hasSubmenu = hasSubmenu
		
		if control.m_arrow then
			control.m_arrow:SetHidden(not hasSubmenu)
			--SUBMENU_ARROW_PADDING = control.m_arrow:GetHeight()
		end
	end
	
	local function addDivider(control, data, list)
		control.m_owner = data.m_owner
		control.m_data = data
		control.m_divider = control:GetNamedChild("Divider")
	end

	local function addLabel(control, data, list)
		control.m_owner = data.m_owner
		control.m_data = data
		control.m_label = control.m_label or control:GetNamedChild("Label")

		local oName = data.name
		local name = getValueOrCallback(data.name, data)
		-- I used this to test max row width. Since this text is being changed later then data is passed in,
		-- it only effects the width after 1st showing.
	--	local name = GetValueOrCallback(data.name, data) .. ': This is so I can test the max width of entry text.'
		local labelStr = name
		if oName ~= name then
			data.oName = oName
			data.name = name
		end
		
		--Passed in an alternative text/function returning a text to show at the label control of the menu entry?
		if data.label ~= nil then
			data.labelStr  = getValueOrCallback(data.label, data)
			labelStr = data.labelStr
		end
		
		control.m_label:SetText(labelStr)
		control.m_font = control.m_owner.m_font
		
		if not control.isHeader then
			-- This would overwrite the header's font and color.
			control.m_label:SetFont(control.m_owner.m_font)
			control.m_label:SetColor(control.m_owner.m_normalColor:UnpackRGBA())
		end
	end

	local function hookHandlers(control, data, list)
			-- This is for the mouse-over tooltips
		if not control.hookedMouseHandlers then --only do it once per control
			control.hookedMouseHandlers = true
			ZO_PreHookHandler(control, "OnMouseEnter", onMouseEnter)
			ZO_PreHookHandler(control, "OnMouseExit", onMouseExit)
		end
	end

	-- was planing on moving ScrollableDropdownHelper:AddDataTypes() and 
	-- all the template stuff wrapped up in here
	local defaultXMLTemplates  = {
		[ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				oSetup(control, data, list)
				control.oSetup = oSetup

				--Check if the data.name is a function returning a string, so prepare the String value now
				--and update the original function for later usage to data.oName
				addIcon(control, data, list)
				addArrow(control, data, list)
				addLabel(control, data, list)
				hookHandlers(control, data, list)
			--	control.m_data = data --update changed (after oSetup) data entries to the control, and other entries have been updated
			end,
		},
		[SUBMENU_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxSubmenuEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				--Check if the data.name is a function returning a string, so prepare the String value now
				--and update the original function for later usage to data.oName
				addIcon(control, data, list)
				addArrow(control, data, list)
				addLabel(control, data, list)
				hookHandlers(control, data, list)
			--	control.m_data = data --update changed (after oSetup) data entries to the control, and other entries have been updated
			end,
		},
		[DIVIDER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxDividerEntry',
			rowHeight = DIVIDER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				addDivider(control, data, list)
			end,
		},
		[HEADER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxHeaderEntry',
			rowHeight = HEADER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				control.isHeader = true
				addDivider(control, data, list)
				addIcon(control, data, list)
				addLabel(control, data, list)
				hookHandlers(control, data, list)
			end,
		},
		[CHECKBOX_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxCheckboxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				oSetup(control, data, list)
				control.oSetup = oSetup

				control.isCheckbox = true
				addIcon(control, data, list)
				addCheckbox(control, data, list)
				addLabel(control, data, list)
				hookHandlers(control, data, list)
			end,
		},
	}
	--Default last entry ID copies from normal entry id
	defaultXMLTemplates[LAST_ENTRY_ID] = ZO_ShallowTableCopy(defaultXMLTemplates[ENTRY_ID])
	lib.DefaultXMLTemplates = defaultXMLTemplates

	-- >> template, height, setupFunction
	local function getTemplateData(entryType, template)
		local templateDataForEntryType = template[entryType]
		return templateDataForEntryType.template, templateDataForEntryType.rowHeight, templateDataForEntryType.setupFunc
	end

	--Overwrite(remove) the list's data types for entry and last entry: Set nil
	mScroll.dataTypes[ENTRY_ID] = nil
	mScroll.dataTypes[LAST_ENTRY_ID] = nil

--    local entryHeight = dropdown:GetEntryTemplateHeightWithSpacing()
	
		--Were any options and XMLRowTemplates passed in?
	local optionTemplates = options and getValueOrCallback(options.XMLRowTemplates, options)
	local XMLrowTemplatesToUse = ZO_ShallowTableCopy(defaultXMLTemplates)

	--Check if all XML row templates are passed in, and update missing ones with default values
	if optionTemplates ~= nil then
		for entryType, defaultData in pairs(defaultXMLTemplates) do
			if optionTemplates[entryType] ~= nil  then
				zo_mixin(XMLrowTemplatesToUse[entryType], optionTemplates[entryType])
			end
		end
	end
	
    ZO_ScrollList_AddDataType(mScroll, ENTRY_ID, getTemplateData(ENTRY_ID, XMLrowTemplatesToUse))
    ZO_ScrollList_AddDataType(mScroll, LAST_ENTRY_ID, getTemplateData(LAST_ENTRY_ID, XMLrowTemplatesToUse))
	ZO_ScrollList_AddDataType(mScroll, SUBMENU_ENTRY_ID, getTemplateData(SUBMENU_ENTRY_ID, XMLrowTemplatesToUse))
	ZO_ScrollList_AddDataType(mScroll, DIVIDER_ENTRY_ID, getTemplateData(DIVIDER_ENTRY_ID, XMLrowTemplatesToUse))
	ZO_ScrollList_AddDataType(mScroll, HEADER_ENTRY_ID, getTemplateData(HEADER_ENTRY_ID, XMLrowTemplatesToUse))
	ZO_ScrollList_AddDataType(mScroll, CHECKBOX_ENTRY_ID, getTemplateData(CHECKBOX_ENTRY_ID, XMLrowTemplatesToUse))
	ZO_ScrollList_SetTypeSelectable(mScroll, DIVIDER_ENTRY_ID, false)
	ZO_ScrollList_SetTypeSelectable(mScroll, HEADER_ENTRY_ID, false)
--	ZO_ScrollList_SetTypeCategoryHeader(mScroll, HEADER_ENTRY_ID, true)

	--Define the heights of the different rowTypes, for later totaleight calculation
	SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = XMLrowTemplatesToUse[ENTRY_ID].rowHeight
	DIVIDER_ENTRY_HEIGHT = XMLrowTemplatesToUse[DIVIDER_ENTRY_ID].rowHeight
	HEADER_ENTRY_HEIGHT = XMLrowTemplatesToUse[HEADER_ENTRY_ID].rowHeight
	ICON_PADDING = SCROLLABLE_ENTRY_TEMPLATE_HEIGHT
end

-- Add the MenuItems to the list (also for submenu lists!)
function ScrollableDropdownHelper:AddMenuItems()
	--local combobox = self.combobox
	local dropdown = self.dropdown

	local dividers = 0
	local headers = 0
	local maxWidth = 0
	local anchorOffset = -5
	local dividerOffset = 0
	local headerOffset = 0
	local largestEntryWidth = 0

	-- Clear the indices of saved headers and dividers
	rowIndex[DIVIDER_ENTRY_ID] = {}
	rowIndex[HEADER_ENTRY_ID] = {}
	
	-- NOTE: the whole reason we need to override it completely, to add our divider and header data entry
	--> item should be the data table of the sortedItems -> means each entry in table which got added with comboBox:AddItems(table)
	local function createEntry(self, item, index, isLast)
		item.m_index = index
		item.m_owner = self

		local isHeader = getValueOrCallback(item.isHeader, item)
		local isCheckbox = getValueOrCallback(item.isCheckbox, item)
		--local isCheckboxChecked = GetValueOrCallback(item.checked, item)
		--local icon = GetValueOrCallback(item.icon, item)

		local hasSubmenu = item.entries ~= nil

		local entryType = (item.name == lib.DIVIDER and DIVIDER_ENTRY_ID) or (isCheckbox and CHECKBOX_ENTRY_ID) or (isHeader and HEADER_ENTRY_ID) or
				(hasSubmenu and SUBMENU_ENTRY_ID) or (isLast and LAST_ENTRY_ID) or ENTRY_ID
		if hasSubmenu then
			item.hasSubmenu = true
			item.isNew = areAnyEntriesNew(item)
		end

		--Save divider and header entries' indices for later usage at the height calulation
		if rowIndex[entryType] ~= nil then
			tins(rowIndex[entryType], index)
		end
		
		return ZO_ScrollList_CreateDataEntry(entryType, item)
	end

	ZO_ScrollList_Clear(dropdown.m_scroll)

	local dataList = ZO_ScrollList_GetDataList(dropdown.m_scroll)

	--Got passed in via comboBox:AddItems(table)
	local visibleItems = #dropdown.m_sortedItems
	for i = 1, visibleItems do
		local item = dropdown.m_sortedItems[i]
		local entry = createEntry(dropdown, item, i, i == visibleItems)
		tins(dataList, entry)

		-- Here the width is calculated while the list is being populated. 
		-- It also makes it so the for loop on m_sortedItems is not done more than once per run
		-- Also detect the totla number of dividers and headers in the list (not only the currntly shown ones!)
		maxWidth, dividers, headers = self:GetMaxWidth(item, maxWidth, dividers, headers)
		if maxWidth > largestEntryWidth then
			largestEntryWidth = maxWidth
		end
	end
	--Visible rows of the main menu, or if a submenu: Read from mainMenu's owner data's scrollhelper
	local visibleRows =  (self.isSubMenuScrollHelper and
			(lib.submenu and lib.submenu.parentScrollableDropdownHelper and lib.submenu.parentScrollableDropdownHelper.visibleRowsSubmenu)) or self.visibleRows

	-- using the exact width of the text can leave us with pixel rounding issues
	-- so just add 5 to make sure we don't truncate at certain screen sizes
	largestEntryWidth = largestEntryWidth + 5

	if(visibleItems > visibleRows - 1) then
		largestEntryWidth = largestEntryWidth + ZO_SCROLL_BAR_WIDTH
		anchorOffset = -ZO_SCROLL_BAR_WIDTH
		visibleItems = visibleRows
		
		--Get the currently visible headers and dividers, within the visible number of rows.
		local visibleHeaders, visibleDividers = getVisibleHeadersAndDivider(visibleItems)
		headerOffset = visibleHeaders * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - HEADER_ENTRY_HEIGHT)
		dividerOffset = visibleDividers * (DIVIDER_ENTRY_HEIGHT + 2)
	else -- account for divider height difference when we shrink the height
		local visibleHeaders, visibleDividers = getVisibleHeadersAndDivider(visibleItems)
		dividerOffset = visibleDividers * ( -(SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - DIVIDER_ENTRY_HEIGHT))
		headerOffset = visibleHeaders * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - HEADER_ENTRY_HEIGHT)
	end

	-- Allow the dropdown to automatically widen to fit the widest entry, but
	-- prevent it from getting any skinnier than the container's initial width
	local totalDropDownWidth = largestEntryWidth + (ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2) + ZO_SCROLL_BAR_WIDTH

	if totalDropDownWidth > dropdown.m_containerWidth then
		dropdown.m_dropdown:SetWidth(totalDropDownWidth)
	else
		dropdown.m_dropdown:SetWidth(dropdown.m_containerWidth)
	end

	local scroll = dropdown.m_dropdown:GetNamedChild("Scroll")
	local scrollContent = scroll:GetNamedChild("Contents")
	-- Shift right edge of container over to compensate for with/without scroll-bars
	scrollContent:ClearAnchors()
	scrollContent:SetAnchor(TOPLEFT)
	scrollContent:SetAnchor(BOTTOMRIGHT, nil, nil, anchorOffset)

	-- get the height of all the entries we are going to show
	if visibleItems > MAX_MENU_ROWS then
		visibleItems = MAX_MENU_ROWS
	end
	
	local firstRowPadding = (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2) + 8
	--local desiredHeight = dropdown:GetEntryTemplateHeightWithSpacing() * (visibleItems - 1) + SCROLLABLE_ENTRY_TEMPLATE_HEIGHT + firstRowPadding - (dividerOffset + headerOffset)
	local desiredHeight = dropdown:GetEntryTemplateHeightWithSpacing() * (visibleItems - 1) + SCROLLABLE_ENTRY_TEMPLATE_HEIGHT + firstRowPadding - headerOffset + dividerOffset

	dropdown.m_dropdown:SetHeight(desiredHeight)
	ZO_ScrollList_SetHeight(dropdown.m_scroll, desiredHeight)

	ZO_ScrollList_Commit(dropdown.m_scroll)
end

function ScrollableDropdownHelper:GetMaxWidth(item, maxWidth, dividers, headers)
	local fontObject = _G[item.m_owner.m_font]
	
	if item.name == lib.DIVIDER then
		dividers = dividers + 1
	elseif item.isHeader then
		headers = headers + 1
	end
	
	local labelStr = item.name
	if item.label ~= nil then
		labelStr = getValueOrCallback(item.label, item)
	end
	
	local submenuEntryPadding = item.hasSubmenu and SCROLLABLE_ENTRY_TEMPLATE_HEIGHT or 0
	local iconPadding = (item.icon ~= nil or item.isNew == true) and ICON_PADDING or 0 -- NO_ICON_PADDING
	local width = GetStringWidthScaled(fontObject, labelStr, 1, SPACE_INTERFACE) + iconPadding + submenuEntryPadding
	
	-- MAX_MENU_WIDTH is to set a cap on how wide text can make a menu. Don't want a menu being 2934 pixels wide.
	width = zo_min(MAX_MENU_WIDTH, width)
	if (width > maxWidth) then
		maxWidth = width
	--	d( sfor('maxWidth = %s', width))
	end
	
	return maxWidth, dividers, headers
end

function ScrollableDropdownHelper:DoHide()
	local dropdown = self.dropdown
	if dropdown:IsDropdownVisible() then
		dropdown:HideDropdown()
	end
end

function ScrollableDropdownHelper:OnHide(isOnEffectivelyHiddenCall)
	isOnEffectivelyHiddenCall = isOnEffectivelyHiddenCall or false

	local dropdown = self.dropdown
	if dropdown.m_lastParent then
		dropdown.m_dropdown:SetParent(dropdown.m_lastParent)
		dropdown.m_lastParent = nil
	end

	local isSubmenu
	if not not isOnEffectivelyHiddenCall then
		isSubmenu = self.isSubMenuScrollHelper
		if not isSubmenu then
--d("lib:FireCallbacks('MenuOnHide)")
			self:Narrate("OnMenuHide", self.control, nil, nil)
			lib:FireCallbacks('MenuOnHide', self)
			isSubmenu = false
		end
	else
		isSubmenu = false
	end

	if self.parent ~= nil then -- submenus won't have a parent for their scroll helper
		--Fires SubmenuOnHide callback
		lib.submenu:Clear(isSubmenu)
	end
end

function ScrollableDropdownHelper:OnShow()
	local dropdown = self.dropdown
	-- This is the culprit in the parent dropdown being stuck on the first opened
	if dropdown.m_lastParent ~= ZO_Menus then
		dropdown.m_lastParent = dropdown.m_dropdown:GetParent()
		dropdown.m_dropdown:SetParent(ZO_Menus)
		ZO_Menus:BringWindowToTop()

		if not self.isSubMenuScrollHelper then
			--d("lib:FireCallbacks('MenuOnShow)")
			self:Narrate("OnMenuShow", self.control, nil, nil)
			lib:FireCallbacks('MenuOnShow', self)
		end
	end
end

local function hideTooltip()
	ClearTooltip(InformationTooltip)
end

local function showTooltip(control, data, wasDelayed)
	lib.lastCustomTooltipControl = nil
	--Was the call delayed by 1 frame? Check if the tooltip should still be shown. Maybe OnMouseExit already fired before
	if wasDelayed == true then
		if not control.showTooltip then return end
	end

	local customTooltipFunc = data.customTooltip
	if type(customTooltipFunc) == "function" then
		local SHOW = true
		lib.lastCustomTooltipControl = customTooltipFunc(data, control, SHOW)
	else
		local tooltipData = getValueOrCallback(data.tooltip, data)
		if tooltipData ~= nil then
			local parent = control
			local anchor = defaultTooltipAnchor
			--Is a submenu's combobox shown meanwhile (see ScrollableSubmenu:Show(...))
			if control.m_active ~= nil then
				parent = control.m_active.m_comboBox.m_dropdown
				local anchorPoint = select(2,parent:GetAnchor())
				local anchorPointNew = anchorPoint + 3
				local offsetX = ((anchorPointNew == TOPLEFT or anchorPointNew == LEFT or anchorPointNew == BOTTOMLEFT) and 15) or -15
				anchor = {anchorPointNew, offsetX, -10, anchorPoint} --anchor right if anchor of parent was left, and vice versa
			end
			InitializeTooltip(InformationTooltip, parent, unpack(anchor))
			SetTooltipText(InformationTooltip, getValueOrCallback(tooltipData, data))
			InformationTooltipTopLevel:BringWindowToTop()
		end
	end
end

function ScrollableDropdownHelper:OnMouseEnter(control)
	-- show tooltip
	local data = ZO_ScrollList_GetData(control)
	if data == nil then return end

	if data.disabled then
		return true
	end

	if data.hasSubmenu == true then
		control.showTooltip = true
		zo_callLater(function()
			showTooltip(control, data, true)
		end, 0) --call 1 frame later so that the tooltip can find the submenu control created and properly anchor to it
	else
		showTooltip(control, data, false)
	end
end

function ScrollableDropdownHelper:OnMouseExit(control)
	control.showTooltip = nil
	-- hide tooltip
	local data = ZO_ScrollList_GetData(control)
	if data == nil then return end

	if data.disabled then
		return true
	end

	local customTooltipFunc = data.customTooltip
	if type(customTooltipFunc) == "function" then
		local HIDE = false
		customTooltipFunc(data, control, HIDE)
		lib.lastCustomTooltipControl = nil
	else
		hideTooltip()
	end
end

--[[
function ScrollableDropdownHelper:SetSpacing(spacing) -- TODO: remove it not used
	local dropdown = self.dropdown
    ZO_ComboBox.SetSpacing(dropdown, spacing)

    local newHeight = dropdown:GetEntryTemplateHeightWithSpacing()
    ZO_ScrollList_UpdateDataTypeHeight(dropdown.m_scroll, ENTRY_ID, newHeight)
    ZO_ScrollList_UpdateDataTypeHeight(dropdown.m_scroll, DIVIDER_ENTRY_ID, 2)
    ZO_ScrollList_UpdateDataTypeHeight(dropdown.m_scroll, HEADER_ENTRY_ID, HEADER_ENTRY_HEIGHT)
end
]]

function ScrollableDropdownHelper:InitContextMenuValues()
	self.options = defaultContextMenuOptions
	self.customContextMenuEntries = {}
	self:ClearDropdownEntries()
end

function ScrollableDropdownHelper:ClearDropdownEntries()
	self.dropdown:ClearItems()
end

function ScrollableDropdownHelper:UpdateDropdownEntries(entries)
	if ZO_IsTableEmpty(entries) then return end
	self:ClearDropdownEntries()
	self.dropdown:AddItems(entries)
end

function ScrollableDropdownHelper:SetContextMenuItems(entries)
	self.customContextMenuEntries = entries
end

function ScrollableDropdownHelper:GetContextMenuItems()
	return self.customContextMenuEntries
end

function ScrollableDropdownHelper:AddContextMenuItem(entry)
	if entry == nil then return end
	table.insert(self.customContextMenuEntries, entry)
end


function ScrollableDropdownHelper:GetOptions()
	return self.options
end

function ScrollableDropdownHelper:UpdateOptions(options)
	local emptyOptions = false
	if options == nil then
		emptyOptions = true
		options = {}
	end
	if self.options ~= nil then
		if not emptyOptions then
			mergeTable(self.options, options)
		end
	end

	local control = self.control

	--Read the passed in options table
	local visibleRows, visibleRowsSubmenu, sortsItems, narrateData
	if options ~= nil then
		if type(options) == "table" then
			visibleRows = 			getValueOrCallback(options.visibleRowsDropdown, options)
			visibleRowsSubmenu = 	getValueOrCallback(options.visibleRowsSubmenu, options)
			sortsItems = 			getValueOrCallback(options.sortEntries, options)
			narrateData = 			getValueOrCallback(options.narrate, options)
			self.narrateData = narrateData

			control.options = options
			control.narrateData = narrateData
			self.options = options
		else
			--Backwards compatibility with AddOns using older library version ScrollableDropdownHelper:Initialize where options was the visibleRows directly
			visibleRows = options
		end
	end

	visibleRows = visibleRows or DEFAULT_VISIBLE_ROWS
	visibleRowsSubmenu = visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS
	self.visibleRows = visibleRows					--Will be nil for a submenu!
	self.visibleRowsSubmenu = visibleRowsSubmenu

	if sortsItems == nil then sortsItems = DEFAULT_SORTS_ENTRIES end
	self.sortsItems = sortsItems

	local combobox = control.combobox
	combobox.m_comboBox:SetSortsItems(self.sortsItems)

	self.options = options
	self.control.options = options
end


function ScrollableDropdownHelper:UpdateIcons(data)
	local isNewValue = getValueOrCallback(data.isNew, data)
	local iconData = getValueOrCallback(data.icon, data)
	--If only a "any.dds" texture was passed in
	if type(iconData) ~= 'table' then
		iconData = { iconTexture = iconData }
	end
	local iconValue = iconData ~= nil and getValueOrCallback(iconData.iconTexture, data)
	local visible = isNewValue == true or iconValue ~= nil

	local tooltipForIcon = getValueOrCallback(iconData.tooltip, data)
	local iconNarration = visible and iconData.iconNarration

	local multiIconContainerCtrl = self.m_iconContainer
	local multiIconCtrl = self.m_icon

	local parentHeight = multiIconCtrl:GetParent():GetHeight()
	local iconHeight = parentHeight
	-- This leaves a padding to keep the label from being too close to the edge
	local iconWidth = visible and iconHeight or WITHOUT_ICON_LABEL_DEFAULT_OFFSETX


	multiIconCtrl:ClearIcons()
	if visible == true then
		self.m_icon.data = self.m_icon.data or {}

		--Icon's height and width
		if iconData.width ~= nil then
			iconWidth = zo_clamp(getValueOrCallback(iconData.width, data), WITHOUT_ICON_LABEL_DEFAULT_OFFSETX, parentHeight)
		end
		if iconData.height ~= nil then
			iconHeight = zo_clamp(getValueOrCallback(iconData.height, data), WITHOUT_ICON_LABEL_DEFAULT_OFFSETX, parentHeight)
		end
		--Icon's color
		local iconTint = getValueOrCallback(iconData.iconTint, data)
		if type(iconTint) == "string" then
			local iconColorDef = ZO_ColorDef:New(iconTint)
			iconTint = iconColorDef
		end
		--Icon's tooltip? Reusing default tooltip functions of controls: ZO_Options_OnMouseEnter and ZO_Options_OnMouseExit
		multiIconCtrl.data.tooltipText = nil
		if tooltipForIcon ~= nil and tooltipForIcon ~= "" then
			multiIconCtrl.data.tooltipText = tooltipForIcon
		end

		--Icon's narration=
		iconNarration = getValueOrCallback(iconData.iconNarration, data)

		if isNewValue == true then
			multiIconCtrl:AddIcon(iconNewIcon, nil, iconNarrationNewValue)
		end
		if iconValue ~= nil then
			multiIconCtrl:AddIcon(iconValue, iconTint, iconNarration)
		end

		multiIconCtrl:SetHandler("OnMouseEnter", function(...)
			ZO_Options_OnMouseEnter(...)
			InformationTooltipTopLevel:BringWindowToTop()
		end)
		multiIconCtrl:SetHandler("OnMouseExit", ZO_Options_OnMouseExit)

		multiIconCtrl:Show()
	end
	multiIconCtrl:SetMouseEnabled(tooltipForIcon ~= nil)
	multiIconCtrl:SetDrawTier(DT_MEDIUM)
	multiIconCtrl:SetDrawLayer(DL_CONTROLS)
	multiIconCtrl:SetDrawLevel(10)

	-- Using the control also as a padding. if no icon then shrink it
	-- This also allows for keeping the icon in size with the row height.
	multiIconContainerCtrl:SetDimensions(iconWidth, iconHeight)
	multiIconCtrl:SetDimensions(iconWidth, iconHeight)
	multiIconCtrl:SetHidden(not visible)
end

--Narration
function ScrollableDropdownHelper:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	local narrateData = self.narrateData
--d("[LSM]Narrate-"..tos(eventName) .. ", narrateData: " ..tos(narrateData))
	if eventName == nil or isAccessibilityUIReaderEnabled() == false or narrateData == nil then return end
	local narrateCallbackFuncForEvent = narrateData[eventName]
	if narrateCallbackFuncForEvent == nil or type(narrateCallbackFuncForEvent) ~= "function" then return end

	local eventCallbackFunctionsSignatures = {
		["OnDropdownMouseEnter"] = function() return self, ctrl end,
		["OnDropdownMouseExit"] =  function() return self, ctrl end,
		["OnMenuShow"]           = function() return self, ctrl end,
		["OnMenuHide"]           = function() return self, ctrl end,
		["OnSubMenuShow"]        = function() return self, ctrl, anchorPoint end,
		["OnSubMenuHide"]        = function() return self, ctrl end,
		["OnEntryMouseEnter"]    = function() return self, ctrl, data, hasSubmenu end,
		["OnEntryMouseExit"]     = function() return self, ctrl, data, hasSubmenu end,
		["OnEntrySelected"]      = function() return self, ctrl, data, hasSubmenu end,
		["OnCheckboxUpdated"]    = function() return self, ctrl, data end,
	}
	--Create a table with the callback functions parameters
	local callbackParams = { eventCallbackFunctionsSignatures[eventName]() }
	--Pass in the callback params to the narrateFunction
	local narrateText, stopCurrent = narrateCallbackFuncForEvent(unpack(callbackParams))

--d(">NarrateText: " ..tos(narrateText) .. ", stopCurrent: " ..tos(stopCurrent))
	--Didn't the addon take care of the narration itsself? So this library here should narrate the text returned
	if type(narrateText) == "string" then
		local narrateFuncOfLibrary = narrationEventToLibraryNarrateFunction[eventName]
		if narrateFuncOfLibrary == nil then return end
		narrateFuncOfLibrary(narrateText, stopCurrent)
	end
end

--------------------------------------------------------------------
-- ScrollableSubmenu
--------------------------------------------------------------------
local submenus = {}
local ScrollableSubmenu = ZO_InitializingObject:Subclass()

local function getScrollableSubmenu(depth)
	if depth > #submenus then
		tins(submenus, ScrollableSubmenu:New(depth))
	end
	return submenus[depth]
end

-- ScrollableSubmenu:New

function ScrollableSubmenu:Initialize(submenuDepth)
	self.isShown = false

	local submenuControl = WINDOW_MANAGER:CreateControlFromVirtual(ROOT_PREFIX..submenuDepth, ZO_Menus, 'LibScrollableMenu_ComboBox')
	submenuControl:SetHidden(true)
	submenuControl:SetHandler("OnHide", function(control)
		clearTimeout()
		self:Clear()
	end)
	submenuControl:SetDrawLevel(ZO_Menu:GetDrawLevel() + submenuDepth)
	--submenuControl:SetExcludeFromResizeToFitExtents(true)
	
	local scrollableDropdown = submenuControl:GetNamedChild('Dropdown')
	self.combobox = scrollableDropdown

	self.dropdown = ZO_ComboBox_ObjectFromContainer(scrollableDropdown)
	self.dropdown.m_submenu = self

	self.dropdown.SetSelected = function(dropdown, index, ignoreCallback)
		local parentDropdown = lib.submenu.owner.m_comboBox
		parentDropdown:ItemSelectedClickHelper(dropdown.m_sortedItems[index])
		parentDropdown:HideDropdown()
	end

	-- nesting
	self.depth = submenuDepth
	self.parentMenu = getScrollableSubmenu(submenuDepth - 1)
	if self.parentMenu then
		self.parentMenu.childMenu = self
	end

	-- for easier access
	self.control = submenuControl
	self.control.dropdown = self.dropdown
	self.control.combobox = scrollableDropdown

	--don't need parent for this / leave visibleRows nil (defualt 10 will be used) / only use visibleSubmenuRows = 10 as default
	-->visibleSubmenuRows will be overwritten at ScrollableSubmenu:Show -> taken from parent's ScrollableDropdownHelper dropdown.visibleRowsSubMenu
	self.scrollHelper = ScrollableDropdownHelper:New(nil, self.control, nil, true)

	--self.scrollHelper.OnShow = function() end
	self.control.scrollHelper = self.scrollHelper
	self.control.submenu = self
end

function ScrollableSubmenu:AddItem(...)
	self.dropdown:AddItem(...)
end

function ScrollableSubmenu:AddItems(entries)
	self:ClearItems()
	for i = 1, #entries do
		self:AddItem(entries[i], ZO_COMBOBOX_SUPRESS_UPDATE)
	end
end

function ScrollableSubmenu:AnchorToControl(parentControl)
	local myControl = self.control.dropdown.m_dropdown
	myControl:ClearAnchors()

	local parentDropdown = self:GetOwner().m_comboBox.m_dropdown

	local anchorPoint = LEFT
	local anchorOffset = -3
	local anchorOffsetY = -7 --Move the submenu a bit up so it's 1st row is even with the main menu's row having/showing this submenu

	if self.parentMenu then
		anchorPoint = self.parentMenu.anchorPoint
	elseif (parentControl:GetRight() + myControl:GetWidth()) < GuiRoot:GetRight() then
		anchorPoint = RIGHT
	end

	if anchorPoint == RIGHT then
		anchorOffset = 3 + parentDropdown:GetWidth() - parentControl:GetWidth() - PADDING * 2
	end

	myControl:SetAnchor(TOP + (10 - anchorPoint), parentControl, TOP + anchorPoint, anchorOffset, anchorOffsetY)
	self.anchorPoint = anchorPoint
	myControl:SetHidden(false)
end

function ScrollableSubmenu:Clear(doFireCallback)
	if self.isShown == true then
--d("lib:FireCallbacks('SubmenuOnHide)")
		self.scrollHelper:Narrate("OnSubMenuHide", self.dropdown, nil, nil)
		lib:FireCallbacks('SubmenuOnHide', self)
	end

	self:ClearItems()
	self:SetOwner(nil)
	self.control:SetHidden(true)
	self:ClearChild()

	self.isShown = false
end

function ScrollableSubmenu:ClearChild()
	if self.childMenu then
		self.childMenu:Clear()
	end
end

function ScrollableSubmenu:ClearItems()
	self.dropdown:ClearItems()
end

function ScrollableSubmenu:GetChild(canCreate)
	if not self.childMenu and canCreate then
		self.childMenu = getScrollableSubmenu(self.depth + 1)
	end
	return self.childMenu
end

function ScrollableSubmenu:GetOwner(topmost)
	if topmost and self.parentMenu then
		return self.parentMenu:GetOwner(topmost)
	else
		return self.owner
	end
end

function ScrollableSubmenu:IsVisible()
	return not self.control:IsControlHidden()
end

function ScrollableSubmenu:SetOwner(owner) --owner is container for dropdown, use owner.m_comboBox for the object
		if self.owner then
			--self.control.dropdown.m_dropdown:SetParent(Z)
			self.owner = nil
		end
		if owner then
			if self == lib.submenu then
				--self.control:SetParent(owner)
				--self.control.dropdown.m_dropdown:SetParent(owner.m_comboBox.m_dropdown)
			end
			self.owner = owner
		end
end

function ScrollableSubmenu:Show(parentControl) -- parentControl is a row within another combobox's dropdown scrollable list
	local owner = getContainerFromControl(parentControl)
	self:SetOwner(owner)

	parentControl.m_owner.m_dropdown:SetDrawTier(DT_MEDIUM)
	--Get the owner's (ComboBox control) ScrollableDropdownHelper object and the visibleSubmenuRows attribute, and update this
	--ScrollableSubmenu's ScrollableDropdownHelper object with this owner data, as attribute .parentScrollableDropdownHelper
	self.parentScrollableDropdownHelper = owner and owner.parentScrollableDropdownHelper
	--Take over options from the owner scrollhelper
	-->Narration
	if self.parentScrollableDropdownHelper ~= nil then
		self.scrollHelper.narrateData = self.parentScrollableDropdownHelper.narrateData
	end

	local data = ZO_ScrollList_GetData(parentControl)
	self:AddItems(getValueOrCallback(data.entries, data)) -- "self:GetOwner(TOP_MOST)", remove TOP_MOST if we want to pass the parent submenu control instead
	ZO_Scroll_ResetToTop(self.dropdown.m_scroll)

	self:AnchorToControl(parentControl)

	self:ClearChild()
	self.dropdown:ShowDropdownOnMouseUp() --show the submenu's ScrollableDropdownHelper comboBox entries -> Calls self.dropdown:AddMenuItems()

	-- This gives us a parent submenu to all entries
	-- entry.m_owner.m_submenu.m_parent
	self.m_parent = parentControl

	parentControl.m_active = self.combobox
	self.isShown = true
--d("lib:FireCallbacks('SubmenuOnShow)")
	self.scrollHelper:Narrate("OnSubMenuShow", parentControl, nil, nil, self.anchorPoint)
	lib:FireCallbacks('SubmenuOnShow', self)

	return true
end



--------------------------------------------------------------------
-- Custom scrollable menu combobox
--------------------------------------------------------------------
local function createNewCustomScrollableComboBox()
d("[LSM]createNewCustomScrollableComboBox")
	if customScrollableMenuComboBox ~= nil then return end
	customScrollableMenuComboBox = WINDOW_MANAGER:CreateControlFromVirtual(CUSTOM_SCROLLABLE_MENU_NAME, ZO_Menus, 'LibScrollableMenu_CustomContextMenu_ComboBox')
	customScrollableMenuComboBox:SetHidden(true)
end


--------------------------------------------------------------------
-- Public API functions
--------------------------------------------------------------------
lib.persistentMenus = false -- controls if submenus are closed shortly after the mouse exists them
function lib.GetPersistentMenus()
	return lib.persistentMenus
end
function lib.SetPersistentMenus(persistent)
	lib.persistentMenus = persistent
end

lib.MapEntries = mapEntries


--[Custom scrollable ZO_ComboBox menu]
----------------------------------------------------------------------
--Adds a scroll helper to the comboBoxControl dropdown entries, and enables submenus (scollable too) at the entries.
--	control parent 							Must be the parent control of the comboBox
--	control comboBoxControl 				Must be any ZO_ComboBox control (e.g. created from virtual template ZO_ComboBox)
 --  table options:optional = {
 --		number visibleRowsDropdown:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened dropdown
 --		number visibleRowsSubmenu:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened submenus
 --		boolean sortEntries:optional			Boolean or function returning boolean if items in the main-/submenu should be sorted alphabetically
--		table	XMLRowTemplates:optional		Table or function returning a table with key = row type of lib.scrollListRowTypes and the value = subtable having
--												"template" String = XMLVirtualTemplateName, rowHeight number = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,setupFunc = function(control, data, list) end
--												-->See local table "defaultXMLTemplates" in LibScrollableMenu
--												-->Attention: If you do not specify all template attributes, the non-specified will be mixedIn from defaultXMLTemplates[entryType_ID] again!
--		{
--			[lib.scrollListRowTypes.ENTRY_ID] = 		{ template = "XMLVirtualTemplateRow_ForEntryId", ... }
--			[lib.scrollListRowTypes.SUBMENU_ENTRY_ID] = { template = "XMLVirtualTemplateRow_ForSubmenuEntryId", ... },
--			...
--		}
--		table	narrate:optional				Table or function returning a table with key = narration event and value = function called for that narration event.
--												Each functions signature/parameters is shown below!
--												-> The function either builds your narrateString and narrates it in your addon.
--												   Or you must return a string as 1st return param (and optionally a boolean "stopCurrentNarration" as 2nd return param. If this is nil it will be set to false!)
--												    and let the library here narrate it for you via the UI narration
--												Optional narration events can be:
--												"OnDropdownMouseEnter" 	function(scrollhelperObject, dropdownControl)  Build your narrateString and narrate it now, or return a string and let the library narrate it for you end
--												"OnDropdownMouseExit"	function(scrollhelperObject, dropdownControl) end
--												"OnMenuShow"			function(scrollhelperObject, dropdownControl, nil, nil) end
--												"OnMenuHide"			function(scrollhelperObject, dropdownControl) end
--												"OnSubMenuShow"			function(scrollhelperObject, parentControl, anchorPoint) end
--												"OnSubMenuHide"			function(scrollhelperObject, parentControl) end
--												"OnEntryMouseEnter"		function(scrollhelperObject, entryControl, data, hasSubmenu) end
--												"OnEntryMouseExit"		function(scrollhelperObject, entryControl, data, hasSubmenu) end
--												"OnEntrySelected"		function(scrollhelperObject, entryControl, data, hasSubmenu) end
--												"OnCheckboxUpdated"		function(scrollhelperObject, checkboxControl, data) end
--			Example:	narrate = { ["OnDropdownMouseEnter"] = myAddonsNarrateDropdownOnMouseEnter, ... }
--  }

function AddCustomScrollableComboBoxDropdownMenu(parent, comboBoxControl, options)
	assert(parent ~= nil and comboBoxControl ~= nil, MAJOR .. " - AddCustomScrollableComboBoxDropdownMenu ERROR: Parameters parent and comboBoxControl must be provided!")

	if comboBoxControl.combobox == nil then
		comboBoxControl.combobox = comboBoxControl
	end
	if comboBoxControl.dropdown == nil then
		comboBoxControl.dropdown = ZO_ComboBox_ObjectFromContainer(comboBoxControl)
	end
	
--	d( parent:GetName())
	
	--Add a new scrollable menu helper
	return ScrollableDropdownHelper:New(parent, comboBoxControl, options, false)
end
local addCustomScrollableComboBoxDropdownMenu = AddCustomScrollableComboBoxDropdownMenu



--[Custom scrollable context menu at any control]
----------------------------------------------------------------------
local ENTRY_TYPE_HEADER = 1
local ENTRY_TYPE_CHECKBOX = 2

local mouseUpRefCounts = {}
local function onGlobalMouseUp()
    local refCount = mouseUpRefCounts[customScrollableMenuComboBox]
d("[LSM]OnGlobalMouseUp-refCount: " ..tos(refCount))
    if refCount ~= nil then
        local moc = moc()
		local parent = customScrollableMenuComboBox:GetParent()
		-- moc:GetOwningWindow() ~= ZO_Menus to subtract 1 on click outside of ZO_Menus
		-- moc == parent to subtract 1 on show.
		-- moc ~= parent to subtract 1 on click in ZO_Menus but not over same row.
		
        if moc:GetOwningWindow() ~= ZO_Menus or moc == parent or moc ~= parent then
            refCount = refCount - 1
            mouseUpRefCounts[customScrollableMenuComboBox] = refCount
            if refCount <= 0 then
                HideCustomScrollableMenu()
            end
        end
    end
end

--Add a scrollable menu to any control (not only a ZO_ComboBox), e.g. to an inventory row

local function initCustomScrollMenuControl(parent)
	if customScrollableMenuComboBox == nil then
		InitCustomScrollableMenu(parent)
	end
end

function ClearCustomScrollableMenu()
d("[LSM]ClearCustomScrollableMenu")
	if customScrollableMenuComboBox == nil then return end
	local scrollHelper = getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	scrollHelper:InitContextMenuValues()
end

function InitCustomScrollableMenu(parent)
	parent = parent or moc()
d("[LSM]InitCustomScrollableMenu-parent: " ..tos(parent:GetName()))
	if parent == nil then return end

	-- Initialize in one place. To simplify setup not depending on what method is used
	-->Creates one dummy ZO_ComboBox which can be used to show the context menu via it's "opened dropdown", and hiding the combobox borders etc. itsself
	createNewCustomScrollableComboBox()

	lib.customContextMenu = customScrollableMenuComboBox

	local scrollHelper = addCustomScrollableComboBoxDropdownMenu(parent, customScrollableMenuComboBox, customScrollableMenuComboBox.options)
	customScrollableMenuComboBox.scrollHelper = scrollHelper
	scrollHelper:InitContextMenuValues()
end

function AddCustomScrollableMenuEntry(text, callback, entryType, isNew, label)
	initCustomScrollMenuControl()

	local scrollHelper = getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	local options = scrollHelper:GetOptions()

	scrollHelper:AddContextMenuItem({
		isHeader		= entryType == ENTRY_TYPE_HEADER,
		isCheckbox		= entryType == ENTRY_TYPE_CHECKBOX,
		isNew        	= getValueOrCallback(isNew, options) or false,
		name            = getValueOrCallback(text, options),
		label			= getValueOrCallback(label, options),
		callback        = callback,
	})
end

function AddCustomScrollableMenu(parent, entries, options)
	local entryTableType = type(entries)
	assert(entryTableType == 'table' , sfor('[LibScrollableMenu:AddCustomScrollableMenu] table expected got entries = %s', tos(entryTableType)))

	-- the menu is only being added to the first parent
	--parent should be changed every time it's shown. so it can be the correct control even if from another addon
	initCustomScrollMenuControl(parent)
	local scrollHelper = getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	--Set the passed in entries to the internal tables
	-->Will be read at ShowCustomScrollableMenu then and add the entries to the dropdown of the ZO_ComboBox dummy
	if entries ~= nil then
		scrollHelper:SetContextMenuItems(entries)
	end
	if options ~= nil then
		scrollHelper:UpdateOptions(options)
	end
	return customScrollableMenuComboBox
end

function SetCustomScrollableMenuOptions(options)
d("[LMS]SetCustomScrollableMenuOptions")
	if customScrollableMenuComboBox == nil then return end
	local scrollHelper = getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	scrollHelper:UpdateOptions(options)
end

function ShowCustomScrollableMenu(controlToAnchorTo, point, relativePoint, offsetX, offsetY, options)
d("[LMS]ShowCustomScrollableMenu", customScrollableMenuComboBox ~= nil)
	EVENT_MANAGER:UnregisterForEvent(MAJOR .. "_OnGlobalMouseUp")
	if customScrollableMenuComboBox == nil then return end

	-----------------
	--Additional/changed options for this menu show were passed in?
	local scrollHelper = getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	if options ~= nil then
		scrollHelper:UpdateOptions(options)
	end
	--Add the items of internal table to the ZO_ComboBox dropdown's items
	 scrollHelper:UpdateDropdownEntries(scrollHelper:GetContextMenuItems())

	-----------------
	--Hide the ZO_ComboBox and only show it's dropdown -> opened. The dropdown is the "menu" then
	customScrollableMenuComboBox:SetHidden(true)
	customScrollableMenuComboBox.dropdown:ShowDropdownOnMouseUp()

	local dropdownCtrl = customScrollableMenuComboBox.dropdown.m_dropdown
	--Anchor to the current control below the mouse, or was a control passed in to anchor & parent to?
	local parent = controlToAnchorTo or moc()
d(">parent: " .. parent:GetName())
	customScrollableMenuComboBox:SetParent(parent)
	if controlToAnchorTo == nil then
		AnchorCustomContextMenuToMouse(dropdownCtrl)
	else
		point = point or LEFT
		relativePoint = relativePoint or RIGHT
		offsetX = offsetX or 0
		offsetY = offsetY or 0
		dropdownCtrl:ClearAnchors()
		dropdownCtrl:SetAnchor(point, controlToAnchorTo, relativePoint, offsetX, offsetY)
	end

	--Set to 2 so first global click (as the menu shows) will not directly close it again
    mouseUpRefCounts[customScrollableMenuComboBox] = 2
	--Register the event to check for any mouse down click, so the menu will close if anywhere clicked else than on a menu entry
	EVENT_MANAGER:RegisterForEvent(MAJOR .. "_OnGlobalMouseUp", EVENT_GLOBAL_MOUSE_UP, onGlobalMouseUp)
	return true
end

function HideCustomScrollableMenu()
d("[LSM]HideCustomScrollableMenu")
	EVENT_MANAGER:UnregisterForEvent(MAJOR .. "_OnGlobalMouseUp", EVENT_GLOBAL_MOUSE_UP)
	ClearCustomScrollableMenu()
	local scrollHelper = getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	scrollHelper:DoHide()
	mouseUpRefCounts[customScrollableMenuComboBox] = nil
	return true
end


--Custom tooltip function
--[[
Function to show or hide a custom tooltip control. Pass that in to the data table of any entry, via data.customTooltip!

Your function needs to create and show/hide that control, and populate the text etc to the control too!
Parameters:
-data The table with the current data of the rowControl
-rowControl The userdata of the control the tooltip should show about
-showOrHide boolean true to show, or hide to hide the tooltip

myAddon.customTooltipFunc(table data, userdata rowControl, boolean showOrHide)
e.g. data = { name="Test 1", label="Test", customTooltip=function(data, rowControl, showOrHide) ... end, ... }
]]


--------------------------------------------------------------------
-- XML functions
--------------------------------------------------------------------
-- This works up from the mouse-over entry's submenu up to the dropdown, 
-- as long as it does not run into a submenu still having a new entry.
local function updateSubmenuNewStatus(m_parent)
--	d( m_parent:GetName())
	-- reverse parse
	local result = false
	local data = m_parent.m_data
	local submenu = data.entries or {}
	
	-- We are only going to check the current submenu's entries, not recursively
	-- down from here since we are working our way up until we find a new entry.
	for k, subentry in pairs(submenu) do
		if subentry.entries == nil then
		end
		if getIsNew(subentry) then
			result = true
		end
	end
	
	--d( 'updateSubmenuNewStatus ' .. tos(result))
	
	data.isNew = result
	if not result then
--		d( '> m_parent.m_owner ' .. tos(m_parent.m_owner ~= nil))
		if m_parent.m_owner then
--	d( 'm_parent.m_owner.m_scroll ' .. tos(m_parent.m_owner.m_scroll:GetName()))
			ZO_ScrollList_RefreshVisible(m_parent.m_owner.m_scroll)
			
			if m_parent.m_owner.m_submenu then
				local m_submenu = m_parent.m_owner.m_submenu
--		d( '> m_submenu.m_parent ' .. tos(m_submenu.m_parent ~= nil))
				
				if m_submenu.m_parent then
					updateSubmenuNewStatus(m_submenu.m_parent)
				end
			end
		end
	end
end

local function clearNewStatus(entry, data)
	if data.isNew then
		if data.entries == nil then
			data.isNew = false
			-- Refresh mouse-over entry
			ZO_ScrollList_RefreshVisible(entry.m_owner.m_scroll)
			
			lib:FireCallbacks('NewStatusUpdated', data, entry)
			
			local m_submenu = entry.m_owner.m_submenu or {}-- entry.m_owner.m_submenu.m_parent
			
--		d( '> m_submenu.m_parent ' .. tos(m_submenu.m_parent ~= nil))
			if m_submenu.m_parent ~= nil then
				updateSubmenuNewStatus(m_submenu.m_parent)
			end
		end
	end
end

function LibScrollableMenu_Entry_OnMouseEnter(entry)
    if entry.m_owner and entry.selectible then
--d("LibScrollableMenu_Entry_OnMouseEnter")

		local data = ZO_ScrollList_GetData(entry)
		local hasSubmenu = entry.hasSubmenu or data.entries ~= nil

--d("lib:FireCallbacks('EntryOnMouseEnter)")
		local scrollHelper = getScrollHelperObjectFromControl(entry)
		scrollHelper:Narrate("OnEntryMouseEnter", entry, data, hasSubmenu)
		lib:FireCallbacks('EntryOnMouseEnter', data, entry)

		-- For submenus
		local mySubmenu = getSubmenuFromControl(entry)
		if hasSubmenu then
			entry.hasSubmenu = true
			clearTimeout()
			if mySubmenu then -- open next submenu (nested)
				local childMenu = mySubmenu:GetChild(true) -- create if needed
				if childMenu then
					childMenu:Show(entry)
				else
					lib.submenu:Show(entry)
				end
			else
				lib.submenu:Show(entry)
			end
		elseif mySubmenu then
			clearTimeout()
			mySubmenu:ClearChild()
		else
			lib.submenu:Clear(false)
		end
		
		-- Original
        ZO_ScrollList_MouseEnter(entry.m_owner.m_scroll, entry)
        entry.m_label:SetColor(entry.m_owner.m_highlightColor:UnpackRGBA())
        if entry.m_owner.onMouseEnterCallback then
            entry.m_owner:onMouseEnterCallback(entry)
        end
		
		-- I moved this to the bottom to see if any of the Clear*s had any effect on submenu data.
	--	d( 'LibScrollableMenu_Entry_OnMouseEnter ' .. tos(data.name))
		clearNewStatus(entry, data)
    end
end
local libMenuEntryOnMouseEnter = LibScrollableMenu_Entry_OnMouseEnter

local function onMouseExitTimeout()
	local control = moc()
	local name = control and control:GetName()
	if name and zo_strfind(name, ROOT_PREFIX) == 1 then
		--TODO: check for matching depth??
	else
		lib.submenu:Clear()
	end
end

function LibScrollableMenu_Entry_OnMouseExit(entry)
	-- Original
	if entry.m_owner then
--d("LibScrollableMenu_Entry_OnMouseExit")
		local data = ZO_ScrollList_GetData(entry)
		local hasSubmenu = entry.hasSubmenu or data.entries ~= nil

		--d("lib:FireCallbacks('EntryOnMouseExit)")
		local scrollHelper = getScrollHelperObjectFromControl(entry)
		scrollHelper:Narrate("OnEntryMouseExit", entry, data, hasSubmenu)
		lib:FireCallbacks('EntryOnMouseExit', data, entry)

		ZO_ScrollList_MouseExit(entry.m_owner.m_scroll, entry)
		entry.m_label:SetColor(entry.m_owner.m_normalColor:UnpackRGBA())
		if entry.m_owner.onMouseExitCallback then
			entry.m_owner:onMouseExitCallback(entry)
		end
	end
	
	if not lib.GetPersistentMenus() then
		setTimeout(onMouseExitTimeout)
	end
end

local function selectEntryAndResetLastSubmenuData(entry)
	playSelectedSoundCheck(entry)

	--Pass the entrie's text to the dropdown control's selectedItemText
	entry.m_owner:SetSelected(entry.m_data.m_index, ignoreCallback)
	lib.submenu.lastClickedEntryWithSubmenu = nil
end

function LibScrollableMenu_OnSelected(entry, button, upInside)
	--d(string.format('$s, buttonIndex = %s, upInside = %s', "LibScrollableMenu_OnSelected", tostring(button), tostring(upInside)))
	if entry.m_owner then -- id this really needed? It only fires from our xml. 
		-- also, what happens if an addon uses a different template. Hopefully they call this function in their OnMouseUp
		local data = ZO_ScrollList_GetData(entry)
		if data and upInside then
			if button == MOUSE_BUTTON_INDEX_LEFT then
				--d("LibScrollableMenu_OnSelected")
				local data = ZO_ScrollList_GetData(entry)
				local hasSubmenu = entry.hasSubmenu or data.entries ~= nil

				local scrollHelper = getScrollHelperObjectFromControl(entry)
				scrollHelper:Narrate("OnEntrySelected", entry, data, hasSubmenu)
				--d("lib:FireCallbacks('EntryOnSelected)")
				lib:FireCallbacks('EntryOnSelected', data, entry)

				local mySubmenu = getSubmenuFromControl(entry)
				--	d( data.entries)
				if hasSubmenu then
					entry.hasSubmenu = true
					--d(">menu entry with submenu - hasSubmenu: " ..tos(entry.hasSubmenu))
					--Save the current entry to lib.submenu.lastClickedEntryWithSubmenu
					lib.submenu.lastClickedEntryWithSubmenu = entry

					local targetSubmenu = lib.submenu
					if mySubmenu and mySubmenu.childMenu then
						--d(">childMenu")
						targetSubmenu = mySubmenu.childMenu
					end

					if targetSubmenu then
						if targetSubmenu:IsVisible() then
							--d(">targetSubMenu:IsVisible")
							targetSubmenu:Clear() -- need to clear it straight away, no timeout
						else
							--Has the entry a submenu but also a callback function: Do not show the submenu if you click the entry
							-->e.g. AddonSelector: Click main entry to select addon pack, instead of having to select the submenu entry
							if data.callback ~= nil then
								--Run the callback
								data.callback(entry)
								targetSubmenu:Clear()
								--Hide the dropdown
								local comboBox = getContainerFromControl(entry)
								if comboBox and comboBox.scrollHelper then
									comboBox.scrollHelper:DoHide()
								end
								
								selectEntryAndResetLastSubmenuData(entry)
								return
							end
							--Check if submenu should be shown/hidden
							libMenuEntryOnMouseEnter(entry)
						end
					end
					return true
				elseif data.checked ~= nil then
					playSelectedSoundCheck(entry)
					ZO_CheckButton_OnClicked(entry.m_checkbox)
					lib.submenu.lastClickedEntryWithSubmenu = nil
					return true
				else
					selectEntryAndResetLastSubmenuData(entry)
				end
			else -- right-click
				if data.contextMenuCallback  then
					data.contextMenuCallback (entry)
				end
			end
		end
	end
end


------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------
local function onAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
	setMaxMenuWidthAndRows()

	lib.submenu = getScrollableSubmenu(1)
	--hookScrollableEntry()

	--Other events
	EM:RegisterForEvent(lib.name, EVENT_SCREEN_RESIZED, setMaxMenuWidthAndRows)
end

EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
EM:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, onAddonLoaded)


------------------------------------------------------------------------------------------------------------------------
-- Global library reference
------------------------------------------------------------------------------------------------------------------------
LibScrollableMenu = lib
