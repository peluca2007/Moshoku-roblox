-- Defesas temporárias do encontro autônomo; funções puras para PV temporários.
local EncontroAutonomoDefesas = {}

local function inteiroNaoNegativo(valor)
	return type(valor) == "number" and valor == valor and valor % 1 == 0 and valor >= 0
end

local function numeroNaoNegativo(valor)
	return type(valor) == "number" and valor == valor and valor >= 0 and valor < math.huge
end

local function estadoTemporarioValido(estado)
	return type(estado) == "table"
		and inteiroNaoNegativo(estado.valor)
		and inteiroNaoNegativo(estado.expiraNoTurno)
end

function EncontroAutonomoDefesas.concederPvTemporarios(atuais, valor, turno, duracao)
	if (atuais ~= nil and not estadoTemporarioValido(atuais))
		or not inteiroNaoNegativo(valor)
		or not inteiroNaoNegativo(turno)
		or type(duracao) ~= "number" or duracao % 1 ~= 0 or duracao <= 0
	then
		return nil, false, "PV temporários inválidos."
	end
	local vigentes = if atuais and atuais.expiraNoTurno > turno then atuais else nil
	if vigentes and vigentes.valor >= valor then
		return table.clone(vigentes), false
	end
	if valor == 0 then return vigentes and table.clone(vigentes) or nil, false end
	return { valor = valor, expiraNoTurno = turno + duracao }, true
end

function EncontroAutonomoDefesas.aplicarDano(pv, pvTemporarios, dano, turno)
	if not inteiroNaoNegativo(pv)
		or (pvTemporarios ~= nil and not estadoTemporarioValido(pvTemporarios))
		or not numeroNaoNegativo(dano)
		or not inteiroNaoNegativo(turno)
	then
		return nil, "Dano ou PV temporários inválidos."
	end
	local escudo = if pvTemporarios and pvTemporarios.expiraNoTurno > turno
		then pvTemporarios.valor else 0
	local absorvido = math.min(escudo, dano)
	local restante = escudo - absorvido
	local danoNosPv = dano - absorvido
	return {
		pv = math.max(0, pv - danoNosPv),
		pvTemporarios = if restante > 0 then {
			valor = restante,
			expiraNoTurno = pvTemporarios.expiraNoTurno,
		} else nil,
		danoAbsorvido = absorvido,
		danoNosPv = danoNosPv,
	}, nil
end

function EncontroAutonomoDefesas.expirarPvTemporarios(estado, turno)
	if (estado ~= nil and not estadoTemporarioValido(estado)) or not inteiroNaoNegativo(turno) then
		return nil, false, "PV temporários inválidos."
	end
	if estado and turno >= estado.expiraNoTurno then return nil, true end
	return estado and table.clone(estado) or nil, false
end

return EncontroAutonomoDefesas
