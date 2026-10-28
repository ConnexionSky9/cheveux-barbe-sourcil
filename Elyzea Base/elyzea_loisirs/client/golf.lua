-- =====================================================================
--  GOLF - client : drapeaux, balles des joueurs, choix du club, swing animé (mini@golf),
--  rejeu de la trajectoire calculée par le serveur
-- =====================================================================
local M = {}
CL.Games.golf = M
local GC = Config.Golf
local K = Config.Keys
local courses = {}   -- [instId] = { flags = { objets }, balls = { [joueur] = objet }, blips = {} }

local function hasHoles(inst) return inst.data.holes and #inst.data.holes > 0 end

function M.Near(inst, pos, dist)
    for _, h in ipairs(inst.data.holes or {}) do
        if h.tee and #(pos - vector3(h.tee.x, h.tee.y, h.tee.z)) < dist + 250 then return true end
        if h.flag and #(pos - vector3(h.flag.x, h.flag.y, h.flag.z)) < dist + 250 then return true end
    end
    return false
end
function M.InteractPoint(inst)
    local h = inst.data.holes and inst.data.holes[1]
    return h and h.tee and vector3(h.tee.x, h.tee.y, h.tee.z + 1.0) or nil
end

-- objet posé sur le vrai sol de la carte (pied du modèle au niveau du sol)
local function onGround(model, p)
    local z = CL.Ground(p.x, p.y, p.z) or p.z
    local o = CL.Object(model, p.x, p.y, z, false)
    if o then
        local mn = GetModelDimensions(GetEntityModel(o))
        SetEntityCoordsNoOffset(o, p.x, p.y, z - math.min(0.0, mn and mn.z or 0.0), false, false, false)
    end
    return o
end
function M.Spawn(inst)
    local C = { flags = {}, balls = {}, tees = {} }
    courses[inst.id] = C
    for _, h in ipairs(inst.data.holes or {}) do
        if h.flag then C.flags[#C.flags + 1] = onGround(GC.models.flag, h.flag) end
        if h.tee then C.tees[#C.tees + 1] = onGround(GC.models.tee, h.tee) end
    end
end
function M.Despawn(inst)
    local C = courses[inst.id]
    if not C then return end
    for _, o in ipairs(C.flags) do CL.Delete(o) end
    for _, o in ipairs(C.tees) do CL.Delete(o) end
    for _, o in pairs(C.balls) do CL.Delete(o) end
    for _, b in pairs(C.blips or {}) do if DoesBlipExist(b) then RemoveBlip(b) end end
    courses[inst.id] = nil
end

-- Balle posée sur le relief réel de la carte
local function ballZ(b) local gz = CL.Ground(b.x, b.y, b.z) return (gz or b.z) + GC.ballRadius end
local function setBall(C, sid, b)
    if not b or b.lie == 'holed' then if C.balls[sid] then CL.Delete(C.balls[sid]) C.balls[sid] = nil end return end
    local z = ballZ(b)
    if not (C.balls[sid] and DoesEntityExist(C.balls[sid])) then C.balls[sid] = CL.Object(GC.models.ball, b.x, b.y, z, false)
    else SetEntityCoordsNoOffset(C.balls[sid], b.x, b.y, z, false, false, false) end
end

local myBlip, flagBlip
local function clearBlips()
    if myBlip and DoesBlipExist(myBlip) then RemoveBlip(myBlip) end
    if flagBlip and DoesBlipExist(flagBlip) then RemoveBlip(flagBlip) end
    myBlip, flagBlip = nil, nil
end

function M.OnState(pub, inst)
    local C = inst and courses[inst.id]
    if not C or not pub.data then return end
    local seen = {}
    for _, p in ipairs(pub.data.players or {}) do
        seen[p.id] = true
        if pub.state == 'IN_PROGRESS' then setBall(C, p.id, p.ball) end
    end
    for sid, o in pairs(C.balls) do if not seen[sid] or pub.state ~= 'IN_PROGRESS' then CL.Delete(o) C.balls[sid] = nil end end
    -- repères sur la carte pour MA balle et le drapeau du trou en cours
    if CL.my == pub.id and pub.state == 'IN_PROGRESS' then
        clearBlips()
        for _, p in ipairs(pub.data.players) do
            if p.id == CL.Me() and p.ball and p.ball.lie ~= 'holed' then
                myBlip = AddBlipForCoord(p.ball.x, p.ball.y, p.ball.z)
                SetBlipSprite(myBlip, 1) SetBlipColour(myBlip, 3) SetBlipScale(myBlip, 0.6)
                BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Ma balle') EndTextCommandSetBlipName(myBlip)
            end
        end
        local h = pub.data.current
        if h and h.flag then
            flagBlip = AddBlipForCoord(h.flag.x, h.flag.y, h.flag.z)
            SetBlipSprite(flagBlip, 109) SetBlipColour(flagBlip, 2) SetBlipScale(flagBlip, 0.8)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(('Trou %d'):format(pub.data.hole)) EndTextCommandSetBlipName(flagBlip)
        end
    end
end
function M.OnEnd(s, inst)
    local C = courses[inst.id]
    if C then for sid, o in pairs(C.balls) do CL.Delete(o) C.balls[sid] = nil end end
    if s and CL.my == nil then clearBlips() end
end

-- équipement vu par les autres joueurs : le club dans les mains de celui qui joue (gardé pendant son coup)
function M.Equipment(s)
    return { model = 'prop_golf_iron_01', hand = GC.clubHand }
end

-- ---------------------------------------------------------------- mon tour
local function clubAnim(club) return GC.anims[club.anim] or GC.anims.iron end

function M.Turn(s, inst, alive)
    local ped = PlayerPedId()
    local me
    for _, p in ipairs(s.data.players) do if p.id == CL.Me() then me = p end end
    if not me or not me.ball then return end
    local h = s.data.current
    local ball = me.ball
    -- 1. aller jusqu'à sa balle
    while alive() do
        local pos = GetEntityCoords(ped)
        if LU.dist2(pos.x, pos.y, ball.x, ball.y) <= GC.addressDistance then break end
        local z = ballZ(ball)
        DrawMarker(0, ball.x, ball.y, z + 1.2, 0, 0, 0, 0, 0, 0, 0.4, 0.4, 0.4, 43, 255, 154, 160, true, false, 2, false, nil, nil, false)
        CL.SendUI({ action = 'controls', show = true, game = 'golf', hint = ('À toi ! Va jusqu\'à ta balle (%.0f m).'):format(LU.dist2(pos.x, pos.y, ball.x, ball.y)) })
        Wait(0)
    end
    if not alive() then return end
    -- 2. choix du club conseillé selon la distance
    local dist = Golf.DistToFlag(h, ball.x, ball.y)
    local ci = #GC.clubs
    if ball.lie ~= 'green' then
        ci = 1
        for i, c in ipairs(GC.clubs) do if c.id ~= 'putter' and c.speed * 3.1 >= dist then ci = i end end
    end
    local dir = math.deg(math.atan(-(h.flag.x - ball.x), h.flag.y - ball.y))
    local spin, power, charging, rising, follow = 0.0, 0.0, false, true, false
    local bz = ballZ(ball)
    local curAnim
    local function address()
        local club = GC.clubs[ci]
        local a = clubAnim(club)
        -- gaucher non géré : position d'un droitier, épaule gauche vers la cible
        local hd = math.rad(dir - 90.0)
        local fx, fy = -math.sin(hd), math.cos(hd)
        local off = GC.stanceOffset or 0.75
        SetEntityCoordsNoOffset(ped, ball.x - fx * off, ball.y - fy * off, bz + (GC.stanceHeight or 0.98), false, false, false)
        SetEntityHeading(ped, dir - 90.0)
        if curAnim ~= a then
            curAnim = a
            CL.Anim.PlayClip(ped, GC.anims.dict, a.intro, 0, 8.0, 900)
            Wait(700)
            CL.Anim.PlayClip(ped, GC.anims.dict, a.idle, 1, 4.0)
            CL.Anim.Hold(ped, club.model, GC.clubHand)
        end
    end
    FreezeEntityPosition(ped, true)
    address()
    local last = GetGameTimer()
    while alive() do
        local now = GetGameTimer() local dt = (now - last) / 1000 last = now
        CL.Anim.LockControls()
        if not charging then
            local turned = false
            if IsControlPressed(0, K.left) then dir = dir + 25 * dt turned = true end
            if IsControlPressed(0, K.right) then dir = dir - 25 * dt turned = true end
            if IsControlPressed(0, K.up) then spin = LU.clamp(spin + 0.8 * dt, -GC.maxSpin, GC.maxSpin) end
            if IsControlPressed(0, K.down) then spin = LU.clamp(spin - 0.8 * dt, -GC.maxSpin, GC.maxSpin) end
            if IsDisabledControlJustPressed(0, K.nextClub) then ci = ci % #GC.clubs + 1 curAnim = nil turned = true end
            if IsDisabledControlJustPressed(0, K.prevClub) then ci = (ci - 2) % #GC.clubs + 1 curAnim = nil turned = true end
            if turned then address() end
            if IsControlJustPressed(0, K.camera) then follow = not follow end
            if IsDisabledControlJustPressed(0, K.special) and ball.lie ~= 'green' and ball.lie ~= 'tee' then
                CL.SendUI({ action = 'controls', show = false })
                CL.Anim.Clear()
                CL.Play({ type = 'unplayable' })
                return
            end
            if IsDisabledControlJustPressed(0, K.power) then charging, power, rising = true, 0.0, true end
        else
            -- jauge : monte puis redescend ; au-delà de 92 % le coup devient imprécis (rouge)
            power = power + (rising and 1 or -1) * dt / 1.4
            if power >= 1 then power, rising = 1, false elseif power <= 0.02 then power, rising = 0.02, true end
            if IsDisabledControlJustReleased(0, K.power) then break end
        end
        -- direction : ligne au sol et point d'arrivée estimé (indicatif, sans vent ni rebond)
        local club = GC.clubs[ci]
        local est = club.id == 'putter' and (club.speed * math.max(power, 0.3)) ^ 2 / (2 * GC.lies.green.roll) or club.speed * 3.1 * math.max(power, 0.3) * (GC.lies[ball.lie] or GC.lies.fairway).power
        local hd = math.rad(dir)
        local tx, ty = ball.x - math.sin(hd) * est, ball.y + math.cos(hd) * est
        local tz = CL.Ground(tx, ty, h.flag.z) or h.flag.z
        DrawLine(ball.x, ball.y, bz + 0.05, tx, ty, tz + 0.05, 43, 255, 154, 180)
        DrawMarker(25, tx, ty, tz + 0.05, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 1.0, 43, 255, 154, 120, false, false, 2, false, nil, nil, false)
        if follow then CL.Cam.Set(vector3(ball.x + math.sin(hd) * 4.0, ball.y - math.cos(hd) * 4.0, bz + 1.6), vector3(tx, ty, tz), 50.0) else CL.Cam.Stop() end
        CL.SendUI({ action = 'controls', show = true, game = 'golf', power = power, charging = charging, over = power > GC.noise.overswing,
            info = ('%s · %.0f m du trou · effet %s%.0f %%'):format(club.label, dist, spin >= 0 and '+' or '', spin * 100),
            keys = { 'A / D : direction', 'Molette : club', 'W / S : effet', 'ESPACE (maintenir) : swing', 'C : caméra', ball.lie ~= 'green' and ball.lie ~= 'tee' and 'G : balle injouable (+1)' or nil } })
        Wait(0)
    end
    if not alive() then return end
    -- 3. swing : mouvement de frappe ; la balle part au contact (rejeu envoyé par le serveur)
    CL.SendUI({ action = 'controls', show = false })
    local club = GC.clubs[ci]
    local a = clubAnim(club)
    CL.Anim.PlayClip(ped, GC.anims.dict, a.action, 0, 8.0)
    Wait(math.floor(1000 * GC.anims.impact))
    local r = CL.Play({ type = 'swing', club = club.id, power = power, dir = dir, spin = spin })
    Wait(1400)
    CL.Anim.Clear()
    if r.error then return end
    while alive() do Wait(100) end
end

-- ---------------------------------------------------------------- rejeu (tous les clients proches)
local camDir
function M.PlayShot(shot, inst, s)
    camDir = nil
    local C = courses[inst.id]
    if shot.timeout then
        if shot.shooter == CL.Me() then CL.Notify('Temps écoulé : 1 coup compté.', 'error') end
        return
    end
    if not C then return end
    if shot.drop then
        CL.SendUI({ action = 'toast', text = 'Balle injouable : +1 coup, balle replacée', kind = 'info' })
        return
    end
    local path = shot.path or {}
    local o = C.balls[shot.shooter]
    if not (o and DoesEntityExist(o)) and path[1] then
        o = CL.Object(GC.models.ball, path[1][2], path[1][3], path[1][4], false)
        C.balls[shot.shooter] = o
    end
    -- sons : frappe du club, puis rebonds / sable / eau / balle dans le trou, à l'endroit de la balle
    local function at(tt)
        local x, y, z = path[1][2], path[1][3], path[1][4]
        for i = 2, #path do
            if tt <= path[i][1] then
                local a, b = path[i - 1], path[i]
                local k = (tt - a[1]) / math.max(1e-6, b[1] - a[1])
                return vector3(a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k)
            end
        end
        return vector3(path[#path][2], path[#path][3], path[#path][4])
    end
    if path[1] then CL.Sfx(shot.club == 'putter' and 'putt' or 'swing', vector3(path[1][2], path[1][3], path[1][4]), 1.0) end
    local sounds = CL.HitPlayer(shot.hits, function(h) return at(h[1]) end, { land = 12.0, sand = 10.0, water = 10.0, cup = 2.0 })
    local start = GetGameTimer()
    local camOn = shot.shooter == CL.Me()
    local lx, ly = nil, nil
    while o and #path > 0 do
        local t = (GetGameTimer() - start) / 1000
        sounds(t)
        if t > path[#path][1] then break end
        local x, y, z = path[1][2], path[1][3], path[1][4]
        for i = 2, #path do
            if t <= path[i][1] then
                local a, b = path[i - 1], path[i]
                local k = (t - a[1]) / math.max(1e-6, b[1] - a[1])
                x, y, z = a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k
                break
            end
        end
        -- jamais sous le relief réel de la carte (le serveur raisonne sur un plan)
        local gz = CL.Ground(x, y, z)
        if gz and z < gz + GC.ballRadius then z = gz + GC.ballRadius end
        SetEntityCoordsNoOffset(o, x, y, z, false, false, false)
        -- caméra de suivi : derrière la balle, dans le sens de sa course, un peu au-dessus
        if camOn and t > 0.3 then
            if lx then
                local dx, dy = x - lx, y - ly
                local l = math.sqrt(dx * dx + dy * dy)
                if l > 0.02 then camDir = { dx / l, dy / l } end
            end
            local cd = camDir or { 0.0, 1.0 }
            CL.Cam.Set(vector3(x - cd[1] * 7.0, y - cd[2] * 7.0, z + 3.0), vector3(x + cd[1] * 4.0, y + cd[2] * 4.0, z), 55.0)
        end
        lx, ly = x, y
        Wait(0)
    end
    sounds(math.huge)
    if camOn then Wait(900) CL.Cam.Stop() end
    local LIE = { green = 'sur le green', fairway = 'sur le fairway', rough = 'dans le rough', bunker = 'dans le bunker', tee = 'au départ' }
    local text
    if shot.holed then
        local diff = (shot.strokes or 0) - (shot.par or GC.defaultPar)
        local names = { [-3] = 'Albatros !', [-2] = 'Eagle !', [-1] = 'Birdie !', [0] = 'Par', [1] = 'Bogey', [2] = 'Double bogey' }
        text = ('Dans le trou en %d coup%s · %s'):format(shot.strokes, shot.strokes > 1 and 's' or '', names[diff] or (diff > 0 and ('+%d'):format(diff) or tostring(diff)))
        if shot.strokes == 1 then text = 'TROU EN UN !' end
    elseif shot.note then text = shot.note
    else text = ('%.0f m · balle %s'):format(shot.distance or 0, LIE[shot.ball and shot.ball.lie] or '') end
    CL.SendUI({ action = 'toast', text = text, kind = shot.holed and 'win' or (shot.note and 'lose' or 'info') })
    if shot.holed and shot.shooter == CL.Me() then
        CL.Anim.PlayClip(PlayerPedId(), GC.anims.dict, (shot.strokes or 9) <= (shot.par or 4) and GC.anims.good or GC.anims.bad, 48, 4.0, 2500)
    end
end
