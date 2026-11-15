-- Layout puro da barra de atalhos do canto superior direito (client/Atalhos): ordem dos botões e medidas
-- que cabem na largura da tela. Sem Instances; quem monta a barra é o client (UIListLayout).
local L = {}

-- Ordem fixa da barra. "?" e "RUN" são nomes antigos do mesmo atalho (AJUDA, DIÁRIO).
L.ORDEM = table.freeze({ "MENU", "DIÁRIO", "ÁRVORES", "CONTA", "AJUDA" })
L.ALIAS = table.freeze({ ["?"] = "AJUDA", RUN = "DIÁRIO" })
L.LARGURA, L.ALTURA = 68, 46 -- todos os botões têm o mesmo tamanho
L.ESPACO = 6 -- entre botões
L.PADDING = 6 -- da moldura da barra até os botões
L.MARGEM = 8 -- da barra até a borda da tela
L.MIN_LARGURA = 44 -- toque mínimo

-- Posição de um rótulo na ordem; rótulos desconhecidos vão depois dos conhecidos.
function L.posicao(rotulo: string): number
	local nome = L.ALIAS[rotulo] or rotulo
	return table.find(L.ORDEM, nome) or (#L.ORDEM + 1)
end

-- Índices dos rótulos recebidos na ordem da barra (estável: empate mantém a ordem de chegada).
function L.ordem(rotulos: { string }): { number }
	local indices = {}
	for i in rotulos do table.insert(indices, i) end
	table.sort(indices, function(a, b)
		local pa, pb = L.posicao(rotulos[a]), L.posicao(rotulos[b])
		if pa ~= pb then return pa < pb end
		return a < b
	end)
	return indices
end

-- Medidas para `quantidade` botões numa tela de `larguraTela` px: encolhe a largura (até MIN_LARGURA)
-- quando a tela é estreita.
function L.medidas(quantidade: number, larguraTela: number)
	if quantidade <= 0 then return { largura = L.LARGURA, altura = L.ALTURA, total = 0, barra = 0 } end
	local livre = larguraTela - 2 * L.MARGEM - 2 * L.PADDING - (quantidade - 1) * L.ESPACO
	local largura = math.clamp(math.floor(livre / quantidade), L.MIN_LARGURA, L.LARGURA)
	local total = quantidade * largura + (quantidade - 1) * L.ESPACO
	return { largura = largura, altura = L.ALTURA, total = total, barra = total + 2 * L.PADDING }
end

-- Tamanho do texto do rótulo: o padrão cabe em 68 px; botões mais estreitos usam um corpo menor.
function L.tamanhoTexto(largura: number): number
	return if largura >= L.LARGURA - 4 then 14 else 13
end

-- Caixas (x, y, largura, altura) de cada rótulo, na ordem da barra, medidas a partir da borda
-- esquerda da barra (dentro do padding). Serve para conferir ausência de sobreposição.
function L.caixas(rotulos: { string }, larguraTela: number)
	local m = L.medidas(#rotulos, larguraTela)
	local caixas = {}
	for posicao, indice in L.ordem(rotulos) do
		table.insert(caixas, {
			rotulo = rotulos[indice], x = L.PADDING + (posicao - 1) * (m.largura + L.ESPACO), y = L.PADDING,
			largura = m.largura, altura = m.altura,
		})
	end
	return caixas, m
end

return L
