-- Arcos de pedra do esgoto (CEN2): aduelas em segmento de círculo (arco de verdade, não disco chapado),
-- enchimento acima do vão e nervuras curvas da abóbada. Geometria pura sobre `EsgotoPecas.peca`.
local EsgotoPecas = require(script.Parent.EsgotoPecas)
local peca = EsgotoPecas.peca

local EsgotoArcos = {}

-- Aduelas de um arco de círculo no plano XY de `centro` (de a0 a a1, em graus, 0 = +X, 90 = topo).
-- `raioInterno` + `espessura` formam o anel; `profundidade` é a medida em Z. Devolve as peças.
function EsgotoArcos.segmentos(pasta, nome, centro, raioInterno, espessura, profundidade, a0, a1, n, cor, material, extra)
	local pecas = {}
	local passo = math.rad(a1 - a0) / n
	local externo = raioInterno + espessura
	local tangente = 2 * externo * math.tan(math.abs(passo) / 2)
	for i = 1, n do
		local ang = math.rad(a0) + passo * (i - 0.5)
		local rm = raioInterno + espessura / 2
		local c = (i % 2 == 0) and cor:Lerp(Color3.new(0, 0, 0), 0.08) or cor
		pecas[i] = peca(pasta, nome, Vector3.new(tangente, espessura, profundidade),
			centro * CFrame.new(rm * math.cos(ang), rm * math.sin(ang), 0) * CFrame.Angles(0, 0, ang - math.pi / 2), c, material, extra)
	end
	return pecas
end

-- Vão em arco numa parede (frame local `L`, parede em z=-meia, espessura 4): umbrais, aduelas, pedra-chave
-- e enchimento por cima. O trecho reto vai até y=17; o semicírculo (raio 11) fecha em y=28.
function EsgotoArcos.vao(pasta, L, ax, meia, alturaTeto)
	local PEDRA, ESCURA, CLARA = EsgotoPecas.PEDRA, EsgotoPecas.PEDRA_ESCURA, EsgotoPecas.PEDRA_CLARA
	local cobble = Enum.Material.Slate
	local R, YC = 11, 17
	for _, lado in { -1, 1 } do
		peca(pasta, "Umbral", Vector3.new(3.2, YC, 5.2), L(ax + lado * (R + 1.6), YC / 2, -meia + 0.5), ESCURA, cobble)
		peca(pasta, "Imposta", Vector3.new(4.2, 1.4, 5.8), L(ax + lado * (R + 1.8), YC + 0.7, -meia + 0.5), CLARA, cobble)
	end
	-- Enchimento: colunas de 2 studs do topo do semicírculo até o teto (o anel de aduelas esconde os degraus).
	for i = 0, 10 do
		local x0 = -R + i * 2
		local xmin = (x0 < 0 and x0 + 2 > 0) and 0 or math.min(math.abs(x0), math.abs(x0 + 2))
		local base = YC + math.sqrt(math.max(0, R * R - xmin * xmin))
		local altura = alturaTeto - base
		peca(pasta, "Enchimento", Vector3.new(2.04, altura, 4), L(ax + x0 + 1, base + altura / 2, -meia), (i % 2 == 0) and PEDRA or ESCURA, Enum.Material.Plastic)
	end
	EsgotoArcos.segmentos(pasta, "Aduela", L(ax, YC, -meia + 0.5), R, 3.2, 5.2, 0, 180, 11, PEDRA, cobble)
	peca(pasta, "PedraChave", Vector3.new(3.4, 5.4, 5.8), L(ax, YC + R + 2.3, -meia + 0.5), CLARA, cobble)
end

-- Nervuras curvas da abóbada: arcos rasos de parede a parede, presos sob a laje do teto.
-- `eixo` "x" corre ao longo de X (posição em z) e "z" ao longo de Z (posição em x).
function EsgotoArcos.nervuras(pasta, origem, meia, alturaTeto, posicoes)
	local subida = 5 -- flecha do arco
	local corda = meia
	local R = (corda * corda + subida * subida) / (2 * subida)
	local meioAng = math.deg(math.asin(corda / R))
	local topo = alturaTeto - 1.6 -- centro do anel no ponto mais alto
	local espessura, profundidade = 2.6, 6
	for _, eixo in { "x", "z" } do
		for _, p in posicoes do
			local base = CFrame.new(origem.X + (eixo == "z" and p or 0), topo - R + espessura / 2, origem.Z + (eixo == "x" and p or 0))
			if eixo == "z" then base = base * CFrame.Angles(0, math.rad(90), 0) end
			EsgotoArcos.segmentos(pasta, "Nervura", base, R - espessura / 2, espessura, profundidade, 90 - meioAng, 90 + meioAng, 15,
				EsgotoPecas.PEDRA, Enum.Material.Slate)
		end
	end
end

return EsgotoArcos
