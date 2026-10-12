-- =====================================================================
--  ELYZEA DYNASTY 8 - client : zone de gestion (cercle bleu) et éditeur de décoration
--  Éditeur : l'objet apparaît devant soi ;
--    flèches = déplacer (selon la caméra) · Pg.Préc / Pg.Suiv = hauteur · Q / E = tourner
--    Maj = plus vite · G = poser au sol · Entrée = valider · Retour arrière = annuler
--  La position est revérifiée par le serveur (modèle autorisé, limite, distance).
-- =====================================================================
local C = D8C
local manage = nil

-- ---------------------------------------------------------------------
-- Zone de gestion (NUI)
-- ---------------------------------------------------------------------
local function CloseManage()
    if not manage then return end
    manage = nil
    C.Focus('manage', false)
    SendNUIMessage({ action = 'manage', show = false })
end
C.ui.manage = { close = CloseManage }

function C.OpenManage(pid)
    local r = C.Pub('manage', { pid = pid })
    if r.error then return C.Notify(r.error, 'error') end
    manage = { pid = pid }
    C.Focus('manage', true)
    SendNUIMessage({ action = 'manage', show = true, data = r })
end
RegisterNUICallback('manageRefresh', function(_, cb)
    if not manage then return cb({ error = 'Fermé.' }) end
    cb(C.Pub('manage', { pid = manage.pid }))
end)

-- ---------------------------------------------------------------------
-- Éditeur de décoration
-- ---------------------------------------------------------------------
local E = nil   -- { pid, model, id (déplacement), obj, pos, rot }
function C.DecoEditing() return E ~= nil end

local function Stop(restoreManage)
    if not E then return end
    if DoesEntityExist(E.obj) then DeleteEntity(E.obj) end
    if E.hidden and DoesEntityExist(E.hidden) then SetEntityVisible(E.hidden, true, false) end
    FreezeEntityPosition(PlayerPedId(), false)
    local pid = E.pid
    E = nil
    if restoreManage then C.OpenManage(pid) end
end
function C.DecoCancel() Stop(false) end

local function Start(pid, model, id)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return C.Notify('Modèle introuvable sur le serveur.', 'error') end
    RequestModel(hash)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(hash) then return C.Notify('Modèle introuvable.', 'error') end
    local ped = PlayerPedId()
    local p = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.6, -0.9)
    local rot = vector3(0.0, 0.0, GetEntityHeading(ped))
    local hidden
    -- Déplacement d'un objet déjà posé : on part de sa position et on cache l'original
    if id then
        for _, o in ipairs(C.DecoShown and C.DecoShown() or {}) do
            if o.id == id and DoesEntityExist(o.ent) then
                p, rot, hidden = GetEntityCoords(o.ent), GetEntityRotation(o.ent, 2), o.ent
                SetEntityVisible(o.ent, false, false)
            end
        end
    end
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    SetEntityAlpha(obj, 200, false)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    FreezeEntityPosition(ped, true)
    E = { pid = pid, model = model, id = id, obj = obj, pos = p, rot = rot, hidden = hidden }
end

RegisterNUICallback('decoStart', function(body, cb)
    cb({})
    if not manage then return end
    local pid = manage.pid
    CloseManage()
    Start(pid, tostring(body.model or ''), tonumber(body.id))
end)

CreateThread(function()
    while true do
        if not E then Wait(300) else
            local fast = IsControlPressed(0, 21) and 3.0 or 1.0
            local step, rstep = 0.02 * fast, 1.5 * fast
            local camRot = GetGameplayCamRot(2)
            local h = math.rad(camRot.z)
            local fwd, right = vector3(-math.sin(h), math.cos(h), 0.0), vector3(math.cos(h), math.sin(h), 0.0)
            for _, k in ipairs({ 172, 173, 174, 175, 10, 11, 44, 38, 47, 191, 194, 177, 21 }) do DisableControlAction(0, k, true) end
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
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
            if IsDisabledControlJustPressed(0, 47) then
                PlaceObjectOnGroundProperly(E.obj)
                E.pos = GetEntityCoords(E.obj)
            end
            C.Help('~INPUT_CELLPHONE_UP~~INPUT_CELLPHONE_DOWN~~INPUT_CELLPHONE_LEFT~~INPUT_CELLPHONE_RIGHT~ déplacer · ~INPUT_SCRIPTED_FLY_ZUP~~INPUT_SCRIPTED_FLY_ZDOWN~ hauteur\n~INPUT_COVER~ ~INPUT_PICKUP~ tourner · ~INPUT_DETONATE~ au sol · ~INPUT_FRONTEND_RDOWN~ valider · ~INPUT_FRONTEND_RRIGHT~ annuler')
            if IsDisabledControlJustPressed(0, 191) then
                local d = { pid = E.pid, model = E.model, id = E.id, x = E.pos.x, y = E.pos.y, z = E.pos.z, rx = E.rot.x, ry = E.rot.y, rz = E.rot.z }
                local r = C.Pub(E.id and 'decoMove' or 'decoPlace', d)
                C.Show(r)
                if r.ok then Stop(true) end
            elseif IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 177) then
                Stop(true)
            end
            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and E then Stop(false) end end)
