-- Variação de superfície do esgoto (CEN2): remendos de pedra e tijolo, musgo na base, escorridos escuros
-- e entulho nos cantos, para a parede e o chão não repetirem o mesmo padrão. Tudo fino, sem sombra própria.
local EsgotoPecas = require(script.Parent.EsgotoPecas)
local peca = EsgotoPecas.peca

local EsgotoSujeira = {}

local MATERIAIS = { Enum.Material.Concrete, Enum.Material.Slate, Enum.Material.Pebble, Enum.Material.Concrete, Enum.Material.Brick }

local function tom(r, v)
	local k = r:NextNumber(0.88, 1.08)
	return Color3.fromRGB(math.min(255, v * 0.92 * k), math.min(255, v * k), math.min(255, v * 0.94 * k))
end

-- Manchas na face interna de uma parede (frame local `L`); `fatias` são os trechos sem vão.
function EsgotoSujeira.parede(pasta, L, meia, fatias, semente)
	local r = Random.new(semente)
	local z0 = -meia + 2.05
	local n = 0
	for _, f in fatias do
		local larg = f[2] - f[1]
		if larg > 12 then
			for _ = 1, math.max(2, math.floor(larg / 16)) do
				n += 1
				local w, h = r:NextNumber(3, 7), r:NextNumber(3, 6)
				local x = r:NextNumber(f[1] + w / 2 + 1, f[2] - w / 2 - 1)
				local y = r:NextNumber(h / 2 + 1, 24 - h / 2)
				peca(pasta, "Remendo", Vector3.new(w, h, 0.1), L(x, y, z0 + n * 0.004), tom(r, r:NextInteger(36, 58)),
					MATERIAIS[r:NextInteger(1, #MATERIAIS)], { CastShadow = false })
			end
			-- Escorridos escuros (umidade) e musgo grudado na base.
			for _ = 1, math.max(1, math.floor(larg / 22)) do
				n += 1
				local h = r:NextNumber(7, 15)
				peca(pasta, "Escorrido", Vector3.new(r:NextNumber(1, 2.4), h, 0.08), L(r:NextNumber(f[1] + 2, f[2] - 2), r:NextNumber(h / 2 + 3, 30 - h / 2), z0 + n * 0.004),
					Color3.fromRGB(26, 34, 32), Enum.Material.Slate, { Transparency = 0.35, CastShadow = false })
			end
			for _ = 1, math.max(1, math.floor(larg / 12)) do
				n += 1
				local h = r:NextNumber(1.5, 4)
				peca(pasta, "MusgoBase", Vector3.new(r:NextNumber(4, 11), h, 0.14), L(r:NextNumber(f[1] + 3, f[2] - 3), h / 2, z0 + 0.02 + n * 0.004),
					EsgotoPecas.MUSGO:Lerp(EsgotoPecas.PEDRA, r:NextNumber(0, 0.35)), Enum.Material.Grass, { CastShadow = false })
			end
		end
	end
end

-- Cantos da sala: lama escura no chão e uns blocos caídos.
function EsgotoSujeira.cantos(pasta, origem, meia)
	local r = Random.new(77)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local cx, cz = origem.X + sx * (meia - 8), origem.Z + sz * (meia - 8)
			peca(pasta, "Lama", Vector3.new(r:NextNumber(14, 20), 0.05, r:NextNumber(14, 20)), CFrame.new(cx, 0.07, cz) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0),
				Color3.fromRGB(34, 36, 30), Enum.Material.Mud, { CastShadow = false })
			for _ = 1, 4 do
				local s = r:NextNumber(1.6, 4)
				peca(pasta, "Entulho", Vector3.new(s, s * r:NextNumber(0.5, 0.9), s * r:NextNumber(0.7, 1.2)),
					CFrame.new(cx + r:NextNumber(-7, 7), s * 0.3, cz + r:NextNumber(-7, 7)) * CFrame.Angles(r:NextNumber(-0.3, 0.3), r:NextNumber(0, 6.28), r:NextNumber(-0.3, 0.3)),
					tom(r, r:NextInteger(60, 90)), Enum.Material.Rock)
			end
		end
	end
end

return EsgotoSujeira
