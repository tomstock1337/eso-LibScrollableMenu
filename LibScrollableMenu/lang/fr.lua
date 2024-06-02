local stringsFR = {
	SI_LSM_SEARCH_FILTER_TOOLTIP = "Saisissez un terme de recherche pour filtrer les menus et les entrées de sous-menu (imbriqués).\nLa recherche avec le préfixe \'/\' affiche également les sous-menus qui ne correspondent pas."
}

for stringId, stringValue in pairs(stringsFR) do
   SafeAddString(_G[stringId], stringValue, 1)
end

