--!strict
-- HAB8: destaques de jogo de um golpe (puro, só apresentação): o que o jogador deve sentir como "fiz algo especial".
-- Lê o resumo do alvo no recibo (HabilidadeService.resumoDoEfeito): `furtivo = { dados, total, triplo }` (Dano Furtivo,
-- triplo no Primeiro Golpe) e `combo` (bônus do Golpe Contínuo por já ter acertado no turno). Não decide regra.
-- O combo é bônus de ACERTO: o texto não mostra "+4" para não parecer dano extra.
local M = {}

export type Destaque = { chave: string, texto: string, curto: string, forte: boolean }

function M.listar(alvo: any): { Destaque }
	local saida: { Destaque } = {}
	if type(alvo) ~= "table" or alvo.acertou == false then
		return saida
	end
	local f = alvo.furtivo
	if type(f) == "table" and type(f.total) == "number" and f.total > 0 then
		if f.triplo then
			table.insert(saida, { chave = "furtivo-triplo", texto = "FURTIVO ×3  +" .. f.total, curto = "Furtivo ×3", forte = true })
		else
			table.insert(saida, { chave = "furtivo", texto = "FURTIVO  +" .. f.total, curto = "Furtivo", forte = false })
		end
	end
	if type(alvo.combo) == "number" and alvo.combo > 0 then
		table.insert(saida, { chave = "combo", texto = "COMBO!", curto = "Combo", forte = false })
	end
	return saida
end

-- Prefixo para a linha de resultado da faixa ("Furtivo ×3 · 18 de dano"); "" sem destaque.
function M.prefixo(alvos: { any }?): string
	local vistos, partes = {}, {}
	for _, a in alvos or {} do
		for _, d in M.listar(a) do
			if not vistos[d.chave] then
				vistos[d.chave] = true
				table.insert(partes, d.curto)
			end
		end
	end
	return table.concat(partes, " · ")
end

return M
