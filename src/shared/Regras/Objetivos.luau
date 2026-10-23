-- Projeta o próximo passo compreensível a partir do snapshot da run e do mundo.
-- Módulo puro: não cria Instances nem decide/avança regras da run.
-- Prioridade: combate -> sem RUN -> fim -> provação ativa -> evento -> pegar/entregar Selo
-- (somente opções liberadas) -> prazo expirado -> árvore zero -> treino sem árvore -> nó/história.
local Objetivos = {}

local function alvo(tipo, id, posicao)
	local resultado = { tipo = tipo, id = id }
	if posicao then resultado.posicao = { x = posicao.x, y = posicao.y, z = posicao.z } end
	return resultado
end

local function objetivo(chave, titulo, linha, destino)
	return { chave = chave, titulo = titulo, linha = linha, alvo = destino }
end

local function opLiberada(run, id)
	for _, op in run.opcoes or {} do
		if op.id == id and op.liberada == true then return op end
	end
	return nil
end

local function treinadorProximo(estado)
	local escolhido, distancia
	local pos = estado.posicao
	if type(pos) ~= "table" then return nil end
	for _, npc in estado.treinadores or {} do
		if npc.disponivel == true and type(npc.posicao) == "table" then
			local dx, dy, dz = npc.posicao.x - pos.x, npc.posicao.y - pos.y, npc.posicao.z - pos.z
			local d = dx * dx + dy * dy + dz * dz
			if distancia == nil or d < distancia or (d == distancia and npc.id < escolhido.id) then
				escolhido, distancia = npc, d
			end
		end
	end
	return escolhido
end

local function votar(run, op, chave, titulo)
	return objetivo(chave, titulo, "Abra a RUN e vote: " .. op.texto)
end

local function objetivoHistoria(run, estado)
	local op
	if run.galho == "vila" then
		if run.mundoAberto then
			if (run.dia or 0) < 2 and (run.diasRestantes or 0) > 3 and not run.cacadaConcluida then
				return objetivo("fazer-cacada", "Faça uma caçada", "Ganhe ouro e PA de aprimoramento no quadro de caçadas perto da praça.", alvo("destino", "quadro-cacadas", {x=21,y=0,z=-183}))
			end
			return objetivo("seguir-floresta", "Siga para a Floresta Sombria", "Siga a trilha a pé; o tempo passa enquanto explora.", alvo("destino", "floresta", {x=0,y=0,z=-310}))
		end
		op = opLiberada(run, "rumo-a-floresta") or opLiberada(run, "rumo-as-ruinas")
		if op then return votar(run, op, "seguir-historia", "Escolha uma região") end
	elseif run.galho == "floresta-sombria" then
		op = opLiberada(run, "enfrentar-o-guardiao")
		if op then return votar(run, op, "enfrentar-guardiao", "Enfrente o guardião") end
	elseif run.galho == "ruinas-do-vale" then
		op = opLiberada(run, "entrar-na-camara") or opLiberada(run, "forcar-a-passagem")
		if op then return votar(run, op, "abrir-caminho", "Avance pelas ruínas") end
	elseif run.galho == "chefe-floresta" or run.galho == "chefe-ruinas" then
		op = opLiberada(run, "pegar-o-selo")
		if op then return votar(run, op, "pegar-selo", "Pegue o Selo") end
		if run.luta then
			local regiaoDoChefe = if run.galho == "chefe-floresta" then "floresta-sombria" else "ruinas-do-vale"
			local ponto = estado.destinos and estado.destinos[run.galho]
			local destino = if run.regiao == regiaoDoChefe and ponto then alvo("destino", run.galho, ponto) else nil
			return objetivo("vencer-guardiao", "Enfrente o guardião", "Abra a RUN e entre na luta.", destino)
		end
		return nil
	elseif run.galho == "retorno" then
		op = opLiberada(run, "entregar-o-selo")
		if op then return votar(run, op, "voltar-vila", "Entregue o Selo") end
	elseif run.galho == "final-selo" or (run.fim and run.fim.motivo == "final") then
		return objetivo("final-concluido", "O Selo voltou para casa", "A história foi concluída.")
	end
	local opcoes = {}
	for _, opcao in run.opcoes or {} do if opcao.liberada then table.insert(opcoes, opcao) end end
	if #opcoes > 0 then return votar(run, opcoes[1], "seguir-historia", run.titulo or "Continue a história") end
	return nil
end

local function calcular(estado)
	if type(estado) ~= "table" then return nil end
	if estado.emEncontro then return nil end
	local run = estado.run
	if type(run) == "table" and run.semRun == true then run = nil end
	if type(run) ~= "table" then
		if estado.semRun or type(estado.run) == "table" and estado.run.semRun == true then return objetivo("iniciar-run", "Inicie uma RUN", "Vá ao painel e comece uma RUN.") end
		return nil
	end
	if run.fim then
		if run.fim.motivo == "final" then return objetivo("final-concluido", "O Selo voltou para casa", "A história foi concluída.") end
		return objetivo("run-encerrada", "RUN encerrada", "Consulte o painel para ver o resultado.")
	end
	local provacao = estado.provacao
	if provacao and provacao.estado == "em-curso" then
		if provacao.npcId == "vila-1" then
			if provacao.sino == true then
				return objetivo("prova-vila-1-portao", "Volte ao portão", "Leve o sino ao portão sem ser visto.", alvo("destino", "portao", estado.destinos and estado.destinos.portao))
			end
			return objetivo("prova-vila-1-sino", "Pegue o sino", "Pegue o sino e volte ao portão sem ser visto.", alvo("destino", "sino", estado.destinos and estado.destinos.sino))
		elseif provacao.npcId == "vila-2" then
			return objetivo("prova-vila-2", "Conclua a provação", "Faça a água passar pelas três bacias.", alvo("destino", "agua", estado.destinos and estado.destinos.agua))
		end
	end
	if run.evento then return objetivo("resolver-evento", "Resolva o evento", "Escolha uma opção no painel da RUN.") end
	if run.mundoAberto and run.seloObtido and run.galho ~= "retorno" then
		return objetivo("voltar-vila", "Leve o Selo à vila", "Volte a pé e entregue o Selo na praça.", alvo("destino", "vila", {x=0,y=0,z=-190}))
	end

	for _, op in run.opcoes or {} do
		if op.id == "pegar-o-selo" and op.liberada == true then
			return votar(run, op, "pegar-selo", "Pegue o Selo")
		end
	end
	if run.galho == "retorno" then
		local op = opLiberada(run, "entregar-o-selo")
		if op then return votar(run, op, "entregar-selo", "Entregue o Selo") end
	end
	if run.objetivo and run.objetivo.status == "expirado" then
		return objetivo("prazo-esgotado", "O prazo terminou", "Consulte o painel da RUN para ver as opções disponíveis.")
	end

	local plano = run.plano or {}
	local arvore = estado.arvore or plano.escolhida or plano.arvore
	if plano.modo == "zero" and not arvore then
		return objetivo("escolher-arvore", "Escolha sua árvore", "Escolha uma árvore no painel da RUN.")
	end
	if plano.modo == "semArvore" and not arvore and (run.diasRestantes or 0) >= 1 then
		local npc = treinadorProximo(estado)
		if npc then
			local conversado = estado.conversados and estado.conversados[npc.id] == true
			local oferta = estado.ofertas and estado.ofertas[npc.id]
			if not conversado then return objetivo("conversar-treinador", "Fale com um mestre da vila", "Siga o marcador e peça orientação.", alvo("treinador", npc.id, npc.posicao)) end
			if not oferta or oferta.podeComprar == true then
				return objetivo("iniciar-provacao", "Faça a provação", "Aceite o desafio para aprender com o treinador.", alvo("treinador", npc.id, npc.posicao))
			end
		end
	end
	return objetivoHistoria(run, estado)
end

function Objetivos.atual(estado)
	local atual = calcular(estado)
	local run = type(estado) == "table" and estado.run or nil
	if atual and not atual.chave:find("prova", 1, true) and type(run) == "table" and not run.fim and run.objetivo and run.objetivo.status == "ativo" then
		local restantes = run.diasRestantes
		if type(restantes) ~= "number" and type(run.objetivo.prazoFinal) == "number" and type(run.dia) == "number" then
			restantes = math.max(0, run.objetivo.prazoFinal - run.dia)
		end
		if type(restantes) == "number" then
			atual.linha ..= string.format(" · Restam %.1f dias", restantes)
		end
	end
	return atual
end

return Objetivos
