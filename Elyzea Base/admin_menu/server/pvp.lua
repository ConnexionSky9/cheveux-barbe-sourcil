-- =========================================================
--  ARÈNE PVP - SERVEUR (pont avec la ressource pvp_arena)
--  Onglet « ⚔️ Arène PvP » (permission « pvp_manage ») : parties en cours, arènes (points posés à la
--  position du staff), réglages, historique. Tout est revérifié par pvp_arena.
-- =========================================================
local AM = AdminMenu
local RES = 'pvp_arena'
local function available() return GetResourceState(RES) == 'started' end

AM.Actions.pvp = { perm = 'pvp_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Arène PvP « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'pvp_arena ne répond pas (redémarre la ressource).', 'error')
    end
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success and name ~= 'arena_show' and name ~= 'arena_tp' and name ~= 'stats_refresh' then AM.addLog(src, 'Arène PvP', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'pvp_manage') then return end
    if not available() then data.pvp = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData(src) end)
    data.pvp = ok and d or { available = false, resource = RES, error = true }
end)
