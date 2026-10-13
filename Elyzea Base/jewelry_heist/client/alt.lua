-- =====================================================================
--  JEWELRY HEIST - client : menu ALT (bijoutier, racheteur, sac au sol)
--  Intégré au menu ALT existant d'elyzea_police (fournisseur « jewelry_heist ») :
--    AltTarget(entité) -> titre si l'entité visée est un de nos PNJ
--    AltNearby()       -> entité, titre de la cible la plus proche (sac au sol, PNJ) si rien n'est visé
--    AltOptions(ctx)   -> actions possibles · AltSelect(id, ctx) -> exécute l'action
--  Si elyzea_police n'est pas démarré : menu ALT autonome (même touche, réglable dans les touches FiveM).
-- =====================================================================
local C = JHC

local function target(ent)
    if not ent or ent == 0 then return nil end
    local p = C.PedByEntity[ent]
    if p then return { kind = p.kind, id = p.id, def = C.PedDef(p.kind, p.id), entity = ent } end
    local bag = C.BagByEntity[ent]
    if bag then return { kind = 'bag', id = bag, entity = ent } end
end

-- Sac de billets (braquage de banque) : se ramasse, ne s'ouvre pas (encaissement à un point de dépôt)
local function isBankBag(id) local b = (GlobalState.jhBags or {})[id] return b ~= nil and b.kind == 'bank' end

local function titleOf(t)
    if t.kind == 'bag' then return isBankBag(t.id) and 'Sac de billets' or 'Sac de butin' end
    return t.def and t.def.name or (t.kind == 'shop' and 'Bijoutier' or 'Racheteur')
end

local function armed()
    local w = GetSelectedPedWeapon(PlayerPedId())
    return w ~= 0 and w ~= joaat('WEAPON_UNARMED')
end

local function nearest()
    local cfg = C.Cfg()
    if not cfg or not cfg.general.enabled then return nil end
    local bag, obj = C.NearestBag()
    if bag and obj then return { kind = 'bag', id = bag, entity = obj } end
    local pc = GetEntityCoords(PlayerPedId())
    local best, bestD
    for ent, p in pairs(C.PedByEntity) do
        if DoesEntityExist(ent) then
            local def = C.PedDef(p.kind, p.id)
            local d = #(pc - GetEntityCoords(ent))
            local max = def and (p.kind == 'shop' and math.max(def.interactDistance, def.robDistance or 0) or def.interactDistance) or cfg.general.interactDistance
            if d <= max + 0.5 and (not bestD or d < bestD) then best, bestD = { kind = p.kind, id = p.id, def = def, entity = ent }, d end
        end
    end
    return best
end

local function options(t)
    local out = {}
    if not t then return out end
    local carrying = LocalPlayer.state.jhBag ~= nil
    if t.kind == 'bag' then
        out[#out + 1] = { id = 'pickup', label = 'Ramasser le sac', icon = 'bag', disabled = carrying or IsPedInAnyVehicle(PlayerPedId(), false),
            desc = carrying and 'Vous portez déjà un sac' or nil }
        if not isBankBag(t.id) then out[#out + 1] = { id = 'open', label = 'Ouvrir le sac', icon = 'open' } end
    elseif t.kind == 'shop' and t.def then
        local heist = (GlobalState.jhHeists or {})[t.id]
        if t.def.buy then out[#out + 1] = { id = 'buy', label = 'Acheter des bijoux', icon = 'buy', disabled = heist ~= nil } end
        if t.def.sell then out[#out + 1] = { id = 'sell', label = 'Vendre des bijoux', icon = 'sell', disabled = heist ~= nil } end
        if t.def.rob then
            out[#out + 1] = { id = 'rob', label = 'Braquer la bijouterie', icon = 'rob', disabled = heist ~= nil or not armed() or carrying,
                desc = heist and 'Braquage déjà en cours' or (not armed() and 'Il faut une arme en main') or (carrying and 'Vous portez déjà un sac') or nil }
        end
    elseif t.kind == 'buyer' then
        out[#out + 1] = { id = 'sell', label = 'Vendre des bijoux', icon = 'sell' }
    end
    return out
end

local function openTrade(t, mode)
    local r = t.kind == 'buyer' and C.Req('buyerData', { buyer = t.id }) or C.Req('shopData', { shop = t.id })
    if not C.Show(r) then return end
    r.mode = mode
    C.OpenUI('trade', r)
end

local function select(id, t)
    if not t then return end
    if id == 'pickup' then C.PickupBag(t.id)
    elseif id == 'open' then C.OpenBag(t.id)
    elseif id == 'buy' then openTrade(t, 'buy')
    elseif id == 'sell' then openTrade(t, 'sell')
    elseif id == 'rob' then
        local ped = PlayerPedId()
        if t.entity and DoesEntityExist(t.entity) then TaskAimGunAtEntity(ped, t.entity, 1500, false) end
        C.Show(C.Req('rob', { shop = t.id }))
    end
end

-- ---------------------------------------------------------------------
-- Fournisseur du menu ALT d'elyzea_police
-- ---------------------------------------------------------------------
exports('AltTarget', function(ent)
    local t = target(ent)
    return t and titleOf(t) or nil
end)
exports('AltNearby', function()
    local t = nearest()
    if not t then return nil end
    return t.entity, titleOf(t)
end)
exports('AltOptions', function(ctx) return options(target(ctx and ctx.entity)) end)
exports('AltSelect', function(id, ctx)
    local t = target(ctx and ctx.entity)
    CreateThread(function() select(id, t) end)
end)

-- ---------------------------------------------------------------------
-- Menu ALT autonome (si elyzea_police n'est pas démarré)
-- ---------------------------------------------------------------------
local menuTarget = nil
RegisterCommand('+jh_alt', function()
    if GetResourceState('elyzea_police') == 'started' or C.ui then return end
    local t = nearest()
    if not t then return end
    local opts = options(t)
    if #opts == 0 then return end
    menuTarget = t
    C.OpenUI('menu', { title = titleOf(t), options = opts })
end, false)
RegisterCommand('-jh_alt', function() end, false)
-- Touche par défaut : ALT gauche (chaque joueur peut la changer dans Paramètres > Touches > FiveM)
RegisterKeyMapping('+jh_alt', 'Bijouterie : menu d\'interaction (si le menu ALT de la police est absent)', 'keyboard', 'LMENU')

RegisterNUICallback('menuSelect', function(body, cb)
    cb({})
    local t = menuTarget
    menuTarget = nil
    C.CloseUI()
    if t and body and body.id then CreateThread(function() select(tostring(body.id), t) end) end
end)

-- Rappel à l'écran près d'un PNJ ou d'un sac
CreateThread(function()
    while true do
        local sleep = 700
        if not C.ui and not LocalPlayer.state.jhBag then
            local t = nearest()
            if t then
                sleep = 0
                C.Help(('~INPUT_CHARACTER_WHEEL~ %s : %s'):format(titleOf(t), t.kind == 'bag' and 'ramasser / ouvrir' or 'interagir'))
            end
        end
        Wait(sleep)
    end
end)
