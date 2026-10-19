-- =========================================================
--  CASINO - SERVEUR (pont avec la ressource elyzea_casino)
--  · Rôle « Casino » des PNJ de l'éditeur : croupier de blackjack, croupier de roulette,
--    roue de la fortune, guichetier. La table / roue se pose avec l'outil de placement.
--  · Onglet « Casino » : réglages, roues, guichet, statistiques (permission « casino_manage »),
--    revérifiée par elyzea_casino qui revalide chaque valeur.
-- =========================================================
local AM = AdminMenu
local RES = 'elyzea_casino'
local ROLES = { blackjack = true, roulette = true, wheel = true, cashier = true }

local function available() return GetResourceState(RES) == 'started' end

-- Validation du rôle (appelée par cleanNpc de l'éditeur)
function CasinoCleanRole(c)
    if type(c) ~= 'table' or not ROLES[c.role] then return nil end
    local out = {
        role = c.role,
        name = (tostring(c.name or ''):gsub('[%c<>]', '')):sub(1, 40),
        model = (tostring(c.model or ''):gsub('[^%w_]', '')):sub(1, 60),
    }
    if out.model == '' then out.model = nil end
    if c.role == 'wheel' then
        local w = (tostring(c.wheel or ''):lower():gsub('[^%w_]', '')):sub(1, 30)
        out.wheel = w ~= '' and w or 'lucky'
    end
    return out
end

local last = {}   -- [src] = dernier résultat de test / simulation (affiché dans l'onglet)

AM.Actions.casino = { perm = 'casino_manage', fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, success, msg, extra = pcall(function() return exports[RES]:AdminAction(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] Casino « %s » : %s^7'):format(name, tostring(success)))
        return AM.notify(src, 'elyzea_casino ne répond pas (redémarre la ressource).', 'error')
    end
    last[src] = extra
    if msg and msg ~= '' then AM.notify(src, msg, success and 'success' or 'error') end
    if success and name ~= 'wheel_test' and name ~= 'wheel_simulate' and name ~= 'stats_refresh' then AM.addLog(src, 'Casino', tostring(msg)) end
end }

table.insert(AM.DataHooks, function(src, data)
    -- Liste des roues pour le rôle « Roue de la fortune » dans l'éditeur de PNJ
    if AM.hasPerm(src, 'editor_peds') or AM.hasPerm(src, 'casino_manage') then
        local ok, d = pcall(function() return available() and exports[RES]:AdminData(0) or nil end)
        data.casinoWheels = {}
        if ok and type(d) == 'table' and d.wheels then
            for _, w in ipairs(d.wheels) do data.casinoWheels[#data.casinoWheels + 1] = { id = w.id, name = w.name } end
        end
    end
    if not AM.hasPerm(src, 'casino_manage') then return end
    if not available() then data.casino = { available = false, resource = RES } return end
    local ok, d = pcall(function() return exports[RES]:AdminData(src) end)
    data.casino = ok and d or { available = false, resource = RES, error = true }
    if ok and type(d) == 'table' then d.last = last[src] end
end)

AddEventHandler('playerDropped', function() last[source] = nil end)
