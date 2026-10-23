-- Janela de Reação (A14). O servidor decide quem pode reagir; o dono da ficha
-- escolhe numa pergunta com prazo (sem resposta = não reage). As regras puras
-- estão em Regras/Reacoes; este módulo guarda o orçamento (1 Reação por rodada,
-- Fluxo com limite próprio), pergunta e aplica.
--
-- Contrato de rede:
--   servidor → cliente  "reacao" { id, tokenId, texto, opcoes = {{ id, nome, detalhe }}, prazo }
--                       "reacao" { id, fechar = true }
--   cliente → servidor  reagir { id, escolha? }  (escolha nil = não reagir)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Reacoes = require(Shared.Regras.Reacoes)
local Combate = require(Shared.Regras.Combate)
local Execucao = require(Shared.Regras.Execucao)
local Maestrias = require(Shared.Regras.Maestrias)

local ReacoesService = {}

ReacoesService.PRAZO = 8

-- ctx: tokens, combat, remote, random, catalogo, handlers, condicoesDe(token),
-- semAcoes(token), aliado(a, b), visivel(a, b), logAboutToken(token, texto),
-- contraAtacar(reator, atacante), estadoValor?(token, nome),
-- decidir? (testes: substitui a pergunta).
function ReacoesService.novo(ctx)
	local api = {}
	local usada: { [string]: boolean } = {}
	local fluxoNaRodada: { [string]: number } = {}
	local designado: { [string]: string } = {}
	local pendentes: { [number]: any } = {}
	local sequencia = 0
	local abertas = 0

	local function ficha(token)
		return token and token.ficha2
	end

	-- Pode reagir agora: ficha de jogador, de pé, com Reação e sem condição que a tire.
	local function podeReagir(token): boolean
		if not token or not ficha(token) or token.pv <= 0 or token.derrotado or usada[token.id] then
			return false
		end
		if ctx.semAcoes(token) then
			return false
		end
		return ctx.condicoesDe(token).desequilibrado == nil
	end

	local function sabe(token)
		return Reacoes.daFicha(ficha(token), ctx.catalogo)
	end

	local function bcDa(token, arvore: string): number
		return Execucao.bc(token.ficha2, arvore, ctx.catalogo)
	end

	-- Pergunta ao dono da ficha. Devolve o id da opção escolhida ou nil.
	local function perguntar(token, texto: string, opcoes)
		if #opcoes == 0 then
			return nil
		end
		if api.decidir then
			return api.decidir(token, texto, opcoes)
		end
		local player = token.ownerUserId and Players:GetPlayerByUserId(token.ownerUserId)
		if not player then
			return nil
		end
		sequencia += 1
		local id = sequencia
		local sinal = Instance.new("BindableEvent")
		local pedido = { userId = player.UserId, opcoes = opcoes, sinal = sinal }
		pendentes[id] = pedido
		abertas += 1
		ctx.remote:FireClient(player, "reacao", { id = id, tokenId = token.id, texto = texto, opcoes = opcoes, prazo = ReacoesService.PRAZO })
		task.delay(ReacoesService.PRAZO, function()
			if pendentes[id] == pedido then
				pendentes[id] = nil
				sinal:Fire(nil)
			end
		end)
		local escolha = sinal.Event:Wait()
		abertas -= 1
		sinal:Destroy()
		if player.Parent then
			ctx.remote:FireClient(player, "reacao", { id = id, fechar = true })
		end
		return escolha
	end

	ctx.handlers.reagir = function(player, payload)
		local id = payload.id
		local pedido = type(id) == "number" and pendentes[id]
		if not pedido or pedido.userId ~= player.UserId then
			return "Essa Reação já passou."
		end
		local escolha = payload.escolha
		if escolha ~= nil then
			local valida = false
			for _, opcao in pedido.opcoes do
				if opcao.id == escolha then
					valida = true
				end
			end
			if not valida then
				return "Opção de Reação inválida."
			end
		end
		pendentes[id] = nil
		pedido.sinal:Fire(escolha)
		return nil
	end

	-- Pergunta genérica ao dono (Inspiração, Voz que Corrige, Refrão...).
	api.perguntar = perguntar

	function api.pendente(): boolean
		return abertas > 0
	end

	function api.gastar(tokenId: string)
		usada[tokenId] = true
	end

	function api.temReacao(token): boolean
		return podeReagir(token)
	end

	-- Início da vez: a Reação volta e a Parede de quem age agora some.
	function api.inicioDaVez(tokenId: string?)
		if not tokenId then
			return
		end
		usada[tokenId] = nil
	end

	function api.limpar()
		table.clear(usada)
		table.clear(fluxoNaRodada)
		table.clear(designado)
	end

	-- Sob Minha Guarda: o protetor designa um aliado (troca o anterior).
	function api.designar(protetor, alvo)
		designado[protetor.id] = alvo.id
	end

	function api.designadoDe(protetorId: string): string?
		return designado[protetorId]
	end

	local function candidatos(alvo, atacante, filtro)
		local lista = {}
		for _, outro in ctx.tokens do
			if outro ~= atacante and podeReagir(outro) and filtro(outro) then
				table.insert(lista, outro)
			end
		end
		table.sort(lista, function(a, b)
			return a.id < b.id
		end)
		return lista
	end

	-- Antes da rolagem: Guarda do Corpo (vira o alvo) e Parede de Emergência.
	-- Devolve o alvo final.
	function api.antesDoAtaque(atacante, alvo, mec)
		if not alvo or alvo.pv <= 0 then
			return alvo
		end
		local nomeAtacante = atacante and atacante.name or "Alguém"
		for _, guarda in candidatos(alvo, atacante, function(t)
			return t ~= alvo and ctx.aliado(t, alvo) and Combate.distancia(t.x, t.z, alvo.x, alvo.z) <= 1 and sabe(t).guardaDoCorpo == true
		end) do
			local texto = string.format("%s vai atacar %s, ao seu lado.", nomeAtacante, alvo.name)
			local escolha = perguntar(guarda, texto, { { id = "guardaDoCorpo", nome = "Guarda do Corpo", detalhe = "Você vira o alvo; vale a sua CA." } })
			if escolha == "guardaDoCorpo" and podeReagir(guarda) then
				usada[guarda.id] = true
				ctx.logAboutToken(guarda, string.format("%s usa Guarda do Corpo: entra na frente de %s.", guarda.name, alvo.name))
				alvo = guarda
				break
			end
		end
		if Reacoes.fisico(mec) and ctx.criarParede and (not ctx.paredeBarra or ctx.paredeBarra(mec)) then
			for _, autor in candidatos(alvo, atacante, function(t)
				return (t == alvo or ctx.aliado(t, alvo)) and Combate.distancia(t.x, t.z, alvo.x, alvo.z) <= 2 and (t == alvo or ctx.visivel(t, alvo))
					and sabe(t).parede == true and (t.mana or 0) >= Reacoes.CUSTO_PM.parede
			end) do
				local quem = if autor == alvo then "você" else alvo.name
				local texto = string.format("%s vai atacar %s.", nomeAtacante, quem)
				local escolha = perguntar(autor, texto, { { id = "parede", nome = "Parede de Emergência", detalhe = string.format("%d PM: uma parede de %d PV recebe o golpe.", Reacoes.CUSTO_PM.parede, Reacoes.PV_DA_PAREDE) } })
				if escolha == "parede" and podeReagir(autor) and (autor.mana or 0) >= Reacoes.CUSTO_PM.parede and ctx.criarParede(autor, atacante, alvo, Reacoes.PV_DA_PAREDE) then
					usada[autor.id] = true
					autor.mana -= Reacoes.CUSTO_PM.parede
					autor.version += 1
					ctx.logAboutToken(autor, string.format("%s ergue a Parede de Emergência diante de %s (%d PV).", autor.name, alvo.name, Reacoes.PV_DA_PAREDE))
					break
				end
			end
		end
		return alvo
	end

	-- Depois da rolagem, antes de aplicar. Pode mudar o efeito; devolve uma
	-- lista de { token, efeito } a aplicar além do original (dano interceptado).
	function api.aposRolagem(atacante, alvo, efeito, mec)
		local extras = {}
		local ataque = efeito.ataque
		if not ataque or not ataque.acertou or not alvo then
			return extras
		end
		-- Defender/Absorver (Ação do turno anterior, não Reação): todo golpe que
		-- acerta perde Vigor + metade do maior Rank de corpo.
		if ctx.estadoValor and ctx.estadoValor(alvo, "defender") and efeito.dano and efeito.dano.total > 0 and ficha(alvo) then
			local f = ficha(alvo)
			local corpo = Execucao.arvoreDeCorpo(f, ctx.catalogo)
			local valor = Maestrias.reducaoDefender(f.calculated.attributes.vigor or 0, Execucao.bonusDeRankDa(f, corpo))
			local r = Reacoes.reduzir(efeito, valor)
			table.insert(efeito.notas, string.format("Defender: dano −%d", r))
		end
		-- Reação do próprio alvo.
		if podeReagir(alvo) then
			local s = sabe(alvo)
			local opcoes = {}
			local f = ficha(alvo)
			local rankAgua = Execucao.bonusDeRankDa(f, "deus-da-agua-corpo")
			if s.aparar and Reacoes.corpoACorpo(mec) and Reacoes.apararViraErro(ataque, rankAgua) then
				table.insert(opcoes, { id = "aparar", nome = "Aparar", detalhe = string.format("+%d na CA (%d): o golpe de %d erra.", rankAgua, ataque.defesa + rankAgua, ataque.total) })
			end
			if s.escudo and Reacoes.fisico(mec) and not ctx.condicoesDe(alvo).cego then
				local prof = Reacoes.proficienteEmEscudo(f)
				local erra, reducao = Reacoes.bloqueio(ataque, prof, f.calculated.highestRankBonus or 0)
				table.insert(opcoes, { id = "escudo", nome = "Bloquear com Escudo",
					detalhe = if erra then string.format("+%d na CA: o golpe erra.", if prof then 5 else 2) else string.format("O golpe ainda acerta; o dano cai %d.", reducao) })
			end
			if s.couraca and Reacoes.danoFisico(efeito, mec) and (alvo.mana or 0) >= Reacoes.CUSTO_PM.couraca then
				table.insert(opcoes, { id = "couraca", nome = "Couraça de Barro", detalhe = string.format("%d PM: reduz 1d6 + %d do dano (%d).", Reacoes.CUSTO_PM.couraca, bcDa(alvo, "terra"), efeito.dano.total) })
			end
			if #opcoes > 0 then
				local dano = if efeito.dano then efeito.dano.total else 0
				local texto = string.format("%s acerta você: %d contra CA %d%s.", if atacante then atacante.name else "Um golpe", ataque.total, ataque.defesa,
					if dano > 0 then string.format(", %d de dano", dano) else "")
				local escolha = perguntar(alvo, texto, opcoes)
				if escolha and podeReagir(alvo) then
					if escolha == "aparar" then
						usada[alvo.id] = true
						Reacoes.anular(efeito, string.format("Aparar: CA %d → %d, o golpe erra", ataque.defesa, ataque.defesa + rankAgua))
					elseif escolha == "escudo" then
						usada[alvo.id] = true
						local erra, reducao = Reacoes.bloqueio(ataque, Reacoes.proficienteEmEscudo(f), f.calculated.highestRankBonus or 0)
						if erra then
							Reacoes.anular(efeito, "Bloquear com Escudo: o golpe erra")
						else
							local r = Reacoes.reduzir(efeito, reducao)
							table.insert(efeito.notas, string.format("Bloquear com Escudo: dano −%d", r))
						end
					elseif escolha == "couraca" and (alvo.mana or 0) >= Reacoes.CUSTO_PM.couraca and efeito.dano then
						usada[alvo.id] = true
						alvo.mana -= Reacoes.CUSTO_PM.couraca
						alvo.version += 1
						local d6 = ctx.random:NextInteger(1, 6)
						local r = Reacoes.reduzir(efeito, d6 + bcDa(alvo, "terra"))
						table.insert(efeito.notas, string.format("Couraça de Barro: 1d6 (%d) + %d, dano −%d", d6, bcDa(alvo, "terra"), r))
					end
				end
			end
		end
		-- Sob Minha Guarda (Interpor): o protetor a até 3 m toma todo o dano.
		if efeito.dano and efeito.dano.total > 0 then
			for _, protetor in candidatos(alvo, atacante, function(t)
				if t == alvo or not sabe(t).interpor or Combate.distancia(t.x, t.z, alvo.x, alvo.z) > 2 then
					return false
				end
				local guarda = ctx.guardaDe(alvo)
				return designado[t.id] == alvo.id or guarda == t.id
			end) do
				local texto = string.format("%s acerta %s, Sob Sua Guarda: %d de dano.", if atacante then atacante.name else "Um golpe", alvo.name, efeito.dano.total)
				local escolha = perguntar(protetor, texto, { { id = "interpor", nome = "Interpor", detalhe = "Todo o dano vem para você." } })
				if escolha == "interpor" and podeReagir(protetor) and efeito.dano then
					usada[protetor.id] = true
					local desvio = { alvoId = protetor.id, dano = efeito.dano, notas = { "Interpor: recebe o golpe no lugar de " .. alvo.name } }
					efeito.dano = nil
					table.insert(efeito.notas, protetor.name .. " intercepta o dano (Sob Minha Guarda)")
					table.insert(extras, { token = protetor, efeito = desvio })
					break
				end
			end
		end
		return extras
	end

	-- Depois de aplicar: Fluxo (Deus da Água). Não gasta Reação; 1 por rodada.
	function api.aposAplicar(atacante, alvo, efeito, mec)
		local ataque = efeito.ataque
		if not atacante or not alvo or not ataque or ataque.acertou or not Reacoes.corpoACorpo(mec) then
			return
		end
		if atacante.pv <= 0 or atacante.derrotado or alvo.pv <= 0 or ctx.semAcoes(alvo) or not ficha(alvo) then
			return
		end
		if not sabe(alvo).fluxo or Combate.distancia(alvo.x, alvo.z, atacante.x, atacante.z) > 1 then
			return
		end
		local rodada = ctx.combat.round or 0
		if fluxoNaRodada[alvo.id] == rodada then
			return
		end
		fluxoNaRodada[alvo.id] = rodada
		ctx.logAboutToken(alvo, alvo.name .. " responde com o Fluxo.")
		ctx.contraAtacar(alvo, atacante)
	end

	return api
end

return ReacoesService
