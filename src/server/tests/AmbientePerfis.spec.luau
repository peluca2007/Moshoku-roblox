local Shared = game:GetService("ReplicatedStorage").Shared
local A = require(Shared.Mundo.AmbientePerfis)
local FlorestaLayout = require(Shared.Mundo.FlorestaLayout)

local function igual(t, a, b, rotulo)
	for chave, valor in a do
		if chave == "skybox" then
			for _, face in A.FACES_SKYBOX do
				t.eq(valor[face], b[chave][face], rotulo .. " skybox " .. face)
			end
		elseif type(valor) == "table" then
			for i = 1, 3 do
				t.ok(math.abs(valor[i] - b[chave][i]) < 1e-9, rotulo .. " " .. chave)
			end
		else
			t.ok(math.abs(valor - b[chave]) < 1e-9, rotulo .. " " .. chave)
		end
	end
end

return {
	["os tres perfis tem os mesmos campos"] = function(t)
		for nome, perfil in A.PERFIS do
			for chave, valor in A.PERFIS.dia do
				t.ok(perfil[chave] ~= nil, nome .. " sem " .. chave)
				t.eq(type(perfil[chave]), type(valor), nome .. " tipo " .. chave)
			end
			for chave in perfil do
				t.ok(A.PERFIS.dia[chave] ~= nil, nome .. " campo extra " .. chave)
			end
		end
	end,
	["cores ficam entre 0 e 255"] = function(t)
		for nome, perfil in A.PERFIS do
			for chave, valor in perfil do
				if type(valor) == "table" and chave ~= "skybox" then
					t.eq(#valor, 3, nome .. " " .. chave)
					for _, canal in valor do
						t.ok(canal >= 0 and canal <= 255, nome .. " " .. chave)
					end
				end
			end
		end
	end,
	["campos de ceu, foco e luz ficam em faixas validas"] = function(t)
		local faixas = {
			brilho = { 0, 4 }, difuso = { 0, 1 }, especular = { 0, 1 },
			atmDensidade = { 0, 1 }, atmOffset = { 0, 1 }, atmGlare = { 0, 10 }, atmHaze = { 0, 10 },
			bloomIntensidade = { 0, 3 }, raios = { 0, 1 },
			dofLonge = { 0, 1 }, dofDistancia = { 0, 500 }, dofRaio = { 0, 500 },
			estrelas = { 0, 5000 }, solTam = { 0, 100 }, luaTam = { 0, 100 },
			nuvemCobertura = { 0, 1 }, nuvemDensidade = { 0, 1 },
		}
		for nome, perfil in A.PERFIS do
			t.ok(perfil.clock >= 0 and perfil.clock <= 24, nome .. " clock")
			for chave, faixa in faixas do
				local v = perfil[chave]
				t.ok(type(v) == "number" and v >= faixa[1] and v <= faixa[2], nome .. " faixa " .. chave)
			end
			-- Future clareia: o dia ao ar livre nao passa de 2,6 de brilho.
			t.ok(perfil.brilho <= 2.6, nome .. " brilho acima do conservador")
		end
	end,
	["dof so desfoca ao longe: o foco comeca ao longe (distancia + raio >= 80 studs)"] = function(t)
		for nome, perfil in A.PERFIS do
			if perfil.dofLonge > 0 then
				t.ok(perfil.dofDistancia + perfil.dofRaio >= 80, nome .. " foco proximo demais")
			end
		end
	end,
	["skybox: vazio nos perfis atuais; completo so com as 6 faces"] = function(t)
		for nome, perfil in A.PERFIS do
			t.eq(type(perfil.skybox), "table", nome)
			-- Se alguem preencher, tem de ser completo e com texto.
			local usado = next(perfil.skybox) ~= nil
			if usado then
				t.ok(A.skyboxCompleto(perfil.skybox), nome .. " skybox incompleto")
			end
		end
		t.eq(#A.FACES_SKYBOX, 6)
		t.ok(not A.skyboxCompleto(nil))
		t.ok(not A.skyboxCompleto({}))
		local cheio = { bk = "rbxassetid://1", dn = "rbxassetid://2", ft = "rbxassetid://3", lf = "rbxassetid://4", rt = "rbxassetid://5", up = "rbxassetid://6" }
		t.ok(A.skyboxCompleto(cheio))
		local faltando = table.clone(cheio)
		faltando.up = ""
		t.ok(not A.skyboxCompleto(faltando))
	end,
	["misturar troca a skybox na metade e nao mistura texto"] = function(t)
		local cheio = { bk = "a", dn = "b", ft = "c", lf = "d", rt = "e", up = "f" }
		local com = table.clone(A.PERFIS.dia)
		com.skybox = cheio
		local sem = A.PERFIS.floresta
		t.eq(A.misturar(com, sem, 0.49).skybox, cheio)
		t.eq(A.misturar(com, sem, 0.51).skybox, sem.skybox)
		-- as nuvens e estrelas continuam misturando de forma continua.
		local meio = A.misturar(A.PERFIS.dia, A.PERFIS.floresta, 0.5)
		t.ok(math.abs(meio.nuvemCobertura - (A.PERFIS.dia.nuvemCobertura + A.PERFIS.floresta.nuvemCobertura) / 2) < 1e-9)
	end,
	["misturar nas pontas devolve cada perfil sem alterar o original"] = function(t)
		local antes = A.PERFIS.dia.clock
		igual(t, A.misturar(A.PERFIS.dia, A.PERFIS.floresta, 0), A.PERFIS.dia, "t=0")
		igual(t, A.misturar(A.PERFIS.dia, A.PERFIS.floresta, 1), A.PERFIS.floresta, "t=1")
		local meio = A.misturar(A.PERFIS.dia, A.PERFIS.floresta, 0.5)
		t.ok(math.abs(meio.clock - (A.PERFIS.dia.clock + A.PERFIS.floresta.clock) / 2) < 1e-9)
		t.ok(meio.ambiente ~= A.PERFIS.dia.ambiente)
		t.eq(A.PERFIS.dia.clock, antes)
	end,
	["a sala fica sempre na noite, em qualquer z"] = function(t)
		for _, z in { 900, 0, -175, -450 } do
			t.eq(A.pesos(0, z, true).noite, 1)
			igual(t, A.alvo(0, z, true), A.PERFIS.noite, "sala z=" .. z)
		end
	end,
	["vila e regiao sao dia; a floresta so comeca depois de -270"] = function(t)
		for _, z in { 0, -44, -175, -269 } do
			t.eq(A.pesos(0, z, false).floresta, 0, tostring(z))
			igual(t, A.alvo(0, z, false), A.PERFIS.dia, "z=" .. z)
		end
		igual(t, A.alvo(0, -320, false), A.PERFIS.floresta, "limite")
		igual(t, A.alvo(0, -485, false), A.PERFIS.floresta, "clareira")
	end,
	["a mistura da trilha e monotona e entra na floresta antes da clareira"] = function(t)
		local anterior = 0
		for z = -260, -340, -2 do
			local f = A.pesos(0, z, false).floresta
			t.ok(f >= anterior - 1e-12, "recuou em z=" .. z)
			anterior = f
		end
		-- O solo da floresta comeca em z=-300: ali a luz ja e mais floresta que vila.
		local solo = FlorestaLayout.SOLO
		local entrada = solo.z + solo.sz / 2
		t.eq(entrada, -300)
		t.ok(A.pesos(0, entrada, false).floresta > 0.4)
		t.eq(A.pesos(0, FlorestaLayout.CLAREIRA.z, false).floresta, 1)
	end,
	["as ruinas (x>=400) tem luz propria; a vila, a floresta e a sala nao"] = function(t)
		igual(t, A.alvo(600, -200, false), A.PERFIS.ruinas, "ruinas")
		igual(t, A.alvo(600, 700, true), A.PERFIS.noite, "sala tem prioridade")
		t.eq(A.pesos(100, -200, false).ruinas, 0)
		t.eq(A.pesos(0, -450, false).ruinas, 0)
	end,
	["passo converge ao alvo, nunca ultrapassa e ignora dt negativo"] = function(t)
		local atual, alvo = A.PERFIS.noite, A.PERFIS.dia
		local parado = A.passo(atual, alvo, -1, 1)
		igual(t, parado, atual, "dt negativo")
		local antes = math.abs(atual.brilho - alvo.brilho)
		for _ = 1, 600 do
			atual = A.passo(atual, alvo, 1 / 60, A.TAU_ZONA)
			local depois = math.abs(atual.brilho - alvo.brilho)
			t.ok(depois <= antes + 1e-12, "afastou")
			antes = depois
		end
		t.ok(antes < 1e-3, "nao convergiu em 10 s")
		-- passo grande de tempo (queda de quadros) cai no alvo sem passar dele.
		local salto = A.passo(A.PERFIS.noite, alvo, 60, A.TAU_ZONA)
		t.ok(math.abs(salto.brilho - alvo.brilho) < 1e-6)
	end,
}
