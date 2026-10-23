-- Viagem entre regiões da run (PLANO §12, R4): custo em dias, sorteio de eventos, prévia da próxima
-- região e opções vetadas por defeito. Pura: o gerador é injetado; quem vota é RunVotacao e quem
-- gasta o prazo é Run. Valores PROVISÓRIOS (docs/FIDELIDADE.md "R4a").
local Shared = game:GetService("ReplicatedStorage").Shared
local Run = require(Shared.Regras.Run)
local Sorteios = require(Shared.Regras.RunSorteios)
local Defeitos = require(Shared.Regras.RunDefeitos)

local Combate = require(Shared.Regras.Combate)
local Pericias = require(Shared.Livro.Dados.Pericias)

local Viagem = {}

-- Liderar a marcha ignora terreno difícil natural (Navegação e Liderança): viagem 25% mais curta.
Viagem.FATOR_EXPLORADOR = 0.75
-- Com Explorador, eventos bons pesam o dobro e os ruins a metade (arredondado para o inteiro mais próximo, mínimo 1).
Viagem.PESO_EXPLORADOR_BOM = 2
Viagem.PESO_EXPLORADOR_RUIM = 0.5
Viagem.PASSO_PREVIA = 5 -- a prévia mostra chances em múltiplos de 5%

local function arredondarAoQuarto(dias)
	return math.max(0.25, math.floor(dias * 4 + 0.5) / 4)
end

-- etapas = trechos da rota (>= 1). modo = "pe" | "cavalo". Devolve dias de jogo (múltiplo de 0,25).
function Viagem.custoEmDias(etapas, modo, grupoComExplorador)
	if type(etapas) ~= "number" or etapas < 1 or etapas % 1 ~= 0 then return nil, "Etapas inválidas." end
	local porEtapa
	if modo == "pe" then porEtapa = Run.CUSTO_DIAS.viagemAPe
	elseif modo == "cavalo" then porEtapa = Run.CUSTO_DIAS.viagemACavalo
	else return nil, "Modo de viagem inválido." end
	local dias = etapas * porEtapa
	if grupoComExplorador == true then dias = arredondarAoQuarto(dias * Viagem.FATOR_EXPLORADOR) end
	return dias
end

-- evento = { id, tom = "bom"|"neutro"|"ruim", peso (inteiro >= 1), regioes = { id... } | nil (qualquer),
--            modo = "pe"|"cavalo"|nil, opcoes = { { id, tags = {...}|nil, dias = n|nil }... } }
local function pesoDoEvento(evento, grupoComExplorador)
	local peso = evento.peso
	if grupoComExplorador == true then
		if evento.tom == "bom" then peso *= Viagem.PESO_EXPLORADOR_BOM
		elseif evento.tom == "ruim" then peso *= Viagem.PESO_EXPLORADOR_RUIM end
	end
	return math.max(1, math.floor(peso + 0.5))
end

local function ocorreNaRegiao(evento, regiao)
	if evento.regioes == nil then return true end
	for _, r in evento.regioes do
		if r == regiao then return true end
	end
	return false
end

-- Sorteia `quantidade` eventos distintos para a viagem até `regiao`. Cavalo e Explorador mudam o que ocorre:
-- evento com `modo` só vale se o grupo viaja assim; Explorador favorece os bons e reduz os ruins.
function Viagem.sortearEventos(catalogo, regiao, quantidade, rng, contexto)
	contexto = contexto or {}
	if type(catalogo) ~= "table" or type(regiao) ~= "string" then return nil, "Viagem inválida." end
	local itens = {}
	for _, e in catalogo do
		if type(e) ~= "table" or type(e.id) ~= "string" or type(e.peso) ~= "number" or e.peso < 1 then
			return nil, "Evento inválido."
		end
		if ocorreNaRegiao(e, regiao) and (e.modo == nil or e.modo == contexto.modo) then
			table.insert(itens, { id = e.id, peso = pesoDoEvento(e, contexto.explorador) })
		end
	end
	return Sorteios.ponderado(itens, quantidade, rng)
end

-- Característica de região = { id, chance (0–100) }. Só um grupo com Explorador as vê, antes de votar,
-- e sem os itens/eventos exatos; a chance mostrada é arredondada ao passo da prévia.
function Viagem.previaDaRegiao(caracteristicas, grupoComExplorador)
	if grupoComExplorador ~= true or type(caracteristicas) ~= "table" then return {} end
	local lista = {}
	for _, c in caracteristicas do
		if type(c) == "table" and type(c.id) == "string" and type(c.chance) == "number" and c.chance >= 0 and c.chance <= 100 then
			local chance = math.floor(c.chance / Viagem.PASSO_PREVIA + 0.5) * Viagem.PASSO_PREVIA
			table.insert(lista, { id = c.id, chance = chance })
		end
	end
	table.sort(lista, function(a, b)
		if a.chance ~= b.chance then return a.chance > b.chance end
		return a.id < b.id
	end)
	return lista
end

-- Quem não pode escolher a opção por causa dos defeitos. defeitosPorJogador = { [userId] = { defeitoId... } }.
function Viagem.vetadosNaOpcao(opcao, defeitosPorJogador)
	local vetados = {}
	if type(opcao) ~= "table" or type(defeitosPorJogador) ~= "table" then return vetados end
	for userId, ids in defeitosPorJogador do
		if Defeitos.bloqueiaOpcao(ids, opcao.tags) then table.insert(vetados, userId) end
	end
	table.sort(vetados, function(a, b) return tostring(a) < tostring(b) end)
	return vetados
end

-- Ficha v2 calculada por Criacao/PericiasPersonagem no servidor.
local ATRIBUTOS = { ["Força"] = "forca", Agilidade = "agilidade", Vigor = "vigor", Intelecto = "intelecto", ["Espírito"] = "espirito",
 forca = "forca", agilidade = "agilidade", vigor = "vigor", intelecto = "intelecto", espirito = "espirito" }
function Viagem.bonusDaFicha(ficha, nome)
 local c = ficha and ficha.calculated
 if not c then return nil, "Crie uma ficha antes de testar." end
 local atributo = ATRIBUTOS[nome]
 if atributo then return c.attributes and c.attributes[atributo] end
 for _, p in Pericias do
  if p.data.name == nome then
   for _, skill in c.skills or {} do if skill.skillId == p.id then return skill.bonus end end
  end
 end
 return nil, "Perícia não calculada na ficha."
end

function Viagem.resolverTeste(opcao, rng, bonus, desvantagem)
 if not opcao.teste then return { desfecho = opcao.sucesso or {} } end
 local teste = opcao.teste
 if type(teste.pericia) ~= "string" or type(teste.cd) ~= "number" or teste.cd ~= teste.cd or math.abs(teste.cd) == math.huge
  or type(bonus) ~= "number" or bonus ~= bonus or math.abs(bonus) == math.huge then return nil, "Teste inválido." end
 local r = Combate.resistencia(rng, bonus, teste.cd, false, desvantagem)
 return { pericia = teste.pericia, cd = r.cd, bonus = bonus, dados = r.d20.dados, natural = r.d20.natural,
  ajuste = r.d20.ajuste, total = r.total, sucesso = r.passou,
  desfecho = (if r.passou then opcao.sucesso else opcao.falha) or {} }
end

-- resolução vem exclusivamente do servidor; legado mantém dias e flag.
function Viagem.podePagar(run, opcao)
 local custo = if not opcao.teste and opcao.sucesso then -(opcao.sucesso.ouro or 0) else 0
 return (run.ouroViagem or 0) >= custo
end

function Viagem.aplicarOpcao(run, evento, opcaoId, resolucao)
 if type(evento) ~= "table" or type(evento.opcoes) ~= "table" then return nil, nil, "Evento inválido." end
 local opcao
 for _, o in evento.opcoes do if o.id == opcaoId then opcao = o end end
 if not opcao then return nil, nil, "Opção inexistente." end
 if not Viagem.podePagar(run, opcao) then return nil, nil, "Caixa da viagem insuficiente." end
 if opcao.teste and not resolucao then return nil, nil, "Teste não resolvido." end
 local desfecho = (resolucao and resolucao.desfecho) or opcao.sucesso or {}
 local dias = (opcao.dias or 0) + (desfecho.dias or 0)
 local atual, expirou, motivo = Run.ajustarDiasViagem(run, dias)
 if not atual then return nil, nil, motivo end
 local ouroAnterior = atual.ouroViagem or 0
 atual = table.clone(atual)
 atual.ouroViagem = math.max(0, ouroAnterior + (desfecho.ouro or 0))
 if desfecho.flag then atual, motivo = Run.definirFlag(atual, desfecho.flag) end
 if not atual then return nil, nil, motivo end
 atual, motivo = Run.definirFlag(atual, "evento/" .. evento.id .. "/" .. opcao.id)
 if not atual then return nil, nil, motivo end
 local recibo = resolucao and table.clone(resolucao) or {}
 recibo.desfecho = nil
 recibo.evento, recibo.opcao, recibo.texto = evento.id, opcao.id, desfecho.texto or opcao.texto or ""
 recibo.dias, recibo.ouro, recibo.flag = atual.dia - run.dia, atual.ouroViagem - ouroAnterior, desfecho.flag
 atual.ultimoEvento = recibo
 return atual, expirou
end

return Viagem
