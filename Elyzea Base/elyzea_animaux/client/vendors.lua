-- =========================================================
--  ELYZEA ANIMAUX - CLIENT : vendeurs PNJ et aperçu
--  PNJ locaux (un par vendeur, recréés seulement s'ils manquent :
--  jamais en double après un redémarrage), invincibles et figés.
--  L'aperçu est un vrai animal local avec le pelage choisi :
--  ce que l'on voit est exactement ce que l'on achète.
-- =========================================================
local peds, blips = {}, {}
local current = nil          -- vendeur à portée
local textShown = false     -- texte « [E] … » affiché (libellé du vendeur)
local shopVendor = nil
local preview = { ped = nil, cam = nil, model = nil, heading = 0.0 }

local function removeVendor(id)
    if peds[id] and DoesEntityExist(peds[id]) then DeleteEntity(peds[id]) end
    peds[id] = nil
end

local function clearBlips()
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
end

local function vendorById(id) for _, v in ipairs(C.World.vendors or {}) do if v.id == id then return v end end end

function C.OnVendors()
    -- vendeurs supprimés ou modifiés : PNJ recréés avec les nouveaux réglages
    for id, ped in pairs(peds) do
        local v = vendorById(id)
        if not v or not DoesEntityExist(ped) or GetEntityModel(ped) ~= joaat(v.model)
            or #(GetEntityCoords(ped) - vector3(v.x, v.y, GetEntityCoords(ped).z)) > 0.5 or math.abs(((GetEntityHeading(ped) - v.h + 180) % 360) - 180) > 2.0 then
            removeVendor(id)
        end
    end
    clearBlips()
    for _, v in ipairs(C.World.vendors or {}) do
        if v.blip and v.blip.enabled then
            local b = AddBlipForCoord(v.x, v.y, v.z)
            SetBlipSprite(b, v.blip.sprite)
            SetBlipColour(b, v.blip.color)
            SetBlipScale(b, 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(v.label)
            EndTextCommandSetBlipName(b)
            blips[v.id] = b
        end
    end
end

local function spawnVendor(v)
    local hash = C.LoadModel(v.model)
    if not hash then
        C.Issue('model', 'Vendeur ' .. v.id .. ' : modèle ' .. v.model .. ' introuvable')
        hash = C.LoadModel('a_m_y_hipster_01')
        if not hash then return end
    end
    local z = C.Ground(v.x, v.y, v.z) or v.z
    local ped = CreatePed(4, hash, v.x, v.y, z, v.h, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    SetEntityHeading(ped, v.h)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedDiesWhenInjured(ped, false)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    if v.scenario and v.scenario ~= '' then TaskStartScenarioInPlace(ped, v.scenario, 0, true) end
    peds[v.id] = ped
end

CreateThread(function()
    while true do
        local wait = 1000
        local pos = GetEntityCoords(PlayerPedId())
        local best, bestD = nil, 1e9
        for _, v in ipairs(C.World.vendors or {}) do
            local d = #(pos - vector3(v.x, v.y, v.z))
            if d < 70.0 then
                if not peds[v.id] or not DoesEntityExist(peds[v.id]) then spawnVendor(v) end
            elseif peds[v.id] and d > 90.0 then
                removeVendor(v.id)
            end
            if d < bestD then best, bestD = v, d end
        end
        current = (best and bestD <= best.distance + 0.5) and best or nil
        if current and not C.ui and not IsPedInAnyVehicle(PlayerPedId(), false) then
            wait = 0
            if textShown ~= current.label then textShown = current.label Ely.showTextUI(('[E] %s'):format(current.label)) end
            if IsControlJustReleased(0, 38) then
                textShown = false
                Ely.hideTextUI()
                C.OpenShop(current)
            end
        elseif textShown then
            textShown = false
            Ely.hideTextUI()
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(peds) do removeVendor(id) end
    clearBlips()
    if C.EndPreview then C.EndPreview() end
    Ely.hideTextUI()
end)

-- ---------------------------------------------------------
--  Aperçu
-- ---------------------------------------------------------
local function previewSpot(v)
    local o = Config.PreviewOffset
    local h = math.rad(v.h)
    local x = v.x + (o[1] * math.cos(h) - o[2] * math.sin(h))
    local y = v.y + (o[1] * math.sin(h) + o[2] * math.cos(h))
    local z = C.Ground(x, y, v.z) or v.z
    return vector3(x, y, z)
end

local function placeCam(spot, ped)
    local me = GetEntityCoords(PlayerPedId())
    local dir = vector3(me.x - spot.x, me.y - spot.y, 0.0)
    local len = #dir
    dir = len > 0.1 and dir / len or vector3(1.0, 0.0, 0.0)
    local _, maxDim = GetModelDimensions(GetEntityModel(ped))
    local size = math.max(0.4, maxDim and math.max(maxDim.x, maxDim.y, maxDim.z) or 0.6)
    local dist = 1.2 + size * 2.4
    local camPos = spot + dir * dist + vector3(0.0, 0.0, 0.35 + size * 0.6)
    if not preview.cam then
        preview.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        RenderScriptCams(true, true, 500, true, false)
    end
    SetCamCoord(preview.cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(preview.cam, spot.x, spot.y, spot.z + size * 0.45)
    SetCamFov(preview.cam, 45.0)
    preview.face = math.deg(math.atan(dir.y, dir.x)) - 90.0
end

function C.ShowPreview(spot, v, label)
    if preview.ped and DoesEntityExist(preview.ped) and preview.model == v.model then
        SetPedComponentVariation(preview.ped, v.c or 0, v.d or 0, v.t or 0, 0)
        return true
    end
    if preview.ped and DoesEntityExist(preview.ped) then DeleteEntity(preview.ped) end
    preview.ped = nil
    preview.token = (preview.token or 0) + 1
    local mine, tk = preview, preview.token   -- aperçu demandé pendant ce chargement, ou boutique fermée : on abandonne
    local hash = C.LoadModel(v.model)
    if not hash then C.Issue('model', 'Aperçu : modèle ' .. v.model .. ' introuvable') return false end
    if preview ~= mine or preview.token ~= tk then SetModelAsNoLongerNeeded(hash) return false end
    local ped = CreatePed(28, hash, spot.x, spot.y, spot.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return false end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedComponentVariation(ped, v.c or 0, v.d or 0, v.t or 0, 0)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    preview.ped, preview.model = ped, v.model
    placeCam(spot, ped)
    preview.heading = preview.face or 0.0
    SetEntityHeading(ped, preview.heading)
    return true
end

function C.EndPreview()
    if preview.ped and DoesEntityExist(preview.ped) then DeleteEntity(preview.ped) end
    if preview.cam then
        RenderScriptCams(false, true, 400, true, false)
        DestroyCam(preview.cam, false)
    end
    preview = { ped = nil, cam = nil, model = nil, heading = 0.0 }
    shopVendor = nil
end

-- ---------------------------------------------------------
--  Boutique
-- ---------------------------------------------------------
local function filterCatalog(d)
    for _, sp in ipairs(d.catalog or {}) do
        local keep = {}
        for _, v in ipairs(sp.variants) do
            if C.VariantExists(v) then keep[#keep + 1] = v else C.Issue('texture', ('%s · %s (%s c%d d%d t%d) absent'):format(sp.id, v.id, v.model, v.c, v.d, v.t)) end
        end
        sp.variants = keep
    end
    local list = {}
    for _, sp in ipairs(d.catalog or {}) do if #sp.variants > 0 then list[#list + 1] = sp end end
    d.catalog = list
    return d
end

function C.OpenShop(v)
    if C.ui then return end
    local d, err = Ely.callback.await('elyzea_animaux:shop', false, v.id)
    if type(d) ~= 'table' then return C.Notify(err or 'Ce vendeur ne répond pas.', 'error') end
    shopVendor = v
    C.OpenUI('shop', { loading = true, vendor = d.vendor })
    filterCatalog(d)
    if C.ui ~= 'shop' then return end
    SendNUIMessage({ action = 'update', view = 'shop', data = d })
end

RegisterNUICallback('shop', function(body, cb)
    local v = shopVendor
    if not v then return cb({ ok = false }) end
    local a = body.action
    if a == 'preview' then
        cb({})
        if type(body.variant) == 'table' and type(body.variant.model) == 'string' then
            CreateThread(function() C.ShowPreview(previewSpot(v), body.variant) end)
        end
    elseif a == 'rotate' then
        cb({})
        if preview.ped and DoesEntityExist(preview.ped) then
            preview.heading = (preview.heading + (tonumber(body.deg) or 0)) % 360
            SetEntityHeading(preview.ped, preview.heading)
        end
    elseif a == 'hidePreview' then
        cb({})
        if preview.ped and DoesEntityExist(preview.ped) then DeleteEntity(preview.ped) end
        preview.ped, preview.model = nil, nil
    elseif a == 'buy' then
        local ok, msg = Ely.callback.await('elyzea_animaux:buy', false, { vendor = v.id, species = body.species, variant = body.variant,
            name = body.name, pay = body.pay, expected = body.expected })
        cb({ ok = ok == true, msg = msg })
        if msg then C.Notify(msg, ok and 'success' or 'error') end
    elseif a == 'buyItem' then
        local ok, msg = Ely.callback.await('elyzea_animaux:buyItem', false, { vendor = v.id, kind = body.kind, style = body.style, color = body.color,
            qty = body.qty, pay = body.pay, expected = body.expected })
        cb({ ok = ok == true, msg = msg })
        if msg then C.Notify(msg, ok and 'success' or 'error') end
    elseif a == 'vet' then
        local ok, msg = Ely.callback.await('elyzea_animaux:vet', false, { vendor = v.id, pet = body.pet, pay = body.pay, expected = body.expected })
        cb({ ok = ok == true, msg = msg })
        if msg then C.Notify(msg, ok and 'success' or 'error') end
    elseif a == 'reload' then
        local d = Ely.callback.await('elyzea_animaux:shop', false, v.id)
        if type(d) == 'table' then filterCatalog(d) cb({ ok = true, data = d }) else cb({ ok = false }) end
    else
        cb({})
    end
end)

-- Rien ne reste à l'écran si on s'éloigne / meurt pendant l'achat
CreateThread(function()
    while true do
        Wait(500)
        if C.ui == 'shop' and shopVendor then
            local d = #(GetEntityCoords(PlayerPedId()) - vector3(shopVendor.x, shopVendor.y, shopVendor.z))
            if d > shopVendor.distance + 6.0 or IsEntityDead(PlayerPedId()) then C.CloseUI() end
        end
    end
end)

-- ---------------------------------------------------------
--  Aperçu staff (menu admin › Catalogue › Aperçu) : 20 s devant soi
-- ---------------------------------------------------------
local staffPreview = nil
RegisterNetEvent('elyzea_animaux:client:adminPreview', function(v)
    if type(v) ~= 'table' or type(v.model) ~= 'string' then return end
    CreateThread(function()
        if staffPreview and DoesEntityExist(staffPreview) then DeleteEntity(staffPreview) end
        local hash = C.LoadModel(v.model)
        if not hash then return C.Notify('Modèle ' .. v.model .. ' introuvable sur ton client.', 'error') end
        local me = PlayerPedId()
        local p = GetOffsetFromEntityInWorldCoords(me, 0.0, 2.5, 0.0)
        local z = C.Ground(p.x, p.y, p.z) or (p.z - 1.0)
        local ped = CreatePed(28, hash, p.x, p.y, z, GetEntityHeading(me) + 180.0, false, false)
        SetModelAsNoLongerNeeded(hash)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetPedComponentVariation(ped, v.c or 0, v.d or 0, v.t or 0, 0)
        staffPreview = ped
        local real = GetPedTextureVariation(ped, v.c or 0)
        C.Notify(('Aperçu : %s (texture appliquée %d) devant toi pendant 20 s. Ferme le menu pour le voir.'):format(v.label or v.model, real), 'inform')
        local t = GetGameTimer() + 20000
        while GetGameTimer() < t and DoesEntityExist(ped) do Wait(500) end
        if DoesEntityExist(ped) then DeleteEntity(ped) end
        if staffPreview == ped then staffPreview = nil end
    end)
end)
