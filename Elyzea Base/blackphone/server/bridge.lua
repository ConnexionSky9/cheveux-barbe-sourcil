-- =====================================================================
--  BLACKPHONE - pont vers les ressources du serveur (aucun export inventé)
--  elyzea_core   : GetCitizenId, GetCharName, GetSourceByCitizenId, GetPlayerData, AddMoney, RemoveMoney, GetMoney, Notify
--  elyzea_inventory : GetItemCount, AddItem, RemoveItem, CanCarryItem, Search('slots'), SetMetadata, Items
--  elyzea_police : IsOnDuty, GetGrade (ajouté pour BLACKPHONE)
--  admin_menu    : HasPermission(src, 'blackphone_manage')
-- =====================================================================
Bridge = {}
local B = Bridge

local function ex(res, fn, ...)
    if GetResourceState(res) ~= 'started' then return nil end
    local args = { ... }
    local ok, a, b = pcall(function() return exports[res][fn](exports[res], table.unpack(args)) end)
    if not ok then print(('^1[BLACKPHONE] %s:%s : %s^0'):format(res, fn, tostring(a))) return nil end
    return a, b
end

-- Joueurs
function B.Cid(src) return ex('elyzea_core', 'GetCitizenId', src) end
function B.Name(src) return ex('elyzea_core', 'GetCharName', src) or GetPlayerName(src) or ('ID ' .. tostring(src)) end
function B.Src(cid) if not cid then return nil end return ex('elyzea_core', 'GetSourceByCitizenId', cid) end
function B.Job(src) local pd = ex('elyzea_core', 'GetPlayerData', src) return type(pd) == 'table' and type(pd.job) == 'table' and pd.job or nil end
function B.Notify(src, text, kind) if src and src > 0 then ex('elyzea_core', 'Notify', src, text, kind or 'inform', 6000, 'BLACKPHONE') end end

-- Inventaire
function B.Count(src, item) return tonumber((ex('elyzea_inventory', 'GetItemCount', src, item))) or 0 end
function B.CanCarry(src, item, n) return ex('elyzea_inventory', 'CanCarryItem', src, item, n) == true end
function B.Add(src, item, n, meta) local ok, why = ex('elyzea_inventory', 'AddItem', src, item, n, meta) return ok == true, why end
function B.Remove(src, item, n, meta, slot) local ok, why = ex('elyzea_inventory', 'RemoveItem', src, item, n, meta, slot) return ok == true, why end
function B.Slots(src, item) local r = ex('elyzea_inventory', 'Search', src, 'slots', item) return type(r) == 'table' and r or {} end
function B.SetMeta(src, slot, meta) return ex('elyzea_inventory', 'SetMetadata', src, slot, meta) == true end
function B.ItemDef(item) local d = ex('elyzea_inventory', 'Items', item) return type(d) == 'table' and d or nil end

-- Argent : 'cash' / 'bank' (comptes elyzea_core) ou 'item' (objet d'argent sale)
local function mItem() return BPS and BPS.S.general.moneyItem or 'black_money' end
function B.GetMoney(src, kind)
    if kind == 'item' then return B.Count(src, mItem()) end
    return tonumber((ex('elyzea_core', 'GetMoney', src, kind))) or 0
end
function B.AddMoney(src, kind, n, reason)
    n = math.floor(tonumber(n) or 0)
    if n <= 0 then return true end
    if kind == 'item' then if not B.CanCarry(src, mItem(), n) then return false end return (B.Add(src, mItem(), n)) end
    return ex('elyzea_core', 'AddMoney', src, kind, n, reason or 'blackphone') == true
end
function B.RemoveMoney(src, kind, n, reason)
    n = math.floor(tonumber(n) or 0)
    if n <= 0 then return true end
    if kind == 'item' then return (B.Remove(src, mItem(), n)) end
    if B.GetMoney(src, kind) < n then return false end
    return ex('elyzea_core', 'RemoveMoney', src, kind, n, reason or 'blackphone') == true
end

-- Police : en service (elyzea_police, sinon métier en service) et niveau de grade
function B.PoliceOnDuty(src)
    if GetResourceState('elyzea_police') == 'started' then return ex('elyzea_police', 'IsOnDuty', src) == true end
    local job = B.Job(src)
    if not job or not job.onduty then return false end
    for _, j in ipairs(BPS.S.police.jobs) do if j == job.name then return true end end
    return false
end
function B.PoliceLevel(src)
    if not B.PoliceOnDuty(src) then return -1 end
    local g = ex('elyzea_police', 'GetGrade', src)
    if type(g) == 'table' and tonumber(g.level) then return tonumber(g.level) end
    local job = B.Job(src)
    return job and job.grade and tonumber(job.grade.level) or 0
end

function B.IsAdmin(src)
    if GetResourceState('admin_menu') == 'started' then
        local r = ex('admin_menu', 'HasPermission', src, 'blackphone_manage')
        if r ~= nil then return r == true end
    end
    return IsPlayerAceAllowed(src, 'blackphone.admin')
end
