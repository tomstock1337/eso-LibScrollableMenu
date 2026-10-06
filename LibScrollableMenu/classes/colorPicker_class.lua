-- -----------------------------------------------------------------------------
-- live color picker (cloned ZOS keyboard widgets) - idea Dakjaniels (addon: HUDitor Tools)
-- -----------------------------------------------------------------------------

local lib = LibScrollableMenu
if not lib then return end

--local MAJOR = lib.name


--------------------------------------------------------------------
-- For debugging and logging
--------------------------------------------------------------------
--Logging and debugging
--local libDebug = lib.Debug
--local debugPrefix = libDebug.prefix

--local dlog = libDebug.DebugLog

--------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------
local tos = tostring
local funcType = "function"

local CM = CALLBACK_MANAGER

--------------------------------------------------------------------
--Library classes
--------------------------------------------------------------------
local classes = lib.classes


--------------------------------------------------------------------
--LSM library locals
--------------------------------------------------------------------
local constants = lib.constants
local entryTypeConstants = constants.entryTypes


local libUtil = lib.Util
local getValueOrCallback = libUtil.getValueOrCallback
local getControlName = libUtil.getControlName
local checkIfContextMenuOpenedButOtherControlWasClicked = libUtil.checkIfContextMenuOpenedButOtherControlWasClicked
local hideTooltip = libUtil.hideTooltip

--------------------------------------------------------------------

local colorPickerClass = ZO_InitializingCallbackObject:Subclass() --#2026_21
classes.colorPickerClass = colorPickerClass


local PANEL_TEMPLATE = "LibScrollableMenu_ColorPickerPanel"
local DEFAULT_ANCHOR_OFFSET_X = 100
local DEFAULT_ANCHOR_OFFSET_Y = 100
local INTERACTABLE_LEVEL = ZO_HUD_EDITOR_KEYBOARD_INFO_BOX_INTERACTABLE_ELEMENT_LEVEL

local sharedPicker

--- INITIALIZE ---------------------------------------------------------------------------------------------------------
function colorPickerClass:Initialize(control)
    self.control = control
    self.suppressApply = false
    self.isUpdatingColors = false

    self.lastComboBoxOpenedFrom = nil   --the combobox of the LSM entry that opened the colorpicker -> so we can re-register the global mouse up event for the still opened LSM
    self.LSMEntryControlOpenedFrom = nil          --the LSM entry control that the color picker was opened for
    self.controlToColorize = nil        --used to store the control reference that should get the color applied directly
    self.previewControlToColorize = nil --used to store the control reference to any small preview control that shows the color (e.g. at LSM entry)
    self.resetToColors = nil            --used to store the default current colors of the control to colorize (for the reset function)
    self.OnColorUpdateFunc = nil        --used to store the updateFunction(r, g, b, a) which is called as the color is selected (the function is provided in the entry's colorPickerData and used to e.g. update SavedVariables instead of changing the color directly at any control)
    self.colorPickerData = nil          --used to store the colorPickerData table of the entry currently processed
    self.defaultColor = nil             --used to store the default color for the color picker
    self.OnColorGetFunc = nil           --used to store the funciton the returns the r, g, b, a values for the color (from e.g. SavedVariables) -> only if controlToColorize is not specified!

    control:SetDrawTier(DT_HIGH)
    control:SetDrawLevel(10)
    control:SetMouseEnabled(true)
    control:SetMovable(true)
    control:SetClampedToScreen(true)
    control:SetHidden(true)

    local titleLabel = control:GetNamedChild("Title")
    titleLabel:SetText(GetString(SI_WINDOW_TITLE_COLOR_PICKER))
    self.titleCtrl = titleLabel                                                                            --#2026_22

    local closeButton = control:GetNamedChild("Close")
    closeButton:SetDrawLevel(INTERACTABLE_LEVEL)
    closeButton:SetHandler("OnClicked", function ()
        self:Hide()
    end)

    local resetButton = control:GetNamedChild("Reset")
    resetButton:SetText(GetString(SI_GROUP_FINDER_FILTERS_RESET)) --"Reset"
    resetButton:SetHandler("OnClicked", function ()
        self:Reset()
    end)

    control:SetHandler("OnMoveStop", function ()
        self:SaveAnchor()
    end)

    self:InitializePickerWidgets()
    self:ApplySavedAnchor()
end

function colorPickerClass:InitializePickerWidgets()
    local content = self.control:GetNamedChild("Content")
    self.content = content

    self.colorSelect = content:GetNamedChild("ColorSelect")
    self.colorSelectThumb = self.colorSelect:GetNamedChild("Thumb")
    self.colorSelect:SetColorWheelThumbTextureControl(self.colorSelectThumb)
    self.colorSelect:SetHandler("OnColorSelected", function (_, r, g, b)
        self:OnColorSet(r, g, b)
    end)

    self.valueSlider = content:GetNamedChild("Value")
    self.valueSlider:GetThumbTextureControl():SetDrawLayer(3)
    self.valueTexture = self.valueSlider:GetNamedChild("Texture")
    self.valueSlider:SetHandler("OnValueChanged", function (_, value)
        self:OnValueSet(1 - value)
    end)

    self.alphaLabel = content:GetNamedChild("AlphaLabel")
    self.alphaSlider = content:GetNamedChild("Alpha")
    local alphaThumbTexture = self.alphaSlider:GetThumbTextureControl()
    alphaThumbTexture:SetTextureRotation(ZO_HALF_PI)
    alphaThumbTexture:SetDrawLayer(3)
    self.alphaTexture = self.alphaSlider:GetNamedChild("Texture")
    self.alphaSlider:SetHandler("OnValueChanged", function (_, value)
        self:OnAlphaSet(value)
    end)

    local previewControl = content:GetNamedChild("Preview")
    self.previewInitialTexture = previewControl:GetNamedChild("TextureBottom")
    self.previewCurrentTexture = previewControl:GetNamedChild("TextureTop")

    local function SetColorFromSpinner(r, g, b, a)
        if not self.isUpdatingColors then
            self:SetColor(r, g, b, a)
        end
    end

    local spinners = content:GetNamedChild("Spinners")
    self.redSpinner = ZO_Spinner:New(spinners:GetNamedChild("Red"), 0, 255)
    self.redSpinner:RegisterCallback("OnValueChanged", function (value)
        SetColorFromSpinner(value / 255, self.greenSpinner:GetValue() / 255, self.blueSpinner:GetValue() / 255, self.alphaSpinner:GetValue() / 255)
    end)
    self.redSpinner:SetNormalColor(ZO_ColorDef:New(1, .2, .2, 1))

    self.greenSpinner = ZO_Spinner:New(spinners:GetNamedChild("Green"), 0, 255)
    self.greenSpinner:RegisterCallback("OnValueChanged", function (value)
        SetColorFromSpinner(self.redSpinner:GetValue() / 255, value / 255, self.blueSpinner:GetValue() / 255, self.alphaSpinner:GetValue() / 255)
    end)
    self.greenSpinner:SetNormalColor(ZO_ColorDef:New(.2, 1, .2, 1))

    self.blueSpinner = ZO_Spinner:New(spinners:GetNamedChild("Blue"), 0, 255)
    self.blueSpinner:RegisterCallback("OnValueChanged", function (value)
        SetColorFromSpinner(self.redSpinner:GetValue() / 255, self.greenSpinner:GetValue() / 255, value / 255, self.alphaSpinner:GetValue() / 255)
    end)
    self.blueSpinner:SetNormalColor(ZO_ColorDef:New(.2, .2, 1, 1))

    self.alphaSpinner = ZO_Spinner:New(spinners:GetNamedChild("Alpha"), 0, 255)
    self.alphaSpinner:RegisterCallback("OnValueChanged", function (value)
        SetColorFromSpinner(self.redSpinner:GetValue() / 255, self.greenSpinner:GetValue() / 255, self.blueSpinner:GetValue() / 255, value / 255)
    end)
end


--- SETTER -------------------------------------------------------------------------------------------------------------
function colorPickerClass:SetTitle()                                                                       --#2026_22
    self.titleCtrl:SetText(self:GetTitleString())
end

function colorPickerClass:SetColorPickerData(colorPickerData)
    self.colorPickerData = colorPickerData
end

function colorPickerClass:SetControlToColorize(controlOrFunc)
    self.controlToColorize = controlOrFunc
end

function colorPickerClass:SetPreviewControlToColorize(controlOrFunc)
    self.previewControlToColorize = controlOrFunc
end

function colorPickerClass:SetDefaultColor(colorOrFunc)                                                     --#2026_22
    self.defaultColor = colorOrFunc
end

function colorPickerClass:SetOnColorUpdateFunc(func) --func uses the signature updateFunction(r, g, b, a, colorPickerData)
    if type(func) == funcType then
        self.OnColorUpdateFunc = func
    else
        self.OnColorUpdateFunc = nil
    end
end

function colorPickerClass:SetOnColorGetFunc(func)  --func uses the signature updateFunction(colorPickerData) and returns r, g, b, a --#2026_22
    if type(func) == funcType then
        self.OnColorGetFunc = func
    else
        self.OnColorGetFunc = nil
    end
end


function colorPickerClass:SetResetToColors()
    self.resetToColors = self:GetCurrentControlColors(true)
end

function colorPickerClass:SetColor(r, g, b, a)
    self.colorSelect:SetColorAsRGB(r, g, b)
    self.valueSlider:SetValue(1 - self.colorSelect:GetValue())
    self.alphaSlider:SetValue(a or 1)
    self:UpdateColors(r, g, b, a or 1)
end

function colorPickerClass:UpdateColors(r, g, b, a)
    self.isUpdatingColors = true

    local fullR, fullG, fullB = self.colorSelect:GetFullValuedColorAsRGB()
    self.valueTexture:SetGradientColors(ORIENTATION_VERTICAL, 0, 0, 0, 1, fullR, fullG, fullB, 1)
    self.previewCurrentTexture:SetColor(r, g, b, a)
    self.alphaTexture:SetGradientColors(ORIENTATION_HORIZONTAL, r, g, b, 0, r, g, b, .85)

    self.redSpinner:SetValue(r * 255)
    self.greenSpinner:SetValue(g * 255)
    self.blueSpinner:SetValue(b * 255)
    self.alphaSpinner:SetValue(a * 255)

    self.isUpdatingColors = false

    if not self.suppressApply then
        self:ApplyLiveColor(r, g, b, a)

        self:FireCallbacks("LibScrollableMenu_ColorPicker_OnColorSelected", self, self:GetComboBox(), self:GetLSMEntryControl(), self:GetColorPickerData(), { r=r, g=g, b=b, a=a })
    end
end

function colorPickerClass:Reset()
    local resetToColorTable = self:GetResetToColors()
    if resetToColorTable == nil then return end
    self:ApplyLiveColor(resetToColorTable.r, resetToColorTable.g, resetToColorTable.b, resetToColorTable.a)
    self:LoadColors()

    self:FireCallbacks("LibScrollableMenu_ColorPicker_OnColorReset", self, self:GetComboBox(), self:GetLSMEntryControl(), self:GetColorPickerData(), resetToColorTable)
end


--- GETTER -------------------------------------------------------------------------------------------------------------
function colorPickerClass:GetComboBox()
    return self.lastComboBoxOpenedFrom
end

function colorPickerClass:GetLSMEntryControl()
    return self.LSMEntryControlOpenedFrom
end

function colorPickerClass:GetTitleString()                                                                  --#2026_22
    local colorPickerTitleStr = ""
    local colorPickerData = self:GetColorPickerData()
    local colorPickerCustomTitle = getValueOrCallback(colorPickerData.title, colorPickerData)
    if colorPickerCustomTitle ~= nil and colorPickerCustomTitle ~= "" then
        --Use custom title
        colorPickerTitleStr = colorPickerCustomTitle
    else
        colorPickerTitleStr = "|cC0C0C0" .. GetString(SI_WINDOW_TITLE_COLOR_PICKER) .. "|r" .. ((colorPickerData.LSMEntryLabel ~= nil and ": " .. colorPickerData.LSMEntryLabel) or "")
    end
    return colorPickerTitleStr
end

function colorPickerClass:GetColorPickerData()
    return self.colorPickerData
end

function colorPickerClass:GetControlToColorize()
    return getValueOrCallback(self.controlToColorize, self:GetColorPickerData())
end

function colorPickerClass:GetPreviewControlToColorize()
    return getValueOrCallback(self.previewControlToColorize, self:GetComboBox(), self:GetLSMEntryControl(), self:GetColorPickerData())
end

function colorPickerClass:GetDefaultColor()                                         --#2026_22
    return getValueOrCallback(self.defaultColor, self:GetColorPickerData())
end

function colorPickerClass:GetResetToColors()
    return self.resetToColors
end

function colorPickerClass:GetOnColorUpdateFunc()
    return self.OnColorUpdateFunc
end

function colorPickerClass:GetOnColorGetFunc()                                       --#2026_22
    return self.OnColorGetFunc
end


--Get the controlToColorize's current color, or if that is missing use the OnColorGetFunc(colorPickerData) to get the
--r, g, b, a values for the color picker UI. If a defaultColor was specified save that to be applied by the "reset" button
local noColorSpecifiedTable = { r = 1, g = 1, b = 1, a = 1 }
function colorPickerClass:GetCurrentControlColors(isResetColorSave)
    local defaultColor
    if isResetColorSave == true then
        defaultColor = self:GetDefaultColor()                                                         --#2026_22
        --Are we saving the resetToColor on showing of the color picker? If we got any defaultColor defined, use that one as resetToColor!
        if not ZO_IsTableEmpty(defaultColor) then
            return defaultColor
        end
    end

    local currentColors

    --Do we have a control to read the current color from? Use that
    local controlToColorize = self:GetControlToColorize()
    if not controlToColorize or controlToColorize.GetColor == nil then
        --#2026_22 Added colorPickerData.OnColorGetFunc = function() return r, g, b, a end Return the color values e.g. from SavedVariables, but only if colorPickerData.controlToColorize wasn't provided!
        --Do we have any OnColorGetFunc callback defined? Use that to get the color values
        local OnColorGetFunc = self:GetOnColorGetFunc()
        if type(OnColorGetFunc) == funcType then
            currentColors = {}
            currentColors.r, currentColors.g, currentColors.b, currentColors.a = OnColorGetFunc(self:GetComboBox(), self:GetColorPickerData())
            return currentColors
        end
    else
        --Use control
        currentColors = { controlToColorize:GetColor() }
        return { r = currentColors[1], g = currentColors[2], b = currentColors[3], a = currentColors[4] }
    end

    --No control and no OnColorGetFunc? Return the defaultColor if specified, or a dummy black value
    defaultColor = defaultColor or self:GetDefaultColor()                                                     --#2026_22
    if not ZO_IsTableEmpty(defaultColor) then
        return defaultColor
    end
    return noColorSpecifiedTable
end

function colorPickerClass:LoadColors()
    local colorTable = self:GetCurrentControlColors()
    if colorTable == nil then return end

    local r, g, b, a = colorTable.r, colorTable.g, colorTable.b, colorTable.a
    self.suppressApply = true
    self:SetColor(r, g, b, a)
    self.previewInitialTexture:SetColor(r, g, b, a)
    self:ApplyLiveColorToPreviewControl(r, g, b, a)
    self.suppressApply = false
end


--- Event handlers -----------------------------------------------------------------------------------------------------
function colorPickerClass:OnColorSet(r, g, b)
    self:UpdateColors(r, g, b, self.alphaSlider:GetValue())
end

function colorPickerClass:OnValueSet(value)
    self.colorSelect:SetValue(value)
end

function colorPickerClass:OnAlphaSet(value)
    local r, g, b = self.colorSelect:GetColorAsRGB()
    self:UpdateColors(r, g, b, value)
end


--- Utility ------------------------------------------------------------------------------------------------------------
function colorPickerClass:AnchorToMouse()
    local mocCtrl = moc()
    if mocCtrl == nil then return end
    local control = self.control
    local screenWidth = GuiRoot:GetWidth()
    local screenHeight = GuiRoot:GetHeight()
    local mocLeft = mocCtrl:GetLeft()
    local mocTop = mocCtrl:GetTop()
    local controlWidth = control:GetWidth()
    local controlHeight = control:GetHeight()
    local xOffset = mocLeft - ( controlWidth + 20 )
    if xOffset <= 0 then
        xOffset = mocLeft + mocCtrl:GetWidth() + 30 --+20 would anchor it directly to the side of the scrollbar (if any)
        if xOffset >= screenWidth then return end
    end
    local yOffset = mocTop
    if ( screenHeight - yOffset ) <= controlHeight then
        yOffset = screenHeight - controlHeight - 20
    end

    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, xOffset, yOffset)
end

function colorPickerClass:ApplyLiveColorToPreviewControl(r, g, b, a)
    local previewControlToColorize = self:GetPreviewControlToColorize()
    if previewControlToColorize and previewControlToColorize.SetColor then
        previewControlToColorize:SetColor(r, g, b, a)
    end
end


--- Callback - Set color if value changed/clicked ----------------------------------------------------------------------
--Set's the color to the controlToColorize, the previewColorCOntrol and/or calls the callback function OnColorUpdateFunc
function colorPickerClass:ApplyLiveColor(r, g, b, a)
    local controlToColorize = self:GetControlToColorize()
    if controlToColorize and controlToColorize.SetColor then
        controlToColorize:SetColor(r, g, b, a)
    end

    self:ApplyLiveColorToPreviewControl(r, g, b, a)

    local OnColorUpdateFunc = self:GetOnColorUpdateFunc()
    if OnColorUpdateFunc ~= nil then
        OnColorUpdateFunc(self:GetComboBox(), r, g, b, a, self:GetColorPickerData())                              --#2026_22
    end
end


--- Anchoring & Hidden state -------------------------------------------------------------------------------------------
function colorPickerClass:ApplySavedAnchor()
    --d("ApplySavedAnchor")
    local colorPickerSV = lib.SV.colorPicker
    local control = self.control
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, colorPickerSV.OffsetX or DEFAULT_ANCHOR_OFFSET_X, colorPickerSV.OffsetY or DEFAULT_ANCHOR_OFFSET_Y)
end

function colorPickerClass:SaveAnchor()
    --d("SaveAnchor")
    local control = self.control
    local colorPickerSV = lib.SV.colorPicker
    colorPickerSV.OffsetX = control:GetLeft()
    colorPickerSV.OffsetY = control:GetTop()
end

function colorPickerClass:SetHidden(hidden)
    local control = self.control
    local parent = control:GetParent() --should be LibScrollableMenu_ColorPicker_TLC
    local mouseEnabled = not hidden
    parent:SetHidden(hidden)
    control:SetHidden(hidden)
    control:SetMovable(mouseEnabled)
    control:SetMouseEnabled(mouseEnabled)
    if mouseEnabled then
        --Get, build and set the title of the color picker UI
        self:SetTitle()                                                                                     --#2026_22
        --Set the default / currentColor now
        self:LoadColors()
        parent:BringWindowToTop()
    end
end

--- UI -----------------------------------------------------------------------------------------------------------------
function colorPickerClass:Show(comboBox, LSMEntryControl, colorPickerData)        --#2026_22
    if colorPickerData == nil then return end
    self.lastComboBoxOpenedFrom = comboBox                                                                  --#2026_22
    self.LSMEntryControlOpenedFrom = LSMEntryControl                                                        --#2026_22

    self:SetColorPickerData(colorPickerData)                                                                --#2026_22
    --Set the default color that should be used for the color picker (will be applied to the controlToColorize, if specified, automatically!) --#2026_22
    self:SetDefaultColor(colorPickerData.defaultColor)                                                      --#2026_22
    --Any function provided to get the color's r, g, b, a values from (only if controlToColorize is missing)--#2026_22
    self:SetOnColorGetFunc(colorPickerData.OnColorGetFunc)
    --Shall we update any SavedVariables (or any control(s)) etc. by calling a callback function as the color changes?
    self:SetOnColorUpdateFunc(colorPickerData.OnColorUpdateFunc)
    --Shall we colorize a control directly?
    self:SetControlToColorize(colorPickerData.controlToColorize)
    --Backup the current controlToColorize (or use the OnColorGetFunc()) color -> for the reset functionality
    self:SetResetToColors()
    --Is a preview control provided where the color changes should be shown as they happen (default is the texture control at the LSM colorPicker entry)
    self:SetPreviewControlToColorize(colorPickerData.previewControl)

    --Show the ColorPicker UI and set it's default/current color now
    self:SetHidden(false)

    self:FireCallbacks("LibScrollableMenu_ColorPicker_OnShown", self, comboBox, LSMEntryControl, colorPickerData)
end

function colorPickerClass:Hide(noNextGlobalMouseUpSkip)
--d("[LSM]ColorPicker:Hide - noNextGlobalMouseUpSkip: "..tos(noNextGlobalMouseUpSkip) .. ", suppressNextOnGlobalMouseUp: " .. tos(lib.preventerVars.suppressNextOnGlobalMouseUp))
    self:SetHidden(true)

    --Re-register the global mouse up event again so we can close the LSM normally once clicked outside
    -->if the dropdown is still opened
    local comboBox = self.lastComboBoxOpenedFrom
    if comboBox ~= nil then
        comboBox.colorPickerOpened = nil
        if not noNextGlobalMouseUpSkip and comboBox:IsDropdownVisible() then
            lib.preventerVars.suppressNextOnGlobalMouseUp = true --Skip the next click which happens as the RegisterGlobalMouseUpEvent is registered, as it seems
        end
    end

    self.lastComboBoxOpenedFrom = nil
    self.LSMEntryControlOpenedFrom = nil
    self.controlToColorize = nil
    self.previewControlToColorize = nil
    self.resetToColors = nil
    self.OnColorUpdateFunc = nil
    self.colorPickerData = nil
    self.defaultColor = nil
    self.OnColorGetFunc = nil

    self:FireCallbacks("LibScrollableMenu_ColorPicker_OnHidden", self)
end



------------------------------------------------------------------------------------------------------------------------
-- ColorPicker create and reference API
------------------------------------------------------------------------------------------------------------------------
local function GetPicker()
    return sharedPicker
end

function lib.InstallColorPicker()
    if sharedPicker then
        return
    end
    --Parent the LSM ColorPicker to it's own TLC which can be shown on any active scene and UI
    local parentControl = LibScrollableMenu_ColorPicker_TLC
    local control = CreateControlFromVirtual(parentControl:GetName() .. "LibScrollableMenuColorPicker", parentControl, PANEL_TEMPLATE)
    sharedPicker = colorPickerClass:New(control)

    lib.ColorPicker = sharedPicker
    lib.ColorPickerTLC = parentControl
end


------------------------------------------------------------------------------------------------------------------------
-- ColorPicker Use API
------------------------------------------------------------------------------------------------------------------------
function lib.AnchorColorPickerToMouse()
    local picker = GetPicker()
    if picker then
        picker:AnchorToMouse()
    end
end

function lib.ShowColorPicker(comboBox, LSMEntryControl, colorPickerData)
    if ZO_IsTableEmpty(colorPickerData) then return end
    local picker = GetPicker()
    if picker then
        picker:Show(comboBox, LSMEntryControl, colorPickerData)
    end
end

function lib.HideColorPicker(noNextGlobalMouseUpSkip)
    local picker = GetPicker()
    if picker then
        picker:Hide(noNextGlobalMouseUpSkip)
    end
end

function lib.IsColorPickerVisible()
    local picker = GetPicker()
    if picker then
        local control = picker.control
        return (control ~= nil and not control:IsHidden()) or false
    end
    return false
end