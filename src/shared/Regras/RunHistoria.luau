-- Esqueleto da história em árvore da run (PLANO §12). Pura: valida e navega por dados, sem rede nem Instances.
-- historia = { id, inicio = <no>, nos = { [id] = no } }
-- no.luta (só em tipo "chefe") = { criaturas = { id canônico... }, areaId }: ao chegar aqui a run espera a luta.
-- no = { tipo = "vila"|"viagem"|"regiao"|"chefe"|"final", regiao = id|nil, titulo, opcoes = { opcao... } }  (final não tem opções)
-- opcao = { id, texto, para = <no>, dias = n|nil, exige = { flag = nome|nil }|nil, marca = flag|nil }
-- Trancas são flags da run (Run.definirFlag): abertas por item, habilidade de árvore, escolha da história ou
-- desbloqueio permanente (o jogo decide quem chama definirFlag). Aqui só se verifica se estão abertas.
local Run = require(game:GetService("ReplicatedStorage").Shared.Regras.Run)

local Historia = {}

local TIPOS = { vila = true, viagem = true, regiao = true, chefe = true, final = true }

-- Devolve true ou false + lista de problemas. Garante: início existe, todo destino existe, só `final` não
-- tem opções, ids de opção únicos por nó, e todo nó é alcançável a partir do início com ao menos um final alcançável.
function Historia.validar(h)
	local problemas = {}
	local function p(msg) table.insert(problemas, msg) end
	if type(h) ~= "table" or type(h.nos) ~= "table" or type(h.inicio) ~= "string" then return false, { "Estrutura inválida." } end
	if h.nos[h.inicio] == nil then p("Início inexistente: " .. h.inicio) end
	for id, no in h.nos do
		if type(no) ~= "table" or not TIPOS[no.tipo] then
			p("Tipo inválido em " .. tostring(id))
		elseif no.luta ~= nil and (no.tipo ~= "chefe" or type(no.luta) ~= "table" or type(no.luta.criaturas) ~= "table"
			or #no.luta.criaturas < 1 or type(no.luta.areaId) ~= "string") then
			p("Luta inválida em " .. tostring(id))
		elseif no.tipo == "final" then
			if no.opcoes and #no.opcoes > 0 then p("Final com opções: " .. id) end
		else
			if type(no.opcoes) ~= "table" or #no.opcoes < 1 then p("Sem saída: " .. id) end
			local vistos = {}
			for _, op in no.opcoes or {} do
				if type(op.id) ~= "string" or vistos[op.id] then p("Opção sem id ou repetida em " .. id) end
				vistos[op.id] = true
				if h.nos[op.para] == nil then p("Destino inexistente em " .. id .. "/" .. tostring(op.id) .. ": " .. tostring(op.para)) end
				if op.dias ~= nil and (type(op.dias) ~= "number" or op.dias < 0 or (op.dias / 0.25) % 1 ~= 0) then
					p("Dias inválidos em " .. id .. "/" .. tostring(op.id))
				end
			end
		end
	end
	-- Alcance: busca em largura ignorando trancas (uma tranca fechada só atrasa; o desenho deve poder abri-la).
	local alcancados, fila, finais = {}, { h.inicio }, 0
	alcancados[h.inicio] = true
	while #fila > 0 do
		local id = table.remove(fila, 1)
		local no = h.nos[id]
		if no then
			if no.tipo == "final" then finais += 1 end
			for _, op in no.opcoes or {} do
				if h.nos[op.para] and not alcancados[op.para] then
					alcancados[op.para] = true
					table.insert(fila, op.para)
				end
			end
		end
	end
	for id in h.nos do
		if not alcancados[id] then p("Inalcançável: " .. id) end
	end
	if finais < 1 then p("Nenhum final alcançável.") end
	return #problemas == 0, problemas
end

-- Opções do nó onde a run está (`run.galho`), com a marca de liberada e o motivo se trancada.
function Historia.opcoes(h, run)
	local no = h.nos[run.galho]
	if not no or no.tipo == "final" then return {} end
	local lista = {}
	for _, op in no.opcoes do
		local liberada, motivo = true, nil
		if op.exige and op.exige.flag and not Run.temFlag(run, op.exige.flag) then
			liberada, motivo = false, "Trancado: " .. op.exige.flag
		end
		table.insert(lista, { id = op.id, texto = op.texto, para = op.para, dias = op.dias or 0, liberada = liberada, motivo = motivo })
	end
	return lista
end

-- Aplica a opção escolhida (já votada): confere a tranca, gasta dias, marca a flag, move a run e encerra em final.
-- Devolve (novaRun, expirou) ou (nil, nil, motivo).
function Historia.avancar(h, run, opcaoId)
	if Run.encerrada(run) then return nil, nil, "A run já terminou." end
	local no = h.nos[run.galho]
	if not no or no.tipo == "final" then return nil, nil, "Nó sem saída." end
	local op
	for _, o in no.opcoes do
		if o.id == opcaoId then op = o end
	end
	if not op then return nil, nil, "Opção inexistente." end
	if op.exige and op.exige.flag and not Run.temFlag(run, op.exige.flag) then
		return nil, nil, "Trancado: " .. op.exige.flag
	end
	local atual, expirou = run, false
	if op.dias and op.dias > 0 then
		local novo, venceu, motivo = Run.gastarDias(atual, op.dias)
		if not novo then return nil, nil, motivo end
		atual, expirou = novo, venceu
	end
	if op.marca then
		local novo, motivo = Run.definirFlag(atual, op.marca)
		if not novo then return nil, nil, motivo end
		atual = novo
	end
	local destino = h.nos[op.para]
	local movido, motivo = Run.moverPara(atual, destino.regiao or atual.regiao, op.para)
	if not movido then return nil, nil, motivo end
	if destino.tipo == "final" then
		-- Um final que cumpre o objetivo (`cumpreObjetivo`) o marca antes de encerrar, se ainda estiver ativo.
		if destino.cumpreObjetivo and movido.objetivo.status == "ativo" then
			movido = Run.cumprirObjetivo(movido)
		end
		local fim, motivoFim = Run.encerrarComFinal(movido, op.para)
		if not fim then return nil, nil, motivoFim end
		return fim, expirou
	end
	return movido, expirou
end

return Historia
