-- Adapta itens consumíveis explicitamente suportados ao encontro J2.
-- Não concede itens nem altera a ficha de campanha; o servidor aplica o consumo.
local Combate = require(game:GetService("ReplicatedStorage").Shared.Regras.Combate)

local Itens = {}
local POCAO_MENOR = "item/pocao_menor_cura"
local NOME_POCAO_MENOR = "Poção Menor de Cura"
local DESCRICAO_POCAO_MENOR = "Cura 1d8 + 2 PV. Beber ou dar a um aliado adjacente é Usar Item (1 Ação). Poção não é magia: a Ferida Fresca não a dobra, e nenhuma poção apaga Ferimento Crítico."

local function inteiro(valor)
	return type(valor) == "number" and valor == valor and valor % 1 == 0
end

local function indicePocao(ficha)
	local construcao = type(ficha) == "table" and ficha.construction
	local inventario = type(construcao) == "table" and construcao.inventory
	if type(inventario) ~= "table" then return nil end
	for indice, item in ipairs(inventario) do
		if type(item) == "table" and item.name == NOME_POCAO_MENOR and item.type == "geral"
			and item.description == DESCRICAO_POCAO_MENOR
		then return indice, item end
	end
	return nil
end

function Itens.disponiveis(ator)
	if type(ator) ~= "table" or ator.kind ~= "jogador" or not indicePocao(ator.ficha) then return {} end
	return { POCAO_MENOR }
end

function Itens.usar(rng, itemId, atacante, alvo)
	if itemId ~= POCAO_MENOR then return nil, "Este item não está implementado no encontro." end
	if (typeof(rng) ~= "table" and typeof(rng) ~= "Random") or type(rng.NextInteger) ~= "function"
		or type(atacante) ~= "table" or atacante.kind ~= "jogador"
		or type(alvo) ~= "table" or alvo.kind ~= "jogador"
	then return nil, "Poção exige um jogador e um aliado do encontro." end
	local _, item = indicePocao(atacante.ficha)
	if not item then return nil, "A Poção Menor de Cura não está no inventário." end
	if not inteiro(atacante.pv) or atacante.pv <= 0
		or not inteiro(atacante.x) or not inteiro(atacante.z)
		or not inteiro(alvo.x) or not inteiro(alvo.z)
		or not inteiro(alvo.pv) or alvo.pv < 0 or not inteiro(alvo.pvMax) or alvo.pvMax <= 0
		or alvo.pv >= alvo.pvMax
	then return nil, "Estado ou alvo da poção inválido." end
	local distancia = Combate.distancia(atacante.x, atacante.z, alvo.x, alvo.z)
	if distancia > 1 then return nil, "A poção exige alvo próprio ou aliado adjacente." end
	local cura = rng:NextInteger(1, 8) + 2
	local pv = math.min(alvo.pvMax, alvo.pv + cura)
	return {
		actorId = atacante.id, targetId = alvo.id, action = "use-item", itemId = POCAO_MENOR,
		itemName = NOME_POCAO_MENOR, actionsCost = 1, distance = distancia,
		healing = pv - alvo.pv, targetPv = pv, targetDowned = pv <= 0,
		inventorySourceLocalId = item.sourceLocalId,
	}, nil
end

function Itens.pocaoMenorId()
	return POCAO_MENOR
end

return Itens
