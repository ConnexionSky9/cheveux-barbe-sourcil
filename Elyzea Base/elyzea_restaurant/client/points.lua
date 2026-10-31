-- =====================================================================
--  ELYZEA RESTAURANT - client : points des restaurants
--  · Point de commande (tout joueur) : E → carte et panier.
--  · Stations de cuisine : employés du restaurant (« cook », en service) → E.
--  · Coffre (« stash »), Bureau (tablette) : employés du restaurant.
--  La liste est rechargée quand le serveur change sa version (GlobalState.restoVersion).
--  Boucle : 800 ms loin de tout point, chaque image seulement près d'un point.
-- =====================================================================
local C = RSC
C.shops = {}
local version = -1
local blips = {}

local function Blips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    for _, s in ipairs(C.shops) do
        local p = s.order
        if s.blip and p then
            local b = AddBlipForCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
            SetBlipSprite(b, s.blipSprite or 93) SetBlipColour(b, s.blipColor or 47) SetBlipScale(b, 0.8) SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(s.publicOpen and s.name or ('%s · fermé'):format(s.name))
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

local function Reload()
    local r = C.Pub('shops')
    if r.list then
        C.shops = r.list
        version = r.version or version
        Blips()
    end
end
CreateThread(function()
    Wait(3000)
    while true do
        local v = GlobalState.restoVersion
        if v and v ~= version then version = v Reload() end
        Wait(2000)
    end
end)
AddEventHandler('elyzea:client:playerLoaded', function() version = -1 end)
function C.ShopById(id) for _, s in ipairs(C.shops) do if s.id == id then return s end end end

local COL = { order = { 249, 115, 22 }, stash = { 59, 130, 246 }, manage = { 34, 197, 94 } }
local function StationColor(st)
    local t = Config.StationTypes[(st.types or {})[1] or '']
    return t and t.color or { 234, 179, 8 }
end
local function StationLabel(st)
    local out = {}
    for _, t in ipairs(st.types or {}) do out[#out + 1] = (Config.StationTypes[t] or {}).label or t end
    return table.concat(out, ' · ')
end

CreateThread(function()
    local st, stAt = nil, -1000   -- état employé relu au plus toutes les 500 ms
    while true do
        local sleep = 800
        if #C.shops > 0 and not C.AnyOpen() then
            local ped = PlayerPedId()
            local pc = GetEntityCoords(ped)
            local inVeh = GetVehiclePedIsIn(ped, false) ~= 0
            local now = GetGameTimer()
            if now - stAt >= 500 then st, stAt = C.State(), now end
            local mine = function(s) return st and st.shop == s.id end
            local can = function(perm) return st and st.perms and st.perms[perm] == true end
            local prompt, action
            local function point(p, col, text, fn)
                if not p or p.on == false or inVeh then return end
                local d = #(pc - C.Vec(p))
                if d < Config.Points.drawDistance then
                    sleep = 0
                    C.Circle(p, col, p.r)
                    if d <= (p.r or 1.2) + 0.4 then prompt, action = text, fn end
                end
            end
            for _, s in ipairs(C.shops) do
                point(s.order, COL.order, ('~INPUT_CONTEXT~ Commander · %s'):format(s.name), function() C.OpenOrder(s) end)
                if mine(s) then
                    if can('stash') then point(s.stash, COL.stash, '~INPUT_CONTEXT~ Coffre du restaurant', function() C.Show(C.Req('stash')) end) end
                    if can('tablet') then point(s.manage, COL.manage, '~INPUT_CONTEXT~ Bureau · tablette', function() C.OpenTablet() end) end
                    if can('cook') then
                        for _, k in ipairs(s.stations or {}) do
                            point(k, StationColor(k), ('~INPUT_CONTEXT~ Station · %s'):format(StationLabel(k)), function() C.OpenStation(s, k.i) end)
                        end
                    end
                end
            end
            if prompt then
                C.Help(prompt)
                if IsControlJustPressed(0, Config.Keys.interact) then action() end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end end
end)
