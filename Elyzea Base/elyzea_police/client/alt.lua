-- =====================================================================
--  elyzea_police - client : actions du menu ALT commun (elyzea_jobs)
--  Seules les actions possibles (métier, service, accès, distance, état de la cible) sont proposées.
--  Le serveur revérifie tout.
-- =====================================================================
local C = PoliceC

local function HandsUp(ped)
    return IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3) or IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3)
end

local function Options(ctx)
    if not C.cfg or C.cuffed or not C.OnDuty() then return {} end
    local out = {}
    if ctx.kind == 'player' and ctx.serverId then
        local st = Player(ctx.serverId).state
        local cuffed = st.cuffed == true
        local ped = ctx.entity
        local inVeh = IsPedInAnyVehicle(ped, false)
        if C.Can('cuff') then
            out[#out + 1] = { id = 'cuff', label = cuffed and 'Démenotter' or 'Menotter', group = 'Police', order = 10 }
            if cuffed and not inVeh then
                out[#out + 1] = { id = 'escort', label = 'Escorter / arrêter l\'escorte', group = 'Police', order = 11 }
                out[#out + 1] = { id = 'inVehicle', label = 'Mettre dans le véhicule', desc = 'Véhicule le plus proche', group = 'Police', order = 12 }
            end
            out[#out + 1] = { id = 'id', label = 'Vérifier l\'identité', desc = 'Ouvre son dossier dans la tablette', group = 'Police', order = 14 }
        end
        if C.Can('search') and C.cfg.hasInventory then
            local ok = cuffed or HandsUp(ped) or not C.cfg.settings.searchNeedsCuff
            out[#out + 1] = { id = 'search', label = 'Fouiller', desc = ok and nil or 'Menotté ou mains en l\'air', disabled = not ok, group = 'Police', order = 15 }
        end
        if C.Can('fines') then out[#out + 1] = { id = 'fine', label = 'Mettre une amende…', group = 'Police', order = 20 } end
        if C.Can('jail') then out[#out + 1] = { id = 'jail', label = 'Envoyer en prison…', group = 'Police', order = 21 } end
        if C.Can('ppa_revoke') then out[#out + 1] = { id = 'ppaRevoke', label = 'Retirer le PPA', desc = 'Permis de port d\'arme', group = 'Police', order = 30 } end
    elseif ctx.kind == 'vehicle' then
        if C.Can('cuff') then
            local any = false
            for seat = -1, GetVehicleMaxNumberOfPassengers(ctx.entity) - 1 do
                local ped = GetPedInVehicleSeat(ctx.entity, seat)
                if ped ~= 0 and IsPedAPlayer(ped) and Player(GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))).state.cuffed then any = true end
            end
            if any then out[#out + 1] = { id = 'outVehicle', label = 'Sortir les personnes menottées', group = 'Police', order = 10 } end
        end
    end
    return out
end

local function Select(id, ctx)
    if id == 'fine' then return C.OpenActions(ctx.serverId, 'fine') end
    if id == 'jail' then return C.OpenActions(ctx.serverId, 'jail') end
    if id == 'outVehicle' then return C.Interact('outVehicle', nil, ctx.entity) end
    C.Interact(id, ctx.serverId)
end

local function Register()
    if GetResourceState('elyzea_jobs') ~= 'started' then return end
    exports.elyzea_jobs:AltRegister('police', Options, Select)
end

CreateThread(function() Wait(1000) Register() end)
AddEventHandler('onClientResourceStart', function(res) if res == 'elyzea_jobs' then Wait(500) Register() end end)
