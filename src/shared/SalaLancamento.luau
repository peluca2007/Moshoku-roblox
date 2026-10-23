-- Valida apenas intenção de lançamento; origem/velocidade finais são do servidor.
local L={}
function L.validar(d)
	if type(d)~="table" or type(d.direcao)~="table" or type(d.forca)~="number" or d.forca~=d.forca or d.forca<0 or d.forca>1 then return nil end
	if d.soltar~=nil and type(d.soltar)~="boolean" then return nil end
	local v=d.direcao
	for _,n in {v.x,v.y,v.z} do if type(n)~="number" or n~=n or math.abs(n)>2 then return nil end end
	if type(v.x)~="number" or type(v.y)~="number" or type(v.z)~="number" then return nil end
	local m=math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z);if m<.1 or m>2 then return nil end
	return {x=v.x/m,y=v.y/m,z=v.z/m,velocidade=if d.soltar then 0 else 9+14*d.forca,subida=if d.soltar then 0 else 5+7*d.forca}
end
return L
