local Shared = game:GetService("ReplicatedStorage").Shared
local AtributosPersonagem = require(Shared.Regras.AtributosPersonagem)

local function catalogo()
	return {
		POR_ID = {
			["race/humano"] = { kind = "race", data = { attributeChoices = 1, bonuses = {} } },
			["race/elfo"] = { kind = "race", data = { bonuses = { attributes = { agilidade = 1 } } } },
			["background/plebeu"] = { kind = "background", data = { bonuses = { attributes = { vigor = 1 } } } },
			["background/miko"] = { kind = "background", data = { requiresSubtable = "miko", bonuses = { attributes = { espirito = 1 } } } },
			["background/olho"] = { kind = "background", data = { requiresSubtable = "olho", bonuses = {} } },
			["subtable-entry/miko/forca-sobre-humana"] = { kind = "subtable-entry", data = { id = "forca-sobre-humana", subtableId = "miko", bonuses = { attributes = { forca = 2 } } } },
			["subtable-entry/olho/previsao"] = { kind = "subtable-entry", data = { id = "previsao", subtableId = "olho", bonuses = { attributes = { forca = 3 } } } },
		},
		POR_ESPECIE = {
			["subtable-entry"] = {
				{ data = { id = "forca-sobre-humana", subtableId = "miko", bonuses = { attributes = { forca = 2 } } } },
				{ data = { id = "previsao", subtableId = "olho", bonuses = { attributes = { forca = 3 } } } },
			},
		},
	}
end

return {
	["vetor diferencial do site: elfo, plebeu e atributos base"] = function(t)
		local finais = AtributosPersonagem.finais({
			raceId = "race/elfo",
			backgroundId = "background/plebeu",
			attributeBase = { forca = 2, agilidade = 1, vigor = 3, intelecto = 4, espirito = 0 },
		}, catalogo())
		t.eq(finais.forca, 2)
		t.eq(finais.agilidade, 2)
		t.eq(finais.vigor, 4)
		t.eq(finais.intelecto, 4)
		t.eq(finais.espirito, 0)
	end,
	["escolhas raciais usam só os primeiros pontos concedidos e permitem repetição"] = function(t)
		local finais = AtributosPersonagem.finais({
			raceId = "race/humano",
			attributeBase = {},
			raceAttributeChoices = { "forca", "agilidade", "forca" },
		}, catalogo())
		t.eq(finais.forca, 1)
		t.eq(finais.agilidade, 0)
		t.eq(finais.vigor, 0)
	end,
	["subtabela só soma quando o antecedente exige subtabela"] = function(t)
		local c = catalogo()
		local construcao = { backgroundId = "background/miko", subtableEntryId = "subtable-entry/miko/forca-sobre-humana", attributeBase = {} }
		local finais = AtributosPersonagem.finais(construcao, c)
		t.eq(finais.forca, 2)
		t.eq(finais.espirito, 1)
		construcao.subtableEntryId = "subtable-entry/olho/previsao"
		finais = AtributosPersonagem.finais(construcao, c)
		t.eq(finais.forca, 0, "não mistura entradas de subtabelas diferentes")
		t.eq(finais.espirito, 1)
		construcao.backgroundId = "background/plebeu"
		t.eq(AtributosPersonagem.finais(construcao, c).espirito, 0)
	end,
}
