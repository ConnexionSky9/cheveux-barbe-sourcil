-- =========================================================
--  ELYZEA TAGS - CLIENT
--  Affichage : chaque tag proche est une page html/tag.html
--  rendue en texture (DUI) et collée sur le mur (2 triangles).
--  Seuls les Config.Render.maxVisible tags les plus proches
--  ont une texture : les autres ne coûtent rien.
-- =========================================================
local RES = GetCurrentResourceName()
local Tags = {}          -- [id] = { id, text, color, font, size, pos, n, corners }
local Slots = {}         -- textures réutilisables : { dui, txd, tagId, showAt }
local Visible = {}       -- { { tag, slot } } : tags dessinés en ce moment
local busy = false       -- formulaire, placement ou animation en cours
local uid = GetGameTimer()

local function notify(msg, kind) Ely.notify({ description = msg, type = kind or 'inform' }) end
RegisterNetEvent('elyzea_tags:client:notify', notify)

-- ---------------------------------------------------------
--  Géométrie : coins du tag sur le mur
-- ---------------------------------------------------------
local function norm(v) local l = #v return l > 0.0001 and v / l or v end

-- Vecteurs « droite » et « haut » du mur vu de face (n = normale vers l'extérieur)
local function basis(n)
    local r = norm(vector3(-n.y, n.x, 0.0))
    local u = vector3(n.y * r.z - n.z * r.y, n.z * r.x - n.x * r.z, n.x * r.y - n.y * r.x)
    return r, u
end

local function corners(pos, n, size)
    local r, u = basis(n)
    local c = pos + n * 0.015
    local w, h = r * (size / 2), u * (size / 4)   -- texture 2:1
    return { tl = c - w + h, tr = c + w + h, bl = c - w - h, br = c + w - h }
end

local function addTag(t)
    local pos, n = vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0), norm(vector3(t.nx + 0.0, t.ny + 0.0, t.nz + 0.0))
    Tags[t.id] = { id = t.id, text = t.text, color = t.color, font = t.font, size = t.size + 0.0, pos = pos, n = n, corners = corners(pos, n, t.size + 0.0) }
end

-- ---------------------------------------------------------
--  Textures (DUI)
-- ---------------------------------------------------------
local function newSlot(i)
    local dui = CreateDui(('nui://%s/html/tag.html'):format(RES), Config.Render.texture.w, Config.Render.texture.h)
    local txd = ('elytags_%d_%d'):format(uid, i)
    CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd(txd), 'tag', GetDuiHandle(dui))
    return { dui = dui, txd = txd }
end

local function fontFamily(key)
    for _, f in ipairs(Config.Fonts) do if f.key == key then return f.family end end
    return Config.Fonts[1].family
end

-- Affiche un tag dans une texture (attend que la page soit chargée)
local function paint(slot, t)
    slot.tagId, slot.showAt = t.id, nil
    CreateThread(function()
        local limit = GetGameTimer() + 5000
        while not IsDuiAvailable(slot.dui) and GetGameTimer() < limit do Wait(50) end
        if slot.tagId ~= t.id then return end
        SendDuiMessage(slot.dui, json.encode({ text = t.text, color = t.color, font = fontFamily(t.font) }))
        slot.showAt = GetGameTimer() + 250   -- laisse le temps à la page de se redessiner
    end)
end

local function drawQuad(c, txd, r, g, b, a)
    local tl, tr, bl, br = c.tl, c.tr, c.bl, c.br
    -- Deux sens de rotation : visible quel que soit le sens retenu par le jeu
    DrawSpritePoly(tl.x, tl.y, tl.z, bl.x, bl.y, bl.z, br.x, br.y, br.z, r, g, b, a, txd, 'tag', 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    DrawSpritePoly(tl.x, tl.y, tl.z, br.x, br.y, br.z, tr.x, tr.y, tr.z, r, g, b, a, txd, 'tag', 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0)
    DrawSpritePoly(tl.x, tl.y, tl.z, br.x, br.y, br.z, bl.x, bl.y, bl.z, r, g, b, a, txd, 'tag', 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    DrawSpritePoly(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, br.x, br.y, br.z, r, g, b, a, txd, 'tag', 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
end

local function brightness()
    local h = GetClockHours()
    if h >= 21 or h < 6 then return Config.Render.nightDim end
    return 1.0
end

-- Choix des tags affichés (les plus proches), une fois par seconde
CreateThread(function()
    local maxD = Config.Render.distance
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local near = {}
        for _, t in pairs(Tags) do
            local d = #(t.pos - me)
            if d < maxD then near[#near + 1] = { t = t, d = d } end
        end
        table.sort(near, function(a, b) return a.d < b.d end)
        local keep = {}
        for i = 1, math.min(#near, Config.Render.maxVisible) do keep[near[i].t.id] = near[i] end

        -- Textures libérées par les tags trop loin
        local free = {}
        for _, s in ipairs(Slots) do
            if not s.tagId or not keep[s.tagId] or not Tags[s.tagId] then s.tagId, s.showAt = nil, nil free[#free + 1] = s
            else keep[s.tagId].slot = s end
        end
        local vis = {}
        for _, e in pairs(keep) do
            if not e.slot then
                local s = table.remove(free)
                if not s and #Slots < Config.Render.maxVisible then s = newSlot(#Slots + 1) Slots[#Slots + 1] = s end
                if s then paint(s, e.t) e.slot = s end
            end
            if e.slot then vis[#vis + 1] = { tag = e.t, slot = e.slot, d = e.d } end
        end
        Visible = vis
        Wait(1000)
    end
end)

-- Dessin (chaque image)
CreateThread(function()
    local maxD = Config.Render.distance
    while true do
        if #Visible == 0 then
            Wait(500)
        else
            local now, me, k = GetGameTimer(), GetEntityCoords(PlayerPedId()), brightness()
            local c = math.floor(255 * k)
            for _, v in ipairs(Visible) do
                local s = v.slot
                if s.tagId == v.tag.id and s.showAt and now >= s.showAt and Tags[v.tag.id] then
                    local d = #(v.tag.pos - me)
                    local a = d < maxD * 0.75 and 255 or math.floor(255 * math.max(0.0, (maxD - d) / (maxD * 0.25)))
                    if a > 0 then drawQuad(v.tag.corners, s.txd, c, c, c, a) end
                end
            end
            Wait(0)
        end
    end
end)

-- ---------------------------------------------------------
--  Synchronisation
-- ---------------------------------------------------------
RegisterNetEvent('elyzea_tags:client:all', function(list)
    Tags = {}
    for _, t in ipairs(list or {}) do addTag(t) end
end)
RegisterNetEvent('elyzea_tags:client:add', function(t) if type(t) == 'table' then addTag(t) end end)
RegisterNetEvent('elyzea_tags:client:remove', function(ids)
    for _, id in ipairs(ids or {}) do Tags[id] = nil end
    local vis = {}
    for _, v in ipairs(Visible) do if Tags[v.tag.id] then vis[#vis + 1] = v end end
    Visible = vis
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(2000)
    TriggerServerEvent('elyzea_tags:server:hello')
end)
RegisterNetEvent('elyzea:client:playerLoaded', function() TriggerServerEvent('elyzea_tags:server:hello') end)

local Preview
AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for _, s in ipairs(Slots) do if s.dui then DestroyDui(s.dui) end end
    if Preview then DestroyDui(Preview.dui) end
end)

-- ---------------------------------------------------------
--  Visée : point du mur devant la caméra
-- ---------------------------------------------------------
local function camDir()
    local r = GetGameplayCamRot(2)
    local x, z = math.rad(r.x), math.rad(r.z)
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

local function probe(from, to)
    local h = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1, PlayerPedId(), 7)
    local _, hit, at, normal = GetShapeTestResult(h)
    return hit == 1, at, normal
end

local function aimWall()
    local cam = GetGameplayCamCoord()
    local hit, at, n = probe(cam, cam + camDir() * 10.0)
    if not hit then return nil end
    return at, norm(n)
end

-- Le tag tient-il entièrement sur un mur plat ?
local function fits(pos, n, size)
    local c = corners(pos, n, size)
    for _, p in pairs(c) do
        local hit, _, n2 = probe(p + n * 0.25, p - n * 0.25)
        if not hit or #(norm(n2) - n) > 0.25 then return false end
    end
    return true
end

-- ---------------------------------------------------------
--  Peindre : formulaire → placement → animation → serveur
-- ---------------------------------------------------------
local formCb
RegisterNUICallback('submit', function(d, cb)
    local ok, why = Ely.callback.await('elyzea_tags:check', false, d and d.text)
    if not ok then return cb({ ok = false, error = why or 'Texte refusé.' }) end
    cb({ ok = true })
    SetNuiFocus(false, false)
    if formCb then formCb(d) end
end)
RegisterNUICallback('close', function(_, cb)
    cb('ok')
    SetNuiFocus(false, false)
    if formCb then formCb(nil) end
end)

local function askTag(opts)
    local p = promise.new()
    formCb = function(d) formCb = nil p:resolve(d) end
    SendNUIMessage({ action = 'open', data = opts })
    SetNuiFocus(true, true)
    return Citizen.Await(p)
end

local function help(text) Ely.showTextUI(text) end

-- Placement : aperçu sur le mur, molette / flèches pour la taille, E pour peindre
local function place(d)
    Preview = Preview or newSlot(0)
    local slot = Preview
    paint(slot, { id = -1, text = d.text, color = d.color, font = d.font })
    local size = Config.Size.default
    local result
    local ped = PlayerPedId()
    help('[E] Peindre  ·  [Molette] Taille  ·  [Retour] Annuler')
    while true do
        DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 14, true)
        DisableControlAction(0, 15, true) DisableControlAction(0, 16, true) DisableControlAction(0, 17, true)
        DisableControlAction(0, 37, true) DisablePlayerFiring(PlayerId(), true)
        if IsDisabledControlJustPressed(0, 15) or IsControlJustPressed(0, 172) then size = math.min(Config.Size.max, size + Config.Size.step) end
        if IsDisabledControlJustPressed(0, 14) or IsControlJustPressed(0, 173) then size = math.max(Config.Size.min, size - Config.Size.step) end
        if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) or IsEntityDead(ped) then break end

        local at, n = aimWall()
        local ok = false
        if at then
            ok = math.abs(n.z) <= Config.Spray.maxSlope and #(GetEntityCoords(ped) - at) <= Config.Spray.reach and fits(at, n, size)
            if slot.showAt and GetGameTimer() >= slot.showAt then
                drawQuad(corners(at, n, size), slot.txd, 255, ok and 255 or 70, ok and 255 or 70, ok and 190 or 120)
            end
        end
        if IsControlJustPressed(0, 38) then
            if ok then result = { pos = at, n = n, size = size } break end
            notify(at and 'Place le tag à plat sur un mur, plus près de toi.' or 'Vise un mur.', 'error')
        end
        Wait(0)
    end
    Ely.hideTextUI()
    slot.tagId, slot.showAt = nil, nil
    return result
end

local SPRAY_ANIM = { dict = 'switch@franklin@lamar_tagging_wall', clip = 'lamar_tagging_wall_loop_lamar', flag = 1 }
local SPRAY_PROP = { model = 'prop_cs_spray_can', bone = 28422, pos = vec3(0.0, 0.0, 0.07), rot = vec3(0.0, 0.0, 0.0) }

-- Nuage de peinture (effet de la mission de Lamar, sinon fumée colorée)
local FX = { { 'scr_playerlamgraff', 'scr_lamgraff_paint_spray', 1.0 }, { 'scr_recartheft', 'scr_wheel_burnout', 0.4 } }
local function sprayFx(pos, color)
    local fx
    for _, e in ipairs(FX) do
        RequestNamedPtfxAsset(e[1])
        local t = GetGameTimer() + 1500
        while not HasNamedPtfxAssetLoaded(e[1]) and GetGameTimer() < t do Wait(0) end
        if HasNamedPtfxAssetLoaded(e[1]) then
            UseParticleFxAsset(e[1])
            fx = StartParticleFxLoopedAtCoord(e[2], pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, e[3], false, false, false, false)
            if fx and fx ~= 0 then break end
        end
    end
    if not fx or fx == 0 then return nil end
    local r, g, b = tonumber(color:sub(2, 3), 16) / 255, tonumber(color:sub(4, 5), 16) / 255, tonumber(color:sub(6, 7), 16) / 255
    SetParticleFxLoopedColour(fx, r, g, b, false)
    SetParticleFxLoopedAlpha(fx, 0.6)
    return fx
end

RegisterNetEvent('elyzea_tags:client:spray', function(opts)
    if busy then return end
    busy = true
    pcall(function() exports.elyzea_inventory:closeInventory() end)
    Wait(150)
    local d = askTag(opts)
    if d then
        local spot = place(d)
        if spot then
            local ped = PlayerPedId()
            TaskTurnPedToFaceCoord(ped, spot.pos.x, spot.pos.y, spot.pos.z, 800)
            Wait(800)
            local fx = sprayFx(spot.pos + spot.n * 0.3, d.color)
            local done = Ely.progressBar({ duration = Config.Spray.duration, label = 'Tu peins ton tag…', canCancel = true,
                disable = { move = true, car = true, combat = true }, anim = SPRAY_ANIM, prop = SPRAY_PROP })
            if fx then StopParticleFxLooped(fx, false) end
            if done then
                TriggerServerEvent('elyzea_tags:server:place', { text = d.text, color = d.color, font = d.font, size = spot.size,
                    x = spot.pos.x, y = spot.pos.y, z = spot.pos.z, nx = spot.n.x, ny = spot.n.y, nz = spot.n.z })
            end
        end
    end
    busy = false
end)

-- ---------------------------------------------------------
--  Effacer : tag le plus proche, face au joueur
-- ---------------------------------------------------------
local CLEAN_ANIM = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base', flag = 1 }
local CLEAN_PROP = { model = 'prop_sponge_01', bone = 28422, pos = vec3(0.0, 0.0, -0.01), rot = vec3(90.0, 0.0, 0.0) }

local function targetTag()
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, t in pairs(Tags) do
        local d = #(t.pos - me)
        local side = (me.x - t.pos.x) * t.n.x + (me.y - t.pos.y) * t.n.y + (me.z - t.pos.z) * t.n.z
        if d <= Config.Clean.reach + t.size / 2 and side > 0 and (not bestD or d < bestD) then best, bestD = t, d end
    end
    return best
end

RegisterNetEvent('elyzea_tags:client:clean', function()
    if busy then return end
    local t = targetTag()
    if not t then return notify('Aucun tag à effacer devant toi.', 'error') end
    busy = true
    pcall(function() exports.elyzea_inventory:closeInventory() end)
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, t.pos.x, t.pos.y, t.pos.z, 800)
    Wait(800)
    local done = Ely.progressBar({ duration = Config.Clean.duration, label = 'Tu effaces le tag…', canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = CLEAN_ANIM, prop = CLEAN_PROP })
    if done then TriggerServerEvent('elyzea_tags:server:clean', t.id) end
    busy = false
end)
