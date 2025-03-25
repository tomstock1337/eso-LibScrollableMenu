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
local constants = lib.constants

local libUtil = lib.Util
local getControlName = libUtil.getControlName

local SubOrContextMenu_highlightControl = libUtil.SubOrContextMenu_highlightControl
local checkIfHiddenForReasons = libUtil.checkIfHiddenForReasons
local getComboBox = libUtil.getComboBox
local throttledCall = libUtil.throttledCall


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


--------------------------------------------------------------------
-- LSM contextMenu class
--------------------------------------------------------------------
-- LibScrollableMenu.contextMenu
-- contextMenuClass:New(To simplify locating the beginning of the class
function contextMenuClass:Initialize(comboBoxContainer)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 149, tos(getControlName(comboBoxContainer))) end
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
	local indexAdded = tins(self.data, itemEntry)
	indexAdded = indexAdded or #self.data
	return indexAdded
--	m_unsortedItems
end

function contextMenuClass:AddMenuItems(parentControl, comingFromFilters)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 151) end
	self:RefreshSortedItems()
	--self:UpdateWidth()
	--self:UpdateHeight() -->Should be called from self:Show -> self:ShowContextMenu -> self:UpdateHeader
	self:Show()
	self.m_dropdownObject:AnchorToMouse()
end

function contextMenuClass:ClearItems()
--d(debugPrefix .. 'contextMenuClass:ClearItems()')
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 152) end
	self:SetContextMenuOptions(nil)
	self:ResetToDefaults()

--	ZO_ComboBox_HideDropdown(self:GetContainer())
	ZO_ComboBox_HideDropdown(self)
	ZO_ClearNumericallyIndexedTable(self.data)

	self:SetSelectedItemText("")
	self.m_selectedItemData = nil
	self:OnClearItems()
end

function contextMenuClass:GetEntries()
	return self.data
end

function contextMenuClass:GetMenuPrefix()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 153) end
	return 'ContextMenu'
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

--d(">Before options: self.visibleRows = " .. tos(self.visibleRows))

	self:UpdateOptions(self.contextMenuOptions, nil, true, nil) --Updates self.options

--d(">After options: self.visibleRows = " .. tos(self.visibleRows))

	self:HighlightOpeningControl()

--d("->->->->->->-> [LSM]ContextMenuClass:ShowContextMenu -> ShowDropdown now!")
	self:ShowDropdown()

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

function contextMenuClass:SetContextMenuOptions(options)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 158, tos(options)) end

	-- self.contextMenuOptions is only a temporary table used to check for changes and to send to UpdateOptions
	-- so we can check here if anything changed within the passed in options paramter (compared to previous options)
	self.optionsChanged = self.contextMenuOptions ~= options

--d(debugPrefix .. "contextMenuClass:SetContextMenuOptions - optionsChanged: " .. tos(self.optionsChanged))
	--Wil be used in contextMenuClass:ShowContextMenu -> self:UpdateOptions(self.contextMenuOptions)
	self.contextMenuOptions = options
end

--Create the local context menu object for the library's context menu API functions
local function createContextMenuObject()
	local comboBoxContainer = CreateControlFromVirtual(MAJOR .. "_ContextMenu", GuiRoot, "ZO_ComboBox")
	g_contextMenu = contextMenuClass:New(comboBoxContainer)
	lib.contextMenu = g_contextMenu

	lib.CreateContextMenuObject = nil --remove globally accessible function after first call
end
lib.CreateContextMenuObject = createContextMenuObject