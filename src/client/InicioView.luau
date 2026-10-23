-- Menu por páginas; pedidos continuam sujeitos à confirmação do servidor.
local Players = game:GetService("Players")
local Extra = require(script.Parent.UI.ExtraEntrada)
local T, C = Extra.T, Extra.C
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalogo = require(ReplicatedStorage.Shared.Livro.Catalogo)
local Som = require(script.Parent.Sonorizacao)
local FX = require(script.Parent.MenuEfeitos)
local Fluxo = require(script.Parent.AberturaFluxo)
local Abertura = require(ReplicatedStorage.Shared.Regras.AberturaRun)
local AjudaConteudo = require(ReplicatedStorage.Shared.AjudaConteudo)
local Inicio = {}
function Inicio.start(state, escolha, admin, criacao, encontroAutonomo)
	local pg=Players.LocalPlayer:WaitForChild("PlayerGui")
	pg:WaitForChild("MesaPanel").Enabled=false
	local ouro=T.cores.ouro
	local function criar(class,parent,props)
		local o=Instance.new(class); for k,v in props do o[k]=v end; o.Parent=parent; Extra.estilizar(o, props.FontFace); return o
	end
	local function canto(o,r) criar("UICorner",o,{CornerRadius=UDim.new(0,T.raios.botao)}) end
	local gui=criar("ScreenGui",pg,{Name="InicioJogo",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=20,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
	-- Vinheta transparente: o mundo permanece visível à direita do menu.
	local fundo=criar("Frame",gui,{Name="MenuInicial",Size=UDim2.fromScale(1,1),BackgroundColor3=T.cores.painel,BackgroundTransparency=.35,BorderSizePixel=0,Active=true})
	criar("UIGradient",fundo,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,.85)}),Rotation=0})
	local moldura=C.painel({parent=fundo,nome="Entrada",losangos=true,padding=16,
		tamanho=UDim2.new(.48,0,.92,0),posicao=UDim2.new(.05,0,.04,0)})
	local painel=criar("ScrollingFrame",moldura.Conteudo,{Name="Conteudo",Size=UDim2.new(1,0,1,-28),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
	Extra.rolagem(painel)
	criar("UIListLayout",painel,{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})
	local indicacao=C.texto({parent=moldura.Conteudo,nome="IndicacaoRolagem",texto="Role para ver mais opções",secundario=true,posicao=UDim2.new(0,0,1,-24),tamanho=UDim2.new(1,0,0,24)})
	local function responsivo()
		local vp=workspace.CurrentCamera.ViewportSize
		local pequeno=vp.X<760
		moldura.Position=if pequeno then UDim2.new(.04,0,.03,0) else UDim2.new(.05,0,.04,0)
		moldura.Size=if pequeno then UDim2.new(.92,0,.94,0) else UDim2.new(.48,0,.92,0)
		indicacao.Visible=painel.AbsoluteCanvasSize.Y>painel.AbsoluteSize.Y+1
		indicacao.Text=if painel.CanvasPosition.Y+painel.AbsoluteSize.Y>=painel.AbsoluteCanvasSize.Y-2 then "Início acima · role para voltar" else "Role para ver mais opções"
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(responsivo)
	painel:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(responsivo)
	painel:GetPropertyChangedSignal("CanvasPosition"):Connect(responsivo)
	task.defer(responsivo)
	local ordem=0
	local function texto(parent,nome,t,altura,tamanho,cor)
		ordem+=1
		return criar("TextLabel",parent,{Name=nome,Text=t,LayoutOrder=ordem,Size=UDim2.new(1,0,0,altura),BackgroundTransparency=1,TextColor3=cor or T.cores.texto,TextSize=tamanho or 16,FontFace=T.fontes.rotulo,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
	end
	texto(painel,"Edicao","CRÔNICAS DE UMA NOVA VIDA",22,13,ouro)
	local titulo=texto(painel,"Titulo","Moshoku",58,48); titulo.FontFace=T.fontes.titulo
	texto(painel,"Subtitulo","Cada turno escreve a sua história.",30,17,T.cores.secundario)
	local fio=Extra.ornamento(painel); fio.LayoutOrder=4
	ordem=4
	local personagem=texto(painel,"PersonagemAtual","Sem personagem ainda",28,16,ouro)
	local status=texto(painel,"EstadoSala","Aguarde o servidor.",40,15,T.cores.secundario)
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
			tamanho=UDim2.new(1,0,0,if sub then 96 else 48),aoClicar=fn})
		if sub then
			b.Rotulo.Position=UDim2.fromOffset(12,8); b.Rotulo.Size=UDim2.new(1,-24,0,28); b.Rotulo.TextXAlignment=Enum.TextXAlignment.Left
			local d=C.texto({parent=b,nome="Descricao",texto=sub,posicao=UDim2.fromOffset(12,38),tamanho=UDim2.new(1,-24,0,50)})
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
	task.spawn(function()
		remoteRun=ReplicatedStorage:WaitForChild("RunJogo")
		remoteRun.OnClientEvent:Connect(function(tipo,dado)
			if tipo~="run" or type(dado)~="table" or dado.erro then return end
			runAtiva=not dado.semRun and not dado.fim
			local principal=home:FindFirstChild("Expedicao")
			if principal then principal.Rotulo.Text=if runAtiva then "Continuar" else "Nova expedição" end
		end)
		remoteRun:FireServer({acao="consultar"})
	end)
	botao(home,"Expedicao","Nova expedição","Explore o mundo a pé, fale com os mestres e enfrente o que encontrar.",function()
		status.Text="Preparando a expedição…"
		Fluxo.novaExpedicao()
	end,true)
	botao(home,"Personagem","Personagem","Montar ficha e personalizar aparência.",function()
		if criacao then fundo.Visible=false; criacao.abrir(function() fundo.Visible=true end)
		else escolha.abrir(function() fundo.Visible=true end) end
	end)
	botao(home,"Ajuda","Como jogar",nil,function() abrir("Ajuda") end)
	botao(home,"Ajustes","Ajustes",nil,function() abrir("Ajustes") end)
	botao(home,"OutrosModos","Outros modos",nil,function() abrir("Jogar") end)
	-- P2: a partir da 2ª expedição o jogador escolhe como começar (a 1ª é sempre "aprender na vila").
	texto(modos,"TituloModos","COMO COMEÇAR A EXPEDIÇÃO",26,13,ouro)
	for _,modo in Abertura.MODOS do
		botao(modos,"Modo_"..modo.id,modo.titulo,modo.descricao,function() Fluxo.iniciarRun(modo.id) end,modo.id=="semArvore")
	end
	botao(jogar,"Escolher","Personagens prontos da mesa",nil,function() escolha.abrir(function() fundo.Visible=true end) end)
	-- Sair da partida: encerra o seu treino ou desiste da luta/duelo (o servidor decide).
	local sairPartida=botao(home,"SairPartida","Sair da partida","Encerra o seu treino ou desiste desta luta.",function()
		state.send("sairPartida",{}); fundo.Visible=false
	end); sairPartida.Visible=false
	local continuar=botao(home,"Continuar","Explorar o mundo",nil,function() fundo.Visible=false; if snap and snap.combat.active then state.setTableView(true) end end)
	local adm=botao(ajustes,"Administracao","Administração",nil,admin.abrir); adm.Visible=false
	texto(jogar,"TituloModo","OUTROS MODOS · MESA",26,13,ouro)
	botao(jogar,"Treinar","01   Campo de treino","Pratique suas habilidades contra bonecos.",function() pedir("iniciarTreino") end)
	local inicioAutonomoPendente=false
	if encontroAutonomo then
		local pedidoFilaPendente=false
		local botaoInicio=nil
		local botaoFila=botao(jogar,"GrupoAutonomo","Entrar no grupo","Junte-se voluntariamente a até três outros jogadores.",function()
			local fila=encontroAutonomo.fila()
			local presente=false
			for _,membro in ipairs(fila.jogadores or {}) do if membro.userId==state.localUserId() then presente=true;break end end
			pedidoFilaPendente=true
			if not encontroAutonomo.alterarFila(not presente) then
				pedidoFilaPendente=false
				status.Text="Não foi possível alterar o grupo agora."
			end
		end)
		local function atualizarFila(fila)
			local membros=fila.jogadores or {}
			local presente=false
			for _,membro in ipairs(membros) do if membro.userId==state.localUserId() then presente=true;break end end
			local lider=presente and fila.liderUserId==state.localUserId()
			botaoFila.Rotulo.Text=if presente then "Sair do grupo"..(if lider then " · líder" else "").." · "..tostring(#membros).."/4" else "Entrar no grupo · "..tostring(#membros).."/4"
			botaoFila.Descricao.Text=if presente
				then (if lider then "Você pode iniciar a expedição para o grupo." else "Aguardando a pessoa que lidera a fila.")
				else "Junte-se voluntariamente a até três outros jogadores."
			if botaoInicio then
				botaoInicio.Descricao.Text=if not presente then "Solo ou entre na fila para cooperar."
					elseif lider then "Você lidera · encontro com até quatro jogadores."
					else "Aguardando a liderança iniciar a expedição."
				botaoInicio.Active=not presente or lider
			end
			if pedidoFilaPendente then
				pedidoFilaPendente=false
				status.Text=if presente then "Você entrou no grupo. Quem criou o grupo pode iniciar." else "Você saiu do grupo."
			end
		end
		encontroAutonomo.onRecusado(function(mensagem)
			if pedidoFilaPendente then pedidoFilaPendente=false;status.Text=mensagem or "Não foi possível alterar o grupo." end
		end)
		botaoInicio=botao(jogar,"EncontroAutonomo","Encontro autônomo","Solo ou entre na fila para cooperar.",function()
			inicioAutonomoPendente=true
			status.Text="Preparando seu encontro…"
			if not encontroAutonomo.iniciar() then
				inicioAutonomoPendente=false
				status.Text="Não foi possível iniciar agora. Confira se já está em uma partida."
			end
		end,true)
		encontroAutonomo.onFila(atualizarFila)
		encontroAutonomo.onRecusado(function(mensagem)
			if not inicioAutonomoPendente then return end
			inicioAutonomoPendente=false
			status.Text=mensagem or "Encontro recusado."
		end)
		encontroAutonomo.onEstado(function()
			if inicioAutonomoPendente then
				inicioAutonomoPendente=false
				status.Text="Encontro iniciado."
			end
		end)
	end
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
	local guia=texto(ajuda,"Guia","PRIMEIROS PASSOS\n\n"..table.concat(passos,"\n\n"),300,16,T.cores.secundario); guia.AutomaticSize=Enum.AutomaticSize.Y
	botao(ajuda,"ReverAbertura","Rever abertura",nil,function() Fluxo.rever() end)
	for _,p in {jogar,ajustes,ajuda,desafios,pvp,modos} do
		local voltar=botao(p,"Voltar","‹   Voltar",nil,function() abrir("Inicio") end)
		voltar.LayoutOrder=10000
	end
	
	abrir("Inicio")
	-- Somente um atalho durante o jogo. Ferramentas ficam em um pequeno painel.
	local nav=criar("Frame",gui,{Name="Navegacao",Position=UDim2.fromOffset(16,66),Size=UDim2.fromOffset(132,44),BackgroundTransparency=1,Visible=false})
	local toggle=criar("TextButton",nav,{Name="MENU",Text="MENU",Size=UDim2.fromScale(1,1),BackgroundColor3=T.cores.painel,TextColor3=T.cores.texto,TextSize=15,FontFace=T.fontes.rotulo,BorderSizePixel=0}); canto(toggle,T.raios.botao)
	FX.botao(toggle,T.cores.painel,T.cores.painel)
	local function dimensionarNavegacao()
		local vp=workspace.CurrentCamera.ViewportSize
		local compacto=snap and snap.combat.active and (vp.X<700 or vp.Y<500)
		nav.Position=if compacto then UDim2.new(1,-60,0,70) else UDim2.fromOffset(16,66)
		nav.Size=UDim2.fromOffset(if compacto then 44 else 132,44)
		toggle.TextSize=if compacto then 12 else 15
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(dimensionarNavegacao)
	toggle.Activated:Connect(function() abrir("Inicio"); fundo.Visible=true end)
	-- As ferramentas da mesa continuam acessíveis por um submenu, sem barra extra.
	botao(ajustes,"Registro","Registro da mesa",nil,function() fundo.Visible=false; pg.MesaPanel.Enabled=true end)
	fundo:GetPropertyChangedSignal("Visible"):Connect(function() nav.Visible=not fundo.Visible end)
	state.onLog(function(e) if e.tone=="erro" then status.Text=e.text or e.message or "Pedido recusado." end end)
	state.onSnapshot(function(s)
		snap=s
		dimensionarNavegacao()
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
		continuar.Rotulo.Text=if s.combat.active then "Voltar à partida / assistir" else "Explorar o mundo"
		local minha=false
		for _,t in s.tokens do if t.ownerUserId==state.localUserId() and not t.derrotado then minha=true; break end end
		sairPartida.Visible=s.combat.active and minha
		-- Só fecha o menu quando a SUA partida começa; depois o botão MENU continua abrindo.
		if s.combat.active and minha and not estavaNaPartida then fundo.Visible=false; state.setTableView(true) end
		estavaNaPartida=s.combat.active and minha
	end)
	return {
		abrir=function() abrir("Inicio"); fundo.Visible=true end,
		abrirJogar=function() abrir("Jogar"); fundo.Visible=true end,
		-- P2: usados pelo AberturaFluxo (cena, assistente de criação, expedição).
		esconder=function() fundo.Visible=false end,
		abrirModos=function() abrir("Modos"); fundo.Visible=true; status.Text="Escolha como começar." end,
		aviso=function(t) fundo.Visible=true; abrir("Inicio"); status.Text=t end,
	}
end
return Inicio
