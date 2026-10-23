-- T28: execute em Server num Play de teste. O executor substitui FIXTURE_JSON
-- pelo conteúdo de tools/fixtures/ficha-v2-aria.json (entre colchetes longos).
-- Usa o importador real com dependências isoladas; não altera mesa ou DataStore.
local HttpService = game:GetService("HttpService")
local Import = require(game.ServerScriptService.Server.FichaV2Import)
local Catalogo = require(game.ReplicatedStorage.Shared.Livro.Catalogo)
local fixture = HttpService:JSONDecode(FIXTURE_JSON)
fixture.calculated.maxima.pt, fixture.calculated.maxima.pp = 5, 3
fixture.session.current.pt, fixture.session.current.pp = 3, 2
local player = { UserId = 999 }
local tokens, handlers = {}, {}
local visible, generation = true, 1
local api = Import.start({
	handlers = handlers, tokens = tokens, catalogo = Catalogo,
	filterText = function(text)
		return if text == "pelo arqueiro da torre" then "[nota filtrada]" else text
	end,
	stillMaster = function() return true end,
	generation = function() return generation end,
	ocupado = function() return false end,
	isPresentUser = function() return true end,
	canSeeStats = function() return visible end,
	logMasters = function() end,
})
handlers.createToken = function(_, payload)
	tokens.t1 = {
		id = "t1", version = 1, name = payload.name,
		pv = payload.pvMax, pvMax = payload.pvMax,
		mana = payload.manaMax, manaMax = payload.manaMax,
		conditions = {},
	}
	return nil, "t1"
end
handlers.updateToken = function(_, payload)
	local token = tokens[payload.id]
	for _, key in { "name", "pv", "pvMax", "mana", "manaMax" } do
		if payload[key] ~= nil then token[key] = payload[key] end
	end
	token.version += 1
	return nil
end
local report, failures = {}, 0
local function check(name, condition)
	if not condition then failures += 1 end
	table.insert(report, (if condition then "OK " else "FALHA ") .. name)
end
local function send(command, payload)
	local err, data = handlers[command](player, payload, true)
	assert(not err, command .. ": " .. tostring(err))
	return data
end
local function propose(options)
	local json = HttpService:JSONEncode(fixture)
	local payload = options or {}
	payload.byteCount, payload.partCount = #json, math.ceil(#json / 4096)
	local upload = send("fichaImportBegin", payload)
	for index = 1, payload.partCount do
		send("fichaImportPart", { uploadId = upload.uploadId, index = index,
			text = string.sub(json, (index - 1) * 4096 + 1, index * 4096) })
	end
	local result = send("fichaImportCommit", { uploadId = upload.uploadId })
	return { proposalId = result.proposalId, version = 1 }
end
local proposal = propose()
check("nenhuma ficha antes da aprovação", tokens.t1 == nil)
send("fichaImportApply", proposal)
check("nota do corpo passou pelo filtro", tokens.t1.ficha2.session.conditions[1].note == "[nota filtrada]")
check("nota aplicada à mesa também passou pelo filtro", tokens.t1.conditions[1].note == "[nota filtrada]")
local _, publicDetail = handlers.fichaDetalhe(player, { id = "t1" }, false)
check("observador com atributos públicos não recebe notas privadas", publicDetail.ficha2.session.conditions[1].note == nil)
check("aprovação consumida não aplica duas vezes", handlers.fichaImportApply(player, proposal, true) ~= nil)

tokens.t1.pv, tokens.t1.mana = 7, 4
tokens.t1.conditions = {}
tokens.t1.version += 1
tokens.t1.ficha2.session.current.pt, tokens.t1.ficha2.session.current.pp = 1, 0
tokens.t1.ficha2.session.shortRests = 1
local detail = send("fichaDetalhe", { id = "t1" })
check("detalhe acompanha PV atual da mesa", detail.ficha2.session.current.pv == 7)
check("detalhe acompanha PM atual da mesa", detail.ficha2.session.current.pm == 4)
check("detalhe acompanha condições removidas", #detail.ficha2.session.conditions == 0)
visible = false
check("detalhe é recusado sem permissão", handlers.fichaDetalhe(player, { id = "t1" }) ~= nil)
visible = true

proposal = propose({ targetId = "t1", sessionPolicy = "preserve" })
send("fichaImportApply", proposal)
check("atualização preserva PV e PM da mesa", tokens.t1.pv == 7 and tokens.t1.mana == 4)
check("preserve mantém PT PP e descansos", tokens.t1.ficha2.session.current.pt == 1 and tokens.t1.ficha2.session.current.pp == 0 and tokens.t1.ficha2.session.shortRests == 1)
detail = send("fichaDetalhe", { id = "t1" })
check("detalhe após preservar não volta aos recursos do site", detail.ficha2.session.current.pv == 7 and detail.ficha2.session.current.pm == 4)
proposal = propose({ targetId = "t1" })
generation += 1
check("detalhe muda de versão ao trocar a geração", send("fichaDetalhe", { id = "t1" }).version ~= detail.version)
check("troca de mesa invalida aprovação antiga", handlers.fichaImportApply(player, proposal, true) ~= nil)
api.descartarTudo()
table.insert(report, string.format("RESUMO: %d falha(s)", failures))
return table.concat(report, "\n")
