-- Ponte de apresentação: recibos autoritativos J2 reutilizam Magias/Coreografia.
-- Nenhuma regra ou intenção é enviada por este módulo.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").Shared
local Dados=require(Shared.EncontroAnimacoesDados)
local Catalogo=require(Shared.Livro.Catalogo)
local Magias=require(script.Parent.Magias)
local A={}
local function seguro(id) return (tostring(id):gsub("[^%w%-_]","_")) end
function A.start(state)
 local atual, tokens, vistos, ordem={}, {}, {}, {}
 local emitirSnapshot, emitirEfeito
 local geracao, encerrado=0,false
 local contexto={tamanhoCasa=1.8}
 local function pasta()
  return atual.encounterId and workspace:FindFirstChild("MiniaturasJ2_"..seguro(atual.encounterId))
 end
 local function jogadorDe(id)
  local userId=tonumber(tostring(id):match("^jogador:(%-?%d+)$"))
  if id==atual.controlledActorId then userId=Players.LocalPlayer.UserId end
  return userId and Players:GetPlayerByUserId(userId)
 end
 local function ancora(id)
  local p=jogadorDe(id)
  local root=p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
  local f=pasta()
  return root or f and f:FindFirstChild("Ator_"..seguro(id))
 end
 function contexto.findToken(id) return tokens[id] end
 function contexto.modeloDe(id)
  local p=jogadorDe(id)
  if p and p.Character then return p.Character,true end
  local f=pasta()
  local modelo=f and f:FindFirstChild("Criatura_"..seguro(id))
  if modelo and modelo:IsA("Model") then return modelo,modelo:FindFirstChildOfClass("Humanoid")~=nil end
  return nil,false
 end
 local function referencia()
  -- Uma posição replicada e sua casa confirmada definem o centro da mesma grade.
  for _,a in ipairs(atual.actors or {}) do
   local parte=ancora(a.id)
   if parte then return parte.Position,a end
  end
  return nil
 end
 function contexto.chao(p)
  local f=pasta()
  if f then
   for _,obj in ipairs(f:GetChildren()) do
    if obj:IsA("BasePart") and obj.Name:sub(-5)=="_Base" then return Vector3.new(p.X,obj.Position.Y-.08,p.Z) end
   end
  end
  local root=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
  return Vector3.new(p.X,if root then root.Position.Y-3 else 0,p.Z)
 end
 function contexto.posicaoCasa(x,z)
  local pos,a=referencia()
  if not pos then return Vector3.zero end
  return contexto.chao(Vector3.new(pos.X+(x-a.x)*contexto.tamanhoCasa,pos.Y,pos.Z+(z-a.z)*contexto.tamanhoCasa))
 end
 function contexto.posicaoDe(id,fallback)
  local parte=id and ancora(id)
  if parte then return parte.Position+Vector3.new(0,1,0) end
  local t=id and tokens[id]
  local c=if t then {t.x,t.z} else fallback
  return if c then contexto.posicaoCasa(c[1],c[2])+Vector3.new(0,2,0) else Vector3.zero
 end
 function contexto.onSnapshot(fn) emitirSnapshot=fn end
 function contexto.onEfeito(fn) emitirEfeito=fn end
 local visual=Magias.start(contexto,{nomePasta="MagiasJ2Locais"})
 local function limpar()
  geracao+=1
  visual.limpar()
  table.clear(vistos);table.clear(ordem);table.clear(tokens)
  atual={}
 end
 state.onEstado(function(s)
  if encerrado or type(s)~="table" then return end
  if atual.encounterId~=s.encounterId then limpar() end
  atual=s
  table.clear(tokens)
  for _,a in ipairs(s.actors or {}) do
   local p=jogadorDe(a.id)
   tokens[a.id]={id=a.id,name=a.name,x=a.x,z=a.z,avatar=p~=nil,ownerUserId=p and p.UserId}
  end
  emitirSnapshot({combat={active=true}})
  if s.phase~="active" then
   local g=geracao
   -- A última animação termina antes de recolher seus objetos; nova luta cancela a espera.
   task.delay(2.5,function() if not encerrado and geracao==g then limpar() end end)
  end
 end)
 state.onRecibo(function(r)
  if encerrado or r.encounterId~=atual.encounterId then return end
  local efeito=Dados.projetar(r,atual)
  if not efeito then return end
  local chave=tostring(r.version)..":"..tostring(r.actorId)..":"..tostring(r.action)
  if vistos[chave] then return end
  vistos[chave]=true;table.insert(ordem,chave)
  if #ordem>128 then vistos[table.remove(ordem,1)]=nil end
  local entrada=Catalogo.POR_ID[efeito.habilidadeId]
  efeito.encantamento=entrada and entrada.name
  emitirEfeito(efeito)
 end)
 state.onRetorno(function() if not encerrado then limpar() end end)
 return {destruir=function() if encerrado then return end;limpar();encerrado=true;visual.destruir() end}
end
return A
