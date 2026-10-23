-- Árvores de utilidade no combate (A20): Ladino (Se Esconder, Dano Furtivo,
-- Primeiro Golpe, Duelista de Rua), Bardo (Inspiração, Insulto, Canções, Refrão)
-- e Tático (Ordem de Tiro, Voz que Corrige, Primeiro a Ver). Regras puras em
-- Regras/Utilidades; o HabilidadeService chama os ganchos abaixo.
local Shared = game:GetService("ReplicatedStorage").Shared
local U = require(Shared.Regras.Utilidades)
local Combate = require(Shared.Regras.Combate)
local Execucao = require(Shared.Regras.Execucao)
local Arma = require(Shared.Regras.Arma)
local Armas = require(Shared.Regras.Armas)
local Estados = require(Shared.Regras.EstadosDeCombate)
local Visao = require(Shared.VisaoFurtiva)

local UtilidadesService = {}

-- ctx: tokens, combat, estados, random, catalogo, reacoes, aliado(a,b),
-- condicoesDe, aplicarCondicao, removerCondicao, temCondicao, visivel(a,b),
-- emNevoa(token), defesaDe(token), aplicarEfeito, logAboutToken, jaAgiu(id),
-- semAcoes(token), silenciado(token), resistenciaDe(token, atributo)
function UtilidadesService.novo(ctx)
	local api = {}
	local tokens, combat, estados = ctx.tokens, ctx.combat, ctx.estados
	local usosInspiracao: { [string]: number } = {}
	local primeiroGolpeUsado: { [string]: boolean } = {}
	local furtivoNoTurno: { [string]: number } = {}
	local vozNoTurno: { [string]: number } = {}
	local ultimoApontado: { [string]: { alvoId: string, dados: number, acertado: boolean } } = {}
	local duelista: { [string]: { rodada: number, atacanteId: string } } = {}
	local cancoes: { [string]: string } = {}

	local function f(token)
		return U.daFicha(token and token.ficha2, ctx.catalogo)
	end
	local function hostil(a, b)
		return a ~= b and not ctx.aliado(a, b)
	end
	local function distancia(a, b)
		return Combate.distancia(a.x, a.z, b.x, b.z)
	end
	local function vivo(t)
		return t and t.pv > 0 and not t.derrotado
	end
	local function ouve(t)
		return vivo(t) and not ctx.condicoesDe(t).surdo
	end
	local function cancaoAtiva(token)
		if not token then return nil end
		if not vivo(token) or ctx.semAcoes(token) or ctx.silenciado(token) then
			cancoes[token.id] = nil
		end
		return cancoes[token.id]
	end
	local function iniciarPP(token)
		if token.ppMax == nil and token.ficha2 then
			token.ppMax = token.ficha2.calculated.maxima.pp or 0
			token.pp = (token.ficha2.session.current and token.ficha2.session.current.pp) or token.ppMax
		end
	end

	-- Validação (antes de pagar) e execução das cartas "especial" --------------
	function api.testeFurtivo(token)
		local bonus = ctx.resistenciaDe(token, "agilidade")
		for _, pericia in token.ficha2 and token.ficha2.calculated.skills or {} do
			if pericia.skillId == "skill/furtividade" then bonus = pericia.bonus; break end
		end
		local cd = 10
		for _, outro in tokens do
			if hostil(token, outro) and vivo(outro) and distancia(token, outro) <= Visao.ALCANCE
				and ctx.visivel(token, outro) then
				cd = math.max(cd, U.cdParaEsconder(ctx.resistenciaDe(outro, "espirito")))
			end
		end
		return { bonus = bonus, cd = cd }
	end

	function api.validar(player, token, mec, payload): (string?, any)
		local e = mec.especial
		local alvo = type(payload.alvoId) == "string" and tokens[payload.alvoId] or nil
		if e == "esconder" then
			if U.patamar(token.ficha2, U.FURTIVIDADE) == 0 then return "Se Esconder é exclusivo do Ladino (Furtividade e Armadilhas)." end
			if ctx.temCondicao(token, "escondido") then return "Você já está Escondido." end
			if ctx.emNevoa(token) then return nil, { motivo = "na névoa", teste = api.testeFurtivo(token) } end
			for _, outro in tokens do
				if outro ~= token and vivo(outro) and hostil(token, outro) and Visao.contem(outro, token.x, token.z, ctx.bloqueiaVisao) then
					return "Você está no campo de visão de um inimigo. Vá para trás dele, afaste-se ou use cobertura/névoa."
				end
			end
			return nil, { motivo = "fora da vista", teste = api.testeFurtivo(token) }
		elseif e == "inspirar" or e == "insulto" or e == "apontar" then
			if not alvo or not vivo(alvo) or not ctx.podeVer(player, alvo) then return "Escolha um alvo visível." end
			if distancia(token, alvo) > (mec.alcanceCasas or 1) then return "Alvo fora do alcance da sua voz." end
			if e ~= "apontar" and ctx.silenciado(token) then return "Silenciado: sem voz." end
			if e == "inspirar" then
				if alvo == token or not ctx.aliado(token, alvo) then return "Inspire um aliado que te ouça." end
				if not ouve(alvo) then return "O aliado não te ouve." end
				if Estados.valor(estados, alvo.id, "inspiracao") then return "Esse aliado já tem um Dado de Inspiração. Ele precisa usá-lo primeiro." end
				local espirito = token.ficha2.calculated.attributes.espirito or 0
				if (usosInspiracao[token.id] or 0) >= espirito then return string.format("Sem usos de Inspiração (Espírito %d por descanso).", espirito) end
			else
				if not hostil(token, alvo) then return "Escolha um inimigo." end
				if e == "insulto" and not ouve(alvo) then return "O alvo não te ouve." end
			end
			return nil, { alvo = alvo }
		elseif e == "cancao" then
			if ctx.silenciado(token) then return "Silenciado: não toca." end
			if ctx.sustenta and ctx.sustenta(token) then return "Encerre a magia sustentada antes de tocar uma canção." end
			if cancaoAtiva(token) == mec.cancao then return "Essa canção já está tocando. Use outra ação ou troque de canção." end
			return nil, {}
		elseif e == "pararCancao" then
			if not cancoes[token.id] then return "Nenhuma canção tocando." end
			return nil, {}
		end
		return "Carta desconhecida.", nil
	end

	-- Ser visto revela, inclusive ao atravessar um cone e terminar fora dele.
	function api.atualizarVisao(movido, deX, deZ)
		local caminho = if movido and deX then Combate.linha(deX, deZ, movido.x, movido.z) else {}
		if #caminho == 0 then caminho = { false } end
		for _, escondido in tokens do
			if not ctx.temCondicao(escondido, "escondido") then continue end
			local visto = false
			for _, casa in caminho do
				local alvo = escondido
				if casa and escondido == movido then alvo = table.clone(escondido); alvo.x, alvo.z = casa[1], casa[2] end
				if ctx.emNevoa(alvo) then continue end
				for _, outro in tokens do
					local observador = outro
					if casa and outro == movido then observador = table.clone(outro); observador.x, observador.z = casa[1], casa[2] end
					if hostil(escondido, outro) and vivo(outro) and Visao.contem(observador, alvo.x, alvo.z, ctx.bloqueiaVisao) then visto = true; break end
				end
				if visto then break end
			end
			if visto then ctx.removerCondicao(escondido, "escondido"); ctx.logAboutToken(escondido, escondido.name .. " entra no campo de visão e se revela.") end
		end
	end

	function api.executar(token, mec, info, registro, recibo)
		local e = mec.especial
		if (e == "inspirar" or e == "insulto" or e == "cancao") and ctx.temCondicao(token, "escondido") then
			ctx.removerCondicao(token, "escondido")
			table.insert(registro, "usa a voz e se revela")
		end
		if e == "esconder" then
			local r = Combate.resistencia(ctx.random, info.teste.bonus, info.teste.cd)
			if r.passou then ctx.aplicarCondicao(token, "escondido") end
			recibo.resultado = string.format("Furtividade: d20 %d %+d = %d / CD %d • %s", r.d20.natural, r.bonus, r.total, r.cd, if r.passou then "Escondido" else "Falhou: continua visível")
			table.insert(registro, recibo.resultado)
		elseif e == "inspirar" then
			local alvo = info.alvo
			usosInspiracao[token.id] = (usosInspiracao[token.id] or 0) + 1
			local dado = U.dadoDeInspiracao(f(token).bardo)
			Estados.definir(estados, alvo.id, "inspiracao", dado, token.id, nil, combat.round)
			table.insert(registro, string.format("inspira %s: Dado de Inspiração %s para somar a um teste", alvo.name, dado))
			table.insert(recibo.alvos, { id = alvo.id })
			alvo.version += 1
			recibo.resultado = alvo.name .. " recebeu Inspiração " .. dado .. " • guardada até usar"
		elseif e == "insulto" then
			local alvo = info.alvo
			local atributos = token.ficha2.calculated.attributes
			local meu = ctx.random:NextInteger(1, 20) + (atributos.espirito or 0)
			local dele = ctx.random:NextInteger(1, 20) + ctx.resistenciaDe(alvo, "espirito")
			if meu > dele then
				Estados.definir(estados, alvo.id, "insultado", true, token.id, nil, combat.round)
				table.insert(registro, string.format("insulta %s: %d contra %d — o próximo ataque dele tem Desvantagem", alvo.name, meu, dele))
				recibo.resultado = "Insulto funcionou • próximo ataque do alvo com Desvantagem"
			else
				table.insert(registro, string.format("insulta %s: %d contra %d — não abala", alvo.name, meu, dele))
				recibo.resultado = "Insulto não abalou o alvo • nenhum bônus aplicado"
			end
			table.insert(recibo.alvos, { id = alvo.id })
		elseif e == "cancao" then
			cancoes[token.id] = mec.cancao
			recibo.resultado = if mec.cancao == "marcha" then "Marcha ativa • aliados no alcance: +1 casa de movimento" else "Dissonância ativa • dano no começo da sua próxima vez"
			table.insert(registro, "começa a tocar " .. mec.nome)
		elseif e == "pararCancao" then
			cancoes[token.id] = nil
			recibo.resultado = "Canção encerrada • os bônus dela terminaram"
			table.insert(registro, "para de tocar")
		elseif e == "apontar" then
			local alvo = info.alvo
			local patamar = f(token).tatico
			local anterior = ultimoApontado[token.id]
			local dados = patamar
			if anterior and anterior.alvoId == alvo.id and not anterior.acertado then
				dados = U.dadosApontado(patamar, anterior.dados + 1)
			end
			ultimoApontado[token.id] = { alvoId = alvo.id, dados = dados, acertado = false }
			Estados.remover(estados, alvo.id, "apontado", token.id)
			Estados.definir(estados, alvo.id, "apontado", dados, token.id, { de = "conjurador", inicio = true }, combat.round)
			table.insert(registro, string.format("aponta %s: o primeiro acerto nele causa +%dd6", alvo.name, dados))
			table.insert(recibo.alvos, { id = alvo.id })
			alvo.version += 1
		end
		token.version += 1
	end

	-- Primeiro Golpe: uma vez por combate, contra alvo Desprevenido.
	local function desprevenido(atacante, alvo): boolean
		return U.desprevenido(ctx.jaAgiu(alvo.id), ctx.condicoesDe(alvo).surpreso ~= nil, ctx.temCondicao(atacante, "escondido"))
	end
	function api.validarAtaque(token, mec, alvos): string?
		if mec.primeiroGolpe then
			if primeiroGolpeUsado[token.id] then return "Primeiro Golpe: uma vez por combate." end
			for _, alvo in alvos or {} do
				if not alvo.zona and not desprevenido(token, alvo) then return "Primeiro Golpe exige alvo Desprevenido (ainda não agiu, Surpreso ou você Escondido)." end
			end
		end
		return nil
	end

	-- Antes da rolagem: Desvantagem do Insulto, bônus do Tático contra o Apontado,
	-- e os ganchos de Inspiração/Voz que Corrige (depois de ver o d20).
	local function grupoDaArma(token)
		local a = token.ficha2 and Arma.daFicha(token.ficha2, ctx.catalogo, false)
		return a and not a.desarmado and Armas.grupo(a.nome)
	end
	local function oferecerInspiracao(quem, faltou: number, texto: string): number?
		local dado = Estados.valor(estados, quem.id, "inspiracao")
		if not dado or faltou <= 0 then return nil end
		local escolha = ctx.reacoes.perguntar(quem, texto, { { id = "inspiracao", nome = "Dado de Inspiração", detalhe = string.format("Soma %s (faltou %d).", dado, faltou) } })
		if escolha ~= "inspiracao" then return nil end
		Estados.remover(estados, quem.id, "inspiracao")
		return Combate.rolarDados(ctx.random, dado).total
	end
	-- Inspiração do alvo num teste de resistência que falhou (vale para todo efeito).
	function api.prepararTestes(alvos, entradas)
		for i, entrada in entradas do
			local alvo = alvos[i]
			if alvo and not alvo.zona and Estados.valor(estados, alvo.id, "inspiracao") then
				entrada.aposRolarTeste = function(r)
					if r.passou or r.d20.natural == 20 then return end
					local soma = oferecerInspiracao(alvo, r.cd - r.total, string.format("Você falhou no teste: %d contra CD %d.", r.total, r.cd))
					if soma then
						r.total += soma
						r.passou = r.total >= r.cd
					end
				end
			end
		end
	end
	function api.prepararAtaque(token, conjurador, alvos, entradas, mec)
		api.prepararTestes(alvos, entradas)
		local insulto = Estados.entrada(estados, token.id, "insultado")
		if insulto then
			conjurador.desvantagem = true
			Estados.remover(estados, token.id, "insultado")
		end
		local meu = f(token)
		for i, entrada in entradas do
			local alvo = alvos[i]
			local ap = alvo and Estados.entrada(estados, alvo.id, "apontado")
			if ap and ap.fonteId == token.id and meu.tatico > 0 then
				local g = grupoDaArma(token)
				if mec.arma and (g == "hastes" or g == "arcos-e-bestas") then
					entrada.bonusDeAcerto = (entrada.bonusDeAcerto or 0) + Execucao.bonusDeRankDa(token.ficha2, U.NAVEGACAO)
				end
			end
		end
		conjurador.aposRolarAtaque = function(ataque, alvoEntrada)
			if ataque.acertou or ataque.d20.natural == 1 then return end
			local soma = oferecerInspiracao(token, ataque.defesa - ataque.total, string.format("Seu ataque errou: %d contra CA %d.", ataque.total, ataque.defesa))
			if soma then
				ataque.total += soma
				ataque.acertou = ataque.total >= ataque.defesa
			end
			if ataque.acertou then return end
			-- Voz que Corrige: Reação do Tático quando um ataque contra o Apontado erra.
			local alvo = tokens[alvoEntrada.id]
			local ap = alvo and Estados.entrada(estados, alvo.id, "apontado")
			local tatico = ap and tokens[ap.fonteId]
			if tatico and vivo(tatico) and f(tatico).vozQueCorrige and vozNoTurno[tatico.id] ~= combat.turn
				and (tatico == token or ctx.aliado(tatico, token)) and ctx.reacoes.temReacao(tatico) and not ctx.silenciado(tatico) then
				local escolha = ctx.reacoes.perguntar(tatico, string.format("%s errou o Apontado (%d contra CA %d).", token.name, ataque.total, ataque.defesa),
					{ { id = "voz", nome = "Voz que Corrige", detalhe = "Quem errou repete a rolagem." } })
				if escolha == "voz" and ctx.reacoes.temReacao(tatico) then
					ctx.reacoes.gastar(tatico.id)
					vozNoTurno[tatico.id] = combat.turn
					local d = ctx.random:NextInteger(1, 20)
					ataque.d20 = { dados = { d }, natural = d, ajuste = "normal" }
					ataque.total = d + ataque.bonus
					ataque.critico = d == 20
					ataque.acertou = d ~= 1 and (d == 20 or ataque.total >= ataque.defesa)
					ctx.logAboutToken(tatico, string.format("%s grita a correção: %s rola de novo (%d).", tatico.name, token.name, ataque.total))
				end
			end
		end
	end

	-- Depois da rolagem: Dano Furtivo, Primeiro Golpe, bônus do Apontado e revelar.
	function api.aposResolver(token, alvos, efeitos, mec)
		local meu = f(token)
		local escondido = ctx.temCondicao(token, "escondido")
		for i, efeito in efeitos do
			local alvo = alvos[i]
			if alvo and not alvo.zona and efeito.ataque and efeito.ataque.acertou and efeito.dano then
				local extra, notas = 0, {}
				if meu.furtivo > 0 and furtivoNoTurno[token.id] ~= combat.turn then
					local vantagem = efeito.ataque.d20.ajuste == "vantagem"
					if U.furtivoValido(desprevenido(token, alvo), ctx.condicoesDe(alvo), vantagem) then
						furtivoNoTurno[token.id] = combat.turn
						local n = U.dadosFurtivos(meu.furtivo, mec.primeiroGolpe == true)
						local r = Combate.rolarDados(ctx.random, n .. "d6")
						extra += r.total
						table.insert(notas, string.format("%s %dd6 (%d)", if mec.primeiroGolpe then "Primeiro Golpe: Dano Furtivo triplicado" else "Dano Furtivo", n, r.total))
					end
				end
				local ap = Estados.entrada(estados, alvo.id, "apontado")
				local tatico = ap and tokens[ap.fonteId]
				if ap and tatico and (tatico == token or ctx.aliado(tatico, token)) then
					local r = Combate.rolarDados(ctx.random, ap.valor .. "d6")
					extra += r.total
					table.insert(notas, string.format("Apontado: +%dd6 (%d)", ap.valor, r.total))
					if tatico == token and mec.arma then
						local g = grupoDaArma(token)
						if g == "hastes" or g == "arcos-e-bestas" then
							local br = Execucao.bonusDeRankDa(token.ficha2, U.NAVEGACAO)
							extra += br
							table.insert(notas, string.format("ordem própria: +%d", br))
						end
					end
					Estados.remover(estados, alvo.id, "apontado")
					if ultimoApontado[ap.fonteId] then ultimoApontado[ap.fonteId].acertado = true end
				end
				if extra > 0 then
					efeito.dano.total += extra
					for _, n in notas do table.insert(efeito.notas, n) end
				end
			end
		end
		if mec.primeiroGolpe then primeiroGolpeUsado[token.id] = true end
		if escondido and mec.tipo == "ataque" then
			ctx.removerCondicao(token, "escondido")
			ctx.logAboutToken(token, token.name .. " ataca e se revela.")
		end
	end

	-- Refrão da Retomada: aliado a até 9 m erra um ataque contra inimigo.
	function api.aposAplicar(atacante, alvo, efeito, mec)
		if not atacante or not alvo or not efeito.ataque or efeito.ataque.acertou or not hostil(atacante, alvo) then return end
		for _, bardo in tokens do
			if bardo ~= atacante and vivo(bardo) and bardo.ficha2 and ctx.aliado(bardo, atacante) and f(bardo).refrao
				and distancia(bardo, atacante) <= U.ALCANCE_REFRAO and ctx.reacoes.temReacao(bardo) and not ctx.silenciado(bardo) then
				iniciarPP(bardo)
				if (bardo.pp or 0) >= 1 then
					local escolha = ctx.reacoes.perguntar(bardo, string.format("%s errou o ataque.", atacante.name),
						{ { id = "refrao", nome = "Refrão da Retomada", detalhe = "1 PP: até 3 aliados ganham 1d6 + patamar de PV temporários." } })
					if escolha == "refrao" and ctx.reacoes.temReacao(bardo) and (bardo.pp or 0) >= 1 then
						ctx.reacoes.gastar(bardo.id)
						bardo.pp -= 1
						bardo.version += 1
						local d6 = ctx.random:NextInteger(1, 6)
						local valor = U.pvDoRefrao(d6, f(bardo).bardo)
						local escolhidos = {}
						for _, t in tokens do
							if vivo(t) and (t == bardo or ctx.aliado(bardo, t)) and ouve(t) and distancia(bardo, t) <= U.ALCANCE_REFRAO then
								table.insert(escolhidos, t)
							end
						end
						table.sort(escolhidos, function(a, b) return a.pv / math.max(1, a.pvMax) < b.pv / math.max(1, b.pvMax) end)
						local nomes = {}
						for i = 1, math.min(3, #escolhidos) do
							local t = escolhidos[i]
							ctx.aplicarEfeito(t, { alvoId = t.id, pvTemp = valor, notas = {} }, bardo, { duracaoRodadas = 600 })
							table.insert(nomes, t.name)
						end
						ctx.logAboutToken(bardo, string.format("%s puxa o Refrão da Retomada (1d6 %d + %d): %d PV temporários para %s.", bardo.name, d6, f(bardo).bardo, valor, table.concat(nomes, ", ")))
					end
					return
				end
			end
		end
	end

	-- Duelista de Rua: com arma leve, +2 na CA contra um oponente por rodada.
	function api.caExtra(alvo, atacante): number
		if not atacante or not alvo.ficha2 or not f(alvo).duelistaDeRua then return 0 end
		local g = grupoDaArma(alvo)
		if g ~= "laminas-curtas" then return 0 end
		local d = duelista[alvo.id]
		if not d or d.rodada ~= combat.round then
			duelista[alvo.id] = { rodada = combat.round, atacanteId = atacante.id }
			return 2
		end
		return if d.atacanteId == atacante.id then 2 else 0
	end

	-- Marcha: aliados que ouvem o bardo ganham +1 casa (1,5 m) de Deslocamento.
	function api.bonusDeslocamento(token): number
		for bardoId, cancao in cancoes do
			local bardo = tokens[bardoId]
			if cancao == "marcha" and cancaoAtiva(bardo) == "marcha" and (bardo == token or ctx.aliado(bardo, token)) and ouve(token) and distancia(bardo, token) <= U.ALCANCE_VOZ then
				return 1
			end
		end
		return 0
	end

	-- Início da vez: a canção acaba se o bardo foi silenciado ou não age; a
	-- Dissonância fere quem ouve.
	function api.inicioDaVez(novoId)
		local bardo = novoId and tokens[novoId]
		local cancao = bardo and cancoes[bardo.id]
		if not cancao then return end
		if not vivo(bardo) or ctx.semAcoes(bardo) or ctx.silenciado(bardo) then
			cancoes[bardo.id] = nil
			ctx.logAboutToken(bardo, bardo.name .. " para de tocar.")
			return
		end
		if cancao ~= "dissonancia" then return end
		local quantos, formula = U.dissonancia(f(bardo).bardo)
		local alvos = {}
		for _, t in tokens do
			if vivo(t) and hostil(bardo, t) and ouve(t) and distancia(bardo, t) <= U.ALCANCE_VOZ and not (t.criatura and t.criatura.categoria == "construto") then
				table.insert(alvos, t)
			end
		end
		table.sort(alvos, function(a, b) return distancia(bardo, a) < distancia(bardo, b) end)
		for i = 1, math.min(quantos, #alvos) do
			local t = alvos[i]
			local r = Combate.rolarDados(ctx.random, formula)
			local texto = ctx.aplicarEfeito(t, { alvoId = t.id, dano = { partes = { r }, fixo = 0, total = r.total, tipo = "sônico" }, notas = {} }, bardo, nil)
			ctx.logAboutToken(t, string.format("Dissonância de %s em %s (%s): %s", bardo.name, t.name, formula, texto))
		end
	end

	-- Primeiro a Ver: aliados somam o Bônus de Rank do Tático na Iniciativa.
	function api.bonusDeIniciativa(token, grupo): number
		local melhor = 0
		for _, t in grupo do
			if t.ficha2 and f(t).primeiroAVer then
				melhor = math.max(melhor, Execucao.bonusDeRankDa(t.ficha2, U.NAVEGACAO))
			end
		end
		return melhor
	end

	function api.cancaoDe(token): string?
		return cancaoAtiva(token)
	end
	-- DTO de apoio. IDs/fontes são filtrados pela mesma visibilidade das fichas.
	function api.suporteDe(token, podeVer)
		local flags = f(token)
		local cancao = cancaoAtiva(token)
		local inspiracao = Estados.entrada(estados, token.id, "inspiracao")
		local fontesMarcha, beneficiados = {}, {}
		for id in cancoes do
			local bardo = tokens[id]
			if cancaoAtiva(bardo) == "marcha" and (bardo == token or ctx.aliado(bardo, token)) and ouve(token) and distancia(bardo, token) <= U.ALCANCE_VOZ then
				if podeVer(bardo) then table.insert(fontesMarcha, bardo.id) end
			end
		end
		if cancao == "marcha" then
			for _, outro in tokens do
				if podeVer(outro) and (outro == token or ctx.aliado(token, outro)) and ouve(outro) and distancia(token, outro) <= U.ALCANCE_VOZ then table.insert(beneficiados, outro.id) end
			end
		end
		table.sort(fontesMarcha); table.sort(beneficiados)
		return {
			bardo = flags.bardo > 0, cancao = cancao, beneficiados = beneficiados,
			marcha = api.bonusDeslocamento(token), fontesMarcha = fontesMarcha,
			inspiracao = inspiracao and inspiracao.valor,
			inspiracaoFonte = if inspiracao and tokens[inspiracao.fonteId] and podeVer(tokens[inspiracao.fonteId]) then inspiracao.fonteId else nil,
			inspiracoesMax = if flags.inspiracao then math.max(0, token.ficha2.calculated.attributes.espirito or 0) else 0,
			inspiracoesUsadas = usosInspiracao[token.id] or 0,
			dadoInspiracao = U.dadoDeInspiracao(flags.bardo),
			dissonancia = if cancao == "dissonancia" then flags.bardo .. "d6" else nil,
			limiteDissonancia = if cancao == "dissonancia" then flags.bardo else nil,
			pvTemp = token.pvTemp or 0,
		}
	end
	function api.estadosDe(token)
		local lista = {}
		local cancao = cancaoAtiva(token)
		if cancao then table.insert(lista, "Tocando: " .. (if cancao == "marcha" then "Marcha" else "Dissonância")) end
		if api.bonusDeslocamento(token) > 0 then table.insert(lista, "Marcha +1 casa") end
		local d = Estados.valor(estados, token.id, "inspiracao")
		if d then table.insert(lista, "Inspiração " .. d) end
		local ap = Estados.valor(estados, token.id, "apontado")
		if ap then table.insert(lista, "Apontado +" .. ap .. "d6") end
		if Estados.valor(estados, token.id, "insultado") then table.insert(lista, "Insultado") end
		return lista
	end
	function api.limpar()
		table.clear(usosInspiracao); table.clear(primeiroGolpeUsado); table.clear(furtivoNoTurno)
		table.clear(vozNoTurno); table.clear(ultimoApontado); table.clear(duelista); table.clear(cancoes)
	end
	function api.parar(token) cancoes[token.id] = nil end
	return api
end

return UtilidadesService
