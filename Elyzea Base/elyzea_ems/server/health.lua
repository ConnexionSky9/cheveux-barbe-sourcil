-- =====================================================================
--  ELYZEA EMS - serveur : maladies et blessures
--  · Rhume : attrapé au hasard ou près d'un malade, part tout seul (ou traitement EMS).
--  · Chute de haut (à pied) : blessure à la jambe, le joueur boite jusqu'à la pose
--    d'une attelle par un EMS (ALT › « Poser une attelle »).
--  · MST : transmises lors d'un moment intime sans préservatif (elyzea_famille),
--    découvertes par un examen EMS, soignées par un traitement EMS.
--  · Tout se règle et se gère dans admin_menu › Santé.
--  · Les effets sont envoyés au seul joueur concerné (rien n'est visible des autres).
-- =====================================================================
local P = Ems
local HR = HealthRules
local core = exports.elyzea_core
local KEY = 'health'

P.Tables.ems_conditions = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `kind` VARCHAR(30) NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `diagnosed` TINYINT(1) NOT NULL DEFAULT 0,
    `splinted` TINYINT(1) NOT NULL DEFAULT 0,
    `source` VARCHAR(40) NULL,
    `contracted_at` INT UNSIGNED NOT NULL,
    `expires_at` INT UNSIGNED NULL,
    `cured_at` INT UNSIGNED NULL,
    `cured_by` VARCHAR(100) NULL,
    INDEX (`citizenid`, `active`) ) ]]
P.TableOrder[#P.TableOrder + 1] = 'ems_conditions'

-- ---------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------
local S
function P.HealthSettings()
    if not S then S = HR.Settings(Config.Health, P.GetSetting(KEY, {})) end
    return S
end
function P.HealthSave(input)
    P.SetSetting(KEY, HR.CleanSaved(input, Config.Health))
    S = nil
    for src in pairs(P.health) do P.HealthPush(src) end
end

-- ---------------------------------------------------------------------
-- État des joueurs connectés
-- ---------------------------------------------------------------------
P.health = {}   -- [src] = { cid, active = { [kind] = { id, since, expires, diagnosed, splinted } } }

local function RowView(r)
    return { id = r.id, since = tonumber(r.contracted_at), expires = tonumber(r.expires_at), diagnosed = tonumber(r.diagnosed) == 1, splinted = tonumber(r.splinted) == 1 }
end

function P.HealthPush(src)
    local h = P.health[src]
    if not h then return end
    TriggerClientEvent('ems:client:health', src, HR.Effects(h.active, P.HealthSettings()))
end

local function Load(src)
    local cid = P.Cid(src)
    if not cid then return end
    local h = { cid = cid, active = {} }
    local now = os.time()
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `ems_conditions` WHERE `citizenid` = ? AND `active` = 1', { cid }) or {}) do
        if r.expires_at and tonumber(r.expires_at) <= now then
            MySQL.update('UPDATE `ems_conditions` SET `active` = 0, `cured_at` = ? WHERE `id` = ?', { now, r.id })
        elseif not h.active[r.kind] then
            h.active[r.kind] = RowView(r)
        end
    end
    P.health[src] = h
    P.HealthPush(src)
end

AddEventHandler('elyzea:server:playerLoaded', function(src) SetTimeout(3000, function() if GetPlayerName(src) then Load(src) end end) end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) P.health[tonumber(src) or -1] = nil end)
AddEventHandler('playerDropped', function() P.health[source] = nil end)
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    CreateThread(function()
        for src in pairs(core:GetPlayers()) do pcall(Load, src) Wait(50) end
    end)
end

local MSG_GOT = {
    cold = 'Vous avez attrapé un rhume. Il passera tout seul, ou un EMS peut vous donner un traitement.',
    leg = 'Vous vous êtes blessé à la jambe en tombant : vous boitez. Allez à l\'hôpital ou appelez les EMS pour une attelle.',
}
local MSG_CURED = {
    cold = 'Votre rhume est passé.',
    leg = 'Votre jambe est guérie.',
}

-- Donne une maladie / blessure. src (connecté) ou cid (absent). Renvoie true si ajoutée.
function P.HealthGive(src, kind, source, cid)
    local c = P.HealthSettings().conditions[kind]
    if not c then return false, 'Maladie inconnue.' end
    if src then cid = P.Cid(src) end
    if not cid then return false, 'Personnage non chargé.' end
    local h = src and P.health[src]
    if src and not h then Load(src) h = P.health[src] end
    if h and h.active[kind] then return false, 'Déjà atteint.' end
    if not h then
        local n = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `ems_conditions` WHERE `citizenid` = ? AND `kind` = ? AND `active` = 1', { cid, kind })) or 0
        if n > 0 then return false, 'Déjà atteint.' end
    end
    local now = os.time()
    local exp = HR.ExpiresAt(c, now)
    local id = MySQL.insert.await([[INSERT INTO `ems_conditions` (`citizenid`, `kind`, `diagnosed`, `source`, `contracted_at`, `expires_at`) VALUES (?, ?, ?, ?, ?, ?)]],
        { cid, kind, c.known and 1 or 0, tostring(source or ''):sub(1, 40), now, exp })
    if h and id then
        h.active[kind] = { id = id, since = now, expires = exp, diagnosed = c.known, splinted = false }
        P.HealthPush(src)
        if c.known then P.Notify(src, MSG_GOT[kind] or ('Vous êtes atteint : %s.'):format(c.label), 'error') end
    end
    return id ~= nil
end

-- Guérit. by = nom de l'EMS / « Staff » / nil (guérison naturelle)
function P.HealthCure(src, kind, by, cid)
    if src then cid = P.Cid(src) end
    if not cid then return false end
    local now = os.time()
    local n = MySQL.update.await('UPDATE `ems_conditions` SET `active` = 0, `cured_at` = ?, `cured_by` = ? WHERE `citizenid` = ? AND `kind` = ? AND `active` = 1',
        { now, by, cid, kind })
    local h = src and P.health[src]
    if h and h.active[kind] then
        h.active[kind] = nil
        P.HealthPush(src)
        local c = P.HealthSettings().conditions[kind]
        P.Notify(src, MSG_CURED[kind] or ('Vous êtes guéri : %s.'):format(c and c.label or kind), 'success')
    end
    return (n or 0) > 0
end

function P.HealthHas(src, kind) local h = P.health[src] return h ~= nil and h.active[kind] ~= nil end

-- Ce qu'un EMS peut soigner chez ce patient avec un geste (« treat » ou « splint »)
function P.HealthCurable(src, cure)
    local h, out = P.health[src], {}
    if not h then return out end
    local set = P.HealthSettings()
    for kind, r in pairs(h.active) do
        local c = set.conditions[kind]
        if c and c.cure == cure and not (cure == 'splint' and r.splinted) then out[#out + 1] = kind end
    end
    return out
end

-- Geste EMS : traitement (rhume, MST) ou attelle (jambe)
function P.HealthTreat(target, cure, emsSrc)
    local kinds = P.HealthCurable(target, cure)
    if #kinds == 0 then return false end
    local by = P.Name(emsSrc)
    if cure == 'splint' then
        local heal = P.HealthSettings().splint.healMinutes
        for _, kind in ipairs(kinds) do
            if heal > 0 then
                local h = P.health[target]
                local exp = os.time() + heal * 60
                MySQL.update.await('UPDATE `ems_conditions` SET `splinted` = 1, `diagnosed` = 1, `expires_at` = ? WHERE `id` = ?', { exp, h.active[kind].id })
                h.active[kind].splinted, h.active[kind].expires, h.active[kind].diagnosed = true, exp, true
                P.HealthPush(target)
                P.Notify(target, ('Attelle posée par %s : plus de boiterie, évitez de courir pendant %d min.'):format(by, heal), 'success')
            else
                P.HealthCure(target, kind, by)
            end
        end
    else
        for _, kind in ipairs(kinds) do P.HealthCure(target, kind, by) end
    end
    return true
end

-- Examen EMS : tout ce qui est en cours est découvert (le patient le voit ensuite dans l'application Santé)
function P.HealthDiagnose(target)
    local h, out = P.health[target], {}
    if not h then return out end
    local set = P.HealthSettings()
    local newly = false
    for kind, r in pairs(h.active) do
        local c = set.conditions[kind]
        if c then
            if not r.diagnosed then
                r.diagnosed = true
                newly = true
                MySQL.update('UPDATE `ems_conditions` SET `diagnosed` = 1 WHERE `id` = ?', { r.id })
            end
            out[#out + 1] = { kind = kind, label = c.label, type = c.type, cure = c.cure, splinted = r.splinted, since = r.since }
        end
    end
    if newly then P.Notify(target, 'L\'examen a révélé un problème de santé : consultez l\'application Santé de votre téléphone.', 'inform') end
    table.sort(out, function(a, b) return a.since < b.since end)
    return out
end

-- Historique pour le dossier médical
function P.HealthHistory(cid)
    local set, out = P.HealthSettings(), {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `ems_conditions` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 40', { cid }) or {}) do
        local c = set.conditions[r.kind]
        out[#out + 1] = { kind = r.kind, label = c and c.label or r.kind, type = c and c.type or 'illness', active = tonumber(r.active) == 1,
            diagnosed = tonumber(r.diagnosed) == 1, splinted = tonumber(r.splinted) == 1, since = tonumber(r.contracted_at),
            cured = tonumber(r.cured_at), curedBy = r.cured_by }
    end
    return out
end

-- Ce que le joueur sait de sa santé (application Santé) : seulement ce qui est connu ou diagnostiqué
function P.HealthMine(src)
    local cid = P.Cid(src)
    if not cid then return { error = 'Personnage non chargé.' } end
    local set, cur, past = P.HealthSettings(), {}, {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `ems_conditions` WHERE `citizenid` = ? AND (`diagnosed` = 1) ORDER BY `id` DESC LIMIT 25', { cid }) or {}) do
        local c = set.conditions[r.kind]
        local v = { kind = r.kind, label = c and c.label or r.kind, type = c and c.type or 'illness', cure = c and c.cure or 'treat',
            splinted = tonumber(r.splinted) == 1, since = tonumber(r.contracted_at), expires = tonumber(r.expires_at), cured = tonumber(r.cured_at), curedBy = r.cured_by }
        if tonumber(r.active) == 1 then cur[#cur + 1] = v else past[#past + 1] = v end
    end
    return { ok = true, current = cur, past = past, now = os.time() }
end

-- ---------------------------------------------------------------------
-- Chute (signalée par le client, plafonnée et limitée par le serveur)
-- ---------------------------------------------------------------------
local lastFall = {}
RegisterNetEvent('ems:server:fall', function(height)
    local src = tonumber(source)
    if not src or not P.health[src] then return end
    local set = P.HealthSettings()
    if not set.enabled then return end
    local now = os.time()
    if lastFall[src] and now - lastFall[src] < 10 then return end
    lastFall[src] = now
    -- (une chute qui met à terre blesse aussi la jambe : on boite après la réanimation)
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return end
    if HR.FallInjury(height, set) and not P.HealthHas(src, 'leg') then P.HealthGive(src, 'leg', 'chute') end
end)
AddEventHandler('playerDropped', function() lastFall[source] = nil end)

-- ---------------------------------------------------------------------
-- MST : moment intime terminé sans préservatif (elyzea_famille)
-- ---------------------------------------------------------------------
local function KindsOf(cid)
    local s = core:GetSourceByCitizenId(cid)
    local h = s and P.health[s]
    local kinds = {}
    if h then
        for k in pairs(h.active) do kinds[k] = true end
    else
        for _, r in ipairs(MySQL.query.await('SELECT `kind` FROM `ems_conditions` WHERE `citizenid` = ? AND `active` = 1', { cid }) or {}) do kinds[r.kind] = true end
    end
    return kinds, s
end
AddEventHandler('elyzea_famille:server:momentIntime', function(aCid, bCid, protected, pct)
    local set = P.HealthSettings()
    if not set.enabled or not aCid or not bCid then return end
    local ka, sa = KindsOf(aCid)
    local kb, sb = KindsOf(bCid)
    for _, t in ipairs(HR.Transmissions({ cid = aCid, kinds = ka }, { cid = bCid, kinds = kb }, protected == true, pct, set)) do
        local s = t.cid == aCid and sa or sb
        P.HealthGive(s, t.kind, 'transmission', t.cid)
    end
end)

-- ---------------------------------------------------------------------
-- Boucle : guérisons naturelles, rhume au hasard, contagion
-- ---------------------------------------------------------------------
CreateThread(function()
    while not P.ready do Wait(1000) end
    while true do
        local set = P.HealthSettings()
        local ok, err = pcall(function()
            if not set.enabled then return end
            local now = os.time()
            local cold = set.conditions.cold
            local sick = {}
            for src, h in pairs(P.health) do
                if not GetPlayerName(src) then P.health[src] = nil else
                    for kind, r in pairs(h.active) do
                        if r.expires and r.expires <= now then P.HealthCure(src, kind, nil) end
                    end
                    if cold and cold.enabled and not h.active.cold and HR.Roll(HR.TickChance(cold.randomPerHour, set.tick)) then
                        P.HealthGive(src, 'cold', 'hasard')
                    end
                    if h.active.cold then sick[#sick + 1] = src end
                end
            end
            -- Contagion du rhume : quelques minutes près d'un malade
            if cold and cold.enabled and cold.contagionChance > 0 and #sick > 0 then
                local chance = HR.ContagionTickChance(cold.contagionChance, set.tick)
                for src, h in pairs(P.health) do
                    if not h.active.cold then
                        local c = P.Coords(src)
                        for _, s in ipairs(sick) do
                            local cs = P.Coords(s)
                            if c and cs and #(c - cs) <= cold.contagionRadius then
                                if HR.Roll(chance) then P.HealthGive(src, 'cold', 'contagion') end
                                break
                            end
                        end
                    end
                end
            end
        end)
        if not ok then print(('^1[EMS] Santé : %s^0'):format(tostring(err))) end
        Wait((set.tick or 60) * 1000)
    end
end)

-- ---------------------------------------------------------------------
-- Staff (admin_menu › Santé) : un seul export, l'admin_menu vérifie les droits du staff
-- ---------------------------------------------------------------------
local function OnlineList()
    local set, out = P.HealthSettings(), {}
    for src in pairs(core:GetPlayers()) do
        local h = P.health[src]
        local conds = {}
        for kind, r in pairs(h and h.active or {}) do
            local c = set.conditions[kind]
            conds[#conds + 1] = { kind = kind, label = c and c.label or kind, splinted = r.splinted, diagnosed = r.diagnosed, since = r.since, expires = r.expires }
        end
        out[#out + 1] = { id = src, name = P.Name(src), conditions = conds }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function AdminData()
    local set = P.HealthSettings()
    local conds = {}
    for _, id in ipairs(set.order) do conds[#conds + 1] = set.conditions[id] end
    return { ok = true, enabled = set.enabled, fall = set.fall, splint = set.splint, conditions = conds,
        appointments = P.ApptSettings(), points = P.RecordsPoints(), players = OnlineList() }
end

exports('HealthAdmin', function(op, src, d)
    d = type(d) == 'table' and d or {}
    local staff = ('Staff · %s'):format(GetPlayerName(src) or '?')
    if op == 'data' then return AdminData() end
    if op == 'save' then
        P.HealthSave(d.health)
        if type(d.appointments) == 'table' then P.ApptSaveSettings(d.appointments) end
        P.Log(src, 'Santé : réglages enregistrés', staff)
        return { ok = true, message = 'Réglages de santé enregistrés.' }
    end
    if op == 'give' or op == 'cure' then
        local t = tonumber(d.target)
        if not t or not GetPlayerName(t) then return { error = 'Joueur introuvable.' } end
        local kind = tostring(d.kind or '')
        if not P.HealthSettings().conditions[kind] then return { error = 'Maladie inconnue.' } end
        if op == 'give' then
            local ok, why = P.HealthGive(t, kind, 'staff')
            if not ok then return { error = why or 'Impossible.' } end
            P.Log(src, 'Santé : maladie donnée', ('%s → %s'):format(kind, P.Name(t)))
            return { ok = true, message = ('%s : %s.'):format(P.Name(t), P.HealthSettings().conditions[kind].label) }
        end
        if not P.HealthCure(t, kind, 'Staff') then return { error = 'Ce joueur n\'a pas cette maladie.' } end
        P.Log(src, 'Santé : maladie retirée', ('%s → %s'):format(kind, P.Name(t)))
        return { ok = true, message = ('%s est guéri(e).'):format(P.Name(t)) }
    end
    if op == 'cureAll' then
        local t = tonumber(d.target)
        local h = t and P.health[t]
        if not h then return { error = 'Joueur introuvable.' } end
        for kind in pairs(h.active) do P.HealthCure(t, kind, 'Staff') end
        return { ok = true, message = ('%s est complètement guéri(e).'):format(P.Name(t)) }
    end
    if op == 'pointAdd' then
        local ok, msg = P.RecordsPointAdd(src, d.label, staff)
        return ok and { ok = true, message = msg } or { error = msg }
    end
    if op == 'pointRemove' then
        local ok, msg = P.RecordsPointRemove(src, d.id)
        return ok and { ok = true, message = msg } or { error = msg }
    end
    return { error = 'Action inconnue.' }
end)

-- Santé du joueur pour l'application Santé d'Elyzea Aura
exports('HealthMine', function(src) return P.HealthMine(tonumber(src)) end)
