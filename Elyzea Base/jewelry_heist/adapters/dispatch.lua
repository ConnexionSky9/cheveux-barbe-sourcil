-- =====================================================================
--  ADAPTATEUR DISPATCH (serveur) : alerte « Braquage de bijouterie en cours »
--  · elyzea_police : SendAlert(type, coords, titre, description, rue, { radius })
--    (carte et liste des alertes de la tablette police)
--  · interne : notification + blip temporaire envoyés aux seuls policiers en service
--  Mode « police.dispatch » : 'auto' | 'elyzea_police' | 'internal' | 'both'
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Dispatch = A

local function sendPolice(P, coords, title, desc)
    if GetResourceState('elyzea_police') ~= 'started' then return false end
    local ok, id = pcall(function()
        return exports.elyzea_police:SendAlert(P.alertKind or 'robbery', coords, title, desc, nil, { radius = math.floor(P.blip.radius or 0) })
    end)
    return ok and id ~= nil
end

local function sendInternal(P, coords, title, desc, shopId)
    for _, src in ipairs(Adapters.Police.OnDuty()) do
        TriggerClientEvent('jh:client:policeAlert', src, { coords = coords, title = title, desc = desc, shop = shopId, blip = P.blip, notify = P.notify })
    end
    return true
end

-- Retourne le canal réellement utilisé (journalisé)
function A.Alert(coords, title, desc, shopId)
    local P = JHS.S.police
    local mode = P.dispatch or 'auto'
    local used = {}
    if mode == 'elyzea_police' or mode == 'both' or mode == 'auto' then
        if sendPolice(P, coords, title, desc) then used[#used + 1] = 'elyzea_police' end
    end
    if mode == 'internal' or mode == 'both' or (mode == 'auto' and #used == 0) then
        sendInternal(P, coords, title, desc, shopId)
        used[#used + 1] = 'interne'
    end
    return table.concat(used, ' + ')
end
