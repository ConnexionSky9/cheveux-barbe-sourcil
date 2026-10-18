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
        lines[1] = 'Aucune ressource ne remplace l\'eau du jeu par WATER_FILE.'
        lines[2] = 'Autre cause fréquente : un script Cayo Perico (ex. cayo-perico-ultimate-main) charge l\'eau de l\'île. En jeu, à l\'endroit bugué : /eau_zone puis /eau_principale.'
        lines[3] = 'Si l\'eau ne revient pas : c\'est une map qui couvre la zone (sol / collision) ; arrête-les une par une pour trouver laquelle.'
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

-- =========================================================
--  /eau_maps (console ou Fondateur) : ressources démarrées qui chargent des morceaux de carte
--  (.ymap = objets / sol posés, .ybn = collisions). Pour trouver celle qui recouvre l'eau :
--  mets « # » devant la moitié de leurs lignes ensure, redémarre, regarde ; puis recommence sur la bonne moitié.
-- =========================================================
local function countMapFiles(res)
    local path = GetResourcePath(res)
    if not path or path == '' then return nil end
    local cmd = (package and package.config or '/'):sub(1, 1) == '\\'
        and ('dir /s /b "%s" 2>nul'):format(path:gsub('/', '\\'))
        or ('find "%s" -type f 2>/dev/null'):format(path)
    local ok, h = pcall(io.popen, cmd)
    if not ok or not h then return nil end
    local ymap, ybn, water = 0, 0, {}
    for line in h:lines() do
        local l = line:lower()
        if l:sub(-5) == '.ymap' then ymap = ymap + 1
        elseif l:sub(-4) == '.ybn' then ybn = ybn + 1 end
        if l:find('water', 1, true) and (l:sub(-4) == '.xml' or l:sub(-4) == '.ymt' or l:sub(-5) == '.meta') then
            water[#water + 1] = line:match('[^/\\]+$')
        end
    end
    h:close()
    return ymap, ybn, water
end

RegisterCommand('eau_maps', function(src)
    if src ~= 0 then
        local AM = AdminMenu
        local rn = AM and AM.getRankName and AM.getRankName(src)
        if rn ~= Config.OwnerRank then return end
    end
    local out, scanned = {}, false
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res and GetResourceState(res) == 'started' then
            local ymap, ybn, water = countMapFiles(res)
            if ymap then scanned = true end
            local isMap = GetResourceMetadata(res, 'this_is_a_map', 0) ~= nil
            if (ymap and (ymap > 0 or ybn > 0 or #water > 0)) or (not ymap and isMap) then
                out[#out + 1] = ymap
                    and ('  - %s : %d ymap, %d ybn%s'):format(res, ymap, ybn, #water > 0 and (' | fichiers d\'eau : ' .. table.concat(water, ', ')) or '')
                    or ('  - %s (map)'):format(res)
            end
        end
    end
    local function say(l) if src == 0 then print('[EAU] ' .. l) else TriggerClientEvent('chat:addMessage', src, { args = { 'Eau', l } }) print('[EAU] ' .. l) end end
    say(('%d ressource(s) chargent des morceaux de carte%s :'):format(#out, scanned and '' or ' (dossiers illisibles : seules celles marquées « map » sont listées)'))
    for _, l in ipairs(out) do say(l) end
    say('Retire-les par moitié (# devant ensure, redémarrage complet, reconnexion) jusqu\'à ce que l\'eau revienne.')
end, false)

-- Grade staff d'un joueur (utilisé par elyzea_eau : /eau_ajouter réservé au Fondateur)
exports('GetStaffRank', function(src) return AdminMenu and AdminMenu.getRankName and AdminMenu.getRankName(src) or nil end)
