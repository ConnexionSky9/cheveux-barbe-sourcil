-- =====================================================================
--  ELYZEA PIER - RÉGLAGES MODIFIABLES EN JEU (admin_menu › Parc de Del Perro)
--  · Valeurs de départ = config.lua. Les réglages faits dans le menu admin les REMPLACENT,
--    sont enregistrés sur le serveur (KVP « pier_settings ») et gardés après un redémarrage.
--  · Appliqués tout de suite (sans redémarrage) : la roue et le train relisent ces valeurs.
--    La durée du parcours des montagnes russes attend que le train soit en gare.
--  · Les joueurs reçoivent le PNJ (position, modèle, animation, blip) et l'état des attractions
--    par GlobalState.pierPublic.
--  · Permission : admin_menu « pier_manage » (revérifiée à chaque action), sinon ACE elyzea_pier.admin.
-- =====================================================================
PierSettings = {}
local KVP = 'pier_settings'
local PERM = 'pier_manage'

-- Valeurs d'origine (config.lua), gardées pour « réglages par défaut »
local function snapshotDefaults()
    local n = Config.Npc
    return {
        wheelEnabled = Config.Wheel.enabled, coasterEnabled = Config.Coaster.enabled,
        wheelPrice = Config.Tickets.wheel.price, coasterPrice = Config.Tickets.coaster.price,
        cash = Config.Accounts.cash == true, bank = Config.Accounts.bank == true,
        maxPerPurchase = Config.MaxTicketsPerPurchase, maxOwned = Config.MaxTicketsOwned,
        turnDuration = Config.Wheel.turnDuration, stopDuration = Config.Wheel.stopDuration, idleRotation = Config.Wheel.idleRotation,
        boardingTime = Config.Coaster.boardingTime, fullDepartDelay = Config.Coaster.fullDepartDelay, coasterDuration = Config.Coaster.duration or 0,
        npc = { enabled = n.enabled, x = n.coords.x, y = n.coords.y, z = n.coords.z, h = n.coords.w, model = n.model,
            scenario = n.scenario or '', blip = n.blip and n.blip.enabled ~= false },
    }
end
local DEFAULTS = snapshotDefaults()

-- ---------------------------------------------------------------- validation
local function num(v, def, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(lo, math.min(hi, v))
end
local function int(v, def, lo, hi) return math.floor(num(v, def, lo, hi)) end
local function bool(v, def) if v == nil then return def end return v == true end
local function model(v, def)
    v = tostring(v or ''):lower():gsub('[^%w_]', '')
    return (v ~= '' and #v <= 48) and v or def
end
local function scenario(v, def)
    if v == nil then return def end
    v = tostring(v):upper():gsub('[^%w_]', '')
    return #v <= 60 and v or def
end

function PierSettings.Sanitize(raw)
    local D = DEFAULTS
    raw = type(raw) == 'table' and raw or {}
    local n, N = type(raw.npc) == 'table' and raw.npc or {}, D.npc
    local out = {
        wheelEnabled = bool(raw.wheelEnabled, D.wheelEnabled), coasterEnabled = bool(raw.coasterEnabled, D.coasterEnabled),
        wheelPrice = int(raw.wheelPrice, D.wheelPrice, 0, 100000), coasterPrice = int(raw.coasterPrice, D.coasterPrice, 0, 100000),
        cash = bool(raw.cash, D.cash), bank = bool(raw.bank, D.bank),
        maxPerPurchase = int(raw.maxPerPurchase, D.maxPerPurchase, 1, 50), maxOwned = int(raw.maxOwned, D.maxOwned, 0, 500),
        turnDuration = int(raw.turnDuration, D.turnDuration, 60, 900), stopDuration = int(raw.stopDuration, D.stopDuration, 5, 60),
        idleRotation = bool(raw.idleRotation, D.idleRotation),
        boardingTime = int(raw.boardingTime, D.boardingTime, 5, 180), fullDepartDelay = int(raw.fullDepartDelay, D.fullDepartDelay, 0, 60),
        coasterDuration = int(raw.coasterDuration, D.coasterDuration, 0, 300),
        npc = {
            enabled = bool(n.enabled, N.enabled), model = model(n.model, N.model), scenario = scenario(n.scenario, N.scenario),
            blip = bool(n.blip, N.blip),
            x = num(n.x, N.x, -20000, 20000), y = num(n.y, N.y, -20000, 20000), z = num(n.z, N.z, -500, 3000), h = num(n.h, N.h, -360, 720) % 360,
        },
    }
    if not out.cash and not out.bank then out.cash = true end            -- au moins un moyen de paiement
    if out.coasterDuration > 0 and out.coasterDuration < 30 then out.coasterDuration = 30 end
    return out
end

-- ---------------------------------------------------------------- application
local S = PierSettings.Sanitize(nil)
local pendingDuration = nil

local function coasterAtStation()
    local st = Coaster and Coaster._S
    return not st or st.phase == 'idle' or st.phase == 'boarding'
end

local function apply()
    Config.Wheel.enabled, Config.Coaster.enabled = S.wheelEnabled, S.coasterEnabled
    Config.Tickets.wheel.price, Config.Tickets.coaster.price = S.wheelPrice, S.coasterPrice
    Config.Accounts.cash, Config.Accounts.bank = S.cash, S.bank
    Config.MaxTicketsPerPurchase, Config.MaxTicketsOwned = S.maxPerPurchase, S.maxOwned
    Config.Wheel.turnDuration, Config.Wheel.stopDuration, Config.Wheel.idleRotation = S.turnDuration, S.stopDuration, S.idleRotation
    Config.Coaster.boardingTime, Config.Coaster.fullDepartDelay = S.boardingTime, S.fullDepartDelay
    -- durée du parcours : jamais pendant un trajet (les passagers suivent la vitesse de leur départ)
    local wanted = S.coasterDuration > 0 and S.coasterDuration or nil
    if coasterAtStation() then Config.Coaster.duration, pendingDuration = wanted, nil
    elseif Config.Coaster.duration ~= wanted then pendingDuration = { v = wanted } end
    local n = S.npc
    Config.Npc.enabled, Config.Npc.model = n.enabled, n.model
    Config.Npc.scenario = n.scenario ~= '' and n.scenario or nil
    Config.Npc.coords = vector4(n.x, n.y, n.z, n.h)
    Config.Npc.blip = Config.Npc.blip or {}
    Config.Npc.blip.enabled = n.blip
    GlobalState.pierPublic = {
        npc = { enabled = n.enabled, x = n.x, y = n.y, z = n.z, h = n.h, model = n.model, scenario = n.scenario, blip = n.blip },
        wheelEnabled = S.wheelEnabled, coasterEnabled = S.coasterEnabled,
    }
end

local function save() SetResourceKvp(KVP, json.encode(S)) end
local function load()
    local raw = GetResourceKvpString(KVP)
    local ok, v = false, nil
    if raw and raw ~= '' then ok, v = pcall(json.decode, raw) end
    S = PierSettings.Sanitize(ok and v or nil)
    apply()
end
PierSettings.Load = load
function PierSettings.Get() return S end

load()

-- Durée en attente : appliquée dès que le train est revenu en gare
CreateThread(function()
    while true do
        Wait(2000)
        if pendingDuration and coasterAtStation() then
            Config.Coaster.duration = pendingDuration.v
            pendingDuration = nil
            Pier.Log('durée des montagnes russes appliquée (train en gare)')
        end
    end
end)

-- ---------------------------------------------------------------- permission
local function isAdmin(src)
    src = tonumber(src)
    if src == 0 then return true end
    if not src or not GetPlayerName(src) then return false end
    if GetResourceState('admin_menu') == 'started' then
        local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, PERM) end)
        return ok and r == true
    end
    return IsPlayerAceAllowed(src, Config.AcePermission) == true
end
PierSettings.IsAdmin = isAdmin

local function staffLog(src, msg)
    if GetResourceState('admin_menu') == 'started' then pcall(function() exports.admin_menu:AddLog(src, 'Parc de Del Perro', msg) end) end
    Pier.Log(('%s : %s'):format(src == 0 and 'console' or ((Pier.Identity(src) or {}).name or src), msg))
end

-- ---------------------------------------------------------------- vue et actions du menu admin
local function riders(st)
    local list = {}
    for src, r in pairs(st.riders or {}) do
        list[#list + 1] = { id = src, name = (Pier.Identity(src) or {}).name or ('#' .. src), place = r.c and ('cabine ' .. r.c) or (r.seat and ('place ' .. r.seat)) or '' }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function PierSettings.Summary(src)
    if not isAdmin(src) then return nil end
    local players = {}
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        players[#players + 1] = { id = s, name = (Pier.Identity(s) or {}).name or GetPlayerName(s) }
    end
    return {
        settings = S, defaults = DEFAULTS, pendingDuration = pendingDuration ~= nil,
        wheel = { status = Wheel.Status(), describe = Wheel.Describe(), capacity = Wheel.Capacity(), free = Wheel.Free(), queue = Wheel.QueueLength(), riders = riders(Wheel._S) },
        coaster = { status = Coaster.Status(), describe = Coaster.Describe(), capacity = Coaster.Capacity(), free = Coaster.Free(), queue = Coaster.QueueLength(),
            riders = riders(Coaster._S), natural = math.floor(PierRide.Coaster.natural + 0.5) },
        tickets = { wheel = { item = Config.Tickets.wheel.item, label = Config.Tickets.wheel.label }, coaster = { item = Config.Tickets.coaster.item, label = Config.Tickets.coaster.label } },
        players = players,
    }
end

local Act = {}

function Act.settings(src, d)
    local raw = json.decode(json.encode(S))
    for _, k in ipairs({ 'wheelEnabled', 'coasterEnabled', 'cash', 'bank', 'idleRotation' }) do if d[k] ~= nil then raw[k] = d[k] == true end end
    for _, k in ipairs({ 'wheelPrice', 'coasterPrice', 'maxPerPurchase', 'maxOwned', 'turnDuration', 'stopDuration', 'boardingTime', 'fullDepartDelay', 'coasterDuration' }) do
        if d[k] ~= nil then raw[k] = tonumber(d[k]) end
    end
    S = PierSettings.Sanitize(raw)
    apply() save()
    staffLog(src, ('réglages : roue %s (%d $), montagnes russes %s (%d $), tour %d s, arrêt %d s, embarquement %d s'):format(
        S.wheelEnabled and 'ouverte' or 'fermée', S.wheelPrice, S.coasterEnabled and 'ouvertes' or 'fermées', S.coasterPrice,
        S.turnDuration, S.stopDuration, S.boardingTime))
    return true, pendingDuration and 'Réglages enregistrés (la nouvelle durée du parcours s\'appliquera au retour du train en gare).' or 'Réglages enregistrés.'
end

function Act.npc(src, d)
    local raw = json.decode(json.encode(S))
    if d.enabled ~= nil then raw.npc.enabled = d.enabled == true end
    if d.blip ~= nil then raw.npc.blip = d.blip == true end
    if d.model ~= nil and tostring(d.model) ~= '' then raw.npc.model = d.model end
    if d.scenario ~= nil then raw.npc.scenario = d.scenario end
    if d.h ~= nil then raw.npc.h = tonumber(d.h) end
    S = PierSettings.Sanitize(raw)
    apply() save()
    staffLog(src, 'vendeur de tickets modifié')
    return true, 'Vendeur de tickets enregistré.'
end

-- Position et orientation lues par le serveur sur le personnage de l'admin
function Act.npcHere(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'Position introuvable.' end
    local c = GetEntityCoords(ped)
    local raw = json.decode(json.encode(S))
    raw.npc.x, raw.npc.y, raw.npc.z, raw.npc.h = c.x, c.y, c.z - 1.0, GetEntityHeading(ped)
    S = PierSettings.Sanitize(raw)
    apply() save()
    staffLog(src, ('vendeur de tickets placé en %.1f, %.1f, %.1f'):format(c.x, c.y, c.z))
    return true, 'Vendeur de tickets placé à ta position, dans ton orientation.'
end

function Act.teleport(src, d)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p
    if d.to == 'npc' then local c = Config.Npc.coords p = { x = c.x + 0.8, y = c.y + 0.8, z = c.z + 1.0 }
    elseif d.to == 'wheel' then p = Config.Wheel.entry
    elseif d.to == 'coaster' then p = Config.Coaster.entry end
    if not p then return false, 'Destination inconnue.' end
    SetEntityCoords(ped, p.x + 0.0, p.y + 0.0, p.z + 0.2, false, false, false, false)
    return true, 'Téléporté.'
end

function Act.reset(src, d)
    local what = d.what
    if what == 'wheel' or what == 'all' then Wheel.Reset('remise à zéro par le staff') end
    if what == 'coaster' or what == 'all' then Coaster.Reset('remise à zéro par le staff') end
    if what ~= 'wheel' and what ~= 'coaster' and what ~= 'all' then return false, 'Attraction inconnue.' end
    staffLog(src, 'remise à zéro : ' .. what)
    return true, 'Attraction remise à zéro : passagers redescendus, file vidée (tickets non consommés gardés).'
end

function Act.give(src, d)
    local t = Config.Tickets[tostring(d.kind or '')]
    local target, qty = tonumber(d.target), math.floor(tonumber(d.qty) or 0)
    if not t then return false, 'Ticket inconnu.' end
    if not target or not GetPlayerName(target) or not Pier.Identity(target) then return false, 'Joueur introuvable (ID serveur).' end
    if qty < 1 or qty > 50 then return false, 'Quantité : 1 à 50.' end
    local ok, r = pcall(function() return exports.elyzea_inventory:AddItem(target, t.item, qty) end)
    if not ok or r ~= true then return false, 'Inventaire plein ou indisponible.' end
    Pier.Notify(target, ('Le staff t\'a offert %d ticket(s) %s.'):format(qty, t.label), 'success')
    staffLog(src, ('%d ticket(s) %s offert(s) à %s'):format(qty, t.label, (Pier.Identity(target) or {}).name or target))
    return true, ('%d ticket(s) %s donné(s).'):format(qty, t.label)
end

function Act.reload(src)
    load()
    staffLog(src, 'réglages rechargés')
    return true, 'Réglages enregistrés rechargés.'
end

function Act.defaults(src, d)
    if d.confirm ~= true then return false, 'Confirmation manquante.' end
    S = PierSettings.Sanitize(nil)
    apply() save()
    staffLog(src, 'réglages remis à ceux de config.lua')
    return true, 'Réglages remis à ceux de config.lua.'
end

function PierSettings.Action(src, name, data)
    if not isAdmin(src) then return false, 'Permission refusée.' end
    local fn = Act[tostring(name or '')]
    if not fn then return false, 'Action inconnue.' end
    local ok, res, msg = pcall(fn, tonumber(src), type(data) == 'table' and data or {})
    if not ok then Pier.Log('^1action admin ' .. tostring(name) .. ' : ' .. tostring(res) .. '^0') return false, 'Erreur pendant l\'enregistrement.' end
    return res, msg
end

exports('AdminSummary', function(src) return PierSettings.Summary(src) end)
exports('AdminAction', function(src, name, data) return PierSettings.Action(src, name, data) end)
