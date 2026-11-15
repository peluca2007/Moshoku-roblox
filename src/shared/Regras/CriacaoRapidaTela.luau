-- Regras puras da tela de criação rápida (sem Instances): etapas, validade e estado visual de cada uma.
local Tela = {}

Tela.PASSOS = { "Raça", "Aparência", "Nome" }
Tela.RACA, Tela.APARENCIA, Tela.NOME = 1, 2, 3

function Tela.limitar(passo)
	if type(passo) ~= "number" or passo ~= passo then return 1 end
	return math.clamp(math.floor(passo), 1, #Tela.PASSOS)
end

-- Etapa válida para seguir: raça exige escolha; aparência sempre (o visual padrão já está pronto);
-- nome exige o texto aceito pelo `nomeValido` injetado (devolve nome, motivo).
function Tela.passoValido(passo, escolha, nomeValido)
	if passo == Tela.RACA then return escolha.raceId ~= nil end
	if passo == Tela.APARENCIA then return escolha.raceId ~= nil end
	if passo == Tela.NOME then return nomeValido ~= nil and nomeValido(escolha.nome or "") ~= nil end
	return false
end

-- "atual" | "feito" | "pendente" para cada etapa.
function Tela.estadoDosPassos(passo)
	local atual = Tela.limitar(passo)
	local lista = {}
	for i = 1, #Tela.PASSOS do
		lista[i] = if i == atual then "atual" elseif i < atual then "feito" else "pendente"
	end
	return lista
end

function Tela.rotuloAvancar(passo, ocupado)
	if ocupado then return "Criando seu aventureiro…" end
	return if Tela.limitar(passo) == #Tela.PASSOS then "Começar a aventura" else "Continuar"
end

function Tela.mostraVoltar(passo) return Tela.limitar(passo) > 1 end

return Tela
