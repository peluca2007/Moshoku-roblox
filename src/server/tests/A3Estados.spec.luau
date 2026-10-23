local E = require(game:GetService("ReplicatedStorage").Shared.Regras.EstadosDeCombate)
return {
 ["estados: termina no fim da próxima vez, não na aplicação"] = function(t)
  local s = E.novo(); E.definir(s, "a", "imovel", true, "b", { de = "alvo" }, 1)
  E.avancar(s, "a", "b", 1); t.eq(E.valor(s, "a", "imovel"), true)
  E.avancar(s, "b", "a", 2); t.eq(E.valor(s, "a", "imovel"), true)
  E.avancar(s, "a", "b", 2); t.eq(E.valor(s, "a", "imovel"), nil)
 end,
 ["estados: duas vezes com única ficha"] = function(t)
  local s = E.novo(); E.definir(s, "a", "odio", true, "b", { turnos = 2 }, 1)
  E.avancar(s, "a", "a", 2); E.avancar(s, "a", "a", 3)
  t.eq(E.valor(s, "a", "odio"), true); E.avancar(s, "a", "a", 4); t.eq(E.valor(s, "a", "odio"), nil)
 end,
 ["estados: início do conjurador e expiração em rodada"] = function(t)
  local s = E.novo(); E.definir(s, "a", "cobertura", 5, "b", { de = "conjurador", inicio = true }, 1)
  E.definir(s, "a", "antidoto", true, "b", { rodadas = 2 }, 1)
  E.avancar(s, "b", "a", 2); t.eq(E.valor(s, "a", "cobertura"), 5)
  E.avancar(s, "a", "b", 3); t.eq(E.valor(s, "a", "cobertura"), nil); t.eq(E.valor(s, "a", "antidoto"), nil)
 end,
 ["estados: fontes não removem proteção alheia nem somam cobertura"] = function(t)
  local s = E.novo(); E.definir(s, "a", "cobertura", 5, "b", nil, 1); E.definir(s, "a", "cobertura", 3, "c", nil, 1)
  t.eq(E.valor(s, "a", "cobertura"), 5); E.remover(s, "a", "cobertura", "b"); t.eq(E.valor(s, "a", "cobertura"), 3)
 end,
}
