-- SOMENTE STUDIO: serviço real, Instances, prompts capturados e relógio determinístico; sem cliente real.
local Shared = game:GetService("ReplicatedStorage").Shared
local Sessao = require(Shared.Regras.RunSessao)
local T = require(Shared.Regras.RunTreinadores)
local C = require(Shared.Regras.ProvacaoComportas)
local Layout = require(Shared.Mundo.TreinadoresLayout)
local Servico = require(script.Parent.Parent.ProvacoesServico)
local Mundo = require(script.Parent.Parent.Mundo.Provacoes)
local function rng() return {NextInteger=function(_,lo) return lo end} end
local function montar()
 local f={agora=100,respostas={}}
 function f.limpar()
  -- Cada recurso é limpo mesmo que uma etapa anterior da limpeza falhe.
  local limpo=not f.api
  if f.api then local ok=pcall(f.api.destruir); limpo=ok end
  if not limpo and f.mundo then pcall(f.mundo.destruir) end
  if f.modelo then pcall(function() f.modelo:Destroy() end) end
  if f.batimento then pcall(function() f.batimento:Destroy() end) end
 end
 local ok,erro=pcall(function()
  local s=Sessao.new({rng=rng(),guardar=function() end})
  assert(s:iniciar("t1-studio",{{userId=7},{userId=8}},{[7]="semArvore",[8]="semArvore"}))
  local modelo=Instance.new("Model",workspace); f.modelo=modelo
  local raiz=Instance.new("Part",modelo); raiz.Name="HumanoidRootPart"; raiz.Anchored=true
  local h=Instance.new("Humanoid",modelo)
  local player={UserId=7,Character=modelo,SetAttribute=function() end}
  -- Remoto falso: BindableEvent copia tabelas ao disparar, e o serviço indexa ativos pela identidade do player.
  local manipuladores={}
  f.remoto={Fire=function(_,...) for _,fn in manipuladores do fn(...) end end}
  local remoto={OnServerEvent={Connect=function(_,fn)
   table.insert(manipuladores,fn)
   return {Disconnect=function() table.remove(manipuladores,table.find(manipuladores,fn)) end}
  end}}
  local batimento=Instance.new("BindableEvent")
  f.batimento=batimento
  local api=Servico.start({
   sessao=function() return s end,ocupado=function() return false end,
   emCombate=function() return false end,transmitir=function() end,
   relogio=function() return f.agora end,rng=rng(),heartbeat=batimento.Event,
   remote={OnServerEvent=remoto.OnServerEvent,FireClient=function(_,_,r) table.insert(f.respostas,r) end},
   criarMundo=function(acoes)
    f.acoes=acoes
    local mundo=Mundo.criar(acoes); f.mundo=mundo
    local mostrar=mundo.grade
    mundo.grade=function(grade) f.grade=grade; mostrar(grade) end
    return mundo
   end,
  })
  f.api,f.s,f.player,f.raiz,f.h=api,s,player,raiz,h
 end)
 if not ok then f.limpar(); error(erro,0) end
 return f
end
local function comFixture(fn)
 local f=montar()
 local ok,erro=pcall(fn,f); f.limpar(); if not ok then error(erro) end
end
return {
 ["B1 provação iniciada com movimento zero restaura padrões ao cancelar"]=function(t)
  comFixture(function(f)
   local config=game:GetService("StarterPlayer")
   f.h.WalkSpeed=0; f.h.JumpPower=0; f.h.JumpHeight=0
   local npc=T.listar(f.s.treinadores)[1]
   t.eq(f.api.iniciar(f.player,f.s,npc),true)
   f.remoto:Fire(f.player,{acao="agachar",agachado=true})
   t.eq(f.h.WalkSpeed,math.min(7,config.CharacterWalkSpeed))
   f.agora+=.2; f.remoto:Fire(f.player,{acao="cancelar"})
   t.eq(f.h.WalkSpeed,config.CharacterWalkSpeed)
   t.eq(f.h.JumpPower,config.CharacterJumpPower); t.eq(f.h.JumpHeight,config.CharacterJumpHeight)
  end)
 end,
 ["T1 sino exige segurar, alcance e retorno; aprovar ensina uma vez sem PA"]=function(t)
  comFixture(function(f)
   local npc=T.listar(f.s.treinadores)[1]
   t.eq(f.api.iniciar(f.player,f.s,npc),true)
   local outro={UserId=8,Character=f.player.Character}
   local ok,msg=f.api.iniciar(outro,f.s,npc)
   t.eq(ok,false); t.eq(msg,"Ocupado — aguarde")
   f.acoes.sino(f.player); t.eq(f.s.provacoes[npc.id].sino,false)
   f.raiz.CFrame=CFrame.new(f.mundo.sino.Position)
   f.acoes.segurarSino(f.player); f.agora+=1
   f.acoes.sino(f.player); t.eq(f.s.provacoes[npc.id].sino,false)
   f.agora+=.6; f.acoes.sino(f.player); t.eq(f.s.provacoes[npc.id].sino,true)
   f.acoes.portao(f.player); t.eq(f.s.planos[7].escolhida,nil,"longe do portão")
   f.raiz.CFrame=CFrame.new(Layout.PORTAO.x,3,Layout.PORTAO.z)
   f.acoes.portao(f.player)
   t.eq(f.s.planos[7].escolhida,npc.arvore); t.eq(f.s.run.dia,1); t.eq(f.s.planos[7].paExtra,2)
   f.acoes.portao(f.player); t.eq(f.s.run.dia,1)
  end)
 end,
 ["T1 comportas rejeita giro distante e rapido, valida prazo e salva solução"]=function(t)
  comFixture(function(f)
   local npc=T.listar(f.s.treinadores)[2]
   t.eq(f.api.iniciar(f.player,f.s,npc),true)
   local p=f.mundo.pecas[3][1]
   f.raiz.CFrame=CFrame.new(p.Position+Vector3.new(13,0,0))
   local original=f.grade[3][1].rotacao
   f.acoes.girar(f.player,3,1,p); t.eq(f.grade[3][1].rotacao,original)
   f.raiz.CFrame=CFrame.new(p.Position+Vector3.new(0,3,0))
   f.acoes.girar(f.player,3,1,p); t.eq(f.grade[3][1].rotacao,(original+1)%4)
   f.acoes.girar(f.player,3,1,p); t.eq(f.grade[3][1].rotacao,(original+1)%4)
   local _,solucao=C.gerar(rng())
   for i=1,5 do
    if f.s.planos[7].escolhida then break end
    for j=1,5 do
     if f.s.planos[7].escolhida then break end
     local passos=(solucao[i][j].rotacao-f.grade[i][j].rotacao)%4
     for _=1,passos do
      f.agora+=.2
      local peca=f.mundo.pecas[i][j]
      f.raiz.CFrame=CFrame.new(peca.Position+Vector3.new(0,3,0))
      f.acoes.girar(f.player,i,j,peca)
     end
    end
   end
   t.eq(f.s.planos[7].escolhida,"agua"); t.eq(f.s.run.dia,1); t.eq(f.s.planos[7].paExtra,2)
  end)
 end,
 ["T1 tempo expirado e cancelamento liberam vaga sem cobrar"]=function(t)
  comFixture(function(f)
   local npc=T.listar(f.s.treinadores)[2]
   -- A expiração é o comportamento sob teste; mantenha o personagem dentro da área
   -- para que o heartbeat não encerre a tentativa pelo limite de afastamento.
   f.raiz.CFrame=CFrame.new(f.mundo.pecas[3][3].Position+Vector3.new(0,3,0))
   t.eq(f.api.iniciar(f.player,f.s,npc),true)
   f.agora+=90
   -- Repita ticks menores durante a espera: não atribuímos a falha original
   -- à serialização de .1 sem evidência do valor recebido pelo handler.
   local limite=os.clock()+1
   while f.s.provacoes[npc.id].estado=="em-curso" and os.clock()<limite do
    f.batimento:Fire(.05)
    task.wait(.03)
   end
   t.eq(f.s.provacoes[npc.id].estado,"livre")
   t.eq(f.respostas[#f.respostas].estado,"falhou","o handler deve responder antes de liberar a vaga")
   t.eq(f.respostas[#f.respostas].mensagem,"Tempo esgotado. Tente novamente sem custo.")
   t.eq(f.s.run.dia,0); t.eq(f.s.planos[7].escolhida,nil)
   t.eq(f.api.iniciar(f.player,f.s,npc),true)
   f.remoto:Fire(f.player,{acao="cancelar"})
   limite=os.clock()+1
   while f.s.provacoes[npc.id].estado=="em-curso" and os.clock()<limite do task.wait(.03) end
   t.eq(f.s.provacoes[npc.id].estado,"livre"); t.eq(f.s.run.dia,0)
  end)
 end,
}
