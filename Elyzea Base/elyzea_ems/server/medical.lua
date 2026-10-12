-- =====================================================================
--  ELYZEA EMS - serveur : actions médicales
--  Soins, stabilisation, réanimation : en deux temps. « medStart » vérifie et
--  mémorise ; le client joue l'animation ; « medFinish » n'est accepté que si
--  la durée minimale est écoulée et que les deux joueurs sont encore proches.
--  Chaque acte est enregistré (ems_treatments) pour la facture et le compte rendu.
-- =====================================================================
local P = Ems
local DI = Config.Distances

local KINDS = {
    heal      = { perm = 'heal',      duration = Config.Heal.duration,      label = 'Soins' },
    stabilize = { perm = 'stabilize', duration = Config.Stabilize.duration, label = 'Stabilisation' },
    revive    = { perm = 'revive',    duration = Config.Revive.duration,    label = 'Réanimation' },
}

local pending = {}        -- [ems] = { kind, target, t }
local EQ = Config.Equipment or {}

-- Matériel requis (Config.Equipment) : renvoie l'objet manquant, ou nil
local function Missing(src, kind)
    local e = EQ.enabled and EQ[kind]
    if not e or not e.item or GetResourceState('elyzea_inventory') ~= 'started' then return nil end
    local ok, n = pcall(function() return exports.elyzea_inventory:Search(src, 'count', e.item) end)
    if ok and (tonumber(n) or 0) > 0 then return nil end
    return e.item
end
local function Consume(src, kind)
    local e = EQ.enabled and EQ[kind]
    if not e or not e.item or not e.consume or GetResourceState('elyzea_inventory') ~= 'started' then return true end
    local ok, done = pcall(function() return exports.elyzea_inventory:RemoveItem(src, e.item, 1) end)
    return ok and done ~= false
end
P.escort = {}             -- [ems] = patient
P.escortedBy = {}         -- [patient] = ems

local function Target(src, id, dist)
    local t = tonumber(id)
    if not t or t == src or not GetPlayerName(t) or not P.GetPlayer(t) then return nil, 'Patient introuvable.' end
    if P.Dist(src, t) > (dist or DI.interact) + 1.0 then return nil, 'Le patient est trop loin.' end
    return t
end

-- Acte enregistré (une seule fois par acte, jamais par le client)
function P.AddTreatment(target, service, emsSrc)
    local cid = P.Cid(target)
    if not cid then return end
    local call = P.CallOfPatient and P.CallOfPatient(cid)
    MySQL.insert.await([[INSERT INTO `ems_treatments` (`patient_cid`, `patient_name`, `service`, `ems_cid`, `ems_name`, `call_id`) VALUES (?, ?, ?, ?, ?, ?)]],
        { cid, P.Name(target), service, P.Cid(emsSrc), P.Name(emsSrc), call and call.id or nil })
    if call and P.CallAdvance then P.CallAdvance(call, service == 'transport' and 'transport' or 'care', emsSrc) end
end

-- Acte déjà noté récemment (évite un doublon : examen répété, transport aller-retour)
local function Recent(target, service, minutes)
    local cid = P.Cid(target)
    return cid and (tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM `ems_treatments` WHERE `patient_cid` = ? AND `service` = ? AND `invoice_uid` IS NULL
        AND `created_at` >= DATE_SUB(NOW(), INTERVAL ? MINUTE)]], { cid, service, minutes })) or 0) > 0
end

local function HealthOf(t)
    local ped = GetPlayerPed(t)
    local h, max, armor = 0, 200, 0
    if ped ~= 0 then
        h, max, armor = GetEntityHealth(ped), GetEntityMaxHealth(ped), GetPedArmour(ped)
        if not max or max <= 100 then max = 200 end
    end
    return math.max(0, math.min(100, math.floor((h - 100) / (max - 100) * 100 + 0.5))), math.max(0, math.min(100, armor or 0))
end

-- ---------------------------------------------------------------------
-- Examiner / vérifier l'état
-- ---------------------------------------------------------------------
P.Actions.examine = { perm = 'medical', duty = true, fn = function(src, d)
    local t, why = Target(src, d.target)
    if not t then return { error = why } end
    local hp, armor = HealthOf(t)
    local down = P.down[t]
    local p = P.GetPlayer(t)
    local md = p and p.PlayerData.metadata or {}
    local cid = P.Cid(t)
    local file = cid and MySQL.single.await('SELECT `blood`, `allergies` FROM `ems_patients` WHERE `citizenid` = ?', { cid }) or nil
    if not Recent(t, 'consult', 30) then P.AddTreatment(t, 'consult', src) end
    local state = 'Conscient'
    if down then state = down.stabilized and 'Inconscient · stabilisé' or 'Inconscient · état critique'
    elseif hp < 25 then state = 'Conscient · blessures graves'
    elseif hp < 60 then state = 'Conscient · blessé' end
    return { exam = {
        id = t, name = P.Name(t), hp = hp, armor = armor, state = state, down = down ~= nil,
        downFor = down and (os.time() - down.since) or nil, bleedLeft = down and math.max(0, down.untilT - os.time()) or nil,
        stabilized = down and down.stabilized or false, cause = down and down.cause or nil,
        hunger = tonumber(md.hunger) and math.floor(md.hunger) or nil, thirst = tonumber(md.thirst) and math.floor(md.thirst) or nil,
        blood = file and file.blood or nil, allergies = file and file.allergies or nil, cid = cid,
    } }
end }

-- ---------------------------------------------------------------------
-- Soins, stabilisation, réanimation
-- ---------------------------------------------------------------------
P.Actions.medStart = { perm = 'medical', duty = true, fn = function(src, d)
    local k = KINDS[tostring(d.kind or '')]
    if not k then return { error = 'Acte inconnu.' } end
    if not P.Can(src, k.perm) then return { error = 'Votre grade ne permet pas cet acte.' } end
    if P.down[src] then return { error = 'Vous êtes à terre.' } end
    local t, why = Target(src, d.target)
    if not t then return { error = why } end
    local down = P.down[t]
    if d.kind == 'heal' and down then return { error = 'Le patient est inconscient : stabilisez-le ou réanimez-le.' } end
    if d.kind == 'stabilize' and not down then return { error = 'Le patient n\'est pas à terre.' } end
    if d.kind == 'stabilize' and down.stabilized then return { error = 'Le patient est déjà stabilisé.' } end
    if d.kind == 'revive' and not down then return { error = 'Le patient n\'est pas inconscient.' } end
    local miss = Missing(src, d.kind)
    if miss then return { error = ('Matériel manquant : %s.'):format(miss) } end
    pending[src] = { kind = d.kind, target = t, t = GetGameTimer() }
    TriggerClientEvent('ems:client:treated', t, d.kind, P.Name(src))
    return { ok = true, duration = k.duration, label = k.label }
end }

P.Actions.medCancel = { perm = 'medical', fn = function(src) pending[src] = nil return { ok = true } end }

P.Actions.medFinish = { perm = 'medical', duty = true, fn = function(src, d)
    local pd = pending[src]
    pending[src] = nil
    local k = pd and KINDS[pd.kind]
    if not pd or not k or pd.kind ~= d.kind or pd.target ~= tonumber(d.target) then return { error = 'Acte interrompu.' } end
    if GetGameTimer() - pd.t < k.duration - 1500 then return { error = 'Acte interrompu trop tôt.' } end
    local t, why = Target(src, pd.target)
    if not t then return { error = why } end
    if Missing(src, pd.kind) or not Consume(src, pd.kind) then return { error = 'Matériel manquant.' } end
    if pd.kind == 'heal' then
        if P.down[t] then return { error = 'Le patient a perdu connaissance.' } end
        TriggerClientEvent('ems:client:heal', t)
    elseif pd.kind == 'stabilize' then
        if not P.Stabilize(t) then return { error = 'Le patient n\'a plus besoin d\'être stabilisé.' } end
    elseif pd.kind == 'revive' then
        if not P.down[t] then return { error = 'Le patient n\'est plus inconscient.' } end
        P.Revive(t)
    end
    P.AddTreatment(t, pd.kind, src)
    P.Notify(t, ('%s : %s.'):format(k.label, P.Name(src)), 'success')
    P.Log(src, k.label, ('%s [%d]'):format(P.Name(t), t))
    return { ok = true, message = ('%s terminé(e) : %s.'):format(k.label, P.Name(t)) }
end }

-- ---------------------------------------------------------------------
-- Accompagner / porter un patient
-- ---------------------------------------------------------------------
local function StopEscort(ems)
    local t = P.escort[ems]
    if not t then return end
    P.escort[ems] = nil
    P.escortedBy[t] = nil
    if GetPlayerName(t) then
        Player(t).state:set('emsEscortedBy', nil, true)
        TriggerClientEvent('ems:client:escort', t, nil)
    end
    if GetPlayerName(ems) then TriggerClientEvent('ems:client:escorting', ems, nil) end
end
P.StopEscortBy = StopEscort

P.Actions.escort = { perm = 'escort', duty = true, fn = function(src, d)
    local t = tonumber(d.target)
    if t and P.escort[src] == t then StopEscort(src) return { ok = true, message = 'Vous lâchez le patient.' } end
    if P.escort[src] then return { error = 'Vous accompagnez déjà quelqu\'un.' } end
    local why
    t, why = Target(src, d.target)
    if not t then return { error = why } end
    if P.escortedBy[t] then return { error = 'Quelqu\'un s\'occupe déjà de ce patient.' } end
    if GetVehiclePedIsIn(GetPlayerPed(t), false) ~= 0 then return { error = 'Le patient est dans un véhicule.' } end
    if Player(t).state.carriedBy or Player(t).state.escortedBy then return { error = 'Le patient est déjà tenu par quelqu\'un.' } end
    P.escort[src], P.escortedBy[t] = t, src
    local down = P.down[t] ~= nil
    Player(t).state:set('emsEscortedBy', src, true)
    TriggerClientEvent('ems:client:escort', t, src, down)
    TriggerClientEvent('ems:client:escorting', src, t, down)
    return { ok = true, message = down and 'Vous portez le patient.' or 'Vous accompagnez le patient.' }
end }

-- ---------------------------------------------------------------------
-- Ambulance : installer / sortir un patient
-- ---------------------------------------------------------------------
P.Actions.putIn = { perm = 'vehicle', duty = true, fn = function(src, d)
    local t, why = Target(src, d.target, DI.vehicle)
    if not t then return { error = why } end
    local veh = NetworkGetEntityFromNetworkId(tonumber(d.net) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return { error = 'Véhicule introuvable.' } end
    local vc = GetEntityCoords(veh)
    if #(vc - (P.Coords(src) or vc + 100.0)) > DI.vehicle + 2.0 or #(vc - (P.Coords(t) or vc + 100.0)) > DI.vehicle + 4.0 then
        return { error = 'Le véhicule est trop loin.' }
    end
    if P.escortedBy[t] then StopEscort(P.escortedBy[t]) end
    TriggerClientEvent('ems:client:putIn', t, tonumber(d.net), P.down[t] ~= nil)
    if not Recent(t, 'transport', 30) then P.AddTreatment(t, 'transport', src) end
    return { ok = true, message = ('%s installé(e) dans le véhicule.'):format(P.Name(t)) }
end }

P.Actions.takeOut = { perm = 'vehicle', duty = true, fn = function(src, d)
    local t, why = Target(src, d.target, DI.vehicle)
    if not t then return { error = why } end
    if GetVehiclePedIsIn(GetPlayerPed(t), false) == 0 then return { error = 'Le patient n\'est pas dans un véhicule.' } end
    TriggerClientEvent('ems:client:takeOut', t, P.down[t] ~= nil)
    return { ok = true, message = ('%s sorti(e) du véhicule.'):format(P.Name(t)) }
end }

AddEventHandler('playerDropped', function()
    local src = source
    pending[src] = nil
    if P.escort[src] then StopEscort(src) end
    local ems = P.escortedBy[src]
    if ems then
        P.escort[ems], P.escortedBy[src] = nil, nil
        if GetPlayerName(ems) then TriggerClientEvent('ems:client:escorting', ems, nil) end
    end
end)

-- Le patient escorté est réanimé / relevé : on garde l'escorte mais on passe en « accompagner »
RegisterNetEvent('ems:server:escortBreak', function()
    local src = source
    local ems = P.escortedBy[src]
    if ems then StopEscort(ems) end
end)
