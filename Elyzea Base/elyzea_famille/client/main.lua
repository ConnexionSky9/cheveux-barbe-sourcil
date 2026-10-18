-- =====================================================================
--  ELYZEA FAMILLE - client : fenêtres (consentement, proposition, contraception), menu ALT, commandes
--  Le client n'envoie que des intentions ; le serveur vérifie tout.
-- =====================================================================
local ouvert = nil     -- fenêtre NUI ouverte : 'consentement' | 'proposer' | 'panneau'
local consentId = nil
local proposerCible = nil

local function Notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end
FamNotify = Notify

local function fermer()
    ouvert, consentId, proposerCible = nil, nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'fermer' })
end

local function ouvrir(nom, data)
    ouvert = nom
    SetNuiFocus(true, true)
    data.action = nom
    SendNUIMessage(data)
end

-- ─────────── Consentement (demande reçue du serveur) ───────────

RegisterNetEvent('elyzea_famille:client:consentement', function(id, contenu, secondes)
    if ouvert then fermer() end
    consentId = id
    ouvrir('consentement', { id = id, contenu = contenu, secondes = secondes })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)

RegisterNetEvent('elyzea_famille:client:consentementFerme', function(id)
    if ouvert == 'consentement' and consentId == id then fermer() end
end)

RegisterNUICallback('consentement', function(body, cb)
    cb('ok')
    if ouvert ~= 'consentement' or body.id ~= consentId then return end
    local id = consentId
    fermer()
    TriggerServerEvent('elyzea_famille:consentement', id, body.accepte == true, type(body.options) == 'table' and body.options or {})
end)

-- ─────────── Proposer un moment intime ───────────

local function joueurEnFace(rayon)
    local me = PlayerPedId()
    local pc, fwd = GetEntityCoords(me), GetEntityForwardVector(me)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local v = GetEntityCoords(GetPlayerPed(pid)) - pc
            local d = #v
            if d <= rayon and (d < 0.8 or (v.x * fwd.x + v.y * fwd.y) / d > 0.3) and (not bestD or d < bestD) then best, bestD = pid, d end
        end
    end
    return best and GetPlayerServerId(best) or nil
end

local function proposer(sid)
    if not Config.Modules.intimite then return end
    if not sid then return Notify('Placez-vous face à la personne.', 'error') end
    local res = Ely.callback.await('famille:intime:options', false, sid)
    if type(res) ~= 'table' then return Notify('Le serveur ne répond pas.', 'error') end
    if res.erreur then return Notify(res.erreur, 'error') end
    proposerCible = sid
    ouvrir('proposer', { cible = sid, options = res.options, duree = res.duree })
end

RegisterNUICallback('proposer', function(body, cb)
    cb('ok')
    if ouvert ~= 'proposer' or not proposerCible then return end
    local cible = proposerCible
    fermer()
    if body.envoyer then
        local o = type(body.options) == 'table' and body.options or {}
        TriggerServerEvent('elyzea_famille:intime:demande', cible, { preservatif = o.preservatif == true, enfant = o.enfant == true })
    end
end)

RegisterCommand(Config.Intimite.commande, function() proposer(joueurEnFace(Config.Intimite.distanceMax)) end, false)

-- ─────────── Ma contraception (privé) ───────────

local function panneau()
    if not Config.Modules.contraception then return end
    local res = Ely.callback.await('famille:contraception', false)
    if type(res) ~= 'table' then return Notify('Le serveur ne répond pas.', 'error') end
    if res.erreur then return Notify(res.erreur, 'error') end
    ouvrir('panneau', { donnees = res })
end
RegisterCommand(Config.Contraception.commande, panneau, false)

-- ─────────── Ma grossesse (privé) ───────────

local function grossesse()
    local res = Ely.callback.await('famille:grossesse', false)
    if type(res) ~= 'table' then return Notify('Le serveur ne répond pas.', 'error') end
    if res.erreur then return Notify(res.erreur, 'error') end
    if res.aucune then return Notify('Aucune grossesse connue. Un test de grossesse ou un examen EMS permet de le savoir.', 'inform') end
    ouvrir('grossesse', { donnees = res })
end
RegisterCommand(Config.Grossesse.commande, grossesse, false)

RegisterNetEvent('elyzea_famille:client:resultatTest', function()
    local ped = PlayerPedId()
    local dict = 'amb@world_human_clipboard@male@idle_a'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    if HasAnimDictLoaded(dict) then TaskPlayAnim(ped, dict, 'idle_c', 4.0, 4.0, 2500, 49, 0.0, false, false, false) end
end)

RegisterNUICallback('fermer', function(_, cb)
    cb('ok')
    if ouvert == 'consentement' and consentId then
        local id = consentId
        fermer()
        TriggerServerEvent('elyzea_famille:consentement', id, false, {})
        return
    end
    fermer()
end)

-- ─────────── Petite animation après une prise de pilule ───────────

RegisterNetEvent('elyzea_famille:client:anim', function(kind)
    if kind ~= 'pilule' then return end
    local ped = PlayerPedId()
    local dict = 'mp_player_intdrink'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    if HasAnimDictLoaded(dict) then TaskPlayAnim(ped, dict, 'loop_bottle', 4.0, 4.0, 2000, 49, 0.0, false, false, false) end
end)

-- ─────────── Menu ALT (fournisseur ajouté dans elyzea_police/client/alt.lua) ───────────

local function emsEnService()
    local ok, job = pcall(function() return exports.elyzea_core:GetJob() end)
    return ok and type(job) == 'table' and job.type == 'ems' and job.onduty == true
end

exports('AltOptions', function(ctx)
    local out = {}
    if type(ctx) ~= 'table' or ctx.kind ~= 'player' or not ctx.sid or ctx.inVehicle then return out end
    if Config.Modules.intimite and not FamIntimeEnCours() then
        out[#out + 1] = { id = 'intime', label = 'Proposer un moment intime', icon = 'intime' }
    end
    if Config.Modules.contraception and emsEnService() then
        local Cc = Config.Contraception
        if Cc.implant.actif and Cc.implant.poseParEms then
            out[#out + 1] = { id = 'implant', label = 'Poser un implant contraceptif', icon = 'implant' }
            out[#out + 1] = { id = 'retrait', label = 'Retirer l\'implant contraceptif', icon = 'implant' }
        end
        if Cc.pilule.actif and Cc.pilule.ordonnance then
            out[#out + 1] = { id = 'ordonnance', label = 'Prescrire la pilule', icon = 'ordonnance' }
        end
    end
    if Config.Modules.conception and Config.Grossesse.examenEms and emsEnService() then
        out[#out + 1] = { id = 'examen', label = 'Examen de grossesse', icon = 'examine' }
    end
    return out
end)

exports('AltSelect', function(id, ctx)
    if type(ctx) ~= 'table' or not ctx.sid then return true end
    CreateThread(function()
        if id == 'intime' then proposer(ctx.sid)
        elseif id == 'implant' or id == 'retrait' or id == 'ordonnance' then TriggerServerEvent('elyzea_famille:ems', id, ctx.sid)
        elseif id == 'examen' then TriggerServerEvent('elyzea_famille:examen', ctx.sid) end
    end)
    return true
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and ouvert then SetNuiFocus(false, false) end
end)
