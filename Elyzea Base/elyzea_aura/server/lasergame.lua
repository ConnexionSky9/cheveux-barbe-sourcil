-- =========================================================
--  APPLI « LASERGAME » : passerelle vers elyzea_lasergame
--  Toute la logique (classements, points, demandes de match, annonces, messages, GPS)
--  est dans elyzea_lasergame (server/phone.lua) qui revérifie tout. Ici : appli installée,
--  liste blanche des actions, et annonce des nouvelles publications aux joueurs qui ont l'appli.
--  « Rejoindre » ne téléporte jamais : le téléphone pose seulement un point GPS.
-- =========================================================
local A = AuraCore
local Register, Notify, Players, HasApp = A.Register, A.Notify, A.Players, A.HasApp
local APP = 'lasergame'

local ACTIONS = { home = true, board = true, posts = true, create = true, cancel = true, join = true, leave = true,
    gps = true, threads = true, thread = true, send = true }

Register('lgCall', function(src, me, args)
    if not HasApp(me, APP) then return { ok = false, error = 'Application non installée' } end
    local action = tostring(args.action or '')
    if not ACTIONS[action] then return { ok = false, error = 'Action inconnue' } end
    if GetResourceState('elyzea_lasergame') ~= 'started' then
        return { ok = false, offline = true, error = 'Le LaserGame est fermé pour le moment.' }
    end
    local ok, r = pcall(function()
        return exports.elyzea_lasergame:PhoneCall(src, action, type(args.data) == 'table' and args.data or {})
    end)
    if not ok or type(r) ~= 'table' then
        print(('[elyzea_aura] LaserGame (%s) : %s'):format(action, tostring(r)))
        return { ok = false, error = 'Le LaserGame est momentanément indisponible.' }
    end
    -- Nouvelle demande de match / annonce : prévenir les autres joueurs qui ont l'appli
    if r.ok and type(r.broadcast) == 'table' then
        local title, text = tostring(r.broadcast.title or 'LaserGame'), tostring(r.broadcast.text or '')
        for s, p in pairs(Players) do
            if s ~= src and p and p.settings and HasApp(p, APP) then
                Notify(s, { app = APP, title = title, text = text })
            end
        end
    end
    r.broadcast, r.toSrc = nil, nil
    return r
end)
