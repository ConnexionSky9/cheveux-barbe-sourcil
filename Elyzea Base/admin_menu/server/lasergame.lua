-- =========================================================
--  LASERGAME - SERVEUR (pont avec la ressource elyzea_lasergame)
--  Onglet « LaserGame » (permission « lasergame_manage ») : parties en cours, arrêt d'une partie,
--  arènes (créer à sa position, dessiner la zone, poser les apparitions, régler, ouvrir aux joueurs),
--  ouverture du panneau staff complet (/lgadmin). elyzea_lasergame revérifie la permission
--  auprès d'admin_menu à chaque action (export HasPermission).
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_lasergame'
local PERM = 'lasergame_manage'

local function available() return GetResourceState(RES) == 'started' end

AM.Actions.lasergame = { perm = PERM, fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    if name == 'open' then
        TriggerClientEvent('elyzea_lasergame:openAdmin', src)
    elseif name == 'stop' then
        local uid = tostring((type(d.data) == 'table' and d.data.uid) or '')
        local ok, success, msg = pcall(function() return exports[RES]:AdminStopGame(src, uid) end)
        if not ok then return AM.notify(src, 'elyzea_lasergame ne répond pas (redémarre la ressource).', 'error') end
        AM.notify(src, msg or (success and 'Partie arrêtée.' or 'Action impossible.'), success and 'success' or 'error')
        if success then AM.addLog(src, 'LaserGame', 'partie arrêtée : ' .. uid) end
    elseif name:sub(1, 6) == 'arena_' then
        -- arènes : création, réglages, zone et apparitions dessinées en jeu (client/zones.lua, action « lasergame »)
        -- elyzea_lasergame revérifie la permission, la forme de la zone et chaque point
        local MAP = { arena_create = 'create', arena_update = 'update', arena_zone = 'zone', arena_spawns = 'spawns', arena_delete = 'delete',
            arena_tp = 'tp', arena_show = 'show', arena_clear = 'clear', arena_remove = 'remove_point' }
        local action = MAP[name]
        if not action then return AM.notify(src, 'Action inconnue.', 'error') end
        local ok, success, msg = pcall(function() return exports[RES]:AdminArena(src, action, type(d.data) == 'table' and d.data or {}) end)
        if not ok then return AM.notify(src, 'elyzea_lasergame ne répond pas (redémarre la ressource après la mise à jour).', 'error') end
        if msg then AM.notify(src, msg, success and 'success' or 'error') end
        if success and action ~= 'tp' and action ~= 'show' then
            AM.addLog(src, 'LaserGame', ('arène : %s %s'):format(action, tostring((type(d.data) == 'table' and (d.data.id or d.data.label)) or '')))
        end
    end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, PERM) then return end
    if not available() then data.lasergame = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminSummary() end)
    if ok and type(d) == 'table' then d.available = true data.lasergame = d
    else data.lasergame = { available = false, resource = RES, error = true } end
end)
