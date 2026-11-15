-- Orquestra UMA run em andamento (PLANO §12, R5b): estado, votação do grupo, avanço da história e save.
-- Sem Instances nem serviços do Roblox: tudo vem injetado (`deps`), então roda fora do Studio e o servidor
-- só liga o armazenamento real e os remotos. Servidor autoritativo: o cliente só pede e recebe `visao`.
--
-- deps = {
--   rng,                              -- NextInteger(lo, hi)
--   guardar = function(chave, dado),  -- grava o save (RunSave); pode lançar erro
--   carregar = function(chave) -> dado|nil,
--   ehExplorador = function(userId) -> bool,   -- tem Navegação e Liderança no rank Explorador
--   historia, objetivo,               -- padrão: HistoriaV1
--   prontos,                          -- PersonagensProntos, para o modo "pronto"
--   historiaDaSemente = function(semente) -> historia,  -- expedição gerada pela semente (iniciar sorteia antes;
--                                     retomar regenera por run.semente). Sem ela: HistoriaV1. `area` = dados da área.
--   eventos,                        -- catálogo de eventos de viagem (RunViagem); sem ele não há eventos.
--                                     Com `area` (expedição) nunca há evento de viagem, mesmo com catálogo.
-- }
-- Chaves no armazenamento: "run/<grupoId>" (o save) e "membro/<userId>" (ponteiro: grupoId da última run do jogador).
local Shared = game:GetService("ReplicatedStorage").Shared
local Run = require(Shared.Regras.Run)
local Votacao = require(Shared.Regras.RunVotacao)
local Historia = require(Shared.Regras.RunHistoria)
local Criacao = require(Shared.Regras.RunCriacao)
local Save = require(Shared.Regras.RunSave)
local Viagem = require(Shared.Regras.RunViagem)
local Relogio = require(Shared.Regras.RunRelogio)
local Caminho = require(Shared.Mundo.EventosCaminho)
local HistoriaV1 = require(Shared.Mundo.HistoriaV1)

local Defeitos = require(Shared.Regras.RunDefeitos)

local Treinadores = require(Shared.Regras.RunTreinadores)

local ativa
local Sessao = {}
Sessao.__index = Sessao

local function chaveDaRun(grupoId) return "run/" .. grupoId end
local function chaveDoMembro(userId) return "membro/" .. tostring(userId) end

-- Somente servidor usa este contexto para aplicar kit na criação J1.
function Sessao.contextoCriacao(userId)
 local s = ativa
 if not s or s.ocupada or not s.run or s.run.fim or not s.run.jogadores[userId] then return nil end
 return s.grupoId .. "-" .. tostring(s.run.semente)
end

function Sessao.new(deps)
	assert(type(deps) == "table" and deps.rng ~= nil and type(deps.guardar) == "function", "deps inválidas")
	return setmetatable({
		deps = deps,
		historia = deps.historia or HistoriaV1.HISTORIA,
		objetivo = deps.objetivo or HistoriaV1.OBJETIVO,
		run = nil, planos = {}, grupoId = nil, votos = {}, evento = nil, luta = nil, contaRegistrada = false, viagem = nil,
	}, Sessao)
end

function Sessao:_salvar()
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	local dado, motivo = Save.serializar(self.run, self.planos, { eventoPendente = self.evento and self.evento.id or nil, contaRegistrada = self.contaRegistrada,
		lutaPendente = self.luta,
		treinadoresVila = self.treinadores and table.concat(self.treinadores.vila, ",") or nil,
		treinadorTaverna = self.treinadores and self.treinadores.taverna or nil,
		viagemOrigem = self.viagem and self.viagem.origem or nil, viagemDestino = self.viagem and self.viagem.destino or nil })
	if not dado then return false, motivo end
	self.ocupada = true
	local ok, erro = pcall(self.deps.guardar, chaveDaRun(self.grupoId), dado)
	self.ocupada = false
	if not ok then return false, "Falha ao salvar: " .. tostring(erro) end
	return true
end

-- jogadores = { { userId, nome? }... }; modos = { [userId] = "zero"|"semArvore"|"pronto" } (padrão "zero").
function Sessao:iniciar(grupoId, jogadores, modos, liberadas)
	if self.run then return false, "Já existe uma run." end
	if type(grupoId) ~= "string" or grupoId == "" or type(jogadores) ~= "table" then return false, "Pedido inválido." end
	local ids = {}
	for _, j in jogadores do table.insert(ids, j.userId) end
	local semente = self.deps.rng:NextInteger(0, 2 ^ 30)
	local historia = if self.deps.historiaDaSemente then self.deps.historiaDaSemente(semente) else self.historia
	local run, motivo = Run.nova({
		semente = semente, jogadores = ids, objetivo = self.objetivo,
		regiao = historia.nos[historia.inicio].regiao or "vila", galho = historia.inicio,
	})
	if not run then return false, motivo end
	local planos = {}
	for _, id in ids do
		local modo = modos and modos[id] or "zero"
		local plano, erro = Criacao.planejar(modo, self.deps.rng, self.deps.prontos)
		if not plano then return false, erro end
		planos[id] = plano
	end
	local treinadores, falha = Treinadores.sortear(self.deps.rng, { liberadas = liberadas })
	if not treinadores then return false, falha end
	self.treinadores = treinadores
	local historiaAnterior = self.historia
	self.historia = historia
	self.run, self.planos, self.grupoId, self.votos = run, planos, grupoId, {}
	local ok, erro = self:_salvar()
	if not ok then self.run, self.planos, self.grupoId, self.historia = nil, {}, nil, historiaAnterior; return false, erro end
	ativa = self
	return true
end

-- Ponteiro por membro para a run (qualquer membro retoma, não só quem iniciou). O servidor chama depois de
-- iniciar; retomarDeMembros regrava. Melhor esforço: falha não desfaz nada.
function Sessao:gravarPonteiros()
	if not self.run or not self.grupoId then return end
	self.ocupada = true
	for id in self.run.jogadores do pcall(self.deps.guardar, chaveDoMembro(id), self.grupoId) end
	self.ocupada = false
end

function Sessao:_limpar()
	self.run, self.planos, self.grupoId, self.votos, self.evento, self.luta, self.viagem = nil, {}, nil, {}, nil, nil, nil
	self.lutaErro, self.contaRegistrada, self.treinadores = nil, false, nil
	if ativa == self then ativa = nil end
end

-- Retoma a run de algum dos jogadores (servidor reiniciou ou o grupo voltou): para cada userId, na ordem dada,
-- tenta o ponteiro "membro/<id>" e depois `grupoPadrao(id)` (saves anteriores ao ponteiro). Prefere a primeira
-- run em andamento; sem nenhuma, a primeira encerrada. Devolve (ok, grupoId|motivo, avisos) — avisos lista os
-- saves ignorados por incompatibilidade (para o servidor registrar).
function Sessao:retomarDeMembros(userIds, grupoPadrao)
	if self.run then return false, "Já existe uma run.", {} end
	local candidatos, vistos, avisos = {}, {}, {}
	local function incluir(g)
		if type(g) == "string" and g ~= "" and #g <= 64 and not vistos[g] then vistos[g] = true; table.insert(candidatos, g) end
	end
	for _, id in userIds or {} do
		local ok, g = pcall(self.deps.carregar, chaveDoMembro(id))
		if ok then incluir(g) end
		if grupoPadrao then incluir(grupoPadrao(id)) end
	end
	local encerrada
	for _, g in candidatos do
		local ok, _, detalhe = self:retomar(g)
		if detalhe then table.insert(avisos, g .. ": " .. detalhe) end
		if ok then
			if not self.run.fim then self:gravarPonteiros(); return true, g, avisos end
			encerrada = encerrada or g
			self:_limpar()
		end
	end
	if encerrada and self:retomar(encerrada) then return true, encerrada, avisos end
	return false, "Nenhuma run salva.", avisos
end

-- Retoma uma run salva (servidor reiniciou ou o grupo voltou). Votos em aberto não são salvos: recomeçam.
-- Com história gerada (`historiaDaSemente`), save que não cabe nela (galho inexistente ou outro objetivo) conta
-- como "nenhuma run salva"; o terceiro retorno explica, para o servidor registrar.
function Sessao:retomar(grupoId)
	if self.run then return false, "Já existe uma run." end
	local ok, dado = pcall(self.deps.carregar, chaveDaRun(grupoId))
	if not ok then return false, "Falha ao carregar." end
	if dado == nil then return false, "Nenhuma run salva." end
	local run, planos, extras = Save.restaurar(dado)
	if not run then return false, planos end
	local historia = self.historia
	if self.deps.historiaDaSemente then
		historia = self.deps.historiaDaSemente(run.semente)
		if type(historia) ~= "table" or type(historia.nos) ~= "table" or not historia.nos[run.galho] then
			return false, "Nenhuma run salva.", "save incompatível: galho " .. tostring(run.galho) .. " não existe na história atual"
		end
		if run.objetivo.id ~= self.objetivo.id then
			return false, "Nenhuma run salva.", "save incompatível: objetivo " .. tostring(run.objetivo.id) .. " difere de " .. tostring(self.objetivo.id)
		end
	end
	self.historia = historia
	local treinadores
	if extras.treinadoresVila ~= nil then
		if type(extras.treinadoresVila) ~= "string" then return false, "Treinadores salvos inválidos." end
		treinadores = { vila = string.split(extras.treinadoresVila, ","), taverna = extras.treinadorTaverna }
		if not Treinadores.validarSorteio(treinadores) then return false, "Treinadores salvos inválidos." end
	else
		-- Save v1 anterior à F4: migração aditiva, determinística pela semente da run.
		local estado = if type(run.semente) == "number" and run.semente == run.semente and math.abs(run.semente) < 2 ^ 53 then math.floor(run.semente) % 2147483647 else 0
		local rng = { NextInteger = function(_, lo, hi)
			estado = (estado * 48271 + 1) % 2147483647
			return lo + estado % (hi - lo + 1)
		end }
		treinadores = Treinadores.sortear(rng, { liberadas = self.deps.treinadoresLiberados })
	end
	local function reciboDoTreinador(recibo)
		for i, arvore in treinadores.vila do
			if recibo.npcId == "vila-" .. i and recibo.arvore == arvore then return true end
		end
		return recibo.npcId == "taverna" and recibo.arvore == treinadores.taverna
	end
	local function reciboFormaValida(recibo)
		return type(recibo) == "table" and type(recibo.requestId) == "string" and #recibo.requestId >= 1 and #recibo.requestId <= 64
			and recibo.requestId:match("^[%w_-]+$") ~= nil and type(recibo.npcId) == "string"
	end
	for _, plano in planos do
		if plano.treino ~= nil then
			local recibo = plano.treino
			if not reciboFormaValida(recibo) or recibo.arvore ~= plano.escolhida or plano.modo ~= "semArvore"
				or type(plano.paExtra) ~= "number" or plano.paExtra ~= plano.paExtra or plano.paExtra < 0 or plano.paExtra == math.huge then
				return false, "Recibo de treino salvo inválido."
			end
			if not reciboDoTreinador(recibo) then return false, "Treinador do recibo salvo inválido." end
		end
		if plano.treinoSegunda ~= nil or plano.segunda ~= nil then
			local recibo = plano.treinoSegunda
			local primeira = plano.escolhida or plano.arvore
			if not reciboFormaValida(recibo) or type(plano.segunda) ~= "string" or recibo.arvore ~= plano.segunda
				or primeira == nil or primeira == plano.segunda then
				return false, "Recibo da segunda árvore salvo inválido."
			end
			if not reciboDoTreinador(recibo) then return false, "Treinador do recibo salvo inválido." end
		end
	end
	self.treinadores = treinadores
	local evento
	-- Expedição não tem evento de viagem: um evento salvo por versão antiga é descartado, sem travar a retomada.
	if extras.eventoPendente ~= nil and not self.deps.area then
		for _, e in self.deps.eventos or {} do
			if e.id == extras.eventoPendente then evento = e end
		end
		if not evento then return false, "Evento salvo desconhecido." end
	end
	-- Valida antes de assumir o estado: uma falha aqui não deixa a sessão meio retomada.
	if extras.lutaPendente ~= nil then
		local no = self.historia.nos[extras.lutaPendente]
		if not no or not no.luta then return false, "Luta salva desconhecida." end
	end
	self.run, self.planos, self.grupoId, self.votos, self.evento = run, planos, grupoId, {}, evento
	self.lutaErro = nil
	self.contaRegistrada = extras.contaRegistrada == true
	self.viagem = if evento and type(extras.viagemOrigem) == "string" and type(extras.viagemDestino) == "string"
		then { origem = extras.viagemOrigem, destino = extras.viagemDestino } else nil
	if self.deps.mundoAberto then self.viagem = nil end
	self.luta = extras.lutaPendente
	ativa = self
	return true
end

-- Explorador = rank Principiante de Navegação e Liderança (o livro chama assim o 1º rank da árvore): quem a
-- escolheu ou recebeu como ficha pronta, ou o que `deps.ehExplorador` informar (ex.: comprada com treinador).
local ARVORE_EXPLORADOR = "navegacao-e-lideranca"

function Sessao:ehExplorador(userId)
	local plano = self.planos[userId]
	if plano and (plano.escolhida == ARVORE_EXPLORADOR or plano.arvore == ARVORE_EXPLORADOR or plano.segunda == ARVORE_EXPLORADOR) then return true end
	return self.deps.ehExplorador ~= nil and self.deps.ehExplorador(userId) == true
end

function Sessao:_eleitores()
	local eleitores = {}
	for id, j in self.run.jogadores do
		eleitores[id] = { explorador = self:ehExplorador(id), presente = j.presente and not j.caido }
		-- Quem tem todas as opções do evento vetadas por defeito não trava a decisão do grupo.
		if self.evento and eleitores[id].presente then
			local algumaLiberada = false
			for _, o in self:_opcoes(id) do
				if o.liberada then algumaLiberada = true end
			end
			if not algumaLiberada then eleitores[id].presente = false end
		end
	end
	return eleitores
end

-- Nome de uma região da história (título do primeiro nó de vila/região que a ocupa).
function Sessao:_rotuloDaRegiao(regiao)
	for _, no in self.historia.nos do
		if no.regiao == regiao and (no.tipo == "vila" or no.tipo == "regiao") and no.titulo then return no.titulo end
	end
	return tostring(regiao)
end

function Sessao:_defeitosPorJogador()
	local mapa = {}
	for id, plano in self.planos do mapa[id] = plano.defeitos or {} end
	return mapa
end

-- Opções do momento (evento pendente ou história), com liberada/motivo; `userId` aplica os vetos por defeito.
function Sessao:_opcoes(userId)
	if self.luta then return {} end -- enquanto a luta do chefe não termina, não há escolha a votar
	if self.evento then
		local vetados = {}
		local lista = {}
		for _, o in self.evento.opcoes do
			vetados = {}
			for _, id in Viagem.vetadosNaOpcao(o, self:_defeitosPorJogador()) do vetados[id] = true end
			local vetada = userId ~= nil and vetados[userId] == true
   local paga = Viagem.podePagar(self.run, o)
			table.insert(lista, { id = o.id, texto = o.texto, dias = o.dias or 0, liberada = not vetada and paga,
				motivo = if vetada then "Seu defeito impede esta escolha." elseif not paga then "Caixa da viagem insuficiente." else nil })
		end
		return lista
	end
	local opcoes = self:_semOcultas(Historia.opcoes(self.historia, self.run))
	if not self.deps.mundoAberto then return self:_filtrarRetomadas(opcoes) end
 local locais = {}
 for _, o in opcoes do
  local destino = self.historia.nos[o.para]
  -- Deslocamento é físico. O Selo é recolhido no chefe e entregue ao voltar a pé.
  if (o.id == "pegar-o-selo" and not self.run.flags["selo-obtido"]) or (o.id ~= "pegar-o-selo" and destino and (destino.regiao == self.run.regiao) and destino.tipo ~= "vila") then
   table.insert(locais, o)
  end
 end
 return locais
end

-- Opção do nó atual como foi definida na história (com os campos extras do gerador: `ocultaCom`, `marcas`).
function Sessao:_opcaoDoNo(galho, opcaoId)
	local no = self.historia.nos[galho]
	for _, o in (no and no.opcoes) or {} do
		if o.id == opcaoId then return o end
	end
	return nil
end

-- Tira da lista as opções cuja flag `ocultaCom` já está marcada (ex.: entrar/retomar uma área concluída).
function Sessao:_semOcultas(opcoes)
	local lista = {}
	for _, o in opcoes do
		local def = self:_opcaoDoNo(self.run.galho, o.id)
		if not (def and def.ocultaCom and self.run.flags[def.ocultaCom]) then table.insert(lista, o) end
	end
	return lista
end

-- No hub só aparecem entrar e a retomada liberada mais funda (as outras retomadas ficam fora da lista).
function Sessao:_filtrarRetomadas(opcoes)
	local no = self.historia.nos[self.run.galho]
	if not no or no.tipo ~= "hub" then return opcoes end
	local melhor, passoMelhor = nil, -1
	for _, o in opcoes do
		local destino = self.historia.nos[o.para]
		if string.sub(o.id, 1, 8) == "retomar-" and o.liberada and destino and (destino.passo or 0) > passoMelhor then
			melhor, passoMelhor = o, destino.passo or 0
		end
	end
	local lista = {}
	for _, o in opcoes do
		if string.sub(o.id, 1, 8) ~= "retomar-" or o == melhor then table.insert(lista, o) end
	end
	return lista
end

function Sessao:_opcoesLiberadas()
	local ids = {}
	for _, o in self:_opcoes(nil) do
		if o.liberada then table.insert(ids, o.id) end
	end
	return ids
end

-- Árvore escolhida na criação (modo "zero"); só vale uma vez por jogador e só antes do primeiro avanço.
function Sessao:escolherArvore(userId, arvoreId)
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	if not self.run or Run.encerrada(self.run) then return false, "Sem run ativa." end
	local plano = self.planos[userId]
	if not plano then return false, "Jogador fora da run." end
	if plano.escolhida then return false, "Árvore já escolhida." end
	-- A criação do personagem usa esta escolha: depois que a expedição parte ela não muda mais.
	if (not self.deps.mundoAberto and self.run.dia > 0) or self.run.galho ~= self.historia.inicio then return false, "A árvore só pode ser escolhida antes de partir." end
	local escolha, motivo = Criacao.escolherArvore(plano, arvoreId)
	if not escolha then return false, motivo end
	return self:_concederArvore(userId, escolha.arvore)
end

-- Oferta e treinador fixam a mesma árvore autoritativa que RestricaoDeCriacao consulta.
function Sessao:_concederArvore(userId, arvore, novaRun, recibo, segunda)
	local anterior, runAnterior = self.planos[userId], self.run
	local novo = table.clone(anterior)
	if segunda then
		novo.segunda = arvore
		if recibo then novo.treinoSegunda = recibo end
	else
		novo.escolhida = arvore
		if recibo then novo.treino = recibo end
	end
	self.planos[userId], self.run = novo, novaRun or self.run
	local ok, erro = self:_salvar()
	if not ok then self.planos[userId], self.run = anterior, runAnterior end
	return ok, erro
end

function Sessao:treinar(userId, npcId, arvore, requestId)
	if type(requestId) ~= "string" or #requestId < 1 or #requestId > 64 or not requestId:match("^[%w_-]+$") then return false, "requestId inválido." end
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	if not self.run or self.run.fim then return false, "Sem run ativa." end
	local plano = self.planos[userId]
	local recibo = plano and ((plano.treino and plano.treino.requestId == requestId and plano.treino)
		or (plano.treinoSegunda and plano.treinoSegunda.requestId == requestId and plano.treinoSegunda))
	if recibo then
		if recibo.npcId ~= npcId or recibo.arvore ~= arvore then return false, "requestId já usado com outro pedido." end
		return true, "Treino já concluído."
	end
	local membro = self.run.jogadores[userId]
	if not membro or not membro.presente or membro.caido then return false, "Jogador indisponível na run." end
	if self.run.regiao ~= "vila" or self.evento or self.luta then return false, "Volte à vila e conclua as decisões antes de treinar." end
	-- Treinar gasta dias, o que mudaria a escolha já votada: com voto em aberto, recusa com motivo claro
	-- (o próprio voto sai com "retirarVoto"; o de outro jogador, pedindo a ele ou esperando a decisão).
	if self.votos[userId] ~= nil then return false, "Retire seu voto antes de treinar." end
	if next(self.votos) ~= nil then return false, "Há votos em aberto no grupo: decidam o caminho ou retirem os votos antes de treinar." end
	local encontrado = false
	for _, npc in Treinadores.listar(self.treinadores) do
		if npc.id == npcId and npc.arvore == arvore then encontrado = true end
	end
	if not encontrado then return false, "Árvore diferente da ensinada pelo treinador." end
	local P = require(game:GetService("ReplicatedStorage").Shared.Regras.Provacoes)
 if not P.aprovado(self.provacoes and self.provacoes[npcId], userId) then return false, "Conclua a provação deste treinador." end
 local escolha, motivo = Treinadores.escolher(plano, arvore)
	if not escolha then return false, motivo end
	local nova, _, erro
 if self.deps.mundoAberto then nova, erro = Relogio.descansar(self.run, "treino") else nova, _, erro = Run.gastarDias(self.run, Treinadores.diasDeTreino(arvore)) end
	if not nova then return false, erro end
	local ok, erroSave = self:_concederArvore(userId, escolha.arvore, nova, { requestId = requestId, npcId = npcId, arvore = arvore }, escolha.segunda)
 if ok then P.liberar(self.provacoes[npcId]) end
 return ok, erroSave
end

-- Registra o voto; quando todos que podem votar votaram, resolve e avança. Devolve (ok, resultado|motivo).
-- resultado = { aguardando = {userId...} } ou { avancou = true, opcao, dado?, expirou, run }.
function Sessao:votar(userId, opcaoId)
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	if not self.run or Run.encerrada(self.run) then return false, "Sem run ativa." end
	local membro = self.run.jogadores[userId]
	if not membro or not membro.presente or membro.caido then return false, "Você não pode votar agora." end
	if self.luta then return false, "Há uma luta pendente." end
	local valida = false
	for _, o in self:_opcoes(userId) do
		if o.id == opcaoId and o.liberada then valida = true end
	end
	if not valida then return false, "Opção indisponível." end
	self.votos[userId] = opcaoId
	return self:_fechar()
end

-- Desfaz o voto do jogador enquanto o grupo ainda não decidiu (votos não são salvos: nada a gravar).
function Sessao:retirarVoto(userId)
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	if not self.run or Run.encerrada(self.run) then return false, "Sem run ativa." end
	if self.votos[userId] == nil then return false, "Você não tem voto para retirar." end
	self.votos[userId] = nil
	return true
end

-- Maior bônus entre presentes aptos à opção (independe de quem votou nela).
-- Empate entre executores usa o mesmo RNG; ausentes/caídos/vetados ficam fora.
function Sessao:_resolverEvento(opcao)
 if not opcao.teste then return Viagem.resolverTeste(opcao) end
 local candidatos, maior = {}, -math.huge
 local vetados = {}
 for _, id in Viagem.vetadosNaOpcao(opcao, self:_defeitosPorJogador()) do vetados[id] = true end
 for id, j in self.run.jogadores do
  if j.presente and not j.caido and not vetados[id] then
   local ficha = self.deps.fichaDe and self.deps.fichaDe(id)
   local bonus = Viagem.bonusDaFicha(ficha, opcao.teste.pericia)
   if type(bonus) == "number" and bonus == bonus and math.abs(bonus) < math.huge then
    if bonus > maior then maior, candidatos = bonus, {} end
    if bonus == maior then table.insert(candidatos, id) end
   end
  end
 end
 if #candidatos == 0 then return nil, "Nenhum participante apto tem ficha para este teste." end
 table.sort(candidatos, function(a, b) return tostring(a) < tostring(b) end)
 local id = candidatos[if #candidatos == 1 then 1 else self.deps.rng:NextInteger(1, #candidatos)]
 local efeitos, erro = Defeitos.efeitos(self.planos[id] and self.planos[id].defeitos or {})
 if not efeitos then return nil, erro end
 local r, motivo = Viagem.resolverTeste(opcao, self.deps.rng, maior, efeitos.desvantagemEm[opcao.teste.pericia])
 if r then r.userId = id end
 return r, motivo
end

-- Se todos que podem votar já votaram, resolve (empate no dado) e avança a história; senão diz quem falta.
function Sessao:_fechar()
	if self.luta then return true, { aguardando = {} } end
	local liberadas = self:_opcoesLiberadas()
	local eleitores = self:_eleitores()
	local pendentes = Votacao.pendentes(liberadas, self.votos, eleitores)
	if #pendentes > 0 then return true, { aguardando = pendentes } end
	local resultado, motivo
 if self.resolucaoEvento then
  resultado = { vencedora = self.resolucaoEvento.opcao, dado = self.resolucaoEvento.dadoVotacao }
 else
  resultado, motivo = Votacao.resolver(liberadas, self.votos, eleitores, function(lados)
		return self.deps.rng:NextInteger(1, lados)
	end)
 end
	if not resultado then return false, motivo end
	local anterior, eventoAnterior, votosAnteriores = self.run, self.evento, self.votos
	local nova, expirou, erro
	if eventoAnterior then
		local resolucao = self.resolucaoEvento
  if resolucao then
   resultado.vencedora = resolucao.opcao
  else
   local opcao
   for _, o in eventoAnterior.opcoes do if o.id == resultado.vencedora then opcao = o end end
   resolucao, erro = self:_resolverEvento(opcao)
   if not resolucao then return false, erro end
   resolucao.opcao, resolucao.dadoVotacao = resultado.vencedora, resultado.dado
   self.resolucaoEvento = resolucao -- não rerrola se a gravação falhar
  end
  nova, expirou, erro = Viagem.aplicarOpcao(anterior, eventoAnterior, resultado.vencedora, resolucao)
	else
		if self.deps.mundoAberto and resultado.vencedora == "pegar-o-selo" then
   nova = Run.definirFlag(anterior, "selo-obtido")
   expirou = false
  else
   nova, expirou, erro = Historia.avancar(self.historia, anterior, resultado.vencedora)
   -- Flags extras da opção (gerador da expedição): RunHistoria só aplica a `marca` única.
   local def = nova and self:_opcaoDoNo(anterior.galho, resultado.vencedora)
   for _, flag in (def and def.marcas) or {} do
    nova, erro = Run.definirFlag(nova, flag)
    if not nova then break end
   end
  end
	end
	if not nova then return false, erro end
	self.run, self.evento, self.votos = nova, nil, {}
	-- Mudou de região (e a run segue): a viagem traz um evento para o grupo decidir.
	local lutaAnterior, lutaErroAnterior = self.luta, self.lutaErro
	local no = self.historia.nos[nova.galho]
	if not eventoAnterior and not Run.encerrada(nova) and no and no.luta
		and not nova.flags["vencido/" .. nova.galho] then self.luta, self.lutaErro = nova.galho, nil end
	-- Expedição (`area`) não sorteia evento de viagem: voltar à cidade ou retomar não traz evento antigo.
	if not self.deps.mundoAberto and not self.deps.area and not eventoAnterior and not self.luta and not Run.encerrada(nova) and nova.regiao ~= anterior.regiao then
		self.evento = self:_sortearEvento(nova.regiao)
	end
	local viagemAnterior = self.viagem
	if self.evento and nova.regiao ~= anterior.regiao then
		self.viagem = { origem = self:_rotuloDaRegiao(anterior.regiao), destino = self:_rotuloDaRegiao(nova.regiao) }
	elseif not self.evento then
		self.viagem = nil
	end
	local ok, falha = self:_salvar()
	if not ok then
		self.run, self.evento, self.luta, self.viagem, self.votos = anterior, eventoAnterior, lutaAnterior, viagemAnterior, votosAnteriores
		self.lutaErro = lutaErroAnterior
		return false, falha
	end
 self.resolucaoEvento = nil
	return true, { avancou = true, opcao = resultado.vencedora, dado = resultado.dado, expirou = expirou, run = nova,
		evento = self.evento and self.evento.id or nil, luta = self.luta, ultimoEvento = nova.ultimoEvento }
end

function Sessao:_sortearEvento(regiao)
	if type(self.deps.eventos) ~= "table" then return nil end
	local explorador = false
	for id, j in self.run.jogadores do
		if j.presente and self:ehExplorador(id) then explorador = true end
	end
	local ids = Viagem.sortearEventos(self.deps.eventos, regiao, 1, self.deps.rng, { modo = "pe", explorador = explorador })
	if not ids or ids[1] == nil then return nil end
	for _, e in self.deps.eventos do
		if e.id == ids[1] then return e end
	end
	return nil
end

-- Luta do chefe à espera do servidor: { no, titulo, criaturas, areaId } ou nil.
function Sessao:lutaPendente()
	if not self.luta or not self.run or Run.encerrada(self.run) then return nil end
	local no = self.historia.nos[self.luta]
	return { no = self.luta, titulo = no.titulo, criaturas = no.luta.criaturas, areaId = no.luta.areaId }
end

-- O servidor informa o desfecho do encontro J2 do chefe: "victory" libera a história (flag `vencido/<no>`),
-- "defeat" derruba todo o grupo presente (a run termina), "fled" mantém a luta pendente para nova tentativa.
function Sessao:lutaTerminou(resultado)
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	if not self.luta then return false, "Não há luta pendente." end
	local anterior, lutaAnterior = self.run, self.luta
	if resultado == "victory" then
		local nova = Run.definirFlag(self.run, "vencido/" .. self.luta)
		self.run, self.luta = nova, nil
	elseif resultado == "defeat" and self.historia.nos[self.luta].area and self.deps.area then
		-- Derrota em expedição não encerra a campanha: o grupo volta à cidade pagando o mesmo que "voltar-a-cidade".
		local no = self.historia.nos[self.luta]
		local movida, erro = self:_voltarAoHub(math.max(1, no.passo * self.deps.area.custos.voltarPorPasso))
		if not movida then return false, erro end
		self.run, self.luta = movida, nil
	elseif resultado == "defeat" then
		local nova = self.run
		for id, j in nova.jogadores do
			if j.presente and not j.caido then nova = Run.marcarCaido(nova, id, true) end
		end
		self.run, self.luta = Run.encerrarPorQueda(nova), nil
	elseif resultado == "fled" then
		return true
	else
		return false, "Resultado de luta inválido."
	end
	self.votos = {}
	local erroAnterior = self.lutaErro
	self.lutaErro = nil
	local ok, falha = self:_salvar()
	if not ok then self.run, self.luta, self.lutaErro = anterior, lutaAnterior, erroAnterior; return false, falha end
	return true
end

-- Run movida para o hub da expedição (início da história) depois de gastar `dias`. Devolve (run) ou (nil, motivo).
function Sessao:_voltarAoHub(dias)
	local gasta, _, erro = Run.gastarDias(self.run, dias)
	if not gasta then return nil, erro end
	local hub = self.historia.nos[self.historia.inicio]
	return Run.moverPara(gasta, hub and hub.regiao or "vila", self.historia.inicio)
end

-- Motivo de a luta pendente não ter começado (o servidor informa; nil limpa). Some da visão quando a luta acaba.
function Sessao:definirErroDaLuta(motivo)
	self.lutaErro = if self.luta and type(motivo) == "string" then motivo else nil
end

-- Desiste da luta pendente da expedição (ex.: a mesa não pôde montá-la): volta à cidade pagando
-- max(1, (passo - 1) * voltarPorPasso) dias — o passo atual ainda não foi vencido. Recusa com encontro em curso.
function Sessao:abandonarLuta(userId, encontroAtivo)
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	if not self.run or Run.encerrada(self.run) then return false, "Sem run ativa." end
	local membro = self.run.jogadores[userId]
	if not membro or not membro.presente then return false, "Você não está nesta run." end
	if not self.luta then return false, "Não há luta pendente." end
	if encontroAtivo then return false, "A luta já começou." end
	local no, area = self.historia.nos[self.luta], self.deps.area
	if not (no and no.area and area) then return false, "Esta luta não pode ser abandonada." end
	local anterior, lutaAnterior, erroAnterior, votosAnteriores = self.run, self.luta, self.lutaErro, self.votos
	local movida, erro = self:_voltarAoHub(math.max(1, ((no.passo or 1) - 1) * area.custos.voltarPorPasso))
	if not movida then return false, erro end
	self.run, self.luta, self.lutaErro, self.votos = movida, nil, nil, {}
	local ok, falha = self:_salvar()
	if not ok then
		self.run, self.luta, self.lutaErro, self.votos = anterior, lutaAnterior, erroAnterior, votosAnteriores
		return false, falha
	end
	return true
end

-- Ouro da área concluída já entregue (e avisado) a este membro? Persistido em flag da run: um servidor
-- reiniciado não reenvia o aviso.
local function flagAreaPaga(areaId, userId) return "expedicao/" .. areaId .. "/paga/" .. tostring(userId) end

function Sessao:areaPaga(areaId, userId)
	return self.run ~= nil and self.run.flags[flagAreaPaga(areaId, userId)] == true
end

function Sessao:marcarAreaPaga(areaId, userId)
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	if not self.run or not self.run.jogadores[userId] then return false, "Jogador fora da run." end
	if self:areaPaga(areaId, userId) then return true end
	local anterior = self.run
	self.run = Run.definirFlag(anterior, flagAreaPaga(areaId, userId))
	local ok, falha = self:_salvar()
	if not ok then self.run = anterior end
	return ok, falha
end

-- Resumo da run para a conta (RunConta.registrarRun); nil enquanto a run não terminou.
function Sessao:resumo(userId)
	if not self.run or not self.run.fim then return nil end
	return {
		status = if self.run.fim.motivo == "final" then "final" else "derrota",
		objetivoCumprido = self.run.objetivo.status == "cumprido",
		regioesVisitadas = Run.regioesVisitadas(self.run),
		plano = self.planos[userId],
	}, self.run.fim.final
end

-- Marca (e salva) que a conta já recebeu o fim desta run, para um servidor reiniciado não pagar duas vezes.
function Sessao:marcarContaRegistrada()
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	if self.contaRegistrada then return true end
	self.contaRegistrada = true
	local ok, falha = self:_salvar()
	if not ok then self.contaRegistrada = false end
	return ok, falha
end

function Sessao:ausentar(userId)
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	local nova, motivo = Run.marcarAusente(self.run, userId)
	if not nova then return false, motivo end
	self.run = nova
	self.votos[userId] = nil
	local ok, falha = self:_salvar()
	if not ok then return false, falha end
	-- Quem falta pode ter sido o último que impedia o grupo de decidir.
	if next(self.votos) ~= nil and not Run.encerrada(self.run) then
		local fechou, resultado = self:_fechar()
		if fechou then return true, resultado end
	end
	return true
end

function Sessao:retornar(userId)
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	local nova, perdidos, motivo = Run.retornar(self.run, userId)
	if not nova then return false, motivo end
	self.run = nova
	local ok, falha = self:_salvar()
	if not ok then return false, falha end
	return true, perdidos
end

-- Queda de um jogador; se o grupo inteiro cair, a run termina em derrota.
function Sessao:cair(userId, caido)
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	local nova, motivo = Run.marcarCaido(self.run, userId, caido)
	if not nova then return false, motivo end
	self.run = Run.encerrarPorQueda(nova)
	self.votos[userId] = nil
	return self:_salvar()
end

-- Tick autoritativo não grava a cada frame; serviço faz checkpoint e salva saída/ações.
function Sessao:avancarTempo(segundos, combate)
 if self.ocupada or not self.run then return false end
 local presente = false
 for _, j in self.run.jogadores do if j.presente and not j.caido then presente = true end end
 self.relogioPausado = combate == true or not presente
 local nova = Relogio.avancar(self.run, segundos, self.relogioPausado)
 if not nova then return false end
 self.run = nova
 return true
end

function Sessao:podeDescansar(userId)
 if self.ocupada or not self.run or self.run.fim or self.evento or self.luta then return false, "Run indisponível." end
 local j = self.run.jogadores[userId]
 if not j or not j.presente or j.caido then return false, "Jogador indisponível." end
 return true
end

function Sessao:descansar(userId,tipo)
 local pode, motivo = self:podeDescansar(userId)
 if not pode then return false,motivo end
 local anterior = self.run
 local nova, erro = Relogio.descansar(anterior, tipo)
 if not nova then return false, erro end
 self.run = nova
 local ok, motivo = self:_salvar()
 if not ok then self.run = anterior end
 return ok, motivo
end

-- Descanso de acampamento (só com a sala/chefe vencido): gasta `area.custos.descanso` dias. Sem limite fixo
-- (decisão de 14/11); `area.descansosMax`, se houver, ainda limita por área na run. As flags contam os usados.
function Sessao:_descansosUsados(areaId)
	local prefixo = "descanso/" .. areaId .. "/"
	local usados = 0
	for flag in self.run.flags do
		if string.sub(flag, 1, #prefixo) == prefixo then usados += 1 end
	end
	return usados
end

-- "luta" (luta pendente) | "acampamento" (sala/chefe já vencido) | nil.
function Sessao:_fase()
	if not self.run then return nil end
	if self.luta then return "luta" end
	local no = self.historia.nos[self.run.galho]
	if no and (no.tipo == "sala" or no.tipo == "chefe") and self.run.flags["vencido/" .. self.run.galho] then return "acampamento" end
	return nil
end

-- Confere tudo do descanso do acampamento sem gastar nada (o servidor restaura as fichas antes de gastar o dia).
function Sessao:podeDescansarNoAcampamento(userId)
	local area = self.deps.area
	if self.ocupada then return false, "Aguarde o salvamento da run." end
	if not self.run or self.run.fim or not area then return false, "Run indisponível." end
	local j = self.run.jogadores[userId]
	if not j or not j.presente or j.caido then return false, "Jogador indisponível." end
	if self:_fase() ~= "acampamento" then return false, "Só é possível descansar no acampamento." end
	if area.descansosMax ~= nil and self:_descansosUsados(area.id) >= area.descansosMax then return false, "Sem descansos restantes nesta área." end
	return true
end

function Sessao:descansarNoAcampamento(userId)
	local pode, motivoPode = self:podeDescansarNoAcampamento(userId)
	if not pode then return false, motivoPode end
	local area = self.deps.area
	local usados = self:_descansosUsados(area.id)
	local anterior = self.run
	local nova, _, erro = Run.gastarDias(anterior, area.custos.descanso)
	if not nova then return false, erro end
	self.run = Run.definirFlag(nova, "descanso/" .. area.id .. "/" .. (usados + 1))
	local ok, motivo = self:_salvar()
	if not ok then self.run = anterior end
	return ok, motivo
end

-- Só recebe coordenadas do avatar lidas pelo servidor, nunca payload remoto.
function Sessao:presencaNoMundo(userId, x, z)
 if not self.deps.mundoAberto or self.ocupada or not self.run or self.run.fim or self.evento or self.luta then return false end
 local j = self.run.jogadores[userId]
 if not j or not j.presente or j.caido then return false end
 if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then return false end
 local anterior, eventoAnterior = self.run, self.evento
 local regiao = Caminho.regiao(x,z)
 local mudou = false
 if regiao and regiao ~= self.run.regiao then
  local galho = if regiao == "vila" and self.run.flags["selo-obtido"] then "retorno" else regiao
  if self.historia.nos[galho] then
   self.run = Run.moverPara(self.run, regiao, galho)
   self.votos = {}
   mudou = true
  end
 end
 local trecho = Caminho.trecho(x,z,self.run.flags)
 if trecho then
  self.run = Run.definirFlag(self.run,"caminho/"..trecho.id)
  self.evento = self:_sortearEvento(trecho.regiao)
  self.viagem = nil
  mudou = true
 end
 if not mudou then return false end
 local ok, erro = self:_salvar()
 if not ok then self.run, self.evento = anterior, eventoAnterior end
 return ok, erro
end

-- O que o cliente pode ver: nunca o RNG nem os votos dos outros (só quem ainda falta).
function Sessao:visao(userId)
	if not self.run then return nil end
	local r = self.run
	local pendentes = Votacao.pendentes(self:_opcoesLiberadas(), self.votos, self:_eleitores())
	local no = self.historia.nos[r.galho]
	local grupo = {}
	for id, j in r.jogadores do table.insert(grupo, { userId = id, presente = j.presente, caido = j.caido }) end
	-- Total de votos (com o peso do Explorador) por opção, sem expor quem votou em quê.
	local contagem = {}
	local eleitores = self:_eleitores()
	for _, o in self:_opcoesLiberadas() do contagem[o] = 0 end
	for id, opcao in self.votos do
		local peso = Votacao.peso(eleitores[id])
		if peso > 0 and contagem[opcao] ~= nil then contagem[opcao] += peso end
	end
	table.sort(grupo, function(a, b) return tostring(a.userId) < tostring(b.userId) end)
	return {
		passo = no and no.passo, totalPassos = no and no.total, area = no and no.area, fase = self:_fase(),
		descansos = if no and no.area and self.deps.area then { usados = self:_descansosUsados(no.area), max = self.deps.area.descansosMax } else nil,
		seloObtido = r.flags["selo-obtido"] == true,
  relogio = Relogio.visao(r, self.relogioPausado), mundoAberto = self.deps.mundoAberto == true,
		dia = r.dia, diasRestantes = Run.diasRestantes(r), objetivo = table.clone(r.objetivo),
		cacadaConcluida = r.cacadas ~= nil and next(r.cacadas.conclusoes or {}) ~= nil,
  ouroViagem = r.ouroViagem or 0, ultimoEvento = r.ultimoEvento,
		titulo = no and no.titulo, tipoDoNo = no and no.tipo, grupo = grupo,
		galho = r.galho, regiao = r.regiao, regiaoTitulo = self:_rotuloDaRegiao(r.regiao), opcoes = self:_opcoes(userId),
		evento = self.evento and { id = self.evento.id, titulo = self.evento.titulo } or nil,
		luta = self.luta and { titulo = no and no.titulo } or nil,
		lutaErro = if self.luta then self.lutaErro else nil, -- por que a luta pendente não começou (string) ou nil
		fim = r.fim and table.clone(r.fim) or nil, aguardando = pendentes, votei = self.votos[userId],
		plano = self.planos[userId], viagem = self.viagem and table.clone(self.viagem) or nil, contagem = contagem,
	}
end

return Sessao
