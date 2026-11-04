-- =====================================================================
--  ELYZEA MANUTENTION - OUTILS STAFF (client)
--  · Affichage en jeu de tous les emplacements configurés (marqueurs, numéros, orientation, rayon)
--  · Lecture de la tenue portée par l'admin pour en faire la tenue de travail
--  Tout est déclenché par le serveur, qui vérifie la permission avant.
-- =====================================================================
local shown = nil

local COLORS = {
    npc = { 255, 181, 71, 'PNJ' }, pickups = { 155, 92, 255, 'Cartons' }, pallets = { 62, 230, 176, 'Palette' },
    spawns = { 64, 160, 255, 'Fenwick' }, deliveries = { 255, 77, 109, 'Livraison' },
}

local function text3d(x, y, z, txt)
    local on, sx, sy = World3dToScreen2d(x, y, z)
    if not on then return end
    SetTextScale(0.32, 0.32) SetTextFont(4) SetTextCentre(true) SetTextOutline()
    SetTextColour(255, 255, 255, 230)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(txt) EndTextCommandDisplayText(sx, sy)
end

local function drawPoint(kind, i, p)
    local c = COLORS[kind]
    local r = (kind == 'deliveries') and ((p.radius or Config.DeliveryRadius) * 2.0) or 1.0
    DrawMarker(1, p.x, p.y, p.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r, r, 0.4, c[1], c[2], c[3], 110, false, false, 2, false, nil, nil, false)
    -- flèche d'orientation (cap enregistré)
    local h = math.rad(p.h or 0.0)
    local fx, fy = p.x - math.sin(h) * 1.2, p.y + math.cos(h) * 1.2
    DrawLine(p.x, p.y, p.z - 0.5, fx, fy, p.z - 0.5, c[1], c[2], c[3], 255)
    DrawMarker(2, fx, fy, p.z - 0.5, 0.0, 0.0, 0.0, 90.0, (p.h or 0.0), 0.0, 0.3, 0.3, 0.3, c[1], c[2], c[3], 220, false, false, 2, false, nil, nil, false)
    text3d(p.x, p.y, p.z + 0.4, ('%s%s%s'):format(c[4], i and (' n°' .. i) or '', p.label and (' · ' .. p.label) or ''))
end

RegisterNetEvent('elyzea_manutention:adminShow', function(data)
    shown = type(data) == 'table' and data or nil
    if not shown then return end
    CreateThread(function()
        while shown do
            local me = GetEntityCoords(PlayerPedId())
            local near = false
            for _, kind in ipairs({ 'pickups', 'pallets', 'spawns', 'deliveries' }) do
                for i, p in ipairs(shown[kind] or {}) do
                    if #(me - vector3(p.x, p.y, p.z)) < 120.0 then near = true drawPoint(kind, i, p) end
                end
            end
            if shown.npc and shown.npc.placed and #(me - vector3(shown.npc.x, shown.npc.y, shown.npc.z)) < 120.0 then
                near = true drawPoint('npc', nil, shown.npc)
            end
            Wait(near and 0 or 500)
        end
    end)
end)

RegisterNetEvent('elyzea_manutention:captureOutfit', function(gender)
    local o, sex = SnapshotOutfit()
    TriggerServerEvent('elyzea_manutention:capturedOutfit', gender, o, sex)
end)
