-- =====================================================================
--  ELYZEA LASERGAME - MODE ZOMBIE (serveur, 1 à 4 joueurs)
--  Le serveur décide de TOUT : apparition des zombies (entités serveur dans l'instance),
--  points de vie des zombies, attaques au corps à corps et crachats d'acide (distances
--  calculées avec les positions serveur), vie des joueurs, mise à terre, réanimation,
--  argent Zombie (jamais converti en argent RP), portes, armes murales, atouts, manches.
--  Les clients ne font que l'animation (déplacement des zombies qu'ils contrôlent, effets).
-- =====================================================================
Zombie = {}

local Z = function() return LG.Zombie end
local GLOBAL_MAX_ALIVE = 70       -- zombies présents en même temps sur tout le serveur (toutes parties)
local ZS = LG.ZState

local function rand() return math.random() end

local function now() return GetGameTimer() end

local function connected(g)
    local n = 0
    for _ in pairs(g.players) do n = n + 1 end
    return n
end

local function globalAlive()
    local n = 0
    for _, g in pairs(Games.list) do if g.mode == 'zombie' then n = n + (g.alive or 0) end end
    return n
end

local function pedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

-- ---------------------------------------------------------------- vues
local function playersView(g)
    local out = {}
    for _, s in ipairs(Games.PlayerList(g)) do
        local p = g.players[s]
        local perks = {}
        for id in pairs(p.perks) do perks[#perks + 1] = id end
        table.sort(perks)
        out[#out + 1] = { id = s, name = p.name, state = p.state, hp = math.floor(p.hp), maxHp = p.maxHp, money = p.money,
            kills = p.kills, downs = p.downs, revives = p.revives, perks = perks, ready = p.ready, host = s == g.host }
    end
    return out
end

local function lobbyView(g, viewer)
    local m = Maps.Get(g.map)
    return { uid = g.uid, mode = 'zombie', name = g.name, host = g.hostName, isHost = viewer == g.host, private = g.private,
        hasPassword = g.password ~= nil, map = g.map, mapLabel = m and m.label or g.map, phase = g.phase, max = Z().maxPlayers,
        players = playersView(g) }
end

local function publicView(g)
    local m = Maps.Get(g.map)
    local spectators = 0
    for _ in pairs(g.spectators) do spectators = spectators + 1 end
    local roster = {}
    for _, s in ipairs(Games.PlayerList(g)) do roster[#roster + 1] = { name = g.players[s].name, state = g.players[s].state } end
    return { uid = g.uid, mode = 'zombie', name = g.name, host = g.hostName, private = g.private, hasPassword = g.password ~= nil,
        map = g.map, mapLabel = m and m.label or g.map, players = connected(g), max = Z().maxPlayers, phase = g.phase,
        round = g.round or 0, roster = roster, spectators = spectators, createdAt = g.createdAt }
end

function Zombie.SendState(g)
    local remaining = (g.toSpawn or 0) + (g.alive or 0)
    local doors = {}
    for id in pairs(g.opened or {}) do doors[#doors + 1] = id end
    Games.Send(g, 'zbState', { round = g.round, phase = g.phase, alive = g.alive or 0, remaining = remaining,
        players = playersView(g), doors = doors, endsAt = g.intermissionEndsAt })
end

-- ---------------------------------------------------------------- lobby
local function newPlayer(g, src, id)
    return Lobby.Add(g, src, id, { state = ZS.ALIVE, hp = Z().player.health, maxHp = Z().player.health, money = Z().money.startMoney,
        perks = {}, weapons = { LG.ZombieStartWeapon }, current = LG.ZombieStartWeapon, kills = 0, downs = 0, revives = 0,
        moneyEarned = 0, lastHit = 0 })
end

RPC.Register('zb:create', function(src, opts)
    if not Z().enabled then return false, 'Le mode Zombie est désactivé.' end
    local can, id = Games.CanJoin(src)
    if not can then return false, id end
    local lobbies = Games.Count()
    if lobbies >= Config.MaxParallelGames * 2 then return false, 'Trop de lobbies ouverts, réessaie plus tard.' end
    opts = type(opts) == 'table' and opts or {}
    local ok, m = Maps.Usable('zombie_map', 'zombie')
    if not ok then return false, m end
    local name = LGU.CleanText(opts.name, Config.PvP.matchNameMaxLength)
    if name == '' then name = ('Survie de %s'):format(id.firstname ~= '' and id.firstname or id.name) end
    local pw = LGU.CleanText(opts.password, Config.PvP.passwordMaxLength)
    local g = Lobby.New(LG.Mode.ZOMBIE, src, id, { name = name, private = opts.private == true, password = pw ~= '' and pw or nil, map = m.id })
    newPlayer(g, src, id)
    Logs.Add('zombie', ('lobby créé « %s »'):format(name), { uid = g.uid }, src)
    Lobby.Push(g)
    -- partie solo immédiate
    if opts.solo then g.players[src].ready = true return Zombie.Start(g, src) end
    return true, g.uid
end)

RPC.Register('zb:join', function(src, uid, password)
    local g = Games.list[tostring(uid or '')]
    if not g or g.mode ~= 'zombie' then return false, 'Partie introuvable.' end
    if g.phase ~= LG.Phase.LOBBY then return false, 'La partie a déjà commencé.' end
    local can, id = Games.CanJoin(src)
    if not can then return false, id end
    local ok, err = Lobby.CheckAccess(g, id, password)
    if not ok then return false, err end
    if connected(g) >= Z().maxPlayers then return false, 'Le groupe est complet (4 joueurs).' end
    g.invites[id.cid] = nil
    newPlayer(g, src, id)
    Lobby.Push(g)
    return true, g.uid
end)

RPC.Register('zb:ready', function(src, ready)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    g.players[src].ready = ready == true
    g.lastActivity = os.time()
    Lobby.Push(g)
    return true
end)

RPC.Register('zb:kick', function(src, target)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    if g.host ~= src then return false, 'Seul l\'hôte peut expulser.' end
    target = tonumber(target)
    if not target or target == src or not g.players[target] then return false, 'Joueur introuvable.' end
    Zombie.LeaveLobby(g, target, 'expulsé')
    Games.Notify(target, 'Tu as été expulsé du groupe.', 'error')
    return true
end)

RPC.Register('zb:invite', function(src, target)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    if connected(g) >= Z().maxPlayers then return false, 'Le groupe est complet.' end
    return Lobby.Invite(g, src, target)
end)

RPC.Register('zb:start', function(src)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' or g.phase ~= LG.Phase.LOBBY then return false, 'Aucun lobby.' end
    if g.host ~= src then return false, 'Seul l\'hôte peut lancer la partie.' end
    return Zombie.Start(g, src)
end)

function Zombie.Start(g, src)
    if not Z().enabled then return false, 'Le mode Zombie est désactivé.' end
    if connected(g) < Z().minPlayers then return false, 'Pas assez de joueurs.' end
    for _, p in pairs(g.players) do if not p.ready then return false, ('%s n\'est pas prêt.'):format(p.name) end end
    local slot = Games.AllocSlot()
    if not slot then return false, 'Toutes les instances sont occupées, réessaie dans un instant.' end
    g.slot, g.bucket = slot, Games.Bucket(slot)
    g.phase = LG.Phase.LOADING
    Lobby.PushList()
    CreateThread(function()
        local ok, err = pcall(Zombie.Run, g)
        if not ok then
            Logs.Error(('partie Zombie %s : %s'):format(g.uid, tostring(err)))
            Zombie.Finish(g, 'erreur interne')
        end
    end)
    return true, g.uid
end

function Zombie.LeaveLobby(g, src, reason)
    Lobby.Remove(g, src)
    TriggerClientEvent('elyzea_lasergame:lobbyClosed', src, g.uid, reason)
    if connected(g) == 0 then return Zombie.Cancel(g, 'lobby vide') end
    Lobby.Push(g)
end

function Zombie.Cancel(g, reason)
    if g.closed then return end
    for _, s in ipairs(Games.PlayerList(g)) do TriggerClientEvent('elyzea_lasergame:lobbyClosed', s, g.uid, reason) end
    if g.phase ~= LG.Phase.LOBBY then
        Zombie.ClearZombies(g)
        for _, s in ipairs(Games.Members(g)) do Games.ExitInstance(g, s, true) end
    end
    Games.Close(g)
    Lobby.PushList()
end

-- ---------------------------------------------------------------- entités zombies
function Zombie.ClearZombies(g)
    for net, z in pairs(g.zombies or {}) do
        if z.ent and DoesEntityExist(z.ent) then DeleteEntity(z.ent) end
        g.zombies[net] = nil
    end
    g.alive = 0
end

local function sectorSpawns(g, m)
    local list = {}
    for _, s in ipairs(m.sectors or {}) do
        if g.sectorsOpen[s.id] then
            for _, p in ipairs(s.zspawns or {}) do list[#list + 1] = p end
        end
    end
    return list
end

local function pickSpawn(g, m)
    local cands = sectorSpawns(g, m)
    if #cands == 0 then return nil end
    local alivePos = {}
    for s, p in pairs(g.players) do
        if p.state ~= ZS.DEAD then local pp = pedPos(s) if pp then alivePos[#alivePos + 1] = pp end end
    end
    local good, ok = {}, {}
    for _, lp in ipairs(cands) do
        local w = Maps.World(m, lp)
        local nearest = math.huge
        for _, pp in ipairs(alivePos) do nearest = math.min(nearest, LGU.Dist2D(w, pp)) end
        if nearest >= 10 and nearest <= 45 then good[#good + 1] = w elseif nearest >= 8 then ok[#ok + 1] = w end
    end
    local pool = #good > 0 and good or ok
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

local function spawnZombie(g, m)
    local w = pickSpawn(g, m)
    if not w then return false end
    local typeId = LGU.PickZombieType(g.round, rand(), g.aliveByType)
    local t = Z().types[typeId]
    local model = t.models[math.random(#t.models)]
    local ent = CreatePed(4, GetHashKey(model), w.x, w.y, w.z + 0.8, math.random(0, 359) + 0.0, true, true)
    local deadline = now() + 2500
    while not DoesEntityExist(ent) and now() < deadline do Wait(10) end
    if not DoesEntityExist(ent) then return false end
    SetEntityRoutingBucket(ent, g.bucket)
    if SetEntityOrphanMode then SetEntityOrphanMode(ent, 2) end
    local net = NetworkGetNetworkIdFromEntity(ent)
    local gait = LGU.ZombieGait(g.round, rand())
    local hp = math.floor(LGU.ZombieHealth(g.round) * t.hp)
    local z = { ent = ent, net = net, type = typeId, hp = hp, maxHp = hp, gait = gait, speed = t.speed,
        damage = LGU.ZombieDamage(g.round) * t.damage, nextAttack = now() + 1500, nextSpit = now() + 3000,
        movedAt = now(), lastPos = w, born = now() }
    g.zombies[net] = z
    g.alive = g.alive + 1
    g.aliveByType[typeId] = (g.aliveByType[typeId] or 0) + 1
    Entity(ent).state:set('lgZombie', { uid = g.uid, t = typeId, g = gait, s = t.speed }, true)
    Games.Send(g, 'zbSpawn', { net = net, t = typeId, g = gait, s = t.speed })
    return true
end

local function removeZombie(g, net, requeue)
    local z = g.zombies[net]
    if not z then return end
    g.zombies[net] = nil
    g.alive = math.max(0, g.alive - 1)
    g.aliveByType[z.type] = math.max(0, (g.aliveByType[z.type] or 1) - 1)
    if requeue then g.toSpawn = g.toSpawn + 1 end
    local ent = z.ent
    SetTimeout(requeue and 0 or 2500, function() if DoesEntityExist(ent) then DeleteEntity(ent) end end)
end

-- ---------------------------------------------------------------- joueurs : dégâts, mise à terre, réanimation
local function perkVal(p, perk, key, default)
    if p.perks[perk] then return Z().perks[perk][key] or default end
    return default
end

local function allDown(g)
    for _, p in pairs(g.players) do
        if p.state == ZS.ALIVE or p.selfRevive then return false end
    end
    return true
end

local function goDown(g, src, p)
    p.state = ZS.DOWN
    p.hp = 0
    p.downs = p.downs + 1
    p.bleedUntil = now() + Z().player.bleedout * 1000
    -- solo avec Réanimation rapide : relevé automatiquement après 5 s (l'atout est consommé)
    if connected(g) == 1 and p.perks.quickrevive then p.selfRevive = now() + 5000 end
    TriggerClientEvent('elyzea_lasergame:zbDowned', src, { bleedout = Z().player.bleedout, selfRevive = p.selfRevive ~= nil })
    Games.Send(g, 'zbFeed', { kind = 'down', name = p.name, id = src })
    Zombie.SendState(g)
end

local function hurt(g, src, p, dmg, kind)
    if p.state ~= ZS.ALIVE then return end
    if kind == 'acid' then dmg = dmg * perkVal(p, 'acidres', 'acidMultiplier', 1) end
    dmg = dmg * perkVal(p, 'armor', 'damageTaken', 1)
    p.hp = p.hp - dmg
    p.lastHit = now()
    if p.hp <= 0 then return goDown(g, src, p) end
    TriggerClientEvent('elyzea_lasergame:zbHurt', src, { hp = math.floor(p.hp), maxHp = p.maxHp, kind = kind })
end
Zombie.Hurt = hurt

local function revive(g, src, p, by)
    p.state = ZS.ALIVE
    p.hp = p.maxHp
    p.bleedUntil, p.selfRevive = nil, nil
    g.revives[src] = nil
    TriggerClientEvent('elyzea_lasergame:zbRevived', src, { hp = p.hp, maxHp = p.maxHp })
    if by and g.players[by] then
        local r = g.players[by]
        r.revives = r.revives + 1
        r.money = r.money + Z().money.reviveBonus
        r.moneyEarned = r.moneyEarned + Z().money.reviveBonus
        TriggerClientEvent('elyzea_lasergame:zbMoney', by, { money = r.money, delta = Z().money.reviveBonus })
    end
    Games.Send(g, 'zbFeed', { kind = 'revive', name = p.name, by = by and g.players[by] and g.players[by].name or nil })
    Zombie.SendState(g)
end

local function die(g, src, p)
    p.state = ZS.DEAD
    p.hp = 0
    p.bleedUntil, p.selfRevive = nil, nil
    g.revives[src] = nil
    -- mort : perd ses atouts et ses armes achetées (revient avec le pistolet à la manche suivante)
    if not Z().player.keepPerksOnRespawn then p.perks = {} end
    p.weapons, p.current, p.ammo, p.reloadUntil = { LG.ZombieStartWeapon }, LG.ZombieStartWeapon, {}, {}
    p.maxHp = Z().player.health
    TriggerClientEvent('elyzea_lasergame:zbDead', src, {})
    Games.Send(g, 'zbFeed', { kind = 'dead', name = p.name, id = src })
    Zombie.SendState(g)
end

RPC.Register('zb:reviveStart', function(src, target)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' then return false end
    local p, t = g.players[src], g.players[tonumber(target) or -1]
    if not p or p.state ~= ZS.ALIVE or not t or t.state ~= ZS.DOWN then return false, 'Personne à réanimer.' end
    if g.revives[target] and g.revives[target].by ~= src then return false, 'Quelqu\'un le réanime déjà.' end
    local a, b = pedPos(src), pedPos(target)
    if not a or not b or LGU.Dist(a, b) > Z().player.reviveRange + 0.5 then return false, 'Trop loin.' end
    local dur = Z().player.reviveTime * perkVal(p, 'quickrevive', 'reviveMultiplier', 1)
    g.revives[target] = { by = src, endsAt = now() + math.floor(dur * 1000) }
    TriggerClientEvent('elyzea_lasergame:zbReviving', target, { by = p.name, duration = dur })
    return true, dur
end)

RPC.Register('zb:reviveStop', function(src)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' then return true end
    for target, r in pairs(g.revives) do
        if r.by == src then g.revives[target] = nil TriggerClientEvent('elyzea_lasergame:zbReviving', target, false) end
    end
    return true
end)

-- ---------------------------------------------------------------- achats
local function near(src, m, lp, dist)
    local pos = pedPos(src)
    if not pos then return false end
    local w = Maps.World(m, lp)
    return LGU.Dist(pos, w) <= dist
end

local function spend(src, p, price)
    if p.money < price then return false end
    p.money = p.money - price
    TriggerClientEvent('elyzea_lasergame:zbMoney', src, { money = p.money, delta = -price })
    return true
end

local function findById(list, id)
    for _, v in ipairs(list or {}) do if v.id == id then return v end end
end

RPC.Register('zb:door', function(src, doorId)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' or (g.phase ~= LG.Phase.ROUND and g.phase ~= LG.Phase.INTERMISSION) then return false end
    return Security.Locked(src, 'zb:door', function()
        local p = g.players[src]
        local m = Maps.Get(g.map)
        local d = findById(m.doors, tostring(doorId or ''))
        if not p or not d or p.state ~= ZS.ALIVE then return false, 'Impossible.' end
        if g.opened[d.id] then return false, 'Déjà ouverte.' end
        if not near(src, m, d, 4.0) then Security.Suspicious(src, 'achat de porte à distance', { door = d.id }) return false, 'Trop loin.' end
        local price = Settings.DoorPrice(d)
        if not spend(src, p, price) then return false, ('Il faut %d $ Zombie.'):format(price) end
        g.opened[d.id] = true
        g.sectorsOpen[d.a] = true
        g.sectorsOpen[d.b] = true
        Games.Send(g, 'zbDoor', { id = d.id, by = p.name })
        Logs.Add('zombie', ('porte « %s » ouverte (%d $ Zombie)'):format(d.label or d.id, price), { uid = g.uid }, src)
        Zombie.SendState(g)
        return true
    end)
end)

RPC.Register('zb:wallbuy', function(src, wbId)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' or (g.phase ~= LG.Phase.ROUND and g.phase ~= LG.Phase.INTERMISSION) then return false end
    return Security.Locked(src, 'zb:wallbuy', function()
        local p = g.players[src]
        local m = Maps.Get(g.map)
        local wb = findById(m.wallbuys, tostring(wbId or ''))
        if not p or not wb or p.state ~= ZS.ALIVE then return false, 'Impossible.' end
        if wb.sector and not g.sectorsOpen[wb.sector] then return false, 'Salle fermée.' end
        if not near(src, m, wb, 3.5) then Security.Suspicious(src, 'achat d\'arme à distance', { wb = wb.id }) return false, 'Trop loin.' end
        local wid = Settings.WallbuyWeapon(wb)
        local w = LGU.Weapon(wid)
        if not w or w.disabled then return false, 'Arme indisponible.' end
        for _, x in ipairs(p.weapons) do if x == wid then return false, 'Tu as déjà cette arme.' end end
        local price = Settings.WallbuyPrice(wb)
        if not spend(src, p, price) then return false, ('Il faut %d $ Zombie.'):format(price) end
        if #p.weapons < 2 then p.weapons[#p.weapons + 1] = wid
        else
            for i, x in ipairs(p.weapons) do if x == p.current then p.weapons[i] = wid break end end
        end
        p.current = wid
        p.ammo = p.ammo or {}
        p.ammo[wid] = nil
        TriggerClientEvent('elyzea_lasergame:zbWeapons', src, { weapons = p.weapons, current = p.current })
        Logs.Add('zombie', ('achète %s (%d $ Zombie)'):format(w.label, price), { uid = g.uid }, src)
        return true
    end)
end)

RPC.Register('zb:perk', function(src, machineId)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' or (g.phase ~= LG.Phase.ROUND and g.phase ~= LG.Phase.INTERMISSION) then return false end
    return Security.Locked(src, 'zb:perk', function()
        local p = g.players[src]
        local m = Maps.Get(g.map)
        local mc = findById(m.perks, tostring(machineId or ''))
        if not p or not mc or p.state ~= ZS.ALIVE then return false, 'Impossible.' end
        if mc.sector and not g.sectorsOpen[mc.sector] then return false, 'Salle fermée.' end
        if not near(src, m, mc, 3.5) then Security.Suspicious(src, 'achat d\'atout à distance', { perk = mc.perk }) return false, 'Trop loin.' end
        local def = Z().perks[mc.perk]
        if not def or def.disabled then return false, 'Atout indisponible.' end
        if p.perks[mc.perk] then return false, 'Tu as déjà cet atout.' end
        local count = 0
        for _ in pairs(p.perks) do count = count + 1 end
        if count >= Z().maxPerks then return false, ('Maximum %d atouts.'):format(Z().maxPerks) end
        if not spend(src, p, def.price) then return false, ('Il faut %d $ Zombie.'):format(def.price) end
        p.perks[mc.perk] = true
        if def.health then p.maxHp = def.health p.hp = def.health end
        local list = {}
        for id in pairs(p.perks) do list[#list + 1] = id end
        TriggerClientEvent('elyzea_lasergame:zbPerks', src, { perks = list, hp = math.floor(p.hp), maxHp = p.maxHp, bought = mc.perk })
        Logs.Add('zombie', ('achète l\'atout %s (%d $ Zombie)'):format(def.label, def.price), { uid = g.uid }, src)
        Zombie.SendState(g)
        return true
    end)
end)

RPC.Register('zb:switch', function(src, idx)
    local g = Games.ByPlayer(src)
    if not g or g.mode ~= 'zombie' then return false end
    local p = g.players[src]
    local wid = p and p.weapons[tonumber(idx) or 0]
    if not wid then return false end
    p.current = wid
    return true, wid
end)

-- ---------------------------------------------------------------- combat (tirs sur les zombies)
Combat.Register(LG.Mode.ZOMBIE, {
    owns = function(g, p, wid)
        for _, x in ipairs(p.weapons) do if x == wid then return true end end
        return false
    end,
    canShoot = function(g, p) return p.state == ZS.ALIVE and (g.phase == LG.Phase.ROUND or g.phase == LG.Phase.INTERMISSION) end,
    reloadMult = function(g, p) return perkVal(p, 'fastreload', 'reloadMultiplier', 1) end,
    apply = function(g, src, p, w, shot)
        if shot.hit.k ~= 'z' then return end
        local net = tonumber(shot.hit.id)
        local z = net and g.zombies[net]
        if not z or z.hp <= 0 then return end
        if not DoesEntityExist(z.ent) then return end
        local c = GetEntityCoords(z.ent)
        local ok, why = Combat.CheckHit(shot.o, shot.d, shot.hp, { x = c.x, y = c.y, z = c.z }, w.range)
        if not ok then
            p.badHits = (p.badHits or 0) + 1
            if p.badHits % 15 == 0 then Security.Suspicious(src, 'impacts Zombie invalides (' .. why .. ')', { n = p.badHits }) end
            return
        end
        local dmg = w.zDamage * perkVal(p, 'doubledmg', 'damageMultiplier', 1)
        z.hp = z.hp - dmg
        local gain = Z().money.hit
        if z.hp <= 0 then
            local t = Z().types[z.type]
            gain = gain + (t.reward or 0) + (w.cat == 'melee' and Z().money.meleeKillBonus or 0)
            p.kills = p.kills + 1
            g.kills = (g.kills or 0) + 1
            Games.Send(g, 'zbDie', { net = net, by = src })
            removeZombie(g, net, false)
        end
        p.money = p.money + gain
        p.moneyEarned = p.moneyEarned + gain
        TriggerClientEvent('elyzea_lasergame:zbMoney', src, { money = p.money, delta = gain, hit = true, kill = z.hp <= 0 })
    end,
})

-- ---------------------------------------------------------------- boucle de partie
local function startRound(g, m)
    g.round = g.round + 1
    local players = connected(g)
    g.toSpawn = LGU.ZombieCount(g.round, players)
    g.nextSpawn = now() + 1500
    g.phase = LG.Phase.ROUND
    g.intermissionEndsAt = nil
    -- les joueurs morts reviennent dans la salle de départ (ou une salle ouverte) avec le pistolet
    local spawns = m.start and m.start.spawns or {}
    local i = 0
    for s, p in pairs(g.players) do
        if p.state == ZS.DEAD then
            i = i + 1
            p.state, p.hp = ZS.ALIVE, p.maxHp
            local lp = spawns[((i - 1) % math.max(1, #spawns)) + 1]
            TriggerClientEvent('elyzea_lasergame:zbRespawn', s, { pos = Maps.World(m, lp), hp = p.hp, maxHp = p.maxHp,
                weapons = p.weapons, current = p.current, perks = {} })
        end
    end
    Games.Send(g, 'zbRound', { round = g.round, count = g.toSpawn })
    Zombie.SendState(g)
end

local function tickZombies(g, m, t, dt)
    local alivePlayers = {}
    for s, p in pairs(g.players) do
        if p.state == ZS.ALIVE then
            local pos = pedPos(s)
            if pos then alivePlayers[#alivePlayers + 1] = { s = s, p = p, pos = pos } end
        end
    end
    for net, z in pairs(g.zombies) do
        if not DoesEntityExist(z.ent) then
            removeZombie(g, net, true)
        else
            local c = GetEntityCoords(z.ent)
            local zp = { x = c.x, y = c.y, z = c.z }
            -- coincé ou sorti de la carte : réapparaît ailleurs
            if LGU.Dist(zp, z.lastPos) > 1.5 then z.lastPos, z.movedAt = zp, t end
            local inside = Maps.InBounds(m, zp)
            local best, bestD
            for _, ap in ipairs(alivePlayers) do
                local d = LGU.Dist(zp, ap.pos)
                if not bestD or d < bestD then best, bestD = ap, d end
            end
            if not inside or (t - z.movedAt > 25000 and (not bestD or bestD > 12)) then
                removeZombie(g, net, true)
            elseif best then
                local typ = Z().types[z.type]
                -- corps à corps : distance serveur + écart de hauteur limité
                if bestD <= (typ.range or 1.6) + 0.35 and math.abs(zp.z - best.pos.z) < 1.8 and t >= z.nextAttack then
                    z.nextAttack = t + (typ.cooldown or 1300)
                    Games.Send(g, 'zbAttack', { net = net, target = best.s })
                    hurt(g, best.s, best.p, z.damage, 'melee')
                end
                -- cracheur d'acide : tir en cloche vers la position du joueur, flaque au sol
                local acid = typ.acid
                if acid and t >= z.nextSpit and bestD >= acid.minRange and bestD <= acid.maxRange then
                    z.nextSpit = t + acid.cooldown
                    local landAt = t + acid.windup + acid.flight
                    Games.Send(g, 'zbSpit', { net = net, to = best.pos, windup = acid.windup, flight = acid.flight, radius = acid.radius, duration = acid.duration })
                    g.puddles[#g.puddles + 1] = { x = best.pos.x, y = best.pos.y, z = best.pos.z, r = acid.radius, from = landAt,
                        to = landAt + acid.duration, dmg = acid.tickDamage, tick = acid.tick, next = landAt }
                end
            end
        end
    end
    -- flaques d'acide : dégâts par intervalle aux joueurs à l'intérieur
    for i = #g.puddles, 1, -1 do
        local pd = g.puddles[i]
        if t > pd.to then table.remove(g.puddles, i)
        elseif t >= pd.from and t >= pd.next then
            pd.next = t + pd.tick
            for _, ap in ipairs(alivePlayers) do
                if LGU.Dist2D(ap.pos, pd) <= pd.r and math.abs(ap.pos.z - pd.z) < 2.0 then hurt(g, ap.s, ap.p, pd.dmg, 'acid') end
            end
        end
    end
end

local function tickPlayers(g, m, t, dt)
    for s, p in pairs(g.players) do
        if p.state == ZS.ALIVE then
            -- régénération après un délai sans coup
            local regenMult = perkVal(p, 'regen', 'regenMultiplier', 1)
            if p.hp < p.maxHp and t - p.lastHit >= Z().player.regenDelay / regenMult then
                local before = math.floor(p.hp)
                p.hp = math.min(p.maxHp, p.hp + Z().player.regenPerSecond * regenMult * dt / 1000)
                if math.floor(p.hp) ~= before and (math.floor(p.hp) % 10 == 0 or p.hp >= p.maxHp) then
                    TriggerClientEvent('elyzea_lasergame:zbHurt', s, { hp = math.floor(p.hp), maxHp = p.maxHp, regen = true })
                end
            end
        elseif p.state == ZS.DOWN then
            if p.selfRevive and t >= p.selfRevive then
                p.perks.quickrevive = nil
                revive(g, s, p, nil)
            elseif p.bleedUntil and t >= p.bleedUntil and not g.revives[s] then
                die(g, s, p)
            end
        end
    end
    -- réanimations en cours : le serveur vérifie la distance jusqu'au bout
    for target, r in pairs(g.revives) do
        local tp, rp = g.players[target], g.players[r.by]
        if not tp or tp.state ~= ZS.DOWN or not rp or rp.state ~= ZS.ALIVE then
            g.revives[target] = nil
            if tp then TriggerClientEvent('elyzea_lasergame:zbReviving', target, false) end
        else
            local a, b = pedPos(target), pedPos(r.by)
            if not a or not b or LGU.Dist(a, b) > Z().player.reviveRange + 1.0 then
                g.revives[target] = nil
                TriggerClientEvent('elyzea_lasergame:zbReviving', target, false)
                TriggerClientEvent('elyzea_lasergame:notify', r.by, 'Réanimation interrompue (trop loin).', 'error')
            elseif t >= r.endsAt then
                revive(g, target, tp, r.by)
            end
        end
    end
end

-- Salles fermées et limites : un joueur ne peut pas entrer dans un secteur non acheté
local function tickZones(g, m)
    for s, p in pairs(g.players) do
        if p.state ~= ZS.DEAD then
            local pos = pedPos(s)
            if pos then
                local inside, l = Maps.InBounds(m, pos)
                local sector = Maps.SectorAt(m, l)
                if inside and (not sector or g.sectorsOpen[sector]) then
                    p.lastValid = pos
                else
                    p.exits = (p.exits or 0) + 1
                    TriggerClientEvent('elyzea_lasergame:pushBack', s, p.lastValid or Maps.World(m, m.start.spawns[1]))
                    if p.exits % 8 == 0 then Security.Suspicious(s, 'entrée dans une salle fermée / hors zone', { sector = sector }) end
                end
            end
        end
    end
end

function Zombie.Run(g)
    local m = Maps.Get(g.map)
    SetRoutingBucketPopulationEnabled(g.bucket, false)
    SetRoutingBucketEntityLockdownMode(g.bucket, 'strict')
    g.startedAt = os.time()
    g.round, g.kills = 0, 0
    g.zombies, g.alive, g.aliveByType, g.toSpawn = {}, 0, {}, 0
    g.opened, g.sectorsOpen, g.puddles, g.revives, g.leavers = {}, {}, {}, {}, {}
    for _, s in ipairs(m.sectors or {}) do if s.open then g.sectorsOpen[s.id] = true end end
    MySQL.insert.await('INSERT INTO `lg_matches` (`uid`, `mode`, `name`, `map`, `status`) VALUES (?, \'zombie\', ?, ?, \'running\')', { g.uid, g.name, g.map })
    local spawns = m.start.spawns
    local i = 0
    for _, s in ipairs(Games.PlayerList(g)) do
        local p = g.players[s]
        if not Games.EnterInstance(g, s, 'player') then
            Lobby.Remove(g, s)
        else
            i = i + 1
            local pos = Maps.World(m, spawns[((i - 1) % #spawns) + 1])
            p.lastValid = pos
            TriggerClientEvent('elyzea_lasergame:enterGame', s, {
                uid = g.uid, mode = 'zombie', role = 'player', map = Maps.ClientInfo(m), name = g.name, spawn = pos,
                weapons = p.weapons, current = p.current, hp = p.hp, maxHp = p.maxHp, money = p.money, team = 'Z',
            })
        end
    end
    if connected(g) == 0 then return Zombie.Cancel(g, 'aucun joueur') end
    Logs.Add('zombie', ('partie %s lancée (%d joueur(s))'):format(g.uid, connected(g)))
    g.phase = LG.Phase.INTERMISSION
    g.intermissionEndsAt = os.time() + Z().rounds.firstDelay
    Zombie.SendState(g)
    Wait(Z().rounds.firstDelay * 1000)
    if g.closed then return end
    startRound(g, m)

    local last, lastZone, lastState = now(), 0, 0
    while not g.closed and not g.finished do
        Wait(250)
        local t = now()
        local dt = t - last
        last = t
        if connected(g) == 0 then return Zombie.Finish(g, 'abandon') end
        if g.phase == LG.Phase.ROUND then
            -- apparitions (limite par partie et globale)
            if g.toSpawn > 0 and t >= g.nextSpawn and g.alive < Z().rounds.maxAlive and globalAlive() < GLOBAL_MAX_ALIVE then
                g.nextSpawn = t + Z().rounds.spawnInterval
                g.toSpawn = g.toSpawn - 1
                if not spawnZombie(g, m) then g.toSpawn = g.toSpawn + 1 g.nextSpawn = t + 2000 end
            end
            -- fin de manche
            if g.toSpawn <= 0 and g.alive <= 0 then
                g.phase = LG.Phase.INTERMISSION
                g.intermissionEndsAt = os.time() + Z().rounds.intermission
                g.puddles = {}
                for s, p in pairs(g.players) do
                    if p.state == ZS.ALIVE and Z().money.roundBonus > 0 then
                        p.money = p.money + Z().money.roundBonus
                        p.moneyEarned = p.moneyEarned + Z().money.roundBonus
                        TriggerClientEvent('elyzea_lasergame:zbMoney', s, { money = p.money, delta = Z().money.roundBonus })
                    end
                end
                Games.Send(g, 'zbRoundEnd', { round = g.round, next = Z().rounds.intermission })
                Zombie.SendState(g)
            end
        elseif g.phase == LG.Phase.INTERMISSION and g.intermissionEndsAt and os.time() >= g.intermissionEndsAt then
            if g.round >= Z().rounds.maxRound then return Zombie.Finish(g, 'maximum') end
            startRound(g, m)
        end
        tickZombies(g, m, t, dt)
        tickPlayers(g, m, t, dt)
        if allDown(g) then return Zombie.Finish(g, 'défaite') end
        if t - lastZone >= 1000 then lastZone = t tickZones(g, m) end
        if t - lastState >= 2000 then lastState = t Zombie.SendState(g) end
    end
end

-- ---------------------------------------------------------------- fin de partie
function Zombie.Finish(g, why)
    if g.closed or g.finished then return end
    g.finished = true
    g.phase = LG.Phase.ENDED
    Zombie.ClearZombies(g)
    local list = {}
    for _, s in ipairs(Games.PlayerList(g)) do
        local p = g.players[s]
        list[#list + 1] = { cid = p.cid, name = p.name, kills = p.kills, money = p.moneyEarned, downs = p.downs, revives = p.revives }
    end
    for _, l in ipairs(g.leavers or {}) do list[#list + 1] = l end
    local duration = os.time() - (g.startedAt or os.time())
    local round = g.round or 0
    if #list > 0 and round > 0 then
        local ok, err = pcall(Ranking.ApplyZombie, g, list, round, duration)
        if not ok then Logs.Error('classement Zombie : ' .. tostring(err)) end
    end
    MySQL.update('UPDATE `lg_matches` SET `status` = \'finished\', `round` = ?, `data` = ?, `ended_at` = NOW() WHERE `uid` = ?',
        { round, json.encode({ players = list, why = why, kills = g.kills }), g.uid })
    Logs.Add('zombie', ('partie %s terminée à la manche %d (%s)'):format(g.uid, round, why or '?'))
    Games.Send(g, 'zbGameOver', { round = round, why = why, duration = duration, players = list, kills = g.kills or 0 })
    Wait(12000)
    for _, s in ipairs(Games.Members(g)) do Games.ExitInstance(g, s, false) end
    Games.Close(g)
    Lobby.PushList()
end

function Zombie.Stop(g, reason)
    if g.phase == LG.Phase.LOBBY then return Zombie.Cancel(g, reason) end
    Games.Send(g, 'notify', ('Partie arrêtée par le staff : %s'):format(reason or ''), 'error')
    Zombie.Finish(g, 'arrêt staff')
end

local function leaveRunning(g, src, reason, dropped)
    local p = g.players[src]
    if not p then return end
    g.leavers[#g.leavers + 1] = { cid = p.cid, name = p.name, kills = p.kills, money = p.moneyEarned, downs = p.downs, revives = p.revives, left = true }
    g.revives[src] = nil
    for target, r in pairs(g.revives) do if r.by == src then g.revives[target] = nil end end
    if not dropped then Games.ExitInstance(g, src, false) end
    g.players[src] = nil
    for i, s in ipairs(g.order) do if s == src then table.remove(g.order, i) break end end
    Games.Detach(src)
    Logs.Add('zombie', ('%s quitte la partie %s (%s)'):format(p.name, g.uid, reason or '?'))
    Games.Send(g, 'zbFeed', { kind = 'left', name = p.name })
    if g.phase ~= LG.Phase.ENDED then Zombie.SendState(g) end
end

Games.Register(LG.Mode.ZOMBIE, {
    view = publicView,
    lobbyView = lobbyView,
    cancel = function(g, reason) Zombie.Cancel(g, reason) end,
    leave = function(g, src, reason)
        if g.phase == LG.Phase.LOBBY then return Zombie.LeaveLobby(g, src, reason) end
        leaveRunning(g, src, reason, false)
    end,
    drop = function(g, src)
        if g.phase == LG.Phase.LOBBY then return Zombie.LeaveLobby(g, src, 'déconnexion') end
        leaveRunning(g, src, 'déconnexion', true)
    end,
})
