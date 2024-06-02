local stringsES = {
	SI_LSM_SEARCH_FILTER_TOOLTIP = "Ingrese un término de búsqueda para filtrar los menús y las entradas de submenús (anidados).\nLa búsqueda con prefijo \'/\' también muestra submenús que no coinciden"
}

for stringId, stringValue in pairs(stringsES) do
   SafeAddString(_G[stringId], stringValue, 1)
end

