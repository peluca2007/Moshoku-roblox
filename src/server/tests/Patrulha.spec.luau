-- SOMENTE STUDIO no harness padrao (caminho server); tambem executado por inline no Luau CLI. Testa o módulo novo do servidor pela hierarquia do place.
local Patrulha = require(script.Parent.Parent.Mundo.Patrulha)

return {
 ["visao obstruida e alvo pelas costas nao detectam"] = function(t)
  t.eq(Patrulha.deveDetectar(1, 1, true, false), false)
  t.eq(Patrulha.deveDetectar(1, 1, false, true), false)
  t.eq(Patrulha.dentroDoCone(Vector3.zero, Vector3.new(0,0,-1), Vector3.new(0,0,5), 20, 100), false)
 end,

	["cone exige direção e distância; detecção respeita intervalo"] = function(t)
		local origem = Vector3.zero
		t.eq(Patrulha.dentroDoCone(origem, Vector3.new(0, 0, -1), Vector3.new(0, 0, -8), 10, 90), true)
		t.eq(Patrulha.dentroDoCone(origem, Vector3.new(0, 0, -1), Vector3.new(8, 0, 0), 10, 90), false)
		t.eq(Patrulha.dentroDoCone(origem, Vector3.new(0, 0, -1), Vector3.new(0, 0, -11), 10, 90), false)
		local detectada, proxima = Patrulha.deveDetectar(1, 1, true, true)
		t.eq(detectada, true)
		t.eq(proxima, 1.25)
		detectada = Patrulha.deveDetectar(1.1, 1.25, true, true)
		t.eq(detectada, false)
		t.eq(Patrulha.proximoPonto(3, 3), 1)
	end,
}
