-- Resolvedor genérico de habilidades (puro; RNG injetado). Recebe a mecânica
-- estruturada (Regras/<árvore>), o conjurador e os alvos já validados pelo
-- servidor (vez, Ações, recursos, alcance, visão e geometria são do servidor) e
-- devolve o que aconteceu com cada alvo. Não muda estado: o servidor aplica.
--
-- Como no simulador do site (combatSim `resolver`, `defesaDaParte`):
-- - Vantagem/Desvantagem pelas MECÂNICAS das condições do catálogo
--   (desvantagemEmAtaques, vantagemParaQuemAtaca, vantagemCorpoACorpo,
--   desvantagemADistancia, desvantagemEmTestes); atacante Escondido: Vantagem;
-- - Quebrantado: −1 de CA do alvo e −1 no dano de quem ataca, por acúmulo;
-- - dano em parcelas tipadas: Resistência corta a parcela pela metade (para
--   baixo), Imunidade zera; imune ao tipo da condição (ígneo) não a pega;
-- - crítico rola de novo os DADOS de todas as parcelas; fixos somam uma vez.
-- NÃO suportado, e avisado na nota: o nível de Exaustão.
--
-- Esquema da mecânica (ver docs/FIDELIDADE.md §7A/§7B):
--   tipo: "ataque" | "efeito" | "cura"   (os demais tipos são só do servidor)
--   partes: { { dados?, arma?, degrau?, metade?, bc?, tipo?, dobraContra? } }
--     (formato curto do Fogo: dados + tipoDano + somaBc vira partes)
--   aplica: id ou lista; empurraCasas; acertoAutomaticoContra; bonusAcerto;
--   efeitoNoAcerto = { resistencia, aplica, empurraCasas };
--   resistencia = { atributo, cdBase }; semTeste; metadeNoSucesso; doses;
--   inverteDoses; cura: pvTemporarios, dobraComFeridaFresca, curaAtributo, curaRank.
local Combate = require(game:GetService("ReplicatedStorage").Shared.Regras.Combate)
local Arma = require(game:GetService("ReplicatedStorage").Shared.Regras.Arma)

local Agarrar = require(game:GetService("ReplicatedStorage").Shared.Regras.Agarrar)

local Habilidades = {}

export type Conjurador = {
	bc: number,
	pv: number,
	pvMax: number,
	condicoes: { [string]: number },
	atributos: { [string]: number }?,
	arma: { dado: string, bonus: number }?,
	bonusDeRank: number?,
	bonusAcertoJogo: number?,
	bonusCDJogo: number?,
	danoCheioEmChamas: boolean?,
	dadoExtraContra: string?,
	jaAcertou: boolean?,
	primeiroAtaque: boolean?,
	condutorDeGelo: boolean?,
	auxilio: boolean?,
	id: string?,
	odioPor: string?,
}
export type Alvo = {
	id: string,
	patamar: number?,
	ca: number,
	condicoes: { [string]: number },
	resistencia: (atributo: string) -> number,
	resistencias: { string }?,
	imunidades: { string }?,
	reduzIgneo: boolean?,
	feridaFresca: boolean?,
	respira: boolean?,
	antidoto: boolean?,
	molhadoPor: string?,
	esquivaContra: string?,
	bonusContraMarcado: number?,
}
export type Efeito = {
	alvoId: string,
	ataque: Combate.Ataque?,
	segundoAtaque: Combate.Ataque?,
	danosDisparos: { number }?,
	ambosAcertaram: boolean?,
	estados: { any }?,
	quebrantado: number?,
	resistencia: Combate.Resistencia?,
	dano: Combate.Dano?,
	cura: number?,
	pvTemp: number?,
	aplica: { string }?,
	remove: { string }?,
	doses: number?,
	empurrar: number?,
	notas: { string },
}

-- Tipo da condição aplicada (a imunidade ao tipo impede a condição).
local TIPO_DA_CONDICAO = { ["em-chamas"] = "ígneo" }

local function contem(lista: { string }?, tipo: string?): boolean
	if not lista or not tipo then
		return false
	end
	for _, item in lista do
		if string.find(tipo, item, 1, true) then
			return true
		end
	end
	return false
end

local function comoLista(valor): { string }
	if valor == nil then
		return {}
	elseif type(valor) == "string" then
		return { valor }
	end
	return table.clone(valor)
end

-- Formato curto (dados + tipoDano + somaBc) → partes.
local function partesDe(mec): { any }
	if mec.partes then
		return mec.partes
	end
	local partes = {}
	for i, dados in mec.dados or {} do
		table.insert(partes, { dados = dados, bc = mec.somaBc == true and i == 1, tipo = mec.tipoDano })
	end
	return partes
end

local function temMecanica(condicoes: { [string]: number }, regras, campo: string): boolean
	for id in condicoes do
		local m = regras and regras[id]
		if m and m[campo] then
			return true
		end
	end
	return false
end

-- Rola as parcelas de dano (ou cura) contra um alvo.
local function rolarPartes(rng, partes, conj: Conjurador, alvo: Alvo?, critico: boolean, notas: { string }, mec): Combate.Dano
	local rolagens, total, tipoPrincipal = {}, 0, nil
	local maiorFaces, danoIgneo = 0, 0
	local extraAplicado = false
	local maiorFrio, extraFrioAplicado, extraArmaAplicado = 0, false, false
	for _, parte in partes do
		if parte.tipo == "frio" and parte.dados then
			for _, g in Combate.lerDados(parte.dados) do maiorFrio = math.max(maiorFrio, g.faces) end
		end
	end
	for _, parte in partes do
		local formula = parte.dados
		if parte.arma then
			local dado = conj.arma and conj.arma.dado or "d6"
			if parte.degrau and parte.degrau < 0 then dado = Arma.descer(dado, -parte.degrau) end
			formula = Arma.formula(dado)
		end
		if formula then for _, g in Combate.lerDados(formula) do maiorFaces = math.max(maiorFaces, g.faces) end end
	end
	for _, parte in partes do
		local formula, fixoDaArma = nil, 0
		if parte.arma then
			local dado = conj.arma and conj.arma.dado or "d6"
			if parte.degrau and parte.degrau < 0 then
				dado = Arma.descer(dado, -parte.degrau)
			end
			formula, fixoDaArma = Arma.formula(dado)
		else
			formula = parte.dados
		end
		local valor = 0
		if formula then
			local r = Combate.rolarDados(rng, formula)
			table.insert(rolagens, r)
			valor += r.total
			if parte.arma and conj.primeiroAtaque and not extraArmaAplicado then
				extraArmaAplicado = true
				for _ = 1, (if critico then 2 else 1) do
					local extra = Combate.rolarDados(rng, formula)
					table.insert(rolagens, extra); valor += extra.total
				end
				table.insert(notas, "Quem Se Move Primeiro: +1 Dado de Arma")
			end
			if critico then
				local extra = Combate.rolarDados(rng, formula)
				extra.formula ..= " (crítico)"
				table.insert(rolagens, extra)
				valor += extra.total
			end
			for _, g in Combate.lerDados(formula) do
				if not extraAplicado and g.faces == maiorFaces and conj.dadoExtraContra and alvo and alvo.condicoes[conj.dadoExtraContra] then
					extraAplicado = true
					local extra = Combate.rolarDados(rng, (if critico then "2d" else "1d") .. maiorFaces)
					table.insert(rolagens, extra)
					valor += extra.total
					table.insert(notas, "Dado extra da maestria, sujeito às defesas da parcela")
				end
			end
		end
		if parte.metade then
			valor = math.floor(valor / 2)
		end
		valor += fixoDaArma
		if parte.bc then
			valor += if parte.arma and conj.arma then conj.arma.bonus else conj.bc
		end
		if parte.fixo then
			valor += parte.fixo
		end
		if parte.atributo then
			valor += (conj.atributos and conj.atributos[parte.atributo]) or 0
		end
		if parte.rank then
			valor += conj.bonusDeRank or 0
		end
		local dobraContra = parte.dobraContra or (if parte.tipo == "frio" then "molhado" else nil)
		if dobraContra and alvo and alvo.condicoes[dobraContra] then
			table.insert(notas, string.format("%s dobra contra %s: %d → %d", parte.tipo or "dano", dobraContra, valor, valor * 2))
			valor *= 2
		end
		-- Defesa por parcela.
		-- Condutor: um dado do maior frio, depois da dobra e antes das defesas.
		if conj.condutorDeGelo and alvo and alvo.condicoes.molhado and parte.tipo == "frio" and not extraFrioAplicado and maiorFrio > 0 then
			extraFrioAplicado = true
			local extra = Combate.rolarDados(rng, (if critico then "2d" else "1d") .. maiorFrio)
			table.insert(rolagens, extra); valor += extra.total
			table.insert(notas, "Condutor de Gelo: dado extra de frio sem dobra de Molhado")
		end
		if alvo and parte.tipo then
			if contem(alvo.imunidades, parte.tipo) then
				table.insert(notas, string.format("Imunidade a %s: %d → 0", parte.tipo, valor))
				valor = 0
			elseif contem(alvo.resistencias, parte.tipo) then
				local metade = math.floor(valor / 2)
				table.insert(notas, string.format("Resistência a %s: %d → %d", parte.tipo, valor, metade))
				valor = metade
			end
		end
		if parte.tipo == "ígneo" and alvo and alvo.reduzIgneo then valor = math.floor(valor / 2); table.insert(notas, "Escudo de Água: metade do dano ígneo que o atravessa") end
		if parte.tipo == "ígneo" then danoIgneo += valor end
		tipoPrincipal = tipoPrincipal or parte.tipo
		total += valor
	end
	-- Quebrantado cobra "todos os seus ataques": só no tipo ataque.
	local quebrantado = conj.condicoes.quebrantado or 0
	if quebrantado > 0 and alvo and total > 0 and mec and mec.tipo == "ataque" then
		table.insert(notas, string.format("Atacante Quebrantado: dano %d → %d", total, math.max(0, total - quebrantado)))
		total = math.max(0, total - quebrantado)
	end
	return { partes = rolagens, fixo = 0, total = math.max(0, total), tipo = tipoPrincipal, danoIgneo = danoIgneo }
end

local function conj_rank(conj): number
	return conj.bonusDeRank or 0
end

local function condicoesQuePegam(lista: { string }, alvo: Alvo, notas: { string }): { string }?
	local resultado = {}
	for _, id in lista do
		local tipo = TIPO_DA_CONDICAO[id]
		if tipo and contem(alvo.imunidades, tipo) then
			table.insert(notas, "Imune a " .. tipo .. ": não pega " .. id)
		else
			table.insert(resultado, id)
		end
	end
	return if #resultado > 0 then resultado else nil
end

local function teste(rng, alvo: Alvo, resistencia, conj: Conjurador, regras)
	-- CD 8 + BC; ou CD 8 + <atributo> + Rank quando a carta nomeia outro atributo.
	local cd = resistencia.cdBase + (resistencia.extra or 0) + (conj.bonusCDJogo or 0)
	if resistencia.cdAtributo then
		cd += ((conj.atributos and conj.atributos[resistencia.cdAtributo]) or 0) + (conj.bonusDeRank or 0)
	else
		cd += conj.bc
	end
	local desvantagem = temMecanica(alvo.condicoes, regras, "desvantagemEmTestes")
	local r = Combate.resistencia(rng, alvo.resistencia(resistencia.atributo), cd, alvo.esquivaContra == "*" or (alvo.esquivaContra ~= nil and alvo.esquivaContra == conj.id), desvantagem)
	-- Gancho (A20): Dado de Inspiração somado depois de ver o resultado.
	if alvo.aposRolarTeste then
		alvo.aposRolarTeste(r)
	end
	return r
end

-- regras: mecânicas das condições do catálogo (id → { desvantagemEmAtaques, ... }).
function Habilidades.resolver(rng: Combate.Rng, mec, conjurador: Conjurador, alvos: { Alvo }, regras): { Efeito }
	local efeitos: { Efeito } = {}
	local k = conjurador.condicoes
	local partes = partesDe(mec)
	if mec.tipo == "ataque" then
		for indiceAlvo, alvo in alvos do
			local conjurador = conjurador
			if indiceAlvo > 1 and conjurador.primeiroAtaque then conjurador = table.clone(conjurador); conjurador.primeiroAtaque = false end
			local notas = {}
			local corpo = mec.corpoACorpo == true
			local vantagemBase = temMecanica(alvo.condicoes, regras, "vantagemParaQuemAtaca") or k.escondido ~= nil or conjurador.auxilio == true or alvo.marcaPacto == true
			local vantagem = vantagemBase or conjurador.primeiroAtaque == true
			local desvantagem = conjurador.desvantagem == true or temMecanica(k, regras, "desvantagemEmAtaques") or (conjurador.odioPor ~= nil and conjurador.odioPor ~= alvo.id) or (conjurador.agarradoPor ~= nil and conjurador.agarradoPor ~= alvo.id) or alvo.esquivaContra == "*" or (alvo.esquivaContra ~= nil and alvo.esquivaContra == conjurador.id)
			if corpo and temMecanica(alvo.condicoes, regras, "vantagemCorpoACorpo") then
				vantagem, vantagemBase = true, true
			elseif not corpo and temMecanica(alvo.condicoes, regras, "desvantagemADistancia") then
				desvantagem = true
			end
			if vantagem then
				table.insert(notas, "Vantagem")
			end
			if desvantagem then
				table.insert(notas, "Desvantagem")
			end
			if k.exausto then
				table.insert(notas, "Exausto: o nível não é registrado na mesa; a Desvantagem do nível 3 não foi aplicada")
			end
			local quebrantado = alvo.condicoes.quebrantado or 0
			local ca = math.max(1, alvo.ca - quebrantado)
			if quebrantado > 0 then
				table.insert(notas, string.format("Quebrantado: CA %d → %d", alvo.ca, ca))
			end
			local bonus = (if mec.atributoAcerto then (conjurador.atributos[mec.atributoAcerto] or 0) + (conjurador.bonusDeRank or 0) elseif mec.arma and conjurador.arma then conjurador.arma.bonus else conjurador.bc) + (mec.bonusAcerto or 0)
			bonus += alvo.bonusContraMarcado or 0
			bonus += alvo.bonusDeAcerto or 0
			bonus += conjurador.bonusAcertoJogo or 0
			if mec.bonusSeJaAcertou and conjurador.jaAcertou then
				bonus += mec.bonusSeJaAcertou
				table.insert(notas, string.format("Já acertou neste turno: +%d no acerto", mec.bonusSeJaAcertou))
			end
			local ataque = Combate.ataque(rng, bonus, ca, vantagem, desvantagem)
			-- Gancho (A20): Dado de Inspiração e Voz que Corrige mudam a rolagem
			-- depois de vista, antes do dano.
			if conjurador.aposRolarAtaque then
				conjurador.aposRolarAtaque(ataque, alvo, notas)
			end
			if alvo.barreira then ataque.acertou = true; ataque.critico = false end
			if (mec.acertoAutomaticoContra and alvo.condicoes[mec.acertoAutomaticoContra]) or alvo.acertoDesarmadoAutomatico then
				ataque.acertou = true
				table.insert(notas, "Contra alvo agarrado: qualquer resultado acerta")
			end
			local efeito: Efeito = { alvoId = alvo.id, ataque = ataque, notas = notas }
			-- Os disparos são independentes: errar o primeiro não cancela o segundo.
			if mec.segundoDisparo then
				efeito.danosDisparos = { 0, 0 }
				local segundo = Combate.ataque(rng, bonus, ca, vantagemBase, desvantagem)
				efeito.segundoAtaque = segundo
				table.insert(notas, string.format("2º disparo: d20 %d %+d = %d (%s)", segundo.d20.natural, segundo.bonus, segundo.total, if segundo.acertou then "acerta" else "erra"))
				if segundo.acertou then
					local conjSegundo = table.clone(conjurador); conjSegundo.primeiroAtaque = false
					efeito.dano = rolarPartes(rng, mec.segundoDisparo, conjSegundo, alvo, segundo.critico, notas, mec)
					efeito.danosDisparos[2] = efeito.dano.total
					efeito.ambosAcertaram = ataque.acertou
					if efeito.ambosAcertaram and mec.aplicaSeAmbos then efeito.aplica = { mec.aplicaSeAmbos } end
				end
			end

			if ataque.acertou then
				local p = table.clone(partes)
				if mec.condicional and mec.condicional.quando == "metadePv" and conjurador.pv * 2 <= conjurador.pvMax then
					table.insert(p, { dados = mec.condicional.dados, tipo = mec.tipoDano })
					table.insert(notas, "Com metade dos PV ou menos: +" .. mec.condicional.dados)
				end
				if mec.condicional and mec.condicional.quando == "alvoEmChamas" and alvo.condicoes["em-chamas"] then
					table.insert(p, { dados = mec.condicional.dados, tipo = mec.tipoDano })
					table.insert(notas, "Alvo Em Chamas: +" .. mec.condicional.dados)
				end
				if #p > 0 then
					local primeiroDano = rolarPartes(rng, p, conjurador, alvo, ataque.critico, notas, mec)
					if efeito.danosDisparos then efeito.danosDisparos[1] = primeiroDano.total end
					if efeito.dano then
						primeiroDano.total += efeito.dano.total
						primeiroDano.danoIgneo += efeito.dano.danoIgneo or 0
						for _, r in efeito.dano.partes do table.insert(primeiroDano.partes, r) end
					end
					efeito.dano = primeiroDano
				end
				local principais = condicoesQuePegam(comoLista(mec.aplica), alvo, notas)
				if principais then
					efeito.aplica = efeito.aplica or {}
					for _, c in principais do table.insert(efeito.aplica, c) end
				end
				efeito.estados = mec.estados
				efeito.empurrar = mec.empurraCasas
				local extra = mec.efeitoNoAcerto
				if extra and mec.segundoDisparo and not efeito.ambosAcertaram then
					extra = nil
				end
				if extra and not alvo.barreira then
					local r = teste(rng, alvo, extra.resistencia, conjurador, regras)
					efeito.resistencia = r
					if not r.passou then
						local mais = condicoesQuePegam(comoLista(extra.aplica), alvo, notas) or {}
						efeito.aplica = efeito.aplica or {}
						for _, c in mais do
							table.insert(efeito.aplica, c)
						end
						if #efeito.aplica == 0 then
							efeito.aplica = nil
						end
						efeito.empurrar = extra.empurraCasas or efeito.empurrar
						efeito.estados = extra.estados or efeito.estados
						if extra.desarmar then efeito.desarmar = true end
						if extra.quebrantado then efeito.quebrantado = conjurador.bonusDeRank or 1 end
						if extra.nota then
							table.insert(notas, extra.nota)
						end
					end
				end
			end
			table.insert(efeitos, efeito)
		end
	elseif mec.tipo == "efeito" then
		for _, alvo in alvos do
			local notas = {}
			local efeito: Efeito = { alvoId = alvo.id, notas = notas }
			if mec.exigeRespirar and alvo.respira == false then
				table.insert(notas, "Não respira: nenhum efeito")
				table.insert(efeitos, efeito)
				continue
			end
			-- Purgar (Desintoxicação): numa criatura com Dose, inverte as Doses em dano.
			if mec.inverteDoses and (alvo.condicoes.dose or 0) > 0 then
				local doses = alvo.condicoes.dose
				local p = {}
				for _ = 1, doses do
					table.insert(p, { dados = mec.inverteDoses, tipo = "veneno" })
				end
				efeito.dano = rolarPartes(rng, p, conjurador, alvo, false, notas, mec)
				efeito.remove = { "dose" }
				table.insert(notas, string.format("Inverter: %d Dose(s) viram %s cada, sem teste", doses, mec.inverteDoses))
			else
				local falhou = true
				local semTeste = mec.semTeste
				if mec.testeSoContraRankMaior and (alvo.patamar or 0) <= (conj_rank(conjurador)) then
					semTeste = true
					table.insert(notas, "Rank do alvo igual ou menor: sem teste")
				end
				if mec.disputa then
                    local venceu, total, defesa = Agarrar.disputa(rng, ((conjurador.atributos and conjurador.atributos[mec.disputa]) or 0) + (conjurador.bonusDisputa or 0), alvo.resistencia(if mec.desarmarManobra then "forcaOuAgilidade" else mec.disputa))
                    falhou = venceu
                    efeito.cdEscape = total
                    efeito.disputaVenceu = venceu
                    table.insert(notas, string.format("Disputa: %d contra %d (%s)", total, defesa, if venceu then "agarra" else "resiste"))
				end
				if mec.resistencia and not semTeste then
					local regrasDoTeste = regras
					if alvo.molhadoPor == conjurador.id then
						for _, parte in partes do if parte.tipo == "frio" then
							regrasDoTeste = table.clone(regras or {})
							regrasDoTeste.molhado = { desvantagemEmTestes = true }
						end end
					end
					local r
					if alvo.antidoto and mec.exigeRespirar then
						local cd = mec.resistencia.cdBase + conjurador.bc
						r = Combate.resistencia(rng, alvo.resistencia(mec.resistencia.atributo), cd, true, temMecanica(alvo.condicoes, regrasDoTeste, "desvantagemEmTestes"))
					else r = teste(rng, alvo, mec.resistencia, conjurador, regrasDoTeste) end
					efeito.resistencia = r
					falhou = not r.passou
				end
				if #partes > 0 and (falhou or mec.metadeNoSucesso or mec.danoSempre) then
					local dano = rolarPartes(rng, partes, conjurador, alvo, false, notas, mec)
					local cheio = falhou or mec.danoSempre or (conjurador.danoCheioEmChamas == true and alvo.condicoes["em-chamas"] ~= nil)
					if not cheio then
						dano.total = math.floor(dano.total / 2)
						table.insert(notas, "Passou no teste: metade do dano")
					end
					efeito.dano = dano
				end
				if mec.empurraSempre then efeito.empurrar = mec.empurraSempre end
				if falhou then
					efeito.aplica = condicoesQuePegam(comoLista(mec.aplica), alvo, notas)
					efeito.empurrar = mec.empurraCasas or efeito.empurrar
					efeito.doses = if alvo.antidoto then nil else mec.doses
					efeito.estados = mec.estados
					efeito.remove = mec.remove
					if mec.notaNaFalha then
						table.insert(notas, mec.notaNaFalha)
					end
				end
			end
			table.insert(efeitos, efeito)
		end
	elseif mec.tipo == "cura" then
		for _, alvo in alvos do
			local notas = {}
			local dobra = mec.dobraComFeridaFresca and alvo.feridaFresca == true
			local p = {}
			for _, parte in partes do
				table.insert(p, parte)
				if dobra and parte.dados then
					table.insert(p, { dados = parte.dados })
				end
			end
			if dobra then
				table.insert(notas, "Ferida Fresca: o dobro dos dados")
			end
			local valor = rolarPartes(rng, p, conjurador, nil, false, notas, mec).total
			if mec.curaAtributo then
				valor += (conjurador.atributos and conjurador.atributos[mec.curaAtributo]) or 0
			end
			if mec.curaRank then
				valor += conjurador.bonusDeRank or 0
			end
			local efeito: Efeito = { alvoId = alvo.id, notas = notas, remove = mec.remove }
			if mec.pvTemporarios then
				efeito.pvTemp = valor
			else
				efeito.cura = valor
			end
			table.insert(efeitos, efeito)
		end
	end
	return efeitos
end

-- Quem entra numa casa de muro com dano: dano do muro e a condição, sem teste.
function Habilidades.atravessar(rng: Combate.Rng, mec, alvo: Alvo): Efeito
	local notas = { "Atravessou a zona de perigo" }
	local partes = {}
	for _, d in mec.danoAoAtravessar do
		table.insert(partes, { dados = d, tipo = mec.tipoDano })
	end
	local dano = rolarPartes(rng, partes, { bc = 0, pv = 1, pvMax = 1, condicoes = {} }, alvo, false, notas, mec)
	return { alvoId = alvo.id, dano = dano, aplica = condicoesQuePegam(comoLista(mec.aplica), alvo, notas), notas = notas }
end

-- Dano de condição no início do turno (Em Chamas: 1d6 ígneo; Soterrado: 2d10).
function Habilidades.danoDeCondicao(rng: Combate.Rng, formula: string, tipo: string?, alvo: Alvo): Efeito
	local notas = {}
	local dano = rolarPartes(rng, { { dados = formula, tipo = tipo } }, { bc = 0, pv = 1, pvMax = 1, condicoes = {} }, alvo, false, notas, nil)
	return { alvoId = alvo.id, dano = dano, notas = notas }
end

return Habilidades
