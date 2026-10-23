-- G1: HUD de orientação independente; entrada só inicializa este módulo.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Objetivos=require(RS.Shared.Regras.Objetivos)
local C=require(script.Parent.UI.Componentes)
local T=require(script.Parent.UI.Tema)
local FX=require(script.Parent.MenuEfeitos)
local View={}
function View.start(mesa)
	local pg=Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder="OrientacaoJogador",false,2
	gui.IgnoreGuiInset=true; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=pg
	local grupo=Instance.new("CanvasGroup",gui)
	grupo.Name="ObjetivoAtual"; grupo.BackgroundTransparency=1
	local painel=C.painel({parent=grupo,tamanho=UDim2.fromScale(1,1),padding=10,sombra=false})
	local icone=C.texto({parent=painel.Conteudo,texto="!",tamanho=UDim2.fromOffset(28,32)})
	icone.FontFace,icone.TextColor3,icone.TextSize=T.FONTE_ICONE,T.cores.ouro,30
	local titulo=C.titulo({parent=painel.Conteudo,posicao=UDim2.fromOffset(34,0),tamanho=UDim2.new(1,-34,0,28)})
	titulo.TextSize=T.tamanhos.subtitulo
	titulo.AutomaticSize=Enum.AutomaticSize.None; titulo.TextWrapped=false; titulo.TextTruncate=Enum.TextTruncate.AtEnd
	local linha=C.texto({parent=painel.Conteudo,posicao=UDim2.fromOffset(34,30),tamanho=UDim2.new(1,-34,0,48)})
	linha.AutomaticSize=Enum.AutomaticSize.None; linha.TextTruncate=Enum.TextTruncate.AtEnd
	local bloqueado,limparVisibilidade=require(script.Parent.OrientacaoVisibilidade).start(pg,gui)
	local marcadores=require(script.Parent.MarcadoresMundo).start(gui)
	local estado=require(script.Parent.ObjetivoEstado).start(mesa)
	local chave,pendente,cancelarAviso,acumulado=nil,nil,nil,0
	local conexao=RunService.Heartbeat:Connect(function(dt)
		acumulado+=dt; if acumulado<.1 then return end; acumulado=0
		local camera=workspace.CurrentCamera
		if not camera then return end
		estado:atualizar()
		local objetivo=Objetivos.atual(estado)
		local tela=camera.ViewportSize
		local inset=game:GetService("GuiService"):GetGuiInset()
		local topo=if tela.X<700 then math.max(90,inset.Y+80) else inset.Y+12
		grupo.Position=UDim2.fromOffset(12,topo)
		grupo.Size=UDim2.fromOffset(math.min(410,tela.X-24),106)
		local mostrar=not estado.emEncontro and not bloqueado(tela)
		grupo.Visible=mostrar and objetivo~=nil
		if objetivo and objetivo.chave~=chave then
			if chave then pendente=objetivo.titulo end
			chave=objetivo.chave; titulo.Text=objetivo.titulo; linha.Text=objetivo.linha
			grupo.GroupTransparency=1; FX.animar(grupo,.22,{GroupTransparency=0})
		elseif objetivo then linha.Text=objetivo.linha end
		if not mostrar and cancelarAviso then cancelarAviso(); cancelarAviso=nil end
		if mostrar and pendente then
			if cancelarAviso then cancelarAviso() end
			cancelarAviso=C.aviso({parent=gui,titulo="Novo objetivo",detalhe=pendente,duracao=2})
			pendente=nil
		end
		marcadores.atualizar(estado,objetivo,mostrar)
	end)
	gui.Destroying:Once(function()
		conexao:Disconnect(); estado:destruir(); marcadores.destruir(); limparVisibilidade()
		if cancelarAviso then cancelarAviso() end
	end)
	return gui
end
return View
