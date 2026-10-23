-- Apresentação local G1. Instâncias reutilizadas; atualização chamada no máximo a 10 Hz.
local RS=game:GetService("ReplicatedStorage")
local Regras=require(RS.Shared.Regras.MarcadoresOrientacao)
local C=require(script.Parent.UI.Componentes)
local T=require(script.Parent.UI.Tema)
local FX=require(script.Parent.MenuEfeitos)
local M={}
function M.start(gui)
	local selos={}
	local seta=C.texto({parent=gui,nome="DirecaoObjetivo",texto="▶",tamanho=UDim2.fromOffset(36,36)})
	seta.FontFace,seta.TextColor3,seta.TextSize=T.FONTE_ICONE,T.cores.ouro,32
	seta.AnchorPoint=Vector2.new(.5,.5); seta.Visible=false
	local distancia=C.texto({parent=gui,nome="DistanciaObjetivo",tamanho=UDim2.fromOffset(90,24)})
	distancia.AnchorPoint=Vector2.new(.5,0); distancia.TextXAlignment=Enum.TextXAlignment.Center; distancia.Visible=false
	local anel=Instance.new("Part")
	anel.Name="DestinoObjetivoLocal"
	anel.Size=Vector3.new(5,.05,5); anel.Anchored=true
	anel.CanCollide,anel.CanTouch,anel.CanQuery=false,false,false
	anel.Color,anel.Material,anel.Transparency=T.cores.ouro,Enum.Material.Neon,1
	anel.Parent=workspace
	local superficie=Instance.new("SurfaceGui",anel)
	superficie.Face=Enum.NormalId.Top; superficie.CanvasSize=Vector2.new(128,128); superficie.Enabled=false
	local aro=Instance.new("Frame",superficie)
	aro.Size,aro.Position,aro.BackgroundTransparency=UDim2.fromOffset(112,112),UDim2.fromOffset(8,8),1
	Instance.new("UICorner",aro).CornerRadius=UDim.new(1,0)
	local fio=Instance.new("UIStroke",aro); fio.Color,fio.Thickness,fio.Transparency=T.cores.ouro,3,.4
	local luz=Instance.new("PointLight",anel)
	luz.Color,luz.Range,luz.Brightness,luz.Enabled=T.cores.ouro,8,.35,false
	local api={}
	function api.atualizar(e,objetivo,mostrar)
		mostrar=mostrar and FX.orientacao~=false
		local vistos={}
		for _, npc in e.npcs do
			local glifo=if mostrar then Regras.glifo(npc,e) else nil
			local selo=selos[npc.modelo]
			if glifo and not selo then
				selo=Instance.new("BillboardGui")
				selo.Name="NovidadeObjetivoLocal"; selo.Adornee=npc.modelo:FindFirstChild("Head") or npc.base
				selo.Size=UDim2.fromOffset(36,48); selo.StudsOffset=Vector3.new(0,6,0)
				selo.AlwaysOnTop,selo.LightInfluence,selo.MaxDistance=true,0,100
				local texto=C.texto({parent=selo,nome="Glifo",tamanho=UDim2.fromScale(1,1)})
				texto.FontFace,texto.TextColor3,texto.TextSize=T.FONTE_ICONE,T.cores.ouro,40
				texto.TextXAlignment=Enum.TextXAlignment.Center
				selo.Parent=gui; selos[npc.modelo]=selo
			end
			if selo then selo.Enabled=glifo~=nil; selo.Glifo.Text=glifo or ""; vistos[npc.modelo]=true end
		end
		for modelo, selo in selos do if not vistos[modelo] then selo:Destroy(); selos[modelo]=nil end end
		seta.Visible,distancia.Visible=false,false
		superficie.Enabled,luz.Enabled=false,false
		local alvo=objetivo and objetivo.alvo
		local p=alvo and (alvo.posicao or e.destinos[alvo.id])
		local camera=workspace.CurrentCamera
		if not mostrar or not p or not camera or not e.posicao then return end
		local mundo=Vector3.new(p.x,p.y or 0,p.z)
		local projetado=camera:WorldToViewportPoint(mundo)
		local tela=camera.ViewportSize
		local b=Regras.borda(projetado.X-tela.X/2,projetado.Y-tela.Y/2,projetado.Z,tela.X,tela.Y,32)
		local metros=(mundo-Vector3.new(e.posicao.x,e.posicao.y,e.posicao.z)).Magnitude*.28
		if b then
			-- ScreenGui usa a mesma origem da projeção (IgnoreGuiInset).
			seta.Visible=true; seta.Position=UDim2.fromOffset(b.x,b.y); seta.Rotation=b.rotacao
			distancia.Visible=true; distancia.Text=string.format("%d m",math.floor(metros+.5))
			distancia.Position=UDim2.fromOffset(math.clamp(b.x,48,tela.X-48),math.clamp(b.y+18,32,tela.Y-28))
		end
		if metros<=20 then
			-- O terreno define o chão; telhados, o sino e NPCs não elevam o aro.
			local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances={workspace.Terrain}
			local hit=workspace:Raycast(mundo+Vector3.new(0,40,0),Vector3.new(0,-100,0),params)
			local chao=hit and hit.Position or Vector3.new(p.x,0,p.z)
			anel.CFrame=CFrame.new(chao+Vector3.new(0,.1,0))
			superficie.Enabled=true; luz.Enabled=not FX.reduzidos
		end
	end
	function api.destruir() for _, s in selos do s:Destroy() end; anel:Destroy() end
	return api
end
return M
