-- SOMENTE STUDIO: cria Instances.
local P = require(script.Parent.Parent.PersistenciaDeEstudio)

return {
	["so usa memoria no Studio com place nao publicado"] = function(t)
		t.eq(P.deveUsarMemoria(true, 0), true)
		t.eq(P.deveUsarMemoria(true, 12345), false)
		t.eq(P.deveUsarMemoria(false, 0), false)
		t.eq(P.deveUsarMemoria(nil, 0), false)
	end,
	["cria a configuracao reconhecida pela persistencia e nao duplica"] = function(t)
		local alvo = Instance.new("Folder")
		local guid = "{AAAAAAAA-BBBB-CCCC-DDDD-0123456789AB}"
		local pasta = P.preparar({ emStudio = true, gameId = 0, armazenamento = alvo, novoGuid = function() return guid end })
		t.eq(pasta.Name, "PersonagemTestConfig")
		local scope = pasta:GetAttribute("Scope")
		t.eq(#scope, 37)
		t.ok(string.match(scope, "^test_%x+$") ~= nil, scope)
		t.eq(pasta:GetAttribute("Mode"), "memory")
		t.eq(P.preparar({ emStudio = true, gameId = 0, armazenamento = alvo }), pasta)
		t.eq(#alvo:GetChildren(), 1)
		alvo:Destroy()
	end,
	["publicado ou fora do Studio nao cria nada"] = function(t)
		local alvo = Instance.new("Folder")
		t.eq(P.preparar({ emStudio = true, gameId = 99, armazenamento = alvo }), nil)
		t.eq(P.preparar({ emStudio = false, gameId = 0, armazenamento = alvo }), nil)
		t.eq(#alvo:GetChildren(), 0)
		alvo:Destroy()
	end,
}
