-- =====================================================================
--  ADAPTATEUR POLICE (serveur) : effectifs en service
--  1. elyzea_police:GetOnDutyCount() / IsOnDuty(src) (service de la police)
--  2. repli : métiers de « police.jobs » avec job.onduty (elyzea_core)
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Police = A

local function policeRes() return GetResourceState('elyzea_police') == 'started' end

local function jobOnDuty(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    if not ok or type(pd) ~= 'table' or type(pd.job) ~= 'table' then return false end
    for _, j in ipairs(JHS.S.police.jobs or {}) do
        if pd.job.name == j and pd.job.onduty then return true end
    end
    return false
end

function A.IsOnDuty(src)
    if policeRes() then
        local ok, res = pcall(function() return exports.elyzea_police:IsOnDuty(src) end)
        if ok then return res == true end
    end
    return jobOnDuty(src)
end

-- Liste des policiers en service (sources)
function A.OnDuty()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if A.IsOnDuty(src) then out[#out + 1] = src end
    end
    return out
end

function A.Count()
    if policeRes() then
        local ok, n = pcall(function() return exports.elyzea_police:GetOnDutyCount() end)
        if ok and tonumber(n) then return tonumber(n) end
    end
    return #A.OnDuty()
end
