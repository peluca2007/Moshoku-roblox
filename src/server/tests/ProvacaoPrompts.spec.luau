local P=require(game:GetService("ReplicatedStorage").Shared.Regras.ProvacaoPrompts)
return {
 ["fora da provação somente Falar está habilitado"]=function(t)
  for _,r in {false,{npcId="vila-1",estado="falhou"},{npcId="vila-1",estado="aprovado"},{npcId="vila-2",estado="em-curso"}} do
   t.eq(P.habilitado("falar",r),true)
   t.eq(P.habilitado("sino",r),false); t.eq(P.habilitado("portao",r),false)
  end
 end,
 ["durante Ladino portão tem E exclusivo do Falar; sino acompanha posse"]=function(t)
  local r={npcId="vila-1",estado="em-curso",sino=false}
  t.eq(P.habilitado("falar",r),false); t.eq(P.habilitado("sino",r),true); t.eq(P.habilitado("portao",r),true)
  r.sino=true; t.eq(P.habilitado("sino",r),false); t.eq(P.habilitado("portao",r),true)
  t.eq(P.habilitado("falar",nil),true,"a tentativa de outro jogador não participa desta projeção")
 end,
}
