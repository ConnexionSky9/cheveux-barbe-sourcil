-- Studio photo : enchaîne modèles et coloris, capture l'écran, envoie l'image au serveur.
local CAT = {}
for _, c in ipairs(Config.Categories) do CAT[c.id] = c end

local running, stopAsked = false, false
local cam, backdrop
local pending, nextId = {}, 0

local function notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

local function sexOf(ped)
    local m = GetEntityModel(ped)
    if m == `mp_m_freemode_01` then return 'male' end
    if m == `mp_f_freemode_01` then return 'female' end
end

-- ───────── Tenue : sauvegarde / application ─────────

local function snapshot(ped)
    local s = { comp = {}, prop = {} }
    for i = 0, 11 do s.comp[i] = { GetPedDrawableVariation(ped, i), GetPedTextureVariation(ped, i) } end
    for i = 0, 7 do s.prop[i] = { GetPedPropIndex(ped, i), GetPedPropTextureIndex(ped, i) } end
    return s
end

local function restore(ped, s)
    for i = 0, 11 do SetPedComponentVariation(ped, i, s.comp[i][1], s.comp[i][2], 0) end
    for i = 0, 7 do
        if s.prop[i][1] < 0 then ClearPedProp(ped, i) else SetPedPropIndex(ped, i, s.prop[i][1], math.max(0, s.prop[i][2]), true) end
    end
end

-- Applique un vêtement en attendant que le jeu ait chargé le modèle (sinon photo vide)
local function wear(ped, c, d, t)
    local limit = GetGameTimer() + 3000
    if c.type == 'prop' then
        if d < 0 then ClearPedProp(ped, c.index) return end
        SetPedPreloadPropData(ped, c.index, d, t)
        while not HasPedPreloadPropDataFinished(ped) and GetGameTimer() < limit do Wait(0) end
        SetPedPropIndex(ped, c.index, d, t, true)
        ReleasePedPreloadPropData(ped)
    else
        SetPedPreloadVariationData(ped, c.index, d, t)
        while not HasPedPreloadVariationDataFinished(ped) and GetGameTimer() < limit do Wait(0) end
        SetPedComponentVariation(ped, c.index, d, t, 0)
        ReleasePedPreloadVariationData(ped)
    end
end

local function nakedFor(ped, sex, id)
    local c, n = CAT[id], Config.Naked[sex] and Config.Naked[sex][id]
    if c and n then wear(ped, c, n[1], n[2]) end
end

-- ───────── Caméra et fond vert ─────────

local function rotate(v, deg)
    local r = math.rad(deg)
    return vector3(v.x * math.cos(r) - v.y * math.sin(r), v.x * math.sin(r) + v.y * math.cos(r), 0.0)
end

local function frame(ped, view)
    local fwd = GetEntityForwardVector(ped)
    local dir = rotate(vector3(fwd.x, fwd.y, 0.0), view.side or 0)
    local target = GetPedBoneCoords(ped, view.bone, 0.0, 0.0, 0.0) + vector3(0.0, 0.0, view.dz or 0.0)
    local pos = target + dir * view.dist
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamFov(cam, view.fov or 40.0)
    local center = target - dir * 1.2
    local right = vector3(-dir.y, dir.x, 0.0)
    backdrop = { center = center, right = right * 2.5, up = vector3(0.0, 0.0, 2.5), light = target + dir * 0.8 }
end

local function studioThread()
    CreateThread(function()
        while running do
            if backdrop then
                local c, r, u = backdrop.center, backdrop.right, backdrop.up
                local a, b, cc, d = c - r - u, c + r - u, c + r + u, c - r + u
                for _, tri in ipairs({ { a, b, cc }, { a, cc, d }, { cc, b, a }, { d, cc, a } }) do
                    DrawPoly(tri[1].x, tri[1].y, tri[1].z, tri[2].x, tri[2].y, tri[2].z, tri[3].x, tri[3].y, tri[3].z, 0, 255, 0, 255)
                end
                local l = backdrop.light
                DrawLightWithRange(l.x, l.y, l.z + 0.4, 255, 255, 255, 3.0, 1.4)
            end
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
end

-- ───────── Capture ─────────

RegisterNUICallback('processed', function(data, cb)
    cb('ok')
    local p = data and pending[data.id]
    if p then pending[data.id] = nil p:resolve(data.data or '') end
end)

local function capture()
    local shot = promise.new()
    exports['screenshot-basic']:requestScreenshot({ encoding = 'png' }, function(uri) shot:resolve(uri) end)
    local uri = Citizen.Await(shot)
    if type(uri) ~= 'string' or uri == '' then return nil end
    nextId = nextId + 1
    local id, p = nextId, promise.new()
    pending[id] = p
    SendNUIMessage({ action = 'process', id = id, data = uri, size = PhotoConfig.Size, quality = PhotoConfig.Quality })
    SetTimeout(5000, function() if pending[id] then pending[id] = nil p:resolve('') end end)
    local b64 = Citizen.Await(p)
    return b64 ~= '' and b64 or nil
end

local missingReply
RegisterNetEvent('elyzea_photos:missing', function(list) if missingReply then missingReply:resolve(list) end end)

local function askMissing(paths)
    missingReply = promise.new()
    TriggerLatentServerEvent('elyzea_photos:check', 200000, paths)
    local list = Citizen.Await(missingReply)
    missingReply = nil
    return list or {}
end

RegisterNetEvent('elyzea_photos:start', function(cats, allTextures, overwrite)
    if running then return notify('Une séance photo est déjà en cours.') end
    local ped = PlayerPedId()
    local sex = sexOf(ped)
    if not sex then return notify('Utilise un personnage freemode (homme ou femme).') end

    running, stopAsked = true, false
    local saved, origin, heading = snapshot(ped), GetEntityCoords(ped), GetEntityHeading(ped)
    local st = PhotoConfig.Studio
    SetEntityCoords(ped, st.x, st.y, st.z, false, false, false, false)
    SetEntityHeading(ped, st.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    ClearPedTasksImmediately(ped)
    NetworkOverrideClockTime(12, 0, 0)
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, true, true)
    studioThread()
    Wait(1500)

    local done, total = 0, 0
    for _, id in ipairs(cats) do
        local c, view = CAT[id], PhotoConfig.Views[id]
        if stopAsked then break end
        if c and view then
            restore(ped, saved)
            for _, other in ipairs(PhotoConfig.Isolate[id] or {}) do nakedFor(ped, sex, other) end

            -- Liste des images à produire pour ce rayon
            local count = c.type == 'prop' and GetNumberOfPedPropDrawableVariations(ped, c.index) or GetNumberOfPedDrawableVariations(ped, c.index)
            local naked = Config.Naked[sex] and Config.Naked[sex][id]
            local paths, where = {}, {}
            for d = 0, count - 1 do
                if not (naked and c.type ~= 'prop' and d == naked[1]) then
                    local nt = 1
                    if allTextures then
                        nt = c.type == 'prop' and GetNumberOfPedPropTextureVariations(ped, c.index, d) or GetNumberOfPedTextureVariations(ped, c.index, d)
                    end
                    for t = 0, math.max(1, nt) - 1 do
                        -- Même nommage que la boutique (dossier du pack pour un vêtement de pack)
                        local ok, path = pcall(function() return exports.elyzea_clothing:ImagePath(sex, id, d, t) end)
                        path = ok and path or ('%s/%s/%d_%d.webp'):format(sex, id, d, t)
                        paths[#paths + 1] = path
                        where[path] = { d, t }
                    end
                end
            end
            if not overwrite then paths = askMissing(paths) end
            total = total + #paths
            notify(('Rayon %s : %d image(s) à faire.'):format(c.label, #paths))

            for _, path in ipairs(paths) do
                if stopAsked then break end
                local d, t = table.unpack(where[path])
                wear(ped, c, d, t)
                frame(ped, view)
                Wait(PhotoConfig.Delay)
                local b64 = capture()
                if b64 then
                    TriggerLatentServerEvent('elyzea_photos:save', 100000, path, b64)
                    done = done + 1
                end
                if done % 25 == 0 and done > 0 then
                    BeginTextCommandPrint('STRING')
                    AddTextComponentSubstringPlayerName(('Studio photo : %d / %d'):format(done, total))
                    EndTextCommandPrint(1500, true)
                end
            end
        end
    end

    -- Fin : tout remettre comme avant
    backdrop = nil
    running = false
    RenderScriptCams(false, false, 0, true, true)
    if cam then DestroyCam(cam, false) cam = nil end
    restore(ped, saved)
    SetEntityCoords(ped, origin.x, origin.y, origin.z, false, false, false, false)
    SetEntityHeading(ped, heading)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    NetworkClearClockTimeOverride()
    TriggerServerEvent('elyzea_photos:finished', done)
    notify(('Studio photo terminé : %d image(s). Faites « restart elyzea_clothing ».'):format(done))
end)

RegisterNetEvent('elyzea_photos:stop', function() if running then stopAsked = true notify('Arrêt après l\'image en cours…') end end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and running then
        RenderScriptCams(false, false, 0, true, true)
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)
