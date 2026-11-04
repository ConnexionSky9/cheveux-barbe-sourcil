-- =====================================================================
--  ELYZEA PIER - CLIENT : horloge commune, PNJ, interactions, interface
-- =====================================================================
P = { offset = 0, synced = false, riding = nil, queued = nil, menuOpen = false }

-- ---------------------------------------------------------------- horloge du serveur
-- Tous les clients calculent la roue et le train à partir de l'heure du SERVEUR :
-- écart mesuré par aller-retour (on garde la mesure la plus rapide).
local function syncClock()
    local best
    for _ = 1, 5 do
        local t1 = GetGameTimer()
        local s = Ely.callback.await('elyzea_pier:time', false)
        local t2 = GetGameTimer()
        if s then
            local rtt = t2 - t1
            if not best or rtt < best.rtt then best = { rtt = rtt, offset = s + rtt / 2 - t2 } end
        end
        Wait(150)
    end
    if best then P.offset, P.synced = best.offset, true end
end

function P.Now() return GetGameTimer() + P.offset end

CreateThread(function()
    while true do
        syncClock()
        Wait(120000)
    end
end)

-- ---------------------------------------------------------------- utilitaires
function P.LoadModel(name)
    local h = type(name) == 'number' and name or GetHashKey(name)
    if not IsModelInCdimage(h) then print('[elyzea_pier] modèle absent : ' .. tostring(name)) return nil end
    RequestModel(h)
    local t = GetGameTimer() + 8000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(h) and h or nil
end

function P.LoadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

function P.Notify(msg, kind)
    SendNUIMessage({ action = 'toast', data = { text = msg, kind = kind or 'info' } })
end
RegisterNetEvent('elyzea_pier:notify', function(msg, kind) P.Notify(msg, kind) end)

function P.Hud(data) SendNUIMessage({ action = 'hud', data = data or false }) end

-- Joue une animation par scène synchronisée (même méthode que le jeu original) et attend sa fin
function P.PlayScene(ped, pos, rot, dict, anim, timeout)
    local scene = CreateSynchronizedScene(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, 2)
    TaskSynchronizedScene(ped, scene, dict, anim, 8.0, -8.0, 0, 0, 1000.0, 0)
    local t = GetGameTimer() + (timeout or 8000)
    Wait(100)
    while GetGameTimer() < t do
        if not IsSynchronizedSceneRunning(scene) or GetSynchronizedScenePhase(scene) >= 0.99 then break end
        Wait(0)
    end
end

-- Attache le joueur à l'objet là où l'animation l'a placé ; renvoie le décalage (pour les autres joueurs)
function P.AttachHere(ped, obj)
    local pc = GetEntityCoords(ped)
    local off = GetOffsetFromEntityGivenWorldCoords(obj, pc.x, pc.y, pc.z)
    local heading = GetEntityHeading(ped) - GetEntityHeading(obj)
    AttachEntityToEntity(ped, obj, 0, off.x, off.y, off.z, 0.0, 0.0, heading, false, false, false, false, 2, true)
    if NetworkAllowRemoteAttachmentModification then NetworkAllowRemoteAttachmentModification(ped, true) end
    return { x = off.x, y = off.y, z = off.z }, heading
end

-- Pendant un trajet : le joueur ne peut ni marcher, ni tirer, ni sortir (la caméra reste libre)
local RIDE_CONTROLS = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 45, 47, 58, 75, 140, 141, 142, 143, 257, 263, 264 }
function P.RideLoop(check)
    CreateThread(function()
        while P.riding do
            for i = 1, #RIDE_CONTROLS do DisableControlAction(0, RIDE_CONTROLS[i], true) end
            if check then check() end
            Wait(0)
        end
    end)
end

-- ---------------------------------------------------------------- PNJ vendeur
local npc, blip
local function spawnNpc()
    local n = Config.Npc
    local h = P.LoadModel(n.model)
    if not h then return end
    local c = n.coords
    npc = CreatePed(4, h, c.x, c.y, c.z, c.w, false, true)
    SetModelAsNoLongerNeeded(h)
    -- posé sur le sol réel du ponton (la hauteur exacte n'a pas besoin d'être juste dans la config)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local t = GetGameTimer() + 2000
    local found, gz = false, c.z
    while not found and GetGameTimer() < t do
        found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
        if not found then Wait(50) end
    end
    if found and math.abs(gz - c.z) < 4.0 then SetEntityCoordsNoOffset(npc, c.x, c.y, gz, false, false, false) end
    SetEntityHeading(npc, c.w)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedCanRagdoll(npc, false)
    SetPedFleeAttributes(npc, 0, false)
    SetPedDiesWhenInjured(npc, false)
    SetEntityProofs(npc, true, true, true, true, true, true, true, true)
    if n.anim and n.anim.dict and P.LoadDict(n.anim.dict) then
        TaskPlayAnim(npc, n.anim.dict, n.anim.name, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    elseif n.scenario then
        TaskStartScenarioInPlace(npc, n.scenario, 0, true)
    end
end

local function refreshBlip()
    if blip then RemoveBlip(blip) blip = nil end
    local b = Config.Npc.blip
    if Config.Npc.enabled and b and b.enabled then
        local c = Config.Npc.coords
        blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, b.sprite) SetBlipColour(blip, b.color) SetBlipScale(blip, b.scale) SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(b.label) EndTextCommandSetBlipName(blip)
    end
end

-- Réglages du menu admin (admin_menu › Parc de Del Perro) : PNJ, blip, attractions ouvertes / fermées, appliqués en direct
local function applyPublic(v)
    if type(v) ~= 'table' then return end
    local n = v.npc
    if type(n) == 'table' then
        Config.Npc.enabled = n.enabled ~= false
        Config.Npc.coords = vector4(n.x + 0.0, n.y + 0.0, n.z + 0.0, n.h + 0.0)
        if n.model and n.model ~= '' then Config.Npc.model = n.model end
        Config.Npc.scenario = (n.scenario and n.scenario ~= '') and n.scenario or nil
        Config.Npc.blip = Config.Npc.blip or {}
        Config.Npc.blip.enabled = n.blip ~= false
    end
    if v.wheelEnabled ~= nil then Config.Wheel.enabled = v.wheelEnabled end
    if v.coasterEnabled ~= nil then Config.Coaster.enabled = v.coasterEnabled end
    if npc and DoesEntityExist(npc) then DeleteEntity(npc) npc = nil end   -- recréé à la nouvelle place / avec le nouveau modèle
    refreshBlip()
end
AddStateBagChangeHandler('pierPublic', 'global', function(_, _, value) applyPublic(value) end)

CreateThread(function()
    if GlobalState.pierPublic then applyPublic(GlobalState.pierPublic) else refreshBlip() end
    while true do
        local c = Config.Npc.coords
        local d = #(GetEntityCoords(PlayerPedId()) - vector3(c.x, c.y, c.z))
        if Config.Npc.enabled and d < 80.0 and (not npc or not DoesEntityExist(npc)) then spawnNpc()
        elseif (d > 100.0 or not Config.Npc.enabled) and npc and DoesEntityExist(npc) then DeleteEntity(npc) npc = nil end
        Wait(1500)
    end
end)

-- ---------------------------------------------------------------- interface (billetterie)
local function openMenu()
    if P.menuOpen then return end
    local ok, info = Ely.callback.await('elyzea_pier:info', false)
    if not ok then return P.Notify(info or 'Billetterie indisponible.', 'error') end
    P.menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = info })
end

local function closeMenu()
    P.menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb) cb(1) closeMenu() end)
RegisterNUICallback('buy', function(d, cb)
    local ok, msg, info = Ely.callback.await('elyzea_pier:buy', false, d.kind, d.qty, d.account)
    cb({ ok = ok == true, msg = msg, info = info })
end)
RegisterNUICallback('refresh', function(_, cb)
    local ok, info = Ely.callback.await('elyzea_pier:info', false)
    cb(ok and info or false)
end)

-- ---------------------------------------------------------------- interactions (touche E)
local prompt
local function setPrompt(text)
    if prompt == text then return end
    prompt = text
    if text then Ely.showTextUI(text) else Ely.hideTextUI() end
end

local function ticketCount(item)
    local ok, n = pcall(function() return exports.elyzea_inventory:Search('count', item) end)
    return ok and tonumber(n) or nil
end

local current   -- interaction disponible : 'npc' | 'wheel' | 'coaster' | 'leave'
CreateThread(function()
    while true do
        local wait = 1000
        local pos = GetEntityCoords(PlayerPedId())
        local npcC = Config.Npc.coords
        local dNpc = #(pos - vector3(npcC.x, npcC.y, npcC.z))
        local dWheel = #(pos - Config.Wheel.entry)
        local dCoaster = #(pos - Config.Coaster.entry)
        local near = math.min(dNpc, dWheel, dCoaster)
        current = nil
        if P.riding then
            current = (P.riding.kind == 'coaster' and P.riding.canLeave) and 'leave' or nil
            if current then setPrompt(('[%s] Descendre avant le départ (ticket rendu)'):format(Config.InteractKey)) else setPrompt(nil) end
        elseif P.queued then
            current = 'leave'
            setPrompt(('[%s] Quitter la file d\'attente'):format(Config.InteractKey))
        elseif Config.Npc.enabled and dNpc <= Config.InteractDistance then
            current = 'npc'
            setPrompt(('[%s] Parler au vendeur de tickets'):format(Config.InteractKey))
        elseif Config.Wheel.enabled and dWheel <= Config.Wheel.entryRadius then
            current = 'wheel'
            local n = ticketCount(Config.Tickets.wheel.item)
            setPrompt(('[%s] Monter dans la grande roue%s'):format(Config.InteractKey, n and (' (%d ticket%s)'):format(n, n > 1 and 's' or '') or ''))
        elseif Config.Coaster.enabled and dCoaster <= Config.Coaster.entryRadius then
            current = 'coaster'
            local n = ticketCount(Config.Tickets.coaster.item)
            setPrompt(('[%s] Monter dans les montagnes russes%s'):format(Config.InteractKey, n and (' (%d ticket%s)'):format(n, n > 1 and 's' or '') or ''))
        else
            setPrompt(nil)
        end
        if near < 30.0 or P.riding or P.queued then wait = 250 end
        Wait(wait)
    end
end)

local function interact()
    if P.menuOpen or IsPauseMenuActive() then return end
    if current == 'npc' then return openMenu() end
    if current == 'leave' then
        local ok, err = Ely.callback.await('elyzea_pier:leave', false)
        if ok then P.queued = nil P.Hud(false) elseif err then P.Notify(err, 'error') end
        return
    end
    if current == 'wheel' or current == 'coaster' then
        local ok, res = Ely.callback.await(current == 'wheel' and 'elyzea_pier:wheelJoin' or 'elyzea_pier:coasterJoin', false)
        if not ok then return P.Notify(res or 'Impossible.', 'error') end
        if type(res) == 'table' and not res.boarded then
            P.queued = current
            P.Notify(('File d\'attente : position %d, attente estimée %d s.'):format(res.position, res.wait), 'info')
            P.Hud({ ride = current, label = Config.Tickets[current].label, status = 'queue', position = res.position, wait = res.wait })
        end
    end
end

RegisterCommand('+pier_interact', interact, false)
RegisterCommand('-pier_interact', function() end, false)
RegisterKeyMapping('+pier_interact', 'Parc de Del Perro : interagir', 'keyboard', Config.InteractKey)

RegisterNetEvent('elyzea_pier:queueLeft', function(kind, reason)
    P.queued = nil
    P.Hud(false)
    if reason then P.Notify(('File d\'attente quittée : %s.'):format(reason), 'info') end
end)

-- Panneau d'attente mis à jour (position, temps, places)
CreateThread(function()
    while true do
        if P.queued and not P.riding then
            local ok, info = Ely.callback.await('elyzea_pier:info', false)
            if ok and P.queued then
                local r = info.rides[P.queued]
                P.Hud({ ride = P.queued, label = r.label, status = 'queue', wait = r.wait, free = r.free, capacity = r.capacity, queue = r.queue })
            end
            Wait(3000)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if npc and DoesEntityExist(npc) then DeleteEntity(npc) end
    if blip then RemoveBlip(blip) end
    setPrompt(nil)
    SetNuiFocus(false, false)
    local ped = PlayerPedId()
    if P.riding then DetachEntity(ped, true, true) ClearPedTasksImmediately(ped) end
end)
