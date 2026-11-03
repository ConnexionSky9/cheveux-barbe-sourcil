-- =====================================================================
--  ELYZEA LASERGAME - RESTAURATION DE L'ÉTAT RP (serveur)
--  Avant l'entrée dans une partie, l'état RP est sauvegardé EN BASE (lg_restore) :
--    instance (routing bucket), position, cap, vie, gilet, apparence (vêtements, accessoires).
--  L'inventaire RP n'est ni copié ni modifié : il est verrouillé pendant la partie (state bag),
--  donc rien ne peut être perdu ni dupliqué. Les armes LaserGame n'existent que côté GTA,
--  elles sont retirées à la sortie et ne passent jamais par l'inventaire.
--  La ligne lg_restore n'est supprimée qu'APRÈS la restauration : déconnexion, crash du client,
--  redémarrage de la ressource ou du serveur → restauration à la prochaine occasion.
-- =====================================================================
Restore = {}

-- Apparence envoyée par le client juste avant l'entrée (vêtements uniquement, valeurs bornées)
local pendingLook = {}   -- [src] = { model, comps, props }

local function cleanLook(l)
    if type(l) ~= 'table' then return nil end
    local out = { model = tonumber(l.model), comps = {}, props = {} }
    for i = 0, 11 do
        local c = type(l.comps) == 'table' and l.comps[tostring(i)] or nil
        if type(c) == 'table' then out.comps[tostring(i)] = { LGU.Int(c[1], -1, 4000, 0), LGU.Int(c[2], 0, 255, 0), LGU.Int(c[3], 0, 3, 0) } end
    end
    for _, i in ipairs({ 0, 1, 2, 6, 7 }) do
        local p = type(l.props) == 'table' and l.props[tostring(i)] or nil
        if type(p) == 'table' then out.props[tostring(i)] = { LGU.Int(p[1], -1, 4000, -1), LGU.Int(p[2], 0, 255, 0) } end
    end
    return out
end

RegisterNetEvent('elyzea_lasergame:look', function(look)
    local src = source
    if not Security.Allow(src, 'look') then return end
    pendingLook[src] = cleanLook(look)
end)
AddEventHandler('playerDropped', function() pendingLook[source] = nil end)

-- Sauvegarde (appelée par le serveur au moment de l'entrée, avant tout changement)
function Restore.Save(src, cid, uid)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    local snap = {
        bucket = GetPlayerRoutingBucket(src),
        x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped),
        health = GetEntityHealth(ped), armor = GetPedArmour(ped),
        look = pendingLook[src],
        t = os.time(),
    }
    -- ne remplace jamais une sauvegarde plus ancienne non restaurée (l'état RP d'origine reste la référence)
    local existing = MySQL.single.await('SELECT `data` FROM `lg_restore` WHERE `citizenid` = ?', { cid })
    if existing then
        local ok, old = pcall(json.decode, existing.data)
        if ok and type(old) == 'table' then
            MySQL.update.await('UPDATE `lg_restore` SET `match_uid` = ? WHERE `citizenid` = ?', { uid, cid })
            return old
        end
    end
    MySQL.query.await('INSERT INTO `lg_restore` (`citizenid`, `match_uid`, `data`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `match_uid` = VALUES(`match_uid`), `data` = VALUES(`data`)',
        { cid, uid, json.encode(snap) })
    return snap
end

-- Renvoie le joueur dans son monde RP. La ligne en base est supprimée une fois le client confirmé.
local awaiting = {}  -- [src] = cid en attente de confirmation
function Restore.Apply(src, cid, snap, quiet)
    if not snap or not GetPlayerName(src) then return false end
    SetPlayerRoutingBucket(src, tonumber(snap.bucket) or 0)
    awaiting[src] = cid
    TriggerClientEvent('elyzea_lasergame:restore', src, {
        x = snap.x, y = snap.y, z = snap.z, h = snap.h, health = snap.health, armor = snap.armor, look = snap.look, quiet = quiet,
    })
    -- l'état « en partie » est retiré un peu après le retour (le joueur, téléporté, n'est pas pris pour un mort
    -- qui réapparaît par admin_menu / elyzea_ems)
    SetTimeout(4000, function()
        if GetPlayerName(src) and not Games.ByPlayer(src) then
            Player(src).state:set(LG.StateArena, false, true)
            Player(src).state:set(LG.StateGame, nil, true)
        end
    end)
    -- filet de sécurité : sans confirmation du client en 20 s, la ligne reste et sera rejouée à la reconnexion
    return true
end

RegisterNetEvent('elyzea_lasergame:restored', function()
    local src = source
    local cid = awaiting[src]
    if not cid then return end
    awaiting[src] = nil
    MySQL.query('DELETE FROM `lg_restore` WHERE `citizenid` = ?', { cid })
end)
AddEventHandler('playerDropped', function() awaiting[source] = nil end)

-- Restauration depuis la base (reconnexion, démarrage de la ressource) : seulement hors partie
function Restore.FromDb(src)
    if Games.ByPlayer(src) then return false end
    local id = Bridge.Identity(src)
    if not id then return false end
    local row = MySQL.single.await('SELECT `data`, `match_uid` FROM `lg_restore` WHERE `citizenid` = ?', { id.cid })
    if not row then return false end
    local ok, snap = pcall(json.decode, row.data)
    if not ok or type(snap) ~= 'table' then
        MySQL.query('DELETE FROM `lg_restore` WHERE `citizenid` = ?', { id.cid })
        return false
    end
    Restore.Apply(src, id.cid, snap, true)
    Logs.Add('pvp', ('état RP restauré après la partie %s (reconnexion / redémarrage)'):format(row.match_uid), nil, src)
    return true
end

-- Commande de secours pour le staff : /lgrestore [id]
RegisterCommand('lgrestore', function(src, args)
    local target = tonumber(args[1]) or src
    if src ~= 0 and not Bridge.IsAdmin(src) then return end
    if not GetPlayerName(target) then return end
    if Games.ByPlayer(target) then Games.ForceLeave(target, 'restauration staff') end
    SetTimeout(500, function()
        local done = Restore.FromDb(target)
        Logs.Add('admin', ('/lgrestore sur le joueur %d : %s'):format(target, done and 'restauré' or 'aucune sauvegarde'), nil, src)
    end)
end, false)
