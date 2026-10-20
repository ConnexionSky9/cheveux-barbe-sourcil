-- =====================================================================
--  ELYZEA PRESSE - serveur : locaux de la rédaction (points placés en jeu),
--  véhicules de service, coffre, vestiaire et présentoirs du journal.
--  · Même fonctionnement que le garage de service du mécano (elyzea_meca/server/garage.lua) :
--    la direction (permission « points_manage ») place les points à SA position depuis la tablette.
--  · Points par rédaction : garage, spawn (place de sortie), stash (coffre), gear (matériel),
--    wardrobe (vestiaire). Présentoirs (kiosks) : ouverts à tous, pour lire le journal.
--  · Véhicules créés par le serveur, clés données par elyzea_core ; rangement sans doublon.
--  · Vestiaire : la tenue de service n'est pas un objet. Le serveur pose le state bag
--    « elyUniform » (lu par elyzea_clothing pour bloquer les échanges de vêtements-objets
--    pendant le service) ; « Tenue personnelle » remet les vêtements d'avant.
-- =====================================================================
local P = Presse
local core = exports.elyzea_core
local G = Config.Garage
local STASH = 'presse_stash'

local VTYPES = { automobile = true, heli = true, bike = true, boat = true, plane = true }
local KINDS = { garage = 'Véhicules de service', spawn = 'Place de sortie', stash = 'Coffre de la rédaction', gear = 'Matériel', wardrobe = 'Vestiaire' }

P.vehicles = {}   -- [netId] = { src, cid, model, job }

-- Réglages propres à chaque rédaction (la première garde la clé « points »)
local function Key(job) return (not job or job == Config.Job.name) and 'points' or ('points:' .. job) end
local function StashOf(job) return (not job or job == Config.Job.name) and STASH or (STASH .. '_' .. job) end

function P.PointsOf(job)
    local s = P.GetSetting(Key(job), {})
    local vehicles = {}
    for _, v in ipairs(type(s.vehicles) == 'table' and s.vehicles or G.vehicles) do
        vehicles[#vehicles + 1] = { model = tostring(v.model), label = tostring(v.label or v.model), minLevel = tonumber(v.minLevel) or 1,
            type = VTYPES[v.type] and v.type or 'automobile' }
    end
    local kiosks = {}
    for _, k in ipairs(type(s.kiosks) == 'table' and s.kiosks or {}) do kiosks[#kiosks + 1] = k end
    return { garage = s.garage, spawn = s.spawn, stash = s.stash, gear = s.gear, wardrobe = s.wardrobe, vehicles = vehicles, kiosks = kiosks,
        outfits = type(s.outfits) == 'table' and s.outfits or {} }
end

function P.NearPoint(src, kind, radius)
    local pts = P.PointsOf(P.MyJob(src))
    local p = pts[kind]
    if not p then return false end
    local c = P.Coords(src)
    return c ~= nil and #(c - vector3(p.x, p.y, p.z)) <= radius
end

-- Présentoirs de toutes les rédactions
function P.KioskList()
    local out = {}
    for _, a in ipairs(P.agencyList) do
        for _, k in ipairs(P.PointsOf(a.job).kiosks) do out[#out + 1] = { x = k.x, y = k.y, z = k.z, label = k.label, job = a.job, agency = a.label } end
    end
    return out
end

-- Points publics (marqueurs côté client) : { [métier de la rédaction] = points }
local function Publish()
    local all = {}
    for _, a in ipairs(P.agencyList) do
        local s = P.PointsOf(a.job)
        all[a.job] = { garage = s.garage, spawn = s.spawn, stash = s.stash, gear = s.gear, wardrobe = s.wardrobe }
        if s.stash and GetResourceState('elyzea_inventory') == 'started' then
            pcall(function()
                exports.elyzea_inventory:RegisterStash(StashOf(a.job), ('Coffre · %s'):format(a.label), Config.Stash.slots, Config.Stash.weight, nil,
                    { [a.job] = 0 }, vector3(s.stash.x, s.stash.y, s.stash.z))
            end)
        end
    end
    GlobalState.pressePoints = all
    GlobalState.presseKiosks = P.KioskList()
end
P.AfterAgencies = P.AfterAgencies or {}
P.AfterAgencies[#P.AfterAgencies + 1] = Publish
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = Publish
-- Redémarrage de la ressource : le client a remis les vêtements d'avant, le blocage est levé
P.OnReady[#P.OnReady + 1] = function()
    for _, s in ipairs(GetPlayers()) do
        local id = tonumber(s)
        if Player(id).state.elyUniform == 'presse' then Player(id).state:set('elyUniform', nil, true) end
    end
end
AddEventHandler('onResourceStart', function(res) if res == 'elyzea_inventory' and P.ready then SetTimeout(2000, Publish) end end)

local function Save(src, s)
    P.SetSetting(Key(P.MyJob(src)), s)
    Publish()
end

local function Levels(src)
    local l = {}
    for _, g in ipairs(P.SortedGrades(P.MyJob(src))) do l[#l + 1] = { level = g.level, name = g.name } end
    return l
end

-- ---------------------------------------------------------------------
-- Réglages (tablette › Locaux)
-- ---------------------------------------------------------------------
P.Actions.pointsSettings = { perm = 'points_manage', fn = function(src)
    local s = P.PointsOf(P.MyJob(src))
    local outfits = {}
    for _, slot in ipairs(Config.Wardrobe.slots) do
        local o = s.outfits[slot.id] or {}
        outfits[#outfits + 1] = { id = slot.id, label = slot.label, minLevel = slot.minLevel, male = o.male ~= nil, female = o.female ~= nil }
    end
    return { settings = { garage = s.garage, spawn = s.spawn, stash = s.stash, gear = s.gear, wardrobe = s.wardrobe, vehicles = s.vehicles, kiosks = s.kiosks },
        outfits = outfits, levels = Levels(src), kinds = KINDS, maxKiosks = Config.Points.maxKiosks }
end }

P.Actions.pointSet = { perm = 'points_manage', fn = function(src, d)
    local kind = tostring(d.kind or '')
    if not KINDS[kind] then return { error = 'Point inconnu.' } end
    local s = P.GetSetting(Key(P.MyJob(src)), {})
    if d.remove == true then
        s[kind] = nil
    else
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        s[kind] = { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100, h = math.floor(GetEntityHeading(ped)) }
    end
    Save(src, s)
    P.AddLog(src, nil, nil, d.remove and 'Point retiré' or 'Point placé', nil, KINDS[kind], nil)
    return { ok = true, message = d.remove and ('%s retiré.'):format(KINDS[kind]) or ('%s placé à votre position.'):format(KINDS[kind]) }
end }

P.Actions.kioskAdd = { perm = 'points_manage', fn = function(src, d)
    local s = P.GetSetting(Key(P.MyJob(src)), {})
    s.kiosks = type(s.kiosks) == 'table' and s.kiosks or {}
    if #s.kiosks >= Config.Points.maxKiosks then return { error = ('%d présentoirs au maximum.'):format(Config.Points.maxKiosks) } end
    local c = GetEntityCoords(GetPlayerPed(src))
    local label = P.Clean(tostring(d.label or ''):gsub('%c', ' '), 40)
    s.kiosks[#s.kiosks + 1] = { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100, label = label ~= '' and label or 'Présentoir' }
    Save(src, s)
    P.AddLog(src, nil, nil, 'Présentoir ajouté', nil, nil, label)
    return { ok = true, message = 'Présentoir du journal placé à votre position.' }
end }

P.Actions.kioskRemove = { perm = 'points_manage', fn = function(src, d)
    local s = P.GetSetting(Key(P.MyJob(src)), {})
    local i = tonumber(d.i)
    if type(s.kiosks) ~= 'table' or not i or not s.kiosks[i] then return { error = 'Présentoir introuvable.' } end
    table.remove(s.kiosks, i)
    Save(src, s)
    return { ok = true, message = 'Présentoir retiré.' }
end }

P.Actions.garageVehicles = { perm = 'points_manage', fn = function(src, d)
    local list = {}
    for _, v in ipairs(type(d.vehicles) == 'table' and d.vehicles or {}) do
        local model = tostring(v.model or ''):lower():gsub('[^%w_]', ''):sub(1, 30)
        if model ~= '' then
            list[#list + 1] = { model = model, label = P.Clean(v.label ~= '' and v.label or model, 40), minLevel = P.Int(v.minLevel, 0, 99, 1),
                type = VTYPES[v.type] and v.type or 'automobile' }
        end
        if #list >= 30 then break end
    end
    if #list == 0 then return { error = 'Gardez au moins un véhicule.' } end
    local s = P.GetSetting(Key(P.MyJob(src)), {})
    s.vehicles = list
    Save(src, s)
    P.AddLog(src, nil, nil, 'Véhicules du garage', nil, nil, ('%d modèle(s)'):format(#list))
    return { ok = true, message = 'Véhicules enregistrés.' }
end }

-- ---------------------------------------------------------------------
-- Véhicules de service : sortir / ranger
-- ---------------------------------------------------------------------
P.Actions.garageList = { perm = 'garage', duty = true, fn = function(src)
    local s = P.PointsOf(P.MyJob(src))
    if not P.NearPoint(src, 'garage', 4.0) then return { error = 'Vous n\'êtes pas au point des véhicules de service.' } end
    local my = P.Grade(src).level
    local list = {}
    for i, v in ipairs(s.vehicles) do list[#list + 1] = { i = i, label = v.label, model = v.model, locked = my < v.minLevel, minLevel = v.minLevel } end
    return { list = list }
end }

local lastSpawn = {}
P.Actions.garageSpawn = { perm = 'garage', duty = true, fn = function(src, d)
    local s = P.PointsOf(P.MyJob(src))
    if not P.NearPoint(src, 'garage', 4.0) then return { error = 'Vous n\'êtes pas au point des véhicules de service.' } end
    if not s.spawn then return { error = 'La direction n\'a pas encore placé la place de sortie.' } end
    local v = s.vehicles[tonumber(d.i) or 0]
    if not v then return { error = 'Véhicule inconnu.' } end
    if P.Grade(src).level < v.minLevel then return { error = 'Votre grade ne permet pas de sortir ce véhicule.' } end
    local now = os.time()
    if lastSpawn[src] and now - lastSpawn[src] < 10 then return { error = 'Patientez quelques secondes.' } end
    local sp = vector3(s.spawn.x, s.spawn.y, s.spawn.z)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - sp) < 3.0 then return { error = 'La place de sortie est occupée.' } end
    end
    lastSpawn[src] = now
    local veh = CreateVehicleServerSetter(joaat(v.model), v.type, sp.x, sp.y, sp.z, (s.spawn.h or 0) + 0.0)
    local t = GetGameTimer()
    while not DoesEntityExist(veh) and GetGameTimer() - t < 4000 do Wait(10) end
    if not DoesEntityExist(veh) then return { error = ('Le modèle « %s » n\'existe pas sur ce serveur.'):format(v.model) } end
    local plate = ('%s%04d'):format(G.platePrefix:sub(1, 4), math.random(0, 9999))
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('presseVehicle', P.MyJob(src), true)
    pcall(function() core:GiveKeys(src, veh) end)
    local net = NetworkGetNetworkIdFromEntity(veh)
    P.vehicles[net] = { src = src, cid = P.Cid(src), model = v.model, job = P.MyJob(src) }
    SetTimeout(300, function() if DoesEntityExist(veh) then SetPedIntoVehicle(GetPlayerPed(src), veh, -1) end end)
    P.Log(src, 'Véhicule sorti', ('%s · %s'):format(v.label, plate))
    return { ok = true, message = ('%s sorti · %s.'):format(v.label, plate) }
end }

P.Actions.garageStore = { perm = 'garage', fn = function(src, d)
    if not P.NearPoint(src, 'garage', G.storeRadius + 4.0) and not P.NearPoint(src, 'spawn', G.storeRadius + 4.0) then
        return { error = 'Rangez le véhicule au point des véhicules de service.' }
    end
    local veh = NetworkGetEntityFromNetworkId(tonumber(d.net) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return { error = 'Véhicule introuvable.' } end
    if not Entity(veh).state.presseVehicle then return { error = 'Ce n\'est pas un véhicule de la rédaction.' } end
    if #(GetEntityCoords(veh) - P.Coords(src)) > G.storeRadius + 2.0 then return { error = 'Le véhicule est trop loin.' } end
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and ped ~= GetPlayerPed(src) then return { error = 'Quelqu\'un est encore dans le véhicule.' } end
    end
    P.vehicles[tonumber(d.net)] = nil
    DeleteEntity(veh)
    return { ok = true, message = 'Véhicule rangé.' }
end }

-- ---------------------------------------------------------------------
-- Coffre de la rédaction
-- ---------------------------------------------------------------------
RegisterNetEvent('presse:server:stash', function()
    local src = source
    if not P.IsPresse(src) or not P.OnDuty(src) or not P.Can(src, 'stash') then return P.Notify(src, 'Coffre réservé aux journalistes en service autorisés.', 'error') end
    if not P.NearPoint(src, 'stash', 3.0) then return end
    if GetResourceState('elyzea_inventory') ~= 'started' then return P.Notify(src, 'Inventaire indisponible.', 'error') end
    local ok, done = pcall(function() return exports.elyzea_inventory:OpenInventory(src, 'stash', StashOf(P.MyJob(src))) end)
    if not ok or not done then P.Notify(src, 'Coffre indisponible.', 'error') end
end)

-- ---------------------------------------------------------------------
-- Vestiaire
-- ---------------------------------------------------------------------
local SLOTS, PIECE_IDS = {}, {}
for _, s in ipairs(Config.Wardrobe.slots) do SLOTS[s.id] = s end
for _, c in ipairs(Config.ClothingSlots) do PIECE_IDS[c.id] = true end

local function SexOf(src)
    local m = GetEntityModel(GetPlayerPed(src))
    if m == `mp_m_freemode_01` then return 'male' end
    if m == `mp_f_freemode_01` then return 'female' end
end

-- Pièces reçues du client (enregistrement d'une tenue) : nombres propres, collection de pack gardée
local function CleanPieces(raw)
    if type(raw) ~= 'table' then return nil end
    local out, n = {}, 0
    for id in pairs(PIECE_IDS) do
        local p = raw[id]
        if type(p) == 'table' and tonumber(p.drawable) then
            local piece = { drawable = math.max(-1, math.min(10000, math.floor(tonumber(p.drawable)))), texture = math.max(0, math.min(500, math.floor(tonumber(p.texture) or 0))) }
            if type(p.col) == 'string' and p.col ~= '' and #p.col <= 64 and tonumber(p.li) then
                piece.col, piece.li = p.col:lower():gsub('[^%w_%-]', ''), math.max(0, math.floor(tonumber(p.li)))
            end
            out[id] = piece
            n = n + 1
        end
    end
    return n > 0 and out or nil
end

P.Actions.wardrobeList = { perm = 'wardrobe', duty = true, fn = function(src)
    if not P.NearPoint(src, 'wardrobe', 3.0) then return { error = 'Vous n\'êtes pas au vestiaire de la rédaction.' } end
    local sex = SexOf(src)
    local s = P.PointsOf(P.MyJob(src))
    local lvl = P.Grade(src).level
    local list = {}
    for _, slot in ipairs(Config.Wardrobe.slots) do
        local o = s.outfits[slot.id]
        list[#list + 1] = { id = slot.id, label = slot.label, minLevel = slot.minLevel, locked = lvl < slot.minLevel, ready = sex ~= nil and o ~= nil and o[sex] ~= nil }
    end
    return { list = list, wearing = Player(src).state.elyUniform == 'presse', sex = sex }
end }

P.Actions.wardrobeWear = { perm = 'wardrobe', duty = true, fn = function(src, d)
    if not P.NearPoint(src, 'wardrobe', 3.0) then return { error = 'Vous n\'êtes pas au vestiaire.' } end
    local slot = SLOTS[tostring(d.id or '')]
    if not slot then return { error = 'Tenue inconnue.' } end
    if P.Grade(src).level < slot.minLevel then return { error = 'Votre grade ne donne pas accès à cette tenue.' } end
    local sex = SexOf(src)
    if not sex then return { error = 'Personnage non compatible (homme ou femme du jeu).' } end
    local o = P.PointsOf(P.MyJob(src)).outfits[slot.id]
    if not o or not o[sex] then return { error = 'Cette tenue n\'a pas encore été enregistrée par la direction pour ce sexe.' } end
    Player(src).state:set('elyUniform', 'presse', true)
    return { ok = true, pieces = o[sex], label = slot.label }
end }

-- Retour à la tenue personnelle : le client remet ses vêtements d'avant, le serveur lève le blocage
function P.TakeOffUniform(src)
    if Player(src).state.elyUniform == 'presse' then
        Player(src).state:set('elyUniform', nil, true)
        TriggerClientEvent('presse:client:civil', src)
    end
end
P.Actions.wardrobeCivil = { perm = nil, fn = function(src)
    if Player(src).state.elyUniform ~= 'presse' then return { error = 'Vous ne portez pas de tenue de service.' } end
    P.TakeOffUniform(src)
    return { ok = true, message = 'Vous avez remis votre tenue personnelle.' }
end }

-- La direction enregistre la tenue qu'elle porte comme tenue de la rédaction
P.Actions.outfitCapture = { perm = 'points_manage', fn = function(src, d)
    local slot = SLOTS[tostring(d.id or '')]
    if not slot then return { error = 'Tenue inconnue.' } end
    local sex = SexOf(src)
    if not sex then return { error = 'Personnage non compatible.' } end
    local pieces = CleanPieces(d.pieces)
    if not pieces then return { error = 'Tenue illisible : réessayez.' } end
    local s = P.GetSetting(Key(P.MyJob(src)), {})
    s.outfits = type(s.outfits) == 'table' and s.outfits or {}
    s.outfits[slot.id] = type(s.outfits[slot.id]) == 'table' and s.outfits[slot.id] or {}
    s.outfits[slot.id][sex] = pieces
    Save(src, s)
    P.AddLog(src, nil, nil, 'Tenue enregistrée', nil, slot.label, sex == 'male' and 'homme' or 'femme')
    return { ok = true, message = ('« %s » (%s) enregistrée à partir de votre tenue.'):format(slot.label, sex == 'male' and 'homme' or 'femme') }
end }

P.Actions.outfitClear = { perm = 'points_manage', fn = function(src, d)
    local slot = SLOTS[tostring(d.id or '')]
    local sex = d.sex == 'female' and 'female' or 'male'
    if not slot then return { error = 'Tenue inconnue.' } end
    local s = P.GetSetting(Key(P.MyJob(src)), {})
    if type(s.outfits) == 'table' and type(s.outfits[slot.id]) == 'table' then s.outfits[slot.id][sex] = nil end
    Save(src, s)
    return { ok = true, message = 'Tenue effacée.' }
end }

-- Fin de service ou départ de la rédaction : tenue personnelle remise
local setDuty = P.SetDuty
P.SetDuty = function(src, on, ...)
    setDuty(src, on, ...)
    if not on and Config.Wardrobe.restoreOnDutyOff then P.TakeOffUniform(src) end
end
local push = P.PushState
P.PushState = function(src, ...)
    local r = push(src, ...)
    if GetPlayerName(src) and not P.IsPresse(src) and Player(src).state.elyUniform == 'presse' then P.TakeOffUniform(src) end
    return r
end

AddEventHandler('playerDropped', function() lastSpawn[source] = nil end)
