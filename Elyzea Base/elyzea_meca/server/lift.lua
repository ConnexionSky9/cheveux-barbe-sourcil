-- =====================================================================
--  ELYZEA MÉCANO - serveur : objet « Pont roulant »
--  · Utilisé (inventaire) par un mécanicien en service à côté d'un véhicule garé sur un point
--    d'atelier : le pont est posé sous ce véhicule (gardé en base, visible par tous), l'objet consommé.
--  · Aux points équipés, les interventions montent le véhicule sur le pont et le mécanicien
--    travaille debout sous la voiture ; ailleurs, chandelles et chariot.
--  · Touche H à côté du pont (ou /meca_pont_retirer) : n'importe quel mécanicien en service le
--    reprend, il revient dans son inventaire (refusé pendant une intervention).
-- =====================================================================
local P = Meca
local LC = (Config.Interventions or {}).liftItem or {}
local ITEM = LC.name or 'pont_roulant'

local function inv() return exports.elyzea_inventory end

function P.GiveLiftItem(src)
    local ok, res = pcall(function() return inv():AddItem(src, ITEM, 1) end)
    return ok and res ~= false
end

-- Point d'atelier sur lequel se tient le joueur (ou son véhicule)
local function PointHere(src)
    local c = P.Coords(src)
    if not c then return nil end
    local best, bestD
    for _, w in ipairs(P.WorkshopList()) do
        if w.coords then
            local d = #(c - vector3(w.coords.x + 0.0, w.coords.y + 0.0, w.coords.z + 0.0))
            if d <= (tonumber(w.radius) or 3.5) + (LC.range or 3.0) and (not bestD or d < bestD) then best, bestD = w, d end
        end
    end
    return best
end

-- Véhicule le plus proche du joueur (à pied, à côté)
local function NearVehicle(src, radius)
    local c = P.Coords(src)
    if not c then return nil end
    local best, bestD
    for _, v in ipairs(GetAllVehicles()) do
        local d = #(GetEntityCoords(v) - c)
        if d <= radius and (not bestD or d < bestD) then best, bestD = v, d end
    end
    return best
end

-- Point d'atelier sur lequel un véhicule est garé
local function PointOfVehicle(veh)
    local vc = GetEntityCoords(veh)
    for _, w in ipairs(P.WorkshopList()) do
        if w.coords and #(vc - vector3(w.coords.x + 0.0, w.coords.y + 0.0, w.coords.z + 0.0)) <= (tonumber(w.radius) or 3.5) + 1.0 then return w end
    end
end

local function Busy(wsId)
    for _, l in pairs(P.wsBusy or {}) do if l and P.quotes[l.uid] and P.quotes[l.uid].workshop == wsId then return true end end
    return false
end

-- Pose du pont SOUS un véhicule garé sur un point d'atelier (l'objet est consommé)
local function Install(src)
    if not P.IsMeca(src) then P.Notify(src, 'Seul un mécanicien peut poser un pont roulant.', 'error') return false end
    if not P.OnDuty(src) then P.Notify(src, 'Prenez votre service (F6) pour poser le pont.', 'error') return false end
    if not P.Can(src, LC.perm or 'workshop') then P.Notify(src, 'Votre grade ne permet pas de poser un pont roulant.', 'error') return false end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then P.Notify(src, 'Descendez du véhicule pour poser le pont.', 'error') return false end
    local veh = NearVehicle(src, LC.vehicleRange or 5.0)
    if not veh then P.Notify(src, 'Approchez-vous du véhicule sous lequel poser le pont.', 'error') return false end
    local here = PointOfVehicle(veh)
    if not here then P.Notify(src, 'Garez d\'abord le véhicule sur un point d\'atelier (cercle au sol).', 'error') return false end
    local list = P.WorkshopList()
    for _, w in ipairs(list) do
        if w.id == here.id then
            if w.lift then P.Notify(src, 'Il y a déjà un pont roulant sous ce véhicule.', 'error') return false end
            if Busy(w.id) then P.Notify(src, 'Une intervention est en cours sur ce point.', 'error') return false end
            w.lift = { h = math.floor(GetEntityHeading(veh) * 10) / 10, by = P.Name(src), at = os.time() }
            P.SetSetting('workshops', list)
            P.PublishWorkshops()
            P.AddLog(src, nil, nil, 'Pont roulant posé', nil, w.label, nil)
            TriggerClientEvent('meca:client:liftAnim', src)
            P.Notify(src, 'Pont roulant posé sous le véhicule. H à côté du pont pour le reprendre.', 'success')
            return true   -- l'objet est consommé
        end
    end
    return false
end

CreateThread(function()
    local t = GetGameTimer() + 30000
    while GetResourceState('elyzea_inventory') ~= 'started' and GetGameTimer() < t do Wait(500) end
    local ok, err = pcall(function() inv():RegisterUsableItem(ITEM, function(src) return Install(src) end) end)
    if not ok then print(('^1[MECA] Objet « %s » non utilisable : %s^0'):format(ITEM, tostring(err))) end
end)

-- Reprendre le pont (touche H à côté, ou /meca_pont_retirer) : il revient dans l'inventaire
P.Actions.liftRemove = { perm = LC.perm or 'workshop', duty = true, fn = function(src)
    local here = PointHere(src)
    if not here then return { error = 'Approchez-vous du pont roulant.' } end
    local list = P.WorkshopList()
    for _, w in ipairs(list) do
        if w.id == here.id then
            if not w.lift then return { error = 'Il n\'y a pas de pont roulant ici.' } end
            if Busy(w.id) then return { error = 'Une intervention est en cours : attendez qu\'elle soit terminée.' } end
            if not P.GiveLiftItem(src) then return { error = 'Pas assez de place dans votre inventaire.' } end
            w.lift = nil
            P.SetSetting('workshops', list)
            P.PublishWorkshops()
            P.AddLog(src, nil, nil, 'Pont roulant repris', nil, w.label, nil)
            return { ok = true, message = 'Pont roulant repris : il est dans votre inventaire.' }
        end
    end
    return { error = 'Pont introuvable.' }
end }
