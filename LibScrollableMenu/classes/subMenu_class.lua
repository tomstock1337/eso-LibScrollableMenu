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


--------------------------------------------------------------------
--Library classes
--------------------------------------------------------------------
local classes = lib.classes
local comboBox_base = classes.comboboxBaseClass
local comboBoxClass = classes.comboBoxClass


--------------------------------------------------------------------
--ZO_ComboBox function references
--------------------------------------------------------------------
local zo_comboBox_base_addItem = ZO_ComboBox_Base.AddItem
local zo_comboBox_base_hideDropdown = ZO_ComboBox_Base.HideDropdown
local zo_comboBox_base_updateItems = ZO_ComboBox_Base.UpdateItems

local zo_comboBox_setItemEntryCustomTemplate = ZO_ComboBox.SetItemEntryCustomTemplate

--local zo_comboBoxDropdown_onEntrySelected = ZO_ComboBoxDropdown_Keyboard.OnEntrySelected
local zo_comboBoxDropdown_onMouseExitEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry
local zo_comboBoxDropdown_onMouseEnterEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry


--------------------------------------------------------------------
--LSM library locals
--------------------------------------------------------------------
local constants = lib.contants
local entryTypeConstants = constants.entryTypes
local comboBoxConstants = constants.comboBox
local submenuConstants = constants.submenu
local comboBoxMappingConstants = comboBoxConstants.mapping
local comboBoxDefaults = comboBoxConstants.defaults

local submenuClass_exposedVariables = submenuConstants.submenuClass_exposedVariables
local submenuClass_exposedFunctions = submenuConstants.submenuClass_exposedFunctions


local libUtil = lib.Util
local getControlName = libUtil.getControlName
local getValueOrCallback = libUtil.getValueOrCallback
local showTooltip = libUtil.showTooltip
local hideTooltip = libUtil.hideTooltip
local SubOrContextMenu_highlightControl = libUtil.SubOrContextMenu_highlightControl


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------
-- LSM submenu class definition
--------------------------------------------------------------------
local submenuClass = classes.submenuClass --Defined at comboBoxBase class already!


--------------------------------------------------------------------
--LSM submenu class
--------------------------------------------------------------------
--------------------------------------------------------------------
-- submenuClass
--------------------------------------------------------------------

function submenuClass:New(...)
	local newObject = setmetatable({},  {
		--Use variables from the main LSM comboBox, which are missing in the submenu's combobox, for the  submenu's comboBox, e.g. m_containerWidth, m_font etc.
		-->All variables which are maintained in table submenuClass_exposedVariables with value = boolean true
		-->Will be checked via metatables each time as the submenu_combobox[key] is triggered -> lookup [key] in main menu LSM combobox
		__index = function (obj, key)
			--Is it a variable - Get it from the parent LSM menu
			if submenuClass_exposedVariables[key] then
				local value = obj.m_comboBox[key]
--[[
LSM_Debug = LSM_Debug or {}
LSM_Debug.submenuClass_new = LSM_Debug.submenuClass_new or {}
LSM_Debug.submenuClass_new[obj] = LSM_Debug.submenuClass_new[obj] or {}
LSM_Debug.submenuClass_new[obj][key] = value

if key == "m_enableMultiSelect" then
	d(">main->submenu key="..tos(key).." = " .. tos(value))
end
]]
				if value ~= nil then
					return value
				end
			end

			--Is it a function at the submenuClass (or inherited parent classes)?
			local value = submenuClass[key]
			if value then
				if submenuClass_exposedFunctions[key] then
					return function(p_self, ...)
						return value(p_self.m_comboBox, ...)
					end
				end

				return value
			end
		end
	})

	newObject.__parentClasses = {self}
	newObject:Initialize(...)
	return newObject
end

-- submenuClass:New(To simplify locating the beginning of the class
function submenuClass:Initialize(parent, comboBoxContainer, options, depth)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 140, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth)) end
	self.m_comboBox = comboBoxContainer.m_comboBox
	self.isSubmenu = true
	self.m_parentMenu = parent

	comboBox_base.Initialize(self, parent, comboBoxContainer, options, depth, nil)
	self.breadcrumbName = 'SubmenuBreadcrumb'
end

function submenuClass:UpdateOptions(options, onInit)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 141, tos(options), tos(onInit)) end

	self:AddCustomEntryTemplates(self:GetOptions())
end

function submenuClass:AddMenuItems(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 142, tos(getControlName(parentControl))) end
	self.openingControl = parentControl
	self:RefreshSortedItems(parentControl)
	self:UpdateWidth()
	self:UpdateHeight()
	--self:Show() --Is called from self:UpdateHeight() already so would be called double here!
	self.m_dropdownObject:AnchorToControl(parentControl)
end

function submenuClass:GetEntries()
	local data = getControlData(self.openingControl)

	local entries = getValueOrCallback(data.entries, data)
	return entries
end

function submenuClass:GetMaxRows()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 143, tos(self.visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS)) end
	return self.visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS
end

function submenuClass:GetMenuPrefix()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 144) end
	return 'SubMenu'
end

function submenuClass:ShowDropdownInternal()
	if self.openingControl then
		SubOrContextMenu_highlightControl(self, self.openingControl) --submenu
	end
end

function submenuClass:HideDropdownInternal()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 145) end

	if self.m_dropdownObject:IsOwnedByComboBox(self) then
		self.m_dropdownObject:SetHidden(true)
	end
	self:SetVisible(false)
	if self.onHideDropdownCallback then
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 146) end
		self.onHideDropdownCallback()
	end

	if self.highlightedControl then
		unhighlightHighlightedControl(self)
	end
end

function submenuClass:HideDropdown()
	return comboBox_base.HideDropdown(self)
end

function submenuClass:HideOnMouseExit(mocCtrl)
	-- Only begin hiding if we stopped over a dropdown.
	mocCtrl = mocCtrl or moc()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 147, tos(getControlName(mocCtrl))) end
	if mocCtrl.m_dropdownObject then
		if comboBoxClass.HideOnMouseExit(self) then
			-- Close all open submenus beyond this point
			-- This will only close the dropdown if the mouse is not over the dropdown or over the control that opened it.
			if self:ShouldHideDropdown() then
				return self:HideDropdown()
			end
		end
	end
end

function submenuClass:ShouldHideDropdown()
	return self:IsDropdownVisible() and (not self:IsMouseOverControl() and not self:IsMouseOverOpeningControl())
end

function submenuClass:IsMouseOverOpeningControl()
--d(debugPrefix .. "submenuClass:IsMouseOverOpeningControl: " .. tos(MouseIsOver(self.openingControl)))
	return MouseIsOver(self.openingControl)
end

function submenuClass:GetHiddenForReasons(button)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 148, tos(button)) end
--d("222222222222222 submenuClass:GetHiddenForReasons - button: " ..tos(button))
	local selfVar = self
	return function(owningWindow, mocCtrl, comboBox, entry) return checkIfHiddenForReasons(selfVar, button, false, owningWindow, mocCtrl, comboBox, entry, true) end
end