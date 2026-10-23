-- SOMENTE STUDIO: AdminCombate com dependências isoladas; sem campanha real.
local A=require(script.Parent.Parent.AdminCombate)
local function fixture()
 local a={id="a",ownerUserId=1,x=5,z=5,pv=1,pvMax=10,mana=0,manaMax=8,pt=0,ptMax=4,version=1}
 local b={id="b",ownerUserId=2,x=6,z=5,pv=0,pvMax=20,mana=0,manaMax=6,version=1}
 local tokens={a=a,b=b};local mudancas,acoes,vez=0,0,0;local combat={active=true}
 local usar=A.start({tokens=tokens,combat=combat,mudou=function() mudancas+=1 end,
  bloqueada=function(x,z) return x==9 and z==9 end,
  mover=function(t,x,z) t.x,t.z=x,z end,
  pv=function(t,v) t.pv=v end,limpar=function(t) t.limpo=true end,
  acoes=function() acoes+=1 end,passar=function() vez+=1 end})
 return usar,a,b,combat,function() return mudancas,acoes,vez end
end
return {
 ["G7 ADM alvos explícitos, meus e todos durante combate"] = function(t)
  local usar,a,b=fixture();local p={UserId=1}
  t.eq(usar(p,"curar",{alvo="meus"}),nil);t.eq(a.pv,10);t.eq(b.pv,0)
  t.eq(usar(p,"reviver",{alvo="b"}),nil);t.eq(b.pv,20)
  t.eq(usar(p,"recursos",{alvo="todos"}),nil);t.eq(a.mana,8);t.eq(a.pt,4);t.eq(b.mana,6)
  t.eq(usar(p,"pv",{alvo="a",valor=999}),nil);t.eq(a.pv,10)
  t.eq(usar(p,"limpar",{alvo="todos"}),nil);t.ok(a.limpo);t.ok(b.limpo)
  t.ok(usar(p,"curar",{alvo="inexistente"})~=nil)
 end,
 ["G7 ADM mover recusa parede, ocupação e múltiplos sem alterar posição"] = function(t)
  local usar,a=fixture();local p={UserId=1}
  for _,args in {{alvo="a",x=9,z=9},{alvo="a",x=6,z=5},{alvo="todos",x=4,z=4}} do
   t.ok(usar(p,"mover",args)~=nil);t.eq(a.x,5);t.eq(a.z,5)
  end
  t.eq(usar(p,"mover",{alvo="a",x=4,z=4}),nil);t.eq(a.x,4);t.eq(a.z,4)
 end,
 ["G7 ADM Ações, passagem e voltar não exigem encerrar combate"] = function(t)
  local usar,a,b,combat,resultado=fixture();local p={UserId=1}
  t.eq(usar(p,"acoes",{}),nil);t.eq(usar(p,"passar",{}),nil)
  local _,acoes,vez=resultado();t.eq(acoes,1);t.eq(vez,1)
  t.eq(usar(p,"voltar",{}),nil);t.ok(a.x==1 or a.z==1 or a.x==20 or a.z==20);t.eq(b.x,6)
  combat.active=false;t.ok(usar(p,"acoes",{})~=nil)
 end,
}
