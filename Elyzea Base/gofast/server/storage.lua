--[[
    GO FAST - Stockage persistant et réglages modifiables en jeu
    * Tout ce qui est réglé depuis le menu staff est enregistré dans data/gofast.json
      (contacts, réglages, paliers, destinations) et réappliqué à chaque démarrage.
    * Les valeurs de config.lua servent de valeurs par défaut (bouton « Valeurs par défaut »).
    * Écritures regroupées : plusieurs modifications rapprochées = une seule écriture disque.
]]

local U = GoFast.Utils
local RESOURCE = GetCurrentResourceName()

Store = { data = nil }

local function DeepCopy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = DeepCopy(inner) end
    return copy
end
Store.DeepCopy = DeepCopy

local function Round(value, decimals)
    local factor = 10 ^ (decimals or 2)
    return math.floor(value * factor + 0.5) / factor
end
Store.Round = Round

-- =========================================================================
-- RÉGLAGES GÉNÉRAUX MODIFIABLES
-- type : 'int' | 'number' | 'bool' | 'percent' (stocké en fraction, affiché en %)
-- =========================================================================
Store.SettingsSchema = {
    { key = 'maxActive',       label = 'Go Fast simultanés (max)',          path = { 'Mission', 'MaxActive' },        type = 'int',     min = 1,  max = 64,    group = 'Missions' },
    { key = 'pickupTimeout',   label = 'Temps pour récupérer le véhicule (s)', path = { 'Mission', 'PickupTimeout' }, type = 'int',     min = 60, max = 1800,  group = 'Missions' },
    { key = 'awayDistance',    label = 'Distance max loin du véhicule (m)', path = { 'Mission', 'AwayDistance' },     type = 'number',  min = 50, max = 1500,  group = 'Missions' },
    { key = 'awayTimeout',     label = 'Temps toléré loin du véhicule (s)', path = { 'Mission', 'AwayTimeout' },      type = 'int',     min = 10, max = 600,   group = 'Missions' },
    { key = 'checkpoints',     label = 'Points de passage facultatifs',     path = { 'Checkpoints', 'Enabled' },      type = 'bool',                         group = 'Missions' },
    { key = 'cdSuccess',       label = 'Attente après une réussite (s)',    path = { 'Cooldown', 'Success' },         type = 'int',     min = 0,  max = 86400, group = 'Attentes' },
    { key = 'cdFail',          label = 'Attente après un échec (s)',        path = { 'Cooldown', 'Fail' },            type = 'int',     min = 0,  max = 86400, group = 'Attentes' },
    { key = 'cdAbandon',       label = 'Attente après un abandon (s)',      path = { 'Cooldown', 'Abandon' },         type = 'int',     min = 0,  max = 86400, group = 'Attentes' },
    { key = 'cdDisconnect',    label = 'Attente après une déconnexion (s)', path = { 'Cooldown', 'Disconnect' },      type = 'int',     min = 0,  max = 86400, group = 'Attentes' },
    { key = 'cdGlobal',        label = 'Délai entre 2 lancements, serveur (s)', path = { 'Cooldown', 'Global' },      type = 'int',     min = 0,  max = 3600,  group = 'Attentes' },
    { key = 'police',          label = 'Alertes police',                    path = { 'Police', 'Enabled' },           type = 'bool',                         group = 'Police et risques' },
    { key = 'blockPolice',     label = 'Interdire aux policiers en service', path = { 'Police', 'BlockPoliceFromMissions' }, type = 'bool',                   group = 'Police et risques' },
    { key = 'events',          label = 'Événements aléatoires (rivaux, balise…)', path = { 'RandomEvents', 'Enabled' }, type = 'bool',                       group = 'Police et risques' },
    { key = 'xp',              label = 'Niveaux et XP',                     path = { 'XP', 'Enabled' },               type = 'bool',                         group = 'Récompenses' },
    { key = 'levelBonus',      label = 'Bonus par niveau (%)',              path = { 'Rewards', 'LevelBonusPerLevel' }, type = 'percent', min = 0, max = 0.5, group = 'Récompenses' },
    { key = 'fastBonus',       label = 'Bonus rapidité (%)',                path = { 'Rewards', 'FastBonus', 'Percent' }, type = 'percent', min = 0, max = 2, group = 'Récompenses' },
    { key = 'damagePenalty',   label = 'Pénalité max de dégâts (%)',        path = { 'Rewards', 'DamagePenalty', 'MaxPercent' }, type = 'percent', min = 0, max = 1, group = 'Récompenses' },
    { key = 'checkpointBonus', label = 'Bonus par point de passage (%)',    path = { 'Rewards', 'CheckpointBonus' },  type = 'percent', min = 0, max = 0.5,  group = 'Récompenses' },
}

-- =========================================================================
-- CHAMPS DES PALIERS MODIFIABLES
-- =========================================================================
Store.TierSchema = {
    { key = 'enabled',      label = 'Proposé aux joueurs',          type = 'bool' },
    { key = 'label',        label = 'Nom',                           type = 'string', max = 40 },
    { key = 'description',  label = 'Description',                   type = 'string', max = 160 },
    { key = 'minLevel',     label = 'Niveau requis',                 type = 'int',     min = 1, max = 99 },
    { key = 'rewardMin',    label = 'Paie de base min',              type = 'int',     min = 0, max = 10000000 },
    { key = 'rewardMax',    label = 'Paie de base max',              type = 'int',     min = 0, max = 10000000 },
    { key = 'perKm',        label = 'Paie en plus par km',           type = 'int',     min = 0, max = 1000000 },
    { key = 'xp',           label = 'XP gagnée',                     type = 'int',     min = 0, max = 100000 },
    { key = 'dropsMin',     label = 'Livraisons min',                type = 'int',     min = 1, max = 8 },
    { key = 'dropsMax',     label = 'Livraisons max',                type = 'int',     min = 1, max = 8 },
    { key = 'timeBase',     label = 'Temps de base (s)',             type = 'int',     min = 30, max = 7200 },
    { key = 'timePerKm',    label = 'Temps en plus par km (s)',      type = 'int',     min = 5, max = 600 },
    { key = 'checkpoints',  label = 'Points de passage',             type = 'int',     min = 0, max = 10 },
    { key = 'policeChance', label = 'Risque d\'alerte police (%)',   type = 'percent', min = 0, max = 1 },
    { key = 'minCops',      label = 'Policiers requis',              type = 'int',     min = 0, max = 30 },
    { key = 'eventChance',  label = 'Chance d\'événement (%)',       type = 'percent', min = 0, max = 1 },
    { key = 'rareChance',   label = 'Chance de contrat rare (%)',    type = 'percent', min = 0, max = 1 },
}

local function ReadTierField(tier, key)
    if key == 'enabled' then return tier.enabled ~= false end
    if key == 'label' then return tier.label end
    if key == 'description' then return tier.description or '' end
    if key == 'minLevel' then return tier.minLevel end
    if key == 'rewardMin' then return tier.reward.min end
    if key == 'rewardMax' then return tier.reward.max end
    if key == 'perKm' then return tier.reward.perKm or 0 end
    if key == 'xp' then return tier.xp end
    if key == 'dropsMin' then return tier.drops[1] end
    if key == 'dropsMax' then return tier.drops[2] or tier.drops[1] end
    if key == 'timeBase' then return tier.time.base end
    if key == 'timePerKm' then return tier.time.perKm end
    if key == 'checkpoints' then return tier.checkpoints or 0 end
    if key == 'policeChance' then return tier.police.chance or 0 end
    if key == 'minCops' then return tier.police.minCops or 0 end
    if key == 'eventChance' then return tier.events and tier.events.chance or 0 end
    if key == 'rareChance' then return tier.rareChance or 0 end
end
Store.ReadTierField = ReadTierField

local function WriteTierField(tier, key, value)
    if key == 'enabled' then tier.enabled = value
    elseif key == 'label' then tier.label = value
    elseif key == 'description' then tier.description = value
    elseif key == 'minLevel' then tier.minLevel = value
    elseif key == 'rewardMin' then tier.reward.min = value
    elseif key == 'rewardMax' then tier.reward.max = value
    elseif key == 'perKm' then tier.reward.perKm = value
    elseif key == 'xp' then tier.xp = value
    elseif key == 'dropsMin' then tier.drops[1] = value
    elseif key == 'dropsMax' then tier.drops[2] = value
    elseif key == 'timeBase' then tier.time.base = value
    elseif key == 'timePerKm' then tier.time.perKm = value
    elseif key == 'checkpoints' then tier.checkpoints = value
    elseif key == 'policeChance' then tier.police.chance = value
    elseif key == 'minCops' then tier.police.minCops = value
    elseif key == 'eventChance' then
        tier.events = tier.events or { chance = 0, max = 1, pool = {}, window = { 60, 180 } }
        tier.events.chance = value
    elseif key == 'rareChance' then tier.rareChance = value
    end
end

--- Normalise une valeur selon son schéma. Renvoie nil si invalide.
function Store.CleanValue(field, value)
    if field.type == 'bool' then
        if value == true or value == 'true' or value == 1 then return true end
        if value == false or value == 'false' or value == 0 then return false end
        return nil
    end
    if field.type == 'string' then
        if type(value) ~= 'string' then return nil end
        local text = value:gsub('[%c<>]', ''):sub(1, field.max or 60)
        text = text:match('^%s*(.-)%s*$')
        if text == '' and field.key == 'label' then return nil end
        return text
    end
    local number = tonumber(value)
    if not number or number ~= number then return nil end
    if field.type == 'percent' then number = number / 100.0 end
    number = U.Clamp(number, field.min or -math.huge, field.max or math.huge)
    if field.type == 'int' then return math.floor(number + 0.5) end
    return Round(number, 4)
end

-- =========================================================================
-- VALEURS PAR DÉFAUT (photo de config.lua avant toute modification)
-- =========================================================================
local Defaults = { settings = {}, tiers = {}, destinations = {} }

local function ReadPath(path)
    local node = Config
    for index = 1, #path do
        if type(node) ~= 'table' then return nil end
        node = node[path[index]]
    end
    return node
end

local function WritePath(path, value)
    local node = Config
    for index = 1, #path - 1 do
        node[path[index]] = node[path[index]] or {}
        node = node[path[index]]
    end
    node[path[#path]] = value
end

for _, field in ipairs(Store.SettingsSchema) do Defaults.settings[field.key] = ReadPath(field.path) end
for _, tier in ipairs(Config.Tiers) do
    local snapshot = {}
    for _, field in ipairs(Store.TierSchema) do snapshot[field.key] = ReadTierField(tier, field.key) end
    Defaults.tiers[tier.id] = snapshot
end
for _, destination in ipairs(Config.Destinations) do
    Defaults.destinations[#Defaults.destinations + 1] = {
        label = destination.label, zone = destination.zone,
        x = destination.coords.x, y = destination.coords.y, z = destination.coords.z,
    }
end

function Store.GetDefaultSetting(key) return Defaults.settings[key] end
function Store.GetDefaultTier(tierId) return Defaults.tiers[tierId] end

-- =========================================================================
-- APPLICATION DES SURCHARGES SUR CONFIG
-- =========================================================================
function Store.ApplySettings()
    for _, field in ipairs(Store.SettingsSchema) do
        local value = Store.data.settings[field.key]
        if value == nil then value = Defaults.settings[field.key] end
        WritePath(field.path, value)
    end
end

function Store.ApplyTiers()
    for _, tier in ipairs(Config.Tiers) do
        local overrides = Store.data.tiers[tier.id] or {}
        for _, field in ipairs(Store.TierSchema) do
            local value = overrides[field.key]
            if value == nil then value = Defaults.tiers[tier.id][field.key] end
            WriteTierField(tier, field.key, value)
        end
        -- Cohérence : min <= max
        if tier.reward.max < tier.reward.min then tier.reward.max = tier.reward.min end
        if (tier.drops[2] or tier.drops[1]) < tier.drops[1] then tier.drops[2] = tier.drops[1] end
    end
end

function Store.ApplyDestinations()
    local source = Store.data.destinations or Defaults.destinations
    local list = {}
    for _, destination in ipairs(source) do
        list[#list + 1] = {
            label = destination.label,
            zone = destination.zone,
            coords = vector3(destination.x + 0.0, destination.y + 0.0, destination.z + 0.0),
        }
    end
    Config.Destinations = list
end

--- Liste de destinations modifiable (copie la liste par défaut à la première modification)
function Store.EditableDestinations()
    if not Store.data.destinations then Store.data.destinations = DeepCopy(Defaults.destinations) end
    return Store.data.destinations
end

function Store.ResetDestinations()
    Store.data.destinations = nil
    Store.ApplyDestinations()
    Store.Save()
end

-- =========================================================================
-- LECTURE / ÉCRITURE
-- =========================================================================
local function EmptyData()
    return { version = 1, enabled = true, seeded = false, sequence = 0, contacts = {}, settings = {}, tiers = {}, destinations = nil }
end

function Store.Load()
    local raw = LoadResourceFile(RESOURCE, Config.Manage.DataFile)
    local data
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            data = decoded
        else
            print(('^1[gofast] %s illisible : une copie est gardée en .bak et les valeurs par défaut sont utilisées.^0'):format(Config.Manage.DataFile))
            SaveResourceFile(RESOURCE, Config.Manage.DataFile .. '.bak', raw, -1)
        end
    end

    local base = EmptyData()
    data = data or base
    for key, value in pairs(base) do
        if data[key] == nil then data[key] = value end
    end
    if type(data.contacts) ~= 'table' then data.contacts = {} end
    if type(data.settings) ~= 'table' then data.settings = {} end
    if type(data.tiers) ~= 'table' then data.tiers = {} end
    if data.destinations ~= nil and type(data.destinations) ~= 'table' then data.destinations = nil end
    Store.data = data

    Store.ApplySettings()
    Store.ApplyTiers()
    Store.ApplyDestinations()
end

local function WriteNow()
    local ok, encoded = pcall(json.encode, Store.data, { indent = true })
    if not ok then
        print('^1[gofast] Impossible d\'encoder les données : ' .. tostring(encoded) .. '^0')
        return
    end
    if not SaveResourceFile(RESOURCE, Config.Manage.DataFile, encoded, -1) then
        print(('^1[gofast] Écriture impossible de %s : le dossier data/ existe-t-il ?^0'):format(Config.Manage.DataFile))
    end
end

local savePending = false
function Store.Save()
    if savePending then return end
    savePending = true
    SetTimeout(1500, function()
        savePending = false
        WriteNow()
    end)
end

function Store.Flush()
    if Store.data then WriteNow() end
    savePending = false
end

function Store.NextId(prefix)
    Store.data.sequence = (Store.data.sequence or 0) + 1
    return ('%s%d'):format(prefix, Store.data.sequence)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == RESOURCE and savePending then Store.Flush() end
end)

Store.Load()
