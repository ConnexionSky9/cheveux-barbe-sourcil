-- =====================================================================
--  rp_animations : contrôles serveur (limites d'appels, état des joueurs)
-- =====================================================================
RPA = RPA or {}
local Sec = {}
RPA.Sec = Sec

local limits = {}   -- [src][clé] = { n, resetAt }

-- Limite d'appels : max appels par fenêtre (ms). Renvoie false si dépassé.
function Sec.Allow(src, key, max, window)
    local now = GetGameTimer()
    local byKey = limits[src]
    if not byKey then byKey = {} limits[src] = byKey end
    local l = byKey[key]
    if not l or now >= l.resetAt then
        byKey[key] = { n = 1, resetAt = now + window }
        return true
    end
    l.n = l.n + 1
    if l.n > max then
        if l.n == max + 1 then
            print(('[rp_animations] %s (%d) : trop d\'appels « %s », ignorés'):format(GetPlayerName(src) or '?', src, key))
        end
        return false
    end
    return true
end

function Sec.Forget(src) limits[src] = nil end

function Sec.Online(src)
    return type(src) == 'number' and src > 0 and GetPlayerName(src) ~= nil
end

-- Raison pour laquelle ce joueur ne peut pas participer à une animation en duo (nil = il peut)
function Sec.Blocker(src)
    if not Sec.Online(src) then return 'absent' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return 'onesync' end
    if GetEntityHealth(ped) <= 100 then return 'mort' end
    local st = Player(src).state
    for _, key in ipairs(Config.BlockingStates) do
        local v = st[key]
        if v ~= nil and v ~= false then return 'etat' end
    end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return 'vehicule' end
    return nil
end

Sec.BlockerText = {
    absent   = "n'est plus là",
    onesync  = 'est introuvable (OneSync requis)',
    mort     = "n'est pas en état (inconscient ou blessé)",
    etat     = "ne peut pas bouger librement (menotté, porté, escorté ou à terre)",
    vehicule = 'est dans un véhicule',
}

Sec.SelfText = {
    absent   = 'Action impossible',
    onesync  = 'Animation en duo impossible : OneSync requis',
    mort     = "Tu n'es pas en état de le faire",
    etat     = 'Tu ne peux pas bouger librement',
    vehicule = "Descends d'abord du véhicule",
}

function Sec.Distance(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or not pb or pa == 0 or pb == 0 then return math.huge end
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return math.huge end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

function Sec.IsAdmin(src)
    -- 'admin' : permission déjà donnée à group.admin dans permissions.cfg
    return IsPlayerAceAllowed(src, Config.AdminAce) == true or IsPlayerAceAllowed(src, 'admin') == true
end

-- Offset reçu d'un client admin (calibrage) : nombres bornés
function Sec.CleanOffset(o)
    if type(o) ~= 'table' then return nil end
    local function num(v, lim)
        v = tonumber(v)
        if not v or v ~= v or v < -lim or v > lim then return nil end
        return math.floor(v * 1000 + 0.5) / 1000
    end
    local x, y, z, h = num(o.x, 2.0), num(o.y, 2.0), num(o.z, 1.0), num(o.h, 360.0)
    if not (x and y and z and h) then return nil end
    return { x = x, y = y, z = z, h = h }
end
