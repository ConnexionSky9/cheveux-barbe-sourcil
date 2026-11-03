-- =====================================================================
--  ELYZEA LASERGAME - JOUEURS : exclusions du LaserGame, proximité des PNJ
--  Chargé AVANT pvp.lua / zombie.lua : les actions qui font entrer dans une partie
--  exigent d'être auprès d'un PNJ LaserGame (anti-téléportation, anti-menu de triche).
-- =====================================================================
Players = { excluded = {} }

local NPC_RANGE = 7.0     -- distance max d'un PNJ LaserGame pour créer / rejoindre une partie

-- ---------------------------------------------------------------- exclusions
function Players.LoadExclusions()
    Players.excluded = {}
    local rows = MySQL.query.await('SELECT `citizenid`, `ban_until` FROM `lg_players` WHERE `banned` = 1') or {}
    for _, r in ipairs(rows) do
        local untilTs = type(r.ban_until) == 'number' and math.floor(r.ban_until / 1000) or nil
        Players.excluded[r.citizenid] = untilTs or true
    end
end

function Players.IsExcluded(cid)
    local e = Players.excluded[cid]
    if not e then return false end
    if e ~= true and os.time() > e then
        Players.excluded[cid] = nil
        MySQL.update('UPDATE `lg_players` SET `banned` = 0, `ban_reason` = NULL, `ban_until` = NULL WHERE `citizenid` = ?', { cid })
        return false
    end
    return true
end

-- hours = 0 : définitif
function Players.Exclude(cid, on, reason, hours)
    DB.ProfileByCid(cid)
    if on then
        hours = tonumber(hours) or 0
        MySQL.update.await('UPDATE `lg_players` SET `banned` = 1, `ban_reason` = ?, `ban_until` = ' .. (hours > 0 and '(NOW() + INTERVAL ? HOUR)' or 'NULL') .. ' WHERE `citizenid` = ?',
            hours > 0 and { tostring(reason or ''):sub(1, 160), hours, cid } or { tostring(reason or ''):sub(1, 160), cid })
        Players.excluded[cid] = hours > 0 and (os.time() + hours * 3600) or true
        local s = Bridge.SourceByCid(cid)
        if s and Games.ByPlayer(s) then Games.ForceLeave(s, 'exclu du LaserGame') end
    else
        MySQL.update.await('UPDATE `lg_players` SET `banned` = 0, `ban_reason` = NULL, `ban_until` = NULL WHERE `citizenid` = ?', { cid })
        Players.excluded[cid] = nil
    end
end

-- ---------------------------------------------------------------- proximité d'un PNJ LaserGame
-- PNJ de la configuration / posés en jeu + PNJ « LaserGame » de l'éditeur de map d'admin_menu
local function npcPositions()
    local list = {}
    for _, n in ipairs(Settings.Npcs()) do list[#list + 1] = { x = n.x, y = n.y, z = n.z } end
    if GetResourceState('admin_menu') == 'started' then
        local ok, eds = pcall(function() return exports.admin_menu:GetLaserGameNpcs() end)
        if ok and type(eds) == 'table' then for _, n in ipairs(eds) do list[#list + 1] = n end end
    end
    return list
end

function Players.NearNpc(src)
    if Bridge.IsAdmin(src) then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local p = { x = c.x, y = c.y, z = c.z }
    for _, n in ipairs(npcPositions()) do
        if LGU.Dist(p, n) <= NPC_RANGE then return true end
    end
    return false
end

-- Les actions qui font entrer dans une partie exigent d'être auprès d'un PNJ (anti-téléportation)
local NEED_NPC = { ['pvp:create'] = true, ['pvp:join'] = true, ['pvp:quick'] = true, ['zb:create'] = true, ['zb:join'] = true, ['spectate:join'] = true }
local origRegister = RPC.Register
RPC.Register = function(name, fn)
    if NEED_NPC[name] then
        return origRegister(name, function(src, ...)
            if not Players.NearNpc(src) then return false, 'Approche-toi d\'un PNJ LaserGame.' end
            return fn(src, ...)
        end)
    end
    return origRegister(name, fn)
end
