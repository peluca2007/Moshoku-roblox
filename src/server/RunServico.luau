-- Servidor da run (R5b/R5c): liga RunSessao (regras puras) ao armazenamento real, aos remotos e aos jogadores.
-- Por enquanto há UMA run por servidor, para todos os jogadores presentes (até 4); o servidor por grupo
-- com teleporte exige place publicado (PLANO §12). Servidor autoritativo: o cliente só envia intenção.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local Sessao = require(Shared.Regras.RunSessao)
local Criacao = require(Shared.Regras.RunCriacao)
local Conta = require(Shared.Regras.RunConta)
local Prontos = require(Shared.PersonagensProntos)
local RestricaoDeCriacao = require(Shared.Regras.RestricaoDeCriacao)
local Abertura = require(Shared.Regras.AberturaRun)
local EventosV1 = require(Shared.Mundo.ViagemEventosV1)
local VilaLayout = require(Shared.Mundo.VilaLayout)
local FlorestaLayout = require(Shared.Mundo.FlorestaLayout)
local RuinasLayout = require(Shared.Mundo.RuinasLayout)
local CatalogoAparencia = require(Shared.Aparencia.Catalogo)

local Servico = {}

Servico.REMOTE = "RunJogo"
local INTERVALO = 0.4

-- W1b: regiões conectadas a pé; nenhum destino/teleporte na navegação.
local Relogio = require(Shared.Regras.RunRelogio)
local Tempo = require(Shared.Mundo.RunTempo)

function Servico.payloadValido(pedido)
	if type(pedido) ~= "table" or getmetatable(pedido) ~= nil or type(pedido.acao) ~= "string" then return false end
	local permitidos = { acao = true }
	if pedido.acao == "consultar" then
	elseif pedido.acao == "iniciar" then
		permitidos.modo = true
		local ok = false
		for _, m in Criacao.MODOS do
			if pedido.modo == m then ok = true end
		end
		if pedido.modo ~= nil and not ok then return false end
	elseif pedido.acao == "lutar" then
		-- sem campos: reinicia a luta do chefe pendente
	elseif pedido.acao == "escolherArvore" then
		permitidos.arvore = true
		if type(pedido.arvore) ~= "string" or #pedido.arvore > 64 then return false end
	elseif pedido.acao == "votar" then
		permitidos.opcao = true
		if type(pedido.opcao) ~= "string" or #pedido.opcao > 64 then return false end
	else
		return false
	end
	for chave in pedido do
		if not permitidos[chave] then return false end
	end
	return true
end

-- Armazenamento: DataStore no jogo publicado; memória no Studio com place não publicado (como PersistenciaDeEstudio).
local function armazenamento()
	if require(script.Parent.PersistenciaDeEstudio).memoriaAtiva() then
		local dados = {}
		return function(chave, dado) dados[chave] = dado end, function(chave) return dados[chave] end
	end
	local store = DataStoreService:GetDataStore("RunsSalvas")
	return function(chave, dado) store:SetAsync(chave, dado) end, function(chave) return store:GetAsync(chave) end
end

-- deps = { emEncontro = function() -> bool, ehExplorador = function(userId) -> bool (opcional),
--          conta = ContaServico (opcional; sem ela o fim da run não paga a conta),
--          iniciarLuta = function(jogadores, luta) -> encounterId | nil, erro   (luta = { no, criaturas, areaId }; monta o encontro J2 do chefe) }
function Servico.start(deps)
	deps = deps or {}
	local remote = Instance.new("RemoteEvent")
	remote.Name = Servico.REMOTE
	remote.Parent = ReplicatedStorage
	local guardar, carregar = armazenamento()
	local sessao
	local observadores, processando = {}, false
	local ultimo = {}
	local lutaAtiva -- encounterId do encontro J2 da luta pendente (nil = ainda não começou)
	local function novaSessao()
		return Sessao.new({
			rng = Random.new(), guardar = guardar, carregar = carregar, mundoAberto = true,
			ehExplorador = deps.ehExplorador, prontos = Prontos, eventos = EventosV1,
   fichaDe = function(userId)
    local player = Players:GetPlayerByUserId(userId)
    return player and deps.corpoPessoal and deps.corpoPessoal(player) or nil
   end,
		})
	end
	local function enviar(player, dado) remote:FireClient(player, "run", dado) end
	local function nomeDe(userId)
		local p = Players:GetPlayerByUserId(userId)
		return p and p.DisplayName or tostring(userId)
	end
	local function visaoPara(player)
		local v = sessao and sessao:visao(player.UserId)
		if not v then return { semRun = true } end
		for _, m in v.grupo do m.nome = nomeDe(m.userId) end
		return v
	end
	local function transmitir()
		for _, fn in observadores do fn(sessao) end
		for _, p in Players:GetPlayers() do enviar(p, visaoPara(p)) end
	end
	local function recusa(player, motivo) enviar(player, { erro = motivo }) end
	-- Fim da run (final ou queda): paga a conta de cada jogador UMA vez (marca antes de pagar: um servidor
	-- reiniciado nunca paga duas vezes; se o pagamento falhar, fica o aviso no log).
	local function fecharConta()
		if not (deps.conta and sessao and sessao.run and sessao.run.fim) or sessao.contaRegistrada then return end
		if not sessao:marcarContaRegistrada() then return end
		for userId in sessao.run.jogadores do
			local resumo, finalId = sessao:resumo(userId)
			local conta, ganhos = deps.conta.registrarRun(userId, resumo, finalId)
			local jogador = Players:GetPlayerByUserId(userId)
			if not conta then
				warn("[Run] Conta não paga para " .. tostring(userId) .. ": " .. tostring(ganhos))
			elseif jogador then
				remote:FireClient(jogador, "conta", { ganho = ganhos.moeda, total = conta.moeda, conquistas = ganhos.conquistas })
			end
		end
	end

	-- Luta do chefe pendente e ainda sem encontro: o servidor monta o J2 com quem está presente e vivo.
	local function iniciarLutaPendente(solicitante)
		local luta = sessao and sessao:lutaPendente()
		if not luta or lutaAtiva then return end
		local alvo = if sessao.run.regiao == "floresta-sombria" then FlorestaLayout.MARCO else RuinasLayout.CAMARA
		local function proximo(player)
			local membro = sessao.run.jogadores[player.UserId]
			local raiz = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			return membro and membro.presente and not membro.caido and raiz and hum and hum.Health > 0
				and Vector2.new(raiz.Position.X-alvo.x,raiz.Position.Z-alvo.z).Magnitude <= 42
		end
		if solicitante and not proximo(solicitante) then recusa(solicitante, "Aproxime-se do guardião."); return end
		if not deps.iniciarLuta then
			if solicitante then recusa(solicitante, "A luta do chefe ainda não está disponível neste servidor.") end
			return
		end
		local grupo = {}
		for userId, membro in sessao.run.jogadores do
			local jogador = Players:GetPlayerByUserId(userId)
			if jogador and proximo(jogador) then table.insert(grupo, jogador) end
		end
		table.sort(grupo, function(a, b) return a.UserId < b.UserId end)
		if #grupo == 0 then return end
		local id, motivo = deps.iniciarLuta(grupo, luta)
		if not id then
			if solicitante then recusa(solicitante, motivo or "Não foi possível começar a luta.") end
			return
		end
		lutaAtiva = id
	end

	-- Com a run ativa, o personagem pessoal só nasce com a árvore que a run deu (PersonagemSessao consulta isto).
	RestricaoDeCriacao.definir(function(player)
		local run = sessao and sessao.run
		local plano = run and not run.fim and sessao.planos[player.UserId]
		if sessao and sessao.ocupada then return nil, "Aguarde o salvamento da run." end
		if not plano then return nil end
		if plano.modo == "zero" then
			if plano.escolhida then return plano.escolhida end
			return nil, "Escolha sua árvore inicial no painel RUN antes de criar o personagem."
		elseif plano.modo == "pronto" then
			return plano.arvore
		end
		if plano.escolhida then return plano.escolhida end
		-- P2: sem árvore ainda; a ficha nasce sem ela e o mestre da vila ensina a primeira.
		return nil, nil, true
	end)

	local function processar(player, pedido)
		if not Servico.payloadValido(pedido) then return end
		local agora = os.clock()
		if ultimo[player.UserId] and agora - ultimo[player.UserId] < INTERVALO then return end
		ultimo[player.UserId] = agora
		if deps.emEncontro and deps.emEncontro() and pedido.acao ~= "consultar" then
			recusa(player, "Termine o encontro antes de mexer na run.")
			return
		end
		if pedido.acao == "consultar" then
			if not sessao then
				local tentativa = novaSessao()
				if tentativa:retomar("u" .. player.UserId) then sessao = tentativa; transmitir() end
			end
			enviar(player, visaoPara(player))
		elseif pedido.acao == "iniciar" then
			if sessao and sessao.run and not sessao.run.fim then recusa(player, "Já existe uma run em andamento."); return end
			local lista, modos = {}, {}
			for _, p in ipairs(Players:GetPlayers()) do
				if #lista < 4 then table.insert(lista, { userId = p.UserId, nome = p.DisplayName }); modos[p.UserId] = "semArvore" end
			end
			local liberadas
			if deps.conta then
				local conta, erro = deps.conta.obter(player.UserId)
				if not conta then recusa(player, erro or "Conta indisponível."); return end
				liberadas = Conta.treinadoresLiberados(conta)
				-- P2: até a primeira run acabar, o jogo escolhe o modo (sem árvore); depois o pedido vale.
				modos[player.UserId] = Abertura.modo(conta, pedido.modo)
			else
				modos[player.UserId] = pedido.modo or "semArvore"
			end
			if player.Parent ~= Players then return end
			local nova = novaSessao()
			local ok, motivo = nova:iniciar("u" .. player.UserId, lista, modos, liberadas)
			if not ok then recusa(player, motivo); return end
			sessao = nova
			transmitir()
			-- A expedição começa na entrada norte da vila, com o objetivo "Fale com um mestre".
			local nascimento = Abertura.nascimento()
			for userId in nova.run.jogadores do
				local jogador = Players:GetPlayerByUserId(userId)
				local personagem = jogador and jogador.Character
				if personagem then
					personagem:PivotTo(CFrame.lookAt(Vector3.new(nascimento.x, nascimento.y, nascimento.z), Vector3.new(nascimento.x, nascimento.y, nascimento.z - 10)))
				end
			end
		elseif not sessao then
			recusa(player, "Não há run em andamento.")
		elseif pedido.acao == "lutar" then
			iniciarLutaPendente(player)
			transmitir()
		elseif pedido.acao == "escolherArvore" then
			local ok, motivo = sessao:escolherArvore(player.UserId, pedido.arvore)
			if not ok then recusa(player, motivo); return end
			transmitir()
		elseif pedido.acao == "votar" then
   -- Ações narrativas só perto do marco do capítulo; eventos já foram ativados pela presença.
   if not sessao.evento then
    local raiz = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local regiao = sessao.run.regiao
    local alvo = if regiao == "floresta-sombria" then FlorestaLayout.MARCO elseif regiao == "ruinas-do-vale" then RuinasLayout.CAMARA else VilaLayout.PRACA
    if not raiz or (Vector2.new(raiz.Position.X-alvo.x,raiz.Position.Z-alvo.z)).Magnitude > 42 then
     recusa(player, "Aproxime-se do local do objetivo."); return
    end
   end
   local ok, resultado = sessao:votar(player.UserId, pedido.opcao)
   if not ok then recusa(player, resultado); return end
			transmitir()
			iniciarLutaPendente(player)
			fecharConta()
		end
	end
	remote.OnServerEvent:Connect(function(player, pedido)
		if processando or (sessao and sessao.ocupada) then recusa(player, "Aguarde a operação da run."); return end
		processando = true
		local ok, erro = pcall(processar, player, pedido)
		processando = false
		if not ok then warn("[Run] " .. tostring(erro)); recusa(player, "Falha ao processar a run.") end
	end)

	Players.PlayerRemoving:Connect(function(player)
		while processando or (sessao and sessao.ocupada) do task.wait() end
		ultimo[player.UserId] = nil
		if sessao and sessao.run and sessao.run.jogadores[player.UserId] and not sessao.run.fim then
			sessao:ausentar(player.UserId)
			transmitir()
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		while processando or (sessao and sessao.ocupada) do task.wait() end
		if sessao and sessao.run and sessao.run.jogadores[player.UserId] and not sessao.run.fim then
			sessao:retornar(player.UserId)
		end
		if sessao then enviar(player, visaoPara(player)) end
	end)

 local acumulado, checkpoint = 0, 0
 local function publicarRelogio()
  if not sessao or not sessao.run then return end
  local r = sessao.run
  local v = Relogio.visao(r, sessao.relogioPausado)
  ReplicatedStorage:SetAttribute("RunDia", v.dia)
  ReplicatedStorage:SetAttribute("RunFracaoDia", v.fracao)
  ReplicatedStorage:SetAttribute("RunHora", v.hora)
  ReplicatedStorage:SetAttribute("RunPeriodo", v.periodo)
  ReplicatedStorage:SetAttribute("RunRelogioPausado", v.pausado)
  ReplicatedStorage:SetAttribute("RunDiasRestantes", math.max(0,r.objetivo.prazoFinal-r.dia))
  ReplicatedStorage:SetAttribute("RunTempoDecorrido", r.dia * Tempo.DIA_SEGUNDOS)
 end
 RunService.Heartbeat:Connect(function(dt)
  if processando or not sessao or not sessao.run or sessao.ocupada or sessao.run.fim then return end
  local combate = deps.emEncontro and deps.emEncontro() == true
  sessao:avancarTempo(dt,combate)
  acumulado += dt
  checkpoint += dt
  if acumulado < 1 then return end
  acumulado = 0
  processando = true
  if not combate then
   for _, p in Players:GetPlayers() do
    local raiz = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if raiz then sessao:presencaNoMundo(p.UserId,raiz.Position.X,raiz.Position.Z) end
   end
  end
  publicarRelogio()
  if checkpoint >= 15 then sessao:_salvar(); checkpoint = 0 end
  transmitir()
  processando = false
 end)
 game:BindToClose(function()
  if sessao and sessao.run and not sessao.ocupada then sessao:_salvar() end
 end)

	return {
		-- Para testes/ferramentas: estado atual da sessão (nil sem run).
		sessao = function() return sessao end,
		transmitir = transmitir,
  podeDescansar = function(player)
   if not sessao or not sessao.run or sessao.run.fim then return true end
   if processando or not sessao or (deps.emEncontro and deps.emEncontro()) then return false, "Run indisponível." end
   return sessao:podeDescansar(player.UserId)
  end,
  -- Chamado pelo serviço de descanso após validar lugar, alcance, combate e cooldown.
  descansar = function(player,tipo)
   if not sessao or not sessao.run or sessao.run.fim then return true end
   if processando or not sessao or (deps.emEncontro and deps.emEncontro()) then return false, "Run indisponível." end
   processando = true
   local ok, erro = sessao:descansar(player.UserId,tipo)
   processando = false
   if ok then publicarRelogio(); transmitir() end
   return ok, erro
  end,
		ocupado = function() return processando or (sessao and sessao.ocupada) end,
		observar = function(fn) table.insert(observadores, fn); fn(sessao) end,
		-- Chamado quando QUALQUER encontro J2 termina; só interessa o da luta do chefe da run.
		encerrado = function(encontro, estado)
			if not sessao or not sessao.run or sessao.run.fim or type(estado) ~= "table" then return end
			if not lutaAtiva or estado.encounterId ~= lutaAtiva then
				-- Encontro comum (patrulha, marco) durante a run: derrota derruba quem lutou; o grupo todo caído encerra a run.
				if estado.phase == "defeat" and type(encontro) == "table" and type(encontro.atoresPorJogador) == "table" then
					for userId in encontro.atoresPorJogador do
						if sessao.run.jogadores[userId] then sessao:cair(userId, true) end
					end
					transmitir()
					fecharConta()
				end
				return
			end
			local fonteLoot = lutaAtiva
			lutaAtiva = nil
			local fase = estado.phase
			local resultado = if fase == "victory" then "victory" elseif fase == "defeat" then "defeat" else "fled"
			local ok, motivo = sessao:lutaTerminou(resultado)
			if not ok then warn("[Run] Desfecho da luta não aplicado: " .. tostring(motivo)) end
			if ok and fase == "victory" and deps.conta and deps.conta.registrarLootChefe then
				-- Só participantes da luta; observadores não recebem uma rolagem.
				local premiados = {}
				for userId, atorId in encontro.atoresPorJogador or {} do
					local ator = encontro.atoresPorId and encontro.atoresPorId[atorId]
					if not (ator and ator.fled) then table.insert(premiados, userId) end
				end
				-- Persistência não segura o processamento do encontro nem lê a sessão após I/O.
				task.defer(function()
					for _, userId in premiados do
						local conta, peca = deps.conta.registrarLootChefe(userId, fonteLoot, Random.new())
						if not conta then warn("[Aparencia] Falha ao persistir loot do chefe: " .. tostring(peca)) end
						local jogador = Players:GetPlayerByUserId(userId)
						if conta and peca and jogador then
							local item = CatalogoAparencia.PECAS[peca]
							remote:FireClient(jogador, "lootRaro", { peca = peca, nome = item.nome, raridade = item.raridade })
						end
					end
				end)
			end
			transmitir()
			fecharConta()
		end,
	}
end

return Servico
