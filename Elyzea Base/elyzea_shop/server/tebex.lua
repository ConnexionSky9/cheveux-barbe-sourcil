-- =====================================================================
--  Tebex : intégration OFFICIELLE de FiveM (sv_tebexSecret dans server.cfg).
--  Après un paiement confirmé, Tebex exécute les commandes du paquet dans la CONSOLE du serveur.
--  Ces commandes ne sont acceptées que depuis la console (source 0) : un joueur, même admin,
--  ne peut pas les lancer. Commandes à mettre dans chaque paquet Tebex (voir README) :
--
--    À l'achat :                         elyzea_shop_deliver {transaction} {id} <cle_produit>
--    À l'expiration / remboursement /
--    opposition bancaire :               elyzea_shop_revoke {transaction} {id} <cle_produit>
--
--  {transaction} et {id} sont des variables Tebex ; <cle_produit> est la clé du produit dans config.lua.
--  Le clic « Acheter » dans la boutique n'accorde RIEN : seul Tebex, après paiement, déclenche ces commandes.
-- =====================================================================
Tebex = {}

local function cleanAccount(v)
    v = tostring(v or ''):gsub('^fivem:', '')
    return v:match('^%d+$') and #v <= 20 and v or nil
end
local function cleanTx(v)
    v = tostring(v or '')
    return v:match('^[%w%-_%.]+$') and #v >= 3 and #v <= 64 and v or nil
end

local function handle(source, args, action)
    if source ~= 0 then
        print(('^1[elyzea_shop] %s refusée : commande réservée à la console (joueur %s)^0'):format(action, tostring(source)))
        Db.log('warn', 'tebex_command_from_player', nil, nil, ('source %s'):format(source))
        return
    end
    local tx, account, key = cleanTx(args[1]), cleanAccount(args[2]), tostring(args[3] or '')
    if not tx or not account or not Config.Products[key] then
        -- Paramètres invalides : visible dans la console et le journal pour corriger la commande du paquet Tebex
        print(('^1[elyzea_shop] commande Tebex invalide : %s %s %s %s^0'):format(action, tostring(args[1]), tostring(args[2]), tostring(args[3])))
        Db.log('error', 'tebex_bad_command', account, tx, ('%s %s %s %s'):format(action, tostring(args[1]), tostring(args[2]), key))
        return
    end
    CreateThread(function()
        Db.log('info', 'tebex_' .. action, account, tx, key)
        local status, existed = Shop.enqueue(tx, key, action, account, 'tebex')
        print(('[elyzea_shop] Tebex %s %s → %s (compte %s, transaction %s)%s'):format(action, key, tostring(status), account, tx, existed and ' [déjà traitée]' or ''))
    end)
end

RegisterCommand('elyzea_shop_deliver', function(source, args) handle(source, args, 'grant') end, true)
RegisterCommand('elyzea_shop_revoke', function(source, args) handle(source, args, 'revoke') end, true)

--- Lien de la page du paquet sur la boutique Tebex officielle (aucun secret)
function Tebex.packageUrl(packageId)
    local id = tonumber(packageId)
    if not id then return nil end
    return (Config.Tebex.packageUrl:gsub('{store}', (Config.Tebex.storeUrl:gsub('/+$', ''))):gsub('{id}', tostring(math.floor(id))))
end
