-- =========================================================
--  TAGS - SERVEUR
--  Pont entre le menu et elyzea_tags (graffitis des quartiers).
--  Permission « tags_manage » vérifiée par le dispatcher ;
--  elyzea_tags revalide chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_tags'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.tags = { perm = 'tags_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:TagsAdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Tags « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'Les tags ne répondent pas (redémarre elyzea_tags).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success and name ~= 'goto' then AM.addLog(src, 'Tags', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'tags_manage') then return end
    if not available() then data.tags = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:TagsAdminData() end)
    data.tags = ok and d or { available = false, resource = RES, error = true }
end)

-- Tags PERMANENTS posés dans l'éditeur de map (Mode édition) : permission « editor_props »
AM.Actions.editor_tag_place = { perm = 'editor_props', noRefresh = true, fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local ok, success, msg = pcall(function() return exports[RES]:StaffPlaceTag(src, d) end)
    if not ok then return AM.notify(src, 'Les tags ne répondent pas (redémarre elyzea_tags).', 'error') end
    AM.notify(src, msg or (success and 'Tag posé.' or 'Tag refusé.'), success and 'success' or 'error')
    if success then AM.addLog(src, 'Tag permanent', tostring(msg)) end
end }
AM.Actions.editor_tag_delete = { perm = 'editor_props', noRefresh = true, fn = function(src, d)
    if not available() then return end
    local ok, success, msg = pcall(function() return exports[RES]:TagsAdminAction(src, 'delete', { id = tonumber(d.id) }) end)
    if not ok then return AM.notify(src, 'Les tags ne répondent pas (redémarre elyzea_tags).', 'error') end
    AM.notify(src, msg or '', success and 'success' or 'error')
    if success then AM.addLog(src, 'Tag supprimé (éditeur)', tostring(msg)) end
end }
