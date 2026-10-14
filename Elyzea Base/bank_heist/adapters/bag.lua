-- =====================================================================
--  ADAPTATEUR SAC (serveur) : système de sac de jewelry_heist (un seul système de sac sur le serveur)
--  CreateCarriedBag(src, opts) -> id · GetCarriedBag(src) -> { id, kind, money, capacity }
--  AddBagMoney(src, id, montant) -> ajouté · CashOutCarriedBag(src, 'bank') -> montant, id
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Bag = A
local RES = 'jewelry_heist'

function A.Ready() return GetResourceState(RES) == 'started' end
local function call(fn, ...)
    if not A.Ready() then return nil end
    local args = { ... }
    local ok, a, b = pcall(function() return exports[RES][fn](exports[RES], table.unpack(args)) end)
    if not ok then
        if tostring(a):find('No such export', 1, true) then
            if not A.warned then
                A.warned = true
                print('^1[BANK] jewelry_heist n\'est PAS à jour : il lui manque les exports du sac de billets (' .. fn .. ').^0')
                print('^1[BANK] Remplace le dossier jewelry_heist par la version livrée avec bank_heist, puis : refresh, restart jewelry_heist, restart bank_heist.^0')
            end
        else
            print(('^1[BANK] Sac (%s) : %s^0'):format(fn, tostring(a)))
        end
        return nil
    end
    return a, b
end
function A.Carried(src) return call('GetCarriedBag', src) end
function A.Create(src, capacity, ref) return call('CreateCarriedBag', src, { kind = 'bank', capacity = capacity, ref = ref }) end
function A.AddMoney(src, id, amount) return tonumber((call('AddBagMoney', src, id, amount))) or 0 end
function A.CashOut(src) local a, id = call('CashOutCarriedBag', src, 'bank') return tonumber(a) or 0, id end
