-- =========================================================
--  APPLI « MAISON » : passerelle vers elyzea_dynasty (Dynasty 8)
--  · Visible seulement pour les joueurs qui ont des droits sur au moins un logement
--    (titulaire ou locataire ajouté) : pas besoin de l'installer.
--  · Toute la logique (droits, améliorations, caméras, danseuse, code, sonnette,
--    locataires) est dans elyzea_dynasty (server/upgrades.lua) qui revérifie tout.
--  · Sonnette : le résident reçoit une notification du téléphone et peut ouvrir à distance.
-- =========================================================
local A = AuraCore
local Register, Notify = A.Register, A.Notify
local RES = 'elyzea_dynasty'

local ACTIONS = { home = true, has = true, prop = true, buy = true, setCode = true, bellAnswer = true, grantRevoke = true, grantInvite = true,
    tenantAdd = true, tenantSet = true, camView = true, camRemove = true, camRename = true, camInfo = true,
    dancerStart = true, dancerStyle = true, dancerStop = true }

local function Call(src, action, data)
    if GetResourceState(RES) ~= 'started' then return { ok = false, offline = true, error = 'Dynasty 8 est indisponible pour le moment.' } end
    local ok, r = pcall(function() return exports[RES]:PhoneCall(src, action, data) end)
    if not ok or type(r) ~= 'table' then
        print(('[elyzea_aura] Maison (%s) : %s'):format(action, tostring(r)))
        return { ok = false, error = 'Service momentanément indisponible.' }
    end
    if r.ok == nil then r.ok = r.error == nil end
    return r
end

Register('maisonCall', function(src, me, args)
    local action = tostring(args.action or '')
    if not ACTIONS[action] then return { ok = false, error = 'Action inconnue' } end
    return Call(src, action, type(args.data) == 'table' and args.data or {})
end)

-- L'icône n'apparaît que pour les joueurs qui ont un logement
Register('maisonHas', function(src)
    if GetResourceState(RES) ~= 'started' then return { ok = true, has = false } end
    local ok, has = pcall(function() return exports[RES]:HasHome(src) end)
    return { ok = true, has = ok and has == true }
end)

-- Sonnette : notification du téléphone (elyzea_dynasty déclenche cet évènement serveur)
AddEventHandler('d8:server:bellRang', function(target, b)
    if type(b) ~= 'table' or not tonumber(target) then return end
    Notify(tonumber(target), { app = 'maison', title = 'On sonne chez vous', text = ('%s · %s'):format(tostring(b.visitor or '?'), tostring(b.property or '')) })
end)
