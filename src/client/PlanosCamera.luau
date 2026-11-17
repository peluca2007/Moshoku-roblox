--!strict
-- CAM1: linguagem de planos de câmera por habilidade (referência: Expedition 33). Cada habilidade ativa até o rank
-- Principiante das árvores de foco tem uma lista de tomadas: aproxima no preparo, plano de 3/4 no lançamento,
-- segue o golpe/projétil e corta para o alvo no contato. Só dados; a matemática está em
-- `shared/PlanosCameraCalculo` e a aplicação (oclusão, parede, mistura com a câmera da luta) em `client/ImpactoCamera`.
-- `zona = true`: o plano é chamado pelo desenho da zona (MagiasAgua), não pela Coreografia.
-- Campos de cada tomada (ver PlanosCameraCalculo): t = s relativos ao contato; f = de|para|meio|proj;
-- ang = graus em volta do ponto (0 de lado, + atrás do atacante, - pela frente do alvo); dist; alt = altura da
-- câmera acima do ponto; mira = quanto o olhar sobe. Tomadas antes do início da cena colapsam no instante 0.
-- Limites: a câmera da luta (BoardView) filtra a 110 graus/s e 30 studs/s; por isso os planos usam movimentos curtos
-- e contínuos (sem cortes secos). Duração total do plano <= contato + ~1 s: não alonga o turno.
local Calculo = require(game:GetService("ReplicatedStorage").Shared.PlanosCameraCalculo)

local M = {}

M.PLANOS = {
	-- Ladino ------------------------------------------------------------------------------------------------
	["primeiro-golpe"] = { tomadas = {
		{ t = -1.2, f = "de", ang = 30, dist = 9, alt = 1.4 }, -- aproxima no preparo (o ladino se agacha)
		{ t = -0.4, f = "meio", ang = 8, dist = 9.5, alt = 1.2 }, -- de lado: a sombra do ladino e o alvo no mesmo quadro
		{ t = 0, f = "para", ang = -30, dist = 6, alt = 0.9 }, -- contato: corta para a frente do alvo
		{ t = 0.5, f = "para", ang = -15, dist = 8, alt = 1.3 }, -- abre devagar (a câmera lenta da assinatura corre aqui)
	} },
	-- Mago da Água ------------------------------------------------------------------------------------------
	["respingo"] = { tomadas = {
		{ t = -0.5, f = "de", ang = 45, dist = 7, alt = 1.1 },
		{ t = -0.15, f = "proj", ang = 30, dist = 7, alt = 1.2 }, -- segue o jato
		{ t = 0, f = "para", ang = -30, dist = 6, alt = 0.9 },
		{ t = 0.35, f = "para", ang = -15, dist = 8, alt = 1.2 },
	} },
	["bola-de-agua"] = { tomadas = {
		{ t = -1.1, f = "de", ang = 50, dist = 7.5, alt = 1.2 }, -- o puxão das duas mãos
		{ t = -0.45, f = "proj", ang = 35, dist = 8, alt = 1.3 }, -- acompanha a esfera
		{ t = 0, f = "para", ang = -30, dist = 6, alt = 0.9 }, -- acerto e empurrão
		{ t = 0.5, f = "para", ang = -15, dist = 8.5, alt = 1.3 },
	} },
	["flecha-de-agua"] = { tomadas = {
		{ t = -1.4, f = "de", ang = 60, dist = 7.5, alt = 1.3 }, -- arma o arco de água
		{ t = -0.6, f = "proj", ang = 40, dist = 8, alt = 1.3 }, -- segue a flecha
		{ t = 0, f = "para", ang = -28, dist = 5.5, alt = 0.9 }, -- contato em câmera lenta (assinatura)
		{ t = 0.9, f = "para", ang = -14, dist = 7, alt = 1.2 },
	} },
	["impacto-de-gelo"] = { tomadas = { -- HAB8: antes sem plano (câmera longe, alvo pequeno)
		{ t = -1.0, f = "de", ang = 45, dist = 7.5, alt = 1.2 }, -- aponta e fecha a mão
		{ t = -0.35, f = "proj", ang = 30, dist = 8, alt = 1.4 }, -- segue o estilhaço
		{ t = 0, f = "para", ang = -25, dist = 6.5, alt = 0.6, mira = 0.4 }, -- baixo: os cristais crescem para cima do quadro
		{ t = 0.6, f = "para", ang = -12, dist = 8.5, alt = 1.4 },
	} },
	["lamina-de-gelo"] = { tomadas = {
		-- em si (sem alvo): o eixo é o da câmera da luta; ang negativo vai para a frente do conjurador
		{ t = -0.7, f = "de", ang = 20, dist = 8, alt = 1.2 },
		{ t = 0, f = "de", ang = -15, dist = 5.5, alt = 0.3, mira = 0.2 }, -- de baixo, a lâmina se materializa
		{ t = 0.5, f = "de", ang = -5, dist = 7.5, alt = 1.0 },
	} },
	["escudo-de-agua"] = { zona = true, tomadas = {
		-- `de` = lado dos aliados, `para` = o muro (o chamador passa os pontos): 3/4 pela face, recuando e subindo
		{ t = 0, f = "para", ang = 62, dist = 11, alt = 1.2 },
		{ t = 1.0, f = "para", ang = 30, dist = 14, alt = 3.5 },
		{ t = 2.4, f = "para", ang = 6, dist = 16, alt = 7 }, -- HAB8: termina alto e de lado (aliados, muro e inimigos); antes ficava atrás do muro
	} },
	["nevoa-densa"] = { zona = true, tomadas = {
		{ t = 0, f = "para", ang = 40, dist = 14, alt = 10 }, -- HAB8: do alto, por cima de muros (o Escudo de pé tapava)
		{ t = 1.4, f = "para", ang = 20, dist = 16, alt = 15 }, -- sobe e mostra a área rente ao chão
	} },
	-- Deus da Espada ----------------------------------------------------------------------------------------
	["corte-de-braco"] = { tomadas = {
		{ t = -1.0, f = "de", ang = 32, dist = 9, alt = 1.3 },
		{ t = -0.35, f = "meio", ang = 10, dist = 9, alt = 1.1 },
		{ t = 0, f = "para", ang = -32, dist = 5.5, alt = 0.8 }, -- depois do contato a câmera da arma caindo assume
		{ t = 0.35, f = "para", ang = -18, dist = 7, alt = 1.1 },
	} },
	["investida-espada"] = { tomadas = {
		{ t = -3, f = "proj", ang = 60, dist = 7.5, alt = 1.3 }, -- acompanha a corrida desde a largada
		{ t = -0.8, f = "proj", ang = 40, dist = 7, alt = 1.1 },
		{ t = 0, f = "para", ang = -30, dist = 6, alt = 0.9 }, -- corta para a frente do alvo no contato
		{ t = 0.45, f = "para", ang = -15, dist = 8, alt = 1.4 },
	} },
	["golpe-continuo"] = { tomadas = {
		{ t = -1.0, f = "de", ang = 30, dist = 9, alt = 1.3 },
		{ t = -0.35, f = "meio", ang = 8, dist = 9, alt = 1.1 },
		{ t = 0, f = "para", ang = -28, dist = 6, alt = 0.9 },
		{ t = 0.5, f = "para", ang = -12, dist = 8, alt = 1.2 },
	} },
}

for nome, plano in M.PLANOS do
	local erro = Calculo.validar(plano)
	if erro then warn("[PlanosCamera]", nome, erro) end
end

-- "ability/agua/Principiante/respingo" -> "respingo"
function M.curto(habilidadeId: string): string
	return string.match(habilidadeId, "[^/]+$") or habilidadeId
end

function M.plano(habilidadeId: string)
	return M.PLANOS[M.curto(habilidadeId)]
end

-- Opções para `ImpactoCamera.golpe` (nil se a habilidade não tem plano: fica a câmera padrão do golpe).
-- `zona`: true só para quem desenha a zona (MagiasAgua); a Coreografia pede os planos que não são de zona.
function M.opc(habilidadeId: string, zona: boolean?): { plano: any }?
	local plano = M.plano(habilidadeId)
	if not plano or (plano.zona == true) ~= (zona == true) then return nil end
	return { plano = plano }
end

return M
