-- Projeção pura do cliente: a sequência autoritativa mantém objetivo e avisos separados.
local P = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.ExtraProvacoes)
return {
	["ladino segue sino confirmado e não inventa aprovação"] = function(t)
		local r = { estado = "em-curso", npcId = "vila-1" }
		t.eq(P.projetar(r).objetivo, "Pegue o sino")
		r.sino = true
		t.eq(P.projetar(r).objetivo, "Leve o sino ao portão")
		t.eq(P.projetar(r).aviso, nil)
		r.sino, r.mensagem = false, "Pego! O sino voltou ao pedestal. Tente de novo."
		local v = P.projetar(r)
		t.eq(v.objetivo, "Pegue o sino"); t.eq(v.ativo, true)
		t.eq(v.aviso.tipo, "perigo"); t.eq(v.aviso.titulo, "Pego!")
	end,
	["mestra distingue tempo esgotado sem inventar custo"] = function(t)
		local r = { estado = "em-curso", npcId = "vila-2", tempo = 90 }
		t.eq(P.projetar(r).objetivo, "Encha as 3 bacias")
		t.eq(P.projetar(r).ladino, false)
		r.estado, r.mensagem, r.tempo = "falhou", "Tempo esgotado. Tente novamente sem custo.", 0
		local v = P.projetar(r)
		t.eq(v.ativo, false); t.eq(v.aviso.tipo, "alerta")
		t.eq(r.tempo, 0); t.eq(r.estado, "falhou")
	end,
	["aprovação exige estado do servidor e celebra por pelo menos cinco segundos"] = function(t)
		for _, npc in { "vila-1", "vila-2" } do
			local v = P.projetar({ estado = "aprovado", npcId = npc })
			t.eq(v.ativo, false); t.eq(v.aviso.tipo, "sucesso"); t.ok(v.aviso.duracao >= 5)
			t.ok(P.identidade(npc).nome ~= ""); t.ok(P.identidade(npc).arvore ~= "")
		end
	end,
	["mensagem ausente não repete aviso nos batimentos de tempo ou postura"] = function(t)
		local r = { estado = "em-curso", npcId = "vila-1", agachado = true }
		t.eq(P.projetar(r).aviso, nil)
		t.eq(r.agachado, true)
	end,
}
