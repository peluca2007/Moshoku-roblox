-- Projeta somente o snapshot filtrado. Não calcula alcance nem concede bônus.
local A = {}
function A.resumir(snap)
	local proprios, amigos, porId = {}, {}, {}
	for _, token in snap.tokens do
		porId[token.id] = token
		if token.apoio and (token.aliadoSeu or token.ownerUserId == snap.you.userId) then
			table.insert(amigos, token)
			if token.ownerUserId == snap.you.userId and token.apoio.bardo then table.insert(proprios, token) end
		end
	end
	local function ordenar(a, b)
		if a.name == b.name then return a.id < b.id end
		return a.name < b.name
	end
	table.sort(proprios, ordenar); table.sort(amigos, ordenar)
	local function nomes(ids)
		local lista, vistos = {}, {}
		for _, id in ids or {} do
			if porId[id] and not vistos[id] then
				vistos[id] = true
				table.insert(lista, porId[id].name)
			end
		end
		table.sort(lista)
		return if #lista > 0 then table.concat(lista, ", ") else "nenhuma ficha visível no alcance"
	end
	local linhas, resumo, cancoes, afetados = {}, {}, 0, 0
	for _, token in proprios do
		local a = token.apoio
		local cancao = if a.cancao == "marcha" then "Marcha" elseif a.cancao == "dissonancia" then "Dissonância" else "Sem canção"
		if a.cancao then cancoes += 1 end
		local usos = string.format("Inspiração %s: %d/%d", a.dadoInspiracao, math.max(0, a.inspiracoesMax - a.inspiracoesUsadas), a.inspiracoesMax)
		table.insert(resumo, cancao .. " • " .. usos)
		table.insert(linhas, token.name .. " • " .. cancao)
		table.insert(linhas, usos .. " usos restantes por descanso.")
		if a.cancao == "marcha" then
			table.insert(linhas, "+1 casa de movimento: " .. nomes(a.beneficiados) .. ". Saiu de 12 casas ou não ouve: perde o bônus.")
		elseif a.cancao == "dissonancia" then
			table.insert(linhas, a.dissonancia .. " sônico no início da sua próxima vez; até " .. a.limiteDissonancia .. " inimigo(s) mais próximo(s) que ouvem, em 12 casas.")
		end
		table.insert(linhas, "1 canção por vez. Trocar substitui a anterior; manter não gasta Ação.")
		table.insert(linhas, "Pode combinar com Inspiração, Insulto e Refrão; canção não combina com magia sustentada.")
		table.insert(linhas, "Aliado guarda a Inspiração até usar; não acumula.\n")
	end
	local efeitos = {}
	for _, token in amigos do
		local a, lista = token.apoio, {}
		if a.marcha > 0 then table.insert(lista, "Marcha +1 casa") end
		if a.inspiracao then table.insert(lista, "Inspiração " .. a.inspiracao .. " guardada") end
		if a.pvTemp > 0 then table.insert(lista, a.pvTemp .. " PV temporários") end
		if #lista > 0 then
			afetados += 1
			table.insert(efeitos, token.name .. ": " .. table.concat(lista, " • "))
		end
	end
	if #proprios > 1 then resumo = { string.format("%d bardos • %d canções ativas", #proprios, cancoes) } end
	table.insert(resumo, string.format("Apoio em %d ficha(s) visível(is)", afetados))
	table.insert(linhas, "QUEM RECEBE APOIO")
	table.insert(linhas, if #efeitos > 0 then table.concat(efeitos, "\n") else "Nenhuma ficha visível recebe bônus agora.")
	return { visivel = snap.combat.active and (#proprios > 0 or afetados > 0), resumo = table.concat(resumo, "\n"), texto = table.concat(linhas, "\n"), afetados = afetados }
end
return table.freeze(A)
