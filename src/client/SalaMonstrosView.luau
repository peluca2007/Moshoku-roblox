local V={}
function V.start(state)
	local g=Instance.new("ScreenGui");g.Name="MonstrosDoMestre";g.ResetOnSpawn=false;g.Parent=game.Players.LocalPlayer:WaitForChild("PlayerGui")
	local f=Instance.new("Frame");f.Name="Comandos";f.Size=UDim2.fromOffset(600,65);f.Position=UDim2.new(.5,-300,1,-80);f.BackgroundColor3=Color3.fromRGB(46,37,31);f.Visible=false;f.Parent=g
	local token
	local function b(nome,text,x,fn)
		local o=Instance.new("TextButton");o.Name=nome;o.Text=text;o.Size=UDim2.fromOffset(185,48);o.Position=UDim2.fromOffset(x,8);o.TextSize=19;o.BackgroundColor3=Color3.fromRGB(199,173,127);o.Parent=f;o.Activated:Connect(fn)
	end
	b("Andar","Mover monstro",8,function() state.setMira({tokenId=token.id,habilidadeId="mesa/andar",tipo="mover",modo="casa"}) end)
	b("Atacar","Atacar • 1 casa",207,function() state.setMira({tokenId=token.id,habilidadeId="criatura/ataque",tipo="ataque",modo="ficha",alcanceCasas=1}) end)
	b("Passar","Encerrar vez",406,function() local s=state.snapshot();state.send("nextTurn",{expectedTurn=s.combat.turn,expectedId=token.id}) end)
	state.onSnapshot(function(s)
		token=if s.combat.active then state.findToken(s.combat.turnId) else nil
		f.Visible=s.you.master and token~=nil and token.monstroDoMestre==true
	end)
end
return V
