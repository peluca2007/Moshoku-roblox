local Shared = game:GetService("ReplicatedStorage").Shared
local T = require(Shared.UITemaDados)
local function luminancia(c)
	local function linear(x) return if x <= 0.04045 then x / 12.92 else ((x + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * linear(c.R) + 0.7152 * linear(c.G) + 0.0722 * linear(c.B)
end
local function contraste(a, b)
	local x, y = luminancia(a), luminancia(b)
	return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05)
end
return {
 ["prévia de corpo ocupa pelo menos 70 por cento da caixa"] = function(t)
  for _,aspecto in {1,1.5,1.8,2} do
   for _,angulo in {0,.24,math.pi/4,math.pi/2} do
    local altura,largura,profundidade=4.7,4,1.2
    local distancia=T.distanciaPrevia(altura,largura,profundidade,aspecto,angulo,38,false)
    local ocupacaoAltura=altura/(2*distancia*math.tan(math.rad(19)))
    t.ok(ocupacaoAltura>=.70 and ocupacaoAltura<=.80)
    t.ok(T.distanciaPrevia(1,1,1,aspecto,angulo,38,true)<distancia)
   end
  end
 end,

 ["grade fraca fora e forte somente na arena ativa"] = function(t)
  for _,base in {0.08,0.18,0.38,0.72,1} do
   for _,casa in {false,true} do
    for _,centro in {{10,20},{90,80}} do
     for _,ativo in {false,true} do
      local forte=ativo and T.gradeAtiva(centro[1],centro[2],10,20)
      local mod=T.gradeLocal(base,casa,forte)
      local efetiva=1-(1-base)*(1-mod)
      local esperado=if forte then base elseif casa then 1 else math.max(base,.92)
      t.ok(math.abs(efetiva-esperado)<1e-6)
     end
    end
   end
  end
  t.eq(T.gradeAtiva(10,20,nil,nil),false)
 end,

 ["banner e estado empilham em retrato paisagem e desktop"] = function(t)
  for _,largura in {320,374,666,700,1647} do
   for _,grande in {false,true} do
    local f=T.faixasAviso(largura,grande)
    t.ok(f.painelTopo >= f.topo+f.altura+12)
   end
  end
 end,
	["fontes hierarquia e mapa de ícones V2 revisados"] = function(t)
		t.eq(T.familias.titulo, "Bodoni"); t.eq(T.familias.subtitulo, "Garamond"); t.eq(T.familias.icone, "Garamond")
		for _, familia in T.familias do t.ok(not string.find(familia, "Grenze")); t.ok(not string.find(familia, "Cinzel")) end
		for chave, valor in { titulo=30, subtitulo=22, corpo=19, rotulo=20, numero=22, legenda=15 } do
			t.eq(T.tamanhos[chave], valor)
			for _, escala in { 0.85, 1 } do t.ok(T.tamanhoTexto(valor, escala)*escala >= 14) end
		end
		for nome, glifo in { fechar="✕", confirmar="✓", menu="☰", ajuda="?", run="✦", combate="⚔", mapa="⚑", conta="♦", tempo="☀", vida="♥", girarEsq="↺", girarDir="▶", estrela="★", seta="▶" } do t.eq(T.icone(nome), glifo) end
		t.eq(T.icone("◇"), "◇")
	end,
	["texto e títulos contrastam inclusive sobre painel composto com mundo branco"] = function(t)
		local c = T.cores.painel
		local a = T.transparencias.painel
		local composto = Color3.new(c.R * (1-a) + a, c.G * (1-a) + a, c.B * (1-a) + a)
		for _, papel in { "texto", "secundario", "titulo", "info", "sucesso", "perigo", "alerta" } do
			t.ok(contraste(T.cores[papel], c) >= 4.5, papel)
			t.ok(contraste(T.cores[papel], composto) >= 4.5, papel .. " sobre mundo claro")
		end
	end,
	["texto escuro contrasta com ouro e estados hover e pressionado"] = function(t)
		local function misturar(a, b, f) return Color3.new(a.R*(1-f)+b.R*f, a.G*(1-f)+b.G*f, a.B*(1-f)+b.B*f) end
		for _, ponta in { T.cores.ouroClaro, T.cores.ouroEscuro } do
			for _, alvo in { T.cores.texto, misturar(T.cores.texto, T.cores.gradienteBase, 0.6), misturar(T.cores.texto, T.cores.ouroEscuro, 0.16) } do
				local composto = Color3.new(ponta.R*alvo.R, ponta.G*alvo.G, ponta.B*alvo.B)
				t.ok(contraste(T.cores.textoEscuro, composto) >= 4.5, "gradiente principal")
			end
		end
		for _, fator in { 0, 0.08, 0.16 } do
			local o, e = T.cores.ouro, T.cores.textoEscuro
			local fundo = Color3.new(o.R*(1-fator)+e.R*fator, o.G*(1-fator)+e.G*fator, o.B*(1-fator)+e.B*fator)
			t.ok(contraste(e, fundo) >= 4.5)
		end
	end,
	["escala por altura e toque físico mínimo"] = function(t)
		for _, altura in { 320, 600, 699 } do
			local e = T.escala(altura); t.eq(e, 0.85); t.ok(T.alturaToque(e)*e >= 44)
		end
		for _, altura in { 0, -1, 700, 1080, math.huge, 0/0 } do t.eq(T.escala(altura), 1) end
	end,
	["contrato de tokens completo"] = function(t)
		for _, chave in { "painel", "borda", "fio", "texto", "titulo", "secundario", "ouro", "textoEscuro", "vinho", "perigo", "sucesso", "alerta", "info", "sombra" } do
			local c = T.cores[chave]; t.ok(c ~= nil, chave)
			for _, v in { c.R, c.G, c.B } do t.ok(v >= 0 and v <= 1) end
		end
		for _, chave in { "titulo", "subtitulo", "corpo", "rotulo", "numero" } do t.ok(T.tamanhos[chave] > 0) end
		for _, valor in { 4, 8, 12, 16, 24 } do
			local achou = false; for _, v in T.espacamentos do if v == valor then achou = true end end; t.ok(achou)
		end
		t.eq(T.raios.painel, 6); t.eq(T.espessuras.borda, 2); t.eq(T.espessuras.botao, 1.5)
		for _, v in T.transparencias do t.ok(v >= 0 and v <= 1) end
		t.ok(T.transparencias.painel >= 0.10 and T.transparencias.painel <= 0.15)
		for _, chave in { "titulo", "reserva", "corpo", "rotulo", "numero" } do t.ok(type(T.familias[chave]) == "string") end
		t.ok(T.tween > 0 and T.tween <= 0.12); t.eq(T.toqueMinimo, 44)
	end,
}
