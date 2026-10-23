local Shared = game:GetService("ReplicatedStorage").Shared
local Camera = require(Shared.CameraMundoCalculo)
local Ambiente = require(Shared.Mundo.AmbientePerfis)
local Modelos = require(Shared.Mundo.ModelosCriaturas)

return {
	["copas acima do avatar incluem bordas e rejeitam chao ou distancia"] = function(t)
		t.ok(Camera.copaSobreAvatar(0, 12, 0, 5, 5, 5))
		t.ok(Camera.copaSobreAvatar(10, 12, 0, 3, 5, 3), "origem fora, borda no raio")
		t.ok(not Camera.copaSobreAvatar(10.1, 12, 0, 3, 5, 3))
		t.ok(not Camera.copaSobreAvatar(0, 0, 0, 5, 1, 5), "folhas no chao")
		t.ok(not Camera.copaSobreAvatar(0, 54, 0, 5, 5, 5), "acima do teto de busca")
		t.ok(not Camera.copaSobreAvatar(10, 12, 10, 3, 5, 3), "distancia radial, nao quadrada")
	end,
	["nomes cobrem arvores locais e pinheiros sem incluir criaturas e portao"] = function(t)
		for _, nome in { "Copa", "CopaClara", "Folhas", "FolhasClaras", "Leaves1" } do
			t.ok(Camera.folhagem(nome), nome)
		end
		for _, nome in { "Tronco", "Trunk1", "Corpo_Folha", "Folha aberta do portão", "Telhado" } do
			t.ok(not Camera.folhagem(nome), nome)
		end
	end,
	["luz pessoal acompanha noite e floresta e desliga na vila diurna e sala"] = function(t)
		t.ok(Ambiente.luzPessoal(0, -450, false, 12))
		t.ok(Ambiente.luzPessoal(0, -450, false, 0))
		t.ok(Ambiente.luzPessoal(0, -100, false, 5.99))
		t.ok(Ambiente.luzPessoal(0, -100, false, 18))
		t.ok(not Ambiente.luzPessoal(0, -100, false, 6))
		t.ok(not Ambiente.luzPessoal(0, -100, false, 17.99))
		t.ok(not Ambiente.luzPessoal(0, -450, true, 0))
		t.ok(not Ambiente.luzPessoal(0, -100, false, nil))
		t.ok(Ambiente.luzPessoal(0, -450, false, nil))
		t.ok(not Ambiente.luzPessoal(600, -450, false, 12), "ruinas nao sao floresta")
	end,
	["materiais de pele pelo e casca ficam lisos com brilho e metal preservados"] = function(t)
		for _, material in { "Grass", "Fabric", "Wood", "Slate", "Plastic", "Neon" } do
			t.eq(Modelos.material("Corpo_Pelo", material), "SmoothPlastic")
		end
		t.eq(Modelos.material("Cabeca_Brilho", "Plastic"), "Neon")
		t.eq(Modelos.material("Arma_Ferro", "Metal"), "Metal")
		t.eq(Modelos.material("Corpo_Armadura", "Metal"), "Metal")
	end,
}
