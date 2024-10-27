-- Messages settings
local strings = {
	SI_LSM_SEARCH_FILTER_TOOLTIP = "Enter a search term to filter the menus and (nested) submenu entries.\nPrefix search with \'/\' shows non matching submenus too",

    SI_LSM_CNTXT_CHECK_ALL = "Check all",
    SI_LSM_CNTXT_CHECK_NONE = "Check none",
    SI_LSM_CNTXT_CHECK_INVERT = "Invert",

    SI_LSM_LAM_HEADER_CNTXTMENU = "Context menu",
    SI_LSM_LAM_CNTXTMEN_DESC = "LibScrollableMenu (short: LSM) is able to replace the non-scrollable context menus of ESO (and LibCustomMenu).\n\nIf you enable the setting here you can choose which controls at the UI should add the context menus via LSM instead.",
    SI_LSM_LAM_CNTXTMEN_REPLACE = "Replace all ZO_Menu context menus",
    SI_LSM_LAM_CNTXTMEN_REPLACE_TT = "Replace the context menus (ZO_Menu, LibCustomMenu) with LibScrolableMenu's scrollable context menu",
    SI_LSM_LAM_CNTXTMEN_OWNER_NAME = "Owner control name",
    SI_LSM_LAM_CNTXTMEN_OWNER_NAME_TT = "Enter here the control name of a context menu owner, e.g. ZO_PlayerInventory",
    SI_LSM_LAM_CNTXTMEN_VIS_ROWS = "Visible rows #",
    SI_LSM_LAM_CNTXTMEN_VIS_ROWS_TT = "Enter the number of visible rows at the contextmenu of the owner's controlName",
    SI_LSM_LAM_CNTXTMEN_VIS_ROWS_SUBMENU = "Visible rows #, submenus",
    SI_LSM_LAM_CNTXTMEN_VIS_ROWS_SUBMENU_TT = "Enter the number of visible rows at the contextmenu's submenus of the owner's controlName",
    SI_LSM_LAM_CNTXTMEN_APPLY_VIS_ROWS = "Apply visibleRows",
    SI_LSM_LAM_CNTXTMEN_APPLY_VIS_ROWS_TT = "Change the visible rows and visible rows of the submenu for the entered context menu owner's controlName.",
    SI_LSM_LAM_CNTXTMEN_ADDED_OWNERS_DD = "Already added owner names",
    SI_LSM_LAM_CNTXTMEN_ADDED_OWNERS_DD_TT = "Choose an already added owner's controlName to change the values, or to delete the saved values in total.",
    SI_LSM_LAM_CNTXTMEN_DELETE_OWNER = "Delete control name",
    SI_LSM_LAM_CNTXTMEN_DELETE_OWNER_TT = "Delete the selected owner's controlName from the saved controls list",
}

for stringId, stringValue in pairs(strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end