-- =====================================================================
--  Danses : positionnement des danseurs (client)
--
--  Duo : le meneur (A) reste sur place. Le partenaire (B) marche jusqu'à sa place (pas de téléportation),
--  puis il est attaché au meneur exactement comme le fait rpemotes pour ces animations (même os, même
--  position, même rotation, mêmes paramètres). Les deux restent alignés sans correction permanente, et
--  le moteur réplique l'attache chez tous les joueurs.
--  Groupe : chacun marche jusqu'à sa place dans la formation, tourné comme prévu (pas d'attache).
-- =====================================================================
local P = {}
Danse.Pos = P
local cfg = DanseConfig.Positioning

-- Position effective d'une étape de duo : réglage du staff (calibrage) sinon valeur du catalogue
function P.Offset(e, step, tuned)
    local st = e.steps[step]
    local base = (st and st.off) or { x = 0.0, y = 0.0, z = 0.0, h = 0.0, bone = -1 }
    local t = tuned and tuned[tostring(step)]
    local o = t or base
    return { x = o.x + 0.0, y = o.y + 0.0, z = o.z + 0.0, h = o.h + 0.0, bone = base.bone or -1 }
end

-- Position monde d'un décalage (x droite, y devant, z) par rapport au meneur, et cap correspondant
function P.Target(pedA, x, y, z, h)
    local pos = GetOffsetFromEntityInWorldCoords(pedA, x, y, z)
    return pos, (GetEntityHeading(pedA) + h) % 360.0
end

local function blocked(from, to, ignore)
    from, to = from + vector3(0.0, 0.0, 0.3), to + vector3(0.0, 0.0, 0.3)
    if #(to - from) < 0.25 then return false end
    local h = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, ignore, 7)
    local _, hit = GetShapeTestResult(h)
    return hit == 1
end

-- Un mur ou un objet sur le chemin de B, ou entre le meneur et la place de B ?
function P.Obstacle(pedA, pedB, pos)
    if not cfg.CheckObstacle then return false end
    return blocked(GetEntityCoords(pedB), pos, pedB) or blocked(GetEntityCoords(pedA), pos, pedA)
end

-- Le sol sous la place est à la même hauteur que sous le meneur (pas de vide, pas de marche)
function P.GroundOk(pedA, pos)
    local a = GetEntityCoords(pedA)
    local okA, za = GetGroundZFor_3dCoord(a.x, a.y, a.z + 0.5, false)
    local okB, zb = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 0.5, false)
    if not okA or not okB then return true end   -- sol non chargé : on ne bloque pas pour ça
    return math.abs(za - zb) < 0.6
end

-- Marche vers une place. Si la place est collée au meneur, on vise juste devant pour ne pas le pousser ;
-- l'attache finit le placement. alive() renvoie false si la danse a été annulée pendant la marche.
-- Renvoie la distance restante à la place.
function P.WalkTo(ped, pedA, pos, heading, alive)
    local me, a = GetEntityCoords(ped), GetEntityCoords(pedA)
    local aim = pos
    if #(pos - a) < 0.6 then
        local dir = me - a
        local len = #dir
        aim = len > 0.01 and (pos + dir / len * 0.55) or pos
    end
    if #(me - aim) > cfg.SnapDistance then
        TaskGoStraightToCoord(ped, aim.x, aim.y, aim.z, cfg.WalkSpeed, cfg.WalkTimeout, heading, 0.05)
        local t = GetGameTimer() + cfg.WalkTimeout
        while alive() and GetGameTimer() < t and #(GetEntityCoords(ped) - aim) > 0.25 do Wait(50) end
        ClearPedTasks(ped)
    end
    return #(GetEntityCoords(ped) - pos)
end

-- Attache identique à rpemotes (Syncing.lua) : os du meneur, rotation relative, isPed = true, fixedRot = true
function P.Attach(pedB, pedA, off)
    AttachEntityToEntity(pedB, pedA, GetPedBoneIndex(pedA, off.bone or -1), off.x, off.y, off.z, 0.0, 0.0, off.h,
        false, false, false, true, 1, true)
end

function P.Detach(ped)
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
end

-- À appeler à chaque image pendant la danse : rien ne reste après la fin (thisFrameOnly)
function P.NoCollision(ped, other)
    if other and DoesEntityExist(other) then SetEntityNoCollisionEntity(ped, other, true) end
end
