-- Relógio puro. Dia legado = tempo decorrido contínuo; apresentação começa no Dia 1 às 06h.
local Shared = game:GetService("ReplicatedStorage").Shared
local Dados = require(Shared.Mundo.RunTempo)
local R = {}
function R.visao(run, pausado)
 local fracao = run.dia % 1
 local hora = (Dados.HORA_INICIAL + fracao * 24) % 24
 local periodo = if hora >= 6 and hora < 9 then "amanhecer" elseif hora >= 9 and hora < 15 then "dia" elseif hora >= 15 and hora < 21 then "tarde" else "noite"
 return { dia = math.floor(run.dia) + 1, fracao = fracao, hora = hora, periodo = periodo, pausado = pausado == true }
end
function R.avancar(run, segundos, pausado)
 if type(segundos) ~= "number" or segundos ~= segundos or segundos < 0 or segundos == math.huge then return nil, "Tempo inválido." end
 if run.fim or pausado or segundos == 0 then return run, false end
 local novo = table.clone(run)
 novo.objetivo = table.clone(run.objetivo)
 novo.dia += segundos / Dados.DIA_SEGUNDOS
 local expirou = novo.objetivo.status == "ativo" and novo.dia >= novo.objetivo.prazoFinal
 if expirou then novo.objetivo.status = "expirado" end
 return novo, expirou
end
function R.descansar(run, tipo)
 if run.fim then return nil, "A run já terminou." end
 if tipo == "curto" then return R.avancar(run, Dados.DIA_SEGUNDOS * Dados.DESCANSO_CURTO_HORAS / 24) end
 if tipo ~= "longo" and tipo ~= "treino" then return nil, "Descanso inválido." end
 return R.avancar(run, (math.floor(run.dia) + 1 - run.dia) * Dados.DIA_SEGUNDOS)
end
return R
