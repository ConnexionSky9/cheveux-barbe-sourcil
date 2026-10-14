-- =========================================================
--  NOIR X - SERVEUR
--  Pont entre le menu et la ressource noirx (téléphone clandestin).
--  Permission « noirx_staff » vérifiée par le dispatcher ;
--  noirx revérifie la permission et revalide chaque valeur.
--  noirx lit sa base pendant ces appels : on passe par ses exports asynchrones
--  (AdminDataAsync / AdminActionAsync) et on reçoit la réponse par événement local.
-- =========================================================
local AM = AdminMenu
local RES = 'noirx'
local REFRESH = 4          -- secondes entre deux lectures des données NOIR X par staff

local Cache, FetchedAt, Pending = {}, {}, {}

local function available() return GetResourceState(RES) == 'started' end

local function fetch(src)
    if Pending[src] then return end
    Pending[src] = true
    local ok = pcall(function() return exports[RES]:AdminDataAsync(src) end)
    if not ok then Pending[src] = nil end
end

AddEventHandler('noirx:server:adminData', function(src, d)
    src = tonumber(src)
    if not src then return end
    Pending[src] = nil
    FetchedAt[src] = os.time()
    Cache[src] = type(d) == 'table' and d or { available = false, error = true }
    AM.sendData(src)
end)

AddEventHandler('noirx:server:adminActionDone', function(src, name, success, msg)
    src = tonumber(src)
    if not src then return end
    if msg and msg ~= '' then AM.notify(src, tostring(msg), success and 'success' or 'error') end
    if success then AM.addLog(src, 'NOIR X', ('%s : %s'):format(tostring(name), tostring(msg or ''))) end
    FetchedAt[src] = 0
    fetch(src)
end)

AM.Actions.noirx = { perm = 'noirx_staff', noRefresh = true, fn = function(src, d)
    if not available() then return AM.notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(RES), 'error') end
    local name = tostring(d.name or '')
    local ok, err = pcall(function() return exports[RES]:AdminActionAsync(src, name, type(d.data) == 'table' and d.data or {}) end)
    if not ok then
        print(('^1[AdminMenu] NOIR X « %s » : %s^7'):format(name, tostring(err)))
        return AM.notify(src, 'NOIR X ne répond pas (redémarre noirx).', 'error')
    end
end }

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'noirx_staff') then return end
    if not available() then data.noirx = { available = false, resource = RES } return end
    if (FetchedAt[src] or 0) + REFRESH <= os.time() then fetch(src) end
    data.noirx = Cache[src] or { available = true, loading = true }
end)

AddEventHandler('playerDropped', function()
    local src = source
    Cache[src], FetchedAt[src], Pending[src] = nil, nil, nil
end)
AddEventHandler('onResourceStop', function(res)
    if res == RES then Cache, FetchedAt, Pending = {}, {}, {} end
end)
