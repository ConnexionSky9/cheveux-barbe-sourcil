--[[
    GO FAST - Contacts dynamiques (PNJ donneurs de missions)
    * Créés et modifiés depuis le menu staff, sauvegardés par Store.
    * Chaque contact a plusieurs emplacements ; chaque emplacement a ses propres points
      d'apparition du véhicule.
    * Rotation : fixe, dans l'ordre ou au hasard, toutes les X à Y minutes, avec option
      « attendre qu'aucun joueur ne soit à proximité » (le PNJ ne disparaît pas sous les yeux d'un joueur).
    * Les clients ne reçoivent que l'emplacement actuel de chaque contact (pas les autres).
]]

local U = GoFast.Utils

Contacts = {}

local ROTATION_MODES = { fixed = true, sequential = true, random = true }

-- =========================================================================
-- OUTILS
-- =========================================================================
local function Now() return os.time() end

local function FindIndex(id)
    for index, contact in ipairs(Store.data.contacts) do
        if contact.id == id then return index, contact end
    end
    return nil, nil
end

function Contacts.Get(id)
    if type(id) ~= 'string' then return nil end
    local _, contact = FindIndex(id)
    return contact
end

function Contacts.All()
    return Store.data.contacts
end

local function CurrentLocation(contact)
    local locations = contact.locations or {}
    if #locations == 0 then return nil, nil end
    local index = U.Clamp(math.floor(tonumber(contact.current) or 1), 1, #locations)
    contact.current = index
    return locations[index], index
end
Contacts.CurrentLocation = CurrentLocation

local function RandomInterval(contact)
    local rotation = contact.rotation
    local low = math.max(1, tonumber(rotation.intervalMin) or 30)
    local high = math.max(low, tonumber(rotation.intervalMax) or low)
    return math.floor((low + math.random() * (high - low)) * 60)
end

local function IsActive(contact)
    return Store.data.enabled ~= false and contact.enabled ~= false and CurrentLocation(contact) ~= nil
end
Contacts.IsActive = IsActive

-- =========================================================================
-- VUE « DONNEUR DE MISSION » UTILISÉE PAR server/main.lua
-- =========================================================================
function Contacts.GetGiver(id)
    local contact = Contacts.Get(id)
    if not contact or not IsActive(contact) then return nil end
    local location, index = CurrentLocation(contact)

    local spawnPoints = {}
    for _, point in ipairs(location.vehicles or {}) do
        spawnPoints[#spawnPoints + 1] = vector4(point.x + 0.0, point.y + 0.0, point.z + 0.0, (point.h or 0.0) + 0.0)
    end

    return {
        id = contact.id,
        label = contact.label,
        subtitle = (contact.subtitle ~= '' and contact.subtitle) or location.label or '',
        coords = vector4(location.x + 0.0, location.y + 0.0, location.z + 0.0, (location.h or 0.0) + 0.0),
        spawnPoints = spawnPoints,
        spawnPrefix = ('%s:%d'):format(contact.id, index),
        tiers = contact.tiers or {},
    }
end

-- =========================================================================
-- DIALOGUES
-- =========================================================================
function Contacts.Line(contactId, category, vars)
    local contact = Contacts.Get(contactId)
    local lines = contact and contact.dialogues and contact.dialogues[category]
    if type(lines) ~= 'table' or #lines == 0 then lines = Config.DefaultDialogues[category] end
    if type(lines) ~= 'table' or #lines == 0 then return nil end
    vars = vars or {}
    vars.contact = vars.contact or (contact and contact.label) or 'Contact'
    return U.Template(lines[math.random(#lines)], vars)
end

-- =========================================================================
-- SYNCHRONISATION CLIENTS (regroupée)
-- =========================================================================
local function PublicList()
    local list = {}
    if Store.data.enabled == false then return list end
    for _, contact in ipairs(Store.data.contacts) do
        if IsActive(contact) then
            local location = CurrentLocation(contact)
            list[#list + 1] = {
                id = contact.id,
                label = contact.label,
                model = contact.model,
                scenario = contact.scenario or '',
                x = location.x, y = location.y, z = location.z, h = location.h or 0.0,
                blip = contact.blip ~= false,
                blipSprite = contact.blipSprite or Config.Manage.NewContact.BlipSprite,
                blipColor = contact.blipColor or Config.Manage.NewContact.BlipColor,
                marker = contact.marker ~= false,
            }
        end
    end
    return list
end

local syncPending = false
function Contacts.Broadcast()
    if syncPending then return end
    syncPending = true
    SetTimeout(200, function()
        syncPending = false
        TriggerClientEvent('gofast:client:contacts', -1, PublicList())
    end)
end

RegisterNetEvent('gofast:server:requestContacts', function()
    local src = source
    if not Security.RateLimit(src, 'contacts', 3000) then return end
    TriggerLatentClientEvent('gofast:client:contacts', src, 50000, PublicList())
end)

function Contacts.Changed()
    Store.Save()
    Contacts.Broadcast()
end

-- =========================================================================
-- DÉPLACEMENT
-- =========================================================================
function Contacts.MoveTo(contact, index)
    local count = #(contact.locations or {})
    if count == 0 then return false end
    contact.current = U.Clamp(math.floor(index), 1, count)
    contact.nextMoveAt = Now() + RandomInterval(contact)
    Contacts.Changed()
    U.Debug(('Contact %s déplacé vers l\'emplacement %d'):format(contact.id, contact.current))
    return true
end

function Contacts.NextIndex(contact)
    local count = #(contact.locations or {})
    if count <= 1 then return 1 end
    local current = contact.current or 1
    if contact.rotation.mode == 'random' then
        local pick = math.random(count - 1)
        if pick >= current then pick = pick + 1 end
        return pick
    end
    return (current % count) + 1
end

local function PlayersNear(coords, radius)
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped ~= 0 and #(GetEntityCoords(ped) - coords) < radius then return true end
    end
    return false
end

CreateThread(function()
    while true do
        Wait(15000)
        if Store.data.enabled ~= false then
            local now = Now()
            for _, contact in ipairs(Store.data.contacts) do
                local rotation = contact.rotation
                if contact.enabled ~= false and rotation and rotation.mode ~= 'fixed' and #(contact.locations or {}) > 1 then
                    if not contact.nextMoveAt then
                        contact.nextMoveAt = now + RandomInterval(contact)
                        Store.Save()
                    elseif now >= contact.nextMoveAt then
                        local location = CurrentLocation(contact)
                        local here = vector3(location.x + 0.0, location.y + 0.0, location.z + 0.0)
                        if rotation.onlyWhenAlone and PlayersNear(here, Config.Manage.MoveCheckRadius) then
                            contact.nextMoveAt = now + Config.Manage.MoveRetryDelay
                        else
                            Contacts.MoveTo(contact, Contacts.NextIndex(contact))
                        end
                    end
                end
            end
        end
    end
end)

-- =========================================================================
-- NORMALISATION (utilisée à la création, à la modification et au chargement)
-- =========================================================================
local function CleanText(value, maxLength)
    if type(value) ~= 'string' then return nil end
    local text = value:gsub('[%c<>]', ''):sub(1, maxLength)
    return text:match('^%s*(.-)%s*$')
end
Contacts.CleanText = CleanText

local function CleanModel(value)
    if type(value) ~= 'string' then return nil end
    local model = value:gsub('[^%w_]', ''):sub(1, 60)
    if model == '' then return nil end
    return model
end
Contacts.CleanModel = CleanModel

local function CleanScenario(value)
    if type(value) ~= 'string' then return '' end
    return value:gsub('[^%w_]', ''):sub(1, 60)
end

local function CleanTiers(list)
    local result, seen = {}, {}
    if type(list) ~= 'table' then return result end
    for _, tierId in ipairs(list) do
        if type(tierId) == 'string' and not seen[tierId] and U.GetTier(tierId) then
            seen[tierId] = true
            result[#result + 1] = tierId
        end
    end
    return result
end

local function CleanDialogues(source)
    local result = {}
    if type(source) ~= 'table' then source = {} end
    for _, category in ipairs(Config.DialogueCategories) do
        local lines = {}
        if type(source[category.id]) == 'table' then
            for _, line in ipairs(source[category.id]) do
                local text = CleanText(line, Config.Manage.MaxDialogueLength)
                if text and text ~= '' and #lines < Config.Manage.MaxDialogueLines then lines[#lines + 1] = text end
            end
        end
        result[category.id] = lines
    end
    return result
end

local function CleanRotation(source, previous)
    source = type(source) == 'table' and source or {}
    previous = previous or { mode = 'fixed', intervalMin = 30, intervalMax = 30, onlyWhenAlone = true }
    local mode = ROTATION_MODES[source.mode] and source.mode or previous.mode
    local low = math.floor(U.Clamp(tonumber(source.intervalMin) or previous.intervalMin, 1, 1440))
    local high = math.floor(U.Clamp(tonumber(source.intervalMax) or previous.intervalMax, low, 1440))
    local alone = previous.onlyWhenAlone
    if source.onlyWhenAlone ~= nil then alone = source.onlyWhenAlone == true or source.onlyWhenAlone == 'true' end
    return { mode = mode, intervalMin = low, intervalMax = high, onlyWhenAlone = alone }
end

local function CleanPoint(point)
    if type(point) ~= 'table' then return nil end
    local x, y, z = tonumber(point.x), tonumber(point.y), tonumber(point.z)
    if not x or not y or not z then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or z < -500 or z > 3000 then return nil end
    return { x = Store.Round(x, 3), y = Store.Round(y, 3), z = Store.Round(z, 3), h = Store.Round((tonumber(point.h) or 0.0) % 360, 2) }
end
Contacts.CleanPoint = CleanPoint

local function CleanLocation(location)
    local point = CleanPoint(location)
    if not point then return nil end
    point.label = CleanText(location.label, 40) or ''
    point.vehicles = {}
    for _, vehiclePoint in ipairs(type(location.vehicles) == 'table' and location.vehicles or {}) do
        local cleaned = CleanPoint(vehiclePoint)
        if cleaned and #point.vehicles < Config.Manage.MaxVehiclePoints then point.vehicles[#point.vehicles + 1] = cleaned end
    end
    return point
end
Contacts.CleanLocation = CleanLocation

--- Applique les champs modifiables envoyés par le menu. Renvoie false + message si invalide.
function Contacts.ApplyFields(contact, fields)
    if fields.label ~= nil then
        local label = CleanText(fields.label, 40)
        if not label or label == '' then return false, 'Donne un nom au contact.' end
        contact.label = label
    end
    if fields.subtitle ~= nil then contact.subtitle = CleanText(fields.subtitle, 60) or '' end
    if fields.model ~= nil then
        local model = CleanModel(fields.model)
        if not model then return false, 'Modèle de PNJ invalide.' end
        contact.model = model
    end
    if fields.scenario ~= nil then contact.scenario = CleanScenario(fields.scenario) end
    if fields.tiers ~= nil then contact.tiers = CleanTiers(fields.tiers) end
    if fields.enabled ~= nil then contact.enabled = fields.enabled == true or fields.enabled == 'true' end
    if fields.blip ~= nil then contact.blip = fields.blip == true or fields.blip == 'true' end
    if fields.marker ~= nil then contact.marker = fields.marker == true or fields.marker == 'true' end
    if fields.blipSprite ~= nil then contact.blipSprite = math.floor(U.Clamp(tonumber(fields.blipSprite) or 500, 1, 900)) end
    if fields.blipColor ~= nil then contact.blipColor = math.floor(U.Clamp(tonumber(fields.blipColor) or 47, 0, 85)) end
    if fields.rotation ~= nil then
        local before = contact.rotation and contact.rotation.mode
        contact.rotation = CleanRotation(fields.rotation, contact.rotation)
        if before ~= contact.rotation.mode or not contact.nextMoveAt then contact.nextMoveAt = Now() + RandomInterval(contact) end
    end
    if fields.dialogues ~= nil then contact.dialogues = CleanDialogues(fields.dialogues) end
    return true
end

function Contacts.New(fields)
    if #Store.data.contacts >= Config.Manage.MaxContacts then
        return nil, ('Limite de %d contacts atteinte.'):format(Config.Manage.MaxContacts)
    end
    local defaults = Config.Manage.NewContact
    local tiers = {}
    for _, tier in ipairs(Config.Tiers) do tiers[#tiers + 1] = tier.id end

    local contact = {
        id = Store.NextId('c'),
        label = 'Contact',
        subtitle = '',
        model = defaults.Model,
        scenario = defaults.Scenario,
        enabled = true,
        blip = true,
        marker = true,
        blipSprite = defaults.BlipSprite,
        blipColor = defaults.BlipColor,
        tiers = tiers,
        locations = {},
        current = 1,
        rotation = CleanRotation(nil),
        dialogues = CleanDialogues(nil),
        nextMoveAt = nil,
    }
    local ok, message = Contacts.ApplyFields(contact, fields or {})
    if not ok then return nil, message end
    Store.data.contacts[#Store.data.contacts + 1] = contact
    return contact
end

function Contacts.Remove(id)
    local index = FindIndex(id)
    if not index then return false end
    table.remove(Store.data.contacts, index)
    return true
end

-- =========================================================================
-- CHARGEMENT : nettoyage des données + création des exemples si demandé
-- =========================================================================
local function SanitizeLoaded()
    local cleaned = {}
    for _, contact in ipairs(Store.data.contacts) do
        if type(contact) == 'table' and type(contact.id) == 'string' then
            contact.label = CleanText(contact.label, 40) or 'Contact'
            contact.subtitle = CleanText(contact.subtitle, 60) or ''
            contact.model = CleanModel(contact.model) or Config.Manage.NewContact.Model
            contact.scenario = CleanScenario(contact.scenario)
            contact.tiers = CleanTiers(contact.tiers)
            contact.rotation = CleanRotation(contact.rotation)
            contact.dialogues = CleanDialogues(contact.dialogues)
            local locations = {}
            for _, location in ipairs(type(contact.locations) == 'table' and contact.locations or {}) do
                local cleanedLocation = CleanLocation(location)
                if cleanedLocation then locations[#locations + 1] = cleanedLocation end
            end
            contact.locations = locations
            contact.current = U.Clamp(math.floor(tonumber(contact.current) or 1), 1, math.max(1, #locations))
            contact.nextMoveAt = tonumber(contact.nextMoveAt)
            cleaned[#cleaned + 1] = contact
        end
    end
    Store.data.contacts = cleaned
end

local function SeedExamples()
    if Store.data.seeded then return end
    Store.data.seeded = true
    if Config.Manage.SeedDefaultContacts and #Store.data.contacts == 0 then
        for _, giver in ipairs(Config.MissionGivers or {}) do
            local contact = Contacts.New({
                label = giver.label, subtitle = giver.subtitle,
                model = giver.ped and giver.ped.model, scenario = giver.ped and giver.ped.scenario,
                tiers = giver.tiers,
            })
            if contact then
                local vehicles = {}
                for _, point in ipairs(giver.spawnPoints or {}) do
                    vehicles[#vehicles + 1] = { x = point.x, y = point.y, z = point.z, h = point.w }
                end
                -- Les exemples sont au sol : +1 m pour la position du PNJ (centre du corps)
                contact.locations[1] = CleanLocation({
                    label = giver.subtitle or giver.label,
                    x = giver.coords.x, y = giver.coords.y, z = giver.coords.z + 1.0, h = giver.coords.w,
                    vehicles = vehicles,
                })
            end
        end
        print(('^2[gofast] %d contact(s) d\'exemple créé(s).^0'):format(#Store.data.contacts))
    end
    Store.Save()
end

SanitizeLoaded()
SeedExamples()
