-- =====================================================================
--  JEWELRY HEIST - client : socle
--  Réglages publics : GlobalState.jhCfg (publiés par le serveur, mis à jour en direct).
--  Requêtes : Ely.callback 'jh:req' (le serveur revérifie tout).
-- =====================================================================
JHC = { ui = nil }
local C = JHC

function C.Cfg() return GlobalState.jhCfg end

function C.Req(action, data)
    local ok, res = pcall(function() return Ely.callback.await('jh:req', false, action, data or {}) end)
    if not ok or type(res) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return res
end

function C.Notify(text, kind)
    local ok = pcall(function() exports.elyzea_core:Notify(text, kind or 'inform', nil, 'Bijouterie') end)
    if not ok then
        BeginTextCommandThefeedPost('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandThefeedPostTicker(false, false)
    end
end
function C.Show(r)
    if r.error then C.Notify(r.error, 'error') return false end
    return true
end

-- Chargement d'animations / modèles avec délai maximal (jamais de blocage)
function C.LoadDict(dict, ms)
    if not dict or dict == '' or not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + (ms or 3000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end
function C.LoadModel(model, ms)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + (ms or 5000)
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

-- Joue une animation ; repli sur un scénario si elle ne charge pas. Retourne true si quelque chose est joué.
function C.PlayAnim(ped, a, fallback, duration)
    if a and C.LoadDict(a.dict) then
        TaskPlayAnim(ped, a.dict, a.name, 4.0, -4.0, duration or -1, a.flag or 0, 0.0, false, false, false)
        return true
    end
    if fallback and fallback ~= '' then TaskStartScenarioInPlace(ped, fallback, 0, true) return true end
    return false
end

function C.Text3D(x, y, z, text)
    SetDrawOrigin(x + 0.0, y + 0.0, z + 0.0, 0)
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true) SetTextOutline()
    SetTextColour(255, 255, 255, 235)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

function C.Help(text)
    BeginTextCommandDisplayHelp('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayHelp(0, false, false, -1)
end

-- ---------------------------------------------------------------------
-- Interface (NUI)
-- ---------------------------------------------------------------------
function C.OpenUI(name, data)
    C.ui = name
    SetNuiFocus(true, true)
    local cfg = C.Cfg() or {}
    SendNUIMessage({ action = 'open', panel = name, data = data, imagePath = cfg.imagePath })
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
    if was == 'bag' and body and body.bag then C.Req('bagClose', { bag = body.bag }) end
end)
RegisterNUICallback('req', function(body, cb) cb(C.Req(body.action, body.data)) end)
RegisterNUICallback('notify', function(body, cb) cb({}) if body and body.text then C.Notify(body.text, body.kind) end end)

-- Barre de progression (sans focus)
function C.Progress(label, seconds, color)
    SendNUIMessage({ action = 'progress', show = label ~= nil, label = label, seconds = seconds, color = color })
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if C.ui then SetNuiFocus(false, false) end
end)

RegisterCommand('jh_debloquer', function() C.CloseUI() SetNuiFocus(false, false) end, false)
