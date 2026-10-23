-- SOMENTE STUDIO: a vila monta Instances do mundo.
local Vila = require(script.Parent.Parent.Mundo.Vila)
local Layout = require(game:GetService("ReplicatedStorage").Shared.Mundo.VilaLayout)
local TerrenoLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.TerrenoLayout)

local function comLimpeza(pasta, corpo)
	local ok, erro = pcall(corpo)
	pasta:Destroy()
	if not ok then error(erro, 0) end
end

local function porNome(raiz, areaId)
	for _, item in ipairs(raiz:GetDescendants()) do
		if item:GetAttribute("AreaId") == areaId then return item end
	end
	return nil
end

-- Caixa alinhada aos eixos do mundo (GetBoundingBox segue a orientação do pivô).
local function caixaMundo(modelo)
	local minimo, maximo = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, parte in ipairs(modelo:GetDescendants()) do
		if parte:IsA("BasePart") and parte.Transparency < 1 then
			for _, sx in ipairs({ -0.5, 0.5 }) do
				for _, sy in ipairs({ -0.5, 0.5 }) do
					for _, sz in ipairs({ -0.5, 0.5 }) do
						local canto = parte.CFrame:PointToWorldSpace(parte.Size * Vector3.new(sx, sy, sz))
						minimo, maximo = minimo:Min(canto), maximo:Max(canto)
					end
				end
			end
		end
	end
	return minimo, maximo
end

-- Volume de um avatar logo à frente da porta, do lado da praça.
local function frenteLivre(mundo, e)
	local porta = Layout.porta(e)
	local o = Layout.ocupacao(e)
	local dx, dz = porta.x - o.x, porta.z - o.z
	local n = math.sqrt(dx * dx + dz * dz)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mundo }
	params.RespectCanCollide = true
	local centro = CFrame.new(porta.x + dx / n * 3, 3, porta.z + dz / n * 3)
	return #workspace:GetPartBoundsInBox(centro, Vector3.new(2, 4, 2), params) == 0
end

return {
	["V6 monta fonte casas opcionais caminhos e fica abaixo de 3500 pecas"] = function(t)
		local mundo=Instance.new("Folder")
		comLimpeza(mundo, function()
		local vila=Vila.start({workspace=mundo,semente=41636})
		local montar=require(script.Parent.Parent.Mundo.MontarModelo)
		if montar.existe("Chafariz") then
			local fonte=porNome(vila,Layout.ID.."/chafariz")
			t.ok(fonte~=nil)
			local respingos=0
			for _,p in fonte:GetDescendants() do if p:IsA("ParticleEmitter") then respingos+=1 end end
			t.eq(respingos,1)
		end
		local n=0
		mundo.Parent=workspace
		for _,e in ipairs(Layout.CASAS_NOVAS) do
			local casa=porNome(vila,Layout.ID.."/"..e.id)
			t.eq(casa~=nil,montar.existe(e.modelo),e.id.." opcional")
			if casa then t.ok(frenteLivre(mundo,e),e.id.." frente da porta bloqueada") end
		end
		for _,p in vila:GetDescendants() do
			if p:IsA("BasePart") then n+=1 end
		end
		t.ok(n<3500,"vila "..n)
		for _,p in vila["Pedras de acesso"]:GetChildren() do
			t.eq(p.Material,Enum.Material.Slate);t.ok(math.abs(p.Size.Y-0.15)<1e-4,"pedra de 0,15")
			t.ok(not p.CanCollide,"pedras nao bloqueiam avatar")
		end
		for _,m in vila["Praca e quintais"]:GetChildren() do
			if m.Name=="bandeirolas" then
				for _,p in m:GetDescendants() do if p:IsA("BasePart") then t.ok(not p.CanCollide,"mastro agrupado nao fecha vao") end end
			end
		end
		end)
	end,

	["vila monta edificios, praca e marcos do layout"] = function(t)
		local mundo = Instance.new("Folder")
		comLimpeza(mundo, function()
		mundo.Parent = workspace
		local vila = Vila.start({ workspace = mundo })
		t.eq(vila:GetAttribute("AreaId"), "region/vila")
		t.eq(#vila.Edificios:GetChildren(), #Layout.EDIFICIOS)
		t.eq(vila.Praca.ClassName, "Folder")
		t.eq(vila.Praca:GetAttribute("AreaRole"), "landmark")
		t.eq(vila.Nascimento.ClassName, "SpawnLocation")
		t.eq(vila.Nascimento.Neutral, true)
		t.eq(vila.Nascimento.Position.X, Layout.NASCIMENTO.x)
		t.eq(vila.Nascimento.Position.Z, Layout.NASCIMENTO.z)
		t.eq(vila.Nascimento.CanCollide, false)
		t.eq(TerrenoLayout.altura(Layout.NASCIMENTO.x, Layout.NASCIMENTO.z), 0)
		t.eq(vila:FindFirstChild("Trilha para a Floresta Sombria"), nil)
		local trilhaSul = vila:FindFirstChild("Trilha para a Floresta Sombria")
		local placa = vila:FindFirstChild("Saida da Floresta Sombria")
		t.eq(trilhaSul, nil)
		t.ok(placa ~= nil)
		t.eq(placa.Placa["Texto da placa"].Aviso.Text, "Floresta Sombria — perigo")
		t.eq(Vila.start({ workspace = mundo }), vila)
		for _, e in ipairs(Layout.EDIFICIOS) do
			local entrada = porNome(vila, "region/vila/" .. e.id .. "/entrada")
			t.ok(entrada ~= nil, e.id .. " sem entrada")
			t.eq(entrada.CanCollide, false)
			t.ok(frenteLivre(mundo, e), e.id .. " frente da porta bloqueada")
		end
		end)
	end,
	["predios ficam no chao, dentro da area do layout e sem scripts"] = function(t)
		local mundo = Instance.new("Folder")
		comLimpeza(mundo, function()
		local vila = Vila.start({ workspace = mundo })
		for _, e in ipairs(Layout.EDIFICIOS) do
			local modelo = porNome(vila, "region/vila/" .. e.id)
			local minimo, maximo = caixaMundo(modelo)
			local o = Layout.ocupacao(e)
			t.ok(math.abs(minimo.Y) < 0.6, e.id .. " fora do chao: " .. minimo.Y)
			-- Tolerância para beirais e o pequeno giro do modelo original.
			t.ok(minimo.X >= o.x - o.sx / 2 - 4 and maximo.X <= o.x + o.sx / 2 + 4, e.id .. " excede X")
			t.ok(minimo.Z >= o.z - o.sz / 2 - 4 and maximo.Z <= o.z + o.sz / 2 + 4, e.id .. " excede Z")
		end
		for _, item in ipairs(vila:GetDescendants()) do
			t.ok(not item:IsA("LuaSourceContainer"), item:GetFullName())
		end
		t.eq(vila:FindFirstChild("Estrada"), nil)
		t.eq(vila:FindFirstChild("Solo"), nil)
		end)
	end,
}
