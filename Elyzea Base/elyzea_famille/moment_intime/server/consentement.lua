-- =====================================================================
--  ELYZEA FAMILLE - serveur : demandes de consentement
--  Le serveur ouvre une fenêtre « Accepter / Refuser » chez un joueur et attend sa réponse.
--  Une seule demande en attente par joueur ; expiration = refus ; déconnexion = refus.
-- =====================================================================
local pending = {}   -- [src] = { id, cb, expire }

-- Fam.Consentement(src, { titre, texte, details = {..}, options = {...} }, secondes, cb(accepte, options))
-- Renvoie false si le joueur a déjà une demande en attente.
function Fam.Consentement(src, contenu, secondes, cb)
    if pending[src] then return false end
    local id = Fam.NouvelId('DEM')
    pending[src] = { id = id, cb = cb, expire = os.time() + secondes }
    TriggerClientEvent('elyzea_famille:client:consentement', src, id, contenu, secondes)
    SetTimeout(secondes * 1000 + 500, function()
        local p = pending[src]
        if p and p.id == id then
            pending[src] = nil
            TriggerClientEvent('elyzea_famille:client:consentementFerme', src, id)
            cb(false, nil, 'expire')
        end
    end)
    return true
end

function Fam.ConsentementEnAttente(src) return pending[src] ~= nil end

-- Annule la demande en attente d'un joueur (ex. l'autre personne s'est éloignée ou déconnectée)
function Fam.AnnulerConsentement(src, raison)
    local p = pending[src]
    if not p then return end
    pending[src] = nil
    TriggerClientEvent('elyzea_famille:client:consentementFerme', src, p.id)
    p.cb(false, nil, raison or 'annule')
end

RegisterNetEvent('elyzea_famille:consentement', function(id, accepte, options)
    local src = source
    local p = pending[src]
    if not p or type(id) ~= 'string' or p.id ~= id then return Fam.Suspect(src, 'réponse de consentement sans demande') end
    pending[src] = nil
    if type(options) ~= 'table' then options = {} end
    -- seules des cases à cocher sont acceptées en retour
    local clean = {}
    for k, v in pairs(options) do
        if type(k) == 'string' and #k <= 24 then clean[k] = v == true end
    end
    p.cb(accepte == true, clean, accepte == true and 'accepte' or 'refuse')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local p = pending[src]
    if p then pending[src] = nil p.cb(false, nil, 'deconnexion') end
end)
