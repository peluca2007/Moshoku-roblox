-- Regras puras da tela de criação rápida.
local Tela = require(game:GetService("ReplicatedStorage").Shared.Regras.CriacaoRapidaTela)
local function nomeValido(n) if #n >= 2 then return n end return nil, "curto" end
return {
	["estado dos passos: atual, feitos e pendentes"] = function(t)
		local a = Tela.estadoDosPassos(2)
		t.eq(a[1], "feito"); t.eq(a[2], "atual"); t.eq(a[3], "pendente")
		t.eq(Tela.estadoDosPassos(99)[3], "atual")
		t.eq(Tela.estadoDosPassos(-4)[1], "atual")
	end,
	["continuar só habilita com etapa válida"] = function(t)
		t.eq(Tela.passoValido(1, { raceId = nil }, nomeValido), false)
		t.eq(Tela.passoValido(1, { raceId = "humano" }, nomeValido), true)
		t.eq(Tela.passoValido(2, { raceId = "humano" }, nomeValido), true)
		t.eq(Tela.passoValido(3, { raceId = "humano", nome = "" }, nomeValido), false)
		t.eq(Tela.passoValido(3, { raceId = "humano", nome = "Ana" }, nomeValido), true)
		t.eq(Tela.passoValido(3, { raceId = "humano", nome = "Ana" }, nil), false)
	end,
	["rótulo do botão principal e Voltar"] = function(t)
		t.eq(Tela.rotuloAvancar(1, false), "Continuar")
		t.eq(Tela.rotuloAvancar(3, false), "Começar a aventura")
		t.eq(Tela.rotuloAvancar(3, true), "Criando seu aventureiro…")
		t.eq(Tela.mostraVoltar(1), false)
		t.eq(Tela.mostraVoltar(2), true)
	end,
}
