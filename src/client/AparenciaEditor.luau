-- Editor V2 reutilizável. Só modifica rascunhos locais; o fluxo confirma no servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage.Shared
local Estado = require(Shared.Aparencia.EditorEstado)
local Catalogo = require(Shared.Aparencia.Catalogo)
local ModeloAparencia = require(script.Parent.ModeloAparencia)
local T = require(script.Parent.UI.Tema)
local C = require(script.Parent.UI.Componentes)
local Editor = {}

local abas = {
 {nome="Rosto", campos={{"olhos","Olhos"},{"sobrancelhas","Sobrancelhas"},{"nariz","Nariz"},{"boca","Boca"},{"olho","Cor dos olhos"}}},
 {nome="Cabelo", campos={{"cabelo","Estilo"},{"corCabelo","Cor"},{"barba","Barba"}}},
 {nome="Pele", campos={{"pele","Paleta da raça"}}},
 {nome="Traços de raça", campos={{"tracos","Traços opcionais"}}},
 {nome="Roupa", campos={{"roupas","Peças"},{"camisa","Cor da camisa"},{"calca","Cor da calça"}}},
}
-- Ícone do botão na fonte de glifos do tema (SourceSans não desenha ✕ ◀ ▶ direito).
local function glifo(botao,nome)
 local r=botao.Rotulo
 r.Position,r.Size,r.TextWrapped=UDim2.new(),UDim2.fromScale(1,1),false
 r.Text=T.icone(nome); r.FontFace=T.FONTE_ICONE; r.TextSize=22; r.TextColor3=T.cores.ouro
 r:SetAttribute("TextoBaseUIV2",22)
end
local function criar(classe, pai, props)
 local o = Instance.new(classe)
 for k,v in props do o[k]=v end
 o.Parent=pai
 return o
end

-- Rig estático de blocos com nomes R15; decoração/encaixes são exatamente os do A1.
-- Não cria Humanoid, não consulta avatar online e não modifica Character.
-- Campos cujas miniaturas mostram só a cabeça (o corpo inteiro tornava todas iguais).
local FOCO_CABECA={olhos=true,sobrancelhas=true,nariz=true,boca=true,olho=true,cabelo=true,corCabelo=true,barba=true}
local function legivel(id)
 local nomeCor=Catalogo.NOMES.CORES[id]
 if nomeCor then return nomeCor end
 for categoria,nomes in Catalogo.NOMES.ROSTO do
  if nomes[id] then return nomes[id] end
 end
 local item=Catalogo.PECAS[id] or Catalogo.CABELOS[id] or Catalogo.BARBAS[id]
 if item and item.nome and item.nome~=id then return item.nome end
 return Catalogo.NOMES.PECAS[id] or Catalogo.NOMES.ESTILOS[id] or (item and item.nome) or (string.gsub(id,"(%l)(%u)","%1 %2"))
end

local function viewport(pai,a,raceId,foco)
 local focoSolicitado=foco
 local fundo=criar("Frame",pai,{Name="FundoPrevia",Size=UDim2.fromScale(1,1),BackgroundColor3=T.cores.gradienteBase,BorderSizePixel=0,ZIndex=5})
 criar("UIGradient",fundo,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.cores.cabecalho),ColorSequenceKeypoint.new(1,T.cores.painel)}),Rotation=90})
 local v=criar("ViewportFrame",pai,{Name="Previa3D",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=6,
  Ambient=T.cores.texto,LightColor=T.cores.texto,LightDirection=Vector3.new(-1,-1,-1),Active=true})
 local cam=criar("Camera",v,{FieldOfView=38})
 v.CurrentCamera=cam
  local ajustarCamera
 task.spawn(function()
  if not v.Parent then return end
		local ok,modelo=pcall(ModeloAparencia.criar,a,raceId)
  if not ok then warn("[AparenciaEditor] "..tostring(modelo)); return end
  if not v.Parent then modelo:Destroy(); return end
  local mundo=Instance.new("WorldModel"); mundo.Parent=v; modelo.Parent=mundo
  local caixaCorpo,tamanhoCorpo=modelo:GetBoundingBox()
  local baseCorpo=caixaCorpo.Position.Y-tamanhoCorpo.Y/2
  local cabeca=modelo:FindFirstChild("Head")
  local focoAtual=focoSolicitado
  ajustarCamera=function(angulo,aproximarRosto)
   if not cam.Parent or not modelo.Parent then return end
   if aproximarRosto~=nil then focoAtual=aproximarRosto end
   local tamanho=v.AbsoluteSize
   local aspecto=if tamanho.Y>0 then tamanho.X/tamanho.Y else 1
   local alvo=caixaCorpo.Position
   local altura,largura,profundidade=tamanhoCorpo.Y,tamanhoCorpo.X,tamanhoCorpo.Z
   if aproximarRosto and cabeca then
    alvo=cabeca.Position+Vector3.new(0,0.05,0)
    altura,largura,profundidade=cabeca.Size.Y,cabeca.Size.X,cabeca.Size.Z
   end
   local distancia=T.distanciaPrevia(altura,largura,profundidade,aspecto,angulo,cam.FieldOfView,aproximarRosto)
   cam.CFrame=CFrame.lookAt(alvo+Vector3.new(math.sin(angulo)*distancia,0,-math.cos(angulo)*distancia),alvo)
  end
  ajustarCamera(0.24,focoSolicitado)
  local resize=v:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() ajustarCamera(0.24,focoAtual) end)
  v.Destroying:Once(function() resize:Disconnect() end)
  local chao=Instance.new("Part")
  chao.Name="ChaoPrevia"; chao.Size=Vector3.new(24,0.25,24); chao.CFrame=CFrame.new(0,baseCorpo-0.125,0)
  chao.Anchored=true; chao.CanCollide=false; chao.Material=Enum.Material.SmoothPlastic; chao.Color=T.cores.painel; chao.Parent=mundo
  local sombra=Instance.new("Part")
  sombra.Name="SombraPrevia"; sombra.Shape=Enum.PartType.Cylinder; sombra.Size=Vector3.new(0.025,2.6,1.8)
  sombra.CFrame=CFrame.new(0,baseCorpo+0.014,0)*CFrame.Angles(0,0,math.rad(90)); sombra.Anchored=true
  sombra.CanCollide=false; sombra.Material=Enum.Material.SmoothPlastic; sombra.Color=T.cores.sombra; sombra.Transparency=0.25; sombra.Parent=mundo
 end)
 return v,cam,function(angulo,aproximarRosto)
  if aproximarRosto~=nil then focoSolicitado=aproximarRosto end
  if ajustarCamera then ajustarCamera(angulo,focoSolicitado) end
 end
end

function Editor.abrir(p)
 local estado=Estado.novo(p.raceId,p.aparencia,p.possuidos or {})
 local gui=criar("ScreenGui",p.parent,{Name="AparenciaEditor",ResetOnSpawn=false,DisplayOrder=65,
  ZIndexBehavior=Enum.ZIndexBehavior.Sibling,ScreenInsets=Enum.ScreenInsets.None})
 local painel=C.painel({parent=gui,tamanho=UDim2.fromScale(1,1),losangos=true,sombra=false})
 painel.BackgroundTransparency=0 -- tela cheia modal: opaca (a tela de criação não pode transparecer)
 local raiz=painel.Conteudo
 -- Cobre a tela inteira (sem faixa descoberta no topo) e começa o conteúdo abaixo da barra do Roblox.
 local margem=raiz:FindFirstChildOfClass("UIPadding")
 if margem then margem.PaddingTop=UDim.new(0,GuiService:GetGuiInset().Y+8) end
 painel.Active=true -- tela modal recebe toque, sem atingir controles sob o editor
 local topo=C.titulo({parent=raiz,texto="Aparência",tamanho=UDim2.new(1,-60,0,44)})
 topo.Text= "APARÊNCIA"
 local fechado=false
 local conexoes={}
 gui.Destroying:Once(function()
  for _,c in conexoes do c:Disconnect() end
 end)
 local function fechar()
  if fechado then return end
  fechado=true
  for _,c in conexoes do c:Disconnect() end
  gui:Destroy()
  if p.aoFechar then p.aoFechar() end
 end
 local sair=C.botao({parent=raiz,texto="",variante="secundario",tamanho=UDim2.fromOffset(44,44),posicao=UDim2.new(1,-44,0,0),aoClicar=fechar})
 glifo(sair,"fechar")
 local previa=criar("Frame",raiz,{BackgroundColor3=T.cores.fio,BorderSizePixel=0,ZIndex=4})
 local opcoes=criar("Frame",raiz,{BackgroundTransparency=1,ZIndex=4})
 local tabs=criar("ScrollingFrame",opcoes,{Name="Abas",Size=UDim2.new(1,0,0,52),BackgroundTransparency=1,
  BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.X})
 criar("UIListLayout",tabs,{FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})
 criar("UIPadding",tabs,{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,2),PaddingLeft=UDim.new(0,2)}) -- a rolagem cortava o contorno (só as pontas apareciam)
 local lista=criar("ScrollingFrame",opcoes,{Name="Opcoes",Position=UDim2.fromOffset(0,56),Size=UDim2.new(1,0,1,-56),
  BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4})
 local rodape=criar("Frame",raiz,{BackgroundTransparency=1,Position=UDim2.new(0,0,1,-48),Size=UDim2.new(1,0,0,48)})
 local aba=1
 local cameraPrevia=nil
 local enquadrarPrevia=nil
 local angulo=0.24
 local arrastando=false
 local focoRosto=false
 local focavel=false
 local botaoFoco
 local desenhar
 local function atualizarPrevia()
  previa:ClearAllChildren()
  local v,cam,enquadrar=viewport(previa,Estado.clone(estado.aparencia),estado.raceId,false)
  cameraPrevia,enquadrarPrevia=cam,enquadrar
  local entrada=v.InputBegan:Connect(function(input)
   if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then arrastando=true end
  end)
  v.Destroying:Once(function() entrada:Disconnect() end)
  if botaoFoco then botaoFoco.Visible=focavel end
  if enquadrarPrevia then enquadrarPrevia(angulo,focoRosto and focavel) end
 end
 desenhar=function()
  lista:ClearAllChildren()
  criar("UIListLayout",lista,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)})
  local ordem=0
  for _,campo in abas[aba].campos do
   local id,rotulo=campo[1],campo[2]
   ordem+=1
   local linha=criar("Frame",lista,{Size=UDim2.new(1,-8,0,48),BackgroundTransparency=1,LayoutOrder=ordem})
   C.texto({parent=linha,texto=rotulo,tamanho=UDim2.new(1,-112,1,0)})
   for _,seta in {{"setaEsq",-1,-100},{"seta",1,-48}} do
    local bs=C.botao({parent=linha,texto="",variante="secundario",posicao=UDim2.new(1,seta[3],0,0),tamanho=UDim2.fromOffset(48,48),
     aoClicar=function() Estado.navegar(estado,id,seta[2]); atualizarPrevia(); desenhar() end})
    glifo(bs,seta[1])
   end
   local disponiveis=Estado.opcoes(estado,id)
   ordem+=1
   if #disponiveis==0 then
    C.texto({parent=lista,texto="Esta raça não tem traços opcionais.",ordem=ordem,tamanho=UDim2.new(1,0,0,44)})
   else
    local grade=criar("Frame",lista,{Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=ordem})
    local colunas=if raiz.AbsoluteSize.X<700 then 3 else 2
    local alturaCelula=if colunas==3
     then math.max(44,(lista.AbsoluteSize.Y-48-8-16)/2.5)
     else 152
    criar("UIGridLayout",grade,{CellSize=UDim2.new(1/colunas,-6,0,alturaCelula),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder})
    for i,item in disponiveis do
     local copia=Estado.novo(estado.raceId,Estado.clone(estado.aparencia),estado.possuidos)
     if id=="roupas" or id=="tracos" then
      copia.aparencia.roupas[Catalogo.PECAS[item.id].slot]=item.id
     else Estado.selecionar(copia,id,item.id) end
     local selecionado=if id=="roupas" or id=="tracos" then estado.aparencia.roupas[Catalogo.PECAS[item.id].slot]==item.id
      elseif estado.aparencia.rosto[id] then estado.aparencia.rosto[id]==item.id
      elseif id=="corCabelo" then estado.aparencia.cores.cabelo==item.id
      elseif id=="cabelo" or id=="barba" then estado.aparencia[id]==item.id
      else estado.aparencia.cores[id]==item.id
     local b=C.botao({parent=grade,texto=(if selecionado then "✓ " else "")..legivel(item.nome),ordem=i,
      variante=if selecionado then "principal" else "secundario",aoClicar=function()
       Estado.selecionar(estado,id,item.id); atualizarPrevia(); desenhar()
      end})
     b.Rotulo.Position=UDim2.fromScale(0.04,0.72); b.Rotulo.Size=UDim2.fromScale(0.92,0.28)
     if colunas==3 then
      b.Rotulo.Position,b.Rotulo.Size=UDim2.new(.04,0,1,-26),UDim2.new(.92,0,0,26)
      b.Rotulo.TextSize,b.Rotulo.TextWrapped,b.Rotulo.TextTruncate=16,false,Enum.TextTruncate.AtEnd
     end
     local imagem=criar("Frame",b,{Size=if colunas==3 then UDim2.new(1,0,1,-26) else UDim2.fromScale(1,0.72),BackgroundTransparency=1,ZIndex=6})
     viewport(imagem,copia.aparencia,estado.raceId,FOCO_CABECA[id])
     if item.raridade=="rara" then
      local stroke=b:FindFirstChildWhichIsA("UIStroke")
      if stroke then stroke.Color=T.cores.ouro; stroke.Thickness=T.espessuras.destaque end
      local selo=C.texto({parent=b,texto="RARO",posicao=UDim2.new(1,-64,0,4),tamanho=UDim2.fromOffset(60,24)})
      selo.AutomaticSize=Enum.AutomaticSize.None; selo.TextColor3=T.cores.ouro
      selo.BackgroundColor3=T.cores.painel; selo.BackgroundTransparency=T.transparencias.painel
      selo.FontFace=T.fontes.rotulo; selo.TextSize=T.tamanhos.rotulo; selo.ZIndex=8
     end
    end
   end
  end
 end
 local controlesPrevia=criar("Frame",raiz,{BackgroundTransparency=1,ZIndex=7})
 botaoFoco=C.botao({parent=controlesPrevia,texto="Rosto",variante="secundario",posicao=UDim2.new(1,-96,1,-48),tamanho=UDim2.fromOffset(92,44),aoClicar=function()
  focoRosto=not focoRosto
  if enquadrarPrevia then enquadrarPrevia(angulo,focoRosto and focavel) end
  botaoFoco.Rotulo.Text=if focoRosto then "Corpo" else "Rosto"
 end})
 botaoFoco.ZIndex=8
 botaoFoco.Visible=false
 -- Arraste horizontal gira a prévia com mouse ou toque; o giro lento continua em repouso.
 previa.Active=true
 table.insert(conexoes,previa.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then arrastando=true end
 end))
 table.insert(conexoes,UserInputService.InputChanged:Connect(function(input)
  if not arrastando then return end
  if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
   angulo+=input.Delta.X*0.012
   if enquadrarPrevia then enquadrarPrevia(angulo,focoRosto and focavel) end
  end
 end))
 table.insert(conexoes,UserInputService.InputEnded:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then arrastando=false end
 end))
 local function desenharAbas()
  tabs:ClearAllChildren()
  criar("UIListLayout",tabs,{FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})
  criar("UIPadding",tabs,{PaddingTop=UDim.new(0,2),PaddingBottom=UDim.new(0,2),PaddingLeft=UDim.new(0,2)})
  for i,dados in abas do
   C.botao({parent=tabs,texto=dados.nome,ordem=i,variante=if i==aba then "principal" else "secundario",
    tamanho=UDim2.fromOffset(if i==4 then 152 else 100,48),
    aoClicar=function() aba=i; lista.CanvasPosition=Vector2.zero; desenharAbas(); desenhar() end})
  end
  focavel=(aba==1 or aba==2)
  if botaoFoco then
   botaoFoco.Visible=focavel
   botaoFoco.Rotulo.Text=if focoRosto then "Corpo" else "Rosto"
  end
 end
 desenharAbas()
 C.botao({parent=rodape,texto="Aleatório",variante="secundario",tamanho=UDim2.new(0.49,0,1,0),aoClicar=function()
  Estado.aleatorio(estado,Random.new()); atualizarPrevia(); desenhar()
 end})
 local pronto=C.botao({parent=rodape,texto="Pronto",posicao=UDim2.fromScale(0.51,0),tamanho=UDim2.new(0.49,0,1,0),variante="principal",
  aoClicar=function() if p.aoPronto then p.aoPronto(Estado.clone(estado.aparencia),fechar) else fechar() end end})
 local function layout()
  local tamanho=raiz.AbsoluteSize
  local compacto=tamanho.X<700
  if compacto then
   local alturaUtil=tamanho.Y-(if margem then margem.PaddingTop.Offset+margem.PaddingBottom.Offset else 0)
   local altura=math.clamp(alturaUtil*0.38,112,260)
   previa.Position=UDim2.fromOffset(0,48); previa.Size=UDim2.new(1,0,0,altura)
   controlesPrevia.Position=previa.Position; controlesPrevia.Size=previa.Size
   opcoes.Position=UDim2.fromOffset(0,52+altura); opcoes.Size=UDim2.new(1,0,1,-108-altura)
  else
   previa.Position=UDim2.fromOffset(0,52); previa.Size=UDim2.new(0.4,-8,1,-108)
   controlesPrevia.Position=previa.Position; controlesPrevia.Size=previa.Size
   opcoes.Position=UDim2.new(0.4,8,0,52); opcoes.Size=UDim2.new(0.6,-8,1,-108)
  end
 end
 local compactoAnterior=raiz.AbsoluteSize.X<700
 table.insert(conexoes,raiz:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
  layout()
  local compacto=raiz.AbsoluteSize.X<700
  if compacto~=compactoAnterior then compactoAnterior=compacto; task.defer(desenhar) end
 end))
 table.insert(conexoes,lista:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
  task.defer(desenhar)
 end))
 table.insert(conexoes,RunService.RenderStepped:Connect(function(dt)
  if not arrastando then angulo+=dt*0.10 end
  if cameraPrevia and cameraPrevia.Parent and enquadrarPrevia then enquadrarPrevia(angulo,focoRosto and focavel) end
 end))
 atualizarPrevia(); desenhar(); layout()
 return {fechar=fechar,ocupado=function(valor) pronto:SetAttribute("Desabilitado",valor) end}
end
return Editor
