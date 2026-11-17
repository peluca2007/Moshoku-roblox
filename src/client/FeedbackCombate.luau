-- Feedback discreto dos recursos confirmados pelo servidor; sem tremor ou flash.
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local T=require(script.Parent.UI.Tema)
local FX=require(script.Parent.MenuEfeitos)
local Fila=require(game:GetService("ReplicatedStorage").Shared.Animacoes.FilaApresentacao)
local Efeitos=require(script.Parent.Efeitos)
local Protocol=require(game:GetService("ReplicatedStorage").Shared.MesaProtocol)
local Feedback={}
-- ANIM3: fila de apresentação única do cliente. A Coreografia registra `fila:reter` (PV até o marco `impacto`
-- do atacante); BarrasLuta, BoardView e AnimacaoLuta mostram `Feedback.visto(token)` em vez do token cru. Ao vencer
-- o prazo (ou no `soltar` do contato), `aoLiberar` avisa quem redesenha; o número de dano é da BarrasLuta (HAB8).
Feedback.fila=Fila.nova()
local liberacoes={}
function Feedback.aoLiberar(cb) table.insert(liberacoes,cb) end
function Feedback.visto(token) return Feedback.fila:visto(token,os.clock()) end
local emCombate=false
-- BoardView: em luta (sem movimento reduzido) o número de dano sai daqui, no impacto; fora dela, do próprio BoardView.
function Feedback.emCombate() return emCombate and not FX.reduzidos end
function Feedback.retido(id) return Feedback.fila:retido(id,os.clock()) end
function Feedback.start(state)
	local pg=Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder,gui.IgnoreGuiInset="FeedbackCombate",false,12,true
	gui.Parent=pg
	local bordas={}
	for i=1,2 do
		local f=Instance.new("Frame"); f.Name="Borda"..i; f.BorderSizePixel=0
		f.Size=UDim2.new(0,9,1,0); f.Position=UDim2.new(i-1,if i==2 then -9 else 0,0,0)
		f.BackgroundTransparency=1; f.Parent=gui; bordas[i]=f
	end
	local anterior={}; local ativos={}
	local ultimo=nil
	local function aplicar(s)
		local proximos={}
		local delta=0
		for _,t0 in s.tokens do
			local t=Feedback.visto(t0)
			if t.ownerUserId==state.localUserId() then
				proximos[t.id]=t.pv
				if anterior[t.id] and type(t.pv)=="number" then delta+=t.pv-anterior[t.id] end
			end
		end
		anterior=proximos
		local menu=pg:FindFirstChild("InicioJogo")
		local oculto=menu and menu.MenuInicial.Visible
		if not s.combat.active or oculto or FX.reduzidos then
			for _,f in bordas do if ativos[f] then ativos[f]:Cancel() end; f.BackgroundTransparency=1 end
			return
		end
		if delta==0 then return end
		for _,f in bordas do
			if ativos[f] then ativos[f]:Cancel() end
			f.BackgroundColor3=if delta<0 then T.cores.perigo else T.cores.sucesso
			f.BackgroundTransparency=.3
			local t=TweenService:Create(f,TweenInfo.new(.8,Enum.EasingStyle.Quad),{BackgroundTransparency=1})
			ativos[f]=t; t:Play()
		end
	end
	-- HAB8: passiva que agiu (Roupa Leve +2 CA, Sem Recuo imune a Amedrontado): o servidor conta em avisoPassiva.n;
	-- cada aumento vira um destaque sobre o token. O primeiro snapshot só registra (não repete avisos antigos).
	local avisosVistos={}
	local function avisos(s)
		for _,t in s.tokens do
			-- token já visto sem aviso conta como 0: o primeiro aviso (n=1) também aparece; token novo só registra
			local a=t.avisoPassiva
			local n=if type(a)=="table" and type(a.n)=="number" then a.n else 0
			local visto=avisosVistos[t.id]
			avisosVistos[t.id]=n
			if type(a)=="table" then
				if visto and n>visto and s.combat.active and not t.hidden and t.x and t.z then
					local texto=string.upper(tostring(a.nome))..(if a.detalhe=="imune" then "  · IMUNE" elseif a.detalhe then "  "..tostring(a.detalhe) else "")
					Efeitos.destaque(Protocol.cellCenter(t.x,t.z)+Vector3.new(0,6.5,0),texto,T.barras.cheia,false) -- HAB8: verde claro do tema (o escuro sumia no painel)
				end
			end
		end
	end
	state.onSnapshot(function(s)
		ultimo=s
		avisos(s)
		emCombate=s.combat.active==true
		local agora=os.clock()
		for _,t in s.tokens do Feedback.fila:observar(t.id,t.pv,agora,if s.combat.active and not FX.reduzidos then Fila.CARENCIA else nil) end
		if not s.combat.active then Feedback.fila:limpar() end
		aplicar(s)
	end)
	-- libera as retenções vencidas: número de dano no instante do golpe e redesenho de quem esperava
	RunService.Heartbeat:Connect(function()
		local vencidos=Feedback.fila:expirados(os.clock())
		if #vencidos==0 then return end
		-- HAB8: em luta o número sai só da BarrasLuta (salto grande no contato); aqui saía um segundo "-7" no mundo
		if ultimo then aplicar(ultimo) end
		for _,cb in liberacoes do task.spawn(cb,vencidos) end
	end)
	return gui
end
return Feedback
