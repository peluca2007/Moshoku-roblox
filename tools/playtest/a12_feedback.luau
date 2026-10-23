local p=game.Players.LocalPlayer
local c=p.PlayerScripts.Client
local FX=require(c.MenuEfeitos)
local pg=p.PlayerGui
local menu=pg.InicioJogo.MenuInicial
local snap
local fake={onSnapshot=function(f) snap=f end, localUserId=function() return p.UserId end}
local g=require(c.FeedbackCombate).start(fake)
local linhas={}
local function ok(n,b) assert(b,n); table.insert(linhas,'OK '..n) end
local antigo=menu.Visible
menu.Visible=false
FX.reduzir(false)
local function estado(pv,dono)
 snap({combat={active=true},tokens={{id='a12',pv=pv,ownerUserId=dono or p.UserId}}})
end
estado(100); ok('sem pulso no primeiro snapshot',g.Borda1.BackgroundTransparency==1)
estado(80); ok('dano confirmado pulsa vermelho',g.Borda1.BackgroundTransparency<1 and g.Borda1.BackgroundColor3==require(game.ReplicatedStorage.Shared.Estilo).PERIGO)
estado(90); ok('cura confirmada pulsa verde',g.Borda1.BackgroundColor3==require(game.ReplicatedStorage.Shared.Estilo).SUCESSO)
FX.reduzir(true); estado(70); ok('reduzir animações suprime pulso',g.Borda1.BackgroundTransparency==1)
FX.reduzir(false); menu.Visible=true; estado(60); ok('menu aberto suprime pulso',g.Borda1.BackgroundTransparency==1)
local count=0
for _,o in menu:GetChildren() do if o.Name:match('^Centelha') then count+=1 end end
ok('partículas limitadas a 12',count==12)
local testeFundo=Instance.new('Frame'); testeFundo.Size=UDim2.fromOffset(300,300); testeFundo.Parent=g
FX.fundo(testeFundo,Color3.new(1,1,1))
FX.reduzir(true)
local visiveis=0
for _,o in testeFundo:GetChildren() do if o.Name:match('^Centelha') and o.Visible then visiveis+=1 end end
ok('redução oculta partículas imediatamente',visiveis==0)
menu.Visible=antigo; g:Destroy()
return table.concat(linhas,'\n')
