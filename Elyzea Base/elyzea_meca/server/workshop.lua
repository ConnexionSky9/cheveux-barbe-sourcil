-- =====================================================================
--  ELYZEA MÉCANO - serveur : points d'atelier, devis, paiement, installation, factures
--
--  1. Le mécanicien ouvre un point d'atelier (E) : le serveur vérifie la position
--     du mécanicien et du véhicule, son grade et son service.
--  2. Il compose le devis (prévisualisation côté client) puis l'envoie à un client proche.
--     Les prix sont ceux du catalogue AU MOMENT DU DEVIS (copiés dans le devis).
--  3. Le client accepte : le total est prélevé tout de suite (banque puis liquide)
--     et versé sur le compte société. Refus ou fonds insuffisants : rien n'est prélevé.
--  4. Le mécanicien installe : le serveur envoie à son client les propriétés exactes
--     de chaque ligne ; le client les applique et renvoie ce qui a réellement été posé.
--  5. Seules les lignes posées sont facturées : la différence est remboursée tout de suite.
--     Les modifications sont enregistrées sur la carte grise ; le CarPlay est lié au véhicule.
--  Un devis ne sert qu'une fois (identifiant unique) : aucune double facturation.
--
--  Interventions animées (client/interventions.lua) : à l'installation, le serveur
--  verrouille le point d'atelier et le mécanicien, puis ne remet les propriétés d'une
--  ligne qu'au moment où l'animation la pose (quoteInstallStep). Chaque ligne posée et
--  vérifiée est marquée « installed » et enregistrée en base : une intervention
--  interrompue (annulation, mort, déconnexion, véhicule déplacé…) peut être reprise,
--  et seules les lignes posées sont facturées, comme avant.
-- =====================================================================
local P = Meca
local Q = Config.Quotes

P.quotes = {}   -- [uid] = devis actif (pending / accepted)
P.wsBusy = {}   -- [id du point d'atelier] = { uid, by } : une seule intervention par emplacement
local IC = Config.Interventions or {}
local BEAT_TIMEOUT = tonumber(IC.serverTimeout) or 120   -- secondes sans nouvelle du mécanicien → intervention libérée

-- Clés d'elyzea_core par type de modification GTA (inverse de la table MODS du core)
local MOD_KEYS = {
    [0] = 'modSpoilers', [1] = 'modFrontBumper', [2] = 'modRearBumper', [3] = 'modSideSkirt', [4] = 'modExhaust', [5] = 'modFrame',
    [6] = 'modGrille', [7] = 'modHood', [8] = 'modFender', [9] = 'modRightFender', [10] = 'modRoof', [14] = 'modHorns',
    [25] = 'modPlateHolder', [26] = 'modVanityPlate', [27] = 'modTrimA', [28] = 'modOrnaments', [29] = 'modDashboard', [30] = 'modDial',
    [31] = 'modDoorSpeaker', [32] = 'modSeats', [33] = 'modSteeringWheel', [34] = 'modShifterLeavers', [35] = 'modAPlate', [36] = 'modSpeakers',
    [37] = 'modTrunk', [38] = 'modHydrolic', [39] = 'modEngineBlock', [40] = 'modAirFilter', [41] = 'modStruts', [42] = 'modArchCover',
    [43] = 'modAerials', [44] = 'modTrimB', [45] = 'modTank', [46] = 'modWindows', [47] = 'modDoorR', [49] = 'modLightbar',
}
local BODY_IDS = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true,
    [10] = true, [14] = true, [37] = true, [38] = true, [39] = true, [40] = true, [41] = true, [42] = true, [43] = true, [44] = true, [45] = true, [46] = true, [47] = true, [49] = true }
local INTERIOR_IDS = { [25] = true, [26] = true, [27] = true, [28] = true, [29] = true, [30] = true, [31] = true, [32] = true, [33] = true,
    [34] = true, [35] = true, [36] = true }
local PERF_KEYS = { engine = 'modEngine', brakes = 'modBrakes', transmission = 'modTransmission', suspension = 'modSuspension', armor = 'modArmor' }

local function N(v, mn, mx) v = tonumber(v) if not v or v ~= v then return nil end v = math.floor(v) if v < mn or v > mx then return nil end return v end
-- Requête SQL dont certaines valeurs peuvent être vides (nil) : chaque nil devient NULL directement
-- dans le texte SQL et n'est pas envoyé en paramètre. Sans ça, un nil décale les paramètres suivants
-- (une table Lua s'arrête au premier trou) et la requête vise la mauvaise ligne.
-- vals = { n = nombre de « ? », [1] = …, [2] = … }
local function Bind(sql, vals)
    local out, i = {}, 0
    local sql2 = sql:gsub('%?', function()
        i = i + 1
        local v = vals[i]
        if v == nil then return 'NULL' end
        out[#out + 1] = v
        return '?'
    end)
    return sql2, out
end

local function RGB(t)
    if type(t) ~= 'table' then return nil end
    local r, g, b = N(t[1], 0, 255), N(t[2], 0, 255), N(t[3], 0, 255)
    if not r or not g or not b then return nil end
    return { r, g, b }
end

-- Néons : uniquement les couleurs de la palette de l'atelier (Config.Lights)
local function IsLight(c)
    for _, l in ipairs(Config.Lights) do if l[2] == c[1] and l[3] == c[2] and l[4] == c[3] then return true end end
    return false
end

-- Spécification esthétique envoyée par le client → propriétés elyzea_core (validées ici)
-- Renvoie patch, clé d'unicité
local function CosmeticPatch(group, s)
    if type(s) ~= 'table' then return nil end
    local t = s.t
    if group == 'body' or group == 'interior' then
        local id = N(s.id, 0, 48)
        local ids = group == 'body' and BODY_IDS or INTERIOR_IDS
        local v = N(s.v, -1, 100)
        if not id or not ids[id] or not v or t ~= 'mod' then return nil end
        return { [MOD_KEYS[id]] = v }, 'mod' .. id
    elseif group == 'wheels' and t == 'wheels' then
        local wt, v = N(s.wt, 0, 13), N(s.v, -1, 300)
        if not wt or not v then return nil end
        return { wheels = wt, modFrontWheels = v, modBackWheels = v }, 'wheels'
    elseif group == 'wheelcolor' and t == 'wheelcolor' then
        local v = N(s.v, 0, 160) if not v then return nil end
        return { wheelColor = v }, 'wheelcolor'
    elseif group == 'paint' and t == 'paint' then
        local slot = N(s.slot, 1, 2)
        local finish = N(s.finish, 0, 5) or 0
        if not slot then return nil end
        local color = type(s.color) == 'table' and RGB(s.color) or N(s.color, 0, 160)
        if not color then return nil end
        if slot == 1 then return { color1 = color, paintType1 = finish }, 'paint1' end
        return { color2 = color, paintType2 = finish }, 'paint2'
    elseif group == 'pearl' and t == 'pearl' then
        local v = N(s.v, 0, 160) if not v then return nil end
        return { pearlescentColor = v }, 'pearl'
    elseif group == 'livery' and t == 'livery' then
        local v = N(s.v, -1, 60) if not v then return nil end
        return { modLivery = v }, 'livery'
    elseif group == 'tint' and t == 'tint' then
        local v = N(s.v, 0, 6) if not v then return nil end
        return { windowTint = v }, 'tint'
    elseif (group == 'intcolor' or group == 'dashcolor') and t == group then
        local v = N(s.v, 0, 160) if not v then return nil end
        return { [group == 'intcolor' and 'interiorColor' or 'dashboardColor'] = v }, group
    elseif group == 'tyres' and t == 'tyres' then
        local ct = s.custom == true
        return { modCustomTiresF = ct, modCustomTiresR = ct }, 'tyres'   -- pneus pare-balles retirés de l'atelier
    elseif group == 'extras' and t == 'extra' then
        local id = N(s.id, 0, 20) if not id then return nil end
        return { extras = { [tostring(id)] = s.on == true and 0 or 1 } }, 'extra' .. id
    elseif group == 'roofliv' and t == 'roofliv' then
        local v = N(s.v, 0, 30) if not v then return nil end
        return { modRoofLivery = v }, 'roofliv'
    elseif group == 'platetext' and t == 'platetext' then
        local p = exports.elyzea_core:CleanNewPlate(s.v)
        if not p then return nil end
        return {}, 'platetext', p
    elseif group == 'plate' and t == 'plate' then
        local v = N(s.v, 0, 5) if not v then return nil end
        return { plateIndex = v }, 'plate'
    elseif group == 'smoke' and t == 'smoke' then
        local c = RGB(s.rgb) if not c then return nil end
        return { modSmokeEnabled = true, tyreSmokeColor = c }, 'smoke'
    elseif group == 'neon' and t == 'neon' then
        local on = s.on == true
        local c = on and RGB(s.rgb) or { 255, 255, 255 }
        if not c then return nil end
        if on and not IsLight(c) then return nil end   -- couleur libre / multicolore : staff seulement
        local sides = tostring(s.sides or '1111')
        if not sides:match('^[01][01][01][01]$') then sides = '1111' end
        local en = {}
        for i = 1, 4 do en[i] = on and sides:sub(i, i) == '1' end
        return { neonEnabled = en, neonColor = c }, 'neon'
    elseif group == 'xenon' and t == 'xenon' then
        local on = s.on == true
        if on and s.rgb ~= nil then return nil end     -- couleur libre des phares : staff seulement (admin_menu)
        local v = on and (N(s.v, -1, 12) or -1) or -1
        return { modXenon = on, xenonColor = v }, 'xenon'
    end
    return nil
end

-- ---------------------------------------------------------------------
-- Points d'atelier : placés en jeu par la direction (tablette › Direction › Points d'atelier)
-- Gardés dans meca_settings (clé 'workshops'), publiés aux clients par GlobalState.mecaWorkshops.
-- ---------------------------------------------------------------------
local WD = Config.WorkshopDefaults
local function Vec(t) return type(t) == 'table' and tonumber(t.x) and vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0) or nil end
local function Pos(src)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    local c = GetEntityCoords(veh ~= 0 and veh or ped)
    return { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100 }
end

function P.WorkshopList()
    local list = {}
    for _, w in ipairs(P.GetSetting('workshops', {})) do
        if type(w) == 'table' and w.id then
            -- Ancien format (point du mécanicien + emplacement) : on garde l'emplacement du véhicule
            if w.vehicle then w.coords, w.vehicle = w.vehicle, nil end
            list[#list + 1] = w
        end
    end
    return list
end
local function Publish()
    local pub = {}
    for _, w in ipairs(P.WorkshopList()) do
        if w.coords then
            pub[#pub + 1] = { id = w.id, label = w.label, coords = w.coords, radius = w.radius, categories = w.categories, minLevel = w.minLevel,
                lift = type(w.lift) == 'table' and { h = tonumber(w.lift.h) or 0.0 } or nil }
        end
    end
    GlobalState.mecaWorkshops = pub
end
P.PublishWorkshops = Publish
P.WorkshopById = function(id) return Workshop(id) end
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = Publish

local function Workshop(id)
    for _, w in ipairs(P.WorkshopList()) do
        if w.id == id and w.coords then
            return { id = w.id, label = w.label, coords = Vec(w.coords), radius = tonumber(w.radius) or WD.radius,
                categories = w.categories or {}, minLevel = tonumber(w.minLevel) or 1, lift = type(w.lift) == 'table' and w.lift or nil }
        end
    end
end

P.Actions.workshopList = { perm = 'garage_manage', fn = function(src)
    local grades = {}
    for _, g in ipairs(P.SortedGrades(P.MyJob(src))) do grades[#grades + 1] = { level = g.level, name = g.name } end
    local list = {}
    for _, w in ipairs(P.WorkshopList()) do
        local n = 0
        for _, q in pairs(P.quotes) do if q.workshop == w.id then n = n + 1 end end
        local c = w.coords and P.Coords(src)
        list[#list + 1] = { id = w.id, label = w.label, coords = w.coords, radius = w.radius, categories = w.categories, minLevel = w.minLevel,
            lift = w.lift ~= nil, quotes = n, distance = c and math.floor(#(c - Vec(w.coords))) or nil }
    end
    return { list = list, categories = P.CATEGORIES, grades = grades, max = Config.WorkshopMax, defaults = WD }
end }

local function Find(list, id) for i, w in ipairs(list) do if w.id == id then return w, i end end end

-- Créer (au point où se tient la direction) ou modifier le nom, les rubriques, le grade et la tolérance
P.Actions.workshopSave = { perm = 'garage_manage', fn = function(src, d)
    local list = P.WorkshopList()
    local w = d.id and Find(list, tostring(d.id)) or nil
    if d.id and not w then return { error = 'Point introuvable.' } end
    local label = P.Clean(d.label, 40)
    if #label < 2 then return { error = 'Nom trop court.' } end
    local cats, seen = {}, {}
    for _, c in ipairs(type(d.categories) == 'table' and d.categories or {}) do
        c = tostring(c)
        if P.CATEGORIES[c] and not seen[c] then seen[c] = true cats[#cats + 1] = c end
    end
    if #cats == 0 then return { error = 'Choisissez au moins une rubrique.' } end
    local minLevel = P.Int(d.minLevel, 1, 99, 1)
    local radius = math.max(1.5, math.min(8.0, tonumber(d.radius) or WD.radius))
    if not w then
        if #list >= Config.WorkshopMax then return { error = ('%d points maximum.'):format(Config.WorkshopMax) } end
        w = { id = P.Uid('WS'), coords = Pos(src) }
        list[#list + 1] = w
    end
    w.label, w.categories, w.minLevel, w.radius = label, cats, minLevel, math.floor(radius * 10) / 10
    P.SetSetting('workshops', list)
    Publish()
    P.AddLog(src, nil, nil, d.id and 'Point d\'atelier modifié' or 'Point d\'atelier créé', nil, label, nil)
    return { ok = true, id = w.id, message = d.id and ('« %s » enregistré.'):format(label)
        or ('« %s » créé à votre position.'):format(label) }
end }

-- Déplacer le point à votre position (ou celle du véhicule si vous êtes dedans)
P.Actions.workshopPlace = { perm = 'garage_manage', fn = function(src, d)
    local list = P.WorkshopList()
    local w = Find(list, tostring(d.id or ''))
    if not w then return { error = 'Point introuvable.' } end
    w.coords = Pos(src)
    P.SetSetting('workshops', list)
    Publish()
    P.AddLog(src, nil, nil, 'Point d\'atelier déplacé', nil, w.label, nil)
    return { ok = true, message = ('« %s » déplacé à votre position.'):format(w.label) }
end }

P.Actions.workshopDelete = { perm = 'garage_manage', fn = function(src, d)
    local list = P.WorkshopList()
    local w, i = Find(list, tostring(d.id or ''))
    if not w then return { error = 'Point introuvable.' } end
    for _, q in pairs(P.quotes) do
        if q.workshop == w.id then return { error = 'Un devis est en cours sur ce point : terminez-le ou annulez-le d\'abord.' } end
    end
    if w.lift and P.GiveLiftItem and not P.GiveLiftItem(src) then
        return { error = 'Ce point a un pont roulant : libérez de la place dans votre inventaire pour le récupérer.' }
    end
    table.remove(list, i)
    P.SetSetting('workshops', list)
    Publish()
    P.AddLog(src, nil, nil, 'Point d\'atelier supprimé', nil, w.label, nil)
    return { ok = true, message = ('« %s » supprimé.'):format(w.label) }
end }
local function Allowed(w, item)
    if not w then return item.kind == 'service' or item.kind == 'custom' end   -- devis hors atelier (F6) : prestations seulement
    for _, c in ipairs(w.categories) do if c == item.category then return true end end
    return false
end

-- Le mécanicien est au point d'atelier et le véhicule sur l'emplacement
local function CheckWorkshop(src, w, net)
    if not w then return nil, 'Point d\'atelier inconnu.' end
    local g = P.Grade(src)
    if not g or g.level < (w.minLevel or 1) then return nil, 'Votre grade ne permet pas d\'utiliser ce point.' end
    if not P.Can(src, 'workshop') then return nil, 'Votre grade ne permet pas d\'utiliser les points d\'atelier.' end
    local veh = NetworkGetEntityFromNetworkId(tonumber(net) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil, 'Amenez le véhicule du client sur le point.' end
    if #(GetEntityCoords(veh) - w.coords) > (w.radius or 3.5) + 1.0 then return nil, 'Le véhicule n\'est pas sur le point d\'atelier.' end
    local c = P.Coords(src)
    if not c or #(c - GetEntityCoords(veh)) > 6.0 then return nil, 'Restez avec le véhicule.' end
    return veh
end

local function NearbyCustomers(src, veh, ownerCid)
    local list = {}
    local vc = GetEntityCoords(veh)
    -- Le mécanicien peut se faire un devis à lui-même (ses propres customisations)
    if Q.allowSelf ~= false then list[#list + 1] = { id = src, self = true, owner = ownerCid ~= nil and P.Cid(src) == ownerCid, name = P.Name(src) } end
    for _, s in ipairs(GetPlayers()) do
        local id = tonumber(s)
        if id ~= src then
            local c = P.Coords(id)
            if c and #(c - vc) <= Config.Distances.workshopCustomer then
                local isOwner = ownerCid ~= nil and P.Cid(id) == ownerCid
                list[#list + 1] = { id = id, owner = isOwner, name = isOwner and P.Name(id) or nil }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.owner ~= b.owner then return a.owner end
        if (a.self == true) ~= (b.self == true) then return b.self == true end   -- un client en premier, soi-même ensuite
        return a.id < b.id
    end)
    return list
end

local function ActiveQuoteForPlate(plate)
    for _, q in pairs(P.quotes) do
        if q.plate == plate and (q.status == 'pending' or q.status == 'accepted') then return q end
    end
end

local function QuoteView(q)
    return { uid = q.uid, status = q.status, total = q.total, items = q.items, plate = q.plate, model = q.model, mechanic = q.mechanicName,
        customer = q.customerName, workshop = q.workshop, t = q.t, expires = q.expires }
end

-- ---------------------------------------------------------------------
-- Interventions en cours : verrous, état de la scène, remise en état
-- ---------------------------------------------------------------------
local function WorkshopLocked(wsId, src)
    local l = wsId and P.wsBusy[wsId]
    if not l then return false end
    local q = P.quotes[l.uid]
    if not q or not q.installing then P.wsBusy[wsId] = nil return false end   -- verrou orphelin
    return l.by ~= src
end

-- Lignes réellement posées (prestations comprises seulement à la fin normale d'une installation)
local function InstalledOnly(q)
    local r = {}
    for i, l in ipairs(q.items) do r[i] = l.installed == true end
    return r
end
local function AnyInstalled(q) for _, l in ipairs(q.items) do if l.installed then return true end end return false end

-- Remet la scène en état quand le mécanicien n'est plus là pour le faire (déconnexion, délai) :
-- objets temporaires supprimés, véhicule redescendu et libéré par le joueur qui le contrôle.
local function CleanScene(q)
    local ins = q.installing
    if not ins then return end
    for _, net in ipairs(ins.scene and ins.scene.props or {}) do
        local e = NetworkGetEntityFromNetworkId(tonumber(net) or 0)
        if e and e ~= 0 and DoesEntityExist(e) and GetEntityType(e) == 3 then DeleteEntity(e) end
    end
    local veh = ins.veh
    if veh and DoesEntityExist(veh) then
        local owner = NetworkGetEntityOwner(veh)
        if owner and owner > 0 and GetPlayerName(owner) then
            TriggerClientEvent('meca:client:interventionRestore', owner, NetworkGetNetworkIdFromEntity(veh), ins.base, ins.scene or {})
        else
            if ins.base then SetEntityCoords(veh, ins.base.x, ins.base.y, ins.base.z, false, false, false, false) end
            FreezeEntityPosition(veh, false)
        end
    end
end

-- Libère le point et le mécanicien (clean = remettre la scène en état côté serveur)
local function Release(q, clean)
    if not q.installing then return end
    if clean then CleanScene(q) end
    for id, l in pairs(P.wsBusy) do if l.uid == q.uid then P.wsBusy[id] = nil end end
    q.installing = nil
end

-- Les lignes posées sont gardées en base : une reprise ou un redémarrage n'en perd aucune
local function SaveItems(q)
    MySQL.update('UPDATE `meca_quotes` SET `items` = ?, `updated_at` = NOW() WHERE `uid` = ?', { json.encode(q.items), q.uid })
end

-- Intervention du mécanicien (vérifie que c'est bien lui qui installe ce devis)
local function Installing(src, uid)
    local q = P.quotes[tostring(uid or '')]
    if not q or q.status ~= 'accepted' or not q.installing or q.installing.by ~= src then return nil end
    return q
end

-- État de la scène envoyé par le client (objets réseau, capot démonté, pneus retirés, véhicule levé)
local function Scene(q, sc)
    if type(sc) ~= 'table' then return end
    local props = {}
    for i, n in ipairs(type(sc.props) == 'table' and sc.props or {}) do
        if i > 20 then break end
        if tonumber(n) then props[#props + 1] = math.floor(tonumber(n)) end
    end
    local tyres = {}
    for i, t in ipairs(type(sc.tyres) == 'table' and sc.tyres or {}) do
        if i > 8 then break end
        local v = N(t, 0, 7)
        if v then tyres[#tyres + 1] = v end
    end
    q.installing.scene = { props = props, tyres = tyres, hood = sc.hood == true, lifted = sc.lifted == true }
    q.installing.beat = os.time()
end

-- ---------------------------------------------------------------------
-- Ouverture d'un point d'atelier
-- ---------------------------------------------------------------------
P.Actions.wsOpen = { perm = 'workshop', duty = true, fn = function(src, d)
    local w = Workshop(tostring(d.ws or ''))
    local veh, why = CheckWorkshop(src, w, d.net)
    if not veh then return { error = why } end
    if WorkshopLocked(w.id, src) then return { error = 'Une intervention est en cours sur ce point : attendez qu\'elle soit terminée.' } end
    local plate = P.CleanPlate(GetVehicleNumberPlateText(veh))
    local row = P.VehicleRow(plate)
    local ok, mods = pcall(json.decode, row and row.mods or '{}')
    mods = ok and type(mods) == 'table' and mods or {}
    local items = {}
    for _, it in ipairs(P.SortedCatalog()) do
        if it.enabled and Allowed(w, it) then
            local can, reason = P.CanSell(src, it)
            items[#items + 1] = { code = it.code, name = it.name, description = it.description, category = it.category, kind = it.kind, mod = it.mod,
                level = it.level, price = it.price, locked = not can, reason = reason }
        end
    end
    local saved = {}
    for key, k in pairs(PERF_KEYS) do saved[key] = (tonumber(mods[k]) or -1) + 1 end
    saved.turbo = mods.modTurbo == true and 1 or 0
    local q = ActiveQuoteForPlate(plate)
    return { ws = { id = w.id, label = w.label, categories = w.categories }, plate = plate, owned = row ~= nil, vehicleId = row and row.id,
        owner = row and P.OwnerName(row.citizenid) or nil, carplay = row and P.HasCarPlay(plate) or false, savedPerf = saved,
        items = items, categories = P.CATEGORIES, customers = NearbyCustomers(src, veh, row and row.citizenid),
        quote = q and QuoteView(q) or nil, canInstall = q and (q.mechanicCid == P.Cid(src) or P.Can(src, 'quotes_manage')) or false }
end }

-- ---------------------------------------------------------------------
-- Création d'un devis (atelier ou F6 pour les prestations)
-- ---------------------------------------------------------------------
local function BuildLines(src, w, list, ctx)
    if type(list) ~= 'table' or #list == 0 then return nil, 'Le devis est vide.' end
    if #list > Q.maxItems then return nil, ('%d lignes maximum.'):format(Q.maxItems) end
    local lines, seen, total = {}, {}, 0
    for _, req in ipairs(list) do
        local it = P.catalog[tostring(type(req) == 'table' and req.code or '')]
        if not it then return nil, 'Article inconnu dans le devis.' end
        local can, why = P.CanSell(src, it)
        if not can then return nil, why end
        if not Allowed(w, it) then return nil, ('« %s » ne s\'installe pas à ce point.'):format(it.name) end
        local line = { code = it.code, name = it.name, kind = it.kind, price = it.price, qty = 1 }
        if it.kind == 'perf' then
            local key = it.mod
            if seen['perf:' .. key] then return nil, ('Une seule amélioration « %s » par devis.'):format(key) end
            seen['perf:' .. key] = true
            local cur = math.max(tonumber(ctx.savedPerf[key]) or 0, tonumber(type(req.current) == 'number' and req.current or 0) or 0)
            if (it.level or 1) <= cur then return nil, ('« %s » : le véhicule a déjà ce niveau ou mieux.'):format(it.name) end
            line.patch = key == 'turbo' and { modTurbo = true } or { [PERF_KEYS[key]] = (it.level or 1) - 1 }
            line.label = it.name
        elseif it.kind == 'cosmetic' then
            local patch, slot, plateText = CosmeticPatch(it.mod, req.spec)
            if not patch then return nil, ('Option invalide pour « %s ».'):format(it.name) end
            if seen['cos:' .. slot] then return nil, 'La même pièce apparaît deux fois dans le devis.' end
            seen['cos:' .. slot] = true
            if plateText then
                if not ctx.vehicleId then return nil, 'La plaque personnalisée ne se pose que sur un véhicule de joueur (carte grise).' end
                if plateText == ctx.plate then return nil, 'C\'est déjà la plaque du véhicule.' end
                if MySQL.scalar.await('SELECT `id` FROM `player_vehicles` WHERE `plate` = ? LIMIT 1', { plateText }) then return nil, ('La plaque « %s » est déjà prise.'):format(plateText) end
                line.plateText = plateText
                patch = nil
            end
            line.patch = patch
            local lbl = P.Clean(req.label, 60)
            -- « Néons : Or » déjà préfixé par l'interface : pas de « Néons : Néons : Or »
            line.label = lbl:sub(1, #it.name) == it.name and lbl or ('%s : %s'):format(it.name, lbl)
        elseif it.kind == 'carplay' then
            if not ctx.vehicleId then return nil, 'Le CarPlay ne s\'installe que sur un véhicule de joueur (carte grise).' end
            if seen.carplay then return nil, 'Le CarPlay apparaît deux fois.' end
            seen.carplay = true
            local has = P.HasCarPlay(ctx.plate)
            if it.code == 'carplay' and has then return nil, 'Ce véhicule a déjà le CarPlay : aucune nouvelle installation à facturer.' end
            if it.code ~= 'carplay' and not has then return nil, 'Une réinstallation n\'est possible que sur un véhicule déjà équipé.' end
            line.label = it.name
        else
            line.qty = N(req.qty, 1, 10) or 1
            line.label = it.name
        end
        line.total = line.price * line.qty
        total = total + line.total
        lines[#lines + 1] = line
    end
    return lines, total
end

local Answer   -- acceptation / refus d'un devis (défini plus bas)

P.Actions.quoteCreate = { perm = 'quotes', duty = true, fn = function(src, d)
    local w = d.ws and Workshop(tostring(d.ws)) or nil
    local veh, why
    if w then
        veh, why = CheckWorkshop(src, w, d.net)
        if not veh then return { error = why } end
        if WorkshopLocked(w.id, src) then return { error = 'Une intervention est en cours sur ce point.' } end
    else
        veh = NetworkGetEntityFromNetworkId(tonumber(d.net) or 0)
        if not veh or veh == 0 or not DoesEntityExist(veh) then veh = nil end
    end
    local plate = veh and P.CleanPlate(GetVehicleNumberPlateText(veh)) or nil
    if plate and ActiveQuoteForPlate(plate) then return { error = 'Un devis est déjà en cours pour ce véhicule.' } end
    local cust = tonumber(d.customer)
    if not cust or (cust == src and Q.allowSelf == false) or not GetPlayerName(cust) or not P.GetPlayer(cust) then return { error = 'Choisissez le client.' } end
    local ref = veh and GetEntityCoords(veh) or P.Coords(src)
    local cc = P.Coords(cust)
    if not cc or not ref or #(cc - ref) > (w and Config.Distances.workshopCustomer or Config.Distances.quote + 4.0) then return { error = 'Le client doit être à côté.' } end
    local row = plate and P.VehicleRow(plate) or nil
    local ok, mods = pcall(json.decode, row and row.mods or '{}')
    mods = ok and type(mods) == 'table' and mods or {}
    local savedPerf = {}
    for key, k in pairs(PERF_KEYS) do savedPerf[key] = (tonumber(mods[k]) or -1) + 1 end
    savedPerf.turbo = mods.modTurbo == true and 1 or 0
    local lines, total = BuildLines(src, w, d.items, { savedPerf = savedPerf, vehicleId = row and row.id, plate = plate })
    if not lines then return { error = total } end
    local uid = P.Uid('DEV')
    local q = { uid = uid, status = 'pending', items = lines, total = total, plate = plate, vehicleId = row and row.id,
        model = P.Clean(d.model, 60), net = veh and NetworkGetNetworkIdFromEntity(veh) or nil, workshop = w and w.id or nil,
        job = P.MyJob(src),   -- garage (agence) qui encaisse
        mechanic = src, mechanicCid = P.Cid(src), mechanicName = P.Name(src), customer = cust, customerCid = P.Cid(cust), customerName = P.Name(cust),
        t = os.time(), expires = os.time() + Q.acceptTimeout }
    P.quotes[uid] = q
    MySQL.insert.await(Bind([[INSERT INTO `meca_quotes` (`job`, `uid`, `customer_cid`, `customer_name`, `vehicle_id`, `plate`, `model`, `mechanic_cid`, `mechanic_name`, `workshop`, `items`, `total`, `status`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')]], { q.job, uid, q.customerCid, q.customerName, q.vehicleId, plate, q.model, q.mechanicCid, q.mechanicName, q.workshop,
        json.encode(lines), total }))
    -- Devis pour soi-même : le mécanicien a validé l'envoi, il paie tout de suite (pas de fenêtre d'acceptation)
    if cust == src then
        local r = Answer(src, q, true)
        if not r.ok then return { error = r.message } end
        return { ok = true, quote = QuoteView(q), message = r.message }
    end
    TriggerClientEvent('meca:client:quoteOffer', cust, QuoteView(q), Q.acceptTimeout)
    return { ok = true, quote = QuoteView(q), message = ('Devis %s envoyé (%d $).'):format(uid, total) }
end }

-- Enregistre l'état du devis. extra = colonnes en plus (« , `col` = ? »), args = leurs valeurs (nil accepté)
local function Save(q, extra, args)
    extra = extra or ''
    local sql = 'UPDATE `meca_quotes` SET `status` = ?, `paid` = ?, `refunded` = ?, `method` = ?, `updated_at` = NOW()' .. extra .. ' WHERE `uid` = ?'
    local vals = { q.status, q.paid or 0, q.refunded or 0, q.method }
    local k = select(2, extra:gsub('%?', ''))
    for i = 1, k do vals[4 + i] = args and args[i] end   -- valeurs à leur place exacte, même vides
    vals[5 + k] = q.uid
    local ok, err = pcall(function() MySQL.update.await(Bind(sql, vals)) end)
    if not ok then print(('^1[MECA] Devis %s : enregistrement impossible : %s^0'):format(tostring(q.uid), tostring(err))) end
end

-- Facture finale : seulement les lignes réellement posées
local function Finalize(q, results, actorSrc)
    Release(q, false)
    -- Déjà facturé (facture existante pour ce devis) : rien n'est refait (ni remboursement, ni facture, ni commission)
    local existing = MySQL.scalar.await('SELECT `uid` FROM `meca_invoices` WHERE `quote_uid` = ? LIMIT 1', { q.uid })
    if existing then
        q.status = (q.status == 'accepted' or q.status == 'pending') and 'installed' or q.status
        Save(q, ', `invoice_uid` = ?', { existing })
        P.quotes[q.uid] = nil
        return { ok = true, status = q.status, amount = 0, refund = 0, invoice = existing, failed = 0, already = true }
    end
    local done, failed, amount = {}, {}, 0
    for i, line in ipairs(q.items) do
        if results[i] then done[#done + 1] = line amount = amount + line.total else failed[#failed + 1] = line end
    end
    local refund = math.max(0, (q.paid or 0) - amount)
    local refundNote
    if refund > 0 then
        if P.SocietyRemove(refund, ('Remboursement devis %s (non installé)'):format(q.uid), q.job) then
            local back = P.Refund(q.customerCid, refund, q.method, 'Remboursement ' .. q.uid)
            if back then
                q.refunded = refund
                P.Tx({ job = q.job, type = 'out', category = 'refund', amount = refund, reason = 'Prestations non installées', actorName = 'Système',
                    targetCid = q.customerCid, targetName = q.customerName, ref = q.uid })
            else
                P.SocietyAdd(refund, ('Annulation remboursement %s'):format(q.uid), q.job)
                refundNote = ('Remboursement de %d $ à faire à la main'):format(refund)
            end
        else
            refundNote = ('Remboursement de %d $ à faire : fonds de l\'entreprise insuffisants'):format(refund)
        end
    end
    q.status = #done == 0 and 'failed' or (#failed > 0 and 'partial' or 'installed')
    local invoiceUid
    if #done > 0 then
        invoiceUid = P.Uid('FAC')
        MySQL.insert.await(Bind([[INSERT INTO `meca_invoices` (`job`, `uid`, `quote_uid`, `customer_cid`, `customer_name`, `vehicle_id`, `plate`, `mechanic_name`, `items`, `amount`, `status`, `method`, `txid`, `note`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'paid', ?, ?, ?)]], { q.job, invoiceUid, q.uid, q.customerCid, q.customerName, q.vehicleId, q.plate, q.mechanicName,
            json.encode(done), amount, q.method, q.txid, refundNote }))
        -- Commission du mécanicien sur le montant final (lignes réellement posées)
        -- Pas de commission sur ses propres customisations (sinon le mécanicien se rembourserait une partie)
        if not (q.mechanicCid and q.mechanicCid == q.customerCid) or Q.selfCommission == true then
            P.Commission(q.mechanicCid, amount, ('Devis %s · %s'):format(q.uid, q.customerName or ''), invoiceUid)
        end
    end
    Save(q, ', `invoice_uid` = ?, `note` = ?', { invoiceUid, refundNote })
    -- Persistance : modifications sur la carte grise, CarPlay lié au véhicule, historique
    local patch = {}
    for _, line in ipairs(done) do
        if line.patch then
            for k, v in pairs(line.patch) do
                if k == 'extras' then patch.extras = patch.extras or {} for id, x in pairs(v) do patch.extras[id] = x end
                else patch[k] = v end
            end
        end
        if line.kind == 'carplay' and q.vehicleId then
            MySQL.query.await([[INSERT INTO `meca_carplay` (`vehicle_id`, `plate`, `invoice_uid`, `price`, `installed_by`) VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE `invoice_uid` = VALUES(`invoice_uid`), `price` = `price` + VALUES(`price`), `installed_by` = VALUES(`installed_by`), `installed_at` = NOW()]],
                { q.vehicleId, q.plate, invoiceUid, line.total, q.mechanicName })
            P.ForgetCarPlay(q.plate)
        end
        P.History(q.vehicleId, q.plate or '', line.kind == 'carplay' and 'CarPlay installé' or (line.kind == 'service' or line.kind == 'custom') and 'Prestation' or 'Installation',
            ('%s · %d $'):format(line.label, line.total), invoiceUid, actorSrc)
    end
    if q.vehicleId and next(patch) then P.SaveMods(q.vehicleId, patch) end
    P.quotes[q.uid] = nil
    local cust = q.customerCid and exports.elyzea_core:GetSourceByCitizenId(q.customerCid)
    if cust then
        P.Notify(cust, (#failed > 0 and 'Facture %s : %d $ (%d prestation(s) non installée(s), %d $ remboursés).' or 'Facture %s : %d $. Merci !')
            :format(invoiceUid or q.uid, amount, #failed, refund), #failed > 0 and 'inform' or 'success')
    end
    return { ok = true, status = q.status, amount = amount, refund = refund, invoice = invoiceUid, failed = #failed, note = refundNote }
end

-- Réponse du client : paiement immédiat du total à l'acceptation
local answering = {}
-- Acceptation (paiement immédiat du total) ou refus. Renvoie { ok, message }.
Answer = function(src, q, accept)
    answering[q.uid] = true
    local mech = q.mechanic
    local self = q.customer == mech
    local function tellMech(msg, kind)
        if self then return end
        if GetPlayerName(mech) then P.Notify(mech, msg, kind) TriggerClientEvent('meca:client:quoteUpdate', mech, QuoteView(q)) end
    end
    local function done(ok, msg, kind) answering[q.uid] = nil P.Notify(src, msg, kind) return { ok = ok, message = msg } end
    if os.time() > q.expires then
        q.status = 'expired' Save(q) P.quotes[q.uid] = nil
        tellMech(('Devis %s expiré.'):format(q.uid), 'error')
        return done(false, 'Le devis a expiré.', 'error')
    end
    if accept ~= true then
        q.status = 'refused' Save(q) P.quotes[q.uid] = nil
        tellMech(('Le client a refusé le devis %s.'):format(q.uid), 'error')
        return done(false, 'Devis refusé.', 'inform')
    end
    local method = P.Charge(src, q.total, ('Devis garage %s'):format(q.uid))
    if not method then
        q.status = 'refused' q.note = 'fonds insuffisants' Save(q, ', `note` = ?', { 'Fonds insuffisants' }) P.quotes[q.uid] = nil
        tellMech(('Le client n\'a pas assez d\'argent (%d $) : devis %s annulé.'):format(q.total, q.uid), 'error')
        return done(false, ('Fonds insuffisants (%d $).'):format(q.total), 'error')
    end
    if q.total > 0 and not P.SocietyAdd(q.total, ('Devis %s · %s'):format(q.uid, q.customerName), q.job) then
        P.Refund(q.customerCid, q.total, method, 'Annulation ' .. q.uid)
        q.status = 'failed' Save(q, ', `note` = ?', { 'Compte société indisponible' }) P.quotes[q.uid] = nil
        tellMech('Compte de l\'entreprise indisponible : client remboursé.', 'error')
        return done(false, 'Paiement annulé et remboursé.', 'error')
    end
    q.status, q.paid, q.method = 'accepted', q.total, method == 'free' and nil or method
    q.txid = q.total > 0 and P.Tx({ job = q.job, type = 'in', category = 'invoice', amount = q.total, reason = self and 'Devis personnel' or 'Devis accepté',
        actorCid = q.mechanicCid, actorName = q.mechanicName, targetCid = q.customerCid, targetName = q.customerName, ref = q.uid }) or nil
    q.acceptedAt = os.time()
    Save(q)
    -- Prestations seules (réparations déjà faites…) : facture tout de suite
    local onlyServices = true
    for _, l in ipairs(q.items) do if l.kind ~= 'service' and l.kind ~= 'custom' then onlyServices = false end end
    if onlyServices then
        local res = {}
        for i = 1, #q.items do res[i] = true end
        local r = Finalize(q, res, mech)
        tellMech(('Devis %s accepté et facturé : %d $.'):format(q.uid, r.amount), 'success')
        return done(true, ('Devis %s payé et facturé : %d $.'):format(q.uid, r.amount), 'success')
    end
    tellMech(('Devis %s accepté (%d $) : installez les prestations.'):format(q.uid, q.total), 'success')
    if self then return done(true, ('Devis %s payé (%d $) : cliquez sur « Installer » pour faire votre custom.'):format(q.uid, q.total), 'success') end
    return done(true, ('Devis accepté : %d $ payés. Les prestations non installées vous seront remboursées.'):format(q.total), 'success')
end

-- Réponse du client (fenêtre de devis)
RegisterNetEvent('meca:server:quoteAnswer', function(uid, accept)
    local src = source
    local q = P.quotes[tostring(uid or '')]
    if not q or q.status ~= 'pending' or q.customer ~= src or answering[q.uid] then return end
    Answer(src, q, accept == true)
end)

-- Installation animée : le serveur verrouille le point et le mécanicien, puis donne la liste
-- des lignes (sans leurs propriétés : elles sont remises une par une, au moment de la pose)
P.Actions.quoteInstallStart = { perm = 'workshop', duty = true, fn = function(src, d)
    local q = P.quotes[tostring(d.uid or '')]
    if not q or q.status ~= 'accepted' then return { error = 'Ce devis n\'est pas prêt à être installé.' } end
    if q.mechanicCid ~= P.Cid(src) and not P.Can(src, 'quotes_manage') then return { error = 'Seul le mécanicien du devis peut l\'installer.' } end
    if q.installing and q.installing.by ~= src and GetPlayerName(q.installing.by) and os.time() - (q.installing.beat or 0) < BEAT_TIMEOUT then
        return { error = 'Un autre mécanicien installe déjà ce devis.' }
    end
    for _, other in pairs(P.quotes) do
        if other ~= q and other.installing and other.installing.by == src then return { error = 'Vous avez déjà une intervention en cours.' } end
    end
    local w = Workshop(q.workshop or '')
    local veh, why = CheckWorkshop(src, w, d.net)
    if not veh then return { error = why } end
    if P.CleanPlate(GetVehicleNumberPlateText(veh)) ~= q.plate then return { error = 'Ce n\'est pas le véhicule du devis.' } end
    if WorkshopLocked(w.id, src) then return { error = 'Une intervention est déjà en cours sur ce point.' } end
    local c = GetEntityCoords(veh)
    q.installing = { by = src, t = GetGameTimer(), veh = veh, net = NetworkGetNetworkIdFromEntity(veh), beat = os.time(), granted = {},
        base = { x = c.x, y = c.y, z = c.z }, scene = {} }
    P.wsBusy[w.id] = { uid = q.uid, by = src }
    -- Personne ne reste dans le véhicule pendant l'intervention (client, passagers)
    for _, s in ipairs(GetPlayers()) do
        local id = tonumber(s)
        if id ~= src and GetVehiclePedIsIn(GetPlayerPed(id), false) == veh then
            TriggerClientEvent('meca:client:leaveVehicle', id, q.installing.net)
        end
    end
    local cust = q.customerCid and exports.elyzea_core:GetSourceByCitizenId(q.customerCid)
    if cust and cust ~= src then P.Notify(cust, ('Intervention en cours sur votre véhicule (%s).'):format(q.plate or '?'), 'inform') end
    local lines = {}
    for i, l in ipairs(q.items) do
        local keys = {}
        for k in pairs(l.patch or {}) do keys[#keys + 1] = k end
        table.sort(keys)
        lines[i] = { i = i, label = l.label, kind = l.kind, code = l.code, keys = keys, plate = l.plateText ~= nil, done = l.installed == true }
    end
    return { ok = true, lines = lines, uid = q.uid, lift = w.lift ~= nil }
end }

-- Une ligne est sur le point d'être posée : ses propriétés exactes (une seule fois par ligne et par passage)
P.Actions.quoteInstallStep = { perm = 'workshop', duty = true, fn = function(src, d)
    local q = Installing(src, d.uid)
    if not q then return { error = 'Intervention non démarrée.' } end
    local i = N(d.i, 1, #q.items)
    local line = i and q.items[i]
    if not line then return { error = 'Ligne inconnue.' } end
    if line.installed then return { error = 'Cette ligne est déjà posée.' } end
    if q.installing.granted[i] then return { error = 'Cette ligne est déjà en cours de pose.' } end
    local veh = q.installing.veh
    if not veh or not DoesEntityExist(veh) then return { error = 'Le véhicule a disparu.' } end
    local cc = P.Coords(src)
    if not cc or #(cc - GetEntityCoords(veh)) > 10.0 then return { error = 'Restez auprès du véhicule.' } end
    q.installing.granted[i] = true
    Scene(q, d.scene)
    return { ok = true, patch = line.patch, plate = line.plateText ~= nil }
end }

-- Résultat de la pose d'une ligne (relue sur le véhicule par le client)
P.Actions.quoteInstallStepDone = { perm = 'workshop', duty = true, fn = function(src, d)
    local q = Installing(src, d.uid)
    if not q then return { error = 'Intervention non démarrée.' } end
    local i = N(d.i, 1, #q.items)
    if not i or not q.installing.granted[i] then return { error = 'Ligne non commencée.' } end
    q.installing.granted[i] = nil
    if d.ok == true and not q.items[i].installed then
        q.items[i].installed = true
        SaveItems(q)
    end
    Scene(q, d.scene)
    return { ok = true }
end }

-- Le mécanicien est toujours là (longues étapes) : état de la scène à jour
P.Actions.quoteInstallBeat = { perm = 'workshop', duty = true, fn = function(src, d)
    local q = Installing(src, d.uid)
    if not q then return { error = 'Intervention non démarrée.' } end
    Scene(q, d.scene)
    return { ok = true }
end }

-- Interruption (annulation, mort, véhicule déplacé…) : la scène a été remise en état par le client.
-- Le devis reste payé et en attente : les lignes déjà posées sont gardées, la suite peut être reprise.
P.Actions.quoteInstallAbort = { perm = 'workshop', fn = function(src, d)
    local q = Installing(src, d.uid)
    if not q then return { ok = true } end
    Release(q, d.cleaned ~= true)
    local n, total = 0, 0
    for _, l in ipairs(q.items) do if l.kind ~= 'service' and l.kind ~= 'custom' then total = total + 1 if l.installed then n = n + 1 end end end
    P.Log(src, 'Intervention interrompue', ('%s · %d/%d posée(s) · %s'):format(q.uid, n, total, P.Clean(d.reason, 80)))
    local left = math.max(1, math.floor((Q.installTimeout - (os.time() - (q.acceptedAt or os.time()))) / 60))
    return { ok = true, message = ('Intervention interrompue : %d/%d pièce(s) posée(s). Rouvrez l\'atelier et « Installer » pour reprendre (sinon remboursement automatique des pièces non posées dans %d min).')
        :format(n, total, left) }
end }

-- Fin de l'intervention : facture des lignes réellement posées (comptées par le serveur)
P.Actions.quoteInstallDone = { perm = 'workshop', duty = true, fn = function(src, d)
    local q = Installing(src, d.uid)
    if not q then return { error = 'Installation non démarrée.' } end
    local results = {}
    for i, l in ipairs(q.items) do
        local ok = l.installed == true
        if l.kind == 'service' or l.kind == 'custom' then ok = true end
        -- Plaque personnalisée : changée par le serveur (carte grise, clés, coffre du véhicule)
        if l.plateText and ok then
            local veh = q.installing.veh
            local old = q.plate
            local changed, why = exports.elyzea_core:ChangePlate(old, l.plateText, veh and DoesEntityExist(veh) and veh or nil)
            ok = changed == true
            if ok then
                P.ForgetCarPlay(old)
                q.plate = l.plateText
                P.History(q.vehicleId, l.plateText, 'Plaque changée', ('%s → %s'):format(old or '?', l.plateText), q.uid, src)
                if q.customerCid then
                    local cust = exports.elyzea_core:GetSourceByCitizenId(q.customerCid)
                    if cust then exports.elyzea_core:GiveKeys(cust, l.plateText) end
                end
            else
                l.installed = nil
                P.Notify(src, why or 'Plaque non changée.', 'error')
            end
        end
        results[i] = ok
    end
    local r = Finalize(q, results, src)
    P.Log(src, 'Installation', ('%s · %s · %d $'):format(q.uid, q.plate or '?', r.amount))
    r.message = r.failed > 0 and ('Facture %s : %d $ (%d ligne(s) non posée(s), %d $ remboursés). Le véhicule peut repartir.'):format(r.invoice or '-', r.amount, r.failed, r.refund)
        or ('Intervention terminée · facture %s : %d $. Le véhicule peut repartir.'):format(r.invoice or '-', r.amount)
    local cust = q.customerCid and exports.elyzea_core:GetSourceByCitizenId(q.customerCid)
    if cust and cust ~= src then P.Notify(cust, 'Intervention terminée : votre véhicule peut repartir.', 'success') end
    return r
end }

-- Annulation par le mécanicien : avant acceptation, ou après (remboursement intégral)
P.Actions.quoteCancel = { perm = 'quotes', fn = function(src, d)
    local q = P.quotes[tostring(d.uid or '')]
    if not q then return { error = 'Devis introuvable ou terminé.' } end
    if q.mechanicCid ~= P.Cid(src) and not P.Can(src, 'quotes_manage') then return { error = 'Ce devis n\'est pas le vôtre.' } end
    if q.status == 'accepted' then
        if q.installing and GetPlayerName(q.installing.by) and os.time() - (q.installing.beat or 0) < BEAT_TIMEOUT then
            return { error = 'Une intervention est en cours sur ce devis : interrompez-la d\'abord (X).' }
        end
        local partial = AnyInstalled(q)
        local r = Finalize(q, InstalledOnly(q), src)   -- pièces déjà posées : facturées ; le reste : remboursé
        if not partial then q.status = 'cancelled' Save(q) end
        r.message = partial and ('Devis clos : pièces posées facturées, %d $ remboursés.'):format(r.refund) or ('Devis annulé : %d $ remboursés.'):format(r.refund)
        return r
    end
    q.status = 'cancelled' Save(q) P.quotes[q.uid] = nil
    if GetPlayerName(q.customer) then TriggerClientEvent('meca:client:quoteClosed', q.customer, q.uid) end
    return { ok = true, message = 'Devis annulé.' }
end }

-- Expirations : devis pas répondus ; devis payés jamais installés (remboursés)
CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for _, q in pairs(P.quotes) do
            if q.status == 'pending' and now > q.expires then
                q.status = 'expired' Save(q) P.quotes[q.uid] = nil
                if GetPlayerName(q.customer) then TriggerClientEvent('meca:client:quoteClosed', q.customer, q.uid) end
            elseif q.status == 'accepted' and q.installing and now - (q.installing.beat or now) > BEAT_TIMEOUT then
                -- Mécanicien sans nouvelles : intervention libérée, scène remise en état, devis repris plus tard
                local by = q.installing.by
                Release(q, true)
                if GetPlayerName(by) then P.Notify(by, ('Intervention %s interrompue (délai dépassé).'):format(q.uid), 'error') end
            elseif q.status == 'accepted' and not q.installing and now - (q.acceptedAt or now) > Q.installTimeout then
                local partial = AnyInstalled(q)
                local r = Finalize(q, InstalledOnly(q), nil)
                if not partial then q.status = 'expired' Save(q) end
                print(('^3[MECA] Devis %s %s : %d $ remboursés.^0'):format(q.uid, partial and 'installé en partie' or 'jamais installé', r.refund))
            end
        end
    end
end)

-- Devis payés laissés en cours par un arrêt du serveur : remboursés au démarrage
P.OnReady = P.OnReady or {}
P.OnReady[#P.OnReady + 1] = function()
    MySQL.update.await("UPDATE `meca_quotes` SET `status` = 'expired', `updated_at` = NOW() WHERE `status` = 'pending'")
    -- Réparation : devis déjà facturés mais restés « accepted » (ancien bug d'enregistrement du statut).
    -- Ils ne doivent être ni remboursés ni refacturés au démarrage.
    local fixed = MySQL.update.await([[UPDATE `meca_quotes` q JOIN `meca_invoices` i ON i.`quote_uid` = q.`uid`
        SET q.`status` = 'installed', q.`invoice_uid` = i.`uid`, q.`updated_at` = NOW() WHERE q.`status` = 'accepted']])
    if (tonumber(fixed) or 0) > 0 then print(('^3[MECA] %d devis déjà facturé(s) remis à l\'état « installé » (aucun remboursement ni double facture).^0'):format(fixed)) end
    for _, r in ipairs(MySQL.query.await("SELECT * FROM `meca_quotes` WHERE `status` = 'accepted'") or {}) do
        local okj, items = pcall(json.decode, r.items or '[]')
        local q = { uid = r.uid, job = r.job, items = okj and type(items) == 'table' and items or {}, paid = tonumber(r.paid) or 0, method = r.method, customerCid = r.customer_cid, customerName = r.customer_name,
            plate = r.plate, vehicleId = r.vehicle_id, mechanicName = r.mechanic_name, mechanicCid = r.mechanic_cid, status = 'accepted' }
        -- Intervention interrompue par l'arrêt : les pièces déjà posées sont facturées et enregistrées, le reste remboursé
        if AnyInstalled(q) then
            local ok, res = pcall(Finalize, q, InstalledOnly(q), nil)
            print(ok and ('^3[MECA] Devis %s : intervention interrompue par l\'arrêt, pièces posées facturées (%d $), %d $ remboursés.^0'):format(q.uid, res.amount, res.refund)
                or ('^1[MECA] Devis %s : %s^0'):format(q.uid, tostring(res)))
            goto continue
        end
        local refund = q.paid
        local done = false
        if refund > 0 and P.SocietyRemove(refund, ('Remboursement devis %s (arrêt du serveur)'):format(q.uid), q.job) then
            if P.Refund(q.customerCid, refund, q.method, 'Remboursement ' .. q.uid) then
                P.Tx({ job = q.job, type = 'out', category = 'refund', amount = refund, reason = 'Devis non installé (arrêt du serveur)', actorName = 'Système',
                    targetCid = q.customerCid, targetName = q.customerName, ref = q.uid })
                done = true
            else
                P.SocietyAdd(refund, ('Annulation remboursement %s'):format(q.uid), q.job)
            end
        end
        MySQL.update.await(Bind('UPDATE `meca_quotes` SET `status` = ?, `refunded` = ?, `note` = ?, `updated_at` = NOW() WHERE `uid` = ?',
            { 'expired', done and refund or 0, (not done) and ('Remboursement de %d $ à faire'):format(refund) or nil, q.uid }))
        ::continue::
    end
end

-- ---------------------------------------------------------------------
-- Consultation (F6, tablette)
-- ---------------------------------------------------------------------
-- Devis en cours (job : ceux d'une agence)
function P.OpenQuotes(job)
    local list = {}
    for _, q in pairs(P.quotes) do if not job or q.job == job then list[#list + 1] = QuoteView(q) end end
    table.sort(list, function(a, b) return a.t > b.t end)
    return list
end

P.Actions.quotes = { perm = 'quotes', fn = function(src, d)
    local mine = d.mine == true or not P.Can(src, 'quotes_manage')
    local where, args = { '`job` = ?' }, { P.MyJob(src) }
    if mine then where[#where + 1] = '`mechanic_cid` = ?' args[#args + 1] = P.Cid(src) end
    local st = tostring(d.status or '')
    if st:match('^%a+$') then where[#where + 1] = '`status` = ?' args[#args + 1] = st end
    local q = P.Clean(d.q, 40):gsub('[%%_]', '')
    if q ~= '' then
        local like = '%' .. q .. '%'
        where[#where + 1] = '(`uid` LIKE ? OR `plate` LIKE ? OR `customer_name` LIKE ? OR `mechanic_name` LIKE ?)'
        for _ = 1, 4 do args[#args + 1] = like end
    end
    local rows = MySQL.query.await([[SELECT `uid`, `customer_name`, `plate`, `model`, `mechanic_name`, `items`, `total`, `paid`, `refunded`, `status`, `invoice_uid`, `note`,
        UNIX_TIMESTAMP(`created_at`) AS t FROM `meca_quotes`]] .. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '') .. ' ORDER BY `id` DESC LIMIT 120', args) or {}
    for _, r in ipairs(rows) do local ok, it = pcall(json.decode, r.items or '[]') r.items = ok and it or {} end
    return { list = rows, active = P.OpenQuotes(P.MyJob(src)), canManage = P.Can(src, 'quotes_manage') }
end }

P.Actions.invoices = { perm = 'quotes', fn = function(src, d)
    if not (P.Can(src, 'finance') or P.Can(src, 'quotes_manage')) then
        return { list = MySQL.query.await([[SELECT `uid`, `quote_uid`, `customer_name`, `plate`, `mechanic_name`, `items`, `amount`, `status`, `method`, `note`,
            UNIX_TIMESTAMP(`created_at`) AS t FROM `meca_invoices` WHERE `mechanic_name` = ? ORDER BY `id` DESC LIMIT 80]], { P.Name(src) }) or {}, canManage = false }
    end
    local q = P.Clean(d.q, 40):gsub('[%%_]', '')
    local rows
    if q ~= '' then
        local like = '%' .. q .. '%'
        rows = MySQL.query.await([[SELECT `uid`, `quote_uid`, `customer_name`, `plate`, `mechanic_name`, `items`, `amount`, `status`, `method`, `note`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `meca_invoices` WHERE `job` = ? AND (`uid` LIKE ? OR `plate` LIKE ? OR `customer_name` LIKE ?) ORDER BY `id` DESC LIMIT 150]], { P.MyJob(src), like, like, like })
    else
        rows = MySQL.query.await([[SELECT `uid`, `quote_uid`, `customer_name`, `plate`, `mechanic_name`, `items`, `amount`, `status`, `method`, `note`, UNIX_TIMESTAMP(`created_at`) AS t
            FROM `meca_invoices` WHERE `job` = ? ORDER BY `id` DESC LIMIT 150]], { P.MyJob(src) })
    end
    for _, r in ipairs(rows or {}) do local ok, it = pcall(json.decode, r.items or '[]') r.items = ok and it or {} end
    return { list = rows or {}, canManage = P.Can(src, 'quotes_manage') }
end }

-- Remboursement d'une facture (une seule fois) ; le CarPlay remboursé est retiré du véhicule
local refunding = {}
P.Actions.invoiceRefund = { perm = 'quotes_manage', fn = function(src, d)
    local uid = tostring(d.uid or ''):sub(1, 40)
    if refunding[uid] then return { error = 'Opération en cours.' } end
    refunding[uid] = true
    local ok, res = pcall(function()
        local inv = MySQL.single.await('SELECT * FROM `meca_invoices` WHERE `uid` = ?', { uid })
        if not inv or inv.job ~= P.MyJob(src) then return { error = 'Facture introuvable.' } end
        local job = inv.job
        if inv.status ~= 'paid' then return { error = 'Cette facture n\'est pas remboursable.' } end
        local reason = P.Clean(d.reason, 160)
        if #reason < 3 then return { error = 'Indiquez le motif.' } end
        local amount = tonumber(inv.amount) or 0
        if amount > 0 and not P.SocietyRemove(amount, ('Remboursement facture %s'):format(uid), job) then return { error = ('Fonds insuffisants (%d $).'):format(amount) } end
        if amount > 0 and not P.Refund(inv.customer_cid, amount, inv.method, 'Remboursement ' .. uid) then
            P.SocietyAdd(amount, ('Annulation remboursement %s'):format(uid), job)
            return { error = 'Remboursement impossible sur le compte du client : rien n\'a changé.' }
        end
        MySQL.update.await('UPDATE `meca_invoices` SET `status` = ?, `note` = ?, `updated_at` = NOW() WHERE `uid` = ?', { 'refunded', ('%s · %s'):format(reason, P.Name(src)), uid })
        if amount > 0 then
            P.Tx({ job = job, type = 'out', category = 'refund', amount = amount, reason = 'Remboursement : ' .. reason, actorCid = P.Cid(src), actorName = P.Name(src),
                targetCid = inv.customer_cid, targetName = inv.customer_name, ref = uid })
        end
        if inv.vehicle_id and MySQL.scalar.await('SELECT 1 FROM `meca_carplay` WHERE `invoice_uid` = ?', { uid }) then
            MySQL.update.await('DELETE FROM `meca_carplay` WHERE `invoice_uid` = ?', { uid })
            P.ForgetCarPlay(inv.plate)
            P.History(inv.vehicle_id, inv.plate, 'CarPlay retiré', 'Facture remboursée : ' .. reason, uid, src)
        end
        P.History(inv.vehicle_id, inv.plate or '', 'Facture remboursée', ('%d $ · %s'):format(amount, reason), uid, src)
        return { ok = true, message = ('Facture %s remboursée (%d $).'):format(uid, amount) }
    end)
    refunding[uid] = nil
    if not ok then print(('^1[MECA] Remboursement : %s^0'):format(tostring(res))) return { error = 'Erreur pendant le remboursement.' } end
    return res
end }

AddEventHandler('playerDropped', function()
    local src = source
    for _, q in pairs(P.quotes) do
        if q.status == 'pending' and (q.customer == src or q.mechanic == src) then
            q.status = 'cancelled' Save(q) P.quotes[q.uid] = nil
        elseif q.installing and q.installing.by == src then
            -- Mécanicien déconnecté en pleine intervention : scène remise en état, devis repris plus tard
            Release(q, true)
        end
    end
end)
