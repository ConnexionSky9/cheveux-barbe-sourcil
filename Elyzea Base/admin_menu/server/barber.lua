-- =========================================================
--  COIFFEUR / BARBIER - SERVEUR
--  Le PNJ est posé avec l'éditeur (rôle « Coiffeur »).
--  Le serveur ne fait JAMAIS confiance au prix envoyé par le client :
--  il recalcule le total avec les prix du PNJ avant de débiter.
-- =========================================================
local AM = AdminMenu
local CFG = Config.Barber or {}

-- Clés du panier → service qui les autorise (tout vient de barber_data.lua)
local KEYS, SERVICES = {}, {}
for key, k in pairs(BarberData.keys) do KEYS[key] = k.service end
for _, sv in ipairs(BarberData.services) do SERVICES[#SERVICES + 1] = sv.id end

local function num(v, mn, mx, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if v < mn then return mn end
    if v > mx then return mx end
    return v
end
local function int(v, mn, mx, def) local n = num(v, mn, mx, nil) return n and math.floor(n) or def end

-- ---------------------------------------------------------
--  Nettoyage du rôle (appelé par server/editor.lua › cleanNpc)
-- ---------------------------------------------------------
function BarberCleanRole(b)
    local def = CFG.defaultPrices or {}
    local prices = {}
    local src = type(b.prices) == 'table' and b.prices or {}
    for key in pairs(KEYS) do
        prices[key] = int(src[key], 0, 1000000, int(def[key], 0, 1000000, 0))
    end
    local services = {}
    local seen = {}
    for _, s in ipairs(type(b.services) == 'table' and b.services or {}) do
        for _, ok in ipairs(SERVICES) do
            if s == ok and not seen[s] then seen[s] = true services[#services + 1] = s end
        end
    end
    local name = tostring(b.name or ''):gsub('[<>]', ''):sub(1, 40)
    return {
        name = name ~= '' and name or 'Salon de coiffure',
        prices = prices,
        services = services,                       -- vide = tous les services
        payChoice = b.payChoice ~= false,          -- le joueur choisit liquide ou banque
        specialEyes = b.specialEyes == true,       -- lentilles fantaisie (yeux de démon, zombie…)
        blip = b.blip == true,
        blipSprite = int(b.blipSprite, 1, 900, CFG.blipSprite or 71),
        blipColor = int(b.blipColor, 0, 85, CFG.blipColor or 4),
    }
end

-- Prix d'une prestation (un salon créé avant l'ajout d'un service prend le prix par défaut)
local function priceOf(bb, key)
    local p = bb.prices and bb.prices[key]
    if p == nil then p = (CFG.defaultPrices or {})[key] end
    return math.floor(tonumber(p) or 0)
end

local function offers(bb, service)
    if not bb.services or #bb.services == 0 then return true end
    for _, s in ipairs(bb.services) do if s == service then return true end end
    return false
end

-- ---------------------------------------------------------
--  Têtes sauvegardées (mode 'internal')
-- ---------------------------------------------------------
local Looks = Storage.load('barber_looks', {})

-- Tête par PERSONNAGE : clé = citizenid (jamais la licence, commune à tous les personnages du compte)
local function charKey(src)
    local ok, cid = pcall(function() return exports.elyzea_core:GetCitizenId(src) end)
    if ok and cid and tostring(cid) ~= '' then return tostring(cid) end
    return nil
end

-- Valide une valeur de panier / de tête. Renvoie nil si invalide.
local function cleanValue(key, v, bb)
    if key == 'hair' then return int(v, 0, 500, nil) end
    if key == 'eyes' then
        local e = int(v, 0, 31, nil)
        if e and bb and not bb.specialEyes and e >= (BarberData.naturalEyes or 9) then return nil end
        return e
    end
    local k = BarberData.keys[key]
    if k and k.kind == 'style' then
        if type(v) ~= 'table' then return nil end
        local st = int(v.s, -1, 120, nil)
        if not st then return nil end
        return { s = st, o = math.floor(num(v.o, 0, 1, 1) * 100 + 0.5) / 100 }
    end
    return int(v, 0, 63, nil) -- couleurs
end

local function cleanLook(look)
    if type(look) ~= 'table' then return nil end
    local out = { model = (look.model == 'female') and 'female' or 'male' }
    for key in pairs(KEYS) do
        if look[key] ~= nil then out[key] = cleanValue(key, look[key], nil) end
    end
    if out.hair == nil then return nil end
    -- Coupe d'un pack addon : texture + collection + n° dans la collection (retrouvée même si les n° globaux changent)
    out.hairTex = int(look.hairTex, 0, 63, 0)
    if type(look.hairCol) == 'string' and look.hairCol:match('^[%w_%-]+$') and #look.hairCol <= 64 then
        out.hairCol = look.hairCol
        out.hairLi = int(look.hairLi, 0, 1000, nil)
        if out.hairLi == nil then out.hairCol = nil end
    end
    return out
end

RegisterNetEvent('adminmenu:barber:getLook', function()
    local src = source
    if not AM.rateLimit(src, 'barber_look', 3, 5000) then return end
    local key = charKey(src)
    if not key then return end
    TriggerClientEvent('adminmenu:barber:look', src, Looks[key] or false, key)
end)

-- ---------------------------------------------------------
--  Ouverture du salon (le joueur a appuyé sur E)
-- ---------------------------------------------------------
local Paying = {}

RegisterNetEvent('adminmenu:barber:request', function(id)
    local src = source
    if CFG.enabled == false then return end
    if not AM.rateLimit(src, 'npc', 4, 1000) then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.barber then return end
    local bb, n = r.npc.barber, r.npc

    local prices = {}
    for key, service in pairs(KEYS) do
        if offers(bb, service) then prices[key] = priceOf(bb, key) end
    end
    local wallet = {}
    if bb.payChoice and n.payment ~= 'item' then
        wallet.cash = Bridge.GetMoney(src, 'cash')
        wallet.bank = Bridge.GetMoney(src, 'bank')
    else
        wallet[n.payment] = Bridge.GetMoney(src, n.payment, n.paymentItem)
    end

    TriggerClientEvent('adminmenu:barber:show', src, {
        id = r.id, name = bb.name, prices = prices,
        payChoice = bb.payChoice and n.payment ~= 'item', payment = n.payment,
        paymentLabel = n.payment == 'item' and (Bridge.GetLabel(n.paymentItem) or n.paymentItem) or nil,
        specialEyes = bb.specialEyes, wallet = wallet,
    })
end)

-- ---------------------------------------------------------
--  Paiement du panier
-- ---------------------------------------------------------
local function result(src, ok, msg, total)
    TriggerClientEvent('adminmenu:barber:result', src, ok, msg, total)
end

RegisterNetEvent('adminmenu:barber:pay', function(id, cart, look, method)
    local src = source
    if not AM.rateLimit(src, 'barber_pay', 2, 1500) then return end
    if Paying[src] then return end
    local r = AM.EditorPeds.check(src, id)
    if not r or not r.npc.barber then return result(src, false, 'Tu es trop loin du salon.') end
    local bb, n = r.npc.barber, r.npc
    if type(cart) ~= 'table' then return result(src, false, 'Panier invalide.') end

    -- Recalcul du total avec les prix du serveur
    local total, lines = 0, 0
    for key, value in pairs(cart) do
        local service = KEYS[key]
        if not service or not offers(bb, service) then return result(src, false, 'Ce salon ne propose pas ce service.') end
        if cleanValue(key, value, bb) == nil then return result(src, false, 'Choix invalide dans le panier.') end
        total = total + priceOf(bb, key)
        lines = lines + 1
    end
    if lines == 0 then return result(src, false, 'Ton panier est vide.') end
    if not charKey(src) then return result(src, false, 'Personnage non chargé : réessaie dans un instant.') end

    local kind, item = n.payment, n.paymentItem
    if bb.payChoice and n.payment ~= 'item' then kind = (method == 'bank') and 'bank' or 'cash' end

    Paying[src] = true
    if total > 0 then
        if Bridge.GetMoney(src, kind, item) < total then
            Paying[src] = nil
            return result(src, false, kind == 'bank' and 'Pas assez d\'argent sur ton compte.' or 'Tu n\'as pas assez d\'argent sur toi.')
        end
        if not Bridge.RemoveMoney(src, kind, item, total, 'coiffeur') then
            Paying[src] = nil
            return result(src, false, 'Le paiement a échoué.')
        end
    end
    Paying[src] = nil

    -- Sauvegarde interne (sert de secours si aucune ressource d'apparence n'est trouvée)
    local clean = cleanLook(look)
    local key = charKey(src)
    if clean and key then
        Looks[key] = clean
        Storage.save('barber_looks', Looks)
    end

    result(src, true, total > 0 and ('Payé %s $. Nouvelle tête enregistrée !'):format(total) or 'Nouvelle tête enregistrée !', total)
    TriggerEvent('adminmenu:barber:paid', src, total, r.id, cart)  -- pour une société / des logs externes
end)

AddEventHandler('playerDropped', function() Paying[source] = nil end)

-- ---------------------------------------------------------
--  Diagnostic des packs de coupes addon (Config.Barber.debug = true)
--  Le client envoie les collections de coupes qu'il voit ; le serveur retrouve
--  la ressource qui les déclare (SHOP_PED_APPAREL_META_FILE) et vérifie ses fichiers :
--  .meta, .ymt et un .ydd / .ytd au bon nom pour CHAQUE coupe déclarée.
-- ---------------------------------------------------------
local function say(src, fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    msg = ok and msg or fmt
    print('^5[Salon]^7 ' .. msg)
    if src then TriggerClientEvent('adminmenu:barber:debug', src, msg) end
end

-- Liste (minuscules) de tous les fichiers d'une ressource, sous-dossiers compris
local function listFiles(res)
    local path = GetResourcePath(res)
    if not path or path == '' or not io or not io.popen then return nil end
    local win = package.config:sub(1, 1) == '\\'
    local cmd = win and ('dir /b /s /a-d "%s" 2>nul'):format(path:gsub('/', '\\')) or ('find "%s" -type f 2>/dev/null'):format(path)
    local ok, h = pcall(io.popen, cmd)
    if not ok or not h then return nil end
    local out = {}
    for line in h:lines() do
        local name = line:match('[^\\/]+$')
        if name then out[name:lower()] = line end
    end
    h:close()
    return out
end

local function metaFiles(res)
    local out = {}
    local n = GetNumResourceMetadata(res, 'data_file') or 0
    for i = 0, n - 1 do
        if GetResourceMetadata(res, 'data_file', i) == 'SHOP_PED_APPAREL_META_FILE' then
            local extra = GetResourceMetadata(res, 'data_file_extra', i) or ''
            extra = extra:gsub('^%s*"', ''):gsub('"%s*$', '')
            out[#out + 1] = extra
        end
    end
    return out
end

local function declaredInFiles(res, file)
    local n = GetNumResourceMetadata(res, 'file') or 0
    for i = 0, n - 1 do
        local f = GetResourceMetadata(res, 'file', i) or ''
        if f == file or f:find('[%*]') then return true end
    end
    return false
end

-- Toutes les collections déclarées par les ressources démarrées : dlc → infos
local function apparelPacks()
    local packs = {}
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res and GetResourceState(res) == 'started' then
            for _, file in ipairs(metaFiles(res)) do
                local xml = LoadResourceFile(res, file)
                local p = { res = res, meta = file, found = xml ~= nil, listed = declaredInFiles(res, file) }
                if xml then
                    p.ped = xml:match('<pedName>%s*(.-)%s*</pedName>')
                    p.dlc = xml:match('<dlcName>%s*(.-)%s*</dlcName>')
                    p.full = xml:match('<fullDlcName>%s*(.-)%s*</fullDlcName>')
                end
                local key = (p.dlc or file):lower()
                packs[key] = p
                if p.full then packs[p.full:lower()] = p end
            end
        end
    end
    return packs
end

RegisterNetEvent('adminmenu:barber:checkPacks', function(ped, cols)
    local src = source
    if not CFG.debug then return end
    if not AM.rateLimit(src, 'barber_check', 1, 10000) then return end
    if type(cols) ~= 'table' or (ped ~= 'mp_m_freemode_01' and ped ~= 'mp_f_freemode_01') then return end
    local packs = apparelPacks()
    if #cols == 0 then
        say(src, 'Aucune collection addon de coupes chargée pour %s : seules les coupes du jeu sont disponibles.', ped)
    end
    for i, c in ipairs(cols) do
        if i > 30 then break end
        local col, count = tostring(c.col or ''), math.floor(tonumber(c.count) or 0)
        local p = packs[col:lower()] or packs[(ped .. '_' .. col):lower()]
        if not p then
            say(src, '%s (%d coupes) : déclarée par un DLC du jeu ou par une ressource sans data_file lisible.', col, count)
        else
            local prefix = (p.full or (ped .. '_' .. col)):lower()
            say(src, '%s : ressource « %s », meta « %s »%s', col, p.res, p.meta, p.listed and '' or ' ^1(absent de files {} du fxmanifest)^7')
            if p.ped and p.ped:lower() ~= ped then say(src, '  ^1pedName du .meta = %s, attendu %s^7', p.ped, ped) end
            if p.full and p.dlc and p.full:lower() ~= (ped .. '_' .. p.dlc):lower() then
                say(src, '  ^1fullDlcName (%s) ≠ pedName + "_" + dlcName (%s_%s)^7', p.full, ped, p.dlc)
            end
            local files = listFiles(p.res)
            if not files then
                -- Pas de liste des dossiers sur ce serveur : on cherche aux emplacements habituels
                files = {}
                local dirs = { '', 'stream/', ('stream/%s/'):format(p.dlc or col), ('stream/%s/'):format(prefix), 'stream/hair/', ('stream/%s/'):format(ped) }
                local function probe(name)
                    for _, d in ipairs(dirs) do
                        if LoadResourceFile(p.res, d .. name) then files[name:lower()] = d .. name return end
                    end
                end
                probe(prefix .. '.ymt')
                for li = 0, count - 1 do
                    probe(('%s^hair_%03d_u.ydd'):format(prefix, li)); probe(('%s^hair_%03d_r.ydd'):format(prefix, li))
                    probe(('%s^hair_diff_%03d_a_uni.ytd'):format(prefix, li)); probe(('%s^hair_diff_%03d_a_whi.ytd'):format(prefix, li))
                end
                say(src, '  (recherche limitée à stream/ et à ses sous-dossiers habituels : un fichier rangé ailleurs sera signalé manquant)')
            end
            do
                say(src, '  .ymt %s : %s', prefix .. '.ymt', files[prefix .. '.ymt'] and 'trouvé' or '^1MANQUANT^7')
                local missing, wrongSuffix, noTex = {}, {}, {}
                for li = 0, count - 1 do
                    local u = files[('%s^hair_%03d_u.ydd'):format(prefix, li)]
                    local r = files[('%s^hair_%03d_r.ydd'):format(prefix, li)]
                    if not u and not r then missing[#missing + 1] = li end
                    if not files[('%s^hair_diff_%03d_a_uni.ytd'):format(prefix, li)] and not files[('%s^hair_diff_%03d_a_whi.ytd'):format(prefix, li)] then noTex[#noTex + 1] = li end
                end
                -- Fichiers de coupes présents mais sous un AUTRE préfixe (cause classique de tête chauve)
                for name in pairs(files) do
                    local pre = name:match('^(.-)%^hair_%d%d%d_[ur]%.ydd$')
                    if pre and pre ~= prefix then wrongSuffix[pre] = (wrongSuffix[pre] or 0) + 1 end
                end
                say(src, '  coupes déclarées : %d · .ydd manquants : %d · textures « a » manquantes : %d', count, #missing, #noTex)
                if #missing > 0 then
                    say(src, '  ^1n° locaux sans .ydd au bon nom : %s → ces coupes s\'affichent CHAUVES^7', table.concat(missing, ', ', 1, math.min(#missing, 30)))
                end
                for pre, n in pairs(wrongSuffix) do
                    say(src, '  ^3%d fichier(s) .ydd nommés « %s^hair_… » dans cette ressource : préfixe différent de « %s »^7', n, pre, prefix)
                end
            end
        end
    end
end)

-- Statistiques simples pour d'autres ressources
exports('GetBarberLook', function(src) local k = charKey(src) return k and Looks[k] or nil end)
