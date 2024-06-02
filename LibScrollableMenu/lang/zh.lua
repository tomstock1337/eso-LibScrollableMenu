local stringsZH = {
	SI_LSM_SEARCH_FILTER_TOOLTIP = "输入搜索词来过滤菜单和（嵌套的）子菜单条目。\n以 \'/\' 为前缀的搜索也会显示不匹配的子菜单"
}

for stringId, stringValue in pairs(stringsZH) do
   SafeAddString(_G[stringId], stringValue, 1)
end

