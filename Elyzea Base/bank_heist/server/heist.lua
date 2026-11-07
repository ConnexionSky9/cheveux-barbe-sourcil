-- =====================================================================
--  BANK HEIST - serveur : sessions de braquage (une par banque)
--  Banquier braqué (arme en main) → session active : alarme, police prévenue (position), banquier
--  mains en l'air puis à genoux.
--  Porte du coffre : locked → hacking (décryptage) ou c4 (charge posée) → open.
--  À l'ouverture, le butin de CHAQUE point (chariot, liasses, coffres) est tiré une seule fois.
--  Fin : coffre refermé après la durée d'ouverture, butin épuisé, abandon ou staff → délai (cooldown).
-- =====================================================================
local P = BHS
P.sessions = {}      -- [bankId] = session
P.cooldown = {}      -- [bankId] = os.time() de fin de délai
P.globalUntil = 0

local function now() return os.time() end
local function minLeft(t) return math.max(1, math.ceil((t - now()) / 60)) end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- ---------------------------------------------------------------------
-- Persistance des délais (un redémarrage ne remet pas une banque à disposition)
-- ---------------------------------------------------------------------
local function saveState(bankId, untilT, session)
    MySQL.query('INSERT INTO `bh_state` (`bank_id`, `cooldown_until`, `active_session`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `cooldown_until` = VALUES(`cooldown_until`), `active_session` = VALUES(`active_session`)',
        { bankId, untilT or 0, session })
end

function P.LoadState()
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `bh_state`') or {}) do
        if r.bank_id == '_global' then P.globalUntil = tonumber(r.cooldown_until) or 0
        else
            P.cooldown[r.bank_id] = tonumber(r.cooldown_until) or 0
            if r.active_session then
                P.Log('heist', r.active_session, nil, ('%s : braquage interrompu par un redémarrage (banque laissée en délai)'):format(r.bank_id))
                saveState(r.bank_id, P.cooldown[r.bank_id], nil)
            end
        end
    end
    P.PublishBanks()
end

-- ---------------------------------------------------------------------
-- État public : anime le banquier, l'alarme, la porte, le butin et la C4 chez tous les joueurs
-- ---------------------------------------------------------------------
function P.Phase(bankId)
    if P.sessions[bankId] then return 'active' end
    if math.max(P.cooldown[bankId] or 0, P.globalUntil) > now() then return 'cooldown' end
    return 'available'
end

function P.PublishBanks()
    local pub = {}
    for _, b in ipairs(P.S.banks) do
        local s = P.sessions[b.id]
        local x = { phase = P.Phase(b.id) }
        if s then
            x.door, x.alarm = s.door, s.alarm
            x.handsUp = (s.threatUntil or 0) > now()
            x.c4At = s.door == 'c4' and s.c4At or nil
            x.openAt = s.openAt
            x.points = {}
            for i, p in ipairs(s.points or {}) do
                x.points[i] = { full = s.door ~= 'open' or p.left > 0 or (p.itemLeft or 0) > 0, busy = p.busyBy ~= nil, drilled = p.drilled == true, drilling = p.drillBy ~= nil }
            end
        end
        pub[b.id] = x
    end
    GlobalState.bhBanks = pub
end

-- Affichage du butin en haut à droite (braqueurs de la session)
function P.PushHud(s)
    local b = P.BankById(s.bank)
    if not b then return end
    local data = { bank = b.name, total = s.distributed or 0, initial = s.initialPool or 0, door = s.door, alarm = s.alarm,
        closeIn = s.openUntil and math.max(0, s.openUntil - now()) or nil, robbers = count(s.participants) }
    for id in pairs(s.participants) do
        local d = {}
        for k, v in pairs(data) do d[k] = v end
        d.mine = (s.byPlayer or {})[id] or 0
        TriggerClientEvent('bh:client:hud', id, d)
    end
end
local function hudOff(s) for id in pairs(s.participants) do TriggerClientEvent('bh:client:hud', id, false) end end

-- ---------------------------------------------------------------------
-- Braqueurs
-- ---------------------------------------------------------------------
function P.Robber(src, s)
    if s.participants[src] then return true end
    local b = P.BankById(s.bank)
    if not P.S.general.lateJoin or not b or count(s.participants) >= b.maxRobbers then return false end
    if Adapters.Police.IsOnDuty(src) or not P.Near(src, b.doorPoint, P.S.general.bankRadius) then return false end
    s.participants[src] = true
    P.Log('heist', s.id, src, 'Rejoint le braquage')
    P.PushHud(s)
    return true
end

local function hoursOk(hh)
    local f, t = hh.from, hh.to
    if f == t then return true end
    local h = tonumber(os.date('%H'))
    if f < t then return h >= f and h < t end
    return h >= f or h < t
end
P.HoursOk = hoursOk

-- Matériel réuni par les braqueurs présents
local function gear(list, req)
    local laptop, c4, bag = false, false, false
    for _, src in ipairs(list) do
        if not laptop and P.FindLaptop(src) then laptop = true end
        if not c4 and Adapters.Inv.Count(src, P.S.items.c4.name) > 0 then c4 = true end
        if not bag then
            local cb = Adapters.Bag.Carried(src)
            if Adapters.Inv.Count(src, P.S.items.bag.name) > 0 or (cb and cb.kind == 'bank') then bag = true end
        end
    end
    local miss = {}
    if req.tool == 'any' and not laptop and not c4 then miss[#miss + 1] = P.S.items.laptop.label .. ' ou ' .. P.S.items.c4.label
    elseif req.tool == 'laptop' and not laptop then miss[#miss + 1] = P.S.items.laptop.label .. ' (avec des tentatives)'
    elseif req.tool == 'c4' and not c4 then miss[#miss + 1] = P.S.items.c4.label end
    if req.bag and not bag then miss[#miss + 1] = P.S.items.bag.label end
    return miss
end

-- Le braquage est-il possible ? (affichage du menu ALT et lancement)
function P.CanRob(src, b)
    if not P.S.general.enabled then return 'Les braquages de banque sont désactivés.' end
    if not b or not b.enabled then return 'Cette banque ne peut pas être braquée.' end
    if Adapters.Police.IsOnDuty(src) then return 'Pas en service de police.' end
    if P.sessions[b.id] then return 'Un braquage est déjà en cours ici.' end
    if count(P.sessions) >= P.S.general.maxSimultaneous then return 'Un autre braquage de banque est déjà en cours en ville.' end
    local cd = math.max(P.cooldown[b.id] or 0, P.globalUntil)
    if cd > now() then return ('Banque sous haute surveillance : réessayez dans %d min.'):format(minLeft(cd)) end
    if not hoursOk(b.hours) then return ('Braquage possible seulement de %dh à %dh.'):format(b.hours.from, b.hours.to) end
    local cops = Adapters.Police.Count()
    if cops < b.minCops then return ('Pas assez de policiers en service (%d/%d).'):format(cops, b.minCops) end
end

-- ---------------------------------------------------------------------
-- BRAQUER LA BANQUE (ALT sur le banquier, arme en main)
-- ---------------------------------------------------------------------
P.Req.rob = function(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    local why = P.CanRob(src, b)
    if why then return { error = why } end
    if not P.Near(src, b.banker, 4.0) then return { error = 'Approchez-vous du banquier.' } end
    if not P.Armed(src) then return { error = 'Il vous faut une arme en main.' } end
    if P.InVehicle(src) or P.IsDown(src) then return { error = 'Impossible maintenant.' } end
    -- braqueurs : le joueur + les joueurs proches (hors police), les plus proches d'abord
    local me = P.PedPos(src)
    local near = {}
    for _, sid in ipairs(GetPlayers()) do
        local id = tonumber(sid)
        local p = P.PedPos(id)
        if id ~= src and p and #(p - me) <= P.S.general.participantRadius and not Adapters.Police.IsOnDuty(id) and not P.IsDown(id) then near[#near + 1] = { id = id, d = #(p - me) } end
    end
    table.sort(near, function(a, c) return a.d < c.d end)
    local list = { src }
    for _, x in ipairs(near) do if #list < b.maxRobbers then list[#list + 1] = x.id end end
    if #list < b.minRobbers then return { error = ('Il faut au moins %d braqueurs dans la banque (%d).'):format(b.minRobbers, #list) } end
    local miss = gear(list, b.required)
    if #miss > 0 then return { error = 'Matériel manquant : ' .. table.concat(miss, ', ') .. '.' } end
    if not P.Lock('bank:' .. b.id) then return { error = 'Patientez un instant.' } end
    local s = { id = P.Uid('BK'), bank = b.id, participants = {}, startedAt = now(), door = 'locked', points = {}, distributed = 0, byPlayer = {},
        threatUntil = now() + b.threatTime, alarm = P.S.alarm.enabled, alarmUntil = now() + P.S.alarm.maxMinutes * 60, starter = Adapters.Perms.Name(src), lastPresence = now() }
    for _, id in ipairs(list) do s.participants[id] = true end
    for i in ipairs(b.loot) do s.points[i] = { left = 0, itemLeft = 0 } end
    P.sessions[b.id] = s
    P.cooldown[b.id] = now() + b.cooldown * 60
    P.globalUntil = now() + P.S.general.globalCooldown * 60
    saveState(b.id, P.cooldown[b.id], s.id)
    saveState('_global', P.globalUntil, nil)
    P.Unlock('bank:' .. b.id)
    -- Alerte police : immédiate, avec la position de la banque
    local cops = Adapters.Police.Count()
    local desc = ('%s · braquage à main armée · alarme %s · %s'):format(b.name, s.alarm and 'déclenchée' or 'silencieuse', os.date('%H:%M'))
    local channel = Adapters.Police.Alert(vector3(b.doorPoint.x, b.doorPoint.y, b.doorPoint.z), P.S.police.title, desc)
    local names = {}
    for id in pairs(s.participants) do
        names[#names + 1] = Adapters.Perms.Name(id)
        TriggerClientEvent('bh:client:robStart', id, { bank = b.name, alarm = s.alarm })
    end
    P.Log('heist', s.id, src, ('%s · BRAQUAGE · braqueurs : %s · policiers en service : %d · alerte : %s'):format(b.name, table.concat(names, ', '), cops, channel))
    P.PublishBanks()
    P.PushHud(s)
    return { ok = true }
end

-- ---------------------------------------------------------------------
-- Ouverture de la porte (décryptage réussi ou C4) : butin de chaque point tiré une seule fois
-- ---------------------------------------------------------------------
P.doorLinks = {}
function P.VaultDoors(b)
    if GetResourceState('admin_menu') ~= 'started' or not b.door then return {} end
    local ok, l = pcall(function() return exports.admin_menu:DoorsNear(b.door.x, b.door.y, b.door.z, 4.0) end)
    local ids = {}
    for _, d in ipairs(ok and type(l) == 'table' and l or {}) do ids[#ids + 1] = d.id end
    return ids
end
function P.SetVaultLock(bankId, locked)
    local b = P.BankById(bankId)
    if not b then return end
    for _, id in ipairs(P.VaultDoors(b)) do pcall(function() exports.admin_menu:SetDoorLocked(id, locked) end) end
end

function P.OpenDoor(s, how, src)
    if s.door == 'open' then return end
    local b = P.BankById(s.bank)
    local L = P.S.loot
    local mult, mod = 100, ''
    if L.bonus.enabled and math.random() * 100 < L.bonus.chance then mult = math.random(L.bonus.min, L.bonus.max) mod = (' · bonus %d %%'):format(mult)
    elseif L.malus.enabled and math.random() * 100 < L.malus.chance then mult = math.random(L.malus.min, L.malus.max) mod = (' · malus %d %%'):format(mult) end
    local total, parts = 0, {}
    for i, p in ipairs(b.loot) do
        local sp = s.points[i] or {}
        if p.item ~= '' then
            sp.left, sp.item, sp.itemLeft = 0, p.item, p.itemMax > p.itemMin and math.random(p.itemMin, p.itemMax) or p.itemMin
            parts[#parts + 1] = ('%s ×%d'):format(p.item, sp.itemLeft)
        else
            local v = p.max > p.min and math.random(p.min, p.max) or p.min
            sp.left = math.floor(v * mult / 100)
            sp.itemLeft = 0
            total = total + sp.left
        end
        s.points[i] = sp
    end
    s.door, s.openAt, s.openUntil, s.hackBy = 'open', now(), now() + P.S.door.openTime + L.openDuration, nil
    s.initialPool = total
    P.Log('heist', s.id, src, ('Porte du coffre ouverte (%s) · butin : %s%s%s'):format(how, BH.Money(total), mod, #parts > 0 and (' · objets : ' .. table.concat(parts, ', ')) or ''))
    for id in pairs(s.participants) do TriggerClientEvent('bh:client:doorOpen', id, { how = how }) end
    P.SetVaultLock(s.bank, false)
    P.PublishBanks()
    P.PushHud(s)
end

function P.EndSession(bankId, reason, src)
    local s = P.sessions[bankId]
    if not s then return end
    P.SetVaultLock(bankId, true)
    P.sessions[bankId] = nil
    if P.StopCollectorsOf then P.StopCollectorsOf(bankId) end
    if P.CancelHackOf then P.CancelHackOf(bankId) end
    if P.CancelAlarmGame then P.CancelAlarmGame(bankId) end
    saveState(bankId, P.cooldown[bankId], nil)
    hudOff(s)
    P.Log('heist', s.id, src, ('Fin du braquage : %s · butin du coffre : %s · ramassé : %s'):format(reason, BH.Money(s.initialPool or 0), BH.Money(s.distributed)))
    P.PublishBanks()
end

-- ---------------------------------------------------------------------
-- C4 sur la porte
-- ---------------------------------------------------------------------
P.Req.c4Check = function(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    local s = b and P.sessions[b.id]
    if not s then return { error = 'Aucun braquage en cours ici.' } end
    if not P.S.door.c4 then return { error = 'La C4 n\'est pas autorisée sur cette porte.' } end
    if s.door ~= 'locked' then return { error = s.door == 'c4' and 'Une charge est déjà posée.' or (s.door == 'hacking' and 'Décryptage en cours.' or 'La porte est déjà ouverte.') } end
    if P.S.door.c4OnlyAfterHack and P.S.door.hack and not s.hackBurned then return { error = 'La C4 n\'est possible qu\'après l\'échec du décryptage.' } end
    if not P.Robber(src, s) then return { error = 'Vous ne participez pas à ce braquage.' } end
    if not P.Near(src, b.doorPoint, 2.5) then return { error = 'Approchez-vous de la porte du coffre.' } end
    if Adapters.Inv.Count(src, P.S.items.c4.name) < 1 then return { error = 'Il vous faut une charge C4.' } end
    if P.InVehicle(src) or P.IsDown(src) then return { error = 'Impossible maintenant.' } end
    return { ok = true, time = P.S.c4.plantTime }
end

P.Req.c4Plant = function(src, d)
    local chk = P.Req.c4Check(src, d)
    if chk.error then return chk end
    local b = P.BankById(tostring(d.bank))
    local s = P.sessions[b.id]
    if not P.Lock('open:' .. b.id) then return { error = 'Une autre action est en cours sur la porte.' } end
    local ok = Adapters.Inv.Remove(src, P.S.items.c4.name, 1)
    if not ok then P.Unlock('open:' .. b.id) return { error = 'Il vous faut une charge C4.' } end
    s.door, s.c4At, s.c4By = 'c4', now() + P.S.c4.delay, src
    P.Unlock('open:' .. b.id)
    P.Log('heist', s.id, src, ('Charge C4 posée (explosion dans %d s)'):format(P.S.c4.delay))
    P.PublishBanks()
    P.PushHud(s)
    return { ok = true, delay = P.S.c4.delay }
end

-- ---------------------------------------------------------------------
-- Suivi : explosion, fermeture du coffre, alarme, abandon, braqueurs déconnectés
-- ---------------------------------------------------------------------
local lastSig = ''
CreateThread(function()
    while true do
        Wait(1000)
        local changed = false
        for bankId, s in pairs(P.sessions) do
            local b = P.BankById(bankId)
            if not b then P.EndSession(bankId, 'banque supprimée') goto continue end
            for id in pairs(s.participants) do if GetPlayerPing(id) <= 0 then s.participants[id] = nil end end
            if s.door == 'c4' and now() >= s.c4At then
                -- explosion (sans dégâts) synchronisée : chaque joueur proche joue l'effet localement
                TriggerClientEvent('bh:client:explode', -1, { bank = bankId, x = b.door.x, y = b.door.y, z = b.door.z, type = P.S.c4.explosionType })
                if P.S.c4.alertPolice then Adapters.Police.Alert(vector3(b.door.x, b.door.y, b.door.z), 'Explosion à la banque', ('%s · explosion dans la salle des coffres · %s'):format(b.name, os.date('%H:%M'))) end
                P.OpenDoor(s, 'C4', s.c4By)
                changed = true
            end
            if s.alarm and now() >= s.alarmUntil then
                s.alarm = false
                P.Log('heist', s.id, nil, 'Alarme coupée automatiquement (durée maximale)')
                changed = true
                P.PushHud(s)
            end
            if s.door == 'open' then
                local left = false
                for _, p in ipairs(s.points) do if p.left > 0 or (p.itemLeft or 0) > 0 then left = true break end end
                if now() >= s.openUntil or not left then
                    P.EndSession(bankId, left and 'coffre refermé (temps écoulé)' or 'coffre vidé')
                    goto continue
                end
            end
            -- abandon : plus aucun braqueur dans la banque pendant N minutes
            local present = false
            for id in pairs(s.participants) do if P.Near(id, b.doorPoint, P.S.general.bankRadius) then present = true break end end
            if present then s.lastPresence = now()
            elseif now() - s.lastPresence > P.S.general.abandonMinutes * 60 then P.EndSession(bankId, 'abandonné (plus personne dans la banque)') goto continue end
            if s.threatUntil and not s.threatDone and now() >= s.threatUntil then s.threatDone = true changed = true end
            ::continue::
        end
        local sig = {}
        for _, b in ipairs(P.S.banks) do sig[#sig + 1] = P.Phase(b.id) end
        sig = table.concat(sig, ',')
        if sig ~= lastSig then lastSig = sig changed = true end
        if changed then P.PublishBanks() end
    end
end)

-- Minuteur du coffre dans l'affichage des braqueurs (toutes les 5 s, en plus des mises à jour du butin)
CreateThread(function()
    while true do
        Wait(5000)
        for _, s in pairs(P.sessions) do if s.door == 'open' then P.PushHud(s) end end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for bankId, s in pairs(P.sessions) do
        MySQL.query('UPDATE `bh_state` SET `active_session` = ? WHERE `bank_id` = ?', { s.id, bankId })
    end
end)
