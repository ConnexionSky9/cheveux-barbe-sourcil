-- =========================================================
--  EAU BUGUÉE (zones sans eau, bord noir droit) : diagnostic
--  Une map qui déclare data_file 'WATER_FILE' remplace TOUTE l'eau du jeu par son water.xml :
--  s'il est incomplet, des lacs / rivières disparaissent. Cette commande liste ces ressources.
--  /eau_diagnostic  (console du serveur, ou Fondateur en jeu)
-- =========================================================
local function list()
    local found = {}
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res then
            for k = 0, (GetNumResourceMetadata(res, 'data_file') or 0) - 1 do
                if GetResourceMetadata(res, 'data_file', k) == 'WATER_FILE' then
                    local file = (GetResourceMetadata(res, 'data_file_extra', k) or ''):gsub('^%s*"', ''):gsub('"%s*$', '')
                    found[#found + 1] = { res = res, file = file, state = GetResourceState(res) }
                end
            end
        end
    end
    return found
end

RegisterCommand('eau_diagnostic', function(src)
    if src ~= 0 then
        local AM = AdminMenu
        local rn = AM and AM.getRankName and AM.getRankName(src)
        if rn ~= Config.OwnerRank then return end
    end
    local found = list()
    local lines = {}
    if #found == 0 then
        lines[1] = 'Aucune ressource ne remplace l\'eau du jeu (WATER_FILE) : le souci vient d\'une map qui couvre la zone (sol / collision) ou du build du jeu.'
    else
        lines[1] = ('%d ressource(s) remplacent l\'eau du jeu (seule la DERNIÈRE démarrée compte) :'):format(#found)
        for _, f in ipairs(found) do lines[#lines + 1] = ('  - %s (%s) : %s'):format(f.res, f.state, f.file) end
        lines[#lines + 1] = 'Corriger : dans le fxmanifest de cette ressource, mets « -- » devant la ligne data_file \'WATER_FILE\', puis redémarre le serveur.'
        lines[#lines + 1] = 'Ou garde-la et utilise un water.xml complet (eau du jeu + eau de la map). En jeu : /eau_vanilla pour comparer.'
    end
    for _, l in ipairs(lines) do
        if src == 0 then print('[EAU] ' .. l) else TriggerClientEvent('chat:addMessage', src, { args = { 'Eau', l } }) print('[EAU] ' .. l) end
    end
end, false)
