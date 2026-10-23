-- Avatar de bancada no mesmo cliente; não é conexão multiplayer real.
local r=shared.G15;local player=game.Players.LocalPlayer
local pasta=Instance.new("Folder");pasta.Name="G15BracosTeste";pasta.Parent=workspace
local real=player.Character;local a=real.Archivable;real.Archivable=true;local outro=real:Clone();real.Archivable=a;outro.Name="OutroJogadorG15"
for _,d in outro:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored=true;d.LocalTransparencyModifier=0 end end
outro.Parent=pasta;outro:PivotTo(CFrame.new(260,5,-8))
local corpo=require(player.PlayerScripts.Client.SalaCorpo).new(pasta,function() return {{UserId=999,Character=outro}} end)
corpo.atualizar({maos={[999]="mago-de-fogo"}},1,nil)
r.check("papel remoto existe antes",pasta:FindFirstChild("PapelDoJogador999")~=nil)
corpo.atualizar({maos={[999]="dados-brotos"}},1,nil)
r.check("dados nao viram papel remoto",pasta:FindFirstChild("PapelDoJogador999")==nil)
corpo.atualizar({maos={[999]="jogador:"..player.UserId}},1,nil)
r.check("amigo nao vira papel remoto",pasta:FindFirstChild("PapelDoJogador999")==nil)
r.check("braco remoto visivel",outro.RightHand.LocalTransparencyModifier==1 and pasta.Bracos_OutroJogadorG15.RightHand.Transparency<.1)
corpo.restaurar();r.check("braco restaurado ao sair",outro.RightHand.LocalTransparencyModifier==0);pasta:Destroy()
return "Gestos de dados/jogador verificados em bancada"
