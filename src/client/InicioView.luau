-- Menu de pausa central: tela escurecida, painel estreito no centro (máx. 520x640, abaixo da faixa de
-- botões do Roblox), poucos botões grandes e páginas (Ajuda, Ajustes e, só no Studio/administrador, os
-- modos da mesa). Fecha por "Continuar", pelo X ou por Esc. Pedidos continuam sujeitos à confirmação do
-- servidor. Instances: ScreenGui "InicioJogo" > MenuInicial > Entrada > Conteudo > Conteudo > Pagina_<nome>.
-- O botão MENU mora na barra de atalhos (client/Atalhos).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Extra = require(script.Parent.UI.ExtraEntrada)
local T, C = Extra.T, Extra.C
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalogo = require(ReplicatedStorage.Shared.Livro.Catalogo)
local Som = require(script.Parent.Sonorizacao)
local FX = require(script.Parent.MenuEfeitos)
local Fluxo = require(script.Parent.AberturaFluxo)
local Abertura = require(ReplicatedStorage.Shared.Regras.AberturaRun)
local AjudaConteudo = require(ReplicatedStorage.Shared.AjudaConteudo)
local Atalhos = require(script.Parent.Atalhos)
local Inicio = {}
local MAX_PAINEL = Vector2.new(520, 640)
local ALTURA_BOTAO, ALTURA_BOTAO_COM_TEXTO = 56, 88
function Inicio.start(state, escolha, admin, criacao)
	local pg=Players.LocalPlayer:WaitForChild("PlayerGui")
	pg:WaitForChild("MesaPanel").Enabled=false
	local ouro=T.cores.ouro
	local function criar(class,parent,props)
		local o=Instance.new(class); for k,v in props do o[k]=v end; o.Parent=parent; Extra.estilizar(o, props.FontFace); return o
	end
	local gui=criar("ScreenGui",pg,{Name="InicioJogo",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=20,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
	-- Tela inteira escurecida (e que bloqueia cliques no mundo); o painel fica no centro.
	local fundo=criar("Frame",gui,{Name="MenuInicial",Size=UDim2.fromScale(1,1),BackgroundColor3=T.cores.fundoTela,BackgroundTransparency=.25,BorderSizePixel=0,Active=true})
	local moldura=C.painel({parent=fundo,nome="Entrada",losangos=true,padding=16,
		tamanho=UDim2.new(.92,0,1,-24),posicao=UDim2.fromScale(.5,.5),ancora=Vector2.new(.5,.5)})
	criar("UISizeConstraint",moldura,{MaxSize=MAX_PAINEL})
	C.aplicarEscala(moldura)
	local painel=criar("ScrollingFrame",moldura.Conteudo,{Name="Conteudo",Size=UDim2.new(1,0,1,-28),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
	Extra.rolagem(painel)
	criar("UIListLayout",painel,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
	local indicacao=C.texto({parent=moldura.Conteudo,nome="IndicacaoRolagem",texto="Role para ver mais opções",secundario=true,posicao=UDim2.new(0,0,1,-24),tamanho=UDim2.new(1,0,0,24)})
	-- Faixa de botões do Roblox no topo: nada do painel fica por baixo dela.
	local function topoSeguro()
		local ok,faixa=pcall(function() return GuiService.TopbarInset end)
		local altura=if ok and typeof(faixa)=="Rect" then faixa.Max.Y else 0
		return math.max(altura,GuiService:GetGuiInset().Y)
	end
	local function responsivo()
		local topo=topoSeguro()
		moldura.Size=UDim2.new(.92,0,1,-(topo+24))
		moldura.Position=UDim2.new(.5,0,.5,topo/2)
		indicacao.Visible=painel.AbsoluteCanvasSize.Y>painel.AbsoluteSize.Y+1
		indicacao.Text=if painel.CanvasPosition.Y+painel.AbsoluteSize.Y>=painel.AbsoluteCanvasSize.Y-2 then "Início acima · role para voltar" else "Role para ver mais opções"
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(responsivo)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(responsivo)
	painel:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(responsivo)
	painel:GetPropertyChangedSignal("CanvasPosition"):Connect(responsivo)
	task.defer(responsivo)
	local ordem=0
	local function texto(parent,nome,t,altura,tamanho,cor)
		ordem+=1
		return criar("TextLabel",parent,{Name=nome,Text=t,LayoutOrder=ordem,Size=UDim2.new(1,0,0,altura),BackgroundTransparency=1,TextColor3=cor or T.cores.texto,TextSize=tamanho or 16,FontFace=T.fontes.rotulo,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
	end
	texto(painel,"Edicao","CRÔNICAS DE UMA NOVA VIDA",22,14,ouro)
	local titulo=texto(painel,"Titulo","Moshoku",52,44); titulo.FontFace=T.fontes.titulo
	local fio=Extra.ornamento(painel); fio.LayoutOrder=3
	ordem=3
	local personagem=texto(painel,"PersonagemAtual","Sem personagem ainda",26,16,ouro)
	local status=texto(painel,"EstadoSala","Aguarde o servidor.",34,15,T.cores.secundario)
	local paginas={}
	local function pagina(nome)
		ordem+=1
		local p=criar("Frame",painel,{Name="Pagina_"..nome,LayoutOrder=ordem,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=false})
		criar("UIListLayout",p,{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
		paginas[nome]=p; return p
	end
	local home,jogar,ajustes,ajuda,modos=pagina("Inicio"),pagina("Jogar"),pagina("Ajustes"),pagina("Ajuda"),pagina("Modos")
	local desafios,pvp=pagina("Desafios"),pagina("PvP")
	local paginaAtual="Inicio"
	local function abrir(nome)
		paginaAtual=nome
		for id,p in paginas do p.Visible=id==nome end
		painel.CanvasPosition=Vector2.zero
	end
	local function botao(parent,nome,t,sub,fn,principal)
		ordem+=1
		local b=C.botao({parent=parent,nome=nome,texto=t,ordem=ordem,
			variante=if principal then "principal" elseif nome=="OutrosModos" then "fantasma" else "secundario",
			tamanho=UDim2.new(1,0,0,if sub then ALTURA_BOTAO_COM_TEXTO else ALTURA_BOTAO),aoClicar=fn})
		if sub then
			b.Rotulo.Position=UDim2.fromOffset(12,8); b.Rotulo.Size=UDim2.new(1,-24,0,28); b.Rotulo.TextXAlignment=Enum.TextXAlignment.Left
			local d=C.texto({parent=b,nome="Descricao",texto=sub,posicao=UDim2.fromOffset(12,38),tamanho=UDim2.new(1,-24,0,44)})
			d.AutomaticSize=Enum.AutomaticSize.None; d.TextSize=16; d:SetAttribute("TextoBaseUIV2",16); d.TextTruncate=Enum.TextTruncate.AtEnd
			d.TextColor3=if principal then T.cores.textoEscuro else T.cores.secundario
		end
		return b
	end
	local snap=nil; local pedidoAte=0; local estavaNaPartida=false
	local pediuPerfilPessoal=false
	state.onPersonagemPessoal(function(perfil)
		local construcao=perfil and perfil.construcao or nil
		local raca=construcao and Catalogo.POR_ID[construcao.raceId]
		local arvore=construcao and Catalogo.POR_ID[construcao.startingTreeId]
		personagem.Text=if construcao then string.format("%s · %s · %s",perfil.nome or "Personagem",raca and raca.data.name or "Raça",arvore and arvore.data.name or "Árvore") else "Sem personagem ainda"
	end)
	if not pediuPerfilPessoal then
		pediuPerfilPessoal=true
		state.send("personagemPessoalConsultar",{})
	end
	local function pedir(comando,payload)
		if not snap then status.Text="Conectando…"; return end
		if snap.combat.active then status.Text="Há uma partida em andamento. Você pode assistir."; return end
		if os.clock()<pedidoAte then return end
		pedidoAte=os.clock()+.6; state.send(comando,payload or {}); status.Text="Aguardando a sala…"
	end
	local runAtiva=false
	local remoteRun
	local continuar -- botão único "Continuar" (com expedição) / "Nova expedição" (sem)
	local TEXTOS_CONTINUAR={
		[true]={"Continuar","Volte para a cidade e para a expedição de onde parou."},
		[false]={"Nova expedição","Fale com os mestres da cidade e desça ao esgoto."},
	}
	local function atualizarContinuar()
		if not continuar then return end
		local t=TEXTOS_CONTINUAR[runAtiva]
		continuar.Rotulo.Text=t[1]
		local d=continuar:FindFirstChild("Descricao")
		if d then d.Text=t[2] end
	end
	task.spawn(function()
		remoteRun=ReplicatedStorage:WaitForChild("RunJogo")
		remoteRun.OnClientEvent:Connect(function(tipo,dado)
			if tipo~="run" or type(dado)~="table" or dado.erro then return end
			runAtiva=not dado.semRun and not dado.fim
			atualizarContinuar()
		end)
		remoteRun:FireServer({acao="consultar"})
	end)
	local function fecharMenu()
		fundo.Visible=false
		if snap and snap.combat.active then state.setTableView(true) end
	end
	-- Um só botão: com expedição em andamento só fecha o menu (Fluxo.novaExpedicao); sem ela, começa uma.
	continuar=botao(home,"Continuar",TEXTOS_CONTINUAR[false][1],TEXTOS_CONTINUAR[false][2],function()
		if not runAtiva then status.Text="Preparando a expedição…" end
		if snap and snap.combat.active then state.setTableView(true) end
		Fluxo.novaExpedicao()
	end,true)
	atualizarContinuar()
	botao(home,"Personagem","Personagem",nil,function()
		if criacao then fundo.Visible=false; criacao.abrir(function() fundo.Visible=true end)
		else escolha.abrir(function() fundo.Visible=true end) end
	end)
	botao(home,"Ajuda","Como jogar",nil,function() abrir("Ajuda") end)
	botao(home,"Ajustes","Ajustes",nil,function() abrir("Ajustes") end)
	-- Treino, desafios e PvP da mesa: só no Studio ou para administrador (atualizado a cada snapshot).
	local outrosModos=botao(home,"OutrosModos","Outros modos",nil,function() abrir("Jogar") end)
	local noStudio=RunService:IsStudio()
	local podeModos=noStudio
	outrosModos.Visible=podeModos
	-- P2: a partir da 2ª expedição o jogador escolhe como começar (a 1ª é sempre "aprender na vila").
	texto(modos,"TituloModos","COMO COMEÇAR A EXPEDIÇÃO",26,13,ouro)
	for _,modo in Abertura.MODOS do
		botao(modos,"Modo_"..modo.id,modo.titulo,modo.descricao,function() Fluxo.iniciarRun(modo.id) end,modo.id=="semArvore")
	end
	botao(jogar,"Escolher","Personagens prontos da mesa",nil,function() escolha.abrir(function() fundo.Visible=true end) end)
	-- Sair da partida: encerra o seu treino ou desiste da luta/duelo (o servidor decide).
	local sairPartida=botao(home,"SairPartida","Sair da partida",nil,function()
		state.send("sairPartida",{}); fundo.Visible=false
	end); sairPartida.Visible=false
	local adm=botao(ajustes,"Administracao","Administração",nil,admin.abrir); adm.Visible=false
	texto(jogar,"TituloModo","OUTROS MODOS · MESA",26,13,ouro)
	botao(jogar,"Treinar","01   Campo de treino","Pratique suas habilidades contra bonecos.",function() pedir("iniciarTreino") end)
	botao(jogar,"Lutar","02   Desafios","Três níveis. Até quatro aventureiros.",function() abrir("Desafios") end,true)
	botao(jogar,"Duelo","03   PvP por equipes","Monte os lados ou jogue cada um por si.",function() abrir("PvP") end)
	botao(jogar,"PrepararGrupo","Entrar no grupo",nil,function() pedir("entrarFila",{modo="luta"}) end)
	local sair=botao(jogar,"SairFila","Sair da fila",nil,function() pedir("entrarFila",{modo="sair"}) end); sair.Visible=false
	texto(desafios,"TituloDesafio","DESAFIOS · 1–4 JOGADORES",26,13,ouro)
	botao(desafios,"Grupo","Entrar no grupo",nil,function() pedir("entrarFila",{modo="luta"}) end)
	botao(desafios,"Nivel1","Nível 1 · Expedição","Normal · Goblins e lobos do caminho.",function() pedir("iniciarLuta",{nivel=1}) end)
	botao(desafios,"Nivel2","Nível 2 · Presas vermelhas","Difícil · Um urso e seu bando.",function() pedir("iniciarLuta",{nivel=2}) end)
	botao(desafios,"Nivel3","Nível 3 · Treant Ancião","Chefão · Entre na floresta desperta.",function() pedir("iniciarLuta",{nivel=3}) end,true)
	texto(pvp,"TituloPvp","ESCOLHA SEU LADO",26,13,ouro)
	local ladoAtual=texto(pvp,"SeuLado","Sem equipe",26,16,ouro)
	for _,e in {1,2,0} do
		botao(pvp,"Equipe"..e,if e==0 then "Sem equipe · cada um por si" else "Equipe "..e,nil,function() pedir("entrarFila",{modo="duelo",equipe=e}) end)
	end
	local listas={}
	for i,nomeLado in {"Sem equipe","Equipe 1","Equipe 2"} do
		listas[i]=texto(pvp,"Lado"..(i-1),nomeLado.." · vazio",40,14,T.cores.secundario)
		listas[i].AutomaticSize=Enum.AutomaticSize.Y
	end
	botao(pvp,"Comecar","Começar PvP","Vence o último lado de pé.",function() pedir("iniciarDuelo") end,true)
	botao(pvp,"SairPvp","Sair da fila",nil,function() pedir("entrarFila",{modo="sair"}) end)
	local volume; local niveis={0,.35,.7,1}
	local function atualizarVolume() volume.Rotulo.Text="Volume dos efeitos   ·   "..math.floor(Som.volume()*100+.5).."%" end
	volume=botao(ajustes,"Volume","",nil,function()
		local proximo=0; for _,n in niveis do if n>Som.volume()+.01 then proximo=n; break end end
		Som.volume(proximo); atualizarVolume()
	end); atualizarVolume()
	local movimento
	movimento=botao(ajustes,"Movimento","Animações   ·   completas",nil,function()
		FX.reduzir(not FX.reduzidos); movimento.Rotulo.Text="Animações   ·   "..(if FX.reduzidos then "reduzidas" else "completas")
	end)
	texto(ajustes,"Nota","Suas preferências valem nesta sessão.",36,14,T.cores.secundario)
	local orientacao; orientacao=botao(ajustes,"Orientacao","Marcadores no mundo   ·   ligados",nil,function()
		FX.orientacao=FX.orientacao==false; orientacao.Rotulo.Text="Marcadores no mundo   ·   "..(if FX.orientacao then "ligados" else "desligados")
	end)
	local passos={}
	for _,p in AjudaConteudo.abas[1].paragrafos do table.insert(passos,p) end
	local guia=texto(ajuda,"Guia",AjudaConteudo.abas[1].titulo:upper().."\n\n"..table.concat(passos,"\n\n"),300,16,T.cores.secundario); guia.AutomaticSize=Enum.AutomaticSize.Y
	botao(ajuda,"ReverAbertura","Rever abertura",nil,function() Fluxo.rever() end)
	for _,p in {jogar,ajustes,ajuda,desafios,pvp,modos} do
		local voltar=botao(p,"Voltar","‹   Voltar",nil,function() abrir("Inicio") end)
		voltar.LayoutOrder=10000
	end
	
	abrir("Inicio")
	-- O botão MENU mora na barra de atalhos; a barra some enquanto o menu está aberto.
	Atalhos.criar({nome="MENU",rotulo="MENU",icone="menu",aoClicar=function() abrir("Inicio"); fundo.Visible=true end})
	Atalhos.ocultar("menu",fundo.Visible)
	fundo:GetPropertyChangedSignal("Visible"):Connect(function() Atalhos.ocultar("menu",fundo.Visible) end)
	-- As ferramentas da mesa continuam acessíveis por um submenu (só Studio/administrador).
	local registro=botao(ajustes,"Registro","Registro da mesa",nil,function() fundo.Visible=false; pg.MesaPanel.Enabled=true end)
	registro.Visible=podeModos
	-- Botão X no canto do painel (fecha sem efeito colateral).
	local fechar=C.botao({parent=moldura.Conteudo,nome="Fechar",texto="",variante="secundario",
		tamanho=UDim2.fromOffset(44,44),posicao=UDim2.fromScale(1,0),ancora=Vector2.new(1,0),aoClicar=fecharMenu})
	fechar.ZIndex=9
	fechar.Rotulo.Text,fechar.Rotulo.Position,fechar.Rotulo.Size=T.icone("fechar"),UDim2.new(),UDim2.fromScale(1,1)
	fechar.Rotulo.TextWrapped,fechar.Rotulo.ZIndex=false,10
	-- Esc abre e fecha (o menu do Roblox também responde a Esc); B do controle fecha.
	UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode==Enum.KeyCode.Escape then
			if fundo.Visible then fecharMenu()
			elseif Atalhos.livre() then abrir("Inicio"); fundo.Visible=true end
		elseif input.KeyCode==Enum.KeyCode.ButtonB and fundo.Visible then
			fecharMenu()
		end
	end)
	state.onLog(function(e) if e.tone=="erro" then status.Text=e.text or e.message or "Pedido recusado." end end)
	state.onSnapshot(function(s)
		snap=s
		local sala=s.sala or {}
		ladoAtual.Text=if sala.equipe and sala.equipe>0 then "Seu lado · Equipe "..sala.equipe else "Seu lado · Sem equipe"
		for i,l in listas do
			local nomes={}
			for _,id in (sala.lados or {})[i] or {} do
				local p=Players:GetPlayerByUserId(id)
				table.insert(nomes,if p then p.DisplayName else "Jogador "..id)
			end
			l.Text=(if i==1 then "Sem equipe" else "Equipe "..(i-1)).." · "..(if #nomes==0 then "vazio" else table.concat(nomes,", "))
		end
		status.Text=if s.combat.active then "Uma partida está em andamento. Entre para acompanhar."
			elseif sala.suaFila then string.format("Na fila · %s   /   Grupo %d   /   Duelo %d",sala.suaFila,sala.luta or 0,sala.duelo or 0)
			else "Sua próxima aventura começa aqui."
		sair.Visible=not s.combat.active and sala.suaFila~=nil; adm.Visible=s.you.admin==true
		podeModos=noStudio or s.you.admin==true
		outrosModos.Visible,registro.Visible=podeModos,podeModos
		local minha=false
		for _,t in s.tokens do if t.ownerUserId==state.localUserId() and not t.derrotado then minha=true; break end end
		sairPartida.Visible=s.combat.active and minha
		-- Só fecha o menu quando a SUA partida começa; depois o botão MENU continua abrindo.
		if s.combat.active and minha and not estavaNaPartida then fundo.Visible=false; state.setTableView(true) end
		estavaNaPartida=s.combat.active and minha
	end)
	return {
		abrir=function() abrir("Inicio"); fundo.Visible=true end,
		abrirJogar=function() abrir(if podeModos then "Jogar" else "Inicio"); fundo.Visible=true end,
		-- P2: usados pelo AberturaFluxo (cena, assistente de criação, expedição).
		esconder=function() fundo.Visible=false end,
		abrirModos=function() abrir("Modos"); fundo.Visible=true; status.Text="Escolha como começar." end,
		aviso=function(t) fundo.Visible=true; abrir("Inicio"); status.Text=t end,
	}
end
return Inicio
