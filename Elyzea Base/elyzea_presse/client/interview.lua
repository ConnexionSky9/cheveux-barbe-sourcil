-- =====================================================================
--  ELYZEA PRESSE - client : interviews et annonces payantes (côté personne sollicitée)
--  · Demande d'interview : Accepter / Refuser (souris), case « rester anonyme ».
--    Sans réponse, la demande expire : personne n'est jamais forcé.
--  · Interview en cours : bandeau ; /fininterview pour y mettre fin à tout moment.
--  · Notes (journaliste) : bloc-notes de reportage ou tablette › Interviews.
--  · Proposition d'annonce payante : récapitulatif, paiement banque / liquide, ou refus.
-- =====================================================================
local C = PresseC

C.interview = nil   -- { id, subject, role, other, anonymous, started, agency }

-- ---------------------------------------------------------------------
-- Demande reçue
-- ---------------------------------------------------------------------
local offer = nil
local function EndOffer()
    if not offer then return end
    offer = nil
    C.Focus('ivOffer', false)
    SendNUIMessage({ action = 'ivOffer', show = false })
end
C.ui.ivOffer = { close = function()
    if offer then TriggerServerEvent('presse:server:interviewAnswer', offer.id, false) end
    EndOffer()
end }

RegisterNetEvent('presse:client:interviewOffer', function(o)
    if offer then TriggerServerEvent('presse:server:interviewAnswer', o.id, false) return end   -- une seule demande à la fois
    offer = o
    C.Focus('ivOffer', true)
    SendNUIMessage({ action = 'ivOffer', show = true, offer = o })
    local id = o.id
    CreateThread(function()
        local untilT = GetGameTimer() + (o.timeout or 30) * 1000
        while offer and offer.id == id do
            if GetGameTimer() > untilT then EndOffer() break end
            Wait(250)
        end
    end)
end)
RegisterNetEvent('presse:client:interviewOfferClosed', function(id) if offer and offer.id == id then EndOffer() end end)

RegisterNUICallback('ivAnswer', function(body, cb)
    cb({})
    if not offer then return end
    TriggerServerEvent('presse:server:interviewAnswer', offer.id, body.accept == true, body.anonymous == true)
    EndOffer()
end)

-- ---------------------------------------------------------------------
-- Interview en cours
-- ---------------------------------------------------------------------
RegisterNetEvent('presse:client:interviewStart', function(iv)
    C.interview = iv
    SendNUIMessage({ action = 'ivBanner', iv = iv })
end)
RegisterNetEvent('presse:client:interviewEnd', function(id)
    if C.interview and C.interview.id == id then C.interview = nil end
    SendNUIMessage({ action = 'ivBanner', iv = nil })
end)

local function Leave()
    if not C.interview then return C.Notify('Aucune interview en cours.', 'error') end
    TriggerServerEvent('presse:server:interviewLeave')
end
RegisterCommand('fininterview', Leave, false)
C.LeaveInterview = Leave

-- ---------------------------------------------------------------------
-- Notes de l'interview (journaliste)
-- ---------------------------------------------------------------------
local notesOpen = false
C.ui.notes = { close = function() notesOpen = false C.Focus('notes', false) SendNUIMessage({ action = 'notes', show = false }) end }

function C.OpenNotes(id)
    id = id or (C.interview and C.interview.role == 'journalist' and C.interview.id)
    if not id then
        if C.Can('tablet') and C.OpenTablet then return C.OpenTablet({ page = 'interviews' }) end
        return C.Notify('Aucune interview en cours.', 'error')
    end
    local r = C.Req('interviewGet', { id = id })
    if r.error then return C.Notify(r.error, 'error') end
    notesOpen = true
    C.Focus('notes', true)
    SendNUIMessage({ action = 'notes', show = true, interview = r.interview, max = Config.Interview.notesMax })
end
RegisterNUICallback('notesSave', function(body, cb)
    local r = C.Req('interviewNotes', { id = body.id, notes = body.notes })
    if r.ok then C.Notify(r.message, 'success') end
    cb(r)
end)

-- ---------------------------------------------------------------------
-- Annonce payante proposée par un journaliste
-- ---------------------------------------------------------------------
local ad = nil
local function EndAd()
    if not ad then return end
    ad = nil
    C.Focus('adOffer', false)
    SendNUIMessage({ action = 'adOffer', show = false })
end
C.ui.adOffer = { close = function()
    if ad then TriggerServerEvent('presse:server:adAnswer', ad.id, false) end
    EndAd()
end }
RegisterNetEvent('presse:client:adOffer', function(o)
    if ad then TriggerServerEvent('presse:server:adAnswer', o.id, false) return end
    ad = o
    C.Focus('adOffer', true)
    SendNUIMessage({ action = 'adOffer', show = true, offer = o })
    local id = o.id
    CreateThread(function()
        local untilT = GetGameTimer() + (o.timeout or 45) * 1000
        while ad and ad.id == id do
            if GetGameTimer() > untilT then EndAd() break end
            Wait(250)
        end
    end)
end)
RegisterNetEvent('presse:client:adOfferClosed', function(id) if ad and ad.id == id then EndAd() end end)
RegisterNUICallback('adAnswer', function(body, cb)
    cb({})
    if not ad then return end
    TriggerServerEvent('presse:server:adAnswer', ad.id, body.accept == true, body.method == 'cash' and 'cash' or 'bank')
    EndAd()
end)

-- ---------------------------------------------------------------------
-- Carte de presse montrée (par soi ou par quelqu'un à côté)
-- ---------------------------------------------------------------------
RegisterNetEvent('presse:client:card', function(card, own)
    SendNUIMessage({ action = 'card', card = card, own = own })
end)

-- ---------------------------------------------------------------------
-- Flash info / annonce diffusée (tout le monde)
-- ---------------------------------------------------------------------
RegisterNetEvent('presse:client:flash', function(f)
    SendNUIMessage({ action = 'flash', flash = f })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)
