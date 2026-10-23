local Shared = game:GetService("ReplicatedStorage").Shared
local L = require(Shared.Mundo.VilaLayout)

local P = require(Shared.Mundo.PropsLayout)
local T = require(Shared.Mundo.TerrenoLayout)
local Treinadores = require(Shared.Mundo.TreinadoresLayout)
local Npcs = require(Shared.Mundo.NpcsDados)

return {
	["V6 casas e quintais respeitam predios vias portas e treinadores"] = function(t)
		local erros={}
		local function check(ok,msg) if not ok then table.insert(erros,msg or "invalido") end end
		local zonas={L.ESTRADA,L.TRILHA_FLORESTA,Treinadores.ZONA_PLANA_NECESSARIA,Treinadores.LADINO,Treinadores.grade(),Treinadores.mestra()}
		for _,p in ipairs(P.VILA) do
			for _,e in ipairs(L.CASAS_NOVAS) do
				check(not L.sobrepoe(P.retangulo(p),L.ocupacao(e)),"prop "..p[3].." na casa "..e.id)
				if p[3]~="casa" then check(L.distancia(L.porta(e),P.retangulo(p))>=L.DISTANCIA_MAX_PORTA,"prop na porta "..e.id) end
			end
		end
		for _,e in ipairs(L.CASAS_NOVAS) do
			for _,z in ipairs(zonas) do check(not L.sobrepoe(L.ocupacao(e),z),e.id.." em zona protegida") end
		end
		for indice,p in ipairs(L.DECORACAO) do
			for _,r in ipairs(L.pegadasDecoracao(p,P.retangulo)) do
				for j=1,indice-1 do
					for _,outro in ipairs(L.pegadasDecoracao(L.DECORACAO[j],P.retangulo)) do
						check(not L.sobrepoe(r,outro),p[3].." sobre decoracao "..j)
					end
				end
				check(not L.sobrepoe(r,L.POCO_QUINTAL),p[3].." sobre poco")
				for _,outro in ipairs(P.VILA) do check(not L.sobrepoe(r,P.retangulo(outro)),p[3].." sobre prop "..outro[3]) end
				for _,b in ipairs(L.BARRACAS) do check(not L.sobrepoe(r,{x=b.x,z=b.z,sx=8,sz=9.4}),p[3].." sobre mercado") end
				for _,z in ipairs(zonas) do check(not L.sobrepoe(r,z),p[3].." em zona protegida") end
				for _,e in ipairs(L.predios()) do
					check(not L.sobrepoe(r,L.ocupacao(e)),p[3].." sobre casa "..e.id)
					check(L.distancia(L.porta(e),r)>=L.DISTANCIA_MAX_PORTA,p[3].." na porta "..e.id)
				end
				for _,a in ipairs(L.ACESSOS) do check(not L.sobrepoe(r,a),p[3].." no acesso "..a.id) end
				for _,npc in ipairs(Npcs.LISTA) do check(L.distancia(Npcs.posicao(npc),r)>=2,p[3].." no NPC") end
			end
		end
		t.eq(#erros,0,table.concat(erros,"; "))
	end,
	["V6 praca conserva anel livre e nascimento fora do chafariz"] = function(t)
		t.eq(#L.CASAS_NOVAS,4)
		t.eq(L.CHAFARIZ.x,L.PRACA.x); t.eq(L.CHAFARIZ.z,L.PRACA.z)
		t.ok(L.distancia(L.NASCIMENTO,L.CHAFARIZ)>=2.9,"spawn fora da fonte")
		for _,p in ipairs(L.DECORACAO) do
			if p[3]=="banco" or p[3]=="canteiro" or p[3]=="bandeirolas" then
				for _,r in ipairs(L.pegadasDecoracao(p,P.retangulo)) do
					local dx=math.max(math.abs(r.x-L.CHAFARIZ.x)-(r.sx+L.CHAFARIZ.sx)/2,0)
					local dz=math.max(math.abs(r.z-L.CHAFARIZ.z)-(r.sz+L.CHAFARIZ.sz)/2,0)
					t.ok(math.sqrt(dx*dx+dz*dz)>=L.RAIO_CIRCULACAO,"anel ocupado por "..p[3])
				end
			end
		end
	end,
	["V6 pedras deterministicas ligam cada porta sem cruzar predios"] = function(t)
		local a,b=L.pedras(41636),L.pedras(41636)
		t.eq(#a,#b)
		local c=L.pedras(9);t.ok(c[1].giro~=a[1].giro,"semente varia pedras")
		for i,p in ipairs(a) do
			t.eq(p.x,b[i].x);t.eq(p.z,b[i].z);t.eq(p.giro,b[i].giro)
			local r={x=p.x,z=p.z,sx=p.sx+0.5,sz=p.sz+0.5}
			for _,e in ipairs(L.predios()) do t.ok(not L.sobrepoe(r,L.ocupacao(e)),"pedra em "..e.id) end
		end
		for _,e in ipairs(L.CASAS_NOVAS) do
			local r=L.ocupacao(e)
			local baixo,alto=math.huge,-math.huge
			for ix=0,4 do for iz=0,4 do
				local x,z=r.x+(ix/4-0.5)*r.sx,r.z+(iz/4-0.5)*r.sz
				t.eq(T.agua(x,z),nil,"casa seca "..e.id)
				local h=T.altura(x,z);baixo,alto=math.min(baixo,h),math.max(alto,h)
			end end
			t.ok(alto-baixo<2,"fundacao baixa "..e.id.." = "..(alto-baixo))
			local acesso
			for _,r in ipairs(L.ACESSOS) do if r.id==e.id then acesso=r end end
			t.ok(acesso~=nil,e.id.." sem trilha")
			t.ok(L.distancia(L.porta(e),acesso)<0.01,"trilha alcanca porta "..e.id)
			t.ok(L.sobrepoe(acesso,L.PRACA) or L.distancia({x=acesso.x,z=acesso.z},L.PRACA)<=math.max(acesso.sx,acesso.sz)/2+1)
			local paleta=L.paleta(e,41636);t.eq(paleta[1],L.paleta(e,41636)[1]);t.ok(paleta[1]~=L.paleta(e,41637)[1])
		end
	end,

	["layout da vila nao tem sobreposicao nem caminho bloqueado"] = function(t)
		local problemas = L.validar()
		t.eq(#problemas, 0, table.concat(problemas, "; "))
	end,
	["vila encosta na regiao inicial e a estrada nasce no acampamento"] = function(t)
		t.eq(L.SOLO.z + L.SOLO.sz / 2, -120)
		t.eq(L.ESTRADA.z + L.ESTRADA.sz / 2, -44)
		t.eq(L.ESTRADA.z - L.ESTRADA.sz / 2, L.PRACA.z + L.PRACA.sz / 2 - 2)
		t.eq(L.SOLO.z - L.SOLO.sz / 2, -300)
		t.eq(L.TRILHA_FLORESTA.z + L.TRILHA_FLORESTA.sz / 2, -300)
		t.eq(L.TRILHA_FLORESTA.z - L.TRILHA_FLORESTA.sz / 2, -350)
		t.eq(L.PLACA_FLORESTA.z, -296)
	end,
	["estrada passa entre as arvores do anel sul da regiao"] = function(t)
		-- Árvores (25,-108) escala 1.3 e (-24,-108) escala 1.1 de RegiaoInicial.
		t.ok(not L.sobrepoe(L.ESTRADA, { x = 25, z = -108, sx = 14.3, sz = 14.3 }))
		t.ok(not L.sobrepoe(L.ESTRADA, { x = -24, z = -108, sx = 12.1, sz = 12.1 }))
	end,
	["dojo existe e cada porta encara a praca"] = function(t)
		local dojo
		for _, e in ipairs(L.EDIFICIOS) do
			if e.papel == "dojo" then dojo = e end
			t.ok(L.distancia(L.porta(e), L.PRACA) <= L.DISTANCIA_MAX_PORTA, e.id)
		end
		t.ok(dojo ~= nil)
		t.ok(L.porta(dojo).z > L.ocupacao(dojo).z)
	end,
	["ocupacao gira a base do modelo conforme a porta"] = function(t)
		local e = { id = "x", largura = 10, profundidade = 4, escala = 1, x = 0, z = 0, porta = "leste" }
		local o = L.ocupacao(e)
		t.eq(o.sx, 4)
		t.eq(o.sz, 10)
		t.eq(L.porta(e).x, 2)
		t.eq(L.angulo(e), math.pi / 2)
		e.porta = "norte"
		t.eq(L.ocupacao(e).sx, 10)
		t.eq(L.porta(e).z, 2)
	end,
	["validar detecta sobreposicao"] = function(t)
		t.ok(L.sobrepoe({ x = 0, z = 0, sx = 4, sz = 4 }, { x = 3, z = 0, sx = 4, sz = 4 }))
		t.ok(not L.sobrepoe({ x = 0, z = 0, sx = 4, sz = 4 }, { x = 4, z = 0, sx = 4, sz = 4 }))
		t.eq(L.distancia({ x = 10, z = 0 }, { x = 0, z = 0, sx = 4, sz = 4 }), 8)
	end,
}
