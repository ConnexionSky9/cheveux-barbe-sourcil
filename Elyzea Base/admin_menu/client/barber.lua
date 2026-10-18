-- =========================================================
--  COIFFEUR / BARBIER - CLIENT
--  Caméra sur le visage, aperçu au survol, panier, paiement.
--  Optimisé : aucune boucle quand le salon est fermé, seuls les
--  natives de la partie modifiée sont rappelés à chaque survol.
-- =========================================================
local CFG = Config.Barber or {}
local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`
local HEAD_BONE = 31086
local HAIR = 2                                  -- composant « cheveux » du personnage
local HAIR_LOAD_MS = tonumber(CFG.hairLoadTimeout) or 4000

-- Journal de diagnostic (Config.Barber.debug = true) : console F8
local function dbg(fmt, ...)
    if not CFG.debug then return end
    local ok, msg = pcall(string.format, fmt, ...)
    print('^5[Salon]^7 ' .. (ok and msg or fmt))
end

BarberOpen = false

local shop             -- données du salon envoyées par le serveur
local gender           -- 'male' | 'female'
local orig, state      -- tête d'origine / tête avec le panier
local preview          -- { key, value } : survol en cours
local inCart = {}
local awaiting = false
local accessories      -- chapeau, lunettes, masque retirés pendant la coupe

-- Tout est déduit de barber_data.lua : GROUP[clé] = partie du visage à redessiner
local GROUP, STYLE, OVERLAY = { hair = 'hair', hair_color = 'hair', hair_highlight = 'hair', eyes = 'eyes' }, {}, {}
for name, ov in pairs(BarberData.overlays) do
    OVERLAY[name] = ov
    STYLE[name] = true
    GROUP[name] = name
    if ov.palette then
        GROUP[name .. '_color'] = name
        if ov.highlight then GROUP[name .. '_highlight'] = name end
    end
end
-- Type de couleur GTA : 1 = teintes de cheveux, 2 = teintes de maquillage
local COLOR_TYPE = { hair = 1, makeup = 2 }

local function copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == 'table' and copy(v) or v end
    return o
end

local function normalize(key, v)
    if STYLE[key] then
        if type(v) ~= 'table' then return nil end
        local o = tonumber(v.o) or 1.0
        return { s = math.floor(tonumber(v.s) or -1), o = math.max(0.0, math.min(1.0, o)) + 0.0 }
    end
    v = tonumber(v)
    return v and math.floor(v) or nil
end

-- ---------------------------------------------------------
--  Coupes réellement disponibles pour CE personnage
--  GTA numérote toutes les coupes à la suite : d'abord celles du jeu et de ses
--  mises à jour, puis celles des packs addon (une « collection » par pack).
--  On ne propose que les n° qui existent (au moins une texture) et on garde,
--  pour chaque coupe, sa collection et son n° dans la collection.
-- ---------------------------------------------------------
local hairInfo -- { count, list = { {v, t, c, l} }, byIndex = { [v] = entrée }, invalid = { v… } }

local function pedName(m) return m == FEMALE and 'mp_f_freemode_01' or 'mp_m_freemode_01' end

local function hairCollection(p, d)
    if not (ElyCloth and ElyCloth.enabled) then return nil, nil end
    local col, li = ElyCloth.info(p, 'component', HAIR, d)
    if col == '' or li == nil or li < 0 then return nil, nil end
    return col, li
end

-- Nom que doivent porter les fichiers d'une coupe addon dans le pack
local function expectedFiles(p, col, li)
    if not col then return nil end
    local ped = pedName(GetEntityModel(p))
    local prefix = col:lower():find('freemode_01', 1, true) and col or (ped .. '_' .. col)
    return ('%s^hair_%03d_u.ydd (ou _r) + %s^hair_diff_%03d_a_uni.ytd'):format(prefix, li, prefix, li)
end

local function scanHair(p)
    local count = GetNumberOfPedDrawableVariations(p, HAIR)
    local info = { count = count, list = {}, byIndex = {}, invalid = {} }
    for d = 0, count - 1 do
        local t = GetNumberOfPedTextureVariations(p, HAIR, d)
        local col, li = hairCollection(p, d)
        local e = { v = d, t = t, c = col, l = li }
        if t and t > 0 then
            info.list[#info.list + 1] = e
            info.byIndex[d] = e
        else
            info.invalid[#info.invalid + 1] = d
        end
    end
    if CFG.debug then
        dbg('Modèle : %s · coupes déclarées : %d · utilisables : %d · sans texture (ignorées) : %d',
            pedName(GetEntityModel(p)), count, #info.list, #info.invalid)
        if not (ElyCloth and ElyCloth.enabled) then
            dbg('^3Natives de collection absentes : impossible de distinguer coupes du jeu et addon (sv_enforceGameBuild trop ancien ?).^7')
        else
            local packs = {}
            for _, r in ipairs(ElyCloth.ranges(p, 'component', HAIR)) do
                dbg('  collection %-40s n° %d à %d (%d coupe(s))', r.col == '' and '(jeu de base)' or r.col, r.first, r.first + r.count - 1, r.count)
                if r.col ~= '' then packs[#packs + 1] = { col = r.col, first = r.first, count = r.count } end
            end
            -- Vérification des fichiers des packs côté serveur (noms, .ymt, .meta)
            TriggerServerEvent('adminmenu:barber:checkPacks', pedName(GetEntityModel(p)), packs)
        end
        if #info.invalid > 0 then
            dbg('  n° sans texture : %s', table.concat(info.invalid, ', ', 1, math.min(#info.invalid, 40)))
        end
    end
    return info
end

-- Applique une coupe une fois son modèle chargé : la coupe actuelle reste visible pendant le
-- chargement (plus de tête chauve), et seule la DERNIÈRE coupe demandée est appliquée.
local hairToken = 0
local function setHair(p, d, t, color, highlight, onFail)
    hairToken = hairToken + 1
    local token = hairToken
    local e = hairInfo and hairInfo.byIndex[d]
    if not e then
        dbg('^1Coupe n°%s refusée : elle n\'existe pas pour ce personnage (0 texture ou hors limites, %d coupes).^7', tostring(d), hairInfo and hairInfo.count or -1)
        if onFail then onFail('absente') end
        return false
    end
    if not t or t < 0 or t >= e.t then t = 0 end
    local function finish()
        SetPedComponentVariation(p, HAIR, d, t, 0)
        if color then SetPedHairColor(p, color, highlight or color) end
        dbg('Coupe appliquée : n°%d texture %d/%d%s', d, t, e.t, e.c and (' · collection %s n° local %d'):format(e.c, e.l) or ' · jeu')
    end
    if GetPedDrawableVariation(p, HAIR) == d and GetPedTextureVariation(p, HAIR) == t then finish() return true end
    if not (SetPedPreloadVariationData and HasPedPreloadVariationDataFinished) then finish() return true end
    SetPedPreloadVariationData(p, HAIR, d, t)
    CreateThread(function()
        local start = GetGameTimer()
        while not HasPedPreloadVariationDataFinished(p) do
            if token ~= hairToken then return end            -- une autre coupe a été demandée entre-temps
            if GetGameTimer() - start > HAIR_LOAD_MS then
                ReleasePedPreloadVariationData(p)
                dbg('^1Coupe n°%d non chargée après %d ms : le modèle n\'est pas trouvé.%s^7', d, HAIR_LOAD_MS,
                    e.c and (' Fichiers attendus dans le pack : ' .. expectedFiles(p, e.c, e.l)) or '')
                if onFail then onFail('non chargée') end
                return
            end
            Wait(0)
        end
        if token ~= hairToken then return end
        finish()
        ReleasePedPreloadVariationData(p)
    end)
    return true
end

-- ---------------------------------------------------------
--  Lecture / application de la tête
-- ---------------------------------------------------------
local function overlayOf(p, idx)
    local ok, val, _, c1, c2, op = GetPedHeadOverlayData(p, idx)
    if not ok or val == nil or val == 255 then return { s = -1, o = 1.0 }, c1 or 0, c2 or 0 end
    return { s = val, o = math.floor((op or 1.0) * 100 + 0.5) / 100 }, c1 or 0, c2 or 0
end

local function snapshot(p)
    local s = {
        hair = GetPedDrawableVariation(p, HAIR), hairTex = math.max(0, GetPedTextureVariation(p, HAIR)),
        hair_color = math.max(0, GetPedHairColor(p)), hair_highlight = math.max(0, GetPedHairHighlightColor(p)),
        eyes = math.max(0, GetPedEyeColor(p)),
    }
    for name, ov in pairs(OVERLAY) do
        local st, c1, c2 = overlayOf(p, ov.index)
        s[name] = st
        if ov.palette then
            s[name .. '_color'] = c1
            if ov.highlight then s[name .. '_highlight'] = c2 end
        end
    end
    return s
end

local function val(key)
    if preview and preview.key == key then return preview.value end
    return state[key]
end

-- Texture de la coupe affichée : celle choisie dans le salon, sinon celle d'origine si c'est la même coupe
local function hairTex(d)
    if preview and preview.key == 'hair' and preview.tex then return preview.tex end
    if d == state.hair and state.hairTex then return state.hairTex end
    if orig and d == orig.hair then return orig.hairTex end
    return 0
end

local function hairFailed(d, why)
    SendNUIMessage({ action = 'barber', event = 'hairfail', v = d, why = why })
end

local function applyGroup(g)
    local p = PlayerPedId()
    if g == 'hair' then
        local d = val('hair')
        SetPedHairColor(p, val('hair_color'), val('hair_highlight'))
        setHair(p, d, hairTex(d), val('hair_color'), val('hair_highlight'), function(why) hairFailed(d, why) end)
    elseif g == 'eyes' then
        SetPedEyeColor(p, val('eyes'))
    else
        local ov, st = OVERLAY[g], val(g)
        if not ov or type(st) ~= 'table' then return end
        SetPedHeadOverlay(p, ov.index, st.s < 0 and 255 or st.s, st.o + 0.0)
        if ov.palette then
            local c1 = val(g .. '_color') or 0
            SetPedHeadOverlayColor(p, ov.index, COLOR_TYPE[ov.palette] or 0, c1, ov.highlight and (val(g .. '_highlight') or c1) or c1)
        end
    end
end

local function applyAll()
    applyGroup('hair')
    applyGroup('eyes')
    for name in pairs(OVERLAY) do applyGroup(name) end
end

-- Tête sauvegardée (mode interne) appliquée sans ouvrir le salon
local function applyLook(look)
    if type(look) ~= 'table' then return end
    local p = PlayerPedId()
    local m = GetEntityModel(p)
    if (look.model == 'female' and m ~= FEMALE) or (look.model ~= 'female' and m ~= MALE) then return end
    -- Coupe d'un pack : retrouvée par sa collection (son n° global change si on ajoute / retire un pack)
    local d = look.hair
    if look.hairCol and ElyCloth and ElyCloth.enabled then
        d = ElyCloth.resolve(p, 'component', HAIR, { drawable = look.hair, col = look.hairCol, li = look.hairLi })
        if d == nil then
            dbg('^3Coupe enregistrée introuvable : le pack « %s » n\'est pas chargé. Coupe actuelle conservée.^7', look.hairCol)
        end
    end
    if d and d >= 0 and d < GetNumberOfPedDrawableVariations(p, HAIR) and GetNumberOfPedTextureVariations(p, HAIR, d) > 0 then
        local t = look.hairTex
        if t == nil then t = GetPedDrawableVariation(p, HAIR) == d and GetPedTextureVariation(p, HAIR) or 0 end
        if t < 0 or t >= GetNumberOfPedTextureVariations(p, HAIR, d) then t = 0 end
        SetPedComponentVariation(p, HAIR, d, t, 0)
    elseif d then
        dbg('^3Coupe enregistrée n°%s non valide pour ce personnage : coupe actuelle conservée.^7', tostring(d))
    end
    SetPedHairColor(p, look.hair_color, look.hair_highlight)
    for name, ov in pairs(OVERLAY) do
        local st = look[name]
        if type(st) == 'table' then
            SetPedHeadOverlay(p, ov.index, st.s < 0 and 255 or st.s, (st.o or 1.0) + 0.0)
            if ov.palette then
                local c1 = look[name .. '_color'] or 0
                SetPedHeadOverlayColor(p, ov.index, COLOR_TYPE[ov.palette] or 0, c1, ov.highlight and (look[name .. '_highlight'] or c1) or c1)
            end
        end
    end
    if look.eyes then SetPedEyeColor(p, look.eyes) end
end

-- ---------------------------------------------------------
--  Accessoires qui cachent les cheveux
-- ---------------------------------------------------------
local function hideAccessories(p)
    if CFG.hideAccessories == false then return end
    accessories = {
        hat = { GetPedPropIndex(p, 0), GetPedPropTextureIndex(p, 0) },
        glasses = { GetPedPropIndex(p, 1), GetPedPropTextureIndex(p, 1) },
        mask = { GetPedDrawableVariation(p, 1), GetPedTextureVariation(p, 1) },
    }
    ClearPedProp(p, 0)
    ClearPedProp(p, 1)
    SetPedComponentVariation(p, 1, 0, 0, 0)
end

local function restoreAccessories()
    if not accessories then return end
    local p, a = PlayerPedId(), accessories
    accessories = nil
    if a.hat[1] >= 0 then SetPedPropIndex(p, 0, a.hat[1], a.hat[2], true) end
    if a.glasses[1] >= 0 then SetPedPropIndex(p, 1, a.glasses[1], a.glasses[2], true) end
    SetPedComponentVariation(p, 1, a.mask[1], a.mask[2], 0)
end

-- ---------------------------------------------------------
--  Caméra
-- ---------------------------------------------------------
local CAMS = {
    head = { dist = 0.95, z = 0.08, look = 0.03, fov = 38.0 },
    face = { dist = 0.62, z = 0.04, look = 0.02, fov = 34.0 },
    eyes = { dist = 0.42, z = 0.07, look = 0.065, fov = 28.0 },
    lips = { dist = 0.42, z = -0.03, look = -0.045, fov = 28.0 },
    bust = { dist = 1.70, z = -0.12, look = -0.30, fov = 40.0 },
}
local cam, camMode, zoom, spin = nil, 'head', 1.0, 0
local anchor, fwd, baseHeading, radarWas
local cur = {}

local function camTarget()
    local m = CAMS[camMode] or CAMS.head
    local d = m.dist * zoom
    return anchor.x + fwd.x * d, anchor.y + fwd.y * d, anchor.z + m.z,
           anchor.z + m.look, m.fov
end

local function startCamera(p)
    baseHeading = GetEntityHeading(p)
    local r = math.rad(baseHeading)
    fwd = { x = -math.sin(r), y = math.cos(r) }
    local h = GetPedBoneCoords(p, HEAD_BONE, 0.0, 0.0, 0.0)
    anchor = { x = h.x, y = h.y, z = h.z }
    camMode, zoom, spin = 'head', 1.0, 0

    local x, y, z, lz, fov = camTarget()
    cur = { x = x, y = y, z = z, lz = lz, fov = fov }
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', x, y, z, 0.0, 0.0, 0.0, fov, false, 2)
    PointCamAtCoord(cam, anchor.x, anchor.y, lz)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 600, true, false)
end

local function stopCamera()
    if not cam then return end
    RenderScriptCams(false, true, 500, true, false)
    DestroyCam(cam, false)
    cam = nil
end

-- ---------------------------------------------------------
--  Ouverture / fermeture
-- ---------------------------------------------------------
local palettes -- teintes du jeu (calculées une seule fois)
local function getPalettes()
    if palettes then return palettes end
    palettes = { hair = {}, makeup = {} }
    for i = 0, GetNumHairColors() - 1 do
        local r, g, b = GetPedHairRgbColor(i)
        palettes.hair[#palettes.hair + 1] = ('#%02x%02x%02x'):format(r or 0, g or 0, b or 0)
    end
    for i = 0, GetNumMakeupColors() - 1 do
        local r, g, b = GetPedMakeupRgbColor(i)
        palettes.makeup[#palettes.makeup + 1] = ('#%02x%02x%02x'):format(r or 0, g or 0, b or 0)
    end
    return palettes
end

-- Les tables Lua indexées à partir de 0 sont converties en { ["0"] = ... } pour l'interface
local function strKeys(t)
    local out = {}
    for k, v in pairs(t or {}) do out[tostring(k)] = v end
    return out
end

local catalog -- catalogue préparé pour l'interface (une seule fois par sexe)
local function getCatalog(g)
    catalog = catalog or {}
    if catalog[g] then return catalog[g] end
    local overlays = {}
    for name, ov in pairs(OVERLAY) do
        overlays[name] = { label = ov.label, none = ov.none, palette = ov.palette, highlight = ov.highlight == true, styles = strKeys(ov.styles) }
    end
    local female = g == 'female'
    local tabs = {}
    for _, t in ipairs(BarberData.tabs) do
        local hideTab = female and t.female == false and not (t.id == 'beard' and CFG.beardForFemale)
        if not female and t.male == false then hideTab = true end
        if not hideTab then
            local modes = {}
            for _, m in ipairs(t.modes) do
                local hideMode = (female and m.female == false and not CFG.chestForFemale) or (not female and m.male == false)
                if not hideMode then modes[#modes + 1] = { key = m.key, label = m.label, cart = m.cart or m.label } end
            end
            if #modes > 0 then tabs[#tabs + 1] = { id = t.id, icon = t.icon, label = t.label, cam = t.cam or 'head', modes = modes } end
        end
    end
    catalog[g] = {
        hair = strKeys(BarberData.hair[g]),
        eyes = BarberData.eyes, naturalEyes = BarberData.naturalEyes or 9,
        naturalHairColors = BarberData.naturalHairColors or 29,
        overlays = overlays, tabs = tabs,
    }
    return catalog[g]
end

local function closeBarber(revert)
    if not BarberOpen then return end
    BarberOpen = false
    awaiting = false
    if revert and orig then
        state, preview = copy(orig), nil
        applyAll()
    end
    preview = nil
    restoreAccessories()
    stopCamera()
    local p = PlayerPedId()
    if baseHeading then SetEntityHeading(p, baseHeading) end
    FreezeEntityPosition(p, false)
    if radarWas then DisplayRadar(true) end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'barber', open = false })
    shop, inCart = nil, {}
end

local function frameLoop()
    CreateThread(function()
        while BarberOpen do
            HideHudAndRadarThisFrame()
            local p = PlayerPedId()
            if IsEntityDead(p) or IsPedInAnyVehicle(p, false) then closeBarber(true) break end
            local ft = GetFrameTime()
            if spin ~= 0 then SetEntityHeading(p, GetEntityHeading(p) + spin * 110.0 * ft) end
            if cam then
                local x, y, z, lz, fov = camTarget()
                local k = math.min(1.0, ft * 9.0)
                cur.x = cur.x + (x - cur.x) * k
                cur.y = cur.y + (y - cur.y) * k
                cur.z = cur.z + (z - cur.z) * k
                cur.lz = cur.lz + (lz - cur.lz) * k
                cur.fov = cur.fov + (fov - cur.fov) * k
                SetCamCoord(cam, cur.x, cur.y, cur.z)
                PointCamAtCoord(cam, anchor.x, anchor.y, cur.lz)
                SetCamFov(cam, cur.fov)
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('adminmenu:barber:show', function(data)
    if BarberOpen or type(data) ~= 'table' then return end
    if IsStaffMenuOpen and IsStaffMenuOpen() then return end
    local p = PlayerPedId()
    local m = GetEntityModel(p)
    if m ~= MALE and m ~= FEMALE then
        return Notify('Le coiffeur ne peut coiffer qu\'un personnage personnalisé (freemode).', 'error')
    end
    if IsPedInAnyVehicle(p, false) or IsEntityDead(p) then return end

    gender = m == MALE and 'male' or 'female'
    shop = data
    orig = snapshot(p)
    state, preview, inCart = copy(orig), nil, {}

    ClearPedTasks(p)
    FreezeEntityPosition(p, true)
    hideAccessories(p)
    radarWas = not IsRadarHidden()
    DisplayRadar(false)
    startCamera(p)

    hairInfo = scanHair(p)
    local counts = { hair = hairInfo.count }
    for name, ov in pairs(OVERLAY) do counts[name] = GetPedHeadOverlayNum(ov.index) end

    BarberOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'barber', open = true,
        shop = data,
        gender = gender,
        counts = counts,
        palettes = getPalettes(),
        current = orig,
        catalog = getCatalog(gender),
        hairList = hairInfo.list,      -- coupes utilisables : { v = n° global, t = nb de textures, c = collection, l = n° dans la collection }
    })
    frameLoop()
end)

-- Tête à enregistrer : coupe + texture + collection du pack (pour la retrouver même si les n° changent)
local function lookOf(st)
    local look = copy(st)
    look.model = gender
    local e = hairInfo and hairInfo.byIndex[st.hair]
    look.hairTex = st.hairTex or 0
    if e and e.c then look.hairCol, look.hairLi = e.c, e.l else look.hairCol, look.hairLi = nil, nil end
    return look
end

-- ---------------------------------------------------------
--  Callbacks de l'interface
-- ---------------------------------------------------------
RegisterNUICallback('barber_preview', function(d, cb)
    cb('ok')
    if not BarberOpen or awaiting then return end
    local key = d.key
    local v = key and GROUP[key] and d.value ~= nil and normalize(key, d.value) or nil
    local old = preview
    if v == nil then
        preview = nil
        if old then applyGroup(GROUP[old.key]) end
        return
    end
    preview = { key = key, value = v, tex = key == 'hair' and tonumber(d.tex) and math.floor(d.tex) or nil }
    if old and GROUP[old.key] ~= GROUP[key] then applyGroup(GROUP[old.key]) end
    applyGroup(GROUP[key])
end)

RegisterNUICallback('barber_set', function(d, cb)
    cb('ok')
    if not BarberOpen or awaiting or not GROUP[d.key] then return end
    local v = normalize(d.key, d.value)
    if v == nil then return end
    if d.key == 'hair' and not (hairInfo and hairInfo.byIndex[v]) then return hairFailed(v, 'absente') end
    state[d.key] = v
    if d.key == 'hair' then state.hairTex = math.max(0, math.floor(tonumber(d.tex) or 0)) end
    inCart[d.key] = true
    preview = nil
    applyGroup(GROUP[d.key])
end)

RegisterNUICallback('barber_unset', function(d, cb)
    cb('ok')
    if not BarberOpen or awaiting or not GROUP[d.key] then return end
    state[d.key] = copy({ v = orig[d.key] }).v
    if d.key == 'hair' then state.hairTex = orig.hairTex end
    inCart[d.key] = nil
    preview = nil
    applyGroup(GROUP[d.key])
end)

RegisterNUICallback('barber_reset', function(_, cb)
    cb('ok')
    if not BarberOpen or awaiting then return end
    state, preview, inCart = copy(orig), nil, {}
    applyAll()
end)

RegisterNUICallback('barber_close', function(_, cb)
    cb('ok')
    if awaiting then return end
    closeBarber(true)
end)

RegisterNUICallback('barber_rotate', function(d, cb)
    cb('ok')
    if not BarberOpen then return end
    local p = PlayerPedId()
    SetEntityHeading(p, GetEntityHeading(p) + math.max(-45.0, math.min(45.0, tonumber(d.d) or 0.0)))
end)

RegisterNUICallback('barber_spin', function(d, cb)
    cb('ok')
    spin = math.max(-1, math.min(1, math.floor(tonumber(d.dir) or 0)))
end)

RegisterNUICallback('barber_zoom', function(d, cb)
    cb('ok')
    zoom = math.max(0.55, math.min(1.9, zoom + (tonumber(d.d) or 0) * 0.08))
end)

RegisterNUICallback('barber_cam', function(d, cb)
    cb('ok')
    if CAMS[d.mode] then camMode, zoom = d.mode, 1.0 end
end)

RegisterNUICallback('barber_pay', function(d, cb)
    cb('ok')
    if not BarberOpen or awaiting or not shop then return end
    local cart, n = {}, 0
    for key in pairs(inCart) do cart[key] = state[key] n = n + 1 end
    if n == 0 then return SendNUIMessage({ action = 'barber', event = 'payfail', msg = 'Ton panier est vide.' }) end
    local look = lookOf(state)
    awaiting = true
    TriggerServerEvent('adminmenu:barber:pay', shop.id, cart, look, d.method == 'bank' and 'bank' or 'cash')
    SetTimeout(10000, function()
        if awaiting and BarberOpen then
            awaiting = false
            SendNUIMessage({ action = 'barber', event = 'payfail', msg = 'Le serveur ne répond pas, réessaie.' })
        end
    end)
end)

-- ---------------------------------------------------------
--  Enregistrement de la nouvelle tête
-- ---------------------------------------------------------
-- La tête est enregistrée par le serveur lors du paiement et remise à chaque apparition
local function saveMode() return 'internal' end

local function saveAppearance(look)
    TriggerEvent('adminmenu:barber:saved', look, 'internal')
end

RegisterNetEvent('adminmenu:barber:result', function(ok, msg)
    if not BarberOpen then return end
    awaiting = false
    if not ok then
        return SendNUIMessage({ action = 'barber', event = 'payfail', msg = msg or 'Paiement refusé.' })
    end
    preview = nil
    restoreAccessories()            -- remis AVANT l'enregistrement pour ne pas perdre le chapeau
    applyAll()
    local look = lookOf(state)
    orig = copy(state)              -- la nouvelle tête devient la tête d'origine
    saveAppearance(look)
    SendNUIMessage({ action = 'barber', event = 'paid', msg = msg })
    SetTimeout(900, function() closeBarber(false) end)
    if saveMode() == 'internal' then SavedLook = look end
    Notify(msg or 'Nouvelle tête enregistrée !', 'success')
end)

-- ---------------------------------------------------------
--  Mode interne : la tête est remise à chaque spawn / chargement
-- ---------------------------------------------------------
SavedLook = nil
local reapplyToken = 0

local function reapply(delays)
    if saveMode() ~= 'internal' or not SavedLook then return end
    reapplyToken = reapplyToken + 1
    local token = reapplyToken
    for _, ms in ipairs(delays) do
        SetTimeout(ms, function()
            if token == reapplyToken and not BarberOpen then applyLook(SavedLook) end
        end)
    end
end

RegisterNetEvent('adminmenu:barber:look', function(look)
    SavedLook = look
    reapply({ 0, 2500, 7000 })
end)

local function requestLook()
    if saveMode() ~= 'internal' then return end
    SetTimeout(1500, function() TriggerServerEvent('adminmenu:barber:getLook') end)
end

RegisterNetEvent('elyzea:client:playerLoaded', requestLook)
-- ely_creator vient de remettre l'apparence : on remet la coupe par-dessus
AddEventHandler('ely_creator:loaded', function() reapply({ 600, 2000 }) end)
AddEventHandler('ely_creator:created', function() reapply({ 600, 2000 }) end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() and NetworkIsPlayerActive(PlayerId()) then requestLook() end
end)

-- ---------------------------------------------------------
--  Blips des salons posés dans l'éditeur
-- ---------------------------------------------------------
local blips = {}
function RefreshBarberBlips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    if CFG.enabled == false then return end
    for _, r in ipairs((Editor and Editor.peds) or {}) do
        local bb = r.npc and r.npc.barber
        if bb and bb.blip then
            local b = AddBlipForCoord(r.x + 0.0, r.y + 0.0, r.z + 0.0)
            SetBlipSprite(b, bb.blipSprite or CFG.blipSprite or 71)
            SetBlipColour(b, bb.blipColor or CFG.blipColor or 4)
            SetBlipScale(b, CFG.blipScale or 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(bb.name or 'Coiffeur')
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    if BarberOpen then closeBarber(true) end
end)

-- Données pour la carte « Coiffeur » de l'éditeur (services et liste des prix tirés du catalogue)
function BarberAdminConfig()
    local list = {}
    for _, t in ipairs(BarberData.tabs) do
        for _, m in ipairs(t.modes) do list[#list + 1] = { k = m.key, s = t.service, label = m.cart or m.label } end
    end
    return {
        prices = CFG.defaultPrices or {}, services = BarberData.services, priceList = list,
        blipSprite = CFG.blipSprite or 71, blipColor = CFG.blipColor or 4,
    }
end

-- Résultat du diagnostic des packs (serveur) affiché dans la console F8
RegisterNetEvent('adminmenu:barber:debug', function(msg)
    if CFG.debug and type(msg) == 'string' then print('^5[Salon]^7 ' .. msg) end
end)

exports('IsBarberOpen', function() return BarberOpen end)
