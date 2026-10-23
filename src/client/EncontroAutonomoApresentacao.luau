-- Somente projeção de estados/recibos J2; nenhuma intenção ou regra nova.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Extra = require(script.Parent.UI.ExtraCombate)
local T, C = Extra.tema, Extra.componentes
local FX = require(script.Parent.MenuEfeitos)
local Efeitos = require(script.Parent.Efeitos)
local Dados = require(game:GetService("ReplicatedStorage").Shared.EncontroApresentacaoDados)
local A = {}
local function seguro(id) return (tostring(id):gsub("[^%w%-_]", "_")) end
local function corRecibo(r)
	if r.healing ~= nil then return T.cores.sucesso end
	if r.attack and r.attack.acertou == false then return T.cores.secundario end
	if (r.damageDealt or 0) > 0 or r.turnStartDamage then return T.cores.perigo end
	return T.cores.alerta
end
function A.start(gui, state)
	local api, atual, encontroId = {}, nil, nil
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local flutuantes = {}
 local posicoes, inicioImpacto = {}, -math.huge
 local anuncio = C.titulo({parent=gui, nome="AnuncioEncontro", texto="", tamanho=UDim2.new(1,-24,0,88), posicao=UDim2.new(0,12,.22,0)})
 anuncio.TextSize, anuncio.TextColor3, anuncio.TextXAlignment = 34, T.cores.ouro, Enum.TextXAlignment.Center
 anuncio.Visible = false
 -- Compõe só um impulso local sobre a pose entregue pela câmera existente.
 -- Retira o impulso antes do próximo frame, inclusive se a câmera estiver congelada.
 local cameraAplicada, poseBase, poseAplicada
 local function retirarImpulso()
  if cameraAplicada and cameraAplicada.Parent and cameraAplicada.CFrame == poseAplicada then cameraAplicada.CFrame = poseBase end
  cameraAplicada, poseBase, poseAplicada = nil, nil, nil
 end
 RunService:BindToRenderStep("J2ImpulsoAntes", Enum.RenderPriority.Camera.Value-2, retirarImpulso)
 RunService:BindToRenderStep("J2ImpulsoDepois", Enum.RenderPriority.Camera.Value+8, function()
  local p = Dados.pulso(os.clock()-inicioImpacto)
  local cam = workspace.CurrentCamera
  if p == 0 or not cam or FX.reduzidos then return end
  cameraAplicada, poseBase = cam, cam.CFrame
  poseAplicada = poseBase * CFrame.new(0,0,-.65*p) * Efeitos.tremorCFrame()
  cam.CFrame = poseAplicada
 end)
	local retrato = C.painel({parent = gui, nome = "EstadoJogador", tamanho = UDim2.fromOffset(218, 160), posicao = UDim2.fromOffset(8, 98), padding = 8})
	local nome = C.titulo({parent = retrato.Conteudo, nome = "Nome", texto = "", tamanho = UDim2.new(1, 0, 0, 28)})
	nome.TextWrapped, nome.TextTruncate, nome.AutomaticSize, nome.TextSize = false, Enum.TextTruncate.AtEnd, Enum.AutomaticSize.None, T.tamanhos.subtitulo -- nome longo não pode invadir a barra de PV
	local barraPV, pv = C.barra({parent = retrato.Conteudo, nome = "PV", rotulo = "♥ PV", destaque = T.cores.sucesso, posicao = UDim2.fromOffset(0, 32)})
	local barraPM, pm = C.barra({parent = retrato.Conteudo, nome = "PM", rotulo = "PM", destaque = T.cores.info, posicao = UDim2.fromOffset(0, 88)})
	local condicoes = C.texto({parent = retrato.Conteudo, nome = "Condicoes", posicao = UDim2.fromOffset(0, 145), tamanho = UDim2.new(1, 0, 0, 24)})
	local fila = Instance.new("ScrollingFrame")
	fila.Name, fila.Size, fila.Position = "OrdemTurno", UDim2.new(1, -16, 0, 44), UDim2.fromOffset(8, 48)
	fila.BackgroundColor3, fila.BackgroundTransparency, fila.BorderSizePixel = T.cores.painel, T.transparencias.painel, 0
	fila.ScrollingDirection, fila.ScrollBarThickness, fila.CanvasSize = Enum.ScrollingDirection.X, 3, UDim2.new()
	fila.Parent = gui
	local registro = C.painel({parent = gui, nome = "RegistroCombate", tamanho = UDim2.fromOffset(260, 188), ancora = Vector2.new(1, 0), posicao = UDim2.new(1, -8, 0, 98), padding = 8})
	local abrir = C.botao({parent = registro.Conteudo, nome = "AbrirHistorico", texto = "Registro completo", variante = "secundario", tamanho = UDim2.new(1, 0, 0, 44)})
	local linhas = {}
	local ultimas = Instance.new("ScrollingFrame")
	ultimas.Name, ultimas.Size, ultimas.Position = "UltimasLinhas", UDim2.new(1, 0, 1, -48), UDim2.fromOffset(0, 48)
	ultimas.BackgroundTransparency, ultimas.BorderSizePixel, ultimas.ScrollBarThickness = 1, 0, 3
	ultimas.AutomaticCanvasSize, ultimas.CanvasSize, ultimas.Parent = Enum.AutomaticSize.Y, UDim2.new(), registro.Conteudo
	local ultimasLayout = Instance.new("UIListLayout"); ultimasLayout.SortOrder = Enum.SortOrder.LayoutOrder; ultimasLayout.Padding = UDim.new(0, 6); ultimasLayout.Parent = ultimas
	for i = 1, 4 do
		linhas[i] = C.texto({parent = ultimas, nome = "Linha" .. i, tamanho = UDim2.new(1, -6, 0, 0), ordem = i})
		linhas[i].TextSize = 14
	end
	local historico = C.painel({parent = gui, nome = "HistoricoCombate", tamanho = UDim2.new(1, -24, 1, -100), posicao = UDim2.fromOffset(12, 50), padding = 12, zIndex = 30})
	historico.Visible = false
	local fechar = C.botao({parent = historico.Conteudo, nome = "Fechar", texto = "Fechar histórico", variante = "secundario", tamanho = UDim2.new(1, 0, 0, 44), aoClicar = function() historico.Visible = false end})
	fechar.ZIndex = 32; fechar.Rotulo.ZIndex = 33
	local rolagem = Instance.new("ScrollingFrame")
	rolagem.Name, rolagem.Position, rolagem.Size = "Linhas", UDim2.fromOffset(0, 52), UDim2.new(1, 0, 1, -52)
	rolagem.BackgroundTransparency, rolagem.BorderSizePixel, rolagem.ScrollBarThickness = 1, 0, 6
	rolagem.AutomaticCanvasSize, rolagem.CanvasSize, rolagem.ZIndex = Enum.AutomaticSize.Y, UDim2.new(), 32
	rolagem.Parent = historico.Conteudo
	local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = rolagem
	abrir.Activated:Connect(function() historico.Visible = not historico.Visible end)
	local entradas, textosHistorico, placas, alvos = {}, {}, {}, {}
	local selecao = Instance.new("SelectionBox")
	selecao.Name, selecao.Color3, selecao.SurfaceTransparency, selecao.LineThickness = "AlvoJ2", T.cores.ouro, 1, .04
	selecao.Parent = gui
	local alvoSelecionado, danoCausado, danoRecebido = nil, 0, 0
 local function localizar(id)
  local userId = id and tonumber(string.match(id, "^jogador:(%-?%d+)$"))
  local jogador = userId and Players:GetPlayerByUserId(userId)
  local personagem = jogador and jogador.Character
  local pasta = atual and workspace:FindFirstChild("MiniaturasJ2_"..seguro(atual.encounterId))
  local alvo = personagem and (personagem:FindFirstChild("Head") or personagem:FindFirstChild("HumanoidRootPart"))
   or pasta and pasta:FindFirstChild("Ator_"..seguro(id))
  if alvo then posicoes[id] = alvo.Position end
  return alvo
 end
 local function celebrarQueda(id)
  local alvo = localizar(id)
  local pos = alvo and alvo.Position or posicoes[id]
  if not pos or FX.reduzidos then return end
  local apoio = Instance.new("Attachment")
  apoio.Name, apoio.Position, apoio.Parent = "QuedaJ2", pos, workspace.Terrain
  local brilho = Instance.new("ParticleEmitter")
  brilho.Texture = "rbxasset://textures/particles/sparkles_main.dds"
  brilho.Color, brilho.LightEmission = ColorSequence.new(T.cores.ouro), .7
  brilho.Lifetime, brilho.Speed, brilho.SpreadAngle = NumberRange.new(.25,.55), NumberRange.new(2,5), Vector2.new(180,180)
  brilho.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,.24),NumberSequenceKeypoint.new(1,0)})
  brilho.Rate, brilho.Parent = 0, apoio
  brilho:Emit(14); Debris:AddItem(apoio,1)
 end
	function api.selecionar(id) alvoSelecionado = id end
	local function limparPlacas()
		for _, p in placas do p:Destroy() end
		table.clear(placas); table.clear(alvos)
		selecao.Adornee = nil
		for b, apoio in flutuantes do b:Destroy(); apoio:Destroy() end
		table.clear(flutuantes)
	end
	function api.atualizar(s)
		local anterior = atual
		atual = s
  if s and anterior and anterior.encounterId == s.encounterId then
   for _, id in Dados.derrotados(anterior.actors,s.actors) do celebrarQueda(id) end
  end
		local ativo = s ~= nil and s.phase == "active"
		retrato.Visible, fila.Visible, registro.Visible = ativo, ativo, ativo
		if not ativo then historico.Visible = false; anuncio.Visible = false; inicioImpacto = -math.huge; limparPlacas(); return end
		if encontroId ~= s.encounterId then
   table.clear(posicoes)
   inicioImpacto = os.clock()
   anuncio.Text, anuncio.Visible = "ENCONTRO!\n"..Dados.inimigos(s.actors), true
   if not FX.reduzidos then Efeitos.tremer(.12,.35) end
   local chave = s.encounterId
   task.delay(.8,function() if encontroId == chave and anuncio.Parent then anuncio.Visible=false end end)
			encontroId, alvoSelecionado, danoCausado, danoRecebido = s.encounterId, nil, 0, 0
			table.clear(entradas); table.clear(textosHistorico); rolagem:ClearAllChildren(); layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 8); layout.Parent = rolagem
			Players.LocalPlayer:SetAttribute("DanoJ2Causado", 0); Players.LocalPlayer:SetAttribute("DanoJ2Recebido", 0)
			for _, l in linhas do l.Text = "" end
		end
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local estreito = viewport.X < 700
  retrato.Size = UDim2.fromOffset(if estreito then math.max(164, viewport.X - 132) else 218, if estreito then 84 else 190)
  nome.TextSize = if estreito then 16 else T.tamanhos.subtitulo
  nome.Size = UDim2.new(1,0,0,if estreito then 20 else 28)
  for i, barra in {barraPV,barraPM} do
   barra.Position = UDim2.fromOffset(0,if estreito then 22+(i-1)*24 elseif i==1 then 32 else 88)
   barra.Size = UDim2.new(1,0,0,if estreito then 24 else 56)
   barra.Trilho.Position = UDim2.fromOffset(0,if estreito then 18 else 26)
   barra.Trilho.Size = UDim2.new(1,0,0,if estreito then 4 else 10)
   for _,label in barra:GetChildren() do
    if label:IsA("TextLabel") then label.TextSize=if estreito then 14 else T.tamanhos.rotulo; label.AutomaticSize=Enum.AutomaticSize.None; label.Size=UDim2.new(label.Size.X.Scale,label.Size.X.Offset,0,18) end
   end
  end
  condicoes.Visible = not estreito
  ultimas.Visible = not estreito
  abrir.Rotulo.Text = if estreito then "Registro" else "Registro completo"
  abrir.Rotulo.Position, abrir.Rotulo.Size, abrir.Rotulo.TextWrapped = UDim2.new(), UDim2.fromScale(1, 1), false -- "Registro" quebrava em 2 linhas no celular
  if estreito then abrir.Rotulo.TextSize = 14 end
  registro.Size = UDim2.fromOffset(if estreito then 108 else 280,if estreito then 60 else 188)
		local porId = {}
		for _, ator in s.actors or {} do
			porId[ator.id] = ator
			if ator.id == s.controlledActorId then
				nome.Text = (ator.name or "Você")
				pv((ator.pv or 0) / math.max(1, ator.pvMax or 1), string.format("%s/%s", tostring(ator.pv or 0), tostring(ator.pvMax or 0)))
				pm((ator.pm or 0) / math.max(1, ator.pmMax or 1), string.format("%s/%s", tostring(ator.pm or 0), tostring(ator.pmMax or 0)))
				local nomes = {}
				for k, v in pairs(ator.conditions or {}) do if v then table.insert(nomes, tostring(if type(k) == "number" then v else k)) end end
				if ator.defenderReduction then table.insert(nomes, "Defendendo") end
				condicoes.Text = table.concat(nomes, " · ")
			end
		end
		fila:ClearAllChildren()
		local ordem = {}
		for _, rolagem in ipairs(s.initiativeRolls or {}) do
			if porId[rolagem.actorId] then table.insert(ordem, porId[rolagem.actorId]) end
		end
		if #ordem == 0 then ordem = s.actors or {} end
		for i, ator in ipairs(ordem) do
			local id = ator.id
			local t = C.texto({parent = fila, nome = "Vez_" .. seguro(id), texto = (if id == s.currentActorId then "▶ " else "") .. (ator and ator.name or id), tamanho = UDim2.fromOffset(118, 44), posicao = UDim2.fromOffset((i - 1) * 124, 0)})
			t.AutomaticSize = Enum.AutomaticSize.None
			t.TextYAlignment, t.TextSize, t.TextTruncate = Enum.TextYAlignment.Center, 16, Enum.TextTruncate.AtEnd -- cabe numa linha, centralizado na faixa de 44 px
			t.TextColor3 = if id == s.currentActorId then T.cores.ouro elseif ator and ator.kind == "jogador" then T.cores.info else T.cores.perigo
		end
		fila.CanvasSize = UDim2.fromOffset(#ordem * 124, 44)
	end
	local function flutuar(id, texto, cor)
		if not id then return end
  local alvo = localizar(id)
  local pos = alvo and alvo.Position or posicoes[id]
  if not pos then return end
		-- Miniaturas são recriadas pelo servidor; o impacto conserva a posição
		-- confirmada em um Attachment local, independente da próxima réplica.
		local apoio = Instance.new("Attachment")
		apoio.Name, apoio.Position, apoio.Parent = "ImpactoJ2Posicao", pos, workspace.Terrain
		local b = Instance.new("BillboardGui")
		b.Name, b.Adornee, b.Size, b.AlwaysOnTop = "ImpactoJ2", apoio, UDim2.fromOffset(140, 44), true
		b.StudsOffsetWorldSpace, b.Parent = Vector3.new(0, 4, 0), playerGui
		flutuantes[b] = apoio
		local t = C.texto({parent = b, texto = texto, tamanho = UDim2.fromScale(1, 1)})
		t.FontFace, t.TextSize, t.TextColor3 = T.fontes.numero, 36, cor
  t.TextStrokeTransparency, t.TextStrokeColor3 = .2, T.cores.painel
		if not FX.reduzidos then TweenService:Create(b, TweenInfo.new(1.1), {StudsOffsetWorldSpace = Vector3.new(0, 6, 0)}):Play() end
		TweenService:Create(t, TweenInfo.new(1.1), {TextTransparency = 1}):Play()
		Debris:AddItem(b, 1.2)
		Debris:AddItem(apoio, 1.2)
		task.delay(1.2, function() flutuantes[b] = nil end)
	end
	function api.registrar(texto, recibo)
		if not gui.Parent or not texto then return end
		local r = recibo and recibo.result or {}
		local cor = corRecibo(r)
		table.insert(entradas, {texto = texto, cor = cor})
		if #entradas > 160 then table.remove(entradas, 1); table.remove(textosHistorico, 1):Destroy() end
		local t = C.texto({parent = rolagem, nome = "Entrada" .. tostring(#entradas), texto = texto, tamanho = UDim2.new(1, -10, 0, 0), ordem = #entradas})
		t.ZIndex, t.TextColor3 = 33, cor
		table.insert(textosHistorico, t)
		for i, textoHistorico in textosHistorico do textoHistorico.LayoutOrder = i end
		for i, l in linhas do
			local e = entradas[#entradas - 4 + i]
			l.Text, l.TextColor3 = e and e.texto or "", e and e.cor or T.cores.texto
		end
		local id = r.targetId or (recibo and recibo.targetId)
		if id then alvoSelecionado = id end
		if r.attack and r.attack.acertou == false then flutuar(id, "errou", T.cores.secundario) end
		if (r.damageDealt or 0) > 0 then flutuar(id, "−" .. tostring(r.damageDealt), T.cores.perigo) end
		if (r.healing or 0) > 0 then flutuar(id, "+" .. tostring(r.healing), T.cores.sucesso) end
		for _, alvo in ipairs(r.targets or {}) do
			local alvoId = alvo.actorId or alvo.targetId or alvo.id
			if (alvo.damageDealt or 0) > 0 then flutuar(alvoId, "−" .. tostring(alvo.damageDealt), T.cores.perigo) end
   if (alvo.healing or 0) > 0 then flutuar(alvoId, "+"..tostring(alvo.healing), T.cores.sucesso) end
		end
		if atual and recibo then
			if recibo.actorId == atual.controlledActorId then danoCausado += r.damageDealt or 0; for _, a in ipairs(r.targets or {}) do danoCausado += a.damageDealt or 0 end end
			if id == atual.controlledActorId then danoRecebido += r.damageDealt or 0 end
			for _, a in ipairs(r.targets or {}) do if (a.actorId or a.targetId or a.id) == atual.controlledActorId then danoRecebido += a.damageDealt or 0 end end
			Players.LocalPlayer:SetAttribute("DanoJ2Causado", danoCausado); Players.LocalPlayer:SetAttribute("DanoJ2Recebido", danoRecebido)
		end
	end
	local acumulado = 0
	local conexao = RunService.Heartbeat:Connect(function(dt)
		acumulado += dt; if acumulado < .2 then return end; acumulado = 0
		if not atual or atual.phase ~= "active" then return end
		local pasta = workspace:FindFirstChild("MiniaturasJ2_" .. seguro(atual.encounterId))
		selecao.Adornee = alvoSelecionado and alvos[alvoSelecionado] or nil
		for _, ator in atual.actors or {} do
			local userId = tonumber(string.match(ator.id, "^jogador:(%-?%d+)$"))
			local jogador = userId and Players:GetPlayerByUserId(userId)
			local personagem = jogador and jogador.Character
			local alvo = personagem and (personagem:FindFirstChild("Head") or personagem:FindFirstChild("HumanoidRootPart"))
			local token = pasta and pasta:FindFirstChild("Ator_" .. seguro(ator.id))
			if token then local legado = token:FindFirstChild("Estado"); if legado then legado.Enabled = false end end
			if not alvo then alvo = token end
			alvos[ator.id] = alvo
   if alvo then posicoes[ator.id] = alvo.Position end
			if not alvo or ator.fled then if placas[ator.id] then placas[ator.id]:Destroy(); placas[ator.id] = nil end; continue end
			local b = placas[ator.id]
			if not b then
				b = Instance.new("BillboardGui"); b.Name = "PVJ2_" .. seguro(ator.id); b.Size = UDim2.fromOffset(130, 36); b.AlwaysOnTop = true
				b.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0); b.Parent = playerGui
				local n = C.texto({parent = b, nome = "Nome", tamanho = UDim2.new(1, 0, 0, 22)}); n.TextSize = 14
				local trilho = Instance.new("Frame"); trilho.Name = "Trilho"; trilho.Size = UDim2.new(1, 0, 0, 6); trilho.Position = UDim2.fromOffset(0, 26); trilho.BackgroundColor3 = T.cores.fio; trilho.BorderSizePixel = 0; trilho.Parent = b
				local barra = Instance.new("Frame"); barra.Name = "Valor"; barra.BorderSizePixel = 0; barra.Parent = trilho
				placas[ator.id] = b
			end
			b.Adornee = alvo
			-- Criaturas com modelo: etiqueta acima da cabeça (altura publicada pelo token do servidor).
			b.StudsOffsetWorldSpace = Vector3.new(0, alvo:GetAttribute("AlturaEtiqueta") or 2.8, 0)
			b.Nome.Text = (if alvoSelecionado == ator.id then "◎ " else "") .. string.sub(ator.name or "", 1, 18) .. " " .. tostring(ator.pv or 0)
			b.Nome.TextColor3 = if alvoSelecionado == ator.id then T.cores.ouro else T.cores.texto
			b.Trilho.Valor.Size = UDim2.fromScale(math.clamp((ator.pv or 0) / math.max(1, ator.pvMax or 1), 0, 1), 1)
			b.Trilho.Valor.BackgroundColor3 = if ator.kind == "jogador" then T.cores.sucesso else T.cores.perigo
		end
	end)
	function api.destruir()
  conexao:Disconnect(); limparPlacas(); retirarImpulso()
  RunService:UnbindFromRenderStep("J2ImpulsoAntes"); RunService:UnbindFromRenderStep("J2ImpulsoDepois")
 end
	api.atualizar(nil)
	return api
end
return A
