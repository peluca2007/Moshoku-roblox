-- GERADO por tools/gerar-kits-iniciais.mts. Não edite à mão.
-- Fonte: site original, src/data/startingKits.ts (Cap. 1, Equipamento Inicial e a Árvore Inicial).
-- SHA256 da fonte: 611f283c898b595d73d1fe74dd156ffda7eaaa888de679064e6ac5e4413a4759
-- Nomes/alternativas/descrições preservados; este catálogo não escolhe nem equipa itens.
local LISTA = {
	{
		["subgroup"] = "Espadachim",
		["items"] = {
			{
				["name"] = "Espada Longa",
				["type"] = "arma",
				["baseDie"] = "d8",
			},
			{
				["name"] = "Roupas de viagem resistentes",
				["type"] = "geral",
			},
		},
	},
	{
		["subgroup"] = "Guerreiro / Parrudice",
		["items"] = {
			{
				["name"] = "Machado de Batalha",
				["type"] = "arma",
				["baseDie"] = "d8",
			},
		},
	},
	{
		["subgroup"] = "Tank / Defensor",
		["items"] = {
			{
				["name"] = "Escudo",
				["type"] = "armadura",
				["acBonus"] = 2,
			},
			{
				["name"] = "Espada Curta",
				["type"] = "arma",
				["baseDie"] = "d6",
			},
			{
				["name"] = "Armadura Leve",
				["type"] = "armadura",
				["acBonus"] = 1,
			},
		},
	},
	{
		["subgroup"] = "Arqueiro",
		["items"] = {
			{
				["name"] = "Arco Curto",
				["type"] = "arma",
				["baseDie"] = "d6",
				["description"] = "20 flechas inclusas.",
			},
			{
				["name"] = "Funda / Dardo",
				["type"] = "arma",
				["baseDie"] = "d4",
				["description"] = "A arma de reserva, quando as flechas acabam.",
			},
		},
	},
	{
		["subgroup"] = "Magia Ofensiva",
		["items"] = {
			{
				["name"] = "Cajado / Foco Arcano",
				["type"] = "arma",
				["baseDie"] = "d6",
				["description"] = "Conta como objeto improvisado corpo a corpo.",
			},
			{
				["name"] = "Grimório básico",
				["type"] = "geral",
			},
			{
				["name"] = "Roupas de viajante",
				["type"] = "geral",
			},
		},
	},
	{
		["subgroup"] = "Cura e Suporte",
		["items"] = {
			{
				["name"] = "Kit de cura",
				["type"] = "geral",
				["description"] = "Bandagens, ervas, um frasco vazio.",
			},
			{
				["name"] = "Símbolo do templo de origem",
				["type"] = "geral",
			},
			{
				["name"] = "Cajado / Foco Arcano",
				["type"] = "arma",
				["baseDie"] = "d6",
				["description"] = "Conta como objeto improvisado corpo a corpo.",
			},
		},
	},
	{
		["subgroup"] = "Invocação",
		["items"] = {
			{
				["name"] = "Giz e tinta ritual",
				["type"] = "geral",
				["description"] = "Material pra três círculos.",
			},
			{
				["name"] = "Cajado / Foco Arcano",
				["type"] = "arma",
				["baseDie"] = "d6",
				["description"] = "Conta como objeto improvisado corpo a corpo.",
			},
		},
	},
	{
		["subgroup"] = "Batedor e Ladrão",
		["items"] = {
			{
				["name"] = "Adaga / Punhal",
				["type"] = "arma",
				["baseDie"] = "d4",
				["description"] = "Duas: a de mão e a de reserva.",
			},
			{
				["name"] = "Kit de arrombamento",
				["type"] = "geral",
			},
			{
				["name"] = "Roupas escuras",
				["type"] = "geral",
			},
		},
	},
	{
		["subgroup"] = "Bardo",
		["items"] = {
			{
				["name"] = "Instrumento musical",
				["type"] = "geral",
				["description"] = "Escolha o instrumento.",
			},
			{
				["name"] = "Adaga / Punhal",
				["type"] = "arma",
				["baseDie"] = "d4",
			},
		},
	},
	{
		["subgroup"] = "Sobrevivência e Táticas",
		["items"] = {
			{
				["name"] = "Kit de sobrevivência",
				["type"] = "geral",
				["description"] = "Corda, mapa em branco, uma semana de provisões.",
			},
			{
				["name"] = "Alabarda / Lança",
				["type"] = "arma",
				["baseDie"] = "d10",
				["description"] = "Ou troque por Arco Curto com 20 flechas.",
			},
		},
	},
}

local function congelar(valor)
	if type(valor) == "table" then
		for _, filho in valor do
			congelar(filho)
		end
		table.freeze(valor)
	end
end
congelar(LISTA)

local POR_SUBGRUPO = {}
for _, kit in LISTA do
	POR_SUBGRUPO[kit.subgroup] = kit
end
table.freeze(POR_SUBGRUPO)

return table.freeze({
	LISTA = LISTA,
	POR_SUBGRUPO = POR_SUBGRUPO,
	FONTE = "src/data/startingKits.ts",
	SHA256_FONTE = "611f283c898b595d73d1fe74dd156ffda7eaaa888de679064e6ac5e4413a4759",
	-- Mesmo contrato de getStartingKit no site: chave exata de Tree.subgroup, nil se ausente.
	obter = function(subgrupo)
		return POR_SUBGRUPO[subgrupo]
	end,
})
