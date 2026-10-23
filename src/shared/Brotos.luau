-- Três d6. Regra do Pedro; RNG recebido do servidor, nunca do cliente.
local B = {}
function B.avaliar(dados)
	if type(dados) ~= "table" or #dados ~= 3 then return nil end
	local d = {}
	for i=1,3 do local n=dados[i]; if type(n)~="number" or n%1~=0 or n<1 or n>6 then return nil end; d[i]=n end
	table.sort(d)
	if d[1]==d[3] then return {categoria="Trio",pontos=4000+(if d[1]==1 then 7 else d[1]),dados=d} end
	if d[2]==d[1]+1 and d[3]==d[2]+1 then return {categoria="Sequência",pontos=3000+d[3],dados=d} end
	if d[1]==d[2] or d[2]==d[3] then
		local dupla=if d[1]==d[2] then d[1] else d[2]
		local resto=if d[1]==d[2] then d[3] else d[1]
		return {categoria="Dupla",pontos=2000+dupla*7+resto,dados=d}
	end
	return {categoria="Sem combinação",pontos=d[3]*49+d[2]*7+d[1],dados=d}
end
function B.rolar(inteiro)
	return {inteiro(1,6),inteiro(1,6),inteiro(1,6)}
end
function B.vencedores(resultados)
	local ids, maior={},-1
	for id,d in resultados do
		local r=B.avaliar(d)
		if r and r.pontos>maior then ids={id}; maior=r.pontos elseif r and r.pontos==maior then table.insert(ids,id) end
	end
	table.sort(ids)
	return ids
end
return B
