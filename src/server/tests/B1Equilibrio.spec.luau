local Shared = game:GetService("ReplicatedStorage").Shared
local Catalogo = require(Shared.Livro.Catalogo)
local Preset = require(Shared.Regras.CriacaoPreset)
local Criacao = require(Shared.Regras.CriacaoPersonagem)
local Sim = require(Shared.Regras.SimulacaoEncontros)
local Encontros = require(Shared.EncontrosPorZona)
local Cacadas = require(Shared.Regras.Cacadas)
local Criaturas = require(Shared.Regras.Criaturas)
local Elenco = require(Shared.EncontroAutonomoElenco)
-- No Studio as 280 linhas "B1 SIM" so poluem o Output; a tabela completa sai pelo tools/testar.ps1.
local EM_STUDIO = select(2, pcall(function() return game:GetService("RunService"):IsStudio() end)) == true
local function ficha(raca,arvore)
 local p=assert(Criacao.calcular(assert(Preset.criar(Catalogo,raca,arvore)),Catalogo))
 return {name="Preset B1",construction={inventory=p.inventarioInicial,unlockedRankIds=p.construcao.unlockedRankIds,
  startingTreeId=arvore,purchasedIds={}}, calculated={attributes=p.atributos,maxima=p.estatisticas.maxima,
  movementMeters=p.estatisticas.movementMeters,
  armorClass=p.estatisticas.armorClass,initiative=p.estatisticas.initiative}}
end
return {
 ["formação inicial é a mesma em marco fixo e arena de patrulha"] = function(t)
  local f=ficha("race/humano","tree/agua")
  local function montar(area,formacao)
   return assert(Elenco.montar({{UserId=1}},{"creature/rato-gigante"},{areaId=area,formacaoId=formacao,
    conectado=function() return true end,corpoPessoal=function() return f end,
    criatura=function(id) return Criaturas.ficha(Catalogo.POR_ID[id]) end}))
  end
  local fixo=montar("region/encounter/clearing")
  local patrulha=montar("region/encounter/patrol","region/encounter/clearing")
  t.eq(fixo[1].z,10); t.eq(fixo[2].z,18)
  t.eq(patrulha[2].z,fixo[2].z)
  t.eq(montar("region/encounter/forest")[2].z,11)
  t.eq(montar("region/encounter/patrol","region/encounter/dark-forest")[2].z,11)
  t.eq(montar("region/encounter/ruinas")[2].z,4)
 end,
 ["curva usa Fácil inicial, médio na trilha e lobos fora do nascimento"] = function(t)
  local menor=math.huge
  for _,c in Catalogo.POR_ESPECIE.creature do
   local f=Criaturas.ficha(c)
   local peso=2^(f.patamar-1)*(if f.papel=="lacaio" then 0.5 elseif f.papel=="chefe" then 4 else 1)
   menor=math.min(menor,peso)
  end
  t.eq(menor,0.5,"catálogo não oferece criatura abaixo de um lacaio comum")
  for _,p in Encontros.patrulhas() do
   if p.faixa=="inicial" then
    t.eq(#Encontros.elencoPatrulha(p.id,1),1)
    t.eq(Criaturas.ficha(Catalogo.POR_ID[p.criatura]).papel,"lacaio")
   elseif p.faixa=="trilha" then
    t.eq(#Encontros.elencoPatrulha(p.id,1),1)
    t.eq(p.perigo,"médio")
   end
   if p.id=="lobos-estrada" then t.ok(p.z<=-340); t.eq(p.perigo,"alto") end
  end
  -- Qualquer subconjunto de 3/4 possui ao menos duas caçadas fáceis próximas.
  local faceis=0
  for _,d in Cacadas.LISTA do if string.find(d.perigo,"fácil",1,true) then faceis+=1 end end
  t.eq(faceis,3)
 end,
 ["200 lutas por preset racial e encontro inicial, mínimo 70 por cento"] = function(t)
  local falhas={}
  local liberadas={}; for _,r in Catalogo.POR_ESPECIE.race do if r.data.tier=="rara" then liberadas[r.id]=true end end
  for _,r in Preset.racasDisponiveis(Catalogo,liberadas) do
   for _,arvore in {"tree/furtividade-e-armadilhas","tree/agua"} do
    local f=ficha(r.id,arvore)
    local cenarios=Encontros.patrulhas()
    for _,id in Encontros.listar() do
     local z=Encontros.elegivel(id,1)
     table.insert(cenarios,{id=id,zona=z.zona,inicial=id=="region/encounter/clearing",elenco=z.elenco,marco=id})
    end
    for _,p in cenarios do
     local taxa=Sim.amostra(f,p.elenco or Encontros.elencoPatrulha(p.id,1),Catalogo,200,17102026,p.marco,if p.elenco then p.marco else "region/encounter/patrol")
     if not EM_STUDIO then print(string.format("B1 SIM %s %s %s PV=%d %.1f%%",r.id,arvore,p.id,f.calculated.maxima.pv,taxa*100)) end
     if p.faixa=="inicial" or p.inicial then if taxa<0.70 then table.insert(falhas,r.id.."/"..arvore.."/"..p.id.." "..taxa) end end
    end
   end
  end
  t.eq(#falhas,0,table.concat(falhas,"; "))
 end,
}
