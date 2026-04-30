-- FS25_SlurryPipeSystem
-- Author: Oscar Mods
-- Version: 1.0.0.0

-- PlaceableOverride.lua

SPSPlaceableOverride = {}

function SPSPlaceableOverride.updateInfo(self, superFunc, infoTable)
    superFunc(self, infoTable)
    if g_slurryPipeManager ~= nil then
        local pEntry = g_slurryPipeManager:getPlaceableEntry(self)
        if pEntry ~= nil and pEntry.agitatorEnabled and pEntry.sourceEntry ~= nil then
            local t   = pEntry.sourceEntry.thickness or 0
            local pct = math.min(100, math.floor(t * 100 + 0.5))
            local warn = g_slurryPipeManager:getThicknessWarning(pEntry.sourceEntry)
            if warn == "tooThick" then
                table.insert(infoTable, {
                    title      = g_i18n:getText("warning_spsSlurryTooThick"),
                    text       = string.format("%d%%", pct),
                    accentuate = true,
                })
            elseif warn == "thickening" then
                table.insert(infoTable, {
                    title      = string.format(g_i18n:getText("warning_spsSlurryThickening"), pct),
                    text       = "",
                    accentuate = true,
                })
            else
                table.insert(infoTable, {
                    title = g_i18n:getText("sps_infoThicknessTitle"),
                    text  = string.format("%d%%", pct),
                })
            end
        end
    end
end