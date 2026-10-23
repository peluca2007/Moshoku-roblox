-- Densidade das consultas físicas em pixels projetados; não decide regras.
local L={}
function L.tamanho(tipo,aspecto)
	if tipo=="mestre" then return if aspecto<.9 then 2.6 else 4.1,if aspecto<.9 then 3.7 else 3.2 end
	return 2.3,3.2
end
function L.canvas(largura,altura)
	-- Quantização evita reconstruir controles por oscilações subpixel.
	return math.max(8,math.floor(largura/8+.5)*8),math.max(8,math.floor(altura/8+.5)*8)
end
function L.texto(tamanho) return math.clamp(math.floor(tamanho*.7+.5),17,30) end
return L
