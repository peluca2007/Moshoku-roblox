local Shared = game:GetService("ReplicatedStorage").Shared
local V = require(Shared.Regras.RunViagem)
local Run = require(Shared.Regras.Run)
local Save = require(Shared.Regras.RunSave)
local Sessao = require(Shared.Regras.RunSessao)
local Eventos = require(Shared.Mundo.ViagemEventosV1)
local function rng(lista)
 local i = 0
 return { NextInteger = function(_, lo, hi)
  i += 1
  local n = lista[i]
  assert(n and n >= lo and n <= hi, "RNG inesperado")
  return n
 end }
end
local opcao = { id = "esconder", texto = "Esconder", teste = { pericia = "Furtividade", cd = 12 },
 sucesso = { dias = -0.25, ouro = 5, flag = "passou-oculto", texto = "Passagem livre." },
 falha = { dias = 0.5, ouro = -2, flag = "foi-visto", texto = "Atraso na trilha." } }
local evento = { id = "teste", opcoes = { opcao, { id = "esperar", dias = 0.25 } } }
local function nova()
 return Run.nova({ jogadores = { 11, 22, 33 }, objetivo = { id = "selo", prazoDias = 1 } })
end
local function ficha(bonus)
 return { calculated = { attributes = { vigor = 3 }, skills = { { skillId = "skill/furtividade", bonus = bonus } } } }
end
local function sessao()
 local dados, falhar = {}, false
 local s = Sessao.new({ rng = rng({ 18, 7 }), eventos = { evento }, fichaDe = function(id) return ficha(if id == 33 then 99 else 5) end,
  guardar = function(k, v) if falhar then error("offline") end; dados[k] = v end,
  carregar = function(k) return dados[k] end })
 s.run, s.grupoId, s.planos, s.evento = nova(), "f8", { [11] = { modo = "zero", defeitos = { "desastrado" } }, [22] = { modo = "zero" }, [33] = { modo = "zero" } }, evento
 s.run.jogadores[22].caido = true
 s.run.jogadores[33].presente = false
 return s, dados, function(v) falhar = v end
end
return {
 ["d20 injetado, CD empatada passa e desvantagem escolhe menor"] = function(t)
  local r = V.resolverTeste(opcao, rng({ 9 }), 3, false)
  t.eq(r.total, 12); t.eq(r.sucesso, true); t.eq(#r.dados, 1)
  local f = V.resolverTeste(opcao, rng({ 20, 2 }), 3, true)
  t.eq(f.total, 5); t.eq(f.sucesso, false); t.eq(f.natural, 2); t.eq(#f.dados, 2)
  t.eq(f.desfecho.flag, "foi-visto")
  t.eq(V.resolverTeste(opcao, rng({ 1 }), 11, false).sucesso, true)
 end,
 ["bonus da ficha usa calculos canonicos de pericia e atributo"] = function(t)
  t.eq(V.bonusDaFicha(ficha(6), "Furtividade"), 6)
  t.eq(V.bonusDaFicha(ficha(6), "Vigor"), 3)
  t.eq(V.bonusDaFicha(nil, "Furtividade"), nil)
  t.eq(V.bonusDaFicha(ficha(6), "inventada"), nil)
 end,
 ["consequencias imutaveis, limites, expiracao e save aditivo"] = function(t)
  local run = nova()
  local r = V.resolverTeste(opcao, rng({ 15 }), 0, false)
  local n = V.aplicarOpcao(run, evento, "esconder", r)
  t.eq(n.dia, 0); t.eq(n.ouroViagem, 5); t.eq(n.flags["passou-oculto"], true)
  t.eq(run.ouroViagem, nil); t.eq(run.ultimoEvento, nil)
  n = Run.gastarDias(n, 1)
  local f = V.resolverTeste(opcao, rng({ 1 }), 0, false)
  local m, expirou = V.aplicarOpcao(n, evento, "esconder", f)
  t.eq(m.dia, 1.5); t.eq(m.ouroViagem, 3); t.eq(expirou, false) -- expirou no salto anterior até o limite
  t.eq(n.objetivo.status, "expirado"); t.eq(m.objetivo.status, "expirado")
  local atalho = V.aplicarOpcao(m, evento, "esconder", r)
  t.eq(atalho.objetivo.status, "expirado")
  local carregada = Save.restaurar(Save.serializar(m))
  t.eq(carregada.ultimoEvento.total, 1); t.eq(carregada.ultimoEvento.texto, "Atraso na trilha.")
  t.eq(carregada.ouroViagem, 3); t.eq(carregada.flags["foi-visto"], true)
  local antiga = Save.restaurar(Save.serializar(run))
  t.eq(antiga.ouroViagem, nil); t.eq(antiga.ultimoEvento, nil)
  t.eq(V.aplicarOpcao(run, evento, "esconder"), nil)
 end,
 ["evento sem teste nao consome rng e preserva contrato legado"] = function(t)
  local o = evento.opcoes[2]
  local r = V.resolverTeste(o, rng({}))
  local n = V.aplicarOpcao(nova(), evento, o.id, r)
  t.eq(n.dia, 0.25); t.eq(n.flags["evento/teste/esperar"], true)
  t.eq(n.ultimoEvento.pericia, nil)
 end,
 ["sessao exclui ausente e caido e aplica defeito no executor"] = function(t)
  local s = sessao()
  local ok, r = s:votar(11, "esconder")
  t.eq(ok, true); t.eq(r.ultimoEvento.userId, 11); t.eq(r.ultimoEvento.total, 12)
  t.eq(r.ultimoEvento.ajuste, "desvantagem"); t.eq(s:visao(11).ouroViagem, 5)
  local restored = Sessao.new(s.deps)
  t.eq(restored:retomar("f8"), true)
  t.eq(restored:visao(11).ultimoEvento.total, 12)
  t.eq(restored.evento, nil)
 end,
 ["falha de save preserva votos e rolagem sem reaplicar ou rerrolar"] = function(t)
  local s, _, falhar = sessao()
  falhar(true)
  t.eq(s:votar(11, "esconder"), false)
  t.eq(s.run.ouroViagem, nil); t.eq(s.evento.id, "teste"); t.eq(s.votos[11], "esconder")
  falhar(false)
  t.eq(s:votar(11, "esconder"), true)
  t.eq(s.run.ouroViagem, 5)
 end,
 ["maior bonus apto testa e empate usa dado com ordem estavel"] = function(t)
  local s = sessao()
  s.run.jogadores[22].caido = false
  s.deps.fichaDe = function(id) return ficha(if id == 22 then 8 else 5) end
  s.deps.rng = rng({ 4 })
  s:votar(11, "esconder")
  local ok, r = s:votar(22, "esconder")
  t.eq(ok, true); t.eq(r.ultimoEvento.userId, 22); t.eq(r.ultimoEvento.total, 12)
  local empatada = sessao()
  empatada.run.jogadores[22].caido = false
  empatada.deps.fichaDe = function() return ficha(5) end
  empatada.deps.rng = rng({ 2, 7 })
  empatada:votar(11, "esconder")
  local certo, rr = empatada:votar(22, "esconder")
  t.eq(certo, true); t.eq(rr.ultimoEvento.userId, 22); t.eq(rr.ultimoEvento.sucesso, true)

 end,
 ["compras exigem saldo e perda nao cria divida"] = function(t)
  local compra = { id = "comprar", sucesso = { ouro = -2 } }
  local e = { id = "mercado", opcoes = { compra } }
  t.eq(V.podePagar(nova(), compra), false)
  t.eq(V.aplicarOpcao(nova(), e, "comprar"), nil)
  local run = nova(); run.ouroViagem = 3
  local n = V.aplicarOpcao(run, e, "comprar")
  t.eq(n.ouroViagem, 1); t.eq(n.ultimoEvento.ouro, -2)
  local f = V.resolverTeste(opcao, rng({ 1 }), 0, false)
  n = V.aplicarOpcao(n, evento, "esconder", f)
  t.eq(n.ouroViagem, 0); t.eq(n.ultimoEvento.ouro, -1)
 end,
 ["sem ficha recusa sem aplicar efeitos; opcao segura continua funcionando"] = function(t)
  local s = sessao()
  s.deps.fichaDe = nil
  t.eq(s:votar(11, "esconder"), false)
  t.eq(s.run.dia, 0); t.eq(s.run.ultimoEvento, nil)
  t.eq(s:votar(11, "esperar"), true)
  t.eq(s.run.dia, 0.25)
 end,
 ["empate na votacao preservado ao repetir save sem novos dados"] = function(t)
  local s, _, falhar = sessao()
  s.run.jogadores[22].caido = false
  s.deps.fichaDe = function(id) return ficha(if id == 22 then 8 else 5) end
  s.deps.rng = rng({ 1, 4 }) -- d2 seleciona esconder, d20 + 8 = 12
  falhar(true)
  s:votar(11, "esconder")
  t.eq(s:votar(22, "esperar"), false)
  falhar(false)
  local ok, r = s:votar(22, "esperar")
  t.eq(ok, true); t.eq(r.dado, 1); t.eq(s.run.ouroViagem, 5)
 end,
 ["catalogo tem dez novos eventos com testes e regioes alcancaveis"] = function(t)
  t.eq(#Eventos, 14)
  local regioes, testes = {}, 0
  for i, e in Eventos do
   if i > 4 then
    t.ok(#e.opcoes >= 2 and #e.opcoes <= 3)
    for _, regiao in e.regioes or { "estrada" } do regioes[regiao] = true end
    local tem = false
    for _, o in e.opcoes do
     if o.teste then
      tem = true
      t.ok(o.sucesso ~= nil and o.falha ~= nil)
      t.ok(V.resolverTeste(o, { NextInteger = function() return 12 end }, 0, false) ~= nil)
     end
    end
    if tem then testes += 1 end
   end
  end
  t.ok(testes >= 5)
  for _, r in { "vila", "floresta-sombria", "ruinas-do-vale", "estrada" } do t.ok(regioes[r], r) end
 end,
}
