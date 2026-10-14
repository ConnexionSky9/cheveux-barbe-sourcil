-- NOIR X — Police Hack RP. Les opérations sont simulées en jeu ; les rapports MDT
-- ne sont touchés qu'au travers d'un adaptateur explicitement configuré.
PoliceHack = { sessions = {}, cooldowns = {} }
local PH = PoliceHack
local function cfg() return Config.PoliceHack end
local function now() return os.time() end
local function srcForChar(charId) return Players.SrcOf(charId) end
local function playerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local p = GetEntityCoords(ped)
    return p and { x=p.x, y=p.y, z=p.z } or nil
end
local function dist(a,b)
    local x,y,z=a.x-b.x,a.y-b.y,a.z-b.z
    return math.sqrt(x*x+y*y+z*z)
end
local function isPolice(src)
    -- Le serveur police peut surcharger ce contrôle via l'export documenté ci-dessous.
    local resource = cfg().adapterResource
    if resource ~= '' and GetResourceState(resource) == 'started' then
        local ok, result = pcall(function() return exports[resource]:IsPolice(src) end)
        if ok and result ~= nil then return result == true end
    end
    return IsPlayerAceAllowed(src, 'noirx.policehack.defend')
end
local function adapterReady()
    local r = cfg().adapterResource
    return r ~= '' and GetResourceState(r) == 'started'
end
local function dispatch(src)
    local c=cfg()
    -- Alerte dans le dispatch d'elyzea_police (carte, GPS, tablette)
    local pos = playerPos(src)
    if pos and GetResourceState('elyzea_police') == 'started' then
        pcall(function() exports.elyzea_police:SendAlert('other', pos, 'Intrusion MDT', 'Tentative de piratage du serveur de police : intervention requise.', nil, {}) end)
    end
    if c.dispatchEvent and c.dispatchEvent ~= '' then
        TriggerEvent(c.dispatchEvent, { source=src, coords=playerPos(src), message='Tentative de piratage du MDT — intervention requise.' })
    end
    for _, id in ipairs(GetPlayers()) do
        local target=tonumber(id)
        if target and isPolice(target) then
            Push.Notify(target, 'ALERTE MDT', 'Tentative de piratage du serveur de police. Défendez le MDT !', 'alert')
            Push.ToSrc(target, 'policehack:warning', { remainingMs=c.warningSeconds*1000 })
        end
    end
end
local function makeLine()
    return Launder.GenerateLine(34, 46)
end
local function startDuel(s)
    s.line=makeLine(); s.duelEnds=now()+cfg().duelSeconds; s.startedMs=GetGameTimer()
    local a=srcForChar(s.attacker); local d=s.defender and srcForChar(s.defender)
    if a then Push.ToSrc(a,'duel:start',{attack='ph:'..s.id,role='attacker',line=s.line,windowMs=cfg().duelSeconds*1000,remainingMs=cfg().duelSeconds*1000}) end
    if d then Push.ToSrc(d,'duel:start',{attack='ph:'..s.id,role='defender',line=s.line,windowMs=cfg().duelSeconds*1000,remainingMs=cfg().duelSeconds*1000}) end
end
local function adapterCall(method, ...)
    local r=cfg().adapterResource
    if r=='' or GetResourceState(r)~='started' then return false, 'Adaptateur MDT non configuré.' end
    local args = { ... }
    local ok, result = pcall(function()
        return exports[r][method](exports[r], table.unpack(args))
    end)
    if not ok then return false, 'Erreur de l’adaptateur MDT.' end
    return true, result
end
Rpc.Register('policehack.status',{app='policehack',rate={8,10}},function(src,ctx)
    local c=cfg(); local p=playerPos(src); local cd=PH.cooldowns[ctx.charId] or 0
    local up=Upgrades.Get(ctx.charId); local radius=Config.Upgrades.policeHackRadius[(up.policeRadiusLevel or 0)+1] or c.radius
    local d=p and dist(p,{x=c.station.x,y=c.station.y,z=c.station.z}) or math.huge
    return {ok=true,price=c.price,currency=c.currency,radius=radius,warningSeconds=c.warningSeconds,
      accessSeconds=c.accessSeconds,cooldownSeconds=c.cooldownSeconds,cooldown=math.max(0,cd-now()),
      canStart=c.enabled and d<=radius and now()>=cd and not PH.sessions[ctx.charId],
      distance=math.floor(d),adapterReady=adapterReady()}
end)
Rpc.Register('policehack.start',{app='policehack',rate={2,30}},function(src,ctx)
    local c=cfg(); if not c.enabled then return Rpc.Fail('disabled','Intrusion désactivée.') end
    local up=Upgrades.Get(ctx.charId); local radius=Config.Upgrades.policeHackRadius[(up.policeRadiusLevel or 0)+1] or c.radius
    local cd=PH.cooldowns[ctx.charId] or 0
    if now()<cd then return Rpc.Fail('cooldown',('Attends %d secondes.'):format(cd-now())) end
    if PH.sessions[ctx.charId] then return Rpc.Fail('busy','Tu as déjà une intrusion en cours.') end
    local p=playerPos(src); if not p or dist(p,{x=c.station.x,y=c.station.y,z=c.station.z})>radius then return Rpc.Fail('distance','Tu es trop loin du commissariat selon ton niveau d’amélioration.') end
    if not Wallet.Charge(src,c.currency,c.price,'policehack') then return Rpc.Fail('funds','Fonds insuffisants pour lancer le hack.') end
    local id=('%s:%s'):format(ctx.charId,now())
    local s={id=id,attacker=ctx.charId,attackerSrc=src,created=now(),phase='warning',defender=nil,deleted=false}
    PH.sessions[ctx.charId]=s; PH.cooldowns[ctx.charId]=now()+c.cooldownSeconds
    dispatch(src)
    Push.ToSrc(src,'policehack:warning',{remainingMs=c.warningSeconds*1000})
    SetTimeout(c.warningSeconds*1000,function()
      if PH.sessions[ctx.charId]~=s then return end
      s.phase='duel'; s.duelEnds=now()+cfg().duelSeconds+2; s.startedMs=GetGameTimer()
      -- Une défense peut être prise par un policier connecté ayant l'ACE configuré.
      local officers=GetPlayers()
      for _,v in ipairs(officers) do local officer=tonumber(v); if officer and isPolice(officer) then
        local ch=Players.CharOf(officer)
        if ch then s.defender=ch; Phone.OpenDefense(officer); break end
      end end
      -- laisse le temps au terminal de défense de s'ouvrir chez le policier
      SetTimeout(800, function() if PH.sessions[ctx.charId]==s and s.phase=='duel' then startDuel(s) end end)
    end)
    return {ok=true,message='Intrusion lancée.'}
end)
Rpc.Register('policehack.reports',{app='policehack',rate={4,10}},function(src,ctx)
    local s=PH.sessions[ctx.charId]
    if not s or s.phase~='access' or s.accessUntil<now() or s.deleted then return Rpc.Fail('locked','Fenêtre d’accès fermée ou aucune victoire.') end
    local ok,rows=adapterCall('ListReports',src)
    if not ok then return Rpc.Fail('adapter',rows) end
    return {ok=true,reports=type(rows)=='table' and rows or {}}
end)
Rpc.Register('policehack.deleteReport',{app='policehack',rate={1,30}},function(src,ctx,args)
    local s=PH.sessions[ctx.charId]
    if not s or s.phase~='access' or s.accessUntil<now() or s.deleted then return Rpc.Fail('locked','Accès fermé ou suppression déjà utilisée.') end
    local id=(type(args.id)=='string' or type(args.id)=='number') and tostring(args.id) or nil
    if not id then return Rpc.Fail('bad_args','Identifiant de dossier invalide.') end
    local ok,result=adapterCall('DeleteReport',src,id)
    if not ok or result~=true then return Rpc.Fail('adapter',ok and 'Le MDT a refusé la suppression.' or result) end
    s.deleted=true
    Audit.Log(src,'policehack.report_deleted',{session=s.id,report=id})
    return {ok=true}
end)
-- Session du duel : celle du pirate, ou celle que ce policier défend
local function sessionOf(charId)
    if PH.sessions[charId] then return PH.sessions[charId] end
    for _, s in pairs(PH.sessions) do if s.defender == charId then return s end end
    return nil
end
Rpc.Register('policehack.duelSubmit',{app='policehack',rate={12,10},auth=false},function(src,ctx,args)
    local s=sessionOf(ctx.charId)
    if not s or s.phase~='duel' or now()>s.duelEnds then return Rpc.Fail('over','Le duel est terminé.') end
    local role=ctx.charId==s.attacker and 'attacker' or (ctx.charId==s.defender and 'defender' or nil)
    if not role then return Rpc.Fail('forbidden','Tu ne participes pas à ce duel.') end
    if type(args.text)~='string' or args.text~=s.line then return {ok=true,correct=false} end
    if GetGameTimer()-s.startedMs < Launder.MinHumanMs(s.line) then return Rpc.Fail('too_fast','Séquence trop rapide.') end
    local winner=role
    local winnerChar=ctx.charId
    local winnerSrc=src
    s.phase='finished'
    if winner=='attacker' then
      s.phase='access'; s.accessUntil=now()+cfg().accessSeconds
      Push.ToSrc(src,'policehack:access',{remaining=cfg().accessSeconds})
    else
      local target=srcForChar(s.attacker)
      if target then
        local pos=playerPos(target)
        if pos then
          local radius=0.0
          local upgrades=Upgrades and Upgrades.Get and Upgrades.Get(ctx.charId) or { revealLevel=0 }
          radius=(Config.Upgrades.revealRadius[(upgrades.revealLevel or 0)+1] or 0.0)+0.0
          if radius>0 then
            local angle=math.random()*math.pi*2
            local distance=math.sqrt(math.random())*radius
            pos.x=pos.x+math.cos(angle)*distance
            pos.y=pos.y+math.sin(angle)*distance
          end
          TriggerClientEvent('noirx:policehack:trace', winnerSrc, pos, 30)
        end
      end
    end
    local attackKey = 'ph:' .. s.id
    local attackerSrc = srcForChar(s.attacker)
    local defenderSrc = s.defender and srcForChar(s.defender) or nil
    if attackerSrc then Push.ToSrc(attackerSrc, 'duel:end', { attack=attackKey, role='attacker', won=winner=='attacker', reason=winner=='defender' and 'defended' or nil }) end
    if defenderSrc then Push.ToSrc(defenderSrc, 'duel:end', { attack=attackKey, role='defender', won=winner=='defender', reason=winner=='attacker' and 'compromised' or nil }) end
    if winner=='defender' then PH.sessions[s.attacker]=nil else PH.sessions[s.attacker]=s end
    return {ok=true,correct=true}
end)
CreateThread(function()
  while true do
    Wait(1000)
    for char,s in pairs(PH.sessions) do
      if s.phase=='duel' and now()>s.duelEnds then
        s.phase='finished'; PH.sessions[char]=nil
        local a=srcForChar(s.attacker); if a then Push.ToSrc(a,'duel:end',{attack='ph:'..s.id,role='attacker',won=false,reason='timeout'}) end
        if s.defender then local d=srcForChar(s.defender); if d then Push.ToSrc(d,'duel:end',{attack='ph:'..s.id,role='defender',won=true}) end end
      elseif s.phase=='access' and s.accessUntil<now() then PH.sessions[char]=nil end
    end
  end
end)
