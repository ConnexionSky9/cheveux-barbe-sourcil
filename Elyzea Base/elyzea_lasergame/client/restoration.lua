-- =====================================================================
--  ELYZEA LASERGAME - ENTRÉE / SORTIE DE PARTIE ET RESTAURATION RP (client)
--  Entrée : inventaire RP fermé, arme RP rangée, arène chargée, tenue LaserGame.
--  Sortie : armes LaserGame retirées, arène quittée, puis le serveur envoie l'état RP
--           sauvegardé (position, vie, gilet, vêtements) qui est appliqué ici, et le client
--           confirme : le serveur ne supprime la sauvegarde qu'après cette confirmation.
-- =====================================================================
local savedWanted

-- Entrée dans une partie (appelée par client/pvp.lua)
function C.EnterGame(d, onBuilt)
    C.CloseUI()
    C.inGame = true
    C.uid, C.mode, C.role, C.team = d.uid, d.mode, d.role, d.team
    C.alive, C.frozen = false, true
    C.game = d
    savedWanted = GetMaxWantedLevel()
    C.PrepareEnter()
    C.Fade(true, 400)
    C.UI('loading', { map = d.map and d.map.id, mapLabel = d.map and d.map.label, name = d.name, mode = d.mode, role = d.role })
    local ped = PlayerPedId()
    SetEntityInvincible(ped, true)
    -- position provisoire au centre de l'arène pendant le chargement (collisions et décor de l'éditeur de map)
    local a = (d.map and (d.map.center or (d.map.spawns and d.map.spawns[d.team or 'A'] and d.map.spawns[d.team or 'A'][1]))) or GetEntityCoords(ped)
    SetEntityCoordsNoOffset(ped, a.x + 0.0, a.y + 0.0, a.z + 1.0, false, false, false)
    FreezeEntityPosition(ped, true)
    Map.Build(d.map, function(k) C.UI('loadingProgress', k) end)
    if d.role == 'player' then C.ApplyOutfit(d.team) end
    C.StartGameLoop()
    if onBuilt then onBuilt() end
    C.UI('loadingDone')
end

-- Fin de partie côté client (le serveur envoie ensuite l'événement de restauration)
function C.LeaveGame()
    if not C.inGame then return end
    C.inGame = false
    C.alive, C.frozen = false, false
    if C.StopSpectate then C.StopSpectate() end
    Weapons.Strip()
    Laser.Clear()
    Map.Unload()
    C.ModeTick = nil
    C.CanFire = function() return false end
    C.ClearPrompt()
    C.UI('hud', false)
    C.UI('crosshair', false)
    local ped = PlayerPedId()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    SetPedMoveRateOverride(ped, 1.0)
    if savedWanted then SetMaxWantedLevel(savedWanted) savedWanted = nil end
    C.uid, C.mode, C.role, C.team, C.game = nil, nil, nil, nil, nil
end

RegisterNetEvent('elyzea_lasergame:leaveGame', function() C.LeaveGame() end)

-- Restauration de l'état RP (sortie normale, reconnexion, redémarrage, staff)
RegisterNetEvent('elyzea_lasergame:restore', function(s)
    if C.inGame then C.LeaveGame() end
    if type(s) ~= 'table' then return end
    if not IsScreenFadedOut() then C.Fade(true, 300) end
    local ped = C.Resurrect()
    C.SetGhost(false)
    FreezeEntityPosition(ped, false)
    RequestCollisionAtCoord(s.x, s.y, s.z)
    SetEntityCoordsNoOffset(ped, s.x + 0.0, s.y + 0.0, s.z + 0.0, false, false, false)
    SetEntityHeading(ped, (s.h or 0.0) + 0.0)
    local t = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
    ped = PlayerPedId()
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, math.max(101, math.min(200, tonumber(s.health) or 200)))
    SetPedArmour(ped, math.max(0, math.min(100, tonumber(s.armor) or 0)))
    C.ApplyLook(s.look)
    C.RestoreWeapons()
    SetEntityInvincible(ped, false)
    ClearPedTasksImmediately(ped)
    C.Fade(false, 500)
    TriggerServerEvent('elyzea_lasergame:restored')
    if not s.quiet then C.Notify('Retour au RP : ta position, ta tenue et ton équipement sont restaurés.', 'success') end
end)
