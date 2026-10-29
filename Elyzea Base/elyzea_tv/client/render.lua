-- =====================================================================
--  ELYZEA TV - rendu : pages vidéo (DUI), écran des télés du jeu, écrans du staff, son selon la distance
--  · Une page vidéo (html/player.html, lecteur YouTube) par écran allumé et proche, au maximum Config.Player.maxActive.
--  · Télés à écran plat : l'image est dessinée sur l'écran d'origine du modèle (« render target » du jeu).
--  · Écrans du staff : rectangle texturé dans le monde (DrawTexturedPoly), à la position et la taille choisies.
--  · Son : le volume de chaque page suit la distance de la caméra à l'écran.
-- =====================================================================
local C = Config
local P = C.Player
local TXD_NAME = 'elyzea_tv'
local txd = CreateRuntimeTxd(TXD_NAME)
local URL = ('https://cfx-nui-%s/html/player.html'):format(GetCurrentResourceName())

-- texture d'un écran éteint (couleur unie)
do
    local ic = C.Custom.idleColor or { 8, 8, 12 }
    local t = CreateRuntimeTexture(txd, 'idle', 4, 4)
    for x = 0, 3 do for y = 0, 3 do SetRuntimeTexturePixel(t, x, y, ic[1], ic[2], ic[3], 255) end end
    CommitRuntimeTexture(t)
    -- mire de test (/tv_test) : 8 bandes de couleur
    local bars = { { 255, 255, 255 }, { 255, 255, 0 }, { 0, 255, 255 }, { 0, 255, 0 }, { 255, 0, 255 }, { 255, 0, 0 }, { 0, 0, 255 }, { 20, 20, 20 } }
    local m = CreateRuntimeTexture(txd, 'mire', 64, 36)
    for x = 0, 63 do
        local c = bars[math.floor(x / 8) + 1]
        for y = 0, 35 do SetRuntimeTexturePixel(m, x, y, c[1], c[2], c[3], 255) end
    end
    CommitRuntimeTexture(m)
end

-- Dessin d'un triangle texturé dans le monde (DRAW_TEXTURED_POLY, ancien nom _DRAW_SPRITE_POLY).
-- Appelé par son identifiant : le nom de la fonction change selon la version de FiveM, l'identifiant jamais.
-- Les nombres sont forcés en décimaux (sinon 1 serait lu comme un minuscule nombre à virgule).
local POLY = 0x29280002282F1928
local function poly(a, b, c, alpha, tex, ua, va, ub, vb, uc, vc)
    Citizen.InvokeNative(POLY, a.x + 0.0, a.y + 0.0, a.z + 0.0, b.x + 0.0, b.y + 0.0, b.z + 0.0, c.x + 0.0, c.y + 0.0, c.z + 0.0,
        255, 255, 255, math.floor(alpha or 255), TXD_NAME, tex, ua + 0.0, va + 0.0, 1.0, ub + 0.0, vb + 0.0, 1.0, uc + 0.0, vc + 0.0, 1.0)
end
TVC.Poly = poly
-- erreurs d'affichage : montrées une fois dans F8 (et dans /tv_debug), sans jamais arrêter l'affichage
TVC.drawErrors = {}
local function guard(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        if not TVC.drawErrors[what] then print(('^1[elyzea_tv] affichage (%s) : %s^0'):format(what, tostring(err))) end
        TVC.drawErrors[what] = tostring(err)
    end
    return ok
end

local duis = {}       -- [clé] = { dui, tex, at, vid, vol, lastSync }
local texSeq = 0
local function send(d, msg) SendDuiMessage(d.dui, json.encode(msg)) end
local function ensure(key)
    local d = duis[key]
    if d then return d end
    local dui = CreateDui(URL, P.width, P.height)
    if not dui then return nil end
    texSeq = texSeq + 1
    local name = 'v' .. texSeq
    CreateRuntimeTextureFromDuiHandle(txd, name, GetDuiHandle(dui))
    d = { dui = dui, tex = name, vol = -1, lastSync = 0 }
    duis[key] = d
    TVC.Dbg('page vidéo créée', key)
    return d
end
local function destroy(key)
    local d = duis[key]
    if not d then return end
    pcall(function() send(d, { type = 'stop' }) end)
    DestroyDui(d.dui)
    duis[key] = nil
    TVC.Dbg('page vidéo détruite', key)
end
TVC.Duis = duis

-- ---------------------------------------------------------------- où sont les écrans
-- renvoie position, portée du son, distance d'affichage
local function where(key)
    local id = tostring(key):match('^s(%d+)$')
    if id then
        local s = TVC.screens[tonumber(id)]
        if not s then return nil end
        local d = s.data
        local range = d.range or C.Custom.defaultRange
        return vector3(d.x, d.y, d.z), range, math.max(80.0, range * 2.0), s
    end
    local f = TVC.ParseKey(key)
    if not f then return nil end
    return vector3(f.x, f.y, f.z), C.Flat.soundRange, C.Flat.renderRange, nil
end
TVC.Where = where

local function falloff(dist, range)
    if dist >= range then return 0.0 end
    return (1.0 - dist / range) ^ 1.5
end

-- ---------------------------------------------------------------- gestion des pages (3 fois par seconde)
local active = {}      -- liste triée des écrans affichés : { key, pos, dist, ent }
local dirty = true
function TVC.OnState() dirty = true end
function TVC.OnScreens() dirty = true end

local function manage()
    local cam = GetFinalRenderedCamCoord()
    local list = {}
    for key, st in pairs(TVC.states) do
        if st and st.id then
            local pos, range, show = where(key)
            if pos then
                local dist = #(cam - pos)
                if dist <= show then
                    local ent = nil
                    if not key:match('^s%d+$') then ent = TVC.FlatEntity(key) end
                    if key:match('^s%d+$') or ent then list[#list + 1] = { key = key, pos = pos, dist = dist, range = range, ent = ent, st = st } end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local keep = {}
    for i = 1, math.min(#list, P.maxActive) do keep[list[i].key] = list[i] end
    for key in pairs(duis) do if not keep[key] then destroy(key) end end
    active = {}
    for i = 1, math.min(#list, P.maxActive) do
        local e = list[i]
        local d = ensure(e.key)
        if d then
            e.d = d
            active[#active + 1] = e
            if IsDuiAvailable(d.dui) then
                local st = e.st
                -- nouvelle vidéo ou changement (pause, reprise, avance) : la page se recale sur l'heure commune
                if d.vid ~= st.id or d.at ~= st.at then
                    send(d, { type = 'load', id = st.id, at = TVC.Position(st), paused = st.paused == true })
                    d.vid, d.at, d.lastSync = st.id, st.at, GetGameTimer()
                elseif GetGameTimer() - d.lastSync > P.syncEvery * 1000 then
                    send(d, { type = 'sync', at = TVC.Position(st), paused = st.paused == true })
                    d.lastSync = GetGameTimer()
                end
                local vol = (st.volume or 0) / 100 * P.masterVolume * falloff(e.dist, e.range)
                if math.abs(vol - d.vol) > 0.015 then send(d, { type = 'volume', v = math.floor(vol * 1000) / 1000 }) d.vol = vol end
            end
        end
    end
    dirty = false
end
CreateThread(function()
    while true do
        local ok, err = pcall(manage)
        if not ok then print('^1[elyzea_tv] ' .. tostring(err) .. '^0') end
        local t = 0
        while t < 300 and not dirty do Wait(50) t = t + 50 end
    end
end)

-- ---------------------------------------------------------------- écran d'origine des télés du jeu (render target)
local rts = {}         -- [hash du modèle] = { name, id, linked }
TVC.RTs = rts
local function rtFor(model)
    if rts[model] ~= nil then return rts[model] end
    local info = TVC.flat[model]
    local names = { info and info.rt or 'tvscreen' }
    for _, n in ipairs(C.RenderTargets or {}) do if n ~= names[1] then names[#names + 1] = n end end
    for _, name in ipairs(names) do
        if not IsNamedRendertargetRegistered(name) then RegisterNamedRendertarget(name, false) end
        if not IsNamedRendertargetLinked(model) then LinkNamedRendertarget(model) end
        local id = IsNamedRendertargetRegistered(name) and GetNamedRendertargetRenderId(name) or -1
        -- on ne refuse pas l'écran si le jeu ne confirme pas le lien : beaucoup de télés marchent quand même
        if id and id ~= -1 and id ~= 0 then
            rts[model] = { name = name, id = id, linked = IsNamedRendertargetLinked(model) == true }
            TVC.Dbg('écran du modèle', info and info.model, '→', name, 'id', id, 'lié', rts[model].linked)
            return rts[model]
        end
    end
    rts[model] = false
    return false
end

-- ---------------------------------------------------------------- image posée sur la face avant de la télé
-- Calculée d'après la taille du modèle : écran 16:9 en haut de la télé (les pieds / socles sont en bas),
-- sur la grande face tournée vers la caméra, 1 cm devant.
local geom = {}
local function screenGeom(ent)
    local m = TVC.s32(GetEntityModel(ent))
    local g = geom[m]
    if g then return g end
    local mn, mx = GetModelDimensions(GetEntityModel(ent))
    if not mn then return nil end
    local info = TVC.flat[m] or {}
    local sx, sy, sz = mx.x - mn.x, mx.y - mn.y, mx.z - mn.z
    local longX = sx >= sy
    local W = longX and sx or sy
    local margin = (C.Flat.margin or 0.035) * W
    local w, h, cz
    local o = info.screen
    if o and o.w and o.h then
        w, h, cz = o.w, o.h, o.z or (mn.z + mx.z) / 2
    else
        w = W - 2 * margin
        h = w * 9 / 16
        if h > sz - 2 * margin then h = sz - 2 * margin w = h * 16 / 9 end
        cz = mx.z - margin - h / 2
    end
    local cl = (o and o.x) or 0.0
    g = { longX = longX, mn = mn, mx = mx, w = w, h = h, cz = cz, cl = cl,
        cx = (mn.x + mx.x) / 2, cy = (mn.y + mx.y) / 2 }
    geom[m] = g
    return g
end
local function drawOverlay(ent, tex)
    local g = screenGeom(ent)
    if not g then return end
    local cam = GetFinalRenderedCamCoord()
    local lc = GetOffsetFromEntityGivenWorldCoords(ent, cam.x, cam.y, cam.z)
    -- face tournée vers la caméra (normale n), centre de l'écran sur cette face
    local nx, ny, fx, fy
    if g.longX then
        nx, ny = 0.0, (lc.y >= g.cy) and 1.0 or -1.0
        fx, fy = g.cx + g.cl, (ny > 0 and g.mx.y or g.mn.y) + ny * 0.01
    else
        nx, ny = (lc.x >= g.cx) and 1.0 or -1.0, 0.0
        fx, fy = (nx > 0 and g.mx.x or g.mn.x) + nx * 0.01, g.cy + g.cl
    end
    local lx, ly = ny, -nx          -- la gauche de l'image, vue de face
    local hw, hh = g.w / 2, g.h / 2
    local function at(sx, sz)
        return GetOffsetFromEntityInWorldCoords(ent, fx + lx * sx, fy + ly * sx, g.cz + sz)
    end
    local tl, tr, bl, br = at(hw, hh), at(-hw, hh), at(hw, -hh), at(-hw, -hh)
    local function tri(a, b, c, ua, va, ub, vb, uc, vc) poly(a, b, c, 255, tex, ua, va, ub, vb, uc, vc) end
    tri(tl, tr, br, 0, 0, 1, 0, 1, 1) tri(tl, br, bl, 0, 0, 1, 1, 0, 1)
    tri(tl, br, tr, 0, 0, 1, 1, 1, 0) tri(tl, bl, br, 0, 0, 0, 1, 1, 1)
end
TVC.DrawFlatOverlay = drawOverlay

local usedRT = {}
local function releaseUnused(now)
    for name, used in pairs(usedRT) do
        if not now[name] then
            if IsNamedRendertargetRegistered(name) then ReleaseNamedRendertarget(name) end
            usedRT[name] = nil
            for m, r in pairs(rts) do if r and r.name == name then rts[m] = nil end end
        end
    end
end

-- ---------------------------------------------------------------- écrans du staff (rectangle dans le monde)
local function corners(d, back)
    local h = math.rad(d.h or 0.0)
    local rx, ry = math.cos(h), math.sin(h)            -- « droite » du repère de l'écran
    local fx, fy = -math.sin(h), math.cos(h)           -- avant de l'écran
    local hw, hh = d.w / 2, d.hgt / 2
    -- deux faces à 2 cm l'une de l'autre, chacune avec l'image : on la voit de face comme de dos
    local o = back and -0.01 or 0.01
    local cx, cy, cz = d.x + fx * o, d.y + fy * o, d.z
    -- vue de devant, la gauche de l'image est du côté +droite ; vue de derrière, c'est l'inverse (image non inversée)
    local s = back and -1 or 1
    return vector3(cx + s * rx * hw, cy + s * ry * hw, cz + hh), vector3(cx - s * rx * hw, cy - s * ry * hw, cz + hh),
        vector3(cx + s * rx * hw, cy + s * ry * hw, cz - hh), vector3(cx - s * rx * hw, cy - s * ry * hw, cz - hh)
end
local function tri(a, b, c, tex, ua, va, ub, vb, uc, vc, alpha) poly(a, b, c, alpha, tex, ua, va, ub, vb, uc, vc) end
local function face(tl, tr, bl, br, tex, alpha)
    -- les deux sens de tracé : visible quel que soit le sens d'affichage du jeu
    tri(tl, tr, br, tex, 0, 0, 1, 0, 1, 1, alpha) tri(tl, br, bl, tex, 0, 0, 1, 1, 0, 1, alpha)
    tri(tl, br, tr, tex, 0, 0, 1, 1, 1, 0, alpha) tri(tl, bl, br, tex, 0, 0, 0, 1, 1, 1, alpha)
end
-- dessine un écran : l'image sur ses DEUX faces (plus de dos noir : impossible de la mettre « du mauvais côté »)
function TVC.DrawScreen(d, tex, alpha)
    tex = tex or 'idle'
    local btl, btr, bbl, bbr = corners(d, true)
    face(btl, btr, bbl, bbr, tex, alpha)
    local tl, tr, bl, br = corners(d, false)
    face(tl, tr, bl, br, tex, alpha)
end

-- ---------------------------------------------------------------- dessin, chaque image
local function drawRT(x)
    SetTextRenderId(x.rt.id)
    SetScriptGfxDrawOrder(4)
    SetScriptGfxDrawBehindPausemenu(true)
    DrawSprite(TXD_NAME, x.e.d.tex, 0.5, 0.5, 1.0, 1.0, 0.0, 255, 255, 255, 255)
    SetTextRenderId(GetDefaultScriptRendertargetRenderId())
end
local function frame()
    local sleep = 500
    local cam = GetFinalRenderedCamCoord()
    local playing = {}
    for _, e in ipairs(active) do playing[e.key] = e end
    -- 1. télés du jeu : d'abord l'écran d'origine du modèle (une image par modèle : la télé la plus proche)
    local mode = C.Flat.display or 'both'
    local flats, byRT, now = {}, {}, {}
    for _, e in ipairs(active) do
        if e.ent and DoesEntityExist(e.ent) and e.d and IsDuiAvailable(e.d.dui) then
            flats[#flats + 1] = e
            if mode ~= 'overlay' then
                guard('écran d\'origine', function()
                    local rt = rtFor(TVC.s32(GetEntityModel(e.ent)))
                    if rt and not byRT[rt.name] then byRT[rt.name] = { rt = rt, e = e } end
                end)
            end
        end
    end
    for name, x in pairs(byRT) do
        sleep = 0
        now[name] = true
        usedRT[name] = true
        if not guard('écran d\'origine', drawRT, x) then SetTextRenderId(GetDefaultScriptRendertargetRenderId()) end
    end
    guard('libération', releaseUnused, now)
    -- 2. puis l'image posée sur la face avant de chaque télé
    if mode ~= 'rendertarget' then
        for _, e in ipairs(flats) do sleep = 0 guard('face avant', drawOverlay, e.ent, e.d.tex) end
    end
    -- mire de test (/tv_test) sur la télé la plus proche
    if TVC.test and GetGameTimer() < TVC.test.untilAt and DoesEntityExist(TVC.test.ent) then
        sleep = 0
        local rt = rtFor(TVC.s32(GetEntityModel(TVC.test.ent)))
        if rt then guard('mire (écran d\'origine)', drawRT, { rt = rt, e = { d = { tex = 'mire' } } }) usedRT[rt.name] = true now[rt.name] = true end
        guard('mire (face avant)', drawOverlay, TVC.test.ent, 'mire')
    elseif TVC.test then TVC.test = nil end
    -- 3. écrans du staff : allumés (vidéo) ou éteints (couleur unie), à portée de vue
    for id, s in pairs(TVC.screens) do
        local d = s.data
        if not (TVC.editing and TVC.editing.id == id) then
            local dist = #(cam - vector3(d.x, d.y, d.z))
            if dist < math.max(150.0, (d.range or 45) * 3) then
                sleep = 0
                local e = playing['s' .. id]
                local tex = (e and e.d and IsDuiAvailable(e.d.dui)) and e.d.tex or nil
                guard('écran du staff', TVC.DrawScreen, d, tex)
            end
        end
    end
    return sleep
end
CreateThread(function()
    while true do
        local ok, sleep = pcall(frame)
        if not ok then
            if not TVC.drawErrors.boucle then print('^1[elyzea_tv] affichage : ' .. tostring(sleep) .. '^0') end
            TVC.drawErrors.boucle = tostring(sleep)
            sleep = 250
        end
        Wait(sleep)
    end
end)

-- /tv_test : mire de couleurs 10 s sur la télé la plus proche, sans YouTube (vérifie l'affichage seul)
RegisterCommand('tv_test', function()
    local me = GetEntityCoords(PlayerPedId())
    local best, bd
    for _, o in ipairs(TVC.nearFlat or {}) do
        if DoesEntityExist(o) then local d = #(GetEntityCoords(o) - me) if not bd or d < bd then best, bd = o, d end end
    end
    if not best then return TVC.Notify('Aucune télé à écran plat à moins de 30 m.', 'error') end
    TVC.test = { ent = best, untilAt = GetGameTimer() + 10000 }
    TVC.Notify('Mire de test sur la télé pendant 10 s (bandes de couleur).', 'inform')
end, false)

-- /tv_debug : état de l'affichage de la télé la plus proche (à copier depuis la console F8 si l'image ne s'affiche pas)
RegisterCommand('tv_debug', function()
    local me = GetEntityCoords(PlayerPedId())
    local best, bd
    for _, o in ipairs(TVC.nearFlat or {}) do
        if DoesEntityExist(o) then local d = #(GetEntityCoords(o) - me) if not bd or d < bd then best, bd = o, d end end
    end
    if not best then print('[elyzea_tv] aucune télé à écran plat à moins de 30 m') return end
    local m = TVC.s32(GetEntityModel(best))
    local info = TVC.flat[m] or {}
    local rt = rtFor(m)
    local key = TVC.FlatKey(best)
    local g = screenGeom(best)
    print(('[elyzea_tv] télé %s à %.1f m · clé %s'):format(info.model or '?', bd, key))
    print(('  affichage %s · écran d\'origine : %s'):format(C.Flat.display or 'both', rt and ('%s id %s lié %s'):format(rt.name, tostring(rt.id), tostring(rt.linked)) or 'indisponible'))
    if g then print(('  image sur la face avant : %.2f × %.2f m'):format(g.w, g.h)) end
    local st = TVC.states[key]
    local d = duis[key]
    for what, err in pairs(TVC.drawErrors) do print(('  ^1erreur (%s) : %s^0'):format(what, err)) end
    if not next(TVC.drawErrors) then print('  aucune erreur d\'affichage') end
    print(('  vidéo : %s · page : %s'):format(st and st.id or 'aucune', d and (IsDuiAvailable(d.dui) and ('prête (' .. d.tex .. ')') or 'en chargement') or 'fermée'))
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(duis) do destroy(key) end
    for name in pairs(usedRT) do if IsNamedRendertargetRegistered(name) then ReleaseNamedRendertarget(name) end end
end)
