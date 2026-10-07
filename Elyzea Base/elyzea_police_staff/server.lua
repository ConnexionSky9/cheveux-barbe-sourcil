-- =====================================================================
--  elyzea_police_staff - serveur
--  L'accès est décidé par admin_menu (permission « police_staff » ou
--  accès individuel, refusé en mode RP). Les données et la logique sont
--  dans elyzea_police.
-- =====================================================================
local function Notify(src, msg, kind)
    TriggerClientEvent('police_staff:client:notify', src, msg, kind or 'inform')
end

local function CanUse(src)
    if not src or src == 0 then return false, 'none' end
    if GetResourceState(Config.AdminMenu) == 'started' then
        local ok, allowed, why = pcall(function() return exports[Config.AdminMenu]:CanUsePoliceStaff(src) end)
        if ok then return allowed == true, why end
    end
    if Config.FallbackAce ~= '' and IsPlayerAceAllowed(src, Config.FallbackAce) then return true end
    return false, 'none'
end

local Deny = {
    rp = 'Tu es en mode RP : reprends ton service staff pour ouvrir la tablette Police.',
    none = "Tu n'as pas accès à la tablette staff Police.",
}

local function PoliceReady()
    if GetResourceState(Config.PoliceResource) ~= 'started' then return false end
    return true
end

local function AdminMenuReady() return GetResourceState(Config.AdminMenu) == 'started' end

local function Data()
    local ok, data = pcall(function() return exports[Config.PoliceResource]:StaffGetData() end)
    if not ok or not data then return nil end
    -- Tenues de service (gérées par admin_menu, communes à tous les métiers)
    data.uniformsAvailable = AdminMenuReady()
    data.uniforms = {}
    if data.uniformsAvailable then
        for _, j in ipairs(data.policeJobs or {}) do
            local okU, sum = pcall(function() return exports[Config.AdminMenu]:GetUniformSummary(j.name) end)
            data.uniforms[j.name] = okU and sum or {}
        end
    end
    return data
end

-- Actions des tenues : traitées ici, enregistrées par admin_menu
local function IsPoliceJob(job)
    local ok, list = pcall(function() return exports[Config.PoliceResource]:GetPoliceJobs() end)
    for _, j in ipairs(ok and list or {}) do if j == job then return true end end
    return false
end

local UniformActions = {
    uniformSave = function(src, d)
        return exports[Config.AdminMenu]:SaveUniform(src, d.job, d.grade, d.gender, d.outfit)
    end,
    uniformDelete = function(src, d)
        return exports[Config.AdminMenu]:DeleteUniform(src, d.job, d.grade, d.gender)
    end,
    uniformReset = function(src, d)
        return exports[Config.AdminMenu]:ResetUniforms(src, d.job)
    end,
}

RegisterCommand(Config.Command, function(src)
    if src == 0 then return end
    local ok, why = CanUse(src)
    if not ok then return Notify(src, Deny[why] or Deny.none, 'error') end
    if not PoliceReady() then return Notify(src, ('La ressource « %s » n\'est pas démarrée.'):format(Config.PoliceResource), 'error') end
    local data = Data()
    if not data then return Notify(src, 'La ressource Police ne répond pas.', 'error') end
    TriggerClientEvent('police_staff:client:open', src, data)
end, false)

RegisterNetEvent('police_staff:server:action', function(action, payload)
    local src = source
    local ok, why = CanUse(src)
    if not ok then
        Notify(src, Deny[why] or Deny.none, 'error')
        return TriggerClientEvent('police_staff:client:forceClose', src)
    end
    if not PoliceReady() then return Notify(src, 'La ressource Police n\'est pas démarrée.', 'error') end
    payload = type(payload) == 'table' and payload or {}
    local okCall, success, msg
    if UniformActions[action] then
        if not AdminMenuReady() then return Notify(src, 'Les tenues nécessitent admin_menu.', 'error') end
        if not IsPoliceJob(tostring(payload.job or '')) then return Notify(src, 'Ce métier n\'est pas un métier police.', 'error') end
        okCall, success, msg = pcall(UniformActions[action], src, payload)
    else
        okCall, success, msg = pcall(function()
            return exports[Config.PoliceResource]:StaffAction(src, tostring(action), payload)
        end)
    end
    if not okCall then
        Notify(src, 'La ressource Police ne répond pas.', 'error')
    elseif msg and msg ~= '' then
        Notify(src, msg, success and 'success' or 'error')
    end
    local data = Data()
    if data then TriggerClientEvent('police_staff:client:data', src, data) end
end)
