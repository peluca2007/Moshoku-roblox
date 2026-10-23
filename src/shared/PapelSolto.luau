-- Trajetória cosmética determinística. Não move fichas nem usa física replicada.
local P = {}
local function finito(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
function P.vetor(v)
	return type(v) == "table" and finito(v.x) and finito(v.y) and finito(v.z)
end
local function ponto(o, v, t)
	local x = math.clamp(o.x + v.x*t, 231, 269)
	local z = math.clamp(o.z + v.z*t, -18, 18)
	local chao = if math.abs(x-250)<5.5 and math.abs(z)<10.5 then 3.77 else .12
	return {x=x, y=math.max(chao, o.y+v.y*t-12*t*t), z=z}, o.y+v.y*t-12*t*t <= chao
end
function P.criar(origem, direcao, forca, inicio, soltar)
	if not P.vetor(origem) or not P.vetor(direcao) or not finito(forca) or forca<0 or forca>1 then return nil end
	if soltar~=nil and type(soltar)~="boolean" then return nil end
	local tamanho=math.sqrt(direcao.x^2+direcao.y^2+direcao.z^2)
	if tamanho<.1 or tamanho>2 then return nil end
	local v={x=direcao.x/tamanho*(5+forca*23),y=direcao.y/tamanho*(5+forca*23)+3,z=direcao.z/tamanho*(5+forca*23)}
	if soltar then v={x=0,y=0,z=0} end
	local voo=3
	for i=1,90 do local _,bateu=ponto(origem,v,i/30);if bateu then voo=i/30;break end end
	return {origem=origem,velocidade=v,inicio=inicio,tempoVoo=voo}
end
function P.posicao(p,agora)
	local t=math.clamp(agora-p.inicio,0,p.tempoVoo)
	local pos=ponto(p.origem,p.velocidade,t)
	return pos,t,p.tempoVoo<=agora-p.inicio
end
return P
