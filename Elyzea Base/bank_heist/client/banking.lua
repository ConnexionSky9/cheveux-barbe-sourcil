-- =====================================================================
--  BANK HEIST - client : guichet du banquier (ALT sur le banquier, hors braquage)
--  Toutes les opérations sont faites et vérifiées par le serveur ; l'interface ne fait qu'afficher.
-- =====================================================================
local C = BHC
local openBank = nil

function C.OpenBank(bankId)
    if C.ui then return end
    local r = C.Req('bankOpen', { bank = bankId })
    if not C.Show(r) then return end
    openBank = bankId
    local ped = C.PedEntityOf(bankId)
    if ped and DoesEntityExist(ped) then TaskTurnPedToFaceEntity(PlayerPedId(), ped, 600) end
    C.Sfx('open')
    C.OpenUI('bank', r)
end

-- Opérations depuis l'interface : la banque ouverte est ajoutée ici (jamais choisie par l'interface)
RegisterNUICallback('bank', function(body, cb)
    local action = ({ deposit = 'bankDeposit', withdraw = 'bankWithdraw', transfer = 'bankTransfer', refresh = 'bankOpen' })[body and body.op or '']
    if not action or not openBank then return cb({ error = 'Guichet fermé.' }) end
    local data = type(body.data) == 'table' and body.data or {}
    data.bank = openBank
    local r = C.Req(action, data)
    if r.ok and action ~= 'bankOpen' then C.Sfx('cash', 0.6) end
    cb(r)
end)

-- Fermé automatiquement si le joueur s'éloigne du guichet
CreateThread(function()
    while true do
        local sleep = 1000
        if openBank and C.ui == 'bank' then
            sleep = 300
            local def = C.BankDef(openBank)
            if not def or C.Dist(def.banker) > 5.0 or C.Bank(openBank).phase == 'active' then C.CloseUI() end
        elseif openBank and C.ui ~= 'bank' then openBank = nil end
        Wait(sleep)
    end
end)
