-- =====================================================================
--  BANK HEIST - client : décryptage de la porte (scène + mini-jeu) et pose de la C4
--  Le mini-jeu est choisi et vérifié par le serveur. Fermer l'interface, s'éloigner, tomber ou
--  être déplacé compte comme un échec (la tentative était déjà consommée au lancement).
-- =====================================================================
local C = BHC
local hack = nil   -- { bank, scene }

function C.OnHackClosed(done)
    if not hack then return end
    local h = hack
    hack = nil
    if not done then C.Req('hackAbort') end
    C.Scenes.HackEnd(h.scene)
    if not done then C.Notify('Décryptage abandonné : la tentative est perdue.', 'error') end
end

function C.StartHack(bankId)
    if hack or C.ui then return end
    local def = C.BankDef(bankId)
    if not def then return end
    local r = C.Req('hackStart', { bank = bankId })
    if not C.Show(r) then return end
    hack = { bank = bankId }
    hack.scene = C.Scenes.HackBegin(def.doorPoint)
    if not hack then return end   -- interrompu pendant l'entrée
    C.OpenUI('hack', r)
end

RegisterNetEvent('bh:client:hackEnd', function()
    if not hack then return end
    local h = hack
    hack = nil
    C.CloseUI()
    C.Scenes.HackEnd(h.scene)
    C.Notify('Temps écoulé : décryptage échoué.', 'error')
end)

-- Interruption : trop loin, à terre, projeté, en véhicule
CreateThread(function()
    while true do
        local sleep = 800
        if hack then
            sleep = 200
            local ped = PlayerPedId()
            local def = C.BankDef(hack.bank)
            if not def or IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) or LocalPlayer.state.emsDown or C.Dist(def.doorPoint) > 3.5 then
                C.CloseUI()
                C.OnHackClosed(false)
            end
        end
        Wait(sleep)
    end
end)

-- Porte ouverte : effet pour les braqueurs (bandeau, son)
RegisterNetEvent('bh:client:doorOpen', function(d)
    C.Banner('COFFRE OUVERT', (d and d.how == 'C4') and 'La porte a sauté : servez-vous, vite !' or 'Décryptage réussi : la porte s\'ouvre', 'success')
    C.Sfx('unlock')
end)

-- ---------------------------------------------------------------------
-- Charge C4 : vérification, pose (scène), puis consommation par le serveur
-- ---------------------------------------------------------------------
local planting = false
function C.PlantC4(bankId)
    if planting then return end
    local chk = C.Req('c4Check', { bank = bankId })
    if not C.Show(chk) then return end
    planting = true
    local cfg = C.Cfg()
    local def = C.BankDef(bankId)
    local ped = PlayerPedId()
    local ok = C.Scenes.PlantC4(def.doorPoint, cfg.c4.prop, cfg.c4.plantTime, function()
        return IsEntityDead(ped) or IsPedRagdoll(ped) or C.Dist(def.doorPoint) > 3.0
    end)
    if not ok then C.Notify('Pose interrompue : la charge n\'a pas été utilisée.', 'error')
    else
        local r = C.Req('c4Plant', { bank = bankId })
        if C.Show(r) then
            C.Banner('CHARGE ARMÉE', ('Mettez-vous à couvert : explosion dans %d s'):format(r.delay), 'danger')
            C.Sfx('arm')
        end
    end
    planting = false
end

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and hack then C.Scenes.HackEnd(hack.scene) end end)
