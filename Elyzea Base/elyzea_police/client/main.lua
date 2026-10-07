-- =====================================================================
--  elyzea_police - client : état commun
-- =====================================================================
PoliceC = {
    cfg = nil,          -- configuration publique envoyée par le serveur
    jailed = false,
    cuffed = false,
}
local C = PoliceC

function C.Notify(msg, kind)
    local ok = pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end)
    if not ok then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

function C.Job()
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData() end)
    return ok and pd and pd.job or nil
end

function C.IsCop()
    local job = C.Job()
    return job ~= nil and C.cfg ~= nil and C.cfg.policeJobs[job.name] == true
end

function C.OnDuty()
    local job = C.Job()
    return C.IsCop() and job.onduty == true
end

function C.Grade()
    local job = C.Job()
    return job and job.grade and job.grade.level or 0
end

-- Même règle que le serveur (le serveur revérifie toujours)
function C.Can(perm, allowOffDuty)
    if not C.IsCop() then return false end
    if not allowOffDuty and not C.OnDuty() then return false end
    local min = C.cfg.permGrades[perm]
    return min ~= nil and C.Grade() >= min
end

function C.Street(coords)
    local c = coords or GetEntityCoords(PlayerPedId())
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local name = GetStreetNameFromHashKey(s1)
    if s2 and s2 ~= 0 then name = name .. ' / ' .. GetStreetNameFromHashKey(s2) end
    return name
end

function C.ClosestPlayer(maxDist)
    local pc = GetEntityCoords(PlayerPedId())
    local best, bestDist
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(GetEntityCoords(GetPlayerPed(pid)) - pc)
            if d <= (maxDist or 3.0) and (not bestDist or d < bestDist) then best, bestDist = pid, d end
        end
    end
    return best, bestDist
end

function C.LoadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - t < 3000 do Wait(10) end
    return HasAnimDictLoaded(dict)
end

RegisterNetEvent('police:client:sync', function(cfg)
    C.cfg = cfg
    TriggerEvent('police:client:configChanged')
end)

RegisterNetEvent('police:client:notify', function(msg, kind) C.Notify(msg, kind) end)

RegisterNetEvent('police:client:teleport', function(c)
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    Wait(350)
    SetEntityCoords(ped, c.x + 0.0, c.y + 0.0, c.z + 0.0, false, false, false, false)
    Wait(300)
    DoScreenFadeIn(300)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('police:server:requestSync') end
end)

RegisterNetEvent('elyzea:client:playerLoaded', function()
    TriggerServerEvent('police:server:playerLoaded')
end)
