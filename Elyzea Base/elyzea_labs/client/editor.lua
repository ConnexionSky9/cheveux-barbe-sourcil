-- =====================================================================
--  ELYZEA LABS · client : cercle bleu → gestion des équipements et éditeur de placement
--  Même principe que la décoration de Dynasty 8 (cercle bleu) :
--    flèches = déplacer (selon la caméra) · Pg.Préc / Pg.Suiv = hauteur · Q / E = tourner
--    Maj = plus vite · G = poser au sol · Entrée = valider · Retour arrière = annuler
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
    if DoesEntityExist(E.obj) then DeleteEntity(E.obj) end
    if E.hidden and DoesEntityExist(E.hidden) then SetEntityVisible(E.hidden, true, false) end
    FreezeEntityPosition(PlayerPedId(), false)
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
    SetEntityAlpha(obj, 190, false)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(h)
    FreezeEntityPosition(ped, true)
    E = { mode = mode, type = typ, id = id, obj = obj, pos = p, rot = rot, hidden = hidden }
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

CreateThread(function()
    while true do
        if not E then Wait(300) else
            if not C.inside then stop(false) else
                local fast = IsControlPressed(0, 21) and 3.0 or 1.0
                local step, rstep = 0.02 * fast, 1.5 * fast
                local camRot = GetGameplayCamRot(2)
                local h = math.rad(camRot.z)
                local fwd, right = vector3(-math.sin(h), math.cos(h), 0.0), vector3(math.cos(h), math.sin(h), 0.0)
                for _, k in ipairs({ 172, 173, 174, 175, 10, 11, 44, 38, 47, 191, 194, 177, 21, 24, 25, 166, 167 }) do DisableControlAction(0, k, true) end
                if IsDisabledControlPressed(0, 172) then E.pos = E.pos + fwd * step end
                if IsDisabledControlPressed(0, 173) then E.pos = E.pos - fwd * step end
                if IsDisabledControlPressed(0, 175) then E.pos = E.pos + right * step end
                if IsDisabledControlPressed(0, 174) then E.pos = E.pos - right * step end
                if IsDisabledControlPressed(0, 10) then E.pos = E.pos + vector3(0, 0, step) end
                if IsDisabledControlPressed(0, 11) then E.pos = E.pos - vector3(0, 0, step) end
                if IsDisabledControlPressed(0, 44) then E.rot = vector3(E.rot.x, E.rot.y, (E.rot.z + rstep) % 360) end
                if IsDisabledControlPressed(0, 38) then E.rot = vector3(E.rot.x, E.rot.y, (E.rot.z - rstep) % 360) end
                SetEntityCoordsNoOffset(E.obj, E.pos.x, E.pos.y, E.pos.z, false, false, false)
                SetEntityRotation(E.obj, E.rot.x, E.rot.y, E.rot.z, 2, true)
                if IsDisabledControlJustPressed(0, 47) then PlaceObjectOnGroundProperly(E.obj) E.pos = GetEntityCoords(E.obj) end
                local bad = localCheck(E.pos)
                local col = bad and { 239, 68, 68 } or { 34, 197, 94 }
                DrawMarker(25, E.pos.x, E.pos.y, E.pos.z + 0.02, 0, 0, 0, 0, 0, 0, 1.4, 1.4, 1.0, col[1], col[2], col[3], 140, false, false, 2, false, nil, nil, false)
                C.Help((bad and ('~r~Interdit : %s~s~\n'):format(bad) or '') ..
                    '~INPUT_CELLPHONE_UP~~INPUT_CELLPHONE_DOWN~~INPUT_CELLPHONE_LEFT~~INPUT_CELLPHONE_RIGHT~ déplacer · ~INPUT_SCRIPTED_FLY_ZUP~~INPUT_SCRIPTED_FLY_ZDOWN~ hauteur\n~INPUT_COVER~ ~INPUT_PICKUP~ tourner · ~INPUT_DETONATE~ au sol · ~INPUT_FRONTEND_RDOWN~ valider · ~INPUT_FRONTEND_RRIGHT~ annuler')
                if IsDisabledControlJustPressed(0, 191) then
                    if bad then C.Notify('Emplacement interdit : ' .. bad, 'error') else
                        local d = { lab = C.inside.id, type = E.type, id = E.mode ~= 'buy' and E.id or nil,
                            x = E.pos.x, y = E.pos.y, z = E.pos.z, rx = E.rot.x, ry = E.rot.y, rz = E.rot.z }
                        local r = C.Show(C.Pub('equipPlace', d))
                        if r.ok then stop(true) end
                    end
                elseif IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 177) then
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
