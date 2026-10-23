local Sons = require(game:GetService("ReplicatedStorage").Shared.Sons)
return {
	["nenhuma vocalizacao entra no catalogo"] = function(t)
		t.eq(Sons.ARQUIVOS.buff, nil)
		t.eq(Sons.ARQUIVOS.assobio, nil)
		local total = 0
		for chave in Sons.ARQUIVOS do
			t.eq(string.find(chave, "grito", 1, true), nil)
			total += 1
		end
		t.eq(total, 19)
		for chave, id in Sons.IDS do
			t.ok(Sons.ARQUIVOS[chave])
			t.ok(string.match(id, "^rbxassetid://%d+$"))
		end
	end,
	["erro nao toca impacto e ataque sem dano nao inventa golpe"] = function(t)
		t.eq(Sons.impacto("mesa/ataque-basico", "basico", { g = "golpe" }, { acertou = false, dano = 4 }), nil)
		t.eq(Sons.impacto("x", "basico", { g = "golpe" }, { dano = 0 }), nil)
	end,
	["grito e provocar nao reutilizam voz nem espada"] = function(t)
		t.eq(Sons.lancamento("provocar", "deus-da-agua-corpo", { g = "grito" }), nil)
		t.eq(Sons.impacto("provocar", "deus-da-agua-corpo", { g = "grito" }, { dano = 2 }), nil)
	end,
	["gestos fisicos e magia recebem efeitos distintos"] = function(t)
		t.eq(Sons.lancamento("mesa/ataque-basico", "basico", { g = "golpe" }), "espada-corte")
		t.eq(Sons.lancamento("ability/deus-da-espada/golpe-continuo", "deus-da-espada", { g = "golpe" }), "espada-combo")
		t.eq(Sons.lancamento("cabecada", "armas-pesadas", { g = "cabecada" }), nil)
		t.eq(Sons.impacto("cabecada", "armas-pesadas", { g = "cabecada" }, { dano = 3 }), "soco")
		t.eq(Sons.impacto("disparo", "arquearia", { g = "disparo" }, { dano = 3 }), "flecha-impacto-1")
		t.eq(Sons.lancamento("magia", "fogo", { g = "conjuro" }), "fogo")
		t.eq(Sons.impacto("magia", "fogo", { g = "conjuro" }, { dano = 3 }), "fogo-impacto")
		t.eq(Sons.lancamento("lamina-de-gelo", "agua", { g = "conjuro" }), "gelo")
		t.eq(Sons.impacto("cura", "cura", { g = "conjuro" }, { cura = 3 }), "cura-1")
	end,
	["cura nao duplica conjuracao e resultado"] = function(t)
		t.eq(Sons.lancamento("cura", "cura", { g = "conjuro" }), nil)
		t.eq(Sons.impacto("cura", "cura", { g = "conjuro" }, { cura = 3 }), "cura-1")
		t.eq(Sons.impacto("cura", "desintoxicacao", { g = "conjuro" }, { cura = 3 }), "cura-2")
	end,
}
