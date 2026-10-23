-- SOMENTE STUDIO: árvores de utilidade (A20) no serviço real, mesa isolada.
local Shared = game:GetService("ReplicatedStorage").Shared
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(Shared.Livro.Catalogo)

local FURT, BARDO, NAV = "furtividade-e-armadilhas", "bardo-e-interacao", "navegacao-e-lideranca"
local MARCHA = "talent/" .. BARDO .. "/Principiante/cantiga-de-marcha"
local ADAGA = { name = "Adaga / Punhal", type = "arma", equipped = true, baseDie = "d4" }
local LANCA = { name = "Alabarda / Lança", type = "arma", equipped = true, baseDie = "d10" }

local function jogador(id, x, z, arvore, compras, arma)
	return { id = id, name = id, x = x, z = z, kind = "jogador", ownerUserId = 123,
		pv = 30, pvMax = 30, mana = 8, manaMax = 8, version = 1, conditions = {},
		sheet = { ca = 12, forca = 0, agilidade = 0, vigor = 0 },
		ficha2 = { construction = { unlockedRankIds = if arvore then { "rank/" .. arvore .. "/Principiante" } else {}, purchasedIds = compras or {}, inventory = { arma or ADAGA } },
			calculated = { highestRankBonus = 1, attributes = { forca = 0, agilidade = 3, vigor = 1, intelecto = 2, espirito = 2 }, maxima = { pt = 0, pp = 2 }, movementMeters = 9 },
			session = { current = { pt = 0, pp = 2 } } },
	}
end
local function inimigo(id, x, z)
	return { id = id, name = id, x = x, z = z, kind = "npc", pv = 40, pvMax = 40, mana = 0, manaMax = 0, version = 1,
		conditions = {}, ia = true,
		criatura = { ca = 10, bonusResistencia = 0, bonusAtaque = 3, patamar = 1, danoPorTurno = 6, deslocamentoMetros = 9,
			categoria = "humanoide", resistencias = {}, imunidades = {} } }
end
local function contexto(lista, d20, dados, terreno)
	local tokens, ordem = {}, {}
	for _, t in lista do tokens[t.id] = t; table.insert(ordem, t.id) end
	local handlers, logs = {}, {}
	local combat = { active = true, round = 1, turn = 1, current = ordem[1], order = ordem, turnIndex = 1 }
	local fila, filaDados = table.clone(d20 or {}), table.clone(dados or {})
	local api = Servico.start({
		handlers = handlers, tokens = tokens, tokenOrder = ordem, combat = combat,
		catalogo = Catalogo, terrain = terreno or {}, cellKey = function(x, z) return x .. ":" .. z end,
		random = { NextInteger = function(_, lo, hi)
			if hi == 20 then return math.clamp(table.remove(fila, 1) or 10, lo, hi) end
			return math.clamp(table.remove(filaDados, 1) or 3, lo, hi)
		end },
		remote = { FireClient = function() end },
		canSee = function() return true end, currentTurnId = function() return combat.current end,
		logAboutToken = function(_, texto) table.insert(logs, texto) end,
		moverFicha = function(token, x, z) token.x, token.z = x, z end,
		removerFicha = function(id) tokens[id] = nil end, reviverBoneco = function() end,
	})
	local resposta = {}
	api.reacoes.decidir = function(token, _, opcoes)
		for _, o in opcoes do if resposta[o.id] then return o.id end end
		return nil
	end
	local P = { UserId = 123 }
	return { api = api, handlers = handlers, logs = logs, combat = combat, tokens = tokens, responder = function(r) resposta = r end,
		usar = function(id, hab, extra) local p = { tokenId = id, habilidadeId = hab }; for k, v in extra or {} do p[k] = v end; return handlers.usarHabilidade(P, p, false) end,
		vez = function(id) local ant = combat.current; combat.current = id; combat.turn += 1; api.aoTrocarVez(ant, id) end,
		registro = function() return table.concat(logs, "\n") end }
end
local function tem(t, cond) for _, c in t.conditions or {} do if c.id == cond then return true end end return false end

return {
 ["G7 Esquivar sem alvo protege contra dois atacantes diferentes"] = function(t)
  local a,e,f=jogador("a",5,5),inimigo("e",6,5),inimigo("f",5,6)
  local x=contexto({a,e,f},{15,2,15,2})
  t.eq(x.usar("a","mesa/esquivar"),nil)
  x.vez("e");x.api.turnoDoInimigo(e);t.eq(a.pv,30)
  x.vez("f");x.api.turnoDoInimigo(f);t.eq(a.pv,30)
  x.vez("a");t.eq(table.find(x.api.estadosDe(a),"esquiva"),nil)
 end,
 ["G7 furtividade falha cobra uma Ação e não aplica Escondido; sucesso mostra teste"] = function(t)
  local a,e=jogador("a",5,5,FURT),inimigo("e",8,5);e.olharX,e.olharZ=1,0
  local x=contexto({a,e},{1,20})
  t.eq(x.usar("a","mesa/esconder"),nil);t.ok(not tem(a,"escondido"));t.eq(x.api.estado().acoes.usadas,1)
  t.ok(x.registro():find("Falhou: continua visível",1,true))
  t.eq(x.usar("a","mesa/esconder"),nil);t.ok(tem(a,"escondido"));t.eq(x.api.estado().acoes.usadas,2)
 end,
 ["G7 furtividade usa bônus exportado sem duplicar rank e CD dos observadores próximos"] = function(t)
  local a,e=jogador("a",5,5,FURT),inimigo("e",8,5)
  a.ficha2.calculated.skills={{skillId="skill/furtividade",bonus=8}};e.criatura.bonusResistencia=6
  local x=contexto({a,e});local r=x.api.testeFurtivo(a);t.eq(r.bonus,8);t.eq(r.cd,16)
  e.x=15;t.eq(x.api.testeFurtivo(a).cd,10)
 end,
 ["G7 Marcha combina com Inspiração e informa beneficiários sem acumular ou desperdiçar"] = function(t)
  local b=jogador("b",5,5,BARDO,{"ability/"..BARDO.."/Principiante/inspiracao",MARCHA})
  local a,e=jogador("a",5,6),inimigo("e",8,5);local x=contexto({b,a,e})
  t.eq(x.usar("b","mesa/marcha"),nil)
  local v=function() return true end
  local s=x.api.suporteDe(b,v);t.eq(s.cancao,"marcha");t.eq(#s.beneficiados,2);t.eq(s.marcha,1)
  t.ok(x.usar("b","mesa/marcha")~=nil);t.eq(x.api.estado().acoes.usadas,1)
  t.eq(x.usar("b","ability/"..BARDO.."/Principiante/inspiracao",{alvoId="a"}),nil)
  s=x.api.suporteDe(a,v);t.eq(s.marcha,1);t.eq(s.inspiracao,"1d6");t.eq(s.inspiracaoFonte,"b")
  t.eq(x.api.suporteDe(b,v).inspiracoesUsadas,1)
  t.ok(x.usar("b","ability/"..BARDO.."/Principiante/inspiracao",{alvoId="a"})~=nil)
  t.eq(x.api.suporteDe(b,v).inspiracoesUsadas,1);t.eq(x.api.estado().acoes.usadas,2)
  t.eq(x.usar("b","mesa/dissonancia"),nil);t.eq(x.api.suporteDe(a,v).marcha,0)
  t.eq(x.api.suporteDe(a,v).inspiracao,"1d6");t.eq(x.api.suporteDe(b,v).cancao,"dissonancia")
 end,
 ["G7 apoio não revela fontes ocultas e a canção termina ao cair a zero"] = function(t)
  local b,a=jogador("b",5,5,BARDO,{MARCHA}),jogador("a",5,6);local x=contexto({b,a})
  t.eq(x.usar("b","mesa/marcha"),nil)
  local s=x.api.suporteDe(a,function(o) return o~=b end);t.eq(#s.fontesMarcha,0);t.eq(s.marcha,1)
  x.api.adminPV(b,0);t.eq(x.api.suporteDe(a,function() return true end).marcha,0)
  x.api.adminPV(b,30);t.eq(x.api.suporteDe(b,function() return true end).cancao,nil)
 end,
 ["G7 ADM recupera zero preservando condições não relacionadas e limpa efeitos reais"] = function(t)
  local a=jogador("a",5,5,FURT);local x=contexto({a})
  x.api.adminPV(a,0);t.ok(tem(a,"inconsciente"));t.ok(tem(a,"caido"))
  table.insert(a.conditions,{id="molhado",stacks=1});x.api.adminPV(a,30)
  t.ok(not tem(a,"inconsciente"));t.ok(not tem(a,"caido"));t.ok(tem(a,"molhado"))
  t.eq(x.usar("a","mesa/esquivar"),nil);t.ok(table.find(x.api.estadosDe(a),"esquiva"))
  x.api.adminLimpar(a);t.eq(#a.conditions,0);t.eq(table.find(x.api.estadosDe(a),"esquiva"),nil)
  t.eq(x.api.adminAcoes(),nil);t.eq(x.api.estado().acoes.usadas,0)
 end,
}
