local function pecas(ids, slot, modulo, parte, offset, raridade)
	local r = {}
	for _, id in ids do r[id] = { nome = id, raridade = raridade or "basica", slot = slot, modulo = modulo, encaixe = { parte = parte, offset = offset or { x = 0, y = 0, z = 0 } } } end
	return r
end
local CORES = {
	PeleClara={225,188,150}, PeleMedia={178,123,85}, PeleEscura={92,58,42}, PeleOliva={166,132,88}, PeleAzul={82,145,178}, PeleVerde={102,145,86}, PeleVioleta={148,104,166}, PeleCinza={128,128,128}, PeleAzeviche={24,20,22},
	OlhoCastanho={92,55,32}, OlhoAzul={60,145,220}, OlhoVerde={75,170,105}, OlhoVioleta={150,90,210}, OlhoVermelho={195,60,55}, OlhoDourado={220,175,50}, OlhoNegro={25,25,30}, OlhoTurquesa={45,190,180},
	CabeloPreto={28,25,30}, CabeloCastanho={95,56,35}, CabeloLoiro={230,195,105}, CabeloRuivo={180,75,40}, CabeloBranco={230,230,220}, CabeloPrata={200,206,218}, CabeloAzul={55,115,200}, CabeloVerde={55,150,85}, CabeloRosa={220,115,165}, CamisaVermelha={170,55,55}, CamisaAzul={55,90,160}, CamisaVerde={65,125,75}, CamisaPreta={35,35,40}, CamisaBranca={225,220,205}, CamisaRoxa={115,65,145}, CalcaMarrom={95,65,45}, CalcaPreta={35,35,40}, CalcaAzul={45,65,110}, CalcaCinza={110,110,115},
}
-- Coordenadas puras na face -Z, cabeça de referência 2x1x1.
-- B(x,y,largura,altura,papel[,z,profundidade]); todos os elementos são cuboides.
local function B(x,y,sx,sy,papel,z,sz)
 return { tamanho={x=sx,y=sy,z=sz or 0.04},posicao={x=x,y=y,z=z or -0.525},papel=papel }
end
local function par(sx,sy,iris)
 local b={B(-0.45,0.12,sx,sy,"olho"),B(0.45,0.12,sx,sy,"olho")}
 if iris then
  table.insert(b,B(-0.45,0.12,0.10,math.min(sy,0.15),"iris",-0.555))
  table.insert(b,B(0.45,0.12,0.10,math.min(sy,0.15),"iris",-0.555))
 end
 return b
end
local ROSTO={olhos={},sobrancelhas={},nariz={},boca={}}
ROSTO.olhos.OlhoQuadrado=par(0.30,0.26,true)
ROSTO.olhos.OlhoRetangular=par(0.38,0.18,true)
ROSTO.olhos.OlhoFechado={B(-0.45,0.13,0.32,0.035,"boca"),B(0.45,0.13,0.32,0.035,"boca")}
ROSTO.olhos.OlhoFeliz={B(-0.45,0.19,0.18,0.035,"boca"),B(-0.57,0.14,0.06,0.10,"boca"),B(-0.33,0.14,0.06,0.10,"boca"),B(0.45,0.19,0.18,0.035,"boca"),B(0.57,0.14,0.06,0.10,"boca"),B(0.33,0.14,0.06,0.10,"boca")}
ROSTO.olhos.OlhoBravo=par(0.34,0.16,true)
table.insert(ROSTO.olhos.OlhoBravo,B(-0.32,0.19,0.12,0.12,"peleEscura",-0.58))
table.insert(ROSTO.olhos.OlhoBravo,B(0.32,0.19,0.12,0.12,"peleEscura",-0.58))
ROSTO.olhos.OlhoSonolento=par(0.34,0.09,true)
ROSTO.olhos.OlhoBrilho=par(0.32,0.27,true)
table.insert(ROSTO.olhos.OlhoBrilho,B(-0.48,0.17,0.055,0.055,"dente",-0.58))
table.insert(ROSTO.olhos.OlhoBrilho,B(0.42,0.17,0.055,0.055,"dente",-0.58))
ROSTO.olhos.OlhoUmDeCada={B(-0.45,0.12,0.30,0.26,"olho"),B(-0.45,0.12,0.1,0.15,"iris",-0.555),B(0.45,0.12,0.38,0.08,"iris")}
ROSTO.olhos.OlhoCilios=par(0.34,0.22,true)
for _,x in {-0.62,-0.45,-0.28,0.28,0.45,0.62} do table.insert(ROSTO.olhos.OlhoCilios,B(x,0.28,0.035,0.12,"boca")) end
ROSTO.sobrancelhas.SobrancelhaReta={B(-0.45,0.34,0.36,0.045,"peleEscura"),B(0.45,0.34,0.36,0.045,"peleEscura")}
ROSTO.sobrancelhas.SobrancelhaGrossa={B(-0.45,0.34,0.38,0.09,"peleEscura"),B(0.45,0.34,0.38,0.09,"peleEscura")}
ROSTO.sobrancelhas.SobrancelhaFina={B(-0.45,0.34,0.38,0.025,"peleEscura"),B(0.45,0.34,0.38,0.025,"peleEscura")}
ROSTO.sobrancelhas.SobrancelhaCurta={B(-0.45,0.34,0.18,0.055,"peleEscura"),B(0.45,0.34,0.18,0.055,"peleEscura")}
ROSTO.sobrancelhas.SobrancelhaArqueada={B(-0.45,0.37,0.18,0.04,"peleEscura"),B(-0.60,0.33,0.12,0.04,"peleEscura"),B(-0.30,0.33,0.12,0.04,"peleEscura"),B(0.45,0.37,0.18,0.04,"peleEscura"),B(0.60,0.33,0.12,0.04,"peleEscura"),B(0.30,0.33,0.12,0.04,"peleEscura")}
ROSTO.sobrancelhas.SobrancelhaSeria={B(-0.56,0.36,0.18,0.055,"peleEscura"),B(-0.36,0.30,0.18,0.055,"peleEscura"),B(0.56,0.36,0.18,0.055,"peleEscura"),B(0.36,0.30,0.18,0.055,"peleEscura")}
ROSTO.nariz.NarizNenhum={}
ROSTO.nariz.NarizPequeno={B(0,-0.07,0.10,0.08,"peleEscura",-0.55,0.08)}
ROSTO.nariz.NarizReto={B(0,-0.03,0.10,0.20,"peleEscura",-0.57,0.12)}
ROSTO.nariz.NarizLargo={B(0,-0.09,0.28,0.10,"peleEscura",-0.56,0.10)}
ROSTO.nariz.NarizDegrau={B(0,-0.02,0.10,0.14,"peleEscura",-0.55,0.08),B(0,-0.10,0.18,0.08,"peleEscura",-0.60,0.12)}
ROSTO.boca.BocaReta={B(0,-0.29,0.44,0.035,"boca")}
ROSTO.boca.BocaSorriso={B(0,-0.32,0.36,0.045,"boca"),B(-0.23,-0.27,0.08,0.10,"boca"),B(0.23,-0.27,0.08,0.10,"boca")}
ROSTO.boca.BocaAberta={B(0,-0.28,0.28,0.21,"boca")}
ROSTO.boca.BocaDentes={B(0,-0.28,0.48,0.18,"boca"),B(0,-0.25,0.40,0.065,"dente",-0.56)}
ROSTO.boca.BocaBigode={B(0,-0.31,0.30,0.03,"boca"),B(-0.19,-0.23,0.30,0.07,"peleEscura"),B(0.19,-0.23,0.30,0.07,"peleEscura")}
ROSTO.boca.BocaTriste={B(0,-0.24,0.30,0.04,"boca"),B(-0.19,-0.29,0.08,0.10,"boca"),B(0.19,-0.29,0.08,0.10,"boca")}
ROSTO.boca.BocaPresas={B(0,-0.27,0.44,0.13,"boca"),B(-0.14,-0.29,0.08,0.14,"dente",-0.56),B(0.14,-0.29,0.08,0.14,"dente",-0.56)}
ROSTO.boca.BocaPequena={B(0,-0.29,0.15,0.06,"boca")}
local PECAS={}
for id,v in pecas({"RoupaTunica1"},"corpo",nil,"UpperTorso") do PECAS[id]=v end
for id,v in pecas({"RoupaCapuz1"},"cabeca",nil,"Head") do PECAS[id]=v end
for id,v in pecas({"RoupaCinto1"},"cintura",nil,"LowerTorso") do PECAS[id]=v end
for id,v in pecas({"RoupaBotas1"},"pes",nil,"LeftFoot") do PECAS[id]=v end
local raras={
	{"LadinoCapuz","cabeca","Head",{x=0,y=0,z=0}}, {"LadinoMascara","rosto","Head",{x=0,y=0,z=0}}, {"LadinoCapa","costas","UpperTorso",{x=0,y=0.8,z=0.5}}, {"LadinoCinto","cintura","LowerTorso",{x=0,y=0,z=0}},
	{"MestraTiara","cabeca","Head",{x=0,y=0,z=0}}, {"MestraManto","costas","UpperTorso",{x=0,y=0.8,z=0.5}}, {"MestraObi","cintura","LowerTorso",{x=0,y=0,z=0}}, {"MestraCajado","mao","RightHand",{x=0,y=-0.1,z=-0.3}},
}
for id, p in PECAS do p.modulo = id end
for _, e in raras do PECAS[e[1]]={nome=e[1],raridade="rara",slot=e[2],modulo=e[1],encaixe={parte=e[3],offset=e[4]}} end
local CABELOS=pecas({"CabeloCurto1","CabeloLongo1","CabeloTrancado1","CabeloNenhum"},"cabelo",nil,"Head")
local BARBAS=pecas({"Barba1","BarbaLonga1","BarbaNenhum"},"barba",nil,"Head")
for id,p in CABELOS do p.modulo=if id=="CabeloNenhum" then nil else id end
for id,p in BARBAS do p.modulo=if id=="BarbaNenhum" then nil else id end
local MODULOS={OrelhasElficas={"cabeca","Head"},OrelhasBestiais={"cabeca","Head"},AsasCelestial={"costas","UpperTorso"},CaudaSuperd={"costas","LowerTorso"},ChifresOgro={"cabeca","Head"},}
for id,v in MODULOS do PECAS[id]={nome=id,raridade="basica",slot=v[1],racial=true,modulo=id,encaixe={parte=v[2],offset={x=0,y=0,z=0}}} end
-- Um único módulo de bota é instanciado em cada pé, com soldas independentes.
PECAS.RoupaBotas1.encaixes={{parte="LeftFoot",offset={x=0,y=0,z=0}},{parte="RightFoot",offset={x=0,y=0,z=0}}}
for id, nome in {
	LadinoCapuz="Capuz do Ladino", LadinoMascara="Máscara do Ladino", LadinoCapa="Capa do Ladino", LadinoCinto="Cinto do Ladino",
	MestraTiara="Tiara da Mestra", MestraManto="Manto da Mestra", MestraObi="Obi da Mestra", MestraCajado="Cajado da Mestra",
	RoupaTunica1="Túnica básica", RoupaCapuz1="Capuz simples", RoupaCinto1="Cinto simples", RoupaBotas1="Botas simples",
} do PECAS[id].nome = nome end
-- Rótulos de apresentação: IDs públicos de persistência/rede permanecem intactos.
local NOMES_ROSTO = {
	OlhoQuadrado="Olhos quadrados", OlhoRetangular="Olhos estreitos", OlhoFechado="Olhos fechados",
	OlhoFeliz="Olhos sorridentes", OlhoBravo="Olhar bravo", OlhoSonolento="Olhos sonolentos",
	OlhoBrilho="Olhos brilhantes", OlhoUmDeCada="Olhos diferentes", OlhoCilios="Olhos com cílios",
	SobrancelhaReta="Sobrancelhas retas", SobrancelhaGrossa="Sobrancelhas grossas", SobrancelhaFina="Sobrancelhas finas",
	SobrancelhaCurta="Sobrancelhas curtas", SobrancelhaArqueada="Sobrancelhas arqueadas", SobrancelhaSeria="Sobrancelhas sérias",
	NarizNenhum="Sem nariz marcado", NarizPequeno="Nariz pequeno", NarizReto="Nariz reto", NarizLargo="Nariz largo", NarizDegrau="Nariz curvo",
	BocaReta="Boca neutra", BocaSorriso="Sorriso", BocaAberta="Boca aberta", BocaDentes="Sorriso com dentes",
	BocaBigode="Bigode", BocaTriste="Boca triste", BocaPresas="Presas", BocaPequena="Boca pequena",
}
for categoria in ROSTO do
	NOMES_ROSTO[categoria] = NOMES_ROSTO[categoria] or {}
	for id in ROSTO[categoria] do
		NOMES_ROSTO[categoria][id] = NOMES_ROSTO[id] or id
		NOMES_ROSTO[id] = nil
	end
end
local NOMES_ESTILO = {
	CabeloCurto1="Cabelo curto", CabeloLongo1="Cabelo longo", CabeloTrancado1="Cabelo trançado", CabeloNenhum="Sem cabelo",
	Barba1="Barba curta", BarbaLonga1="Barba longa", BarbaNenhum="Sem barba",
}
for id, nome in NOMES_ESTILO do
	local item = CABELOS[id] or BARBAS[id]
	if item then item.nome = nome end
end
local NOMES_CORES = {
	PeleClara="Pele clara", PeleMedia="Pele morena", PeleEscura="Pele escura", PeleOliva="Pele oliva",
	PeleAzul="Pele azul", PeleVerde="Pele verde", PeleVioleta="Pele violeta", PeleCinza="Pele cinzenta", PeleAzeviche="Pele azeviche",
	OlhoCastanho="Castanhos", OlhoAzul="Azuis", OlhoVerde="Verdes", OlhoVioleta="Violetas", OlhoVermelho="Vermelhos", OlhoDourado="Dourados", OlhoNegro="Negros", OlhoTurquesa="Turquesa",
	CabeloPreto="Preto", CabeloCastanho="Castanho", CabeloLoiro="Loiro", CabeloRuivo="Ruivo", CabeloBranco="Branco", CabeloPrata="Prateado", CabeloAzul="Azul", CabeloVerde="Verde", CabeloRosa="Rosa",
	CamisaVermelha="Vermelha", CamisaAzul="Azul", CamisaVerde="Verde", CamisaPreta="Preta", CamisaBranca="Branca", CamisaRoxa="Roxa",
	CalcaMarrom="Marrom", CalcaPreta="Preta", CalcaAzul="Azul", CalcaCinza="Cinza",
}
local NOMES_PECAS = {
	OrelhasElficas="Orelhas élficas", OrelhasBestiais="Orelhas bestiais", AsasCelestial="Asas celestiais",
	CaudaSuperd="Cauda de superd", ChifresOgro="Chifres de ogro",
}
local NOMES = { ROSTO=NOMES_ROSTO, CORES=NOMES_CORES, ESTILOS=NOMES_ESTILO, PECAS=NOMES_PECAS }
return { CORES=CORES, PECAS=PECAS, CABELOS=CABELOS, BARBAS=BARBAS, ROSTO=ROSTO, NOMES=NOMES }
