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

-----------------------------------------------------------------------
-- Library utility
--------------------------------------------------------------------
local constants = lib.contants
local entryTypeConstants = constants.entryTypes
local comboBoxConstants = constants.comboBox
local comboBoxMappingConstants = comboBoxConstants.mapping
local comboBoxDefaults = comboBoxConstants.defaults

local libUtil = lib.Util


-----------------------------------------------------------------------
-- Library local utility variables
--------------------------------------------------------------------
local throttledCallDelaySuffixCounter = 0
local NIL_CHECK_TABLE = {}
libUtil.NIL_CHECK_TABLE = NIL_CHECK_TABLE

--Throttled calls
local throttledCallDelayName = MAJOR .. '_throttledCallDelay'
local throttledCallDelay = 10

--Context menus
local g_contextMenu


--------------------------------------------------------------------
-- Get the context menu reference variable
--------------------------------------------------------------------
function libUtil.getContextMenuReference()
	g_contextMenu = g_contextMenu or lib.contextMenu
	return g_contextMenu
end




--------------------------------------------------------------------
-- Determine value or function returned value
--------------------------------------------------------------------
--Run function arg to get the return value (passing in ... as optional params to that function),
--or directly use non-function return value arg
function libUtil.getValueOrCallback(arg, ...)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 6, tos(arg)) end
	if type(arg) == "function" then
		return arg(...)
	else
		return arg
	end
end
local getValueOrCallback = libUtil.getValueOrCallback


--------------------------------------------------------------------
-- Controls
--------------------------------------------------------------------
function libUtil.getControlName(control, alternativeControl)
	local ctrlName = control ~= nil and (control.name or (control.GetName ~= nil and control:GetName()))
	if ctrlName == nil and alternativeControl ~= nil then
		ctrlName = (alternativeControl.name or (alternativeControl.GetName ~= nil and alternativeControl:GetName()))
	end
	ctrlName = ctrlName or "n/a"
	return ctrlName
end
local getControlName = libUtil.getControlName

function libUtil.getHeaderControl(selfVar)
	if ZO_IsTableEmpty(selfVar.options) then return end
	local dropdownControl = selfVar.m_dropdownObject.control
	return dropdownControl.header, dropdownControl
end
local getHeaderControl = libUtil.getHeaderControl


--------------------------------------------------------------------
-- Data & data source determination
--------------------------------------------------------------------
function libUtil.getDataSource(data)
	if data and data.dataSource then
		return data:GetDataSource()
	end
	return data or NIL_CHECK_TABLE
end
local getDataSource = libUtil.getDataSource

-- >> data, dataEntry
function libUtil.getControlData(control)
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 28, tos(getControlName(control))) end
	local data = control.m_sortedItems or control.m_data

	return getDataSource(data)
end
--local getControlData = libUtil.getControlData


--------------------------------------------------------------------
-- Delayed / queued calls
--------------------------------------------------------------------
function libUtil.throttledCall(callback, delay, throttledCallNameSuffix)
	delay = delay or throttledCallDelay
	throttledCallDelaySuffixCounter = throttledCallDelaySuffixCounter + 1
	throttledCallNameSuffix = throttledCallNameSuffix or tos(throttledCallDelaySuffixCounter)
	local throttledCallDelayTotalName = throttledCallDelayName .. throttledCallNameSuffix
	if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 4, tos(callback), tos(delay), tos(throttledCallDelayTotalName)) end
	EM:UnregisterForUpdate(throttledCallDelayTotalName)
	EM:RegisterForUpdate(throttledCallDelayTotalName, delay, function()
		EM:UnregisterForUpdate(throttledCallDelayTotalName)
		if libDebug.doDebug then dlog(libDebug.LSM_LOGTYPE_VERBOSE, 5, tos(callback), tos(throttledCallDelayTotalName)) end
		callback()
	end)
end
--local throttledCall = libUtil.throttledCall
