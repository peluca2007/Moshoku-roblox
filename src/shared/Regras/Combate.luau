-- Núcleo de resolução de combate (puro; RNG injetado). Porte do que o site faz em
-- src/lib/combatSim.ts (`resolver`) e src/lib/combatTrace.ts (`rolar*`), só no
-- que a fatia jogável usa. Não cria Instances nem envia eventos.
--
-- Livro (Cap. 4/5), conferido no simulador do site:
-- - Ataque: d20 + bônus contra a CA. 1 natural erra; 20 natural acerta e é crítico.
-- - Crítico: os DADOS de dano rolam de novo e somam; o bônus fixo não dobra.
-- - Vantagem/desvantagem: dois d20, o maior/menor; as duas juntas se anulam.
-- - Teste de resistência: d20 + bônus contra a CD; empata e passa.
-- - Personagem resiste com o atributo pedido; criatura, com o bônus de
--   resistência do Apêndice G (metade do bônus de ataque, para cima).
local Combate = {}

export type Rng = { NextInteger: (any, number, number) -> number }

export type D20 = { dados: { number }, natural: number, ajuste: string }

function Combate.d20(rng: Rng, vantagem: boolean?, desvantagem: boolean?): D20
	local dados = { rng:NextInteger(1, 20) }
	if (vantagem == true) == (desvantagem == true) then
		return { dados = dados, natural = dados[1], ajuste = "normal" }
	end
	table.insert(dados, rng:NextInteger(1, 20))
	local natural = if vantagem then math.max(dados[1], dados[2]) else math.min(dados[1], dados[2])
	return { dados = dados, natural = natural, ajuste = if vantagem then "vantagem" else "desvantagem" }
end

-- Lê os dados de uma fórmula de dano: só parcelas positivas de dados ("2d6",
-- "1d8 + 1d6"). O fixo (BC) vem à parte. Qualquer outra coisa é erro: a tabela
-- de mecânicas não pode carregar fórmula que o resolvedor leria errado.
function Combate.lerDados(formula: string): { { quantidade: number, faces: number } }
	local limpa = string.gsub(string.lower(formula), "%s", "")
	-- Cada parcela entre "+" precisa ser NdM; vazio, sinal de menos ou texto solto falham.
	for _, parcela in string.split(limpa, "+") do
		assert(string.match(parcela, "^%d+d%d+$"), "fórmula de dados inválida: " .. formula)
	end
	local grupos = {}
	for quantidade, faces in string.gmatch(limpa, "(%d+)d(%d+)") do
		local q, f = tonumber(quantidade), tonumber(faces)
		assert(q and f and q >= 1 and q <= 100 and f >= 2 and f <= 1000, "fórmula de dado inválida: " .. formula)
		table.insert(grupos, { quantidade = q, faces = f })
	end
	return grupos
end

export type Rolagem = { formula: string, resultados: { number }, total: number }

function Combate.rolarDados(rng: Rng, formula: string): Rolagem
	local resultados, total = {}, 0
	for _, grupo in Combate.lerDados(formula) do
		for _ = 1, grupo.quantidade do
			local valor = rng:NextInteger(1, grupo.faces)
			table.insert(resultados, valor)
			total += valor
		end
	end
	return { formula = formula, resultados = resultados, total = total }
end

export type Ataque = {
	d20: D20,
	bonus: number,
	total: number,
	defesa: number,
	acertou: boolean,
	critico: boolean,
}

function Combate.ataque(rng: Rng, bonus: number, ca: number, vantagem: boolean?, desvantagem: boolean?): Ataque
	local d = Combate.d20(rng, vantagem, desvantagem)
	local total = d.natural + bonus
	local acertou = d.natural ~= 1 and (d.natural == 20 or total >= ca)
	return { d20 = d, bonus = bonus, total = total, defesa = ca, acertou = acertou, critico = d.natural == 20 }
end

export type Resistencia = { d20: D20, bonus: number, total: number, cd: number, passou: boolean }

function Combate.resistencia(rng: Rng, bonus: number, cd: number, vantagem: boolean?, desvantagem: boolean?): Resistencia
	local d = Combate.d20(rng, vantagem, desvantagem)
	local total = d.natural + bonus
	return { d20 = d, bonus = bonus, total = total, cd = cd, passou = total >= cd }
end

-- Dano de um acerto: dados (+ dados de novo no crítico) + bônus fixo, mínimo 0.
-- tipo: tipo do dano inteiro ("ígneo"), para Resistência e Imunidade; nil = sem tipo.
export type Dano = { partes: { Rolagem }, fixo: number, total: number, tipo: string? }

function Combate.dano(rng: Rng, formulas: { string }, fixo: number, critico: boolean, tipo: string?): Dano
	local partes, total = {}, fixo
	for _, formula in formulas do
		local rolagem = Combate.rolarDados(rng, formula)
		table.insert(partes, rolagem)
		total += rolagem.total
		if critico then
			local extra = Combate.rolarDados(rng, formula)
			extra.formula ..= " (crítico)"
			table.insert(partes, extra)
			total += extra.total
		end
	end
	return { partes = partes, fixo = fixo, total = math.max(0, total), tipo = tipo }
end

-- Distância em casas na grade: diagonal conta 1 (adaptação registrada em
-- FIDELIDADE: o livro mede em metros; 1 casa = 1,5 m). Alcance usa esta medida.
function Combate.distancia(ax: number, az: number, bx: number, bz: number): number
	return math.max(math.abs(ax - bx), math.abs(az - bz))
end

-- Raio de área ("esfera de 6 m"): distância euclidiana entre centros de casa, para
-- a área ser um círculo na grade, e não um quadrado (adaptação registrada).
function Combate.distanciaEuclidiana(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- As oito direções da grade; a escolhida é a mais próxima do vetor (dx, dz).
function Combate.direcao8(dx: number, dz: number): (number, number)
	if dx == 0 and dz == 0 then
		return 0, 0
	end
	local angulo = math.atan2(dz, dx)
	local setor = math.round(angulo / (math.pi / 4))
	return math.round(math.cos(setor * math.pi / 4)), math.round(math.sin(setor * math.pi / 4))
end

Combate.METROS_POR_CASA = 1.5

function Combate.casasDeMetros(metros: number): number
	return math.floor(metros / Combate.METROS_POR_CASA + 1e-9)
end

-- Casas entre dois pontos (Bresenham), sem incluir a origem; inclui o destino.
function Combate.linha(ax: number, az: number, bx: number, bz: number): { { number } }
	local casas = {}
	local dx, dz = math.abs(bx - ax), -math.abs(bz - az)
	local sx, sz = if ax < bx then 1 else -1, if az < bz then 1 else -1
	local erro = dx + dz
	local x, z = ax, az
	while not (x == bx and z == bz) do
		local e2 = 2 * erro
		if e2 >= dz then
			erro += dz
			x += sx
		end
		if e2 <= dx then
			erro += dx
			z += sz
		end
		table.insert(casas, { x, z })
	end
	return casas
end

-- Supercobertura entre centros: cantos de paredes também fecham a visão.
-- Exclui origem/destino, mas não as casas laterais tocadas num canto.
function Combate.temVisao(ax: number, az: number, bx: number, bz: number, bloqueia: (number, number) -> boolean): boolean
	local nx, nz = math.abs(bx-ax), math.abs(bz-az)
	local sx, sz = if bx>ax then 1 else -1, if bz>az then 1 else -1
	local x,z,ix,iz=ax,az,0,0
	local function fecha(cx,cz)
		return not (cx==ax and cz==az) and not (cx==bx and cz==bz) and bloqueia(cx,cz)
	end
	while ix<nx or iz<nz do
		local a,b=(1+2*ix)*nz,(1+2*iz)*nx
		if a==b then
			if fecha(x+sx,z) or fecha(x,z+sz) then return false end
			x+=sx;z+=sz;ix+=1;iz+=1
		elseif a<b then x+=sx;ix+=1
		else z+=sz;iz+=1 end
		if fecha(x,z) then return false end
	end
	return true
end

return Combate
