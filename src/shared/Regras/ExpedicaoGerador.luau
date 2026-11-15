-- Gera a história de uma expedição (DIRECAO §4): cidade → N salas com escolha de caminho → chefe → volta.
-- Pura e determinística: mesma semente = mesma história (gerador congruente próprio, sem Random).
-- Nós: "cidade", "<id>-1", "<id>-<i>a"/"<id>-<i>b" (i = 2..passos), "<id>-chefe", "final-<id>".
local Gerador = {}

Gerador.OBJETIVO = table.freeze({ id = "limpar-o-esgoto", prazoDias = 30 })

local function sorteador(semente)
	local estado = (math.floor(tonumber(semente) or 0) % 2147483646) + 1
	return function(n)
		estado = (estado * 48271) % 2147483647
		return estado % n + 1
	end
end

function Gerador.gerar(area, semente)
	local sorte = sorteador(semente)
	local id, c, n = area.id, area.custos, area.passos
	local nos = {}

	local function sala(idNo, passo, encontro)
		return { tipo = "sala", regiao = area.regiao, titulo = area.titulo, passo = passo, total = n, area = id,
			dica = encontro.dica, luta = { criaturas = encontro.criaturas, areaId = area.areaId }, opcoes = {} }
	end
	-- Duas alternativas com encontros diferentes (índices sorteados sem repetir).
	local function par()
		local a = sorte(#area.encontros)
		local b = sorte(#area.encontros - 1)
		if b >= a then b += 1 end
		return area.encontros[a], area.encontros[b]
	end
	-- Dias de voltar à cidade a partir de um passo (múltiplos de 0,25).
	local function diasDeVoltar(passo) return math.max(1, passo * c.voltarPorPasso) end
	local function opcoesDe(idNo, passo, destinos)
		local venceu = { flag = "vencido/" .. idNo }
		local lista = {}
		for _, d in destinos do
			table.insert(lista, { id = d.opcao, texto = d.texto, dica = d.dica, para = d.para, exige = venceu })
		end
		table.insert(lista, { id = "voltar-a-cidade", texto = "Voltar à cidade", para = "cidade", dias = diasDeVoltar(passo), exige = venceu })
		return lista
	end

	nos["cidade"] = { tipo = "hub", regiao = "vila", titulo = "A cidade", opcoes = {
		{ id = "entrar-" .. id, texto = "Descer ao " .. string.lower(string.sub(area.titulo, 1, 1)) .. string.sub(area.titulo, 2), para = id .. "-1", dias = c.entrar },
	} }

	local primeiro = area.encontros[sorte(#area.encontros)]
	nos[id .. "-1"] = sala(id .. "-1", 1, primeiro)
	local atuais = { id .. "-1" }
	for i = 2, n do
		local ea, eb = par()
		local ida, idb = id .. "-" .. i .. "a", id .. "-" .. i .. "b"
		nos[ida], nos[idb] = sala(ida, i, ea), sala(idb, i, eb)
		for _, idNo in atuais do
			nos[idNo].opcoes = opcoesDe(idNo, i - 1, {
				{ opcao = "caminho-a", texto = "Seguir pelo caminho da esquerda", dica = ea.dica, para = ida },
				{ opcao = "caminho-b", texto = "Seguir pelo caminho da direita", dica = eb.dica, para = idb },
			})
		end
		atuais = { ida, idb }
	end

	local idChefe = id .. "-chefe"
	for _, idNo in atuais do
		nos[idNo].opcoes = opcoesDe(idNo, n, { { opcao = "enfrentar-o-chefe", texto = "Seguir até a câmara do chefe", para = idChefe } })
	end
	nos[idChefe] = { tipo = "chefe", regiao = area.regiao, titulo = area.chefe.titulo, passo = n, total = n, area = id,
		luta = { criaturas = area.chefe.criaturas, areaId = area.areaId }, opcoes = {
			{ id = "voltar-com-a-recompensa", texto = "Voltar com a recompensa", para = "final-" .. id,
				exige = { flag = "vencido/" .. idChefe }, marca = "expedicao/" .. id .. "/concluida" },
		} }
	-- Retomada: da cidade direto a uma sala já vencida (progresso mantido).
	-- TODO: combates reduzidos no caminho de volta/retomada (adiado).
	for idNo, no in nos do
		if no.tipo == "sala" then
			table.insert(nos["cidade"].opcoes, { id = "retomar-" .. id .. "-" .. idNo, texto = "Retomar no passo " .. no.passo .. " (" .. idNo .. ")",
				para = idNo, dias = c.entrar + no.passo * c.voltarPorPasso, exige = { flag = "vencido/" .. idNo } })
		end
	end
	table.sort(nos["cidade"].opcoes, function(a, b) return a.id < b.id end)
	nos["final-" .. id] = { tipo = "final", regiao = "vila", titulo = "De volta à cidade", cumpreObjetivo = true }

	return { id = "expedicao-" .. id, inicio = "cidade", nos = nos }
end

return Gerador
