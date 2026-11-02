-- =====================================================================
--  ELYZEA RESTAURANT - paiement en pesos de Cayo Perico (objet d'inventaire)
--  · Le client paie en pesos (prix en $ × Config.Pesos.rate, arrondi au-dessus).
--  · Les pesos vont dans le COFFRE du restaurant (resto:<id>), pas sur le compte
--    de société en $ : le patron les récupère au coffre (ou les change au bureau
--    de change de elyzea_change).
--  · Annulation : les pesos sont repris dans le coffre et rendus au client ;
--    client absent ou inventaire plein : remis à sa prochaine connexion (rs_refunds).
-- =====================================================================
local P = Resto
local core = exports.elyzea_core
local PESOS = (Config.Pesos or {}).item or 'pesos'

local function Inv() return exports.elyzea_inventory end
function P.StashId(D) return ('resto:%d'):format(D.id) end

function P.PesosCount(inv)
    local ok, n = pcall(function() return Inv():GetItemCount(inv, PESOS) end)
    return ok and math.floor(tonumber(n) or 0) or 0
end

local function AddTo(inv, amount)
    local okC, can = pcall(function() return Inv():CanCarryItem(inv, PESOS, amount) end)
    if not okC or not can then return false end
    local okA, added = pcall(function() return Inv():AddItem(inv, PESOS, amount) end)
    return okA and added == true
end
local function RemoveFrom(inv, amount)
    local ok, removed = pcall(function() return Inv():RemoveItem(inv, PESOS, amount) end)
    return ok and removed == true
end

-- Rendre des pesos à un client (connecté : tout de suite ; sinon à sa prochaine connexion)
function P.GivePesos(cid, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not cid then return true, 'none' end
    local s = core:GetSourceByCitizenId(cid)
    if s and AddTo(s, amount) then return true, 'now', s end
    MySQL.insert.await('INSERT INTO `rs_refunds` (`citizenid`, `item`, `amount`, `reason`) VALUES (?, ?, ?, ?)', { cid, PESOS, amount, P.Clean(reason or '', 160) })
    if s then P.Notify(s, ('%d pesos vous attendent (inventaire plein) : ils vous seront rendus à votre prochaine connexion.'):format(amount), 'inform') end
    return true, 'later', s
end

-- Encaisser : pesos du joueur → coffre du restaurant. Renvoie true, ou false + raison
function P.ChargePesos(src, D, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if P.PesosCount(src) < amount then return false, ('Pas assez de pesos sur vous (%d nécessaires).'):format(amount) end
    P.RegisterStash(D)
    local okC, can = pcall(function() return Inv():CanCarryItem(P.StashId(D), PESOS, amount) end)
    if not okC or not can then return false, 'Le coffre du restaurant est plein : paiement en pesos impossible pour le moment.' end
    if not RemoveFrom(src, amount) then return false, ('Pas assez de pesos sur vous (%d nécessaires).'):format(amount) end
    if not AddTo(P.StashId(D), amount) then
        P.GivePesos(P.Cid(src), amount, 'Paiement en pesos annulé · ' .. D.name)
        return false, 'Paiement en pesos impossible pour le moment : vos pesos vous ont été rendus.'
    end
    return true
end

-- Reprendre des pesos dans le coffre du restaurant (remboursement)
function P.TakeStashPesos(D, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    P.RegisterStash(D)
    if P.PesosCount(P.StashId(D)) < amount then return false end
    return RemoveFrom(P.StashId(D), amount)
end

-- Remboursements en attente d'un joueur qui se connecte
local delivering = {}
function P.DeliverRefunds(src)
    local cid = P.Cid(src)
    if not cid or delivering[cid] then return 0 end
    delivering[cid] = true
    local given = 0
    local ok, err = pcall(function()
        for _, r in ipairs(MySQL.query.await('SELECT `id`, `item`, `amount`, `reason` FROM `rs_refunds` WHERE `citizenid` = ? ORDER BY `id`', { cid }) or {}) do
            local amount = tonumber(r.amount) or 0
            local okC, can = pcall(function() return Inv():CanCarryItem(src, r.item, amount) end)
            if not okC or not can then
                P.Notify(src, ('%d pesos de remboursement vous attendent : faites de la place dans votre inventaire.'):format(amount), 'inform')
                break
            end
            -- La ligne est supprimée AVANT de donner : jamais deux fois
            local del = MySQL.update.await('DELETE FROM `rs_refunds` WHERE `id` = ?', { r.id })
            if (tonumber(del) or 0) == 1 then
                local okA, added = pcall(function() return Inv():AddItem(src, r.item, amount) end)
                if okA and added then
                    given = given + amount
                    P.Notify(src, ('Remboursement reçu : %d pesos (%s).'):format(amount, r.reason or 'restaurant'), 'success')
                else
                    MySQL.insert.await('INSERT INTO `rs_refunds` (`citizenid`, `item`, `amount`, `reason`) VALUES (?, ?, ?, ?)', { cid, r.item, amount, r.reason })
                    break
                end
            end
        end
    end)
    delivering[cid] = nil
    if not ok then print(('^1[RESTO] Remboursements en pesos (%s) : %s^0'):format(cid, tostring(err))) end
    return given
end

AddEventHandler('elyzea:server:playerLoaded', function(src)
    SetTimeout(4000, function() if P.ready and GetPlayerName(src) then P.DeliverRefunds(src) end end)
end)
