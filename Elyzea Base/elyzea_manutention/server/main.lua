-- =====================================================================
--  ELYZEA MANUTENTION - SERVEUR
--  · Réglages : valeurs de config.lua, remplacées par celles du menu admin (table manut_settings)
--  · Missions : une par joueur, machine à états vérifiée ICI (le client ne fait qu'afficher et demander)
--      collect (cartons) → ready (palette complète) → carry (palette sur le Fenwick) → livraison payée → collect
--  · Sécurité : positions lues par le serveur, distances, étapes, nombre exact de cartons, Fenwick du joueur,
--    un seul paiement par livraison, cadence minimale, nettoyage à la déconnexion.
--  · Le métier principal du joueur n'est JAMAIS modifié (intérim en complément).
-- =====================================================================
local RES = GetCurrentResourceName()
Manut = { settings = nil, ready = false }
local S                       -- réglages en vigueur
local M = {}                  -- [src] = mission
local lastAction = {}         -- [src] = { [nom] = GetGameTimer() } : anti-flood
local nextMissionId = 0

-- ---------------------------------------------------------------- utilitaires
local function now() return os.time() end
local function deepcopy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepcopy(v) end
    return o
end
local function num(v, def, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if lo and v < lo then v = lo end
    if hi and v > hi then v = hi end
    return v
end
local function int(v, def, lo, hi) local n = num(v, def, lo, hi) return n and math.floor(n) end
local function bool(v, def) if v == nil then return def end return v == true or v == 1 or v == '1' or v == 'true' end
local function str(v, max, def)
    v = tostring(v or ''):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return def end
    return v:sub(1, max or 40)
end
local function model(v, def)
    v = tostring(v or ''):lower():gsub('[^%w_]', '')
    if v == '' or #v > 48 then return def end
    return v
end
local function notify(src, msg, kind, title) pcall(function() exports.elyzea_core:Notify(src, msg, kind or 'inform', 6000, title) end) end
local function coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped), GetEntityHeading(ped), ped
end
local function dist(a, b) return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z)) end
local function dist2(a, b) local dx, dy = a.x - b.x, a.y - b.y return math.sqrt(dx * dx + dy * dy) end
local function flood(src, name, ms)
    lastAction[src] = lastAction[src] or {}
    local t = GetGameTimer()
    if lastAction[src][name] and t - lastAction[src][name] < ms then return true end
    lastAction[src][name] = t
    return false
end
local function cidOf(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    return ok and type(pd) == 'table' and pd.citizenid or nil
end
local function nameOf(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    local ci = ok and type(pd) == 'table' and pd.charinfo or {}
    local n = (tostring(ci.firstname or '') .. ' ' .. tostring(ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or (GetPlayerName(src) or ('#' .. src))
end
local function log(msg) print(('^5[Manutention]^0 %s'):format(msg)) end

-- ---------------------------------------------------------------- réglages
local function point(p, withRadius)
    if type(p) ~= 'table' then return nil end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not x or not y or not z or math.abs(x) > 20000 or math.abs(y) > 20000 or z < -500 or z > 3000 then return nil end
    local o = { x = x + 0.0, y = y + 0.0, z = z + 0.0, h = num(p.h, 0.0, -360, 720) % 360, label = str(p.label, 40, nil) }
    if withRadius then o.radius = num(p.radius, Config.DeliveryRadius, 1.5, 25.0) end
    return o
end
local function points(list, withRadius, max)
    local out = {}
    for _, p in ipairs(type(list) == 'table' and list or {}) do
        local q = point(p, withRadius)
        if q then out[#out + 1] = q end
        if #out >= (max or 64) then break end
    end
    return out
end
local function outfitPart(o)
    local out = { c = {}, p = {} }
    if type(o) ~= 'table' then return out end
    for k, v in pairs(type(o.c) == 'table' and o.c or {}) do
        local slot = tonumber(k)
        if slot and slot >= 0 and slot <= 11 and type(v) == 'table' then
            local e = { int(v[1], 0, -1, 4000), int(v[2], 0, 0, 255) }
            if type(v.col) == 'string' and #v.col <= 64 then e.col, e.li = v.col, int(v.li, nil, 0, 4000) end
            out.c[tostring(slot)] = e
        end
    end
    for k, v in pairs(type(o.p) == 'table' and o.p or {}) do
        local slot = tonumber(k)
        if slot and slot >= 0 and slot <= 7 and type(v) == 'table' then
            local e = { int(v[1], -1, -1, 4000), int(v[2], 0, 0, 255) }
            if type(v.col) == 'string' and #v.col <= 64 then e.col, e.li = v.col, int(v.li, nil, 0, 4000) end
            out.p[tostring(slot)] = e
        end
    end
    return out
end

-- Réglages complets et valides (toute valeur absente ou fausse reprend celle de config.lua)
function Manut.Sanitize(raw)
    local D = Config.Defaults
    raw = type(raw) == 'table' and raw or {}
    local pay, P0 = type(raw.pay) == 'table' and raw.pay or {}, D.pay
    local mo, M0 = type(raw.models) == 'table' and raw.models or {}, D.models
    local npc, N0 = type(raw.npc) == 'table' and raw.npc or {}, D.npc
    local fk, F0 = type(raw.forklift) == 'table' and raw.forklift or {}, D.forklift
    local out = {
        enabled = bool(raw.enabled, D.enabled),
        boxesPerPallet = int(raw.boxesPerPallet, D.boxesPerPallet, 1, Config.MaxBoxes),
        allowSprint = bool(raw.allowSprint, D.allowSprint),
        account = (raw.account == 'cash' or raw.account == 'bank') and raw.account or D.account,
        pay = {
            delivery = int(pay.delivery, P0.delivery, 0, Config.MaxPay),
            perBox = int(pay.perBox, P0.perBox, 0, Config.MaxPay), perBoxOn = bool(pay.perBoxOn, P0.perBoxOn),
            palletDone = int(pay.palletDone, P0.palletDone, 0, Config.MaxPay), palletDoneOn = bool(pay.palletDoneOn, P0.palletDoneOn),
            transport = int(pay.transport, P0.transport, 0, Config.MaxPay), transportOn = bool(pay.transportOn, P0.transportOn),
        },
        models = {
            npc = model(mo.npc, M0.npc), box = model(mo.box, M0.box), boxOnPallet = model(mo.boxOnPallet, M0.boxOnPallet),
            pallet = model(mo.pallet, M0.pallet), forklift = model(mo.forklift, M0.forklift),
        },
        npc = { enabled = bool(npc.enabled, N0.enabled), scenario = str(npc.scenario, 60, N0.scenario), placed = false },
        forklift = {
            enabled = bool(fk.enabled, F0.enabled), max = int(fk.max, F0.max, 0, 64), idleMinutes = int(fk.idleMinutes, F0.idleMinutes, 0, 240),
        },
        pickups = points(raw.pickups or D.pickups, false, 64),
        pallets = points(raw.pallets or D.pallets, false, 32),
        spawns = points(raw.spawns or D.spawns, false, 32),
        deliveries = points(raw.deliveries or D.deliveries, true, 32),
        outfit = { male = outfitPart((raw.outfit or {}).male or D.outfit.male), female = outfitPart((raw.outfit or {}).female or D.outfit.female) },
    }
    if out.npc.scenario == 'aucun' or out.npc.scenario == 'none' then out.npc.scenario = '' end
    local np = point(npc) or point(N0)
    if np and (npc.placed == true or N0.placed == true) then
        out.npc.x, out.npc.y, out.npc.z, out.npc.h, out.npc.placed = np.x, np.y, np.z, np.h, true
    else
        out.npc.x, out.npc.y, out.npc.z, out.npc.h = 0.0, 0.0, 0.0, 0.0
    end
    return out
end

-- Ce que les joueurs reçoivent (pas les points de spawn, pas la tenue)
local function publicView()
    return {
        enabled = S.enabled, boxesPerPallet = S.boxesPerPallet, allowSprint = S.allowSprint, models = S.models,
        npc = S.npc, pickups = S.pickups, pallets = S.pallets, deliveries = S.deliveries, forklift = { enabled = S.forklift.enabled },
        pay = { delivery = S.pay.delivery, account = S.account },
    }
end
local function broadcast() TriggerClientEvent('elyzea_manutention:config', -1, publicView()) end

local function dbSave()
    MySQL.query.await('INSERT INTO `manut_settings` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)', { 'config', json.encode(S) })
end
local function dbLoad()
    local row = MySQL.single.await('SELECT `v` FROM `manut_settings` WHERE `k` = ?', { 'config' })
    if not row or type(row.v) ~= 'string' or row.v == '' then return nil end
    local ok, v = pcall(json.decode, row.v)
    return ok and type(v) == 'table' and v or nil
end

function Manut.Load()
    S = Manut.Sanitize(dbLoad())
    Manut.settings = S
    broadcast()
end
function Manut.Save() dbSave() broadcast() end
function Manut.Get() return S end

-- ---------------------------------------------------------------- missions : outils
local function missionView(m)
    if not m then return nil end
    return {
        id = m.id, stage = m.stage, boxes = m.boxes, required = m.required, carrying = m.carrying,
        pallet = m.pallet, delivery = m.delivery, vehNet = m.vehNet, palletNet = m.palletNet,
        delivered = m.delivered, earned = m.earned, payDelivery = S.pay.delivery, allowSprint = S.allowSprint,
    }
end
local function push(src) TriggerClientEvent('elyzea_manutention:mission', src, missionView(M[src])) end

local function entityFromNet(net)
    net = tonumber(net)
    if not net or net <= 0 then return nil end
    local e = NetworkGetEntityFromNetworkId(net)
    if e and e ~= 0 and DoesEntityExist(e) then return e end
end
local function deleteNet(net)
    local e = entityFromNet(net)
    if e then DeleteEntity(e) end
end

local function pay(src, m, amount, why)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return 0 end
    local ok, res = pcall(function() return exports.elyzea_core:AddMoney(src, S.account, amount, 'Intérim manutention : ' .. why) end)
    if not ok or res == false then
        log(('paiement impossible (%s, %d $) pour %s'):format(why, amount, nameOf(src)))
        return 0
    end
    m.earned = (m.earned or 0) + amount
    return amount
end

local function pickFrom(list, avoidIndex)
    if #list == 0 then return nil end
    if #list == 1 then return 1 end
    local i
    repeat i = math.random(1, #list) until i ~= avoidIndex
    return i
end

-- Palette libre : pas déjà utilisée par la mission d'un autre joueur (tant que c'est possible)
local function freePallet(exclude)
    local used = {}
    for s, m in pairs(M) do if s ~= exclude and m.palletIndex then used[m.palletIndex] = true end end
    local free = {}
    for i = 1, #S.pallets do if not used[i] then free[#free + 1] = i end end
    if #free > 0 then return free[math.random(1, #free)] end
    return pickFrom(S.pallets)
end

local function newRound(src, m)
    m.palletIndex = freePallet(src)
    local deliveryIndex = pickFrom(S.deliveries, m.deliveryIndex)
    m.deliveryIndex = deliveryIndex
    m.pallet = m.palletIndex and deepcopy(S.pallets[m.palletIndex]) or nil
    m.delivery = deliveryIndex and deepcopy(S.deliveries[deliveryIndex]) or nil
    m.stage, m.boxes, m.carrying, m.required = 'collect', 0, false, S.boxesPerPallet
    m.round = (m.round or 0) + 1
    m.paid = { box = {}, palletDone = false, transport = false, delivery = false }
    m.palletNet, m.boxNets = nil, {}
    m.last = now()
end

-- Point de spawn libre : aucun véhicule à moins de SpawnFreeRadius, pas réservé par un autre joueur
local function freeSpawn()
    local reserved = {}
    for _, m in pairs(M) do if m.spawnIndex and m.spawnAt and now() - m.spawnAt < 20 then reserved[m.spawnIndex] = true end end
    local order = {}
    for i = 1, #S.spawns do order[i] = i end
    for i = #order, 2, -1 do local j = math.random(1, i) order[i], order[j] = order[j], order[i] end
    local vehicles = GetAllVehicles and GetAllVehicles() or {}
    for _, i in ipairs(order) do
        local sp = S.spawns[i]
        local busy = reserved[i]
        if not busy then
            for _, v in ipairs(vehicles) do
                if DoesEntityExist(v) and dist(GetEntityCoords(v), sp) < Config.SpawnFreeRadius then busy = true break end
            end
        end
        if not busy then return i end
    end
end

local function activeForklifts()
    local n = 0
    for _, m in pairs(M) do if m.veh and DoesEntityExist(m.veh) then n = n + 1 end end
    return n
end

local function spawnForklift(src, m)
    if not S.forklift.enabled then return true end
    if #S.spawns == 0 then return false, 'Aucun emplacement de Fenwick n\'est configuré (menu admin).' end
    local max = S.forklift.max > 0 and S.forklift.max or #S.spawns
    if activeForklifts() >= max then return false, 'Tous les Fenwick sont utilisés. Réessaie dans un instant.' end
    local i = freeSpawn()
    if not i then return false, 'Les emplacements des Fenwick sont tous occupés. Réessaie dans un instant.' end
    local sp = S.spawns[i]
    m.spawnIndex, m.spawnAt = i, now()
    local veh = CreateVehicleServerSetter(joaat(S.models.forklift), 'automobile', sp.x, sp.y, sp.z, sp.h + 0.0)
    local t = GetGameTimer()
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() - t < 4000 do Wait(20) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        return false, ('Le Fenwick (modèle « %s ») n\'a pas pu apparaître.'):format(S.models.forklift)
    end
    local plate = ('INTR%04d'):format(math.random(0, 9999))
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('manutForklift', src, true)
    m.veh, m.vehNet, m.plate = veh, NetworkGetNetworkIdFromEntity(veh), plate
    pcall(function() exports.elyzea_core:GiveKeys(src, veh) end)
    return true
end

-- Fin de mission : tout ce qui appartient au joueur disparaît (Fenwick, palette, cartons empilés)
local function cleanup(src, m)
    m = m or M[src]
    if not m then return end
    if m.veh and DoesEntityExist(m.veh) then
        pcall(function() exports.elyzea_core:RemoveKeys(src, m.veh) end)
        DeleteEntity(m.veh)
    end
    deleteNet(m.palletNet)
    for _, n in ipairs(m.boxNets or {}) do deleteNet(n) end
    M[src] = nil
end

-- ---------------------------------------------------------------- actions des joueurs
local A = {}

function A.accept(src)
    if not S.enabled then return false, 'Le métier de manutentionnaire est fermé pour le moment.' end
    if M[src] then return false, 'Tu travailles déjà.' end
    local c = coords(src)
    if not c or not S.npc.placed or dist(c, S.npc) > Config.NpcDistance + 1.0 then return false, 'Approche-toi du responsable de l\'entrepôt.' end
    if #S.pickups == 0 or #S.pallets == 0 or #S.deliveries == 0 then
        return false, 'L\'entrepôt n\'est pas encore prêt (emplacements à placer dans le menu admin).'
    end
    local cid = cidOf(src)
    if not cid then return false, 'Personnage introuvable.' end
    nextMissionId = nextMissionId + 1
    local m = { id = ('%d-%d'):format(now(), nextMissionId), cid = cid, earned = 0, delivered = 0, started = now() }
    newRound(src, m)
    local ok, why = spawnForklift(src, m)
    if not ok then return false, why end
    M[src] = m
    log(('%s a commencé (Fenwick %s)'):format(nameOf(src), m.plate or 'aucun'))
    return true, 'Travail accepté : récupère les cartons et constitue ta palette.', { outfit = S.outfit }
end

function A.finish(src, reason)
    local m = M[src]
    if not m then return false, 'Tu ne travailles pas.' end
    local earned, delivered = m.earned or 0, m.delivered or 0
    cleanup(src, m)
    TriggerClientEvent('elyzea_manutention:ended', src, { earned = earned, delivered = delivered, reason = reason })
    return true, ('Travail terminé. %d palette(s) livrée(s), %d $ gagnés.'):format(delivered, earned)
end

function A.pickup(src, data)
    local m = M[src]
    if not m then return false end
    if m.stage ~= 'collect' then return false, 'Ta palette est complète : charge-la avec le Fenwick.' end
    if m.carrying then return false, 'Tu portes déjà un carton.' end
    if m.boxes >= m.required then return false, 'La palette est déjà complète.' end
    local p = S.pickups[int(data and data.point, 0)]
    local c = coords(src)
    if not p or not c or dist(c, p) > Config.PickupDistance + 0.5 then return false, 'Tu es trop loin du stock de cartons.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'Descends du véhicule.' end
    m.carrying, m.last, m.pickedAt = true, now(), GetGameTimer()
    return true
end

function A.drop(src)
    local m = M[src]
    if not m then return false end
    if m.stage ~= 'collect' or not m.carrying then return false, 'Tu n\'as pas de carton.' end
    if m.boxes >= m.required then return false, 'La palette est déjà complète.' end
    local c = coords(src)
    if not c or not m.pallet or dist(c, m.pallet) > Config.PalletDistance + 0.5 then return false, 'Approche-toi de ta palette.' end
    local t = GetGameTimer()
    if m.lastBoxAt and t - m.lastBoxAt < Config.MinBoxInterval then return false, 'Doucement.' end
    if m.pickedAt and t - m.pickedAt < 800 then return false, 'Doucement.' end
    m.lastBoxAt = t
    m.carrying, m.last = false, now()
    m.boxes = m.boxes + 1
    if S.pay.perBoxOn and S.pay.perBox > 0 and not m.paid.box[m.boxes] then
        m.paid.box[m.boxes] = true
        pay(src, m, S.pay.perBox, 'carton déposé')
    end
    if m.boxes >= m.required then
        m.stage = 'ready'
        if S.pay.palletDoneOn and S.pay.palletDone > 0 and not m.paid.palletDone then
            m.paid.palletDone = true
            pay(src, m, S.pay.palletDone, 'palette complète')
        end
    end
    return true
end

-- Le Fenwick du joueur, conduit par lui
local function driving(src, m)
    if not m.veh or not DoesEntityExist(m.veh) then return nil, 'Ton Fenwick a disparu : demande-en un autre au responsable.' end
    local ped = GetPlayerPed(src)
    if GetPedInVehicleSeat(m.veh, -1) ~= ped then return nil, 'Monte sur TON Fenwick (place du conducteur).' end
    return m.veh
end

function A.lift(src)
    local m = M[src]
    if not m then return false end
    if m.stage == 'collect' then return false, ('Palette incomplète : %d/%d cartons.'):format(m.boxes, m.required) end
    if m.stage ~= 'ready' then return false, 'La palette est déjà chargée.' end
    if not S.forklift.enabled then return false, 'Les Fenwick sont désactivés par l\'administration.' end
    local veh, why = driving(src, m)
    if not veh then return false, why end
    local vc = GetEntityCoords(veh)
    local pal = m.pallet
    local pe = entityFromNet(m.palletNet)
    if pe then pal = GetEntityCoords(pe) end
    if dist2(vc, pal) > Config.ForkDistance + 1.2 or math.abs(vc.z - pal.z) > 2.5 then return false, 'Place les fourches sous la palette.' end
    m.stage, m.last = 'carry', now()
    if S.pay.transportOn and S.pay.transport > 0 and not m.paid.transport then
        m.paid.transport = true
        pay(src, m, S.pay.transport, 'transport')
    end
    return true
end

function A.unload(src)
    -- Palette reposée hors de la zone de livraison : elle redevient « à charger » à sa nouvelle place
    local m = M[src]
    if not m or m.stage ~= 'carry' then return false end
    local pe = entityFromNet(m.palletNet)
    local veh = m.veh and DoesEntityExist(m.veh) and m.veh
    local p = pe and GetEntityCoords(pe) or (veh and GetEntityCoords(veh))
    if p then m.pallet = { x = p.x, y = p.y, z = p.z, h = pe and GetEntityHeading(pe) or (m.pallet and m.pallet.h) or 0.0 } end
    m.stage, m.last = 'ready', now()
    return true
end

function A.deliver(src)
    local m = M[src]
    if not m then return false end
    if m.stage ~= 'carry' then return false, m.stage == 'collect' and ('Palette incomplète : %d/%d cartons.'):format(m.boxes, m.required) or 'Charge d\'abord la palette.' end
    if m.boxes ~= m.required then return false, 'Le nombre de cartons ne correspond pas.' end
    if m.paid.delivery then return false, 'Cette livraison a déjà été payée.' end
    local veh, why = driving(src, m)
    if not veh then return false, why end
    local d = m.delivery
    if not d then return false, 'Aucun point de livraison.' end
    local vc = GetEntityCoords(veh)
    local pe = entityFromNet(m.palletNet)
    local pc = pe and GetEntityCoords(pe) or vc
    local r = (d.radius or Config.DeliveryRadius)
    if dist2(vc, d) > r + 3.5 or dist2(pc, d) > r + 0.5 or math.abs(pc.z - d.z) > 3.0 then
        return false, 'Dépose la palette dans la zone de livraison indiquée.'
    end
    -- Validation : un seul paiement, puis nouvelle mission
    m.paid.delivery = true
    local amount = pay(src, m, S.pay.delivery, 'palette livrée')
    m.delivered = (m.delivered or 0) + 1
    local boxes = m.boxes
    deleteNet(m.palletNet)
    for _, n in ipairs(m.boxNets or {}) do deleteNet(n) end
    newRound(src, m)
    log(('%s a livré une palette (%d cartons, %d $)'):format(nameOf(src), boxes, amount))
    return true, nil, { amount = amount, boxes = boxes, account = S.account }
end

-- Palette et cartons créés par le client (objets réseau) : gardés pour le nettoyage
function A.palletObject(src, data)
    local m = M[src]
    if not m or m.stage ~= 'collect' or m.palletNet then return false end
    local e = entityFromNet(data and data.net)
    if not e then return false end
    if m.pallet and dist(GetEntityCoords(e), m.pallet) > 4.0 then DeleteEntity(e) return false end
    m.palletNet = tonumber(data.net)
    return true
end
function A.boxObject(src, data)
    local m = M[src]
    if not m or not m.palletNet then return false end
    local e = entityFromNet(data and data.net)
    if not e or #m.boxNets >= m.required + 2 then if e then DeleteEntity(e) end return false end
    m.boxNets[#m.boxNets + 1] = tonumber(data.net)
    return true
end

function A.replaceForklift(src)
    local m = M[src]
    if not m then return false, 'Tu ne travailles pas.' end
    local c = coords(src)
    if not c or not S.npc.placed or dist(c, S.npc) > Config.NpcDistance + 1.0 then return false, 'Approche-toi du responsable de l\'entrepôt.' end
    if m.replacedAt and now() - m.replacedAt < 60 then return false, 'Patiente une minute avant de redemander un Fenwick.' end
    if m.stage == 'carry' then return false, 'Dépose d\'abord ta palette.' end
    if m.veh and DoesEntityExist(m.veh) then
        pcall(function() exports.elyzea_core:RemoveKeys(src, m.veh) end)
        DeleteEntity(m.veh)
    end
    m.veh, m.vehNet = nil, nil
    local ok, why = spawnForklift(src, m)
    if not ok then return false, why end
    m.replacedAt = now()
    return true, 'Nouveau Fenwick disponible.'
end

-- ---------------------------------------------------------------- réception des demandes
local FLOOD = { accept = 2000, finish = 1500, pickup = 700, drop = 700, lift = 800, unload = 800, deliver = 1000,
    palletObject = 300, boxObject = 100, replaceForklift = 3000 }

RegisterNetEvent('elyzea_manutention:action', function(name, data)
    local src = source
    local fn = A[tostring(name or '')]
    if not fn or not Manut.ready then return end
    if flood(src, name, FLOOD[name] or 1000) then return end
    local ok, res, msg, extra = pcall(fn, src, type(data) == 'table' and data or {})
    if not ok then
        log(('erreur %s : %s'):format(tostring(name), tostring(res)))
        notify(src, 'Le métier est momentanément indisponible.', 'error')
        return
    end
    TriggerClientEvent('elyzea_manutention:result', src, name, res == true, msg, extra)
    if M[src] or name == 'finish' then push(src) end
end)

RegisterNetEvent('elyzea_manutention:requestConfig', function()
    local src = source
    if not Manut.ready then return end
    TriggerClientEvent('elyzea_manutention:config', src, publicView())
    push(src)
end)

-- Déconnexion / changement de personnage : tout est nettoyé (la tenue est rendue par le client à la reconnexion)
AddEventHandler('playerDropped', function()
    local src = source
    if M[src] then cleanup(src) end
    lastAction[src] = nil
end)
AddEventHandler('elyzea:server:playerUnloaded', function(src)
    src = tonumber(src)
    if src and M[src] then A.finish(src, 'logout') end
end)

-- Missions abandonnées : rien fait depuis N minutes → travail terminé ; Fenwick détruit → signalé
CreateThread(function()
    while true do
        Wait(30000)
        if Manut.ready then
            for src, m in pairs(M) do
                if not GetPlayerName(src) then
                    cleanup(src, m)
                elseif S.forklift.idleMinutes > 0 and now() - (m.last or now()) > S.forklift.idleMinutes * 60 then
                    A.finish(src, 'idle')
                    notify(src, ('Travail terminé : aucune activité depuis %d minutes.'):format(S.forklift.idleMinutes), 'error', 'MANUTENTIONNAIRE')
                    push(src)
                elseif m.veh and (not DoesEntityExist(m.veh) or GetEntityHealth(m.veh) <= 0) then
                    m.veh, m.vehNet = nil, nil
                    notify(src, 'Ton Fenwick est hors service : demande-en un autre au responsable de l\'entrepôt.', 'error', 'MANUTENTIONNAIRE')
                    push(src)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for src, m in pairs(M) do
        cleanup(src, m)
        TriggerClientEvent('elyzea_manutention:ended', src, { reason = 'stop' })
    end
end)

-- ---------------------------------------------------------------- démarrage
CreateThread(function()
    MySQL.ready.await()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `manut_settings` (
        `k` VARCHAR(40) NOT NULL PRIMARY KEY, `v` LONGTEXT NOT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) DEFAULT CHARSET=utf8mb4]])
    Manut.Load()
    Manut.ready = true
    log(('prêt : %d point(s) de cartons, %d palette(s), %d spawn(s) de Fenwick, %d livraison(s), %d $ par palette'):format(
        #S.pickups, #S.pallets, #S.spawns, #S.deliveries, S.pay.delivery))
end)

-- Exports utiles aux autres ressources
exports('IsWorking', function(src) return M[tonumber(src)] ~= nil end)
exports('GetMission', function(src) return missionView(M[tonumber(src)]) end)

-- Accès interne (server/admin.lua)
Manut.M, Manut.broadcast, Manut.missionView, Manut.push, Manut.cleanup, Manut.A = M, broadcast, missionView, push, cleanup, A
Manut.sanitizePoint = point
Manut.sanitizeOutfit = outfitPart
Manut.notify, Manut.nameOf, Manut.coords = notify, nameOf, coords
Manut.setSettings = function(new) S = new Manut.settings = S end
