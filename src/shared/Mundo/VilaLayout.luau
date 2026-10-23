-- Layout da vila ao sul da região inicial, em dados puros (sem Instances).
-- Coordenadas em studs no plano XZ; y=0 é o chão. O construtor físico fica em
-- server/Mundo/Vila. Retângulos são alinhados aos eixos: {x, z, sx, sz} (centro e tamanho).
local VilaLayout = {}

VilaLayout.ID = "region/vila"

-- Chão contínuo com o terreno da região inicial (que termina em z=-120).
VilaLayout.SOLO = { x = 0, z = -210, sx = 220, sz = 180 }

-- Estrada sai do acampamento (z=-44), passa pela abertura do anel de árvores
-- (x entre -24 e 25 em z=-108) e entra 2 studs na praça.
VilaLayout.ESTRADA = { x = 0, z = -98.5, sx = 10, sz = 109 }
-- Saída sul para a Floresta Sombria; termina no limite do solo em z=-350.
VilaLayout.TRILHA_FLORESTA = { x = 0, z = -325, sx = 10, sz = 50 }
VilaLayout.PLACA_FLORESTA = { x = 0, z = -296 }
VilaLayout.PRACA = { x = 0, z = -175, sx = 48, sz = 48 }
-- Ponto livre da praça, fora do chafariz; usado pelo spawn do jogador.
VilaLayout.NASCIMENTO = { x = -8, z = -175 }
-- Espelho A1: dentro da praça, fora da fonte, bancos, canteiros e vias.
VilaLayout.ESPELHO = { x = -20, z = -181, alcance = 8, modulo = "EspelhoVila" }

-- Prédios vêm de server/Mundo/Modelos (gerados no Blender: tools/gerar_modelo.py).
-- largura/profundidade: base do modelo original (eixos X/Z locais); a porta fica em +Z local.
-- porta: lado voltado à praça ("leste" = +x, "oeste" = -x, "norte" = +z, "sul" = -z).
VilaLayout.ESCALA_PREDIOS = 1
-- Prédios gerados no Blender (tools/gerar_modelo.py); largura/profundidade = caixa do modelo
-- (telhado e degraus incluídos). A porta fica em +Z local, voltada à praça.
VilaLayout.EDIFICIOS = {
	{ id = "taverna", nome = "Taverna do Caminho", modelo = "Taverna", largura = 23.7, profundidade = 18.5, x = -36.5, z = -168, porta = "leste", papel = "tavern" },
	{ id = "ferreiro", nome = "Forja", modelo = "Forja", largura = 19.7, profundidade = 15.5, x = 35.5, z = -168, porta = "oeste", papel = "smith" },
	{ id = "dojo", nome = "Dojo", modelo = "Dojo", largura = 23, profundidade = 21.3, x = 0, z = -214, porta = "norte", papel = "dojo" },
	{ id = "casa-oeste", nome = "Casa", modelo = "Casa1", largura = 13.4, profundidade = 11.1, x = -35, z = -206, porta = "leste", papel = "house" },
	{ id = "casa-leste", nome = "Casa", modelo = "Casa2", largura = 13.6, profundidade = 11.1, x = 35, z = -206, porta = "oeste", papel = "house" },
}

-- Adereços em escala 1 (base 8x8 no modelo original).
VilaLayout.BARRACAS = {
	{ id = "barraca-oeste", modelo = "MercadoListrado", x = -14, z = -144, sx = 9, sz = 7.6, porta = "leste" },
	{ id = "barraca-leste", modelo = "MercadoLiso", x = 14, z = -144, sx = 9, sz = 7.6, porta = "oeste" },
}
-- Contrato antigo de zona plana, preservado para o terreno; o objeto saiu daqui.
VilaLayout.POCO = { id = "poco", modelo = "Poco", x = 0, z = -175, sx = 8, sz = 8 }
VilaLayout.POCO_QUINTAL = { id = "poco-quintal", modelo = "PocoV2", x = -62, z = -213, sx = 8, sz = 8 }
VilaLayout.CHAFARIZ = { id = "chafariz", modelo = "Chafariz", x = 0, z = -175, sx = 10.1, sz = 10.1 }
VilaLayout.RAIO_CIRCULACAO = 4
-- Separadas de EDIFICIOS: não criam zonas planas implicitamente em TerrenoLayout.
-- O coordenador pode nivelar estes lotes (ocupação + margem 2). Até lá o montador
-- amostra o relevo e apoia cada casa numa fundação nivelada; não enterra o piso.
VilaLayout.CASAS_NOVAS = {
	{ id="sacada-oeste", nome="Casa das Flores", modelo="CasaSacada1", largura=14.9, profundidade=12.65, x=-48, z=-190, porta="leste", papel="house" },
	{ id="sacada-leste", nome="Casa do Mercador", modelo="CasaSacada1", largura=14.9, profundidade=12.65, x=48, z=-190, porta="oeste", papel="house" },
	{ id="palha-oeste", nome="Casa da Horta", modelo="CasaPalha1", largura=11, profundidade=10.65, x=-18, z=-235, porta="norte", papel="house" },
	{ id="palha-leste", nome="Casa do Lenhador", modelo="CasaPalha1", largura=11, profundidade=10.65, x=18, z=-235, porta="norte", papel="house" },
}
-- Vias adicionais não são zonas de Terrain; pedras individuais acompanham altura().
VilaLayout.ACESSOS = {
	{ id="sacada-oeste", x=-32, z=-190, sx=19.4, sz=3.2 },
	{ id="sacada-leste", x=32, z=-190, sx=19.4, sz=3.2 },
	{ id="palha-oeste", x=-18, z=-214.35, sx=3.2, sz=30.7 },
	{ id="palha-leste", x=18, z=-214.35, sx=3.2, sz=30.7 },
	{ id="mercado", x=0, z=-140, sx=8, sz=22 },
	{ id="entrada-oeste", x=-16.4, z=-131, sx=22.1, sz=3.2 },
	{ id="entrada-leste", x=16.4, z=-131, sx=22.1, sz=3.2 },
}
-- {x,z,família,escala,giro,altura opcional}. Banco: encosto -Z, assento +Z (conferido no gerador e no exportado).
VilaLayout.DECORACAO = {
	{-12,-175,"banco",1,90}, {12,-175,"banco",1,270},
	{-12,-187,"banco",1,45}, {12,-187,"banco",1,315},
	{-20,-153,"canteiro",0.6,0}, {20,-153,"canteiro",0.6,0},
	{-20,-192,"canteiro",0.6,0}, {20,-192,"canteiro",0.6,0},
	-- Mastros ±14,4, fora da estrada central; cordas acima de 12 studs.
	{0,-155,"bandeirolas",1.8,0}, {0,-195,"bandeirolas",1.8,0},
	{-8,-146,"estandarte",0.7,90}, {8,-146,"estandarte",0.7,270},
	{-8,-67,"estandarte",0.7,0}, {8,-67,"estandarte",0.7,0},
	{-8,-297,"estandarte",0.7,180}, {8,-297,"estandarte",0.7,180},
	-- Quintais: fora dos corredores que chegam às portas.
	{-75,-208,"varal",0.8,90}, {75,-208,"varal",0.8,90},
	{-63,-173,"lenha",0.8,0}, {63,-173,"lenha",0.8,180},
	{-40,-244,"canteiro",0.7,0}, {-40,-250,"canteiro",0.7,0},
	{-34,-253,"canteiro",0.7,0}, {-25,-255,"varal",0.65,0},
	{37,-253,"lenha",0.9,90}, {35,-265,"varal",0.65,0},
	-- Carga intercalada com as duas bancas da rua do mercado.
	{-16,-136,"caixotes",0.45,0}, {16,-136,"barril",0.85,0},
}

-- Pegadas que realmente alcançam a altura do avatar. Cordões só ocupam os
-- dois mastros; a corda e panos ficam acima da passagem.
function VilaLayout.pegadasDecoracao(prop, retangulo)
	if prop[3]=="bandeirolas" then
		return {{x=prop[1]-8*prop[4],z=prop[2],sx=1.3*prop[4],sz=1.3*prop[4]},
			{x=prop[1]+8*prop[4],z=prop[2],sx=1.3*prop[4],sz=1.3*prop[4]}}
	end
	return {retangulo(prop)}
end

-- Janelas térreas dos geradores casas.py/predios.py: X local, face da parede
-- em +Z e pé da jardineira. O montador refina Z pela malha Parede real.
VilaLayout.JARDINEIRAS = {
	Casa1={xs={-3.4,3.4},paredeZ=4.3,pe=0.4},
	Casa2={xs={-3.4,3.4},paredeZ=4.3,pe=0.4},
	CasaSacada1={xs={-4.25,4.25},paredeZ=4.5,pe=0.5},
	CasaPalha1={xs={2.2},paredeZ=3.6,pe=0.25},
}

-- Variação reprodutível de pintura, sem alterar a geometria/reservas de terreno.
function VilaLayout.paleta(e, semente)
	local h = math.abs(math.floor(e.x * 7 + e.z * 13 + (semente or 41636)))
	local cores = {{212,188,145},{184,197,165},{210,174,151},{185,197,204}}
	return cores[h % #cores + 1]
end

function VilaLayout.predios()
	local lista = {}
	for _, e in ipairs(VilaLayout.EDIFICIOS) do table.insert(lista,e) end
	for _, e in ipairs(VilaLayout.CASAS_NOVAS) do table.insert(lista,e) end
	return lista
end

-- Pedras soltas: duas fileiras alternadas, sem placa contínua nem RNG global.
function VilaLayout.pedras(semente)
	local lista = {}
	for i,r in ipairs(VilaLayout.ACESSOS) do
		local horizontal = r.sx > r.sz
		local n = math.floor((if horizontal then r.sx else r.sz) / 1.9)
		for j=0,n do
			local h = (j*37+i*71+(semente or 41636)) % 101
			local t = (j+0.5)/(n+1)-0.5
			local lateral = (if j%2==0 then -0.65 else 0.65) + (h/100-0.5)*0.3
			table.insert(lista,{x=r.x+(if horizontal then t*(r.sx-1.6) else lateral),
				z=r.z+(if horizontal then lateral else t*(r.sz-1.6)),sx=1.1+h/250,sz=0.85+h/350,giro=h%31-15,acesso=r.id})
		end
	end
	return lista
end

-- Postes de luz nos cantos da praça.
VilaLayout.POSTES = {
	{ x = -26, z = -149 }, { x = 26, z = -149 }, { x = -26, z = -201 }, { x = 26, z = -201 },
}

-- Árvores na borda da vila: {x, z, escala}. Copa ocupa raio 5.5 * escala.
VilaLayout.ARVORES = {
	{ -95, -140, 1.1 }, { -97, -185, 1.2 }, { -94, -230, 1 }, { -80, -275, 1.2 },
	{ 95, -140, 1.2 }, { 97, -188, 1 }, { 94, -232, 1.1 }, { 78, -275, 1.2 },
	{ -35, -282, 1 }, { 35, -282, 1.1 }, { 0, -290, 1 },
}

VilaLayout.DISTANCIA_MAX_PORTA = 14

local ANGULO = { norte = 0, leste = math.pi / 2, sul = math.pi, oeste = -math.pi / 2 }

-- Giro em Y que leva o +Z local do modelo para o lado da porta.
function VilaLayout.angulo(edificio)
	return ANGULO[edificio.porta] or 0
end

-- Pegada visual dos mercados novos, separada da antiga reserva de solo.
-- BARRACAS.sx/sz permanecem estáveis porque o terreno os consome.
function VilaLayout.pegadaBarraca(b)
	local lateral=b.porta=="leste" or b.porta=="oeste"
	return {id=b.id,x=b.x,z=b.z,sx=if lateral then 8 else 9.4,sz=if lateral then 9.4 else 8}
end

-- Área ocupada no mundo, já girada e escalada.
function VilaLayout.ocupacao(e)
	if e.largura == nil then return e end
	local escala = e.escala or VilaLayout.ESCALA_PREDIOS
	local w, d = e.largura * escala, e.profundidade * escala
	local deitado = e.porta == "leste" or e.porta == "oeste"
	return { id = e.id, x = e.x, z = e.z, sx = if deitado then d else w, sz = if deitado then w else d }
end

function VilaLayout.porta(edificio)
	local o = VilaLayout.ocupacao(edificio)
	local dx, dz = 0, 0
	if edificio.porta == "leste" then dx = o.sx / 2
	elseif edificio.porta == "oeste" then dx = -o.sx / 2
	elseif edificio.porta == "norte" then dz = o.sz / 2
	elseif edificio.porta == "sul" then dz = -o.sz / 2 end
	return { x = edificio.x + dx, z = edificio.z + dz }
end

function VilaLayout.sobrepoe(a, b)
	return math.abs(a.x - b.x) < (a.sx + b.sx) / 2 and math.abs(a.z - b.z) < (a.sz + b.sz) / 2
end

function VilaLayout.contem(fora, dentro)
	return math.abs(dentro.x - fora.x) + dentro.sx / 2 <= fora.sx / 2
		and math.abs(dentro.z - fora.z) + dentro.sz / 2 <= fora.sz / 2
end

-- Distância de um ponto à borda de um retângulo (0 se dentro).
function VilaLayout.distancia(ponto, ret)
	local dx = math.max(math.abs(ponto.x - ret.x) - ret.sx / 2, 0)
	local dz = math.max(math.abs(ponto.z - ret.z) - ret.sz / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function arvoreRet(a, i)
	local r = 5.5 * a[3]
	return { id = "arvore-" .. i, x = a[1], z = a[2], sx = r * 2, sz = r * 2 }
end

-- Lista de problemas do layout; vazia quando consistente.
function VilaLayout.validar()
	local problemas = {}
	local ocupados = {}
	for _, e in ipairs(VilaLayout.predios()) do table.insert(ocupados, VilaLayout.ocupacao(e)) end
	table.insert(ocupados,VilaLayout.POCO_QUINTAL)
	for _, b in ipairs(VilaLayout.BARRACAS) do table.insert(ocupados, VilaLayout.pegadaBarraca(b)) end
	for i, a in ipairs(VilaLayout.ARVORES) do table.insert(ocupados, arvoreRet(a, i)) end
	for i, a in ipairs(ocupados) do
		if not VilaLayout.contem(VilaLayout.SOLO, a) then
			table.insert(problemas, a.id .. " fora do solo")
		end
		for _, livre in ipairs({ VilaLayout.ESTRADA, VilaLayout.PRACA, VilaLayout.TRILHA_FLORESTA }) do
			if VilaLayout.sobrepoe(a, livre) then table.insert(problemas, a.id .. " bloqueia caminho") end
		end
		for j = i + 1, #ocupados do
			if VilaLayout.sobrepoe(a, ocupados[j]) then
				table.insert(problemas, a.id .. " sobrepoe " .. ocupados[j].id)
			end
		end
	end
	for _, e in ipairs(VilaLayout.EDIFICIOS) do
		if VilaLayout.distancia(VilaLayout.porta(e), VilaLayout.PRACA) > VilaLayout.DISTANCIA_MAX_PORTA then
			table.insert(problemas, e.id .. " porta longe da praca")
		end
	end
	return problemas
end

return VilaLayout
