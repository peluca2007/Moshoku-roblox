-- Servidor em Play: fluxo de um JOGADOR COMUM (sem mestre), pelo MesaDebug.commandAs,
-- com o UserId do jogador real do teste. Confere: treino, sair do treino, Desafio,
-- desistir, PvP sozinho recusado. Devolve as linhas.
local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local debug = SS:WaitForChild("MesaDebug")
local p = Players:GetPlayers()[1]
local uid = p.UserId
local linhas, falhas = {}, 0
local function check(nome, ok, det)
	table.insert(linhas, (if ok then "OK " else "FALHA ") .. nome .. ((not ok and det) and (" — " .. tostring(det)) or ""))
	if not ok then falhas += 1 end
end
local function cmd(c, payload) local r = debug:Invoke("commandAs", uid, c, payload or {}); task.wait(0.4); return r end
local function snap() return debug:Invoke("snapshotAs", uid) end
local function meu(s)
	for _, t in s.tokens do if t.ownerUserId == uid and t.habilidades then return t end end
end

debug:Invoke("commandAs", uid, "sairPartida", {}) -- limpa resto de teste anterior (pode recusar)
check("escolher Isa", cmd("escolherPersonagem", { id = "duelista-da-agua" }) == nil)
check("iniciar treino sozinho", cmd("iniciarTreino") == nil)
local s = snap()
check("treino ativo com a Isa", s.combat.active and meu(s) ~= nil and string.find(meu(s).name, "Isa", 1, true) ~= nil)
check("menu bloqueia outro treino", type(cmd("iniciarTreino")) == "string")
local me = meu(s)
check("passa a vez", cmd("nextTurn", { expectedTurn = s.combat.turn }) == nil)
check("sair do treino", cmd("sairPartida") == nil)
s = snap()
check("treino encerrado", not s.combat.active)
check("trocar para o Gorm", cmd("escolherPersonagem", { id = "brutamontes", arma = "desarmado" }) == nil)
check("Desafio nível 3", cmd("iniciarLuta", { nivel = 3 }) == nil)
task.wait(1)
s = snap()
check("luta ativa", s.combat.active)
check("Gorm de punhos", meu(s) ~= nil and string.find(meu(s).name, "Gorm", 1, true) ~= nil)
check("a barra recebe as cartas do jogador comum", meu(s) ~= nil and meu(s).habilidades ~= nil and #meu(s).habilidades > 5)
-- espera a vez do Gorm (os inimigos agem sozinhos) e usa Defender e o ataque básico
local t0 = os.clock()
while os.clock() - t0 < 25 do
	s = snap()
	if s.combat.turnId == meu(s).id then break end
	task.wait(0.5)
end
check("chega a vez do jogador", s.combat.turnId == meu(s).id)
check("usar Defender como jogador comum", cmd("usarHabilidade", { tokenId = meu(s).id, habilidadeId = "mesa/defender" }) == nil)
check("andar como jogador comum", cmd("move", { id = meu(s).id, x = meu(s).x, z = meu(s).z - 1, andar = true }) == nil)
check("desistir", cmd("sairPartida") == nil)
task.wait(2.5)
s = snap()
check("luta termina após desistir (derrota)", not s.combat.active, s.combat.active)
check("sair sem partida recusa", type(cmd("sairPartida")) == "string")
check("PvP sozinho é recusado", type(cmd("iniciarDuelo")) == "string")
return (if falhas == 0 then "TUDO OK " else falhas .. " FALHA(S) ") .. table.concat(linhas, " | ")
