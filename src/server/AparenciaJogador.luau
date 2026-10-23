-- A1: apresentação autoritativa; nenhuma estatística da ficha é modificada.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Regras = require(Shared.Aparencia.Aparencia)
local Catalogo = require(Shared.Aparencia.Catalogo)
local Layout = require(Shared.Mundo.VilaLayout)
local Montar = require(script.Parent.Mundo.MontarModelo)
local Servico = { REMOTE = "aparencia" }

local Visual = require(Shared.Aparencia.Visual)
Servico.descrever, Servico.decorar = Visual.descrever, Visual.decorar

-- Fronteira testável: criação é uma janela AUTORITATIVA, nunca um flag do payload.
function Servico.criarHandler(deps)
	local sessoes = {}
	local function processar(player, pedido)
		if not deps.autenticado(player) then return false, "Conexão inválida." end
		local uid, instante = player.UserId, deps.relogio()
		local s = sessoes[uid] or {}; sessoes[uid] = s
		if s.ocupado or (s.ultimo and instante - s.ultimo < 0.5) then return false, "Aguarde." end
		s.ultimo = instante
		if type(pedido) ~= "table" or getmetatable(pedido) ~= nil then return false, "Pedido inválido." end
		for k in pedido do if k ~= "acao" and k ~= "aparencia" then return false, "Campo inválido." end end
		if pedido.acao ~= "consultar" and pedido.acao ~= "salvar" then return false, "Ação inválida." end
		if pedido.acao == "consultar" and pedido.aparencia ~= nil then return false, "Consulta inválida." end
		if pedido.acao == "salvar" and type(pedido.aparencia) ~= "table" then return false, "Aparência inválida." end
		local function autorizado() return deps.autenticado(player) and not deps.emCombate(player) and deps.contexto(player) end
		if not autorizado() then return false, "Use a criação ou o espelho fora de combate." end
		local perfil = deps.consultar(player)
		if not perfil then return false, "Crie a ficha primeiro." end
		s.ocupado = true
		local ok, sucesso, resultado = pcall(function()
			local conta = deps.conta.obter(uid)
			if not conta or not autorizado() then return false, "Conta/contexto indisponível." end
			local possuidos = conta.cosmeticos or {}
			if pedido.acao == "consultar" then return true, { aparencia = perfil.aparencia, possuidos = possuidos, raceId = perfil.construcao.raceId } end
			local valida, motivo = Regras.validar(pedido.aparencia, perfil.construcao.raceId, possuidos)
			if not valida then return false, motivo end
			return deps.alterar(player, pedido.aparencia, possuidos, autorizado)
		end)
		s.ocupado = false
		if not ok then return false, "Falha ao salvar aparência." end
		return sucesso, resultado
	end
	return processar, function(p) sessoes[p.UserId] = nil end
end

local function espelho()
	local p = Layout.ESPELHO
	if workspace:FindFirstChild("EspelhoMoshoku") then return end
	local cf = CFrame.new(p.x, 2, p.z)
	if Montar.existe(p.modulo) then
		local m = Montar.montar(p.modulo, workspace, cf, 1); m.Name = "EspelhoMoshoku"
	else
		local bloco = Instance.new("Part")
		bloco.Name, bloco.Size, bloco.CFrame = "EspelhoMoshoku", Vector3.new(2,4,0.3), cf
		bloco.Anchored, bloco.Material, bloco.Color = true, Enum.Material.Glass, Color3.fromRGB(165,205,220)
		bloco.Parent = workspace
	end
 local esp = workspace:FindFirstChild("EspelhoMoshoku")
 local alvo = if esp and esp:IsA("BasePart") then esp else esp and esp:FindFirstChildWhichIsA("BasePart", true)
 if alvo then
  local prompt = Instance.new("ProximityPrompt")
  prompt.Name, prompt.ActionText, prompt.ObjectText = "EditarAparencia", "Mudar aparência", "Espelho da vila"
  prompt.MaxActivationDistance, prompt.RequiresLineOfSight = p.alcance, false
  prompt.Parent = alvo
 end
end

function Servico.start(deps)
	-- Replica somente os dados visuais conhecidos do catalogo.
 local modelos = Shared.Aparencia:FindFirstChild("Modelos") or Instance.new("Folder")
 modelos.Name, modelos.Parent = "Modelos", Shared.Aparencia
 local moldes = Shared.Aparencia:FindFirstChild("MoldesVisuais") or Instance.new("Folder")
 moldes.Name, moldes.Parent = "MoldesVisuais", Shared.Aparencia
 local origem = script.Parent.Mundo.Modelos
 for _, lista in {Catalogo.PECAS, Catalogo.CABELOS, Catalogo.BARBAS} do
  for _, item in lista do
   local id = item.modulo
   local fonte = id and origem:FindFirstChild(id)
   if fonte and fonte:IsA("ModuleScript") and not modelos:FindFirstChild(id) then fonte:Clone().Parent = modelos end
   if fonte and not moldes:FindFirstChild(id) then
    local molde = Montar.montar(id, moldes, CFrame.new(), 1)
    molde.Name = id
   end
  end
 end
 local mesa, encontro = deps.mesa, deps.encontro
	local conta = deps.conta or require(script.Parent.ContaServico).start()
	local remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = Servico.REMOTE, ReplicatedStorage
	local estados, criacao = {}, {}
	local function conectado(p) return p.Parent == Players and Players:GetPlayerByUserId(p.UserId) == p end
	local function combate(p)
		local h = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		return mesa.emCombate() or encontro.emEncontroAtivo() or (h and h.Anchored) == true
	end
	local function contexto(p)
		if criacao[p] and os.clock() < criacao[p] then return true end
		local h = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local v = Layout.ESPELHO
		return h ~= nil and (h.Position - Vector3.new(v.x,2,v.z)).Magnitude <= v.alcance
	end
	local function atualizar(p)
		local s = estados[p]
		if not s then return end
		s.versao += 1
		if s.aplicando then return end
		s.aplicando = true
		task.spawn(function()
			local ok, erro = pcall(function()
				repeat
					local versao = s.versao
					local corpo = p.Character
					local hum = corpo and corpo:FindFirstChildOfClass("Humanoid")
					if hum and conectado(p) and not combate(p) then
						local perfil = mesa.consultarPerfilPessoal(p)
						local raceId = perfil and perfil.construcao.raceId or "race/humano"
						local a = perfil and perfil.aparencia or Regras.padrao(raceId, p.UserId)
						local c = conta.obter(p.UserId)
						if not c then break end -- erro de conta nunca concede peça
						if not Regras.validar(a, raceId, c.cosmeticos or {}) then a = Regras.padrao(raceId,p.UserId) end
						if not conectado(p) or p.Character ~= corpo or s.versao ~= versao or combate(p) then continue end
						local d = Servico.descrever(a, raceId)
						if hum.RigType ~= Enum.HumanoidRigType.R15 then
							local novo = Players:CreateHumanoidModelFromDescriptionAsync(d, Enum.HumanoidRigType.R15)
							if not conectado(p) or p.Character ~= corpo or combate(p) then novo:Destroy(); d:Destroy(); break end
							novo.Name = p.Name; novo:PivotTo(corpo:GetPivot())
							local animar = corpo:FindFirstChild("Animate")
							if animar then animar:Clone().Parent = novo end
							novo.Parent = workspace; p.Character = novo; corpo:Destroy(); corpo = novo
						else
							hum:ApplyDescriptionResetAsync(d)
						end
						d:Destroy()
						if conectado(p) and p.Character == corpo and not combate(p) then Servico.decorar(corpo,a,raceId) end
					end
				until s.versao == versao or not conectado(p)
			end)
			s.aplicando = false
			if not ok then warn("[Aparencia] " .. tostring(erro)) end
		end)
	end
	mesa.observarPerfilPessoal(function(p, perfil, tipo)
		if tipo == "criacao" then criacao[p] = os.clock() + 60 end
		-- Evita remontar o avatar a cada consulta de ficha/compra/descanso.
		local s = estados[p]
		local assinatura = perfil and game:GetService("HttpService"):JSONEncode({perfil.construcao.raceId,perfil.aparencia}) or ""
		if s and s.assinatura ~= assinatura then s.assinatura = assinatura; atualizar(p) end
	end)
	local processar, remover = Servico.criarHandler({autenticado=conectado,relogio=os.clock,emCombate=combate,contexto=contexto,
		consultar=mesa.consultarPerfilPessoal,alterar=mesa.alterarAparenciaPessoal,conta=conta})
	remote.OnServerEvent:Connect(function(p, pedido)
		local ok, resultado = processar(p,pedido)
		if conectado(p) then remote:FireClient(p, {ok=ok,resultado=resultado}) end
	end)
	local function entrou(p)
		estados[p] = {versao=0}
		p.CharacterAdded:Connect(function(c) c:WaitForChild("Humanoid",10); atualizar(p) end)
		p.CharacterAppearanceLoaded:Connect(function() atualizar(p) end)
		if p.Character then atualizar(p) end
	end
	Players.PlayerAdded:Connect(entrou)
	Players.PlayerRemoving:Connect(function(p) remover(p); estados[p],criacao[p] = nil,nil end)
	for _, p in Players:GetPlayers() do entrou(p) end
	espelho()
	return { atualizar = atualizar }
end
return Servico
