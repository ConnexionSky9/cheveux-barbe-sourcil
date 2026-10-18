-- =========================================================
--  ELYZEA ANIMAUX - CLIENT : textures réellement disponibles
--  On crée un animal local invisible pour lire ce que le modèle
--  contient vraiment (GetNumberOfPed…Variations). Sert à :
--   · n'afficher en boutique que les pelages qui existent ;
--   · le scan staff (/animaux_scan) enregistré pour le diagnostic.
-- =========================================================
local cache = {}   -- [modèle] = { exists, comps = { ['0'] = { drawables, textures = { ['0'] = n } } } }

local function probe(model)
    if cache[model] then return cache[model] end
    local hash = C.LoadModel(model, 8000)
    if not hash then
        cache[model] = { exists = false, comps = {} }
        return cache[model]
    end
    local p = GetEntityCoords(PlayerPedId())
    local ped = CreatePed(28, hash, p.x, p.y, p.z - 30.0, 0.0, false, false)
    local r = { exists = true, comps = {} }
    if ped and ped ~= 0 then
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)
        for c = 0, 11 do
            local n = GetNumberOfPedDrawableVariations(ped, c)
            if n and n > 0 then
                local tex = {}
                for d = 0, math.min(n, 50) - 1 do tex[tostring(d)] = GetNumberOfPedTextureVariations(ped, c, d) end
                r.comps[tostring(c)] = { drawables = n, textures = tex }
            end
        end
        DeleteEntity(ped)
    end
    SetModelAsNoLongerNeeded(hash)
    cache[model] = r
    return r
end
C.Probe = probe

-- Le pelage existe-t-il vraiment sur ce client ?
function C.VariantExists(v)
    local r = probe(v.model)
    if not r.exists then return false end
    local comp = r.comps[tostring(v.c or 0)]
    if not comp then return (v.c or 0) == 0 and (v.d or 0) == 0 and (v.t or 0) == 0 end
    return (v.d or 0) < comp.drawables and (v.t or 0) < (comp.textures[tostring(v.d or 0)] or 0)
end

RegisterNetEvent('elyzea_animaux:client:scan', function(models)
    if type(models) ~= 'table' then return end
    CreateThread(function()
        local out = {}
        for _, m in ipairs(models) do
            if type(m) == 'string' then
                cache[m] = nil
                out[m] = probe(m)
            end
        end
        TriggerServerEvent('elyzea_animaux:server:scanResult', out)
    end)
end)
