local Shared = game:GetService("ReplicatedStorage").Shared
local Save = require(Shared.Regras.RunSave)
local Run = require(Shared.Regras.Run)
local Criacao = require(Shared.Regras.RunCriacao)

local menor = { NextInteger = function(_, lo) return lo end }

local function nova()
	local run = Run.nova({ jogadores = { 1001, 1002, "convidado" }, objetivo = { id = "entregar", prazoDias = 10 }, semente = 9 })
	run = Run.gastarDias(run, 2.5)
	run = Run.definirFlag(run, "ponte-aberta")
	run = Run.marcarAusente(run, 1002)
	return run
end

return {
	["serializar troca userId numerico por texto e e aceito pelo DataStore"] = function(t)
		local dado = Save.serializar(nova(), { [1001] = Criacao.planejar("semArvore", menor) })
		t.ok(dado ~= nil)
		t.eq(dado.run.jogadores["1001"] ~= nil, true)
		t.eq(dado.run.jogadores[1001], nil)
		t.eq(dado.tiposDeId["1001"], "number")
		t.eq(dado.tiposDeId["convidado"], "string")
		t.eq(Save.chavesSaoTexto(dado), true)
		t.eq(Save.chavesSaoTexto({ [1] = "a", [2] = "b" }), true) -- lista é permitida
		t.eq(Save.chavesSaoTexto({ [1001] = {} , x = 1 }), false)
	end,
	["ida e volta preserva a run, os planos e os tipos de id"] = function(t)
		local original = nova()
		local planos = { [1001] = Criacao.planejar("zero", menor), [1002] = Criacao.planejar("semArvore", menor) }
		local run, planosVolta = Save.restaurar(Save.serializar(original, planos))
		t.ok(run ~= nil)
		t.eq(run.dia, 2.5)
		t.eq(Run.temFlag(run, "ponte-aberta"), true)
		t.eq(run.jogadores[1001].presente, true)
		t.eq(run.jogadores[1002].presente, false)
		t.eq(run.jogadores[1002].ausenteDesde, 2.5)
		t.eq(run.jogadores["convidado"].presente, true)
		t.eq(run.jogadores["1001"], nil)
		t.eq(planosVolta[1001].modo, "zero")
		t.eq(#planosVolta[1001].oferta, 6)
		t.eq(planosVolta[1002].paExtra, Criacao.PA_EXTRA_SEM_ARVORE)
		t.eq(Run.estadoValido(run), true)
	end,
	["extras planos ida e volta; extra invalido e recusado"] = function(t)
		local dado = Save.serializar(nova(), nil, { eventoPendente = "ponte-quebrada", n = 2, b = true })
		t.eq(Save.chavesSaoTexto(dado), true)
		local run, _, extras = Save.restaurar(dado)
		t.ok(run ~= nil)
		t.eq(extras.eventoPendente, "ponte-quebrada")
		t.eq(extras.n, 2)
		t.eq((Save.serializar(nova(), nil, { x = {} })), nil)
		t.eq((Save.serializar(nova(), nil, { [1] = "a" })), nil)
		local _, _, vazio = Save.restaurar(Save.serializar(nova(), nil))
		t.eq(next(vazio), nil)
	end,
	["a run restaurada continua jogavel"] = function(t)
		local run = Save.restaurar(Save.serializar(nova(), nil))
		local depois, expirou = Run.gastarDias(run, 8)
		t.eq(depois.dia, 10.5)
		t.eq(expirou, true)
		local volta, perdidos = Run.retornar(depois, 1002)
		t.eq(perdidos, 8)
		t.eq(volta.jogadores[1002].presente, true)
	end,
	["serializar nao altera a run original"] = function(t)
		local original = nova()
		Save.serializar(original, nil)
		t.eq(original.jogadores[1001] ~= nil, true)
		t.eq(original.jogadores["1001"], nil)
	end,
	["recusa plano de quem nao esta na run, plano invalido e estado invalido"] = function(t)
		t.eq((Save.serializar(nova(), { [9999] = { modo = "zero" } })), nil)
		t.eq((Save.serializar(nova(), { [1001] = { modo = "magico" } })), nil)
		t.eq((Save.serializar({ versao = 1 }, nil)), nil)
		t.eq((Save.serializar(nil, nil)), nil)
	end,
	["restaurar recusa versao desconhecida, save incompleto e estado corrompido"] = function(t)
		local bom = Save.serializar(nova(), nil)
		t.eq((Save.restaurar(nil)), nil)
		t.eq((Save.restaurar({ versao = 99, run = bom.run, tiposDeId = bom.tiposDeId })), nil)
		t.eq((Save.restaurar({ versao = 1, run = bom.run })), nil)
		local semTipo = table.clone(bom)
		semTipo.tiposDeId = {}
		local _, motivo = Save.restaurar(semTipo)
		t.ok(motivo ~= nil)
		local quebrado = table.clone(bom)
		quebrado.run = table.clone(bom.run)
		quebrado.run.objetivo = { id = "x" }
		t.eq((Save.restaurar(quebrado)), nil)
	end,
}
