local C = require(game:GetService("ReplicatedStorage").Shared.AdminComandos)
return {
 ["ajuda e catálogo fechado"] = function(t)
  t.eq(C.parse("/adm"),"ajuda");t.eq(C.parse(" /adm FESTA "),"festa")
  for _,c in C.LISTA do
   local texto="/adm "..c.id..(if c.alvo then " meus" elseif c.jogadorAlvo then " todos" else "")..(if c.valor then " 10" else "")..(if c.casa then " 2 3" else "")
   t.eq(C.parse(texto),c.id)
  end
 end,
 ["argumentos de chat e painel geram a mesma intenção"] = function(t)
  local id,erro,a=C.parse("/adm pv Token-A 30");t.eq(id,"pv");t.eq(erro,nil);t.eq(a.alvo,"Token-A");t.eq(a.valor,30)
  local i,e,b=C.parse({comando="mover",alvo="a",x=1,z=20});t.eq(i,"mover");t.eq(e,nil);t.eq(b.z,20)
  t.eq(C.parse("curar todos"),"curar")
 end,
 ["diversão aceita eu, todos, nome e UserId; modo não recebe alvo"] = function(t)
  local _,_,a=C.parse("/adm gigante");t.eq(a.alvo,"eu")
  _,_,a=C.parse("raio Pedro_123");t.eq(a.alvo,"Pedro_123")
  _,_,a=C.parse({comando="dados",alvo="2287856135"});t.eq(a.alvo,"2287856135")
  _,_,a=C.parse({comando="coroa"});t.eq(a.alvo,"eu")
  t.eq(C.parse("jogador"),"jogador");t.eq(C.parse({comando="mestre"}),"mestre")
  for _,c in C.LISTA do if c.diversao then t.ok(c.jogadorAlvo,c.id) end end
 end,
 ["rejeita valores, campos, tipos, coordenadas e código inválidos"] = function(t)
  for _,v in {"/adm loadstring()","/admin festa",string.rep("x",161),{},12,true,
   "pv meus","pv a -1","mana a nan","pt a 2.5","mover a 0 1","mover a 1 21","curar a extra",
   {comando="festa",alvo="a b"},{comando="festa",alvo="<b>x</b>"},{comando="festa",alvo=string.rep("a",41)},
   "gigante eu extra",{comando="mestre",alvo="eu"},"jogador eu",
   {comando="curar",alvo={}},{comando="pv",alvo="a",valor=0/0},
   {comando="pv",alvo="a",valor=math.huge},{comando="curar",codigo="print(1)"}} do
   local id,erro=C.parse(v);t.eq(id,nil);t.ok(type(erro)=="string")
  end
 end,
}
