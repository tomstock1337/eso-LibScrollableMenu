local lib = LibScrollableMenu
if not lib then return end

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
local suppressNextOnGlobalMouseUp
local buttonGroupDefaultContextMenu

local libUtil = lib.Util
local getControlName = libUtil.getControlName


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------
-- LSM ComboBox base & submenu classes definition
--------------------------------------------------------------------

local comboBox_base = ZO_ComboBox:Subclass()
classes.comboboxBaseClass = comboBox_base

local submenuClass = comboBox_base:Subclass()
classes.submenuClass = submenuClass


--------------------------------------------------------------------
-- LSM comboBox base class
--------------------------------------------------------------------
function comboBox_base:Initialize(parent, comboBoxContainer, options, depth, initExistingComboBox)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 84, tos(getControlName(parent)), tos(getControlName(comboBoxContainer)), tos(depth)) end
	self.m_sortedItems = {}
	self.m_unsortedItems = {}

	--Multiselection
    ---v- 20250128 do NOT set this default values to false or true, or else the metattable lookup from parent combobox won't work! -v-
	--self.m_enableMultiSelect = comboBoxDefaults.m_enableMultiSelect
    --self.m_maxNumSelections = comboBoxDefaults.m_maxNumSelections
    --self.m_multiSelectItemData = {}
	-- -^-

	self.m_container = comboBoxContainer
	local dropdownObject = self:GetDropdownObject(comboBoxContainer, depth)
	self:SetDropdownObject(dropdownObject)

	self:UpdateOptions(options, true, nil, initExistingComboBox)

--[[
LSM_DebugComboBoxBase = {
	isSubmenu = self.isSubmenu,
	self = ZO_ShallowTableCopy(self),
	options = (options ~= nil and ZO_ShallowTableCopy(options)) or nil,
}
]]

	self:SetupDropdownHeader()
	self:UpdateWidth()
	self:UpdateHeight()
end

-- Common functions
-- Adds the customEntryTemplate to all items added
function comboBox_base:AddItem(itemEntry, updateOptions, templates)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 85, tos(updateOptions), tos(self.baseEntryHeight), tos(templates)) end
	addItem_Base(self, itemEntry)
	zo_comboBox_base_addItem(self, itemEntry, updateOptions)
	tins(self.m_unsortedItems, itemEntry)
end

-- Adds widthPadding as a valid parameter
function comboBox_base:AddCustomEntryTemplate(entryTemplate, entryHeight, setupFunction, widthPadding)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 86, tos(entryTemplate), tos(entryHeight), tos(setupFunction), tos(widthPadding)) end
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

function comboBox_base:GetItemFontObject(item)
	local font = item.font or self:GetDropdownFont() --self.m_font
	return _G[font]
end

-- >> template, height, setupFunction
local function getTemplateData(entryType, template)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 87, tos(entryType), tos(template)) end
	local templateDataForEntryType = template[entryType]
	return templateDataForEntryType.template, templateDataForEntryType.rowHeight, templateDataForEntryType.setupFunc, templateDataForEntryType.widthPadding
end

local function getDefaultXMLTemplates(selfVar)
	--The virtual XML templates, with their setup functions for the row controls, for the different row types
	local defaultXMLTemplates  = {
		[LSM_ENTRY_TYPE_NORMAL] = {
			template = 'LibScrollableMenu_ComboBoxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
--d(debugPrefix .. "XMLtemplate LSM_ENTRY_TYPE_NORMAL, setupFunc")
				selfVar:SetupEntryLabel(control, data, list, LSM_ENTRY_TYPE_NORMAL)
			end,
		},
		[LSM_ENTRY_TYPE_SUBMENU] = {
			template = 'LibScrollableMenu_ComboBoxSubmenuEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthPadding = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntrySubmenu(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_DIVIDER] = {
			template = 'LibScrollableMenu_ComboBoxDividerEntry',
			rowHeight = DIVIDER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryDivider(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_HEADER] = {
			template = 'LibScrollableMenu_ComboBoxHeaderEntry',
			rowHeight = HEADER_ENTRY_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryHeader(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_CHECKBOX] = {
			template = 'LibScrollableMenu_ComboBoxCheckboxEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthPadding = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryCheckbox(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_BUTTON] = {
			template = 'LibScrollableMenu_ComboBoxButtonEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthPadding = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryButton(control, data, list)
			end,
		},
		[LSM_ENTRY_TYPE_RADIOBUTTON] = {
			template = 'LibScrollableMenu_ComboBoxRadioButtonEntry',
			rowHeight = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			widthPadding = ZO_COMBO_BOX_ENTRY_TEMPLATE_HEIGHT,
			setupFunc = function(control, data, list)
				selfVar:SetupEntryRadioButton(control, data, list)
			end,
		},
	}

	--The virtual XML highlight templates (mouse moved above an antry), for the different row types
	local defaultXMLHighlightTemplates = {
		[LSM_ENTRY_TYPE_NORMAL] = {
			template = defaultHighlightTemplate,
			templateContextMenuOpeningControl = defaultHighlightTemplate, --template for an entry providing a contextMenu
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_SUBMENU] = {
			template = defaultHighlightTemplate,
			templateContextMenuOpeningControl = defaultHighlightTemplate, --template for an entry providing a contextMenu
			templateSubMenuWithCallback = LSM_ROW_HIGHLIGHT_GREEN, -- template for the entry where a submenu is opened but you can click the entry to call a callback too
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_DIVIDER] = {
			template = defaultHighlightTemplate,
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_HEADER] = {
			template = defaultHighlightTemplate,
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_CHECKBOX] = {
			template = defaultHighlightTemplate,
			templateContextMenuOpeningControl = defaultHighlightTemplate, --template for an entry providing a contextMenu
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_BUTTON] = {
			template = defaultHighlightTemplate,
			templateContextMenuOpeningControl = defaultHighlightTemplate, --template for an entry providing a contextMenu
			color = defaultHighlightColor,
		},
		[LSM_ENTRY_TYPE_RADIOBUTTON] = {
			template = defaultHighlightTemplate,
			templateContextMenuOpeningControl = defaultHighlightTemplate, --template for an entry providing a contextMenu
			color = defaultHighlightColor,
		},
	}
	return defaultXMLTemplates, defaultXMLHighlightTemplates
end

--Called from comboBoxClass:UpdateOptions
function comboBox_base:AddCustomEntryTemplates(options, isContextMenu)
	--[[
	if isContextMenu then
		d(debugPrefix .. "comboBox_base:AddCustomEntryTemplates - options: " ..tos(options) .. ", contextMenu: " ..tos(isContextMenu))
	end
	]]
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 88, tos(options)) end

	local defaultXMLTemplates, defaultXMLHighlightTemplates = getDefaultXMLTemplates(self)

	--Were any options and options.XMLRowTemplates passed in?
	local optionTemplates = options and getValueOrCallback(options.XMLRowTemplates, options)
	--Copy the default XML templates to a new table (protect original one against changes!)
	local XMLrowTemplatesToUse = ZO_ShallowTableCopy(defaultXMLTemplates)

	--Check if all XML row templates are passed in, and update missing ones with default values
	if optionTemplates ~= nil then
--d(debugPrefix .. "options.XMLRowTemplates found!")
		for entryType, _ in pairs(defaultXMLTemplates) do
			if optionTemplates[entryType] ~= nil then
				--ZOs function overwrites exising table entries!
				zo_mixin(XMLrowTemplatesToUse[entryType], optionTemplates[entryType])
			end
		end
	end
	self.XMLRowTemplates = XMLrowTemplatesToUse


	--Custom highlight XML templates from options:
	--Was "one" highlight template (or color) provided, then use this for all row's entryTypes
	local customHighlightTemplateForAllEntryTypes = options and getValueOrCallback(options.highlightTemplate, options)
	local customHighlightColorForAllEntryTypes = options and getValueOrCallback(options.highlightColor, options)

	--Were any options and options.XMLRowHighlightTemplates passed in?
	local optionHighlightTemplates = options and getValueOrCallback(options.XMLRowHighlightTemplates, options)

	--Copy the default XML templates to a new table (protect original one against changes!)
	local XMLrowHighlightTemplatesToUse = ZO_ShallowTableCopy(defaultXMLHighlightTemplates)
	--Check if all XML row highlight templates are passed in, and update missing ones with default values
	--or set the template/color that should be used for all of the entryTypes
	if optionHighlightTemplates or customHighlightTemplateForAllEntryTypes or customHighlightColorForAllEntryTypes then
		--[[
		if isContextMenu then
			d(debugPrefix .. "customHighlightTemplateForAll: " .. tos(customHighlightTemplateForAllEntryTypes) ..", customHighlightColorForAll: ".. tos(customHighlightColorForAllEntryTypes) ..", optionHighlightTemplates: " .. tos(options.XMLRowHighlightTemplates))
		end
		]]
		for entryType, _ in pairs(defaultXMLHighlightTemplates) do
			--Any highlight templates passed in via options
			if optionHighlightTemplates and optionHighlightTemplates[entryType] then
	--[[
	if isContextMenu then
		d(">entryType: " .. tos(entryType) ..", customHighlightXML: " .. tos(optionHighlightTemplates[entryType].template) .. "; templateSubMenuWithCallback: " .. tos(optionHighlightTemplates[entryType].templateSubMenuWithCallback) .. "; templateContextMenuOpeningControl: " .. tos(optionHighlightTemplates[entryType].templateContextMenuOpeningControl))
	end
	]]
				--ZOs function overwrites exising table entries!
				zo_mixin(XMLrowHighlightTemplatesToUse[entryType], optionHighlightTemplates[entryType])
			end

			--Use one highlightTemplate for all normal highlights
			if customHighlightTemplateForAllEntryTypes ~= nil then
				XMLrowHighlightTemplatesToUse[entryType].template = customHighlightTemplateForAllEntryTypes
			end
			--use one highlight color for all normal highlights?
			if customHighlightColorForAllEntryTypes ~= nil then
				XMLrowHighlightTemplatesToUse[entryType].color = customHighlightColorForAllEntryTypes
			end
		end
	end
	--Will be used in comboBox_base:GetHighLightTemplate to get the template data for the rowType
	self.XMLRowHighlightTemplates = XMLrowHighlightTemplatesToUse


	--Set the row templates to use to the current object
	--[[ for debugging
		lib._debugXMLrowTemplates = lib._debugXMLrowTemplates or {}
		lib._debugXMLrowTemplates[self] = self
		if isContextMenu then
			LSM_DebugAddCustomEntryTemplates = {
				options = ZO_ShallowTableCopy(options),
				XMLRowHighlightTemplates = ZO_ShallowTableCopy(self.XMLRowHighlightTemplates)
			}
		end
	]]

	-- These register the templates and creates a dataType for each.
	for entryTypeId, entryTypeIsUsed in ipairs(libraryAllowedEntryTypes) do
		if entryTypeIsUsed == true then
			self:AddCustomEntryTemplate(getTemplateData(entryTypeId, XMLrowTemplatesToUse))
		end
	end

	--Update the current object's rowHeight (normal entry type)
	local normalEntryHeight = XMLrowTemplatesToUse[LSM_ENTRY_TYPE_NORMAL].rowHeight
	-- We will use this, per-comboBox, to set max rows.
	self.baseEntryHeight = normalEntryHeight
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 89, tos(normalEntryHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_DIVIDER].rowHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_HEADER].rowHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_CHECKBOX].rowHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_BUTTON].rowHeight), tos(XMLrowTemplatesToUse[LSM_ENTRY_TYPE_RADIOBUTTON].rowHeight)) end
end

--Called from ZO_ComboBox:ShowDropdownInternal() -> self.m_container:RegisterForEvent(EVENT_GLOBAL_MOUSE_UP, function(...) self:OnGlobalMouseUp(...) end)
function comboBox_base:OnGlobalMouseUp(eventId, button)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 90, tos(button), tos(suppressNextOnGlobalMouseUp)) end
--d(debugPrefix .. "comboBox_base:OnGlobalMouseUp-button: " ..tos(button) .. ", suppressNextMouseUp: " .. tos(suppressNextOnGlobalMouseUp))
	if suppressNextOnGlobalMouseUp then
		suppressNextOnGlobalMouseUp = nil
		return false
	end

	if self:IsDropdownVisible() then
		if not self.m_dropdownObject:IsMouseOverControl() then
--d(">>dropdownVisible -> not IsMouseOverControl")
			if self:HiddenForReasons(button) then
--d(">>>HiddenForReasons -> Hiding dropdown now")
				return self:HideDropdown()
			end
		end
	else
		if self.m_container:IsHidden() then
--d(">>>else - containerIsHidden -> Hiding dropdown now")
			self:HideDropdown()
		else
--d("<SHOW DROPDOWN OnMouseUp")
			lib.openMenu = self
			-- If shown in ShowDropdownInternal, the global mouseup will fire and immediately dismiss the combo box. We need to
			-- delay showing it until the first one fires.
			self:ShowDropdownOnMouseUp()
		end
	end
end

function comboBox_base:GetBaseHeight(control)
	-- We need to include the header height to allItemsHeight, or the scroll hight will include the header height.
	-- Filtering will result in a shorter list with scrollbars that extend byond it.
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 91, tos(getControlName(control)), tos(control.header ~= nil), tos(control.header ~= nil and control.header:GetHeight() or 0)) end
	if control.header then
		return control.header:GetHeight()--  + ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y
	end
	return 0
end

function comboBox_base:GetBaseWidth(control)
	-- We need to include the header width
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 91, tos(getControlName(control)), tos(control.header ~= nil), tos(control.header ~= nil and control.header:GetWidth() or 0)) end
	if control and control.header then
		local minWidth = control.header:GetWidth()
		if minWidth <= 0 then minWidth = MIN_WIDTH_WITHOUT_SEARCH_HEADER end
		return minWidth
	end
	return MIN_WIDTH_WITHOUT_SEARCH_HEADER
end


function comboBox_base:GetMaxDropdownHeight()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 92, tos(self.maxHeight)) end
	return self.maxHeight --is set via options.maxDropdownHeight -> see table LSMOptionsToZO_ComboBoxOptionsCallbacks
end

function comboBox_base:GetMaxDropdownWidth()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 179, tos(self.maxWidth)) end
	return self.maxWidth --is set via options.maxDropdownWidth -> see table LSMOptionsToZO_ComboBoxOptionsCallbacks
end

function comboBox_base:GetDropdownObject(comboBoxContainer, depth)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 93, tos(getControlName(comboBoxContainer)), tos(depth)) end
	self.m_nextFree = depth + 1
	return dropdownClass:New(self, comboBoxContainer, depth)
end

-- Create the m_dropdownObject on initialize.
function comboBox_base:GetOptions()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 94) end
	return self.options or {}
end

-- Get or create submenu
function comboBox_base:GetSubmenu()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 95) end
	if not self.m_submenu then
		self.m_submenu = submenuClass:New(self, self.m_container, self:GetOptions(), self.m_nextFree)
	end
	return self.m_submenu
end

function comboBox_base:HiddenForReasons(button)
	local owningWindow, mocCtrl, comboBox, mocEntry = getMouseOver_HiddenFor_Info()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 96, tos(button)) end
--d("comboBox_base:HiddenForReasons - button: " .. tos(button))

	--[[
	LSM_debug = LSM_debug or {}
	LSM_debug.HiddenForReasons = LSM_debug.HiddenForReasons or {}
	local tabEntryName = getControlName(mocCtrl) or "n/a"
	LSM_debug.HiddenForReasons[tabEntryName] = {
		self = self,
		owningWindow = owningWindow,
		mocCtrl = mocCtrl,
		mocEntry = mocEntry,
		comboBox = comboBox,
		m_dropdownObject = self.m_dropdownObject,
		selfOwner = self.owner,
		dropdownObjectOwner = self.m_dropdownObject.owner,
	}
	]]

	local dropdownObject = self.m_dropdownObject
	local isContextMenuVisible = g_contextMenu:IsDropdownVisible()
	local isOwnedByComboBox = dropdownObject:IsOwnedByComboBox(comboBox)
	local wasTextSearchContextMenuEntryClicked = dropdownObject:WasTextSearchContextMenuEntryClicked()
	if isContextMenuVisible and not wasTextSearchContextMenuEntryClicked then
		wasTextSearchContextMenuEntryClicked = g_contextMenu.m_dropdownObject:WasTextSearchContextMenuEntryClicked()
	end
--d(">ownedByCBox: " .. tos(isOwnedByComboBox) .. ", isCtxtMenVis: " .. tos(isContextMenuVisible) ..", isCtxMen: " ..tos(self.isContextMenu) .. "; cntxTxtSearchEntryClicked: " .. tos(wasTextSearchContextMenuEntryClicked))

	if isOwnedByComboBox == true or wasTextSearchContextMenuEntryClicked == true then
--d(">>isEmpty: " ..tos(ZO_IsTableEmpty(mocEntry)) .. ", enabled: " ..tos(mocEntry.enabled) .. ", mouseEnabled: " .. tos(mocEntry.IsMouseEnabled and mocEntry:IsMouseEnabled()))
		if ZO_IsTableEmpty(mocEntry) or (mocEntry.enabled and mocEntry.enabled ~= false) or (mocEntry.IsMouseEnabled and mocEntry:IsMouseEnabled()) then
			if button == MOUSE_BUTTON_INDEX_LEFT then
				--do not close or keep open based on clicked entry but do checks in contextMenuClass:GetHiddenForReasons instead
				if isContextMenuVisible == true then
					--Is the actual mocCtrl's owner the contextMenu? Or did we click some other non-context menu entry/control?
					if owningWindow ~= g_contextMenu.m_container then
--d(">>>returing nothing because is or isOpened -> contextMenu. Going to GetHiddenForReasons")
						if wasTextSearchContextMenuEntryClicked == true then
--d(">>>returing false cuz textSearchEntry was selected")
							return false
						end
					else
--d("<<returning contextmenu via mouseLeft -> closeOnSelect: " ..tos(mocCtrl.closeOnSelect))
						return mocCtrl.closeOnSelect and not self.m_enableMultiSelect
					end
				else
--d("<<returning via mouseLeft -> closeOnSelect: " ..tos(mocCtrl.closeOnSelect))
					--Clicked entry should close after selection?
					return mocCtrl.closeOnSelect and not self.m_enableMultiSelect
				end
			elseif button == MOUSE_BUTTON_INDEX_RIGHT then
				-- bypass right-clicks on the entries. Context menus will be checked and opened at the OnMouseUp handler
				-->See local function onMouseUp called via runHandler -> from dropdownClass:OnEntrySelected
				return false
			end
		end
	end

	local hiddenForReasons
	if not self.GetHiddenForReasons then
--d("<<self:GetHiddenForReasons is NIL! isContextMenuVisible: " .. tos(isContextMenuVisible))
--LSM_debug.HiddenForReasons[tabEntryName]._GetHiddenForReasonsMissing = true
		return false
	end
	hiddenForReasons = self:GetHiddenForReasons(button) --call e.g. contextMenuClass:GetHiddenForReasons()

	if hiddenForReasons == nil then return false end
	return hiddenForReasons(owningWindow, mocCtrl, comboBox, mocEntry)
end

--Get the highlight XML template for the entry
function comboBox_base:GetHighlightTemplate(control)
	local highlightTemplate = ((control ~= nil and control.m_data ~= nil and control.m_data.m_highlightTemplate) or self.m_highlightTemplate) or nil
	return highlightTemplate
end


--Get the current row's highlight template based on the options, and differ between normal entry type's highlights,
-- entry type opening a submenu and having it's own callback (templateSubMenuWithCallback) highlights, contextMenu opening
-- control (templateContextMenuOpeningControl) highlights
function comboBox_base:GetHighlightTemplateData(control, m_data, isSubMenu, isContextMenu)
	local entryType = control.typeId

	--Get the highlight template based on the entryType
	if entryType == nil then return	end

	local appliedHighlightTemplate = self:GetHighlightTemplate(control)
	local appliedHighlightTemplateCopy = appliedHighlightTemplate
	local highlightTemplateData = ((self.XMLRowHighlightTemplates[entryType] ~= nil and ZO_ShallowTableCopy(self.XMLRowHighlightTemplates[entryType])) or (appliedHighlightTemplateCopy)) or ZO_ShallowTableCopy(defaultHighlightTemplateData) --loose the reference so we can overwrite values below, without changing originals
	highlightTemplateData.overwriteHighlightTemplate = highlightTemplateData.overwriteHighlightTemplate or false

	local options = self:GetOptions()
	local data = getControlData(control)

	--Check if the original data passed in got a m_highlightTemplate, m_highlightColor etc. which should always be used
	-->Original data was copied to data._LSM.OriginalData.data via function updateDataValues in addItembase
	if data then
		local origData = data[LSM_DATA_SUBTABLE] and data[LSM_DATA_SUBTABLE][LSM_DATA_SUBTABLE_ORIGINAL_DATA] and data[LSM_DATA_SUBTABLE][LSM_DATA_SUBTABLE_ORIGINAL_DATA].data
		if origData then
			if origData.m_highlightTemplate or origData.m_highlightColor then
				local origHighlightTemplateData = {}
				origHighlightTemplateData.template = 	origData.m_highlightTemplate
				origHighlightTemplateData.color = 		origData.m_highlightColor or defaultHighlightColor

				origHighlightTemplateData.overwriteHighlightTemplate = true

				return origHighlightTemplateData
			end
		end
	end

	if isSubMenu and control.closeOnSelect then
		if options and not options.useDefaultHighlightForSubmenuWithCallback then
			--Color the highlight light row green if the submenu has a callback (entry opening a submenu can be clicked to select it)
			--but keep the color of the text as defined in options (self.XMLRowHighlightTemplates[entryType].color)
			--Was a custom template provided in "templateSubMenuWithCallback" for that case, then use it. Else use default template (green)
			highlightTemplateData.template = ((highlightTemplateData.templateSubMenuWithCallback ~= nil and highlightTemplateData.templateSubMenuWithCallback) or (appliedHighlightTemplateCopy)) or ZO_ShallowTableCopy(defaultHighlightTemplateDataEntryHavingSubMenuWithCallback).template
		end
	else
		local isContextMenuAndHighlightContextMenuOpeningControl = (options ~= nil and options.highlightContextMenuOpeningControl == true) or self.highlightContextMenuOpeningControl == true
		if isContextMenuAndHighlightContextMenuOpeningControl then
			local comboBox = control.m_owner
			local gotRightCLickCallback = ((data ~= nil and comboBox ~= nil and (data.contextMenuCallback ~= nil or data.rightClickCallback ~= nil)) and true) or false
			local isOwnedByContextMenuComboBox = g_contextMenu.m_dropdownObject:IsOwnedByComboBox(comboBox)

			if gotRightCLickCallback and not isOwnedByContextMenuComboBox then

				--highlightContextMenuOpeningControl support -> highlightTemplateData.templateContextMenuOpeningControl
				highlightTemplateData.template = ((highlightTemplateData.templateContextMenuOpeningControl ~= nil and highlightTemplateData.templateContextMenuOpeningControl) or (appliedHighlightTemplateCopy)) or ZO_ShallowTableCopy(defaultHighlightTemplateDataEntryContextMenuOpeningControl).template
				highlightTemplateData.overwriteHighlightTemplate = true
			end
		end
	end
	return highlightTemplateData
end

--Write the highlight template to the control.m_data.m_highlightTemplate (ZO_ComboBox default variable for that), based
--on the XMLRowHighlightTemplates passed in via the options (or using default values)
function comboBox_base:UpdateHighlightTemplate(control, data, isSubMenu, isContextMenu)
	isContextMenu = isContextMenu or self.isContextMenu
	local highlightTemplateData = self:GetHighlightTemplateData(control, data, isSubMenu, isContextMenu)
	local highlightTemplate = (highlightTemplateData ~= nil and highlightTemplateData.template) or nil
--d(debugPrefix .. "UpdateHighlightTemplate - highlightTemplateData: " .. tos(highlightTemplateData) .. ", override: " .. tos(highlightTemplateData and highlightTemplateData.overwriteHighlightTemplate) .. "; current: " .. tos(control.m_data.m_highlightTemplate))
	if control.m_data then
		if highlightTemplateData == nil then
			control.m_data.m_highlightTemplate = nil --defaultHighlightTemplateData.template ???
			control.m_data.m_highlightColor = nil    --defaultHighlightTemplateData.color ???
		elseif highlightTemplateData.overwriteHighlightTemplate == true or not control.m_data.m_highlightTemplate then
			control.m_data.m_highlightTemplate = highlightTemplate
			control.m_data.m_highlightColor = highlightTemplateData.color
		end
	end
end

-- Changed to hide tooltip and, if available, it's submenu
-- We hide the tooltip here so it is hidden if the dropdown is hidden OnGlobalMouseUp
function comboBox_base:HideDropdown()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 97) end
	-- Recursive through all open submenus and close them starting from last.

	if self.m_submenu and self.m_submenu:IsDropdownVisible() then
		-- Close all open descendants.
		self.m_submenu:HideDropdown()
	end

--	lib.openMenu = nil

	if self.highlightedControl then
		unhighlightControl(self, false, nil, nil)
	end

	-- Close self
	zo_comboBox_base_hideDropdown(self)
	return true
end

-- These are part of the m_dropdownObject but, since we now use them from the comboBox,
-- they are added here to reference the ones in the m_dropdownObject.
function comboBox_base:IsMouseOverControl()
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 98, tos(self.m_dropdownObject:IsMouseOverControl())) end
	return self.m_dropdownObject:IsMouseOverControl()
end

--Narrate (screen UI reader): Read out text based on the narration event fired
function comboBox_base:Narrate(eventName, ctrl, data, hasSubmenu, anchorPoint)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 99, tos(eventName), tos(getControlName(ctrl)), tos(hasSubmenu), tos(anchorPoint)) end
	local narrateData = self.narrateData
	if eventName == nil or isAccessibilityUIReaderEnabled() == false or narrateData == nil then return end
	local narrateCallbackFuncForEvent = narrateData[eventName]
	if narrateCallbackFuncForEvent == nil or type(narrateCallbackFuncForEvent) ~= "function" then return end
	local selfVar = self

	--The function parameters signature for the different narration callbacks
	local eventCallbackFunctionsSignatures = {
		["OnMenuShow"]			= function() return selfVar, ctrl end,
		["OnMenuHide"]			= function() return selfVar, ctrl end,
		["OnSubMenuShow"]		= function() return selfVar, ctrl, anchorPoint end,
		["OnSubMenuHide"]		= function() return selfVar, ctrl end,
		["OnEntrySelected"]		= function() return selfVar, ctrl, data, hasSubmenu end,
		["OnEntryMouseExit"]	= function() return selfVar, ctrl, data, hasSubmenu end,
		["OnEntryMouseEnter"]	= function() return selfVar, ctrl, data, hasSubmenu end,
		["OnCheckboxUpdated"]	= function() return selfVar, ctrl, data end,
		["OnRadioButtonUpdated"]= function() return selfVar, ctrl, data end,
		["OnComboBoxMouseExit"] = function() return selfVar, ctrl end,
		["OnComboBoxMouseEnter"]= function() return selfVar, ctrl end,
	}
	--Create a table with the callback functions parameters
	if eventCallbackFunctionsSignatures[eventName] == nil then return end
	local callbackParams = { eventCallbackFunctionsSignatures[eventName]() }
	--Pass in the callback params to the narrateFunction
	local narrateText, stopCurrent = narrateCallbackFuncForEvent(unpack(callbackParams))

	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 100, tos(narrateText), tos(stopCurrent)) end
	--Didn't the addon take care of the narration itsself? So this library here should narrate the text returned
	if type(narrateText) == "string" then
		local narrateFuncOfLibrary = narrationEventToLibraryNarrateFunction[eventName]
		if narrateFuncOfLibrary == nil then return end
		narrateFuncOfLibrary(narrateText, stopCurrent)
	end
end

--Should exist on PTS already
--[[
if comboBox_base.IsEnabled == nil then
	function comboBox_base:IsEnabled()
		return self.m_openDropdown:GetState() ~= BSTATE_DISABLED
	end
end
]]

function comboBox_base:RefreshSortedItems(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 101, tos(getControlName(parentControl))) end
	ZO_ClearNumericallyIndexedTable(self.m_sortedItems)

	local entries = self:GetEntries()
	-- Ignore nil entries
	if entries ~= nil then
		-- replace empty entries with noEntriesSubmenu item
		if ZO_IsTableEmpty(entries) then
			noEntriesSubmenu.m_owner = self
			noEntriesSubmenu.m_parentControl = parentControl
			self:AddItem(noEntriesSubmenu, ZO_COMBOBOX_SUPPRESS_UPDATE)
		else
			for _, item in ipairs(entries) do
				item.m_owner = self
				item.m_parentControl = parentControl
				-- update strings by functions will be done in AddItem
				self:AddItem(item, ZO_COMBOBOX_SUPPRESS_UPDATE)
			end

			self:UpdateItems()
		end
	end
end

function comboBox_base:RunItemCallback(item, ignoreCallback, ...)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 102) end

	if item.callback and not ignoreCallback then
		return item.callback(self, item.name, item, ...)
	end
	return false
end

function comboBox_base:SetOptions(options)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 103) end
	self.options = options
end

function comboBox_base:Show()
	self.m_dropdownObject:Show(self, self.m_sortedItems, self.containerMinWidth, self.m_containerWidth, self.m_height, self:GetSpacing())
	self.m_dropdownObject.control:BringWindowToTop()
end

-- used for onMouseEnter[submenu] and onMouseUp[contextMenu]
function comboBox_base:ShowDropdownOnMouseAction(parentControl)
	--d( debugPrefix .. 'comboBox_base:ShowDropdownOnMouseAction')
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 105, tos(getControlName(parentControl))) end
	if self:IsDropdownVisible() then
		-- If submenu was currently opened, close it so it can reset.
		self:HideDropdown()
	end

	if self:IsEnabled() then
		self.m_dropdownObject:SetHidden(false)
		self:AddMenuItems(parentControl)

		self:ShowDropdown()
		self:SetVisible(true)
	else
		--If we get here, that means the dropdown was disabled after the request to show it was made, so just cancel showing entirely
		self.m_container:UnregisterForEvent(EVENT_GLOBAL_MOUSE_UP)
	end
end

function comboBox_base:ShowSubmenu(parentControl)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 106, tos(getControlName(parentControl))) end
	-- We don't want a submenu to open under the context menu or it's submenus.
	--TODO: see if this acts negatively in contextmenu submenus
	hideContextMenu()

	local submenu = self:GetSubmenu()
	submenu:ShowDropdownOnMouseAction(parentControl)
end

function comboBox_base:ShouldHideDropdown()
	if self.m_submenu and self.m_submenu:ShouldHideDropdown() then
		self.m_submenu:HideDropdown()
	end
	return self:IsDropdownVisible() and not self:IsMouseOverControl()
end

function comboBox_base:UpdateItems()
	zo_comboBox_base_updateItems(self)

	--[[
	20240615 Should not be needed anymore as this is already done at runPostItemSetupFunction[LSM_ENTRY_TYPE_SUBMENU] in add_itemBase
	for _, itemEntry in pairs(self.m_sortedItems) do
		if itemEntry.hasSubmenu then
			recursiveOverEntries(itemEntry, preUpdateSubItems)
		end
	end
	]]
end

function comboBox_base:UpdateHeight(control)
--d(debugPrefix .. "comboBox_base:UpdateHeight - control: " .. getControlName(control))
	local maxHeightInTotal = 0

	local spacing = self.m_spacing or 0
	--Maximum height explicitly set by options?
	local maxDropdownHeight = self:GetMaxDropdownHeight()

	--The height of each row
	local baseEntryHeight = self.baseEntryHeight
	local maxRows
	local maxHeightByEntries

	--Is the dropdown using a header control? then calculate it's size too
	local headerHeight = 0
	if control ~= nil then
		headerHeight = self:GetBaseHeight(control)
--d(">>header BaseHeight: " ..tos(headerHeight))
	end

	--Calculate the maximum height now:
	---If set as explicit maximum value: Use that
	if maxDropdownHeight ~= nil then
		maxHeightInTotal = maxDropdownHeight
	else
		--Calculate maximum visible height based on visibleRowsDrodpdown or visibleRowsSubmenu
		maxRows = self:GetMaxRows()
		-- Add spacing to each row then subtract spacing for last row
		maxHeightByEntries = ((baseEntryHeight + spacing) * maxRows) - spacing + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 2)

--d(">>maxRows: " ..tos(maxRows) .. ", maxHeightByEntries: " ..tos(maxHeightByEntries))
		--Add the header's height first, then add the rows' calculated needed total height
		maxHeightInTotal = maxHeightByEntries
	end


	--The minimum dropdown height is either the height of 1 base row + the y padding (4x because 2 at anchors of ZO_ScrollList and 1x at top of list and 1x at bottom),
	--> and if a header exists + header height
	local minHeight = (baseEntryHeight * 1) + (ZO_SCROLLABLE_COMBO_BOX_LIST_PADDING_Y * 4) + headerHeight

	--Add a possible header's height to the total maximum height
	maxHeightInTotal = maxHeightInTotal + headerHeight

	--Check if the determined dropdown height is > than the screen's height: An min to that screen height then
	local screensMaxDropdownHeight = getScreensMaxDropdownHeight()
	--maxHeightInTotal = (maxHeightInTotal > screensMaxDropdownHeight and screensMaxDropdownHeight) or maxHeightInTotal
	--If the height of the total height is below minHeight then increase it to be at least that high
	maxHeightInTotal = zo_clamp(maxHeightInTotal, minHeight, screensMaxDropdownHeight)
--d(">>>headerHeight: " ..tos(headerHeight) .. ", maxHeightInTotal: " ..tos(maxHeightInTotal))


	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 107, tos(getControlName(control)), tos(maxHeightInTotal), tos(maxDropdownHeight), tos(maxHeightByEntries),  tos(baseEntryHeight), tos(maxRows), tos(spacing), tos(headerHeight)) end

	--This will set self.m_height for later usage in self:Show() -> as the dropdown is shown
	self:SetHeight(maxHeightInTotal)

	--Why calling hte Show function here? To apply updated options?
	-->The show function is called twice then if a new submenu is opened e.g....
	if self:IsDropdownVisible() then
	--	self.m_dropdownObject:Show(self, self.m_sortedItems, self.containerMinWidth, self.m_containerWidth, self.m_height, self:GetSpacing())
		self:Show()
	end
end

function comboBox_base:SetMinMaxWidth(minWidth, maxWidth)
	self.containerMinWidth = minWidth 	--LSM added variable
	self.m_containerWidth = maxWidth 	--ZO_ComboBox variable
end

function comboBox_base:UpdateWidth(control)
	--d(debugPrefix .. "comboBox_base:UpdateWidth - control: " .. getControlName(control))
	--Is the dropdown using a header control? then calculate it's size too
	local minWidth = self:GetBaseWidth(control)

	--Calculate the maximum width now: Maximum width explicitly set by options? Else use container's width (should be same as the dropdown opening ctrl).
	-->Will be overwritten at Show function IF no maxWidth is set and any entry in the list is wider (text width) than the container width
	local maxDropdownWidth = self:GetMaxDropdownWidth()
	local maxWidthInTotal = maxDropdownWidth or self.m_containerWidth
	if maxWidthInTotal <= 0 then maxWidthInTotal = MIN_WIDTH_WITHOUT_SEARCH_HEADER end

	--Calculate end width
	local newWidth = maxWidthInTotal
	--Was option.maxDropdownWidth provided?
	if maxDropdownWidth ~= nil then
		newWidth = zo_clamp(maxWidthInTotal, minWidth, maxDropdownWidth)
		--d(">1, newWidth: " ..tos(newWidth))
	else
		--No options passed in a maxDropdownWidth
		if minWidth < maxWidthInTotal  then
			newWidth = zo_clamp(maxWidthInTotal, minWidth, maxWidthInTotal)
			--d(">2, newWidth: " ..tos(newWidth))
		else
			newWidth = minWidth
			--d(">3, newWidth: " ..tos(newWidth))
		end
	end

	--d(debugPrefix.."UpdateWidth - minWidth: " .. tos(minWidth).. ", maxWidthInTotal: " ..tos(maxWidthInTotal) ..", maxDropdownWidth: " .. tos(maxDropdownWidth) .. ", newWidth: " .. tos(newWidth))


	--[181] = "comboBox_base:UpdateWidth - control: %q, maxWidth: %s, maxDropdownWidth: %s, headerWidth: %s",
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 181, tos(getControlName(control)), tos(newWidth), tos(maxWidthInTotal), tos(maxDropdownWidth), tos(minWidth)) end

	--This will set self.m_containerWidth = newWidth, and self.containerMinWidth = minWidth, for later usage in self:Show() -> as the dropdown is shown
	self:SetMinMaxWidth(minWidth, newWidth)
end

do -- Row setup functions
	local function applyEntryFont(control, font, color, horizontalAlignment)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 108, tos(getControlName(control)), tos(font), tos(color), tos(horizontalAlignment)) end
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
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 109, tos(getControlName(control)), tos(list)) end
		control.m_iconContainer = control.m_iconContainer or control:GetNamedChild("IconContainer")
		local iconContainer = control.m_iconContainer
		control.m_icon = control.m_icon or iconContainer:GetNamedChild("Icon")
		updateIcons(control, data)
	end

	local function addArrow(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 110, tos(getControlName(control)), tos(list)) end
		control.m_arrow = control:GetNamedChild("Arrow")
		data.hasSubmenu = true
	end

	local function addDivider(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 111, tos(getControlName(control)), tos(list)) end
		control.m_divider = control:GetNamedChild("Divider")
	end

	local function addLabel(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 112, tos(getControlName(control)), tos(list)) end
		control.m_label = control.m_label or control:GetNamedChild("Label")

		control.m_label:SetText(data.label or data.name) -- Use alternative passed in label string, or the default mandatory name string
	end

	local function addButton(comboBox, control, data, toggleFunction)
		local entryType = control.typeId
		if entryType == nil then return end
		local childName = entryTypeToButtonChildName[entryType]
		if childName == nil then return end

		local buttonControl = control.m_button or control:GetNamedChild(childName)
		control.m_button = buttonControl
		buttonControl.entryType = entryType

		local isEnabled = data.enabled ~= false
		buttonControl:SetMouseEnabled(isEnabled)
		buttonControl.enabled = isEnabled

		ZO_CheckButton_SetToggleFunction(buttonControl, toggleFunction)
		--	ZO_CheckButton_SetEnableState(buttonControl, data.enabled ~= false)

		local buttonGroup
		local groupIndex = getValueOrCallback(data.buttonGroup, data)

		if type(groupIndex) == "number" then
			-- Prepare buttonGroup
			comboBox.m_buttonGroup = comboBox.m_buttonGroup or {}
			comboBox.m_buttonGroup[entryType] = comboBox.m_buttonGroup[entryType] or {}
			comboBox.m_buttonGroup[entryType][groupIndex] = comboBox.m_buttonGroup[entryType][groupIndex] or buttonGroupClass:New()
			buttonGroup = comboBox.m_buttonGroup[entryType][groupIndex]

			--d(debugPrefix .. "setupFunc RB - addButton, groupIndex: " ..tos(groupIndex))

			if type(data.buttonGroupOnSelectionChangedCallback) == "function" then
				buttonGroup:SetSelectionChangedCallback(data.buttonGroupOnSelectionChangedCallback)
			end

			if type(data.buttonGroupOnStateChangedCallback) == "function" then
				buttonGroup:SetStateChangedCallback(data.buttonGroupOnStateChangedCallback)
			end

			-- Add buttonControl to buttonGroup
			buttonControl.m_buttonGroup = buttonGroup
			buttonControl.m_buttonGroupIndex = groupIndex
			buttonGroup:Add(buttonControl, entryType)

			local IGNORECALLBACK = true
			buttonGroup:SetButtonState(buttonControl, data.clicked, isEnabled, IGNORECALLBACK)
			--	buttonGroup:SetButtonIsValidOption(buttonControl, isEnabled)

			if entryType == LSM_ENTRY_TYPE_CHECKBOX and data.rightClickCallback == nil and data.contextMenuCallback == nil then
				data.rightClickCallback = buttonGroupDefaultContextMenu
			end
		end
		return buttonControl, buttonGroup
	end

	function comboBox_base:SetupEntryBase(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 104, tos(getControlName(control))) end
		self.m_dropdownObject:SetupEntryBase(control, data, list) --Calls ZO_ComboBoxDropdown_Keyboard:SetupEntryBase where m_selectionHighlight is used for multiSelect

		control.callback = data.callback
		control.contextMenuCallback = data.contextMenuCallback
		control.closeOnSelect = (control.selectable and type(data.callback) == 'function') or false

		control:SetMouseEnabled(data.enabled ~= false)
	end

	function comboBox_base:SetupEntryDivider(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 113, tos(getControlName(control)), tos(list)) end
		control.typeId = LSM_ENTRY_TYPE_DIVIDER
		addDivider(control, data, list)
		self:SetupEntryBase(control, data, list)
		control.isDivider = true
	end

	function comboBox_base:SetupEntryLabelBase(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 114, tos(getControlName(control)), tos(list)) end
		local font = getValueOrCallback(data.font, data)
		font = font or self:GetDropdownFont()

		local color = getValueOrCallback(data.color, data)
		color = color or self:GetItemNormalColor(data)

		local horizontalAlignment = getValueOrCallback(data.horizontalAlignment, data)
		horizontalAlignment = horizontalAlignment or self.horizontalAlignment

		applyEntryFont(control, font, color, horizontalAlignment)
		self:SetupEntryBase(control, data, list, realEntryType)
	end

	function comboBox_base:SetupEntryLabel(control, data, list, realEntryType)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 115, tos(getControlName(control)), tos(list)) end
		control.typeId = LSM_ENTRY_TYPE_NORMAL
		addIcon(control, data, list)
		addLabel(control, data, list)
		self:SetupEntryLabelBase(control, data, list, realEntryType)

		if realEntryType == LSM_ENTRY_TYPE_NORMAL then
			--Update the control.m_highlightTemplate
			self:UpdateHighlightTemplate(control, data, nil, nil)
		end
	end

	function comboBox_base:SetupEntrySubmenu(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 116, tos(getControlName(control)), tos(list)) end
		self:SetupEntryLabel(control, data, list)
		addArrow(control, data, list)
		control.typeId = LSM_ENTRY_TYPE_SUBMENU

--d(debugPrefix .. "submenu setup: - name: " .. tos(getValueOrCallback(data.label or data.name, data)) ..", closeOnSelect: " ..tos(control.closeOnSelect) .. "; m_highlightTemplate: " ..tos(data.m_highlightTemplate) )

		self:UpdateHighlightTemplate(control, data, true, nil)
	end

	function comboBox_base:SetupEntryHeader(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 117, tos(getControlName(control)), tos(list)) end
		addDivider(control, data, list)
		self:SetupEntryLabel(control, data, list)
		control.isHeader = true
		control.typeId = LSM_ENTRY_TYPE_HEADER
	end


	function comboBox_base:SetupEntryRadioButton(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 118, tos(getControlName(control)), tos(list)) end

		local selfVar = self
		local function toggleFunction(button, checked)
--d(debugPrefix .. "RB toggleFunc - button: " ..tos(getControlName(button)) .. ", checked: " .. tos(checked))
			local rowData = getControlData(button:GetParent())
			rowData.checked = checked

			if checked then
				if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 119, tos(getControlName(control)), tos(checked), tos(list)) end
				selfVar:RunItemCallback(data, data.ignoreCallback, checked)

				lib:FireCallbacks('RadioButtonUpdated', control, data, checked)
				selfVar:Narrate("OnRadioButtonUpdated", button, data, nil)
				if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 120, tos(getControlName(button)), tos(checked)) end
			end
		end
		self:SetupEntryLabel(control, data, list)
		control.isRadioButton = true
		control.typeId = LSM_ENTRY_TYPE_RADIOBUTTON

		self:UpdateHighlightTemplate(control, data, nil, nil)

		local radioButton, radioButtonGroup = addButton(self, control, data, toggleFunction)
		if radioButtonGroup then
			if data.checked == true then
				-- Only 1 can be set as "checked" here.
				local IGNORECALLBACK = true
				radioButtonGroup:SetClickedButton(radioButton, IGNORECALLBACK)
			end
		end
	end

	function comboBox_base:SetupEntryCheckbox(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 121, tos(getControlName(control)), tos(list)) end

		local selfVar = self
		local function toggleFunction(checkbox, checked)
			local checkedData = getControlData(checkbox:GetParent())

			checkedData.checked = checked

			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 122, tos(getControlName(control)), tos(checked), tos(list)) end
			--Changing the params similar to the normal entry's itemSelectionHelper signature: function(comboBox, itemName, item, checked, data)
			selfVar:RunItemCallback(data, data.ignoreCallback, checked)

			lib:FireCallbacks('CheckboxUpdated', control, data, checked)
			selfVar:Narrate("OnCheckboxUpdated", checkbox, data, nil)
			if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_DEBUG_CALLBACK, 123, tos(getControlName(checkbox)), tos(checked)) end

			hideTooltip(control)
		end

		self:SetupEntryLabel(control, data, list)
		control.isCheckbox = true
		control.typeId = LSM_ENTRY_TYPE_CHECKBOX

		self:UpdateHighlightTemplate(control, data, nil, nil)

		local checkbox = addButton(self, control, data, toggleFunction)
		ZO_CheckButton_SetCheckState(checkbox, getValueOrCallback(data.checked, data))
	end

	function comboBox_base:SetupEntryButton(control, data, list)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 124, tos(getControlName(control)), tos(list)) end

		-- The row it's self is treated as a button, no child button
		control.isButton = true
		control.typeId = LSM_ENTRY_TYPE_BUTTON
		addIcon(control, data, list)
		addLabel(control, data, list)

		local font = getValueOrCallback(data.font, data)
		font = font or self:GetDropdownFont()

		local color = getValueOrCallback(data.color, data)
		color = color or self:GetItemNormalColor(data)

		local horizontalAlignment = getValueOrCallback(data.horizontalAlignment, data)
		horizontalAlignment = horizontalAlignment or TEXT_ALIGN_CENTER

		applyEntryFont(control, font, color, horizontalAlignment)
		self:SetupEntryBase(control, data, list)

		control:SetEnabled(data.enabled)

		if data.buttonTemplate then
			ApplyTemplateToControl(control, data.buttonTemplate)
		end

		self:UpdateHighlightTemplate(control, data, nil, nil)
	end
end

--[[
	if comboBox.m_buttonGroup then
		comboBox.m_buttonGroup:Clear()
	end

function comboBox_base:HighlightLabel(labelControl, data)
	if labelControl.SetColor then
		local color = self:GetItemHighlightColor(data)
		labelControl:SetColor(color:UnpackRGBA())
	end
end

function ZO_ComboBox:UnhighlightLabel(labelControl, data)
	if labelControl.SetColor then
		local color = self:GetItemNormalColor(data)
		labelControl:SetColor(color:UnpackRGBA())
	end
end
]]

-- Blank
function comboBox_base:GetMaxRows()
	-- Overwrite at subclasses
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 125) end
end

function comboBox_base:IsFilterEnabled()
	-- Overwrite at subclasses
end

function comboBox_base:GetFilterFunction()
	local options = self:GetOptions()
	local filterFunction = (options and options.customFilterFunc) or defaultFilterFunc
	return filterFunction
end

function comboBox_base:UpdateOptions(options, onInit, isContextMenu, initExistingComboBox)
	-- Overwrite at subclasses
end

function comboBox_base:SetFilterString()
	-- Overwrite at subclasses
end

function comboBox_base:SetupDropdownHeader()
	-- Overwrite at subclasses
end

function comboBox_base:UpdateDropdownHeader()
	-- Overwrite at subclasses
end