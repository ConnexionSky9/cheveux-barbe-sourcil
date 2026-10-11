-- =====================================================================
--  ELYZEA JOBS · client : proposition d'embauche et menu ALT commun
-- =====================================================================
local function Notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end

-- ---------------------------------------------------------------------
-- Proposition d'embauche (Y accepter · L refuser)
-- ---------------------------------------------------------------------
local offer = nil

RegisterNetEvent('elyzea_jobs:recruitOffer', function(o)
    offer = o
    offer.until_ = GetGameTimer() + (o.timeout or 30) * 1000
    SendNUIMessage({ action = 'offer', offer = o })
    CreateThread(function()
        local id = o.id
        while offer and offer.id == id do
            if IsControlJustPressed(0, 246) then        -- Y
                TriggerServerEvent('elyzea_jobs:recruitAnswer', id, true)
                break
            elseif IsControlJustPressed(0, 182) then    -- L
                TriggerServerEvent('elyzea_jobs:recruitAnswer', id, false)
                break
            elseif GetGameTimer() > offer.until_ then
                break
            end
            Wait(0)
        end
        if offer and offer.id == id then offer = nil SendNUIMessage({ action = 'offerEnd' }) end
    end)
end)

RegisterNetEvent('elyzea_jobs:recruitClosed', function(id)
    if offer and offer.id == id then offer = nil SendNUIMessage({ action = 'offerEnd' }) end
end)

-- =====================================================================
--  MENU ALT
--  Les ressources métiers ajoutent leurs actions :
--      exports.elyzea_jobs:AltRegister('nom', function(ctx) return { {id=, label=, desc=, disabled=} } end,
--                                             function(id, ctx) ... end)
--  ctx = { kind = 'player'|'vehicle'|'ped'|'object'|'world', entity, serverId, coords = {x,y,z}, distance }
-- =====================================================================
local providers = {}   -- [nom] = { get, select, owner }
local active, menuOpen = false, false
local outlined = nil
local menuCtx, menuOpts = nil, nil

exports('AltRegister', function(name, get, select)
    providers[name] = { get = get, select = select, owner = GetInvokingResource() }
end)
exports('AltUnregister', function(name) providers[name] = nil end)
exports('AltIsOpen', function() return active or menuOpen end)

AddEventHandler('onClientResourceStop', function(res)
    for name, p in pairs(providers) do if p.owner == res then providers[name] = nil end end
end)

local function Outline(ent)
    if outlined == ent then return end
    if outlined and DoesEntityExist(outlined) and SetEntityDrawOutline then SetEntityDrawOutline(outlined, false) end
    outlined = ent
    if ent and SetEntityDrawOutline then
        if SetEntityDrawOutlineColor then SetEntityDrawOutlineColor(255, 255, 255, 200) end
        SetEntityDrawOutline(ent, true)
    end
end

-- Rayon caméra → curseur
local function CursorRay()
    local sx, sy = GetControlNormal(0, 239), GetControlNormal(0, 240)
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local fwd = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
    local right = vector3(math.cos(rz), math.sin(rz), 0.0)
    local up = vector3(right.y * fwd.z - right.z * fwd.y, right.z * fwd.x - right.x * fwd.z, right.x * fwd.y - right.y * fwd.x)
    local t = math.tan(math.rad(GetGameplayCamFov()) / 2)
    local dir = fwd + right * ((sx * 2.0 - 1.0) * t * GetAspectRatio(false)) + up * (-(sy * 2.0 - 1.0) * t)
    return GetGameplayCamCoord(), dir / #dir
end

-- Joueur le plus proche devant soi (secours si le curseur ne vise rien)
local function FacingPlayer()
    local me = PlayerPedId()
    local pc, fwd = GetEntityCoords(me), GetEntityForwardVector(me)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            local v = GetEntityCoords(ped) - pc
            local d = #v
            if d <= 3.0 and (d < 1.0 or (v.x * fwd.x + v.y * fwd.y) / d > 0.3) and (not bestD or d < bestD) then best, bestD = ped, d end
        end
    end
    return best
end

local function Context()
    local me = PlayerPedId()
    local myPos = GetEntityCoords(me)
    local from, dir = CursorRay()
    local to = from + dir * Config.Alt.rayDistance
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 2 | 4 | 8 | 16, me, 7)
    local _, hit, endPos, _, ent = GetShapeTestResult(ray)
    hit = hit == true or hit == 1
    local ctx = { kind = 'world', coords = hit and { x = endPos.x, y = endPos.y, z = endPos.z } or nil }
    if hit and ent and ent ~= 0 and DoesEntityExist(ent) then
        local d = #(GetEntityCoords(ent) - myPos)
        if IsEntityAPed(ent) and IsPedAPlayer(ent) and d <= Config.Alt.playerDistance then
            ctx.kind, ctx.entity = 'player', ent
        elseif IsEntityAVehicle(ent) and d <= Config.Alt.vehicleDistance then
            ctx.kind, ctx.entity = 'vehicle', ent
        elseif IsEntityAPed(ent) and d <= Config.Alt.playerDistance then
            ctx.kind, ctx.entity = 'ped', ent
        elseif IsEntityAnObject(ent) and d <= Config.Alt.playerDistance then
            ctx.kind, ctx.entity = 'object', ent
        end
    end
    if ctx.kind == 'world' then
        local f = FacingPlayer()
        if f then ctx.kind, ctx.entity = 'player', f end
    end
    if ctx.entity then
        ctx.distance = #(GetEntityCoords(ctx.entity) - myPos)
        if ctx.kind == 'player' then ctx.serverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ctx.entity)) end
        if NetworkGetEntityIsNetworked(ctx.entity) then ctx.netId = NetworkGetNetworkIdFromEntity(ctx.entity) end
    elseif ctx.coords then
        ctx.distance = #(vector3(ctx.coords.x, ctx.coords.y, ctx.coords.z) - myPos)
    end
    return ctx
end

local function Collect(ctx)
    local list = {}
    for name, p in pairs(providers) do
        local ok, opts = pcall(p.get, ctx)
        if ok and type(opts) == 'table' then
            for _, o in ipairs(opts) do
                if type(o) == 'table' and o.id and o.label then
                    list[#list + 1] = { provider = name, id = tostring(o.id), label = tostring(o.label), desc = o.desc and tostring(o.desc) or nil,
                        disabled = o.disabled == true, group = o.group and tostring(o.group) or nil, order = tonumber(o.order) or 50 }
                end
            end
        elseif not ok then
            print(('^3[elyzea_jobs] Menu ALT « %s » : %s^0'):format(name, tostring(opts)))
        end
    end
    table.sort(list, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.label < b.label end)
    return list
end

local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function TargetLabel(ctx)
    if ctx.kind == 'player' then return GetPlayerName(NetworkGetPlayerIndexFromPed(ctx.entity)) or 'la personne' end
    if ctx.kind == 'vehicle' then return 'le véhicule' end
    return nil
end

local function CloseMenu()
    if not menuOpen then return end
    menuOpen = false
    menuCtx, menuOpts = nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'altMenu', show = false })
end

local function Stop()
    active = false
    Outline(nil)
end

local function Start()
    if active or menuOpen or IsPauseMenuActive() or IsNuiFocused() then return end
    if IsEntityDead(PlayerPedId()) then return end
    active = true
    CreateThread(function()
        local ctx, opts = nil, {}
        local lastKey, lastAt = nil, 0
        while active do
            SetMouseCursorActiveThisFrame()
            DisableControlAction(0, 1, true) DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true) DisableControlAction(0, 263, true)
            local okC, c = pcall(Context)
            if okC then ctx = c end
            -- Les actions ne sont recalculées que si la cible change (ou toutes les 0,4 s pour une position)
            local key = ctx and (ctx.kind .. ':' .. tostring(ctx.entity or '') .. ':' .. (ctx.coords and ('%.1f,%.1f'):format(ctx.coords.x, ctx.coords.y) or ''))
            local now = GetGameTimer()
            if ctx and (key ~= lastKey or (not ctx.entity and now - lastAt > 400)) then
                opts = Collect(ctx)
                lastKey, lastAt = key, now
            end
            Outline(ctx and (ctx.kind == 'player' or ctx.kind == 'vehicle' or ctx.kind == 'ped' or ctx.kind == 'object') and #opts > 0 and ctx.entity or nil)
            local who = ctx and TargetLabel(ctx)
            if #opts > 0 then
                Help(('~INPUT_ATTACK~ %d action(s)%s'):format(#opts, who and (' : ' .. who) or ''))
            else
                Help(who and ('Aucune action possible sur ' .. who) or 'Visez une personne, un véhicule ou un objet')
            end
            if IsDisabledControlJustPressed(0, 24) and ctx and #opts > 0 then
                menuCtx, menuOpts = ctx, opts
                Stop()
                menuOpen = true
                SetNuiFocus(true, true)
                local ui = {}
                for i, o in ipairs(opts) do ui[i] = { key = i, label = o.label, desc = o.desc, disabled = o.disabled, group = o.group } end
                SendNUIMessage({ action = 'altMenu', show = true, title = who or 'Actions', options = ui,
                    x = GetControlNormal(0, 239), y = GetControlNormal(0, 240) })
                return
            end
            if IsEntityDead(PlayerPedId()) then break end
            Wait(0)
        end
        Stop()
    end)
end

RegisterNUICallback('altSelect', function(body, cb)
    cb({})
    local o = menuOpts and menuOpts[tonumber(body.key) or 0]
    local ctx = menuCtx
    CloseMenu()
    if not o or o.disabled or not ctx then return end
    local p = providers[o.provider]
    if not p then return end
    -- La cible est-elle toujours là ?
    if ctx.entity and (not DoesEntityExist(ctx.entity) or #(GetEntityCoords(ctx.entity) - GetEntityCoords(PlayerPedId())) > (ctx.kind == 'vehicle' and Config.Alt.vehicleDistance or Config.Alt.playerDistance) + 1.5) then
        return Notify('La cible est trop loin.', 'error')
    end
    CreateThread(function()
        local ok, err = pcall(p.select, o.id, ctx)
        if not ok then print(('^1[elyzea_jobs] Action ALT « %s/%s » : %s^0'):format(o.provider, o.id, tostring(err))) end
    end)
end)
RegisterNUICallback('altClose', function(_, cb) cb({}) CloseMenu() end)

RegisterCommand('+ely_alt', Start, false)
RegisterCommand('-ely_alt', Stop, false)
RegisterKeyMapping('+ely_alt', 'Interactions (maintenir, puis clic sur la cible)', 'keyboard', Config.Alt.key)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Outline(nil)
    if menuOpen then SetNuiFocus(false, false) end
end)
