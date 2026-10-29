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
local rts = {}         -- [hash du modèle] = { name, id } ou false si le modèle n'a pas d'écran utilisable
local function rtFor(model)
    if rts[model] ~= nil then return rts[model] end
    local info = TVC.flat[model]
    local names = { info and info.rt or 'tvscreen' }
    for _, n in ipairs(C.RenderTargets) do if n ~= names[1] then names[#names + 1] = n end end
    for _, name in ipairs(names) do
        if not IsNamedRendertargetRegistered(name) then RegisterNamedRendertarget(name, false) end
        if not IsNamedRendertargetLinked(model) then LinkNamedRendertarget(model) end
        if IsNamedRendertargetLinked(model) then
            local id = GetNamedRendertargetRenderId(name)
            if id and id ~= 0 and id ~= -1 then
                rts[model] = { name = name, id = id }
                TVC.Dbg('écran du modèle', info and info.model, '→', name, id)
                return rts[model]
            end
        end
    end
    rts[model] = false
    TVC.Dbg('aucun écran utilisable pour', info and info.model)
    return false
end
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
    local fx, fy = -math.sin(h), math.cos(h)           -- l'écran regarde vers l'avant (vers le public)
    local hw, hh = d.w / 2, d.hgt / 2
    local o = back and -0.02 or 0.0                    -- dos de l'écran : un peu en retrait
    local cx, cy, cz = d.x + fx * o, d.y + fy * o, d.z
    -- vu de face, la gauche de l'image est du côté +droite du repère
    return vector3(cx + rx * hw, cy + ry * hw, cz + hh), vector3(cx - rx * hw, cy - ry * hw, cz + hh),
        vector3(cx + rx * hw, cy + ry * hw, cz - hh), vector3(cx - rx * hw, cy - ry * hw, cz - hh)
end
local function tri(a, b, c, tex, ua, va, ub, vb, uc, vc, alpha)
    DrawTexturedPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, alpha or 255, TXD_NAME, tex, ua, va, 1.0, ub, vb, 1.0, uc, vc, 1.0)
end
-- dessine un écran : face (image) + dos (écran éteint) ; les deux sens de tracé pour être vu quel que soit le côté
function TVC.DrawScreen(d, tex, alpha)
    local tl, tr, bl, br = corners(d, false)
    tex = tex or 'idle'
    tri(tl, tr, br, tex, 0, 0, 1, 0, 1, 1, alpha) tri(tl, br, bl, tex, 0, 0, 1, 1, 0, 1, alpha)
    tri(tl, br, tr, tex, 0, 0, 1, 1, 1, 0, alpha) tri(tl, bl, br, tex, 0, 0, 0, 1, 1, 1, alpha)
    local btl, btr, bbl, bbr = corners(d, true)
    tri(btl, bbr, btr, 'idle', 0, 0, 1, 1, 1, 0, alpha) tri(btl, bbl, bbr, 'idle', 0, 0, 0, 1, 1, 1, alpha)
    tri(btl, btr, bbr, 'idle', 0, 0, 1, 0, 1, 1, alpha) tri(btl, bbr, bbl, 'idle', 0, 0, 1, 1, 0, 1, alpha)
end

-- ---------------------------------------------------------------- dessin, chaque image
CreateThread(function()
    while true do
        local sleep = 500
        local cam = GetFinalRenderedCamCoord()
        local playing = {}
        for _, e in ipairs(active) do playing[e.key] = e end
        -- écrans du staff : allumés (vidéo) ou éteints (couleur unie), à portée de vue
        for id, s in pairs(TVC.screens) do
            local d = s.data
            if not (TVC.editing and TVC.editing.id == id) then
                local dist = #(cam - vector3(d.x, d.y, d.z))
                if dist < math.max(150.0, (d.range or 45) * 3) then
                    sleep = 0
                    local e = playing['s' .. id]
                    local tex = (e and e.d and IsDuiAvailable(e.d.dui)) and e.d.tex or nil
                    TVC.DrawScreen(d, tex)
                end
            end
        end
        -- télés du jeu : la plus proche en lecture de chaque écran d'origine
        local byRT, now = {}, {}
        for _, e in ipairs(active) do
            if e.ent and DoesEntityExist(e.ent) and e.d and IsDuiAvailable(e.d.dui) then
                local rt = rtFor(TVC.s32(GetEntityModel(e.ent)))
                if rt and not byRT[rt.name] then byRT[rt.name] = { rt = rt, e = e } end
            end
        end
        for name, x in pairs(byRT) do
            sleep = 0
            now[name] = true
            usedRT[name] = true
            SetTextRenderId(x.rt.id)
            SetScriptGfxDrawOrder(4)
            SetScriptGfxDrawBehindPausemenu(true)
            DrawSprite(TXD_NAME, x.e.d.tex, 0.5, 0.5, 1.0, 1.0, 0.0, 255, 255, 255, 255)
            SetTextRenderId(GetDefaultScriptRendertargetRenderId())
        end
        releaseUnused(now)
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(duis) do destroy(key) end
    for name in pairs(usedRT) do if IsNamedRendertargetRegistered(name) then ReleaseNamedRendertarget(name) end end
end)
