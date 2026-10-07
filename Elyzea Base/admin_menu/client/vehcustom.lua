-- =========================================================
--  VÉHICULES › PERSONNALISATION (staff, gratuit, en direct)
--  Le staff est au volant : chaque choix s'applique aussitôt.
--  « Annuler mes changements » remet le véhicule comme à l'ouverture,
--  « Enregistrer » le garde sur la carte grise (player_vehicles).
-- =========================================================
local Snapshot = nil   -- { veh, props } à l'ouverture de l'onglet

-- Propriétés complètes du véhicule : fournies par la base Elyzea (elyzea_core)
local VP = {
    getVehicleProperties = function(veh) return exports.elyzea_core:GetVehicleProperties(veh) end,
    setVehicleProperties = function(veh, props) return exports.elyzea_core:SetVehicleProperties(veh, props) end,
}
local function ox()
    if GetResourceState('elyzea_core') ~= 'started' then return nil end
    return VP
end

local CATS = {
    -- Performance
    { key = 'engine', label = 'Moteur', group = 'perf', kind = 'mod', mod = 11, level = true },
    { key = 'brakes', label = 'Freins', group = 'perf', kind = 'mod', mod = 12, level = true },
    { key = 'transmission', label = 'Transmission', group = 'perf', kind = 'mod', mod = 13, level = true },
    { key = 'suspension', label = 'Suspension', group = 'perf', kind = 'mod', mod = 15, level = true },
    { key = 'armor', label = 'Blindage', group = 'perf', kind = 'mod', mod = 16, level = true },
    { key = 'turbo', label = 'Turbo', group = 'perf', kind = 'toggle', mod = 18 },
    -- Carrosserie
    { key = 'fbumper', label = 'Pare-choc avant', group = 'body', kind = 'mod', mod = 1 },
    { key = 'rbumper', label = 'Pare-choc arrière', group = 'body', kind = 'mod', mod = 2 },
    { key = 'skirts', label = 'Bas de caisse', group = 'body', kind = 'mod', mod = 3 },
    { key = 'spoiler', label = 'Aileron', group = 'body', kind = 'mod', mod = 0 },
    { key = 'hood', label = 'Capot', group = 'body', kind = 'mod', mod = 7 },
    { key = 'grille', label = 'Calandre', group = 'body', kind = 'mod', mod = 6 },
    { key = 'exhaust', label = 'Échappement', group = 'body', kind = 'mod', mod = 4 },
    { key = 'frame', label = 'Arceau', group = 'body', kind = 'mod', mod = 5 },
    { key = 'lfender', label = 'Aile gauche', group = 'body', kind = 'mod', mod = 8 },
    { key = 'rfender', label = 'Aile droite', group = 'body', kind = 'mod', mod = 9 },
    { key = 'roof', label = 'Toit', group = 'body', kind = 'mod', mod = 10 },
    { key = 'archcover', label = 'Passages de roue', group = 'body', kind = 'mod', mod = 42 },
    { key = 'aerials', label = 'Antennes', group = 'body', kind = 'mod', mod = 43 },
    { key = 'trim2', label = 'Garnitures extérieures', group = 'body', kind = 'mod', mod = 44 },
    { key = 'tank', label = 'Réservoir', group = 'body', kind = 'mod', mod = 45 },
    { key = 'windows', label = 'Fenêtres', group = 'body', kind = 'mod', mod = 46 },
    { key = 'trunk', label = 'Coffre', group = 'body', kind = 'mod', mod = 37 },
    { key = 'hydraulics', label = 'Hydraulique', group = 'body', kind = 'mod', mod = 38 },
    { key = 'engineblock', label = 'Bloc moteur', group = 'body', kind = 'mod', mod = 39 },
    { key = 'airfilter', label = 'Filtre à air', group = 'body', kind = 'mod', mod = 40 },
    { key = 'struts', label = 'Barres de renfort', group = 'body', kind = 'mod', mod = 41 },
    { key = 'horn', label = 'Klaxon', group = 'body', kind = 'mod', mod = 14 },
    -- Roues
    { key = 'wheels', label = 'Jantes', group = 'wheels', kind = 'wheels' },
    { key = 'wheelcolor', label = 'Couleur des jantes', group = 'wheels', kind = 'wheelcolor' },
    { key = 'smoke', label = 'Fumée des pneus', group = 'wheels', kind = 'smoke' },
    -- Peinture
    { key = 'paint1', label = 'Peinture principale', group = 'paint', kind = 'paint' },
    { key = 'paint2', label = 'Peinture secondaire', group = 'paint', kind = 'paint' },
    { key = 'pearl', label = 'Nacrage', group = 'paint', kind = 'pearl' },
    { key = 'livery', label = 'Livrées', group = 'paint', kind = 'livery' },
    { key = 'tint', label = 'Vitres teintées', group = 'paint', kind = 'tint' },
    { key = 'plate', label = 'Plaques', group = 'paint', kind = 'plate' },
    -- Lumières
    { key = 'neon', label = 'Néons', group = 'lights', kind = 'neon' },
    { key = 'xenon', label = 'Phares xénon', group = 'lights', kind = 'xenon' },
    -- Intérieur
    { key = 'plateholder', label = 'Support de plaque', group = 'interior', kind = 'mod', mod = 25 },
    { key = 'vanity', label = 'Plaque personnalisée', group = 'interior', kind = 'mod', mod = 26 },
    { key = 'trim', label = 'Garnitures', group = 'interior', kind = 'mod', mod = 27 },
    { key = 'ornaments', label = 'Ornements', group = 'interior', kind = 'mod', mod = 28 },
    { key = 'dashboard', label = 'Tableau de bord', group = 'interior', kind = 'mod', mod = 29 },
    { key = 'dials', label = 'Compteurs', group = 'interior', kind = 'mod', mod = 30 },
    { key = 'doorspeakers', label = 'Haut-parleurs de portes', group = 'interior', kind = 'mod', mod = 31 },
    { key = 'seats', label = 'Sièges', group = 'interior', kind = 'mod', mod = 32 },
    { key = 'steering', label = 'Volant', group = 'interior', kind = 'mod', mod = 33 },
    { key = 'shifter', label = 'Levier de vitesse', group = 'interior', kind = 'mod', mod = 34 },
    { key = 'plaques', label = 'Plaques décoratives', group = 'interior', kind = 'mod', mod = 35 },
    { key = 'speakers', label = 'Sono', group = 'interior', kind = 'mod', mod = 36 },
}
local BY = {}
for _, c in ipairs(CATS) do BY[c.key] = c end

local COLORS = {
    { 0, 'Noir', 'Métallisé' }, { 1, 'Graphite', 'Métallisé' }, { 4, 'Argent', 'Métallisé' }, { 111, 'Blanc', 'Métallisé' },
    { 27, 'Rouge', 'Métallisé' }, { 28, 'Rouge Torino', 'Métallisé' }, { 35, 'Rouge bonbon', 'Métallisé' }, { 38, 'Orange', 'Métallisé' },
    { 88, 'Jaune', 'Métallisé' }, { 89, 'Jaune course', 'Métallisé' }, { 53, 'Vert', 'Métallisé' }, { 55, 'Vert lime', 'Métallisé' },
    { 49, 'Vert foncé', 'Métallisé' }, { 64, 'Bleu', 'Métallisé' }, { 70, 'Bleu ultra', 'Métallisé' }, { 62, 'Bleu foncé', 'Métallisé' },
    { 61, 'Bleu nuit', 'Métallisé' }, { 145, 'Violet', 'Métallisé' }, { 135, 'Rose vif', 'Métallisé' }, { 90, 'Bronze', 'Métallisé' },
    { 96, 'Chocolat', 'Métallisé' }, { 99, 'Beige', 'Métallisé' }, { 12, 'Noir mat', 'Mat' }, { 13, 'Gris mat', 'Mat' },
    { 131, 'Blanc mat', 'Mat' }, { 39, 'Rouge mat', 'Mat' }, { 128, 'Vert mat', 'Mat' }, { 83, 'Bleu mat', 'Mat' },
    { 117, 'Acier brossé', 'Métal' }, { 118, 'Noir brossé', 'Métal' }, { 119, 'Aluminium brossé', 'Métal' },
    { 158, 'Or pur', 'Métal' }, { 159, 'Or brossé', 'Métal' }, { 120, 'Chrome', 'Métal' },
}
local LIGHTS = {
    { 1, 'Blanc', 255, 255, 255 }, { 2, 'Bleu', 2, 21, 255 }, { 3, 'Bleu électrique', 3, 83, 255 }, { 4, 'Vert menthe', 0, 255, 140 },
    { 5, 'Vert lime', 94, 255, 1 }, { 6, 'Jaune', 255, 255, 0 }, { 7, 'Or', 255, 150, 5 }, { 8, 'Orange', 255, 62, 0 },
    { 9, 'Rouge', 255, 1, 1 }, { 10, 'Rose', 255, 50, 100 }, { 11, 'Rose vif', 255, 5, 190 }, { 12, 'Violet', 35, 1, 255 },
}
local XENON = { 'Blanc', 'Bleu', 'Bleu électrique', 'Vert menthe', 'Vert lime', 'Jaune', 'Or', 'Orange', 'Rouge', 'Rose', 'Rose vif', 'Violet', 'Lumière noire' }
local TINTS = { { 0, 'Aucune' }, { 3, 'Fumé clair' }, { 2, 'Fumé foncé' }, { 5, 'Limousine' }, { 1, 'Noir pur' }, { 6, 'Vert' } }
local PLATES = { { 0, 'Bleu sur blanc' }, { 3, 'Bleu sur blanc (2)' }, { 4, 'Bleu sur blanc (3)' }, { 1, 'Jaune sur noir' }, { 2, 'Jaune sur bleu' }, { 5, 'North Yankton' } }
local WHEELTYPES = { { 0, 'Sport' }, { 1, 'Muscle' }, { 2, 'Lowrider' }, { 3, 'SUV' }, { 4, 'Tout-terrain' }, { 5, 'Tuner' }, { 7, 'Haut de gamme' },
    { 8, "Benny's Original" }, { 9, "Benny's Bespoke" }, { 11, 'Street' }, { 12, 'Track' }, { 6, 'Moto' } }

local function myVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

local function plateOf(veh) local p = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '') return p end
local function useMod48(veh) return GetNumVehicleMods(veh, 48) > 0 end
local function lightById(id) for _, l in ipairs(LIGHTS) do if l[1] == id then return l end end end
local function rgbMatch(r, g, b)
    for _, l in ipairs(LIGHTS) do if math.abs(l[3] - r) < 6 and math.abs(l[4] - g) < 6 and math.abs(l[5] - b) < 6 then return l[1] end end
    return ('rgb:%d,%d,%d'):format(r, g, b)
end
local function parseRgb(v)
    local r, g, b, f = tostring(v or ''):match('^rgb:(%d+),(%d+),(%d+):?(%d*)$')
    if not r then return nil end
    local c = function(x) return math.max(0, math.min(255, tonumber(x))) end
    return c(r), c(g), c(b), tonumber(f)
end
local function neonFxAvailable() return GetResourceState('elyzea_lscustom') == 'started' end

-- ---------------------------------------------------------
--  Lecture / application
-- ---------------------------------------------------------
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
        local fx = Entity(veh).state.neonFx
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
    if k == 'mod' then SetVehicleMod(veh, c.mod, tonumber(v), false)
    elseif k == 'toggle' then ToggleVehicleMod(veh, c.mod, tonumber(v) == 1)
    elseif k == 'wheels' then
        local t, i = tostring(v):match('^(%-?%d+):(%-?%d+)$')
        if not t then return end
        SetVehicleWheelType(veh, tonumber(t))
        SetVehicleMod(veh, 23, tonumber(i), false)
        if IsThisModelABike(GetEntityModel(veh)) then SetVehicleMod(veh, 24, tonumber(i), false) end
    elseif k == 'paint' then
        local r, g, b, finish = parseRgb(v)
        local pearl, wheel = GetVehicleExtraColours(veh)
        if r then
            finish = math.max(0, math.min(5, finish or 1))
            if c.key == 'paint1' then SetVehicleModColor_1(veh, finish, 0, 0) SetVehicleCustomPrimaryColour(veh, r, g, b)
            else SetVehicleModColor_2(veh, finish, 0) SetVehicleCustomSecondaryColour(veh, r, g, b) end
        else
            local p, s = GetVehicleColours(veh)
            if c.key == 'paint1' then ClearVehicleCustomPrimaryColour(veh) p = tonumber(v) else ClearVehicleCustomSecondaryColour(veh) s = tonumber(v) end
            SetVehicleColours(veh, p, s)
        end
        SetVehicleExtraColours(veh, pearl, wheel)
    elseif k == 'pearl' then local _, w = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, tonumber(v), w)
    elseif k == 'wheelcolor' then local pe = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, pe, tonumber(v))
    elseif k == 'neon' then
        local fx = tostring(v):match('^fx:(%w+)$')
        local r, g, b = parseRgb(v)
        local on = fx ~= nil or r ~= nil or tonumber(v) ~= -1
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, on) end
        -- Effet animé (LsCustom) : posé sur le véhicule par le serveur, visible par tous
        TriggerServerEvent('adminmenu:action', 'vehcustom_neonfx', { netId = NetworkGetNetworkIdFromEntity(veh), fx = fx or false })
        if r then SetVehicleNeonLightsColour(veh, r, g, b)
        elseif not fx and on then local l = lightById(tonumber(v)) if l then SetVehicleNeonLightsColour(veh, l[3], l[4], l[5]) end end
    elseif k == 'xenon' then
        local on = tonumber(v) ~= -1
        ToggleVehicleMod(veh, 22, on)
        if on then SetVehicleXenonLightsColor(veh, tonumber(v)) end
    elseif k == 'tint' then SetVehicleWindowTint(veh, tonumber(v))
    elseif k == 'plate' then SetVehicleNumberPlateTextIndex(veh, tonumber(v))
    elseif k == 'livery' then if useMod48(veh) then SetVehicleMod(veh, 48, tonumber(v), false) else SetVehicleLivery(veh, tonumber(v)) end
    elseif k == 'smoke' then
        local r, g, b = parseRgb(v)
        local on = r ~= nil or tonumber(v) ~= -1
        ToggleVehicleMod(veh, 20, on)
        if r then SetVehicleTyreSmokeColor(veh, r, g, b)
        elseif on then local l = lightById(tonumber(v)) if l then SetVehicleTyreSmokeColor(veh, l[3], l[4], l[5]) end end
    end
end

local function modLabel(veh, c, i)
    if c.level then return ('Niveau %d'):format(i + 1) end
    local txt = GetModTextLabel(veh, c.mod, i)
    local label = txt and GetLabelText(txt)
    if not label or label == 'NULL' or label == '' then label = ('%s n°%d'):format(c.label, i + 1) end
    return label
end

local function options(veh, c, wheelType)
    local k, out = c.kind, {}
    if k == 'mod' then
        out[1] = { value = -1, label = 'Origine' }
        for i = 0, GetNumVehicleMods(veh, c.mod) - 1 do out[#out + 1] = { value = i, label = modLabel(veh, c, i) } end
    elseif k == 'toggle' then out = { { value = 0, label = 'Sans' }, { value = 1, label = 'Avec' } }
    elseif k == 'wheels' then
        local curT, curM = GetVehicleWheelType(veh), GetVehicleMod(veh, 23)
        local t = tonumber(wheelType) or curT
        SetVehicleModKit(veh, 0)
        SetVehicleWheelType(veh, t)
        out[1] = { value = ('%d:-1'):format(t), label = 'Origine' }
        for i = 0, GetNumVehicleMods(veh, 23) - 1 do
            local txt = GetModTextLabel(veh, 23, i)
            local label = txt and GetLabelText(txt)
            if not label or label == 'NULL' then label = ('Jante n°%d'):format(i + 1) end
            out[#out + 1] = { value = ('%d:%d'):format(t, i), label = label }
        end
        SetVehicleWheelType(veh, curT)
        SetVehicleMod(veh, 23, curM, false)
        return out, t
    elseif k == 'paint' or k == 'pearl' or k == 'wheelcolor' then
        for _, x in ipairs(COLORS) do out[#out + 1] = { value = x[1], label = ('%s · %s'):format(x[2], x[3]) } end
    elseif k == 'neon' or k == 'smoke' then
        out[1] = { value = -1, label = k == 'neon' and 'Éteints' or 'Aucune' }
        if k == 'neon' and neonFxAvailable() then
            out[#out + 1] = { value = 'fx:rainbow', label = '🌈 Arc-en-ciel animé' }
            out[#out + 1] = { value = 'fx:elyzea', label = '✨ Elyzea animé' }
        end
        for _, l in ipairs(LIGHTS) do out[#out + 1] = { value = l[1], label = l[2] } end
    elseif k == 'xenon' then
        out[1] = { value = -1, label = 'Phares normaux' }
        for i, l in ipairs(XENON) do out[#out + 1] = { value = i - 1, label = l } end
    elseif k == 'tint' then for _, x in ipairs(TINTS) do out[#out + 1] = { value = x[1], label = x[2] } end
    elseif k == 'plate' then for _, x in ipairs(PLATES) do out[#out + 1] = { value = x[1], label = x[2] } end
    elseif k == 'livery' then
        if useMod48(veh) then
            out[1] = { value = -1, label = 'Origine' }
            for i = 0, GetNumVehicleMods(veh, 48) - 1 do out[#out + 1] = { value = i, label = modLabel(veh, { mod = 48, label = 'Livrée' }, i) } end
        else
            for i = 0, GetVehicleLiveryCount(veh) - 1 do out[#out + 1] = { value = i, label = ('Livrée n°%d'):format(i + 1) } end
        end
    end
    return out
end

local function available(veh, c)
    if c.kind == 'mod' then return GetNumVehicleMods(veh, c.mod) > 0 end
    if c.kind == 'neon' then return IsThisModelACar(GetEntityModel(veh)) end
    if c.kind == 'livery' then return useMod48(veh) or GetVehicleLiveryCount(veh) > 0 end
    return true
end

-- ---------------------------------------------------------
--  Interface
-- ---------------------------------------------------------
RegisterNUICallback('vc_info', function(_, cb)
    local veh = myVehicle()
    if not veh then return cb({ inVehicle = false }) end
    local L = ox()
    if not Snapshot or Snapshot.veh ~= veh then Snapshot = { veh = veh, props = L and L.getVehicleProperties(veh) or nil } end
    SetVehicleModKit(veh, 0)
    local cats = {}
    for _, c in ipairs(CATS) do
        if available(veh, c) then cats[#cats + 1] = { key = c.key, label = c.label, group = c.group } end
    end
    cb({
        inVehicle = true, plate = plateOf(veh), cats = cats, canRevert = Snapshot.props ~= nil, canSave = L ~= nil,
        label = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))),
        wheelTypes = (function() local o = {} for _, w in ipairs(WHEELTYPES) do o[#o + 1] = { id = w[1], label = w[2] } end return o end)(),
    })
end)

RegisterNUICallback('vc_options', function(body, cb)
    local veh, c = myVehicle(), BY[tostring(body.key)]
    if not veh or not c then return cb({ options = {} }) end
    local opts, wt = options(veh, c, body.wheelType)
    cb({ options = opts, current = current(veh, c), wheelType = wt })
end)

RegisterNUICallback('vc_apply', function(body, cb)
    local veh, c = myVehicle(), BY[tostring(body.key)]
    if veh and c then apply(veh, c, body.value) end
    cb({ current = veh and c and current(veh, c) or nil })
end)

-- Tout au maximum (performances)
RegisterNUICallback('vc_max', function(_, cb)
    local veh = myVehicle()
    if veh then
        SetVehicleModKit(veh, 0)
        for _, m in ipairs({ 11, 12, 13, 15, 16 }) do SetVehicleMod(veh, m, GetNumVehicleMods(veh, m) - 1, false) end
        ToggleVehicleMod(veh, 18, true)
    end
    cb('ok')
end)

RegisterNUICallback('vc_revert', function(_, cb)
    local veh = myVehicle()
    local L = ox()
    if veh and Snapshot and Snapshot.veh == veh and Snapshot.props and L then
        L.setVehicleProperties(veh, Snapshot.props)
        TriggerServerEvent('adminmenu:action', 'vehcustom_neonfx', { netId = NetworkGetNetworkIdFromEntity(veh), fx = false })
    end
    cb('ok')
end)

-- Enregistrer sur la carte grise (si le véhicule appartient à un joueur)
RegisterNUICallback('vc_save', function(_, cb)
    local veh = myVehicle()
    local L = ox()
    if veh and L then
        local props = L.getVehicleProperties(veh)
        props._neonFx = Entity(veh).state.neonFx
        TriggerServerEvent('adminmenu:action', 'vehcustom_save', { plate = plateOf(veh), props = props })
        Snapshot = { veh = veh, props = props }
    end
    cb('ok')
end)
