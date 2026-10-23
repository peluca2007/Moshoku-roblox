-- Matemática pura da câmera do mundo (estilo Project Zomboid): diagonal alta
-- que segue o personagem, gira em passos de 90° e aproxima/afasta. Só números:
-- sem Instances, CFrame nem Vector3, para rodar também fora do Studio.
-- O módulo cliente `CameraMundo` monta o CFrame e cuida de entrada, oclusão e pausa.
local Calculo = {}

Calculo.PASSOS = 4 -- quatro diagonais
Calculo.YAW_BASE_GRAUS = 45 -- passo 0; os demais somam 90° cada
Calculo.PITCH_GRAUS = 52 -- inclinação para baixo
Calculo.ZOOM_MIN = 22
Calculo.ZOOM_MAX = 70
Calculo.ZOOM_PADRAO = 40
Calculo.DURACAO_GIRO = 0.16 -- segundos do giro de 90°
Calculo.RAIO_TELEPORTE = 60 -- além disso a câmera salta em vez de deslizar
Calculo.FOLGA_Y_MAX = 10 -- a câmera nunca fica mais que isso atrás do Y real

-- Passo é um inteiro que pode crescer sem limite (giros acumulados); `girarPasso`
-- devolve o passo "visível" 0..3 e `yawDoPasso` aceita qualquer inteiro.
function Calculo.girarPasso(passo: number, direcao: number): number
	return (passo + direcao) % Calculo.PASSOS
end

-- Yaw em radianos: direção horizontal da câmera EM RELAÇÃO ao alvo
-- (x = sen yaw, z = cos yaw). Passo 0 = 45° (câmera em +X/+Z do personagem).
function Calculo.yawDoPasso(passo: number): number
	return math.rad(Calculo.YAW_BASE_GRAUS + 90 * passo)
end

function Calculo.limitarZoom(zoom: number): number
	return math.clamp(zoom, Calculo.ZOOM_MIN, Calculo.ZOOM_MAX)
end

-- Roda do mouse: cada "dente" muda a distância em ~12%. roda > 0 aproxima.
function Calculo.zoomPelaRoda(zoom: number, roda: number): number
	return Calculo.limitarZoom(zoom * 0.88 ^ roda)
end

-- Pinça: escala > 1 (dedos se afastando) aproxima. Parte do zoom do início do gesto.
function Calculo.zoomPelaPinca(zoomInicial: number, escala: number): number
	return Calculo.limitarZoom(zoomInicial / math.max(escala, 0.1))
end

-- Direcional analógico: eixo em -1..1 (cima aproxima), independente de FPS.
function Calculo.zoomPorEixo(zoom: number, eixo: number, dt: number): number
	return Calculo.limitarZoom(zoom * math.exp(-eixo * dt * 1.2))
end

-- Fração do caminho percorrido em dt com constante de tempo tau (não depende do FPS:
-- dois passos de dt/2 chegam ao mesmo ponto de um passo de dt).
function Calculo.fatorSuave(dt: number, tau: number): number
	if tau <= 0 then
		return 1
	end
	return 1 - math.exp(-math.max(dt, 0) / tau)
end

function Calculo.seguir(atual: number, alvo: number, dt: number, tau: number): number
	return atual + (alvo - atual) * Calculo.fatorSuave(dt, tau)
end

-- Y é suavizado à parte (degraus do terreno não chacoalham a câmera) e nunca fica
-- mais que `folga` atrás do alvo, para uma queda longa não deixar o personagem fora da tela.
function Calculo.seguirY(atual: number, alvo: number, dt: number, tau: number): number
	local novo = Calculo.seguir(atual, alvo, dt, tau)
	return math.clamp(novo, alvo - Calculo.FOLGA_Y_MAX, alvo + Calculo.FOLGA_Y_MAX)
end

-- Aproxima rápido e afasta devagar (a câmera encosta no terreno sem tranco e
-- só volta ao zoom pedido depois que o obstáculo passou).
function Calculo.seguirAssimetrico(atual: number, alvo: number, dt: number, tauSubida: number, tauDescida: number): number
	return Calculo.seguir(atual, alvo, dt, if alvo < atual then tauDescida else tauSubida)
end

function Calculo.deveTeleportar(dx: number, dy: number, dz: number): boolean
	return dx * dx + dy * dy + dz * dz > Calculo.RAIO_TELEPORTE * Calculo.RAIO_TELEPORTE
end

-- Menor diferença angular em radianos, em (-pi, pi].
function Calculo.diferencaAngular(de: number, para: number): number
	local d = (para - de) % (2 * math.pi)
	if d > math.pi then
		d -= 2 * math.pi
	end
	return d
end

-- Suavização em S (começa e termina devagar), k em 0..1.
function Calculo.suavizarGiro(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- Yaw durante o giro: vai de `de` a `para` (já não enrolados) com progresso k (0..1, linear).
function Calculo.yawAnimado(de: number, para: number, k: number): number
	return de + (para - de) * Calculo.suavizarGiro(k)
end

-- Posição da câmera (x, y, z) e ponto de mira (= foco) para o foco, yaw e zoom.
-- Retorna uma tabela de números; o cliente faz CFrame.lookAt(pos, foco).
function Calculo.camera(foco: { x: number, y: number, z: number }, yaw: number, pitchGraus: number?, zoom: number)
	local pitch = math.rad(pitchGraus or Calculo.PITCH_GRAUS)
	local horizontal = math.cos(pitch) * zoom
	return {
		x = foco.x + math.sin(yaw) * horizontal,
		y = foco.y + math.sin(pitch) * zoom,
		z = foco.z + math.cos(yaw) * horizontal,
		alvoX = foco.x,
		alvoY = foco.y,
		alvoZ = foco.z,
	}
end

-- Distância usável quando o terreno tampa a visão: `livre` é a distância do foco até o
-- primeiro ponto do terreno no caminho da câmera (nil = nada tampa). Nunca passa de
-- `zoom` e nunca fica abaixo de `minimo`.
function Calculo.distanciaLivre(zoom: number, livre: number?, margem: number, minimo: number): number
	if livre == nil then
		return zoom
	end
	return math.clamp(livre - margem, math.min(minimo, zoom), zoom)
end

-- Fade linear de opacidade: anda `dt/duracao` de `atual` em direção a `alvo` (0..1).
function Calculo.passoFade(atual: number, alvo: number, dt: number, duracao: number): number
	local passo = math.max(dt, 0) / math.max(duracao, 1e-3)
	if atual < alvo then
		return math.min(alvo, atual + passo)
	end
	return math.max(alvo, atual - passo)
end

-- Sem depender de visibilidade: margem evita giro ao chegar ao NPC.
function Calculo.promptReservaE(habilitado: boolean, distancia: number, alcance: number): boolean
 return habilitado and distancia <= alcance + 6
end

-- Copas têm nomes do catálogo local ou do pack de pinheiros (Leaves).
function Calculo.folhagem(nome: string): boolean
	local n = string.lower(nome)
	return string.match(n, "^copa[%w_]*$") ~= nil or string.match(n, "^folha[%w_]*$") ~= nil or string.match(n, "^leaves[%w_]*$") ~= nil
end

Calculo.RAIO_COPAS = 7
Calculo.ALTURA_COPAS = 48
-- Caixa mundial da copa em relação ao peito: só acima e perto da projeção do avatar.
-- Aceita meias extensões, para copas largas cuja origem fica fora do raio.
function Calculo.copaSobreAvatar(dx: number, dy: number, dz: number, mx: number, my: number, mz: number): boolean
	local x = math.max(0, math.abs(dx) - mx)
	local z = math.max(0, math.abs(dz) - mz)
	return dy + my > 2 and dy - my < Calculo.ALTURA_COPAS and x*x + z*z <= Calculo.RAIO_COPAS^2
end

return Calculo
