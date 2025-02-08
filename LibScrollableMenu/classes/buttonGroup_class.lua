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

local constants = lib.contants
local entryTypeConstants = constants.entryTypes
local comboBoxConstants = constants.comboBox
local comboBoxMappingConstants = comboBoxConstants.mapping
local searchFilterConstants = constants.searchFilter

local comboBoxDefaults = comboBoxConstants.defaults
local noEntriesResults = searchFilterConstants.noEntriesResults
local noEntriesSubmenuResults = searchFilterConstants.noEntriesSubmenuResults
local filteredEntryTypes = searchFilterConstants.filteredEntryTypes
local filterNamesExempts = searchFilterConstants.filterNamesExempts



local libUtil = lib.Util
local getControlName = libUtil.getControlName
local getValueOrCallback = libUtil.getValueOrCallback
local checkIfContextMenuOpenedButOtherControlWasClicked = libUtil.checkIfContextMenuOpenedButOtherControlWasClicked
local showTooltip = libUtil.showTooltip
local hideTooltip = libUtil.hideTooltip

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------
-- LSM buttonGroup class definition
--------------------------------------------------------------------
local buttonGroupClass = ZO_RadioButtonGroup:Subclass()
classes.buttonGroupClass = buttonGroupClass


--------------------------------------------------------------------
-- LSM buttonGroup class
--  (radio) buttons in a group will change their checked state to false if another button in the group was clicked
--------------------------------------------------------------------
function buttonGroupClass:Add(button, entryType)
	if button then
		--local buttonGroupIndex = button.m_buttonGroupIndex
--d("Add - groupIndex: " ..tos(buttonGroupIndex) .. ", button: " .. tos(button:GetName()))
		if self.m_buttons[button] == nil then
			local selfVar = self
--d(">>adding new button to group now...")

			-- Remember the original handler so that its call can be forced.
			local originalHandler = button:GetHandler("OnClicked")
			self.m_buttons[button] = { originalHandler = originalHandler, isValidOption = true, entryType = entryType } -- newly added buttons always start as valid options for now.

			--d( debugPrefix..'isRadioButton ' .. tos(isRadioButton))
			if entryType == entryTypeConstants.LSM_ENTRY_TYPE_RADIOBUTTON then
				-- This throws away return values from the original function, which is most likely ok in the case of a click handler.
				local newHandler = function(control, buttonId, ignoreCallback)
--d( debugPrefix.. 'buttonGroup -> OnClicked handler. Calling HandleClick')
					--2024-08-15 Add checkIfContextMenuWasOpened here at direct radioButton click as OnClick handler does not work here!
					if checkIfContextMenuOpenedButOtherControlWasClicked(control, control:GetParent().m_owner, buttonId) == true then return end
					selfVar:HandleClick(control, buttonId, ignoreCallback)
				end

				--d( debugPrefix..'originalHandler' .. tos(originalHandler))
				button:SetHandler("OnClicked", newHandler)

				if button.label then
					button.label:SetColor(self.labelColorEnabled:UnpackRGB())
				end
			end
			return true
		end
	end
end

function buttonGroupClass:Remove(button)
	local buttonData = self.m_buttons[button]
	if buttonData then
--d("Removed  - button: " .. tos(button:GetName()))
		--self:SetButtonState(button, nil, buttonData.isValidOption)
		button:SetHandler("OnClicked", buttonData.originalHandler)
		if self.m_clickedButton == button then
			self.m_clickedButton = nil
		end
		self.m_buttons[button] = nil
	end
end

function buttonGroupClass:SetButtonState(button, clickedButton, enabled, ignoreCallback)
--d("SetButtonState  - button: " .. tos(button:GetName()) .. ", clickedButton: " .. tos(clickedButton ~= nil and clickedButton) .. ", enabled: " .. tos(enabled) .. "; ignoreCallback: " ..tos(ignoreCallback))
	if(enabled) then
		local checked = true
		if(button == clickedButton) then
			button:SetState(BSTATE_PRESSED, true)
		else
			button:SetState(BSTATE_NORMAL, false)
			checked = false
		end

		if button.label then
			button.label:SetColor(self.labelColorEnabled:UnpackRGB())
		end
		-- move here and always update
--d(">checked: " .. tos(checked))

		if (button.toggleFunction ~= nil) and not ignoreCallback then -- and checked then
			button:toggleFunction(checked)
		end
	else
        if(button == clickedButton) then
            button:SetState(BSTATE_DISABLED_PRESSED, true)
        else
            button:SetState(BSTATE_DISABLED, true)
        end
        if button.label then
            button.label:SetColor(self.labelColorDisabled:UnpackRGB())
        end
    end
end

function buttonGroupClass:HandleClick(control, buttonId, ignoreCallback)
--d("HandleClick - button: " .. getControlName(control))
	if not self.m_enabled or self.m_clickedButton == control then
		return
	end

	-- Can't click disabled buttons
	local controlData = self.m_buttons[control]
	if controlData and not controlData.isValidOption then
		return
	end

	if self.customClickHandler and self.customClickHandler(control, buttonId, ignoreCallback) then
		return
	end

	-- For now only the LMB will be allowed to click radio buttons.
	if buttonId == MOUSE_BUTTON_INDEX_LEFT then
		-- Set all buttons in the group to unpressed, and unlocked.
		-- If the button is disabled externally (maybe it isn't a valid option at this time)
		-- then set it to unpressed, but disabled.
--d(">>> for k, v in pairs(self.buttons) -> SetButtonState")
		for k, v in pairs(self.m_buttons) do
		--	self:SetButtonState(k, nil, v.isValidOption)
			self:SetButtonState(k, control, v.isValidOption, ignoreCallback)
		end

		-- Set the clicked button to pressed and lock it down (so that it stays pressed.)
--		control:SetState(BSTATE_PRESSED, true)
		local previousControl = self.m_clickedButton
		self.m_clickedButton = control

		if self.onSelectionChangedCallback and not ignoreCallback then
			self:onSelectionChangedCallback(control, previousControl)
			hideTooltip(control)
		end
	end

	if controlData.originalHandler then
		controlData.originalHandler(control, buttonId)
	end
end

function buttonGroupClass:SetChecked(control, checked, ignoreCallback)
--d("SetChecked - control: " .. getControlName(control) .. ", checked: " ..tos(checked) .. ", ignoreCallback: " .. tos(ignoreCallback))
	local previousControl = self.m_clickedButton
	-- This must be made nil as running this virtually resets the button group.
	-- Not dong so will break readial buttons, if used on them.
	-- Lets say one inverts radio buttons. The previously set one will remain so, tho it's no inverted, it will not be able to be selected again until another is selected first.
	-- if not self.m_enabled or self.m_clickedButton == control then
	self.m_clickedButton = nil

	local buttonId = MOUSE_BUTTON_INDEX_LEFT
	local updatedButtons = {}

	local valueChanged = false
	for button, controlData in pairs(self.m_buttons) do
--d(">button: " ..getControlName(button) .. ", enabled: " ..tos(button.enabled))
		if button.enabled then
			if ZO_CheckButton_IsChecked(button) ~= checked then
				valueChanged = true
				-- button.checked Used to pass checked to handler
				button.checked = checked
				table.insert(updatedButtons, button)
				if controlData.originalHandler then
--d(">>calling originalHandler")
					local skipHiddenForReasonsCheck = true
					controlData.originalHandler(button, buttonId, ignoreCallback, skipHiddenForReasonsCheck) --As a normal OnClicked handler is called here: prevent doing nothing-> So we need to skip the HiddenForReasons check at the checkboxes!
				end
			end
		end
	end

	if not ignoreCallback and not ZO_IsTableEmpty(updatedButtons) and self.onStateChangedCallback then
		self:onStateChangedCallback(control, updatedButtons)
	end

	return valueChanged
end

function buttonGroupClass:SetInverse(control, ignoreCallback)
	return self:SetChecked(control, nil, ignoreCallback)
end

function buttonGroupClass:SetStateChangedCallback(callback)
    self.onStateChangedCallback = callback
end