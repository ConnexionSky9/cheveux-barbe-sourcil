-- =====================================================================
--  ELYZEA EMS - serveur : brancards et fauteuil roulant
--  Chaque brancard est un objet réseau suivi ici : qui le tient, qui est
--  allongé dessus, dans quel véhicule il est chargé. L'état est publié dans
--  GlobalState.emsStretchers ; les clients ne font que l'afficher.
--  Quand le patient descend, sa position vient du brancard côté serveur :
--  il reste là où est le brancard (jamais de retour à l'ancienne position).
-- =====================================================================
local P = Ems
local ST = Config.Stretcher or {}
local VH = ST.vehicle or {}
local S = {}             -- [net] = { net, holder, patient, veh, owner }
P.stretchers = S

local MODELS = {}
for _, m in ipairs(ST.models or {}) do MODELS[type(m) == 'number' and m or GetHashKey(m)] = true end

local function Publish()
    local out = {}
    for _, s in pairs(S) do out[#out + 1] = { net = s.net, holder = s.holder, patient = s.patient, veh = s.veh } end
    GlobalState.emsStretchers = out
end

local function Ent(net)
    net = tonumber(net)
    if not net then return nil end
    local e = NetworkGetEntityFromNetworkId(net)
    if e and e ~= 0 and DoesEntityExist(e) then return e end
    return nil
end

local function PedPos(src) local ped = GetPlayerPed(src) return ped ~= 0 and GetEntityCoords(ped) or nil end
local function Near(src, ent, dist)
    local p = PedPos(src)
    return p ~= nil and ent ~= nil and #(p - GetEntityCoords(ent)) <= dist
end
local function ByHolder(src) for _, s in pairs(S) do if s.holder == src then return s end end end
local function ByPatient(src) for _, s in pairs(S) do if s.patient == src then return s end end end
local function ByVeh(vnet) for _, s in pairs(S) do if s.veh == vnet then return s end end end
local function Owned(src) local n = 0 for _, s in pairs(S) do if s.owner == src then n = n + 1 end end return n end

-- Le patient descend : posé à côté du brancard, à l'endroit où le brancard se trouve vraiment
local function PatientOff(s)
    local t = s.patient
    if not t then return end
    s.patient = nil
    if GetPlayerName(t) then
        Player(t).state:set('emsOnStretcher', nil, true)
        local e = Ent(s.net)
        local c = e and GetEntityCoords(e)
        TriggerClientEvent('ems:client:offStretcher', t, s.net, c and { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(e) } or nil)
    end
end

local function Remove(net)
    local s = S[net]
    if not s then return end
    PatientOff(s)
    S[net] = nil
    local e = Ent(net)
    if e then DeleteEntity(e) end
end

-- Utilisé par server/medical.lua (installer dans un véhicule) : le patient quitte d'abord le brancard
function P.StretcherFree(t)
    local s = ByPatient(t)
    if s then PatientOff(s) Publish() end
end
function P.OnStretcher(t) return ByPatient(t) ~= nil end

local function Patient(src, id)
    local t = tonumber(id)
    if not t or t == src or not GetPlayerName(t) or not P.GetPlayer(t) then return nil, 'Patient introuvable.' end
    if P.Dist(src, t) > (ST.reach or 3.0) + 2.0 then return nil, 'Le patient est trop loin.' end
    return t
end

local A = {}

-- Brancard sorti par l'EMS (objet créé par son client) : vérifié puis suivi
A.stretcherRegister = function(src, d)
    local net = tonumber(d.net)
    local e
    for _ = 1, 20 do e = Ent(net) if e then break end Wait(50) end
    if not e then return { error = 'Brancard introuvable.' } end
    local bad
    if not MODELS[GetEntityModel(e)] then bad = 'Objet non autorisé.'
    elseif S[net] then bad = 'Brancard déjà suivi.'
    elseif not Near(src, e, 6.0) then bad = 'Brancard trop loin.'
    elseif ByHolder(src) then bad = 'Vous tenez déjà un brancard.'
    elseif Owned(src) >= (ST.perEms or 1) then bad = 'Rangez d\'abord votre autre brancard.' end
    if bad then DeleteEntity(e) return { error = bad } end
    S[net] = { net = net, holder = src, owner = src }
    Publish()
    return { ok = true, net = net }
end

A.stretcherGrab = function(src, d)
    local s = S[tonumber(d.net)]
    if not s then return { error = 'Brancard introuvable.' } end
    if s.holder then return { error = 'Quelqu\'un tient déjà ce brancard.' } end
    if s.veh then return { error = 'Le brancard est dans un véhicule : sortez-le d\'abord.' } end
    if ByHolder(src) then return { error = 'Vous tenez déjà un brancard.' } end
    if not Near(src, Ent(s.net), (ST.reach or 3.0) + 1.0) then return { error = 'Le brancard est trop loin.' } end
    s.holder = src
    Publish()
    return { ok = true, message = 'Vous tenez le brancard.' }
end

A.stretcherDrop = function(src, d)
    local s = S[tonumber(d.net)] or ByHolder(src)
    if not s or s.holder ~= src then return { error = 'Vous ne tenez pas ce brancard.' } end
    s.holder = nil
    Publish()
    return { ok = true, message = 'Brancard laissé ici.' }
end

A.stretcherPut = function(src, d)
    local s = S[tonumber(d.net)]
    if not s then return { error = 'Brancard introuvable.' } end
    if s.veh then return { error = 'Le brancard est dans un véhicule : sortez-le d\'abord.' } end
    if s.patient then return { error = 'Il y a déjà quelqu\'un sur ce brancard.' } end
    if not Near(src, Ent(s.net), (ST.reach or 3.0) + 1.0) then return { error = 'Le brancard est trop loin.' } end
    local t, why = Patient(src, d.target)
    if not t then return { error = why } end
    if ByPatient(t) then return { error = 'Le patient est déjà sur un brancard.' } end
    if GetVehiclePedIsIn(GetPlayerPed(t), false) ~= 0 then return { error = 'Le patient est dans un véhicule.' } end
    if Player(t).state.carriedBy or Player(t).state.escortedBy then return { error = 'Le patient est tenu par quelqu\'un.' } end
    if P.escortedBy and P.escortedBy[t] and P.StopEscortBy then P.StopEscortBy(P.escortedBy[t]) end
    s.patient = t
    Player(t).state:set('emsOnStretcher', s.net, true)
    TriggerClientEvent('ems:client:onStretcher', t, s.net)
    Publish()
    return { ok = true, message = ('%s est allongé(e) sur le brancard.'):format(P.Name(t)) }
end

A.stretcherOff = function(src, d)
    local s = S[tonumber(d.net)] or (d.target and ByPatient(tonumber(d.target)))
    if not s or not s.patient then return { error = 'Personne sur ce brancard.' } end
    if s.veh then return { error = 'Sortez d\'abord le brancard du véhicule.' } end
    if not Near(src, Ent(s.net), (ST.reach or 3.0) + 1.0) then return { error = 'Le brancard est trop loin.' } end
    local name = P.Name(s.patient)
    PatientOff(s)
    Publish()
    return { ok = true, message = ('%s descend du brancard.'):format(name) }
end

A.stretcherStore = function(src, d)
    local s = S[tonumber(d.net)]
    if not s then return { error = 'Brancard introuvable.' } end
    if s.patient then return { error = 'Retirez d\'abord le patient du brancard.' } end
    if s.veh then return { error = 'Sortez d\'abord le brancard du véhicule.' } end
    if s.holder and s.holder ~= src then return { error = 'Quelqu\'un tient ce brancard.' } end
    if not Near(src, Ent(s.net), (ST.reach or 3.0) + 1.0) then return { error = 'Le brancard est trop loin.' } end
    Remove(s.net)
    Publish()
    return { ok = true, message = 'Brancard rangé.' }
end

A.stretcherLoad = function(src, d)
    local s = ByHolder(src)
    if not s then return { error = 'Vous ne tenez pas de brancard.' } end
    local vnet = tonumber(d.veh)
    local veh = Ent(vnet)
    if not veh or GetEntityType(veh) ~= 2 then return { error = 'Véhicule introuvable.' } end
    if not Near(src, veh, (VH.reach or 6.0) + 1.0) then return { error = 'Le véhicule est trop loin.' } end
    if ByVeh(vnet) then return { error = 'Il y a déjà un brancard dans ce véhicule.' } end
    s.veh, s.holder = vnet, nil
    Publish()
    if s.patient then P.AddTreatment(s.patient, 'transport', src) end
    return { ok = true, message = s.patient and 'Brancard et patient chargés dans le véhicule.' or 'Brancard chargé dans le véhicule.' }
end

A.stretcherUnload = function(src, d)
    local vnet = tonumber(d.veh)
    local s = vnet and ByVeh(vnet)
    if not s then return { error = 'Pas de brancard dans ce véhicule.' } end
    if ByHolder(src) then return { error = 'Vous tenez déjà un brancard.' } end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return { error = 'Sortez du véhicule.' } end
    if not Near(src, Ent(vnet), (VH.reach or 6.0) + 1.0) then return { error = 'Le véhicule est trop loin.' } end
    s.veh, s.holder = nil, src
    Publish()
    return { ok = true, message = 'Brancard sorti du véhicule : vous le tenez.' }
end

for name, fn in pairs(A) do P.Actions[name] = { perm = 'escort', duty = true, fn = fn } end

-- Déconnexions : le brancard reste où il est ; un patient qui part est retiré
AddEventHandler('playerDropped', function()
    local src = source
    local changed = false
    for _, s in pairs(S) do
        if s.holder == src then s.holder = nil changed = true end
        if s.patient == src then s.patient = nil changed = true end
    end
    if changed then Publish() end
end)

-- Brancard disparu (propriétaire parti sans relais, suppression externe…) : on oublie, le patient descend
CreateThread(function()
    while true do
        Wait(3000)
        local changed = false
        for net, s in pairs(S) do
            if not Ent(net) then
                if s.patient and GetPlayerName(s.patient) then
                    Player(s.patient).state:set('emsOnStretcher', nil, true)
                    TriggerClientEvent('ems:client:offStretcher', s.patient, net, nil)
                end
                S[net] = nil
                changed = true
            end
        end
        if changed then Publish() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for net in pairs(S) do Remove(net) end
end)

Publish()

-- ---------------------------------------------------------------------
-- Fauteuil roulant : objet de l'inventaire (pas consommé)
-- ---------------------------------------------------------------------
local WC = Config.Wheelchair or {}
local function RegisterWheelchair()
    local ok, err = pcall(function()
        exports.elyzea_inventory:RegisterUsableItem(WC.item or 'wheelchair', function(src)
            TriggerClientEvent('ems:client:wheelchair', src)
            return false
        end)
    end)
    if not ok then print(('^1[EMS] Fauteuil roulant : %s^0'):format(tostring(err))) end
end
if WC.enabled ~= false then
    CreateThread(function()
        local t = GetGameTimer() + 60000
        while GetResourceState('elyzea_inventory') ~= 'started' and GetGameTimer() < t do Wait(500) end
        if GetResourceState('elyzea_inventory') == 'started' then RegisterWheelchair() end
    end)
    -- inventaire redémarré : on réenregistre l'objet
    AddEventHandler('onResourceStart', function(res)
        if res == 'elyzea_inventory' then SetTimeout(1000, RegisterWheelchair) end
    end)
end
