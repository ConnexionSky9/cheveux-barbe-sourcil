-- =====================================================================
--  ELYZEA EMS - serveur : blessures RP localisées (hémorragies, fractures, lésions internes)
--  · Table ems_injuries : une ligne par blessure, gardée pour l'historique du dossier.
--  · Créées par le serveur : coups reçus (zone et type d'arme signalés par le client,
--    gravité décidée ici, fréquence plafonnée), chute de haut, staff (admin_menu › Santé).
--  · Statuts : active → (hémorragie) controlled → healed ; (fracture) active → treated → healed.
--  · Seul le joueur concerné reçoit ses effets (saignement) ; les EMS les voient à l'examen.
-- =====================================================================
local P = Ems
local PR = ProcRules
local core = exports.elyzea_core

P.Tables.ems_injuries = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `type` VARCHAR(12) NOT NULL,
    `zone` VARCHAR(20) NOT NULL,
    `severity` TINYINT NOT NULL DEFAULT 1,
    `status` VARCHAR(12) NOT NULL DEFAULT 'active',
    `source` VARCHAR(40) NULL,
    `created_at` INT UNSIGNED NOT NULL,
    `xray_at` INT UNSIGNED NULL,
    `seen_at` INT UNSIGNED NULL,
    `treated_at` INT UNSIGNED NULL,
    `treated_by` VARCHAR(100) NULL,
    `heal_at` INT UNSIGNED NULL,
    `healed_at` INT UNSIGNED NULL,
    `note` VARCHAR(160) NULL,
    INDEX (`citizenid`, `status`) ) ]]
P.TableOrder[#P.TableOrder + 1] = 'ems_injuries'

P.injuries = {}   -- [src] = { cid, list = { blessures non guéries } }

local function Row(r)
    return { id = tonumber(r.id), type = r.type, zone = r.zone, severity = tonumber(r.severity) or 1, status = r.status,
        created = tonumber(r.created_at), xray = tonumber(r.xray_at), seen = tonumber(r.seen_at), treated = tonumber(r.treated_at),
        treatedBy = r.treated_by, healAt = tonumber(r.heal_at), healed = tonumber(r.healed_at), source = r.source, note = r.note }
end

-- Effets pour le joueur seul : saignement actif (perte de santé lente, jamais mortelle)
function P.InjuryPush(src)
    local h = P.injuries[src]
    if not h then return end
    local set = P.ProcSettings()
    local worst = PR.WorstBleed(h.list)
    local lv = worst and worst.severity or 0
    TriggerClientEvent('ems:client:injuries', src, { bleed = lv, drain = set.injuries.drain[lv] or 0, floor = set.injuries.drainFloor })
end

local function Load(src)
    local cid = P.Cid(src)
    if not cid then return end
    local h = { cid = cid, list = {} }
    for _, r in ipairs(MySQL.query.await("SELECT * FROM `ems_injuries` WHERE `citizenid` = ? AND `status` <> 'healed' ORDER BY `id`", { cid }) or {}) do
        h.list[#h.list + 1] = Row(r)
    end
    P.injuries[src] = h
    P.InjuryPush(src)
end
P.InjuryLoad = Load

AddEventHandler('elyzea:server:playerLoaded', function(src) SetTimeout(3500, function() if GetPlayerName(src) then Load(src) end end) end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) P.injuries[tonumber(src) or -1] = nil end)
AddEventHandler('playerDropped', function() P.injuries[source] = nil end)
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    CreateThread(function() for src in pairs(core:GetPlayers()) do pcall(Load, src) Wait(50) end end)
end

-- Blessures non guéries d'un joueur connecté (src) ou d'un dossier (cid)
function P.InjuryList(src, cid)
    if src then
        if not P.injuries[src] then Load(src) end
        return P.injuries[src] and P.injuries[src].list or {}
    end
    local out = {}
    for _, r in ipairs(MySQL.query.await("SELECT * FROM `ems_injuries` WHERE `citizenid` = ? AND `status` <> 'healed' ORDER BY `id`", { cid }) or {}) do out[#out + 1] = Row(r) end
    return out
end

function P.InjuryGet(src, id)
    for _, inj in ipairs(P.InjuryList(src)) do if inj.id == tonumber(id) then return inj end end
    return nil
end

-- Ajoute une blessure. Même type et même zone déjà actifs : on garde la plus grave (pas de doublon)
function P.InjuryAdd(src, kind, zone, severity, source)
    local set = P.ProcSettings()
    if not set.zoneById[zone or ''] then return false, 'Zone inconnue.' end
    if kind ~= 'hemorrhage' and kind ~= 'fracture' and kind ~= 'internal' then return false, 'Type inconnu.' end
    local h = P.injuries[src]
    if not h then Load(src) h = P.injuries[src] end
    if not h then return false, 'Personnage non chargé.' end
    severity = math.floor(PR.Num(severity, 1, kind == 'hemorrhage' and 3 or 2, 1))
    local now = os.time()
    for _, inj in ipairs(h.list) do
        if inj.type == kind and inj.zone == zone and (inj.status == 'active' or (kind == 'hemorrhage' and inj.status == 'controlled')) then
            if severity > inj.severity or inj.status ~= 'active' then
                inj.severity, inj.status = math.max(severity, inj.severity), 'active'
                MySQL.update.await('UPDATE `ems_injuries` SET `severity` = ?, `status` = \'active\' WHERE `id` = ?', { inj.severity, inj.id })
                P.InjuryPush(src)
            end
            return true, inj.id
        end
    end
    local active = 0
    for _, inj in ipairs(h.list) do if inj.status ~= 'healed' then active = active + 1 end end
    if active >= set.injuries.maxActive then return false, 'Trop de blessures.' end
    local id = MySQL.insert.await([[INSERT INTO `ems_injuries` (`citizenid`, `type`, `zone`, `severity`, `status`, `source`, `created_at`) VALUES (?, ?, ?, ?, 'active', ?, ?)]],
        { h.cid, kind, zone, severity, tostring(source or ''):sub(1, 40), now })
    if not id then return false, 'Erreur base de données.' end
    h.list[#h.list + 1] = { id = id, type = kind, zone = zone, severity = severity, status = 'active', created = now, source = source }
    P.InjuryPush(src)
    return true, id
end

-- Change le statut d'une blessure (soin, guérison) et met la base à jour
function P.InjurySet(src, id, fields)
    local inj = P.InjuryGet(src, id)
    if not inj then return false end
    local cols, vals = {}, {}
    for k, col in pairs({ status = 'status', xray = 'xray_at', seen = 'seen_at', treated = 'treated_at', treatedBy = 'treated_by', healAt = 'heal_at', healed = 'healed_at', note = 'note' }) do
        if fields[k] ~= nil then inj[k] = fields[k] cols[#cols + 1] = ('`%s` = ?'):format(col) vals[#vals + 1] = fields[k] end
    end
    if #cols == 0 then return true end
    vals[#vals + 1] = inj.id
    MySQL.update.await(('UPDATE `ems_injuries` SET %s WHERE `id` = ?'):format(table.concat(cols, ', ')), vals)
    if inj.status == 'healed' then
        local h = P.injuries[src]
        for i, x in ipairs(h and h.list or {}) do if x.id == inj.id then table.remove(h.list, i) break end end
    end
    P.InjuryPush(src)
    return true
end

-- Soin terminé : guérie tout de suite, ou après le délai réglé (healMinutes)
function P.InjuryTreated(src, id, by, status)
    local now = os.time()
    local heal = P.ProcSettings().injuries.healMinutes
    if heal > 0 and status ~= 'healed' then
        return P.InjurySet(src, id, { status = status or 'treated', treated = now, treatedBy = by, healAt = now + heal * 60 })
    end
    return P.InjurySet(src, id, { status = 'healed', treated = now, treatedBy = by, healed = now })
end

-- Historique pour le dossier médical
function P.InjuryHistory(cid)
    local set, out = P.ProcSettings(), {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `ems_injuries` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 40', { cid }) or {}) do
        local v = Row(r)
        local z = set.zoneById[v.zone]
        v.zoneLabel = z and z.label or v.zone
        v.label = PR.InjuryLabel(set, v)
        out[#out + 1] = v
    end
    return out
end

-- Vue pour l'examen EMS (seulement ce qui est observable : saignement, membre déformé, signes)
function P.InjuryExamView(src)
    local set, out = P.ProcSettings(), {}
    for _, inj in ipairs(P.InjuryList(src)) do
        local z = set.zoneById[inj.zone]
        local v = { id = inj.id, type = inj.type, zone = inj.zone, zoneLabel = z and z.label or inj.zone, severity = inj.severity, status = inj.status }
        if inj.type == 'hemorrhage' then v.label = PR.InjuryLabel(set, inj)
        elseif inj.type == 'fracture' then v.label = inj.xray and PR.InjuryLabel(set, inj) or 'Douleur, membre à radiographier'
        else v.label = inj.seen and PR.InjuryLabel(set, inj) or 'Signes de traumatisme (imagerie conseillée)' end
        v.known = inj.type == 'hemorrhage' or inj.xray ~= nil or inj.seen ~= nil
        out[#out + 1] = v
    end
    return out
end

-- ---------------------------------------------------------------------
-- Coups reçus : signalés par le client du blessé (plafonnés et revérifiés ici)
-- ---------------------------------------------------------------------
local lastHit = {}
local GROUPS = { bullet = true, blade = true, blunt = true, vehicle = true }
RegisterNetEvent('ems:server:injury', function(zone, group, damage)
    local src = tonumber(source)
    local set = P.ProcSettings()
    if not src or not set.injuries.enabled or not P.injuries[src] then return end
    if type(zone) ~= 'string' or not GROUPS[group] then return end
    local now = os.time()
    if lastHit[src] and now - lastHit[src] < set.injuries.cooldown then return end
    damage = PR.Num(damage, 0, 200, 0)
    local r = PR.InjuryFromDamage(set, zone, group, damage)
    if not r then return end
    lastHit[src] = now
    P.InjuryAdd(src, r.type, zone, r.severity, group)
end)
AddEventHandler('playerDropped', function() lastHit[source] = nil end)

-- Chute de haut : appelé par server/health.lua après la blessure à la jambe
function P.InjuryFall(src, height)
    local set = P.ProcSettings()
    if not set.injuries.enabled then return end
    local f = PR.FallFracture(set, height)
    P.InjuryAdd(src, f.type, f.zone, f.severity, 'chute')
end

-- Réapparition à l'hôpital : hémorragies et lésions internes prises en charge par l'hôpital
-- (les fractures restent : il faut une radiographie puis une attelle / un plâtre)
function P.InjuryHospital(src)
    for _, inj in ipairs(PR.Copy(P.InjuryList(src))) do
        if inj.type ~= 'fracture' then P.InjurySet(src, inj.id, { status = 'healed', healed = os.time(), treatedBy = 'Hôpital' }) end
    end
end

-- Guérisons différées (healMinutes)
CreateThread(function()
    while not P.ready do Wait(1000) end
    while true do
        Wait(60000)
        local now = os.time()
        for src, h in pairs(P.injuries) do
            if not GetPlayerName(src) then P.injuries[src] = nil else
                for _, inj in ipairs(PR.Copy(h.list)) do
                    if inj.healAt and inj.healAt <= now and inj.status ~= 'healed' then P.InjurySet(src, inj.id, { status = 'healed', healed = now }) end
                end
            end
        end
    end
end)
