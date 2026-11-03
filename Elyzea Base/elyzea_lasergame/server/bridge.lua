-- =====================================================================
--  ELYZEA LASERGAME - ADAPTATEURS DE FRAMEWORK (serveur)
--  Le reste de la ressource ne parle JAMAIS directement au framework : uniquement à Bridge.
--  Pris en charge : elyzea_core (base Elyzea), ESX (es_extended), QBCore (qb-core / qbx_core).
--  L'inventaire RP n'est jamais modifié : il est seulement verrouillé pendant une partie
--  (state bag « pvpArena », déjà respecté par elyzea_inventory) et les armes GTA tenues en main
--  sont retirées / rendues côté client.
-- =====================================================================
Bridge = { name = 'none' }

local function started(res) return GetResourceState(res) == 'started' end

local function detect()
    local want = Config.Framework or 'auto'
    if (want == 'auto' or want == 'elyzea') and started('elyzea_core') then return 'elyzea' end
    if (want == 'auto' or want == 'esx') and started('es_extended') then return 'esx' end
    if (want == 'auto' or want == 'qbcore') and (started('qb-core') or started('qbx_core')) then return 'qbcore' end
    return 'standalone'
end

local ESX, QB

local function trimName(a, b)
    local s = ((a or '') .. ' ' .. (b or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return s
end

-- ---------------------------------------------------------------- elyzea_core
local Elyzea = {}
function Elyzea.identity(src)
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData(src) end)
    if not ok or type(pd) ~= 'table' or not pd.citizenid then return nil end
    local ci = pd.charinfo or {}
    return { cid = pd.citizenid, firstname = ci.firstname or '', lastname = ci.lastname or '' }
end
function Elyzea.getMoney(src, acc)
    local ok, v = pcall(function() return exports.elyzea_core:GetMoney(src, acc) end)
    return ok and tonumber(v) or 0
end
function Elyzea.removeMoney(src, acc, amount, reason)
    local ok, r = pcall(function() return exports.elyzea_core:RemoveMoney(src, acc, amount, reason) end)
    return ok and r == true
end
function Elyzea.addMoney(src, acc, amount, reason)
    local ok, r = pcall(function() return exports.elyzea_core:AddMoney(src, acc, amount, reason) end)
    return ok and r == true
end

-- ---------------------------------------------------------------- ESX
local Esx = {}
local function esxPlayer(src)
    if not ESX then
        local ok, obj = pcall(function() return exports.es_extended:getSharedObject() end)
        ESX = ok and obj or nil
    end
    return ESX and ESX.GetPlayerFromId(src) or nil
end
local function esxAcc(acc) return acc == 'cash' and 'money' or acc end
function Esx.identity(src)
    local x = esxPlayer(src)
    if not x then return nil end
    local fn = x.get and x.get('firstName') or nil
    local ln = x.get and x.get('lastName') or nil
    if not fn and x.getName then
        local full = x.getName() or ''
        fn, ln = full:match('^(%S+)%s*(.*)$')
    end
    return { cid = x.identifier, firstname = fn or '', lastname = ln or '' }
end
function Esx.getMoney(src, acc)
    local x = esxPlayer(src)
    if not x then return 0 end
    local a = x.getAccount(esxAcc(acc))
    return a and tonumber(a.money) or 0
end
function Esx.removeMoney(src, acc, amount, reason)
    local x = esxPlayer(src)
    if not x then return false end
    local before = Esx.getMoney(src, acc)
    if before < amount then return false end
    x.removeAccountMoney(esxAcc(acc), amount, reason)
    return Esx.getMoney(src, acc) == before - amount
end
function Esx.addMoney(src, acc, amount, reason)
    local x = esxPlayer(src)
    if not x then return false end
    x.addAccountMoney(esxAcc(acc), amount, reason)
    return true
end

-- ---------------------------------------------------------------- QBCore / Qbox
local Qb = {}
local function qbPlayer(src)
    if started('qbx_core') then
        local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and p then return p end
    end
    if not QB then
        local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
        QB = ok and obj or nil
    end
    return QB and QB.Functions.GetPlayer(src) or nil
end
function Qb.identity(src)
    local p = qbPlayer(src)
    if not p then return nil end
    local ci = p.PlayerData.charinfo or {}
    return { cid = p.PlayerData.citizenid, firstname = ci.firstname or '', lastname = ci.lastname or '' }
end
function Qb.getMoney(src, acc)
    local p = qbPlayer(src)
    return p and tonumber(p.Functions.GetMoney(acc)) or 0
end
function Qb.removeMoney(src, acc, amount, reason)
    local p = qbPlayer(src)
    return p ~= nil and p.Functions.RemoveMoney(acc, amount, reason) == true
end
function Qb.addMoney(src, acc, amount, reason)
    local p = qbPlayer(src)
    return p ~= nil and p.Functions.AddMoney(acc, amount, reason) ~= false
end

-- ---------------------------------------------------------------- sans framework (tests, serveur nu)
local Standalone = {}
function Standalone.identity(src)
    local lic = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, 'license') or nil
    if not lic then return nil end
    return { cid = lic, firstname = GetPlayerName(src) or 'Joueur', lastname = '' }
end
function Standalone.getMoney() return 0 end
function Standalone.removeMoney() return false end
function Standalone.addMoney() return false end

local impl
local function I()
    if not impl then
        Bridge.name = detect()
        impl = ({ elyzea = Elyzea, esx = Esx, qbcore = Qb, standalone = Standalone })[Bridge.name]
        print(('[elyzea_lasergame] framework détecté : %s'):format(Bridge.name))
    end
    return impl
end

-- ---------------------------------------------------------------- API publique
-- Identité RP du personnage joué : { cid, firstname, lastname, name } ou nil
function Bridge.Identity(src)
    local id = I().identity(src)
    if not id or not id.cid then return nil end
    id.cid = tostring(id.cid)
    id.firstname = tostring(id.firstname or ''):sub(1, 40)
    id.lastname = tostring(id.lastname or ''):sub(1, 40)
    local n = trimName(id.firstname, id.lastname)
    id.name = n ~= '' and n or (GetPlayerName(src) or ('#' .. tostring(src)))
    return id
end

function Bridge.GetMoney(src, acc) return I().getMoney(src, acc or Config.Account) end
function Bridge.RemoveMoney(src, amount, reason, acc)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return I().removeMoney(src, acc or Config.Account, amount, reason or 'LaserGame')
end
function Bridge.AddMoney(src, amount, reason, acc)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return I().addMoney(src, acc or Config.Account, amount, reason or 'LaserGame')
end

-- Joueur connecté qui joue ce personnage (ou nil)
function Bridge.SourceByCid(cid)
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        local id = I().identity(s)
        if id and tostring(id.cid) == tostring(cid) then return s end
    end
    return nil
end

-- Permission staff : c'est admin_menu qui décide (case « LaserGame » dans Staff › Rangs).
-- L'ACE ne sert que si admin_menu n'est pas démarré (serveur sans menu staff).
function Bridge.IsAdmin(src)
    if src == 0 then return true end
    if started('admin_menu') then
        local ok, r = pcall(function() return exports.admin_menu:HasPermission(src, Config.Permission) end)
        return ok and r == true
    end
    return IsPlayerAceAllowed(src, Config.AcePermission) == true
end

-- Journal staff d'admin_menu (en plus des journaux de la ressource)
function Bridge.StaffLog(src, action, details)
    if started('admin_menu') then pcall(function() exports.admin_menu:AddLog(src, action, details) end) end
end

-- Connexion d'un personnage : rappel cb(src)
function Bridge.OnLogin(cb)
    AddEventHandler('elyzea:server:playerLogin', function(src) cb(tonumber(src)) end)
    AddEventHandler('esx:playerLoaded', function(src) cb(tonumber(src)) end)
    AddEventHandler('QBCore:Server:PlayerLoaded', function(p)
        local s = type(p) == 'table' and p.PlayerData and p.PlayerData.source or p
        if s then cb(tonumber(s)) end
    end)
end

function Bridge.Name() I() return Bridge.name end
