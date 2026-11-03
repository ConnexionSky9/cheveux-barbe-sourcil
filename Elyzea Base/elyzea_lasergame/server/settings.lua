-- =====================================================================
--  ELYZEA LASERGAME - RÉGLAGES MODIFIÉS EN JEU
--  Le staff modifie les réglages depuis /lgadmin. Ils sont enregistrés dans lg_settings
--  (clé « overrides ») et appliqués par-dessus les fichiers de configuration, sans redémarrage.
--  La partie utile aux clients (armes, cartes, PNJ, prix) est publiée dans GlobalState.lgPublic.
-- =====================================================================
Settings = { data = {} }

local Defaults = {}

-- Valeurs d'origine des fichiers (pour pouvoir annuler une modification)
function Settings.CaptureDefaults()
    Defaults.pvp = LGU.Copy(Config.PvP)
    Defaults.stake = LGU.Copy(Config.Stake)
    Defaults.weapons = LGU.Copy(LG.Weapons)
    Defaults.zombie = LGU.Copy(LG.Zombie)
    Defaults.ranks = LGU.Copy(LG.Ranks)
end

local function num(v, a, b, def) v = tonumber(v) if not v then return def end return LGU.Clamp(v, a, b) end

-- Nettoyage strict de ce que le staff envoie (aucune valeur libre n'est acceptée telle quelle)
local SCHEMA = {
    pvp = {
        enabled = 'bool', requireFullTeams = 'bool', requireEqualTeams = 'bool', oneHitElimination = 'bool', friendlyFire = 'bool',
        shield = { 1, 1000 }, minRankedDuration = { 0, 3600 }, lobbyIdleTimeout = { 60, 7200 },
        defaultRoundTime = { 30, 900 }, defaultRounds = { 1, 15 },
    },
    stake = { enabled = 'bool', min = { 0, 10000000 }, max = { 0, 10000000 }, step = { 1, 100000 }, houseFeePct = { 0, 50 } },
    weapon = { damage = { 1, 1000 }, zDamage = { 1, 100000 }, range = { 1, 400 }, rpm = { 10, 1500 }, spread = { 0, 15 },
               mag = { 0, 500 }, reload = { 0, 10000 }, disabled = 'bool' },
    zombieRounds = { countBase = { 1, 100 }, countPerRound = { 0, 50 }, countMax = { 1, 500 }, maxAlive = { 1, 40 },
                     hpBase = { 10, 10000 }, hpPerRound = { 0, 5000 }, hpLinearUntil = { 1, 100 }, hpGrowth = { 1, 2 }, hpMax = { 100, 1000000 },
                     damageBase = { 1, 500 }, damagePerRound = { 0, 50 }, damageMax = { 1, 1000 },
                     runFromRound = { 1, 100 }, sprintFromRound = { 1, 100 }, speedRamp = { 0, 1 },
                     intermission = { 3, 120 }, spawnInterval = { 200, 10000 } },
    zombieType = { hp = { 0.1, 50 }, damage = { 0.1, 20 }, speed = { 0.3, 3 }, reward = { 0, 100000 }, weight = { 0, 1000 }, minRound = { 1, 200 } },
    zombieMoney = { hit = { 0, 10000 }, meleeKillBonus = { 0, 10000 }, reviveBonus = { 0, 100000 }, roundBonus = { 0, 100000 }, startMoney = { 0, 1000000 } },
    zombiePlayer = { health = { 10, 5000 }, regenDelay = { 0, 60000 }, regenPerSecond = { 0, 1000 }, bleedout = { 5, 300 }, reviveTime = { 0.5, 30 } },
}

local function cleanBy(schema, input)
    local out = {}
    if type(input) ~= 'table' then return out end
    for k, rule in pairs(schema) do
        local v = input[k]
        if v ~= nil then
            if rule == 'bool' then out[k] = v == true
            elseif type(rule) == 'table' then out[k] = num(v, rule[1], rule[2], nil) end
        end
    end
    return out
end
Settings.Clean = cleanBy
Settings.SCHEMA = SCHEMA

-- Applique les réglages enregistrés par-dessus les valeurs d'origine
function Settings.Apply()
    local d = Settings.data
    -- PVP
    for k, v in pairs(Defaults.pvp) do Config.PvP[k] = LGU.Copy(v) end
    for k, v in pairs(d.pvp or {}) do Config.PvP[k] = v end
    Config.PvP.disabledFormats = LGU.Copy((d.pvp or {}).disabledFormats or {})
    for k, v in pairs(Defaults.stake) do Config.Stake[k] = v end
    for k, v in pairs(d.stake or {}) do Config.Stake[k] = v end
    if Config.Stake.max < Config.Stake.min then Config.Stake.max = Config.Stake.min end
    -- armes
    for i, w in ipairs(Defaults.weapons) do
        local nw = LGU.Copy(w)
        for k, v in pairs((d.weapons or {})[w.id] or {}) do nw[k] = v end
        LG.Weapons[i] = nw
    end
    LGU.ResetWeaponIndex()
    -- Zombie
    local z = LGU.Copy(Defaults.zombie)
    local dz = d.zombie or {}
    if dz.enabled ~= nil then z.enabled = dz.enabled end
    for k, v in pairs(dz.rounds or {}) do z.rounds[k] = v end
    for k, v in pairs(dz.money or {}) do z.money[k] = v end
    for k, v in pairs(dz.player or {}) do z.player[k] = v end
    for id, t in pairs(dz.types or {}) do if z.types[id] then for k, v in pairs(t) do z.types[id][k] = v end end end
    for id, p in pairs(dz.perks or {}) do if z.perks[id] then for k, v in pairs(p) do z.perks[id][k] = v end end end
    if dz.maxPerks then z.maxPerks = dz.maxPerks end
    for k, v in pairs(z) do LG.Zombie[k] = v end
    -- rangs (seuils)
    for i, r in ipairs(Defaults.ranks) do
        LG.Ranks[i] = LGU.Copy(r)
        local o = (d.ranks or {})[r.id]
        if o and tonumber(o.min) then LG.Ranks[i].min = math.floor(tonumber(o.min)) end
    end
    LG.Ranks[1].min = 0
    Settings.Publish()
end

-- Données publiques pour les clients (armes, cartes, PNJ, prix, modes)
function Settings.Publish()
    local weapons = {}
    for _, w in ipairs(LG.Weapons) do
        weapons[w.id] = { damage = w.damage, zDamage = w.zDamage, range = w.range, rpm = w.rpm, spread = w.spread,
            mag = w.mag, reload = w.reload, disabled = w.disabled }
    end
    local maps = {}
    for id, m in pairs(Maps.list) do maps[id] = { anchor = m.anchor, enabled = m.enabled } end
    local perks = {}
    for id, p in pairs(LG.Zombie.perks) do perks[id] = { price = p.price, disabled = p.disabled } end
    local ranks = {}
    for _, r in ipairs(LG.Ranks) do ranks[#ranks + 1] = r.min end
    GlobalState.lgPublic = {
        v = os.time(),
        pvpEnabled = Config.PvP.enabled ~= false,
        zombieEnabled = LG.Zombie.enabled ~= false,
        weapons = weapons, maps = maps, perks = perks, ranks = ranks,
        doors = (Settings.data.zombie or {}).doors or {},
        wallbuys = (Settings.data.zombie or {}).wallbuys or {},
        npcs = Settings.Npcs(),
        player = { health = LG.Zombie.player.health, reviveTime = LG.Zombie.player.reviveTime },
    }
end

-- PNJ : ceux du fichier de configuration + ceux posés en jeu (/lgadmin › PNJ)
function Settings.Npcs()
    local out = {}
    local removed = Settings.data.npcRemoved or {}
    for _, n in ipairs(Config.Npcs) do
        if n.enabled ~= false and not removed[n.id] then
            local c = n.coords
            out[#out + 1] = { id = n.id, model = n.model, x = c.x, y = c.y, z = c.z, h = c.w, scenario = n.scenario, anim = n.anim,
                distance = n.distance, label = n.label, text = n.text, blip = n.blip }
        end
    end
    for _, n in ipairs(Settings.data.npcs or {}) do out[#out + 1] = n end
    return out
end

function Settings.Load()
    Settings.data = DB.GetSetting('overrides') or {}
end

function Settings.Save()
    DB.SetSetting('overrides', Settings.data)
    Settings.Apply()
end

-- Prix effectif d'une porte / arme murale de la carte Zombie (réglage staff sinon valeur de la carte)
function Settings.DoorPrice(door) return tonumber(((Settings.data.zombie or {}).doors or {})[door.id]) or door.price end
function Settings.WallbuyPrice(wb) return tonumber((((Settings.data.zombie or {}).wallbuys or {})[wb.id] or {}).price) or wb.price end
function Settings.WallbuyWeapon(wb)
    local w = (((Settings.data.zombie or {}).wallbuys or {})[wb.id] or {}).weapon
    return (w and LGU.Weapon(w)) and w or wb.weapon
end
