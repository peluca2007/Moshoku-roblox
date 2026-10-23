-- Transporte exclusivo do editor. A1 mantém a autoridade e o contrato remoto.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Prompts=game:GetService("ProximityPromptService")
local Editor=require(script.Parent.AparenciaEditor)
local C=require(script.Parent.UI.Componentes)
local Fluxo={}
local instancia
function Fluxo.start()
 if instancia then return instancia end
 local pai=Players.LocalPlayer:WaitForChild("PlayerGui")
 local avisos=Instance.new("ScreenGui")
 avisos.Name="AparenciaAvisos"; avisos.ResetOnSpawn=false; avisos.DisplayOrder=80
 avisos.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; avisos.Parent=pai
 local remote,pendente,editor=nil,nil,nil
 local ultimo=0
 local function aviso(texto,tipo)
  C.aviso({parent=avisos,tipo=tipo or "perigo",titulo=if tipo=="sucesso" then "Aparência salva" else "Aparência",detalhe=texto,duracao=6})
 end
 local function pedir(payload,callback)
  if not remote or pendente then aviso("Aguarde a conexão ou a confirmação anterior."); return false end
  pendente=callback
  task.delay(math.max(0,0.55-(os.clock()-ultimo)),function()
   if pendente~=callback then return end
   ultimo=os.clock(); remote:FireServer(payload)
   task.delay(15,function()
    if pendente~=callback then return end
    -- Sem requestId no A1, conservar a operação até a resposta, inclusive tardia.
    aviso("A confirmação está demorando. Aguarde antes de tentar novamente.")
   end)
  end)
  return true
 end
 local api={}
 function api.editar(raceId,a,possuidos,aoPronto,aoFechar)
  if editor then editor.fechar() end
  editor=Editor.abrir({parent=pai,raceId=raceId,aparencia=a,possuidos=possuidos,
   aoPronto=aoPronto,aoFechar=function() editor=nil; if aoFechar then aoFechar() end end})
  return editor
 end
 function api.salvar(a,callback)
  return pedir({acao="salvar",aparencia=a},function(ok,resultado)
   if not ok then aviso(tostring(resultado)) end
   if callback then callback(ok,resultado) end
  end)
 end
 function api.fechar() if editor then editor.fechar() end end
 task.spawn(function()
  remote=ReplicatedStorage:WaitForChild("aparencia")
  remote.OnClientEvent:Connect(function(resposta)
   if not pendente or type(resposta)~="table" then return end
   local cb=pendente; pendente=nil
   cb(resposta.ok==true,resposta.resultado)
  end)
 end)
 Prompts.PromptTriggered:Connect(function(prompt,jogador)
  if jogador and jogador~=Players.LocalPlayer then return end
  if prompt.Name~="EditarAparencia" or not prompt:IsDescendantOf(workspace) or editor then return end
  pedir({acao="consultar"},function(ok,dados)
   if not ok then aviso(tostring(dados)); return end
   api.editar(dados.raceId,dados.aparencia,dados.possuidos,function(a,fechar)
    local atual=editor
    if atual then atual.ocupado(true) end
    local enviado=api.salvar(a,function(salvo)
     if salvo then fechar(); aviso("Sua aparência foi atualizada.","sucesso")
     elseif atual then atual.ocupado(false) end
    end)
    if not enviado and atual then atual.ocupado(false) end
   end)
  end)
 end)
 task.spawn(function()
  ReplicatedStorage:WaitForChild("RunJogo").OnClientEvent:Connect(function(tipo,dados)
   if tipo~="lootRaro" or type(dados)~="table" then return end
   C.aviso({parent=avisos,tipo="sucesso",icone="✦",titulo="LOOT RARO · "..tostring(dados.nome or dados.peca),
    detalhe=string.upper(tostring(dados.raridade or "rara")).." · Experimente no espelho da vila",duracao=8})
  end)
 end)
 instancia=api
 return api
end
return Fluxo
