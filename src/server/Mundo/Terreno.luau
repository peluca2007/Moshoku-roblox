-- Adapta o relevo puro para Terrain; inicialização síncrona com yields entre blocos.
-- O READY global do jogo só é liberado depois deste start e dos construtores.
local Layout = require(game:GetService("ReplicatedStorage").Shared.Mundo.TerrenoLayout)
local Terreno = {}
local ATRIBUTO = "TerrenoPronto"
local EM_GERACAO = "TerrenoGerando"
local COLUNAS = 64

function Terreno.pronto(raiz)
	return (raiz or workspace):GetAttribute(ATRIBUTO) == true
end

local function escrever(terrain, x0, z0, nx, nz)
	local r, base = Layout.RESOLUCAO, Layout.BASE
	local alturas, maior = {}, base
	-- Halo evita recalcular cinco relevos completos por coluna para a inclinação.
	for x = 0, nx + 1 do
		alturas[x] = {}
		for z = 0, nz + 1 do
			local h = Layout.altura(x0 + (x - 0.5) * r, z0 + (z - 0.5) * r)
			alturas[x][z] = h
			maior = math.max(maior, h)
		end
	end
	local teto = math.max(4, math.ceil(maior / r) * r + r)
	local ny = (teto - base) / r
	local materiais, ocupacoes = {}, {}
	for x = 1, nx do
		materiais[x], ocupacoes[x] = {}, {}
		for y = 1, ny do materiais[x][y], ocupacoes[x][y] = {}, {} end
		for z = 1, nz do
			local px, pz = x0 + (x - 0.5) * r, z0 + (z - 0.5) * r
			local h = alturas[x][z]
			local dx, dz = (alturas[x + 1][z] - alturas[x - 1][z]) / (2 * r),
				(alturas[x][z + 1] - alturas[x][z - 1]) / (2 * r)
			local material = Enum.Material[Layout.material(px, pz, h, math.sqrt(dx * dx + dz * dz))]
			local agua = Layout.agua(px, pz)
			-- Reserva qualquer célula que intercepte a caixa da sala: voxels nunca entram
			-- no interior fechado, incluindo sob o piso. Não chama Terrain:Clear().
			local excluido = Layout.excluido(px, pz, r / 2)
			for y = 1, ny do
				local baixo = base + (y - 1) * r
				local m, o = Enum.Material.Air, 0
				if not excluido then
					-- O Roblox desenha a superfície em baixo + ocupação * r + r/2 (medido no
					-- Studio em 16/10: célula -4..0 cheia dá topo em +2). Daí o desconto de r/2.
					o = math.clamp((h - baixo - r / 2) / r, 0, 1)
					if o > 0 then
						m = material
					elseif agua and baixo < agua.nivel then
						m, o = Enum.Material.Water, math.clamp((agua.nivel - baixo - r / 2) / r, 0, 1)
					end
				end
				materiais[x][y][z], ocupacoes[x][y][z] = m, o
			end
		end
	end
	terrain:WriteVoxels(Region3.new(Vector3.new(x0, base, z0), Vector3.new(x0 + nx * r, teto, z0 + nz * r)),
		r, materiais, ocupacoes)
end

function Terreno.start(deps)
	deps = deps or {}
	local raiz = deps.workspace or workspace
	if Terreno.pronto(raiz) then return raiz.Terrain end
	local esperar = deps.esperar or task.wait
	-- Outro chamador aguarda o mesmo trabalho, em vez de sobrepor WriteVoxels.
	while raiz:GetAttribute(EM_GERACAO) do
		esperar()
		if Terreno.pronto(raiz) then return raiz.Terrain end
	end
	raiz:SetAttribute(EM_GERACAO, true)
	raiz:SetAttribute(ATRIBUTO, false)
	local terrain = deps.terrain or raiz.Terrain
	local ok, erro = pcall(function()
		for nome, rgb in pairs(Layout.CORES_MATERIAL) do
			terrain:SetMaterialColor(Enum.Material[nome], Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
		end
		for _, b in ipairs(Layout.BLOCOS) do
			local r = Layout.RESOLUCAO
			local xmin, zmin = b.x - b.sx / 2, b.z - b.sz / 2
			for x = 0, b.sx / r - 1, COLUNAS do
				for z = 0, b.sz / r - 1, COLUNAS do
					escrever(terrain, xmin + x * r, zmin + z * r,
						math.min(COLUNAS, b.sx / r - x), math.min(COLUNAS, b.sz / r - z))
					esperar()
				end
			end
		end
	end)
	raiz:SetAttribute(EM_GERACAO, nil)
	if not ok then error(erro, 0) end
	-- Só sucesso completo marca o mundo; erro pode ser repetido deterministicamente.
	raiz:SetAttribute(ATRIBUTO, true)
	return terrain
end
return Terreno
