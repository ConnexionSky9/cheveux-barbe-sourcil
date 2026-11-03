-- =====================================================================
--  ELYZEA LASERGAME - RENDU DES LASERS ET EFFETS (client)
--  Faisceaux épais (deux couches : cœur + halo) tournés vers la caméra, lumière dynamique
--  à la bouche du canon et à l'impact, étincelles, arc de mêlée, projectiles et flaques d'acide.
--  La boucle par image ne tourne QUE s'il y a des effets à afficher (sinon pause de 250 ms).
-- =====================================================================
Laser = { beams = {}, impacts = {}, acids = {}, puddles = {} }

local MAX_BEAMS = 90       -- au-delà, les plus anciens disparaissent (protection des performances)
local active = false

local function cross(a, b) return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
local function norm(v) local l = #v if l < 0.0001 then return vector3(0, 0, 1) end return v / l end

local function quad(a, b, p, r, g, bl, al)
    -- quadrilatère a-b épaissi de p, visible des deux côtés
    local a1, a2, b1, b2 = a + p, a - p, b + p, b - p
    DrawPoly(a1.x, a1.y, a1.z, b1.x, b1.y, b1.z, b2.x, b2.y, b2.z, r, g, bl, al)
    DrawPoly(b2.x, b2.y, b2.z, a2.x, a2.y, a2.z, a1.x, a1.y, a1.z, r, g, bl, al)
    DrawPoly(b2.x, b2.y, b2.z, b1.x, b1.y, b1.z, a1.x, a1.y, a1.z, r, g, bl, al)
    DrawPoly(a1.x, a1.y, a1.z, a2.x, a2.y, a2.z, b2.x, b2.y, b2.z, r, g, bl, al)
end

local function drawBeam(b, now, cam)
    local age = now - b.born
    local k = 1.0 - age / b.life
    if k <= 0 then return false end
    local dir = b.e - b.o
    local mid = (b.o + b.e) * 0.5
    local side = norm(cross(dir, cam - mid))
    local r, g, bl = b.c[1], b.c[2], b.c[3]
    local w = b.w * (b.kind == 'rail' and (1.0 + (1 - k) * 0.8) or 1.0)
    -- halo
    quad(b.o, b.e, side * (w * 3.2), r, g, bl, math.floor(70 * k))
    -- cœur lumineux (presque blanc)
    quad(b.o, b.e, side * w, math.min(255, r + 120), math.min(255, g + 120), math.min(255, bl + 120), math.floor(235 * k))
    DrawLine(b.o.x, b.o.y, b.o.z, b.e.x, b.e.y, b.e.z, r, g, bl, math.floor(255 * k))
    if age < 70 then DrawLightWithRange(b.o.x, b.o.y, b.o.z, r, g, bl, 2.5, 4.0 * k) end
    return true
end

local function drawImpact(i, now)
    local age = now - i.born
    if age > 160 then return false end
    local k = 1.0 - age / 160
    DrawLightWithRange(i.p.x, i.p.y, i.p.z, i.c[1], i.c[2], i.c[3], 3.0, 6.0 * k)
    DrawMarker(28, i.p.x, i.p.y, i.p.z, 0, 0, 0, 0, 0, 0, 0.12 * (1 + (1 - k) * 2), 0.12 * (1 + (1 - k) * 2), 0.12 * (1 + (1 - k) * 2),
        i.c[1], i.c[2], i.c[3], math.floor(200 * k), false, false, 2, false, nil, nil, false)
    return true
end

local function sparks(p, c, big)
    if not C.settings.effects then return end
    if not HasNamedPtfxAssetLoaded('core') then RequestNamedPtfxAsset('core') return end
    UseParticleFxAssetNextCall('core')
    SetParticleFxNonLoopedColour(c[1] / 255, c[2] / 255, c[3] / 255)
    StartParticleFxNonLoopedAtCoord(big and 'ent_brk_sparking_wires' or 'ent_sht_electrical_box', p.x, p.y, p.z, 0.0, 0.0, 0.0, big and 0.8 or 0.35, false, false, false)
end

local function ensureLoop()
    if active then return end
    active = true
    CreateThread(function()
        while active do
            local now = GetGameTimer()
            local cam = GetFinalRenderedCamCoord()
            local any = false
            for i = #Laser.beams, 1, -1 do
                if not drawBeam(Laser.beams[i], now, cam) then table.remove(Laser.beams, i) else any = true end
            end
            for i = #Laser.impacts, 1, -1 do
                if not drawImpact(Laser.impacts[i], now) then table.remove(Laser.impacts, i) else any = true end
            end
            for i = #Laser.acids, 1, -1 do
                local a = Laser.acids[i]
                local t = (now - a.start) / a.flight
                if now < a.start then any = true
                elseif t >= 1 then table.remove(Laser.acids, i) Laser.Puddle(a.to, a.radius, a.duration)
                else
                    any = true
                    local p = a.from + (a.to - a.from) * t + vector3(0, 0, math.sin(t * math.pi) * a.arc)
                    DrawMarker(28, p.x, p.y, p.z, 0, 0, 0, 0, 0, 0, 0.35, 0.35, 0.35, 120, 255, 40, 220, false, false, 2, false, nil, nil, false)
                    DrawLightWithRange(p.x, p.y, p.z, 120, 255, 40, 3.0, 3.0)
                end
            end
            for i = #Laser.puddles, 1, -1 do
                local pd = Laser.puddles[i]
                if now > pd.ends then
                    if pd.fx then StopParticleFxLooped(pd.fx, false) end
                    table.remove(Laser.puddles, i)
                else
                    any = true
                    local pulse = 0.85 + math.sin(now / 160) * 0.15
                    DrawMarker(1, pd.p.x, pd.p.y, pd.p.z - 0.95, 0, 0, 0, 0, 0, 0, pd.r * 2, pd.r * 2, 0.25, 90, 255, 30, math.floor(110 * pulse), false, false, 2, false, nil, nil, false)
                    DrawLightWithRange(pd.p.x, pd.p.y, pd.p.z, 90, 255, 30, pd.r * 1.8, 1.8)
                end
            end
            if not any then active = false break end
            Wait(0)
        end
    end)
end

-- Faisceau : o, e = vector3 · c = {r,g,b} · kind = pulse | beam | rail | scatter | blade
function Laser.Beam(o, e, c, w, life, kind)
    if #Laser.beams >= MAX_BEAMS then table.remove(Laser.beams, 1) end
    Laser.beams[#Laser.beams + 1] = { o = o, e = e, c = c, w = w or 0.02, life = life or 80, born = GetGameTimer(), kind = kind }
    ensureLoop()
end

function Laser.Impact(p, c, big)
    if #Laser.impacts > 40 then table.remove(Laser.impacts, 1) end
    Laser.impacts[#Laser.impacts + 1] = { p = p, c = c, born = GetGameTimer() }
    sparks(p, c, big)
    ensureLoop()
end

-- Arc de mêlée devant le tireur
function Laser.Blade(ped, c, range)
    local o = GetEntityCoords(ped) + vector3(0, 0, 0.35)
    local fwd = GetEntityForwardVector(ped)
    local right = vector3(fwd.y, -fwd.x, 0)
    local prev
    for i = -4, 4 do
        local a = i / 4 * 0.9
        local p = o + (fwd * math.cos(a) + right * math.sin(a)) * range * 0.85 + vector3(0, 0, -i * 0.06)
        if prev then Laser.Beam(prev, p, c, 0.03, 180, 'blade') end
        prev = p
    end
end

-- Tir d'un joueur (local ou relayé par le serveur)
function Laser.Shot(weaponId, o, e, team, hit)
    local w = LGU.Weapon(weaponId)
    if not w then return end
    local r, g, b = C.TeamColor(team)
    local c = { r, g, b }
    if w.beam == 'blade' then return end
    Laser.Beam(o, e, c, w.width, w.life, w.beam)
    Laser.Impact(e, c, w.beam == 'rail')
end

-- Crachat d'acide : projectile en cloche puis flaque
function Laser.Acid(from, to, windup, flight, radius, duration)
    Laser.acids[#Laser.acids + 1] = { from = from, to = to, start = GetGameTimer() + (windup or 0), flight = flight or 900,
        arc = math.min(6.0, #(to - from) * 0.25), radius = radius or 2.5, duration = duration or 6000 }
    ensureLoop()
end

function Laser.Puddle(p, r, duration)
    local fx
    if C.settings.effects and C.LoadPtfx('core') then
        UseParticleFxAssetNextCall('core')
        fx = StartParticleFxLoopedAtCoord('exp_grd_bzgas_smoke', p.x, p.y, p.z - 0.9, 0.0, 0.0, 0.0, r * 0.35, false, false, false, false)
        if fx then SetParticleFxLoopedColour(fx, 0.35, 1.0, 0.1, false) end
    end
    Laser.puddles[#Laser.puddles + 1] = { p = p, r = r, ends = GetGameTimer() + duration, fx = fx }
    C.Sound('acid', 0.7, { x = p.x, y = p.y, z = p.z })
    ensureLoop()
end

function Laser.Clear()
    for _, pd in ipairs(Laser.puddles) do if pd.fx then StopParticleFxLooped(pd.fx, false) end end
    Laser.beams, Laser.impacts, Laser.acids, Laser.puddles = {}, {}, {}, {}
end

-- Effets relayés par le serveur (tirs des autres joueurs de la partie)
RegisterNetEvent('elyzea_lasergame:fx', function(batch)
    if not C.inGame or type(batch) ~= 'table' then return end
    for _, f in ipairs(batch) do
        if f.s ~= C.serverId and f.o and f.e then
            local o, e = vector3(f.o.x, f.o.y, f.o.z), vector3(f.e.x, f.e.y, f.e.z)
            -- le faisceau part de l'arme du tireur s'il est visible (plus joli que l'origine caméra)
            local p = GetPlayerFromServerId(f.s)
            if p ~= -1 then
                local ped = GetPlayerPed(p)
                local we = GetCurrentPedWeaponEntityIndex(ped)
                if we and we ~= 0 then
                    local bone = GetEntityBoneIndexByName(we, 'gun_muzzle')
                    o = bone ~= -1 and GetWorldPositionOfEntityBone(we, bone) or GetEntityCoords(we)
                end
            end
            Laser.Shot(f.w, o, e, f.t)
            local w = LGU.Weapon(f.w)
            if w then C.Sound(w.sound or 'pistol', 0.6, f.o) end
        end
    end
end)
