-- =====================================================================
--  ELYZEA LABS · client : tablette « Laboratoire »
--  À l'intérieur : F5 (intégré au F5 d'elyzea_illegal, Config.Tablet.useIllegalF5) ou /laboratoire.
-- =====================================================================
local C = LabC

function C.OpenTablet()
    if not C.inside then return C.Notify('La tablette du laboratoire s\'utilise à l\'intérieur.', 'error') end
    if C.Editing and C.Editing() then return end
    local r = C.Pub('tablet', { lab = C.inside.id })
    if r.error then return C.Notify(r.error, 'error') end
    C.Open('tablet', r)
end
function C.RefreshTablet()
    if C.ui ~= 'tablet' or not C.inside then return end
    local r = C.Pub('tablet', { lab = C.inside.id })
    if not r.error then C.Update('tablet', r) end
end

RegisterCommand(Config.Tablet.command, function() C.OpenTablet() end, false)

local ACTIONS = { setCode = true, setPerms = true, equipBuy = true, equipStore = true, equipSell = true, upgrade = true }
RegisterNUICallback('tabletAction', function(body, cb)
    if not C.inside then return cb({ error = 'Tu n\'es plus dans le laboratoire.' }) end
    local name = tostring(body.name or '')
    local d = type(body.data) == 'table' and body.data or {}
    d.lab = C.inside.id
    if name == 'stash' then
        d.fromTablet = true
        C.Close()
        cb({})
        return C.Show(C.Pub('stash', d))
    elseif name == 'place' then
        C.Close()
        cb({})
        return C.StartPlacement(d.id and 'place' or 'buy', tostring(d.type or ''), tonumber(d.id))
    end
    if not ACTIONS[name] then return cb({ error = 'Action inconnue.' }) end
    local r = C.Pub(name, d)
    C.Show(r)
    cb(r)
    C.RefreshTablet()
end)
