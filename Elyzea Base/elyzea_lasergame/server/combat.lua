-- =====================================================================
--  ELYZEA LASERGAME - TIRS LASER (validation serveur)
--  Le client envoie des LOTS de tirs (~10 / s) : origine, direction, cible touchée, point d'impact.
--  Le serveur vérifie TOUT avant d'appliquer quoi que ce soit :
--    partie et phase, joueur vivant, arme réellement attribuée, cadence (seau à jetons),
--    chargeur / recharge, origine proche de la position serveur du tireur, portée,
--    cible dans la même partie, géométrie (la cible est bien sur la trajectoire).
--  Les dégâts viennent UNIQUEMENT de la table serveur des armes (jamais du client).
--  Les effets visuels sont relayés seulement aux membres de la partie, regroupés toutes les 100 ms.
-- =====================================================================
Combat = { modes = {} }

local HIT_RAY_TOL = 2.2      -- m : distance max entre la cible (position serveur) et la trajectoire
local HIT_POS_TOL = 2.8      -- m : distance max entre le point d'impact annoncé et la cible
local MAX_SHOTS_PER_BATCH = 24

-- Chaque mode déclare : Combat.modes[mode] = { canShoot = fn(g, p) -> bool, owns = fn(g, p, weaponId) -> bool,
--                                              apply = fn(g, src, p, w, shot) }
function Combat.Register(mode, h) Combat.modes[mode] = h end

local function vec(t)
    if type(t) ~= 'table' then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 3000 then return nil end
    return { x = x, y = y, z = z }
end
Combat.Vec = vec

-- Seau à jetons de cadence par joueur et par arme
local function allowFire(p, w, now, mult)
    p.fire = p.fire or {}
    local f = p.fire[w.id]
    local perSec = (w.rpm or 60) / 60
    local cap = math.max(3, perSec * 0.6)
    if not f then f = { tokens = cap, t = now } p.fire[w.id] = f end
    f.tokens = math.min(cap, f.tokens + (now - f.t) / 1000 * perSec * 1.15)
    f.t = now
    if f.tokens < 1 then return false end
    f.tokens = f.tokens - 1
    return true
end

-- Chargeur : renvoie false si le joueur tire alors qu'il devrait recharger
local function useAmmo(p, w, now)
    if (w.mag or 0) <= 0 then return true end
    p.ammo = p.ammo or {}
    p.reloadUntil = p.reloadUntil or {}
    if (p.reloadUntil[w.id] or 0) > now then return false end
    local a = p.ammo[w.id]
    if a == nil then a = w.mag end
    if a <= 0 then return false end
    p.ammo[w.id] = a - 1
    return true
end

function Combat.Reload(p, w, now, mult)
    if (w.mag or 0) <= 0 then return end
    p.ammo = p.ammo or {}
    p.reloadUntil = p.reloadUntil or {}
    if (p.reloadUntil[w.id] or 0) > now then return end
    -- 15 % de tolérance réseau sur la durée
    p.reloadUntil[w.id] = now + math.floor((w.reload or 0) * (mult or 1) * 0.85)
    p.ammo[w.id] = w.mag
end

-- Vérification géométrique d'un impact sur une cible dont la position serveur est tpos
function Combat.CheckHit(o, d, hitPos, tpos, range)
    local dist, t = LGU.DistToRay(o, d, tpos)
    if t < -1 or t > range + 2.0 then return false, 'portée' end
    if dist > HIT_RAY_TOL then return false, 'trajectoire' end
    if hitPos and LGU.Dist(hitPos, tpos) > HIT_POS_TOL then return false, 'impact' end
    return true
end

-- Relais des effets visuels (regroupés)
function Combat.QueueFx(g, fx)
    g.fx = g.fx or {}
    if #g.fx < 120 then g.fx[#g.fx + 1] = fx end
end

CreateThread(function()
    while true do
        Wait(100)
        for _, g in pairs(Games.list) do
            if g.fx and #g.fx > 0 and not g.closed then
                local batch = g.fx
                g.fx = {}
                Games.Send(g, 'fx', batch)
            end
        end
    end
end)

-- Réception d'un lot de tirs
RegisterNetEvent('elyzea_lasergame:shots', function(batch)
    local src = source
    if type(batch) ~= 'table' then return end
    if not Security.Allow(src, 'shots') then return end
    local g, role = Games.ByPlayer(src)
    if not g or role ~= 'player' then return end
    local h = Combat.modes[g.mode]
    local p = g.players[src]
    if not h or not p then return end
    local now = GetGameTimer()
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local spos = GetEntityCoords(ped)
    local shooterPos = { x = spos.x, y = spos.y, z = spos.z }
    local n = 0
    for _, shot in ipairs(batch) do
        n = n + 1
        if n > MAX_SHOTS_PER_BATCH then
            Security.Suspicious(src, 'lot de tirs trop grand', { n = #batch })
            break
        end
        if type(shot) ~= 'table' then break end
        local w = LGU.Weapon(tostring(shot.w or ''))
        if not w or w.disabled or not h.owns(g, p, w.id) then
            if w then Security.Suspicious(src, 'arme non attribuée', { w = shot.w }) end
            break
        end
        if shot.r then
            -- demande de recharge
            Combat.Reload(p, w, now, h.reloadMult and h.reloadMult(g, p) or 1)
        elseif h.canShoot(g, p) then
            local o, d = vec(shot.o), vec(shot.d)
            if o and d then
                d = LGU.Normalize(d)
                if LGU.Dist(o, shooterPos) > Config.Security.maxShotDistanceSlack then
                    Security.Suspicious(src, 'origine du tir éloignée', { dist = LGU.Dist(o, shooterPos) })
                elseif not allowFire(p, w, now) then
                    p.rateDrops = (p.rateDrops or 0) + 1
                    if p.rateDrops % 20 == 0 then Security.Suspicious(src, 'cadence de tir dépassée', { w = w.id, n = p.rateDrops }) end
                elseif not useAmmo(p, w, now) then
                    p.ammoDrops = (p.ammoDrops or 0) + 1
                    if p.ammoDrops % 20 == 0 then Security.Suspicious(src, 'tir sans recharge', { w = w.id }) end
                else
                    p.shotsFired = (p.shotsFired or 0) + 1
                    local endPos = vec(shot.e) or { x = o.x + d.x * w.range, y = o.y + d.y * w.range, z = o.z + d.z * w.range }
                    if LGU.Dist(o, endPos) > w.range + 2 then endPos = { x = o.x + d.x * w.range, y = o.y + d.y * w.range, z = o.z + d.z * w.range } end
                    Combat.QueueFx(g, { s = src, t = p.team or 'Z', w = w.id, o = o, e = endPos, h = shot.hit and 1 or 0 })
                    if type(shot.hit) == 'table' then h.apply(g, src, p, w, { o = o, d = d, hit = shot.hit, hp = vec(shot.hp) }) end
                    -- arme à plusieurs rayons : un impact par rayon (direction propre), plafonné à w.pellets
                    if (w.pellets or 0) > 1 and type(shot.hits) == 'table' then
                        for i = 1, math.min(#shot.hits, w.pellets) do
                            local ph = shot.hits[i]
                            local pd = type(ph) == 'table' and vec(ph.d)
                            if pd and type(ph.hit) == 'table' then
                                local nd = LGU.Normalize(pd)
                                -- la dispersion d'un rayon ne peut pas dépasser celle de l'arme (+ marge)
                                local dot = nd.x * d.x + nd.y * d.y + nd.z * d.z
                                if dot >= math.cos(math.rad((w.spread or 0) * 1.6 + 1.0)) then
                                    h.apply(g, src, p, w, { o = o, d = nd, hit = ph.hit, hp = vec(ph.hp), pellet = true })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)
