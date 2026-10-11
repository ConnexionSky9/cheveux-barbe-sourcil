-- =====================================================================
--  ELYZEA JOBS · pont pour les tablettes des métiers
--  À inclure dans le fxmanifest d'une ressource métier :
--      client_script '@elyzea_jobs/client/bridge.lua'
--  et dans son interface :
--      <link rel="stylesheet" href="nui://elyzea_jobs/html/ejobs.css">
--      <script src="nui://elyzea_jobs/html/ejobs.js"></script>
--  Les pages « Équipe » et « Patron » (EJobs.mount) appellent ici le callback NUI « ejobs ».
-- =====================================================================
local RES = GetCurrentResourceName()
local pending, seq = {}, 0

RegisterNUICallback('ejobs', function(body, cb)
    seq = seq + 1
    local id = seq
    pending[id] = cb
    TriggerServerEvent('elyzea_jobs:req', RES, id, body and body.action, body and body.data)
    SetTimeout(10000, function()
        if pending[id] then pending[id]({ error = 'Le serveur ne répond pas.' }) pending[id] = nil end
    end)
end)

RegisterNetEvent('elyzea_jobs:res:' .. RES, function(id, result)
    local cb = pending[id]
    if cb then pending[id] = nil cb(result or {}) end
end)

-- Tenue de service : uniquement quand le joueur la demande (jamais à la prise de service).
-- Une ressource peut définir sa propre fonction globale EJobsUniform(on) -> ok, message ;
-- sinon les tenues du menu admin (admin_menu › Métiers › Tenues) sont utilisées.
RegisterNUICallback('ejobsUniform', function(body, cb)
    local on = body and body.on == true
    local ok, msg
    if type(EJobsUniform) == 'function' then
        ok, msg = EJobsUniform(on)
    elseif GetResourceState('admin_menu') == 'started' then
        local okCall, a, b = pcall(function() return exports.admin_menu:SetServiceUniform(on) end)
        if okCall then ok, msg = a, b else ok, msg = false, 'Tenues indisponibles.' end
    else
        ok, msg = false, 'Aucune tenue de service configurée.'
    end
    cb({ ok = ok == true, message = msg })
end)
