-- SOMENTE STUDIO (usa o catálogo real do livro)
-- P2: o preset recomendado nunca gera ficha inválida (todas as raças, com e sem árvore).
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalogo = require(Shared.Livro.Catalogo)
local Criacao = require(Shared.Regras.CriacaoPersonagem)
local Preset = require(Shared.Regras.CriacaoPreset)
local KitsIniciais = require(Shared.KitsIniciais)

local function arvoresJogaveis()
	local lista = {}
	for _, arvore in Catalogo.POR_ESPECIE.tree or {} do
		local kit = type(arvore.data.subgroup) == "string" and KitsIniciais.obter(arvore.data.subgroup) or nil
		if type(kit) == "table" and type(kit.items) == "table" and #kit.items > 0 then table.insert(lista, arvore) end
	end
	return lista
end

return {
	["preset sem árvore é válido e calculável para todas as raças do catálogo"] = function(t)
		local total = 0
		for _, raca in Catalogo.POR_ESPECIE.race do
			local escolha, erro = Preset.criar(Catalogo, raca.id, nil)
			t.ok(escolha, raca.id .. ": " .. tostring(erro))
			local normalizada, motivo = Criacao.validar(escolha, Catalogo)
			t.ok(normalizada, raca.id .. ": " .. tostring(motivo))
			local calculo, erroCalculo = Criacao.calcular(escolha, Catalogo)
			t.ok(calculo, raca.id .. ": " .. tostring(erroCalculo))
			total += 1
		end
		t.ok(total >= 5)
	end,
	["preset com cada árvore jogável também é válido e a troca de árvore conserva a ficha"] = function(t)
		local arvores = arvoresJogaveis()
		t.ok(#arvores >= 1)
		for _, raca in Catalogo.POR_ESPECIE.race do
			local semArvore = Preset.criar(Catalogo, raca.id, nil)
			for _, arvore in arvores do
				local direto, erro = Preset.criar(Catalogo, raca.id, arvore.id)
				t.ok(direto and Criacao.validar(direto, Catalogo), raca.id .. "/" .. arvore.id .. ": " .. tostring(erro))
				local depois, erroDepois = Preset.comArvore(Catalogo, semArvore, arvore.id)
				t.ok(depois, tostring(erroDepois))
				local ok, motivo = Criacao.validar(depois, Catalogo)
				t.ok(ok, raca.id .. "/" .. arvore.id .. " comArvore: " .. tostring(motivo))
				t.eq(depois.startingTreeId, arvore.id)
				t.eq(depois.backgroundId, semArvore.backgroundId)
				t.eq(depois.attributeBase.forca, semArvore.attributeBase.forca)
			end
		end
	end,
	["perícias livres do preset nunca repetem concessões nem a si mesmas (Arcanismo duplicado)"] = function(t)
		for _, raca in Catalogo.POR_ESPECIE.race do
			local escolha = Preset.criar(Catalogo, raca.id, nil)
			local vistas = {}
			for _, id in escolha.freeSkillChoiceIds do
				t.ok(not vistas[id], raca.id .. " repete " .. id)
				vistas[id] = true
			end
		end
	end,
	["nomes sugeridos são válidos e o sorteio é injetado"] = function(t)
		local vistos = {}
		for i = 1, 12 do
			local nome = Preset.sugerirNome(function(lo) return lo + (i - 1) end)
			t.ok(Preset.nomeValido(nome), tostring(nome))
			vistos[nome] = true
		end
		local quantidade = 0
		for _ in vistos do quantidade += 1 end
		t.ok(quantidade >= 6)
		t.eq(Preset.nomeValido(""), nil)
		t.eq(Preset.nomeValido(string.rep("a", 33)), nil)
		t.eq(Preset.nomeValido("  Lina  "), "Lina")
	end,
	["cartão da raça: uma frase curta e selo de bônus não vazios"] = function(t)
		for _, raca in Catalogo.POR_ESPECIE.race do
			local frase, selo = Preset.frase(raca), Preset.selo(raca)
			t.ok(type(frase) == "string" and #frase > 0 and utf8.len(frase) <= 130, raca.id)
			t.ok(type(selo) == "string" and #selo > 0, raca.id)
		end
	end,
}
