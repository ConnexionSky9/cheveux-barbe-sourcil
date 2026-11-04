-- =====================================================================
--  ELYZEA MANUTENTION - ADMINISTRATION
--  Appelé par admin_menu (onglet « Manutentionnaire ») : exports AdminSummary / AdminAction.
--  La permission est revérifiée ICI à chaque action (admin_menu › HasPermission, sinon ACE).
--  Les positions sont lues par le serveur sur le personnage de l'admin (jamais envoyées par le client).
--  Chaque modification est validée, enregistrée en base puis envoyée à tous les joueurs.
-- =====================================================================
local KINDS = {
    pickups = { label = 'Point de récupération des cartons', max = 64 },
    pallets = { label = 'Emplacement de palette', max = 32 },
    spawns = { label = 'Spawn de Fenwick', max = 32 },
    deliveries = { label = 'Zone de livraison', max = 32, radius = true },
}

local function isAdmin(src)
    src = tonumber(src)
    if src == 0 then return true end
    if not src or not GetPlayerName(src) then return false end
    if GetResourceState('admin_menu') == 'started' then
        local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, Config.Permission) end)
        return ok and r == true
    end
    return IsPlayerAceAllowed(src, Config.AcePermission) == true
end
Manut.IsAdmin = isAdmin

local function staffLog(src, msg)
    if GetResourceState('admin_menu') == 'started' then pcall(function() exports.admin_menu:AddLog(src, 'Manutentionnaire', msg) end) end
    print(('^5[Manutention]^0 %s : %s'):format(Manut.nameOf(src), msg))
end

-- Applique une modification (copie complète → validation → enregistrement → diffusion)
local function apply(mutate)
    local raw = json.decode(json.encode(Manut.Get()))
    mutate(raw)
    Manut.setSettings(Manut.Sanitize(raw))
    Manut.Save()
end

local function here(src)
    local c, h = Manut.coords(src)
    if not c then return nil end
    return { x = c.x, y = c.y, z = c.z, h = h }
end

local function fmt(p) return p and ('%.1f, %.1f, %.1f (cap %d°)'):format(p.x, p.y, p.z, math.floor((p.h or 0) + 0.5)) or '?' end

-- Fenwick d'un point de spawn : libre / occupé (véhicule présent) / réservé
local function spawnState(sp)
    for _, v in ipairs(GetAllVehicles and GetAllVehicles() or {}) do
        if DoesEntityExist(v) and #(GetEntityCoords(v) - vector3(sp.x, sp.y, sp.z)) < Config.SpawnFreeRadius then return 'occupé' end
    end
    return 'libre'
end

function Manut.AdminSummary(src)
    if not isAdmin(src) then return nil end
    local S = Manut.Get()
    local workers = {}
    for s, m in pairs(Manut.M) do
        workers[#workers + 1] = { id = s, name = Manut.nameOf(s), stage = m.stage, boxes = m.boxes, required = m.required,
            delivered = m.delivered or 0, earned = m.earned or 0, plate = m.plate, since = m.started, forklift = m.veh ~= nil and DoesEntityExist(m.veh) }
    end
    table.sort(workers, function(a, b) return a.id < b.id end)
    local spawns = {}
    for i, sp in ipairs(S.spawns) do
        local c = json.decode(json.encode(sp))
        c.state = spawnState(sp)
        spawns[i] = c
    end
    local out = json.decode(json.encode(S))
    out.spawns = spawns
    return {
        settings = out, workers = workers,
        limits = { maxBoxes = Config.MaxBoxes, maxPay = Config.MaxPay, deliveryRadius = Config.DeliveryRadius },
        defaults = { boxesPerPallet = Config.Defaults.boxesPerPallet, delivery = Config.Defaults.pay.delivery },
    }
end

local Act = {}

-- 1. Configuration générale
function Act.general(src, d)
    apply(function(r)
        if d.enabled ~= nil then r.enabled = d.enabled == true end
        if d.boxesPerPallet ~= nil then r.boxesPerPallet = tonumber(d.boxesPerPallet) end
        if d.allowSprint ~= nil then r.allowSprint = d.allowSprint == true end
        if d.account ~= nil then r.account = d.account end
    end)
    local S = Manut.Get()
    staffLog(src, ('réglages : métier %s, %d cartons par palette, course avec carton %s, paiement %s'):format(
        S.enabled and 'ouvert' or 'fermé', S.boxesPerPallet, S.allowSprint and 'autorisée' or 'interdite', S.account == 'cash' and 'liquide' or 'banque'))
    return true, 'Configuration enregistrée.'
end

function Act.models(src, d)
    apply(function(r)
        r.models = r.models or {}
        for _, k in ipairs({ 'npc', 'box', 'boxOnPallet', 'pallet', 'forklift' }) do
            if d[k] ~= nil and tostring(d[k]) ~= '' then r.models[k] = tostring(d[k]) end
        end
    end)
    staffLog(src, 'modèles modifiés')
    return true, 'Modèles enregistrés (un modèle absent du jeu est remplacé par celui d\'origine chez le joueur).'
end

-- 7. Rémunérations
function Act.pay(src, d)
    apply(function(r)
        r.pay = r.pay or {}
        for _, k in ipairs({ 'delivery', 'perBox', 'palletDone', 'transport' }) do
            if d[k] ~= nil then r.pay[k] = tonumber(d[k]) end
        end
        for _, k in ipairs({ 'perBoxOn', 'palletDoneOn', 'transportOn' }) do
            if d[k] ~= nil then r.pay[k] = d[k] == true end
        end
    end)
    local p = Manut.Get().pay
    staffLog(src, ('rémunération : %d $ par palette livrée%s%s%s'):format(p.delivery,
        p.perBoxOn and (', ' .. p.perBox .. ' $ par carton') or '', p.palletDoneOn and (', ' .. p.palletDone .. ' $ palette complète') or '',
        p.transportOn and (', ' .. p.transport .. ' $ au chargement') or ''))
    return true, ('Rémunération enregistrée : %d $ par palette livrée.'):format(p.delivery)
end

-- 5. Fenwick (réglages)
function Act.forklift(src, d)
    apply(function(r)
        r.forklift = r.forklift or {}
        if d.enabled ~= nil then r.forklift.enabled = d.enabled == true end
        if d.max ~= nil then r.forklift.max = tonumber(d.max) end
        if d.idleMinutes ~= nil then r.forklift.idleMinutes = tonumber(d.idleMinutes) end
    end)
    local f = Manut.Get().forklift
    staffLog(src, ('Fenwick : %s, %d max, retrait après %d min sans activité'):format(f.enabled and 'activés' or 'désactivés', f.max, f.idleMinutes))
    return true, 'Réglages des Fenwick enregistrés.'
end

-- 2. PNJ
function Act.npc(src, d)
    apply(function(r)
        r.npc = r.npc or {}
        if d.enabled ~= nil then r.npc.enabled = d.enabled == true end
        if d.scenario ~= nil then r.npc.scenario = tostring(d.scenario) ~= '' and tostring(d.scenario) or 'aucun' end
        if d.h ~= nil and r.npc.placed then r.npc.h = tonumber(d.h) end
        if d.model ~= nil and tostring(d.model) ~= '' then r.models = r.models or {} r.models.npc = tostring(d.model) end
    end)
    staffLog(src, 'PNJ modifié')
    return true, 'PNJ enregistré.'
end

function Act.npcHere(src)
    local p = here(src)
    if not p then return false, 'Position introuvable.' end
    apply(function(r) r.npc = r.npc or {} r.npc.x, r.npc.y, r.npc.z, r.npc.h, r.npc.placed = p.x, p.y, p.z, p.h, true end)
    staffLog(src, 'PNJ placé en ' .. fmt(p))
    return true, 'PNJ placé à ta position, dans ton orientation.'
end

-- 3-6. Emplacements (ajouter / déplacer / modifier / supprimer)
local function kindOf(d)
    local k = tostring(d.kind or '')
    return KINDS[k] and k or nil
end

function Act.pointAdd(src, d)
    local k = kindOf(d)
    if not k then return false, 'Type d\'emplacement inconnu.' end
    local p = here(src)
    if not p then return false, 'Position introuvable.' end
    local list = Manut.Get()[k]
    if #list >= KINDS[k].max then return false, ('Maximum %d emplacements de ce type.'):format(KINDS[k].max) end
    p.label = d.label
    if KINDS[k].radius then p.radius = tonumber(d.radius) or Config.DeliveryRadius end
    apply(function(r) r[k] = r[k] or {} table.insert(r[k], p) end)
    staffLog(src, ('%s ajouté en %s'):format(KINDS[k].label, fmt(p)))
    return true, ('%s n°%d enregistré à ta position.'):format(KINDS[k].label, #Manut.Get()[k])
end

function Act.pointMove(src, d)
    local k = kindOf(d)
    local i = tonumber(d.i)
    if not k or not i or not Manut.Get()[k][i] then return false, 'Emplacement introuvable.' end
    local p = here(src)
    if not p then return false, 'Position introuvable.' end
    apply(function(r) local q = r[k][i] q.x, q.y, q.z, q.h = p.x, p.y, p.z, p.h end)
    staffLog(src, ('%s n°%d déplacé en %s'):format(KINDS[k].label, i, fmt(p)))
    return true, ('%s n°%d déplacé à ta position.'):format(KINDS[k].label, i)
end

function Act.pointEdit(src, d)
    local k = kindOf(d)
    local i = tonumber(d.i)
    if not k or not i or not Manut.Get()[k][i] then return false, 'Emplacement introuvable.' end
    apply(function(r)
        local q = r[k][i]
        if d.label ~= nil then q.label = tostring(d.label) end
        if d.h ~= nil then q.h = tonumber(d.h) end
        if d.radius ~= nil and KINDS[k].radius then q.radius = tonumber(d.radius) end
    end)
    staffLog(src, ('%s n°%d modifié'):format(KINDS[k].label, i))
    return true, 'Emplacement modifié.'
end

function Act.pointDel(src, d)
    local k = kindOf(d)
    local i = tonumber(d.i)
    if not k or not i or not Manut.Get()[k][i] then return false, 'Emplacement introuvable.' end
    apply(function(r) table.remove(r[k], i) end)
    staffLog(src, ('%s n°%d supprimé'):format(KINDS[k].label, i))
    return true, 'Emplacement supprimé.'
end

function Act.teleport(src, d)
    local S = Manut.Get()
    local p = d.kind == 'npc' and (S.npc.placed and S.npc) or (kindOf(d) and S[kindOf(d)][tonumber(d.i) or 0])
    if not p then return false, 'Emplacement introuvable.' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    SetEntityCoords(ped, p.x + 0.0, p.y + 0.0, p.z + 0.2, false, false, false, false)
    SetEntityHeading(ped, (p.h or 0.0) + 0.0)
    return true, 'Téléporté à l\'emplacement.'
end

-- Tenue : copiée sur le personnage de l'admin (le client lit ses vêtements, le serveur les valide)
function Act.outfitCapture(src, d)
    local g = d.gender == 'female' and 'female' or (d.gender == 'male' and 'male' or nil)
    if not g or type(d.outfit) ~= 'table' then return false, 'Tenue illisible.' end
    local o = Manut.sanitizeOutfit(d.outfit)
    local n = 0 for _ in pairs(o.c) do n = n + 1 end
    if n < 3 then return false, 'Tenue incomplète.' end
    apply(function(r) r.outfit = r.outfit or {} r.outfit[g] = o end)
    staffLog(src, 'tenue ' .. (g == 'female' and 'femme' or 'homme') .. ' copiée')
    return true, ('Tenue %s enregistrée : c\'est celle que tu portes.'):format(g == 'female' and 'femme' or 'homme')
end
-- Bouton du menu : le jeu de l'admin lit sa tenue et la renvoie (demande valable 20 s, permission revérifiée)
local asked = {}
function Act.outfitAsk(src, d)
    local g = d.gender == 'female' and 'female' or 'male'
    asked[src] = { gender = g, t = os.time() }
    TriggerClientEvent('elyzea_manutention:captureOutfit', src, g)
    return true, 'Lecture de ta tenue…'
end
RegisterNetEvent('elyzea_manutention:capturedOutfit', function(gender, outfit, sex)
    local src = source
    local a = asked[src]
    asked[src] = nil
    if not a or os.time() - a.t > 20 or not isAdmin(src) then return end
    if sex and sex ~= a.gender then
        return Manut.notify(src, ('Ton personnage n\'est pas %s : change de personnage (ou de modèle) pour copier cette tenue.'):format(a.gender == 'female' and 'une femme' or 'un homme'), 'error')
    end
    local ok, msg = Act.outfitCapture(src, { gender = a.gender, outfit = outfit })
    Manut.notify(src, msg or (ok and 'Tenue enregistrée.' or 'Tenue refusée.'), ok and 'success' or 'error')
end)

function Act.outfitReset(src, d)
    local g = d.gender == 'female' and 'female' or 'male'
    apply(function(r) r.outfit = r.outfit or {} r.outfit[g] = Config.Defaults.outfit[g] end)
    staffLog(src, 'tenue ' .. (g == 'female' and 'femme' or 'homme') .. ' remise par défaut')
    return true, 'Tenue d\'origine remise.'
end

-- Voir les emplacements en jeu (marqueurs, numéros, zones) : seulement chez cet admin
function Act.show(src, d)
    local S = Manut.Get()
    TriggerClientEvent('elyzea_manutention:adminShow', src, d.on == true and {
        npc = S.npc, pickups = S.pickups, pallets = S.pallets, spawns = S.spawns, deliveries = S.deliveries,
    } or nil)
    return true, d.on == true and 'Emplacements affichés en jeu (re-clique pour les cacher).' or 'Emplacements cachés.'
end

-- 8. Sauvegardes
function Act.save(src)
    Manut.Save()
    staffLog(src, 'sauvegarde manuelle')
    return true, 'Paramètres sauvegardés en base de données.'
end
function Act.reload(src)
    Manut.Load()
    staffLog(src, 'paramètres rechargés depuis la base')
    return true, 'Paramètres rechargés depuis la base de données.'
end
function Act.reset(src, d)
    if d.confirm ~= true then return false, 'Confirmation manquante.' end
    local keep = d.keepPoints == true
    local S = Manut.Get()
    local fresh = json.decode(json.encode(Config.Defaults))
    if keep then
        fresh.npc, fresh.pickups, fresh.pallets, fresh.spawns, fresh.deliveries = S.npc, S.pickups, S.pallets, S.spawns, S.deliveries
    end
    Manut.setSettings(Manut.Sanitize(fresh))
    Manut.Save()
    staffLog(src, keep and 'réglages remis par défaut (emplacements gardés)' or 'TOUT remis par défaut')
    return true, keep and 'Réglages remis par défaut (emplacements conservés).' or 'Tout a été remis par défaut.'
end

-- Arrêter le travail d'un joueur
function Act.stopWorker(src, d)
    local t = tonumber(d.id)
    if not t or not Manut.M[t] then return false, 'Ce joueur ne travaille pas.' end
    Manut.A.finish(t, 'staff')
    Manut.push(t)
    Manut.notify(t, 'Le staff a mis fin à ton travail de manutentionnaire.', 'error', 'MANUTENTIONNAIRE')
    staffLog(src, ('travail de %s arrêté'):format(Manut.nameOf(t)))
    return true, 'Travail arrêté.'
end

function Manut.AdminAction(src, name, data)
    if not isAdmin(src) then return false, 'Permission refusée.' end
    if not Manut.ready then return false, 'La ressource démarre, réessaie.' end
    local fn = Act[tostring(name or '')]
    if not fn then return false, 'Action inconnue.' end
    local ok, res, msg = pcall(fn, tonumber(src), type(data) == 'table' and data or {})
    if not ok then
        print('^1[Manutention] action admin ' .. tostring(name) .. ' : ' .. tostring(res) .. '^0')
        return false, 'Erreur pendant l\'enregistrement.'
    end
    return res, msg
end

exports('AdminSummary', function(src) return Manut.AdminSummary(src) end)
exports('AdminAction', function(src, name, data) return Manut.AdminAction(src, name, data) end)

-- Sans admin_menu : /manutpoints (ACE elyzea_manutention.admin) affiche les emplacements en jeu
RegisterCommand('manutpoints', function(src)
    if src == 0 or not isAdmin(src) then return end
    Act.show(src, { on = true })
end, false)
