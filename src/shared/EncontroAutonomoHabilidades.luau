-- Adapta somente habilidades já disponíveis na ficha pessoal ao encontro J2.
-- Resolução pura; custos, turno, alvo e aplicação de PV ficam no serviço.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fogo = require(ReplicatedStorage.Shared.Regras.Fogo)
local Habilidades = require(ReplicatedStorage.Shared.Regras.Habilidades)
local Execucao = require(ReplicatedStorage.Shared.Regras.Execucao)
local Combate = require(ReplicatedStorage.Shared.Regras.Combate)
local Maestrias = require(ReplicatedStorage.Shared.Regras.Maestrias)
local Arvores = require(ReplicatedStorage.Shared.Regras.ArvoresPrincipiante)
local Estado = require(ReplicatedStorage.Shared.Regras.EstadoHabilidades)
local Areas = require(ReplicatedStorage.Shared.AreaHabilidade)
local Terreno = require(ReplicatedStorage.Shared.EncontroAutonomoTerreno)
local Movimento = require(ReplicatedStorage.Shared.EncontroAutonomoMovimento)
local Agarrar = require(ReplicatedStorage.Shared.Regras.Agarrar)
local Tecnicas = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoTecnicas)

local EncontroAutonomoHabilidades = {}
local BRASA = "ability/fogo/Principiante/brasa"
local FAGULHA = "ability/fogo/Principiante/fagulha"
local BOLA_DE_FOGO = "ability/fogo/Principiante/bola-de-fogo"
local TOQUE_ESCALDANTE = "ability/fogo/Principiante/toque-escaldante"
local MURO_DE_CHAMAS = "ability/fogo/Principiante/muro-de-chamas"
local CLARAO = "ability/fogo/Principiante/clarao"
local CURA = "ability/cura/Principiante/cura"
local VIGOR_EMPRESTADO = "ability/cura/Principiante/vigor-emprestado"
local RAJADA_CURTA = "ability/vento/Principiante/rajada-curta"
local PEDRISCO = "ability/terra/Principiante/pedrisco"
local LANCA_DE_PEDRA = "ability/terra/Principiante/lanca-de-pedra"
local ATOLEIRO = "ability/terra/Principiante/atoleiro"
local MURO_DE_TERRA = "ability/terra/Principiante/muro-de-terra"
local DARDO_ARCANO = "ability/teorica/Principiante/dardo-arcano"
local ANTEPARO_TEORICO = "ability/teorica/Principiante/anteparo-teorico"
local ESCUDO_DE_AGUA = "ability/agua/Principiante/escudo-de-agua"
local NEVOA_DENSA = "ability/agua/Principiante/nevoa-densa"
local SOPRO_DE_POEIRA = "ability/vento/Principiante/sopro-de-poeira"
local PASSO_DE_VENTO = "ability/vento/Principiante/passo-de-vento"
local VACUO_LOCALIZADO = "ability/vento/Principiante/vacuo-localizado"
local MAO_DE_TERRA = "ability/terra/Principiante/mao-de-terra"
local ESCAPAR_MAO = "mesa/mao-de-terra-escapar"
local ARRASTAR_MAO = "mesa/mao-de-terra-arrastar"
local SOLTAR_MAO = "mesa/mao-de-terra-soltar"
local BALA_DE_PEDRA = "ability/terra/Principiante/bala-de-pedra"
local LAMINA_DE_VENTO = "ability/vento/Principiante/lamina-de-vento"
local RESPINGO = "ability/agua/Principiante/respingo"
local BOLA_DE_AGUA = "ability/agua/Principiante/bola-de-agua"
local FLECHA_DE_AGUA = "ability/agua/Principiante/flecha-de-agua"
local IMPACTO_DE_GELO = "ability/agua/Principiante/impacto-de-gelo"
local EMPURRAO = "ability/vento/Principiante/empurrao"
local LAMINA_DE_GELO = "ability/agua/Principiante/lamina-de-gelo"
local LAMINA_GELO_FORCA = "mesa/lamina-de-gelo-forca"
local LAMINA_GELO_INTELECTO = "mesa/lamina-de-gelo-intelecto"
local PREFIXO_ALVO_CLARAO = "clarao:"

local function inteiro(valor)
	return type(valor) == "number" and valor == valor and valor % 1 == 0
end

function EncontroAutonomoHabilidades.disponiveis(ator)
	if type(ator) ~= "table" or ator.kind ~= "jogador" or type(ator.ficha) ~= "table" then
		return {}
	end
	local construcao = ator.ficha.construction
	if type(construcao) ~= "table" or type(construcao.unlockedRankIds) ~= "table"
		or type(construcao.purchasedIds) ~= "table"
	then
		return {}
	end
	local conhecidas = Fogo.habilidadesDe(ator.ficha)
	local disponiveis = {}
	if table.find(conhecidas, BRASA) then table.insert(disponiveis, BRASA) end
	if table.find(conhecidas, FAGULHA) then table.insert(disponiveis, FAGULHA) end
	if table.find(conhecidas, BOLA_DE_FOGO) then table.insert(disponiveis, BOLA_DE_FOGO) end
	if table.find(conhecidas, TOQUE_ESCALDANTE) then table.insert(disponiveis, TOQUE_ESCALDANTE) end
	if table.find(conhecidas, MURO_DE_CHAMAS) then table.insert(disponiveis, MURO_DE_CHAMAS) end
	if table.find(conhecidas, CLARAO) then table.insert(disponiveis, CLARAO) end
	if table.find(construcao.purchasedIds, CURA) then table.insert(disponiveis, CURA) end
	if table.find(construcao.purchasedIds, VIGOR_EMPRESTADO) then
		table.insert(disponiveis, VIGOR_EMPRESTADO)
	end
	if table.find(construcao.unlockedRankIds, "rank/teorica/Principiante") then
		if table.find(construcao.purchasedIds, DARDO_ARCANO) then table.insert(disponiveis, DARDO_ARCANO) end
		if table.find(construcao.purchasedIds, ANTEPARO_TEORICO) then table.insert(disponiveis, ANTEPARO_TEORICO) end
	end
	-- Truque de 0 PA: vem com o Principiante de Vento, sem compra separada.
	if table.find(construcao.unlockedRankIds, "rank/vento/Principiante") then
		table.insert(disponiveis, RAJADA_CURTA)
		if table.find(construcao.purchasedIds, LAMINA_DE_VENTO) then
			table.insert(disponiveis, LAMINA_DE_VENTO)
		end
		if table.find(construcao.purchasedIds, EMPURRAO) then
			table.insert(disponiveis, EMPURRAO)
		end
		if table.find(construcao.purchasedIds, SOPRO_DE_POEIRA) then
			table.insert(disponiveis, SOPRO_DE_POEIRA)
		end
		if table.find(construcao.purchasedIds, PASSO_DE_VENTO) then
			table.insert(disponiveis, PASSO_DE_VENTO)
		end
		if table.find(construcao.purchasedIds, VACUO_LOCALIZADO) then
			table.insert(disponiveis, VACUO_LOCALIZADO)
		end
	end
	-- Truque de 0 PA: vem com o Principiante de Terra, sem compra separada.
	if table.find(construcao.unlockedRankIds, "rank/terra/Principiante") then
		table.insert(disponiveis, PEDRISCO)
		if table.find(construcao.purchasedIds, ATOLEIRO) then
			table.insert(disponiveis, ATOLEIRO)
		end
		if table.find(construcao.purchasedIds, LANCA_DE_PEDRA) then
			table.insert(disponiveis, LANCA_DE_PEDRA)
		end
		if table.find(construcao.purchasedIds, BALA_DE_PEDRA) then
			table.insert(disponiveis, BALA_DE_PEDRA)
		end
		if table.find(construcao.purchasedIds, MURO_DE_TERRA) then
			table.insert(disponiveis, MURO_DE_TERRA)
		end
		if table.find(construcao.purchasedIds, MAO_DE_TERRA) then
			table.insert(disponiveis, MAO_DE_TERRA)
		end
	end
	if table.find(construcao.unlockedRankIds, "rank/agua/Principiante")
		and table.find(construcao.purchasedIds, RESPINGO)
	then
		table.insert(disponiveis, RESPINGO)
	end
	if table.find(construcao.unlockedRankIds, "rank/agua/Principiante")
		and table.find(construcao.purchasedIds, BOLA_DE_AGUA)
	then
		table.insert(disponiveis, BOLA_DE_AGUA)
	end
	if table.find(construcao.unlockedRankIds, "rank/agua/Principiante")
		and table.find(construcao.purchasedIds, FLECHA_DE_AGUA)
	then
		table.insert(disponiveis, FLECHA_DE_AGUA)
	end
	if table.find(construcao.unlockedRankIds, "rank/agua/Principiante")
		and table.find(construcao.purchasedIds, IMPACTO_DE_GELO)
	then
		table.insert(disponiveis, IMPACTO_DE_GELO)
	end
	if table.find(construcao.unlockedRankIds, "rank/agua/Principiante")
		and table.find(construcao.purchasedIds, LAMINA_DE_GELO)
	then
		table.insert(disponiveis, LAMINA_DE_GELO)
	end
	if table.find(construcao.unlockedRankIds, "rank/agua/Principiante")
		and table.find(construcao.purchasedIds, ESCUDO_DE_AGUA)
	then
		table.insert(disponiveis, ESCUDO_DE_AGUA)
	end
	if table.find(construcao.unlockedRankIds, "rank/agua/Principiante")
		and table.find(construcao.purchasedIds, NEVOA_DENSA)
	then
		table.insert(disponiveis, NEVOA_DENSA)
	end
	local armaGelo = (ator.estadosDeCombate or {}).armaGelo
	if type(armaGelo) == "table" and armaGelo.valor == true then
		table.insert(disponiveis, LAMINA_GELO_FORCA)
		table.insert(disponiveis, LAMINA_GELO_INTELECTO)
	end
	for _, id in ipairs(Tecnicas.disponiveis(ator)) do table.insert(disponiveis, id) end
	table.insert(disponiveis, "mesa/defender")
	return disponiveis
end

function EncontroAutonomoHabilidades.mecanica(abilityId)
	if Tecnicas.mecanica(abilityId) then return Tecnicas.mecanica(abilityId) end
	if abilityId == "mesa/defender" then return Maestrias.MECANICAS[abilityId] end
	if abilityId == ESCAPAR_MAO or abilityId == ARRASTAR_MAO then return { acoes = 1, pm = 0 } end
	if abilityId == SOLTAR_MAO then return { acoes = 0, pm = 0 } end
	if abilityId == LAMINA_GELO_FORCA or abilityId == LAMINA_GELO_INTELECTO then
		local mecanica = table.clone(Execucao.MECANICAS[abilityId])
		mecanica.alcanceCasas = 1
		return mecanica
	end
	if abilityId == DARDO_ARCANO or abilityId == CURA or abilityId == VIGOR_EMPRESTADO or abilityId == RAJADA_CURTA or abilityId == PEDRISCO or abilityId == BALA_DE_PEDRA or abilityId == LANCA_DE_PEDRA or abilityId == ATOLEIRO or abilityId == MURO_DE_TERRA or abilityId == ANTEPARO_TEORICO or abilityId == MAO_DE_TERRA
		or abilityId == LAMINA_DE_VENTO
		or abilityId == RESPINGO or abilityId == BOLA_DE_AGUA or abilityId == FLECHA_DE_AGUA
		or abilityId == IMPACTO_DE_GELO or abilityId == EMPURRAO or abilityId == LAMINA_DE_GELO
		or abilityId == ESCUDO_DE_AGUA or abilityId == NEVOA_DENSA or abilityId == SOPRO_DE_POEIRA or abilityId == PASSO_DE_VENTO
		or abilityId == VACUO_LOCALIZADO
	then
		return Arvores.MECANICAS[abilityId]
	end
	if abilityId == FAGULHA or abilityId == MURO_DE_CHAMAS or abilityId == CLARAO then return Fogo.MECANICAS[abilityId] end
	if abilityId == BRASA or abilityId == BOLA_DE_FOGO or abilityId == TOQUE_ESCALDANTE then
		return Fogo.MECANICAS[abilityId]
	end
	return nil
end

function EncontroAutonomoHabilidades.conjurarLaminaDeGelo(atacante)
	local mecanica = Arvores.MECANICAS[LAMINA_DE_GELO]
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), LAMINA_DE_GELO)
	then return nil, "Lâmina de Gelo exige compra e rank de Água." end
	if not inteiro(atacante.pv) or atacante.pv <= 0 or not inteiro(atacante.pm or 0)
		or (atacante.pm or 0) < mecanica.pm
	then return nil, "PV/PM inválidos para conjurar Lâmina de Gelo." end
	return {
		actorId = atacante.id, targetId = atacante.id, action = "use-ability", abilityId = LAMINA_DE_GELO,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm,
		weaponDurationRounds = 10,
	}, nil
end

local function regrasCondicoes(catalogo)
	local regras = {}
	for _, entrada in ipairs(catalogo.POR_ESPECIE.condition or {}) do
		local dados = entrada.data
		if type(dados) == "table" and type(dados.id) == "string" and type(dados.mecanica) == "table" then
			regras[dados.id] = dados.mecanica
		end
	end
	return regras
end

function EncontroAutonomoHabilidades.usarClarao(rng, atacante, atores, catalogo, centroX, centroZ)
	local mecanica = Fogo.MECANICAS[CLARAO]
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
		or type(catalogo.POR_ESPECIE) ~= "table" or type(atores) ~= "table"
	then return nil, "Dependências de Clarão indisponíveis." end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), CLARAO)
	then return nil, "Clarão exige habilidade comprada e ficha de Fogo." end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(atacante.pv) or atacante.pv <= 0
		or type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm
	then return nil, "Estado ou PM do conjurador inválido para Clarão." end
	if not inteiro(centroX) or not inteiro(centroZ) or centroX < 1 or centroX > 20 or centroZ < 1 or centroZ > 20 then
		return nil, "Centro do Clarão inválido."
	end
	local ficha = atacante.ficha
	local atributos = ficha.calculated and ficha.calculated.attributes
	if type(atributos) ~= "table" then return nil, "Ficha do conjurador incompleta." end
	local regras = regrasCondicoes(catalogo)
	local cdBase = mecanica.resistencia.cdBase
	local efeitos = {}
	for _, alvo in ipairs(atores) do
		if type(alvo) == "table" and alvo.id ~= atacante.id and alvo.defeated ~= true
			and (alvo.kind == "jogador" or alvo.kind == "criatura")
			and inteiro(alvo.x) and inteiro(alvo.z)
		then
			local dx, dz = alvo.x - centroX, alvo.z - centroZ
			if dx * dx + dz * dz <= mecanica.raioCasas * mecanica.raioCasas then
				local fichaAlvo = alvo.ficha
				local fichaCriatura = alvo.fichaCriatura or {}
				local resistencia = function(atributo)
					if alvo.kind == "criatura" then
						return math.ceil((fichaCriatura.bonusAtaque or 0) / 2)
					end
					local stats = fichaAlvo and fichaAlvo.calculated
					return Estado.resistencia(stats and stats.attributes, stats and stats.highestRankBonus or 0, atributo)
				end
				table.insert(efeitos, {
					id = alvo.id, ca = alvo.ca or 10, kind = alvo.kind,
					condicoes = alvo.condicoes or {}, resistencia = resistencia,
					resistencias = fichaCriatura.resistencias or {},
					imunidades = fichaCriatura.imunidades or {},
					patamar = fichaCriatura.patamar or (fichaAlvo and fichaAlvo.calculated and fichaAlvo.calculated.highestRankBonus) or 0,
				})
			end
		end
	end
	local resultado = Habilidades.resolver(rng, mecanica, {
		id = atacante.id, bc = Execucao.bc(ficha, "fogo", catalogo), pv = atacante.pv,
		pvMax = atacante.pvMax or atacante.pv, condicoes = atacante.condicoes or {}, atributos = atributos,
	}, efeitos, regras)
	local alvos = {}
	for _, efeito in ipairs(resultado) do
		table.insert(alvos, {
			actorId = efeito.alvoId, resistance = efeito.resistencia,
			applies = efeito.aplica or {}, notes = efeito.notas or {},
		})
	end
	return {
		actorId = atacante.id, action = "use-ability", abilityId = CLARAO,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm, dc = cdBase + Execucao.bc(ficha, "fogo", catalogo),
		center = { x = centroX, z = centroZ }, radiusHouses = mecanica.raioCasas,
		targets = alvos,
	}, nil
end

EncontroAutonomoHabilidades.ALVO_ATOLEIRO = "area:atoleiro"
EncontroAutonomoHabilidades.ATOLEIRO = ATOLEIRO
EncontroAutonomoHabilidades.LAMINA_DE_GELO = LAMINA_DE_GELO
EncontroAutonomoHabilidades.LAMINA_GELO_FORCA = LAMINA_GELO_FORCA
EncontroAutonomoHabilidades.LAMINA_GELO_INTELECTO = LAMINA_GELO_INTELECTO

local function celulasCirculo(xCentro, zCentro, raioCasas)
	if not inteiro(xCentro) or not inteiro(zCentro) or not inteiro(raioCasas) or raioCasas < 0 then return nil end
	local resultado = {}
	for x = math.max(1, xCentro - raioCasas), math.min(20, xCentro + raioCasas) do
		for z = math.max(1, zCentro - raioCasas), math.min(20, zCentro + raioCasas) do
			local dx, dz = x - xCentro, z - zCentro
			if dx * dx + dz * dz <= raioCasas * raioCasas then
				table.insert(resultado, { x = x, z = z })
			end
		end
	end
	return resultado
end

function EncontroAutonomoHabilidades.alvoClarao(centroX, centroZ)
	if not inteiro(centroX) or not inteiro(centroZ) or centroX < 1 or centroX > 20 or centroZ < 1 or centroZ > 20 then
		return nil
	end
	return string.format("%s%d:%d", PREFIXO_ALVO_CLARAO, centroX, centroZ)
end

function EncontroAutonomoHabilidades.coordenadasAlvoClarao(targetId)
	if type(targetId) ~= "string" then return nil end
	local x, z = string.match(targetId, "^clarao:(%d+):(%d+)$")
	x, z = tonumber(x), tonumber(z)
	if EncontroAutonomoHabilidades.alvoClarao(x, z) ~= targetId then return nil end
	return x, z
end

function EncontroAutonomoHabilidades.preverClarao(atacante, centroX, centroZ, celulasBloqueadas, perigos, turno)
	local mecanica = Fogo.MECANICAS[CLARAO]
	if type(atacante) ~= "table" or atacante.kind ~= "jogador"
		or not inteiro(atacante.x) or not inteiro(atacante.z)
		or not EncontroAutonomoHabilidades.alvoClarao(centroX, centroZ)
		or not Terreno.visaoLivre(atacante.x, atacante.z, centroX, centroZ, celulasBloqueadas, perigos, turno)
	then return nil end
	return {
		targetId = EncontroAutonomoHabilidades.alvoClarao(centroX, centroZ),
		center = { x = centroX, z = centroZ },
		cells = celulasCirculo(centroX, centroZ, mecanica.raioCasas),
	}
end

function EncontroAutonomoHabilidades.celulasAtoleiro(xCentro, zCentro)
	return celulasCirculo(xCentro, zCentro, Arvores.MECANICAS[ATOLEIRO].raioCasas)
end

function EncontroAutonomoHabilidades.usarAtoleiro(rng, atacante, atores, catalogo)
	local mecanica = Arvores.MECANICAS[ATOLEIRO]
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function" or type(atores) ~= "table"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
	then return nil, "Dependências de Atoleiro indisponíveis." end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), ATOLEIRO)
	then return nil, "Atoleiro exige compra e rank de Terra." end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(atacante.pv) or atacante.pv <= 0
		or type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm
	then return nil, "Estado ou PM inválidos para Atoleiro." end
	local ficha = atacante.ficha
	local atributos = ficha.calculated and ficha.calculated.attributes
	if type(atributos) ~= "table" then return nil, "Ficha do conjurador incompleta." end
	local bc = Execucao.bc(ficha, "terra", catalogo)
	local alvos = {}
	for _, alvo in ipairs(atores) do
		if type(alvo) == "table" and alvo.id ~= atacante.id and alvo.defeated ~= true
			and (alvo.kind == "jogador" or alvo.kind == "criatura")
			and inteiro(alvo.x) and inteiro(alvo.z) and type(alvo.pv) == "number" and alvo.pv > 0
		then
			local dx, dz = alvo.x - atacante.x, alvo.z - atacante.z
			if dx * dx + dz * dz <= mecanica.raioCasas * mecanica.raioCasas then
				local fichaAlvo = alvo.ficha
				local fichaCriatura = alvo.fichaCriatura or {}
				local resistencia = function(atributo)
					if alvo.kind == "criatura" then return math.ceil((fichaCriatura.bonusAtaque or 0) / 2) end
					local stats = fichaAlvo and fichaAlvo.calculated
					return Estado.resistencia(stats and stats.attributes, stats and stats.highestRankBonus or 0, atributo)
				end
				table.insert(alvos, { id = alvo.id, kind = alvo.kind, condicoes = alvo.condicoes or {},
					resistencias = fichaCriatura.resistencias or {}, imunidades = fichaCriatura.imunidades or {},
					resistencia = resistencia })
			end
		end
	end
	local resolvidos = Habilidades.resolver(rng, mecanica, {
		id = atacante.id, bc = bc, bonusDeRank = Execucao.bonusDeRankDa(ficha, "terra"),
		pv = atacante.pv, pvMax = atacante.pvMax or atacante.pv, condicoes = atacante.condicoes or {},
		atributos = atributos,
	}, alvos, regrasCondicoes(catalogo))
	local efeitos = {}
	for _, efeito in ipairs(resolvidos) do
		table.insert(efeitos, { actorId = efeito.alvoId, resistance = efeito.resistencia,
			applies = efeito.aplica or {}, notes = efeito.notas or {} })
	end
	return { actorId = atacante.id, action = "use-ability", abilityId = ATOLEIRO,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm, center = { x = atacante.x, z = atacante.z },
		radiusHouses = mecanica.raioCasas, targets = efeitos,
		zone = { center = { x = atacante.x, z = atacante.z }, cells = EncontroAutonomoHabilidades.celulasAtoleiro(atacante.x, atacante.z),
			durationRounds = mecanica.zonaApos.duracaoRodadas } }, nil
end

function EncontroAutonomoHabilidades.preverMuro(atacante, fimX, fimZ)
	local mecanica = Fogo.MECANICAS[MURO_DE_CHAMAS]
	if type(atacante) ~= "table" or not inteiro(atacante.x) or not inteiro(atacante.z)
		or not inteiro(fimX) or not inteiro(fimZ)
	then return nil end
	local dx, dz = fimX - atacante.x, fimZ - atacante.z
	local tamanho = math.max(math.abs(dx), math.abs(dz))
	if tamanho < 1 or tamanho > mecanica.comprimentoCasas
		or (dx ~= 0 and dz ~= 0 and math.abs(dx) ~= math.abs(dz))
	then return nil end
	local passoX = if dx == 0 then 0 elseif dx > 0 then 1 else -1
	local passoZ = if dz == 0 then 0 elseif dz > 0 then 1 else -1
	local casas = {}
	for passo = 1, tamanho do
		local x, z = atacante.x + passoX * passo, atacante.z + passoZ * passo
		if x < 1 or x > 20 or z < 1 or z > 20 then return nil end
		table.insert(casas, { x = x, z = z })
	end
	return {
		targetId = string.format("muro:%d:%d:%d:%d:%d", casas[1].x, casas[1].z, passoX, passoZ, tamanho),
		cells = casas,
	}
end

function EncontroAutonomoHabilidades.criarMuro(atacante, targetId)
	local mecanica = Fogo.MECANICAS[MURO_DE_CHAMAS]
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), MURO_DE_CHAMAS)
	then return nil, "A ficha não conhece Muro de Chamas." end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(atacante.pv) or atacante.pv <= 0
		or type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm
	then return nil, "Estado ou PM do conjurador inválido para Muro de Chamas." end
	if type(targetId) ~= "string" then return nil, "Muro de Chamas exige uma linha válida." end
	local x, z, dx, dz, tamanho = string.match(targetId, "^muro:(%d+):(%d+):(-?%d+):(-?%d+):(%d+)$")
	x, z, dx, dz, tamanho = tonumber(x), tonumber(z), tonumber(dx), tonumber(dz), tonumber(tamanho)
	if not inteiro(x) or not inteiro(z) or not inteiro(dx) or not inteiro(dz) or not inteiro(tamanho)
		or (dx == 0 and dz == 0) or math.abs(dx) > 1 or math.abs(dz) > 1
		or tamanho < 1 or tamanho > mecanica.comprimentoCasas
		or x ~= atacante.x + dx or z ~= atacante.z + dz
	then return nil, "Linha do Muro de Chamas inválida ou fora de alcance." end
	local casas = {}
	for passo = 0, tamanho - 1 do
		local casaX, casaZ = x + dx * passo, z + dz * passo
		if casaX < 1 or casaX > 20 or casaZ < 1 or casaZ > 20 then
			return nil, "A linha do Muro de Chamas sai dos limites da grade."
		end
		table.insert(casas, { x = casaX, z = casaZ })
	end
	return {
		actorId = atacante.id, action = "use-ability", abilityId = MURO_DE_CHAMAS,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm,
		durationRounds = mecanica.duracaoRodadas, cells = casas,
	}, nil
end

function EncontroAutonomoHabilidades.preverMuroDeTerra(atacante, centroX, centroZ, celulasBloqueadas, perigos, turno)
	local mecanica = Arvores.MECANICAS[MURO_DE_TERRA]
	if type(atacante) ~= "table" or not inteiro(atacante.x) or not inteiro(atacante.z)
		or not inteiro(centroX) or not inteiro(centroZ)
	then return nil end
	local bloqueadas = Terreno.chavesDe(celulasBloqueadas)
	local function casaBloqueada(x, z) return bloqueadas[tostring(x) .. ":" .. tostring(z)] == true end
	local function linhaDeVisaoBloqueada(x, z)
		return not Terreno.visaoLivre(atacante.x, atacante.z, x, z, celulasBloqueadas, perigos, turno)
	end
	if linhaDeVisaoBloqueada(centroX, centroZ) then return nil end
	local desenhada = Areas.zona(atacante, mecanica, { x = centroX, z = centroZ }, casaBloqueada, linhaDeVisaoBloqueada)
	if type(desenhada) ~= "table" or #desenhada ~= mecanica.comprimentoCasas then return nil end
	local casas = {}
	for _, casa in ipairs(desenhada) do table.insert(casas, { x = casa[1], z = casa[2] }) end
	return { targetId = string.format("muro-terra:%d:%d", centroX, centroZ), cells = casas }
end

function EncontroAutonomoHabilidades.criarMuroDeTerra(atacante, targetId, celulasBloqueadas, perigos, turno)
	local mecanica = Arvores.MECANICAS[MURO_DE_TERRA]
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), MURO_DE_TERRA)
	then return nil, "A ficha não conhece Muro de Terra." end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(atacante.pv) or atacante.pv <= 0
		or type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm
	then return nil, "Estado ou PM do conjurador inválido para Muro de Terra." end
	if type(targetId) ~= "string" then return nil, "Muro de Terra exige um centro válido." end
	local x, z = string.match(targetId, "^muro%-terra:(%d+):(%d+)$")
x, z = tonumber(x), tonumber(z)
	local previsao = if inteiro(x) and inteiro(z)
		then EncontroAutonomoHabilidades.preverMuroDeTerra(atacante, x, z, celulasBloqueadas, perigos, turno)
		else nil
	if not previsao or previsao.targetId ~= targetId then return nil, "Centro do Muro de Terra inválido ou fora de alcance." end
	return {
		actorId = atacante.id, action = "use-ability", abilityId = MURO_DE_TERRA,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm,
		durationRounds = mecanica.duracaoRodadas, zonePv = mecanica.pvZona,
		cells = previsao.cells,
	}, nil
end

function EncontroAutonomoHabilidades.preverAnteparo(atacante, centroX, centroZ, celulasBloqueadas, perigos, turno)
	local mecanica = Arvores.MECANICAS[ANTEPARO_TEORICO]
	if type(atacante) ~= "table" or not inteiro(atacante.x) or not inteiro(atacante.z)
		or not inteiro(centroX) or not inteiro(centroZ)
	then return nil end
	local bloqueadas = Terreno.chavesDe(celulasBloqueadas)
	local function bloqueada(x, z) return bloqueadas[tostring(x) .. ":" .. tostring(z)] == true end
	local function visaoBloqueada(x, z)
		return not Terreno.visaoLivre(atacante.x, atacante.z, x, z, celulasBloqueadas, perigos, turno)
	end
	local desenhada = Areas.zona(atacante, mecanica, { x = centroX, z = centroZ }, bloqueada, visaoBloqueada)
	if type(desenhada) ~= "table" or #desenhada ~= mecanica.comprimentoCasas then return nil end
	local casas = {}
	for _, casa in ipairs(desenhada) do table.insert(casas, { x = casa[1], z = casa[2] }) end
	return { targetId = string.format("anteparo:%d:%d", centroX, centroZ), cells = casas }
end

function EncontroAutonomoHabilidades.criarAnteparo(atacante, targetId, celulasBloqueadas, perigos, turno)
	local mecanica = Arvores.MECANICAS[ANTEPARO_TEORICO]
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), ANTEPARO_TEORICO)
	then return nil, "A ficha não conhece Anteparo Teórico." end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(atacante.pv) or atacante.pv <= 0
		or type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm
	then return nil, "Estado ou PM do conjurador inválido para Anteparo." end
	local x, z = string.match(targetId or "", "^anteparo:(%d+):(%d+)$")
	x, z = tonumber(x), tonumber(z)
	local previsao = if inteiro(x) and inteiro(z)
		then EncontroAutonomoHabilidades.preverAnteparo(atacante, x, z, celulasBloqueadas, perigos, turno)
		else nil
	if not previsao or previsao.targetId ~= targetId then return nil, "Centro do Anteparo inválido ou fora de alcance." end
	return {
		actorId = atacante.id, action = "use-ability", abilityId = ANTEPARO_TEORICO,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm,
		durationRounds = mecanica.duracaoRodadas, zonePv = mecanica.pvZona,
		cells = previsao.cells,
	}, nil
end

function EncontroAutonomoHabilidades.preverEscudoDeAgua(atacante, centroX, centroZ, celulasBloqueadas, perigos, turno)
	local mecanica = Arvores.MECANICAS[ESCUDO_DE_AGUA]
	if type(atacante) ~= "table" or not inteiro(atacante.x) or not inteiro(atacante.z)
		or not inteiro(centroX) or not inteiro(centroZ)
	then return nil end
	if not Terreno.visaoLivre(atacante.x, atacante.z, centroX, centroZ, celulasBloqueadas, perigos, turno) then
		return nil
	end
	local bloqueadas = Terreno.chavesDe(celulasBloqueadas)
	local function bloqueada(x, z) return bloqueadas[tostring(x) .. ":" .. tostring(z)] == true end
	local function visaoBloqueada(x, z)
		return not Terreno.visaoLivre(atacante.x, atacante.z, x, z, celulasBloqueadas, perigos, turno)
	end
	local desenhada = Areas.zona(atacante, mecanica, { x = centroX, z = centroZ }, bloqueada, visaoBloqueada)
	if type(desenhada) ~= "table" or #desenhada ~= mecanica.comprimentoCasas then return nil end
	local casas = {}
	for _, casa in ipairs(desenhada) do table.insert(casas, { x = casa[1], z = casa[2] }) end
	return { targetId = string.format("escudo-agua:%d:%d", centroX, centroZ), cells = casas }
end

function EncontroAutonomoHabilidades.criarEscudoDeAgua(atacante, targetId, celulasBloqueadas, perigos, turno)
	local mecanica = Arvores.MECANICAS[ESCUDO_DE_AGUA]
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), ESCUDO_DE_AGUA)
	then return nil, "Escudo de Água exige compra e rank de Água." end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(atacante.pv) or atacante.pv <= 0
		or type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm
	then return nil, "Estado ou PM do conjurador inválido para Escudo de Água." end
	local x, z = string.match(targetId or "", "^escudo%-agua:(%d+):(%d+)$")
	x, z = tonumber(x), tonumber(z)
	local previsao = if inteiro(x) and inteiro(z)
		then EncontroAutonomoHabilidades.preverEscudoDeAgua(atacante, x, z, celulasBloqueadas, perigos, turno)
		else nil
	if not previsao or previsao.targetId ~= targetId then return nil, "Centro do Escudo de Água inválido ou fora de alcance." end
	return {
		actorId = atacante.id, action = "use-ability", abilityId = ESCUDO_DE_AGUA,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm,
		durationRounds = mecanica.duracaoRodadas, coverage = mecanica.cobertura,
		reduzIgneo = mecanica.reduzIgneo == true, cells = previsao.cells,
	}, nil
end

function EncontroAutonomoHabilidades.criarNevoaDensa(atacante)
	local mecanica = Arvores.MECANICAS[NEVOA_DENSA]
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), NEVOA_DENSA)
	then return nil, "Névoa Densa exige compra e rank de Água." end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or atacante.x < 1 or atacante.x > 20
		or atacante.z < 1 or atacante.z > 20 or not inteiro(atacante.pv) or atacante.pv <= 0
		or type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm
	then return nil, "Estado ou PM do conjurador inválido para Névoa Densa." end
	local celulas = celulasCirculo(atacante.x, atacante.z, mecanica.raioCasas)
	return {
		actorId = atacante.id, targetId = atacante.id, action = "use-ability", abilityId = NEVOA_DENSA,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm,
		durationRounds = mecanica.duracaoRodadas, radiusHouses = mecanica.raioCasas,
		cells = celulas,
	}, nil
end

function EncontroAutonomoHabilidades.preverSoproDePoeira(atacante, direcaoX, direcaoZ, celulasBloqueadas, perigos, turno)
	local mecanica = Arvores.MECANICAS[SOPRO_DE_POEIRA]
	if type(atacante) ~= "table" or not inteiro(atacante.x) or not inteiro(atacante.z)
		or not inteiro(direcaoX) or not inteiro(direcaoZ)
	then return nil end
	if direcaoX < 1 or direcaoX > 20 or direcaoZ < 1 or direcaoZ > 20
		or Combate.distancia(atacante.x, atacante.z, direcaoX, direcaoZ) > mecanica.comprimentoCasas
	then return nil end
	local bloqueadas = Terreno.chavesDe(celulasBloqueadas)
	local function bloqueada(x, z) return bloqueadas[tostring(x) .. ":" .. tostring(z)] == true end
	local function visaoBloqueada(x, z)
		return not Terreno.visaoLivre(atacante.x, atacante.z, x, z, celulasBloqueadas, perigos, turno)
	end
	local casas = Areas.previa(atacante, mecanica, { x = direcaoX, z = direcaoZ }, bloqueada, visaoBloqueada)
	if type(casas) ~= "table" or #casas == 0 then return nil end
	local celulas = {}
	for _, casa in ipairs(casas) do table.insert(celulas, { x = casa[1], z = casa[2] }) end
	return { targetId = string.format("sopro-poeira:%d:%d", direcaoX, direcaoZ), cells = celulas }
end

function EncontroAutonomoHabilidades.usarSoproDePoeira(rng, atacante, atores, targetId, celulasBloqueadas, perigos, turno, catalogo)
	local mecanica = Arvores.MECANICAS[SOPRO_DE_POEIRA]
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function" or type(atores) ~= "table"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
		or type(catalogo.POR_ESPECIE) ~= "table"
	then return nil, "Dependências de Sopro de Poeira indisponíveis." end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), SOPRO_DE_POEIRA)
	then return nil, "Sopro de Poeira exige compra e rank de Vento." end
	if not inteiro(atacante.pv) or atacante.pv <= 0 or type(atacante.pm or 0) ~= "number" or atacante.pm < mecanica.pm
	then return nil, "Estado ou PM inválido para Sopro de Poeira." end
	local direcaoX, direcaoZ = string.match(targetId or "", "^sopro%-poeira:(%d+):(%d+)$")
	direcaoX, direcaoZ = tonumber(direcaoX), tonumber(direcaoZ)
	local previsao = if inteiro(direcaoX) and inteiro(direcaoZ)
		then EncontroAutonomoHabilidades.preverSoproDePoeira(atacante, direcaoX, direcaoZ, celulasBloqueadas, perigos, turno)
		else nil
	if not previsao or previsao.targetId ~= targetId then return nil, "Direção inválida para Sopro de Poeira." end
	local ficha = atacante.ficha
	local atributos = ficha.calculated and ficha.calculated.attributes
	if type(atributos) ~= "table" then return nil, "Ficha do conjurador incompleta." end
	local celulas = {}
	for _, celula in ipairs(previsao.cells) do celulas[tostring(celula.x) .. ":" .. tostring(celula.z)] = true end
	local alvos = {}
	for _, alvo in ipairs(atores) do
		if type(alvo) == "table" and alvo.id ~= atacante.id and (alvo.kind == "jogador" or alvo.kind == "criatura")
			and alvo.defeated ~= true and alvo.downed ~= true and type(alvo.pv) == "number" and alvo.pv > 0
			and inteiro(alvo.x) and inteiro(alvo.z) and celulas[tostring(alvo.x) .. ":" .. tostring(alvo.z)]
		then
			local fichaAlvo, fichaCriatura = alvo.ficha, alvo.fichaCriatura or {}
			local stats = fichaAlvo and fichaAlvo.calculated
			table.insert(alvos, { id = alvo.id, ca = alvo.ca or 10, kind = alvo.kind,
				condicoes = alvo.condicoes or {}, resistencias = fichaCriatura.resistencias or {}, imunidades = fichaCriatura.imunidades or {},
				resistencia = function(atributo)
					if alvo.kind == "criatura" then return math.ceil((fichaCriatura.bonusAtaque or 0) / 2) end
					return Estado.resistencia(stats and stats.attributes, stats and stats.highestRankBonus or 0, atributo)
				end,
			})
		end
	end
	local arvore = Execucao.arvoreDe(SOPRO_DE_POEIRA)
	local resolvidos = Habilidades.resolver(rng, mecanica, {
		id = atacante.id, bc = Execucao.bc(ficha, arvore, catalogo),
		bonusDeRank = Execucao.bonusDeRankDa(ficha, arvore), pv = atacante.pv,
		pvMax = atacante.pvMax or atacante.pv, condicoes = atacante.condicoes or {}, atributos = atributos,
	}, alvos, regrasCondicoes(catalogo))
	local efeitos = {}
	for _, efeito in ipairs(resolvidos) do
		table.insert(efeitos, { actorId = efeito.alvoId, resistance = efeito.resistencia, applies = efeito.aplica or {}, notes = efeito.notas or {} })
	end
	return { actorId = atacante.id, action = "use-ability", abilityId = SOPRO_DE_POEIRA,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm, dc = mecanica.resistencia.cdBase + Execucao.bc(ficha, arvore, catalogo),
		center = { x = atacante.x, z = atacante.z }, direction = { x = direcaoX, z = direcaoZ },
		cells = previsao.cells, targets = efeitos,
	}, nil
end

EncontroAutonomoHabilidades.MURO_DE_CHAMAS = MURO_DE_CHAMAS
EncontroAutonomoHabilidades.MURO_DE_TERRA = MURO_DE_TERRA
EncontroAutonomoHabilidades.ANTEPARO_TEORICO = ANTEPARO_TEORICO
EncontroAutonomoHabilidades.ESCUDO_DE_AGUA = ESCUDO_DE_AGUA
EncontroAutonomoHabilidades.NEVOA_DENSA = NEVOA_DENSA
EncontroAutonomoHabilidades.SOPRO_DE_POEIRA = SOPRO_DE_POEIRA
EncontroAutonomoHabilidades.PASSO_DE_VENTO = PASSO_DE_VENTO
EncontroAutonomoHabilidades.VACUO_LOCALIZADO = VACUO_LOCALIZADO

function EncontroAutonomoHabilidades.preverPassoDeVento(atacante, destinoX, destinoZ, atores, celulasBloqueadas)
	local mecanica = Arvores.MECANICAS[PASSO_DE_VENTO]
	if type(atacante) ~= "table" or not inteiro(atacante.x) or not inteiro(atacante.z)
		or not inteiro(destinoX) or not inteiro(destinoZ) or type(atores) ~= "table"
	then return nil end
	local destino = Movimento.validar(atacante.x, atacante.z, destinoX, destinoZ, atores,
		mecanica.alcanceCasas, Terreno.chavesDe(celulasBloqueadas), nil)
	if not destino then return nil end
	return { targetId = string.format("passo-vento:%d:%d", destinoX, destinoZ),
		from = { x = atacante.x, z = atacante.z }, to = { x = destinoX, z = destinoZ },
		houses = destino.casas, route = destino.rota }
end

function EncontroAutonomoHabilidades.criarPassoDeVento(atacante, targetId, atores, celulasBloqueadas)
	local mecanica = Arvores.MECANICAS[PASSO_DE_VENTO]
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), PASSO_DE_VENTO)
	then return nil, "Passo de Vento exige compra e rank de Vento." end
	if not inteiro(atacante.pv) or atacante.pv <= 0 or type(atacante.pm) ~= "number" or atacante.pm < mecanica.pm
	then return nil, "Estado ou PM inválido para Passo de Vento." end
	local x, z = string.match(targetId or "", "^passo%-vento:(%d+):(%d+)$")
	x, z = tonumber(x), tonumber(z)
	local destino = if inteiro(x) and inteiro(z)
		then EncontroAutonomoHabilidades.preverPassoDeVento(atacante, x, z, atores, celulasBloqueadas)
		else nil
	if not destino or destino.targetId ~= targetId then return nil, "Destino inválido para Passo de Vento." end
	return { actorId = atacante.id, action = "use-ability", abilityId = PASSO_DE_VENTO,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm, from = destino.from, to = destino.to,
		houses = destino.houses, route = destino.route }, nil
end
EncontroAutonomoHabilidades.MAO_DE_TERRA = MAO_DE_TERRA
EncontroAutonomoHabilidades.ESCAPAR_MAO = ESCAPAR_MAO
EncontroAutonomoHabilidades.ARRASTAR_MAO = ARRASTAR_MAO
EncontroAutonomoHabilidades.SOLTAR_MAO = SOLTAR_MAO

function EncontroAutonomoHabilidades.usarMaoDeTerra(rng, atacante, alvo, catalogo)
	local mecanica = Arvores.MECANICAS[MAO_DE_TERRA]
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
	then return nil, "Dependências de Mão de Terra indisponíveis." end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), MAO_DE_TERRA)
	then return nil, "A ficha não conhece Mão de Terra." end
	if atacante.downed == true or (atacante.condicoes or {}).caido == true
		or (atacante.condicoes or {}).inconsciente == true or (atacante.condicoes or {}).incapacitado == true
	then return nil, "A fonte precisa estar viva, capaz de agir e não Caída." end
	if type(alvo) ~= "table" or (alvo.kind ~= "jogador" and alvo.kind ~= "criatura")
		or alvo.id == atacante.id or (alvo.kind == "criatura" and type(alvo.fichaCriatura) ~= "table")
		or (alvo.kind == "jogador" and type(alvo.ficha) ~= "table")
	then return nil, "Mão de Terra exige outro participante ou criatura." end
	if not inteiro(atacante.pv) or atacante.pv <= 0 or not inteiro(alvo.pv) or alvo.pv <= 0
		or alvo.downed == true or type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm
		or not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(alvo.x) or not inteiro(alvo.z)
	then return nil, "Estado, condição ou PM inválidos para Mão de Terra." end
	if (alvo.condicoes or {}).agarrado == true then return nil, "Esse alvo já está Agarrado." end
	local distancia = Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z)
	if distancia > mecanica.alcanceCasas then return nil, "Alvo fora do alcance de Mão de Terra." end
	local atributos = atacante.ficha.calculated and atacante.ficha.calculated.attributes
	if type(atributos) ~= "table" then return nil, "Ficha do conjurador incompleta." end
	local arvore = "terra"
	local bc = Execucao.bc(atacante.ficha, arvore, catalogo)
	local fichaAlvo = alvo.ficha
	local fichaCriatura = alvo.fichaCriatura or {}
	local entrada = {
		id = alvo.id, ca = alvo.ca or 0, pv = alvo.pv, pvMax = alvo.pvMax or alvo.pv,
		condicoes = alvo.condicoes or {}, resistencias = fichaCriatura.resistencias or {},
		imunidades = fichaCriatura.imunidades or {},
		resistencia = function(atributo)
			if alvo.kind == "criatura" then return math.ceil((fichaCriatura.bonusAtaque or 0) / 2) end
			local stats = fichaAlvo and fichaAlvo.calculated
			return Estado.resistencia(stats and stats.attributes, stats and stats.highestRankBonus or 0, atributo)
		end,
	}
	local efeitos = Habilidades.resolver(rng, mecanica, {
		id = atacante.id, bc = bc, bonusDeRank = Execucao.bonusDeRankDa(atacante.ficha, arvore),
		pv = atacante.pv, pvMax = atacante.pvMax or atacante.pv, condicoes = atacante.condicoes or {}, atributos = atributos,
	}, { entrada }, regrasCondicoes(catalogo))
	local efeito = efeitos[1]
	local cd = efeito and efeito.resistencia and efeito.resistencia.cd or mecanica.resistencia.cdBase + bc
	return {
		actorId = atacante.id, targetId = alvo.id, action = "use-ability", abilityId = MAO_DE_TERRA,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm, distance = distancia,
		resistance = efeito and efeito.resistencia, applies = efeito and efeito.aplica or {},
		bindingDc = cd, bindingSourceId = atacante.id,
	}, nil
end

function EncontroAutonomoHabilidades.escaparMao(rng, ator, vinculo, catalogo)
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function" or type(ator) ~= "table"
		or type(vinculo) ~= "table" or type(vinculo.cd) ~= "number"
	then return nil, "Vínculo ou dependências de escape inválidos." end
	local condicoesAtuais = ator.condicoes or {}
	if type(ator.pv) ~= "number" or ator.pv <= 0 or ator.downed == true
		or condicoesAtuais.caido == true or condicoesAtuais.inconsciente == true or condicoesAtuais.incapacitado == true
	then return nil, "Quem está Caído ou incapaz não pode gastar Ação para escapar." end
	local bonus
	if ator.kind == "criatura" then
		bonus = math.ceil(((ator.fichaCriatura or {}).bonusAtaque or 0) / 2)
	else
		local stats = ator.ficha and ator.ficha.calculated
		bonus = Estado.resistencia(stats and stats.attributes, stats and stats.highestRankBonus or 0, "forca")
	end
	local desvantagem = false
	local mecanicas = regrasCondicoes(catalogo)
	for condicao in ator.condicoes or {} do
		if mecanicas[condicao] and mecanicas[condicao].desvantagemEmTestes then desvantagem = true; break end
	end
	local teste = Agarrar.escapar(rng, bonus, vinculo.cd, desvantagem)
	return { actorId = ator.id, targetId = ator.id, abilityId = ESCAPAR_MAO, action = "use-ability",
		actionsCost = 1, resistance = teste, escaped = teste.passou }, nil
end

function EncontroAutonomoHabilidades.criarFagulha(atacante, x, z)
	local mecanica = Fogo.MECANICAS[FAGULHA]
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), FAGULHA)
	then return nil, "A ficha não conhece Fagulha." end
	if not inteiro(x) or x < 1 or x > 20 or not inteiro(z) or z < 1 or z > 20
		or not inteiro(atacante.x) or not inteiro(atacante.z)
		or type(atacante.pv) ~= "number" or atacante.pv <= 0
	then return nil, "Casa ou conjurador inválido." end
	local distancia = math.max(math.abs(atacante.x - x), math.abs(atacante.z - z))
	if distancia > mecanica.alcanceCasas then return nil, "Casa fora de alcance de Fagulha." end
	if type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm then
		return nil, "PM insuficientes para Fagulha."
	end
	return {
		actorId = atacante.id, action = "use-ability", abilityId = FAGULHA,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm, x = x, z = z,
		durationRounds = mecanica.duracaoRodadas,
	}, nil
end

function EncontroAutonomoHabilidades.usarCura(rng, atacante, alvo, catalogo)
	local mecanica = Arvores.MECANICAS[CURA]
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
	then return nil, "Dependências de Cura indisponíveis." end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or type(alvo) ~= "table" or alvo.kind ~= "jogador"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), CURA)
	then return nil, "Cura exige habilidade comprada e alvo aliado." end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(alvo.x) or not inteiro(alvo.z)
		or not inteiro(atacante.pv) or atacante.pv <= 0 or not inteiro(alvo.pv) or alvo.pv < 0
		or not inteiro(alvo.pvMax) or alvo.pvMax <= 0 or alvo.pv >= alvo.pvMax
	then return nil, "Estado ou alvo da Cura inválido." end
	local distancia = Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z)
	if distancia > 1 then return nil, "Cura exige um aliado adjacente." end
	if type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm then
		return nil, "PM insuficientes para Cura."
	end
	local ficha = atacante.ficha
	if type(ficha.calculated) ~= "table" or type(ficha.calculated.attributes) ~= "table" then
		return nil, "Ficha do conjurador incompleta."
	end
	local efeitos = Habilidades.resolver(rng, mecanica, {
		id = atacante.id, bc = Execucao.bc(ficha, "cura", catalogo), pv = atacante.pv,
		pvMax = atacante.pvMax, condicoes = atacante.condicoes or {}, atributos = ficha.calculated.attributes,
		}, { { id = alvo.id, pv = alvo.pv, pvMax = alvo.pvMax, condicoes = alvo.condicoes or {},
			feridaFresca = Estado.feridaFresca(alvo, atacante, 0) } }, {})
	local efeito = efeitos[1]
	local cura = efeito and efeito.cura or 0
	local pv = math.min(alvo.pvMax, alvo.pv + cura)
	return {
		actorId = atacante.id, targetId = alvo.id, action = "use-ability", abilityId = CURA,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm, distance = distancia,
		healing = cura, targetPv = pv, targetDowned = pv <= 0, targetDefeated = false,
		notes = efeito and efeito.notas or {},
	}, nil
end

function EncontroAutonomoHabilidades.usarVigorEmprestado(rng, atacante, alvo, catalogo)
	local mecanica = Arvores.MECANICAS[VIGOR_EMPRESTADO]
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
	then return nil, "Dependências de Vigor Emprestado indisponíveis." end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador" or type(atacante.ficha) ~= "table"
		or type(alvo) ~= "table" or alvo.kind ~= "jogador"
		or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), VIGOR_EMPRESTADO)
	then return nil, "Vigor Emprestado exige habilidade comprada e alvo aliado." end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(alvo.x) or not inteiro(alvo.z)
		or not inteiro(atacante.pv) or atacante.pv <= 0 or not inteiro(alvo.pv) or alvo.pv < 0
		or not inteiro(alvo.pvMax) or alvo.pvMax <= 0
	then return nil, "Estado ou alvo de Vigor Emprestado inválido." end
	local distancia = Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z)
	if distancia > 1 then return nil, "Vigor Emprestado exige um aliado adjacente." end
	if type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm then
		return nil, "PM insuficientes para Vigor Emprestado."
	end
	local ficha = atacante.ficha
	if type(ficha.calculated) ~= "table" or type(ficha.calculated.attributes) ~= "table" then
		return nil, "Ficha do conjurador incompleta."
	end
	local efeitos = Habilidades.resolver(rng, mecanica, {
		id = atacante.id, bc = Execucao.bc(ficha, "cura", catalogo), pv = atacante.pv,
		pvMax = atacante.pvMax, condicoes = atacante.condicoes or {}, atributos = ficha.calculated.attributes,
	}, { { id = alvo.id, pv = alvo.pv, pvMax = alvo.pvMax, condicoes = alvo.condicoes or {},
		feridaFresca = Estado.feridaFresca(alvo, atacante, 0) } }, {})
	local efeito = efeitos[1]
	local valor = efeito and efeito.pvTemp or 0
	return {
		actorId = atacante.id, targetId = alvo.id, action = "use-ability", abilityId = VIGOR_EMPRESTADO,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm, distance = distancia,
		pvTemporariosConcedidos = valor, targetPv = alvo.pv, targetDowned = alvo.downed == true or alvo.pv <= 0,
		freshWound = Estado.feridaFresca(alvo, atacante, 0), notes = efeito and efeito.notas or {},
	}, nil
end

function EncontroAutonomoHabilidades.usar(rng, abilityId, atacante, alvo, catalogo)
	if Tecnicas.mecanica(abilityId) then return Tecnicas.usar(rng, abilityId, atacante, alvo, catalogo) end
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(catalogo) ~= "table" or type(catalogo.POR_ID) ~= "table"
	then
		return nil, "Dependências da habilidade indisponíveis."
	end
	if type(atacante) ~= "table" or atacante.kind ~= "jogador"
		or type(alvo) ~= "table" or alvo.kind ~= "criatura"
		or type(atacante.ficha) ~= "table" or type(alvo.fichaCriatura) ~= "table"
	then
		return nil, "Atacante ou alvo não suportado por esta habilidade."
	end
	local mecanica = EncontroAutonomoHabilidades.mecanica(abilityId)
	if not mecanica or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), abilityId) then
		return nil, "A ficha não conhece esta habilidade."
	end
	if not inteiro(atacante.x) or not inteiro(atacante.z) or not inteiro(alvo.x) or not inteiro(alvo.z)
		or not inteiro(atacante.pv) or not inteiro(atacante.pvMax) or atacante.pv <= 0
		or not inteiro(alvo.pv) or alvo.pv <= 0 or not inteiro(alvo.ca) or alvo.ca < 0
	then
		return nil, "Estado da habilidade inválido."
	end
	local distancia = Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z)
	if distancia > mecanica.alcanceCasas then return nil, "O alvo está fora do alcance da habilidade." end
	if type(atacante.pm or 0) ~= "number" or (atacante.pm or 0) < mecanica.pm then
		return nil, "PM insuficientes para a habilidade."
	end
	local ficha = atacante.ficha
	if type(ficha.calculated) ~= "table" or type(ficha.calculated.attributes) ~= "table" then
		return nil, "Ficha do conjurador incompleta."
	end
	local arvore = Execucao.arvoreDe(abilityId) or (if mecanica.exigeArmaGelo then "agua" else nil)
	local bc = Execucao.bc(ficha, arvore, catalogo)
	local efeitos = Habilidades.resolver(rng, mecanica, {
		id = atacante.id,
		bc = bc,
		bonusDeRank = Execucao.bonusDeRankDa(ficha, arvore),
		pv = atacante.pv,
		pvMax = atacante.pvMax,
		condicoes = atacante.condicoes or {},
		atributos = ficha.calculated.attributes,
	}, {
		{
			id = alvo.id,
			ca = alvo.ca,
			condicoes = alvo.condicoes or {},
			patamar = alvo.fichaCriatura.patamar or 0,
			respira = alvo.kind == "jogador" or alvo.respira == true or alvo.fichaCriatura.respira == true,
			resistencias = alvo.fichaCriatura.resistencias or {},
			imunidades = alvo.fichaCriatura.imunidades or {},
			resistencia = function()
				return math.ceil((alvo.fichaCriatura.bonusAtaque or 0) / 2)
			end,
			reduzIgneo = alvo.reduzIgneo == true,
		},
	}, regrasCondicoes(catalogo))
	local efeito = efeitos[1]
	if abilityId == BALA_DE_PEDRA and alvo.condicoes and alvo.condicoes.atolado and efeito then
		for indice, nota in ipairs(efeito.notas or {}) do
			if nota == "Contra alvo agarrado: qualquer resultado acerta" then
				efeito.notas[indice] = "Alvo Atolado: qualquer resultado acerta; só 20 natural é crítico"
			end
		end
	end
	local dano = efeito and efeito.dano or nil
	local causado = dano and dano.total or 0
	return {
		actorId = atacante.id,
		targetId = alvo.id,
		action = "use-ability",
		abilityId = abilityId,
		actionsCost = mecanica.acoes,
		pmCost = mecanica.pm,
		distance = distancia,
		attack = efeito and efeito.ataque,
		resistance = efeito and efeito.resistencia,
		damage = dano,
		damageDealt = causado,
		targetPv = math.max(0, alvo.pv - causado),
		targetDefeated = causado >= alvo.pv,
		applies = efeito and efeito.aplica or {},
		states = efeito and efeito.estados or {},
		pushHouses = efeito and mecanica.empurraCasas or nil,
		notes = efeito and efeito.notas or {},
	}, nil
end

-- Lista canônica mantém a deduplicação do protocolo targetId já existente.
function EncontroAutonomoHabilidades.codificarLista(ids)
	if type(ids) ~= "table" or #ids < 1 or #ids > 3 then return nil end
	local ordenados, vistos = {}, {}
	for chave, id in ids do
		if type(chave) ~= "number" or chave % 1 ~= 0 or chave < 1 or chave > #ids
			or type(id) ~= "string" or not string.match(id, "^[%w_:%-]+$") or vistos[id]
		then return nil end
		vistos[id] = true
		table.insert(ordenados, id)
	end
	table.sort(ordenados)
	local texto = "lista:" .. table.concat(ordenados, ",")
	return if #texto <= 96 then texto else nil
end

function EncontroAutonomoHabilidades.decodificarLista(texto)
	if type(texto) ~= "string" or string.sub(texto, 1, 6) ~= "lista:" then return nil end
	local ids = string.split(string.sub(texto, 7), ",")
	return if EncontroAutonomoHabilidades.codificarLista(ids) == texto then ids else nil
end

function EncontroAutonomoHabilidades.usarLancaDePedra(rng, atacante, alvos, catalogo)
	local mecanica = EncontroAutonomoHabilidades.mecanica(LANCA_DE_PEDRA)
	if type(atacante) ~= "table" or not table.find(EncontroAutonomoHabilidades.disponiveis(atacante), LANCA_DE_PEDRA)
		or type(alvos) ~= "table" or #alvos < 1 or #alvos > mecanica.maxAlvos
	then return nil, "Lança de Pedra exige compra, rank de Terra e até três criaturas." end
	local ids = {}
	for chave, alvo in alvos do
		if type(chave) ~= "number" or chave % 1 ~= 0 or chave < 1 or chave > #alvos
			or type(alvo) ~= "table" or alvo.kind ~= "criatura" or alvo.defeated == true
			or not inteiro(alvo.pv) or alvo.pv <= 0 or not inteiro(alvo.ca) or alvo.ca < 0
			or type(alvo.fichaCriatura) ~= "table" or not inteiro(alvo.x) or not inteiro(alvo.z)
			or not inteiro(atacante.x) or not inteiro(atacante.z)
			or Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z) > mecanica.alcanceCasas
		then return nil, "A lista contém criatura inválida ou fora de alcance." end
		table.insert(ids, alvo.id)
	end
	if not EncontroAutonomoHabilidades.codificarLista(ids) then return nil, "Lista de alvos inválida ou repetida." end
	-- Todas as verificações por alvo precedem o primeiro dado.
	local resultados = {}
	for _, alvo in ipairs(alvos) do
		local resultado, erro = EncontroAutonomoHabilidades.usar(rng, LANCA_DE_PEDRA, atacante, alvo, catalogo)
		if not resultado then return nil, erro end
		resultado.actorId = alvo.id
		table.insert(resultados, resultado)
	end
	return { actorId = atacante.id, action = "use-ability", abilityId = LANCA_DE_PEDRA,
		actionsCost = mecanica.acoes, pmCost = mecanica.pm, targets = resultados }, nil
end

EncontroAutonomoHabilidades.LANCA_DE_PEDRA = LANCA_DE_PEDRA
EncontroAutonomoHabilidades.VIGOR_EMPRESTADO = VIGOR_EMPRESTADO

function EncontroAutonomoHabilidades.usarBrasa(rng, atacante, alvo, catalogo)
	return EncontroAutonomoHabilidades.usar(rng, BRASA, atacante, alvo, catalogo)
end

return EncontroAutonomoHabilidades
