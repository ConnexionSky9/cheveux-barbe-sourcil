-- =====================================================================
--  ELYZEA — MULTICHAR · SERVEUR (base Elyzea)
-- =====================================================================
local owned   = {}  -- [src] = { [slot] = citizenid }
local busy    = {}  -- [src] = true pendant un login
local lastAsk = {}  -- anti-spam

local function dbg(...) if Config.Debug then print('[elyzea_multichar]', ...) end end

local function validSlot(slot)
    slot = tonumber(slot)
    if slot and slot >= 1 and slot <= Config.Slots and slot % 1 == 0 then return slot end
end

local function decode(v)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return nil end
    local ok, res = pcall(json.decode, v)
    return ok and res or nil
end

local function licenses(src)
    return GetPlayerIdentifierByType(src, 'license2') or 'none', GetPlayerIdentifierByType(src, 'license') or 'none'
end

local function fetchCharacters(src)
    local l2, l1 = licenses(src)
    local params = { l2, l1, Config.Slots + 3 }
    -- 1) avec l'apparence d'ely_creator (ely_characters)
    local ok, rows = pcall(MySQL.query.await, [[
        SELECT p.citizenid, p.cid, p.charinfo, p.money, p.job, p.gang, p.last_updated,
               e.skin AS ely_skin
        FROM players p
        LEFT JOIN ely_characters e ON e.identifier = p.citizenid
        WHERE p.license = ? OR p.license = ?
        ORDER BY p.cid ASC LIMIT ?
    ]], params)
    -- 2) sinon sans les tables d'apparence
    if not ok or type(rows) ~= 'table' then
        dbg('tables d\'apparence indisponibles, requête simple')
        rows = MySQL.query.await([[
            SELECT citizenid, cid, charinfo, money, job, gang, last_updated
            FROM players WHERE license = ? OR license = ?
            ORDER BY cid ASC LIMIT ?
        ]], params) or {}
    end

    local list, slots, used = {}, {}, {}
    -- 1er passage : persos dont le cid correspond à un slot
    for _, r in ipairs(rows) do
        local cid = tonumber(r.cid)
        if cid and cid >= 1 and cid <= Config.Slots and not used[cid] then used[cid] = r end
    end
    -- 2e passage : les autres prennent un slot libre
    for _, r in ipairs(rows) do
        local placed = false
        for s = 1, Config.Slots do if used[s] == r then placed = true end end
        if not placed then
            for s = 1, Config.Slots do
                if not used[s] then used[s] = r; break end
            end
        end
    end

    for slot = 1, Config.Slots do
        local r = used[slot]
        if r then
            local info  = decode(r.charinfo) or {}
            local money = decode(r.money) or {}
            local job   = decode(r.job) or {}
            local gang  = decode(r.gang) or {}
            local jobTxt = job.label or 'Sans emploi'
            if job.grade and job.grade.name and job.name ~= 'unemployed' then jobTxt = jobTxt .. ' · ' .. job.grade.name end
            if gang.name and gang.name ~= 'none' and gang.label then jobTxt = jobTxt .. ' | ' .. gang.label end

            local last = '—'
            local ts = tonumber(r.last_updated)
            if ts then last = os.date('%d/%m/%Y %H:%M', math.floor(ts / 1000)) end

            slots[slot] = r.citizenid
            list[#list + 1] = {
                id = r.citizenid, slot = slot,
                firstname = info.firstname or '?', lastname = info.lastname or '',
                gender = tonumber(info.gender) or 0,
                job = jobTxt,
                cash = tonumber(money.cash) or 0, bank = tonumber(money.bank) or 0,
                lastPlayed = last,
                elySkin = decode(r.ely_skin)
            }
        end
    end
    owned[src] = slots
    return list
end

RegisterNetEvent('elyzea_multichar:requestCharacters', function()
    local src = source
    local now = GetGameTimer()
    if lastAsk[src] and now - lastAsk[src] < 3000 then return end
    lastAsk[src] = now
    if exports.elyzea_core:GetPlayer(src) then return end -- déjà connecté

    SetPlayerRoutingBucket(src, 1000 + src) -- seul pendant la sélection
    local ok, list = pcall(fetchCharacters, src)
    if not ok then
        -- Sans liste, le joueur resterait sur un écran noir : on l'en informe
        print('[elyzea_multichar] Personnages introuvables (base de données) : ' .. tostring(list))
        return DropPlayer(src, 'Impossible de charger tes personnages : la base de données ne répond pas. Réessaie dans un instant.')
    end
    dbg(('joueur %s : %d personnage(s)'):format(src, #list))
    TriggerClientEvent('elyzea_multichar:setCharacters', src, list)
end)

-- La connexion et la création sont gérées par ely_creator
-- (events ely_creator:play et ely_creator:new, qui vérifient eux-mêmes la propriété du perso).

AddEventHandler('playerDropped', function()
    local src = source
    owned[src], busy[src], lastAsk[src] = nil, nil, nil
end)
