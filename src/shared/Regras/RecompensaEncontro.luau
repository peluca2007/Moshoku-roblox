-- Port do cálculo de recompensa do Apêndice G. Sem estado Roblox; rng é função [0,1).
local R = {}
local BASE = { 10, 20, 40, 80, 160, 320 }
local PAPEL = { lacaio = 0.5, padrao = 1, chefe = 4 }
local ARQUETIPO = { bruto = 1, agil = 1, conjurador = 1.5, tanque = 1.5, controlador = 1.5, assassino = 1.5 }
local SUB = {
	 besta = { riqueza = 1, moeda = 0, equipamento = false },
	 humanoide = { riqueza = 1, moeda = 0.6, equipamento = true },
	 planta = { riqueza = 0.75, moeda = 0, equipamento = false },
	 construto = { riqueza = 1.5, moeda = 0, equipamento = false },
	 dragonico = { riqueza = 2, moeda = 0.3, equipamento = false },
	 demonio = { riqueza = 1.5, moeda = 0.3, equipamento = false },
	 elemental = { riqueza = 1.5, moeda = 0, equipamento = false },
	 mortoVivo = { riqueza = 0.75, moeda = 0.3, equipamento = false },
}
local function base(p)
	p = math.max(1, math.floor(p + 0.5))
	return BASE[p] or BASE[6] * 2 ^ (p - 6)
end
function R.valorCriatura(c)
	if type(c) ~= "table" or type(c.patamar) ~= "number" or PAPEL[c.papel] == nil then return nil end
	local p = c.patamar + (c.temImunidade and 1 or 0)
	return math.floor(base(p) * PAPEL[c.papel] * (ARQUETIPO[c.arquetipo] or 1) * ((SUB[c.subArquetipo] and SUB[c.subArquetipo].riqueza) or 1) + 0.5)
end
local function sortear(lista, teto, rng, maximo)
	local saida, gasto = {}, 0
	for _ = 1, maximo do
		local elegiveis = {}
		for _, item in ipairs(lista) do if item.preco <= teto - gasto then table.insert(elegiveis, item) end end
		if #elegiveis == 0 then break end
		local n = rng()
		if type(n) ~= "number" or n < 0 or n >= 1 then error("RNG deve retornar valor em [0,1).") end
		local item = elegiveis[math.floor(n * #elegiveis) + 1]
		table.insert(saida, item); gasto += item.preco
	end
	return saida, gasto
end
function R.gerar(criaturas, rng, itens)
	assert(type(rng) == "function", "RNG injetado obrigatório.")
	local porSub, moedas, tralhas, equipamento, total = {}, 0, {}, {}, 0
	for _, c in ipairs(criaturas) do
		local valor = R.valorCriatura(c)
		if valor then local sub = SUB[c.subArquetipo] and c.subArquetipo or "besta"; porSub[sub] = (porSub[sub] or 0) + valor end
	end
	for subId, valor in pairs(porSub) do
		local sub = SUB[subId]; total += valor
		local m = math.floor(valor * sub.moeda + 0.5); moedas += m
		local resto = valor - m
		if sub.equipamento and itens then
			local selecionados, gasto = sortear(itens.equipamento or {}, math.floor(resto * 0.4), rng, 3)
			for _, v in ipairs(selecionados) do table.insert(equipamento, v) end; resto -= gasto
		end
		local selecionados, gasto = sortear(itens and itens.tralhas or {}, resto, rng, 3)
		for _, v in ipairs(selecionados) do table.insert(tralhas, v) end; resto -= gasto
		if resto > 0 then table.insert(tralhas, { id = "partes_" .. subId, nome = "Partes aproveitáveis", preco = resto }) end
	end
	return { moedas = moedas, tralhas = tralhas, itens = equipamento, valorTotal = total }
end
function R._dados() return table.clone(BASE), table.clone(PAPEL), table.clone(ARQUETIPO), table.clone(SUB) end

-- Valores do Apêndice G das criaturas do mundo (entrada de R.gerar), vindos do antigo elenco J2.
local CRIATURAS = table.freeze({
	["creature/rato-gigante"] = { patamar = 1, papel = "lacaio", arquetipo = "agil", subArquetipo = "besta" },
	["creature/aranha-da-floresta"] = { patamar = 2, papel = "padrao", arquetipo = "agil", subArquetipo = "besta" },
	["creature/bandido-de-estrada"] = { patamar = 1, papel = "padrao", arquetipo = "bruto", subArquetipo = "humanoide" },
	["creature/golem-de-pedra-menor"] = { patamar = 2, papel = "padrao", arquetipo = "fortaleza", subArquetipo = "construto", temImunidade = true },
	["creature/urso-de-presas-vermelhas"] = { patamar = 2, papel = "padrao", arquetipo = "bruto", subArquetipo = "besta" },
	["creature/goblin-batedor"] = { patamar = 1, papel = "lacaio", arquetipo = "agil", subArquetipo = "humanoide" },
	["creature/lobo-cinzento"] = { patamar = 1, papel = "padrao", arquetipo = "bruto", subArquetipo = "besta" },
	["creature/treant-anciao"] = { patamar = 3, papel = "chefe", arquetipo = "bruto", subArquetipo = "planta" },
})
function R.daCriatura(creatureId)
	local dados = CRIATURAS[creatureId]
	return if dados then table.clone(dados) else nil
end
return R
