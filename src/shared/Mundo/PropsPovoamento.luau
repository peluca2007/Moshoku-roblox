-- Integração pura: consulta o terreno sem criar ciclo PropsLayout -> Terreno -> layouts.
local Shared = game:GetService("ReplicatedStorage").Shared
local P = require(Shared.Mundo.PropsLayout)
local T = require(Shared.Mundo.TerrenoLayout)
local Vila = require(Shared.Mundo.VilaLayout)
local Regiao = require(Shared.Mundo.RegiaoLayout)
local Floresta = require(Shared.Mundo.FlorestaLayout)
local Ruinas = require(Shared.Mundo.RuinasLayout)
local Treinadores = require(Shared.Mundo.TreinadoresLayout)
local M = {}
M.FOLGA_TREINADORES = 4
M.LATERAIS = { -88, 106 }
-- z=-44 está dentro de ACAMPAMENTO (até -52). Mantém o contrato de não cortá-lo.
M.PORTAO_NORTE = -64

-- Consulta a pegada inteira (incluindo a margem de voxel), não apenas o centro.
function M.seco(p)
	local r = P.retangulo(p)
	for _,dx in ipairs({-0.5,0,0.5}) do
		for _,dz in ipairs({-0.5,0,0.5}) do
			if T.agua(r.x+dx*r.sx,r.z+dz*r.sz) then return false end
		end
	end
	return true
end

function M.zonaPlana(p)
	local r=P.retangulo(p)
	local raio=math.sqrt(r.sx*r.sx+r.sz*r.sz)/2
	for _,z in ipairs(T.ZONAS_PLANAS) do
		local a=math.rad(z.giro or 0)
		local dx,dz=r.x-z.x,r.z-z.z
		local x=dx*math.cos(a)-dz*math.sin(a)
		local zz=dx*math.sin(a)+dz*math.cos(a)
		if math.abs(x)<z.sx/2+raio and math.abs(zz)<z.sz/2+raio then return z.id end
	end
	return nil
end

function M.margem(p)
	if not M.seco(p) then return false end
	for _, d in ipairs({{6,0},{-6,0},{0,6},{0,-6}}) do
		if T.agua(p[1]+d[1],p[2]+d[2]) then return true end
	end
	return false
end

-- Abertura real do asset é ~5.9 studs: escala 1.8 preserva estrada de 10.
-- No asset exportado Tabuas fica em +Z em relação a Pedra; norte180/sul0 abrem para dentro.
function M.cercado(norte)
	local lista={ {0,norte,"portao",1.8,180},{0,-300,"portao",1.8,0} }
	for _,z in ipairs({norte,-300}) do
		for _,lado in ipairs({-1,1}) do
			local x=13.5
			local limite = if lado<0 then -M.LATERAIS[1] else M.LATERAIS[2]
			while x<limite do table.insert(lista,{lado*x,z,"palicada",1,0}); x+=8 end
		end
	end
	for _,x in ipairs(M.LATERAIS) do
		-- Distribui centros para não deixar fresta nos cantos, comprimento <=8.
		local n=math.ceil((norte+300)/8)
		for i=0,n-1 do table.insert(lista,{x,-300+(i+0.5)*(norte+300)/n,"palicada",1,90}) end
	end
	return lista
end

function M.vila(norte)
	norte = norte or M.PORTAO_NORTE
	local lista={}
	local zonasTreinadores={Treinadores.PATIO,Treinadores.LADINO,Treinadores.grade(),Treinadores.mestra()}
	local function livreTreinadores(p)
		local r=P.retangulo(p)
		for _,z in ipairs(zonasTreinadores) do
			if Vila.sobrepoe(r,{x=z.x,z=z.z,sx=z.sx+M.FOLGA_TREINADORES*2,sz=z.sz+M.FOLGA_TREINADORES*2}) then return false end
		end
		return true
	end
	for _,p in ipairs(P.VILA) do if M.seco(p) and livreTreinadores(p) then table.insert(lista,p) end end
	local rets={}
	for _,lago in ipairs(T.AGUA) do
	for x=lago.x-(lago.ax or lago.raio)*1.5-8,lago.x+(lago.ax or lago.raio)*1.5+8,4 do
		for z=lago.z-(lago.bz or lago.raio)*1.5-8,lago.z+(lago.bz or lago.raio)*1.5+8,4 do
			local p={x,z,"juncos",0.7,((x+z)%4)*90}
			local r=P.retangulo(p)
			local livre=M.margem(p) and not M.zonaPlana(p) and livreTreinadores(p)
			for _,f in ipairs(P.fixosVila()) do if Vila.sobrepoe(r,f) then livre=false break end end
			for _,o in ipairs(lista) do if Vila.sobrepoe(r,P.retangulo(o)) then livre=false break end end
			if livre then table.insert(lista,p); table.insert(rets,r) end
		end
	end
	end
	if norte then
		local cerca=M.cercado(norte)
		local filtrada={}
		for _,p in ipairs(lista) do
			local livre=true
			for _,c in ipairs(cerca) do if Vila.sobrepoe(P.retangulo(p),P.retangulo(c)) then livre=false break end end
			if livre then table.insert(filtrada,p) end
		end
		lista=filtrada
		for _,p in ipairs(cerca) do
			local permitido=true
			-- A grade da Mestra fica dentro do perímetro. Abra uma passagem na lateral
			-- do lago usando a sua própria geometria como referência.
			local grade=Treinadores.grade()
			local mestra=Treinadores.mestra()
			if p[3]=="palicada" and math.abs(p[1]-M.LATERAIS[1])<1
				and math.abs(p[2]-mestra.z)<grade.sz/2+8 then permitido=false end
			for _,z in ipairs(zonasTreinadores) do
				local passagemExtra=if p[3]=="palicada" then 8 else 0
				if Vila.sobrepoe(P.retangulo(p),{x=z.x,z=z.z,sx=z.sx+(M.FOLGA_TREINADORES+passagemExtra)*2,sz=z.sz+(M.FOLGA_TREINADORES+passagemExtra)*2}) then permitido=false break end
			end
			if permitido then table.insert(lista,p) end
		end
	end
	return lista
end

-- Auditoria de caminhos previstos sobre água. Não monta ponte automaticamente.
function M.caminhosAlagados()
	local nomes={}
	local vias={Vila.ESTRADA,Vila.TRILHA_FLORESTA,Floresta.TRILHA,Ruinas.CAMINHO}
	for _,r in ipairs(Regiao.TRILHAS) do table.insert(vias,{x=r[1],z=r[2],sx=r[3],sz=r[4],giro=r[5]}) end
	for _,via in ipairs(vias) do
		local a=math.rad(via.giro or 0)
		for dz=-via.sz/2,via.sz/2,2 do
			for dx=-via.sx/2,via.sx/2,2 do
				local x=via.x+dx*math.cos(a)+dz*math.sin(a)
				local z=via.z-dx*math.sin(a)+dz*math.cos(a)
				if T.agua(x,z) then table.insert(nomes,{x=x,z=z}) end
			end
		end
	end
	return nomes
end
return M
