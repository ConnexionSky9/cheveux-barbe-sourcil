-- =========================================================
--  PVP ARENA - client : interface, entrée / sortie de l'arène, armes prêtées (jamais dans
--  l'inventaire RP), munitions illimitées limitées à l'arène, décompte, mort → spectateur,
--  retour au RP. Le client n'a aucune autorité : il affiche et transmet des demandes.
-- =========================================================
local A = {
    open = false,       -- interface ouverte avec le curseur
    inArena = false,    -- dans une partie (instance de l'arène)
    phase = nil,        -- WEAPON_SELECTION | COUNTDOWN | IN_ROUND | ROUND_END | MATCH_END
    team = nil, weapon = nil, frozen = false, eliminated = false, ff = false,
    arena = nil, deathSent = false, spectateIdx = 1, cam = nil, aliveList = {},
}
PvpArena = A

local function notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end
RegisterNetEvent('pvp_arena:notify', function(msg, kind) notify(msg, kind) SendNUIMessage({ action = 'toast', text = msg, kind = kind }) end)

local function ui(msg) SendNUIMessage(msg) end
local function focus(on)
    A.open = on
    SetNuiFocus(on, on)
    if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
end

-- ---------------------------------------------------------------- ouverture de l'interface
local opening = false
function A.Open()
    if opening or A.open then return end
    if A.inArena then return end
    opening = true
    local ok, data = Ely.callback.await('pvp_arena:open', false)
    opening = false
    if not ok then return notify(type(data) == 'string' and data or 'Arène indisponible.', 'error') end
    focus(true)
    ui({ action = 'open', data = data })
end

-- Rôle « Arène PvP » des PNJ de l'éditeur de map (admin_menu)
AddEventHandler('pvp_arena:client:open', function() A.Open() end)
RegisterNetEvent('pvp_arena:client:openNet', function() A.Open() end)

RegisterNUICallback('close', function(_, cb)
    cb(1)
    focus(false)
    if not A.inArena then Ely.callback('pvp_arena:close', false, nil) end
end)

-- Demandes vers le serveur (liste fermée : rien d'autre ne peut être appelé depuis l'interface)
local ALLOWED = { create = true, join = true, leave = true, team = true, ready = true, shuffle = true, configure = true,
    stake = true, bet = true, unbet = true, watch = true, launch = true, pick = true, quit = true, open = true }
RegisterNUICallback('call', function(d, cb)
    local name = type(d) == 'table' and d.name
    if not ALLOWED[name] then return cb({ ok = false, err = 'Action inconnue.' }) end
    local args = type(d.args) == 'table' and d.args or {}
    CreateThread(function()
        local res = table.pack(Ely.callback.await('pvp_arena:' .. name, false, table.unpack(args, 1, 4)))
        cb({ ok = res[1] == true, err = res[1] ~= true and res[2] or nil, data = res[1] == true and res[2] or nil })
    end)
end)

RegisterNetEvent('pvp_arena:list', function(list) ui({ action = 'list', list = list }) end)
RegisterNetEvent('pvp_arena:lobby', function(view) ui({ action = 'lobby', lobby = view }) end)
RegisterNetEvent('pvp_arena:closed', function(uid) ui({ action = 'closed', uid = uid }) end)
RegisterNetEvent('pvp_arena:betResult', function(r) ui({ action = 'betResult', result = r }) end)

-- ---------------------------------------------------------------- armes prêtées (arène seulement)
local allWeapons = {}
for _, c in ipairs(Config.WeaponCategories) do for _, w in ipairs(c.weapons) do allWeapons[#allWeapons + 1] = GetHashKey(w.name) end end

local function stripArenaWeapons()
    local ped = PlayerPedId()
    for _, h in ipairs(allWeapons) do SetPedInfiniteAmmo(ped, false, h) end
    SetPedInfiniteAmmoClip(ped, false)
    RemoveAllPedWeapons(ped, true)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
end

local function giveWeapon(name, ammo)
    local ped = PlayerPedId()
    stripArenaWeapons()
    local h = GetHashKey(name)
    GiveWeaponToPed(ped, h, ammo or 250, false, true)
    SetPedInfiniteAmmo(ped, true, h)     -- munitions de réserve illimitées : le chargeur se recharge normalement
    SetCurrentPedWeapon(ped, h, true)
    A.weapon = h
end

-- ---------------------------------------------------------------- utilitaires du personnage
local function fade(out)
    if out then DoScreenFadeOut(300) else DoScreenFadeIn(400) end
    local t = GetGameTimer() + 1500
    while (out and not IsScreenFadedOut() or (not out and not IsScreenFadedIn())) and GetGameTimer() < t do Wait(10) end
end

local function placeAt(p, h)
    local ped = PlayerPedId()
    if A.WallReset then A.WallReset(nil) end   -- le mur repart de la nouvelle position
    RequestCollisionAtCoord(p.x, p.y, p.z)
    SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    if h then SetEntityHeading(ped, h + 0.0) end
    local t = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(10) end
end

local function resurrect(p, h)
    local ped = PlayerPedId()
    local c = p or GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, h or GetEntityHeading(ped), true, false)
    ped = PlayerPedId()
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    return ped
end

local function setGhost(on)
    local ped = PlayerPedId()
    SetEntityVisible(ped, not on, false)
    SetEntityCollision(ped, not on, not on)
    SetEntityInvincible(ped, on)
    FreezeEntityPosition(ped, on)
    if NetworkSetEntityInvisibleToNetwork then NetworkSetEntityInvisibleToNetwork(ped, on) end
    SetEntityAlpha(ped, on and 0 or 255, false)
    if not on then ResetEntityAlpha(ped) end
end

local function stopSpectate()
    if A.cam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(A.cam, false)
        A.cam = nil
    end
end

-- ---------------------------------------------------------------- entrée dans l'arène
RegisterNetEvent('pvp_arena:enter', function(d)
    A.inArena, A.team, A.arena, A.ff = true, d.team, d.arena, d.ff == true
    A.eliminated, A.deathSent, A.phase = false, false, 'PREPARATION'
    -- l'arme d'inventaire éventuellement en main est rangée (l'inventaire RP n'est jamais touché)
    pcall(function() exports.elyzea_inventory:closeInventory() end)
    pcall(function() exports.elyzea_inventory:disarm() end)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) end
    focus(false)
    ui({ action = 'enter', data = d })
end)

-- Choix de l'arme (écran avec décompte)
RegisterNetEvent('pvp_arena:weaponSelect', function(d)
    if not A.inArena then return end
    A.phase = 'WEAPON_SELECTION'
    stopSpectate()
    focus(true)
    ui({ action = 'weapons', data = d })
end)

RegisterNUICallback('pickClosed', function(_, cb) cb(1) if A.inArena then focus(false) end end)

-- Placement sur le point d'apparition, arme prêtée, vie et gilet ; immobile jusqu'au début de la manche
RegisterNetEvent('pvp_arena:spawn', function(d)
    if not A.inArena then return end
    A.phase = 'COUNTDOWN'
    focus(false)
    ui({ action = 'hideWeapons' })
    fade(true)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or A.eliminated then ped = resurrect(d.pos, d.pos.h) end
    stopSpectate()
    setGhost(false)
    A.eliminated, A.deathSent = false, false
    placeAt(d.pos, d.pos.h)
    ped = PlayerPedId()
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, math.min(200, d.health or 200))
    SetPedArmour(ped, d.armor or 0)
    ClearPedBloodDamage(ped)
    giveWeapon(d.weapon, d.ammo)
    SetCanAttackFriendly(ped, A.ff, false)
    A.frozen = true
    FreezeEntityPosition(ped, true)
    fade(false)
end)

RegisterNetEvent('pvp_arena:countdown', function(d)
    if not A.inArena then return end
    ui({ action = 'countdown', seconds = d.seconds, round = d.round })
    PlaySoundFrontend(-1, '3_2_1', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('pvp_arena:roundStart', function(d)
    if not A.inArena then return end
    A.phase = 'IN_ROUND'
    A.frozen = false
    FreezeEntityPosition(PlayerPedId(), false)
    ui({ action = 'roundStart', seconds = d.seconds, round = d.round })
    PlaySoundFrontend(-1, 'GO', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('pvp_arena:roundEnd', function(d)
    if not A.inArena then return end
    A.phase = 'ROUND_END'
    ui({ action = 'roundEnd', data = d, myTeam = A.team })
    PlaySoundFrontend(-1, d.winner == A.team and 'Mission_Pass_Notify' or 'LOSER', d.winner == A.team and 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS' or 'HUD_AWARDS', true)
end)

RegisterNetEvent('pvp_arena:hud', function(h)
    if not A.inArena then return end
    A.aliveList = {}
    for _, r in ipairs(h.roster or {}) do if r.alive and r.team == A.team then A.aliveList[#A.aliveList + 1] = r.id end end
    ui({ action = 'hud', hud = h, myTeam = A.team, me = GetPlayerServerId(PlayerId()) })
end)

RegisterNetEvent('pvp_arena:killfeed', function(k) if A.inArena and Config.UI.showKillFeed then ui({ action = 'killfeed', kill = k }) end end)

-- Éliminé : réanimé sur place, invisible, sans arme ni collision ; regarde ses coéquipiers
RegisterNetEvent('pvp_arena:eliminated', function(d)
    if not A.inArena then return end
    A.eliminated = true
    CreateThread(function()
        Wait(1200)
        local ped = PlayerPedId()
        if IsEntityDead(ped) then resurrect() end
        stripArenaWeapons()
        setGhost(true)
        ui({ action = 'eliminated' })
        A.spectateIdx = 1
        if d and d.spectate then A.Spectate() end
    end)
end)

function A.Spectate()
    if not A.eliminated or not A.inArena then return end
    local list = A.aliveList
    if #list == 0 then return stopSpectate() end
    if A.spectateIdx > #list then A.spectateIdx = 1 end
    local target = GetPlayerFromServerId(list[A.spectateIdx])
    local tped = target ~= -1 and GetPlayerPed(target) or 0
    if tped == 0 then return end
    if not A.cam then A.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true) end
    AttachCamToEntity(A.cam, tped, 0.0, -3.2, 1.2, true)
    PointCamAtEntity(A.cam, tped, 0.0, 0.0, 0.6, true)
    SetCamActive(A.cam, true)
    RenderScriptCams(true, true, 300, true, true)
    ui({ action = 'spectating', id = list[A.spectateIdx] })
end

RegisterNetEvent('pvp_arena:zoneBack', function(p)
    if not A.inArena then return end
    placeAt(p, p.h)
    ui({ action = 'zoneWarn' })
end)

RegisterNetEvent('pvp_arena:matchEnd', function(s)
    if not A.inArena then return end
    A.phase = 'MATCH_END'
    A.frozen = true
    FreezeEntityPosition(PlayerPedId(), true)
    stopSpectate()
    stripArenaWeapons()
    ui({ action = 'matchEnd', summary = s, myTeam = A.team })
end)

-- ---------------------------------------------------------------- retour au RP
local function cleanState()
    if A.WallReset then A.WallReset(nil) end
    stopSpectate()
    stripArenaWeapons()
    setGhost(false)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetCanAttackFriendly(ped, true, false)
    A.inArena, A.phase, A.team, A.weapon, A.frozen, A.eliminated, A.arena = false, nil, nil, nil, false, false, nil
    ClearOverrideWeather()
    NetworkClearClockTimeOverride()
end

RegisterNetEvent('pvp_arena:exit', function(d)
    CreateThread(function()
        local was = A.inArena
        fade(true)
        local ped = PlayerPedId()
        if IsEntityDead(ped) then ped = resurrect(d, d.h) end
        cleanState()
        placeAt(d, d.h)
        ped = PlayerPedId()
        if d.health and d.health > 100 then SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), d.health)) end
        SetPedArmour(ped, d.armor or 0)
        focus(false)
        ui({ action = 'exit' })
        fade(false)
        if was and not d.quiet then notify('Retour au RP.', 'inform') end
    end)
end)

RegisterNetEvent('pvp_arena:forceClean', function()
    cleanState()
    focus(false)
    ui({ action = 'exit' })
end)

-- ---------------------------------------------------------------- mur de la zone
-- Chaque image : si le joueur est dans la zone, sa position est retenue ; s'il en sort (course, saut,
-- roulade, explosion, chute sous le sol), il est remis à la dernière position valide, sans élan.
-- Le serveur garde son propre contrôle derrière (triche).
local lastIn, lastWarn = nil, 0
function A.Wall(ped)
    local z = A.arena.zone
    local c = GetEntityCoords(ped)
    if Rules.InZone(z, c.x, c.y, c.z) then
        lastIn = c
    elseif lastIn and not A.frozen then
        SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        SetEntityCoordsNoOffset(ped, lastIn.x, lastIn.y, lastIn.z, false, false, false)
        if GetGameTimer() - lastWarn > 2500 then
            lastWarn = GetGameTimer()
            ui({ action = 'zoneWarn' })
            PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
    end
    -- mur visible seulement à proximité (quelques murs, pas tout le contour)
    local pts = z.points
    local show = Config.Zone.wallShowDistance or 6.0
    if Rules.EdgeDistance(pts, c.x, c.y) > show then return end
    local col = Config.Zone.wallColor or { 34, 211, 238 }
    local z0 = z.minZ or (c.z - 3.0)
    local z1 = z.maxZ and math.min(z.maxZ, c.z + 6.0) or (c.z + 6.0)
    z0 = math.max(z0, c.z - 4.0)
    for i = 1, #pts do
        local p, q = pts[i], pts[i % #pts + 1]
        -- seulement les murs proches
        if Rules.EdgeDistance({ p, q }, c.x, c.y) <= show then
            DrawPoly(p.x, p.y, z0, q.x, q.y, z0, q.x, q.y, z1, col[1], col[2], col[3], 45)
            DrawPoly(p.x, p.y, z0, q.x, q.y, z1, p.x, p.y, z1, col[1], col[2], col[3], 45)
            DrawPoly(q.x, q.y, z0, p.x, p.y, z0, q.x, q.y, z1, col[1], col[2], col[3], 45)
            DrawPoly(q.x, q.y, z1, p.x, p.y, z0, p.x, p.y, z1, col[1], col[2], col[3], 45)
            DrawLine(p.x, p.y, z0, q.x, q.y, z0, col[1], col[2], col[3], 220)
            DrawLine(p.x, p.y, z1, q.x, q.y, z1, col[1], col[2], col[3], 220)
        end
    end
end
function A.WallReset(p) lastIn = p and vector3(p.x, p.y, p.z) or nil end

-- ---------------------------------------------------------------- boucle de l'arène (seulement en partie)
CreateThread(function()
    local lastClock = 0
    while true do
        if A.inArena then
            local ped = PlayerPedId()
            -- pas de roue des armes, pas d'inventaire, pas de changement d'arme
            HideHudComponentThisFrame(19)
            HideHudComponentThisFrame(20)
            DisableControlAction(0, 37, true)
            for _, c in ipairs({ 157, 158, 160, 164, 165, 159, 161, 162, 163 }) do DisableControlAction(0, c, true) end
            if A.frozen or A.phase ~= 'IN_ROUND' or A.eliminated then
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
                DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
            end
            -- l'arme prêtée reste en main (aucun script de synchronisation ne la retire)
            if A.weapon and not A.eliminated and A.phase ~= 'MATCH_END' and GetSelectedPedWeapon(ped) ~= A.weapon and HasPedGotWeapon(ped, A.weapon, false) then
                SetCurrentPedWeapon(ped, A.weapon, true)
            end
            -- mort pendant la manche : signalée au serveur (qui vérifie et désigne le tueur)
            if A.phase == 'IN_ROUND' and not A.eliminated and not A.deathSent and (IsEntityDead(ped) or IsPedFatallyInjured(ped)) then
                A.deathSent = true
                local killerPed = GetPedSourceOfDeath(ped)
                local killer = nil
                if killerPed ~= 0 and IsPedAPlayer(killerPed) then
                    local pl = NetworkGetPlayerIndexFromPed(killerPed)
                    if pl ~= -1 then killer = GetPlayerServerId(pl) end
                end
                TriggerServerEvent('pvp_arena:died', killer)
            elseif A.phase ~= 'IN_ROUND' and IsEntityDead(ped) and not A.eliminated then
                resurrect()   -- chute ou accident hors manche : pas de mort RP
            end
            -- mur de la zone : impossible d'en sortir (bord, sol et plafond) ; visible près du bord
            if Config.Zone.wall and not A.eliminated and A.arena and A.arena.zone and #(A.arena.zone.points or {}) >= 3 then
                A.Wall(ped)
            end
            -- spectateur : flèches gauche / droite pour changer de coéquipier
            if A.eliminated and A.cam then
                if IsControlJustPressed(0, 174) then A.spectateIdx = A.spectateIdx - 1 if A.spectateIdx < 1 then A.spectateIdx = #A.aliveList end A.Spectate() end
                if IsControlJustPressed(0, 175) then A.spectateIdx = A.spectateIdx + 1 A.Spectate() end
            end
            if A.arena and A.arena.time and GetGameTimer() - lastClock > 2000 then
                lastClock = GetGameTimer()
                NetworkOverrideClockTime(math.floor(A.arena.time), 0, 0)
                if A.arena.weather then SetWeatherTypeNowPersist(A.arena.weather) end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Arrêt de la ressource : aucune arme, munition illimitée ou état d'arène ne reste
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if A.inArena then cleanState() end
    SetNuiFocus(false, false)
end)

-- ---------------------------------------------------------------- visualisation d'une arène (admin)
RegisterNetEvent('pvp_arena:showArena', function(a, seconds)
    local untilT = GetGameTimer() + (seconds or 60) * 1000
    CreateThread(function()
        while GetGameTimer() < untilT do
            local pts = a.zone.points or {}
            local z0 = a.zone.minZ or (GetEntityCoords(PlayerPedId()).z - 2.0)
            local z1 = a.zone.maxZ or (z0 + 10.0)
            for i = 1, #pts do
                local p, q = pts[i], pts[i % #pts + 1]
                DrawLine(p.x, p.y, z0, q.x, q.y, z0, 34, 211, 238, 255)
                DrawLine(p.x, p.y, z1, q.x, q.y, z1, 34, 211, 238, 255)
                DrawLine(p.x, p.y, z0, p.x, p.y, z1, 34, 211, 238, 180)
                DrawPoly(p.x, p.y, z0, q.x, q.y, z0, q.x, q.y, z1, 34, 211, 238, 30)
                DrawPoly(p.x, p.y, z0, q.x, q.y, z1, p.x, p.y, z1, 34, 211, 238, 30)
            end
            for t, col in pairs({ A = { 34, 211, 238 }, B = { 249, 115, 98 } }) do
                for i, s in ipairs(a.spawns[t] or {}) do
                    DrawMarker(1, s.x, s.y, s.z - 1.0, 0, 0, 0, 0, 0, 0, 0.9, 0.9, 1.5, col[1], col[2], col[3], 150, false, false, 2, false, nil, nil, false)
                    DrawMarker(2, s.x + math.sin(math.rad(-(s.h or 0))) * 0.8, s.y + math.cos(math.rad(-(s.h or 0))) * 0.8, s.z, 0, 0, 0, 90.0, 0, -(s.h or 0), 0.4, 0.4, 0.4,
                        col[1], col[2], col[3], 200, false, false, 2, false, nil, nil, false)
                end
            end
            for _, s in ipairs(a.safe or {}) do
                DrawMarker(1, s.x, s.y, s.z - 1.0, 0, 0, 0, 0, 0, 0, 0.6, 0.6, 0.8, 120, 255, 120, 150, false, false, 2, false, nil, nil, false)
            end
            Wait(0)
        end
    end)
end)

-- ---------------------------------------------------------------- PNJ de secours (sans l'éditeur de map)
-- Un seul PNJ, local, recréé proprement : jamais de doublon après un redémarrage de la ressource.
if Config.Npc.enabled then
    local npc
    CreateThread(function()
        local n = Config.Npc
        local hash = GetHashKey(n.model)
        while true do
            local d = #(GetEntityCoords(PlayerPedId()) - n.coords.xyz)
            if d < 60.0 and not npc then
                RequestModel(hash)
                local t = GetGameTimer() + 5000
                while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(50) end
                if HasModelLoaded(hash) then
                    npc = CreatePed(4, hash, n.coords.x, n.coords.y, n.coords.z - 1.0, n.coords.w, false, true)
                    SetEntityInvincible(npc, true)
                    FreezeEntityPosition(npc, true)
                    SetBlockingOfNonTemporaryEvents(npc, true)
                    SetPedFleeAttributes(npc, 0, false)
                    SetPedCanRagdoll(npc, false)
                    if n.scenario then TaskStartScenarioInPlace(npc, n.scenario, 0, true) end
                    SetModelAsNoLongerNeeded(hash)
                end
            elseif d > 80.0 and npc then
                DeleteEntity(npc) npc = nil
            end
            if npc and d < n.distance and not A.inArena and not A.open then
                pcall(function() exports.elyzea_core:ShowTextUI('[E] ' .. n.label) end)
                if IsControlJustPressed(0, Config.InteractKey) then A.Open() end
                Wait(0)
            else
                if npc and d < n.distance + 2.0 then pcall(function() exports.elyzea_core:HideTextUI() end) end
                Wait(d < 10.0 and 200 or 1000)
            end
        end
    end)
    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() and npc and DoesEntityExist(npc) then DeleteEntity(npc) end
    end)
end
