local Shared = game:GetService("ReplicatedStorage").Shared
local P=require(Shared.Regras.Provacoes)
return {
 ["uma vaga por prova, outro aguarda e pode tentar apos liberar"]=function(t)
  local p=P.nova()
  t.eq(p.estado,"livre"); t.eq(P.iniciar(p,7,0,90),true)
  local ok,msg=P.iniciar(p,8,1,90)
  t.eq(ok,false); t.eq(msg,"Ocupado — aguarde"); t.eq(p.userId,7)
  P.liberar(p); t.eq(P.iniciar(p,8,2,90),true)
 end,
 ["aprovacao exige dono e respeita limite inclusivo"]=function(t)
  local p=P.nova(); P.iniciar(p,7,10,90)
  t.eq(P.tempo(p,20),80); t.eq(P.aprovar(p,8,50),false)
  t.eq(P.aprovar(p,7,99.99),true); t.eq(P.aprovado(p,7),true)
  t.eq(P.aprovar(p,7,99.99),false)
  P.liberar(p); P.iniciar(p,7,10,90)
  t.eq(P.aprovar(p,7,100),false); t.eq(p.estado,"falhou")
 end,
 ["sino reseta sem custo nem fim de tentativa, sem prazo"]=function(t)
  local p=P.nova(); P.iniciar(p,7,0)
  t.eq(P.pegarSino(p,8),false); t.eq(P.pegarSino(p,7),true)
  t.eq(p.sino,true); t.eq(P.pego(p,7),true); t.eq(p.sino,false)
  t.eq(P.expirar(p,1e9),false); t.eq(p.estado,"em-curso")
  t.eq(P.tempo(p,1e9),nil)
 end,
 ["provas independentes nao bloqueiam jogador distinto"]=function(t)
  local ladino,agua=P.nova(),P.nova()
  t.eq(P.iniciar(ladino,7,0),true); t.eq(P.iniciar(agua,8,0,90),true)
  t.eq(P.expirar(agua,90),true); t.eq(ladino.estado,"em-curso")
 end,
}
