-- SOMENTE PLAY/STUDIO. Fixture de cobertura, não construção legal de jogador.
-- Todos os ranks/compras do catálogo; reservas sintéticas evitam esgotamento.
-- Não lê/grava perfil, DataStore, recompensas ou campanha. Parar Play remove tudo.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsRunning())
local S = game.ServerScriptService.Server
local R = game.ReplicatedStorage
local C = require(R.Shared.Livro.Catalogo)
local H = require(R.Shared.EncontroAutonomoHabilidades)
local player = assert(game.Players:GetPlayers()[1])
local ranks, compras, arvores = {}, {}, {}
for id, entrada in C.POR_ID do
 if entrada.kind == "rank" then table.insert(ranks,id)
 elseif entrada.kind == "ability" or entrada.kind == "talent" then table.insert(compras,id)
 elseif entrada.kind == "tree" then table.insert(arvores,id) end
end
table.sort(ranks); table.sort(compras); table.sort(arvores)
local eventos, contador, tempo = {}, 0, 0
local remote = R:WaitForChild("EncontroAutonomo")
local api = require(S.EncontroAutonomoService).start({
 remote = {}, emitir = function(p,t,d) table.insert(eventos,{tipo=t,dados=d}); remote:FireClient(p,t,d) end,
 agora = function() return tempo end,
 agendarPrazo = function() end, cancelarPrazo = function() end,
 rng = {NextInteger=function(_,a,b) return if b==20 then 15 else a end,NextNumber=function() return 0 end},
 miniaturas = require(S.EncontroAutonomoMiniaturas).start(),
 avatares = require(S.EncontroAutonomoAvatares).start(),
})
local function pedido(cmd,id)
 contador+=1; tempo+=1
 return {command=cmd,encounterId=id,requestId="max1-"..contador,expectedVersion=api.estado(id).version}
end
local ficha = { name="Teste todas as árvores", construction={unlockedRankIds=ranks,purchasedIds=compras},
 calculated={attributes={forca=8,agilidade=8,vigor=8,intelecto=8,espirito=8,carisma=8},
 highestRankBonus=7,maxima={pv=1000,pm=1000,pt=1000,pp=1000},armorClass=25,
 initiative={bonus=8,advantage=false},movementMeters=9},
 session={current={pv=500,pm=1000,pt=1000,pp=1000}} }
local ator = {id="max1",userId=player.UserId,name="Teste todas as árvores",kind="jogador",x=10,z=10,ficha=ficha}
local disponiveis=H.disponiveis(ator)
local atual
local function fechar()
 if not atual then return end
 local estado=api.estado(atual)
 if estado and estado.phase=="active" then api.solicitarDesistencia(player,pedido("abandon-encounter",atual)) end
 api.solicitarRetorno(player,{command="return-autonomous",encounterId=atual,requestId="max1-retorno-"..contador})
 atual=nil
end
local bridge=Instance.new("BindableFunction")
bridge.Name="CodexMax1Fixture"
bridge.OnInvoke=function(cmd,id,target)
 if cmd=="inventario" then return {ranks=#ranks,compras=#compras,arvores=arvores,disponiveis=disponiveis} end
 if cmd=="fechar" then fechar(); return true end
 if cmd=="abrir" then
  fechar()
  local criatura={id="alvo",kind="criatura",name="Goblin de teste",criaturaId="creature/goblin-batedor",x=10,z=11,respira=true,
   fichaCriatura={catalogId="creature/goblin-batedor",nome="Goblin de teste",pvMax=10000,ca=10,patamar=1,
    respira=true,bonusAtaque=0,danoPorTurno=0,deslocamentoMetros=0}}
  local err; atual,err=api.criar({ator,criatura},nil,"region/encounter/clearing")
  return {id=atual,erro=err,atores=atual and api.atores(atual)}
 end
 if cmd=="usar" then
  table.clear(eventos)
  local p=pedido("use-ability",atual); p.abilityId=id;p.targetId=target or "alvo"
  local ok,recibo=api.solicitarHabilidade(player,p)
  return {ok=ok,recibo=recibo,eventos=eventos,estado=api.estado(atual)}
 end
 if cmd=="estado" then return {id=atual,estado=atual and api.estado(atual),atores=atual and api.atores(atual)} end
end
bridge.Parent=game.ServerStorage
script:SetAttribute("Pronto",true)
