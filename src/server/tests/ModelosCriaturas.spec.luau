local Shared = game:GetService("ReplicatedStorage").Shared
local Modelos = require(Shared.Mundo.ModelosCriaturas)
local Anim = require(Shared.Mundo.AnimacaoCriatura)
local Pivos = require(Shared.Mundo.PivosModelos)

local CRIATURAS = {
	"creature/goblin-batedor", "creature/lobo-cinzento", "creature/urso-de-presas-vermelhas",
	"creature/bandido-de-estrada", "creature/rato-gigante", "creature/aranha-da-floresta",
	"creature/treant-anciao", "creature/golem-de-pedra-menor",
}

return {
	["toda criatura do mundo aberto tem modelo com pivôs"] = function(t)
		for _, id in ipairs(CRIATURAS) do
			local info = Modelos.escolher(id, 0)
			t.ok(info ~= nil, id)
			t.ok(Pivos[info.modulo] ~= nil, "pivôs de " .. info.modulo)
			t.ok(info.escalaCombate > 0 and info.escalaMundo > 0)
		end
		t.eq(Modelos.escolher("creature/inexistente", 0), nil)
	end,
	["variante escolhe entre os modelos de forma estável"] = function(t)
		t.eq(Modelos.escolher("creature/goblin-batedor", 0).modulo, "GoblinFaca")
		t.eq(Modelos.escolher("creature/goblin-batedor", 1).modulo, "GoblinArco")
		t.eq(Modelos.escolher("creature/goblin-batedor", 2).modulo, "GoblinFaca")
		t.eq(Modelos.variante("Goblin rondando o campo"), Modelos.variante("Goblin rondando o campo"))
	end,
	["prefixos legados das patrulhas apontam para criaturas do mapa"] = function(t)
		for prefixo, id in pairs(Modelos.POR_PREFIXO) do
			t.ok(Modelos.POR_CRIATURA[id] ~= nil, prefixo)
		end
		t.eq(Modelos.criaturaDoPrefixo("Lobo"), "creature/lobo-cinzento")
		t.eq(Modelos.criaturaDoPrefixo(nil), nil)
	end,
	["grupos saem do nome Parte_Cor e a arma segue o braço mais próximo"] = function(t)
		t.eq(Anim.grupo("PernaE_Pelo"), "PernaE")
		t.eq(Anim.grupo("Corpo_PeleEscura"), "Corpo")
		t.eq(Anim.bracoDaArma(Pivos.GoblinFaca), "BracoD")
		t.eq(Anim.bracoDaArma(Pivos.GoblinArco), "BracoE")
		t.eq(Anim.bracoDaArma(Pivos.LoboCinzento), nil)
	end,
	["andar balança pernas opostas e parado respira"] = function(t)
		local c = { tipo = "humanoide", fase = math.pi / 2, mov = 1, t = 0 }
		local pe = Anim.pose("PernaE", c)
		local pd = Anim.pose("PernaD", c)
		t.ok(pe > 0.3 and pd < -0.3 and math.abs(pe + pd) < 1e-6)
		local be = Anim.pose("BracoE", c)
		t.ok(be < 0, "braço oposto à perna do mesmo lado")
		local parado = { tipo = "humanoide", fase = 0, mov = 0, t = 0.65 }
		t.eq(Anim.pose("PernaE", parado), 0)
		local dy = Anim.corpo(parado)
		t.ok(dy ~= 0 and math.abs(dy) <= 0.04)
	end,
	["cabeça acompanha o alvo com limite e golpe levanta e desce o braço da arma"] = function(t)
		local _, yaw = Anim.pose("Cabeca", { tipo = "humanoide", fase = 0, mov = 1, t = 0, yawCabeca = 3 })
		t.ok(yaw <= 1.2 + 1e-6)
		local c = { tipo = "humanoide", bracoArma = "BracoD", mov = 0, t = 0, fase = 0 }
		c.golpe = 0.3
		local alto = Anim.pose("BracoD", c)
		c.golpe = 0.5
		local baixo = Anim.pose("BracoD", c)
		t.ok(alto < -1.5 and baixo > 1.0)
		t.eq(Anim.pose("Arma", c), Anim.pose("BracoD", c))
		c.golpe, c.tipo = 0.45, "quadrupede"
		local _, dz = Anim.corpo(c)
		t.ok(dz < -0.3, "quadrúpede avança no golpe (-Z é frente)")
	end,
}
