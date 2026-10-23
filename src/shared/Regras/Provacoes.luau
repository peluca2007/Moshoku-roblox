-- Estado puro T1. Uma vaga por provação; recusa imediata aos demais, sem fila oculta.
local P = {}
P.DURACAO_AGUA = 90
function P.nova() return { estado = "livre" } end
function P.iniciar(p, userId, agora, duracao)
 if p.userId ~= nil then return false, "Ocupado — aguarde" end
 p.estado, p.userId, p.inicio, p.limite = "em-curso", userId, agora, duracao and agora + duracao
 p.sino, p.agachado = false, false
 return true
end
function P.emCurso(p, userId) return p ~= nil and p.estado == "em-curso" and p.userId == userId end
function P.aprovado(p, userId) return p ~= nil and p.estado == "aprovado" and p.userId == userId end
function P.tempo(p, agora) return if p.limite then math.max(0, p.limite - agora) else nil end
function P.expirar(p, agora)
 if p.estado == "em-curso" and p.limite and agora >= p.limite then
  p.estado = "falhou"; return true
 end
 return false
end
function P.aprovar(p, userId, agora)
 if not P.emCurso(p, userId) or P.expirar(p, agora) then return false end
 p.estado = "aprovado"; return true
end
function P.pegarSino(p, userId)
 if not P.emCurso(p, userId) then return false end
 p.sino = true; return true
end
function P.pego(p, userId)
 if not P.emCurso(p, userId) then return false end
 p.sino = false; return true
end
function P.liberar(p)
 table.clear(p); p.estado = "livre"
end
return P
