-- SOMENTE STUDIO: confere a tabela de mecânicas contra o catálogo gerado do livro.
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalogo = require(Shared.Livro.Catalogo)
local Combate = require(Shared.Regras.Combate)
local Fogo = require(Shared.Regras.Fogo)

local function metros(texto: string): number?
	local n = string.match(texto or "", "(%d+)%s*m")
	return n and tonumber(n)
end

return {
	["Fogo: PM e Ações de cada mecânica são os do livro"] = function(t)
		for id, mec in Fogo.MECANICAS do
			local entrada = Catalogo.POR_ID[id]
			t.ok(entrada, "fora do catálogo: " .. id)
			t.eq(entrada.data.pmCost, mec.pm, id .. " PM")
			t.eq(entrada.data.actions.normal, mec.acoes, id .. " Ações")
		end
	end,
	["Fogo: alcance, raio e linha em casas saem dos metros do livro"] = function(t)
		for id, mec in Fogo.MECANICAS do
			local m = metros(Catalogo.POR_ID[id].data.range)
			local casas = mec.alcanceCasas or mec.raioCasas or mec.comprimentoCasas
			if m then
				t.eq(casas, Combate.casasDeMetros(m), id .. " (" .. m .. " m)")
			else
				t.ok(mec.corpoACorpo, id .. ": sem metros só se for Toque")
			end
		end
	end,
	["Fogo: Em Chamas da tabela é a condição do catálogo com 1d6"] = function(t)
		local cond = Catalogo.POR_ID["condition/" .. Fogo.EM_CHAMAS]
		t.ok(cond, "condição Em Chamas no catálogo")
		t.eq(cond.data.mecanica.danoPorTurno, Fogo.DANO_EM_CHAMAS)
	end,
}
