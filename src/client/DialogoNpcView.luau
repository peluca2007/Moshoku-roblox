-- Um único Falar por rig; as opções enviam apenas intenções já existentes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prompts = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local C = require(script.Parent.UI.Componentes)
local Estado = require(script.Parent.DialogoNpcEstado)
local Dados = require(ReplicatedStorage.Shared.Mundo.NpcsDados)
local View = {}
local SAUDACOES = {
 ["mestre-dojo"] = "Bem-vindo ao dojo. Deseja conversar ou treinar?",
 ["taverneira"] = "Bem-vindo à Taverna do Caminho. Deseja conversar, ver as missões ou negociar?",
 ["ferreiro"] = "Bem-vindo à forja. Deseja conversar ou ver meus equipamentos?",
}
function View.start(state)
 local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
 local gui = Instance.new("ScreenGui")
 gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Enabled = "ConversaNpc", false, 44, false
 gui.Parent = playerGui
 local painel, conexao, combate
 local function fechar()
  gui.Enabled = false
  Estado.fechar()
  if painel then painel:Destroy(); painel = nil end
 end
 conexao = Prompts.PromptTriggered:Connect(function(prompt, jogador)
  if jogador and jogador ~= Players.LocalPlayer then return end
  if prompt.Name ~= "Falar" or Players.LocalPlayer:GetAttribute("InterfaceCombate") then return end
  local rig = prompt:FindFirstAncestorOfClass("Model")
  if not rig then return end
  local id, treinador = rig:GetAttribute("NpcId"), rig:GetAttribute("TreinadorId")
  if not id and not treinador then return end
  fechar()
  if id == "taverneira" then Estado.iniciar() end
  local npc
  for _, item in Dados.LISTA do if item.id == id then npc = item; break end end
  local function perto()
   local char = Players.LocalPlayer.Character
   local root = char and char:FindFirstChild("HumanoidRootPart")
   local alvo = rig:FindFirstChild("HumanoidRootPart")
   local hum = char and char:FindFirstChildOfClass("Humanoid")
   return root and alvo and hum and hum.Health > 0 and (root.Position-alvo.Position).Magnitude <= prompt.MaxActivationDistance
  end
  local opcoes = {}
  local function opcao(texto, executar)
   table.insert(opcoes, { texto = texto, aoClicar = function()
    if not perto() then fechar(); return end
    executar()
   end })
  end
  opcao("Conversar", function()
   if painel then
    for _, label in painel.Conteudo:GetChildren() do
     if label:IsA("TextLabel") and label.LayoutOrder == 2 then
      label.Text = if npc then Dados.fala(npc, 2) else "Quando estiver pronto, pergunte pela provação."
     end
    end
   end
  end)
  if treinador then
   opcao("Treinar", function()
    fechar()
    ReplicatedStorage.TreinadorJogo:FireServer({ acao = "consultar", npcId = treinador, requestId = HttpService:GenerateGUID(false) })
   end)
  elseif id == "mestre-dojo" then
   opcao("Treinar no dojo", function() fechar(); ReplicatedStorage.Dojo:FireServer({ acao = "consultar" }) end)
  elseif id == "taverneira" or id == "ferreiro" then
   opcao("Comprar / Vender", function() fechar(); state.send("lojaListar", { npcId = id }) end)
   if id == "taverneira" then
    opcao("Missões", function()
     local recebido = Estado.escolher()
     gui.Enabled = false
     if painel then painel:Destroy(); painel = nil end
     local missoes = playerGui:FindFirstChild("MissoesPessoais")
     if recebido and missoes then missoes.Enabled = true end
    end)
   end
  end
  table.insert(opcoes, { texto = "Sair", aoClicar = fechar })
  painel = C.dialogoNpc({ parent = gui, nomeNpc = rig.Name,
   fala = SAUDACOES[id] or "Bem-vindo. Deseja conhecer minha provação?", opcoes = opcoes })
  C.aplicarEscala(painel)
  gui.Enabled = true
 end)
 combate = Players.LocalPlayer:GetAttributeChangedSignal("InterfaceCombate"):Connect(function()
  if Players.LocalPlayer:GetAttribute("InterfaceCombate") then fechar() end
 end)
 gui.Destroying:Connect(function() conexao:Disconnect(); combate:Disconnect(); Estado.fechar() end)
 return gui
end
return View
