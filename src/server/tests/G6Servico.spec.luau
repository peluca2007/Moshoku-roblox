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
	local handlers, logs, movimentos, recibos, trajetos = {}, {}, {}, {}, {}
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
			table.insert(movimentos, token.id);table.insert(trajetos,{deX,deZ,x,z}); api.moveu(token, deX, deZ)
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
		combat = combat, terrain = terrain, logs = logs, movimentos = movimentos, recibos = recibos, player = player, trajetos = trajetos }
end


local L, E = "mesa/levantar", "mesa/esconder"
local W = "ability/terra/Principiante/muro-de-terra"
local N = "ability/deus-do-norte/Principiante/arremesso-de-espada"
local function tem(token,id) for _, c in token.conditions do if c.id==id then return true end end return false end
local function ctx(d)
 return contexto(Execucao.MECANICAS,d)
end
local function arma(token)
 local i={name="Espada Longa",type="arma",baseDie="d8",equipped=true}
 token.ficha2.construction.inventory={i}; return i
end
return {
 ["G12 muralha moldada cobra uma vez e recusa desenho adulterado sem custo"] = function(t)
  local id="ability/fogo/Principiante/muro-de-chamas"
  local x=ctx();local mana=x.a.mana
  t.eq(x.usar(id,nil,{inicioX=6,inicioZ=5,x=6,z=8}),nil)
  t.eq(x.a.mana,mana-3);t.eq(x.api.estado().acoes.usadas,2)
  local muros=x.api.estado().muros;t.eq(#muros,1);t.eq(#muros[1].casas,4)
  for _,p in {{inicioX=6,inicioZ=5,x=15,z=5},{inicioX=6,inicioZ=5,x=8,z=6},{inicioX=9,inicioZ=5,x=10,z=5}} do
   local y=ctx();local antes=y.a.mana;t.ok(y.usar(id,nil,p)~=nil);t.eq(y.a.mana,antes);t.eq(y.api.estado().acoes.usadas,0)
  end
  local y=ctx();y.terrain["6:6"]="parede";t.ok(y.usar(id,nil,{inicioX=6,inicioZ=5,x=6,z=8})~=nil);t.eq(y.a.mana,100)
 end,
 ["G12 magia nao atravessa canto de pedra e recusa antes de cobrar"] = function(t)
  local x=ctx();x.b.x,x.b.z=8,8;x.terrain["6:5"]="parede"
  t.ok(x.usar("ability/fogo/Principiante/brasa","b")~=nil)
  t.eq(x.b.pv,50);t.eq(x.a.mana,100);t.eq(x.api.estado().acoes.usadas,0)
 end,
 ["G6 IA não corta em linha reta através do muro ao buscar caminho"] = function(t)
  local x=ctx();t.eq(x.usar(W,nil,{x=7,z=5}),nil)
  x.b.kind="npc";x.b.ownerUserId=nil;x.b.ia=true;x.b.x=9
  x.b.criatura={ca=12,bonusAtaque=3,danoPorTurno=4,deslocamentoMetros=9,resistencias={},imunidades={}}
  local deX,deZ=x.b.x,x.b.z;x.vez("b");x.api.turnoDoInimigo(x.b)
  for _,rota in x.trajetos do for _,casa in require(Shared.Regras.Combate).linha(rota[1],rota[2],rota[3],rota[4]) do t.ok(not x.api.bloqueiaMovimento(casa[1],casa[2])) end end
 end,
 ["G6 atravessar cone revela mesmo terminando fora dele"] = function(t)
  local x=ctx(20);x.a.x=5;x.a.z=9;x.b.x=7;x.b.z=5;x.b.ownerUserId=nil;x.b.kind="npc";x.b.olharX=0;x.b.olharZ=1
	  x.a.ficha2.construction.unlockedRankIds={"rank/furtividade-e-armadilhas/Principiante"}
  t.eq(x.usar(E),nil);t.ok(tem(x.a,"escondido"))
  x.a.x=9;x.api.moveu(x.a,5,9);t.ok(not tem(x.a,"escondido"))
 end,
 ["G6 inimigo caído pode levantar na sua vez"] = function(t)
  local x=ctx();x.b.kind="npc";x.b.ia=true;x.b.ownerUserId=nil;x.b.x=6
  x.b.criatura={ca=12,bonusAtaque=3,danoPorTurno=4,deslocamentoMetros=9,resistencias={},imunidades={}}
  x.b.conditions={{id="caido",stacks=1}};x.vez("b")
  t.eq(x.api.turnoDoInimigo(x.b),true);t.ok(not tem(x.b,"caido"))
 end,
 ["G6 Caído ataca, levanta por 1 Ação e usa metade do movimento sem pagar de novo"] = function(t)
  local x=ctx(); x.a.conditions={{id="caido",stacks=1}};x.b.x=6
  t.eq(x.usar("mesa/ataque-basico","b"),nil)
  t.ok(tem(x.a,"caido"));t.eq(x.usar(L),nil);t.ok(not tem(x.a,"caido"))
  t.eq(x.api.estado().acoes.usadas,2); local passos=x.api.estado().acoes.passosLivres;t.ok(passos>0)
  t.eq(x.api.validarMovimento(x.a,5,5-passos,true),nil);t.eq(x.api.estado().acoes.usadas,2);t.eq(x.api.estado().acoes.passosLivres,0)
  x.vez("a");t.eq(x.api.estado().acoes.passosLivres,0)
 end,
 ["G6 Levantar recusa sem Caído, sem Ações, zero PV, agarrado e incapacitado sem cobrar"] = function(t)
  for _, caso in {"normal","semAcoes","zero","agarrado","incapacitado"} do
   local x=ctx();x.a.conditions={{id="caido",stacks=1}}
   if caso=="normal" then x.a.conditions={} elseif caso=="semAcoes" then x.usar("mesa/defender");x.usar("mesa/apontar","b");x.api.validarMovimento(x.a,4,5,true);x.api.validarMovimento(x.a,4,5,true)
   elseif caso=="zero" then x.a.pv=0 else table.insert(x.a.conditions,{id=caso,stacks=1}) end
   local antes=x.api.estado().acoes.usadas
   t.ok(x.usar(L)~=nil,caso);t.eq(x.api.estado().acoes.usadas,antes,caso)
  end
 end,
 ["G6 recuperação de zero remove Inconsciente e Caído, sem retirar outras condições"] = function(t)
  local x=ctx();x.b.x=6;x.b.pv=0;x.b.conditions={{id="caido",stacks=1},{id="inconsciente",stacks=1},{id="molhado",stacks=1}}
  t.eq(x.usar("ability/deus-do-norte/Principiante/primeiros-socorros-de-campo","b"),nil)
  t.ok(x.b.pv>0);t.ok(not tem(x.b,"caido"));t.ok(not tem(x.b,"inconsciente"));t.ok(tem(x.b,"molhado"))
  x.vez("b");t.eq(x.usar("mesa/ataque-basico","a"),nil)
 end,
 ["G6 zero PV quando já Caído aplica Inconsciente e exige cura"] = function(t)
  local x=ctx();x.b.x=6;x.b.pv=1;x.b.conditions={{id="caido",stacks=1}}
  t.eq(x.usar("mesa/ataque-basico","b"),nil);t.eq(x.b.pv,0);t.ok(tem(x.b,"inconsciente"))
  x.vez("b");t.ok(x.usar(L)~=nil)
 end,
 ["G7 Esconder nas costas passa com dado alto; já escondido não cobra"] = function(t)
  local x=ctx(20);x.b.ownerUserId=999;x.b.kind="npc";x.b.x=8;x.b.olharX=1;x.b.olharZ=0
	  x.a.ficha2.construction.unlockedRankIds={"rank/furtividade-e-armadilhas/Principiante"}
  t.eq(x.usar(E),nil);t.ok(tem(x.a,"escondido"));t.eq(x.api.estado().acoes.usadas,1)
  t.ok(x.usar(E)~=nil);t.eq(x.api.estado().acoes.usadas,1)
  local y=ctx(1);y.b.ownerUserId=999;y.b.kind="npc";y.b.x=10;y.b.olharX=-1;y.b.olharZ=0
	  y.a.ficha2.construction.unlockedRankIds={"rank/furtividade-e-armadilhas/Principiante"}
  t.eq(y.usar(E),nil);t.ok(not tem(y.a,"escondido"));t.eq(y.api.estado().acoes.usadas,1)
 end,
 ["G6 Esconder de frente recusa antes do custo; parede permite"] = function(t)
  local x=ctx(20);x.b.ownerUserId=999;x.b.kind="npc";x.b.x=8;x.b.olharX=-1;x.b.olharZ=0
	  x.a.ficha2.construction.unlockedRankIds={"rank/furtividade-e-armadilhas/Principiante"}
  t.ok(x.usar(E)~=nil);t.eq(x.api.estado().acoes.usadas,0)
  x.terrain["6:5"]="parede";t.eq(x.usar(E),nil);t.ok(tem(x.a,"escondido"))
 end,
 ["G6 movimento muda a direção autoritativa da visão"] = function(t)
  local x=ctx();x.b.x=8;x.api.moveu(x.b,7,5);t.eq(x.b.olharX,1);t.eq(x.b.olharZ,0)
  x.b.z=6;x.api.moveu(x.b,8,5);t.eq(x.b.olharX,0);t.eq(x.b.olharZ,1)
 end,
 ["G6 arremesso que erra deixa a mesma arma no impacto e recupera sem duplicar"] = function(t)
  local x=ctx(1);local item=arma(x.a)
  t.eq(x.usar(N,"b"),nil);t.eq(item.equipped,false);t.eq(#x.api.estado().objetos,1)
  t.eq(x.api.estado().objetos[1].x,x.b.x);t.eq(x.api.estado().objetos[1].z,x.b.z)
  t.ok(x.usar("mesa/pegar-arma",nil,{x=8,z=5})~=nil)
  x.a.x=7;t.eq(x.usar("mesa/pegar-arma",nil,{x=8,z=5}),nil)
  t.eq(item.equipped,true);t.eq(#x.a.ficha2.construction.inventory,1);t.eq(#x.api.estado().objetos,0)
 end,
 ["G6 desarmar larga equipamento no chão do alvo"] = function(t)
  local x=ctx(15);x.b.x=6;local item=arma(x.b);x.a.ficha2.calculated.attributes.forca=12
  t.eq(x.usar("mesa/desarmar","b"),nil);t.eq(item.equipped,false);t.eq(#x.api.estado().objetos,1)
  t.eq(x.api.estado().objetos[1].x,7)
 end,
 ["G6 muro de terra bloqueia caminho, destino, habilidade e fresta diagonal sem custo"] = function(t)
  local x=ctx();t.eq(x.usar(W,nil,{x=7,z=5}),nil);x.vez("a")
  t.ok(x.api.bloqueiaMovimento(7,5));t.ok(x.api.validarMovimento(x.a,9,5,true)~=nil)
  t.eq(x.api.estado().acoes.usadas,0)
  t.ok(x.usar("ability/vento/Principiante/passo-de-vento",nil,{x=9,z=5})~=nil)
  t.eq(x.api.estado().acoes.usadas,0)
  local y=ctx();y.terrain["6:5"]="parede"
  t.ok(y.api.validarMovimento(y.a,6,6,true)~=nil);t.eq(y.api.estado().acoes.usadas,0)
  y.combat.active=false;t.ok(y.api.validarMovimento(y.a,7,5,true)~=nil)
 end,
 ["G6 bônus do jogo não pode ser enviado no pedido remoto"] = function(t)
  local x=ctx(8);x.b.x=6;x.b.sheet.ca=12
  t.eq(x.usar("mesa/ataque-basico","b",{balanceamentoJogo=true,bonusAcertoJogo=99}),nil);t.eq(x.b.pv,50)
  local y=ctx(8);y.a.balanceamentoJogo=true;y.b.x=6;y.b.sheet.ca=12
  t.eq(y.usar("mesa/ataque-basico","b"),nil);t.ok(y.b.pv<50)
 end,
}
