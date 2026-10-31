-- =========================================================
--  BUILDER STUDIO - MOTEUR DE RENDU EN JEU (client)
--  Utilisé par l'éditeur ET copié dans chaque ressource exportée.
--  - Chargement progressif par distance (file d'attente, N entités / image)
--  - Entités LOCALES (non réseau) : aucune charge sur le serveur / OneSync
--  - Placement exact par SetEntityMatrix (rotation complète + échelle visuelle)
--  - Lumières dynamiques (DrawLightWithRange / DrawSpotLight) près de la caméra
--  - Portes battantes / coulissantes / automatiques, ascenseurs
-- =========================================================
BRuntime = {
    projects = {},        -- [pid] = { data = projet, els = { [eid] = état } }
    dims = {},            -- dimensions mesurées des modèles
    cfg = { Radius = 250.0, UnloadMargin = 40.0, SpawnPerFrame = 12, MaxEntities = 6000, LightDistance = 60.0, MaxLights = 48 },
    texturesPath = 'textures/custom/',
    hooks = {},           -- onSpawn(pid, eid, st), onDespawn(pid, eid)
    entityCount = 0,
    doorOpen = {},        -- [clé] = true
    entityLookup = {},    -- [handle] = { pid, eid, idx }
    matrixOrder = nil,
    paused = false,
}
local R = BRuntime
local queue = {}          -- { pid, eid }
local queued = {}         -- [pid..eid] = true
local lightsNear = {}

-- ---------------------------------------------------------
--  Modèles et dimensions
-- ---------------------------------------------------------
local function hashOf(model) return type(model) == 'number' and model or GetHashKey(model) end

function R.modelExists(model)
    local h = hashOf(model)
    return IsModelInCdimage(h) or IsModelValid(h)
end

function R.measured(model)
    local d = R.dims[model]
    if d then return d end
    return nil
end

-- Mesure (bloquant, à appeler dans un thread)
function R.measure(model, timeout)
    if R.dims[model] then return R.dims[model] end
    local h = hashOf(model)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer()
    while not HasModelLoaded(h) do
        Wait(0)
        if GetGameTimer() - t > (timeout or 4000) then return nil end
    end
    local mn, mx = GetModelDimensions(h)
    SetModelAsNoLongerNeeded(h)
    local d = { min = { x = mn.x, y = mn.y, z = mn.z }, max = { x = mx.x, y = mx.y, z = mx.z } }
    if mx.x - mn.x <= 0 then return nil end
    R.dims[model] = d
    return d
end

-- Mesure tous les modules du kit vanilla (une fois)
function R.measureKit()
    local out = {}
    for _, m in ipairs(BKits.allModels('blocs')) do
        if not R.dims[m] then
            local d = R.measure(m)
            if d then out[m] = d end
        end
    end
    return out
end

local function ctx() return { measured = R.measured } end
R.ctx = ctx

-- ---------------------------------------------------------
--  Calibrage de SetEntityMatrix (ordre des axes) : on ne devine pas,
--  on mesure sur une entité de test au premier chargement.
-- ---------------------------------------------------------
function R.calibrate()
    if R.matrixOrder then return R.matrixOrder end
    local h = GetHashKey('prop_roadcone02a')
    if not IsModelInCdimage(h) then R.matrixOrder = 'xyz' return R.matrixOrder end
    RequestModel(h)
    local t = GetGameTimer()
    while not HasModelLoaded(h) and GetGameTimer() - t < 3000 do Wait(0) end
    local c = GetFinalRenderedCamCoord()
    local obj = CreateObjectNoOffset(h, c.x, c.y, c.z - 50.0, false, false, false)
    SetEntityRotation(obj, 0.0, 0.0, 90.0, 2, true)
    Wait(0)
    local a = GetEntityMatrix(obj)
    -- cap 90 : axe droit (X) = (0, 1, 0) ; axe avant (Y) = (-1, 0, 0)
    if a and a.x < -0.5 then R.matrixOrder = 'yxz' else R.matrixOrder = 'xyz' end
    DeleteObject(obj)
    SetModelAsNoLongerNeeded(h)
    return R.matrixOrder
end

function R.setMatrix(ent, m, pos, scale)
    local sx, sy, sz = 1.0, 1.0, 1.0
    if scale then sx, sy, sz = scale.x or 1.0, scale.y or 1.0, scale.z or 1.0 end
    local X = { m[1][1] * sx, m[2][1] * sx, m[3][1] * sx }
    local Y = { m[1][2] * sy, m[2][2] * sy, m[3][2] * sy }
    local Z = { m[1][3] * sz, m[2][3] * sz, m[3][3] * sz }
    local A, B = X, Y
    if R.matrixOrder == 'yxz' then A, B = Y, X end
    SetEntityMatrix(ent, A[1], A[2], A[3], B[1], B[2], B[3], Z[1], Z[2], Z[3], pos.x, pos.y, pos.z)
end

-- ---------------------------------------------------------
--  Projets
-- ---------------------------------------------------------
function R.setProject(p)
    local old = R.projects[p.id]
    if old then R.unloadProject(p.id) end
    R.projects[p.id] = { data = p, els = {} }
    for k, d in pairs(p.dims or {}) do if not R.dims[k] then R.dims[k] = d end end
    R.applyTextures(p)
end

function R.removeProject(pid)
    R.unloadProject(pid)
    R.projects[pid] = nil
end

function R.unloadProject(pid)
    local pr = R.projects[pid]
    if not pr then return end
    for eid in pairs(pr.els) do R.despawn(pid, eid) end
end

local function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
R.deepEqual = deepEqual

-- Même forme (seuls position / rotation / nom / verrou changent) ?
local SHAPE_IGNORE = { pos = true, rot = true, name = true, locked = true, parent = true, level = true }
local function sameShape(a, b)
    for k, v in pairs(a) do if not SHAPE_IGNORE[k] and not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if not SHAPE_IGNORE[k] and a[k] == nil then return false end end
    return true
end

-- Un élément a changé : déplacement sur place si possible, sinon on le recrée
function R.updateElement(pid, el)
    local pr = R.projects[pid]
    if not pr then return end
    local old = pr.data.elements[el.id]
    pr.data.elements[el.id] = el
    local st = pr.els[el.id]
    if st and st.done and old and sameShape(old, el) then
        R.retransform(pid, el, st)
        return
    end
    R.despawn(pid, el.id)
end

-- Recalcule les matrices et déplace les entités existantes (aucun clignotement)
function R.retransform(pid, el, st, overridePos, overrideRot)
    local tmp = el
    if overridePos or overrideRot then
        tmp = {}
        for k, v in pairs(el) do tmp[k] = v end
        tmp.pos, tmp.rot = overridePos or el.pos, overrideRot or el.rot
    end
    local pieces = BGeo.worldPieces(tmp, ctx())
    if el.doorsOnly then
        local only = {}
        for _, pc in ipairs(pieces) do if pc.kind == 'door' then only[#only + 1] = pc end end
        pieces = only
    end
    if #pieces ~= #st.pieces then return false end
    for i, pc in ipairs(pieces) do
        local ent = st.ents[i]
        pc.doorT = st.pieces[i].doorT
        if ent and DoesEntityExist(ent) then
            if pc.door and (pc.doorT or 0) > 0 then R.applyDoor(ent, pc, pc.doorT) else R.setMatrix(ent, pc.matrix, pc.pos, pc.scale) end
        end
    end
    if not (overridePos or overrideRot) then
        st.pieces = pieces
        st.lights = {}
        for _, pc in ipairs(pieces) do if pc.kind == 'light' then st.lights[#st.lights + 1] = pc end end
    else
        st.preview = pieces
    end
    return true
end

function R.removeElement(pid, eid)
    local pr = R.projects[pid]
    if not pr then return end
    R.despawn(pid, eid)
    pr.data.elements[eid] = nil
end

-- ---------------------------------------------------------
--  Création / suppression des entités d'un élément
-- ---------------------------------------------------------
local function requestModel(h)
    if HasModelLoaded(h) then return true end
    RequestModel(h)
    return false
end

function R.despawn(pid, eid)
    local pr = R.projects[pid]
    if not pr then return end
    local st = pr.els[eid]
    if not st then return end
    for _, ent in ipairs(st.ents or {}) do
        if ent and DoesEntityExist(ent) then
            R.entityLookup[ent] = nil
            SetEntityAsMissionEntity(ent, true, true)
            if IsEntityAVehicle(ent) then DeleteVehicle(ent) else DeleteObject(ent) end
            R.entityCount = R.entityCount - 1
        end
    end
    pr.els[eid] = nil
    queued[pid .. ':' .. eid] = nil
    if R.hooks.onDespawn then R.hooks.onDespawn(pid, eid) end
end

-- Prépare l'état (pièces monde) d'un élément
local function prepare(pid, el)
    local c = ctx()
    local pieces = BGeo.worldPieces(el, c)
    if el.doorsOnly then
        local only = {}
        for _, pc in ipairs(pieces) do if pc.kind == 'door' then only[#only + 1] = pc end end
        pieces = only
    end
    local st = { pieces = pieces, ents = {}, next = 1, lights = {}, doors = {}, warnings = c.warnings, done = false }
    for i, pc in ipairs(pieces) do
        if pc.kind == 'light' then st.lights[#st.lights + 1] = pc end
        if pc.kind == 'door' then st.doors[#st.doors + 1] = { idx = i, key = pid .. ':' .. el.id .. ':' .. i } end
    end
    return st
end

-- Crée au plus « budget » entités pour cet élément ; renvoie le budget restant
local function spawnStep(pid, el, st, budget)
    while st.next <= #st.pieces and budget > 0 do
        local pc = st.pieces[st.next]
        if pc.model and pc.kind ~= 'light' then
            if R.entityCount >= R.cfg.MaxEntities then return 0 end
            local h = hashOf(pc.model)
            if not IsModelInCdimage(h) then
                st.missing = (st.missing or 0) + 1
                st.next = st.next + 1
            elseif not requestModel(h) then
                -- modèle en cours de chargement : on réessaie à l'image suivante (6 s max)
                st.wait = st.wait or GetGameTimer()
                if GetGameTimer() - st.wait < 6000 then return 0 end
                st.wait = nil
                st.missing = (st.missing or 0) + 1
                st.next = st.next + 1
            else
                st.wait = nil
                local ent
                if el.vehicle then
                    ent = CreateVehicle(h, pc.pos.x, pc.pos.y, pc.pos.z, 0.0, false, false)
                    SetVehicleDoorsLocked(ent, 2)
                    SetEntityInvincible(ent, true)
                    SetVehicleEngineOn(ent, false, true, true)
                else
                    ent = CreateObjectNoOffset(h, pc.pos.x, pc.pos.y, pc.pos.z, false, false, false)
                end
                if ent and ent ~= 0 then
                    R.setMatrix(ent, pc.matrix, pc.pos, pc.scale)
                    if not pc.dynamic then FreezeEntityPosition(ent, true) end
                    if pc.tint then SetObjectTextureVariation(ent, pc.tint) end
                    if pc.alpha and pc.alpha < 255 then SetEntityAlpha(ent, pc.alpha, false) end
                    SetEntityLodDist(ent, 500)
                    st.ents[st.next] = ent
                    R.entityLookup[ent] = { pid = pid, eid = el.id, idx = st.next }
                    R.entityCount = R.entityCount + 1
                    if pc.door then
                        local key = pid .. ':' .. el.id .. ':' .. st.next
                        if R.doorOpen[key] then pc.doorT = 1.0 R.applyDoor(ent, pc, 1.0) end
                    end
                end
                SetModelAsNoLongerNeeded(h)
                st.next = st.next + 1
                budget = budget - 1
            end
        else
            st.next = st.next + 1
        end
    end
    if st.next > #st.pieces and not st.done then
        st.done = true
        if R.hooks.onSpawn then R.hooks.onSpawn(pid, el.id, st) end
    end
    return budget
end

function R.queue(pid, eid)
    local k = pid .. ':' .. eid
    if queued[k] then return end
    queued[k] = true
    queue[#queue + 1] = { pid = pid, eid = eid }
end

-- Force le chargement immédiat (éditeur)
function R.load(pid, eid)
    local pr = R.projects[pid]
    if not pr then return end
    local el = pr.data.elements[eid]
    if not el or el.hidden then return end
    if not pr.els[eid] then pr.els[eid] = prepare(pid, el) end
    R.queue(pid, eid)
end

-- ---------------------------------------------------------
--  Portes
-- ---------------------------------------------------------
function R.applyDoor(ent, pc, t)
    local m, pos = pc.matrix, pc.pos
    local d = pc.door
    if d.mode == 'slide' then
        local off = BMath.apply(m, { x = (d.slide or 1.0) * t, y = 0, z = 0 })
        R.setMatrix(ent, m, BMath.add(pos, off))
    else
        local rz = BMath.eulerToMatrix({ x = 0, y = 0, z = 90 * (d.dir or 1) * t })
        local m2 = BMath.mul(m, rz)
        local pv = d.pivot or { x = 0, y = 0, z = 0 }
        local p2 = BMath.add(pos, BMath.sub(BMath.apply(m, pv), BMath.apply(m2, pv)))
        R.setMatrix(ent, m2, p2)
    end
end

-- événements préfixés par le nom de la ressource : une map exportée et le studio ne se mélangent pas
local EV = GetCurrentResourceName()
RegisterNetEvent(EV .. ':door', function(key, open) R.doorOpen[key] = open or nil end)
RegisterNetEvent(EV .. ':doors', function(list) R.doorOpen = list or {} end)

local function helpText(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, false, -1)
end
R.helpText = helpText

-- ---------------------------------------------------------
--  Textures personnalisées (vrai remplacement du moteur)
-- ---------------------------------------------------------
local runtimeTxd = {}
function R.applyTextures(p)
    for _, t in ipairs(p.textures or {}) do
        local dict = 'bstx_' .. t.file:gsub('%.png$', '')
        if not runtimeTxd[dict] then
            local txd = CreateRuntimeTxd(dict)
            CreateRuntimeTextureFromImage(txd, 'img', R.texturesPath .. t.file)
            runtimeTxd[dict] = true
        end
        AddReplaceTexture(t.txd, t.txn, dict, 'img')
    end
end

-- ---------------------------------------------------------
--  Boucles
-- ---------------------------------------------------------
local function refPoint()
    local c = GetFinalRenderedCamCoord()
    return { x = c.x, y = c.y, z = c.z }
end

-- Décide quoi charger / décharger (2 fois par seconde)
CreateThread(function()
    while true do
        Wait(500)
        if not R.paused then
            local ref = refPoint()
            local r = R.cfg.Radius
            for pid, pr in pairs(R.projects) do
                for eid, el in pairs(pr.data.elements) do
                    if el.type ~= 'group' and not el.hidden then
                        local d = BMath.dist(ref, el.pos or ref) - BGeo.radius(el)
                        local st = pr.els[eid]
                        if d < r then
                            if not st then R.load(pid, eid) end
                        elseif st and d > r + R.cfg.UnloadMargin then
                            R.despawn(pid, eid)
                        end
                    elseif pr.els[eid] then
                        R.despawn(pid, eid)
                    end
                end
            end
        end
    end
end)

-- Création progressive (chaque image)
CreateThread(function()
    while true do
        if #queue == 0 then
            Wait(100)
        else
            local budget = R.cfg.SpawnPerFrame
            while budget > 0 and #queue > 0 do
                local q = queue[1]
                local pr = R.projects[q.pid]
                local el = pr and pr.data.elements[q.eid]
                local st = pr and pr.els[q.eid]
                if not el or not st then
                    table.remove(queue, 1)
                    queued[q.pid .. ':' .. q.eid] = nil
                else
                    local before = budget
                    budget = spawnStep(q.pid, el, st, budget)
                    if st.next > #st.pieces then
                        table.remove(queue, 1)
                        queued[q.pid .. ':' .. q.eid] = nil
                    elseif budget == before or budget == 0 then
                        break      -- modèle en chargement : on laisse respirer
                    end
                end
            end
            Wait(0)
        end
    end
end)

-- Lumières proches (tri 2 fois par seconde)
CreateThread(function()
    while true do
        Wait(500)
        local ref = refPoint()
        local list = {}
        local maxD = R.cfg.LightDistance
        for _, pr in pairs(R.projects) do
            for eid, st in pairs(pr.els) do
                local el = pr.data.elements[eid]
                for _, l in ipairs(st.lights or {}) do
                    local d = BMath.dist(ref, l.pos)
                    if d < maxD then list[#list + 1] = { d = d, l = l } end
                end
            end
        end
        table.sort(list, function(a, b) return a.d < b.d end)
        local out = {}
        for i = 1, math.min(#list, R.cfg.MaxLights) do out[i] = list[i].l end
        lightsNear = out
    end
end)

-- Dessin des lumières, portes et ascenseurs (chaque image)
CreateThread(function()
    while true do
        local sleep = 250
        if #lightsNear > 0 then
            sleep = 0
            for _, pc in ipairs(lightsNear) do
                local l = pc.light
                local c = l.color
                if l.kind == 'spot' then
                    local dir = BMath.apply(pc.matrix, { x = 0, y = 0, z = -1 })
                    if l.shadow then
                        DrawSpotLightWithShadow(pc.pos.x, pc.pos.y, pc.pos.z, dir.x, dir.y, dir.z, c.r, c.g, c.b, l.range, l.intensity, 0.0, 35.0, 1.0, 0)
                    else
                        DrawSpotLight(pc.pos.x, pc.pos.y, pc.pos.z, dir.x, dir.y, dir.z, c.r, c.g, c.b, l.range, l.intensity, 0.0, 35.0, 1.0)
                    end
                elseif l.shadow then
                    DrawLightWithRangeAndShadow(pc.pos.x, pc.pos.y, pc.pos.z, c.r, c.g, c.b, l.range, l.intensity, 1.0)
                else
                    DrawLightWithRange(pc.pos.x, pc.pos.y, pc.pos.z, c.r, c.g, c.b, l.range, l.intensity)
                end
            end
        end

        -- Portes et ascenseurs autour du joueur
        local ped = PlayerPedId()
        local pp = GetEntityCoords(ped)
        local me = { x = pp.x, y = pp.y, z = pp.z }
        local promptDone = false
        for pid, pr in pairs(R.projects) do
            for eid, st in pairs(pr.els) do
                local el = pr.data.elements[eid]
                for _, dr in ipairs(st.doors or {}) do
                    local pc = st.pieces[dr.idx]
                    local ent = st.ents[dr.idx]
                    if pc and ent and DoesEntityExist(ent) then
                        local d = BMath.dist(me, pc.pos)
                        if d < 25.0 then
                            sleep = 0
                            local want = R.doorOpen[dr.key] == true
                            if pc.door.auto then
                                want = false
                                for _, pl in ipairs(GetActivePlayers()) do
                                    local q = GetEntityCoords(GetPlayerPed(pl))
                                    if #(q - vector3(pc.pos.x, pc.pos.y, pc.pos.z)) < 3.0 then want = true break end
                                end
                            elseif d < 2.0 and not promptDone and not R.paused then
                                promptDone = true
                                helpText(want and '~INPUT_CONTEXT~ Fermer la porte' or '~INPUT_CONTEXT~ Ouvrir la porte')
                                if IsControlJustPressed(0, 38) then TriggerServerEvent(EV .. ':door', dr.key, not want) end
                            end
                            local tgt = want and 1.0 or 0.0
                            local t = pc.doorT or 0.0
                            if math.abs(t - tgt) > 0.001 then
                                t = t + (tgt > t and 1 or -1) * 0.04
                                if t < 0 then t = 0 elseif t > 1 then t = 1 end
                                pc.doorT = t
                                R.applyDoor(ent, pc, t)
                            end
                        end
                    end
                end
                if el and el.type == 'elevator' and not promptDone and not R.paused then
                    local p = el.params or {}
                    local m = BMath.eulerToMatrix(el.rot or { x = 0, y = 0, z = 0 })
                    local center = { x = (p.width or 2) / 2, y = (p.depth or 2) / 2 }
                    local levels = BGeo.elevatorLevels(p)
                    for li, z in ipairs(levels) do
                        local wp = BMath.add(el.pos, BMath.apply(m, { x = center.x, y = center.y, z = z }))
                        local dx, dy = me.x - wp.x, me.y - wp.y
                        if dx * dx + dy * dy < 1.6 and math.abs(me.z - 1.0 - wp.z) < 1.6 then
                            sleep = 0
                            promptDone = true
                            helpText(('Ascenseur : niveau %d / %d~n~~INPUT_CONTEXT~ Monter   ~INPUT_DETONATE~ Descendre'):format(li, #levels))
                            local target
                            if IsControlJustPressed(0, 38) and li < #levels then target = levels[li + 1] end
                            if IsControlJustPressed(0, 47) and li > 1 then target = levels[li - 1] end
                            if target then
                                local tp = BMath.add(el.pos, BMath.apply(m, { x = center.x, y = center.y, z = target }))
                                DoScreenFadeOut(250)
                                Wait(300)
                                SetEntityCoords(ped, tp.x, tp.y, tp.z + 0.1, false, false, false, false)
                                Wait(200)
                                DoScreenFadeIn(250)
                            end
                            break
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Échelle visuelle : le moteur peut la réinitialiser, on la réapplique
CreateThread(function()
    while true do
        Wait(1000)
        for _, pr in pairs(R.projects) do
            for _, st in pairs(pr.els) do
                for i, pc in ipairs(st.pieces or {}) do
                    if pc.scale and (pc.scale.x ~= 1 or pc.scale.y ~= 1 or pc.scale.z ~= 1) and st.ents[i] and DoesEntityExist(st.ents[i]) and not pc.door then
                        R.setMatrix(st.ents[i], pc.matrix, pc.pos, pc.scale)
                    end
                end
            end
        end
    end
end)

-- Nettoyage à l'arrêt de la ressource
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for pid in pairs(R.projects) do R.unloadProject(pid) end
end)

return BRuntime
