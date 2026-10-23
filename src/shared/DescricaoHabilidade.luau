-- Consulta da mecânica executável, sem rolar ou autorizar ações.
local D = {}
local Arma = require(game:GetService("ReplicatedStorage").Shared.Regras.Arma)
local Execucao = require(game:GetService("ReplicatedStorage").Shared.Regras.Execucao)
local Balanceamento = require(game:GetService("ReplicatedStorage").Shared.BalanceamentoJogo)
function D.contexto(m, ficha, catalogo, id, token)
	if not ficha then return nil end
	local arvore = m.arvore or Execucao.arvoreDe(id) or Execucao.arvoreDeCorpo(ficha, catalogo)
	local bc = Execucao.bc(ficha, arvore, catalogo)
	local rank = Execucao.bonusDeRankDa(ficha, arvore)
	local a = Arma.daFicha(ficha, catalogo, m.armaADistancia and not m.desarmaConjurador)
	local attrs = ficha.calculated.attributes
	local acerto = if m.atributoAcerto then (attrs[m.atributoAcerto] or 0) + rank elseif m.arma then Execucao.atributoDaArma(arvore, a.atributo, ficha, catalogo) + a.bonusDeRank else bc
	return {bc=bc,rank=rank,atributos=attrs,dadoArma="1"..a.dado,acerto=acerto+(m.bonusAcerto or 0)+Balanceamento.acerto(token or {})}
end
local function dano(m, ctx)
	local p = {}
	for _, d in m.dados or {} do table.insert(p, d) end
	for _, v in m.partes or {} do
		local s = v.dados or (v.arma and (ctx and ctx.dadoArma or "dado da arma")) or (v.fixo and tostring(v.fixo))
		if s then table.insert(p, s .. (if v.metade then " / 2" else "")) end
		if v.atributo then table.insert(p,tostring(ctx and ctx.atributos[v.atributo] or v.atributo)) end
		if v.rank then table.insert(p,tostring(ctx and ctx.rank or "Rank")) end
		if v.somaBc or v.bc then table.insert(p, tostring(ctx and ctx.bc or "BC")) end
	end
	if m.somaBc then table.insert(p, tostring(ctx and ctx.bc or "BC")) end
	if #p == 0 then return nil end
	return table.concat(p, " + ") .. (if m.tipoDano then " (" .. m.tipoDano .. ")" else "")
end
function D.texto(m, t, ctx): string
	local linhas = {}
	local bonusAcerto, bonusCD = Balanceamento.acerto(t or {}), Balanceamento.cd(t or {})
	local alcance = if m.alvo == "si" or m.forma == "esferaNoConjurador" then "Você" elseif m.corpoACorpo then "Corpo a corpo • 1 casa" elseif m.alcanceCasas then tostring(m.alcanceCasas) .. " casas (" .. tostring(m.alcanceCasas * 1.5) .. " m)" else "Sem alvo externo"
	table.insert(linhas, "Alcance: " .. alcance)
	local d = dano(m, ctx)
	if d then table.insert(linhas, "Dano: " .. d) end
	if m.tipo == "ataque" or m.tipo == "investida" then
		table.insert(linhas, "Acerto: d20 + " .. (if m.atributoAcerto then m.atributoAcerto .. " + Rank" elseif m.arma then "bônus da arma" else "BC") .. (if bonusAcerto ~= 0 then " + " .. bonusAcerto .. " do jogo" else "") .. " contra CA. 1 natural erra; 20 é crítico.")
		if ctx then table.insert(linhas, string.format("Seu acerto: d20 %+d (antes de condições, cobertura e reações).",ctx.acerto)) end
	end
	local r = m.resistencia or (m.efeitoNoAcerto and m.efeitoNoAcerto.resistencia)
	if r then
		local cd = (r.cdBase or 8) + (r.extra or 0) + bonusCD
		table.insert(linhas, "Resistência: " .. r.atributo .. " contra CD " .. cd .. " + " .. (if r.cdAtributo then r.cdAtributo .. " + Rank" else "BC") .. (if m.metadeNoSucesso then "; passa: metade do dano." else "; passa: evita o efeito resistido."))
		if ctx then table.insert(linhas, "Sua CD: " .. (cd + (if r.cdAtributo then (ctx.atributos[r.cdAtributo] or 0) + ctx.rank else ctx.bc))) end
	end
	if m.raioCasas then table.insert(linhas, "Área: raio de " .. m.raioCasas .. " casas") end
	if m.comprimentoCasas then table.insert(linhas, "Área: " .. m.comprimentoCasas .. " casas de comprimento") end
	if m.maxAlvos then table.insert(linhas, "Até " .. m.maxAlvos .. " alvos") end
	if m.umaVezPorTurno then table.insert(linhas, "Limite: uma vez por turno") end
	local dur = m.duracaoRodadas or (m.duracao and m.duracao.rodadas)
	if dur then table.insert(linhas, "Duração: " .. dur .. " rodadas") end
	if m.desarmaConjurador then table.insert(linhas, "Sua arma fica na casa do alvo, acertando ou errando. Pegar arma: 1 Ação, até 1 casa.") end
	if m.bloqueiaMovimento then table.insert(linhas, "Barreira: bloqueia passagem" .. (if m.pvZona then " • " .. m.pvZona .. " PV" else "")) end
	if m.descricao then table.insert(linhas, m.descricao) end
	return table.concat(linhas, "\n\n")
end
return D
