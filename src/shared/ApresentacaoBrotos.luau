-- Ordenação estável do placar, sem sortear dados ou escolher o mestre.
local Shared = game:GetService("ReplicatedStorage").Shared
local B=require(Shared.Brotos)
local A={}
function A.linhas(resultado,pessoas,social)
	local nomes={};for _,p in pessoas do nomes[tostring(p.id)]=p.nome end
	local entradas={}
	for id,dados in resultado.dados do
		local r=B.avaliar(dados)
		if r then table.insert(entradas,{id=tostring(id),dados=dados,r=r}) end
	end
	table.sort(entradas,function(a,b) if a.r.pontos~=b.r.pontos then return a.r.pontos>b.r.pontos end;return a.id<b.id end)
	local linhas={"DADOS DO BROTOS",if social then "Diversão • rodada "..resultado.serial else "Escolha do mestre • rodada "..resultado.rodada}
	for _,e in entradas do table.insert(linhas,(nomes[e.id] or "Jogador")..": "..table.concat(e.dados," – ").." • "..e.r.categoria) end
	if #resultado.vencedores==1 then
		table.insert(linhas,(if social then "Venceu: " else "Novo mestre: ")..(nomes[tostring(resultado.vencedores[1])] or "Jogador"))
	else table.insert(linhas,if social then "Empate! A mesa dividiu a vitória." else "Empate! Só os empatados repetem.") end
	return linhas
end
return A
