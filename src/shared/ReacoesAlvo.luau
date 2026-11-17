--!strict
-- REA1: reação do corpo do alvo = f(habilidade, tipo de alvo, resultado do recibo). Pura (sem Instances): o servidor
-- decide tudo (acerto, crítico, teste de Vigor, se algo caiu mesmo); isto só escolhe COMO o corpo mostra.
-- Regra do livro (Corte de Braço): o alvo faz teste de Vigor; se falhar, larga o que segura. Sem arma no modelo,
-- nada cai: o membro atingido cede (humanoide desarmado: braço; quadrúpede/aracnídeo: pata, manca).
local M = {}

M.TIPOS = { "humanoide", "quadrupede", "aracnideo", "voador", "amorfo", "morto-vivo" }

local PALAVRAS = {
	{ "aracnideo", { "aranha", "escorpi", "inseto", "formiga", "besouro", "mosca" } },
	{ "quadrupede", { "lobo", "rato", "cao", "cachorro", "urso", "javali", "gato", "cavalo", "cervo", "fera" } },
	{ "voador", { "morcego", "corvo", "ave", "passaro", "vespa", "dragao" } },
	{ "amorfo", { "slime", "gosma", "gelatina", "limo" } },
	{ "morto-vivo", { "esqueleto", "zumbi", "morto", "fantasma", "cadaver" } },
}

-- Tipo do corpo a partir do nome/modelo da criatura (minúsculas, sem acento é responsabilidade de quem chama).
function M.tipoDoAlvo(nome: string?): string
	local n = string.lower(nome or "")
	for _, par in PALAVRAS do
		for _, p in par[2] :: { string } do
			if string.find(n, p, 1, true) then
				return par[1] :: string
			end
		end
	end
	return "humanoide"
end

-- Recibo do alvo (resumoDoEfeito): { acertou, critico, passou, dano, largouArma }.
-- Devolve { reacao, forca, solta, membro? } com reacao em:
--   "esquiva" | "bloqueio" | "recuo" | "recuo-forte" | "cambaleio" | "larga-arma" | "membro-atingido" | "nenhuma"
function M.decidir(idHabilidade: string, tipo: string, temArma: boolean, r: { [string]: any })
	local corteBraco = string.find(idHabilidade, "corte-de-braco", 1, true) ~= nil
	if r.acertou == false then
		return { reacao = "esquiva", forca = 0.3, solta = false }
	end
	local dano = r.dano or 0
	if dano <= 0 and not corteBraco then
		return { reacao = if r.acertou then "bloqueio" else "nenhuma", forca = 0.3, solta = false }
	end
	if corteBraco then
		if r.passou == true then
			return { reacao = "recuo-forte", forca = 1.6, solta = false }
		end
		-- falhou no Vigor: só larga se o servidor confirmou (largouArma ~= false) e o modelo tem a peça
		if temArma and r.largouArma ~= false then
			return { reacao = "larga-arma", forca = 1.4, solta = true }
		end
		local membro = if tipo == "humanoide" or tipo == "morto-vivo" then "braco" else "pata"
		return { reacao = "membro-atingido", forca = 1.2, solta = false, membro = membro }
	end
	if r.critico then
		return { reacao = "cambaleio", forca = 1.8, solta = false }
	end
	return { reacao = "recuo", forca = if dano >= 8 then 1.2 else 0.9, solta = false }
end

return M
