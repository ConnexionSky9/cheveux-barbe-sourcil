-- =====================================================================
--  ADAPTATEUR POLICE (serveur)
--  elyzea_police : GetOnDutyCount(), IsOnDuty(src), SendAlert(type, coords, titre, description, rue, opts)
--  Repli (elyzea_police arrêté) : métiers « police.jobs » en service (elyzea_core) + notification.
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Police = A
local function res() return GetResourceState('elyzea_police') == 'started' end

local function jobOnDuty(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    if not ok or type(pd) ~= 'table' or type(pd.job) ~= 'table' then return false end
    for _, j in ipairs(BHS.S.police.jobs or {}) do if pd.job.name == j and pd.job.onduty then return true end end
    return false
end

function A.IsOnDuty(src)
    if res() then
        local ok, r = pcall(function() return exports.elyzea_police:IsOnDuty(src) end)
        if ok then return r == true end
    end
    return jobOnDuty(src)
end

function A.Count()
    if res() then
        local ok, n = pcall(function() return exports.elyzea_police:GetOnDutyCount() end)
        if ok and tonumber(n) then return tonumber(n) end
    end
    local n = 0
    for _, s in ipairs(GetPlayers()) do if A.IsOnDuty(tonumber(s)) then n = n + 1 end end
    return n
end

-- Alerte envoyée UNE fois au lancement. Retourne le canal utilisé.
function A.Alert(coords, title, desc)
    if res() then
        local ok, id = pcall(function() return exports.elyzea_police:SendAlert(BHS.S.police.alertKind or 'robbery', coords, title, desc, nil, {}) end)
        if ok and id then return 'elyzea_police' end
    end
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if A.IsOnDuty(src) then TriggerClientEvent('bh:client:policeAlert', src, { coords = coords, title = title, desc = desc }) end
    end
    return 'interne'
end
