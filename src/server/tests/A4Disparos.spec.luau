local Shared = game:GetService("ReplicatedStorage").Shared
local Estado = require(Shared.Regras.EstadoHabilidades)
local Arma = require(Shared.Regras.Arma)
local Habilidades = require(Shared.Regras.Habilidades)
local Regras = require(Shared.Livro.Regras)
local Execucao = require(Shared.Regras.Execucao)

local function rng(valores)
	local i = 0
	return { NextInteger = function(_, minimo, maximo)
		i += 1
		local v = valores[i]
		assert(v and v >= minimo and v <= maximo, "rolagem inesperada " .. i)
		return v
	end }
end
local function conj()
	return { bc = 3, pv = 20, pvMax = 20, condicoes = {}, bonusDeRank = 1, atributos = { forca = 3, agilidade = 5, vigor = 2 }, arma = { dado = "d8", bonus = 4 } }
end
local function alvo()
	return { id = "alvo", ca = 10, condicoes = {}, resistencia = function() return 0 end }
end
local function resolve(mec, c, a, dados)
	return Habilidades.resolver(rng(dados), mec, c or conj(), { a or alvo() }, {})[1]
end
local m = { tipo="ataque", arma=true, partes={{arma=true,bc=true}}, segundoDisparo={{arma=true,degrau=-1}} }
return {
 ["recibo duplo: dano individual soma o total"] = function(t)
  local r=resolve(m,nil,nil,{15,15,4,6})
  t.eq(r.danosDisparos[1],10);t.eq(r.danosDisparos[2],4);t.eq(r.dano.total,14)
 end,
 ["recibo duplo: primeiro erro não herda dano do segundo"] = function(t)
  local r=resolve(m,nil,nil,{1,15,4})
  t.eq(r.danosDisparos[1],0);t.eq(r.danosDisparos[2],4)
 end,
 ["recibo duplo: segundo erro não herda dano do primeiro"] = function(t)
  local r=resolve(m,nil,nil,{15,1,6})
  t.eq(r.danosDisparos[1],10);t.eq(r.danosDisparos[2],0);t.eq(r.dano.total,10)
 end,
}
