local lib = LibScrollableMenu
if not lib then return end

local MAJOR = lib.name

--------------------------------------------------------------------
-- Libraries
--------------------------------------------------------------------
local LDL = LibDebugLogger


--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
--ZOs local speed-up/reference variables
local sfor = string.format


------------------------------------------------------------------------------------------------------------------------
--Logging and debugging
local libDebug = lib.Debug

local logger
local debugPrefix = lib.Debug.prefix

--DebugLog types
local LSM_LOGTYPE_DEBUG = 1
local LSM_LOGTYPE_VERBOSE = 2
local LSM_LOGTYPE_DEBUG_CALLBACK = 3
local LSM_LOGTYPE_INFO = 10
local LSM_LOGTYPE_ERROR = 99
libDebug.LSM_LOGTYPE_DEBUG = LSM_LOGTYPE_DEBUG
libDebug.LSM_LOGTYPE_VERBOSE = LSM_LOGTYPE_VERBOSE
libDebug.LSM_LOGTYPE_DEBUG_CALLBACK = LSM_LOGTYPE_DEBUG_CALLBACK
libDebug.LSM_LOGTYPE_INFO = LSM_LOGTYPE_INFO
libDebug.LSM_LOGTYPE_ERROR = LSM_LOGTYPE_ERROR

--DebugLog type to name mapping
local loggerTypeToName = {
	[LSM_LOGTYPE_DEBUG] = 			" -DEBUG- ",
	[LSM_LOGTYPE_VERBOSE] = 		" -VERBOSE- ",
	[LSM_LOGTYPE_DEBUG_CALLBACK] = 	" -CALLBACK- ",
	[LSM_LOGTYPE_INFO] = 			" -INFO- ",
	[LSM_LOGTYPE_ERROR] = 			" -ERROR- ",
}


--------------------------------------------------------------------
-- Debug logging
--------------------------------------------------------------------

--The debug messages patterns with their uniqueId. The function dLog only passes in the textId and params to make it
--more performant
local debugLogMessagePatterns = {
	[1]  = "highlightControl - highlightTemplate:  %s",
	[2]  = "getDropdownTemplate - templateName:  %s",
	[3]  = "getScrollContentsTemplate - barHidden:  %s",
	[4]  = "REGISTERING throttledCall - callback: %s, delay: %s, name: %s",
	[5]  = "DELAYED throttledCall -> CALLING callback now: %s, name: %s",
	[6]  = "getValueOrCallback - arg:  %s",
	[7]  = "ClearTimeout",
	[8]  = "setTimeout",
	[9]  = "setTimeout -> delayed by:  %s",
	[10] = "mixinTableAndSkipExisting - callbackFunc: %s",
	[11] = "defaultRecursiveCallback",
	[12] = "addEntryLSM - data: %s, subTB: %s, key: %q, valueOrCallbackFunc: %s",
	[13] = "updateDataByFunctions - data: %s",
	[14] = "updateDataValues - saving callback func. for key: %s",
	[15] = "Run func. data._LSM.funcData[%q] - value: %s",
	[16] = "updateDataValues - key: %s, setting nilToTrue: %s",
	[17] = "getIsNew",
	[18] = "verifyLabelString - data.name: %s",
	[19] = "recursiveOverEntries - #submenu: %s, result: %s",
	[20] = "silenceComboBoxClickedSound - doSilence: %s, entryType: %s",
	[21] = "getOptionsForDropdown",
	[22] = "playSelectedSoundCheck - entryType: %s",
	[23] = "doMapEntries",
	[24] = "mapEntries",
	[25] = "updateIcon - Adding \'new icon\'",
	[26] = "updateIcon - iconIdx %s, visible: %s, texture: %s, tint: %s, width: %s, height: %s, narration: %s",
	[27] = "updateIcons - numIcons %s",
	[28] = "getControlData - name:  %s",
	[29] = "checkIfContextMenuOpenedButOtherControlWasClicked - cbox == ctxtMenu? %s; cntxt dropdownVis? %s",
	[30] = "areAnyEntriesNew",
	[31] = "updateSubmenuNewStatus",
	[32] = "clearNewStatus",
	[33] = "FireCallbacks: NewStatusUpdated - control:  %s",
	[34] = "setItemEntryCustomTemplate - name: %q, entryType: %s",
	[35] = "addItem_Base - itemEntry:  %s",
	[36] = "resetCustomTooltipFuncVars",
	[37] = "hideTooltip - custom onHide func:  %s",
	[38] = "getTooltipAnchor - control: %s, tooltipText: %s, hasSubmenu: %s",
	[39] = "showTooltip - control: %s, tooltipText: %s, hasSubmenu: %s, customTooltipFunc: %s",
	[40] = "isAccessibilitySettingEnabled - settingId: %s, isSettingEnabled: %s",
	[41] = "isAccessibilityModeEnabled",
	[42] = "isAccessibilityUIReaderEnabled",
	[43] = "addNewUINarrationText - newText: %s, stopCurrent: %s",
	[44] = "onUpdateDoNarrate - updName: %s, delay: %s",
	[45] = "onUpdateDoNarrate - Delayed call: updName: %s",
	[46] = "onMouseEnterOrExitNarrate - narrateText: %s, stopCurrent: %s",
	[47] = "onSelectedNarrate - narrateText: %s, stopCurrent: %s",
	[48] = "onMouseMenuOpenOrCloseNarrate - narrateText: %s, stopCurrent: %s",
	[49] = "onMouseEnter - control: %s, hasSubmenu: %s",
	[50] = "FireCallbacks: EntryOnMouseEnter - control: %s, hasSubmenu: %s",
	[51] = "onMouseExit - control: %s, hasSubmenu: %s",
	[52] = "FireCallbacks: EntryOnMouseExit - control: %s, hasSubmenu: %s",
	[53] = "runHandler - control: %s, handlerTable: %s, typeId: %s",
	[54] = "createScrollableComboBoxEntry - index: %s, entryType: %s",
	[55] = "dropdownClass:Initialize - parent: %s, comboBoxContainer: %s, depth: %s",
	[56] = "dropdownClass:Narrate - eventName: %s, ctrl: %s, hasSubmenu: %s, anchorPoint: %s",
	[57] = "dropdownClass:AddCustomEntryTemplate - entryTemplate: %s, entryHeight: %s, setupFunction: %s, widthPadding: %s",
	[58] = "dropdownClass:AnchorToControl - point: %s, relativeTo: %s, relativePoint: %s offsetX: %s, offsetY: %s",
	[59] = "dropdownClass:AnchorToComboBox - comboBox container: %s",
	[60] = "dropdownClass:AnchorToMouse - point: %s, relativeTo: %s, relativePoint: %s offsetX: %s, offsetY: %s",
	[61] = "dropdownClass:GetSubmenu - submenu:  %s",
	[62] = "dropdownClass:IsDropdownVisible:  %s",
	[63] = "dropdownClass:IsEnteringSubmenu -> Yes",
	[64] = "dropdownClass:IsEnteringSubmenu -> No",
	[65] = "dropdownClass:IsItemSelected ->  %s",
	[66] = "dropdownClass:IsItemSelected -> No",
	[67] = "dropdownClass:IsMouseOverOpeningControl -> No",
	[68] = "dropdownClass:OnMouseEnterEntry - control:  %s",
	[69] = "dropdownClass:OnMouseExitEntry - control:  %s",
	[70] = "dropdownClass:OnMouseExitTimeout - control:  %s",
	[71] = "dropdownClass:OnEntryMouseUp - control: %s, button: %s, upInside: %s",
	[72] = "dropdownClass:OnEntryMouseUp - contextMenuCallback!",
	[73] = "dropdownClass:SelectItemByIndex - index: %s, ignoreCallback: %s",
	[74] = "dropdownClass:RunItemCallback - item: %s, ignoreCallback: %s",
	[75] = "dropdownClass:Show - comboBox: %s, minWidth: %s, maxWidth: %s, maxHeight: %s, spacing: %s",
	[76] = ">totalDropDownWidth: %s, allItemsHeight: %s, desiredHeight: %s",
	[77] = "dropdownClass:UpdateHeight",
	[78] = "dropdownClass:OnShow",
	[79] = "dropdownClass:OnHide",
	[80] = "dropdownClass:ShowSubmenu - control:  %s",
	[81] = "dropdownClass:ShowTooltip - control: %s, hasSubmenu: %s",
	[82] = "dropdownClass:HideDropdown",
	[83] = "dropdownClass:HideSubmenu",
	[84] = "comboBox_base:Initialize - parent: %s, comboBoxContainer: %s, depth: %s",
	[85] = "comboBox_base:AddItem - itemEntry: %s, updateOptions: %s, templates: %s",
	[86] = "comboBox_base:AddCustomEntryTemplate - entryTemplate: %s, entryHeight: %s, setupFunction: %s, widthPadding: %s",
	[87] = "getTemplateData - entryType: %s, template: %s",
	[88] = "comboBox_base:AddCustomEntryTemplates - options: %s",
	[89] = ">NORMAL_ENTRY_HEIGHT %s, DIVIDER_ENTRY_HEIGHT: %s, HEADER_ENTRY_HEIGHT: %s, CHECKBOX_ENTRY_HEIGHT: %s, BUTTON_ENTRY_HEIGHT: %s, RADIOBUTTON_ENTRY_HEIGHT: %s",
	[90] = "comboBox_base:OnGlobalMouseUp-button: %s, suppressNextMouseUp: %s",
	[91] = "comboBox_base:GetBaseHeight - control: %s, gotHeader: %s, height: %s",
	[92] = "comboBox_base:GetMaxDropdownHeight - maxDropdownHeight: %s",
	[93] = "comboBox_base:GetDropdownObject - comboBoxContainer: %s, depth: %s",
	[94] = "comboBox_base:GetOptions",
	[95] = "comboBox_base:GetSubmenu",
	[96] = "comboBox_base:HiddenForReasons - button:  %s",
	[97] = "comboBox_base:HideDropdown",
	[98] = "comboBox_base:IsMouseOverControl:  %s",
	[99] = "comboBox_base:Narrate - eventName: %s, ctrl: %s, hasSubmenu: %s, anchorPoint: %s",
	[100] = ">narrateText: %s, stopCurrent: %s",
	[101] = "comboBox_base:RefreshSortedItems - parentControl: %s",
	[102] = "comboBox_base:FireEntrtCallback",
	[103] = "comboBox_base:SetOptions",
	[104] = "comboBox_base:SetupEntryBase - control:  %s",
	[105] = "comboBox_base:ShowDropdownOnMouseAction - parentControl: %s  %s",
	[106] = "comboBox_base:ShowSubmenu - parentControl: %s  %s",
	[107] = "comboBox_base:UpdateHeight - control: %q, maxHeight: %s, maxDropdownHeight: %s, maxHeightByEntries: %s, baseEntryHeight: %s, maxRows: %s, spacing: %s, headerHeight: %s",
	[108] = "applyEntryFont - control: %s, font: %s, color: %s, horizontalAlignment: %s",
	[109] = "addIcon - control: %s, list: %s,",
	[110] = "addArrow - control: %s, list: %s,",
	[111] = "addDivider - control: %s, list: %s,",
	[112] = "addLabel - control: %s, list: %s,",
	[113] = "comboBox_base:SetupEntryDivider - control: %s, list: %s,",
	[114] = "comboBox_base:SetupEntryLabelBase - control: %s, list: %s,",
	[115] = "comboBox_base:SetupEntryLabel - control: %s, list: %s,",
	[116] = "comboBox_base:SetupEntrySubmenu - control: %s, list: %s",
	[117] = "comboBox_base:SetupEntryHeader - control: %s, list: %s",
	[118] = "comboBox_base:SetupEntryRadioButton - control: %s, list: %s",
	[119] = "comboBox_base:SetupEntryRadioButton - calling radiobutton callback, control: %s, checked: %s, list: %s",
	[120] = "FireCallbacks: RadioButtonUpdated - control: %q, checked: %s",
	[121] = "comboBox_base:SetupEntryCheckbox - control: %s, list: %s",
	[122] = "comboBox_base:SetupEntryCheckbox - calling checkbox callback, control: %s, checked: %s, list: %s",
	[123] = "FireCallbacks: CheckboxUpdated - control: %q, checked: %s",
	[124] = "comboBox_base:SetupEntryButton - control: %s, list: %s",
	[125] = "comboBox_base:GetMaxRows",
	[126] = "comboBoxClass:Initialize - parent: %s, comboBoxContainer: %s, depth: %s",
	[127] = "comboBoxClass:AddMenuItems",
	[128] = "comboBoxClass:GetMaxRows:  %s",
	[129] = "comboBoxClass:GetMenuPrefix: Menu",
	[130] = "comboBoxClass:GetHiddenForReasons - button:  %s",
	[131] = "comboBoxClass:HideDropdown",
	[132] = "comboBoxClass:HideOnMouseEnter",
	[133] = "comboBoxClass:HideOnMouseExit",
	[134] = "comboBoxClass:ResetToDefaults",
	[135] = "comboBoxClass:SetOption . key: %s, ZO_ComboBox[key]: %s",
	[136] = "comboBoxClass:UpdateOptions - options: %s, onInit: %s, optionsChanged: %s",
	[137] = "comboBoxClass:UpdateMetatable - parent: %s, comboBoxContainer: %s, options: %s",
	[138] = "FireCallbacks: OnDropdownMenuAdded - control: %s, options: %s",
	[139] = "comboBoxClass:UpdateDropdownHeader - options: %s, toggleButton: %s",
	[140] = "submenuClass:Initialize - parent: %s, comboBoxContainer: %s, depth: %s",
	[141] = "submenuClass:UpdateOptions - options: %s, onInit: %s",
	[142] = "submenuClass:AddMenuItems - parentControl: %s",
	[143] = "submenuClass:GetMaxRows:  %s",
	[144] = "submenuClass:GetMenuPrefix: SubMenu",
	[145] = "submenuClass:HideDropdownInternal",
	[146] = ">submenuClass:HideDropdownInternal - onHideDropdownCallback called",
	[147] = "submenuClass:HideOnMouseExit - mocCtrl: %s",
	[148] = "submenuClass:GetHiddenForReasons - button:  %s",
	[149] = "contextMenuClass:Initialize - comboBoxContainer: %s",
	[150] = "contextMenuClass:AddContextMenuItem - itemEntry: %s",
	[151] = "contextMenuClass:AddMenuItems",
	[152] = "contextMenuClass:ClearItems",
	[153] = "contextMenuClass:GetMenuPrefix: Contextmenu",
	[154] = "contextMenuClass:GetHiddenForReasons - button:  %s",
	[155] = "contextMenuClass:HideDropdown",
	[156] = "contextMenuClass:ShowSubmenu - parentControl: %s",
	[157] = "contextMenuClass:ShowContextMenu - parentControl: %s",
	[158] = "contextMenuClass:SetContextMenuOptions - options: %s",
	[159] = "GetPersistentMenus: %s",
	[160] = "SetPersistentMenus - persistent: %s",
	[161] = "AddCustomScrollableComboBoxDropdownMenu - parent: %s, comboBoxContainer: %s, options: %s",
	[162] = "AddCustomScrollableMenuEntry - text: %s, callback: %s, entryType: %s, entries: %s",
	[163] = "AddCustomScrollableSubMenuEntry - text: %s, entries: %s",
	[164] = "AddCustomScrollableMenuDivider",
	[165] = "AddCustomScrollableMenuHeader-text: %s",
	[166] = "AddCustomScrollableMenuCheckbox-text: %s, checked: %s",
	[167] = "SetCustomScrollableMenuOptions - comboBoxContainer: %s, options: %s",
	[168] = "ClearCustomScrollableMenu",
	[169] = "AddCustomScrollableMenuEntries - contextMenuEntries: %s",
	[170] = "AddCustomScrollableMenu - entries: %s, options: %s",
	[171] = "ShowCustomScrollableMenu - controlToAnchorTo: %s, options: %s",
	[172] = "FireCallbacks: ContextMenu - OnDropdownMenuAdded - control: %s, options: %s",
	[173] = "m_button OnMouseUp!",
	[174] = "~~~~~ onAddonLoaded ~~~~~",
	[175] = "ZO_Menu -> ShowMenu. Items#: %s, menuType:  %s",
	[176] = "Debugging turned %s",
	[177] = "Verbose debugging turned %s / Debugging: %s",
	[178] = "dropdownClass:UpdateWidth",
	[179] = "comboBox_base:GetMaxDropdownWidth - maxDropdownWidth: %s",
	[180] = "comboBox_base:GetBaseWidth - control: %s, gotHeader: %s, width: %s",
	[181] = "comboBox_base:UpdateWidth - control: %q, newWidth: %s, maxWidth: %s, maxDropdownWidth: %s, minWidth: %s",
}


------------------------------------------------------------------------------------------------------------------------
-- Logger creation
------------------------------------------------------------------------------------------------------------------------
local function loadLogger()
	--LibDebugLogger
	LDL = LDL or LibDebugLogger
	if not lib.logger and LDL then
		logger = LDL(MAJOR)
		logger:SetEnabled(true)
		logger:Debug("Library loaded")
		logger.verbose = logger:Create("Verbose")
		logger.verbose:SetEnabled(false)

		logger.callbacksFired = logger:Create("Callbacks")

		lib.Debug.logger = logger
	end
end
libDebug.LoadLogger = loadLogger


--Early try to load libs and to create logger (done again in EVENT_ADD_ON_LOADED)
loadLogger()


------------------------------------------------------------------------------------------------------------------------
-- Logging functions
------------------------------------------------------------------------------------------------------------------------
--Debug log function
local function dlog(debugType, textId, ...)
	if not lib.doDebug or not textId then return end
	debugType = debugType or LSM_LOGTYPE_DEBUG

	local debugText = debugLogMessagePatterns[textId]
	if ... ~= nil and select(1, {...}) ~= nil then
		debugText = sfor(debugText, ...)
	end
	if debugText == nil or debugText == "" then return end

	--LibDebugLogger
	if LDL then
		if debugType == LSM_LOGTYPE_DEBUG_CALLBACK then
			logger.callbacksFired:Debug(debugText)

		elseif debugType == LSM_LOGTYPE_DEBUG then
			logger:Debug(debugText)

		elseif debugType == LSM_LOGTYPE_VERBOSE then
			if lib.doVerboseDebug then
				local loggerVerbose = logger.verbose
				if loggerVerbose and loggerVerbose.isEnabled == true then
					loggerVerbose:Verbose(debugText)
				end
			end

		elseif debugType == LSM_LOGTYPE_INFO then
			logger:Info(debugText)

		elseif debugType == LSM_LOGTYPE_ERROR then
			logger:Error(debugText)
		end

	--Normal debugging via chat d() messages
	else
		--No verbose debuglos in normal chat!
		if debugType ~= LSM_LOGTYPE_VERBOSE then
			local debugTypePrefix = loggerTypeToName[debugType] or ""
			d(debugPrefix .. debugTypePrefix .. debugText)
		end
	end
end
libDebug.DebugLog = dlog