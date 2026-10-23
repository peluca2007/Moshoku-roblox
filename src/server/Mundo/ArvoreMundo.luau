-- Árvore decorativa compartilhada entre as regiões do mundo. Usa as árvores prontas
-- (Mundo/Modelos: Pinheiro1-5 da Creator Store, Low-Poly Pine de Cliosow; CarvalhoB1-4 gerados no Blender)
-- quando existem; senão, o bloco de tronco e copa.
local MontarModelo = require(script.Parent.MontarModelo)

local ArvoreMundo = {}

local FAMILIAS = {
	pinheiro = { prefixo = "Pinheiro", total = 5, escala = 0.8 },
	carvalho = { prefixo = "CarvalhoB", total = 4, escala = 1 },
}

-- Variante e giro determinísticos pela posição: a mesma árvore sai igual em todo servidor.
function ArvoreMundo.variante(familia, x, z)
	local f = FAMILIAS[familia]
	if not f then return nil end
	local h = math.abs(math.floor(x * 7.31 + z * 13.17)) % 1000
	return f.prefixo .. (h % f.total + 1), math.rad((h * 37) % 360)
end

local function modelo(pai, x, z, escala, familia)
	local nome, giro = ArvoreMundo.variante(familia, x, z)
	if not nome or not MontarModelo.existe(nome) then return nil end
	local arvore = MontarModelo.montar(nome, pai, CFrame.new(x, 0, z) * CFrame.Angles(0, giro, 0), escala * FAMILIAS[familia].escala)
	-- Apoia a base no chão (y=0), qualquer que seja a altura do pivô original.
	local caixa, tamanho = arvore:GetBoundingBox()
	arvore:PivotTo(arvore:GetPivot() + Vector3.new(0, -(caixa.Position.Y - tamanho.Y / 2), 0))
	arvore.Name = "Arvore"
	return arvore
end

-- `familia` ("pinheiro" | "carvalho") é opcional; sem ela, ou sem o modelo, sai o bloco.
function ArvoreMundo.criar(pai, criarParte, x, z, escala, copa, familia)
	if familia then
		local pronta = modelo(pai, x, z, escala, familia)
		if pronta then return pronta end
	end
	local tronco = criarParte(pai, "Tronco", Vector3.new(2, 9, 2) * escala,
		Vector3.new(x, 3.5 * escala, z), Color3.fromRGB(102, 73, 48), Enum.Material.Wood)
	tronco.Shape = Enum.PartType.Cylinder
	local folhagem = criarParte(pai, "Copa", Vector3.new(11, 11, 11) * escala,
		Vector3.new(x, 10 * escala, z), copa or Color3.fromRGB(54, 103, 65), Enum.Material.Grass)
	folhagem.Shape = Enum.PartType.Ball
	folhagem.CanCollide = false
	return tronco, folhagem
end

return ArvoreMundo
