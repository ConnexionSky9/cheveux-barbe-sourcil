-- =====================================================================
--  BANK HEIST - client : piratage (ordinateur en main + interface) et charge C4
--  Le mini-jeu est choisi et vérifié par le serveur. Fermer l'interface, s'éloigner, tomber ou
--  être déplacé compte comme un échec (la tentative était déjà consommée au lancement).
-- =====================================================================
local C = BHC
local hack = nil   -- { bank, prop }

local function stopAnim()
    if hack and hack.prop then C.DeleteProp(hack.prop) end
    ClearPedTasks(PlayerPedId())
end

function C.OnHackClosed(done)
    if not hack then return end
    local h = hack
    hack = nil
    stopAnim()
    if not done then C.Req('hackAbort') end
    if h then C.Notify(done and 'Fin du piratage.' or 'Piratage abandonné : la tentative est perdue.', done and 'inform' or 'error') end
end

function C.StartHack(bankId)
    if hack or C.ui then return end
    local r = C.Req('hackStart', { bank = bankId })
    if not C.Show(r) then return end
    local cfg = C.Cfg()
    hack = { bank = bankId }
    local ped = PlayerPedId()
    -- l'ordinateur sort : animation + objet tenu (secours : aucun objet si le modèle manque)
    C.PlayAnim(ped, cfg.hack.anim)
    hack.prop = C.HoldProp(cfg.hack.prop, 60309, vector3(0.025, -0.05, 0.08), vector3(-50.0, 290.0, 0.0))
    Wait(900)
    C.OpenUI('hack', r)
end

RegisterNetEvent('bh:client:hackEnd', function()
    if not hack then return end
    hack = nil
    stopAnim()
    C.CloseUI()
    C.Notify('Temps écoulé : piratage échoué.', 'error')
end)

-- Interruption : trop loin, à terre, projeté, en véhicule
CreateThread(function()
    while true do
        local sleep = 800
        if hack then
            sleep = 200
            local ped = PlayerPedId()
            local def = C.BankDef(hack.bank)
            if not def or IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) or LocalPlayer.state.emsDown or C.Dist(def.vault) > 3.5 then
                C.CloseUI()
                C.OnHackClosed(false)
            end
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------------
-- Charge C4 : vérification, pose (animation), puis consommation par le serveur
-- ---------------------------------------------------------------------
local planting = false
function C.PlantC4(bankId)
    if planting then return end
    local chk = C.Req('c4Check', { bank = bankId })
    if not C.Show(chk) then return end
    planting = true
    local cfg = C.Cfg()
    local ped = PlayerPedId()
    local def = C.BankDef(bankId)
    if def then SetEntityHeading(ped, (def.vault.h or GetEntityHeading(ped)) + 0.0) end
    C.PlayAnim(ped, cfg.c4.anim)
    local prop = C.HoldProp(cfg.c4.prop, 28422, vector3(0.0, 0.0, 0.0), vector3(0.0, 0.0, 0.0))
    local t = GetGameTimer() + cfg.c4.plantTime * 1000
    local cancelled = false
    while GetGameTimer() < t do
        DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
        if IsEntityDead(ped) or IsPedRagdoll(ped) or (def and C.Dist(def.vault) > 3.0) then cancelled = true break end
        Wait(0)
    end
    C.DeleteProp(prop)
    ClearPedTasks(ped)
    if cancelled then C.Notify('Pose interrompue : la charge n\'a pas été utilisée.', 'error')
    else
        local r = C.Req('c4Plant', { bank = bankId })
        if C.Show(r) then C.Notify(('Charge posée : éloignez-vous ! Explosion dans %d s.'):format(r.delay), 'error') end
    end
    planting = false
end

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and hack then stopAnim() end end)
