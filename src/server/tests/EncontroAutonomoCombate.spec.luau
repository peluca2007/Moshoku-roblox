local Combate = require(game:GetService("ReplicatedStorage").Shared.EncontroAutonomoCombate)
local Catalogo = { POR_ID = {} }
local CatalogoComCego = { POR_ID = { ["condition/cego"] = { data = { mecanica = {
	desvantagemEmAtaques = true, vantagemParaQuemAtaca = true,
} } } } }

local function rngCom(valores)
	local usados = 0
	return {
		NextInteger = function(_, minimo, maximo)
			usados += 1
			return math.clamp(table.remove(valores, 1) or minimo, minimo, maximo)
		end,
		usados = function() return usados end,
	}
end

local function elenco()
	local ficha = {
		construction = { inventory = {}, unlockedRankIds = {} },
		calculated = { attributes = { forca = 2, agilidade = 0, vigor = 0, intelecto = 0, espirito = 0 } },
	}
	return {
		{ id = "jogador:1", kind = "jogador", ficha = ficha, x = 10, z = 10, pv = 20 },
		{ id = "criatura:1", kind = "criatura", fichaCriatura = { ca = 10, bonusAtaque = 4, danoPorTurno = 5 }, x = 10, z = 11, pv = 10, ca = 10 },
	}
end

return {
	["ataque adjacente acerta usa d6 de referencia e aplica atributo"] = function(t)
		local atores, rng = elenco(), rngCom({ 15, 4 })
		local resultado, erro = Combate.atacarBasico(rng, atores[1], atores[2], Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.attack.total, 17)
		t.eq(resultado.damageDealt, 6)
		t.eq(resultado.targetPv, 4)
		t.eq(resultado.targetDefeated, false)
		t.eq(rng.usados(), 2)
		t.eq(atores[2].pv, 10, "resolvedor puro não muta o alvo")
	end,
	["critico repete somente os dados do dano"] = function(t)
		local atores, rng = elenco(), rngCom({ 20, 5, 3 })
		local resultado = Combate.atacarBasico(rng, atores[1], atores[2], Catalogo)
		t.eq(resultado.attack.critico, true)
		t.eq(resultado.damageDealt, 10)
		t.eq(rng.usados(), 3)
	end,
	["disparo alcança doze casas e usa a arma de referência quando não há arco"] = function(t)
		local atores, rng = elenco(), rngCom({ 15, 4 })
		atores[2].x, atores[2].z = 10, 22
		local resultado, erro = Combate.atacarDistancia(rng, atores[1], atores[2], Catalogo)
		t.eq(erro, nil)
		t.eq(resultado.action, "ranged-attack")
		t.eq(resultado.distance, 12)
		t.eq(resultado.weapon, "Arma de referência (d6)")
		t.eq(resultado.damageDealt, 6)
		t.eq(rng.usados(), 2)
	end,
	["disparo recusa alcance maior que doze sem rolar"] = function(t)
		local atores, rng = elenco(), rngCom({ 20, 6 })
		atores[2].x, atores[2].z = 10, 23
		local resultado, erro = Combate.atacarDistancia(rng, atores[1], atores[2], Catalogo)
		t.eq(resultado, nil)
		t.eq(erro, "Disparo exige criatura a até 12 casas.")
		t.eq(rng.usados(), 0)
	end,
	["falha natural nao rola dano"] = function(t)
		local atores, rng = elenco(), rngCom({ 1 })
		local resultado = Combate.atacarBasico(rng, atores[1], atores[2], Catalogo)
		t.eq(resultado.attack.acertou, false)
		t.eq(resultado.damage, nil)
		t.eq(resultado.targetPv, 10)
		t.eq(rng.usados(), 1)
	end,
	["distancia ou alvo fora do escopo recusa sem consumir rng"] = function(t)
		local atores, rng = elenco(), rngCom({ 20, 6 })
		atores[2].x = 12
		local resultado, erro = Combate.atacarBasico(rng, atores[1], atores[2], Catalogo)
		t.eq(resultado, nil)
		t.eq(erro, "Ataque básico exige criatura adjacente.")
		t.eq(rng.usados(), 0)
		atores[2].x = 11
		atores[2].kind = "jogador"
		resultado = Combate.atacarBasico(rng, atores[1], atores[2], Catalogo)
		t.eq(resultado, nil)
		t.eq(rng.usados(), 0)
	end,
	["criatura adjacente usa bonus do apendice G e dano fixo"] = function(t)
		local atores, rng = elenco(), rngCom({ 15 })
		atores[1].pv = 20
		atores[1].ca = 10
		local resultado, erro = Combate.atacarCriatura(rng, atores[2], atores[1])
		t.eq(erro, nil)
		t.eq(resultado.attack.total, 19)
		t.eq(resultado.damageDealt, 5)
		t.eq(resultado.targetPv, 15)
		t.eq(rng.usados(), 1)
	end,
	["critico da criatura conserva dano fixo do molde"] = function(t)
		local atores, rng = elenco(), rngCom({ 20 })
		atores[1].pv = 20
		atores[1].ca = 10
		local resultado = Combate.atacarCriatura(rng, atores[2], atores[1])
		t.eq(resultado.attack.critico, true)
		t.eq(resultado.damageDealt, 5)
		t.eq(rng.usados(), 1)
	end,
	["Cego dá Desvantagem ao atacante no ataque básico"] = function(t)
		local atores, rng = elenco(), rngCom({ 15, 5 })
		atores[1].condicoes = { cego = true }
		local resultado = Combate.atacarBasico(rng, atores[1], atores[2], CatalogoComCego)
		t.eq(resultado.attack.d20.ajuste, "desvantagem")
		t.eq(resultado.attack.d20.natural, 5)
		t.eq(rng.usados(), 2)
	end,
	["Cego dá Vantagem a quem ataca o alvo no ataque básico"] = function(t)
		local atores, rng = elenco(), rngCom({ 5, 15, 4 })
		atores[2].condicoes = { cego = true }
		local resultado = Combate.atacarBasico(rng, atores[1], atores[2], CatalogoComCego)
		t.eq(resultado.attack.d20.ajuste, "vantagem")
		t.eq(resultado.attack.d20.natural, 15)
		t.eq(rng.usados(), 3)
	end,
	["Cego também altera ataques da criatura"] = function(t)
		local atores, rng = elenco(), rngCom({ 15, 5 })
		atores[2].condicoes = { cego = true }
		atores[1].ca = 10
		local resultado = Combate.atacarCriatura(rng, atores[2], atores[1], CatalogoComCego)
		t.eq(resultado.attack.d20.ajuste, "desvantagem")
		t.eq(resultado.attack.d20.natural, 5)
	end,
	["criatura tem Vantagem contra jogador Cego"] = function(t)
		local atores, rng = elenco(), rngCom({ 5, 15 })
		atores[1].pv, atores[1].ca = 20, 10
		atores[1].condicoes = { cego = true }
		local resultado = Combate.atacarCriatura(rng, atores[2], atores[1], CatalogoComCego)
		t.eq(resultado.attack.d20.ajuste, "vantagem")
		t.eq(resultado.attack.d20.natural, 15)
	end,
}
