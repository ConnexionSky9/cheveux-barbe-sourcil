-- =====================================================================
--  ADAPTATEUR PERMISSIONS (serveur)
--  Staff : admin_menu:HasPermission(src, 'heist_manage') (permission ajoutée dans admin_menu).
--  Repli si admin_menu n'est pas démarré : ACE « jewelry_heist.admin ».
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Perms = A

A.PERM = 'heist_manage'

function A.IsAdmin(src)
    if GetResourceState('admin_menu') == 'started' then
        local ok, res = pcall(function() return exports.admin_menu:HasPermission(src, A.PERM) end)
        if ok then return res == true end
    end
    return IsPlayerAceAllowed(src, 'jewelry_heist.admin')
end

function A.CitizenId(src)
    local ok, cid = pcall(function() return exports.elyzea_core:GetCitizenId(src) end)
    return ok and cid or nil
end

function A.Name(src)
    local ok, n = pcall(function() return exports.elyzea_core:GetCharName(src) end)
    return ok and n or GetPlayerName(src) or ('ID ' .. tostring(src))
end

function A.SourceByCid(cid)
    if not cid then return nil end
    local ok, s = pcall(function() return exports.elyzea_core:GetSourceByCitizenId(cid) end)
    return ok and s or nil
end
