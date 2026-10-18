-- =========================================================
--  ELYZEA EAU : éditeur d'eau (Fondateur)
--  /eau_editeur : vise le sol, E pose un coin, molette = hauteur de l'eau,
--                 Retour arrière retire le dernier coin, Entrée enregistre.
--  /eau_ajouter [taille] [hauteur] : carré d'eau autour de soi (version rapide)
--  /eau_liste · /eau_supprimer <n°> · /eau_annuler
-- =========================================================
local K = {
    corner = 38,        -- E
    undo = 177,         -- Retour arrière / Échap
    finish = 191,       -- Entrée
    up = 241, down = 242, -- molette
    up2 = 172, down2 = 173, -- flèches haut / bas
    fast = 21,          -- Maj : réglage rapide
}
local ed = nil   -- éditeur ouvert : { points, z, quads, aim, ground }

-- Touche appuyée, qu'elle soit active ou désactivée par un autre script
-- (le noclip d'admin_menu désactive toutes les touches du jeu à chaque image)
local function pressed(c) return IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c) end
local function held(c) return IsControlPressed(0, c) or IsDisabledControlPressed(0, c) end

RegisterCommand('eau_ajouter', function(_, args)
    local c = GetEntityCoords(PlayerPedId())
    local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    TriggerServerEvent('elyzea_eau:add', tonumber(args[1]), tonumber(args[2]), ok and gz or nil)
end, false)
RegisterCommand('eau_annuler', function() TriggerServerEvent('elyzea_eau:undo') end, false)
RegisterCommand('eau_liste', function() TriggerServerEvent('elyzea_eau:list') end, false)
RegisterCommand('eau_supprimer', function(_, args) TriggerServerEvent('elyzea_eau:remove', tonumber(args[1])) end, false)
RegisterCommand('eau_editeur', function()
    if ed then ed = nil return end
    TriggerServerEvent('elyzea_eau:editor:open')
end, false)

-- ---------------------------------------------------------------- outils
local function aimPoint(planeZ)
    local from = GetFinalRenderedCamCoord()
    local rot = GetFinalRenderedCamRot(2)
    local zr, xr = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(xr))
    local dir = vector3(-math.sin(zr) * n, math.cos(zr) * n, math.sin(xr))
    local to = from + dir * 400.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, PlayerPedId(), 7)
    local _, hit, pos = GetShapeTestResult(ray)
    if hit == 1 then return pos end
    -- Rien touché (vide, trop loin) : point du rayon à la hauteur de l'eau
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

-- Rectangle horizontal visible des deux côtés
local function fillRect(r, z, cr, cg, cb, a)
    DrawPoly(r.minX, r.minY, z, r.maxX, r.minY, z, r.maxX, r.maxY, z, cr, cg, cb, a)
    DrawPoly(r.minX, r.minY, z, r.maxX, r.maxY, z, r.minX, r.maxY, z, cr, cg, cb, a)
    DrawPoly(r.maxX, r.maxY, z, r.maxX, r.minY, z, r.minX, r.minY, z, cr, cg, cb, a)
    DrawPoly(r.minX, r.maxY, z, r.maxX, r.maxY, z, r.minX, r.minY, z, cr, cg, cb, a)
end

local function outline(r, z, cr, cg, cb, a)
    DrawLine(r.minX, r.minY, z, r.maxX, r.minY, z, cr, cg, cb, a)
    DrawLine(r.maxX, r.minY, z, r.maxX, r.maxY, z, cr, cg, cb, a)
    DrawLine(r.maxX, r.maxY, z, r.minX, r.maxY, z, cr, cg, cb, a)
    DrawLine(r.minX, r.maxY, z, r.minX, r.minY, z, cr, cg, cb, a)
end

local function near(r, p, d)
    return p.x > r.minX - d and p.x < r.maxX + d and p.y > r.minY - d and p.y < r.maxY + d
end

-- ---------------------------------------------------------------- éditeur
local function preview()
    if #ed.points < 3 then ed.rects = {} return end
    local pts = {}
    for _, p in ipairs(ed.points) do pts[#pts + 1] = p end
    ed.rects = EauGeo.Subtract(EauGeo.Rasterize(pts), ed.quads)
end

local function editorLoop()
    while ed do
        local e = ed
        local me = GetEntityCoords(PlayerPedId())
        for _, c in ipairs({ 24, 25, 14, 15, 16, 17, 37, 44, 140, 141, 142 }) do DisableControlAction(0, c, true) end

        -- Visée
        local aim = aimPoint(e.z)
        e.aim = aim
        if aim then
            DrawMarker(28, aim.x, aim.y, aim.z, 0, 0, 0, 0, 0, 0, 0.3, 0.3, 0.3, 80, 200, 255, 230, false, false, 2, false, nil, nil, false)
            -- poteau jusqu'à la surface de l'eau
            DrawLine(aim.x, aim.y, aim.z, aim.x, aim.y, e.z, 80, 200, 255, 255)
        end

        -- Hauteur de l'eau
        -- Chat ouvert, menu pause : on ne lit aucune touche
        local typing = IsNuiFocused() or IsPauseMenuActive()
        local step = held(K.fast) and 1.0 or 0.1
        if not typing and (pressed(K.up) or pressed(K.up2)) then e.z = e.z + step end
        if not typing and (pressed(K.down) or pressed(K.down2)) then e.z = e.z - step end

        -- Coins
        if not typing and pressed(K.corner) and not aim then
            PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
        if not typing and pressed(K.corner) and aim then
            e.points[#e.points + 1] = { x = aim.x, y = aim.y, gz = aim.z }
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            preview()
        end
        if not typing and pressed(K.undo) then
            if #e.points > 0 then
                table.remove(e.points)
                preview()
            else
                ed = nil
                TriggerEvent('chat:addMessage', { args = { 'Eau', 'Éditeur d\'eau fermé.' } })
                break
            end
        end
        if not typing and pressed(K.finish) then
            if #e.points < 3 then
                PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            else
                local pts = {}
                for _, p in ipairs(e.points) do pts[#pts + 1] = { x = p.x, y = p.y } end
                TriggerServerEvent('elyzea_eau:editor:save', pts, math.floor(e.z * 100 + 0.5) / 100)
                ed = nil
                break
            end
        end

        -- Eau existante proche (contours bleu clair) : on voit où s'arrête l'eau du jeu
        for _, q in ipairs(e.quads) do
            if near(q, me, 150.0) then outline(q, q.z + 0.05, 120, 220, 255, 150) end
        end

        -- Zone en cours : contour aux coins + aperçu de l'eau à la hauteur choisie
        local pts = e.points
        for i, p in ipairs(pts) do
            local nx = pts[i + 1] or aim or p
            DrawMarker(1, p.x, p.y, math.min(p.gz, e.z) - 0.5, 0, 0, 0, 0, 0, 0, 0.5, 0.5, math.abs(e.z - p.gz) + 1.5, 255, 210, 80, 200, false, false, 2, false, nil, nil, false)
            DrawLine(p.x, p.y, e.z + 0.05, nx.x, nx.y, e.z + 0.05, 255, 210, 80, 255)
        end
        if #pts >= 2 and aim then DrawLine(aim.x, aim.y, e.z + 0.05, pts[1].x, pts[1].y, e.z + 0.05, 255, 210, 80, 120) end
        for _, r in ipairs(e.rects or {}) do
            if near(r, me, 300.0) then fillRect(r, e.z, 40, 140, 230, 110) end
        end

        -- Panneau
        local depth = aim and (e.z - aim.z) or nil
        local b = #pts > 0 and EauGeo.Bounds(pts) or nil
        local y = 0.30
        text(0.015, y, '~b~ÉDITEUR D\'EAU', 0.5) y = y + 0.04
        text(0.015, y, ('Hauteur de l\'eau : ~y~%.2f m'):format(e.z)) y = y + 0.03
        if depth then
            if depth > 0.05 then text(0.015, y, ('Profondeur sous le viseur : ~g~%.2f m'):format(depth))
            else text(0.015, y, ('Sol AU-DESSUS de l\'eau de ~r~%.2f m~s~ : pas d\'eau visible ici'):format(-depth)) end
            y = y + 0.03
        end
        if b and #pts >= 2 then
            text(0.015, y, ('Largeur : %.0f m · Longueur : %.0f m'):format(b.maxX - b.minX, b.maxY - b.minY)) y = y + 0.03
        end
        if #pts >= 3 then
            text(0.015, y, ('Nouvelle eau : %d m² en %d morceau(x)%s'):format(EauGeo.Area(e.rects), #e.rects,
                #e.rects > EauGeo.MAX_RECTS and ' ~r~(trop découpée)' or '')) y = y + 0.03
        end
        y = y + 0.01
        text(0.015, y, ('E : poser un coin (%d posé(s))'):format(#pts), 0.32) y = y + 0.027
        text(0.015, y, 'Molette / flèches : hauteur de l\'eau (Maj = 1 m)', 0.32) y = y + 0.027
        text(0.015, y, 'Retour arrière : ' .. (#pts > 0 and 'retirer le dernier coin' or 'fermer l\'éditeur'), 0.32) y = y + 0.027
        text(0.015, y, 'Entrée : enregistrer la zone' .. (#pts < 3 and ' (3 coins minimum)' or ''), 0.32)
        Wait(0)
    end
end

RegisterNetEvent('elyzea_eau:editor:start', function(quads, z)
    if ed then return end
    ed = { points = {}, z = tonumber(z) or 0.0, quads = quads or {}, rects = {} }
    TriggerEvent('chat:addMessage', { args = { 'Eau', 'Éditeur d\'eau : vise le sol et pose les coins avec E (le noclip marche). Les contours bleu clair montrent l\'eau qui existe déjà.' } })
    CreateThread(function()
        local ok, err = pcall(editorLoop)
        if not ok then print('^1[EAU] erreur de l\'éditeur : ' .. tostring(err) .. '^0') ed = nil end
    end)
end)
