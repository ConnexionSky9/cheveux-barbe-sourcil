-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - client : entrée, contrôle du videur, annonces
-- =====================================================================
local C = CLC

-- ---------------------------------------------------------------------
-- Entrée (tout joueur)
-- ---------------------------------------------------------------------
local entry = nil
local function CloseEntry()
    if not entry then return end
    entry = nil
    C.Focus('entry', false)
    SendNUIMessage({ action = 'entry', show = false })
end
C.ui.entry = { close = CloseEntry }

function C.OpenEntry(s)
    if C.AnyOpen() then return end
    local r = C.Pub('entryInfo', { shop = s.id })
    if r.error then return C.Notify(r.error, 'error') end
    -- Personnel, bracelet, VIP : on entre directement
    if r.staff or r.band or (r.vip and r.open) then return C.Show(C.Pub('enter', { shop = s.id })) end
    entry = { shop = s.id }
    C.Focus('entry', true)
    r.id = s.id
    SendNUIMessage({ action = 'entry', show = true, data = r })
end
RegisterNUICallback('enter', function(body, cb)
    if not entry then return cb({}) end
    local r = C.Pub('enter', { shop = entry.shop, method = body.method == 'cash' and 'cash' or 'bank' })
    C.Show(r)
    if r.ok then CloseEntry() end
    cb(r)
end)

-- ---------------------------------------------------------------------
-- Annonce d'une boîte : bandeau pour toute la ville
-- ---------------------------------------------------------------------
RegisterNetEvent('club:client:announce', function(a)
    SendNUIMessage({ action = 'announce', data = a })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)

-- Statut rapide (utilisé par le bar et la platine)
AddEventHandler('club:client:status', function(id)
    if C.OnDuty() then
        local s = C.State()
        if s and s.status ~= id then C.Req('status', { status = id }) end
    end
end)
