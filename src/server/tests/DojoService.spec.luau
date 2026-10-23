-- SOMENTE STUDIO: carrega o serviço de servidor e testa o validador de payloads.
local DojoService = require(script.Parent.Parent.DojoService)

return {
	["consulta e início aceitam somente comando sem campos extras"] = function(t)
		t.eq(DojoService.payloadValido({ acao = "consultar" }), true)
		t.eq(DojoService.payloadValido({ acao = "iniciar" }), true)
		t.eq(DojoService.payloadValido({ acao = "iniciar", arvore = "tree/fogo" }), false)
	end,
	["escolha aceita somente as três portas do dilema"] = function(t)
		for _, porta in { "travado", "livre", "marca" } do
			t.eq(DojoService.payloadValido({ acao = "escolher", porta = porta }), true)
		end
		t.eq(DojoService.payloadValido({ acao = "escolher", porta = "livre", userId = 1 }), false)
		t.eq(DojoService.payloadValido({ acao = "escolher", porta = "outro" }), false)
		t.eq(DojoService.payloadValido("iniciar"), false)
	end,
}
