-- =========================================================
--  ELYZEA CASINO - client : objets posés (tables, roues, chaises), places, assise, interface
-- =========================================================
CS = {
    points = {},        -- [id] = point reçu du serveur
    enabled = true,
    ents = {},          -- [id] = { table, chairs = {}, wheel, base }
    seated = nil,       -- { id, idx, game }
    tables = {},        -- [id] = dernier état reçu
    uiOpen = nil,       -- 'cashier' | 'bj' | 'rl' | 'wheel'
}
local A = Config.Anims

function CS.Notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end
RegisterNetEvent('elyzea_casino:notify', function(msg, kind) CS.Notify(msg, kind) end)

function CS.LoadModel(model)
    local h = type(model) == 'number' and model or GetHashKey(model or '')
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(h) and h or nil
end

function CS.LoadDict(dict)
    if not dict or not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- Joue une animation (dict, clip) ; repli si elle n'existe pas. Jamais bloquant.
function CS.PlayAnim(ped, spec, flag, dur, fallback)
    if spec and CS.LoadDict(spec[1]) then
        TaskPlayAnim(ped, spec[1], spec[2], 4.0, 4.0, dur or -1, flag or 0, 0.0, false, false, false)
        return true
    end
    if fallback and CS.LoadDict(fallback[1]) then
        TaskPlayAnim(ped, fallback[1], fallback[2], 4.0, 4.0, dur or 1500, flag or 48, 0.0, false, false, false)
    end
    return false
end

-- PNJ posé par l'éditeur (croupier, animateur) : entité locale d'admin_menu
function CS.DealerPed(id)
    local ok, ent = pcall(function() return exports.admin_menu:GetSpawnedEntity('ped:' .. tostring(id)) end)
    if ok and ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    return nil
end

-- ---------------------------------------------------------------- points
RegisterNetEvent('elyzea_casino:points', function(list, enabled)
    local new = {}
    for _, p in ipairs(list or {}) do new[p.id] = p end
    -- objets des points supprimés ou déplacés : retirés
    for id, e in pairs(CS.ents) do
        local p, old = new[id], CS.points[id]
        if not p or not old or json.encode(p.table) ~= json.encode(old.table) or p.model ~= old.model
            or json.encode(p.wheel) ~= json.encode(old.wheel) then CS.Despawn(id) end
    end
    CS.points = new
    CS.enabled = enabled ~= false
    if CS.seated and not new[CS.seated.id] then CS.StandUp(true) end
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('elyzea_casino:requestPoints')
end)

local function vec(t) return vector3(t.x, t.y, t.z) end

function CS.TableModel(p)
    if p.model and p.model ~= '' then return p.model end
    return p.role == 'roulette' and Config.Models.roulette or Config.Models.blackjack
end

local function newObj(model, x, y, z, h)
    local hash = CS.LoadModel(model)
    if not hash then return nil end
    local o = CreateObjectNoOffset(hash, x, y, z, false, false, false)
    SetEntityHeading(o, h or 0.0)
    FreezeEntityPosition(o, true)
    SetModelAsNoLongerNeeded(hash)
    return o
end

-- Places : os « Chair_Base_0X » du modèle de table, sinon arc face au croupier (avec chaises posées)
function CS.Seats(id)
    local p, e = CS.points[id], CS.ents[id]
    if not p or not p.table or not e or not e.table then return {} end
    if e.seats then return e.seats end
    local seats = {}
    local center = vec(p.table)
    for i = 1, Config.MaxPlayers do
        local b = GetEntityBoneIndexByName(e.table, ('Chair_Base_0%d'):format(i))
        if b ~= -1 then
            local pos = GetWorldPositionOfEntityBone(e.table, b)
            seats[i] = { pos = pos }
        end
    end
    if #seats < Config.MaxPlayers then
        seats = {}
        -- direction croupier → centre : les joueurs sont de l'autre côté
        local dp = p.ped and vector3(p.ped.x, p.ped.y, p.ped.z) or (center + vector3(0.0, -1.0, 0.0))
        local dir = center - dp
        dir = vector3(dir.x, dir.y, 0.0)
        local len = #dir
        if len < 0.1 then dir = vector3(0.0, 1.0, 0.0) else dir = dir / len end
        local base = math.atan(dir.y, dir.x)
        local T = Config.Table
        for i = 1, Config.MaxPlayers do
            local a = base + math.rad(-T.seatArc / 2 + (i - 1) * T.seatArc / (Config.MaxPlayers - 1))
            local pos = center + vector3(math.cos(a) * T.seatRadius, math.sin(a) * T.seatRadius, 0.0)
            seats[i] = { pos = pos, spawnChair = true }
        end
    end
    for _, s in ipairs(seats) do
        local d = center - s.pos
        s.heading = (math.deg(math.atan(d.y, d.x)) - 90.0) % 360.0
    end
    e.seats = seats
    return seats
end

function CS.Spawn(id)
    local p = CS.points[id]
    if not p or not p.table or CS.ents[id] then return end
    local e = { chairs = {} }
    CS.ents[id] = e
    local t = p.table
    if p.role == 'blackjack' or p.role == 'roulette' then
        e.table = newObj(CS.TableModel(p), t.x, t.y, t.z, t.h)
        if not e.table then CS.ents[id] = nil return end
        for i, s in ipairs(CS.Seats(id)) do
            if s.spawnChair then
                local c = newObj(Config.Models.chairFallback, s.pos.x, s.pos.y, s.pos.z, (s.heading + 180.0) % 360.0)
                if c then PlaceObjectOnGroundProperly(c) e.chairs[i] = c end
            end
        end
    elseif p.role == 'wheel' and p.wheel then
        local w = p.wheel
        if w.baseModel and w.baseModel ~= '' then e.base = newObj(w.baseModel, t.x, t.y, t.z, t.h) end
        e.wheel = newObj(w.model or 'vw_prop_vw_luckywheel_02a', t.x, t.y, t.z + (w.wheelZ or 0.0), t.h)
        if e.wheel then SetEntityRotation(e.wheel, 0.0, 0.0, t.h, 2, true) end
    end
end

function CS.Despawn(id)
    local e = CS.ents[id]
    if not e then return end
    if CS.ClearCards then CS.ClearCards(id) end
    for _, o in pairs({ e.table, e.wheel, e.base, e.ball }) do if o and DoesEntityExist(o) then DeleteEntity(o) end end
    for _, c in pairs(e.chairs) do if DoesEntityExist(c) then DeleteEntity(c) end end
    CS.ents[id] = nil
end

-- Apparition / disparition selon la distance
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for id, p in pairs(CS.points) do
            if p.table then
                local d = #(pos - vec(p.table))
                if d < 90.0 and not CS.ents[id] then CS.Spawn(id)
                    if p.role ~= 'wheel' then TriggerServerEvent('elyzea_casino:requestTable', id) end
                elseif d > 110.0 and CS.ents[id] then CS.Despawn(id) end
            end
        end
        Wait(1500)
    end
end)

-- ---------------------------------------------------------------- interface
function CS.UI(msg) SendNUIMessage(msg) end
function CS.Focus(on, cursor)
    SetNuiFocus(on, cursor ~= false and on)
    if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
end

RegisterNUICallback('close', function(_, cb)
    cb(1)
    local what = CS.uiOpen
    CS.uiOpen = nil
    CS.Focus(false)
    if what == 'bj' or what == 'rl' then CS.StandUp() end
end)

-- ---------------------------------------------------------------- assise
local cam

local function tableCam(id, seat)
    local p = CS.points[id]
    if not p or not seat then return end
    local c = vec(p.table) + vector3(0.0, 0.0, Config.Table.top)
    local from = seat.pos + (seat.pos - vec(p.table)) * 0.35 + vector3(0.0, 0.0, 1.45)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', from.x, from.y, from.z, 0.0, 0.0, 0.0, 55.0, false, 2)
    PointCamAtCoord(cam, c.x, c.y, c.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 700, true, true)
end

local function dropCam()
    if cam then
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

function CS.SitDown(id, idx)
    if CS.seated or CS.sitting then return end
    local p = CS.points[id]
    if not p or not CS.ents[id] then return end
    CS.sitting = true
    local ok, err, info = Ely.callback.await('elyzea_casino:sit', false, id, idx)
    CS.sitting = false
    if not ok then return CS.Notify(err or 'Impossible de s\'asseoir.', 'error') end
    local seat = CS.Seats(id)[idx]
    local ped = PlayerPedId()
    CS.seated = { id = id, idx = idx, game = info and info.game or p.role }
    -- Le personnage marche jusqu'à la chaise puis s'assoit face à la table (jamais de téléportation brutale)
    local approach = seat.pos + (seat.pos - vec(p.table)) * 0.45
    TaskGoStraightToCoord(ped, approach.x, approach.y, approach.z, 1.0, 6000, seat.heading, 0.1)
    local t = GetGameTimer() + 6000
    while GetGameTimer() < t and #(GetEntityCoords(ped).xy - approach.xy) > 0.35 do Wait(50) end
    local sz = seat.pos.z + Config.Table.seatZ
    local back = (seat.pos - vec(p.table))
    back = vector3(back.x, back.y, 0.0)
    back = #back > 0 and back / #back * Config.Table.seatBack or back
    CS.seated.sit = { x = seat.pos.x + back.x, y = seat.pos.y + back.y, z = sz, h = seat.heading }
    TaskStartScenarioAtPosition(ped, A.sitScenario, seat.pos.x + back.x, seat.pos.y + back.y, sz, seat.heading, 0, true, true)
    Wait(800)
    if not IsPedUsingScenario(ped, A.sitScenario) then
        -- repli : position assise jouée sur place
        SetEntityCoords(ped, seat.pos.x + back.x, seat.pos.y + back.y, sz - 0.5, false, false, false, false)
        SetEntityHeading(ped, seat.heading)
        CS.PlayAnim(ped, { 'amb@prop_human_seat_chair@male@generic@base', 'base' }, 1)
    end
    tableCam(id, seat)
    CS.uiOpen = CS.seated.game == 'roulette' and 'rl' or 'bj'
    CS.Focus(true)
    CS.UI({ action = 'seat', game = CS.seated.game, id = id, idx = idx, name = p.name, me = GetPlayerServerId(PlayerId()) })
    if CS.tables[id] then CS.OnTable(id, CS.seated.game, CS.tables[id]) end
end

-- Se lever (bouton, Échap, table fermée, mort). quiet : sans prévenir le serveur (déjà fait)
function CS.StandUp(quiet)
    local s = CS.seated
    if not s then return end
    CS.seated = nil
    if not quiet then TriggerServerEvent('elyzea_casino:leave') end
    dropCam()
    CS.UI({ action = 'unseat' })
    if CS.uiOpen == 'bj' or CS.uiOpen == 'rl' then CS.uiOpen = nil CS.Focus(false) end
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    local p = CS.points[s.id]
    local seat = p and CS.Seats(s.id)[s.idx]
    if seat then
        local out = seat.pos + (seat.pos - vec(p.table)) * 0.6
        TaskGoStraightToCoord(ped, out.x, out.y, out.z, 1.0, 2000, seat.heading + 180.0, 0.2)
    end
end

RegisterNetEvent('elyzea_casino:forceLeave', function(why)
    if why then CS.Notify(why, 'info') end
    CS.StandUp(true)
end)
RegisterNUICallback('leave', function(_, cb) cb(1) CS.StandUp() end)

-- Assis : commandes de déplacement bloquées ; mort / trop loin = on se lève
CreateThread(function()
    while true do
        if CS.seated then
            local ped = PlayerPedId()
            for _, c in ipairs({ 30, 31, 32, 33, 34, 35, 21, 22, 24, 25, 44, 140, 141, 142 }) do DisableControlAction(0, c, true) end
            local p = CS.points[CS.seated.id]
            if IsEntityDead(ped) or IsPedRagdoll(ped) or not p or #(GetEntityCoords(ped) - vec(p.table)) > 6.0 then CS.StandUp() end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ---------------------------------------------------------------- invites (s'asseoir, roue)
local prompt
local function showPrompt(text)
    if prompt == text then return end
    prompt = text
    pcall(function() exports.elyzea_core:ShowTextUI(text) end)
end
local function hidePrompt()
    if not prompt then return end
    prompt = nil
    pcall(function() exports.elyzea_core:HideTextUI() end)
end

local function freeSeat(id, near)
    local st = CS.tables[id]
    local best, bd
    for i, s in ipairs(CS.Seats(id)) do
        local taken = st and st.seats and st.seats[tostring(i)]
        local max = (CS.points[id] or {}).maxPlayers or Config.MaxPlayers
        if not taken and i <= max then
            local d = #(near - s.pos)
            if not bd or d < bd then best, bd = i, d end
        end
    end
    return best, bd
end

CreateThread(function()
    while true do
        local sleep = 600
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local shown = false
        if CS.enabled and not CS.seated and not CS.uiOpen and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
            for id, p in pairs(CS.points) do
                local e = CS.ents[id]
                if p.table and e then
                    local d = #(pos - vec(p.table))
                    if d < 6.0 then sleep = 0 end
                    if (p.role == 'blackjack' or p.role == 'roulette') and d < 2.6 then
                        local idx, sd = freeSeat(id, pos)
                        if idx and sd < Config.InteractDistance then
                            local st = CS.tables[id]
                            local busy = 0
                            if st and st.seats then for _ in pairs(st.seats) do busy = busy + 1 end end
                            showPrompt(('[E] S\'asseoir · %s (%d/%d places prises)'):format(p.role == 'roulette' and 'Roulette' or 'Blackjack', busy, p.maxPlayers or 4))
                            shown = true
                            if IsControlJustPressed(0, 38) then hidePrompt() CS.SitDown(id, idx) end
                        elseif not idx and d < 2.0 then
                            showPrompt('Table complète : toutes les places sont prises.')
                            shown = true
                        end
                    elseif p.role == 'wheel' and d < Config.InteractDistance + 0.6 and CS.WheelPrompt then
                        shown = CS.WheelPrompt(id, p) or shown
                    end
                end
            end
        end
        if not shown then hidePrompt() end
        Wait(sleep)
    end
end)
CS.HidePrompt = hidePrompt
CS.ShowPrompt = showPrompt

-- ---------------------------------------------------------------- PNJ de l'éditeur (E sur le PNJ)
-- Guichetier : caisse ; croupier : s'asseoir à la place libre la plus proche ; animateur : info roue
AddEventHandler('elyzea_casino:client:npc', function(id, role)
    id = tonumber(id)
    local p = CS.points[id]
    if not p then return CS.Notify('Ce point du casino n\'est pas encore chargé.', 'error') end
    if not CS.enabled then return CS.Notify('Le casino est fermé.', 'error') end
    if p.role == 'cashier' then
        CS.OpenCashier(id)
    elseif p.role == 'blackjack' or p.role == 'roulette' then
        if not p.table then return CS.Notify('La table n\'est pas encore installée.', 'error') end
        if not CS.ents[id] then CS.Spawn(id) end
        local idx = freeSeat(id, GetEntityCoords(PlayerPedId()))
        if not idx then return CS.Notify('Toutes les places sont prises.', 'error') end
        CS.SitDown(id, idx)
    elseif p.role == 'wheel' then
        local dealer = CS.DealerPed(id)
        if dealer then CS.PlayAnim(dealer, A.greet, 48, 2000) end
        CS.Notify(p.wheel and ('%s : approche-toi de la roue et appuie sur E (%s).'):format(p.wheel.name, (p.wheel.costType == 'free' or (p.wheel.cost or 0) == 0) and 'gratuit'
            or ('%d %s'):format(p.wheel.cost, p.wheel.costType == 'money' and '$' or 'jetons')) or 'Aucune roue réglée ici.', 'info')
    end
end)

-- ---------------------------------------------------------------- guichet
function CS.OpenCashier(id)
    local dealer = CS.DealerPed(id)
    if dealer then CS.PlayAnim(dealer, A.greet, 48, 2000) end
    local info = Ely.callback.await('elyzea_casino:cashier:info', false, id)
    if not info or info.error then return CS.Notify(info and info.error or 'Guichet indisponible.', 'error') end
    CS.uiOpen = 'cashier'
    CS.Focus(true)
    CS.UI({ action = 'cashier', show = true, id = id, info = info })
end

RegisterNUICallback('cashierTx', function(d, cb)
    local ok, msg, res = Ely.callback.await('elyzea_casino:cashier:tx', false, d)
    cb({ ok = ok == true, msg = msg, res = res })
    if ok then
        local dealer = CS.DealerPed(tonumber(d.pedId))
        if dealer then CS.PlayAnim(dealer, A.fallbackHand, 48, 1500) end
        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
    end
end)

RegisterNUICallback('cashierInfo', function(d, cb)
    cb(Ely.callback.await('elyzea_casino:cashier:info', false, tonumber(d.pedId)) or {})
end)

-- ---------------------------------------------------------------- état des tables
RegisterNetEvent('elyzea_casino:table', function(id, game, st)
    CS.tables[id] = st
    if CS.OnTable then CS.OnTable(id, game, st) end
end)

function CS.OnTable(id, game, st)
    if game == 'blackjack' and CS.BJState then CS.BJState(id, st) end
    if game == 'roulette' and CS.RLState then CS.RLState(id, st) end
    if CS.seated and CS.seated.id == id then
        CS.UI({ action = game == 'roulette' and 'rlState' or 'bjState', id = id, state = st, me = GetPlayerServerId(PlayerId()), idx = CS.seated.idx })
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if CS.seated then ClearPedTasks(PlayerPedId()) end
    dropCam()
    hidePrompt()
    CS.Focus(false)
    for id in pairs(CS.ents) do CS.Despawn(id) end
end)

RegisterNUICallback('chips', function(_, cb) cb({ chips = Ely.callback.await('elyzea_casino:chips', false) or 0 }) end)
