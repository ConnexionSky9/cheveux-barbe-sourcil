-- =====================================================================
--  ELYZEA CLOTHING · DÉTECTION AUTOMATIQUE DES PACKS
--  Un pack de vêtements est une ressource qui déclare dans son fxmanifest :
--      data_file 'SHOP_PED_APPAREL_META_FILE' 'xxx.meta'
--  (c'est le cas de tous les packs « addon », Durty Cloth Tool compris).
--  On lit ce fichier pour connaître sa « collection » (<dlcName>) et son sexe (<pedName>) :
--  la boutique sait alors quels vêtements viennent de quel pack, sans aucun réglage.
--  Nouveau pack démarré ou arrêté : la liste se met à jour toute seule.
-- =====================================================================
Packs = { list = {}, byCol = {}, version = 0 }

local ME = GetCurrentResourceName()

-- « mes_vetements-luxe » -> « Mes vetements luxe »
local function pretty(name)
    local s = tostring(name):gsub('^%[.-%]', ''):gsub('[_%-%.]+', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return (s:gsub('^%l', string.upper))
end

local function paths(extra)
    local ok, v = pcall(json.decode, extra or '')
    if not ok then return {} end
    if type(v) == 'string' then return { v } end
    if type(v) == 'table' then
        local out = {}
        for _, p in ipairs(v) do if type(p) == 'string' then out[#out + 1] = p end end
        return out
    end
    return {}
end

local function override(res, cols)
    local list = Config.Packs.list or {}
    if list[res] then return list[res] end
    for col in pairs(cols) do if list[col] then return list[col] end end
    return {}
end

-- Lit les fichiers « boutique » d'une ressource. Renvoie nil si ce n'est pas un pack.
local function scanResource(res)
    local n = GetNumResourceMetadata(res, 'data_file') or 0
    local cols, sexes, files, glob = {}, {}, 0, false
    for j = 0, n - 1 do
        if GetResourceMetadata(res, 'data_file', j) == 'SHOP_PED_APPAREL_META_FILE' then
            for _, path in ipairs(paths(GetResourceMetadata(res, 'data_file_extra', j))) do
                files = files + 1
                if path:find('%*') then
                    glob = true
                else
                    local xml = LoadResourceFile(res, path)
                    if xml then
                        local dlc = xml:match('<dlcName>%s*([^<%s]+)%s*</dlcName>')
                        local ped = xml:match('<pedName>%s*([^<%s]+)%s*</pedName>') or ''
                        if dlc then cols[dlc:lower()] = true end
                        if ped:find('mp_m_') then sexes.male = true elseif ped:find('mp_f_') then sexes.female = true end
                    end
                end
            end
        end
    end
    -- Secours : fxmanifest sans data_file lisible -> on lit les .meta cités dans le fichier du manifeste
    if next(cols) == nil then
        local manifest = LoadResourceFile(res, 'fxmanifest.lua') or LoadResourceFile(res, '__resource.lua') or ''
        for path in manifest:gmatch('[\'"]([^\'"]-%.meta)[\'"]') do
            local xml = not path:find('%*') and LoadResourceFile(res, path)
            local dlc = xml and xml:find('ShopPedApparel', 1, true) and xml:match('<dlcName>%s*([^<%s]+)%s*</dlcName>')
            if dlc then
                files = files + 1
                cols[dlc:lower()] = true
                local ped = xml:match('<pedName>%s*([^<%s]+)%s*</pedName>') or ''
                if ped:find('mp_m_') then sexes.male = true elseif ped:find('mp_f_') then sexes.female = true end
            end
        end
    end
    if files == 0 then return nil end
    local o = override(res, cols)
    return {
        id = res, label = o.label or pretty(res), cols = cols, male = sexes.male == true, female = sexes.female == true,
        price = math.max(0, math.floor(tonumber(o.price) or tonumber(Config.Packs.price) or 100)),
        hidden = o.hidden == true, unreadable = glob and next(cols) == nil,
    }
end

local function publicList()
    local out = {}
    for _, p in ipairs(Packs.list) do
        local cols = {}
        for c in pairs(p.cols) do cols[#cols + 1] = c end
        out[#out + 1] = { id = p.id, label = p.label, cols = cols, price = p.price, hidden = p.hidden, male = p.male, female = p.female }
    end
    return out
end

function Packs.scan(quiet)
    local list, byCol = {}, {}
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res and res ~= ME and GetResourceState(res) == 'started' then
            local p = scanResource(res)
            if p then
                list[#list + 1] = p
                for c in pairs(p.cols) do byCol[c] = p end
            end
        end
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    Packs.list, Packs.byCol, Packs.version = list, byCol, Packs.version + 1
    TriggerClientEvent('elyzea_clothing:packs', -1, publicList(), Config.Packs.showGTA ~= false)
    if not quiet then
        if #list == 0 then
            print('^3[elyzea_clothing] Aucun pack de vêtements détecté (vêtements de GTA seulement).^0')
        else
            local names = {}
            for _, p in ipairs(list) do
                names[#names + 1] = p.label .. (p.hidden and ' (caché)' or '') .. (p.unreadable and ' (nom de collection illisible)' or '')
            end
            print(('^2[elyzea_clothing] %d pack(s) de vêtements détecté(s) : %s^0'):format(#list, table.concat(names, ', ')))
        end
    end
end

-- Pack d'une collection (nil = vêtement de GTA)
function Packs.ofCollection(col)
    if type(col) ~= 'string' or col == '' then return nil end
    return Packs.byCol[col:lower()]
end

RegisterNetEvent('elyzea_clothing:requestPacks', function()
    TriggerClientEvent('elyzea_clothing:packs', source, publicList(), Config.Packs.showGTA ~= false)
end)

-- Un pack démarre ou s'arrête pendant que le serveur tourne : nouvelle détection (regroupée)
local rescanAt = nil
local function scheduleRescan()
    local token = GetGameTimer()
    rescanAt = token
    SetTimeout(3000, function() if rescanAt == token then Packs.scan() end end)
end
AddEventHandler('onServerResourceStart', function(res) if res ~= ME then scheduleRescan() end end)
AddEventHandler('onServerResourceStop', function(res) if res ~= ME then scheduleRescan() end end)

CreateThread(function()
    Wait(1500)   -- laisse démarrer les packs listés après cette ressource
    Packs.scan()
end)

exports('GetPacks', function() return publicList() end)

-- Console serveur : liste des packs détectés
RegisterCommand('vetements_packs', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command') then return end
    -- vetements_packs <dossier> : ce que la boutique voit d'une ressource précise
    if args[1] then
        local res = args[1]
        local n = GetNumResourceMetadata(res, 'data_file') or 0
        print(('[elyzea_clothing] %s : état « %s », %d ligne(s) data_file'):format(res, GetResourceState(res), n))
        for j = 0, n - 1 do
            print(('  data_file %s %s'):format(GetResourceMetadata(res, 'data_file', j), GetResourceMetadata(res, 'data_file_extra', j) or '?'))
        end
        local manifest = LoadResourceFile(res, 'fxmanifest.lua') or LoadResourceFile(res, '__resource.lua')
        print(manifest and '  manifeste lu' or '  ^1manifeste introuvable (fxmanifest.lua)^0')
        for path in (manifest or ''):gmatch('[\'"]([^\'"]-%.meta)[\'"]') do
            local xml = LoadResourceFile(res, path)
            print(('  %s : %s'):format(path, not xml and '^1fichier introuvable^0'
                or (xml:match('<dlcName>%s*([^<%s]+)') and ('collection ' .. xml:match('<dlcName>%s*([^<%s]+)')) or 'pas un fichier de boutique')))
        end
        local p = GetResourceState(res) == 'started' and scanResource(res)
        print(p and ('  ^2-> pack détecté : ' .. p.label .. '^0') or '  ^1-> pas détecté comme pack^0')
        return
    end
    Packs.scan(true)
    print(('[elyzea_clothing] %d pack(s) :'):format(#Packs.list))
    for _, p in ipairs(Packs.list) do
        local cols = {}
        for c in pairs(p.cols) do cols[#cols + 1] = c end
        print(('  - %s  (dossier %s · %s%s · prix %d %%%s)'):format(p.label, p.id,
            (p.male and 'homme' or '') .. (p.male and p.female and ' + ' or '') .. (p.female and 'femme' or ''),
            #cols > 0 and (' · collection ' .. table.concat(cols, ', ')) or '', p.price, p.hidden and ' · CACHÉ' or ''))
    end
end, true)
