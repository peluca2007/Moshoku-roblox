-- Estado da mesa no cliente: último snapshot do servidor, seleção local e avisos.
-- BoardView e MesaPanel leem daqui; nenhum dos dois decide regras.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MesaProtocol"))
local UploadPartes = require(ReplicatedStorage.Shared:WaitForChild("UploadPartes"))

local MesaState = {}

local remote: RemoteEvent
local snapshot = nil
local selectedToken: string? = nil
local selectedX: number?, selectedZ: number? = nil, nil
local tableView = false
local brush: string? = nil
local logHistory = {}

local listeners = {
	snapshot = {},
	log = {},
	selection = {},
	tableView = {},
	brush = {},
	roll = {},
	fichaUpload = {},
	personagemPessoal = {},
	loja = {},
	missoes = {},
	fichaDetalhe = {},
	efeito = {},
	encontro = {},
	mira = {},
}
-- Mira de habilidade (A1): { tokenId, habilidadeId, tipo, alcanceCasas?, raioCasas? } ou nil.
local mira = nil
-- Fichas v2 completas recebidas sob demanda: id -> { version, ficha2 }.
local detalhes: { [string]: { version: string, ficha2: any } } = {}
local pedidosDeDetalhe: { [string]: { version: string, stamp: number } } = {}

local function emit(kind: string, ...)
	for _, callback in listeners[kind] do
		task.spawn(callback, ...)
	end
end

function MesaState.start()
	-- Os specs do Studio terminam antes do serviço criar o remoto. O atributo
	-- também atende clientes que entram depois que o servidor já ficou pronto.
	local readinessChanged = ReplicatedStorage:GetAttributeChangedSignal(Protocol.READY_ATTRIBUTE)
	while ReplicatedStorage:GetAttribute(Protocol.READY_ATTRIBUTE) ~= true do
		readinessChanged:Wait()
	end
	remote = ReplicatedStorage:WaitForChild(Protocol.REMOTE) :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind, data)
		if kind == "snapshot" then
			local mudouPapel = snapshot and snapshot.you.master ~= data.you.master
			snapshot = data
			if mudouPapel then table.clear(pedidosDeDetalhe) end
			for id, detalhe in detalhes do
				local token = MesaState.findToken(id)
				if mudouPapel or not token or token.ficha2Versao ~= detalhe.version then
					detalhes[id] = nil
					pedidosDeDetalhe[id] = nil
				end
			end
			if selectedToken and not MesaState.findToken(selectedToken) then
				selectedToken = nil
				emit("selection", nil, selectedX, selectedZ)
			end
			emit("snapshot", data)
		elseif kind == "roll" then
			emit("roll", data)
		elseif kind == "efeito" and type(data) == "table" then
			emit("efeito", data)
		elseif kind == "encontro" and type(data) == "table" then
			emit("encontro", data)
		elseif kind == "fichaUpload" and type(data) == "table" then
			emit("fichaUpload", data)
		elseif kind == "personagemPessoal" then
			emit("personagemPessoal", data)
		elseif kind == "loja" and type(data) == "table" then
			emit("loja", data)
		elseif kind == "missoes" and type(data) == "table" then
			emit("missoes", data)
		elseif kind == "fichaDetalhe" and type(data) == "table" and type(data.id) == "string" then
			local token = MesaState.findToken(data.id)
			if not token or not token.ficha2Versao or token.ficha2Versao ~= data.version then return end
			detalhes[data.id] = { version = data.version, ficha2 = data.ficha2 }
			pedidosDeDetalhe[data.id] = nil
			emit("fichaDetalhe", data.id, data.ficha2)
		elseif kind == "log" then
			table.insert(logHistory, data)
			if #logHistory > Protocol.LIMITS.log then
				table.remove(logHistory, 1)
			end
			emit("log", data)
		end
	end)
end

-- Chamado depois que as telas se registraram, para não perder o primeiro snapshot.
function MesaState.ready()
	MesaState.send("requestSnapshot")
end

function MesaState.send(command: string, payload: { [string]: any }?)
	remote:FireServer(command, payload)
end

function MesaState.snapshot()
	return snapshot
end

function MesaState.localUserId(): number
	return Players.LocalPlayer.UserId
end

function MesaState.isMaster(): boolean
	return snapshot ~= nil and snapshot.you.master == true
end

function MesaState.findToken(id: string?)
	if not snapshot or not id then
		return nil
	end
	for _, token in snapshot.tokens do
		if token.id == id then
			return token
		end
	end
	return nil
end

function MesaState.tokenAt(x: number, z: number)
	if not snapshot then
		return nil
	end
	for _, token in snapshot.tokens do
		if token.x == x and token.z == z then
			return token
		end
	end
	return nil
end

function MesaState.canControl(token): boolean
	return MesaState.isMaster() or token.ownerUserId == MesaState.localUserId()
end

-- Seleção: uma ficha OU uma casa vazia (usada para criar fichas).
function MesaState.selectedToken(): string?
	return selectedToken
end

function MesaState.selectedCell(): (number?, number?)
	return selectedX, selectedZ
end

function MesaState.selectToken(id: string?)
	selectedToken, selectedX, selectedZ = id, nil, nil
	emit("selection", selectedToken, nil, nil)
end

function MesaState.selectCell(x: number?, z: number?)
	selectedToken, selectedX, selectedZ = nil, x, z
	emit("selection", nil, x, z)
end

function MesaState.tableView(): boolean
	return tableView
end

function MesaState.setTableView(enabled: boolean)
	if enabled ~= tableView then
		tableView = enabled
		emit("tableView", enabled)
	end
end

-- Pincel de mapa (M4): com pincel ativo, o tabuleiro pinta casas em vez de selecionar.
-- Valores: "parede", "dificil", "agua", "limpar", "nevoa", "revelar" ou nil.
function MesaState.brush(): string?
	return brush
end

function MesaState.setBrush(name: string?)
	if name ~= brush then
		brush = name
		emit("brush", name)
	end
end

-- Rolagem vista por este jogador (só apresentação: dados 3D, destaque no painel).
-- data = { by, label?, text, total, natural?, critical?, secret, tokenId? }
function MesaState.onRoll(callback: (any) -> ())
	table.insert(listeners.roll, callback)
end

function MesaState.onBrush(callback: (string?) -> ())
	table.insert(listeners.brush, callback)
end

-- Ficha v2 (docs/CONTRATOS.md §5) ------------------------------------------

-- O código copiado no site é o envelope v2 (JSON com "mesa": 2)?
function MesaState.ehFichaV2(texto: string): boolean
	local corpo = string.match(texto, "^%s*(.-)%s*$")
	return string.sub(corpo, 1, 1) == "{" and string.find(corpo, '"mesa":2', 1, true) ~= nil
end

-- Envia o envelope em partes, cada uma depois da confirmação da anterior, e
-- conclui. opcoes: { targetId? } para atualizar ou { ownerUserId?, x?, z?, hidden? }
-- para criar. progresso(texto, terminou, falhou) informa o painel. O servidor
-- devolve uma PROPOSTA; nada muda na mesa até o mestre aprovar.
local envioAtivo = false
function MesaState.enviarFichaV2(texto: string, opcoes: { [string]: any }, progresso: (string, boolean, boolean) -> ())
	if envioAtivo then
		progresso("Já há uma ficha sendo enviada.", true, true)
		return
	end
	envioAtivo = true
	task.spawn(function()
		local json = string.match(texto, "^%s*(.-)%s*$")
		local partes = UploadPartes.dividir(json)
		local pedido = "r" .. math.floor(os.clock() * 1000) % 1000000000
		local ultima = nil
		local conexao = remote.OnClientEvent:Connect(function(kind, data)
			if kind == "fichaUpload" and type(data) == "table" then
				ultima = data
			elseif kind == "log" and type(data) == "table" and data.tone == "erro" then
				-- Recusas chegam pelo registro: o envio para logo, sem esperar o prazo.
				ultima = { erro = data.text }
			end
		end)
		local function esperar(condicao: (any) -> boolean): any
			local limite = os.clock() + 10
			while os.clock() < limite do
				if ultima and (ultima.erro or condicao(ultima)) then
					local dado = ultima
					ultima = nil
					return dado
				end
				task.wait(0.05)
			end
			return { erro = "O servidor não respondeu a tempo." }
		end
		local function terminar(mensagem: string, falhou: boolean)
			conexao:Disconnect()
			envioAtivo = false
			progresso(mensagem, true, falhou)
		end

		local inicio = table.clone(opcoes)
		inicio.requestId = pedido
		inicio.byteCount = #json
		inicio.partCount = #partes
		ultima = nil
		MesaState.send("fichaImportBegin", inicio)
		local resposta = esperar(function(d)
			return d.requestId == pedido and d.uploadId ~= nil
		end)
		if resposta.erro then
			return terminar(resposta.erro, true)
		end
		local uploadId = resposta.uploadId
		for indice, parte in partes do
			progresso(string.format("Enviando a ficha: parte %d de %d…", indice, #partes), false, false)
			-- Ritmo abaixo do limite de pedidos do servidor (8 por segundo).
			task.wait(0.15)
			MesaState.send("fichaImportPart", { uploadId = uploadId, index = indice, text = parte })
			resposta = esperar(function(d)
				return d.uploadId == uploadId and d.nextIndex == indice + 1
			end)
			if resposta.erro then
				MesaState.send("fichaImportAbort", { uploadId = uploadId })
				return terminar(resposta.erro, true)
			end
		end
		progresso("Validando a ficha no servidor…", false, false)
		MesaState.send("fichaImportCommit", { uploadId = uploadId })
		resposta = esperar(function(d)
			return d.uploadId == uploadId and d.proposalId ~= nil
		end)
		if resposta.erro then
			return terminar(resposta.erro, true)
		end
		terminar("Ficha recebida: confira a proposta " .. resposta.proposalId .. " e aprove.", false)
	end)
end

-- Ficha v2 completa de uma ficha da mesa (pede ao servidor quando a versão muda).
-- Devolve o que já está em cache; onFichaDetalhe avisa quando chegar.
function MesaState.fichaDetalhe(id: string): any?
	local token = MesaState.findToken(id)
	if not token or not token.ficha2Versao then
		return nil
	end
	local guardada = detalhes[id]
	if guardada and guardada.version == token.ficha2Versao then
		return guardada.ficha2
	end
	local pedido = pedidosDeDetalhe[id]
	if not pedido or pedido.version ~= token.ficha2Versao or os.clock() - pedido.stamp > 5 then
		pedidosDeDetalhe[id] = { version = token.ficha2Versao, stamp = os.clock() }
		MesaState.send("fichaDetalhe", { id = id })
	end
	return nil
end

function MesaState.onFichaDetalhe(callback: (string, any) -> ())
	table.insert(listeners.fichaDetalhe, callback)
end

-- Perfil de personagem temporário da própria sessão; nunca vem no snapshot da mesa.
function MesaState.onPersonagemPessoal(callback: (any?) -> ())
	table.insert(listeners.personagemPessoal, callback)
end

function MesaState.onLoja(callback: (any) -> ())
	table.insert(listeners.loja, callback)
end

function MesaState.onMissoes(callback: (any) -> ())
	table.insert(listeners.missoes, callback)
end

-- Habilidades (A1) -----------------------------------------------------------

-- Fim de um encontro do Modo Luta: { resultado = "vitoria" | "derrota" }.
function MesaState.onEncontro(callback: (any) -> ())
	table.insert(listeners.encontro, callback)
end

-- Recibo de um efeito resolvido pelo servidor (só apresentação: animar).
function MesaState.onEfeito(callback: (any) -> ())
	table.insert(listeners.efeito, callback)
end

function MesaState.mira()
	return mira
end

-- Liga (ou desliga, com nil) a mira; o tabuleiro destaca o alcance e o próximo
-- clique escolhe o alvo ou a casa.
function MesaState.setMira(nova)
	mira = nova
	emit("mira", nova)
end

function MesaState.onMira(callback: (any) -> ())
	table.insert(listeners.mira, callback)
end

function MesaState.escolherCasaDaMira(x,z)
	local mec=mira and require(game.ReplicatedStorage.Shared.Regras.Execucao).MECANICAS[mira.habilidadeId]
	if mec and require(game.ReplicatedStorage.Shared.AreaHabilidade).eArea(mec) then
		MesaState.setMira(require(game.ReplicatedStorage.Shared.PlanejamentoArea).escolher(mira,mec,x,z))
	else MesaState.dispararMira(nil,x,z) end
end

-- Envia o uso da habilidade da mira com o alvo escolhido e desliga a mira.
function MesaState.dispararMira(alvoId: string?, x: number?, z: number?)
	if not mira then
		return
	end
	-- Andar (botão da barra): a casa escolhida vira um pedido de movimento comum.
	if mira.habilidadeId == "mesa/andar" then
		if x and z then
			MesaState.send("move", { id = mira.tokenId, x = x, z = z, andar = true })
			MesaState.setMira(nil)
		end
		return
	end
	if mira.modo == "lista" and alvoId then
		mira.alvoIds = mira.alvoIds or {}
		local i = table.find(mira.alvoIds, alvoId)
		if i then table.remove(mira.alvoIds, i) elseif #mira.alvoIds < mira.maxAlvos then table.insert(mira.alvoIds, alvoId) end
		emit("mira", mira)
		return
	end
	if mira.habilidadeId=="criatura/ataque" then
		MesaState.send("salaAtaqueMonstro",{tokenId=mira.tokenId,alvoId=alvoId});MesaState.setMira(nil);return
	end
	if mira.modo == "lista" and #(mira.alvoIds or {}) == 0 then return end
	local area = require(game.ReplicatedStorage.Shared.PlanejamentoArea).pedido(mira)
	MesaState.send("usarHabilidade", { tokenId = mira.tokenId, habilidadeId = mira.habilidadeId, alvoId = alvoId, alvoIds = mira.alvoIds, pactoId = mira.pactoId, x = if area then area.x else x, z = if area then area.z else z, inicioX = area and area.inicioX, inicioZ = area and area.inicioZ })
	MesaState.setMira(nil)
end

-- Registro de ouvintes. onSnapshot e onLog repetem o que já chegou.
function MesaState.onSnapshot(callback: (any) -> ())
	table.insert(listeners.snapshot, callback)
	if snapshot then
		task.spawn(callback, snapshot)
	end
end

function MesaState.onLog(callback: (any) -> ())
	table.insert(listeners.log, callback)
	for _, entry in logHistory do
		task.spawn(callback, entry)
	end
end

function MesaState.onSelection(callback: (string?, number?, number?) -> ())
	table.insert(listeners.selection, callback)
end

function MesaState.onTableView(callback: (boolean) -> ())
	table.insert(listeners.tableView, callback)
end

return MesaState
