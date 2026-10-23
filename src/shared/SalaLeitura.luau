-- Geometria de apresentação: mantém página e marcadores acessíveis ao arrastar
-- ou girar em qualquer proporção de tela, sem decidir regras nem criar objetos.
local L={}
function L.calcular(largura,altura,aspecto,fov,angulo,x,y,minima)
	local tangente=math.tan(math.rad(fov/2))
	aspecto=math.max(.1,aspecto)
	local c,s=math.abs(math.cos(angulo)),math.abs(math.sin(angulo))
	local larguraGirada=c*largura+s*altura
	local alturaGirada=s*largura+c*altura
	local distancia=math.max(minima or 3,alturaGirada/(2*tangente)*1.2,larguraGirada/(2*tangente*aspecto)*1.2)
	local escala=math.min(1,1.2/distancia)
	local profundidade=distancia*escala
	local limiteY=profundidade*tangente
	local limiteX=limiteY*aspecto
	local margemX=math.max(0,limiteX-larguraGirada*escala/2-.02)
	local margemY=math.max(0,limiteY-alturaGirada*escala/2-.02)
	return {escala=escala,distancia=profundidade,
		x=math.clamp(x*escala,-margemX,margemX),y=math.clamp(y*escala,-margemY,margemY),
		largura=larguraGirada*escala,altura=alturaGirada*escala,limiteX=limiteX,limiteY=limiteY}
end
return L
