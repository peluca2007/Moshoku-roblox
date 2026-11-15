-- SOMENTE STUDIO: RunServico e PortaExpedicao usam serviços do Roblox (DataStore, Players, workspace).
local Servico = require(script.Parent.Parent.RunServico)
local Porta = require(script.Parent.Parent.PortaExpedicao)
local VilaLayout = require(game:GetService("ReplicatedStorage").Shared.Mundo.VilaLayout)

return {
	["acao descansar: sem campos extras, so tabela simples"] = function(t)
		t.eq(Servico.payloadValido({ acao = "descansar" }), true)
		t.eq(Servico.payloadValido({ acao = "descansar", tipo = "longo" }), false)
		t.eq(Servico.payloadValido({ acao = "descansar", dias = 1 }), false)
		t.eq(Servico.payloadValido(setmetatable({ acao = "descansar" }, {})), false)
		t.eq(Servico.payloadValido("descansar"), false)
		t.eq(Servico.payloadValido({ acao = "descansa" }), false)
	end,
	["acoes existentes continuam validas"] = function(t)
		t.eq(Servico.payloadValido({ acao = "consultar" }), true)
		t.eq(Servico.payloadValido({ acao = "lutar" }), true)
		t.eq(Servico.payloadValido({ acao = "votar", opcao = "entrar-esgoto" }), true)
		t.eq(Servico.payloadValido({ acao = "votar", opcao = 5 }), false)
		t.eq(Servico.payloadValido({ acao = "votar", opcao = "x", extra = 1 }), false)
	end,
	["acoes abandonar e retirarVoto: sem campos extras"] = function(t)
		t.eq(Servico.payloadValido({ acao = "abandonar" }), true)
		t.eq(Servico.payloadValido({ acao = "retirarVoto" }), true)
		t.eq(Servico.payloadValido({ acao = "abandonar", dias = 0 }), false)
		t.eq(Servico.payloadValido({ acao = "retirarVoto", opcao = "entrar-esgoto" }), false)
		t.eq(Servico.payloadValido({ acao = "retirarvoto" }), false)
	end,
	["porta: definirAtiva antes de start nao falha"] = function(t)
		Porta.definirAtiva(false)
		Porta.definirAtiva(true)
		t.ok(true)
	end,
	["porta do esgoto fica na praca e livre de construcoes"] = function(t)
		local ponto = Porta.escolherPonto()
		t.ok(ponto ~= nil, "sem ponto livre")
		local praca = VilaLayout.PRACA
		t.ok(math.abs(ponto.x - praca.x) <= praca.sx / 2 and math.abs(ponto.z - praca.z) <= praca.sz / 2, "fora da praça")
		for _, e in ipairs(VilaLayout.predios()) do
			t.ok(not VilaLayout.sobrepoe({ x = ponto.x, z = ponto.z, sx = 6, sz = 6 }, VilaLayout.ocupacao(e)), "sobrepõe " .. e.id)
		end
		t.ok(not VilaLayout.sobrepoe({ x = ponto.x, z = ponto.z, sx = 6, sz = 6 }, VilaLayout.CHAFARIZ), "sobrepõe o chafariz")
		local de = Porta.escolherPonto()
		t.eq(de.x, ponto.x) -- determinístico
		t.eq(de.z, ponto.z)
	end,
	["pertoDe recusa jogador sem avatar e sem porta"] = function(t)
		t.eq(Porta.pertoDe(nil), false)
		t.eq(Porta.pertoDe({ Character = nil }), false)
	end,
}
