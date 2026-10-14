-- =====================================================================
--  PC Police — serveur
--  · Liste des PC : props de l'éditeur d'admin_menu ayant le rôle « police_pc »
--    (exports.admin_menu:GetPropsByRole), publiée dans GlobalState.policePCs.
--    Mise à jour à chaque modification des props dans l'éditeur (événement adminmenu:propsChanged).
--  · Accès : vérifié ICI (policier en service, grade minimum, PC existant, joueur à côté).
-- =====================================================================
local PCs = {}

local function refresh()
    if GetResourceState('admin_menu') ~= 'started' then return end
    local ok, list = pcall(function() return exports.admin_menu:GetPropsByRole('police_pc') end)
    if not ok or type(list) ~= 'table' then return end
    PCs = {}
    local pub = {}
    for _, p in ipairs(list) do
        PCs[tostring(p.id)] = p
        pub[#pub + 1] = { id = p.id, x = p.x, y = p.y, z = p.z }
    end
    GlobalState.policePCs = pub
end

AddEventHandler('adminmenu:propsChanged', function() SetTimeout(200, refresh) end)
AddEventHandler('onResourceStart', function(res) if res == 'admin_menu' then SetTimeout(3000, refresh) end end)
CreateThread(function() Wait(2000) refresh() end)

local function police(src)
    if GetResourceState('elyzea_police') ~= 'started' then return false end
    if Config.RequireDuty then
        local ok, duty = pcall(function() return exports.elyzea_police:IsOnDuty(src) end)
        if not ok or duty ~= true then return false end
    else
        local ok, cop = pcall(function() return exports.elyzea_police:IsPolice(src) end)
        if not ok or cop ~= true then return false end
    end
    if (Config.MinimumGrade or 0) > 0 then
        local ok, lvl = pcall(function() return exports.elyzea_police:GetGradeLevel(src) end)
        if not ok or (tonumber(lvl) or 0) < Config.MinimumGrade then return false end
    end
    return true
end

local function allowed(src) return police(src) or (Config.StaffAce ~= '' and IsPlayerAceAllowed(src, Config.StaffAce)) end

local function nearPC(src, id)
    local p = PCs[tostring(id or '')]
    if not p then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)) <= Config.InteractDistance + 1.5
end

-- Session ouverte par joueur (le terminal ne répond qu'à celui qui l'a ouvert, devant le PC)
local Open = {}

Ely.callback.register('npl:open', function(src, id)
    if not PCs[tostring(id or '')] then return { error = 'PC non enregistré dans l\'éditeur.' } end
    if not nearPC(src, id) then return { error = 'Trop loin du PC.' } end
    if not allowed(src) then return { error = 'Accès réservé aux policiers en service.' } end
    Open[src] = tostring(id)
    return { ok = true, features = Config.Features, name = GetPlayerName(src) }
end)

local function session(src) return Open[src] and nearPC(src, Open[src]) and allowed(src) end

Ely.callback.register('npl:units', function(src)
    if not session(src) or not Config.Features.units then return { error = 'Accès refusé.' } end
    local ok, list = pcall(function() return exports.elyzea_police:GetOnDutyUnits() end)
    return ok and { ok = true, units = list or {} } or { error = 'elyzea_police ne répond pas.' }
end)

Ely.callback.register('npl:reports', function(src)
    if not session(src) or not Config.Features.reports then return { error = 'Accès refusé.' } end
    local ok, list = pcall(function() return exports.elyzea_police:ListReports(src) end)
    return ok and { ok = true, reports = list or {} } or { error = 'elyzea_police ne répond pas.' }
end)

RegisterNetEvent('npl:close', function() Open[source] = nil end)
AddEventHandler('playerDropped', function() Open[source] = nil end)
