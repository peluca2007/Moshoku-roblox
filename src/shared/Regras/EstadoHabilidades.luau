-- Projeções puras do estado de combate. Sem Instances, relógio global ou RNG.
local Estado = {}

function Estado.resistencia(sheet, maiorRank: number, atributo: string): number
	local atributos = sheet or {}
	local valor = if atributo == "forcaOuAgilidade" then math.max(atributos.forca or 0, atributos.agilidade or 0) else atributos[atributo] or 0
	return valor + math.ceil(maiorRank / 2)
end

function Estado.patamar(token): number
	if token.criatura then return token.criatura.patamar or 0 end
	return if token.ficha2 then token.ficha2.calculated.highestRankBonus or 0 else 0
end

-- Livro, árvore Cura: dano desde o FIM do último turno de quem cura, inclusive
-- dano absorvido por PV temporários. Sequência causal evita empates no turno.
function Estado.feridaFresca(alvo, conjurador, rodada: number): boolean
	if alvo.feridaSeladaAte and rodada < alvo.feridaSeladaAte then return true end
	return alvo.ultimoDano ~= nil and alvo.ultimoDano > (conjurador and conjurador.fimUltimoTurno or 0)
end

return Estado
