-- =====================================================================
--  ELYZEA MANUTENTION - CLIENT
--  PNJ, menu du travail, tenue (sauvegardée / rendue à l'identique), cartons portés,
--  palette qui se remplit carton par carton, objectifs, GPS, interface.
--  Le client ne décide de rien : il DEMANDE au serveur (elyzea_manutention:action) et affiche la réponse.
-- =====================================================================
Cfg = nil          -- réglages publics envoyés par le serveur
Mission = nil      -- mission en cours (vue serveur) ou nil
Work = { box = nil, pallet = nil, stacked = {}, busy = false, carryAnim = false }

local DEFAULT_MODELS = { npc = 's_m_y_construct_01', box = 'hei_prop_heist_box', boxOnPallet = 'prop_cs_cardbox_01',
    pallet = 'prop_pallet_02a', forklift = 'forklift' }
local COMPS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROPS = { 0, 1, 2, 6, 7 }
local KEY_E = 38
local npcPed, blips, menuOpen = nil, {}, false

-- ---------------------------------------------------------------- utilitaires
function MNotify(msg, kind, title)
    if not msg or msg == '' then return end
    pcall(function() exports.elyzea_core:Notify({ title = title or 'MANUTENTIONNAIRE', description = msg, type = kind or 'inform' }) end)
end
function MTextUI(text) pcall(function() if text then exports.elyzea_core:ShowTextUI(text) else exports.elyzea_core:HideTextUI() end end) end
function MAction(name, data) TriggerServerEvent('elyzea_manutention:action', name, data or {}) end

function ModelOf(kind)
    local want = Cfg and Cfg.models and Cfg.models[kind] or DEFAULT_MODELS[kind]
    local h = GetHashKey(want)
    if not IsModelInCdimage(h) then h = GetHashKey(DEFAULT_MODELS[kind]) end
    return h
end
function LoadModel(h)
    RequestModel(h)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(h)
end
local function loadDict(d)
    RequestAnimDict(d)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(d)
end
local function v3(p) return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) end
local function deleteObj(o)
    if o and DoesEntityExist(o) then
        SetEntityAsMissionEntity(o, true, true)
        DetachEntity(o, true, false)
        DeleteEntity(o)
    end
end

-- ---------------------------------------------------------------- tenue
local function gender()
    local m = GetEntityModel(PlayerPedId())
    if m == GetHashKey('mp_f_freemode_01') then return 'female' end
    return 'male'
end
local function kvpKey()
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData() end)
    return 'manut_civil_' .. tostring(ok and type(pd) == 'table' and pd.citizenid or 'default')
end
-- Tenue portée, pièce par pièce (avec la collection du vêtement : rendue à l'identique même si des packs changent)
function SnapshotOutfit()
    local ped = PlayerPedId()
    local o = { c = {}, p = {} }
    for _, c in ipairs(COMPS) do
        local r = ElyCloth and ElyCloth.read(ped, 'component', c) or { drawable = GetPedDrawableVariation(ped, c), texture = GetPedTextureVariation(ped, c) }
        o.c[tostring(c)] = { r.drawable, r.texture, col = r.col, li = r.li }
    end
    for _, p in ipairs(PROPS) do
        local r = ElyCloth and ElyCloth.read(ped, 'prop', p) or { drawable = GetPedPropIndex(ped, p), texture = GetPedPropTextureIndex(ped, p) }
        o.p[tostring(p)] = { r.drawable, math.max(0, r.texture or 0), col = r.col, li = r.li }
    end
    return o, gender()
end
local function applyPiece(ped, kind, slot, v)
    local p = { drawable = v[1], texture = v[2], col = v.col, li = v.li }
    if kind == 'prop' and (p.drawable or -1) < 0 then ClearPedProp(ped, slot) return end
    if ElyCloth and ElyCloth.apply(ped, kind, slot, p) then return end
    if kind == 'prop' then SetPedPropIndex(ped, slot, p.drawable, p.texture or 0, true)
    else SetPedComponentVariation(ped, slot, p.drawable, p.texture or 0, 0) end
end
local function applyOutfit(o)
    if type(o) ~= 'table' then return end
    local ped = PlayerPedId()
    pcall(function() exports.elyzea_clothing:IgnoreFall(4000) end)   -- le chapeau retiré n'est pas « tombé »
    for k, v in pairs(o.c or {}) do applyPiece(ped, 'component', tonumber(k), v) end
    for k, v in pairs(o.p or {}) do applyPiece(ped, 'prop', tonumber(k), v) end
end
local function putOnUniform(outfits)
    local key = kvpKey()
    if not GetResourceKvpString(key) then
        local civ = SnapshotOutfit()
        SetResourceKvp(key, json.encode(civ))      -- gardée sur le PC du joueur : rendue même après un crash
    end
    applyOutfit(outfits and outfits[gender()])
end
local function restoreCivilian()
    local key = kvpKey()
    local raw = GetResourceKvpString(key)
    if not raw then return false end
    local ok, o = pcall(json.decode, raw)
    if ok then applyOutfit(o) end
    DeleteResourceKvp(key)
    return true
end

-- ---------------------------------------------------------------- interface (NUI)
local function nui(action, data) SendNUIMessage({ action = action, data = data }) end

local STAGE = {
    collect = { n = 1, title = 'Constitution de la palette' },
    ready = { n = 2, title = 'Chargement de la palette' },
    carry = { n = 3, title = 'Transport et livraison' },
}
function ObjectiveText()
    local m = Mission
    if not m then return nil end
    if m.stage == 'collect' then
        if m.carrying then return 'Pose le carton sur ta palette', m.pallet, 'Palette' end
        return 'Récupère un carton dans le stock', NearestPickup(), 'Stock de cartons'
    elseif m.stage == 'ready' then
        if not m.vehNet then return 'Demande un Fenwick au responsable', Cfg and Cfg.npc, 'Responsable' end
        local veh = MyForklift()
        if not veh or GetVehiclePedIsIn(PlayerPedId(), false) ~= veh then return 'Monte sur ton Fenwick', veh and GetEntityCoords(veh), 'Fenwick' end
        return 'Glisse les fourches sous la palette et charge-la', m.pallet, 'Palette'
    elseif m.stage == 'carry' then
        return 'Dépose la palette dans la zone de livraison', m.delivery, m.delivery and (m.delivery.label or 'Livraison') or 'Livraison'
    end
end
function NearestPickup()
    if not Cfg then return nil end
    local c = GetEntityCoords(PlayerPedId())
    local best, bd = nil, math.huge
    for i, p in ipairs(Cfg.pickups or {}) do
        local d = #(c - v3(p))
        if d < bd then best, bd = p, d end
        p.index = i
    end
    return best
end

function RefreshHud()
    local m = Mission
    if not m then nui('hud', { show = false }) return end
    local txt, target, label = ObjectiveText()
    local distTxt = nil
    if target then
        local t = target.x and v3(target) or target
        distTxt = math.floor(#(GetEntityCoords(PlayerPedId()) - t) + 0.5)
    end
    local st = STAGE[m.stage] or STAGE.collect
    nui('hud', {
        show = true, stage = st.n, stageTitle = st.title, objective = txt, boxes = m.boxes, required = m.required,
        destination = label, distance = distTxt, carrying = m.carrying, delivered = m.delivered or 0, earned = m.earned or 0,
        pay = m.payDelivery, sprint = Cfg and Cfg.allowSprint,
    })
end

-- ---------------------------------------------------------------- blips et GPS
local function clearBlips() for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end blips = {} end
local function blip(p, sprite, color, label, route)
    local b = AddBlipForCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    SetBlipSprite(b, sprite) SetBlipColour(b, color) SetBlipScale(b, 0.75) SetBlipAsShortRange(b, not route)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(label) EndTextCommandSetBlipName(b)
    if route then SetBlipRoute(b, true) SetBlipRouteColour(b, color) end
    blips[#blips + 1] = b
    return b
end
local lastRouteKey = nil
function RefreshBlips()
    clearBlips()
    local m = Mission
    if not m or not Cfg then lastRouteKey = nil return end
    local _, target = ObjectiveText()
    local tkey = target and target.x and ('%.0f:%.0f'):format(target.x, target.y) or nil
    for i, p in ipairs(Cfg.pickups or {}) do
        blip(p, 478, 5, ('Stock de cartons n°%d'):format(i), m.stage == 'collect' and not m.carrying and target == p)
    end
    if m.pallet then blip(m.pallet, 569, 46, 'Ma palette', (m.stage == 'collect' and m.carrying) or m.stage == 'ready') end
    if m.delivery then blip(m.delivery, 50, 2, 'Livraison : ' .. (m.delivery.label or 'zone de livraison'), m.stage == 'carry') end
    local veh = MyForklift()
    if veh then
        local b = AddBlipForEntity(veh)
        SetBlipSprite(b, 357) SetBlipColour(b, 47) SetBlipScale(b, 0.7)
        BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Mon Fenwick') EndTextCommandSetBlipName(b)
        blips[#blips + 1] = b
    end
    -- GPS : point posé sur la prochaine destination quand elle change
    if tkey and tkey ~= lastRouteKey then SetNewWaypoint(target.x + 0.0, target.y + 0.0) end
    lastRouteKey = tkey
end

-- ---------------------------------------------------------------- PNJ
local function deleteNpc() if npcPed and DoesEntityExist(npcPed) then DeleteEntity(npcPed) end npcPed = nil end
local function spawnNpc()
    local n = Cfg.npc
    local h = ModelOf('npc')
    if not LoadModel(h) then return end
    npcPed = CreatePed(4, h, n.x + 0.0, n.y + 0.0, n.z - 1.0, n.h + 0.0, false, false)
    SetModelAsNoLongerNeeded(h)
    SetEntityInvincible(npcPed, true) FreezeEntityPosition(npcPed, true) SetBlockingOfNonTemporaryEvents(npcPed, true)
    SetPedCanRagdoll(npcPed, false) SetPedFleeAttributes(npcPed, 0, false)
    if n.scenario and n.scenario ~= '' then TaskStartScenarioInPlace(npcPed, n.scenario, 0, true) end
end
local npcBlip = nil
local function refreshNpcBlip()
    if npcBlip and DoesBlipExist(npcBlip) then RemoveBlip(npcBlip) end
    npcBlip = nil
    if not Cfg or not Cfg.enabled or not Cfg.npc or not Cfg.npc.placed or Cfg.npc.enabled == false then return end
    npcBlip = AddBlipForCoord(Cfg.npc.x + 0.0, Cfg.npc.y + 0.0, Cfg.npc.z + 0.0)
    SetBlipSprite(npcBlip, 478) SetBlipColour(npcBlip, 47) SetBlipScale(npcBlip, 0.8) SetBlipAsShortRange(npcBlip, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Intérim : manutentionnaire') EndTextCommandSetBlipName(npcBlip)
end

local function openMenu()
    menuOpen = true
    SetNuiFocus(true, true)
    nui('menu', {
        open = true, working = Mission ~= nil, enabled = Cfg and Cfg.enabled, boxes = Cfg and Cfg.boxesPerPallet or 20,
        pay = Cfg and Cfg.pay and Cfg.pay.delivery or 0, account = Cfg and Cfg.pay and Cfg.pay.account or 'bank',
        sprint = Cfg and Cfg.allowSprint, forklift = Cfg and Cfg.forklift and Cfg.forklift.enabled ~= false,
        delivered = Mission and Mission.delivered or 0, earned = Mission and Mission.earned or 0, hasForklift = Mission and Mission.vehNet ~= nil,
    })
end
local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    nui('menu', { open = false })
end
RegisterNUICallback('menu', function(d, cb)
    cb('ok')
    local a = d and d.action
    closeMenu()
    if a == 'accept' then MAction('accept')
    elseif a == 'finish' then MAction('finish')
    elseif a == 'replace' then MAction('replaceForklift') end
end)
RegisterNUICallback('close', function(_, cb) cb('ok') closeMenu() end)

CreateThread(function()
    while true do
        local sleep = 1200
        local n = Cfg and Cfg.npc
        if n and n.placed and n.enabled ~= false and Cfg.enabled ~= false then
            local c = GetEntityCoords(PlayerPedId())
            local d = #(c - v3(n))
            if d < 60.0 then
                if not npcPed or not DoesEntityExist(npcPed) then spawnNpc() end
            elseif d > 80.0 and npcPed then deleteNpc() end
            if d < Config.NpcDistance and not menuOpen and not IsPedInAnyVehicle(PlayerPedId(), false) then
                sleep = 0
                MTextUI(Mission and '[E] Responsable : terminer le travail' or '[E] Responsable de l\'entrepôt : intérim')
                if IsControlJustReleased(0, KEY_E) then MTextUI(nil) openMenu() end
            elseif d < Config.NpcDistance + 2.0 then
                sleep = 200
                if not Work.prompt then MTextUI(nil) end
            elseif d < 20.0 then sleep = 400 end
        elseif npcPed then deleteNpc() end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------- palette (objet + cartons empilés)
local function palletLayout(count)
    local ph, bh = ModelOf('pallet'), ModelOf('boxOnPallet')
    local pmin, pmax = GetModelDimensions(ph)
    local bmin, bmax = GetModelDimensions(bh)
    local pw, pd = math.max(0.8, pmax.x - pmin.x), math.max(0.8, pmax.y - pmin.y)
    local bw, bd, bhgt = math.max(0.2, bmax.x - bmin.x), math.max(0.2, bmax.y - bmin.y), math.max(0.15, bmax.z - bmin.z)
    local cols, rows = math.max(1, math.floor(pw / bw)), math.max(1, math.floor(pd / bd))
    local perLayer = cols * rows
    local out = {}
    for i = 0, count - 1 do
        local layer = math.floor(i / perLayer)
        local k = i % perLayer
        local cx, cy = k % cols, math.floor(k / cols)
        out[i + 1] = {
            x = (pmin.x + pmax.x) / 2 - (cols * bw) / 2 + bw * (cx + 0.5) - (bmin.x + bmax.x) / 2,
            y = (pmin.y + pmax.y) / 2 - (rows * bd) / 2 + bd * (cy + 0.5) - (bmin.y + bmax.y) / 2,
            z = pmax.z + layer * bhgt - bmin.z + 0.005,
        }
    end
    return out
end

local function ensurePallet()
    local m = Mission
    if not m or not m.pallet or m.stage ~= 'collect' then return end
    if Work.pallet and DoesEntityExist(Work.pallet) then return end
    local h = ModelOf('pallet')
    if not LoadModel(h) then return end
    local p = m.pallet
    local o = CreateObject(h, p.x + 0.0, p.y + 0.0, p.z + 0.0, true, true, false)
    SetModelAsNoLongerNeeded(h)
    SetEntityHeading(o, p.h + 0.0)
    PlaceObjectOnGroundProperly(o)
    FreezeEntityPosition(o, true)
    SetEntityAsMissionEntity(o, true, true)
    Work.pallet, Work.stacked = o, {}
    local t = GetGameTimer() + 2000
    while not NetworkGetEntityIsNetworked(o) and GetGameTimer() < t do Wait(0) end
    MAction('palletObject', { net = ObjToNet(o) })
end

-- Cartons visibles sur la palette = cartons validés par le serveur
local function syncStack()
    local m = Mission
    if not m or not Work.pallet or not DoesEntityExist(Work.pallet) then return end
    local want = math.min(m.boxes or 0, m.required or 0)
    if #Work.stacked == want then return end
    local h = ModelOf('boxOnPallet')
    if not LoadModel(h) then return end
    local lay = palletLayout(math.max(want, 1))
    while #Work.stacked < want do
        local i = #Work.stacked + 1
        local pc = GetEntityCoords(Work.pallet)
        local o = CreateObject(h, pc.x, pc.y, pc.z + 1.0, true, true, false)
        SetEntityCollision(o, false, false)
        AttachEntityToEntity(o, Work.pallet, 0, lay[i].x, lay[i].y, lay[i].z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        Work.stacked[i] = o
        MAction('boxObject', { net = ObjToNet(o) })
    end
    while #Work.stacked > want do deleteObj(table.remove(Work.stacked)) end
    SetModelAsNoLongerNeeded(h)
end

local function clearPallet()
    for _, o in ipairs(Work.stacked) do deleteObj(o) end
    Work.stacked = {}
    deleteObj(Work.pallet)
    Work.pallet = nil
end

-- ---------------------------------------------------------------- carton porté
local CARRY = { dict = 'anim@heists@box_carry@', clip = 'idle' }
local function attachBox()
    local h = ModelOf('box')
    if not LoadModel(h) then return end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local o = CreateObject(h, c.x, c.y, c.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(h)
    SetEntityCollision(o, false, false)
    AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, 60309), 0.025, 0.08, 0.255, -145.0, 290.0, 0.0, true, true, false, true, 1, true)
    Work.box = o
end
local function playCarry()
    local ped = PlayerPedId()
    if loadDict(CARRY.dict) and not IsEntityPlayingAnim(ped, CARRY.dict, CARRY.clip, 3) then
        TaskPlayAnim(ped, CARRY.dict, CARRY.clip, 4.0, 4.0, -1, 51, 0, false, false, false)
    end
end
local function stopCarry()
    deleteObj(Work.box)
    Work.box = nil
    StopAnimTask(PlayerPedId(), CARRY.dict, CARRY.clip, 2.0)
end
local function gesture(dict, clip, ms)
    local ped = PlayerPedId()
    if loadDict(dict) then
        TaskPlayAnim(ped, dict, clip, 6.0, 4.0, ms, 0, 0, false, false, false)
        Wait(ms)
    end
end

-- ---------------------------------------------------------------- réponses du serveur
local function busy(on) Work.busy = on end

RegisterNetEvent('elyzea_manutention:config', function(cfg)
    Cfg = type(cfg) == 'table' and cfg or nil
    if npcPed then deleteNpc() end
    refreshNpcBlip()
    RefreshBlips()
end)

RegisterNetEvent('elyzea_manutention:mission', function(m)
    local before = Mission
    Mission = type(m) == 'table' and m or nil
    if not Mission then
        if before then EndWork() end
        return
    end
    -- nouvelle palette (nouvelle mission ou livraison faite)
    if before and before.pallet and Mission.pallet and (before.stage == 'carry' and Mission.stage == 'collect') then
        clearPallet()
    end
    if Mission.stage == 'collect' then ensurePallet() end
    syncStack()
    RefreshBlips()
    RefreshHud()
end)

RegisterNetEvent('elyzea_manutention:result', function(name, ok, msg, extra)
    if name == 'accept' then
        if ok then
            putOnUniform(extra and extra.outfit)
            MNotify(msg, 'success')
            nui('banner', { title = 'TRAVAIL ACCEPTÉ', text = ('Remplis une palette de %d cartons, charge-la avec ton Fenwick et livre-la.'):format(Cfg and Cfg.boxesPerPallet or 20), kind = 'info' })
        else MNotify(msg, 'error') end
    elseif name == 'pickup' then
        if ok then
            CreateThread(function()
                busy(true)
                gesture('pickup_object', 'pickup_low', 900)
                attachBox()
                playCarry()
                busy(false)
                MNotify('Carton récupéré : pose-le sur ta palette.', 'inform')
            end)
        else busy(false) MNotify(msg, 'error') end
    elseif name == 'drop' then
        if ok then
            CreateThread(function()
                busy(true)
                stopCarry()
                gesture('pickup_object', 'putdown_low', 800)
                busy(false)
                local m = Mission
                if m and m.stage == 'ready' then
                    MNotify(('Palette complète : %d/%d cartons.'):format(m.boxes, m.required), 'success')
                    nui('banner', { title = 'PALETTE COMPLÈTE !', text = ('Votre palette contient %d cartons.\nVous pouvez maintenant passer à l\'étape du transport.'):format(m.required), kind = 'ok' })
                elseif m then
                    MNotify(('Carton déposé : %d/%d.'):format(m.boxes, m.required), 'success')
                end
            end)
        else busy(false) MNotify(msg, 'error') end
    elseif name == 'lift' then ForkliftLiftResult(ok, msg)
    elseif name == 'deliver' then ForkliftDeliverResult(ok, msg, extra)
    elseif name == 'unload' then ForkliftUnloadResult(ok, msg)
    elseif name == 'finish' then
        if not ok then MNotify(msg, 'error') end
    elseif name == 'replaceForklift' then MNotify(msg, ok and 'success' or 'error')
    end
end)

-- Fin du travail (demandée, staff, inactivité, déconnexion, arrêt de la ressource)
function EndWork()
    Mission = nil
    stopCarry()
    clearPallet()
    ForkliftReset()
    clearBlips()
    lastRouteKey = nil
    MTextUI(nil)
    Work.prompt = nil
    nui('hud', { show = false })
    SetWaypointOff()
end
RegisterNetEvent('elyzea_manutention:ended', function(d)
    local was = Mission ~= nil or Work.pallet ~= nil
    EndWork()
    if restoreCivilian() or was then
        local earned = d and d.earned or 0
        if d and d.reason ~= 'stop' and d.reason ~= 'logout' then
            MNotify(('Travail terminé. Ta tenue t\'a été rendue.%s'):format(earned > 0 and (' Gains : %d $.'):format(earned) or ''), 'success')
            nui('banner', { title = 'FIN DU TRAVAIL', text = ('%d palette(s) livrée(s) · %d $ gagnés'):format(d and d.delivered or 0, earned), kind = 'info' })
        end
    end
end)

-- Changement de personnage : tout est rendu ; reconnexion après un crash : tenue d'origine remise
RegisterNetEvent('elyzea:client:playerUnloaded', function() if Mission then EndWork() restoreCivilian() end end)
RegisterNetEvent('elyzea:client:playerLoaded', function()
    SetTimeout(7000, function() if not Mission then restoreCivilian() end end)
    TriggerServerEvent('elyzea_manutention:requestConfig')
end)
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    TriggerServerEvent('elyzea_manutention:requestConfig')
    SetTimeout(5000, function() if not Mission then restoreCivilian() end end)
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopCarry() clearPallet() deleteNpc() clearBlips() MTextUI(nil)
    if npcBlip and DoesBlipExist(npcBlip) then RemoveBlip(npcBlip) end
    if menuOpen then SetNuiFocus(false, false) end
end)

-- ---------------------------------------------------------------- boucle de travail (seulement pendant le travail)
local function marker(p, r, g, b, size)
    DrawMarker(1, p.x + 0.0, p.y + 0.0, p.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size or 1.2, size or 1.2, 0.5, r, g, b, 120, false, false, 2, false, nil, nil, false)
end

CreateThread(function()
    local lastHud = 0
    while true do
        local m = Mission
        if not m then
            Wait(800)
        else
            local sleep = 300
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            local prompt = nil
            local inVeh = IsPedInAnyVehicle(ped, false)

            -- carton dans les bras : course bloquée (si interdite), pas d'arme, pas de saut, pas de véhicule
            if m.carrying then
                sleep = 0
                if not Work.busy then
                    if not Work.box or not DoesEntityExist(Work.box) then attachBox() end
                    playCarry()
                end
                if not (Cfg and Cfg.allowSprint) then DisableControlAction(0, 21, true) end
                DisableControlAction(0, 22, true) DisableControlAction(0, 23, true) DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true) DisableControlAction(0, 44, true) DisableControlAction(0, 37, true)
            elseif Work.box then stopCarry() end

            if m.stage == 'collect' and not inVeh and not Work.busy then
                if not m.carrying then
                    for i, p in ipairs(Cfg and Cfg.pickups or {}) do
                        local d = #(c - v3(p))
                        if d < 25.0 then sleep = 0 marker(p, 155, 92, 255, 1.0) end
                        if d < Config.PickupDistance then
                            prompt = ('[E] Prendre un carton (%d/%d)'):format(m.boxes, m.required)
                            if IsControlJustReleased(0, KEY_E) then busy(true) MAction('pickup', { point = i }) SetTimeout(1500, function() if Work.busy and not Mission.carrying then busy(false) end end) end
                            break
                        end
                    end
                elseif m.pallet then
                    local d = #(c - v3(m.pallet))
                    if d < 25.0 then sleep = 0 marker(m.pallet, 62, 230, 176, 1.8) end
                    if d < Config.PalletDistance then
                        prompt = ('[E] Poser le carton sur la palette (%d/%d)'):format(m.boxes, m.required)
                        if IsControlJustReleased(0, KEY_E) then busy(true) MAction('drop') SetTimeout(1500, function() if Work.busy and Mission and Mission.carrying then busy(false) end end) end
                    end
                end
            end
            if m.stage == 'ready' or m.stage == 'carry' then
                local p2 = ForkliftTick(c)
                if p2 then prompt, sleep = p2, 0 elseif m.stage == 'carry' and m.delivery and #(c - v3(m.delivery)) < 60.0 then sleep = 0 end
                if m.stage == 'carry' and m.delivery and #(c - v3(m.delivery)) < 60.0 then
                    local r = (m.delivery.radius or Config.DeliveryRadius)
                    DrawMarker(1, m.delivery.x, m.delivery.y, m.delivery.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r * 2.0, r * 2.0, 0.6, 62, 230, 176, 90, false, false, 2, false, nil, nil, false)
                end
            end

            if prompt ~= Work.prompt then Work.prompt = prompt MTextUI(prompt) end
            if GetGameTimer() - lastHud > 500 then lastHud = GetGameTimer() RefreshHud() end
            Wait(sleep)
        end
    end
end)

-- Destination recalculée de temps en temps (stock le plus proche, monter sur le Fenwick…)
CreateThread(function()
    local lastKey = nil
    while true do
        Wait(1500)
        if Mission then
            local txt = ObjectiveText()
            local key = tostring(Mission.stage) .. tostring(Mission.carrying) .. tostring(txt)
            if key ~= lastKey then lastKey = key RefreshBlips() end
        else lastKey = nil end
    end
end)
