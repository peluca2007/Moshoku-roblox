local Shared = game:GetService("ReplicatedStorage").Shared
local Conteudo = require(Shared.AjudaConteudo)

return {
	["ajuda oferece quatro abas identificaveis com texto curto e puro"] = function(t)
		t.eq(#Conteudo.abas, 4)
		local ids = {}
		for _, aba in Conteudo.abas do
			t.eq(type(aba.id), "string")
			t.ok(not ids[aba.id], "id de aba repetido")
			ids[aba.id] = true
			t.ok(utf8.len(aba.titulo) <= 18, "título deve caber nos botões móveis")
			t.ok(#aba.paragrafos >= 3 and #aba.paragrafos <= 5)
			for _, texto in aba.paragrafos do
				t.eq(type(texto), "string")
				t.ok(utf8.len(texto) > 0 and utf8.len(texto) <= 330, "parágrafo deve ser curto e UTF-8 válido")
				t.ok(not string.find(texto, "<[^>]+>"), "conteúdo não usa marcação RichText")
			end
		end
	end,
	["a ajuda descreve o jogo atual e não o mundo aberto antigo"] = function(t)
		local todo = {}
		for _, aba in Conteudo.abas do
			table.insert(todo, aba.titulo)
			for _, texto in aba.paragrafos do table.insert(todo, texto) end
		end
		local junto = string.lower(table.concat(todo, " "))
		for _, proibida in { "8 minutos", "relógio", "relogio", "trilha", "mundo aberto", "um dia dura", "patrulha" } do
			t.ok(not string.find(junto, proibida, 1, true), "texto do jogo antigo na ajuda: " .. proibida)
		end
		-- o que o jogo atual precisa explicar
		for _, esperada in { "esgoto", "anomalia", "fragmento", "meio dia", "30 dias", "voltar à cidade", "tela viajando", "vota" } do
			t.ok(string.find(junto, esperada, 1, true), "a ajuda não menciona: " .. esperada)
		end
	end,
	["conteudo compartilhado nao pode ser alterado por uma view"] = function(t)
		t.ok(table.isfrozen(Conteudo))
		t.ok(table.isfrozen(Conteudo.abas))
		for _, aba in Conteudo.abas do
			t.ok(table.isfrozen(aba))
			t.ok(table.isfrozen(aba.paragrafos))
		end
	end,
	["dica tem o atalho visivel e dura oito segundos"] = function(t)
		t.eq(Conteudo.dica, "Toque em AJUDA para abrir o guia")
		t.eq(Conteudo.duracaoDica, 8)
	end,
}
