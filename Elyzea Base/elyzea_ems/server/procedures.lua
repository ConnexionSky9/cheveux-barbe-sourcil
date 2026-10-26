-- =====================================================================
--  ELYZEA EMS - serveur : actes médicaux en mini-jeux
--  Un acte se déroule en trois temps, tous vérifiés ici :
--   1. procConsent (si l'acte l'exige) : le patient accepte ou refuse sur son écran ;
--   2. procStart   : permission, service, grade, distance, état du patient, matériel,
--                    verrous (un acte par EMS, un acte par patient) → défi envoyé au client ;
--   3. procResult  : résultat du mini-jeu vérifié (identifiant, durée réelle, erreurs, choix imposés),
--                    puis distance, état et matériel revérifiés, matériel retiré UNE fois,
--                    effet appliqué, acte enregistré (ems_procedures) et ajouté aux actes facturables.
--  Un acte annulé ou raté n'est jamais enregistré comme soin terminé.
-- =====================================================================
local P = Ems
local PR = ProcRules
local KEY = 'procedures'

P.Tables.ems_procedures = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `uid` VARCHAR(40) NOT NULL UNIQUE,
    `act` VARCHAR(20) NOT NULL,
    `patient_cid` VARCHAR(50) NOT NULL, `patient_name` VARCHAR(100) NULL,
    `ems_cid` VARCHAR(50) NULL, `ems_name` VARCHAR(100) NULL, `ems_grade` VARCHAR(50) NULL,
    `zone` VARCHAR(20) NULL,
    `result` VARCHAR(30) NULL,
    `report` TEXT NULL,
    `items` VARCHAR(255) NULL,
    `score` TINYINT NULL,
    `sensitive` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` INT UNSIGNED NOT NULL,
    INDEX (`patient_cid`), INDEX (`act`) ) ]]
P.Tables.ems_vaccinations = [[ (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `vaccine` VARCHAR(30) NOT NULL,
    `label` VARCHAR(80) NULL,
    `zone` VARCHAR(20) NULL,
    `given_at` INT UNSIGNED NOT NULL,
    `effective_at` INT UNSIGNED NOT NULL,
    `expires_at` INT UNSIGNED NULL,
    `ems_cid` VARCHAR(50) NULL, `ems_name` VARCHAR(100) NULL,
    `proc_uid` VARCHAR(40) NOT NULL UNIQUE,
    INDEX (`citizenid`) ) ]]
P.TableOrder[#P.TableOrder + 1] = 'ems_procedures'
P.TableOrder[#P.TableOrder + 1] = 'ems_vaccinations'

-- ---------------------------------------------------------------------
-- Réglages (config + admin_menu › Santé)
-- ---------------------------------------------------------------------
local S
function P.ProcSettings()
    if S then return S end
    local set = PR.Settings(Config.Procedures, P.GetSetting(KEY, {}))
    if P.ready then S = set end   -- avant le chargement des réglages : pas de cache
    return set
end

local function Publish()
    local set, on = P.ProcSettings(), {}
    for id, a in pairs(set.acts) do on[id] = set.enabled and a.enabled end
    GlobalState.emsProcs = on
end

function P.ProcEnabled(act)
    local set = P.ProcSettings()
    local a = set.acts[act]
    return set.enabled and a ~= nil and a.enabled
end
exports('ProcEnabled', function(act) return P.ProcEnabled(tostring(act or '')) end)

P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    S = nil
    SetTimeout(0, Publish)
    -- Nouvelles permissions données une seule fois aux grades existants
    CreateThread(function()
        while not P.ready do Wait(500) end
        if P.GetSetting('proc_perms_v1') then return end
        local n = 0
        for _, g in pairs(P.grades or {}) do
            local add = {}
            if g.name == 'Directeur' or g.perms.direction then add = { 'imaging', 'vaccinate', 'implant', 'records_sensitive' }
            elseif g.perms.lab_analyze or g.perms.reports_manage then add = { 'imaging', 'vaccinate', 'implant', 'records_sensitive' }
            elseif g.perms.revive then add = { 'imaging', 'vaccinate' } end
            local changed = false
            for _, k in ipairs(add) do if not g.perms[k] then g.perms[k] = true changed = true end end
            if changed then
                MySQL.update.await('UPDATE `ems_grades` SET `perms` = ? WHERE `id` = ?', { P.EncodePerms(g.perms), g.id })
                n = n + 1
            end
        end
        P.SetSetting('proc_perms_v1', os.time())
        if n > 0 then
            print(('^2[EMS] Actes médicaux : permissions ajoutées à %d grade(s) existant(s).^0'):format(n))
            P.PushAll()
        end
    end)
end

-- ---------------------------------------------------------------------
-- Outils
-- ---------------------------------------------------------------------
local active = {}        -- [ems] = { act, target, ch, t0, ctx, items, uid }
local patientBusy = {}   -- [patient] = ems
local consents = {}      -- ['ems:patient:act'] = expiration
local asks = {}          -- [jeton] = { target, ems, p }
local lastStart = {}     -- [ems] = GetGameTimer()

local function Level(src) local g = P.Grade(src) return g and g.level or 0 end
local function Avail(src, act)
    return PR.CanUse(P.ProcSettings(), act, Level(src), function(perm) return P.Can(src, perm) end)
end
local function Inv() return GetResourceState('elyzea_inventory') == 'started' end
local function Fam() return GetResourceState('elyzea_famille') == 'started' end

local function Count(src, name)
    if not Inv() then return 0 end
    local ok, n = pcall(function() return exports.elyzea_inventory:Search(src, 'count', name) end)
    return ok and (tonumber(n) or 0) or 0
end
local function MissingItem(src, list)
    for _, it in ipairs(list or {}) do
        if not Inv() then return it.item end
        if Count(src, it.item) < (it.count or 1) then return it.item end
    end
    return nil
end
local function ItemLabel(name)
    if Inv() then
        local ok, def = pcall(function() return exports.elyzea_inventory:Items(name) end)
        if ok and type(def) == 'table' and def.label then return def.label end
    end
    return name
end
-- Retire le matériel (consume = true). Tout ou rien : ce qui a été retiré est rendu en cas d'échec.
local function Consume(src, list)
    local done = {}
    for _, it in ipairs(list or {}) do
        if it.consume then
            local ok, r = pcall(function() return exports.elyzea_inventory:RemoveItem(src, it.item, it.count or 1) end)
            if not ok or r == false then
                for _, d in ipairs(done) do pcall(function() exports.elyzea_inventory:AddItem(src, d.item, d.count or 1) end) end
                return false, it.item
            end
            done[#done + 1] = it
        end
    end
    return true, done
end
local function Refund(src, done)
    for _, d in ipairs(done or {}) do pcall(function() exports.elyzea_inventory:AddItem(src, d.item, d.count or 1) end) end
end

local function TargetOk(src, id)
    local t = tonumber(id)
    if not t or t == src or not GetPlayerName(t) or not P.GetPlayer(t) then return nil, 'Patient introuvable.' end
    if P.Dist(src, t) > P.ProcSettings().distance + 1.0 then return nil, 'Le patient est trop loin.' end
    if GetVehiclePedIsIn(GetPlayerPed(t), false) ~= 0 then return nil, 'Sortez d\'abord le patient du véhicule.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return nil, 'Descendez du véhicule.' end
    return t
end

local function PatientOk(a, t)
    if a.patient == 'down' and not P.down[t] then return false, 'Le patient n\'est pas inconscient.' end
    if a.patient == 'conscious' and P.down[t] then return false, 'Le patient doit être conscient pour cet acte.' end
    return true
end

local function NeedConsent(a, t)
    if a.consent == 'always' then return true end
    if a.consent == 'conscious' then return P.down[t] == nil end
    return false
end
-- Le consentement vaut pour un acte précis (et pour le vaccin ou le type d'examen accepté)
local function ConsentKey(src, t, act, c)
    local sub = type(c) == 'table' and tostring(c.vaccine or c.type or '') or ''
    return ('%d:%d:%s:%s'):format(src, t, act, sub:sub(1, 30))
end

local function Zone(id) return P.ProcSettings().zoneById[tostring(id or '')] end
local function FindIn(list, id) for _, x in ipairs(list or {}) do if x.id == id then return x end end return nil end

-- Implant (elyzea_famille) : fin de protection en cours (0 = aucun)
local function ImplantUntil(t)
    if not Fam() then return nil end
    local ok, v = pcall(function() return exports.elyzea_famille:ImplantFin(t) end)
    return ok and tonumber(v) or nil
end

-- Hémorragie / fracture du patient par identifiant
local function Injury(t, id, kind)
    local inj = P.InjuryGet(t, id)
    if inj and (not kind or inj.type == kind) then return inj end
    return nil
end

-- ---------------------------------------------------------------------
-- Consentement : demandé au patient sur son écran (jamais décidé par l'EMS)
-- ---------------------------------------------------------------------
local function AskConsent(target, ems, title, text)
    for _, a in pairs(asks) do if a.target == target then return nil, 'Une demande est déjà en attente pour ce patient.' end end
    local timeout = math.min(25, P.ProcSettings().consentTimeout)
    local token = ('%d%06d'):format(os.time() % 100000, math.random(0, 999999))
    local p = promise.new()
    asks[token] = { target = target, ems = ems, p = p }
    TriggerClientEvent('ems:client:consent', target, token, title, text, timeout, P.Name(ems))
    SetTimeout(timeout * 1000 + 1500, function()
        if asks[token] then asks[token] = nil p:resolve('timeout') end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('ems:server:consent', function(token, yes)
    local src = source
    local a = asks[tostring(token)]
    if not a or a.target ~= src then return end
    asks[tostring(token)] = nil
    a.p:resolve(yes == true and 'yes' or 'no')
end)

-- ---------------------------------------------------------------------
-- Choix proposés pour un patient (fenêtre « Actes et examens »)
-- ---------------------------------------------------------------------
local function Options(src, t)
    local set = P.ProcSettings()
    local inj = P.InjuryList(t)
    local down = P.down[t] ~= nil
    local out = {}
    for _, id in ipairs(set.order) do
        local a = set.acts[id]
        local ok, why = Avail(src, id)
        if ok or (a.enabled and set.enabled and why ~= 'Cet acte est désactivé.') then
            local o = { id = id, label = a.label, icon = a.icon, consent = NeedConsent(a, t) }
            if not ok then o.disabled, o.reason = true, why end
            local pOk, pWhy = PatientOk(a, t)
            if not pOk and not o.disabled then o.disabled, o.reason = true, pWhy end
            if a.consent == 'always' and down and not o.disabled then o.disabled, o.reason = true, 'Le patient doit être conscient pour consentir.' end
            if id == 'blood' then
                o.choices = {}
                for _, x in ipairs(set.blood.analyses or {}) do o.choices[#o.choices + 1] = { key = 'analysis', value = x.id, label = x.label } end
            elseif id == 'xray' then
                o.choices = { { key = 'zone', value = 'corps', label = 'Corps entier (radiographie intégrale)' } }
                for _, z in ipairs(set.zones) do if z.xray then o.choices[#o.choices + 1] = { key = 'zone', value = z.id, label = z.label } end end
            elseif id == 'cast' then
                o.choices = {}
                for _, x in ipairs(inj) do
                    if x.type == 'fracture' and x.status == 'active' and (x.xray or not set.cast.requireXray) then
                        local z = set.zoneById[x.zone]
                        for _, m in ipairs(set.cast.materials) do
                            o.choices[#o.choices + 1] = { key = 'injury', value = x.id, material = m.id,
                                label = ('%s · %s'):format(m.label, z and z.label or x.zone), sub = PR.InjuryLabel(set, x),
                                warn = not PR.CastAllowed(m, x) and 'Matériel inadapté à la blessure' or nil }
                        end
                    end
                end
                if #o.choices == 0 and not o.disabled then o.disabled, o.reason = true, 'Aucune lésion radiographiée à immobiliser.' end
            elseif id == 'hemostasis' or id == 'dressing' then
                o.choices = {}
                for _, x in ipairs(inj) do
                    local want = id == 'hemostasis' and x.status == 'active' or (x.status == 'controlled')
                    if x.type == 'hemorrhage' and want then
                        local z = set.zoneById[x.zone]
                        o.choices[#o.choices + 1] = { key = 'injury', value = x.id, label = z and z.label or x.zone, sub = PR.InjuryLabel(set, x) }
                    end
                end
                if #o.choices == 0 and not o.disabled then
                    o.disabled, o.reason = true, id == 'hemostasis' and 'Aucune hémorragie active.' or 'Aucune hémorragie contrôlée à panser.'
                end
                if id == 'hemostasis' and patientBusy[t] and patientBusy[t] ~= src and active[patientBusy[t]] and active[patientBusy[t]].act == 'hemostasis'
                    and P.Can(src, 'stabilize') then
                    o.assist = true
                end
            elseif id == 'echo' then
                o.choices = {}
                for _, x in ipairs(set.echo.types or {}) do
                    if x.id ~= 'pregnancy' or Fam() then o.choices[#o.choices + 1] = { key = 'type', value = x.id, label = x.label } end
                end
            elseif id == 'scan' then
                o.choices = {}
                for _, x in ipairs(set.scan.types or {}) do o.choices[#o.choices + 1] = { key = 'type', value = x.id, label = x.label } end
            elseif id == 'vaccine' then
                o.choices = {}
                for _, v in ipairs(set.vaccines) do
                    if v.enabled then o.choices[#o.choices + 1] = { key = 'vaccine', value = v.id, label = v.label, sub = ItemLabel(v.item) } end
                end
                if #o.choices == 0 and not o.disabled then o.disabled, o.reason = true, 'Aucun vaccin disponible.' end
            elseif id == 'implant' or id == 'implant_remove' then
                local fin = ImplantUntil(t)
                if fin == nil then o.disabled, o.reason = true, 'Module contraception (elyzea_famille) indisponible.'
                elseif id == 'implant_remove' and fin <= os.time() and not o.disabled then o.disabled, o.reason = true, 'Aucun implant en place.' end
            end
            out[#out + 1] = o
        end
    end
    return out
end

P.Actions.procOptions = { perm = 'medical', duty = true, fn = function(src, d)
    if not P.ProcSettings().enabled then return { error = 'Les actes médicaux en mini-jeux sont désactivés.' } end
    local t, why = TargetOk(src, d.target)
    if not t then return { error = why } end
    return { patient = { id = t, name = P.Name(t), down = P.down[t] ~= nil }, acts = Options(src, t) }
end }

-- ---------------------------------------------------------------------
-- Préparation d'un acte : données imposées par le serveur (ctx) et matériel
-- ---------------------------------------------------------------------
local function Prepare(src, t, act, c)
    local set = P.ProcSettings()
    local a = set.acts[act]
    local ctx = { extra = {} }
    local list = {}
    for _, it in ipairs(a.items) do list[#list + 1] = it end
    c = type(c) == 'table' and c or {}
    if act == 'blood' then
        local an = FindIn(set.blood.analyses, tostring(c.analysis or ''))
        if not an then return nil, 'Choisissez l\'analyse à réaliser.' end
        local tubes = {}
        for _, x in ipairs(set.blood.tubes or {}) do tubes[#tubes + 1] = { id = x.id, label = x.label, color = x.color } end
        ctx.analysis = an
        ctx.extra = { tubes = tubes, expect = an.tube, analysis = an.label }
        ctx.title = ('Prise de sang · %s'):format(an.label)
    elseif act == 'xray' and c.zone == 'corps' then
        -- radiographie intégrale (audit V9) : toutes les zones, résultat tiré des blessures enregistrées
        ctx.zone, ctx.full = { id = 'corps', label = 'Corps entier', region = 'body' }, true
        ctx.extra = { zone = 'corps', zoneLabel = 'Corps entier', region = 'body', full = true }
        ctx.title = 'Radiographie intégrale'
    elseif act == 'xray' then
        local z = Zone(c.zone)
        if not z or not z.xray then return nil, 'Choisissez la zone à radiographier.' end
        ctx.zone = z
        ctx.extra = { zone = z.id, zoneLabel = z.label, region = z.region }
        ctx.title = ('Radiographie · %s'):format(z.label)
    elseif act == 'cast' then
        local inj = Injury(t, c.injury, 'fracture')
        local m = FindIn(set.cast.materials, tostring(c.material or ''))
        if not inj or inj.status ~= 'active' then return nil, 'Cette blessure n\'est plus à immobiliser.' end
        if set.cast.requireXray and not inj.xray then return nil, 'Faites d\'abord une radiographie de ce membre.' end
        if not m then return nil, 'Choisissez le matériel.' end
        if not PR.CastAllowed(m, inj) then return nil, ('%s ne convient pas : %s.'):format(m.label, PR.InjuryLabel(set, inj):lower()) end
        local z = set.zoneById[inj.zone]
        ctx.injury, ctx.material, ctx.zone = inj, m, z
        list[#list + 1] = { item = m.item, count = 1, consume = true }
        ctx.extra = { zoneLabel = z and z.label or inj.zone, material = m.id, materialLabel = m.label, region = z and z.region }
        ctx.title = ('%s · %s'):format(m.label, z and z.label or inj.zone)
    elseif act == 'hemostasis' or act == 'dressing' then
        local inj = Injury(t, c.injury, 'hemorrhage')
        if act == 'hemostasis' and (not inj or inj.status ~= 'active') then return nil, 'Cette hémorragie n\'est plus active.' end
        if act == 'dressing' and (not inj or inj.status ~= 'controlled') then return nil, 'Contrôlez d\'abord le saignement par compression.' end
        local z = set.zoneById[inj.zone]
        ctx.injury, ctx.zone, ctx.severity = inj, z, inj.severity
        ctx.extra = { zoneLabel = z and z.label or inj.zone, severity = inj.severity, region = z and z.region,
            seconds = set.hemostasis.seconds[inj.severity], assistBonus = set.hemostasis.assistBonus }
        ctx.title = ('%s · %s'):format(act == 'hemostasis' and 'Compression' or 'Pansement compressif', z and z.label or inj.zone)
    elseif act == 'cpr' then
        local defib = Count(src, set.cpr.defibItem) > 0
        ctx.defib = defib
        ctx.extra = { compressions = set.cpr.compressions, bpm = set.cpr.bpm, defib = defib, pass = set.cpr.passScore }
    elseif act == 'echo' or act == 'scan' then
        local ty = FindIn((act == 'echo' and set.echo or set.scan).types, tostring(c.type or ''))
        if not ty then return nil, 'Choisissez le type d\'examen.' end
        if ty.id == 'pregnancy' and not Fam() then return nil, 'Module grossesse (elyzea_famille) indisponible.' end
        if ty.id == 'pregnancy' and P.down[t] then return nil, 'Le patient doit être conscient pour consentir à ce suivi.' end
        ctx.type = ty
        ctx.extra = { type = ty.id, typeLabel = ty.label }
        ctx.title = ty.label
    elseif act == 'vaccine' then
        local v = set.vaccineById[tostring(c.vaccine or '')]
        if not v or not v.enabled then return nil, 'Choisissez un vaccin disponible.' end
        local cid = P.Cid(t)
        local hist = MySQL.query.await('SELECT `vaccine`, `given_at` FROM `ems_vaccinations` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 30', { cid }) or {}
        local actv = {}
        for kind in pairs((P.health[t] or {}).active or {}) do actv[kind] = true end
        local ok, why = PR.VaccineCheck(v, hist, actv, os.time())
        if not ok then return nil, why end
        list[#list + 1] = { item = v.item, count = 1, consume = true }
        local zones = {}
        for _, z in ipairs(set.injectionZones) do zones[#zones + 1] = { id = z.id, label = z.label } end
        ctx.vaccine = v
        ctx.extra = { zones = zones, expect = v.zone, vaccine = v.label }
        ctx.title = v.label
    elseif act == 'implant' then
        local fin = ImplantUntil(t)
        if fin == nil then return nil, 'Module contraception (elyzea_famille) indisponible.' end
        if fin - os.time() > 24 * 3600 then return nil, 'Un implant est déjà en place.' end
    elseif act == 'implant_remove' then
        local fin = ImplantUntil(t)
        if fin == nil then return nil, 'Module contraception (elyzea_famille) indisponible.' end
        if fin <= os.time() then return nil, 'Aucun implant en place.' end
    end
    ctx.items = list
    return ctx
end

-- ---------------------------------------------------------------------
-- 1. Consentement
-- ---------------------------------------------------------------------
local CONSENT_TEXT = {
    blood = 'propose de vous faire une prise de sang.',
    xray = 'propose de vous faire une radiographie.',
    cast = 'propose de vous poser une attelle ou un plâtre.',
    echo = 'propose de vous faire une échographie.',
    scan = 'propose de vous faire passer un scanner.',
    vaccine = 'propose de vous vacciner.',
    implant = 'propose de vous poser un implant contraceptif.',
    implant_remove = 'propose de retirer votre implant contraceptif.',
}

P.Actions.procConsent = { perm = 'medical', duty = true, fn = function(src, d)
    local act = tostring(d.act or '')
    local set = P.ProcSettings()
    local a = set.acts[act]
    local ok, why = Avail(src, act)
    if not ok then return { error = why } end
    local t
    t, why = TargetOk(src, d.target)
    if not t then return { error = why } end
    if not NeedConsent(a, t) then return { ok = true } end
    if P.down[t] then return { error = 'Le patient doit être conscient pour consentir.' } end
    local key = ConsentKey(src, t, act, d.choice)
    if consents[key] and consents[key] > os.time() then return { ok = true } end
    local extra = ''
    if act == 'echo' and d.label then extra = (' (%s)'):format(P.Clean(d.label, 40)) end
    if act == 'vaccine' and d.label then extra = (' : %s'):format(P.Clean(d.label, 60)) end
    local r = AskConsent(t, src, a.label, ('%s %s%s'):format(P.Name(src), CONSENT_TEXT[act] or 'propose un acte médical.', extra))
    if r == nil then return { error = 'Une demande est déjà en attente pour ce patient.' } end
    if r == 'yes' then
        consents[key] = os.time() + 300
        return { ok = true }
    end
    return { error = r == 'timeout' and 'Le patient n\'a pas répondu.' or 'Le patient a refusé.' }
end }

-- ---------------------------------------------------------------------
-- 2. Début
-- ---------------------------------------------------------------------
local function Release(ems, A)
    if active[ems] == A then active[ems] = nil end
    local t = A and A.target
    if t and patientBusy[t] == ems then
        patientBusy[t] = nil
        if GetPlayerName(t) then
            Player(t).state:set('emsProc', nil, true)
            TriggerClientEvent('ems:client:procRelease', t)
        end
    end
end

P.Actions.procStart = { perm = 'medical', duty = true, fn = function(src, d)
    local act = tostring(d.act or '')
    local set = P.ProcSettings()
    local a = set.acts[act]
    local ok, why = Avail(src, act)
    if not ok then return { error = why } end
    if P.down[src] then return { error = 'Vous êtes à terre.' } end
    local now = GetGameTimer()
    -- acte resté ouvert (client coupé avant le résultat) : libéré après le temps maximum
    local old = active[src]
    if old and now - old.t0 > (old.ch.duration * set.maxRatio + 30) * 1000 then Release(src, old) end
    if active[src] then return { error = 'Vous avez déjà un acte en cours.' } end
    if lastStart[src] and now - lastStart[src] < 1500 then return { error = 'Patientez un instant.' } end
    local t
    t, why = TargetOk(src, d.target)
    if not t then return { error = why } end
    if patientBusy[t] and not active[patientBusy[t]] then patientBusy[t] = nil end
    if patientBusy[t] and patientBusy[t] ~= src then return { error = 'Un autre acte est déjà en cours sur ce patient.' } end
    ok, why = PatientOk(a, t)
    if not ok then return { error = why } end
    if NeedConsent(a, t) then
        local key = ConsentKey(src, t, act, d.choice)
        if not consents[key] or consents[key] <= os.time() then return { error = 'Le consentement du patient est nécessaire.', needConsent = true } end
    end
    local ctx
    ctx, why = Prepare(src, t, act, d.choice)
    if not ctx then return { error = why } end
    local miss = MissingItem(src, ctx.items)
    if miss then return { error = ('Matériel manquant : %s.'):format(ItemLabel(miss)) } end
    local ch = PR.Challenge(act, set, ctx)
    if act == 'cpr' then ch.maxMistakes = set.cpr.compressions + 10 end
    lastStart[src] = now
    active[src] = { act = act, target = t, ch = ch, t0 = now, ctx = ctx }
    patientBusy[t] = src
    Player(t).state:set('emsProc', { act = act, ems = src }, true)
    TriggerClientEvent('ems:client:procPose', t, act, src)
    if act == 'cpr' then TriggerClientEvent('ems:client:treated', t, 'revive', P.Name(src)) end
    return { ok = true, game = ch }
end }

P.Actions.procCancel = { perm = 'medical', fn = function(src)
    local A = active[src]
    if A then Release(src, A) end
    return { ok = true }
end }

-- Aide à la compression (hémorragie critique) : un 2e EMS rejoint l'acte en cours
P.Actions.procAssist = { perm = 'stabilize', duty = true, fn = function(src, d)
    local t, why = TargetOk(src, d.target)
    if not t then return { error = why } end
    local ems = patientBusy[t]
    local A = ems and active[ems]
    if not A or A.act ~= 'hemostasis' or ems == src then return { error = 'Aucune compression en cours sur ce patient.' } end
    if (A.ctx.severity or 1) < 3 then return { error = 'L\'aide n\'est prévue que pour une hémorragie critique.' } end
    if A.assist then return { error = 'Un secouriste aide déjà.' } end
    A.assist = src
    TriggerClientEvent('ems:client:procAssist', ems, P.Name(src))
    return { ok = true, message = ('Vous aidez %s à comprimer.'):format(P.Name(ems)), ems = ems }
end }

-- ---------------------------------------------------------------------
-- 3. Résultat : effets (l'acte n'est appliqué qu'ici, après validation)
-- ---------------------------------------------------------------------
local function Record(uid, src, t, act, zone, result, report, items, score, sensitive)
    local g = P.Grade(src)
    local names = {}
    for _, it in ipairs(items or {}) do names[#names + 1] = ('%s ×%d'):format(it.item, it.count or 1) end
    MySQL.insert.await([[INSERT INTO `ems_procedures` (`uid`, `act`, `patient_cid`, `patient_name`, `ems_cid`, `ems_name`, `ems_grade`, `zone`, `result`, `report`, `items`, `score`, `sensitive`, `created_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { uid, act, P.Cid(t), P.Name(t), P.Cid(src), P.Name(src), g and g.name or nil, zone,
        result, report, #names > 0 and table.concat(names, ', ') or nil, score and math.floor(score * 100 + 0.5) or nil, sensitive and 1 or 0, os.time() })
end

local EFFECT = {}

EFFECT.blood = function(src, t, A)
    local an = A.ctx.analysis
    local tube = FindIn(P.ProcSettings().blood.tubes, an.tube)
    local id, err = EmsLab.CreateSample(src, t, ('Prise de sang · %s · %s'):format(tube and tube.label or an.tube, an.label))
    if not id then return nil, err end
    return { result = 'sample', report = ('Prélèvement LAB-%05d (%s, %s). Analyse à lancer depuis la tablette › Laboratoire.'):format(id, tube and tube.label or an.tube, an.label),
        patientMsg = 'Prise de sang terminée.' }
end

EFFECT.xray = function(src, t, A)
    local set = P.ProcSettings()
    local z = A.ctx.zone
    if A.ctx.full then
        -- Aucune donnée inventée : seules les blessures enregistrées (et l'ancienne blessure à la jambe) apparaissent.
        local legacy = P.HealthHas and P.HealthHas(t, 'leg') or false
        local findings, normal, fractures = PR.XrayFull(set, P.InjuryList(t), legacy)
        local now = os.time()
        for _, inj in ipairs(fractures) do P.InjurySet(t, inj.id, { xray = now }) end   -- fractures vues : plâtre / attelle possibles
        -- lésions internes : seulement des signes indirects (pas de diagnostic posé) → scanner / échographie conseillés
        if #findings == 0 then
            return { result = 'normal', zone = 'corps', report = set.reports.xray_full_none }
        end
        local parts = {}
        for _, f in ipairs(findings) do parts[#parts + 1] = ('%s : %s.'):format(f.zoneLabel, f.label) end
        return { result = 'anomalies', zone = 'corps', report = PR.Fill(set.reports.xray_full_found,
            { count = #findings, list = table.concat(parts, ' '), normal = #normal > 0 and table.concat(normal, ', '):lower() or 'aucune' }) }
    end
    -- ancienne « Blessure à la jambe » (chute, sans côté) : la jambe radiographiée la porte
    if z.region == 'leg' and P.HealthHas and P.HealthHas(t, 'leg') then
        local any = false
        for _, inj in ipairs(P.InjuryList(t)) do if inj.type == 'fracture' and (inj.zone == 'jambe_g' or inj.zone == 'jambe_d') and inj.status == 'active' then any = true end end
        if not any then P.InjuryAdd(t, 'fracture', z.id, 1, 'chute') end
    end
    local key, inj = PR.XrayResult(P.InjuryList(t), z.id)
    if inj then P.InjurySet(t, inj.id, { xray = os.time() }) end
    local tpl = ({ none = set.reports.xray_none, immob = set.reports.xray_immob, fracture = set.reports.xray_fracture })[key]
    return { result = key, zone = z.id, report = PR.Fill(tpl, { zone = z.label:lower() }) }
end

EFFECT.cast = function(src, t, A)
    local set = P.ProcSettings()
    local inj, m, z = A.ctx.injury, A.ctx.material, A.ctx.zone
    local cur = Injury(t, inj.id, 'fracture')
    if not cur or cur.status ~= 'active' then return nil, 'La blessure a déjà été prise en charge.' end
    P.InjuryTreated(t, inj.id, P.Name(src), 'treated')
    if z and z.region == 'leg' and P.HealthHas and P.HealthHas(t, 'leg') then P.HealthTreat(t, 'splint', src) end
    return { result = m.id, zone = inj.zone, report = PR.Fill(set.reports.cast_done, { material = m.label, zone = z and z.label:lower() or inj.zone }),
        patientMsg = ('%s posé(e) : %s.'):format(m.label, z and z.label:lower() or '') }
end

EFFECT.hemostasis = function(src, t, A)
    local set = P.ProcSettings()
    local inj, z = A.ctx.injury, A.ctx.zone
    local cur = Injury(t, inj.id, 'hemorrhage')
    if not cur or cur.status ~= 'active' then return nil, 'Ce saignement a déjà été contrôlé.' end
    local needDressing = cur.severity >= set.hemostasis.dressingFrom
    if needDressing then P.InjurySet(t, cur.id, { status = 'controlled', treated = os.time(), treatedBy = P.Name(src) })
    else P.InjuryTreated(t, cur.id, P.Name(src)) end
    local rep = PR.Fill(set.reports.hemo_done, { zone = z and z.label:lower() or cur.zone, level = PR.InjuryLabel(set, cur):lower() })
    if A.assist and GetPlayerName(A.assist) then rep = rep .. (' Aide : %s.'):format(P.Name(A.assist)) end
    return { result = needDressing and 'controlled' or 'healed', zone = cur.zone, report = rep,
        message = needDressing and 'Saignement contrôlé : posez maintenant un pansement compressif.' or 'Saignement contrôlé.' }
end

EFFECT.dressing = function(src, t, A)
    local set = P.ProcSettings()
    local inj, z = A.ctx.injury, A.ctx.zone
    local cur = Injury(t, inj.id, 'hemorrhage')
    if not cur or cur.status ~= 'controlled' then return nil, 'Le pansement n\'est plus nécessaire.' end
    P.InjuryTreated(t, cur.id, P.Name(src))
    return { result = 'dressed', zone = cur.zone, report = PR.Fill(set.reports.dressing_done, { zone = z and z.label:lower() or cur.zone }) }
end

EFFECT.cpr = function(src, t, A, res)
    local set = P.ProcSettings()
    local d = P.down[t]
    if not d then return nil, 'Le patient n\'est plus inconscient.' end
    local score = PR.Num(res.score, 0, 1, 0)
    if score < set.cpr.passScore then
        return nil, ('Rythme trop irrégulier (%d %% dans le rythme) : séquence non validée.'):format(math.floor(score * 100)), true
    end
    d.cpr = d.cpr or { n = 0 }
    local worst = PR.WorstBleed(P.InjuryList(t))
    local defib = Count(src, set.cpr.defibItem) > 0
    local chance = PR.CprChance(set, { score = score, previous = d.cpr.n, stabilized = d.stabilized, defib = defib, bleeding = worst and worst.severity or 0 })
    d.cpr.n = d.cpr.n + 1
    local seq = d.cpr.n
    if math.random() < chance then
        P.Revive(t, set.cpr.health)
        P.AddTreatment(t, 'revive', src)
        return { result = 'rosc', score = score, noTreatment = true,
            report = ('Massage cardiaque : reprise d\'activité cardiaque après %d séquence(s) (régularité %d %%)%s.'):format(seq, math.floor(score * 100), defib and ', défibrillateur utilisé' or ''),
            message = ('Le cœur repart ! %s reprend connaissance.'):format(P.Name(t)), patientMsg = ('%s vous a réanimé(e).'):format(P.Name(src)) }
    end
    if P.DownExtend then P.DownExtend(t, set.cpr.extendSeconds) end
    local hint = worst and worst.severity >= 2 and ' Une hémorragie non contrôlée gêne la réanimation.' or (not d.stabilized and ' Stabiliser le patient aiderait.' or '')
    return { result = 'no_rosc', score = score, noTreatment = true,
        report = ('Massage cardiaque : séquence %d réalisée (régularité %d %%), pas de reprise.'):format(seq, math.floor(score * 100)),
        message = ('Séquence correcte, pas de reprise pour l\'instant. Poursuivez, utilisez un défibrillateur ou passez le relais.%s'):format(hint), continue = true }
end

local function Imaging(src, t, A, regions, label)
    local set = P.ProcSettings()
    local found = PR.ImagingFindings(set, P.InjuryList(t), regions)
    for _, f in ipairs(found) do P.InjurySet(t, f.id, { seen = os.time() }) end
    if #found == 0 then return { result = 'none', report = PR.Fill(set.reports.imaging_none, { type = label }) } end
    local parts = {}
    for _, f in ipairs(found) do parts[#parts + 1] = PR.Fill(set.reports.imaging_found, { type = label, level = f.label, zone = f.zoneLabel:lower() }) end
    return { result = 'found', report = table.concat(parts, ' ') }
end

EFFECT.echo = function(src, t, A)
    local ty = A.ctx.type
    local set = P.ProcSettings()
    if ty.id == 'pregnancy' then
        local ok, r = pcall(function() return exports.elyzea_famille:EchographieEms(src, t) end)
        if not ok or type(r) ~= 'table' then return nil, 'Module grossesse indisponible.' end
        if not r.pregnant then
            return { result = 'not_pregnant', sensitive = true, report = set.reports.echo_preg_no, patientMsg = set.reports.echo_preg_no }
        end
        local babies = r.babies == 1 and 'un bébé' or (r.babies == 2 and 'des jumeaux' or (r.babies == 3 and 'des triplés' or ('%d bébés'):format(r.babies or 1)))
        local txt = PR.Fill(set.reports.echo_preg_yes, { day = r.day, days = r.days, babies = babies })
        return { result = 'pregnant', sensitive = true, report = txt, patientMsg = txt }
    end
    return Imaging(src, t, A, ty.regions, ty.label)
end

EFFECT.scan = function(src, t, A)
    local ty = A.ctx.type
    return Imaging(src, t, A, ty.regions, ty.label)
end

EFFECT.vaccine = function(src, t, A, _, uid)
    local v = A.ctx.vaccine
    local now = os.time()
    local eff, exp = PR.VaccineDates(v, now)
    local id = MySQL.insert.await([[INSERT INTO `ems_vaccinations` (`citizenid`, `vaccine`, `label`, `zone`, `given_at`, `effective_at`, `expires_at`, `ems_cid`, `ems_name`, `proc_uid`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { P.Cid(t), v.id, v.label, v.zone, now, eff, exp, P.Cid(src), P.Name(src), uid })
    if not id then return nil, 'Vaccin non enregistré.' end
    local zl = FindIn(P.ProcSettings().injectionZones, v.zone)
    local txt = ('%s administré (%s). Protection %s%s.'):format(v.label, zl and zl.label:lower() or v.zone,
        eff > now and ('à partir du ' .. os.date('%d/%m %H:%M', eff)) or 'immédiate',
        exp and (' jusqu\'au ' .. os.date('%d/%m/%Y', exp)) or '')
    return { result = v.id, report = txt, patientMsg = txt, sensitive = v.id == 'mst' }
end

EFFECT.implant = function(src, t)
    local ok, done, fin = pcall(function() return exports.elyzea_famille:PoseImplantEms(t, src) end)
    if not ok or not done then return nil, 'L\'implant n\'a pas pu être posé.' end
    return { result = 'placed', sensitive = true, report = ('Implant contraceptif posé le %s, efficace jusqu\'au %s.'):format(os.date('%d/%m/%Y %H:%M'), fin and os.date('%d/%m/%Y', fin) or '?') }
end

EFFECT.implant_remove = function(src, t)
    local ok, done = pcall(function() return exports.elyzea_famille:RetraitImplantEms(t, src) end)
    if not ok or not done then return nil, 'L\'implant n\'a pas pu être retiré.' end
    return { result = 'removed', sensitive = true, report = ('Implant contraceptif retiré le %s.'):format(os.date('%d/%m/%Y %H:%M')) }
end

local FAIL_MSG = {
    blood = 'Veine manquée : recommencez le prélèvement.',
    xray = 'Cliché incorrect : examen à refaire.',
    cast = 'Pose ratée : recommencez l\'étape.',
    hemostasis = 'Pression instable : le saignement reprend, recommencez la compression.',
    dressing = 'Pansement mal posé : recommencez.',
    cpr = 'Séquence interrompue.',
    echo = 'Image trop floue : examen à refaire.',
    scan = 'Acquisition ratée : examen à refaire.',
    vaccine = 'Injection ratée : rien n\'a été administré.',
    implant = 'Pose interrompue : rien n\'a été posé.',
    implant_remove = 'Retrait interrompu.',
}

P.Actions.procResult = { perm = 'medical', duty = true, fn = function(src, d)
    local A = active[src]
    if not A then return { error = 'Aucun acte en cours.' } end
    active[src] = nil          -- une seule validation par acte (double clic, latence)
    local set = P.ProcSettings()
    local a = set.acts[A.act]
    local t = A.target
    local res = type(d.result) == 'table' and d.result or {}
    local ok, why = PR.Check(A.ch, res, (GetGameTimer() - A.t0) / 1000, set)
    if not ok then
        Release(src, A)
        if why == 'invalid' then P.Log(src, 'Acte refusé (résultat invalide)', ('%s · %s'):format(A.act, P.Name(t))) end
        if why == 'cancel' then return { cancelled = true, message = 'Acte annulé.' } end
        return { failed = true, retry = a.retry and why == 'fail', message = why == 'fail' and FAIL_MSG[A.act] or 'Résultat refusé.' }
    end
    -- revérifications au moment de valider
    local t2, tWhy = TargetOk(src, t)
    if not t2 then Release(src, A) return { error = tWhy } end
    local pOk, pWhy = PatientOk(a, t)
    if not pOk then Release(src, A) return { error = pWhy } end
    local aOk, aWhy = Avail(src, A.act)
    if not aOk then Release(src, A) return { error = aWhy } end
    local miss = MissingItem(src, A.ctx.items)
    if miss then Release(src, A) return { error = ('Matériel manquant : %s.'):format(ItemLabel(miss)) } end
    local cOk, done = Consume(src, A.ctx.items)
    if not cOk then Release(src, A) return { error = ('Matériel manquant : %s.'):format(ItemLabel(done)) } end
    local uid = P.Uid('ACT')
    local okE, r, err, retry = pcall(EFFECT[A.act], src, t, A, res, uid)
    if not okE or not r then
        Refund(src, done)
        Release(src, A)
        if not okE then print(('^1[EMS] Acte %s : %s^0'):format(A.act, tostring(r))) return { error = 'Erreur serveur : rien n\'a été appliqué.' } end
        if retry then return { failed = true, retry = true, message = err } end
        return { error = err or 'Acte impossible.' }
    end
    local zone = r.zone or (A.ctx.zone and A.ctx.zone.id) or nil
    Record(uid, src, t, A.act, zone, r.result, r.report, done, r.score or tonumber(res.score), r.sensitive)
    if not r.noTreatment and a.service then P.AddTreatment(t, a.service, src) end
    Release(src, A)
    if r.patientMsg then P.Notify(t, r.patientMsg, 'inform') else P.Notify(t, ('%s : %s.'):format(a.label, P.Name(src)), 'inform') end
    P.Log(src, a.label, ('%s [%d] · %s'):format(P.Name(t), t, r.result or ''))
    return { ok = true, message = r.message or ('%s terminé(e) : %s.'):format(a.label, P.Name(t)), report = r.report, continue = r.continue,
        sensitive = r.sensitive }
end }

-- ---------------------------------------------------------------------
-- Déconnexions et nettoyage
-- ---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    local A = active[src]
    if A then Release(src, A) end
    local ems = patientBusy[src]
    if ems then
        local B = active[ems]
        patientBusy[src] = nil
        if B then active[ems] = nil end
        if GetPlayerName(ems) then
            TriggerClientEvent('ems:client:procAbort', ems, 'Le patient s\'est déconnecté : acte annulé.')
        end
    end
    for token, a in pairs(asks) do if a.target == src or a.ems == src then asks[token] = nil a.p:resolve('no') end end
    for k in pairs(consents) do
        local e, p = k:match('^(%d+):(%d+):')
        if tonumber(e) == src or tonumber(p) == src then consents[k] = nil end
    end
    lastStart[src] = nil
end)

-- Le patient se relève (X) : l'acte en cours sur lui est arrêté
RegisterNetEvent('ems:server:procLeave', function()
    local t = source
    local ems = patientBusy[t]
    local A = ems and active[ems]
    if not A then return end
    Release(ems, A)
    if GetPlayerName(ems) then TriggerClientEvent('ems:client:procAbort', ems, 'Le patient s\'est relevé : acte interrompu.') end
end)

-- Le patient tombe à terre pendant un acte qui demande qu'il soit conscient : acte arrêté
AddStateBagChangeHandler('emsDown', nil, function(bagName, _, value)
    if not value then return end
    local t = tonumber(tostring(bagName):match('^player:(%d+)$'))
    local ems = t and patientBusy[t]
    local A = ems and active[ems]
    if A and P.ProcSettings().acts[A.act].patient == 'conscious' then
        Release(ems, A)
        if GetPlayerName(ems) then TriggerClientEvent('ems:client:procAbort', ems, 'Le patient a perdu connaissance : acte arrêté.') end
    end
end)

-- ---------------------------------------------------------------------
-- Vaccins : protection (utilisé par server/health.lua avant de donner une maladie)
-- ---------------------------------------------------------------------
function P.ProcImmune(cid, kind)
    local set = P.ProcSettings()
    local any = false
    for _, v in ipairs(set.vaccines) do for _, k in ipairs(v.protects or {}) do if k == kind then any = true end end end
    if not any or not cid then return false end
    local rows = MySQL.query.await('SELECT `vaccine`, `effective_at`, `expires_at` FROM `ems_vaccinations` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 30', { cid }) or {}
    return PR.Immune(set, rows, kind, os.time())
end

-- Dossier médical : actes et vaccins (les actes confidentiels ne sont lus qu'avec « records_sensitive »)
function P.ProcHistory(cid, src)
    local sens = P.Can(src, 'records_sensitive')
    local set = P.ProcSettings()
    local out = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `uid`, `act`, `zone`, `result`, `report`, `items`, `score`, `sensitive`, `ems_name`, `ems_grade`, `created_at` AS t
        FROM `ems_procedures` WHERE `patient_cid` = ? ORDER BY `id` DESC LIMIT 60]], { cid }) or {}) do
        local a = set.acts[r.act]
        local z = set.zoneById[r.zone or '']
        local hidden = tonumber(r.sensitive) == 1 and not sens
        out[#out + 1] = { uid = r.uid, act = r.act, label = a and a.label or r.act, icon = a and a.icon or '🩺', zone = z and z.label or nil,
            report = hidden and 'Information confidentielle (accès réservé).' or r.report, items = not hidden and r.items or nil,
            score = r.score, ems = r.ems_name, grade = r.ems_grade, t = tonumber(r.t), hidden = hidden }
    end
    local vacc = {}
    for _, r in ipairs(MySQL.query.await([[SELECT `vaccine`, `label`, `given_at`, `effective_at`, `expires_at`, `ems_name` FROM `ems_vaccinations` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 30]], { cid }) or {}) do
        if r.vaccine ~= 'mst' or sens then vacc[#vacc + 1] = r end
    end
    return out, vacc
end

-- ---------------------------------------------------------------------
-- Staff : admin_menu › Santé (appelé par l'export HealthAdmin de server/health.lua)
-- ---------------------------------------------------------------------
function P.ProcAdminData()
    local set = P.ProcSettings()
    local acts = {}
    for _, id in ipairs(set.order) do acts[#acts + 1] = set.acts[id] end
    local mats = {}
    for _, m in ipairs(set.cast.materials) do mats[#mats + 1] = { id = m.id, label = m.label, item = m.item } end
    local keys = {}
    for k in pairs(set.reports) do keys[#keys + 1] = k end
    table.sort(keys)
    local reports = {}
    for _, k in ipairs(keys) do reports[#reports + 1] = { key = k, text = set.reports[k] } end
    local zones = {}
    for _, z in ipairs(set.zones) do zones[#zones + 1] = { id = z.id, label = z.label } end
    return { enabled = set.enabled, acts = acts, injuries = set.injuries, hemostasis = set.hemostasis, cpr = set.cpr,
        materials = mats, vaccines = set.vaccines, reports = reports, zones = zones }
end

function P.ProcAdmin(op, src, d)
    local staff = ('Staff · %s'):format(GetPlayerName(src) or '?')
    if op == 'procSave' then
        P.SetSetting(KEY, PR.CleanSaved(d.procedures, Config.Procedures))
        S = nil
        Publish()
        for s in pairs(P.injuries) do P.InjuryPush(s) end
        P.Log(src, 'Actes médicaux : réglages enregistrés', staff)
        return { ok = true, message = 'Réglages des actes médicaux enregistrés.' }
    end
    if op == 'injuryGive' then
        local t = tonumber(d.target)
        if not t or not GetPlayerName(t) then return { error = 'Joueur introuvable.' } end
        local ok, why = P.InjuryAdd(t, tostring(d.type or ''), tostring(d.zone or ''), d.severity, 'staff')
        if not ok then return { error = why } end
        P.Log(src, 'Santé : blessure donnée', ('%s %s (%s) → %s'):format(tostring(d.type), tostring(d.zone), tostring(d.severity), P.Name(t)))
        return { ok = true, message = ('Blessure ajoutée à %s.'):format(P.Name(t)) }
    end
    if op == 'injuryHeal' then
        local t = tonumber(d.target)
        if not t or not GetPlayerName(t) then return { error = 'Joueur introuvable.' } end
        local n = 0
        for _, inj in ipairs(PR.Copy(P.InjuryList(t))) do
            if not d.id or inj.id == tonumber(d.id) then P.InjurySet(t, inj.id, { status = 'healed', healed = os.time(), treatedBy = 'Staff' }) n = n + 1 end
        end
        return n > 0 and { ok = true, message = ('%d blessure(s) soignée(s).'):format(n) } or { error = 'Aucune blessure.' }
    end
    return nil
end

-- Liste des blessures d'un joueur connecté (onglet staff)
function P.ProcAdminPlayer(src)
    local set, out = P.ProcSettings(), {}
    for _, inj in ipairs(P.InjuryList(src)) do
        local z = set.zoneById[inj.zone]
        out[#out + 1] = { id = inj.id, label = PR.InjuryLabel(set, inj), zone = z and z.label or inj.zone, status = inj.status }
    end
    return out
end
