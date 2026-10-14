--[[
    NOIR X — Pont administration : admin_menu
    Même vérification que elyzea_illegal (server/players.lua → Players.isStaff) :
        exports.admin_menu:HasPermission(src, 'noirx_staff')
    La permission 'noirx_staff' s'ajoute dans admin_menu/config.lua (Config.Permissions)
    puis se donne aux grades staff dans l'onglet Grades du menu.

    Repli tant que admin_menu n'est pas démarré : ACE Config.Admin.ace ('noirx.admin').
    La console serveur (src 0) est toujours autorisée.
]]

Admin = {}

function Admin.IsStaff(src)
    src = tonumber(src)
    if not src then return false end
    if src == 0 then return true end
    local res = Config.Admin.resource
    if res and GetResourceState(res) == 'started' then
        local ok, allowed = pcall(function() return exports[res]:HasPermission(src, Config.Admin.permission) end)
        if ok and allowed == true then return true end
    end
    return IsPlayerAceAllowed(src, Config.Admin.ace)
end
