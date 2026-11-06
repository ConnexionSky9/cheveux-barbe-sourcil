-- =====================================================================
--  ELYZEA LASERGAME - ARMES LASER (client) ET BOUCLE DE PARTIE
--  * L'arme GTA tenue en main ne sert qu'au visuel : le tir GTA est désactivé chaque image.
--  * Un tir = rayon depuis la caméra (avec dispersion) ; la couverture arrête le laser.
--  * Les tirs sont regroupés et envoyés au serveur toutes les 100 ms ; le serveur vérifie
--    cadence, chargeur, portée, trajectoire et applique SES dégâts.
--  * Cette boucle par image ne tourne QUE pendant une partie.
-- =====================================================================
Weapons = { current = nil, hash = nil, ammo = 0, reloadUntil = 0, nextShot = 0, out = {}, reloadMult = 1.0, slots = nil }

local function hud()
    local w = Weapons.current
    if not w then return C.UI('ammo', false) end
    C.UI('ammo', { label = w.label, cat = w.cat, ammo = Weapons.ammo, mag = w.mag, reloading = GetGameTimer() < Weapons.reloadUntil,
        reload = math.floor((w.reload or 0) * Weapons.reloadMult), slots = Weapons.slots, current = w.id })
end
Weapons.Hud = hud

-- Donne l'arme (modèle GTA pour le visuel) et prépare le chargeur
function Weapons.Equip(id)
    local w = LGU.Weapon(id)
    if not w then return end
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    local h = GetHashKey(w.model)
    GiveWeaponToPed(ped, h, 250, false, true)
    SetCurrentPedWeapon(ped, h, true)
    SetPedInfiniteAmmo(ped, true, h)
    Weapons.current, Weapons.hash = w, h
    Weapons.ammo = w.mag or 0
    Weapons.reloadUntil, Weapons.nextShot = 0, 0
    hud()
end

function Weapons.Strip()
    local ped = PlayerPedId()
    if Weapons.hash then SetPedInfiniteAmmo(ped, false, Weapons.hash) end
    RemoveAllPedWeapons(ped, true)
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    Weapons.current, Weapons.hash, Weapons.slots = nil, nil, nil
    C.UI('ammo', false)
end

local function queue(shot)
    if #Weapons.out < 24 then Weapons.out[#Weapons.out + 1] = shot end
end

-- Envoi groupé des tirs
CreateThread(function()
    while true do
        if #Weapons.out > 0 then
            local batch = Weapons.out
            Weapons.out = {}
            TriggerServerEvent('elyzea_lasergame:shots', batch)
        end
        Wait(C.inGame and 100 or 500)
    end
end)

function Weapons.Reload()
    local w = Weapons.current
    if not w or (w.mag or 0) <= 0 then return end
    local now = GetGameTimer()
    if now < Weapons.reloadUntil or Weapons.ammo >= w.mag then return end
    Weapons.reloadUntil = now + math.floor(w.reload * Weapons.reloadMult)
    queue({ w = w.id, r = true })
    TaskReloadWeapon(PlayerPedId(), true)
    C.Sound('reload', 0.7)
    hud()
    SetTimeout(math.floor(w.reload * Weapons.reloadMult), function()
        if Weapons.current == w then Weapons.ammo = w.mag hud() end
    end)
end

-- Classement de l'entité touchée : joueur de la partie
local function classify(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 1 then return nil end
    if IsPedAPlayer(ent) then
        local idx = NetworkGetPlayerIndexFromPed(ent)
        if idx and idx ~= -1 then return { k = 'p', id = GetPlayerServerId(idx) } end
        return nil
    end
    return nil
end

local function spreadDir(dir, deg)
    if deg <= 0 then return dir end
    local r = math.rad(deg)
    local a, b = (math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r
    -- deux axes perpendiculaires au tir
    local up = math.abs(dir.z) < 0.95 and vector3(0, 0, 1) or vector3(1, 0, 0)
    local right = vector3(dir.y * up.z - dir.z * up.y, dir.z * up.x - dir.x * up.z, dir.x * up.y - dir.y * up.x)
    right = right / #right
    local up2 = vector3(right.y * dir.z - right.z * dir.y, right.z * dir.x - right.x * dir.z, right.x * dir.y - right.y * dir.x)
    local d = dir + right * math.tan(a) + up2 * math.tan(b)
    return d / #d
end

local function raycast(o, dir, range, ped)
    local e = o + dir * range
    local ray = StartExpensiveSynchronousShapeTestLosProbe(o.x, o.y, o.z, e.x, e.y, e.z, -1, ped, 7)
    local _, hit, endPos, _, ent = GetShapeTestResult(ray)
    if hit == 1 or hit == true then return endPos, ent end
    return e, nil
end

local function muzzle(ped)
    local we = GetCurrentPedWeaponEntityIndex(ped)
    if we and we ~= 0 then
        local bone = GetEntityBoneIndexByName(we, 'gun_muzzle')
        if bone ~= -1 then return GetWorldPositionOfEntityBone(we, bone) end
        return GetEntityCoords(we)
    end
    return GetPedBoneCoords(ped, 57005, 0.1, 0.0, 0.0)
end

-- Cibles de mêlée possibles (fournies par le mode : joueurs adverses)
Weapons.MeleeTargets = function() return {} end

local function melee(w, ped)
    local o = GetEntityCoords(ped) + vector3(0, 0, 0.4)
    local fwd = GetEntityForwardVector(ped)
    local best, bestD
    for _, t in ipairs(Weapons.MeleeTargets()) do
        if DoesEntityExist(t.ped) then
            local tp = GetEntityCoords(t.ped)
            local v = tp - o
            local d = #v
            if d <= w.range and d > 0.05 and (v.x * fwd.x + v.y * fwd.y) / d > 0.35 and (not bestD or d < bestD) then best, bestD = t, d end
        end
    end
    if C.LoadDict('melee@large_wpn@streamed_core') then
        TaskPlayAnim(ped, 'melee@large_wpn@streamed_core', 'ground_attack_on_spot', 8.0, -8.0, 600, 48, 0.0, false, false, false)
    end
    local r, g, b = C.TeamColor(C.team)
    Laser.Blade(ped, { r, g, b }, w.range)
    C.Sound('blade', 0.9)
    local d = fwd
    local hit, hp = nil, nil
    if best then
        local tp = GetEntityCoords(best.ped)
        d = (tp - o) / #(tp - o)
        hit, hp = best.hit, tp
        Laser.Impact(tp, { r, g, b }, true)
    end
    queue({ w = w.id, o = { x = o.x, y = o.y, z = o.z }, d = { x = d.x, y = d.y, z = d.z }, e = hp and { x = hp.x, y = hp.y, z = hp.z } or nil,
        hit = hit, hp = hp and { x = hp.x, y = hp.y, z = hp.z } or nil })
end

function Weapons.Fire()
    local w = Weapons.current
    if not w then return end
    local now = GetGameTimer()
    if now < Weapons.nextShot or now < Weapons.reloadUntil then return end
    if (w.mag or 0) > 0 and Weapons.ammo <= 0 then return Weapons.Reload() end
    Weapons.nextShot = now + LGU.ShotInterval(w)
    local ped = PlayerPedId()
    if w.cat == 'melee' then return melee(w, ped) end
    local cam = GetFinalRenderedCamCoord()
    local dir = C.RotToDir(GetFinalRenderedCamRot(2))
    local spread = (w.spread or 0) * (IsPlayerFreeAiming(PlayerId()) and 0.5 or 1.0)
    local r, g, b = C.TeamColor(C.team)
    local col = { r, g, b }
    local mz = muzzle(ped)
    local shot = { w = w.id, o = { x = cam.x, y = cam.y, z = cam.z } }
    local pellets = math.max(1, w.pellets or 1)
    for i = 1, pellets do
        local d = spreadDir(dir, spread)
        local endPos, ent = raycast(cam, d, w.range, ped)
        local hit = classify(ent)
        Laser.Beam(mz, endPos, col, w.width, w.life, w.beam)
        Laser.Impact(endPos, col, w.beam == 'rail')
        if i == 1 then
            shot.d = { x = d.x, y = d.y, z = d.z }
            shot.e = { x = endPos.x, y = endPos.y, z = endPos.z }
            shot.hit = hit
            shot.hp = hit and { x = endPos.x, y = endPos.y, z = endPos.z } or nil
        elseif hit then
            shot.hits = shot.hits or {}
            shot.hits[#shot.hits + 1] = { d = { x = d.x, y = d.y, z = d.z }, hit = hit, hp = { x = endPos.x, y = endPos.y, z = endPos.z } }
        end
    end
    queue(shot)
    if (w.mag or 0) > 0 then Weapons.ammo = Weapons.ammo - 1 end
    C.Sound(w.sound or 'pistol', 0.85)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', w.cat == 'sniper' and 0.05 or 0.012)
    hud()
    if (w.mag or 0) > 0 and Weapons.ammo <= 0 then Weapons.Reload() end
end

-- Retour du serveur : impact confirmé (marqueur de touche)
RegisterNetEvent('elyzea_lasergame:hitConfirm', function(d)
    C.UI('hitmarker', { kill = d.kill })
    C.Sound(d.kill and 'kill' or 'hit', d.kill and 1.0 or 0.6)
end)

-- ---------------------------------------------------------------- boucle de partie (par image, seulement en partie)
local DISABLED = { 24, 257, 140, 141, 142, 143, 263, 264, 37, 45, 47, 58, 23, 75, 157, 158, 159, 160, 161, 162, 163, 164, 165, 14, 15, 16, 17, 99, 100 }

C.CanFire = function() return false end   -- défini par le mode (PVP : manche en cours et vivant…)

function C.StartGameLoop()
    if C.loopRunning then return end
    C.loopRunning = true
    CreateThread(function()
        local pid = PlayerId()
        local lastSlow = 0
        while C.inGame do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            DisablePlayerFiring(pid, true)
            for i = 1, #DISABLED do DisableControlAction(0, DISABLED[i], true) end
            HideHudComponentThisFrame(14)  -- réticule GTA (remplacé par celui de l'interface)
            HideHudComponentThisFrame(2)
            HideHudComponentThisFrame(19)
            HideHudComponentThisFrame(20)
            DisplayAmmoThisFrame(false)
            Map.Tick(ped, pos, C.alive and not C.frozen and C.role == 'player')
            if C.CanFire() and Weapons.current then
                if IsDisabledControlPressed(0, 24) then Weapons.Fire() end
                if IsDisabledControlJustPressed(0, 45) then Weapons.Reload() end
            end
            if C.ModeTick then C.ModeTick(ped, pos) end
            local now = GetGameTimer()
            if now - lastSlow > 1000 then
                lastSlow = now
                SetEntityInvincible(ped, true)          -- la vie est gérée par le serveur (bouclier / PV LaserGame)
                SetPedCanSwitchWeapon(ped, false)
                SetMaxWantedLevel(0)
                ClearPlayerWantedLevel(pid)
                if GetEntityHealth(ped) < 150 then SetEntityHealth(ped, 200) end
            end
            Wait(0)
        end
        C.loopRunning = false
    end)
end
