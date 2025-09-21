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
local tins = table.insert


--------------------------------------------------------------------
--Library classes
--------------------------------------------------------------------
local classes = lib.classes
local comboBox_base = classes.comboboxBaseClass
local comboBoxClass = classes.comboBoxClass


--------------------------------------------------------------------
--LSM library locals
--------------------------------------------------------------------
--local constants = lib.constants

local libUtil = lib.Util
local getControlName = libUtil.getControlName

local SubOrContextMenu_highlightControl = libUtil.SubOrContextMenu_highlightControl
local checkIfHiddenForReasons = libUtil.checkIfHiddenForReasons
local getComboBox = libUtil.getComboBox
local throttledCall = libUtil.throttledCall
local libUtil_isAnyLSMDropdownVisible = libUtil.isAnyLSMDropdownVisible

--------------------------------------------------------------------
--Local library class reference variable
--------------------------------------------------------------------
local g_contextMenu


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------
-- LSM contextMenu class definition
--------------------------------------------------------------------
local contextMenuClass = comboBoxClass:Subclass()
classes.contextMenuClass = contextMenuClass


--Create the local context menu object for the library's context menu API functions
local function createContextMenuObject()
	local comboBoxContainer = CreateControlFromVirtual(MAJOR .. "_ContextMenu", GuiRoot, "ZO_ComboBox")
	g_contextMenu = contextMenuClass:New(comboBoxContainer)
	lib.contextMenu = g_contextMenu

	lib.CreateContextMenuObject = nil --remove globally accessible function after first call, so noone ever calls it twice
end
lib.CreateContextMenuObject = createContextMenuObject --Called once from initialization of LibScrollableMenu -> EVENT_ADD_ON_LOADED


--------------------------------------------------------------------
-- LSM contextMenu class
--------------------------------------------------------------------
-- LibScrollableMenu.contextMenu
-- contextMenuClass:New(To simplify locating the beginning of the class
function contextMenuClass:Initialize(comboBoxContainer)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 149, tos(getControlName(comboBoxContainer))) end
--d(debugPrefix .. 'contextMenuClass:Initialize')
	self:SetDefaults()
	comboBoxClass.Initialize(self, nil, comboBoxContainer, nil, 1)
	self.data = {}

	self:ClearItems()

	self.breadcrumbName = 'ContextmenuBreadcrumb'
	self.isContextMenu = true
end

function contextMenuClass:GetUniqueName()
	if self.openingControl then
		return getControlName(self.openingControl)
	else
		return self.m_name
	end
end

-- Renamed from AddItem since AddItem can be the same as base. This function is only to pre-set data for updating on show,
function contextMenuClass:AddContextMenuItem(itemEntry)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 150, tos(itemEntry)) end
--d(debugPrefix .. 'contextMenuClass:AddContextMenuItem - name: ' ..tos(itemEntry.label or itemEntry.name))

	local indexAdded = tins(self.data, itemEntry)
	indexAdded = indexAdded or #self.data
	return indexAdded
--	m_unsortedItems
end

function contextMenuClass:GetEntries()
	return self.data
end

function contextMenuClass:GetMenuPrefix()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 153) end
	return 'ContextMenu'
end

function contextMenuClass:HighlightOpeningControl()
	local openingControl = self.openingControl
	if openingControl then
		local highlightContextMenuOpeningControl = (self.options ~= nil and self.options.highlightContextMenuOpeningControl) or false
--d(debugPrefix .. "ctxMen-highlightCntxtMenOpeningControl-name: " .. tos(getControlName(openingControl)) ..", highlightIt: " .. tos(highlightContextMenuOpeningControl))
		--Options tell us to highlight the openingControl?
		if highlightContextMenuOpeningControl == true then
			--Apply the highlightOpeningControl XML template to the openingControl and highlight it than via the animation
			SubOrContextMenu_highlightControl(self, openingControl) --context menu
		end
	end
end

function contextMenuClass:SetContextMenuOptions(options)
--d(debugPrefix .. 'contextMenuClass:SetContextMenuOptions - options: ' ..tos(options))
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 158, tos(options)) end

	-- self.contextMenuOptions is only a temporary table used to check for changes in comboBox_class:UpdateOptions
	-- so we can check here if anything changed within the passed in options paramter (compared to previous options)
	-- It will be set to self.options in the end, via self:UpdateOptions -> called from contextMenuClass:ShowContextMenu
	self.optionsChanged = self.contextMenuOptions ~= options

--d(debugPrefix .. "SetContextMenuOptions - changed: " .. tos(self.optionsChanged) .. ", before: " .. tos(self.contextMenuOptions))
	--Wil be used in contextMenuClass:ShowContextMenu -> self:UpdateOptions(self.contextMenuOptions)
	self.contextMenuOptions = options
--d(debugPrefix .. ">after: " .. tos(self.contextMenuOptions))
end

function contextMenuClass:AddMenuItems(parentControl, comingFromFilters)
--d(debugPrefix .. 'contextMenuClass:AddMenuItems()')
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 151) end
	self:RefreshSortedItems()
	self:UpdateWidth()
	--self:UpdateHeight() -->Should be already called from self:Show -> self:ShowContextMenu -> self:UpdateHeader
	self:Show() --> Calls comboBox_base:Show -> dropdown_class:Show
	self.m_dropdownObject:AnchorToMouse()
end

--Called from ClearCustomScrollableMenu -> libUtil.hideContextMenu
function contextMenuClass:ClearItems()
--d(debugPrefix .. 'contextMenuClass:ClearItems()')
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 152) end
	self.contextMenuIssuingControl = nil	--#2025_28 Reset the contextMenuIssuingControl of the contextMenu for API functions

	self:SetContextMenuOptions(nil)
	self:ResetToDefaults(nil) --comboBox_class

--	ZO_ComboBox_HideDropdown(self:GetContainer())
	ZO_ComboBox_HideDropdown(self)
	ZO_ClearNumericallyIndexedTable(self.data)

	self:SetSelectedItemText("")
	self.m_selectedItemData = nil
	self:OnClearItems()
end

function contextMenuClass:GetHiddenForReasons(button)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 154, tos(button)) end
--d(debugPrefix.."3333333333333333 contextMenuClass:GetHiddenForReasons - button: " ..tos(button))
	local selfVar = self
	return function(owningWindow, mocCtrl, comboBox, entry) return checkIfHiddenForReasons(selfVar, button, true, owningWindow, mocCtrl, comboBox, entry) end
end

function contextMenuClass:HideDropdown()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 155) end
	-- Recursive through all open submenus and close them starting from last.
--d(debugPrefix .. "contextMenuClass:HideDropdown")

	return comboBox_base.HideDropdown(self)
end

function contextMenuClass:ShowSubmenu(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 156, tos(getControlName(parentControl))) end
	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

function contextMenuClass:ShowContextMenu(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 157, tos(getControlName(parentControl))) end
	--Resetting some preventer variables
--d("///////////////////////////////")
--d(debugPrefix .. "->->->->-> contextMenuClass:ShowContextMenu")
--d(">resetting some lib.preventerVars")
	lib.preventerVars.wasContextMenuOpenedAsOnMouseUpWasSuppressed = nil
	lib.preventerVars.suppressNextOnEntryMouseUpDisableCounter = nil

	--Cache last opening Control for the comparison with new openingControl and reset of filters etc. below
	local openingControlOld = self.openingControl
	if parentControl == nil then parentControl = self.contextMenuIssuingControl or moc() end --#2025_28
	self.openingControl = parentControl


	-- To prevent the context menu from overlapping a submenu it is not opened from:
	-- If the opening control is a dropdown and has a submenu visible, close the submenu.
	local comboBox = getComboBox(parentControl)
	if comboBox and comboBox.m_submenu and comboBox.m_submenu:IsDropdownVisible() then
		comboBox.m_submenu:HideDropdown()
	end

	if self:IsDropdownVisible() then
		self:HideDropdown()
	end
    --d(">Before options: self.enableFilter = " .. tos(self.enableFilter))
    --[[
	LSM_Debug = LSM_Debug or {}
    LSM_Debug.contextMenusOpened = LSM_Debug.contextMenusOpened or {}
    local newIndex = #LSM_Debug.contextMenusOpened+1
    LSM_Debug.contextMenusOpened[newIndex] = {
        optionsBefore = self.options ~= nil and ZO_ShallowTableCopy(self.options) or nil,
        contextMenuOptionsBefore = self.contextMenuOptions ~= nil and ZO_ShallowTableCopy(self.contextMenuOptions) or nil,
        enableFilterBefore = self.contextMenuOptionsBefore ~= nil and self.contextMenuOptionsBefore.enableFilter or nil,
    }
    ]]
	self:UpdateOptions(self.contextMenuOptions, nil, true, nil) --Updates self.options
    --[[
	LSM_Debug.contextMenusOpened[newIndex].optionsAfter = self.options ~= nil and ZO_ShallowTableCopy(self.options) or nil
    LSM_Debug.contextMenusOpened[newIndex].contextMenuOptionsAfter = self.contextMenuOptions ~= nil and ZO_ShallowTableCopy(self.contextMenuOptions) or nil
    LSM_Debug.contextMenusOpened[newIndex].enableFilterAfter = self.contextMenuOptions ~= nil and self.contextMenuOptions.enableFilter or nil,
    d(">After options: self.enableFilter = " .. tos(self.enableFilter))
    ]]

	self:HighlightOpeningControl()

--d("->->->->->->-> [LSM]ContextMenuClass:ShowContextMenu -> ShowDropdown now!")
	--Check if any non-contextMenu LSM is shown and if that is the case it's OnGlobalMouseUp will fire as it closes
	if libUtil_isAnyLSMDropdownVisible(false) then --#2025_29
--d(">supressing next onMouseUp as an LSM is still opened, and the mouse would clear the contextMenu entries")
		lib.preventerVars.suppressNextOnGlobalMouseUp = true
	end
	self:ShowDropdown()


	--#2025_29 Next OnGlobalMouse up of any before opened LSM (as we right clicked any other owningWindow's LSM entry to show a contextMenu)
	--will fire after the contextMenu here is shown -> and these other onGlobalMouseUps will clear the contextMenu entries via libUtil.hideContextMenu again :-(
	--todo 20250406 How can we detect this? And then prevent the globalMouseUps (there are 2 in that case: 1 from the new contextMenu's opening control and one from the before opened LSM)


	--d(debugPrefix .. "ContextMenuClass:ShowContextMenu - openingControl changed!")
	throttledCall(function()
		if openingControlOld ~= parentControl then
			--d(debugPrefix .. "ContextMenuClass:ShowContextMenu - openingControl changed!")
			if self:IsFilterEnabled() then
				--d(">>resetting filters now")
				local dropdown = self.m_dropdown
				if dropdown and dropdown.object then
					dropdown.object:ResetFilters(dropdown)
				end
			end
		end
	end, 10, "_ContextMenuClass_ShowContextMenu")
end