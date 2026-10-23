-- Testa o MesaState real com transporte e agendamento síncronos simulados.
local receive, requests = nil, {}
local pronta, esperasProntidao = false, 0
local readinessChanged = {
	Wait = function()
		esperasProntidao += 1
		pronta = true
	end,
}
local remote = {
	OnClientEvent = { Connect = function(_, fn) receive = fn end },
	FireServer = function(_, command, payload) table.insert(requests, { command, payload }) end,
}
local shared = { UploadPartes = "upload", WaitForChild = function() return "protocol" end }
local storage = {
	Shared = shared,
	GetAttribute = function(_, name)
		assert(name == "MesaPronta")
		return if pronta then true else nil
	end,
	GetAttributeChangedSignal = function(_, name)
		assert(name == "MesaPronta")
		return readinessChanged
	end,
	WaitForChild = function(_, name)
		if name == "Mesa" then assert(pronta, "remote awaited before server readiness") end
		return if name == "Shared" then shared else remote
	end,
}
local game = { GetService = function(_, name)
	return if name == "Players" then { LocalPlayer = { UserId = 10 } } else storage
end }
local require = function(name)
	return if name == "protocol" then { REMOTE = "Mesa", READY_ATTRIBUTE = "MesaPronta", LIMITS = { log = 50 } } else {}
end
local task = { spawn = function(fn, ...) fn(...) end }
local state = (function()
-- STATE_SOURCE
end)()
state.start()
assert(esperasProntidao == 1 and pronta, "aguarda o servidor quando o cliente chega antes do fim da inicialização")
local function snapshot(version, master)
	receive("snapshot", { you = { master = master }, tokens = { { id = "t1", ficha2Versao = version } } })
end
snapshot("1:1", true)
assert(state.fichaDetalhe("t1") == nil and #requests == 1)
state.fichaDetalhe("t1")
assert(#requests == 1, "não repete pedido pendente igual")
receive("fichaDetalhe", { id = "t1", version = "1:1", ficha2 = { name = "primeira" } })
assert(state.fichaDetalhe("t1").name == "primeira")
snapshot("2:1", true)
assert(state.fichaDetalhe("t1") == nil and #requests == 2, "troca de campanha invalida mesmo id/version local")
receive("fichaDetalhe", { id = "t1", version = "1:1", ficha2 = { name = "atrasada" } })
assert(state.fichaDetalhe("t1") == nil, "resposta atrasada não reaparece")
snapshot("2:2", true)
assert(state.fichaDetalhe("t1") == nil and #requests == 3, "mudança durante pedido não aguarda timeout")
receive("fichaDetalhe", { id = "t1", version = "2:2", ficha2 = { name = "privada" } })
snapshot("2:2", false)
assert(state.fichaDetalhe("t1") == nil and #requests == 4, "mudança de papel descarta cache privado")
receive("fichaDetalhe", { id = "t1", version = "2:2", ficha2 = { name = "pública" } })
snapshot(nil, false)
assert(state.fichaDetalhe("t1") == nil, "perda de acesso remove detalhe")
receive("fichaDetalhe", { id = "t1", version = "2:2", ficha2 = { name = "sem acesso" } })
snapshot("2:2", true)
assert(state.fichaDetalhe("t1") == nil, "pacote sem acesso não ficou em cache")
print("MesaState: cache, geração, resposta atrasada e permissões OK")
