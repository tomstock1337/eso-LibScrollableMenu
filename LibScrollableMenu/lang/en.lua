-- Messages settings
local strings = {
	SI_LSM_SEARCH_FILTER_TOOLTIP = "Enter a search term to filter the menus and (nested) submenu entries.\nPrefix search with \'/\' shows non matching submenus too"
}

for stringId, stringValue in pairs(strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end