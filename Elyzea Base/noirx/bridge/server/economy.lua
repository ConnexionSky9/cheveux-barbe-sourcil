--[[
    NOIR X — Pont économie (façade argent propre) + Wallet (argent sale/propre unifié)
      Economy.IsConfigured()
      Economy.GetMoney(src)                  → number|nil (nil = non relié)
      Economy.AddMoney(src, amount, reason)  → boolean
      Economy.RemoveMoney(src, amount, reason) → boolean

      Wallet.Get(src)                         → { dirty, clean } (nil pour une source non reliée)
      Wallet.Charge(src, currency, amount, reason) → boolean   currency = 'dirty' | 'clean'
      Wallet.Credit(src, currency, amount, reason) → boolean
]]

Economy = {}
Wallet = {}

local warned = false
local function provider() return Config.Economy.provider end

local function validAmount(n)
    return type(n) == 'number' and n == n and n > 0 and n < 1e12 and math.floor(n) == n
end

local function call(fnName, ...)
    if not (EconomyCustom and EconomyCustom.Implemented and EconomyCustom[fnName]) then
        if not warned then
            warned = true
            NoirX.Warn('Économie non reliée : voir bridge/server/custom_economy.lua. Les paiements en argent propre seront mis en attente.')
        end
        return false, nil
    end
    local ok, r = pcall(EconomyCustom[fnName], ...)
    if not ok then
        NoirX.Error(('EconomyCustom.%s a levé une erreur : %s'):format(fnName, tostring(r)))
        return false, nil
    end
    return true, r
end

function Economy.IsConfigured()
    if provider() == 'devtest' then return true end
    return EconomyCustom ~= nil and EconomyCustom.Implemented == true
end

function Economy.GetMoney(src)
    if provider() == 'devtest' then return DevStore.GetMoney(src) end
    local ok, r = call('GetMoney', src)
    if not ok or type(r) ~= 'number' or r ~= r then return nil end
    return math.max(0, math.floor(r))
end

function Economy.AddMoney(src, amount, reason)
    if not validAmount(amount) then return false end
    if provider() == 'devtest' then return DevStore.AddMoney(src, amount) end
    local ok, r = call('AddMoney', src, amount, reason)
    return ok and r == true
end

function Economy.RemoveMoney(src, amount, reason)
    if not validAmount(amount) then return false end
    if provider() == 'devtest' then return DevStore.RemoveMoney(src, amount) end
    local ok, r = call('RemoveMoney', src, amount, reason)
    return ok and r == true
end

-- ─── Wallet ─────────────────────────────────────────────────────

function Wallet.Get(src)
    return {
        dirty = Inventory.GetItemCount(src, Config.Money.dirtyItem),
        clean = Economy.GetMoney(src),
    }
end

function Wallet.Charge(src, currency, amount, reason)
    if currency == 'dirty' then
        return Inventory.RemoveItem(src, Config.Money.dirtyItem, amount, { reason = reason })
    elseif currency == 'clean' then
        return Economy.RemoveMoney(src, amount, reason)
    end
    return false
end

function Wallet.Credit(src, currency, amount, reason)
    if currency == 'dirty' then
        return Inventory.AddItem(src, Config.Money.dirtyItem, amount, { reason = reason })
    elseif currency == 'clean' then
        return Economy.AddMoney(src, amount, reason)
    end
    return false
end
