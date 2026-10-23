local JsonEstrutura = require(game:GetService("ReplicatedStorage").Shared.JsonEstrutura)

local LIMITES = { profundidade = 12, nos = 16384 }
local function ok(texto)
	return (JsonEstrutura.verificar(texto, LIMITES))
end
local function motivo(texto, limites)
	local _, m = JsonEstrutura.verificar(texto, limites or LIMITES)
	return m or ""
end

return {
	["aceita JSON válido com acentos, escapes e números"] = function(t)
		t.ok(ok('{"nome":"Irmão Ossório","pv":44,"x":-1.5e2,"s":"a\\"b\\n\\u00e3","l":[1,true,false,{}],"v":[]}'))
		t.ok(ok("  [ 1 , 2 ]  "))
	end,
	["recusa chave repetida (o JSONDecode ficaria só com a última)"] = function(t)
		t.ok(string.find(motivo('{"pv":1,"pv":9999}'), "chave repetida", 1, true) ~= nil)
		t.ok(string.find(motivo('{"a":{"b":1,"b":2}}'), "chave repetida", 1, true) ~= nil)
		t.ok(ok('{"a":{"b":1},"c":{"b":2}}'), "mesma chave em objetos diferentes é válida")
	end,
	["chave repetida escrita com escape também é pega"] = function(t)
		t.ok(string.find(motivo('{"a":1,"\\u0061":2}'), "chave repetida", 1, true) ~= nil, "a = \\u0061")
		t.ok(string.find(motivo('{"\\u00e3":1,"ã":2}'), "chave repetida", 1, true) ~= nil, "ã = \\u00e3")
		t.ok(not ok('{"a":"\\ud800"}'), "surrogate isolado")
		t.ok(ok('{"e":"\\ud83d\\ude00"}'), "par de surrogates válido")
		t.ok(string.find(motivo('{"\\u0061":1,"\\u0061":2}'), "chave repetida", 1, true) ~= nil)
	end,
	["recusa null"] = function(t)
		t.ok(string.find(motivo('{"a":null}'), "null", 1, true) ~= nil)
		t.ok(string.find(motivo("[1,null,3]"), "null", 1, true) ~= nil)
	end,
	["limita profundidade e quantidade de nós"] = function(t)
		t.ok(not ok(string.rep("[", 13) .. string.rep("]", 13)))
		t.ok(ok(string.rep("[", 12) .. string.rep("]", 12)))
		local muitos = "[" .. string.rep("1,", 20) .. "1]"
		t.ok(string.find(motivo(muitos, { profundidade = 12, nos = 10 }), "valores", 1, true) ~= nil)
	end,
	["recusa sintaxe quebrada"] = function(t)
		for _, ruim in { "", "{", '{"a":1,}', '{"a" 1}', "[1 2]", '{"a":01}', '"sem fim', "{} lixo", "'aspas simples'", '{"a":tru}' } do
			t.ok(not ok(ruim), ruim)
		end
	end,
	["recusa UTF-8 inválido e controle dentro de texto"] = function(t)
		t.ok(not ok('{"a":"\255"}'))
		t.ok(not ok('{"a":"linha\nquebrada"}'))
		t.ok(not ok(42), "não é texto")
	end,
}
