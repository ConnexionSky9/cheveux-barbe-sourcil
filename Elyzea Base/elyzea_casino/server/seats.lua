-- =========================================================
--  ELYZEA CASINO - places assises (blackjack et roulette, 4 places maximum par table)
--  Le serveur est seul juge : une place = un joueur, un joueur = une place.
--  Deux demandes pour la même place : la première gagne, la seconde est refusée.
-- =========================================================
Tables = {}        -- [pedId] = état de la table (créé par le jeu concerné)
SeatOf = {}        -- [src] = { pedId, idx }
local Games = {}   -- [role] = { new = fn(pt), onSit = fn(T, src, idx), onLeave = fn(T, src, idx, why), public = fn(T) }
Casino.Games = Games

function Casino.GetTable(pedId)
    pedId = tonumber(pedId)
    local pt = Casino.points[pedId or -1]
    if not pt or (pt.role ~= 'blackjack' and pt.role ~= 'roulette') then return nil end
    local T = Tables[pedId]
    if not T or T.game ~= pt.role then
        T = Games[pt.role].new(pt)
        T.id, T.game, T.seats = pedId, pt.role, T.seats or {}
        Tables[pedId] = T
    end
    T.pt = pt
    return T
end

-- Joueurs à qui envoyer l'état d'une table : assis + à moins de 40 m
function Casino.Audience(T)
    local out, seen = {}, {}
    for _, s in pairs(T.seats) do if s.src and GetPlayerName(s.src) and not seen[s.src] then seen[s.src] = true out[#out + 1] = s.src end end
    local tp = T.pt and T.pt.table
    if tp then
        local c = vector3(tp.x, tp.y, tp.z)
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            if not seen[src] then
                local ped = GetPlayerPed(src)
                if ped ~= 0 and #(GetEntityCoords(ped) - c) < 40.0 then seen[src] = true out[#out + 1] = src end
            end
        end
    end
    return out
end

function Casino.Broadcast(T, event, ...)
    for _, src in ipairs(Casino.Audience(T)) do TriggerClientEvent(event, src, ...) end
end

function Casino.PushTable(T)
    Casino.Broadcast(T, 'elyzea_casino:table', T.id, T.game, Games[T.game].public(T))
end

Ely.callback.register('elyzea_casino:sit', function(src, pedId, idx)
    return Casino.Locked(src, 'sit', function()
        if not Casino.Enabled() then return false, 'Le casino est fermé.' end
        local T = Casino.GetTable(pedId)
        if not T then return false, 'Table introuvable.' end
        if not T.pt.table then return false, 'Cette table n\'est pas encore installée.' end
        local cfg = Casino.TableCfg(T.id, T.game)
        if not cfg.enabled then return false, 'Cette table est fermée.' end
        if T.closing then return false, 'Cette table ferme après la manche en cours.' end
        if SeatOf[src] then return false, 'Tu es déjà assis à une table.' end
        idx = math.tointeger(tonumber(idx))
        if not idx or idx < 1 or idx > cfg.maxPlayers then return false, 'Place invalide.' end
        if T.seats[idx] then return false, 'Cette place est déjà prise.' end
        if not Casino.Near(src, T.pt) then return false, 'Approche-toi de la table.' end
        local p = Casino.Player(src)
        if not p then return false, 'Personnage non chargé.' end
        T.seats[idx] = { src = src, cid = p.cid, name = p.name }
        SeatOf[src] = { pedId = T.id, idx = idx }
        Games[T.game].onSit(T, src, idx)
        Casino.PushTable(T)
        return true, nil, { game = T.game, idx = idx, cfg = cfg }
    end)
end)

-- Quitter (bouton, distance, mort, déconnexion, arrêt de la ressource)
function Casino.Leave(src, why)
    local so = SeatOf[src]
    if not so then return false end
    SeatOf[src] = nil
    local T = Tables[so.pedId]
    if not T then return true end
    local s = T.seats[so.idx]
    if s and s.src == src then Games[T.game].onLeave(T, src, so.idx, why) end
    Casino.PushTable(T)
    return true
end

Ely.callback.register('elyzea_casino:leave', function(src) return Casino.Leave(src, 'leave') end)
RegisterNetEvent('elyzea_casino:leave', function() Casino.Leave(source, 'leave') end)
AddEventHandler('playerDropped', function() Casino.Leave(source, 'drop') end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) Casino.Leave(src, 'drop') end)

-- Nouvelle liste de points (éditeur) : une table supprimée rembourse et libère tout le monde
Casino.OnPointsChanged = function(_, new)
    for id, T in pairs(Tables) do
        local pt = new[id]
        if not pt or pt.role ~= T.game or not pt.table then
            if Games[T.game].reset then Games[T.game].reset(T, 'La table a été retirée.') end
            Tables[id] = nil
        else
            T.pt = pt
        end
    end
end

-- Demande d'état (en arrivant près d'une table)
RegisterNetEvent('elyzea_casino:requestTable', function(pedId)
    local src = source
    local T = Tables[tonumber(pedId) or -1]
    if T then TriggerClientEvent('elyzea_casino:table', src, T.id, T.game, Games[T.game].public(T)) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- Arrêt : toutes les mises en jeu sont rendues (en attente si le joueur ne peut pas les recevoir)
    for _, T in pairs(Tables) do
        if Games[T.game].reset then pcall(Games[T.game].reset, T, 'Le casino a été redémarré : mise rendue.') end
    end
end)
