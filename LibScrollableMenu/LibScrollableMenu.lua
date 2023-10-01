if LibScrollableMenu ~= nil then return end -- the same or newer version of this lib is already loaded into memory

local lib = ZO_CallbackObject:New()
lib.name = "LibScrollableMenu"
local MAJOR = lib.name
lib.version = "1.2"

lib.data = {}

if not lib then return end

lib.DIVIDER = "-"
lib.HELPER_MODE_NORMAL = 0
lib.HELPER_MODE_LAYOUT_ONLY = 1 -- means only the layout of the dropdown will be altered, not the way it handles layering through ZO_Menus

--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
local wm = WINDOW_MANAGER
local em = EVENT_MANAGER

local origSoundComboClicked = SOUNDS.COMBO_CLICK
local soundComboClickedSilenced = SOUNDS.NONE

local SUBMENU_ITEM_MOUSE_ENTER = 1
local SUBMENU_ITEM_MOUSE_EXIT = 2
local SUBMENU_SHOW_TIMEOUT = 350
local SUBMENU_HIDE_TIMEOUT = 350

local ROOT_PREFIX = MAJOR.."Sub"

local submenuCallLaterHandle
local nextId = 1

local DIVIDER_ENTRY_HEIGHT = 7
local HEADER_ENTRY_HEIGHT = 25

local DEFAULT_VISIBLE_ROWS = 10
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = 25 -- same as in zo_combobox.lua
local TEXT_PADDING = 4
local CONTENT_PADDING = 18 -- decreased from 24
local SCROLLBAR_PADDING = 16

local ICON_PADDING = 0

local NO_ICON_PADDING = -5
local ICON_PADDING = 20

local MAX_MENU_WIDTH
local PADDING = GetMenuPadding() / 2 -- half the amount looks closer to the regular dropdown
local ROUNDING_MARGIN = 0.01 -- needed to avoid rare issue with too many anchors processed

local SCROLLABLE_COMBO_BOX_LIST_PADDING_Y = 9


local ENTRY_ID = 1
local LAST_ENTRY_ID = 2
local DIVIDER_ENTRY_ID = 3
local HEADER_ENTRY_ID = 4
local SUBMENU_ENTRY_ID = 5
--Make them accessible for the ScrollableDropdownHelper:New options table -> options.XMLRowTemplates 
lib.scrollListRowTypes = {
	ENTRY_ID = ENTRY_ID,
	LAST_ENTRY_ID = LAST_ENTRY_ID,
	DIVIDER_ENTRY_ID = DIVIDER_ENTRY_ID,
	HEADER_ENTRY_ID = HEADER_ENTRY_ID,
	SUBMENU_ENTRY_ID = SUBMENU_ENTRY_ID,
}

--------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------
local function ClearTimeout()
	if (submenuCallLaterHandle ~= nil) then
		em:UnregisterForUpdate(submenuCallLaterHandle)
		submenuCallLaterHandle = nil
	end
end

local function SetTimeout(callback)
	if (submenuCallLaterHandle ~= nil) then ClearTimeout() end
	submenuCallLaterHandle = MAJOR.."Timeout" .. nextId
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

local function GetOption(options, value, default)
	return options and options[value] or default
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

local function GetOptionsForEntry(entry)
	local entrysComboBox = GetContainerFromControl(entry)
	return entrysComboBox ~= nil and entrysComboBox.options
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
	local options = GetOptionsForEntry(entry)
	if options ~= nil then
		--Chosen at options to play no selected sound?
		if GetValueOrCallback(options.selectedSoundDisabled, options) == true then
			silenceComboBoxClickedSound(true)
			return
		else
			soundToPlay = GetValueOrCallback(options.selectedSound, options)
			soundToPlay = soundToPlay or SOUNDS.COMBO_CLICK
		end
	end
	PlaySound(soundToPlay) --SOUNDS.COMBO_CLICK
end

-- Loop through, if needed, to find any entry set as new.
local function areAnyEntriesNew(entry)
	local new = false
	if entry.entries ~= nil then
		for k, subentry in pairs(entry.entries) do
			if subentry.isNew then
				new = true
				break
			end
			if subentry.entries then
				return areAnyEntriesNew(subentry)
			end
		end
	else
		new = entry.isNew
	end
	return new
end

local function setMaxMenuWidth()
    local uiWidth, uiHeight = GuiRoot:GetDimensions()
	MAX_MENU_WIDTH = uiWidth * 0.2
end
setMaxMenuWidth()
EVENT_MANAGER:RegisterForEvent(lib.name, EVENT_SCREEN_RESIZED, setMaxMenuWidth)

--	/script d(GuiRoot:GetDimensions() * 0.1)
--------------------------------------------------------------------
-- List data type templates
--------------------------------------------------------------------
local defaultXMLTemplates
do
	-- was planning on moving ScrollableDropdownHelper:AddDataTypes() and
	-- all the template stuff wrapped up in here
end
defaultXMLTemplates  = {
	[ENTRY_ID] = {
		template = 'LibScrollableMenu_ComboBoxEntry',
	--	setupFunc = ,
	},
	[LAST_ENTRY_ID] = {
		template = 'LibScrollableMenu_ComboBoxEntry',
	--	setupFunc = ,
	},
	[SUBMENU_ENTRY_ID] = {
		template = 'LibScrollableMenu_ComboBoxEntrySubmenu',
--		setupFunc = ,
	},
	[DIVIDER_ENTRY_ID] = {
		template = 'LibScrollableMenu_ComboBoxEntryDivider',
--		setupFunc = ,
	},
	[HEADER_ENTRY_ID] = {
		template = 'LibScrollableMenu_ComboBoxHeaderEntry', --LibScrollableMenu_ComboBoxEntryHeader
--		setupFunc = ,
	},
}


------------------------------------------------------------------------------------------------------------------------
-- ScrollableDropdownHelper
------------------------------------------------------------------------------------------------------------------------
local ScrollableDropdownHelper = ZO_InitializingObject:Subclass()
lib.ScrollableDropdownHelper = ScrollableDropdownHelper

-- Available options are:
--   visibleRowsDropdown	Visible rows at the scollable list, for the main menu scroll helper
--	 visibleRowsSubmenu		Visible rows at the scollable list of submenu helpers of this main menu scroll helper
--[[
--   persistantMenus - its submenus won't close when the mouse exits them, only by clicking somewhere or selecting something else
--   orientation - the preferred direction for tooltips and submenus (either LEFT or RIGHT)
]]

-- Split the data types out
function ScrollableDropdownHelper:Initialize(parent, control, options, isSubMenuScrollHelper)
	isSubMenuScrollHelper = isSubMenuScrollHelper or false

	--Read the passed in options table
	local visibleRows, visibleRowsSubmenu
	if options ~= nil then
		if type(options) == "table" then
			visibleRows = GetValueOrCallback(options.visibleRowsDropdown, options)
			visibleRowsSubmenu = GetValueOrCallback(options.visibleRowsSubmenu, options)
			control.options = options
			self.options = options
		else
			--Backwards compatibility with AddOns using older library version ScrollableDropdownHelper:Initialize where options was the visibleRows directly
			visibleRows = options
		end
	end
	visibleRows = visibleRows or DEFAULT_VISIBLE_ROWS
	visibleRowsSubmenu = visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS

	local combobox = control.combobox
	local dropdown = control.dropdown

--todo: For debugging!
lib._control = control
lib._combobox = combobox
lib._dropdown = dropdown
lib._selfScrollHelper = self

	self.parent = parent
	self.control = control
	self.combobox = combobox
	self.dropdown = dropdown
	self.visibleRows = visibleRows					--Will be nil for a submenu!
	self.visibleRowsSubmenu = visibleRowsSubmenu
	self.isSubMenuScrollHelper = isSubMenuScrollHelper
	--Not a submenu? Add the reference to our ScrollHelper object to the combobox's control/container
	--so we can read it via the Submenu's "owner" (= the combobox control) .parentScrollableDropdownHelper again
	if not isSubMenuScrollHelper then
		control.parentScrollableDropdownHelper = self
	end
	--self.visibleRows = GetOption(options, "visibleRows", DEFAULT_VISIBLE_ROWS)
	--self.mode        = GetOption(options, "mode", lib.HELPER_MODE_NORMAL)

	-- clear anchors so we can adjust the width dynamically
	dropdown.m_dropdown:ClearAnchors()
	dropdown.m_dropdown:SetAnchor(TOPRIGHT, combobox, BOTTOMRIGHT)

	-- handle dropdown or settingsmenu opening/closing
	-- I would prefer to add these to a class
	local function onShow() self:OnShow() end
	local function onHide() self:OnHide() end
	local function doHide() self:DoHide() end

	ZO_PreHook(dropdown,"ShowDropdownOnMouseUp", onShow)
	ZO_PreHook(dropdown,"HideDropdownInternal", onHide)
	combobox:SetHandler("OnEffectivelyHidden", onHide)
	if parent then parent:SetHandler("OnEffectivelyHidden", doHide) end

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
	local function SetSpacing(dropdown, spacing)
		local newHeight = DIVIDER_ENTRY_HEIGHT + spacing
		ZO_ScrollList_UpdateDataTypeHeight(mScroll, DIVIDER_ENTRY_ID, newHeight)
	end
	ZO_PreHook(dropdown, "SetSpacing", SetSpacing)

	-- NOTE: changed to completely override the function
	dropdown.AddMenuItems = function() self:AddMenuItems() end
	
	--Add the dataTypes to the scroll list (normal row, last row, header row, submenu row)
	self:AddDataTypes()

	--Hooks
	--Disable the SOUNDS.COMBO_CLICK upon item selected. Will be handled via options table AND
	--function LibScrollableMenu_OnSelected below!
	--...
	--Reenable the sound for comboBox select item again
	SecurePostHook(dropdown, "SelectItem", function()
		silenceComboBoxClickedSound(false)
	end)


end

-- With multi icon
function ScrollableDropdownHelper:AddDataTypes()
	local dropdown = self.dropdown
	local options = self.options or {}

	--Were any options and XMLRowTemplates passed in?
	local optionTemplates = options and GetValueOrCallback(options.XMLRowTemplates, options)
	local XMLrowTemplatesToUse = defaultXMLTemplates
	--Check if all XML row templates are passed in, and update missing ones with default values
	if optionTemplates ~= nil then
		XMLrowTemplatesToUse = {}
		for entryType, defaultData in pairs(defaultXMLTemplates) do
			XMLrowTemplatesToUse[entryType] = {}
			if optionTemplates[entryType] == nil or optionTemplates[entryType].template == nil then
				XMLrowTemplatesToUse[entryType] = defaultData
			else
				XMLrowTemplatesToUse[entryType] = optionTemplates[entryType]
			end
		end
	end
	
	local mScroll = dropdown.m_scroll
	-- dont fade entries near the edges
	
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

	local dataType1 = ZO_ScrollList_GetDataTypeTable(mScroll, 1)
	--local dataType2 = ZO_ScrollList_GetDataTypeTable(mScroll, 2)
	--Determine the original setupCallback for the list row -> Maybe default's ZO:ComboBox one, but maybe even changed by any addon -> Depends on the
	--combobox this ScrollHelper was added to!
	local oSetup = dataType1.setupCallback -- both data types 1 (normal row) and 2 (last row) use the same setup function. See ZO_ComboBox.lua, ZO_ComboBox:SetupScrollList()
 
	local function SetupEntry(control, data, list)
		--Check if the data.name is a function returning a string, so prepare the String value now
		--and update the original function for later usage to data.oName
		local oName = data.name
		local name = GetValueOrCallback(data.name, data)
		if oName ~= name then
			data.oName = oName
			data.name = name
		end

		--Reference original setupCallback for the list row
		local oSetup = control.oSetup or oSetup
		control.oSetup = oSetup
		--Call original callback function -> e.g.  ZO_ComboBox.lua, SetupScrollableEntry(control, data, list)
		-->To set the data.name to teh control's label, and update the selection highlight etc.
		oSetup(control, data, list)

		--Passed in an alternative text/function returning a text to show at the label control of the menu entry?
		if data.label ~= nil then
			local labelStr = GetValueOrCallback(data.label, data)
			data.labelStr = labelStr
			control.m_label:SetText(labelStr) -- Override the label's text with the String created from data.label, if provided
		end

		--From: ZO_Combobox.lua, ZO_ComboBox:SetupScrollList()
		control.m_owner = data.m_owner
		local mOwner = control.m_owner --local reference -> Speed
		--control.m_label = control:GetNamedChild("Label") -- was set in oSetup already

		--Set the font and color
		self.font = mOwner.m_font
		
		control.m_owner = data.m_owner
		control.m_arrow = control:GetNamedChild("Arrow")
		control.m_icon = control:GetNamedChild("Icon")

		local hasSubmenu = data.entries ~= nil
		data.hasSubmenu = hasSubmenu
		if control.m_arrow then
			control.m_arrow:SetHidden(not hasSubmenu)
		end
		
		if data.label ~= nil then
			local labelStr = GetValueOrCallback(data.label, data)
			data.labelStr = labelStr
			control.m_label:SetText(labelStr) -- Override the label's text with the data.label, if provided
		end
		
		-- This is for the mouse-over tooltips
		if not control.hookedMouseHandlers then --only do it once per control
			control.hookedMouseHandlers = true
			ZO_PreHookHandler(control, "OnMouseEnter", onMouseEnter)
			ZO_PreHookHandler(control, "OnMouseExit", onMouseExit)
		end
		control.m_label:SetFont(control.m_owner.m_font)
		ScrollableDropdownHelper.UpdateIcons(control, data)
		
	--	control.m_label:SetColor(control.m_owner.m_normalColor:UnpackRGBA())
		
		-- if a menu never uses "checked" then it will never create these controls
		if data.checked ~= nil then
			local checkbox = control.m_checkbox
			if not checkbox then
				checkbox = wm:CreateControlFromVirtual("$(parent)Checkbox", control, "ZO_CheckButton")
				checkbox:SetAnchor(LEFT, nil, LEFT, 2, -1)
				checkbox:SetHandler("OnMouseEnter", function(checkbox) ZO_ComboBox_Entry_OnMouseEnter(control) end)
				checkbox:SetHandler("OnMouseExit", function(checkbox) ZO_ComboBox_Entry_OnMouseExit(control) end)
				control.m_checkbox = checkbox
			end
			checkbox:SetHidden(false)
			ZO_CheckButton_SetToggleFunction(checkbox, setChecked)
			ZO_CheckButton_SetCheckState(checkbox, GetValueOrCallback(data.checked, data))
			control.m_label:SetText(string.format(" |u18:0::|u%s", data.labelStr or data.name))
		elseif control.m_checkbox then
			control.m_checkbox:SetHidden(true)
		end
		
		control.m_data = data --update changed (after oSetup) data entries to the control, and other entries have been updated
	end
	--Overwrite(remove) the list's data types for entry and last entry: Set nil
	mScroll.dataTypes[ENTRY_ID] = nil
	mScroll.dataTypes[LAST_ENTRY_ID] = nil

	--Add the list's data types for entry and last entry again, this time with our custom setupCallback function "SetupEntry"
    local entryHeight = dropdown:GetEntryTemplateHeightWithSpacing()
	
    ZO_ScrollList_AddDataType(mScroll, ENTRY_ID, 			XMLrowTemplatesToUse[ENTRY_ID].template, 			entryHeight, SetupEntry)
    ZO_ScrollList_AddDataType(mScroll, LAST_ENTRY_ID, 		XMLrowTemplatesToUse[LAST_ENTRY_ID].template, 		entryHeight, SetupEntry)
	ZO_ScrollList_AddDataType(mScroll, SUBMENU_ENTRY_ID, 	XMLrowTemplatesToUse[SUBMENU_ENTRY_ID].template, 	entryHeight, SetupEntry)

	-- add data type for dividers, tho we don't bother with a special "LAST_" entry
	local function SetupDividerEntry(control, data, list)
		control.m_owner = data.m_owner
		control.m_data = data
		control.m_divider  = control:GetNamedChild("Divider")
		control.m_divider:SetHidden(false)
	end
	ZO_ScrollList_AddDataType(mScroll, DIVIDER_ENTRY_ID, 	XMLrowTemplatesToUse[DIVIDER_ENTRY_ID].template, 	DIVIDER_ENTRY_HEIGHT, SetupDividerEntry)
	
	-- add data type for headers - based on ZO_AddOnSectionHeaderRow
	local function SetupHeaderEntry(control, data, list)
		control.isHeader = true
		control.m_owner = data.m_owner
		control.m_data = data

		control:SetHeight(HEADER_ENTRY_HEIGHT)
		
		local divider = control:GetNamedChild("Divider")
		control.m_divider = divider

		local label = control:GetNamedChild("Label")
		control.m_label = label
--		label:SetFont("ZoFontWinH5") -- Header font
--		label.normalColor = ZO_WHITE

		local oName = data.name
		local name = GetValueOrCallback(data.name, data)
		if oName ~= name then
			data.oName = oName
			data.name = name
		end

		--Passed in an alternative text/function returning a text to show at the label control of the menu entry?
		if data.label ~= nil then
			local labelStr = GetValueOrCallback(data.label, data)
			data.labelStr = labelStr
		end

		label:SetText(data.labelStr or data.name)
		control.m_icon = control:GetNamedChild("Icon")
		ScrollableDropdownHelper.UpdateIcons(control, data)
	end
	
	ZO_ScrollList_AddDataType(mScroll, HEADER_ENTRY_ID, 	XMLrowTemplatesToUse[HEADER_ENTRY_ID].template, 	HEADER_ENTRY_HEIGHT, SetupHeaderEntry)
	ZO_ScrollList_SetTypeSelectable(mScroll, HEADER_ENTRY_ID, false)
--	ZO_ScrollList_SetTypeCategoryHeader(mScroll, HEADER_ENTRY_ID, true)
end

function ScrollableDropdownHelper:UpdateIcons(data)
	local visible = data.isNew or data.icon ~= nil
	local iconSize = visible and self.m_icon:GetParent():GetHeight() or 4
	
	self.m_icon:ClearIcons()
	if visible then
		if data.isNew then
			self.m_icon:AddIcon(ZO_KEYBOARD_NEW_ICON)
		end
		
		if data.icon then
			self.m_icon:AddIcon(data.icon)
		end
		self.m_icon:Show()
	end
	
	-- Using the control also as a padding. if no icon then shrink it
	-- This also allows for keeping the icon in size with the row height.
	self.m_icon:SetDimensions(iconSize, iconSize)
	self.m_icon:SetHidden(not visible)
end

-- Add the MenuItems to the list (also for submenu lists!)
function ScrollableDropdownHelper:AddMenuItems()
	local combobox = self.combobox
	local dropdown = self.dropdown
	
	local dividers = 0
	local headers = 0
	local maxWidth = 0
	local anchorOffset = -5
	local dividerOffset = 0
	local headerOffset = 0
	local largestEntryWidth = 0
	
	-- NOTE: the whole reason we need to override it completely, to add our divider and header data entry
	local function CreateEntry(self, item, index, isLast)
		item.m_index = index
		item.m_owner = self
				
		local entryType = (item.name == lib.DIVIDER and DIVIDER_ENTRY_ID) or (item.isHeader and HEADER_ENTRY_ID) or 
			(item.entries and SUBMENU_ENTRY_ID) or (isLast and LAST_ENTRY_ID) or ENTRY_ID
		if item.entries then
			item.hasSubmenu = true
			item.isNew = areAnyEntriesNew(item)
		end
		return ZO_ScrollList_CreateDataEntry(entryType, item)
	end
	
	ZO_ScrollList_Clear(dropdown.m_scroll)

	local dataList = ZO_ScrollList_GetDataList(dropdown.m_scroll)

	local visibleItems = #dropdown.m_sortedItems
	for i = 1, visibleItems do
		local item = dropdown.m_sortedItems[i]
		local entry = CreateEntry(dropdown, item, i, i == visibleItems)
		table.insert(dataList, entry)
		
		-- Here the width is calculated while the list is being populated. 
		-- It also makes it so the for loop on m_sortedItems is not done more than once per run
		maxWidth, dividers, headers = self:GetMaxWidth(item, maxWidth, dividers, headers)
		if maxWidth > largestEntryWidth then
			largestEntryWidth = maxWidth
		end
	end
	
	local visibleRows =  (self.isSubMenuScrollHelper and
			(lib.submenu and lib.submenu.parentScrollableDropdownHelper and lib.submenu.parentScrollableDropdownHelper.visibleRowsSubmenu)) or self.visibleRows

	-- using the exact width of the text can leave us with pixel rounding issues
	-- so just add 5 to make sure we don't truncate at certain screen sizes
--	largestEntryWidth = largestEntryWidth + 5
	
	local scrollbarEnabled = false
	if(visibleItems > visibleRows - 1) then
		scrollbarEnabled = true
		largestEntryWidth = largestEntryWidth + ZO_SCROLL_BAR_WIDTH
		anchorOffset = -ZO_SCROLL_BAR_WIDTH
		visibleItems = visibleRows
	else -- account for divider height difference when we shrink the height
		dividerOffset = dividers * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - DIVIDER_ENTRY_HEIGHT)
		headerOffset = headers * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - HEADER_ENTRY_HEIGHT)
	end
	
	-- Allow the dropdown to automatically widen to fit the widest entry, but
	-- prevent it from getting any skinnier than the container's initial width
--	local totalDropDownWidth = largestEntryWidth + ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2 + ZO_SCROLL_BAR_WIDTH
	-- I don't know if there's a difference in dropdown.m_containerWidth and combobox:GetWidth(). I left the if in there since zos used it to force a min with based on the container,
--	local totalDropDownWidth = PADDING * 2 + zo_max(largestEntryWidth, combobox:GetWidth()) + CONTENT_PADDING
	local totalDropDownWidth = PADDING * 2 + largestEntryWidth + CONTENT_PADDING
	
	if totalDropDownWidth > dropdown.m_containerWidth then
		dropdown.m_dropdown:SetWidth(totalDropDownWidth)
	else
		dropdown.m_dropdown:SetWidth(dropdown.m_containerWidth)
	end
	
	local scroll = dropdown.m_dropdown:GetNamedChild("Scroll")
	local scrollContent = scroll:GetNamedChild("Contents")
	scrollContent:ClearAnchors()
	scrollContent:SetAnchor(TOPLEFT)
	scrollContent:SetAnchor(BOTTOMRIGHT, nil, nil, anchorOffset)

	local maxHeight = dropdown.m_height
	-- get the height of all the entries we are going to show
	-- the last entry uses a separate entry template that does not include the spacing in its height
	--	local allItemsHeight = dropdown:GetEntryTemplateHeightWithSpacing() * (visibleItems - 1) + ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2)
	local entryTemplateHeightOfAll = dropdown:GetEntryTemplateHeightWithSpacing() * visibleItems
	local allItemsHeight = entryTemplateHeightOfAll + (SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2) - dividerOffset - headerOffset --+ ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT

	local desiredHeight = maxHeight
	if scrollbarEnabled == true then
		--Enlarge menu height if more rows as maxVisible should be shown
		if allItemsHeight > desiredHeight then
			desiredHeight = allItemsHeight
		end
	else
		--Shrink menu height if only a few rows of maxVisible should be shown
		if allItemsHeight < desiredHeight then
			desiredHeight = allItemsHeight
		else
			--Show all rows (e.g. if 20 rows could be shown but currently only 17 entries exist.
			--But the menu's height is too low for 17 -> Increase to show all 17, without scrollbar)
			if dropdown.m_height < allItemsHeight then
				desiredHeight = allItemsHeight
			end
		end
	end

	dropdown.m_dropdown:SetHeight(desiredHeight)

	ZO_ScrollList_SetHeight(dropdown.m_scroll, desiredHeight)

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

function ScrollableDropdownHelper:GetMaxWidth(item, maxWidth, dividers, headers)
	local dropdown = self.dropdown
	local fontObject = _G[dropdown.m_font]
	-- I based this off of how the lib is using "item" in AddMenuItems and GetMaxWidth
	if item.name == lib.DIVIDER then
		dividers = dividers + 1
	elseif item.isHeader then
		headers = headers + 1
	end
	
	local labelStr = item.name
	if item.label ~= nil then
		labelStr = GetValueOrCallback(item.label, item)
	end
	
	local padding = (item.icon ~= nil or item.isNew) and ICON_PADDING or NO_ICON_PADDING
	local width = GetStringWidthScaled(fontObject, labelStr, 1, SPACE_INTERFACE) + padding
	width = zo_min(MAX_MENU_WIDTH, width)
	if (width > maxWidth) then
		maxWidth = width
	end
	
	return maxWidth, dividers, headers
end
--	/script LibScrollableMenuSub1DropdownDropdown:SetWidth(LibScrollableMenuSub1DropdownDropdown:GetWidth() + 10)
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

------------------------------------------------------------------------------------------------------------------------
-- ScrollableSubmenu
------------------------------------------------------------------------------------------------------------------------
local submenus = {}
local ScrollableSubmenu = ZO_InitializingObject:Subclass()

local function GetScrollableSubmenu(depth)
	if depth > #submenus then
		table.insert(submenus, ScrollableSubmenu:New(depth))
	end
	return submenus[depth]
end

function ScrollableSubmenu:Initialize(submenuDepth)
	local submenuControl = WINDOW_MANAGER:CreateControlFromVirtual(ROOT_PREFIX..submenuDepth, ZO_Menus, 'LibScrollableMenu_ComboBox')
	submenuControl:SetHidden(true)
	submenuControl:SetHandler("OnHide", function(control) ClearTimeout() self:Clear() end)
	submenuControl:SetDrawLevel(ZO_Menu:GetDrawLevel() + 1)
	--submenuControl:SetExcludeFromResizeToFitExtents(true)
	
	local scrollableDropdown = submenuControl:GetNamedChild('Dropdown')
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

	--don't need parent for this / leave visibleRows nil (defualt 10 will be used) / only use visibleSubmenuRows = 10 as default
	-->visibleSubmenuRows will be overwritten at ScrollableSubmenu:Show -> taken from parent's ScrollableDropdownHelper dropdown.visibleRowsSubMenu
	self.scrollHelper = ScrollableDropdownHelper:New(nil, self.control, nil, true)

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

local TOP_MOST = true -- not being used
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
	local anchorOffset = -3

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

function ScrollableSubmenu:Show(parentControl) -- parentControl is a row within another combobox's dropdown scrollable list
	local owner = GetContainerFromControl(parentControl)
	self:SetOwner(owner)

	--Get the owner's ScrollableDropdownHelper object and the visibleSubmenuRows attribute, and update this
	--ScrollableSubmenu's ScrollableDropdownHelper object with this owner data, as attribute .parentScrollableDropdownHelper
	self.parentScrollableDropdownHelper = owner.parentScrollableDropdownHelper

	--Get the owner's ScrollableDropdownHelper object and the visibleSubmenuRows attribute, and update this
	--ScrollableSubmenu's ScrollableDropdownHelper object with this owner data, as attribute .parentScrollableDropdownHelper
	self.parentScrollableDropdownHelper = owner and owner.parentScrollableDropdownHelper

	local data = ZO_ScrollList_GetData(parentControl)
	self:AddItems(GetValueOrCallback(data.entries, data)) -- "self:GetOwner(TOP_MOST)", remove TOP_MOST if we want to pass the parent submenu control instead
	ZO_Scroll_ResetToTop(self.dropdown.m_scroll)

	self:AnchorToControl(parentControl)

	self:ClearChild()
	self.dropdown:ShowDropdownOnMouseUp() --show the submenu's ScrollableDropdownHelper comboBox entries -> Calls self.dropdown:AddMenuItems()

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
	--Overwrite ZO_ComboBox.OnGlobalMouseUp to support submenu hide, if clicked somewhere
	ZO_ComboBox.OnGlobalMouseUp = function(self, _, button)
		if self:IsDropdownVisible() then
			if not MouseIsOverDropdownOrSubmenu(self) then
				self:HideDropdown()
			end
		else
			if self.m_container:IsHidden() then
				self:HideDropdown()
			else
				self:ShowDropdownOnMouseUp()
			end
		end
	end
end


------------------------------------------------------------------------------------------------------------------------
-- Public API functions
------------------------------------------------------------------------------------------------------------------------
lib.persistentMenus = false -- controls if submenus are closed shortly after the mouse exists them
function lib.GetPersistentMenus()
	return lib.persistentMenus
end
function lib.SetPersistentMenus(persistent)
	lib.persistentMenus = persistent
end

--[[
function lib.CreateEntry(name, icon, tooltip, callback)
	local submenu
	
	if type(callback) == 'table' then
		submenu = callback
		callback = nil
	end
	
	local newEntry = {
		name = name,
		icon = icon,
		callback = callback
		tooltip = toolTip, 
		entries = submenus, nil or table of submenu entries
	
	}
	return newEntry
end
/script LibScrollableMenuSub1DropdownDropdown:SetWidth(LibScrollableMenuSub1DropdownDropdown:GetWidth() - 10)
/script LibScrollableMenuSub1DropdownDropdown:SetWidth(LibScrollableMenuSub1DropdownDropdown:GetWidth() - 10)
]]


--Adds a scroll helper to the comboBoxControl dropdown entries, and enables submenus (scollable too) at the entries.
--	control parent 							Must be the parent control of the comboBox
--	control comboBoxControl 				Must be any ZO_ComboBox control (e.g. created from virtual template ZO_ComboBox)

--  table options:optional = {
--		number visibleRowsDropdown:optional		Number of shown entries at 1 page of the scrollable comboBox's opened dropdown
--		number visibleRowsSubmenu:optional		Number of shown entries at 1 page of the scrollable comboBox's opened submenus
--		table	XMLRowTemplates:optional		Table with key = row type of lib.scrollListRowTypes and the value = subtable having "template" String = XMLVirtualTemplateName
--		{
--			[lib.scrollListRowTypes.ENTRY_ID] = 		{ template = "XMLVirtualTemplateRow_ForEntryId", }
--			[lib.scrollListRowTypes.SUBMENU_ENTRY_ID] = { template = "XMLVirtualTemplateRow_ForSubmenuEntryId" },
--			...
--		}
--  }
function AddCustomScrollableComboBoxDropdownMenu(parent, comboBoxControl, options)
	assert(parent ~= nil and comboBoxControl ~= nil, MAJOR .. " - AddCustomScrollableComboBoxDropdownMenu ERROR: Parameters parent and comboBoxControl must be provided!")

	if comboBoxControl.combobox == nil then
		comboBoxControl.combobox = comboBoxControl
	end
	if comboBoxControl.dropdown == nil then
		comboBoxControl.dropdown = ZO_ComboBox_ObjectFromContainer(comboBoxControl)
	end
	--Add a new scrollable menu helper
	return ScrollableDropdownHelper:New(parent, comboBoxControl, options, false)
end

------------------------------------------------------------------------------------------------------------------------
-- XML functions
------------------------------------------------------------------------------------------------------------------------
function LibScrollableMenu_Entry_OnMouseEnter(entry)
    if entry.m_owner and entry.selectible then
--d("LibScrollableMenu_Entry_OnMouseEnter")
		-- For submenus
		local data = ZO_ScrollList_GetData(entry)
		local mySubmenu = GetSubmenuFromControl(entry)
		
		if data.isNew then
			if data.entries == nil or not areAnyEntriesNew(data) then
				data.isNew = false
				-- first send the data to the addon that sent the entry so it can update it's data
				LibScrollableMenu:FireCallbacks('NewStatusUpdated', data, entry)
				
				-- Next refresh visible
				ZO_ScrollList_RefreshVisible(entry.m_owner.m_scroll)
				LibScrollableMenu.submenu.combobox.m_comboBox:ShowDropdownOnMouseUp()
			end
		end
		--Submenu
		if entry.hasSubmenu or data.entries ~= nil then
			entry.hasSubmenu = true
			ClearTimeout()
			
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
			ClearTimeout()
			mySubmenu:ClearChild()
		else
			lib.submenu:Clear()
		end
		
		-- Original
        ZO_ScrollList_MouseEnter(entry.m_owner.m_scroll, entry)
        entry.m_label:SetColor(entry.m_owner.m_highlightColor:UnpackRGBA())
        if entry.m_owner.onMouseEnterCallback then
            entry.m_owner:onMouseEnterCallback(entry)
        end
    end
end
local libMenuEntryOnMouseEnter = LibScrollableMenu_Entry_OnMouseEnter

local function OnMouseExitTimeout()
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
        ZO_ScrollList_MouseExit(entry.m_owner.m_scroll, entry)
        entry.m_label:SetColor(entry.m_owner.m_normalColor:UnpackRGBA())
        if entry.m_owner.onMouseExitCallback then
            entry.m_owner:onMouseExitCallback(entry)
        end
    end
	
	if not lib.GetPersistentMenus() then
		SetTimeout( OnMouseExitTimeout )
	end
end

function LibScrollableMenu_OnSelected(entry)
    if entry.m_owner then
--TODO: For debugging
lib._selectedEntry = entry
--d("LibScrollableMenu_OnSelected")
		local data = ZO_ScrollList_GetData(entry)
		local mySubmenu = GetSubmenuFromControl(entry)
	--	d( data.entries)
		if entry.hasSubmenu or data.entries ~= nil then
			entry.hasSubmenu = true
--d(">menu entry with submenu - hasSubmenu: " ..tostring(entry.hasSubmenu))
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
						data.callback(entry)
						targetSubmenu:Clear()
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
			--Check if the selected entry belongs to a submenu:	if mySubmenu ~= nil
--d(">menu entry - isSubmenuClickedEntry: " ..tostring(mySubmenu ~= nil))
			playSelectedSoundCheck(entry)

			--Pass the entrie's text to the dropdown control's selectedItemText
			entry.m_owner:SetSelected(entry.m_data.m_index)

			lib.submenu.lastClickedEntryWithSubmenu = nil
		end
		
    end
end


------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------
local function OnAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EVENT_MANAGER:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
	lib.submenu = GetScrollableSubmenu(1)
	HookScrollableEntry()
end

EVENT_MANAGER:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
EVENT_MANAGER:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, OnAddonLoaded)


------------------------------------------------------------------------------------------------------------------------
-- Global library reference
------------------------------------------------------------------------------------------------------------------------
LibScrollableMenu = lib