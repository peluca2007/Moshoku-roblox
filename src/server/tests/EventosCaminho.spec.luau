local Shared = game:GetService("ReplicatedStorage").Shared
local S = require(Shared.Regras.RunSessao)
local C = require(Shared.Mundo.EventosCaminho)
local Eventos = require(Shared.Mundo.ViagemEventosV1)
local function nova(guardar)
 local s=S.new({mundoAberto=true,eventos=Eventos,rng={NextInteger=function(_,lo) return lo end},guardar=guardar or function() end})
 s:iniciar("g",{{userId=11}},{[11]="semArvore"})
 return s
end
return {
 ["vitória e coleta do selo não reiniciam chefe nem teleportam retorno"] = function(t)
  local s=nova()
  s:presencaNoMundo(11,0,-400)
  t.eq(s:votar(11,"enfrentar-o-guardiao"),true)
  t.ok(s:lutaPendente())
  t.eq(s:lutaTerminou("victory"),true)
  t.eq(s:votar(11,"pegar-o-selo"),true)
  t.eq(s:lutaPendente(),nil)
  t.eq(s.run.galho,"chefe-floresta")
  t.eq(s.run.dia,0)
  s:presencaNoMundo(11,-8,-175)
  t.eq(s.run.galho,"retorno")
  t.eq(s:votar(11,"entregar-o-selo"),true)
  t.eq(s.run.fim.motivo,"final")
 end,
 ["viagem de destino nao aparece nem pode ser votada"] = function(t)
  local s=nova();t.eq(#s:visao(11).opcoes,0);t.eq(s:votar(11,"rumo-a-floresta"),false)
  t.eq(s.run.regiao,"vila");t.eq(s.run.dia,0)
 end,
 ["primeira presenca no trecho dispara F8 uma vez por run e salva flag"] = function(t)
  local s=nova();local trecho=C.TRECHOS[1]
  t.eq(s:presencaNoMundo(11,trecho.x,trecho.z),true)
  t.ok(s.evento~=nil);t.eq(s:visao(11).viagem,nil)
  local opcao=s:visao(11).opcoes[1].id
  t.eq(s:votar(11,opcao),true)
  t.eq(s.run.flags["caminho/"..trecho.id],true)
  t.eq(s:presencaNoMundo(11,trecho.x,trecho.z),false)
  t.eq(s.evento,nil)
 end,
 ["andar muda regiao sem custo artificial e retorno exige selo"] = function(t)
  local s=nova();s:presencaNoMundo(11,0,-400)
  t.eq(s.run.regiao,"floresta-sombria");t.eq(s.run.dia,0)
  t.eq(s:votar(11,"voltar"),false)
  s:presencaNoMundo(11,-8,-175);t.eq(s.run.galho,"vila")
  s.run.flags["selo-obtido"]=true
  s:presencaNoMundo(11,600,-220);t.eq(s.run.regiao,"ruinas-do-vale")
  s:presencaNoMundo(11,-8,-175);t.eq(s.run.galho,"retorno")
  t.eq(s:visao(11).opcoes[1].id,"entregar-o-selo")
 end,
 ["tick pausa em combate e descanso faz rollback no save falho"] = function(t)
  local falha=false
  local s=nova(function() if falha then error("save") end end)
  s:avancarTempo(120,false);t.eq(s.run.dia,0.25)
  s:avancarTempo(480,true);t.eq(s.run.dia,0.25)
  falha=true;t.eq(s:descansar(11,"longo"),false);t.eq(s.run.dia,0.25)
  falha=false;t.eq(s:descansar(11,"longo"),true);t.eq(s.run.dia,1)
 end,
}
