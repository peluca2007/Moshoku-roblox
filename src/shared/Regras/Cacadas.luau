-- Estado pessoal das ofertas dentro da run; sem Instances ou autoridade cliente.
local C = {}
local Encontros = require(game:GetService("ReplicatedStorage").Shared.EncontrosPorZona)
C.LISTA = {
 -- B1: três ofertas dentre quatro, das quais três fáceis e próximas: sempre há ≥2 fáceis.
 { id="ratos-celeiro", nome="Ratos no celeiro", ouro=8, pa=1, perigo="fácil — perto da vila" },
 { id="goblin-campo", nome="Goblin rondando o campo", ouro=10, pa=1, perigo="fácil — perto da vila" },
 { id="lobos-estrada", nome="Lobos na estrada (borda da floresta)", ouro=12, pa=1, perigo="alto — borda da floresta" },
 { id="ratos-horta", nome="Ratos da horta", ouro=8, pa=1, perigo="fácil — perto da vila" },
}
function C.sortear(rng)
 local pool, ofertas = table.clone(C.LISTA), {}
 for _ = 1, 3 do
  local i = rng:NextInteger(1, #pool)
  table.insert(ofertas, table.remove(pool, i).id)
 end
 return ofertas
end
function C.novo(rng) return { ofertas=C.sortear(rng), aceitas={}, conclusoes={}, geracao=1 } end
function C.definicao(id)
 for _, d in ipairs(C.LISTA) do if d.id == id then return table.clone(d) end end
 return nil
end
local function tabela(valor)
 return type(valor) == "table" and getmetatable(valor) == nil
end
local function jogadorValido(chave, jogadores)
 if type(chave) ~= "string" or #chave == 0 or #chave > 32 then return false end
 local n = tonumber(chave)
 -- Clientes locais do Studio usam UserIds negativos; a identidade vem do Player servidor.
 if not n or n == 0 or math.abs(n) >= 2^53 or n % 1 ~= 0 or tostring(n) ~= chave then return false end
 return not jogadores or jogadores[n] ~= nil or jogadores[chave] ~= nil
end
-- nil e legado sem quadro. Campos extras/indices esparsos nao sao saves validos.
function C.estadoValido(estado, jogadores)
 if estado == nil then return true end
 if not tabela(estado) or not tabela(estado.ofertas) or not tabela(estado.aceitas)
  or not tabela(estado.conclusoes) or type(estado.geracao) ~= "number"
  or estado.geracao < 1 or estado.geracao % 1 ~= 0 or estado.geracao == math.huge then return false end
 for k in estado do
  if k ~= "ofertas" and k ~= "aceitas" and k ~= "conclusoes" and k ~= "geracao" then return false end
 end
 local vistos, quantidade = {}, 0
 for k,id in estado.ofertas do
  if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > 3 or not C.definicao(id) or vistos[id] then return false end
  vistos[id], quantidade = true, quantidade + 1
 end
 if quantidade ~= 3 then return false end
 for userId,id in estado.aceitas do
  if not jogadorValido(userId,jogadores) or not vistos[id] then return false end
 end
 quantidade = 0
 for chave,concluida in estado.conclusoes do
  if type(chave) ~= "string" or #chave > 132 or concluida ~= true then return false end
  local userId,encontro = string.match(chave,"^([^:]+):(.+)$")
  if not jogadorValido(userId,jogadores) or #encontro > 96 then return false end
  quantidade += 1
  if quantidade > 4096 then return false end
 end
 return true
end
function C.patrulhasValidas(estado)
 if estado == nil then return true end
 if not tabela(estado) then return false end
 local ids = {}
 for _,d in ipairs(Encontros.patrulhas()) do ids[d.id] = true end
 for id,tempo in estado do
  if not ids[id] or type(tempo) ~= "number" or tempo ~= tempo
   or tempo < 0 or tempo == math.huge then return false end
 end
 return true
end
function C.aceitar(estado, userId, id)
 if estado == nil or not C.estadoValido(estado) or not jogadorValido(tostring(userId)) or not C.definicao(id) or not table.find(estado.ofertas, id) then return false end
 estado.aceitas[tostring(userId)] = id
 return true
end
function C.bonus(estado, userId, id)
 if not estado or not C.estadoValido(estado) or estado.aceitas[tostring(userId)] ~= id then return 0, 0 end
 local d = C.definicao(id)
 return if d then d.ouro else 0, if d then d.pa else 0
end
function C.concluir(estado, userId, id, encontroId)
 if not estado or not C.estadoValido(estado) or type(encontroId) ~= "string" or #encontroId == 0 or #encontroId > 96 then return false end
 local chave = tostring(userId) .. ":" .. encontroId
 if estado.conclusoes[chave] or estado.aceitas[tostring(userId)] ~= id then return false end
 estado.conclusoes[chave] = true
 estado.aceitas[tostring(userId)] = nil
 return true
end
return C
