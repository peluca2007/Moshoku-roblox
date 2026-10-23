-- Projeção pura da apresentação U2. Não decide resultado, tempo ou recompensa.
local P = {}
function P.identidade(npcId)
	if npcId == "vila-1" then
		return { arvore = "furtividade-e-armadilhas", nome = "Furtividade e Armadilhas", titulo = "O Sino do Ladino" }
	end
	return { arvore = "agua", nome = "Água", titulo = "As Comportas" }
end
function P.projetar(r)
	local ativo = r.estado == "em-curso"
	local ladino = r.npcId == "vila-1"
	local objetivo = if ladino then (if r.sino then "Leve o sino ao portão" else "Pegue o sino") else "Encha as 3 bacias"
	local msg = r.mensagem
	local aviso
	if r.estado == "aprovado" then
		aviso = { tipo = "sucesso", titulo = "Aprovado!", duracao = 6 }
	elseif msg and string.match(msg, "^Pego!") then
		aviso = { tipo = "perigo", titulo = "Pego!", duracao = 4 }
	elseif msg and string.match(msg, "^Tempo esgotado") then
		aviso = { tipo = "alerta", titulo = "Tempo esgotado", duracao = 5 }
	elseif msg then
		aviso = { tipo = if ativo then "info" else "alerta", titulo = "Provação", duracao = 4 }
	end
	return { ativo = ativo, ladino = ladino, objetivo = objetivo, aviso = aviso }
end
return P
