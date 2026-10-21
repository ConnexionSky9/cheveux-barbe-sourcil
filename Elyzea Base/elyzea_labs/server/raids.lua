-- =====================================================================
--  ELYZEA LABS · serveur : attaques et capture
--  États : preparing (préparation) → active (en cours) → success / failed / cancelled.
--  · Lancement à l'entrée par un groupe ennemi, dans un créneau autorisé, hors délais de repos,
--    avec assez d'attaquants vivants dans la zone et assez de défenseurs connectés.
--  · Pendant l'attaque, le serveur compte chaque seconde les attaquants VIVANTS (ni morts, ni à
--    terre) dans la zone, dans le monde normal (instance 0). Les joueurs déconnectés ne comptent pas.
--  · Échec : plus aucun attaquant vivant dans la zone pendant « emptyGrace » secondes.
--  · Victoire à la fin du compte à rebours selon la règle (present / majority) → transfert atomique.
-- =====================================================================
local L = Labs
local raids = {}       -- [labId] = attaque en cours
local groupLast = {}   -- [groupId] = fin de sa dernière attaque (os.time)
function L.raidOf(labId) return raids[labId] end
function L.RaidList() local t = {} for _, r in pairs(raids) do t[#t + 1] = r end return t end

local function alive(src)
    local ped = L.Ped(src)
    if not ped or GetEntityHealth(ped) <= 0 then return false end
    if GetResourceState('elyzea_ems') == 'started' then
        local ok, down = pcall(function() return exports.elyzea_ems:IsDown(src) end)
        if ok and down then return false end
    end
    return true
end
L.Alive = alive

local function inZone(src, lab, radius)
    return GetPlayerRoutingBucket(src) == 0 and L.Dist(src, lab) <= radius
end

-- Membres vivants d'un groupe dans la zone
local function countIn(gid, lab, radius)
    local n = 0
    for _, m in ipairs(L.GroupOnline(gid)) do
        if alive(m.src) and inZone(m.src, lab, radius) then n = n + 1 end
    end
    return n
end
L.CountInZone = countIn

local function notifySide(gid, msg, kind)
    L.NotifyGroup(gid, msg, kind, not L.Raids().notifyAllMembers)
end

-- Toutes les conditions de lancement. quiet : simple consultation (entrée)
function L.RaidCheck(src, lab, g, quiet)
    local S = L.Raids()
    if not S.enabled then return false, 'Les attaques de laboratoires sont désactivées.' end
    if not lab.owner or lab.disabled then return false, 'Ce laboratoire ne peut pas être attaqué.' end
    if not g then return false, 'Il faut faire partie d\'un groupe illégal.' end
    if g.id == lab.owner then return false, 'C\'est le laboratoire de ton groupe.' end
    if S.starterBossOnly and not g.boss then return false, 'Seul le chef du groupe peut lancer une attaque.' end
    if raids[lab.id] then return false, 'Une attaque est déjà en cours ici.' end
    for _, r in pairs(raids) do if r.attacker == g.id then return false, 'Ton groupe attaque déjà un laboratoire.' end end
    local now = os.time()
    if not LabRules.InSchedule(S, now) then return false, 'Hors des horaires d\'attaque.' end
    local labWait = (lab.lastRaid or 0) + S.labCooldown * 60 - now
    if labWait > 0 then return false, ('Ce laboratoire a été attaqué récemment (encore %d min).'):format(math.ceil(labWait / 60)) end
    local gWait = (groupLast[g.id] or 0) + S.groupCooldown * 60 - now
    if gWait > 0 then return false, ('Ton groupe doit attendre %d min avant une nouvelle attaque.'):format(math.ceil(gWait / 60)) end
    if not alive(src) or not inZone(src, lab, S.radius) then return false, 'Tu dois être vivant dans la zone.' end
    local a = countIn(g.id, lab, S.radius)
    if a < S.minAttackers then return false, ('Il faut %d attaquant(s) vivant(s) dans la zone (%d).'):format(S.minAttackers, a) end
    local def = #L.GroupOnline(lab.owner)
    if def < S.minDefendersOnline then return false, ('Il faut au moins %d défenseur(s) connecté(s).'):format(S.minDefendersOnline) end
    return true
end

-- État envoyé aux membres connectés des deux groupes (zone, compte à rebours, effectifs)
local function stateFor(r, side)
    local lab = L.list[r.lab]
    local now = os.time()
    return { lab = r.lab, name = lab and lab.name or '?', x = lab and lab.x, y = lab and lab.y, z = lab and lab.z, radius = r.radius,
        status = r.status, side = side, remaining = r.status == 'preparing' and (r.prepEnd - now) or ((r.endAt or now) - now),
        attackers = r.a or 0, defenders = r.d or 0, grace = r.emptySince and math.max(0, L.Raids().emptyGrace - (now - r.emptySince)) or nil,
        attackerLabel = r.attackerLabel, defenderLabel = r.defenderLabel, rule = L.Raids().winRule }
end
local function broadcast(r)
    for _, m in ipairs(L.GroupOnline(r.attacker)) do TriggerClientEvent('elyzea_labs:raid', m.src, stateFor(r, 'attack')) end
    for _, m in ipairs(L.GroupOnline(r.defender)) do TriggerClientEvent('elyzea_labs:raid', m.src, stateFor(r, 'defend')) end
end
function L.SendRaidState(src)
    local g = L.PlayerGroup(src)
    if not g then return end
    for _, r in pairs(raids) do
        if r.attacker == g.id then TriggerClientEvent('elyzea_labs:raid', src, stateFor(r, 'attack'))
        elseif r.defender == g.id then TriggerClientEvent('elyzea_labs:raid', src, stateFor(r, 'defend')) end
    end
end

local LABELS = { success = 'réussie', failed = 'échouée', cancelled = 'annulée' }

local function finish(r, status, reason)
    if raids[r.lab] ~= r then return end
    raids[r.lab] = nil
    local lab = L.list[r.lab]
    local now = os.time()
    if lab and status ~= 'cancelled' then lab.lastRaid = now end
    if status ~= 'cancelled' then groupLast[r.attacker] = now end
    if status == 'success' and lab then
        local ok, err = L.Transfer(lab, r.attacker, 'capture', ('Attaque #%d'):format(r.id or 0))
        if not ok then status, reason = 'failed', 'Transfert impossible : ' .. tostring(err) end
    end
    if r.id then MySQL.update('UPDATE `labs_raids` SET `status` = ?, `reason` = ?, `ended_at` = NOW() WHERE `id` = ?', { status, tostring(reason or ''):sub(1, 255), r.id }) end
    local name = lab and lab.name or '?'
    if status == 'success' then
        notifySide(r.attacker, ('🏴 Capture réussie : « %s » appartient maintenant à ton groupe (niveau, équipements et coffre compris).'):format(name), 'success')
        notifySide(r.defender, ('🏴 « %s » a été capturé par %s.'):format(name, r.attackerLabel), 'error')
    elseif status == 'failed' then
        notifySide(r.attacker, ('Attaque de « %s » échouée : %s'):format(name, reason or ''), 'error')
        notifySide(r.defender, ('🛡️ « %s » défendu avec succès : %s'):format(name, reason or ''), 'success')
    else
        notifySide(r.attacker, ('Attaque de « %s » annulée : %s'):format(name, reason or ''), 'inform')
        notifySide(r.defender, ('Attaque de « %s » annulée : %s'):format(name, reason or ''), 'inform')
    end
    local done = { lab = r.lab, status = 'end', result = status, reason = reason }
    for _, gid in ipairs({ r.attacker, r.defender }) do
        for _, m in ipairs(L.GroupOnline(gid)) do TriggerClientEvent('elyzea_labs:raid', m.src, done) end
    end
    L.Log(r.lab, 'attaque', r.starter, ('%s contre %s : %s (%s)'):format(r.attackerLabel, r.defenderLabel, LABELS[status] or status, reason or ''))
    L.PushLabs()
end
L.FinishRaid = finish

function L.CancelRaid(labId, reason)
    local r = raids[labId]
    if not r then return false end
    finish(r, 'cancelled', reason or 'Annulée par le staff')
    return true
end

L.pub.raidStart = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab then return { error = 'Laboratoire introuvable.' } end
    if L.Dist(src, lab) > 6.0 or GetPlayerRoutingBucket(src) ~= 0 then return { error = 'Va à l\'entrée du laboratoire.' } end
    if not L.Lock('raid:' .. lab.id) then return { error = 'Patiente.' } end
    local g = L.PlayerGroup(src)
    local ok, why = L.RaidCheck(src, lab, g)
    if not ok then L.Unlock('raid:' .. lab.id) return { error = why } end
    local S = L.Raids()
    local r = { lab = lab.id, attacker = g.id, defender = lab.owner, attackerLabel = g.label, defenderLabel = L.GroupLabel(lab.owner),
        status = 'preparing', prepEnd = os.time() + S.prepSeconds, radius = S.radius, starter = L.Name(src), a = 0, d = 0 }
    raids[lab.id] = r
    L.Unlock('raid:' .. lab.id)
    r.id = MySQL.insert.await('INSERT INTO `labs_raids` (`lab_id`, `attacker_group`, `defender_group`, `attacker_label`, `defender_label`, `status`, `started_by`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { lab.id, g.id, lab.owner, g.label, r.defenderLabel, 'preparing', r.starter })
    notifySide(r.defender, ('⚠️ Ton laboratoire « %s » est attaqué par %s ! Début dans %d s.'):format(lab.name, g.label, S.prepSeconds), 'error')
    notifySide(r.attacker, ('Attaque de « %s » lancée : début dans %d s. Restez vivants dans la zone (%d m) pendant %d min.'):format(
        lab.name, S.prepSeconds, math.floor(S.radius), math.floor(S.duration / 60)), 'success')
    broadcast(r)
    L.PushLabs()
    return { ok = true, message = 'Attaque lancée.' }
end

-- Tablette (droit « raid ») : attaque en cours et historique de ce laboratoire
function L.RaidHistory(labId, limit)
    local rows = MySQL.query.await(('SELECT `id`, `attacker_label`, `defender_label`, `status`, `reason`, `started_by`, UNIX_TIMESTAMP(`started_at`) AS `t`, UNIX_TIMESTAMP(`ended_at`) AS `e` FROM `labs_raids` %s ORDER BY `id` DESC LIMIT %d')
        :format(labId and 'WHERE `lab_id` = ?' or '', limit or 20), labId and { labId } or {}) or {}
    return rows
end

-- Boucle (1 s) seulement quand il y a des attaques
CreateThread(function()
    local tick = 0
    while true do
        if next(raids) == nil then Wait(1500) else
            Wait(1000)
            tick = tick + 1
            local now = os.time()
            local S = L.Raids()
            for _, r in pairs(raids) do
                local lab = L.list[r.lab]
                if not lab or lab.owner ~= r.defender or lab.disabled then
                    finish(r, 'cancelled', 'Le laboratoire a changé')
                elseif r.status == 'preparing' then
                    if now >= r.prepEnd then
                        r.status, r.endAt = 'active', now + S.duration
                        if r.id then MySQL.update('UPDATE `labs_raids` SET `status` = \'active\' WHERE `id` = ?', { r.id }) end
                        notifySide(r.attacker, ('L\'attaque de « %s » commence : %d min.'):format(lab.name, math.floor(S.duration / 60)), 'error')
                        notifySide(r.defender, ('L\'attaque de « %s » commence : défendez la zone !'):format(lab.name), 'error')
                        broadcast(r)
                    end
                else
                    r.a, r.d = countIn(r.attacker, lab, r.radius), countIn(r.defender, lab, r.radius)
                    if r.a == 0 then
                        r.emptySince = r.emptySince or now
                        if now - r.emptySince >= S.emptyGrace then
                            finish(r, 'failed', 'Plus aucun attaquant vivant dans la zone.')
                            goto continue
                        end
                    else
                        r.emptySince = nil
                    end
                    if now >= r.endAt then
                        local win = (S.winRule == 'majority') and (r.a > r.d) or (r.a >= 1)
                        if win then finish(r, 'success', ('%d attaquant(s) dans la zone à la fin.'):format(r.a))
                        else finish(r, 'failed', S.winRule == 'majority' and 'Les défenseurs tiennent la zone.' or 'Aucun attaquant dans la zone à la fin.') end
                        goto continue
                    end
                end
                if raids[r.lab] == r and tick % 2 == 0 then broadcast(r) end
                ::continue::
            end
        end
    end
end)
