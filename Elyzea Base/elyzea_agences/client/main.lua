-- =====================================================================
--  ELYZEA AGENCES - client : panneau staff (carte, zones, agences)
--  Le serveur revérifie la permission à chaque action.
-- =====================================================================
local isOpen = false

local function Notify(msg, kind) pcall(function() exports.elyzea_core:Notify(msg, kind or 'inform') end) end

local function Req(action, data)
    local ok, res = pcall(function() return Ely.callback.await('agences:req', false, action, data or {}) end)
    if not ok or type(res) ~= 'table' then return { error = 'Le serveur ne répond pas.' } end
    return res
end

local function Close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function Open()
    local r = Req('data')
    if r.error then return Notify(r.error, 'error') end
    isOpen = true
    SetNuiFocus(true, true)
    local c = GetEntityCoords(PlayerPedId())
    SendNUIMessage({ action = 'open', data = r, me = { x = c.x, y = c.y } })
end

RegisterNetEvent('elyzea_agences:client:open', function()
    if isOpen then
        local r = Req('data')
        if not r.error then SendNUIMessage({ action = 'data', data = r }) end
        return
    end
    Open()
end)

RegisterNUICallback('req', function(body, cb) cb(Req(body.action, body.data)) end)
RegisterNUICallback('close', function(_, cb) cb({}) Close() end)

-- Dessin EN JEU avec l'outil de l'éditeur de map (admin_menu) : coins posés un par un
RegisterNUICallback('worldDraw', function(body, cb)
    cb({})
    if GetResourceState('admin_menu') ~= 'started' then return Notify('Le dessin en jeu demande admin_menu (outil de l\'éditeur de map).', 'error') end
    Close()
    Wait(150)
    TriggerEvent('adminmenu:client:drawAgencyZone', tonumber(body.id), tostring(body.name or 'Agence'))
end)

-- Point GPS sur la carte du jeu
RegisterNUICallback('gps', function(body, cb)
    cb({})
    local x, y = tonumber(body.x), tonumber(body.y)
    if x and y then SetNewWaypoint(x + 0.0, y + 0.0) Notify('Point GPS placé.', 'success') end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
