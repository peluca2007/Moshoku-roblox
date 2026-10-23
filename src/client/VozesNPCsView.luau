-- Vozes locais sobre resultados confirmados. Fila curta, cancelável e sem remotos de intenção.
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Plano = require(RS.Shared.VozesNPCs)
local Falas = require(RS.Shared.DublagemNPCs)
local Protocol = require(RS.Shared.MesaProtocol)
local Sonorizacao = require(script.Parent.Sonorizacao)
local View = {}
function View.start(state)
	local mem, fila, ativos, variantes = Plano.novo(), {}, {}, {}
	local geracao, emCombate, ultimaVez = 0, false, nil
	local encerrado = false
	local historico = {}
	local function limpar()
		geracao += 1
		table.clear(fila)
		for som in ativos do som:Destroy() end
		table.clear(ativos)
		mem, variantes = Plano.novo(), {}
	end
	local function valido(item)
		if encerrado then return false end
		local s = state.snapshot()
		if item.geracao ~= geracao or not s or not s.combat or not s.combat.active then return false end
		local t = state.findToken(item.tokenId)
		return t ~= nil and t.vozNPC == item.familia and (item.prioridade == 5 or not t.derrotado and (type(t.pv) ~= "number" or t.pv > 0))
	end
	local function adicionar(lista)
		if encerrado then return end
		for _, item in lista do
			item.geracao, item.criado = geracao, os.clock()
			-- Uma reação mais importante substitui a anterior da mesma criatura.
			local aceitar = true
			for i = #fila, 1, -1 do
				if fila[i].tokenId == item.tokenId then
					if fila[i].prioridade > item.prioridade then aceitar = false else table.remove(fila, i) end
				end
			end
			for som, tocando in ativos do
				if tocando.tokenId == item.tokenId then
					if tocando.prioridade < item.prioridade then som:Destroy(); ativos[som] = nil
					elseif tocando.prioridade > item.prioridade then aceitar = false end
				end
			end
			if aceitar and valido(item) then table.insert(fila, item) end
		end
		table.sort(fila, function(a, b) return a.prioridade > b.prioridade or a.prioridade == b.prioridade and a.criado < b.criado end)
		while #fila > 4 do table.remove(fila) end
	end
	local function despachar()
		if encerrado then return end
		table.sort(fila, function(a, b) return a.prioridade > b.prioridade or a.prioridade == b.prioridade and a.criado < b.criado end)
		local n = 0
		for som, item in ativos do
			if not valido(item) or os.clock() > item.fim or not som.Parent then som:Destroy(); ativos[som] = nil else n += 1 end
		end
		local tentativas = #fila
		while n < 2 and #fila > 0 and tentativas > 0 do
			tentativas -= 1
			local item = table.remove(fila, 1)
			if not valido(item) or os.clock() - item.criado > 3.5 or Sonorizacao.volume() <= 0 then continue end
			local ocupado = false
			for _, tocando in ativos do if tocando.tokenId == item.tokenId then ocupado = true; break end end
			if ocupado then table.insert(fila, item); continue end
			local lista = {}
			for chave in Falas do if string.sub(chave, 1, #item.prefixo) == item.prefixo then table.insert(lista, chave) end end
			table.sort(lista)
			if #lista == 0 then continue end
			variantes[item.prefixo] = (variantes[item.prefixo] or 0) % #lista + 1
			local chave = lista[variantes[item.prefixo]]
			local fala = Falas[chave]
			if type(fala.id) ~= "string" or not string.match(fala.id, "^rbxassetid://[1-9]%d*$") then continue end
			local som = Instance.new("Sound")
			som.Name, som.SoundId, som.Volume = "VozNPC_" .. chave, fala.id, .8
			som.SoundGroup = SoundService:FindFirstChild("MoshokuEfeitos")
			som.Parent = SoundService
			item.chave, item.fim = chave, os.clock() + math.clamp(fala.segundos or 4, .1, 30) + 5
			ativos[som] = item
			som.Ended:Connect(function() ativos[som] = nil; som:Destroy() end)
			local ok = pcall(function() som:Play() end)
			if not ok then ativos[som] = nil; som:Destroy() else
				n += 1
				table.insert(historico, chave)
				if #historico > 32 then table.remove(historico, 1) end
			end
		end
	end
	state.onSnapshot(function(s)
		if encerrado then return end
		local ativo = s.combat and s.combat.active == true
		-- Recomeço sem snapshot inativo também invalida filas da partida anterior.
		local reinicio = ativo and ultimaVez and type(s.combat.turn) == "number" and s.combat.turn < ultimaVez
		if ativo ~= emCombate or reinicio then limpar() end
		emCombate, ultimaVez = ativo, if ativo then s.combat.turn else nil
		if ativo then adicionar(Plano.snapshot(mem, s)) end
		despachar()
	end)
	state.onEfeito(function(r) adicionar(Plano.efeito(mem, state.snapshot(), r)); despachar() end)
	state.onEncontro(function() limpar(); emCombate, ultimaVez = false, nil end)
	local remoto = RS:WaitForChild(Protocol.REMOTE).OnClientEvent:Connect(function(tipo, d)
		if tipo == "chefeEfeito" then adicionar(Plano.especial(mem, state.snapshot(), d)); despachar() end
	end)
	local pulso = RunService.Heartbeat:Connect(despachar)
	return {
		limpar = limpar,
		destruir = function() encerrado = true; limpar(); remoto:Disconnect(); pulso:Disconnect() end,
		estado = function()
			local n = 0; for _ in ativos do n += 1 end
			return { ativos = n, fila = #fila, historico = table.clone(historico), geracao = geracao }
		end,
	}
end
return View
