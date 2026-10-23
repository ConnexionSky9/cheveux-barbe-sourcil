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
-- La mini-carte est fixée par le code (Config.Minimap) : aucun réglage du menu, aucun aperçu,
-- aucun autre script ne peut la déplacer.
local function current() return Config.Minimap end

-- Masque de la mini-carte : celui de GTA a des bords flous et laisse des bandes noires sur les côtés.
-- On le remplace par un masque net (minimap/radarmask.png) : la carte remplit exactement son rectangle.
local maskTxd, maskOn = nil, false
local function SharpMask(on)
    -- Carte rectangulaire : masque carré (minimap/radarmask.png) à la place du masque arrondi / flou de GTA.
    -- Config.Minimap.sharpMask = false pour garder celui de GTA.
    if Config.Minimap and Config.Minimap.sharpMask == false then on = false end
    if on == maskOn then return end
    if on then
        if not maskTxd then
            maskTxd = CreateRuntimeTxd('elyzea_minimap')
            CreateRuntimeTextureFromImage(maskTxd, 'radarmasksm', 'minimap/radarmask.png')
        end
        -- Texture réellement chargée ? Sinon on garde le masque de GTA (sinon la carte n'est plus découpée)
        local res = GetTextureResolution('elyzea_minimap', 'radarmasksm')
        if not res or res.x < 8 then return end
        -- Seulement le masque de la PETITE carte : celui de la grande carte (radarmask1g) reste celui de GTA,
        -- sinon la grande carte n'est plus découpée et couvre la moitié de l'écran.
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'elyzea_minimap', 'radarmasksm')
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmask1g')
    else
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmask1g')
    end
    maskOn = on
end


-- =========================================================
--  MODE « CARTE D'ORIGINE » (par défaut) : la mini-carte de GTA n'est pas déplacée ni
--  redécoupée (c'est ce qui la faisait déborder ou s'agrandir à la connexion). On calcule
--  seulement l'endroit exact où GTA la dessine, pour y caler le cadre du HUD.
--  Config.Minimap.native = false : ancien mode (carte rectangulaire déplacée).
-- =========================================================
local NATIVE = not (Config.Minimap and Config.Minimap.native == false)
-- Rectangle de la mini-carte de GTA (formule standard, suit la zone de sécurité et le format d'écran)
local function NativeRect()
    local safe = GetSafeZoneSize()
    local rx, ry = GetActiveScreenResolution()
    rx, ry = math.max(rx, 1), math.max(ry, 1)
    local aspect = GetAspectRatio(false)
    if not aspect or aspect <= 0 then aspect = rx / ry end
    local margin = (1.0 / 20.0) * (math.abs(safe - 1.0) * 10)
    local w = 1.0 / (4 * aspect)
    local h = 1.0 / 5.674
    local left, bottom = margin, 1.0 - margin
    return { x = left, y = bottom - h, w = w, h = h, align = 'LB', native = true }
end
-- Position d'origine des trois éléments de la mini-carte (au cas où un ancien réglage les aurait déplacés)
local function NativeComponents()
    SetMinimapClipType(0)
    SetMinimapComponentPosition('minimap', 'L', 'B', -0.0045, 0.002, 0.150, 0.188888)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.020, 0.032, 0.111, 0.159)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.03, 0.022, 0.266, 0.237)
end

-- Rectangle réellement occupé à l'écran (fractions 0..1 depuis le coin haut gauche), pour le cadre du HUD
MinimapRect = nil
exports('GetMinimapRect', function() return MinimapRect end)

-- Disposition éprouvée de la carte rectangulaire (celle des HUD « square map ») pour une hauteur de 0,183 :
-- GTA ne place pas le masque et le flou dans le même repère que la carte : ils ont leurs propres
-- proportions. On garde exactement ces rapports, multipliés par l'échelle choisie (Config.Minimap.size).
local REF_H = 0.183
local GEO = {
    map  = { dx = 0.0,   dy = 0.0,   w = 0.1638, h = 0.183 },
    mask = { dx = 0.0,   dy = 0.047, w = 0.128,  h = 0.20 },
    blur = { dx = -0.01, dy = 0.072, w = 0.262,  h = 0.300 },
}

-- Renvoie les 3 rectangles GTA (ancrage gauche / bas) et le rectangle visible à l'écran
local function layout(s)
    local sc = (tonumber(s.size) or REF_H) / REF_H
    local rx, ry = GetActiveScreenResolution()
    local aspect = rx / math.max(ry, 1)
    local k = aspect > 16 / 9 + 0.01 and (16 / 9) / aspect or 1.0           -- repère 16:9 → écran
    local off = (1.0 - GetSafeZoneSize()) * 0.5
    local mx, my = tonumber(s.marginX) or 0.01, tonumber(s.marginY) or 0.0
    local a = ALIGN[s.position] or ALIGN['bottom-left']
    local mapW, mapH = GEO.map.w * sc, GEO.map.h * sc
    local base = -0.047 * sc - my                                           -- décalage vertical de la carte
    local bottom = 1.0 - off + base                                          -- bas visible de la carte
    if a[2] == 'T' then bottom = off + my + mapH base = bottom - (1.0 - off) end
    local left = (a[1] == 'R') and (1.0 - off - mx - mapW * k) or (off + mx * k)
    local gx = (0.5 + (left - 0.5) / k) - off                               -- gauche de la carte dans le repère GTA
    local comps = {}
    for name, g in pairs(GEO) do
        comps[name] = { gx + g.dx * sc, base + g.dy * sc, g.w * sc, g.h * sc }
    end
    return comps, { x = left, y = bottom - mapH, w = mapW * k, h = mapH, align = a[1] .. a[2], round = s.shape == 'round' }
end
function RectOf() return MinimapRect end

-- GTA ne recalcule la mini-carte qu'après un passage d'une image en grande carte.
-- JAMAIS pendant que la carte est cachée (chargement, choix du personnage) : GTA ne revient alors
-- pas à la petite carte et l'affiche agrandie à la connexion. On attend qu'elle soit dessinée.
local pendingRefresh, refreshing = false, false
local function RefreshGta()
    if IsRadarHidden() or not IsMinimapRendering() or IsPauseMenuActive() then pendingRefresh = true return end
    pendingRefresh = false
    refreshing = true
    SetBigmapActive(true, false)
    Wait(0)
    SetBigmapActive(false, false)
    refreshing = false
end

local nativeDone = false
local function place(relayout)
    local s = current()
    if not s or s.enabled == false then return end
    if NATIVE then
        SharpMask(false)
        local rect = NativeRect()
        local changed = not MinimapRect or MinimapRect.x ~= rect.x or MinimapRect.y ~= rect.y or MinimapRect.w ~= rect.w or MinimapRect.h ~= rect.h
        MinimapRect = rect
        if changed or relayout then TriggerEvent('elyzea:minimapRect', MinimapRect) end
        -- Une seule fois par session : remettre la carte à sa place d'origine si un ancien réglage l'avait déplacée
        if not nativeDone and not IsRadarHidden() and IsMinimapRendering() and not IsPauseMenuActive() then
            nativeDone = true
            NativeComponents()
            RefreshGta()
        end
        return
    end
    local comps, rect = layout(s)
    if s.shape == 'round' then
        -- carte ronde : les trois éléments sur le même carré
        local m = comps.map
        SetMinimapClipType(1)
        SharpMask(false)
        for _, n in ipairs({ 'minimap', 'minimap_mask', 'minimap_blur' }) do SetMinimapComponentPosition(n, 'L', 'B', m[1], m[2], m[3], m[4]) end
    else
        SetMinimapClipType(0)
        SharpMask(true)
        SetMinimapComponentPosition('minimap', 'L', 'B', comps.map[1], comps.map[2], comps.map[3], comps.map[4])
        SetMinimapComponentPosition('minimap_mask', 'L', 'B', comps.mask[1], comps.mask[2], comps.mask[3], comps.mask[4])
        SetMinimapComponentPosition('minimap_blur', 'L', 'B', comps.blur[1], comps.blur[2], comps.blur[3], comps.blur[4])
    end
    local changed = not MinimapRect or MinimapRect.x ~= rect.x or MinimapRect.y ~= rect.y or MinimapRect.w ~= rect.w or MinimapRect.h ~= rect.h
    MinimapRect = rect
    if changed or relayout then TriggerEvent('elyzea:minimapRect', MinimapRect) end
    if relayout then RefreshGta() end
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
    saved = data and data.minimap or saved   -- gardé pour info : la carte suit Config.Minimap
    enforce()
end)

-- ---------------------------------------------------------
--  Commandes d'autres scripts qui déplacent la mini-carte (/carte…) : neutralisées
-- ---------------------------------------------------------
local Blocked = {}   -- { command, resource }

local function blockCommands()
    if Config.Minimap.enabled == false then return end
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
        if #Blocked > 0 and not preview and not IsBigmapActive() and Config.Minimap.enabled ~= false then apply() end
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
-- On attend que GTA dessine vraiment la carte (IsMinimapRendering) : avant, la position est ignorée.
-- Puis on la repose plusieurs fois pendant 20 s (le jeu finit de charger l'interface pendant ce temps).
local function settle()
    enforceToken = enforceToken + 1
    local token = enforceToken
    CreateThread(function()
        for _, delay in ipairs({ 0, 300, 700, 1500, 2500, 4000, 7000, 12000, 20000 }) do
            Wait(delay)
            if token ~= enforceToken then return end
            if not preview and not IsBigmapActive() and not IsPauseMenuActive() and not IsRadarHidden() then apply() end
        end
    end)
end
CreateThread(function()
    local wasVisible = false
    while true do
        local visible = not IsRadarHidden() and IsMinimapRendering() and IsScreenFadedIn() and not GetIsLoadingScreenActive()
            and not IsPlayerSwitchInProgress() and not IsBigmapActive() and not IsPauseMenuActive()
        if visible and not wasVisible and not preview then settle() end
        wasVisible = visible
        Wait(visible and 1000 or 100)
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

-- Grande carte restée ouverte toute seule (bascule faite pendant le chargement, autre script) : refermée,
-- sauf si le joueur maintient lui-même la touche d'agrandissement (Z). Puis recalcul en attente.
CreateThread(function()
    while true do
        Wait(250)
        if not refreshing and IsBigmapActive() and not IsPauseMenuActive() and not IsControlPressed(0, 20) and not IsDisabledControlPressed(0, 20) then
            SetBigmapActive(false, false)
            pendingRefresh = true
        end
        if pendingRefresh and not IsRadarHidden() and IsMinimapRendering() and not IsBigmapActive() and not IsPauseMenuActive() and not preview then
            apply()
        end
    end
end)

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
RegisterNUICallback('minimap_preview', function(_, cb) cb('ok') end)   -- plus d'aperçu : carte fixée par le code

RegisterNUICallback('minimap_preview_end', function(_, cb) cb('ok') end)

-- Ressource arrêtée : on rend à GTA son masque d'origine
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and maskOn then
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmask1g')
    end
end)
