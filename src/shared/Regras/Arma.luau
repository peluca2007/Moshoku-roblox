-- Arma de combate da ficha (puro; catálogo injetado). Porte de
-- `resolverArmaCombate` (src/lib/combatWeapon.ts), `getWeaponDamage`
-- (src/store/selectors.ts) e `escalateWeaponDie` (src/lib/weaponDie.ts):
-- - a arma é a ÚNICA arma equipada com dado válido; mãos vazias com a
--   maestria O Corpo é a Arma resolvem punhos, d6 com os degraus normais;
-- - demais fichas ambíguas preservam a referência d6 com aviso;
-- - o Dado de Arma sobe pela Escada de Dados os degraus (weaponDieSteps) da
--   árvore de corpo de maior rank (empate: a que dá mais degraus);
-- - acerto e dano = atributo + Bônus de Rank desse rank de corpo.
local Regras = require(game:GetService("ReplicatedStorage").Shared.Livro.Regras)
local Armas = require(game:GetService("ReplicatedStorage").Shared.Regras.Armas)

local Arma = {}

local function indice(dado: string): number?
	return table.find(Regras.escadaDeDados, dado)
end

-- "1d8" → "d8"; o resto como está.
function Arma.normalizar(dado: string): string
	return (string.gsub(string.gsub(string.lower(dado), "%s", ""), "^1d", "d"))
end

-- Sobe `degraus` na escada; acima do topo cada degrau vira dano fixo (site).
function Arma.escalar(dado: string, degraus: number): string
	local i = indice(dado)
	if not i then
		return dado
	end
	local topo = #Regras.escadaDeDados
	local bruto = i + math.max(0, degraus)
	local alvo = math.clamp(bruto, 1, topo)
	local excesso = math.max(0, bruto - topo)
	local resultado = Regras.escadaDeDados[alvo]
	return if excesso > 0 then resultado .. "+" .. (excesso * Regras.excessoPorDegrau) else resultado
end

-- "Um degrau abaixo" (técnicas que reduzem o dado); para no d4.
function Arma.descer(dado: string, degraus: number): string
	local base, extra = string.match(dado, "^([^%+]+)%+?(%d*)$")
	local i = indice(base or dado)
	if not i then
		return dado
	end
	local excesso = (tonumber(extra) or 0) / Regras.excessoPorDegrau
	local restante = math.max(0, excesso - degraus)
	local baseNova = Regras.escadaDeDados[math.max(1, i - math.max(0, degraus - excesso))]
	return if restante > 0 then baseNova .. "+" .. (restante * Regras.excessoPorDegrau) else baseNova
end

-- Fórmula rolável ("d8" → "1d8", "2d6+2" fica com o fixo separado).
function Arma.formula(dado: string): (string, number)
	local dados, fixo = string.match(dado, "^([^%+]+)%+?(%d*)$")
	dados = dados or dado
	if string.sub(dados, 1, 1) == "d" then
		dados = "1" .. dados
	end
	return dados, tonumber(fixo) or 0
end

local ARMAS_A_DISTANCIA = { "arco", "besta", "funda", "zarabatana" }

local function aDistancia(nome: string): boolean
	if Armas.ehDisparo(nome) then return true end
	local n = string.lower(nome)
	for _, palavra in ARMAS_A_DISTANCIA do
		if string.find(n, palavra, 1, true) then
			return true
		end
	end
	return false
end

local function valida(item): boolean
	return not item.a16Indisponivel and item.type == "arma" and type(item.baseDie) == "string" and indice(Arma.normalizar(item.baseDie)) ~= nil
end

-- Degraus e Bônus de Rank vindos da árvore de corpo de maior rank.
function Arma.escala(ficha2, catalogo): (number, number, string?)
	local melhor, porArvore = 0, {}
	for _, rankId in ficha2.construction.unlockedRankIds do
		local rank = catalogo.POR_ID[rankId]
		local arvore = rank and catalogo.POR_ID["tree/" .. rank.data.treeId]
		if arvore and arvore.data.category == "corpo" then
			local i = table.find(Regras.ordemDosRanks, rank.data.rank) or 0
			melhor = math.max(melhor, i)
			porArvore[rank.data.treeId] = math.max(porArvore[rank.data.treeId] or 0, i)
		end
	end
	if melhor == 0 then
		return 0, 0, nil
	end
	local degraus, escolhida = 0, nil
	for arvore, i in porArvore do
		if i == melhor then
			local soma = 0
			for _, r in catalogo.POR_ESPECIE.rank do
				if r.data.treeId == arvore and (table.find(Regras.ordemDosRanks, r.data.rank) or 99) <= melhor then
					soma += r.data.weaponDieSteps or 0
				end
			end
			if not escolhida or soma > degraus or (soma == degraus and arvore == "deus-do-norte") then
				degraus, escolhida = soma, arvore
			end
		end
	end
	return degraus, Regras.bonusDeRank[Regras.ordemDosRanks[melhor]], escolhida
end

-- A arma do golpe. distancia = true escolhe uma arma de disparo do inventário
-- (adaptação: o site usa só a equipada; as técnicas de Arquearia pedem arco).
function Arma.daFicha(ficha2, catalogo, distancia: boolean?)
	local inventario = ficha2.construction.inventory or {}
	local item, aviso = nil, nil
	if distancia then
		for _, i in inventario do
			if valida(i) and aDistancia(i.name) then
				item = i
				break
			end
		end
		aviso = if item then nil else "Sem arco no inventário: disparo com a arma de referência d6."
	else
		local equipadas = {}
		for _, i in inventario do
			if i.type == "arma" and i.equipped and not aDistancia(i.name) then
				table.insert(equipadas, i)
			end
		end
		if #equipadas == 1 and valida(equipadas[1]) then
			item = equipadas[1]
		elseif #equipadas > 1 then
			aviso = "Mais de uma arma equipada: usando a arma de referência d6."
		else
			aviso = "Nenhuma arma equipada: usando a arma de referência d6."
		end
	end
	local desarmado = false
	local dadoPunhos
	if not item and not distancia then
		local equipadas = false
		for _, i in inventario do if i.type == "arma" and i.equipped then equipadas = true end end
		if not equipadas then
			for _, rankId in ficha2.construction.unlockedRankIds do
				local rank = catalogo.POR_ID[rankId]
				local entrada = rank and catalogo.POR_ID[rank.data.mastery]
				local maestria = entrada and entrada.data
				if maestria and maestria.name == "O Corpo é a Arma" then
					dadoPunhos = string.match(maestria.description, "ataques desarmados usam Dado Base (d%d+)")
					desarmado = dadoPunhos ~= nil
				end
			end
		end
	end
	local base = if item then Arma.normalizar(item.baseDie) elseif desarmado then dadoPunhos else "d6"
	local degraus, bonusDeRank, arvoreDaEscala = Arma.escala(ficha2, catalogo)
	-- Cap. 3: improvisado não escala. Norte é a exceção (punho com
	-- maestria é arma desarmada, não um objeto improvisado).
	if item and Armas.grupo(item.name) == "desarmado-e-improvisado" then
		if arvoreDaEscala ~= "deus-do-norte" then degraus = 0 end
	end
	return {
		nome = if item then item.name elseif desarmado then "Punhos (desarmado)" else "Arma de referência (d6)",
		base = base,
		dado = Arma.escalar(base, degraus),
		degraus = degraus,
		bonusDeRank = bonusDeRank,
		atributo = item and item.damageAttribute,
		aviso = if desarmado then nil else aviso,
		desarmado = desarmado,
	}
end

return Arma
