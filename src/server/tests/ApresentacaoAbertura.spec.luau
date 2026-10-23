local Shared = game:GetService("ReplicatedStorage").Shared
local Apresentacao = require(Shared.ApresentacaoAbertura)
local Historia = require(Shared.Mundo.HistoriaV1)
local Prontos = require(Shared.PersonagensProntos)
-- Catalogo.lua depende da hierarquia Instances/WaitForChild; a tabela de árvores
-- abaixo é remontada das mesmas fontes geradas de dados que alimentam POR_ID.
local Catalogo = { POR_ID = {} }
for _, arvore in {
	require(Shared.Livro.Dados.Arvores.agua), require(Shared.Livro.Dados.Arvores.armas_pesadas),
	require(Shared.Livro.Dados.Arvores.arquearia), require(Shared.Livro.Dados.Arvores.bardo_e_interacao),
	require(Shared.Livro.Dados.Arvores.cavalaria_e_escudos), require(Shared.Livro.Dados.Arvores.cura),
	require(Shared.Livro.Dados.Arvores.desintoxicacao), require(Shared.Livro.Dados.Arvores.deus_da_agua_corpo),
	require(Shared.Livro.Dados.Arvores.deus_da_espada), require(Shared.Livro.Dados.Arvores.deus_do_norte),
	require(Shared.Livro.Dados.Arvores.fogo), require(Shared.Livro.Dados.Arvores.furtividade_e_armadilhas),
	require(Shared.Livro.Dados.Arvores.invocacao), require(Shared.Livro.Dados.Arvores.navegacao_e_lideranca),
	require(Shared.Livro.Dados.Arvores.punho_de_fogo), require(Shared.Livro.Dados.Arvores.teorica),
	require(Shared.Livro.Dados.Arvores.terra), require(Shared.Livro.Dados.Arvores.vendaval),
	require(Shared.Livro.Dados.Arvores.vento),
} do
	for _, entrada in arvore do Catalogo.POR_ID[entrada.id] = entrada end
end

local function semSlug(t, texto)
	t.ok(type(texto) == "string" and texto ~= "")
	t.ok(not string.find(texto, "%l+%-%l+"), "rótulo expõe slug: " .. texto)
end

return {
	["árvores do catálogo e escolhas prontas usam nomes de apresentação"] = function(t)
		local total = 0
		for id, entrada in Catalogo.POR_ID do
			if string.sub(id, 1, 5) == "tree/" then
				semSlug(t, Apresentacao.nomeArvore(id, Catalogo))
				t.eq(Apresentacao.nomeArvore(id, Catalogo), entrada.data.name)
				total += 1
			end
		end
		t.ok(total > 0)
		for _, personagem in Prontos do
			semSlug(t, Apresentacao.nomePronto(personagem.id, Prontos))
			t.eq(Apresentacao.nomePronto(personagem.id, Prontos), personagem.nome)
			semSlug(t, Apresentacao.nomeArvore(personagem.arvore, Catalogo))
		end
		t.eq(Apresentacao.nomeArvore("arvore-que-nao-existe", Catalogo), "Árvore")
		t.eq(Apresentacao.nomePronto("pronto-que-nao-existe", Prontos), "Personagem pronto")
	end,
	["objetivo e títulos da HistóriaV1 não expõem IDs"] = function(t)
		semSlug(t, Apresentacao.nomeObjetivo({ id = Historia.OBJETIVO.id }, Historia))
		t.eq(Apresentacao.nomeObjetivo({ id = Historia.OBJETIVO.id }, Historia), "Levar o Selo do guardião à vila")
		for _, no in Historia.HISTORIA.nos do
			if no.titulo then semSlug(t, Apresentacao.nomeObjetivo({ titulo = no.titulo }, Historia)) end
		end
		t.eq(Apresentacao.nomeObjetivo({ id = "no-desconhecido" }, Historia), "Expedição")
	end,
}
