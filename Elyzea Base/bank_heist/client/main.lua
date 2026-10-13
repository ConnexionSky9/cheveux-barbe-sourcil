-- =====================================================================
--  BANK HEIST - client : socle (réglages publics, requêtes, interface, utilitaires)
-- =====================================================================
BHC = { ui = nil }
local C = BHC

function C.Cfg() return GlobalState.bhCfg end
function C.Bank(id) return (GlobalState.bhBanks or {})[id] or {} end
function C.BankDef(id) for _, b in ipairs((C.Cfg() or {}).banks or {}) do if b.id == id then return b end end end

function C.Req(action, data)
    local ok, res = pcall(function() return Ely.callback.await('bh:req', false, action, data or {}) end)
    if not ok or type(res) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return res
end
function C.Notify(text, kind)
    if not pcall(function() exports.elyzea_core:Notify(text, kind or 'inform', nil, 'Banque') end) then
        BeginTextCommandThefeedPost('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandThefeedPostTicker(false, false)
    end
end
function C.Show(r) if r.error then C.Notify(r.error, 'error') return false end if r.message then C.Notify(r.message, 'success') end return true end

function C.LoadDict(dict, ms)
    if not dict or dict == '' or not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + (ms or 3000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end
function C.LoadModel(m, ms)
    local hash = type(m) == 'number' and m or joaat(m)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + (ms or 5000)
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end
function C.PlayAnim(ped, a, duration)
    if a and C.LoadDict(a.dict) then TaskPlayAnim(ped, a.dict, a.name, 4.0, -4.0, duration or -1, a.flag or 0, 0.0, false, false, false) return true end
    return false
end
function C.Help(text) BeginTextCommandDisplayHelp('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayHelp(0, false, false, -1) end
function C.Vec(p) return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) end
function C.Dist(p) return #(GetEntityCoords(PlayerPedId()) - C.Vec(p)) end
function C.Armed() local w = GetSelectedPedWeapon(PlayerPedId()) return w ~= 0 and w ~= joaat('WEAPON_UNARMED') end

-- Objet tenu en main (ordinateur, C4)
function C.HoldProp(model, bone, off, rot)
    local hash = C.LoadModel(model)
    if not hash then return nil end
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local obj = CreateObject(hash, p.x, p.y, p.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, bone), off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    return obj
end
function C.DeleteProp(obj) if obj and DoesEntityExist(obj) then DeleteEntity(obj) end end

-- Interface
function C.OpenUI(panel, data)
    C.ui = panel
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', panel = panel, data = data, imagePath = (C.Cfg() or {}).imagePath })
end
function C.CloseUI()
    if not C.ui then return end
    C.ui = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end
RegisterNUICallback('close', function(body, cb)
    cb({})
    local was = C.ui
    C.CloseUI()
    if was == 'hack' and C.OnHackClosed then C.OnHackClosed(type(body) == 'table' and body.done == true) end
end)
RegisterNUICallback('req', function(body, cb) cb(C.Req(body.action, body.data)) end)
RegisterNUICallback('notify', function(body, cb) cb({}) if body and body.text then C.Notify(body.text, body.kind) end end)

-- Alerte interne (si elyzea_police n'est pas démarré)
RegisterNetEvent('bh:client:policeAlert', function(a)
    if type(a) ~= 'table' or not a.coords then return end
    C.Notify(('%s\n%s'):format(a.title, a.desc or ''), 'error')
    local b = AddBlipForCoord(a.coords.x + 0.0, a.coords.y + 0.0, a.coords.z + 0.0)
    SetBlipSprite(b, 161) SetBlipColour(b, 1) SetBlipScale(b, 1.3) SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(a.title) EndTextCommandSetBlipName(b)
    SetNewWaypoint(a.coords.x + 0.0, a.coords.y + 0.0)
    SetTimeout(300000, function() if DoesBlipExist(b) then RemoveBlip(b) end end)
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and C.ui then SetNuiFocus(false, false) end end)
RegisterCommand('bh_debloquer', function() C.CloseUI() SetNuiFocus(false, false) end, false)
