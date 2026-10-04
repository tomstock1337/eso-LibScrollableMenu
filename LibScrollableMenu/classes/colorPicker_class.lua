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
local getControlName = libUtil.getControlName
local checkIfContextMenuOpenedButOtherControlWasClicked = libUtil.checkIfContextMenuOpenedButOtherControlWasClicked
local hideTooltip = libUtil.hideTooltip

--------------------------------------------------------------------

local colorPickerClass = ZO_InitializingObject:Subclass() --#2026_21
classes.colorPickerClass = colorPickerClass


local PANEL_TEMPLATE = "LibScrollableMenu_ColorPickerPanel"
local DEFAULT_ANCHOR_OFFSET_X = 100
local DEFAULT_ANCHOR_OFFSET_Y = 100
local INTERACTABLE_LEVEL = ZO_HUD_EDITOR_KEYBOARD_INFO_BOX_INTERACTABLE_ELEMENT_LEVEL

local sharedPicker


function colorPickerClass:Initialize(control)
    self.control = control
    self.suppressApply = false
    self.isUpdatingColors = false

    self.controlToColorize = nil --used to store the control reference that should get the color applied
    self.resetToColors = nil --used to store the default current colors of the control to colorize (for the reset function)

    control:SetDrawTier(DT_HIGH)
    control:SetDrawLevel(10)
    control:SetMouseEnabled(true)
    control:SetMovable(true)
    control:SetClampedToScreen(true)
    control:SetHidden(true)

    local titleLabel = control:GetNamedChild("Title")
    titleLabel:SetText(GetString(SI_WINDOW_TITLE_COLOR_PICKER))

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
d("Move stop")
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

function colorPickerClass:Show(controlToColorize)
    if controlToColorize == nil then return end
    self:SetControlToColorize(controlToColorize)

    self:SetHidden(false)
end

function colorPickerClass:Hide()
    self:SetHidden(true)

    self.controlToColorize = nil
    self.resetToColors = nil
end

function colorPickerClass:SetControlToColorize(control)
    self.controlToColorize = control
    --Backup the current control's color as default, for the reset
    self:SetResetToColors()
end

function colorPickerClass:GetControlToColorize()
    return self.controlToColorize
end

function colorPickerClass:SetResetToColors()
    self.resetToColors = self:GetCurrentControlColors()
end

function colorPickerClass:GetResetToColors()
    return self.resetToColors
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
    end
end

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

function colorPickerClass:SetColor(r, g, b, a)
    self.colorSelect:SetColorAsRGB(r, g, b)
    self.valueSlider:SetValue(1 - self.colorSelect:GetValue())
    self.alphaSlider:SetValue(a or 1)
    self:UpdateColors(r, g, b, a or 1)
end

function colorPickerClass:GetCurrentControlColors()
    local controlToColorize = self:GetControlToColorize()
    if not controlToColorize or controlToColorize.GetColor == nil then return end
    local currentColors = { controlToColorize:GetColor() }
    return { r = currentColors[1], g = currentColors[2], b = currentColors[3], a = currentColors[4] }
end

function colorPickerClass:ApplyLiveColor(r, g, b, a)
    local controlToColorize = self:GetControlToColorize()
    if controlToColorize and controlToColorize.SetColor then
        controlToColorize:SetColor(r, g, b, a)
    end
end

function colorPickerClass:LoadColors()
    local colorTable = self:GetCurrentControlColors()
    if colorTable == nil then
        return
    end
    self.suppressApply = true
    self:SetColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
    self.previewInitialTexture:SetColor(colorTable.r, colorTable.g, colorTable.b, colorTable.a)
    self.suppressApply = false
end

function colorPickerClass:Reset()
    local resetToColorTable = self:GetResetToColors()
    if resetToColorTable == nil then return end
    self:ApplyLiveColor(resetToColorTable.r, resetToColorTable.g, resetToColorTable.b, resetToColorTable.a)
    self:LoadColors()
end

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
    parent:SetHidden(hidden)
    control:SetHidden(hidden)

    if not hidden then
        parent:BringWindowToTop()
        control:SetMovable(true)
        control:SetMouseEnabled(true)
        self:LoadColors()
    end
end

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
        xOffset = mocLeft + mocCtrl:GetWidth() + 20
        if xOffset >= screenWidth then return end
    end
    local yOffset = mocTop
    if ( screenHeight - yOffset ) <= controlHeight then
        yOffset = screenHeight - controlHeight - 20
    end

    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, yOffset, yOffset)
    control:ClearAnchors()
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

function lib.ShowColorPicker(control)
    if not control then return end
--d("[LSM]ShowColorPicker for " .. tos(control and control.GetName and control:GetName() or ""))
    local picker = GetPicker()
    if picker then
        picker:Show(control)
    end
end

function lib.HideColorPicker()
    local picker = GetPicker()
    if picker then
        picker:Hide()
    end
end