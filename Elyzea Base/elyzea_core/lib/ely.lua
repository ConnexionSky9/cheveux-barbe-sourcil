--[[
    ELYZEA CORE — bibliothèque partagée pour les ressources Elyzea.
    Dans le fxmanifest :  shared_script '@elyzea_core/lib/ely.lua'

    Client :
      Ely.notify({ title, description, type, duration })   Ely.showTextUI(texte)   Ely.hideTextUI()
      Ely.progressBar({ duration, label, canCancel, disable, anim, prop }) -> true / false
      Ely.requestModel(modèle, délai)   Ely.requestAnimDict(dict, délai)
      Ely.getVehicleProperties(veh)     Ely.setVehicleProperties(veh, props)
      Ely.getClosestVehicle(coords, distance, inclureLeSien)
      Ely.addKeybind({ name, description, defaultKey, onPressed, onReleased })
      Ely.callback.await(nom, délai, ...)   Ely.callback(nom, délai, cb, ...)
      Ely.GetPlayerData()
    Serveur :
      Ely.callback.register(nom, function(source, ...) return ... end)
      Ely.GetPlayer(source)   Ely.notify(source, { ... })
]]

Ely = Ely or {}
local core = exports.elyzea_core
local RES = GetCurrentResourceName()
local IS_SERVER = IsDuplicityVersion()

-- ─────────── Rappels client <-> serveur ───────────
Ely.callback = setmetatable({}, {
    __call = function(self, name, delay, cb, ...)
        local args = table.pack(...)
        CreateThread(function()
            local res = table.pack(self.await(name, delay, table.unpack(args, 1, args.n)))
            if cb then cb(table.unpack(res, 1, res.n)) end
        end)
    end,
})

if IS_SERVER then
    function Ely.callback.register(name, fn)
        RegisterNetEvent(('__elycb:%s'):format(name), function(resource, id, ...)
            local src = source
            local res = table.pack(pcall(fn, src, ...))
            if not res[1] then
                print(('^1[%s] rappel %s : %s^0'):format(RES, name, tostring(res[2])))
                TriggerClientEvent(('__elycb_r:%s'):format(resource), src, id)
                return
            end
            TriggerClientEvent(('__elycb_r:%s'):format(resource), src, id, table.unpack(res, 2, res.n))
        end)
    end
else
    local pending, seq = {}, 0
    RegisterNetEvent(('__elycb_r:%s'):format(RES), function(id, ...)
        local p = pending[id]
        if not p then return end
        pending[id] = nil
        p:resolve(table.pack(...))
    end)

    function Ely.callback.await(name, delay, ...)
        seq = seq + 1
        local id = seq
        local p = promise.new()
        pending[id] = p
        TriggerServerEvent(('__elycb:%s'):format(name), RES, id, ...)
        SetTimeout(30000, function()
            if pending[id] then pending[id] = nil p:resolve(table.pack()) end
        end)
        local res = Citizen.Await(p)
        return table.unpack(res, 1, res.n)
    end
end

-- ─────────── Joueur ───────────
if IS_SERVER then
    function Ely.GetPlayer(src) return core:GetPlayer(src) end
    function Ely.notify(src, data) core:Notify(src, data) end
else
    function Ely.GetPlayerData() return core:GetPlayerData() or {} end
    function Ely.notify(data) core:Notify(data) end
    function Ely.showTextUI(text) core:ShowTextUI(text) end
    function Ely.hideTextUI() core:HideTextUI() end
    function Ely.isTextUIOpen() return core:IsTextUIOpen() end
    function Ely.progressBar(data) return core:ProgressBar(data) end
    function Ely.getVehicleProperties(veh) return core:GetVehicleProperties(veh) end
    function Ely.setVehicleProperties(veh, props, fix) return core:SetVehicleProperties(veh, props, fix) end
    function Ely.getClosestVehicle(coords, dist, includeOwn) return core:GetClosestVehicle(coords, dist, includeOwn) end

    function Ely.requestModel(model, timeout)
        model = type(model) == 'string' and joaat(model) or model
        if HasModelLoaded(model) then return model end
        if not IsModelInCdimage(model) then error(('modèle introuvable : %s'):format(tostring(model)), 2) end
        RequestModel(model)
        local t = GetGameTimer() + (timeout or 10000)
        while not HasModelLoaded(model) do
            if GetGameTimer() > t then error(('chargement du modèle %s trop long'):format(tostring(model)), 2) end
            Wait(0)
        end
        return model
    end

    function Ely.requestAnimDict(dict, timeout)
        if HasAnimDictLoaded(dict) then return dict end
        if not DoesAnimDictExist(dict) then error(('animation introuvable : %s'):format(tostring(dict)), 2) end
        RequestAnimDict(dict)
        local t = GetGameTimer() + (timeout or 10000)
        while not HasAnimDictLoaded(dict) do
            if GetGameTimer() > t then error(('chargement de l\'animation %s trop long'):format(dict), 2) end
            Wait(0)
        end
        return dict
    end

    -- Touche configurable (Paramètres FiveM › Assignation des touches)
    function Ely.addKeybind(d)
        local name = d.name
        RegisterCommand('+' .. name, function() if d.onPressed then d.onPressed(d) end end, false)
        RegisterCommand('-' .. name, function() if d.onReleased then d.onReleased(d) end end, false)
        RegisterKeyMapping('+' .. name, d.description or name, d.defaultMapper or 'keyboard', d.defaultKey or '')
        return d
    end
end
