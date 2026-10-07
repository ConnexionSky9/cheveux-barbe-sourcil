-- =====================================================================
--  elyzea_lscustom - client : personnalisation des véhicules
-- =====================================================================
local L = LSC
local M = { veh = nil, orig = nil, origValues = {}, open = false, waiting = false }

local CAT = {}
for _, c in ipairs(Config.Catalog) do CAT[c.key] = c end

local function lightById(id) for _, c in ipairs(Config.LightColors) do if c.id == id then return c end end end

-- Couleur de lumière : id de la liste si elle correspond, sinon couleur personnalisée « rgb:r,g,b »
local function rgbMatch(r, g, b)
    for _, c in ipairs(Config.LightColors) do
        if math.abs(c.rgb[1] - r) < 6 and math.abs(c.rgb[2] - g) < 6 and math.abs(c.rgb[3] - b) < 6 then return c.id end
    end
    return ('rgb:%d,%d,%d'):format(r, g, b)
end

-- « rgb:r,g,b » ou « rgb:r,g,b:finition » -> r, g, b, finition (nil si ce n'est pas une couleur personnalisée)
local function parseRgb(v)
    local r, g, b, f = tostring(v or ''):match('^rgb:(%d+),(%d+),(%d+):?(%d*)$')
    if not r then return nil end
    local clamp = function(x) return math.max(0, math.min(255, tonumber(x))) end
    return clamp(r), clamp(g), clamp(b), tonumber(f)
end

local function useMod48(veh) return GetNumVehicleMods(veh, 48) > 0 end

-- ---------------------------------------------------------------------
-- Lecture / application d'une valeur
-- ---------------------------------------------------------------------
local function current(veh, c)
    local k = c.kind
    if k == 'mod' then return GetVehicleMod(veh, c.mod)
    elseif k == 'toggle' then return IsToggleModOn(veh, c.mod) and 1 or 0
    elseif k == 'wheels' then return ('%d:%d'):format(GetVehicleWheelType(veh), GetVehicleMod(veh, 23))
    elseif k == 'paint' then
        if c.key == 'paint1' and GetIsVehiclePrimaryColourCustom(veh) then
            local r, g, b = GetVehicleCustomPrimaryColour(veh)
            return ('rgb:%d,%d,%d:%d'):format(r, g, b, (GetVehicleModColor_1(veh)))
        elseif c.key == 'paint2' and GetIsVehicleSecondaryColourCustom(veh) then
            local r, g, b = GetVehicleCustomSecondaryColour(veh)
            return ('rgb:%d,%d,%d:%d'):format(r, g, b, (GetVehicleModColor_2(veh)))
        end
        local p, s = GetVehicleColours(veh)
        return c.key == 'paint1' and p or s
    elseif k == 'pearl' then return (GetVehicleExtraColours(veh))
    elseif k == 'wheelcolor' then return select(2, GetVehicleExtraColours(veh))
    elseif k == 'neon' then
        if not IsVehicleNeonLightEnabled(veh, 0) then return -1 end
        local fx = L.NeonFxOf(veh)
        if fx then return 'fx:' .. fx end
        return rgbMatch(GetVehicleNeonLightsColour(veh))
    elseif k == 'xenon' then
        if not IsToggleModOn(veh, 22) then return -1 end
        local x = GetVehicleXenonLightsColor(veh)
        return (x and x >= 0 and x <= 12) and x or 0
    elseif k == 'tint' then return GetVehicleWindowTint(veh)
    elseif k == 'plate' then return GetVehicleNumberPlateTextIndex(veh)
    elseif k == 'livery' then return useMod48(veh) and GetVehicleMod(veh, 48) or GetVehicleLivery(veh)
    elseif k == 'smoke' then
        if not IsToggleModOn(veh, 20) then return -1 end
        return rgbMatch(GetVehicleTyreSmokeColor(veh))
    end
end

local function apply(veh, c, v)
    SetVehicleModKit(veh, 0)
    local k = c.kind
    if k == 'mod' then
        SetVehicleMod(veh, c.mod, tonumber(v), false)
    elseif k == 'toggle' then
        ToggleVehicleMod(veh, c.mod, tonumber(v) == 1)
    elseif k == 'wheels' then
        local t, i = tostring(v):match('^(%-?%d+):(%-?%d+)$')
        t, i = tonumber(t), tonumber(i)
        if not t then return end
        SetVehicleWheelType(veh, t)
        SetVehicleMod(veh, 23, i, false)
        if IsThisModelABike(GetEntityModel(veh)) then SetVehicleMod(veh, 24, i, false) end
    elseif k == 'paint' then
        local r, g, b, finish = parseRgb(v)
        if r then
            -- Couleur libre + finition (0 normal, 1 métallisé, 2 nacré, 3 mat, 4 métal, 5 chrome)
            local pearl, wheel = GetVehicleExtraColours(veh)
            finish = math.max(0, math.min(5, finish or 1))
            if c.key == 'paint1' then
                SetVehicleModColor_1(veh, finish, 0, 0)
                SetVehicleCustomPrimaryColour(veh, r, g, b)
            else
                SetVehicleModColor_2(veh, finish, 0)
                SetVehicleCustomSecondaryColour(veh, r, g, b)
            end
            SetVehicleExtraColours(veh, pearl, wheel)
        else
            local p, s = GetVehicleColours(veh)
            if c.key == 'paint1' then ClearVehicleCustomPrimaryColour(veh) p = tonumber(v) else ClearVehicleCustomSecondaryColour(veh) s = tonumber(v) end
            SetVehicleColours(veh, p, s)
        end
    elseif k == 'pearl' then
        local _, w = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, tonumber(v), w)
    elseif k == 'wheelcolor' then
        local pe = GetVehicleExtraColours(veh)
        SetVehicleExtraColours(veh, pe, tonumber(v))
    elseif k == 'neon' then
        local fx = tostring(v):match('^fx:(%w+)$')
        local r, g, b = parseRgb(v)
        local on = fx ~= nil or r ~= nil or tonumber(v) ~= -1
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, on) end
        L.SetPreviewFx(veh, fx or false)   -- aperçu : animé, ou couleur fixe (même si le véhicule avait un effet)
        if fx then
            -- rien à poser : la couleur est animée par client/neon.lua
        elseif r then
            SetVehicleNeonLightsColour(veh, r, g, b)
        else
            local lc = on and lightById(tonumber(v))
            if lc then SetVehicleNeonLightsColour(veh, lc.rgb[1], lc.rgb[2], lc.rgb[3]) end
        end
    elseif k == 'xenon' then
        local on = tonumber(v) ~= -1
        ToggleVehicleMod(veh, 22, on)
        if on then SetVehicleXenonLightsColor(veh, tonumber(v)) end
    elseif k == 'tint' then
        SetVehicleWindowTint(veh, tonumber(v))
    elseif k == 'plate' then
        SetVehicleNumberPlateTextIndex(veh, tonumber(v))
    elseif k == 'livery' then
        if useMod48(veh) then SetVehicleMod(veh, 48, tonumber(v), false) else SetVehicleLivery(veh, tonumber(v)) end
    elseif k == 'smoke' then
        local r, g, b = parseRgb(v)
        local on = r ~= nil or tonumber(v) ~= -1
        ToggleVehicleMod(veh, 20, on)
        if r then
            SetVehicleTyreSmokeColor(veh, r, g, b)
        else
            local lc = on and lightById(tonumber(v))
            if lc then SetVehicleTyreSmokeColor(veh, lc.rgb[1], lc.rgb[2], lc.rgb[3]) end
        end
    end
end

-- ---------------------------------------------------------------------
-- Options disponibles pour une catégorie
-- ---------------------------------------------------------------------
local function modLabel(veh, c, i)
    if c.perLevel then return ('Niveau %d'):format(i + 1) end
    local txt = GetModTextLabel(veh, c.mod, i)
    local label = txt and GetLabelText(txt)
    if not label or label == 'NULL' or label == '' then label = ('%s n°%d'):format(c.label, i + 1) end
    return label
end

local function listColors(list, withOff, offLabel)
    local out = {}
    if withOff then out[#out + 1] = { value = -1, label = offLabel } end
    for _, x in ipairs(list) do out[#out + 1] = { value = x.id, label = x.type and ('%s · %s'):format(x.label, x.type) or x.label } end
    return out
end

local function options(veh, c, wheelType)
    local k = c.kind
    if k == 'mod' then
        local out = { { value = -1, label = c.perLevel and 'Origine' or 'Origine' } }
        for i = 0, GetNumVehicleMods(veh, c.mod) - 1 do out[#out + 1] = { value = i, label = modLabel(veh, c, i) } end
        return out
    elseif k == 'toggle' then
        return { { value = 0, label = 'Sans' }, { value = 1, label = 'Avec' } }
    elseif k == 'wheels' then
        local curType, curMod = GetVehicleWheelType(veh), GetVehicleMod(veh, 23)
        local t = tonumber(wheelType) or curType
        SetVehicleModKit(veh, 0)
        SetVehicleWheelType(veh, t)
        local out = { { value = ('%d:-1'):format(t), label = 'Origine' } }
        for i = 0, GetNumVehicleMods(veh, 23) - 1 do
            local txt = GetModTextLabel(veh, 23, i)
            local label = txt and GetLabelText(txt)
            if not label or label == 'NULL' then label = ('Jante n°%d'):format(i + 1) end
            out[#out + 1] = { value = ('%d:%d'):format(t, i), label = label }
        end
        SetVehicleWheelType(veh, curType)
        SetVehicleMod(veh, 23, curMod, false)
        return out, t
    elseif k == 'paint' or k == 'pearl' or k == 'wheelcolor' then
        return listColors(Config.Colors)
    elseif k == 'neon' then
        local out = listColors(Config.LightColors, true, 'Éteints')
        for i, fx in ipairs(Config.NeonEffects or {}) do table.insert(out, 1 + i, { value = 'fx:' .. fx.id, label = fx.label }) end
        return out
    elseif k == 'smoke' then
        return listColors(Config.LightColors, true, 'Aucune')
    elseif k == 'xenon' then
        return listColors(Config.XenonColors, true, 'Phares normaux')
    elseif k == 'tint' then
        return listColors(Config.Tints)
    elseif k == 'plate' then
        return listColors(Config.Plates)
    elseif k == 'livery' then
        local out = {}
        if useMod48(veh) then
            out[1] = { value = -1, label = 'Origine' }
            for i = 0, GetNumVehicleMods(veh, 48) - 1 do out[#out + 1] = { value = i, label = modLabel(veh, { mod = 48, label = 'Livrée' }, i) } end
        else
            for i = 0, GetVehicleLiveryCount(veh) - 1 do out[#out + 1] = { value = i, label = ('Livrée n°%d'):format(i + 1) } end
        end
        return out
    end
    return {}
end

local function available(veh, c)
    local k = c.kind
    if k == 'service' then return false end
    if k == 'mod' then return GetNumVehicleMods(veh, c.mod) > 0 end
    if k == 'neon' then return IsThisModelACar(GetEntityModel(veh)) end
    if k == 'livery' then return useMod48(veh) or GetVehicleLiveryCount(veh) > 0 end
    return true
end

-- ---------------------------------------------------------------------
-- Services de l'atelier (réparation, roues, nettoyage)
-- ---------------------------------------------------------------------
local WHEELS = { 0, 1, 2, 3, 4, 5, 45, 47 }

-- État du véhicule affiché en haut du menu
local function VehicleState(veh)
    local burst = 0
    for _, w in ipairs(WHEELS) do
        if IsVehicleTyreBurst(veh, w, false) then burst = burst + 1 end
    end
    return {
        engine = math.floor(math.max(0, GetVehicleEngineHealth(veh)) / 10),
        body = math.floor(math.max(0, GetVehicleBodyHealth(veh)) / 10),
        dirt = math.floor(GetVehicleDirtLevel(veh) / 15 * 100),
        tyres = burst,
    }
end

local function FixTyres(veh)
    for _, w in ipairs(WHEELS) do SetVehicleTyreFixed(veh, w) end
    for i = 0, GetVehicleNumberOfWheels(veh) - 1 do SetVehicleWheelHealth(veh, i, 1000.0) end
end

-- Appliqués seulement quand la facture est payée
local function ApplyServices(veh, services)
    if services.repair then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
        FixTyres(veh)
    end
    if services.tyres then FixTyres(veh) end
    if services.clean then
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
    end
end

-- Les propriétés enregistrées en base tiennent compte des services payés
local function PropsWithServices(props, services)
    if services.repair then
        props.bodyHealth, props.engineHealth, props.tankHealth = 1000.0, 1000.0, 1000.0
        props.tyres, props.windows, props.doors = {}, {}, {}
    end
    if services.tyres then props.tyres = {} end
    if services.clean then props.dirtLevel = 0.0 end
    return props
end

-- ---------------------------------------------------------------------
-- Ouverture / fermeture
-- ---------------------------------------------------------------------
local function Close(revert)
    if not M.open then return end
    if M.veh and DoesEntityExist(M.veh) then L.SetPreviewFx(M.veh, nil) end
    if revert and M.veh and DoesEntityExist(M.veh) and M.orig then lib.setVehicleProperties(M.veh, M.orig) end
    L.ModCam.Stop()
    if M.veh and DoesEntityExist(M.veh) then
        FreezeEntityPosition(M.veh, false)
        -- Au volant : on rallume le moteur
        if GetPedInVehicleSeat(M.veh, -1) == PlayerPedId() then SetVehicleEngineOn(M.veh, true, true, false) end
    end
    M.open, M.waiting, M.veh, M.orig, M.origValues = false, false, nil, nil, {}
    L.busy = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mods', show = false })
    TriggerServerEvent('lscustom:server:closeMods')
end

function L.StartMods()
    if M.open or L.busy then return end
    local veh = L.ClosestVehicle(5.0)
    if not veh or veh == 0 then return L.Notify('Aucun véhicule à proximité.', 'error') end
    if not L.CanModifyFrom(veh) then return end
    M.pendingVeh = veh
    TriggerServerEvent('lscustom:server:openMods', L.Plate(veh))
end

RegisterNetEvent('lscustom:client:openMods', function(prices)
    local veh = M.pendingVeh
    M.pendingVeh = nil
    if not veh or not DoesEntityExist(veh) then return TriggerServerEvent('lscustom:server:closeMods') end
    SetVehicleModKit(veh, 0)
    M.veh, M.orig, M.origValues, M.open, L.busy = veh, lib.getVehicleProperties(veh), {}, true, true
    FreezeEntityPosition(veh, true)
    SetVehicleEngineOn(veh, false, true, true)
    L.ModCam.Start(veh)
    local cats = {}
    for _, c in ipairs(Config.Catalog) do
        if available(veh, c) then cats[#cats + 1] = { key = c.key, label = c.label, group = c.group, perLevel = c.perLevel == true } end
    end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'mods', show = true, categories = cats, prices = prices, wheelTypes = Config.WheelTypes,
        vehicle = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))), plate = L.Plate(veh),
        state = VehicleState(veh),
        services = { repair = L.Can('repair'), tyres = L.Can('repair'), clean = L.Can('clean') },
    })
end)

RegisterNUICallback('modsOptions', function(body, cb)
    local c = CAT[body.key]
    if not M.open or not c then return cb({ options = {} }) end
    local cur = current(M.veh, c)
    if M.origValues[c.key] == nil then M.origValues[c.key] = cur end
    L.ModCam.View(c.key)
    local opts, wheelType = options(M.veh, c, body.wheelType)
    cb({ options = opts, current = cur, original = M.origValues[c.key], wheelType = wheelType })
end)

RegisterNUICallback('modsPreview', function(body, cb)
    local c = CAT[body.key]
    if M.open and c and not M.waiting and DoesEntityExist(M.veh) then apply(M.veh, c, body.value) end
    cb('ok')
end)

-- Caméra libre : clic droit maintenu sur le décor, molette pour zoomer
RegisterNUICallback('camFree', function(body, cb)
    if M.open then
        if body.start then L.ModCam.BeginFree() else L.ModCam.Orbit(tonumber(body.dx) or 0, tonumber(body.dy) or 0) end
    end
    cb('ok')
end)

RegisterNUICallback('camZoom', function(body, cb)
    if M.open then L.ModCam.Zoom(tonumber(body.delta) or 0) end
    cb('ok')
end)

-- Personnes autour (pour choisir le client)
RegisterNUICallback('nearbyPlayers', function(_, cb)
    local pc = GetEntityCoords(PlayerPedId())
    local list = {}
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(GetEntityCoords(GetPlayerPed(pid)) - pc)
            if d < 10.0 then list[#list + 1] = { id = GetPlayerServerId(pid), name = GetPlayerName(pid), distance = math.floor(d) } end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    cb({ players = list })
end)

RegisterNUICallback('modsInvoice', function(body, cb)
    cb('ok')
    if not M.open or M.waiting then return end
    M.waiting = true
    M.services = {}
    for _, it in ipairs(body.items or {}) do
        if it.key == 'repair' or it.key == 'tyres' or it.key == 'clean' then M.services[it.key] = true end
    end
    local props = PropsWithServices(lib.getVehicleProperties(M.veh), M.services)
    props._neonFx = IsVehicleNeonLightEnabled(M.veh, 0) and L.NeonFxOf(M.veh) or nil
    TriggerServerEvent('lscustom:server:modsInvoice', tonumber(body.target), body.items or {}, L.Plate(M.veh), props)
end)

RegisterNUICallback('modsCancel', function(_, cb)
    cb('ok')
    if M.waiting then return end
    Close(true)
end)

RegisterNetEvent('lscustom:client:invoiceResult', function(_, paid, kind)
    if kind ~= 'mods' or not M.open then return end
    if paid then
        if M.veh and DoesEntityExist(M.veh) and M.services and next(M.services) then
            ApplyServices(M.veh, M.services)
        end
        L.Notify('Travaux terminés et payés.', 'success')
        Close(false)
    else
        M.waiting = false
        SendNUIMessage({ action = 'modsRefused' })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and M.open then
        L.ModCam.Stop()
        if M.veh and DoesEntityExist(M.veh) then
            if M.orig then lib.setVehicleProperties(M.veh, M.orig) end
            FreezeEntityPosition(M.veh, false)
        end
        SetNuiFocus(false, false)
    end
end)
