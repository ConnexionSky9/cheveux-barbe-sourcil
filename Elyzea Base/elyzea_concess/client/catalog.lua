-- =====================================================================
--  ELYZEA CONCESSION - client : catalogue (clients et employés) et offre d'achat
--  · Catalogue en lecture seule : consulter ne débite rien et ne crée aucun véhicule.
--  · Aperçu : véhicule LOCAL (hors réseau, figé, verrouillé) sur le point d'aperçu
--    de la concession, caméra orbitale (clic droit + glisser, molette). Supprimé à
--    la fermeture : jamais de clé, jamais de garage, jamais un véhicule personnel.
--  · Offre d'achat : récapitulatif, Accepter / Refuser (le serveur revérifie tout).
-- =====================================================================
local C = CDC
local cat = nil   -- { shop, preview = véhicule local, cam }

-- ---------------------------------------------------------------------
-- Aperçu du véhicule
-- ---------------------------------------------------------------------
local CAM = { cam = nil, h = 0.0, p = 12.0, d = 6.0, at = nil }
local function CamUpdate()
    if not CAM.cam or not CAM.at then return end
    local c = CAM.at + vector3(0.0, 0.0, 0.4)
    local h, p = math.rad(CAM.h), math.rad(CAM.p)
    SetCamCoord(CAM.cam, c.x - math.sin(h) * math.cos(p) * CAM.d, c.y + math.cos(h) * math.cos(p) * CAM.d, c.z + math.sin(p) * CAM.d)
    PointCamAtCoord(CAM.cam, c.x, c.y, c.z)
end
local function CamStart(veh)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    CAM.d = math.max(4.0, math.min(14.0, #(max - min) * 1.3))
    CAM.at = GetEntityCoords(veh)
    if not CAM.cam then
        CAM.h, CAM.p = GetEntityHeading(veh) + 220.0, 12.0
        CAM.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(CAM.cam, 50.0)
        CamUpdate()
        RenderScriptCams(true, true, 600, true, true)
    else
        CamUpdate()
    end
end
local function CamStop()
    if not CAM.cam then return end
    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(CAM.cam, false)
    CAM.cam, CAM.at = nil, nil
end
local function ClearPreview()
    if cat and cat.preview and DoesEntityExist(cat.preview) then DeleteEntity(cat.preview) end
    if cat then cat.preview = nil end
end

local function PreviewSpot(shopId)
    local s = C.ShopById(shopId)
    local p = s and (s.preview or s.catalog)
    if not p then return nil end
    if s.preview then return vector3(p.x, p.y, p.z), (p.h or 0.0) end
    -- Pas de point d'aperçu : devant le point de consultation
    local h = math.rad(p.h or 0.0)
    return vector3(p.x - math.sin(h) * 5.0, p.y + math.cos(h) * 5.0, p.z), (p.h or 0.0) + 180.0
end

local function ShowModel(model)
    if not cat then return { error = 'Catalogue fermé.' } end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return { error = 'Aperçu indisponible : modèle absent de votre jeu.' } end
    local pos, h = PreviewSpot(cat.shop)
    if not pos then return { error = 'Aucun point d\'aperçu dans cette concession.' } end
    RequestModel(hash)
    local t = GetGameTimer() + 6000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(20) end
    if not HasModelLoaded(hash) or not cat then return { error = 'Chargement du modèle impossible.' } end
    ClearPreview()
    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, h + 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(veh) then return { error = 'Aperçu impossible.' } end
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleUndriveable(veh, true)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, 'APERCU')
    cat.preview = veh
    CamStart(veh)
    return { ok = true }
end

-- Caractéristiques lues dans le jeu (modèle) : vitesse, accélération, freinage, adhérence, places
local function Stats(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return {} end
    return { speed = math.floor(GetVehicleModelEstimatedMaxSpeed(hash) * 3.6), accel = GetVehicleModelAcceleration(hash), brake = GetVehicleModelMaxBraking(hash),
        traction = GetVehicleModelMaxTraction(hash), seats = GetVehicleModelNumberOfSeats(hash), name = C.LabelOf(hash) }
end

-- ---------------------------------------------------------------------
-- Ouverture / fermeture
-- ---------------------------------------------------------------------
local function Close()
    if not cat then return end
    ClearPreview()
    CamStop()
    cat = nil
    C.Focus('catalog', false)
    SendNUIMessage({ action = 'catalog', show = false })
end
C.ui.catalog = { close = Close }

function C.OpenCatalog(shopId)
    if cat then return Close() end
    if C.IsDown() or IsPauseMenuActive() then return end
    local r = C.Pub('catalog', { shop = shopId })
    if r.error then return C.Notify(r.error, 'error') end
    cat = { shop = shopId }
    C.Focus('catalog', true)
    SendNUIMessage({ action = 'catalog', show = true, data = r })
    -- Fermeture si le joueur s'éloigne beaucoup (catalogue client)
    CreateThread(function()
        local start = GetEntityCoords(PlayerPedId())
        while cat and cat.shop == shopId do
            Wait(500)
            if #(GetEntityCoords(PlayerPedId()) - start) > 25.0 or IsEntityDead(PlayerPedId()) then Close() end
        end
    end)
end
RegisterNetEvent('concess:client:openCatalog', function(shopId) if not cat then C.OpenCatalog(shopId) end end)

RegisterNUICallback('catPreview', function(body, cb) cb(ShowModel(tostring(body.model or ''))) end)
RegisterNUICallback('catStats', function(body, cb) cb(Stats(tostring(body.model or ''))) end)
RegisterNUICallback('catPreviewOff', function(_, cb) cb({}) ClearPreview() CamStop() end)
RegisterNUICallback('catCam', function(body, cb)
    cb({})
    if not CAM.cam then return end
    CAM.h = (CAM.h - (tonumber(body.dx) or 0) * 0.35) % 360
    CAM.p = math.max(-10.0, math.min(70.0, CAM.p + (tonumber(body.dy) or 0) * 0.25))
    if tonumber(body.zoom) then CAM.d = math.max(2.5, math.min(16.0, CAM.d + tonumber(body.zoom))) end
    CamUpdate()
end)
RegisterNUICallback('catRefresh', function(_, cb)
    if not cat then return cb({ error = 'Catalogue fermé.' }) end
    cb(C.Pub('catalog', { shop = cat.shop }))
end)

-- ---------------------------------------------------------------------
-- Offre d'achat reçue (client)
-- ---------------------------------------------------------------------
local offer = nil
local function EndOffer()
    if not offer then return end
    offer = nil
    C.Focus('saleOffer', false)
    SendNUIMessage({ action = 'saleOffer', show = false })
end
C.ui.saleOffer = { close = function()
    if offer then TriggerServerEvent('concess:server:offerAnswer', offer.id, false) end
    EndOffer()
end }
RegisterNetEvent('concess:client:offer', function(o)
    if cat then Close() end
    offer = o
    C.Focus('saleOffer', true)
    SendNUIMessage({ action = 'saleOffer', show = true, offer = o })
    local id = o.id
    CreateThread(function()
        local untilT = GetGameTimer() + (o.timeout or 60) * 1000
        while offer and offer.id == id do
            if GetGameTimer() > untilT then EndOffer() break end
            Wait(250)
        end
    end)
end)
RegisterNetEvent('concess:client:offerClosed', function(id) if offer and offer.id == id then EndOffer() end end)
RegisterNUICallback('saleAnswer', function(body, cb)
    cb({})
    if not offer then return end
    TriggerServerEvent('concess:server:offerAnswer', offer.id, body.accept == true)
    EndOffer()
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then ClearPreview() CamStop() end end)
