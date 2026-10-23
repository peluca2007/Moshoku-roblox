-- Construção física T1; regras e permissóes ficam em ProvacoesServico.
local Shared = game:GetService("ReplicatedStorage").Shared
local Patio = require(script.Parent.PatioLadino)
local M = {}
function M.criar(acoes)
 local pasta = Instance.new("Folder", workspace); pasta.Name = "ProvacoesTreinadores"
 local ok,resultado=pcall(function()
 local function prompt(p, nome, seg, callback)
  local q = Instance.new("ProximityPrompt", p)
  q.ActionText, q.ObjectText, q.HoldDuration = nome, p.Name, seg
  -- Sem linha de visão: a CameraMundo (alta, diagonal) olha por cima do telhado do campanário e escondia o prompt do sino.
  -- O servidor continua validando alcance e contexto em cada ação.
  q.MaxActivationDistance, q.RequiresLineOfSight = 8, false
  q.Triggered:Connect(callback)
  return q
 end
 local patio=Patio.criar(pasta)
 local gate,sino,guardas=patio.gate,patio.sino,patio.guardas
 local segurar = prompt(sino,"Pegar sino",1.5,acoes.sino)
 segurar:SetAttribute("ProvacaoLadino","sino"); segurar.Enabled=false
 segurar.PromptButtonHoldBegan:Connect(acoes.segurarSino)
 local voltar=prompt(gate,"Voltar com sino",0,acoes.portao)
 voltar:SetAttribute("ProvacaoLadino","portao"); voltar.Enabled=false
 local jardim=require(script.Parent.JardimAgua).criar(pasta,acoes.girar,prompt)
 local api={pasta=pasta,guardas=guardas,sino=sino,pecas=jardim.pecas,gate=gate}
 function api.mostrarSino(tem) patio.mostrarSino(tem) end
 function api.grade(grade) jardim.grade(grade) end
 function api.canais(ligado) jardim.ativar(ligado) end
 function api.destruir() pasta:Destroy() end
 return api
 end)
 if not ok then pasta:Destroy(); error(resultado,0) end
 return resultado
end
return M
