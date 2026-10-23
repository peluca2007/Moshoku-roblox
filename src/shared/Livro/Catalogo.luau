-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Índice: POR_ID (todas as entradas), POR_ESPECIE (listas em ordem da fonte), FORMATO e CONTEUDO.
-- Os dados vêm de Dados/; as pastas têm nomes diferentes dos módulos (o Roblox confunde homônimos).
local dados = script.Parent:WaitForChild("Dados")
local arvores = dados:WaitForChild("Arvores")
local Manifesto = require(script.Parent:WaitForChild("Manifesto"))
local POR_ID, POR_ESPECIE = {}, {}
local function incluir(lista)
	for _, entrada in lista do
		assert(POR_ID[entrada.id] == nil, "id repetido no catálogo: " .. entrada.id)
		POR_ID[entrada.id] = entrada
		POR_ESPECIE[entrada.kind] = POR_ESPECIE[entrada.kind] or {}
		table.insert(POR_ESPECIE[entrada.kind], entrada)
	end
end
incluir(require(arvores:WaitForChild("fogo")))
incluir(require(arvores:WaitForChild("agua")))
incluir(require(arvores:WaitForChild("vento")))
incluir(require(arvores:WaitForChild("terra")))
incluir(require(arvores:WaitForChild("cura")))
incluir(require(arvores:WaitForChild("desintoxicacao")))
incluir(require(arvores:WaitForChild("teorica")))
incluir(require(arvores:WaitForChild("invocacao")))
incluir(require(arvores:WaitForChild("deus_da_espada")))
incluir(require(arvores:WaitForChild("deus_da_agua_corpo")))
incluir(require(arvores:WaitForChild("deus_do_norte")))
incluir(require(arvores:WaitForChild("armas_pesadas")))
incluir(require(arvores:WaitForChild("cavalaria_e_escudos")))
incluir(require(arvores:WaitForChild("vendaval")))
incluir(require(arvores:WaitForChild("punho_de_fogo")))
incluir(require(arvores:WaitForChild("arquearia")))
incluir(require(arvores:WaitForChild("furtividade_e_armadilhas")))
incluir(require(arvores:WaitForChild("bardo_e_interacao")))
incluir(require(arvores:WaitForChild("navegacao_e_lideranca")))
incluir(require(dados:WaitForChild("Antecedentes")))
incluir(require(dados:WaitForChild("Condicoes")))
incluir(require(dados:WaitForChild("Criaturas")))
incluir(require(dados:WaitForChild("GruposDeArma")))
incluir(require(dados:WaitForChild("Itens")))
incluir(require(dados:WaitForChild("MagiasCombinadas")))
incluir(require(dados:WaitForChild("Pericias")))
incluir(require(dados:WaitForChild("Racas")))
for kind, lista in POR_ESPECIE do
	POR_ESPECIE[kind] = table.freeze(lista)
end
return table.freeze({
	FORMATO = Manifesto.formato,
	CONTEUDO = Manifesto.conteudo,
	POR_ID = table.freeze(POR_ID),
	POR_ESPECIE = table.freeze(POR_ESPECIE),
})
