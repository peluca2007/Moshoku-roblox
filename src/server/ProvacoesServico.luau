-- Autoridade T1. Cliente nunca envia aprovação, posição ou resultado da provação.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Movimento=require(Shared.MovimentoPersonagem)
local StarterPlayer=game:GetService("StarterPlayer")
local P=require(Shared.Regras.Provacoes)
local Canais=require(Shared.Regras.ProvacaoComportas)
local Cone=require(Shared.Regras.VisaoCone)
local Layout=require(Shared.Mundo.TreinadoresLayout)
local Guardas=require(script.Parent.Mundo.GuardasLadino)
local S={}
function S.start(deps)
 local sessao, mundo
 local relogio=deps.relogio or os.clock
 local ativos, segura, limites = {}, {}, {}
 local function raiz(player)
  local c=player.Character
  local r=c and c:FindFirstChild("HumanoidRootPart")
  local h=c and c:FindFirstChildOfClass("Humanoid")
  return if r and h and h.Health>0 then r else nil, h
 end
 local function contexto(player,s)
  local j=s and s.run and s.run.jogadores[player.UserId]
  return s==deps.sessao() and j and j.presente and not j.caido and not s.run.fim
   and s.run.regiao=="vila" and not s.ocupada and not deps.ocupado()
   and not s.evento and not s.luta and next(s.votos)==nil and not deps.emCombate(player)
 end
 local function enviar(player,estado,msg)
  deps.remote:FireClient(player,{provacao=true,estado=estado.estado,npcId=estado.npcId,
   agachado=estado.agachado,sino=estado.sino,tempo=P.tempo(estado,relogio()),mensagem=msg})
 end
 local function restaurar(player,a)
  local _,h=raiz(player)
  if h and a.humanoide==h then Movimento.restaurar(h,Movimento.padroes(StarterPlayer)) end
  if player.Parent==Players then player:SetAttribute("ProvacaoAgachado",nil) end
 end
 local function limpar(player,msg)
  local a=ativos[player]
  if not a then return end
  restaurar(player,a)
  if a.p.estado=="em-curso" then a.p.estado="falhou" end
  enviar(player,a.p,msg)
  P.liberar(a.p); ativos[player]=nil; segura[player]=nil
  if a.npcId=="vila-1" then mundo.mostrarSino(true) else mundo.canais(false) end
 end
 local function premio(player,a)
  if not contexto(player,a.s) or a.salvando then return end
  a.salvando=true
  -- A aprovação fica reservada enquanto o mesmo save atômico concede árvore + dia.
  local ok,erro=a.s:treinar(player.UserId,a.npcId,a.arvore,a.requestId)
  a.salvando=false
  if ok then
   restaurar(player,a); ativos[player]=nil
   enviar(player,{estado="aprovado",npcId=a.npcId},"Aprovado! Caminho aprendido: 1 dia da expedição, sem custo de pontos. Sua ficha foi atualizada.")
   if a.npcId=="vila-1" then mundo.mostrarSino(true) else mundo.canais(false) end
   deps.transmitir()
  else enviar(player,a.p,erro or "Não foi possível salvar. Fale com o treinador para tentar salvar novamente.") end
 end
 local function aprovar(player,a)
  if P.aprovar(a.p,player.UserId,relogio()) then premio(player,a) end
 end
 local function proximo(player,npcId)
  local a=ativos[player]
  if not a or a.npcId~=npcId or not P.emCurso(a.p,player.UserId) or not contexto(player,a.s) then return nil end
  return a,raiz(player)
 end
 local function perto(r,p,d) return r and (r.Position-p).Magnitude<=d end
 local function taxa(player,chave,intervalo)
  local agora=relogio(); limites[player]=limites[player] or {}
  local t=limites[player]
  if t[chave] and agora-t[chave]<intervalo then return false end
  t[chave]=agora; return true
 end
 local criarMundo=deps.criarMundo or require(script.Parent.Mundo.Provacoes).criar
 mundo=criarMundo({
  segurarSino=function(player)
   local a,r=proximo(player,"vila-1")
   if a and perto(r,mundo.sino.Position,8) then segura[player]=relogio() end
  end,
  sino=function(player)
   local a,r=proximo(player,"vila-1")
   if not a or not perto(r,mundo.sino.Position,8) or not segura[player] or relogio()-segura[player]<1.45 then return end
   segura[player]=nil
   P.pegarSino(a.p,player.UserId); mundo.mostrarSino(false); enviar(player,a.p,"Leve o sino ao portão.")
  end,
  portao=function(player)
   local a,r=proximo(player,"vila-1")
   if a and a.p.sino and perto(r,mundo.gate.Position,8) then aprovar(player,a) end
  end,
  girar=function(player,i,j,peca)
   local a,r=proximo(player,"vila-2")
   if not a or not perto(r,peca.Position,12) or not taxa(player,"girar",1/6) then return end
   if P.expirar(a.p,relogio()) then limpar(player,"Tempo esgotado. Tente novamente sem custo."); return end
   a.grade=Canais.girar(a.grade,i,j)
   mundo.grade(a.grade)
   local b=Canais.bacias(a.grade)
   if b[1] and b[2] and b[3] then aprovar(player,a) end
  end,
 })
 local api={mundo=mundo}
 function api.iniciar(player,s,npc)
  local existente=ativos[player]
  if existente and P.aprovado(existente.p,player.UserId) then premio(player,existente); return true,"Tentando salvar a aprovação." end
  if existente then return false,"Conclua sua provação atual." end
  if not contexto(player,s) then return false,"Provação indisponível no contexto atual da run." end
  if sessao and sessao~=s then
   for outro in ativos do limpar(outro,"Run alterada.") end
  end
  sessao=s; s.provacoes=s.provacoes or {}
  local p=s.provacoes[npc.id] or P.nova(); s.provacoes[npc.id]=p
  local ok,erro=P.iniciar(p,player.UserId,relogio(),if npc.id=="vila-2" then 90 else nil)
  if not ok then return false,erro end
  p.npcId=npc.id
  local r,h=raiz(player)
  if not r or not h then P.liberar(p); return false,"Personagem indisponível." end
  local a={s=s,p=p,npcId=npc.id,arvore=npc.arvore,humanoide=h,
   requestId=game:GetService("HttpService"):GenerateGUID(false)}
  ativos[player]=a
  if npc.id=="vila-1" then
   r.CFrame=CFrame.new(Layout.ENTRADA.x,3,Layout.ENTRADA.z); mundo.mostrarSino(true)
  else
   a.grade=Canais.gerar(deps.rng or Random.new())
   mundo.grade(a.grade); mundo.canais(true)
  end
  enviar(player,p,if npc.id=="vila-1" then "Pegue o sino e volte sem ser visto." else "Encha as três bacias em 90 segundos.")
  return true,"Provação iniciada."
 end
 -- Remoto só para agachar/cancelar. Giros e sino usam prompts, sempre revalidados aqui.
 local remotoConexao=deps.remote.OnServerEvent:Connect(function(player,pedido)
  if type(pedido)~="table" or getmetatable(pedido)~=nil or (pedido.acao~="agachar" and pedido.acao~="cancelar") then return end
  for k in pedido do if k~="acao" and k~="agachado" then return end end
  if pedido.acao=="agachar" and type(pedido.agachado)~="boolean" then return end
  if not taxa(player,"controle",.15) then return end
  local a=ativos[player]
  if not a or not contexto(player,a.s) then return end
  if pedido.acao=="cancelar" then a.p.estado="falhou"; limpar(player,"Provação cancelada, sem custo."); return end
  if a.npcId~="vila-1" or not P.emCurso(a.p,player.UserId) then return end
  local r,h=raiz(player)
  local patio=Layout.PATIO
  if not r or math.abs(r.Position.X-patio.x)>patio.sx/2+10 or math.abs(r.Position.Z-patio.z)>patio.sz/2+10 then return end
  a.p.agachado=pedido.agachado
  local velocidade=Movimento.padroes(StarterPlayer).WalkSpeed
  h.WalkSpeed=if pedido.agachado then math.min(7,velocidade) else velocidade
  player:SetAttribute("ProvacaoAgachado",pedido.agachado)
  enviar(player,a.p)
 end)
 local saidaConexao=Players.PlayerRemoving:Connect(function(player) limpar(player,"Jogador saiu."); limites[player]=nil end)
 local acumulado=0
 local batimento=(deps.heartbeat or RunService.Heartbeat):Connect(function(dt)
  acumulado+=dt; if acumulado<.1 then return end
  local passo=math.min(acumulado,.25); acumulado=0
  local agora=relogio()
  for _,g in mundo.guardas do Guardas.atualizar(g,passo) end
  for player,a in ativos do
   local r=raiz(player)
   if a.salvando or a.s.ocupada or deps.ocupado() then continue end
   if not r or not contexto(player,a.s) then a.p.estado="falhou"; limpar(player,"Provação interrompida, sem custo."); continue end
   if P.expirar(a.p,agora) then limpar(player,"Tempo esgotado. Tente novamente sem custo."); continue end
   if P.aprovado(a.p,player.UserId) then continue end
   if a.npcId=="vila-1" then
    local patio=Layout.PATIO
    if math.abs(r.Position.X-patio.x)>patio.sx/2+12 or math.abs(r.Position.Z-patio.z)>patio.sz/2+12 then
     a.p.estado="falhou"; limpar(player,"Você saiu do pátio. Tente novamente."); continue
    end
    for _,g in mundo.guardas do
     local o,f=g.parte.Position,g.parte.CFrame.LookVector
     local alcance=if a.p.agachado then 10 else 20
     local viu=Cone.detecta({x=o.X,z=o.Z},{x=f.X,z=f.Z},{x=r.Position.X,z=r.Position.Z},alcance,70,function()
      local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
      params.FilterDescendantsInstances={g.parte.Parent}; params.RespectCanCollide=true
      local hit=workspace:Raycast(o+Vector3.new(0,1,0),r.Position-(o+Vector3.new(0,1,0)),params)
      return hit==nil or hit.Instance:IsDescendantOf(player.Character)
     end)
     if viu then
      P.pego(a.p,player.UserId); segura[player]=nil; mundo.mostrarSino(true)
      r.CFrame=CFrame.new(Layout.ENTRADA.x,3,Layout.ENTRADA.z)
      enviar(player,a.p,"Pego! O sino voltou ao pedestal. Tente de novo."); break
     end
    end
   elseif (r.Position-mundo.pecas[3][3].Position).Magnitude>50 then
    a.p.estado="falhou"; limpar(player,"Você se afastou das comportas."); continue
   end
   if not a.ultimoEstado or agora-a.ultimoEstado>=1 then a.ultimoEstado=agora; enviar(player,a.p) end
  end
 end)
 function api.destruir()
  for player in ativos do limpar(player) end
  remotoConexao:Disconnect(); saidaConexao:Disconnect(); batimento:Disconnect(); mundo.destruir()
 end
 return api
end
return S
