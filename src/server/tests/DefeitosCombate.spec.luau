-- Regras puras F1: executadas pelo TestRunner e pelo harness fora do Studio.
local Shared = game:GetService("ReplicatedStorage").Shared
local Combate = require(Shared.EncontroAutonomoCombate)
local Defeitos = require(Shared.Regras.RunDefeitos)
local Movimento = require(Shared.EncontroAutonomoMovimento)
local Patrulha = require(Shared.Regras.EncontroPatrulha)
local Habilidades = require(Shared.Regras.Habilidades)
local Arvores = require(Shared.Regras.ArvoresPrincipiante)

local function rngCom(valores)
	local indice = 0
	return { NextInteger = function(_, minimo, maximo)
		indice += 1
		local valor = valores[indice]
		assert(valor and valor >= minimo and valor <= maximo, "RNG consumido fora do esperado")
		return valor
	end, usados = function() return indice end }
end

local function jogador(ids, metros)
	return Combate.prepararDefeitos({ id = "j:2", userId = 2, kind = "jogador", pv = 20,
		x = 10, z = 12, condicoes = {}, ficha = { calculated = { movementMeters = metros or 9 } } }, ids)
end

-- Bancada do contrato do adaptador: o mesmo resolvedor/mec?nica de Sopro,
-- com alvos j? na ?rea. Geometria e transporte do J2 exigem Studio.
local function resolverSopro(rng, atacante, atores, _, _, _, _, catalogo)
	local regras, alvos = {}, {}
	for _, entrada in catalogo.POR_ESPECIE.condition do regras[entrada.data.id] = entrada.data.mecanica end
	for _, ator in atores do
		table.insert(alvos, { id = ator.id, kind = ator.kind, ca = 10,
			condicoes = ator.condicoes or {}, imunidades = ator.imunidades or {},
			resistencia = function() return 0 end })
	end
	local efeitos = Habilidades.resolver(rng, Arvores.MECANICAS["ability/vento/Principiante/sopro-de-poeira"],
		{ id = atacante.id, bc = 0, condicoes = {} }, alvos, regras)
	local resultado = { targets = {} }
	for _, efeito in efeitos do
		table.insert(resultado.targets, { actorId = efeito.alvoId, resistance = efeito.resistencia,
			applies = efeito.aplica or {}, notes = efeito.notas or {} })
	end
	return resultado
end

local function sopro(rng, atores, catalogo)
	return Combate.soproComDefeitos(resolverSopro, rng, { id = "j:1" }, atores, "sopro-poeira:10:11",
		nil, nil, 1, catalogo or { POR_ESPECIE = { condition = {} } })
end

return {
	["cada defeito usa somente seu teste e escolhe o menor de dois d20"] = function(t)
		for _, defeito in Defeitos.LISTA do
			for _, teste in defeito.desvantagemEm or {} do
				local rng = rngCom({ 19, 3 })
				local r = Combate.testeComDefeitos(rng, { defeito.id }, teste, 2, 10)
				t.eq(r.d20.ajuste, "desvantagem")
				t.eq(r.d20.natural, 3)
				t.eq(r.total, 5)
				t.eq(r.passou, false)
				t.eq(r.defects[1], defeito.id)
				t.eq(rng.usados(), 2)
				local normal = Combate.testeComDefeitos(rngCom({ 19 }), { defeito.id }, "Atletismo", 2, 10)
				t.eq(normal.d20.ajuste, "normal")
				t.eq(#normal.defects, 0)
			end
		end
	end,
	["vantagem anula defeito e desvantagens nao acumulam"] = function(t)
		local rng = rngCom({ 12 })
		local r = Combate.testeComDefeitos(rng, { "fragil" }, "Vigor", 0, 10, true)
		t.eq(r.d20.ajuste, "normal")
		t.eq(rng.usados(), 1)
		rng = rngCom({ 18, 4 })
		r = Combate.testeComDefeitos(rng, { "fragil" }, "Vigor", 0, 10, false, true)
		t.eq(r.d20.natural, 4)
		t.eq(rng.usados(), 2)
	end,
	["Manco reduz tres metros antes da conversao em casas e limita destinos"] = function(t)
		local ator = jogador({ "manco" })
		t.eq(ator.movementCasas, 4)
		t.eq(ator.movementMeters, 6)
		t.eq(ator.ficha.calculated.movementMeters, 9)
		t.eq(ator.defectMovement.reductionMeters, 3)
		t.ok(Movimento.validar(10, 10, 14, 10, {}, ator.movementCasas))
		t.eq(Movimento.validar(10, 10, 15, 10, {}, ator.movementCasas), nil)
		local repetido = Combate.prepararDefeitos(ator, { "manco" })
		t.eq(repetido.movementCasas, 4)
		t.eq(jogador({ "manco" }, 1.5).movementCasas, 0)
		t.eq(jogador({}, 10).movementCasas, 6)
	end,
	["Manco aumenta CD da fuga sem alterar Atletismo nem dados"] = function(t)
		local ator = jogador({ "manco" })
		local normal = Patrulha.fuga(rngCom({ 11 }), 0, 9, { 9 })
		local manco = Patrulha.fuga(rngCom({ 11 }), 0, ator.movementMeters, { 9 })
		t.eq(normal.cd, 10)
		t.eq(normal.fugiu, true)
		t.eq(manco.cd, 12)
		t.eq(manco.fugiu, false)
	end,
	["validacao recusa listas invalidas e nao consulta RNG"] = function(t)
		for _, ids in { { "manco", "manco" }, { "inventado" }, { [2] = "manco" },
			{ efeito = "fragil" }, { 1 }, { "manco", bonus = 3 } } do
			t.eq(Defeitos.validarCombate(ids), nil)
		end
		t.eq(Defeitos.validarCombate("manco"), nil)
		for _, metros in { -1, math.huge, 0/0, "9" } do
			t.eq(Defeitos.deslocamentoCombate({ "manco" }, metros), nil)
		end
		local rng = rngCom({})
		t.eq(Combate.testeComDefeitos(rng, { "inventado" }, "Vigor", 0, 10), nil)
		t.eq(rng.usados(), 0)
	end,
	["provedor recebe identidade valida e nao pode falhar ceder ou devolver nil"] = function(t)
		local ids = { "fragil" }
		local copia = Combate.consultarDefeitos(function(uid) t.eq(uid, 42); return ids end, 42)
		ids[1] = "manco"
		t.eq(copia[1], "fragil")
		local chamou = false
		t.eq(Combate.consultarDefeitos(function() chamou = true; return {} end, "42"), nil)
		t.eq(chamou, false)
		t.eq(Combate.consultarDefeitos(function() error("falha") end, 42), nil)
		t.eq(Combate.consultarDefeitos(function() coroutine.yield(); return {} end, 42), nil)
		t.eq(Combate.consultarDefeitos(function() return nil end, 42), nil)
		t.eq(#Combate.consultarDefeitos(function() return {} end, 42), 0)
	end,
	["Sopro aplica Fr?gil antes de decidir Cego e separa os outros alvos"] = function(t)
		local fragil, normal = jogador({ "fragil" }), jogador({ "zangado" })
		normal.id = "j:3"
		local rng = rngCom({ 19, 2, 19 })
		local catalogo = { POR_ESPECIE = { condition = {} } }
		local r = sopro(rng, { fragil, normal }, catalogo)
		t.eq(r.targets[1].resistance.d20.ajuste, "desvantagem")
		t.eq(r.targets[1].resistance.d20.natural, 2)
		t.eq(r.targets[1].resistance.defects[1], "fragil")
		t.eq(table.find(r.targets[1].applies, "cego") ~= nil, true)
		t.eq(r.targets[2].resistance.d20.ajuste, "normal")
		t.eq(#r.targets[2].applies, 0)
		t.eq(rng.usados(), 3)
		t.eq(next(fragil.condicoes), nil)
		t.eq(#catalogo.POR_ESPECIE.condition, 0)
	end,
	["Sopro preserva condicoes e desvantagem existente sem terceiro dado"] = function(t)
		local ator = jogador({ "fragil" })
		ator.imunidades = { "cego" }
		ator.condicoes.envenenado = 1
		local catalogo = { POR_ESPECIE = { condition = { { data = { id = "envenenado",
			mecanica = { desvantagemEmTestes = true } } } } } }
		local rng = rngCom({ 19, 2 })
		local r = sopro(rng, { ator }, catalogo)
		t.eq(rng.usados(), 2)
		t.ok(table.find(r.targets[1].applies, "cego"))
		t.ok(table.find(r.targets[1].applies, "desequilibrado"))
		t.eq(ator.condicoes.envenenado, 1)
		t.eq(ator.imunidades[1], "cego")
	end,
	["sem defeito Sopro preserva um dado e nao registra penalidade"] = function(t)
		local rng = rngCom({ 19 })
		local r = sopro(rng, { jogador({}) })
		t.eq(r.targets[1].resistance.d20.ajuste, "normal")
		t.eq(r.targets[1].resistance.defects, nil)
		t.eq(rng.usados(), 1)
	end,
	["ataque e dano nao recebem penalidade de pericias ou Vigor"] = function(t)
		local ator = jogador({ "zangado", "burro", "medroso", "desastrado", "fragil" })
		ator.x, ator.z = 10, 10
		ator.ficha.construction = { inventory = {}, unlockedRankIds = {} }
		ator.ficha.calculated.attributes = { forca = 2 }
		local alvo = { id = "c:1", kind = "criatura", x = 10, z = 11, pv = 30, ca = 10, fichaCriatura = {} }
		local rng = rngCom({ 15, 4 })
		local r = Combate.atacarBasico(rng, ator, alvo, { POR_ID = {} })
		t.eq(r.attack.d20.ajuste, "normal")
		t.eq(r.damageDealt, 6)
		t.eq(rng.usados(), 2)
	end,
}
