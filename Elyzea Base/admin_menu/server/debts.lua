-- =========================================================
--  JOUEURS EN NÉGATIF EN BANQUE (permission « view_debts »)
--  La liste est recalculée en arrière-plan (au plus toutes les 30 s,
--  seulement si quelqu'un la consulte) : l'envoi des données du menu
--  n'attend jamais la base de données.
-- =========================================================
local AM = AdminMenu
local cache = { list = {}, total = 0, updated = nil }
local wanted, busy = 0, false

local function db(query, params)
    return MySQL.query.await(query, params or {}) or {}
end

local function refresh()
    if busy then return end
    busy = true
    local ok, err = pcall(function()
        local list = {}
        local rows = db([[SELECT citizenid AS id, charinfo, money FROM players
            WHERE CAST(JSON_UNQUOTE(JSON_EXTRACT(money, '$.bank')) AS DECIMAL(20,2)) < 0]])
        local byId = {}
        for _, r in ipairs(rows) do
            local m = json.decode(r.money or '{}') or {}
            local name = r.name
            if not name and r.charinfo then
                local ci = json.decode(r.charinfo) or {}
                name = ('%s %s'):format(ci.firstname or '?', ci.lastname or '')
            end
            local e = { citizenid = r.id, name = name or r.id, bank = math.floor(tonumber(m.bank) or 0) }
            list[#list + 1] = e
            byId[r.id] = e
        end
        -- Joueurs connectés : solde en direct (plus récent que la base)
        for _, p in ipairs(GetPlayers()) do
            local src = tonumber(p)
            local cid = Bridge.GetCharId(src)
            local bank = cid and tonumber(Bridge.GetMoney(src, 'bank'))
            if cid and bank then
                local e = byId[cid]
                if bank < 0 then
                    if not e then e = { citizenid = cid, name = Bridge.GetCharName(src) or GetPlayerName(src) } list[#list + 1] = e byId[cid] = e end
                    e.bank, e.online, e.rp = math.floor(bank), src, GetPlayerName(src)
                elseif e then
                    e.remove = true   -- il a remboursé depuis le dernier enregistrement
                end
            end
        end
        local out, total = {}, 0
        for _, e in ipairs(list) do if not e.remove then out[#out + 1] = e total = total + e.bank end end
        table.sort(out, function(a, b) return a.bank < b.bank end)
        cache = { list = out, total = total, updated = os.date('%H:%M:%S') }
    end)
    if not ok then print(('^1[AdminMenu] Banque négative : %s^7'):format(tostring(err))) end
    busy = false
end

CreateThread(function()
    while true do
        if wanted > os.time() then refresh() end
        Wait(30000)
    end
end)

table.insert(AM.DataHooks, function(src, data)
    if not AM.hasPerm(src, 'view_debts') then return end
    if wanted < os.time() and not cache.updated then CreateThread(refresh) end   -- première consultation
    wanted = os.time() + 120   -- quelqu'un regarde : on garde la liste à jour pendant 2 min
    data.debts = cache
end)

AM.Actions.debts_refresh = { perm = 'view_debts', fn = function() refresh() end }
