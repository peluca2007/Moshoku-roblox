-- REA4: clipes Mixamo por peça rígida das criaturas humanoides (Shared/Animacoes/CriaturasMx).
local Shared = game:GetService("ReplicatedStorage").Shared
local Anim = require(Shared.Mundo.AnimacaoCriatura)
local Pivos = require(Shared.Mundo.PivosModelos)
local Reacoes = require(Shared.ReacoesAlvo)

-- (require com caminho literal: o executor fora do Studio resolve só assim)
local DADOS = {
	BandidoEspadaQuaternius = require(Shared.Animacoes.CriaturasMx.BandidoEspadaQuaternius),
	BandidoPorreteQuaternius = require(Shared.Animacoes.CriaturasMx.BandidoPorreteQuaternius),
	GoblinQuaternius = require(Shared.Animacoes.CriaturasMx.GoblinQuaternius),
	EsqueletoQuaternius = require(Shared.Animacoes.CriaturasMx.EsqueletoQuaternius),
}
local MODULOS = { "BandidoEspadaQuaternius", "BandidoPorreteQuaternius", "GoblinQuaternius", "EsqueletoQuaternius" }
local NOMES = { "ReacaoLeve", "ReacaoForte", "Esquiva", "EsquivaLado", "EsquivaLadoD", "Bloqueio", "MorrerMx" }

return {
	["cada humanoide tem os 7 clipes, válidos pelo contrato de AnimacaoCriatura"] = function(t)
		for _, m in ipairs(MODULOS) do
			local dados = DADOS[m]
			t.eq(dados.modulo, m)
			local ok, por = Anim.validar(dados)
			t.ok(ok, m .. ": " .. tostring(por))
			for _, n in ipairs(NOMES) do t.ok(dados.clipes[n] ~= nil, m .. " sem " .. n) end
		end
	end,
	["as peças animadas existem no modelo (PivosModelos) e o repouso começa em identidade"] = function(t)
		for _, m in ipairs(MODULOS) do
			local dados = DADOS[m]
			for n, clipe in dados.clipes do
				for grupo, chaves in clipe.pecas do
					t.ok(Pivos[m][grupo] ~= nil, m .. "." .. n .. ": grupo " .. grupo .. " sem pivô")
					local c = chaves[1]
					t.ok(math.abs(c[5] - 1) < 1e-3 and math.abs(c[6]) < 1e-3, m .. "." .. n .. "." .. grupo .. " não começa no repouso")
				end
			end
		end
	end,
	["reações que terminam de pé voltam ao repouso; a morte segura o último quadro"] = function(t)
		for _, m in ipairs(MODULOS) do
			local dados = DADOS[m]
			for _, n in ipairs({ "ReacaoLeve", "ReacaoForte", "Esquiva", "EsquivaLado", "EsquivaLadoD", "Bloqueio" }) do
				local clipe = dados.clipes[n]
				t.ok(not clipe.segurar, n .. " não segura")
				for grupo, chaves in clipe.pecas do
					local u = chaves[#chaves]
					t.ok(math.abs(u[5] - 1) < 0.02 and math.abs(u[6]) + math.abs(u[7]) + math.abs(u[8]) < 0.05, m .. "." .. n .. "." .. grupo .. " termina fora do repouso")
				end
			end
			t.ok(dados.clipes.MorrerMx.segurar, "morte segura")
		end
	end,
	["todo clipe decidido por ReacoesAlvo existe nos humanoides"] = function(t)
		local dados = DADOS.GoblinQuaternius
		for _, r in ipairs({ "esquiva", "bloqueio", "recuo", "cambaleio", "recuo-forte", "larga-arma", "membro-atingido" }) do
			for v = 0, 2 do
				local n = Reacoes.clipeCriatura(r, 1.2, v)
				t.ok(n ~= nil and dados.clipes[n] ~= nil, r .. " -> " .. tostring(n))
			end
		end
	end,
}
