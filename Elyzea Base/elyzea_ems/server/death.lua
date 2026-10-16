-- =====================================================================
--  ELYZEA EMS - serveur : coma (tous les joueurs)
--  · À la mort, le client relève le joueur sur place en position « à terre »
--    (state bag emsDown = true, posé ici par le serveur) et l'annonce au serveur.
--  · Le serveur garde l'heure de mise à terre et le délai avant réapparition :
--    le client ne peut pas réapparaître plus tôt.
--  · Métadonnée isdead conservée : déconnexion à terre = toujours à terre.
--  · Réapparition : frais d'hôpital (banque puis liquide), puis réveil au point
--    Config.Death.hospital. Si des lits sont réglés dans admin_menu › Réapparition,
--    admin_menu détecte la réapparition et place le joueur sur un lit (déjà en place).
--  · Compatibilité : admin_menu (réanimation staff) met emsDown = false et
--    déclenche « elyzea_ems:revived » : le coma est alors terminé ici aussi.
-- =====================================================================
local P = Ems
local core = exports.elyzea_core
local D = Config.Death

P.down = {}   -- [src] = { since, untilT, stabilized, cid, x, y, z, street, cause }

local function SetDeadMeta(src, on)
    pcall(function() core:SetMetadata(src, 'isdead', on == true) end)
end

local function Clear(src)
    local d = P.down[src]
    P.down[src] = nil
    if GetPlayerName(src) then
        if Player(src).state.emsDown then Player(src).state:set('emsDown', false, true) end
        SetDeadMeta(src, false)
    end
    if d and P.PatientUp then P.PatientUp(src, d) end
    return d
end
P.ClearDown = Clear

function P.IsDown(src) return P.down[tonumber(src) or -1] ~= nil end

local function Info(src)
    local d = P.down[src]
    if not d then return nil end
    return { since = d.since, untilT = d.untilT, stabilized = d.stabilized, now = os.time(), fee = D.respawnFee }
end
local function Push(src) TriggerClientEvent('ems:client:downInfo', src, Info(src)) end

-- Mise à terre annoncée par le client (mort réelle constatée côté client)
RegisterNetEvent('ems:server:down', function(info)
    local src = source
    if not D.enabled or P.down[src] or not P.GetPlayer(src) then return end
    local c = P.Coords(src)
    if not c then return end
    info = type(info) == 'table' and info or {}
    local now = os.time()
    P.down[src] = { since = now, untilT = now + D.bleedout, stabilized = false, cid = P.Cid(src), x = c.x, y = c.y, z = c.z,
        street = P.Clean(info.street, 120), cause = P.Clean(info.cause, 40) }
    Player(src).state:set('emsDown', true, true)
    SetDeadMeta(src, true)
    Push(src)
    if D.autoCall and P.CreateCall then
        P.CreateCall({ source = 'auto', reason = 'Personne inconsciente', urgency = 3, coords = c, street = P.down[src].street,
            patientSrc = src, info = P.down[src].cause ~= '' and ('Cause probable : ' .. P.down[src].cause) or nil })
    end
end)

-- Appel manuel depuis le coma (G) si l'appel automatique est coupé ou fini
RegisterNetEvent('ems:server:downCall', function()
    local src = source
    local d = P.down[src]
    if not d or not P.CreateCall then return end
    if d.called and os.time() - d.called < 60 then return P.Notify(src, 'Les secours ont déjà été prévenus.', 'inform') end
    d.called = os.time()
    P.CreateCall({ source = 'down', reason = 'Personne inconsciente (signal)', urgency = 3, coords = vector3(d.x, d.y, d.z), street = d.street, patientSrc = src })
    P.Notify(src, 'Signal envoyé aux secours.', 'success')
end)

-- Réapparition à l'hôpital (après le délai)
RegisterNetEvent('ems:server:respawn', function()
    local src = source
    local d = P.down[src]
    if not d then return end
    if os.time() < d.untilT then return Push(src) end
    local fee = math.floor(tonumber(D.respawnFee) or 0)
    local paidWith
    if fee > 0 then
        paidWith = P.Charge(src, fee, 'Frais d\'hôpital')
        if paidWith then
            -- Agence dont la zone d'alerte couvre le lieu du coma
            local job = next(P.RouteJobs(vector3(d.x or 0.0, d.y or 0.0, d.z or 0.0))) or P.MainJob()
            P.SocietyAdd(fee, 'Frais d\'hôpital · ' .. P.Name(src), job)
            P.Tx({ job = job, type = 'in', category = 'respawn', amount = fee, reason = 'Frais d\'hôpital (réapparition)', targetCid = d.cid, targetName = P.Name(src) })
        end
    end
    Clear(src)
    TriggerClientEvent('ems:client:respawn', src, D.hospital)
    if fee > 0 then
        P.Notify(src, paidWith and ('Frais d\'hôpital : %d $.'):format(fee) or 'Vous n\'aviez pas de quoi payer les frais d\'hôpital.', paidWith and 'inform' or 'error')
    end
    P.Log(src, 'Réapparition', ('%s · après %d s'):format(P.Name(src), os.time() - d.since))
end)

-- Le client est debout tout seul (réanimé par un autre script, vie remise…) : on suit
RegisterNetEvent('ems:server:up', function()
    local src = source
    if P.down[src] and not Player(src).state.emsDown then Clear(src) end
end)

-- Réanimation (EMS ou export). health : 101-200 (sinon santé de Config.Revive)
function P.Revive(target, health)
    target = tonumber(target)
    if not target then return false end
    local was = P.down[target] ~= nil
    Clear(target)
    TriggerClientEvent('ems:client:revive', target, tonumber(health) or Config.Revive.health)
    return was
end

function P.Stabilize(target)
    local d = P.down[target]
    if not d or d.stabilized then return false end
    d.stabilized = true
    d.untilT = d.untilT + (D.stabilizeBonus or 0)
    Push(target)
    return true
end

-- Liste des personnes à terre (tablette, carte : EMS en service)
function P.DownList(withPos)
    local list = {}
    for src, d in pairs(P.down) do
        if GetPlayerName(src) then
            local v = { id = src, name = P.Name(src), since = d.since, stabilized = d.stabilized, street = d.street }
            if withPos then
                local c = P.Coords(src)
                if c then v.x, v.y = math.floor(c.x), math.floor(c.y) end
            end
            list[#list + 1] = v
        end
    end
    table.sort(list, function(a, b) return a.since < b.since end)
    return list
end

-- Réanimation staff (admin_menu met emsDown à false sur le serveur)
AddStateBagChangeHandler('emsDown', nil, function(bagName, _, value)
    if value then return end
    local src = tonumber(tostring(bagName):match('^player:(%d+)$'))
    if src and P.down[src] then
        CreateThread(function() Clear(src) end)
    end
end)

-- Reconnexion : un joueur parti à terre revient à terre
AddEventHandler('elyzea:server:playerLoaded', function(src)
    if not D.enabled then return end
    local p = P.GetPlayer(src)
    if not p or p.PlayerData.metadata.isdead ~= true then return end
    SetTimeout(4000, function()
        if not GetPlayerName(src) or P.down[src] then return end
        local c = P.Coords(src) or vector3(0, 0, 0)
        local now = os.time()
        P.down[src] = { since = now, untilT = now + D.bleedout, stabilized = false, cid = P.Cid(src), x = c.x, y = c.y, z = c.z, street = '' }
        Player(src).state:set('emsDown', true, true)
        TriggerClientEvent('ems:client:forceDown', src, Info(src))
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local d = P.down[src]
    P.down[src] = nil
    if d and P.PatientUp then P.PatientUp(src, d) end
end)

P.Actions.downInfo = { perm = false, fn = function(src) return { info = Info(src) } end }
