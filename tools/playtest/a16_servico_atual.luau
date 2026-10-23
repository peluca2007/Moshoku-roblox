-- Spec e fonte A16 atuais, isolados: não altera a mesa nem o modo do Studio.
local ServicoAtual=(function()
-- Habilidades em combate. O servidor decide tudo: vez, Ações do turno, PM/PT,
-- alcance, linha de visão, geometria, rolagens e efeitos. O cliente só pede e
-- depois anima o RECIBO (evento "efeito"). Mecânicas: Regras/Execucao (uma
-- tabela por árvore); resolução pura: Regras/Habilidades.
--
-- Comandos (pelo despachante único da mesa):
--   usarHabilidade  { tokenId, habilidadeId, alvoId?, x?, z? }  dono na vez dele, ou mestre
--   apagarFogo      { tokenId }   1 Ação: Agilidade CD 10 apaga Em Chamas (livro)
--   criarCriatura   { creatureId, x?, z? }  só mestre: ficha do bestiário
--   criarPremontado { id, ownerUserId?, x?, z? }  só mestre: personagem pronto
--   reagir          { id, escolha? }  resposta à pergunta de Reação (ReacoesService)
--
-- Estado próprio: Ações e habilidades usadas na vez atual, zonas persistentes
-- (muros, névoa, escudos) e durações de condição ("até o fim do próximo turno").
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Protocol = require(Shared.MesaProtocol)
local CondicaoRules = require(Shared.CondicaoRules)
local Condicoes = require(Shared.Condicoes)
local FichaV2 = require(Shared.FichaV2)
local Combate = require(Shared.Regras.Combate)
local Habilidades = require(Shared.Regras.Habilidades)
local Criaturas = require(Shared.Regras.Criaturas)
local Execucao = require(Shared.Regras.Execucao)
local Arma = require(Shared.Regras.Arma)
local Estado = require(Shared.Regras.EstadoHabilidades)
local Estados = require(Shared.Regras.EstadosDeCombate)
local Regras = require(Shared.Livro.Regras)
local Progressao = require(Shared.Regras.Progressao)
local Reacoes = require(Shared.Regras.Reacoes)
local Barreiras = require(Shared.Regras.Barreiras)
local Agarrar = require(Shared.Regras.Agarrar)
local Desarme = require(Shared.Regras.Desarme)
local Armas = require(Shared.Regras.Armas)
local ReacoesService = require(game.ServerScriptService.Server.ReacoesService)

local HabilidadeService = {}

local ACOES_POR_TURNO = Regras.acoesPorTurno
local CD_APAGAR_FOGO = 10
local TIPO_DO_DANO_POR_TURNO = { ["em-chamas"] = "ígneo", soterrado = "sufocamento" }

-- deps (de MesaService):
--   remote, handlers, tokens, tokenOrder, combat, random, catalogo, premontados
--   canSee(player, token), currentTurnId(), logAboutToken(token, texto)
--   terrain, cellKey(x, z), removerFicha(id), reviverBoneco(token)
--   moverFicha(token, x, z)   move de verdade (avatar, registro); sem custo
function HabilidadeService.start(deps)
	-- Injeção do registro permite cenários isolados no Studio, sem alterar a mesa.
	local Execucao = deps.execucao or Execucao
	local handlers, tokens, combat = deps.handlers, deps.tokens, deps.combat
	local turnoAtual = { tokenId = nil :: string?, turno = -1, usadas = 0, usos = {} :: { [string]: boolean }, acertou = false, acertados = {} }
	local zonas: { any } = {}
	local proximaZona = 0
	local sequencia = 0
	local estados = Estados.novo()
	local fontesCondicao = {}
 local agarrados, objetos, equipamentoOriginal, quebrados, ultimasPosicoes = {}, {}, {}, {}, {}
 local proximoObjeto = 0
	local usosCombate = {}
	local usosDescanso = {}
	local vacuos = {}
	local invocados = {}
	local pactosExaustos = {}
	-- Durações: { tokenId, condicao, gatilho (tokenId cuja vez encerra), estado, rodadaFim? }
	local duracoes: { any } = {}
	-- Condições que as habilidades aplicaram: saem no fim do combate.
	local aplicadas: { [string]: { [string]: boolean } } = {}
	-- Janela de Reação (A14); criada depois das utilidades de que precisa.
	local reacoes

	-- Mecânicas das condições do catálogo (id local → mecanica).
	local regrasDeCondicao = {}
	for _, entrada in deps.catalogo.POR_ESPECIE.condition or {} do
		regrasDeCondicao[entrada.sourceId or entrada.data.id] = entrada.data.mecanica
	end

	-- Utilidades -----------------------------------------------------------

	local function limiteDeAcoes(token)
		return math.max(0, (if token.invocado then 1 else ACOES_POR_TURNO) - (Estados.valor(estados, token.id, "perdeAcao") or 0))
	end
	local function deslocamentoDe(token)
		local limite = if token.invocado then token.invocado.movimento else 6
		limite = math.max(0, limite - (Estados.valor(estados, token.id, "reduzMovimento") or 0))
		return if Estados.valor(estados, token.id, "metadeMovimento") then math.floor(limite / 2) else limite
	end
	local function estadoDoTurno(tokenId: string)
		if turnoAtual.tokenId ~= tokenId or turnoAtual.turno ~= combat.turn then
			turnoAtual.tokenId, turnoAtual.turno, turnoAtual.usadas, turnoAtual.acertou = tokenId, combat.turn, 0, false
			turnoAtual.usos, turnoAtual.acertados = {}, {}
		end
		return turnoAtual
	end

	local function temCondicao(token, id: string): boolean
		for _, c in token.conditions or {} do
			if c.id == id then
				return true
			end
		end
		return false
	end

	-- id -> acúmulos (Quebrantado e Dose contam; as demais valem 1).
	local function condicoesDe(token): { [string]: number }
		local mapa = {}
		for _, c in token.conditions or {} do
			mapa[c.id] = c.stacks or 1
		end
		-- O catálogo deixa essa composição apenas em prosa: Inconsciente =
		-- Incapacitado e Caído (Cap. 4). Projeta sem gravar condições derivadas.
		if mapa.inconsciente then
			mapa.incapacitado, mapa.caido = 1, 1
		end
		for _, zona in zonas do if zona.estilo == "nevoa" and zona.casas[deps.cellKey(token.x, token.z)] then mapa.cego = 1 end end
		return mapa
	end

	local function aplicarCondicao(token, id: string, acumulos: number?, nota: string?)
		if temCondicao(token, id) and not (Condicoes.POR_ID[id] and Condicoes.POR_ID[id].acumulavel) then
			return
		end
		local lista = CondicaoRules.add(token.conditions or {}, Condicoes, id, acumulos, nota)
		if lista then
			token.conditions = lista
			aplicadas[token.id] = aplicadas[token.id] or {}
			aplicadas[token.id][id] = true
		end
	end

	local function removerCondicao(token, id: string)
		if not temCondicao(token, id) then
			return
		end
		local stacks = 1
		for _, c in token.conditions do
			if c.id == id then
				stacks = c.stacks or 1
			end
		end
		local lista = CondicaoRules.remove(token.conditions or {}, Condicoes, id, if Condicoes.POR_ID[id] and Condicoes.POR_ID[id].acumulavel then stacks else nil)
		if lista then
			token.conditions = lista
		end
  if fontesCondicao[token.id] then fontesCondicao[token.id][id] = nil end
	end

	-- CA, resistência e defesas de quem é alvo: criatura do bestiário, ficha do site ou sem dados.
	local function defesaDe(token)
		if token.invocado then return token.invocado.ca, function() return token.invocado.bc end, nil, nil end
		if token.criatura and not token.criatura.ca then
			local entrada = deps.catalogo.POR_ID[token.criatura.catalogId]
			if entrada then
				local ficha = Criaturas.ficha(entrada)
				token.criatura = { catalogId = entrada.id, ca = ficha.ca, bonusResistencia = ficha.bonusResistencia, bonusAtaque = ficha.bonusAtaque, patamar = ficha.patamar, papel = ficha.papel, resistencias = ficha.resistencias, imunidades = ficha.imunidades, danoPorTurno = ficha.danoPorTurno, deslocamentoMetros = ficha.deslocamentoMetros, categoria = entrada.data.categoria }
			else
				token.criatura = nil
			end
		end
		if token.criatura then
			local c = token.criatura
			return c.ca, function()
				return c.bonusResistencia
			end, c.resistencias, c.imunidades
		end
		-- Personagem: 1d20 + atributo + metade do maior Bônus de Rank, para cima
		-- (livro; combatSim `metadeDoMaiorRank`). Resistências da ficha: fora da fatia.
		local sheet = token.sheet
		local maiorRank = if token.ficha2 then token.ficha2.calculated.highestRankBonus else 0
		return (sheet and sheet.ca) or 10, function(atributo: string)
			return Estado.resistencia(sheet, maiorRank, atributo)
		end, nil, nil
	end

	-- No Duelo (PvP) só é aliado quem tem o mesmo dono (o personagem e o invocado dele).
	local function aliado(a, b): boolean
		if a == b then
			return false
		end
		local mesmoDono = a.ownerUserId ~= nil and a.ownerUserId ~= 0 and a.ownerUserId == b.ownerUserId
		if deps.emDuelo and deps.emDuelo() then
			return mesmoDono
		end
		return mesmoDono or (a.kind == "jogador" and b.kind == "jogador")
	end
	local function respira(token): boolean
		if token.criatura then
			local entrada = deps.catalogo.POR_ID[token.criatura.catalogId]
			local categoria = entrada and entrada.data.categoria
			return categoria ~= "construto" and categoria ~= "morto-vivo"
		end
		return true
	end
	local function fonteDaCondicao(token, id)
		local fonte = fontesCondicao[token.id] and fontesCondicao[token.id][id]
		if fonte then return fonte end
		for _, c in (token.ficha2 and token.ficha2.session.conditions) or {} do
			if c.conditionId == "condition/" .. id and c.sourceRankBonus then return { rank = c.sourceRankBonus, magica = true } end
		end
		return nil
	end
	local function aflicaoPurgavel(token, rank)
		for _, id in { "envenenado", "petrificado" } do
			local fonte = fonteDaCondicao(token, id)
			if temCondicao(token, id) and fonte and fonte.rank <= rank then return id end
		end
		return nil
	end


 local function lembrarEquipamento(token, item)
  equipamentoOriginal[token.id] = equipamentoOriginal[token.id] or {}
  if equipamentoOriginal[token.id][item] == nil then equipamentoOriginal[token.id][item] = { equipped = item.equipped } end
 end
 local function temBainhas(token)
  return token.ficha2 and table.find(token.ficha2.construction.purchasedIds, "talent/deus-do-norte/Principiante/tres-bainhas") ~= nil
 end
 local function largarArma(token, x, z)
  local item = Desarme.arma(token.ficha2)
  if not item and (not token.criatura or token.criatura.categoria ~= "humanoide") then return nil end
  if item then lembrarEquipamento(token, item); Desarme.largar(item) end
  proximoObjeto += 1
  local objeto = { id = "arma-" .. proximoObjeto, donoId = token.id, item = item, x = x, z = z, nome = if item then item.name else "Arma do inimigo" }
  objetos[objeto.id] = objeto
  Estados.definir(estados, token.id, "desarmado", true, token.id, nil, combat.round)
  if temBainhas(token) then
   -- O talento garante reservas; o exportador não enumera as armas escondidas.
   local reserva
   for _, i in token.ficha2.construction.inventory or {} do
    if i.type == "arma" and not i.a16Indisponivel and i ~= item then reserva = i; break end
   end
   if not reserva then
    reserva = table.clone(item); reserva.sourceLocalId = "a16-reserva-" .. proximoObjeto; reserva.a16Indisponivel = nil
    reserva.equipped = false; reserva.a16Reserva = true
    table.insert(token.ficha2.construction.inventory, reserva)
   end
   lembrarEquipamento(token, reserva); Desarme.pegar(token.ficha2, reserva)
   Estados.remover(estados, token.id, "desarmado")
  end
  return objeto
 end
 local function pegarObjeto(token, objeto)
  if objeto.item then
   for _, item in token.ficha2.construction.inventory or {} do lembrarEquipamento(token, item) end
   Desarme.pegar(token.ficha2, objeto.item)
  end
  objetos[objeto.id] = nil
  Estados.remover(estados, token.id, "desarmado")
  token.version += 1
 end
 local function soltar(alvoId)
  local v = agarrados[alvoId]
  if not v then return end
  local alvo = tokens[alvoId]
  if alvo then
   for id, propria in v.condicoes do if propria then removerCondicao(alvo, id) end end
   alvo.version += 1
  end
  for id in v.condicoes do
   if fontesCondicao[alvoId] then fontesCondicao[alvoId][id] = nil end
  end
  agarrados[alvoId] = nil
 end
 local function limparVinculos()
  for id, v in agarrados do
   local fonte, alvo = tokens[v.sourceId], tokens[id]
   local distancia = if fonte and alvo then Combate.distancia(fonte.x, fonte.z, alvo.x, alvo.z) else math.huge
   local incapaz = false
   if fonte then
    local condsFonte = condicoesDe(fonte)
    if v.sustenta and condsFonte.caido then incapaz = true end
    for cond in condsFonte do if regrasDeCondicao[cond] and regrasDeCondicao[cond].semAcoes then incapaz = true end end
   end
   if not v.sustentaArrasto and (incapaz or not Agarrar.valido(v, fonte, alvo, distancia)) then soltar(id) end
  end
 end
 local function tentarEscapar(token)
  local v = agarrados[token.id]
  if not v then return false end
  local _, bonus = defesaDe(token)
  local desvantagem = false
  for id in condicoesDe(token) do if regrasDeCondicao[id] and regrasDeCondicao[id].desvantagemEmTestes then desvantagem = true end end
  local r = Agarrar.escapar(deps.random, bonus(v.escape), v.cd, desvantagem)
  deps.logAboutToken(token, string.format("%s tenta escapar: %d contra CD %d (%s).", token.name, r.total, r.cd, if r.passou then "escapa" else "preso"))
  if r.passou then soltar(token.id) end
  return r.passou
 end
 local function restaurarEquipamento()
  for id, itens in equipamentoOriginal do
   local token = tokens[id]
   for item, original in itens do item.equipped = original.equipped; item.a16Indisponivel = nil end
   if token then token.a16CaQuebrada = nil end
   if token and token.ficha2 then
    for i = #token.ficha2.construction.inventory, 1, -1 do
     if token.ficha2.construction.inventory[i].a16Reserva then table.remove(token.ficha2.construction.inventory, i) end
    end
   end
  end
  table.clear(equipamentoOriginal); table.clear(objetos); table.clear(quebrados); table.clear(ultimasPosicoes)
  for id in agarrados do soltar(id) end
 end
 local function categoriaMagia(mec)
  local arvore = mec.arvore or Execucao.arvoreDe(mec.idDoLivro or mec.livro or "")
  local entrada = arvore and deps.catalogo.POR_ID["tree/" .. arvore]
  return entrada and entrada.data.category == "magia"
 end
 local function fisicoDeBarreira(mec)
  return (mec.arma or mec.criatura or Reacoes.fisico(mec)) and not categoriaMagia(mec)
 end
	local function protecao(alvo, nome)
		local e = Estados.entrada(estados, alvo.id, nome)
		local fonte = e and tokens[e.fonteId]
		return if fonte and Combate.distancia(alvo.x, alvo.z, fonte.x, fonte.z) <= 2 then e.valor else nil
	end
	local function entradaDeAlvo(alvo, conjurador, mec)
		local ca, resistir, resistencias, imunidades = defesaDe(alvo)
		local cobertura, reduzIgneo = 0, false
		if conjurador then
			for _, casa in Combate.linha(conjurador.x, conjurador.z, alvo.x, alvo.z) do
				for _, zona in zonas do
					if zona.casas[deps.cellKey(casa[1], casa[2])] then
						reduzIgneo = reduzIgneo or zona.reduzIgneo == true
						local fonte = zona.criadorId and tokens[zona.criadorId]
						if fonte and (fonte == alvo or aliado(fonte, alvo)) and mec and mec.tipo == "ataque" then
							local fisico = mec.arma == true
							for _, parte in mec.partes or {} do if parte.tipo == "cortante" or parte.tipo == "perfurante" or parte.tipo == "contundente" then fisico = true end end
							if fisico or not mec.corpoACorpo then cobertura = math.max(cobertura, zona.cobertura or 0) end
						end
					end
				end
			end
		end
		
		return {
			id = alvo.id,
			ca = math.max(1, ca - (alvo.a16CaQuebrada or 0)) + math.max(cobertura, protecao(alvo, "cobertura") or 0, Estados.valor(estados, alvo.id, "coberturaProximoAtaque") or 0),
			reduzIgneo = reduzIgneo,
			respira = respira(alvo),
			antidoto = Estados.valor(estados, alvo.id, "antidoto"),
			marcaPacto = Estados.valor(estados, alvo.id, "marcaPacto"),
			molhadoPor = (fonteDaCondicao(alvo, "molhado") or {}).sourceId,
			condicoes = condicoesDe(alvo),
			resistencia = resistir,
			resistencias = resistencias,
			imunidades = imunidades,
			feridaFresca = Estado.feridaFresca(alvo, conjurador, combat.round),
			patamar = Estado.patamar(alvo),
   acertoDesarmadoAutomatico = conjurador and mec and mec.basico and not mec.armaADistancia and conjurador.ficha2
    and Arma.daFicha(conjurador.ficha2, deps.catalogo).desarmado and agarrados[alvo.id] and not agarrados[alvo.id].sustenta and agarrados[alvo.id].sourceId == conjurador.id,
		}
	end

	local function zonaEm(x: number, z: number, propriedade: string?)
		local chave = deps.cellKey(x, z)
		for _, zona in zonas do
			if zona.casas[chave] and (propriedade == nil or zona[propriedade]) then
				return zona
			end
		end
		return nil
	end

	local function bloqueiaVisao(x: number, z: number): boolean
		return deps.terrain[deps.cellKey(x, z)] == "parede" or zonaEm(x, z, "bloqueiaVisao") ~= nil
	end

	local function bloqueiaProjetil(x: number, z: number): boolean
		return bloqueiaVisao(x, z) or zonaEm(x, z, "bloqueiaProjeteis") ~= nil
	end

 local function alvoDaBarreira(zona)
  local casa = zona.lista[1]
  return { id = "barreira-" .. zona.id, name = "Barreira", x = casa[1], z = casa[2], pv = zona.pv, pvMax = zona.pvMax, conditions = {}, zona = zona }
 end
 local function intercepta(token, alvo, mec)
  local zona = Barreiras.intercepta(zonas, Combate.linha(token.x, token.z, alvo.x, alvo.z), deps.cellKey, fisicoDeBarreira(mec))
  if zona then
   local resultado = alvoDaBarreira(zona)
   for _, casa in Combate.linha(token.x, token.z, alvo.x, alvo.z) do
    if zona.casas[deps.cellKey(casa[1], casa[2])] then resultado.x, resultado.z = casa[1], casa[2]; break end
   end
   return resultado
  end
  return alvo
 end
 local function bloqueioDoAtaque(mec)
  return function(x, z)
   if deps.terrain[deps.cellKey(x, z)] == "parede" then return true end
   for _, zona in zonas do
    if zona.casas[deps.cellKey(x, z)] and zona.bloqueiaVisao and not (zona.pv and fisicoDeBarreira(mec)) then return true end
   end
   return false
  end
 end

	local function ocupada(x: number, z: number, exceto)
		for _, id in deps.tokenOrder do
			local t = tokens[id]
			if t and t ~= exceto and t.x == x and t.z == z and not t.derrotado then
				return t
			end
		end
		return nil
	end

	local function livre(x: number, z: number, exceto): boolean
		return Protocol.isCell(x, z) and not ocupada(x, z, exceto) and deps.terrain[deps.cellKey(x, z)] ~= "parede"
			and zonaEm(x, z, "bloqueiaMovimento") == nil
	end

	-- Quem recebe o recibo: quem vê o conjurador ou algum alvo; ids que o
	-- observador não pode ver saem (D-19: efeito não revela ficha oculta).
	local function enviarRecibo(recibo)
		for _, player in game:GetService("Players"):GetPlayers() do
			local conjurador = recibo.casterId and tokens[recibo.casterId]
			local veConjurador = conjurador ~= nil and deps.canSee(player, conjurador)
			local alvos = {}
			for _, alvo in recibo.alvos do
				local token = tokens[alvo.id]
				if token and deps.canSee(player, token) then
					table.insert(alvos, alvo)
				end
			end
			if veConjurador or #alvos > 0 or recibo.publico then
				local copia = table.clone(recibo)
				copia.casterId = if veConjurador then recibo.casterId else nil
				if not veConjurador then
					copia.origem, copia.centro, copia.direcao, copia.trajeto, copia.encantamento = nil, nil, nil, nil, nil
				end
				copia.alvos = alvos
				deps.remote:FireClient(player, "efeito", copia)
			end
		end
	end

	-- Empurra o alvo para longe de (deX, deZ), casa a casa, até onde houver espaço.
	local function empurrar(alvo, deX: number, deZ: number, casas: number): number
		local dx, dz = Combate.direcao8(alvo.x - deX, alvo.z - deZ)
		if dx == 0 and dz == 0 then
			return 0
		end
		local andou = 0
		local x, z = alvo.x, alvo.z
		for _ = 1, casas do
			local nx, nz = x + dx, z + dz
			if not livre(nx, nz, alvo) then
				break
			end
			x, z = nx, nz
			andou += 1
		end
		if andou > 0 then deps.moverFicha(alvo, x, z) end
		return andou
	end

	local function caminhoLivre(alvo, x, z): boolean
		for _, casa in Combate.linha(alvo.x, alvo.z, x, z) do
			if not livre(casa[1], casa[2], alvo) then return false end
		end
		return true
	end

 local function caminhoDoArrasto(token, x, z, par)
  for _, casa in Combate.linha(token.x, token.z, x, z) do
   if not Protocol.isCell(casa[1], casa[2]) or deps.terrain[deps.cellKey(casa[1], casa[2])] == "parede" or zonaEm(casa[1], casa[2], "bloqueiaMovimento") then return false end
   local ocupante = ocupada(casa[1], casa[2], token)
   if ocupante and ocupante ~= par then return false end
  end
  return true
 end

	local function destinoDoPuxao(alvo, conjurador)
			local melhor, melhorDist = nil, math.huge
			for dx = -1, 1 do
				for dz = -1, 1 do
					local cx, cz = conjurador.x + dx, conjurador.z + dz
					if (dx ~= 0 or dz ~= 0) and livre(cx, cz, alvo) and caminhoLivre(alvo, cx, cz) then
						local d = Combate.distanciaEuclidiana(alvo.x, alvo.z, cx, cz)
						if d < melhorDist then
							melhor, melhorDist = { cx, cz }, d
						end
					end
				end
			end
		return melhor
	end

	local function registrarDuracao(alvo, condicao: string, duracao, conjurador)
		if not duracao or not (aplicadas[alvo.id] and aplicadas[alvo.id][condicao]) then
			return
		end
		for i = #duracoes, 1, -1 do
			if duracoes[i].tokenId == alvo.id and duracoes[i].condicao == condicao then table.remove(duracoes, i) end
		end
		if duracao.rodadas then
			table.insert(duracoes, { tokenId = alvo.id, condicao = condicao, rodadaFim = combat.round + duracao.rodadas })
		else
			local gatilho = if duracao.de == "conjurador" then conjurador.id else alvo.id
			-- A vez em andamento não conta: vale a PRÓXIMA vez do gatilho.
			table.insert(duracoes, { tokenId = alvo.id, condicao = condicao, gatilho = gatilho, estado = "aplicada" })
		end
	end

	-- Aplica um efeito resolvido; devolve o texto do registro.
	local function aplicarEfeito(alvo, efeito, conjurador, mec): string
		local partes = {}
  if alvo.zona then
   local zona = alvo.zona
   local caiu = Barreiras.ferir(zona, efeito.dano and efeito.dano.total or 0)
   if caiu then for i, z in zonas do if z == zona then table.remove(zonas, i); break end end end
   return string.format("Barreira: %d/%d PV%s", zona.pv, zona.pvMax, if caiu then " (destruída)" else "")
  end
  local secou = efeito.dano and efeito.dano.total > 0 and (efeito.dano.danoIgneo or 0) > 0 and temCondicao(alvo, "molhado")
		if secou then removerCondicao(alvo, "molhado"); table.insert(partes, "o fogo seca Molhado") end
		if efeito.dano then
			local dano = efeito.dano.total
			if dano > 0 then
				local guarda = Estados.entrada(estados, alvo.id, "guarda")
				local protetor = guarda and tokens[guarda.fonteId]
				if protetor and protetor.ptMax then protetor.pt = math.min(protetor.ptMax, (protetor.pt or 0) + 1); protetor.version += 1 end
				sequencia += 1
				alvo.ultimoDano = sequencia
			end
			if not (mec and mec.sangria) and (alvo.pvTemp or 0) > 0 and dano > 0 then
				local absorvido = math.min(alvo.pvTemp, dano)
				alvo.pvTemp -= absorvido
				dano -= absorvido
				table.insert(partes, string.format("PV temporários absorvem %d", absorvido))
			end
			local antes = alvo.pv
			alvo.pv = math.max(0, alvo.pv - dano)
			table.insert(partes, string.format("%d de dano %s(PV %d → %d)", dano, if efeito.dano.tipo then efeito.dano.tipo .. " " else "", antes, alvo.pv))
			if not alvo.criatura and not alvo.invocado and efeito.dano.tipo then
				table.insert(partes, "resistências da ficha não aplicadas nesta versão")
			end
			-- Sono (Rosa-Preta): sofrer dano acorda.
			if dano > 0 and alvo.dormindo and temCondicao(alvo, "inconsciente") then
				removerCondicao(alvo, "inconsciente")
				alvo.dormindo = nil
				table.insert(partes, "acorda com o golpe")
			end
		end
		if efeito.cura then
			local antes = alvo.pv
			alvo.pv = math.min(alvo.pvMax, alvo.pv + efeito.cura)
			table.insert(partes, string.format("recupera %d PV (PV %d → %d)", alvo.pv - antes, antes, alvo.pv))
			if alvo.pv > 0 and temCondicao(alvo, "caido") and antes == 0 then
				removerCondicao(alvo, "caido")
				table.insert(partes, "levanta")
			end
		end
		if efeito.pvTemp then
			-- Não acumulam com outra fonte: fica o maior.
			if efeito.pvTemp >= (alvo.pvTemp or 0) then
				alvo.pvTemp = efeito.pvTemp
				alvo.pvTempAte = combat.round + (mec.duracaoRodadas or 100)
			end
			table.insert(partes, string.format("ganha %d PV temporários", efeito.pvTemp))
		end
		for _, id in efeito.remove or {} do
			if temCondicao(alvo, id) then
				removerCondicao(alvo, id)
				if id == "dose" and fontesCondicao[alvo.id] and fontesCondicao[alvo.id].envenenado then removerCondicao(alvo, "envenenado") end
				local entrada = Condicoes.POR_ID[id]
				table.insert(partes, "perde " .. (if entrada then entrada.nome else id))
			end
		end
		if efeito.doses then
			if not Estados.valor(estados, alvo.id, "antidoto") and respira(alvo) then
				local antes = condicoesDe(alvo).dose or 0
				aplicarCondicao(alvo, "dose", efeito.doses)
				if antes + efeito.doses >= 3 then
					aplicadas[alvo.id] = aplicadas[alvo.id] or {}; aplicadas[alvo.id].atordoado = true
					removerCondicao(alvo, "envenenado")
					registrarDuracao(alvo, "atordoado", { de = "alvo" }, conjurador)
				elseif antes + efeito.doses >= 2 then
					aplicarCondicao(alvo, "envenenado")
					fontesCondicao[alvo.id] = fontesCondicao[alvo.id] or {}
					fontesCondicao[alvo.id].envenenado = { sourceId = conjurador.id, rank = 1 }
				end
			end
			table.insert(partes, string.format("recebe %d Dose(s)", efeito.doses))
		end
  if mec and mec.escape and efeito.aplica and table.find(efeito.aplica, "agarrado") then
   local conds = {}
   for _, id in efeito.aplica do conds[id] = not temCondicao(alvo, id) end
   agarrados[alvo.id] = { sourceId = conjurador.id, cd = efeito.cdEscape or (efeito.resistencia and efeito.resistencia.cd) or 8,
    escape = mec.escape, sustenta = mec.sustenta, condicoes = conds }
  end
  if (efeito.desarmar and efeito.ataque and efeito.ataque.acertou) or (mec and mec.desarmarManobra and efeito.cdEscape and efeito.disputaVenceu) then
   local x, z = alvo.x, alvo.z
   -- Cap. 4 §6: cai a 1,5 m; borda/parede usa a própria casa.
   if Protocol.isCell(x + 1, z) and deps.terrain[deps.cellKey(x + 1, z)] ~= "parede" then x += 1 end
   local objeto = largarArma(alvo, x, z)
   if mec.corteBraco and Estado.patamar(alvo) < (Regras.bonusDeRank.Santo or 4) then
    Estados.definir(estados, alvo.id, "bracoInutil", true, conjurador.id, { de = "alvo" }, combat.round)
   end
   table.insert(partes, if objeto then "larga a arma" else "sem arma representada para largar")
  end
  if mec and mec.quebrarEquipamento and efeito.resistencia and not efeito.resistencia.passou then
   local item = Desarme.equipamento(alvo.ficha2, mec.escolhaEquipamento)
   if item then
    lembrarEquipamento(alvo, item); Desarme.largar(item)
    if item.armorClassBonus then alvo.a16CaQuebrada = (alvo.a16CaQuebrada or 0) + item.armorClassBonus end
   end
   quebrados[alvo.id] = true
   if not item or item.type == "arma" then Estados.definir(estados, alvo.id, "desarmado", true, alvo.id, nil, combat.round) end
   table.insert(partes, "equipamento quebrado até o descanso automático")
  end
  if mec and mec.estancar then
   local fonte = fonteDaCondicao(alvo, "em-chamas")
   if temCondicao(alvo, "em-chamas") and not (fonte and fonte.magica) then removerCondicao(alvo, "em-chamas"); table.insert(partes, "apaga fogo não mágico") end
   if Estados.valor(estados, alvo.id, "sangramento") then Estados.remover(estados, alvo.id, "sangramento"); table.insert(partes, "estanca sangramento") end
  end
  if mec and mec.sangria then
   removerCondicao(alvo, mec.aflicao)
   table.insert(partes, "purga " .. mec.aflicao)
  end

		for _, id in efeito.aplica or {} do
			if secou and id == "em-chamas" then continue end
			aplicarCondicao(alvo, id)
			if id == "inconsciente" and mec and mec.sono then
				alvo.dormindo = true
			end
			registrarDuracao(alvo, id, mec and mec.duracao, conjurador)
			local entrada = Condicoes.POR_ID[id]
			table.insert(partes, "fica " .. (if entrada then entrada.nome else id))
		end
		for _, e in efeito.estados or {} do
			Estados.definir(estados, alvo.id, e.nome, e.valor, conjurador.id, e.duracao, combat.round)
			table.insert(partes, e.nome)
		end
		if efeito.quebrantado and conjurador then
			local atuais = condicoesDe(alvo).quebrantado or 0
			local teto = efeito.quebrantado
			if atuais < teto then aplicarCondicao(alvo, "quebrantado", teto - atuais) end
		end
		for _, id in efeito.aplica or {} do
			if conjurador and temCondicao(alvo, id) then
				fontesCondicao[alvo.id] = fontesCondicao[alvo.id] or {}
				fontesCondicao[alvo.id][id] = { sourceId = conjurador.id, rank = if conjurador.invocado then conjurador.invocado.rank else Execucao.bonusDeRankDa(conjurador.ficha2, Execucao.arvoreDe(mec.idDoLivro or mec.livro or "")), cd = 8 + (if conjurador.invocado then conjurador.invocado.bc else Execucao.bc(conjurador.ficha2, Execucao.arvoreDe(mec.idDoLivro or mec.livro or ""), deps.catalogo)), escape = mec.escape, arrasta = mec.arrasta, sustenta = mec.sustenta, magica = categoriaMagia(mec) == true }
			end
		end
		if mec and mec.purga and not efeito.dano then
			local id = aflicaoPurgavel(alvo, mec.purga)
			if id then removerCondicao(alvo, id); table.insert(partes, "purga " .. id) end
		end
		if mec and mec.armaTemporaria then
			Estados.definir(estados, alvo.id, "armaGelo", true, conjurador.id, { rodadas = 10 }, combat.round)
			table.insert(partes, "empunha Lâmina de Gelo")
		end
		if mec and mec.guarda and conjurador then
			if mec.designaGuarda then
				local anterior = reacoes.designadoDe(conjurador.id)
				local e = anterior and Estados.entrada(estados, anterior, "guarda")
				if e and e.fonteId == conjurador.id and anterior ~= alvo.id then Estados.remover(estados, anterior, "guarda") end
				reacoes.designar(conjurador, alvo)
			end
			Estados.definir(estados, alvo.id, "guarda", true, conjurador.id, nil, combat.round)
			table.insert(partes, "fica Sob Sua Guarda (" .. conjurador.name .. " pode Interpor)")
		end
		-- Marcas de estado (Selar a Ferida).
		if mec and mec.marca and not efeito.ataque then
			alvo[mec.marca] = true
			if mec.marca == "feridaSelada" then alvo.feridaSeladaAte = combat.round + 600 end
			table.insert(partes, mec.marcaTexto or "marcado")
		end
		-- Puxar (Cavalaria): o aliado vem para uma casa vizinha de quem puxa.
		if mec and mec.puxar and conjurador and alvo ~= conjurador then
			local melhor = destinoDoPuxao(alvo, conjurador)
			if melhor then
				deps.moverFicha(alvo, melhor[1], melhor[2])
				table.insert(partes, "é puxado para uma casa adjacente a quem puxou")
			end
		end
		if efeito.empurrar and conjurador then
			local andou = empurrar(alvo, conjurador.x, conjurador.z, efeito.empurrar)
			table.insert(partes, string.format("é empurrado %d casa(s)", andou))
		end
		alvo.version += 1
		if alvo.pv == 0 and efeito.dano then
			if alvo.boneco then
				table.insert(partes, "cai (e levanta inteiro: é um boneco de treino)")
				alvo.derrotado = true
				deps.reviverBoneco(alvo)
			elseif alvo.invocado then
				pactosExaustos[alvo.invocado.sourceId .. ":" .. alvo.invocado.pactoId] = true
				alvo.derrotado = true
				deps.removerFicha(alvo.id)
			elseif alvo.criatura then
				table.insert(partes, "é derrotado")
				alvo.derrotado = true
				task.delay(2.5, function()
					if tokens[alvo.id] == alvo then
						deps.removerFicha(alvo.id)
					end
				end)
			elseif not temCondicao(alvo, "caido") then
				aplicarCondicao(alvo, "caido")
				table.insert(partes, "cai a 0 PV; precisa de cura antes de agir")
			end
		end
		limparVinculos()
		return table.concat(partes, ", ")
	end

	local function textoDoAtaque(a: Combate.Ataque): string
		local dado = if #a.d20.dados > 1 then string.format("d20 [%s] (%s)", table.concat(a.d20.dados, ", "), a.d20.ajuste) else "d20 " .. a.d20.natural
		local veredito = if a.critico then "CRÍTICO" elseif a.acertou then "acerta" elseif a.d20.natural == 1 then "falha (1 natural)" else "erra"
		return string.format("%s %+d = %d contra CA %d: %s", dado, a.bonus, a.total, a.defesa, veredito)
	end

	local function textoDoTeste(r: Combate.Resistencia): string
		return string.format("teste d20 %d %+d = %d contra CD %d: %s", r.d20.natural, r.bonus, r.total, r.cd, if r.passou then "resiste" else "falha")
	end

	local function resumoDoEfeito(efeito)
		local alvo = tokens[efeito.alvoId]
		local disparos
		if efeito.segundoAtaque then
			disparos = {}
			for i, ataque in { efeito.ataque, efeito.segundoAtaque } do
				table.insert(disparos, { id = efeito.alvoId, acertou = ataque.acertou, critico = ataque.critico, dano = efeito.danosDisparos and efeito.danosDisparos[i] or 0 })
			end
		end
		return {
			casa = alvo and { alvo.x, alvo.z } or nil,
			disparos = disparos,
			id = efeito.alvoId,
			acertou = if efeito.ataque then efeito.ataque.acertou or (efeito.segundoAtaque ~= nil and efeito.segundoAtaque.acertou) else nil,
			critico = if efeito.ataque then efeito.ataque.critico or (efeito.segundoAtaque ~= nil and efeito.segundoAtaque.critico) else nil,
			natural = if efeito.ataque then efeito.ataque.d20.natural elseif efeito.resistencia then efeito.resistencia.d20.natural else nil,
			passou = if efeito.resistencia then efeito.resistencia.passou else nil,
			dano = if efeito.dano then efeito.dano.total else nil,
			cura = efeito.cura or efeito.pvTemp,
			aplica = if efeito.aplica then efeito.aplica[1] else nil,
		}
	end

	-- Reações (A14): Aparar, Guarda do Corpo, Couraça de Barro, Parede de
	-- Emergência, Bloquear com Escudo, Interpor e o Fluxo. Ver ReacoesService.
	local function semAcoes(token): boolean
		for id in condicoesDe(token) do
			if regrasDeCondicao[id] and regrasDeCondicao[id].semAcoes then
				return true
			end
		end
		return false
	end
	local contraAtacar
	reacoes = ReacoesService.novo({
		tokens = tokens, combat = combat, remote = deps.remote, random = deps.random, catalogo = deps.catalogo, handlers = handlers,
		condicoesDe = condicoesDe, semAcoes = semAcoes, aliado = aliado, logAboutToken = deps.logAboutToken,
		visivel = function(a, b) return Combate.temVisao(a.x, a.z, b.x, b.z, bloqueiaVisao) end,
		guardaDe = function(alvo) local e = Estados.entrada(estados, alvo.id, "guarda"); return e and e.fonteId end,
		contraAtacar = function(reator, atacante) contraAtacar(reator, atacante) end,
	})
	-- Reações depois da rolagem e o dano interceptado (Interpor); devolve o texto extra.
	local function reagirAoGolpe(atacante, alvo, efeito, mec): string
		local textos = {}
		for _, extra in reacoes.aposRolagem(atacante, alvo, efeito, mec) do
			local t = aplicarEfeito(extra.token, extra.efeito, atacante, nil)
			table.insert(textos, extra.token.name .. ": " .. t)
			table.insert(extra.efeito.notas, 1, t)
		end
		return table.concat(textos, "; ")
	end
	-- Fluxo: golpe corpo a corpo comum com a arma, com rolagem de acerto.
	contraAtacar = function(reator, atacante)
		local mec = table.clone(Execucao.MECANICAS["mesa/ataque-basico"])
		mec.idDoLivro = "mesa/ataque-basico"
		local arvore = Execucao.arvoreDeCorpo(reator.ficha2, deps.catalogo)
		local a = Arma.daFicha(reator.ficha2, deps.catalogo, false)
		local conjurador = {
			id = reator.id, bc = Execucao.bc(reator.ficha2, arvore, deps.catalogo), pv = reator.pv, pvMax = reator.pvMax,
			condicoes = condicoesDe(reator), atributos = reator.ficha2.calculated.attributes,
			arma = { dado = a.dado, bonus = Execucao.atributoDaArma(arvore, a.atributo, reator.ficha2, deps.catalogo) + a.bonusDeRank, nome = a.nome },
			bonusDeRank = Execucao.bonusDeRankDa(reator.ficha2, arvore),
		}
		if deps.virarPara then deps.virarPara(reator, atacante.x, atacante.z) end
		local efeito = Habilidades.resolver(deps.random, mec, conjurador, { entradaDeAlvo(atacante, reator, mec) }, regrasDeCondicao)[1]
		local extra = reagirAoGolpe(reator, atacante, efeito, mec)
		local texto = aplicarEfeito(atacante, efeito, reator, mec)
		deps.logAboutToken(atacante, string.format("Fluxo de %s em %s (%s): %s%s%s%s", reator.name, atacante.name, a.nome, textoDoAtaque(efeito.ataque),
			if texto ~= "" then " — " .. texto else "", if #efeito.notas > 0 then " (" .. table.concat(efeito.notas, "; ") .. ")" else "",
			if extra ~= "" then "; " .. extra else ""))
		enviarRecibo({ habilidadeId = "mesa/ataque-basico", casterId = reator.id, origem = { reator.x, reator.z }, alvos = { resumoDoEfeito(efeito) }, arma = a.nome, publico = true })
		reacoes.aposAplicar(reator, atacante, efeito, mec)
	end

	-- Recursos da ficha: PM no token (mana); PT guardado à parte, vindo da ficha.
	local function iniciarPT(token)
		if token.ptMax == nil and token.ficha2 then
			token.ptMax = token.ficha2.calculated.maxima.pt
			token.pt = token.ficha2.session.current.pt
		end
	end

	-- Geometria dos alvos ---------------------------------------------------

	local function visivel(player, alvo): boolean
		return type(alvo) == "table" and deps.canSee(player, alvo) and not alvo.derrotado
	end

	local function alvosDaMecanica(player, token, mec, payload): ({ any }?, string?, { any }?)
		local forma = mec.alvo or "unico"
		local alvos = {}
		local info = {}
		local bloqueio = if mec.tipo == "ataque" then bloqueioDoAtaque(mec) else bloqueiaVisao
		if forma == "si" then
			return { token }, nil, info
		elseif forma == "lista" or forma == "disparos" then
			local ids = payload.alvoIds or { payload.alvoId }
			if type(ids) ~= "table" or #ids == 0 or #ids > mec.maxAlvos then return nil, "Informe a lista de alvos." end
			local count, vistos = 0, {}
			for k in ids do count += 1; if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > #ids then return nil, "Lista inválida." end end
			if count ~= #ids then return nil, "Lista inválida." end
			for _, id in ids do
				if type(id) ~= "string" or vistos[id] then return nil, "Alvo inválido ou repetido." end
				vistos[id] = true
				local outro = tokens[id]
				if not visivel(player, outro) or (outro == token and not mec.permiteSi) or Combate.distancia(token.x, token.z, outro.x, outro.z) > mec.alcanceCasas or not Combate.temVisao(token.x, token.z, outro.x, outro.z, bloqueio) then return nil, "Alvo invisível ou fora de alcance." end
				table.insert(alvos, outro)
			end
			return alvos, nil, info
		elseif forma == "unico" then
			local alvo = type(payload.alvoId) == "string" and tokens[payload.alvoId]
   if not alvo and mec.basico and mec.tipo == "ataque" and Protocol.isCell(payload.x, payload.z) then
    local zona = zonaEm(payload.x, payload.z)
    if zona and zona.pv then alvo = alvoDaBarreira(zona); alvo.x, alvo.z = payload.x, payload.z end
   end
   if not (alvo and alvo.zona) and not visivel(player, alvo) then
				return nil, "Escolha um alvo visível."
			end
			if mec.soAliados and alvo ~= token and not aliado(token, alvo) then return nil, "Escolha um aliado." end
			if alvo == token and mec.tipo ~= "cura" and not mec.permiteSi then
				return nil, "Escolha outro alvo."
			end
			local alcance = if mec.corpoACorpo then 1 else (mec.alcanceCasas or 1)
			local distancia = Combate.distancia(token.x, token.z, alvo.x, alvo.z)
			if distancia > alcance then
				return nil, string.format("Fora de alcance: %d casa(s); o alcance é %d.", distancia, alcance)
			end
			if alvo ~= token and not Combate.temVisao(token.x, token.z, alvo.x, alvo.z, bloqueio) then
				return nil, "Sem linha de visão até o alvo."
			end
			if mec.puxar and not destinoDoPuxao(alvo, token) then return nil, "Não há caminho livre para puxar o alvo." end
			return { if mec.tipo == "ataque" and not alvo.zona then intercepta(token, alvo, mec) else alvo }, nil, info
		end
		local function considerar(outro, cx, cz)
			return outro ~= token and not outro.derrotado and (not mec.soAliados or aliado(token, outro)) and Combate.temVisao(cx, cz, outro.x, outro.z, bloqueiaVisao)
		end
		if forma == "esferaNoConjurador" then
			for _, id in deps.tokenOrder do
				local outro = tokens[id]
				if considerar(outro, token.x, token.z) and Combate.distanciaEuclidiana(token.x, token.z, outro.x, outro.z) <= mec.raioCasas then
					table.insert(alvos, outro)
				end
			end
			info.centro = { token.x, token.z }
		elseif forma == "adjacentes" then
			for _, id in deps.tokenOrder do
				local outro = tokens[id]
				if outro ~= token and not outro.derrotado and Combate.distancia(token.x, token.z, outro.x, outro.z) == 1 then
					table.insert(alvos, outro)
				end
			end
			info.centro = { token.x, token.z }
		elseif forma == "esferaNaCasa" or forma == "cone" then
			local x, z = payload.x, payload.z
			if not Protocol.isCell(x, z) then
				return nil, "Escolha uma casa no tabuleiro."
			end
			if forma == "esferaNaCasa" then
				if Combate.distancia(token.x, token.z, x, z) > (mec.alcanceCasas or 0) then
					return nil, "Casa fora de alcance."
				end
				if not Combate.temVisao(token.x, token.z, x, z, bloqueiaVisao) then
					return nil, "Sem linha de visão até a casa."
				end
				for _, id in deps.tokenOrder do
					local outro = tokens[id]
					if outro ~= token and not outro.derrotado and Combate.distanciaEuclidiana(x, z, outro.x, outro.z) <= mec.raioCasas
						and Combate.temVisao(x, z, outro.x, outro.z, bloqueiaVisao) then
						table.insert(alvos, outro)
					end
				end
				info.centro = { x, z }
			else
				-- Cone: até o comprimento, dentro de 45° da direção escolhida.
				local dx, dz = x - token.x, z - token.z
				if dx == 0 and dz == 0 then
					return nil, "Escolha a direção do cone."
				end
				local direcao = Vector2.new(dx, dz).Unit
				for _, id in deps.tokenOrder do
					local outro = tokens[id]
					if considerar(outro, token.x, token.z) then
						local v = Vector2.new(outro.x - token.x, outro.z - token.z)
						if Combate.distancia(token.x, token.z, outro.x, outro.z) <= mec.comprimentoCasas and v.Magnitude > 0 and v.Unit:Dot(direcao) >= math.cos(math.rad(45)) - 1e-6 then
							table.insert(alvos, outro)
						end
					end
				end
				info.centro = { token.x, token.z }
				info.direcao = { dx, dz }
			end
			if mec.maxAlvos and #alvos > mec.maxAlvos then
				table.sort(alvos, function(a, b)
					return Combate.distanciaEuclidiana(info.centro[1], info.centro[2], a.x, a.z) < Combate.distanciaEuclidiana(info.centro[1], info.centro[2], b.x, b.z)
				end)
				while #alvos > mec.maxAlvos do
					table.remove(alvos)
				end
			end
		end
		return alvos, nil, info
	end

	-- Casas de uma zona, pela forma.
	local function casasDaZona(token, mec, payload): ({ { number } }?, string?)
		local forma = mec.forma or "linhaDoConjurador"
		local casas = {}
		local function pode(x, z)
			return Protocol.isCell(x, z) and deps.terrain[deps.cellKey(x, z)] ~= "parede"
		end
		if forma == "esferaNoConjurador" then
			for x = token.x - mec.raioCasas, token.x + mec.raioCasas do
				for z = token.z - mec.raioCasas, token.z + mec.raioCasas do
					if pode(x, z) and Combate.distanciaEuclidiana(token.x, token.z, x, z) <= mec.raioCasas then
						table.insert(casas, { x, z })
					end
				end
			end
			return casas, nil
		end
		local x, z = payload.x, payload.z
		if not Protocol.isCell(x, z) or (x == token.x and z == token.z) then
			return nil, "Escolha uma casa no tabuleiro."
		end
		if forma == "linhaDoConjurador" then
			local dx, dz = Combate.direcao8(x - token.x, z - token.z)
			for _, casa in Combate.linha(token.x, token.z, token.x + dx * mec.comprimentoCasas, token.z + dz * mec.comprimentoCasas) do
				if #casas >= mec.comprimentoCasas or not pode(casa[1], casa[2]) then
					break
				end
				table.insert(casas, casa)
			end
		elseif forma == "linhaTransversal" then
			-- Centro na casa escolhida, perpendicular à direção conjurador → casa.
			if Combate.distancia(token.x, token.z, x, z) > (mec.alcanceCasas or 1) then
				return nil, "Casa fora de alcance."
			end
			local dx, dz = Combate.direcao8(x - token.x, z - token.z)
			local px, pz = -dz, dx
			local metade = (mec.comprimentoCasas - 1) / 2
			for i = -math.floor(metade), math.ceil(metade) do
				local cx, cz = x + px * i, z + pz * i
				if pode(cx, cz) then
					table.insert(casas, { cx, cz })
				end
			end
		end
		if #casas == 0 then
			return nil, "Não há espaço para isso nessa direção."
		end
		return casas, nil
	end

	local function criarInvocado(conjurador, pactoId, lugar)
		local pacto = Execucao.PACTOS[pactoId]
		local rank = Execucao.bonusDeRankDa(conjurador.ficha2, "invocacao")
		local bc = Execucao.bc(conjurador.ficha2, "invocacao", deps.catalogo)
		local firme = table.find(conjurador.ficha2.construction.purchasedIds, "talent/invocacao/Principiante/pacto-firmado") ~= nil
		local pvMax = 10 * (rank + 1)
		local id = "pacto-" .. HttpService:GenerateGUID(false)
		local invocado = { id = id, name = pacto.nome, kind = "jogador", ownerUserId = conjurador.ownerUserId,
			x = lugar[1], z = lugar[2], pvMax = pvMax, pv = if firme then pvMax else math.floor(pvMax / 2), mana = 0, manaMax = 0,
			hidden = conjurador.hidden, showStats = true, color = Color3.fromRGB(155, 181, 217), version = 1, conditions = {},
			invocado = { sourceId = conjurador.id, pactoId = pactoId, ca = 10 + rank, bc = bc, rank = rank, metadeDano = not firme, movimento = pacto.movimento or 6, rodadaFim = combat.round + 600 },
		}
		tokens[id] = invocado
		table.insert(deps.tokenOrder, id)
		table.insert(combat.order, math.min(#combat.order + 1, (combat.turnIndex or 1) + 1), id)
		invocados[conjurador.id] = id
		return invocado
	end

	-- Comando: usar habilidade --------------------------------------------

	handlers.usarHabilidade = function(player, payload, master)
		if type(payload) ~= "table" then return "Pedido inválido." end
		local token = type(payload.tokenId) == "string" and tokens[payload.tokenId]
		if not token or not deps.canSee(player, token) then
			return "Ficha não encontrada."
		end
		if not master and token.ownerUserId ~= player.UserId then
			return "Você só usa habilidades da sua ficha."
		end
		if not combat.active then
			return "Inicie o combate (iniciativa) para usar habilidades."
		end
		if reacoes.pendente() then
			return "Aguarde: alguém está decidindo uma Reação."
		end
		if deps.currentTurnId() ~= token.id then
			return "Aguarde a vez dessa ficha."
		end
		if token.pv <= 0 then
			return "Ficha caída não age."
		end
		for id in condicoesDe(token) do
			local m = regrasDeCondicao[id]
			if m and m.semAcoes then
				local entrada = Condicoes.POR_ID[id]
				return (if entrada then entrada.nome else id) .. ": sem Ações neste turno."
			end
		end
		local id = payload.habilidadeId
  if type(id) ~= "string" or #id > 160 then return "Habilidade inválida." end
  limparVinculos()
  local controle = type(id) == "string" and Execucao.MECANICAS[id] and Execucao.MECANICAS[id].controleA16
  if controle then
   local turno = estadoDoTurno(token.id)
   local custo = if controle == "soltar" then 0 else 1
   if turno.usadas + custo > limiteDeAcoes(token) then return "Sem Ação para esse controle." end
   if controle == "escapar" then
    if not agarrados[token.id] then return "Não está em um agarrão executável." end
    turno.usadas += 1; tentarEscapar(token)
   elseif controle == "soltar" then
    local achou = false
    for alvoId, v in agarrados do if v.sourceId == token.id then soltar(alvoId); achou = true end end
    if not achou then return "Não sustenta agarrão." end
   elseif controle == "pegar-arma" then
    if not Protocol.isCell(payload.x, payload.z) or Combate.distancia(token.x, token.z, payload.x, payload.z) > 1 then return "Arma fora de alcance." end
    if Estados.valor(estados, token.id, "bracoInutil") then return "Braço inutilizado: não pode pegar a arma." end
    local objeto
    for _, o in objetos do if o.donoId == token.id and o.x == payload.x and o.z == payload.z then objeto = o; break end end
    if not objeto then return "Sem arma sua nessa casa." end
    if not Combate.temVisao(token.x, token.z, payload.x, payload.z, bloqueiaVisao) then return "Sem acesso à arma." end
    turno.usadas += 1; pegarObjeto(token, objeto)
   elseif controle == "arrastar" then
    local alvo, v
    for alvoId, vinculo in agarrados do if vinculo.sourceId == token.id then alvo, v = tokens[alvoId], vinculo; break end end
    if not alvo or not Protocol.isCell(payload.x, payload.z) then return "Escolha o destino do alvo agarrado." end
    local d = Combate.distancia(alvo.x, alvo.z, payload.x, payload.z)
    if d == 0 or d > 2 or turno.usos[id] then return "Arrastar: até 3 m, uma vez por turno." end
    if not caminhoDoArrasto(alvo, payload.x, payload.z, if v.sustenta then nil else token) then return "Caminho do alvo bloqueado." end
    local nx, nz = token.x + payload.x - alvo.x, token.z + payload.z - alvo.z
    if not v.sustenta and (condicoesDe(token).agarrado or condicoesDe(token).atolado or Estados.valor(estados, token.id, "imovel") or not caminhoDoArrasto(token, nx, nz, alvo)) then return "Não há espaço para arrastar junto." end
    turno.usadas += 1; turno.usos[id] = true
    -- Movimento simultâneo: evita soltar entre os dois movimentos.
    v.sustentaArrasto = true
    if not v.sustenta then deps.moverFicha(token, nx, nz) end
    deps.moverFicha(alvo, payload.x, payload.z)
    v.sustentaArrasto = nil
    limparVinculos()
   end
   token.version += 1
   deps.logAboutToken(token, token.name .. " usa " .. Execucao.MECANICAS[id].nome .. ".")
   enviarRecibo({ habilidadeId = id, casterId = token.id, origem = { token.x, token.z }, alvos = {} })
   return nil
  end

		if token.invocado then
			local dados = token.invocado
			local pacto = Execucao.PACTOS[dados.pactoId]
			local turno = estadoDoTurno(token.id)
			if turno.usadas >= limiteDeAcoes(token) then return "Invocado tem 1 Ação por turno (reduzida pelos efeitos)." end
			if id ~= "invocado/ataque" and id ~= "invocado/ajudar" and id ~= "invocado/derrubar" then return "Ação de Pacto inválida." end
			if (id == "invocado/ataque" and pacto.ajuda) or (id == "invocado/ajudar" and not pacto.ajuda) or (id == "invocado/derrubar" and not pacto.derruba) then return "Esse Pacto não tem essa ação." end
			local alvo = type(payload.alvoId) == "string" and tokens[payload.alvoId]
			if not visivel(player, alvo) or alvo == token or Combate.distancia(token.x, token.z, alvo.x, alvo.z) > 1 then return "Escolha uma ficha adjacente visível." end
			turno.usadas += 1
			local recibo = { habilidadeId = id, casterId = token.id, origem = { token.x, token.z }, alvos = {} }
			if id == "invocado/ajudar" then
				Estados.definir(estados, alvo.id, if pacto.marca then "marcaPacto" else "auxilio", true, token.id, { rodadas = 1 }, combat.round)
				table.insert(recibo.alvos, { id = alvo.id })
				deps.logAboutToken(alvo, alvo.name .. " recebe ajuda de Pacto")
			else
				local m = { tipo = "ataque", corpoACorpo = true, partes = if id == "invocado/ataque" then { { dados = pacto.dados } } else {}, aplica = if id == "invocado/derrubar" then "caido" else nil }
				local c = { bc = dados.bc, pv = token.pv, pvMax = token.pvMax, condicoes = condicoesDe(token) }
				local e = Habilidades.resolver(deps.random, m, c, { entradaDeAlvo(alvo) }, regrasDeCondicao)[1]
				if e.dano and dados.metadeDano then e.dano.total = math.floor(e.dano.total / 2) end
				deps.logAboutToken(alvo, alvo.name .. ": " .. aplicarEfeito(alvo, e, token, m))
				table.insert(recibo.alvos, resumoDoEfeito(e))
			end
			token.version += 1; alvo.version += 1
			enviarRecibo(recibo)
			return nil
		end
		local mec = type(id) == "string" and Execucao.MECANICAS[id]
		if Execucao.INDISPONIVEIS[id] then return Execucao.INDISPONIVEIS[id] end
		if mec and mec.exigeArmaGelo and not Estados.valor(estados, token.id, "armaGelo") then
			return "Conjure a Lâmina de Gelo antes de atacar com ela."
		end
		if not mec or not token.ficha2 or (not mec.exigeArmaGelo and not mec.basico and not table.find(Execucao.habilidadesDe(token.ficha2, deps.catalogo), mec.exigeHabilidade or id)) then
			return "Essa ficha não tem essa habilidade."
		end
		if mec.exigeRank and not Progressao.rankAberto(token.ficha2.construction, mec.exigeRank, "Principiante") then
			return "Essa ficha não tem essa habilidade."
		end
		mec = table.clone(mec); mec.idDoLivro = id
		if mec.escolhasPacto and table.find(token.ficha2.construction.purchasedIds, "talent/invocacao/Principiante/invocacao-de-emergencia") then mec = table.clone(mec); mec.pm = 4 end
		if Estados.valor(estados, token.id, "silenciado") then
			local arv = deps.catalogo.POR_ID["tree/" .. (Execucao.arvoreDe(id) or "")]
			if arv and arv.data.category == "magia" then return "Silenciado: não recita cânticos." end
		end
		if (mec.arma or mec.exigeMao) and Estados.valor(estados, token.id, "bracoInutil") then return "Braço inutilizado: não usa arma." end
		if mec.exigeTalento and not table.find(token.ficha2.construction.purchasedIds, mec.exigeTalento) then return "Falta o talento exigido." end
		if mec.exigeEscudo then
			local tem = Reacoes.escudo(token.ficha2) ~= nil
			if not tem then return "Equipe um escudo para essa técnica." end
		end
		local quantidadeObjetos = 0; for _ in objetos do quantidadeObjetos += 1 end
  if (mec.desarmaConjurador or mec.corteBraco or mec.desarmarManobra) and quantidadeObjetos >= 60 then return "Limite de armas no chão atingido: recupere uma." end
  if mec.desarmaConjurador and not Desarme.arma(token.ficha2) then return "Equipe uma arma para arremessar." end
  if mec.arma and (mec.desarmaConjurador or Estados.valor(estados, token.id, "desarmado")) and not Desarme.arma(token.ficha2) then
   local punhos = Arma.daFicha(token.ficha2, deps.catalogo).desarmado
   if not (mec.basico and not mec.armaADistancia and punhos) then return "Desarmado: recupere a arma antes dessa técnica." end
  end
  mec.escolhaEquipamento = mec.equipamento or payload.equipamento or "arma"
  if mec.quebrarEquipamento and mec.escolhaEquipamento ~= "arma" and mec.escolhaEquipamento ~= "escudo" then return "Equipamento inválido." end
  local turno = estadoDoTurno(token.id)
		local totalAcoes = limiteDeAcoes(token)
		if turno.usadas + mec.acoes > totalAcoes then
			return string.format("Ações insuficientes: restam %d, a habilidade custa %d.", math.max(0, totalAcoes - turno.usadas), mec.acoes)
		end
		if mec.umaVezPorTurno and turno.usos[id] then
			return "Essa habilidade só pode ser usada uma vez por turno."
		end
		if (mec.pm or 0) > 0 and token.mana < mec.pm then
			return string.format("PM insuficiente: tem %d, precisa de %d.", token.mana, mec.pm)
		end
		iniciarPT(token)
		if (mec.pt or 0) > 0 and (token.pt or 0) < mec.pt then
			return string.format("PT insuficiente: tem %d, precisa de %d.", token.pt or 0, mec.pt)
		end

		local arvore = mec.arvore or (if mec.basico then Execucao.arvoreDeCorpo(token.ficha2, deps.catalogo) else Execucao.arvoreDe(id))
		local entrada = deps.catalogo.POR_ID[id]
		local nome = entrada and entrada.data.name or mec.nome or id
		local recibo = {
			habilidadeId = id,
			casterId = token.id,
			origem = { token.x, token.z },
			alvos = {},
			encantamento = entrada and entrada.data.incantation or nil,
			estilo = mec.estilo,
		}
		local registro = { string.format("%s usa %s", token.name, nome) }
		local alvos, casas, info = nil, nil, {}
		local destino = nil

		-- Validação de geometria antes de pagar.
		if mec.tipo == "ataque" or mec.tipo == "efeito" or mec.tipo == "cura" then
			local falha
			alvos, falha, info = alvosDaMecanica(player, token, mec, payload)
			if not alvos then
				return falha
			end
		elseif mec.tipo == "invocacao" then
			local conhecidos = Execucao.pactosDe(token.ficha2)
			local escolhido = payload.pactoId or (#conhecidos == 1 and conhecidos[1])
			if type(escolhido) ~= "string" or not table.find(conhecidos, escolhido) then return "Escolha um Pacto conhecido." end
			if pactosExaustos[token.id .. ":" .. escolhido] then return "Pacto derrotado: indisponível até Descanso Longo (controle manual)." end
			if invocados[token.id] and tokens[invocados[token.id]] then return "Já mantém um Pacto ativo." end
			if #deps.tokenOrder >= 60 then return "Mesa cheia." end
			local lugar
			for dx = -1, 1 do for dz = -1, 1 do
				if (dx ~= 0 or dz ~= 0) and livre(token.x + dx, token.z + dz, nil) then lugar = { token.x + dx, token.z + dz }; break end
			end if lugar then break end end
			if not lugar then return "Não há espaço livre para o Pacto." end
			info.pactoId, info.lugar = escolhido, lugar
		elseif mec.tipo == "investida" then
			local alvo = type(payload.alvoId) == "string" and tokens[payload.alvoId]
			if not visivel(player, alvo) or alvo == token then
				return "Escolha um alvo visível."
			end
			local alcanceCorrida = math.min(mec.alcanceCasas, deslocamentoDe(token) * (if mec.dobraDeslocamento then 2 else 1))
			if Combate.distancia(token.x, token.z, alvo.x, alvo.z) > alcanceCorrida + 1 then
				return "Alvo longe demais para a investida."
			end
			-- Casa vizinha ao alvo mais próxima de quem investe, em linha reta.
			local melhor, melhorDist = nil, math.huge
			for dx = -1, 1 do
				for dz = -1, 1 do
					local cx, cz = alvo.x + dx, alvo.z + dz
					if (dx ~= 0 or dz ~= 0) and (livre(cx, cz, token) or (cx == token.x and cz == token.z)) then
						local d = Combate.distanciaEuclidiana(token.x, token.z, cx, cz)
						if d < melhorDist then
							melhor, melhorDist = { cx, cz }, d
						end
					end
				end
			end
			if not melhor then
				return "Não há espaço ao lado do alvo."
			end
			if not caminhoLivre(token, melhor[1], melhor[2]) then
				return "O caminho da investida está bloqueado."
			end
			local corrida = Combate.distancia(token.x, token.z, melhor[1], melhor[2])
			if corrida > alcanceCorrida then return "Corrida além do Deslocamento disponível." end
			if mec.exigeCorridaCasas and corrida < mec.exigeCorridaCasas then
				return string.format("Precisa correr ao menos %d casa(s) em linha reta (correria %d).", mec.exigeCorridaCasas, corrida)
			end
			destino = { melhor[1], melhor[2], corrida, alvo }
		elseif mec.tipo == "deslocamento" then
			local x, z = payload.x, payload.z
			if not Protocol.isCell(x, z) or not livre(x, z, token) then
				return "Escolha uma casa livre."
			end
			if Combate.distancia(token.x, token.z, x, z) > mec.alcanceCasas then
				return "Casa fora de alcance."
			end
			if not caminhoLivre(token, x, z) then return "O caminho está bloqueado." end
			destino = { x, z }
		elseif mec.tipo == "zona" then
			local falha
			casas, falha = casasDaZona(token, mec, payload)
			if not casas then
				return falha
			end
		elseif mec.tipo == "utilidade" then
			if mec.alvoCasa then
				local x, z = payload.x, payload.z
				if not Protocol.isCell(x, z) then
					return "Escolha uma casa no tabuleiro."
				end
				if Combate.distancia(token.x, token.z, x, z) > (mec.alcanceCasas or 1) then
					return "Casa fora de alcance."
				end
				if not Combate.temVisao(token.x, token.z, x, z, bloqueiaVisao) then
					return "Sem linha de visão até a casa."
				end
				info.centro = { x, z }
			end
		end

  for _, alvo in alvos or {} do
   if mec.umaVezPorCriaturaCombate and usosCombate[id .. ":" .. alvo.id] then return "Já recebeu Primeiros Socorros neste combate." end
   if mec.sangria then
    if alvo.pv <= 0 then return "Sangria não funciona a 0 PV." end
    local rank = Execucao.bonusDeRankDa(token.ficha2, "desintoxicacao") + 1
    local aflicao = aflicaoPurgavel(alvo, rank)
    if not aflicao then return "Sem aflição purgável com rank/origem conhecidos até um rank acima." end
    local fonte = fonteDaCondicao(alvo, aflicao)
    local chave = "sangria:" .. alvo.id .. ":" .. aflicao .. ":" .. tostring(fonte.sourceId or "importada")
    if usosCombate[chave] then return "Sangria já usada nessa aflição até o descanso automático." end
    mec.aflicao, info.chaveSangria = aflicao, chave
   end
   if mec.estancar then
    local fonte = fonteDaCondicao(alvo, "em-chamas")
    if not Estados.valor(estados, alvo.id, "sangramento") and not (temCondicao(alvo, "em-chamas") and not (fonte and fonte.magica)) then return "Sem sangramento ou fogo não mágico para Estancar." end
   end
   if mec.escape and agarrados[alvo.id] then return "Esse alvo já está agarrado." end
   if mec.escape then for _, v in agarrados do if v.sourceId == token.id then return "Solte o agarrão atual antes de prender outro alvo." end end end
   if mec.desarmarManobra or mec.quebrarEquipamento then
    local item = if mec.quebrarEquipamento then Desarme.equipamento(alvo.ficha2, mec.escolhaEquipamento) else Desarme.arma(alvo.ficha2)
    if not item and not (alvo.criatura and alvo.criatura.categoria == "humanoide" and (not mec.quebrarEquipamento or mec.escolhaEquipamento == "arma") and not Estados.valor(estados, alvo.id, "desarmado")) then return "Alvo sem equipamento representado (garras/mordidas não são armas)." end
    if mec.quebrarEquipamento and item and not (Armas.grupo(item.name) or string.lower(item.name) == "escudo") then return "Natureza mágica/mundana desse item desconhecida; não cobrados recursos." end
   end
			if mec.maxAutoRank and Estado.patamar(alvo) > mec.maxAutoRank then return "Este alvo exige resolução manual do desarme; não foram cobrados recursos." end
			if mec.naoConsecutivo and vacuos[token.id .. ":" .. alvo.id] and combat.turn - vacuos[token.id .. ":" .. alvo.id] <= #(combat.order or {}) then return "Essa criatura não pode ser afetada em turnos seguidos." end
			local chave = token.id .. ":" .. id .. ":" .. alvo.id
			if mec.umaVezPorCombateAlvo and usosCombate[chave] then return "Já usada contra esse alvo neste combate." end
			if mec.umaVezPorDescansoAlvo and usosDescanso[chave] then return "Já usada contra esse alvo desde o último Descanso Curto." end
			if mec.purga and (condicoesDe(alvo).dose or 0) == 0 and not aflicaoPurgavel(alvo, mec.purga) then return "Sem Dose ou aflição Principiante com origem/rank conhecido." end
		end
		local provocacao = Estados.entrada(estados, token.id, "provocado")
		local provocador = provocacao and tokens[provocacao.fonteId]
		if provocador and Combate.distancia(token.x, token.z, provocador.x, provocador.z) <= (mec.alcanceCasas or 1) and Combate.temVisao(token.x, token.z, provocador.x, provocador.z, bloqueiaVisao) and (mec.tipo == "ataque" or mec.tipo == "investida") then
			for _, alvo in alvos or (destino and { destino[4] }) or {} do
				if alvo.id ~= provocacao.fonteId then return "Provocado: ataque quem provocou." end
			end
		end
		if (mec.tipo == "investida" or mec.tipo == "deslocamento") and (Estados.valor(estados, token.id, "imovel") or condicoesDe(token).agarrado or condicoesDe(token).atolado) then return "Não pode se deslocar neste estado." end
		if mec.consumivel then
			local achou
			for i, item in token.ficha2.construction.inventory or {} do if string.find(string.lower(item.name), mec.consumivel, 1, true) then achou = i; break end end
			if not achou then return "Falta saco de temperos no inventário." end
			info.consumivel = achou
		end

		-- Paga (sem ceder: atômico).
  if info.chaveSangria then usosCombate[info.chaveSangria] = true end
		turno.usadas += mec.acoes
		turno.usos[id] = true
		if mec.semReacoes then reacoes.gastar(token.id) end
		token.mana -= (mec.pm or 0)
		if (mec.pt or 0) > 0 then
			token.pt -= mec.pt
		end
		token.version += 1
		-- O livro exige o saco preparado; não define gasto de uma unidade por uso.
		for _, alvo in alvos or {} do
			local chave = token.id .. ":" .. id .. ":" .. alvo.id
			if mec.umaVezPorCombateAlvo then usosCombate[chave] = true end
   if mec.umaVezPorCriaturaCombate then usosCombate[id .. ":" .. alvo.id] = true end
			if mec.umaVezPorDescansoAlvo then usosDescanso[chave] = true end
		end

		local arma = nil
		if mec.arma or mec.tipo == "investida" then
			local a = Arma.daFicha(token.ficha2, deps.catalogo, mec.armaADistancia and not mec.desarmaConjurador)
			local atributo = Execucao.atributoDaArma(arvore, a.atributo, token.ficha2, deps.catalogo)
			arma = { dado = a.dado, bonus = atributo + a.bonusDeRank, nome = a.nome }
			recibo.arma = a.nome
			table.insert(registro, string.format("(%s, %s)", a.nome, a.dado))
			if a.aviso then
				table.insert(registro, a.aviso)
			end
		end
		local bandeiras = Execucao.bandeiras(token.ficha2, arvore)
		local conjurador = {
			id = token.id,
			odioPor = (Estados.entrada(estados, token.id, "odio") or {}).fonteId,
   agarradoPor = agarrados[token.id] and agarrados[token.id].sourceId,
			bc = Execucao.bc(token.ficha2, arvore, deps.catalogo),
			pv = token.pv,
			pvMax = token.pvMax,
			condicoes = condicoesDe(token),
			atributos = token.ficha2.calculated.attributes,
			arma = arma,
			bonusDeRank = Execucao.bonusDeRankDa(token.ficha2, arvore),
   bonusDisputa = math.ceil((token.ficha2.calculated.highestRankBonus or 0) / 2),
			danoCheioEmChamas = bandeiras.danoCheioEmChamas,
			dadoExtraContra = bandeiras.dadoExtraContra,
			jaAcertou = turno.acertou,
			auxilio = Estados.valor(estados, token.id, "auxilio"),
		}

		if mec.tipo == "investida" then
			local x, z, corrida, alvo = destino[1], destino[2], destino[3], destino[4]
			deps.moverFicha(token, x, z)
			table.insert(registro, string.format("avança %d casa(s)", corrida))
			recibo.trajeto = { recibo.origem, { x, z } }
			local ataque = table.clone(mec)
			ataque.tipo = "ataque"
			ataque.arma = true
			ataque.corpoACorpo = true
			if mec.bonusSeCorrerCasas and corrida >= mec.bonusSeCorrerCasas then
				ataque.partes = table.clone(mec.partes or {})
				for _, extra in mec.partesExtraNaCorrida or {} do
					table.insert(ataque.partes, extra)
				end
				table.insert(registro, "a corrida soma dano")
			end
			alvos = { alvo }
			mec = ataque
		end

		if mec.tipo == "ataque" or mec.tipo == "efeito" or mec.tipo == "cura" then
			if mec.tipo == "ataque" then
				for i, alvo in alvos do
					alvos[i] = if alvo.zona then alvo else intercepta(token, alvo, mec)
     if not alvos[i].zona then alvos[i] = intercepta(token, reacoes.antesDoAtaque(token, alvos[i], mec), mec) end
				end
			end
			if token.pv <= 0 or token.derrotado then return nil end
   local entradas = {}
			for _, alvo in alvos do
				local entradaAlvo = entradaDeAlvo(alvo, token, mec)
    if alvo.zona then entradaAlvo.ca = 1; entradaAlvo.barreira = true end -- barreira imóvel: acerto automático, sem crítico
    table.insert(entradas, entradaAlvo)
			end
			local efeitos
			if mec.alvo == "disparos" and #entradas == 2 then
				local primeiro = table.clone(mec); primeiro.segundoDisparo, primeiro.efeitoNoAcerto, primeiro.aplicaSeAmbos = nil, nil, nil
				local segundo = table.clone(primeiro); segundo.partes = mec.segundoDisparo
				efeitos = { Habilidades.resolver(deps.random, primeiro, conjurador, { entradas[1] }, regrasDeCondicao)[1], Habilidades.resolver(deps.random, segundo, conjurador, { entradas[2] }, regrasDeCondicao)[1] }
			else efeitos = Habilidades.resolver(deps.random, mec, conjurador, entradas, regrasDeCondicao) end
			for i, efeito in efeitos do
				local alvo = alvos[i]
    local extra = if mec.tipo == "ataque" and not alvo.zona then reagirAoGolpe(token, alvo, efeito, mec) else ""
				local texto = alvo.name .. ": "
				if efeito.ataque then
					texto ..= textoDoAtaque(efeito.ataque)
					if efeito.ataque.acertou or (efeito.segundoAtaque and efeito.segundoAtaque.acertou) then
						turno.acertou = true
					end
				end
				if efeito.resistencia then
					texto ..= (if efeito.ataque then "; " else "") .. textoDoTeste(efeito.resistencia)
				end
				if mec.naoConsecutivo and (efeito.estados or efeito.dano) then vacuos[token.id .. ":" .. alvo.id] = combat.turn end
				if efeito.dano and protecao(alvo, "resisteArea") and (mec.alvo == "cone" or mec.alvo == "esferaNoConjurador" or mec.alvo == "esferaNaCasa") then efeito.dano.total = math.floor(efeito.dano.total / 2) end
				if efeito.ataque then Estados.remover(estados, token.id, "auxilio"); Estados.remover(estados, alvo.id, "marcaPacto") end
				local resultado = aplicarEfeito(alvo, efeito, token, mec)
				if resultado ~= "" then
					texto ..= " — " .. resultado
				end
				if #efeito.notas > 0 then
					texto ..= " (" .. table.concat(efeito.notas, "; ") .. ")"
				end
				if extra ~= "" then
					texto ..= "; " .. extra
				end
				deps.logAboutToken(if alvo.zona then token else alvo, texto)
				if not alvo.zona then
     table.insert(recibo.alvos, resumoDoEfeito(efeito))
     if efeito.ataque then Estados.remover(estados, alvo.id, "coberturaProximoAtaque") end
    else recibo.centro = { alvo.x, alvo.z }; recibo.barreiraId = alvo.zona.id end
			end
			if mec.tipo == "ataque" then
				for i, efeito in efeitos do
					if not alvos[i].zona then reacoes.aposAplicar(token, alvos[i], efeito, mec) end
				end
			end
			if #alvos == 0 then
				table.insert(registro, "ninguém foi atingido")
			end
			recibo.centro = info.centro
			recibo.direcao = info.direcao
		elseif mec.tipo == "invocacao" then
			local invocado = criarInvocado(token, info.pactoId, info.lugar)
			table.insert(registro, invocado.name .. " surge com " .. invocado.pv .. " PV")
			table.insert(recibo.alvos, { id = invocado.id })
		elseif mec.tipo == "deslocamento" then
			deps.moverFicha(token, destino[1], destino[2])
			recibo.trajeto = { recibo.origem, { destino[1], destino[2] } }
			table.insert(registro, string.format("vai para a casa %d, %d", destino[1], destino[2]))
		elseif mec.tipo == "zona" then
			proximaZona += 1
			local zona = {
				id = "z" .. proximaZona,
				habilidadeId = id,
				casas = {},
				lista = casas,
				rodadaFim = combat.round + (mec.duracaoRodadas or 10),
				criadorId = token.id,
				estilo = mec.estilo or arvore,
				cobertura = mec.cobertura, reduzIgneo = mec.reduzIgneo, terrenoDificil = mec.terrenoDificil,
				bloqueiaMovimento = mec.bloqueiaMovimento,
				bloqueiaVisao = mec.bloqueiaVisao,
				bloqueiaProjeteis = mec.bloqueiaProjeteis,
    pv = mec.pvZona, pvMax = mec.pvZona,
				danoAoAtravessar = mec.danoAoAtravessar ~= nil,
			}
			for _, casa in casas do
				zona.casas[deps.cellKey(casa[1], casa[2])] = true
			end
			table.insert(zonas, zona)
			recibo.casas = casas
			recibo.zonaId = zona.id
			table.insert(registro, string.format("%d casa(s) até a rodada %d", #casas, zona.rodadaFim))
		else
			recibo.centro = info.centro
			table.insert(registro, mec.registro or "efeito narrativo (o mestre descreve)")
		end

		if mec.zonaApos then
			proximaZona += 1
			local zona = { id = "z" .. proximaZona, habilidadeId = id, casas = {}, lista = {}, estilo = mec.zonaApos.estilo, terrenoDificil = true, rodadaFim = combat.round + mec.zonaApos.duracaoRodadas }
			for x = 1, Protocol.BOARD.width do for z = 1, Protocol.BOARD.height do
				if Combate.distanciaEuclidiana(token.x, token.z, x, z) <= mec.raioCasas then table.insert(zona.lista, { x, z }); zona.casas[deps.cellKey(x, z)] = true end
			end end
			table.insert(zonas, zona)
		end
		for _, e in mec.estadosConjurador or {} do Estados.definir(estados, token.id, e.nome, e.valor, token.id, e.duracao, combat.round) end
		if mec.desarmaConjurador then
   local alvo = alvos[1]
   local x, z = alvo.x, alvo.z
   largarArma(token, x, z)
  end
  if mec.ultimaPosicao then ultimasPosicoes[token.id] = { x = token.x, z = token.z } end
		if mec.removeMarcasDaMorte then table.insert(registro, "Marcas da Morte ausentes: a cura recupera PV; descanso automático encerra o encontro.") end
		if mec.aviso then table.insert(registro, mec.aviso) end
		if mec.danoConjurador then
			local e = Habilidades.danoDeCondicao(deps.random, mec.danoConjurador, nil, entradaDeAlvo(token))
			deps.logAboutToken(token, aplicarEfeito(token, e, token, nil))
		end
		deps.logAboutToken(token, table.concat(registro, " • "))
		enviarRecibo(recibo)
		return nil
	end

	-- Comando: apagar o fogo -------------------------------------------------

	handlers.apagarFogo = function(player, payload, master)
		local token = type(payload.tokenId) == "string" and tokens[payload.tokenId]
		if not token or not deps.canSee(player, token) then
			return "Ficha não encontrada."
		end
		if not master and token.ownerUserId ~= player.UserId then
			return "Você só age com a sua ficha."
		end
		if token.pv <= 0 then return "Ficha caída não age." end
		for id in condicoesDe(token) do
			if regrasDeCondicao[id] and regrasDeCondicao[id].semAcoes then return "Sem Ações neste estado." end
		end
		if not temCondicao(token, "em-chamas") then
			return "Essa ficha não está Em Chamas."
		end
		if combat.active then
			if deps.currentTurnId() ~= token.id then
				return "Aguarde a vez dessa ficha."
			end
			local turno = estadoDoTurno(token.id)
			if turno.usadas + 1 > limiteDeAcoes(token) then
				return "Sem Ações neste turno."
			end
			turno.usadas += 1
		end
		local _, resistir = defesaDe(token)
		local r = Combate.resistencia(deps.random, resistir("agilidade"), CD_APAGAR_FOGO)
		if r.passou then
			removerCondicao(token, "em-chamas")
		end
		token.version += 1
		deps.logAboutToken(token, string.format("%s rola no chão para apagar o fogo: d20 %d %+d = %d contra CD %d — %s.", token.name, r.d20.natural, r.bonus, r.total, r.cd, if r.passou then "apagou" else "ainda queima"))
		enviarRecibo({ habilidadeId = "apagar-fogo", casterId = token.id, origem = { token.x, token.z }, alvos = { { id = token.id, passou = r.passou } } })
		return nil
	end

	-- Comandos do mestre: criatura e personagem pronto ---------------------

	handlers.criarCriatura = function(player, payload, master)
		if not master then
			return "Só o mestre cria criaturas."
		end
		local entrada = type(payload.creatureId) == "string" and deps.catalogo.POR_ID[payload.creatureId]
		if not entrada or entrada.kind ~= "creature" then
			return "Criatura desconhecida."
		end
		local ficha = Criaturas.ficha(entrada)
		local falha, id = handlers.createToken(player, {
			name = string.sub(ficha.nome, 1, 32),
			kind = "npc",
			pvMax = ficha.pvMax,
			manaMax = 0,
			x = payload.x,
			z = payload.z,
		}, true)
		if falha then
			return falha
		end
		local token = tokens[id]
		token.criatura = { catalogId = entrada.id, ca = ficha.ca, bonusResistencia = ficha.bonusResistencia, bonusAtaque = ficha.bonusAtaque, patamar = ficha.patamar, papel = ficha.papel, resistencias = ficha.resistencias, imunidades = ficha.imunidades, danoPorTurno = ficha.danoPorTurno, deslocamentoMetros = ficha.deslocamentoMetros, categoria = entrada.data.categoria }
		token.showStats = true
		token.version += 1
		return nil, { id = id }
	end

	handlers.criarPremontado = function(player, payload, master)
		if not master then
			return "Só o mestre cria personagens prontos."
		end
		local texto = type(payload.id) == "string" and deps.premontados[payload.id]
		if not texto then
			return "Personagem pronto desconhecido."
		end
		local corpo, falha = FichaV2.validar(HttpService:JSONDecode(texto), deps.catalogo)
		if not corpo then
			return "Personagem pronto inválido: " .. tostring(falha)
		end
		local mesa = FichaV2.paraMesa(corpo)
		local erro, id = handlers.createToken(player, {
			name = corpo.name,
			kind = "jogador",
			pvMax = mesa.pvMax,
			manaMax = mesa.manaMax,
			ownerUserId = payload.ownerUserId,
			x = payload.x,
			z = payload.z,
		}, true)
		if erro then
			return erro
		end
		local token = tokens[id]
		token.pv, token.mana = mesa.pv, mesa.mana
		token.sheet = mesa.sheet
		token.ficha2 = corpo
		iniciarPT(token)
		token.version += 1
		return nil, { id = id }
	end

	-- Ganchos do MesaService ------------------------------------------------

	local api = {}
	-- Janela de Reação (testes do Studio trocam a pergunta por api.reacoes.decidir).
	api.reacoes = reacoes

	-- A vez passou de anteriorId para novoId: encerra durações de quem terminou a
	-- vez, expira zonas, cobra o dano por turno das condições de quem começa.
	function api.aoTrocarVez(anteriorId: string?, novoId: string?)
  limparVinculos()
  if novoId then ultimasPosicoes[novoId] = nil end
		reacoes.inicioDaVez(novoId)
		for id in Estados.avancar(estados, anteriorId, novoId, combat.round) do if tokens[id] then tokens[id].version += 1 end end
		if anteriorId and tokens[anteriorId] then
			sequencia += 1
			tokens[anteriorId].fimUltimoTurno = sequencia
		end
		for i = #duracoes, 1, -1 do
			local d = duracoes[i]
			local token = tokens[d.tokenId]
			local acabou = false
			if d.rodadaFim then
				acabou = combat.round >= d.rodadaFim
			elseif d.gatilho == anteriorId and d.estado == "ativa" then
				acabou = true
			elseif d.gatilho == novoId and d.estado == "aplicada" then
				d.estado = "ativa"
			end
			if acabou then
				table.remove(duracoes, i)
				if token and temCondicao(token, d.condicao) then
					removerCondicao(token, d.condicao)
					token.version += 1
					local entrada = Condicoes.POR_ID[d.condicao]
					deps.logAboutToken(token, string.format("%s não está mais %s.", token.name, if entrada then entrada.nome else d.condicao))
				end
			end
		end
		local expirados = {}
		for id, ficha in tokens do if ficha.invocado and combat.round >= ficha.invocado.rodadaFim then table.insert(expirados, id) end end
		for _, id in expirados do deps.removerFicha(id) end
		for i = #zonas, 1, -1 do
			if combat.round >= zonas[i].rodadaFim then
				table.remove(zonas, i)
			end
		end
		for _, ficha in tokens do
			if ficha.pvTempAte and combat.round >= ficha.pvTempAte then
				ficha.pvTemp, ficha.pvTempAte = nil, nil
				ficha.version += 1
			end
		end
		local token = novoId and tokens[novoId]
		if not token or token.pv <= 0 then
			return
		end
		for id in condicoesDe(token) do
			local m = regrasDeCondicao[id]
			local formula = m and m.danoPorTurno
			if formula then
				local efeito = Habilidades.danoDeCondicao(deps.random, formula, TIPO_DO_DANO_POR_TURNO[id], entradaDeAlvo(token))
				local resultado = aplicarEfeito(token, efeito, nil, nil)
				local entrada = Condicoes.POR_ID[id]
				deps.logAboutToken(token, string.format("%s sofre %s (%s [%s]): %s%s.", token.name, if entrada then entrada.nome else id, formula,
					table.concat(efeito.dano.partes[1].resultados, ", "), resultado,
					if #efeito.notas > 0 then " (" .. table.concat(efeito.notas, "; ") .. ")" else ""))
				enviarRecibo({ habilidadeId = id, casterId = nil, origem = { token.x, token.z }, alvos = { { id = token.id, dano = efeito.dano.total } } })
			end
		end
	end

	-- A ficha andou: quem entra numa casa de zona com dano (no caminho ou no destino) sofre, uma vez por movimento.
	function api.moveu(token, deX: number, deZ: number)
  limparVinculos()
  for fonteId, posicao in ultimasPosicoes do
   local fonte = tokens[fonteId]
   if fonte and aliado(fonte, token) then
    for _, casa in Combate.linha(deX, deZ, token.x, token.z) do
     if casa[1] == posicao.x and casa[2] == posicao.z then Estados.definir(estados, token.id, "coberturaProximoAtaque", 2, fonteId, nil, combat.round) end
    end
   end
  end
		local zona
		for _, casa in Combate.linha(deX, deZ, token.x, token.z) do
			zona = zonaEm(casa[1], casa[2], "danoAoAtravessar")
			if zona then
				break
			end
		end
		if not zona or token.pv <= 0 then
			return
		end
		local mec = Execucao.MECANICAS[zona.habilidadeId]
		local efeito = Habilidades.atravessar(deps.random, mec, entradaDeAlvo(token))
		local resultado = aplicarEfeito(token, efeito, nil, mec)
  if temCondicao(token, "em-chamas") and efeito.aplica and table.find(efeito.aplica, "em-chamas") then
   fontesCondicao[token.id] = fontesCondicao[token.id] or {}
   fontesCondicao[token.id]["em-chamas"] = { sourceId = zona.criadorId, rank = 1, magica = true }
  end
		deps.logAboutToken(token, string.format("%s atravessa %s: %s.", token.name, (deps.catalogo.POR_ID[zona.habilidadeId] or { data = { name = "a zona" } }).data.name, resultado))
		enviarRecibo({ habilidadeId = "atravessar-muro", casterId = nil, origem = { token.x, token.z }, alvos = { resumoDoEfeito(efeito) } })
	end

	-- Zonas que barram o movimento (muro de terra, anteparo).
	function api.bloqueiaMovimento(x: number, z: number): boolean
		return zonaEm(x, z, "bloqueiaMovimento") ~= nil
	end

	function api.validarMovimento(token, x, z, pagar, player)
		if not combat.active or (not token.ficha2 and not token.invocado) then return nil end
		local conds = condicoesDe(token)
		for id in conds do if regrasDeCondicao[id] and regrasDeCondicao[id].semAcoes then return "Sem movimento neste estado." end end
		if token.pv <= 0 or conds.agarrado or conds.atolado or Estados.valor(estados, token.id, "imovel") then return "Não pode se mover neste estado." end
		local limite = deslocamentoDe(token)
		for _, casa in Combate.linha(token.x, token.z, x, z) do
			if deps.terrain[deps.cellKey(casa[1], casa[2])] == "parede" or zonaEm(casa[1], casa[2], "bloqueiaMovimento") then return "O caminho está bloqueado." end
			for _, outro in tokens do
				if outro ~= token and not outro.derrotado and outro.x == casa[1] and outro.z == casa[2] and (not player or deps.canSee(player, outro)) then return "O caminho está ocupado." end
			end
		end
		local distancia = 0
		for _, casa in Combate.linha(token.x, token.z, x, z) do distancia += if zonaEm(casa[1], casa[2], "terrenoDificil") or conds.caido then 2 else 1 end
		if distancia > limite then return "Movimento além do deslocamento disponível." end
		local t = estadoDoTurno(token.id)
		local total = limiteDeAcoes(token)
		if pagar and t.usadas >= total then return "Sem Ação para mover." end
		if pagar then t.usadas += 1 end
		return nil
	end
	-- IA simples dos inimigos (J2). O servidor age por eles: vai até o alvo mais
	-- próximo e ataca uma vez, com o bloco do Apêndice G (d20 + bônus de ataque
	-- contra a CA; dano por turno fixo). Só roda para fichas marcadas com `ia`
	-- (Modo Luta); criaturas de mesa continuam sob o mestre.
	local VIZINHOS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
	local VERBO_DA_CATEGORIA = { besta = "morde", humanoide = "golpeia", ["morto-vivo"] = "golpeia", construto = "esmaga", demonio = "dilacera", monstro = "ataca" }

	local function alvosDoInimigo(token)
		local lista = {}
		for _, id in deps.tokenOrder do
			local t = tokens[id]
			if t and t ~= token and not t.ia and not t.boneco and not t.derrotado and t.pv > 0 and (t.kind == "jogador" or t.invocado) then
				table.insert(lista, t)
			end
		end
		return lista
	end

	-- Melhor casa a até `limite` passos: a que mais aproxima do alvo (empate: menos passos).
	-- Não pisa em parede, ficha, barreira nem em zona que fere ao atravessar.
	local function passoAte(token, alvo, limite: number)
		local visto = { [deps.cellKey(token.x, token.z)] = true }
		local fila, cabeca = { { token.x, token.z, 0 } }, 1
		local melhor = { token.x, token.z, 0 }
		local melhorDistancia = Combate.distancia(token.x, token.z, alvo.x, alvo.z)
		while cabeca <= #fila do
			local atual = fila[cabeca]
			cabeca += 1
			if atual[3] < limite then
				for _, v in VIZINHOS do
					local x, z = atual[1] + v[1], atual[2] + v[2]
					local chave = deps.cellKey(x, z)
					if not visto[chave] and livre(x, z, token) and not zonaEm(x, z, "danoAoAtravessar") then
						visto[chave] = true
						local passos = atual[3] + 1
						table.insert(fila, { x, z, passos })
						local d = Combate.distancia(x, z, alvo.x, alvo.z)
						if d < melhorDistancia or (d == melhorDistancia and passos < melhor[3]) then
							melhor, melhorDistancia = { x, z, passos }, d
						end
					end
				end
			end
		end
		return melhor
	end

	-- Devolve true se a ficha agiu (ou tentou); o chamador passa a vez.
	function api.turnoDoInimigo(token): boolean
  limparVinculos()
		local c = token.criatura
		if not c or not c.danoPorTurno or token.pv <= 0 or token.derrotado then
			return false
		end
		local conds = condicoesDe(token)
		for id in conds do
			if regrasDeCondicao[id] and regrasDeCondicao[id].semAcoes then
				deps.logAboutToken(token, token.name .. " não consegue agir.")
				return true
			end
		end
  local acoes = math.max(0, limiteDeAcoes(token))
  if agarrados[token.id] and acoes > 0 then tentarEscapar(token); acoes -= 1; conds = condicoesDe(token) end
  if Estados.valor(estados, token.id, "desarmado") and not Estados.valor(estados, token.id, "bracoInutil") and not quebrados[token.id] and acoes > 0 then
   for _, objeto in objetos do
    if objeto.donoId == token.id and Combate.distancia(token.x, token.z, objeto.x, objeto.z) <= 1 and Combate.temVisao(token.x, token.z, objeto.x, objeto.z, bloqueiaVisao) then pegarObjeto(token, objeto); acoes -= 1; break end
   end
  end
		local alvos = alvosDoInimigo(token)
		if #alvos == 0 then
			return false
		end
		local alvo = alvos[1]
		for _, t in alvos do
			local d, dm = Combate.distancia(token.x, token.z, t.x, t.z), Combate.distancia(token.x, token.z, alvo.x, alvo.z)
			if d < dm or (d == dm and t.pv < alvo.pv) then
				alvo = t
			end
		end
		local casas = math.max(1, math.floor((c.deslocamentoMetros or 9) / 1.5))
		if conds.agarrado or conds.atolado or Estados.valor(estados, token.id, "imovel") then
			casas = 0
		end
		casas = math.max(0, casas - (Estados.valor(estados, token.id, "reduzMovimento") or 0))
		if Estados.valor(estados, token.id, "metadeMovimento") then
			casas = math.floor(casas / 2)
		end
		local origem = { token.x, token.z }
		local passos = 0
		for _ = 1, 2 do
			if acoes <= 1 or Combate.distancia(token.x, token.z, alvo.x, alvo.z) <= 1 or casas == 0 then
				break
			end
			local destino = passoAte(token, alvo, casas)
			if destino[3] == 0 then
				break
			end
			deps.moverFicha(token, destino[1], destino[2])
			passos += destino[3]
			acoes -= 1
			if token.pv <= 0 then
				return true
			end
		end
		if passos > 0 then
			deps.logAboutToken(token, string.format("%s avança %d casa(s) em direção a %s.", token.name, passos, alvo.name))
			token.version += 1
		end
  -- Se não consegue contornar, golpeia a barreira adjacente em direção ao alvo.
  if Combate.distancia(token.x, token.z, alvo.x, alvo.z) > 1 then
   local obstaculo = intercepta(token, alvo, { arma = true })
   if obstaculo.zona and Combate.distancia(token.x, token.z, obstaculo.x, obstaculo.z) <= 1 then alvo = obstaculo end
  end

		if acoes >= 1 and Combate.distancia(token.x, token.z, alvo.x, alvo.z) <= 1 then
			if deps.virarPara then
				deps.virarPara(token, alvo.x, alvo.z)
			end
			local mec = { tipo = "ataque", corpoACorpo = true, criatura = true, partes = { { fixo = Desarme.danoDaCriatura(c.danoPorTurno, Estados.valor(estados, token.id, "desarmado") ~= nil or Estados.valor(estados, token.id, "bracoInutil") ~= nil) } } }
			local conjurador = { bc = c.bonusAtaque or 0, pv = token.pv, pvMax = token.pvMax, condicoes = condicoesDe(token), agarradoPor = agarrados[token.id] and agarrados[token.id].sourceId }
			alvo = intercepta(token, alvo, mec)
   if not alvo.zona then alvo = intercepta(token, reacoes.antesDoAtaque(token, alvo, mec), mec) end
			if token.pv <= 0 or token.derrotado then
				return true
			end
			local entrada = entradaDeAlvo(alvo, token, mec)
   entrada.barreira = alvo.zona ~= nil
   local efeito = Habilidades.resolver(deps.random, mec, conjurador, { entrada }, regrasDeCondicao)[1]
			local extra = if alvo.zona then "" else reagirAoGolpe(token, alvo, efeito, mec)
			local texto = aplicarEfeito(alvo, efeito, token, mec)
			local rolagem = if efeito.ataque then textoDoAtaque(efeito.ataque) else ""
			deps.logAboutToken(alvo, string.format("%s %s %s: %s%s%s%s", token.name, VERBO_DA_CATEGORIA[c.categoria or ""] or "ataca", alvo.name, rolagem,
				if texto ~= "" then " — " .. texto else "", if #efeito.notas > 0 then " (" .. table.concat(efeito.notas, "; ") .. ")" else "",
				if extra ~= "" then "; " .. extra else ""))
			enviarRecibo({ habilidadeId = "criatura/ataque", casterId = token.id, origem = { token.x, token.z }, alvos = { resumoDoEfeito(efeito) }, publico = true })
			if not alvo.zona then reacoes.aposAplicar(token, alvo, efeito, mec) end
		elseif passos == 0 then
			deps.logAboutToken(token, token.name .. " não alcança ninguém e espera.")
		end
		token.version += 1
		return true
	end

	function api.pactosDe(token) return token.ficha2 and Execucao.pactosDe(token.ficha2) or nil end
	function api.estadosDe(token) return Estados.nomes(estados, token.id) end
	-- Para o snapshot: Ações da vez atual e as zonas (públicas, como o terreno).
	function api.estado()
		local id = deps.currentTurnId()
		local acoes = nil
		if id then
			local t = estadoDoTurno(id)
			local usos = {}
			for usado in t.usos do
				table.insert(usos, usado)
			end
			acoes = { tokenId = id, usadas = t.usadas, total = if tokens[id] then limiteDeAcoes(tokens[id]) else ACOES_POR_TURNO, usos = usos }
		end
		local lista = {}
		for _, zona in zonas do
			table.insert(lista, { id = zona.id, casas = zona.lista, rodadaFim = zona.rodadaFim, estilo = zona.estilo, habilidadeId = zona.habilidadeId, pv = zona.pv, pvMax = zona.pvMax })
		end
		local noChao = {}
  for _, o in objetos do
   local dono = tokens[o.donoId]
   local publico = dono ~= nil and not dono.hidden
   if publico then
    local posicao = table.clone(dono); posicao.x, posicao.z = o.x, o.z
    for _, player in game:GetService("Players"):GetPlayers() do if not deps.canSee(player, posicao) then publico = false; break end end
   end
   if publico then table.insert(noChao, { id = o.id, x = o.x, z = o.z, nome = "Arma no chão" }) end
  end
  return { acoes = acoes, muros = lista, objetos = noChao }
	end

	-- Habilidades executáveis da ficha (para o snapshot do dono e do mestre).
	function api.habilidadesDe(token): { string }?
		if token.invocado then
			local pacto = Execucao.PACTOS[token.invocado.pactoId]
			return if pacto.ajuda then { "invocado/ajudar" } elseif pacto.derruba then { "invocado/ataque", "invocado/derrubar" } else { "invocado/ataque" }
		end
		if not token.ficha2 then
			return nil
		end
		local lista = Execucao.habilidadesDe(token.ficha2, deps.catalogo)
  if table.find(lista, "ability/armas-pesadas/Principiante/quebrar-equipamento") then table.insert(lista, "mesa/quebrar-escudo") end
  if agarrados[token.id] then table.insert(lista, "mesa/escapar") end
  for _, v in agarrados do if v.sourceId == token.id then table.insert(lista, "mesa/arrastar"); table.insert(lista, "mesa/soltar"); break end end
  for _, o in objetos do if o.donoId == token.id then table.insert(lista, "mesa/pegar-arma"); break end end
  table.insert(lista, "mesa/desarmar")
		if Estados.valor(estados, token.id, "armaGelo") then
			table.insert(lista, "mesa/lamina-de-gelo-forca")
			table.insert(lista, "mesa/lamina-de-gelo-intelecto")
		end
		for _, id in Execucao.BASICOS do
			table.insert(lista, id)
		end
		if Progressao.rankAberto(token.ficha2.construction, "cavalaria-e-escudos", "Principiante") then
			table.insert(lista, "mesa/sob-minha-guarda")
		end
		return lista
	end

	function api.iniciarPT(token)
		iniciarPT(token)
	end

	function api.descartarTudo()
  restaurarEquipamento()
		table.clear(estados.efeitos)
		table.clear(usosCombate)
		table.clear(vacuos)
		table.clear(fontesCondicao)
		table.clear(zonas)
		table.clear(duracoes)
		table.clear(aplicadas)
		reacoes.limpar()
		turnoAtual.tokenId, turnoAtual.turno = nil, -1
	end

	-- Fim do combate: zonas somem e as condições aplicadas pelas habilidades saem.
	function api.combateEncerrado()
  restaurarEquipamento()
		local ids = {}; for id, t in tokens do if t.invocado then table.insert(ids, id) end end
		for _, id in ids do deps.removerFicha(id) end
		table.clear(invocados)
		for id, conds in aplicadas do
			local token = tokens[id]
			if token then
				for cond in conds do
					if temCondicao(token, cond) and cond ~= "caido" then
						removerCondicao(token, cond)
					end
				end
				token.dormindo = nil
				token.pvTemp = nil
				token.feridaSelada = nil
				token.version += 1
			end
		end
		for _, token in tokens do
			token.ultimoDano, token.fimUltimoTurno = nil, nil
   token.a16CaQuebrada = nil
			token.feridaSelada, token.feridaSeladaAte = nil, nil
			token.pvTemp, token.dormindo, token.pvTempAte = nil, nil, nil
			token.version += 1
		end
		sequencia = 0
		table.clear(estados.efeitos)
		table.clear(usosCombate)
		table.clear(vacuos)
		table.clear(fontesCondicao)
		table.clear(aplicadas)
		table.clear(duracoes)
		table.clear(zonas)
		reacoes.limpar()
		turnoAtual.tokenId, turnoAtual.turno = nil, -1
	end

	return api
end

return HabilidadeService

end)()
local spec=(function()
-- SOMENTE STUDIO: serviço real isolado, RNG e dependências controlados.
local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = ServicoAtual
local Catalogo = require(Shared.Livro.Catalogo)
local Execucao = require(Shared.Regras.Execucao)
local function id(arvore, carta) return "ability/" .. arvore .. "/Principiante/" .. carta end
local function ficha(nome,x,z)
	local atributos = {forca=3,agilidade=3,vigor=3,intelecto=3,espirito=3}
	return { id=nome,name=nome,x=x,z=z,kind="jogador",ownerUserId=123,pv=60,pvMax=60,mana=50,manaMax=50,version=1,conditions={},sheet={ca=10,forca=3,agilidade=3,vigor=3},
		ficha2={construction={unlockedRankIds={},purchasedIds={},inventory={{name="Espada Longa",type="arma",equipped=true,baseDie="d8",sourceLocalId=nome.."-arma"}}},
		calculated={highestRankBonus=1,attributes=atributos,maxima={pt=10}},session={current={pt=10}}} }
end
local function tem(token,idCond)
	for _,c in token.conditions do if c.id==idCond then return true end end
	return false
end
local function contexto(rolagens, extras)
	local a,b,c=ficha("a",5,5),ficha("b",6,5),ficha("c",7,7)
	for _, arvore in {"terra","teorica","cura","desintoxicacao","armas-pesadas","deus-do-norte","deus-da-espada","cavalaria-e-escudos"} do
		table.insert(a.ficha2.construction.unlockedRankIds,"rank/"..arvore.."/Principiante")
	end
	for key in Execucao.MECANICAS do if string.sub(key,1,8)=="ability/" then table.insert(a.ficha2.construction.purchasedIds,key) end end
	local tokens={a=a,b=b,c=c}; local handlers,logs={},{}
	local combat={active=true,round=1,turn=1,current="a",order={"a","b","c"},turnIndex=1}
	local fila=table.clone(rolagens or {}); local terrain={}; local api
	local registro=Execucao
 if extras then registro=table.clone(Execucao);registro.MECANICAS=table.clone(Execucao.MECANICAS);for key,m in extras do registro.MECANICAS[key]=m end end
 api=Servico.start({execucao=registro,handlers=handlers,tokens=tokens,tokenOrder={"a","b","c"},combat=combat,catalogo=Catalogo,terrain=terrain,
		cellKey=function(x,z) return x..":"..z end,random={NextInteger=function(_,lo,hi) return math.clamp(if hi==20 then (table.remove(fila,1) or 15) else 3,lo,hi) end},
		remote={FireClient=function() end},canSee=function(_,token) return not token.hidden end,currentTurnId=function() return combat.current end,
		logAboutToken=function(_,texto) table.insert(logs,texto) end,moverFicha=function(token,x,z) local ox,oz=token.x,token.z; token.x,token.z=x,z; api.moveu(token,ox,oz) end,
		removerFicha=function(key) tokens[key]=nil end,reviverBoneco=function() end})
	api.reacoes.decidir=function() return nil end
	local x={a=a,b=b,c=c,api=api,combat=combat,tokens=tokens,handlers=handlers,terrain=terrain,logs=logs}
	x.usar=function(key,alvo,extra,user)
		local p={tokenId=combat.current,habilidadeId=key,alvoId=alvo}; for k,v in extra or {} do p[k]=v end
		return handlers.usarHabilidade({UserId=user or 123},p,false)
	end
	x.vez=function(key) local anterior=combat.current; combat.current=key; combat.turn+=1; api.aoTrocarVez(anterior,key) end
	return x
end
return {
	["anteparo intercepta disparo, perde PV e magia atravessa"] = function(t)
		local x=contexto({15,15}); x.b.x=9
		t.eq(x.usar(id("teorica","anteparo-teorico"),nil,{x=6,z=5}),nil)
		x.vez("b"); x.vez("a")
		t.eq(x.usar("mesa/ataque-a-distancia","b"),nil); t.eq(x.b.pv,60)
		t.ok(x.api.estado().muros[1].pv<30)
		x.vez("b");x.vez("a")
		local pvBarreira=x.api.estado().muros[1].pv
		t.eq(x.usar(id("teorica","dardo-arcano"),"b"),nil);t.ok(x.b.pv<60);t.eq(x.api.estado().muros[1].pv,pvBarreira)
	end,
	["muro 40 PV: ataque na casa destrói e libera passagem"] = function(t)
		local x=contexto(); t.eq(x.usar(id("terra","muro-de-terra"),nil,{x=6,z=5}),nil)
		t.eq(x.api.estado().muros[1].pv,40); t.eq(x.api.bloqueiaMovimento(6,5),true)
		for _=1,10 do if #x.api.estado().muros==0 then break end; x.vez("b");x.vez("a"); t.eq(x.usar("mesa/ataque-basico",nil,{x=6,z=5}),nil) end
		t.eq(#x.api.estado().muros,0);t.eq(x.api.bloqueiaMovimento(6,5),false)
	end,
	["agarrão tem escape na barra, conserva CD da disputa e punhos acertam"] = function(t)
		local x=contexto({15,1,1,1}); x.a.ficha2.construction.inventory={}
		t.eq(x.usar(id("armas-pesadas","agarrao"),"b"),nil);t.ok(tem(x.b,"agarrado"))
		t.ok(table.find(x.api.habilidadesDe(x.b),"mesa/escapar"))
		t.eq(x.usar("mesa/ataque-basico","b"),nil);t.ok(x.b.pv<60)
		x.vez("b");t.eq(x.usar("mesa/escapar"),nil);t.ok(tem(x.b,"agarrado"));t.eq(x.api.estado().acoes.usadas,1)
	end,
	["Mão de Terra: falha/sucesso de escape custa uma Ação e limpa as duas condições"] = function(t)
		local x=contexto({1,1,20});t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
		x.vez("b");t.eq(x.usar("mesa/escapar"),nil);t.ok(tem(x.b,"agarrado"))
		t.eq(x.usar("mesa/escapar"),nil);t.eq(tem(x.b,"agarrado"),false);t.eq(tem(x.b,"atolado"),false)
		t.eq(x.api.estado().acoes.usadas,2)
	end,
	["Mão de Terra: soltar é livre e fonte caída encerra sustentação"] = function(t)
		local x=contexto({1,1});t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
		t.eq(x.usar("mesa/soltar"),nil);t.eq(tem(x.b,"agarrado"),false)
		x.vez("b");x.vez("a");t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
		x.a.pv=0;x.vez("b");t.eq(tem(x.b,"agarrado"),false);t.eq(tem(x.b,"atolado"),false)
	end,
	["arrastar Mão 3 m custa uma Ação e rejeita parede sem cobrar"] = function(t)
		local x=contexto({1});t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
		t.eq(x.usar("mesa/arrastar",nil,{x=8,z=5}),nil);t.eq(x.b.x,8);t.eq(x.api.estado().acoes.usadas,3)
		x.vez("b");x.vez("a");x.terrain["9:5"]="parede"
		t.ok(x.usar("mesa/arrastar",nil,{x=10,z=5})~=nil);t.eq(x.api.estado().acoes.usadas,0)
	end,
	["arrastar Agarrão desloca os dois juntos e separação solta"] = function(t)
		local x=contexto({15,1});t.eq(x.usar(id("armas-pesadas","agarrao"),"b"),nil)
		t.eq(x.usar("mesa/arrastar",nil,{x=6,z=7}),nil);t.eq(x.a.z,7);t.eq(x.b.z,7);t.ok(tem(x.b,"agarrado"))
		x.a.x=1;x.api.moveu(x.a,5,7);t.eq(tem(x.b,"agarrado"),false)
	end,
	["Corte: arma no chão, braço até fim do próximo turno e recuperar uma Ação"] = function(t)
		local x=contexto({15,1});t.eq(x.usar(id("deus-da-espada","corte-de-braco"),"b"),nil)
		t.eq(x.b.ficha2.construction.inventory[1].equipped,false);t.eq(#x.api.estado().objetos,1)
		x.vez("b");t.ok(x.usar("mesa/pegar-arma",nil,{x=7,z=5})~=nil)
		t.eq(x.api.estado().acoes.usadas,0)
		x.vez("a");x.vez("b");t.eq(x.usar("mesa/pegar-arma",nil,{x=7,z=5}),nil)
		t.eq(x.b.ficha2.construction.inventory[1].equipped,true);t.eq(#x.api.estado().objetos,0);t.eq(x.api.estado().acoes.usadas,1)
	end,
	["Corte Santo apenas desarma, sem bloquear o braço"] = function(t)
		local x=contexto({15,1});x.b.ficha2.calculated.highestRankBonus=4
		t.eq(x.usar(id("deus-da-espada","corte-de-braco"),"b"),nil);x.vez("b")
		t.eq(x.usar("mesa/pegar-arma",nil,{x=7,z=5}),nil)
		t.eq(table.find(x.api.estadosDe(x.b),"bracoInutil"),nil)
	end,
	["arremesso larga até errando; desarmado não usa referência nem duplica recuperação"] = function(t)
		local x=contexto({1});x.a.ficha2.construction.unlockedRankIds={"rank/deus-do-norte/Principiante"};t.eq(x.usar(id("deus-do-norte","arremesso-de-espada"),"b"),nil)
		t.eq(x.b.pv,60);t.eq(#x.api.estado().objetos,1)
		t.ok(x.usar("mesa/ataque-basico","b")~=nil)
		t.eq(x.usar("mesa/pegar-arma",nil,{x=6,z=5}),nil);t.eq(x.api.estado().acoes.usadas,2)
		t.ok(x.usar("mesa/pegar-arma",nil,{x=6,z=5})~=nil);t.eq(#x.a.ficha2.construction.inventory,1)
	end,
	["Três Bainhas repõe livremente sem permanecer desarmado; fim remove reserva"] = function(t)
		local x=contexto({15});table.insert(x.a.ficha2.construction.purchasedIds,"talent/deus-do-norte/Principiante/tres-bainhas")
		t.eq(x.usar(id("deus-do-norte","arremesso-de-espada"),"b"),nil)
		t.eq(table.find(x.api.estadosDe(x.a),"desarmado"),nil);t.eq(#x.a.ficha2.construction.inventory,2)
		x.api.combateEncerrado();t.eq(#x.a.ficha2.construction.inventory,1);t.eq(x.a.ficha2.construction.inventory[1].equipped,true)
	end,
	["Primeiros Socorros levanta 0 PV e limite é da criatura, entre dois curadores"] = function(t)
		local x=contexto();x.b.pv=0;x.b.conditions={{id="caido",stacks=1}}
		t.eq(x.usar(id("deus-do-norte","primeiros-socorros-de-campo"),"b"),nil);t.eq(x.b.pv,4);t.eq(tem(x.b,"caido"),false)
		x.c.x=6;x.c.z=6;x.c.ficha2.construction=x.a.ficha2.construction;x.vez("c")
		t.ok(x.usar(id("deus-do-norte","primeiros-socorros-de-campo"),"b")~=nil);t.eq(x.api.estado().acoes.usadas,0)
		x.api.combateEncerrado();x.combat.active=true;x.vez("a");t.eq(x.usar(id("deus-do-norte","primeiros-socorros-de-campo"),"b"),nil)
	end,
	["Escudo armadura funciona; teste falho empurra e derruba"] = function(t)
		local x=contexto({15,1});table.insert(x.a.ficha2.construction.inventory,{name="Escudo",type="armadura",equipped=true,armorClassBonus=2})
		t.eq(x.usar(id("cavalaria-e-escudos","golpe-de-escudo"),"b"),nil);t.eq(x.b.x,8);t.ok(tem(x.b,"caido"))
	end,
	["Soberano exige Puro Escudo antes de cobrar; empurra 6 m"] = function(t)
		local x=contexto({15,1});table.insert(x.a.ficha2.construction.inventory,{name="Escudo",type="armadura",equipped=true})
		t.ok(x.usar(id("cavalaria-e-escudos","golpe-de-escudo-soberano"),"b")~=nil);t.eq(x.api.estado().acoes.usadas,0)
		table.insert(x.a.ficha2.construction.purchasedIds,"talent/cavalaria-e-escudos/Principiante/puro-escudo")
		t.eq(x.usar(id("cavalaria-e-escudos","golpe-de-escudo-soberano"),"b"),nil);t.eq(x.b.x,10)
	end,
	["Estancar apaga não mágico e não cobra para fogo mágico ativo"] = function(t)
		local x=contexto();x.b.conditions={{id="em-chamas",stacks=1}}
		t.eq(x.usar(id("cura","estancar"),"b"),nil);t.eq(tem(x.b,"em-chamas"),false)
	end,
	["IA tenta escapar com sua Ação; desarme/braço reduzem dano"] = function(t)
		local x=contexto({1,1,15,1});x.b.ficha2=nil;x.b.kind="npc";x.b.ia=true
		x.b.criatura={ca=10,bonusResistencia=0,bonusAtaque=3,patamar=1,danoPorTurno=16,deslocamentoMetros=9,categoria="humanoide",resistencias={},imunidades={}}
		t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil);x.vez("b");t.eq(x.api.turnoDoInimigo(x.b),true)
		t.ok(string.find(table.concat(x.logs,"\n"),"tenta escapar",1,true));t.ok(tem(x.b,"agarrado"))
	end,
	["Quebrar arma mundana desativa e descanso restaura; besta sem inventário recusa"] = function(t)
		local x=contexto({1});t.eq(x.usar(id("armas-pesadas","quebrar-equipamento"),"b"),nil)
		t.eq(x.b.ficha2.construction.inventory[1].equipped,false);x.api.combateEncerrado();t.eq(x.b.ficha2.construction.inventory[1].equipped,true)
	end,
	["Sangria não opera a 0 nem sem origem e não cobra nesses casos"] = function(t)
		local x=contexto();x.b.conditions={{id="envenenado",stacks=1}}
		t.ok(x.usar(id("desintoxicacao","sangria"),"b")~=nil);t.eq(x.api.estado().acoes.usadas,0);t.eq(x.a.mana,50)
		x.b.pv=0;t.ok(x.usar(id("desintoxicacao","sangria"),"b")~=nil)
	end,
 ["Sangria purga rank 2, ignora PV temp e limita aflição após reaplicar"] = function(t)
  local x=contexto();x.b.conditions={{id="envenenado",stacks=1}};x.b.ficha2.session.conditions={{conditionId="condition/envenenado",sourceRankBonus=2}};x.b.pvTemp=20
  t.eq(x.usar(id("desintoxicacao","sangria"),"b"),nil);t.eq(x.b.pv,51);t.eq(x.b.pvTemp,20);t.eq(tem(x.b,"envenenado"),false)
  x.b.conditions={{id="envenenado",stacks=1}};x.vez("b");x.vez("a")
  t.ok(x.usar(id("desintoxicacao","sangria"),"b")~=nil);t.eq(x.api.estado().acoes.usadas,0)
 end,
 ["Estancar recusa Em Chamas de Bola de Fogo sem gastar"] = function(t)
  local x=contexto({15});table.insert(x.a.ficha2.construction.unlockedRankIds,"rank/fogo/Principiante")
  t.eq(x.usar(id("fogo","bola-de-fogo"),"b"),nil);t.ok(tem(x.b,"em-chamas"))
  x.vez("c");x.vez("a");local mana=x.a.mana
  t.ok(x.usar(id("cura","estancar"),"b")~=nil);t.eq(x.a.mana,mana);t.eq(x.api.estado().acoes.usadas,0);t.ok(tem(x.b,"em-chamas"))
 end,
 ["IA com arma quebrada dá metade de dano, sem reduzir garras"] = function(t)
  local x=contexto({1,15});x.b.ficha2=nil;x.b.kind="npc";x.b.ia=true
  x.b.criatura={ca=10,bonusResistencia=0,bonusAtaque=3,patamar=1,danoPorTurno=16,deslocamentoMetros=9,categoria="humanoide",resistencias={},imunidades={}}
  t.eq(x.usar(id("armas-pesadas","quebrar-equipamento"),"b"),nil);x.vez("b");x.api.turnoDoInimigo(x.b);t.eq(x.a.pv,52)
  x.vez("a");x.b.criatura.categoria="besta"
  t.ok(x.usar("mesa/desarmar","b")~=nil);t.eq(x.api.estado().acoes.usadas,0)
 end,
 ["Quebrar escudo retira bônus CA e bloqueio; alias exige compra"] = function(t)
  local x=contexto({1});local escudo={name="Escudo",type="armadura",equipped=true,armorClassBonus=2};table.insert(x.b.ficha2.construction.inventory,escudo)
  t.eq(x.usar("mesa/quebrar-escudo","b"),nil);t.eq(escudo.equipped,false);t.eq(x.b.a16CaQuebrada,2)
  x.vez("b");t.ok(x.usar("mesa/quebrar-escudo","a")~=nil);t.eq(x.api.estado().acoes.usadas,0)
  x.api.descartarTudo();t.eq(escudo.equipped,true);t.eq(x.b.a16CaQuebrada,nil)
 end,
 ["Soberano deixa cobertura parcial de um ataque e expira posição na próxima vez"] = function(t)
  local x=contexto({15,1,8,8});table.insert(x.a.ficha2.construction.inventory,{name="Escudo",type="armadura",equipped=true})
  table.insert(x.a.ficha2.construction.purchasedIds,"talent/cavalaria-e-escudos/Principiante/puro-escudo")
  t.eq(x.usar(id("cavalaria-e-escudos","golpe-de-escudo-soberano"),"b"),nil)
  x.a.x=4;x.c.x=6;x.c.z=5;x.api.moveu(x.c,7,5);x.c.x=5;x.c.z=5;x.api.moveu(x.c,6,5)
  t.ok(table.find(x.api.estadosDe(x.c),"coberturaProximoAtaque"))
  x.b.x=6;x.vez("b");t.eq(x.usar("mesa/ataque-basico","c"),nil);t.eq(x.c.pv,60)
  t.eq(table.find(x.api.estadosDe(x.c),"coberturaProximoAtaque"),nil)
  t.eq(x.usar("mesa/ataque-basico","c"),nil);t.ok(x.c.pv<60)
 end,

 ["Corte aparado não desarma apesar de teste pré-rolado falho"] = function(t)
  local x=contexto({6,1});x.b.ficha2.construction.unlockedRankIds={"rank/deus-da-agua-corpo/Principiante"};x.b.ficha2.construction.purchasedIds={id("deus-da-agua-corpo","aparar")}
  x.api.reacoes.decidir=function() return "aparar" end
  t.eq(x.usar(id("deus-da-espada","corte-de-braco"),"b"),nil)
  t.eq(x.b.pv,60);t.eq(x.b.ficha2.construction.inventory[1].equipped,true);t.eq(#x.api.estado().objetos,0)
 end,
 ["Arremesso não oferece Aparar de corpo a corpo"] = function(t)
  local x=contexto({6});x.b.ficha2.construction.unlockedRankIds={"rank/deus-da-agua-corpo/Principiante"};x.b.ficha2.construction.purchasedIds={id("deus-da-agua-corpo","aparar")}
  local perguntas=0;x.api.reacoes.decidir=function() perguntas+=1;return "aparar" end
  t.eq(x.usar(id("deus-do-norte","arremesso-de-espada"),"b"),nil);t.eq(perguntas,0);t.ok(x.b.pv<60)
 end,

 ["IA abre corredor golpeando barreira que não consegue contornar"] = function(t)
  local x=contexto({15});x.b.x=8;x.b.ficha2=nil;x.b.kind="npc";x.b.ia=true;x.c.pv=0
  x.b.criatura={ca=10,bonusResistencia=0,bonusAtaque=3,patamar=1,danoPorTurno=16,deslocamentoMetros=9,categoria="humanoide",resistencias={},imunidades={}}
  for i=1,100 do x.terrain[i..":4"]="parede";x.terrain[i..":6"]="parede" end
  t.eq(x.usar(id("terra","muro-de-terra"),nil,{x=6,z=5}),nil);x.vez("b");x.api.turnoDoInimigo(x.b)
  t.eq(x.a.pv,60);t.eq(x.api.estado().muros[1].pv,24)
 end,

 ["arrastar físico em frente não trata a casa antiga do par como obstáculo"] = function(t)
  local x=contexto({15,1});t.eq(x.usar(id("armas-pesadas","agarrao"),"b"),nil)
  t.eq(x.usar("mesa/arrastar",nil,{x=8,z=5}),nil);t.eq(x.a.x,7);t.eq(x.b.x,8);t.ok(tem(x.b,"agarrado"))
 end,

 ["Estancar encerra marcador de sangramento do resolvedor genérico"] = function(t)
  local x=contexto({}, { ["teste/sangramento"]={tipo="efeito",basico=true,acoes=0,alvo="si",estados={{nome="sangramento",valor=true}}} })
  t.eq(x.usar("teste/sangramento"),nil);t.ok(table.find(x.api.estadosDe(x.a),"sangramento"))
  t.eq(x.usar(id("cura","estancar"),"a"),nil);t.eq(table.find(x.api.estadosDe(x.a),"sangramento"),nil);t.eq(x.api.estado().acoes.usadas,2)
 end,

 ["Mão de Terra termina se conjurador ficar Caído ainda com PV"] = function(t)
  local x=contexto({1});t.eq(x.usar(id("terra","mao-de-terra"),"b"),nil)
  x.a.conditions={{id="caido",stacks=1}};x.vez("b");t.eq(tem(x.b,"agarrado"),false);t.eq(tem(x.b,"atolado"),false)
 end,

	["pedidos inválidos/fora da vez/não dono não cobram"] = function(t)
		local x=contexto();t.ok(x.handlers.usarHabilidade({UserId=123},false,false)~=nil)
		t.ok(x.usar(id("terra","mao-de-terra"),"b",nil,999)~=nil);t.eq(x.api.estado().acoes.usadas,0)
		t.ok(x.usar("mesa/arrastar",nil,{x=0/0,z=5})~=nil);t.eq(x.api.estado().acoes.usadas,0)
		t.eq(x.handlers.usarHabilidade({UserId=123},{tokenId="b",habilidadeId="mesa/escapar"},false),"Aguarde a vez dessa ficha.")
	end,
}

end)()
local t={eq=function(a,b,m) assert(a==b,(m or "").." esperado "..tostring(b)..", obtido "..tostring(a)) end,ok=function(v,m) assert(v,m or "condição falsa") end,fails=function(f,m) assert(not pcall(f),m or "era esperado erro") end}
local p,f=0,0;local erros={};for nome,teste in spec do local ok,e=pcall(teste,t);if ok then p+=1 else f+=1;table.insert(erros,nome..": "..tostring(e)) end end
return p.." ok, "..f.." falhas | "..table.concat(erros," | ")