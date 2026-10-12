-- =====================================================================
--  ELYZEA MÉCANO - serveur : réparer, nettoyer, retourner (ALT)
--  En deux temps : « repStart » vérifie (grade, service, distance, pièces) ;
--  le client joue l'animation ; « repFinish » n'est accepté qu'après la durée
--  minimale, puis le serveur retire les pièces et demande au client du
--  mécanicien d'appliquer la réparation (il prend le contrôle réseau du véhicule).
--  Les réparations ne facturent rien d'elles-mêmes : F6 › Créer un devis.
-- =====================================================================
local P = Meca
local R = Config.Repair
local PERM = { engine = 'repair', body = 'repair', tyres = 'repair', full = 'repair_full', clean = 'clean', flip = 'flip' }
local pending = {}   -- [src] = { kind, net, t }

local function Vehicle(src, net)
    local veh = NetworkGetEntityFromNetworkId(tonumber(net) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil, 'Véhicule introuvable.' end
    local c = P.Coords(src)
    if not c or #(GetEntityCoords(veh) - c) > Config.Distances.vehicle + 1.5 then return nil, 'Approchez-vous du véhicule.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return nil, 'Descendez du véhicule.' end
    return veh
end

P.Actions.repStart = { perm = 'duty', duty = true, fn = function(src, d)
    local kind = tostring(d.kind or '')
    local cfg = R[kind]
    if not cfg or not PERM[kind] then return { error = 'Action inconnue.' } end
    if not P.Can(src, PERM[kind]) then return { error = 'Votre grade ne permet pas cette action.' } end
    local veh, why = Vehicle(src, d.net)
    if not veh then return { error = why } end
    pending[src] = { kind = kind, net = tonumber(d.net), t = GetGameTimer() }
    return { ok = true, duration = cfg.duration, label = cfg.label }
end }

P.Actions.repCancel = { perm = 'duty', fn = function(src) pending[src] = nil return { ok = true } end }

P.Actions.repFinish = { perm = 'duty', duty = true, fn = function(src, d)
    local pd = pending[src]
    pending[src] = nil
    if not pd or pd.kind ~= d.kind or pd.net ~= tonumber(d.net) then return { error = 'Action interrompue.' } end
    local cfg = R[pd.kind]
    if GetGameTimer() - pd.t < cfg.duration - 1500 then return { error = 'Action interrompue trop tôt.' } end
    local veh, why = Vehicle(src, pd.net)
    if not veh then return { error = why } end
    local plate = P.CleanPlate(GetVehicleNumberPlateText(veh))
    TriggerClientEvent('meca:client:repairApply', src, pd.net, pd.kind)
    local row = P.VehicleRow(plate)
    P.History(row and row.id, plate, cfg.label, nil, nil, src)
    -- Réparations : l'état réparé est aussi gardé sur la carte grise (sinon le garage le remettrait)
    if row and (pd.kind == 'engine' or pd.kind == 'full') then P.SaveMods(row.id, { engineHealth = 1000.0, tankHealth = 1000.0 }) end
    if row and (pd.kind == 'body' or pd.kind == 'full') then P.SaveMods(row.id, { bodyHealth = 1000.0, _deform = {}, windows = {}, doors = {} }) end
    if row and (pd.kind == 'tyres' or pd.kind == 'full') then P.SaveMods(row.id, { tyres = {} }) end
    if row and pd.kind == 'clean' then P.SaveMods(row.id, { dirtLevel = 0.0 }) end
    P.Log(src, cfg.label, plate)
    local billable = ({ engine = 'repair_engine', body = 'repair_body', tyres = 'repair_tyres', full = 'repair_full', clean = 'clean', flip = 'flip' })[pd.kind]
    return { ok = true, message = ('%s : terminé. Pensez au devis (F6 › Créer un devis).'):format(cfg.label), billable = billable, plate = plate }
end }

AddEventHandler('playerDropped', function() pending[source] = nil end)
