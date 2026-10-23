-- Clique/RT/toque mantido. Só envia intenção; a mão vem do snapshot.
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local G={}
function G.new(deps)
 local inputService=deps.input or UIS;local controles=deps.controles or CAS;local agora=deps.agora or os.clock
	local ativo=false;local mao=nil;local pedido=nil;local prazo=0;local entrada=nil;local terminou=false;local usado=false
	local cancelados={};local ultimaOferta=nil
	local contorno=Instance.new("Highlight");contorno.Name="ContornoPegada";contorno.FillTransparency=1;contorno.OutlineColor=Color3.fromRGB(242,204,119);contorno.OutlineTransparency=.1;contorno.DepthMode=Enum.HighlightDepthMode.Occluded;contorno.Enabled=false;contorno.Parent=deps.pasta
	local function acao(nome)
		if not ativo or not mao then return false end
		if (nome=="Arremessar" or nome=="Soltar") and usado then return false end
		local ok=deps.acao(nome)
		if ok and (nome=="Arremessar" or nome=="Soltar") then usado=true end
		return ok
	end
	local dicas=deps.dicas or require(script.Parent.SalaMaoDicas).new(deps.pg,acao)
	local function iniciar(input)
		if not ativo or entrada or pedido or inputService:GetFocusedTextBox() then return end
		entrada=input;terminou=false;usado=false
		if mao then return end
		local pos=if input.UserInputType==Enum.UserInputType.Touch then Vector2.new(input.Position.X,input.Position.Y) else nil
		local objeto=deps.procurar(pos)
		local id=deps.pegar(objeto)
		if id then cancelados[id]=nil;pedido=id;prazo=agora()+2 else entrada=nil end
	end
	local function terminar(input)
		if not entrada or entrada~=input then return end
		entrada=nil;terminou=true
		if mao and not (deps.apoiado and deps.apoiado()) then
			if not acao("Soltar") and not usado then cancelados[mao]=true end
		end
	end
	inputService.InputBegan:Connect(function(input,processed)
		if processed or inputService:GetFocusedTextBox() then return end
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then iniciar(input)
		elseif input.KeyCode==Enum.KeyCode.F then acao("Arremessar") end
	end)
	inputService.InputEnded:Connect(terminar)
	inputService.WindowFocusReleased:Connect(function() if entrada then terminar(entrada) end end)
	controles:BindActionAtPriority("SalaPegadaControle",function(_,estado,input)
		if not ativo or inputService:GetFocusedTextBox() or game:GetService("GuiService").MenuIsOpen then return Enum.ContextActionResult.Pass end
		if input.KeyCode==Enum.KeyCode.ButtonX then
			if not mao or mao:sub(1,8)=="jogador:" then return Enum.ContextActionResult.Pass end
			if estado==Enum.UserInputState.Begin then acao("Arremessar") end
		elseif estado==Enum.UserInputState.Begin then iniciar(input)
		elseif estado==Enum.UserInputState.End or estado==Enum.UserInputState.Cancel then terminar(entrada) end
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value+10,Enum.KeyCode.ButtonR2,Enum.KeyCode.ButtonX)
	deps.state.onLog(function(e) if e.tone=="erro" then pedido=nil;usado=false end end)
	local api={}
	function api.atualizar(ligado,nova,objeto,oferta)
		ativo=ligado;local anterior=mao;mao=nova
		if mao~=anterior and not pedido then usado=false end
		-- Uma entrega tem origem/serial autoritativos distintos da aquisição.
		if oferta and oferta.serial~=ultimaOferta and oferta.id==mao then
			ultimaOferta=oferta.serial;cancelados[mao]=nil;pedido=nil;entrada=nil;terminou=false;usado=false
		end
		if pedido and mao==pedido then pedido=nil;if terminou then cancelados[mao]=true end end
		-- Um remoto descartado não bloqueia novas pegadas. A confirmação tardia
		-- ainda é largada; pegar novamente o mesmo objeto renova a intenção.
		if pedido and agora()>prazo then cancelados[pedido]=true;pedido=nil;entrada=nil;terminou=true end
		if mao and cancelados[mao] then
			if deps.apoiado and deps.apoiado() or acao("Soltar") then cancelados[mao]=nil end
		end
		if not ativo and entrada then terminar(entrada) end
		if not mao and not pedido then usado=false end
		local fisico=objeto and ({ficha=true,livro=true,dados=true,jogador=true})[objeto:GetAttribute("SalaObjeto")]
		contorno.Adornee=if fisico and not mao and not pedido and ativo then (if objeto:GetAttribute("SalaObjeto")=="jogador" then objeto.Parent else objeto) else nil
		contorno.Enabled=contorno.Adornee~=nil
		dicas.atualizar(if ativo then mao else nil,deps.apoiado and deps.apoiado())
	end
	return api
end
return G
