-- =====================================================================
--  ELYZEA TV - télécommande (panneau à l'écran) : coller un lien YouTube, pause, reprise, volume, éteindre
-- =====================================================================
local C = Config
local cur = nil     -- { key, name, pos }

local function stateFor(key)
    local st = TVC.states[key]
    if not st then return nil end
    return { id = st.id, paused = st.paused == true, volume = st.volume or 0, by = st.by, position = math.floor(TVC.Position(st)) }
end
local function push()
    if not cur then return end
    SendNUIMessage({ action = 'remote', open = true, name = cur.name, state = stateFor(cur.key) })
end

function TVC.OpenRemote(key, name, pos)
    cur = { key = key, name = name, pos = pos }
    TVC.uiOpen = true
    TVC.HidePrompt()
    SetNuiFocus(true, true)
    push()
    -- la télécommande se ferme si on s'éloigne trop
    CreateThread(function()
        local mine = cur
        while cur == mine do
            local p = GetEntityCoords(PlayerPedId())
            local limit = key:match('^s%d+$') and (C.Custom.remoteDistance + 3.0) or (C.Flat.controlDistance + 3.0)
            local ref = pos
            if key:match('^s%d+$') then
                local s = TVC.screens[tonumber(key:match('^s(%d+)$'))]
                ref = s and s.data.remote and vector3(s.data.remote.x, s.data.remote.y, s.data.remote.z) or pos
            end
            if ref and #(p - ref) > limit then TVC.CloseRemote() break end
            Wait(500)
        end
    end)
end
function TVC.CloseRemote()
    cur = nil
    TVC.uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'remote', open = false })
end

-- l'état change (par moi ou quelqu'un d'autre) : le panneau suit
local prev = TVC.OnState
TVC.OnState = function(key, st)
    if prev then prev(key, st) end
    if cur and cur.key == key then push() end
end

RegisterNUICallback('remote', function(d, cb)
    cb({ ok = true })
    if not cur or type(d) ~= 'table' then return end
    local key = cur.key
    local st = TVC.states[key]
    CreateThread(function()
        local cmd = tostring(d.cmd or '')
        if cmd == 'play' then TVC.Play(key, tostring(d.url or ''))
        elseif cmd == 'pause' then TVC.Control(key, 'pause')
        elseif cmd == 'resume' then TVC.Control(key, 'resume')
        elseif cmd == 'stop' then TVC.Control(key, 'stop')
        elseif cmd == 'volume' then TVC.Control(key, 'volume', math.floor(tonumber(d.v) or 0))
        elseif cmd == 'seek' and st then TVC.Control(key, 'seek', tonumber(d.by) or 0)
        elseif cmd == 'close' then TVC.CloseRemote() end
        push()
    end)
end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and cur then SetNuiFocus(false, false) end end)
