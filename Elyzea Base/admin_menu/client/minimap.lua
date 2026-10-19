-- =========================================================
--  MINI-CARTE (tous les joueurs)
--  Forme et position réglées dans le menu (onglet 🗺️ Carte).
--  Les trois éléments de la mini-carte (carte, masque, flou) sont
--  posés sur le même rectangle : on voit exactement ce rectangle.
-- =========================================================
local saved = nil      -- réglage commun (serveur)
local preview = nil    -- aperçu du staff en cours de réglage
local scaleform = nil

local ALIGN = {
    ['top-right'] = { 'R', 'T' }, ['top-left'] = { 'L', 'T' },
    ['bottom-left'] = { 'L', 'B' }, ['bottom-right'] = { 'R', 'B' },
}

-- Verrou (Config.Minimap.locked) : position, taille, forme et marges viennent TOUJOURS de config.lua ;
-- ni le réglage enregistré, ni un aperçu, ni un autre script ne peuvent déplacer la carte.
local LOCK_KEYS = { 'position', 'size', 'widthAdjust', 'marginX', 'marginY', 'shape' }
local function current()
    local s = preview or saved or Config.Minimap
    if Config.Minimap and Config.Minimap.locked then
        local out = {}
        for k, v in pairs(s or {}) do out[k] = v end
        for _, k in ipairs(LOCK_KEYS) do out[k] = Config.Minimap[k] end
        out.enabled = true
        return out
    end
    return s
end

-- Masque de la mini-carte : celui de GTA a des bords flous et laisse des bandes noires sur les côtés.
-- On le remplace par un masque net (minimap/radarmask.png) : la carte remplit exactement son rectangle.
local maskTxd, maskOn = nil, false
local function SharpMask(on)
    -- Désactivé par défaut (Config.Minimap.sharpMask) : le masque de GTA découpe toujours la carte
    if not (Config.Minimap and Config.Minimap.sharpMask == true) then on = false end
    if on == maskOn then return end
    if on then
        if not maskTxd then
            maskTxd = CreateRuntimeTxd('elyzea_minimap')
            CreateRuntimeTextureFromImage(maskTxd, 'radarmasksm', 'minimap/radarmask.png')
        end
        -- Texture réellement chargée ? Sinon on garde le masque de GTA (sinon la carte n'est plus découpée)
        local res = GetTextureResolution('elyzea_minimap', 'radarmasksm')
        if not res or res.x < 8 then return end
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'elyzea_minimap', 'radarmasksm')
    else
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
    end
    maskOn = on
end

-- Rectangle réellement occupé à l'écran (fractions 0..1 depuis le coin haut gauche), pour le HUD
MinimapRect = nil
exports('GetMinimapRect', function() return MinimapRect end)

-- Un seul calcul pour la carte ET le cadre du HUD : on choisit d'abord le rectangle voulu à l'écran,
-- puis on le convertit dans le repère de GTA (ancrage gauche / bas, le seul dont le sens est sûr).
-- Écrans plus larges que 16:9 : GTA place la carte dans une zone 16:9 centrée (repère « virtuel »).
local function layout(s)
    local h = tonumber(s.size) or 0.20
    local w = h * (9 / 16) * ((tonumber(s.widthAdjust) or 100) / 100)   -- largeur dans le repère 16:9
    if s.shape == 'default' then w = h * 0.80 end
    local rx, ry = GetActiveScreenResolution()
    local aspect = rx / math.max(ry, 1)
    local k = aspect > 16 / 9 + 0.01 and (16 / 9) / aspect or 1.0           -- virtuel → écran
    local off = (1.0 - GetSafeZoneSize()) * 0.5
    local mx, my = tonumber(s.marginX) or 0.012, tonumber(s.marginY) or 0.018
    local a = ALIGN[s.position] or ALIGN['bottom-right']
    local realW = w * k
    -- rectangle voulu à l'écran (coin haut gauche)
    local left = (a[1] == 'R') and (1.0 - off - mx - realW) or (off + mx)
    local top = (a[2] == 'T') and (off + my) or (1.0 - off - my - h)
    -- conversion dans le repère de GTA (ancrage L / B)
    local virtLeft = 0.5 + (left - 0.5) / k
    local gx = virtLeft - off
    local gy = (top + h) - (1.0 - off)
    return gx, gy, w, h, { x = left, y = top, w = realW, h = h, align = a[1] .. a[2], round = s.shape == 'round' }
end
function RectOf() return MinimapRect end

local last = nil   -- dernière position posée (gx, gy, w, h)
local function place(relayout)
    local s = current()
    if not s or s.enabled == false then return end
    local gx, gy, w, h, rect = layout(s)
    SetMinimapClipType(s.shape == 'round' and 1 or 0)
    SharpMask(s.shape ~= 'round')
    SetMinimapComponentPosition('minimap', 'L', 'B', gx, gy, w, h)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', gx, gy, w, h)
    -- Flou de fond : même rectangle (sinon un halo sombre déborde autour de la carte)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', gx, gy, w, h)
    local changed = not MinimapRect or MinimapRect.x ~= rect.x or MinimapRect.y ~= rect.y or MinimapRect.w ~= rect.w or MinimapRect.h ~= rect.h
    MinimapRect = rect
    last = { gx, gy, w, h }
    if changed or relayout then TriggerEvent('elyzea:minimapRect', MinimapRect) end
    if relayout then
        -- GTA ne recalcule la mini-carte qu'après un passage en grande carte
        SetBigmapActive(true, false)
        Wait(0)
        SetBigmapActive(false, false)
    end
end

-- Pose complète (avec recalcul de GTA)
local function apply() place(true) end

local function hideHealthBars()
    if not scaleform or not HasScaleformMovieLoaded(scaleform) then
        scaleform = RequestScaleformMovie('minimap')
        local t = GetGameTimer()
        while not HasScaleformMovieLoaded(scaleform) and GetGameTimer() - t < 2000 do Wait(0) end
    end
    BeginScaleformMovieMethod(scaleform, 'SETUP_HEALTH_ARMOUR')
    ScaleformMovieMethodAddParamInt(3)
    EndScaleformMovieMethod()
end

-- Entretien : barres de vie cachées, mini-carte seulement en véhicule
CreateThread(function()
    local lastVeh = nil
    while true do
        local s = current()
        if s and s.enabled ~= false then
            if s.hideHealthBars then hideHealthBars() end
            if s.onlyInVehicle then
                local inVeh = IsPedInAnyVehicle(PlayerPedId(), false)
                if inVeh ~= lastVeh then DisplayRadar(inVeh) lastVeh = inVeh end
            elseif lastVeh == false then
                DisplayRadar(true)
                lastVeh = nil
            end
        end
        Wait(500)
    end
end)

-- Après la connexion, d'autres scripts reposent leur propre mini-carte (souvent sauvegardée sur le PC
-- du joueur) : on repasse plusieurs fois derrière eux pour que la position du staff gagne toujours.
local enforceToken = 0
local function enforce()
    enforceToken = enforceToken + 1
    local token = enforceToken
    CreateThread(function()
        for _, delay in ipairs({ 0, 2000, 6000, 15000, 30000, 60000 }) do
            Wait(delay)
            if token ~= enforceToken then return end
            if not preview and not IsBigmapActive() then apply() end
        end
    end)
end

RegisterNetEvent('adminmenu:map', function(data)
    local hadOnly = saved and saved.onlyInVehicle
    saved = data and data.minimap or saved
    if hadOnly and not (saved and saved.onlyInVehicle) then DisplayRadar(true) end
    if not preview then enforce() end
end)

-- ---------------------------------------------------------
--  Commandes d'autres scripts qui déplacent la mini-carte (/carte…) : neutralisées
-- ---------------------------------------------------------
local Blocked = {}   -- { command, resource }

local function blockCommands()
    if not saved or saved.enabled == false then return end
    local owners = {}
    for _, c in ipairs(GetRegisteredCommands() or {}) do owners[c.name] = c.resource end
    Blocked = {}
    for _, name in ipairs((Config.Minimap and Config.Minimap.blockCommands) or {}) do
        local owner = owners[name]
        if owner and owner ~= GetCurrentResourceName() then
            Blocked[#Blocked + 1] = { command = name, resource = owner }
            RegisterCommand(name, function()
                Notify('La mini-carte est placée par le staff : elle ne peut plus être déplacée.', 'info')
                enforce()
            end, false)
        end
    end
end

CreateThread(function()
    Wait(10000)   -- laisse les autres ressources enregistrer leurs commandes
    blockCommands()
    -- Une autre ressource gère aussi la mini-carte : on vérifie la position chaque minute
    while true do
        Wait(60000)
        if #Blocked > 0 and not preview and not IsBigmapActive() and saved and saved.enabled ~= false then apply() end
    end
end)
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then SetTimeout(3000, function() blockCommands() enforce() end) end
end)

RegisterNUICallback('minimap_conflicts', function(_, cb)
    cb({ list = Blocked })
end)

-- Connexion / choix du personnage : la mini-carte est cachée puis réaffichée (multichar, fondu, caméra).
-- Une position posée pendant qu'elle est cachée n'est pas prise en compte par GTA (carte trop grande,
-- mal cadrée) : on la repose dès qu'elle redevient visible à l'écran.
CreateThread(function()
    local wasVisible = false
    while true do
        local visible = not IsRadarHidden() and IsScreenFadedIn() and not GetIsLoadingScreenActive()
            and not IsPlayerSwitchInProgress() and not IsBigmapActive()
        if visible and not wasVisible and not preview then
            apply()
            SetTimeout(600, function() if not preview and not IsBigmapActive() then apply() end end)
            SetTimeout(2500, function() if not preview and not IsBigmapActive() then apply() end end)
        end
        wasVisible = visible
        Wait(visible and 1000 or 200)
    end
end)

-- Gardien : chaque seconde, la position est reposée (sans clignotement). Si un autre script ou GTA
-- la change, c'est la nôtre qui est prise au prochain recalcul. Après le menu pause / la grande carte,
-- la carte est recalculée tout de suite.
CreateThread(function()
    local wasPaused, wasBig = false, false
    while true do
        Wait(1000)
        if not preview then
            local paused, big = IsPauseMenuActive(), IsBigmapActive()
            if not paused and not big then
                if wasPaused or wasBig then apply() else place(false) end
            end
            wasPaused, wasBig = paused, big
        end
    end
end)

-- Pose immédiate au démarrage (sans attendre le serveur) : jamais la position par défaut de GTA
CreateThread(function()
    Wait(500)
    apply()
end)
AddEventHandler('playerSpawned', function() SetTimeout(1000, apply) end)

-- Le changement de résolution déplace la mini-carte : on la repose de temps en temps
CreateThread(function()
    local lastRes = nil
    while true do
        local rx, ry = GetActiveScreenResolution()
        local res = rx .. 'x' .. ry
        if res ~= lastRes then lastRes = res apply() end
        Wait(5000)
    end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('adminmenu:map:request') end
end)
RegisterNetEvent('elyzea:client:playerLoaded', function()
    enforce()
    SetTimeout(2000, function() TriggerServerEvent('adminmenu:map:request') end)
end)

-- ---------------------------------------------------------
--  Aperçu en direct pour le staff (onglet Carte)
-- ---------------------------------------------------------
RegisterNUICallback('minimap_preview', function(body, cb)
    cb('ok')
    if type(body) ~= 'table' then return end
    preview = body
    CreateThread(apply)
end)

RegisterNUICallback('minimap_preview_end', function(_, cb)
    cb('ok')
    preview = nil
    CreateThread(apply)
end)

-- Ressource arrêtée : on rend à GTA son masque d'origine
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and maskOn then RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm') end
end)
