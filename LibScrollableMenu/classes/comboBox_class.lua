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
local tos = tostring


--------------------------------------------------------------------
--Library classes
--------------------------------------------------------------------
local classes = lib.classes
local comboBox_base = classes.comboboxBaseClass


--------------------------------------------------------------------
--ZO_ComboBox function references
--------------------------------------------------------------------
local zo_comboBox_base_selectItem = ZO_ComboBox_Base.SelectItem


--------------------------------------------------------------------
--LSM library locals
--------------------------------------------------------------------
local constants = lib.constants
local entryTypeConstants = constants.entryTypes
local comboBoxConstants = constants.comboBox
local dropdownConstants = constants.dropdown
local comboBoxMappingConstants = comboBoxConstants.mapping
local comboBoxDefaults = comboBoxConstants.defaults
local comboBoxDefaultsContextualInitValues = comboBoxConstants.defaultsContextualInitValues
local dropdownDefaults = dropdownConstants.defaults


local LSMOptionsKeyToZO_ComboBoxOptionsKey = comboBoxMappingConstants.LSMOptionsKeyToZO_ComboBoxOptionsKey
local LSMOptionsToZO_ComboBoxOptionsCallbacks = comboBoxMappingConstants.LSMOptionsToZO_ComboBoxOptionsCallbacks


local libUtil = lib.Util
local getSavedVariable = libUtil.getSavedVariable
local updateSavedVariable = libUtil.updateSavedVariable

local getControlName = libUtil.getControlName
local getControlData = libUtil.getControlData
local getValueOrCallback = libUtil.getValueOrCallback
local mixinTableAndSkipExisting = libUtil.mixinTableAndSkipExisting
local hideContextMenu = libUtil.hideContextMenu
local checkIfHiddenForReasons = libUtil.checkIfHiddenForReasons
local getHeaderControl = libUtil.getHeaderControl
local refreshDropdownHeader = libUtil.refreshDropdownHeader
local recursiveMultiSelectSubmenuOpeningControlUpdate = libUtil.recursiveMultiSelectSubmenuOpeningControlUpdate
local playSelectedSoundCheck = libUtil.playSelectedSoundCheck

--------------------------------------------------------------------
-- local helper functions
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


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------
-- LSM ComboBox class definition
--------------------------------------------------------------------
local comboBoxClass = comboBox_base:Subclass()
classes.comboBoxClass = comboBoxClass


--------------------------------------------------------------------
--LSM combobox class
--------------------------------------------------------------------
-- comboBoxClass:New(To simplify locating the beginning of the class
function comboBoxClass:Initialize(parent, comboBoxContainer, options, depth, initExistingComboBox)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 126, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth)) end
	comboBoxContainer.m_comboBox = self

	--Set the self.default values
	self:SetDefaults()

	--Get the self.defaults values and reset to the default ZO_ComboBox variables (if needed)
	self:ResetToDefaults(initExistingComboBox)

	-- Add all comboBox defaults not present.
	self.m_name = comboBoxContainer:GetName()
	self.m_openDropdown = comboBoxContainer:GetNamedChild("OpenDropdown")
	self.m_containerWidth = comboBoxContainer:GetWidth() --this is the MaxWidth
	self.containerMinWidth = nil --Will be filled via comboBox_base:SetMinMaxWidth(minWidth, maxWidth), from comboBox_base:UpdateWidth()
	self.m_selectedItemText = comboBoxContainer:GetNamedChild("SelectedItemText")
	self.m_multiSelectItemData = {}
	comboBox_base.Initialize(self, parent, comboBoxContainer, options, depth, initExistingComboBox)

	return self
end

-- We need to integrate a supplied ZO_ComboBox (from other addons, via API functions of the library here) with the lib's functionality.
-- We do this by replacing the metatable of that other ZO_ComboBox with our LSM comboBoxClass.
function comboBoxClass:UpdateMetatable(parent, comboBoxContainer, options)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 137, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(options)) end

--d("comboBoxClass:UpdateMetatable")
	--Pass in our comboBoxClass to the ZO_ComboBox (to add new functionality and methods, submenus etc.)
	setmetatable(self, comboBoxClass)
	--Apply the XML template to the combobox container, so the OnMouse* events etc. for LSM trigger properly
	ApplyTemplateToControl(comboBoxContainer, 'LibScrollableMenu_ComboBox_Behavior')

	--Fire the OnDropdownMenuAdded callback where one can replace options in the options table
	lib:FireCallbacks('OnDropdownMenuAdded', self, options)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 138, tos(getControlName(self.m_container)), tos(options)) end

	self:Initialize(parent, comboBoxContainer, options, 1, true)
end


function comboBoxClass:GetUniqueName()
	return self.m_name
end

-- Changed to force updating items and, to set anchor since anchoring was removed from :Show() due to separate anchoring based on comboBox type. (comboBox to self /submenu to row/contextMenu to mouse)
function comboBoxClass:AddMenuItems()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 127) end
	self:UpdateItems()
	self.m_dropdownObject:AnchorToComboBox(self)
	self:Show()
end

-- [New functions]
function comboBoxClass:GetMaxRows()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 128, tos(self.visibleRows or dropdownDefaults.DEFAULT_VISIBLE_ROWS)) end
--d(debugPrefix .. "comboBoxClass:GetMaxRows - visibleRows: " ..tos(self.visibleRows))
	return self.visibleRows or dropdownDefaults.DEFAULT_VISIBLE_ROWS
end

function comboBoxClass:GetMenuPrefix()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 129) end
	return 'Menu'
end

function comboBoxClass:GetHiddenForReasons(button)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 130, tos(button)) end
--d("111111111111111 comboBoxClass:GetHiddenForReasons - button: " ..tos(button))
	local selfVar = self
	return function(owningWindow, mocCtrl, comboBox, entry) return checkIfHiddenForReasons(selfVar, button, false, owningWindow, mocCtrl, comboBox, entry) end
end


function comboBoxClass:HideDropdown()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 131) end
--d(debugPrefix .. "comboBoxClass:HideDropdown")
	-- Recursive through all open submenus and close them starting from last.
	hideContextMenu()
	return comboBox_base.HideDropdown(self)
end

function comboBoxClass:HideOnMouseEnter()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 132) end
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() and not self:IsMouseOverControl() then
		self.m_submenu:HideDropdown()
	end
end

function comboBoxClass:HideOnMouseExit(mocCtrl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 133) end
	if self.m_submenu and self.m_submenu:ShouldHideDropdown() then
--d(">submenu found, but mouse not over it! HideDropdown")
		self.m_submenu:HideDropdown()
		return true
	end
end

function comboBoxClass:IsFilterEnabled()
	local options = self:GetOptions()
	local enableFilter = (options and getValueOrCallback(options.enableFilter, options)) or false
--d(debugPrefix .. "comboBoxClass:IsFilterEnabled - enableFilter: " ..tos(enableFilter))
	if not enableFilter then
		self.filterString = ""
	else
		self.filterString = self.filterString or ""
	end

	--local retVar = #self.m_sortedItems > 1 and enableFilter or false
--d(">#sortedItems: " ..tos(#self.m_sortedItems) .. ",  isEnabled: " ..tos(retVar))
	--Only show the filter header if there is more than 1 entry
	return enableFilter
end

function comboBoxClass:SetFilterString(filterBox, newText)
	ZO_Tooltips_HideTextTooltip()
	self.filterString = (newText ~= nil and zo_strlower(newText)) or zo_strlower(filterBox:GetText())
	self:UpdateResults(true)
end

function comboBoxClass:SetDefaults()
	self.defaults = {}
	for k, v in pairs(comboBoxDefaults) do
		if v and self[k] ~= v then
			self.defaults[k] = v
		end
	end
end

--Reset internal default values like m_font or LSM defaults like visibleRowsDropdown
-->If called from init function of API AddCustomScrollableComboBoxDropdownMenu: Keep existing ZO default (or changed by addons) entries of the ZO_ComboBox and only reset missing ones
-->If called later from e.g. UpdateOptions function where options passed in are nil or empty: Reset all to LSM default values
--->In all cases the function comboBoxClass:UpdateOptions should update the options needed!
function comboBoxClass:ResetToDefaults(initExistingComboBox)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 134) end
--d(debugPrefix .. "comboBoxClass:ResetToDefaults - initExistingComboBox: " ..tos(initExistingComboBox))
	--Mixin comboBoxDefaults to self.defautls again
	local defaults = ZO_DeepTableCopy(comboBoxDefaults)
	zo_mixin(defaults, self.defaults)

	--Attention: zo_mixin overwrites the existing varibales like self.m_enableMultiSelect!
	--Do not do that if we come from API function AddCustomScrollableComboBoxDropdownMenu
	if initExistingComboBox == true then
--d(">mixing in self.visibleRows/defaults.visibleRows = " .. tos(self.visibleRows) .. "/" .. tos(defaults.visibleRows))
		-- do NOT overwrite existing ZO_ComboBox values with LSM defaults, but keep comboBox values that already exist
		-- (skip some values though, like "m_sortsItems", and use the default values of LSM here, if the current ZO_ComboBox value matches the "if" condition)
		--> They will either way be overwritten by self:UpdateOptions later, if necessary
		mixinTableAndSkipExisting(self, defaults, comboBoxDefaultsContextualInitValues, nil)
	else
--d(">overwriting! self.visibleRows/defaults.visibleRows = " .. tos(self.visibleRows) .. "/" .. tos(defaults.visibleRows))
		zo_mixin(self, defaults) -- overwrite existing ZO_ComboBox (self) values with LSM defaults
	end
--d(">>self.visibleRows: " .. tos(self.visibleRows))
	self:SetOptions(nil)
end

--Update the comboBox's attribute/functions with a value returned from the applied custom options of the LSM, or with
--ZO_ComboBox default options (set at self:ResetToDefaults())
function comboBoxClass:SetOption(LSMOptionsKey)
	--Old code: Updating comboBox[key] with the newValue
	--Get current value
	local currentZO_ComboBoxValueKey = LSMOptionsKeyToZO_ComboBoxOptionsKey[LSMOptionsKey]
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 135, tos(LSMOptionsKey), tos(currentZO_ComboBoxValueKey)) end
	if currentZO_ComboBoxValueKey == nil then return end
	local currentValue = self[currentZO_ComboBoxValueKey]

	--Get new value via options passed in
	local options = self:GetOptions()
	local newValue = options and getValueOrCallback(options[LSMOptionsKey], options) --read new value from the options (run function there or get the value)
	if newValue == nil then
--d(">LSMOptionsKey: " .. tos(LSMOptionsKey) .. " -> Is nil in options")
		newValue = currentValue
	end
	if newValue == nil then return end

	--Filling the self.updatedOptions table with values so they can be used in the callback functions (if any is given)
	--from table LSMOptionsToZO_ComboBoxOptionsCallbacks
	-->e.g. used for sortOrder and sortType
	self.updatedOptions[LSMOptionsKey] = newValue

	--Do we need to run a callback function to set the updated value?
	local setOptionFuncOrKey = LSMOptionsToZO_ComboBoxOptionsCallbacks[LSMOptionsKey]
	if type(setOptionFuncOrKey) == "function" then
		setOptionFuncOrKey(self, newValue)
	else
		self[currentZO_ComboBoxValueKey] = newValue
	end
end

function comboBoxClass:UpdateOptions(options, onInit, isContextMenu, initExistingComboBox)
	onInit = onInit or false
	local optionsChanged = self.optionsChanged

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 136, tos(options), tos(onInit), tos(optionsChanged)) end

--[[
	if isContextMenu then
		d("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
		d(debugPrefix .. "comboBoxClass:UpdateOptions - options: " ..tos(options) .. ", onInit: " .. tos(onInit) .. ", optionsChanged: " ..tos(optionsChanged))
	end
]]
	--Called from Initialization of the object -> self:ResetToDefaults() was called in comboBoxClass:Initialize() already
	-->And self:UpdateOptions() is then called via comboBox_base.Initialize(...), from where we get here
	if onInit == true then
--d(">1 onInit")
		--Do not change any other options, just init. the combobox -> call self:AddCustomEntryTemplates(options) and set
		--optionsChanged to false (self.options will be nil at that time)
		optionsChanged = false
	else
		--self.optionsChanged might have been set by contextMenuClass:SetOptions(options) already. Check that first and keep that boolean state as we
		--do not use self.options for the context menus, but self.contextMenuOptions here:
		--->Coming from contextMenuClass:ShowContextMenu() -> self.contextMenuOptions was set via contextMenuClass:SetOptions(options) before, and will be passed in here
		--->to UpdateOptions(options) as options parameter. self.optionsChanged will be true if the options changed at the contex menu (compared to old self.contextMenuOptions)
		---->self.contextMenuOptions is then used at OnShow of the context menu.
		--
		--For other "non-context menu" calls: Compare the already stored self.options table to the new passed in options table (both could be nil though)
		optionsChanged = optionsChanged or options ~= self.options
--d(">2 optionsChanged: " .. tos(optionsChanged))
	end

--[[
	if isContextMenu then
		d("> optionsChanged: " .. tos(optionsChanged))
	end
]]
	--(Did the options change: Yes / OR are we initializing a ZO_ComboBox ) / AND Are the new passed in options nil or empty: Yes
	--> Reset to default ZO_ComboBox variables and just call AddCustomEntryTemplates()
	if (optionsChanged == true or onInit == true) and ZO_IsTableEmpty(options) then
		optionsChanged = false
--[[
		if isContextMenu then
			d(">>resetting options to defaults!")
		end
]]
--d(">3 ResetToDefaults")
		-- Reset comboBox internal variables of ZO_ComboBox, e.g. m_font, and LSM defaults like visibleRowsDropdown
		--todo: 20250204 Check if this is needed -> initExistingComboBox: do not overwrite already existing variables of the ZO_ComboBox if the box was an existing one where LSM was only added to via AddCustomScrollableComboBoxDropdownMenu
		self:ResetToDefaults((onInit == true and initExistingComboBox) or nil)

		--Did the options change: Yes / OR Are the already stored options at the object nil or empty (should happen if self:UpdateOptions(options) was not called before): Yes
		--> Use passed in options, or use the default ZO_ComboBox options added via self:ResetToDefaults() before
	elseif optionsChanged == true or ZO_IsTableEmpty(self.options) then
		optionsChanged = false

		--Create empty table options, if nil
		options = options or {}

		-- Backwards compatiblity for the time when options was no table bu just 1 variable "visibleRowsDropdown"
		if type(options) ~= 'table' then
			options = { visibleRowsDropdown = options }
		end

--d(">4 SetOptions")

		--Set the passed in options to the ZO_ComboBox .options table (for future comparison, see above at optionsChanged = optionsChanged or options ~= self.options)
		self:SetOptions(options)

		--Clear the table with options which got updated. Will be filled in self:SetOption(key) method
		-->Filling the self.updatedOptions table with values so they can be used in the callback functions (if any is given)
		-->from table LSMOptionsToZO_ComboBoxOptionsCallbacks, e.g. sortOrder and sortType can check if either was updated already
		-->via the loop and self:SetOption() calls below
		self.updatedOptions = {}

		-- Defaults are predefined in defaultComboBoxOptions, but they will be taken from ZO_ComboBox defaults set from table comboBoxDefaults
		-- at function self:ResetToDefaults().
		-- If any variable was set to the ZO_ComboBox already (e.g. self.m_font) it will be used again from that internal variable, if nothing
		-- was overwriting it here from passed in options table

--d(">5 Loop options")

		-- LibScrollableMenu custom options
		if not ZO_IsTableEmpty(options) then
			for key, _ in pairs(options) do
--[[
if isContextMenu then
	d(">>setting option key: " ..tos(key))
end
]]

				self:SetOption(key)
			end
		end

		--Reset the table with options which got updated (only needed here for the callback functions called from self:SetOption
		---> See table LSMOptionsToZO_ComboBoxOptionsCallbacks
		self.updatedOptions = nil

	--[[
		if isContextMenu then
			d("> SetOption and for ... do SetOptions looped ")
		end
	]]
	end

	-- this will add custom and default templates to self.XMLRowTemplates the same way dataTypes were created before.
	self:AddCustomEntryTemplates(options, isContextMenu)
end

function comboBoxClass:UpdateResults(comingFromFilters)
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end
	self:Show()
end

function comboBoxClass:ShowDropdown()
	-- Let the caller know that this is about to be shown...
	if self.m_preshowDropdownFn then
		self.m_preshowDropdownFn(self)
	end

	if not self:IsDropdownVisible() then
		-- Update header only if hidden.
		self:UpdateDropdownHeader()
	end
	self:ShowDropdownInternal()
end

function comboBoxClass:SetupDropdownHeader()
	local dropdownControl = self.m_dropdownObject.control
	ApplyTemplateToControl(dropdownControl, 'LibScrollableMenu_Dropdown_Template_WithHeader')

	local options = self:GetOptions()
	if options.headerCollapsible then
		local headerCollapsed = (options and options.headerCollapsed)

		if headerCollapsed == nil then
			headerCollapsed = getSavedVariable("collapsedHeaderState", getHeaderToggleStateControlSavedVariableName(self))
		end
		if headerCollapsed ~= nil then
			if dropdownControl.toggleButton then
				ZO_CheckButton_SetCheckState(dropdownControl.toggleButton, headerCollapsed)
			end
		end
	end
end

--Toggle function called as the collapsible header is clicked
function comboBoxClass:UpdateDropdownHeader(toggleButtonCtrl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 139, tos(self.options), tos(toggleButtonCtrl)) end

--d(debugPrefix .. "comboBoxClass:UpdateDropdownHeader")

	local headerControl, dropdownControl = getHeaderControl(self)
	if headerControl == nil then return end

	local headerCollapsed = false

	local options = self:GetOptions()
	if options.headerCollapsible then
		toggleButtonCtrl = toggleButtonCtrl or dropdownControl.toggleButton
		if toggleButtonCtrl then
			headerCollapsed = ZO_CheckButton_IsChecked(toggleButtonCtrl)

			if options.headerCollapsed == nil then
--d(">updateSavedVariable collapsedHeaderState: " ..tos(getHeaderToggleStateControlSavedVariableName(self)))
				-- No need in saving state if we are going to force state by options.headerCollapsed
				updateSavedVariable("collapsedHeaderState", headerCollapsed, getHeaderToggleStateControlSavedVariableName(self))
			end
		end
	end
--d(">headerCollapsed: " ..tos(headerCollapsed))

	--d(debugPrefix.."comboBoxClass:UpdateDropdownHeader - headerCollapsed: " ..tos(headerCollapsed))
	refreshDropdownHeader(self, headerControl, self.options, headerCollapsed)
	self:UpdateWidth(dropdownControl) --> Update self.m_containerWidth properly for self:Show (in self:UpdateHeight) call (including the now, in refreshDropdownHeader, updated header's width)
	self:UpdateHeight(dropdownControl) --> Update self.m_height properly for self:Show call (including the now, in refreshDropdownHeader, updated header's height)
--d(">new height: " ..tos(self.m_height))
end

function comboBoxClass:AddItemToSelected(item)
    if not self.m_enableMultiSelect then
        return
    end

	--Multiselection
    table.insert(self.m_multiSelectItemData, item)
	--Set a possible submenu's openingControl.isAnySubmenuEntrySelected
	recursiveMultiSelectSubmenuOpeningControlUpdate(self, item, true)
end

function comboBoxClass:RemoveItemFromSelected(item)
    if not self.m_enableMultiSelect then
        return
    end

	--Multiselection
    for i, itemData in ipairs(self.m_multiSelectItemData) do
        if itemData == item then
			--Reset the submenu's openingControl.isAnySubmenuEntrySelected, if no other item in the submenu is still marked
			--Check if other submenu entries are selected: use extra lookup tables self.m_multiSelectItemDataSubmenu[submenuOpeningControl] = { [item1] = true, ... }
            table.remove(self.m_multiSelectItemData, i)
			recursiveMultiSelectSubmenuOpeningControlUpdate(self, item, nil)
            return
        end
    end
end

--ZO_ComboBoxDropdown_Keyboard:OnEntrySelected(control) -> self.owner (comboboxClass) :SetSelected -> self (comboboxClass) :SelectItem
function comboBoxClass:SelectItem(item, ignoreCallback)
--d(debugPrefix .. "comboBoxClass:SelectItem - item: " .. tos(item) ..", ignoreCallback: " .. tos(ignoreCallback))
    --No multiselection
	if not self.m_enableMultiSelect then
--d(">multiSelection is OFF")
        return zo_comboBox_base_selectItem(self, item, ignoreCallback)
    end
--d(">multiSelection is ON")

    if item.enabled == false then
        return false
    end

	--Multiselection
    local newSelectionStatus = not self:IsItemSelected(item)
    if newSelectionStatus then
        if self.m_maxNumSelections == nil or self:GetNumSelectedEntries() < self.m_maxNumSelections then
--d(debugPrefix.."comboBoxClass:SelectItem -> AddItemToSelected")
            self:AddItemToSelected(item)
        else
            if not self.onSelectionBlockedCallback or self.onSelectionBlockedCallback(item) ~= true then
                local alertText = self:GetSelectionBlockedErrorText()
                if ZO_REMOTE_SCENE_CHANGE_ORIGIN == SCENE_MANAGER_MESSAGE_ORIGIN_INTERNAL then
                    RequestAlert(UI_ALERT_CATEGORY_ALERT, SOUNDS.GENERAL_ALERT_ERROR, alertText)
                elseif ZO_REMOTE_SCENE_CHANGE_ORIGIN == SCENE_MANAGER_MESSAGE_ORIGIN_INGAME then
                    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.GENERAL_ALERT_ERROR, alertText)
                end
                return false
            end
        end
    else
        self:RemoveItemFromSelected(item)
    end
	--20250309 Replace sound with LSM selected sound #2025_14 -> For multiselection
    --PlaySound(SOUNDS.COMBO_CLICK)
	playSelectedSoundCheck(self.m_dropdownObject, item.entryType)

    if item.callback and not ignoreCallback then
        item.callback(self, item.name, item)
    end
    self:RefreshSelectedItemText()
    -- refresh the data that was just selected so the selection highlight properly shows/hides
    if self.m_dropdownObject:IsOwnedByComboBox(self) then
        self.m_dropdownObject:Refresh(item)
    end

    return true
end

-- a maxNumSelections of 0 or nil indicates no limit on selections
--[[
function comboBoxClass:SetMaxSelections(maxNumSelections)
d(debugPrefix .. "comboBoxClass:SetMaxSelections:"  ..tos(maxNumSelections))
    if not self.m_enableMultiSelect then
        return false
    end

    if maxNumSelections == 0 then
        maxNumSelections = nil
    end

    -- if the new limit is less than the current limit, clear all the selections
    if maxNumSelections and (self.m_maxNumSelections == nil or maxNumSelections < self.m_maxNumSelections) then
        self:ClearAllSelections()
    end
d(">self.m_maxNumSelections: " .. tos(maxNumSelections))
    self.m_maxNumSelections = maxNumSelections
end
]]