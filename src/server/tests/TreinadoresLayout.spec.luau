local Shared = game:GetService("ReplicatedStorage").Shared
local Layout = require(Shared.Mundo.TreinadoresLayout)
local Vila = require(Shared.Mundo.VilaLayout)
local Terreno = require(Shared.Mundo.TerrenoLayout)
local Povoamento = require(Shared.Mundo.PropsPovoamento)
local Props = require(Shared.Mundo.PropsLayout)
local Regiao = require(Shared.Mundo.RegiaoLayout)

local function sobrepoe(a, b)
	return math.abs(a.x - b.x) < (a.sx + b.sx) / 2 and math.abs(a.z - b.z) < (a.sz + b.sz) / 2
end

return {
 ["patio, treinador e mestra nao colidem com palicada V4 nem trilhas iniciais"] = function(t)
  local m=Layout.mestra()
  for _,area in { Layout.PATIO, Layout.LADINO, Layout.grade(), {x=m.x,z=m.z,sx=4,sz=4} } do
   for _,e in Vila.EDIFICIOS do t.ok(not sobrepoe(area,Vila.ocupacao(e))) end
   for _,r in { Vila.ESTRADA,Vila.PRACA,Vila.TRILHA_FLORESTA } do t.ok(not sobrepoe(area,r)) end
   for _,p in Povoamento.cercado(Povoamento.PORTAO_NORTE) do
    t.ok(not sobrepoe(area,Props.retangulo(p)),"ocupação cruza paliçada V4")
   end
   for _,trilha in Regiao.TRILHAS do
    -- AABB conservadora também protege trilhas giradas.
    local c,s=math.abs(math.cos(math.rad(trilha[5] or 0))),math.abs(math.sin(math.rad(trilha[5] or 0)))
    t.ok(not sobrepoe(area,{x=trilha[1],z=trilha[2],sx=trilha[3]*c+trilha[4]*s,sz=trilha[3]*s+trilha[4]*c}))
   end
  end
 end,
	["patio livre de predios, caminhos e borda da vila"] = function(t)
		local patio = Layout.PATIO
		t.eq(patio.sx, 40); t.eq(patio.sz, 40)
		for _, e in Vila.EDIFICIOS do t.ok(not sobrepoe(patio, Vila.ocupacao(e)), "colide com " .. e.id) end
		for _, e in Vila.BARRACAS do t.ok(not sobrepoe(patio, e), "colide com " .. e.id) end
		for _, caminho in { Vila.ESTRADA, Vila.PRACA, Vila.TRILHA_FLORESTA } do
			t.ok(not sobrepoe(patio, caminho), "colide com caminho ou praca")
		end
		local solo = Vila.SOLO
		t.ok(patio.x - patio.sx / 2 >= solo.x - solo.sx / 2 + 6)
		t.ok(patio.x + patio.sx / 2 <= solo.x + solo.sx / 2 - 6)
		t.ok(patio.z - patio.sz / 2 >= solo.z - solo.sz / 2 + 6)
		t.ok(patio.z + patio.sz / 2 <= solo.z + solo.sz / 2 - 6)
		for _, campo in Vila.PALICADA or Vila.PALISADA or {} do t.ok(not sobrepoe(patio, campo), "colide com palicada") end
	end,
	["grade da mestra deriva da margem do lago e fica seca e fora dos predios"] = function(t)
		local grade = Layout.grade()
		t.eq(grade.sx, 24); t.eq(grade.sz, 24)
		for dx = -grade.sx / 2, grade.sx / 2, 4 do
			for dz = -grade.sz / 2, grade.sz / 2, 4 do
				t.eq(Terreno.agua(grade.x + dx, grade.z + dz), nil, "grade deve permanecer seca")
			end
		end
		for _, e in Vila.EDIFICIOS do t.ok(not sobrepoe(grade, Vila.ocupacao(e))) end
		for _, caminho in { Vila.ESTRADA, Vila.PRACA, Vila.TRILHA_FLORESTA } do t.ok(not sobrepoe(grade, caminho)) end
		t.ok(grade.x+grade.sx/2 < Povoamento.LATERAIS[1]-4, "grade inteira fora da palicada")
        local zona=Terreno.PROVACAO_AGUA
        t.eq(grade.x,zona.x-4.25); t.eq(grade.z,zona.z+4)
        local mestra=Layout.mestra()
        t.eq(mestra.x,grade.x); t.eq(mestra.z,zona.z-12)
        t.eq(Terreno.altura(mestra.x,mestra.z),0); t.eq(Layout.nivelAgua(),.6)
		for _, campo in Vila.PALICADA or Vila.PALISADA or {} do t.ok(not sobrepoe(grade, campo), "colide com palicada") end
        local cap,entrada=Layout.captacao()
        t.ok(Terreno.agua(cap.x,cap.z)~=nil,"bica deve sair do lago real")
        t.ok(math.sqrt((entrada.x-cap.x)^2+(entrada.z-cap.z)^2)<=6,"bica curta")
        t.eq(entrada.x,grade.x-10); t.eq(entrada.z,grade.z)
        local rota=Layout.acessoAgua()
        local povoamento=Povoamento.vila()
        t.eq(rota[1].x,0); t.eq(rota[1].z,-300)
        for n=2,#rota do
         local a,b=rota[n-1],rota[n]
         local passos=math.ceil(math.sqrt((b.x-a.x)^2+(b.z-a.z)^2))
         for k=0,passos do
          local x,z=a.x+(b.x-a.x)*k/passos,a.z+(b.z-a.z)*k/passos
          t.eq(Terreno.agua(x,z),nil,"acesso seco")
          for _,p in povoamento do
           if p[3]=="palicada" then
            local r=Props.retangulo(p)
            t.ok(not sobrepoe({x=x,z=z,sx=3,sz=3},r),"acesso bloqueado pela paliçada")
           end
          end
         end
        end

	end,
}
