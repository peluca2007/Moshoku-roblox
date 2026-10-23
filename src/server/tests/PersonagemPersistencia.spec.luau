-- SOMENTE STUDIO: cobre CAS e integridade sem acessar DataStore real.
local Persistencia = require(script.Parent.Parent.PersonagemPersistencia)
local Dojo = require(game:GetService("ReplicatedStorage").Shared.Regras.Dojo)

local function storeFake()
	local dados = {}
	return {
		dados = dados,
		GetAsync = function(self, chave)
			return self.dados[chave]
		end,
		UpdateAsync = function(self, chave, transformar)
			local proximo = transformar(self.dados[chave])
			if proximo ~= nil then self.dados[chave] = proximo end
			return self.dados[chave]
		end,
	}
end

local function perfil(nome)
	return {
		nome = nome,
		construcao = {
			raceId = "race/humano", startingTreeId = "tree/agua",
			attributeBase = { forca = 2 }, raceAttributeChoices = { "agilidade" },
		},
		habilidadesCompradas = { "ability/agua/Principiante/onda" },
	}
end

return {
	["A1 aparência v1 persiste e migra v5 sem apagar perfil"] = function(t)
		local A = require(game:GetService("ReplicatedStorage").Shared.Aparencia.Aparencia)
		local store = storeFake()
		local p = Persistencia.new({store=store})
		local antiga = perfil("Antiga")
		store.dados.user_4600 = {schemaVersion=5, revision=3, savedAt=1, perfil=antiga}
		local carregada, rev, erro = p:load(4600)
		t.eq(erro,nil); t.eq(rev,3); t.eq(carregada.aparencia,nil)
		carregada.aparencia = A.padrao("race/humano",12)
		carregada.aparencia.roupas.costas = "LadinoCapa" -- persistência verifica estrutura; sessão verifica posse
		t.eq(p:save(4600,carregada,rev),"ok")
		t.eq(store.dados.user_4600.schemaVersion,6)
		local lida = p:load(4600)
		t.eq(lida.aparencia.roupas.costas,"LadinoCapa")
		t.eq(lida.aparencia.rosto.olhos,carregada.aparencia.rosto.olhos)
		lida.aparencia.cores.pele = "OlhoAzul"
		t.eq(p:save(4600,lida,4),"invalido")
	end,
	["modo memória do Studio mantém escopo isolado sem usar DataStore"] = function(t)
		local ServerStorage = game:GetService("ServerStorage")
		local HttpService = game:GetService("HttpService")
		local config = ServerStorage:FindFirstChild(Persistencia.TEST_CONFIG_NAME)
		local criado = config == nil
		if criado then
			config = Instance.new("Folder")
			config.Name = Persistencia.TEST_CONFIG_NAME
			config.Parent = ServerStorage
		end
		local scopeAnterior = config:GetAttribute("Scope")
		local modeAnterior = config:GetAttribute("Mode")
		local scope = "test_" .. string.gsub(HttpService:GenerateGUID(false), "-", "")
		local resultadoTeste
		local ok, erro = pcall(function()
			config:SetAttribute("Scope", scope)
			config:SetAttribute("Mode", "memory")
			local primeira = Persistencia.new()
			t.eq(primeira.scope, scope)
			local vazio, revisao, erroCarga = primeira:load(4599)
			t.eq(vazio, nil); t.eq(revisao, 0); t.eq(erroCarga, nil)
			local status, novaRevisao = primeira:save(4599, perfil("Ária"), revisao)
			t.eq(status, "ok"); t.eq(novaRevisao, 1)

			local segunda = Persistencia.new()
			local carregado, revisaoCarregada, erroReleitura = segunda:load(4599)
			t.eq(erroReleitura, nil); t.eq(revisaoCarregada, 1); t.eq(carregado.nome, "Ária")
			carregado.construcao.raceId = "adulterada"
			local protegido = segunda:load(4599)
			t.eq(protegido.construcao.raceId, "race/humano")

			local outroScope = "test_" .. string.gsub(HttpService:GenerateGUID(false), "-", "")
			config:SetAttribute("Scope", outroScope)
			local isolada = Persistencia.new()
			local semPerfil, outraRevisao, outroErro = isolada:load(4599)
			t.eq(semPerfil, nil); t.eq(outraRevisao, 0); t.eq(outroErro, nil)
		end)
		config:SetAttribute("Scope", scopeAnterior)
		config:SetAttribute("Mode", modeAnterior)
		if criado then config:Destroy() end
		if not ok then error(erro) end
	end,
	["campo opcional de arma persiste sem mudar schema e registros antigos carregam"] = function(t)
		local store = storeFake()
		local persistencia = Persistencia.new({ store = store })
		t.eq(persistencia:save(4510, perfil("Antiga"), 0), "ok")
		local antiga = persistencia:load(4510)
		t.eq(antiga.armaInicialSourceLocalId, nil)
		local nova = perfil("Nova"); nova.armaInicialSourceLocalId = "kit-inicial-01"
		t.eq(persistencia:save(4510, nova, 1), "ok")
		local carregada, revisao, erro = persistencia:load(4510)
		t.eq(erro, nil); t.eq(revisao, 2)
		t.eq(carregada.armaInicialSourceLocalId, "kit-inicial-01")
		t.eq(store.dados.user_4510.schemaVersion, 6)
		local obsoleta = perfil("Obsoleta"); obsoleta.armaInicialSourceLocalId = "kit-inicial-02"
		t.eq(persistencia:save(4510, obsoleta, 1), "conflito")
		t.eq(store.dados.user_4510.perfil.armaInicialSourceLocalId, "kit-inicial-01")
	end,
	["recursos e contador de descanso usam o mesmo perfil pessoal e schema"] = function(t)
		local store = storeFake()
		local persistencia = Persistencia.new({ store = store })
		local ficha = perfil("Descanso")
		ficha.descanso = { atuais = { pv = 8, pm = 2, pt = 1, pp = 0 }, descansosCurtos = 2 }
		t.eq(persistencia:save(4513, ficha, 0), "ok")
		local carregada, revisao, erro = persistencia:load(4513)
		t.eq(erro, nil); t.eq(revisao, 1); t.eq(carregada.descanso.atuais.pv, 8)
		t.eq(carregada.descanso.descansosCurtos, 2); t.eq(store.dados.user_4513.schemaVersion, 6)
		ficha.descanso.descansosCurtos = 3
		t.eq(persistencia:save(4514, ficha, 0), "invalido")
	end,
	["migra registro v1 sem dojo para estado vazio e escreve v2 no próximo save"] = function(t)
		local store = storeFake()
		store.dados.user_4515 = { schemaVersion = 1, revision = 4, savedAt = 1, perfil = perfil("Antiga") }
		local persistencia = Persistencia.new({ store = store })
		local carregada, revisao, erro = persistencia:load(4515)
		t.eq(erro, nil); t.eq(revisao, 4); t.ok(Dojo.estadoValido(carregada.dojo))
		t.eq(store.dados.user_4515.schemaVersion, 1)
		local ok, novaRevisao = persistencia:save(4515, carregada, revisao)
		t.eq(ok, "ok"); t.eq(novaRevisao, 5); t.eq(store.dados.user_4515.schemaVersion, 6)
	end,
	["arma persistida recusa tipo vazio e tamanho impróprios"] = function(t)
		local store = storeFake()
		local persistencia = Persistencia.new({ store = store })
		for _, valor in { false, 12, {}, "", string.rep("a", 97) } do
			local registro = perfil("Inválida"); registro.armaInicialSourceLocalId = valor
			t.eq(persistencia:save(4511, registro, 0), "invalido")
			t.eq(store.dados.user_4511, nil)
			store.dados.user_4512 = { schemaVersion = 1, revision = 1, savedAt = 1, perfil = registro }
			local carregada, _, erro = persistencia:load(4512)
			t.eq(carregada, nil); t.ok(erro)
		end
	end,
	["salva e carrega somente perfil com revisão explícita"] = function(t)
		local persistencia = Persistencia.new({ store = storeFake() })
		local vazio, revisao, erro = persistencia:load(4501)
		t.eq(vazio, nil); t.eq(revisao, 0); t.eq(erro, nil)
		local outcome, novaRevisao = persistencia:save(4501, perfil("Ária"), revisao)
		t.eq(outcome, "ok"); t.eq(novaRevisao, 1)
		local carregado, revisaoLida, erroLeitura = persistencia:load(4501)
		t.eq(erroLeitura, nil); t.eq(revisaoLida, 1)
		t.eq(carregado.nome, "Ária")
		t.eq(carregado.habilidadesCompradas[1], "ability/agua/Principiante/onda")
	end,
	["conflito e registro inválido bloqueiam gravação sem sobrescrever"] = function(t)
		local store = storeFake()
		local persistencia = Persistencia.new({ store = store })
		local outcome, revision = persistencia:save(4502, perfil("Primeira"), 0)
		t.eq(outcome, "ok"); t.eq(revision, 1)
		local conflito = persistencia:save(4502, perfil("Antiga"), 0)
		t.eq(conflito, "conflito")
		t.eq(store.dados.user_4502.perfil.nome, "Primeira")
		store.dados.user_4502 = { schemaVersion = 99, revision = 1, savedAt = 1, perfil = perfil("Legado") }
		local registro, _, erro = persistencia:load(4502)
		t.eq(registro, nil); t.ok(erro)
		local invalidado = persistencia:save(4502, perfil("Sobrescrita"), 1)
		t.eq(invalidado, "invalido")
		t.eq(store.dados.user_4502.perfil.nome, "Legado")
	end,
	["recusa payload cíclico e não aceita UserId/revisão impróprios"] = function(t)
		local persistencia = Persistencia.new({ store = storeFake() })
		local ciclico = perfil("Ciclo"); ciclico.construcao.loop = ciclico.construcao
		t.eq(persistencia:save(4503, ciclico, 0), "invalido")
		t.eq(persistencia:save(0, perfil("Inválido"), 0), "invalido")
		t.eq(persistencia:save(4503, perfil("Inválido"), -1), "invalido")
	end,
	["ficha antiga recebe zero PO e schema atual persiste ouro e recibo de encontro"] = function(t)
		local store = storeFake()
		store.dados.user_4504 = { schemaVersion = 2, revision = 1, savedAt = 1, perfil = perfil("Legado") }
		local persistencia = Persistencia.new({ store = store })
		local carregada, revisao, erro = persistencia:load(4504)
		t.eq(erro, nil); t.eq(revisao, 1); t.eq(carregada.ouro, 0); t.eq(#carregada.encontrosPagos, 0)
		carregada.ouro, carregada.encontrosPagos = 23, { "enc-1" }
		local status = persistencia:save(4504, carregada, revisao)
		t.eq(status, "ok"); t.eq(store.dados.user_4504.schemaVersion, 6)
		local relida = persistencia:load(4504)
		t.eq(relida.ouro, 23); t.eq(relida.encontrosPagos[1], "enc-1")
	end,
	["schema v3 migra inventario de loja vazio sem apagar dados pessoais"] = function(t)
		local store = storeFake()
		local antiga = perfil("Legada")
		antiga.ouro, antiga.encontrosPagos = 27, { "enc-legado" }
		store.dados.user_4516 = { schemaVersion = 3, revision = 2, savedAt = 1, perfil = antiga }
		local persistencia = Persistencia.new({ store = store })
		local carregada, revisao, erro = persistencia:load(4516)
		t.eq(erro, nil); t.eq(revisao, 2); t.eq(carregada.ouro, 27)
		t.eq(#carregada.inventarioLoja, 0); t.eq(#carregada.itensVendidos, 0)
		local status, nova = persistencia:save(4516, carregada, revisao)
		t.eq(status, "ok"); t.eq(nova, 3); t.eq(store.dados.user_4516.schemaVersion, 6)
	end,
	["migração v4 para v5 cria estado de missões sem apagar ficha"] = function(t)
		local store = storeFake()
		local antiga = perfil("Viajante")
		antiga.ouro, antiga.inventarioLoja = 44, {}
		store.dados.user_4517 = { schemaVersion = 4, revision = 7, savedAt = 1, perfil = antiga }
		local persistencia = Persistencia.new({ store = store })
		local carregada, revisao, erro = persistencia:load(4517)
		t.eq(erro, nil); t.eq(revisao, 7); t.eq(carregada.ouro, 44)
		t.eq(carregada.missoes and next(carregada.missoes), nil)
		t.ok(carregada.missoes and next(carregada.missoes) == nil)
		local status = persistencia:save(4517, carregada, revisao)
		t.eq(status, "ok"); t.eq(store.dados.user_4517.schemaVersion, 6)
	end,
}
