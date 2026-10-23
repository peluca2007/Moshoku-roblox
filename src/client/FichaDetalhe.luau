-- Consulta da ficha v2. Não envia comandos nem decide aquisição ou regras.
-- FichaDetalhe.secoes(ficha2, Catalogo) é pura: não acessa serviços/Instances.
-- FichaDetalhe.montar requer um pai com altura definida, como a área da aba Ficha.
-- O texto do livro vem exclusivamente de Catalogo.POR_ID.
-- Inventário e nome da ficha são declarações já filtradas pelo servidor.

local FichaDetalhe = {}

local function tabela(valor)
	return if type(valor) == "table" then valor else {}
end

local function texto(valor, padrao)
	if type(valor) == "string" then return valor end
	if type(valor) == "number" then return tostring(valor) end
	return padrao or "—"
end

local function numero(valor)
	return type(valor) == "number"
		and valor == valor
		and math.abs(valor) < math.huge
end

local function sinal(valor)
	if not numero(valor) then return "—" end
	return (if valor >= 0 then "+" else "") .. tostring(valor)
end

local function segmento(valor)
	local resultado = {}
	local origem = texto(valor, "")
	for index = 1, #origem do
		local byte = string.byte(origem, index)
		local livre = (byte >= 65 and byte <= 90)
			or (byte >= 97 and byte <= 122)
			or (byte >= 48 and byte <= 57)
			or byte == 45 or byte == 46 or byte == 95 or byte == 126
		table.insert(resultado, if livre then string.char(byte) else string.format("%%%02X", byte))
	end
	return table.concat(resultado)
end

local function entrada(catalogo, id, especie)
	if type(id) ~= "string" then return nil end
	local item = tabela(tabela(catalogo).POR_ID)[id]
	if type(item) ~= "table" then return nil end
	if especie and item.kind ~= especie then return nil end
	return item
end

local function nomeDoCatalogo(catalogo, id, especie)
	local item = entrada(catalogo, id, especie)
	if not item then
		return texto(id, "ID ausente") .. " [fora do catálogo]"
	end
	local dados = tabela(item.data)
	return texto(dados.name or dados.nome, texto(item.sourceId, id))
end

local function nomeDaArvore(catalogo, idLocal)
	if type(idLocal) ~= "string" then return "Árvore não informada" end
	return nomeDoCatalogo(catalogo, "tree/" .. segmento(idLocal), "tree")
end

local function adicionarTexto(destino, rotulo, valor)
	if type(valor) == "string" and valor ~= "" then
		table.insert(destino, rotulo .. valor)
	elseif type(valor) == "number" then
		table.insert(destino, rotulo .. tostring(valor))
	end
end

local function modalidades(valor)
	local dados = tabela(valor)
	local partes = {}
	for _, modo in { "normal", "encurtada", "silenciosa" } do
		if dados[modo] ~= nil then
			table.insert(partes, modo .. ": " .. texto(dados[modo]))
		end
	end
	return if #partes > 0 then table.concat(partes, " • ") else "não informadas"
end

local function custos(dados)
	local partes = {}
	for _, campo in {
		{ "paCost", "PA de aprimoramento" },
		{ "pmCost", "PM" },
		{ "ptCost", "PT" },
		{ "ppCost", "PP" },
	} do
		if dados[campo[1]] ~= nil then
			table.insert(partes, campo[2] .. ": " .. texto(dados[campo[1]]))
		end
	end
	return if #partes > 0 then table.concat(partes, " • ") else "Custos não informados"
end

local function descricaoDePoder(dados, especie)
	local partes = {}
	if especie ~= "mastery" then table.insert(partes, custos(dados)) end

	if dados.actions ~= nil then
		table.insert(partes, "Ações — " .. modalidades(dados.actions))
	end
	if dados.reaction == true then table.insert(partes, "Reação") end
	adicionarTexto(partes, "Alcance: ", dados.range)

	local dano = tabela(dados.damage)
	for _, campo in {
		{ "normal", "Dano: " },
		{ "encurtada", "Dano encurtado: " },
		{ "condicional", "Dano condicional: " },
		{ "porTurno", "Dano por turno: " },
	} do
		adicionarTexto(partes, campo[2], dano[campo[1]])
	end
	if type(dados.damage) == "string" then
		adicionarTexto(partes, "Dano: ", dados.damage)
	end

	local cura = tabela(dados.healing)
	adicionarTexto(partes, "Cura: ", cura.normal)
	adicionarTexto(partes, "", dados.effect)
	adicionarTexto(partes, "", dados.description)
	adicionarTexto(partes, "Nota de custo: ", dados.costNote)
	adicionarTexto(partes, "Pré-requisito: ", dados.prerequisiteNote)

	if dados.ritual == true then
		table.insert(partes, "Ritual")
		adicionarTexto(partes, "Tempo de ritual: ", dados.tempoDeRitual)
	end
	adicionarTexto(partes, "Encantamento:\n", dados.incantation)
	return if #partes > 0 then table.concat(partes, "\n") else "Sem descrição no catálogo."
end

local function criarSecao(destino, chave, titulo)
	local secao = { key = chave, title = titulo, lines = {} }
	table.insert(destino, secao)
	return secao
end

local function linha(secao, titulo, corpo, tom)
	table.insert(secao.lines, {
		key = secao.key .. "/" .. tostring(#secao.lines + 1),
		title = titulo,
		text = corpo or "",
		tone = tom or "normal",
	})
end

local function preencherVazio(secao, mensagem)
	if #secao.lines == 0 then linha(secao, mensagem, "", "muted") end
end

-- Árvore de apresentação: lista de seções, cada uma com linhas de texto.
-- Nenhum número desta função é uma autorização ou resultado de combate.
function FichaDetalhe.secoes(ficha2, Catalogo)
	local ficha = tabela(ficha2)
	local construcao = tabela(ficha.construction)
	local calculados = tabela(ficha.calculated)
	local sessao = tabela(ficha.session)
	local resultado = {}

	local cabecalho = criarSecao(resultado, "cabecalho", "Cabeçalho")
	linha(cabecalho, texto(ficha.name, "Ficha não disponível"), "")
	for _, campo in {
		{ "raceId", "Raça", "race" },
		{ "backgroundId", "Antecedente", "background" },
		{ "subtableEntryId", "Detalhe do antecedente", "subtable-entry" },
		{ "startingTreeId", "Árvore inicial", "tree" },
	} do
		local id = construcao[campo[1]]
		if id ~= nil then
			linha(cabecalho, campo[2], nomeDoCatalogo(Catalogo, id, campo[3]))
		end
	end
	for _, id in ipairs(tabela(construcao.unlockedRankIds)) do
		local item = entrada(Catalogo, id, "rank")
		if item then
			local dados = tabela(item.data)
			linha(cabecalho, "Rank",
				nomeDaArvore(Catalogo, dados.treeId) .. " • " .. texto(dados.rank))
		else
			linha(cabecalho, "Rank", nomeDoCatalogo(Catalogo, id, "rank"), "warning")
		end
	end
	for _, id in ipairs(tabela(construcao.racialUpgradeIds)) do
		local item = entrada(Catalogo, id, "race-upgrade")
		linha(cabecalho, nomeDoCatalogo(Catalogo, id, "race-upgrade"),
			if item then texto(tabela(item.data).description, "") else "",
			if item then "normal" else "warning")
	end

	local atributos = criarSecao(resultado, "atributos", "Atributos")
	local finais = tabela(calculados.attributes)
	local bases = tabela(construcao.attributeBase)
	for _, campo in {
		{ "forca", "Força" },
		{ "agilidade", "Agilidade" },
		{ "vigor", "Vigor" },
		{ "intelecto", "Intelecto" },
		{ "espirito", "Espírito" },
	} do
		local final = finais[campo[1]]
		local base = bases[campo[1]]
		local resumo = "Final: " .. sinal(final)
		if numero(base) then
			resumo ..= " • Base: " .. sinal(base)
			if numero(final) then
				-- Diferença dos valores fornecidos, sem inferir a origem das regras.
				resumo ..= " • Ajustes totais: " .. sinal(final - base)
			end
		end
		linha(atributos, campo[2], resumo)
	end

	local defesa = criarSecao(resultado, "defesa", "Defesa e recursos")
	local iniciativa = tabela(calculados.initiative)
	linha(defesa, "Defesa",
		"CA " .. texto(calculados.armorClass)
		.. " • Iniciativa " .. sinal(iniciativa.bonus)
		.. (if iniciativa.advantage == true then " • vantagem" else "")
		.. "\nDeslocamento: " .. texto(calculados.movementMeters) .. " m")
	local maximos = tabela(calculados.maxima)
	local atuais = tabela(sessao.current)
	for _, recurso in { { "pv", "PV" }, { "pm", "PM" }, { "pt", "PT" }, { "pp", "PP" } } do
		linha(defesa, recurso[2],
			texto(atuais[recurso[1]]) .. " / " .. texto(maximos[recurso[1]])
			.. " • atual / máximo")
	end
	linha(defesa, "Aprimoramento",
		"PA gastos: " .. texto(calculados.paSpent)
		.. "\nPA de aprimoramento não são ações do turno.", "muted")
	for _, condicao in ipairs(tabela(sessao.conditions)) do
		local item = tabela(condicao)
		local resumo = "Acúmulos: " .. texto(item.stacks)
		if item.note ~= nil then resumo ..= "\nNota: " .. texto(item.note, "") end
		linha(defesa, nomeDoCatalogo(Catalogo, item.conditionId, "condition"), resumo)
	end

	local pericias = criarSecao(resultado, "pericias", "Perícias")
	for _, registro in ipairs(tabela(calculados.skills)) do
		local item = tabela(registro)
		linha(pericias, nomeDoCatalogo(Catalogo, item.skillId, "skill"),
			"Bônus " .. sinal(item.bonus)
			.. (if item.trained == true then " • treinada" else " • não treinada"))
	end
	for _, declaracao in ipairs(tabela(construcao.proficiencyTexts)) do
		linha(pericias, "Proficiência declarada", texto(declaracao), "muted")
	end
	preencherVazio(pericias, "Nenhuma perícia informada.")

	local poderes = criarSecao(resultado, "poderes", "Habilidades e Talentos")
	local comprados = {}
	for _, id in ipairs(tabela(construcao.purchasedIds)) do
		if type(id) == "string" then comprados[id] = true end
	end

	local grupos, porGrupo, poderesVistos = {}, {}, {}
	local function incluirPoder(id)
		if type(id) ~= "string" or poderesVistos[id] then return end
		poderesVistos[id] = true
		local item = entrada(Catalogo, id)
		if not item or (item.kind ~= "ability" and item.kind ~= "talent") then
			local chave = "fora-do-catalogo"
			if not porGrupo[chave] then
				porGrupo[chave] = { title = "Referências não resolvidas", ids = {} }
				table.insert(grupos, porGrupo[chave])
			end
			table.insert(porGrupo[chave].ids, id)
			return
		end
		local dados = tabela(item.data)
		local chave = texto(dados.treeId, "") .. "/" .. texto(dados.rank, "")
		if not porGrupo[chave] then
			porGrupo[chave] = {
				title = nomeDaArvore(Catalogo, dados.treeId) .. " • " .. texto(dados.rank),
				ids = {},
			}
			table.insert(grupos, porGrupo[chave])
		end
		table.insert(porGrupo[chave].ids, id)
	end

	-- Os ranks oferecem consulta ao livro. Não presumir que toda referência
	-- é comprada, nem que uma habilidade gratuita precisa de compra registrada.
	for _, id in ipairs(tabela(construcao.unlockedRankIds)) do
		local item = entrada(Catalogo, id, "rank")
		if item then
			local dados = tabela(item.data)
			for _, poder in ipairs(tabela(dados.abilities)) do incluirPoder(poder) end
			for _, poder in ipairs(tabela(dados.talents)) do incluirPoder(poder) end
		end
	end
	for _, id in ipairs(tabela(construcao.purchasedIds)) do incluirPoder(id) end

	for _, grupo in ipairs(grupos) do
		linha(poderes, grupo.title, "", "heading")
		for _, id in ipairs(grupo.ids) do
			local item = entrada(Catalogo, id)
			if item and (item.kind == "ability" or item.kind == "talent") then
				local dados = tabela(item.data)
				local estado = if comprados[id]
					then "Compra registrada na construção."
					else "Referência do rank; compra não registrada. Aquisição não inferida."
				local especie = if item.kind == "talent" then "Talento" else "Habilidade"
				linha(poderes, especie .. " • " .. nomeDoCatalogo(Catalogo, id),
					estado .. "\n" .. descricaoDePoder(dados, item.kind))
			else
				linha(poderes, nomeDoCatalogo(Catalogo, id),
					"Não foi possível consultar esta referência.", "warning")
			end
		end
	end
	preencherVazio(poderes, "Nenhuma habilidade ou talento informado.")

	local maestrias = criarSecao(resultado, "maestrias", "Maestrias")
	local maestriasVistas = {}
	for _, rankId in ipairs(tabela(construcao.unlockedRankIds)) do
		local rank = entrada(Catalogo, rankId, "rank")
		if rank then
			local id = tabela(rank.data).mastery
			if type(id) == "string" and not maestriasVistas[id] then
				maestriasVistas[id] = true
				local item = entrada(Catalogo, id, "mastery")
				local dados = if item then tabela(item.data) else {}
				local origem = if item
					then nomeDaArvore(Catalogo, dados.treeId) .. " • " .. texto(dados.rank) .. "\n"
					else ""
				linha(maestrias, nomeDoCatalogo(Catalogo, id, "mastery"),
					origem .. (if item then descricaoDePoder(dados, "mastery") else ""),
					if item then "normal" else "warning")
			end
		end
	end
	preencherVazio(maestrias, "Nenhuma maestria referenciada pelos ranks.")

	local combinadas = criarSecao(resultado, "combinadas", "Magias combinadas")
	for _, id in ipairs(tabela(construcao.combinedSpellIds)) do
		local item = entrada(Catalogo, id, "combined-spell")
		linha(combinadas, nomeDoCatalogo(Catalogo, id, "combined-spell"),
			if item then descricaoDePoder(tabela(item.data), "combined-spell") else "",
			if item then "normal" else "warning")
	end
	preencherVazio(combinadas, "Nenhuma magia combinada informada.")

	local inventario = criarSecao(resultado, "inventario", "Inventário")
	linha(inventario, "Inventário declarado",
		"Textos e modificações fornecidos pelo jogador; não comprovam aquisição.", "muted")
	for _, registro in ipairs(tabela(construcao.inventory)) do
		local item = tabela(registro)
		local partes = {
			"Tipo: " .. texto(item.type),
			if item.equipped == true then "Equipado" else "Não equipado",
		}
		adicionarTexto(partes, "Dado base: ", item.baseDie)
		adicionarTexto(partes, "Atributo de dano: ", item.damageAttribute)
		adicionarTexto(partes, "Bônus de CA: ", item.armorClassBonus)
		adicionarTexto(partes, "Tratamentos usados: ", item.treatmentsUsed)
		adicionarTexto(partes, "", item.description)
		linha(inventario, texto(item.name, "Item sem nome") .. " • declarado",
			table.concat(partes, "\n"))
	end
	if #tabela(construcao.inventory) == 0 then
		linha(inventario, "Nenhum item informado.", "", "muted")
	end

	return resultado
end

local function modelosIguais(primeiro, segundo)
	if not primeiro or #primeiro ~= #segundo then return false end
	for index, secao in ipairs(segundo) do
		local anterior = primeiro[index]
		if anterior.key ~= secao.key or anterior.title ~= secao.title
			or #anterior.lines ~= #secao.lines then return false end
		for linhaIndex, item in ipairs(secao.lines) do
			local outro = anterior.lines[linhaIndex]
			if outro.key ~= item.key or outro.title ~= item.title
				or outro.text ~= item.text or outro.tone ~= item.tone then
				return false
			end
		end
	end
	return true
end

function FichaDetalhe.montar(pai: GuiObject, ficha2, Catalogo)
	local TweenService = game:GetService("TweenService")
	-- Estética Livro Noite (Estilo). Exigido só aqui: secoes continua pura.
	local Estilo = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Estilo"))
	local cores = {
		background = Estilo.PAPEL,
		card = Estilo.PAPEL_2,
		text = Estilo.TINTA,
		muted = Estilo.TINTA_SUAVE,
		border = Estilo.FIO_COR,
		gold = Estilo.DESTAQUE,
	}
	local fonteTexto = Estilo.ROTULO
	local fonteTitulo = Estilo.GRITO
	local ordem = 0
	local vivo = true
	local modeloAtual = nil
	local frames = {}
	local abertas = {
		cabecalho = true, atributos = true, defesa = true,
		pericias = false, poderes = false, maestrias = false,
		combinadas = false, inventario = false,
	}

	local function novo(classe, parent, propriedades)
		local objeto = Instance.new(classe)
		if objeto:IsA("GuiObject") then
			ordem += 1
			objeto.LayoutOrder = ordem
		end
		for chave, valor in propriedades do objeto[chave] = valor end
		objeto.Parent = parent
		return objeto
	end

	local function decorar(objeto, raio)
		novo("UICorner", objeto, { CornerRadius = UDim.new(0, raio) })
		novo("UIStroke", objeto, {
			Color = cores.border, Thickness = 1, Transparency = 0.55,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end

	local function pilha(parent, espaco)
		return novo("UIListLayout", parent, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, espaco),
		})
	end

	local function padding(parent, espaco)
		novo("UIPadding", parent, {
			PaddingTop = UDim.new(0, espaco),
			PaddingBottom = UDim.new(0, espaco),
			PaddingLeft = UDim.new(0, espaco),
			PaddingRight = UDim.new(0, espaco),
		})
	end

	local rolagem = novo("ScrollingFrame", pai, {
		Name = "FichaDetalhe",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = cores.gold,
		Active = true,
	})
	padding(rolagem, 8)
	pilha(rolagem, 8)

	local function rotulo(parent, conteudo, titulo, cor)
		return novo("TextLabel", parent, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = conteudo,
			TextWrapped = true, RichText = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			FontFace = if titulo then fonteTitulo else fonteTexto,
			TextSize = if titulo then 20 else 16,
			TextColor3 = cor,
		})
	end

	local function renderizar(modelo)
		local posicaoAnterior = rolagem.CanvasPosition
		for _, frame in ipairs(frames) do frame:Destroy() end
		frames = {}

		for _, secao in ipairs(modelo) do
			local chave = secao.key
			local frame = novo("Frame", rolagem, {
				Name = "FichaSecao_" .. chave,
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = cores.card,
				BorderSizePixel = 0,
			})
			table.insert(frames, frame)
			decorar(frame, 8)
			padding(frame, 8)
			pilha(frame, 6)

			local aberta = abertas[chave] == true
			local botao = novo("TextButton", frame, {
				Name = "FichaAbrir_" .. chave,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = cores.background,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = (if aberta then "▾ " else "▸ ") .. secao.title,
				TextWrapped = true, RichText = false,
				TextSize = 20, FontFace = fonteTitulo,
				TextColor3 = cores.text,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			padding(botao, 8)
			decorar(botao, 6)

			local corpo = novo("Frame", frame, {
				Name = "FichaCorpo_" .. chave,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = aberta,
			})
			pilha(corpo, 8)

			for _, item in ipairs(secao.lines) do
				local card = novo("Frame", corpo, {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
				})
				pilha(card, 3)
				local corTitulo = if item.tone == "heading" then cores.gold
					elseif item.tone == "muted" then cores.muted
					else cores.text
				rotulo(card, item.title, item.tone == "heading", corTitulo)
				if item.text ~= "" then
					rotulo(card, item.text, false,
						if item.tone == "muted" then cores.muted else cores.text)
				end
			end

			botao.Activated:Connect(function()
				if not vivo then return end
				abertas[chave] = not abertas[chave]
				corpo.Visible = abertas[chave]
				botao.Text = (if abertas[chave] then "▾ " else "▸ ") .. secao.title
			end)

			local tween = nil
			local function realcar(ativo)
				if not vivo or not botao.Parent then return end
				if tween then tween:Cancel() end
				tween = TweenService:Create(botao,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundColor3 = if ativo
						then cores.background:Lerp(cores.gold, 0.1)
						else cores.background })
				tween:Play()
			end
			botao.MouseEnter:Connect(function() realcar(true) end)
			botao.MouseLeave:Connect(function() realcar(false) end)
		end

		-- Esperar o layout, sem bloquear atualização ou qualquer comando.
		task.defer(function()
			if not vivo or not rolagem.Parent then return end
			local limite = math.max(0, rolagem.AbsoluteCanvasSize.Y - rolagem.AbsoluteSize.Y)
			rolagem.CanvasPosition = Vector2.new(0, math.min(posicaoAnterior.Y, limite))
		end)
	end

	local function atualizar(proximaFicha)
		if not vivo then return end
		local modelo = FichaDetalhe.secoes(proximaFicha, Catalogo)
		if modelosIguais(modeloAtual, modelo) then return end
		modeloAtual = modelo
		renderizar(modelo)
	end

	local function destruir()
		if not vivo then return end
		vivo = false
		rolagem:Destroy()
		frames = {}
		modeloAtual = nil
	end

	atualizar(ficha2)
	return {
		atualizar = atualizar,
		destruir = destruir,
	}
end

return FichaDetalhe
