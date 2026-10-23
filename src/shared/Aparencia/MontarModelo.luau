-- Monta em runtime modelos prontos guardados como DADOS em Mundo/Modelos/<Nome>.luau
-- (gerados por tools/exportar_modelo.py a partir da Creator Store). Só cria peças
-- ancoradas e adereços visuais (Smoke, SurfaceGui, TextLabel); nunca cria scripts.
--
-- Formato do módulo de dados (versao = 1):
--   fonte  = { nome, asset, autor }      caixa = { x, y, z } tamanho original (alinhado ao pivô)
--   centro = { x, y, z }                 centro da caixa em relação ao pivô
--   S = { strings }                      classes, nomes, grupos, materiais, fontes, textos
--   R = { {r00..r22}, ... }              rotações únicas (ordem de CFrame:GetComponents)
--   P = { linha, ... }                   uma peça por linha, relativa ao pivô:
--     { classe, nome, grupo, sx, sy, sz, px, py, pz, rot, cor, material, transp, refletancia,
--       flags, forma, filhos? }
--     classe/nome/grupo/material: índices em S; rot: índice em R; cor: RGB inteiro;
--     flags: 1 = CanCollide, 2 = CastShadow; forma: valor de Enum.PartType (só Part);
--     grupo: caminho de Models separado por "/" ("" = direto no modelo).
--     malha (18º, só MeshPart): { MeshId, TextureID } índices em S; recriada por
--     AssetService:CreateMeshPartAsync (yield); se a malha falhar, cai num bloco do mesmo tamanho.
--     filhos: { {1, cor, tamanho, opacidade, subida}                              -- Smoke
--             , {2, face, modoDeTamanho, pixelsPorStud, telaX, telaY, luz, rotulos} } -- SurfaceGui
--     rotulo: { texto, cor, fonte, escalado, fundoTransp, {sx,ox,sy,oy}, {px,ox,py,oy}, tamanhoTexto }
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local PASTA = if RunService:IsServer()
 then game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Mundo"):WaitForChild("Modelos")
 else script.Parent:WaitForChild("Modelos")
local TAMANHO_MINIMO = 0.05

local MontarModelo = {}

local moldes = {} -- MeshId -> MeshPart molde (false = falhou)

local function modulo(nome)
	if type(nome) ~= "string" or not PASTA then
		return nil
	end
	local item = PASTA:FindFirstChild(nome)
	return if item and item:IsA("ModuleScript") then item else nil
end

function MontarModelo.existe(nomeModulo: string): boolean
	return modulo(nomeModulo) ~= nil
end

local function cor(inteiro: number): Color3
	return Color3.fromRGB(inteiro // 65536, inteiro // 256 % 256, inteiro % 256)
end

local function enum(tipo, nome, padrao)
	local ok, valor = pcall(function()
		return tipo[nome]
	end)
	return if ok and valor then valor else padrao
end

local function adereco(parte, filho, S, escala)
	if filho[1] == 1 then
		local fumaca = Instance.new("Smoke")
		fumaca.Color = cor(filho[2])
		fumaca.Size = filho[3] * escala
		fumaca.Opacity = filho[4]
		fumaca.RiseVelocity = filho[5] * escala
		fumaca.Parent = parte
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = enum(Enum.NormalId, S[filho[2]], Enum.NormalId.Front)
	gui.SizingMode = enum(Enum.SurfaceGuiSizingMode, S[filho[3]], Enum.SurfaceGuiSizingMode.FixedSize)
	local porStud = filho[4]
	if gui.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud then
		porStud = porStud / escala -- o rótulo em pixels encolhe junto com a peça
	end
	gui.PixelsPerStud = porStud
	gui.CanvasSize = Vector2.new(filho[5], filho[6])
	gui.LightInfluence = filho[7]
	for _, r in ipairs(filho[8]) do
		local rotulo = Instance.new("TextLabel")
		rotulo.Text = S[r[1]]
		rotulo.TextColor3 = cor(r[2])
		rotulo.Font = enum(Enum.Font, S[r[3]], Enum.Font.SourceSans)
		rotulo.TextScaled = r[4] == 1
		rotulo.BackgroundTransparency = r[5]
		rotulo.Size = UDim2.new(r[6][1], r[6][2], r[6][3], r[6][4])
		rotulo.Position = UDim2.new(r[7][1], r[7][2], r[7][3], r[7][4])
		rotulo.TextSize = r[8]
		rotulo.Parent = gui
	end
	gui.Parent = parte
end

-- Cria (e guarda em cache) o Model de um grupo "A/B/C" dentro do modelo raiz.
local function grupoDe(raiz, grupos, caminho: string)
	if caminho == "" then
		return raiz
	end
	local existente = grupos[caminho]
	if existente then
		return existente
	end
	local acima, nome = string.match(caminho, "^(.*)/([^/]*)$")
	local pai = if acima then grupoDe(raiz, grupos, acima) else raiz
	local modelo = Instance.new("Model")
	modelo.Name = nome or caminho
	modelo.Parent = pai
	grupos[caminho] = modelo
	return modelo
end

-- Cria em paralelo o molde de cada malha única de todos os módulos de Mundo/Modelos (a criação
-- é rede e levava ~15 s em série durante a montagem do mundo). Bloqueia até terminar; malha que
-- falhar fica como bloco (como já acontecia). Devolve (quantidade, segundos).
function MontarModelo.preaquecer(): (number, number)
	local inicio = os.clock()
	local ids, vistos = {}, {}
	if PASTA then
		for _, item in ipairs(PASTA:GetChildren()) do
			if item:IsA("ModuleScript") then
				local ok, dados = pcall(require, item)
				if ok and type(dados) == "table" and dados.P and dados.S then
					for _, p in ipairs(dados.P) do
						if dados.S[p[1]] == "MeshPart" and p[18] then
							local id = dados.S[p[18][1]]
							if not vistos[id] and moldes[id] == nil then
								vistos[id] = true
								table.insert(ids, id)
							end
						end
					end
				end
			end
		end
	end
	local pendentes, fim = #ids, Instance.new("BindableEvent")
	for _, id in ipairs(ids) do
		task.spawn(function()
			local ok, criada = pcall(AssetService.CreateMeshPartAsync, AssetService, id)
			moldes[id] = if ok then criada else false
			pendentes -= 1
			if pendentes == 0 then fim:Fire() end
		end)
	end
	if pendentes > 0 then
		fim.Event:Wait()
	end
	fim:Destroy()
	return #ids, os.clock() - inicio
end

-- Monta o modelo `nomeModulo` em `pai`: o pivô original vai para `cframeDestino`;
-- `escala` (padrão 1) multiplica posições e tamanhos. Todas as peças ficam ancoradas.
function MontarModelo.montar(nomeModulo: string, pai: Instance, cframeDestino: CFrame, escala: number?): Model
	-- A3: moldes visuais já montados pelo servidor evitam carregar malhas no cliente.
	if not RunService:IsServer() then
		local moldesVisuais = script.Parent:FindFirstChild("MoldesVisuais")
		local molde = moldesVisuais and moldesVisuais:FindFirstChild(nomeModulo)
		if molde then
			local copia = molde:Clone()
			copia:ScaleTo(escala or 1)
			copia:PivotTo(cframeDestino)
			copia.Parent = pai
			return copia
		end
	end
	local origem = modulo(nomeModulo)
	assert(origem, "MontarModelo: módulo de dados desconhecido: " .. tostring(nomeModulo))
	local e = escala or 1
	assert(type(e) == "number" and e > 0 and e < math.huge, "MontarModelo: escala inválida")
	local dados = require(origem)
	local S, R = dados.S, dados.R

	local raiz = Instance.new("Model")
	raiz.Name = nomeModulo
	raiz:SetAttribute("Fonte", "asset:" .. tostring(dados.fonte.asset))
	raiz:SetAttribute("EscalaDoModelo", e)
	local grupos = {}
	local materiais = {}

	for _, p in ipairs(dados.P) do
		local classe = S[p[1]]
		local parte: BasePart
		if classe == "MeshPart" then
			local malha = p[18]
			-- Uma criação por MeshId (rede); as demais peças usam clones do molde em cache.
			local molde = moldes[S[malha[1]]]
			if molde == nil then
				local ok, criada = pcall(AssetService.CreateMeshPartAsync, AssetService, S[malha[1]])
				molde = if ok then criada else false
				moldes[S[malha[1]]] = molde
			end
			local ok = molde ~= false
			if ok then
				parte = molde:Clone()
				if S[malha[2]] ~= "" then (parte :: MeshPart).TextureID = S[malha[2]] end
			else
				parte = Instance.new("Part")
			end
		else
			parte = Instance.new(classe) :: BasePart
		end
		parte.Name = S[p[2]]
		parte.Anchored = true
		parte.Size = Vector3.new(
			math.max(p[4] * e, TAMANHO_MINIMO),
			math.max(p[5] * e, TAMANHO_MINIMO),
			math.max(p[6] * e, TAMANHO_MINIMO)
		)
		local r = R[p[10]]
		parte.CFrame = cframeDestino
			* CFrame.new(p[7] * e, p[8] * e, p[9] * e, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
		parte.Color = cor(p[11])
		local nomeMaterial = S[p[12]]
		local material = materiais[nomeMaterial]
		if not material then
			material = enum(Enum.Material, nomeMaterial, Enum.Material.Plastic)
			materiais[nomeMaterial] = material
		end
		parte.Material = material
		parte.Transparency = p[13]
		parte.Reflectance = p[14]
		parte.CanCollide = bit32.band(p[15], 1) ~= 0
		parte.CastShadow = bit32.band(p[15], 2) ~= 0
		if classe == "Part" then
			(parte :: Part).Shape = Enum.PartType:FromValue(p[16]) or Enum.PartType.Block
		end
		if p[17] then
			for _, filho in ipairs(p[17]) do
				adereco(parte, filho, S, e)
			end
		end
		parte.Parent = grupoDe(raiz, grupos, S[p[3]])
	end

	raiz.WorldPivot = cframeDestino
	raiz.Parent = pai
	return raiz
end

return MontarModelo
