-- =====================================================================
--  elyzea_papiers - serveur
--  Carte d'identité (remise au premier passage en jeu) et PPA (délivré
--  par un EMS en service). Les papiers sont des objets d'inventaire :
--  leurs informations sont dans la metadata de l'objet.
-- =====================================================================
local core = exports.elyzea_core
local inv = exports.elyzea_inventory

local function Notify(src, msg, kind) core:Notify(src, msg, kind or 'inform') end
local function Coords(src) return GetEntityCoords(GetPlayerPed(src)) end
local function Log(src, action, details)
    if GetResourceState('admin_menu') ~= 'started' then return end
    pcall(function() exports.admin_menu:AddLog(src, '[Papiers] ' .. action, details) end)
end

local function Number(prefix)
    return ('%s-%06d'):format(prefix, math.random(0, 999999))
end

local function Holder(p)
    local ci = p.PlayerData.charinfo or {}
    return {
        firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate,
        gender = tonumber(ci.gender) or 0, nationality = ci.nationality or Config.IdCard.nationality,
        citizenid = p.PlayerData.citizenid,
    }
end

-- Donne un objet ; réessaie quelques secondes si l'inventaire n'est pas encore chargé
local function GiveItem(src, item, meta)
    for _ = 1, 15 do
        if not GetPlayerName(src) then return false end
        local ok, res, err = pcall(function() return inv:AddItem(src, item, 1, meta) end)
        if ok and res == true then return true end
        if ok and err ~= 'no_inventory' then return false, err end
        Wait(2000)
    end
    return false, 'no_inventory'
end

-- ---------------------------------------------------------------------
-- Carte d'identité
-- ---------------------------------------------------------------------
local function GiveIdCard(src)
    local p = core:GetPlayer(src)
    if not p then return false end
    local meta = Holder(p)
    meta.number = Number('ID')
    meta.issued = os.date('%d/%m/%Y')
    meta.label = "Carte d'identité"
    meta.description = ('%s %s · n° %s'):format(meta.firstname or '', meta.lastname or '', meta.number)
    local ok, err = GiveItem(src, Config.Items.id, meta)
    if not ok then
        print(('^1[elyzea_papiers] Carte d\'identité non donnée à %s (%s)^0'):format(GetPlayerName(src) or src, tostring(err)))
        return false
    end
    core:SetMetadata(src, 'idcard', meta.number)
    return true, meta.number
end
exports('GiveIdCard', GiveIdCard)

AddEventHandler('elyzea:server:playerLoaded', function(src)
    if not Config.IdCard.giveOnFirstSpawn then return end
    src = tonumber(src)
    CreateThread(function()
        Wait(3000)   -- laisse l'inventaire se charger
        local p = core:GetPlayer(src)
        if not p or p.PlayerData.metadata.idcard then return end
        if GiveIdCard(src) then Notify(src, 'Vous avez reçu votre carte d\'identité.', 'success') end
    end)
end)

-- Carte perdue : le staff en refait une
RegisterCommand(Config.IdCard.command, function(src, args)
    local target = tonumber(args[1]) or src
    local function reply(msg, kind) if src == 0 then print(msg) else Notify(src, msg, kind) end end
    if target == 0 or not core:GetPlayer(target) then return reply('Joueur introuvable.', 'error') end
    local ok, number = GiveIdCard(target)
    if not ok then return reply('Impossible de donner la carte (inventaire plein ?).', 'error') end
    Notify(target, 'Vous avez reçu une nouvelle carte d\'identité.', 'success')
    reply(('Carte d\'identité %s donnée à %d.'):format(number, target), 'success')
    Log(src, 'Carte d\'identité refaite', ('%s [%d] · %s'):format(GetPlayerName(target) or '?', target, number))
end, true)

-- ---------------------------------------------------------------------
-- PPA : délivré par un EMS en service, au patient à côté de lui
-- ---------------------------------------------------------------------
local function CanIssuePpa(src)
    local p = core:GetPlayer(src)
    local job = p and p.PlayerData.job
    if not job or job.name ~= Config.PPA.job then return false, 'Réservé au personnel médical.' end
    if (job.grade and job.grade.level or 0) < Config.PPA.minGrade then return false, 'Votre grade ne permet pas de délivrer un PPA.' end
    if Config.PPA.requireDuty and Player(src).state.emsDuty ~= true and job.onduty ~= true then
        return false, 'Vous devez être en service.'
    end
    return true
end

RegisterNetEvent('elyzea_papiers:issuePpa', function(target)
    local src = source
    local ok, why = CanIssuePpa(src)
    if not ok then return Notify(src, why, 'error') end
    target = tonumber(target)
    if not target or target == src or not core:GetPlayer(target) then return Notify(src, 'Patient introuvable.', 'error') end
    if #(Coords(src) - Coords(target)) > Config.ShowDistance + 2.0 then return Notify(src, 'Le patient est trop loin.', 'error') end

    local price = math.floor(tonumber(Config.PPA.price) or 0)
    if price > 0 then
        if not core:RemoveMoney(target, 'bank', price, 'ppa') then
            Notify(src, 'Le patient n\'a pas assez d\'argent en banque.', 'error')
            return Notify(target, ('Le PPA coûte %d $ : solde bancaire insuffisant.'):format(price), 'error')
        end
        core:AddSocietyMoney(Config.PPA.job, price, 'PPA')
    end

    local p = core:GetPlayer(target)
    local meta = Holder(p)
    meta.number = Number('PPA')
    meta.issued = os.date('%d/%m/%Y')
    meta.doctor = core:GetCharName(src)
    if (Config.PPA.validDays or 0) > 0 then
        meta.expiresAt = os.time() + Config.PPA.validDays * 86400
        meta.expires = os.date('%d/%m/%Y', meta.expiresAt)
    end
    meta.label = "Permis de port d'arme"
    meta.description = ('%s %s · n° %s%s'):format(meta.firstname or '', meta.lastname or '', meta.number,
        meta.expires and (' · valide jusqu\'au ' .. meta.expires) or '')

    local given, err = GiveItem(target, Config.Items.ppa, meta)
    if not given then
        if price > 0 then core:AddMoney(target, 'bank', price, 'ppa-remboursement') core:RemoveSocietyMoney(Config.PPA.job, price, 'PPA remboursé') end
        return Notify(src, ('Impossible de remettre le PPA (%s).'):format(err == 'no_inventory' and 'inventaire indisponible' or 'inventaire plein'), 'error')
    end

    -- Permis enregistré dans le personnage (tablette de la police)
    local lic = p.PlayerData.metadata.licences or {}
    lic[Config.PPA.licence] = true
    core:SetMetadata(target, 'licences', lic)

    Notify(src, ('PPA %s délivré.'):format(meta.number), 'success')
    Notify(target, 'Vous avez reçu votre permis de port d\'arme.', 'success')
    Log(src, 'PPA délivré', ('%s %s [%d] · %s'):format(meta.firstname or '', meta.lastname or '', target, meta.number))
end)

exports('CanIssuePpa', function(src) return (CanIssuePpa(src)) end)

-- ---------------------------------------------------------------------
-- Montrer un papier à la personne la plus proche
-- ---------------------------------------------------------------------
local Allowed = {}
for _, name in pairs(Config.Items) do Allowed[name] = true end

RegisterNetEvent('elyzea_papiers:show', function(slot)
    local src = source
    local item = inv:GetSlot(src, tonumber(slot) or 0)
    if not item or not Allowed[item.name] or type(item.metadata) ~= 'table' then return end
    local me, target, best = Coords(src), nil, nil
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src then
            local d = #(me - Coords(id))
            if d <= Config.ShowDistance and (not best or d < best) then target, best = id, d end
        end
    end
    if not target then return Notify(src, ('Personne à moins de %d m.'):format(math.floor(Config.ShowDistance)), 'error') end
    TriggerClientEvent('elyzea_papiers:card', target, item.name, item.metadata, src)
    Notify(src, 'Vous montrez vos papiers.', 'success')
end)
