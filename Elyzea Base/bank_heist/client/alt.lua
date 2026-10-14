-- =====================================================================
--  BANK HEIST - client : menu ALT
--  Fournisseur du menu ALT d'elyzea_police (comme jewelry_heist) :
--    AltTarget(entité) -> titre si c'est un de nos PNJ (employé, marchand)
--    AltNearby()       -> entité, titre si le joueur est à un point (départ, coffre, billets)
--    AltOptions(ctx) / AltSelect(id, ctx)
--  Sans elyzea_police : menu autonome sur ALT.
-- =====================================================================
local C = BHC

local function pedTarget(ent)
    local p = ent and C.PedByEntity[ent]
    if not p then return nil end
    if p.kind == 'clerk' then local b = C.BankDef(p.id) return b and { kind = 'clerk', bank = p.id, title = ('Employé · %s'):format(b.name) } end
    for _, m in ipairs((C.Cfg() or {}).merchants or {}) do if m.id == p.id then return { kind = 'merchant', id = m.id, title = m.name } end end
end

-- Point le plus proche : départ, coffre, billets (ou PNJ proche si rien n'est visé)
local function nearest()
    local cfg = C.Cfg()
    if not cfg or not cfg.general.enabled then return nil end
    local best, bd
    local function consider(t, p, max)
        local d = C.Dist(p)
        if d <= max and (not bd or d < bd) then best, bd = t, d end
    end
    -- distances un peu plus larges qu'avant (le serveur accepte jusqu'à distance + 1 m)
    local D = math.max(cfg.general.interactDistance, 2.5)
    for _, b in ipairs(cfg.banks) do
        if b.enabled then
            consider({ kind = 'start', bank = b.id, title = 'Braquer · ' .. b.name }, b.start, D)
            consider({ kind = 'vault', bank = b.id, title = 'Coffre · ' .. b.name }, b.vault, 2.0)
            for i, p in ipairs(b.cash or {}) do consider({ kind = 'cash', bank = b.id, spot = i, title = 'Billets · ' .. b.name }, p, 1.8) end
            consider({ kind = 'clerk', bank = b.id, title = 'Employé · ' .. b.name }, b.clerk, 3.0)
        end
    end
    for _, m in ipairs(cfg.merchants) do if m.enabled then consider({ kind = 'merchant', id = m.id, title = m.name }, m.ped, math.max(m.interactDistance, 2.5)) end end
    return best
end

local function options(t)
    local out = {}
    if not t then return out end
    local st = t.bank and C.Bank(t.bank) or {}
    local phase = st.phase or 'available'
    if t.kind == 'merchant' then
        out[#out + 1] = { id = 'shop', label = 'Acheter du matériel', icon = 'buy' }
    elseif t.kind == 'start' then
        out[#out + 1] = { id = 'start', label = 'Braquer la banque', icon = 'rob', disabled = phase ~= 'available',
            desc = phase == 'cooldown' and 'Banque sous surveillance renforcée' or (phase ~= 'available' and 'Braquage en cours') or nil }
    elseif t.kind == 'clerk' then
        if phase ~= 'available' and phase ~= 'cooldown' and not st.threatened then
            out[#out + 1] = { id = 'threat', label = 'Menacer l\'employé', icon = 'rob', disabled = not C.Armed(), desc = not C.Armed() and 'Il faut une arme en main' or nil }
        end
    elseif t.kind == 'vault' then
        if phase == 'started' or phase == 'hacking' then
            out[#out + 1] = { id = 'hack', label = 'Pirater le coffre avec l\'ordinateur portable', icon = 'hack', disabled = phase == 'hacking',
                desc = phase == 'hacking' and 'Piratage déjà en cours' or nil }
        end
        if phase == 'exhausted' then out[#out + 1] = { id = 'c4', label = 'Placer une charge C4', icon = 'c4' } end
        if phase == 'c4' then out[#out + 1] = { id = 'none', label = 'Charge posée : éloignez-vous !', icon = 'c4', disabled = true } end
    elseif t.kind == 'cash' then
        if phase == 'open' then
            out[#out + 1] = { id = 'collect', label = 'Ramasser les billets', icon = 'cash', disabled = not st.cashLeft, desc = not st.cashLeft and 'Il n\'y a plus de billets' or nil }
            out[#out + 1] = { id = 'extras', label = 'Prendre les objets du coffre', icon = 'bag' }
        end
    end
    return out
end

local function openShop(id)
    local r = C.Req('shopData', { merchant = id })
    if C.Show(r) then C.OpenUI('shop', r) end
end

local function select(id, t)
    if not t then return end
    if id == 'shop' then openShop(t.id)
    elseif id == 'start' then C.Show(C.Req('start', { bank = t.bank }))
    elseif id == 'threat' then
        local def = C.BankDef(t.bank)
        local ped = def and C.PedEntityOf and C.PedEntityOf(t.bank)
        if ped then TaskAimGunAtEntity(PlayerPedId(), ped, 2000, false) end
        local r = C.Req('threat', { bank = t.bank })
        if C.Show(r) then C.Notify('L\'employé lève les mains puis se met à genoux.', 'success') end
    elseif id == 'hack' then C.StartHack(t.bank)
    elseif id == 'c4' then C.PlantC4(t.bank)
    elseif id == 'collect' then C.Collect(t.bank, t.spot)
    elseif id == 'extras' then C.Show(C.Req('takeExtras', { bank = t.bank }))
    end
end

-- Résolution de la cible d'un contexte du menu ALT de la police
local function resolve(ctx)
    local t = ctx and pedTarget(ctx.entity)
    if t then return t end
    return nearest()
end

exports('AltTarget', function(ent) local t = pedTarget(ent) return t and t.title or nil end)
exports('AltNearby', function()
    local t = nearest()
    if not t then return nil end
    if #options(t) == 0 then return nil end
    return PlayerPedId(), t.title
end)
exports('AltOptions', function(ctx) return options(resolve(ctx)) end)
exports('AltSelect', function(id, ctx) local t = resolve(ctx) CreateThread(function() select(id, t) end) end)

-- Menu autonome (sans elyzea_police)
local menuTarget = nil
RegisterCommand('+bh_alt', function()
    if GetResourceState('elyzea_police') == 'started' or C.ui then return end
    local t = nearest()
    local opts = options(t)
    if #opts == 0 then return end
    menuTarget = t
    C.OpenUI('menu', { title = t.title, options = opts })
end, false)
RegisterCommand('-bh_alt', function() end, false)
RegisterKeyMapping('+bh_alt', 'Banque : menu d\'interaction (si le menu ALT de la police est absent)', 'keyboard', 'LMENU')
RegisterNUICallback('menuSelect', function(body, cb)
    cb({})
    local t = menuTarget
    menuTarget = nil
    C.CloseUI()
    if t and body and body.id then CreateThread(function() select(tostring(body.id), t) end) end
end)

-- Interaction directe : E = action principale (acheter, braquer, menacer, pirater, C4, ramasser),
-- ALT = toutes les actions. Fonctionne même si le menu ALT ne trouve pas la cible.
local busy = false
local function mainOption(opts)
    for _, o in ipairs(opts) do if not o.disabled then return o end end
end
CreateThread(function()
    while true do
        local sleep = 700
        local blocking = false
        if not C.ui and not busy and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local t = nearest()
            local opts = t and options(t) or {}
            if #opts > 0 then
                sleep = 0
                local main = mainOption(opts)
                if main then
                    blocking = true
                    C.Help(('~INPUT_CONTEXT~ %s~n~~INPUT_CHARACTER_WHEEL~ %s'):format(main.label, t.title))
                    if IsControlJustReleased(0, 38) then
                        busy = true
                        CreateThread(function() select(main.id, t) Wait(800) busy = false end)
                    end
                else
                    local why = opts[1].desc or opts[1].label
                    C.Help(('%s~n~%s'):format(t.title, why))
                end
            end
        end
        C.NoDrop('alt', blocking)
        Wait(sleep)
    end
end)
