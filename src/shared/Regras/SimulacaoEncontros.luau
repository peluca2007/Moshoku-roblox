-- Bancada pura B1. J2 real para ataque, iniciativa e orçamento de ações.
-- Arena aberta e formação real do elenco, sem surpresa/poção/habilidade de árvore.
-- Bot usa Disparo básico fora de adjacência; sem kiting nem habilidades de árvore.
-- IA J2: UM ataque por turno; bot ataca e reserva a terceira ação a Defender
-- só quando reduz ao menos 1/3 do dano potencial vivo (sem consultar o RNG).
local Shared = game:GetService("ReplicatedStorage").Shared
local Combate = require(Shared.EncontroAutonomoCombate)
local Iniciativa = require(Shared.EncontroIniciativa)
local Turnos = require(Shared.EncontroTurnos)
local Maestrias = require(Shared.Regras.Maestrias)
local Execucao = require(Shared.Regras.Execucao)
local Criaturas = require(Shared.Regras.Criaturas)
local Elenco = require(Shared.EncontroAutonomoElenco)
local Movimento = require(Shared.EncontroAutonomoMovimento)
local S = {}
-- Park–Miller, produto abaixo de 2^53: reproduzível CLI/Studio.
function S.rng(semente)
 local estado = semente
 return { NextInteger=function(_, minimo, maximo)
  estado = (estado * 16807) % 2147483647
  return minimo + estado % (maximo - minimo + 1)
 end }
end
function S.lutar(ficha, ids, catalogo, rng, areaId, areaFisica)
 local atores=assert(Elenco.montar({{UserId=1}},ids,{
  areaId=areaFisica or areaId,
  formacaoId=areaId,conectado=function() return true end,corpoPessoal=function() return ficha end,
  criatura=function(id) return Criaturas.ficha(catalogo.POR_ID[id]) end }))
 local jogador=atores[1]
 local porId={}
 for _,a in atores do
  local f=a.fichaCriatura
  a.pv=if f then f.pvMax else ficha.calculated.maxima.pv
  a.ca=if f then f.ca else ficha.calculated.armorClass
  porId[a.id]=a
 end
 local ordem = assert(Iniciativa.ordenar(atores,rng))
 local fila = {}; for _,a in ipairs(ordem) do table.insert(fila,a.id) end
 local estado = assert(Turnos.criar("simulacao",fila))
 local passos, defesa = 0, 0
 local function consumir(acao, alvo)
  passos += 1
  estado = assert(Turnos.consumirAcao(estado,{actorId=estado.order[estado.currentIndex],
   expectedVersion=estado.version,requestId="acao:"..passos,action=acao,targetId=alvo}))
 end
 while estado.phase=="active" and passos<1000 do
  local ator = porId[estado.order[estado.currentIndex]]
  if ator==jogador then
   defesa=0
   local corpo = Execucao.arvoreDeCorpo(ficha,catalogo)
   local reducao=Maestrias.reducaoDefender(ficha.calculated.attributes.vigor or 0,
    if corpo then Execucao.bonusDeRankDa(ficha,corpo) else 0)
   local danoPotencial,mitigado=0,0
   for _,a in atores do if a.kind=="criatura" and a.pv>0 then
    danoPotencial+=a.fichaCriatura.danoPorTurno
    mitigado+=math.min(reducao,a.fichaCriatura.danoPorTurno)
   end end
   local defender=mitigado*3>=danoPotencial
   for acao=1,3 do
    local alvo
    for _,id in ipairs(estado.order) do if porId[id].kind=="criatura" then alvo=porId[id]; break end end
    if not alvo then return true,passos end
    if acao==3 and defender then
     defesa=reducao
     consumir("defend",jogador.id)
    else
     local distancia=math.max(math.abs(jogador.x-alvo.x),math.abs(jogador.z-alvo.z))
     if distancia>12 then
      local vivos={}; for _,id in estado.order do table.insert(vivos,porId[id]) end
      local destino=assert(Movimento.aproximar(jogador.x,jogador.z,vivos,{alvo},jogador.movementCasas,{}))
      consumir("move"); jogador.x,jogador.z=destino.x,destino.z
     else
      local r=assert((if distancia<=1 then Combate.atacarBasico else Combate.atacarDistancia)(rng,jogador,alvo,catalogo))
      consumir(r.action,alvo.id); alvo.pv=r.targetPv
      if alvo.pv<=0 then estado=assert(Turnos.removerDerrotado(estado,alvo.id)) end
      if estado.phase~="active" then return true,passos end
     end
    end
   end
  else
   local r=Combate.atacarCriatura(rng,ator,jogador,catalogo)
   if not r then
    local vivos={}; for _,id in estado.order do table.insert(vivos,porId[id]) end
    local destino=Movimento.aproximar(ator.x,ator.z,vivos,{jogador},ator.movementCasas,{})
    if destino then consumir("creature-move"); ator.x,ator.z=destino.x,destino.z end
    r=Combate.atacarCriatura(rng,ator,jogador,catalogo)
   end
   if r then
    consumir("creature-attack",jogador.id)
    jogador.pv=math.max(0,jogador.pv-math.max(0,r.damageDealt-defesa))
    if jogador.pv<=0 then return false,passos end
   end
  end
  passos+=1
  estado=assert(Turnos.encerrarTurno(estado,{actorId=ator.id,expectedVersion=estado.version,requestId="fim:"..passos}))
 end
 assert(passos<1000,"simulação não terminou")
 return estado.phase=="victory",passos
end
function S.amostra(ficha,ids,catalogo,n,semente,areaId,areaFisica)
 local vitorias=0
 local rng=S.rng(semente)
 for _=1,n do if S.lutar(ficha,ids,catalogo,rng,areaId,areaFisica) then vitorias+=1 end end
 return vitorias/n
end
return S
