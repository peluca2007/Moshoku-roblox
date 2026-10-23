-- Coordena só a apresentação da consulta antecipada de missões, sem novo remoto.
local Estado = { aguardando = false, abrir = false, recebido = false }
function Estado.iniciar()
 -- O servidor pode recusar Falar repetido durante cooldown; conserva o último snapshot.
 Estado.aguardando, Estado.abrir = true, false
end
function Estado.receber()
 Estado.recebido = true
 return not Estado.aguardando or Estado.abrir
end
function Estado.escolher()
 Estado.abrir = true
 return Estado.recebido
end
function Estado.fechar()
 -- Uma resposta atrasada continua recolhida depois de sair da conversa.
 Estado.abrir = false
end
return Estado
