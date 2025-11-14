-- Messages settings
local strings = {
	SI_LSM_SEARCH_FILTER_TOOLTIP = "Enter a search term to filter the menus and (nested) submenu entries.\nPrefix search with \'/\' shows non matching submenu-entries too",

    SI_LSM_CNTXT_CHECK_ALL = "Check all",
    SI_LSM_CNTXT_CHECK_NONE = "Check none",
    SI_LSM_CNTXT_CHECK_INVERT = "Invert",

    SI_LSM_SLIDER_CURRENT_MIN_MAX_STEP = "Current: %q (Min.: %s/Max.: %s, step: %s)"
}

for stringId, stringValue in pairs(strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end