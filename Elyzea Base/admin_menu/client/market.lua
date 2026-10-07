-- =========================================================
--  SUPÉRETTE - CLIENT  (+ icônes de carte du tatoueur et de la supérette)
--  Aucune boucle : l'interface s'ouvre, le serveur fait le reste.
-- =========================================================
MarketOpen = false
local shopId, shopKind

local function close()
    if not MarketOpen then return end
    MarketOpen, shopId = false, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'market', open = false })
end

local function show(data)
    if MarketOpen or type(data) ~= 'table' or GunTrialActive then return end
    if (IsStaffMenuOpen and IsStaffMenuOpen()) or BarberOpen or TattooOpen then return end
    local p = PlayerPedId()
    if IsPedInAnyVehicle(p, false) or IsEntityDead(p) then return end
    MarketOpen, shopId, shopKind = true, data.id, data.kind == 'gunshop' and 'gunshop' or 'market'
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'market', open = true, shop = data })
    CreateThread(function()
        -- Fermeture si le joueur meurt ou s'éloigne (vérifié 2 fois par seconde seulement)
        local start = GetEntityCoords(p)
        while MarketOpen do
            Wait(500)
            local ped = PlayerPedId()
            if IsEntityDead(ped) or #(GetEntityCoords(ped) - start) > 4.0 then close() end
        end
    end)
end
RegisterNetEvent('adminmenu:market:show', show)
RegisterNetEvent('adminmenu:gunshop:show', show)   -- l'armurerie utilise la même interface

RegisterNetEvent('adminmenu:market:result', function(ok, msg, wallet)
    if not MarketOpen then return end
    SendNUIMessage({ action = 'market', event = ok and 'paid' or 'payfail', msg = msg, wallet = wallet })
end)

RegisterNUICallback('market_close', function(_, cb) cb('ok') close() end)
RegisterNUICallback('market_buy', function(d, cb)
    cb('ok')
    if not MarketOpen or type(d.cart) ~= 'table' then return end
    TriggerServerEvent(shopKind == 'gunshop' and 'adminmenu:gunshop:buy' or 'adminmenu:market:buy', shopId, d.cart, d.method == 'bank' and 'bank' or 'cash')
end)
-- Essai d'une arme (armurerie)
RegisterNUICallback('market_trial', function(d, cb)
    cb('ok')
    if not MarketOpen or shopKind ~= 'gunshop' then return end
    TriggerServerEvent('adminmenu:gunshop:trial', shopId, tonumber(d.i))
end)
function CloseMarketUi() close() end

-- ---------------------------------------------------------
--  Icônes sur la carte (tatoueurs + supérettes posés dans l'éditeur)
-- ---------------------------------------------------------
local blips = {}
function RefreshShopBlips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    for _, r in ipairs((Editor and Editor.peds) or {}) do
        local role, cfg = nil, nil
        if r.npc and r.npc.tattoo then role, cfg = r.npc.tattoo, Config.Tattoo or {} end
        if r.npc and r.npc.market then role, cfg = r.npc.market, Config.Market or {} end
        if r.npc and r.npc.gunshop then role, cfg = r.npc.gunshop, Config.GunShop or {} end
        if role and role.blip and cfg.enabled ~= false then
            local b = AddBlipForCoord(r.x + 0.0, r.y + 0.0, r.z + 0.0)
            SetBlipSprite(b, role.blipSprite or cfg.blipSprite or 52)
            SetBlipColour(b, role.blipColor or cfg.blipColor or 2)
            SetBlipScale(b, cfg.blipScale or 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(role.name or 'Magasin')
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    close()
end)
