-- NPCs R15 da run. Sem scripts importados; identidade e oferta vêm só da sessão.
local Players = game:GetService("Players")
local Regras = require(game:GetService("ReplicatedStorage").Shared.Regras.RunTreinadores)
local Aparencia = require(script.Parent.TreinadoresAparencia)
local Visual = require(script.Parent.NpcVisual)
local Catalogo = require(game:GetService("ReplicatedStorage").Shared.Livro.Catalogo)
local Mundo = {}

function Mundo.start(abrir)
	local atual, pasta, geracao = nil, nil, 0
	local corpos = {}
	local api = {}
	function api.atualizar(sessao)
		local nova = sessao and sessao.run and not sessao.run.fim and sessao or nil
		if atual == nova then return end
		atual, geracao = nova, geracao + 1
		local versao = geracao
		if pasta then pasta:Destroy(); pasta = nil end
		corpos = {}
		if not nova then return end
		local vila = workspace:FindFirstChild("Vila")
		if not vila then warn("[Treinadores] Vila ausente."); return end
		pasta = Instance.new("Folder"); pasta.Name = "TreinadoresRun"; pasta.Parent = vila
		local destino = pasta
		for _, npc in Regras.listar(nova.treinadores) do
			task.spawn(function()
				local descricao = Instance.new("HumanoidDescription")
				Aparencia.descrever(descricao, npc.arvore)
    local ok, corpo = pcall(Players.CreateHumanoidModelFromDescription, Players, descricao, Enum.HumanoidRigType.R15)
				descricao:Destroy()
				if not ok then warn("[Treinadores] Rig indisponível: " .. npc.id); return end
				if versao ~= geracao or not destino.Parent then corpo:Destroy(); return end
				for _, item in corpo:GetDescendants() do
					if item:IsA("LuaSourceContainer") then item:Destroy() end
				end
				local humanoide = corpo:FindFirstChildOfClass("Humanoid")
				local raiz = corpo:FindFirstChild("HumanoidRootPart")
				if not humanoide or not raiz then corpo:Destroy(); return end
				corpo.Name = Regras.titulo(npc.arvore) or npc.arvore
				humanoide.DisplayName = corpo.Name
				humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				local entrada = Catalogo.POR_ID["tree/" .. npc.arvore]
				Visual.nome(corpo, corpo.Name, if entrada then entrada.data.name else npc.arvore)
				for _, parte in corpo:GetDescendants() do
					if parte:IsA("BasePart") then parte.Anchored = parte == raiz; parte.CanCollide = false end
				end
				local p = npc.ponto
				local pos = Vector3.new(p.x, (if npc.arvore == "agua" then require(game:GetService("ReplicatedStorage").Shared.Mundo.TreinadoresLayout).nivelAgua() else 0) + humanoide.HipHeight + raiz.Size.Y / 2, p.z)
				local grade = require(game:GetService("ReplicatedStorage").Shared.Mundo.TreinadoresLayout).grade()
                local alvo = if npc.arvore == "agua" then Vector3.new(grade.x, pos.Y, grade.z) else Vector3.new(0, pos.Y, -175)
                corpo:PivotTo(CFrame.lookAt(pos, alvo))
				corpo:SetAttribute("TreinadorId", npc.id)
				corpo:SetAttribute("Arvore", npc.arvore)
				corpo:SetAttribute("AreaId", "region/vila/treinador/" .. npc.id)
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name, prompt.ActionText, prompt.ObjectText = "Falar", "Falar", corpo.Name
				prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0, 10, false
				prompt.Parent = raiz
				Aparencia.aplicar(corpo,npc.arvore)
    if versao ~= geracao or not destino.Parent then corpo:Destroy(); return end
    corpo.Parent = destino
				corpos[npc.id] = { sessao = nova, corpo = corpo, arvore = npc.arvore }
				local animador = humanoide:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoide)
				local anim = Instance.new("Animation"); anim.AnimationId = "rbxassetid://507766388"
				local carregou, faixa = pcall(function() return animador:LoadAnimation(anim) end)
				anim:Destroy()
				if carregou and faixa and corpo.Parent then faixa.Looped = true; faixa:Play() end
			end)
		end
	end
	function api.obter(sessao, id)
		local npc = corpos[id]
		if npc and npc.sessao == sessao and npc.corpo.Parent then return npc end
		return nil
	end
	return api
end

return Mundo
