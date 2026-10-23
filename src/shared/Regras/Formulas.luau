-- Cap. 2 §6–8; porte de lib/magiaTeorica.ts (site somente leitura).
-- Escopo: uma essência, UM verbo e as três formas do Alfabeto Arcano.
-- Sem Instances/eventos; RNG e ficha são fornecidos pelo chamador.
local Progressao = require(game:GetService("ReplicatedStorage").Shared.Regras.Progressao)
local F = {}
F.RANKS = table.freeze({ "Principiante", "Intermediário", "Avançado", "Santo", "Rei", "Imperador" })
F.POTENCIA = table.freeze({
	Principiante = { pm = 1, dados = 1, pv = 20, alcance = 9, tamanho = 3, acoes = 2 },
	["Intermediário"] = { pm = 2, dados = 2, pv = 40, alcance = 18, tamanho = 6, acoes = 2 },
	["Avançado"] = { pm = 5, dados = 5, pv = 60, alcance = 27, tamanho = 9, acoes = 3 },
	Santo = { pm = 6, dados = 6, pv = 80, alcance = 45, tamanho = 12, acoes = 3 },
	Rei = { pm = 10, dados = 10, pv = 100, alcance = 90, tamanho = 18, acoes = 4 },
	Imperador = { pm = 12, dados = 12, pv = 120, alcance = 150, tamanho = 30, acoes = 4 },
})
F.ESSENCIAS = table.freeze({
	mana = { nome = "Mana", glifo = "◇", tipo = "arcano" },
	fogo = { nome = "Fogo", glifo = "△", tipo = "ígneo", arvore = "fogo" },
	agua = { nome = "Água", glifo = "≋", tipo = "contundente", arvore = "agua" },
	vento = { nome = "Vento", glifo = "⌁", tipo = "cortante", arvore = "vento" },
	terra = { nome = "Terra", glifo = "▱", tipo = "contundente", arvore = "terra" },
	som = { nome = "Som", glifo = "♫", tipo = "sônico", arvore = "bardo" },
	vida = { nome = "Vida", glifo = "✧", tipo = "cura", arvore = "cura" },
})
F.VERBOS = table.freeze({ lancar = "Lançar", erguer = "Erguer", selar = "Selar", sinalizar = "Sinalizar" })
F.FORMAS = table.freeze({ circulo = "Círculo", linha = "Linha", quadrado = "Quadrado" })
local function inteiro(n) return type(n) == "number" and n == n and math.abs(n) < math.huge and n % 1 == 0 end
function F.rank(ficha)
	return ficha and ficha.construction and Progressao.maiorRank(ficha.construction, "teorica") or nil
end
function F.talento(ficha, id)
	return ficha ~= nil and ficha.construction ~= nil and table.find(ficha.construction.purchasedIds or {}, "talent/teorica/Principiante/" .. id) ~= nil
end
function F.conheceEssencia(ficha, id)
	local e = F.ESSENCIAS[id]
	if not e or not F.rank(ficha) then return false end
	return id == "mana" or F.talento(ficha, "simbolo-" .. id)
		or Progressao.rankAberto(ficha.construction, e.arvore, "Principiante")
end
local CONTATO = {
	fogo = "Quem encosta sofre %dd6 ígneo, Agilidade CD 8 + BC para metade, uma vez por rodada; arma não transmite calor.",
	agua = "Quem encosta testa Agilidade CD 8 + BC ou fica Molhado até o fim da próxima vez.",
	vento = "Quem encosta testa Força CD 8 + BC ou é empurrado 1,5 m para fora, uma vez por rodada.",
	terra = "Terra soma +50% dos PV base (soma com Quadrado).",
	som = "Encostar produz som audível a 18 m.",
	vida = "Ao erguer, um aliado ao toque recebe %d PV temporários por até 10 turnos.",
}
-- Resultado canônico independente dos recursos atuais. Nunca usa qualidade.
function F.validar(ficha, pedido, meio)
	if type(pedido) ~= "table" then return nil, "Fórmula deve ser uma tabela." end
	local rank = F.rank(ficha)
	if not rank then return nil, "Exige Alfabeto Arcano (Magia Teórica)." end
	if type(pedido.essencia) ~= "string" or not F.ESSENCIAS[pedido.essencia] then return nil, "Essência desconhecida." end
	if type(pedido.verbo) ~= "string" or not F.VERBOS[pedido.verbo] then return nil, "Escolha um dos quatro verbos do Alfabeto Arcano." end
	if type(pedido.forma) ~= "string" or not F.FORMAS[pedido.forma] then return nil, "Só Círculo, Linha e Quadrado são desenháveis nesta etapa." end
	if type(pedido.potencia) ~= "string" or not F.POTENCIA[pedido.potencia] then return nil, "Potência desconhecida." end
	if (table.find(F.RANKS, pedido.potencia) or 99) > (table.find(F.RANKS, rank) or 0) then return nil, "Potência excede o rank na Teórica." end
	if not F.conheceEssencia(ficha, pedido.essencia) then return nil, "Essência exige o talento ou o Principiante da escola de origem." end
	meio = meio or "ar"
	if meio ~= "ar" and meio ~= "giz" and meio ~= "bolso" then return nil, "Meio não implementado; pedra e fórmulas armadas ficam fora deste escopo." end
	if meio ~= "ar" and pedido.verbo == "lancar" then return nil, "Lançar sozinho não pode ser preparado, inclusive Vida." end
	if meio == "bolso" and not F.talento(ficha, "simbolo-rejeitar") then return nil, "Exige Fórmula de Bolso." end
	local p, e = F.POTENCIA[pedido.potencia], F.ESSENCIAS[pedido.essencia]
	local r = { essencia = pedido.essencia, verbo = pedido.verbo, forma = pedido.forma, potencia = pedido.potencia, meio = meio,
		pm = p.pm + (if pedido.essencia == "mana" then 0 else 1) + (if pedido.forma == "circulo" then 0 else 1),
		acoes = if meio == "ar" then p.acoes else 1, preparoSegundos = if meio == "ar" then 0 else 60,
		alcanceMetros = if pedido.verbo == "lancar" then math.floor(p.alcance * (if pedido.forma == "linha" then 1.5 else 1) / 1.5) * 1.5 else 1.5,
		tamanhoMetros = math.floor(p.tamanho * (if pedido.forma == "linha" then 1.5 else 1) / 1.5) * 1.5,
		duracaoRodadas = if pedido.verbo == "lancar" then 0 elseif pedido.verbo == "sinalizar" then 1 elseif meio == "ar" then 10 else 100,
		dados = p.dados, tipoDano = e.tipo, fere = pedido.verbo == "lancar" and pedido.essencia ~= "vida",
		cura = pedido.verbo == "lancar" and pedido.essencia == "vida", sustenta = pedido.verbo == "erguer" or pedido.verbo == "selar",
		leitura = e.nome .. " + " .. F.VERBOS[pedido.verbo] .. " + " .. F.FORMAS[pedido.forma],
	}
	if meio == "ar" then r.tamanhoMetros = math.min(r.tamanhoMetros, 12) end
	if pedido.verbo == "erguer" then
		r.pv = math.ceil(p.pv * (1 + (if pedido.forma == "quadrado" then 0.5 else 0) + (if pedido.essencia == "terra" then 0.5 else 0)))
		r.contato = CONTATO[pedido.essencia]
		if pedido.essencia == "fogo" then r.contatoDados = math.ceil(p.dados / 2); r.contato = string.format(r.contato, r.contatoDados) end
		if pedido.essencia == "vida" then r.pvTemp = p.dados * 5; r.contato = string.format(r.contato, r.pvTemp) end
		r.descricao = string.format("Parede: %d PV, até %g m. Segura corpos e projéteis; magia atravessa. %s", r.pv, r.tamanhoMetros, r.contato or "")
	elseif pedido.verbo == "selar" then
		r.tetoSelo = (table.find(F.RANKS, pedido.potencia) or 0) + (if pedido.essencia == "mana" then 0 else 1)
		r.descricao = "Fronteira sem PV. Magia até a potência" .. (if pedido.essencia == "mana" then "" else " +1 rank, só de " .. e.nome)
			.. ": bloqueada; 1 rank acima: dados, área e duração pela metade; 2+ acima: atravessa. Corpos, armas e Touki atravessam."
	elseif pedido.verbo == "sinalizar" then
		r.descricao = "Sinal de luz, som ou cheiro no desenho por 1 turno. Sem dano, cura ou condição."
	else
		r.descricao = string.format("%s %dd8%s; um alvo a até %g m.%s", if r.cura then "Cura" else "Ataque mágico:", p.dados,
			if r.cura then " PV, sem BC, alvo voluntário" else " + BC contra CA", r.alcanceMetros, if pedido.forma == "quadrado" then " Quadrado não altera Lançar." else "")
	end
	return r, nil
end
-- A escola vem da origem da MAGIA, não do tipo de dano (Pedrisco é Terra).
function F.fatorSelo(formula, rankMagia, escola, magica)
	if not magica or formula.verbo ~= "selar" then return 1 end
	local origem = F.ESSENCIAS[formula.essencia].arvore
	if origem and escola ~= origem then return 1 end
	local indice = table.find(F.RANKS, rankMagia)
	if rankMagia == "Deus" then indice = 7 end
	if not indice then return nil, "Rank da magia desconhecido; não presumir bloqueio." end
	local delta = indice - formula.tetoSelo
	return if delta <= 0 then 0 elseif delta == 1 then 0.5 else 1
end
function F.concentracao(random, espirito, maiorBonus, bonusAtacante, desvantagem)
	local a = random:NextInteger(1, 20)
	local b = if desvantagem then random:NextInteger(1, 20) else a
	local dado = math.min(a, b)
	local cd = if bonusAtacante then 10 + bonusAtacante else 12
	local total = dado + espirito + math.ceil(maiorBonus / 2)
	return { passou = total >= cd, dado = dado, total = total, cd = cd }
end
function F.reembolsoInterrupcao(pm) return pm - math.floor(pm / 2) end

-- Contrato do executor existente. O servidor decide Ações/PM (o chamador
-- pode reservar o custo primeiro para conjuração dividida entre turnos).
function F.mecanica(r)
	local m = { arvore = "teorica", estilo = "teorica", formula = r, nome = r.leitura,
		acoes = r.acoes, pm = r.pm, pt = 0, alcanceCasas = r.alcanceMetros / 1.5,
		duracaoRodadas = r.duracaoRodadas, descricao = r.descricao }
	if r.verbo == "lancar" then
		m.tipo = if r.cura then "cura" else "ataque"
		m.partes = {{ dados = r.dados .. "d8", bc = not r.cura, tipo = if r.cura then nil else r.tipoDano }}
		m.soAliados, m.permiteSi = r.cura, r.cura
	elseif r.verbo == "erguer" or r.verbo == "selar" then
		m.tipo, m.forma, m.comprimentoCasas = "zona", "linhaTransversal", r.tamanhoMetros / 1.5
		m.pvZona = r.pv
		m.bloqueiaMovimento = r.verbo == "erguer"
		-- Erguer deixa magia passar, inclusive a visão necessária à mira.
		m.bloqueiaProjeteis = r.verbo == "erguer"
	else m.tipo, m.alvoCasa, m.registro = "utilidade", true, r.descricao end
	return m
end

-- Régua: metade DOS DADOS, não do dano com BC. Área e duração se ajustam
-- antes de escolher alvos; a parcela fixa e a CD não são cortadas.
function F.reduzirMecanica(mec, fator)
	local m = table.clone(mec)
	if fator ~= 0.5 then return m end
	local function reduzirPartes(partes)
		local out = {}
		for _,parte in partes or {} do
			local p = table.clone(parte)
			if p.dados then
				local dados = {}
				for n,d in string.gmatch(p.dados, "(%d*)d(%d+)") do
					local qtd = math.floor((tonumber(n) or 1) / 2)
					if qtd > 0 then table.insert(dados,qtd .. "d" .. d) end
				end
				p.dados = if #dados > 0 then table.concat(dados,"+") else nil
			end
			table.insert(out,p)
		end
		return out
	end
	if m.partes then m.partes = reduzirPartes(m.partes) end
	if m.dados then
		local dados = {}
		for _,formula in m.dados do
			local reduzida = reduzirPartes({{dados=formula}})[1].dados
			if reduzida then table.insert(dados,reduzida) end
		end
		m.dados = dados
	end
	if m.segundoDisparo then m.segundoDisparo = reduzirPartes(m.segundoDisparo) end
	for _,campo in {"raioCasas","comprimentoCasas","duracaoRodadas"} do if m[campo] then m[campo] /= 2 end end
	if m.duracao and m.duracao.rodadas then m.duracao=table.clone(m.duracao); m.duracao.rodadas/=2 end
	return m
end

-- Reconhecimento cosmético, sem efeito em PM/ataque/concentração. Coordenadas
-- são pares {x,y}; o servidor recebe somente a forma canônica e a revalida.
local function distancia(a,b) return math.sqrt((a[1]-b[1])^2 + (a[2]-b[2])^2) end
local function distLinha(p,a,b)
	local dx,dy = b[1]-a[1],b[2]-a[2]
	local d = dx*dx+dy*dy
	if d == 0 then return distancia(p,a) end
	local u = math.clamp(((p[1]-a[1])*dx+(p[2]-a[2])*dy)/d,0,1)
	return distancia(p,{a[1]+u*dx,a[2]+u*dy})
end
local function simplificar(pontos, primeiro, ultimo, tolerancia, saida)
	local maior, indice = 0, primeiro
	for i=primeiro+1,ultimo-1 do
		local d = distLinha(pontos[i],pontos[primeiro],pontos[ultimo])
		if d > maior then maior,indice=d,i end
	end
	if maior > tolerancia then
		simplificar(pontos,primeiro,indice,tolerancia,saida); simplificar(pontos,indice,ultimo,tolerancia,saida)
	else table.insert(saida,pontos[primeiro]) end
end
function F.reconhecer(pontos)
	if type(pontos) ~= "table" or #pontos < 6 or #pontos > 512 then return nil, 0 end
	local minX,minY,maxX,maxY,comprimento = math.huge,math.huge,-math.huge,-math.huge,0
	for i,p in pontos do
		if type(p) ~= "table" or not inteiro(i) or type(p[1]) ~= "number" or type(p[2]) ~= "number"
			or p[1] ~= p[1] or p[2] ~= p[2] or math.abs(p[1]) > 10000 or math.abs(p[2]) > 10000 then return nil,0 end
		minX,minY,maxX,maxY=math.min(minX,p[1]),math.min(minY,p[2]),math.max(maxX,p[1]),math.max(maxY,p[2])
		if i>1 then comprimento+=distancia(p,pontos[i-1]) end
	end
	local span=math.max(maxX-minX,maxY-minY)
	if span < 24 or comprimento > span*6 then return nil,0 end
	local ponta=distancia(pontos[1],pontos[#pontos])
	if ponta/span > 0.7 and comprimento/ponta < 1.12 then
		local erro=0
		for _,p in pontos do erro=math.max(erro,distLinha(p,pontos[1],pontos[#pontos])/span) end
		if erro<0.06 then return "linha",math.clamp(1-erro*5,0,1) end
	end
	if ponta/span>0.22 or comprimento<span*2.5 then return nil,0 end
	local fechado=table.clone(pontos); table.insert(fechado,pontos[1])
	local vertices={}; simplificar(fechado,1,#fechado,span*0.06,vertices)
	-- Se o gesto começa no meio de um lado, elimina esse vértice colinear.
	local mudou=true
	while mudou and #vertices>3 do
		mudou=false
		for i,p in vertices do
			local anterior=vertices[(i-2)%#vertices+1]; local proximo=vertices[i%#vertices+1]
			if distLinha(p,anterior,proximo)<span*0.06 then table.remove(vertices,i); mudou=true; break end
		end
	end
	if #vertices==4 then
		local menor,maior,ortogonal=math.huge,0,true
		for i,p in vertices do
			local a,b=vertices[(i-2)%4+1],vertices[i%4+1]
			local la,lb=distancia(p,a),distancia(p,b)
			menor,maior=math.min(menor,lb),math.max(maior,lb)
			if la*lb==0 or math.abs(((a[1]-p[1])*(b[1]-p[1])+(a[2]-p[2])*(b[2]-p[2]))/(la*lb))>0.35 then ortogonal=false end
		end
		if ortogonal and menor/maior>0.7 then return "quadrado",menor/maior end
	end
	local cx,cy=(minX+maxX)/2,(minY+maxY)/2
	local raio,soma,erro=span/2,0,0
	for _,p in pontos do soma+=distancia(p,{cx,cy}) end
	local media=soma/#pontos
	for _,p in pontos do erro+=(distancia(p,{cx,cy})-media)^2 end
	erro=math.sqrt(erro/#pontos)/raio
	if math.min(maxX-minX,maxY-minY)/span>0.72 and erro<0.13 then return "circulo",math.clamp(1-erro*4,0,1) end
	return nil,0
end
return F
