-- NOIR X — progression des améliorations (sauvegarde SQL).
Upgrades = { cache = {} }
local U = Upgrades
local function defaults() return { policeRadiusLevel=0, defenseLevel=0, revealLevel=0, intelLevel=0 } end
function U.Get(charId)
  if U.cache[charId] then return U.cache[charId] end
  local value=defaults()
  if DB.driver~='none' then
    local row=DB.Single('SELECT police_radius, defense_level, reveal_level, intel_level FROM noirx_upgrades WHERE char_id = ?', {charId})
    if row then value.policeRadiusLevel=tonumber(row.police_radius) or 0; value.defenseLevel=tonumber(row.defense_level) or 0; value.revealLevel=tonumber(row.reveal_level) or 0; value.intelLevel=tonumber(row.intel_level) or 0 end
  end
  U.cache[charId]=value; return value
end
local keys={policeRadiusLevel='police_radius',defenseLevel='defense_level',revealLevel='reveal_level',intelLevel='intel_level'}
local function save(charId,v)
  return DB.Execute([[INSERT INTO noirx_upgrades (char_id, police_radius, defense_level, reveal_level, intel_level)
    VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE police_radius=VALUES(police_radius), defense_level=VALUES(defense_level), reveal_level=VALUES(reveal_level), intel_level=VALUES(intel_level)]],
    {charId,v.policeRadiusLevel,v.defenseLevel,v.revealLevel,v.intelLevel})
end
Rpc.Register('upgrades.status',{db=true,rate={8,10}},function(src,ctx)
  local c=Config.Upgrades; if not c.enabled then return Rpc.Fail('disabled','Améliorations désactivées.') end
  local wallet=Wallet.Get(src)
  return {ok=true,levels=U.Get(ctx.charId),costs=c.costs,currency=c.currency,balance=c.currency=='dirty' and wallet.dirty or wallet.clean}
end)
Rpc.Register('upgrades.buy',{db=true,rate={4,10}},function(src,ctx,args)
  local c=Config.Upgrades
  if not c.enabled then return Rpc.Fail('disabled','Améliorations désactivées.') end
  if type(args.upgrade)~='string' or not keys[args.upgrade] then return Rpc.Fail('bad_args','Amélioration inconnue.') end
  local v=U.Get(ctx.charId); local lvl=v[args.upgrade] or 0
  if lvl>=5 then return Rpc.Fail('max','Niveau maximum atteint.') end
  local cost=c.costs[lvl+1] or 0
  if not Wallet.Charge(src,c.currency,cost,'noirx_upgrade:'..args.upgrade) then return Rpc.Fail('funds','Fonds insuffisants.') end
  v[args.upgrade]=lvl+1
  if DB.driver=='none' then v[args.upgrade]=lvl; return Rpc.Fail('database','Base de données non configurée : impossible de sauvegarder les niveaux.') end
  save(ctx.charId,v)
  Audit.Log(src,'upgrade_purchased',{upgrade=args.upgrade,level=lvl+1,cost=cost})
  return {ok=true,level=lvl+1}
end)
