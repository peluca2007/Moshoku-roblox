local Shared = game:GetService("ReplicatedStorage").Shared
local Conta = require(Shared.Regras.RunConta)
local Beneficios = require(Shared.Regras.RunBeneficiosConta)
local Transacoes = require(Shared.Regras.ContaTransacoes)
local Sessao = require(Shared.Regras.RunSessao)
local Racas = require(Shared.Livro.Dados.Racas)

return {
 ["catálogo classifica todas as compras e explica efeito"] = function(t)
  local tipos = { treinador = 0, raca = 0, item = 0, cosmetico = 0 }
  for id, item in Conta.CATALOGO do
   t.ok(tipos[item.tipo] ~= nil); tipos[item.tipo] += 1
   t.ok(#item.titulo > 0 and #item.efeito > 0)
   t.eq(string.match(id, "^([^:]+):"), item.tipo)
  end
  t.eq(tipos.treinador, 5); t.eq(tipos.raca, 1); t.eq(tipos.item, 1); t.eq(tipos.cosmetico, 1)
 end,
 ["raças base e compra rara seguem tiers do livro sem liberar lendária mítica"] = function(t)
  local conta = Conta.nova()
  local base = Beneficios.racasLiberadas(conta)
  conta.desbloqueios["raca:rara"] = true
  local raras = Conta.racasLiberadas(conta)
  for _, raca in Racas do
   local tier = raca.data.tier
   t.eq(base[raca.id] == true, tier == "comum" or tier == "incomum")
   t.eq(raras[raca.id] == true, tier == "comum" or tier == "incomum" or tier == "rara")
  end
  conta.desbloqueios["raca:dragao"] = true
  t.eq(Conta.racasLiberadas(conta)["race/dragao"], nil)
 end,
 ["kit extra exato no livro só dentro da run e só com compra"] = function(t)
  local conta = Conta.nova()
  t.eq(#Beneficios.itensIniciais(conta, "u1-123"), 0)
  conta.desbloqueios["item:pocao-menor"] = true
  t.eq(#Beneficios.itensIniciais(conta, nil), 0)
  local registros = Beneficios.itensIniciais(conta, "u1-123")
  t.eq(#registros, 1); t.eq(registros[1].itemId, "item/pocao_menor_cura")
  local item = Beneficios.materializar(registros[1])
  t.eq(item.name, "Poção Menor de Cura"); t.eq(item.type, "geral"); t.eq(item.equipped, false)
  t.ok(string.find(item.description, "1d8 + 2", 1, true))
 end,
 ["recalcular reconectar e baixar item não renovam kit; outra run ganha um novo"] = function(t)
  local conta = Conta.nova(); conta.desbloqueios["item:pocao-menor"] = true
  local inicial = { { sourceLocalId = "kit-1", name = "Arma" } }
  local inventario, registros = Beneficios.prepararInventario(inicial, {}, {}, conta, "u1-123")
  t.eq(#inicial, 1); t.eq(#inventario, 2); t.eq(#registros, 1)
  local repetido, recibos = Beneficios.prepararInventario(inicial, registros, {}, conta, "u1-123")
  t.eq(#repetido, 2); t.eq(#recibos, 1)
  local baixas = { registros[1].sourceLocalId }
  local consumido, guardados = Beneficios.prepararInventario(inicial, registros, baixas, conta, "u1-123")
  t.eq(#consumido, 1); t.eq(#guardados, 1)
  local novo, novos = Beneficios.prepararInventario(inicial, guardados, baixas, conta, "u1-456")
  t.eq(#novo, 2); t.eq(#novos, 2)
  t.eq(#registros, 1)
 end,
 ["cosmético registrado não libera raça treinador raro ou item"] = function(t)
  local conta = Conta.nova(); conta.moeda = 40
  conta = assert(Conta.comprar(conta, "cosmetico:capa-vermelha"))
  t.eq(conta.desbloqueios["cosmetico:capa-vermelha"], true)
  t.eq(Conta.racasLiberadas(conta)["race/superd"], nil)
  t.eq(Conta.treinadoresLiberados(conta).agua, nil)
  t.eq(#Beneficios.itensIniciais(conta, "run"), 0)
 end,
 ["remote com store falso compra libera benefícios somente da identidade e replay único"] = function(t)
  local c = Conta.nova(); c.moeda = 1000
  local dados = { ["conta/7"] = c }
  local api = Transacoes.start({ store = { atualizar = function(k, f)
   local nova = f(dados[k]); if nova then dados[k] = nova end; return dados[k]
  end } })
  local p, agora = { UserId = 7 }, 0
  local handler = Transacoes.criarHandler(api, { autenticado = function(v) return v == p end,
   entreRuns = function() return true end, relogio = function() agora += 1; return agora end })
  for _, id in { "raca:rara", "item:pocao-menor", "treinador:agua", "cosmetico:capa-vermelha" } do
   local pedido = { acao = "comprar", itemId = id, requestId = string.gsub(id, ":", "-") }
   t.eq(handler(p, pedido).ok, true); t.eq(handler(p, pedido).ok, true)
  end
  t.eq(api.obter(7).moeda, 500)
  t.eq(Conta.racasLiberadas(api.obter(7))["race/superd"], true)
  t.eq(#Beneficios.itensIniciais(api.obter(7), "run"), 1)
  t.eq(Conta.treinadoresLiberados(api.obter(7)).agua, true)
  t.eq(Conta.racasLiberadas(api.obter(8))["race/superd"], nil)
  t.eq(#Beneficios.itensIniciais(api.obter(8), "run"), 0)
 end,
 ["contexto de kit só existe para integrante da run ativa e sobrevive ao save"] = function(t)
  local dados
  local deps = { rng = { NextInteger = function(_, lo) return lo end },
   guardar = function(_, v) dados = v end, carregar = function() return dados end }
  local sessao = Sessao.new(deps)
  t.eq(sessao:iniciar("f7", { { userId = 71 } }), true)
  local id = Sessao.contextoCriacao(71)
  t.ok(type(id) == "string"); t.eq(Sessao.contextoCriacao(72), nil)
  local outra = Sessao.new(deps); t.eq(outra:retomar("f7"), true)
  t.eq(Sessao.contextoCriacao(71), id)
  outra.run.fim = { status = "derrota" }
  t.eq(Sessao.contextoCriacao(71), nil)
 end,
}
