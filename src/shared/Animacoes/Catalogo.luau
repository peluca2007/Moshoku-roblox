-- Gerado por tools/blender/anim_exportar.py (ANIM1). Índice dos clipes de animação por dados.
-- Catalogo.CLIPES[nome] = tabela do clipe; Catalogo.NOMES = ordem estável. Ver tools/animacao/README.md.
local Shared = game:GetService("ReplicatedStorage").Shared

local CLIPES = {
	PosturaCombate = require(Shared.Animacoes.Clipes.PosturaCombate),
	CorteLeve = require(Shared.Animacoes.Clipes.CorteLeve),
	CortePesado = require(Shared.Animacoes.Clipes.CortePesado),
	Estocada = require(Shared.Animacoes.Clipes.Estocada),
	Emboscada = require(Shared.Animacoes.Clipes.Emboscada), -- HAB1: gerado por tools/animacao/hab1_clipes.py
	DisparoArco = require(Shared.Animacoes.Clipes.DisparoArco),
	Conjurar = require(Shared.Animacoes.Clipes.Conjurar),
	Canalizar = require(Shared.Animacoes.Clipes.Canalizar),
	ReacaoGolpe = require(Shared.Animacoes.Clipes.ReacaoGolpe),
	Esquiva = require(Shared.Animacoes.Clipes.Esquiva),
	Bloqueio = require(Shared.Animacoes.Clipes.Bloqueio),
	Queda = require(Shared.Animacoes.Clipes.Queda),
	Vitoria = require(Shared.Animacoes.Clipes.Vitoria),
}

return {
	CLIPES = CLIPES,
	NOMES = { "PosturaCombate", "CorteLeve", "CortePesado", "Estocada", "Emboscada", "DisparoArco", "Conjurar", "Canalizar", "ReacaoGolpe", "Esquiva", "Bloqueio", "Queda", "Vitoria" },
}
