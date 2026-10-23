-- Servidor: carregador de bancada, alvo é o jogador conectado real.
-- Exercita o remoto de soltura vindo do cliente real, sem inventar segunda conexão.
local Players=game.Players;local player=Players:GetPlayers()[1]
local real=player.Character;local archivable=real.Archivable;real.Archivable=true;local char=real:Clone();real.Archivable=archivable
char.Name="CarregadorDeBancada"
for _,d in char:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.CanCollide=false;d.Anchored=false end end
char.Parent=workspace;char:PivotTo(real:GetPivot()*CFrame.new(2,0,0))
local fake={UserId=999,Character=char};local s={maos={},escaped=false,char=char};shared.G15Carry=s
s.api=require(game.ServerScriptService.Server.SalaCarregarJogadores).new({maos=s.maos,agora=function() return workspace:GetServerTimeNow() end,permitido=function() return nil end,jogador=function(id) return if id==player.UserId then player else nil end,mudou=function() end})
local erro=s.api.aplicar(fake,{userId=player.UserId});assert(not erro,erro);char.HumanoidRootPart.Anchored=true
s.heart=game:GetService("RunService").Heartbeat:Connect(s.api.atualizar)
s.remote=game.ReplicatedStorage.Mesa.OnServerEvent:Connect(function(p,cmd,d) if p==player and cmd=="salaCarregar" and type(d)=="table" and d.soltar==true then s.api.aplicar(p,d);s.escaped=true end end)
return "Alvo real carregado por avatar de bancada"
