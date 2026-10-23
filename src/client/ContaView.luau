-- Conta entre runs: consulta e compra são confirmadas exclusivamente pelo servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Extra = require(script.Parent.UI.ExtraTelas)
local RunConta = require(ReplicatedStorage.Shared.Regras.RunConta)
local View = {}
local ROTULOS = {
	["treinador:agua"] = "Treinador de Água", ["treinador:terra"] = "Treinador de Terra",
	["treinador:desintoxicacao"] = "Treinador de Desintoxicação", ["treinador:deus-do-norte"] = "Treinador do Deus do Norte",
	["treinador:deus-da-espada"] = "Treinador do Deus da Espada", ["raca:rara"] = "Raça rara (provisória)",
	["item:pocao-menor"] = "Poção menor inicial", ["cosmetico:capa-vermelha"] = "Capa vermelha",
}

local function chaves(mapa)
	local lista = {}
	for id, valor in mapa or {} do if valor then table.insert(lista, id) end end
	table.sort(lista)
	return lista
end

function View.start()
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "ContaJogo", false, 43
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local conexoes, vivo, remote = {}, true, nil
	local function conectar(sinal, funcao) table.insert(conexoes, sinal:Connect(funcao)) end
	local atalho = Extra.atalho(gui, "AtalhoConta", "◉", "CONTA", 2)
	atalho.Position = UDim2.new(1, -84, 0, 76)
	local painel = Extra.painel(gui, "Painel", Vector2.new(760, 740), UDim2.fromScale(.92, .86))
	local titulo = Extra.tituloPainel(painel.Conteudo, "CONTA · entre runs", 1)
	titulo.Position, titulo.Size = UDim2.fromOffset(0, 0), UDim2.new(1, -104, 0, 36)
	local fechar = Extra.fechar(painel.Conteudo, painel, 2)
	fechar.Position = UDim2.new(1, -96, 0, 0)
	local aviso = Extra.texto(painel.Conteudo, "Abra para consultar sua conta.", 3, "secundario")
	aviso.Position, aviso.Size = UDim2.fromOffset(0, 42), UDim2.new(1, 0, 0, 0)
	local lista, layout = Extra.lista(painel.Conteudo, "Conteudo", UDim2.fromOffset(0, 82), UDim2.new(1, 0, 1, -82), 8)
	local conta, catalogo, pendente, ultimo = nil, RunConta.CATALOGO, nil, -math.huge
	local render, enviar
	local function linha(texto, destaque)
		return Extra.texto(lista, texto, #lista:GetChildren(), destaque)
	end
	local function renderizar()
		Extra.limpar(lista, layout)
		if not conta then linha("Nenhuma conta carregada."); return end
		linha(string.format("%d moedas da conta", conta.moeda), "alerta")
		linha("Conquistas", "titulo")
		local ganhas = chaves(conta.conquistas)
		if #ganhas == 0 then linha("Nenhuma conquista ainda.", "secundario") end
		for _, id in ganhas do linha("✦ " .. (RunConta.CONQUISTAS[id] and RunConta.CONQUISTAS[id].titulo or id)) end
		linha("Códice", "titulo")
		for _, categoria in RunConta.CATEGORIAS_CODICE do
			local entradas = chaves(conta.codice[categoria])
			linha(categoria .. ": " .. (if #entradas > 0 then table.concat(entradas, ", ") else "a descobrir"), "secundario")
		end
		linha("Desbloqueios · catálogo provisório", "titulo")
		linha("Desbloqueios para próximas expedições; catálogo provisório.", "secundario")
		for _, id in chaves(catalogo) do
			local item, comprado = catalogo[id], conta.desbloqueios[id] == true
			local ativo = not comprado and not pendente and conta.moeda >= item.custo
			local tituloItem = item.titulo or ROTULOS[id] or "Desbloqueio"
			local tipo = item.tipo or string.match(id, "^([^:]+):") or ""
			local status = if comprado then (if tipo == "cosmetico" then "Registrado · sem efeito mecânico; aparência futura" else "Ativo nas próximas runs")
				elseif conta.moeda < item.custo then "Saldo insuficiente" else "Comprar"
			local detalhe = if type(item.efeito) == "string" and item.efeito ~= "" then " · " .. item.efeito else ""
			local b = Extra.botao(lista, id, tituloItem .. " · " .. tipo .. detalhe .. " · " .. tostring(item.custo) .. " moedas · " .. status,
				#lista:GetChildren(), ativo, if ativo then function() enviar("comprar", id) end else nil)
			b:SetAttribute("Desabilitado", not ativo)
		end
	end
	render = renderizar
	enviar = function(acao, itemId)
		if not remote or pendente then return end
		if os.clock() - ultimo < .4 then aviso.Text = "Aguarde um instante antes de tentar novamente."; return end
		ultimo = os.clock()
		local id = HttpService:GenerateGUID(false)
		pendente = id
		aviso.Text = if acao == "comprar" then "Confirmando compra…" else "Consultando conta…"
		render()
		local pedido = { acao = acao, requestId = id }
		if itemId then pedido.itemId = itemId end
		remote:FireServer(pedido)
		task.delay(15, function()
			if vivo and pendente == id then pendente = nil; aviso.Text = "Sem resposta. Feche e abra a conta para consultar antes de comprar novamente."; render() end
		end)
	end
	conectar(fechar.Activated, function() painel.Visible = false end)
	conectar(atalho.Activated, function() painel.Visible = not painel.Visible; if painel.Visible then enviar("consultar") end end)
	conectar(gui.Destroying, function() vivo = false; for _, conexao in conexoes do conexao:Disconnect() end end)
	task.spawn(function()
		remote = ReplicatedStorage:WaitForChild("ContaJogo", 15)
		if not vivo then return end
		if not remote then aviso.Text = "Conta indisponível neste servidor."; return end
		conectar(remote.OnClientEvent, function(resposta)
			if type(resposta) ~= "table" or resposta.requestId ~= pendente then return end
			pendente = nil
			if RunConta.valida(resposta.conta) then conta = resposta.conta end
			if type(resposta.catalogo) == "table" then catalogo = resposta.catalogo end
			aviso.Text = resposta.mensagem or (if resposta.ok then "Conta atualizada. Compras são feitas entre runs." else "Não foi possível concluir o pedido.")
			render()
		end)
		if painel.Visible then enviar("consultar") end
	end)
	return gui
end

return View
