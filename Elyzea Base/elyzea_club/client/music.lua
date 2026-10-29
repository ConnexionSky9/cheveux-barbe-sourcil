-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - client : enceintes, son, platine DJ, pose d'enceinte
--  · Les enceintes de chaque boîte sont affichées chez chaque joueur (objets locaux).
--  · Son : la musique d'une boîte (GlobalState.clubMusic) est jouée par la page du
--    jeu (lecteur YouTube invisible) ; le volume baisse avec la distance à l'enceinte
--    la plus proche de CETTE boîte. Tout le monde entend le même passage (heure commune).
--  · /musique 0-100 : volume personnel des boîtes de nuit.
-- =====================================================================
local C = CLC
local M = Config.Music

-- ---------------------------------------------------------------------
-- Heure commune (secondes) : heure du serveur recalée sur l'horloge réseau
-- ---------------------------------------------------------------------
local offset = 0
local function SyncClock()
    local r = C.Pub('time')
    if r.now then offset = r.now - GetCloudTimeAsInt() end
end
function C.Now() return GetCloudTimeAsInt() + offset end
CreateThread(function()
    Wait(2500)
    while true do SyncClock() Wait(600000) end
end)

-- Volume personnel
local personal = 100
CreateThread(function() personal = GetResourceKvpInt('club_volume_set') == 1 and GetResourceKvpInt('club_volume') or 100 end)
RegisterCommand('musique', function(_, args)
    local v = tonumber(args[1])
    if not v then return C.Notify(('Volume des boîtes de nuit : %d %%. Exemple : /musique 50'):format(personal), 'inform') end
    personal = math.max(0, math.min(100, math.floor(v)))
    SetResourceKvpInt('club_volume', personal)
    SetResourceKvpInt('club_volume_set', 1)
    C.Notify(('Volume des boîtes de nuit : %d %%.'):format(personal), 'success')
end, false)

-- ---------------------------------------------------------------------
-- Enceintes (objets locaux, proches seulement)
-- ---------------------------------------------------------------------
local props = {}        -- [speakerId] = entity
local wanted = {}       -- [speakerId] = speaker
local function ModelFor(name)
    if name == 'none' then return nil end
    local h = joaat(name)
    if IsModelInCdimage(h) then return h end
    local fb = joaat('prop_speaker_06')
    return IsModelInCdimage(fb) and fb or nil
end
local function Spawn(sp)
    local model = ModelFor(sp.model)
    if not model then return nil end
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(20) end
    if not HasModelLoaded(model) then return nil end
    local o = CreateObjectNoOffset(model, sp.x + 0.0, sp.y + 0.0, sp.z + 0.0, false, false, false)
    SetEntityHeading(o, sp.h + 0.0)
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    SetModelAsNoLongerNeeded(model)
    return o
end
local function Despawn(id) if props[id] and DoesEntityExist(props[id]) then DeleteEntity(props[id]) end props[id] = nil end

C.OnShops = function(shops)
    wanted = {}
    for _, s in ipairs(shops) do for _, sp in ipairs(s.speakers or {}) do sp.shop = s.id wanted[sp.id] = sp end end
    for id in pairs(props) do if not wanted[id] then Despawn(id) end end
    SendNUIMessage({ action = 'shops', shops = shops })
end
CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        for id, sp in pairs(wanted) do
            local near = #(pc - vector3(sp.x + 0.0, sp.y + 0.0, sp.z + 0.0)) < 150.0
            if near and props[id] == nil and sp.model ~= 'none' then props[id] = Spawn(sp) or false
            elseif not near and props[id] ~= nil then Despawn(id) end
        end
        Wait(2000)
    end
end)

-- ---------------------------------------------------------------------
-- Son : quelles musiques j'entends, à quel volume, à quel moment du titre
-- ---------------------------------------------------------------------
local lastSent, lastSync = '', 0
CreateThread(function()
    while true do
        Wait(250)
        local music = GlobalState.clubMusic or {}
        local cam = GetFinalRenderedCamCoord()
        local cands = {}
        for _, s in ipairs(C.shops or {}) do
            local m = music[tostring(s.id)]
            if m and s.speakers and #s.speakers > 0 then
                local best
                for _, sp in ipairs(s.speakers) do
                    local d = #(cam - vector3(sp.x + 0.0, sp.y + 0.0, sp.z + 0.0))
                    if not best or d < best then best = d end
                end
                local range = tonumber(m.range) or M.defaultRange
                if best and best <= range then
                    local fall = (1.0 - best / range) ^ 1.2
                    cands[#cands + 1] = { shop = s.id, yt = m.yt, track = m.track, paused = m.paused, d = best,
                        at = m.paused and (m.pausedAt or 0) or math.max(0, C.Now() - (m.startAt or C.Now())),
                        vol = math.floor((m.volume or 70) / 100 * personal / 100 * fall * 100 + 0.5) / 100 }
                end
            end
        end
        table.sort(cands, function(a, b) return a.d < b.d end)
        while #cands > M.maxActive do table.remove(cands) end
        -- On n'envoie que ce qui change (volume au centième), et un recalage toutes les 5 s
        local key = {}
        for _, c in ipairs(cands) do key[#key + 1] = ('%d:%s:%s:%s:%.2f'):format(c.shop, c.track, c.yt, tostring(c.paused), c.vol) end
        key = table.concat(key, '|')
        local now = GetGameTimer()
        if key ~= lastSent or now - lastSync > 5000 then
            lastSent, lastSync = key, now
            SendNUIMessage({ action = 'audio', list = cands })
        end
    end
end)

-- La page signale la durée d'un titre ou une vidéo refusée par YouTube
RegisterNUICallback('musicReport', function(body, cb)
    cb({})
    C.Pub('musicReport', { shop = tonumber(body.shop), track = tonumber(body.track), duration = tonumber(body.duration), error = tonumber(body.error) })
end)

-- ---------------------------------------------------------------------
-- Platine DJ (employés « music » de la boîte)
-- ---------------------------------------------------------------------
local djOpen = false
local function CloseDj()
    if not djOpen then return end
    djOpen = false
    C.Focus('dj', false)
    SendNUIMessage({ action = 'dj', show = false })
end
C.ui.dj = { close = CloseDj }
function C.OpenDj()
    if C.AnyOpen() then return end
    local r = C.Req('music')
    if r.error then return C.Notify(r.error, 'error') end
    djOpen = true
    C.Focus('dj', true)
    SendNUIMessage({ action = 'dj', show = true, data = r })
    TriggerEvent('club:client:status', 'dj')
end
-- Les actions de la platine passent par la requête générique « req » (main.lua)

-- ---------------------------------------------------------------------
-- Poser une enceinte (permission « speakers ») : l'objet suit le regard
-- ---------------------------------------------------------------------
local function CamRay(dist)
    local p = GetFinalRenderedCamCoord()
    local r = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(r.x), math.rad(r.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local to = p + dir * dist
    local h = StartExpensiveSynchronousShapeTestLosProbe(p.x, p.y, p.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, endPos = GetShapeTestResult(h)
    return (hit == 1 or hit == true) and endPos or nil
end

function C.PlaceSpeaker(model)
    if C.placing or C.AnyOpen() then return end
    local s = C.State()
    if not s or not (s.perms or {}).speakers then return C.Notify('Votre grade ne permet pas de poser des enceintes.', 'error') end
    local hash = ModelFor(model)
    if model ~= 'none' and not hash then return C.Notify('Ce modèle d\'enceinte n\'existe pas dans le jeu.', 'error') end
    C.placing = true
    CreateThread(function()
        local ghost
        if hash then
            RequestModel(hash)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(20) end
            ghost = CreateObjectNoOffset(hash, 0.0, 0.0, 0.0, false, false, false)
            SetEntityAlpha(ghost, 170, false)
            SetEntityCollision(ghost, false, false)
            FreezeEntityPosition(ghost, true)
        end
        local heading = GetEntityHeading(PlayerPedId()) + 180.0
        local pos
        while C.placing do
            Wait(0)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 44, true) DisableControlAction(0, 51, true)
            DisableControlAction(0, 191, true) DisableControlAction(0, 177, true) DisableControlAction(0, 200, true) DisableControlAction(0, 14, true) DisableControlAction(0, 15, true)
            local hit = CamRay(M.placeDistance)
            if hit then pos = hit end
            local fine = IsDisabledControlPressed(0, 21)
            if IsDisabledControlPressed(0, 44) then heading = heading + (fine and 0.5 or 2.0) end
            if IsDisabledControlPressed(0, 51) then heading = heading - (fine and 0.5 or 2.0) end
            if IsDisabledControlJustPressed(0, 15) then heading = heading + 15.0 end
            if IsDisabledControlJustPressed(0, 14) then heading = heading - 15.0 end
            if pos then
                if ghost then SetEntityCoordsNoOffset(ghost, pos.x, pos.y, pos.z, false, false, false) SetEntityHeading(ghost, heading % 360) end
                DrawMarker(28, pos.x, pos.y, pos.z + 0.05, 0, 0, 0, 0, 0, 0, 0.25, 0.25, 0.25, 217, 70, 239, 160, false, false, 2, false, nil, nil, false)
            end
            C.Help('~INPUT_ATTACK~ / ~INPUT_FRONTEND_ACCEPT~ Poser l\'enceinte~n~~INPUT_PICKUP~ ~INPUT_COVER~ Tourner (MAJ : précis)~n~~INPUT_FRONTEND_CANCEL~ / ~INPUT_AIM~ Annuler')
            if (IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 191)) and pos then
                local r = C.Req('speakerPlace', { model = model, x = pos.x, y = pos.y, z = pos.z, h = heading % 360 })
                C.Show(r)
                if r.ok then break end
            end
            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 25) then
                C.Notify('Pose de l\'enceinte annulée.', 'inform')
                break
            end
        end
        if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
        C.placing = false
    end)
end
RegisterNUICallback('placeSpeaker', function(body, cb)
    cb({})
    for name, ui in pairs(C.ui) do if ui.close then ui.close(true) end end
    Wait(150)
    C.PlaceSpeaker(tostring(body.model or ''))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(props) do Despawn(id) end
    C.placing = false
end)
