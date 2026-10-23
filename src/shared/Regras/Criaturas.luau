-- Bloco numérico das criaturas do bestiário (Apêndice G), puro. Porte de
-- src/data/bestiary.ts do site (`aplicarPapel`, `atributosDaCriatura`,
-- `bonusResistencia`), conferido contra os vetores que o gerador calcula com as
-- funções originais (Livro/Regras.vetores; spec Criaturas.spec).
local Regras = require(game:GetService("ReplicatedStorage").Shared.Livro.Regras)

local Criaturas = {}

function Criaturas.molde(patamar: number)
	for _, molde in Regras.moldesDeCriatura do
		if molde.patamar == patamar then
			return molde
		end
	end
	return Regras.moldesDeCriatura[1]
end

-- "lacaio": metade do PV e do dano; "chefe": 2,5× o PV e 1,5× o dano.
function Criaturas.aplicarPapel(patamar: number, papel: string): { pv: number, danoPorTurno: number }
	local molde = Criaturas.molde(patamar)
	if papel == "lacaio" then
		return { pv = math.round(molde.pv / 2), danoPorTurno = math.round(molde.danoPorTurno / 2) }
	elseif papel == "chefe" then
		return { pv = math.round(molde.pv * 2.5), danoPorTurno = math.round(molde.danoPorTurno * 1.5) }
	end
	return { pv = molde.pv, danoPorTurno = molde.danoPorTurno }
end

function Criaturas.atributos(patamar: number): { principal: number, bom: number, comum: number, fraco: number }
	local molde = Criaturas.molde(patamar)
	local principal = molde.bonusAtaque - molde.patamar
	local bom = math.ceil(principal / 2)
	return { principal = principal, bom = bom, comum = math.max(0, bom - 1), fraco = -1 }
end

-- Apêndice G: metade do bônus de ataque, arredondado para cima.
function Criaturas.bonusResistencia(patamar: number): number
	return math.ceil(Criaturas.molde(patamar).bonusAtaque / 2)
end

-- Ficha de jogo de uma entrada do catálogo (kind "creature").
function Criaturas.ficha(entrada)
	local dados = entrada.data
	local patamar = dados.patamar or 1
	local papel = dados.papel or "padrao"
	local molde = Criaturas.molde(patamar)
	local papelAplicado = Criaturas.aplicarPapel(patamar, papel)
	return {
		catalogId = entrada.id,
		nome = dados.nome,
		patamar = patamar,
		papel = papel,
		pvMax = papelAplicado.pv,
		ca = molde.ca,
		bonusAtaque = molde.bonusAtaque,
		danoPorTurno = papelAplicado.danoPorTurno,
		cdResistencia = molde.cdResistencia,
		bonusResistencia = Criaturas.bonusResistencia(patamar),
		bonusDeRank = math.clamp(math.round(patamar), 1, 6),
		deslocamentoMetros = dados.deslocamento or 9,
		resistencias = dados.resistencias or {},
		imunidades = dados.imunidades or {},
	}
end

return Criaturas
