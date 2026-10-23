-- Cliente real, efeitos isolados e descartáveis; não altera a campanha.
local Client = game.Players.LocalPlayer.PlayerScripts.Client
local Coreografia = require(Client.Coreografia)
local Protocol = require(game.ReplicatedStorage.Shared.MesaProtocol)
local pasta = Instance.new("Folder"); pasta.Name="A4TesteVisual"; pasta.Parent=workspace
local a, b = Protocol.cellCenter(8,10)+Vector3.yAxis*3, Protocol.cellCenter(11,10)+Vector3.yAxis*3
local api=Coreografia.start({},pasta,function(_,id) return if id=="a" then a else b end)
local report, failures={},0
local function check(n,ok) table.insert(report,(if ok then "OK " else "FALHA ")..n); if not ok then failures+=1 end end
local function recibo(id) return {habilidadeId=id,casterId="a",origem={8,10},alvos={{id="b",acertou=true,dano=4}}} end
local arvores={agua="corrente",vento="vento",terra="pedra",cura="vida",desintoxicacao="alquimia",teorica="geometria",invocacao="portal",["deus-da-espada"]="corte",["deus-da-agua-corpo"]="guarda",["deus-do-norte"]="astucia",["armas-pesadas"]="peso",["cavalaria-e-escudos"]="escudo",arquearia="flecha"}
for arv,familia in arvores do
 api.limpar()
 check(arv.." aceita recibo",api.tocar(recibo("ability/"..arv.."/Principiante/teste")))
 local modelo=pasta:GetChildren()[1]
 check(arv.." tem identidade",modelo and modelo:GetAttribute("Familia")==familia)
 task.wait(0.06)
end
api.limpar()
local cura=recibo("ability/cura/Principiante/cura-menor");cura.alvos[1].dano=nil;cura.alvos[1].cura=8
api.tocar(cura);task.wait(0.65)
local seguro,finito,visivel=true,true,false
for _,p in pasta:GetDescendants() do
 if p:IsA("ParticleEmitter") or p:IsA("Fire") then seguro=false end
 if p:IsA("BasePart") then
  seguro=seguro and not p.CanCollide and not p.CanTouch and not p.CanQuery
  for _,n in {p.CFrame:GetComponents()} do if n~=n or math.abs(n)==math.huge then finito=false end end
  if p.Transparency<1 then visivel=true end
 end
end
check("cura sem fogo nem colisão",seguro);check("transformações finitas",finito);check("cura anima peças visíveis",visivel)
task.wait(1.6);check("cena expira sem peças residuais",api.estado().pecas==0 and #pasta:GetChildren()==0)
for _=1,30 do api.tocar(recibo("ability/invocacao/Principiante/chamado")) end
local estado=api.estado();check("rajada de recibos respeita orçamento",estado.cenas<=estado.maxCenas and estado.pecas<=estado.maxPecas)
api.limpar();check("cancelamento elimina todas as cenas",api.estado().cenas==0 and api.estado().pecas==0)
local mesmo=recibo("mesa/lamina-de-gelo-forca");mesmo.alvos[1].id="a"
check("ataque de gelo reconhecido",api.tocar(mesmo));task.wait(0.7)
check("origem coincidente não interrompe cena",api.estado().cenas==1)
api.destruir();check("diretor destruído recusa novos efeitos",not api.tocar(cura));pasta:Destroy()
table.insert(report,string.format("A4 visual: %d verificações, %d falhas",#report,failures))
return table.concat(report,"\n")
