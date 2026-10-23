local Shared = game:GetService("ReplicatedStorage").Shared
local C = require(Shared.Regras.Cacadas)
local E = require(Shared.EncontrosPorZona)
local Elenco = require(Shared.EncontroAutonomoElenco)
local CriaturasDados = require(Shared.Livro.Dados.Criaturas)
local porId = {}
for _, d in ipairs(CriaturasDados) do porId[d.id] = d end
local Criaturas = require(Shared.Regras.Criaturas)
local rng = { NextInteger=function(_,minimo) return minimo end }
return {
 ["save de cacadas valida estrutura jogadores e recibos"] = function(t)
  local localStudio = C.novo(rng)
  t.eq(C.aceitar(localStudio,-1,"ratos-celeiro"),true)
  t.eq(C.estadoValido(localStudio,{[-1]={}}),true)
  t.eq(C.estadoValido(localStudio,{[1]={}}),false)
  t.eq(C.estadoValido(nil),true)
  local e = C.novo(rng)
  t.eq(C.estadoValido(e,{[1]={}}),true)
  C.aceitar(e,1,"ratos-celeiro")
  t.eq(C.estadoValido(e,{[2]={}}),false)
  t.eq(C.estadoValido(e,{[1]={}}),true)
  C.concluir(e,1,"ratos-celeiro","encontro-a")
  t.eq(C.estadoValido(e,{[1]={}}),true)
  e.conclusoes["sem-separador"] = true
  t.eq(C.estadoValido(e),false)
  e.conclusoes["sem-separador"] = nil
  e.ofertas[3] = e.ofertas[1]
  t.eq(C.estadoValido(e),false)
  e = C.novo(rng); e.ofertas[4] = "ratos-horta"
  t.eq(C.estadoValido(e),false)
  e = C.novo(rng); e.aceitas = false
  t.eq(C.estadoValido(e),false)
  t.eq(C.bonus(e,1,"ratos-celeiro"),0)
  t.eq(C.aceitar(e,1,"ratos-celeiro"),false)
  t.eq(C.concluir(e,1,"ratos-celeiro","a"),false)
  e = C.novo(rng); e.geracao = 0/0
  t.eq(C.estadoValido(e),false)
 end,
 ["save de reaparecimento recusa ids falsos e tempos invalidos"] = function(t)
  t.eq(C.patrulhasValidas(nil),true)
  t.eq(C.patrulhasValidas({["ratos-celeiro"]=120.5}),true)
  t.eq(C.patrulhasValidas({inventada=1}),false)
  t.eq(C.patrulhasValidas({["ratos-celeiro"]=-1}),false)
  t.eq(C.patrulhasValidas({["ratos-celeiro"]=math.huge}),false)
  t.eq(C.patrulhasValidas({["ratos-celeiro"]=0/0}),false)
 end,
 ["quadro sorteia tres ofertas distintas sem alterar dados"] = function(t)
  local e = C.novo(rng)
  t.eq(#e.ofertas,3)
  t.eq(e.ofertas[1],"ratos-celeiro")
  t.eq(e.ofertas[2],"goblin-campo")
  t.eq(e.ofertas[3],"lobos-estrada")
  local vistos = {}
  for _,id in ipairs(e.ofertas) do t.eq(vistos[id],nil); vistos[id]=true; t.eq(C.definicao(id).pa,1) end
  t.eq(#C.LISTA,4)
 end,
 ["aceite pessoal recompensa uma vez e permite repetir outro encontro"] = function(t)
  local e = C.novo(rng)
  t.eq(C.aceitar(e,1,"inventado"),false)
  t.eq(C.aceitar(e,1,"ratos-horta"),false)
  t.eq(C.aceitar(e,1,"ratos-celeiro"),true)
  local ouro,pa = C.bonus(e,1,"ratos-celeiro")
  t.eq(ouro,8); t.eq(pa,1)
  t.eq(C.bonus(e,2,"ratos-celeiro"),0)
  t.eq(C.bonus(e,1,"goblin-campo"),0)
  t.eq(C.concluir(e,1,"ratos-celeiro","a"),true)
  t.eq(C.concluir(e,1,"ratos-celeiro","a"),false)
  t.eq(C.bonus(e,1,"ratos-celeiro"),0)
  t.eq(C.aceitar(e,1,"ratos-celeiro"),true)
  t.eq(C.concluir(e,1,"ratos-celeiro","a"),false)
  t.eq(C.concluir(e,1,"ratos-celeiro","b"),true)
 end,
 ["patrulhas cobrem regioes com criaturas canonicas e elencos privados"] = function(t)
  local ids,zonas = {},{}
  for _,d in ipairs(E.patrulhas()) do
   t.eq(ids[d.id],nil); ids[d.id]=true; zonas[d.zona]=true
   t.ok(E.consultar(d.marco))
   local ficha = Criaturas.ficha(porId[d.criatura])
   t.ok(ficha)
   t.ok(d.raio > 0 and type(d.x)=="number" and type(d.z)=="number")
   t.eq(#E.elencoPatrulha(d.id,1),d.quantidadePorJogador or 1)
   t.eq(#E.elencoPatrulha(d.id,4),4*(d.quantidadePorJogador or 1))
   local a = E.elencoPatrulha(d.id,1); a[1]="alterado"
   t.eq(E.elencoPatrulha(d.id,1)[1],d.criatura)
  end
  for _,z in ipairs({"region/clareira-inicial","region/floresta-sombria","region/passagem","region/ruinas-do-vale"}) do t.eq(zonas[z],true) end
  for _,d in ipairs(C.LISTA) do t.eq(ids[d.id],true) end
  t.eq(E.elencoPatrulha("invalido",1),nil)
  t.eq(E.elencoPatrulha("ratos-celeiro",0),nil)
 end,
 ["metadados J2 preservam recompensa e respiracao de novas criaturas"] = function(t)
  local deps = {
   conectado = function() return true end,
   corpoPessoal = function() return {name="Heroi",calculated={initiative={bonus=0,advantage=false},movementMeters=9}} end,
   criatura = function(id) return Criaturas.ficha(porId[id]) end,
  }
  for _,id in ipairs({"creature/rato-gigante","creature/aranha-da-floresta","creature/bandido-de-estrada","creature/golem-de-pedra-menor"}) do
   local atores = Elenco.montar({{UserId=1}}, {id}, deps)
   local c, d = atores[2], porId[id].data
   t.eq(c.recompensa.patamar,d.patamar)
   t.eq(c.recompensa.papel,d.papel)
   t.eq(c.respira,id ~= "creature/golem-de-pedra-menor")
  end
 end,
 ["reaparecimento usa tempo decorrido da run e espera completa"] = function(t)
  t.eq(E.podeReaparecer(100,100),false)
  t.eq(E.podeReaparecer(219.9,100),false)
  t.eq(E.podeReaparecer(220,100),true)
  t.eq(E.podeReaparecer(100,nil),false)
 end,
}
