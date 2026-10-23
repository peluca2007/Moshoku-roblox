-- Catálogo e parser fechado; autorização e estado pertencem ao servidor.
-- `alvo` escolhe fichas (id|meus|todos); `jogadorAlvo` escolhe avatares (eu|todos|nome|UserId).
local C = {}
C.LISTA = {
 { id="ajuda", descricao="Lista os comandos e como usá-los." },
 { id="status", descricao="Mostra a partida e a quantidade de fichas." },
 { id="brotos", descricao="Abre Dados do Brotos para todos na sala; só diversão, sem trocar o mestre." },
 { id="arrumar", descricao="Recolhe papéis e livros arremessados e organiza a sala." },
 { id="jogador", descricao="Modo jogador em mesas sem lobby; na sala, transfira o posto pelo escudo." },
 { id="mestre", descricao="Modo mestre em mesas sem lobby; a sala usa eleição ou transferência consentida." },
 { id="curar", alvo=true, descricao="Restaura PV e levanta quem estava com zero PV." },
 { id="recursos", alvo=true, descricao="Restaura mana e PT, inclusive durante o combate." },
 { id="reviver", alvo=true, descricao="Recupera fichas caídas com zero PV e remove Inconsciente/Caído." },
 { id="limpar", alvo=true, descricao="Remove condições, agarrões e efeitos temporários do alvo." },
 { id="pv", alvo=true, valor=true, descricao="Define os PV do alvo (limitado ao máximo da ficha)." },
 { id="mana", alvo=true, valor=true, descricao="Define a mana do alvo (limitada ao máximo)." },
 { id="pt", alvo=true, valor=true, descricao="Define os PT do alvo (limitados ao máximo)." },
 { id="mover", alvo=true, casa=true, descricao="Reposiciona uma ficha sem gastar Ação; destino deve estar livre." },
 { id="acoes", descricao="Devolve as Ações gastas na vez atual; não renova técnicas de uma vez por turno." },
 { id="passar", descricao="Avança a vez atual, inclusive de outros jogadores." },
 { id="encerrar", confirmar=true, descricao="Encerra a partida atual, sem apagar a mesa." },
 { id="voltar", descricao="Reposiciona suas fichas na borda da mesa, ou seu avatar na entrada." },
 -- Diversão: só aparência, ~15 s, também em combate. Nunca em quem está Escondido.
 { id="brilho", jogadorAlvo=true, diversao=true, descricao="Brilha como quem acabou de tirar 20 natural." },
 { id="confete", jogadorAlvo=true, diversao=true, descricao="Explosão de confete. Alguém fez aniversário?" },
 { id="festa", jogadorAlvo=true, diversao=true, descricao="Brilho e confete juntos. A festa é sua." },
 { id="gigante", jogadorAlvo=true, diversao=true, descricao="Fica com o dobro do tamanho. Cuidado com o teto." },
 { id="mini", jogadorAlvo=true, diversao=true, descricao="Encolhe pela metade. Perfeito para se esconder atrás de um d20." },
 { id="fantasma", jogadorAlvo=true, diversao=true, descricao="Fica translúcido, mas os inimigos ainda acertam você." },
 { id="arcoiris", jogadorAlvo=true, diversao=true, descricao="Contorno trocando de cor sem parar." },
 { id="fogos", jogadorAlvo=true, diversao=true, descricao="Fogos de artifício saindo da cabeça." },
 { id="raio", jogadorAlvo=true, diversao=true, descricao="Um raio dramático cai em cima. Só cenografia, sem dano." },
 { id="dados", jogadorAlvo=true, diversao=true, descricao="Chove d20 em volta. Nenhum deles conta." },
 { id="coroa", jogadorAlvo=true, diversao=true, descricao="Uma coroa flutuante sobre a cabeça." },
 { id="fumaca", jogadorAlvo=true, diversao=true, descricao="Puf! Nuvem de fumaça de mágico de palco." },
 { id="dancar", jogadorAlvo=true, diversao=true, descricao="Gira no lugar sem sair da casa." },
 { id="normal", jogadorAlvo=true, diversao=true, descricao="Remove os efeitos de diversão." },
}
C.POR_ID = {}
for _, c in C.LISTA do C.POR_ID[c.id] = c end
local function inteiro(v, min, max)
 return type(v)=="number" and v==v and v%1==0 and v>=min and v<=max
end
function C.parse(entrada: any)
 local a
 if type(entrada)=="string" and #entrada<=160 then
  local partes={}
  for parte in string.gmatch(entrada,"%S+") do table.insert(partes,parte) end
  if partes[1] and string.lower(partes[1])=="/adm" then table.remove(partes,1) end
  local id=string.lower(table.remove(partes,1) or "ajuda")
  local c=C.POR_ID[id]
  if not c then return nil,"Comando desconhecido. Use /adm ajuda." end
  a={comando=id}
  if c.alvo then a.alvo=table.remove(partes,1) or "meus" end
  if c.jogadorAlvo then a.alvo=table.remove(partes,1) or "eu" end
  if c.valor then a.valor=tonumber((table.remove(partes,1))) end
  if c.casa then a.x=tonumber((table.remove(partes,1))); a.z=tonumber((table.remove(partes,1))) end
  if #partes>0 then return nil,"Argumentos inválidos. Use /adm ajuda." end
 elseif type(entrada)=="table" then
  a=entrada
  for k in a do if k~="comando" and k~="alvo" and k~="valor" and k~="x" and k~="z" then return nil,"Campo administrativo inválido." end end
 else return nil,"Comando inválido (máximo 160 caracteres)." end
 local c=type(a.comando)=="string" and C.POR_ID[a.comando]
 if not c then return nil,"Comando desconhecido. Use /adm ajuda." end
 local args={}
 if c.alvo then
  args.alvo=a.alvo or "meus"
  if type(args.alvo)~="string" or #args.alvo<1 or #args.alvo>80 then return nil,"Alvo inválido." end
 elseif c.jogadorAlvo then
  args.alvo=a.alvo or "eu"
  if type(args.alvo)~="string" or #args.alvo<1 or #args.alvo>40 or not string.match(args.alvo,"^[%w_]+$") then
   return nil,"Alvo inválido: use eu, todos, o nome do jogador ou o UserId."
  end
 elseif a.alvo~=nil then return nil,"Este comando não recebe alvo." end
 if c.valor then
  if not inteiro(a.valor,0,1000000) then return nil,"Informe um valor inteiro entre 0 e 1000000." end
  args.valor=a.valor
 elseif a.valor~=nil then return nil,"Este comando não recebe valor." end
 if c.casa then
  if not inteiro(a.x,1,20) or not inteiro(a.z,1,20) then return nil,"Casa inválida: X e Z entre 1 e 20." end
  args.x,args.z=a.x,a.z
 elseif a.x~=nil or a.z~=nil then return nil,"Este comando não recebe coordenadas." end
 return c.id,nil,args
end
function C.uso(c)
 return "/adm "..c.id..(if c.alvo then " <id|meus|todos>" elseif c.jogadorAlvo then " [eu|todos|nome]" else "")..(if c.valor then " <valor>" else "")..(if c.casa then " <x> <z>" else "")
end
return C
