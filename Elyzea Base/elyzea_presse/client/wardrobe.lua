-- =====================================================================
--  ELYZEA PRESSE - client : vestiaire de la rédaction
--  · Mettre une tenue : les vêtements portés sont d'abord mémorisés (mémoire + PC du
--    joueur, par personnage), puis la tenue de la rédaction est appliquée (packs compris,
--    via @elyzea_core/lib/clothing.lua). Elle n'est jamais enregistrée dans l'apparence.
--  · « Tenue personnelle » (ou fin de service) : les vêtements mémorisés reviennent.
--  · Pendant la tenue, le serveur pose « elyUniform » : elyzea_clothing refuse d'échanger
--    des vêtements-objets, pour que l'uniforme ne devienne jamais des objets.
--  · Déconnexion en tenue : à la reconnexion, les vêtements mémorisés sont remis.
-- =====================================================================
local C = PresseC
local SLOTS = Config.ClothingSlots
local civilian = nil

local function Key()
    local ok, cid = pcall(function() return (exports.elyzea_core:GetPlayerData() or {}).citizenid end)
    return 'presse_civil_' .. tostring(ok and cid or 'default')
end
local function Store(o) if o then SetResourceKvp(Key(), json.encode(o)) else DeleteResourceKvp(Key()) end end
local function Stored()
    local raw = GetResourceKvpString(Key())
    if not raw then return nil end
    local ok, v = pcall(json.decode, raw)
    return ok and type(v) == 'table' and v or nil
end

-- Toutes les pièces portées (jamais le ventre de grossesse : readReal)
function C.ReadOutfit()
    local ped, out = PlayerPedId(), {}
    for _, s in ipairs(SLOTS) do out[s.id] = (ElyCloth.readReal or ElyCloth.read)(ped, s.type, s.index) end
    return out
end

local function Apply(pieces)
    local ped = PlayerPedId()
    local missing = 0
    for _, s in ipairs(SLOTS) do
        local p = pieces[s.id]
        if type(p) == 'table' and not ElyCloth.apply(ped, s.type, s.index, p) then missing = missing + 1 end
    end
    return missing
end

local function Anim()
    if C.LoadDict('clothingtie') and not IsPedInAnyVehicle(PlayerPedId(), false) then
        TaskPlayAnim(PlayerPedId(), 'clothingtie', 'try_tie_neutral_a', 6.0, -6.0, 1500, 48, 0, false, false, false)
        Wait(800)
    end
end

local function Civil()
    local o = civilian or Stored()
    Anim()
    if o then Apply(o)
    elseif GetResourceState('ely_creator') == 'started' then pcall(function() exports.ely_creator:ReloadSkin() end) end
    civilian = nil
    Store(nil)
    TriggerEvent('elyzea_clothing:wardrobeRefresh')
end
RegisterNetEvent('presse:client:civil', Civil)

-- ---------------------------------------------------------------------
-- Fenêtre du vestiaire
-- ---------------------------------------------------------------------
function C.OpenWardrobe()
    local r = C.Req('wardrobeList')
    if r.error then return C.Notify(r.error, 'error') end
    C.Focus('wardrobe', true)
    SendNUIMessage({ action = 'wardrobe', show = true, list = r.list, wearing = r.wearing })
end
C.ui.wardrobe = { close = function() C.Focus('wardrobe', false) SendNUIMessage({ action = 'wardrobe', show = false }) end }

RegisterNUICallback('wardrobeWear', function(body, cb)
    cb({})
    C.ui.wardrobe.close()
    if body.civil then return C.Do('wardrobeCivil') end
    local r = C.Req('wardrobeWear', { id = body.id })
    if r.error then return C.Notify(r.error, 'error') end
    if not civilian then
        civilian = Stored() or C.ReadOutfit()
        Store(civilian)
    end
    Anim()
    local missing = Apply(r.pieces or {})
    C.Notify(missing > 0 and ('%s mise (%d pièce(s) d\'un pack absent laissée(s) de côté).'):format(r.label, missing) or (r.label .. ' mise.'), missing > 0 and 'inform' or 'success')
end)

-- Direction : enregistrer la tenue portée comme tenue de la rédaction (tablette › Locaux)
RegisterNUICallback('outfitCapture', function(body, cb)
    cb(C.Req('outfitCapture', { id = body.id, pieces = C.ReadOutfit() }))
end)

-- Reconnexion après une déconnexion en tenue : vêtements d'avant remis
AddEventHandler('ely_creator:loaded', function()
    SetTimeout(1500, function()
        if Stored() and LocalPlayer.state.elyUniform ~= 'presse' then
            local o = Stored()
            Apply(o)
            Store(nil)
            civilian = nil
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and civilian then Apply(civilian) end
end)
