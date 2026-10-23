-- SOMENTE STUDIO: serviço real com dependências/mesa isoladas; não altera a campanha aberta.
local Shared = game:GetService("ReplicatedStorage").Shared
local Fogo = require(Shared.Regras.Fogo)
local Servico = require(script.Parent.Parent.HabilidadeService)
local Catalogo = require(Shared.Livro.Catalogo)
local Execucao = require(Shared.Regras.Execucao)

local function ficha(id, x, z)
	return { id = id, name = id, x = x, z = z, kind = "jogador", ownerUserId = 123,
		pv = 50, pvMax = 100, mana = 100, manaMax = 100, version = 1, conditions = {},
		sheet = { ca = 10, forca = 0, agilidade = 0, vigor = 0 },
		ficha2 = { construction = { unlockedRankIds = {}, purchasedIds = {}, inventory = {} },
			calculated = { highestRankBonus = 1, attributes = { forca = 2, agilidade = 4, vigor = 3 }, maxima = { pt = 10 } },
			session = { current = { pt = 10 } } },
	}
end
local function contexto(mecanicas, rolagem)
	local a, b, c = ficha("a", 5, 5), ficha("b", 8, 5), ficha("c", 5, 8)
	local tokens = { a = a, b = b, c = c }
	local handlers, logs, movimentos, recibos = {}, {}, {}, {}
	local combat = { active = true, round = 1, turn = 1, current = "a" }
	local terrain, player = {}, { UserId = 123 }
	local registro = table.clone(Execucao)
	registro.MECANICAS = mecanicas
	registro.habilidadesDe = function() local ids = {}; for id in mecanicas do table.insert(ids, id) end; return ids end
	registro.bc = function() return 3 end
	registro.bonusDeRankDa = function() return 1 end
	registro.bandeiras = function() return {} end
	local api
	api = Servico.start({
		execucao = registro, handlers = handlers, tokens = tokens, tokenOrder = { "a", "b", "c" }, combat = combat,
		catalogo = Catalogo, terrain = terrain, cellKey = function(x, z) return x .. ":" .. z end,
		random = { NextInteger = function(_, lo, hi) return math.clamp(rolagem or 10, lo, hi) end },
		remote = { FireClient = function(_, p, kind, data) table.insert(recibos, { player = p, kind = kind, data = data }) end },
		canSee = function(_, token) return not token.hidden end, currentTurnId = function() return combat.current end,
		logAboutToken = function(token, texto) table.insert(logs, { id = token.id, text = texto }) end,
		moverFicha = function(token, x, z)
			local deX, deZ = token.x, token.z
			token.x, token.z = x, z; token.version += 1
			table.insert(movimentos, token.id); api.moveu(token, deX, deZ)
		end,
		removerFicha = function() error("Não deveria remover ficha") end, reviverBoneco = function() end,
	})
	local function usar(id, alvoId, extra, master)
		local payload = { tokenId = combat.current, habilidadeId = id, alvoId = alvoId }
		for k, v in extra or {} do payload[k] = v end
		return handlers.usarHabilidade(player, payload, master == true)
	end
	local function vez(id)
		local anterior = combat.current
		combat.current = id; combat.turn += 1
		api.aoTrocarVez(anterior, id)
	end
	return { a = a, b = b, c = c, tokens = tokens, handlers = handlers, api = api, usar = usar, vez = vez,
		combat = combat, terrain = terrain, logs = logs, movimentos = movimentos, recibos = recibos, player = player }
end

local F = "ability/fogo/Principiante/fagulha"
local B = "ability/fogo/Principiante/brasa"
local O = "ability/fogo/Principiante/bola-de-fogo"
local V = "ability/vento/Principiante/empurrao"
local M = "ability/fogo/Principiante/muro-de-chamas"
local function ctx()
 return contexto({ [F]=Execucao.MECANICAS[F], [B]=Execucao.MECANICAS[B], [O]=Execucao.MECANICAS[O], [V]=Execucao.MECANICAS[V], [M]=Execucao.MECANICAS[M] }, 4)
end
local function tem(token,id)
 for _, c in token.conditions do if c.id==id then return true end end
 return false
end
return {
 ["G5 servidor: Fagulha cobra e não fere quem já ocupa a casa"] = function(t)
  local x=ctx(); t.eq(x.usar(F,nil,{x=8,z=5}),nil)
  t.eq(x.a.mana,99); t.eq(x.api.estado().acoes.usadas,1); t.eq(x.b.pv,50)
  local z=x.api.estado().muros[1]; t.eq(#z.casas,1); t.eq(z.casas[1][1],8); t.eq(z.rodadaFim,3)
  t.ok(not x.api.bloqueiaMovimento(8,5)); t.ok(not tem(x.b,"em-chamas"))
 end,
 ["G5 servidor: tipos, limite, alcance, parede e visão recusam sem custo"] = function(t)
  for _, dest in { {x="8",z=5}, {x=0,z=5}, {x=8.5,z=5}, {x=12,z=5}, {x=6,z=5}, {x=8,z=5} } do
   local x=ctx(); x.terrain["6:5"]="parede"
   t.ok(x.usar(F,nil,dest)~=nil); t.eq(x.a.mana,100); t.eq(x.api.estado().acoes.usadas,0); t.eq(#x.api.estado().muros,0)
  end
 end,
 ["G5 servidor: sem mana e fora da vez não cria perigo"] = function(t)
  local x=ctx(); x.a.mana=0; t.ok(x.usar(F,nil,{x=8,z=5})~=nil); t.eq(#x.api.estado().muros,0)
  x.a.mana=100; x.combat.current="b"
  t.ok(x.handlers.usarHabilidade(x.player,{tokenId="a",habilidadeId=F,x=8,z=5},false)~=nil)
  t.eq(x.a.mana,100); t.eq(#x.api.estado().muros,0)
 end,
 ["G5 servidor: atravessa, permanece e reentra sem dano por casa duplicado"] = function(t)
  local x=ctx(); t.eq(x.usar(F,nil,{x=9,z=5}),nil)
  x.b.x=10; x.api.moveu(x.b,8,5); t.eq(x.b.pv,46); t.ok(not tem(x.b,"em-chamas"))
  x.api.moveu(x.b,10,5); t.eq(x.b.pv,46)
  x.b.x=8; x.api.moveu(x.b,10,5); t.eq(x.b.pv,42)
 end,
 ["G5 servidor: aliado e criador também sofrem ao entrar"] = function(t)
  local x=ctx(); t.eq(x.usar(F,nil,{x=6,z=5}),nil)
  x.a.x=6; x.api.moveu(x.a,5,5); t.eq(x.a.pv,46)
 end,
 ["G5 servidor: empurrão de Vento atravessa Fagulha uma vez"] = function(t)
  local x=ctx(); t.eq(x.usar(F,nil,{x=9,z=5}),nil)
  t.eq(x.usar(V,"b"),nil); t.eq(x.b.x,12); t.eq(x.b.pv,46); t.ok(not tem(x.b,"em-chamas"))
  t.eq(x.a.mana,98); t.eq(x.api.estado().acoes.usadas,3)
 end,
 ["G5 servidor: perigo expira na rodada limite e ao encerrar"] = function(t)
  local x=ctx(); t.eq(x.usar(F,nil,{x=9,z=5}),nil)
  x.combat.round=2; x.vez("b"); t.eq(#x.api.estado().muros,1)
  x.combat.round=3; x.vez("c"); t.eq(#x.api.estado().muros,0)
  x.b.x=10; x.api.moveu(x.b,8,5); t.eq(x.b.pv,50)
  x.vez("a"); t.eq(x.usar(F,nil,{x=9,z=5}),nil); x.api.combateEncerrado(); t.eq(#x.api.estado().muros,0)
 end,
 ["G5 servidor: uma zona não mascara outra e cada zona cobra uma vez"] = function(t)
  local x=ctx(); t.eq(x.usar(F,nil,{x=9,z=5}),nil); t.eq(x.usar(F,nil,{x=10,z=5}),nil)
  x.b.x=11; x.api.moveu(x.b,8,5); t.eq(x.b.pv,42)
  local y=ctx(); t.eq(y.usar(F,nil,{x=9,z=5}),nil); t.eq(y.usar(F,nil,{x=9,z=5}),nil)
  y.b.x=10; y.api.moveu(y.b,8,5); t.eq(y.b.pv,42)
 end,
 ["G5 servidor: Bola e Brasa completam 3 Ações com bônus real e limite"] = function(t)
  local x=ctx(); x.b.sheet.ca=7; t.eq(x.usar(O,"b"),nil); t.eq(x.b.pv,43); t.ok(tem(x.b,"em-chamas"))
  t.eq(x.usar(B,"b"),nil); t.eq(x.b.pv,32); t.eq(x.a.mana,99); t.eq(x.api.estado().acoes.usadas,3)
  t.ok(x.usar(B,"b")~=nil); t.eq(x.b.pv,32)
 end,
 ["G5 servidor: Fagulha não mascara Muro e várias casas do muro cobram uma vez"] = function(t)
  local x=ctx(); t.eq(x.usar(F,nil,{x=9,z=5}),nil); t.eq(x.usar(M,nil,{x=11,z=5}),nil)
  x.b.x=10; x.api.moveu(x.b,8,5); t.eq(x.b.pv,34); t.ok(tem(x.b,"em-chamas"))
 end,
 ["G5 servidor: bônus não é aceito do payload"] = function(t)
  local x=ctx(); x.b.sheet.ca=7; t.eq(x.usar(B,"b",{condicoes={["em-chamas"]=1},bonus=100,dano=999}),nil); t.eq(x.b.pv,43)
  t.ok(x.usar(B,"b")~=nil); t.eq(x.b.pv,43)
 end,
}
