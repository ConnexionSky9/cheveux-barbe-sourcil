-- =========================================================
--  PVP ARENA - réglages modifiables depuis le menu admin (onglet ⚔️ Arène PvP)
--  Enregistrés dans data/settings.json et appliqués par-dessus config.lua, sans redémarrage.
--  Chaque valeur est revalidée ici (types, bornes) : le menu ne peut rien imposer d'invalide.
-- =========================================================
local FILE = 'data/settings.json'
local DEFAULTS = nil   -- copie de config.lua au démarrage (pour « Revenir à la config »)

local function deep(t) if type(t) ~= 'table' then return t end local o = {} for k, v in pairs(t) do o[k] = deep(v) end return o end
local function num(v, mn, mx, def) v = tonumber(v) if not v or v ~= v then return def end if v < mn then v = mn end if v > mx then v = mx end return v end
local function int(v, mn, mx, def) return math.floor(num(v, mn, mx, def)) end
local function bool(v, def) if v == nil then return def end return v == true end
local function color(v, def) v = tostring(v or '') return v:match('^#%x%x%x%x%x%x$') and v or def end
local function str(v, len, def) v = tostring(v or ''):gsub('[%c<>]', ''):sub(1, len) return v ~= '' and v or def end
local function oneOf(v, list, def) for _, x in ipairs(list) do if v == x then return v end end return def end

-- Valeurs actuellement appliquées (format envoyé au menu)
function Arena.CurrentSettings()
    local disabled = {}
    for name in pairs(Arena.disabledWeapons or {}) do disabled[#disabled + 1] = name end
    table.sort(disabled)
    return {
        account = Config.Account,
        stake = { min = Config.Stake.min, max = Config.Stake.max, step = Config.Stake.step },
        bet = { enabled = Config.Bet.enabled, min = Config.Bet.min, max = Config.Bet.max },
        fee = { stake = Config.HouseFeePct.stake, bet = Config.HouseFeePct.bet },
        participantBets = Config.ParticipantBets, leaverForfeits = Config.LeaverForfeitsShare,
        maxLobbies = Config.MaxLobbies, defaultWins = Config.DefaultWins, requireFull = Config.RequireFullTeams,
        allowFF = Config.AllowFriendlyFireOption, idle = Config.LobbyIdleTimeout,
        timers = deep(Config.Timers), defaultRoundTime = Config.DefaultRoundTime, timeoutRule = Config.TimeoutRule,
        abandon = Config.AbandonPolicy, maxExits = Config.Zone.maxExitsPerRound,
        health = Config.Health, armor = Config.Armor, ammo = Config.Ammo, defaultWeapon = Config.DefaultWeapon,
        teams = deep(Config.Teams), disabledWeapons = disabled,
    }
end

local function clean(d)
    local C = DEFAULTS
    local out = {}
    out.account = oneOf(d.account, { 'bank', 'cash' }, C.Account)
    local s = type(d.stake) == 'table' and d.stake or {}
    out.stake = { min = int(s.min, 0, 100000000, C.Stake.min), max = int(s.max, 0, 1000000000, C.Stake.max), step = int(s.step, 1, 1000000, C.Stake.step) }
    if out.stake.max < out.stake.min then return nil, 'Mise : le maximum doit être ≥ au minimum.' end
    local b = type(d.bet) == 'table' and d.bet or {}
    out.bet = { enabled = bool(b.enabled, C.Bet.enabled), min = int(b.min, 1, 100000000, C.Bet.min), max = int(b.max, 1, 1000000000, C.Bet.max) }
    if out.bet.max < out.bet.min then return nil, 'Paris : le maximum doit être ≥ au minimum.' end
    local f = type(d.fee) == 'table' and d.fee or {}
    out.fee = { stake = num(f.stake, 0, 50, C.HouseFeePct.stake), bet = num(f.bet, 0, 50, C.HouseFeePct.bet) }
    out.participantBets = oneOf(d.participantBets, { 'own', 'none', 'any' }, C.ParticipantBets)
    out.leaverForfeits = bool(d.leaverForfeits, C.LeaverForfeitsShare)
    out.maxLobbies = int(d.maxLobbies, 1, 30, C.MaxLobbies)
    local wins = int(d.defaultWins, 1, 15, C.DefaultWins)
    local okWins = false
    for _, w in ipairs(Config.WinsOptions) do if w == wins then okWins = true end end
    out.defaultWins = okWins and wins or C.DefaultWins
    out.requireFull = bool(d.requireFull, C.RequireFullTeams)
    out.allowFF = bool(d.allowFF, C.AllowFriendlyFireOption)
    out.idle = int(d.idle, 60, 86400, C.LobbyIdleTimeout)
    local t = type(d.timers) == 'table' and d.timers or {}
    out.timers = { weaponSelect = int(t.weaponSelect, 5, 60, C.Timers.weaponSelect), loading = num(t.loading, 0.5, 10, C.Timers.loading),
        countdown = int(t.countdown, 1, 10, C.Timers.countdown), roundEnd = int(t.roundEnd, 2, 20, C.Timers.roundEnd),
        matchEnd = int(t.matchEnd, 3, 60, C.Timers.matchEnd), teleportGrace = int(t.teleportGrace, 1, 15, C.Timers.teleportGrace),
        deathSettle = num(t.deathSettle, 0.1, 2, C.Timers.deathSettle) }
    local rt = int(d.defaultRoundTime, 0, 3600, C.DefaultRoundTime)
    local okRt = false
    for _, r in ipairs(Config.RoundTimes) do if r == rt then okRt = true end end
    out.defaultRoundTime = okRt and rt or C.DefaultRoundTime
    out.timeoutRule = oneOf(d.timeoutRule, { 'most_alive', 'draw' }, C.TimeoutRule)
    out.abandon = oneOf(d.abandon, { 'forfeit', 'cancel' }, C.AbandonPolicy)
    out.maxExits = int(d.maxExits, 0, 20, C.Zone.maxExitsPerRound)
    out.health = int(d.health, 101, 200, C.Health)
    out.armor = int(d.armor, 0, 100, C.Armor)
    out.ammo = int(d.ammo, 30, 9999, C.Ammo)
    local tm = type(d.teams) == 'table' and d.teams or {}
    out.teams = {}
    for _, k in ipairs({ 'A', 'B' }) do
        local x = type(tm[k]) == 'table' and tm[k] or {}
        out.teams[k] = { name = str(x.name, 16, C.Teams[k].name):upper(), color = color(x.color, C.Teams[k].color) }
    end
    -- armes désactivées (au moins une arme doit rester disponible)
    out.disabledWeapons = {}
    local all = Rules.WeaponIndex()
    local left = 0
    local off = {}
    for _, n in ipairs(type(d.disabledWeapons) == 'table' and d.disabledWeapons or {}) do
        local key = tostring(n):upper()
        if all[key] and not off[key] then off[key] = true out.disabledWeapons[#out.disabledWeapons + 1] = key end
    end
    for name in pairs(all) do if not off[name] then left = left + 1 end end
    if left == 0 then return nil, 'Garde au moins une arme disponible.' end
    out.defaultWeapon = tostring(d.defaultWeapon or C.DefaultWeapon):upper()
    if not all[out.defaultWeapon] or off[out.defaultWeapon] then return nil, 'L\'arme par défaut doit exister et être disponible.' end
    return out
end

-- Applique un réglage validé sur Config (lu en direct par tout le serveur)
local function apply(s)
    Config.Account = s.account
    Config.Stake = s.stake
    Config.Bet = s.bet
    Config.HouseFeePct = s.fee
    Config.ParticipantBets = s.participantBets
    Config.LeaverForfeitsShare = s.leaverForfeits
    Config.MaxLobbies = s.maxLobbies
    Config.DefaultWins = s.defaultWins
    Config.RequireFullTeams = s.requireFull
    Config.AllowFriendlyFireOption = s.allowFF
    Config.LobbyIdleTimeout = s.idle
    for k, v in pairs(s.timers) do Config.Timers[k] = v end
    Config.DefaultRoundTime = s.defaultRoundTime
    Config.TimeoutRule = s.timeoutRule
    Config.AbandonPolicy = s.abandon
    Config.Zone.maxExitsPerRound = s.maxExits
    Config.Health, Config.Armor, Config.Ammo = s.health, s.armor, s.ammo
    Config.DefaultWeapon = s.defaultWeapon
    Config.Teams.A.name, Config.Teams.A.color = s.teams.A.name, s.teams.A.color
    Config.Teams.B.name, Config.Teams.B.color = s.teams.B.name, s.teams.B.color
    -- armes : l'index de validation ne contient que les armes disponibles
    Arena.disabledWeapons = {}
    for _, n in ipairs(s.disabledWeapons) do Arena.disabledWeapons[n] = true end
    local idx = Rules.WeaponIndex()
    for n in pairs(Arena.disabledWeapons) do idx[n] = nil end
    Arena.weapons = idx
end

-- Catégories d'armes envoyées aux joueurs (armes désactivées retirées)
function Arena.PublicWeapons()
    local out = {}
    for _, c in ipairs(Config.WeaponCategories) do
        local list = {}
        for _, w in ipairs(c.weapons) do if not (Arena.disabledWeapons or {})[w.name:upper()] then list[#list + 1] = w end end
        if #list > 0 then out[#out + 1] = { id = c.id, label = c.label, icon = c.icon, weapons = list } end
    end
    return out
end

function Arena.SaveSettings(d)
    local s, err = clean(type(d) == 'table' and d or {})
    if not s then return false, err end
    apply(s)
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(s), -1)
    return true
end

function Arena.ResetSettings()
    local s = clean({})   -- clean() part des valeurs de config.lua
    s.disabledWeapons = {}
    s.defaultWeapon = DEFAULTS.DefaultWeapon:upper()
    apply(s)
    SaveResourceFile(GetCurrentResourceName(), FILE, '', -1)
    return true
end

-- Démarrage : config.lua puis data/settings.json par-dessus
DEFAULTS = deep(Config)
do
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    local ok, d = pcall(function() return raw and raw ~= '' and json.decode(raw) or nil end)
    if ok and type(d) == 'table' then
        local s = clean(d)
        if s then apply(s) else print('^3[pvp_arena] data/settings.json invalide : réglages de config.lua utilisés.^0') end
    end
end
