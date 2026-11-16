-- Peças-base do cenário do esgoto (CEN1/CEN2): cores, construtor de Part sem colisão nem consulta e luz.
-- CanQuery = false em tudo: raios da câmera da luta e do mouse atravessam o cenário.
local EsgotoPecas = {}

EsgotoPecas.PEDRA = Color3.fromRGB(74, 80, 78)
EsgotoPecas.PEDRA_ESCURA = Color3.fromRGB(52, 58, 56)
EsgotoPecas.PEDRA_CLARA = Color3.fromRGB(110, 114, 106)
EsgotoPecas.MUSGO = Color3.fromRGB(58, 84, 52)
EsgotoPecas.FERRO = Color3.fromRGB(70, 60, 54)
EsgotoPecas.FERRUGEM = Color3.fromRGB(112, 72, 44)
EsgotoPecas.AGUA = Color3.fromRGB(12, 24, 22)
EsgotoPecas.VAZIO = Color3.fromRGB(6, 9, 8)

function EsgotoPecas.peca(pasta, nome, tamanho, cf, cor, material, extra)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = nome, true, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = tamanho, cf, cor, material or Enum.Material.Slate
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if extra then
		for k, v in extra do
			if k == "variante" then p.MaterialVariant = v else (p :: any)[k] = v end
		end
	end
	p.Parent = pasta
	return p
end

function EsgotoPecas.luz(pai, cor, brilho, alcance, sombras)
	local l = Instance.new("PointLight")
	l.Color, l.Brightness, l.Range, l.Shadows = cor, brilho, alcance, sombras or false
	l.Parent = pai
	return l
end

return EsgotoPecas
