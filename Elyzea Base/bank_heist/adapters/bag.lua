-- =====================================================================
--  BANK HEIST - SAC DE BILLETS (serveur), propre à la banque (aucune autre ressource)
--  Un sac = un identifiant + l'argent qu'il contient, enregistré en base (bh_bags).
--  États : 'carried' (porté), 'ground' (posé au sol avec E), 'offline' (porteur déconnecté).
--  Porter, poser ou ramasser déplace le sac, jamais son contenu (aucune copie possible).
--  API utilisée par le butin : Ready, Carried, Create, AddMoney, CashOut, CashOutGround.
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Bag = A
local P = BHS
local CFG = Config.Bag or {}

local bags, carry, lastPos = {}, {}, {}   -- [id] = sac · [src] = id porté · [src] = dernière position
local uid = 0
local function now() return os.time() end
local function newId() uid = uid + 1 return ('BB%d%04d'):format(os.time() % 100000000, uid % 10000) end

local function save(b)
    MySQL.query([[INSERT INTO `bh_bags` (`id`, `owner_cid`, `owner_name`, `holder_cid`, `state`, `x`, `y`, `z`, `money`, `capacity`, `ref`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `holder_cid` = VALUES(`holder_cid`), `state` = VALUES(`state`),
        `x` = VALUES(`x`), `y` = VALUES(`y`), `z` = VALUES(`z`), `money` = VALUES(`money`)]],
        { b.id, b.ownerCid, b.ownerName, b.holderCid, b.state, b.x, b.y, b.z, b.money, b.capacity, b.ref })
end
local function delRow(id) MySQL.query('DELETE FROM `bh_bags` WHERE `id` = ?', { id }) end

local function publish()
    local pub = {}
    for id, b in pairs(bags) do if b.state == 'ground' then pub[id] = { x = b.x, y = b.y, z = b.z } end end
    GlobalState.bhBags = pub
end
local function info(b) return b and { id = b.id, kind = 'bank', money = b.money, capacity = b.capacity } or nil end
local function push(src, b) if src and GetPlayerPing(src) > 0 then TriggerClientEvent('bh:client:bagInfo', src, info(b)) end end

local function setCarry(src, b)
    if b then
        carry[src] = b.id
        b.state, b.holderSrc, b.holderCid = 'carried', src, Adapters.Perms.CitizenId(src)
        Player(src).state:set('bhBag', b.id, true)
    else
        carry[src] = nil
        Player(src).state:set('bhBag', nil, true)
    end
    push(src, b)
end

local function remove(b, why, src)
    bags[b.id] = nil
    if b.holderSrc and carry[b.holderSrc] == b.id then setCarry(b.holderSrc, nil) end
    delRow(b.id)
    P.Log('bag', b.id, src, ('Sac supprimé : %s'):format(why))
    publish()
end

local function toGround(b, x, y, z)
    if b.holderSrc and carry[b.holderSrc] == b.id then setCarry(b.holderSrc, nil) end
    b.state, b.holderSrc, b.holderCid, b.x, b.y, b.z, b.since = 'ground', nil, nil, x + 0.0, y + 0.0, z + 0.0, now()
    save(b)
    publish()
end

local function carried(src) local id = carry[src] return id and bags[id] or nil end
local function near(src, b) return P.Near(src, { x = b.x, y = b.y, z = b.z }, (CFG.pickupDistance or 2.0) + 1.0) end

-- ---------------------------------------------------------------------
-- Base de données et restauration après redémarrage
-- ---------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `bh_bags` (`id` VARCHAR(32) NOT NULL PRIMARY KEY, `owner_cid` VARCHAR(64) NULL, `owner_name` VARCHAR(100) NULL,
        `holder_cid` VARCHAR(64) NULL, `state` VARCHAR(12) NOT NULL, `x` DOUBLE NOT NULL DEFAULT 0, `y` DOUBLE NOT NULL DEFAULT 0, `z` DOUBLE NOT NULL DEFAULT 0,
        `money` INT NOT NULL DEFAULT 0, `capacity` INT NOT NULL DEFAULT 0, `ref` VARCHAR(64) NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)
        DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `bh_bags`') or {}) do
        local b = { id = r.id, ownerCid = r.owner_cid, ownerName = r.owner_name, holderCid = r.holder_cid, state = r.state,
            x = tonumber(r.x) or 0.0, y = tonumber(r.y) or 0.0, z = tonumber(r.z) or 0.0, money = tonumber(r.money) or 0,
            capacity = tonumber(r.capacity) or 0, ref = r.ref, since = now() }
        bags[b.id] = b
        if b.state == 'carried' then b.state = 'offline' end   -- rendu au porteur à sa prochaine connexion
    end
    publish()
end)

-- ---------------------------------------------------------------------
-- API du butin
-- ---------------------------------------------------------------------
function A.Ready() return true end
function A.Carried(src) return info(carried(src)) end

-- Crée un sac porté directement par le joueur (il ne doit pas déjà en porter un)
function A.Create(src, capacity, ref)
    if carry[src] then return nil end
    local pos = P.PedPos(src)
    if not pos then return nil end
    local b = { id = newId(), ownerCid = Adapters.Perms.CitizenId(src), ownerName = Adapters.Perms.Name(src), state = 'carried',
        x = pos.x, y = pos.y, z = pos.z, money = 0, capacity = math.floor(tonumber(capacity) or 0), ref = ref, since = now() }
    bags[b.id] = b
    setCarry(src, b)
    save(b)
    P.Log('bag', b.id, src, 'Sac de billets sorti')
    return b.id
end

-- Ajoute de l'argent dans le sac porté (plafonné). Retourne le montant réellement ajouté.
function A.AddMoney(src, id, amount)
    local b = carried(src)
    amount = math.floor(tonumber(amount) or 0)
    if not b or b.id ~= id or amount <= 0 or not P.Lock('bag:' .. b.id) then return 0 end
    local room = b.capacity > 0 and math.max(0, b.capacity - b.money) or amount
    local add = math.min(amount, room)
    b.money = b.money + add
    save(b)
    P.Unlock('bag:' .. b.id)
    push(src, b)
    return add
end

-- Vide et supprime le sac porté. Retourne le montant, l'id.
function A.CashOut(src)
    local b = carried(src)
    if not b or not P.Lock('bag:' .. b.id) then return 0 end
    local amount, id = b.money, b.id
    remove(b, ('encaissé (%s)'):format(BH.Money(amount)), src)
    P.Unlock('bag:' .. id)
    return amount, id
end

-- Vide et supprime un sac posé au sol, si le joueur est à côté et à pied. Retourne le montant, l'id.
function A.CashOutGround(src, id)
    local b = bags[tostring(id or '')]
    if not b or b.state ~= 'ground' or not near(src, b) or P.InVehicle(src) or not P.Lock('bag:' .. b.id) then return 0 end
    local amount, bid = b.money, b.id
    remove(b, ('vidé sur place (%s)'):format(BH.Money(amount)), src)
    P.Unlock('bag:' .. bid)
    return amount, bid
end

-- ---------------------------------------------------------------------
-- Ramasser (ALT) / poser (E)
-- ---------------------------------------------------------------------
P.Req.bagPickup = function(src, d)
    local b = bags[tostring(d.bag or '')]
    if not b or b.state ~= 'ground' then return { error = 'Ce sac n\'est plus là.' } end
    if carry[src] then return { error = 'Vous portez déjà un sac.' } end
    if not near(src, b) then return { error = 'Trop loin.' } end
    if P.InVehicle(src) then return { error = 'Descendez du véhicule.' } end
    if not P.Lock('bag:' .. b.id) then return { error = 'Patientez un instant.' } end
    setCarry(src, b)
    save(b)
    publish()
    P.Unlock('bag:' .. b.id)
    P.Log('bag', b.id, src, ('Sac ramassé (%s)'):format(BH.Money(b.money)))
    return { ok = true, message = ('Sac ramassé (%s).'):format(BH.Money(b.money)) }
end

P.Req.bagDrop = function(src)
    local b = carried(src)
    if not b then setCarry(src, nil) return { error = 'Vous ne portez pas de sac.' } end
    if P.InVehicle(src) then return { error = 'Descendez du véhicule.' } end
    local pos, h = P.PedPos(src)
    if not pos then return { error = 'Patientez un instant.' } end
    local r = math.rad(h or 0.0)
    toGround(b, pos.x - math.sin(r) * 0.6, pos.y + math.cos(r) * 0.6, pos.z)
    P.Log('bag', b.id, src, ('Sac posé (%.1f, %.1f, %.1f)'):format(b.x, b.y, b.z))
    return { ok = true, message = 'Sac posé au sol.' }
end

-- ---------------------------------------------------------------------
-- Porteurs : position, à terre, déconnexion, reconnexion, nettoyage
-- ---------------------------------------------------------------------
CreateThread(function()
    local tick = 0
    while true do
        Wait(1000)
        tick = tick + 1
        for src, id in pairs(carry) do
            local b = bags[id]
            local pos = P.PedPos(src)
            if not b then setCarry(src, nil)
            elseif pos then
                lastPos[src] = pos
                b.x, b.y, b.z = pos.x, pos.y, pos.z
                if (CFG.onDeath or 'drop') == 'drop' and P.IsDown(src) then
                    toGround(b, pos.x, pos.y, pos.z)
                    P.Log('bag', b.id, src, 'Porteur à terre : sac tombé au sol')
                    P.Notify(src, 'Vous êtes à terre : le sac est tombé.', 'error')
                elseif tick % 15 == 0 then save(b) end
            end
        end
        local cm, ground = CFG.cleanupMinutes or 60, {}
        for _, b in pairs(bags) do
            if b.state == 'ground' then
                if cm > 0 and now() - b.since > cm * 60 then remove(b, ('abandonné depuis %d min (%s perdus)'):format(cm, BH.Money(b.money)))
                else ground[#ground + 1] = b end
            end
        end
        if #ground > (CFG.maxGroundBags or 30) then
            table.sort(ground, function(a, c) return a.since < c.since end)
            for i = 1, #ground - (CFG.maxGroundBags or 30) do remove(ground[i], 'trop de sacs au sol') end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local b = carried(src)
    carry[src] = nil
    if not b then lastPos[src] = nil return end
    local pos = lastPos[src] or vector3(b.x, b.y, b.z)
    lastPos[src] = nil
    if (CFG.onDisconnect or 'keep') == 'keep' and b.holderCid then
        b.state, b.holderSrc, b.x, b.y, b.z = 'offline', nil, pos.x, pos.y, pos.z
        save(b)
    else
        b.holderSrc = nil
        toGround(b, pos.x, pos.y, pos.z)
    end
end)

local function giveBack(src)
    local cid = Adapters.Perms.CitizenId(src)
    if not cid or carry[src] then return end
    for _, b in pairs(bags) do
        if b.state == 'offline' and b.holderCid == cid then
            setCarry(src, b)
            save(b)
            P.Log('bag', b.id, src, 'Sac rendu à la reconnexion')
            return
        end
    end
end
AddEventHandler('elyzea:server:playerLoaded', function(src) giveBack(src) end)
CreateThread(function()   -- redémarrage de la ressource : joueurs déjà en ville
    Wait(3000)
    for _, s in ipairs(GetPlayers()) do giveBack(tonumber(s)) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src, id in pairs(carry) do
        local b = bags[id]
        if b then local pos = P.PedPos(src) if pos then b.x, b.y, b.z = pos.x, pos.y, pos.z end save(b) end
        Player(src).state:set('bhBag', nil, true)
    end
end)
