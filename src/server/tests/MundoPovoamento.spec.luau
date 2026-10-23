local Shared = game:GetService("ReplicatedStorage").Shared
local P = require(Shared.Mundo.PropsLayout)
local F = require(Shared.Mundo.FlorestaLayout)
local R = require(Shared.Mundo.RegiaoLayout)
local U = require(Shared.Mundo.RuinasLayout)
local M = require(Shared.Mundo.PropsPovoamento)
local V = require(Shared.Mundo.VilaLayout)
local T = require(Shared.Mundo.TerrenoLayout)
local Treinadores = require(Shared.Mundo.TreinadoresLayout)
local pecas = {
	["Banco"]=5,
	["Canteiro"]=10,
	["Jardineira"]=11,
	["Varal"]=11,
	["Lenha"]=8,
	["Bandeirolas1"]=7,
	["Bandeirolas2"]=7,
	["Bandeirolas3"]=7,
	["Estandarte1"]=6,
	["Estandarte2"]=6,
	["Estandarte3"]=6,
	["CasaSacada1"]=16,
	["CasaPalha1"]=12,
	["MercadoLiso"]=11,
	["MercadoListrado"]=12,
	["PocoV2"]=18,
	["Chafariz"]=4,
	["AbetoSombrio1"]=3,
	["AbetoSombrio2"]=3,
	["AbetoSombrio3"]=3,
	["Altar"]=4,
	["Arbusto1"]=2,
	["Arbusto2"]=2,
	["ArbustoFlor1"]=3,
	["Arco"]=4,
	["ArvoreMorta1"]=1,
	["ArvoreMorta2"]=1,
	["ArvoreMorta3"]=1,
	["Barraca"]=6,
	["Barril"]=1,
	["Caixotes"]=4,
	["Carroca"]=5,
	["CarvalhoAntigo1"]=5,
	["CarvalhoAntigo2"]=6,
	["CarvalhoB1"]=3,
	["CarvalhoB2"]=3,
	["CarvalhoB3"]=3,
	["CarvalhoB4"]=3,
	["Casa1"]=8,
	["Casa2"]=8,
	["Casa3"]=8,
	["CercaRipas"]=1,
	["CercaTrilhos"]=1,
	["Cogumelos1"]=6,
	["CogumelosLuz1"]=4,
	["Coluna1"]=3,
	["Coluna2"]=3,
	["ColunaHera1"]=6,
	["ColunaHera2"]=6,
	["ColunaQuebrada1"]=3,
	["ColunaQuebrada2"]=3,
	["Dojo"]=9,
	["EscadaQuebrada"]=3,
	["Fardo1"]=2,
	["Flores1"]=6,
	["Flores2"]=6,
	["Flores3"]=6,
	["Forja"]=8,
	["Juncos1"]=4,
	["Lampiao"]=3,
	["Lapide1"]=3,
	["Lapide2"]=3,
	["Loja"]=496,
	["Muro1"]=3,
	["Muro2"]=3,
	["Palicada"]=6,
	["Pinheiro1"]=2,
	["Pinheiro2"]=2,
	["Pinheiro3"]=2,
	["Pinheiro4"]=2,
	["Pinheiro5"]=2,
	["Placa1"]=2,
	["Poco"]=11,
	["Ponte"]=5,
	["Portao"]=6,
	["Rocha1"]=2,
	["Rocha2"]=2,
	["Rocha3"]=2,
	["Rochedo1"]=3,
	["Rochedo2"]=3,
	["Samambaia1"]=2,
	["Samambaia2"]=2,
	["Taverna"]=11,
	["Tenda1"]=3,
	["Tenda2"]=3,
	["Tenda3"]=3,
	["Toco1"]=3,
	["Tora1"]=3,
	["Tora2"]=3,
	["ToraMusgo1"]=5,
	["Tripe1"]=2,
	["TufoGrama1"]=2,
	["TufoGrama2"]=3,
}
local function contar(p,lista)
 local n=0
 for _,a in ipairs(lista) do n+=pecas[p.modelo(a[3],a[1],a[2])] end
 return n
end

local function familias(lista)
 local c={}
 for _,p in ipairs(lista) do c[p[3]]=(c[p[3]] or 0)+1 end
 return c
end
local function iguais(t,a,b)
 t.eq(#a,#b)
 for i,p in ipairs(a) do for j=1,5 do t.eq(p[j],b[i][j],"determinismo "..i..":"..j) end end
end
return {
 ["V6 vila completa cabe no alvo de 3500 pecas"] = function(t)
  local n=contar(P,M.vila())+contar(P,V.DECORACAO)+#V.pedras()+pecas.Chafariz+pecas.PocoV2
  for _,e in ipairs(V.EDIFICIOS) do n+=pecas[e.modelo]+1 end
  for _,e in ipairs(V.CASAS_NOVAS) do n+=pecas[e.modelo]+2 end -- entrada e fundacao
  for _,e in ipairs(V.BARRACAS) do n+=pecas[e.modelo] end
  n+=#V.POSTES*2+#V.ARVORES*3+3 -- placa/poste e spawn
  n+=10*pecas.Jardineira -- limite conservador (8 atuais)
  print("V6 inventario conservador",n,"pedras",#V.pedras())
  t.ok(n<3500,"vila completa "..n)
 end,
 ["familias exportadas e orçamento de MeshParts"] = function(t)
  for nome,f in pairs(P.FAMILIAS) do for _,m in ipairs(f.modelos) do if not f.opcional then t.ok(pecas[m]~=nil,nome.." "..m) end end end
  local floresta=contar(P,P.floresta())
  t.ok(floresta+47<4000,"floresta incl grade/marco/obstaculos "..floresta)
  t.ok(contar(P,R.campo())<1400)
 end,
 ["mata deterministica com folga de camera e copas entrelacadas"] = function(t)
  local a=P.floresta(); iguais(t,a,P.floresta())
  t.ok(#F.ARVORES>=300)
  local c=familias(a); t.ok(c.abeto>c.carvalhoantigo*2)
  for i,ar in ipairs(F.ARVORES) do
   local ret=F.arvoreRetangulo(ar,i)
   for _,z in ipairs({F.TRILHA,F.CLAREIRA}) do
    t.ok(not F.sobrepoe(ret,{x=z.x,z=z.z,sx=z.sx+12,sz=z.sz+12}),"copa na zona "..i)
   end
   for j=1,i-1 do
    local o=F.ARVORES[j]
    t.ok((ar[1]-o[1])^2+(ar[2]-o[2])^2>=64,"troncos a menos de 8 studs")
   end
  end
 end,
 ["camada baixa sombreada e cogumelos luminosos raros perto da clareira"] = function(t)
  local c=familias(P.floresta())
  t.ok(c.samambaia>=80,"samambaias "..c.samambaia); t.ok(c.cogumelos>=20,"cogumelos "..c.cogumelos); t.ok(c.toramusgo>=10,"toras "..c.toramusgo); t.ok(c.rochedo>=4,"rochedos "..c.rochedo)
  t.ok((c.cogumelosluz or 0)>0 and c.cogumelosluz<12,"luminosos "..tostring(c.cogumelosluz))
  for _,p in ipairs(P.floresta()) do
   if p[3]=="cogumelosluz" then t.ok(math.abs(p[1])<52 and math.abs(p[2]+485)<45) end
  end
 end,
 ["campo acrescenta flores tufos e rochedos sem invadir zonas"] = function(t)
  local a=R.campo(); iguais(t,a,R.campo()); local c=familias(a)
  t.ok(c.flores>=60 and c.tufo>=60 and (c.rochedo or 0)>0,"flores/tufo/rochedo "..tostring(c.flores).."/"..tostring(c.tufo).."/"..tostring(c.rochedo))
  for _,p in ipairs(a) do
   local r=P.retangulo(p)
   t.ok(not R.proibido(p[1],p[2],math.max(r.sx,r.sz)/2+1),"campo "..p[3])
  end
 end,
 ["vila tem flores lampioes e carga longe das portas"] = function(t)
  local a=M.vila(); iguais(t,a,M.vila()); local c=familias(a)
  t.ok((c.lampiao or 0)>=6,"lampioes "..(c.lampiao or 0))
  t.ok((c.carroca or 0)>=1 and (c.caixotes or 0)>=1,"carga")
  t.ok(c.flores>=70 and c.tufo>=70)
  for _,p in ipairs(a) do
   if p[3]=="flores" or p[3]=="tufo" or p[3]=="lampiao" or p[3]=="carroca" or p[3]=="caixotes" then
    for _,e in ipairs(V.EDIFICIOS) do t.ok(V.distancia(V.porta(e),P.retangulo(p))>=V.DISTANCIA_MAX_PORTA,p[3].." na porta "..e.id) end
   end
  end
 end,
 ["juncos consultam agua na margem sem ocupar zonas planas nem lago"] = function(t)
  local c=familias(M.vila()); t.ok((c.juncos or 0)>=12,"juncos "..(c.juncos or 0))
  for _,p in ipairs(M.vila()) do
   t.ok(M.seco(p),"prop dentro da agua")
   t.ok(p[3]~="ponte")
   if p[3]=="juncos" then t.ok(M.margem(p));t.eq(M.zonaPlana(p),nil) end
  end
  t.eq(#M.caminhosAlagados(),0,"registrar cruzamento antes de adicionar ponte")
 end,
 ["ruinas misturam hera e escadas fora da camara e do caminho"] = function(t)
  local a=U.pecas(); iguais(t,a,U.pecas());local c=familias(a)
  t.ok((c.colunahera or 0)>=4 and (c.escada or 0)>=1)
  for _,p in ipairs(a) do
   if p[3]=="colunahera" or p[3]=="escada" then
    local r=P.retangulo(p)
    t.ok(not V.sobrepoe(r,U.CAMINHO))
    t.ok(not V.sobrepoe(r,{x=U.CAMARA.x,z=U.CAMARA.z,sx=U.CAMARA.raio*2+4,sz=U.CAMARA.raio*2+4}))
   end
  end
 end,
 ["cercado fecha contorno com apenas dois portoes e nao corta zonas ou agua"] = function(t)
  local norte=M.PORTAO_NORTE
  local lista=M.cercado(norte); iguais(t,lista,M.cercado(norte))
  t.eq(familias(lista).portao,2)
  for _,p in ipairs(lista) do
   if p[3]=="palicada" then t.eq(M.zonaPlana(p),nil,"paliçada na zona");t.ok(M.seco(p),"paliçada na agua") end
  end
  local function fechado(x,z)
   for _,p in ipairs(lista) do
    if p[3]=="portao" then
     if math.abs(x)<5.31 and math.abs(z-p[2])<0.01 then return false end
    end
    local r=P.retangulo(p)
    if math.abs(x-r.x)<=r.sx/2+0.01 and math.abs(z-r.z)<=r.sz/2+0.01 then return true end
   end
   return false
  end
  for x=M.LATERAIS[1],M.LATERAIS[2],0.5 do
   for _,z in ipairs({norte,-300}) do t.eq(fechado(x,z),math.abs(x)>=5.31,"fechamento horizontal "..x) end
  end
  for z=-300,norte,0.5 do for _,x in ipairs(M.LATERAIS) do t.ok(fechado(x,z),"fresta lateral") end end
  t.eq(lista[1][5],180); t.eq(lista[2][5],0)
 end,
 ["povoamento preserva areas T1 com folga e acesso a pe"] = function(t)
  local zonas={Treinadores.PATIO,Treinadores.LADINO,Treinadores.grade(),Treinadores.mestra()}
  local vila=M.vila()
  for _,p in ipairs(vila) do
   local r=P.retangulo(p)
   for _,z in ipairs(zonas) do
    t.ok(not V.sobrepoe(r,{x=z.x,z=z.z,sx=z.sx+M.FOLGA_TREINADORES*2,sz=z.sz+M.FOLGA_TREINADORES*2}),"prop/cerca invade zona T1: "..p[3])
   end
  end
  -- O pátio fica dentro do cercado e se alcança pelo portão sul; a margem da Mestra
  -- fica fora do cercado, ligada ao espaço aberto pelo portão norte/lateral.
  local cercado=vila
  local function bloqueado(x,z)
   for _,p in ipairs(cercado) do
    if p[3]=="palicada" then
     local r=P.retangulo(p)
     if math.abs(x-r.x)<r.sx/2+0.5 and math.abs(z-r.z)<r.sz/2+0.5 then return true end
    end
   end
   return false
  end
  local patio=Treinadores.PATIO
  t.ok(not bloqueado(patio.x,patio.z),"centro do patio livre")
  local rotaPatio=true
  -- Sai do pátio pelo corredor interno e cruza a abertura sul (x=0).
  for x=patio.x,0,-1 do if bloqueado(x,-290) then rotaPatio=false end end
  for z=-290,-299,-1 do if bloqueado(0,z) then rotaPatio=false end end
  t.ok(rotaPatio,"rota do patio ao portao sul")
  local mestra=Treinadores.mestra()
  t.ok(not bloqueado(mestra.x,mestra.z),"centro da Mestra livre")
  local caminhoMestra=true
  local xExterior=M.LATERAIS[1]-6
  for x=mestra.x,xExterior,-1 do if bloqueado(x,mestra.z) then caminhoMestra=false end end
  t.ok(caminhoMestra,"passagem lateral livre da Mestra")
 end,
 ["inventario por regiao cresce dentro dos limites"] = function(t)
  -- Baseline V3: vila75, floresta324 (incluindo pinheiros), campo218, ruinas289.
  local a={contar(P,M.vila()),contar(P,P.floresta()),contar(P,R.campo()),contar(P,U.pecas())}
  local antes={75,324,218,289}; local limites={2300,3953,1400,500}
  for i,n in ipairs(a) do t.ok(n>antes[i] and n<limites[i],"inventario "..i.." = "..n) end
 end,
}
