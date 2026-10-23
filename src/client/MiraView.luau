-- Alcance, contornos de fichas visíveis e alvo sob o mouse; não envia comandos.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Protocol = require(Shared.MesaProtocol)
local Estilo = require(Shared.Estilo)
local Tatica = require(Shared.MiraTatica)
local Area = require(Shared.AreaHabilidade)
local Execucao = require(Shared.Regras.Execucao)
local View = {}

function View.start(state, casaSobMouse)
	local pasta = Instance.new("Folder")
	pasta.Name, pasta.Parent = "MiraLocal", workspace
	local areaFolder = Instance.new("Folder", pasta)
	areaFolder.Name = "AreaPrevista"
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "MiraTatica", false, 7
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local texto = Instance.new("TextLabel")
	texto.Name, texto.AnchorPoint = "Alvo", Vector2.new(.5, 0)
	texto.Position, texto.Size = UDim2.new(.5, 0, 0, 122), UDim2.new(.9, 0, 0, 52)
	texto.BackgroundColor3, texto.BackgroundTransparency = Estilo.PAPEL_2, .05
	texto.FontFace, texto.TextSize, texto.TextWrapped = Estilo.ROTULO_FORTE, 16, true
	texto.Visible, texto.Parent = false, gui
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize, limite.Parent = Vector2.new(620, 52), texto
	local canto = Instance.new("UICorner")
	canto.CornerRadius, canto.Parent = UDim.new(0, 8), texto
	local reiniciar = Instance.new("TextButton")
	reiniciar.Name, reiniciar.Text = "TrocarInicio", "Trocar início"
	reiniciar.AnchorPoint, reiniciar.Position, reiniciar.Size = Vector2.new(.5,0),UDim2.new(.5,0,0,178),UDim2.fromOffset(180,44)
	reiniciar.BackgroundColor3,reiniciar.TextColor3,reiniciar.FontFace,reiniciar.TextSize = Estilo.BOTAO,Estilo.TINTA,Estilo.ROTULO_FORTE,16
	reiniciar.Visible,reiniciar.Parent = false,gui
	reiniciar.Activated:Connect(function()
		local mira=state.mira()
		if mira then local n=table.clone(mira);n.inicio=nil;n.ponto=nil;state.setMira(n) end
	end)
	local hover = Instance.new("Part")
	hover.Name, hover.Anchored, hover.CanCollide, hover.CanQuery, hover.CanTouch = "CasaSobMouse", true, false, false, false
	hover.Size, hover.Material = Vector3.new(Protocol.BOARD.cell - .2, .1, Protocol.BOARD.cell - .2), Enum.Material.Neon
	hover.Transparency = 1
	hover.Parent = workspace
	local destruido, versao, chave = false, 0, nil
	local function desenhar()
		if destruido then return end
		versao += 1
		for _,p in pasta:GetChildren() do if p~=areaFolder then p:Destroy() end end
		areaFolder:ClearAllChildren()
		hover.Transparency, texto.Visible = 1, false
		local mira, snap = state.mira(), state.snapshot()
		if not mira or not snap then return end
		local fonte = state.findToken(mira.tokenId)
		if not fonte then return end
		local alcance = mira.alcanceCasas or mira.raioCasas or mira.comprimentoCasas or 1
		for x = math.max(1, fonte.x - alcance), math.min(Protocol.BOARD.width, fonte.x + alcance) do
			for z = math.max(1, fonte.z - alcance), math.min(Protocol.BOARD.height, fonte.z + alcance) do
				if (x ~= fonte.x or z ~= fonte.z) and (mira.modo ~= "confirmar" or (x - fonte.x)^2 + (z - fonte.z)^2 <= alcance^2) then
					local p = Instance.new("Part")
					p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = "Alcance", true, false, false, false, false
					p.Size, p.Position = Vector3.new(Protocol.BOARD.cell - .5, .06, Protocol.BOARD.cell - .5), Protocol.cellCenter(x, z) + Vector3.new(0, .05, 0)
					p.Color, p.Material, p.Transparency, p.Parent = mira.cor or Estilo.DESTAQUE, Enum.Material.Neon, .88, pasta
				end
			end
		end
		if mira.modo == "ficha" or mira.modo == "lista" then
			for _, t in snap.tokens do
				local previa = Tatica.avaliar(snap, mira, t.x, t.z)
				if previa and not previa.motivo then
					local p = Instance.new("Part")
					p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = "Alvo_" .. t.id, true, false, false, false
					p.Size, p.Position, p.Transparency = Vector3.new(Protocol.BOARD.cell - .3, .14, Protocol.BOARD.cell - .3), Protocol.cellCenter(t.x, t.z) + Vector3.new(0, .2, 0), 1
					p.Parent = pasta
					local borda = Instance.new("SelectionBox")
					borda.Adornee, borda.SurfaceTransparency, borda.LineThickness = p, 1, if previa.selecionado then .1 else .04
					borda.Color3, borda.Parent = if previa.selecionado then Estilo.ALERTA elseif t.aliadoSeu then Estilo.SUCESSO else Estilo.PERIGO, p
				end
			end
		end
	end
	state.onMira(desenhar)
	state.onSnapshot(desenhar)
	local con = RunService.RenderStepped:Connect(function()
		local mira, snap = state.mira(), state.snapshot()
		local menu = gui.Parent:FindFirstChild("InicioJogo")
		if not mira or not snap or not state.tableView() or (menu and menu.MenuInicial.Visible) then
			texto.Visible, reiniciar.Visible, hover.Transparency, chave = false, false, 1, nil
			areaFolder:ClearAllChildren()
			return
		end
		local x, z = casaSobMouse()
		local nova = tostring(x) .. ":" .. tostring(z) .. ":" .. versao
		if nova == chave then return end
		chave = nova
		local mec=Execucao.MECANICAS[mira.habilidadeId]
		reiniciar.Visible=mec~=nil and mec.moldavel==true and mira.inicio~=nil
		areaFolder:ClearAllChildren()
		if Area.eArea(mec) then
			local fonte=state.findToken(mira.tokenId)
			if not fonte then return end
			local px,pz=if mira.ponto then mira.ponto[1] else x,if mira.ponto then mira.ponto[2] else z
			local pedido={x=px,z=pz}
			if mec.moldavel and mira.inicio and Protocol.isCell(px,pz) then
				pedido.x,pedido.z=Area.finalDaLinha(mira.inicio,px,pz,mec.comprimentoCasas)
				pedido.inicioX,pedido.inicioZ=mira.inicio[1],mira.inicio[2]
			end
			local function parede(cx,cz) return snap.map and (snap.map.terrain or {})[cx..","..cz]=="parede" end
			local function bloqueia(cx,cz)
				if parede(cx,cz) then return true end
				for _,m in (snap.jogo and snap.jogo.muros) or {} do if m.bloqueiaVisao then for _,c in m.casas do if c[1]==cx and c[2]==cz then return true end end end end
				return false
			end
			local casas,motivo
			if mec.moldavel and not mira.inicio then
				casas=if Protocol.isCell(x,z) then {{x,z}} else {}
				motivo=if not Protocol.isCell(x,z) or Protocol.distance(fonte.x,fonte.z,x,z)~=1 or parede(x,z) then "Escolha uma casa vizinha livre para começar." else nil
			else casas,motivo=Area.previa(fonte,mec,pedido,parede,bloqueia) end
			for _,c in casas or {} do
				local p=Instance.new("Part")
				p.Name,p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch="CasaDaArea",true,false,false,false
				p.Size,p.Position=Vector3.new(Protocol.BOARD.cell-.25,.12,Protocol.BOARD.cell-.25),Protocol.cellCenter(c[1],c[2])+Vector3.new(0,.23,0)
				p.Color,p.Material,p.Transparency,p.Parent=mira.cor or Estilo.ALERTA,Enum.Material.Neon,.45,areaFolder
			end
			local instrucao=if mec.moldavel then (if not mira.inicio then "1. Clique no início (ao seu lado)" elseif not mira.ponto then "2. Aponte a direção e clique no fim • até 6 casas" else "3. Confirmar área • clique em outra casa para ajustar") elseif mira.modo=="confirmar" then "Use o botão Usar habilidade" elseif mira.ponto then "Confirmar área • clique em outra casa para ajustar" else "Clique para fixar a área antes de confirmar"
			texto.Visible,texto.TextColor3,hover.Transparency=true,if motivo then Estilo.ALERTA else Estilo.TINTA,1
			texto.Text=(motivo or instrucao).."\n"..#(casas or {}).." casas na prévia • resultado validado pelo servidor"
			return
		end
		local p = Tatica.avaliar(snap, mira, x, z)
		texto.Visible = true
		if not p then
			hover.Transparency, texto.TextColor3 = 1, Estilo.TINTA
			texto.Text = if mira.modo == "confirmar" then "Ação sobre si • use o botão Usar habilidade" else "Mire no campo • clique direito ou Cancelar mira para voltar"
			return
		end
		local alvo = if p.alvo then p.alvo.name elseif p.barreira then "Barreira" else string.format("Casa %d, %d", x, z)
		local instrucao = p.motivo or (if mira.modo == "lista" then (if p.selecionado then "Selecionado • clique para remover" else "Clique para selecionar") elseif mira.modo == "confirmar" then "Use o botão Usar habilidade" else "No alcance • clique para usar")
		if mira.modo == "lista" then instrucao ..= string.format(" • %d/%d alvos", #(mira.alvoIds or {}), mira.maxAlvos or 1) end
		texto.Text, texto.TextColor3 = alvo .. " • " .. p.distancia .. "/" .. p.alcance .. " casas\n" .. instrucao, if p.motivo then Estilo.ALERTA else Estilo.TINTA
		hover.Position, hover.Color, hover.Transparency = Protocol.cellCenter(x, z) + Vector3.new(0, .15, 0), if p.motivo then Estilo.PERIGO else Estilo.SUCESSO, .65
	end)
	gui.Destroying:Connect(function() destruido = true; con:Disconnect(); pasta:Destroy(); hover:Destroy() end)
	desenhar()
	return gui
end

return View
