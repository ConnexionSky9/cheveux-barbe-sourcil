-- =====================================================================
--  BANK HEIST - serveur : sessions de braquage (une machine à états par banque)
--  disponible -> started (alerte police) -> [menace] -> hacking -> open (piratage réussi)
--                                        \-> exhausted (ordinateur grillé) -> c4 -> open
--  open -> done (coffre refermé après la durée d'ouverture ou butin épuisé) -> délai (cooldown)
--  Le butin est tiré UNE fois, à l'ouverture, et n'est jamais redistribué.
-- =====================================================================
local P = BHS
P.sessions = {}      -- [bankId] = session
P.cooldown = {}      -- [bankId] = os.time() de fin de délai
P.globalUntil = 0

local function now() return os.time() end
local function minLeft(t) return math.max(1, math.ceil((t - now()) / 60)) end

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
                -- braquage coupé par un redémarrage : aucun butin n'est redistribué, la banque reste en délai
                P.Log('heist', r.active_session, nil, ('%s : braquage interrompu par un redémarrage (banque laissée en délai)'):format(r.bank_id))
                saveState(r.bank_id, P.cooldown[r.bank_id], nil)
            end
        end
    end
    P.PublishBanks()
end

-- ---------------------------------------------------------------------
-- État public (pour animer le PNJ, la porte, les billets, la C4)
-- ---------------------------------------------------------------------
function P.Phase(bankId)
    local s = P.sessions[bankId]
    if s then return s.state end
    if math.max(P.cooldown[bankId] or 0, P.globalUntil) > now() then return 'cooldown' end
    return 'available'
end

function P.PublishBanks()
    local pub = {}
    for _, b in ipairs(P.S.banks) do
        local s = P.sessions[b.id]
        pub[b.id] = { phase = P.Phase(b.id), threatened = s and s.threatened or false, threatLeft = s and math.max(0, (s.threatUntil or 0) - now()) or 0,
            open = s and s.state == 'open' or false, cashLeft = s and s.state == 'open' and s.pool > 0 or false,
            c4Left = s and s.state == 'c4' and math.max(0, s.c4At - now()) or nil, hacker = s and s.hackBy or nil,
            doorLinked = (P.doorLinks and P.doorLinks[b.id] or 0) > 0 }
    end
    GlobalState.bhBanks = pub
end

-- ---------------------------------------------------------------------
-- Braqueurs
-- ---------------------------------------------------------------------
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- Le joueur est-il braqueur de cette session ? (s'il arrive après le départ : ajouté si autorisé)
function P.Robber(src, s)
    if s.participants[src] then return true end
    local b = P.BankById(s.bank)
    if not P.S.general.lateJoin or not b or count(s.participants) >= b.maxRobbers then return false end
    if Adapters.Police.IsOnDuty(src) or not P.Near(src, b.vault, P.S.general.bankRadius) then return false end
    s.participants[src] = true
    P.Log('heist', s.id, src, 'Rejoint le braquage')
    return true
end

local function hoursOk(b)
    local f, t = b.hours.from, b.hours.to
    if f == t then return true end
    local h = tonumber(os.date('%H'))
    if f < t then return h >= f and h < t end
    return h >= f or h < t
end

-- Matériel réuni par les braqueurs (au moins un exemplaire de chaque objet demandé)
local function gear(list, req)
    local have = { laptop = false, bag = false, c4 = false }
    for _, src in ipairs(list) do
        if req.laptop and not have.laptop and P.FindLaptop(src) then have.laptop = true end
        if req.bag and not have.bag then
            local bag = Adapters.Bag.Carried(src)
            if Adapters.Inv.Count(src, P.S.items.bag.name) > 0 or (bag and bag.kind == 'bank') then have.bag = true end
        end
        if req.c4 and not have.c4 and Adapters.Inv.Count(src, P.S.items.c4.name) > 0 then have.c4 = true end
    end
    local miss = {}
    if req.laptop and not have.laptop then miss[#miss + 1] = P.S.items.laptop.label .. ' (avec des tentatives)' end
    if req.bag and not have.bag then miss[#miss + 1] = P.S.items.bag.label end
    if req.c4 and not have.c4 then miss[#miss + 1] = P.S.items.c4.label end
    return miss
end

-- ---------------------------------------------------------------------
-- Lancement
-- ---------------------------------------------------------------------
P.Req.start = function(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    if not P.S.general.enabled then return { error = 'Les braquages de banque sont désactivés.' } end
    if not b or not b.enabled then return { error = 'Cette banque ne peut pas être braquée.' } end
    if not P.Near(src, b.start, P.S.general.interactDistance + 1.0) then return { error = 'Vous êtes trop loin.' } end
    if Adapters.Police.IsOnDuty(src) then return { error = 'Pas en service de police.' } end
    if P.sessions[b.id] then return { error = 'Un braquage est déjà en cours ici.' } end
    if count(P.sessions) >= P.S.general.maxSimultaneous then return { error = 'Un autre braquage de banque est déjà en cours en ville.' } end
    local cd = math.max(P.cooldown[b.id] or 0, P.globalUntil)
    if cd > now() then return { error = ('Banque sous haute surveillance : réessayez dans %d min.'):format(minLeft(cd)) } end
    if not hoursOk(b) then return { error = ('Braquage possible seulement de %dh à %dh.'):format(b.hours.from, b.hours.to) } end
    local cops = Adapters.Police.Count()
    if cops < b.minCops then return { error = ('Pas assez de policiers en service (%d/%d).'):format(cops, b.minCops) } end
    -- braqueurs : le joueur + les joueurs proches (hors police), les plus proches d'abord
    local me = P.PedPos(src)
    local near = {}
    for _, s in ipairs(GetPlayers()) do
        local id = tonumber(s)
        local pos = P.PedPos(id)
        if id ~= src and pos and #(pos - me) <= P.S.general.participantRadius and not Adapters.Police.IsOnDuty(id) and not P.IsDown(id) then near[#near + 1] = { id = id, d = #(pos - me) } end
    end
    table.sort(near, function(a, c) return a.d < c.d end)
    local list = { src }
    for _, x in ipairs(near) do if #list < b.maxRobbers then list[#list + 1] = x.id end end
    if #list < b.minRobbers then return { error = ('Il faut au moins %d braqueurs près du point de départ (%d).'):format(b.minRobbers, #list) } end
    local miss = gear(list, b.required)
    if #miss > 0 then return { error = 'Matériel manquant : ' .. table.concat(miss, ', ') .. '.' } end
    if not P.Lock('bank:' .. b.id) then return { error = 'Patientez un instant.' } end
    local s = { id = P.Uid('BK'), bank = b.id, state = 'started', participants = {}, startedAt = now(), threatened = false, pool = 0, distributed = 0, extras = {},
        starter = Adapters.Perms.Name(src), lastPresence = now() }
    for _, id in ipairs(list) do s.participants[id] = true end
    P.sessions[b.id] = s
    P.cooldown[b.id] = now() + b.cooldown * 60
    P.globalUntil = now() + P.S.general.globalCooldown * 60
    saveState(b.id, P.cooldown[b.id], s.id)
    saveState('_global', P.globalUntil, nil)
    P.Unlock('bank:' .. b.id)
    -- Alerte police : une seule fois, dès la validation
    local desc = ('%s · %s · GPS %.1f, %.1f · %s'):format(b.name, b.id, b.vault.x, b.vault.y, os.date('%H:%M'))
    local channel = Adapters.Police.Alert(vector3(b.vault.x, b.vault.y, b.vault.z), P.S.police.title, desc)
    local names = {}
    for id in pairs(s.participants) do
        names[#names + 1] = Adapters.Perms.Name(id)
        P.Notify(id, ('Braquage de %s lancé : la police est prévenue. Menacez l\'employé puis piratez le coffre.'):format(b.name), 'inform')
    end
    P.Log('heist', s.id, src, ('%s · lancé · braqueurs : %s · policiers en service : %d · alerte : %s'):format(b.name, table.concat(names, ', '), cops, channel))
    P.PublishBanks()
    return { ok = true }
end

-- ---------------------------------------------------------------------
-- Menace de l'employé
-- ---------------------------------------------------------------------
P.Req.threat = function(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    local s = b and P.sessions[b.id]
    if not s then return { error = 'Aucun braquage en cours ici.' } end
    if s.threatened then return { error = 'L\'employé est déjà à terre.' } end
    if not P.Robber(src, s) then return { error = 'Vous ne participez pas à ce braquage.' } end
    if not P.Near(src, b.clerk, 5.0) then return { error = 'Approchez-vous de l\'employé.' } end
    if not P.Armed(src) then return { error = 'Il vous faut une arme en main.' } end
    s.threatened, s.threatUntil = true, now() + b.threatTime
    P.Log('heist', s.id, src, 'Employé menacé')
    P.PublishBanks()
    return { ok = true, time = b.threatTime }
end

-- ---------------------------------------------------------------------
-- Ouverture du coffre (piratage réussi ou C4) : butin tiré une seule fois
-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
-- Verrou de la porte du coffre (système de portes / clés de l'éditeur d'admin_menu)
-- La porte du coffre ajoutée dans l'éditeur (Map › Portes) près du point « Porte du coffre »
-- est déverrouillée par le piratage ou la C4 et reverrouillée à la fin du braquage.
-- ---------------------------------------------------------------------
P.doorLinks = {}   -- [bankId] = { ids }
function P.VaultDoors(b)
    if GetResourceState('admin_menu') ~= 'started' or not b.door then return {} end
    local ok, list = pcall(function() return exports.admin_menu:DoorsNear(b.door.x, b.door.y, b.door.z, 4.0) end)
    local ids = {}
    for _, d in ipairs(ok and type(list) == 'table' and list or {}) do ids[#ids + 1] = d.id end
    return ids
end
function P.SetVaultLock(bankId, locked)
    local b = P.BankById(bankId)
    if not b then return end
    for _, id in ipairs(P.VaultDoors(b)) do pcall(function() exports.admin_menu:SetDoorLocked(id, locked) end) end
end
function P.RefreshDoorLinks()
    local changed = false
    for _, b in ipairs(P.S.banks) do
        local n = #P.VaultDoors(b)
        if (P.doorLinks[b.id] or 0) ~= n then P.doorLinks[b.id] = n changed = true end
    end
    if changed then P.PublishBanks() end
end
CreateThread(function()
    Wait(5000)
    while true do
        -- hors braquage, la porte reste comme les détenteurs des clés l'ont laissée
        if P.S then P.RefreshDoorLinks() end
        Wait(30000)
    end
end)

function P.OpenVault(s, how, src)
    if s.state == 'open' or s.opened then return end
    local b = P.BankById(s.bank)
    local L = P.S.loot
    local pool = b.loot.max > b.loot.min and math.random(b.loot.min, b.loot.max) or b.loot.min
    local mod = ''
    if L.bonus.enabled and math.random() * 100 < L.bonus.chance then
        local pct = math.random(L.bonus.min, L.bonus.max) pool = math.floor(pool * pct / 100) mod = (' · bonus %d %%'):format(pct)
    elseif L.malus.enabled and math.random() * 100 < L.malus.chance then
        local pct = math.random(L.malus.min, L.malus.max) pool = math.floor(pool * pct / 100) mod = (' · malus %d %%'):format(pct)
    end
    local extras = {}
    for _, e in ipairs(L.extras) do
        if e.enabled and math.random() * 100 < e.chance then extras[#extras + 1] = { item = e.item, count = e.max > e.min and math.random(e.min, e.max) or e.min } end
    end
    s.opened, s.state, s.pool, s.initialPool, s.extras, s.openUntil, s.hackBy = true, 'open', pool, pool, extras, now() + L.openDuration, nil
    local ex = {}
    for _, e in ipairs(extras) do ex[#ex + 1] = ('%s ×%d'):format(e.item, e.count) end
    P.Log('heist', s.id, src, ('Coffre ouvert (%s) · butin : %s%s%s'):format(how, BH.Money(pool), mod, #ex > 0 and (' · objets : ' .. table.concat(ex, ', ')) or ''))
    for id in pairs(s.participants) do P.Notify(id, 'Le coffre est ouvert : ramassez les billets avec votre sac (E ou ALT sur les chariots).', 'success') end
    P.SetVaultLock(s.bank, false)
    P.PublishBanks()
end

function P.EndSession(bankId, reason, src)
    local s = P.sessions[bankId]
    if not s then return end
    P.SetVaultLock(bankId, true)
    P.sessions[bankId] = nil
    if P.StopCollectorsOf then P.StopCollectorsOf(bankId) end
    if P.CancelHackOf then P.CancelHackOf(bankId) end
    saveState(bankId, P.cooldown[bankId], nil)
    P.Log('heist', s.id, src, ('Fin du braquage : %s · butin du coffre : %s · ramassé : %s'):format(reason, BH.Money(s.initialPool or 0), BH.Money(s.distributed)))
    P.PublishBanks()
end

-- ---------------------------------------------------------------------
-- C4 : seulement quand l'ordinateur a épuisé ses tentatives sur ce coffre
-- ---------------------------------------------------------------------
P.Req.c4Check = function(src, d)
    local b = P.BankById(tostring(d.bank or ''))
    local s = b and P.sessions[b.id]
    if not s then return { error = 'Aucun braquage en cours ici.' } end
    if s.opened or s.state == 'c4' then return { error = 'Le coffre est déjà ouvert ou une charge est posée.' } end
    if s.state ~= 'exhausted' then return { error = 'La C4 n\'est possible qu\'après l\'échec des tentatives de piratage.' } end
    if not P.Robber(src, s) then return { error = 'Vous ne participez pas à ce braquage.' } end
    if not P.Near(src, b.vault, 2.5) then return { error = 'Approchez-vous du coffre.' } end
    if Adapters.Inv.Count(src, P.S.items.c4.name) < 1 then return { error = 'Il vous faut une charge C4.' } end
    return { ok = true, time = P.S.c4.plantTime }
end

P.Req.c4Plant = function(src, d)
    local chk = P.Req.c4Check(src, d)
    if chk.error then return chk end
    local b = P.BankById(tostring(d.bank))
    local s = P.sessions[b.id]
    if not P.Lock('open:' .. b.id) then return { error = 'Une autre action est en cours sur le coffre.' } end
    local ok = Adapters.Inv.Remove(src, P.S.items.c4.name, 1)
    if not ok then P.Unlock('open:' .. b.id) return { error = 'Il vous faut une charge C4.' } end
    s.state, s.c4At, s.c4By = 'c4', now() + P.S.c4.delay, src
    P.Unlock('open:' .. b.id)
    P.Log('heist', s.id, src, ('Charge C4 posée (explosion dans %d s)'):format(P.S.c4.delay))
    P.PublishBanks()
    return { ok = true, delay = P.S.c4.delay }
end

-- ---------------------------------------------------------------------
-- Suivi : explosion, fermeture du coffre, abandon, braqueurs déconnectés
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
            if s.state == 'c4' and now() >= s.c4At then
                -- l'explosion (sans dégâts) est créée par un seul client : elle est synchronisée pour tous
                local who = (GetPlayerPing(s.c4By or 0) > 0 and P.Near(s.c4By, b.vault, 80.0)) and s.c4By or nil
                if not who then for id in pairs(s.participants) do if P.Near(id, b.vault, 80.0) then who = id break end end end
                if who then TriggerClientEvent('bh:client:explode', who, { x = b.vault.x, y = b.vault.y, z = b.vault.z, type = P.S.c4.explosionType }) end
                P.OpenVault(s, 'C4', s.c4By)
                changed = true
            end
            if s.state == 'open' and (now() >= s.openUntil or (s.pool <= 0 and #s.extras == 0)) then
                P.EndSession(bankId, s.pool <= 0 and 'coffre vidé' or 'coffre refermé (temps écoulé)')
                goto continue
            end
            -- abandon : plus aucun braqueur dans la banque pendant N minutes
            local present = false
            for id in pairs(s.participants) do if P.Near(id, b.vault, P.S.general.bankRadius) then present = true break end end
            if present then s.lastPresence = now()
            elseif now() - s.lastPresence > P.S.general.abandonMinutes * 60 then P.EndSession(bankId, 'abandonné (plus personne dans la banque)') goto continue end
            if s.threatened and s.threatUntil and now() >= s.threatUntil and not s.threatDone then s.threatDone = true changed = true end
            ::continue::
        end
        -- fin d'un délai : la banque redevient « disponible » pour les joueurs
        local sig = {}
        for _, b in ipairs(P.S.banks) do sig[#sig + 1] = P.Phase(b.id) end
        sig = table.concat(sig, ',')
        if sig ~= lastSig then lastSig = sig changed = true end
        if changed then P.PublishBanks() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for bankId, s in pairs(P.sessions) do
        MySQL.query('UPDATE `bh_state` SET `active_session` = ? WHERE `bank_id` = ?', { s.id, bankId })
    end
end)
