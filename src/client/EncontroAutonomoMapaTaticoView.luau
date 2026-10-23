-- Mapa tático local; casas ocupadas refletem somente o snapshot do servidor.

local MapaTatico = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoMapaTatico)
local HabilidadesAutonomas = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoHabilidades)
local Terreno = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoTerreno)
local TweenService = game:GetService("TweenService")

local MapaTaticoView = {}
local LADO = 20
local MURO = "ability/fogo/Principiante/muro-de-chamas"
local MURO_TERRA = HabilidadesAutonomas.MURO_DE_TERRA
local ANTEPARO = HabilidadesAutonomas.ANTEPARO_TEORICO
local ESCUDO_AGUA = HabilidadesAutonomas.ESCUDO_DE_AGUA
local NEVOA_DENSA = HabilidadesAutonomas.NEVOA_DENSA
local SOPRO_DE_POEIRA = HabilidadesAutonomas.SOPRO_DE_POEIRA
local PASSO_DE_VENTO = HabilidadesAutonomas.PASSO_DE_VENTO
local CLARAO = "ability/fogo/Principiante/clarao"

function MapaTaticoView.start(parent, state)
	local Tema = require(script.Parent.UI.Tema)
	local cores = Tema.cores
	local atualizar, estadoAtual, centralizarMapa
	local abrirMapa = Instance.new("TextButton")
	abrirMapa.Name, abrirMapa.AnchorPoint, abrirMapa.Position = "AbrirMapaTatico", Vector2.new(1, 1), UDim2.new(1, -12, 1, -12)
	abrirMapa.Size, abrirMapa.Text = UDim2.fromOffset(132, 48), "Mapa tático"
	abrirMapa.BackgroundColor3, abrirMapa.TextColor3 = cores.painel, cores.texto
	abrirMapa.FontFace, abrirMapa.TextSize, abrirMapa.ZIndex = Tema.fontes.rotulo, Tema.tamanhos.rotulo, 6
	abrirMapa.Visible, abrirMapa.Parent = false, parent
	local abrirCanto = Instance.new("UICorner"); abrirCanto.CornerRadius, abrirCanto.Parent = UDim.new(0, Tema.raios.botao), abrirMapa
	local abrirBorda = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)(); abrirBorda.Color, abrirBorda.Thickness, abrirBorda.Parent = cores.borda, Tema.espessuras.borda, abrirMapa

	local painel = Instance.new("Frame")
	painel.Name, painel.Size, painel.Position = "MapaTatico", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0)
	painel.BackgroundColor3, painel.BackgroundTransparency = cores.fio, .16
	painel.Visible, painel.ZIndex, painel.Parent = false, 20, parent
	painel.Active = true
	local cartao = Instance.new("Frame")
	cartao.Name, cartao.AnchorPoint, cartao.Position = "Cartao", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
	cartao.Size, cartao.BackgroundColor3, cartao.BorderSizePixel = UDim2.new(1, -16, 1, -16), cores.painel, 0
	cartao.ZIndex, cartao.Parent = 21, painel
	local cartaoCanto = Instance.new("UICorner"); cartaoCanto.CornerRadius, cartaoCanto.Parent = UDim.new(0, Tema.raios.painel), cartao
	local cartaoBorda = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)(); cartaoBorda.Color, cartaoBorda.Thickness, cartaoBorda.Parent = cores.borda, Tema.espessuras.borda, cartao
	local fecharMapa = Instance.new("TextButton")
	fecharMapa.Name, fecharMapa.Position, fecharMapa.Size = "FecharMapa", UDim2.new(1, -52, 0, 6), UDim2.fromOffset(44, 44)
	fecharMapa.Text, fecharMapa.TextSize, fecharMapa.FontFace = "X", Tema.tamanhos.titulo, Tema.fontes.rotulo
	fecharMapa.BackgroundColor3, fecharMapa.TextColor3, fecharMapa.ZIndex, fecharMapa.Parent = cores.painel, cores.texto, 22, cartao
	local fecharCanto = Instance.new("UICorner"); fecharCanto.CornerRadius, fecharCanto.Parent = UDim.new(0, Tema.raios.botao), fecharMapa
	local fecharBorda = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)(); fecharBorda.Color, fecharBorda.Thickness, fecharBorda.Parent = cores.borda, Tema.espessuras.borda, fecharMapa
	fecharMapa.Activated:Connect(function() painel.Visible = false end)
	abrirMapa.Activated:Connect(function()
		painel.Visible = true
		if atualizar then atualizar(estadoAtual or state.estado()) end
		task.defer(centralizarMapa)
	end)
	local titulo = Instance.new("TextLabel")
	titulo.Name, titulo.Position = "Legenda", UDim2.fromOffset(12, 7)
	titulo.Size, titulo.BackgroundTransparency = UDim2.new(1, -76, 0, 30), 1
	titulo.TextColor3, titulo.FontFace, titulo.TextSize = cores.titulo, Tema.fontes.titulo, Tema.tamanhos.subtitulo
	titulo.TextXAlignment, titulo.TextTruncate, titulo.ZIndex, titulo.Parent = Enum.TextXAlignment.Left, Enum.TextTruncate.AtEnd, 22, cartao
	local legenda = Instance.new("TextLabel")
	legenda.Name, legenda.Position, legenda.Size = "LegendaCores", UDim2.fromOffset(12, 38), UDim2.new(1, -24, 0, 32)
	legenda.BackgroundTransparency, legenda.TextColor3, legenda.FontFace = 1, cores.secundario, Tema.fontes.corpo
	legenda.TextSize, legenda.TextWrapped, legenda.TextXAlignment = Tema.tamanhos.rotulo, true, Enum.TextXAlignment.Left
	legenda.Text, legenda.ZIndex, legenda.Parent = "Verde: destino | Ouro: você | Vinho: criaturas | Cinza: terreno | ~ água/lama, N névoa, F fogo", 22, cartao
	local areaGrade = Instance.new("ScrollingFrame")
	areaGrade.Name, areaGrade.Position = "AreaRolavel", UDim2.fromOffset(12, 74)
	areaGrade.BackgroundTransparency, areaGrade.BorderSizePixel = 1, 0
	areaGrade.ScrollBarThickness, areaGrade.ScrollingDirection = 8, Enum.ScrollingDirection.XY
	areaGrade.AutomaticCanvasSize, areaGrade.CanvasSize, areaGrade.ZIndex = Enum.AutomaticSize.XY, UDim2.new(), 22
	areaGrade.Parent = cartao
	local grade = Instance.new("Frame")
	grade.Name, grade.BackgroundTransparency, grade.ZIndex, grade.Parent = "Casas", 1, 23, areaGrade
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder, layout.CellPadding, layout.Parent = Enum.SortOrder.LayoutOrder, UDim2.fromOffset(1, 1), grade
	local confirmarMuro = Instance.new("TextButton")
	confirmarMuro.Name, confirmarMuro.Size = "ConfirmarMuro", UDim2.new(.5, -18, 0, 48)
	confirmarMuro.Position, confirmarMuro.AnchorPoint = UDim2.new(0, 12, 1, -56), Vector2.zero
	confirmarMuro.BackgroundColor3, confirmarMuro.TextColor3 = cores.ouro, cores.textoEscuro
	confirmarMuro.FontFace, confirmarMuro.TextSize = Tema.fontes.rotulo, Tema.tamanhos.rotulo
	confirmarMuro.Text, confirmarMuro.Visible, confirmarMuro.ZIndex = "Confirmar", false, 22
	confirmarMuro.Parent = cartao
	local confirmarCanto = Instance.new("UICorner"); confirmarCanto.CornerRadius, confirmarCanto.Parent = UDim.new(0, Tema.raios.botao), confirmarMuro
	local confirmarBorda = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)(); confirmarBorda.Color, confirmarBorda.Thickness, confirmarBorda.Parent = cores.borda, Tema.espessuras.borda, confirmarMuro
	local cancelarMuro = Instance.new("TextButton")
	cancelarMuro.Name, cancelarMuro.Size = "CancelarMuro", UDim2.new(.5, -18, 0, 48)
	cancelarMuro.Position, cancelarMuro.AnchorPoint = UDim2.new(.5, 6, 1, -56), Vector2.zero
	cancelarMuro.BackgroundColor3, cancelarMuro.TextColor3 = cores.painel, cores.texto
	cancelarMuro.FontFace, cancelarMuro.TextSize = Tema.fontes.rotulo, Tema.tamanhos.rotulo
	cancelarMuro.Text, cancelarMuro.Visible, cancelarMuro.ZIndex = "Cancelar", false, 22
	cancelarMuro.Parent = cartao
	local cancelarCanto = Instance.new("UICorner"); cancelarCanto.CornerRadius, cancelarCanto.Parent = UDim.new(0, Tema.raios.botao), cancelarMuro
	local cancelarBorda = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)(); cancelarBorda.Color, cancelarBorda.Thickness, cancelarBorda.Parent = cores.borda, Tema.espessuras.borda, cancelarMuro
	local casas = table.create(LADO * LADO)
	local destinosAtuais = {}
	local candidatosMuro = {}
	local muroSelecionado
	local ultimaMira
	for z = 1, LADO do
		for x = 1, LADO do
			local indice = (z - 1) * LADO + x
			local casa = Instance.new("TextButton")
			casa.Name, casa.LayoutOrder = "Casa_" .. x .. "_" .. z, indice
			casa.BackgroundColor3, casa.BorderSizePixel = cores.painel, 0
			casa.Text, casa.TextColor3 = "", cores.texto
			casa.TextSize, casa.FontFace, casa.ZIndex = Tema.tamanhos.rotulo, Tema.fontes.rotulo, 24
			casa.AutoButtonColor, casa.Active, casa.Selectable = false, false, false
			casa.Parent, casas[indice] = grade, casa
			local casaCanto = Instance.new("UICorner"); casaCanto.CornerRadius, casaCanto.Parent = UDim.new(0, Tema.raios.botao), casa
			local casaBorda = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)(); casaBorda.Color, casaBorda.Thickness, casaBorda.Parent = cores.borda, Tema.espessuras.borda, casa
			casa.Activated:Connect(function()
				local habilidade = state.habilidadeEmMira and state.habilidadeEmMira()
				if habilidade then
					if habilidade == MURO or habilidade == MURO_TERRA or habilidade == ANTEPARO
						or habilidade == ESCUDO_AGUA or habilidade == SOPRO_DE_POEIRA then
						local candidato = candidatosMuro[indice]
						if candidato then
							muroSelecionado = candidato
							confirmarMuro.Text = if habilidade == SOPRO_DE_POEIRA then "Confirmar cone" else "Confirmar"
							atualizar(estadoAtual)
						end
						return
					end
					if habilidade == PASSO_DE_VENTO then
						local controlado
						for _, ator in ipairs(estadoAtual.actors or {}) do
							if ator.id == estadoAtual.controlledActorId then controlado = ator; break end
						end
						if HabilidadesAutonomas.preverPassoDeVento(controlado, x, z, estadoAtual.actors,
							estadoAtual.blockedCells) and state.usarHabilidade(habilidade, "passo-vento:" .. x .. ":" .. z) then
							for _, botao in casas do botao.Active = false end
						end
						return
					end
					if habilidade == CLARAO then
						local controlado
						for _, ator in ipairs(estadoAtual.actors or {}) do
							if ator.id == estadoAtual.controlledActorId then controlado = ator; break end
						end
						local previsao = HabilidadesAutonomas.preverClarao(controlado,
							x, z, estadoAtual.blockedCells, estadoAtual.dangers, estadoAtual.turn)
						if previsao and state.usarHabilidade(habilidade, previsao.targetId) then
							for _, botao in casas do botao.Active = false end
						end
						return
					end
					if state.usarHabilidade(habilidade, "casa:" .. x .. ":" .. z) then
						for _, botao in casas do botao.Active = false end
					end
					return
				end
				local destino = destinosAtuais[indice]
				if destino and MapaTatico.solicitarMovimento(state, estadoAtual, destino.x, destino.z) then
					table.clear(destinosAtuais)
					for _, botao in casas do botao.Active = false end
				end
			end)
		end
	end

	atualizar = function(estado)
		estadoAtual = estado
		local ativo = estado ~= nil and estado.phase == "active"
		abrirMapa.Visible = ativo
		if not ativo then painel.Visible = false; return end
		local celula = math.max(Tema.toqueMinimo, 48)
		local extensao = celula * LADO + LADO - 1
		layout.CellSize, grade.Size = UDim2.fromOffset(celula, celula), UDim2.fromOffset(extensao, extensao)
		local habilidadeMuro = state.habilidadeEmMira and state.habilidadeEmMira()
		if habilidadeMuro and habilidadeMuro ~= ultimaMira then
			painel.Visible = true
			task.defer(centralizarMapa)
		elseif ultimaMira and not habilidadeMuro then
			painel.Visible = false
		end
		ultimaMira = habilidadeMuro
		local mirandoMuro = habilidadeMuro == MURO or habilidadeMuro == MURO_TERRA or habilidadeMuro == ANTEPARO
			or habilidadeMuro == ESCUDO_AGUA or habilidadeMuro == SOPRO_DE_POEIRA
		areaGrade.Size = UDim2.new(1, -24, 1, if mirandoMuro then -140 else -90)
		cartao.Size = UDim2.new(1, -16, 1, -16)
		confirmarMuro.Visible = mirandoMuro and muroSelecionado ~= nil
		cancelarMuro.Visible = mirandoMuro
		titulo.Text = string.format("TURNO %s · %s", tostring(estado.turn or "?"), estado.currentActorName or "Combate")
		for _, casa in casas do
			casa.BackgroundColor3, casa.Text = cores.painel, ""
			casa.Active, casa.Selectable, casa.AutoButtonColor = false, false, false
		end
		for _, celula in estado.blockedCells or {} do
			if type(celula) == "table" and type(celula.x) == "number" and type(celula.z) == "number"
				and celula.x % 1 == 0 and celula.z % 1 == 0
				and celula.x >= 1 and celula.x <= LADO and celula.z >= 1 and celula.z <= LADO
			then
				local casa = casas[(celula.z - 1) * LADO + celula.x]
				casa.BackgroundColor3, casa.Text = cores.secundario, "■"
			end
		end
		for _, celula in estado.difficultCells or {} do
			if type(celula) == "table" and type(celula.x) == "number" and type(celula.z) == "number"
				and celula.x % 1 == 0 and celula.z % 1 == 0
				and celula.x >= 1 and celula.x <= LADO and celula.z >= 1 and celula.z <= LADO
			then
				local casa = casas[(celula.z - 1) * LADO + celula.x]
				casa.BackgroundColor3, casa.Text = cores.alerta, "~"
			end
		end
		for _, zona in estado.dangers or {} do
			if type(zona.x) == "number" and type(zona.z) == "number"
				and zona.x >= 1 and zona.x <= LADO and zona.z >= 1 and zona.z <= LADO
			then
				local casa = casas[(zona.z - 1) * LADO + zona.x]
				casa.Text = if zona.abilityId == MURO_TERRA then "■" elseif zona.abilityId == ANTEPARO then "▥"
					elseif zona.abilityId == ESCUDO_AGUA then "~" elseif zona.abilityId == NEVOA_DENSA then "N" else "F"
				casa.BackgroundColor3 = if zona.abilityId == MURO_TERRA or zona.abilityId == ANTEPARO
					then cores.secundario elseif zona.abilityId == ESCUDO_AGUA
					then cores.info elseif zona.abilityId == NEVOA_DENSA
					then cores.secundario else cores.perigo
			end
		end
		table.clear(destinosAtuais)
		table.clear(candidatosMuro)
		local destinos = MapaTatico.destinos(estado)
		for _, ator in estado.actors or {} do
			if type(ator.x) ~= "number" or type(ator.z) ~= "number"
				or ator.x % 1 ~= 0 or ator.z % 1 ~= 0
				or ator.x < 1 or ator.x > LADO or ator.z < 1 or ator.z > LADO
				or (ator.kind == "criatura" and ator.defeated == true)
			then continue end
			local casa = casas[(ator.z - 1) * LADO + ator.x]
			casa.BackgroundColor3 = if ator.id == estado.controlledActorId then cores.ouro
				elseif ator.kind == "criatura" then cores.vinho
				else cores.info
			casa.Text = if ator.id == estado.controlledActorId then "EU" else string.sub(ator.name or "?", 1, 1)
			for _, zona in estado.dangers or {} do
				if zona.x == ator.x and zona.z == ator.z then
					casa.Text ..= if zona.abilityId == MURO_TERRA then "■" elseif zona.abilityId == ESCUDO_AGUA then "~"
						elseif zona.abilityId == NEVOA_DENSA then "N" else "F"
					break
				end
			end
		end
		if type(destinos) == "table" and estado.isMyTurn == true and (estado.actionsRemaining or 0) > 0 then
			for chave, destino in destinos do
				local x, z = string.match(chave, "^(%d+):(%d+)$")
				local indice = (tonumber(z) - 1) * LADO + tonumber(x)
				local casa = casas[indice]
				casa.BackgroundColor3 = cores.sucesso
				casa.Text = if destino.custoMovimento and destino.custoMovimento > destino.casas then "~" else "·"
				casa.Active, casa.Selectable, casa.AutoButtonColor = true, true, true
				destinosAtuais[indice] = destino
			end
		end
		local habilidadeEmMira = state.habilidadeEmMira and state.habilidadeEmMira()
		if habilidadeEmMira then
			local controlado
			for _, candidato in estado.actors or {} do
				if candidato.id == estado.controlledActorId then controlado = candidato; break end
			end
			if habilidadeEmMira == MURO or habilidadeEmMira == MURO_TERRA or habilidadeEmMira == ANTEPARO
				or habilidadeEmMira == ESCUDO_AGUA or habilidadeEmMira == SOPRO_DE_POEIRA then
				for indice, casa in casas do
					local x, z = (indice - 1) % LADO + 1, math.floor((indice - 1) / LADO) + 1
					local candidato = if not controlado then nil
						elseif habilidadeEmMira == SOPRO_DE_POEIRA then HabilidadesAutonomas.preverSoproDePoeira(
							controlado, x, z, estado.blockedCells, estado.dangers, estado.turn)
						elseif habilidadeEmMira == MURO_TERRA then HabilidadesAutonomas.preverMuroDeTerra(
							controlado, x, z, estado.blockedCells, estado.dangers, estado.turn)
						elseif habilidadeEmMira == ANTEPARO then HabilidadesAutonomas.preverAnteparo(
							controlado, x, z, estado.blockedCells, estado.dangers, estado.turn)
						elseif habilidadeEmMira == ESCUDO_AGUA then HabilidadesAutonomas.preverEscudoDeAgua(
							controlado, x, z, estado.blockedCells, estado.dangers, estado.turn)
						else HabilidadesAutonomas.preverMuro(controlado, x, z)
					if candidato then
						candidatosMuro[indice] = candidato
						casa.Active, casa.Selectable, casa.AutoButtonColor = true, true, true
						casa.BackgroundColor3 = cores.alerta
					end
				end
				if muroSelecionado then
					for _, celulaMuro in ipairs(muroSelecionado.cells) do
						local casa = casas[(celulaMuro.z - 1) * LADO + celulaMuro.x]
						casa.BackgroundColor3, casa.Text = cores.ouro,
							if habilidadeEmMira == SOPRO_DE_POEIRA then "✳" elseif habilidadeEmMira == MURO_TERRA then "■" elseif habilidadeEmMira == ANTEPARO then "▥"
							elseif habilidadeEmMira == ESCUDO_AGUA then "~" else "F"
					end
				end
				local nomeMuro = if habilidadeEmMira == SOPRO_DE_POEIRA then "SOPRO DE POEIRA"
					elseif habilidadeEmMira == MURO_TERRA then "MURO DE TERRA"
					elseif habilidadeEmMira == ANTEPARO then "ANTEPARO TEÓRICO"
					elseif habilidadeEmMira == ESCUDO_AGUA then "ESCUDO DE ÁGUA" else "MURO DE CHAMAS"
				titulo.Text = if muroSelecionado
					then string.format("%s · %d casas · confira e confirme", nomeMuro, #muroSelecionado.cells)
					else if habilidadeEmMira == SOPRO_DE_POEIRA then "SOPRO DE POEIRA · escolha a direção do cone"
					elseif habilidadeEmMira == MURO_TERRA then "MURO DE TERRA · escolha o centro até 6 casas"
					elseif habilidadeEmMira == ANTEPARO then "ANTEPARO · escolha o centro em uma casa vizinha"
					elseif habilidadeEmMira == ESCUDO_AGUA then "ESCUDO DE ÁGUA · centro até 4 casas · 2 rodadas"
					else "MURO DE CHAMAS · escolha a ponta (1–6 casas)"
			elseif habilidadeEmMira == CLARAO then
				for indice, casa in casas do
					local x, z = (indice - 1) % LADO + 1, math.floor((indice - 1) / LADO) + 1
					local previsao = if controlado and estado.isMyTurn == true and (estado.actionsRemaining or 0) > 0
						then HabilidadesAutonomas.preverClarao(controlado, x, z, estado.blockedCells, estado.dangers, estado.turn)
						else nil
					if previsao then
						casa.Active, casa.Selectable, casa.AutoButtonColor = true, true, true
						casa.BackgroundColor3, casa.Text = cores.info, "○"
					end
				end
				titulo.Text = "CLARÃO · escolha qualquer casa visível como centro"
			elseif habilidadeEmMira == PASSO_DE_VENTO then
				for indice, casa in casas do
					local x, z = (indice - 1) % LADO + 1, math.floor((indice - 1) / LADO) + 1
					local destino = if controlado then HabilidadesAutonomas.preverPassoDeVento(
						controlado, x, z, estado.actors, estado.blockedCells) else nil
					if destino then
						casa.Active, casa.Selectable, casa.AutoButtonColor = true, true, true
						casa.BackgroundColor3, casa.Text = cores.sucesso, "↗"
					end
				end
				titulo.Text = "PASSO DE VENTO · escolha destino até 12 casas · terreno difícil ignorado"
			else
				for indice, casa in casas do
					local x, z = (indice - 1) % LADO + 1, math.floor((indice - 1) / LADO) + 1
					local distancia = controlado and math.max(math.abs(controlado.x - x), math.abs(controlado.z - z)) or math.huge
					if distancia <= 6 and controlado and Terreno.visaoLivre(
						controlado.x, controlado.z, x, z, estado.blockedCells, estado.dangers, estado.turn) then
						casa.Active, casa.Selectable, casa.AutoButtonColor = true, true, true
						casa.BackgroundColor3 = cores.alerta
					end
				end
				titulo.Text = "FAGULHA · escolha uma casa até 6"
			end
		end
		for _, zona in estado.dangers or {} do
			if type(zona.x) == "number" and type(zona.z) == "number"
				and zona.x >= 1 and zona.x <= LADO and zona.z >= 1 and zona.z <= LADO
			then
				local casa = casas[(zona.z - 1) * LADO + zona.x]
				casa.BackgroundColor3 = if zona.abilityId == ESCUDO_AGUA then cores.info
					elseif zona.abilityId == NEVOA_DENSA then cores.secundario else cores.perigo
				local marcador = if zona.abilityId == MURO_TERRA then "■" elseif zona.abilityId == ANTEPARO then "▥"
					elseif zona.abilityId == ESCUDO_AGUA then "~" elseif zona.abilityId == NEVOA_DENSA then "N" else "F"
				if not string.find(casa.Text, marcador, 1, true) then casa.Text ..= marcador end
			end
		end
	end

	centralizarMapa = function()
		local ator
		for _, candidato in estadoAtual and estadoAtual.actors or {} do
			if candidato.id == estadoAtual.controlledActorId then ator = candidato; break end
		end
		if not ator or type(ator.x) ~= "number" or type(ator.z) ~= "number" then return end
		local celula = math.max(Tema.toqueMinimo, 48)
		local centroX = (ator.x - 1) * (celula + 1) + celula / 2
		local centroY = (ator.z - 1) * (celula + 1) + celula / 2
		areaGrade.CanvasPosition = Vector2.new(
			math.max(0, centroX - areaGrade.AbsoluteSize.X / 2),
			math.max(0, centroY - areaGrade.AbsoluteSize.Y / 2))
	end

	confirmarMuro.Activated:Connect(function()
		local habilidade = state.habilidadeEmMira and state.habilidadeEmMira()
		if not muroSelecionado or (habilidade ~= MURO and habilidade ~= MURO_TERRA and habilidade ~= ANTEPARO
			and habilidade ~= ESCUDO_AGUA and habilidade ~= SOPRO_DE_POEIRA) then return end
		if state.usarHabilidade(habilidade, muroSelecionado.targetId) then
			muroSelecionado = nil
			confirmarMuro.Active = false
		end
	end)
	cancelarMuro.Activated:Connect(function()
		muroSelecionado = nil
		local habilidade = state.habilidadeEmMira and state.habilidadeEmMira()
		if habilidade == MURO or habilidade == MURO_TERRA or habilidade == ANTEPARO
			or habilidade == ESCUDO_AGUA or habilidade == SOPRO_DE_POEIRA then state.iniciarMira(habilidade) end
		atualizar(state.estado())
	end)

	state.onEstado(atualizar)
	state.onRecibo(function(recibo)
		if type(recibo) ~= "table" or type(recibo.result) ~= "table" then return end
		local resultado = recibo.result
		local function piscar(x, z, cor)
			if type(x) ~= "number" or type(z) ~= "number" or x % 1 ~= 0 or z % 1 ~= 0
				or x < 1 or x > LADO or z < 1 or z > LADO then return end
			local casa = casas[(z - 1) * LADO + x]
			local borda = (function() local u = Instance.new("UIStroke"); u.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return u end)()
			borda.Color, borda.Thickness, borda.Transparency = cor, Tema.espessuras.destaque, .05
			borda.Parent = casa
			TweenService:Create(borda, TweenInfo.new(.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = 0, Transparency = 1,
			}):Play()
			task.delay(.45, function() if borda.Parent then borda:Destroy() end end)
		end
		if resultado.abilityId == "ability/fogo/Principiante/fagulha" and type(resultado.zone) == "table" then
			piscar(resultado.zone.x, resultado.zone.z, cores.alerta)
		elseif (resultado.abilityId == MURO or resultado.abilityId == MURO_TERRA or resultado.abilityId == ANTEPARO or resultado.abilityId == ESCUDO_AGUA)
			and type(resultado.zone) == "table"
		then
			for _, casa in ipairs(resultado.zone.cells or {}) do
				piscar(casa.x, casa.z, if resultado.abilityId == MURO_TERRA then cores.alerta
					elseif resultado.abilityId == ANTEPARO then cores.info
					elseif resultado.abilityId == ESCUDO_AGUA then cores.info
					else cores.alerta)
			end
		elseif recibo.action == "move" and type(resultado.toX) == "number" and type(resultado.toZ) == "number" then
			piscar(resultado.fromX, resultado.fromZ, cores.secundario)
			piscar(resultado.toX, resultado.toZ, cores.ouro)
		elseif resultado.abilityId == HabilidadesAutonomas.ATOLEIRO and type(resultado.zone) == "table" then
			for _, celula in ipairs(resultado.zone.cells or {}) do
				piscar(celula.x, celula.z, cores.alerta)
			end
		elseif recibo.action == "creature-move" and type(resultado.to) == "table" then
			local origem = resultado.from
			if type(origem) == "table" then piscar(origem.x, origem.z, cores.secundario) end
			piscar(resultado.to.x, resultado.to.z, cores.ouro)
		else
			if type(resultado.attack) == "table" and resultado.attack.acertou ~= true then return end
			if type(resultado.healing) ~= "number" and type(resultado.damageDealt) ~= "number" then return end
			local alvoId = resultado.targetId or recibo.targetId
			for _, ator in estadoAtual and estadoAtual.actors or {} do
				if ator.id == alvoId then
					local cor = if type(resultado.healing) == "number" and resultado.healing > 0
						then cores.sucesso
						elseif type(resultado.damageDealt) == "number" and resultado.damageDealt > 0
						then cores.perigo
						else cores.alerta
					piscar(ator.x, ator.z, cor)
					break
				end
			end
		end
	end)
	return { atualizar = atualizar }
end

return MapaTaticoView
