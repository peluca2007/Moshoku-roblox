-- Recebimento de texto em partes (docs/CONTRATOS.md §5.2–5.3), puro: o relógio
-- e o gerador de ids são injetados; o servidor liga isto ao RemoteEvent.
-- Partes chegam em ordem, densas a partir de 1; parte repetida idêntica é
-- confirmada sem anexar; diferente ou fora de ordem é erro e não muda o buffer.
local UploadPartes = {}
UploadPartes.__index = UploadPartes

export type Limites = {
	parteMax: number, -- bytes por parte
	partesMax: number,
	totalMax: number, -- bytes do texto inteiro
	porDono: number, -- transferências simultâneas por jogador
	porServidor: number,
	memoriaMax: number, -- bytes reservados somados
	prazo: number, -- segundos desde o início (não renova)
}

UploadPartes.PADRAO = table.freeze({
	parteMax = 4096,
	partesMax = 32,
	totalMax = 65536,
	porDono = 2,
	porServidor = 16,
	memoriaMax = 1048576,
	prazo = 60,
})

local function inteiro(v: any, min: number, max: number): boolean
	return type(v) == "number" and v == v and v % 1 == 0 and v >= min and v <= max
end

function UploadPartes.new(limites: Limites?, gerarId: (() -> string)?)
	local contador = 0
	return setmetatable({
		limites = limites or UploadPartes.PADRAO,
		gerarId = gerarId or function()
			contador += 1
			return "u" .. contador
		end,
		ativos = {}, -- uploadId -> estado
		reservado = 0,
	}, UploadPartes)
end

function UploadPartes:_contar(dono: any): (number, number)
	local doDono, total = 0, 0
	for _, u in self.ativos do
		total += 1
		if u.dono == dono then
			doDono += 1
		end
	end
	return doDono, total
end

function UploadPartes:_liberar(uploadId: string)
	local u = self.ativos[uploadId]
	if u then
		self.reservado -= u.bytes
		self.ativos[uploadId] = nil
	end
end

-- Remove transferências vencidas.
function UploadPartes:expirar(agora: number)
	for id, u in self.ativos do
		if agora - u.inicio > self.limites.prazo then
			self:_liberar(id)
		end
	end
end

-- contexto: dados opacos do chamador (geração da mesa, destino…), devolvidos no commit.
function UploadPartes:iniciar(dono: any, bytes: any, partes: any, agora: number, contexto: any): (string?, string?)
	self:expirar(agora)
	local L = self.limites
	if not inteiro(bytes, 1, L.totalMax) then
		return nil, "tamanho fora do limite (até " .. L.totalMax .. " bytes)"
	end
	if not inteiro(partes, 1, L.partesMax) or partes > bytes or partes < math.ceil(bytes / L.parteMax) then
		return nil, "quantidade de partes inválida para esse tamanho"
	end
	local doDono, total = self:_contar(dono)
	if doDono >= L.porDono then
		return nil, "você já tem transferências em andamento"
	end
	if total >= L.porServidor or self.reservado + bytes > L.memoriaMax then
		return nil, "o servidor está ocupado com outras transferências; tente de novo"
	end
	local id = self.gerarId()
	self.ativos[id] = {
		dono = dono,
		bytes = bytes,
		partes = partes,
		recebidas = {},
		recebidosBytes = 0,
		inicio = agora,
		contexto = contexto,
	}
	self.reservado += bytes
	return id, nil
end

-- Devolve o próximo índice esperado.
function UploadPartes:parte(dono: any, uploadId: any, indice: any, texto: any, agora: number): (number?, string?)
	self:expirar(agora)
	local u = type(uploadId) == "string" and self.ativos[uploadId]
	if not u or u.dono ~= dono then
		return nil, "transferência desconhecida ou vencida"
	end
	if type(texto) ~= "string" or #texto < 1 or #texto > self.limites.parteMax or utf8.len(texto) == nil then
		return nil, "parte inválida (UTF-8, até " .. self.limites.parteMax .. " bytes)"
	end
	local proximo = #u.recebidas + 1
	if inteiro(indice, 1, u.partes) and indice < proximo then
		if u.recebidas[indice] == texto then
			return proximo, nil -- repetição idêntica: confirma sem anexar
		end
		return nil, "parte " .. indice .. " repetida com conteúdo diferente"
	end
	if indice ~= proximo then
		return nil, "parte fora de ordem (esperada " .. proximo .. ")"
	end
	if u.recebidosBytes + #texto > u.bytes then
		return nil, "partes passam do tamanho anunciado"
	end
	table.insert(u.recebidas, texto)
	u.recebidosBytes += #texto
	return proximo + 1, nil
end

-- Junta as partes; libera a transferência em qualquer resultado.
function UploadPartes:concluir(dono: any, uploadId: any, agora: number): (string?, string?, any)
	self:expirar(agora)
	local u = type(uploadId) == "string" and self.ativos[uploadId]
	if not u or u.dono ~= dono then
		return nil, "transferência desconhecida ou vencida", nil
	end
	self:_liberar(uploadId)
	if #u.recebidas ~= u.partes or u.recebidosBytes ~= u.bytes then
		return nil, "transferência incompleta", nil
	end
	local texto = table.concat(u.recebidas)
	if utf8.len(texto) == nil then
		return nil, "texto com UTF-8 inválido", nil
	end
	return texto, nil, u.contexto
end

function UploadPartes:abortar(dono: any, uploadId: any)
	local u = type(uploadId) == "string" and self.ativos[uploadId]
	if u and u.dono == dono then
		self:_liberar(uploadId)
	end
end

-- Jogador saiu: libera tudo dele.
function UploadPartes:liberarDono(dono: any)
	for id, u in self.ativos do
		if u.dono == dono then
			self:_liberar(id)
		end
	end
end

-- Divide um texto em partes UTF-8 válidas de até parteMax bytes (lado do cliente).
function UploadPartes.dividir(texto: string, parteMax: number?): { string }
	local maximo = parteMax or UploadPartes.PADRAO.parteMax
	local partes = {}
	local inicio = 1
	while inicio <= #texto do
		local fim = math.min(inicio + maximo - 1, #texto)
		-- Recua até uma fronteira de caractere (byte de continuação é 10xxxxxx).
		while fim < #texto and fim > inicio and bit32.band(string.byte(texto, fim + 1), 0xC0) == 0x80 do
			fim -= 1
		end
		table.insert(partes, string.sub(texto, inicio, fim))
		inicio = fim + 1
	end
	return partes
end

return UploadPartes
