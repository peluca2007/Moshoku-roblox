-- Decide o que a interface da expedição mostra a partir da `visao` do RunSessao e do estado local.
-- Módulo puro: não cria Instances nem envia eventos; a ExpedicaoView só monta o que isto devolve.
--
-- estado local = { emCombate?, portaAberta?, levantadoEm? (galho cujo acampamento já foi levantado),
--   esperaLuta? (segundos seguidos com luta pendente sem combate), agoraNaoEm? (assinatura de votos dispensada),
--   confirmaAbandono? (primeiro toque em "Voltar à cidade" da luta pendente já dado) }
-- decidir(visao, estado, nomeDe?) -> { faixa?, tela, ... }
--   tela: "nenhuma" | "luta" | "lutaPendente" | "porta" | "acampamento" | "escolhas"
local Esgoto = require(game:GetService("ReplicatedStorage").Shared.Mundo.ExpedicaoEsgoto)
local ExpedicaoTela = {}

-- Antes disso o servidor ainda inicia a luta sozinho (1–2 s depois do voto): não mostrar a tela para não piscar.
ExpedicaoTela.ESPERA_LUTA = 3
-- Abaixo desta largura (px de interface) os cartões de caminho empilham.
ExpedicaoTela.LARGURA_EMPILHAR = 700

local ID_VOLTAR = "voltar-a-cidade"

-- 0.5 -> "meio dia"; 1 -> "1 dia"; 1.5 -> "1,5 dia"; 2 -> "2 dias". nil se não custa nada.
function ExpedicaoTela.custoEmDias(dias)
	if type(dias) ~= "number" or dias <= 0 then return nil end
	if dias == 0.5 then return "meio dia" end
	if dias == 1 then return "1 dia" end
	if dias == math.floor(dias) then return string.format("%d dias", dias) end
	return (string.format("%.1f", dias):gsub("%.", ",")) .. " dias"
end

function ExpedicaoTela.nomeDaArea(area)
	if type(area) ~= "string" or area == "" then return nil end
	local nome = area:gsub("[-_]", " ")
	return nome:sub(1, 1):upper() .. nome:sub(2)
end

local function restantes(dias)
	if type(dias) ~= "number" then return nil end
	local texto = if dias == math.floor(dias) then string.format("%d", dias) else (string.format("%.1f", dias):gsub("%.", ","))
	return if dias == 1 then "falta 1 dia" else "faltam " .. texto .. " dias"
end

-- Faixa do topo: "Dia 3 · faltam 9 dias" e, dentro da área, "Sala 2/5 · Esgoto".
function ExpedicaoTela.faixa(visao)
	if type(visao) ~= "table" or visao.semRun or visao.erro or type(visao.dia) ~= "number" then return nil end
	local partes = { string.format("Dia %d", math.floor(visao.dia) + 1) }
	local falta = restantes(visao.diasRestantes)
	if falta then table.insert(partes, falta) end
	local contador
	if visao.area and type(visao.passo) == "number" and type(visao.totalPassos) == "number" then
		contador = string.format("Sala %d/%d · %s", visao.passo, visao.totalPassos, ExpedicaoTela.nomeDaArea(visao.area) or "")
	end
	return { dia = table.concat(partes, " · "), contador = contador }
end

local function ehHub(visao) return visao.tipoDoNo == "hub" end

local function lugar(visao)
	return { galho = visao.galho, luta = visao.fase == "luta" }
end

-- Tela "Viajando…": o nó mudou ou a fase entrou/saiu de "luta". Devolve (viajar, nova memória).
function ExpedicaoTela.viajar(anterior, visao)
	if type(visao) ~= "table" or visao.semRun or visao.erro or visao.galho == nil then return false, anterior end
	local agora = lugar(visao)
	if anterior == nil then return false, agora end
	return anterior.galho ~= agora.galho or anterior.luta ~= agora.luta, agora
end

-- "Trancado: fragmento/esgoto" -> "Precisa do fragmento do esgoto"; textos do servidor já legíveis passam direto.
function ExpedicaoTela.motivoLegivel(motivo)
	if type(motivo) ~= "string" or motivo == "" then return nil end
	local area = motivo:match("^Trancado: fragmento/(.+)$")
	if area then return "Precisa do fragmento do " .. area:gsub("[-_]", " ") end
	if motivo:match("^Trancado:") then return "Ainda trancado" end
	return motivo
end

local function maiorVoto(visao)
	local maior = 0
	for _, n in visao.contagem or {} do
		if n > maior then maior = n end
	end
	return maior
end

local function cartao(op, visao, grupoGrande, maior)
	local votos = visao.contagem and visao.contagem[op.id] or 0
	return {
		id = op.id, titulo = op.texto, dica = op.dica, custo = ExpedicaoTela.custoEmDias(op.dias),
		liberada = op.liberada == true, motivo = if op.liberada == true then nil else ExpedicaoTela.motivoLegivel(op.motivo),
		votada = visao.votei == op.id,
		votos = if grupoGrande then votos else nil, votosTexto = if grupoGrande then "Votos: " .. votos else nil,
		maisVotada = grupoGrande and maior > 0 and votos == maior,
		rotuloVotar = if visao.votei == op.id then "Meu voto" elseif grupoGrande then "Votar" else "Escolher",
	}
end

local function opcoes(visao, filtro)
	local grupoGrande = #(visao.grupo or {}) > 1
	local maior = maiorVoto(visao)
	local cartoes = {}
	for _, op in visao.opcoes or {} do
		if filtro(op) then table.insert(cartoes, cartao(op, visao, grupoGrande, maior)) end
	end
	return cartoes
end

-- Disposição dos cartões: "lado" (linha) ou "pilha" (coluna) conforme a largura da interface; teto de largura por quantidade.
function ExpedicaoTela.disposicao(larguraTela, quantidade)
	local largura = if quantidade >= 3 then 860 elseif quantidade == 2 then 600 else 420
	local modo = if type(larguraTela) == "number" and larguraTela < ExpedicaoTela.LARGURA_EMPILHAR then "pilha" else "lado"
	return { modo = modo, larguraMax = if modo == "pilha" then 420 else largura }
end

-- Assinatura dos votos em andamento ("" sem nenhum): muda quando alguém vota ou retira o voto.
function ExpedicaoTela.assinaturaVotos(visao)
	local partes = {}
	for id, n in visao.contagem or {} do
		if n > 0 then table.insert(partes, id .. "=" .. n) end
	end
	table.sort(partes)
	return table.concat(partes, ",")
end

-- Quem falta votar, só em grupo; em jogo solo o voto resolve na hora.
local function votacao(visao, nomeDe)
	if #(visao.grupo or {}) <= 1 or not visao.aguardando or #visao.aguardando == 0 then return nil end
	local nomes = {}
	for _, id in visao.aguardando do table.insert(nomes, if nomeDe then nomeDe(id) else tostring(id)) end
	return "Aguardando voto: " .. table.concat(nomes, ", ")
end

local function membros(visao, nomeDe)
	local lista = {}
	for _, m in visao.grupo or {} do
		local nome = if nomeDe then nomeDe(m.userId) else tostring(m.userId)
		table.insert(lista, if m.presente == false then nome .. " (ausente)" elseif m.caido then nome .. " (caído)" else nome)
	end
	return lista
end

-- Custo em dias de abandonar a luta pendente: o mesmo do servidor, max(1, (passo - 1) * voltarPorPasso).
function ExpedicaoTela.custoAbandonar(passo)
	local porPasso = Esgoto.AREA.custos.voltarPorPasso
	return math.max(1, ((if type(passo) == "number" then passo else 1) - 1) * porPasso)
end

local function lutaPendente(visao, estado, faixa)
	local base = "Voltar à cidade (" .. ExpedicaoTela.custoEmDias(ExpedicaoTela.custoAbandonar(visao.passo)) .. ")"
	return {
		faixa = faixa, tela = "lutaPendente",
		titulo = (visao.luta and visao.luta.titulo) or visao.titulo or "Uma luta aguarda o grupo",
		erro = visao.lutaErro,
		entrar = { texto = if visao.lutaErro then "Tentar de novo" else "Entrar na luta" },
		abandonar = {
			texto = if estado.confirmaAbandono then "Toque de novo para confirmar: " .. base else base,
			confirmando = estado.confirmaAbandono == true,
		},
	}
end

function ExpedicaoTela.decidir(visao, estado, nomeDe)
	estado = estado or {}
	local faixa = ExpedicaoTela.faixa(visao)
	local saida = { faixa = faixa, tela = "nenhuma" }
	if not faixa or visao.fim then return saida end
	if estado.emCombate == true then saida.tela = "luta"; return saida end
	if visao.fase == "luta" or visao.luta then
		if visao.lutaErro or (estado.esperaLuta or 0) >= ExpedicaoTela.ESPERA_LUTA then
			return lutaPendente(visao, estado, faixa)
		end
		saida.tela = "luta"
		return saida
	end
	saida.votacao = votacao(visao, nomeDe)
	saida.retirarVoto = visao.votei ~= nil
	if ehHub(visao) then
		local assinatura = ExpedicaoTela.assinaturaVotos(visao)
		local votoAlheio = assinatura ~= "" and visao.votei == nil and estado.agoraNaoEm ~= assinatura
		if estado.portaAberta == true or votoAlheio then
			saida.tela = "porta"
			saida.cartoes = opcoes(visao, function(op) return op.id ~= ID_VOLTAR end)
			saida.fechar = if estado.portaAberta == true then { nome = "Cancelar", texto = "Cancelar" } else { nome = "AgoraNao", texto = "Agora não" }
		end
		return saida
	end
	if not visao.area then return saida end
	local voltar
	for _, op in visao.opcoes or {} do
		if op.id == ID_VOLTAR then
			local custo = ExpedicaoTela.custoEmDias(op.dias)
			voltar = { id = op.id, texto = if custo then "Voltar à cidade (" .. custo .. ")" else "Voltar à cidade", liberada = op.liberada == true }
		end
	end
	saida.voltar = voltar
	if visao.fase == "acampamento" and estado.levantadoEm ~= visao.galho then
		saida.tela = "acampamento"
		saida.grupo = membros(visao, nomeDe)
		local d = visao.descansos
		if d then
			saida.descansar = { texto = string.format("Descansar · meio dia · %d/%d", d.usados, d.max), desabilitado = d.usados >= d.max }
		end
		saida.levantar = { texto = "Pronto" }
		return saida
	end
	saida.tela = "escolhas"
	saida.titulo = "Para onde seguir?"
	saida.subtitulo = visao.titulo
	saida.cartoes = opcoes(visao, function(op) return op.id ~= ID_VOLTAR end)
	return saida
end

-- Texto do fim da run, nunca o id cru.
function ExpedicaoTela.textoFim(visao)
	local fim = type(visao) == "table" and visao.fim or nil
	if not fim then return nil end
	if fim.motivo == "final" then
		if fim.final == "final-campanha" or visao.galho == "final-campanha" then return "A anomalia foi selada." end
		return "A história chegou ao fim."
	end
	if type(visao.objetivo) == "table" and visao.objetivo.status == "expirado" then return "O prazo se esgotou. A expedição terminou." end
	return "O grupo caiu. A expedição terminou."
end

-- Diário da expedição (RunView): só o que a visão permite saber.
function ExpedicaoTela.diario(visao, nomeDe)
	if type(visao) ~= "table" or visao.semRun or visao.erro or type(visao.dia) ~= "number" then return nil end
	local d = { dia = ExpedicaoTela.faixa(visao).dia, grupo = membros(visao, nomeDe), fim = ExpedicaoTela.textoFim(visao) }
	if visao.area then
		d.lugar = string.format("%s · sala %s", ExpedicaoTela.nomeDaArea(visao.area) or "", tostring(visao.passo or "?"))
			.. (if visao.totalPassos then "/" .. visao.totalPassos else "")
	elseif ehHub(visao) then
		d.lugar = "Na cidade"
	end
	if visao.descansos then d.descansos = string.format("Descansos usados: %d/%d", visao.descansos.usados, visao.descansos.max) end
	if ehHub(visao) then
		for _, op in visao.opcoes or {} do
			if op.id == "selar-a-anomalia" and op.liberada == true then d.concluida = "Esgoto concluído · fragmento obtido" end
		end
	end
	return d
end

function ExpedicaoTela.avisoConcluida(dado)
	local ouro = type(dado) == "table" and type(dado.ouro) == "number" and dado.ouro or 0
	local detalhe = if ouro > 0 then string.format("+%d de ouro · fragmento do esgoto", ouro) else "Fragmento do esgoto · de volta à cidade."
	return { titulo = "Expedição concluída", detalhe = detalhe }
end

return ExpedicaoTela
