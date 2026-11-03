-- =====================================================================
--  ELYZEA PIER - GRANDE ROUE (serveur)
--  Une seule roue pour tout le serveur. Le serveur décide de l'angle (publié dans
--  GlobalState.pierWheel = { rot, t, speed, limit }), des arrêts en gare, de qui monte dans
--  quelle cabine et quand chacun descend (après un tour complet de SA cabine).
--  Comme dans le jeu original : 16 cabines, 2 places, la roue s'arrête quand une cabine en
--  gare doit être chargée ou déchargée, sinon elle tourne en continu.
-- =====================================================================
Wheel = {}
local CFG = Config.Wheel
local W = PierRide.Wheel

local S = {
    rot = 0.0, t = 0, speed = 0.0,     -- état publié
    stopped = false, stopUntil = 0, stopCabin = nil,
    cabins = {},                        -- [c] = { [seat] = src }
    riders = {},                        -- [src] = { c, s, state = 'boarding'|'riding'|'arriving', done, since, offset, heading }
    queue = {},                         -- liste ordonnée de src
}
for c = 1, CFG.cabins do S.cabins[c] = {} end

local function speed() return 360 / math.max(20, CFG.turnDuration) end
local function now() return GetGameTimer() end
local function rotNow() return W.RotAt(S, now()) end

function Wheel.Enabled() return CFG.enabled end
function Wheel.Capacity() return CFG.cabins * CFG.seatsPerCabin end
function Wheel.Free()
    local n = 0
    for c = 1, CFG.cabins do for s = 1, CFG.seatsPerCabin do if not S.cabins[c][s] then n = n + 1 end end end
    return n
end
function Wheel.QueueLength() return #S.queue end

local function queuePos(src)
    for i, q in ipairs(S.queue) do if q == src then return i end end
end

-- ---------------------------------------------------------------- publication
local function publishState()
    GlobalState.pierWheel = { rot = S.rot, t = S.t, speed = S.speed, limit = S.limit, stopped = S.stopped, stopCabin = S.stopCabin }
end

local function publishSeats()
    local seats = {}
    for src, r in pairs(S.riders) do
        seats[tostring(src)] = { c = r.c, s = r.s, o = r.offset, h = r.heading, st = r.state }
    end
    GlobalState.pierWheelSeats = seats
end

-- Fixe l'angle courant et la vitesse (et donc la courbe que calculent tous les clients)
local function setMotion(rot, spd)
    S.rot, S.t, S.speed = rot, now(), spd
    S.stopped = spd == 0
    publishState()
end

-- ---------------------------------------------------------------- estimation de l'attente
function Wheel.EstimatedWait(src)
    local pos = queuePos(src) or (#S.queue + 1)
    local stops = math.ceil(pos / CFG.seatsPerCabin)
    local perStop = W.STEP / speed() + CFG.stopDuration
    local first = S.stopped and math.max(0, (S.stopUntil - now()) / 1000) or (W.STEP / speed())
    return math.floor(first + (stops - 1) * perStop + 0.5)
end

function Wheel.Status()
    if not CFG.enabled then return 'fermée' end
    return S.stopped and ('arrêtée (cabine %d en gare)'):format(S.stopCabin or 0) or 'en rotation'
end

-- ---------------------------------------------------------------- file d'attente
Pier.Register('wheelJoin', function(src)
    return Pier.Locked(src, function()
        if not CFG.enabled then return false, 'La grande roue est fermée.' end
        if Pier.busy[src] then return false, Pier.busy[src] == 'wheel' and 'Tu es déjà dans la file de la grande roue.' or 'Tu es déjà sur une autre attraction.' end
        if not Pier.Near(src, CFG.entry, CFG.entryRadius + 1.0) then return false, 'Approche-toi de l\'entrée de la grande roue.' end
        local ok, err = Pier.CanRide(src)
        if not ok then return false, err end
        if Pier.TicketCount(src, 'wheel') < 1 then return false, 'Il te faut un ticket « Grande roue » (billetterie).' end
        S.queue[#S.queue + 1] = src
        Pier.busy[src] = 'wheel'
        Player(src).state:set('pierRide', 'wheel_queue', true)
        Wheel.Plan()
        return true, { position = #S.queue, wait = Wheel.EstimatedWait(src) }
    end)
end)

local function removeFromQueue(src, reason)
    local i = queuePos(src)
    if not i then return false end
    table.remove(S.queue, i)
    if Pier.busy[src] == 'wheel' then Pier.busy[src] = nil end
    if GetPlayerName(src) then
        Player(src).state:set('pierRide', nil, true)
        TriggerClientEvent('elyzea_pier:queueLeft', src, 'wheel', reason)
    end
    return true
end

function Wheel.Leave(src)
    if removeFromQueue(src, 'tu as quitté la file') then return true end
    return false, 'Impossible de descendre pendant le tour.'
end

-- ---------------------------------------------------------------- passagers
local function freeSeat(src)
    local r = S.riders[src]
    if not r then return end
    if S.cabins[r.c][r.s] == src then S.cabins[r.c][r.s] = nil end
    S.riders[src] = nil
    if Pier.busy[src] == 'wheel' then Pier.busy[src] = nil end
    if GetPlayerName(src) then Player(src).state:set('pierRide', nil, true) end
    publishSeats()
end

-- Embarquement dans la cabine en gare (appelé seulement par le serveur pendant un arrêt)
local function boardQueue()
    local c = S.stopCabin
    if not c then return end
    -- pas de nouvel embarquement dans les 4 dernières secondes de l'arrêt (le temps de l'animation)
    if S.stopUntil - now() < 4000 then return end
    local i = 1
    while i <= #S.queue do
        local src = S.queue[i]
        local seat
        for s = 1, CFG.seatsPerCabin do if not S.cabins[c][s] then seat = s break end end
        if not seat then return end
        local okRide = Pier.CanRide(src)
        if not okRide or not Pier.Near(src, CFG.entry, CFG.queueLeaveRadius) then
            i = i + 1   -- pas prêt (trop loin, à terre…) : il garde sa place dans la file
        else
            table.remove(S.queue, i)
            if Pier.TakeTicket(src, 'wheel') then
                S.cabins[c][seat] = src
                S.riders[src] = { c = c, s = seat, state = 'boarding', done = S.rot + 360, since = now() }
                Player(src).state:set('pierRide', 'wheel', true)
                TriggerClientEvent('elyzea_pier:wheelBoard', src, { c = c, s = seat, suffix = seat == 1 and 'one' or 'two', duration = CFG.turnDuration })
                Pier.Notify(src, ('Embarquement : cabine n°%d. Bon tour de grande roue !'):format(c), 'success')
                publishSeats()
            else
                Pier.busy[src] = nil
                Player(src).state:set('pierRide', nil, true)
                TriggerClientEvent('elyzea_pier:queueLeft', src, 'wheel', 'aucun ticket valide')
            end
        end
    end
end

-- Le client du passager indique où l'animation l'a assis (pour que les autres le voient au bon endroit)
Pier.Register('wheelSeated', function(src, offset, heading)
    local r = S.riders[src]
    if not r or r.state ~= 'boarding' then return false end
    if type(offset) ~= 'table' then return false end
    local x, y, z = tonumber(offset.x), tonumber(offset.y), tonumber(offset.z)
    if not x or not y or not z or math.abs(x) > 4 or math.abs(y) > 4 or math.abs(z) > 4 then return false end
    r.offset = { x = x, y = y, z = z }
    r.heading = (tonumber(heading) or 0) % 360
    r.state = 'riding'
    publishSeats()
    return true
end)

-- ---------------------------------------------------------------- arrêts et rotation
-- Calcule le prochain arrêt nécessaire et le publie (les clients s'arrêtent exactement dessus)
function Wheel.Plan()
    if S.stopped then return end
    local rot = rotNow()
    local target
    for _, r in pairs(S.riders) do
        if r.state ~= 'arriving' and r.done >= rot - 0.001 and (not target or r.done < target) then target = r.done end
    end
    if #S.queue > 0 then
        for c = 1, CFG.cabins do
            local free = false
            for s = 1, CFG.seatsPerCabin do if not S.cabins[c][s] then free = true end end
            if free then
                local stop = W.NextStop(rot + 0.01, c, CFG.boardAngleOffset)
                if not target or stop < target then target = stop end
            end
        end
    end
    if S.limit ~= target then
        S.rot, S.t = rot, now()
        S.limit = target
        if not target and not CFG.idleRotation then setMotion(rot, 0) else publishState() end
    end
end

local function startStop(target)
    setMotion(target, 0)
    S.limit = nil
    S.stopCabin = W.CabinAt(target, CFG.cabins, CFG.boardAngleOffset)
    S.stopUntil = now() + CFG.stopDuration * 1000
    publishState()
    -- descente des passagers dont la cabine a fait un tour complet
    for src, r in pairs(S.riders) do
        if r.c == S.stopCabin and r.done <= target + 0.01 and r.state ~= 'arriving' then
            r.state = 'arriving'
            TriggerClientEvent('elyzea_pier:wheelArrive', src, { c = r.c, s = r.s, exit = CFG.exitPoint })
            Pier.Notify(src, 'Fin du tour : merci d\'être monté sur la grande roue !', 'success')
            local who = src
            SetTimeout(5000, function() if S.riders[who] and S.riders[who].state == 'arriving' then freeSeat(who) end end)
        end
    end
    publishSeats()
    boardQueue()
end

-- ---------------------------------------------------------------- boucle serveur
local lastCheck = 0
CreateThread(function()
    Wait(500)
    setMotion(0.0, CFG.idleRotation and speed() or 0)
    publishSeats()
    while true do
        Wait(100)
        if CFG.enabled then
            local t = now()
            if S.stopped then
                if S.stopCabin then boardQueue() end
                if t >= S.stopUntil and S.stopUntil > 0 then
                    S.stopUntil = 0
                    S.stopCabin = nil
                    local needMove = #S.queue > 0 or next(S.riders) ~= nil or CFG.idleRotation
                    if needMove then setMotion(S.rot, speed()) end
                    Wheel.Plan()
                elseif S.stopUntil == 0 and (#S.queue > 0 or next(S.riders)) then
                    setMotion(S.rot, speed())
                    Wheel.Plan()
                end
            else
                local rot = rotNow()
                if S.limit and rot >= S.limit - 0.0001 then
                    startStop(S.limit)
                elseif S.speed == 0 and (#S.queue > 0 or next(S.riders)) then
                    setMotion(S.rot, speed())
                end
                if S.rot > 36000 then S.rot = S.rot - 36000 end
            end
            -- contrôles (1 fois par seconde) : file d'attente et passagers
            if t - lastCheck > 1000 then
                lastCheck = t
                for i = #S.queue, 1, -1 do
                    local src = S.queue[i]
                    if not GetPlayerName(src) then table.remove(S.queue, i)
                    elseif not Pier.Near(src, CFG.entry, CFG.queueLeaveRadius) then removeFromQueue(src, 'tu t\'es éloigné de l\'entrée')
                    elseif Player(src).state.emsDown or GetEntityHealth(GetPlayerPed(src)) <= 0 then removeFromQueue(src, 'tu n\'es plus en état de monter (ticket conservé)') end
                end
                for src, r in pairs(S.riders) do
                    if not GetPlayerName(src) then freeSeat(src)
                    elseif r.state ~= 'arriving' and not Pier.Near(src, CFG.center, Config.Security.maxRideDistance) then
                        Pier.Log(('passager %d retiré de la grande roue (trop loin : téléportation ?)'):format(src))
                        freeSeat(src)
                        TriggerClientEvent('elyzea_pier:rideCancelled', src, 'wheel')
                    end
                end
                Wheel.Plan()
            end
        end
    end
end)

-- ---------------------------------------------------------------- déconnexion, staff
function Wheel.Drop(src)
    for i = #S.queue, 1, -1 do if S.queue[i] == src then table.remove(S.queue, i) end end
    if S.riders[src] then
        Pier.Log(('passager %d déconnecté pendant le tour de grande roue : place libérée'):format(src))
        freeSeat(src)
    end
end

function Wheel.Reset(reason)
    for src in pairs(S.riders) do
        TriggerClientEvent('elyzea_pier:rideCancelled', src, 'wheel', reason)
        freeSeat(src)
    end
    for i = #S.queue, 1, -1 do removeFromQueue(S.queue[i], reason) end
    S.stopUntil, S.stopCabin, S.limit = 0, nil, nil
    setMotion(rotNow(), CFG.idleRotation and speed() or 0)
end

function Wheel.Describe()
    local n = 0
    for _ in pairs(S.riders) do n = n + 1 end
    return ('Grande roue : %s, %d passager(s), %d en file, angle %.1f°'):format(Wheel.Status(), n, #S.queue, rotNow() % 360)
end

Wheel._S = S   -- (tests)
