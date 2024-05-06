--[[
GERMAN

Ä = \195\132
ä = \195\164
Ö = \195\150
ö = \195\182
Ü = \195\156
ü = \195\188
ß = \195\159

]]--

local stringsDE = {
	SI_LSM_SEARCH_FILTER_TOOLTIP = "Gib einen Suchbegriff ein, um die Einträge der Menüs und (mehrstufigen) Untermenüs zu filtern.\nSchreibe \'/\' davor, um nicht passende Untermenüs dennoch anzuzeigen."
}

for stringId, stringValue in pairs(stringsDE) do
   SafeAddString(_G[stringId], stringValue, 1)
end

