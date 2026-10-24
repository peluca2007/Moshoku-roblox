local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Gui=game:GetService("GuiService")
local RS=game:GetService("ReplicatedStorage")
local Personagens=require(RS.Shared.PersonagensProntos)
local E=require(RS.Shared.SalaEspaco)
local Placar=require(RS.Shared.ApresentacaoBrotos)
local Fichas=require(RS.Shared.SalaFichas)
local O=require(script.Parent.SalaObjetos)
local modoCamera=require(script.Parent.ModoCamera)
local mundo=require(script.Parent.CameraMundo) -- câmera do mundo: pausa/retoma e dona do mouse fora da sala
local Movimento=require(script.Parent.BloqueioMovimento)
local V={}
function V.start(state)
	local player=Players.LocalPlayer;local pg=player:WaitForChild("PlayerGui")
	local pasta=Instance.new("Folder");pasta.Name="SalaObjetosLocais";pasta.Parent=workspace
	local papeis={}
	local rotulos={};local prontoConfirmado=false
	local function atualizarSelo()
		if rotulos.pronto then rotulos.pronto.Text=if prontoConfirmado then "✓ PRONTO\nInteraja para cancelar" else "PRONTO\nConfirme no selo" end
	end
	for i,f in Personagens do
		local cf=CFrame.new(246.5+((i-1)%2)*7,3.73,3.6+math.floor((i-1)/2)*.55)*CFrame.Angles(math.pi/2,0,math.rad((i%3-1)*6))
		local p,g=O.papel(pasta,"Ficha_"..f.id,cf);p.Size=Vector3.new(2.2,2.8,.025);p:SetAttribute("SalaObjeto","ficha");p:SetAttribute("FichaId",f.id)
		O.texto(g,f.nome,UDim2.fromScale(.06,.07),UDim2.fromScale(.9,.5),65)
		O.texto(g,"PERSONAGEM\nPegue para consultar",UDim2.fromScale(.06,.6),UDim2.fromScale(.9,.35),34);papeis[i]=p
	end
	local dados=O.dados(pasta)
	local soltos=O.soltos(pasta)
	local atalho,gAtalho=O.papel(pasta,"PilhaDeFichas",CFrame.new(253.8,3.72,-9.3)*CFrame.Angles(math.pi/2,0,.12))
	atalho:SetAttribute("SalaObjeto","tabuleiro")
	O.texto(gAtalho,"PREPARAR PARTIDA\n\nModo • participantes\nVer o que falta",UDim2.fromScale(.08,.08),UDim2.fromScale(.84,.85),58)
	task.spawn(function()
		local world=workspace:WaitForChild("SalaRPG",20);if not world then return end
		for _,p in world:GetChildren() do
			local acao=p:GetAttribute("SalaObjeto")
			local titulos={mestre="MOSHOKU\nPreparar a sessão",livro="CADERNO",ajustes="AJUSTES",assumir="ASSUMIR FICHA",admin="ADM",pronto="PRONTO",dados="LANÇAR",tabuleiro="MAPA DA SESSÃO"}
			if titulos[acao] and p.Name~="AbaEscudo" and not p.Name:find("Dado") and p.Name~="TabuleiroDaSala" then
				local face=if acao=="mestre" then Enum.NormalId.Front else Enum.NormalId.Top
				local superficie=if p.Name=="LivroDeAjustes" then world:FindFirstChild("CapaCaderno") or p else p
				local g=O.superficie(superficie,face,600,250);local l=O.texto(g,titulos[acao],UDim2.fromScale(.05,.16),UDim2.fromScale(.9,.7),48,Color3.fromRGB(245,228,190));l.TextXAlignment=Enum.TextXAlignment.Center
				rotulos[acao]=l;atualizarSelo()
			end
		end
	end)
	local paginas=require(script.Parent.SalaPaginas).start(pasta,state)
	local gui=Instance.new("ScreenGui");gui.Name="SalaConceitual";gui.ResetOnSpawn=false;gui.DisplayOrder=25;gui.Parent=pg
	local hint=O.texto(gui,"Entrando na sala…",UDim2.new(.5,0,1,-85),UDim2.new(.9,0,0,64),19,Color3.fromRGB(255,239,207));hint.AnchorPoint=Vector2.new(.5,0);hint.TextXAlignment=Enum.TextXAlignment.Center;hint.TextYAlignment=Enum.TextYAlignment.Center;hint.BackgroundColor3=Color3.fromRGB(34,28,24);hint.BackgroundTransparency=.15
	local max=Instance.new("UISizeConstraint");max.MaxSize=Vector2.new(700,64);max.Parent=hint

	local eleicao=require(script.Parent.SalaEleicaoView).new(gui,state)
	local papelPlacar,gPlacar=O.papel(pasta,"PlacarDaMesa",CFrame.new(250,3.77,5.1)*CFrame.Angles(math.pi/2,0,math.pi));papelPlacar.Size=Vector3.new(4.2,2.6,.025);papelPlacar:SetAttribute("SalaObjeto","placar")
	local placar=O.texto(gPlacar,"",UDim2.fromScale(.06,.07),UDim2.fromScale(.88,.86),40);placar.Name="PlacarBrotos"
	O.visivel(papelPlacar,false)

	local snap,sala,eu=nil,nil,nil
	local combateAnterior=nil
	local lobby=false;local foco=nil;local ultimaTrans=nil;local ultimoOlhar=0;local cameraPapel=nil;local erroAte=0;local tinhaTransicao=false;local ultimoPlacar=nil
	local corpo=require(script.Parent.SalaCorpo).new(pasta)
	local fisicos=require(script.Parent.SalaDadosControle).new(state)
	local direcaoInicial=false
	local olharCentrado=false
	local cursorLivre=false
	local ultimoSocial,ultimaEleicao=nil,nil
	local toqueAnterior=nil
	local function suspenderToque(bloquear)
		if bloquear then
			if toqueAnterior==nil then toqueAnterior=Gui.TouchControlsEnabled end
			Gui.TouchControlsEnabled=false
		elseif toqueAnterior~=nil then Gui.TouchControlsEnabled=toqueAnterior;toqueAnterior=nil end
	end
	local function resultadoAberto()
		local resultado=pg:FindFirstChild("ResultadoPartida")
		local fundo=resultado and resultado:FindFirstChild("Fundo")
		return resultado~=nil and resultado.Enabled and fundo~=nil and fundo.Visible
	end

	local function procurar(posicao)
		local c=workspace.CurrentCamera;local mouse=UIS:GetMouseLocation();local ray
		if posicao then ray=c:ScreenPointToRay(posicao.X,posicao.Y) elseif UIS.MouseBehavior==Enum.MouseBehavior.LockCenter then ray=c:ViewportPointToRay(c.ViewportSize.X/2,c.ViewportSize.Y/2) else ray=c:ScreenPointToRay(mouse.X,mouse.Y) end
		local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={player.Character,paginas.part}
		local hit=workspace:Raycast(ray.Origin,ray.Direction*22,params)
		if not hit then return nil end
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart");if not root or (hit.Position-root.Position).Magnitude>12 then return nil end
		if hit.Instance:GetAttribute("SalaObjeto") then return hit.Instance end
		local char=hit.Instance:FindFirstAncestorOfClass("Model");local other=char and Players:GetPlayerFromCharacter(char)
		return other and other~=player and char:FindFirstChild("HumanoidRootPart") or nil
	end
	local function abrir(t)
		if not lobby or not eu or not eu.admitido then return end
		if t=="mestre" and sala.eleicao then eleicao.abrir();return end
		paginas.abrir(t,eu.ficha)
	end
	local function pronto() if lobby and eu and eu.admitido then state.send("salaPronto",{ativo=not eu.pronto}) end end
	local function interagir(objeto)
		foco=objeto
		if not lobby or resultadoAberto() or pg.AdminPanel.Enabled or paginas.congelar() or eleicao.congelar() or not foco or not eu or not eu.admitido then return end
		local acao=foco:GetAttribute("SalaObjeto")
		if acao=="dados" or acao=="jogador" then if not fisicos.ocupado() then paginas.fechar();fisicos.interagir(foco) end;return end
		if fisicos.ocupado() then return end
		if acao=="ficha" then paginas.abrir("ficha",foco:GetAttribute("FichaId"),foco:GetAttribute("PapelObjeto"))
		elseif acao=="livro" then paginas.abrir("livro",foco:GetAttribute("ObjetoId"),foco:GetAttribute("PapelObjeto"))
		elseif acao=="placar" then paginas.abrir("placar")
		elseif acao=="assumir" then paginas.assumir()
		elseif acao=="admin" then if snap.you.admin then paginas.fechar();pg.AdminPanel.Enabled=true end
		elseif acao=="mestre" or acao=="tabuleiro" then
			if sala.eleicao then eleicao.abrir();return end
			local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if acao=="mestre" and (not h or not h.SeatPart) then hint.Text="Sente-se à mesa para usar o escudo.";erroAte=os.clock()+4;return end
			paginas.abrir("mestre")
		elseif acao=="ajustes" then paginas.abrir("ajustes")
		elseif acao=="pronto" then state.send("salaPronto",{ativo=not eu.pronto})
		end
	end
	local interacoes=require(script.Parent.SalaInteracoes).new(pasta,interagir)
	local pegada=require(script.Parent.SalaPegada).new({pasta=pasta,pg=pg,state=state,procurar=procurar,
		pegar=function(objeto)
			if not objeto or paginas.congelar() then return nil end
			local acao=objeto:GetAttribute("SalaObjeto");interagir(objeto)
			if acao=="ficha" then return objeto:GetAttribute("FichaId") elseif acao=="livro" then return objeto:GetAttribute("ObjetoId") elseif acao=="dados" then return "dados-brotos" elseif acao=="jogador" then return "jogador:"..objeto:GetAttribute("SalaJogador") end
		end,
		apoiado=function() return paginas.congelar() end,
		acao=function(nome)
			if nome=="Arremessar" then return fisicos.lancar(.65,false) or paginas.lancar(.65,false) end
			if nome=="Soltar" then return fisicos.soltar() or paginas.lancar(0,true) end
			return paginas.acao(nome)
		end})
	local transicao=require(script.Parent.SalaTransicao).new(pg)
	UIS.InputBegan:Connect(function(input,processed)
		if processed or UIS:GetFocusedTextBox() or eleicao.congelar() or resultadoAberto() then return end
		if input.KeyCode==Enum.KeyCode.C then abrir("mestre")
		elseif input.KeyCode==Enum.KeyCode.P then pronto()
		elseif input.KeyCode==Enum.KeyCode.G and lobby then state.send("salaBrotos",{}) end
		if input.KeyCode==Enum.KeyCode.L and lobby then cursorLivre=not cursorLivre end
	end)
	state.onSnapshot(function(s)
		snap=s;sala=s.salaConceitual;eu=nil;for _,p in sala and sala.pessoas or {} do if p.id==player.UserId then eu=p end end
		local confirmado=eu~=nil and eu.pronto==true
		if lobby and confirmado~=prontoConfirmado then hint.Text=if confirmado then "Prontidão confirmada. Interaja no selo para cancelar." else "Prontidão desmarcada. Confirme no selo quando estiver pronto.";erroAte=os.clock()+3 end
		prontoConfirmado=confirmado;atualizarSelo()
		paginas.atualizar(s)
		local novo=sala~=nil and not s.combat.active
		if novo~=lobby then
			if not novo then
				Movimento.definir("consulta",false)
			end
			-- modoCamera antes do tabuleiro: ao sair, a câmera do mundo devolve o controle
			-- primeiro e só então o BoardView assume a câmera da mesa.
			lobby=novo;modoCamera.definir(novo);state.setTableView(not novo)
			direcaoInicial=novo
			if novo then workspace.CurrentCamera.CameraType=Enum.CameraType.Custom;local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid");if h then workspace.CurrentCamera.CameraSubject=h end
			else UIS.MouseBehavior=Enum.MouseBehavior.Default;UIS.MouseIconEnabled=true;suspenderToque(false);paginas.fechar(false);cameraPapel=nil;corpo.restaurar() end
		end
		if sala then
			local old=pg:FindFirstChild("InicioJogo")
			if old then
				-- O menu precisa continuar ativo para deixar o atalho MENU visível
				-- na sala inicial; por ele, jogadores sem ficha abrem a criação J1.
				old.Enabled=true
				if lobby and old:FindFirstChild("MenuInicial") then old.MenuInicial.Visible=false end
				if s.combat.active and combateAnterior==false then old.MenuInicial.Visible=false end
			end
			local sel=pg:FindFirstChild("EscolhaDePersonagem");if sel then sel.Enabled=false end
		end
		combateAnterior=s.combat.active==true
		gui.Enabled=lobby or (sala and sala.eleicao~=nil) or false
		soltos.atualizar(sala and sala.papeisSoltos,lobby)
		
		for _,p in papeis do O.visivel(p,lobby and Fichas.disponiveis(sala or {},p:GetAttribute("FichaId"))>0) end
		O.visivel(atalho,lobby)
		for _,d in dados do O.visivel(d.part,lobby) end
		local e=sala and sala.eleicao
		local br=sala and sala.brincadeiraBrotos

		eleicao.atualizar(e,eu~=nil and eu.admitido)
		local oferta=sala and (sala.ofertas[player.UserId] or sala.ofertas[tostring(player.UserId)])
		local mao=sala and (sala.maos[player.UserId] or sala.maos[tostring(player.UserId)])
		if oferta and oferta.id==mao and lobby and not paginas.aberto() and not eleicao.congelar() then paginas.abrir("ficha",oferta.id,nil,true) end
		if sala and sala.transicao and ultimaTrans~=sala.transicao.inicio then ultimaTrans=sala.transicao.inicio;paginas.fechar(false) end
		mundo.pausa("transicao-sala",sala~=nil and sala.transicao~=nil)
		if tinhaTransicao and not (sala and sala.transicao) and lobby and not mundo.ligada() then workspace.CurrentCamera.CameraType=Enum.CameraType.Custom end
		tinhaTransicao=sala and sala.transicao~=nil
		local social=br and br.fase=="resultado" and br.serial~=ultimoSocial and not e
		local eleitoral=sala and sala.ultimoBrotos
		local resultado=if social then br elseif eleitoral and eleitoral.evento~=ultimaEleicao then eleitoral else nil
		if resultado then
			if social then ultimoSocial=br.serial else ultimaEleicao=resultado.evento end
			local linhas=Placar.linhas(resultado,sala.pessoas,social)
			local chave=table.concat(linhas,"\n");if chave~=ultimoPlacar then ultimoPlacar=chave;placar.Text=chave;paginas.placar(linhas) end
		end
	end)
	-- AvisosJogo já apresenta recusas do servidor; aqui ficam apenas orientações locais.
	RunService:BindToRenderStep("SalaPrimeiraPessoa",Enum.RenderPriority.Camera.Value+3,function(dt)
		local camera=workspace.CurrentCamera
		eleicao.redimensionar()
		fisicos.atualizar(sala,lobby and eu and eu.admitido and not (sala and sala.transicao) and not paginas.congelar() and not eleicao.congelar() and not pg.AdminPanel.Enabled,dt)
		if not sala then Movimento.definir("consulta",false);suspenderToque(false);pegada.atualizar(false,nil,nil);return end
		local fimAberto=resultadoAberto()
		Movimento.definir("consulta",lobby and not fimAberto and (paginas.congelar() or eleicao.congelar() or pg.AdminPanel.Enabled))
		suspenderToque(lobby and (paginas.congelar() or eleicao.congelar() or pg.AdminPanel.Enabled or fimAberto))
		O.visivel(papelPlacar,lobby and ultimoPlacar~=nil)
		if lobby then
			local overlay=paginas.congelar() or eleicao.congelar() or pg.AdminPanel.Enabled or fimAberto
			-- A câmera do mundo cede enquanto a sobreposição congela a vista (e volta sozinha).
			mundo.pausa("sobreposicao-sala",overlay)
			soltos.animar(workspace:GetServerTimeNow())
			interacoes.atualizar(not overlay and not sala.transicao,eu and eu.admitido,snap.you.admin,prontoConfirmado)
			hint.Visible=os.clock()<erroAte or not eu or not eu.admitido
			local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if direcaoInicial and root and (root.Position-E.CENTRO).Magnitude<30 then camera.CFrame=CFrame.lookAt(camera.CFrame.Position,E.MESA+Vector3.new(0,1,0));direcaoInicial=false end
			foco=if overlay then nil else procurar()
			local oferta=sala.ofertas and (sala.ofertas[player.UserId] or sala.ofertas[tostring(player.UserId)])
			pegada.atualizar(eu~=nil and eu.admitido and not sala.transicao and not eleicao.congelar() and not pg.AdminPanel.Enabled and not fimAberto,sala.maos[player.UserId] or sala.maos[tostring(player.UserId)],foco,oferta)
			if os.clock()>=erroAte and (not eu or not eu.admitido) then hint.Text="Aguardando autorização do mestre • seis vagas, até dez com autorização" end
			if overlay then
				if not cameraPapel then cameraPapel=camera.CFrame end
				camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=cameraPapel;UIS.MouseBehavior=Enum.MouseBehavior.Default;UIS.MouseIconEnabled=true
			elseif mundo.ligada() then
				-- No mundo a CameraMundo é dona do CameraType e o mouse fica livre.
				cameraPapel=nil
				UIS.MouseBehavior=Enum.MouseBehavior.Default;UIS.MouseIconEnabled=true
			else
				if cameraPapel then cameraPapel=nil;camera.CameraType=Enum.CameraType.Custom end
				camera.CameraType=Enum.CameraType.Custom
				UIS.MouseBehavior=if cursorLivre then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter;UIS.MouseIconEnabled=cursorLivre
			end
			if sala.transicao then
				local t=math.clamp((workspace:GetServerTimeNow()-sala.transicao.inicio)/2.4,0,1)
				for i,d in dados do d.part.CFrame=d.base*CFrame.new(0,math.sin(t*math.pi)*.8,0)*(if t<.7 then CFrame.Angles(t*30+i,t*21,0) else d.rotacao(sala.transicao.dados[i]));d.label.Text=t<.7 and "?" or tostring(sala.transicao.dados[i]) end
			else
				-- Brotos físico já mostra os resultados; a bandeja permanece estável.
				for _,d in dados do d.part.CFrame=d.base;d.label.Text="1" end
			end
			paginas.posicionar(camera,dt)
			if os.clock()-ultimoOlhar>.35 and eu and eu.admitido and not paginas.congelar() then
				ultimoOlhar=os.clock();local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and mundo.ligada() then
					-- A vista alta do mundo não é olhar: avisa a cabeça reta uma vez.
					if not olharCentrado then olharCentrado=true;state.send("salaOlhar",{x=0,y=0}) end
				elseif root then
					olharCentrado=false
					local v=root.CFrame:VectorToObjectSpace(camera.CFrame.LookVector);state.send("salaOlhar",{x=math.clamp(math.asin(v.Y),-1.3,1.3),y=math.clamp(math.atan2(-v.X,-v.Z),-1.6,1.6)})
				end
			end
		end
		if lobby then
			-- Fora da sala o avatar fica inteiro (cabeça visível, sem braços de leitura).
			if mundo.ligada() then corpo.restaurar() else corpo.atualizar(sala,dt,paginas.papel()) end
		else
			UIS.MouseBehavior=Enum.MouseBehavior.Default;UIS.MouseIconEnabled=true
			interacoes.atualizar(false,false,false);pegada.atualizar(false,nil,nil)
		end
		transicao.atualizar(sala.transicao,lobby and not mundo.ligada(),camera)
	end)
	return {abrirFicha=function(id) paginas.abrir("ficha",id) end,abrirMestre=function() paginas.abrir("mestre") end,
		abrirPreparacao=function() if sala then paginas.abrir("mestre") end end}
end
return V
