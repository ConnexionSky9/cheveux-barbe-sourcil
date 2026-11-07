-- =====================================================================
--  BANK HEIST - client : menu ALT
--  Fournisseur du menu ALT d'elyzea_police :
--    AltTarget(entité) -> titre si c'est un de nos PNJ (banquier, marchand, indic)
--    AltNearby()       -> entité, titre si le joueur est à un point (porte, butin, boîtier d'alarme)
--    AltOptions(ctx) / AltSelect(id, ctx)
--  Banquier : « Accéder à mon compte » ; arme en main : « BRAQUER LA BANQUE ».
--  Sans elyzea_police : menu autonome sur ALT.
-- =====================================================================
local C = BHC

local function pedTarget(ent)
    local p = ent and C.PedByEntity[ent]
    if not p then return nil end
    local cfg = C.Cfg() or {}
    if p.kind == 'banker' then local b = C.BankDef(p.id) return b and { kind = 'banker', bank = p.id, title = ('Banquier · %s'):format(b.name) } end
    if p.kind == 'merchant' then for _, m in ipairs(cfg.merchants or {}) do if m.id == p.id then return { kind = 'merchant', id = m.id, title = m.name } end end end
    if p.kind == 'informant' then for _, n in ipairs(cfg.informants or {}) do if n.id == p.id then return { kind = 'informant', id = n.id, title = n.name } end end end
end

-- Point le plus proche : porte du coffre, butin, boîtier d'alarme, PNJ (si rien n'est visé)
local function nearest()
    local cfg = C.Cfg()
    if not cfg or not cfg.general.enabled then return nil end
    local best, bd
    local function consider(t, p, max)
        local d = C.Dist(p)
        if d <= max and (not bd or d < bd) then best, bd = t, d end
    end
    for _, b in ipairs(cfg.banks) do
        if b.enabled then
            local st = C.Bank(b.id)
            if st.phase == 'active' then
                consider({ kind = 'door', bank = b.id, title = 'Porte du coffre · ' .. b.name }, b.doorPoint, 2.0)
                if st.alarm then consider({ kind = 'alarm', bank = b.id, title = 'Boîtier d\'alarme' }, b.alarm, 2.0) end
                for i, p in ipairs(b.loot or {}) do
                    local t = (cfg.lootTypes or {})[p.type] or {}
                    consider({ kind = 'loot', bank = b.id, point = i, title = t.label or 'Butin' }, p, 1.9)
                end
            end
            consider({ kind = 'banker', bank = b.id, title = 'Banquier · ' .. b.name }, b.banker, 3.0)
        end
    end
    for _, m in ipairs(cfg.merchants) do if m.enabled then consider({ kind = 'merchant', id = m.id, title = m.name }, m.ped, math.max(m.interactDistance, 2.5)) end end
    for _, n in ipairs(cfg.informants or {}) do if n.enabled then consider({ kind = 'informant', id = n.id, title = n.name }, n.ped, math.max(n.interactDistance, 2.5)) end end
    if not best then
        local carried = C.CarriedBankBag and C.CarriedBankBag()
        if carried and (carried.money or 0) > 0 then best = { kind = 'carried', title = 'Sac de billets', noE = true } end
    end
    return best
end

local function options(t)
    local out = {}
    if not t then return out end
    local cfg = C.Cfg() or {}
    local st = t.bank and C.Bank(t.bank) or {}
    local active = st.phase == 'active'
    if t.kind == 'carried' then
        local carried = C.CarriedBankBag and C.CarriedBankBag()
        out[#out + 1] = { id = 'takeMoney', label = ('Prendre l\'argent du sac (%s)'):format(BH.Money(carried and carried.money or 0)), icon = 'cash' }
    elseif t.kind == 'merchant' then
        out[#out + 1] = { id = 'shop', label = 'Acheter du matériel', icon = 'buy' }
    elseif t.kind == 'informant' then
        out[#out + 1] = { id = 'talk', label = 'Lui parler', icon = 'talk' }
    elseif t.kind == 'banker' then
        if not active and (cfg.banking or {}).enabled ~= false then out[#out + 1] = { id = 'bank', label = 'Accéder à mon compte', icon = 'bank' } end
        if C.Armed() then   -- un policier en service est refusé par le serveur
            out[#out + 1] = { id = 'rob', label = 'BRAQUER LA BANQUE', icon = 'rob', disabled = st.phase ~= 'available',
                desc = st.phase == 'cooldown' and 'Banque sous surveillance renforcée' or (active and 'Braquage en cours') or 'La police sera prévenue' }
        end
        if active then out[#out + 1] = { id = 'none', label = st.handsUp and 'Le banquier lève les mains…' or 'Le banquier est à terre', icon = 'rob', disabled = true } end
    elseif t.kind == 'door' then
        if st.door == 'locked' then
            if cfg.door.hack then out[#out + 1] = { id = 'hack', label = 'Décrypter la porte (ordinateur)', icon = 'hack', disabled = st.handsUp == true, desc = st.handsUp and 'Attendez que le banquier soit à terre' or nil } end
            if cfg.door.c4 then out[#out + 1] = { id = 'c4', label = 'Poser une charge C4 sur la porte', icon = 'c4' } end
        elseif st.door == 'hacking' then out[#out + 1] = { id = 'none', label = 'Décryptage en cours…', icon = 'hack', disabled = true }
        elseif st.door == 'c4' then out[#out + 1] = { id = 'none', label = 'Charge armée : éloignez-vous !', icon = 'c4', disabled = true } end
    elseif t.kind == 'alarm' then
        -- policier en service : coupée directement ; braqueur : mini-jeu des fils (décidé par le serveur)
        if cfg.alarm.robbersCanDisable or cfg.alarm.policeCanDisable then out[#out + 1] = { id = 'alarm', label = 'Couper l\'alarme', icon = 'alarm' } end
    elseif t.kind == 'loot' and active and st.door == 'open' then
        local def = C.BankDef(t.bank)
        local p = def and def.loot[t.point]
        local ps = (st.points or {})[t.point] or {}
        local lt = (cfg.lootTypes or {})[p and p.type or ''] or {}
        if lt.tool == 'drill' and not ps.drilled then
            out[#out + 1] = { id = 'drill', label = 'Percer les coffres individuels', icon = 'drill', disabled = ps.drilling == true, desc = ps.drilling and 'Perçage en cours' or nil }
        else
            out[#out + 1] = { id = 'collect', label = lt.anim == 'trolley' and 'Vider le chariot dans le sac' or 'Mettre le butin dans le sac', icon = 'cash',
                disabled = not ps.full or ps.busy, desc = (not ps.full) and 'Il n\'y a plus rien' or (ps.busy and 'Quelqu\'un se sert déjà' or nil) }
        end
    end
    return out
end

local function openShop(id)
    local r = C.Req('shopData', { merchant = id })
    if C.Show(r) then C.OpenUI('shop', r) end
end

local function talk(id)
    local r = C.Req('infoTalk', { id = id })
    if C.Show(r) then
        local ped
        for e, p in pairs(C.PedByEntity) do if p.kind == 'informant' and p.id == id then ped = e end end
        if ped and DoesEntityExist(ped) then TaskTurnPedToFaceEntity(PlayerPedId(), ped, 600) PlayPedAmbientSpeechNative(ped, 'GENERIC_HI', 'SPEECH_PARAMS_FORCE') end
        C.OpenUI('talk', r)
    end
end

local function rob(bankId)
    local ped = C.PedEntityOf(bankId)
    C.Scenes.Threaten(ped)
    if ped and DoesEntityExist(ped) then PlayPedAmbientSpeechNative(PlayerPedId(), 'GENERIC_INSULT_HIGH', 'SPEECH_PARAMS_FORCE_SHOUTED') end
    C.Show(C.Req('rob', { bank = bankId }))
end

local function select(id, t)
    if not t or id == 'none' then return end
    if id == 'shop' then openShop(t.id)
    elseif id == 'talk' then talk(t.id)
    elseif id == 'bank' then C.OpenBank(t.bank)
    elseif id == 'rob' then rob(t.bank)
    elseif id == 'hack' then C.StartHack(t.bank)
    elseif id == 'c4' then C.PlantC4(t.bank)
    elseif id == 'alarm' then C.DisableAlarm(t.bank)
    elseif id == 'drill' then C.Drill(t.bank, t.point)
    elseif id == 'collect' then C.Collect(t.bank, t.point)
    elseif id == 'takeMoney' then C.TakeBagMoney(nil)
    end
end

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
