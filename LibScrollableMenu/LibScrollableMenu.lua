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

local MAX_MENU_ROWS = 25
local MAX_MENU_WIDTH
--local MAX_MENU_HEIGHT
local DIVIDER_ENTRY_HEIGHT = 7
local HEADER_ENTRY_HEIGHT = 30

local DEFAULT_VISIBLE_ROWS = 10
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT -- same as in zo_combobox.lua
local TEXT_PADDING = 4
local CONTENT_PADDING = 18 -- decreased from 24
local SCROLLBAR_PADDING = 16

local ICON_PADDING = 0

local NO_ICON_PADDING = -5
local ICON_PADDING = 20

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

-- Recursively check for new entries.
local function areAnyEntriesNew(entry)
	local submenu = entry.entries or {}
	local new = false
	
	if #submenu > 0 then
		for k, subentry in pairs(submenu) do
			if areAnyEntriesNew(subentry) then
				new = true
                break
			end
		end
	elseif entry.isNew then
		new = true
	end
	
	return new
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

-- TODO: Is this even needed?
local function setMaxMenuWidthAndRows()
	-- MAX_MENU_WIDTH is to set a cap on how wide text can make a menu. Don't want a menu being 2934 pixels wide.
    local uiWidth, uiHeight = GuiRoot:GetDimensions()
	MAX_MENU_WIDTH = uiWidth * 0.3
	MAX_MENU_ROWS = zo_floor((uiHeight * 0.5) / SCROLLABLE_ENTRY_TEMPLATE_HEIGHT)
--	/script d(GuiRoot:GetDimensions() * 0.2)
-- On mu screen this is currently 384
end
setMaxMenuWidthAndRows()
EVENT_MANAGER:RegisterForEvent(lib.name, EVENT_SCREEN_RESIZED, setMaxMenuWidthAndRows)

--------------------------------------------------------------------
-- ScrollableDropdownHelper
--------------------------------------------------------------------
local ScrollableDropdownHelper = ZO_InitializingObject:Subclass()
lib.ScrollableDropdownHelper = ScrollableDropdownHelper

-- ScrollableDropdownHelper:New( -- Just a reference for New
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

	--dropdown:SetSpacing(8)

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
--	self:SetSpacing(4) -- TODO: remove it not used
 
 
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
end

--------------------------------------------------------------------
-- List data type templates
--------------------------------------------------------------------

-- With multi icon
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
		if data.callback then
			data.callback(checked, data)
		end
	end

	local function addCheckbox(control, data, list)
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
	end
	
	local function addIcon(control, data, list)
		control.m_icon = control:GetNamedChild("Icon")
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
		control.m_label = control:GetNamedChild("Label")

		local oName = data.name
		local name = GetValueOrCallback(data.name, data)
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
			data.labelStr  = GetValueOrCallback(data.label, data)
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

	local function hooHandlers(control, data, list)
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
				addCheckbox(control, data, list)
				hooHandlers(control, data, list)
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
				addCheckbox(control, data, list)
				hooHandlers(control, data, list)
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
		--	rowHeight = HEADER_ENTRY_HEIGHT,
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				control.isHeader = true
				
				addDivider(control, data, list)
				addIcon(control, data, list)
				addLabel(control, data, list)
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
	local optionTemplates = options and GetValueOrCallback(options.XMLRowTemplates, options)
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
	ZO_ScrollList_SetTypeSelectable(mScroll, DIVIDER_ENTRY_ID, false)
	ZO_ScrollList_SetTypeSelectable(mScroll, HEADER_ENTRY_ID, false)
--	ZO_ScrollList_SetTypeCategoryHeader(mScroll, HEADER_ENTRY_ID, true)

	SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = XMLrowTemplatesToUse[ENTRY_ID].rowHeight
	ICON_PADDING = SCROLLABLE_ENTRY_TEMPLATE_HEIGHT
end

function ScrollableDropdownHelper:UpdateIcons(data)
	local visible = data.isNew or data.icon ~= nil
--	local iconSize = visible and ICON_PADDING or 4
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
	largestEntryWidth = largestEntryWidth + 5
	
	if(visibleItems > visibleRows - 1) then
		largestEntryWidth = largestEntryWidth + ZO_SCROLL_BAR_WIDTH
		anchorOffset = -ZO_SCROLL_BAR_WIDTH
		visibleItems = visibleRows
	else -- account for divider height difference when we shrink the height
		dividerOffset = dividers * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - DIVIDER_ENTRY_HEIGHT)
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
	-- the last entry uses a separate entry template that does not include the spacing in its height
	if visibleItems > MAX_MENU_ROWS then
		visibleItems = MAX_MENU_ROWS
		visibleItems = 3
	end
	
	-- firstRowPadding is to compensate for the additional padding required by the container, 5 above and 5 below entries.
	-- Why is this modification needed? ZO_ComboBox does not add the + 10.
	local firstRowPadding = (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2) + 10
    local desiredHeight = dropdown:GetEntryTemplateHeightWithSpacing() * (visibleItems - 1) + SCROLLABLE_ENTRY_TEMPLATE_HEIGHT + firstRowPadding - dividerOffset

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
	local fontObject = _G[item.m_owner.m_font]
	
	if item.name == lib.DIVIDER then
		dividers = dividers + 1
	elseif item.isHeader then
		headers = headers + 1
	end
	
	local labelStr = item.name
	if item.label ~= nil then
		labelStr = GetValueOrCallback(item.label, item)
	end
	
	local submenuEntryPadding = item.hasSubmenu and SCROLLABLE_ENTRY_TEMPLATE_HEIGHT or 0
	local iconPadding = (item.icon ~= nil or item.isNew) and ICON_PADDING or NO_ICON_PADDING
	local width = GetStringWidthScaled(fontObject, labelStr, 1, SPACE_INTERFACE) + iconPadding + submenuEntryPadding
	
	-- MAX_MENU_WIDTH is to set a cap on how wide text can make a menu. Don't want a menu being 2934 pixels wide.
	width = zo_min(MAX_MENU_WIDTH, width)
	if (width > maxWidth) then
		maxWidth = width
	--	d( string.format('maxWidth = %s', width))
	end
	
	return maxWidth, dividers, headers
end

function ScrollableDropdownHelper:OnMouseEnter(control)
	-- show tooltip
	local data = ZO_ScrollList_GetData(control)
	if data == nil then return end
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
	if data == nil then return end
	if data.tooltip then
		ClearTooltip(InformationTooltip)
	end
	if data.disabled then
		return true
	end
end

function ScrollableDropdownHelper:SetSpacing(spacing) -- TODO: remove it not used
	local dropdown = self.dropdown
    ZO_ComboBox.SetSpacing(dropdown, spacing)

    local newHeight = dropdown:GetEntryTemplateHeightWithSpacing()
    ZO_ScrollList_UpdateDataTypeHeight(dropdown.m_scroll, ENTRY_ID, newHeight)
    ZO_ScrollList_UpdateDataTypeHeight(dropdown.m_scroll, DIVIDER_ENTRY_ID, 2)
    ZO_ScrollList_UpdateDataTypeHeight(dropdown.m_scroll, HEADER_ENTRY_ID, HEADER_ENTRY_HEIGHT)
end

--------------------------------------------------------------------
-- ScrollableSubmenu
--------------------------------------------------------------------
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
	local anchorOffsetY = -7

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

--[[
	local newEntry = LibScrollableMenu.CreateEntry(
		name, 
		icon, 
		tooltip, 
		entries, 
		callback
	)
	-- Add additional variables
	newEntry.isHeader = header
	table.insert(dropdownEntries, newEntry)

local createEntry = LibScrollableMenu.CreateEntry

	local newEntry = createEntry(
		name, 
		icon, 
		tooltip, 
		entries, 
		callback
	)
	-- Add additional variables
	newEntry.label = label
	table.insert(dropdownEntries, newEntry)
]]
function lib.CreateEntry(name, icon, tooltip, entries, callback)
	local newEntry = {
		name = name,
		icon = icon, -- icon file or nil
		callback = callback, -- function or nil
		tooltip = tooltip,
		entries = entries, -- nil or table of submenu entries
		hasSubmenu = (entries ~= nil),
	}
	
	-- Optional params added to returned newEntry
	-- newEntry.label string or function returning a string
	-- newEntry.isHeader bool
	-- newEntry.checked bool
	-- newEntry.isNew bool
	return newEntry
end

--	/script LibScrollableMenuSub1DropdownDropdown:SetWidth(LibScrollableMenuSub1DropdownDropdown:GetWidth() - 10)
--Adds a scroll helper to the comboBoxControl dropdown entries, and enables submenus (scollable too) at the entries.
--	control parent 							Must be the parent control of the comboBox
--	control comboBoxControl 				Must be any ZO_ComboBox control (e.g. created from virtual template ZO_ComboBox)

 --  table options:optional = {
 --  table options:optional = {
 --		number visibleRowsDropdown:optional		Number of shown entries at 1 page of the scrollable comboBox's opened dropdown
 --		number visibleRowsDropdown:optional		Number of shown entries at 1 page of the scrollable comboBox's opened dropdown
 --		number visibleRowsSubmenu:optional		Number of shown entries at 1 page of the scrollable comboBox's opened submenus
 --		number visibleRowsSubmenu:optional		Number of shown entries at 1 page of the scrollable comboBox's opened submenus
--		userdata dropdown:optional				Either this exists as comboBoxControl.dropdown already, or you can pass in the
--		table	XMLRowTemplates:optional		Table with key = row type of lib.scrollListRowTypes and the value = subtable having "template" String = XMLVirtualTemplateName
--												dropdown object (containing the m_comboBox etc.) here to add it to the comboBoxControl
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

--------------------------------------------------------------------
-- XML functions
--------------------------------------------------------------------
local function refeshNewStatus(entry, data)
	local data = data or ZO_ScrollList_GetData(entry)
	if data.isNew then
		-- Check if not a submenu or, check if any subentries(recursively) are new.
		if data.entries == nil or not areAnyEntriesNew(data) then
			data.isNew = false
			-- Refresh mouse-over entry
			ZO_ScrollList_RefreshVisible(entry.m_owner.m_scroll)
			
			if entry.m_owner.m_submenu then
			--	LibScrollableMenu_Entry_OnMouseEnter(entry.m_owner.m_submenu.m_owner)
				refeshNewStatus(entry.m_owner.m_submenu.m_owner)
			end
			
			lib:FireCallbacks('NewStatusUpdated', data, entry)
		end
	end
end

function LibScrollableMenu_Entry_OnMouseEnter(entry)
    if entry.m_owner and entry.selectible then
		-- For submenus
		local data = ZO_ScrollList_GetData(entry)
		local mySubmenu = GetSubmenuFromControl(entry)

		refeshNewStatus(entry, data)

		if entry.hasSubmenu or data.entries ~= nil then
			lib.submenu.m_owner = lib.submenu.m_owner or entry
--For debugging
lib._lastMouseOverSubmenuEntry = entry
			
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
						--entry.m_owner:Hide()
						local comboBox = GetContainerFromControl(entry)
						if comboBox and comboBox.scrollHelper then
							comboBox.scrollHelper:DoHide()
						end
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
-- For testing - Combobox with all kind of entry types (test offsets, etc.)
------------------------------------------------------------------------------------------------------------------------
local function test()
	if lib.testDropdown == nil then
		local testTLC = CreateTopLevelWindow(MAJOR .. "TestTLC")
		testTLC:SetHidden(true)
		testTLC:SetDimensions(800, 600)
		testTLC:SetMovable(true)
		testTLC:SetMouseEnabled(false)

		local dropdown = WINDOW_MANAGER:CreateControlFromVirtual(MAJOR .. "TestDropdown", testTLC, "ZO_ComboBox")
		dropdown:SetAnchor(LEFT, testTLC, LEFT, 10, 0)
		dropdown:SetHeight(24)
		dropdown:SetWidth(250)
		dropdown:SetMovable(true)
		dropdown:SetMouseEnabled(true)

		local options = nil -- { visibleRowsDropdown = 10, visibleRowsSubmenu = 15 }
		AddCustomScrollableComboBoxDropdownMenu(testTLC, dropdown, options)

		lib.testDropdown = dropdown

		--Prepare and add the text entries in the dropdown's comboBox
		local comboBoxMenuEntries = {}
		local submenuEntries = {}

		--LibScrollableMenu - LSM entry - Submenu normal
		submenuEntries[#submenuEntries+1] = {
			isHeader        = false,
			name            = "Submenu Entry Test 1",
			callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				d("Submenu entry test 1")
			end,
			--tooltip         = "Submenu Entry Test 1",
			--icons 			= nil,
		}
		submenuEntries[#submenuEntries+1] = {
			isHeader        = false,
			name            = "Submenu Entry Test 2",
			callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				d("Submenu entry test 2")
			end,
			tooltip         = "Submenu Entry Test 2",
			--icons 			= nil,
		}
		--LibScrollableMenu - LSM entry - Submenu divider
		submenuEntries[#submenuEntries+1] = {
			name            = "-",
			callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				--Headers do not use any callback
			end,
			tooltip         = "Submenu Divider Test 1",
			--icons 			= nil,
		}
		submenuEntries[#submenuEntries+1] = {
			isHeader        = false,
			name            = "Submenu Entry Test 3",
			callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				d("Submenu entry test 3")
			end,
			--tooltip         = "Submenu Entry Test 3",
			--icons 			= nil,
		}
		submenuEntries[#submenuEntries+1] = {
			isHeader        = true, --Enables the header at LSM
			name            = "Header Test 1",
			tooltip         = "Header test 1",
			--icons 			= nil,
		}
		submenuEntries[#submenuEntries+1] = {
			isHeader        = false,
			name            = "Submenu Entry Test 4",
			callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				d("Submenu entry test 4")
			end,
			tooltip         = function() return "Submenu Entry Test 4"  end
			--icons 			= nil,
		}

		--Normal entries
		comboBoxMenuEntries[#comboBoxMenuEntries+1] = {
			name            = "Normal entry 1",
			callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				d("Normal entry 1")
			end,
			--entries         = submenuEntries,
			--tooltip         =
		}
		comboBoxMenuEntries[#comboBoxMenuEntries+1] = {
			name            = "-", --Divider
		}
		comboBoxMenuEntries[#comboBoxMenuEntries+1] = {
			name            = "Entry having submenu 1",
			callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				d("Entry having submenu 1")
			end,
			entries         = submenuEntries,
			--tooltip         =
		}
		comboBoxMenuEntries[#comboBoxMenuEntries+1] = {
			name            = "Normal entry 2",
			callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				d("Normal entry 2")
			end,
			--entries         = submenuEntries,
			--tooltip         =
		}
		comboBoxMenuEntries[#comboBoxMenuEntries+1] = {
			isHeader		= true,
			name            = "Header entry 1",
			--icons 	     = nil,
		}
		comboBoxMenuEntries[#comboBoxMenuEntries+1] = {
			name            = "Normal entry 3",
			callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
				d("Normal entry 3")
			end,
			--entries         = submenuEntries,
			tooltip         = function() return "Normal entry 3"  end
		}

		--Add the items
		local comboBox = dropdown.m_comboBox
		comboBox:AddItems(comboBoxMenuEntries)
	end
	local dropdown = lib.testDropdown
	local testTLC = dropdown:GetParent()
	if testTLC:IsHidden() then
		testTLC:SetHidden(false)
		testTLC:SetMouseEnabled(true)
	else
		testTLC:SetHidden(true)
		testTLC:SetMouseEnabled(false)
	end

end
lib.Test = test

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



