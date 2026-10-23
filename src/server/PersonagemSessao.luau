-- Perfil pessoal ativo em memória, isolado de campanha, tokens e slots.
-- API Mesa: personagemPessoalConsultar {} e personagemPessoalCriar <construção
-- bruta de CriacaoPersonagem>. Resposta privada: personagemPessoal <perfil|nil>.
-- personagemPessoalEquiparArma {sourceLocalId, requestId}: seleção privada de
-- uma arma já pertencente ao kit; grava antes de atualizar a folha em memória.
-- Erros retornam mensagem segura ao dispatcher (log privado); preservam a folha.
-- A identidade vem exclusivamente de player.UserId. Não há consulta por ownerId.
local PersonagemSessao = {}
local Aparencia = require(game:GetService("ReplicatedStorage").Shared.Aparencia.Aparencia)
local BeneficiosConta = require(game:GetService("ReplicatedStorage").Shared.Regras.RunBeneficiosConta)
local RunSessao = require(game:GetService("ReplicatedStorage").Shared.Regras.RunSessao)
local ContaServico = require(script.Parent.ContaServico)
local Progressao = require(game:GetService("ReplicatedStorage").Shared.Regras.Progressao)
local DescansoAcampamento = require(game:GetService("ReplicatedStorage").Shared.Regras.DescansoAcampamento)
local Dojo = require(game:GetService("ReplicatedStorage").Shared.Regras.Dojo)
local Missao = require(game:GetService("ReplicatedStorage").Shared.Regras.Missao)
local MissoesDados = require(game:GetService("ReplicatedStorage").Shared.Mundo.MissoesDados)
local Loja = require(game:GetService("ReplicatedStorage").Shared.Regras.Loja)
local Itens = require(game:GetService("ReplicatedStorage").Shared.Livro.Dados.Itens)
local RegrasLivro = require(game:GetService("ReplicatedStorage").Shared.Livro.Regras)
local RestricaoDeCriacao = require(game:GetService("ReplicatedStorage").Shared.Regras.RestricaoDeCriacao)
local ArvoresAprendidas = require(game:GetService("ReplicatedStorage").Shared.Regras.ArvoresAprendidas)
local INTERVALO_NOVA_CARGA = 5
local LIMITE_PEDIDOS_CRIACAO = 128
local ITENS_LOJA, ORDEM_ITENS_LOJA = {}, {}
for _, registro in ipairs(Itens) do ITENS_LOJA[registro.id] = registro.data; table.insert(ORDEM_ITENS_LOJA, registro.data) end

local function copiar(valor)
	if type(valor) ~= "table" then return valor end
	local copia = {}
	for chave, item in valor do copia[chave] = copiar(item) end
	return copia
end

local function iguais(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for chave, valor in a do
		if b[chave] == nil and valor ~= nil then return false end
		if not iguais(valor, b[chave]) then return false end
	end
	for chave in b do
		if a[chave] == nil then return false end
	end
	return true
end

-- Limite de transporte, não regra do livro: impede percorrer propostas enormes,
-- ciclos e tipos sem significado antes do cálculo. A validação de domínio segue
-- exclusivamente em CriacaoPersonagem.calcular, com o catálogo do servidor.
local function propostaLimitada(proposta)
	local restantes = 96
	local function visitar(valor, nivel)
		restantes -= 1
		if restantes < 0 then return false end
		local tipo = type(valor)
		if tipo == "string" then return #valor <= 160 end
		if tipo == "number" then return valor == valor and math.abs(valor) < math.huge end
		if tipo ~= "table" or nivel > 1 or getmetatable(valor) ~= nil then return false end
		for chave, item in valor do
			if not visitar(chave, nivel + 1) or not visitar(item, nivel + 1) then return false end
		end
		return true
	end
	return type(proposta) == "table" and visitar(proposta, 0)
end

local function prepararNome(valor)
	if type(valor) ~= "string" or #valor > 128 then return nil end
	local nome = string.gsub(valor, "^%s*(.-)%s*$", "%1")
	local ok, comprimento = pcall(utf8.len, nome)
	if not ok or type(comprimento) ~= "number" or comprimento < 1 or comprimento > 32 or string.find(nome, "%c") then return nil end
	return nome
end

local function armaDoKit(perfil, sourceLocalId)
	if type(sourceLocalId) ~= "string" or #sourceLocalId == 0 or #sourceLocalId > 96 then return false end
	for _, item in perfil.inventarioInicial or {} do
		if item.sourceLocalId == sourceLocalId and item.type == "arma" then return true end
	end
	return false
end

-- Dependências injetadas: handlers, remote, calcular, catalogo, emCombate,
-- conectado; persistencia é opcional nos specs puros; relogio controla throttle.
-- Criar/recalcular é permitido somente antes do combate, inclusive substituição.
function PersonagemSessao.start(ctx)
	local folhas, tentativas, progressaoTentativas, ultimasCompras = {}, {}, {}, {}
	local carregamentos, revisoes, errosCarga = {}, {}, {}
	local cargasRecuperaveis, ultimaTentativaCarga = {}, {}
	local pedidosArma, tentativasArma, gravandoArma = {}, {}, {}
	local pedidosCriacao = {}
	local observadoresPerfil = {}
	local salvamentos = {}
	local agora = ctx.relogio or os.clock

	local function construcaoPersistivel(construcao)
		local resultado = {}
		local campos = {
			raceId = "raceId", backgroundId = "backgroundId", subtableEntryId = "subtableEntryId",
			attributeBase = "attributeBase", raceAttributeChoices = "raceAttributeChoices",
			freeSkillChoiceIds = "skillIds", startingTreeId = "startingTreeId",
			treeSkillChoiceIds = "treeSkillChoiceIds",
		}
		for destino, origem in campos do
			if construcao[origem] ~= nil then resultado[destino] = copiar(construcao[origem]) end
		end
		return resultado
	end
	local function salvar(player, perfil)
		if not ctx.persistencia then return true end
		if salvamentos[player.UserId] then return false, "Aguarde o salvamento atual." end
		local registro = {
			nome = perfil.nome,
			construcao = construcaoPersistivel(perfil.construcao),
			habilidadesCompradas = copiar(perfil.habilidadesCompradas or {}),
			arvoresAprendidas = copiar(perfil.arvoresAprendidas or {}), paGanhos = perfil.paGanhos or 0,
			armaInicialSourceLocalId = perfil.armaInicialSourceLocalId,
			descanso = copiar(perfil.descanso),
			dojo = copiar(perfil.dojo or Dojo.novoEstado()),
			ouro = perfil.ouro or 0,
			encontrosPagos = copiar(perfil.encontrosPagos or {}),
			inventarioLoja = copiar(perfil.inventarioLoja or {}),
			itensVendidos = copiar(perfil.itensVendidos or {}),
			missoes = copiar(perfil.missoes or Missao.novoEstado()),
			aparencia = copiar(perfil.aparencia),
		}
		salvamentos[player.UserId] = true
		local ok, resultado, revisaoOuErro = pcall(ctx.persistencia.save, ctx.persistencia, player.UserId, registro, revisoes[player.UserId] or 0)
		salvamentos[player.UserId] = nil
		if not ok then return false, "Não foi possível salvar a ficha. Tente novamente." end
		if resultado ~= "ok" then
			if resultado == "conflito" then return false, "Esta ficha mudou em outra sessão. Saia e entre novamente antes de alterar." end
			return false, if resultado == "invalido" then "A ficha salva está inválida; a alteração foi bloqueada." else "Não foi possível salvar a ficha. Tente novamente."
		end
		return true, revisaoOuErro
	end

	local function construirPersistida(registro)
		if type(registro) ~= "table" or type(registro.nome) ~= "string" or type(registro.construcao) ~= "table"
			or type(registro.habilidadesCompradas) ~= "table" then return nil, "Registro pessoal inválido; carregamento bloqueado." end
		local nome = prepararNome(registro.nome)
		if not nome then return nil, "Nome salvo inválido; carregamento bloqueado." end
		local ok, perfil, erro = pcall(ctx.calcular, registro.construcao, ctx.catalogo)
		if not ok or not perfil then return nil, "Construção salva inválida; carregamento bloqueado." end
		perfil = ArvoresAprendidas.aplicar(perfil, registro.arvoresAprendidas or {}, ctx.catalogo)
		if not perfil then return nil, "Árvores salvas inválidas." end
		perfil.paGanhos = registro.paGanhos or 0
		local compradas, construcao = {}, table.clone(perfil.construcao)
		construcao.unlockedRankIds = table.clone(perfil.construcao.unlockedRankIds or {})
		for _, habilidadeId in registro.habilidadesCompradas do
			if type(habilidadeId) ~= "string" or #habilidadeId > 256 then return nil, "Progressão salva inválida; carregamento bloqueado." end
			construcao.purchasedIds = compradas
			local permitido = Progressao.podeComprar(construcao, ctx.catalogo, habilidadeId)
			if not permitido then return nil, "Progressão salva incompatível; carregamento bloqueado." end
			table.insert(compradas, habilidadeId)
		end
		perfil.nome, perfil.habilidadesCompradas = nome, compradas
		if registro.armaInicialSourceLocalId ~= nil then
			if not armaDoKit(perfil, registro.armaInicialSourceLocalId) then
				return nil, "Arma salva incompatível com o kit; carregamento bloqueado."
			end
			perfil.armaInicialSourceLocalId = registro.armaInicialSourceLocalId
		end
		perfil.aparencia = copiar(registro.aparencia) or Aparencia.padrao(perfil.construcao.raceId, 1)
		perfil.descanso = copiar(registro.descanso)
		perfil.dojo = if registro.dojo == nil then Dojo.novoEstado() else copiar(registro.dojo)
		perfil.ouro = registro.ouro or 0
		perfil.encontrosPagos = copiar(registro.encontrosPagos or {})
		perfil.inventarioLoja = copiar(registro.inventarioLoja or {})
		perfil.itensVendidos = copiar(registro.itensVendidos or {})
		perfil.missoes = copiar(registro.missoes or Missao.novoEstado())
		if not Missao.estadoValido(perfil.missoes, MissoesDados.porId()) then return nil, "Missões salvas inválidas; carregamento bloqueado." end
		local vendidos, ids = {}, {}
		for _, id in ipairs(perfil.itensVendidos) do vendidos[id] = true end
		for _, item in ipairs(perfil.inventarioInicial) do ids[item.sourceLocalId] = true end
		for indice = #perfil.inventarioInicial, 1, -1 do
			if vendidos[perfil.inventarioInicial[indice].sourceLocalId] then table.remove(perfil.inventarioInicial, indice) end
		end
		for _, comprado in ipairs(perfil.inventarioLoja) do
			local item = ITENS_LOJA[comprado.itemId]
			if not item or type(comprado.sourceLocalId) ~= "string" or ids[comprado.sourceLocalId] then
				return nil, "Inventário salvo incompatível; carregamento bloqueado."
			end
			ids[comprado.sourceLocalId] = true
			if not vendidos[comprado.sourceLocalId] then
			table.insert(perfil.inventarioInicial, { sourceLocalId = comprado.sourceLocalId, name = item.name,
				type = item.type, equipped = false, description = item.description, baseDie = item.baseDie,
				damageAttribute = item.damageAttribute, armorClassBonus = item.acBonus })
			end
		end
		return perfil
	end

	local function enviarPerfil(player, tipo)
		ctx.remote:FireClient(player, "personagemPessoal", copiar(folhas[player.UserId]))
		for _, fn in observadoresPerfil do fn(player, copiar(folhas[player.UserId]), tipo) end
	end

	local function perfilDisponivel(player)
		local estado = carregamentos[player.UserId]
		if estado == "carregando" or (ctx.persistencia and estado == nil) then
			return false, "Sua ficha ainda está carregando. Tente novamente."
		end
		if estado == "erro" then return false, errosCarga[player.UserId] or "Não foi possível carregar sua ficha." end
		return true
	end

	local function carregar(player)
		local id = player.UserId
		carregamentos[id] = "carregando"
		errosCarga[id], cargasRecuperaveis[id] = nil, nil
		if not ctx.persistencia then carregamentos[id] = "pronto"; return true end
		local ok, registro, revisao, erro = pcall(ctx.persistencia.load, ctx.persistencia, id)
		if not ctx.conectado(player) then
			folhas[id], carregamentos[id], revisoes[id], errosCarga[id], cargasRecuperaveis[id] = nil, nil, nil, nil, nil
			return false, "Jogador fora da sessão."
		end
		if not ok or erro then
			carregamentos[id] = "erro"
			errosCarga[id] = "Não foi possível carregar sua ficha agora. Tente novamente."
			cargasRecuperaveis[id] = true
			return false, errosCarga[id]
		end
		if registro then
			local perfil, motivo = construirPersistida(registro)
			if not perfil then
				carregamentos[id], errosCarga[id] = "erro", motivo
				return false, motivo
			end
			folhas[id], revisoes[id] = perfil, revisao
		end
		carregamentos[id] = "pronto"
		if ctx.conectado(player) then enviarPerfil(player) end
		return true
	end

	ctx.handlers.personagemPessoalAprender = function(player, payload)
		if not ctx.conectado(player) then return "Jogador fora da sessão." end
		if gravandoArma[player.UserId] then return "Aguarde o salvamento da arma." end
		if type(payload) ~= "table" or type(payload.habilidadeId) ~= "string"
			or #payload.habilidadeId == 0 or #payload.habilidadeId > 256
			or type(payload.requestId) ~= "string" or #payload.requestId == 0 or #payload.requestId > 96
		then return "Pedido de progressão inválido." end
		for chave in payload do
			if chave ~= "habilidadeId" and chave ~= "requestId" then return "Pedido de progressão inválido." end
		end
		local id = player.UserId
		local disponivel, erroDisponivel = perfilDisponivel(player)
		if not disponivel then return erroDisponivel end
		local anterior = ultimasCompras[id]
		if anterior and anterior.requestId == payload.requestId then
			if anterior.habilidadeId ~= payload.habilidadeId then return "ID de pedido já usado com outra habilidade." end
			ctx.remote:FireClient(player, "personagemPessoal", copiar(folhas[id]))
			return nil
		end
		if ctx.emCombate() then return "Aprenda habilidades antes do combate." end
		local perfil = folhas[id]
		if not perfil then return "Crie um personagem antes de aprender habilidades." end
		local instante = agora()
		if progressaoTentativas[id] and instante - progressaoTentativas[id] < 0.5 then
			return "Aguarde antes de aprender outra habilidade."
		end
		progressaoTentativas[id] = instante
		local construcao = table.clone(perfil.construcao)
		construcao.unlockedRankIds = table.clone(perfil.construcao.unlockedRankIds or {})
		construcao.purchasedIds = table.clone(perfil.habilidadesCompradas or {})
		local permitido, motivo = Progressao.podeComprar(construcao, ctx.catalogo, payload.habilidadeId)
		if not permitido then return motivo or "Habilidade indisponível para esta ficha." end
		local atualizado = copiar(perfil)
		table.insert(atualizado.habilidadesCompradas, payload.habilidadeId)
		local salvo, revisaoOuErro = salvar(player, atualizado)
		if not salvo then return revisaoOuErro end
		if not ctx.conectado(player) then return "Jogador fora da sessão." end
		if ctx.persistencia and ctx.emCombate() then
			folhas[id], carregamentos[id] = nil, "erro"
			revisoes[id] = revisaoOuErro
			errosCarga[id] = "O combate começou durante o salvamento. Saia e entre novamente para carregar a ficha atualizada."
			return "O combate começou durante o salvamento. Saia e entre novamente para carregar a ficha atualizada."
		end
		revisoes[id] = revisaoOuErro or revisoes[id]
		folhas[id] = atualizado
		ultimasCompras[id] = { requestId = payload.requestId, habilidadeId = payload.habilidadeId }
		enviarPerfil(player)
		return nil
	end

	ctx.handlers.personagemPessoalEquiparArma = function(player, payload)
		if not ctx.conectado(player) then return "Jogador fora da sessão." end
		if type(payload) ~= "table" or getmetatable(payload) ~= nil
			or type(payload.sourceLocalId) ~= "string" or #payload.sourceLocalId == 0 or #payload.sourceLocalId > 96
			or type(payload.requestId) ~= "string" or #payload.requestId == 0 or #payload.requestId > 96
		then return "Pedido de arma inválido." end
		for chave in payload do
			if chave ~= "sourceLocalId" and chave ~= "requestId" then return "Pedido de arma inválido." end
		end
		local id = player.UserId
		local disponivel, motivo = perfilDisponivel(player)
		if not disponivel then return motivo end
		if ctx.emCombate() then return "Escolha a arma antes do combate." end
		if gravandoArma[id] then return "Aguarde o salvamento da arma." end
		local perfil = folhas[id]
		if not perfil then return "Crie um personagem antes de escolher a arma." end
		local pedidos = pedidosArma[id]
		local anterior = pedidos and pedidos.porId[payload.requestId]
		if anterior then
			if anterior ~= payload.sourceLocalId then return "ID de pedido já usado com outra arma." end
			enviarPerfil(player)
			return nil
		end
		-- Conserva todos os recibos aceitos nesta sessão: replay antigo nunca
		-- volta para uma arma anterior. O limite contém memória por jogador.
		if pedidos and pedidos.quantidade >= 128 then return "Limite de trocas atingido. Saia e entre novamente." end
		local instante = agora()
		if tentativasArma[id] and instante - tentativasArma[id] < 0.5 then return "Aguarde antes de trocar a arma." end
		tentativasArma[id] = instante
		if not armaDoKit(perfil, payload.sourceLocalId) then return "Escolha uma arma do kit da sua ficha." end
		local atualizado = copiar(perfil)
		atualizado.armaInicialSourceLocalId = payload.sourceLocalId
		gravandoArma[id] = true
		local salvo, revisaoOuErro = salvar(player, atualizado)
		gravandoArma[id] = nil
		if not salvo then return revisaoOuErro end
		if not ctx.conectado(player) then return "Jogador fora da sessão." end
		if ctx.emCombate() or folhas[id] ~= perfil then
			folhas[id], carregamentos[id], revisoes[id] = nil, "erro", revisaoOuErro
			errosCarga[id] = "A sessão mudou durante o salvamento. Saia e entre novamente para carregar a ficha atualizada."
			return errosCarga[id]
		end
		revisoes[id] = revisaoOuErro or revisoes[id]
		folhas[id] = atualizado
		pedidos = pedidos or { quantidade = 0, porId = {} }
		pedidos.porId[payload.requestId] = payload.sourceLocalId
		pedidos.quantidade += 1
		pedidosArma[id] = pedidos
		enviarPerfil(player)
		return nil
	end

	ctx.handlers.personagemPessoalConsultar = function(player, payload)
		if not ctx.conectado(player) then return "Jogador fora da sessão." end
		if type(payload) ~= "table" or next(payload) ~= nil then return "Consulta pessoal inválida." end
		local id = player.UserId
		if carregamentos[id] == "erro" and cargasRecuperaveis[id] then
			local instante = agora()
			if ultimaTentativaCarga[id] and instante - ultimaTentativaCarga[id] < INTERVALO_NOVA_CARGA then
				return "Aguarde alguns segundos antes de tentar carregar a ficha novamente."
			end
			ultimaTentativaCarga[id] = instante
			local carregou, motivo = carregar(player)
			if not carregou then return motivo end
			return nil
		end
		local disponivel, erroDisponivel = perfilDisponivel(player)
		if not disponivel then return erroDisponivel end
		enviarPerfil(player)
		return nil
	end

	ctx.handlers.personagemPessoalCriar = function(player, proposta)
		if not ctx.conectado(player) then return "Jogador fora da sessão." end
		if gravandoArma[player.UserId] then return "Aguarde o salvamento da arma." end
		if type(proposta) ~= "table" or getmetatable(proposta) ~= nil
			or type(proposta.requestId) ~= "string" or #proposta.requestId == 0 or #proposta.requestId > 96
		then return "Criação inválida ou grande demais." end
		local camposPermitidos = {
		nome = true, requestId = true, raceId = true, backgroundId = true, subtableEntryId = true,
		attributeBase = true, raceAttributeChoices = true, freeSkillChoiceIds = true,
		startingTreeId = true, treeSkillChoiceIds = true,
		}
		for chave in proposta do
			if not camposPermitidos[chave] then return "Criação inválida ou grande demais." end
		end
		if not propostaLimitada(proposta) then return "Criação inválida ou grande demais." end
		local disponivel, erroDisponivel = perfilDisponivel(player)
		if not disponivel then return erroDisponivel end
		local id = player.UserId
		local anteriores = pedidosCriacao[id]
		local anterior = anteriores and anteriores.porId[proposta.requestId]
		local conteudoPedido = copiar(proposta)
		conteudoPedido.requestId = nil
		if anterior then
			if not iguais(anterior, conteudoPedido) then return "ID de pedido já usado com outra criação." end
			enviarPerfil(player)
			return nil
		end
		if anteriores and anteriores.quantidade >= LIMITE_PEDIDOS_CRIACAO then
			return "Limite de criações atingido nesta sessão. Saia e entre novamente."
		end
		if ctx.emCombate() then return "Crie ou ajuste o personagem antes do combate." end
		local instante = agora()
		if tentativas[id] and instante - tentativas[id] < 0.75 then
			return "Aguarde antes de recalcular o personagem."
		end
		tentativas[id] = instante
		local nomeSolicitado = prepararNome(proposta.nome)
		if not nomeSolicitado then return "Informe um nome de personagem com até 32 caracteres." end
		if type(ctx.filtrarNome) ~= "function" then return "Filtro de nome indisponível. Tente novamente." end
		local filtrou, nomeFiltrado = pcall(ctx.filtrarNome, player, nomeSolicitado)
		if not filtrou or type(nomeFiltrado) ~= "string" then
			return "Não foi possível verificar o nome. Tente novamente."
		end
		nomeFiltrado = prepararNome(nomeFiltrado)
		if not nomeFiltrado then return "Escolha outro nome para o personagem." end
		if not ctx.conectado(player) then return "Jogador fora da sessão." end
		if gravandoArma[id] then return "Aguarde o salvamento da arma." end
		if ctx.emCombate() then return "Crie ou ajuste o personagem antes do combate." end

		local construcao = {}
		for chave, valor in proposta do
			if chave ~= "nome" and chave ~= "requestId" then construcao[chave] = valor end
		end
		-- Dentro de uma run, a árvore inicial é a que a run deu (RestricaoDeCriacao).
		local arvoreDaRun, bloqueioDaRun, semArvoreDaRun = RestricaoDeCriacao.consultar(player)
		if bloqueioDaRun then return bloqueioDaRun end
		if arvoreDaRun and construcao.startingTreeId ~= arvoreDaRun then
			return "Sua run exige a árvore inicial " .. string.gsub(arvoreDaRun, "^tree/", "") .. "."
		end
		if semArvoreDaRun and construcao.startingTreeId ~= nil then
			return "Árvore inicial: nesta expedição você a aprende com um mestre da vila; crie a ficha sem árvore."
		end
		local contextoRun = ctx.runId or RunSessao.contextoCriacao
		local runAntes = contextoRun(id)
		local contaApi = ctx.conta or ContaServico.start()
		local conta, erroConta = contaApi.obter(id)
		if not conta then return erroConta or "Não foi possível confirmar os desbloqueios da conta." end
		if not ctx.conectado(player) or ctx.emCombate() then return "A sessão mudou durante a consulta da conta." end
		local arvoreAtual, bloqueioAtual, semArvoreAtual = RestricaoDeCriacao.consultar(player)
		if bloqueioAtual or arvoreAtual ~= arvoreDaRun or semArvoreAtual ~= semArvoreDaRun or contextoRun(id) ~= runAntes then return bloqueioAtual or "A run mudou; tente criar novamente." end
		if BeneficiosConta.racaBloqueada(conta, construcao.raceId) then
			return "Raça bloqueada: escolha uma raça base (comum/incomum) ou compre o desbloqueio de raças raras na CONTA."
		end
		local runId = if arvoreDaRun or semArvoreDaRun then runAntes else nil
		local ok, perfil, erro = pcall(ctx.calcular, construcao, ctx.catalogo)
		if not ok then return "Erro interno ao calcular o personagem." end
		if not perfil then return erro or "Criação inválida." end
		local anterior = folhas[id]
		if anterior and anterior.construcao.startingTreeId == perfil.construcao.startingTreeId then
			perfil = ArvoresAprendidas.aplicar(perfil, anterior.arvoresAprendidas or {}, ctx.catalogo)
			if not perfil then return "Não foi possível preservar as árvores aprendidas." end
		end
		if anterior and #(anterior.habilidadesCompradas or {}) > 0
			and anterior.construcao.startingTreeId ~= perfil.construcao.startingTreeId
		then
			return "Esta ficha já aprendeu habilidades; mantenha a árvore inicial para preservar a progressão."
		end
		-- O cálculo atual é síncrono; a revalidação protege também uma dependência
		-- futura que ceda ao scheduler durante a construção da folha.
		if not ctx.conectado(player) then return "Jogador fora da sessão." end
		if ctx.emCombate() then return "Crie ou ajuste o personagem antes do combate." end
		if gravandoArma[id] then return "Aguarde o salvamento da arma." end
		perfil.aparencia = if anterior and anterior.construcao.raceId == perfil.construcao.raceId then copiar(anterior.aparencia) else nil
		perfil.aparencia = perfil.aparencia or Aparencia.padrao(perfil.construcao.raceId, id)
		perfil.nome = nomeFiltrado
		perfil.habilidadesCompradas = if anterior then copiar(anterior.habilidadesCompradas or {}) else {}
		perfil.descanso = anterior and copiar(anterior.descanso) or nil
		perfil.dojo = anterior and copiar(anterior.dojo) or Dojo.novoEstado()
		perfil.ouro = anterior and anterior.ouro or 0
		perfil.paGanhos = anterior and anterior.paGanhos or 0
		perfil.encontrosPagos = anterior and copiar(anterior.encontrosPagos or {}) or {}
		perfil.inventarioLoja = anterior and copiar(anterior.inventarioLoja or {}) or {}
		perfil.itensVendidos = anterior and copiar(anterior.itensVendidos or {}) or {}
		perfil.missoes = anterior and copiar(anterior.missoes or Missao.novoEstado()) or Missao.novoEstado()
		if anterior and anterior.construcao and perfil.construcao
			and anterior.construcao.startingTreeId == perfil.construcao.startingTreeId
			and armaDoKit(perfil, anterior.armaInicialSourceLocalId) then
			perfil.armaInicialSourceLocalId = anterior.armaInicialSourceLocalId
		end
		local inventario, registros, erroKit = BeneficiosConta.prepararInventario(
			perfil.inventarioInicial, perfil.inventarioLoja, perfil.itensVendidos, conta, runId)
		if not inventario then return erroKit end
		perfil.inventarioInicial, perfil.inventarioLoja = inventario, registros
		if contextoRun(id) ~= runAntes then return "A run mudou; tente criar novamente." end
		local novoPerfil = copiar(perfil)
		local salvo, revisaoOuErro = salvar(player, novoPerfil)
		if not salvo then return revisaoOuErro end
		if not ctx.conectado(player) then return "Jogador fora da sessão." end
		if ctx.persistencia and (ctx.emCombate() or contextoRun(id) ~= runAntes) then
			folhas[id], carregamentos[id] = nil, "erro"
			revisoes[id] = revisaoOuErro
			local motivoMudanca = if ctx.emCombate()
				then "O combate começou durante o salvamento. Saia e entre novamente para carregar a ficha atualizada."
				else "A sessão mudou durante o salvamento. Saia e entre novamente para carregar a ficha atualizada."
			errosCarga[id] = motivoMudanca
			return motivoMudanca
		end
		revisoes[id] = revisaoOuErro or revisoes[id]
		folhas[id] = novoPerfil
		anteriores = anteriores or { quantidade = 0, porId = {} }
		anteriores.porId[proposta.requestId] = conteudoPedido
		anteriores.quantidade += 1
		pedidosCriacao[id] = anteriores
		enviarPerfil(player, "criacao")
		return nil
	end

	return {
		sincronizarArvoresRun = function(player, ids)
			if not ctx.conectado(player) or ctx.emCombate() then return false end
			local id, perfil = player.UserId, folhas[player.UserId]
			if not perfil or gravandoArma[id] then return false end
			if #ids == #(perfil.arvoresAprendidas or {}) then
				local iguais = true
				for i, arvore in ids do if arvore ~= perfil.arvoresAprendidas[i] then iguais = false end end
				if iguais then return true end
			end
			local atualizado = ArvoresAprendidas.aplicar(perfil, ids, ctx.catalogo)
			if not atualizado then return false end
			gravandoArma[id] = true
			local salvo, revisao = salvar(player, atualizado)
			gravandoArma[id] = nil
			if not salvo or folhas[id] ~= perfil then return false end
			revisoes[id], folhas[id] = revisao or revisoes[id], atualizado
			enviarPerfil(player)
			return true
		end,
		observarPerfil = function(fn) table.insert(observadoresPerfil, fn) end,
		alterarAparencia = function(player, proposta, possuidos, autorizado)
			if not ctx.conectado(player) or ctx.emCombate() or not autorizado() then return false, "Aparência indisponível aqui." end
			local id, perfil = player.UserId, folhas[player.UserId]
			if not perfil or gravandoArma[id] then return false, "Aguarde a ficha/salvamento." end
			local valida, motivo = Aparencia.validar(proposta, perfil.construcao.raceId, possuidos)
			if not valida then return false, motivo end
			local atualizado = copiar(perfil)
			atualizado.aparencia = copiar(proposta)
			gravandoArma[id] = true
			local salvo, revisao = salvar(player, atualizado)
			gravandoArma[id] = nil
			if not salvo then return false, revisao end
			if not ctx.conectado(player) or folhas[id] ~= perfil then return false, "A sessão mudou durante o salvamento." end
			revisoes[id], folhas[id] = revisao or revisoes[id], atualizado
			-- O save confirmado é preservado; mudança de contexto durante I/O não aplica visual em combate.
			if not ctx.emCombate() and autorizado() then enviarPerfil(player) end
			return true, copiar(atualizado.aparencia)
		end,
		carregar = carregar,
		estadoCarga = function(player) return carregamentos[player.UserId] end,
		-- Somente API interna: não aceita identidade vinda de payload remoto.
		consultar = function(player)
			return copiar(folhas[player.UserId])
		end,
		acaoMissao = function(player, acao, missaoId)
			if player == nil or not ctx.conectado(player) or ctx.emCombate() then return false, "Missões indisponíveis durante combate." end
			if type(acao) ~= "string" or (acao ~= "aceitar" and acao ~= "entregar")
				or type(missaoId) ~= "string" or #missaoId < 1 or #missaoId > 96 then return false, "Pedido de missão inválido." end
			local id, perfil = player.UserId, folhas[player.UserId]
			local missao = MissoesDados.porId()[missaoId]
			if not perfil or not missao then return false, "Ficha ou missão indisponível." end
			if gravandoArma[id] then return false, "Aguarde o salvamento atual." end
			local novo, recompensa, erro
			if acao == "aceitar" then
				novo, erro = Missao.aceitar(perfil.missoes or Missao.novoEstado(), missao)
			else
				novo, recompensa, erro = Missao.entregar(perfil.missoes or Missao.novoEstado(), missao)
			end
			if not novo then return false, erro or "Ação de missão indisponível." end
			local atualizado = copiar(perfil)
			atualizado.missoes = novo
			if recompensa then
				local saldo = atualizado.ouro or 0
				if saldo > 9007199254740991 - recompensa.ouro then return false, "Saldo de ouro atingiu o limite seguro." end
				atualizado.ouro = saldo + recompensa.ouro
			end
			gravandoArma[id] = true
			local salvo, revisaoOuErro = salvar(player, atualizado)
			gravandoArma[id] = nil
			if not salvo then return false, revisaoOuErro end
			if not ctx.conectado(player) or folhas[id] ~= perfil then return false, "Sessão mudou durante o salvamento." end
			revisoes[id], folhas[id] = revisaoOuErro or revisoes[id], atualizado
			enviarPerfil(player)
			return true, copiar(atualizado), recompensa and recompensa.ouro or 0
		end,
		comprarLoja = function(player, itemId, sourceLocalId)
			if player == nil or not ctx.conectado(player) or ctx.emCombate() then return false, "Loja indisponível durante combate." end
			if type(itemId) ~= "string" or type(sourceLocalId) ~= "string" or #sourceLocalId < 1 or #sourceLocalId > 96 then return false, "Compra inválida." end
			local id, perfil = player.UserId, folhas[player.UserId]
			if not perfil then return false, "Crie uma ficha pessoal antes de comprar." end
			if gravandoArma[id] then return false, "Aguarde o salvamento atual." end
			local item = ITENS_LOJA[itemId]
			if not item or not Loja.naPrateleira(item, "F") then return false, "Este item não está à venda." end
			for _, existente in ipairs(perfil.inventarioInicial or {}) do if existente.sourceLocalId == sourceLocalId then return false, "ID de item já existe." end end
			local ouro, novo = Loja.comprar(perfil.ouro or 0, item, "F")
			if not ouro then return false, novo end
			novo.sourceLocalId, novo.equipped, novo.armorClassBonus = sourceLocalId, false, item.acBonus
			local atualizado = copiar(perfil)
			atualizado.ouro = ouro
			table.insert(atualizado.inventarioInicial, novo)
			table.insert(atualizado.inventarioLoja, { itemId = itemId, sourceLocalId = sourceLocalId })
			gravandoArma[id] = true
			local salvo, revisaoOuErro = salvar(player, atualizado)
			gravandoArma[id] = nil
			if not salvo then return false, revisaoOuErro end
			if not ctx.conectado(player) or ctx.emCombate() or folhas[id] ~= perfil then return false, "Sessão mudou durante o salvamento." end
			revisoes[id], folhas[id] = revisaoOuErro or revisoes[id], atualizado
			enviarPerfil(player)
			return true, ouro
		end,
		venderLoja = function(player, sourceLocalId, categoriasPermitidas)
			if player == nil or not ctx.conectado(player) or ctx.emCombate() then return false, "Loja indisponível durante combate." end
			if type(sourceLocalId) ~= "string" or #sourceLocalId < 1 or #sourceLocalId > 96 then return false, "Venda inválida." end
			local id, perfil = player.UserId, folhas[player.UserId]
			if not perfil then return false, "Crie uma ficha pessoal antes de vender." end
			if gravandoArma[id] then return false, "Aguarde o salvamento atual." end
			local indice, possuido
			for i, item in ipairs(perfil.inventarioInicial or {}) do if item.sourceLocalId == sourceLocalId then indice, possuido = i, item; break end end
			if not possuido then return false, "Você não possui este item." end
			if possuido.equipped == true or perfil.armaInicialSourceLocalId == sourceLocalId then return false, "Não é possível vender um item equipado ou arma ativa." end
			local itemCatalogo
			for _, comprado in ipairs(perfil.inventarioLoja or {}) do
				if comprado.sourceLocalId == sourceLocalId then itemCatalogo = ITENS_LOJA[comprado.itemId]; break end
			end
			if not itemCatalogo then
				for _, candidato in ipairs(ORDEM_ITENS_LOJA) do
					if candidato.name == possuido.name and candidato.type == possuido.type then itemCatalogo = candidato; break end
				end
			end
			local valor = itemCatalogo and Loja.valorDeVenda(itemCatalogo)
			if not valor or type(categoriasPermitidas) ~= "table" or not categoriasPermitidas[itemCatalogo.category] then return false, "A loja não compra este item." end
			local atualizado = copiar(perfil)
			atualizado.ouro = Loja.vender(atualizado.ouro or 0, itemCatalogo)
			table.remove(atualizado.inventarioInicial, indice)
			local compradoIndice
			for i, comprado in ipairs(atualizado.inventarioLoja) do if comprado.sourceLocalId == sourceLocalId then compradoIndice = i; break end end
			if compradoIndice and not string.match(sourceLocalId, "^conta%-") then table.remove(atualizado.inventarioLoja, compradoIndice)
			else table.insert(atualizado.itensVendidos, sourceLocalId) end
			gravandoArma[id] = true
			local salvo, revisaoOuErro = salvar(player, atualizado)
			gravandoArma[id] = nil
			if not salvo then return false, revisaoOuErro end
			if not ctx.conectado(player) or ctx.emCombate() or folhas[id] ~= perfil then return false, "Sessão mudou durante o salvamento." end
			revisoes[id], folhas[id] = revisaoOuErro or revisoes[id], atualizado
			enviarPerfil(player)
			return true, valor
		end,
		-- API interna, chamada apenas pelo encerramento autoritativo de J2.
		recompensarEncontro = function(player, encounterId, moedas, marcoId, pa)
			if player == nil or not ctx.conectado(player) or type(encounterId) ~= "string"
				or #encounterId == 0 or #encounterId > 128 or type(moedas) ~= "number"
				or moedas % 1 ~= 0 or moedas < 0 or moedas > 1000000
				or (marcoId ~= nil and (type(marcoId) ~= "string" or #marcoId > 128)) then return false end
			if pa ~= nil and (type(pa) ~= "number" or pa % 1 ~= 0 or pa < 0 or pa > 100) then return false end
			local id, perfil = player.UserId, folhas[player.UserId]
			if not perfil or gravandoArma[id] then return false end
			for _, pago in ipairs(perfil.encontrosPagos or {}) do if pago == encounterId then return true, perfil.ouro or 0, {} end end
			local atualizado = copiar(perfil)
			atualizado.ouro = (atualizado.ouro or 0) + moedas
			atualizado.paGanhos = (atualizado.paGanhos or 0) + (pa or 0)
			atualizado.encontrosPagos = atualizado.encontrosPagos or {}
			table.insert(atualizado.encontrosPagos, encounterId)
			local cumpridas = {}
			if marcoId then
				local novo
				novo, cumpridas = Missao.registrar(perfil.missoes or Missao.novoEstado(), MissoesDados.porId(), marcoId)
				if not novo then return false end
				atualizado.missoes = novo
			end
			gravandoArma[id] = true
			local salvo, revisaoOuErro = salvar(player, atualizado)
			gravandoArma[id] = nil
			if not salvo or folhas[id] ~= perfil then return false end
			revisoes[id], folhas[id] = revisaoOuErro or revisoes[id], atualizado
			enviarPerfil(player)
			return true, atualizado.ouro, cumpridas
		end,
		atualizarDojo = function(player, novoEstado)
			if player == nil or not ctx.conectado(player) or ctx.emCombate()
				or not Dojo.estadoValido(novoEstado) then return false, "Atualização do dojo indisponível." end
			local id, perfil = player.UserId, folhas[player.UserId]
			if not perfil then return false, "Crie uma ficha pessoal antes de treinar." end
			if gravandoArma[id] then return false, "Aguarde o salvamento atual." end
			local atualizado = copiar(perfil)
			atualizado.dojo = copiar(novoEstado)
			gravandoArma[id] = true
			local salvo, revisaoOuErro = salvar(player, atualizado)
			gravandoArma[id] = nil
			if not salvo then return false, revisaoOuErro end
			if not ctx.conectado(player) or ctx.emCombate() or folhas[id] ~= perfil then
				return false, "Sessão mudou durante o salvamento."
			end
			revisoes[id], folhas[id] = revisaoOuErro or revisoes[id], atualizado
			enviarPerfil(player)
			return true, copiar(atualizado.dojo)
		end,
		descansar = function(player, tipo)
			if player == nil or not ctx.conectado(player) or ctx.emCombate() then return false, "Descanso indisponível agora." end
			local id, perfil = player.UserId, folhas[player.UserId]
			if not perfil then return false, "Crie um personagem antes de descansar." end
			if gravandoArma[id] then return false, "Aguarde o salvamento atual." end
			local maximos = perfil.estatisticas.maxima
			local estado = perfil.descanso or { atuais = copiar(maximos), descansosCurtos = 0 }
			local maiorBonus = 1
			for _, rankId in perfil.construcao.unlockedRankIds or {} do
				local rank = ctx.catalogo.POR_ID[rankId]
				if rank and type(rank.data) == "table" and type(rank.data.rank) == "string" then
					maiorBonus = math.max(maiorBonus, RegrasLivro.bonusDeRank(rank.data.rank) or 1)
				end
			end
			local resultado, erro = DescansoAcampamento.resolver({ tipo = tipo, maximos = maximos,
				atuais = estado.atuais, descansosCurtos = estado.descansosCurtos,
				vigor = perfil.atributos.vigor, maiorBonus = maiorBonus })
			if not resultado then return false, erro end
			local atualizado = copiar(perfil)
			atualizado.descanso = { atuais = resultado.atuais, descansosCurtos = resultado.descansosCurtos }
			gravandoArma[id] = true
			local salvo, revisaoOuErro = salvar(player, atualizado)
			gravandoArma[id] = nil
			if not salvo then return false, revisaoOuErro end
			if not ctx.conectado(player) or ctx.emCombate() or folhas[id] ~= perfil then return false, "Sessão mudou durante o salvamento." end
			revisoes[id], folhas[id] = revisaoOuErro or revisoes[id], atualizado
			enviarPerfil(player)
			return true, resultado
		end,
		consumirItem = function(player, itemId, sourceLocalId)
			if player == nil or not ctx.conectado(player)
				or itemId ~= "item/pocao_menor_cura"
				or type(sourceLocalId) ~= "string" or #sourceLocalId == 0 or #sourceLocalId > 96
			then
				return false
			end
			local perfil = folhas[player.UserId]
			local inventario = perfil and perfil.inventarioInicial
			if type(inventario) ~= "table" then return false end
			for indice, item in ipairs(inventario) do
				if item.sourceLocalId == sourceLocalId
					and item.name == "Poção Menor de Cura"
					and item.type == "geral"
					and item.description == "Cura 1d8 + 2 PV. Beber ou dar a um aliado adjacente é Usar Item (1 Ação). Poção não é magia: a Ferida Fresca não a dobra, e nenhuma poção apaga Ferimento Crítico."
				then
					if string.match(sourceLocalId, "^conta%-") then
						if gravandoArma[player.UserId] then return false end
						local atualizado = copiar(perfil)
						table.remove(atualizado.inventarioInicial, indice)
						table.insert(atualizado.itensVendidos, sourceLocalId)
						gravandoArma[player.UserId] = true
						local salvo, revisao = salvar(player, atualizado)
						gravandoArma[player.UserId] = nil
						if not salvo or folhas[player.UserId] ~= perfil then return false end
						folhas[player.UserId], revisoes[player.UserId] = atualizado, revisao or revisoes[player.UserId]
						enviarPerfil(player)
						return true
					end
					table.remove(inventario, indice)
					ctx.remote:FireClient(player, "personagemPessoal", copiar(perfil))
					return true
				end
			end
			return false
		end,
		remover = function(player)
			folhas[player.UserId], tentativas[player.UserId] = nil, nil
			progressaoTentativas[player.UserId], ultimasCompras[player.UserId] = nil, nil
			carregamentos[player.UserId], revisoes[player.UserId], errosCarga[player.UserId] = nil, nil, nil
			cargasRecuperaveis[player.UserId], ultimaTentativaCarga[player.UserId] = nil, nil
			pedidosArma[player.UserId], tentativasArma[player.UserId], gravandoArma[player.UserId] = nil, nil, nil
			pedidosCriacao[player.UserId] = nil
		end,
	}
end

return PersonagemSessao
