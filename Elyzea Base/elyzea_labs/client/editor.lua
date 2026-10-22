-- =====================================================================
--  ELYZEA LABS · client : cercle bleu → gestion des équipements et éditeur de placement
--  Placement LIBRE : on se déplace normalement dans le laboratoire ; le fantôme de l'équipement suit
--  l'endroit regardé (centre de l'écran) et se pose sur le sol ou sur la surface visée.
--    Molette ou Q / E = tourner · flèches = ajuster finement · Pg.Préc / Pg.Suiv = hauteur
--    G = remettre les ajustements à zéro · clic gauche ou Entrée = poser · clic droit ou Retour = annuler
--  Le fantôme est vert si l'emplacement est valide, rouge sinon ; le serveur revérifie tout.
-- =====================================================================
local C = LabC
local E = nil   -- { mode = 'buy' | 'place' | 'move', type, id, obj, pos, rot, hidden }

function C.Editing() return E ~= nil end

function C.OpenEditorMenu()
    if not C.inside then return end
    local r = C.Pub('editorData', { lab = C.inside.id })
    if r.error then return C.Notify(r.error, 'error') end
    C.Open('editor', r)
end

local function stop(reopen)
    if not E then return end
    if DoesEntityExist(E.obj) then SetEntityDrawOutline(E.obj, false) DeleteEntity(E.obj) end
    if E.hidden and DoesEntityExist(E.hidden) then SetEntityVisible(E.hidden, true, false) end
    E = nil
    if reopen then C.OpenEditorMenu() end
end
function C.EditorCancel() stop(false) end

local function start(mode, typ, id)
    local model = C.EquipModel(typ)
    local h = model and C.LoadModel(model)
    if not h then return C.Notify('Modèle de cet équipement introuvable dans le jeu.', 'error') end
    local ped = PlayerPedId()
    local p = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.8, -0.95)
    local rot = vector3(0.0, 0.0, GetEntityHeading(ped))
    local hidden
    if id then
        for _, s in ipairs(C.Shown()) do
            if s.id == id and DoesEntityExist(s.ent) then
                p, rot, hidden = GetEntityCoords(s.ent), GetEntityRotation(s.ent, 2), s.ent
                SetEntityVisible(s.ent, false, false)
            end
        end
    end
    local obj = CreateObjectNoOffset(h, p.x, p.y, p.z, false, false, false)
    SetEntityAlpha(obj, 170, false)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(h)
    local mn = GetModelDimensions(h)
    -- le joueur reste libre de ses mouvements (placement en marchant)
    E = { mode = mode, type = typ, id = id, obj = obj, pos = p, rot = rot, hidden = hidden, bottom = mn.z, off = vector3(0.0, 0.0, 0.0), lift = 0.0 }
end

RegisterNUICallback('editorAction', function(body, cb)
    cb({})
    if not C.inside then return end
    local act, id, typ = tostring(body.action or ''), tonumber(body.id), tostring(body.type or '')
    if act == 'buy' then
        C.Close() start('buy', typ, nil)
    elseif act == 'place' or act == 'move' then
        local t
        for _, o in ipairs(body.owned or {}) do if tonumber(o.id) == id then t = o.type end end
        t = t or typ
        C.Close() start(act, t, id)
    elseif act == 'store' or act == 'sell' then
        C.Show(C.Pub(act == 'store' and 'equipStore' or 'equipSell', { lab = C.inside.id, id = id }))
        local r = C.Pub('editorData', { lab = C.inside.id })
        if not r.error then C.Update('editor', r) end
    end
end)

-- Vérification locale (même règles que le serveur) pour colorer le fantôme
local function localCheck(p)
    local it = C.inside.interior
    local b = it.bounds
    if #(vector2(p.x, p.y) - vector2(b.x, b.y)) > b.r or p.z < b.minZ or p.z > b.maxZ then return 'hors du laboratoire' end
    for _, k in ipairs({ 'spawn', 'manage', 'stash' }) do
        if it[k] and #(p - C.Vec(it[k])) < Config.KeepClear then return 'passage à garder libre' end
    end
    for _, s in ipairs(C.Shown()) do
        if s.id ~= E.id and #(p - vector3(s.x, s.y, s.z)) < Config.MinSpacing then return 'trop près d\'un autre équipement' end
    end
    return nil
end

-- Point visé au centre de l'écran (sol, table, autre surface), à 6 m au plus du joueur
local function aimPoint()
    local cam, rot = GetGameplayCamCoord(), GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
    local to = cam + dir * 12.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, pos = GetShapeTestResult(ray)
    local me = GetEntityCoords(PlayerPedId())
    if hit == 1 or hit == true then
        local d = #(vector2(pos.x, pos.y) - vector2(me.x, me.y))
        if d <= 6.0 then return pos end
        local k = 6.0 / d
        return vector3(me.x + (pos.x - me.x) * k, me.y + (pos.y - me.y) * k, pos.z)
    end
    -- rien de touché (on regarde en l'air) : devant le joueur, au niveau de ses pieds
    local f = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 2.0, -0.98)
    return f
end

CreateThread(function()
    while true do
        if not E then Wait(300) else
            if not C.inside then stop(false) else
                local fast = IsControlPressed(0, 21) and 3.0 or 1.0
                local step, rstep = 0.01 * fast, 2.0 * fast
                -- on garde la marche et la caméra ; on bloque tir, visée, arme, couverture, menus
                for _, k in ipairs({ 24, 25, 37, 44, 38, 47, 140, 141, 142, 257, 263, 14, 15, 16, 17, 99, 100, 115, 116, 172, 173, 174, 175, 10, 11, 191, 194, 177, 199, 200 }) do DisableControlAction(0, k, true) end
                local camH = math.rad(GetGameplayCamRot(2).z)
                local fwd, right = vector3(-math.sin(camH), math.cos(camH), 0.0), vector3(math.cos(camH), math.sin(camH), 0.0)
                if IsDisabledControlPressed(0, 172) then E.off = E.off + fwd * step end
                if IsDisabledControlPressed(0, 173) then E.off = E.off - fwd * step end
                if IsDisabledControlPressed(0, 175) then E.off = E.off + right * step end
                if IsDisabledControlPressed(0, 174) then E.off = E.off - right * step end
                if #(E.off) > 1.0 then E.off = E.off / #(E.off) end
                if IsDisabledControlPressed(0, 10) then E.lift = math.min(1.5, E.lift + step) end
                if IsDisabledControlPressed(0, 11) then E.lift = math.max(-0.5, E.lift - step) end
                local wheel = (IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16)) and -1 or ((IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17)) and 1 or 0)
                if wheel ~= 0 then E.rot = vector3(E.rot.x, E.rot.y, (E.rot.z + wheel * 15.0) % 360) end
                if IsDisabledControlPressed(0, 44) then E.rot = vector3(E.rot.x, E.rot.y, (E.rot.z + rstep) % 360) end
                if IsDisabledControlPressed(0, 38) then E.rot = vector3(E.rot.x, E.rot.y, (E.rot.z - rstep) % 360) end
                if IsDisabledControlJustPressed(0, 47) then E.off, E.lift = vector3(0.0, 0.0, 0.0), 0.0 end
                -- position : point visé + ajustements ; le bas du modèle touche la surface (jamais enfoncé ni flottant)
                local a = aimPoint()
                E.pos = vector3(a.x + E.off.x, a.y + E.off.y, a.z - E.bottom + E.lift)
                SetEntityCoordsNoOffset(E.obj, E.pos.x, E.pos.y, E.pos.z, false, false, false)
                SetEntityRotation(E.obj, E.rot.x, E.rot.y, E.rot.z, 2, true)
                local bad = localCheck(E.pos)
                local col = bad and { 239, 68, 68 } or { 34, 197, 94 }
                -- contour du fantôme (objet : contour natif, sans risque) + repère au sol
                SetEntityDrawOutlineColor(col[1], col[2], col[3], 255)
                SetEntityDrawOutline(E.obj, true)
                DrawMarker(25, E.pos.x, E.pos.y, E.pos.z + E.bottom - E.lift + 0.02, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 1.0, col[1], col[2], col[3], 110, false, false, 2, false, nil, nil, false)
                C.Help((bad and ('~r~Interdit : %s~s~\n'):format(bad) or '') ..
                    'Déplace-toi et vise l\'endroit · ~INPUT_WEAPON_WHEEL_NEXT~ / ~INPUT_COVER~ ~INPUT_PICKUP~ tourner · ~INPUT_CELLPHONE_UP~~INPUT_CELLPHONE_DOWN~~INPUT_CELLPHONE_LEFT~~INPUT_CELLPHONE_RIGHT~ ajuster · ~INPUT_SCRIPTED_FLY_ZUP~~INPUT_SCRIPTED_FLY_ZDOWN~ hauteur\n~INPUT_DETONATE~ remettre à zéro · ~INPUT_ATTACK~ / ~INPUT_FRONTEND_RDOWN~ poser · ~INPUT_AIM~ / ~INPUT_FRONTEND_RRIGHT~ annuler')
                if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 24) then
                    if bad then C.Notify('Emplacement interdit : ' .. bad, 'error') else
                        local d = { lab = C.inside.id, type = E.type, id = E.mode ~= 'buy' and E.id or nil,
                            x = E.pos.x, y = E.pos.y, z = E.pos.z, rx = E.rot.x, ry = E.rot.y, rz = E.rot.z }
                        local r = C.Show(C.Pub('equipPlace', d))
                        if r.ok then stop(true) end
                    end
                elseif IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 25) then
                    stop(true)
                end
                Wait(0)
            end
        end
    end
end)

-- Depuis la tablette : poser un équipement de la réserve, ou acheter et poser
function C.StartPlacement(mode, typ, id) if C.inside then start(mode, typ, id) end end
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and E then stop(false) end end)
