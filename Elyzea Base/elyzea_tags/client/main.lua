-- =========================================================
--  ELYZEA TAGS - CLIENT
--  Affichage : chaque tag proche est une page html/tag.html
--  rendue en texture (DUI) et collée sur le mur (2 triangles).
--  Seuls les Config.Render.maxVisible tags les plus proches
--  ont une texture : les autres ne coûtent rien.
-- =========================================================
local RES = GetCurrentResourceName()
local Tags = {}          -- [id] = { id, text, color, font, size, rot, pos, n, corners }
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

-- rot : rotation du tag sur le mur (degrés, sens inverse des aiguilles d'une montre)
local function corners(pos, n, size, rot)
    local r, u = basis(n)
    if rot and rot ~= 0.0 then
        local a = math.rad(rot)
        local ca, sa = math.cos(a), math.sin(a)
        r, u = r * ca + u * sa, u * ca - r * sa
    end
    local c = pos + n * 0.015   -- 1,5 cm devant le mur : ni enterré, ni flottant
    local w, h = r * (size / 2), u * (size / 4)   -- texture 2:1
    return { tl = c - w + h, tr = c + w + h, bl = c - w - h, br = c + w - h }
end

local function addTag(t)
    local pos, n = vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0), norm(vector3(t.nx + 0.0, t.ny + 0.0, t.nz + 0.0))
    local rot = (tonumber(t.rot) or 0) + 0.0
    Tags[t.id] = { id = t.id, text = t.text, color = t.color, font = t.font, size = t.size + 0.0, rot = rot, pos = pos, n = n,
        corners = corners(pos, n, t.size + 0.0, rot) }
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
--  Visée : surface devant la caméra (ou devant le joueur)
-- ---------------------------------------------------------
local function camDir()
    local r = GetGameplayCamRot(2)
    local x, z = math.rad(r.x), math.rad(r.z)
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

-- Rayon : décor de la map (1) + objets (16). Le résultat « touché » vaut true ou 1 selon la version du jeu.
local MAT_BLOCK = {}
for _, h in ipairs(Config.Spray.forbiddenMaterials or {}) do MAT_BLOCK[h] = true end

local function probe(from, to)
    local h = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, at, normal, material, ent = GetShapeTestResultIncludingMaterial(h)
    return hit == true or hit == 1, at, normal, material, ent
end

-- Surface utilisable ? renvoie nil ou la raison du refus
local function surfaceProblem(n, material, ent)
    if math.abs(n.z) > Config.Spray.maxSlope then return 'Ce n\'est pas un mur (sol, plafond ou pente trop forte).' end
    if MAT_BLOCK[material] then return 'Impossible de peindre sur cette matière.' end
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        if IsEntityAPed(ent) or IsEntityAVehicle(ent) then return 'Impossible de peindre là-dessus.' end
        -- Objet : seulement le décor de la map (non réseau) ; pas un objet posé par un joueur ou un script, qui peut disparaître
        if NetworkGetEntityIsNetworked(ent) then
            return 'Cet objet peut bouger : peins sur un mur.'
        end
    end
    return nil
end

-- Point visé : rayon de la caméra ; s'il ne trouve rien à portée, rayon droit devant le joueur
local function aimWall()
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    local cam = GetGameplayCamCoord()
    local hit, at, n, mat, ent = probe(cam, cam + camDir() * 12.0)
    if not hit or #(at - me) > Config.Spray.reach then
        local from = me + vector3(0.0, 0.0, 0.5)
        local h2, at2, n2, mat2, ent2 = probe(from, from + GetEntityForwardVector(ped) * Config.Spray.reach)
        if h2 then hit, at, n, mat, ent = h2, at2, n2, mat2, ent2 end
    end
    if not hit then return nil end
    return at, norm(n), mat, ent
end

-- Le tag tient-il sur le mur ? Centre + au moins 3 coins sur la même surface (tolère briques, joints, petites bosses)
local function fits(pos, n, size, rot)
    local c = corners(pos, n, size, rot)
    local function on(p)
        local hit, at, n2 = probe(p + n * 0.3, p - n * 0.3)
        if not hit then return false end
        local depth = (at.x - pos.x) * n.x + (at.y - pos.y) * n.y + (at.z - pos.z) * n.z
        local dot = n.x * n2.x + n.y * n2.y + n.z * n2.z
        return math.abs(depth) <= Config.Spray.flatness and dot >= 0.8
    end
    if not on(pos) then return false end
    local ok = 0
    for _, p in pairs(c) do if on(p) then ok = ok + 1 end end
    return ok >= 3
end

-- Zones interdites (Config.ForbiddenZones), vérifiées aussi par le serveur
local function forbiddenAt(p)
    for _, z in ipairs(Config.ForbiddenZones or {}) do
        if #(vector3(z.x, z.y, z.z) - p) <= z.radius then return z.name end
    end
    return nil
end

-- Contour du tag (toujours visible, même avant le chargement de la texture)
local function drawFrame(c, r, g, b)
    DrawLine(c.tl.x, c.tl.y, c.tl.z, c.tr.x, c.tr.y, c.tr.z, r, g, b, 255)
    DrawLine(c.tr.x, c.tr.y, c.tr.z, c.br.x, c.br.y, c.br.z, r, g, b, 255)
    DrawLine(c.br.x, c.br.y, c.br.z, c.bl.x, c.bl.y, c.bl.z, r, g, b, 255)
    DrawLine(c.bl.x, c.bl.y, c.bl.z, c.tl.x, c.tl.y, c.tl.z, r, g, b, 255)
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

local HELP = '[E] Peindre · [Molette / ↑ ↓] Taille · [← →] Rotation · [Retour] Annuler'
local shownHelp
local function help(text)
    if text == shownHelp then return end
    shownHelp = text
    Ely.showTextUI(text)
end

-- Placement : aperçu aligné sur le mur ; blanc = possible, rouge = impossible (raison affichée)
local function place(d)
    Preview = Preview or newSlot(0)
    local slot = Preview
    paint(slot, { id = -1, text = d.text, color = d.color, font = d.font })
    local size, rot = Config.Size.default, 0.0
    local result
    local ped = PlayerPedId()
    local nextCheck, ok, why, at, n = 0, false, nil, nil, nil
    while true do
        DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 14, true)
        DisableControlAction(0, 15, true) DisableControlAction(0, 16, true) DisableControlAction(0, 17, true)
        DisableControlAction(0, 37, true) DisableControlAction(0, 174, true) DisableControlAction(0, 175, true)
        DisablePlayerFiring(PlayerId(), true)
        local changed = false
        if IsDisabledControlJustPressed(0, 15) or IsControlJustPressed(0, 172) then size = math.min(Config.Size.max, size + Config.Size.step) changed = true end
        if IsDisabledControlJustPressed(0, 14) or IsControlJustPressed(0, 173) then size = math.max(Config.Size.min, size - Config.Size.step) changed = true end
        if IsDisabledControlPressed(0, 174) then rot = math.min(Config.Rotation.max, rot + Config.Rotation.speed) changed = true end
        if IsDisabledControlPressed(0, 175) then rot = math.max(-Config.Rotation.max, rot - Config.Rotation.speed) changed = true end
        if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) or IsEntityDead(ped) then break end

        -- Détection limitée à 10 fois par seconde (les rayons ne sont pas lancés à chaque image)
        local now = GetGameTimer()
        if now >= nextCheck or changed then
            nextCheck = now + 100
            local mat, ent
            at, n, mat, ent = aimWall()
            if not at then ok, why = false, 'Vise un mur.'
            else
                why = surfaceProblem(n, mat, ent)
                if not why and #(GetEntityCoords(ped) - at) > Config.Spray.reach then why = 'Rapproche-toi du mur.' end
                if not why then local z = forbiddenAt(at) if z then why = ('Zone protégée : %s.'):format(z) end end
                if not why and not fits(at, n, size, rot) then why = 'Le tag dépasse du mur : réduis la taille ou décale-toi.' end
                ok = why == nil
            end
            help(ok and HELP or (HELP .. '\n⛔ ' .. why))
        end
        if at then
            local c = corners(at, n, size, rot)
            if slot.showAt and now >= slot.showAt then
                drawQuad(c, slot.txd, 255, ok and 255 or 70, ok and 255 or 70, ok and 200 or 130)
            end
            if ok then drawFrame(c, 255, 255, 255) else drawFrame(c, 255, 60, 60) end
        end
        if IsControlJustPressed(0, 38) then
            if ok then result = { pos = at, n = n, size = size, rot = rot } break end
            notify(why or 'Vise un mur.', 'error')
        end
        Wait(0)
    end
    Ely.hideTextUI()
    shownHelp = nil
    slot.tagId, slot.showAt = nil, nil
    return result
end

-- Animation de graffiti de GTA Online (version homme / femme), même bombe que les emotes « tag »
local function sprayAnim()
    local female = GetEntityModel(PlayerPedId()) == joaat('mp_f_freemode_01')
    return { dict = female and 'anim@scripted@freemode@postertag@graffiti_spray@heeled@' or 'anim@scripted@freemode@postertag@graffiti_spray@male@',
        clip = female and 'spray_can_var_01_female' or 'spray_can_var_01_male', flag = 1 }
end
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
        local payload = spot and { text = d.text, color = d.color, font = d.font, size = spot.size, rot = spot.rot,
            x = spot.pos.x, y = spot.pos.y, z = spot.pos.z, nx = spot.n.x, ny = spot.n.y, nz = spot.n.z }
        -- Le serveur valide l'emplacement AVANT l'animation (territoire, zone, limites…) : pas de bombe vidée pour rien
        if spot then
            local okPlace, why = Ely.callback.await('elyzea_tags:canPlace', false, payload)
            if not okPlace then notify(why or 'Impossible de peindre ici.', 'error') spot = nil end
        end
        if spot then
            local ped = PlayerPedId()
            TaskTurnPedToFaceCoord(ped, spot.pos.x, spot.pos.y, spot.pos.z, 800)
            Wait(800)
            local fx = sprayFx(spot.pos + spot.n * 0.3, d.color)
            local done = Ely.progressBar({ duration = Config.Spray.duration, label = 'Tu peins ton tag…', canCancel = true,
                disable = { move = true, car = true, combat = true }, anim = sprayAnim(), prop = SPRAY_PROP })
            if fx then StopParticleFxLooped(fx, false) end
            if done then TriggerServerEvent('elyzea_tags:server:place', payload)
            else notify('Tag annulé.', 'inform') end
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

-- ---------------------------------------------------------
--  Staff : /tagmat affiche la matière visée (pour remplir Config.Spray.forbiddenMaterials)
-- ---------------------------------------------------------
RegisterNetEvent('elyzea_tags:client:material', function()
    local at, n, mat, ent = aimWall()
    if not at then return notify('Vise une surface.', 'error') end
    notify(('Matière : %s · pente %.2f · %s'):format(tostring(mat), math.abs(n.z), (ent and ent ~= 0) and ('objet ' .. tostring(GetEntityModel(ent))) or 'décor de la map'), 'inform')
    print(('[TAGS] matière visée : %s'):format(tostring(mat)))
end)
