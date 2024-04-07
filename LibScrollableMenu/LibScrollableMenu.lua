if LibScrollableMenu ~= nil then return end -- the same or newer version of this lib is already loaded into memory

local lib = ZO_CallbackObject:New()
lib.name = "LibScrollableMenu"
local MAJOR = lib.name
lib.version = "2.1"

lib.data = {}

if not lib then return end

--Constant for the divider entryType
lib.DIVIDER = "-"
local libDivider = lib.DIVIDER


--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--ZOs local speed-up/reference variables
local EM = EVENT_MANAGER
local SNM = SCREEN_NARRATION_MANAGER
local tos = tostring
local sfor = string.format
local tins = table.insert

------------------------------------------------------------------------------------------------------------------------
--ZO_ComboBox function references
local zo_comboBox_base_addItem = ZO_ComboBox_Base.AddItem
local zo_comboBox_base_hideDropdown = ZO_ComboBox_Base.HideDropdown

--local zo_comboBox_selectItem = ZO_ComboBox.SelectItem
local zo_comboBox_onGlobalMouseUp = ZO_ComboBox.OnGlobalMouseUp
local zo_comboBox_hideDropdownInternal = ZO_ComboBox.HideDropdownInternal
local zo_comboBox_setItemEntryCustomTemplate = ZO_ComboBox.SetItemEntryCustomTemplate

local zo_comboBoxDropdown_onEntrySelected = ZO_ComboBoxDropdown_Keyboard.OnEntrySelected
local zo_comboBoxDropdown_onMouseExitEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseExitEntry
local zo_comboBoxDropdown_onMouseEnterEntry = ZO_ComboBoxDropdown_Keyboard.OnMouseEnterEntry


------------------------------------------------------------------------------------------------------------------------
--Library internal global locals
local g_contextMenu -- The contextMenu (like ZO_Menu): Will be created at onAddonLoaded


------------------------------------------------------------------------------------------------------------------------
--Menu settings (main and submenu)
local DEFAULT_VISIBLE_ROWS = 10
local DEFAULT_SORTS_ENTRIES = true --sort the entries in main- and submenu lists

--Entry type settings
local DIVIDER_ENTRY_HEIGHT = 7
local HEADER_ENTRY_HEIGHT = 30
local SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT -- same as in zo_comboBox.lua: 25
local DEFAULT_SPACING = 0
local WITHOUT_ICON_LABEL_DEFAULT_OFFSETX = 4

--Fonts
local DEFAULT_FONT = "ZoFontGame"
local HEADER_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED))
local DEFAULT_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
local DEFAULT_TEXT_HIGHLIGHT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))

--Height and width
local DEFAULT_HEIGHT = 250

--dropdown settings
local SUBMENU_SHOW_TIMEOUT = 500 --350 ms before
local dropdownCallLaterHandle = MAJOR .. "_Timeout"

--Sound settings
local origSoundComboClicked = SOUNDS.COMBO_CLICK
local soundComboClickedSilenced = SOUNDS.NONE

--Textures
local iconNewIcon = ZO_KEYBOARD_NEW_ICON

--MultiIcon
local iconNarrationNewValue = GetString(SI_SCREEN_NARRATION_NEW_ICON_NARRATION)

--Narration
local UINarrationName = MAJOR .. "_UINarration_"
local UINarrationUpdaterName = MAJOR .. "_UINarrationUpdater_"


local getValueOrCallback

------------------------------------------------------------------------------------------------------------------------
--Menu types for the different scrollable menus
LSM_MENUTYPE_MAINMENU = 1
LSM_MENUTYPE_SUBMENU = 2
LSM_MENUTYPE_CONTEXTMENU = 100
LSM_MENUTYPE_CONTEXTMENU_SUBMENU = 101
local LSM_MENUTYPE_MAINMENU = LSM_MENUTYPE_MAINMENU
local LSM_MENUTYPE_SUBMENU = LSM_MENUTYPE_SUBMENU
local LSM_MENUTYPE_CONTEXTMENU = LSM_MENUTYPE_CONTEXTMENU
local LSM_MENUTYPE_CONTEXTMENU_SUBMENU = LSM_MENUTYPE_CONTEXTMENU_SUBMENU

--Entry types - For the scroll list's dataType of te menus
local ENTRY_ID = 1
local DIVIDER_ENTRY_ID = 2
local HEADER_ENTRY_ID = 3
local SUBMENU_ENTRY_ID = 4
local CHECKBOX_ENTRY_ID = 5

--The custom scrollable context menu entry types
lib.LSM_ENTRY_TYPE_NORMAL = 	ENTRY_ID
lib.LSM_ENTRY_TYPE_DIVIDER = 	DIVIDER_ENTRY_ID
lib.LSM_ENTRY_TYPE_HEADER = 	HEADER_ENTRY_ID
lib.LSM_ENTRY_TYPE_CHECKBOX = 	CHECKBOX_ENTRY_ID
--Add global variables
LSM_ENTRY_TYPE_NORMAL = 		lib.LSM_ENTRY_TYPE_NORMAL
LSM_ENTRY_TYPE_DIVIDER = 		lib.LSM_ENTRY_TYPE_DIVIDER
LSM_ENTRY_TYPE_HEADER = 		lib.LSM_ENTRY_TYPE_HEADER
LSM_ENTRY_TYPE_CHECKBOX = 		lib.LSM_ENTRY_TYPE_CHECKBOX

local allowedEntryTypesForContextMenu = {
	[lib.LSM_ENTRY_TYPE_NORMAL] = true,
	[lib.LSM_ENTRY_TYPE_DIVIDER] = true,
	[lib.LSM_ENTRY_TYPE_HEADER] = true,
	[lib.LSM_ENTRY_TYPE_CHECKBOX] = true,
}

local entryTypesForContextMenuWithoutMandatoryCallback = {
	[lib.LSM_ENTRY_TYPE_DIVIDER] = true,
	[lib.LSM_ENTRY_TYPE_HEADER] = true,
}


--Make them accessible for the DropdownObject:New options table -> options.XMLRowTemplates
lib.scrollListRowTypes = {
	ENTRY_ID = ENTRY_ID,
	DIVIDER_ENTRY_ID = DIVIDER_ENTRY_ID,
	HEADER_ENTRY_ID = HEADER_ENTRY_ID,
	SUBMENU_ENTRY_ID = SUBMENU_ENTRY_ID,
	CHECKBOX_ENTRY_ID = CHECKBOX_ENTRY_ID,
}
------------------------------------------------------------------------------------------------------------------------


--ZO_ComboBox default settings: Will be copied over as default attributes to comboBoxClass and inherited scrollable
--dropdown helper classes
local comboBoxDefaults = {
	--From ZO_ComboBox
	m_selectedItemData = nil,
	m_selectedColor = { GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_SELECTED) },
	m_disabledColor = ZO_ERROR_COLOR,
	m_sortOrder = ZO_SORT_ORDER_UP,
	m_sortType = ZO_SORT_BY_NAME,
	m_sortsItems = true,
	m_isDropdownVisible = false,
	m_preshowDropdownFn = nil,
	m_spacing = DEFAULT_SPACING,
	m_font = DEFAULT_FONT,
	m_normalColor = DEFAULT_TEXT_COLOR,
	m_highlightColor = DEFAULT_TEXT_HIGHLIGHT,
	m_customEntryTemplateInfos = nil,
	m_enableMultiSelect = false,
	m_maxNumSelections = nil,
	m_height = DEFAULT_HEIGHT,
	horizontalAlignment = TEXT_ALIGN_LEFT,

	--LibScrollableMenu internal (e.g. .options)
	filterString = '',
	disableFadeGradient = false,
	m_headerFontColor = HEADER_TEXT_COLOR,
	visibleRows = DEFAULT_VISIBLE_ROWS,
	visibleRowsSubmenu = DEFAULT_VISIBLE_ROWS,
	baseEntryHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
}

--The default values for dropdownHelper options used for non-passed in LSM API functions
local defaultComboBoxOptions  = {
	["visibleRowsDropdown"] = DEFAULT_VISIBLE_ROWS,
	["visibleRowsSubmenu"] = DEFAULT_VISIBLE_ROWS,
	["sortEntries"] = DEFAULT_SORTS_ENTRIES,
	["font"] = DEFAULT_FONT,
	["spacing"] = DEFAULT_SPACING,
	["disableFadeGradient"] = false,
	["headerColor"] = nil,
	["preshowDropdownFn"] = nil,
	--["XMLRowTemplates"] = table, --Will be set at comboBoxClass:UpdateOptions(options) from options
}
lib.defaultComboBoxOptions  = defaultComboBoxOptions

--Possible options that can be passed in to the options table at the scrollable dropdownObject API functions.
--If any option name passed in does not match the table entries below, it will be silently ignored.
local possibleLibraryOptions = {
	--LSM only
	["visibleRowsDropdown"] = true,
	["visibleRowsSubmenu"] = true,
	["narrate"] = true,
	["XMLRowTemplates"] = true,

	--LSM and ZO_ComboBox
	["sortEntries"] = true,
	["font"] = true,
	["spacing"] = true,
	["disableFadeGradient"] = true,
	["preshowDropdownFn"] = true,
}
lib.possibleLibraryOptions = possibleLibraryOptions

--The mapping between LibScrollableMenu options key and ZO_ComboBox options key. Used in comboBoxClass:UpdateOptions()
local LSMOptionsToZO_ComboBoxOptions = {
	--These callback functions will apply the options directly
	['sortType'] = function(comboBoxObject, sortType)
		local options = comboBoxObject.options
		if comboBoxObject.orderSet then comboBoxObject.orderSet = false return end
		local sortOrder = getValueOrCallback(options.sortOrder, options)
		if sortOrder == nil then sortOrder = comboBoxObject.m_sortOrder end
		comboBoxObject:SetSortOrder(sortType , sortOrder )
		comboBoxObject.orderSet = true
	end,
	['sortOrder'] = function(comboBoxObject, sortOrder)
		local options = self.options
		if comboBoxObject.orderSet then comboBoxObject.orderSet = false return end
		local sortType = getValueOrCallback(options.sortType, options) or comboBoxObject.m_sortType
		comboBoxObject:SetSortOrder(sortType , sortOrder )
		comboBoxObject.orderSet = true
	end,
	["sortEntries"] = function(comboBoxObject, sortEntries)
		comboBoxObject:SetSortsItems(sortEntries) --sets comboBoxObject.m_sortsItems
	end,
	['spacing'] = function(comboBoxObject, spacing)
		comboBoxObject:SetSpacing(spacing) --sets comboBoxObject.m_spacing
	end,
	['font'] = function(comboBoxObject, font)
		comboBoxObject:SetFont(font) --sets comboBoxObject.m_font
	end,
	["preshowDropdownFn"] = function(comboBoxObject, preshowDropdownCallbackFunc)
		comboBoxObject:SetPreshowDropdownCallback(preshowDropdownCallbackFunc) --sets m_preshowDropdownFn
	end,

	--These mapping keys just tell via the key where the comboBox object should be updated
	["disableFadeGradient"] =	"disableFadeGradient",
	["headerColor"] =			"m_headerFontColor",
	["visibleRowsDropdown"] =	"visibleRows",
	["visibleRowsSubmenu"]=		"visibleRowsSubmenu",
	["narrate"] = 				"narrateData",
}
lib.LSMOptionsToZO_ComboBoxOptions = LSMOptionsToZO_ComboBoxOptions

--------------------------------------------------------------------
-- XML template functions
--------------------------------------------------------------------

local function getDropdownTemplate(enabled, baseTemplate, alternate, default)
	baseTemplate = MAJOR .. baseTemplate
	return sfor('%s%s', baseTemplate, (enabled and alternate or default))
end

local function getScrollContentsTemplate(barHidden)
	return getDropdownTemplate(barHidden, '_ScrollContents', '_BarHidden', '_BarShown')
end


--------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------

--Run function arg to get the return value (passing in ... as optional params to that function),
--or directly use non-function return value arg
function getValueOrCallback(arg, ...)
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end
lib.GetValueOrCallback = getValueOrCallback

local function clearTimeout()
	EM:UnregisterForUpdate(dropdownCallLaterHandle)
end

local function setTimeout(callback)
	clearTimeout()
	--Delay the dropdown close callback so we can move the mouse above a new dropdown control and keep that opened e.g.
	EM:RegisterForUpdate(dropdownCallLaterHandle, SUBMENU_SHOW_TIMEOUT, function()
		clearTimeout()
		if callback then callback() end
	end)
end

local function updateIsContextMenuAndIsSubmenu(selfVar)
	selfVar.isContextMenu = g_contextMenu and g_contextMenu.m_container == selfVar.m_container
	selfVar.isSubmenu = selfVar.m_parentMenu ~= nil
end

--Mix in table entries in other table and skip existing entries
local function mixinTableAndSkipExisting(object, ...)
	for i = 1, select("#", ...) do
		local source = select(i, ...)
		for k,v in pairs(source) do
			--Skip existing entries in
			if object[k] == nil then
				object[k] = v
			end
		end
	end
end

--The default callback for the recursiveOverEntries function
local function defaultRecursiveCallback(_entry)
	return false
end

-- Recursively loop over drdopdown entries, and submenu dropdown entries of that parent dropdown, and check if e.g. isNew needs to be updated
local function recursiveOverEntries(entry, callback)
	callback = callback or defaultRecursiveCallback
	
	local result = callback(entry)
	local submenu = entry.entries or {}

	--local submenuType = type(submenu)
	--assert(submenuType == 'table', sfor('['..MAJOR..':recursiveOverEntries] table expected, got %q = %s', "submenu", tos(submenuType)))

	if  type(submenu) == "table" and #submenu > 0 then
		for k, subEntry in pairs(submenu) do
			local subEntryResult = recursiveOverEntries(subEntry, callback)
			if subEntryResult then
				result = subEntryResult
			end
		end
	end
	return result
end

--(Un)Silence the OnClicked sound of a selected dropdown
local function silenceComboBoxClickedSound(doSilence)
	doSilence = doSilence or false
	if doSilence == true then
		--Silence the "selected comboBox sound"
		SOUNDS.COMBO_CLICK = soundComboClickedSilenced
	else
		--Unsilence the "selected comboBox sound" again
		SOUNDS.COMBO_CLICK = origSoundComboClicked
	end
end

--Get the options of the scrollable dropdownObject
local function getOptionsForDropdown(dropdown)
	return dropdown.owner.options or {}
end

--Check if a sound should be played if a dropdown entry was selected
local function playSelectedSoundCheck(dropdown)
	silenceComboBoxClickedSound(false)

	local soundToPlay = origSoundComboClicked
	local options = getOptionsForDropdown(dropdown)
	
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

--Recursivley map the entries of a submenu and add them to the mapTable
--used for the callback "NewStatusUpdated" to provide the mapTable with the entries
local function doMapEntries(entryTable, mapTable)
	for k, entry in pairs(entryTable) do
		if entry.entries then
			doMapEntries(entry.entries, mapTable)
		end
		
		-- TODO: only map entries with callbacks?
		if entry.callback then
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
	assert(entryTableType == 'table' and mapTableType == 'table' , sfor('['..MAJOR..':MapEntries] tables expected, got %q = %s, %q = %s', "entryTable", tos(entryTableType), "mapTable", tos(mapTableType)))
	
	-- Splitting these up so the above is not done each iteration
	doMapEntries(entryTable, mapTable)
end
lib.MapEntries = mapEntries

--Update the icons of a dropdown entry's MultiIcon control
local function updateIcons(control, data)
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

	local multiIconContainerCtrl = control.m_iconContainer
	local multiIconCtrl = control.m_icon

	local parentHeight = multiIconCtrl:GetParent():GetHeight()
	local iconHeight = parentHeight
	-- This leaves a padding to keep the label from being too close to the edge
	local iconWidth = visible and iconHeight or WITHOUT_ICON_LABEL_DEFAULT_OFFSETX

	multiIconCtrl:ClearIcons()
	if visible == true then
		control.m_icon.data = control.m_icon.data or {}

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
--TODO: see how this effects it 
--	multiIconCtrl:SetDimensions(iconWidth, iconHeight)
	multiIconCtrl:SetHidden(not visible)
end

--------------------------------------------------------------------
-- Local entryData functions
--------------------------------------------------------------------

-- >> data, dataEntry
local function getControlData(control)
	local data = control.m_sortedItems or control.m_data
	
	if data.dataSource then
		data = data:GetDataSource()
	end
	
	return data
end

--Check if an entry got the isNew set
local function getIsNew(_entry)
	return getValueOrCallback(_entry.isNew, _entry) or false
end

-- Recursively check for new entries.
local function areAnyEntriesNew(entry)
	return recursiveOverEntries(entry, getIsNew)
end

-- Add/Remove the new status of a dropdown entry.
-- This works up from the mouse-over entry's submenu up to the dropdown,
-- as long as it does not run into a submenu still having a new entry.
local function updateSubmenuNewStatus(control)
--	d( '[LSM]updateSubmenuNewStatus')
	-- reverse parse
	local isNew = false
	
	local data = getControlData(control)
	local submenuEntries = data.entries or {}
	
	-- We are only going to check the current submenu's entries, not recursively
	-- down from here since we are working our way up until we find a new entry.
	for k, subentry in ipairs(submenuEntries) do
		if getIsNew(subentry) then
			isNew = true
		end
	end
	-- Set flag on submenu
	data.isNew = isNew
	if not isNew then
		ZO_ScrollList_RefreshVisible(control.m_dropdownObject.scrollControl)
			
		local parent = data.m_parentControl
		if parent then
			updateSubmenuNewStatus(parent)
		end
	end
end

--Remove the new status of a dropdown entry
local function clearNewStatus(control, data)
--d( '[LSM]clearNewStatus')
--d( 'data.isNew ' .. tostring(data.isNew))
	if data.isNew then
		-- Only directly change status on non-submenu entries. The are effected by child entries
		if data.entries == nil then
			data.isNew = false
			
			lib:FireCallbacks('NewStatusUpdated', data, control)
			
			control.m_dropdownObject:Refresh(data)
			
			local parent = data.m_parentControl
			if parent then
				updateSubmenuNewStatus(parent)
			end
		end
	end
end

--Set the custom XML virtual template for a dropdown entry
local function setItemEntryCustomTemplate(item, customEntryTemplates)
	local isHeader = getValueOrCallback(item.isHeader, item)
	--We are not going to use processNameString(item) function here to update item.name and item.label here already because at dropdown:Show it's called to react on
	--actual values -> if item.name or item.label is a function checking values!
	-- processNameString create the functions
	-- updateLabelsStrings updates the strings based on the functions.
	local isDivider = item.label == libDivider or item.name == libDivider
	local isCheckbox = getValueOrCallback(item.isCheckbox, item)

	local hasSubmenu = item.entries ~= nil

	local entryType = (isDivider and DIVIDER_ENTRY_ID) or (isCheckbox and CHECKBOX_ENTRY_ID) or (isHeader and HEADER_ENTRY_ID) or
			(hasSubmenu and SUBMENU_ENTRY_ID) or ENTRY_ID

	item.isHeader = isHeader
	item.isDivider = isDivider
	item.hasSubmenu = hasSubmenu
	item.isCheckbox = isCheckbox
	
	if entryType then
		local customEntryTemplate = customEntryTemplates[entryType].template
		zo_comboBox_setItemEntryCustomTemplate(item, customEntryTemplate)
	end
	--[[ NOTICE: A note on LAST_ENTRY_ID and, why it was removed from here, >= 1.9.
		Last entry is no longer specifically used by ZO_ComboBox.
		As such, I removed all references to LAST ENTRY from the lib
		Each type is given a "Last entry" on creation as...
				ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId, entryTemplate, entryHeightWithSpacing, setupFunction)
				ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId + 1, entryTemplate, entryHeight, setupFunction)
		In most cases, typeId + 1 is never used, well, noticed, since the default padding is 0. Making it the same as root entry,
		Now, Last Entry == entryType + 1
	]]
end

local function updateLabelsStrings(data)
	if data.labelFunction then
		data.label = data.labelFunction(data)
	end

	if data.nameFunction then
		data.name = data.nameFunction(data)
	end
end

local function processNameString(data)
	--Passed in an alternative text/function returning a text to show at the label control of the menu entry?
	if type(data.label) == 'function' then
		--Keep the original label function at the data, data.label will be used as a string directly updated by data.labelFunction(data).
		data.labelFunction = data.label
	end
	
	--Name: Mandatory! Used interally of ZO_ComboBox and dropdownObject to SetSelectedItemText and run callback on clicked entry with (self, item.name, data, selectionChanged, oldItem)
	if type(data.name) == 'function' then
		--Keep the original name function at the data, as we need a "String only" text as data.name for ZO_ComboBox internal functions!
		data.nameFunction = data.name
	end
	
	updateLabelsStrings(data)
	
	if type(data.name) ~= 'string' then
		--TODO: implement logging
	end
end

-- Prevents errors on the off chance a non-string makes it through into ZO_ComboBox
local function verifyLabelString(data)
	updateLabelsStrings(data)
	
	return type(data.name) == 'string'
end

-- We can add any row-type post checks and update dateEntry with static values.
local function addItem_Base(self, itemEntry)
	processNameString(itemEntry)
	
	if not itemEntry.customEntryTemplate then
		setItemEntryCustomTemplate(itemEntry, self.XMLrowTemplates)
		
		if itemEntry.hasSubmenu then
			itemEntry.isNew = areAnyEntriesNew(itemEntry)
		elseif itemEntry.isHeader then
			itemEntry.font = self.m_headerFont
			itemEntry.color = self.m_headerFontColor
		elseif itemEntry.isDivider then
			-- Placeholder
		elseif itemEntry.isCheckbox then
			-- Placeholder
		elseif itemEntry.isNew then
			-- Placeholder
		end
	end
	
end

--------------------------------------------------------------------
-- Local tooltip functions
--------------------------------------------------------------------

--Hide the tooltip of a dropdown entry
local function hideTooltip()
	if lib.lastCustomTooltipFunction then
		lib.lastCustomTooltipFunction()
	else
		ClearTooltip(InformationTooltip)
	end
end

--Show the tooltip of a dropdown entry. First check for any custom tooltip function that handles the control show/hide
--and if none is provided use default InformationTooltip
--> For a custom tooltip example see line below:
--[[
--Custom tooltip function example
Function to show or hide a custom tooltip control. Pass that in to the data table of any entry, via data.customTooltip!

Your function needs to create and show/hide that control, and populate the text etc to the control too!
Parameters:
-data The table with the current data of the rowControl
-rowControl The userdata of the control the tooltip should show about
-point, offsetX, offsetY, relativePoint: Suggested anchoring points

myAddon.customTooltipFunc(table data, userdata rowControl, Int point, Int offsetX, Int offsetY, Int relativePoint)
e.g. data = { name="Test 1", label="Test", customTooltip=function(data, rowControl, point, offsetX, offsetY, relativePoint) ... end, ... }

customTooltipFunc = function(data, rowControl, point, offsetX, offsetY, relativePoint)
	if data == nil then
		self.myTooltipControl:SetHidden(true)
	else
		self.myTooltipControl:ClearAnchors()
		self.myTooltipControl:SetAnchor(point, rowControl, relativePoint, offsetX, offsetY)
		self.myTooltipControl:SetText(data.tooltip)
		self.myTooltipControl:SetHidden(false)
	end
end
]]
local function showTooltip(control, data, hasSubmenu)
	local tooltipData = getValueOrCallback(data.tooltip, data)
	local tooltipText = getValueOrCallback(tooltipData, data)
	
	--To prevent empty tooltips from opening.
	if tooltipText == nil then return end
	
	local point, offsetX, offsetY, relativePoint = BOTTOMLEFT, 0, 0, TOPRIGHT
	
	local parentControl = control
	if control.m_dropdownObject then
		-- Lets get the dropdown control if called from another type of dropdown.
		parentControl = control.m_dropdownObject.control
	end
		
	local anchorPoint = select(2,parentControl:GetAnchor())
	local right = anchorPoint ~= 3
	if not right then
		local width, height = GuiRoot:GetDimensions()
		local fontObject = _G[DEFAULT_FONT]
		local nameWidth = GetStringWidthScaled(fontObject, tooltipText, 1, SPACE_INTERFACE)
		
		if control:GetRight() + nameWidth > width then
			right = true
		end
	end

	if right then
		if hasSubmenu then
			point, relativePoint = BOTTOMRIGHT, TOPRIGHT
		else
			point, relativePoint = RIGHT, LEFT
		end
	else
		if hasSubmenu then
			point, relativePoint = BOTTOMLEFT, TOPLEFT
		else
			point, relativePoint = LEFT, RIGHT
		end
	end
	
	lib.lastCustomTooltipFunction = nil
	
	local customTooltipFunc = data.customTooltip
	if type(customTooltipFunc) == "function" then
		lib.lastCustomTooltipFunction = customTooltipFunc(data, control, point, offsetX, offsetY, relativePoint)
	else
		InitializeTooltip(InformationTooltip, control, point, offsetX, offsetY, relativePoint)
		SetTooltipText(InformationTooltip, tooltipText)
		InformationTooltipTopLevel:BringWindowToTop()
	end
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
--d( "["..MAJOR.."]AddNewChatNarrationText-stopCurrent: " ..tostring(stopCurrent) ..", text: " ..tostring(newText))
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
	local updaterName = UINarrationUpdaterName ..tos(uniqueId)
--d( "[LSM]onUpdateDoNarrate-updaterName: " ..tos(updaterName))
	EM:UnregisterForUpdate(updaterName)
	if isAccessibilityUIReaderEnabled() == false or callbackFunc == nil then return end
	delay = delay or 1000
	EM:RegisterForUpdate(updaterName, delay, function()
		if isAccessibilityUIReaderEnabled() == false then EM:UnregisterForUpdate(updaterName) return end
--d( ">>>calling func delayed now!")
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
	["OnComboBoxMouseEnter"] = 	onMouseEnterOrExitNarrate,
	["OnComboBoxMouseExit"] =	onMouseEnterOrExitNarrate,
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
-- Dropdown entry/row handlers
--------------------------------------------------------------------

local function onMouseEnter(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	
	dropdown:Narrate("OnEntryMouseEnter", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseEnter', data, control)
	
	return dropdown
end

local function onMouseExit(control, data, hasSubmenu)
	local dropdown = control.m_dropdownObject
	
	dropdown:Narrate("OnEntryMouseExit", control, data, hasSubmenu)
	lib:FireCallbacks('EntryOnMouseExit', data, control)
	
	return dropdown
end

local function onMouseUp(control, data, hasSubmenu, button, upInside)
	local dropdown = control.m_dropdownObject

	if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
		dropdown:Narrate("OnEntrySelected", control, data, hasSubmenu)
		lib:FireCallbacks('EntryOnSelected', data, control)
	end

	return dropdown
end

local has_submenu = true
local no_submenu = false

local handlerFunctions  = {
	['onMouseEnter'] = {
		[ENTRY_ID] = function(control, data, ...)
			local dropdown = onMouseEnter(control, data, no_submenu)
			clearNewStatus(control, data)
			return false
		end,
		[HEADER_ENTRY_ID] = function(control, data, ...)
			-- Return true to skip the default handler.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, data, ...)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, data, ...)
			--d( 'onMouseEnter [SUBMENU_ENTRY_ID]')
			-- Must clear now. Otherwise, moving onto a submenu will close it from exiting previous row.
			local dropdown = onMouseEnter(control, data, has_submenu)
			clearTimeout()
			dropdown:ShowSubmenu(control)
			return false
		end,
		[CHECKBOX_ENTRY_ID] = function(control, data, ...)
			local dropdown = onMouseEnter(control, data, no_submenu)
			return false
		end,
	},
	['onMouseExit'] = {
		[ENTRY_ID] = function(control, data)
			local dropdown = onMouseExit(control, data, no_submenu)
			return false
		end,
		[HEADER_ENTRY_ID] = function(control, data)
			-- Return true to skip the default handler.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, data)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, data)
			local dropdown = onMouseExit(control, data, has_submenu)
			--TODO: This is onMouseExit, MouseIsOver(control) should not apply.
			if not (MouseIsOver(control) or dropdown:IsEnteringSubmenu()) then
				dropdown:OnMouseExitTimeout(control)
			end
			return false
		end,
		[CHECKBOX_ENTRY_ID] = function(control, data)
			local dropdown = onMouseExit(control, data, no_submenu)
			return false
		end,
	},
	['onMouseUp'] = {
		[ENTRY_ID] = function(control, data, button, upInside)
			--onMouseUp [ENTRY_ID]')
			local dropdown = onMouseUp(control, data, no_submenu, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					dropdown:SelectItemByIndex(control.m_data.m_index)
				end
			end
			return true
		end,
		[HEADER_ENTRY_ID] = function(control, data, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[DIVIDER_ENTRY_ID] = function(control, data, button, upInside)
			-- Return true to skip the default handler.
			return true
		end,
		[SUBMENU_ENTRY_ID] = function(control, data, button, upInside)
			local dropdown = onMouseUp(control, data, has_submenu, button, upInside)
			
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					if data.callback then
						dropdown:SelectItemByIndex(control.m_data.m_index)
					end
				end
			else
				--TODO: Do we want to close dropdowns on mouse up not upInside?
			end
			return true
		end,
		[CHECKBOX_ENTRY_ID] = function(control, data, button, upInside)
			--d( 'onMouseUp [CHECKBOX_ENTRY_ID]')
			local dropdown = control.m_dropdownObject
			if upInside then
				if button == MOUSE_BUTTON_INDEX_LEFT then
					-- left click on row toggles the checkbox.
					playSelectedSoundCheck(dropdown)
					ZO_CheckButton_OnClicked(control.m_checkbox)
					data.checked = ZO_CheckButton_IsChecked(control.m_checkbox)
				end
			end
			return true
		end,
	},
}

local function runHandler(handlerTable, control, ...)
	local handler = handlerTable[control.typeId]
	if handler then
		return handler(control, ...)
	end

	return false
end

--------------------------------------------------------------------
-- dropdownClass
--------------------------------------------------------------------

local dropdownClass = ZO_ComboBoxDropdown_Keyboard:Subclass()

-- dropdownClass:New(To simplify locating the beginning of the class
function dropdownClass:Initialize(parent, comboBoxContainer, depth)
	local dropdownControl = CreateControlFromVirtual(comboBoxContainer:GetName(), GuiRoot, "LibScrollableMenu_Keyboard_Template", depth)
	ZO_ComboBoxDropdown_Keyboard.Initialize(self, dropdownControl)
	dropdownControl.object = self
	self.m_comboBox = comboBoxContainer.m_comboBox
	self.m_container = comboBoxContainer
	self.owner = parent

	self:SetHidden(true)

	self.m_parentMenu = parent.m_parentMenu
	self.m_sortedItems = {}

	local scrollCtrl = self.scrollControl
	if scrollCtrl then
		scrollCtrl.scrollbar.owner = 	scrollCtrl
		scrollCtrl.upButton.owner = 	scrollCtrl
		scrollCtrl.downButton.owner = 	scrollCtrl
	else
--d("[LSM]dropdownClass:Initialize -  self.scrollControl is nil")
	end
end

function dropdownClass:AddItems(items)
	error('[LSM] scrollHelper:AddItems is obsolete. You must use m_comboBox:AddItems')
end

function dropdownClass:AddItem(item)
	error('[LSM] scrollHelper:AddItems is obsolete. You must use m_comboBox:AddItem')
end

--Narration
function dropdownClass:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	self.owner:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
end

function dropdownClass:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
	if not self.customEntryTemplateInfos then
		self.customEntryTemplateInfos = {}
	end

	if self.customEntryTemplateInfos[entryTemplate] ~= nil then
		-- we have already added this template
		return
	end

	local customEntryInfo =
	{
		typeId = self.nextScrollTypeId,
		entryHeight = entryHeight,
		widthPadding = widthPadding,
	}

	self.customEntryTemplateInfos[entryTemplate] = customEntryInfo

	local entryHeightWithSpacing = entryHeight + self.spacing
	ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId, entryTemplate, entryHeightWithSpacing, setupFunction)
	ZO_ScrollList_AddDataType(self.scrollControl, self.nextScrollTypeId + 1, entryTemplate, entryHeight, setupFunction)

	self.nextScrollTypeId = self.nextScrollTypeId + 2
end

function dropdownClass:AnchorToControl(parentControl)
	local width, height = GuiRoot:GetDimensions()
	local right = true
	local offsetX = -4
	local point, relativePoint = TOPLEFT, TOPRIGHT
	
	if self.m_parentMenu.m_dropdownObject and self.m_parentMenu.m_dropdownObject.anchorRight ~= nil then
		right = self.m_parentMenu.m_dropdownObject.anchorRight
	end
	
	if not right or parentControl:GetRight() + self.control:GetWidth() > width then
		right = false
		offsetX = 4
		point, relativePoint = TOPRIGHT, TOPLEFT
	end
	
	local relativeTo = parentControl.m_dropdownObject.scrollControl
	-- Get offsetY in relation to parentControl's top in the scroll container
    local offsetY = select(6, parentControl:GetAnchor(0))

	self.control:ClearAnchors()
	self.control:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
	
	self.anchorRight = right

	--Check for context menu and submenu, and do narration
	updateIsContextMenuAndIsSubmenu(self)
	if not self.isContextMenu and self.isSubmenu == true then
		local anchorPoint = (right == true and TOPRIGHT) or TOPLEFT
		self:Narrate("OnSubMenuShow", parentControl, nil, nil, anchorPoint)
		lib:FireCallbacks('OnSubMenuShow', parentControl, anchorPoint)
	end
end

function dropdownClass:AnchorToComboBox(conboBox)
	local parentControl = conboBox:GetContainer()
	self.control:ClearAnchors()
	self.control:SetAnchor(TOPLEFT, parentControl, BOTTOMLEFT)
end

function dropdownClass:AnchorToMouse()
	local menuToAnchor = self.control
	
	local x, y = GetUIMousePosition()
	local width, height = GuiRoot:GetDimensions()

	menuToAnchor:ClearAnchors()
	
	local right = true
	if x + menuToAnchor:GetWidth() > width then
		right = false
	end
	local bottom = true
	if y + menuToAnchor:GetHeight() > height then
		bottom = false
	end

	if right then
		x = x + 10
		if bottom then
			menuToAnchor:SetAnchor(TOPLEFT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMLEFT, nil, TOPLEFT, x, y)
		end
	else
		x = x - 10
		if bottom then
			menuToAnchor:SetAnchor(TOPRIGHT, nil, TOPLEFT, x, y)
		else
			menuToAnchor:SetAnchor(BOTTOMRIGHT, nil, TOPLEFT, x, y)
		end
	end
end

function dropdownClass:GetScrollbar()
--d("[LSM]dropdownClass:GetScrollbar")
	local scrollCtrl = self.scrollControl
	local scrollBar = scrollCtrl ~= nil and scrollCtrl.scrollbar
	if scrollBar then ---and scrollCtrl.useScrollbar == true then (does not work for menus where there is no scrollabr active, but used in general!)
--d(">scrollBar found!")
		return scrollBar
	end
	return
end

function dropdownClass:GetSubmenu()
	if self.owner then
		self.m_submenu = self.owner.m_submenu
	end

	return self.m_submenu
end

function dropdownClass:IsDropdownVisible()
	-- inherited ZO_ComboBoxDropdown_Keyboard:IsHidden
	return not self:IsHidden()
end

function dropdownClass:IsEnteringSubmenu()
	local submenu = self:GetSubmenu()
	if submenu then
		if submenu:IsDropdownVisible() and submenu:IsMouseOverControl() then
			return true
		end
	end
	return false
end

function dropdownClass:IsItemSelected(item)
	if self.owner and self.owner.IsItemSelected then
		return self.owner:IsItemSelected(item)
	end
	return false
end

function dropdownClass:IsMouseOverOpeningControl()
	return false
end

function dropdownClass:OnMouseEnterEntry(control)
--	d( '[LSM]dropdownClass:OnMouseEnterEntry')
--	self.control:BringWindowToTop()
	
	-- Added here for when mouse is moved from away from dropdowns over a row, it will know to close specific children
	self:OnMouseExitTimeout(control)

	local data = getControlData(control)
	if not runHandler(handlerFunctions['onMouseEnter'], control, data) then
		zo_comboBoxDropdown_onMouseEnterEntry(self, control)
	end
	
	if data.tooltip or data.customTooltip then
		self:ShowTooltip(control, data)
	end
	
	--TODO: Conflicting OnMouseExitTimeout -> 20240310 What in detail is conflicting here, with what?
	if g_contextMenu:IsDropdownVisible() then
--d(">contex menu: Dropdown visible = yes")
		g_contextMenu.m_dropdownObject:OnMouseExitTimeout(control)
	end
end

function dropdownClass:OnMouseExitEntry(control)
	--d( '[LSM]dropdownClass:OnMouseExitEntry')
--	d( control:GetName())
	
	hideTooltip()
	local data = getControlData(control)
	self:OnMouseExitTimeout(control)
	if not runHandler(handlerFunctions['onMouseExit'], control, data) then
		zo_comboBoxDropdown_onMouseExitEntry(self, control)
	end

	--[[
	if not lib.GetPersistentMenus() then
--		self:OnMouseExitTimeout(control)
	end
	]]
end

function dropdownClass:OnMouseExitTimeout(control)
--	clearTimeout()
	--d( "[LSM]dropdownClass:OnMouseExitTimeout-control: " ..tos(control:GetName()))

	setTimeout(function()
		self.owner:HideOnMouseExit(moc())
	end)
end

function dropdownClass:OnEntrySelected(control, button, upInside)
	--d( '[LSM]dropdownClass:OnEntrySelected IsUpInside ' .. tos(upInside) .. ' Button ' .. tos(button))
	
	local data = getControlData(control)
	if not runHandler(handlerFunctions['onMouseUp'], control, data, button, upInside) then
--d(">not runHandler: onMouseUp -> Calling zo_comboBoxDropdown_onEntrySelected")
		zo_comboBoxDropdown_onEntrySelected(self, control)
	end
	
	if upInside then
		if button == MOUSE_BUTTON_INDEX_RIGHT then
			if data.contextMenuCallback then
				data.contextMenuCallback(control)
			end
		end
	end
end

function dropdownClass:SelectItemByIndex(index, ignoreCallback)
	if self.owner then
		self:HideDropdown()
		playSelectedSoundCheck(self)
		return self.owner:SelectItemByIndex(index, ignoreCallback)
	end
end

local function createScrollableComboBoxEntry(self, item, index, entryType)
	local entryData = ZO_EntryData:New(item)
	entryData.m_index = index
	entryData.m_owner = self.owner
	entryData.m_dropdownObject = self
	entryData:SetupAsScrollListDataEntry(entryType)
	return entryData
end

function dropdownClass:SetupEntryLabel(labelControl, data)
	labelControl:SetText(data.label or data.name) -- Use alternative passed in label string, or the default mandatory name string
	labelControl:SetFont(self.owner:GetDropdownFont())
	local color = self.owner:GetItemNormalColor(data)
	labelControl:SetColor(color:UnpackRGBA())
	labelControl:SetHorizontalAlignment(self.horizontalAlignment)
end

function dropdownClass:Show(comboBox, itemTable, minWidth, maxHeight, spacing)
	--d( sfor('[LSM]dropdownClass:Show - minWidth = %s, maxHeight = %s, spacing = %s', tos(minWidth), tos(maxHeight), tos(spacing)))
	self.owner = comboBox
	
	ZO_ScrollList_Clear(self.scrollControl)

	self:SetSpacing(spacing)

	local numItems = #itemTable
	local dataList = ZO_ScrollList_GetDataList(self.scrollControl)

	local largestEntryWidth = 0
	local allItemsHeight = 0
	for i = 1, numItems do
		local item = itemTable[i]
		if verifyLabelString(item) then
			local isLastEntry = i == numItems
			local entryHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT
			local entryType = ENTRY_ID
			local widthPadding = 0
			if self.customEntryTemplateInfos and item.customEntryTemplate then
				local templateInfo = self.customEntryTemplateInfos[item.customEntryTemplate]
				if templateInfo then
					entryType = templateInfo.typeId
					entryHeight = templateInfo.entryHeight
					 -- for static width padding beyond string length, such as submenu icon
					widthPadding = templateInfo.widthPadding or 0

					-- If the entry has an icon, or isNew, we add the row height to adjust for icon size.
					local iconPadding = (item.isNew or item.icon) and entryHeight or 0
					widthPadding = widthPadding + iconPadding
				end
			end

			if isLastEntry then
				entryType = entryType + 1
			else
				entryHeight = entryHeight + self.spacing
			end

			allItemsHeight = allItemsHeight + entryHeight

			local entry = createScrollableComboBoxEntry(self, item, i, entryType)
			tins(dataList, entry)

			local fontObject = self.owner:GetDropdownFontObject()
			--Check string width of label (alternative text to show at entry) or name (internal value used)
			local nameWidth = GetStringWidthScaled(fontObject, item.label or item.name, 1, SPACE_INTERFACE) + widthPadding
			if nameWidth > largestEntryWidth then
				largestEntryWidth = nameWidth
			end
		end
	end
	
	-- using the exact width of the text can leave us with pixel rounding issues
	-- so just add 5 to make sure we don't truncate at certain screen sizes
	largestEntryWidth = largestEntryWidth + 5

	allItemsHeight = allItemsHeight + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2)

	local desiredHeight = maxHeight
	ApplyTemplateToControl(self.scrollControl.contents, getScrollContentsTemplate(allItemsHeight < desiredHeight))
	if allItemsHeight < desiredHeight then
		desiredHeight = allItemsHeight
	end

	-- Allow the dropdown to automatically widen to fit the widest entry, but
	-- prevent it from getting any skinnier than the container's initial width
	local totalDropDownWidth = largestEntryWidth + ZO_COMBO_BOX_ENTRY_TEMPLATE_LABEL_PADDING * 2 + ZO_SCROLL_BAR_WIDTH
	if totalDropDownWidth > minWidth then
		self.control:SetWidth(totalDropDownWidth)
	else
		self.control:SetWidth(minWidth)
	end
	
	ZO_Scroll_SetUseFadeGradient(self.scrollControl,  not self.owner.disableFadeGradient ) 
	self.control:SetHeight(desiredHeight)
	ZO_ScrollList_SetHeight(self.scrollControl, desiredHeight)

	ZO_ScrollList_Commit(self.scrollControl)
	self:OnShown()
end

function dropdownClass:OnShown()
	self.control:BringWindowToTop()

	--Check for context menu and submenu, and do narration
	updateIsContextMenuAndIsSubmenu(self)
	if not self.isContextMenu and not self.isSubmenu == true then
		self:Narrate("OnMenuShow", self.control)
		lib:FireCallbacks('OnMenuShow', self.control)
	end
end

function dropdownClass:ShowSubmenu(control)
	if self.owner then
		self.owner:ShowSubmenu(control)
	end
end

function dropdownClass:ShowTooltip(control, data)
	if data.hasSubmenu then
		local submenu = self:GetSubmenu()
		zo_callLater(function()
			showTooltip(submenu.m_dropdownObject.control, data, data.hasSubmenu)
		end, 10)
	else
		showTooltip(control, data, data.hasSubmenu)
	end
end

function dropdownClass:HideDropdown()
	if self.owner then
		self.owner:HideDropdown()
	end
end

function dropdownClass:HideSubmenu()
	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		self.m_submenu:HideDropdown()
	end
end


--------------------------------------------------------------------
-- ComboBox classes
--------------------------------------------------------------------

--------------------------------------------------------------------
-- comboBox base
--------------------------------------------------------------------

local comboBox_base = ZO_ComboBox:Subclass()
local submenuClass = comboBox_base:Subclass()

function comboBox_base:Initialize(parent, comboBoxContainer, options, depth)
	self.m_sortedItems = {}
	self.m_unsortedItems = {}
	self.m_container = comboBoxContainer
	local dropdownObject = self:GetDropdownObject(comboBoxContainer, depth)
	self:SetDropdownObject(dropdownObject)

	self:UpdateOptions(options, true)

	local maxHeight = self.baseEntryHeight * self:GetMaxRows()
	self:SetHeight(maxHeight)
end

-- Common functions
-- Adds the customEntryTemplate to all items added
function comboBox_base:AddItem(itemEntry, updateOptions, templates)
	addItem_Base(self, itemEntry)
	zo_comboBox_base_addItem(self, itemEntry, updateOptions)
	tins(self.m_unsortedItems, itemEntry)
end

--[[
function comboBox_base:AddItems(items)
	local group
    for k, item in pairs(items) do
	
		if item.category ~= nil or item.isHeader then
			group = item.category or k
		end
		
		item.group = group
		
        self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    
    self:UpdateItems()
end
]]

-- Adds widthPadding as a valid parameter
function comboBox_base:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
	if not self.m_customEntryTemplateInfos then
		self.m_customEntryTemplateInfos = {}
	end

	local customEntryInfo =
	{
		entryTemplate = entryTemplate,
		entryHeight = entryHeight,
		widthPadding = widthPadding,
		setupFunction = setupFunction,
	}

	self.m_customEntryTemplateInfos[entryTemplate] = customEntryInfo

	self.m_dropdownObject:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
end

-- >> template, height, setupFunction
local function getTemplateData(entryType, template)
	local templateDataForEntryType = template[entryType]
	return templateDataForEntryType.template, templateDataForEntryType.rowHeight, templateDataForEntryType.setupFunc, templateDataForEntryType.widthPadding
end

function comboBox_base:AddCustomEntryTemplates(options)
	local defaultXMLTemplates  = {
		[ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntryLabel(control, data, list)
			end,
		},
		[SUBMENU_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxSubmenuEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthAdjust = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntrySubmenu(control, data, list)
			end,
		},
		[DIVIDER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxDividerEntry',
			rowHeight = DIVIDER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntryDivider(control, data, list)
			end,
		},
		[HEADER_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxHeaderEntry',
			rowHeight = HEADER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupEntryHeader(control, data, list)
			end,
		},
		[CHECKBOX_ENTRY_ID] = {
			template = 'LibScrollableMenu_ComboBoxCheckboxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				self:SetupCheckbox(control, data, list)
			end,
		},
	}
	
	lib.DefaultXMLTemplates = defaultXMLTemplates

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

	self.XMLrowTemplates = XMLrowTemplatesToUse
	-- These register the templates and creates a dataType for each.
	self:AddCustomEntryTemplate(getTemplateData(ENTRY_ID, self.XMLrowTemplates))
	self:AddCustomEntryTemplate(getTemplateData(SUBMENU_ENTRY_ID, self.XMLrowTemplates))
	self:AddCustomEntryTemplate(getTemplateData(DIVIDER_ENTRY_ID, self.XMLrowTemplates))
	self:AddCustomEntryTemplate(getTemplateData(HEADER_ENTRY_ID, self.XMLrowTemplates))
	self:AddCustomEntryTemplate(getTemplateData(CHECKBOX_ENTRY_ID, self.XMLrowTemplates))
	
	-- TODO: we should not rely on these anymore. Instead we should attach them to self if they are still needed
	SCROLLABLE_ENTRY_TEMPLATE_HEIGHT = self.XMLrowTemplates[ENTRY_ID].rowHeight
	DIVIDER_ENTRY_HEIGHT = self.XMLrowTemplates[DIVIDER_ENTRY_ID].rowHeight
	HEADER_ENTRY_HEIGHT = self.XMLrowTemplates[HEADER_ENTRY_ID].rowHeight
	
	-- We will use this, per-comboBox, to set max rows.
	self.baseEntryHeight = self.XMLrowTemplates[ENTRY_ID].rowHeight
end

function comboBox_base:BypassOnGlobalMouseUp(button)
	--d("[LSM]comboBox_base:BypassOnGlobalMouseUp-button: " ..tos(button) .. ", isMouseOverScrollbar: " ..tos(self:IsMouseOverScrollbarControl()))

	if self:IsMouseOverScrollbarControl() then
		--d(">>mouse is above scrollbar")
		return true
	end

	if button == MOUSE_BUTTON_INDEX_LEFT then
		local mocCtrl = moc()
		--d(">moc: " ..tos(mocCtrl ~= nil and mocCtrl:GetName()) .. ", mocTypeId: " ..tos(mocCtrl.typeId))
		if mocCtrl.typeId then
			return mocCtrl.typeId ~= ENTRY_ID
		end
	end
	--Any other right mouse click -> Stay opened!
	return button == MOUSE_BUTTON_INDEX_RIGHT
end

function comboBox_base:GetDropdownControl()
	if self.m_dropdownObject then
		return self.m_dropdownObject.control
	end
end

function comboBox_base:GetDropdownObject(comboBoxContainer, depth)
	self.m_nextFree = depth + 1
	return dropdownClass:New(self, comboBoxContainer, depth)
end

-- Create the m_dropdownObject on initialize.
function comboBox_base:GetOptions()
	return self.options
end

-- Get or create submenu
function comboBox_base:GetSubmenu()
	if not self.m_submenu then
		self.m_submenu = submenuClass:New(self, self.m_container, self.options, self.m_nextFree)
	end
	
	return self.m_submenu
end

-- Changed to hide tooltip and, if available, it's submenu
-- We hide the tooltip here so it is hidden if the dropdown is hidden OnGlobalMouseUp
function comboBox_base:HideDropdown()
--d("comboBoxClass:HideDropdown()")
	-- Recursive through all open submenus and close them starting from last.
--	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
	if self.m_submenu then
		self.m_submenu:HideDropdown()
	end
	zo_comboBox_base_hideDropdown(self)

	--Narrate the OnMenuHide texts
	local function narrateOnMenuHideButOnlyOnceAsHideDropdownIsCalledTwice()
		updateIsContextMenuAndIsSubmenu(self)
		if self.narrateData and self.narrateData["OnMenuHide"] then
	--d(">narrate OnMenuHide-isContextMenu: " ..tos(self.isContextMenu) .. ", isSubmenu: " .. tos(self.isSubmenu))
			if not self.isContextMenu and not self.isSubmenu then
		--		self:Narrate("OnMenuHide", self.m_container)
				lib:FireCallbacks('OnMenuHide', self.m_container)
			end
		end
	end
	onUpdateDoNarrate("OnMenuHide_Start", 25, narrateOnMenuHideButOnlyOnceAsHideDropdownIsCalledTwice)
end

function comboBox_base:IsMouseOverScrollbarControl()
--d("[LSM]comboBox_base:IsMouseOverScrollbarControl")
	local mocCtrl = moc()
	if mocCtrl ~= nil then
		local owner = mocCtrl.owner
		return owner and owner.scrollbar ~= nil
	end
	return false
end

function comboBox_base:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
--	d( 'comboBox_base:Narrate ' .. tos(eventName))
	local narrateData = self.narrateData
--d( "[LSM]Narrate-"..tos(eventName) .. ", narrateData: " ..tos(narrateData))
	if eventName == nil or isAccessibilityUIReaderEnabled() == false or narrateData == nil then return end
	local narrateCallbackFuncForEvent = narrateData[eventName]
	if narrateCallbackFuncForEvent == nil or type(narrateCallbackFuncForEvent) ~= "function" then return end

	local eventCallbackFunctionsSignatures = {
		["OnMenuShow"]			= function() return self, ctrl end,
		["OnMenuHide"]			= function() return self, ctrl end,
		["OnSubMenuShow"]		= function() return self, ctrl, anchorPoint end,
		["OnSubMenuHide"]		= function() return self, ctrl end,
		["OnEntrySelected"]		= function() return self, ctrl, data, hasSubmenu end,
		["OnEntryMouseExit"]	= function() return self, ctrl, data, hasSubmenu end,
		["OnEntryMouseEnter"]	= function() return self, ctrl, data, hasSubmenu end,
		["OnCheckboxUpdated"]	= function() return self, ctrl, data end,
		["OnComboBoxMouseExit"] = function() return self, ctrl end,
		["OnComboBoxMouseEnter"]= function() return self, ctrl end,
	}
	--Create a table with the callback functions parameters
	local callbackParams = { eventCallbackFunctionsSignatures[eventName]() }
	--Pass in the callback params to the narrateFunction
	local narrateText, stopCurrent = narrateCallbackFuncForEvent(unpack(callbackParams))

--d( ">NarrateText: " ..tos(narrateText) .. ", stopCurrent: " ..tos(stopCurrent))
	--Didn't the addon take care of the narration itsself? So this library here should narrate the text returned
	if type(narrateText) == "string" then
		local narrateFuncOfLibrary = narrationEventToLibraryNarrateFunction[eventName]
		if narrateFuncOfLibrary == nil then return end
		narrateFuncOfLibrary(narrateText, stopCurrent)
	end
end

-- used for onMouseEnter[submenu] and onMouseUp[contextMenu]
function comboBox_base:ShowDropdownOnMouseAction(parentControl)
	if self:IsDropdownVisible() then
		-- If submenu was currently opened, close it so it can reset.
		self:HideDropdown()
	end
	
	self:ShowDropdown()
	self.m_dropdownObject:SetHidden(false)
	self:AddMenuItems(parentControl)

	self:SetVisible(true)
end

function comboBox_base:ShowSubmenu(parentControl)
	-- We don't want a submenu to open under the context menu or it's submenus.
	if g_contextMenu:IsDropdownVisible() then
		g_contextMenu:HideDropdown()
	end

	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

-- These are part of the m_dropdownObject but, since we now use them from the comboBox, 
-- they are added here to reference the ones in the m_dropdownObject.
function comboBox_base:IsMouseOverControl()
	return self.m_dropdownObject:IsMouseOverControl()
end

function comboBox_base:SetupEntryBase(control, data, list)
	self.m_dropdownObject:SetupEntryBase(control, data, list)
end

do -- Row setup functions
	local function applyEntryFont(control, font, color, horizontalAlignment)
		if font then
			control.m_label:SetFont(font)
		end
		
		if color then
			control.m_label:SetColor(color:UnpackRGBA())
		end
		
		if horizontalAlignment then
			control.m_label:SetHorizontalAlignment(horizontalAlignment)
		end
	end

	local function addIcon(control, data, list)
		control.m_iconContainer = control.m_iconContainer or control:GetNamedChild("IconContainer")
		local iconContainer = control.m_iconContainer
		control.m_icon = control.m_icon or iconContainer:GetNamedChild("Icon")
		updateIcons(control, data)
	end

	local function addArrow(control, data, list)
		control.m_arrow = control:GetNamedChild("Arrow")
		data.hasSubmenu = true
	end

	local function addDivider(control, data, list)
		control.m_divider = control:GetNamedChild("Divider")
	end

	local function addLabel(control, data, list)
		control.m_label = control.m_label or control:GetNamedChild("Label")
		
		control.m_label:SetText(data.label or data.name) -- Use alternative passed in label string, or the default mandatory name string
	end
	
	function comboBox_base:SetupEntryDivider(control, data, list)
		control.typeId = DIVIDER_ENTRY_ID
		addDivider(control, data, list)
		self:SetupEntryBase(control, data, list)
	end

	function comboBox_base:SetupEntryLabelBase(control, data, list)
		local font = getValueOrCallback(data.font, data)
		font = font or self:GetDropdownFont()
		
		local color = getValueOrCallback(data.color, data)
		color = color or self:GetItemNormalColor(data)
		
		local horizontalAlignment = getValueOrCallback(data.horizontalAlignment, data)
		horizontalAlignment = horizontalAlignment or self.horizontalAlignment
		
		applyEntryFont(control, font, color, alignment)
		self:SetupEntryBase(control, data, list)
	end
	
	function comboBox_base:SetupEntryLabel(control, data)
		control.typeId = ENTRY_ID
		addIcon(control, data, list)
		addLabel(control, data, list)
		self:SetupEntryLabelBase(control, data, list)
	end

	function comboBox_base:SetupEntryHeader(control, data, list)
		self:SetupEntryLabel(control, data, list)
		addArrow(control, data, list)
		control.isHeader = true
		control.typeId = HEADER_ENTRY_ID
	end

	function comboBox_base:SetupEntrySubmenu(control, data, list)
		addDivider(control, data, list)
		self:SetupEntryLabel(control, data, list)
		control.typeId = SUBMENU_ENTRY_ID
	end
	
	function comboBox_base:SetupCheckbox(control, data, list)
		local function setChecked(checkbox, checked)
			local checkedData   = ZO_ScrollList_GetData(checkbox:GetParent())
			
			checkedData.checked = checked
			if checkedData.callback then
				checkedData.callback(checked, checkedData)
			end
			
			self:Narrate("OnCheckboxUpdated", checkbox, checkedData, nil)
			lib:FireCallbacks('CheckboxUpdated', checked, checkedData, checkbox)
		end
		
		self:SetupEntryLabel(control, data, list)
		control.isCheckbox = true
		control.typeId = CHECKBOX_ENTRY_ID
		
		control.m_checkbox = control.m_checkbox or control:GetNamedChild("Checkbox")
		local checkbox = control.m_checkbox
		ZO_CheckButton_SetToggleFunction(checkbox, setChecked)
		ZO_CheckButton_SetCheckState(checkbox, getValueOrCallback(data.checked, data))
	end
end


-- Blank
function comboBox_base:GetMaxRows()
	-- Overwrite at subclasses
end

function comboBox_base:UpdateOptions(options, onInit)
	-- Overwrite at subclasses
end

--------------------------------------------------------------------
-- comboBoxClass
--------------------------------------------------------------------
local comboBoxClass = comboBox_base:Subclass()

-- comboBoxClass:New(To simplify locating the beginning of the class
function comboBoxClass:Initialize(parent, comboBoxContainer, options, depth)
	comboBoxContainer.m_comboBox = self

	--Reset to the default ZO_ComboBox variables
	self:ResetToDefaults()

	-- Add all comboBox defaults not present.
	self.m_name = comboBoxContainer:GetName()
	self.m_openDropdown = comboBoxContainer:GetNamedChild("OpenDropdown")
	self.m_containerWidth = comboBoxContainer:GetWidth()
	self.m_selectedItemText = comboBoxContainer:GetNamedChild("SelectedItemText")
	self.m_multiSelectItemData = {}
	comboBox_base.Initialize(self, parent, comboBoxContainer, options, depth)
	
	return self
end

-- [Replaced functions]

-- Changed to force updating items and, to set anchor since anchoring was removed from :Show( due to separate anchoring based on comboBox type. (comboBox to self /submenu to row/contextMenu to mouse)
function comboBoxClass:AddMenuItems()
	self:UpdateItems()
	self.m_dropdownObject:AnchorToComboBox(self)
	
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
end

function comboBoxClass:HideDropdownInternal()
	zo_comboBox_hideDropdownInternal(self)
	hideTooltip()
end

-- Changed to bypass if needed.
function comboBoxClass:OnGlobalMouseUp(eventCode, ...)
--d("[LSM]comboBoxClass:OnGlobalMouseUp - BypassOnGlobalMouseUp: " ..tos(self:BypassOnGlobalMouseUp(...)))
	if not self:BypassOnGlobalMouseUp(...) then
	   zo_comboBox_onGlobalMouseUp(self ,eventCode , ...)
	else
		local mocCtrl = moc()
		local moc_dropdownObject = mocCtrl.m_dropdownObject -- or mocCtrl.m_comboBox and mocCtrl.m_comboBox.m_dropdownObject
		if not moc_dropdownObject then
			-- Right-click will close if not over dropdown
			self:HideDropdown()
			
			-- Without this, right-clicking outside will close dropdown but not context menu
			if g_contextMenu:IsDropdownVisible() then
				g_contextMenu:HideDropdown()
			end
		end
	end
end

-- [New functions]
function comboBoxClass:GetMaxRows()
	return self.visibleRows or DEFAULT_VISIBLE_ROWS
end

function comboBoxClass:GetMenuPrefix()
	return 'Menu'
end

function comboBoxClass:HideOnMouseEnter()
	--d( 'comboBoxClass:HideOnMouseEnter')
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() and not self:IsMouseOverControl() then
		self.m_submenu:HideDropdown()
	end
end

function comboBoxClass:HideOnMouseExit(mocCtrl)
--d("[LSM]comboBoxClass:HideOnMouseExit")
	if self.m_submenu and not self.m_submenu:IsMouseOverControl() and not self.m_submenu:IsMouseOverOpeningControl() then
--d(">submenu found, but mouse not over it! HideDropdown")
		self.m_submenu:HideDropdown()
		return true
	end
end


function comboBoxClass:SetOption(key)
	local options = self.options
	local currentValue = self[key] -- ZO_ComboBox object[key]
	local newValue = getValueOrCallback(options[key], options) --read nwew value from the options (run function there or get the value)
	if newValue == false then
		-- if new value is false, it will stay false
		currentValue = newValue
	end
	newValue = newValue or currentValue

	local setOptionFuncOrKey = LSMOptionsToZO_ComboBoxOptions[key]
	if type(setOptionFuncOrKey) == "function" then
		setOptionFuncOrKey(self, newValue)
	else
		self[setOptionFuncOrKey] = newValue
	end
end


--[[
--20240407 Baertram
-Ways to update the options-
1) combobox:UpdateOptions(options, onInit)
2) API SetCustomScrollableMenuOptions(options, comboBoxContainer)
a) 2nd param comboBoxContainer = nil -> Update LSM context menu optionsData internally and use on next OnShow of context menu
b) 2nd param comboBoxContainer is provided -> Update LSM scrollable menu via comboBoxContainer:UpdateOptions()


-Possible cases for updated options-
1) Init of new combobox with LSM:
a) If options passed in: use those
-->If parts of options are missing: Should be used internaly from ZO_ComboBox defaults -> So call self:ResetToDefaults()
b) If no options passed in / options nil: 	Should be used internaly from ZO_ComboBox defaults -> So call self:ResetToDefaults()


2) Update of already available combobox with LSM:
a) If options passed in: use those
-->If parts of options are missing: Should be used internaly from ZO_ComboBox -> so use self.attribute (e.g. self.m_font)
b) If no options passed in / options nil: Init with self:ResetToDefaults() and skip UpdateOptions() to AddCustomEntryTemplates


3) Init of new LSM context menu:
a) If options passed in: use those
-->If parts of options are missing: Should be used internaly from ZO_ComboBox defaults -> So call self:ResetToDefaults()
b) If no options passed in / options nil: self:ResetToDefaults()


4) Update existing contextMenu of LSM:
a)-If options passed in: use those
-->If parts of options are missing: Should be used internaly from ZO_ComboBox defaults -> So call self:ResetToDefaults()
b) If no options passed in / options nil: Init with self:ResetToDefaults() and skip UpdateOptions() to AddCustomEntryTemplates
]]
function comboBoxClass:UpdateOptions(options, onInit)
	onInit = onInit or false
	local optionsChanged = self.optionsChanged

	--Called from Initialization of the object -> self:ResetToDefaults() was called in comboBoxClass:Initialize() already
	-->And self:UpdateOptions() is then called via comboBox_base.Initialize(...), from where we get here
	if onInit == true then
		--Do not change any other options, just init. the combobox -> call self:AddCustomEntryTemplates(options) ands set
		--optionsChanged to false (self.options will be nil at that time)
		optionsChanged = false
	else
		--self.optionsChanged might have been set by contextMenuClass:SetOptions(options) already. Check that first and keep that boolean state as we
		--do not use self.options but self.optionsData here:
		--->Coming from contextMenuClass:ShowContextMenu() -> self.optionsData was set via contextMenuClass:SetOptions(options) before, and will be passed in here
		--->to UpdateOptions(options) as options parameter. self.optionsChanged will be true if the options changed at the contex menu (compared to old self.optionsData)
		---->self.optionsData  is then used at OnShow of the context menu. That's why we cannot compare the self.options here!
		--
		--For other "non-context menu" calls: Compare the already stored self.options table to the new passed in options table (both could be nil though)
		optionsChanged = optionsChanged or options ~= self.options
	end


	--(Did the options change: Yes / OR are we initializing a ZO_ComboBox ) / AND Are the new passed in options nil or empty: Yes
	--> Reset to default ZO_ComboBox variables and just call AddCustomEntryTemplates()
	if (optionsChanged == true or onInit == true) and ZO_IsTableEmpty(options) then
		optionsChanged = false
		self:ResetToDefaults()

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

		--Set the passed in options to the ZO_ComboBox .options table (for future comparison, see above at optionsChanged = optionsChanged or options ~= self.options)
		self.options = options

		-- Defaults are predefined in defaultComboBoxOptions, but they will be taken from ZO_ComboBox defaults set from table comboBoxDefaults
		-- at function self:ResetToDefaults().
		-- If any variable was set to the ZO_ComboBox already (e.g. self.m_font) it will be used again from that internal variable, if nothing
		-- was overwriting it here from passed in options table

		-- LibScrollableMenu custom options
		for key, _ in pairs(options) do
			self:SetOption(key)
		end

		--[[
		self.visibleRows = getValueOrCallback(options.visibleRowsDropdown, options) or self.visibleRows
		self.visibleRowsSubmenu = getValueOrCallback(options.visibleRowsSubmenu, options) or self.visibleRowsSubmenu
		self.m_headerFontColor = getValueOrCallback(options.headerColor, options) or self.m_headerFontColor
		self.narrateData = getValueOrCallback(options.narrate, options)
		local disableFadeGradient = getValueOrCallback(options.disableFadeGradient, options)
		disableFadeGradient = disableFadeGradient ~= nil and disableFadeGradient or self.disableFadeGradient
		self.disableFadeGradient = disableFadeGradient

		-- ZO_ComboBox options
		local font = getValueOrCallback(options.font, options) or self.m_font
		local spacing = getValueOrCallback(options.spacing, options) or self.m_spacing
		local sortEntries = getValueOrCallback(options.sortEntries, options)
		sortEntries = sortEntries == nil and self.m_sortsItems or sortEntries
		local sortType = getValueOrCallback(options.sortType, options) or self.m_sortType
		local sortOrder = getValueOrCallback(options.sortOrder, options) or self.m_sortOrder
		local preshowDropdownFn = getValueOrCallback(options.preshowDropdownFn, options)
		if preshowDropdownFn then
			self:SetPreshowDropdownCallback(preshowDropdownFn)
		end

		--Apply ZO_ComboBox options now
		self:SetSortsItems(sortEntries)
		self:SetFont(font)
		self:SetSpacing(spacing)
		self:SetSortOrder(sortOrder, sortType)
		]]
	end

	-- this will add custom and default templates to self.XMLrowTemplates the same way dataTypes were created before.
	self:AddCustomEntryTemplates(options)
end



function comboBoxClass:ResetToDefaults()
	local defaults = ZO_DeepTableCopy(comboBoxDefaults)
	mixinTableAndSkipExisting(self, defaults)

	self.options = nil
end


--------------------------------------------------------------------
-- submenuClass
--------------------------------------------------------------------

-- Pass-through variables
submenuClass.exposedVariables = {
	-- ZO_ComboBox
	["m_font"] = true, -- 
	["m_height"] = false, -- needs to be separate for visibleRowsSubmenu
	['m_normalColor'] = true, -- 
	['m_highlightColor'] = true, -- 
	['m_containerWidth'] = true, -- 
	['m_maxNumSelections'] = true, -- 
	['m_enableMultiSelect'] = true, -- 
	["m_customEntryTemplateInfos"] = false, -- Allowing this to paas-through would break row setup.
	
	-- ZO_ComboBox_Base
	["m_name"] = true, -- since the name is acquired by the container name.
	["m_spacing"] = true, -- 
	["m_sortType"] = true, -- 
	["m_container"] = true, -- all children use the same container as the comboBox
	["m_sortOrder"] = true, -- 
	["m_sortsItems"] = true, -- 
	["m_sortedItems"] = false, -- for obvious reasons
	["m_openDropdown"] = false, -- control
	["m_selectedColor"] = true, -- 
	["m_disabledColor"] = true, -- 
	["m_selectedItemText"] = false, -- This is handeled by "SelectItem"
	["m_selectedItemData"] = false, -- This is handeled by "SelectItem"
	["m_isDropdownVisible"] = false, -- each menu has different dropdowns
	["m_preshowDropdownFn"] = true, -- 
	["horizontalAlignment"] = true, -- 
	
	-- LibScrollableMenu
	['options'] = true,
	['narrateData'] = true,
	['filterString'] = true,
	['m_headerFont'] = true,
	['XMLrowTemplates'] = true, --TODO: is this being overwritten?
	['m_headerFontColor'] = true,
	['visibleRowsSubmenu'] = true, -- we only need this "visibleRowsSubmenu" for the submenus
	['disableFadeGradient'] = true,
}
local submenuClass_exposedVariables = submenuClass.exposedVariables

submenuClass.exposedFunctions = {
	["SelectItem"] = true, -- (item, ignoreCallback)
}
local submenuClass_exposedFunctions = submenuClass.exposedFunctions

submenuClass.exposedMetatable = {
	__index = function (obj, key)
		if submenuClass_exposedVariables[key] then
			local value = obj.m_comboBox[key]
			if value then
				return value
			end
		end
		
		local value = submenuClass[key]
		if value then
			if submenuClass_exposedFunctions[key] then
				return function(self, ...)
					return value(self.m_comboBox, ...)
				end
			end
		
			return value
		end
	end
}

function submenuClass:New(...)
	local newObject = setmetatable({},  self.exposedMetatable)
	newObject.__parentClasses = {self}
	newObject:Initialize(...)
	return newObject
end

-- submenuClass:New(To simplify locating the beginning of the class
function submenuClass:Initialize(parent, comboBoxContainer, options, depth)
--	d( '[LSM]submenuClass:Initialize')
	self.m_comboBox = comboBoxContainer.m_comboBox
	self.isSubmenu = true
	self.m_parentMenu = parent
	
	comboBox_base.Initialize(self, parent, comboBoxContainer, options, depth)
end

function submenuClass:UpdateOptions(options, onInit)
	self:AddCustomEntryTemplates(self.options)
end

function submenuClass:AddMenuItems(parentControl)
	self.openingControl = parentControl
	self:RefreshSortedItems(parentControl)
	
	self:UpdateItems()
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())

	self.m_dropdownObject:AnchorToControl(parentControl)
end

function submenuClass:GetMaxRows()
	return self.visibleRowsSubmenu or DEFAULT_VISIBLE_ROWS
end

function submenuClass:GetMenuPrefix()
	return 'SubMenu'
end

-- Used to take entries from "data" and add them to m_sortedItems
function submenuClass:RefreshSortedItems(parentControl)
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)
	local data = getControlData(parentControl)

	for k, item in ipairs(data.entries) do
		item.m_parentControl = parentControl
		-- update strings by functions will be done in AddItem
		self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
	end
end

function submenuClass:OnGlobalMouseUp(eventCode, ...)
--d("[LSM]submenuClass:OnGlobalMouseUp - DropdownVisible: " ..tos(self:IsDropdownVisible()) ..", BypassOnGlobalMouseUp: " ..tos(self:BypassOnGlobalMouseUp(...)))
	if self:IsDropdownVisible() and not self:BypassOnGlobalMouseUp(...) then
		self:HideDropdown()
	end
end

function submenuClass:ShowDropdownInternal()
	if self.m_dropdownObject then
		local control = self.m_dropdownObject.control
		control:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self:OnGlobalMouseUp(...) end)
	end
end

function submenuClass:HideDropdownInternal()
	-- m_container for a fallback
	local control = self.m_container
	if self.m_dropdownObject then
		control = self.m_dropdownObject.control
		control:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)
	end
	
	updateIsContextMenuAndIsSubmenu(self)
	if not self.isContextMenu then
	--	self:Narrate("OnSubMenuHide", control)
		lib:FireCallbacks('OnSubMenuHide', control)
	end
	
	if self.m_dropdownObject:IsOwnedByComboBox(self) then
		self.m_dropdownObject:SetHidden(true)
	end
	self:SetVisible(false)
	if self.onHideDropdownCallback then
		self.onHideDropdownCallback()
	end
end

function submenuClass:HideOnMouseExit(mocCtrl)
--d("[LSM]submenuClass:HideOnMouseExit")
	-- Only begin hiding if we stopped over a dropdown.
	mocCtrl = mocCtrl or moc()
	if mocCtrl.m_dropdownObject then
		if comboBoxClass.HideOnMouseExit(self) then
			-- Close all open submenus beyond this point
			
			-- This will only close the dropdown if the mouse is not over the dropdown or over the control that opened it.
			if not (self:IsMouseOverControl() or self:IsMouseOverOpeningControl()) then
				self:HideDropdown()
			end
		end
	end
end

function submenuClass:IsMouseOverOpeningControl()
	return MouseIsOver(self.openingControl)
end

--------------------------------------------------------------------
-- contextMenuClass
--------------------------------------------------------------------

local contextMenuClass = comboBoxClass:Subclass()
-- LibScrollableMenu.contextMenu
-- contextMenuClass:New(To simplify locating the beginning of the class
function contextMenuClass:Initialize(comboBoxContainer)
	comboBoxClass.Initialize(self, nil, comboBoxContainer, nil, 1)
	self.data = {}
	
	self:ClearItems()

	self.isContextMenu = true
end

-- Renamed from AddItem since AddItem can be the same as base. This function is only to pre-set data for updating on show,
function contextMenuClass:AddContextMenuItem(itemEntry, updateOptions)
	tins(self.data, itemEntry)
	
--	m_unsortedItems
end

function contextMenuClass:AddMenuItems()
	self:RefreshSortedItems()
	self:UpdateItems()
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.m_containerWidth, self.m_height, self:GetSpacing())
	self.m_dropdownObject:AnchorToMouse()
	self.m_dropdownObject.control:BringWindowToTop()
end

function contextMenuClass:ClearItems()
	self:SetOptions(nil)
	
	ZO_ComboBox_HideDropdown(self:GetContainer())
	ZO_ClearNumericallyIndexedTable(self.data)
	
	self:SetSelectedItemText("")
	self.m_selectedItemData = nil
	self:OnClearItems()
end

function contextMenuClass:GetMenuPrefix()
	return 'Contextmenu'
end

function contextMenuClass:ShowSubmenu(parentControl)
	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

function contextMenuClass:ShowContextMenu(parentControl)
	self.openingControl = parentControl

	self:UpdateOptions(self.optionsData)

	-- Let the caller know that this is about to be shown...
	if self.m_preshowDropdownFn then
		self.m_preshowDropdownFn(self)
	end
	
	self:ShowDropdown()
	self:ShowDropdownOnMouseUp(parentControl)
end

function contextMenuClass:HideDropdownInternal()
	comboBoxClass.HideDropdownInternal(self)
	self:ClearItems()
end

-- Used to take entries from "data" and add them to m_sortedItems
function contextMenuClass:RefreshSortedItems()
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)

	for k, item in ipairs(self.data) do
		self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
	end
end

function contextMenuClass:SetOptions(options)
	-- self.optionsData is only a temporary table used check for change and to send to UpdateOptions.
	self.optionsChanged = self.optionsData ~= options
	self.optionsData = options
end

function contextMenuClass:SetPreshowDropdownCallback()
	-- Intentionally blank. This is to prevent abusing the function in the context menu.
end

function contextMenuClass:OnGlobalMouseUp(eventCode, ...)
--d("[LSM]contextMenuClass:OnGlobalMouseUp")
	submenuClass.OnGlobalMouseUp(self, eventCode, ...)
end

--------------------------------------------------------------------
-- 
--------------------------------------------------------------------
-- We need to integrate a supplied ZO_ComboBox with the lib's functionality.
-- We do this by replacing the metatable with comboBoxClass.

function comboBoxClass:UpdateMetatable(parent, comboBoxContainer, options)
	setmetatable(self, comboBoxClass)
	ApplyTemplateToControl(comboBoxContainer, 'LibScrollableMenu_ComboBox_Behavior')
	lib:FireCallbacks('OnDropdownMenuAdded', self, options)
	self:Initialize(parent, comboBoxContainer, options, 1)
end

--------------------------------------------------------------------
-- Public API functions
--------------------------------------------------------------------
lib.persistentMenus = false -- controls if submenus are closed shortly after the mouse exists them
							-- 2024-03-10 Currently not used anywhere!!!
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
--	control comboBoxContainer 				Must be any ZO_ComboBox control (e.g. created from virtual template ZO_ComboBox)
--  table options:optional = {
--		number visibleRowsDropdown:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened dropdown
--		number visibleRowsSubmenu:optional		Number or function returning number of shown entries at 1 page of the scrollable comboBox's opened submenus
--		boolean sortEntries:optional			Boolean or function returning boolean if items in the main-/submenu should be sorted alphabetically: ZO_SORT_ORDER_UP or ZO_SORT_ORDER_DOWN
--		table sortType:optional					table or function returning table for the sort type, e.g. ZO_SORT_BY_NAME, ZO_SORT_BY_NAME_NUMERIC
--		boolean sortOrder:optional				Boolean or function returning boolean for the sort order
-- 		string font:optional = "FontNameHere" 	String or function returning a string: font to use for the dropdown entries
-- 		number spacing:optional = 1, 			Number or function returning a Number : Spacing between the entries
--		boolean disableFadeGradient:optional	Boolean or function returning a boolean for the fading of the top/bottom scrolled rows
--		table headerColor						table or function returning a color table with r, g, b, a keys and their values
-- 		function preshowDropdownFn:optional 	function function(ctrl) codeHere end to run before the dropdown shows
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
--													and let the library here narrate it for you via the UI narration
--												Optional narration events can be:
--												"OnComboBoxMouseEnter" 	function(m_dropdownObject, comboBoxControl)  Build your narrateString and narrate it now, or return a string and let the library narrate it for you end
--												"OnComboBoxMouseExit"	function(m_dropdownObject, comboBoxControl) end
--												"OnMenuShow"			function(m_dropdownObject, dropdownControl, nil, nil) end
--												"OnMenuHide"			function(m_dropdownObject, dropdownControl) end
--												"OnSubMenuShow"			function(m_dropdownObject, parentControl, anchorPoint) end
--												"OnSubMenuHide"			function(m_dropdownObject, parentControl) end
--												"OnEntryMouseEnter"		function(m_dropdownObject, entryControl, data, hasSubmenu) end
--												"OnEntryMouseExit"		function(m_dropdownObject, entryControl, data, hasSubmenu) end
--												"OnEntrySelected"		function(m_dropdownObject, entryControl, data, hasSubmenu) end
--												"OnCheckboxUpdated"		function(m_dropdownObject, checkboxControl, data) end
--			Example:	narrate = { ["OnComboBoxMouseEnter"] = myAddonsNarrateComboBoxOnMouseEnter, ... }
--  }
function AddCustomScrollableComboBoxDropdownMenu(parent, comboBoxContainer, options)
	assert(parent ~= nil and comboBoxContainer ~= nil, MAJOR .. " - AddCustomScrollableComboBoxDropdownMenu ERROR: Parameters parent and comboBoxContainer must be provided!")

	local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
	assert(comboBox and comboBox.IsInstanceOf and comboBox:IsInstanceOf(ZO_ComboBox), MAJOR .. ' | The comboBoxContainer you supplied must be a valid ZO_ComboBox container. "comboBoxContainer.m_comboBox:IsInstanceOf(ZO_ComboBox)"')
	
	comboBoxClass.UpdateMetatable(comboBox, parent, comboBoxContainer, options)
	
	return comboBox.m_dropdownObject
end
																					   

--[Custom scrollable context menu at any control]
--Add a scrollable menu to any control (not only a ZO_ComboBox), e.g. to an inventory row
--by creating a DUMMY ZO_ComboBox, adding the ScrollHelper class to it and use it
----------------------------------------------------------------------

--Adds a new entry to the context menu entries with the shown text, where the callback function is called once the entry is clicked.
--If entries is provided the entry will be a submenu having those entries. The callback can be used, if entries are passed in, too (to select a special entry and not an enry of the opening submenu).
--But usually it should be nil if entries are specified, as each entry in entries got it's own callback then.
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
--
--Example - Normal entry without submenu
--AddCustomScrollableMenuEntry("Test entry 1", function() d("test entry 1 clicked") end, LibScrollableMenu.LSM_ENTRY_TYPE_NORMAL, nil, nil)
--Example - Normal entry with submenu
--AddCustomScrollableMenuEntry("Test entry 1", function() d("test entry 1 clicked") end, LibScrollableMenu.LSM_ENTRY_TYPE_NORMAL, {
--	{
--		label = "Test submenu entry 1", --optional String or function returning a string. If missing: Name will be shown and used for clicked callback value
--		name = "TestValue1" --String or function returning a string if label is givenm name will be only used for the clicked callback value
--		isHeader = false, -- optional boolean or function returning a boolean Is this entry a non clickable header control with a headline text?
--		isDivider = false, -- optional boolean or function returning a boolean Is this entry a non clickable divider control without any text?
--		isCheckbox = false, -- optional boolean or function returning a boolean Is this entry a clickable checkbox control with text?
--		isNew = false, --  optional booelan or function returning a boolean Is this entry a new entry and thus shows the "New" icon?
--		entries = { ... see above ... }, -- optional table containing nested submenu entries in this submenu -> This entry opens a new nested submenu then. Contents of entries use the same values as shown in this example here
--		contextMenuCallback = function(ctrl) ... end, -- optional function for a right click action, e.g. show a scrollable context menu at the menu entry
-- }
--}, nil)
function AddCustomScrollableMenuEntry(text, callback, entryType, entries, isNew)
	assert(text ~= nil, sfor('['..MAJOR..':AddCustomScrollableMenuEntry] String or function returning a string expected, got %q = %s', "text", tos(text)))
--	local scrollHelper = initCustomScrollMenuControl()
--	scrollHelper = scrollHelper or getScrollHelperObjectFromControl(customScrollableMenuComboBox)
	local options = g_contextMenu:GetOptions()

	--If no entryType was passed in: Use normal text line type
	entryType = entryType or lib.LSM_ENTRY_TYPE_NORMAL
	if not allowedEntryTypesForContextMenu[entryType] then
		entryType = lib.LSM_ENTRY_TYPE_NORMAL
	end
	--If an entry type is used which does need a callback, and no submenu entries were passed in additionally: error the missing callback
	if entries == nil and not entryTypesForContextMenuWithoutMandatoryCallback[entryType] then
		assert(type(callback) == "function", sfor('['..MAJOR..':AddCustomScrollableMenuEntry] Callback function expected, got %q = %s', "callback", tos(callback)))
	end

	--Or is it a header line?
	local isHeader = entryType == lib.LSM_ENTRY_TYPE_HEADER
	--Or a clickable checkbox line?
	local isCheckbox = entryType == lib.LSM_ENTRY_TYPE_CHECKBOX
	--or just a ---------- divider line?
	local isDivider = entryType == lib.LSM_ENTRY_TYPE_DIVIDER or text == libDivider
	if isDivider == true then entryType = lib.LSM_ENTRY_TYPE_DIVIDER end

	--Add the line of the context menu to the internal tables. Will be read as the ZO_ComboBox's dropdown opens and calls
	--:AddMenuItems() -> Added to internal scroll list then
	g_contextMenu:AddContextMenuItem({
		isDivider		= isDivider,
		isHeader		= isHeader,
		isCheckbox		= isCheckbox,
		isNew			= getValueOrCallback(isNew, options) or false,
		--The shown text line of the entry
		name			= getValueOrCallback(text, options),
		--Callback function as context menu entry get's selected. Will also work for an enry where a submenu is available (but usually is not provided in that case)
		callback		= not isDivider and callback, --ZO_ComboBox:SelectItem will call the item.callback(self, item.name, item), where item = { isHeader = ... }
		--Any submenu entries (with maybe nested submenus)?
		entries			= entries,
	}, ZO_COMBOBOX_SUPPRESS_UPDATE)
end
local addCustomScrollableMenuEntry = AddCustomScrollableMenuEntry

--Adds an entry having a submenu (or maybe nested submenues) in the entries table
--> See examples for the table "entries" values above AddCustomScrollableMenuEntry
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableSubMenuEntry(text, entries)
	addCustomScrollableMenuEntry(text, nil, lib.LSM_ENTRY_TYPE_NORMAL, entries, nil)
end

--Adds a divider line to the context menu entries
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableMenuDivider()
	addCustomScrollableMenuEntry(libDivider, nil, lib.LSM_ENTRY_TYPE_DIVIDER, nil, nil)
end

--Set the options (visible rows max, etc.) for the scrollable context menu, or any passed in 2nd param comboBoxContainer
-->See possible options above AddCustomScrollableComboBoxDropdownMenu
function SetCustomScrollableMenuOptions(options, comboBoxContainer)
	--local optionsTableType = type(options)
	--assert(optionsTableType == 'table' , sfor('['..MAJOR..':SetCustomScrollableMenuOptions] table expected, got %q = %s', "options", tos(optionsTableType)))

	--if options ~= nil then
		--Use specified comboBoxContainer's dropdown to update the options to
		if comboBoxContainer ~= nil then
			local comboBox = ZO_ComboBox_ObjectFromContainer(comboBoxContainer)
			if comboBox ~= nil and comboBox.UpdateOptions then
				comboBox.optionsChanged = options ~= comboBox.options
				comboBox:UpdateOptions(options)
			end
		else
			--Update options to default contextMenu
			g_contextMenu:SetOptions(options)
		end
	--end
end
local setCustomScrollableMenuOptions = SetCustomScrollableMenuOptions

--Hide the custom scrollable context menu and clear it's entries, clear internal variables, mouse clicks etc.
function ClearCustomScrollableMenu()
	--d("[LSM]ClearCustomScrollableMenu")
	g_contextMenu:ClearItems()

	setCustomScrollableMenuOptions(defaultComboBoxOptions, nil)
	return true
end
local clearCustomScrollableMenu = ClearCustomScrollableMenu

--Pass in a table with predefined context menu entries and let them all be added in order of the table's number key
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function AddCustomScrollableMenuEntries(contextMenuEntries)
	if ZO_IsTableEmpty(contextMenuEntries) then return end
	for _, v in ipairs(contextMenuEntries) do
		addCustomScrollableMenuEntry(v.label or v.name, v.callback, v.entryType, v.entries, v.isNew)
	end
	return true
end
local addCustomScrollableMenuEntries = AddCustomScrollableMenuEntries

--Populate a new scrollable context menu with the defined entries table.
--Existing context menu entries will be reset, because ClearCustomScrollableMenu will be called!
--You can add more entries later, prior to showing, via AddCustomScrollableMenuEntry / AddCustomScrollableMenuEntries functions too
function AddCustomScrollableMenu(entries, options)
	--Clear the existing menu entries
	clearCustomScrollableMenu()

	local entryTableType = type(entries)
	assert(entryTableType == 'table' , sfor('['..MAJOR..':AddCustomScrollableMenu] table expected, got %q = %s', "entries", tos(entryTableType)))

	if options then
		setCustomScrollableMenuOptions(options)
	end
	
	return addCustomScrollableMenuEntries(entries)
end

--Show the custom scrollable context menu now at the control controlToAnchorTo, using optional options.
--If controlToAnchorTo is nil it will be anchored to the current control's position below the mouse, like ZO_Menu does
--Existing context menu entries will be kept (until ClearCustomScrollableMenu will be called)
function ShowCustomScrollableMenu(controlToAnchorTo, options)
	--d("[LSM]ShowCustomScrollableMenu")
	if options then
		setCustomScrollableMenuOptions(options)
	end

	controlToAnchorTo = controlToAnchorTo or moc()
	g_contextMenu:ShowContextMenu(controlToAnchorTo)
	return true
end

------------------------------------------------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------------------------------------------------
--Load of the addon/library starts
local function onAddonLoaded(event, name)
	if name:find("^ZO_") then return end
	EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)

	local comboBoxContainer = CreateControlFromVirtual(MAJOR .. "_ContextMenu", GuiRoot, "ZO_ComboBox")
	--Create the local context menu object for the library's context menu API functions
	g_contextMenu = contextMenuClass:New(comboBoxContainer)
	lib.contextMenu = g_contextMenu
end
EM:UnregisterForEvent(MAJOR, EVENT_ADD_ON_LOADED)
EM:RegisterForEvent(MAJOR, EVENT_ADD_ON_LOADED, onAddonLoaded)


------------------------------------------------------------------------------------------------------------------------
-- Global library reference
------------------------------------------------------------------------------------------------------------------------
LibScrollableMenu = lib


------------------------------------------------------------------------------------------------------------------------
-- Notes: | TODO:
------------------------------------------------------------------------------------------------------------------------

--[[
-------------------
WORKING ON - Current version: 2.1
-------------------
	- Fixed: comboBoxClass:OnGlobalMouseUp(eventCode, ...) must close all submenus and the main menu (dropdown) of the ZO_ComboBox if we right click on the main comboBox to show a context menu there,
	- Fixed: submenu defaults not inheriting from parent on initialize
	- Added: function sets to update name/label on AddItem and update on Show
	- Added: options.disableFadeGradient, options.headerColor
	
	- changed ScrollContent XML template names to LibScrollableMenu_ScrollContents_BarHidden, LibScrollableMenu_ScrollContents_BarShown
	- Adjusted AnchorToControl so submenus sit on edge of previous dropdown. +- 2 pixels to "4, -4", direction dependent.
	- Exposed row setup functions to object to allow addon use.
	- Isolated submenuClass:ShowDropdownInternal and submenuClass:HideDropdownInternalare also should be set independently based on class
		There was no need for the extra functions attached to dropdownClass
	-Added comboBoxClass:SetOption(key) function
	-Updated comboBoxClass:UpdateOptions() function

-------------------
TODO - To check (future versions)
-------------------
	1. recursive variable sharing for post init submenu updating ideas
		-- this is not recursive, it's direct access to comboBox's variables.
		-- example: comboBox.m_submenu.m_sortsItems returns comboBox.m_sortsItems. The same with comboBox.m_submenu.m_submenu.m_submenu.m_submenu.m_submenu.m_sortsItems. to the nth.
		-- This funnctions no matter where they are called from, even in the api.
		-- This means that no function calling any of the pass-through variables need to be modified to get the comboBox's variable from a submenu object.
		-- in actuallity, submenu.-variable- does not exist. As seen in TB. See about 2.
		-- The function "SelectItem" is allso "pass-through". No. It simply hands the function over too the comboBox.
		-- This makes it so, after the submenu data is colected from submenu.m_sortedItems, it will be handed directly through as submenu.SelectItem(comboBox, submenuItem)
		-- Which makes every self within SelectItem belong to the comboBox
		
		-- The best part about all this is, these variabels do not need to be inhereted on init and, they never need to be set in any submenu.
		1. hook all parent set functions regarding such variables on submenu init 
			-- No. This would break the purpos of the custom metatable.
			-- Setting any of the select variables from the submenu would actually create that variable in the submenu due to .__newindex. It would mean, if the variable is ever changed using the comboBox, it would no longer be reflected in that submenu.
		2. intercept specific functions in comboBox metatable and recursively fire corresponding functions for all available submenus. 
			-- This is not needed. If any function of the comboBox needs to be directly effected by the submenus, adding it to exposedFunctions is all that should be needed.
			-- I've only found this needed for "SelectItem". But, if other functions are found that would benift from this, they can be added too.
		3. intercept variables in comboBox metatable and recursively change available submenus. 
			-- All changes to any variable in exposedVariables, from the comboBox, will automatically be reflected in all child menus
		4. intercept variables in submenu metatable as shared with parent comboBox. 
			-- done
		5. clean up submenuClass:ShowDropdownInternal and submenuClass:HideDropdownInternalare, if needed.
		
		-- Since "SelectItem" is the only funcition currently using this metatable trick, we could just make a custom version of the function that does the same thing. 
		-- But, it would add some dificulty, beyond adding a string to a table, if ever there were other functions needing this action.
		
	2. Attention: zo_comboBox_base_hideDropdown(self) in self:HideDropdown() does NOT close the main dropdown if right clicked! Only for a left click... See ZO_ComboBox:HideDropdownInternal()
	3. Check if callback OnDropdownMenuAdded can change the options of a dropdown pre-init
	4. verify submenu anchors. Small adjustments not easily seen on small laptop monitor
	5. consider making a pre-show function to contain common calls prior to dropdownClass:Show(
		- update fade gradient state
		-
	6. Check if entries' .tooltip can be a function and then call that function and show it as normal ZO_Tooltips_ShowTextTooltip(control, text) instead of having to use .customTooltip for that

-------------------
UPCOMING FEATURES  - What will be added in the future?
-------------------
	1. String filter editbox at the top of dropdownbox allowing to filter for e.g. "search string". Search sring prefixed by "/" will be keeping submenu entries non-matching the search string
	2. Sort headers for the dropdown (ascending/descending) (maybe: allowing custom sort functions too)
	3. LibCustomMenu and ZO_Menu support in inventories
]]

