-- Register with LibStub
local lib ={}
lib.name = "LibScrollableMenu"
lib.data = {}

if not lib then return end -- the same or newer version of this lib is already loaded into memory

local wm = WINDOW_MANAGER
local em = EVENT_MANAGER

local SUBMENU_ITEM_MOUSE_ENTER = 1
local SUBMENU_ITEM_MOUSE_EXIT = 2
local SUBMENU_SHOW_TIMEOUT = 350
local SUBMENU_HIDE_TIMEOUT = 350

local ROOT_PREFIX = "LibScrollableMenuSub"

local submenuCallLaterHandle
local nextId = 1
local function ClearTimeout()
	if (submenuCallLaterHandle ~= nil) then
		em:UnregisterForUpdate(submenuCallLaterHandle)
		submenuCallLaterHandle = nil
	end
end

local function SetTimeout(callback)
	if (submenuCallLaterHandle ~= nil) then ClearTimeout() end
	submenuCallLaterHandle = "LibScrollableMenuTimeout" .. nextId
	nextId = nextId + 1

	em:RegisterForUpdate(submenuCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		ClearTimeout()
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
local function GetValueOrCallback(arg, ...)
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end

-- use container.m_comboBox for the object
local function GetContainerFromControl(control)
	local owner = control.m_owner
	return owner and owner.m_container
end

-- the actual object
local function GetSubmenuFromControl(control)
	local owner = control.m_owner
	return owner and owner.m_submenu
end



-----   Public API  -----
lib.persistentMenus = false -- controls if submenus are closed shortly after the mouse exists them
function lib.GetPersistentMenus()
	return lib.persistentMenus
end
function lib.SetPersistentMenus(persistent)
	lib.persistentMenus = persistent
end
----- End Public API -----


lib.HELPER_MODE_NORMAL = 0
lib.HELPER_MODE_LAYOUT_ONLY = 1 -- means only the layout of the dropdown will be altered, not the way it handles layering through ZO_Menus


local ENTRY_ID = 1
local LAST_ENTRY_ID = 2
local DIVIDER_ENTRY_ID = 3

lib.DIVIDER = "-"
local DIVIDER_ENTRY_HEIGHT = 7

local DEFAULT_VISIBLE_ROWS = 10
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = 25 -- same as in zo_combobox.lua
local TEXT_PADDING = 4
local CONTENT_PADDING = 18 -- decreased from 24
local SCROLLBAR_PADDING = 16
local PADDING = GetMenuPadding() / 2 -- half the amount looks closer to the regular dropdown
local ROUNDING_MARGIN = 0.01 -- needed to avoid rare issue with too many anchors processed
local SCROLLABLE_COMBO_BOX_LIST_PADDING_Y = 9

local ScrollableDropdownHelper = ZO_Object:Subclass()
lib.ScrollableDropdownHelper = ScrollableDropdownHelper

function ScrollableDropdownHelper:New(...)
	local object = ZO_Object.New(self)
	object:Initialize(...)
	return object
end

local function GetOption(options, value, default)
	return options and options[value] or default
end

-- Available options are:
--   visibleRows
--
--   persistantMenus - its submenus won't close when the mouse exits them, only by clicking somewhere or selecting something else
--   orientation - the preferred direction for tooltips and submenus (either LEFT or RIGHT)
function ScrollableDropdownHelper:Initialize(parent, control, visibleRows)
	local combobox = control.combobox
	local dropdown = control.dropdown

	self.parent = parent
	self.control = control
	self.combobox = combobox
	self.dropdown = dropdown
	self.visibleRows = visibleRows
	--self.visibleRows = GetOption(options, "visibleRows", DEFAULT_VISIBLE_ROWS)
	--self.mode        = GetOption(options, "mode", lib.HELPER_MODE_NORMAL)

	-- clear anchors so we can adjust the width dynamically
	dropdown.m_dropdown:ClearAnchors()
	dropdown.m_dropdown:SetAnchor(TOPRIGHT, combobox, BOTTOMRIGHT)

	-- handle dropdown or settingsmenu opening/closing
	local function onShow() self:OnShow() end
	local function onHide() self:OnHide() end
	local function doHide() self:DoHide() end

	ZO_PreHook(dropdown,"ShowDropdownOnMouseUp", onShow)
	ZO_PreHook(dropdown,"HideDropdownInternal", onHide)
	combobox:SetHandler("OnEffectivelyHidden", onHide)
	if parent then parent:SetHandler("OnEffectivelyHidden", doHide) end

	-- dont fade entries near the edges
	local scrollList = dropdown.m_scroll
	scrollList.selectionTemplate = nil
	scrollList.highlightTemplate = nil
	ZO_ScrollList_EnableSelection(scrollList, "ZO_SelectionHighlight")
	ZO_ScrollList_EnableHighlight(scrollList, "ZO_SelectionHighlight")
	ZO_Scroll_SetUseFadeGradient(scrollList, false)

	-- adjust scroll content anchor to mimic menu padding
	local scroll = dropdown.m_dropdown:GetNamedChild("Scroll")
	local anchor1 = {scroll:GetAnchor(0)}
	local anchor2 = {scroll:GetAnchor(1)}
	scroll:ClearAnchors()
	scroll:SetAnchor(anchor1[2], anchor1[3], anchor1[4], anchor1[5] + PADDING, anchor1[6] + PADDING)
	scroll:SetAnchor(anchor2[2], anchor2[3], anchor2[4], anchor2[5] - PADDING, anchor2[6] - PADDING)
	ZO_ScrollList_Commit(scrollList)

	-- hook mouse enter/exit
	local function onMouseEnter(control) return self:OnMouseEnter(control) end
	local function onMouseExit(control)  return self:OnMouseExit(control)  end

	-- checkbox wrappers
	local function setChecked(checkbox, checked)
		local data = ZO_ScrollList_GetData(checkbox:GetParent())
		if data.callback then
			data.callback(checked, data)
		end
	end

	-- adjust row setup to mimic the highlight padding
	local dataType1 = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, 1)
	local dataType2 = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, 2)
	local oSetup = dataType1.setupCallback -- both types have the same setup function
	local function SetupEntry(control, data, list)
		oSetup(control, data, list)
		control.m_label:SetAnchor(LEFT, nil, nil, 2)

		-- no need to store old ones since we have full ownership of our dropdown controls
		if not control.hookedMouseHandlers then --only do it once per control
			control.hookedMouseHandlers = true
			ZO_PreHookHandler(control, "OnMouseEnter", onMouseEnter)
			ZO_PreHookHandler(control, "OnMouseExit", onMouseExit)
		end

		-- if a menu never uses "entries" then it will never create these controls
		if data.entries ~= nil then
			if not control.m_arrow then
				local arrowContainer = control:CreateControl("$(parent)Arrow", CT_CONTROL)
				-- we need this in order to control the menu width independently of the texture size
				arrowContainer:SetAnchor(RIGHT, control, RIGHT, 0, 0)
				arrowContainer:SetDimensions(32, 16)

				local arrow = arrowContainer:CreateControl("$(parent)Texture", CT_TEXTURE)
				arrow:SetAnchor(RIGHT, arrowContainer, RIGHT, 0, 0)
				arrow:SetDimensions(16, 20)
				arrow:SetTexture("EsoUI/Art/Miscellaneous/colorPicker_slider_vertical.dds")
				arrow:SetTextureCoords(0, 0.5, 0, 1)
				control.m_arrow = arrowContainer
			end
			control.m_arrow:SetHidden(false)
		elseif control.m_arrow then
			control.m_arrow:SetHidden(true)
		end

		-- if a menu never uses "checked" then it will never create these controls
		if data.checked ~= nil then
			local checkbox = control.m_checkbox
			if not checkbox then
				checkbox = wm:CreateControlFromVirtual("$(parent)Checkbox", control, "ZO_CheckButton")
				checkbox:SetAnchor(LEFT, nil, LEFT, 2, -1)
				checkbox:SetHandler("OnMouseEnter", function(checkbox) ZO_ScrollableComboBox_Entry_OnMouseEnter(control) end)
				checkbox:SetHandler("OnMouseExit", function(checkbox) ZO_ScrollableComboBox_Entry_OnMouseExit(control) end)
				control.m_checkbox = checkbox
			end
			checkbox:SetHidden(false)
			ZO_CheckButton_SetToggleFunction(checkbox, setChecked)
			ZO_CheckButton_SetCheckState(checkbox, GetValueOrCallback(data.checked, data))
			control.m_label:SetText(string.format(" |u18:0::|u%s", data.name))
		elseif control.m_checkbox then
			control.m_checkbox:SetHidden(true)
		end

		-- NOTE: Cannot do it like this due to the fixed height of this data type
		--local divider = control.m_divider
		--if data.name == lib.DIVIDER then
		--	control:SetHeight(DIVIDER_ENTRY_HEIGHT)
		--	if not divider then
		--		divider = wm:CreateControlFromVirtual("$(parent)Divider", control, "ZO_BaseTooltipDivider")
		--		divider:ClearAnchors()
		--		divider:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 2)
		--		divider:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 2)
		--		control.m_divider = divider
		--	end
		--	divider:SetHidden(false)
		--	control.m_label:SetHidden(true)
		--	control:SetMouseEnabled(false)
		--elseif divider then
		--	divider:SetHidden(true)
		--end
	end
	dataType1.setupCallback = SetupEntry
	dataType2.setupCallback = SetupEntry

	-- add data type for dividers, tho we don't bother with a special "LAST_" entry
	local function SetupDividerEntry(control, data, list)
		control.m_owner = data.m_owner
		control.m_data = data
		control.m_label = control:GetNamedChild("Label")
		control.m_label:SetHidden(true)

		control:SetHeight(DIVIDER_ENTRY_HEIGHT)

		local divider = control.m_divider
		if not divider then
			divider = wm:CreateControlFromVirtual("$(parent)Divider", control, "ZO_BaseTooltipDivider")
			divider:ClearAnchors()
			divider:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 2)
			divider:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 2)
			divider:SetHidden(false)
			control.m_divider = divider
		end
		control:SetMouseEnabled(false)
	end
	ZO_ScrollList_AddDataType(dropdown.m_scroll, DIVIDER_ENTRY_ID, "ZO_ScrollableComboBoxItem", DIVIDER_ENTRY_HEIGHT, SetupDividerEntry)

	-- make sure spacing is updated for dividers
	local function SetSpacing(dropdown, spacing)
		local newHeight = DIVIDER_ENTRY_HEIGHT + spacing
		ZO_ScrollList_UpdateDataTypeHeight(dropdown.m_scroll, DIVIDER_ENTRY_ID, newHeight)
	end
	ZO_PreHook(dropdown, "SetSpacing", SetSpacing)

	-- NOTE: changed to completely override the function
	dropdown.AddMenuItems = function() self:AddMenuItems() end

end

--
function ScrollableDropdownHelper:AddMenuItems()
	local combobox = self.combobox
	local dropdown = self.dropdown

	-- adjust dimensions based on entries
	local maxWidth, dividers = self:GetMaxWidth()
	local width = PADDING * 2 + zo_max(maxWidth, combobox:GetWidth()) + CONTENT_PADDING -- always add this now
	local visibleItems = #dropdown.m_sortedItems
	local anchorOffset = 0
	local dividerOffset = 0
	if(visibleItems > self.visibleRows) then
		width = width + SCROLLBAR_PADDING
		anchorOffset = -SCROLLBAR_PADDING
		visibleItems = self.visibleRows
	else -- account for divider height difference when we shrink the height
		dividerOffset = dividers * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - DIVIDER_ENTRY_HEIGHT)
	end

	local scroll = dropdown.m_dropdown:GetNamedChild("Scroll")
	local scrollContent = scroll:GetNamedChild("Contents")
	scrollContent:SetAnchor(BOTTOMRIGHT, nil, nil, anchorOffset)

	local height = dropdown:GetEntryTemplateHeightWithSpacing() * (visibleItems - 1) + ZO_SCROLLABLE_ENTRY_TEMPLATE_HEIGHT + (SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2) - dividerOffset
	dropdown.m_dropdown:SetWidth(width)
	dropdown.m_dropdown:SetHeight(height)

	-- NOTE: the whole reason we need to override it completely, to add our divider data entry
	local function CreateEntry(self, item, index, isLast)
		item.m_index = index
		item.m_owner = self
		local entryType = item.name == lib.DIVIDER and DIVIDER_ENTRY_ID or isLast and LAST_ENTRY_ID or ENTRY_ID
		return ZO_ScrollList_CreateDataEntry(entryType, item)
	end

	-- original code
	ZO_ScrollList_Clear(dropdown.m_scroll)

	local numItems = #dropdown.m_sortedItems
	local dataList = ZO_ScrollList_GetDataList(dropdown.m_scroll)

	for i = 1, numItems do
		local item = dropdown.m_sortedItems[i]
		local entry = CreateEntry(dropdown, item, i, i == numItems)
		table.insert(dataList, entry)
	end

	ZO_ScrollList_Commit(dropdown.m_scroll)
end


function ScrollableDropdownHelper:OnShow()
	local dropdown = self.dropdown
	if dropdown.m_lastParent ~= ZO_Menus then
		dropdown.m_lastParent = dropdown.m_dropdown:GetParent()
		dropdown.m_dropdown:SetParent(ZO_Menus)
		ZO_Menus:BringWindowToTop()
	end
end

function ScrollableDropdownHelper:OnHide()
	local dropdown = self.dropdown
	if dropdown.m_lastParent then
		dropdown.m_dropdown:SetParent(dropdown.m_lastParent)
		dropdown.m_lastParent = nil
	end

	 -- NOTE: do we really want this here???
	if self.parent then -- submenus won't have a parent for their scroll helper
		lib.submenu:Clear()
	end
end

function ScrollableDropdownHelper:DoHide()
	local dropdown = self.dropdown
	if dropdown:IsDropdownVisible() then
		dropdown:HideDropdown()
	end
end

function ScrollableDropdownHelper:GetMaxWidth()
	local dropdown = self.dropdown
	local dataType = ZO_ScrollList_GetDataTypeTable(dropdown.m_scroll, 1)

	local dummy = dataType.pool:AcquireObject()
	dataType.setupCallback(dummy, {
		m_owner = dropdown,
		name = "Dummy"
	}, dropdown)

	local dividers = 0
	local maxWidth = 0
	local label = dummy.m_label
	local entries = dropdown.m_sortedItems
	local numItems = #entries
	for index = 1, numItems do
		local name = entries[index].name
		if name == lib.DIVIDER then
			dividers = dividers + 1
		elseif entries[index].checked ~= nil then
			name = string.format(" |u18:0::|u%s", name)
		end
		label:SetText(name)
		local width = label:GetTextWidth() + TEXT_PADDING
		if (width > maxWidth) then
			maxWidth = width
		end
	end

	dataType.pool:ReleaseObject(dummy.key)
	return maxWidth, dividers
end

function ScrollableDropdownHelper:OnMouseEnter(control)
	-- show tooltip
	local data = ZO_ScrollList_GetData(control)
	if data.tooltip then
		InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, BOTTOMRIGHT)
		SetTooltipText(InformationTooltip, GetValueOrCallback(data.tooltip, data))
		InformationTooltipTopLevel:BringWindowToTop()
	end
	if data.disabled then
		return true
	end
end
function ScrollableDropdownHelper:OnMouseExit(control)
	-- hide tooltip
	local data = ZO_ScrollList_GetData(control)
	if data.tooltip then
		ClearTooltip(InformationTooltip)
	end
	if data.disabled then
		return true
	end
end



local submenuDepth = 0
local submenus = {}
local ScrollableSubmenu = ZO_Object:Subclass()

local function GetScrollableSubmenu(depth)
	if depth > #submenus then
		table.insert(submenus, ScrollableSubmenu:New())
	end
	return submenus[depth]
end

function ScrollableSubmenu:New(...)
	local object = ZO_Object.New(self)
	object:Initialize(...)
	return object
end

function ScrollableSubmenu:Initialize()

	submenuDepth = submenuDepth + 1
	local submenuControl = WINDOW_MANAGER:CreateControl(ROOT_PREFIX..submenuDepth, ZO_Menus, CT_CONTROL)
	submenuControl:SetClampedToScreen(true)
	submenuControl:SetMouseEnabled(true)
	submenuControl:SetHidden(true)
	submenuControl:SetDimensions(135, 31)
	submenuControl:SetHandler("OnHide", function(control) ClearTimeout() self:Clear() end)
	submenuControl:SetDrawLevel(ZO_Menu:GetDrawLevel() + 1)
	--submenuControl:SetExcludeFromResizeToFitExtents(true)

	local scrollableDropdown = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Dropdown", submenuControl, "ZO_ScrollableComboBox")
	scrollableDropdown:SetAnchor(TOPLEFT, submenuControl, TOPLEFT, 0, 0)
	-- hide the combobox itself
	--scrollableDropdown:GetNamedChild("BG"):SetHidden(true)
	scrollableDropdown:GetNamedChild("SelectedItemText"):SetHidden(true)
	scrollableDropdown:GetNamedChild("OpenDropdown"):SetHidden(true)
	--scrollableDropdown:SetExcludeFromResizeToFitExtents(true)
	self.combobox = scrollableDropdown

	self.dropdown = ZO_ComboBox_ObjectFromContainer(scrollableDropdown)
	self.dropdown.m_submenu = self

	self.dropdown.SetSelected = function(dropdown, index)
		local parentDropdown = lib.submenu.owner.m_comboBox
		parentDropdown:ItemSelectedClickHelper(dropdown.m_sortedItems[index])
		parentDropdown:HideDropdown()
	end

	-- nesting
	self.depth = submenuDepth
	self.parentMenu = GetScrollableSubmenu(submenuDepth - 1)
	if self.parentMenu then
		self.parentMenu.childMenu = self
	end

	-- for easier access
	self.control = submenuControl
	self.control.dropdown = self.dropdown
	self.control.combobox = scrollableDropdown

	self.scrollHelper = ScrollableDropdownHelper:New(nil, self.control, 10) --don't need parent for this

	--self.scrollHelper.OnShow = function() end
	self.control.scrollHelper = self.scrollHelper
	self.control.submenu = self
end

function ScrollableSubmenu:GetChild(canCreate)
	if not self.childMenu and canCreate then
		self.childMenu = GetScrollableSubmenu(self.depth + 1)
	end
	return self.childMenu
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

function ScrollableSubmenu:ClearItems()
	self.dropdown:ClearItems()
end

function ScrollableSubmenu:IsVisible()
	return not self.control:IsControlHidden()
end

local TOP_MOST = true
function ScrollableSubmenu:GetOwner(topmost)
	if topmost and self.parentMenu then
		return self.parentMenu:GetOwner(topmost)
	else
		return self.owner
	end
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


function ScrollableSubmenu:AnchorToControl(parentControl)
	local myControl = self.control.dropdown.m_dropdown
	myControl:ClearAnchors()

	local parentDropdown = self:GetOwner().m_comboBox.m_dropdown

	local anchorPoint = LEFT
	local anchorOffset = 0

	if self.parentMenu then
		anchorPoint = self.parentMenu.anchorPoint
	elseif (parentControl:GetRight() + myControl:GetWidth()) < GuiRoot:GetRight() then
		anchorPoint = RIGHT
	end

	if anchorPoint == RIGHT then
		anchorOffset = parentDropdown:GetWidth() - parentControl:GetWidth() - PADDING * 2
	end

	myControl:SetAnchor(TOP + (10 - anchorPoint), parentControl, TOP + anchorPoint, anchorOffset)
	self.anchorPoint = anchorPoint
	myControl:SetHidden(false)
end

function ScrollableSubmenu:Show(parentControl)

	local owner = GetContainerFromControl(parentControl)
	self:SetOwner(owner)

	local data = ZO_ScrollList_GetData(parentControl)
	self:AddItems(GetValueOrCallback(data.entries, data)) -- "self:GetOwner(TOP_MOST)", remove TOP_MOST if we want to pass the parent submenu control instead
	ZO_Scroll_ResetToTop(self.dropdown.m_scroll)

	self:AnchorToControl(parentControl)

	self:ClearChild()
	self.dropdown:ShowDropdownOnMouseUp()

	return true
end

function ScrollableSubmenu:Clear()
	self:ClearItems()
	self:SetOwner(nil)
	self.control:SetHidden(true)
	self:ClearChild()
end

function ScrollableSubmenu:ClearChild()
	if self.childMenu then
		self.childMenu:Clear()
	end
end


---------------------------------------------------------
-- Actual hooks needed for ZO_ScrollableComboBox itself
---------------------------------------------------------
local function HookScrollableEntry()

	local function ScrollableEntry_OnMouseEnter(control)
		local data = ZO_ScrollList_GetData(control)
		local mySubmenu = GetSubmenuFromControl(control)

		if data.entries then
			ClearTimeout()
			if mySubmenu then -- open next submenu
				local childMenu = mySubmenu:GetChild(true) -- create if needed
				if childMenu then
					childMenu:Show(control)
				else
					lib.submenu:Show(control)
				end
			else
				lib.submenu:Show(control)
			end
		elseif mySubmenu then
			ClearTimeout()
			mySubmenu:ClearChild()
		else
			lib.submenu:Clear()
		end
	end

	local function OnMouseExitTimeout()
		local control = moc()
		local name = control and control:GetName()
		if name and zo_strfind(name, ROOT_PREFIX) == 1 then
			--TODO: check for matching depth??
		else
			lib.submenu:Clear()
		end
	end

	local function ScrollableEntry_OnMouseExit(control)
		-- just close all submenus
		if not lib.GetPersistentMenus() then
			SetTimeout( OnMouseExitTimeout )
		end
	end
	ZO_PreHook("ZO_ScrollableComboBox_Entry_OnMouseEnter", ScrollableEntry_OnMouseEnter)
	ZO_PreHook("ZO_ScrollableComboBox_Entry_OnMouseExit",  ScrollableEntry_OnMouseExit)

	local function ScrollableEntry_OnSelected(control)
		local data = ZO_ScrollList_GetData(control)
		local mySubmenu = GetSubmenuFromControl(control)
		if data.entries then
			local targetSubmenu = lib.submenu
			if mySubmenu and mySubmenu.childMenu then
				targetSubmenu = mySubmenu.childMenu
			end
			if targetSubmenu then
				if targetSubmenu:IsVisible() then
					targetSubmenu:Clear() -- need to clear it straight away, no timeout
				else
					-- just calling this to not have to copy code
					ScrollableEntry_OnMouseEnter(control)
				end
			end
			return true
		elseif data.checked ~= nil then
			ZO_CheckButton_OnClicked(control.m_checkbox)
			return true
		end
	end
	ZO_PreHook("ZO_ScrollableComboBox_Entry_OnSelected", ScrollableEntry_OnSelected)

	-- Now watch for mouse clicks outside of the submenu (if it's persistant)
	local function MouseIsOverDropdownOrSubmenu(dropdown)
		if MouseIsOver(dropdown.m_dropdown) then
			return true
		end
		local submenu = lib.submenu
		while submenu do
			if MouseIsOver(submenu.dropdown.m_dropdown) then
				return true
			end
			submenu = submenu:GetChild()
		end
		return false
	end

	ZO_ScrollableComboBox.OnGlobalMouseUp = function(self, _, button)
		if self:IsDropdownVisible() then
			if button == MOUSE_BUTTON_INDEX_LEFT and not MouseIsOverDropdownOrSubmenu(self) then
				self:HideDropdown()
			end
		elseif self.m_container:IsHidden() then
			self:HideDropdown()
		else
			self:ShowDropdownOnMouseUp()
		end
	end

end


---- Init -----

local function OnAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EVENT_MANAGER:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
	lib.submenu = GetScrollableSubmenu(1)
	HookScrollableEntry()
end

EVENT_MANAGER:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
EVENT_MANAGER:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, OnAddonLoaded)

LibScrollableMenu = lib