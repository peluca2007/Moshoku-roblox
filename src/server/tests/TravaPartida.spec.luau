local Trava = require(game:GetService("ReplicatedStorage").Shared.TravaPartida)

return {
	["modos compartilham exclusao mesmo durante yield"] = function(t)
		local trava = Trava.new()
		local chamadas = 0
		local primeiro = trava.proteger(function()
			coroutine.yield("criando")
			return nil, "ficha"
		end)
		local segundo = trava.proteger(function() chamadas += 1 end)
		local thread = coroutine.create(primeiro)
		local ok, etapa = coroutine.resume(thread)
		t.ok(ok); t.eq(etapa, "criando"); t.ok(trava.ocupada())
		t.ok(type(segundo()) == "string"); t.eq(chamadas, 0)
		local terminou, erro, ficha = coroutine.resume(thread)
		t.ok(terminou); t.eq(erro, nil); t.eq(ficha, "ficha")
		t.eq(trava.ocupada(), false)
		segundo(); t.eq(chamadas, 1)
	end,
	["falha interna libera trava e continua visivel"] = function(t)
		local trava = Trava.new()
		local ok, erro = pcall(trava.proteger(function() error("falha de criacao") end))
		t.eq(ok, false); t.ok(string.find(tostring(erro), "falha de criacao", 1, true))
		t.eq(trava.ocupada(), false)
		t.eq(trava.proteger(function() return "nova tentativa" end)(), "nova tentativa")
	end,
	["recusa normal libera trava e preserva argumentos"] = function(t)
		local trava = Trava.new()
		local fn = trava.proteger(function(a, b, c)
			t.eq(a, 7); t.eq(b, nil); t.eq(c, true)
			return "recusado"
		end)
		t.eq(fn(7, nil, true), "recusado"); t.eq(trava.ocupada(), false)
	end,
	["arenas independentes nao se bloqueiam"] = function(t)
		local a, b = Trava.new(), Trava.new()
		local thread = coroutine.create(a.proteger(function() coroutine.yield() end))
		t.ok(coroutine.resume(thread))
		t.eq(b.proteger(function() return 42 end)(), 42)
		t.ok(coroutine.resume(thread))
	end,
}
