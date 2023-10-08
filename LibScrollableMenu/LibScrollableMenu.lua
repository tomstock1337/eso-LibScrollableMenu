--[[ Just a note. Can be deleted later. 
	I believe that local functions should begin with a lowercase letter. 
		It makes them easier to distinguish from global functions
		This has become inconstant in this lib.

]]

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
local em = EVENT_MANAGER

--Sound settings
local origSoundComboClicked = SOUNDS.COMBO_CLICK
local soundComboClickedSilenced = SOUNDS.NONE

--Submenu settings
local ROOT_PREFIX = MAJOR.."Sub"
local SUBMENU_SHOW_TIMEOUT = 350
local submenuCallLaterHandle
local nextId = 1

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


-- TODO: Decide on what to pass, in LibCustomMenu it always passes ZO_Menu as the 1st parameter
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

local function GetOptionsForEntry(entry)
	local entrysComboBox = GetContainerFromControl(entry)
	
	--[[ IsJustaGhost
		TODO: Would it be better to return {} if nil
		local options = entrysComboBox.options or {}
	]]
		
	return entrysComboBox ~= nil and entrysComboBox.options
end

local function defaultRecursiveCallback()
	return false
end

local function getIsNew(_entry)
	return GetValueOrCallback(_entry.isNew, _entry) or false
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
-- On my screen, at 0.2, this is currently 384
end

-- TODO: Rename
local function getVisible(visibleRows, entryType)
	local highest = 0
	for k, index in ipairs(rowIndex[entryType]) do
		if index < visibleRows then
			highest = highest + 1
		end
	end
	
	return highest
end

local function doMapEntries(entryTable, mapTable)
	for _, entry in pairs(entryTable) do
		if entry.entries then
			doMapEntries(entry.entries, mapTable)
		end
		
		-- TODO: only map entries with callbacks?
		if entry.callback ~= nil then
			table.insert(mapTable, entry)
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
	assert(entryTableType == 'table' and mapTableType == 'table' , string.format('[LibScrollableMenu:MapEntries] tables expected got entryTable = %s, mapTable = %s', tostring(entryTableType), tostring(mapTableType)))
	
	-- Splitting these up so the above is not done each iteration
	doMapEntries(entryTable, mapTable)
end
-- LibScrollableMenu:MapEntries(__table__ entryTable, __table__ mapTable)
-- LibScrollableMenu.MapEntries(__table__ entryTable, __table__ mapTable)

--------------------------------------------------------------------
-- ScrollableDropdownHelper
--------------------------------------------------------------------
local ScrollableDropdownHelper = ZO_InitializingObject:Subclass()
lib.ScrollableDropdownHelper = ScrollableDropdownHelper

-- ScrollableDropdownHelper:New( -- Just a reference for New
-- Available options are:
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

-- Split the data types out
function ScrollableDropdownHelper:Initialize(parent, control, options, isSubMenuScrollHelper)
	isSubMenuScrollHelper = isSubMenuScrollHelper or false

	--Read the passed in options table
	local visibleRows, visibleRowsSubmenu, sortsItems
	if options ~= nil then
		if type(options) == "table" then
			visibleRows = 			GetValueOrCallback(options.visibleRowsDropdown, options)
			visibleRowsSubmenu = 	GetValueOrCallback(options.visibleRowsSubmenu, options)
			sortsItems = 			GetValueOrCallback(options.sortEntries, options)

			control.options = options
			self.options = options
		else
			--Backwards compatibility with AddOns using older library version ScrollableDropdownHelper:Initialize where options was the visibleRows directly
			visibleRows = options
		end
	end
	
	visibleRows = visibleRows or DEFAULT_VISIBLE_ROWS
	visibleRowsSubmenu = visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS
	if sortsItems == nil then sortsItems = DEFAULT_SORTS_ENTRIES end

	local combobox = control.combobox
	local dropdown = control.dropdown
	
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

	combobox.m_comboBox:SetSortsItems(sortsItems)

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
	local function SetSpacing(dropdownCtrl, spacing)
		local newHeight = DIVIDER_ENTRY_HEIGHT + spacing
		ZO_ScrollList_UpdateDataTypeHeight(mScroll, DIVIDER_ENTRY_ID, newHeight)
	end
	ZO_PreHook(dropdown, "SetSpacing", SetSpacing)

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
		
		lib:FireCallbacks('CheckboxUpdated', checked, data, checkbox)
	end

	local function addCheckbox(control, data, list)
		control.m_checkbox = control:GetNamedChild("Checkbox")
		local checkbox = control.m_checkbox
		ZO_CheckButton_SetToggleFunction(checkbox, setChecked)
		ZO_CheckButton_SetCheckState(checkbox, GetValueOrCallback(data.checked, data))
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
	local optionTemplates = options and GetValueOrCallback(options.XMLRowTemplates, options)
	local XMLrowTemplatesToUse = ZO_ShallowTableCopy(defaultXMLTemplates)

	--Check if all XML row templates are passed in, and update missing ones with default values
	if optionTemplates ~= nil then
		for entryType, _ in pairs(defaultXMLTemplates) do
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
	--Get currently shown divider and header idices of the menu entries
	local function getVisibleHeadersAndDivider(visibleItems)
		return getVisible(visibleItems, HEADER_ENTRY_ID), getVisible(visibleItems, DIVIDER_ENTRY_ID)
	end
	
	-- NOTE: the whole reason we need to override it completely, to add our divider and header data entry
	--> item should be the data table of the sortedItems -> means each entry in table which got added with comboBox:AddItems(table)
	local function CreateEntry(self, item, index, isLast)
		item.m_index = index
		item.m_owner = self

		local isHeader = GetValueOrCallback(item.isHeader, item)
		local isCheckbox = GetValueOrCallback(item.isCheckbox, item)
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
			table.insert(rowIndex[entryType], index)
		end
		
		return ZO_ScrollList_CreateDataEntry(entryType, item)
	end

	ZO_ScrollList_Clear(dropdown.m_scroll)

	local dataList = ZO_ScrollList_GetDataList(dropdown.m_scroll)

	--Got passed in via comboBox:AddItems(table)
	local visibleItems = #dropdown.m_sortedItems
	for i = 1, visibleItems do
		local item = dropdown.m_sortedItems[i]
		local entry = CreateEntry(dropdown, item, i, i == visibleItems)
		table.insert(dataList, entry)

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
	else -- account for divider height difference when we shrink the height
		dividerOffset = dividers * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - DIVIDER_ENTRY_HEIGHT)
		headerOffset = headers * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - HEADER_ENTRY_HEIGHT)
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
	if visibleItems > visibleRows then visibleItems = visibleRows end
	if visibleItems > MAX_MENU_ROWS then
		visibleItems = MAX_MENU_ROWS
	end
	--Get the only curently visible headers and dividers, within the visible number of rows
	local visibleHeaders, visibleDividers = getVisibleHeadersAndDivider(visibleItems)
	dividerOffset = visibleDividers * (DIVIDER_ENTRY_HEIGHT)
	headerOffset = visibleHeaders * (SCROLLABLE_ENTRY_TEMPLATE_HEIGHT - HEADER_ENTRY_HEIGHT)

	local firstRowPadding = (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2) + 8
	local desiredHeight = dropdown:GetEntryTemplateHeightWithSpacing() * (visibleItems - 1) + SCROLLABLE_ENTRY_TEMPLATE_HEIGHT + firstRowPadding + dividerOffset - headerOffset


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
		labelStr = GetValueOrCallback(item.label, item)
	end
	
	local submenuEntryPadding = item.hasSubmenu and SCROLLABLE_ENTRY_TEMPLATE_HEIGHT or 0
	local iconPadding = (item.icon ~= nil or item.isNew == true) and ICON_PADDING or 0 -- NO_ICON_PADDING
	local width = GetStringWidthScaled(fontObject, labelStr, 1, SPACE_INTERFACE) + iconPadding + submenuEntryPadding
	
	-- MAX_MENU_WIDTH is to set a cap on how wide text can make a menu. Don't want a menu being 2934 pixels wide.
	width = zo_min(MAX_MENU_WIDTH, width)
	if (width > maxWidth) then
		maxWidth = width
	--	d( string.format('maxWidth = %s', width))
	end
	
	return maxWidth, dividers, headers
end

function ScrollableDropdownHelper:DoHide()
	local dropdown = self.dropdown
	if dropdown:IsDropdownVisible() then
		dropdown:HideDropdown()
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

function ScrollableDropdownHelper:OnShow()
	local dropdown = self.dropdown
	-- This is the culprit in the parent dropdown being stuck on the first opened
	if dropdown.m_lastParent ~= ZO_Menus then
		dropdown.m_lastParent = dropdown.m_dropdown:GetParent()
		dropdown.m_dropdown:SetParent(ZO_Menus)
		ZO_Menus:BringWindowToTop()
	end
end

function ScrollableDropdownHelper:OnMouseEnter(control)
	-- show tooltip
	local data = ZO_ScrollList_GetData(control)
	if data == nil then return end
	local tooltipData = data.tooltip
	if tooltipData ~= nil then
		if type(tooltipData) == "function" then
			local SHOW = true
			tooltipData(data, control, SHOW)
		else
			InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, BOTTOMRIGHT)
			SetTooltipText(InformationTooltip, GetValueOrCallback(tooltipData, data))
			InformationTooltipTopLevel:BringWindowToTop()
		end
	end
	
	if data.disabled then
		return true
	end
end

function ScrollableDropdownHelper:OnMouseExit(control)
	-- hide tooltip
	local data = ZO_ScrollList_GetData(control)
	if data == nil then return end
	local tooltipData = data.tooltip
	if tooltipData ~= nil then
		if type(tooltipData) == "function" then
			local HIDE = false
			tooltipData(control, data, HIDE)
		else
			ClearTooltip(InformationTooltip)
		end
	end
	if data.disabled then
		return true
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

function ScrollableDropdownHelper:UpdateIcons(data)
	local isNewValue = GetValueOrCallback(data.isNew, data)
	local iconValue = GetValueOrCallback(data.icon, data)
	local visible = isNewValue == true or iconValue ~= nil
	local iconHeight = self.m_icon:GetParent():GetHeight()
	-- This leaves a padding to keep the label from being too close to the edge
	local iconWidth = visible and iconHeight or 4
	
	self.m_icon:ClearIcons()
	if visible then
		if isNewValue == true then
			self.m_icon:AddIcon(ZO_KEYBOARD_NEW_ICON)
		end
		if iconValue ~= nil then
			self.m_icon:AddIcon(iconValue)
		end
		self.m_icon:Show()
	end
	
	-- Using the control also as a padding. if no icon then shrink it
	-- This also allows for keeping the icon in size with the row height.
	self.m_icon:SetDimensions(iconWidth, iconHeight)
	self.m_icon:SetHidden(not visible)
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

-- ScrollableSubmenu:New

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
	local anchorOffsetY = -7 --Move the submenu a bi up so it's 1st row is even with the main menu's row having/showing this submenu

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

function ScrollableSubmenu:ClearItems()
	self.dropdown:ClearItems()
end

function ScrollableSubmenu:GetChild(canCreate)
	if not self.childMenu and canCreate then
		self.childMenu = GetScrollableSubmenu(self.depth + 1)
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

	-- This gives us a parent submenu to all entries
	-- entry.m_owner.m_submenu.m_parent
	self.m_parent = parentControl
	return true
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

lib.MapEntries = mapEntries
--[[
	--Currently disabled as not used/non tested - 2023.10.05

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

	Function to create a new entry for a combobox, for LibScrollableMenu
function lib.CreateEntry(name, icon, tooltip, entries, callback)
	local newEntry = {
		name = name, 				--string or function returning a string
		icon = icon, 				-- string iconPath or function returning a string iconPath, or nil
		callback = callback, 		-- function, or nil
		tooltip = tooltip, 			-- string or function returning a string, or nil
		entries = entries, 			-- nil or table of submenu entries
		hasSubmenu = (entries ~= nil),
	}
	
	-- Optional params added to returned newEntry:
	-- newEntry.label string or function returning a string
 	-- newEntry.isHeader boolean or function returning a boolean
 	-- newEntry.isCheckbox boolean or function returning a boolean
	-- newEntry.checked boolean or function returning a boolean (in combination with isCheckbox)
 	-- newEntry.isNew boolean or function returning a boolean
	return newEntry
end
]]

--	/script LibScrollableMenuSub1DropdownDropdown:SetWidth(LibScrollableMenuSub1DropdownDropdown:GetWidth() - 10)
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
	for _, subentry in pairs(submenu) do
		--[[
		if subentry.entries == nil then
		end
		]]
		if getIsNew(subentry) then
			result = true
		end
	end
	
	--d( 'updateSubmenuNewStatus ' .. tostring(result))
	
	data.isNew = result
	if not result then
--		d( '> m_parent.m_owner ' .. tostring(m_parent.m_owner ~= nil))
		if m_parent.m_owner then
--	d( 'm_parent.m_owner.m_scroll ' .. tostring(m_parent.m_owner.m_scroll:GetName()))
			ZO_ScrollList_RefreshVisible(m_parent.m_owner.m_scroll)
			
			if m_parent.m_owner.m_submenu then
				local m_submenu = m_parent.m_owner.m_submenu
--		d( '> m_submenu.m_parent ' .. tostring(m_submenu.m_parent ~= nil))
				
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
			
--		d( '> m_submenu.m_parent ' .. tostring(m_submenu.m_parent ~= nil))
			if m_submenu.m_parent ~= nil then
				updateSubmenuNewStatus(m_submenu.m_parent)
			end
		end
	end
end

function LibScrollableMenu_Entry_OnMouseEnter(entry)
    if entry.m_owner and entry.selectible then
		-- For submenus
		local data = ZO_ScrollList_GetData(entry)
		local mySubmenu = GetSubmenuFromControl(entry)

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
		
		-- I moved this to the bottom to see if any of the Clear*s had any effect on submenu data.
	--	d( 'LibScrollableMenu_Entry_OnMouseEnter ' .. tostring(data.name))
		clearNewStatus(entry, data)
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
		testTLC:SetDimensions(1, 1)
		testTLC:SetAnchor(CENTER, GuiRoot, CENTER)
		testTLC:SetMovable(true)
		testTLC:SetMouseEnabled(false)

		local dropdown = WINDOW_MANAGER:CreateControlFromVirtual(MAJOR .. "TestDropdown", testTLC, "ZO_ComboBox")
		dropdown:SetAnchor(LEFT, testTLC, LEFT, 10, 0)
		dropdown:SetHeight(24)
		dropdown:SetWidth(250)
		dropdown:SetMovable(true)

		local options = { visibleRowsDropdown = 5, visibleRowsSubmenu = 5, sortEntries=function() return false end, }
		local scrollHelper = AddCustomScrollableComboBoxDropdownMenu(testTLC, dropdown, options)

-- did not work		scrollHelper.OnShow = function() end --don't change parenting
	
		lib.testDropdown = dropdown

		--Prepare and add the text entries in the dropdown's comboBox
		local comboBox = dropdown.m_comboBox

		--LibScrollableMenu - LSM entry - Submenu normal
		local submenuEntries = {
			{
				isHeader        = false,
				name            = "Submenu Entry Test 1",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 1")
				end,
				--tooltip         = "Submenu Entry Test 1",
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 2",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 2")
				end,
				tooltip         = "Submenu Entry Test 2",
				isNew			= true,
				--icons 			= nil,
			},
			--LibScrollableMenu - LSM entry - Submenu divider
			{
				name            = "-",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					--Headers do not use any callback
				end,
				tooltip         = "Submenu Divider Test 1",
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 3",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 3")
				end,
				isNew			= true,
				--tooltip         = "Submenu Entry Test 3",
				--icons 			= nil,
			},
			{
				isHeader        = true, --Enables the header at LSM
				name            = "Header Test 1",
				icon			= "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_Staff_Frost_Up.dds",
				tooltip         = "Header test 1",
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 4",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 4")
				end,
				tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 5",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 5")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				name            = "Submenu entry 6",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry 6")
				end,
				entries         = {
					{
						isHeader        = false,
						name            = "Normal entry 6 1:1",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:1")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icons 			= nil,
					},
					{
						isHeader        = false,
						name            = "Submenu entry 6 1:2",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:2")
						end,
						tooltip         = "Submenu entry 6 1:2",
						entries         = {
							{
								isHeader        = false,
								name            = "Submenu entry 6 2:1",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:1")
								end,
								--tooltip         = "Submenu Entry Test 1",
								--icons 			= nil,
							},
							{
								isHeader        = false,
								name            = "Submenu entry 6 2:2",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:2")
								end,
								tooltip         = "Submenu entry 6 2:2",
								entries         = {
									{
										isHeader        = false,
										name            = "Normal entry 6 2:1",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:1")
										end,
										--tooltip         = "Submenu Entry Test 1",
										--icons 			= nil,
									},
									{
										isHeader        = false,
										name            = "Normal entry 6 2:2",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:2")
										end,
										tooltip         = "Normal entry 6 2:2",
										isNew			= true,
										--icons 			= nil,
									},
								},
							},
						},
					},
					{
						isHeader        = false,
						name            = "Normal entry 6 1:2",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Normal entry 6 1:2")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icons 			= nil,
					},
				},
			--	tooltip         = function() return "Submenu entry 6"  end
				tooltip         = "Submenu entry 6"
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 7",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 7")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 8",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 8")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 9",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 9")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			},
			{
				isHeader        = false,
				name            = "Submenu Entry Test 10",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry test 10")
				end,
				--tooltip         = function() return "Submenu Entry Test 4"  end
				--icons 			= nil,
			}
		}

		--Normal entries
		local comboBoxMenuEntries = {
			{
				name            = "Normal entry 1",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 1")
				end,
				icon			= "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_Staff_Frost_Up.dds",
				isNew			= true,
				--entries         = submenuEntries,
				--tooltip         =
			},
			{
				name            = "-", --Divider
			},
			{
				name            = "Entry having submenu 1",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Entry having submenu 1")
				end,
				entries         = submenuEntries,
				--tooltip         =
			},
			{
				name            = "Normal entry 2",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 2")
				end,
				isNew			= true,
				--entries         = submenuEntries,
				--tooltip         =
			},
			{
				isHeader		= function() return true  end,
				name            = "Header entry 1",
				icon 			= "/esoui/art/inventory/inventory_trait_ornate_icon.dds",
				--icons 	     = nil,
			},
			{
				isCheckbox		= function() return true  end,
				name            = "Checkbox entry 1",
				icon 			= "/esoui/art/inventory/inventory_trait_ornate_icon.dds",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Checkbox entry 1")
				end,
			--	tooltip         = function() return "Checkbox entry 1"  end
				tooltip         = "Checkbox entry 1"
			},
			{
				isCheckbox		= true,
				name            = "Checkbox entry 2",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Checkbox entry 2")
				end,
				checked			= true, -- Confirmed does start checked.
				--tooltip         = function() return "Checkbox entry 2" end
				tooltip         = "Checkbox entry 2"
			},
			{
				name            = "Normal entry 4",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 4")
				end,
				--entries         = submenuEntries,
			--	tooltip         = function() return "Normal entry 4"  end
				tooltip         = "Normal entry 4"
			},
			{
				name            = "Normal entry 5",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 5")
				end,
				--entries         = submenuEntries,
			--	tooltip         = function() return "Normal entry 5"  end
				tooltip         = "Normal entry 5"
			},
			{
				name            = "Submenu entry 6",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Submenu entry 6")
				end,
				entries         = {
					{
						isHeader        = false,
						name            = "Normal entry 6 1:1",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:1")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icons 			= nil,
					},
					{
						isHeader        = false,
						name            = "Submenu entry 6 1:1",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Submenu entry 6 1:2")
						end,
						tooltip         = "Submenu entry 6 1:2",
						entries         = {
							{
								isHeader        = false,
								name            = "Submenu entry 6 2:1",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:1")
								end,
								--tooltip         = "Submenu Entry Test 1",
								--icons 			= nil,
							},
							{
								isHeader        = false,
								name            = "Submenu entry 6 2:2",
								callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
									d("Submenu entry 6 2:2")
								end,
								tooltip         = "Submenu entry 6 2:2",
								entries         = {
									{
										isHeader        = false,
										name            = "Normal entry 6 2:1",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:1")
										end,
										--tooltip         = "Submenu Entry Test 1",
										--icons 			= nil,
									},
									{
										isHeader        = false,
										name            = "Normal entry 6 2:2",
										callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
											d("Normal entry 6 2:2")
										end,
										tooltip         = "Normal entry 6 2:2",
										isNew			= true,
										--icons 			= nil,
									},
								},
							},
						},
					},
					{
						isHeader        = false,
						name            = "Normal entry 6 1:2",
						callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
							d("Normal entry 6 1:2")
						end,
						--tooltip         = "Submenu Entry Test 1",
						--icons 			= nil,
					},
				},
			--	tooltip         = function() return "Submenu entry 6"  end
				tooltip         = "Submenu entry 6"
			},
			{
				name            = "Normal entry 7",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 7")
				end,
				--entries         = submenuEntries,
			--	tooltip         = function() return "Normal entry 7"  end
				tooltip         = "Normal entry 7"
			},
			{
				name            = "Normal entry 8",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 8")
				end,
				--entries         = submenuEntries,
			--	tooltip         = function() return "Normal entry 8"  end
				tooltip         = "Normal entry 8"
			},
			{
				name            = "Normal entry 9",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 9")
				end,
				--entries         = submenuEntries,
			--	tooltip         = function() return "Normal entry 9"  end
				tooltip         = "Normal entry 9"
			},
			{
				name            = "Normal entry 10 - Very long text here at this entry!",
				callback        =   function(comboBox, itemName, item, selectionChanged, oldItem)
					d("Normal entry 10")
				end,
				--entries         = submenuEntries,
			--	tooltip         = function() return "Normal entry 10"  end
				tooltip         = "Normal entry 10"
			}
		}

		--Add the items
		comboBox:AddItems(comboBoxMenuEntries)
		
		local entryMap = {}
		-- entries are mapped by 
		-- entryMap[#entryMap + 1]
		-- entryMap[data] 
		lib:MapEntries(comboBoxMenuEntries, entryMap)
	--	lib.MapEntries(comboBoxMenuEntries, entryMap)
	--	mapEntries(comboBoxMenuEntries, entryMap)
	
		lib.testDropdown.entryMap = entryMap
		
		lib:RegisterCallback('NewStatusUpdated', function(data, entry)
			if entryMap[data] ~= nil then
				d( '>>> INTERNAL <<< NewStatusUpdated ' .. data.name)
			else
				d( '>>> EXTERNAL <<< NewStatusUpdated ' .. data.name)
			end
		end)
		
		lib:RegisterCallback('CheckboxUpdated', function(checked, data, checkbox)
			local internal = false
			for k, v in pairs(entryMap) do
				if v == data then
					internal = true
					break
				end
			end
			
			if internal then
				d( '>>> INTERNAL <<< CheckboxUpdated ' .. data.name)
			else
				d( '>>> EXTERNAL <<< CheckboxUpdated ' .. data.name)
			end
		end)
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
--	/script LibScrollableMenu.Test()
SLASH_COMMANDS["/lsmtest"] = function() lib.Test() end


------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------
local function OnAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	em:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
	setMaxMenuWidthAndRows()

	lib.submenu = GetScrollableSubmenu(1)
	HookScrollableEntry()

	--Other events
	em:RegisterForEvent(lib.name, EVENT_SCREEN_RESIZED, setMaxMenuWidthAndRows)
end

em:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
em:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, OnAddonLoaded)


------------------------------------------------------------------------------------------------------------------------
-- Global library reference
------------------------------------------------------------------------------------------------------------------------
LibScrollableMenu = lib
