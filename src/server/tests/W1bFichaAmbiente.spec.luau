local Shared = game:GetService("ReplicatedStorage").Shared
local Arvores = require(Shared.Regras.ArvoresAprendidas)
local Progressao = require(Shared.Regras.Progressao)
local Ambiente = require(Shared.Mundo.AmbientePerfis)
local Objetivos = require(Shared.Regras.Objetivos)
local function fixture()
 local c = {POR_ID={},POR_ESPECIE={skill={},tree={}}}
 local function add(id,kind,data) local e={id=id,kind=kind,data=data}; c.POR_ID[id]=e; if c.POR_ESPECIE[kind] then table.insert(c.POR_ESPECIE[kind],e) end end
 add("race/humano","race",{})
 add("background/plebeu","background",{})
 add("tree/furtividade-e-armadilhas","tree",{id="furtividade-e-armadilhas",category="utilidade"})
 add("rank/furtividade-e-armadilhas/Principiante","rank",{treeId="furtividade-e-armadilhas",rank="Principiante",hpDiceFormula="1d6"})
 add("tree/agua","tree",{id="agua",category="magia",masterySkillsWhenNotFirst={"Medicina"}})
 add("rank/agua/Principiante","rank",{treeId="agua",rank="Principiante",hpDiceFormula="1d6",abilities={"ability/agua/Principiante/truque"}})
 add("ability/agua/Principiante/truque","ability",{paCost=0,treeId="agua",rank="Principiante"})
 add("skill/medicina","skill",{name="Medicina",attribute="intelecto"})
 return c,{construcao={raceId="race/humano",backgroundId="background/plebeu",startingTreeId="tree/furtividade-e-armadilhas",unlockedRankIds={"rank/furtividade-e-armadilhas/Principiante"},purchasedIds={}},atributos={intelecto=2,agilidade=1},estatisticas={maxima={pv=20,pm=0,pt=0,pp=3}}}
end
return {
 ["segunda árvore abre rank e cartas gratuitas sem trocar primeira nem somar PV"] = function(t)
  local c,p=fixture()
  local novo,erro=Arvores.aplicar(p,{"tree/agua"},c)
  t.ok(novo,erro); t.eq(#novo.construcao.unlockedRankIds,2)
  t.eq(novo.construcao.startingTreeId,p.construcao.startingTreeId)
  t.eq(novo.estatisticas.maxima.pv,20); t.eq(novo.estatisticas.maxima.pm,12)
  t.eq(novo.estatisticas.maxima.pp,3); t.eq(#p.construcao.unlockedRankIds,1)
  t.eq(Progressao.conhecidas({unlockedRankIds=novo.construcao.unlockedRankIds,purchasedIds={}},c)[1],"ability/agua/Principiante/truque")
  t.ok(novo.pericias[1].trained)
 end,
 ["aprendizagem recusa árvore inicial repetida desconhecida e lista malformada"] = function(t)
  local c,p=fixture()
  t.eq(Arvores.aplicar(p,{"tree/furtividade-e-armadilhas"},c),nil)
  t.eq(Arvores.aplicar(p,{"tree/agua","tree/agua"},c),nil)
  t.eq(Arvores.aplicar(p,{"tree/inexistente"},c),nil)
  t.eq(Arvores.aplicar(p,{x="tree/agua"},c),nil)
 end,
 ["substituir lista recompõe ranks e recursos sem árvore antiga fantasma"] = function(t)
  local c,p=fixture()
  local comAgua=Arvores.aplicar(p,{"tree/agua"},c)
  local semAgua=Arvores.aplicar(comAgua,{},c)
  t.eq(#semAgua.construcao.unlockedRankIds,1)
  t.eq(semAgua.estatisticas.maxima.pm,0)
  t.eq(#semAgua.arvoresAprendidas,0)
 end,
 ["hora modula luz conservando névoa de cada zona e perfil original"] = function(t)
  for _,zona in {"dia","floresta","ruinas"} do
   local p=Ambiente.PERFIS[zona]
   local dia,noite=Ambiente.modularHora(p,12),Ambiente.modularHora(p,0)
   t.ok(dia.brilho>noite.brilho); t.eq(noite.clock,0)
   t.eq(noite.atmDensidade,p.atmDensidade); t.eq(dia.atmHaze,p.atmHaze)
   t.ok(p.clock~=0); t.ok(noite.ambiente[1]<dia.ambiente[1])
  end
 end,
 ["orientação mundo aberto sugere caçada cedo e floresta com prazo apertado"] = function(t)
  local run={mundoAberto=true,galho="vila",dia=1,diasRestantes=10,plano={escolhida="agua"},opcoes={}}
  t.eq(Objetivos.atual({run=run}).chave,"fazer-cacada")
  run.diasRestantes=2; t.eq(Objetivos.atual({run=run}).chave,"seguir-floresta")
 end,
}
