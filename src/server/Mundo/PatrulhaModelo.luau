-- Modelos do Blender nas patrulhas (mapa criatura -> módulo em Shared.Mundo.ModelosCriaturas;
-- animação em Mundo/CriaturaAnimada). Se o modelo faltar ou falhar, o visual R2 é mantido.
-- `ref` aceita o id da criatura ("creature/...") ou o prefixo legado de EncontrosPorZona.
local Modelos = require(game:GetService("ReplicatedStorage").Shared.Mundo.ModelosCriaturas)
local CriaturaAnimada = require(script.Parent.CriaturaAnimada)
local M = {}

-- Devolve `animar(dt, posicaoCorpo, direcao, andando, velocidade, olharPara)` e o objeto animado.
-- posicaoCorpo é o centro do `corpo` R2 (1,5 stud acima do chão); a direção é suavizada aqui.
function M.criar(pai, corpo, ref, posicao, nome)
	if type(ref) ~= "string" then return nil end
	local criaturaId = if string.sub(ref, 1, 9) == "creature/" then ref else Modelos.criaturaDoPrefixo(ref)
	local info = Modelos.escolher(criaturaId, Modelos.variante(nome or ""))
	if not info then return nil end
	local base = posicao - Vector3.new(0, 1.5, 0)
	local anim = CriaturaAnimada.montar(info, pai, CFrame.new(base), info.escalaMundo)
	if not anim then return nil end
	corpo.Transparency = 1
	local dirVisual = corpo.CFrame.LookVector
	local function animar(dt, pos, direcao, andando, velocidade, olharPara)
		local plano = Vector3.new(direcao.X, 0, direcao.Z)
		if plano.Magnitude > 0.01 then
			dirVisual = dirVisual:Lerp(plano.Unit, math.min(1, dt * 10))
			if dirVisual.Magnitude < 0.05 then dirVisual = plano.Unit else dirVisual = dirVisual.Unit end
		end
		local chao = pos - Vector3.new(0, 1.5, 0)
		anim:atualizar(dt, CFrame.lookAt(chao, chao + dirVisual), andando, velocidade, olharPara)
	end
	return animar, anim
end

return M
