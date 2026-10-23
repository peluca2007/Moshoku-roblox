-- SOMENTE STUDIO: serviço real com jogadores, remoto e relógio injetados.
local Admin = require(script.Parent.Parent.AdminService)
local function fixture()
	local mensagens, agora, encerrados, mudancas = {}, 0, 0, 0
	local tokens = {
		a = { id="a", ownerUserId = 1, pv = 1, pvMax = 10, mana = 0, manaMax = 4, version = 1, conditions = {} },
		b = { id="b", ownerUserId = 2, pv = 2, pvMax = 20, mana = 0, manaMax = 8, version = 1, conditions = {} },
	}
	local combat = { active = false }
	local combate=require(script.Parent.Parent.AdminCombate).start({tokens=tokens,combat=combat,
  mudou=function() mudancas+=1 end, pv=function(t,v) t.pv=v;t.version+=1 end})
 local api = Admin.start({ combate=combate, tokens = tokens, combat = combat, isAdmin = function(p) return p.UserId == 1 end,
		agora = function() agora += 2; return agora end,
		remote = { FireClient = function(_, _, texto) table.insert(mensagens, texto) end },
		encerrar = function() encerrados += 1 end, mudou = function() mudancas += 1 end,
	})
	return api, tokens, combat, function() return encerrados, mudancas, mensagens end
end
return {
	["nao admin nao executa comando nem altera fichas"] = function(t)
		local a, tokens, _, resultado = fixture()
		t.ok(a.executar({ UserId = 2 }, "/adm encerrar") ~= nil)
		t.eq(resultado(), 0)
		t.eq(tokens.a.pv, 1)
	end,
	["cura suas fichas também no combate sem alterar terceiros"] = function(t)
		local a, tokens, combat = fixture()
		combat.active = true
		t.eq(a.executar({ UserId = 1 }, "/adm curar"),nil)
		t.eq(tokens.a.pv, 10)
		combat.active = false
		t.eq(a.executar({ UserId = 1 }, "/adm curar"), nil)
		t.eq(tokens.a.pv, 10); t.eq(tokens.b.pv, 2)
	end,
	["limita frequencia e texto malformado"] = function(t)
		local respostas = {}
		local a = Admin.start({ tokens = {}, combat = {}, isAdmin = function() return true end,
			agora = function() return 1 end, remote = { FireClient = function(_, _, r) table.insert(respostas, r) end } })
		local p = { UserId = 1 }
		t.eq(a.executar(p, 42), "Comando inválido (máximo 160 caracteres).")
		t.eq(a.executar(p, {}), "Comando desconhecido. Use /adm ajuda.")
		t.eq(a.executar(p, "ajuda"), nil)
		t.ok(a.executar(p, "status") ~= nil)
		t.eq(#respostas, 1)
	end,
}
