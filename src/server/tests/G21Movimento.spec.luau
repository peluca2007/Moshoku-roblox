-- Política pura compartilhada pelo bloqueio cliente e pela restauração da provação.
local B=require(game:GetService("ReplicatedStorage").Shared.MovimentoPersonagem)
local function padroes() return {WalkSpeed=16,JumpPower=50,JumpHeight=7.2} end
return {
 ["motivos sobrepostos e repetidos liberam somente na última chave"]=function(t)
  for _,ordem in {{"consulta","tabuleiro"},{"tabuleiro","consulta"}} do
   local h={WalkSpeed=0,JumpPower=0,JumpHeight=0}
   local definir=B.new(function() return h end,padroes)
   definir(ordem[1],true); definir(ordem[1],true); definir(ordem[2],true)
   definir(ordem[1],false); t.eq(h.WalkSpeed,0); t.eq(h.JumpPower,0)
   definir(ordem[2],false); t.eq(h.WalkSpeed,16); t.eq(h.JumpPower,50); t.eq(h.JumpHeight,7.2)
  end
 end,
 ["respawn herda motivos sem copiar zero do corpo anterior"]=function(t)
  local antigo={WalkSpeed=0,JumpPower=0,JumpHeight=0}; local h=antigo
  local definir,atualizar=B.new(function() return h end,padroes)
  definir("consulta",true); h={WalkSpeed=0,JumpPower=0,JumpHeight=0}; atualizar()
  t.eq(antigo.WalkSpeed,16); t.eq(h.WalkSpeed,0)
  definir("consulta",false); t.eq(h.WalkSpeed,16); t.eq(h.JumpPower,50)
 end,
 ["ausência de personagem e liberação estranha não inventam bloqueio"]=function(t)
  local h=nil; local definir,atualizar=B.new(function() return h end,padroes)
  definir("dialogo",true); h={WalkSpeed=0,JumpPower=0,JumpHeight=0}; atualizar()
  definir("outro",false); t.eq(h.WalkSpeed,0)
  definir("dialogo",false); t.eq(h.WalkSpeed,16)
  h.WalkSpeed=7; definir("ausente",false); t.eq(h.WalkSpeed,7)
 end,
 ["restaurar provação usa configuração e recupera ambos os modos de salto"]=function(t)
  local p=B.padroes({CharacterWalkSpeed=18,CharacterJumpPower=55,CharacterJumpHeight=8})
  local h={WalkSpeed=0,JumpPower=0,JumpHeight=0}; B.restaurar(h,p)
  t.eq(h.WalkSpeed,18); t.eq(h.JumpPower,55); t.eq(h.JumpHeight,8)
 end,
}
