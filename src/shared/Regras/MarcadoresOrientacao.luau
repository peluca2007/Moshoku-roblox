-- Glifos de interação e projeção de setas para alvos fora da tela. Sem dependências Roblox.
local Marcadores = {}

function Marcadores.glifo(npc, estado)
	if type(npc) ~= "table" then return nil end
	if npc.tipo == "treinador" then
		local run = estado and estado.run
		local plano = run and run.plano or {}
		local arvore = estado and estado.arvore or plano.escolhida or plano.arvore
		local provacaoAtiva = estado and estado.provacao and estado.provacao.estado == "em-curso"
		if run and not run.semRun and not run.fim and (run.diasRestantes or 0) >= 1
			and not arvore and not provacaoAtiva and plano.modo == "semArvore" and npc.disponivel == true then return "!" end
		return nil
	elseif npc.tipo == "missao" then
		if npc.concluir == true then return "?" end
		if npc.novo == true then return "!" end
	elseif npc.tipo == "loja" and npc.novo == true then
		return "!"
	end
	return nil
end

-- x/y são deslocamentos do centro em pixels; margem só controla até onde desenhar a seta.
function Marcadores.borda(x, y, z, largura, altura, margem)
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number"
		or type(largura) ~= "number" or type(altura) ~= "number" or largura <= 0 or altura <= 0 then return nil end
	local mx = math.clamp(margem or 24, 0, largura / 2)
	local my = math.clamp(margem or 24, 0, altura / 2)
	local hx, hy = largura / 2 - mx, altura / 2 - my
	if z > 0 and math.abs(x) <= largura / 2 and math.abs(y) <= altura / 2 then return nil end
	if z <= 0 then x, y = -x, -y end
	if x == 0 and y == 0 then y = -1 end
	local escala = math.min(hx / math.max(math.abs(x), 1e-9), hy / math.max(math.abs(y), 1e-9))
	local px, py = x * escala, y * escala
	return { x = largura / 2 + px, y = altura / 2 + py, rotacao = math.deg(math.atan2(y, x)) }
end

return Marcadores
