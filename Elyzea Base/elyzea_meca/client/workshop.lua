-- =====================================================================
--  ELYZEA MÉCANO - client : points d'atelier (E), aperçu, devis, installation
--  · E au point : le serveur vérifie la position, le grade et le véhicule.
--  · Chaque option est d'abord un APERÇU (annulé à la fermeture si rien n'est installé).
--  · À l'installation, le serveur envoie les propriétés exactes de chaque ligne :
--    elles sont appliquées puis relues sur le véhicule ; seule une ligne réellement
--    posée est déclarée réussie (et donc facturée).
-- =====================================================================
local C = MecaC
local core = exports.elyzea_core
local WS = { open = false, ws = nil, veh = nil, snapshot = nil, data = nil }

-- Pièces de carrosserie et d'intérieur (type de modification GTA)
local BODY = {
    { id = 0, label = 'Aileron' }, { id = 1, label = 'Pare-chocs avant' }, { id = 2, label = 'Pare-chocs arrière' }, { id = 3, label = 'Bas de caisse' },
    { id = 4, label = 'Échappement' }, { id = 5, label = 'Arceau' }, { id = 6, label = 'Calandre' }, { id = 7, label = 'Capot' },
    { id = 8, label = 'Aile gauche' }, { id = 9, label = 'Aile droite' }, { id = 10, label = 'Toit' }, { id = 14, label = 'Klaxon' },
    { id = 37, label = 'Coffre' }, { id = 38, label = 'Hydraulique' }, { id = 39, label = 'Bloc moteur' }, { id = 40, label = 'Filtre à air' },
    { id = 41, label = 'Barres de renfort' }, { id = 42, label = 'Passages de roue' }, { id = 43, label = 'Antennes' }, { id = 44, label = 'Garnitures extérieures' },
    { id = 45, label = 'Réservoir' }, { id = 46, label = 'Fenêtres' },
}
local INTERIOR = {
    { id = 25, label = 'Support de plaque' }, { id = 26, label = 'Plaque personnalisée' }, { id = 27, label = 'Garnitures' }, { id = 28, label = 'Ornements' },
    { id = 29, label = 'Tableau de bord' }, { id = 30, label = 'Compteurs' }, { id = 31, label = 'Haut-parleurs de portes' }, { id = 32, label = 'Sièges' },
    { id = 33, label = 'Volant' }, { id = 34, label = 'Levier de vitesse' }, { id = 35, label = 'Plaques décoratives' }, { id = 36, label = 'Sono' },
}
local PERF = { engine = 11, brakes = 12, transmission = 13, suspension = 15, armor = 16 }
local COLORS = {
    { 0, 'Noir' }, { 1, 'Graphite' }, { 4, 'Argent' }, { 111, 'Blanc' }, { 27, 'Rouge' }, { 28, 'Rouge Torino' }, { 35, 'Rouge bonbon' }, { 38, 'Orange' },
    { 88, 'Jaune' }, { 89, 'Jaune course' }, { 53, 'Vert' }, { 55, 'Vert lime' }, { 49, 'Vert foncé' }, { 64, 'Bleu' }, { 70, 'Bleu ultra' }, { 62, 'Bleu foncé' },
    { 61, 'Bleu nuit' }, { 145, 'Violet' }, { 135, 'Rose vif' }, { 90, 'Bronze' }, { 96, 'Chocolat' }, { 99, 'Beige' }, { 12, 'Noir mat' }, { 13, 'Gris mat' },
    { 131, 'Blanc mat' }, { 39, 'Rouge mat' }, { 128, 'Vert mat' }, { 83, 'Bleu mat' }, { 117, 'Acier brossé' }, { 118, 'Noir brossé' }, { 119, 'Aluminium brossé' },
    { 158, 'Or pur' }, { 159, 'Or brossé' }, { 120, 'Chrome' },
}
local LIGHTS = {
    { 'Blanc', 255, 255, 255 }, { 'Bleu', 2, 21, 255 }, { 'Bleu électrique', 3, 83, 255 }, { 'Vert menthe', 0, 255, 140 }, { 'Vert lime', 94, 255, 1 },
    { 'Jaune', 255, 255, 0 }, { 'Or', 255, 150, 5 }, { 'Orange', 255, 62, 0 }, { 'Rouge', 255, 1, 1 }, { 'Rose', 255, 50, 100 }, { 'Rose vif', 255, 5, 190 }, { 'Violet', 35, 1, 255 },
}
local XENON = { 'Blanc', 'Bleu', 'Bleu électrique', 'Vert menthe', 'Vert lime', 'Jaune', 'Or', 'Orange', 'Rouge', 'Rose', 'Rose vif', 'Violet', 'Lumière noire' }
local TINTS = { { 0, 'Aucune' }, { 3, 'Fumé clair' }, { 2, 'Fumé foncé' }, { 5, 'Limousine' }, { 1, 'Noir pur' }, { 6, 'Vert' } }
local PLATES = { { 0, 'Bleu sur blanc' }, { 3, 'Bleu sur blanc (2)' }, { 4, 'Bleu sur blanc (3)' }, { 1, 'Jaune sur noir' }, { 2, 'Jaune sur bleu' }, { 5, 'North Yankton' } }
local WHEELTYPES = { { 0, 'Sport' }, { 1, 'Muscle' }, { 2, 'Lowrider' }, { 3, 'SUV' }, { 4, 'Tout-terrain' }, { 5, 'Tuner' }, { 7, 'Haut de gamme' },
    { 8, "Benny's Original" }, { 9, "Benny's Bespoke" }, { 11, 'Street' }, { 12, 'Track' }, { 6, 'Moto' } }
local FINISH = { { 0, 'Normal' }, { 1, 'Métallisé' }, { 2, 'Nacré' }, { 3, 'Mat' }, { 4, 'Métal' }, { 5, 'Chrome' } }

local function ModLabel(veh, mod, i, fallback)
    local txt = GetModTextLabel(veh, mod, i)
    local l = txt and GetLabelText(txt)
    if not l or l == 'NULL' or l == '' then l = ('%s n°%d'):format(fallback, i + 1) end
    return l
end

-- ---------------------------------------------------------------------
-- Options compatibles avec CE véhicule (groupe = mod du catalogue esthétique)
-- Chaque option : { value, label, spec } ; spec = ce que le serveur valide et facture
-- ---------------------------------------------------------------------
local function Subs(veh, group)
    if group == 'body' or group == 'interior' then
        local out = {}
        for _, m in ipairs(group == 'body' and BODY or INTERIOR) do
            if GetNumVehicleMods(veh, m.id) > 0 then out[#out + 1] = { id = tostring(m.id), label = m.label } end
        end
        return out
    elseif group == 'paint' then return { { id = '1', label = 'Peinture principale' }, { id = '2', label = 'Peinture secondaire' } }
    elseif group == 'wheels' then
        local out = {}
        for _, w in ipairs(WHEELTYPES) do
            if (w[1] == 6) == IsThisModelABike(GetEntityModel(veh)) then out[#out + 1] = { id = tostring(w[1]), label = w[2] } end
        end
        return out
    end
    return nil
end

local function Options(veh, group, sub)
    local out = {}
    SetVehicleModKit(veh, 0)
    if group == 'body' or group == 'interior' then
        local id = tonumber(sub)
        if not id then return out end
        local cur = GetVehicleMod(veh, id)
        out[#out + 1] = { value = -1, label = 'Origine', spec = { t = 'mod', id = id, v = -1 } }
        for i = 0, GetNumVehicleMods(veh, id) - 1 do out[#out + 1] = { value = i, label = ModLabel(veh, id, i, 'Pièce'), spec = { t = 'mod', id = id, v = i } } end
        return out, cur
    elseif group == 'paint' then
        local slot = tonumber(sub) or 1
        for _, f in ipairs(FINISH) do
            for _, c in ipairs(COLORS) do
                if f[1] <= 1 or (f[1] == 3 and c[2]:find('mat')) or f[1] == 5 and c[1] == 120 or f[1] == 4 and c[2]:find('brossé') then
                    out[#out + 1] = { value = ('%d:%d'):format(c[1], f[1]), label = ('%s · %s'):format(c[2], f[2]), spec = { t = 'paint', slot = slot, color = c[1], finish = f[1] } }
                end
            end
        end
        local p, s = GetVehicleColours(veh)
        return out, ('%d:%d'):format(slot == 1 and p or s, slot == 1 and (GetVehicleModColor_1(veh)) or (GetVehicleModColor_2(veh)))
    elseif group == 'pearl' or group == 'wheelcolor' then
        for _, c in ipairs(COLORS) do out[#out + 1] = { value = c[1], label = c[2], spec = { t = group, v = c[1] } } end
        local pe, wc = GetVehicleExtraColours(veh)
        return out, group == 'pearl' and pe or wc
    elseif group == 'wheels' then
        local t = tonumber(sub) or GetVehicleWheelType(veh)
        local curT, curM = GetVehicleWheelType(veh), GetVehicleMod(veh, 23)
        SetVehicleWheelType(veh, t)
        out[#out + 1] = { value = -1, label = 'Origine', spec = { t = 'wheels', wt = t, v = -1 } }
        for i = 0, GetNumVehicleMods(veh, 23) - 1 do out[#out + 1] = { value = i, label = ModLabel(veh, 23, i, 'Jante'), spec = { t = 'wheels', wt = t, v = i } } end
        SetVehicleWheelType(veh, curT)
        SetVehicleMod(veh, 23, curM, false)
        return out, curT == t and curM or nil
    elseif group == 'smoke' then
        for i, l in ipairs(LIGHTS) do out[#out + 1] = { value = i, label = l[1], spec = { t = 'smoke', rgb = { l[2], l[3], l[4] } } } end
        return out
    elseif group == 'neon' then
        if not IsThisModelACar(GetEntityModel(veh)) then return out end
        out[#out + 1] = { value = 0, label = 'Éteints', spec = { t = 'neon', on = false } }
        for i, l in ipairs(LIGHTS) do out[#out + 1] = { value = i, label = l[1], spec = { t = 'neon', on = true, rgb = { l[2], l[3], l[4] } } } end
        return out
    elseif group == 'xenon' then
        out[#out + 1] = { value = -2, label = 'Phares normaux', spec = { t = 'xenon', on = false } }
        for i, l in ipairs(XENON) do out[#out + 1] = { value = i - 1, label = l, spec = { t = 'xenon', on = true, v = i - 1 } } end
        return out, IsToggleModOn(veh, 22) and GetVehicleXenonLightsColor(veh) or -2
    elseif group == 'tint' then
        for _, x in ipairs(TINTS) do out[#out + 1] = { value = x[1], label = x[2], spec = { t = 'tint', v = x[1] } } end
        return out, GetVehicleWindowTint(veh)
    elseif group == 'plate' then
        for _, x in ipairs(PLATES) do out[#out + 1] = { value = x[1], label = x[2], spec = { t = 'plate', v = x[1] } } end
        return out, GetVehicleNumberPlateTextIndex(veh)
    elseif group == 'livery' then
        if GetNumVehicleMods(veh, 48) > 0 then
            out[#out + 1] = { value = -1, label = 'Origine', spec = { t = 'livery', v = -1 } }
            for i = 0, GetNumVehicleMods(veh, 48) - 1 do out[#out + 1] = { value = i, label = ModLabel(veh, 48, i, 'Livrée'), spec = { t = 'livery', v = i } } end
            return out, GetVehicleMod(veh, 48)
        end
        for i = 0, GetVehicleLiveryCount(veh) - 1 do out[#out + 1] = { value = i, label = ('Livrée n°%d'):format(i + 1), spec = { t = 'livery', v = i } } end
        return out, GetVehicleLivery(veh)
    end
    return out
end

-- Spécification → propriétés elyzea_core (même conversion que le serveur, pour l'aperçu)
local MODKEY = {}
for _, m in ipairs(BODY) do MODKEY[m.id] = true end
for _, m in ipairs(INTERIOR) do MODKEY[m.id] = true end
local function Preview(veh, spec)
    SetVehicleModKit(veh, 0)
    local t = spec.t
    if t == 'mod' and MODKEY[spec.id] then SetVehicleMod(veh, spec.id, spec.v, false)
    elseif t == 'wheels' then SetVehicleWheelType(veh, spec.wt) SetVehicleMod(veh, 23, spec.v, false) if IsThisModelABike(GetEntityModel(veh)) then SetVehicleMod(veh, 24, spec.v, false) end
    elseif t == 'paint' then
        local p, s = GetVehicleColours(veh)
        local pe, wc = GetVehicleExtraColours(veh)
        if spec.slot == 1 then ClearVehicleCustomPrimaryColour(veh) SetVehicleModColor_1(veh, spec.finish, 0, 0) SetVehicleColours(veh, spec.color, s)
        else ClearVehicleCustomSecondaryColour(veh) SetVehicleModColor_2(veh, spec.finish, 0) SetVehicleColours(veh, p, spec.color) end
        SetVehicleExtraColours(veh, pe, wc)
    elseif t == 'pearl' then local _, wc = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, spec.v, wc)
    elseif t == 'wheelcolor' then local pe = GetVehicleExtraColours(veh) SetVehicleExtraColours(veh, pe, spec.v)
    elseif t == 'smoke' then ToggleVehicleMod(veh, 20, true) SetVehicleTyreSmokeColor(veh, spec.rgb[1], spec.rgb[2], spec.rgb[3])
    elseif t == 'neon' then
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, spec.on == true) end
        if spec.rgb then SetVehicleNeonLightsColour(veh, spec.rgb[1], spec.rgb[2], spec.rgb[3]) end
    elseif t == 'xenon' then ToggleVehicleMod(veh, 22, spec.on == true) if spec.on then SetVehicleXenonLightsColor(veh, spec.v or -1) end
    elseif t == 'tint' then SetVehicleWindowTint(veh, spec.v)
    elseif t == 'plate' then SetVehicleNumberPlateTextIndex(veh, spec.v)
    elseif t == 'livery' then if GetNumVehicleMods(veh, 48) > 0 then SetVehicleMod(veh, 48, spec.v, false) else SetVehicleLivery(veh, spec.v) end
    elseif t == 'perf' then
        if spec.mod == 'turbo' then ToggleVehicleMod(veh, 18, true) elseif PERF[spec.mod] then SetVehicleMod(veh, PERF[spec.mod], spec.level - 1, false) end
    end
end

-- La ligne est-elle réellement posée ? (relecture des propriétés du véhicule)
local IGNORE = { modBackWheels = true, paintType1 = true, paintType2 = true, xenonColor = true }
local function Same(a, b)
    if type(a) == 'table' and type(b) == 'table' then
        for i = 1, math.max(#a, 3) do
            local x, y = a[i], b[i]
            if type(x) == 'boolean' or type(y) == 'boolean' then if (x == true) ~= (y == true) then return false end
            elseif x ~= nil and y ~= nil and math.abs((tonumber(x) or 0) - (tonumber(y) or 0)) > 3 then return false end
        end
        return true
    end
    if type(a) == 'boolean' or type(b) == 'boolean' then return (a == true) == (b == true) end
    if tonumber(a) and tonumber(b) then
        local x, y = tonumber(a), tonumber(b)
        if x == y then return true end
        return (x <= 0 and y <= 0)   -- -1 / 0 : « origine » ou « aucune » selon le natif
    end
    return a == b
end
local function Verify(veh, patch)
    local props = core:GetVehicleProperties(veh) or {}
    for k, v in pairs(patch) do
        if not IGNORE[k] then
            local got = props[k]
            if k == 'modXenon' or k == 'modTurbo' or k == 'modSmokeEnabled' then got = props[k] == true end
            if not Same(got, v) then return false end
        end
    end
    return true
end

local function Control(veh)
    if NetworkHasControlOfEntity(veh) then return true end
    local t = GetGameTimer() + 2500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do NetworkRequestControlOfEntity(veh) Wait(0) end
    return NetworkHasControlOfEntity(veh)
end

-- ---------------------------------------------------------------------
-- Ouverture / fermeture
-- ---------------------------------------------------------------------
local function Restore()
    if WS.veh and DoesEntityExist(WS.veh) and WS.snapshot then
        Control(WS.veh)
        core:SetVehicleProperties(WS.veh, WS.snapshot)
    end
end

local function Close(silent)
    if not WS.open then return end
    WS.open = false
    if not WS.keep then Restore() end
    WS.keep = false
    C.Focus('workshop', false)
    SendNUIMessage({ action = 'workshop', show = false })
    if not silent then C.Notify('Atelier fermé : aucune modification non installée n\'est restée sur le véhicule.', 'inform') end
end
C.ui.workshop = { close = function() Close(false) end }

local function VehicleOn(w)
    local best, bestD
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(veh) - w.vehicle)
        if d <= (w.radius or 3.5) and (not bestD or d < bestD) then best, bestD = veh, d end
    end
    return best
end

local function Open(w)
    local veh = VehicleOn(w)
    if not veh then return C.Notify('Placez le véhicule du client sur l\'emplacement.', 'error') end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return C.Notify('Le véhicule doit être vide pendant l\'intervention.', 'error') end
    local r = C.Req('wsOpen', { ws = w.id, net = VehToNet(veh) })
    if r.error then return C.Notify(r.error, 'error') end
    if not Control(veh) then return C.Notify('Impossible de prendre la main sur le véhicule, réessayez.', 'error') end
    WS.open, WS.ws, WS.veh, WS.data, WS.keep = true, w, veh, r, false
    WS.snapshot = core:GetVehicleProperties(veh)
    -- Niveaux actuels (véhicule) et pièces disponibles par rubrique
    local live = {}
    for k, id in pairs(PERF) do live[k] = GetVehicleMod(veh, id) + 1 end
    live.turbo = IsToggleModOn(veh, 18) and 1 or 0
    local maxLv = {}
    for k, id in pairs(PERF) do maxLv[k] = GetNumVehicleMods(veh, id) end
    maxLv.turbo = 1
    local groups = {}
    for _, it in ipairs(r.items) do
        if it.kind == 'cosmetic' and not groups[it.mod] then
            local subs = Subs(veh, it.mod)
            local opts = subs and {} or select(1, Options(veh, it.mod))
            groups[it.mod] = { subs = subs, empty = (subs and #subs == 0) or (not subs and #opts == 0) }
        end
    end
    C.Focus('workshop', true)
    SendNUIMessage({ action = 'workshop', show = true, data = r, live = live, maxLv = maxLv, groups = groups,
        model = C.ModelLabel(veh), health = { engine = math.floor(GetVehicleEngineHealth(veh) / 10), body = math.floor(GetVehicleBodyHealth(veh) / 10) },
        state = C.VehicleState(veh) })
    -- Fermeture automatique si le mécanicien s'éloigne ou si le véhicule bouge de l'emplacement
    CreateThread(function()
        while WS.open do
            Wait(500)
            if not DoesEntityExist(veh) or #(GetEntityCoords(PlayerPedId()) - w.coords) > 6.0 or #(GetEntityCoords(veh) - w.vehicle) > (w.radius or 3.5) + 2.0
                or C.IsDown() or not C.OnDuty() then
                Close(false)
            end
        end
    end)
end

RegisterNUICallback('wsOptions', function(body, cb)
    if not WS.open then return cb({ options = {} }) end
    local opts, cur = Options(WS.veh, tostring(body.group or ''), body.sub)
    cb({ options = opts, current = cur })
end)
RegisterNUICallback('wsPreview', function(body, cb)
    cb({})
    if not WS.open or type(body.spec) ~= 'table' then return end
    Control(WS.veh)
    Preview(WS.veh, body.spec)
end)
RegisterNUICallback('wsRevert', function(_, cb)
    cb({})
    if WS.open then Restore() end
end)
-- Retire l'aperçu d'une seule ligne : on repart de l'état d'origine puis on remet les autres lignes
RegisterNUICallback('wsReapply', function(body, cb)
    cb({})
    if not WS.open then return end
    Restore()
    for _, spec in ipairs(type(body.specs) == 'table' and body.specs or {}) do if type(spec) == 'table' then Preview(WS.veh, spec) end end
end)

RegisterNUICallback('wsSend', function(body, cb)
    if not WS.open then return cb({ error = 'Atelier fermé.' }) end
    local r = C.Req('quoteCreate', { ws = WS.ws.id, net = VehToNet(WS.veh), customer = body.customer, items = body.items, model = C.ModelLabel(WS.veh) })
    if r.ok then C.Notify(r.message, 'success') end
    cb(r)
end)

RegisterNUICallback('wsCancelQuote', function(body, cb)
    local r = C.Req('quoteCancel', { uid = body.uid })
    if r.error then C.Notify(r.error, 'error') elseif r.message then C.Notify(r.message, 'inform') end
    cb(r)
end)

-- Installation : propriétés exactes envoyées par le serveur, appliquées puis vérifiées
RegisterNUICallback('wsInstall', function(body, cb)
    if not WS.open then return cb({ error = 'Atelier fermé.' }) end
    local veh = WS.veh
    local r = C.Req('quoteInstallStart', { uid = body.uid, net = VehToNet(veh) })
    if r.error then return cb(r) end
    Restore()                         -- on enlève les aperçus : seul le devis est posé
    Control(veh)
    local results = {}
    for i, line in ipairs(r.lines) do
        if line.patch then
            core:SetVehicleProperties(veh, line.patch)
            -- Finition d'une couleur d'origine (le core n'applique la finition qu'aux couleurs libres)
            local pt = line.patch
            if pt.paintType1 and type(pt.color1) == 'number' then
                local _, s2 = GetVehicleColours(veh)
                SetVehicleModColor_1(veh, pt.paintType1, pt.color1, 0) SetVehicleColours(veh, pt.color1, s2)
            end
            if pt.paintType2 and type(pt.color2) == 'number' then
                local p1 = GetVehicleColours(veh)
                SetVehicleModColor_2(veh, pt.paintType2, pt.color2) SetVehicleColours(veh, p1, pt.color2)
            end
            Wait(80)
            results[i] = Verify(veh, line.patch)
        else
            results[i] = true
        end
    end
    local done = C.Req('quoteInstallDone', { uid = body.uid, results = results })
    if done.ok then
        WS.snapshot = core:GetVehicleProperties(veh)   -- l'état installé devient la référence
        WS.keep = true
        C.Notify(done.message, done.failed > 0 and 'inform' or 'success')
    end
    cb(done)
end)

RegisterNetEvent('meca:client:quoteUpdate', function(q)
    if WS.open then SendNUIMessage({ action = 'wsQuote', quote = q }) end
end)

-- ---------------------------------------------------------------------
-- Points d'atelier : marqueur et touche E
-- ---------------------------------------------------------------------
local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

CreateThread(function()
    while true do
        local sleep = 1000
        if C.OnDuty() and C.Can('workshop') and not WS.open then
            local pos = GetEntityCoords(PlayerPedId())
            for _, w in ipairs(C.Workshops()) do
                local d = #(pos - w.coords)
                if d < 25.0 then
                    sleep = 0
                    if Config.WorkshopMarker then
                        DrawMarker(27, w.coords.x, w.coords.y, w.coords.z - 0.97, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 245, 158, 11, 160, false, false, 2, false, nil, nil, false)
                        DrawMarker(1, w.vehicle.x, w.vehicle.y, w.vehicle.z - 1.0, 0, 0, 0, 0, 0, 0, (w.radius or 3.5) * 2, (w.radius or 3.5) * 2, 0.15, 245, 158, 11, 50, false, false, 2, false, nil, nil, false)
                    end
                    if d < 1.4 and not IsPedInAnyVehicle(PlayerPedId(), false) and not C.AnyOpen() then
                        Help(('~INPUT_CONTEXT~ %s'):format(w.label))
                        if IsControlJustPressed(0, Config.Keys.workshop) then Open(w) end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and WS.open then Restore() end end)
