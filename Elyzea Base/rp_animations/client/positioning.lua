-- =====================================================================
--  rp_animations : positionnement des deux participants (client)
--
--  Principe : A reste sur place et sert de repère. B marche jusqu'à sa place (pas de téléportation),
--  puis il est attaché à A avec l'offset de l'étape : les deux restent alignés sans correction
--  permanente et le moteur réplique l'attache à tous les joueurs. Collision désactivée entre eux
--  pour qu'ils ne se repoussent pas.
-- =====================================================================
local P = {}
RPA.Pos = P
local cfg = Config.Positioning

-- Offset effectif d'une étape : réglage du staff (calibrage) sinon valeur du catalogue
function P.Offset(e, step, tuned)
    local t = tuned and tuned[tostring(step)]
    local o = t or (e.steps[step] and e.steps[step].off) or { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }
    return { x = o.x + 0.0, y = o.y + 0.0, z = o.z + 0.0, h = o.h + 0.0 }
end

function P.Target(pedA, off)
    local pos = GetOffsetFromEntityInWorldCoords(pedA, off.x, off.y, off.z)
    return pos, (GetEntityHeading(pedA) + off.h) % 360.0
end

-- Un mur ou un objet sur le chemin de B, ou entre A et la place de B ?
local function blocked(from, to, ignore)
    from, to = from + vector3(0.0, 0.0, 0.3), to + vector3(0.0, 0.0, 0.3)
    if #(to - from) < 0.25 then return false end
    local h = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, ignore, 7)
    local _, hit = GetShapeTestResult(h)
    return hit == 1
end

function P.Obstacle(pedA, pedB, pos)
    if not cfg.CheckObstacle then return false end
    return blocked(GetEntityCoords(pedB), pos, pedB) or blocked(GetEntityCoords(pedA), pos, pedA)
end

-- Le sol sous la place de B est à la même hauteur que sous A (pas de vide, pas de marche)
function P.GroundOk(pedA, pos)
    local a = GetEntityCoords(pedA)
    local okA, za = GetGroundZFor_3dCoord(a.x, a.y, a.z + 0.5, false)
    local okB, zb = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 0.5, false)
    if not okA or not okB then return true end   -- sol non chargé : on ne bloque pas pour ça
    return math.abs(za - zb) < 0.6
end

-- B marche vers sa place. Si l'offset est collé à A, on vise un point juste devant pour ne pas
-- le pousser ; l'attache finit le placement (petite correction, bornée par MaxSnap).
-- alive() renvoie false si la session a été annulée pendant la marche.
function P.WalkTo(ped, pedA, pos, heading, alive)
    local me = GetEntityCoords(ped)
    local aim = pos
    local a = GetEntityCoords(pedA)
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
    if not alive() then return false end
    return #(GetEntityCoords(ped) - pos) <= cfg.MaxSnap
end

-- Mêmes paramètres que les scripts de portage FiveM éprouvés : os racine, sans collision, vertexIndex 2
function P.Attach(pedB, pedA, off)
    AttachEntityToEntity(pedB, pedA, 0, off.x, off.y, off.z, 0.0, 0.0, off.h,
        false, false, false, false, 2, false)
end

function P.Detach(ped)
    if IsEntityAttached(ped) then
        DetachEntity(ped, true, false)
    end
end

-- À appeler à chaque image pendant la session : rien ne reste après la fin (thisFrameOnly)
function P.NoCollision(ped, other)
    if other and DoesEntityExist(other) then
        SetEntityNoCollisionEntity(ped, other, true)
    end
end
