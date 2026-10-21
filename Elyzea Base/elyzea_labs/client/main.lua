-- =====================================================================
--  ELYZEA LABS · client : outils communs (appels serveur, interface, aide, cercles)
-- =====================================================================
LabC = { labs = {}, inside = nil, ui = nil, ents = {} }
local C = LabC
local core = exports.elyzea_core

function C.Notify(msg, kind)
    local ok = pcall(function() core:Notify(msg, kind or 'inform') end)
    if not ok then BeginTextCommandThefeedPost('STRING') AddTextComponentSubstringPlayerName(tostring(msg)) EndTextCommandThefeedPostTicker(false, false) end
end
RegisterNetEvent('elyzea_labs:notify', function(msg, kind) C.Notify(msg, kind) end)

function C.Pub(name, d)
    local ok, r = pcall(function() return Ely.callback.await('elyzea_labs:pub', false, name, d or {}) end)
    if not ok or type(r) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return r
end
-- Affiche le message d'un résultat
function C.Show(r)
    if r.error then C.Notify(r.error, 'error') elseif r.message then C.Notify(r.message, 'success') end
    return r
end

-- Interface (un seul panneau à la fois) : 'entrance' | 'editor' | 'craft' | 'tablet'
function C.Open(kind, data)
    C.ui = kind
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', kind = kind, data = data })
end
function C.Close()
    if not C.ui then return end
    C.ui = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end
function C.Update(kind, data) if C.ui == kind then SendNUIMessage({ action = 'update', kind = kind, data = data }) end end
RegisterNUICallback('close', function(_, cb) C.Close() cb({}) end)

function C.Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end
function C.Vec(p) return vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0) end
function C.Circle(p, color, r)
    r = r or 1.2
    DrawMarker(25, p.x + 0.0, p.y + 0.0, p.z - 0.97, 0, 0, 0, 0, 0, 0, r * 2.0, r * 2.0, 1.0, color[1], color[2], color[3], 170, false, false, 2, false, nil, nil, false)
end
function C.Label3D(p, text)
    SetDrawOrigin(p.x + 0.0, p.y + 0.0, p.z + 0.2, 0)
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true) SetTextOutline()
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

function C.LoadModel(model)
    local h = type(model) == 'number' and model or joaat(model or '')
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(h) and h or nil
end
-- Premier modèle présent dans le jeu pour un équipement
function C.EquipModel(typ)
    local e = Config.Equipment[typ]
    for _, m in ipairs(e and e.models or {}) do if IsModelInCdimage(joaat(m)) then return m end end
    return nil
end

function C.Fade(out)
    if out then DoScreenFadeOut(350) local t = GetGameTimer() + 1000 while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end
    else DoScreenFadeIn(450) end
end
function C.Teleport(p)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
    SetEntityCoords(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false, false)
    if p.h then SetEntityHeading(ped, p.h + 0.0) end
    local t = GetGameTimer() + 2500
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
end

-- Exports utilisés par elyzea_illegal (F5) et d'autres ressources
exports('IsInsideLab', function() return C.inside ~= nil end)
exports('OpenLabTablet', function() if C.inside and C.OpenTablet then C.OpenTablet() return true end return false end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('elyzea_labs:hello')
end)
