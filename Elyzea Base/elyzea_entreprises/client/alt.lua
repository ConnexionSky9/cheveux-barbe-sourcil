-- =====================================================================
--  elyzea_entreprises - client : actions ALT (système commun elyzea_jobs)
--  Visez un client avec ALT : facturer, faire payer l'entrée (Bahamas).
--  Tout est revérifié par le serveur (service, accès du grade, distance, zone).
-- =====================================================================
local C = ENTC

local function NearEntry(s)
    local me = GetEntityCoords(PlayerPedId())
    for _, z in ipairs(s.zones or {}) do
        if z.type == 'entree' and z.enabled ~= false and #(me - vector3(z.x, z.y, z.z)) <= (z.radius or 2.0) + 2.5 then return true end
    end
    return false
end

local function Options(ctx)
    local c, s = C.Company()
    if not c or not s.enabled or C.busy or ctx.kind ~= 'player' or not ctx.serverId then return {} end
    local group = s.job.label
    if not C.OnDuty() then
        return { { id = 'duty', label = 'Hors service', desc = 'Prenez votre service (F6) pour servir ce client.', disabled = true, group = group, order = 60 } }
    end
    local out = {}
    if C.Can('invoice') then
        out[#out + 1] = { id = 'invoice', label = 'Facturer', desc = 'Ouvre la caisse avec ce client', group = group, order = 60 }
    end
    local f = s.features or {}
    if f.entry and C.Can('entry') then
        local st = s.settings or {}
        local near = NearEntry(s)
        local why = not near and 'Placez-vous à l\'entrée' or nil
        out[#out + 1] = { id = 'entry', label = ('Faire payer l\'entrée (%d $)'):format(math.floor(st.entryPrice or 0)), desc = why, disabled = not near, group = group, order = 61 }
        out[#out + 1] = { id = 'entryVip', label = ('Entrée VIP (%d $)'):format(math.floor(st.vipPrice or 0)), desc = why, disabled = not near, group = group, order = 62 }
    end
    return out
end

local function Select(id, ctx)
    if not ctx.serverId then return end
    if id == 'invoice' then
        C.OpenTablet('invoice', ctx.serverId)
    elseif id == 'entry' or id == 'entryVip' then
        TriggerServerEvent('ent:entry', ctx.serverId, id == 'entryVip')
    end
end

local function Register()
    if GetResourceState('elyzea_jobs') ~= 'started' then return end
    exports.elyzea_jobs:AltRegister('entreprises', Options, Select)
end
CreateThread(function() Wait(1200) Register() end)
AddEventHandler('onClientResourceStart', function(res) if res == 'elyzea_jobs' then Wait(600) Register() end end)
