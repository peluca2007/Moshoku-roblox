local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Estilo, Comandos = require(Shared.Estilo), require(Shared.AdminComandos)
local AdminView = {}
function AdminView.start(state)
	local remote = game:GetService("ReplicatedStorage"):WaitForChild("ComandosAdmin")
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.DisplayOrder, gui.ResetOnSpawn, gui.Enabled = "AdminPanel", 23, false, false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local fundo = Instance.new("Frame")
	fundo.Size, fundo.BackgroundColor3, fundo.Active, fundo.Parent = UDim2.fromScale(1, 1), Estilo.MESA_FUNDO, true, gui
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position, scroll.Size = UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.94)
	scroll.BackgroundTransparency, scroll.BorderSizePixel, scroll.CanvasSize = 1, 0, UDim2.new()
	scroll.AutomaticCanvasSize, scroll.ScrollBarThickness, scroll.Parent = Enum.AutomaticSize.Y, 5, fundo
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 10), Enum.SortOrder.LayoutOrder, scroll
	local ordem = 0
	local function objeto(class, texto, altura)
		ordem += 1
		local o = Instance.new(class)
		o.LayoutOrder, o.Size, o.Text = ordem, UDim2.new(1, -10, 0, altura), texto
		o.FontFace, o.TextSize, o.TextWrapped, o.TextColor3 = Estilo.ROTULO_FORTE, 16, true, Estilo.TINTA
		o.BackgroundColor3, o.Parent = Estilo.PAPEL_2, scroll
		return o
	end
	objeto("TextLabel", "ADMIN • /adm ajuda no chat", 48)
	local fechar = objeto("TextButton", "VOLTAR AO JOGO", 44)
	fechar.Activated:Connect(function() gui.Enabled = false end)
	-- Por enquanto não há mestre: o ADM joga como jogador e só vira mestre se quiser.
	local modo = objeto("TextButton", "MODO: JOGADOR • toque para virar mestre", 52)
	modo.Name = "ModoAdmin"
	local modoJogador = true
	local temSala=false;local botoesPapel={}
	modo.Activated:Connect(function()
		if temSala then return end
		remote:FireServer({ comando = if modoJogador then "mestre" else "jogador" })
	end)
	local feedback = objeto("TextLabel", "Brotos e Arrumar funcionam na sala. Os comandos de fichas também funcionam em combate. Escolha o alvo; PV/Mana/PT usam Valor, Mover usa X e Z.", 90)
	feedback.Name = "RespostaAdmin"
 feedback.AutomaticSize = Enum.AutomaticSize.Y
 local alvo = "meus"
 local escolher = objeto("TextButton", "ALVO: minhas fichas • toque para trocar", 52)
 escolher.Name = "AlvoAdmin"
 local function opcoes()
  local lista = {{id="meus",nome="minhas fichas"},{id="todos",nome="TODAS as fichas"}}
  local snap = state.snapshot()
  for _,t in snap and snap.tokens or {} do table.insert(lista,{id=t.id,nome=t.name.." • "..t.id}) end
  return lista
 end
 escolher.Activated:Connect(function()
  local lista=opcoes();local i=0
  for n,t in lista do if t.id==alvo then i=n end end
  local t=lista[i%#lista+1]; alvo=t.id; escolher.Text="ALVO: "..t.nome.." • toque para trocar"
 end)
 local valor=objeto("TextBox","",44)
 valor.Name,valor.PlaceholderText,valor.ClearTextOnFocus="ValorAdmin","Valor para PV, Mana ou PT (0 até o máximo)",false
 local x=objeto("TextBox","",44)
 x.Name,x.PlaceholderText,x.ClearTextOnFocus="XAdmin","Mover: casa X (1 a 20)",false
 local z=objeto("TextBox","",44)
 z.Name,z.PlaceholderText,z.ClearTextOnFocus="ZAdmin","Mover: casa Z (1 a 20)",false
	local admin = false
	local avisoGui = Instance.new("ScreenGui")
	avisoGui.Name, avisoGui.DisplayOrder, avisoGui.ResetOnSpawn, avisoGui.Parent = "AvisosAdmin", 24, false, gui.Parent
	local aviso = Instance.new("TextLabel")
	aviso.AnchorPoint, aviso.Position, aviso.Size = Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.92), UDim2.fromScale(0.85, 0.13)
	aviso.BackgroundColor3, aviso.TextColor3, aviso.FontFace, aviso.TextSize = Estilo.PAPEL_2, Estilo.TINTA, Estilo.ROTULO_FORTE, 16
	aviso.TextWrapped, aviso.Visible, aviso.Parent = true, false, avisoGui
	local versaoAviso = 0
	local alvoDiversao = { id = "eu", nome = "eu" }
	local function opcoesDiversao()
		local lista = { { id = "eu", nome = "eu" }, { id = "todos", nome = "TODOS os jogadores" } }
		local snap = state.snapshot()
		for _, j in snap and snap.players or {} do
			if j.userId ~= Players.LocalPlayer.UserId then table.insert(lista, { id = tostring(j.userId), nome = j.name }) end
		end
		return lista
	end
	for _, c in Comandos.LISTA do
		if c.diversao and alvoDiversao.botao == nil then
			objeto("TextLabel", "DIVERSÃO • só aparência, 15 s, também em combate. Não pega em quem está Escondido.", 52)
			local botao = objeto("TextButton", "ALVO DA DIVERSÃO: eu • toque para trocar", 52)
			botao.Name, alvoDiversao.botao = "AlvoDiversao", botao
			botao.Activated:Connect(function()
				local lista, i = opcoesDiversao(), 0
				for n, o in lista do if o.id == alvoDiversao.id then i = n end end
				local o = lista[i % #lista + 1]
				alvoDiversao.id, alvoDiversao.nome = o.id, o.nome
				botao.Text = "ALVO DA DIVERSÃO: " .. o.nome .. " • toque para trocar"
			end)
		end
		local b = objeto("TextButton", "/adm " .. c.id .. "\n" .. c.descricao, 64)
		b.Name = "Admin_" .. c.id
		if c.id=="jogador" or c.id=="mestre" then table.insert(botoesPapel,b) end
		local confirmarAte = 0
		b.Activated:Connect(function()
			if not admin then return end
			if (c.confirmar or (c.alvo and alvo == "todos")) and os.clock() > confirmarAte then
				confirmarAte = os.clock() + 5
				feedback.Text = "Confirmar /adm "..c.id..(if c.alvo then " em TODAS as fichas" else " a partida").."? Toque novamente em até 5 segundos."
				return
			end
			confirmarAte = 0
			local pedido={comando=c.id}
   if c.alvo then pedido.alvo=alvo end
   if c.jogadorAlvo then pedido.alvo=alvoDiversao.id end
   if c.valor then pedido.valor=tonumber(valor.Text) end
   if c.casa then pedido.x=tonumber(x.Text);pedido.z=tonumber(z.Text) end
   local id,erro=Comandos.parse(pedido)
   if not id then feedback.Text=erro;return end
   remote:FireServer(pedido)
		end)
	end
	remote.OnClientEvent:Connect(function(data)
		if admin and type(data) == "table" and type(data.texto) == "string" then
			feedback.Text = data.texto
			if string.find(data.texto, "/adm ajuda", 1, true) then gui.Enabled = true end
			aviso.Text, aviso.Visible = data.texto, not gui.Enabled
			versaoAviso += 1
			local versao = versaoAviso
			task.delay(5, function() if versao == versaoAviso then aviso.Visible = false end end)
		end
	end)
	state.onSnapshot(function(snap)
		admin = snap.you.admin == true
		modoJogador = snap.you.modoJogador ~= false
		temSala=snap.salaConceitual~=nil
		modo.Interactable=not temSala;modo.AutoButtonColor=not temSala
		for _,b in botoesPapel do b.Visible=not temSala end
		modo.Text = if temSala then "O mestre da sala transfere o posto em Pessoas e equipes no escudo." elseif modoJogador then "MODO: JOGADOR • toque para virar mestre" else "MODO: MESTRE • toque para voltar a jogar como jogador"
		if not admin then gui.Enabled = false; aviso.Visible = false end
	end)
	return { abrir = function()
  if not admin then return end
  if not gui.Enabled then
   local t=state.findToken(state.selectedToken())
   if t then alvo=t.id;escolher.Text="ALVO: "..t.name.." • "..t.id.." • toque para trocar" end
   local cx,cz=state.selectedCell();if cx then x.Text=tostring(cx);z.Text=tostring(cz) end
  end
  gui.Enabled=not gui.Enabled
 end }
end
return AdminView
