-- Messages settings
local strings = {
	SI_LSM_SEARCH_FILTER_TOOLTIP = "Enter a search term to filter the menus and (nested) submenu entries.\nPrefix search with \'/\' shows non matching submenus too",

    SI_LSM_CNTXT_CHECK_ALL = "Check all",
    SI_LSM_CNTXT_CHECK_NONE = "Check none",
    SI_LSM_CNTXT_CHECK_INVERT = "Invert",

    SI_LSM_LAM_HEADER_CNTXTMENU = "Context menu",
    SI_LSM_LAM_CNTXTMEN_DESC = "LibScrollableMenu (short: LSM) can replace the non-scrollable context menus of ESO (and LibCustomMenu).\n\nIf you enable the setting here you can choose which controls at the UI should add the context menus via LSM instead.\nControl = either the control name below the mouse cursor, or it's parent (e.g. a scroll list= or the owning window (e.g. ZO_PlayerInventory).\n\nYou can add new control names at the owner editbox below, and define for each onwer how many context menu rows and submenu rows should be shown.\n\nAlready added controls can be selected from the dropdown and their settings can be changed or the entry can be deleted then.\n\nYou can enable LSM for all controls (and blacklist some of them) or only some controls (need to whitelist them) below.",
    SI_LSM_LAM_CNTXTMEN_REPLACE = "Replace all ZO_Menu context menus",
    SI_LSM_LAM_CNTXTMEN_REPLACE_TT = "Replace the context menus (ZO_Menu, LibCustomMenu) with LibScrolableMenu's scrollable context menu",
    SI_LSM_LAM_CNTXTMEN_OWNER_NAME = "Owner control name",
    SI_LSM_LAM_CNTXTMEN_OWNER_NAME_TT = "Enter the control name of a context menu owner here, e.g. ZO_PlayerInventory.\nPress the return key to update the add button's state.\n\nTo get the control name of the control below the cursor use the chat slash command /lsmmoc, and you will see the current control name, it's parentName and the owning window name in the chat.\nLSM will check for the control name first, then the parent and at the end the owning window name to determine if a control go the LSM context menu enabled (and to determine it's settings like the visible rows)",
    SI_LSM_LAM_CNTXTMEN_VIS_ROWS = "Visible rows #",
    SI_LSM_LAM_CNTXTMEN_VIS_ROWS_TT = "Choose the number of visible rows at the contextmenu of the owner's controlName",
    SI_LSM_LAM_CNTXTMEN_VIS_ROWS_SUBMENU = "Visible rows #, submenus",
    SI_LSM_LAM_CNTXTMEN_VIS_ROWS_SUBMENU_TT = "Choose the number of visible rows at the contextmenu's submenus of the owner's controlName",
    SI_LSM_LAM_CNTXTMEN_APPLY_VIS_ROWS = "Apply visibleRows",
    SI_LSM_LAM_CNTXTMEN_APPLY_VIS_ROWS_TT = "Change the visible rows & visible rows submenu for the chosen context menu owner's controlName.",
    SI_LSM_LAM_CNTXTMEN_ADDED_OWNERS_DD = "Already added owner names",
    SI_LSM_LAM_CNTXTMEN_ADDED_OWNERS_DD_TT = "Choose an already added owner's controlName to change the values, or to delete the saved values in total.",
    SI_LSM_LAM_CNTXTMEN_DELETE_OWNER = "Delete saved owner",
    SI_LSM_LAM_CNTXTMEN_DELETE_OWNER_TT = "Delete the selected owner's controlName from the saved controls list",

    SI_LSM_LAM_CNTXTMEN_USE_FOR_ALL = "Use LSM for all controls",
    SI_LSM_LAM_CNTXTMEN_USE_FOR_ALL_TT = "Use LibScrollableMenu's context menu for all controls in ESO.\n\nIf enabled: You can blacklist controls at the blacklist below.\nIf disabled: You must whitelist controls at the whitelist below.",
    SI_LSM_LAM_CNTXTMEN_WHITELIST = "Whitelisted controls",
    SI_LSM_LAM_CNTXTMEN_WHITELIST_TT = "Only valid if you disable the setting \'Use LSM for all controls\'.\n\nThis list contains the whitelisted controls which will only show a LibScrollableMenu context menu.\nIf the control/parent control/owning window control is not on the list LSM won't be used and default ESO context menu (ZO_Menu, LibCustomMenu) will be used as usually.",
    SI_LSM_LAM_CNTXTMEN_BLACKLIST = "Blacklisted controls",
    SI_LSM_LAM_CNTXTMEN_BLACKLIST_TT = "Only valid if you enable the setting \'Use LSM for all controls\'.\n\nThis list contains the blacklisted controls which will not show a LibScrollableMenu context menu.\nIf the control/parent control/owning window control is on the list LSM won't be used and default ESO context menu (ZO_Menu, LibCustomMenu) will be used as usually.",

    SI_LSM_LAM_CNTXTMEN_LIST_CONTROLNAME = "Control for list",
    SI_LSM_LAM_CNTXTMEN_LIST_CONTROLNAME_TT = "Enter the control name for the whitelist, or blacklist, here. Press the return key to update the add button's state.",

    SI_LSM_LAM_CNTXTMEN_WHITELIST_ADD = "Add to whitelist",
    SI_LSM_LAM_CNTXTMEN_WHITELIST_ADD_TT = "Add the control name to the whitelist",
    SI_LSM_LAM_CNTXTMEN_BLACKLIST_ADD = "Add to blacklist",
    SI_LSM_LAM_CNTXTMEN_BLACKLIST_ADD_TT = "Add the control name to the blacklist",
    SI_LSM_LAM_CNTXTMEN_WHITELIST_DEL = "Delete from whitelist",
    SI_LSM_LAM_CNTXTMEN_WHITELIST_DEL_TT = "Delete the control name from the whitelist",
    SI_LSM_LAM_CNTXTMEN_BLACKLIST_DEL = "Delete from blacklist",
    SI_LSM_LAM_CNTXTMEN_BLACKLIST_DEL_TT = "Delete the control name from the blacklist",

    SI_LSM_MOC_TEMPLATE = "Control names - below the cursor: %s, parent: %s, owning window: %s"
}

for stringId, stringValue in pairs(strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end