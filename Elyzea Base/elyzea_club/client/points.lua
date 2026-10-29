-- =====================================================================
--  ELYZEA BOÎTE DE NUIT - client : points des boîtes
--  · Entrée (tout joueur) : E → entrer (prix, bracelet, VIP, liste noire).
--  · Intérieur (facultatif) : E → sortir.
--  · Bar : employé (« bar ») → servir ; autres → voir la carte.
--  · Coffre (« stash »), Bureau (tablette) : employés de la boîte.
--  · Enceintes : employés (« music ») → platine DJ.
--  La liste est rechargée quand le serveur change sa version (GlobalState.clubVersion).
-- =====================================================================
local C = CLC
C.shops = {}
local version = -1
local blips = {}

local function Blips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    for _, s in ipairs(C.shops) do
        local p = s.door or s.bar
        if s.blip and p then
            local b = AddBlipForCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
            SetBlipSprite(b, s.blipSprite or 614) SetBlipColour(b, s.blipColor or 27) SetBlipScale(b, 0.85) SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(s.publicOpen and ('%s · ouvert'):format(s.name) or ('%s · fermé'):format(s.name))
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
        if C.OnShops then C.OnShops(C.shops) end
    end
end
CreateThread(function()
    Wait(3000)
    while true do
        local v = GlobalState.clubVersion
        if v and v ~= version then version = v Reload() end
        Wait(2000)
    end
end)
AddEventHandler('elyzea:client:playerLoaded', function() version = -1 end)
function C.ShopById(id) for _, s in ipairs(C.shops) do if s.id == id then return s end end end

-- ---------------------------------------------------------------------
-- Boucle : marqueurs et touche E
-- ---------------------------------------------------------------------
local COL = { door = { 217, 70, 239 }, inside = { 148, 163, 184 }, bar = { 245, 158, 11 }, stash = { 59, 130, 246 }, manage = { 34, 197, 94 } }
CreateThread(function()
    local st, stAt = nil, -1000   -- état employé relu au plus toutes les 500 ms
    while true do
        local sleep = 800
        if #C.shops > 0 and not C.AnyOpen() and not C.placing then
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
                    if d <= (p.r or 1.5) + 0.4 then prompt, action = text, fn end
                end
            end
            for _, s in ipairs(C.shops) do
                point(s.door, COL.door, ('~INPUT_CONTEXT~ Entrer · %s'):format(s.name), function() C.OpenEntry(s) end)
                if s.inside and s.door then point(s.inside, COL.inside, ('~INPUT_CONTEXT~ Sortir · %s'):format(s.name), function() C.Show(C.Pub('leave', { shop = s.id })) end) end
                if mine(s) and can('bar') then
                    point(s.bar, COL.bar, '~INPUT_CONTEXT~ Servir au bar', function() C.OpenBar() end)
                else
                    point(s.bar, COL.bar, ('~INPUT_CONTEXT~ Carte du bar · %s'):format(s.name), function() C.OpenMenuCard(s.id) end)
                end
                if mine(s) and can('stash') then point(s.stash, COL.stash, '~INPUT_CONTEXT~ Coffre de la boîte', function() C.Show(C.Req('stash')) end) end
                if mine(s) and can('tablet') then point(s.manage, COL.manage, '~INPUT_CONTEXT~ Bureau · tablette', function() C.OpenTablet() end) end
                -- Platine : près d'une enceinte de SA boîte
                if mine(s) and can('music') and not inVeh then
                    for _, sp in ipairs(s.speakers or {}) do
                        local d = #(pc - vector3(sp.x + 0.0, sp.y + 0.0, sp.z + 0.0))
                        if d < 3.0 then sleep = 0 prompt, action = '~INPUT_CONTEXT~ Platine DJ', function() C.OpenDj() end break end
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
