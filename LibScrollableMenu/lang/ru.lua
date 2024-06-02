local stringsRU = {
	SI_LSM_SEARCH_FILTER_TOOLTIP = "Введите поисковый запрос, чтобы отфильтровать меню и (вложенные) записи подменю.\nПоиск по префиксу с помощью \'/\' также показывает несовпадающие подменю."
}

for stringId, stringValue in pairs(stringsRU) do
   SafeAddString(_G[stringId], stringValue, 1)
end

