-- Posições dos adereços de cenário (barris, cercas, arbustos, rochas) da vila e da
-- Floresta Sombria, em dados puros. Os modelos prontos ficam em server/Mundo/Modelos e
-- são montados por server/Mundo/Props. Nada aqui bloqueia estrada, trilha, clareira,
-- prédios ou árvores; `validar` confere isso (spec MundoProps).
local Shared = game:GetService("ReplicatedStorage").Shared
local VilaLayout = require(Shared.Mundo.VilaLayout)
local FlorestaLayout = require(Shared.Mundo.FlorestaLayout)

local PropsLayout = {}

-- `modelos`: variantes de Mundo/Modelos (escolhidas por posição, iguais em todo servidor);
-- `base` = maior tamanho (x, z) entre elas em escala 1; `escala` = escala-base.
-- `cor` (opcional, RGB) repinta as peças. Modelos Blender: tools/gerar_modelo.py.
PropsLayout.FAMILIAS = {
	-- V6: uploads progressivos, presença conferida por MontarModelo.existe.
	banco = {modelos={"Banco"},base={6,2.5},escala=1,opcional=true},
	canteiro = {modelos={"Canteiro"},base={6,4},escala=1,opcional=true},
	jardineira = {modelos={"Jardineira"},base={4.4,1.5},escala=1,opcional=true},
	varal = {modelos={"Varal"},base={14.2,3.9},escala=1,opcional=true},
	lenha = {modelos={"Lenha"},base={8.2,4.6},escala=1,opcional=true},
	bandeirolas = {modelos={"Bandeirolas1","Bandeirolas2","Bandeirolas3"},base={17.3,1.3},escala=1,opcional=true},
	estandarte = {modelos={"Estandarte1","Estandarte2","Estandarte3"},base={4,2},escala=1,opcional=true},
	abeto = { modelos = { "AbetoSombrio1", "AbetoSombrio2", "AbetoSombrio3" }, base = { 13.202, 14.354 }, escala = 1 },
	carvalhoantigo = { modelos = { "CarvalhoAntigo1", "CarvalhoAntigo2" }, base = { 21.765, 20.956 }, escala = 1 },
	samambaia = { colide = false, modelos = { "Samambaia1", "Samambaia2" }, base = { 6.331, 6.082 }, escala = 1 },
	cogumelos = { colide = false, modelos = { "Cogumelos1" }, base = { 3.631, 3.94 }, escala = 1 },
	cogumelosluz = { colide = false, modelos = { "CogumelosLuz1" }, base = { 4.0, 4.271 }, escala = 1 },
	toramusgo = { modelos = { "ToraMusgo1" }, base = { 12.945, 4.567 }, escala = 1 },
	tufo = { colide = false, modelos = { "TufoGrama1", "TufoGrama2" }, base = { 6.458, 6.668 }, escala = 1 },
	flores = { colide = false, modelos = { "Flores1", "Flores2", "Flores3" }, base = { 4.933, 4.974 }, escala = 1 },
	juncos = { colide = false, modelos = { "Juncos1" }, base = { 5.462, 5.463 }, escala = 1 },
	rochedo = { modelos = { "Rochedo1", "Rochedo2" }, base = { 13.152, 10.745 }, escala = 1 },
	lampiao = { modelos = { "Lampiao" }, base = { 3.258, 1.9 }, escala = 1 },
	carroca = { modelos = { "Carroca" }, base = { 8.904, 4.77 }, escala = 1 },
	caixotes = { modelos = { "Caixotes" }, base = { 9.242, 2.91 }, escala = 1 },
	ponte = { modelos = { "Ponte" }, base = { 24.1, 9.1 }, escala = 1 },
	palicada = { modelos = { "Palicada" }, base = { 9.023, 1.866 }, escala = 1 },
	portao = { modelos = { "Portao" }, base = { 10.5, 4.572 }, escala = 1 },
	colunahera = { modelos = { "ColunaHera1", "ColunaHera2" }, base = { 6.237, 5.374 }, escala = 1 },
	escada = { modelos = { "EscadaQuebrada" }, base = { 12.256, 11.262 }, escala = 1 },
	barril = { modelos = { "Barril" }, base = { 2.8, 2.8 }, escala = 1 },
	cerca = { modelos = { "CercaTrilhos", "CercaRipas" }, base = { 4.5, 0.5 }, escala = 1 },
	arbusto = { modelos = { "Arbusto1", "Arbusto2", "ArbustoFlor1" }, base = { 3.5, 3.5 }, escala = 1 },
	rocha = { modelos = { "Rocha1", "Rocha2", "Rocha3" }, base = { 4.7, 4.9 }, escala = 1 },
	tora = { modelos = { "Tora1", "Tora2" }, base = { 6.9, 1.5 }, escala = 1 },
	toco = { modelos = { "Toco1" }, base = { 2.3, 2.3 }, escala = 1 },
	casa = { modelos = { "Casa1", "Casa2", "Casa3" }, base = { 14.1, 11.5 }, escala = 1 },
	-- Ruínas do Vale (RuinasLayout)
	coluna = { modelos = { "Coluna1", "Coluna2" }, base = { 2.5, 2.5 }, escala = 1 },
	colunaquebrada = { modelos = { "ColunaQuebrada1", "ColunaQuebrada2" }, base = { 8, 5 }, escala = 1 },
	muro = { modelos = { "Muro1", "Muro2" }, base = { 8.6, 1.7 }, escala = 1 },
	arco = { modelos = { "Arco" }, base = { 9, 3.3 }, escala = 1 },
	altar = { modelos = { "Altar" }, base = { 10, 10 }, escala = 1 },
	lapide = { modelos = { "Lapide1", "Lapide2" }, base = { 1.9, 1 }, escala = 1 },
	-- Acampamento da região inicial (RegiaoLayout)
	tenda = { modelos = { "Tenda1", "Tenda2", "Tenda3" }, base = { 6.3, 6.9 }, escala = 1 },
	fardo = { modelos = { "Fardo1" }, base = { 1.9, 3.9 }, escala = 1 },
	placa = { modelos = { "Placa1" }, base = { 3.6, 0.5 }, escala = 1 },
	tripe = { modelos = { "Tripe1" }, base = { 2.7, 2.7 }, escala = 1 },
	arvoremorta = { modelos = { "ArvoreMorta1", "ArvoreMorta2", "ArvoreMorta3" }, base = { 6, 6 }, escala = 1 },
}

-- Variante determinística pela posição.
-- Só famílias explicitamente decorativas atravessam o avatar.
function PropsLayout.colide(familia: string): boolean
 local f = PropsLayout.FAMILIAS[familia]
 return f == nil or f.colide ~= false
end

function PropsLayout.modelo(familia: string, x: number, z: number): string?
	local f = PropsLayout.FAMILIAS[familia]
	if not f then
		return nil
	end
	local h = math.abs(math.floor(x * 7.31 + z * 13.17)) % 1000
	return f.modelos[h % #f.modelos + 1]
end

-- { x, z, familia, escala relativa, giro em graus }
PropsLayout.VILA = {
	-- casas de campo ladeando a estrada de entrada, de porta para a estrada (porta = +Z local)
	{ -34, -131, "casa", 1, 90 }, { 34, -131, "casa", 1, 270 },
	-- Barris transferidos das portas para os intervalos da rua do mercado.
	{ -11, -136, "barril", 1, 0 }, { -13, -122, "barril", 1, 0 }, { -26, -144, "barril", 1, 0 },
	{ 11, -136, "barril", 1, 0 }, { 13, -122, "barril", 1, 0 }, { 26, -144, "barril", 1, 0 },
	-- cercas baixas ao longo da estrada que chega à vila, entre as casas
	{ -9, -124, "cerca", 1, 90 }, { -9, -128.8, "cerca", 1, 90 }, { -9, -133.6, "cerca", 1, 90 },
	{ 9, -124, "cerca", 1, 90 }, { 9, -128.8, "cerca", 1, 90 }, { 9, -133.6, "cerca", 1, 90 },
	-- arbustos nas bordas
	{ -80, -150, "arbusto", 1.1, 20 }, { 80, -150, "arbusto", 1, 200 },
	{ -84, -205, "arbusto", 1.2, 100 }, { 84, -207, "arbusto", 1.1, 300 },
	{ -70, -258, "arbusto", 1, 60 }, { 70, -258, "arbusto", 1.2, 250 },
	{ -45, -262, "arbusto", 1.1, 160 }, { 45, -262, "arbusto", 1, 10 },
	{ -15, -268, "arbusto", 1.2, 330 }, { 16, -268, "arbusto", 1.1, 120 },
	{ -12, -306, "arbusto", 1, 45 }, { 12, -308, "arbusto", 1.2, 225 },
	{ -22, -143, "arbusto", 1, 80 }, { 22, -143, "arbusto", 1.1, 260 },
	-- rochas e uma tora velha
	{ -100, -165, "rocha", 1.2, 30 }, { 102, -250, "rocha", 1.4, 200 },
	{ -60, -275, "rocha", 1.1, 120 }, { 60, -278, "rocha", 1.3, 300 },
	{ -92, -250, "tora", 1, 20 }, { 90, -165, "toco", 1, 0 },
}

local function retangulo(x, z, familia, escala, giro)
	local f = PropsLayout.FAMILIAS[familia]
	local sx, sz = f.base[1] * f.escala * escala, f.base[2] * f.escala * escala
	local a = math.rad(giro)
	local c, s = math.abs(math.cos(a)), math.abs(math.sin(a))
	if c < 1e-12 then c = 0 end
	if s < 1e-12 then s = 0 end
	sx, sz = sx * c + sz * s, sx * s + sz * c
	return { x = x, z = z, sx = sx, sz = sz }
end

function PropsLayout.retangulo(prop)
	return retangulo(prop[1], prop[2], prop[3], prop[4], prop[5])
end

-- Gerador congruencial pequeno e determinístico (mesmos adereços em todo servidor).
local function sorteador(semente)
	local estado = semente
	return function()
		estado = (estado * 1103515245 + 12345) % 2147483648
		return estado / 2147483648
	end
end

-- Copas podem se entrelaçar; a camada baixa pode ficar sob a copa, nunca no tronco.
PropsLayout.DENSIDADE = { plantasFloresta = 280, floresVila = 220 }
function PropsLayout.floresta(): { { any } }
	local lista, rets = {}, {}
	for _, a in ipairs(FlorestaLayout.ARVORES) do
		table.insert(lista, { a[1], a[2], a[4], a[3], a[5] })
	end
	local rng = sorteador(41629)
	local familias = { "samambaia", "samambaia", "samambaia", "cogumelos", "tufo", "toramusgo", "rochedo" }
	local n, luzes = 0, 0
	for _ = 1, 6000 do
		if n >= PropsLayout.DENSIDADE.plantasFloresta then break end
		local x, z = -103 + rng() * 206, -592 + rng() * 284
		local f = familias[math.floor(rng() * #familias) + 1]
		-- Luminosos raros, apenas no anel da clareira.
		if math.abs(z + 485) < 45 and math.abs(x) < 52 and luzes < 4 then f = "cogumelosluz" end
		local p = { x, z, f, 0.65 + rng() * 0.3, math.floor(rng() * 360) }
		local r = PropsLayout.retangulo(p)
		local livre = FlorestaLayout.contem(FlorestaLayout.SOLO, r)
		for _, zona in ipairs({ FlorestaLayout.TRILHA, FlorestaLayout.CLAREIRA }) do
			if FlorestaLayout.sobrepoe(r, { x = zona.x, z = zona.z, sx = zona.sx + 6, sz = zona.sz + 6 }) then livre = false end
		end
		for _, a in ipairs(FlorestaLayout.ARVORES) do
			if FlorestaLayout.sobrepoe(r, { x = a[1], z = a[2], sx = 2.5, sz = 2.5 }) then livre = false break end
		end
		for _, outro in ipairs(rets) do
			if FlorestaLayout.sobrepoe(r, outro) then livre = false break end
		end
		if livre then
			table.insert(lista, p); table.insert(rets, r); n += 1
			if f == "cogumelosluz" then luzes += 1 end
		end
	end
	return lista
end

-- Áreas de exclusão da vila, compartilhadas pelo gerador e pela auditoria.
function PropsLayout.fixosVila()
	local fixos = { VilaLayout.PRACA, VilaLayout.POCO_QUINTAL }
	for _, e in ipairs(VilaLayout.predios()) do table.insert(fixos, VilaLayout.ocupacao(e)) end
	for _, r in ipairs(VilaLayout.ACESSOS) do table.insert(fixos,{x=r.x,z=r.z,sx=r.sx+2,sz=r.sz+2}) end
	for _, p in ipairs(VilaLayout.DECORACAO) do table.insert(fixos,PropsLayout.retangulo(p)) end
	for _, e in ipairs(VilaLayout.BARRACAS) do table.insert(fixos, VilaLayout.pegadaBarraca(e)) end
	for _, e in ipairs(VilaLayout.POSTES) do table.insert(fixos, {x=e.x,z=e.z,sx=2,sz=2}) end
	for _, e in ipairs({VilaLayout.ESTRADA,VilaLayout.TRILHA_FLORESTA}) do
		table.insert(fixos,{x=e.x,z=e.z,sx=e.sx+4,sz=e.sz+4})
	end
	for _, a in ipairs(VilaLayout.ARVORES) do table.insert(fixos,{x=a[1],z=a[2],sx=11*a[3],sz=11*a[3]}) end
	-- Mantém livres as posições dos NPCs/treinadores junto às portas e os acessos.
	for _, e in ipairs(VilaLayout.predios()) do
		local d = VilaLayout.porta(e)
		table.insert(fixos,{x=d.x,z=d.z,sx=VilaLayout.DISTANCIA_MAX_PORTA*2,sz=VilaLayout.DISTANCIA_MAX_PORTA*2})
	end
	for _, e in ipairs(VilaLayout.BARRACAS) do
		local d = VilaLayout.porta(e)
		table.insert(fixos,{x=d.x,z=d.z,sx=VilaLayout.DISTANCIA_MAX_PORTA*2,sz=VilaLayout.DISTANCIA_MAX_PORTA*2})
	end
	return fixos
end

local function livreVila(p, lista)
	local ret = PropsLayout.retangulo(p)
	for _, f in ipairs(PropsLayout.fixosVila()) do if VilaLayout.sobrepoe(ret,f) then return false end end
	for _, outro in ipairs(lista) do if VilaLayout.sobrepoe(ret,PropsLayout.retangulo(outro)) then return false end end
	return true
end

-- Complementa os props antigos, preservados: luz alternada na estrada e na praça.
do
	local lista = PropsLayout.VILA
	for i=0,5 do
		local p = {if i%2==0 then -9 else 9,-56-i*16,"lampiao",1,if i%2==0 then 90 else 270}
		if livreVila(p,lista) then table.insert(lista,p) end
	end
	for _, p in ipairs({{60,-148,"carroca",0.8,90},{46,-150,"caixotes",0.8,0},
		{-26,-191,"lampiao",1,0},{26,-191,"lampiao",1,180},
		{-26,-159,"lampiao",1,90},{26,-159,"lampiao",1,270},{78,-224,"lampiao",1,270},{35,-220,"lampiao",1,90},
		{-9,-147,"lampiao",1,180},{9,-147,"lampiao",1,180}}) do
		if livreVila(p,lista) then table.insert(lista,p) end
	end
	local rng = sorteador(41630)
	local n=0
	for _=1,6000 do
		if n>=PropsLayout.DENSIDADE.floresVila then break end
		local p={-86+rng()*172,-126-rng()*142,if n%2==0 then "flores" else "tufo",0.6+rng()*0.25,math.floor(rng()*360)}
		if livreVila(p,lista) then table.insert(lista,p); n+=1 end
	end
end

function PropsLayout.validar(): { string }
	local problemas={}
	-- Props herdados têm tolerâncias históricas; os novos passam pelo gerador conservador.
	for i,p in ipairs(PropsLayout.VILA) do
		if not PropsLayout.FAMILIAS[p[3]] then table.insert(problemas,"familia desconhecida "..i) end
		local r=PropsLayout.retangulo(p)
		for _,f in ipairs({VilaLayout.PRACA,VilaLayout.ESTRADA,VilaLayout.TRILHA_FLORESTA}) do
			if VilaLayout.sobrepoe(r,f) then table.insert(problemas,p[3].." bloqueia via") end
		end
		for _,e in ipairs(VilaLayout.predios()) do
			if VilaLayout.sobrepoe(r,VilaLayout.ocupacao(e)) then table.insert(problemas,p[3].." bloqueia predio") end
		end
		for j=1,i-1 do
			if VilaLayout.sobrepoe(r,PropsLayout.retangulo(PropsLayout.VILA[j])) then table.insert(problemas,p[3].." sobrepoe prop "..j) end
		end
	end
	return problemas
end

return PropsLayout
