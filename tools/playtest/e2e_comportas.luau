-- Cliente (execute_luau, Play): joga as Comportas da Mestra da Água como um jogador.
-- Pré-requisito: run ativa, provação da Mestra aceita. Lê a grade pelos blocos visuais (cada lado sem "Borda do canal"
-- é uma abertura), resolve com o módulo puro ProvacaoComportas e gira cada peça pelo ProximityPrompt, caminhando
-- até ficar sobre a peça (OnePerButton: só o prompt mais próximo aparece). Progresso em _G.COMPORTAS.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Regras.ProvacaoComportas)
local P = game.Players.LocalPlayer
local pasta = workspace.ProvacoesTreinadores
_G.COMPORTAS = { log = {}, fase = "lendo", fim = false }
local function log(m) table.insert(_G.COMPORTAS.log, string.format("%.1f %s", os.clock() % 1000, m)) end

task.spawn(function()
	local ok, err = pcall(function()
		-- 1. grade atual a partir das peças visuais
		local grade = {}
		local TIPOS = { "tampao", "reto", "curva", "T", "cruz" }
		for i = 1, 5 do
			grade[i] = {}
			for j = 1, 5 do
				local peca = pasta["Canal " .. i .. ":" .. j]
				local fechados = { false, false, false, false }
				-- índice do visual: Folder CanalVisual na mesma ordem de criação; localiza por proximidade
				for _, f in pasta:GetChildren() do
					if f:IsA("Folder") and f.Name == "CanalVisual" then
						local alguma
						for _, b in f:GetChildren() do alguma = b break end
						if alguma and math.abs(alguma.Position.X - peca.Position.X) < 2 and math.abs(alguma.Position.Z - peca.Position.Z) < 2 then
							for _, b in f:GetChildren() do
								if b.Name == "Borda do canal" then
									local dx, dz = b.Position.X - peca.Position.X, b.Position.Z - peca.Position.Z
									if dz < -0.5 then fechados[1] = true elseif dx > 0.5 then fechados[2] = true elseif dz > 0.5 then fechados[3] = true else fechados[4] = true end
								end
							end
							break
						end
					end
				end
				local alvo
				for _, tipo in TIPOS do
					for r = 0, 3 do
						local ab = C.aberturas({ tipo = tipo, rotacao = r })
						local igual = true
						for d = 1, 4 do if (ab[d] == true) == fechados[d] then igual = false end end
						if igual and not alvo then alvo = { tipo = tipo, rotacao = r } end
					end
				end
				grade[i][j] = alvo
			end
		end
		for i = 1, 5 do for j = 1, 5 do assert(grade[i][j], "peça sem tipo " .. i .. ":" .. j) end end
		-- 2. resolve por subida de encosta com reinícios
		local rnd = Random.new(7)
		local function pontos(g)
			local alc = C.conexoes(g)
			local n = 0
			for _ in alc do n += 1 end
			local b = C.bacias(g)
			local cheias = 0
			for _, v in b do if v then cheias += 1 end end
			return cheias * 1000 + n, cheias
		end
		local melhor, melhorPts
		for tentativa = 1, 300 do
			local g = {}
			for i = 1, 5 do g[i] = {} for j = 1, 5 do g[i][j] = { tipo = grade[i][j].tipo, rotacao = rnd:NextInteger(0, 3) } end end
			local pts, cheias = pontos(g)
			local melhorou = true
			while melhorou and cheias < 3 do
				melhorou = false
				for i = 1, 5 do for j = 1, 5 do for r = 0, 3 do
					local velha = g[i][j].rotacao
					g[i][j].rotacao = r
					local p2, c2 = pontos(g)
					if p2 > pts then pts, cheias, melhorou = p2, c2, true else g[i][j].rotacao = velha end
				end end end
			end
			if cheias == 3 then melhor = g break end
		end
		assert(melhor, "sem solução")
		-- 3. giros necessários
		local fila, total = {}, 0
		for i = 1, 5 do for j = 1, 5 do
			local n = (melhor[i][j].rotacao - grade[i][j].rotacao) % 4
			if n > 0 then table.insert(fila, { i, j, n }) total += n end
		end end
		log("giros necessários: " .. total .. " em " .. #fila .. " peças")
		-- 4. executa: caminha até a peça e gira
		_G.COMPORTAS.fase = "girando"
		local h = P.Character.Humanoid
		for _, item in fila do
			local i, j, n = item[1], item[2], item[3]
			local peca = pasta["Canal " .. i .. ":" .. j]
			h:MoveTo(Vector3.new(peca.Position.X, 3, peca.Position.Z))
			local t0 = os.clock()
			while (Vector3.new(P.Character.HumanoidRootPart.Position.X, 0, P.Character.HumanoidRootPart.Position.Z) - Vector3.new(peca.Position.X, 0, peca.Position.Z)).Magnitude > 1.5 and os.clock() - t0 < 3 do task.wait(0.05) end
			local pr = peca:FindFirstChildOfClass("ProximityPrompt")
			-- só gira depois que o prompt desta peça aparece (OnePerButton: o mais próximo vence)
			local gui = P.PlayerGui:WaitForChild("ProximityPrompts")
			local t1 = os.clock()
			while os.clock() - t1 < 1.5 do
				local ok = false
				for _, g in gui:GetChildren() do if g:IsA("BillboardGui") and g.Adornee == peca then ok = true end end
				if ok then break end
				task.wait(0.05)
			end
			for _ = 1, n do
				pr:InputHoldBegin()
				task.wait(0.05)
				pr:InputHoldEnd()
				task.wait(0.22)
			end
			_G.COMPORTAS.feitos = (_G.COMPORTAS.feitos or 0) + n
		end
		_G.COMPORTAS.fase = "fim"
		log("todos os giros enviados")
	end)
	if not ok then log("ERRO " .. tostring(err)); _G.COMPORTAS.fase = "erro" end
	_G.COMPORTAS.fim = true
end)
return "iniciado"
