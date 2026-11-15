-- Tokens V2 puros: sem serviços, fontes ou Instances. Consumir pelo client/UI/Tema.
local T = {}
-- Estilo Pergaminho (Pedro, 14/11/2026): superfície de papel e tinta escura. Os nomes dos papéis são
-- os de sempre: `painel` = superfície, `texto`/`titulo`/`secundario` = tinta sobre ela, `ouro` = cor de
-- destaque e fundo da ação principal (hoje o vermelho do selo), `textoEscuro` = tinta sobre o destaque
-- (hoje creme). Estados (`perigo`, `sucesso`, `alerta`, `info`) são tons de tinta legíveis no papel.
T.cores = {
	painel = Color3.fromRGB(225, 205, 163), borda = Color3.fromRGB(122, 92, 58),
	fio = Color3.fromRGB(58, 42, 28), texto = Color3.fromRGB(44, 31, 20),
	titulo = Color3.fromRGB(112, 28, 24), secundario = Color3.fromRGB(92, 70, 46),
	ouro = Color3.fromRGB(150, 46, 38), textoEscuro = Color3.fromRGB(250, 240, 215),
	vinho = Color3.fromRGB(140, 36, 48), perigo = Color3.fromRGB(155, 28, 38),
	sucesso = Color3.fromRGB(24, 92, 54), alerta = Color3.fromRGB(120, 72, 0),
	info = Color3.fromRGB(30, 78, 140), sombra = Color3.fromRGB(0, 0, 0),
	ouroClaro = Color3.fromRGB(242, 214, 152), ouroEscuro = Color3.fromRGB(187, 148, 76),
	cabecalho = Color3.fromRGB(212, 190, 146),
	fundoTela = Color3.fromRGB(38, 28, 20), -- atrás de um painel que ocupa a tela: o papel precisa se destacar
	gradienteBase = Color3.fromRGB(255, 255, 255),
}
-- Tinta clara para o que fica direto sobre o mundo ou sobre fundo escuro (cena de abertura, marcadores,
-- luz das prévias 3D): não depende do papel.
T.sobreEscuro = {
	texto = Color3.fromRGB(239, 230, 210), titulo = Color3.fromRGB(232, 200, 122),
	secundario = Color3.fromRGB(163, 157, 143), ouro = Color3.fromRGB(201, 164, 92),
}
-- Enchimento das barras: fica sobre o trilho escuro da arte, então é cor viva e não tinta de papel.
T.barras = {
	cheia = Color3.fromRGB(78, 196, 128), media = Color3.fromRGB(232, 190, 92),
	baixa = Color3.fromRGB(240, 120, 110), mana = Color3.fromRGB(110, 165, 245),
}
T.transparencias = { painel = 0.10, sombra = 0.38, fantasma = 1, desabilitado = 0.35 }
T.raios = { painel = 6, botao = 6, barra = 4 }
T.espessuras = { borda = 2, botao = 1.5, fio = 1, destaque = 4 }
T.espacamentos = { minimo = 4, pequeno = 8, medio = 12, padrao = 16, grande = 24 }
T.tamanhos = { titulo = 30, subtitulo = 22, corpo = 19, rotulo = 20, numero = 22, legenda = 15 }
T.familias = { titulo = "Bodoni", subtitulo = "Garamond", reserva = "Garamond", icone = "Garamond", corpo = "Merriweather", rotulo = "SourceSansPro", numero = "Oswald" }
T.ICONES = {
	fechar = "✕", confirmar = "✓", menu = "☰", ajuda = "?", run = "✦", combate = "⚔",
	mapa = "⚑", conta = "♦", tempo = "☀", vida = "♥", girarEsq = "↺", girarDir = "▶",
	estrela = "★", seta = "▶", setaEsq = "◀", losango = "◆", losangoVazio = "◇",
	circulo = "●", quadrado = "■", triangulo = "▲", aspasEsq = "«", aspasDir = "»",
	cruz = "†", cruzDupla = "‡", secao = "§",
}
function T.icone(nome: string): string
	return T.ICONES[nome] or nome
end
function T.tamanhoTexto(tamanho: number, escala: number): number
	return math.max(tamanho, math.ceil(14 / math.clamp(escala, 0.01, 1)))
end
T.toqueMinimo = 44
T.tween = 0.10
T.avisoDuracao = 3
-- Altura útil em pixels; inválida/zero mantém desktop durante a inicialização.
function T.escala(altura: number): number
	return if altura == altura and altura > 0 and altura < 700 then 0.85 else 1
end
-- Compensa UIScale para preservar 44 pixels físicos de toque.
function T.alturaToque(escala: number): number
	return math.ceil(T.toqueMinimo / math.clamp(escala, 0.01, 1))
end
-- Coordenadas compartilhadas pelo banner e pelo painel de estado abaixo dele, abaixo da faixa
-- superior do Roblox (ScreenGui sem IgnoreGuiInset). O banner fica sob o HUD do mundo: celular,
-- abaixo dos atalhos; 700-1099, abaixo do relógio (que desce sob o objetivo); desktop, abaixo do
-- cartão de objetivo (12+106) e do relógio (8+84), sem cobrir nenhum dos dois.
T.TOPO_AVISO = { celular = 84, medio = 204, desktop = 126 }
function T.faixasAviso(largura, grande)
 local topo = if largura > 0 and largura < 700 then T.TOPO_AVISO.celular
  elseif largura > 0 and largura < 1100 then T.TOPO_AVISO.medio else T.TOPO_AVISO.desktop
 local altura = if grande then 144 else 104
 return { topo = topo, altura = altura, painelTopo = topo + altura + 12 }
end
-- Enquadramento geométrico puro; altura alvo de 76%, com proteção da largura.
function T.distanciaPrevia(altura, largura, profundidade, aspecto, angulo, fov, rosto)
 local tangente=math.tan(math.rad(fov/2))
 local ocupacaoAltura,ocupacaoLargura=if rosto then .68 else .76,if rosto then .68 else .78
 local projetada=math.abs(math.cos(angulo))*largura+math.abs(math.sin(angulo))*profundidade
 return math.max(altura/(2*tangente*ocupacaoAltura),projetada/(2*tangente*math.max(.1,aspecto)*ocupacaoLargura))*1.04
end
-- Política cosmética: opacidade efetiva = 1 - (1-base)*(1-modificador).
function T.gradeLocal(base, casa, ativa)
 if ativa then return 0 end
 local destino = if casa then 1 else math.max(base, 0.92)
 return if base >= 1 then 0 else math.clamp((destino-base)/(1-base),0,1)
end
function T.gradeAtiva(cx, cz, x, z)
 return x ~= nil and z ~= nil and math.abs(cx-x)<0.5 and math.abs(cz-z)<0.5
end
return T
