-- =====================================================================
--  ELYZEA LASERGAME - PORTES DE LA CARTE ZOMBIE (client)
--  Chaque porte a un prix (réglable par le staff), une invite d'achat (touche d'interaction),
--  une animation d'ouverture (la barrière s'enfonce dans le sol) et n'est achetable
--  qu'une fois par partie. L'achat, le prix et l'ouverture sont décidés par le serveur.
-- =====================================================================
C.Doors = { opened = {}, list = {} }

local function price(d)
    local pub = C.public or {}
    return tonumber((pub.doors or {})[d.id]) or d.price
end

function C.Doors.Init()
    C.Doors.opened = {}
    C.Doors.list = {}
    for _, d in ipairs((Map.data and Map.data.doors) or {}) do
        local x, y, z = Map.World(d.x, d.y, d.z or 1.0)
        C.Doors.list[#C.Doors.list + 1] = { id = d.id, label = d.label, p = vector3(x, y, z), def = d }
    end
end

function C.Doors.Open(id, by)
    if C.Doors.opened[id] then return end
    C.Doors.opened[id] = true
    Map.OpenDoor(id)
    for _, d in ipairs(C.Doors.list) do
        if d.id == id then
            Laser.Impact(d.p, { 170, 90, 255 }, true)
            C.Sound('door', 1.0, { x = d.p.x, y = d.p.y, z = d.p.z })
        end
    end
end

function C.Doors.Sync(list)
    for _, id in ipairs(list or {}) do C.Doors.Open(id) end
end

function C.Doors.Clear() C.Doors.opened, C.Doors.list = {}, {} end

RegisterNetEvent('elyzea_lasergame:zbDoor', function(d)
    if not C.inGame then return end
    C.Doors.Open(d.id, d.by)
    C.UI('zbFeed', { kind = 'door', name = d.by, label = d.id })
end)

-- Invite d'achat
C.Interactions[#C.Interactions + 1] = function(pos)
    if not C.inGame or C.mode ~= 'zombie' or not C.alive then return nil end
    local best, bestD
    for _, d in ipairs(C.Doors.list) do
        if not C.Doors.opened[d.id] then
            local dist = #(pos - d.p)
            if dist <= 2.6 and (not bestD or dist < bestD) then best, bestD = d, dist end
        end
    end
    if not best then return nil end
    local p = price(best.def)
    return { dist = bestD, title = best.label or 'Porte', label = 'Ouvrir', price = p, money = C.Zc.money >= p,
        action = function()
            local ok, err = RPC.Call('zb:door', best.id)
            if not ok and err then C.Notify(err, 'error') C.Sound('deny', 0.8) end
        end }
end
