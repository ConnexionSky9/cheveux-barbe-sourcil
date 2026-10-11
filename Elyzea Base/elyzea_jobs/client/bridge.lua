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
