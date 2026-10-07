--[[
    GO FAST - Interface d'administration (utilisée par le menu staff admin_menu)
    * exports.gofast:AdminGetData()            -> état complet pour l'onglet Événements › GoFast
    * exports.gofast:AdminAction(src, nom, d)  -> exécute une action, puis répond via l'évènement
      SERVEUR local 'gofast:adminReply' (src, ok, message, extra).
    Les permissions sont vérifiées par admin_menu AVANT l'appel ; ici on valide toutes les données.
    Aucune de ces fonctions ne bloque l'appelant : le travail se fait dans un thread de gofast
    (un export qui attend une réponse de base de données planterait la ressource appelante).
]]

local U = GoFast.Utils
local Core -- GoFastCore, défini à la fin de server/main.lua

local Actions = {}

-- =========================================================================
-- OUTILS
-- =========================================================================
local function Reply(src, ok, message, extra)
    TriggerEvent('gofast:adminReply', src, ok, message, extra or {})
end

local function StaffPosition(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped), GetEntityHeading(ped), ped
end

--- Point envoyé par le client du staff, accepté seulement s'il est proche de sa position serveur
local function TrustedPoint(point, reference, maxDistance)
    local cleaned = Contacts.CleanPoint(point)
    if not cleaned then return nil end
    if #(vector3(cleaned.x, cleaned.y, cleaned.z) - reference) > maxDistance then return nil end
    return cleaned
end

local function ContactArg(data)
    local contact = Contacts.Get(data.id)
    if not contact then return nil, 'Contact introuvable (il a peut-être été supprimé).' end
    return contact
end

local function LocationArg(contact, data)
    local index = math.floor(tonumber(data.index) or 0)
    local location = contact.locations[index]
    if not location then return nil, nil, 'Emplacement introuvable.' end
    return location, index
end

local function TeleportNear(point)
    return { x = point.x + 1.2, y = point.y + 1.2, z = point.z + 0.5 }
end

--- Point véhicule : véhicule du staff, sinon sa position au sol
local function VehiclePointFromStaff(src, data)
    local coords, heading = StaffPosition(src)
    if not coords then return nil end
    if data.vehicle then
        local point = TrustedPoint(data.vehicle, coords, 10.0)
        if point then return point end
    end
    local groundZ = tonumber(data.ground)
    local z = (groundZ and math.abs(groundZ - coords.z) < 3.0) and groundZ or (coords.z - 1.0)
    return Contacts.CleanPoint({ x = coords.x, y = coords.y, z = z, h = heading })
end

-- =========================================================================
-- ÉTAT GÉNÉRAL
-- =========================================================================
Actions.toggle = function(src)
    Store.data.enabled = Store.data.enabled == false
    Contacts.Changed()
    local state = Store.data.enabled and 'ouvert' or 'fermé'
    Log('admin', 'GoFast ' .. state, Security.PlayerLabel(src))
    return true, ('Réseau Go Fast %s.'):format(state), { log = 'Réseau ' .. state }
end

Actions.settings = function(src, data)
    if type(data.values) ~= 'table' then return false, 'Aucune valeur reçue.' end
    local changed = 0
    for _, field in ipairs(Store.SettingsSchema) do
        if data.values[field.key] ~= nil then
            local value = Store.CleanValue(field, data.values[field.key])
            if value == nil then return false, ('Valeur invalide : %s.'):format(field.label) end
            if value == Store.GetDefaultSetting(field.key) then value = nil end
            Store.data.settings[field.key] = value
            changed = changed + 1
        end
    end
    Store.ApplySettings()
    Store.Save()
    return true, 'Réglages enregistrés.', { log = 'Réglages modifiés', details = ('%d valeur(s)'):format(changed) }
end

Actions.settings_reset = function()
    Store.data.settings = {}
    Store.ApplySettings()
    Store.Save()
    return true, 'Réglages remis par défaut.', { log = 'Réglages remis par défaut' }
end

-- =========================================================================
-- PALIERS
-- =========================================================================
Actions.tier = function(src, data)
    local tier = U.GetTier(data.id)
    if not tier then return false, 'Palier introuvable.' end
    if type(data.values) ~= 'table' then return false, 'Aucune valeur reçue.' end

    local overrides = Store.data.tiers[tier.id] or {}
    local defaults = Store.GetDefaultTier(tier.id)
    for _, field in ipairs(Store.TierSchema) do
        if data.values[field.key] ~= nil then
            local value = Store.CleanValue(field, data.values[field.key])
            if value == nil then return false, ('Valeur invalide : %s.'):format(field.label) end
            overrides[field.key] = (value ~= defaults[field.key]) and value or nil
        end
    end
    local minReward = overrides.rewardMin or defaults.rewardMin
    local maxReward = overrides.rewardMax or defaults.rewardMax
    if maxReward < minReward then return false, 'La paie max doit être supérieure ou égale à la paie min.' end
    local minDrops = overrides.dropsMin or defaults.dropsMin
    local maxDrops = overrides.dropsMax or defaults.dropsMax
    if maxDrops < minDrops then return false, 'Le nombre max de livraisons doit être supérieur ou égal au min.' end

    Store.data.tiers[tier.id] = next(overrides) and overrides or nil
    Store.ApplyTiers()
    Store.Save()
    return true, ('Palier « %s » enregistré.'):format(tier.label), { log = 'Palier modifié', details = tier.id }
end

Actions.tier_reset = function(src, data)
    local tier = U.GetTier(data.id)
    if not tier then return false, 'Palier introuvable.' end
    Store.data.tiers[tier.id] = nil
    Store.ApplyTiers()
    Store.Save()
    return true, ('Palier « %s » remis par défaut.'):format(tier.label), { log = 'Palier remis par défaut', details = tier.id }
end

-- =========================================================================
-- CONTACTS
-- =========================================================================
local function NewLocationAtStaff(src, data, label)
    local coords, heading = StaffPosition(src)
    if not coords then return nil, 'Position introuvable.' end
    local location = Contacts.CleanLocation({ label = label, x = coords.x, y = coords.y, z = coords.z, h = heading, vehicles = {} })
    if not location then return nil, 'Position invalide.' end
    local node = data.node and TrustedPoint(data.node, coords, Config.Manage.AutoRoadPointDistance)
    if node then location.vehicles[1] = node end
    return location
end

local function NoVehicleWarning(location)
    if #location.vehicles == 0 then
        return ' Aucun point véhicule trouvé : ajoute-en un (« Ajouter un point véhicule »), sinon les missions ne pourront pas démarrer.'
    end
    return ''
end

Actions.contact_create = function(src, data)
    local contact, message = Contacts.New(type(data.fields) == 'table' and data.fields or {})
    if not contact then return false, message end
    local location, err = NewLocationAtStaff(src, data, Contacts.CleanText(data.locationLabel, 40) or '')
    if not location then
        Contacts.Remove(contact.id)
        return false, err
    end
    contact.locations[1] = location
    contact.current = 1
    contact.nextMoveAt = os.time() + math.floor(contact.rotation.intervalMin * 60)
    Contacts.Changed()
    return true, ('Contact « %s » créé à ta position.%s'):format(contact.label, NoVehicleWarning(location)),
        { log = 'Contact créé', details = contact.label, select = contact.id }
end

Actions.contact_update = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    if type(data.fields) ~= 'table' then return false, 'Aucune modification reçue.' end
    local ok, message = Contacts.ApplyFields(contact, data.fields)
    if not ok then return false, message end
    Contacts.Changed()
    return true, ('Contact « %s » enregistré.'):format(contact.label), { log = 'Contact modifié', details = contact.label }
end

Actions.contact_delete = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    Contacts.Remove(contact.id)
    Contacts.Changed()
    return true, ('Contact « %s » supprimé.'):format(contact.label), { log = 'Contact supprimé', details = contact.label }
end

Actions.loc_add = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    if #contact.locations >= Config.Manage.MaxLocations then
        return false, ('Limite de %d emplacements atteinte.'):format(Config.Manage.MaxLocations)
    end
    local location, message = NewLocationAtStaff(src, data, Contacts.CleanText(data.label, 40) or '')
    if not location then return false, message end
    contact.locations[#contact.locations + 1] = location
    Contacts.Changed()
    return true, ('Emplacement %d ajouté.%s'):format(#contact.locations, NoVehicleWarning(location)),
        { log = 'Emplacement ajouté', details = contact.label }
end

Actions.loc_here = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    local location, index, message = LocationArg(contact, data)
    if not location then return false, message end
    local coords, heading = StaffPosition(src)
    if not coords then return false, 'Position introuvable.' end
    location.x, location.y, location.z = Store.Round(coords.x, 3), Store.Round(coords.y, 3), Store.Round(coords.z, 3)
    location.h = Store.Round(heading % 360, 2)
    Contacts.Changed()
    return true, ('Emplacement %d placé à ta position.'):format(index), { log = 'Emplacement déplacé', details = contact.label }
end

Actions.loc_rename = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    local location, _, message = LocationArg(contact, data)
    if not location then return false, message end
    location.label = Contacts.CleanText(data.label, 40) or ''
    Contacts.Changed()
    return true, 'Emplacement renommé.'
end

Actions.loc_remove = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    local location, index, message = LocationArg(contact, data)
    if not location then return false, message end
    table.remove(contact.locations, index)
    if contact.current > index then
        contact.current = contact.current - 1
    elseif contact.current == index then
        contact.current = math.min(index, math.max(1, #contact.locations))
    end
    Contacts.Changed()
    local warning = #contact.locations == 0 and ' Ce contact n\'a plus d\'emplacement : il n\'apparaît plus.' or ''
    return true, ('Emplacement supprimé.%s'):format(warning), { log = 'Emplacement supprimé', details = contact.label }
end

Actions.veh_add = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    local location, index, message = LocationArg(contact, data)
    if not location then return false, message end
    if #location.vehicles >= Config.Manage.MaxVehiclePoints then
        return false, ('Limite de %d points véhicule atteinte.'):format(Config.Manage.MaxVehiclePoints)
    end
    local point = VehiclePointFromStaff(src, data)
    if not point then return false, 'Position introuvable.' end
    local distance = #(vector3(point.x, point.y, point.z) - vector3(location.x, location.y, location.z))
    if distance > 300.0 then
        return false, ('Trop loin du contact (%d m). Le véhicule doit apparaître à moins de 300 m.'):format(math.floor(distance))
    end
    location.vehicles[#location.vehicles + 1] = point
    Store.Save()
    return true, ('Point véhicule ajouté à l\'emplacement %d (%d m du contact).'):format(index, math.floor(distance)),
        { log = 'Point véhicule ajouté', details = contact.label }
end

Actions.veh_remove = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    local location, _, message = LocationArg(contact, data)
    if not location then return false, message end
    local vehicleIndex = math.floor(tonumber(data.point) or 0)
    if not location.vehicles[vehicleIndex] then return false, 'Point véhicule introuvable.' end
    table.remove(location.vehicles, vehicleIndex)
    Store.Save()
    return true, 'Point véhicule supprimé.'
end

Actions.move_now = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    if #contact.locations == 0 then return false, 'Ce contact n\'a aucun emplacement.' end
    local target = tonumber(data.index) and math.floor(tonumber(data.index)) or Contacts.NextIndex(contact)
    if not contact.locations[target] then return false, 'Emplacement introuvable.' end
    Contacts.MoveTo(contact, target)
    local location = contact.locations[target]
    return true, ('« %s » est maintenant à l\'emplacement %d%s.'):format(contact.label, target,
        location.label ~= '' and (' (' .. location.label .. ')') or ''), { log = 'Contact déplacé', details = contact.label }
end

Actions.tp = function(src, data)
    local contact, err = ContactArg(data)
    if not contact then return false, err end
    local index = tonumber(data.index) and math.floor(tonumber(data.index)) or contact.current
    local location = contact.locations[index]
    if not location then return false, 'Emplacement introuvable.' end
    if data.point then
        local point = location.vehicles[math.floor(tonumber(data.point) or 0)]
        if not point then return false, 'Point véhicule introuvable.' end
        return true, nil, { teleport = { x = point.x, y = point.y, z = point.z + 1.0 } }
    end
    return true, nil, { teleport = TeleportNear(location) }
end

--- Transforme un PNJ de l'éditeur de map (admin_menu) en contact GoFast
Actions.import_ped = function(src, data)
    local ped = data.ped
    if type(ped) ~= 'table' then return false, 'PNJ introuvable.' end
    local contact, message = Contacts.New({
        label = (type(ped.name) == 'string' and ped.name ~= '') and ped.name or 'Contact',
        model = ped.model,
        scenario = ped.scenario,
    })
    if not contact then return false, message end
    local location = Contacts.CleanLocation({ label = '', x = ped.x, y = ped.y, z = ped.z, h = ped.h, vehicles = {} })
    if not location then
        Contacts.Remove(contact.id)
        return false, 'Position du PNJ invalide.'
    end
    local reference = vector3(location.x, location.y, location.z)
    local node = data.node and TrustedPoint(data.node, reference, Config.Manage.AutoRoadPointDistance)
    if node then location.vehicles[1] = node end
    contact.locations[1] = location
    Contacts.Changed()
    return true, ('« %s » est maintenant un contact GoFast.%s'):format(contact.label, NoVehicleWarning(location)),
        { log = 'PNJ converti en contact', details = contact.label, select = contact.id, importedFrom = tonumber(data.editorPedId) }
end

-- =========================================================================
-- DESTINATIONS
-- =========================================================================
local function CleanZone(value)
    if type(value) ~= 'string' then return nil end
    local zone = value:lower():gsub('[^%w_]', ''):sub(1, 20)
    if zone == '' then return nil end
    return zone
end

Actions.dest_add = function(src, data)
    local coords, _, ped = StaffPosition(src)
    if not coords then return false, 'Position introuvable.' end
    local label = Contacts.CleanText(data.label, 40)
    if not label or label == '' then return false, 'Donne un nom à la destination.' end
    local zone = CleanZone(data.zone)
    if not zone then return false, 'Choisis une zone.' end

    local point
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle and vehicle ~= 0 then
        local vehicleCoords = GetEntityCoords(vehicle)
        point = { x = vehicleCoords.x, y = vehicleCoords.y, z = vehicleCoords.z - 0.5 }
    else
        local groundZ = tonumber(data.ground)
        point = { x = coords.x, y = coords.y, z = (groundZ and math.abs(groundZ - coords.z) < 3.0) and groundZ or coords.z - 1.0 }
    end

    local list = Store.EditableDestinations()
    for _, destination in ipairs(list) do
        if #(vector3(destination.x, destination.y, destination.z) - vector3(point.x, point.y, point.z)) < 25.0 then
            return false, ('Une destination existe déjà ici : « %s ».'):format(destination.label)
        end
    end
    list[#list + 1] = { label = label, zone = zone, x = Store.Round(point.x, 2), y = Store.Round(point.y, 2), z = Store.Round(point.z, 2) }
    Store.ApplyDestinations()
    Store.Save()
    return true, ('Destination « %s » ajoutée (zone %s).'):format(label, zone), { log = 'Destination ajoutée', details = label }
end

local function DestinationArg(data)
    local list = Store.EditableDestinations()
    local index = math.floor(tonumber(data.index) or 0)
    if not list[index] then return nil, nil, 'Destination introuvable.' end
    return list[index], index, list
end

Actions.dest_update = function(src, data)
    local destination, _, err = DestinationArg(data)
    if not destination then return false, err end
    if data.label ~= nil then
        local label = Contacts.CleanText(data.label, 40)
        if not label or label == '' then return false, 'Nom invalide.' end
        destination.label = label
    end
    if data.zone ~= nil then
        local zone = CleanZone(data.zone)
        if not zone then return false, 'Zone invalide.' end
        destination.zone = zone
    end
    Store.ApplyDestinations()
    Store.Save()
    return true, 'Destination enregistrée.'
end

Actions.dest_remove = function(src, data)
    local destination, index, list = DestinationArg(data)
    if not destination then return false, list end
    table.remove(list, index)
    Store.ApplyDestinations()
    Store.Save()
    return true, ('Destination « %s » supprimée.'):format(destination.label), { log = 'Destination supprimée', details = destination.label }
end

Actions.dest_tp = function(src, data)
    local list = Config.Destinations
    local destination = list[math.floor(tonumber(data.index) or 0)]
    if not destination then return false, 'Destination introuvable.' end
    return true, nil, { teleport = { x = destination.coords.x, y = destination.coords.y, z = destination.coords.z + 1.0 } }
end

Actions.dest_reset = function()
    Store.ResetDestinations()
    return true, 'Destinations remises par défaut (config.lua).', { log = 'Destinations remises par défaut' }
end

-- =========================================================================
-- MISSIONS ET JOUEURS
-- =========================================================================
local function TargetArg(data)
    local target = math.floor(tonumber(data.target) or 0)
    if target <= 0 or not GetPlayerName(target) then return nil, 'Joueur introuvable.' end
    return target
end

Actions.mission_stop = function(src, data)
    local target, err = TargetArg(data)
    if not target then return false, err end
    local mission = Core.ActiveMissions[target]
    if not mission then return false, 'Ce joueur n\'a pas de Go Fast en cours.' end
    Core.FailMission(target, 'fail_admin', 'Fail')
    local key = Bridge.GetLicense(target) or Bridge.GetIdentifier(target)
    if key then Core.Cooldowns[key] = nil end
    return true, ('Go Fast de %s annulé (sans attente).'):format(GetPlayerName(target)),
        { log = 'Mission annulée', details = ('%s (%s)'):format(GetPlayerName(target), mission.id) }
end

Actions.mission_tp = function(src, data)
    local target, err = TargetArg(data)
    if not target then return false, err end
    local mission = Core.ActiveMissions[target]
    if not mission or not mission.vehicle or not DoesEntityExist(mission.vehicle) then return false, 'Véhicule de mission introuvable.' end
    local coords = GetEntityCoords(mission.vehicle)
    return true, nil, { teleport = { x = coords.x + 2.5, y = coords.y + 2.5, z = coords.z + 1.0 } }
end

local function PlayerSummary(target, identifier)
    local stats = Rewards.LoadStats(identifier)
    local levelData = U.GetLevelData(stats.xp)
    local key = Bridge.GetLicense(target) or identifier
    return {
        id = target, name = GetPlayerName(target), level = levelData.level, xp = stats.xp,
        missions = stats.missions, cooldown = Core.GetCooldownRemaining(key),
        nextLevelXp = levelData.nextLevelXp,
    }
end

Actions.player_info = function(src, data)
    local target, err = TargetArg(data)
    if not target then return false, err end
    local identifier = Bridge.GetIdentifier(target)
    if not identifier then return false, 'Personnage non chargé.' end
    local info = PlayerSummary(target, identifier)
    return true, ('%s : niveau %d, %d XP, %d Go Fast réussi(s), attente %s.'):format(info.name, info.level, info.xp,
        info.missions, info.cooldown > 0 and U.FormatDuration(info.cooldown) or 'aucune'), { player = info }
end

Actions.player_resetcd = function(src, data)
    local target, err = TargetArg(data)
    if not target then return false, err end
    local key = Bridge.GetLicense(target) or Bridge.GetIdentifier(target)
    if key then Core.Cooldowns[key] = nil end
    return true, ('Attente de %s supprimée.'):format(GetPlayerName(target)), { log = 'Attente supprimée', details = GetPlayerName(target) }
end

local function ChangeXp(src, data, mode)
    local target, err = TargetArg(data)
    if not target then return false, err end
    local identifier = Bridge.GetIdentifier(target)
    if not identifier then return false, 'Personnage non chargé.' end
    local amount = math.floor(tonumber(data.value) or 0)
    if mode == 'set' and amount < 0 then return false, 'L\'XP ne peut pas être négative.' end
    if math.abs(amount) > 10000000 then return false, 'Valeur trop grande.' end
    Rewards.LoadStats(identifier)
    if mode == 'set' then
        Rewards.SetXP(identifier, amount)
    else
        local stats = Rewards.GetCachedStats(identifier)
        Rewards.SetXP(identifier, stats.xp + amount)
    end
    local info = PlayerSummary(target, identifier)
    return true, ('%s : %d XP (niveau %d).'):format(info.name, info.xp, info.level),
        { log = mode == 'set' and 'XP définie' or 'XP ajoutée', details = ('%s -> %d XP'):format(info.name, info.xp), player = info }
end

Actions.player_setxp = function(src, data) return ChangeXp(src, data, 'set') end
Actions.player_addxp = function(src, data) return ChangeXp(src, data, 'add') end

-- =========================================================================
-- EXPORTS
-- =========================================================================
exports('AdminAction', function(src, name, data)
    src = tonumber(src)
    local handler = Actions[name]
    if not src or not handler then
        Reply(src or 0, false, 'Action GoFast inconnue.')
        return false
    end
    Core = Core or GoFastCore
    CreateThread(function()
        local ok, success, message, extra = pcall(handler, src, type(data) == 'table' and data or {})
        if not ok then
            print(('^1[gofast] Erreur action admin \"%s\" : %s^0'):format(name, success))
            return Reply(src, false, 'Erreur interne GoFast (détails en console serveur).')
        end
        if success and extra and extra.log then
            Log('admin', 'Menu staff : ' .. extra.log, ('%s\n%s'):format(Security.PlayerLabel(src), extra.details or ''))
        end
        Reply(src, success == true, message, extra)
    end)
    return true
end)

local function Percent(value) return math.floor((value or 0) * 1000 + 0.5) / 10 end

exports('AdminGetData', function()
    Core = Core or GoFastCore
    local now = os.time()

    local settings = {}
    for _, field in ipairs(Store.SettingsSchema) do
        local node = Config
        for _, key in ipairs(field.path) do node = node and node[key] end
        local default = Store.GetDefaultSetting(field.key)
        settings[#settings + 1] = {
            key = field.key, label = field.label, type = field.type, group = field.group,
            min = field.type == 'percent' and Percent(field.min) or field.min,
            max = field.type == 'percent' and Percent(field.max) or field.max,
            value = field.type == 'percent' and Percent(node) or node,
            default = field.type == 'percent' and Percent(default) or default,
            changed = Store.data.settings[field.key] ~= nil,
        }
    end

    local tiers = {}
    for _, tier in ipairs(Config.Tiers) do
        local values = {}
        for _, field in ipairs(Store.TierSchema) do
            local value = Store.ReadTierField(tier, field.key)
            values[field.key] = field.type == 'percent' and Percent(value) or value
        end
        tiers[#tiers + 1] = { id = tier.id, risk = tier.risk, zones = tier.zones, values = values, changed = Store.data.tiers[tier.id] ~= nil }
    end
    local tierSchema = {}
    for _, field in ipairs(Store.TierSchema) do
        tierSchema[#tierSchema + 1] = {
            key = field.key, label = field.label, type = field.type, max = field.type == 'percent' and Percent(field.max) or field.max,
            min = field.type == 'percent' and Percent(field.min) or field.min,
        }
    end

    local destinations, zones, zoneSet = {}, {}, {}
    for index, destination in ipairs(Config.Destinations) do
        destinations[#destinations + 1] = {
            index = index, label = destination.label, zone = destination.zone,
            x = destination.coords.x, y = destination.coords.y, z = destination.coords.z,
        }
        if not zoneSet[destination.zone] then zoneSet[destination.zone] = true zones[#zones + 1] = destination.zone end
    end
    for _, tier in ipairs(Config.Tiers) do
        for _, zone in ipairs(tier.zones or {}) do
            if not zoneSet[zone] then zoneSet[zone] = true zones[#zones + 1] = zone end
        end
    end
    table.sort(zones)

    local contacts = {}
    for _, contact in ipairs(Store.data.contacts) do
        local copy = Store.DeepCopy(contact)
        copy.active = Contacts.IsActive(contact)
        contacts[#contacts + 1] = copy
    end

    local missions = {}
    for playerId, mission in pairs(Core and Core.ActiveMissions or {}) do
        missions[#missions + 1] = {
            target = playerId, id = mission.id, name = mission.playerName or GetPlayerName(playerId) or ('#' .. playerId),
            tier = mission.tierLabel or mission.tierId, contact = mission.giverLabel, rare = mission.rare,
            phase = mission.phase, step = mission.currentDrop, steps = #mission.drops, plate = mission.plate,
            endsAt = mission.phase == 'pickup' and mission.pickupDeadline or mission.deadline,
            police = mission.police and mission.police.sent or false,
        }
    end
    table.sort(missions, function(a, b) return a.target < b.target end)

    return {
        available = true,
        enabled = Store.data.enabled ~= false,
        now = now,
        settings = settings,
        tiers = tiers,
        tierSchema = tierSchema,
        contacts = contacts,
        destinations = destinations,
        destinationsCustom = Store.data.destinations ~= nil,
        zones = zones,
        missions = missions,
        dialogueCategories = Config.DialogueCategories,
        defaultDialogues = Config.DefaultDialogues,
        limits = {
            contacts = Config.Manage.MaxContacts, locations = Config.Manage.MaxLocations,
            vehicles = Config.Manage.MaxVehiclePoints, lines = Config.Manage.MaxDialogueLines,
            lineLength = Config.Manage.MaxDialogueLength,
        },
        defaults = { model = Config.Manage.NewContact.Model, scenario = Config.Manage.NewContact.Scenario },
        maxLevel = #Config.Levels.Thresholds,
    }
end)
