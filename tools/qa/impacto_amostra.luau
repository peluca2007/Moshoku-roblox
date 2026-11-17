-- IMP3: amostrador de enquadramento e corpos duplicados. Roda @DUR@ s em segundo plano (task.spawn) e grava o
-- resultado no atributo QaEnquadre do Workspace: "rodando" enquanto amostra, depois uma linha por quadro:
-- t | peso da câmera | separação em tela (fração da largura) entre atacante e alvo | cabeças visíveis do jogador.
local DUR = @DUR@
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local cam = workspace.CurrentCamera
local ch = Players.LocalPlayer.Character
workspace:SetAttribute("QaEnquadre", "rodando")
local function visivel(p: BasePart): boolean
	return p.Transparency < 0.95 and p.LocalTransparencyModifier < 0.95
end
task.spawn(function()
	local t0, linhas, detalhe, despejado = os.clock(), {}, nil, false
	workspace:SetAttribute("QaEnquadreDetalhe", nil)
	while os.clock() - t0 < DUR do
		RS.RenderStepped:Wait()
		local corpos = workspace:FindFirstChild("CorposDeCriatura")
		local alvo, melhor
		for _, m in (corpos and corpos:GetChildren() or {}) do
			if m:IsA("Model") then
				local d = (m:GetPivot().Position - ch.HumanoidRootPart.Position).Magnitude
				if not melhor or d < melhor then melhor, alvo = d, m end
			end
		end
		local sep = -1
		if alvo then
			local a, oa = cam:WorldToViewportPoint(ch.HumanoidRootPart.Position + Vector3.new(0, 2, 0))
			local b, ob = cam:WorldToViewportPoint(alvo:GetPivot().Position + Vector3.new(0, 1.5, 0))
			-- os dois precisam aparecer na tela; fora dela a separação conta como 0 (reprova)
			sep = if oa and ob then (Vector2.new(a.X, a.Y) - Vector2.new(b.X, b.Y)).Magnitude / cam.ViewportSize.X else 0
		end
		-- enquadramento completo: topo e base das caixas dos dois lutadores dentro da tela (margem de 3%)
		local inteiro = 1
		if alvo then
			local vp = cam.ViewportSize
			for _, m in { ch, alvo } do
				local cf, tam = m:GetBoundingBox()
				for _, dy in { -0.5, 0.5 } do
					local v, on = cam:WorldToViewportPoint((cf * CFrame.new(0, dy * tam.Y, 0)).Position)
					if not on or v.X < vp.X * 0.03 or v.X > vp.X * 0.97 or v.Y < vp.Y * 0.03 or v.Y > vp.Y * 0.97 then inteiro = 0 end
				end
			end
		else
			inteiro = 0
		end
		local cabecas, av, fan = 0, 0, 0
		-- corpo do avatar visível = qualquer peça dele (cabeça, cabelo, arma...) com transparência local < 0,95
		for _, d in ch:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and visivel(d) then av = 1 break end
		end
		cabecas += av
		for _, f in workspace:GetDescendants() do
			if f:IsA("Model") and f.Name == "Fantasma" and f:GetAttribute("FantasmaDe") == ch.Name then
				local fh = f:FindFirstChild("Head")
				if fh and fh:IsA("BasePart") and visivel(fh) then cabecas += 1 fan += 1 end
			end
		end
		if av == 1 and fan >= 1 and not detalhe then
			local v = {}
			for _, d in ch:GetDescendants() do
				if d:IsA("BasePart") and visivel(d) then table.insert(v, d.Name .. ":" .. d.LocalTransparencyModifier) end
			end
			detalhe = "avatar visível com fantasma: " .. table.concat(v, ",")
			workspace:SetAttribute("QaEnquadreDetalhe", detalhe)
		end
		if (workspace:GetAttribute("ImpactoPeso") or 0) >= 0.8 and not despejado then
			despejado = true
			local v = {}
			for _, d in workspace:GetDescendants() do
				if d:IsA("BasePart") and (d.Name == "Head" or d.Name == "Cabelo" or d.Name == "Ferro") and visivel(d)
					and (d.Position - ch.HumanoidRootPart.Position).Magnitude < 25 then
					table.insert(v, d:GetFullName() .. " ltm=" .. d.LocalTransparencyModifier .. " t=" .. d.Transparency)
				end
			end
			workspace:SetAttribute("QaCabecas", table.concat(v, " ;; "))
		end
		table.insert(linhas, string.format("%.2f|%.2f|%.3f|%d|%d|%d|%d", os.clock() - t0, (workspace:GetAttribute("ImpactoPeso") or 0), sep, cabecas, av, fan, inteiro))
	end
	workspace:SetAttribute("QaEnquadre", table.concat(linhas, ";"))
end)
return "ok"
