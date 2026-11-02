-- =====================================================================
--  Imitations FiveM / elyzea_core / elyzea_inventory pour tester hors jeu
--  Chaque ressource est chargée dans son propre environnement (comme en jeu).
-- =====================================================================
MySQL = {
    query = { await = function(s, a) return py_query(s, a) end },
    single = { await = function(s, a) return py_single(s, a) end },
    scalar = { await = function(s, a) return py_scalar(s, a) end },
    update = setmetatable({ await = function(s, a) return py_update(s, a) end }, { __call = function(_, s, a) return py_update(s, a) end }),
    insert = { await = function(s, a) return py_insert(s, a) end },
}
json = { encode = function(t) return py_json_encode(t) end, decode = function(s) return py_json_decode(s) end }

-- vector3
local V = {}
V.__index = V
V.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
V.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V) end

-- Joueurs
Players = {}     -- [src] = { cid, money = {cash, bank}, items = {}, pos }
Society = {}
Sent = {}        -- événements client envoyés
function addPlayer(src, cid, cash, bank, pesos, pos)
    Players[src] = { cid = cid, money = { cash = cash, bank = bank }, items = { pesos = pesos or 0 }, pos = pos or vector3(0, 0, 0) }
end
local function playerObj(src)
    local p = Players[src]
    if not p then return nil end
    return {
        PlayerData = { citizenid = p.cid, source = src },
        Functions = {
            GetMoney = function(k) return p.money[k] or 0 end,
            RemoveMoney = function(k, n) if (p.money[k] or 0) < n then return false end p.money[k] = p.money[k] - n return true end,
            AddMoney = function(k, n) p.money[k] = (p.money[k] or 0) + n return true end,
        },
    }
end

-- Véhicules du monde
Ents, NextEnt = {}, 100
REAL_TYPE = {}        -- modèle → type réel (GetVehicleType)
MISSING = {}          -- modèles absents du serveur
function spawnWorld(model, plate, pos, engine, body)
    NextEnt = NextEnt + 1
    Ents[NextEnt] = { model = model, plate = plate or '', pos = pos, engine = engine or 1000.0, body = body or 1000.0, state = {} }
    return NextEnt
end
function joaat(s) return s end
GetHashKey = joaat
function CreateVehicleServerSetter(model, vtype, x, y, z, h)
    if MISSING[model] then return 0 end
    local e = spawnWorld(model, '', vector3(x, y, z))
    Ents[e].spawnType = vtype
    return e
end
function DoesEntityExist(e) return Ents[e] ~= nil end
function DeleteEntity(e) Ents[e] = nil end
function GetAllVehicles() local t = {} for e in pairs(Ents) do t[#t + 1] = e end return t end
function GetEntityCoords(e)
    if type(e) == 'string' then return Players[tonumber(e:sub(4))].pos end
    return Ents[e].pos
end
function GetPlayerPed(src) return Players[tonumber(src)] and ('ped' .. src) or 0 end
function GetPlayers() local t = {} for s in pairs(Players) do t[#t + 1] = tostring(s) end return t end
function GetVehicleNumberPlateText(e) return Ents[e].plate end
function SetVehicleNumberPlateText(e, p) Ents[e].plate = p end
function GetVehicleEngineHealth(e) return Ents[e].engine end
function GetVehicleBodyHealth(e) return Ents[e].body end
function GetVehicleType(e) return REAL_TYPE[Ents[e].model] or 'automobile' end
function GetEntityType(e) return Ents[e] and 2 or 0 end
function NetworkGetNetworkIdFromEntity(e) return e + 5000 end
function NetworkGetEntityFromNetworkId(n) return n - 5000 end
function Entity(e) return { state = { set = function(_, k, v) Ents[e].state[k] = v end } } end
function GetGameTimer() return os.clock() * 1000 end
function Wait() end
function CreateThread() end
Timeouts = {}
function SetTimeout(ms, fn) Timeouts[#Timeouts + 1] = fn end
function GetPlayerName(src) return 'Joueur' .. src end

Started = { elyzea_change = true, elyzea_fourriere = true, elyzea_garage = true, admin_menu = false }
function GetResourceState(r) return Started[r] and 'started' or 'missing' end

Handlers = {}
function RegisterNetEvent(name, fn) if fn then Handlers[name] = fn end end
function AddEventHandler(name, fn) Handlers[name] = fn end
function TriggerClientEvent(name, src, ...) Sent[#Sent + 1] = { name = name, src = src, args = { ... } } end
function TriggerEvent(name, ...) if Handlers[name] then Handlers[name](...) end end
function fire(name, src, ...)
    source = src
    return Handlers[name](...)
end
function lastSent(name, src)
    for i = #Sent, 1, -1 do if Sent[i].name == name and (not src or Sent[i].src == src) then return Sent[i] end end
end

-- Exports par ressource
Registry = {
    elyzea_core = {
        GetPlayer = function(src) return playerObj(src) end,
        GetSourceByCitizenId = function(cid) for s, p in pairs(Players) do if p.cid == cid then return s end end end,
        AddSocietyMoney = function(name, n) Society[name] = (Society[name] or 0) + n return true end,
        GiveKeys = function() return true end,
        GetMoney = function(src, k) return Players[src] and Players[src].money[k] or 0 end,
        RemoveMoney = function(src, k, n) local p = playerObj(src) return p ~= nil and p.Functions.RemoveMoney(k, n) end,
        AddMoney = function(src, k, n) local p = playerObj(src) return p ~= nil and p.Functions.AddMoney(k, n) end,
    },
    elyzea_inventory = {
        GetItemCount = function(src, item) return Players[src].items[item] or 0 end,
        RemoveItem = function(src, item, n) local p = Players[src] if (p.items[item] or 0) < n then return false end p.items[item] = p.items[item] - n return true end,
        AddItem = function(src, item, n) local p = Players[src] p.items[item] = (p.items[item] or 0) + n return true end,
    },
    elyzea_change = {}, elyzea_fourriere = {}, elyzea_garage = {},
}
local function exportsFor(res)
    return setmetatable({}, {
        __call = function(_, name, fn) Registry[res][name] = fn end,
        __index = function(_, other)
            return setmetatable({}, { __index = function(_, fname)
                return function(_, ...)
                    local f = Registry[other] and Registry[other][fname]
                    if not f then error(('export %s:%s introuvable'):format(other, fname)) end
                    return f(...)
                end
            end })
        end,
    })
end

-- Charge une ressource (fichiers relatifs à « Elyzea Base ») dans son propre environnement
Envs = {}
function loadResource(res, files)
    local env = setmetatable({ exports = exportsFor(res) }, { __index = _G })
    env._G = env
    for _, f in ipairs(files) do
        local chunk = assert(load(py_read(f), '@' .. f, 't', env))
        chunk()
    end
    Envs[res] = env
    return env
end

-- Petit outil de vérification
Fails, Oks = 0, 0
function check(cond, label)
    if cond then Oks = Oks + 1 print('  ok   ' .. label) else Fails = Fails + 1 print('  ÉCHEC ' .. label) end
end
