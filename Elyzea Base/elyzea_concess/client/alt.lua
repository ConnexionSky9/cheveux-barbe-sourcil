-- =====================================================================
--  elyzea_concess - client : actions ALT (système commun elyzea_jobs)
--  Visez un client avec ALT : ouvrir le catalogue pour lui vendre un véhicule
--  (l'acheteur proposé est la personne la plus proche). Tout est revérifié par le serveur.
-- =====================================================================
local C = CCL

local function Options(ctx)
    if ctx.kind ~= 'player' or not ctx.serverId or not C.cfg or not C.IsEmployee() then return {} end
    local group = C.cfg.job and C.cfg.job.label or 'Concession'
    local ej = LocalPlayer.state.ejobs
    local canSell = not ej or type(ej.perms) ~= 'table' or ej.perms.sell == true
    if not canSell then return {} end
    if not C.cfg.enabled then
        return { { id = 'closed', label = 'Concession fermée', disabled = true, group = group, order = 70 } }
    end
    return { { id = 'sell', label = 'Vendre un véhicule', desc = C.OnDuty() and 'Ouvre le catalogue (acheteur : la personne la plus proche)' or 'Prenez votre service (F6)',
        disabled = not C.OnDuty(), group = group, order = 70 } }
end

local function Select(id)
    if id == 'sell' then TriggerServerEvent('concess:server:open', 'catalog') end
end

local function Register()
    if GetResourceState('elyzea_jobs') ~= 'started' then return end
    exports.elyzea_jobs:AltRegister('concess', Options, Select)
end
CreateThread(function() Wait(1200) Register() end)
AddEventHandler('onClientResourceStart', function(res) if res == 'elyzea_jobs' then Wait(600) Register() end end)
