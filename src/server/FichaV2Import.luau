-- Importação da ficha v2 (docs/CONTRATOS.md §5): o cliente envia o JSON do site
-- em partes; o servidor valida na ordem do §5.4, filtra os textos do jogador e
-- monta uma PROPOSTA. Nada muda na mesa até o mestre aprovar (fichaImportApply),
-- quando tudo é revalidado e aplicado de uma vez.
--
-- Comandos (todos só do mestre, pelo RemoteEvent Mesa e pelo despachante único):
--   fichaImportBegin  { byteCount, partCount, targetId?, sessionPolicy?, ownerUserId?, hidden?, x?, z?, requestId? }
--   fichaImportPart   { uploadId, index, text }
--   fichaImportCommit { uploadId }
--   fichaImportAbort  { uploadId }
--   fichaImportApply  { proposalId, version }
--   fichaImportReject { proposalId }
--   fichaDetalhe      { id }  (qualquer um que veja os atributos da ficha)
-- Respostas: evento "fichaUpload" { requestId?, uploadId, nextIndex?, proposalId? }
-- e "fichaDetalhe" { id, version, ficha2 }.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Protocol = require(Shared.MesaProtocol)
local FichaV2 = require(Shared.FichaV2)
local FichaSessao = require(Shared.FichaSessao)
local JsonEstrutura = require(Shared.JsonEstrutura)
local UploadPartes = require(Shared.UploadPartes)
local CondicaoRules = require(Shared.CondicaoRules)
local Condicoes = require(Shared.Condicoes)

local FichaV2Import = {}

local ESTRUTURA = { profundidade = 12, nos = 16384 }
local PROPOSTAS_MAX = 8
local PROPOSTA_PRAZO = 600 -- segundos até a proposta vencer
local AVISOS_NA_PROPOSTA = 20

local function ehJogadorReal(player: any): boolean
	return typeof(player) == "Instance" and player:IsA("Player")
end

-- deps (de MesaService):
--   remote, handlers, tokens, catalogo
--   filterText(texto, userId) -> texto?   (pode ceder)
--   stillMaster(player) -> boolean
--   generation() -> number;  ocupado() -> boolean (carregando ou fechando)
--   isPresentUser(userId) -> boolean;  canSeeStats(player, token) -> boolean
--   logMasters(texto, tom)
function FichaV2Import.start(deps)
	local uploads = UploadPartes.new()
	local propostas: { [string]: any } = {}
	local ordem: { string } = {}
	local proximaProposta = 0
	local handlers = deps.handlers
	local tokens = deps.tokens

	local function responder(player, evento: string, dados)
		if ehJogadorReal(player) then
			deps.remote:FireClient(player, evento, dados)
		end
	end

	local function removerProposta(id: string)
		propostas[id] = nil
		local indice = table.find(ordem, id)
		if indice then
			table.remove(ordem, indice)
		end
	end

	local function vencerPropostas()
		local agora = os.clock()
		for _, id in table.clone(ordem) do
			if propostas[id].vence <= agora then
				removerProposta(id)
			end
		end
	end

	-- Começo ---------------------------------------------------------------

	handlers.fichaImportBegin = function(player, payload, master)
		if not master then
			return "Só o mestre importa fichas."
		end
		uploads:expirar(os.clock())
		local alvo = payload.targetId
		local alvoVersao
		if alvo ~= nil then
			local token = type(alvo) == "string" and tokens[alvo]
			if not token then
				return "Ficha não encontrada."
			end
			alvoVersao = token.version
		end
		local politica = payload.sessionPolicy
		if politica == nil then
			politica = if alvo then "preserve" else "replace"
		elseif politica ~= "preserve" and politica ~= "replace" then
			return "Política de sessão inválida."
		end
		local dono = payload.ownerUserId or 0
		if dono ~= 0 and not deps.isPresentUser(dono) then
			return "Dono precisa ser um jogador presente."
		end
		if payload.hidden ~= nil and type(payload.hidden) ~= "boolean" then
			return "Campo oculto inválido."
		end
		if (payload.x ~= nil or payload.z ~= nil) and not Protocol.isCell(payload.x, payload.z) then
			return "Casa inválida."
		end
		local pedido = payload.requestId
		if pedido ~= nil and (type(pedido) ~= "string" or #pedido > 64) then
			return "Pedido inválido."
		end
		local uploadId, falha = uploads:iniciar(player, payload.byteCount, payload.partCount, os.clock(), {
			geracao = deps.generation(),
			alvo = alvo,
			alvoVersao = alvoVersao,
			politica = politica,
			dono = dono,
			oculta = payload.hidden == true,
			x = payload.x,
			z = payload.z,
		})
		if not uploadId then
			return "Envio recusado: " .. tostring(falha) .. "."
		end
		local resposta = { requestId = pedido, uploadId = uploadId, nextIndex = 1 }
		responder(player, "fichaUpload", resposta)
		return nil, resposta
	end

	handlers.fichaImportPart = function(player, payload, master)
		if not master then
			return "Só o mestre importa fichas."
		end
		uploads:expirar(os.clock())
		local proximo, falha = uploads:parte(player, payload.uploadId, payload.index, payload.text, os.clock())
		if not proximo then
			return "Envio recusado: " .. tostring(falha) .. "."
		end
		local resposta = { uploadId = payload.uploadId, nextIndex = proximo }
		responder(player, "fichaUpload", resposta)
		return nil, resposta
	end

	handlers.fichaImportAbort = function(player, payload, master)
		if not master then
			return "Só o mestre importa fichas."
		end
		uploads:abortar(player, payload.uploadId)
		return nil
	end

	-- Conclusão: valida e propõe -------------------------------------------

	local function resumo(corpo)
		local calc = corpo.calculated
		return {
			pv = calc.maxima.pv,
			pm = calc.maxima.pm,
			pt = calc.maxima.pt,
			pp = calc.maxima.pp,
			ca = calc.armorClass,
			iniciativa = calc.initiative.bonus,
			vantagemIniciativa = calc.initiative.advantage,
			deslocamento = calc.movementMeters,
			atributos = table.clone(calc.attributes),
			atuais = table.clone(corpo.session.current),
			compras = #corpo.construction.purchasedIds,
			ranks = #corpo.construction.unlockedRankIds,
			inventario = #corpo.construction.inventory,
			condicoes = #corpo.session.conditions,
			completa = corpo.constructionComplete,
		}
	end

	handlers.fichaImportCommit = function(player, payload, master)
		if not master then
			return "Só o mestre importa fichas."
		end
		uploads:expirar(os.clock())
		-- 1–4: transferência completa, tamanho e UTF-8 (UploadPartes libera em qualquer resultado).
		local texto, falha, contexto = uploads:concluir(player, payload.uploadId, os.clock())
		if not texto then
			return "Envio recusado: " .. tostring(falha) .. "."
		end
		-- 5: estrutura limitada antes do JSONDecode (chaves repetidas, null, profundidade).
		local estruturaOk, motivo = JsonEstrutura.verificar(texto, ESTRUTURA)
		if not estruturaOk then
			return "Ficha ilegível: " .. tostring(motivo) .. "."
		end
		-- 6: decodificação protegida.
		local decodificou, envelope = pcall(function()
			return HttpService:JSONDecode(texto)
		end)
		if not decodificou then
			return "Ficha ilegível: não é um JSON válido."
		end
		-- 7–8: schema, números, referências e catálogo desta mesa.
		local corpo, recusa, avisos = FichaV2.validar(envelope, deps.catalogo)
		if not corpo then
			return "Ficha recusada: " .. tostring(recusa)
		end
		-- 9: filtro de texto (cede). Textos iguais são filtrados uma vez.
		local geracao = deps.generation()
		local filtrados: { [string]: string } = {}
		for _, ref in FichaV2.textos(corpo) do
			local original = ref[1][ref[2]]
			local limpo = filtrados[original]
			if not limpo then
				limpo = deps.filterText(original, player.UserId)
				if not limpo then
					return "Não foi possível verificar os textos da ficha. Tente novamente."
				end
				filtrados[original] = limpo
			end
			ref[1][ref[2]] = limpo
		end
		if not deps.stillMaster(player) then
			return "Você não é mais mestre."
		end
		if deps.generation() ~= geracao or deps.generation() ~= contexto.geracao or deps.ocupado() then
			return "A mesa foi substituída durante a importação. Importe de novo."
		end
		-- 10: revalida depois do filtro (o filtro pode mudar tamanhos e caracteres).
		local revalidado, depois = FichaV2.validarCorpo(corpo, deps.catalogo)
		if not revalidado then
			return "Ficha recusada depois do filtro de texto: " .. tostring(depois)
		end
		corpo = revalidado
		-- Derivar condições somente do corpo filtrado (D-27).
		local condicoesMesa, avisosCondicoes = CondicaoRules.validate(FichaV2.paraMesa(corpo).conditions, Condicoes)
		for _, aviso in avisosCondicoes do
			table.insert(avisos, "Condição: " .. aviso)
		end
		-- 11: proposta para o mestre.
		vencerPropostas()
		if #ordem >= PROPOSTAS_MAX then
			removerProposta(ordem[1])
		end
		proximaProposta += 1
		local id = "p" .. proximaProposta
		local alvo = contexto.alvo and tokens[contexto.alvo]
		local proposta = {
			id = id,
			version = 1,
			corpo = corpo,
			condicoes = condicoesMesa,
			avisos = avisos,
			contexto = contexto,
			alvoNome = if alvo then alvo.name else nil,
			de = player.UserId,
			vence = os.clock() + PROPOSTA_PRAZO,
		}
		propostas[id] = proposta
		table.insert(ordem, id)
		deps.logMasters(string.format("Proposta de ficha %s: %s. Confira e aprove em Mestre.", id, corpo.name), "sistema")
		local resposta = { uploadId = payload.uploadId, proposalId = id }
		responder(player, "fichaUpload", resposta)
		return nil, resposta
	end

	-- Decisão do mestre ---------------------------------------------------

	handlers.fichaImportReject = function(player, payload, master)
		if not master then
			return "Só o mestre decide importações."
		end
		local proposta = type(payload.proposalId) == "string" and propostas[payload.proposalId]
		if not proposta then
			return "Proposta não encontrada ou vencida."
		end
		removerProposta(proposta.id)
		deps.logMasters("Proposta " .. proposta.id .. " recusada.", "sistema")
		return nil
	end

	handlers.fichaImportApply = function(player, payload, master)
		if not master then
			return "Só o mestre decide importações."
		end
		vencerPropostas()
		local proposta = type(payload.proposalId) == "string" and propostas[payload.proposalId]
		if not proposta then
			return "Proposta não encontrada ou vencida."
		end
		if payload.version ~= proposta.version then
			return "A proposta mudou; confira de novo."
		end
		local contexto, corpo = proposta.contexto, proposta.corpo
		-- 12: revalida tudo o que pode ter mudado desde a proposta.
		if deps.generation() ~= contexto.geracao then
			removerProposta(proposta.id)
			return "A mesa foi substituída desde a proposta. Importe de novo."
		end
		local alvo
		if contexto.alvo then
			alvo = tokens[contexto.alvo]
			if not alvo or alvo.version ~= contexto.alvoVersao then
				removerProposta(proposta.id)
				return "A ficha mudou desde a proposta. Importe de novo."
			end
		end
		local mesa = FichaV2.paraMesa(corpo)
		-- Retira antes de ceder: duas aprovações simultâneas não aplicam duas vezes.
		removerProposta(proposta.id)
		local falha, id
		if alvo then
			local substituir = contexto.politica == "replace"
			falha = handlers.updateToken(player, {
				id = alvo.id,
				name = corpo.name,
				pvMax = mesa.pvMax,
				manaMax = mesa.manaMax,
				pv = if substituir then mesa.pv else nil,
				mana = if substituir then mesa.mana else nil,
			}, true)
			id = alvo.id
		else
			falha, id = handlers.createToken(player, {
				name = corpo.name,
				kind = "jogador",
				pvMax = mesa.pvMax,
				manaMax = mesa.manaMax,
				ownerUserId = contexto.dono,
				hidden = contexto.oculta,
				x = contexto.x,
				z = contexto.z,
			}, true)
		end
		if falha then
			-- Nada foi aplicado: a proposta volta para o mestre decidir de novo.
			if deps.generation() == contexto.geracao and not propostas[proposta.id] then
				propostas[proposta.id] = proposta
				table.insert(ordem, proposta.id)
			end
			return falha
		end
		-- Sem ceder desde criar/editar: a ficha ainda é a mesma.
		local token = tokens[id]
		local substituirSessao = not alvo or contexto.politica == "replace"
		if substituirSessao then
			token.pv, token.mana = mesa.pv, mesa.mana
			token.conditions = proposta.condicoes
		elseif token.ficha2 then
			-- PV/PM/condições vivem no token; os demais recursos vivem no corpo.
			local anterior = token.ficha2.session
			for _, recurso in { "pt", "pp" } do
				corpo.session.current[recurso] = math.min(anterior.current[recurso], corpo.calculated.maxima[recurso])
			end
			corpo.session.shortRests = anterior.shortRests
			corpo.session.manualEffects = anterior.manualEffects
		end
		token.sheet = mesa.sheet
		token.ficha2 = corpo
		token.version += 1
		deps.logMasters(string.format("Ficha %s %s (%s).", token.name, if alvo then "atualizada" else "importada", if substituirSessao then "sessão do site" else "sessão da mesa mantida"), "sistema")
		return nil, { id = id }
	end

	-- Detalhe sob demanda: a ficha completa não vai no snapshot (seria enviada a
	-- todos a cada mudança). O cliente pede quando a versão muda.
	handlers.fichaDetalhe = function(player, payload, master)
		local token = type(payload.id) == "string" and tokens[payload.id]
		if not token or not deps.canSeeStats(player, token) then
			return "Ficha não encontrada."
		end
		local dados = {
			id = token.id, version = tostring(deps.generation()) .. ":" .. token.version,
			ficha2 = FichaSessao.projetar(token, master == true or token.ownerUserId == player.UserId),
		}
		responder(player, "fichaDetalhe", dados)
		return nil, dados
	end

	local api = {}

	-- Resumo das propostas para o snapshot do mestre.
	function api.propostas()
		vencerPropostas()
		local lista = {}
		local agora = os.clock()
		for _, id in ordem do
			local p = propostas[id]
			local avisos = {}
			for indice, aviso in p.avisos do
				if indice > AVISOS_NA_PROPOSTA then
					table.insert(avisos, string.format("… e mais %d aviso(s).", #p.avisos - AVISOS_NA_PROPOSTA))
					break
				end
				table.insert(avisos, aviso)
			end
			for _, aviso in p.corpo.warnings do
				table.insert(avisos, "Site: " .. aviso)
			end
			table.insert(lista, {
				id = p.id,
				version = p.version,
				name = p.corpo.name,
				targetId = p.contexto.alvo,
				targetName = p.alvoNome,
				sessionPolicy = p.contexto.politica,
				avisos = avisos,
				resumo = resumo(p.corpo),
				venceEm = math.max(0, math.floor(p.vence - agora)),
			})
		end
		return lista
	end

	-- A mesa foi substituída (carregar, limpar): propostas e envios caem.
	function api.descartarTudo()
		for _, id in table.clone(ordem) do
			removerProposta(id)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		uploads:liberarDono(player)
	end)

	return api
end

return FichaV2Import
