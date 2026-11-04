-- =====================================================================
--  ELYZEA PIER - MONTAGNES RUSSES (serveur)
--  Un seul train de 4 wagons (8 places) pour tout le serveur, comme dans le jeu original.
--  Cycle : en gare (embarquement) → départ → parcours complet du rail original → arrivée
--  → descente → train suivant. Le serveur publie GlobalState.pierCoaster = { phase, t0, scale,
--  duration, departAt } : chaque client calcule la position du train à partir de la même horloge.
-- =====================================================================
Coaster = {}
local CFG = Config.Coaster
local C = PierRide.Coaster

local SEATS = CFG.cars * CFG.seatsPerCar
local S = {
    phase = 'idle',                     -- idle | boarding | running | unloading
    seats = {},                         -- [seat] = src
    riders = {},                        -- [src] = { seat, state, offset, heading }
    queue = {},
    departAt = 0, t0 = 0, endAt = 0, unloadAt = 0,
}
local function now() return GetGameTimer() end
local lastBoard = -100000           -- embarquements un par un (Config.Coaster.boardInterval)
local function duration() return C.Duration(CFG.duration) end

function Coaster.Enabled() return CFG.enabled end
function Coaster.Capacity() return SEATS end
function Coaster.Free()
    if S.phase == 'running' or S.phase == 'unloading' then return 0 end
    local n = 0
    for s = 1, SEATS do if not S.seats[s] then n = n + 1 end end
    return n
end
function Coaster.QueueLength() return #S.queue end
function Coaster.Status()
    if not CFG.enabled then return 'fermées' end
    return ({ idle = 'en gare, prêt', boarding = 'embarquement', running = 'en cours de trajet', unloading = 'arrivée en gare' })[S.phase]
end

local function queuePos(src) for i, q in ipairs(S.queue) do if q == src then return i end end end

function Coaster.EstimatedWait(src)
    local t = now()
    local cycle = duration() + CFG.barTime + CFG.unloadTime + 3
    local base = 0
    if S.phase == 'boarding' then base = math.max(0, (S.departAt - t) / 1000)
    elseif S.phase == 'running' then base = math.max(0, (S.endAt - t) / 1000) + CFG.unloadTime
    elseif S.phase == 'unloading' then base = math.max(0, (S.unloadAt - t) / 1000) end
    local pos = queuePos(src) or (#S.queue + 1)
    local trains = (S.phase == 'running' or S.phase == 'unloading') and math.ceil(pos / SEATS) - 1 or math.floor((pos - 1 + (SEATS - Coaster.Free())) / SEATS)
    return math.floor(base + math.max(0, trains) * cycle + 0.5)
end

-- ---------------------------------------------------------------- publication
local function publishState()
    GlobalState.pierCoaster = { phase = S.phase, t0 = S.t0, scale = C.Scale(CFG.duration), duration = duration(),
        departAt = S.departAt, endAt = S.endAt }
end
local function publishSeats()
    local seats = {}
    for src, r in pairs(S.riders) do seats[tostring(src)] = { s = r.seat, o = r.offset, h = r.heading, st = r.state } end
    GlobalState.pierCoasterSeats = seats
end

local function setBusy(src, v)
    Pier.busy[src] = v and 'coaster' or nil
    if GetPlayerName(src) then Player(src).state:set('pierRide', v, true) end
end

-- ---------------------------------------------------------------- embarquement
local function freeSeatIndex()
    for s = 1, SEATS do if not S.seats[s] then return s end end
end

-- Assoit un joueur (ticket consommé ici, au moment de l'embarquement effectif)
local function board(src)
    local seat = freeSeatIndex()
    if not seat then return false, 'Le train est complet.' end
    if not Pier.TakeTicket(src, 'coaster') then return false, 'Il te faut un ticket « Montagnes russes » (billetterie).' end
    S.seats[seat] = src
    lastBoard = now()
    local car = math.ceil(seat / CFG.seatsPerCar)
    local place = ((seat - 1) % CFG.seatsPerCar) + 1
    S.riders[src] = { seat = seat, state = 'boarding' }
    setBusy(src, 'coaster')
    if S.phase == 'idle' then
        S.phase = 'boarding'
        S.departAt = now() + CFG.boardingTime * 1000
    end
    if not freeSeatIndex() then S.departAt = math.min(S.departAt, now() + CFG.fullDepartDelay * 1000) end
    TriggerClientEvent('elyzea_pier:coasterBoard', src, { seat = seat, car = car, place = place, departAt = S.departAt })
    Pier.Notify(src, ('Embarquement : wagon %d, place %d. Départ dans %d s.'):format(car, place, math.max(1, math.floor((S.departAt - now()) / 1000))), 'success')
    publishState()
    publishSeats()
    return true, { seat = seat, car = car }
end

Pier.Register('coasterJoin', function(src)
    return Pier.Locked(src, function()
        if not CFG.enabled then return false, 'Les montagnes russes sont fermées.' end
        if Pier.busy[src] then return false, Pier.busy[src] == 'coaster' and 'Tu es déjà inscrit aux montagnes russes.' or 'Tu es déjà sur une autre attraction.' end
        if not Pier.Near(src, CFG.entry, CFG.entryRadius + 1.0) then return false, 'Approche-toi du quai des montagnes russes.' end
        local ok, err = Pier.CanRide(src)
        if not ok then return false, err end
        if Pier.TicketCount(src, 'coaster') < 1 then return false, 'Il te faut un ticket « Montagnes russes » (billetterie).' end
        if (S.phase == 'idle' or S.phase == 'boarding') and #S.queue == 0 and freeSeatIndex() and now() - lastBoard >= (CFG.boardInterval or 1.5) * 1000 then
            local okb, res = board(src)
            if not okb then return false, res end
            return true, { boarded = true, seat = res.seat, car = res.car }
        end
        -- train en route ou complet : file d'attente (ticket conservé jusqu'à l'embarquement)
        S.queue[#S.queue + 1] = src
        Pier.busy[src] = 'coaster'
        Player(src).state:set('pierRide', 'coaster_queue', true)
        return true, { boarded = false, position = #S.queue, wait = Coaster.EstimatedWait(src) }
    end)
end)

-- Le client du passager indique où l'animation l'a assis
Pier.Register('coasterSeated', function(src, offset, heading)
    local r = S.riders[src]
    if not r or r.state ~= 'boarding' then return false end
    if type(offset) ~= 'table' then return false end
    local x, y, z = tonumber(offset.x), tonumber(offset.y), tonumber(offset.z)
    if not x or not y or not z or math.abs(x) > 3 or math.abs(y) > 3 or math.abs(z) > 3 then return false end
    r.offset, r.heading, r.state = { x = x, y = y, z = z }, (tonumber(heading) or 0) % 360, 'seated'
    publishSeats()
    return true
end)

local function removeRider(src)
    local r = S.riders[src]
    if not r then return end
    if S.seats[r.seat] == src then S.seats[r.seat] = nil end
    S.riders[src] = nil
    if Pier.busy[src] == 'coaster' then setBusy(src, nil) end
    publishSeats()
end

local function removeFromQueue(src, reason)
    local i = queuePos(src)
    if not i then return false end
    table.remove(S.queue, i)
    if Pier.busy[src] == 'coaster' then setBusy(src, nil) end
    if GetPlayerName(src) then TriggerClientEvent('elyzea_pier:queueLeft', src, 'coaster', reason) end
    return true
end

-- Quitter la file, ou descendre avant le départ (le ticket est rendu : le trajet n'a pas eu lieu)
function Coaster.Leave(src)
    if removeFromQueue(src, 'tu as quitté la file') then return true end
    local r = S.riders[src]
    if r and S.phase == 'boarding' then
        removeRider(src)
        Pier.GiveTicket(src, 'coaster')
        TriggerClientEvent('elyzea_pier:coasterLeft', src, { seat = r.seat })
        Pier.Notify(src, 'Tu es descendu avant le départ : ton ticket t\'a été rendu.', 'info')
        if not next(S.riders) then S.phase, S.departAt = 'idle', 0 publishState() end
        return true
    end
    return false, 'Impossible de descendre pendant le trajet.'
end

-- ---------------------------------------------------------------- cycle du train
local function depart()
    S.phase = 'running'
    S.t0 = now() + CFG.barTime * 1000
    S.endAt = S.t0 + math.floor(duration() * 1000)
    for src in pairs(S.riders) do
        TriggerClientEvent('elyzea_pier:coasterDepart', src, { t0 = S.t0, endAt = S.endAt })
    end
    publishState()
    Pier.Log(('départ des montagnes russes (%d passager(s))'):format((function() local n = 0 for _ in pairs(S.riders) do n = n + 1 end return n end)()))
end

local function arrive()
    S.phase = 'unloading'
    S.unloadAt = now() + CFG.unloadTime * 1000
    for src, r in pairs(S.riders) do
        r.state = 'arriving'
        TriggerClientEvent('elyzea_pier:coasterArrive', src, { seat = r.seat, exit = CFG.exitPoint })
        Pier.Notify(src, 'Fin du parcours : merci d\'être monté sur les montagnes russes !', 'success')
    end
    publishState()
    publishSeats()
end

local function finishUnload()
    for src in pairs(S.riders) do removeRider(src) end
    S.phase, S.departAt, S.t0, S.endAt = 'idle', 0, 0, 0
    publishState()
    -- train suivant : la file d'attente embarque dans l'ordre, un passager à la fois (boucle serveur)
end

-- Fait monter le premier passager prêt de la file (un seul à la fois)
local function boardNext()
    if not freeSeatIndex() or now() - lastBoard < (CFG.boardInterval or 1.5) * 1000 then return end
    for i, src in ipairs(S.queue) do
        if GetPlayerName(src) and Pier.CanRide(src) and Pier.Near(src, CFG.entry, CFG.queueLeaveRadius) then
            table.remove(S.queue, i)
            Pier.busy[src] = nil
            local ok, err = board(src)
            if not ok then setBusy(src, nil) TriggerClientEvent('elyzea_pier:queueLeft', src, 'coaster', err) end
            return
        end
    end
end

local lastCheck = 0
CreateThread(function()
    Wait(500)
    publishState()
    publishSeats()
    while true do
        Wait(100)
        if CFG.enabled then
            local t = now()
            if S.phase == 'boarding' then
                if not next(S.riders) then S.phase, S.departAt = 'idle', 0 publishState()
                elseif t >= S.departAt then depart() end
            elseif S.phase == 'running' then
                if t >= S.endAt then arrive() end
            elseif S.phase == 'unloading' then
                if t >= S.unloadAt then finishUnload() end
            end
            if (S.phase == 'idle' or S.phase == 'boarding') and #S.queue > 0 then boardNext() end
            if t - lastCheck > 1000 then
                lastCheck = t
                for i = #S.queue, 1, -1 do
                    local src = S.queue[i]
                    if not GetPlayerName(src) then table.remove(S.queue, i)
                    elseif not Pier.Near(src, CFG.entry, CFG.queueLeaveRadius) then removeFromQueue(src, 'tu t\'es éloigné du quai')
                    elseif Player(src).state.emsDown or GetEntityHealth(GetPlayerPed(src)) <= 0 then removeFromQueue(src, 'tu n\'es plus en état de monter (ticket conservé)') end
                end
                for src, r in pairs(S.riders) do
                    if not GetPlayerName(src) then removeRider(src)
                    elseif S.phase == 'boarding' and not Pier.Near(src, CFG.entry, CFG.queueLeaveRadius) then
                        -- parti du quai avant le départ : place libérée, ticket rendu
                        Coaster.Leave(src)
                    elseif S.phase == 'running' then
                        local x, y, z = C.PosAt(C.CarDistance(math.ceil(r.seat / CFG.seatsPerCar), C.TravelAt((t - S.t0) / 1000, C.Scale(CFG.duration)), CFG.carSpacing))
                        if t > S.t0 and not Pier.Near(src, { x = x, y = y, z = z }, Config.Security.maxRideDistance) then
                            Pier.Log(('passager %d retiré des montagnes russes (trop loin du wagon : téléportation ?)'):format(src))
                            removeRider(src)
                            TriggerClientEvent('elyzea_pier:rideCancelled', src, 'coaster')
                        end
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------- déconnexion, staff
function Coaster.Drop(src)
    for i = #S.queue, 1, -1 do if S.queue[i] == src then table.remove(S.queue, i) end end
    if S.riders[src] then
        Pier.Log(('passager %d déconnecté pendant les montagnes russes : place libérée'):format(src))
        removeRider(src)
        if S.phase == 'boarding' and not next(S.riders) then S.phase, S.departAt = 'idle', 0 publishState() end
    end
end

function Coaster.Reset(reason)
    for src in pairs(S.riders) do TriggerClientEvent('elyzea_pier:rideCancelled', src, 'coaster', reason) removeRider(src) end
    for i = #S.queue, 1, -1 do removeFromQueue(S.queue[i], reason) end
    S.phase, S.departAt, S.t0, S.endAt = 'idle', 0, 0, 0
    publishState()
end

function Coaster.Describe()
    local n = 0
    for _ in pairs(S.riders) do n = n + 1 end
    return ('Montagnes russes : %s, %d passager(s), %d en file, trajet %.0f s'):format(Coaster.Status(), n, #S.queue, duration())
end

Coaster._S = S
