-- =========================================================
--  PONT VERS LA BASE ELYZEA (elyzea_core + elyzea_inventory)
--  Bridge.AddItem(src, item, count)    -> true | false, raison
--  Bridge.RemoveItem(src, item, count) -> true | false
--  Bridge.GetItemCount(src, item)      -> nombre
--  Bridge.GetLabel(item)               -> nom affiché
--  Les noms d'armes sont insensibles à la casse (weapon_pistol = WEAPON_PISTOL).
-- =========================================================
Bridge = {}

local core = exports.elyzea_core
local function inv() return exports.elyzea_inventory end
local function invReady() return GetResourceState('elyzea_inventory') == 'started' end

-- ---------------------------------------------------------
function Bridge.Mode() return invReady() and 'elyzea' or 'none' end

function Bridge.GetItemCount(src, item)
    if not invReady() then return 0 end
    local ok, n = pcall(function() return inv():GetItemCount(src, item) end)
    return ok and (tonumber(n) or 0) or 0
end

function Bridge.RemoveItem(src, item, count)
    if not invReady() then return false end
    local ok, res = pcall(function() return inv():RemoveItem(src, item, count) end)
    return ok and res == true
end

local ERR = { too_heavy = 'full', no_space = 'full', unknown_item = 'unknown', no_inventory = 'noplayer' }

function Bridge.AddItem(src, item, count, metadata)
    if not invReady() then return false, 'noinv' end
    local ok, a, b = pcall(function()
        if not inv():Items(item) then return false, 'unknown_item' end
        return inv():AddItem(src, item, count, metadata)
    end)
    if not ok then
        print(('^1[AdminMenu] Erreur inventaire (%s) : %s^7'):format(item, tostring(a)))
        return false, 'noinv'
    end
    if a == true then return true end
    return false, ERR[b] or 'full'
end

-- ---------------------------------------------------------
--  Objets marqués (caisses de l'événement zombies)
--  L'inventaire garde une étiquette sur l'objet : on peut reprendre EXACTEMENT ces objets.
-- ---------------------------------------------------------
function Bridge.SupportsTags() return invReady() end

-- Retire tous les objets portant l'étiquette tag. Renvoie { [objet] = quantité retirée }
function Bridge.RemoveTagged(src, tag)
    local removed = {}
    if not invReady() then return removed end
    pcall(function()
        for _, it in pairs(inv():GetInventoryItems(src) or {}) do
            if type(it) == 'table' and it.metadata and it.metadata.am_event == tag then
                if inv():RemoveItem(src, it.name, it.count, nil, it.slot) then
                    removed[it.name] = (removed[it.name] or 0) + it.count
                end
            end
        end
    end)
    return removed
end

local labelCache = {}
function Bridge.GetLabel(item)
    if labelCache[item] then return labelCache[item] end
    local label = item
    if invReady() then
        local ok, it = pcall(function() return inv():Items(item) end)
        if ok and it and it.label then label = it.label end
    end
    labelCache[item] = label
    return label
end

Bridge.Errors = {
    full      = 'Inventaire plein.',
    unknown   = "Cet objet n'existe pas dans l'inventaire du serveur. Préviens le staff.",
    noplayer  = 'Personnage non chargé.',
    noinv     = "L'inventaire du serveur ne répond pas. Préviens le staff.",
    hasweapon = 'Tu possèdes déjà cette arme.',
}

-- =========================================================
--  ARGENT
--  kind : 'cash', 'bank' ou 'item' (item = nom de l'objet monnaie)
-- =========================================================
function Bridge.GetMoney(src, kind, item)
    if kind == 'item' then return Bridge.GetItemCount(src, item) end
    local ok, n = pcall(function() return core:GetMoney(src, kind) end)
    return ok and (tonumber(n) or 0) or 0
end

local function moneyOp(src, kind, item, amount, add, reason)
    if amount <= 0 then return true end
    if kind == 'item' then
        if add then return (Bridge.AddItem(src, item, amount)) end
        return Bridge.RemoveItem(src, item, amount)
    end
    local ok, res = pcall(function()
        if add then return core:AddMoney(src, kind, amount, reason) end
        return core:RemoveMoney(src, kind, amount, reason)
    end)
    return ok and res == true
end

function Bridge.AddMoney(src, kind, item, amount, reason) return moneyOp(src, kind, item, amount, true, reason) end
function Bridge.RemoveMoney(src, kind, item, amount, reason) return moneyOp(src, kind, item, amount, false, reason) end

-- Joueur policier en service ?
local policeSet
function Bridge.IsPolice(src)
    if not policeSet then
        policeSet = {}
        for _, j in ipairs(Config.PoliceJobs or {}) do policeSet[j] = true end
    end
    local ok, job = pcall(function() local pd = core:GetPlayerData(src) return pd and pd.job end)
    return ok and job ~= nil and policeSet[job.name] == true and job.onduty ~= false
end

-- =========================================================
--  LISTE DE TOUS LES OBJETS DE L'INVENTAIRE (armes comprises)
--  Mise en cache 60 s. image = lien direct vers l'icône de l'inventaire.
-- =========================================================
local itemsCache, itemsCacheTime = nil, -100000
function Bridge.GetAllItems(force)
    if not force and itemsCache and GetGameTimer() - itemsCacheTime < 60000 then return itemsCache end
    local list = {}
    local ok, err = pcall(function()
        for name, d in pairs(inv():Items() or {}) do
            if type(d) == 'table' then
                local kind = d.kind == 'weapon' and 'weapon' or d.kind == 'ammo' and 'ammo' or 'other'
                local img = d.image or (name .. '.png')
                list[#list + 1] = {
                    name = name, label = tostring(d.label or name), weight = tonumber(d.weight) or 0,
                    image = img:find('://') and img or ('nui://elyzea_inventory/html/img/' .. img), kind = kind,
                }
            end
        end
    end)
    if not ok then print(('^1[AdminMenu] Lecture de la liste des objets impossible : %s^7'):format(tostring(err))) end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    itemsCache, itemsCacheTime = list, GetGameTimer()
    print(('[AdminMenu] %d objets chargés depuis l\'inventaire Elyzea.'):format(#list))
    return list
end

function Bridge.ItemExists(name)
    for _, it in ipairs(Bridge.GetAllItems()) do
        if it.name == name or it.name:lower() == name:lower() then return true, it end
    end
    return false
end

-- =========================================================
--  PERSONNAGE (citizenid de la base Elyzea)
--  La propriété d'une porte suit le personnage, pas le compte.
-- =========================================================
function Bridge.GetCharId(src)
    local ok, id = pcall(function() return core:GetCitizenId(src) end)
    if ok and id then return tostring(id) end
    for _, i in ipairs(GetPlayerIdentifiers(src) or {}) do
        if i:sub(1, 8) == 'license:' then return i end
    end
end

function Bridge.GetCharName(src)
    local ok, name = pcall(function() return core:GetCharName(src) end)
    return (ok and name) or GetPlayerName(src) or ('#' .. src)
end

-- Tous les métiers déclarés sur le serveur, avec leurs grades (mis en cache 10 s).
-- Un métier créé plus tard (ex. par elyzea_ems) apparaît donc tout seul.
local jobsCache, jobsTime = nil, -100000
local function gradeList(grades)
    local out = {}
    for k, g in pairs(type(grades) == 'table' and grades or {}) do
        local lvl = tonumber(k) or tonumber(type(g) == 'table' and (g.grade or g.level))
        if lvl then
            local label = type(g) == 'table' and (g.label or g.name) or tostring(g)
            out[#out + 1] = { level = lvl, label = tostring(label or ('Grade ' .. lvl)),
                payment = type(g) == 'table' and tonumber(g.payment or g.salary) or nil, isboss = type(g) == 'table' and g.isboss == true or nil }
        end
    end
    table.sort(out, function(a, b) return a.level < b.level end)
    return out
end
function Bridge.GetJobs()
    if jobsCache and GetGameTimer() - jobsTime < 10000 then return jobsCache end
    local ok, raw = pcall(function() return core:GetJobs() end)
    local list = {}
    if ok and type(raw) == 'table' then
        for name, j in pairs(raw) do
            if type(j) == 'table' then
                list[#list + 1] = { name = tostring(j.name or name), label = tostring(j.label or name), grades = gradeList(j.grades),
                    type = j.type, defaultDuty = j.defaultDuty, offDutyPay = j.offDutyPay }
            end
        end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    jobsCache, jobsTime = list, GetGameTimer()
    return list
end
AddEventHandler('elyzea:server:jobsUpdated', function() jobsCache = nil end)

-- Groupes déclarés dans la base (gangs), avec leurs grades.
local gangsCache, gangsTime = nil, -100000
function Bridge.GetGangs()
    if gangsCache and GetGameTimer() - gangsTime < 10000 then return gangsCache end
    local ok, raw = pcall(function() return core:GetGangs() end)
    local list = {}
    if ok and type(raw) == 'table' then
        for name, g in pairs(raw) do
            if type(g) == 'table' and name ~= 'none' then
                list[#list + 1] = { name = tostring(g.name or name), label = tostring(g.label or name), grades = gradeList(g.grades) }
            end
        end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    gangsCache, gangsTime = list, GetGameTimer()
    return list
end

-- Gang du joueur : nom et grade. nil si aucun.
function Bridge.GetGang(src)
    local ok, g = pcall(function() local pd = core:GetPlayerData(src) return pd and pd.gang end)
    if not ok or not g or g.name == 'none' then return nil end
    return g.name, (type(g.grade) == 'table' and (g.grade.level or 0)) or tonumber(g.grade) or 0
end

-- Métier du joueur : nom, grade (niveau) et en service. nil si inconnu.
function Bridge.GetJob(src)
    local ok, j = pcall(function() local pd = core:GetPlayerData(src) return pd and pd.job end)
    if not ok or not j then return nil end
    return j.name, (type(j.grade) == 'table' and (j.grade.level or 0)) or tonumber(j.grade) or 0, j.onduty ~= false
end

-- Change le métier principal du joueur. Renvoie true si réussi.
function Bridge.SetJob(src, job, grade)
    local ok, res = pcall(function() return core:SetJob(src, job, grade) end)
    return ok and res == true
end

-- Retire le métier du personnage (il repasse sans emploi s'il l'avait).
function Bridge.RemoveFromJob(src, job)
    local cid = Bridge.GetCharId(src)
    if cid then pcall(function() core:RemovePlayerFromJob(cid, job) end) end
end

-- =========================================================
--  BESOINS (faim, soif, stress) : lecture / écriture
-- =========================================================
function Bridge.GetNeeds(src)
    local ok, md = pcall(function() local pd = core:GetPlayerData(src) return pd and pd.metadata end)
    if not ok or not md then return nil end
    return { hunger = tonumber(md.hunger), thirst = tonumber(md.thirst), stress = tonumber(md.stress) }
end

function Bridge.SetNeeds(src, values)
    pcall(function()
        for key, value in pairs(values) do core:SetMetadata(src, key, value) end
        local pd = core:GetPlayerData(src)
        local md = pd and pd.metadata or {}
        TriggerClientEvent('hud:client:UpdateNeeds', src, md.hunger or values.hunger, md.thirst or values.thirst)
        if values.stress then TriggerClientEvent('hud:client:UpdateStress', src, values.stress) end
    end)
end
