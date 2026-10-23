-- Nomes de apresentação para as telas de abertura; IDs internos nunca viram rótulos.
local M = {}

function M.nomeArvore(id, catalogo)
	if type(id) ~= "string" then return "Árvore" end
	local entrada = catalogo.POR_ID["tree/" .. id] or catalogo.POR_ID[id]
	return entrada and entrada.data and entrada.data.name or "Árvore"
end

function M.nomeObjetivo(objetivo, historia)
	if type(objetivo) ~= "table" then return "Expedição" end
	if objetivo.id == historia.OBJETIVO.id then return "Levar o Selo do guardião à vila" end
	if type(objetivo.titulo) == "string" and objetivo.titulo ~= "" then return objetivo.titulo end
	if type(objetivo.texto) == "string" and objetivo.texto ~= "" then return objetivo.texto end
	return "Expedição"
end

function M.nomePronto(id, personagens)
	for _, personagem in personagens do
		if personagem.id == id then return personagem.nome end
	end
	return "Personagem pronto"
end

return table.freeze(M)
