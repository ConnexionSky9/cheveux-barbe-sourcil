-- =========================================================
--  ELYZEA CASINO - roues de la fortune
--  Le serveur vérifie le droit de jouer et le coût, tire le segment (pondéré par les chances
--  réglées dans l'admin) AVANT l'animation, puis remet le lot une seule fois à la fin.
--  Le client ne choisit jamais le résultat et n'envoie jamais de récompense.
-- =========================================================
local S = Casino.settings
local SPIN_MS = 8500
local spinning = {}    -- [pedId] = { src, id }
local cooldown = {}    -- ["wheel:cid"] = GetGameTimer() de fin
local doneNonce = {}   -- [src] = { [nonce] = résultat }
local spinSeq = 0

local function itemExists(name)
    local ok, list = pcall(function() return exports.elyzea_inventory:GetItemList() end)
    if ok and type(list) == 'table' then return list[name] ~= nil end
    return true   -- liste indisponible : on laisse l'inventaire refuser si besoin
end
Casino.ItemExists = itemExists

local function wheelOf(pedId)
    local pt = Casino.points[tonumber(pedId) or -1]
    if not pt or pt.role ~= 'wheel' then return nil, nil, 'Roue introuvable.' end
    local w = Casino.WheelById(pt.wheel)
    if not w then return pt, nil, 'Aucune roue n\'est réglée sur ce point (menu admin › Casino).' end
    return pt, w
end

local function dailyCount(wheelId, cid)
    local n = MySQL.scalar.await('SELECT `spins` FROM `casino_wheel_daily` WHERE `wheel` = ? AND `citizenid` = ? AND `day` = CURDATE()', { wheelId, cid })
    return tonumber(n) or 0
end

local function pay(src, w, cost)
    if (w.costType or 'chips') == 'free' or cost <= 0 then return true end
    if w.costType == 'money' then
        local core = exports.elyzea_core
        if (core:GetMoney(src, 'cash') or 0) >= cost then return core:RemoveMoney(src, 'cash', cost, 'casino-roue') == true, 'cash' end
        if (core:GetMoney(src, 'bank') or 0) >= cost then return core:RemoveMoney(src, 'bank', cost, 'casino-roue') == true, 'bank' end
        return false
    end
    return Casino.TakeChips(src, cost), 'chips'
end

local function refund(src, w, cost, how, cid)
    if cost <= 0 or not how then return end
    if how == 'chips' then Casino.GiveChips(src, cost, 'remboursement roue', cid)
    else exports.elyzea_core:AddMoney(src, how, cost, 'casino-roue-remboursement') end
end

-- ---------------------------------------------------------------- voiture à gagner (un seul gagnant)
local claimed = {}   -- [wheelId] = true pendant la remise de la voiture (personne d'autre ne peut la tirer)

-- Voiture encore à gagner sur cette roue (affichée sur le podium)
function Casino.WheelCar(w)
    for _, s in ipairs(w.segments or {}) do
        if s.reward == 'vehicle' and s.model and s.model ~= '' then
            return { model = s.model, label = s.label }
        end
    end
end

local function newPlate()
    for _ = 1, 50 do
        local p = ('CASI%04d'):format(math.random(0, 9999))
        if not MySQL.scalar.await('SELECT `id` FROM `player_vehicles` WHERE `plate` = ? OR `plate` = ? LIMIT 1', { p, ' ' .. p }) then return p end
    end
end

-- Inscrit la voiture au nom du gagnant (garage public), clés s'il est connecté
local function giveVehicle(src, seg, who)
    local plate = newPlate()
    if not plate then return nil, 'aucune plaque libre' end
    local model = seg.model:lower()
    local hash = joaat(model)
    local license = who.license
    if (not license or license == '') and src and GetPlayerName(src) then
        for _, id in ipairs(GetPlayerIdentifiers(src)) do if id:find('^license:') then license = id break end end
    end
    local ok, vid = pcall(function()
        return MySQL.insert.await([[INSERT INTO `player_vehicles` (`license`, `citizenid`, `vehicle`, `hash`, `mods`, `plate`, `garage`, `fuel`, `engine`, `body`, `state`)
            VALUES (?, ?, ?, ?, ?, ?, ?, 100, 1000, 1000, 1)]], { license or '', who.cid, model, tostring(hash),
            json.encode({ model = hash, plate = plate, fuelLevel = 100.0 }), plate, Config.CarGarage or 'public' })
    end)
    if not ok or not vid then return nil, 'enregistrement du véhicule impossible' end
    if src and GetPlayerName(src) then
        pcall(function() exports.elyzea_core:GiveKeys(src, plate) end)
        if GetResourceState('elyzea_concess') == 'started' then pcall(function() exports.elyzea_concess:EnsureKey(src, plate, model) end) end
    end
    return plate
end

-- La voiture est partie : son segment est retiré de la roue, les chances sont ramenées à 100 %
local function removeCar(wheelId)
    local w = Casino.WheelById(wheelId)   -- la roue a pu être réenregistrée pendant la rotation
    if not w then return end
    for i = #w.segments, 1, -1 do
        if w.segments[i].reward == 'vehicle' then table.remove(w.segments, i) end
    end
    if #w.segments >= 2 then Rules.Normalize(w.segments) else w.enabled = false end
    Casino.SaveKey('wheels')
end

-- Remise du lot (une seule fois : appelée par un seul SetTimeout par tirage)
local function grant(src, w, seg, cid, who)
    local r = seg.reward or 'none'
    local v = math.floor(tonumber(seg.value) or 0)
    local online = src and GetPlayerName(src)
    if r == 'chips' and v > 0 then
        Casino.GiveChips(online and src or nil, v, 'lot roue ' .. w.name, cid)
        return ('%d jetons'):format(v), v
    elseif r == 'money' and v > 0 then
        if online and exports.elyzea_core:AddMoney(src, 'cash', v, 'casino-roue') then return ('%d $'):format(v), 0 end
        MySQL.insert('INSERT INTO `casino_pending` (`citizenid`, `money`, `reason`) VALUES (?, ?, ?)', { cid, v, 'lot roue ' .. w.name })
        return ('%d $ (mis de côté)'):format(v), 0
    elseif r == 'item' and seg.item and seg.item ~= '' then
        local count = math.max(1, math.floor(tonumber(seg.count) or 1))
        if not itemExists(seg.item) then return nil, 0, ('l\'objet « %s » n\'existe plus'):format(seg.item) end
        local ok, res = false, false
        if online then ok, res = pcall(function() return exports.elyzea_inventory:AddItem(src, seg.item, count) end) end
        if not (ok and res == true) then return nil, 0, 'inventaire plein ou joueur parti' end
        return ('%d × %s'):format(count, seg.item), 0
    elseif r == 'vehicle' and seg.model and seg.model ~= '' then
        local plate, why = giveVehicle(online and src or nil, seg, who)
        if not plate then return nil, 0, why end
        return ('la voiture %s (plaque %s, au garage)'):format(seg.label, plate), 0
    elseif r == 'custom' then
        TriggerEvent('elyzea_casino:customReward', src, cid, w.id, seg)   -- pour une autre ressource
        return seg.label or 'Récompense spéciale', 0
    end
    return nil, 0
end

local function spin(src, d)
    if not Casino.Enabled() then return false, 'Le casino est fermé.' end
    local pt, w, err = wheelOf(d.pedId)
    if not w then return false, err end
    if not w.enabled then return false, 'Cette roue est désactivée.' end
    local valid, why = Rules.WeightsValid(w.segments)
    if not valid then return false, 'Roue mal réglée (' .. why .. ') : préviens le staff.' end
    if not Casino.Near(src, pt, 'table') then return false, 'Approche-toi de la roue.' end
    if spinning[pt.id] then return false, 'La roue tourne déjà, attends ton tour.' end
    local p = Casino.Player(src)
    if not p then return false, 'Personnage non chargé.' end
    local ck = w.id .. ':' .. p.cid
    if cooldown[ck] and GetGameTimer() < cooldown[ck] then
        return false, ('Attends encore %d s avant de rejouer.'):format(math.ceil((cooldown[ck] - GetGameTimer()) / 1000))
    end
    local maxDay = math.floor(tonumber(w.maxPerDay) or 0)
    if maxDay > 0 and dailyCount(w.id, p.cid) >= maxDay then return false, ('Limite de %d participation(s) par jour atteinte.'):format(maxDay) end
    local cost = math.floor(tonumber(w.cost) or 0)
    local okPay, how = pay(src, w, cost)
    if not okPay then return false, (w.costType == 'money') and ('Il te faut %d $.'):format(cost) or ('Il te faut %d jetons.'):format(cost) end

    -- Tirage serveur (la voiture déjà en cours de remise ne peut plus sortir)
    local pool = w.segments
    if claimed[w.id] then
        pool = {}
        for i, sg in ipairs(w.segments) do pool[i] = { weight = sg.reward == 'vehicle' and 0 or sg.weight } end
    end
    local idx = Rules.Draw(pool, math.random())
    local seg = w.segments[idx]
    local isCar = seg.reward == 'vehicle'
    if isCar then
        claimed[w.id] = true   -- réservée tout de suite : un seul gagnant même si deux roues tournent
    end
    spinSeq = spinSeq + 1
    local id = spinSeq
    spinning[pt.id] = { src = src, id = id }
    cooldown[ck] = GetGameTimer() + math.max(0, math.floor(tonumber(w.cooldown) or 0)) * 1000 + SPIN_MS
    if maxDay > 0 then
        MySQL.query('INSERT INTO `casino_wheel_daily` (`wheel`, `citizenid`, `day`, `spins`) VALUES (?, ?, CURDATE(), 1) ON DUPLICATE KEY UPDATE `spins` = `spins` + 1', { w.id, p.cid })
    end
    -- Tous les joueurs proches voient la même rotation (même segment, même durée)
    local c = pt.table and vector3(pt.table.x, pt.table.y, pt.table.z) or pt.ped
    for _, sid in ipairs(GetPlayers()) do
        local s2 = tonumber(sid)
        local ped = GetPlayerPed(s2)
        if ped ~= 0 and #(GetEntityCoords(ped) - c) < 60.0 then
            TriggerClientEvent('elyzea_casino:wheel:spin', s2, pt.id, idx, #w.segments, SPIN_MS, src)
        end
    end
    SetTimeout(SPIN_MS + 300, function()
        if not spinning[pt.id] or spinning[pt.id].id ~= id then return end
        spinning[pt.id] = nil
        local label, chipsWon, failed = grant(src, w, seg, p.cid, p)
        if isCar then
            if not failed then removeCar(w.id) end
            claimed[w.id] = nil
            Casino.PushPoints(-1)
            if not failed then
                print(('[elyzea_casino] Voiture « %s » (%s) gagnée à la roue %s par %s (%s).'):format(seg.label, seg.model, w.id, p.name, p.cid))
                TriggerClientEvent('elyzea_casino:notify', -1, ('🎉 %s a gagné la voiture %s à la roue de la fortune !'):format(p.name, seg.label), 'success')
            end
        end
        if failed then
            refund(GetPlayerName(src) and src or nil, w, cost, how, p.cid)
            Casino.Log('wheel', w.id, nil, cost, 0, ('%s : lot non remis (%s), participation remboursée'):format(seg.label, failed), false, p)
            if GetPlayerName(src) then Casino.Notify(src, ('« %s » : lot impossible à remettre (%s). Participation remboursée.'):format(seg.label, failed), 'warning') end
            return
        end
        Casino.Log('wheel', w.id, nil, cost, chipsWon, ('%s%s'):format(seg.label, label and (' → ' .. label) or ''), false, p)
        if GetPlayerName(src) then
            TriggerClientEvent('elyzea_casino:wheel:result', src, pt.id, idx, seg.label, label)
            Casino.Notify(src, label and ('Roue : %s ! Tu gagnes %s.'):format(seg.label, label) or ('Roue : %s.'):format(seg.label), label and 'success' or 'info')
        end
    end)
    return true, nil, { idx = idx, n = #w.segments, duration = SPIN_MS }
end

Ely.callback.register('elyzea_casino:wheel:spin', function(src, d)
    if type(d) ~= 'table' then return false, 'Demande invalide.' end
    local nonce = tostring(d.nonce or '')
    if nonce == '' or #nonce > 40 then return false, 'Demande invalide.' end
    doneNonce[src] = doneNonce[src] or {}
    if doneNonce[src][nonce] then return false, 'Demande déjà traitée.' end
    doneNonce[src][nonce] = true
    return Casino.Locked(src, 'wheel', spin, src, d)
end)

Ely.callback.register('elyzea_casino:wheel:info', function(src, pedId)
    local pt, w, err = wheelOf(pedId)
    if not w then return { error = err } end
    local valid = Rules.WeightsValid(w.segments)
    return { name = w.name, cost = w.cost, costType = w.costType, enabled = w.enabled and valid and Casino.Enabled(),
        busy = spinning[pt.id] ~= nil, maxPerDay = w.maxPerDay, chips = Casino.Chips(src) }
end)

AddEventHandler('playerDropped', function() doneNonce[source] = nil end)

-- ---------------------------------------------------------------- tests (admin) : aucune vraie récompense
function Casino.WheelTest(w)
    local valid, why = Rules.WeightsValid(w.segments)
    if not valid then return nil, why end
    local idx = Rules.Draw(w.segments, math.random())
    return idx
end

function Casino.WheelSimulate(w, n)
    n = math.max(100, math.min(200000, math.floor(tonumber(n) or 10000)))
    local counts = {}
    for i = 1, #w.segments do counts[i] = 0 end
    for _ = 1, n do local i = Rules.Draw(w.segments, math.random()) counts[i] = counts[i] + 1 end
    local out = {}
    for i, s in ipairs(w.segments) do out[i] = { label = s.label, expected = tonumber(s.weight) or 0, got = math.floor(counts[i] / n * 10000 + 0.5) / 100 } end
    return out, n
end
