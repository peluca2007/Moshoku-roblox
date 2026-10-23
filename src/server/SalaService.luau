local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Regras=require(RS.Shared.SalaRegras)
local Personagens=require(RS.Shared.PersonagensProntos)
local Armas=require(RS.Shared.Regras.Armas)
local Fichas=require(RS.Shared.SalaFichas)
local Sala={}
function Sala.start(deps)
	local validos={};for _,p in Personagens do validos[p.id]=true end
	local livros=require(RS.Shared.SalaItens).livros
	local regras=Regras.new(validos);local s=regras.estado
	local handlers=deps.handlers;local escolher=handlers.escolherPersonagem
	local iniciando,transicao=false,nil
	local maos,ofertas={},{}
	local recreativo=require(RS.Shared.BrotosRecreativo).new()
	local function teste() return RunService:IsStudio() and workspace:GetAttribute("MoshokuTesteMestre")==true end
	local function agora() return workspace:GetServerTimeNow() end
	local function inteiro(a,b) return deps.random:NextInteger(a,b) end
	local function jogador(id) return Players:GetPlayerByUserId(id) end
	local function permitido(p)
		local eu=s.pessoas[p.UserId]
		if deps.combat.active or iniciando or not eu or not eu.admitido then return "Objetos só podem ser usados na sala, antes de começar." end
		return nil
	end
	local function maoLivre(p)
		local e=permitido(p);if e then return e end
		local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and root:GetAttribute("CarregadoPor") then return "Pule para se soltar antes de pegar objetos." end
		return nil
	end
	local papeis=require(script.Parent.SalaPapeis).new({maos=maos,permitido=maoLivre,agora=agora})
	local entrega=require(script.Parent.SalaEntrega).new({maos=maos,ofertas=ofertas,fichas=validos,jogador=jogador,permitido=maoLivre,agora=agora})
	local carregar=require(script.Parent.SalaCarregarJogadores).new({maos=maos,permitido=permitido,agora=agora,jogador=jogador,mudou=deps.mudou})
	local dados=require(script.Parent.SalaDados).new({maos=maos,permitido=maoLivre,agora=agora,mudou=deps.mudou,jogadores=function() return Players:GetPlayers() end,rolar=function(p)
		local contexto=s.eleicao or recreativo.publico();local eleicao=s.eleicao~=nil
		if contexto and (eleicao or contexto.fase=="rolagem") then
			local participante=if eleicao then contexto.candidatos[p.UserId] else contexto.participantes[p.UserId]
			if contexto.fase~="rolagem" or not participante or contexto.dados[p.UserId] then return nil,"Você não tem uma rolagem pendente." end
		else contexto=nil end
		local valores={inteiro(1,6),inteiro(1,6),inteiro(1,6)}
		if not contexto then return valores end
		return valores,nil,function()
			if (if eleicao then s.eleicao else recreativo.publico())~=contexto or contexto.dados[p.UserId] then return end
			local i=0;local function fixo() i+=1;return valores[i] end
			if eleicao then regras.rolar(p.UserId,fixo) else recreativo.rolar(p.UserId,fixo) end
		end
	end})
	handlers.salaDadosPegar=dados.pegar;handlers.salaDadosLancar=dados.lancar;handlers.salaCarregar=carregar.aplicar
	RunService.Heartbeat:Connect(function(dt) dados.atualizar(dt);carregar.atualizar() end)
	local function personagem(char) dados.personagem(char) end
	for _,p in Players:GetPlayers() do p.CharacterAdded:Connect(personagem) end
	Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(personagem) end)
	local function rodada()
		if deps.combat.active or iniciando or s.eleicao then return "Espere a partida ou a escolha de mestre terminar." end
		local ids={};for _,id in s.ordem do if s.pessoas[id].admitido then table.insert(ids,id) end end
		return recreativo.abrir(ids,agora())
	end
	handlers.salaBrotosAbrir=function(p)
		local e=permitido(p);if e then return e end
		if p.UserId~=s.mestre then return "Só o mestre abre uma rodada para todos." end
		return rodada()
	end
	handlers.salaBrotos=function(p)
		local e=permitido(p);if e then return e end
		if dados.pendente(p.UserId) then return "Espere seus dados caírem." end
		e=recreativo.rolar(p.UserId,inteiro);if not e and not dados.pendentes() then recreativo.atualizar(agora(),inteiro) end;return e
	end
	handlers.salaArremessar=function(p,d)
		local e=papeis.arremessar(p,d);if not e then ofertas[p.UserId]=nil end;return e
	end
	handlers.salaArrumar=function(p)
		local e=permitido(p);if e then return e end
		if p.UserId~=s.mestre then return "Só o mestre recolhe todos os papéis." end
		papeis.arrumar();dados.arrumar();carregar.arrumar();return nil
	end
	local function aplicar(p,acao,d)
		if iniciando then return "Aguarde os dados terminarem de rolar." end
		return regras.aplicar(p.UserId,acao,d,agora(),deps.combat.active)
	end
	handlers.escolherPersonagem=function(p,d,m)
		if teste() then return escolher(p,d,m) end
		if type(d)=="table" and d.id=="personagem-pessoal" then
			local erro=permitido(p);if erro then return erro end
			-- A ficha J1 não participa da seleção nem das regras da mesa; o handler
			-- de encontro valida o marcador, o perfil do próprio UserId e os campos.
			return escolher(p,d,m)
		end
		local arma,e=Armas.validar(d);if not arma then return e end
		local erro=aplicar(p,"escolher",d);if erro then return erro end
		return escolher(p,d,m)
	end
	for comando,acao in {salaPronto="pronto",salaConfigurar="configurar",salaEquipe="equipe",salaCopia="copia",salaAdmitir="admitir",salaTransferir="transferir",salaCandidatar="candidatar"} do
		handlers[comando]=function(p,d) return aplicar(p,acao,d) end
	end
	handlers.salaRolar=function(p) if dados.pendente(p.UserId) then return "Espere seus dados caírem." end;local e=regras.rolar(p.UserId,inteiro);if not e and not dados.pendentes() then regras.atualizar(agora(),inteiro) end;return e end
	handlers.salaPapel=function(p,d)
		local e=maoLivre(p);if e then return e end
		if d.id==false then maos[p.UserId]=nil;ofertas[p.UserId]=nil;return nil end
		if maos[p.UserId]=="dados-brotos" or (type(maos[p.UserId])=="string" and maos[p.UserId]:sub(1,8)=="jogador:") then return "Solte o objeto antes de pegar um papel." end
		if type(d.id)~="string" or not (validos[d.id] or livros[d.id]) then return "Objeto inválido." end
		local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position-Vector3.new(250,3,0)).Magnitude>24 then return "Aproxime-se da mesa para pegar objetos." end
		if d.objeto~=nil then
			if type(d.objeto)~="number" or d.objeto%1~=0 or d.para~=nil then return "Objeto inválido." end
			local falha=papeis.recolher(p,d.id,d.objeto);if falha then return falha end
		end
		if d.para~=nil then
			return entrega.entregar(p,d.id,d.para)
		else
			if validos[d.id] and d.objeto==nil and Fichas.disponiveis({copias=s.copias,maos=maos,papeisSoltos=papeis.publico()},d.id,p.UserId)==0 then
				return "Essa ficha já está em uso. Peça a entrega do papel ou uma cópia ao mestre."
			end
			maos[p.UserId]=d.id;ofertas[p.UserId]=nil
		end
		return nil
	end
	handlers.salaOlhar=function(p,d)
		if deps.combat.active then return nil end
		local eu=s.pessoas[p.UserId];local c=p.Character
		if not eu or not eu.admitido or not c then return nil end
		local x,y=d.x,d.y
		if type(x)~="number" or type(y)~="number" or x~=x or y~=y or math.abs(x)>1.3 or math.abs(y)>1.6 then return "Olhar inválido." end
		c:SetAttribute("SalaOlharX",x);c:SetAttribute("SalaOlharY",y);return nil
	end
	local function sentado(p)
		local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		return h and h.SeatPart and h.SeatPart:GetAttribute("LugarSala")~=nil
	end
	local configurar=handlers.salaConfigurar
	handlers.salaConfigurar=function(p,d)
		if not sentado(p) then return "Sente-se à mesa para preparar a sessão." end
		return configurar(p,d)
	end
	handlers.salaIniciar=function(p)
		if not sentado(p) then return "Sente-se à mesa e use o escudo para começar." end
		if iniciando or deps.combat.active then return "Já existe uma partida começando ou em andamento." end
		local br=recreativo.publico();if br and br.fase=="rolagem" then return "Espere a rodada do Brotos terminar." end
		local grupo,e=regras.podeIniciar(p.UserId);if not grupo then return e end
		iniciando=true
		carregar.arrumar();dados.arrumar()
		table.clear(maos);table.clear(ofertas)
		local versao,dono=s.versao,s.mestre
		transicao={inicio=agora(),dados={inteiro(1,6),inteiro(1,6),inteiro(1,6)}}
		task.delay(2.4,function()
			local atuais=regras.podeIniciar(dono)
			if versao~=s.versao or s.mestre~=dono or not jogador(dono) or not atuais or deps.combat.active then
				iniciando=false;transicao=nil;deps.mudou();return
			end
			for _,other in Players:GetPlayers() do
				local falha=handlers.entrarFila(other,{modo="sair"},true)
				if not falha and table.find(atuais,other.UserId) then
					local pedido={modo=if s.modo=="duelo" then "duelo" else "luta"}
					if s.modo=="duelo" then pedido.equipe=s.pessoas[other.UserId].equipe end
					falha=handlers.entrarFila(other,pedido,true)
				end
				if falha then
					deps.logTo(p,"Não foi possível incluir "..other.DisplayName..": "..falha,"erro")
					iniciando=false;transicao=nil;deps.mudou();return
				end
			end
			local comando=if s.modo=="treino" then "iniciarTreino" elseif s.modo=="duelo" then "iniciarDuelo" else "iniciarLuta"
			local falha=handlers[comando](p,{nivel=s.nivel},true)
			if falha then deps.logTo(p,falha,"erro") end
			iniciando=false;transicao=nil;deps.mudou()
		end)
		return nil
	end
	local api={}
	function api.mestre() return if teste() then nil else s.mestre end
	function api.entrar(p) regras.entrar(p.UserId,p.DisplayName) end
	function api.sair(p) carregar.sair(p.UserId);dados.sair(p.UserId);entrega.sair(p.UserId);regras.sair(p.UserId,agora());maos[p.UserId]=nil;ofertas[p.UserId]=nil;papeis.sair(p.UserId);recreativo.sair(p.UserId,agora(),inteiro,dados.pendentes()) end
	function api.admin(p,cmd)
		local e=permitido(p);if e then return e end
		if cmd=="brotos" then e=rodada() elseif cmd=="arrumar" then papeis.arrumar();dados.arrumar();carregar.arrumar() else return "Comando de sala desconhecido." end
		if not e then deps.mudou() end
		return e
	end
	function api.publico()
		if teste() then return nil end
		local r=regras.publico();r.transicao=transicao;r.maos=table.clone(maos);r.ofertas=table.clone(ofertas);r.papeisSoltos=papeis.publico();r.brincadeiraBrotos=recreativo.publico();return r
	end
	function api.monstros() return not teste() and s.monstros end
	function api.participa(p) return not api.monstros() or p.UserId~=s.mestre end
	function api.grupoTreino()
		if teste() then return nil end
		local grupo={};for _,id in s.ordem do local p=s.pessoas[id];if p.admitido and p.ficha and jogador(id) then table.insert(grupo,jogador(id)) end end;return grupo
	end
	function api.guardar(p,cmd)
		if teste() then return nil end
		local eu=s.pessoas[p.UserId]
		if (not eu or not eu.admitido) and cmd~="requestSnapshot" then return "Aguarde autorização do mestre para entrar na mesa." end
		if cmd=="iniciarLuta" or cmd=="iniciarDuelo" or cmd=="iniciarTreino" or cmd=="entrarFila" or (cmd=="combatStart" and not deps.combat.active) then return "Prepare a sessão nos objetos da mesa; só o mestre lança os dados para começar." end
		return nil
	end
	task.spawn(function() while true do task.wait(.5);if not teste() and not dados.pendentes() then local mudou=regras.atualizar(agora(),inteiro);if recreativo.atualizar(agora(),inteiro) then mudou=true end;if mudou then deps.mudou() end end end end)
	return api
end
return Sala
