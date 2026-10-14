--[[
    ═══════════════════════════════════════════════════════════════════
     NOIR X — ADAPTATEUR ARGENT PROPRE : elyzea_core
    ═══════════════════════════════════════════════════════════════════
    Relié aux fonctions RÉELLES du joueur elyzea_core (server/players.lua) :
      exports.elyzea_core:GetPlayer(src) → { PlayerData = { money = { cash, bank, crypto } }, Functions = { … } }
      Functions.AddMoney(kind, amount, reason)    → true / false
      Functions.RemoveMoney(kind, amount, reason) → false si le compte passerait en négatif (cash, crypto)

    Compte utilisé : Config.Money.cleanAccount ('cash' par défaut, comme Config.CleanMoney d'elyzea_illegal ;
    'bank' pour verser l'argent blanchi sur le compte en banque).

    L'argent SALE n'est pas ici : c'est l'objet 'black_money' (custom_inventory.lua).
]]

local RES = 'elyzea_core'

EconomyCustom = {
    Implemented = true,
}

local function player(src)
    if GetResourceState(RES) ~= 'started' then return nil end
    local ok, p = pcall(function() return exports[RES]:GetPlayer(src) end)
    if ok and type(p) == 'table' and p.PlayerData then return p end
    return nil
end

local function account() return Config.Money.cleanAccount or 'cash' end

function EconomyCustom.GetMoney(src)
    local p = player(src)
    if not p then return nil end
    return tonumber(p.PlayerData.money and p.PlayerData.money[account()]) or 0
end

function EconomyCustom.AddMoney(src, amount, reason)
    local p = player(src)
    if not p then return false end
    return p.Functions.AddMoney(account(), amount, 'noirx:' .. tostring(reason or '')) == true
end

function EconomyCustom.RemoveMoney(src, amount, reason)
    local p = player(src)
    if not p then return false end
    -- Le core n'interdit le négatif que pour cash/crypto : on vérifie le solde pour tous les comptes.
    if (tonumber(p.PlayerData.money and p.PlayerData.money[account()]) or 0) < amount then return false end
    return p.Functions.RemoveMoney(account(), amount, 'noirx:' .. tostring(reason or '')) == true
end

-- Le core signale chaque mouvement d'argent : le téléphone ouvert se met à jour tout seul.
AddEventHandler('elyzea:server:onMoneyChange', function(src, kind)
    if kind == account() and Push then Push.ToSrc(tonumber(src), 'wallet:changed', {}) end
end)
