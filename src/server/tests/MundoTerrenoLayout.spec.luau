local Shared = game:GetService("ReplicatedStorage").Shared
local L = require(Shared.Mundo.TerrenoLayout)
local R = require(Shared.Mundo.RegiaoLayout)
local V = require(Shared.Mundo.VilaLayout)
local F = require(Shared.Mundo.FlorestaLayout)
local U = require(Shared.Mundo.RuinasLayout)

local function mundo(r, x, z)
	return r.x + x * r.cos + z * r.sin, r.z - x * r.sin + z * r.cos
end
local function coberto(x, z)
	for _, b in ipairs(L.BLOCOS) do if L.distanciaZona(x, z, b) == 0 then return true end end
	return false
end
return {
	["W1a passagem continua seca com largura minima e ligacao nas duas pontas"] = function(t)
		local p = L.PASSAGEM
		t.ok(p.largura >= 12 and p.largura <= 16)
		local comprimento = 0
		for i = 2, #p.polilinha do
			local a, b = p.polilinha[i - 1], p.polilinha[i]
			local dx, dz = b.x - a.x, b.z - a.z
			local n = math.sqrt(dx^2 + dz^2)
			comprimento += n
			for passo = 0, math.ceil(n / 4) do
				local u = math.min(passo * 4 / n, 1)
				for lateral = -p.largura / 2, p.largura / 2, 2 do
					local x, z = a.x + dx * u - dz / n * lateral, a.z + dz * u + dx / n * lateral
					t.ok(L.naPassagem(x, z), "largura interrompida")
					t.ok(math.abs(L.altura(x, z)) <= 0.3, "piso elevado")
					t.eq(L.agua(x, z), nil)
					t.eq(L.distanciaJogavel(x, z), 0)
					t.ok(coberto(x, z)); t.ok(not L.excluido(x, z, 0))
					local m = L.material(x, z, 0, 0)
					t.ok(m == "Ground" or m == "Slate")
					-- Apenas junção com a trilha de origem e chegada podem tocar zonas antigas.
					for _, r in ipairs(L.ZONAS_PLANAS) do
						if r.id ~= "trilha-inicial-1" and r.id ~= "nascimento-ruinas" and r.id ~= "arco-ruinas" and r.id ~= "caminho-ruinas" then
							t.ok(L.distanciaZona(x, z, r) > 0, "invadiu " .. r.id)
						end
					end
				end
			end
		end
		t.ok(comprimento >= 400 and comprimento <= 480, "contorno da sala: " .. comprimento)
		local a, b = p.polilinha[1], p.polilinha[#p.polilinha]
		t.ok(R.dentroDaTrilha(a.x, a.z, R.TRILHAS[1], 0))
		t.eq(b.x, U.NASCIMENTO.x); t.eq(b.z, U.NASCIMENTO.z)
	end,
	["W1a clareiras mirante e placas planos e paredes rochosas dos dois lados"] = function(t)
		local p = L.PASSAGEM
		t.ok(#p.clareiras >= 2 and #p.clareiras <= 3); t.eq(#p.placas, 2)
		local pontos = table.clone(p.clareiras)
		table.insert(pontos, p.mirante)
		for _, c in ipairs(p.placas) do table.insert(pontos, c) end
		for _, c in ipairs(pontos) do
			for ang = 0, 350, 10 do for r = 0, c.raio, 2 do
				local x, z = c.x + r * math.cos(math.rad(ang)), c.z + r * math.sin(math.rad(ang))
				t.ok(math.abs(L.altura(x, z)) <= 0.3); t.eq(L.agua(x, z), nil)
			end end
		end
		for _, x in ipairs({ 340, 400, 460 }) do for _, z in ipairs({ -160, 64 }) do
			local h = L.altura(x, z)
			t.ok(h >= 30, "parede baixa " .. x .. "," .. z .. ": " .. h)
			t.eq(L.material(x, z, h, 0), "Rock")
		end end
	end,
	["zonas derivadas sao planas em toda a superficie inclusive cantos girados"] = function(t)
		for _, r in ipairs(L.ZONAS_PLANAS) do
			for i = -4, 4 do for j = -4, 4 do
				local x, z = mundo(r, i * r.sx / 8, j * r.sz / 8)
				t.eq(L.altura(x, z), 0, r.id)
				t.eq(L.agua(x, z), nil, r.id)
			end end
		end
	end,
	["rampas nao saltam mais de dois studs a cada quatro ao redor de todas zonas"] = function(t)
		for _, r in ipairs(L.ZONAS_PLANAS) do
			for _, eixo in ipairs({ "x", "z" }) do for _, lado in ipairs({ -1, 1 }) do
				for _, fracao in ipairs({ -0.5, 0, 0.5 }) do
					local anterior = nil
					for d = 0, L.RAMPA + 4, 4 do
						local a = if eixo == "x" then lado * (r.sx / 2 + d) else r.sx * fracao
						local b = if eixo == "z" then lado * (r.sz / 2 + d) else r.sz * fracao
						local x, z = mundo(r, a, b)
						local h = L.altura(x, z)
						if anterior then t.ok(math.abs(h - anterior) <= 2, r.id .. " rampa " .. d .. " em " .. x .. "," .. z .. ": " .. math.abs(h - anterior)) end
						anterior = h
					end
				end
			end end
		end
	end,
	["marcos nascimentos e todas as casas das grades continuam em zero"] = function(t)
		for _, p in ipairs({ R.FOGUEIRA, R.ENTRADA, V.NASCIMENTO, F.MARCO, U.NASCIMENTO, U.ARCO }) do
			t.eq(L.altura(p.x, p.z), 0)
		end
		local centros = { { x = F.MARCO.x, z = F.MARCO.z + 8 }, U.ARENA }
		for _, a in ipairs(R.ARENAS) do table.insert(centros, { x = a[1], z = a[2] + 8 }) end
		for _, c in ipairs(centros) do for i = 1, 20 do for j = 1, 20 do
			t.eq(L.altura(c.x + (i - 10.5) * 1.8, c.z + (j - 10.5) * 1.8), 0)
		end end end
	end,
	["lago irregular grande tem fundo e nivel sem atravessar zona plana nem trilhas"] = function(t)
		for i, a in ipairs(L.AGUA) do
			t.eq(L.altura(a.x, a.z), a.fundo)
			t.ok(a.fundo < a.nivel and a.nivel < 0)
			local molhado = 0
			for x = a.x - a.ax * 1.5, a.x + a.ax * 1.5, 2 do for z = a.z - a.bz * 1.5, a.z + a.bz * 1.5, 2 do
				local sd = L.distanciaLago(x, z, i)
				-- Praia e margem de areia ficam longe das zonas planas e das trilhas.
				if sd <= 24 then
					-- A clareira nova pode tocar a praia seca; demais zonas mantem a folga.
                    for _,zona in ipairs(L.ZONAS_PLANAS) do
                     if zona.id ~= "provacao-agua" then t.ok(L.distanciaZona(x,z,zona)>20, zona.id) end
                    end
					for _, trilha in ipairs(R.TRILHAS) do t.ok(not R.dentroDaTrilha(x, z, trilha, 8)) end
				end
				if sd <= 0 then
					molhado += 1
					t.eq(L.agua(x,z) ~= nil, L.distanciaZona(x,z,L.PROVACAO_AGUA)>4)
					if L.agua(x,z) then t.ok(L.altura(x, z) <= a.nivel + 1e-8, "agua elevada em "..x..","..z) end
				else
					t.ok(L.agua(x, z) == nil)
				end
			end end
			t.ok(molhado * 4 > 9000, "lago pequeno: " .. molhado * 4 .. " studs2")
			-- Contorno irregular: o raio varia pelo menos 20% entre direções.
			local menor, maior = math.huge, 0
			for g = 0, 359, 5 do
				local r = 0
				while L.distanciaLago(a.x + math.cos(math.rad(g)) * r, a.z + math.sin(math.rad(g)) * r, i) < 0 do r += 1 end
				menor, maior = math.min(menor, r), math.max(maior, r)
			end
			t.ok(maior > menor * 1.2, "contorno circular")
		end
	end,
 ["provacao da agua plana seca com margem do contorno bruto"] = function(t)
  local r=L.PROVACAO_AGUA
  t.ok(table.find(L.ZONAS_PLANAS,r)~=nil)
  for dx=-r.sx/2,r.sx/2,2 do for dz=-r.sz/2,r.sz/2,2 do
   local x,z=r.x+dx,r.z+dz
   t.eq(L.altura(x,z),0); t.eq(L.agua(x,z),nil)
   -- O terra?o forma uma margem seca na borda leste, sem ?gua na zona.
   t.eq(L.material(x,z,0,0),"Grass")
  end end
 end,
	["patio do Ladino e zona plana igual a de TreinadoresLayout"] = function(t)
		local T = require(Shared.Mundo.TreinadoresLayout).ZONA_PLANA_NECESSARIA
		local achou
		for _, r in ipairs(L.ZONAS_PLANAS) do if r.id == T.id then achou = r end end
		t.ok(achou)
		t.eq(achou.x, T.x); t.eq(achou.z, T.z); t.eq(achou.sx, T.sx); t.eq(achou.sz, T.sz)
		t.eq(L.altura(T.x, T.z), 0)
		t.eq(L.material(T.x, T.z, 0, 0), T.material)
	end,
	["relevo: sope logo fora da area jogavel, montanhas depois, horizonte fechado e sem paredes"] = function(t)
		for _, a in ipairs(L.AREAS_JOGAVEIS) do
			for _, afastamento in ipairs({ 60, 100, 180, 250, 300 }) do
				for _, lado in ipairs({ -1, 1 }) do
					for i = -10, 10 do
						local pontos = {
							{ a.x + lado * (a.sx / 2 + afastamento), a.z + i / 10 * (a.sz / 2 + afastamento) },
							{ a.x + i / 10 * (a.sx / 2 + afastamento), a.z + lado * (a.sz / 2 + afastamento) },
						}
						for _, p in ipairs(pontos) do
							t.ok(coberto(p[1], p[2]), "margem de geracao curta")
							local dj = L.distanciaJogavel(p[1], p[2])
							if dj >= 280 and L.distanciaLago(p[1], p[2]) > L.AGUA[1].praia then
								t.ok(L.altura(p[1], p[2]) >= 30, "anel baixo em " .. p[1] .. "," .. p[2])
							end
						end
					end
				end
			end
		end
		-- Perímetro externo da geração: cristas altas, nunca o vazio logo atrás de uma planície.
		local xmin, xmax, zmin, zmax = math.huge, -math.huge, math.huge, -math.huge
		for _, b in ipairs(L.BLOCOS) do
			xmin, xmax = math.min(xmin, b.x - b.sx / 2), math.max(xmax, b.x + b.sx / 2)
			zmin, zmax = math.min(zmin, b.z - b.sz / 2), math.max(zmax, b.z + b.sz / 2)
		end
		for i = 0, 100 do
			for _, p in ipairs({ { xmin + 2, zmin + (zmax - zmin) * i / 100 }, { xmax - 2, zmin + (zmax - zmin) * i / 100 },
				{ xmin + (xmax - xmin) * i / 100, zmin + 2 }, { xmin + (xmax - xmin) * i / 100, zmax - 2 } }) do
				t.ok(L.altura(p[1], p[2]) >= 30, "perimetro baixo em " .. p[1] .. "," .. p[2])
			end
		end
		t.ok(L.altura(300, -200) >= 40, "divisoria entre continente e ruinas")
		-- Sopé 15-35 studs logo fora do campo (longe de rampas de zonas e do lago).
		local medidos = 0
		for x = -100, 100, 25 do
			local h = L.altura(x, 120 + 40)
			if L.distanciaPlana(x, 160) > 75 then
				medidos += 1
				t.ok(h >= 15 and h <= 40, "sope em x=" .. x .. ": " .. h)
			end
		end
		t.ok(medidos >= 4)
		-- Nenhuma parede lisa: gradiente a cada 4 studs limitado em toda a cobertura.
		local acima, total, maxg = 0, 0, 0
		for _, b in ipairs(L.BLOCOS) do
			for x = b.x - b.sx / 2 + 2, b.x + b.sx / 2 - 6, 10 do for z = b.z - b.sz / 2 + 2, b.z + b.sz / 2 - 6, 10 do
				local h = L.altura(x, z)
				local g = math.max(math.abs(L.altura(x + 4, z) - h), math.abs(L.altura(x, z + 4) - h)) / 4
				total += 1
				if g > 1.5 then acima += 1 end
				maxg = math.max(maxg, g)
			end end
		end
		t.ok(maxg <= 3, "parede com gradiente " .. maxg)
		t.ok(acima / total <= 0.03, "encostas acima de 1.5: " .. acima / total)
	end,
	["ruido e pintura deterministas com colinas neve e materiais dos biomas"] = function(t)
		local neve, colinas = 0, 0
		for x = -360, 960, 24 do for z = -840, 360, 24 do
			local h = L.altura(x, z)
			t.eq(h, L.altura(x, z))
			t.eq(L.material(x, z, h, 0), L.material(x, z, h, 0))
			t.ok(h >= -9 - 1e-8 and h <= 230 + 1e-8, "altura fora do limite em "..x..","..z..": "..string.format("%.17g",h))
			if h > L.NEVE + 12 then neve += 1; t.eq(L.material(x, z, h, 0), "Snow") end
			if h > 3 and h < 10 and L.distanciaJogavel(x, z) == 0 then colinas += 1 end
		end end
		t.ok(neve > 0 and colinas > 0)
		t.eq(L.material(0, -175, 0, 0), "Cobblestone")
		t.eq(L.material(0, -100, 0, 0), "Ground")
		t.eq(L.material(42, 60, 0, 0), "Grass")
		t.eq(L.material(600, -180, 0, 0), "Slate")
		-- Encosta íngreme nas montanhas vira pedra; lago tem lama no fundo e praia de areia.
		local m = L.material(-300, 0, 80, 1)
		t.ok(m == "Rock" or m == "Slate", m)
		local a = L.AGUA[1]
		t.eq(L.material(a.x, a.z, a.fundo, 0), "Mud")
		local x = a.x
		-- Margem oeste natural; a leste existe o terraço das comportas.
		while L.distanciaLago(x, a.z) < 5 do x -= 1 end
		t.eq(L.material(x, a.z, -2, 0), "Sand")
	end,
	["blocos disjuntos alinhados custo limitado e nenhum terreno perto da Mesa"] = function(t)
		local total = 0
		for i, b in ipairs(L.BLOCOS) do
			t.eq(b.resolucao, 4)
			t.eq((b.x - b.sx / 2) % 4, 0); t.eq((b.z - b.sz / 2) % 4, 0)
			t.eq(b.sx % 4, 0); t.eq(b.sz % 4, 0)
			t.ok(b.z + b.sz / 2 <= 490, "aproxima da Mesa")
			total += b.sx * b.sz / 16
			for j = 1, i - 1 do
				local a = L.BLOCOS[j]
				t.ok(math.abs(a.x - b.x) >= (a.sx + b.sx) / 2 or math.abs(a.z - b.z) >= (a.sz + b.sz) / 2)
			end
		end
		-- V2: 133000 colunas (cobertura 340 para as cordilheiras); teto deliberado
		-- para impedir expansão acidental. Geração medida no Studio em docs/TESTES.md.
		t.eq(total, 133000); t.ok(total <= 135000)
	end,
	["interior inteiro reservado incluindo celulas que tocam suas paredes"] = function(t)
		local r = L.INTERIOR
		for x = r.x - r.sx / 2, r.x + r.sx / 2, 2 do for z = r.z - r.sz / 2, r.z + r.sz / 2, 2 do
			t.ok(L.excluido(x, z, 2))
		end end
		t.ok(not L.excluido(R.ENTRADA.x, R.ENTRADA.z, 2))
		t.ok(not L.excluido(r.x - r.sx / 2 - 2, r.z, 2), "celula externa encosta na porta sem abrir buraco")
		t.ok(L.excluido(r.x - r.sx / 2 + 2, r.z, 2), "celula interna nunca recebe terreno")
	end,
}
