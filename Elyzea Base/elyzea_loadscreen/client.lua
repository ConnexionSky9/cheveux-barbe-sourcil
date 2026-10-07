-- =====================================================================
--  ELYZEA — LOADING SCREEN · FERMETURE
--  Si elyzea_multichar est présent : on attend qu'il soit prêt
--  (caméra + interface en place) pour faire le fondu → aucun écran noir.
--  Sinon : fermeture quand le personnage est chargé (base Elyzea).
-- =====================================================================

local Config = {
    -- Durée du fondu de sortie en ms (= effects.fadeOutDuration dans js/config.js)
    fadeOutDuration = 1200,

    -- Nom de la resource de sélection de personnage
    multicharResource = 'elyzea_multichar',

    -- Sécurité sans multichar : fermeture X ms après le début de session
    sessionFallbackDelay = 4000,

    -- Sécurité AVEC multichar : si rien n'arrive au bout de X ms, on ferme quand même
    -- (évite un joueur bloqué à vie sur le loading screen)
    multicharFallbackDelay = 45000
}

local closed = false

local function closeLoadingScreen()
    if closed then return end
    closed = true

    SendLoadingScreenMessage(json.encode({
        eventName = 'elyzea:fadeOut',
        duration = Config.fadeOutDuration
    }))

    Wait(Config.fadeOutDuration + 150)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

local function hasMultichar()
    local state = GetResourceState(Config.multicharResource)
    return state == 'started' or state == 'starting'
end

-- Envoyé par elyzea_multichar quand la sélection est prête derrière
AddEventHandler('elyzea:closeLoadingScreen', function()
    CreateThread(closeLoadingScreen)
end)

-- Spawn classique (utile seulement SANS multichar, sinon déjà fermé)
RegisterNetEvent('elyzea:client:playerLoaded', function() CreateThread(closeLoadingScreen) end)

-- Sécurités
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    local delay = hasMultichar() and Config.multicharFallbackDelay or Config.sessionFallbackDelay
    if delay <= 0 then return end
    Wait(delay)
    closeLoadingScreen()
end)
