-- =====================================================================
--  Téléphone de service (elyzea_jobphone) - pont serveur du métier
--  Fichier identique dans chaque métier (police, EMS, mécano, Dynasty 8,
--  concession). Il ne fait que LIRE les données du métier et passer par
--  ses actions existantes (mêmes contrôles de grade / service) :
--  aucune donnée dupliquée, aucune règle contournée.
--    exports.<métier>:PhoneBridge(op, src, data)
-- =====================================================================
local P = Police or Ems or Meca or Dynasty or Concess
local core = exports.elyzea_core
local RES = GetCurrentResourceName()
local IsMember = P.IsCop or P.IsEms or P.IsMeca or P.IsDynasty or P.IsMember

-- Unité : le métier, ou la concession pour le concessionnaire (multi-concessions)
local function ShopId(e) return P.ShopOf and e and e.shop_id or nil end
local function UnitOf(src)
    if P.ShopOf then local D = P.ShopOf(src) return D and (RES .. ':' .. D.id) or nil, D and D.name or nil end
    return RES, Config.Job and Config.Job.label or RES
end

-- Mêmes contrôles que le dispatcher « <métier>:req »
local function Run(src, action, data)
    if not P.ready then return { error = 'Le métier démarre, réessayez dans un instant.' } end
    local a = P.Actions[action]
    if not a then return { error = 'Action indisponible pour ce métier.' } end
    local D = P.ShopOf and P.ShopOf(src) or nil
    if a.perm ~= false then
        if not IsMember(src) then return { error = 'Réservé aux employés.' } end
        if D and not D.enabled and a.open ~= false then return { error = 'Votre entreprise est fermée par le staff.' } end
        if a.perm and not P.Can(src, a.perm) then return { error = 'Votre grade ne permet pas cette action.' } end
        if a.duty and not P.OnDuty(src) then return { error = 'Prenez votre service pour faire cela.' } end
    end
    local ok, res = pcall(a.fn, src, type(data) == 'table' and data or {}, D)
    if not ok then
        print(('^1[%s/téléphone] Erreur « %s » : %s^0'):format(RES, action, tostring(res)))
        return { error = 'Erreur serveur.' }
    end
    return res or {}
end

-- Début de la session en cours (la police ne garde pas l'heure de début)
local since = {}
local setDuty = P.SetDuty
P.SetDuty = function(src, on, ...)
    setDuty(src, on, ...)
    since[src] = P.OnDuty(src) and (since[src] or os.time()) or nil
end
AddEventHandler('playerDropped', function() since[source] = nil end)

local function Session(src)
    if not P.OnDuty(src) then return 0 end
    if P.SessionSeconds then return P.SessionSeconds(src) end
    since[src] = since[src] or os.time()
    return os.time() - since[src]
end
local function Times(src)
    local e = P.Employee(src)
    if not e then return { session = 0, total = 0 } end
    if P.MyTimes then
        local t = P.MyTimes(src) or {}
        return { session = Session(src), total = tonumber(t.total) or 0 }
    end
    local live = 0
    local d = P.dutySince and P.dutySince[src]
    if d then live = os.time() - d.t end
    return { session = Session(src), total = (tonumber(e.service_seconds) or 0) + live }
end

-- Santé réelle : coma EMS (emsDown), état police (policeLife), métadonnées du core
local function Health(src)
    local ped = GetPlayerPed(src)
    local h, max = 0, 200
    if ped ~= 0 then
        h, max = GetEntityHealth(ped), GetEntityMaxHealth(ped)
        if not max or max <= 100 then max = 200 end
    end
    local hp = math.max(0, math.min(100, math.floor((h - 100) / (max - 100) * 100 + 0.5)))
    local st = Player(src).state
    local p = P.GetPlayer(src)
    local md = p and p.PlayerData.metadata or {}
    local life = 'ok'
    if st.policeLife == 'dead' or md.isdead == true then life, hp = 'dead', 0
    elseif st.emsDown == true or st.policeLife == 'down' or md.inlaststand == true then life = 'down'
    elseif hp < 50 then life = 'hurt' end
    return { hp = hp, life = life }
end

local function Crew(unit)
    local list = {}
    for src in pairs(P.duty) do
        if GetPlayerName(src) and IsMember(src) and UnitOf(src) == unit then list[#list + 1] = src end
    end
    return list
end

local function Me(src)
    if not IsMember(src) then return nil end
    local e, g = P.Employee(src), P.Grade(src)
    local unit, label = UnitOf(src)
    return {
        res = RES, unit = unit, unitLabel = label, cid = P.Cid(src), name = P.Name(src),
        matricule = e and e.matricule or '?', grade = g and g.name or '?', level = g and g.level or 0,
        duty = P.OnDuty(src), canDuty = P.Can(src, 'duty'), tablet = P.Can(src, 'tablet'),
        times = Times(src), status = P.status[src] or 'available',
    }
end

local Ops = {}
function Ops.me(src) return Me(src) end

-- Annuaire : toute l'unité (en ligne ou non), lu dans la table des employés
function Ops.roster(src)
    local unit = UnitOf(src)
    local shop = ShopId(P.Employee(src))
    local list = {}
    for cid, e in pairs(P.employees) do
        if not P.ShopOf or e.shop_id == shop then
            local g = P.grades[e.grade_id]
            local id = core:GetSourceByCitizenId(cid)
            local online = id ~= nil and IsMember(id) and UnitOf(id) == unit
            list[#list + 1] = { cid = cid, name = e.name, matricule = e.matricule, grade = g and g.name or '?', level = g and g.level or 0,
                online = online, duty = online and P.OnDuty(id) or false, id = online and id or nil }
        end
    end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return (a.name or '') < (b.name or '') end)
    return list
end

function Ops.crew(src) return Crew(UnitOf(src)) end

-- Carte : collègues EN SERVICE de la même unité, position + santé calculées ici
function Ops.map(src)
    local list = {}
    for _, id in ipairs(Crew(UnitOf(src))) do
        local c = GetEntityCoords(GetPlayerPed(id))
        local e, g = P.Employee(id), P.Grade(id)
        list[#list + 1] = { id = id, name = P.Name(id), matricule = e and e.matricule or '?', grade = g and g.name or '?', level = g and g.level or 0,
            x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10, health = Health(id), status = P.status[id] or 'available', me = id == src }
    end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level > b.level end return a.name < b.name end)
    return list
end

function Ops.duty(src, d)
    if d.on == true then return Run(src, 'duty', { on = true }) end
    return Run(src, 'dutyOff', {})
end

-- Alertes : système existant du métier s'il en a un (police : alerte agent, EMS : soutien)
local nativeAlerts = not P.Actions.agentAlert and not P.Actions.supportSend
function Ops.alertMode() return nativeAlerts and 'phone' or 'job' end
function Ops.alert(src, d)
    if P.Actions.agentAlert then return Run(src, 'agentAlert', { level = d.level, street = d.street }) end
    if P.Actions.supportSend then return Run(src, 'supportSend', { level = d.level, street = d.street, description = d.description }) end
    return { native = true }
end
function Ops.alerts(src)
    local list = (P.AgentAlertList and P.AgentAlertList()) or (P.SupportList and P.SupportList()) or {}
    local out = {}
    for _, a in ipairs(list) do
        out[#out + 1] = { id = a.id, level = a.level, street = a.street, author = a.author, matricule = a.matricule,
            x = a.x, y = a.y, t = a.t, mine = a.authorId == src }
    end
    return out
end
function Ops.alertClose(src, d)
    if P.Actions.closeAgentAlert then return Run(src, 'closeAgentAlert', { id = d.id }) end
    if P.Actions.supportClose then return Run(src, 'supportClose', { id = d.id }) end
    return { native = true }
end

exports('PhoneBridge', function(op, src, data)
    local f = Ops[op]
    src = tonumber(src)
    if not f or not src or not P.ready then return nil end
    local ok, res = pcall(f, src, type(data) == 'table' and data or {})
    if not ok then print(('^1[%s/téléphone] %s : %s^0'):format(RES, op, tostring(res))) return nil end
    return res
end)

-- Annuaire automatique : chaque changement d'état d'un employé (recrutement,
-- licenciement, grade, service, statut) prévient le téléphone de service
local push = P.PushState
P.PushState = function(src, ...)
    local r = push(src, ...)
    TriggerEvent('elyzea_jobphone:changed', RES, src)
    return r
end
