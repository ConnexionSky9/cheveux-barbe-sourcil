-- =========================================================
--  ÉDITEUR DE MAP - IMAGES DES PROPS (photos prises EN JEU)
--  Au survol d'un prop du catalogue, l'aperçu cherche dans l'ordre :
--    1. l'image déjà enregistrée sur le serveur (html/props/<modèle>.webp, ou envoyée par le serveur) ;
--    2. sinon une PHOTO prise tout de suite en jeu : le prop est posé dans un studio (fond vert
--       au-dessus du joueur), cadré selon sa taille, photographié (screencapture / screenshot-basic),
--       détouré, puis enregistré sur le serveur pour tout le monde.
--  « Générer les images manquantes » fait la même chose pour tout le catalogue d'un coup.
--  Le joueur ne bouge pas ; la photo dure moins d'une seconde.
-- =========================================================
local cache = {}            -- [modèle] = 'data:image/webp;base64,…' | false (introuvable)
local busy = false
local pendingProcess, pendingServer = {}, {}
local seq = 0
local batch = nil

local function captureRes()
    for _, r in ipairs({ 'screenshot-basic', 'screencapture' }) do
        if GetResourceState(r) == 'started' then return r end
    end
end

-- Image déjà gardée par le serveur ?
local function askServer(model)
    seq = seq + 1
    local id, p = seq, promise.new()
    pendingServer[id] = p
    TriggerServerEvent('adminmenu:propPhotoGet', id, model)
    SetTimeout(6000, function() if pendingServer[id] then pendingServer[id] = nil p:resolve(false) end end)
    return Citizen.Await(p)
end
RegisterNetEvent('adminmenu:propPhotoData', function(id, b64)
    local p = pendingServer[id]
    if p then pendingServer[id] = nil p:resolve(b64 or false) end
end)

RegisterNUICallback('ppProcessed', function(data, cb)
    cb('ok')
    local p = data and pendingProcess[data.id]
    if p then pendingProcess[data.id] = nil p:resolve(data.data or '') end
end)

-- ---------------------------------------------------------- studio
local function shoot(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil, 'modèle inconnu' end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(hash) then return nil, 'modèle non chargé' end

    -- Studio au-dessus du joueur (zone déjà chargée), loin de tout décor
    local base = GetEntityCoords(PlayerPedId()) + vector3(0.0, 0.0, 220.0)
    local obj = CreateObjectNoOffset(hash, base.x, base.y, base.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetEntityRotation(obj, 0.0, 0.0, 0.0, 2, true)
    local mn, mx = GetModelDimensions(hash)
    local size = mx - mn
    local center = GetOffsetFromEntityInWorldCoords(obj, (mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
    local radius = math.max(0.25, #size / 2)
    local fov = 40.0
    local dist = radius / math.tan(math.rad(fov / 2)) * 1.15
    -- Vue de trois quarts, légèrement plongeante
    local yaw, pitch = math.rad(35.0), math.rad(-18.0)
    local dir = vector3(math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), -math.sin(pitch))
    local camPos = center + dir * dist
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, center.x, center.y, center.z)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, true)
    SetFocusPosAndVel(center.x, center.y, center.z, 0.0, 0.0, 0.0)

    -- Fond vert derrière l'objet (assez grand pour remplir l'image), lumière blanche
    local back = center - dir * (radius * 2.0)
    local span = (dist + radius * 2.0) * math.tan(math.rad(fov / 2)) * 2.4
    local right = vector3(-dir.y, dir.x, 0.0)
    right = right / math.max(0.0001, #right)
    local up = vector3(dir.y * right.z - dir.z * right.y, dir.z * right.x - dir.x * right.z, dir.x * right.y - dir.y * right.x)
    local r, u = right * span, up * span
    local quad = { back - r - u, back + r - u, back + r + u, back - r + u }
    local drawing = true
    CreateThread(function()
        while drawing do
            local a, b, c, d = quad[1], quad[2], quad[3], quad[4]
            for _, tri in ipairs({ { a, b, c }, { a, c, d }, { c, b, a }, { d, c, a } }) do
                DrawPoly(tri[1].x, tri[1].y, tri[1].z, tri[2].x, tri[2].y, tri[2].z, tri[3].x, tri[3].y, tri[3].z, 0, 255, 0, 255)
            end
            DrawLightWithRange(camPos.x, camPos.y, camPos.z + radius, 255, 255, 255, radius * 6.0 + 4.0, 2.2)
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)
    Wait(350)   -- textures et LOD chargés

    local shot = promise.new()
    local ok = pcall(function()
        exports['screenshot-basic']:requestScreenshot({ encoding = 'png' }, function(uri) if shot.state == 0 then shot:resolve(uri) end end)
    end)
    if ok then SetTimeout(8000, function() if shot.state == 0 then shot:resolve(false) end end) else shot:resolve(false) end
    local uri = Citizen.Await(shot)

    drawing = false
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    ClearFocus()
    if DoesEntityExist(obj) then DeleteEntity(obj) end
    if type(uri) ~= 'string' or uri == '' then return nil, 'capture impossible' end

    -- Détourage + recadrage carré + webp (html/propphotos.js)
    seq = seq + 1
    local id, p = seq, promise.new()
    pendingProcess[id] = p
    SendNUIMessage({ action = 'ppProcess', id = id, data = uri, size = 256, quality = 0.86 })
    SetTimeout(5000, function() if pendingProcess[id] then pendingProcess[id] = nil p:resolve('') end end)
    local b64 = Citizen.Await(p)
    if b64 == '' then return nil, 'traitement de l\'image' end
    return b64
end

-- Image d'un prop (serveur, sinon photo prise maintenant si on a le droit de placer des props)
local function photo(model, allowShoot)
    if cache[model] ~= nil then return cache[model] end
    local b64 = askServer(model)
    if b64 and b64 ~= '' then
        cache[model] = 'data:image/webp;base64,' .. b64
        return cache[model]
    end
    if not allowShoot or not captureRes() or not (HasPerm and HasPerm('editor_props')) then return false end
    local img, why = shoot(model)
    if not img then
        if why == 'modèle inconnu' then cache[model] = false end
        return false, why
    end
    TriggerLatentServerEvent('adminmenu:propPhotoSave', 200000, model, img)
    cache[model] = 'data:image/webp;base64,' .. img
    return cache[model]
end

RegisterNUICallback('propThumb', function(data, cb)
    local model = tostring(data and data.model or ''):lower():gsub('[^%w_%-]', '')
    if model == '' then return cb({}) end
    if cache[model] ~= nil then return cb({ src = cache[model] or nil }) end
    if busy or batch then return cb({ busy = true }) end
    busy = true
    local src, why = photo(model, true)
    busy = false
    cb({ src = src or nil, error = why, noCapture = not captureRes() })
end)

-- Toutes les images manquantes du catalogue (le serveur dit lesquelles manquent)
local missingReply
RegisterNetEvent('adminmenu:propPhotoMissing', function(list) if missingReply then missingReply:resolve(list) end end)
RegisterNUICallback('propThumbAll', function(data, cb)
    cb({})
    if batch or busy then return Notify('Une génération est déjà en cours.', 'error') end
    if not captureRes() then return Notify('Installe et démarre screencapture (ou screenshot-basic) pour prendre les photos des props.', 'error') end
    local models = type(data.models) == 'table' and data.models or {}
    CreateThread(function()
        missingReply = promise.new()
        TriggerLatentServerEvent('adminmenu:propPhotoCheck', 200000, models)
        SetTimeout(15000, function() if missingReply and missingReply.state == 0 then missingReply:resolve({}) end end)
        local list = Citizen.Await(missingReply) or {}
        missingReply = nil
        batch = { total = #list, done = 0, stop = false }
        Notify(('%d image(s) de props à créer. /propphotos_stop pour arrêter.'):format(#list), 'info')
        local fails = 0
        for _, m in ipairs(list) do
            if batch.stop then break end
            local img = shoot(m)
            if img then
                fails = 0
                TriggerLatentServerEvent('adminmenu:propPhotoSave', 200000, m, img)
                cache[m] = 'data:image/webp;base64,' .. img
                batch.done = batch.done + 1
                SendNUIMessage({ action = 'ppProgress', done = batch.done, total = batch.total })
            else
                fails = fails + 1
                if fails >= 5 then Notify('La capture ne répond pas : génération arrêtée.', 'error') break end
            end
            Wait(60)
        end
        Notify(('Images des props : %d créée(s).'):format(batch.done), 'success')
        SendNUIMessage({ action = 'ppProgress', done = batch.done, total = batch.total, finished = true })
        batch = nil
    end)
end)
RegisterCommand('propphotos_stop', function() if batch then batch.stop = true end end, false)
