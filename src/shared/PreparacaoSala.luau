-- Projeção única usada pelo início autoritativo e pela checklist do cliente.
local P={NOMES={luta="Desafios",duelo="PvP",treino="Treino"}}
function P.resumo(s)
	local r={total=0,prontos=0,minimo=0,grupo={},pendencias={}}
	local lados={}
	for _,p in s.pessoas do
		if not p.admitido then continue end
		r.total+=1
		if p.pronto or p.id==s.mestre then r.prontos+=1 end
		if not (p.id==s.mestre and s.monstros) then
			if not p.ficha then table.insert(r.pendencias,p.nome.." precisa escolher uma ficha.") end
			table.insert(r.grupo,p.id)
			lados[if p.equipe==0 then p.id else "e"..p.equipe]=true
		end
	end
	r.minimo=math.ceil(r.total/2)
	if s.eleicao then table.insert(r.pendencias,"Espere a escolha do mestre.") end
	if r.prontos<r.minimo then table.insert(r.pendencias,"Pelo menos metade da mesa precisa confirmar pronto.") end
	if #r.grupo==0 then table.insert(r.pendencias,"É preciso pelo menos um personagem para jogar.") end
	if s.modo=="duelo" then
		if #r.grupo<2 then table.insert(r.pendencias,"PvP precisa de pelo menos dois jogadores.") end
		local n=0;for _ in lados do n+=1 end
		if #r.grupo>=2 and n<2 then table.insert(r.pendencias,"Defina pelo menos dois lados adversários.") end
	end
	r.podeIniciar=#r.pendencias==0
	return r
end
return P
