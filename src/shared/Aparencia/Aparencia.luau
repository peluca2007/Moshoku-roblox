local Shared = game:GetService("ReplicatedStorage").Shared
local C=require(Shared.Aparencia.Catalogo)
local R=require(Shared.Aparencia.Racas)
local M={}
local function keys(t, allowed)
	if type(t)~="table" or getmetatable(t) ~= nil then return false end
	for k in t do if not allowed[k] then return false end end
	return true
end
local function validoId(v,t) return type(v)=="string" and t[v]~=nil end
function M.validar(a,raceId,possuidos)
	local r=R.POR_ID[raceId]; if not r then return false,"raça desconhecida" end
	if type(a)~="table" or type(possuidos)~="table" then return false,"estrutura inválida" end
	local root={versao=true,rosto=true,cores=true,cabelo=true,barba=true,roupas=true}; if not keys(a,root) or a.versao~=1 then return false,"campos ou versão inválidos" end
	local rosto={olhos=true,sobrancelhas=true,nariz=true,boca=true}; if not keys(a.rosto,rosto) then return false,"rosto inválido" end
	for k in rosto do if not validoId(a.rosto[k],C.ROSTO[k]) then return false,"estilo de rosto inválido" end end
	local cores={pele=true,olho=true,cabelo=true,camisa=true,calca=true}; if not keys(a.cores,cores) then return false,"cores inválidas" end
	for k in cores do local id=a.cores[k]; if type(id)~="string" or not C.CORES[id] then return false,"cor inválida" end end
	local permitidas={pele=r.paleta,olho=r.coresOlho,cabelo=r.coresCabelo,camisa=r.coresCamisa,calca=r.coresCalca}
	for k,lista in permitidas do if not table.find(lista,a.cores[k]) then return false,"cor fora da paleta racial" end end
	if not validoId(a.cabelo,C.CABELOS) or not validoId(a.barba,C.BARBAS) then return false,"cabelo ou barba inválidos" end
	if not keys(a.roupas,{cabeca=true,rosto=true,costas=true,cintura=true,mao=true,corpo=true,pes=true}) then return false,"slots inválidos" end
	for slot,id in a.roupas do
		if type(id) ~= "string" then return false,"peça inválida" end
		local p=C.PECAS[id]; if not p or p.slot~=slot then return false,"peça/slot inválidos" end
		if p.raridade=="rara" and possuidos[id]~=true then return false,"peça rara não possuída" end
		if p.racial and not table.find(r.opcionais,id) then return false,"peça racial de outra raça" end
	end
	for _,id in r.obrigatorias do if C.PECAS[id]==nil then return false,"catálogo racial incompleto" end end
	return true
end
local function pick(rng, list) return list[rng:NextInteger(1,#list)] end
local function keysSorted(t) local o={}; for k in t do table.insert(o,k) end; table.sort(o); return o end
function M.aleatoria(raceId,rng)
	local r=R.POR_ID[raceId]; assert(r and rng and rng.NextInteger,"raça/RNG inválido")
	local function choose(t) return pick(rng,keysSorted(t)) end
	local function color(allowed) return pick(rng,allowed) end
	local roupas={}
	return {versao=1,rosto={olhos=choose(C.ROSTO.olhos),sobrancelhas=choose(C.ROSTO.sobrancelhas),nariz=choose(C.ROSTO.nariz),boca=choose(C.ROSTO.boca)},cores={pele=color(r.paleta),olho=color(r.coresOlho),cabelo=color(r.coresCabelo),camisa=color(r.coresCamisa),calca=color(r.coresCalca)},cabelo=choose(C.CABELOS),barba=choose(C.BARBAS),roupas=roupas}
end
function M.padrao(raceId,semente)
	local state=(math.floor(tonumber(semente) or 1)%2147483646)+1
	local rng={}; function rng:NextInteger(a,b) state=(state*48271)%2147483647; return a+(state%(b-a+1)) end
	return M.aleatoria(raceId,rng)
end
return M
