-- =====================================================================
--  ELYZEA BÉBÉ (modèle) - serveur : aperçus LOCAUX réservés au staff (contrôle visuel des variantes)
--  RegisterCommand(..., true) : FiveM vérifie la permission ACE command.<nom> avant d'exécuter.
--  Ces aperçus ne sont visibles que par le staff qui les lance. Le vrai bébé, visible par tous : server/bebes.lua.
-- =====================================================================
local C = Config.Staff

local function bind(cmd, action)
    RegisterCommand(cmd, function(src, args)
        if src == 0 then return print(('[elyzea_bebe_modele] /%s : commande à lancer en jeu.'):format(cmd)) end
        TriggerClientEvent('elyzea_bebe_modele:test', src, action, args)
    end, true)
end

bind(C.test, 'test')
bind(C.galerie, 'galerie')
bind(C.retirer, 'retirer')

-- Vérification au démarrage : les fichiers du jeu sont-ils bien présents ?
CreateThread(function()
    local res = GetCurrentResourceName()
    local manquants, total = {}, 0
    local function check(name)
        total = total + 1
        if not LoadResourceFile(res, 'stream/' .. name) then manquants[#manquants + 1] = name end
    end
    check('ely_bebe.ytyp')
    check('ely_bebe_txd.ytd')
    for _, p in pairs(BebeModeles.poses) do
        for _, group in ipairs({ 'corps', 'yeux', 'cheveux' }) do
            for _, n in pairs(p[group]) do check(n .. '.ydr') end
        end
    end
    if #manquants > 0 then
        print(('^1[elyzea_bebe_modele] %d fichier(s) manquant(s) dans stream/ (ex. %s)^0'):format(#manquants, manquants[1]))
    else
        print(('^2[elyzea_bebe_modele] Prêt : %d fichiers de modèle présents.^0'):format(total))
    end
end)
