-- Apenas intenção e apresentação. Cones usam as mesmas dimensóes confirmadas pelo servidor.
local Players=game:GetService("Players")
local CAS=game:GetService("ContextActionService")
local RunService=game:GetService("RunService")
local C=require(script.Parent.UI.Componentes)
local T=require(script.Parent.UI.Tema)
local P=require(script.Parent.UI.ExtraProvacoes)
local ExtraAvisos=require(script.Parent.UI.ExtraAvisos)
local Prompts=require(game:GetService("ReplicatedStorage").Shared.Regras.ProvacaoPrompts)
local V={}
function V.start(remote,fechar)
 local gui=Instance.new("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"))
 gui.Name,gui.ResetOnSpawn,gui.DisplayOrder="ProvacaoEstado",false,44
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 local painel=C.painel({parent=gui,nome="ProvaAtual",padding=12,sombra=false,
  tamanho=UDim2.new(1,-24,0,144),posicao=UDim2.new(1,-12,0,124),ancora=Vector2.new(.5,0)})
 Instance.new("UISizeConstraint",painel).MaxSize=Vector2.new(600,144)
 local conteudo=painel.Conteudo
 local titulo=C.titulo({parent=conteudo,nome="Titulo",tamanho=UDim2.new(1,0,0,28)})
 local objetivo=C.texto({parent=conteudo,nome="Objetivo",posicao=UDim2.fromOffset(0,32),tamanho=UDim2.new(1,0,0,36)})
 local postura=C.texto({parent=conteudo,nome="Postura",posicao=UDim2.fromOffset(0,78),tamanho=UDim2.new(1,-124,0,40)})
 local tempo,atualizarTempo=C.barra({parent=conteudo,rotulo="Tempo",posicao=UDim2.fromOffset(0,70),tamanho=UDim2.new(1,-124,0,48)})
 local sair=C.botao({parent=conteudo,nome="Desistir",texto="Desistir",variante="perigo",
  tamanho=UDim2.fromOffset(112,44),posicao=UDim2.new(1,-112,1,-44),
  aoClicar=function() remote:FireServer({acao="cancelar"}) end})
 -- Quando a faixa alcança os controles Q/E, reserva os primeiros 136 px à esquerda.
 local function redimensionar()
  local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or gui.AbsoluteSize
  local estreito=vp.Y*.4<270
  painel.AnchorPoint=Vector2.new(1,0)
  -- Abaixo do banner de aviso, que fica sob o HUD do mundo; no desktop também desce do cartão de PV.
  painel.Position=UDim2.new(1,-12,0,T.faixasAviso(vp.X,false).painelTopo)
  painel.Size=UDim2.new(1,if estreito then -148 else -24,0,144)
  titulo.TextSize=T.tamanhos.subtitulo
 end
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(redimensionar)
 redimensionar()
 painel.Visible=false
 local ativo,agachado=false,false
 local ladino=false
 local vinculado=false
 local estadoPrompt=nil
 local prompts={}
 local function aplicarPrompt(q)
  local tipo=q:GetAttribute("ProvacaoLadino")
  if not tipo and q.Name=="Falar" then
   local corpo=q:FindFirstAncestorOfClass("Model")
   if corpo and corpo:GetAttribute("TreinadorId")=="vila-1" then tipo="falar" end
  end
  if not tipo then return end
  prompts[q]=tipo
  q.Enabled=Prompts.habilitado(tipo,estadoPrompt)
 end
 -- Replicação tardia também recebe a política atual sem mudar o prompt dos outros jogadores.
 local function observarPrompt(q)
  aplicarPrompt(q)
  q:GetAttributeChangedSignal("ProvacaoLadino"):Connect(function() aplicarPrompt(q) end)
  q.AncestryChanged:Connect(function() if q.Parent then aplicarPrompt(q) end end)
 end
 for _,q in workspace:GetDescendants() do if q:IsA("ProximityPrompt") then observarPrompt(q) end end
 workspace.DescendantAdded:Connect(function(q)
  if q:IsA("ProximityPrompt") then task.defer(function() if q.Parent then observarPrompt(q) end end) end
 end)
 local linhas=Instance.new("Folder",workspace); linhas.Name="ConesLadinoLocal"
 local function limparCones() linhas:ClearAllChildren() end
 local function agachar(_,estado)
  if estado==Enum.UserInputState.Begin and ativo then
   agachado=not agachado
   remote:FireServer({acao="agachar",agachado=agachado})
  end
  return Enum.ContextActionResult.Sink
 end
 local function desvincular() CAS:UnbindAction("ProvacaoAgachar"); vinculado=false; limparCones() end
 remote.OnClientEvent:Connect(function(r)
  if type(r)~="table" or not r.provacao then return end
  local apresentacao=P.projetar(r)
  estadoPrompt=r
  for q,tipo in prompts do
   if q.Parent then q.Enabled=Prompts.habilitado(tipo,r) else prompts[q]=nil end
  end
  ativo=apresentacao.ativo
  ladino=r.npcId=="vila-1"
  agachado=r.agachado==true
  painel.Visible=ativo
  local identidade=P.identidade(r.npcId)
  titulo.Text=identidade.titulo
  objetivo.Text=apresentacao.objetivo
  postura.Visible=ladino
  postura.Text=if agachado then "◒ Agachado" else "◯ Em pé · C/Ctrl para agachar"
  tempo.Visible=not ladino and r.tempo~=nil
  if r.tempo then atualizarTempo(r.tempo/90,string.format("%ds",math.ceil(r.tempo))) end
  if apresentacao.aviso then
   if r.estado=="aprovado" then ExtraAvisos.aprovacao(gui,identidade,r.mensagem)
   else C.aviso({parent=gui,corDestaque=T.arvore(identidade.arvore).cor,icone=T.arvore(identidade.arvore).selo,tipo=apresentacao.aviso.tipo,titulo=apresentacao.aviso.titulo,detalhe=r.mensagem,duracao=apresentacao.aviso.duracao}) end
  end
  sair.Visible=ativo
  if ativo then
   fechar()
   if r.npcId=="vila-1" then
    if not vinculado then
     CAS:BindAction("ProvacaoAgachar",agachar,true,Enum.KeyCode.C,Enum.KeyCode.LeftControl,Enum.KeyCode.RightControl)
     vinculado=true
    end
    CAS:SetTitle("ProvacaoAgachar",if agachado then "Levantar" else "Agachar")
    CAS:SetPosition("ProvacaoAgachar",UDim2.fromScale(.75,.6))
   else desvincular() end
  else
   desvincular()
   -- O painel segue somente o estado; avisos encerram pela fila, sem ocultar um aviso posterior.
  end
 end)
 local acumulado=0
 RunService.RenderStepped:Connect(function(dt)
  acumulado+=dt; if acumulado<.1 then return end; acumulado=0
  if not ativo then return end
  local pasta=workspace:FindFirstChild("ProvacoesTreinadores")
  if not pasta then return end
  if not ladino then return end
  limparCones()
  local patio=pasta:FindFirstChild("Pátio do Ladino")
  if not patio then return end
  for _,m in patio:GetChildren() do
   if not m:IsA("Model") or not m.Name:match("^Guarda ") then continue end
   local guarda=m:FindFirstChild("HumanoidRootPart")
   if not guarda then continue end
   local alcance=if agachado then 10 else 20
   -- Contorno em linhas no chão; sem colisóo ou lógica de detecção cliente.
   local pontos={guarda.Position}
   for n=0,8 do
    local giro=CFrame.Angles(0,math.rad(-35+70*n/8),0)
    table.insert(pontos,guarda.Position+(guarda.CFrame*giro).LookVector*alcance)
   end
   table.insert(pontos,guarda.Position)
   for n=1,#pontos-1 do
    local a,b=pontos[n],pontos[n+1]
    a,b=Vector3.new(a.X,.15,a.Z),Vector3.new(b.X,.15,b.Z)
    local p=Instance.new("Part",linhas)
    p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
    p.Size=Vector3.new(.15,.08,(b-a).Magnitude)
    p.CFrame=CFrame.lookAt((a+b)/2,b); p.Color=T.cores.perigo
    p.Material,p.Transparency=Enum.Material.Neon,.55
   end
  end
 end)
end
return V
