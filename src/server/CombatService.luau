local CombatService = {}
function CombatService.start()
-- Protótipo: regras provisórias, não é uma conversão integral do livro.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local remote = Instance.new("RemoteEvent")
remote.Name = "RPG"
remote.Parent = RS
local Grid = require(RS.Shared.Grid)
local Rules = require(script.Parent.CombatRules)
local rng = Random.new()
local sessions = {}
local nextArenaId = 0
local cooldown = {}
local World = require(script.Parent.WorldBuilder)
local world = World.create(rng)
local part = world.part
local prompt = world.prompt
local function point(s,x,z) return s.origin + Vector3.new((x-4)*6,3,(z-4)*6) end
local function send(player,s,msg)
 remote:FireClient(player,{active=true,hp=s.hp,mp=s.mp,enemyHp=s.ehp,enemy=s.name,pa=s.pa,origin=s.origin,message=msg})
end
local function finish(player,msg)
 local s = sessions[player]; if not s then return end
 sessions[player] = nil; cooldown[player] = os.clock()+8
 s.arena:Destroy()
 local c = player.Character
 if c and c:FindFirstChild("HumanoidRootPart") then
  c.HumanoidRootPart.Anchored = false
  c:PivotTo(s.returnTo)
 end
 remote:FireClient(player,{active=false,message=msg})
end
local function start(player)
 if sessions[player] or (cooldown[player] or 0)>os.clock() then return end
 local c = player.Character
 if not c or not c:FindFirstChild("HumanoidRootPart") then return end
 local folder = Instance.new("Folder"); folder.Name = "Arena_"..player.UserId; folder.Parent = workspace
 local name = ({"Lobo do campo","Slime errante","Bandido de treino"})[rng:NextInteger(1,3)]
 nextArenaId += 1
 local s = {arena=folder,origin=Vector3.new(nextArenaId * 60,1000,0),returnTo=c:GetPivot(),hp=30,mp=12,ehp=22,x=2,z=4,ex=6,ez=4,pa=3,name=name,last=0}
 sessions[player]=s
 for x=1,7 do for z=1,7 do
  local tile=part("Casa",Vector3.new(5.8,1,5.8),point(s,x,z)-Vector3.new(0,3,0),((x+z)%2==0 and Color3.fromRGB(111,145,133) or Color3.fromRGB(77,107,99)),folder)
  tile:SetAttribute("GridX",x); tile:SetAttribute("GridZ",z)
 end end
 s.enemy=part(name,Vector3.new(3,4,3),point(s,s.ex,s.ez),Color3.fromRGB(185,74,70),folder)
 c:PivotTo(CFrame.new(point(s,s.x,s.z)))
 c.HumanoidRootPart.Anchored=true
 send(player,s,"Encontro: "..name..". Seu turno: 3 pontos de ação.")
end
local distance = Grid.distance
local function enemyTurn(player,s,msg,guard)
 if s.ehp<=0 then finish(player,msg.." Vitória! Recompensa experimental: 1 PA de aprimoramento (não salva)."); return end
 s.pa=0; send(player,s,msg.." Turno inimigo...")
 task.delay(0.7,function()
  if sessions[player]~=s then return end
  for _=1,3 do
   if distance(s.x,s.z,s.ex,s.ez)<=1 then break end
   if s.ex~=s.x then s.ex+= (s.x>s.ex and 1 or -1) else s.ez+=(s.z>s.ez and 1 or -1) end
  end
  s.enemy.Position=point(s,s.ex,s.ez)
  local report="O inimigo se aproximou."
  if distance(s.x,s.z,s.ex,s.ez)<=1 then
   local roll=rng:NextInteger(1,20)
   if roll+3 >= (guard and 16 or 12) then
    local damage=rng:NextInteger(1,6)+2; s.hp=math.max(0,s.hp-damage)
    report="Inimigo: d20="..roll.."; você sofreu "..damage.." de dano."
   else report="Inimigo: d20="..roll.."; errou." end
  end
  if s.hp<=0 then finish(player,"Derrota no treino. Você voltou ao campo."); return end
  s.pa=3; send(player,s,msg.." "..report.." Seu turno.")
 end)
end
remote.OnServerEvent:Connect(function(player,action,x,z)
 local s=sessions[player]
 if not s or s.pa<=0 or os.clock()-s.last<0.12 then return end
 s.last=os.clock()
 if action=="flee" then finish(player,"Você saiu do encontro."); return end
 local msg
 if action=="move" then
  if not Grid.isCell(x,z) then return end
  if x==s.ex and z==s.ez then send(player,s,"Essa casa está ocupada pelo inimigo."); return end
  local cost=distance(s.x,s.z,x,z)
  if cost<1 then return end
  if cost>s.pa then send(player,s,"Destino distante: você tem "..s.pa.." ponto(s) de movimento."); return end
  -- Não permite atravessar a casa inimiga: trajeto reto por eixo.
  if x~=s.x and z~=s.z then send(player,s,"Mova na mesma linha ou coluna do personagem."); return end
  if (z==s.z and s.ez==z and s.ex>=math.min(x,s.x) and s.ex<=math.max(x,s.x)) or (x==s.x and s.ex==x and s.ez>=math.min(z,s.z) and s.ez<=math.max(z,s.z)) then send(player,s,"O inimigo bloqueia esse caminho."); return end
  s.x=x; s.z=z; s.pa-=cost
  player.Character:PivotTo(CFrame.new(point(s,x,z)))
  msg="Movimento: "..cost.." ponto(s)."
 elseif action=="attack" or action=="spell" then
  if s.pa<2 then send(player,s,"Você precisa de 2 pontos para atacar."); return end
  local magic=action=="spell"
  if distance(s.x,s.z,s.ex,s.ez)>(magic and 5 or 1) then send(player,s,"Inimigo fora do alcance."); return end
  if magic and s.mp<3 then send(player,s,"Mana insuficiente."); return end
  if magic then s.mp-=3 end
  s.pa-=2
  local result=Rules.attack(rng,magic)
  if result.hit then
   s.ehp=math.max(0,s.ehp-result.damage)
   msg="d20="..result.roll.." +4: acerto! Dano "..result.damage..(result.critical and " (crítico)." or ".")
  else msg="d20="..result.roll.." +4: errou." end
 elseif action=="guard" or action=="end" then
  enemyTurn(player,s,action=="guard" and "Guarda: +4 defesa nesta rodada." or "Turno encerrado.",action=="guard"); return
 else return end
 if s.ehp<=0 or s.pa==0 then enemyTurn(player,s,msg,false) else send(player,s,msg) end
end)
prompt.Triggered:Connect(function(player) local c=player.Character; local root=c and c:FindFirstChild("HumanoidRootPart"); if root and (root.Position-world.spawn.Position).Magnitude<=16 then start(player) end end)
Players.PlayerAdded:Connect(function(player)
 player.CharacterRemoving:Connect(function() finish(player,"Encontro encerrado.") end)
end)
Players.PlayerRemoving:Connect(function(player)
 local s=sessions[player]; if s then s.arena:Destroy() end
 sessions[player]=nil; cooldown[player]=nil
end)
task.spawn(function()
 while true do
  task.wait(2)
  for _,player in Players:GetPlayers() do
   local c=player.Character; local root=c and c:FindFirstChild("HumanoidRootPart")
   if root and not sessions[player] and math.abs(root.Position.X)<25 and math.abs(root.Position.Z-35)<25 and math.abs(root.Position.Y)<15 and rng:NextNumber()<0.3 then start(player) end
  end
 end
end)

end
return CombatService



