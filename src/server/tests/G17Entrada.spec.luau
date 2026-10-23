-- SOMENTE STUDIO: controlador real com entradas e relógio injetados.
local G=require(game.StarterPlayer.StarterPlayerScripts.Client.SalaPegada)
local function fixture(fn)
	local pasta=Instance.new("Folder");local eventos={};local input={};local chamadas={};local tempo=0;local apoiado=false;local callback=nil;local pedidos=0
	-- InputObject conserva identidade entre Begin/End. BindableEvent copia tabelas,
	-- então o sinal injetado entrega o mesmo objeto de entrada ao controlador.
	for _,nome in {"InputBegan","InputEnded","WindowFocusReleased"} do
		local callbacks={};local e={};function e:Connect(fn) table.insert(callbacks,fn) end;function e:Fire(...) for _,fn in callbacks do fn(...) end end
		input[nome]=e;eventos[nome]=e
	end
	function input:GetFocusedTextBox() return nil end
	local controles={};function controles:BindActionAtPriority(_,f) callback=f end
	local api=G.new({input=input,controles=controles,agora=function() return tempo end,dicas={atualizar=function() end},pasta=pasta,pg=pasta,state={onLog=function() end},apoiado=function() return apoiado end,
		procurar=function() return nil end,pegar=function() pedidos+=1;return "mago-de-fogo" end,acao=function(a) table.insert(chamadas,a);return true end})
	local f={api=api,eventos=eventos,chamadas=chamadas,pedidos=function() return pedidos end,tempo=function(t) tempo=t end,apoiar=function() apoiado=true end,controle=function(...) return callback(...) end}
	local ok,erro=pcall(fn,f);pasta:Destroy();if not ok then error(erro,0) end
end
return {
	["RT mantido confirma e libera sem arremessar"]=function(t) fixture(function(f)
		f.api.atualizar(true,nil,nil);local i={KeyCode=Enum.KeyCode.ButtonR2,UserInputType=Enum.UserInputType.Gamepad1};f.controle("",Enum.UserInputState.Begin,i);f.api.atualizar(true,"mago-de-fogo",nil);t.eq(#f.chamadas,0)
		f.controle("",Enum.UserInputState.End,i);t.eq(f.chamadas[1],"Soltar")
	end) end,
	["toque secundario nao solta pegada principal"]=function(t) fixture(function(f)
		f.api.atualizar(true,nil,nil);local i={UserInputType=Enum.UserInputType.Touch,Position=Vector3.new(50,60,0)};f.eventos.InputBegan:Fire(i,false);f.api.atualizar(true,"mago-de-fogo",nil)
		f.eventos.InputEnded:Fire({UserInputType=Enum.UserInputType.Touch});t.eq(#f.chamadas,0);f.eventos.InputEnded:Fire(i);t.eq(f.chamadas[1],"Soltar")
	end) end,
	["mao confirmada antes de overlay conserva soltura"]=function(t) fixture(function(f)
		f.api.atualizar(true,nil,nil);local i={UserInputType=Enum.UserInputType.MouseButton1};f.eventos.InputBegan:Fire(i,false);task.wait();f.api.atualizar(true,"mago-de-fogo",nil)
		f.api.atualizar(false,"mago-de-fogo",nil);t.eq(#f.chamadas,0);f.api.atualizar(true,"mago-de-fogo",nil);t.eq(f.chamadas[1],"Soltar")
	end) end,
	["entrega confirmada nao confunde com aquisicao descartada"]=function(t) fixture(function(f)
		f.api.atualizar(true,nil,nil);local i={UserInputType=Enum.UserInputType.MouseButton1};f.eventos.InputBegan:Fire(i,false);task.wait();f.eventos.InputEnded:Fire(i);task.wait()
		f.tempo(2.1);f.api.atualizar(true,nil,nil);f.api.atualizar(true,"mago-de-fogo",nil,{id="mago-de-fogo",serial=1,de=2});t.eq(#f.chamadas,0)
	end) end,
	["ack durante overlay conserva soltura ate reativar"]=function(t) fixture(function(f)
		f.api.atualizar(true,nil,nil);local i={UserInputType=Enum.UserInputType.MouseButton1};f.eventos.InputBegan:Fire(i,false);task.wait();f.eventos.InputEnded:Fire(i);task.wait()
		f.api.atualizar(false,"mago-de-fogo",nil);t.eq(#f.chamadas,0);f.api.atualizar(true,"mago-de-fogo",nil);t.eq(f.chamadas[1],"Soltar")
	end) end,
	["pedido sem resposta libera proxima pegada e respeita nova intencao"]=function(t) fixture(function(f)
		f.api.atualizar(true,nil,nil);local i={UserInputType=Enum.UserInputType.MouseButton1};f.eventos.InputBegan:Fire(i,false);task.wait();f.eventos.InputEnded:Fire(i);task.wait()
		f.tempo(2.1);for _=1,5 do f.api.atualizar(true,nil,nil) end
		local novo={UserInputType=Enum.UserInputType.MouseButton1};f.eventos.InputBegan:Fire(novo,false);task.wait();t.eq(f.pedidos(),2)
		f.api.atualizar(true,"mago-de-fogo",nil);t.eq(#f.chamadas,0);f.eventos.InputEnded:Fire(novo);task.wait();t.eq(f.chamadas[1],"Soltar")
	end) end,
	["ack depois do prazo visual ainda larga clique curto"]=function(t) fixture(function(f)
		f.api.atualizar(true,nil,nil);local i={UserInputType=Enum.UserInputType.MouseButton1};f.eventos.InputBegan:Fire(i,false);task.wait();f.eventos.InputEnded:Fire(i);task.wait()
		f.tempo(2.1);f.api.atualizar(true,nil,nil);f.api.atualizar(true,"mago-de-fogo",nil);t.eq(#f.chamadas,1);t.eq(f.chamadas[1],"Soltar")
	end) end,
	["consulta apoiada antes de ack nao larga ao confirmar"]=function(t) fixture(function(f)
		f.api.atualizar(true,nil,nil);local i={UserInputType=Enum.UserInputType.MouseButton1};f.eventos.InputBegan:Fire(i,false);task.wait();f.apoiar();f.eventos.InputEnded:Fire(i);task.wait();f.api.atualizar(true,"mago-de-fogo",nil);t.eq(#f.chamadas,0)
		f.eventos.InputBegan:Fire({KeyCode=Enum.KeyCode.F},false);task.wait();t.eq(f.chamadas[1],"Arremessar")
	end) end,
	["X do controle passa para consultas quando mao vazia"]=function(t) fixture(function(f)
		f.api.atualizar(true,nil,nil);local i={KeyCode=Enum.KeyCode.ButtonX};t.eq(f.controle("",Enum.UserInputState.Begin,i),Enum.ContextActionResult.Pass)
		f.api.atualizar(true,"dados-brotos",nil);t.eq(f.controle("",Enum.UserInputState.Begin,i),Enum.ContextActionResult.Sink);t.eq(f.chamadas[1],"Arremessar")
	end) end,
}
