-- Treinadores da vila a cada run (PLANO §12): 3–4 num sorteio SEPARADO da oferta de árvores da criação,
-- e uma chance de um extra na taverna. Cada treinador ensina uma árvore elegível (RunArvoresForca).
-- Puro: o gerador é injetado. Nomes de NPC e avatares ficam para o Pedro escolher; aqui só há o título.
-- Valores PROVISÓRIOS (quantidade, chance da taverna, dias de treino): docs/FIDELIDADE.md "R3c".
local Shared = game:GetService("ReplicatedStorage").Shared
local Sorteios = require(Shared.Regras.RunSorteios)
local Forca = require(Shared.Regras.RunArvoresForca)

local Treinadores = {}

Treinadores.QUANTIDADE_NA_VILA = 3
Treinadores.CHANCE_TAVERNA = 25 -- em %, de aparecer UM treinador extra
Treinadores.FORCA_RARA = 8 -- árvore desta força para cima só vem pela taverna e treina em mais dias
Treinadores.DIAS_COMUM = 1
Treinadores.DIAS_RARO = 2
-- T1: reversóvel; preserva o sorteio anterior e seus parâmetros.
Treinadores.SOMENTE_FIXOS = true
Treinadores.FIXOS = { "furtividade-e-armadilhas", "agua" }

-- Título do treinador por árvore (a árvore é a chave de RunArvoresForca.ARVORES).
Treinadores.TITULOS = table.freeze({
	["agua"] = "Mestra da Água",
	["desintoxicacao"] = "Alquimista",
	["terra"] = "Mestre da Terra",
	["fogo"] = "Mago de Fogo",
	["vento"] = "Mago do Vento",
	["cura"] = "Curandeira",
	["teorica"] = "Teórico",
	["invocacao"] = "Invocador",
	["armas-pesadas"] = "Lutador",
	["arquearia"] = "Arqueira",
	["cavalaria-e-escudos"] = "Cavaleiro",
	["deus-da-agua-corpo"] = "Duelista da Água",
	["deus-da-espada"] = "Espadachim",
	["deus-do-norte"] = "Guerreiro do Norte",
	["punho-de-fogo"] = "Punho Ardente",
	["vendaval"] = "Lâmina do Vendaval",
	["bardo-e-interacao"] = "Bardo",
	["furtividade-e-armadilhas"] = "Ladino",
	["navegacao-e-lideranca"] = "Tático",
})

function Treinadores.raro(arvore)
	local forca = Forca.forca(arvore)
	return forca ~= nil and forca >= Treinadores.FORCA_RARA
end

function Treinadores.diasDeTreino(arvore)
	if Forca.ARVORES[arvore] == nil then return nil end
	if Treinadores.SOMENTE_FIXOS then return 1 end
	return if Treinadores.raro(arvore) then Treinadores.DIAS_RARO else Treinadores.DIAS_COMUM
end

function Treinadores.titulo(arvore)
	return Treinadores.TITULOS[arvore]
end

-- Candidatos no formato de Sorteios.treinadoresDaVila: só árvores elegíveis. Árvores raras NÃO entram no
-- sorteio comum da vila: aparecem apenas como extra da taverna (`taverna = true`).
function Treinadores.candidatos()
	local lista = {}
	for _, c in Forca.candidatas() do
		local raro = Treinadores.raro(c.id)
		table.insert(lista, { id = c.id, peso = 1, taverna = raro, soTaverna = raro })
	end
	return lista
end

-- Devolve { vila = { arvore... }, taverna = arvore | nil }. `opcoes.quantidade`/`opcoes.chanceTaverna` sobrescrevem
-- os padrões; `opcoes.liberadas` restringe às árvores que a conta já liberou. A árvore que o jogador já sorteou na criação não é excluída aqui: o treinador pode ensinar outra.
function Treinadores.sortearAleatorio(rng, opcoes)
	opcoes = opcoes or {}
	local quantidade = opcoes.quantidade or Treinadores.QUANTIDADE_NA_VILA
	local chance = opcoes.chanceTaverna or Treinadores.CHANCE_TAVERNA
	local todos = Treinadores.candidatos()
	local liberadas = opcoes.liberadas -- conjunto { [arvore] = true } vindo da conta (RunConta); nil = todas
	local function liberada(c) return liberadas == nil or liberadas[c.id] == true end
	local comuns = {}
	for _, c in todos do
		if not c.soTaverna and liberada(c) then table.insert(comuns, c) end
	end
	if #comuns < quantidade then return nil, "Poucos treinadores elegíveis." end
	-- Vila: só comuns. Taverna: com a chance dada, uma árvore rara ou comum que não saiu na vila.
	local vila, motivo = Sorteios.treinadoresDaVila(comuns, quantidade, 0, rng)
	if not vila then return nil, motivo end
	local saiu = {}
	for _, id in vila do saiu[id] = true end
	local candidatosTaverna = {}
	for _, c in todos do
		if c.taverna and liberada(c) and not saiu[c.id] then table.insert(candidatosTaverna, c) end
	end
	local taverna
	if type(chance) == "number" and chance > 0 and #candidatosTaverna > 0 and rng:NextInteger(1, 100) <= chance then
		local extra = Sorteios.ponderado(candidatosTaverna, 1, rng)
		taverna = extra and extra[1]
	end
	return { vila = vila, taverna = taverna }
end

-- F4: custo provisório em PA de aprimoramento (não ações do combate).
function Treinadores.sortear(rng, opcoes)
 if Treinadores.SOMENTE_FIXOS then return { vila = table.clone(Treinadores.FIXOS) } end
 return Treinadores.sortearAleatorio(rng, opcoes)
end
Treinadores.CUSTO_PA = 0
-- Quatro vagas na praça e uma junto à fachada da taverna, fora da porta.
Treinadores.PONTOS = table.freeze({
	{ x = -16, z = -188, sx = 4, sz = 4 },
	{ x = 16, z = -188, sx = 4, sz = 4 },
	{ x = 16, z = -158, sx = 4, sz = 4 },
	{ x = -16, z = -158, sx = 4, sz = 4 },
})
Treinadores.PONTO_TAVERNA = table.freeze({ x = -22, z = -176, sx = 4, sz = 4 })

function Treinadores.listar(sorteio)
	local lista = {}
 if Treinadores.SOMENTE_FIXOS then
  local L = require(Shared.Mundo.TreinadoresLayout)
  return {
   { id = "vila-1", arvore = Treinadores.FIXOS[1], ponto = L.LADINO },
   { id = "vila-2", arvore = Treinadores.FIXOS[2], ponto = L.mestra() },
  }
 end
 if not sorteio then return lista end
	for i, arvore in sorteio.vila do
		table.insert(lista, { id = "vila-" .. i, arvore = arvore, ponto = Treinadores.PONTOS[i] })
	end
	if sorteio.taverna then table.insert(lista, { id = "taverna", arvore = sorteio.taverna, ponto = Treinadores.PONTO_TAVERNA }) end
	return lista
end

function Treinadores.validarSorteio(sorteio)
	if type(sorteio) == "table" and type(sorteio.vila) == "table" and #sorteio.vila == 2
  and sorteio.vila[1] == Treinadores.FIXOS[1] and sorteio.vila[2] == Treinadores.FIXOS[2] and sorteio.taverna == nil then return true end
 if type(sorteio) ~= "table" or type(sorteio.vila) ~= "table" or #sorteio.vila < 3 or #sorteio.vila > 4 then return false end
	local vistos = {}
	for i, id in sorteio.vila do
		if type(i) ~= "number" or i % 1 ~= 0 or i < 1 or i > #sorteio.vila
			or type(id) ~= "string" or not Forca.elegivel(id) or Treinadores.raro(id) or vistos[id] then return false end
		vistos[id] = true
	end
	return sorteio.taverna == nil or (type(sorteio.taverna) == "string" and Forca.elegivel(sorteio.taverna) and Treinadores.raro(sorteio.taverna) and not vistos[sorteio.taverna])
end

-- Primeira árvore: só quem começou sem árvore (uma vez). Segunda árvore (P2): quem já tem uma pode passar na
-- provação de outro mestre (o livro permite aprender outra árvore com um mestre); limite provisório de UMA segunda
-- por run, sem PA. Devolve { arvore, segunda = boolean } ou nil + motivo.
function Treinadores.escolher(plano, arvore)
	if type(plano) ~= "table" then return nil, "Plano inválido." end
	if not Forca.elegivel(arvore) then return nil, "Árvore inelegível." end
	local primeira = plano.escolhida or plano.arvore
	if primeira == nil then
		if plano.modo ~= "semArvore" then return nil, "Escolha sua árvore inicial no painel da run antes de treinar." end
		if type(plano.paExtra) ~= "number" or plano.paExtra ~= plano.paExtra or plano.paExtra < 0 or plano.paExtra == math.huge then
			return nil, "Plano com PA inválido."
		end
		local Criacao = require(Shared.Regras.RunCriacao)
		local escolha, motivo = Criacao.escolherArvore({ modo = "zero", oferta = { arvore } }, arvore)
		if not escolha then return nil, motivo end
		return { arvore = escolha.arvore, segunda = false }
	end
	if arvore == primeira or arvore == plano.segunda then return nil, "Você já conhece esta árvore." end
	if plano.segunda ~= nil then return nil, "Você já aprendeu uma segunda árvore nesta expedição." end
	return { arvore = arvore, segunda = true }
end

-- Fronteira pura e injetada: mesmo handler usado pelo remote no servidor.
Treinadores.INTERVALO = 0.4

function Treinadores.payloadValido(p)
	if type(p) ~= "table" or getmetatable(p) ~= nil then return false end
	if p.acao ~= "consultar" and p.acao ~= "comprar" and p.acao ~= "aceitar" then return false end
	if type(p.requestId) ~= "string" or #p.requestId < 1 or #p.requestId > 64 or not p.requestId:match("^[%w_-]+$") then return false end
	if type(p.npcId) ~= "string" or (p.npcId ~= "taverna" and not p.npcId:match("^vila%-[1-4]$")) then return false end
	if p.acao == "comprar" and (type(p.arvore) ~= "string" or #p.arvore < 1 or #p.arvore > 64) then return false end
	for k in p do
		if k ~= "acao" and k ~= "requestId" and k ~= "npcId" and not (k == "arvore" and p.acao == "comprar") then return false end
	end
	return true
end

-- deps: sessao(), autenticado(player), perto(player,sessao,npcId), emCombate(), ocupado(), relogio().
function Treinadores.criarHandler(deps)
	local Regras = Treinadores
	local estados = {}
	local function responder(p, ok, mensagem, oferta)
		return { requestId = p.requestId, ok = ok, mensagem = mensagem, oferta = oferta }
	end
	local function processar(player, p)
		if not deps.autenticado(player) or not Treinadores.payloadValido(p) then return nil end
		local s = deps.sessao()
		local id = player.UserId
		if not s or not s.run or s.run.fim or not s.run.jogadores[id] then return responder(p, false, "Sem run ativa para este jogador.") end
		local estado = estados[id]
		if not estado or estado.sessao ~= s then
			estado = { sessao = s, recibos = {}, quantidade = 0 }; estados[id] = estado
		end
		if estado.ocupado or s.ocupada or (deps.ocupado and deps.ocupado()) then return responder(p, false, "Aguarde a operação da run.") end
		local agora = (deps.relogio or os.clock)()
		if estado.ultimo and agora - estado.ultimo < Treinadores.INTERVALO then return responder(p, false, "Aguarde antes de tentar novamente.") end
		estado.ultimo = agora
		local assinatura = p.acao .. "/" .. p.npcId .. "/" .. (p.arvore or "")
		local anterior = estado.recibos[p.requestId]
		if anterior then
			if anterior.assinatura ~= assinatura then return responder(p, false, "requestId já usado com outro pedido.") end
			return anterior.resposta
		end
		-- Sucesso sobrevive à reconexão/reinício: recibo no mesmo save do PA e dos dias.
		local plano = s.planos[id]
		local treino = plano and ((plano.treino and plano.treino.requestId == p.requestId and plano.treino)
			or (plano.treinoSegunda and plano.treinoSegunda.requestId == p.requestId and plano.treinoSegunda))
		if treino then
			if p.acao ~= "comprar" or treino.npcId ~= p.npcId or treino.arvore ~= p.arvore then return responder(p, false, "requestId já usado com outro pedido.") end
			return responder(p, true, "Treino já concluído. Monte sua ficha com a árvore aprendida.")
		end
		if estado.quantidade >= 128 then return responder(p, false, "Limite de pedidos atingido. Reconecte para continuar.") end
		estado.ocupado = true
		local executou, resposta = pcall(function()
			local membro = s.run.jogadores[id]
			if not membro.presente or membro.caido or s.run.regiao ~= "vila" or s.evento or s.luta or next(s.votos) ~= nil
				or deps.emCombate(player) then return responder(p, false, "Treine na vila, vivo e fora de combate ou decisões pendentes.") end
			local npc
			for _, candidato in Regras.listar(s.treinadores) do if candidato.id == p.npcId then npc = candidato end end
			if not npc or not deps.perto(player, s, p.npcId) then return responder(p, false, "Aproxime-se até 10 studs de um treinador disponível.") end
			if p.acao == "aceitar" then
    local escolha, motivo = Regras.escolher(s.planos[id], npc.arvore)
    if not escolha then return responder(p, false, motivo) end
    if not deps.iniciarProvacao then return responder(p, false, "Provação indisponível.") end
    local ok, mensagem = deps.iniciarProvacao(player, s, npc)
    return responder(p, ok, mensagem)
   end
   if p.acao == "consultar" then
				local escolha, motivo = Regras.escolher(s.planos[id], npc.arvore)
				local plano = s.planos[id]
				return responder(p, true, motivo, { npcId = npc.id, arvore = npc.arvore, titulo = Regras.titulo(npc.arvore),
					custoPa = Regras.CUSTO_PA, dias = Regras.diasDeTreino(npc.arvore), paExtra = s.planos[id] and s.planos[id].paExtra or 0,
					podeComprar = escolha ~= nil,
     segunda = escolha ~= nil and escolha.segunda == true,
     fala = if escolha then (if escolha.segunda then (if npc.arvore == "agua" then "Já tem um caminho? A água também pode ser o seu segundo. Mostre-me." else "Já tem um caminho? Posso lhe mostrar outro, se passar na minha prova.")
      elseif npc.arvore == "agua" then "A água encontra um caminho. Mostre-me o seu." else "Passos leves. Traga meu sino sem chamar atenção.")
      elseif plano and (plano.escolhida == npc.arvore or plano.arvore == npc.arvore or plano.segunda == npc.arvore) then "Este caminho você já conhece. Pratique o que aprendeu."
      else "Você já conhece dois caminhos. Pratique o que aprendeu.",
     resumo = if npc.arvore == "agua" then "As Comportas: gire os canais e encha as três bacias em 90 s." else "O Sino do Ladino: pegue o sino e volte ao portão sem ser visto. C/Ctrl ou botão para agachar." })
			end
			-- Nada cede antes de treinar; a sessão repete as validações de regra e serializa o save.
			local ok, motivo = s:treinar(id, p.npcId, p.arvore, p.requestId)
			if ok and deps.transmitir then deps.transmitir() end
			return responder(p, ok, if ok then "Treino concluído. Monte sua ficha com a árvore aprendida." else motivo)
		end)
		estado.ocupado = false
		if not executou then return responder(p, false, "Falha ao processar o treino.") end
		estado.recibos[p.requestId] = { assinatura = assinatura, resposta = resposta }; estado.quantidade += 1
		return resposta
	end
	return processar, function(player) estados[player.UserId] = nil end
end

return Treinadores
