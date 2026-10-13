-- =====================================================================
--  ADAPTATEUR PERMISSIONS / JOUEURS (serveur)
--  Staff : admin_menu:HasPermission(src, 'bankheist_manage'). Repli : ACE « bank_heist.admin ».
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Perms = A
A.PERM = 'bankheist_manage'

function A.IsAdmin(src)
    if GetResourceState('admin_menu') == 'started' then
        local ok, res = pcall(function() return exports.admin_menu:HasPermission(src, A.PERM) end)
        if ok then return res == true end
    end
    return IsPlayerAceAllowed(src, 'bank_heist.admin')
end
function A.CitizenId(src) local ok, v = pcall(function() return exports.elyzea_core:GetCitizenId(src) end) return ok and v or nil end
function A.Name(src) local ok, v = pcall(function() return exports.elyzea_core:GetCharName(src) end) return ok and v or GetPlayerName(src) or ('ID ' .. tostring(src)) end
function A.Job(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    return ok and type(pd) == 'table' and type(pd.job) == 'table' and pd.job.name or nil
end
