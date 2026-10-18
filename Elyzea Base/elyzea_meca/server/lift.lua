-- =====================================================================
--  ELYZEA MÉCANO - serveur : objet « Pont roulant »
--  · Utilisé (inventaire) par un mécanicien en service sur un point d'atelier :
--    le pont est installé sur ce point (gardé en base, visible par tous) et l'objet consommé.
--  · Aux points équipés, les interventions montent le véhicule sur le pont et le mécanicien
--    travaille debout sous la voiture ; ailleurs, chandelles et chariot.
--  · /meca_pont_retirer (permission « garage_manage ») : le pont revient dans l'inventaire.
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

local function Install(src)
    if not P.IsMeca(src) then P.Notify(src, 'Seul un mécanicien peut installer un pont roulant.', 'error') return false end
    if not P.OnDuty(src) then P.Notify(src, 'Prenez votre service (F6) pour installer le pont.', 'error') return false end
    if not P.Can(src, LC.perm or 'workshop') then P.Notify(src, 'Votre grade ne permet pas d\'installer un pont roulant.', 'error') return false end
    local list = P.WorkshopList()
    local here = PointHere(src)
    if not here then P.Notify(src, 'Placez-vous sur un point d\'atelier (cercle au sol) pour installer le pont.', 'error') return false end
    for _, w in ipairs(list) do
        if w.id == here.id then
            if w.lift then P.Notify(src, ('« %s » a déjà un pont roulant.'):format(w.label), 'error') return false end
            for _, l in pairs(P.wsBusy or {}) do if l and P.quotes[l.uid] and P.quotes[l.uid].workshop == w.id then
                P.Notify(src, 'Une intervention est en cours sur ce point.', 'error') return false end end
            local ped = GetPlayerPed(src)
            local veh = GetVehiclePedIsIn(ped, false)
            w.lift = { h = math.floor(GetEntityHeading(veh ~= 0 and veh or ped) * 10) / 10, by = P.Name(src), at = os.time() }
            P.SetSetting('workshops', list)
            P.PublishWorkshops()
            P.AddLog(src, nil, nil, 'Pont roulant installé', nil, w.label, nil)
            P.Notify(src, ('Pont roulant installé sur « %s ».'):format(w.label), 'success')
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

-- Retirer le pont du point où l'on se trouve (rendu dans l'inventaire)
P.Actions.liftRemove = { perm = 'garage_manage', fn = function(src)
    local here = PointHere(src)
    if not here then return { error = 'Placez-vous sur le point d\'atelier équipé du pont.' } end
    local list = P.WorkshopList()
    for _, w in ipairs(list) do
        if w.id == here.id then
            if not w.lift then return { error = 'Ce point n\'a pas de pont roulant.' } end
            for _, l in pairs(P.wsBusy or {}) do if l and P.quotes[l.uid] and P.quotes[l.uid].workshop == w.id then
                return { error = 'Une intervention est en cours sur ce point.' } end end
            if not P.GiveLiftItem(src) then return { error = 'Pas assez de place dans votre inventaire.' } end
            w.lift = nil
            P.SetSetting('workshops', list)
            P.PublishWorkshops()
            P.AddLog(src, nil, nil, 'Pont roulant retiré', nil, w.label, nil)
            return { ok = true, message = ('Pont roulant retiré de « %s » (dans votre inventaire).'):format(w.label) }
        end
    end
    return { error = 'Point introuvable.' }
end }
