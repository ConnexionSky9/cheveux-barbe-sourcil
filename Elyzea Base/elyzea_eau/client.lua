-- =========================================================
--  ELYZEA EAU : vraie eau posée en direct + éditeur d'eau (Fondateur)
--
--  /eau_editeur
--    Clic gauche (ou E)   : poser un coin
--    Clic droit (ou Retour arrière) : retirer le dernier coin / fermer
--    R                    : rectangle (2 coins) ou forme libre (autant de coins que voulu)
--    Molette / flèches    : hauteur de l'eau (Maj = 1 m)
--    H                    : hauteur de l'eau = point visé
--    Entrée               : enregistrer
--  /eau_ajouter [taille] [hauteur] · /eau_liste · /eau_supprimer <n°> · /eau_annuler
--
--  Eau en direct : water.xml contient une réserve de zones d'eau cachées sous le mont
--  Chiliad. Le jeu les charge au démarrage ; ce script les déplace sur les zones dessinées.
-- =========================================================
local P = EauGeo.POOL
local K = {
    click = 24, corner = 38,          -- clic gauche, E
    undo = 25, undo2 = 177,           -- clic droit, Retour arrière
    mode = 45,                        -- R
    level = 74,                       -- H
    finish = 191,                     -- Entrée
    up = 241, down = 242, up2 = 172, down2 = 173,
    fast = 21,                        -- Maj
}

-- Touche appuyée, qu'elle soit active ou désactivée par un autre script (le noclip désactive tout)
local function pressed(c) return IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c) end
local function held(c) return IsControlPressed(0, c) or IsDisabledControlPressed(0, c) end
local function say(msg) TriggerEvent('chat:addMessage', { args = { 'Eau', msg } }) end

-- =========================================================
--  EAU EN DIRECT
-- =========================================================
local Live = {
    natives = GetWaterQuadCount ~= nil and GetWaterQuadBounds ~= nil and SetWaterQuadBounds ~= nil and SetWaterQuadLevel ~= nil,
    pool = {},        -- index des zones de la réserve trouvées dans le jeu
    poolSet = {},
    zones = {},       -- zones enregistrées (serveur)
    preview = nil,    -- { rects, z } pendant l'édition
    scanned = false,
    used = 0,
}

local function readBounds(i)
    local r = { pcall(GetWaterQuadBounds, i) }
    if not r[1] then return nil end
    -- r = { true, succès, minX, minY, maxX, maxY }
    if r[2] == false or r[3] == nil then return nil end
    return { minX = math.floor(r[3] + 0.5), minY = math.floor(r[4] + 0.5), maxX = math.floor(r[5] + 0.5), maxY = math.floor(r[6] + 0.5) }
end

-- Retrouve la réserve dans l'eau chargée par le jeu
local function scanPool()
    Live.scanned = true
    Live.pool, Live.poolSet = {}, {}
    if not Live.natives then return end
    local want = {}
    for i = 1, P.count do
        local s = EauGeo.PoolSlot(i)
        want[s.minX .. ':' .. s.minY] = i
    end
    local ok, count = pcall(GetWaterQuadCount)
    if not ok or not count then return end
    local found = {}
    for q = 0, count - 1 do
        local b = readBounds(q)
        if b and b.maxX - b.minX == P.size and b.maxY - b.minY == P.size then
            local slot = want[b.minX .. ':' .. b.minY]
            if slot then found[slot] = q end
        end
    end
    for i = 1, P.count do
        if found[i] then Live.pool[#Live.pool + 1] = found[i] Live.poolSet[found[i]] = true end
    end
    Live.total = count
end

local function park(k, q)
    local s = EauGeo.PoolSlot(k)
    SetWaterQuadBounds(q, s.minX, s.minY, s.maxX, s.maxY)
    SetWaterQuadLevel(q, P.z)
end

-- Ce rectangle existe-t-il déjà dans le fichier d'eau (zone gardée après un redémarrage) ?
local function inFile(r)
    if not GetWaterQuadAtCoords then return false end
    local ok, q = pcall(GetWaterQuadAtCoords, (r.minX + r.maxX) / 2.0, (r.minY + r.maxY) / 2.0)
    if not ok or not q or q < 0 or Live.poolSet[q] then return false end
    local b = readBounds(q)
    return b ~= nil and b.minX == r.minX and b.maxX == r.maxX and b.minY == r.minY and b.maxY == r.maxY
end

-- Pose toutes les zones (enregistrées + aperçu) sur la réserve
local function applyLive()
    if not Live.natives or #Live.pool == 0 then return end
    local n = 0
    local function put(r, z)
        n = n + 1
        local q = Live.pool[n]
        if not q then return end
        SetWaterQuadBounds(q, r.minX, r.minY, r.maxX, r.maxY)
        SetWaterQuadLevel(q, z + 0.0)
    end
    for _, zone in ipairs(Live.zones) do
        for _, r in ipairs(zone.rects or {}) do
            if not r._file then put(r, zone.z) end
        end
    end
    if Live.preview then
        for _, r in ipairs(Live.preview.rects) do put(r, Live.preview.z) end
    end
    Live.used = n
    for k = n + 1, #Live.pool do park(k, Live.pool[k]) end
end

-- Zones retirées : si elles étaient déjà dans le fichier d'eau, on les enfouit tout de suite
local function buryRemoved(old, new)
    if not GetWaterQuadAtCoords then return end
    local keep = {}
    for _, z in ipairs(new) do for _, r in ipairs(z.rects or {}) do keep[('%d:%d:%d:%d'):format(r.minX, r.minY, r.maxX, r.maxY)] = true end end
    for _, z in ipairs(old) do
        for _, r in ipairs(z.rects or {}) do
            if r._file and not keep[('%d:%d:%d:%d'):format(r.minX, r.minY, r.maxX, r.maxY)] then
                local ok, q = pcall(GetWaterQuadAtCoords, (r.minX + r.maxX) / 2.0, (r.minY + r.maxY) / 2.0)
                if ok and q and q >= 0 and not Live.poolSet[q] then SetWaterQuadLevel(q, P.z) end
            end
        end
    end
end

RegisterNetEvent('elyzea_eau:zones', function(zones)
    if not Live.scanned then scanPool() end
    if not ed then Live.preview = nil end   -- zone enregistrée : elle fait maintenant partie des zones
    zones = zones or {}
    for _, z in ipairs(zones) do
        for _, r in ipairs(z.rects or {}) do r._file = inFile(r) end
    end
    buryRemoved(Live.zones, zones)
    Live.zones = zones
    applyLive()
end)

CreateThread(function()
    -- L'eau du jeu est chargée avec la carte : on attend le personnage
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(3000)
    scanPool()
    TriggerServerEvent('elyzea_eau:report', { natives = Live.natives, pool = #Live.pool, total = Live.total or 0 })
    TriggerServerEvent('elyzea_eau:zones:get')
end)

-- État de l'eau en direct (affiché dans l'éditeur et par /eau_etat)
local function liveStatus()
    if not Live.natives then return false, 'Ta version de FiveM ne permet pas de modifier l\'eau en direct : l\'eau apparaîtra après un redémarrage.' end
    if #Live.pool == 0 then
        return false, ('Le fichier d\'eau du serveur N\'EST PAS chargé par ton jeu (%s zones d\'eau). Redémarre tout le serveur, puis reconnecte-toi.'):format(tostring(Live.total or '?'))
    end
    return true, ('Eau en direct : OK (%d/%d zones de réserve utilisées)'):format(Live.used, #Live.pool)
end

RegisterCommand('eau_etat', function()
    scanPool()
    applyLive()
    local _, msg = liveStatus()
    say(msg)
end, false)

-- =========================================================
--  ÉDITEUR
-- =========================================================
local ed = nil

RegisterCommand('eau_ajouter', function(_, args)
    local c = GetEntityCoords(PlayerPedId())
    local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    TriggerServerEvent('elyzea_eau:add', tonumber(args[1]), tonumber(args[2]), ok and gz or nil)
end, false)
RegisterCommand('eau_annuler', function() TriggerServerEvent('elyzea_eau:undo') end, false)
RegisterCommand('eau_liste', function() TriggerServerEvent('elyzea_eau:list') end, false)
RegisterCommand('eau_supprimer', function(_, args) TriggerServerEvent('elyzea_eau:remove', tonumber(args[1])) end, false)
RegisterCommand('eau_editeur', function()
    if ed then ed.close = true return end
    TriggerServerEvent('elyzea_eau:editor:open')
end, false)

local function aimPoint(planeZ)
    local from = GetFinalRenderedCamCoord()
    local rot = GetFinalRenderedCamRot(2)
    local zr, xr = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(xr))
    local dir = vector3(-math.sin(zr) * n, math.cos(zr) * n, math.sin(xr))
    local to = from + dir * 500.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, PlayerPedId(), 7)
    local _, hit, pos = GetShapeTestResult(ray)
    if hit == 1 then return pos end
    -- Rien touché : point du rayon à la hauteur de l'eau
    if planeZ and math.abs(dir.z) > 0.01 then
        local t = (planeZ - from.z) / dir.z
        if t > 0 and t < 1500.0 then
            local p = from + dir * t
            local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, planeZ + 50.0, false)
            return vector3(p.x, p.y, ok and gz or planeZ)
        end
    end
    return nil
end

local function text(x, y, s, scale, r, g, b)
    SetTextFont(4)
    SetTextScale(scale or 0.36, scale or 0.36)
    SetTextColour(r or 255, g or 255, b or 255, 235)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(s)
    EndTextCommandDisplayText(x, y)
end

local function outline(r, z, cr, cg, cb, a)
    DrawLine(r.minX, r.minY, z, r.maxX, r.minY, z, cr, cg, cb, a)
    DrawLine(r.maxX, r.minY, z, r.maxX, r.maxY, z, cr, cg, cb, a)
    DrawLine(r.maxX, r.maxY, z, r.minX, r.maxY, z, cr, cg, cb, a)
    DrawLine(r.minX, r.maxY, z, r.minX, r.minY, z, cr, cg, cb, a)
end

local function near(r, p, d) return p.x > r.minX - d and p.x < r.maxX + d and p.y > r.minY - d and p.y < r.maxY + d end

-- Coins de la forme (rectangle : 2 coins opposés → 4 coins)
local function shape(e, extra)
    local pts = {}
    for _, p in ipairs(e.points) do pts[#pts + 1] = p end
    if extra then pts[#pts + 1] = extra end
    if e.mode == 'rect' then
        if #pts < 2 then return pts end
        local a, b = pts[1], pts[2]
        return { { x = a.x, y = a.y }, { x = b.x, y = a.y }, { x = b.x, y = b.y }, { x = a.x, y = b.y } }
    end
    return pts
end

local function refresh(e)
    local pts = shape(e)
    if #pts >= 3 then
        e.rects = EauGeo.Subtract(EauGeo.Rasterize(pts), e.quads)
        Live.preview = { rects = e.rects, z = e.z }
    else
        e.rects = {}
        Live.preview = nil
    end
    applyLive()
end

local function close(msg)
    ed = nil
    Live.preview = nil
    applyLive()
    if msg then say(msg) end
end

local function editorLoop()
    while ed and not ed.close do
        local e = ed
        local me = GetEntityCoords(PlayerPedId())
        for _, c in ipairs({ 24, 25, 14, 15, 16, 17, 37, 44, 45, 74, 140, 141, 142 }) do DisableControlAction(0, c, true) end
        local typing = IsNuiFocused() or IsPauseMenuActive()

        local aim = aimPoint(e.z)
        e.aim = aim

        if not typing then
            -- Hauteur
            local step = held(K.fast) and 1.0 or 0.1
            local dz = 0.0
            if pressed(K.up) or pressed(K.up2) then dz = step end
            if pressed(K.down) or pressed(K.down2) then dz = -step end
            if pressed(K.level) and aim then dz = aim.z - e.z end
            if dz ~= 0.0 then
                e.z = math.floor((e.z + dz) * 100 + 0.5) / 100
                if Live.preview then Live.preview.z = e.z applyLive() end
            end
            -- Mode
            if pressed(K.mode) then
                e.mode = e.mode == 'rect' and 'poly' or 'rect'
                e.points = {}
                refresh(e)
            end
            -- Coin
            if pressed(K.click) or pressed(K.corner) then
                if not aim then
                    PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                else
                    if e.mode == 'rect' and #e.points >= 2 then e.points = {} end   -- nouveau rectangle
                    e.points[#e.points + 1] = { x = aim.x, y = aim.y, gz = aim.z }
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    refresh(e)
                end
            end
            -- Retirer / fermer
            if pressed(K.undo) or pressed(K.undo2) then
                if #e.points > 0 then
                    table.remove(e.points)
                    refresh(e)
                else
                    close('Éditeur d\'eau fermé.')
                    break
                end
            end
            -- Enregistrer
            if pressed(K.finish) then
                local pts = shape(e)
                if #pts < 3 or #e.rects == 0 then
                    PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                else
                    local send = {}
                    for _, p in ipairs(pts) do send[#send + 1] = { x = p.x, y = p.y } end
                    TriggerServerEvent('elyzea_eau:editor:save', send, e.z)
                    ed = nil   -- l'aperçu reste affiché jusqu'à la réponse du serveur (zones)
                    SetTimeout(8000, function() if not ed and Live.preview then Live.preview = nil applyLive() end end)
                    break
                end
            end
        end

        -- Viseur
        if aim then
            DrawMarker(1, aim.x, aim.y, math.min(aim.z, e.z) - 0.2, 0, 0, 0, 0, 0, 0, 0.8, 0.8, math.abs(e.z - aim.z) + 1.2, 255, 210, 80, 170, false, false, 2, false, nil, nil, false)
            DrawMarker(28, aim.x, aim.y, e.z, 0, 0, 0, 0, 0, 0, 0.35, 0.35, 0.35, 80, 200, 255, 230, false, false, 2, false, nil, nil, false)
        end

        -- Eau qui existe déjà autour (bleu clair)
        for _, q in ipairs(e.quads) do
            if near(q, me, 150.0) then outline(q, q.z + 0.05, 120, 220, 255, 140) end
        end

        -- Forme en cours (jaune), qui suit le viseur
        local pts = shape(e, aim and (e.mode == 'poly' or #e.points == 1) and { x = aim.x, y = aim.y } or nil)
        for i, p in ipairs(pts) do
            local nx = pts[i % #pts + 1]
            if nx and #pts >= 2 then DrawLine(p.x, p.y, e.z + 0.08, nx.x, nx.y, e.z + 0.08, 255, 210, 80, 255) end
        end
        for _, p in ipairs(e.points) do
            DrawMarker(1, p.x, p.y, math.min(p.gz, e.z) - 0.3, 0, 0, 0, 0, 0, 0, 0.6, 0.6, math.abs(e.z - p.gz) + 2.0, 255, 210, 80, 220, false, false, 2, false, nil, nil, false)
        end
        -- Contour des morceaux d'eau réellement posés (bleu)
        for _, r in ipairs(e.rects or {}) do
            if near(r, me, 300.0) then outline(r, e.z + 0.03, 40, 140, 230, 200) end
        end

        -- Panneau
        local okLive, liveMsg = liveStatus()
        local depth = aim and (e.z - aim.z) or nil
        local b = #pts >= 2 and EauGeo.Bounds(pts) or nil
        local y = 0.27
        text(0.015, y, '~b~ÉDITEUR D\'EAU~s~  ·  ' .. (e.mode == 'rect' and 'Rectangle (2 coins)' or 'Forme libre'), 0.48) y = y + 0.038
        text(0.015, y, liveMsg, 0.32, okLive and 140 or 255, okLive and 230 or 110, okLive and 140 or 90) y = y + 0.03
        text(0.015, y, ('Hauteur de l\'eau : ~y~%.2f m'):format(e.z)) y = y + 0.03
        if depth then
            if depth > 0.05 then text(0.015, y, ('Profondeur au viseur : ~g~%.2f m'):format(depth))
            else text(0.015, y, ('Sol AU-DESSUS de l\'eau de ~r~%.2f m~s~ au viseur'):format(-depth)) end
            y = y + 0.03
        end
        if b then text(0.015, y, ('Largeur %.0f m · Longueur %.0f m'):format(b.maxX - b.minX, b.maxY - b.minY)) y = y + 0.03 end
        if #e.rects > 0 then text(0.015, y, ('Nouvelle eau : %d m²'):format(EauGeo.Area(e.rects))) y = y + 0.03 end
        y = y + 0.008
        local tip = e.mode == 'rect'
            and (#e.points == 0 and 'Clic gauche : 1er coin' or #e.points == 1 and 'Clic gauche : coin opposé' or 'Clic gauche : recommencer le rectangle')
            or ('Clic gauche : ajouter un coin (%d)'):format(#e.points)
        for _, l in ipairs({
            tip,
            'Clic droit : ' .. (#e.points > 0 and 'retirer le dernier coin' or 'fermer'),
            'Molette : hauteur (Maj = 1 m)  ·  H : hauteur = point visé',
            'R : ' .. (e.mode == 'rect' and 'passer en forme libre' or 'passer en rectangle'),
            'Entrée : enregistrer',
        }) do text(0.015, y, l, 0.32) y = y + 0.026 end
        Wait(0)
    end
    if ed and ed.close then close('Éditeur d\'eau fermé.') end
end

RegisterNetEvent('elyzea_eau:editor:start', function(quads, z)
    if ed then return end
    if not Live.scanned or #Live.pool == 0 then scanPool() applyLive() end
    ed = { points = {}, z = tonumber(z) or 0.0, quads = quads or {}, rects = {}, mode = 'rect' }
    local okLive, liveMsg = liveStatus()
    say(okLive and 'Éditeur d\'eau : clic gauche sur deux coins opposés, la vraie eau apparaît tout de suite. Molette ou H pour la hauteur, Entrée pour enregistrer.' or liveMsg)
    CreateThread(function()
        local ok, err = pcall(editorLoop)
        if not ok then print('^1[EAU] erreur de l\'éditeur : ' .. tostring(err) .. '^0') close() end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not Live.natives then return end
    for k, q in ipairs(Live.pool) do pcall(park, k, q) end
end)
