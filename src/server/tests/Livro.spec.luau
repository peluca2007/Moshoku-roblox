-- SOMENTE STUDIO: usa a hierarquia de pastas do Roblox (Livro/Dados).
-- Confere o catálogo gerado contra o próprio manifesto (docs/CONTRATOS.md §3).
local Livro = game:GetService("ReplicatedStorage").Shared.Livro
local Catalogo = require(Livro.Catalogo)
local Manifesto = require(Livro.Manifesto)

local function contar(kind: string): number
	local lista = Catalogo.POR_ESPECIE[kind]
	return if lista then #lista else 0
end

return {
	["contagens por espécie batem com o manifesto"] = function(t)
		for kind, quantidade in Manifesto.counts do
			t.eq(contar(kind), quantidade, kind)
		end
	end,
	["versões vêm do manifesto"] = function(t)
		t.eq(Catalogo.FORMATO, 2)
		t.ok(string.match(Catalogo.CONTEUDO, "^sha256:%x+$") ~= nil, Catalogo.CONTEUDO)
	end,
	["ids seguem o contrato e a árvore aponta para seus ranks"] = function(t)
		local fogo = Catalogo.POR_ID["tree/fogo"]
		t.ok(fogo ~= nil, "tree/fogo")
		t.eq(fogo.kind, "tree")
		local rank = Catalogo.POR_ID[fogo.data.ranks[1]]
		t.ok(rank ~= nil and rank.kind == "rank", "primeiro rank")
		local habilidade = Catalogo.POR_ID[rank.data.abilities[1]]
		t.ok(habilidade ~= nil and habilidade.kind == "ability", "primeira habilidade")
		t.ok(string.match(habilidade.id, "^ability/fogo/[^/]+/[^/]+$") ~= nil, habilidade.id)
		t.ok(type(habilidade.data.paCost) == "number")
		t.ok(type(habilidade.data.effect) == "string" and #habilidade.data.effect > 0)
	end,
	["acentos no rank viram percent-encoding"] = function(t)
		t.ok(Catalogo.POR_ID["rank/fogo/Intermedi%C3%A1rio"] ~= nil, "rank Intermediário")
	end,
	["toda referência de rank existe"] = function(t)
		for _, rank in Catalogo.POR_ESPECIE.rank do
			for _, campo in { "abilities", "talents" } do
				for _, id in rank.data[campo] do
					t.ok(Catalogo.POR_ID[id] ~= nil, id)
				end
			end
			if rank.data.mastery then
				t.ok(Catalogo.POR_ID[rank.data.mastery] ~= nil, rank.data.mastery)
			end
		end
	end,
	["catálogo é imutável em profundidade"] = function(t)
		local habilidade = Catalogo.POR_ESPECIE.ability[1]
		t.fails(function()
			(habilidade :: any).data.paCost = 99
		end, "campo de habilidade")
		t.fails(function()
			(habilidade :: any).data.actions.normal = 0
		end, "tabela aninhada")
		t.fails(function()
			(Catalogo.POR_ID :: any)["tree/novo"] = {}
		end, "índice")
	end,
}
